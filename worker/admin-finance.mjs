import {HttpProblem} from './security.mjs';
const fail=(code,status=400)=>{throw new HttpProblem(code,status);};
const clean=(value,max)=>typeof value==='string'&&value.trim().length<=max?value.trim():fail('INVALID_REQUEST');
const id=value=>typeof value==='string'&&/^[A-Za-z0-9_-]{8,100}$/.test(value)?value:fail('INVALID_REQUEST');
export const feeFor=(amount,bps)=>Math.floor((amount*bps+5000)/10000);

export function businessMonthStart(timestamp,shift=0){
 const parts=new Intl.DateTimeFormat('en-US',{timeZone:'Africa/Cairo',year:'numeric',month:'numeric'}).formatToParts(new Date(timestamp));
 const value=type=>Number(parts.find(p=>p.type===type).value);
 const guess=Date.UTC(value('year'),value('month')-1+shift,1);
 const zone=new Intl.DateTimeFormat('en-US',{timeZone:'Africa/Cairo',timeZoneName:'shortOffset'}).formatToParts(new Date(guess)).find(p=>p.type==='timeZoneName').value;
 const match=zone.match(/GMT([+-])(\d+)(?::(\d+))?/);
 const offset=match?(match[1]==='-'?-1:1)*(Number(match[2])*60+Number(match[3]??0))*60000:0;
 return guess-offset;
}
export class PlatformFinance {
 constructor(db,{now=Date.now}={}){this.db=db;this.now=now;}
 async touch(user,requestedRole){
  const now=this.now(),created=Number(user.createdAt);
  const registered=Number.isSafeInteger(created)&&created>0&&created<=now?created:now;
  const role=['customer','worker'].includes(requestedRole)?requestedRole:null;
  await this.db.prepare(`INSERT INTO account_activity(uid,email,auth_created_at,last_seen_at,verified,requested_role)
   SELECT uid,?,?,?,?,COALESCE(?,'customer') FROM marketplace_accounts WHERE uid=? AND deleted_at=0
   ON CONFLICT(uid) DO UPDATE SET email=excluded.email,auth_created_at=MIN(account_activity.auth_created_at,excluded.auth_created_at),last_seen_at=excluded.last_seen_at,verified=excluded.verified,requested_role=COALESCE(?,account_activity.requested_role)
   WHERE account_activity.last_seen_at<? OR account_activity.email<>excluded.email OR account_activity.verified<>excluded.verified OR ? IS NOT NULL`).bind(user.email,registered,now,user.emailVerified===true?1:0,role,user.localId,role,now-60000,role).run();
 }
 depositFee(uid,requestId,amount,createdAt){
  return this.db.prepare(`INSERT OR IGNORE INTO platform_fee_ledger(source_type,uid,request_id,role,amount,fee,net,mode,created_at)
   SELECT 'deposit',uid,request_id,'customer',amount,(amount+50)/100,amount,'demo',?
   FROM marketplace_deposits WHERE uid=? AND request_id=? AND amount=? AND credited=0`).bind(createdAt,uid,requestId,amount);
 }
 async withdraw(account,body,normalizePhone,{demo=true}={}){
  if(!account||!['customer','worker'].includes(account.role))fail('FORBIDDEN',403);
  const uid=account.uid,requestId=id(body.requestId),amount=body.amount,method=body.method;
  if(!Number.isSafeInteger(amount)||amount<1000||amount>100000000||!['mobile_wallet','instapay'].includes(method))fail('INVALID_REQUEST');
  const destination=method==='mobile_wallet'?normalizePhone(body.destination):clean(body.destination,120);
  if(method==='instapay'&&!/^[A-Za-z0-9._-]{3,80}@instapay$/.test(destination))fail('INVALID_DESTINATION');
  const old=await this.db.prepare('SELECT * FROM wallet_withdrawal_history WHERE uid=? AND request_id=?').bind(uid,requestId).first();
  if(old){if(old.amount!==amount||old.method!==method||old.destination!==destination)fail('IDEMPOTENCY_CONFLICT',409);return;}
  const bps=account.role==='worker'?500:100,fee=feeFor(amount,bps),now=this.now();
  try{await this.db.batch([
   this.db.prepare("INSERT INTO marketplace_assertions(passed) SELECT CASE WHEN EXISTS(SELECT 1 FROM marketplace_accounts WHERE uid=? AND role=? AND deleted_at=0) THEN 1 ELSE 0 END").bind(uid,account.role),
   this.db.prepare('INSERT OR IGNORE INTO wallet_withdrawals(uid,request_id,role,amount,fee_bps,fee,net,method,destination,mode,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)').bind(uid,requestId,account.role,amount,bps,fee,amount-fee,method,destination,demo?'demo':'live',now,now),
   this.db.prepare('INSERT INTO marketplace_assertions(passed) SELECT CASE WHEN EXISTS(SELECT 1 FROM wallet_withdrawals WHERE uid=? AND request_id=? AND amount=? AND method=? AND destination=?) THEN 1 ELSE 0 END').bind(uid,requestId,amount,method,destination),
   this.db.prepare("UPDATE marketplace_accounts SET balance=balance-? WHERE uid=? AND EXISTS(SELECT 1 FROM wallet_withdrawals WHERE uid=? AND request_id=? AND reserved=0 AND status='pending')").bind(amount,uid,uid,requestId),
   this.db.prepare('UPDATE wallet_withdrawals SET reserved=1 WHERE uid=? AND request_id=?').bind(uid,requestId),
   this.db.prepare('DELETE FROM marketplace_assertions').bind()
  ]);}catch(e){if(e.message.includes('balance'))fail('INSUFFICIENT_BALANCE',409);if(e.message.includes('marketplace_valid'))fail('IDEMPOTENCY_CONFLICT',409);throw e;}
 }
 async adopt(uid,requestId){
  await this.db.prepare(`INSERT OR IGNORE INTO wallet_withdrawals SELECT * FROM wallet_withdrawal_history WHERE uid=? AND request_id=?`).bind(uid,requestId).run();
 }
 async cancel(uid,requestId){
  await this.adopt(uid,requestId);
  id(requestId);const row=await this.db.prepare('SELECT * FROM wallet_withdrawals WHERE uid=? AND request_id=?').bind(uid,requestId).first();
  if(!row)fail('NOT_FOUND',404);if(row.status==='cancelled')return;if(row.status!=='pending')fail('ORDER_CHANGED',409);
  try{await this.db.batch([
   this.guard(uid,requestId),
   this.db.prepare("UPDATE wallet_withdrawals SET status='cancelled',review_state='cancelled',updated_at=? WHERE uid=? AND request_id=? AND status='pending'").bind(this.now(),uid,requestId),
   this.refund(uid,requestId),this.markRefunded(uid,requestId),this.db.prepare('DELETE FROM marketplace_assertions').bind()
  ]);}catch(e){if(e.message.includes('marketplace_valid')){const latest=await this.db.prepare('SELECT status FROM wallet_withdrawals WHERE uid=? AND request_id=?').bind(uid,requestId).first();if(latest?.status==='cancelled')return;fail('ORDER_CHANGED',409);}throw e;}
 }
 guard(uid,requestId){return this.db.prepare("INSERT INTO marketplace_assertions(passed) SELECT CASE WHEN EXISTS(SELECT 1 FROM wallet_withdrawals WHERE uid=? AND request_id=? AND status='pending' AND reserved=1 AND refunded=0) AND EXISTS(SELECT 1 FROM marketplace_accounts WHERE uid=? AND deleted_at=0) THEN 1 ELSE 0 END").bind(uid,requestId,uid);}
 refund(uid,requestId){return this.db.prepare("UPDATE marketplace_accounts SET balance=balance+(SELECT amount FROM wallet_withdrawals WHERE uid=? AND request_id=?) WHERE uid=? AND EXISTS(SELECT 1 FROM wallet_withdrawals WHERE uid=? AND request_id=? AND status='cancelled' AND refunded=0 AND reserved=1)").bind(uid,requestId,uid,uid,requestId);}
 markRefunded(uid,requestId){return this.db.prepare("UPDATE wallet_withdrawals SET refunded=1 WHERE uid=? AND request_id=? AND status='cancelled'").bind(uid,requestId);}
 async decide(actor,body,{allowDemoFunds=false}={}){
  const uid=clean(body.uid,150),requestId=id(body.id),decision=body.decision,note=clean(body.note??'',1000),now=this.now();
  if(!['reviewed','rejected','paid'].includes(decision))fail('INVALID_REQUEST');
  await this.adopt(uid,requestId);
  const row=await this.db.prepare('SELECT * FROM wallet_withdrawals WHERE uid=? AND request_id=?').bind(uid,requestId).first();
  if(!row)fail('NOT_FOUND',404);
  if((decision==='paid'&&row.status==='paid')||(decision==='rejected'&&row.review_state==='rejected')||(decision==='reviewed'&&row.status==='pending'&&row.review_state==='reviewed'))return;
  if(row.status!=='pending')fail('ORDER_CHANGED',409);
  if(decision==='paid'&&(row.mode!=='demo'||!allowDemoFunds))fail('PAYMENTS_NOT_CONFIGURED',503);
  const statements=[this.guard(uid,requestId)];
  if(decision==='paid'){
   statements.push(this.db.prepare(`INSERT OR IGNORE INTO platform_fee_ledger(source_type,uid,request_id,role,amount,fee,net,mode,created_at)
    SELECT 'withdrawal',uid,request_id,role,amount,fee,net,mode,? FROM wallet_withdrawals WHERE uid=? AND request_id=? AND status='pending'`).bind(now,uid,requestId));
   statements.push(this.db.prepare("UPDATE wallet_withdrawals SET status='paid',review_state='paid',note=?,updated_at=? WHERE uid=? AND request_id=?").bind(note,now,uid,requestId));
  }else if(decision==='rejected'){
   statements.push(this.db.prepare("UPDATE wallet_withdrawals SET status='cancelled',review_state='rejected',note=?,updated_at=? WHERE uid=? AND request_id=?").bind(note,now,uid,requestId),this.refund(uid,requestId),this.markRefunded(uid,requestId));
  }else{
   statements.push(this.db.prepare("UPDATE wallet_withdrawals SET review_state='reviewed',note=?,updated_at=? WHERE uid=? AND request_id=?").bind(note,now,uid,requestId));
  }
  statements.push(this.db.prepare('INSERT INTO admin_audit(id,actor,kind,target,decision,note,created_at) VALUES(?,?,?,?,?,?,?)').bind(crypto.randomUUID(),actor,'withdrawal',uid+':'+requestId,decision,note,now),this.db.prepare('DELETE FROM marketplace_assertions').bind());
  try{await this.db.batch(statements);}catch(e){if(e.message.includes('marketplace_valid'))fail('ORDER_CHANGED',409);throw e;}
 }
 async dashboard(){
  const now=this.now(),month=businessMonthStart(now),active=now-30*86400000;
  const summary=await this.db.prepare(`SELECT COUNT(*) AS accounts,
   COALESCE(SUM(a.role='customer'),0) AS customers,COALESCE(SUM(a.role='worker'),0) AS workers,
   COALESCE(SUM(COALESCE(x.auth_created_at,a.created_at)>=?),0) AS registeredThisMonth,
   COALESCE(SUM(a.role='customer' AND x.last_seen_at>=?),0) AS activeCustomers,
   COALESCE(SUM(a.role='worker' AND x.last_seen_at>=?),0) AS activeWorkers,
   COALESCE(SUM(a.role='worker' AND a.available=1),0) AS availableWorkers
   FROM marketplace_accounts a LEFT JOIN account_activity x ON x.uid=a.uid WHERE a.deleted_at=0`).bind(month,active,active).first();
  const jobs=await this.db.prepare(`SELECT COUNT(*) AS total,COALESCE(SUM(status='pending'),0) AS pending,COALESCE(SUM(status='accepted'),0) AS accepted,COALESCE(SUM(status='completed'),0) AS completed,COALESCE(SUM(status IN('rejected','cancelled')),0) AS closed,
   COALESCE(SUM(status='completed' AND updated_at>=?),0) AS completedThisMonth,
   COALESCE(SUM(CASE WHEN status='completed' THEN amount ELSE 0 END),0) AS completedValue FROM marketplace_orders`).bind(month).first();
  const platform=await this.db.prepare(`SELECT COALESCE(SUM(CASE WHEN mode='live' THEN fee ELSE 0 END),0) AS balance,
   COALESCE(SUM(CASE WHEN mode='demo' THEN fee ELSE 0 END),0) AS demoBalance,
   COALESCE(SUM(CASE WHEN mode='live' AND created_at>=? THEN fee ELSE 0 END),0) AS monthlyEarnings,
   COALESCE(SUM(CASE WHEN mode='demo' AND created_at>=? THEN fee ELSE 0 END),0) AS monthlyDemoEarnings FROM platform_fee_history`).bind(month,month).first();
  const count=await this.db.prepare("SELECT COALESCE(SUM(status='pending'),0) AS pending,COALESCE(SUM(CASE WHEN status='pending' THEN fee ELSE 0 END),0) AS pendingFees FROM wallet_withdrawal_history").bind().first();
  const applications=await this.db.prepare("SELECT COUNT(*) AS pending FROM worker_applications WHERE status='pending'").bind().first();
  const withdrawals=(await this.db.prepare('SELECT w.*,a.name FROM wallet_withdrawal_history w JOIN marketplace_accounts a ON a.uid=w.uid ORDER BY w.created_at DESC LIMIT 100').bind().all()).results;
  const ledger=(await this.db.prepare('SELECT l.*,a.name FROM platform_fee_history l JOIN marketplace_accounts a ON a.uid=l.uid ORDER BY l.created_at DESC LIMIT 100').bind().all()).results;
  const accounts=(await this.db.prepare("SELECT a.uid,a.name,a.role,a.balance,a.created_at,COALESCE(x.email,'') AS email,x.auth_created_at,x.last_seen_at,COALESCE(x.verified,0) AS verified FROM marketplace_accounts a LEFT JOIN account_activity x ON x.uid=a.uid WHERE a.deleted_at=0 ORDER BY a.created_at DESC LIMIT 100").bind().all()).results;
  const orders=(await this.db.prepare('SELECT o.id,o.status,o.amount,o.created_at,c.name AS customer_name,w.name AS worker_name FROM marketplace_orders o JOIN marketplace_accounts c ON c.uid=o.customer_uid JOIN marketplace_accounts w ON w.uid=o.worker_uid ORDER BY o.created_at DESC LIMIT 100').bind().all()).results;
  const registrations=await Promise.all(Array.from({length:6},async(_,i)=>{
   const start=businessMonthStart(now,-i),end=businessMonthStart(now,1-i);
   const local=new Intl.DateTimeFormat('en-CA',{timeZone:'Africa/Cairo',year:'numeric',month:'2-digit'}).formatToParts(new Date(start));
   const label=local.find(p=>p.type==='year').value+'-'+local.find(p=>p.type==='month').value;
   const row=await this.db.prepare('SELECT COUNT(*) AS total FROM marketplace_accounts a LEFT JOIN account_activity x ON x.uid=a.uid WHERE a.deleted_at=0 AND COALESCE(x.auth_created_at,a.created_at)>=? AND COALESCE(x.auth_created_at,a.created_at)<?').bind(start,end).first();
   return {month:label,total:row.total};
  }));
  return {summary:{...summary,pendingApplications:applications.pending,pendingWithdrawals:count.pending},jobs,platform:{...platform,pendingFees:count.pendingFees},ledger,accounts,orders,registrations,withdrawals,generatedAt:now};
 }
}
