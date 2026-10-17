# Separate Firebase browser and server keys

The Flutter client keeps its existing Firebase Web configuration in
`lib/firebase_options.dart`. The Worker reads `FIREBASE_SERVER_API_KEY` from its
runtime environment for both authentication and marketplace requests to Firebase.
It has no fallback to the browser key.

## Configure the server

1. In Google Cloud project `salamoon-services`, use the existing **SANAD Server
   Auth** key. Its API restriction must allow **Identity Toolkit API**
   (`identitytoolkit.googleapis.com`). The Worker currently uses that API for
   password verification, account lookup and account deletion.
2. Set `FIREBASE_SERVER_API_KEY` as a **secret** in this Site's production runtime
   environment. Preserve all existing environment variables. Do not put its value
   in Git, Flutter configuration, a `--dart-define`, or `.openai/hosting.json`.
   `.env.example` documents names only; a local `.env` does not configure Sites.
3. Deploy the Worker and the current Flutter Web build to the existing private
   Site. If the secret is absent or blank, protected API routes return the generic
   `503 TEMPORARILY_UNAVAILABLE`; public app assets still load. Key changes refresh
   the cached handlers and their Firebase token lookup cache.
4. Verify email login and the authenticated marketplace snapshot on the deployed
   Site. Also verify mobile/password login with an account whose mobile number was
   already linked. Do not send SMS just to validate this change.
5. Only after those checks pass, apply the intended website restrictions to the
   browser key. Retain all Firebase APIs required by the client, including
   **Identity Toolkit API** and **Token Service API** for Authentication. Verify
   fresh login and token refresh after changing restrictions. Native apps need
   their own compatible Firebase app/key configuration before applying Web-only
   restrictions to a key they use.

The server key is configured separately so browser HTTP referrer restrictions do
not break Worker requests. Firebase API keys identify a project; Firebase Rules,
verified identity and server authorization continue to protect user data.

## Verification and current release state

The implementation has automated tests for missing/blank configuration, using the
server key on both API paths, key rotation and continued static asset delivery.
Run `npm test` and `node --test test/sanad_web_launch_test.mjs` in an unrestricted
development environment. Where Node cannot spawn its test processes, the supported
single-process equivalent is:

```sh
node --test --test-isolation=none worker/test/*.test.mjs test/sanad_web_launch_test.mjs
```

Source review and automated tests do not prove production secret configuration or
real Firebase login. Do not mark the migration complete until the deployed checks
above pass. Until then, leave both keys' current Cloud restrictions unchanged.

References:

- https://firebase.google.com/docs/projects/api-keys
- https://firebase.google.com/docs/reference/rest/auth
