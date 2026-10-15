CREATE TABLE phone_login_aliases (
  phone TEXT PRIMARY KEY NOT NULL,
  uid TEXT NOT NULL UNIQUE,
  email TEXT NOT NULL
);
--> statement-breakpoint
CREATE TABLE phone_login_limits (
  key TEXT PRIMARY KEY NOT NULL,
  window INTEGER NOT NULL,
  count INTEGER NOT NULL
);
