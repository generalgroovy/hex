class_name PlayerState
extends RefCounted


const SPELL_BUTTON_COUNT: int = 4
const SPELL_LAYER_COUNT: int = 3
const SPELL_SLOT_COUNT: int = SPELL_BUTTON_COUNT * SPELL_LAYER_COUNT

enum MovementMode {
	IDLE,
	WALK,
	SPRINT,
	HOP,
	DOUBLE_JUMP,
	SLIDE,
	SLIDE_JUMP,
	AIR_DODGE,
	WAVE_DASH,
	WALL_KICK,
	VAULT,
	SUPERGLIDE,
	LAUNCHED,
	GRAPPLED,
	CHARGING,
	STUNNED,
	ROOTED,
	SLOWED,
	FAST_FALL,
	WALL_SKIM,
	IMPACT_RECOVERY,
	ROLL,
}

enum ControlState {
	FREE,
	LAUNCHED,
	GRAPPLED,
	CHARGING,
	STUNNED,
	ROOTED,
	SLOWED,
}

enum ActorKind {
	CHAMPION,
	TRAINING_TARGET,
}

var entity_id: int = 1
var team_id: int = 1
var actor_kind: int = ActorKind.CHAMPION
var champion_wire_id: int = 0
var position_x: int = 160_000
var position_y: int = 360_000
var position_remainder_x: int = 0
var position_remainder_y: int = 0
var velocity_x: int = 0
var velocity_y: int = 0
var facing_x: int = 1000
var facing_y: int = 0
var aim_x: int = 1000
var aim_y: int = 0
# Serialized combat hurt-circle radius; fixed by the selected body profile.
# Wall movement, spawn clearance and cast origins use MovementTuning.PLAYER_RADIUS
# instead. Animations and movement modes never resize this combat boundary.
var radius: int = MovementTuning.PLAYER_RADIUS
var movement_mode: int = MovementMode.IDLE
var primary_held: bool = false
var pending_cast_wire_id: int = 0
var pending_cast_ticks: int = 0
var pending_cast_aim_x: int = 1000
var pending_cast_aim_y: int = 0
var pending_cast_target_x: int = -1
var pending_cast_target_y: int = -1
var cast_recovery_ticks: int = 0
var primary_cooldown_ticks: int = 0
var active_1_cooldown_ticks: int = 0
var active_2_cooldown_ticks: int = 0
var edgeweave_cooldown_ticks: int = 0
var primary_wire_id: int = CombatTuning.PRIMARY_WIRE_ID
var active_1_wire_id: int = CombatTuning.ACTIVE_1_WIRE_ID
var active_2_wire_id: int = 0
var spell_wire_ids := PackedInt32Array([
	CombatTuning.PRIMARY_WIRE_ID, CombatTuning.ACTIVE_1_WIRE_ID, 0, 0,
	0, 0, 0, 0,
	0, 0, 0, 0,
])
var spell_cooldown_ticks := PackedInt32Array([
	0, 0, 0, 0,
	0, 0, 0, 0,
	0, 0, 0, 0,
])

var health_maximum: int = PlayerTuning.HEALTH_MAXIMUM
var health_recovery_per_second: int = PlayerTuning.HEALTH_RECOVERY_PER_SECOND
var health: int = health_maximum
var health_recovery_remainder: int = 0
var health_recovery_delay_ticks: int = 0
var spawn_protection_ticks: int = 0
var training_respawn_ticks: int = 0
var training_spawn_x: int = 0
var training_spawn_y: int = 0
var flux_maximum: int = PlayerTuning.FLUX_MAXIMUM
var flux_recovery_per_second: int = PlayerTuning.FLUX_RECOVERY_PER_SECOND
var flux: int = flux_maximum
var flux_recovery_remainder: int = 0
var flux_recovery_delay_ticks: int = 0
var stamina_maximum: int = MovementTuning.STAMINA_MAXIMUM
var stamina_recovery_per_second: int = MovementTuning.STAMINA_RECOVERY_PER_SECOND
var movement_speed_ratio: int = 1000
var stamina: int = stamina_maximum
var stamina_remainder: int = 0
var stamina_recovery_delay_ticks: int = 0

