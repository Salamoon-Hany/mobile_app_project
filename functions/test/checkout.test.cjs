'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {checkoutUrl, initializeCheckout, resolveCheckout} = require('../checkout');

function store(status = 'CREATING') {
  const data = {status};
  const db = {runTransaction: action => action({
    get: async () => ({exists: true, data: () => ({...data})}),
    update: (_ref, patch) => Object.assign(data, patch),
  })};
  return {db, ref: {}, data};
}
test('checkout response accepts only HTTPS provider URLs', () => {
  assert.equal(checkoutUrl('"https://atfawry.com/pay/123"'), 'https://atfawry.com/pay/123');
  for (const url of ['http://atfawry.com/pay', 'https://atfawry.com.evil.invalid/pay', 'javascript:alert(1)', 'broken']) {
    assert.throws(() => checkoutUrl(url));
  }
});
test('provider timeout preserves the reference for explicit reconciliation', async () => {
  const s = store(); let calls = 0;
  const result = await initializeCheckout({...s, host: 'https://provider.invalid', body: {}, fetchImpl: async () => {
    calls++; throw new Error('timeout');
  }});
  assert.equal(calls, 1);
  assert.equal(result.checkoutUrl, null);
  assert.equal(s.data.status, 'RECONCILIATION_REQUIRED');
});
test('checkout creation stores the URL; a late provider error cannot undo PAID', async () => {
  const s = store();
  const result = await initializeCheckout({...s, host: 'https://provider.invalid', body: {}, fetchImpl: async () => ({ok:true, text:async ()=>'https://atfawry.com/pay/123'})});
  assert.equal(s.data.status, 'PENDING');
  assert.equal(result.checkoutUrl, s.data.checkoutUrl);
  const paid = store('PAID');
  await initializeCheckout({...paid, host: 'https://provider.invalid', body: {}, fetchImpl: async () => ({ok:false})});
  assert.equal(paid.data.status, 'PAID');
});
test('failed, invalid and interrupted responses become uncertain without false credit', async () => {
  for (const response of [{ok:false}, {ok:true, text:async ()=>'https://evil.invalid/pay'}, {ok:true, text:async () => {throw new Error('interrupted');}}]) {
    const s = store();
    await initializeCheckout({...s, host:'https://provider.invalid', body:{}, fetchImpl:async () => response});
    assert.equal(s.data.status, 'RECONCILIATION_REQUIRED');
    assert.equal(s.data.checkoutUrl, undefined);
  }
});
test('an interrupted CREATING request becomes actionable after the grace period', async () => {
  const s = store();
  s.data.createdAt = {toMillis: () => 1000};
  assert.equal((await resolveCheckout(s.db, s.ref, 2000)).status, 'CREATING');
  assert.equal((await resolveCheckout(s.db, s.ref, 32000)).status, 'RECONCILIATION_REQUIRED');
  const paid = store('PAID');
  assert.equal((await resolveCheckout(paid.db, paid.ref, 32000)).status, 'PAID');
});
