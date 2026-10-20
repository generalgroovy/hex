import { index, integer, sqliteTable, text } from "drizzle-orm/sqlite-core";

/** Versioned multi-seat lobbies. Tokens are hashed inside the private envelope. */
export const skirmishes = sqliteTable("skirmishes", {
  code: text("code").primaryKey(),
  version: integer("version").notNull().default(0),
  hostHash: text("host_hash").notNull().unique(),
  dataJson: text("data_json").notNull(),
  createdAt: integer("created_at").notNull(),
  updatedAt: integer("updated_at").notNull(),
  expiresAt: integer("expires_at").notNull(),
}, (table) => [index("skirmishes_expiry_idx").on(table.expiresAt)]);

/** Cooperative tower runs are isolated from released competitive protocols. */
export const towerRooms = sqliteTable("tower_rooms", {
  code: text("code").primaryKey(),
  version: integer("version").notNull().default(0),
  hostHash: text("host_hash").notNull().unique(),
  dataJson: text("data_json").notNull(),
  createdAt: integer("created_at").notNull(),
  updatedAt: integer("updated_at").notNull(),
  expiresAt: integer("expires_at").notNull(),
}, (table) => [index("tower_rooms_expiry_idx").on(table.expiresAt)]);

/** Independent player squads with an authoritative shared floor checkpoint. */
export const towerRoomsV23 = sqliteTable("tower_rooms_v23", {
  code: text("code").primaryKey(),
  version: integer("version").notNull().default(0),
  hostHash: text("host_hash").notNull().unique(),
  dataJson: text("data_json").notNull(),
  createdAt: integer("created_at").notNull(),
  updatedAt: integer("updated_at").notNull(),
  expiresAt: integer("expires_at").notNull(),
}, (table) => [index("tower_rooms_v23_expiry_idx").on(table.expiresAt)]);

/** Bearer secrets never enter this table: only their SHA-256 digests are stored. */
export const rooms = sqliteTable("rooms", {
  code: text("code").primaryKey(),
  version: integer("version").notNull().default(0),
  status: text("status").notNull().default("waiting"),
  mapId: text("map_id").notNull().default("confluence"),
  player0Name: text("player0_name").notNull(),
  player0Roster: text("player0_roster").notNull(),
  player0TokenHash: text("player0_token_hash").notNull(),
  player1Name: text("player1_name"),
  player1Roster: text("player1_roster"),
  player1TokenHash: text("player1_token_hash"),
  stateJson: text("state_json"),
  rematch0: integer("rematch0").notNull().default(0),
  rematch1: integer("rematch1").notNull().default(0),
  createdAt: integer("created_at").notNull(),
  updatedAt: integer("updated_at").notNull(),
  expiresAt: integer("expires_at").notNull(),
}, (table) => [index("rooms_expiry_idx").on(table.expiresAt)]);

/** Fixed-window quotas persist across Worker instances. Keys are hashed. */
export const roomRateLimits = sqliteTable("room_rate_limits", {
  key: text("key").primaryKey(),
  requests: integer("requests").notNull(),
  expiresAt: integer("expires_at").notNull(),
}, (table) => [index("room_rate_limits_expiry_idx").on(table.expiresAt)]);
