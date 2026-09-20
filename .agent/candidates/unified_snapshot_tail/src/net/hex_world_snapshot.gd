class_name HexWorldSnapshot
extends RefCounted


const ChemistrySnapshot = preload("res://src/net/hex_chemistry_snapshot.gd")
const WirePacking = preload("res://src/net/hex_snapshot_wire_packing.gd")
const HexWorld = preload("res://src/sim/hex/hex_chemistry_world.gd")
const ReactionWorld = preload("res://src/sim/world/reaction_movement_world.gd")
const DynamicCollision = preload("res://src/sim/hex/hex_collision_world.gd")

const SCHEMA_VERSION := 2
const RESERVED_EPOCH := 0
const MAX_RAW_BYTES := 32_768
const MAX_HEX_UNCOMPRESSED_BYTES := 524_288
const MAX_PLAYERS := 8
const MAX_TARGETS := 4
const MAX_ACTORS := MAX_PLAYERS + MAX_TARGETS
const MAX_PROJECTILES := 128
const MAX_ID := 0x7fffffff
const MAX_TICK := 0x7fffffff
const MAX_TIMER_TICKS := 1_000_000
const MAX_ABSOLUTE_POSITION := 100_000_000
const PLAYER_SCALAR_COUNT := 136
const PLAYER_VALUE_COUNT := 160
const PROJECTILE_ROW_SIZE := 30
const MASK_LOW_BITS := 31
const MASK_LOW_MAX := 0x7fffffff
const MASK_HIGH_MAX := 31

const SNAPSHOT_KEYS: Array[String] = [
	"schema", "epoch", "header", "map_id", "map_hash", "transition_hash",
	"state_hash", "players", "projectiles", "projectile_grazes",
	"fields", "deposits", "reactions", "dynamic_physics", "hex",
]

# This explicit order is the published PlayerState.canonical_values() order.
# Restore uses it directly; property discovery order never enters the wire.
const PLAYER_SCALAR_FIELDS: Array[StringName] = [
	&"entity_id", &"team_id", &"actor_kind", &"champion_wire_id",
	&"position_x", &"position_y", &"position_remainder_x", &"position_remainder_y",
	&"velocity_x", &"velocity_y", &"facing_x", &"facing_y", &"aim_x", &"aim_y", &"radius", &"movement_mode",
	&"primary_held", &"pending_cast_wire_id", &"pending_cast_ticks", &"pending_cast_aim_x", &"pending_cast_aim_y",
	&"pending_cast_target_x", &"pending_cast_target_y", &"cast_recovery_ticks", &"primary_cooldown_ticks",
	&"active_1_cooldown_ticks", &"active_2_cooldown_ticks", &"edgeweave_cooldown_ticks",
	&"primary_wire_id", &"active_1_wire_id", &"active_2_wire_id",
	&"health_maximum", &"health_recovery_per_second", &"health", &"health_recovery_remainder",
	&"health_recovery_delay_ticks", &"spawn_protection_ticks", &"flux_maximum", &"flux_recovery_per_second",
	&"flux", &"flux_recovery_remainder", &"flux_recovery_delay_ticks", &"stamina_maximum",
	&"stamina_recovery_per_second", &"movement_speed_ratio", &"stamina", &"stamina_remainder", &"stamina_recovery_delay_ticks",
	&"jump_buffer_ticks", &"technique_buffer_ticks", &"slide_buffer_ticks", &"fast_falling", &"variable_jump_grace_ticks",
	&"jump_sustain_ticks", &"movement_chain_count", &"movement_chain_reset_ticks", &"movement_action_speed",
	&"air_velocity_x", &"air_velocity_y", &"movement_commitment_ticks", &"wall_air_ticks",
	&"slide_held_last_tick", &"fast_fall_armed", &"evade_buffer_airborne", &"air_height", &"air_vertical_velocity",
	&"air_height_remainder", &"air_dodge_used", &"jump_held_last_tick", &"air_floating", &"float_used", &"float_ticks",
	&"float_max_duration_ms", &"flux_recovery_idle_ticks", &"stamina_recovery_idle_ticks", &"chemistry_reveal_ticks",
	&"chemistry_conceal_ticks", &"chemistry_regen_block_ticks", &"jump_protection_ticks", &"evade_buffer_ticks",
	&"landing_input_ticks", &"landing_input_x", &"landing_input_y", &"hop_ticks", &"hop_cooldown_ticks", &"hop_stage",
	&"hop_mode", &"hop_speed", &"hop_x", &"hop_y", &"air_redirects_remaining", &"air_dodge_ticks",
	&"air_dodge_cooldown_ticks", &"air_dodge_x", &"air_dodge_y", &"wave_dash_queued", &"wave_dash_ticks",
	&"wave_dash_x", &"wave_dash_y", &"slide_ticks", &"slide_cooldown_ticks", &"slide_x", &"slide_y",
	&"vault_ticks", &"vault_cooldown_ticks", &"vault_x", &"vault_y", &"superglide_ticks", &"superglide_x", &"superglide_y",
	&"wall_memory_ticks", &"wall_x", &"wall_y", &"wall_contact_id", &"wall_lockout_id", &"wall_lockout_ticks",
	&"wall_skim_ticks", &"wall_skim_cooldown_ticks", &"wall_skim_x", &"wall_skim_y", &"wall_skim_surface_id",
	&"wall_skim_lockout_id", &"wall_skim_lockout_ticks", &"landing_ticks", &"landing_intensity", &"impact_recovery_ticks",
	&"sprinting", &"control_state", &"control_ticks", &"control_x", &"control_y", &"control_speed", &"slow_ratio",
	&"training_respawn_ticks", &"training_spawn_x", &"training_spawn_y",
]

