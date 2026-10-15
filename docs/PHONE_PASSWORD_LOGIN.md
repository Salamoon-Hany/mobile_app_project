# Verified mobile number and password login

Email/password remains the primary registration and login method. A number must
first be verified through Profile's Firebase SMS linking flow. Typing a number
does not enable mobile login or create another account.

The hosted Worker registers the linked number only after Firebase validates the
signed-in account token and returns its current verified email and phone. The
private D1 directory contains phone, email and UID; it contains no passwords.
Existing linked numbers register automatically when their owner opens the updated
application while signed in (or signs in with email once).

On phone/password login, the server verifies the existing password with Firebase,
then checks that the phone is still linked to that same UID. Only then does it
return the verified account email to the client. Flutter signs in through its
normal Firebase password provider and checks UID, verified email and phone again.
No custom Firebase admin key is required. Unknown numbers, wrong passwords and
stale links return the same generic failure. IP/phone attempts are rate-limited;
responses are not cached. Passwords and Firebase session tokens are not stored in
the directory, logged, or returned from this endpoint.

Hosting now contains a Flutter static client and a small Worker with a DB binding.
Apply the schema-only migration under `drizzle/` through normal Sites publication.
Preserve the existing Site ID and private audience. Firebase email/password and
Phone providers must remain enabled; real SMS still requires the owner's existing
Firebase SMS configuration. No SMS or billing change is triggered by deployment.

The currently configured build is Web. Native Firebase configuration and private
hosting access for a standalone Android/iOS application still require their own
setup before real-device authentication testing.
