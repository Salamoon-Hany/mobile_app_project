import test from 'node:test';
import assert from 'node:assert/strict';
import {preloadFirebase} from '../web/firebase-bootstrap.mjs';

test('SDK modules load without inline scripts or publishing a partial Firebase runtime', async () => {
  const target = {get document() {throw Error('Inline script injection is blocked');}};
  const pending = new Map();
  const ready = preloadFirebase({target,loadModule:url => new Promise(resolve => pending.set(url,resolve))});
  const modules = ['app','auth','firestore'].map(name => ({name}));
  const urls = [...pending.keys()];
  assert.equal(urls.length,3);
  assert.ok(urls.every(url => url.startsWith('https://www.gstatic.com/firebasejs/11.9.1/')));
  pending.get(urls[0])(modules[0]);
  pending.get(urls[1])(modules[1]);
  await Promise.resolve();
  assert.equal(target.firebase_core,undefined);
  pending.get(urls[2])(modules[2]);
  await ready;
  assert.equal(target.firebase_core,modules[0]);
  assert.equal(target.firebase_auth,modules[1]);
  assert.equal(target.firebase_firestore,modules[2]);
});

test('a failed SDK import leaves initialization closed and can be retried', async () => {
  const target = {};
  await assert.rejects(preloadFirebase({target,loadModule:async url => {
    if(url.endsWith('firebase-auth.js'))throw Error('network unavailable');
    return {url};
  }}),/network unavailable/);
  assert.equal(target.firebase_core,undefined);
  assert.equal(target.firebase_auth,undefined);
  await preloadFirebase({target,loadModule:async url => ({url})});
  assert.ok(target.firebase_auth.url.endsWith('firebase-auth.js'));
  assert.ok(target.firebase_core.url.endsWith('firebase-app.js'));
});