const PLAYER_BOOL_INDICES: Array[int] = [16, 51, 61, 62, 63, 67, 68, 69, 70, 95, 126]
const PLAYER_DIRECTION_INDICES: Array[int] = [10, 11, 12, 13, 19, 20, 81, 82, 88, 89, 93, 94, 97, 98, 101, 102, 105, 106, 108, 109, 111, 112, 118, 119, 129, 130]


static func capture(world: SimWorld) -> Dictionary:
	if not _trusted_world_valid(world):
		return {}
	# The complete outer prepare() below validates this deterministic chemistry
	# encoding in trusted topology, so do not pay for the nested chemistry-only
	# reconstruction here. Incoming paths still use the public strict validators.
	var detached := ChemistrySnapshot._capture_for_outer_roundtrip(world.hex_court)
	if detached.is_empty():
		return {}
	var packed_hex := WirePacking.pack(detached, world.hex_court.cells.size())
	if packed_hex.is_empty():
		return {}

	var player_values := PackedInt32Array()
	var ordered_players: Array[PlayerState] = world.players.duplicate()
	ordered_players.sort_custom(func(left: PlayerState, right: PlayerState) -> bool: return left.entity_id < right.entity_id)
	for state: PlayerState in ordered_players:
		var values := state.canonical_values()
		if values.size() != PLAYER_VALUE_COUNT or not _valid_player_values(values):
			return {}
		player_values.append_array(PackedInt32Array(Array(values)))

	var projectile_values := PackedInt32Array()
	var graze_values := PackedInt32Array()
	for shot: ProjectileState in world.projectiles:
		var ledger: Dictionary = world.hex_court.ledger_for_source(shot.source_cast_id)
		var cast_id: int = int(world.hex_court.sources.get(shot.source_cast_id, 0))
		var cast: Dictionary = world.hex_court.casts.get(cast_id, {})
		if ledger.is_empty() or not StrengthBudget.validate(ledger) or cast.is_empty() or not cast.flight_parts.has(shot.entity_id) or int(cast.flight_parts[shot.entity_id]) <= 0:
			return {}
		if shot.initial_strength != int(ledger.initial_strength) or shot.remaining_strength != int(ledger.remaining_strength):
			return {} # Projection must already agree; capture never repairs live state.
		var row := _capture_projectile(shot, ledger)
		if row.is_empty():
			return {}
		projectile_values.append_array(row)
		graze_values.append(shot.entity_id)
		graze_values.append(shot.grazed_entity_ids.size())
		for grazed_id: int in shot.grazed_entity_ids:
			if grazed_id < 1 or grazed_id > MAX_ID:
				return {}
			graze_values.append(grazed_id)

	var snapshot := {
		"schema": SCHEMA_VERSION,
		"epoch": RESERVED_EPOCH,
		"header": PackedInt64Array([
			SimConfig.PROTOCOL_VERSION, world.tick, world.seed,
			world.next_projectile_id, world.next_field_id, world.next_deposit_id, world.next_reaction_id,
			int(world.hex_court.current_tick),
		]),
		"map_id": world.map_id,
		"map_hash": world.map_hash,
		"transition_hash": world.transition_policy.content_hash,
		"state_hash": world.state_hash(),
		"players": player_values,
		"projectiles": projectile_values,
		"projectile_grazes": graze_values,
		"fields": PackedInt32Array(),
		"deposits": PackedInt32Array(),
		"reactions": PackedInt32Array(),
		"dynamic_physics": PackedInt32Array(),
		"hex": _compress_hex(packed_hex),
	}
	if snapshot.hex.is_empty():
		return {}
	var size := byte_size(snapshot)
	if size < 0 or size > MAX_RAW_BYTES:
		return {}
	var prepared := prepare(snapshot, world)
	# prepare() already reconstructs the complete world and verifies its hash
	# against snapshot.state_hash. This synchronous producer has no mutation or
	# re-entry point after that captured hash, so repeating both full hashes here
	# adds no malformed-state rejection.
	return snapshot if prepared != null else {}


