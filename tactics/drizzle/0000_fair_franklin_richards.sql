CREATE TABLE `room_rate_limits` (
	`key` text PRIMARY KEY NOT NULL,
	`requests` integer NOT NULL,
	`expires_at` integer NOT NULL
);
--> statement-breakpoint
CREATE INDEX `room_rate_limits_expiry_idx` ON `room_rate_limits` (`expires_at`);--> statement-breakpoint
CREATE TABLE `rooms` (
	`code` text PRIMARY KEY NOT NULL,
	`version` integer DEFAULT 0 NOT NULL,
	`status` text DEFAULT 'waiting' NOT NULL,
	`map_id` text DEFAULT 'confluence' NOT NULL,
	`player0_name` text NOT NULL,
	`player0_roster` text NOT NULL,
	`player0_token_hash` text NOT NULL,
	`player1_name` text,
	`player1_roster` text,
	`player1_token_hash` text,
	`state_json` text,
	`rematch0` integer DEFAULT 0 NOT NULL,
	`rematch1` integer DEFAULT 0 NOT NULL,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL,
	`expires_at` integer NOT NULL
);
--> statement-breakpoint
CREATE INDEX `rooms_expiry_idx` ON `rooms` (`expires_at`);