extends FluxTestSuite

const Infusion = preload("res://.agent/candidates/gameplay_s6_infusion/src/sim/combat/melee_infusion_system.gd")
const Tuning = preload("res://.agent/candidates/gameplay_s6_infusion/src/sim/combat/melee_infusion_tuning.gd")
const CandidateCourt = preload("res://.agent/candidates/gameplay_s6_hex/hex_court.gd")


class InfusionWorld extends RefCounted:
	var config := SimConfig.new(120)
	var hex_court: Variant
	var next_projectile_id := 8_000
	var tick := 0
	var combat_events: Array[Dictionary] = []


class RejectingCommitCourt extends RefCounted:
	var reserved := false
	var cancelled := 0

	func reserve_infusion(_owner: int, _wire: int, _source: int, _strength: int, _budget: int) -> bool:
		reserved = true
		return true

	func commit_infusion_payment(_owner: int) -> bool:
		return false

	func cancel_infusion(_owner: int) -> bool:
		cancelled += 1
		reserved = false
		return true


func run() -> int:
	_test_exact_profile_and_atomic_reload()
	_test_first_valid_slot_and_material_only_payment()
	_test_refusals_do_not_spend_or_leak()
	_test_commit_failure_restores_all_flux_state()
	_test_first_contact_releases_one_prepush_hex()
	_test_paid_hold_survives_to_final_active_tick()
	_test_whiff_death_and_sequence_cleanup_are_finite()
	return finish("melee-infusion-system")


func _test_exact_profile_and_atomic_reload() -> void:
	var tuning := Tuning.new()
	check(tuning.load_from_file(), "candidate melee infusion tuning loads: %s" % tuning.last_error)
	equal(tuning.profile(), {
		"supported_element_wire_ids": [3, 2],
		"strength": 3,
		"matter_budget": 180,
		"flux_cost": 4_000,
		"readiness_ticks": 36,
	}, "Water/Fire infusion owns the exact material-only trial profile")
	var original_hash := tuning.content_hash
	var original_profile := tuning.profile()
	var path := "user://invalid-melee-infusion-tuning.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "isolated malformed infusion fixture opens")
	if file != null:
		file.store_string('{"version":1,"compatibility_id":"melee-infusion-s6-v1","supported_element_wire_ids":[3,2],"strength":15,"matter_budget":600,"flux_cost":4000,"readiness_ticks":36}')
		file.close()
	check(not tuning.load_from_file(path), "a ranged Heavy payload cannot replace the fixed infusion profile")
	equal(tuning.content_hash, original_hash, "failed tuning reload preserves the last valid hash")
	equal(tuning.profile(), original_profile, "failed tuning reload preserves the last valid profile atomically")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_first_valid_slot_and_material_only_payment() -> void:
	Tuning.reset_shared_for_tests()
	var world := _world_with_court()
	var actor := _actor(1, 41)
	var earth := _wire("earth", "bolt")
	var fire_heavy := _wire("fire", "heavy")
	var water := _wire("water", "bolt")
	_set_slots(actor, [earth, fire_heavy, water])
	actor.spell_cooldown_ticks[1] = 999
	var flux_before := actor.flux
	var pressed := _pressed_slots([1, 2, 3])
	var result: Dictionary = Infusion.begin_tick(world, actor, _command(world, actor, pressed))
	check(result.accepted and result.slot == 2 and result.wire_id == fire_heavy, "ascending search skips unsupported Earth and chooses the first valid Water/Fire slot")
	equal(result.consumed_pressed_actions, pressed, "all simultaneous spell-position edges are quarantined after the first valid selection")
	equal(actor.flux, flux_before - 4_000, "accepted infusion pays its own exact Flux cost once")
	equal(actor.spell_cooldown_ticks[1], 999, "infusion readiness is separate from the selected spell's ranged cooldown")
	equal(actor.infusion_ready_ticks, 36, "accepted payload arms the exact independent readiness")
	equal(world.next_projectile_id, 8_001, "one accepted payload allocates one immutable world source ID")
	var record: Dictionary = world.hex_court.casts[int(world.hex_court.sources[8_000])]
	equal([record.wire, record.strength, record.budget, record.ledger.initial_strength], [fire_heavy, 3, 180, 3], "selecting Heavy contributes identity only and cannot smuggle Heavy strength or quantity")
	check(record.paid and record.ledger.flight_quantity == 180 and world.hex_court.conservation_valid(), "paid held payload remains one finite conserved ledger")


