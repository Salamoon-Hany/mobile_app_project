// Operator-only data reset. Not imported by the Worker or migrations.
// Firebase Auth and Firestore must also be reset before announcing completion.
export const RESET_TABLES=Object.freeze([
 'order_messages','order_reviews','order_complaints','order_extras',
 'quote_requests','notification_reads','withdrawal_reviews',
 'wallet_withdrawals','marketplace_withdrawals','platform_fee_ledger',
 'marketplace_deposits','worker_applications','app_ratings',
 'account_activity','admin_audit','marketplace_orders','marketplace_accounts',
 'phone_login_aliases','phone_login_limits','security_rate_limits',
 'marketplace_assertions',
]);
export async function resetMarketplaceData(db,confirmation){
 if(confirmation!=='RESET SANAD DATA')throw new Error('RESET_CONFIRMATION_REQUIRED');
 // D1 batch is atomic and preserves the schema, views, migrations and bindings.
 await db.batch(RESET_TABLES.map(table=>db.prepare('DELETE FROM '+table).bind()));
}
