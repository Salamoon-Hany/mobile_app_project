# Wallet deposit: university demo and server integration

## Hosted build now

The drawer starts at **EGP 0.00** and has **+ Add funds** to its right. Choose
VISA, Vodafone Cash or Fawry; enter an amount. The input hint is `minimum 10
pounds`, and deposits below EGP 10 are rejected. Amounts accept two decimal
places and Arabic digits. Values are stored as integer piasters. The maximum
single deposit is EGP 1,000,000.

The service fee is **1%**, rounded half up to the nearest piaster and added to
what is paid, not deducted from wallet credit. EGP 100 credit + EGP 1 fee =
EGP 101 total. EGP 10 credit + EGP 0.10 fee = EGP 10.10 total.

The current published build is a **local university simulation**. A confirmation
explicitly says that no real money is charged and no email is sent. It adds the
amount to the demo balance immediately and displays an email receipt preview.
Demo funds reset on logout, account switching or page reload; they are not
persisted money. Demo payment methods do not collect real card/CVV, wallet PIN
or payment OTP details. The existing booking flow can use this demo balance and
cannot go negative. It cannot spend a server-backed real wallet.

## Prepared backend (not deployed or activated)

`functions/` contains a Firebase HTTPS `walletApi` integration for **FawryPay
Hosted Checkout**. CARD maps to VISA, MWALLET to the mobile-wallet checkout
(which requires Vodafone Cash support on the merchant account), and PayAtFawry
to a retail Fawry payment. Selecting a method or generating a Fawry reference
alone does not credit money. All card/wallet credentials belong on the provider
checkout, never in this app or its Firestore database.

The backend requires a revoked-token check and verified email, recalculates
minimum/fee/total itself, signs its hosted checkout request, checks the signature
of the server notification V2, and verifies method and total. Only a **PAID**
notification credits the deposit amount. Credit and the receipt email outbox
are committed together in one Firestore transaction, with a deterministic
reference preventing duplicate credits or emails on concurrent/replayed
callbacks. The recipient comes from the verified Firebase account, never a
client-provided recipient or callback email.

Staging and live ledgers are separate (`testWallets`/`testWalletDeposits` versus
`wallets`/`walletDeposits`). Firestore rules let only a verified owner get their
wallet; clients cannot write balances/deposits, list other users, or queue mail.
The backend creates documents in `mail`, consumed by Firebase's official
**Trigger Email** extension configured with an SMTP sender. Queued receipts are
not shown as sent; only extension delivery status SUCCESS is labelled sent.

The integration has local unit/emulator validation, not merchant sandbox or
live payment approval. No provider credentials, SMTP sender, Firebase admin
session or billing changes were supplied. The source is an integration starting
point and must pass the merchant's full staging checkout/callback tests before
live funds are accepted. Refund notifications are rejected for manual merchant
reconciliation; automatic refunds/withdrawals and real booking fulfilment are
outside this deposit implementation.

## Owner activation steps

1. Obtain a FawryPay merchant account with CARD, MWALLET/Vodafone Cash and
   PayAtFawry enabled, plus separate staging/live merchant codes and secure keys.
   Confirm with Fawry whether wallet top-ups are allowed for this merchant.
2. Create/enable the default Firestore database, publish the repository rules,
   and configure Blaze for Functions/extensions. Preserve email and phone setup.
3. Install Firebase's official Trigger Email extension for the **mail**
   collection and configure its SMTP server and sender. Keep client writes to
   mail denied. Only use a verified sender you control.
4. From an authenticated Firebase CLI, set the secret interactively:

   ```sh
   firebase functions:secrets:set FAWRY_SECURE_KEY --project salamoon-services
   ```

5. Locally create the ignored `functions/.env.salamoon-services` (never commit
   credentials) containing your `FAWRY_MERCHANT_CODE`,
   `FAWRY_ENVIRONMENT=staging`, `RECEIPT_EMAIL_ENABLED=true`, and
   `WALLET_RETURN_URL=https://eslam-mobile-service-app.eslam-hanyram11.chatgpt.site/`.
   Only set the mail flag after the extension is installed and delivery tested.
6. Run `npm ci` inside functions, then deploy with the owner's CLI account:

   ```sh
   firebase deploy --only functions:wallet,firestore:rules --project salamoon-services
   ```

7. Configure the deployed `walletApi/webhook` URL as **Server Notification V2**
   with the Fawry merchant operations team. Browser redirects are not payment
   confirmation. Fawry payments may remain pending until paid at a retailer.
8. Build Flutter with the actual returned HTTPS function URL:

   ```sh
   flutter build web --release --dart-define=WALLET_API_BASE_URL=YOUR_DEPLOYED_WALLET_API_URL
   ```

   The demo is disabled whenever this value is provided. Use **Open secure
   checkout**, then **Check payment status** after completing payment. Test a
   paid/failed/pending payment, duplicate callback, mismatched amount, concurrent
   retry, separate accounts, logout/reload and receipt delivery before live use.
   A provider timeout marks the same reference RECONCILIATION_REQUIRED and shows
   an explicit support/reconciliation notice; check/reconcile its status before
   creating another payment. Do not retry unknown provider charges with new IDs.
9. Merchant processing fees can exist in addition to the app's 1% service fee.
   Agree who absorbs these so the requested EGP 101 total is accurate. After
   staging acceptance, configure live credentials/environment separately.
   Do not enable real booking debits until server-side booking fulfilment exists.

## Validation

```sh
flutter test
flutter analyze --no-fatal-infos --no-fatal-warnings
cd functions
npm ci
npm test
cd ../rules_tests
npm ci
npm test
```

Tests use only local emulators, never a real card, payment provider or email.
Browser/device QA is unavailable here; verify the drawer, keyboard, checkout
link and email delivery in your intended environment when activating a provider.

Primary references:
- https://developer.fawrystaging.com/docs/express-checkout/fawrypay-hosted-checkout
- https://developer.fawrystaging.com/docs/express-checkout/payment-notifications/server-notification-v2
- https://firebase.google.com/docs/extensions/official/firestore-send-email
