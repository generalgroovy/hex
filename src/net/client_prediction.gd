class_name ClientPrediction
extends RefCounted

const ExpandedSpellState = preload("res://src/net/expanded_spell_state_codec.gd")


const MAX_PENDING_INPUTS: int = 48
const SOFT_CORRECTION_LIMIT_PIXELS: float = 72.0
const CORRECTION_RECOVERY_PIXELS_PER_SECOND: float = 720.0
const MOVEMENT_HELD_MASK: int = SimCommand.HELD_SPRINT | SimCommand.HELD_JUMP | SimCommand.HELD_FAST_FALL
const MOVEMENT_PRESSED_MASK: int = SimCommand.PRESSED_EVADE | SimCommand.PRESSED_JUMP | SimCommand.PRESSED_TECHNIQUE | SimCommand.PRESSED_SLIDE | SimCommand.PRESSED_CANCEL_MOVEMENT
const STATE_FIELDS: Array[StringName] = [
	&"entity_id",
	&"position_x", &"position_y", &"position_remainder_x", &"position_remainder_y",
	&"velocity_x", &"velocity_y",
	&"air_velocity_x", &"air_velocity_y", &"movement_commitment_ticks", &"wall_air_ticks",
	&"slide_held_last_tick", &"fast_fall_armed", &"evade_buffer_airborne",
	&"air_height", &"air_vertical_velocity", &"air_height_remainder", &"air_dodge_used", &"jump_held_last_tick", &"air_floating",
	&"float_used", &"float_ticks", &"float_max_duration_ms",
	&"chemistry_reveal_ticks", &"chemistry_conceal_ticks", &"chemistry_regen_block_ticks",
	&"facing_x", &"facing_y", &"aim_x", &"aim_y",
	&"radius", &"movement_mode",
	&"stamina_maximum", &"stamina_recovery_per_second", &"movement_speed_ratio",
	&"stamina", &"stamina_remainder", &"stamina_recovery_delay_ticks", &"stamina_recovery_idle_ticks",
	&"jump_buffer_ticks", &"technique_buffer_ticks", &"slide_buffer_ticks",
	&"fast_falling", &"variable_jump_grace_ticks",
	&"jump_sustain_ticks", &"movement_chain_count", &"movement_chain_reset_ticks", &"movement_action_speed",
	&"jump_protection_ticks", &"evade_buffer_ticks", &"landing_input_ticks", &"hop_ticks", &"hop_cooldown_ticks", &"hop_stage", &"hop_mode",
	&"landing_input_x", &"landing_input_y", &"hop_speed", &"hop_x", &"hop_y", &"air_redirects_remaining",
	&"air_dodge_ticks", &"air_dodge_cooldown_ticks", &"air_dodge_x", &"air_dodge_y",
	&"wave_dash_queued", &"wave_dash_ticks", &"wave_dash_x", &"wave_dash_y",
	&"slide_ticks", &"slide_cooldown_ticks", &"slide_x", &"slide_y",
	&"vault_ticks", &"vault_cooldown_ticks", &"vault_x", &"vault_y",
	&"superglide_ticks", &"superglide_x", &"superglide_y",
	&"wall_memory_ticks", &"wall_x", &"wall_y", &"wall_contact_id",
	&"wall_lockout_id", &"wall_lockout_ticks",
	&"wall_skim_ticks", &"wall_skim_cooldown_ticks", &"wall_skim_x", &"wall_skim_y",
	&"wall_skim_surface_id", &"wall_skim_lockout_id", &"wall_skim_lockout_ticks",
	&"landing_ticks", &"landing_intensity", &"impact_recovery_ticks", &"sprinting",
	&"control_state", &"control_ticks", &"control_x", &"control_y", &"control_speed", &"slow_ratio",
	&"team_id", &"health", &"spawn_protection_ticks",
	&"flight_capable", &"jumpsquat_active", &"jumpsquat_ticks", &"double_jump_used", &"wallrun_armed", &"crouching",
	&"champion_wire_id", &"health_maximum", &"health_recovery_per_second", &"health_recovery_remainder", &"health_recovery_delay_ticks",
	&"flux", &"flux_maximum", &"flux_recovery_per_second", &"flux_recovery_remainder", &"flux_recovery_delay_ticks", &"flux_recovery_idle_ticks",
	&"pending_cast_wire_id", &"pending_cast_ticks", &"cast_recovery_ticks",
]
const BOOLEAN_FIELDS: Array[StringName] = [&"fast_falling", &"wave_dash_queued", &"sprinting", &"slide_held_last_tick", &"fast_fall_armed", &"evade_buffer_airborne", &"air_dodge_used", &"jump_held_last_tick", &"air_floating", &"float_used", &"flight_capable", &"jumpsquat_active", &"double_jump_used", &"wallrun_armed", &"crouching"]
const DIRECTION_FIELDS: Array[StringName] = [
	&"facing_x", &"facing_y", &"aim_x", &"aim_y",
	&"landing_input_x", &"landing_input_y", &"hop_x", &"hop_y", &"air_dodge_x", &"air_dodge_y",
	&"wave_dash_x", &"wave_dash_y", &"slide_x", &"slide_y",
	&"vault_x", &"vault_y", &"superglide_x", &"superglide_y",
	&"wall_x", &"wall_y", &"wall_skim_x", &"wall_skim_y",
	&"control_x", &"control_y",
]
const TIMER_FIELDS: Array[StringName] = [
	&"jumpsquat_ticks",
	&"spawn_protection_ticks",
	&"movement_commitment_ticks", &"wall_air_ticks",
	&"stamina_recovery_delay_ticks", &"jump_buffer_ticks", &"technique_buffer_ticks", &"slide_buffer_ticks",
	&"jump_protection_ticks", &"evade_buffer_ticks", &"landing_input_ticks",
	&"movement_chain_reset_ticks",
	&"variable_jump_grace_ticks", &"hop_ticks", &"hop_cooldown_ticks",
	&"air_dodge_ticks", &"air_dodge_cooldown_ticks", &"wave_dash_ticks",
	&"slide_ticks", &"slide_cooldown_ticks", &"vault_ticks", &"vault_cooldown_ticks",
	&"superglide_ticks", &"wall_memory_ticks", &"wall_lockout_ticks",
	&"wall_skim_ticks", &"wall_skim_cooldown_ticks", &"wall_skim_lockout_ticks",
	&"landing_ticks", &"impact_recovery_ticks", &"control_ticks",
]

