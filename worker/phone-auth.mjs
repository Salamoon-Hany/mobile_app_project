import {HttpProblem,problem,readJson,safeFailure,digest,RequestLimiter,assertPublicOutput} from './security.mjs';
const normalizePhone=input=>{
 if(typeof input!=='string'||input.length>50)problem('INVALID_REQUEST');
 let phone=input.trim().replace(/[\s()\-]/g,'').replace(/[٠-٩۰-۹]/g,d=>String('٠١٢٣٤٥٦٧٨٩'.includes(d)?'٠١٢٣٤٥٦٧٨٩'.indexOf(d):'۰۱۲۳۴۵۶۷۸۹'.indexOf(d)));
 if(phone.startsWith('00'))phone='+'+phone.slice(2);if(/^01[0125]\d{8}$/.test(phone))phone='+20'+phone.slice(1);
 if(!/^\+[1-9]\d{7,14}$/.test(phone))problem('INVALID_REQUEST');return phone;
};
export class PhoneRepository {
  constructor(db) { this.db = db; }
  async limit(key, maximum, now, period=60000) {
    const window = Math.floor(now / period);
    const result = await this.db.prepare('INSERT INTO phone_login_limits (key, window, count) VALUES (?, ?, 1) ON CONFLICT(key) DO UPDATE SET count = CASE WHEN window = excluded.window THEN MIN(count + 1,10000) ELSE 1 END, window = excluded.window RETURNING count').bind(key, window).first();
    return result.count <= maximum;
  }
  async find(phone) { return this.db.prepare('SELECT uid, email FROM phone_login_aliases WHERE phone = ?').bind(phone).first(); }
  async isDeleted(uid){return !!(await this.db.prepare('SELECT deleted_at FROM marketplace_accounts WHERE uid=? AND deleted_at<>0').bind(uid).first());}
  async save(user) {
    await this.db.batch([
      this.db.prepare('INSERT INTO marketplace_assertions(passed) SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM marketplace_accounts WHERE uid=? AND deleted_at<>0) THEN 1 ELSE 0 END').bind(user.localId),
      this.db.prepare('DELETE FROM phone_login_aliases WHERE uid = ? AND phone <> ?').bind(user.localId, user.phoneNumber),
      this.db.prepare('INSERT INTO phone_login_aliases (phone, uid, email) VALUES (?, ?, ?) ON CONFLICT(phone) DO UPDATE SET uid=excluded.uid, email=excluded.email').bind(user.phoneNumber, user.localId, user.email),
      this.db.prepare('DELETE FROM marketplace_assertions').bind(),
    ]);
  }
}

PhoneRepository.prototype.clearLimit=async function(key){await this.db.prepare('DELETE FROM phone_login_limits WHERE key=?').bind(key).run();};

export function createPhoneHandler({repository,apiKey,fetchImpl=fetch,now=Date.now}){
 const limiter=repository.db?new RequestLimiter(repository.db,now):null;
 async function limit(scope,identity,max,period=60000){if(limiter)return limiter.hit(scope,identity,max,period);if(!await repository.limit(scope+':'+await digest(identity),max,now(),period))throw new HttpProblem('RATE_LIMIT',429,Math.ceil((period-now()%period)/1000));}
 async function clear(scope,identity){if(limiter)return limiter.clear(scope,identity);if(repository.clearLimit)await repository.clearLimit(scope+':'+await digest(identity));}
 async function firebase(action,body){
  const response=await fetchImpl(`https://identitytoolkit.googleapis.com/v1/accounts:${action}?key=${encodeURIComponent(apiKey)}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(15000)});
  let data;try{data=await response.json();}catch{problem('TEMPORARILY_UNAVAILABLE',503);}
  if(!response.ok){const message=data?.error?.message??'';if(response.status===429||/TOO_MANY_ATTEMPTS|QUOTA_EXCEEDED|TOO_MANY_REQUESTS/.test(message))throw new HttpProblem('RATE_LIMIT',429,900);const unavailable=response.status>=500||response.status===403||/API_KEY_INVALID|INVALID_API_KEY|OPERATION_NOT_ALLOWED|CONFIGURATION_NOT_FOUND|PROJECT_NOT_FOUND/.test(message);problem(unavailable?'TEMPORARILY_UNAVAILABLE':'INVALID_CREDENTIALS',unavailable?503:401);}return data;
 }
 async function lookup(token,phoneRequired=false){
  if(typeof token!=='string'||token.length>8192)problem('INVALID_CREDENTIALS',401);
  const user=(await firebase('lookup',{idToken:token})).users?.[0];
  if(typeof user?.localId!=='string'||!user.localId||user.localId.length>128||typeof user.email!=='string'||user.email.length>254||user.disabled)problem('INVALID_CREDENTIALS',401);
  if(repository.isDeleted&&await repository.isDeleted(user.localId))problem('INVALID_CREDENTIALS',401);
  if(phoneRequired){if(user.emailVerified!==true||!user.phoneNumber)problem('INVALID_CREDENTIALS',401);user.phoneNumber=normalizePhone(user.phoneNumber);}return user;
 }
 return async request=>{
  try{
   const url=new URL(request.url);if(request.method!=='POST')problem('METHOD_NOT_ALLOWED',405);
   if(request.headers.has('Origin')&&request.headers.get('Origin')!==url.origin)problem('FORBIDDEN',403);
   const body=await readJson(request,8192),ip=request.headers.get('CF-Connecting-IP')??'unknown';await limit('auth-ip',ip,30);
   if(url.pathname==='/api/auth/phone/register'){
    const token=request.headers.get('Authorization')?.match(/^Bearer (\S+)$/)?.[1];const user=await lookup(token,true);await repository.save(user);return Response.json({registered:true},{headers:{'Cache-Control':'no-store'}});
   }
   if(url.pathname!=='/api/auth/login')problem('NOT_FOUND',404);
   const raw=body.identifier;
   if(typeof raw!=='string'||raw.length>254||typeof body.password!=='string'||!body.password||body.password.length>4096)problem('INVALID_REQUEST');
   const identifier=raw.trim().toLowerCase();
   if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(identifier))problem('INVALID_REQUEST');
   await limit('login-ip',ip,120,900000);await limit('login-identifier',identifier,5,900000);
   const email=identifier;
   const signed=await firebase('signInWithPassword',{email,password:body.password,returnSecureToken:true});
   const current=await lookup(signed.idToken,false);
   if(current.email.toLowerCase()!==email.toLowerCase())problem('INVALID_CREDENTIALS',401);
   await clear('login-identifier',identifier);
   const output={email:current.email,uid:current.localId};assertPublicOutput(output);return Response.json(output,{headers:{'Cache-Control':'no-store'}});
  }catch(error){return safeFailure(error,request);}
 };
}
