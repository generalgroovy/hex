CREATE TABLE `tower_rooms_v23` (
	`code` text PRIMARY KEY NOT NULL,
	`version` integer DEFAULT 0 NOT NULL,
	`host_hash` text NOT NULL,
	`data_json` text NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	`expires_at` integer NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `tower_rooms_v23_host_hash_unique` ON `tower_rooms_v23` (`host_hash`);--> statement-breakpoint
CREATE INDEX `tower_rooms_v23_expiry_idx` ON `tower_rooms_v23` (`expires_at`);