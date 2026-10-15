CREATE TABLE security_rate_limits (
 key TEXT PRIMARY KEY,
 bucket INTEGER NOT NULL,
 count INTEGER NOT NULL CHECK(count BETWEEN 1 AND 10000),
 expires_at INTEGER NOT NULL
);
--> statement-breakpoint
CREATE INDEX security_rate_limits_expiry ON security_rate_limits(expires_at);
--> statement-breakpoint
ALTER TABLE marketplace_accounts ADD COLUMN legacy_balance_claim INTEGER NOT NULL DEFAULT 0 CHECK(legacy_balance_claim BETWEEN 0 AND 100000000);
