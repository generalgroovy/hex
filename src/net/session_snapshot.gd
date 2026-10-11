class_name SessionSnapshot
extends RefCounted

const WORLD_BOUNDARY_WALL_IDS := [-1, -2]

const DepositState = preload("res://src/sim/chemistry/element_deposit_state.gd")
const ReactionState = preload("res://src/sim/chemistry/element_reaction_state.gd")
const SpellStateCodec = preload("res://src/net/expanded_spell_state_codec.gd")

const SCHEMA_VERSION: int = 24
const MAX_PLAYERS: int = 8
# Remote movement presentation requires the actual action clocks/contact, not
# a reconstruction from speed. Local reconciliation carries complete intent.
const MOVEMENT_PRESENTATION_FIELDS: Array[StringName] = [
	&"wall_skim_ticks", &"wall_air_ticks", &"movement_commitment_ticks",
	&"wall_x", &"wall_y", &"hop_x", &"hop_y", &"air_dodge_x", &"air_dodge_y",
	&"hop_stage", &"air_redirects_remaining", &"slide_cooldown_ticks",
	&"air_dodge_cooldown_ticks", &"movement_action_speed", &"hop_speed",
	&"air_height", &"air_vertical_velocity", &"air_height_remainder", &"air_dodge_used", &"jump_held_last_tick",
	&"air_floating", &"stamina_recovery_idle_ticks", &"flux_recovery_idle_ticks",
	&"stamina_recovery_delay_ticks", &"flux_recovery_delay_ticks",
	&"stamina_recovery_per_second", &"flux_recovery_per_second",
	&"float_used", &"float_ticks", &"float_max_duration_ms",
	&"chemistry_reveal_ticks", &"chemistry_conceal_ticks", &"chemistry_regen_block_ticks",
	&"pending_cast_target_x", &"pending_cast_target_y",
	&"flight_capable", &"jumpsquat_active", &"jumpsquat_ticks", &"double_jump_used", &"wallrun_armed", &"crouching",
]
const PLAYER_BASE_VALUE_COUNT: int = 115
const PLAYER_VALUE_COUNT: int = PLAYER_BASE_VALUE_COUNT + SpellStateCodec.STATUS_SIZE
const PROJECTILE_BASE_VALUE_COUNT: int = 18
const PROJECTILE_VALUE_COUNT: int = PROJECTILE_BASE_VALUE_COUNT + SpellStateCodec.DELIVERY_SIZE
const FIELD_VALUE_COUNT: int = 7
const EVENT_VALUE_COUNT: int = 6
const TARGET_VALUE_COUNT: int = 10 + SpellStateCodec.STATUS_SIZE
# Every admitted threat must reach clients. Complete snapshots may use bounded
# MTU-sized fragments; cast admission uses these same authority limits.
const MAX_PROJECTILES: int = SimConfig.MAX_ACTIVE_PROJECTILES
const MAX_FIELDS: int = SimConfig.MAX_ACTIVE_FIELDS
const MAX_DEPOSITS: int = SimConfig.MAX_ACTIVE_PROJECTILES
const MAX_REACTIONS: int = 32
const MAX_EVENTS: int = 12
const MAX_TARGETS: int = 4
const MAX_ABSOLUTE_POSITION: int = 100_000_000
# A legal cursor can span the diagonal of the nonnegative coordinate square.
const MAX_PROJECTILE_REMAINING_DISTANCE: int = 142_000_000
const MAX_TIMER_TICKS: int = 1_000_000
const EVENT_KIND_MASK: int = 0xff
const MAX_EVENT_ID: int = 0x7fffffff
const MOVEMENT_CONTEXT_PROTECTION_MASK: int = 0x7f
const MOVEMENT_CONTEXT_SUSTAIN_SHIFT: int = 7
const MOVEMENT_CONTEXT_SUSTAIN_MASK: int = 0x7f
const MOVEMENT_CONTEXT_CHAIN_SHIFT: int = 14
const MOVEMENT_CONTEXT_CHAIN_MASK: int = 0x7
const MOVEMENT_CONTEXT_RESET_SHIFT: int = 17
const MOVEMENT_CONTEXT_RESET_MASK: int = 0x7f