# Transport-only validation. It proves the exact v2 envelope and typed lane
# lengths without accepting remote topology or constructing gameplay state.
static func validate_wire_structure(snapshot: Dictionary) -> bool:
	if not _snapshot_shape_valid(snapshot) or int(snapshot.epoch) != RESERVED_EPOCH:
		return false
	var size := byte_size(snapshot)
	if size < 0 or size > MAX_RAW_BYTES:
		return false
	var header: PackedInt64Array = snapshot.header
	if header.size() != 8 or header[0] != SimConfig.PROTOCOL_VERSION or not _in_range(header[1], 0, MAX_TICK) or header[7] != maxi(0, header[1] - 1):
		return false
	for index: int in range(3, 7):
		if not _in_range(header[index], 1, MAX_ID):
			return false
	var players: PackedInt32Array = snapshot.players
	var projectiles: PackedInt32Array = snapshot.projectiles
	if players.is_empty() or players.size() % PLAYER_VALUE_COUNT != 0 or players.size() / PLAYER_VALUE_COUNT > MAX_ACTORS:
		return false
	if projectiles.size() % PROJECTILE_ROW_SIZE != 0 or projectiles.size() / PROJECTILE_ROW_SIZE > MAX_PROJECTILES:
		return false
	if _decode_players(players).is_empty() or _decode_projectiles(projectiles, snapshot.projectile_grazes) == null:
		return false
	var packed_hex := _decompress_hex(snapshot.hex)
	return not packed_hex.is_empty() and WirePacking.validate_structure(packed_hex)


# The returned world owns decoded mutable authority and a fresh copy of the
# trusted immutable worldbone. No remote geometry or topology is applied.
static func prepare(snapshot: Dictionary, trusted_world: SimWorld) -> SimWorld:
	if not validate_wire_structure(snapshot) or not _trusted_world_valid(trusted_world):
		return null
	var size := byte_size(snapshot)
	if size < 0 or size > MAX_RAW_BYTES or int(snapshot.epoch) != RESERVED_EPOCH:
		return null
	var header: PackedInt64Array = snapshot.header
	if header.size() != 8 or header[0] != SimConfig.PROTOCOL_VERSION or not _in_range(header[1], 0, MAX_TICK):
		return null
	for index: int in range(3, 7):
		if not _in_range(header[index], 1, MAX_ID):
			return null
	if not _in_range(header[7], 0, MAX_TICK):
		return null
	if header[7] != maxi(0, header[1] - 1): return null
	if String(snapshot.map_id) != trusted_world.map_id or String(snapshot.map_hash) != trusted_world.map_hash \
		or String(snapshot.transition_hash) != trusted_world.transition_policy.content_hash:
		return null
	if not _hash_valid(String(snapshot.state_hash)):
		return null

	var packed_hex := _decompress_hex(snapshot.hex, trusted_world.hex_court.cells.size())
	if packed_hex.is_empty():
		return null
	var detached := WirePacking.unpack(packed_hex, trusted_world.hex_court.cells.size())
	if detached.is_empty():
		return null
	var decoded_hex := _blank_trusted_hex(trusted_world.hex_court)
	if decoded_hex == null or not ChemistrySnapshot.restore(detached, decoded_hex) or decoded_hex.current_tick != header[7]:
		return null

	var base_collision := _clone_base_collision(trusted_world.collision)
	if base_collision == null:
		return null
	var dynamic_collision := DynamicCollision.new(base_collision)
	decoded_hex.collision = base_collision
	if not dynamic_collision.set_hex_surfaces(decoded_hex, header[1]):
		return null
	var prepared := SimWorld.new(trusted_world.config.tick_rate, header[2], dynamic_collision, trusted_world.map_id, trusted_world.map_hash)
	if not prepared.is_valid() or prepared.transition_policy.content_hash != snapshot.transition_hash:
		return null
	prepared.tick = header[1]
	prepared.seed = header[2]
	prepared.next_projectile_id = header[3]
	prepared.next_field_id = header[4]
	prepared.next_deposit_id = header[5]
	prepared.next_reaction_id = header[6]
	prepared.hex_court = decoded_hex
	prepared.players = _decode_players(snapshot.players)
	if prepared.players.is_empty() or not _validate_actor_set(prepared.players):
		return null
	var decoded_projectiles: Variant = _decode_projectiles(snapshot.projectiles, snapshot.projectile_grazes)
	if decoded_projectiles == null:
		return null
	prepared.projectiles = decoded_projectiles
	prepared.fields = []
	prepared.deposits = []
	prepared.reactions = []
	prepared.combat_events = []
	prepared.last_error = ""
	if not _validate_relations(prepared):
		return null
	if prepared.state_hash() != String(snapshot.state_hash):
		return null
	return prepared


