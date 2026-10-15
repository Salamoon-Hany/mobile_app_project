ALTER TABLE marketplace_accounts ADD COLUMN gender TEXT NOT NULL DEFAULT '';
--> statement-breakpoint
ALTER TABLE marketplace_accounts ADD COLUMN contact_phone TEXT NOT NULL DEFAULT '';
--> statement-breakpoint
ALTER TABLE marketplace_accounts ADD COLUMN national_id_last4 TEXT NOT NULL DEFAULT '';
--> statement-breakpoint
ALTER TABLE marketplace_accounts ADD COLUMN deleted_at INTEGER NOT NULL DEFAULT 0;
--> statement-breakpoint
ALTER TABLE app_ratings ADD COLUMN comment TEXT NOT NULL DEFAULT '';
--> statement-breakpoint
CREATE TABLE marketplace_withdrawals (
 uid TEXT NOT NULL REFERENCES marketplace_accounts(uid), request_id TEXT NOT NULL,
 amount INTEGER NOT NULL CHECK(amount BETWEEN 1000 AND 100000000),
 fee INTEGER NOT NULL CHECK(fee=(amount*5+50)/100),
 net INTEGER NOT NULL CHECK(net=amount-fee AND net>0),
 method TEXT NOT NULL CHECK(method IN ('mobile_wallet','instapay')), destination TEXT NOT NULL,
 status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','cancelled')),
 reserved INTEGER NOT NULL DEFAULT 0 CHECK(reserved IN (0,1)), refunded INTEGER NOT NULL DEFAULT 0 CHECK(refunded IN (0,1)),
 created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
 PRIMARY KEY(uid,request_id)
);