static func capture(
	world: SimWorld,
	names_by_entity: Dictionary,
	combat_events: Array[Dictionary] = [],
	hearth_values: PackedInt32Array = PackedInt32Array(),
	round_values: PackedInt32Array = PackedInt32Array(),
) -> Dictionary:
	if world.hex_court != null:
		return {} # H1/H2 solo migration: never emit an incomplete legacy snapshot.
	var ordered: Array[PlayerState] = []
	for state: PlayerState in world.players:
		if state.actor_kind == PlayerState.ActorKind.CHAMPION:
			ordered.append(state)
	ordered.sort_custom(func(left: PlayerState, right: PlayerState) -> bool: return left.entity_id < right.entity_id)
	var players: Array[Array] = []
	for state: PlayerState in ordered:
		var player_values := PackedInt32Array([
			state.champion_wire_id,
			state.position_x, state.position_y,
			state.velocity_x, state.velocity_y,
			state.facing_x, state.facing_y,
			state.aim_x, state.aim_y,
			state.radius, state.movement_mode,
			state.health_maximum, state.health,
			state.flux_maximum, state.flux,
			state.stamina_maximum, state.stamina,
			state.hop_ticks, state.hop_mode,
			state.air_dodge_ticks, state.superglide_ticks,
			state.vault_ticks, state.wave_dash_ticks, state.slide_ticks,
			state.landing_ticks, state.landing_intensity,
			state.control_state, state.control_ticks,
			state.primary_wire_id, state.active_1_wire_id,
			state.slow_ratio, state.team_id,
			int(state.sprinting), int(state.fast_falling),
			state.cast_recovery_ticks,
			state.pending_cast_wire_id, state.pending_cast_ticks,
			state.primary_cooldown_ticks, state.active_1_cooldown_ticks,
			state.edgeweave_cooldown_ticks, int(state.primary_held),
			state.pending_cast_aim_x, state.pending_cast_aim_y,
			state.spawn_protection_ticks,
			state.spell_slot_index_for_wire(state.primary_wire_id),
			state.spell_slot_index_for_wire(state.active_1_wire_id),
			state.spell_slot_index_for_wire(state.active_2_wire_id),
			state.active_2_wire_id, state.active_2_cooldown_ticks,
		])
		player_values.append_array(state.spell_wire_ids)
		player_values.append_array(state.spell_cooldown_ticks)
		player_values.append(_encode_movement_context(state))
		for property_name: StringName in MOVEMENT_PRESENTATION_FIELDS:
			player_values.append(int(state.get(property_name)))
		if not SpellStateCodec.valid_status_values(state.spell_status_values): return {}
		player_values.append_array(state.spell_status_values)
		players.append([
			state.entity_id,
			_safe_name(String(names_by_entity.get(state.entity_id, "Traveller %d" % state.entity_id))),
			_safe_event_name(state.last_event),
			player_values,
		])
	if hearth_values.is_empty():
		var fallback_hearth := SessionHearth.new()
		fallback_hearth.bind_host()
		for state: PlayerState in ordered:
			if state.entity_id > SessionCharter.HOST_ENTITY_ID:
				fallback_hearth.connect_entity(state.entity_id)
		hearth_values = fallback_hearth.capture(world.tick, MAX_PLAYERS)
	if round_values.is_empty():
		var fallback_round := SessionRound.new()
		fallback_round.bind_hearth()
		round_values = fallback_round.capture(world)
	var ordered_projectiles: Array[ProjectileState] = world.projectiles.duplicate()
	ordered_projectiles.sort_custom(func(left: ProjectileState, right: ProjectileState) -> bool: return left.entity_id < right.entity_id)
	var projectiles := PackedInt32Array()
	var cast_strengths: Dictionary[int, int] = {}
	for index: int in range(mini(ordered_projectiles.size(), MAX_PROJECTILES)):
		var projectile: ProjectileState = ordered_projectiles[index]
		var values := PackedInt64Array([
			projectile.entity_id, projectile.owner_id,
			projectile.source_wire_id, projectile.element_wire_id,
			projectile.position_x, projectile.position_y,
			projectile.previous_x, projectile.previous_y,
			projectile.velocity_x, projectile.velocity_y,
			projectile.radius, projectile.lifetime_ticks,
			projectile.remaining_distance, projectile.source_cast_id,
			projectile.material_strength, projectile.chemistry_interaction_mask & 0x7fffffff,
			projectile.chemistry_interaction_mask >> 31,
			projectile.reaction_strength,
		])
		var delivery := SpellStateCodec.capture_delivery(projectile)
		if delivery.is_empty(): return {}
		values.append_array(PackedInt64Array(Array(delivery)))
		if not _fits_int32(values) or not _valid_projectile_values(PackedInt32Array(Array(values))) or not _accept_cast_strength(cast_strengths, projectile.source_cast_id, projectile.entity_id, projectile.reaction_strength):
			return {}
		projectiles.append_array(PackedInt32Array(Array(values)))
	var ordered_fields: Array[FieldState] = world.fields.duplicate()
	ordered_fields.sort_custom(func(left: FieldState, right: FieldState) -> bool: return left.entity_id < right.entity_id)
	var fields := PackedInt32Array()
	for index: int in range(mini(ordered_fields.size(), MAX_FIELDS)):
		var field: FieldState = ordered_fields[index]
		var affected_mask: int = 0
		for affected_entity_id: int in field.affected_entity_ids:
			if affected_entity_id >= 1 and affected_entity_id <= MAX_PLAYERS:
				affected_mask |= 1 << (affected_entity_id - 1)
		fields.append_array(PackedInt32Array([
			field.entity_id, field.owner_id, field.source_wire_id,
			field.position_x, field.position_y, field.lifetime_ticks, affected_mask,
		]))
	var events: Array[PackedInt64Array] = []
	var first_event_index := maxi(0, combat_events.size() - MAX_EVENTS)
	for index: int in range(first_event_index, combat_events.size()):
		var encoded_event := encode_event(combat_events[index])
		if not encoded_event.is_empty():
			events.append(encoded_event)
	var ordered_targets: Array[PlayerState] = []
	for state: PlayerState in world.players:
		if state.actor_kind == PlayerState.ActorKind.TRAINING_TARGET:
			ordered_targets.append(state)
	ordered_targets.sort_custom(func(left: PlayerState, right: PlayerState) -> bool: return left.entity_id < right.entity_id)
	var targets: Array[PackedInt64Array] = []
	for index: int in range(mini(ordered_targets.size(), MAX_TARGETS)):
		var target: PlayerState = ordered_targets[index]
		var target_values := PackedInt64Array([
			target.entity_id,
			target.position_x, target.position_y,
			target.radius,
			target.health_maximum, target.health,
			target.training_respawn_ticks, target.training_spawn_x, target.training_spawn_y, target.spawn_protection_ticks,
		])
		if not SpellStateCodec.valid_status_values(target.spell_status_values): return {}
		target_values.append_array(PackedInt64Array(Array(target.spell_status_values)))
		targets.append(target_values)
	# Chemistry is persistent harmful state, unlike the lossy cosmetic event lane.
	# Refuse an over-budget or invalid whole snapshot instead of omitting danger.
	if world.deposits.size() > MAX_DEPOSITS or world.reactions.size() > MAX_REACTIONS or world.deposits.size() + world.projectiles.size() > MAX_PROJECTILES:
		return {}
	var deposits: Array[PackedInt32Array] = []
	var reactions: Array[PackedInt32Array] = []
	var ordered_deposits := world.deposits.duplicate()
	ordered_deposits.sort_custom(func(left: Variant, right: Variant) -> bool: return left.entity_id < right.entity_id)
	var trail_counts: Dictionary[int, int] = {}
	for deposit: Variant in ordered_deposits:
		var values: PackedInt64Array = deposit.canonical_values()
		if not deposit.validate() or not _fits_int32(values) or not _accept_trail_budget(deposit, trail_counts) or not _accept_cast_strength(cast_strengths, deposit.source_cast_id, deposit.entity_id, deposit.reaction_strength):
			return {}
		deposits.append(PackedInt32Array(Array(values)))
	var ordered_reactions := world.reactions.duplicate()
	ordered_reactions.sort_custom(func(left: Variant, right: Variant) -> bool: return left.entity_id < right.entity_id)
	for reaction: Variant in ordered_reactions:
		var values: PackedInt64Array = reaction.canonical_values()
		if not reaction.validate() or not _fits_int32(values):
			return {}
		reactions.append(PackedInt32Array(Array(values)))
	return {
		"schema": SCHEMA_VERSION,
		"tick": world.tick,
		"state_hash": world.state_hash().hex_decode(),
		"players": players,
		"projectiles": projectiles,
		"fields": fields,
		"deposits": deposits,
		"reactions": reactions,
		"events": events,
		"targets": targets,
		"hearth": hearth_values,
		"round": round_values,
		"overflow": PackedInt32Array([
			maxi(0, ordered_projectiles.size() - MAX_PROJECTILES),
			maxi(0, ordered_fields.size() - MAX_FIELDS),
			maxi(0, combat_events.size() - MAX_EVENTS),
			maxi(0, ordered_targets.size() - MAX_TARGETS),
		]),
	}


