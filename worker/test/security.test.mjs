import {test} from 'node:test';
import assert from 'node:assert/strict';
import {perimeter,readJson,safeFailure,assertPublicOutput,RequestLimiter,sensitivePath} from '../security.mjs';
import {validatedPhoto} from '../photo-validation.mjs';
import {createMarketplaceHandler} from '../marketplace.mjs';
import {createPhoneHandler,PhoneRepository} from '../phone-auth.mjs';
import {ServiceExperience} from '../service-experience.mjs';
import {setup,fixture,order} from './fixture.mjs';
const base='https://sanad.test';
const req=(path,body,headers={})=>new Request(base+path,{method:body===undefined?'GET':'POST',headers:{...(body===undefined?{}:{'Content-Type':'application/json'}),...headers},...(body===undefined?{}:{body:JSON.stringify(body)})});
const ok=async()=>Response.json({ok:true});
const photo='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1sAAAAASUVORK5CYII=';
test('security headers apply to HTML, APIs and errors, without a public cache',async()=>{
 for(const [path,callback] of [['/',()=>new Response('<html></html>',{headers:{'Content-Type':'text/html'}})],['/api/data',ok],['/api/error',()=>{throw Error('SQL password=secret');}]]){
  const r=await perimeter(req(path),{},callback);assert.equal(r.headers.get('X-Content-Type-Options'),'nosniff');assert.equal(r.headers.get('Strict-Transport-Security'),'max-age=31536000');assert.match(r.headers.get('Content-Security-Policy'),/object-src 'none'/);assert.match(r.headers.get('Permissions-Policy'),/camera=\(self\)/);if(path.startsWith('/api'))assert.equal(r.headers.get('Cache-Control'),'no-store');assert.ok(!(await r.text()).includes('password=secret'));
 }
});
test('strict CORS rejects null, hostile and cross-site origins and arbitrary preflight headers',async()=>{
 for(const headers of [{Origin:'https://evil.test'},{Origin:'null'},{'Sec-Fetch-Site':'cross-site'}])assert.equal((await perimeter(req('/api/x',{},headers),{},ok)).status,403);
 const pre=(origin,headers='authorization, content-type',method='POST')=>new Request(base+'/api/x',{method:'OPTIONS',headers:{Origin:origin,'Access-Control-Request-Method':method,'Access-Control-Request-Headers':headers}});
 const allowed=await perimeter(pre(base),{},ok);assert.equal(allowed.status,204);assert.equal(allowed.headers.get('Access-Control-Allow-Origin'),base);assert.equal(allowed.headers.get('Access-Control-Allow-Credentials'),null);
 for(const r of [pre('https://evil.test'),pre(base,'x-admin'),pre(base,'authorization','DELETE')])assert.equal((await perimeter(r,{},ok)).status,403);
});
test('HTTP reads redirect to HTTPS; HTTP passwords are rejected, never forwarded',async()=>{
 let invoked=false;const callback=()=>{invoked=true;return ok();};
 const read=await perimeter(new Request('http://sanad.test/'),{},callback);assert.equal(read.status,308);assert.equal(read.headers.get('Location'),base+'/');
 assert.equal((await perimeter(new Request('http://sanad.test/api/auth/login',{method:'POST',body:'password=secret'}),{},callback)).status,400);assert.equal(invoked,false);
});
test('source files, dot files, traversal and directories never reach SPA fallback',async()=>{
 for(const path of ['/.env','/.git/config','/worker/index.js','/drizzle/0000.sql','/package.json','/pubspec.yaml','/assets/','/main.dart.js.map','/%252eenv','/assets%5c..%5c.env']){let served=false;const response=await perimeter(req(path),{},async()=>{served=true;return ok();});assert.equal(response.status,404,path);assert.equal(served,false,path);}
 assert.equal(sensitivePath('/assets/images/service.png'),false);
 assert.equal((await perimeter(new Request(base+'/normal',{method:'DELETE'}),{},ok)).status,405);
});
test('JSON reads enforce exact MIME, UTF-8, object shape, depth and byte limits',async()=>{
 for(const body of ['null','[]','{"constructor":{}}','{"__proto__":{"admin":true}}','{"n":1e400}',JSON.stringify({nested:Array(14).fill(0).reduce(a=>({a}),{})})])await assert.rejects(readJson(new Request(base,{method:'POST',headers:{'Content-Type':'application/json'},body})),/INVALID_REQUEST/);
 await assert.rejects(readJson(new Request(base,{method:'POST',headers:{'Content-Type':'application/jsonp'},body:'{}'})),/UNSUPPORTED_MEDIA_TYPE/);
 await assert.rejects(readJson(new Request(base,{method:'POST',headers:{'Content-Type':'application/json'},body:new Uint8Array([0xff])})),/INVALID_REQUEST/);
 const stream=new ReadableStream({start(c){c.enqueue(new Uint8Array(20));c.enqueue(new Uint8Array(20));c.close();}});
 await assert.rejects(readJson(new Request(base,{method:'POST',duplex:'half',headers:{'Content-Type':'application/json'},body:stream}),30),/PAYLOAD_TOO_LARGE/);
 assert.deepEqual(await readJson(req('/',{name:'أحمد'})),{name:'أحمد'});
});
test('error logs contain a reference, never body, token, raw error, SQL or query strings',async()=>{
 const logs=[],request=req('/api/auth/login?email=private@example.com',{password:'secret'},{Authorization:'Bearer private-token'});
 const response=safeFailure(Object.assign(Error('SELECT private FROM database password=secret'),{status:400}),request,{error:x=>logs.push(x)});
 assert.equal(response.status,503);const body=await response.json();assert.equal(body.error,'TEMPORARILY_UNAVAILABLE');assert.ok(body.requestId);const text=JSON.stringify({logs,body});for(const secret of ['private','secret','SELECT','database'])assert.ok(!text.includes(secret));
});
test('output boundary rejects accidental tokens and invalid numeric values',()=>{
 for(const value of [{idToken:'secret'},{nested:{password:'secret'}},{amount:Infinity}])assert.throws(()=>assertPublicOutput(value));assertPublicOutput({balance:12500,name:'أحمد',list:[null,1]});
});
test('rate limiting is durable, atomic, hashed, scoped and expires',async()=>{
 const {repo,sql}=setup();let now=900001;const a=new RequestLimiter(repo.db,()=>now),b=new RequestLimiter(repo.db,()=>now);
 const results=await Promise.allSettled(Array.from({length:9},(_,i)=>(i%2?a:b).hit('login','private@example.com',5,900000)));assert.equal(results.filter(x=>x.status==='fulfilled').length,5);assert.ok(results.filter(x=>x.status==='rejected').every(x=>x.reason.status===429&&x.reason.retryAfter>0));assert.ok(!JSON.stringify(sql.prepare('SELECT * FROM security_rate_limits').all()).includes('private@example.com'));await a.hit('other','private@example.com',5);now+=900000;await b.hit('login','private@example.com',5,900000);await b.clear('login','private@example.com');await a.hit('login','private@example.com',5,900000);sql.close();
});
function auth(repo,uid='c',extra={}){return createMarketplaceHandler({repository:repo,apiKey:'isolated',...extra,fetchImpl:async()=>Response.json({users:[{localId:uid,email:uid+'@example.com',emailVerified:true,createdAt:'1792000000000',lastLoginAt:String(Date.now())}]})});}
const api=(path,body,token='isolated-token')=>req('/api/marketplace'+path,body,{Authorization:'Bearer '+token});
test('HTTP legacy imports cannot mint money or impersonate a UID',async()=>{
 const {repo,sql}=setup(),handler=auth(repo,'new-customer');const response=await handler(api('/bootstrap',{name:'Customer',role:'customer',uid:'victim',hasLegacy:true,legacyBalance:99999999,legacyOrders:[{id:'old',password:'must-never-persist',location:{latitude:30,longitude:31,label:'old area',token:'strip-this'}}]}));assert.equal(response.status,200);const state=await response.json();assert.equal(state.account.uid,'new-customer');assert.equal(state.account.legacy_orders[0].password,undefined);assert.equal(state.account.legacy_orders[0].location.token,undefined);assert.equal(state.account.balance,0);assert.equal(state.account.legacy_balance_claim,undefined);assert.equal(sql.prepare('SELECT legacy_balance_claim n FROM marketplace_accounts').get().n,99999999);assert.equal(await repo.account('victim'),undefined);await repo.deposit('new-customer',{requestId:'trusted_seed',amount:1000,method:'visa'});await handler(api('/bootstrap',{name:'Customer',hasLegacy:true,legacyBalance:99999999}));assert.equal((await repo.account('new-customer')).balance,1000);sql.close();
});
test('mock funding is disabled by default and can be explicitly enabled without duplicate credit',async()=>{
 const {repo,sql}=await fixture(),body={requestId:'deposit_security',amount:1000,method:'visa'};assert.equal((await auth(repo)(api('/deposit',body))).status,503);const handler=auth(repo,'c',{allowDemoFunds:true});assert.equal((await handler(api('/deposit',body))).status,200);assert.equal((await handler(api('/deposit',body))).status,200);assert.equal((await repo.account('c')).balance,21000);sql.close();
});
test('API write limits survive handler recreation and apply per verified UID',async()=>{
 const {repo,sql}=await fixture();for(let i=0;i<30;i++)assert.equal((await auth(repo,'c',{limiterEnabled:true})(api('/rating',{stars:4,uid:'other'}))).status,200);
 const limited=await auth(repo,'c',{limiterEnabled:true})(api('/rating',{stars:5}));assert.equal(limited.status,429);assert.ok(Number(limited.headers.get('Retry-After'))>0);assert.equal((await repo.customerSettings('c')).rating.stars,4);assert.equal((await repo.snapshot('other')).rating,null);sql.close();
});
test('SQL injection and inherited decision names cannot bypass order ownership or mutate balances',async()=>{
 const {repo,sql}=await fixture(),id=await repo.createOrder('c',order());await assert.rejects(repo.decide('w',id,'toString'),/INVALID_REQUEST/);await assert.rejects(repo.decide("c' OR 1=1 --",id,'complete'),/ACCOUNT_REQUIRED/);await assert.rejects(repo.orderPhoto('other',"' OR 1=1 --"),/NOT_FOUND/);assert.equal((await repo.account('c')).balance,12500);assert.equal((await repo.account('w')).balance,0);sql.close();
});
test('image validation rejects MIME spoofing, malformed containers and dimension bombs',()=>{
 assert.equal(validatedPhoto(photo),photo);for(const invalid of ['data:image/svg+xml;base64,PHN2Zz4=','data:image/png;base64,aGVsbG8=',photo.replace('image/png','image/jpeg'),photo.slice(0,-8)])assert.throws(()=>validatedPhoto(invalid));const b=Buffer.from(photo.split(',')[1],'base64');b.writeUInt32BE(65535,16);assert.throws(()=>validatedPhoto('data:image/png;base64,'+b.toString('base64')),/INVALID_PHOTO/);
});
test('concurrent conflicting chat IDs cannot silently overwrite or report two successful messages',async()=>{
 const {repo,sql}=await fixture(),ex=new ServiceExperience(repo),id=await repo.createOrder('c',order());const results=await Promise.allSettled(['one','two'].map(text=>ex.send('c',id,{requestId:'concurrent_chat',text})));assert.equal(results.filter(x=>x.status==='fulfilled').length,1);assert.equal((await ex.detail('w',id)).messages.length,1);sql.close();
});
test('concurrent conflicting extras preserve exactly one proposal and do not charge automatically',async()=>{
 const {repo,sql}=await fixture(),ex=new ServiceExperience(repo),id=await repo.createOrder('c',order());await repo.decide('w',id,'accept');const results=await Promise.allSettled([500,1000].map(amount=>ex.extra('w',id,{requestId:'concurrent_extra',amount,note:'New part'})));assert.equal(results.filter(x=>x.status==='fulfilled').length,1);assert.equal((await ex.detail('c',id)).extras.length,1);assert.equal((await repo.account('c')).balance,12500);sql.close();
});
test('email login limits incorrect attempts consistently across requests and handles provider quotas',async()=>{
 const {repo,sql}=setup();let current=1000,calls=0;const handler=createPhoneHandler({repository:new PhoneRepository(repo.db),apiKey:'test',now:()=>current,fetchImpl:async()=>{calls++;return Response.json({error:{message:'INVALID_LOGIN_CREDENTIALS'}},{status:400});}});
 const login=()=>req('/api/auth/login',{identifier:'User@Example.com',password:'wrong'});for(let i=0;i<5;i++)assert.equal((await handler(login())).status,401);assert.equal((await handler(login())).status,429);assert.equal(calls,5);current+=900000;assert.equal((await handler(login())).status,401);
 const quota=createPhoneHandler({repository:new PhoneRepository(repo.db),apiKey:'test',now:()=>current,fetchImpl:async()=>Response.json({error:{message:'TOO_MANY_ATTEMPTS_TRY_LATER'}},{status:400})});const r=await quota(req('/api/auth/login',{identifier:'other@example.com',password:'wrong'}));assert.equal(r.status,429);assert.equal(r.headers.get('Retry-After'),'900');sql.close();
});
test('email preflight authenticates an unverified new user without exposing provider tokens',async()=>{
 const {repo,sql}=setup();const handler=createPhoneHandler({repository:new PhoneRepository(repo.db),apiKey:'test',fetchImpl:async(url)=>Response.json(url.includes('lookup')?{users:[{localId:'new',email:'new@example.com',emailVerified:false}]}:{idToken:'private-token',refreshToken:'private-refresh'})});const r=await handler(req('/api/auth/login',{identifier:'new@example.com',password:'correct'}));assert.equal(r.status,200);assert.deepEqual(await r.json(),{uid:'new',email:'new@example.com'});sql.close();
});

