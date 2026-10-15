# Sanad branding and launch

Brand: سند | SANAD. Tagline: ساندينك في كل حاجة.
Palette: charcoal #171917, lime #D7FF00, warm paper #F7F8F0.
The logo PNG is used on account screens. A clean SVG emblem provides scalable
Web launch artwork, favicons, Web icons and native launcher icons.

## Launch behavior

- Web: `web/index.html`, `sanad-intro.js`, `sanad-intro.css` and
  `sanad-launch-state.mjs` display the brand while Flutter loads in an inert
  host. The custom `flutter_bootstrap.js` reports engine readiness.
- Three introduction steps cover services, location and booking. Skip and back
  controls are available. Finishing or skipping saves a browser-local flag;
  subsequent launches show the short splash only. Disabled browser storage does
  not block the flow. Clearing browser data shows the introduction again.
- The app host is revealed only after the short splash, intro completion and
  engine readiness. A failed or slow load shows a retry button. Late readiness
  can recover without another reload. Reduced motion avoids animation.
- Native Flutter: `SplashScreen` animates the logo for 2.7 seconds, then sends
  signed-in users to `AuthGate`. Signed-out users get the three-page introduction
  with Skip; completion always goes through `AuthGate`. This native introduction
  is not persisted between signed-out cold starts.
- All account verification remains enforced by `AuthGate`. Onboarding completion
  grants no authentication or service access. No payment behavior is changed.

## Hosted build and source

The updated Web release is compiled from the edited Flutter application. Its
custom HTML launch shell loads that release in a host element. The SVG branding,
service PNGs and asset/service-worker manifests are packaged with the release.
A tracked Flutter source snapshot is retained alongside the hosted Site source
in `flutter-source/`; it is not part of the static public directory.

## Validation

44 Flutter unit/widget tests passed on the installed Flutter test engine, plus
suite setup/teardown. This includes verification, GPS, booking idempotence,
selecting the worker before payment, profile photo lifecycle, language persistence,
account isolation, restored balances/orders and orphan-reservation refunds.
Eight Web launch tests and eight backend unit tests also passed. Dart semantic
analysis reports no errors or warnings (six informational notices). Release Web
compilation and JavaScript/asset/service-worker checks passed.

The Flutter tooling dependency cache was unavailable, so the tests used the
same test_api suites with the Flutter engine directly. A normal flutter test/CI
run is still recommended on GitHub. Browser visual QA, real device camera/GPS,
real SMS/email-provider tests and payment-provider tests were not performed.
Managed Sites browser QA is unavailable because control-browser is unavailable.

## October 14 application update

Arabic and English are selected in Settings and persisted locally. The Material
locale and RTL/LTR direction follow the selection. The sidebar contains balance
and profile; Settings contains language, appearance, contact and sign-out.
Fourteen consistent service illustrations include cleaning, painting and air
conditioning. Worker selection precedes payment, and a paid draft cannot debit
again. Approval/rejection simulation remains unchanged.

Project wallet balances, receipts and orders are persisted by verified account
UID on the same browser/device. Sign-out clears memory but preserves saved data.
Returning to another account never reads the previous account's key. Clearing
browser/app data removes local records; this is not cross-device cloud sync.
An unfinished payment reservation is refunded on restoration. Real backend wallet
mode never uses client persistence to restore or credit a server balance.

Project-deposit disclosures are kept in the handoff/chat, per the presentation
request. The app does not claim to send a receipt email or charge a real card.
Real payments and receipt email remain inactive; Firebase Auth email still works.

A new full Web release is compiled from the edited Flutter source using the
installed Flutter/Dart SDK. Required sources were recovered from retained test
artifacts and exact upstream dependency versions. No compiled-JavaScript patch
is used. Normal dependency installation and CI remain recommended on GitHub.