static func validate(snapshot: Dictionary) -> bool:
	if typeof(snapshot.get("schema")) != TYPE_INT or int(snapshot["schema"]) != SCHEMA_VERSION:
		return false
	if typeof(snapshot.get("tick")) != TYPE_INT or int(snapshot["tick"]) < 0 or int(snapshot["tick"]) > 0x7fffffff:
		return false
	var state_hash_value: Variant = snapshot.get("state_hash")
	if typeof(state_hash_value) != TYPE_PACKED_BYTE_ARRAY or (state_hash_value as PackedByteArray).size() != 32:
		return false
	var players_value: Variant = snapshot.get("players")
	if not players_value is Array:
		return false
	var players: Array = players_value
	if players.is_empty() or players.size() > MAX_PLAYERS:
		return false
	var seen: Dictionary[int, bool] = {}
	var teams_by_entity: Dictionary[int, int] = {}
	var health_by_entity: Dictionary[int, int] = {}
	var previous_entity_id: int = 0
	for player_value: Variant in players:
		if not player_value is Array or player_value.size() != 4:
			return false
		var player: Array = player_value
		if typeof(player[0]) != TYPE_INT:
			return false
		var entity_id := int(player[0])
		if entity_id < 1 or entity_id > MAX_PLAYERS or entity_id <= previous_entity_id or seen.has(entity_id):
			return false
		previous_entity_id = entity_id
		seen[entity_id] = true
		if _safe_name(String(player[1])).is_empty():
			return false
		if _safe_event_name(String(player[2])).is_empty():
			return false
		var values_value: Variant = player[3]
		if typeof(values_value) != TYPE_PACKED_INT32_ARRAY:
			return false
		var values: PackedInt32Array = values_value
		if values.size() != PLAYER_VALUE_COUNT or not _valid_player_values(values):
			return false
		teams_by_entity[entity_id] = int(values[31])
		health_by_entity[entity_id] = int(values[12])
	var projectiles_value: Variant = snapshot.get("projectiles")
	if typeof(projectiles_value) != TYPE_PACKED_INT32_ARRAY:
		return false
	var projectiles: PackedInt32Array = projectiles_value
	if projectiles.size() % PROJECTILE_VALUE_COUNT != 0 or projectiles.size() > MAX_PROJECTILES * PROJECTILE_VALUE_COUNT:
		return false
	var previous_projectile_id: int = 0
	var cast_strengths: Dictionary[int, int] = {}
	for offset: int in range(0, projectiles.size(), PROJECTILE_VALUE_COUNT):
		var values: PackedInt32Array = projectiles.slice(offset, offset + PROJECTILE_VALUE_COUNT)
		if not _valid_projectile_values(values) or not _accept_cast_strength(cast_strengths, values[13], values[0], values[17]):
			return false
		if values[0] <= previous_projectile_id:
			return false
		previous_projectile_id = values[0]
	var deposits_value: Variant = snapshot.get("deposits")
	var reactions_value: Variant = snapshot.get("reactions")
	if not deposits_value is Array or not reactions_value is Array:
		return false
	if deposits_value.size() > MAX_DEPOSITS or reactions_value.size() > MAX_REACTIONS or deposits_value.size() + projectiles.size() / PROJECTILE_VALUE_COUNT > MAX_PROJECTILES:
		return false
	var previous_deposit_id := 0
	var trail_counts: Dictionary[int, int] = {}
	for values: Variant in deposits_value:
		if typeof(values) != TYPE_PACKED_INT32_ARRAY:
			return false
		var deposit := DepositState.from_values(PackedInt64Array(Array(values)))
		if deposit == null or deposit.entity_id <= previous_deposit_id or not _accept_trail_budget(deposit, trail_counts) or not _accept_cast_strength(cast_strengths, deposit.source_cast_id, deposit.entity_id, deposit.reaction_strength):
			return false
		previous_deposit_id = deposit.entity_id
	var previous_reaction_id := 0
	for values: Variant in reactions_value:
		if typeof(values) != TYPE_PACKED_INT32_ARRAY:
			return false
		var reaction := ReactionState.from_values(PackedInt64Array(Array(values)))
		if reaction == null or reaction.entity_id <= previous_reaction_id:
			return false
		previous_reaction_id = reaction.entity_id
	var fields_value: Variant = snapshot.get("fields")
	if typeof(fields_value) != TYPE_PACKED_INT32_ARRAY:
		return false
	var fields: PackedInt32Array = fields_value
	if fields.size() % FIELD_VALUE_COUNT != 0 or fields.size() > MAX_FIELDS * FIELD_VALUE_COUNT:
		return false
	var previous_field_id: int = 0
	for offset: int in range(0, fields.size(), FIELD_VALUE_COUNT):
		var values: PackedInt32Array = fields.slice(offset, offset + FIELD_VALUE_COUNT)
		if not _valid_field_values(values):
			return false
		if values[0] <= previous_field_id:
			return false
		previous_field_id = values[0]
	var events_value: Variant = snapshot.get("events")
	if not events_value is Array or events_value.size() > MAX_EVENTS:
		return false
	for values_value: Variant in events_value:
		if typeof(values_value) != TYPE_PACKED_INT64_ARRAY:
			return false
		var values: PackedInt64Array = values_value
		if not _valid_event_values(values):
			return false
	var targets_value: Variant = snapshot.get("targets")
	if not targets_value is Array or targets_value.size() > MAX_TARGETS:
		return false
	var previous_target_id: int = MAX_PLAYERS
	for values_value: Variant in targets_value:
		if typeof(values_value) != TYPE_PACKED_INT64_ARRAY:
			return false
		var values: PackedInt64Array = values_value
		if values.size() != TARGET_VALUE_COUNT or not _valid_target_values(values) or values[0] <= previous_target_id:
			return false
		previous_target_id = values[0]
	var overflow_value: Variant = snapshot.get("overflow")
	if typeof(overflow_value) != TYPE_PACKED_INT32_ARRAY or (overflow_value as PackedInt32Array).size() != 4:
		return false
	for overflow_count: int in overflow_value:
		if overflow_count < 0:
			return false
	var hearth_value: Variant = snapshot.get("hearth")
	if typeof(hearth_value) != TYPE_PACKED_INT32_ARRAY or not SessionHearth.validate_packet(hearth_value):
		return false
	var hearth: PackedInt32Array = hearth_value
	if SessionHearth.entry_count(hearth) != players.size():
		return false
	for index: int in range(players.size()):
		if SessionHearth.entity_id_at(hearth, index) != int((players[index] as Array)[0]):
			return false
	var round_value: Variant = snapshot.get("round")
	if typeof(round_value) != TYPE_PACKED_INT32_ARRAY or not SessionRound.validate_packet(round_value):
		return false
	var round_state := SessionRound.decoded(round_value)
	for entry_value: Variant in round_state.get("entries", []):
		var round_entity_id := int((entry_value as Dictionary).get("entity_id", 0))
		# Team results retain the original score ledger after a departure. The
		# same transport ID may later belong to a new, nonparticipating observer.
		if not bool(entry_value.get("present", true)):
			if seen.has(round_entity_id) and int(health_by_entity[round_entity_id]) != 0:
				return false
			continue
		if not seen.has(round_entity_id):
			return false
		if int(round_state.get("mode", 0)) != SessionRound.Mode.FREE_FOR_ALL and int(teams_by_entity[round_entity_id]) != int(entry_value.team_id):
			return false
	return true


static func _accept_trail_budget(deposit: ElementDepositState, counts: Dictionary[int, int]) -> bool:
	if not deposit.is_trail():
		return true
	# Call only after deposit validation: owner IDs are positive, so zero safely
	# records the global total. Orphan owners still consume their role budget.
	var total := int(counts.get(0, 0)) + 1
	var owner_total := int(counts.get(deposit.owner_id, 0)) + 1
	if total > ElementChemistrySystem.MAX_TRAILS or owner_total > ElementChemistrySystem.MAX_OWNER_TRAILS:
		return false
	counts[0] = total
	counts[deposit.owner_id] = owner_total
	return true


static func _accept_cast_strength(strengths: Dictionary[int, int], source_cast_id: int, fallback_entity_id: int, reaction_strength: int) -> bool:
	if reaction_strength < 1 or reaction_strength > 15:
		return false
	var cast_id := source_cast_id if source_cast_id > 0 else fallback_entity_id
	if strengths.has(cast_id):
		return strengths[cast_id] == reaction_strength
	strengths[cast_id] = reaction_strength
	return true


static func apply_to_world(snapshot: Dictionary, world: SimWorld) -> bool:
	if world == null or not world.is_valid() or not validate(snapshot):
		return false
	var retained: Array[PlayerState] = []
	for state: PlayerState in world.players:
		if state.actor_kind not in [PlayerState.ActorKind.CHAMPION, PlayerState.ActorKind.TRAINING_TARGET]:
			retained.append(state)
	world.players = retained
	for player_value: Variant in snapshot["players"]:
		var player: Array = player_value
		var state := PlayerState.new(int(player[0]))
		_apply_values(state, player[3])
		state.last_event = String(player[2])
		world.players.append(state)
	for values_value: Variant in snapshot["targets"]:
		var values: PackedInt64Array = values_value
		var target := PlayerState.new(values[0])
		target.actor_kind = PlayerState.ActorKind.TRAINING_TARGET
		target.team_id = target.entity_id
		target.position_x = values[1]
		target.position_y = values[2]
		target.radius = values[3]
		target.health_maximum = values[4]
		target.health = values[5]
		target.training_respawn_ticks = values[6]
		target.training_spawn_x = values[7]
		target.training_spawn_y = values[8]
		target.spell_status_values = PackedInt32Array(Array(values.slice(10)))
		target.spawn_protection_ticks = values[9]
		target.health_recovery_per_second = 0
		target.flux_maximum = 0
		target.flux = 0
		target.stamina_maximum = 0
		target.stamina = 0
		target.movement_speed_ratio = 0
		world.players.append(target)
	world.players.sort_custom(func(left: PlayerState, right: PlayerState) -> bool: return left.entity_id < right.entity_id)
	world.tick = int(snapshot["tick"])
	world.projectiles = []
	var projectile_values: PackedInt32Array = snapshot["projectiles"]
	for offset: int in range(0, projectile_values.size(), PROJECTILE_VALUE_COUNT):
		world.projectiles.append(_projectile_from_values(projectile_values.slice(offset, offset + PROJECTILE_VALUE_COUNT)))
	world.fields = []
	var field_values: PackedInt32Array = snapshot["fields"]
	for offset: int in range(0, field_values.size(), FIELD_VALUE_COUNT):
		world.fields.append(_field_from_values(field_values.slice(offset, offset + FIELD_VALUE_COUNT), world))
	world.deposits.clear()
	for values: PackedInt32Array in snapshot["deposits"]:
		world.deposits.append(DepositState.from_values(PackedInt64Array(Array(values))))
	world.reactions.clear()
	for values: PackedInt32Array in snapshot["reactions"]:
		world.reactions.append(ReactionState.from_values(PackedInt64Array(Array(values))))
	world.combat_events = []
	for values_value: Variant in snapshot["events"]:
		world.combat_events.append(decode_event(values_value))
	return true