var jump_buffer_ticks: int = 0
var technique_buffer_ticks: int = 0
var slide_buffer_ticks: int = 0
var fast_falling: bool = false
var variable_jump_grace_ticks: int = 0
var jump_sustain_ticks: int = 0
var movement_chain_count: int = 0
var movement_chain_reset_ticks: int = 0
var movement_action_speed: int = 0
var air_velocity_x: int = 0
var air_velocity_y: int = 0
var movement_commitment_ticks: int = 0
var wall_air_ticks: int = 0
var slide_held_last_tick: bool = false
var fast_fall_armed: bool = false
var evade_buffer_airborne: bool = false
var air_height: int = 0
var air_vertical_velocity: int = 0
var air_height_remainder: int = 0
var air_dodge_used: bool = false
var jump_held_last_tick: bool = false
var air_floating: bool = false
var float_used: bool = false
var float_ticks: int = 0
var float_max_duration_ms: int = MovementTuning.FLOAT_MIDDLE_DURATION_MS
var flux_recovery_idle_ticks: int = 0
var stamina_recovery_idle_ticks: int = 0
var chemistry_reveal_ticks: int = 0
var chemistry_conceal_ticks: int = 0
var chemistry_regen_block_ticks: int = 0

var jump_protection_ticks: int = 0
var evade_buffer_ticks: int = 0
var landing_input_ticks: int = 0
var landing_input_x: int = 1000
var landing_input_y: int = 0
var hop_ticks: int = 0
var hop_cooldown_ticks: int = 0
var hop_stage: int = 0
var hop_mode: int = MovementMode.HOP
var hop_speed: int = 0
var hop_x: int = 1000
var hop_y: int = 0
var air_redirects_remaining: int = 0

var air_dodge_ticks: int = 0
var air_dodge_cooldown_ticks: int = 0
var air_dodge_x: int = 1000
var air_dodge_y: int = 0
var wave_dash_queued: bool = false
var wave_dash_ticks: int = 0
var wave_dash_x: int = 1000
var wave_dash_y: int = 0

var slide_ticks: int = 0
var slide_cooldown_ticks: int = 0
var slide_x: int = 1000
var slide_y: int = 0

var vault_ticks: int = 0
var vault_cooldown_ticks: int = 0
var vault_x: int = 1000
var vault_y: int = 0
var superglide_ticks: int = 0
var superglide_x: int = 1000
var superglide_y: int = 0

var wall_memory_ticks: int = 0
var wall_x: int = 0
var wall_y: int = 0
var wall_contact_id: int = 0
var wall_lockout_id: int = 0
var wall_lockout_ticks: int = 0
var wall_skim_ticks: int = 0
var wall_skim_cooldown_ticks: int = 0
var wall_skim_x: int = 0
var wall_skim_y: int = 1000
var wall_skim_surface_id: int = 0
var wall_skim_lockout_id: int = 0
var wall_skim_lockout_ticks: int = 0
var landing_ticks: int = 0
var landing_intensity: int = 0
var impact_recovery_ticks: int = 0
var sprinting: bool = false
var control_state: int = ControlState.FREE
var control_ticks: int = 0
var control_x: int = 1000
var control_y: int = 0
var control_speed: int = 0
var slow_ratio: int = 1000
var last_event: String = "spawn"


func _init(requested_entity_id: int = 1) -> void:
	entity_id = requested_entity_id
	reset_spell_slots_to_kit()


func is_airborne() -> bool:
	return air_height > 0 or air_vertical_velocity > 0 or wall_skim_ticks > 0