var config: SimConfig
var collision: CollisionWorld
var reaction_movement: ReactionMovementWorld
var reaction_surfaces := PackedInt32Array()
var frostway_lanes := PackedInt32Array()
var capacitor_lanes := PackedInt32Array()
var hex_authority: HexChemistryWorld = null
var hex_context_tick: int = -1
var predicted_tick: int = 0
var local_entity_id: int = 0
var predicted_state: PlayerState
var pending_inputs: Array[Dictionary] = []
var last_queued_sequence: int = -1
var last_acknowledged_sequence: int = -1
var last_authoritative_tick: int = -1
var last_authoritative_position_pixels := Vector2.ZERO
var last_correction_pixels: float = 0.0
var correction_count: int = 0
var hard_snap_count: int = 0
var history_overflowed: bool = false
var visual_offset := Vector2.ZERO


func configure(new_config: SimConfig, new_collision: CollisionWorld, entity_id: int) -> bool:
	reset()
	if new_config == null or not new_config.is_valid() or new_collision == null:
		return false
	if entity_id < 2 or entity_id > SessionTransport.MAX_PLAYERS:
		return false
	config = new_config
	collision = new_collision
	reaction_movement = collision if collision is HexCollisionWorld else ReactionMovementWorld.new(collision)
	local_entity_id = entity_id
	return true