static func names(snapshot: Dictionary) -> Dictionary[int, String]:
	var result: Dictionary[int, String] = {}
	if not validate(snapshot):
		return result
	for player_value: Variant in snapshot["players"]:
		var player: Array = player_value
		result[int(player[0])] = String(player[1])
	return result


static func hearth(snapshot: Dictionary) -> Dictionary:
	return SessionHearth.decoded(snapshot.get("hearth", PackedInt32Array())) if validate(snapshot) else {}


static func hearth_values(snapshot: Dictionary) -> PackedInt32Array:
	return snapshot.get("hearth", PackedInt32Array()).duplicate() if validate(snapshot) else PackedInt32Array()


static func round_state(snapshot: Dictionary) -> Dictionary:
	return SessionRound.decoded(snapshot.get("round", PackedInt32Array())) if validate(snapshot) else {}


static func round_values(snapshot: Dictionary) -> PackedInt32Array:
	return snapshot.get("round", PackedInt32Array()).duplicate() if validate(snapshot) else PackedInt32Array()


static func _apply_values(state: PlayerState, values: PackedInt32Array) -> void:
	state.champion_wire_id = values[0]
	state.position_x = values[1]
	state.position_y = values[2]
	state.velocity_x = values[3]
	state.velocity_y = values[4]
	state.facing_x = values[5]
	state.facing_y = values[6]
	state.aim_x = values[7]
	state.aim_y = values[8]
	state.radius = values[9]
	state.movement_mode = values[10]
	state.health_maximum = values[11]
	state.health = values[12]
	state.flux_maximum = values[13]
	state.flux = values[14]
	state.stamina_maximum = values[15]
	state.stamina = values[16]
	state.hop_ticks = values[17]
	state.hop_mode = values[18]
	state.air_dodge_ticks = values[19]
	state.superglide_ticks = values[20]
	state.vault_ticks = values[21]
	state.wave_dash_ticks = values[22]
	state.slide_ticks = values[23]
	state.landing_ticks = values[24]
	state.landing_intensity = values[25]
	state.control_state = values[26]
	state.control_ticks = values[27]
	state.primary_wire_id = values[28]
	state.active_1_wire_id = values[29]
	state.slow_ratio = values[30]
	state.team_id = values[31]
	state.sprinting = values[32] == 1
	state.fast_falling = values[33] == 1
	state.cast_recovery_ticks = values[34]
	state.pending_cast_wire_id = values[35]
	state.pending_cast_ticks = values[36]
	state.primary_cooldown_ticks = values[37]
	state.active_1_cooldown_ticks = values[38]
	state.edgeweave_cooldown_ticks = values[39]
	state.primary_held = values[40] == 1
	state.pending_cast_aim_x = values[41]
	state.pending_cast_aim_y = values[42]
	state.spawn_protection_ticks = values[43]
	state.active_2_wire_id = values[47]
	state.active_2_cooldown_ticks = values[48]
	state.spell_wire_ids = values.slice(49, 49 + PlayerState.SPELL_SLOT_COUNT)
	state.spell_cooldown_ticks = values.slice(49 + PlayerState.SPELL_SLOT_COUNT, 49 + 2 * PlayerState.SPELL_SLOT_COUNT)
	_decode_movement_context(state, values[73])
	for index: int in range(MOVEMENT_PRESENTATION_FIELDS.size()):
		var property_name := MOVEMENT_PRESENTATION_FIELDS[index]
		var value: int = values[74 + index]
		state.set(property_name, value == 1 if property_name in [&"air_dodge_used", &"jump_held_last_tick", &"air_floating", &"float_used", &"flight_capable", &"jumpsquat_active", &"double_jump_used", &"wallrun_armed", &"crouching"] else value)
	state.spell_status_values = values.slice(PLAYER_BASE_VALUE_COUNT)
	state._sync_legacy_spell_cooldowns()


static func _encode_movement_context(state: PlayerState) -> int:
	var protection := clampi(state.jump_protection_ticks, 0, MOVEMENT_CONTEXT_PROTECTION_MASK)
	var sustain := clampi(state.jump_sustain_ticks, 0, MOVEMENT_CONTEXT_SUSTAIN_MASK)
	var chain := clampi(state.movement_chain_count, 0, MOVEMENT_CONTEXT_CHAIN_MASK)
	var reset := clampi(state.movement_chain_reset_ticks, 0, MOVEMENT_CONTEXT_RESET_MASK)
	return protection | (sustain << MOVEMENT_CONTEXT_SUSTAIN_SHIFT) | (chain << MOVEMENT_CONTEXT_CHAIN_SHIFT) | (reset << MOVEMENT_CONTEXT_RESET_SHIFT)


static func _decode_movement_context(state: PlayerState, encoded: int) -> void:
	state.jump_protection_ticks = encoded & MOVEMENT_CONTEXT_PROTECTION_MASK
	state.jump_sustain_ticks = (encoded >> MOVEMENT_CONTEXT_SUSTAIN_SHIFT) & MOVEMENT_CONTEXT_SUSTAIN_MASK
	state.movement_chain_count = (encoded >> MOVEMENT_CONTEXT_CHAIN_SHIFT) & MOVEMENT_CONTEXT_CHAIN_MASK
	state.movement_chain_reset_ticks = (encoded >> MOVEMENT_CONTEXT_RESET_SHIFT) & MOVEMENT_CONTEXT_RESET_MASK


static func _valid_movement_context(encoded: int) -> bool:
	if encoded < 0 or encoded > 0xffffff:
		return false
	var chain := (encoded >> MOVEMENT_CONTEXT_CHAIN_SHIFT) & MOVEMENT_CONTEXT_CHAIN_MASK
	return chain <= MovementTuning.MOVEMENT_CHAIN_MAXIMUM_STEPS