func is_rolling() -> bool:
	return air_dodge_ticks > 0 and hop_mode == MovementMode.ROLL


func reset_spell_slots_to_kit() -> void:
	spell_wire_ids = PackedInt32Array()
	for wire_id: int in kit_spell_wire_ids():
		if wire_id > 0 and not spell_wire_ids.has(wire_id):
			spell_wire_ids.append(wire_id)
	for wire_id: int in CombatTuning.runtime_wire_ids():
		if spell_wire_ids.size() >= SPELL_SLOT_COUNT:
			break
		if not spell_wire_ids.has(wire_id):
			spell_wire_ids.append(wire_id)
	spell_wire_ids.resize(SPELL_SLOT_COUNT)
	spell_cooldown_ticks = PackedInt32Array()
	spell_cooldown_ticks.resize(SPELL_SLOT_COUNT)
	spell_cooldown_ticks.fill(0)
	_sync_legacy_spell_cooldowns()


func kit_spell_wire_ids() -> PackedInt32Array:
	var result := PackedInt32Array([primary_wire_id, active_1_wire_id])
	if active_2_wire_id > 0:
		result.append(active_2_wire_id)
	return result


func proven_spell_wire_ids() -> PackedInt32Array:
	return PackedInt32Array(CombatTuning.runtime_wire_ids())


func spell_wire_id(slot_number: int) -> int:
	return int(spell_wire_ids[slot_number - 1]) if slot_number >= 1 and slot_number <= SPELL_SLOT_COUNT and spell_wire_ids.size() == SPELL_SLOT_COUNT else 0


func spell_slot_index_for_wire(wire_id: int) -> int:
	return spell_wire_ids.find(wire_id) if wire_id > 0 and spell_wire_ids.size() == SPELL_SLOT_COUNT else -1


func spell_cooldown_for_wire(wire_id: int) -> int:
	var slot_index := spell_slot_index_for_wire(wire_id)
	var cooldown := int(spell_cooldown_ticks[slot_index]) if slot_index >= 0 and spell_cooldown_ticks.size() == SPELL_SLOT_COUNT else 0
	if wire_id == primary_wire_id:
		cooldown = maxi(cooldown, primary_cooldown_ticks)
	elif wire_id == active_1_wire_id:
		cooldown = maxi(cooldown, active_1_cooldown_ticks)
	elif wire_id == active_2_wire_id and active_2_wire_id > 0:
		cooldown = maxi(cooldown, active_2_cooldown_ticks)
	return cooldown


func set_spell_cooldown(wire_id: int, ticks: int) -> bool:
	var slot_index := spell_slot_index_for_wire(wire_id)
	if wire_id <= 0 or (slot_index < 0 and wire_id not in kit_spell_wire_ids()): return false
	if spell_cooldown_ticks.size() != SPELL_SLOT_COUNT: return false
	if slot_index >= 0: spell_cooldown_ticks[slot_index] = maxi(0, ticks)
	if wire_id == primary_wire_id: primary_cooldown_ticks = maxi(0, ticks)
	elif wire_id == active_1_wire_id: active_1_cooldown_ticks = maxi(0, ticks)
	elif wire_id == active_2_wire_id: active_2_cooldown_ticks = maxi(0, ticks)
	_sync_legacy_spell_cooldowns()
	return true


func advance_spell_cooldowns() -> void:
	if spell_cooldown_ticks.size() != SPELL_SLOT_COUNT:
		spell_cooldown_ticks = PackedInt32Array()
		spell_cooldown_ticks.resize(SPELL_SLOT_COUNT)
		spell_cooldown_ticks.fill(0)
	_import_legacy_spell_cooldowns()
	if spell_slot_index_for_wire(primary_wire_id) < 0: primary_cooldown_ticks = maxi(0, primary_cooldown_ticks - 1)
	if spell_slot_index_for_wire(active_1_wire_id) < 0: active_1_cooldown_ticks = maxi(0, active_1_cooldown_ticks - 1)
	if spell_slot_index_for_wire(active_2_wire_id) < 0: active_2_cooldown_ticks = maxi(0, active_2_cooldown_ticks - 1)
	for slot_index: int in range(SPELL_SLOT_COUNT):
		spell_cooldown_ticks[slot_index] = maxi(0, int(spell_cooldown_ticks[slot_index]) - 1)
	_sync_legacy_spell_cooldowns()


