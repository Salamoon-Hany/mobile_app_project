'use strict';
const {FieldValue} = require('firebase-admin/firestore');
const {assertPaymentMatches,receiptMessage} = require('./wallet-core');
async function settleDeposit(db,collection,event) {
  const ref=db.collection(collection).doc(event.merchantRefNumber);
  return db.runTransaction(async tx=>{
    const snap=await tx.get(ref);
    if (!snap.exists) throw new Error('UNKNOWN_DEPOSIT');
    const d=snap.data(); assertPaymentMatches(d,event);
    if (event.orderStatus!=='PAID') {
      if (event.orderStatus.includes('REFUND')) throw new Error('REFUND_REQUIRES_RECONCILIATION');
      if (d.status!=='PAID'&&['NEW','FAILED','CANCELED','EXPIRED'].includes(event.orderStatus)) tx.update(ref,{status:event.orderStatus,updatedAt:FieldValue.serverTimestamp()});
      return {credited:false};
    }
    if (d.status==='PAID') return {credited:false};
    const walletRef=db.collection(d.mode==='live'?'wallets':'testWallets').doc(d.uid);
    const wallet=await tx.get(walletRef);
    const previous=wallet.data()?.balancePiasters??0;
    if (!Number.isSafeInteger(previous)||previous<0) throw new Error('INVALID_BALANCE');
    tx.set(walletRef,{uid:d.uid,balancePiasters:previous+d.amountPiasters,updatedAt:FieldValue.serverTimestamp()});
    tx.update(ref,{status:'PAID',fawryRefNumber:event.fawryRefNumber,paidAt:FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp()});
    // Wallet credit and deterministic receipt outbox are one transaction.
    tx.create(db.collection('mail').doc(d.id),{to:d.email,message:receiptMessage(d)});
    return {credited:true};
  });
}
module.exports={settleDeposit};
