import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {tmpdir} from 'node:os';
import {DatabaseSync} from 'node:sqlite';
import {resetMarketplaceData,RESET_TABLES} from '../../tools/reset-marketplace-data.mjs';
import {fixture,setup} from './fixture.mjs';
import {PlatformFinance,feeFor} from '../admin-finance.mjs';
import {createMarketplaceHandler} from '../marketplace.mjs';
const payout=(id='payout_new_001',amount=10000)=>({requestId:id,amount,method:'instapay',destination:'test.user@instapay'});
const paid=(uid,id)=>({kind:'withdrawal',uid,id,decision:'paid',note:'Demo completion'});
const total=sql=>sql.prepare('SELECT COALESCE(SUM(fee),0) AS fee FROM platform_fee_ledger').get().fee;

test('customer deposit credits principal and one separate demo platform fee on concurrent retries',async()=>{
 const {repo,sql}=await fixture();try{
  await Promise.all(Array.from({length:10},()=>repo.deposit('c',{requestId:'deposit_admin_001',amount:10000,method:'visa',fee:0,adminBalance:999999})));
  assert.equal((await repo.account('c')).balance,30000);
  const ledger=sql.prepare('SELECT * FROM platform_fee_ledger').all();
  assert.equal(ledger.length,1);assert.equal(ledger[0].fee,200);assert.equal(ledger[0].net,10000);assert.equal(ledger[0].mode,'demo');
  assert.equal((await repo.finance.dashboard()).platform.balance,0);
  assert.equal((await repo.finance.dashboard()).platform.demoBalance,200);
 }finally{sql.close();}
});
test('customer withdrawal charges 2 percent only on completed demo settlement and cannot be paid twice',async()=>{
 const {repo,sql}=await fixture();try{
  await repo.withdraw('c',payout());
  const row=(await repo.snapshot('c')).withdrawals[0];
  assert.equal(row.fee,200);assert.equal(row.net,9800);assert.equal(row.fee_bps,200);assert.equal(total(sql),0);
  await repo.finance.decide('admin',paid('c','payout_new_001'),{allowDemoFunds:true});
  await repo.finance.decide('admin',paid('c','payout_new_001'),{allowDemoFunds:true});
  assert.equal(total(sql),200);assert.equal((await repo.account('c')).balance,10000);
  await assert.rejects(repo.cancelWithdrawal('c','payout_new_001'),/ORDER_CHANGED/);
  assert.equal(sql.prepare("SELECT COUNT(*) AS n FROM admin_audit WHERE decision='paid'").get().n,1);
 }finally{sql.close();}
});
test('worker fee is 8 percent; review is not payment and reject or cancel refunds gross once',async()=>{
 const {repo,sql}=await fixture();try{
  sql.prepare("UPDATE marketplace_accounts SET balance=30000 WHERE uid='w'").run();
  await repo.withdraw('w',payout('worker_payout_001'));
  assert.equal((await repo.snapshot('w')).withdrawals[0].fee,800);
  await repo.finance.decide('admin',{...paid('w','worker_payout_001'),decision:'reviewed'});
  assert.equal(total(sql),0);
  await repo.finance.decide('admin',{...paid('w','worker_payout_001'),decision:'rejected'});
  await repo.finance.decide('admin',{...paid('w','worker_payout_001'),decision:'rejected'});
  assert.equal((await repo.account('w')).balance,30000);assert.equal(total(sql),0);
  await repo.withdraw('w',payout('worker_payout_002'));
  await repo.cancelWithdrawal('w','worker_payout_002');await repo.cancelWithdrawal('w','worker_payout_002');
  assert.equal((await repo.account('w')).balance,30000);assert.equal(total(sql),0);
 }finally{sql.close();}
});
test('completion racing owner cancellation conserves money and never refunds a paid payout',async()=>{
 const {repo,sql}=await fixture();try{
  await repo.withdraw('c',payout('race_payout_001'));
  await Promise.allSettled([repo.finance.decide('admin',paid('c','race_payout_001'),{allowDemoFunds:true}),repo.cancelWithdrawal('c','race_payout_001')]);
  const row=sql.prepare('SELECT * FROM wallet_withdrawals').get();
  if(row.status==='paid'){assert.equal((await repo.account('c')).balance,10000);assert.equal(total(sql),200);assert.equal(row.refunded,0);}
  else{assert.equal(row.status,'cancelled');assert.equal((await repo.account('c')).balance,20000);assert.equal(total(sql),0);assert.equal(row.refunded,1);}
 }finally{sql.close();}
});
test('live payout cannot be marked paid without a real payment integration',async()=>{
 const {repo,sql}=await fixture();try{
  await repo.withdraw('c',payout(),{demo:false});
  await assert.rejects(repo.finance.decide('admin',paid('c','payout_new_001'),{allowDemoFunds:true}),/PAYMENTS_NOT_CONFIGURED/);
  assert.equal(total(sql),0);assert.equal((await repo.snapshot('c')).withdrawals[0].status,'pending');
 }finally{sql.close();}
});
test('admin access requires the configured verified email and ignores forged role fields',async()=>{
 const {repo,sql}=await fixture();try{
  const handler=createMarketplaceHandler({repository:repo,apiKey:'test-key',adminEmails:['sanad.infoo@gmail.com'],fetchImpl:async(url,opts)=>{
   const token=JSON.parse(opts.body).idToken;
   return Response.json({users:[{localId:'c',email:token==='admin-token'?'Sanad.infoo@gmail.com':'customer@example.test',emailVerified:token!=='unverified-token',createdAt:String(Date.now())}]});
  }});
  const req=(token,body)=>new Request('https://sanad.test/api/marketplace/admin'+(body?'/decision':''),{method:body?'POST':'GET',headers:{Authorization:'Bearer '+token,...(body?{'Content-Type':'application/json'}:{})},...(body?{body:JSON.stringify(body)}:{})});
  assert.equal((await handler(req('customer-token'))).status,403);
  assert.equal((await handler(req('customer-token',{email:'sanad.infoo@gmail.com',isAdmin:true,kind:'withdrawal',...paid('c','payout_new_001')}))).status,403);
  assert.equal((await handler(req('unverified-token'))).status,401);
  const admin=await handler(req('admin-token'));assert.equal(admin.status,200);assert.equal((await admin.json()).summary.accounts,3);
 }finally{sql.close();}
});
test('dashboard counts all accounts and tracks verified visits without relying on the 100-row display limit',async()=>{
 const {repo,sql}=await fixture();try{
  const now=Date.UTC(2026,9,16,18),f=new PlatformFinance(repo.db,{now:()=>now});
  for(let i=0;i<120;i++)sql.prepare("INSERT INTO marketplace_accounts(uid,role,name,created_at) VALUES(?,'customer','New account',?)").run('new_'+i,now);
  await f.touch({localId:'c',email:'customer@example.test',emailVerified:true,createdAt:String(now)});
  const d=await f.dashboard();
  assert.equal(d.summary.accounts,123);assert.equal(d.accounts.length,100);assert.equal(d.summary.customers,121);assert.equal(d.summary.workers,2);assert.equal(d.summary.activeCustomers,1);
  await f.touch({localId:'c',email:'customer@example.test',emailVerified:true,createdAt:String(now)});
  assert.equal(sql.prepare("SELECT COUNT(*) AS n FROM account_activity WHERE uid='c'").get().n,1);
 }finally{sql.close();}
});
test('rounding uses integer piasters and role-specific rates',()=>{
 assert.equal(feeFor(10000,100),100);assert.equal(feeFor(10000,500),500);
 assert.equal(feeFor(1050,100),11);assert.equal(feeFor(1010,500),51);
});
test('migration preserves old reservations and reviews and backfills only credited demo deposits',async()=>{
 const dir=fs.mkdtempSync(path.join(tmpdir(),'sanad-admin-migration-')),file=path.join(dir,'old.sqlite');
 const old=new DatabaseSync(file);
 try{
  for(const name of ['0000_phone_login','0001_marketplace','0002_customer_settings','0003_account_wallet','0004_worker_availability','0005_service_experience','0006_security'])old.exec(fs.readFileSync(new URL('../../drizzle/'+name+'.sql',import.meta.url),'utf8'));
  old.exec("INSERT INTO marketplace_accounts(uid,role,name,balance,created_at) VALUES('legacy','worker','Legacy Worker',9000,1); INSERT INTO marketplace_deposits(uid,request_id,amount,method,created_at,credited) VALUES('legacy','old_deposit_001',1000,'visa',1,1); INSERT INTO marketplace_withdrawals(uid,request_id,amount,fee,net,method,destination,reserved,created_at,updated_at) VALUES('legacy','old_payout_001',1000,50,950,'instapay','legacy@instapay',1,2,2); INSERT INTO withdrawal_reviews(uid,request_id,state,note,updated_at) VALUES('legacy','old_payout_001','reviewed','Old review',3);");
 }finally{old.close();}
 const {repo,sql}=setup(file);
 try{const w=(await repo.snapshot('legacy')).withdrawals[0];assert.equal(w.amount,1000);assert.equal(w.review_state,'reviewed');assert.equal(w.review_note,'Old review');assert.equal((await repo.account('legacy')).balance,9000);assert.equal(sql.prepare('SELECT SUM(fee) AS fee FROM platform_fee_history').get().fee,10);assert.equal((await repo.finance.dashboard()).platform.balance,0);}
 finally{sql.close();fs.rmSync(dir,{recursive:true});}
});