static func spell_slot_label(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= SPELL_SLOT_COUNT:
		return "?"
	var button_number: int = slot_index % SPELL_BUTTON_COUNT + 1
	match slot_index / SPELL_BUTTON_COUNT:
		1:
			return "CTRL+%d" % button_number
		2:
			return "ALT+%d" % button_number
	return "%d" % button_number


func place_proven_spell(slot_index: int, wire_id: int) -> bool:
	if slot_index < 0 or slot_index >= SPELL_SLOT_COUNT or not proven_spell_wire_ids().has(wire_id) or not has_valid_spell_slots():
		return false
	var incoming_cooldown := spell_cooldown_for_wire(wire_id)
	var previous_index: int = spell_wire_ids.find(wire_id)
	var displaced_wire_id: int = spell_wire_ids[slot_index]
	var displaced_cooldown: int = spell_cooldown_ticks[slot_index]
	spell_wire_ids[slot_index] = wire_id
	if previous_index >= 0:
		spell_cooldown_ticks[slot_index] = spell_cooldown_ticks[previous_index]
		spell_wire_ids[previous_index] = displaced_wire_id
		spell_cooldown_ticks[previous_index] = displaced_cooldown
	else:
		# A spell outside the current twelve-position weave replaces the target.
		# Loom access is host-gated to the Wellspring, so newly equipped spells
		# begin ready rather than inheriting the displaced spell's cooldown.
		spell_cooldown_ticks[slot_index] = incoming_cooldown
	_sync_legacy_spell_cooldowns()
	return has_valid_spell_slots()


# Compatibility adapter for callers written while Loom access was kit-local.
func place_kit_spell(slot_index: int, wire_id: int) -> bool:
	return place_proven_spell(slot_index, wire_id)


func has_valid_spell_slots() -> bool:
	if spell_wire_ids.size() != SPELL_SLOT_COUNT or spell_cooldown_ticks.size() != SPELL_SLOT_COUNT or primary_wire_id <= 0 or active_1_wire_id <= 0 or primary_wire_id == active_1_wire_id:
		return false
	if active_2_wire_id < 0 or (active_2_wire_id > 0 and active_2_wire_id in [primary_wire_id, active_1_wire_id]):
		return false
	for kit_wire_id: int in kit_spell_wire_ids():
		if not CombatTuning.is_runtime_wire_id(kit_wire_id):
			return false
	var seen_wires: Dictionary[int, bool] = {}
	for slot_index: int in range(SPELL_SLOT_COUNT):
		var wire_id: int = spell_wire_ids[slot_index]
		if spell_cooldown_ticks[slot_index] < 0:
			return false
		if wire_id == 0:
			continue
		if not CombatTuning.is_runtime_wire_id(wire_id) or seen_wires.has(wire_id):
			return false
		seen_wires[wire_id] = true
	return true


func _import_legacy_spell_cooldowns() -> void:
	for pair: Vector2i in [
		Vector2i(primary_wire_id, primary_cooldown_ticks),
		Vector2i(active_1_wire_id, active_1_cooldown_ticks),
		Vector2i(active_2_wire_id, active_2_cooldown_ticks),
	]:
		var slot_index := spell_slot_index_for_wire(pair.x)
		if pair.x > 0 and slot_index >= 0:
			spell_cooldown_ticks[slot_index] = maxi(int(spell_cooldown_ticks[slot_index]), pair.y)


func _sync_legacy_spell_cooldowns() -> void:
	# E and controller aliases retain their own cooldown if absent from the
	# configurable weave; a slot holding the same spell shares that cooldown.
	if spell_slot_index_for_wire(primary_wire_id) >= 0: primary_cooldown_ticks = _stored_spell_cooldown(primary_wire_id)
	if spell_slot_index_for_wire(active_1_wire_id) >= 0: active_1_cooldown_ticks = _stored_spell_cooldown(active_1_wire_id)
	if spell_slot_index_for_wire(active_2_wire_id) >= 0: active_2_cooldown_ticks = _stored_spell_cooldown(active_2_wire_id)
	if active_2_wire_id <= 0: active_2_cooldown_ticks = 0


func _stored_spell_cooldown(wire_id: int) -> int:
	var slot_index := spell_slot_index_for_wire(wire_id)
	return int(spell_cooldown_ticks[slot_index]) if slot_index >= 0 and spell_cooldown_ticks.size() == SPELL_SLOT_COUNT else 0


func reset_for_spawn(spawn_position: Vector2i, protection_ticks: int = 0) -> void:
	position_x = spawn_position.x
	position_y = spawn_position.y
	position_remainder_x = 0
	position_remainder_y = 0
	velocity_x = 0
	velocity_y = 0
	primary_held = false
	pending_cast_wire_id = 0
	pending_cast_ticks = 0
	pending_cast_target_x = -1
	pending_cast_target_y = -1
	cast_recovery_ticks = 0
	primary_cooldown_ticks = 0
	active_1_cooldown_ticks = 0
	active_2_cooldown_ticks = 0
	spell_cooldown_ticks.fill(0)
	edgeweave_cooldown_ticks = 0
	jump_buffer_ticks = 0
	technique_buffer_ticks = 0
	slide_buffer_ticks = 0
	fast_falling = false
	variable_jump_grace_ticks = 0
	jump_sustain_ticks = 0
	movement_chain_count = 0
	movement_chain_reset_ticks = 0
	movement_action_speed = 0
	air_velocity_x = 0
	air_velocity_y = 0
	movement_commitment_ticks = 0
	wall_air_ticks = 0
	slide_held_last_tick = false
	fast_fall_armed = false
	evade_buffer_airborne = false
	air_height = 0
	air_vertical_velocity = 0
	air_height_remainder = 0
	air_dodge_used = false
	jump_held_last_tick = false
	air_floating = false
	float_used = false
	float_ticks = 0
	flux_recovery_idle_ticks = 0
	stamina_recovery_idle_ticks = 0
	chemistry_reveal_ticks = 0
	chemistry_conceal_ticks = 0
	chemistry_regen_block_ticks = 0
	jump_protection_ticks = 0
	evade_buffer_ticks = 0
	landing_input_ticks = 0
	hop_ticks = 0
	hop_cooldown_ticks = 0
	hop_stage = 0
	hop_mode = MovementMode.HOP
	air_redirects_remaining = 0
	air_dodge_ticks = 0
	air_dodge_cooldown_ticks = 0
	wave_dash_queued = false
	wave_dash_ticks = 0
	slide_ticks = 0
	slide_cooldown_ticks = 0
	vault_ticks = 0
	vault_cooldown_ticks = 0
	superglide_ticks = 0
	wall_memory_ticks = 0
	wall_contact_id = 0
	wall_lockout_id = 0
	wall_lockout_ticks = 0
	wall_skim_ticks = 0
	wall_skim_cooldown_ticks = 0
	wall_skim_surface_id = 0
	wall_skim_lockout_id = 0
	wall_skim_lockout_ticks = 0
	landing_ticks = 0
	landing_intensity = 0
	impact_recovery_ticks = 0
	sprinting = false
	control_state = ControlState.FREE
	control_ticks = 0
	control_speed = 0
	slow_ratio = 1000
	health = health_maximum
	health_recovery_remainder = 0
	health_recovery_delay_ticks = 0
	flux = flux_maximum
	flux_recovery_remainder = 0
	flux_recovery_delay_ticks = 0
	stamina = stamina_maximum
	stamina_remainder = 0
	stamina_recovery_delay_ticks = 0
	spawn_protection_ticks = maxi(0, protection_ticks)
	training_respawn_ticks = 0
	last_event = "protected_spawn" if spawn_protection_ticks > 0 else "spawn"


func canonical_values() -> PackedInt64Array:
	var values := PackedInt64Array([
		entity_id, team_id, actor_kind, champion_wire_id,
		position_x, position_y, position_remainder_x, position_remainder_y,
		velocity_x, velocity_y, facing_x, facing_y, aim_x, aim_y, radius, movement_mode,
		int(primary_held),
		pending_cast_wire_id, pending_cast_ticks, pending_cast_aim_x, pending_cast_aim_y,
		pending_cast_target_x, pending_cast_target_y,
		cast_recovery_ticks, primary_cooldown_ticks, active_1_cooldown_ticks, active_2_cooldown_ticks,
		edgeweave_cooldown_ticks, primary_wire_id, active_1_wire_id, active_2_wire_id,
		health_maximum, health_recovery_per_second,
		health, health_recovery_remainder, health_recovery_delay_ticks, spawn_protection_ticks,
		flux_maximum, flux_recovery_per_second,
		flux, flux_recovery_remainder, flux_recovery_delay_ticks,
		stamina_maximum, stamina_recovery_per_second, movement_speed_ratio,
		stamina, stamina_remainder, stamina_recovery_delay_ticks,
		jump_buffer_ticks, technique_buffer_ticks, slide_buffer_ticks, int(fast_falling), variable_jump_grace_ticks,
		jump_sustain_ticks, movement_chain_count, movement_chain_reset_ticks, movement_action_speed,
		air_velocity_x, air_velocity_y, movement_commitment_ticks, wall_air_ticks,
		int(slide_held_last_tick), int(fast_fall_armed), int(evade_buffer_airborne),
		air_height, air_vertical_velocity, air_height_remainder,
		int(air_dodge_used), int(jump_held_last_tick),
		int(air_floating), int(float_used), float_ticks, float_max_duration_ms,
		flux_recovery_idle_ticks, stamina_recovery_idle_ticks,
		chemistry_reveal_ticks, chemistry_conceal_ticks, chemistry_regen_block_ticks,
		jump_protection_ticks, evade_buffer_ticks, landing_input_ticks, landing_input_x, landing_input_y,
		hop_ticks, hop_cooldown_ticks, hop_stage, hop_mode, hop_speed, hop_x, hop_y,
		air_redirects_remaining,
		air_dodge_ticks, air_dodge_cooldown_ticks, air_dodge_x, air_dodge_y,
		int(wave_dash_queued), wave_dash_ticks, wave_dash_x, wave_dash_y,
		slide_ticks, slide_cooldown_ticks, slide_x, slide_y,
		vault_ticks, vault_cooldown_ticks, vault_x, vault_y,
		superglide_ticks, superglide_x, superglide_y,
		wall_memory_ticks, wall_x, wall_y, wall_contact_id,
		wall_lockout_id, wall_lockout_ticks,
		wall_skim_ticks, wall_skim_cooldown_ticks, wall_skim_x, wall_skim_y,
		wall_skim_surface_id, wall_skim_lockout_id, wall_skim_lockout_ticks,
		landing_ticks, landing_intensity, impact_recovery_ticks, int(sprinting),
		control_state, control_ticks, control_x, control_y, control_speed, slow_ratio,
		training_respawn_ticks, training_spawn_x, training_spawn_y,
	])
	for wire_id: int in spell_wire_ids:
		values.append(wire_id)
	for cooldown_ticks: int in spell_cooldown_ticks:
		values.append(cooldown_ticks)
	return values
