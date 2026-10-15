'use strict';
const {FieldValue} = require('firebase-admin/firestore');

function checkoutUrl(raw) {
  let result;
  try { result = JSON.parse(raw); } catch (_) { result = raw.trim(); }
  const url = new URL(typeof result === 'string' ? result : result?.url ?? result?.redirectUrl);
  if (url.protocol !== 'https:' || !['atfawry.com', 'www.atfawry.com', 'atfawry.fawrystaging.com'].includes(url.hostname)) {
    throw new Error('INVALID_CHECKOUT_RESPONSE');
  }
  return url.href;
}

/// An uncertain provider request is never retried with a fresh reference.
/// A signed callback or merchant reconciliation can finish the same deposit.
async function initializeCheckout({db, ref, host, body, fetchImpl = fetch}) {
  const update = patch => db.runTransaction(async tx => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new Error('UNKNOWN_DEPOSIT');
    const status = snap.data().status;
    if (patch.checkoutUrl) {
      tx.update(ref, {...patch, ...(status === 'CREATING' ? {status: 'PENDING'} : {}), updatedAt: FieldValue.serverTimestamp()});
    } else if (status === 'CREATING') {
      tx.update(ref, {...patch, updatedAt: FieldValue.serverTimestamp()});
    }
  });
  try {
    const response = await fetchImpl(`${host}/fawrypay-api/api/payments/init`, {
      method: 'POST', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify(body), signal: AbortSignal.timeout(20000),
    });
    if (!response.ok) throw new Error('PAYMENT_PROVIDER_UNAVAILABLE');
    const url = checkoutUrl(await response.text());
    await update({checkoutUrl: url});
    return {checkoutUrl: url, status: 'PENDING'};
  } catch (_) {
    // A timeout does not prove that no order/charge was created at the provider.
    await update({status: 'RECONCILIATION_REQUIRED'});
    return {checkoutUrl: null, status: 'RECONCILIATION_REQUIRED'};
  }
}
async function resolveCheckout(db, ref, now = Date.now()) {
  return db.runTransaction(async tx => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new Error('UNKNOWN_DEPOSIT');
    const data = snap.data();
    const createdAt = data.createdAt?.toMillis?.() ?? 0;
    // Also recover an invocation that crashed before its catch block ran.
    if (data.status === 'CREATING' && !data.checkoutUrl && now - createdAt > 30000) {
      const patch = {status: 'RECONCILIATION_REQUIRED', updatedAt: FieldValue.serverTimestamp()};
      tx.update(ref, patch);
      return {...data, ...patch};
    }
    return data;
  });
}
module.exports = {checkoutUrl, initializeCheckout, resolveCheckout};
