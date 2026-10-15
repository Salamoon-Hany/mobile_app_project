# SANAD worker interface

The approved six-screen mockup is implemented as Home, My jobs, Request details, Wallet, My profile and Settings. Home/Jobs/Wallet/Settings remain available through the worker navigation; Profile opens from the account avatar. The visual palette follows the customer Figma reference with lime, pale background, white bordered surfaces and dark buttons. Cards, app bars and buttons use flat styling. Workspace has been removed from rendered labels.

Home shows real account earnings, counts from assigned orders, availability, incoming requests and editable services. Jobs has Pending/Active/History filters and a search by service, customer, description and location. The full request page shows authenticated order data, an optional authenticated photo fetch, contact/location, request timestamp and amount. View location opens the coordinates in the user's maps browser. No fictional appointment schedule or embedded map tiles are claimed. Pending decisions still require confirmation and use the existing atomic server ledger.

Wallet keeps the existing idempotent withdrawal request and cancellation behavior, previews the 5% fee and net, and shows completed-job earnings and withdrawals. Withdrawals remain pending requests; no live payout provider is connected. Deposits still do not charge cards or send emails.

Profiles keep saved photo, name, email, phone, gender, optional worker ID suffix, profile completion and account deletion. The worker can edit offered services from Home or Profile. Completing a profile does not prove identity. Settings preserves Balance, Language, Dark Mode, divider, Contact us, Logout. Original eleven services remain; removed categories are not restored.

## Availability

Append-only migration 0004 adds available INTEGER NOT NULL DEFAULT 1 with a boolean check. Existing accounts retain their data. Only an authenticated worker may change their own availability. Paused workers disappear from customer selection and cannot receive new reservations; existing orders and idempotent retries remain accessible. Availability is checked again in the order-reservation transaction so pausing during checkout cannot create a charge without an order. An unrelated profile update preserves the current availability value.

## Verification

Flutter widget tests use fictional in-memory accounts, covering navigation, filters/search across tabs, live snapshot changes in an open details page, failed availability save, Arabic dark mode, profile actions and withdrawal fee preview. Optional SANAD_VISUAL_QA creates rendered Flutter screenshots with precached images. The real owner account is not used for testing. No real SMS, email, deposit or order is created. A browser session and physical mobile camera are unavailable in this environment; screenshots are widget renders rather than deployed-browser/device tests.

Toolchain: Flutter 3.47.3 / Dart 3.13.3 on Windows. Production source publication uses the existing owner-private Site and its configured D1 binding.

Validation: 76 Flutter tests passed, 43 server/SQLite tests passed; static analysis completed without errors or warnings (existing informational/style notices remain).
Web release build completed successfully. After pinning url_launcher to 6.3.2 for compatibility with the original Flutter SDK floor, the 16 relevant widget tests passed again.
