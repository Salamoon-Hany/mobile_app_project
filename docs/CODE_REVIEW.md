# Code review fixes — 11 October 2026

The review fixes are committed locally. The GitHub review branch
`feature/real-otp-location` was created from the original main on 12 October;
the reviewed files are not uploaded or deployed yet. Full Flutter validation
is still required.

| Finding | Source change |
| --- | --- |
| Reopening booking payment can debit twice | Booking reservations live in the draft, survive navigation, and are consumed when an order is created. Discarding an unfinished draft releases its reservation to the same wallet owner. |
| Duplicate Steel Fixer / Heavy Equipment | Home and picker share one catalogue with canonical IDs; draft additions deduplicate by ID. |
| Profile name changes before Save | Typing stays in the form controller; shared profile updates follow successful saving. |
| Selected Web photo is not shown | Profile renders selected image bytes with MemoryImage / Image.memory on every platform. Photos remain session-local. |
| Image / navigation results can update a disposed screen | Mounted checks guard asynchronous results; image errors receive a friendly message. |
| Orders listeners leak | The named listener is removed in dispose. |
| Dark mode switch can disagree with the theme | The app and switch share one ValueNotifier. |
| Failed search leaves old selectable areas | Starting a new location request clears results and selection. |
| Profile validation differs from Firestore | Name limits (2–80 characters) and supported genders share client validation, with server rules remaining authoritative. |
| Checkout timeouts leave an unusable CREATING deposit | Uncertain and stale checkout creation is explicitly marked RECONCILIATION_REQUIRED. Original references are retained, subsequent requests do not initialize a second provider checkout, and late provider errors cannot overwrite PAID. Signed callbacks or merchant reconciliation must finish uncertain payments. |
| Totals ignore individual prices | Integer piaster totals sum selected job prices. |
| Mixed / unused source and forced text scaling | Screens, state, models and services are separated. The unused sample Payments screen and empty placeholders are removed. Text scaling follows the user's settings; deprecated opacity/back APIs were updated. |

## Validation in this session

- Passed: **8 backend unit tests**, including provider timeout/invalid responses,
  stale CREATING recovery, PAID preservation, signatures and integer money.
- Passed: direct Dart profile-validation boundary checks.
- Passed: Dart formatter/parser on all **34 Dart source and test files**,
  JavaScript syntax checks on all backend modules, and `git diff --check`.
- Added: **10 Flutter regression tests** (9 review tests and 1 stale-location
  search test). These have **not run** in this session.
- Blocked: full Flutter analysis, widget tests and release build. The transient
  pub cache is absent (84 referenced package directories are missing).
  Offline resolution fails because `flutter_lints` is not in the cache;
  network dependency resolution is unavailable here.
- Auth/Firestore emulator tests were **not rerun** in this session.
- Browser/device and merchant sandbox validation were **not performed**.
- GitHub writes return **403 Resource not accessible by integration**. The review branch was created through the signed-in website, but
  its source still matches original main. No reviewed files or main source were
  updated. Browser continuation then failed with a native credential-state
  protection error. The original main commit remains
  `8991e7ea7a8e6878aec1e7530e652b3eb6416bce`.
- The live Site remains on the previous successful build. Payments/receipt
  email are still simulated there; the prepared backend has not been activated.

The prepared GitHub Actions workflow checks Dart formatting, runs tests, builds
a release Web bundle, and retains the bundle as reviewed-web-build. Complete those checks before merging/publishing the reviewed source.

```sh
flutter pub get
flutter analyze --no-fatal-infos
dart format --output=none --set-exit-if-changed lib test
flutter test
flutter build web --release
npm --prefix functions ci
npm --prefix functions test
cd rules_tests
npm ci
npm test
```

## Upload helper

The source ZIP includes `Upload_Reviewed_Source.cmd` and the complete patch.
On Windows, the helper creates a fresh clone of the existing review branch,
checks the expected original base, applies the patch, and pushes the review
branch with normal Git authentication. It waits for this exact commit's named
CI workflow to pass before pushing the same commit to main. A failed/pending
workflow or changed remote main stops the helper; it never force-pushes.
It does not run Flutter locally, collect tokens, change account permissions,
or activate payments. Actual upload/CI results are not claimed until observed.
