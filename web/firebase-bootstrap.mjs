// Keep this aligned with the Firebase JS SDK used by the compiled FlutterFire
// client. Preloading external modules avoids FlutterFire's inline script loader,
// which is blocked by the Site's strict Content Security Policy.
export const firebaseSdkVersion = '11.9.1';

export async function preloadFirebase({target = globalThis, loadModule = url => import(url)} = {}) {
  const base = `https://www.gstatic.com/firebasejs/${firebaseSdkVersion}`;
  const [core, auth, firestore] = await Promise.all([
    loadModule(`${base}/firebase-app.js`),
    loadModule(`${base}/firebase-auth.js`),
    loadModule(`${base}/firebase-firestore.js`),
  ]);
  // Publish core last: FlutterFire treats its presence as the signal that all
  // manually provided SDKs are ready and skips inline injection.
  target.firebase_auth = auth;
  target.firebase_firestore = firestore;
  target.firebase_core = core;
}
