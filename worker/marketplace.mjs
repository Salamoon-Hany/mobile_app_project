import {ServiceExperience, appointment} from './service-experience.mjs';
export const SERVICES = ['builder','electrician','plumber','carpenter','tiler','steel_fixer','plasterer','repairing','gardener','heavy_equipment','rubbish'];
export const EXPERIENCE_COUNTRIES=['EG','AE','SA','QA','KW','BH','OM','PK','IN'];
const names = ['Builder','Electrician','Plumber','Carpenter','Tiler','Steel Fixer','Plasterer','Repairing','Gardener','Heavy Equipment','Rubbish'];
const failure=(code,status=400)=>{const e=new Error(code);e.status=status;throw e;};
const text=(v,max=2000)=>typeof v==='string'&&v.trim().length<=max?v.trim():failure('INVALID_REQUEST');
const requestId=v=>/^[A-Za-z0-9_-]{8,100}$/.test(v??'')?v:failure('INVALID_REQUEST');
function skills(v){if(!Array.isArray(v)||v.length>11||v.some(x=>!SERVICES.includes(x)))failure('INVALID_SERVICES');return [...new Set(v)];}
function photo(v){if(v==null)return null;if(typeof v!=='string'||v.length>700000||!/^data:image\/(jpeg|png|webp);base64,[A-Za-z0-9+/=]+$/.test(v))failure('INVALID_PHOTO');return v;}

