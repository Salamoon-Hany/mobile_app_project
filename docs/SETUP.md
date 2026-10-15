# Firebase email and optional mobile setup

Use the existing **salamoon-services** project with **Spark** for email-only use, or **Blaze** for real SMS. The Web configuration is already in `lib/firebase_options.dart`. Email verification needs no billing upgrade or external mail service. Real SMS needs billing configured by the project owner.

## Firebase Console: remaining steps

1. Authentication → Sign-in method → **Email/Password** → enable **Email/Password** → Save. Leave **Email link (passwordless sign-in)** off: this app uses passwords plus email address verification.
2. Authentication → Settings → Authorized domains: add `eslam-mobile-service-app.eslam-hanyram11.chatgpt.site`. For local Web development add `localhost` explicitly if needed.
3. Firestore Database → Create database → select **production mode**. Choose a region near your users and keep the default database.
4. Firestore Database → Rules: replace the rules with the complete repository-root `firestore.rules`, then **Publish**. They allow only verified-email owners to create/read their own profile, edit name/gender, and never change identity or add privileges. Do not use public/test rules.
5. Authentication → Templates → Email address verification / Password reset: optionally customize app name and language. Keep Firebase's default hosted action handler so links work without a custom email landing page.

If using the Firebase CLI with your own logged-in account, publishing rules can instead be done with:

```sh
firebase deploy --only firestore:rules --project salamoon-services
```

The email/phone flow uses no Functions. Optional wallet deposit Functions are now included but remain inactive; see WALLET_SETUP.md for merchant and SMTP setup. If an earlier OTP backend was actually deployed, remove its old requestEmailOtp/verifyEmailOtp/completeAccount functions in your Firebase Console and revoke any unused mail-provider keys. The current code never calls them.

## Registration and login

- Sign up: full name, email, password (minimum 8 characters), matching confirmation. Firebase creates the Auth identity and sends an email verification link.
- Open the link in inbox/spam, return to the app, press **I verified my email**. The app reloads the Firebase user and refreshes the token before creating/loading the protected profile.
- Failed email delivery leaves the new account pending; use Resend verification email after the cooldown, rather than signing up twice. Resend remains subject to Firebase's server limits.
- Existing unverified accounts log in with the same password and continue verification. If interrupted after creating the Auth identity, login can recover its missing profile after verification.
- Existing verified accounts log in with email/password and keep their UID and saved profile.
- Forgot password sends Firebase's password reset link. If an older email-OTP account has no password, use this once to set a password for the same email/UID.
- Email is displayed read-only in Profile, because profile text edits cannot prove email ownership.
- After email verification, the optional mobile step sends an SMS and links its credential onto the same UID. Continue with email only skips this step. Profile also offers Verify mobile.
- No guest, local OTP, anonymous or phone-only account can unlock the services. A typed mobile number is never saved as verified.

Current documented Spark limits include **1,000 address verification emails/day** and **150 password reset emails/day**. Quotas and abuse protection can change. This is address verification, not passwordless email-link sign-in (which has a different, much lower sending quota).

Official references:
- https://firebase.google.com/docs/auth/flutter/password-auth
- https://firebase.google.com/docs/auth/flutter/manage-users
- https://firebase.google.com/docs/auth/limits
- https://firebase.google.com/pricing

## Mobile SMS configuration and cost

1. Authentication → Sign-in method → **Phone** → Enable → Save. Keep Email/Password enabled.
2. Authentication → Settings → SMS region policy: allow **Egypt** (and only any other intended countries).
3. Ensure the website domain above is authorized. Firebase runs its normal reCAPTCHA security check on Web; do not disable it in production.
4. For real SMS, the owner must configure **Blaze** billing. Current official pricing says the first **ten SMS sent per day are not billed**, then rates vary by country. This is project-wide, not per user, and it is not an automatic hard stop at ten. A client cooldown is not a spending cap. Check current rates/quotas in Console before sending.
5. To try without real SMS, configure a fictional number and 6-digit code in Authentication → Phone → **Phone numbers for testing**. The code belongs in Console, never in application source. Such numbers do not prove ownership of a real phone; remove them after testing.

The app never upgrades billing or sends an SMS until the user presses **Send SMS code**. Incorrect/expired codes stay pending. A number already linked to another account cannot be taken over. Cancelling/logging out invalidates the pending challenge. Email remains required; this is contact verification, not mandatory two-factor login.

The default Firestore database must still exist and the repository rules must be published. If profile completion is blocked, confirm the **Cloud Firestore API** is enabled for this project. Adding SMS does not resolve a disabled database.

Official SMS references:
- https://firebase.google.com/docs/auth/flutter/phone-auth
- https://firebase.google.com/docs/auth/flutter/account-linking
- https://cloud.google.com/identity-platform/pricing

## Validation

```sh
flutter test
flutter analyze --no-fatal-infos --no-fatal-warnings
cd rules_tests
npm ci
npm test
```

Rules/integration tests need Java (CI uses Java 21) and run Auth + Firestore emulators against `demo-mobile-app`. They send no real email/SMS or spend Firebase credit. Tests cover unverified denial, actual email action-code verification, own-profile creation, cross-account denial, privilege tampering, duplicate signup, password login/reset, wrong SMS rejection, SMS linking to the same email UID and saved-profile identity.

On the hosted build, check signup → inbox link → return/check → services, logout/back, login/reset and separate users. Check Locate me with browser permission; searching an area still works if GPS is unavailable. GPS cannot be tested here against your device's physical location.

Real Firebase provider activation/rules publication, billing setup and email/SMS delivery have not been performed by editing source. The Firebase owner must finish the Console steps above. Only the Web Firebase app is configured; Android/iOS require registration/configuration before native testing.

Orders, receipts, balance and profile photos persist locally per UID on the same browser/device. Notifications and unfinished location drafts remain session-local. Identity/name/gender persist in Firebase; the hosted phone-login directory is described in PHONE_PASSWORD_LOGIN.md.