test('identity provider outages are not reported as a wrong password',async()=>{
 const {repo,sql}=await fixture();
 const phone=createPhoneHandler({repository:new PhoneRepository(repo.db),apiKey:'isolated',fetchImpl:async()=>Response.json({error:{message:'API_KEY_INVALID'}},{status:400})});
 const response=await phone(req('/api/auth/login',{identifier:'test@example.invalid',password:'isolated'}));assert.equal(response.status,503);assert.equal((await response.json()).error,'TEMPORARILY_UNAVAILABLE');
 const apiHandler=createMarketplaceHandler({repository:repo,apiKey:'isolated',fetchImpl:async()=>new Response('private provider details',{status:503})});assert.equal((await apiHandler(api('/snapshot'))).status,503);sql.close();
});

import worker from '../index.js';
test('the HTML shell is served by the Worker with headers even when ASSETS would omit them',async()=>{
 let assetCalls=0;const env={ASSETS:{fetch:async()=>{assetCalls++;return new Response('unprotected asset');}}};
 for(const path of ['/','/index.html']){const r=await worker.fetch(req(path),env);assert.equal(r.status,200);assert.match(await r.text(),/SANAD/);assert.match(r.headers.get('Content-Security-Policy'),/object-src 'none'/);assert.equal(r.headers.get('Cache-Control'),'private, no-cache');}assert.equal(assetCalls,0);
});

test('public static URLs proxy through the header boundary without changing browser paths',async()=>{
 let seen;const env={ASSETS:{fetch:async request=>{seen=new URL(request.url);return new Response('self.runtimeReady=true',{headers:{'Content-Type':'text/javascript','Cache-Control':'public, max-age=0'}});}}};
 const r=await worker.fetch(req('/flutter_bootstrap.js?version=1'),env);assert.equal(seen.pathname,'/_sanad_static/flutter_bootstrap.js');assert.equal(seen.search,'?version=1');assert.equal(r.headers.get('X-Content-Type-Options'),'nosniff');assert.equal(r.headers.get('Cache-Control'),'private, no-cache');assert.equal(await r.text(),'self.runtimeReady=true');
});