static func _valid_player_values(values: PackedInt32Array) -> bool:
	if values.size() != PLAYER_VALUE_COUNT or not SpellStateCodec.valid_status_values(values.slice(PLAYER_BASE_VALUE_COUNT)): return false
	var target_x: int = values[74 + MOVEMENT_PRESENTATION_FIELDS.find(&"pending_cast_target_x")]
	var target_y: int = values[74 + MOVEMENT_PRESENTATION_FIELDS.find(&"pending_cast_target_y")]
	if (target_x == -1) != (target_y == -1):
		return false
	for index: int in range(MOVEMENT_PRESENTATION_FIELDS.size()):
		var value: int = values[74 + index]
		var property_name := MOVEMENT_PRESENTATION_FIELDS[index]
		if property_name in [&"wall_x", &"wall_y", &"hop_x", &"hop_y", &"air_dodge_x", &"air_dodge_y"]:
			if value < -1000 or value > 1000:
				return false
		elif property_name in [&"hop_stage", &"air_redirects_remaining"]:
			if value < 0 or value > 2:
				return false
		elif property_name in [&"movement_action_speed", &"hop_speed"]:
			if value < 0 or value > MovementTuning.MAX_AUTHORED_SPEED:
				return false
		elif property_name == &"air_height":
			if value < 0 or value > MovementTuning.AIR_MAX_HEIGHT:
				return false
		elif property_name == &"air_vertical_velocity":
			if value < -MovementTuning.AIR_TERMINAL_FALL_SPEED or value > MovementTuning.CHARGED_JUMP_VERTICAL_SPEED:
				return false
		elif property_name == &"jumpsquat_ticks":
			if value < 0 or value > (MovementTuning.JUMPSQUAT_CHARGE_MS * 120 + 999) / 1000:
				return false
		elif property_name == &"air_height_remainder":
			if absi(value) >= 2 * 120:
				return false
		elif property_name in [&"air_dodge_used", &"jump_held_last_tick", &"air_floating", &"float_used", &"flight_capable", &"jumpsquat_active", &"double_jump_used", &"wallrun_armed", &"crouching"]:
			if value not in [0, 1]:
				return false
		elif property_name == &"float_max_duration_ms":
			if value not in [MovementTuning.FLOAT_SMALL_DURATION_MS, MovementTuning.FLOAT_MIDDLE_DURATION_MS, MovementTuning.FLOAT_LARGE_DURATION_MS]:
				return false
		elif property_name == &"float_ticks":
			var maximum_ms: int = values[74 + MOVEMENT_PRESENTATION_FIELDS.find(&"float_max_duration_ms")]
			if value < 0 or value > (maximum_ms * 120 + 999) / 1000:
				return false
		elif property_name in [&"chemistry_reveal_ticks", &"chemistry_conceal_ticks", &"chemistry_regen_block_ticks"]:
			if value < 0 or value > 120:
				return false
		elif property_name in [&"pending_cast_target_x", &"pending_cast_target_y"]:
			if value < -1 or value > MAX_ABSOLUTE_POSITION:
				return false
		elif property_name in [&"stamina_recovery_idle_ticks", &"flux_recovery_idle_ticks"]:
			if value < 0 or value > ResourceRecovery.maximum_idle_ticks(120):
				return false
		elif property_name in [&"stamina_recovery_per_second", &"flux_recovery_per_second"]:
			if value < 0 or value > 1_000_000:
				return false
		elif value < 0 or value > MAX_TIMER_TICKS:
			return false
	if values[0] <= 0 or values[0] > 4096:
		return false
	for index: int in [1, 2]:
		if absi(values[index]) > MAX_ABSOLUTE_POSITION:
			return false
	for index: int in [3, 4]:
		if absi(values[index]) > 10_000_000:
			return false
	for index: int in [5, 6, 7, 8]:
		if values[index] < -1000 or values[index] > 1000:
			return false
	if values[9] <= 0 or values[9] > 100_000:
		return false
	if values[10] < 0 or values[10] >= PlayerState.MovementMode.size():
		return false
	for pair: Vector2i in [Vector2i(11, 12), Vector2i(13, 14), Vector2i(15, 16)]:
		if values[pair.x] < 0 or values[pair.x] > 1_000_000 or values[pair.y] < 0 or values[pair.y] > values[pair.x]:
			return false
	for index: int in [17, 19, 20, 21, 22, 23, 24, 27, 34, 36, 37, 38, 39, 43, 48]:
		if values[index] < 0 or values[index] > MAX_TIMER_TICKS:
			return false
	if not _valid_movement_context(values[73]):
		return false
	if values[18] < 0 or values[18] >= PlayerState.MovementMode.size():
		return false
	if values[25] < 0 or values[25] > 1000:
		return false
	if values[26] < 0 or values[26] >= PlayerState.ControlState.size():
		return false
	for index: int in [28, 29]:
		if values[index] <= 0 or values[index] > 65_535:
			return false
	if values[30] < MovementTuning.SLOW_MINIMUM_RATIO or values[30] > 1000 or values[31] < 0 or values[31] > 32:
		return false
	if values[35] < 0 or values[35] > 65_535 or values[40] not in [0, 1]:
		return false
	for index: int in [41, 42]:
		if values[index] < -1000 or values[index] > 1000:
			return false
	var primary_slot: int = values[44]
	var active_slot: int = values[45]
	var active_2_slot: int = values[46]
	if primary_slot < -1 or primary_slot >= PlayerState.SPELL_SLOT_COUNT:
		return false
	if active_slot < -1 or active_slot >= PlayerState.SPELL_SLOT_COUNT or (active_slot >= 0 and active_slot == primary_slot):
		return false
	if values[47] < 0 or values[47] > 65_535 or (values[47] > 0 and values[47] in [values[28], values[29]]):
		return false
	if values[47] == 0 and active_2_slot != -1:
		return false
	if values[47] > 0 and (active_2_slot < -1 or active_2_slot >= PlayerState.SPELL_SLOT_COUNT or (active_2_slot >= 0 and active_2_slot in [primary_slot, active_slot])):
		return false
	var spell_wires: PackedInt32Array = values.slice(49, 49 + PlayerState.SPELL_SLOT_COUNT)
	var spell_cooldowns: PackedInt32Array = values.slice(49 + PlayerState.SPELL_SLOT_COUNT, 49 + 2 * PlayerState.SPELL_SLOT_COUNT)
	var seen_spell_wires: Dictionary[int, bool] = {}
	for slot_index: int in range(PlayerState.SPELL_SLOT_COUNT):
		var wire_id: int = spell_wires[slot_index]
		if wire_id < 0 or wire_id > 65_535 or (wire_id > 0 and not CombatTuning.is_runtime_wire_id(wire_id)):
			return false
		if wire_id > 0:
			if seen_spell_wires.has(wire_id):
				return false
			seen_spell_wires[wire_id] = true
		if spell_cooldowns[slot_index] < 0 or spell_cooldowns[slot_index] > MAX_TIMER_TICKS:
			return false
	if spell_wires.find(values[28]) != primary_slot or spell_wires.find(values[29]) != active_slot:
		return false
	if spell_wires.find(values[47]) != active_2_slot and values[47] > 0:
		return false
	if primary_slot >= 0 and spell_cooldowns[primary_slot] != values[37]:
		return false
	if active_slot >= 0 and spell_cooldowns[active_slot] != values[38]:
		return false
	if values[47] > 0 and active_2_slot >= 0 and spell_cooldowns[active_2_slot] != values[48]:
		return false
	return values[32] in [0, 1] and values[33] in [0, 1]


static func _projectile_from_values(values: PackedInt32Array) -> ProjectileState:
	var projectile := ProjectileState.new(
		values[0],
		values[1],
		0,
		values[2],
		values[3],
		Vector2i(values[4], values[5]),
		Vector2i(values[8], values[9]),
		values[10],
		0,
		values[11],
	)
	projectile.previous_x = values[6]
	projectile.previous_y = values[7]
	projectile.remaining_distance = values[12]
	projectile.source_cast_id = values[13]
	projectile.material_strength = values[14]
	projectile.chemistry_interaction_mask = values[15] | (int(values[16]) << 31)
	projectile.reaction_strength = values[17]
	if not SpellStateCodec.restore_delivery(projectile, values.slice(PROJECTILE_BASE_VALUE_COUNT)): return null
	return projectile