test('new administrator sees global lifecycle and payment history while deleted account details are scrubbed',async()=>{
 const {repo,sql}=await fixture();try{
  await repo.finance.touch({localId:'c',email:'private@example.test',emailVerified:true,createdAt:String(Date.now()-1000)});
  await repo.deposit('c',{requestId:'deposit_events_001',amount:10000,method:'visa'});
  const before=await repo.finance.dashboard();
  await repo.deleteAccount('c');
  const d=await repo.finance.dashboard();
  assert.equal(d.summary.registeredThisMonth,before.summary.registeredThisMonth);
  assert.deepEqual(d.registrations,before.registrations);
  assert.equal(d.summary.deletedAccounts,1);assert.equal(d.summary.accounts,2);
  assert.equal(sql.prepare("SELECT COUNT(*) AS n FROM account_activity WHERE uid='c'").get().n,0);
  assert.ok(d.activity.some(x=>x.event==='Account created'&&x.id==='account:c'));
  assert.ok(d.activity.some(x=>x.event==='Account deleted'&&x.name==='Deleted account'));
  assert.ok(d.activity.some(x=>x.event==='Deposit completed'&&x.amount===10000&&x.fee===200&&x.mode==='demo'));
  assert.ok(!JSON.stringify(d).includes('private@example.test'));
  assert.equal(d.platform.demoBalance,200);
 }finally{sql.close();}
});

