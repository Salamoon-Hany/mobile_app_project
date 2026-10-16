# Firebase startup under the Site Content Security Policy

The FlutterFire Web loader in this build creates inline scripts to import its
Firebase SDK modules. The Site disallows inline JavaScript. As a result,
`Firebase.initializeApp` could fail before any login request, leaving the login
button disabled even though the server's Firebase API requests worked.

`web/firebase-bootstrap.mjs` imports the Firebase core, Auth, and Firestore SDKs
as external ES modules from the already allowed Google CDN. The launch script
waits for all three modules, publishes the globals expected by FlutterFire, and
only then starts Flutter. No Firebase app or user is created by this loader;
the Dart entry point still initializes the app with its existing browser config.

The pinned JavaScript SDK version, 11.9.1, matches the compiled Flutter client.
When upgrading FlutterFire, check its supported JavaScript SDK version and keep
the preload module aligned. The server key is never used in this module.

If an import fails, the launch screen offers Retry and does not reveal a broken
login form. The Content Security Policy remains unchanged: inline scripts and
string evaluation remain blocked.

Regression checks:

```sh
node --test test/sanad_web_launch_test.mjs test/firebase_bootstrap_test.mjs
```

These cover launch ordering, failed-load retry, and publishing all Firebase
modules together. They do not replace a browser login test.

Reference: https://firebase.google.com/docs/flutter/setup#disable_firebase_javascript_sdk_auto-injection
