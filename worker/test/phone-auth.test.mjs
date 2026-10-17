import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createPhoneHandler} from '../phone-auth.mjs';

function setup(overrides={}) {
  const user={localId:'same-uid',email:'person@example.com',emailVerified:true,phoneNumber:'+201012345678',...overrides};
  const accounts=new Map(); const counts=new Map();
  const repo={async save(value){accounts.set(value.phoneNumber,{uid:value.localId,email:value.email});},async find(phone){return accounts.get(phone);},async limit(key,max){const count=(counts.get(key)??0)+1;counts.set(key,count);return count<=max;}};
  const firebase=async (url,request)=>{
    const data=JSON.parse(request.body);
    if(url.includes('signInWithPassword'))return data.password==='correct password' ? Response.json({idToken:'login-token'}) : Response.json({error:'INVALID_LOGIN_CREDENTIALS'},{status:400});
    if(data.idToken!=='owner-token'&&data.idToken!=='login-token')return Response.json({error:'INVALID_ID_TOKEN'},{status:400});
    return Response.json({users:[user]});
  };
  const handler=createPhoneHandler({repository:repo,apiKey:'test',fetchImpl:firebase});
  const request=(path,body={},token)=>new Request('https://sanad.test/api/auth/phone/'+path,{method:'POST',headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},body:JSON.stringify(body)});
  return {user,accounts,handler,request};
}

test('only a Firebase-proven verified account can register its phone',async()=>{
  const {handler,request,accounts}=setup();
  assert.equal((await handler(request('register',{phone:'+201099999999'},'owner-token'))).status,200);
  assert.equal(accounts.get('+201012345678').uid,'same-uid');
  assert.equal(accounts.has('+201099999999'),false);
});
test('registration rejects missing/invalid tokens and unverified email',async()=>{
  for(const token of [undefined,'wrong']){const {handler,request}=setup();assert.equal((await handler(request('register',{},token))).status,401);}
  const {handler,request}=setup({emailVerified:false});assert.equal((await handler(request('register',{},'owner-token'))).status,401);
});
test('phone password login is unavailable even for a verified profile number',async()=>{
 const {handler,request}=setup();await handler(request('register',{},'owner-token'));
 assert.equal((await handler(request('login',{phone:'+201012345678',password:'correct password'}))).status,404);
});
test('email and password remain the supported login identifiers',async()=>{
 const {handler}=setup();const response=await handler(new Request('https://sanad.test/api/auth/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({identifier:'person@example.com',password:'correct password'})}));
 assert.equal(response.status,200);assert.deepEqual(await response.json(),{email:'person@example.com',uid:'same-uid'});
});
test('cross-origin calls and malformed phone requests are rejected',async()=>{
  const {handler,request}=setup();const r=request('login',{phone:'+201012345678',password:'wrong'});r.headers.set('Origin','https://other.test');
  assert.equal((await handler(r)).status,403);
  assert.equal((await handler(request('login',{phone:'not-a-number',password:'x'}))).status,404);
});
