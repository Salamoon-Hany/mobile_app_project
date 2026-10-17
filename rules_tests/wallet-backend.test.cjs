'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {createRequire}=require('node:module');
const backendRequire=createRequire(require.resolve('../functions/package.json'));
const {initializeApp,deleteApp}=backendRequire('firebase-admin/app');
const {getFirestore}=backendRequire('firebase-admin/firestore');
const {settleDeposit}=require('../functions/wallet-store');
const {quote}=require('../functions/wallet-core');
test('paid webhook credits once, queues one email and never credits pending/failed/underpaid',async()=>{
  const app=initializeApp({projectId:'demo-mobile-app'},`wallet-${Date.now()}`);
  const db=getFirestore(app), id=`wallet-test-${Date.now()}`,uid=`wallet-user-${Date.now()}`;
  const deposit={...quote(10000),id,uid,email:'wallet@example.invalid',method:'CARD',mode:'staging',status:'CREATING'};
  const ref=db.collection('testWalletDeposits').doc(id);
  await ref.set(deposit);
  const event={merchantRefNumber:id,fawryRefNumber:'1234',orderAmount:102,paymentAmount:102,paymentMethod:'CARD',orderStatus:'NEW'};
  try{
    await settleDeposit(db,'testWalletDeposits',event);
    assert.equal((await db.collection('testWallets').doc(uid).get()).exists,false);
    await settleDeposit(db,'testWalletDeposits',{...event,orderStatus:'FAILED'});
    assert.equal((await db.collection('testWallets').doc(uid).get()).exists,false);
    await assert.rejects(settleDeposit(db,'testWalletDeposits',{...event,orderStatus:'PAID',paymentAmount:100}));
    const paid={...event,orderStatus:'PAID'};
    await Promise.all([settleDeposit(db,'testWalletDeposits',paid),settleDeposit(db,'testWalletDeposits',paid)]);
    assert.equal((await db.collection('testWallets').doc(uid).get()).data().balancePiasters,10000);
    const mail=await db.collection('mail').doc(id).get();
    assert.equal(mail.data().to,'wallet@example.invalid');
    assert.match(mail.data().message.text,/Service fee \(2%\): EGP 2.00/);
    assert.equal((await db.collection('wallets').doc(uid).get()).exists,false);
    await settleDeposit(db,'testWalletDeposits',{...event,orderStatus:'NEW'});
    assert.equal((await ref.get()).data().status,'PAID');
  }finally{await deleteApp(app);}
});
