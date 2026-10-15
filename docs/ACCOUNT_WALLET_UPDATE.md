# Profile, feedback and worker withdrawals

## Behavior

- Customer completion: name, email, contact phone, gender and photo each contribute 20%. Workers have six equal items, including an optional Egyptian national ID (rounded progress). The green completion indicator means the profile is complete, not verified identity.
- Worker signup and Profile accept an optional national ID or skipping it. Both client and server validate 14 digits, century and real/non-future birth date. Only the final four digits are persisted. No government lookup, ID document upload or identity verification is performed.
- Signup offers an optional contact number and Profile permits editing it without SMS. This is stored separately from Firebase's verified phone. Self-reported numbers never overwrite verified login aliases or claim phone ownership; email/password and previously verified phone/password login continue to work.
- Login, signup, email confirmation and auth landing expose English/Arabic in the top right. The same persistent preference controls Settings and RTL.
- App ratings support an optional 0–2000 character comment, with saved stars and feedback restored for the owner. One editable record per customer.
- Intro minimum is now 2700 ms (previously 3700) on web and native; reduced-motion handling and readiness gates remain.

## Withdrawal contract

Workers open Balance & withdrawals from Settings or Withdraw on the earnings dashboard. A request stores a mobile-wallet number or InstaPay address privately and shows gross, **5% withdrawal fee** (half-up to a piaster) and net. Customer top-up quotes retain their existing 1% fee.

The gross amount is reserved atomically when the request is created. Server-computed fee and net cannot be overwritten by client fields. Requests remain Pending: no payout provider or bank transfer is enabled. A worker can cancel a pending request to receive the entire gross reservation, including the unearned fee, back once. The same request ID can be retried after connection failure without a second reservation; conflicting payloads are rejected. Competing requests cannot overdraw the wallet. The UI blocks duplicate clicks during confirmation and sending. Request history persists across devices.

There is no real cash collection, payout, SMS or receipt email. These project balances originate from the existing simulated top-ups. Pending requests do not mean that money has been transferred. Provider reconciliation, payout success/failure settlement and real treasury integration require a separate integration before real payouts can be processed.

## Account deletion

Both profiles end with Delete Account. The user must acknowledge permanent removal and forfeiture of remaining project balance and enter their password. Client reauthenticates through Firebase; server forces a fresh lookup and requires a login within five minutes. The current UID is derived from the token; body UID is ignored.

An atomic transaction refuses active pending/accepted orders and pending withdrawals, then tombstones and scrubs the account. It removes contact details, ID suffix, gender, image, legacy local imports, application and rating. Verified phone aliases are removed. Customer-owned order details, location and photos are redacted; minimal transaction rows and tombstone UID remain to protect counterpart histories and ledger integrity. A late order, deposit, withdrawal or profile request cannot revive a tombstone.

The server then replaces Firestore profile name/gender using the existing owner's rules and deletes Firebase Auth identity using the same reauthenticated ID token. No administrative service-account key is added. If a provider request fails, the private tombstone remains and the UI can resume deletion; bootstrap never recreates it. On success this device's cached records are erased and the session signs out. Other devices retain no server access, including with cached authentication tokens. Copies of old local data on devices that are offline cannot be remotely erased.

## Verification

Isolated SQLite/HTTP tests cover preserved roles, optional feedback, normalized unverified contacts, ID minimization, owner-only withdrawal history, exact-once reservation/refund, competing withdrawals, amount/fee rounding and bounds, deletion guards and scrubbing, token recency, forged UID rejection, and provider-failure retry. Firebase deletion/Firestore responses are mocked; no real account was deleted and no money, SMS or mail was sent. Widget tests cover customer/worker completion, optional comments, language persistence/position, plain phone entry, worker-only ID and deletion confirmation, plus existing camera regression tests.

Direct browser and physical device QA are unavailable in this managed environment. Real Firebase deletion and payout-provider end-to-end verification have not been performed.

Validation result: 71 distinct Flutter tests passed (70-test full suite followed by the eight-test focused suite after adding withdrawal preview coverage), 41 server tests passed, 8 launch tests passed, and Flutter 3.35.6 release Web build passed. Dart analysis reported no errors or warnings; style/info lints remain.