static func restore(snapshot: Dictionary, target: SimWorld) -> bool:
	var prepared := prepare(snapshot, target)
	if prepared == null:
		return false
	target.tick = prepared.tick
	target.seed = prepared.seed
	target.map_id = prepared.map_id
	target.map_hash = prepared.map_hash
	target.players = prepared.players
	target.projectiles = prepared.projectiles
	target.fields = prepared.fields
	target.deposits = prepared.deposits
	target.reactions = prepared.reactions
	target.next_projectile_id = prepared.next_projectile_id
	target.next_field_id = prepared.next_field_id
	target.next_deposit_id = prepared.next_deposit_id
	target.next_reaction_id = prepared.next_reaction_id
	target.hex_court = prepared.hex_court
	target.collision = prepared.collision
	target.reaction_movement = prepared.reaction_movement
	target.combat_events = []
	target.last_error = ""
	return true


static func byte_size(snapshot: Dictionary) -> int:
	return WirePacking.byte_size(snapshot)


static func _compress_hex(packed: Dictionary) -> Dictionary:
	if not WirePacking.validate_structure(packed):
		return {}
	var raw := var_to_bytes(packed)
	if raw.is_empty() or raw.size() > MAX_HEX_UNCOMPRESSED_BYTES:
		return {}
	var compressed := raw.compress(FileAccess.COMPRESSION_DEFLATE)
	if compressed.is_empty():
		return {}
	return {"schema": SCHEMA_VERSION, "size": raw.size(), "bytes": compressed}


static func _decompress_hex(envelope: Dictionary, cell_count: int = -1) -> Dictionary:
	if envelope.size() != 3 or not envelope.has("schema") or not envelope.has("size") or not envelope.has("bytes") \
		or typeof(envelope.schema) != TYPE_INT or int(envelope.schema) != SCHEMA_VERSION \
		or typeof(envelope["size"]) != TYPE_INT or not _in_range(int(envelope["size"]), 1, MAX_HEX_UNCOMPRESSED_BYTES) \
		or typeof(envelope.bytes) != TYPE_PACKED_BYTE_ARRAY or (envelope.bytes as PackedByteArray).is_empty():
		return {}
	var raw: PackedByteArray = (envelope.bytes as PackedByteArray).decompress_dynamic(MAX_HEX_UNCOMPRESSED_BYTES, FileAccess.COMPRESSION_DEFLATE)
	if raw.size() != int(envelope["size"]):
		return {}
	var value: Variant = bytes_to_var(raw)
	if not value is Dictionary:
		return {}
	var packed: Dictionary = value
	return packed if WirePacking.validate_structure(packed, cell_count) else {}


static func _clone_base_collision(source: CollisionWorld) -> CollisionWorld:
	if source == null:
		return null
	var base: CollisionWorld = (source as HexCollisionWorld).base_world if source is HexCollisionWorld else source
	if base == null or base.width <= 0 or base.height <= 0:
		return null
	var result := CollisionWorld.new(base.width, base.height)
	for obstacle: CollisionWorld.Obstacle in base.obstacle_view():
		result.add_obstacle(CollisionWorld.Obstacle.new(obstacle.obstacle_id, obstacle.minimum_x, obstacle.minimum_y, obstacle.maximum_x, obstacle.maximum_y, obstacle.vaultable, obstacle.wall_runnable))
	return result


