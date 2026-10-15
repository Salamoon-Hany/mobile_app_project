ALTER TABLE marketplace_orders ADD COLUMN scheduled_at INTEGER NOT NULL DEFAULT 0;
--> statement-breakpoint
CREATE TABLE order_messages(id TEXT PRIMARY KEY,order_id TEXT NOT NULL REFERENCES marketplace_orders(id),sender_uid TEXT NOT NULL REFERENCES marketplace_accounts(uid),body TEXT NOT NULL,photo TEXT,created_at INTEGER NOT NULL,UNIQUE(order_id,sender_uid,id));
--> statement-breakpoint
CREATE INDEX order_messages_order ON order_messages(order_id,created_at);
--> statement-breakpoint
CREATE TABLE order_reviews(order_id TEXT PRIMARY KEY REFERENCES marketplace_orders(id),customer_uid TEXT NOT NULL,worker_uid TEXT NOT NULL,stars INTEGER NOT NULL CHECK(stars BETWEEN 1 AND 5),comment TEXT NOT NULL DEFAULT '',photo TEXT,created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE INDEX order_reviews_worker ON order_reviews(worker_uid,created_at);
--> statement-breakpoint
CREATE TABLE order_complaints(id TEXT PRIMARY KEY,order_id TEXT NOT NULL REFERENCES marketplace_orders(id),uid TEXT NOT NULL,reason TEXT NOT NULL,body TEXT NOT NULL,photo TEXT,status TEXT NOT NULL DEFAULT 'open' CHECK(status IN ('open','resolved')),reply TEXT NOT NULL DEFAULT '',created_at INTEGER NOT NULL,updated_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE admin_audit(id TEXT PRIMARY KEY,actor TEXT NOT NULL,kind TEXT NOT NULL,target TEXT NOT NULL,decision TEXT NOT NULL,note TEXT NOT NULL,created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE withdrawal_reviews(uid TEXT NOT NULL,request_id TEXT NOT NULL,state TEXT NOT NULL CHECK(state IN ('reviewed','rejected')),note TEXT NOT NULL,updated_at INTEGER NOT NULL,PRIMARY KEY(uid,request_id),FOREIGN KEY(uid,request_id) REFERENCES marketplace_withdrawals(uid,request_id));
--> statement-breakpoint
CREATE TABLE quote_requests(id TEXT PRIMARY KEY,customer_uid TEXT NOT NULL,worker_uid TEXT NOT NULL,services TEXT NOT NULL,details TEXT NOT NULL,location TEXT NOT NULL,photo TEXT,scheduled_at INTEGER NOT NULL DEFAULT 0,amount INTEGER NOT NULL DEFAULT 0 CHECK(amount>=0),status TEXT NOT NULL DEFAULT 'requested' CHECK(status IN ('requested','offered','booked','cancelled')),order_id TEXT,created_at INTEGER NOT NULL,updated_at INTEGER NOT NULL,CHECK(customer_uid<>worker_uid));
--> statement-breakpoint
CREATE TABLE order_extras(order_id TEXT NOT NULL REFERENCES marketplace_orders(id),id TEXT NOT NULL,amount INTEGER NOT NULL CHECK(amount BETWEEN 100 AND 100000000),note TEXT NOT NULL,status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected')),applied INTEGER NOT NULL DEFAULT 0 CHECK(applied IN(0,1)),created_at INTEGER NOT NULL,PRIMARY KEY(order_id,id));
--> statement-breakpoint
CREATE TABLE notification_reads(uid TEXT NOT NULL,id TEXT NOT NULL,PRIMARY KEY(uid,id));
