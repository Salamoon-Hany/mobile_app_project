CREATE TABLE worker_applications (
 uid TEXT PRIMARY KEY NOT NULL REFERENCES marketplace_accounts(uid),
 full_name TEXT NOT NULL, phone TEXT NOT NULL, email TEXT NOT NULL,
 work_types TEXT NOT NULL, experience_years INTEGER NOT NULL CHECK(experience_years BETWEEN 0 AND 60),
 countries TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected')),
 created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
);
--> statement-breakpoint
CREATE TABLE app_ratings (
 uid TEXT PRIMARY KEY NOT NULL REFERENCES marketplace_accounts(uid),
 stars INTEGER NOT NULL CHECK(stars BETWEEN 1 AND 5),
 created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
);