static func _valid_projectile_values(values: PackedInt32Array) -> bool:
	if values.size() != PROJECTILE_VALUE_COUNT or not SpellStateCodec.valid_delivery(values.slice(PROJECTILE_BASE_VALUE_COUNT), values[2]): return false
	# The legacy envelope is still a network boundary. It must not admit retired
	# ingredients or let a live spell claim another element beside the Hex lane.
	var definition := CombatTuning.cast_definition_view(values[2])
	if definition.is_empty() or String(definition.get("shape", "")) != "projectile" or not ElementRules.is_active_wire(values[3]) or int(definition.get("element_wire_id", 0)) != values[3]:
		return false
	if values[12] < -1 or values[12] > MAX_PROJECTILE_REMAINING_DISTANCE or values[13] < 0 or values[13] > 0x7fffffff:
		return false
	# Zero is a canonically spent chemistry payload; the damaging projectile
	# still flies, but cannot regenerate ingredients after an early trail combo.
	if values[14] < 0 or values[14] > 1000 or values[15] < 0 or values[16] < 0 or values[16] > 31 or values[17] < 1 or values[17] > 15:
		return false
	if values[0] <= 0 or values[0] > 0x7fffffff:
		return false
	if values[1] < 1 or values[1] > MAX_PLAYERS:
		return false
	for index: int in [2, 3]:
		if values[index] <= 0 or values[index] > 65_535:
			return false
	for index: int in [4, 5, 6, 7]:
		if absi(values[index]) > MAX_ABSOLUTE_POSITION:
			return false
	for index: int in [8, 9]:
		if absi(values[index]) > 10_000_000:
			return false
	return values[10] > 0 and values[10] <= 100_000 and values[11] >= 0 and values[11] <= MAX_TIMER_TICKS


static func _fits_int32(values: PackedInt64Array) -> bool:
	for value: int in values:
		if value < -0x80000000 or value > 0x7fffffff:
			return false
	return true


static func _field_from_values(values: PackedInt32Array, world: SimWorld) -> FieldState:
	var owner: PlayerState = world.player(values[1])
	var definition := CombatTuning.cast_definition(values[2])
	var field := FieldState.new(
		values[0], values[1], owner.team_id if owner != null else values[1],
		values[2], int(definition.get("element_wire_id", 0)), Vector2i(values[3], values[4]),
		int(definition.get("radius", 0)), values[5],
		int(definition.get("hit_control_state", PlayerState.ControlState.SLOWED)),
		int(definition.get("hit_control_duration_ms", 0)),
		int(definition.get("hit_control_slow_ratio", 1000)),
	)
	for entity_id: int in range(1, MAX_PLAYERS + 1):
		if (values[6] & (1 << (entity_id - 1))) != 0:
			field.record_affected(entity_id)
	return field


static func _valid_field_values(values: PackedInt32Array) -> bool:
	if values[0] <= 0 or values[0] > 0x7fffffff:
		return false
	if values[1] < 1 or values[1] > MAX_PLAYERS:
		return false
	if values[2] <= 0 or values[2] > 65_535 or String(CombatTuning.cast_definition(values[2]).get("shape", "")) != "field":
		return false
	for index: int in [3, 4]:
		if absi(values[index]) > MAX_ABSOLUTE_POSITION:
			return false
	return values[5] > 0 and values[5] <= MAX_TIMER_TICKS and values[6] >= 0 and values[6] < (1 << MAX_PLAYERS)


static func _valid_target_values(values: PackedInt64Array) -> bool:
	if values.size() != TARGET_VALUE_COUNT or not SpellStateCodec.valid_status_values(values.slice(10)): return false
	if values[0] <= MAX_PLAYERS or values[0] > 0x7fffffff:
		return false
	for index: int in [1, 2, 7, 8]:
		if absi(values[index]) > MAX_ABSOLUTE_POSITION:
			return false
	if values[3] <= 0 or values[3] > 100_000:
		return false
	if values[6] < 0 or values[6] > MAX_TIMER_TICKS or values[9] < 0 or values[9] > MAX_TIMER_TICKS:
		return false
	if values[5] > 0 and values[6] != 0:
		return false
	return values[4] > 0 and values[4] <= 10_000_000 and values[5] >= 0 and values[5] <= values[4]


static func encode_event(event: Dictionary) -> PackedInt64Array:
	var event_id := int(event.get("event_id", 0))
	if event_id < 0 or event_id > MAX_EVENT_ID:
		return PackedInt64Array()
	match String(event.get("type", "")):
		"cast_started":
			return PackedInt64Array([_event_header(1, event_id), int(event.get("entity_id", 0)), int(event.get("wire_id", 0)), 0, 0, 0])
		"cast_refused":
			var reason_code: int = {"kit": 1, "flux": 2, "capacity": 4}.get(String(event.get("reason", "")), 3)
			return PackedInt64Array([_event_header(2, event_id), int(event.get("entity_id", 0)), int(event.get("wire_id", 0)), reason_code, 0, 0])
		"cast_blocked":
			return PackedInt64Array([_event_header(3, event_id), int(event.get("entity_id", 0)), int(event.get("wire_id", 0)), 0, 0, 0])
		"projectile_spawned":
			return PackedInt64Array([_event_header(4, event_id), int(event.get("projectile_id", 0)), int(event.get("owner_id", 0)), int(event.get("wire_id", 0)), 0, 0])
		"projectile_hit":
			return PackedInt64Array([_event_header(5, event_id), int(event.get("projectile_id", 0)), int(event.get("source_wire_id", 0)), int(event.get("owner_id", 0)), int(event.get("target_id", 0)), int(event.get("damage", 0))])
		"projectile_impact":
			return PackedInt64Array([_event_header(6, event_id), int(event.get("projectile_id", 0)), int(event.get("wall_id", 0)), 0, 0, 0])
		"projectile_bounced":
			return PackedInt64Array([_event_header(7, event_id), int(event.get("projectile_id", 0)), int(event.get("wall_id", 0)), int(event.get("remaining_bounces", 0)), 0, 0])
		"projectile_expired":
			return PackedInt64Array([_event_header(8, event_id), int(event.get("projectile_id", 0)), 0, 0, 0, 0])
		"edgeweave":
			return PackedInt64Array([_event_header(9, event_id), int(event.get("entity_id", 0)), int(event.get("projectile_id", 0)), int(event.get("stamina", 0)), 0, 0])
		"social_emote":
			return PackedInt64Array([_event_header(10, event_id), int(event.get("entity_id", 0)), int(event.get("emote_id", 0)), 0, 0, 0])
		"station_confirmed":
			return PackedInt64Array([_event_header(11, event_id), int(event.get("entity_id", 0)), int(event.get("action", 0)), int(event.get("sequence", 0)) if int(event.get("action", 0)) == SessionTransport.REQUEST_WEAVE_APPLY else 0, int(event.get("champion_wire_id", 0)) if int(event.get("action", 0)) == SessionTransport.REQUEST_WEAVE_APPLY else 0, 0])
		"champion_attuned":
			return PackedInt64Array([_event_header(12, event_id), int(event.get("entity_id", 0)), int(event.get("champion_wire_id", 0)), 0, 0, 0])
		"request_refused":
			return PackedInt64Array([_event_header(13, event_id), int(event.get("entity_id", 0)), int(event.get("action", 0)), int(event.get("reason", 0)), int(event.get("sequence", 0)) if int(event.get("action", 0)) == SessionTransport.REQUEST_WEAVE_APPLY else 0, 0])
		"ready_changed":
			return PackedInt64Array([_event_header(14, event_id), int(event.get("entity_id", 0)), int(bool(event.get("ready", false))), 0, 0, 0])
		"practice_countdown":
			return PackedInt64Array([_event_header(15, event_id), int(event.get("entity_id", 0)), int(event.get("duration_ticks", 0)), 0, 0, 0])
		"practice_started":
			return PackedInt64Array([_event_header(16, event_id), int(event.get("entity_id", 0)), 0, 0, 0, 0])
		"practice_cancelled":
			return PackedInt64Array([_event_header(17, event_id), int(event.get("entity_id", 0)), int(event.get("reason", 0)), 0, 0, 0])
		"round_knockout":
			var owner := int(event.get("owner_id", 0))
			var target := int(event.get("target_id", 0))
			var scored := bool(event.get("scored", owner > 0 and owner != target))
			return PackedInt64Array([_event_header(18, event_id), owner, target, int(event.get("score", 0)), int(scored) | (int(event.get("credited_team_id", 0)) << 1), int(event.get("team_score", 0))])
		"round_respawned":
			return PackedInt64Array([_event_header(19, event_id), int(event.get("entity_id", 0)), 0, 0, 0, 0])
		"round_finished":
			return PackedInt64Array([_event_header(20, event_id), int(event.get("winner_id", 0)), int(event.get("winner_team_id", 0)), int(event.get("result_reason", 0)), 0, 0])
		"round_returning":
			return PackedInt64Array([_event_header(21, event_id), SessionCharter.HOST_ENTITY_ID, 0, 0, 0, 0])
		"beam_fired":
			return PackedInt64Array([_event_header(22, event_id), int(event.get("owner_id", 0)), int(event.get("source_wire_id", 0)), int(event.get("target_id", 0)), int(event.get("end_x", 0)), int(event.get("end_y", 0)), int(event.get("origin_x", -1)), int(event.get("origin_y", -1))])
		"spray_fired":
			return PackedInt64Array([_event_header(23, event_id), int(event.get("owner_id", 0)), int(event.get("source_wire_id", 0)), int(event.get("end_x", 0)), int(event.get("end_y", 0)), int(event.get("hit_count", 0)), int(event.get("range", -1)), 0])
		"spray_hit":
			return PackedInt64Array([_event_header(24, event_id), int(event.get("owner_id", 0)), int(event.get("source_wire_id", 0)), int(event.get("target_id", 0)), int(event.get("damage", 0)), 0])
		"field_triggered":
			return PackedInt64Array([_event_header(25, event_id), int(event.get("owner_id", 0)), int(event.get("source_wire_id", 0)), int(event.get("target_id", 0)), int(event.get("field_id", 0)), 0])
		"spray_intercepted":
			return PackedInt64Array([_event_header(26, event_id), int(event.get("owner_id", 0)), int(event.get("source_wire_id", 0)), int(event.get("projectile_id", 0)), int(event.get("other_wire_id", 0)), int(event.get("x", 0)), int(event.get("y", 0)), int(event.get("outcome", 0))])
		"hex_clash":
			for key: String in ["source_wire_id", "other_wire_id", "x", "y", "first_remaining", "second_remaining"]:
				if typeof(event.get(key)) != TYPE_INT:
					return PackedInt64Array()
			return PackedInt64Array([_event_header(27, event_id), int(event.source_wire_id), int(event.other_wire_id), int(event.x), int(event.y), int(event.first_remaining), int(event.second_remaining), 0])
		_:
			return PackedInt64Array()


