# سند | SANAD

Flutter home-services application with complete Flutter source in .

Eleven original services retain their original images. Cleaning, air conditioning
and painting are removed. Settings contains Balance, Language, Dark mode, a
divider, Contact us and Logout, in that order. The header opens Profile directly
and shows the saved account photo (or a profile icon).

Email/password registration remains primary. A mobile number verified in Profile
can sign in with the same password and Firebase UID. A small hosted Worker verifies
Firebase credentials and keeps a private phone/email/UID index in D1. Passwords
are never stored. Existing verified numbers register automatically after opening
the updated app signed in, or signing in with email once. See
docs/PHONE_PASSWORD_LOGIN.md.

Customer and Worker roles now open separate interfaces. Registered workers choose
their services; orders, balances and receipts synchronize through private D1
records between the owning customer and assigned worker. Existing local records
import once from their original device; old unassigned orders remain archived. Deposits
do not charge a real payment provider or send a receipt email. The 3.7-second
launch and saved Arabic/English preference remain in place. Automatic order responses are removed. Pending orders wait for the worker;
accept/reject and customer-confirmed completion drive the atomic ledger. See
docs/MARKETPLACE.md for camera, migration and native setup limits.

Verification uses Flutter widget/unit tests, server/SQLite tests and a Web release
build. Physical cameras and a two-account production login need device QA.
Automated tests send no SMS or email and create no records in the owner account.

Customer Settings now includes a saved worker-application form and an editable
five-star app rating, restricted to customers. See
docs/CUSTOMER_SETTINGS.md. This update passed 63 Flutter tests,
31 server/database tests and a release Web build.


Customer/worker profile completion, optional rating comments, auth language selection, account deletion and worker withdrawal requests (5% fee) are described in docs/ACCOUNT_WALLET_UPDATE.md. Withdrawals remain pending requests until an actual payout provider is integrated.


## Latest synchronized release

This source mirrors the deployed SANAD version 21 (Sites source commit 9be98c94bc36eefb4de5de8f8b7f42d1dc50e6bc). Flutter lives at the repository root. Worker API and schema migrations are in worker/ and drizzle/. The redesigned worker interface is described in docs/WORKER_UI.md.

Validation: 76 Flutter tests, 43 server/database tests, and a release Web build passed. Native camera/device QA remains outstanding.