func _test_refusals_do_not_spend_or_leak() -> void:
	var water := _wire("water", "bolt")
	var earth := _wire("earth", "bolt")
	var ordinary := InfusionWorld.new()
	var actor := _actor(2, 51)
	_set_slots(actor, [water])
	var before := _resource_state(actor)
	var water_bit := _pressed_slots([1])
	var result: Dictionary = Infusion.begin_tick(ordinary, actor, _command(ordinary, actor, water_bit))
	check(result.attempted and not result.accepted and result.reason == &"hex_unavailable", "ordinary world explicitly refuses an otherwise valid infusion")
	equal(result.consumed_pressed_actions, water_bit, "ordinary-world refusal returns the spell edge for ranged quarantine")
	equal(_resource_state(actor), before, "ordinary-world refusal spends no Flux or recovery state")
	equal(ordinary.next_projectile_id, 8_000, "ordinary-world refusal allocates no source ID")

	var unsupported := _world_with_court()
	var earth_actor := _actor(3, 52)
	_set_slots(earth_actor, [earth])
	before = _resource_state(earth_actor)
	result = Infusion.begin_tick(unsupported, earth_actor, _command(unsupported, earth_actor, water_bit))
	check(not result.accepted and result.reason == &"water_fire_only", "unsupported element is an explicit infusion refusal")
	equal(result.consumed_pressed_actions, water_bit, "unsupported pressed slot cannot leak into a ranged cast during the physical window")
	equal(_resource_state(earth_actor), before, "unsupported element spends nothing")
	check(unsupported.hex_court.casts.is_empty() and unsupported.next_projectile_id == 8_000, "unsupported element leaves court and source allocation untouched")

	var poor := _world_with_court()
	var poor_actor := _actor(4, 53)
	_set_slots(poor_actor, [water])
	poor_actor.flux = 3_999
	result = Infusion.begin_tick(poor, poor_actor, _command(poor, poor_actor, water_bit))
	check(not result.accepted and result.reason == &"flux", "insufficient Flux is explicit")
	check(poor.hex_court.casts.is_empty() and poor_actor.flux == 3_999 and poor.next_projectile_id == 8_000, "Flux precheck creates no reservation, spend, or source gap")

	var cooling := _world_with_court()
	var cooling_actor := _actor(5, 54)
	_set_slots(cooling_actor, [water])
	cooling_actor.infusion_ready_ticks = 2
	result = Infusion.begin_tick(cooling, cooling_actor, _command(cooling, cooling_actor, water_bit))
	check(not result.accepted and result.reason == &"readiness" and cooling_actor.infusion_ready_ticks == 1, "readiness decrements once before refusing a new payload")
	check(cooling.hex_court.casts.is_empty() and cooling.next_projectile_id == 8_000, "readiness refusal is capacity- and identity-free")

	var full := _world_with_court()
	for index: int in range(CandidateCourt.MAX_PRODUCTS):
		check(full.hex_court.reserve_infusion(100 + index, water, 9_000 + index), "capacity fixture reserves potential product %d" % index)
	var full_actor := _actor(6, 55)
	_set_slots(full_actor, [water])
	before = _resource_state(full_actor)
	result = Infusion.begin_tick(full, full_actor, _command(full, full_actor, water_bit))
	check(not result.accepted and result.reason == &"hex_capacity", "full product reservation refuses before payment")
	equal(_resource_state(full_actor), before, "capacity refusal spends no Flux")
	equal(full.next_projectile_id, 8_000, "capacity refusal leaves the source allocator unchanged")


func _test_commit_failure_restores_all_flux_state() -> void:
	var world := InfusionWorld.new()
	world.hex_court = RejectingCommitCourt.new()
	var actor := _actor(7, 61)
	_set_slots(actor, [_wire("fire", "spray")])
	actor.flux_recovery_remainder = 17
	actor.flux_recovery_delay_ticks = 9
	actor.flux_recovery_idle_ticks = 23
	var before := _resource_state(actor)
	var result: Dictionary = Infusion.begin_tick(world, actor, _command(world, actor, _pressed_slots([1])))
	check(not result.accepted and result.reason == &"commit", "failed ledger commit refuses the infusion")
	equal(_resource_state(actor), before, "failed commit restores Flux and every recovery side effect byte-for-byte")
	check(not world.hex_court.reserved and world.hex_court.cancelled == 1, "failed commit rolls back its reservation once")
	equal(world.next_projectile_id, 8_000, "failed commit cannot burn an immutable source ID")
	equal([actor.infusion_wire_id, actor.infusion_source_id, actor.infusion_used], [0, 0, 0], "failed commit creates no hidden held state")