static func decode_event(values: PackedInt64Array) -> Dictionary:
	var header := int(values[0])
	var kind := header & EVENT_KIND_MASK
	var event_id := header >> 8
	var result: Dictionary = {}
	match kind:
		1:
			result = {"type": "cast_started", "entity_id": values[1], "wire_id": values[2]}
		2:
			var reason: String = {1: "kit", 2: "flux", 3: "other", 4: "capacity"}.get(values[3], "other")
			result = {"type": "cast_refused", "entity_id": values[1], "wire_id": values[2], "reason": reason}
		3:
			result = {"type": "cast_blocked", "entity_id": values[1], "wire_id": values[2]}
		4:
			result = {"type": "projectile_spawned", "projectile_id": values[1], "owner_id": values[2], "wire_id": values[3]}
		5:
			result = {"type": "projectile_hit", "projectile_id": values[1], "source_wire_id": values[2], "owner_id": values[3], "target_id": values[4], "damage": values[5]}
		6:
			result = {"type": "projectile_impact", "projectile_id": values[1], "wall_id": values[2]}
		7:
			result = {"type": "projectile_bounced", "projectile_id": values[1], "wall_id": values[2], "remaining_bounces": values[3]}
		8:
			result = {"type": "projectile_expired", "projectile_id": values[1]}
		9:
			result = {"type": "edgeweave", "entity_id": values[1], "projectile_id": values[2], "stamina": values[3]}
		10:
			result = {"type": "social_emote", "entity_id": values[1], "emote_id": values[2]}
		11:
			result = {"type": "station_confirmed", "entity_id": values[1], "action": values[2]}
			if values[2] == SessionTransport.REQUEST_WEAVE_APPLY:
				result.sequence = values[3]
				result.champion_wire_id = values[4]
		12:
			result = {"type": "champion_attuned", "entity_id": values[1], "champion_wire_id": values[2]}
		13:
			result = {"type": "request_refused", "entity_id": values[1], "action": values[2], "reason": values[3]}
			if values[2] == SessionTransport.REQUEST_WEAVE_APPLY: result.sequence = values[4]
		14:
			result = {"type": "ready_changed", "entity_id": values[1], "ready": values[2] == 1}
		15:
			result = {"type": "practice_countdown", "entity_id": values[1], "duration_ticks": values[2]}
		16:
			result = {"type": "practice_started", "entity_id": values[1]}
		17:
			result = {"type": "practice_cancelled", "entity_id": values[1], "reason": values[2]}
		18:
			result = {"type": "round_knockout", "owner_id": values[1], "target_id": values[2], "score": values[3], "scored": (values[4] & 1) == 1, "credited_team_id": values[4] >> 1, "team_score": values[5]}
		19:
			result = {"type": "round_respawned", "entity_id": values[1]}
		20:
			result = {"type": "round_finished", "winner_id": values[1], "winner_team_id": values[2], "result_reason": values[3]}
		21:
			result = {"type": "round_returning", "entity_id": values[1]}
		22:
			result = {"type": "beam_fired", "owner_id": values[1], "source_wire_id": values[2], "target_id": values[3], "end_x": values[4], "end_y": values[5]}
			if values[6] != -1 or values[7] != -1:
				result["origin_x"] = values[6]
				result["origin_y"] = values[7]
		23:
			result = {"type": "spray_fired", "owner_id": values[1], "source_wire_id": values[2], "end_x": values[3], "end_y": values[4], "hit_count": values[5]}
			if values[6] >= 0:
				result["range"] = values[6]
		24:
			result = {"type": "spray_hit", "owner_id": values[1], "source_wire_id": values[2], "target_id": values[3], "damage": values[4]}
		25:
			result = {"type": "field_triggered", "owner_id": values[1], "source_wire_id": values[2], "target_id": values[3], "field_id": values[4]}
		26:
			result = {"type": "spray_intercepted", "owner_id": values[1], "source_wire_id": values[2], "projectile_id": values[3], "other_wire_id": values[4], "x": values[5], "y": values[6], "outcome": values[7]}
		27:
			result = {"type": "hex_clash", "source_wire_id": values[1], "other_wire_id": values[2], "x": values[3], "y": values[4], "first_remaining": values[5], "second_remaining": values[6]}
	if not result.is_empty() and event_id > 0:
		result["event_id"] = event_id
	return result


