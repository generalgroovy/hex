class_name MeleeInfusionSystem
extends RefCounted

## One paid, material-only Water/Fire payload held by an eligible physical
## sequence. Root owns shared schema, command sanitization and contact ordering.

const Tuning = preload("res://.agent/candidates/gameplay_s6_infusion/src/sim/combat/melee_infusion_tuning.gd")

const PHYSICAL_KIND_NONE := 0
const PHYSICAL_PHASE_NONE := 0
const PHYSICAL_PHASE_STARTUP := 1
const PHYSICAL_PHASE_ACTIVE := 2
const PHYSICAL_PHASE_RECOVERY := 3


## Call after PhysicalAttackSystem.begin_tick and before CombatSystem. All spell
## position presses made while Startup/Active owns input are returned for the
## root caller to clear, whether the infusion is accepted or explicitly refused.
static func begin_tick(world, state, original_command: SimCommand) -> Dictionary:
	var result := {
		"consumed_pressed_actions": 0,
		"attempted": false,
		"accepted": false,
		"slot": 0,
		"wire_id": 0,
		"source_id": 0,
		"reason": &"",
	}
	if state == null:
		result.reason = &"invalid_state"
		return result

	state.infusion_ready_ticks = maxi(0, int(state.infusion_ready_ticks) - 1)
	_reconcile_sequence_and_hold(world, state)

	var pressed_mask := _pressed_spell_mask(original_command)
	var phase := int(state.physical_phase)
	if pressed_mask == 0 or phase not in [PHYSICAL_PHASE_STARTUP, PHYSICAL_PHASE_ACTIVE]:
		return result
	result.attempted = true
	result.consumed_pressed_actions = pressed_mask

	if int(state.health) <= 0:
		return _refuse(world, state, result, &"death")
	if int(state.physical_kind) == PHYSICAL_KIND_NONE or int(state.physical_sequence_id) <= 0:
		return _refuse(world, state, result, &"physical_state")
	if not _selection_window_open(state):
		return _refuse(world, state, result, &"window_closed")
	if int(state.infusion_used) != 0:
		return _refuse(world, state, result, &"already_used")

	var tuning := Tuning.shared()
	if not tuning.is_valid():
		return _refuse(world, state, result, &"tuning")
	var selection := _first_valid_selection(state, original_command)
	result.slot = int(selection.slot)
	result.wire_id = int(selection.wire_id)
	if not bool(selection.valid):
		return _refuse(world, state, result, &"water_fire_only")

	if int(state.infusion_ready_ticks) > 0:
		return _refuse(world, state, result, &"readiness")
	if world == null or world.get("config") == null or not world.config.is_valid():
		return _refuse(world, state, result, &"world")
	var court: Variant = world.get("hex_court")
	if court == null:
		return _refuse(world, state, result, &"hex_unavailable")
	if int(state.flux) < tuning.flux_cost:
		return _refuse(world, state, result, &"flux")

	var source_id := int(world.get("next_projectile_id"))
	if source_id <= 0 or source_id >= 0x7fffffff:
		return _refuse(world, state, result, &"source")
	if not court.reserve_infusion(int(state.entity_id), int(selection.wire_id), source_id, tuning.strength, tuning.matter_budget):
		return _refuse(world, state, result, &"hex_capacity")

	# spend_flux mutates recovery clocks. Preserve every mutation so a failed
	# ledger commit is exactly charge-free as well as reservation-free.
	var flux_before := int(state.flux)
	var remainder_before := int(state.flux_recovery_remainder)
	var delay_before := int(state.flux_recovery_delay_ticks)
	var idle_before := int(state.flux_recovery_idle_ticks)
	if not PlayerResourcesSystem.spend_flux(state, tuning.flux_cost, world.config):
		court.cancel_infusion(int(state.entity_id))
		return _refuse(world, state, result, &"flux")
	if not court.commit_infusion_payment(int(state.entity_id)):
		court.cancel_infusion(int(state.entity_id))
		state.flux = flux_before
		state.flux_recovery_remainder = remainder_before
		state.flux_recovery_delay_ticks = delay_before
		state.flux_recovery_idle_ticks = idle_before
		return _refuse(world, state, result, &"commit")

	world.next_projectile_id = source_id + 1
	state.infusion_wire_id = int(selection.wire_id)
	state.infusion_source_id = source_id
	state.infusion_sequence_id = int(state.physical_sequence_id)
	state.infusion_ready_ticks = tuning.readiness_ticks
	state.infusion_used = 1
	result.accepted = true
	result.source_id = source_id
	_emit(world, {
		"type": "melee_infusion_accepted", "entity_id": int(state.entity_id),
		"wire_id": int(selection.wire_id), "slot": int(selection.slot),
		"source_id": source_id, "physical_sequence_id": int(state.physical_sequence_id),
		"flux_cost": tuning.flux_cost,
	})
	return result


