CREATE TABLE `tower_rooms` (
	`code` text PRIMARY KEY NOT NULL,
	`version` integer DEFAULT 0 NOT NULL,
	`host_hash` text NOT NULL,
	`data_json` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	`expires_at` integer NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `tower_rooms_host_hash_unique` ON `tower_rooms` (`host_hash`);--> statement-breakpoint
CREATE INDEX `tower_rooms_expiry_idx` ON `tower_rooms` (`expires_at`);