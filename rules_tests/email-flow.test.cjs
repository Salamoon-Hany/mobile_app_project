'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {initializeApp, deleteApp} = require('firebase/app');
const {getAuth, connectAuthEmulator, createUserWithEmailAndPassword, updateProfile, sendEmailVerification, applyActionCode, signOut, signInWithEmailAndPassword, sendPasswordResetEmail, confirmPasswordReset, PhoneAuthCredential, linkWithCredential} = require('firebase/auth');
const {getFirestore, connectFirestoreEmulator, doc, getDoc, setDoc, updateDoc, serverTimestamp} = require('firebase/firestore');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');

test('real emulator signup stays locked until email link verification; login/reset preserve identity', async () => {
  const projectId = 'demo-mobile-app';
  const env = await initializeTestEnvironment({projectId, firestore: {host:'127.0.0.1', port:8080, rules:readFileSync('../firestore.rules','utf8')}});
  const app = initializeApp({projectId, apiKey:'demo-key', authDomain:'demo-mobile-app.firebaseapp.com'}, `flow-${Date.now()}`);
  const auth = getAuth(app);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', {disableWarnings:true});
  const db = getFirestore(app);
  connectFirestoreEmulator(db, '127.0.0.1', 8080);
  const email = `student-${Date.now()}@example.com`;
  const password = 'StrongStudent123!';
  const getCode = async type => {
    const response = await fetch(`http://127.0.0.1:9099/emulator/v1/projects/${projectId}/oobCodes`);
    const data = await response.json();
    return data.oobCodes.filter(x => x.email === email && x.requestType === type).at(-1).oobCode;
  };
  try {
    await assert.rejects(signInWithEmailAndPassword(auth, email, password));
    const {user} = await createUserWithEmailAndPassword(auth, email, password);
    const uid = user.uid;
    await updateProfile(user, {displayName:'Student One'});
    const ref = doc(db, `users/${uid}`);
    const profile = {uid, name:'Student One', gender:'', createdAt:serverTimestamp()};
    assert.equal(user.emailVerified, false);
    await assertFails(setDoc(ref, profile));
    await assertFails(getDoc(ref));
    await sendEmailVerification(user);
    const code = await getCode('VERIFY_EMAIL');
    await assert.rejects(applyActionCode(auth, 'invalid-code'));
    await applyActionCode(auth, code);
    await user.reload();
    await user.getIdToken(true);
    assert.equal(user.emailVerified, true);
    await assertSucceeds(setDoc(ref, profile));
    await assertFails(setDoc(doc(db, 'users/someone-else'), {...profile, uid:'someone-else'}));
    await assertSucceeds(updateDoc(ref, {name:'Saved Name', gender:'Male', updatedAt:serverTimestamp()}));
    // Use only emulator-issued SMS codes. Link onto the existing email UID.
    const phoneNumber = '+201012345678';
    const sent = await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:sendVerificationCode?key=demo-key', {
      method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({phoneNumber})
    });
    assert.equal(sent.status, 200);
    const {sessionInfo} = await sent.json();
    const codesResponse = await fetch(`http://127.0.0.1:9099/emulator/v1/projects/${projectId}/verificationCodes`);
    const sms = (await codesResponse.json()).verificationCodes.find(x => x.sessionInfo === sessionInfo);
    assert.ok(sms);
    const wrong = sms.code === '000000' ? '111111' : '000000';
    await assert.rejects(linkWithCredential(user, PhoneAuthCredential.fromJSON({verificationId:sessionInfo, verificationCode:wrong})));
    assert.equal(user.phoneNumber, null);
    const linked = await linkWithCredential(user, PhoneAuthCredential.fromJSON({verificationId:sessionInfo, verificationCode:sms.code}));
    assert.equal(linked.user.uid, uid);
    assert.equal(linked.user.emailVerified, true);
    assert.equal(linked.user.phoneNumber, phoneNumber);
    await user.getIdToken(true);
    assert.equal((await assertSucceeds(getDoc(ref))).data().name, 'Saved Name');
    await signOut(auth);
    await assert.rejects(signInWithEmailAndPassword(auth, email, 'WrongPassword!'));
    const returned = await signInWithEmailAndPassword(auth, email, password);
    assert.equal(returned.user.uid, uid);
    assert.equal(returned.user.phoneNumber, phoneNumber);
    assert.equal((await getDoc(ref)).data().name, 'Saved Name');
    await sendPasswordResetEmail(auth, email);
    await confirmPasswordReset(auth, await getCode('PASSWORD_RESET'), 'ChangedPassword456!');
    await signOut(auth);
    await assert.rejects(signInWithEmailAndPassword(auth, email, password));
    assert.equal((await signInWithEmailAndPassword(auth, email, 'ChangedPassword456!')).user.uid, uid);
    await assert.rejects(createUserWithEmailAndPassword(auth, email, password));
  } finally { await deleteApp(app); await env.cleanup(); }
});