static func _capture_projectile(shot: ProjectileState, ledger: Dictionary) -> PackedInt32Array:
	var mask: int = shot.chemistry_interaction_mask
	if mask < 0 or mask >> 36 != 0:
		return PackedInt32Array()
	var row := PackedInt64Array([
		shot.entity_id, shot.owner_id, shot.team_id, shot.source_wire_id, shot.element_wire_id,
		shot.position_x, shot.position_y, shot.previous_x, shot.previous_y,
		shot.velocity_x, shot.velocity_y, shot.remainder_x, shot.remainder_y,
		shot.radius, shot.damage, shot.lifetime_ticks, shot.hit_control_state,
		shot.hit_control_duration_ms, shot.hit_control_speed, shot.hit_control_slow_ratio,
		shot.remaining_bounces, shot.remaining_distance, shot.source_cast_id, shot.material_strength,
		mask & MASK_LOW_MAX, (mask >> MASK_LOW_BITS) & MASK_HIGH_MAX,
		shot.reaction_strength, shot.range_subunit,
		int(ledger.initial_strength), int(ledger.remaining_strength),
	])
	for number: int in row:
		if number < -0x80000000 or number > 0x7fffffff:
			return PackedInt32Array()
	var result := PackedInt32Array(Array(row))
	return result if _valid_projectile_row(result) else PackedInt32Array()


static func _decode_players(values: PackedInt32Array) -> Array[PlayerState]:
	var result: Array[PlayerState] = []
	if values.size() % PLAYER_VALUE_COUNT != 0 or values.is_empty() or values.size() / PLAYER_VALUE_COUNT > MAX_ACTORS:
		return result
	for offset: int in range(0, values.size(), PLAYER_VALUE_COUNT):
		var row := PackedInt64Array(Array(values.slice(offset, offset + PLAYER_VALUE_COUNT)))
		if not _valid_player_values(row):
			return []
		var state := PlayerState.new(row[0])
		for index: int in PLAYER_SCALAR_COUNT:
			state.set(PLAYER_SCALAR_FIELDS[index], bool(row[index]) if index in PLAYER_BOOL_INDICES else row[index])
		state.spell_wire_ids = PackedInt32Array(Array(row.slice(PLAYER_SCALAR_COUNT, PLAYER_SCALAR_COUNT + PlayerState.SPELL_SLOT_COUNT)))
		state.spell_cooldown_ticks = PackedInt32Array(Array(row.slice(PLAYER_SCALAR_COUNT + PlayerState.SPELL_SLOT_COUNT, PLAYER_VALUE_COUNT)))
		if state.canonical_values() != row:
			return []
		result.append(state)
	return result


static func _decode_projectiles(rows: PackedInt32Array, grazes: PackedInt32Array) -> Variant:
	if rows.size() % PROJECTILE_ROW_SIZE != 0 or rows.size() / PROJECTILE_ROW_SIZE > MAX_PROJECTILES:
		return null
	var grazes_by_id: Variant = _decode_grazes(grazes)
	if grazes_by_id == null:
		return null
	var result: Array[ProjectileState] = []
	var seen_ids := {}
	for offset: int in range(0, rows.size(), PROJECTILE_ROW_SIZE):
		var row := rows.slice(offset, offset + PROJECTILE_ROW_SIZE)
		if not _valid_projectile_row(row) or seen_ids.has(row[0]) or not grazes_by_id.has(row[0]):
			return null
		seen_ids[row[0]] = true
		var shot := ProjectileState.new(row[0], row[1], row[2], row[3], row[4], Vector2i(row[5], row[6]), Vector2i(row[9], row[10]), row[13], row[14], row[15], row[16], row[17], row[18], row[19], row[20])
		shot.previous_x = row[7]
		shot.previous_y = row[8]
		shot.remainder_x = row[11]
		shot.remainder_y = row[12]
		shot.remaining_distance = row[21]
		shot.source_cast_id = row[22]
		shot.material_strength = row[23]
		shot.chemistry_interaction_mask = row[24] | (int(row[25]) << MASK_LOW_BITS)
		shot.reaction_strength = row[26]
		shot.range_subunit = row[27]
		shot.initial_strength = row[28]
		shot.remaining_strength = row[29]
		shot.grazed_entity_ids = grazes_by_id[row[0]]
		result.append(shot)
	if seen_ids.size() != grazes_by_id.size():
		return null
	return result


