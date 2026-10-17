-- Preserve existing amounts and quoted rates; new requests use customer 2%, worker 8%.
DROP VIEW wallet_withdrawal_history;
--> statement-breakpoint
CREATE TABLE wallet_withdrawals_next (
 uid TEXT NOT NULL REFERENCES marketplace_accounts(uid), request_id TEXT NOT NULL,
 role TEXT NOT NULL CHECK(role IN('customer','worker')),
 amount INTEGER NOT NULL CHECK(amount BETWEEN 1000 AND 100000000),
 fee_bps INTEGER NOT NULL CHECK((role='worker' AND fee_bps IN(500,800)) OR (role='customer' AND fee_bps IN(100,200))),
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
INSERT INTO wallet_withdrawals_next SELECT * FROM wallet_withdrawals;
--> statement-breakpoint
DROP TABLE wallet_withdrawals;
--> statement-breakpoint
ALTER TABLE wallet_withdrawals_next RENAME TO wallet_withdrawals;
--> statement-breakpoint
CREATE INDEX wallet_withdrawals_status ON wallet_withdrawals(status,created_at);
--> statement-breakpoint
CREATE VIEW wallet_withdrawal_history AS
 SELECT * FROM wallet_withdrawals
 UNION ALL SELECT w.uid,w.request_id,'worker',w.amount,500,w.fee,w.net,w.method,w.destination,'demo',w.status,
 COALESCE(r.state,CASE WHEN w.status='cancelled' THEN 'cancelled' ELSE 'pending' END),COALESCE(r.note,''),w.reserved,w.refunded,w.created_at,w.updated_at
 FROM marketplace_withdrawals w LEFT JOIN withdrawal_reviews r ON r.uid=w.uid AND r.request_id=w.request_id
 WHERE NOT EXISTS(SELECT 1 FROM wallet_withdrawals n WHERE n.uid=w.uid AND n.request_id=w.request_id);
