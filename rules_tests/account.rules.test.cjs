'use strict';
const { test, before, after } = require('node:test');
const { readFileSync } = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, collection, getDocs, serverTimestamp } = require('firebase/firestore');
let env;
before(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-mobile-app', firestore: {
    host: '127.0.0.1', port: 8080, rules: readFileSync('../firestore.rules', 'utf8')
  }});
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/u1'), { uid: 'u1', name: 'First', gender: '', createdAt: 1 });
    await setDoc(doc(ctx.firestore(), 'users/u2'), { uid: 'u2', name: 'Second', gender: '', createdAt: 2 });
    await setDoc(doc(ctx.firestore(), '_emailOtp/private'), { codeHash: 'secret' });
  });
});
after(async () => { await env?.cleanup(); });
const emailUser = () => env.authenticatedContext('u1', { email_verified: true, email: 'first@example.com' }).firestore();
test('guests and unverified users cannot read profiles', async () => {
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'users/u1')));
  await assertFails(getDoc(doc(env.authenticatedContext('u1').firestore(), 'users/u1')));
});
test('verified email owners can read their profile; phone-only users are denied', async () => {
  await assertSucceeds(getDoc(doc(emailUser(), 'users/u1')));
  await assertFails(getDoc(doc(env.authenticatedContext('u2', { phone_number: '+201112345678' }).firestore(), 'users/u2')));
  await assertFails(getDoc(doc(emailUser(), 'users/u2')));
  await assertFails(getDocs(collection(emailUser(), 'users')));
});
test('own name and gender can be saved, while identity fields stay server-owned', async () => {
  await assertSucceeds(updateDoc(doc(emailUser(), 'users/u1'), { name: 'Updated', gender: 'Male', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(emailUser(), 'users/u1'), { uid: 'u2' }));
  await assertFails(updateDoc(doc(emailUser(), 'users/u2'), { name: 'Overwrite', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(emailUser(), 'users/u1'), { name: '', updatedAt: serverTimestamp() }));
});
test('clients cannot create other profiles or read private data', async () => {
  const db = emailUser();
  await assertFails(setDoc(doc(db, 'users/u3'), { uid: 'u3', name: 'Intruder', gender: '' }));
  await assertFails(getDoc(doc(db, '_emailOtp/private')));
  await assertFails(setDoc(doc(db, '_otpLimits/tamper'), { count: 0 }));
});

test('verified owners can create only a valid own profile without privileges', async () => {
  const db = env.authenticatedContext('new', {email_verified: true, email: 'new@example.com'}).firestore();
  const ref = doc(db, 'users/new');
  const profile = {uid: 'new', name: 'Student', gender: '', createdAt: serverTimestamp()};
  await assertFails(setDoc(ref, {...profile, role: 'admin'}));
  await assertFails(setDoc(ref, {...profile, uid: 'u1'}));
  await assertFails(setDoc(ref, {...profile, createdAt: 1}));
  await assertSucceeds(setDoc(ref, profile));
  await assertFails(updateDoc(ref, {role: 'admin', updatedAt: serverTimestamp()}));
  const unverified = env.authenticatedContext('unverified', {email: 'pending@example.com'}).firestore();
  await assertFails(setDoc(doc(unverified, 'users/unverified'), {...profile, uid: 'unverified'}));
});

test('wallets are private and clients cannot credit money or queue receipt emails', async () => {
  await env.withSecurityRulesDisabled(async ctx => {
    await setDoc(doc(ctx.firestore(),'wallets/u1'),{uid:'u1',balancePiasters:10000});
  });
  const db=emailUser();
  await assertSucceeds(getDoc(doc(db,'wallets/u1')));
  await assertFails(getDoc(doc(env.authenticatedContext('u2',{email_verified:true,email:'other@example.com'}).firestore(),'wallets/u1')));
  await assertFails(updateDoc(doc(db,'wallets/u1'),{balancePiasters:999999}));
  await assertFails(setDoc(doc(db,'wallets/u2'),{uid:'u2',balancePiasters:10000}));
  await assertFails(setDoc(doc(db,'testWallets/u1'),{uid:'u1',balancePiasters:10000}));
  await assertFails(setDoc(doc(db,'mail/client-receipt'),{to:'victim@example.com',message:{text:'fake'}}));
  await assertFails(getDocs(collection(db,'wallets')));
});
