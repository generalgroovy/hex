CREATE TABLE `skirmishes` (
	`code` text PRIMARY KEY NOT NULL,
	`version` integer DEFAULT 0 NOT NULL,
	`host_hash` text NOT NULL,
	`data_json` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	`expires_at` integer NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `skirmishes_host_hash_unique` ON `skirmishes` (`host_hash`);--> statement-breakpoint
CREATE INDEX `skirmishes_expiry_idx` ON `skirmishes` (`expires_at`);