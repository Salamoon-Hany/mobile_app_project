'use strict';
const {createHash,timingSafeEqual} = require('node:crypto');
function quote(amountPiasters) {
  if (!Number.isSafeInteger(amountPiasters) || amountPiasters < 1000 || amountPiasters > 100000000) throw new Error('INVALID_AMOUNT');
  const feePiasters = Math.floor((amountPiasters*2+50)/100);
  return {amountPiasters,feePiasters,totalPiasters:amountPiasters+feePiasters};
}
const money = p => (p/100).toFixed(2);
function asPiasters(value) {
  if (!['string','number'].includes(typeof value) || !/^\d{1,10}(\.\d{1,2})?$/.test(String(value))) throw new Error('INVALID_MONEY');
  const [whole,fraction=''] = String(value).split('.');
  return Number(whole)*100 + Number(fraction.padEnd(2,'0'));
}
const sha256 = s => createHash('sha256').update(s).digest('hex');
function chargeSignature(r,key) {
  return sha256(r.merchantCode+r.merchantRefNum+(r.customerProfileId??'')+r.returnUrl+
    [...r.chargeItems].sort((a,b)=>a.itemId.localeCompare(b.itemId)).map(x=>x.itemId+x.quantity+Number(x.price).toFixed(2)).join('')+key);
}
function notificationSignature(e,key) {
  // Exact documented V2 spelling: paymentRefrenceNumber.
  return sha256(e.fawryRefNumber+e.merchantRefNumber+money(asPiasters(e.paymentAmount))+money(asPiasters(e.orderAmount))+e.orderStatus+e.paymentMethod+(e.paymentRefrenceNumber??'')+key);
}
function verifyNotification(e,key) {
  if (!key || typeof e?.messageSignature !== 'string' || !/^[a-f0-9]{64}$/i.test(e.messageSignature) ||
      !['fawryRefNumber','merchantRefNumber','orderStatus','paymentMethod'].every(k=>typeof e[k]==='string'&&e[k].length>0&&e[k].length<=150)) return false;
  try { return timingSafeEqual(Buffer.from(notificationSignature(e,key),'hex'),Buffer.from(e.messageSignature,'hex')); } catch (_) { return false; }
}
function assertPaymentMatches(d,e) {
  if (asPiasters(e.orderAmount)!==d.totalPiasters || (e.orderStatus==='PAID'&&asPiasters(e.paymentAmount)<d.totalPiasters) || e.paymentMethod.toUpperCase()!==d.method.toUpperCase()) throw new Error('PAYMENT_MISMATCH');
}
function receiptMessage(d) {
  return {subject:`${d.mode==='live'?'':'[TEST] '}Deposit confirmed — EGP ${money(d.amountPiasters)}`,
    text:`${d.mode==='live'?'':'TEST PAYMENT — not real money\n\n'}An amount of EGP ${money(d.amountPiasters)} has been deposited into your Salamoon Services account.\nPayment method: ${d.method}\nService fee (2%): EGP ${money(d.feePiasters)}\nTotal: EGP ${money(d.totalPiasters)}\nReference: ${d.id}`};
}
module.exports={quote,money,asPiasters,chargeSignature,notificationSignature,verifyNotification,assertPaymentMatches,receiptMessage};
