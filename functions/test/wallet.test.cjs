'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {quote,notificationSignature,verifyNotification,assertPaymentMatches,chargeSignature,receiptMessage}=require('../wallet-core');
const {createHash}=require('node:crypto');
test('integer money validation, boundary and 1% rounding',()=>{
  for(const amount of [0,-1,999,1000.1,NaN,Infinity,'1000',100000001])assert.throws(()=>quote(amount));
  assert.deepEqual(quote(10000),{amountPiasters:10000,feePiasters:100,totalPiasters:10100});
  assert.equal(quote(1050).feePiasters,11);
});
test('charge signature sorts items and signs total with two decimals',()=>{
  const r={merchantCode:'merchant',merchantRefNum:'ref',returnUrl:'https://app.invalid',chargeItems:[{itemId:'b',quantity:1,price:100},{itemId:'a',quantity:1,price:1}]};
  assert.equal(chargeSignature(r,'key'),createHash('sha256').update('merchantrefhttps://app.invalida11.00b1100.00key').digest('hex'));
});
test('signed paid amount/method must match; altered callbacks are denied',()=>{
  const deposit={...quote(10000),id:'order',method:'CARD',mode:'live'};
  const event={fawryRefNumber:'fawry',merchantRefNumber:'order',paymentAmount:101,orderAmount:101,orderStatus:'PAID',paymentMethod:'CARD',paymentRefrenceNumber:'bank'};
  event.messageSignature=notificationSignature(event,'test-secret');
  assert.equal(verifyNotification(event,'test-secret'),true);
  assert.equal(verifyNotification({...event,paymentAmount:100},'test-secret'),false);
  assert.equal(verifyNotification({...event,messageSignature:'broken'},'test-secret'),false);
  assert.equal(verifyNotification(event,''),false);
  assertPaymentMatches(deposit,event);
  assert.throws(()=>assertPaymentMatches(deposit,{...event,orderAmount:100}));
  assert.throws(()=>assertPaymentMatches(deposit,{...event,paymentMethod:'MWALLET'}));
  assert.match(receiptMessage(deposit).text,/EGP 100.00/);
  assert.match(receiptMessage({...deposit,mode:'staging'}).subject,/\[TEST\]/);
});
