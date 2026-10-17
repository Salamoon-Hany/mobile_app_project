# سند | SANAD

A Flutter services marketplace with separate customer, worker and administrator interfaces.

## Current release

- Owner-private hosted version: 33 at https://eslam-mobile-service-app.eslam-hanyram11.chatgpt.site/
- Customer navigation: Home, Orders, Notifications, Settings.
- Worker navigation: Home, Jobs, Activity & alerts, Settings. Wallet is in Settings and the home shortcut.
- Standalone administrator UI: combined platform balance/monthly earnings, account/job statistics, applications, withdrawal review, complaints, audit history and persisted notification badges.
- Administrator and support: Sanad.infoo@gmail.com / 01095069208.
- New customer deposits/withdrawals charge 2%; new worker withdrawals charge 8%. Migration 0008 preserves existing quoted amounts/rates and historical fees.
- Email/password-only sign-in. Verified returning users reload their Firebase status/token and enter directly. Signup verification remains required. Phone is profile contact information.

## Architecture

Flutter/Dart source lives at the repository root. Firebase Authentication owns identity; Firestore `users/{uid}` stores the minimal verified-owner profile. The JavaScript Worker in `worker/` verifies Firebase tokens, enforces roles, and stores marketplace accounts, orders, balances, fees, messages, quotes, reviews, complaints and notification reads in D1 via the SQL migrations in `drizzle/`.

`lib/services/marketplace_service.dart` uses authenticated HTTP snapshots and foreground polling, not FCM or WebSockets. `shared_preferences` stores language and account-isolated legacy local state; it is not the financial authority. Images are validated inline data in the current schema, not Firebase Storage uploads. GPS/search uses Geolocator and Photon.

## Payment integration status

The hosted application records project wallet operations under internal mode guards. It does not currently charge cards/mobile wallets, execute bank payouts or send deposit receipt emails. The optional Fawry checkout/webhook implementation in `functions/` is separate and requires merchant, mail and deployment configuration. The Trigger Email extension is a setup dependency for that optional path, not evidence of an installed active extension. Never enable live processing by removing labels or guards.

## Structure

- `lib/screens/`, `lib/widgets/`: screens and shared visual components.
- `lib/models/`, `lib/services/`, `lib/state/`, `lib/l10n/`: models, HTTP/Firebase/device adapters, state and translation.
- `web/`: launch/onboarding shell, Firebase module bootstrap and Web assets.
- `worker/`: production marketplace/auth API and HTTP security boundary.
- `drizzle/`: SQLite/D1 schema migrations and migration journal.
- `functions/`: optional Firebase/Fawry wallet backend.
- `test/`, `worker/test/`, `rules_tests/`, `functions/test/`: validation layers.
- `.github/workflows/validate.yml`: automated checks and reviewed release Web artifact.

## Build and check

```bash
flutter pub get
flutter analyze --no-fatal-infos
dart format lib test
flutter test
npm test
node --test test/sanad_web_launch_test.mjs test/firebase_bootstrap_test.mjs
flutter build web --release
node scripts/build-sanad.mjs
```

The final command packages an existing Web build and Worker modules under `dist/`. Site identity and publishing require the selected Site's supported source/deployment workflow. This command alone does not deploy. Firebase Web configuration is supplied in `lib/firebase_options.dart`; native Android/iOS app registration still needs platform-specific Firebase setup.

Rules/Functions integration checks additionally use Node dependencies, Java 21 and Firebase emulators; see `.github/workflows/validate.yml`. The latest feature validation run passed 98 Flutter tests, 95 Worker/SQLite tests, 12 Web tests, account/rules checks, Functions tests/audit and a release Web build: https://github.com/Salamoon-Hany/mobile_app_project/actions/runs/39068916516

The deployed Web artifact was SHA256-verified before packaging. Production checks confirmed verified admin email sign-in, admin session/dashboard and notification/totals schema; anonymous access is rejected. Physical camera/GPS and browser interaction QA remain separate checks.

## Security and history

Server authorization, parameterized queries, atomic balance changes, request idempotency, rate limits, input/photo validation, HTTPS/CSP and private hosting access remain enforced. No client API key, hidden UI element or client role flag grants admin permission. Server API keys stay outside source.

Some earlier documents in `docs/` describe historical phone-login flows, fee rates and releases. Current source, migration 0008 and this README supersede those historical descriptions. The previous owner-authorized data reset was completed earlier; routine build/test/deploy commands must not invoke the operator reset helper.

The existing pull request stays unmerged until the owner requests a merge.