static func _valid_event_values(values: PackedInt64Array) -> bool:
	if values.is_empty():
		return false
	var header := int(values[0])
	if header <= 0:
		return false
	var kind := header & EVENT_KIND_MASK
	if values.size() != (8 if kind in [22, 23, 26, 27] else EVENT_VALUE_COUNT):
		return false
	var event_id := header >> 8
	if event_id < 0 or event_id > MAX_EVENT_ID:
		return false
	if kind < 1 or kind > 27:
		return false
	if kind == 26:
		return values[1] >= 1 and values[1] <= MAX_PLAYERS and values[2] > 0 and values[2] <= 65535 \
			and values[3] > 0 and values[3] <= 0x7fffffff and values[4] > 0 and values[4] <= 65535 \
			and absi(values[5]) <= MAX_ABSOLUTE_POSITION and absi(values[6]) <= MAX_ABSOLUTE_POSITION and values[7] in [1, 2]
	if kind == 27:
		return CombatTuning.is_runtime_wire_id(values[1]) and CombatTuning.is_runtime_wire_id(values[2]) \
			and absi(values[3]) <= MAX_ABSOLUTE_POSITION and absi(values[4]) <= MAX_ABSOLUTE_POSITION \
			and values[5] >= 0 and values[5] <= 15 and values[6] >= 0 and values[6] <= 15 and values[7] == 0
	if kind in [1, 2, 3]:
		if values[1] < 1 or values[1] > MAX_PLAYERS or values[2] <= 0 or values[2] > 65_535:
			return false
		return kind != 2 or values[3] in [1, 2, 3, 4]
	if kind == 4:
		return values[1] > 0 and values[2] >= 1 and values[2] <= MAX_PLAYERS and values[3] > 0 and values[3] <= 65_535
	if kind == 5:
		return values[1] > 0 and values[2] > 0 and values[2] <= 65_535 and values[3] >= 1 and values[3] <= MAX_PLAYERS and values[4] >= 1 and values[4] <= 0x7fffffff and values[5] > 0 and values[5] <= 1_000_000
	if kind in [6, 7]:
		# CollisionWorld uses -1/-2 for the X/Y world boundaries. These are
		# real impact surfaces, not malformed obstacle IDs.
		return values[1] > 0 and (values[2] >= 0 or values[2] in WORLD_BOUNDARY_WALL_IDS) and (kind != 7 or (values[3] >= 0 and values[3] <= 8))
	if kind == 8:
		return values[1] > 0
	if kind == 9:
		return values[1] >= 1 and values[1] <= MAX_PLAYERS and values[2] > 0 and values[3] > 0 and values[3] <= 1_000_000
	if kind == 18:
		var scored := (values[4] & 1) == 1
		var credited_team := values[4] >> 1
		return values[1] >= 0 and values[1] <= MAX_PLAYERS and values[2] >= 1 and values[2] <= MAX_PLAYERS \
			and values[3] >= 0 and values[3] <= SessionRound.MAX_SCORE_LIMIT and values[4] >= 0 and values[4] <= 5 \
			and values[5] >= 0 and values[5] <= SessionRound.MAX_SCORE_LIMIT \
			and (not scored or (values[1] > 0 and values[1] != values[2])) \
			and (scored or credited_team == 0) and (credited_team > 0 or values[5] == 0)
	if kind == 19:
		return values[1] >= 1 and values[1] <= MAX_PLAYERS
	if kind == 20:
		return values[1] >= 0 and values[1] <= MAX_PLAYERS and values[2] >= 0 and values[2] <= 2 \
			and (values[2] == 0 or values[1] == 0) and values[3] >= 0 and values[3] <= SessionRound.ResultReason.FORFEIT \
			and values[4] == 0 and values[5] == 0
	if kind == 21:
		return values[1] == SessionCharter.HOST_ENTITY_ID
	if kind == 22:
		if (values[6] == -1) != (values[7] == -1) or absi(values[6]) > MAX_ABSOLUTE_POSITION or absi(values[7]) > MAX_ABSOLUTE_POSITION:
			return false
		return (
			values[1] >= 1 and values[1] <= MAX_PLAYERS
			and values[2] > 0 and values[2] <= 65_535
			and values[3] >= 0 and values[3] <= 0x7fffffff
			and absi(values[4]) <= MAX_ABSOLUTE_POSITION
			and absi(values[5]) <= MAX_ABSOLUTE_POSITION
		)
	if kind == 23:
		return (
			values[1] >= 1 and values[1] <= MAX_PLAYERS
			and values[2] > 0 and values[2] <= 65_535
			and absi(values[3]) <= MAX_ABSOLUTE_POSITION
			and absi(values[4]) <= MAX_ABSOLUTE_POSITION
			and values[5] >= 0 and values[5] < MAX_PLAYERS
			and values[6] >= -1 and values[6] <= 1_000_000 and values[7] == 0
		)
	if kind == 24:
		return (
			values[1] >= 1 and values[1] <= MAX_PLAYERS
			and values[2] > 0 and values[2] <= 65_535
			and values[3] >= 1 and values[3] <= 0x7fffffff
			and values[4] > 0 and values[4] <= 1_000_000
		)
	if kind == 25:
		return (
			values[1] >= 1 and values[1] <= MAX_PLAYERS
			and values[2] > 0 and values[2] <= 65_535
			and values[3] >= 1 and values[3] <= 0x7fffffff
			and values[4] > 0 and values[4] <= 0x7fffffff
		)
	if values[1] < 1 or values[1] > MAX_PLAYERS:
		return false
	if kind == 10:
		return values[2] == 1
	if kind == 11:
		if values[2] == SessionTransport.REQUEST_WEAVE_APPLY: return values[3] > 0 and values[3] <= 0x7fffffff and values[4] > 0 and values[4] <= 4096
		return values[2] in [SessionTransport.REQUEST_TRAINING_RESET, SessionTransport.REQUEST_IMPACT_PRACTICE, SessionTransport.REQUEST_WEAVE_APPLY]
	if kind == 12:
		return values[2] > 0 and values[2] <= 4096
	if kind == 13:
		if values[2] == SessionTransport.REQUEST_WEAVE_APPLY and (values[4] <= 0 or values[4] > 0x7fffffff): return false
		return values[2] in [SessionTransport.REQUEST_EMOTE, SessionTransport.REQUEST_TRAINING_RESET, SessionTransport.REQUEST_CHAMPION_NEXT, SessionTransport.REQUEST_READY_TOGGLE, SessionTransport.REQUEST_PRACTICE_START, SessionTransport.REQUEST_SPELL_EQUIP, SessionTransport.REQUEST_IMPACT_PRACTICE, SessionTransport.REQUEST_CHAMPION_SELECT, SessionTransport.REQUEST_WEAVE_APPLY] and values[3] >= 1 and values[3] <= 3
	if kind == 14:
		return values[2] in [0, 1]
	if kind == 15:
		return values[1] == SessionCharter.HOST_ENTITY_ID and values[2] > 0 and values[2] <= SessionHearth.MAX_COUNTDOWN_TICKS
	if kind == 16:
		return values[1] == SessionCharter.HOST_ENTITY_ID
	if kind == 17:
		return values[1] == SessionCharter.HOST_ENTITY_ID and values[2] in [1, 2]
	return false


static func _event_header(kind: int, event_id: int) -> int:
	return (event_id << 8) | kind


static func _safe_event_name(requested_name: String) -> String:
	var safe_name := requested_name.strip_edges()
	if safe_name.is_empty() or safe_name.length() > 48:
		return ""
	for character: String in safe_name:
		if character not in "abcdefghijklmnopqrstuvwxyz0123456789_":
			return ""
	return safe_name


static func _safe_name(requested_name: String) -> String:
	var safe_name := requested_name.strip_edges().left(SessionTransport.MAX_PLAYER_NAME_LENGTH)
	if safe_name.is_empty():
		return ""
	for character: String in safe_name:
		var codepoint := character.unicode_at(0)
		if codepoint < 32 or codepoint == 127:
			return ""
	return safe_name