test('administrator is an independent identity with no marketplace account and no customer operations',async()=>{
 const {repo,sql}=setup();try{
  let email='Sanad.infoo@gmail.com',verified=true;
  const handler=createMarketplaceHandler({repository:repo,apiKey:'test-key',adminEmails:['sanad.infoo@gmail.com'],fetchImpl:async()=>Response.json({users:[{localId:'standalone_admin',email,emailVerified:verified,createdAt:String(Date.now())}]})});
  const req=(path,body)=>new Request('https://sanad.test/api/marketplace/'+path,{method:body?'POST':'GET',headers:{Authorization:'Bearer admin-session','Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});
  const session=await handler(req('session'));
  assert.equal(session.status,200);assert.equal(session.headers.get('Cache-Control'),'no-store');
  assert.deepEqual(await session.json(),{isAdmin:true,role:'admin'});
  const dashboard=await handler(req('admin'));assert.equal(dashboard.status,200);
  assert.equal((await dashboard.json()).summary.accounts,0);
  assert.equal(await repo.account('standalone_admin'),undefined);
  for(const [path,body] of [['bootstrap',{name:'Admin',role:'worker'}],['signup-role',{role:'customer'}],['deposit',{requestId:'admin_deposit_001',amount:10000,method:'visa'}],['worker-application',{fullName:'Admin'}],['snapshot',null]]){
   assert.equal((await handler(req(path,body))).status,403,path);
  }
  assert.equal(sql.prepare('SELECT COUNT(*) AS n FROM marketplace_accounts').get().n,0);
  email='ordinary@example.test';
  assert.deepEqual(await (await handler(req('session'))).json(),{isAdmin:false,role:null});
  assert.equal((await handler(req('admin'))).status,403);
  verified=false;assert.equal((await handler(req('session'))).status,401);
 }finally{sql.close();}
});
test('operator reset removes live and deleted accounts, funds, events and counters without changing the schema',async()=>{
 const {repo,sql}=await fixture();try{
  await repo.deposit('c',{requestId:'reset_deposit_001',amount:10000,method:'visa'});
  await repo.finance.touch({localId:'c',email:'old@example.test',emailVerified:true,createdAt:String(Date.now())});
  await repo.deleteAccount('other');
  await repo.withdraw('c',payout('reset_payout_001'));
  await assert.rejects(resetMarketplaceData(repo.db,'wrong'),/RESET_CONFIRMATION_REQUIRED/);
  assert.equal((await repo.finance.dashboard()).summary.deletedAccounts,1);
  await resetMarketplaceData(repo.db,'RESET SANAD DATA');
  for(const table of RESET_TABLES)assert.equal(sql.prepare('SELECT COUNT(*) AS n FROM '+table).get().n,0,table);
  assert.deepEqual(sql.prepare('PRAGMA foreign_key_check').all(),[]);
  const d=await repo.finance.dashboard();
  assert.equal(d.summary.accounts,0);assert.equal(d.summary.deletedAccounts,0);
  assert.equal(d.summary.registeredThisMonth,0);assert.equal(d.jobs.total,0);
  assert.equal(d.platform.balance,0);assert.equal(d.platform.demoBalance,0);
  assert.equal(d.activity.length,0);assert.equal(d.ledger.length,0);
  assert.ok(d.registrations.every(r=>r.total===0));
  await resetMarketplaceData(repo.db,'RESET SANAD DATA');
  await repo.register({localId:'fresh',displayName:'Fresh Customer',email:'fresh@example.test',emailVerified:true},{role:'customer',name:'Fresh Customer'});
  assert.equal((await repo.account('fresh')).balance,0);
  assert.equal((await repo.snapshot('fresh')).orders.length,0);
 }finally{sql.close();}
});

test('fee migration is registered and preserves v7 customer and worker withdrawal quotes',()=>{
 const sql=new DatabaseSync(':memory:');
 try{
  const journal=JSON.parse(fs.readFileSync(new URL('../../drizzle/meta/_journal.json',import.meta.url),'utf8'));
  for(const entry of journal.entries.filter(e=>e.idx<8))sql.exec(fs.readFileSync(new URL('../../drizzle/'+entry.tag+'.sql',import.meta.url),'utf8'));
  for(const [uid,role,bps,fee] of [['old_customer','customer',100,100],['old_worker','worker',500,500]]){
   sql.prepare('INSERT INTO marketplace_accounts(uid,role,name,balance,created_at) VALUES(?,?,?,10000,1)').run(uid,role,uid);
   sql.prepare("INSERT INTO wallet_withdrawals(uid,request_id,role,amount,fee_bps,fee,net,method,destination,reserved,created_at,updated_at) VALUES(?,'old_request',?,10000,?,?,?,'instapay','old@instapay',1,1,1)").run(uid,role,bps,fee,10000-fee);
  }
  const before=sql.prepare('SELECT * FROM wallet_withdrawals ORDER BY uid').all();
  const migration=journal.entries.find(e=>e.idx===8);assert.equal(migration?.tag,'0008_fee_policy');
  sql.exec(fs.readFileSync(new URL('../../drizzle/'+migration.tag+'.sql',import.meta.url),'utf8'));
  assert.deepEqual(sql.prepare('SELECT * FROM wallet_withdrawals ORDER BY uid').all(),before);
  assert.deepEqual(sql.prepare('PRAGMA foreign_key_check').all(),[]);
 }finally{sql.close();}
});