func reset() -> void:
	hex_authority = null
	hex_context_tick = -1
	config = null
	collision = null
	reaction_movement = null
	reaction_surfaces = PackedInt32Array()
	frostway_lanes = PackedInt32Array()
	capacitor_lanes = PackedInt32Array()
	predicted_tick = 0
	local_entity_id = 0
	predicted_state = null
	pending_inputs = []
	last_queued_sequence = -1
	last_acknowledged_sequence = -1
	last_authoritative_tick = -1
	last_authoritative_position_pixels = Vector2.ZERO
	last_correction_pixels = 0.0
	correction_count = 0
	hard_snap_count = 0
	history_overflowed = false
	visual_offset = Vector2.ZERO


func is_ready() -> bool:
	return predicted_state != null and config != null and collision != null


func queue_input(sequence: int, command: SimCommand) -> bool:
	if config == null or collision == null or command == null:
		return false
	if sequence <= last_queued_sequence or sequence < 0 or sequence > 0x7fffffff:
		return false
	if command.entity_id != local_entity_id:
		return false
	var movement_command := SimCommand.new(
		0,
		local_entity_id,
		command.move_x,
		command.move_y,
		command.held_actions & MOVEMENT_HELD_MASK,
		command.pressed_actions & MOVEMENT_PRESSED_MASK,
		command.aim_x,
		command.aim_y,
	)
	pending_inputs.append({"sequence": sequence, "command": movement_command})
	last_queued_sequence = sequence
	if pending_inputs.size() > MAX_PENDING_INPUTS:
		pending_inputs.pop_front()
		history_overflowed = true
	if is_ready():
		_step_prediction(movement_command)
	return true


func reconcile(packet: Dictionary, authoritative_event: String = "network_snapshot", reduced_motion: bool = false) -> bool:
	if not validate_packet(packet) or config == null or collision == null:
		return false
	var values: PackedInt64Array = packet["values"]
	if values[0] != local_entity_id:
		return false
	var authoritative_tick := int(packet["tick"])
	if hex_authority != null and authoritative_tick != hex_context_tick:
		return false # Never replay movement against another snapshot's geometry.
	var acknowledged_sequence := int(packet["sequence"])
	if authoritative_tick <= last_authoritative_tick or acknowledged_sequence < last_acknowledged_sequence:
		return false
	if acknowledged_sequence > last_queued_sequence:
		return false
	var previous_raw := raw_position_pixels()
	var had_prediction := is_ready()
	predicted_state = restore_state(values)
	reaction_surfaces = packet["surfaces"].duplicate()
	frostway_lanes = packet["lanes"].duplicate()
	capacitor_lanes = packet["capacitors"].duplicate()
	predicted_tick = authoritative_tick
	predicted_state.last_event = authoritative_event
	last_authoritative_position_pixels = raw_position_pixels()
	last_authoritative_tick = authoritative_tick
	last_acknowledged_sequence = acknowledged_sequence
	while not pending_inputs.is_empty() and int(pending_inputs.front()["sequence"]) <= acknowledged_sequence:
		pending_inputs.pop_front()
	for pending: Dictionary in pending_inputs:
		_step_prediction(pending["command"])
	var corrected_raw := raw_position_pixels()
	last_correction_pixels = previous_raw.distance_to(corrected_raw) if had_prediction else 0.0
	if had_prediction and last_correction_pixels > 0.01:
		correction_count += 1
	var hard_snap := history_overflowed or reduced_motion or last_correction_pixels > SOFT_CORRECTION_LIMIT_PIXELS
	if hard_snap:
		if had_prediction and last_correction_pixels > 0.01:
			hard_snap_count += 1
		visual_offset = Vector2.ZERO
	elif had_prediction:
		visual_offset += previous_raw - corrected_raw
		if visual_offset.length() > SOFT_CORRECTION_LIMIT_PIXELS:
			visual_offset = visual_offset.normalized() * SOFT_CORRECTION_LIMIT_PIXELS
	else:
		visual_offset = Vector2.ZERO
	history_overflowed = false
	return true


func advance_visual(delta: float) -> void:
	if visual_offset == Vector2.ZERO:
		return
	visual_offset = visual_offset.move_toward(Vector2.ZERO, maxf(0.0, delta) * CORRECTION_RECOVERY_PIXELS_PER_SECOND)
	if visual_offset.length_squared() < 0.0001:
		visual_offset = Vector2.ZERO


