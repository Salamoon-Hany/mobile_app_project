CREATE TABLE marketplace_accounts (
 uid TEXT PRIMARY KEY, role TEXT NOT NULL CHECK(role IN ('customer','worker')),
 name TEXT NOT NULL, phone TEXT NOT NULL DEFAULT '', skills TEXT NOT NULL DEFAULT '[]', photo TEXT,
 balance INTEGER NOT NULL DEFAULT 0 CHECK(balance >= 0),
 legacy_imported INTEGER NOT NULL DEFAULT 0, legacy_orders TEXT NOT NULL DEFAULT '[]', legacy_receipts TEXT NOT NULL DEFAULT '[]', created_at INTEGER NOT NULL
);
--> statement-breakpoint
CREATE TABLE marketplace_deposits (
 uid TEXT NOT NULL REFERENCES marketplace_accounts(uid), request_id TEXT NOT NULL,
 amount INTEGER NOT NULL CHECK(amount BETWEEN 1000 AND 100000000), method TEXT NOT NULL,
 created_at INTEGER NOT NULL, credited INTEGER NOT NULL DEFAULT 0 CHECK(credited IN (0,1)), PRIMARY KEY(uid,request_id)
);
--> statement-breakpoint
CREATE TABLE marketplace_orders (
 id TEXT PRIMARY KEY, customer_uid TEXT NOT NULL REFERENCES marketplace_accounts(uid),
 worker_uid TEXT NOT NULL REFERENCES marketplace_accounts(uid), request_id TEXT NOT NULL,
 services TEXT NOT NULL, amount INTEGER NOT NULL CHECK(amount > 0),
 details TEXT NOT NULL, location TEXT NOT NULL, photo TEXT,
 status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','accepted','rejected','completed','cancelled')),
 created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, reserved INTEGER NOT NULL DEFAULT 0 CHECK(reserved IN (0,1)), settled INTEGER NOT NULL DEFAULT 0 CHECK(settled IN (0,1)),
 UNIQUE(customer_uid,request_id), CHECK(customer_uid <> worker_uid)
);
--> statement-breakpoint
CREATE INDEX marketplace_orders_customer ON marketplace_orders(customer_uid,created_at);
--> statement-breakpoint
CREATE INDEX marketplace_orders_worker ON marketplace_orders(worker_uid,created_at);
--> statement-breakpoint
CREATE TABLE marketplace_assertions (passed INTEGER NOT NULL CONSTRAINT marketplace_valid CHECK(passed=1));