static func _decode_grazes(values: PackedInt32Array) -> Variant:
	var result := {}
	var offset := 0
	while offset < values.size():
		if offset + 2 > values.size():
			return null
		var projectile_id: int = values[offset]
		var count: int = values[offset + 1]
		offset += 2
		if projectile_id <= 0 or result.has(projectile_id) or count < 0 or count > MAX_ACTORS or offset + count > values.size():
			return null
		var ids := PackedInt64Array()
		var previous := 0
		for index: int in count:
			var actor_id: int = values[offset + index]
			if actor_id <= previous:
				return null
			previous = actor_id
			ids.append(actor_id)
		result[projectile_id] = ids
		offset += count
	return result


static func _valid_player_values(values: PackedInt64Array) -> bool:
	if values.size() != PLAYER_VALUE_COUNT or values[0] <= 0 or values[0] > MAX_ID or values[1] <= 0 or values[1] > 10_000:
		return false
	if values[2] not in [PlayerState.ActorKind.CHAMPION, PlayerState.ActorKind.TRAINING_TARGET] or values[3] < 0 or values[3] > 4096:
		return false
	for value: int in values:
		if value < -MAX_ID or value > MAX_ID:
			return false
	for index: int in PLAYER_BOOL_INDICES:
		if values[index] not in [0, 1]:
			return false
	for index: int in PLAYER_DIRECTION_INDICES:
		if values[index] < -1000 or values[index] > 1000:
			return false
	for index: int in [4, 5, 134, 135]:
		if absi(values[index]) > MAX_ABSOLUTE_POSITION:
			return false
	if (values[21] == -1) != (values[22] == -1) or values[21] < -1 or values[22] < -1 \
		or values[21] > MAX_ABSOLUTE_POSITION or values[22] > MAX_ABSOLUTE_POSITION:
		return false
	if absi(values[6]) >= SimConfig.TICK_RATE or absi(values[7]) >= SimConfig.TICK_RATE \
		or absi(values[8]) > 10_000_000 or absi(values[9]) > 10_000_000:
		return false
	for index: int in [34, 40, 46]:
		if absi(values[index]) >= SimConfig.TICK_RATE:
			return false
	if absi(values[66]) >= 2 * SimConfig.TICK_RATE:
		return false
	if values[14] <= 0 or values[14] > 100_000 or values[15] < 0 or values[15] >= PlayerState.MovementMode.size() \
		or values[86] < 0 or values[86] >= PlayerState.MovementMode.size() or values[127] < 0 or values[127] >= PlayerState.ControlState.size():
		return false
	for pair: Vector2i in [Vector2i(31, 33), Vector2i(37, 39), Vector2i(42, 45)]:
		if values[pair.x] < 0 or values[pair.x] > 1_000_000 or values[pair.y] < 0 or values[pair.y] > values[pair.x]:
			return false
	for index: int in [32, 38, 43]:
		if values[index] < 0 or values[index] > 1_000_000:
			return false
	for index: int in PLAYER_SCALAR_COUNT:
		if String(PLAYER_SCALAR_FIELDS[index]).ends_with("_ticks") and (values[index] < 0 or values[index] > MAX_TIMER_TICKS):
			return false
	if values[44] <= 0 or values[44] > 5000 or values[132] <= 0 or values[132] > 1000 \
		or values[64] < 0 or values[64] > MAX_ABSOLUTE_POSITION or values[85] < 0 or values[85] > 2 or values[90] < 0 or values[90] > 2 \
		or values[124] < 0 or values[124] > 1000 or values[131] < 0 or values[131] > 10_000_000:
		return false
	if values[72] not in [MovementTuning.FLOAT_SMALL_DURATION_MS, MovementTuning.FLOAT_MIDDLE_DURATION_MS, MovementTuning.FLOAT_LARGE_DURATION_MS]:
		return false
	if values[17] != 0 and not CombatTuning.is_runtime_wire_id(values[17]):
		return false
	for index: int in range(PLAYER_SCALAR_COUNT + PlayerState.SPELL_SLOT_COUNT, PLAYER_VALUE_COUNT):
		if values[index] < 0 or values[index] > MAX_TIMER_TICKS:
			return false
	var state := PlayerState.new(values[0])
	for index: int in PLAYER_SCALAR_COUNT:
		state.set(PLAYER_SCALAR_FIELDS[index], bool(values[index]) if index in PLAYER_BOOL_INDICES else values[index])
	state.spell_wire_ids = PackedInt32Array(Array(values.slice(PLAYER_SCALAR_COUNT, PLAYER_SCALAR_COUNT + PlayerState.SPELL_SLOT_COUNT)))
	state.spell_cooldown_ticks = PackedInt32Array(Array(values.slice(PLAYER_SCALAR_COUNT + PlayerState.SPELL_SLOT_COUNT, PLAYER_VALUE_COUNT)))
	return state.has_valid_spell_slots() and state.canonical_values() == values


