CREATE TABLE account_activity (
 uid TEXT PRIMARY KEY REFERENCES marketplace_accounts(uid),
 email TEXT NOT NULL DEFAULT '', auth_created_at INTEGER NOT NULL,
 last_seen_at INTEGER NOT NULL DEFAULT 0, verified INTEGER NOT NULL DEFAULT 0 CHECK(verified IN(0,1)),
 requested_role TEXT NOT NULL DEFAULT 'customer' CHECK(requested_role IN('customer','worker'))
);
--> statement-breakpoint
CREATE TABLE wallet_withdrawals (
 uid TEXT NOT NULL REFERENCES marketplace_accounts(uid), request_id TEXT NOT NULL,
 role TEXT NOT NULL CHECK(role IN('customer','worker')),
 amount INTEGER NOT NULL CHECK(amount BETWEEN 1000 AND 100000000),
 fee_bps INTEGER NOT NULL CHECK(fee_bps=CASE role WHEN 'worker' THEN 500 ELSE 100 END),
 fee INTEGER NOT NULL CHECK(fee=(amount*fee_bps+5000)/10000),
 net INTEGER NOT NULL CHECK(net=amount-fee AND net>0),
 method TEXT NOT NULL CHECK(method IN('mobile_wallet','instapay')), destination TEXT NOT NULL,
 mode TEXT NOT NULL DEFAULT 'demo' CHECK(mode IN('demo','live')),
 status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN('pending','cancelled','paid')),
 review_state TEXT NOT NULL DEFAULT 'pending' CHECK(review_state IN('pending','reviewed','rejected','cancelled','paid')),
 note TEXT NOT NULL DEFAULT '',
 reserved INTEGER NOT NULL DEFAULT 0 CHECK(reserved IN(0,1)), refunded INTEGER NOT NULL DEFAULT 0 CHECK(refunded IN(0,1)),
 created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, PRIMARY KEY(uid,request_id)
);
--> statement-breakpoint
CREATE INDEX wallet_withdrawals_status ON wallet_withdrawals(status,created_at);
--> statement-breakpoint
CREATE TABLE platform_fee_ledger (
 source_type TEXT NOT NULL CHECK(source_type IN('deposit','withdrawal')),
 uid TEXT NOT NULL REFERENCES marketplace_accounts(uid), request_id TEXT NOT NULL,
 role TEXT NOT NULL CHECK(role IN('customer','worker')),
 amount INTEGER NOT NULL CHECK(amount BETWEEN 1000 AND 100000000),
 fee INTEGER NOT NULL CHECK(fee>0), net INTEGER NOT NULL CHECK(net>0),
 mode TEXT NOT NULL CHECK(mode IN('demo','live')), created_at INTEGER NOT NULL,
 PRIMARY KEY(source_type,uid,request_id)
);
--> statement-breakpoint
CREATE INDEX platform_fee_ledger_mode_date ON platform_fee_ledger(mode,created_at);
--> statement-breakpoint
CREATE VIEW wallet_withdrawal_history AS
 SELECT * FROM wallet_withdrawals
 UNION ALL SELECT w.uid,w.request_id,'worker',w.amount,500,w.fee,w.net,w.method,w.destination,'demo',w.status,
 COALESCE(r.state,CASE WHEN w.status='cancelled' THEN 'cancelled' ELSE 'pending' END),COALESCE(r.note,''),w.reserved,w.refunded,w.created_at,w.updated_at
 FROM marketplace_withdrawals w LEFT JOIN withdrawal_reviews r ON r.uid=w.uid AND r.request_id=w.request_id
 WHERE NOT EXISTS(SELECT 1 FROM wallet_withdrawals n WHERE n.uid=w.uid AND n.request_id=w.request_id);
--> statement-breakpoint
CREATE VIEW platform_fee_history AS
 SELECT * FROM platform_fee_ledger
 UNION ALL SELECT 'deposit',d.uid,d.request_id,'customer',d.amount,(d.amount+50)/100,d.amount,'demo',d.created_at
 FROM marketplace_deposits d WHERE d.credited=1 AND NOT EXISTS(
 SELECT 1 FROM platform_fee_ledger l WHERE l.source_type='deposit' AND l.uid=d.uid AND l.request_id=d.request_id);
