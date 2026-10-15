# Service experience update

This release adds customer/worker order conversations with optional photos, completed-order worker reviews, private complaints and support replies, price quotes, appointments and additional-cost approval. Settings includes Price quotes and Activity & alerts. The verified owner email is configured in the server-only ADMIN_EMAILS runtime variable; the browser cannot select its own admin role. No owner credentials or private account data are committed.

## Money and permissions

Fixed-price bookings retain the existing reservation flow. Quote requests reserve nothing. Only the assigned worker can offer a price. Customer approval rechecks the server price and quote state in the reservation batch; duplicate or competing approval cannot reserve twice. The quote's service, location, description and photo must match the booked order. Appointments are stored as UTC milliseconds and displayed in local time, with a 90-day booking window.

A worker may request an additional cost for accepted work. Only the owning customer may approve it. Approval atomically debits available balance and increases the reserved order amount once. Completion reads the current amount inside the settlement transaction, so concurrent completion and extra approval cannot lose money. The existing customer completion action settles earnings; worker acceptance does not.

Admin can reply to complaints, approve/reject worker applications, and review or reject withdrawal requests. Only audited admin approval can change a customer to a worker. Active customer orders must finish before approval. Previous customer orders remain accessible after the change, and worker job/earnings displays exclude previous customer orders. Rejection/cancellation of a withdrawal refunds gross once, including concurrent attempts. Reviewed requests remain pending; there is no claim that money was sent. Add Funds remains simulated. No real payments, payouts, SMS or email were enabled.

Order conversations and message photos require membership in that order. Complaints are visible only to their reporter and admin. Worker reviews require completed orders and are visible to authenticated users selecting workers. Customer names and contacts are not exposed by reviews. Account deletion also scrubs the new user content and quote locations. All writes use verified Firebase identity, bounded inputs and server-side checks.

## Alerts and limits

A durable authenticated activity feed tracks orders, messages, quote updates and complaint replies. Read state persists across devices. The existing three-second foreground refresh updates the feed. Browser notifications are opt-in and work while SANAD remains open, subject to browser support and permission. Background push after closing the app is NOT integrated: Firebase Messaging server credentials/web push configuration are not available. Do not represent foreground polling as guaranteed instant delivery.

Customer and worker profile completion remains a completeness indicator. Entering a national ID is a format check, not identity verification; only its last four digits are stored.

## Validation

81 Flutter tests and 55 server/SQLite tests passed. This includes identity isolation, one review per completed order, optional comments, private attachments, quote booking races, stale prices, insufficient balances, additional-cost settlement races, admin authorization, application approval, withdrawal cancellation/rejection races and chat retry reference reuse. Phone-sized widget renders were checked in English and Arabic. Tests use fictional accounts and isolated databases; no real user transactions were created. Physical device camera capture and deployed-browser interaction remain untested in this environment.

Migration 0005 is append-only and preserves existing account, balance, photo, order and receipt rows. Flutter static analysis and the Web release build are run before publication. ADMIN_EMAILS is a production secret and must be provisioned separately when deploying outside Sites.