func _test_first_contact_releases_one_prepush_hex() -> void:
	var world := _world_with_court()
	var actor := _actor(8, 71)
	_set_slots(actor, [_wire("water", "rapid")])
	check(Infusion.begin_tick(world, actor, _command(world, actor, _pressed_slots([1]))).accepted, "startup accepts one Water payload")
	actor.physical_phase = Infusion.PHYSICAL_PHASE_ACTIVE
	actor.physical_phase_ticks_total = 4
	actor.physical_phase_ticks_remaining = 4
	world.tick = 6
	Infusion.begin_tick(world, actor, _command(world, actor, 0))
	var prepush := world.hex_court.origin + Vector2i(10_000, 0)
	var landing := world.hex_court.origin + Vector2i(90_000, 0)
	var expected_cell := HexGrid.world_to_cell(prepush - world.hex_court.origin)
	check(Infusion.confirm_first_contact(world, actor, prepush, true), "first confirmed contact releases the paid payload")
	var record: Dictionary = world.hex_court.casts[int(world.hex_court.sources[8_000])]
	equal(record.cells, {expected_cell: 180}, "release deposits all matter in the target's one canonical pre-push hex")
	check(not HexFootprint.contains(record.footprint, landing), "later knockback destination cannot move or enlarge the deposit")
	equal([actor.infusion_wire_id, actor.infusion_source_id, actor.infusion_used, actor.infusion_sequence_id], [0, 0, 1, 71], "release clears held identity but latches one-use state for the physical sequence")
	var hash_after := world.hex_court.state_hash()
	check(not Infusion.confirm_first_contact(world, actor, prepush, true), "duplicate contact callback cannot release twice")
	equal(world.hex_court.state_hash(), hash_after, "duplicate callback cannot duplicate terrain or accounting")
	check(world.hex_court.metrics.matter_paid == 180 and world.hex_court.conservation_valid(), "successful release conserves one paid 180-unit payload")


func _test_paid_hold_survives_to_final_active_tick() -> void:
	var world := _world_with_court()
	var actor := _actor(12, 75)
	_set_slots(actor, [_wire("fire", "bolt"), _wire("water", "bolt")])
	check(Infusion.begin_tick(world, actor, _command(world, actor, _pressed_slots([1]))).accepted, "startup accepts the payload before a late target enters")
	actor.physical_phase = Infusion.PHYSICAL_PHASE_ACTIVE
	actor.physical_phase_ticks_total = 4
	actor.physical_phase_ticks_remaining = 2
	world.tick = 8
	var late_attempt: Dictionary = Infusion.begin_tick(world, actor, _command(world, actor, _pressed_slots([2])))
	check(not late_attempt.accepted and late_attempt.reason == &"window_closed", "second Active tick cannot select or replace an infusion")
	check(world.hex_court.held_infusions.has(actor.entity_id) and actor.infusion_source_id == 8_000, "closed selection window does not expire the already paid payload")
	actor.physical_phase_ticks_remaining = 1
	world.tick = 9
	Infusion.begin_tick(world, actor, _command(world, actor, 0))
	check(world.hex_court.held_infusions.has(actor.entity_id), "paid payload survives through the final Active tick while no target has confirmed")
	var prepush := world.hex_court.origin + Vector2i(-12_000, 8_000)
	check(Infusion.confirm_first_contact(world, actor, prepush, true), "target entering on the final Active tick releases exactly once")
	var record: Dictionary = world.hex_court.casts[int(world.hex_court.sources[8_000])]
	var expected_cell := HexGrid.world_to_cell(prepush - world.hex_court.origin)
	equal(record.cells, {expected_cell: 180}, "late confirmed target still receives the one pre-push canonical hex")
	equal([actor.infusion_wire_id, actor.infusion_source_id, actor.infusion_sequence_id, actor.infusion_used], [0, 0, 75, 1], "late release retains only current-sequence used latch state")
	check(world.hex_court.metrics.matter_paid == 180 and world.hex_court.metrics.matter_expired == 0 and world.hex_court.conservation_valid(), "late release deposits rather than prematurely expiring paid stock")


