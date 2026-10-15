# Customer Settings: worker application and app rating

Customers see **Become a worker** and **Rate the app** after Dark mode and before
the existing divider. Balance, Language and Dark mode retain their order;
Contact us and Logout remain under the divider. Worker settings do not show
these customer actions, and the server also rejects worker submissions.

Become a worker opens the introduction, then a form with the account email,
full name, contact phone, services, years of experience and experience countries.
Both selectors support multiple choices. Services come from the application
catalogue (the three removed services stay excluded); countries include Egypt.
Arabic/Persian digits normalize for phone and years, with years bounded to 0–60.

Submission creates or updates one pending application for the authenticated
Firebase UID. The email comes from Firebase, never a caller-supplied identity.
It does not change the account role or add the customer to worker search. The
success dialog confirms storage and directs the customer to Settings for status;
it does not claim that an email or a human follow-up was sent. Pending forms can
be reopened and edited. Approved/rejected records are read-only. An approval
workflow or automatic account conversion is outside this change.

Rating is an in-app 1–5 star vote stored per Firebase UID in D1. It is preselected
when reopened and can be updated, with a single row per customer. It does not
publish a Play Store/App Store review or invent public averages. Failed saves
retain the form/selection and show an error instead of a success message.

The schema-only 0002_customer_settings migration appends two private tables;
existing migrations and account/wallet/order data are preserved. All routes
require a verified Firebase identity and ignore forged ownership fields. Snapshots
return only the current customer's application and rating; signing out clears
both from memory. No mail, SMS, real money or real-account test submissions occur.

Validation: 63 Flutter tests and 31 server/database tests passed, including
customer-only visibility, multiple selections, validation, failed-save behavior,
Arabic labels, role preservation, privacy, updates and database reopening. The
release Web build succeeded. Browser QA was unavailable in the managed runtime;
no browser automation or production user submissions were used for testing.
