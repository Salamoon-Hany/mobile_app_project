# SANAD administration and platform fees

The support address is Sandny.info@gmail.com. Production administrator identities
are configured through the hosted ADMIN_EMAILS variable, never through a client
role or an email entered in a request. The owner must register this email in
SANAD and verify it using Firebase email verification.

The Admin panel is available from Settings for the verified configured identity.
It includes an overview, separate platform wallet, applications, withdrawal
requests, latest orders/accounts, complaints, and an audit log. Worker requests
require administrator approval; choosing Worker during signup records intent and
does not grant worker privileges. Existing approved workers retain their role.

Money is stored as integer piasters and rates are computed on the server:
- Customer deposit of EGP 100: wallet credit EGP 100, platform fee EGP 1, total EGP 101.
- Customer withdrawal of EGP 100: reserve EGP 100, fee EGP 1, recipient gets EGP 99.
- Worker withdrawal of EGP 100: reserve EGP 100, fee EGP 5, recipient gets EGP 95.

Deposits and fees are recorded atomically and idempotently. A pending or reviewed
withdrawal does not earn a fee. Cancellation/rejection refunds the full reserved
amount; demo completion books the fee once. Live completion is blocked until a
real payout integration is implemented. No admin button sends real money.

Real and demo platform balances are separate. Existing Site deposit records are
demo transactions. A read-only view includes their historical fees without
rewriting balances. Existing withdrawals/reviews remain visible and are adopted
one request at a time when acted on; schema migrations contain no data backfill.
Legacy local balance claims and uncredited deposits do not create platform fees.

The counts cover registered SANAD marketplace accounts, not Firebase identities
which have never registered with the app. Current account counts exclude deleted
accounts. Monthly registration counts use SANAD creation dates in Africa/Cairo
and include later-deleted accounts, so deletion does not rewrite signup history.
Activity is a successful authenticated request in the rolling last 30 days;
historical visits before activity tracking are unknown. Available workers and
active workers are distinct metrics. Aggregate counts cover all matching rows;
the detail lists show the latest 100 records.

Validation includes migration compatibility, concurrent deposit retries,
withdrawal completion/cancellation races, exact refunds, real-payment blocking,
administrator authorization, account totals beyond 100 rows, and narrow Arabic
dashboard layout. End-to-end real account login remains an owner check.

Administrator access is global and follows the verified server allowlist, not the
previous administrator's UID. Switching the allowlist preserves platform history
and does not transfer a person's wallet. The activity tab includes account
creation/deletion and settled deposit/withdrawal records, alongside admin actions.
Deleted accounts are counted separately; their contact/activity profile is removed
and retained financial records show Deleted account. Historical events derive
from stored timestamps; unknown visits are not invented.

Password visibility controls are available independently for login/signup, signup
confirmation, and deletion reauthentication. Fields start hidden; toggling retains
the typed text and is disabled during submission.

## Dedicated administrator identity

The verified server allowlist is checked by GET /api/marketplace/session before
creating or reading a customer profile. A configured administrator signs in to
the standalone administration screen directly. No marketplace account, customer
wallet, worker application, or Firestore customer profile is needed or created.
Customer/worker mutation routes reject administrator identities. Administration
routes also work when the marketplace contains zero accounts. The admin screen
provides language selection and logout.

Provision the administrator identity in Firebase Authentication through the
project owner's authorized Firebase management connection. Credentials are never
stored in Dart, Worker source, tests, documentation, or GitHub. The login UI still
uses normal Firebase authentication and verified-email requirements.

## Explicit fresh-start operation

tools/reset-marketplace-data.mjs is an operator helper, not a schema migration,
deployment hook, or public HTTP route. It requires the exact runtime confirmation
RESET SANAD DATA and clears the known marketplace tables in a single D1 batch.
It removes active and deleted accounts, orders, deposits, withdrawal requests,
platform fees, applications, reviews, complaints, messages, activity/audit rows,
phone aliases and counters. It preserves schema, history views, migration records,
hosting identity, configured secrets and the administrator's Firebase identity.

This helper alone is NOT a full application reset. A complete reset also requires
deleting the previous non-admin Firebase Authentication identities (so their
emails can register again), revoking their sessions, and removing their Firestore
profiles/wallets/test-wallets and any receipt/mail queue records. Preserve or
provision only the configured administrator identity with the owner-provided
password through the authorized management connection.

Run the operation with registrations paused, invalidate cached server identity
lookups before reopening, and verify both Firebase and marketplace counts before
declaring success. Old per-UID device caches must not be imported into new
identities. Verify zero live/deleted account counts, jobs, ledger balances and
monthly totals, then verify a new signup starts at zero and the administrator
lands directly in administration without adding to user/worker counts.
