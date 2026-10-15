# Customer and worker accounts

Sign up chooses Customer or Worker. Firebase Auth remains the identity provider;
D1 stores an immutable role per Firebase UID at signup, even before email
verification. Unverified users cannot access services or the marketplace. Accounts created before
14 October 2026, 17:00 UTC remain customers. Each new worker chooses their services
in **Services I provide** before appearing in customer search. There are no seeded
workers or invented ratings. Email/password and linked verified phone/password
continue to address the same Firebase UID.

The Worker workspace separates incoming orders, active work, history and settings.
It shows the requesting customer's name, verified phone when present, location,
details, attachment and amount. Only that worker can accept or reject their order.
Only its customer can cancel a pending order or confirm completed accepted work.

Submitting an order atomically reserves its server-priced amount (EGP 75 per
catalogued service). A rejected/cancelled pending order refunds the customer once.
Acceptance keeps money held; the customer's completion confirmation credits the
worker once. Atomic D1 batches, database constraints and request references enforce these transitions,
including retries, concurrent decisions and insufficient funds. Worker earnings
are project ledger entries; there is no real payout integration. Add Funds remains
a simulated deposit with no payment charged and no receipt email sent.

While open, either UI refreshes shared state every three seconds. Requests are
serialized, account changes invalidate late responses, and network failures show
a retry banner. This is polling, not guaranteed immediate delivery or an OS push
notification. Closed/background mobile browsers may suspend refreshes.

On the first updated login from the browser/device holding the prior records,
its local balance, receipts, small profile image and order history are imported
once into D1. Subsequent logins use the shared server state. Prior orders have no
real assigned worker, so they remain available as archived history, with their raw
original records retained. Local records are not deleted. Open the updated app on the original device to transfer its prior records.
If a fresh device logs in first, the server leaves the one-time legacy import
open; the original device can still merge its old balance and history afterward.
A device already synchronized to cloud is marked so it cannot reimport downloaded
cloud balances as old funds.

Profile and order photos are bounded uploads. Order photos are fetched separately
with participant authorization, rather than retransmitted with every polling
snapshot. Worker search does not expose email, phone or order details.

Take a Picture uses the native image picker on native builds and getUserMedia on
HTTPS Web, with permission/unavailable-camera handling, cancellation, stopped
media tracks and the existing upload fallback. Native camera use was tested with
an injected picker; physical hardware capture still requires device QA. Android
and iOS permissions remain included. Existing native Firebase setup still needs
its platform registrations; standalone native builds also need a reachable,
authorized MARKETPLACE_API_URL rather than the default Web same-origin endpoint.

Automated validation uses isolated SQLite databases, fake Firebase responses and
Flutter widgets. It creates no orders, money, accounts, SMS or emails in the
owner's real account. Publish the schema-only appended D1 migration together with
the client and Worker. Keep the original Site ID and private audience.