## Call only from the first successful physical contact, after damage succeeds
## and before knockback. The supplied point is the captured pre-push target
## position; HexCourt alone selects its canonical occupied cell.
static func confirm_first_contact(world, state, pre_knockback_point: Vector2i, first_contact: bool) -> bool:
	if world == null or state == null or not first_contact:
		return false
	if int(state.infusion_wire_id) <= 0 or int(state.infusion_source_id) <= 0 or int(state.infusion_used) != 1:
		return false
	if int(state.health) <= 0 or int(state.physical_phase) != PHYSICAL_PHASE_ACTIVE or int(state.infusion_sequence_id) != int(state.physical_sequence_id):
		return false
	var court: Variant = world.get("hex_court")
	if court == null:
		return false
	var wire_id := int(state.infusion_wire_id)
	var source_id := int(state.infusion_source_id)
	var released := bool(court.release_infusion(int(state.entity_id), pre_knockback_point, int(world.get("tick"))))
	if not released:
		# release_infusion already expires an out-of-court terminal. This second
		# call is inert there and closes any fail-preserving invalid-record case.
		court.cancel_infusion(int(state.entity_id))
	_clear_held(state)
	_emit(world, {
		"type": "melee_infusion_released" if released else "melee_infusion_cancelled",
		"entity_id": int(state.entity_id), "wire_id": wire_id,
		"source_id": source_id, "physical_sequence_id": int(state.physical_sequence_id),
		"x": pre_knockback_point.x, "y": pre_knockback_point.y,
		"reason": &"" if released else &"contact_release",
	})
	return released


## Modal, movement interruption, death, character change and world-reset callers
## use this before replacing state/world. A paid hold expires once and never
## refunds Flux. Usage remains latched until a different physical sequence.
static func cancel(world, state, reason: StringName) -> bool:
	if state == null:
		return false
	var wire_id := int(state.infusion_wire_id)
	var source_id := int(state.infusion_source_id)
	if wire_id <= 0 and source_id <= 0:
		return false
	var expired := false
	if world != null:
		var court: Variant = world.get("hex_court")
		if court != null:
			expired = bool(court.cancel_infusion(int(state.entity_id)))
	_clear_held(state)
	_emit(world, {
		"type": "melee_infusion_cancelled", "entity_id": int(state.entity_id),
		"wire_id": wire_id, "source_id": source_id,
		"physical_sequence_id": int(state.infusion_sequence_id),
		"reason": reason, "expired": expired,
	})
	return expired


static func _reconcile_sequence_and_hold(world, state) -> void:
	var held := int(state.infusion_wire_id) > 0 or int(state.infusion_source_id) > 0
	var sequence_changed := int(state.infusion_sequence_id) > 0 and int(state.infusion_sequence_id) != int(state.physical_sequence_id)
	if held and (int(state.health) <= 0 or sequence_changed or not _paid_hold_live(state)):
		var reason := &"death" if int(state.health) <= 0 else (&"sequence" if sequence_changed else &"window_closed")
		cancel(world, state, reason)
	if sequence_changed:
		state.infusion_used = 0
		state.infusion_sequence_id = 0
	elif not held and int(state.infusion_used) != 0 and int(state.physical_sequence_id) != int(state.infusion_sequence_id):
		state.infusion_used = 0
		state.infusion_sequence_id = 0


static func _selection_window_open(state) -> bool:
	if not state.physical_hit_ids.is_empty():
		return false
	var phase := int(state.physical_phase)
	if phase == PHYSICAL_PHASE_STARTUP:
		return true
	return phase == PHYSICAL_PHASE_ACTIVE and int(state.physical_phase_ticks_remaining) == int(state.physical_phase_ticks_total)


# Selection closes after the first Active tick, but a reservation already paid
# during the selection window remains live through every Active frame. Contact,
# recovery, death, explicit cancellation or sequence replacement terminates it.
static func _paid_hold_live(state) -> bool:
	return int(state.physical_phase) in [PHYSICAL_PHASE_STARTUP, PHYSICAL_PHASE_ACTIVE]


static func _first_valid_selection(state, command: SimCommand) -> Dictionary:
	var first_pressed_slot := 0
	var first_pressed_wire := 0
	var profile := Tuning.shared().profile()
	var supported: Array = profile.get("supported_element_wire_ids", [])
	for index: int in range(SimCommand.SPELL_PRESSED_BITS.size()):
		var bit := int(SimCommand.SPELL_PRESSED_BITS[index])
		if command == null or not command.has_pressed(bit):
			continue
		var slot := index + 1
		var wire_id := int(state.spell_wire_id(slot))
		if first_pressed_slot == 0:
			first_pressed_slot = slot
			first_pressed_wire = wire_id
		var definition: Dictionary = CombatTuning.cast_definition(wire_id)
		if not definition.is_empty() and int(definition.get("element_wire_id", 0)) in supported:
			return {"valid": true, "slot": slot, "wire_id": wire_id}
	return {"valid": false, "slot": first_pressed_slot, "wire_id": first_pressed_wire}


static func _pressed_spell_mask(command: SimCommand) -> int:
	if command == null:
		return 0
	var mask := 0
	for bit: int in SimCommand.SPELL_PRESSED_BITS:
		mask |= bit
	return int(command.pressed_actions) & mask


static func _refuse(world, state, result: Dictionary, reason: StringName) -> Dictionary:
	result.reason = reason
	_emit(world, {
		"type": "melee_infusion_refused", "entity_id": int(state.entity_id),
		"slot": int(result.slot), "wire_id": int(result.wire_id), "reason": reason,
		"physical_sequence_id": int(state.physical_sequence_id),
	})
	return result


static func _clear_held(state) -> void:
	state.infusion_wire_id = 0
	state.infusion_source_id = 0


static func _emit(world, event: Dictionary) -> void:
	if world == null:
		return
	var events: Variant = world.get("combat_events")
	if events is Array:
		events.append(event)
