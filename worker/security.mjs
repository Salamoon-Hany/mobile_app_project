// Shared HTTP boundary. Do not log credentials, request bodies, SQL or user data.
export class HttpProblem extends Error {
  constructor(code, status = 400, retryAfter = 0) {
    super(code); this.status = status; this.retryAfter = retryAfter;
  }
}
export const problem = (code, status = 400) => { throw new HttpProblem(code, status); };
const codes = new Set(('INVALID_REQUEST INVALID_NAME INVALID_ROLE INVALID_SERVICES INVALID_PHONE INVALID_NATIONAL_ID INVALID_LOCATION INVALID_PHOTO INVALID_RATING INVALID_AMOUNT INVALID_DESTINATION INVALID_EXPERIENCE INVALID_COUNTRIES INVALID_COMPLAINT INVALID_APPOINTMENT EMPTY_MESSAGE FORBIDDEN NOT_FOUND INVALID_CREDENTIALS ACCOUNT_REQUIRED ACCOUNT_DELETING IDEMPOTENCY_CONFLICT WORKER_UNAVAILABLE ORDER_CHANGED QUOTE_CHANGED REVIEW_LOCKED APPLICATION_LOCKED INSUFFICIENT_BALANCE DELETE_RETRY DELETE_ACTIVE_WORK REAUTH_REQUIRED RATE_LIMIT PAYMENTS_NOT_CONFIGURED METHOD_NOT_ALLOWED PAYLOAD_TOO_LARGE UNSUPPORTED_MEDIA_TYPE SECURE_CONNECTION_REQUIRED TEMPORARILY_UNAVAILABLE').split(' '));
export function safeFailure(error, request, logger = console) {
  const code = codes.has(error?.message) ? error.message : 'TEMPORARILY_UNAVAILABLE';
  const status = codes.has(error?.message) && [400,401,403,404,405,409,413,415,429,503].includes(error.status) ? error.status : 503;
  const requestId = crypto.randomUUID();
  if (status >= 500) logger.error(JSON.stringify({event:'request_failed',requestId,area:new URL(request.url).pathname.startsWith('/api/auth/')?'auth':'api',code}));
  return Response.json({error:code,requestId},{status,headers:{'Cache-Control':'no-store','X-Request-ID':requestId,...(status===429?{'Retry-After':String(Math.min(900,Math.max(1,error.retryAfter||60)))}:{})}});
}
export async function digest(value) {
  return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(value))),x=>x.toString(16).padStart(2,'0')).join('');
}
export async function readJson(request, maximum = 1100000) {
  if (request.headers.get('Content-Type')?.split(';')[0].trim().toLowerCase() !== 'application/json') problem('UNSUPPORTED_MEDIA_TYPE',415);
  const length = request.headers.get('Content-Length');
  if (length !== null && (!/^\d+$/.test(length) || Number(length)>maximum)) problem('PAYLOAD_TOO_LARGE',413);
  const reader=request.body?.getReader(); if(!reader) problem('INVALID_REQUEST');
  let size=0; const chunks=[];
  try { for (;;) { const {done,value}=await reader.read(); if(done) break; size+=value.byteLength; if(size>maximum){await reader.cancel();problem('PAYLOAD_TOO_LARGE',413);} chunks.push(value); } } finally { reader.releaseLock(); }
  const bytes=new Uint8Array(size); let offset=0; for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.byteLength;}
  let data; try {data=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));} catch {problem('INVALID_REQUEST');}
  if(!data || Array.isArray(data) || typeof data!=='object') problem('INVALID_REQUEST');
  let nodes=0;
  function check(value,depth=0){if(++nodes>30000||depth>12)problem('INVALID_REQUEST');if(Array.isArray(value)){if(value.length>2000)problem('INVALID_REQUEST');value.forEach(x=>check(x,depth+1));}else if(value&&typeof value==='object'){for(const [key,v] of Object.entries(value)){if(['__proto__','prototype','constructor'].includes(key))problem('INVALID_REQUEST');check(v,depth+1);}}else if(typeof value==='number'&&!Number.isFinite(value))problem('INVALID_REQUEST');}
  check(data); return data;
}
// Fail closed if an internal field accidentally reaches a public response.
export function assertPublicOutput(data) {
  let nodes=0;
  function check(v,depth=0){if(++nodes>80000||depth>16)throw Error('Invalid output');if(typeof v==='number'&&!Number.isFinite(v))throw Error('Invalid output');if(typeof v==='string'&&v.length>800000)throw Error('Invalid output');if(Array.isArray(v)){if(v.length>3000)throw Error('Invalid output');v.forEach(x=>check(x,depth+1));}else if(v&&typeof v==='object'){for(const [key,x] of Object.entries(v)){if(/^(password|idToken|refreshToken|access_token|refresh_token|private_key|credential)$/i.test(key))throw Error('Invalid output');check(x,depth+1);}}}
  check(data);
}
export class RequestLimiter {
  constructor(db,now=Date.now){this.db=db;this.now=now;}
  async hit(scope,identity,maximum,period=60000){
    const now=this.now(),bucket=Math.floor(now/period),key=scope+':'+await digest(identity);
    const row=await this.db.prepare('INSERT INTO security_rate_limits(key,bucket,count,expires_at) VALUES(?,?,1,?) ON CONFLICT(key) DO UPDATE SET count=CASE WHEN bucket=excluded.bucket THEN MIN(count+1,10000) ELSE 1 END,bucket=excluded.bucket,expires_at=excluded.expires_at RETURNING count').bind(key,bucket,(bucket+1)*period).first();
    if(row.count>maximum)throw new HttpProblem('RATE_LIMIT',429,Math.ceil(((bucket+1)*period-now)/1000));
    if(Math.random()<0.01)await this.db.prepare('DELETE FROM security_rate_limits WHERE key IN (SELECT key FROM security_rate_limits WHERE expires_at<? LIMIT 100)').bind(now-86400000).run();
  }
  async clear(scope,identity){await this.db.prepare('DELETE FROM security_rate_limits WHERE key=?').bind(scope+':'+await digest(identity)).run();}
}
export function sensitivePath(path){
  try {for(let i=0;i<2;i++)path=decodeURIComponent(path);}catch{return true;}
  if(/[\\\u0000-\u001f]/.test(path)||path.split('/').some(x=>x.startsWith('.')))return true;
  if(/^\/(worker|server|drizzle|flutter-source|node_modules|scripts)(\/|$)/i.test(path))return true;
  if(/\.(map|env|pem|key|keystore|jks|db|sqlite3?|log|bak|properties)$/i.test(path))return true;
  if(/^\/(package(-lock)?\.json|pubspec\.(yaml|lock)|firestore\.rules)$/i.test(path))return true;
  return path!=='/'&&path.endsWith('/');
}
// Flutter CanvasKit requires WebAssembly compilation; script strings remain blocked.
const csp="default-src 'self'; base-uri 'self'; object-src 'none'; frame-ancestors 'self' https://chatgpt.com https://chat.openai.com; script-src 'self' 'wasm-unsafe-eval' https://www.gstatic.com https://www.googleapis.com; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data: https://fonts.gstatic.com; worker-src 'self' blob:; connect-src 'self' https://identitytoolkit.googleapis.com https://securetoken.googleapis.com https://firestore.googleapis.com https://firebaseinstallations.googleapis.com https://www.googleapis.com https://www.gstatic.com https://fonts.gstatic.com https://photon.komoot.io; frame-src https://salamoon-services.firebaseapp.com; form-action 'self'; upgrade-insecure-requests";
export function protectResponse(response,request){
  const headers=new Headers(response.headers);
  for(const [key,value] of Object.entries({'X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer','Permissions-Policy':'camera=(self), geolocation=(self), microphone=(), payment=(), usb=()','Content-Security-Policy':csp,'Cross-Origin-Opener-Policy':'same-origin-allow-popups','Cross-Origin-Resource-Policy':'same-origin','X-Permitted-Cross-Domain-Policies':'none'}))headers.set(key,value);
  headers.delete('X-Powered-By');headers.delete('Server');
  if(new URL(request.url).protocol==='https:')headers.set('Strict-Transport-Security','max-age=31536000');
  if(new URL(request.url).pathname.startsWith('/api/')){headers.set('Cache-Control','no-store');headers.set('Pragma','no-cache');}
  return new Response(response.body,{status:response.status,statusText:response.statusText,headers});
}
export async function perimeter(request,env,handle){
  let response; const url=new URL(request.url),origin=request.headers.get('Origin');
  try {
    if(url.protocol!=='https:'&&!(env.ALLOW_LOCAL_HTTP==='true'&&['localhost','127.0.0.1','[::1]'].includes(url.hostname))){if(['GET','HEAD'].includes(request.method)){url.protocol='https:';response=Response.redirect(url,308);}else problem('SECURE_CONNECTION_REQUIRED');}
    else if(sensitivePath(url.pathname))problem('NOT_FOUND',404);
    else if(url.pathname.startsWith('/api/')){
      if((origin!==null&&origin!==url.origin)||request.headers.get('Sec-Fetch-Site')==='cross-site')problem('FORBIDDEN',403);
      if(request.method==='OPTIONS'){
        const method=request.headers.get('Access-Control-Request-Method'),requested=request.headers.get('Access-Control-Request-Headers')?.toLowerCase().split(',').map(x=>x.trim()).filter(Boolean)??[];
        if(origin!==url.origin||!['GET','POST'].includes(method)||requested.some(x=>!['authorization','content-type'].includes(x)))problem('FORBIDDEN',403);
        response=new Response(null,{status:204,headers:{'Access-Control-Allow-Origin':origin,'Access-Control-Allow-Methods':'GET, POST','Access-Control-Allow-Headers':'Authorization, Content-Type','Access-Control-Max-Age':'600','Vary':'Origin'}});
      }else{
        if(!['GET','POST'].includes(request.method))problem('METHOD_NOT_ALLOWED',405);
        if(Number(request.headers.get('Content-Length'))>1100000)problem('PAYLOAD_TOO_LARGE',413);
        if(env.DB)await new RequestLimiter(env.DB).hit('api-ip',request.headers.get('CF-Connecting-IP')??'unknown',300);
        response=await handle(request,env);
        if(origin){const h=new Headers(response.headers);h.set('Access-Control-Allow-Origin',origin);h.set('Vary','Origin');response=new Response(response.body,{status:response.status,headers:h});}
      }
    }else{if(!['GET','HEAD'].includes(request.method))problem('METHOD_NOT_ALLOWED',405);response=await handle(request,env);}
  }catch(error){response=safeFailure(error,request);}
  return protectResponse(response,request);
}