func raw_position_pixels() -> Vector2:
	if predicted_state == null:
		return Vector2.ZERO
	return Vector2(float(predicted_state.position_x) / SimConfig.FIXED_SCALE, float(predicted_state.position_y) / SimConfig.FIXED_SCALE)


func presented_position_pixels() -> Vector2:
	return raw_position_pixels() + visual_offset


func pending_count() -> int:
	return pending_inputs.size()


func estimated_ack_delay_ms() -> int:
	if config == null or last_acknowledged_sequence < 0:
		return 0
	return maxi(0, last_queued_sequence - last_acknowledged_sequence) * 1000 / config.tick_rate


func _step_prediction(command: SimCommand) -> void:
	# Identity and paid cast state come from the authoritative snapshot. Forecast
	# recovery and existing cast-clock expiry so movement perk windows stay current.
	# New casts, their payment, and combat outcomes still reconcile from the host.
	if predicted_state.health <= 0:
		SimWorld._idle_defeated(predicted_state)
		predicted_tick += 1
		return
	predicted_state.aim_x = command.aim_x
	predicted_state.aim_y = command.aim_y
	PlayerResourcesSystem.step(predicted_state, config)
	var status_events: Array[Dictionary] = []
	SpellStatusPolicy.advance(predicted_state, config, status_events, false)
	if hex_authority != null:
		hex_authority.expire_at(predicted_tick)
		hex_authority.fracture_products(predicted_tick)
		hex_authority.move_products(predicted_tick, reaction_movement)
	if reaction_movement is HexCollisionWorld:
		reaction_movement.refresh_surfaces(predicted_tick)
	else:
		reaction_movement.set_surfaces(reaction_surfaces, predicted_tick)
	reaction_movement.begin_actor(Vector2i(predicted_state.position_x, predicted_state.position_y), MovementTuning.PLAYER_RADIUS)
	ReactionMovementWorld.clear_stale_contact(predicted_state, reaction_movement)
	var point := Vector2i(predicted_state.position_x, predicted_state.position_y)
	var ground_ratio := FrostwayFieldPolicy.movement_ratio(frostway_lanes, point, predicted_tick)
	if ground_ratio == 1000:
		ground_ratio = CapacitorFieldPolicy.movement_ratio(capacitor_lanes, point, predicted_tick)
	var acceleration_ratio := 1000
	var braking_ratio := 1000
	if hex_authority != null:
		var modifiers := HexProductEffects.pre_movement(hex_authority, predicted_state, predicted_tick, point, config)
		ground_ratio = int(modifiers.ground_target_ratio)
		acceleration_ratio = int(modifiers.acceleration_ratio)
		braking_ratio = int(modifiers.braking_ratio)
	var previous := {"point": point, "height": predicted_state.air_height}
	ground_ratio = mini(ground_ratio, SpellStatusPolicy.movement_ratio(predicted_state))
	MovementSystem.step(predicted_state, command, config, reaction_movement, ground_ratio, acceleration_ratio, braking_ratio)
	# Perk windows use existing authoritative cast clocks. Predict their expiry,
	# never a new cast, projectile, payment or hit that has not been acknowledged.
	predicted_state.cast_recovery_ticks = maxi(0, predicted_state.cast_recovery_ticks - 1)
	if predicted_state.pending_cast_ticks > 0:
		predicted_state.pending_cast_ticks -= 1
		if predicted_state.pending_cast_ticks == 0:
			var definition := CombatTuning.cast_definition(predicted_state.pending_cast_wire_id)
			predicted_state.cast_recovery_ticks = config.milliseconds_to_ticks(int(definition.get("recovery_ms", 0)))
			predicted_state.pending_cast_wire_id = 0
	if hex_authority != null:
		var actors: Array[PlayerState] = [predicted_state]
		var events: Array[Dictionary] = []
		hex_authority.apply_product_effects(actors, predicted_tick, config, reaction_movement, events, {predicted_state.entity_id: previous})
	if CapacitorFieldPolicy.discharge_due(capacitor_lanes, predicted_tick):
		reaction_movement.begin_actor(Vector2i(predicted_state.position_x, predicted_state.position_y), MovementTuning.PLAYER_RADIUS)
		CapacitorFieldPolicy.apply_discharge(capacitor_lanes, predicted_state, predicted_tick, reaction_movement, config)
	predicted_tick += 1


