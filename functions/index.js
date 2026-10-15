'use strict';
const {onRequest}=require('firebase-functions/v2/https');
const {defineSecret,defineString}=require('firebase-functions/params');
const {initializeApp}=require('firebase-admin/app');
const {getAuth}=require('firebase-admin/auth');
const {getFirestore,FieldValue}=require('firebase-admin/firestore');
const {createHash}=require('node:crypto');
const {quote,money,chargeSignature,verifyNotification}=require('./wallet-core');
const {settleDeposit}=require('./wallet-store');
const {initializeCheckout,resolveCheckout}=require('./checkout');
initializeApp();
const key=defineSecret('FAWRY_SECURE_KEY');
const merchant=defineString('FAWRY_MERCHANT_CODE',{default:''});
const environment=defineString('FAWRY_ENVIRONMENT',{default:'staging'});
const mailEnabled=defineString('RECEIPT_EMAIL_ENABLED',{default:'false'});
const returnUrl=defineString('WALLET_RETURN_URL',{default:'https://eslam-mobile-service-app.eslam-hanyram11.chatgpt.site/'});
exports.walletApi=onRequest({region:'europe-west1',secrets:[key],maxInstances:3,cors:[
  'https://eslam-mobile-service-app.eslam-hanyram11.chatgpt.site',/^http:\/\/localhost(:\d+)?$/,
]},async(req,res)=>{
  res.set('Cache-Control','no-store');
  const db=getFirestore(), mode=environment.value();
  const collection=mode==='live'?'walletDeposits':'testWalletDeposits';
  const path=req.path.replace(/\/+$/,'');
  try {
    if (!['staging','live'].includes(mode)||!merchant.value()||!key.value()||mailEnabled.value()!=='true') return res.status(503).json({error:'PAYMENTS_NOT_CONFIGURED'});
    if (path==='/webhook'&&req.method==='POST') {
      if (!verifyNotification(req.body,key.value())) return res.status(403).json({error:'INVALID_SIGNATURE'});
      if (!/^[a-f0-9]{16}_[a-f0-9]{32}$/.test(req.body.merchantRefNumber)) return res.status(400).json({error:'INVALID_REFERENCE'});
      await settleDeposit(db,collection,req.body); return res.status(200).send('');
    }
    const bearer=req.get('Authorization')?.match(/^Bearer (.+)$/)?.[1];
    if (!bearer) return res.status(401).json({error:'SIGN_IN_REQUIRED'});
    let token; try {token=await getAuth().verifyIdToken(bearer,true);} catch(_){return res.status(401).json({error:'INVALID_SESSION'});}
    if (!token.email_verified||!token.email||token.firebase?.sign_in_provider==='anonymous') return res.status(403).json({error:'VERIFIED_EMAIL_REQUIRED'});
    const walletRef=db.collection(mode==='live'?'wallets':'testWallets').doc(token.uid);
    if (path==='/balance'&&req.method==='GET') return res.json({balancePiasters:(await walletRef.get()).data()?.balancePiasters??0,mode});
    if (path.startsWith('/deposit/')&&req.method==='GET') {
      const id=path.slice('/deposit/'.length);
      if (!/^[a-f0-9]{16}_[a-f0-9]{32}$/.test(id)) return res.status(400).json({error:'INVALID_REFERENCE'});
      const snap=await db.collection(collection).doc(id).get();
      if (!snap.exists||snap.data().uid!==token.uid) return res.status(404).json({error:'NOT_FOUND'});
      const deposit = await resolveCheckout(db,snap.ref);
      const [wallet,mail]=await Promise.all([walletRef.get(),db.collection('mail').doc(id).get()]);
      return res.json({id,status:deposit.status,checkoutUrl:deposit.checkoutUrl??null,balancePiasters:wallet.data()?.balancePiasters??0,mode,emailStatus:mail.data()?.delivery?.state??(mail.exists?'queued':'not-sent')});
    }
    if (path!=='/deposit'||req.method!=='POST') return res.status(404).json({error:'NOT_FOUND'});
    if (!req.body || typeof req.body !== 'object' || Array.isArray(req.body)) return res.status(400).json({error:'INVALID_REQUEST'});
    const q=quote(req.body.amountPiasters),method=req.body.method,requestId=req.body.requestId;
    if (!['CARD','MWALLET','PayAtFawry'].includes(method)||typeof requestId!=='string'||!/^[a-f0-9]{32}$/.test(requestId)) return res.status(400).json({error:'INVALID_REQUEST'});
    const url=new URL(returnUrl.value()); if(url.protocol!=='https:')throw new Error('INVALID_CONFIGURATION');
    const id=createHash('sha256').update(token.uid).digest('hex').slice(0,16)+'_'+requestId;
    const ref=db.collection(collection).doc(id);
    const deposit={id,uid:token.uid,email:token.email,method,mode,...q,status:'CREATING',createdAt:FieldValue.serverTimestamp()};
    const existing=await db.runTransaction(async tx=>{
      const snap=await tx.get(ref);
      if (snap.exists) {if(snap.data().amountPiasters!==q.amountPiasters||snap.data().method!==method)throw new Error('IDEMPOTENCY_CONFLICT');return snap.data();}
      const limiter=db.collection('_walletLimits').doc(token.uid),previous=await tx.get(limiter),minute=Math.floor(Date.now()/60000);
      const count=previous.data()?.minute===minute?previous.data().count:0;
      if (count>=6)throw new Error('RATE_LIMIT');
      tx.set(limiter,{minute,count:count+1});tx.create(ref,deposit);return null;
    });
    if (existing) {
      const recovered = await resolveCheckout(db,ref);
      return res.json({id,checkoutUrl:recovered.checkoutUrl??null,status:recovered.status,mode});
    }
    const body={merchantCode:merchant.value(),merchantRefNum:id,customerEmail:token.email,language:'en-gb',returnUrl:url.href,paymentMethod:method,authCaptureModePayment:false,
      chargeItems:[{itemId:'wallet-deposit',description:'Salamoon Services wallet deposit',quantity:1,price:Number(money(q.totalPiasters))}]};
    body.signature=chargeSignature(body,key.value());
    const host=mode==='live'?'https://atfawry.com':'https://atfawry.fawrystaging.com';
    const result = await initializeCheckout({db,ref,host,body});
    return res.json({id,...result,mode});
  }catch(error){
    const known=['INVALID_AMOUNT','IDEMPOTENCY_CONFLICT','PAYMENT_MISMATCH','INVALID_MONEY'];
    const status=error.message==='RATE_LIMIT'?429:known.includes(error.message)?400:500;
    return res.status(status).json({error:known.includes(error.message)||error.message==='RATE_LIMIT'?error.message:'PAYMENT_SERVICE_ERROR'});
  }
});
