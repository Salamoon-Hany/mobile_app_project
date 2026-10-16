import {test} from 'node:test';
import assert from 'node:assert/strict';
import worker from '../index.js';
import {fixture,setup} from './fixture.mjs';

const base='https://sanad.test';
const request=(path,body,token)=>new Request(base+path,{
  method:body===undefined?'GET':'POST',
  headers:{...(body===undefined?{}:{'Content-Type':'application/json'}),...(token?{Authorization:'Bearer '+token}:{})},
  ...(body===undefined?{}:{body:JSON.stringify(body)}),
});
const user={localId:'c',email:'customer@example.test',emailVerified:true};
async function withFetch(fake,run){
  const original=globalThis.fetch;
  globalThis.fetch=fake;
  try{return await run();}finally{globalThis.fetch=original;}
}

test('server auth runtime configuration', {concurrency:false}, async t=>{
  await t.test('missing or blank server key fails closed without calling Firebase',async()=>{
    const {repo,sql}=setup();let calls=0;
    try{await withFetch(async()=>{calls++;throw Error('Firebase must not be called');},async()=>{
      for(const key of [undefined,null,'','  \t\n',123]){
        const env={DB:repo.db,FIREBASE_SERVER_API_KEY:key};
        for(const req of [request('/api/auth/login',{identifier:user.email,password:'test-password'}),request('/api/auth/phone/register',{},'test-token'),request('/api/marketplace/snapshot',undefined,'test-token')]){
          const response=await worker.fetch(req,env);
          assert.equal(response.status,503);
          assert.deepEqual(await response.json(),{error:'TEMPORARILY_UNAVAILABLE'});
          assert.equal(response.headers.get('Cache-Control'),'no-store');
        }
      }
      assert.equal(calls,0);
    });}finally{sql.close();}
  });

  await t.test('HTML, assets and unknown API paths remain available without auth configuration',async()=>{
    let assetCalls=0;
    for(const env of [{},{FIREBASE_SERVER_API_KEY:'server-test-key'}]){
      env.ASSETS={fetch:async req=>{assetCalls++;assert.equal(new URL(req.url).pathname,'/_sanad_static/flutter_bootstrap.js');return new Response('static-content',{headers:{'Content-Type':'text/javascript'}});}};
      for(const path of ['/','/index.html']){
        const response=await worker.fetch(request(path),env);assert.equal(response.status,200);assert.match(await response.text(),/SANAD/);
      }
      const asset=await worker.fetch(request('/flutter_bootstrap.js'),env);assert.equal(asset.status,200);assert.equal(await asset.text(),'static-content');
      const unknown=await worker.fetch(request('/api/unknown'),env);assert.equal(unknown.status,404);assert.deepEqual(await unknown.json(),{error:'NOT_FOUND'});
      const api=await worker.fetch(request('/api/marketplace/snapshot',undefined,'test-token'),env);assert.equal(api.status,503);
    }
    assert.equal(assetCalls,2);
  });

  await t.test('both password login and marketplace verification use only the runtime server key',async()=>{
    const {repo,sql}=await fixture();const calls=[];
    try{await withFetch(async(input,options)=>{
      const url=new URL(input),action=url.pathname.split(':')[1];
      assert.equal(url.origin,'https://identitytoolkit.googleapis.com');
      assert.equal(url.searchParams.get('key'),'server-test-key');
      calls.push({action,body:JSON.parse(options.body)});
      return Response.json(action==='signInWithPassword'?{idToken:'private-signed-token',refreshToken:'private-refresh-token'}:{users:[user]});
    },async()=>{
      const env={DB:repo.db,FIREBASE_SERVER_API_KEY:' server-test-key '};
      const login=await worker.fetch(request('/api/auth/login',{identifier:user.email,password:'test-password'}),env);
      assert.equal(login.status,200);assert.deepEqual(await login.json(),{email:user.email,uid:user.localId});
      const snapshot=await worker.fetch(request('/api/marketplace/snapshot',undefined,'private-marketplace-token'),env);
      assert.equal(snapshot.status,200);assert.equal((await snapshot.json()).account.uid,user.localId);
      assert.deepEqual(calls.map(x=>x.action),['signInWithPassword','lookup','lookup']);
      assert.equal(calls[1].body.idToken,'private-signed-token');
      assert.equal(calls[2].body.idToken,'private-marketplace-token');
    });}finally{sql.close();}
  });

  await t.test('rotating the server key recreates both handlers and invalidates cached verification',async()=>{
    const {repo,sql}=await fixture(),calls=[];const env={DB:repo.db,FIREBASE_SERVER_API_KEY:'first-server-test-key'};
    try{await withFetch(async input=>{
      const url=new URL(input),action=url.pathname.split(':')[1];calls.push({key:url.searchParams.get('key'),action});
      return Response.json(action==='signInWithPassword'?{idToken:'private-signed-token'}:{users:[user]});
    },async()=>{
      const snapshot=()=>worker.fetch(request('/api/marketplace/snapshot',undefined,'same-marketplace-token'),env);
      assert.equal((await snapshot()).status,200);assert.equal((await snapshot()).status,200);
      assert.deepEqual(calls,[{key:'first-server-test-key',action:'lookup'}]);
      env.FIREBASE_SERVER_API_KEY='second-server-test-key';
      assert.equal((await snapshot()).status,200);
      const login=await worker.fetch(request('/api/auth/login',{identifier:user.email,password:'test-password'}),env);assert.equal(login.status,200);
      assert.deepEqual(calls,[{key:'first-server-test-key',action:'lookup'},{key:'second-server-test-key',action:'lookup'},{key:'second-server-test-key',action:'signInWithPassword'},{key:'second-server-test-key',action:'lookup'}]);
      delete env.FIREBASE_SERVER_API_KEY;
      const disabled=await snapshot();assert.equal(disabled.status,503);assert.deepEqual(await disabled.json(),{error:'TEMPORARILY_UNAVAILABLE'});
      assert.equal(calls.length,4);
    });}finally{sql.close();}
  });
});