# A matching full snapshot supplies prediction's geometry and timed effects.
# Prediction owns every mutable dictionary and never changes the replica.
func bind_hex_world(world: SimWorld) -> bool:
	var prepared := prepare_hex_context(world)
	if prepared.is_empty(): return false
	publish_hex_context(prepared)
	return true


# Prepare without touching this predictor. The application can therefore stage
# replica, prediction and epoch together, including a failed new-world bind.
func prepare_hex_context(world: SimWorld) -> Dictionary:
	if world == null or world.hex_court == null:
		return {}
	var source: HexChemistryWorld = world.hex_court
	var copy := HexChemistryWorld.new()
	if source.get_script().resource_path == "res://src/sim/hex/hex_chemistry_world.gd":
		source.clone_cell_storage_to(copy)
	else:
		# Extension methods cannot claim ownership or alias authority into a
		# prediction clone. Preserve the preceding unconditional deep copy.
		copy.cells = (source.get("cells") as Dictionary).duplicate(true)
	for field: String in ["casts", "products", "pending", "sources", "exposure", "flow_carry", "metrics"]:
		copy.set(field, (source.get(field) as Dictionary).duplicate(true))
	for field: String in ["origin", "next_cast_id", "next_product_id", "next_ground_part_id", "current_tick", "render_revision", "value_revision", "chemistry_enabled"]:
		copy.set(field, source.get(field))
	var base := HexWorldSnapshot._clone_base_collision(world.collision)
	if base == null: return {}
	var dynamic := HexCollisionWorld.new(base)
	copy.collision = base
	if not dynamic.set_hex_surfaces(copy, world.tick): return {}
	return {"authority": copy, "tick": world.tick, "collision": dynamic}


# Internal commit of a locally prepared context, never a wire dictionary. No
# validation/allocation follows the application's publication boundary.
func publish_hex_context(prepared: Dictionary) -> void:
	hex_authority = prepared.authority
	hex_context_tick = int(prepared.tick)
	collision = prepared.collision
	reaction_movement = prepared.collision


static func capture_packet(state: PlayerState, tick: int, acknowledged_sequence: int, reactions: Array = []) -> Dictionary:
	if state == null:
		return {}
	var values := PackedInt64Array()
	for property_name: StringName in STATE_FIELDS:
		var value: Variant = state.get(property_name)
		values.append(int(value))
	values.append_array(PackedInt64Array(Array(state.spell_status_values)))
	var packet := {"tick": tick, "sequence": acknowledged_sequence, "values": values, "surfaces": ReactionMovementWorld.capture_surfaces(reactions, tick), "lanes": FrostwayFieldPolicy.capture(reactions, tick), "capacitors": CapacitorFieldPolicy.capture(reactions, tick)}
	return packet if validate_packet(packet) else {}


static func restore_state(values: PackedInt64Array) -> PlayerState:
	if not validate_values(values):
		return null
	var state := PlayerState.new(int(values[0]))
	for index: int in range(STATE_FIELDS.size()):
		var property_name := STATE_FIELDS[index]
		state.set(property_name, values[index] == 1 if property_name in BOOLEAN_FIELDS else int(values[index]))
	state.spell_status_values = PackedInt32Array(Array(values.slice(STATE_FIELDS.size())))
	return state