const digits=v=>text(v,50).replace(/[٠-٩۰-۹]/g,d=>String('٠١٢٣٤٥٦٧٨٩'.includes(d)?'٠١٢٣٤٥٦٧٨٩'.indexOf(d):'۰۱۲۳۴۵۶۷۸۹'.indexOf(d)));
export function normalizeContact(v){let p=digits(v).replace(/[\s()\-]/g,'');if(p.startsWith('00'))p='+'+p.slice(2);if(/^01[0125]\d{8}$/.test(p))p='+20'+p.slice(1);if(!/^\+[1-9]\d{7,14}$/.test(p))failure('INVALID_PHONE');return p;}
export function nationalIdSuffix(v){const id=digits(v);if(!/^[23]\d{13}$/.test(id))failure('INVALID_NATIONAL_ID');const year=(id[0]==='2'?1900:2000)+Number(id.slice(1,3)),month=Number(id.slice(3,5)),day=Number(id.slice(5,7)),date=new Date(Date.UTC(year,month-1,day));if(date.getUTCFullYear()!==year||date.getUTCMonth()!==month-1||date.getUTCDate()!==day||date>Date.now())failure('INVALID_NATIONAL_ID');return id.slice(-4);}
async function eraseFirebaseAccount(uid,token,apiKey,fetchImpl){
 const base='https://firestore.googleapis.com/v1/projects/salamoon-services/databases/(default)/documents';
 try{
  const existing=await fetchImpl(base+'/users/'+encodeURIComponent(uid),{headers:{Authorization:'Bearer '+token},signal:AbortSignal.timeout(15000)});
  if(existing.ok){
   const scrub=await fetchImpl(base+':commit',{method:'POST',headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'},body:JSON.stringify({writes:[{update:{name:'projects/salamoon-services/databases/(default)/documents/users/'+uid,fields:{name:{stringValue:'Deleted account'},gender:{stringValue:''}}},updateMask:{fieldPaths:['name','gender']},updateTransforms:[{fieldPath:'updatedAt',setToServerValue:'REQUEST_TIME'}],currentDocument:{exists:true}}]}),signal:AbortSignal.timeout(15000)});
   if(!scrub.ok)failure('DELETE_RETRY',503);
  }else if(existing.status!==404)failure('DELETE_RETRY',503);
  const result=await fetchImpl(`https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${encodeURIComponent(apiKey)}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({idToken:token}),signal:AbortSignal.timeout(15000)});
  if(!result.ok)failure('DELETE_RETRY',503);
 }catch(e){if(e.message==='DELETE_RETRY')throw e;failure('DELETE_RETRY',503);}
}

export class MarketplaceRepository {
 constructor(db){this.db=db;}
 account(uid){return this.db.prepare('SELECT * FROM marketplace_accounts WHERE uid=? AND deleted_at=0').bind(uid).first();}
 active(uid){return this.db.prepare('INSERT INTO marketplace_assertions(passed) SELECT CASE WHEN EXISTS(SELECT 1 FROM marketplace_accounts WHERE uid=? AND deleted_at=0) THEN 1 ELSE 0 END').bind(uid);}
 async register(user,body){
  const raw=await this.db.prepare('SELECT deleted_at FROM marketplace_accounts WHERE uid=?').bind(user.localId).first();if(raw?.deleted_at)failure('ACCOUNT_DELETING',409);
  const current=await this.account(user.localId);
  if(current){
    if(body.phone!==undefined||body.nationalId!==undefined)await this.update(user.localId,{phone:body.phone,nationalId:body.nationalId});
    if(!current.gender&&body.gender)await this.update(user.localId,{gender:body.gender});
    await this.db.prepare('UPDATE marketplace_accounts SET phone=? WHERE uid=? AND deleted_at=0').bind(user.phoneNumber??current.phone,user.localId).run();
    if(current.role==='customer'&&current.legacy_imported===0&&body.hasLegacy===true){
      const amount=body.legacyBalance??0;
      if(!Number.isSafeInteger(amount)||amount<0||amount>100000000)failure('INVALID_REQUEST');
      const history=JSON.stringify(Array.isArray(body.legacyOrders)?body.legacyOrders.slice(0,1000):[]);
      const receipts=JSON.stringify(Array.isArray(body.legacyReceipts)?body.legacyReceipts.slice(0,1000):[]);
      if(history.length>300000||receipts.length>150000)failure('INVALID_REQUEST');
      await this.db.prepare('UPDATE marketplace_accounts SET balance=balance+?,legacy_orders=?,legacy_receipts=?,photo=COALESCE(photo,?),legacy_imported=1 WHERE uid=? AND legacy_imported=0 AND deleted_at=0').bind(amount,history,receipts,photo(body.photo),user.localId).run();
    }
    return this.account(user.localId);
  }
  // Accounts created before this release always retain their customer role.
  const role=Number(user.createdAt)<1791997200000?'customer':body.role??'customer';
  if(!['customer','worker'].includes(role))failure('INVALID_ROLE');
  if(body.phone!==undefined&&body.phone!=='')normalizeContact(body.phone);if(role==='worker'&&body.nationalId)nationalIdSuffix(body.nationalId);
  const name=text(body.name??user.displayName??'',80);if(name.length<2)failure('INVALID_NAME');
  const balance=body.legacyBalance??0;if(!Number.isSafeInteger(balance)||balance<0||balance>100000000)failure('INVALID_REQUEST');
  const legacy=Array.isArray(body.legacyOrders)?body.legacyOrders.slice(0,1000):[];
  if(JSON.stringify(legacy).length>300000)failure('INVALID_REQUEST');
  await this.db.prepare('INSERT OR IGNORE INTO marketplace_accounts(uid,role,name,balance,legacy_orders,photo,created_at,phone,legacy_receipts,legacy_imported) VALUES(?,?,?,?,?,?,?,?,?,?)').bind(user.localId,role,name,role==='customer'?balance:0,JSON.stringify(legacy),photo(body.photo),Date.now(),user.phoneNumber??'',JSON.stringify(Array.isArray(body.legacyReceipts)?body.legacyReceipts.slice(0,1000):[]),(body.hasLegacy===true||balance>0||legacy.length>0)?1:0).run();
  if(body.phone!==undefined||body.nationalId!==undefined||body.gender!==undefined)await this.update(user.localId,{phone:body.phone,nationalId:body.nationalId,gender:body.gender});
  return this.account(user.localId);
 }
 async customerSettings(uid){
  const a=await this.account(uid);if(a?.role!=='customer')return {workerApplication:null,rating:null};
  const row=await this.db.prepare('SELECT * FROM worker_applications WHERE uid=?').bind(uid).first();
  const vote=await this.db.prepare('SELECT stars,comment,created_at,updated_at FROM app_ratings WHERE uid=?').bind(uid).first();
  return {workerApplication:row?{fullName:row.full_name,phone:row.phone,email:row.email,workTypes:JSON.parse(row.work_types),experienceYears:row.experience_years,countries:JSON.parse(row.countries),status:row.status,createdAt:row.created_at,updatedAt:row.updated_at}:null,rating:vote?{stars:vote.stars,comment:vote.comment,createdAt:vote.created_at,updatedAt:vote.updated_at}:null};
 }
 async submitWorkerApplication(user,body){
  const uid=user.localId,a=await this.account(uid);if(a?.role!=='customer')failure('FORBIDDEN',403);
  const name=text(body.fullName,80);if(name.length<2)failure('INVALID_NAME');
  const selected=skills(body.workTypes);if(!selected.length)failure('INVALID_SERVICES');
  const years=body.experienceYears;if(!Number.isInteger(years)||years<0||years>60)failure('INVALID_EXPERIENCE');
  const countries=body.countries;if(!Array.isArray(countries)||!countries.length||countries.length>EXPERIENCE_COUNTRIES.length||countries.some(c=>!EXPERIENCE_COUNTRIES.includes(c)))failure('INVALID_COUNTRIES');
  let phone=text(body.phone,50).replace(/[\s()\-]/g,'').replace(/[٠-٩۰-۹]/g,d=>'٠١٢٣٤٥٦٧٨٩'.includes(d)?String('٠١٢٣٤٥٦٧٨٩'.indexOf(d)):String('۰۱۲۳۴۵۶۷۸۹'.indexOf(d)));
  if(phone.startsWith('00'))phone='+'+phone.slice(2);if(/^01[0125]\d{8}$/.test(phone))phone='+20'+phone.slice(1);if(!/^\+[1-9]\d{7,14}$/.test(phone))failure('INVALID_PHONE');
  const now=Date.now();
  await this.db.batch([this.active(uid),this.db.prepare("INSERT INTO worker_applications(uid,full_name,phone,email,work_types,experience_years,countries,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?) ON CONFLICT(uid) DO UPDATE SET full_name=excluded.full_name,phone=excluded.phone,email=excluded.email,work_types=excluded.work_types,experience_years=excluded.experience_years,countries=excluded.countries,updated_at=excluded.updated_at WHERE worker_applications.status='pending'").bind(uid,name,phone,user.email,JSON.stringify(selected),years,JSON.stringify([...new Set(countries)]),now,now),this.db.prepare('DELETE FROM marketplace_assertions').bind()]);
  const saved=await this.db.prepare('SELECT status FROM worker_applications WHERE uid=?').bind(uid).first();if(saved.status!=='pending')failure('APPLICATION_LOCKED',409);
 }
 async rateApplication(uid,body){
  const a=await this.account(uid);if(a?.role!=='customer')failure('FORBIDDEN',403);
  const stars=body.stars;if(!Number.isInteger(stars)||stars<1||stars>5)failure('INVALID_RATING');
  const comment=text(body.comment??'',2000);const now=Date.now();await this.db.batch([this.active(uid),this.db.prepare('INSERT INTO app_ratings(uid,stars,comment,created_at,updated_at) VALUES(?,?,?,?,?) ON CONFLICT(uid) DO UPDATE SET stars=excluded.stars,comment=excluded.comment,updated_at=excluded.updated_at').bind(uid,stars,comment,now,now),this.db.prepare('DELETE FROM marketplace_assertions').bind()]);
 }
 async snapshot(uid){
  const account=await this.account(uid);if(!account)failure('ACCOUNT_REQUIRED',409);
  const rows=await this.db.prepare(`SELECT o.id,o.customer_uid,o.worker_uid,o.request_id,o.services,o.amount,o.details,o.location,o.scheduled_at,o.status,o.created_at,o.updated_at,(o.photo IS NOT NULL) AS has_photo,c.name AS customer_name,COALESCE(NULLIF(c.contact_phone,''),c.phone) AS customer_phone,w.name AS worker_name FROM marketplace_orders o JOIN marketplace_accounts c ON c.uid=o.customer_uid JOIN marketplace_accounts w ON w.uid=o.worker_uid WHERE o.customer_uid=? OR o.worker_uid=? ORDER BY o.created_at DESC LIMIT 1000`).bind(uid,uid).all();
  const deposits=await this.db.prepare('SELECT request_id AS id,amount,method FROM marketplace_deposits WHERE uid=? ORDER BY created_at DESC LIMIT 1000').bind(uid).all();
  const withdrawals=await this.db.prepare('SELECT w.request_id AS id,w.amount,w.fee,w.net,w.method,w.destination,w.status,w.created_at,w.updated_at,r.state AS review_state,r.note AS review_note FROM marketplace_withdrawals w LEFT JOIN withdrawal_reviews r ON r.uid=w.uid AND r.request_id=w.request_id WHERE w.uid=? ORDER BY w.created_at DESC LIMIT 1000').bind(uid).all();
  return {withdrawals:withdrawals.results,...await this.customerSettings(uid),account:{...account,skills:JSON.parse(account.skills),legacy_orders:JSON.parse(account.legacy_orders),legacy_receipts:undefined},orders:rows.results.map(o=>({...o,services:JSON.parse(o.services),location:JSON.parse(o.location)})),deposits:[...JSON.parse(account.legacy_receipts),...deposits.results]};
 }
 async orderPhoto(uid,id){
  const row=await this.db.prepare('SELECT photo FROM marketplace_orders WHERE id=? AND (customer_uid=? OR worker_uid=?)').bind(id,uid,uid).first();if(!row)failure('NOT_FOUND',404);return {photo:row.photo};
 }
 async update(uid,body){
  const account=await this.account(uid);if(!account)failure('ACCOUNT_REQUIRED',409);
  const name=text(body.name??account.name,80);if(name.length<2)failure('INVALID_NAME');
  const selected=body.skills==null?JSON.parse(account.skills):skills(body.skills);
  if(body.available!==undefined&&(account.role!=='worker'||typeof body.available!=='boolean'))failure('FORBIDDEN',403);
  const available=body.available===undefined?null:body.available?1:0;
  if(account.role!=='worker'&&selected.length)failure('FORBIDDEN',403);
  const gender=body.gender??account.gender;if(!['','Male','Female','Other'].includes(gender))failure('INVALID_REQUEST');
  const contact=body.phone===undefined?account.contact_phone:body.phone===''?'':normalizeContact(body.phone);
  let last4=account.national_id_last4;
  if(body.nationalId!==undefined){if(account.role!=='worker')failure('FORBIDDEN',403);last4=body.nationalId===''?'':nationalIdSuffix(body.nationalId);}
  await this.db.prepare('UPDATE marketplace_accounts SET name=?,skills=?,photo=?,gender=?,contact_phone=?,national_id_last4=?,available=COALESCE(?,available) WHERE uid=? AND deleted_at=0').bind(name,JSON.stringify(selected),body.photo===undefined?account.photo:photo(body.photo),gender,contact,last4,available,uid).run();
 }
 async workers(uid,requested){
  const a=await this.account(uid);if(a?.role!=='customer')failure('FORBIDDEN',403);
  const wanted=skills(requested);if(!wanted.length)failure('INVALID_SERVICES');
  const result=await this.db.prepare("SELECT uid,name,skills,(SELECT AVG(stars) FROM order_reviews WHERE worker_uid=marketplace_accounts.uid) AS rating,(SELECT COUNT(*) FROM order_reviews WHERE worker_uid=marketplace_accounts.uid) AS review_count,(SELECT COUNT(*) FROM marketplace_orders WHERE worker_uid=marketplace_accounts.uid AND status='completed') AS jobs_completed FROM marketplace_accounts WHERE role='worker' AND deleted_at=0 AND available=1 ORDER BY name LIMIT 1000").bind().all();
  return result.results.filter(w=>wanted.every(s=>JSON.parse(w.skills).includes(s))).map(w=>({...w,skills:JSON.parse(w.skills)}));
 }
 async deposit(uid,body){
  const a=await this.account(uid);if(a?.role!=='customer')failure('FORBIDDEN',403);
  const id=requestId(body.requestId), amount=body.amount;
  if(!Number.isSafeInteger(amount)||amount<1000||amount>100000000||!['visa','vodafoneCash','fawry'].includes(body.method))failure('INVALID_REQUEST');
  const previous=await this.db.prepare('SELECT amount,method FROM marketplace_deposits WHERE uid=? AND request_id=?').bind(uid,id).first();
  if(previous&&(previous.amount!==amount||previous.method!==body.method))failure('IDEMPOTENCY_CONFLICT',409);
  // D1 batch rolls every statement back if any assertion/constraint fails.
  try{await this.db.batch([
    this.active(uid),
    this.db.prepare('INSERT OR IGNORE INTO marketplace_deposits(uid,request_id,amount,method,created_at) VALUES(?,?,?,?,?)').bind(uid,id,amount,body.method,Date.now()),
    this.db.prepare('INSERT INTO marketplace_assertions(passed) SELECT CASE WHEN EXISTS(SELECT 1 FROM marketplace_deposits WHERE uid=? AND request_id=? AND amount=? AND method=?) THEN 1 ELSE 0 END').bind(uid,id,amount,body.method),
    this.db.prepare('UPDATE marketplace_accounts SET balance=balance+? WHERE uid=? AND EXISTS(SELECT 1 FROM marketplace_deposits WHERE uid=? AND request_id=? AND credited=0)').bind(amount,uid,uid,id),
    this.db.prepare('UPDATE marketplace_deposits SET credited=1 WHERE uid=? AND request_id=?').bind(uid,id),
    this.db.prepare('DELETE FROM marketplace_assertions').bind(),
  ]);}catch(e){if(e.message.includes('marketplace_valid'))failure('IDEMPOTENCY_CONFLICT',409);throw e;}

 }
 async createOrder(uid,body){
  const a=await this.account(uid);if(a?.role!=='customer')failure('FORBIDDEN',403);
  const id=requestId(body.requestId), selected=skills(body.services);if(!selected.length)failure('INVALID_SERVICES');
  const worker=await this.account(body.workerUid);if(worker?.role!=='worker'||!selected.every(x=>JSON.parse(worker.skills).includes(x)))failure('WORKER_UNAVAILABLE',409);
  const location=body.location;
  if(!location||typeof location.latitude!=='number'||typeof location.longitude!=='number'||!Number.isFinite(location.latitude)||!Number.isFinite(location.longitude)||Math.abs(location.latitude)>90||Math.abs(location.longitude)>180)failure('INVALID_LOCATION');
  const loc={latitude:location.latitude,longitude:location.longitude,label:text(location.label,300),fromGps:location.fromGps===true};
  const details=text(body.details??'',2000), image=photo(body.photo), serviceJson=JSON.stringify(selected);
  const old=await this.db.prepare('SELECT * FROM marketplace_orders WHERE customer_uid=? AND request_id=?').bind(uid,id).first();
  const matches=o=>o.worker_uid===worker.uid&&o.services===serviceJson&&o.details===details&&o.location===JSON.stringify(loc)&&o.photo===image&&o.scheduled_at===(body.scheduledAt??0);
  if(old){if(!matches(old))failure('IDEMPOTENCY_CONFLICT',409);return old.id;}
  if(worker.available!==1)failure('WORKER_UNAVAILABLE',409);
  let quoted=null; if(body.quoteId){quoted=await this.db.prepare('SELECT * FROM quote_requests WHERE id=? AND customer_uid=?').bind(body.quoteId,uid).first();if(!quoted||quoted.worker_uid!==worker.uid||quoted.services!==serviceJson||quoted.details!==details||quoted.location!==JSON.stringify(loc)||quoted.photo!==image||quoted.amount!==body.expectedQuoteAmount||!['offered','booked'].includes(quoted.status))failure('QUOTE_CHANGED',409);if(quoted.status==='booked'){const existing=await this.db.prepare('SELECT id FROM marketplace_orders WHERE id=? AND customer_uid=?').bind(quoted.order_id,uid).first();if(existing)return existing.id;failure('QUOTE_CHANGED',409);}}
  const amount=quoted?quoted.amount:selected.length*7500,scheduled=appointment(quoted?quoted.scheduled_at:body.scheduledAt);
  const orderId=crypto.randomUUID(),now=Date.now();
  try{await this.db.batch([
    this.active(uid),
    this.active(worker.uid),
    ...(quoted?[this.db.prepare("INSERT INTO marketplace_assertions(passed) SELECT CASE WHEN EXISTS(SELECT 1 FROM quote_requests WHERE id=? AND status='offered' AND amount=?) THEN 1 ELSE 0 END").bind(quoted.id,amount)]:[]),
    this.db.prepare('INSERT INTO marketplace_assertions(passed) SELECT CASE WHEN EXISTS(SELECT 1 FROM marketplace_accounts WHERE uid=? AND available=1 AND deleted_at=0) THEN 1 ELSE 0 END').bind(worker.uid),
    this.db.prepare('INSERT OR IGNORE INTO marketplace_orders(id,customer_uid,worker_uid,request_id,services,amount,details,location,photo,scheduled_at,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)').bind(orderId,uid,worker.uid,id,serviceJson,amount,details,JSON.stringify(loc),image,scheduled,now,now),
    this.db.prepare('INSERT INTO marketplace_assertions(passed) SELECT CASE WHEN EXISTS(SELECT 1 FROM marketplace_orders WHERE customer_uid=? AND request_id=? AND worker_uid=? AND services=? AND details=? AND location=? AND photo IS ?) THEN 1 ELSE 0 END').bind(uid,id,worker.uid,serviceJson,details,JSON.stringify(loc),image),
    this.db.prepare('INSERT INTO marketplace_assertions(passed) SELECT CASE WHEN NOT EXISTS(SELECT value FROM json_each(?) WHERE value NOT IN(SELECT value FROM json_each((SELECT skills FROM marketplace_accounts WHERE uid=?)))) THEN 1 ELSE 0 END').bind(serviceJson,worker.uid),
    this.db.prepare('UPDATE marketplace_accounts SET balance=balance-? WHERE uid=? AND EXISTS(SELECT 1 FROM marketplace_orders WHERE customer_uid=? AND request_id=? AND reserved=0)').bind(amount,uid,uid,id),
    this.db.prepare('UPDATE marketplace_orders SET reserved=1 WHERE customer_uid=? AND request_id=?').bind(uid,id),
    ...(quoted?[this.db.prepare("UPDATE quote_requests SET status='booked',order_id=?,updated_at=? WHERE id=? AND status='offered' AND amount=?").bind(orderId,now,quoted.id,amount)]:[]),
    this.db.prepare('DELETE FROM marketplace_assertions').bind(),
  ]);}catch(e){if(e.message.includes('balance'))failure('INSUFFICIENT_BALANCE',409);if(e.message.includes('marketplace_valid')){if((await this.account(worker.uid))?.available!==1)failure('WORKER_UNAVAILABLE',409);failure('IDEMPOTENCY_CONFLICT',409);}throw e;}
  const saved=await this.db.prepare('SELECT * FROM marketplace_orders WHERE customer_uid=? AND request_id=?').bind(uid,id).first();
  if(!matches(saved))failure('IDEMPOTENCY_CONFLICT',409);return saved.id;
 }
 async decide(uid,id,action){
  if(!await this.account(uid))failure('ACCOUNT_REQUIRED',409);
  const order=await this.db.prepare('SELECT * FROM marketplace_orders WHERE id=? AND (customer_uid=? OR worker_uid=?)').bind(id,uid,uid).first();if(!order)failure('NOT_FOUND',404);
  const target={accept:'accepted',reject:'rejected',complete:'completed',cancel:'cancelled'}[action];if(!target)failure('INVALID_REQUEST');
  const allowed=action==='complete'||action==='cancel'?order.customer_uid===uid:order.worker_uid===uid;
  if(!allowed)failure('FORBIDDEN',403);
  if(order.status===target)return;
  const from=action==='complete'?'accepted':'pending';
  if(order.status!==from)failure('ORDER_CHANGED',409);
  const statements=[
    this.active(uid),
    this.db.prepare('INSERT INTO marketplace_assertions(passed) SELECT CASE WHEN EXISTS(SELECT 1 FROM marketplace_orders WHERE id=? AND status IN (?,?)) THEN 1 ELSE 0 END').bind(id,from,target),
    this.db.prepare('UPDATE marketplace_orders SET status=?,updated_at=? WHERE id=? AND status=?').bind(target,Date.now(),id,from),
  ];
  if(['rejected','cancelled','completed'].includes(target)){
    const recipient=target==='completed'?order.worker_uid:order.customer_uid;
    statements.push(this.db.prepare('UPDATE marketplace_accounts SET balance=balance+(SELECT amount FROM marketplace_orders WHERE id=?) WHERE uid=? AND EXISTS(SELECT 1 FROM marketplace_orders WHERE id=? AND status=? AND settled=0)').bind(id,recipient,id,target));
    statements.push(this.db.prepare('UPDATE marketplace_orders SET settled=1 WHERE id=? AND status=?').bind(id,target));
  }
  statements.push(this.db.prepare('DELETE FROM marketplace_assertions').bind());
  try{await this.db.batch(statements);}catch(e){if(e.message.includes('marketplace_valid'))failure('ORDER_CHANGED',409);throw e;}

 }
 async withdraw(uid,body){
  const a=await this.account(uid);if(a?.role!=='worker')failure('FORBIDDEN',403);
  const id=requestId(body.requestId),amount=body.amount,method=body.method;
  if(!Number.isSafeInteger(amount)||amount<1000||amount>100000000||!['mobile_wallet','instapay'].includes(method))failure('INVALID_REQUEST');
  const destination=method==='mobile_wallet'?normalizeContact(body.destination):text(body.destination,120);
  if(method==='instapay'&&!/^[A-Za-z0-9._-]{3,80}@instapay$/.test(destination))failure('INVALID_DESTINATION');
  const old=await this.db.prepare('SELECT amount,method,destination FROM marketplace_withdrawals WHERE uid=? AND request_id=?').bind(uid,id).first();
  if(old&&(old.amount!==amount||old.method!==method||old.destination!==destination))failure('IDEMPOTENCY_CONFLICT',409);
  const fee=Math.floor((amount*5+50)/100),now=Date.now();
  try{await this.db.batch([
   this.active(uid),
   this.db.prepare('INSERT OR IGNORE INTO marketplace_withdrawals(uid,request_id,amount,fee,net,method,destination,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?)').bind(uid,id,amount,fee,amount-fee,method,destination,now,now),
   this.db.prepare('INSERT INTO marketplace_assertions(passed) SELECT CASE WHEN EXISTS(SELECT 1 FROM marketplace_withdrawals WHERE uid=? AND request_id=? AND amount=? AND method=? AND destination=?) THEN 1 ELSE 0 END').bind(uid,id,amount,method,destination),
   this.db.prepare('UPDATE marketplace_accounts SET balance=balance-? WHERE uid=? AND EXISTS(SELECT 1 FROM marketplace_withdrawals WHERE uid=? AND request_id=? AND reserved=0)').bind(amount,uid,uid,id),
   this.db.prepare('UPDATE marketplace_withdrawals SET reserved=1 WHERE uid=? AND request_id=?').bind(uid,id),
   this.db.prepare('DELETE FROM marketplace_assertions').bind(),
  ]);}catch(e){if(e.message.includes('balance'))failure('INSUFFICIENT_BALANCE',409);if(e.message.includes('marketplace_valid'))failure('IDEMPOTENCY_CONFLICT',409);throw e;}
 }
 async cancelWithdrawal(uid,id){
  if((await this.account(uid))?.role!=='worker')failure('FORBIDDEN',403);requestId(id);
  const row=await this.db.prepare('SELECT * FROM marketplace_withdrawals WHERE uid=? AND request_id=?').bind(uid,id).first();if(!row)failure('NOT_FOUND',404);
  await this.db.batch([
   this.active(uid),
   this.db.prepare("UPDATE marketplace_withdrawals SET status='cancelled',updated_at=? WHERE uid=? AND request_id=? AND status='pending'").bind(Date.now(),uid,id),
   this.db.prepare("UPDATE marketplace_accounts SET balance=balance+? WHERE uid=? AND EXISTS(SELECT 1 FROM marketplace_withdrawals WHERE uid=? AND request_id=? AND status='cancelled' AND refunded=0 AND reserved=1)").bind(row.amount,uid,uid,id),
   this.db.prepare("UPDATE marketplace_withdrawals SET refunded=1 WHERE uid=? AND request_id=? AND status='cancelled'").bind(uid,id),
   this.db.prepare('DELETE FROM marketplace_assertions').bind(),
  ]);
 }
 async deleteAccount(uid){
  // Tombstone first: even cached Firebase tokens cannot read or mutate the account.
  // Preserve only anonymous financial/order ledger records for counterpart histories.
  try{await this.db.batch([
   this.db.prepare("INSERT INTO marketplace_assertions(passed) SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM marketplace_orders WHERE (customer_uid=? OR worker_uid=?) AND status IN ('pending','accepted')) AND NOT EXISTS(SELECT 1 FROM marketplace_withdrawals WHERE uid=? AND status='pending') THEN 1 ELSE 0 END").bind(uid,uid,uid),
   this.db.prepare("UPDATE marketplace_accounts SET deleted_at=CASE WHEN deleted_at=0 THEN ? ELSE deleted_at END,name='Deleted account',phone='',contact_phone='',gender='',national_id_last4='',skills='[]',photo=NULL,balance=0,legacy_orders='[]',legacy_receipts='[]' WHERE uid=?").bind(Date.now(),uid),
   this.db.prepare('DELETE FROM order_messages WHERE sender_uid=?').bind(uid),
   this.db.prepare('DELETE FROM order_reviews WHERE customer_uid=?').bind(uid),
   this.db.prepare('DELETE FROM order_complaints WHERE uid=?').bind(uid),
   this.db.prepare('DELETE FROM notification_reads WHERE uid=?').bind(uid),
   this.db.prepare("UPDATE quote_requests SET status=CASE WHEN status IN ('requested','offered') THEN 'cancelled' ELSE status END,details='',location=?,photo=NULL WHERE customer_uid=? OR worker_uid=?").bind(JSON.stringify({latitude:0,longitude:0,label:'Location removed',redacted:true}),uid,uid),
   this.db.prepare('DELETE FROM app_ratings WHERE uid=?').bind(uid),
   this.db.prepare('DELETE FROM worker_applications WHERE uid=?').bind(uid),
   this.db.prepare('DELETE FROM phone_login_aliases WHERE uid=?').bind(uid),
   this.db.prepare("UPDATE marketplace_withdrawals SET destination='' WHERE uid=?").bind(uid),
   this.db.prepare("UPDATE marketplace_orders SET details='',location=?,photo=NULL WHERE customer_uid=?").bind(JSON.stringify({latitude:0,longitude:0,label:'Location removed',fromGps:false,redacted:true}),uid),
   this.db.prepare('DELETE FROM marketplace_assertions').bind(),
  ]);}catch(e){if(e.message.includes('marketplace_valid'))failure('DELETE_ACTIVE_WORK',409);throw e;}
 }

}
export function createMarketplaceHandler({repository,apiKey,fetchImpl=fetch,now=Date.now,adminEmails=[]}){
 const experience=new ServiceExperience(repository);
 const tokens=new Map();
 async function authenticate(request,allowUnverified=false,force=false){
  const token=request.headers.get('Authorization')?.match(/^Bearer (\S+)$/)?.[1];if(!token)failure('INVALID_CREDENTIALS',401);
  const cached=tokens.get(token);if(!force&&cached&&cached.until>now()){if(!allowUnverified&&cached.user.emailVerified!==true)failure('INVALID_CREDENTIALS',401);return cached.user;}
  const r=await fetchImpl(`https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${encodeURIComponent(apiKey)}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({idToken:token}),signal:AbortSignal.timeout(10000)});
  if(!r.ok)failure('INVALID_CREDENTIALS',401);const user=(await r.json()).users?.[0];
  if(!user?.localId||!user.email||(!allowUnverified&&user.emailVerified!==true)||user.disabled)failure('INVALID_CREDENTIALS',401);
  if(tokens.size>500)tokens.clear();tokens.set(token,{user,until:now()+30000});return user;
 }
 return async request=>{
  try{
   const url=new URL(request.url);if(request.headers.get('Origin')&&request.headers.get('Origin')!==url.origin)failure('FORBIDDEN',403);
   if(!['GET','POST'].includes(request.method))failure('METHOD_NOT_ALLOWED',405);
   const deleting=url.pathname==='/api/marketplace/account/delete';
   const user=await authenticate(request,url.pathname==='/api/marketplace/signup-role'&&request.method==='POST',deleting);let body={};
   if(request.method==='POST'){if(!request.headers.get('Content-Type')?.startsWith('application/json')||Number(request.headers.get('Content-Length'))>1100000)failure('INVALID_REQUEST');const raw=await request.text();if(raw.length>1100000)failure('INVALID_REQUEST');try{body=JSON.parse(raw);}catch{failure('INVALID_REQUEST');}if(!body||typeof body!=='object'||Array.isArray(body))failure('INVALID_REQUEST');}
   let data;const route=url.pathname.replace('/api/marketplace','');
   if(route!=='/account/delete'&&route!=='/bootstrap'&&route!=='/signup-role'&&!await repository.account(user.localId))failure('ACCOUNT_REQUIRED',409);
   const isAdmin=user.emailVerified===true&&adminEmails.map(x=>x.toLowerCase()).includes(user.email.toLowerCase());
   if(route==='/admin'&&request.method==='GET'){if(!isAdmin)failure('FORBIDDEN',403);data=await experience.adminSnapshot();}
   else if(route==='/admin/decision'&&request.method==='POST'){if(!isAdmin)failure('FORBIDDEN',403);await experience.adminDecision(user.localId,body);data=await experience.adminSnapshot();}
   else if(route==='/admin/photo'&&request.method==='POST'){if(!isAdmin)failure('FORBIDDEN',403);const row=await repository.db.prepare('SELECT photo FROM order_complaints WHERE id=?').bind(body.id).first();if(!row)failure('NOT_FOUND',404);data={photo:row.photo};}
   else if(route==='/quotes'&&request.method==='POST'){await experience.requestQuote(user.localId,body);data=await repository.snapshot(user.localId);}
   else if(/^\/quotes\/[^/]+\/(offer|cancel)$/.test(route)&&request.method==='POST'){const id=route.split('/')[2];if(route.endsWith('/offer'))await experience.offer(user.localId,id,body);else await experience.cancelQuote(user.localId,id);data=await repository.snapshot(user.localId);}
   else if(/^\/orders\/[^/]+\/experience$/.test(route)&&request.method==='GET')data=await experience.detail(user.localId,route.split('/')[2]);
   else if(/^\/orders\/[^/]+\/(message|complaint|review|extra)$/.test(route)&&request.method==='POST'){const id=route.split('/')[2],action=route.split('/')[3];await experience[{message:'send',complaint:'complain',review:'review',extra:'extra'}[action]](user.localId,id,body);data=await experience.detail(user.localId,id);}
   else if(/^\/orders\/[^/]+\/extras\/[^/]+$/.test(route)&&request.method==='POST'){await experience.decideExtra(user.localId,route.split('/')[2],route.split('/')[4],body);data=await experience.detail(user.localId,route.split('/')[2]);}
   else if(/^\/workers\/[^/]+\/reviews$/.test(route)&&request.method==='GET')data=await experience.reviews(user.localId,route.split('/')[2]);
   else if(route==='/attachment'&&request.method==='POST')data=await experience.attachment(user.localId,body.kind,body.id);
   else if(route==='/notice/read'&&request.method==='POST'){await experience.readNotice(user.localId,body.id);data={ok:true};}
   else if(route==='/account/delete'&&request.method==='POST'){
    if(body.confirm!==true)failure('INVALID_REQUEST');
    if(!Number.isFinite(Number(user.lastLoginAt))||now()-Number(user.lastLoginAt)>300000)failure('REAUTH_REQUIRED',401);
    await repository.deleteAccount(user.localId);
    const token=request.headers.get('Authorization').slice(7);
    await eraseFirebaseAccount(user.localId,token,apiKey,fetchImpl);
    for(const [key,value] of tokens)if(value.user.localId===user.localId)tokens.delete(key);
    data={deleted:true};
   }
   else if(route==='/signup-role'&&request.method==='POST'){await repository.register(user,{role:body.role,name:body.name,phone:body.phone,nationalId:body.nationalId});data={registered:true};}
   else if(route==='/bootstrap'&&request.method==='POST'){await repository.register(user,body);data=await repository.snapshot(user.localId);}
   else if(route==='/snapshot'&&request.method==='GET')data=await repository.snapshot(user.localId);
   else if(route==='/workers'&&request.method==='GET')data={workers:await repository.workers(user.localId,(url.searchParams.get('services')??'').split(','))};
   else if(/^\/orders\/[^/]+\/photo$/.test(route)&&request.method==='GET')data=await repository.orderPhoto(user.localId,route.split('/')[2]);
   else if(route==='/worker-application'&&request.method==='POST'){await repository.submitWorkerApplication(user,body);data=await repository.snapshot(user.localId);}
   else if(route==='/rating'&&request.method==='POST'){await repository.rateApplication(user.localId,body);data=await repository.snapshot(user.localId);}
   else if(route==='/withdrawals'&&request.method==='POST'){await repository.withdraw(user.localId,body);data=await repository.snapshot(user.localId);}
   else if(/^\/withdrawals\/[^/]+\/cancel$/.test(route)&&request.method==='POST'){await repository.cancelWithdrawal(user.localId,route.split('/')[2]);data=await repository.snapshot(user.localId);}
   else if(route==='/profile'&&request.method==='POST'){await repository.update(user.localId,body);data=await repository.snapshot(user.localId);}
   else if(route==='/deposit'&&request.method==='POST'){await repository.deposit(user.localId,body);data=await repository.snapshot(user.localId);}
   else if(route==='/orders'&&request.method==='POST'){await repository.createOrder(user.localId,body);data=await repository.snapshot(user.localId);}
   else if(/^\/orders\/[^/]+\/decision$/.test(route)&&request.method==='POST'){await repository.decide(user.localId,route.split('/')[2],body.action);data=await repository.snapshot(user.localId);}
   else failure('NOT_FOUND',404);
   if(data?.account){data.isAdmin=isAdmin;data.quotes=await experience.quotes(user.localId);data.notices=await experience.notices(user.localId);}
   return Response.json(data,{headers:{'Cache-Control':'no-store'}});
  }catch(e){const code=e.message?.includes('INSUFFICIENT_BALANCE')?'INSUFFICIENT_BALANCE':e.message;return Response.json({error:e.status||code==='INSUFFICIENT_BALANCE'?code:'TEMPORARILY_UNAVAILABLE'},{status:e.status??(code==='INSUFFICIENT_BALANCE'?409:503),headers:{'Cache-Control':'no-store'}});}
 };
}
export function serviceNames(services){return services.map(s=>names[SERVICES.indexOf(s)]).join(', ');}