func _test_whiff_death_and_sequence_cleanup_are_finite() -> void:
	var fire := _wire("fire", "bolt")
	var whiff := _world_with_court()
	var actor := _actor(9, 81)
	_set_slots(actor, [fire])
	var flux_before := actor.flux
	check(Infusion.begin_tick(whiff, actor, _command(whiff, actor, _pressed_slots([1]))).accepted, "whiff fixture pays one Fire payload")
	actor.physical_phase = Infusion.PHYSICAL_PHASE_RECOVERY
	actor.physical_phase_ticks_total = 16
	actor.physical_phase_ticks_remaining = 16
	Infusion.begin_tick(whiff, actor, _command(whiff, actor, 0))
	check(whiff.hex_court.held_infusions.is_empty() and whiff.hex_court.casts.is_empty(), "recovery expires and removes the held whiff after every Active frame missed")
	check(whiff.hex_court.metrics.matter_paid == 180 and whiff.hex_court.metrics.matter_expired == 180 and whiff.hex_court.conservation_valid(), "paid whiff expires exactly once with no terrain")
	equal(actor.flux, flux_before - 4_000, "paid whiff gives no Flux refund")
	check(not Infusion.cancel(whiff, actor, &"duplicate"), "duplicate cancel is inert after cleanup")

	var no_contact := _world_with_court()
	var guarded := _actor(10, 82)
	_set_slots(guarded, [_wire("water", "spray")])
	check(Infusion.begin_tick(no_contact, guarded, _command(no_contact, guarded, _pressed_slots([1]))).accepted, "protected-contact fixture owns a payload")
	guarded.physical_phase = Infusion.PHYSICAL_PHASE_ACTIVE
	guarded.physical_phase_ticks_total = 4
	guarded.physical_phase_ticks_remaining = 4
	check(not Infusion.confirm_first_contact(no_contact, guarded, no_contact.hex_court.origin, false), "rejected/protected contact cannot release an infusion")
	check(no_contact.hex_court.held_infusions.has(guarded.entity_id), "non-contact leaves payload only until the bounded window closes")
	guarded.health = 0
	Infusion.begin_tick(no_contact, guarded, _command(no_contact, guarded, 0))
	check(no_contact.hex_court.metrics.matter_expired == 180 and no_contact.hex_court.cells[Vector2i.ZERO].water.is_empty(), "death expires held matter without delayed terrain")

	var changed := _world_with_court()
	var sequenced := _actor(11, 83)
	_set_slots(sequenced, [fire])
	check(Infusion.begin_tick(changed, sequenced, _command(changed, sequenced, _pressed_slots([1]))).accepted, "sequence fixture accepts once")
	sequenced.physical_sequence_id = 84
	Infusion.begin_tick(changed, sequenced, _command(changed, sequenced, 0))
	equal([sequenced.infusion_wire_id, sequenced.infusion_source_id, sequenced.infusion_sequence_id, sequenced.infusion_used], [0, 0, 0, 0], "new physical sequence cancels stale hold and rearms one-use state")
	check(changed.hex_court.metrics.matter_expired == 180 and changed.hex_court.conservation_valid(), "sequence replacement expires the old paid ledger once")


func _world_with_court() -> InfusionWorld:
	var world := InfusionWorld.new()
	world.hex_court = CandidateCourt.new()
	world.hex_court.chemistry_enabled = true
	return world


func _actor(entity_id: int, sequence_id: int) -> PlayerState:
	var actor := PlayerState.new(entity_id)
	actor.team_id = entity_id
	actor.physical_kind = 1
	actor.physical_phase = Infusion.PHYSICAL_PHASE_STARTUP
	actor.physical_phase_ticks_remaining = 6
	actor.physical_phase_ticks_total = 6
	actor.physical_sequence_id = sequence_id
	actor.physical_hit_ids.clear()
	actor.infusion_wire_id = 0
	actor.infusion_source_id = 0
	actor.infusion_sequence_id = 0
	actor.infusion_ready_ticks = 0
	actor.infusion_used = 0
	return actor


func _set_slots(actor: PlayerState, leading: Array) -> void:
	var wires: Array[int] = []
	for wire_value: Variant in leading:
		var wire_id := int(wire_value)
		if wire_id > 0 and not wires.has(wire_id):
			wires.append(wire_id)
	for wire_id: int in CombatTuning.runtime_wire_ids():
		if wires.size() >= PlayerState.SPELL_SLOT_COUNT:
			break
		if not wires.has(wire_id):
			wires.append(wire_id)
	actor.spell_wire_ids = PackedInt32Array(wires)
	actor.spell_cooldown_ticks = PackedInt32Array()
	actor.spell_cooldown_ticks.resize(PlayerState.SPELL_SLOT_COUNT)
	actor.spell_cooldown_ticks.fill(0)


func _wire(element: String, family: String) -> int:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "canonical ability catalog loads for %s/%s" % [element, family])
	var ability_id := catalog.spell_id_at(element, family)
	return int(catalog.ability(ability_id).get("wire_id", 0))


func _pressed_slots(slots: Array) -> int:
	var mask := 0
	for slot_value: Variant in slots:
		var slot := int(slot_value)
		mask |= int(SimCommand.SPELL_PRESSED_BITS[slot - 1])
	return mask


func _command(world: InfusionWorld, actor: PlayerState, pressed: int) -> SimCommand:
	return SimCommand.new(world.tick, actor.entity_id, 0, 0, 0, pressed, actor.aim_x, actor.aim_y)


func _resource_state(actor: PlayerState) -> Array[int]:
	return [actor.flux, actor.flux_recovery_remainder, actor.flux_recovery_delay_ticks, actor.flux_recovery_idle_ticks]