static func validate_packet(packet: Dictionary) -> bool:
	if typeof(packet.get("tick")) != TYPE_INT or typeof(packet.get("sequence")) != TYPE_INT:
		return false
	if int(packet["tick"]) < 0 or int(packet["tick"]) > 0x7fffffff:
		return false
	if int(packet["sequence"]) < -1 or int(packet["sequence"]) > 0x7fffffff:
		return false
	var surfaces: Variant = packet.get("surfaces")
	if not surfaces is PackedInt32Array or not ReactionMovementWorld.validate_surfaces(surfaces, int(packet["tick"])):
		return false
	var lanes: Variant = packet.get("lanes")
	if not lanes is PackedInt32Array or not FrostwayFieldPolicy.validate(lanes, int(packet["tick"])):
		return false
	var capacitors: Variant = packet.get("capacitors")
	if not capacitors is PackedInt32Array or not CapacitorFieldPolicy.validate(capacitors, int(packet["tick"])):
		return false
	# Both views derive from the same globally bounded reaction inventory.
	if surfaces.size() / ReactionMovementWorld.ROW_WIDTH + lanes.size() / FrostwayFieldPolicy.ROW_WIDTH + capacitors.size() / CapacitorFieldPolicy.ROW_WIDTH > ElementChemistrySystem.MAX_REACTIONS:
		return false
	var seen: Dictionary = {}
	for context: Array in [[surfaces, ReactionMovementWorld.ROW_WIDTH, ReactionMovementWorld.SURFACE_ID_BASE], [lanes, FrostwayFieldPolicy.ROW_WIDTH, 0], [capacitors, CapacitorFieldPolicy.ROW_WIDTH, 0]]:
		for index: int in range(0, context[0].size(), int(context[1])):
			var id := int(context[0][index]) - int(context[2])
			if seen.has(id):
				return false
			seen[id] = true
	var values: Variant = packet.get("values")
	return typeof(values) == TYPE_PACKED_INT64_ARRAY and validate_values(values)