static func _valid_projectile_row(row: PackedInt32Array) -> bool:
	if row.size() != PROJECTILE_ROW_SIZE or row[0] <= 0 or row[1] <= 0 or row[2] <= 0 or row[22] <= 0:
		return false
	if not CombatTuning.is_runtime_wire_id(row[3]) or row[4] < 1 or row[4] > 8:
		return false
	for index: int in [5, 6, 7, 8]:
		if absi(row[index]) > MAX_ABSOLUTE_POSITION:
			return false
	for index: int in [9, 10]:
		if absi(row[index]) > 10_000_000:
			return false
	if absi(row[11]) >= SimConfig.TICK_RATE or absi(row[12]) >= SimConfig.TICK_RATE:
		return false
	if row[13] <= 0 or row[13] > 100_000 or row[14] < 0 or row[14] > 1_000_000 or row[15] <= 0 or row[15] > MAX_TIMER_TICKS:
		return false
	if row[16] != CombatTuning.NO_HIT_CONTROL_STATE and (row[16] < 0 or row[16] >= PlayerState.ControlState.size()):
		return false
	if row[17] < 0 or row[17] > MAX_TIMER_TICKS or row[18] < 0 or row[18] > 10_000_000 or row[19] < 0 or row[19] > 1000:
		return false
	if row[20] < 0 or row[20] > 8 or row[21] < -1 or row[21] > 142_000_000 or row[23] < 0 or row[23] > 1000:
		return false
	if row[24] < 0 or row[25] < 0 or row[25] > MASK_HIGH_MAX or row[26] < 1 or row[26] > 15:
		return false
	return row[27] >= 0 and row[27] < ProjectileState.RANGE_SUBUNITS and row[28] >= 1 and row[28] <= 15 and row[29] >= 0 and row[29] <= row[28]


static func _validate_actor_set(players: Array[PlayerState]) -> bool:
	var seen := {}
	var champions := 0
	var targets := 0
	var previous := 0
	for state: PlayerState in players:
		if state.entity_id <= previous or seen.has(state.entity_id):
			return false
		previous = state.entity_id
		seen[state.entity_id] = true
		if state.actor_kind == PlayerState.ActorKind.CHAMPION:
			champions += 1
		else:
			if state.pending_cast_wire_id != 0:
				return false
			targets += 1
	return champions >= 1 and champions <= MAX_PLAYERS and targets <= MAX_TARGETS