static func validate_values(values: PackedInt64Array) -> bool:
	if values.size() != STATE_FIELDS.size() + ExpandedSpellState.STATUS_SIZE or not ExpandedSpellState.valid_status_values(values.slice(STATE_FIELDS.size())):
		return false
	if _value(values, &"entity_id") < 2 or _value(values, &"entity_id") > SessionTransport.MAX_PLAYERS:
		return false
	if _value(values, &"team_id") < 1 or _value(values, &"team_id") > 256 or _value(values, &"health") < 0 or _value(values, &"health") > 1_000_000:
		return false
	if _value(values, &"champion_wire_id") < 0 or _value(values, &"champion_wire_id") > 30:
		return false
	for name: StringName in [&"health_maximum", &"flux_maximum"]:
		if _value(values, name) <= 0 or _value(values, name) > 1_000_000:
			return false
	if _value(values, &"health") > _value(values, &"health_maximum") or _value(values, &"flux") < 0 or _value(values, &"flux") > _value(values, &"flux_maximum"):
		return false
	for name: StringName in [&"health_recovery_per_second", &"flux_recovery_per_second", &"health_recovery_remainder", &"flux_recovery_remainder", &"health_recovery_delay_ticks", &"flux_recovery_delay_ticks", &"pending_cast_ticks", &"cast_recovery_ticks"]:
		if _value(values, name) < 0 or _value(values, name) > SessionSnapshot.MAX_TIMER_TICKS:
			return false
	if _value(values, &"flux_recovery_idle_ticks") < 0 or _value(values, &"flux_recovery_idle_ticks") > ResourceRecovery.maximum_idle_ticks(120):
		return false
	var pending_wire := _value(values, &"pending_cast_wire_id")
	if pending_wire != 0 and CombatTuning.cast_definition(pending_wire).is_empty():
		return false
	for property_name: StringName in [&"position_x", &"position_y"]:
		if absi(_value(values, property_name)) > SessionSnapshot.MAX_ABSOLUTE_POSITION:
			return false
	for property_name: StringName in [&"position_remainder_x", &"position_remainder_y"]:
		if absi(_value(values, property_name)) > 1000:
			return false
	for property_name: StringName in [&"velocity_x", &"velocity_y", &"air_velocity_x", &"air_velocity_y", &"hop_speed", &"control_speed"]:
		if absi(_value(values, property_name)) > 10_000_000:
			return false
	for property_name: StringName in [&"air_velocity_x", &"air_velocity_y"]:
		if absi(_value(values, property_name)) > MovementTuning.MAX_AUTHORED_SPEED:
			return false
	for property_name: StringName in DIRECTION_FIELDS:
		if _value(values, property_name) < -1000 or _value(values, property_name) > 1000:
			return false
	if _value(values, &"air_height") < 0 or _value(values, &"air_height") > MovementTuning.AIR_MAX_HEIGHT:
		return false
	if _value(values, &"air_vertical_velocity") < -MovementTuning.AIR_TERMINAL_FALL_SPEED or _value(values, &"air_vertical_velocity") > MovementTuning.CHARGED_JUMP_VERTICAL_SPEED:
		return false
	if _value(values, &"jumpsquat_ticks") > (MovementTuning.JUMPSQUAT_CHARGE_MS * 120 + 999) / 1000:
		return false
	if absi(_value(values, &"air_height_remainder")) >= 2 * 120:
		return false
	if _value(values, &"stamina_recovery_idle_ticks") < 0 or _value(values, &"stamina_recovery_idle_ticks") > ResourceRecovery.maximum_idle_ticks(120):
		return false
	if _value(values, &"float_max_duration_ms") not in [MovementTuning.FLOAT_SMALL_DURATION_MS, MovementTuning.FLOAT_MIDDLE_DURATION_MS, MovementTuning.FLOAT_LARGE_DURATION_MS]:
		return false
	if _value(values, &"float_ticks") < 0 or _value(values, &"float_ticks") > (_value(values, &"float_max_duration_ms") * 120 + 999) / 1000:
		return false
	for property_name: StringName in [&"chemistry_reveal_ticks", &"chemistry_conceal_ticks", &"chemistry_regen_block_ticks"]:
		if _value(values, property_name) < 0 or _value(values, property_name) > 120:
			return false
	for property_name: StringName in BOOLEAN_FIELDS:
		if _value(values, property_name) not in [0, 1]:
			return false
	for property_name: StringName in TIMER_FIELDS:
		if _value(values, property_name) < 0 or _value(values, property_name) > SessionSnapshot.MAX_TIMER_TICKS:
			return false
	var radius := _value(values, &"radius")
	if radius <= 0 or radius > 100_000:
		return false
	if _value(values, &"movement_mode") < 0 or _value(values, &"movement_mode") >= PlayerState.MovementMode.size():
		return false
	if _value(values, &"hop_mode") < 0 or _value(values, &"hop_mode") >= PlayerState.MovementMode.size():
		return false
	if _value(values, &"control_state") < 0 or _value(values, &"control_state") >= PlayerState.ControlState.size():
		return false
	var stamina_maximum := _value(values, &"stamina_maximum")
	var stamina := _value(values, &"stamina")
	if stamina_maximum <= 0 or stamina_maximum > 1_000_000 or stamina < 0 or stamina > stamina_maximum:
		return false
	if _value(values, &"stamina_recovery_per_second") < 0 or _value(values, &"stamina_recovery_per_second") > 1_000_000:
		return false
	if _value(values, &"movement_speed_ratio") <= 0 or _value(values, &"movement_speed_ratio") > 5000:
		return false
	if absi(_value(values, &"stamina_remainder")) > 1_000_000:
		return false
	if _value(values, &"landing_intensity") < 0 or _value(values, &"landing_intensity") > 1000:
		return false
	if _value(values, &"slow_ratio") < MovementTuning.SLOW_MINIMUM_RATIO or _value(values, &"slow_ratio") > 1000:
		return false
	for property_name: StringName in [&"hop_stage", &"air_redirects_remaining", &"wall_contact_id", &"wall_lockout_id", &"wall_skim_surface_id", &"wall_skim_lockout_id"]:
		if _value(values, property_name) < 0 or _value(values, property_name) > 0x7fffffff:
			return false
	return true


static func _value(values: PackedInt64Array, property_name: StringName) -> int:
	return int(values[STATE_FIELDS.find(property_name)])