static func _validate_relations(world: SimWorld) -> bool:
	var actors := {}
	var champions := {}
	for state: PlayerState in world.players:
		actors[state.entity_id] = state
		if state.actor_kind == PlayerState.ActorKind.CHAMPION:
			champions[state.entity_id] = state
	for cast_id: int in world.hex_court.casts:
		var record: Dictionary = world.hex_court.casts[cast_id]
		if not champions.has(int(record.owner)):
			return false
	for owner: int in world.hex_court.pending:
		if not champions.has(owner):
			return false
		var state: PlayerState = champions[owner]
		var cast: Dictionary = world.hex_court.casts.get(int(world.hex_court.pending[owner]), {})
		if cast.is_empty() or not bool(cast.paid) or state.pending_cast_wire_id != int(cast.wire):
			return false
	for owner: int in champions:
		var state: PlayerState = champions[owner]
		if (state.pending_cast_wire_id > 0) != world.hex_court.pending.has(owner):
			return false
	for actor_id: int in world.hex_court.exposure:
		if not actors.has(actor_id):
			return false
	for key: String in world.hex_court.flow_carry:
		var parts := key.split(":", false)
		if parts.size() != 2 or not actors.has(int(parts[1])):
			return false
	var maximum_projectile_id := 0
	var live_flights := {}
	var owner_projectile_counts := {}
	for shot: ProjectileState in world.projectiles:
		if not champions.has(shot.owner_id) or live_flights.has(shot.entity_id):
			return false
		live_flights[shot.entity_id] = shot.source_cast_id
		owner_projectile_counts[shot.owner_id] = int(owner_projectile_counts.get(shot.owner_id, 0)) + 1
		if int(owner_projectile_counts[shot.owner_id]) > SimConfig.MAX_PROJECTILES_PER_PLAYER:
			return false
		var owner: PlayerState = champions[shot.owner_id]
		var ledger: Dictionary = world.hex_court.ledger_for_source(shot.source_cast_id)
		var cast_id: int = int(world.hex_court.sources.get(shot.source_cast_id, 0))
		var cast: Dictionary = world.hex_court.casts.get(cast_id, {})
		if ledger.is_empty() or cast.is_empty() or not cast.flight_parts.has(shot.entity_id) or int(cast.flight_parts[shot.entity_id]) <= 0 \
			or int(cast.owner) != shot.owner_id or int(cast.team) != shot.team_id or owner.team_id != shot.team_id \
			or int(cast.wire) != shot.source_wire_id or int(cast.element) != shot.element_wire_id \
			or int(ledger.initial_strength) != shot.reaction_strength or int(ledger.initial_strength) != shot.initial_strength \
			or int(ledger.remaining_strength) != shot.remaining_strength:
			return false
		for grazed_id: int in shot.grazed_entity_ids:
			if not actors.has(grazed_id) or grazed_id == shot.owner_id:
				return false
		maximum_projectile_id = maxi(maximum_projectile_id, shot.entity_id)
	var maximum_source_id := 0
	for source_id: int in world.hex_court.sources:
		var ledger: Dictionary = world.hex_court.ledger_for_source(source_id)
		var cast: Dictionary = world.hex_court.casts[int(world.hex_court.sources[source_id])]
		var branch_total := 0
		for entity_id: int in cast.flight_parts:
			branch_total += int(cast.flight_parts[entity_id])
			if int(live_flights.get(entity_id, 0)) != source_id:
				return false
		if branch_total != int(ledger.flight_quantity):
			return false
		maximum_source_id = maxi(maximum_source_id, source_id)
	if live_flights.size() != world.projectiles.size():
		return false
	for product_id: int in world.hex_court.products:
		for source_value: Variant in world.hex_court.products[product_id].source_ids:
			maximum_source_id = maxi(maximum_source_id, int(source_value))
		for source_value: Variant in world.hex_court.products[product_id].linked_sources:
			maximum_source_id = maxi(maximum_source_id, int(source_value))
	return world.next_projectile_id > maxi(maximum_projectile_id, maximum_source_id)


static func _blank_trusted_hex(trusted: HexChemistryWorld) -> HexChemistryWorld:
	var result := HexWorld.new()
	var cells: Array[Vector2i] = []
	for key: Variant in trusted.cells:
		if not key is Vector2i:
			return null
		cells.append(key)
	if not result.configure_geometry(trusted.origin, cells):
		return null
	for cell: Vector2i in cells:
		for property_name: String in ["terrain", "elevation", "structure"]:
			result.cells[cell][property_name] = trusted.cells[cell][property_name]
	return result


static func _trusted_world_valid(world: SimWorld) -> bool:
	return world != null and world.is_valid() and world.hex_court is HexChemistryWorld \
		and world.fields.is_empty() and world.deposits.is_empty() and world.reactions.is_empty()


static func _snapshot_shape_valid(snapshot: Dictionary) -> bool:
	if snapshot.size() != SNAPSHOT_KEYS.size():
		return false
	for key: String in SNAPSHOT_KEYS:
		if not snapshot.has(key):
			return false
	if typeof(snapshot.schema) != TYPE_INT or snapshot.schema != SCHEMA_VERSION or typeof(snapshot.epoch) != TYPE_INT:
		return false
	if typeof(snapshot.header) != TYPE_PACKED_INT64_ARRAY or typeof(snapshot.players) != TYPE_PACKED_INT32_ARRAY \
		or typeof(snapshot.projectiles) != TYPE_PACKED_INT32_ARRAY or typeof(snapshot.projectile_grazes) != TYPE_PACKED_INT32_ARRAY:
		return false
	for key: String in ["fields", "deposits", "reactions", "dynamic_physics"]:
		if typeof(snapshot[key]) != TYPE_PACKED_INT32_ARRAY or not snapshot[key].is_empty():
			return false
	for key: String in ["map_id", "map_hash", "transition_hash", "state_hash"]:
		if typeof(snapshot[key]) != TYPE_STRING:
			return false
	return typeof(snapshot.hex) == TYPE_DICTIONARY


static func _hash_valid(value: String) -> bool:
	if value.length() != 64:
		return false
	for character: String in value:
		if character not in "0123456789abcdef":
			return false
	return true


static func _in_range(value: int, minimum: int, maximum: int) -> bool:
	return value >= minimum and value <= maximum
