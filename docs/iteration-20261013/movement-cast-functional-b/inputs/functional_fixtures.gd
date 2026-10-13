extends RefCounted
## Ignored functional workloads for the seven-child observer. No timing claim.
## Campus routes use one real Oh Tipi main-world actor, not Bootstrap, separate
## Garden exhibition courts, training targets, rendering or physical input.
## The death branch alone declares reduced initial Health and zero regeneration;
## all subsequent damage/status/payment/movement comes from ordinary commands.

const Status = preload("res://src/sim/combat/spell_status_policy.gd")
const ORIGIN := Vector2i(600_000, 500_000)
const ICE_CENTER := Vector2i(800_000, 800_000)
const BRANCHES: Array[String] = ["actors_entered", "dead_at_entry", "dead_after_status", "missing_command", "admission_offers", "release_results"]
const CASES: Array[Dictionary] = [
	{"label":"garden_idle", "ticks":240, "expect_success":true, "hex_mode":true},
	{"label":"fire_default", "ticks":480, "expect_success":true, "hex_mode":true},
	{"label":"fire_close", "ticks":480, "expect_success":true, "hex_mode":true},
	{"label":"mantle", "ticks":480, "expect_success":true, "hex_mode":true},
	{"label":"movement_chain", "ticks":240, "expect_success":true, "hex_mode":true},
	{"label":"missing_command", "ticks":1, "expect_success":true, "hex_mode":true},
	{"label":"dead_at_entry", "ticks":1, "expect_success":true, "hex_mode":true},
	{"label":"legacy_paid", "ticks":120, "expect_success":true, "hex_mode":false},
	{"label":"wrong_tick", "ticks":1, "expect_success":false, "hex_mode":true},
	{"label":"paid_status_death", "ticks":96, "expect_success":true, "hex_mode":true},
	{"label":"campus_wall", "ticks":160, "expect_success":true, "hex_mode":true},
	{"label":"paid_black_ice", "ticks":240, "expect_success":true, "hex_mode":true},
]
var last_error := ""
var abilities := AbilityCatalog.new()
var champions := ChampionCatalog.new()
var layout := SanctumCampusLayout.new()
var definition: HexWorldDefinition
var configured := false


func configure() -> bool:
	last_error = ""
	if not abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"):
		last_error = abilities.last_error
		return false
	if not champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities):
		last_error = champions.last_error
		return false
	if not layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"):
		last_error = layout.last_error
		return false
	definition = HexWorldDefinition.from_campus(layout)
	configured = definition != null
	if not configured: last_error = "Current campus has no valid complete Hex topology"
	return configured


func specs() -> Array[Dictionary]:
	return CASES.duplicate(true)


func world(world_script: Script, label: String) -> SimWorld:
	last_error = ""
	if not configured or world_script == null or not _known(label):
		last_error = "Unconfigured fixture or unknown case: " + label
		return null
	var campus := label in ["garden_idle", "fire_default", "fire_close", "mantle", "movement_chain", "campus_wall"]
	var result: SimWorld = world_script.new(120, 714, layout.build_collision_world(), String(layout.data.id), layout.content_hash) if campus else world_script.new(120, 714, CollisionWorld.new(2_000_000, 2_000_000))
	if result == null or not result.is_valid():
		last_error = "Actual requested world class did not configure"
		return null
	if campus:
		if not definition.bind_world(result):
			last_error = "Complete campus authority did not bind"
			return null
	elif label != "legacy_paid":
		var court := HexChemistryWorld.new()
		if not court.configure_geometry(ICE_CENTER if label == "paid_black_ice" else ORIGIN, HexGrid.disk(Vector2i.ZERO, 12 if label == "paid_black_ice" else 8)):
			last_error = "Finite branch topology did not configure"
			return null
		court.chemistry_enabled = true
		result.hex_court = court
	var start := layout.spawn * SimConfig.FIXED_SCALE if campus else ORIGIN
	if label == "garden_idle":
		var destination := layout.travel_destination("element-garden")
		var position: Array = destination.get("position", [])
		if position.size() != 2:
			last_error = "Authored Garden arrival is missing"
			return null
		start = Vector2i(int(position[0]), int(position[1])) * SimConfig.FIXED_SCALE
	elif label in ["fire_close", "movement_chain"]: start = Vector2i(1_536_000, 880_000)
	elif label == "campus_wall": start = Vector2i(400_000, 1_790_000)
	elif label == "paid_black_ice": start = ICE_CENTER - Vector2i(100_000, 0)
	var actor := result.player()
	if not _profile(actor, "oh_tipi", start): return null
	var wire := MixtureCatalog.wire_for(63, "mantle") if label == "mantle" else MixtureCatalog.wire_for(2, "bolt")
	if label == "paid_status_death": wire = MixtureCatalog.wire_for(16, "heavy")
	elif label == "paid_black_ice": wire = MixtureCatalog.wire_for(36, "bolt")
	if not actor.place_proven_spell(0, wire):
		last_error = "Actual profile cannot equip the paid fixture spell"
		return null
	if label == "dead_at_entry": actor.health = 0 # Declared initial dead branch.
	if label == "paid_status_death":
		actor.health_recovery_per_second = 0
		actor.flux_recovery_per_second = 0
		actor.health = int(CombatTuning.cast_definition_view(MixtureCatalog.wire_for(2, "rapid")).damage) + 1
		var attacker := PlayerState.new(2)
		if not _profile(attacker, "s_wayne", ORIGIN + Vector2i(80_000, 0)): return null
		attacker.team_id = 2
		attacker.health_recovery_per_second = 0
		attacker.flux_recovery_per_second = 0
		if not attacker.place_proven_spell(0, MixtureCatalog.wire_for(2, "rapid")):
			last_error = "Actual attacker cannot equip finite Fire Rapid"
			return null
		result.players.append(attacker)
	elif label == "paid_black_ice":
		var target := PlayerState.new(2)
		if not _profile(target, "urzh", ICE_CENTER + Vector2i(160_000, 0)): return null
		target.team_id = 2
		result.players.append(target)
	return result


func _known(label: String) -> bool:
	for item: Dictionary in CASES:
		if String(item.label) == label: return true
	return false


func _profile(actor: PlayerState, profile: String, point: Vector2i) -> bool:
	if not champions.apply_to_player(actor, profile):
		last_error = "Current champion profile did not apply: " + profile
		return false
	actor.reset_for_spawn(point)
	return true


func initial_record(label: String) -> Dictionary:
	var totals := {}
	for branch: String in BRANCHES: totals[branch] = 0
	return {"label":label, "attempted_ticks":0, "completed_tick":0, "requested_casts":0,
		"admissions":0, "refusals":0, "releases":0, "admissions_by_actor":{}, "releases_by_wire":{},
		"next_cast_tick":0, "pending_requested":false, "direct_hit_tick":-1, "death_tick":-1,
		"initial":{}, "final":{}, "minimum_stamina":{}, "minimum_flux":{}, "resource_errors":[],
		"maximum_displacement":0, "sprint_seen":false, "air_seen":false, "slide_seen":false,
		"air_dodge_seen":false, "chain_seen":false, "flight_seen":false, "ground_seen":false,
		"product_seen":false, "product_321_seen":false, "black_ice_slow_seen":false,
		"direct_chill_at_field_slow":false, "wall_contact_seen":false, "wall_skim_seen":false,
		"wall_exit_seen":false, "wall_phase":0, "wall_wait":0, "wall_error":"",
		"burn_damage":0, "ground_damage":0, "alive_paid_pending_seen":false,
		"death_cleared_pending":false, "death_expired_matter":0, "death_ground_damage":-1,
		"matter_paid":0, "matter_expired":0, "previous_matter_expired":0,
		"events":[], "requests":[], "branches":totals, "executions":[0,0,0,0,0,0,0],
		"last_error":"", "scope":"One persistent ordinary-command trajectory per case; prepared initial death/legacy/error branches are separately labeled. No trajectory grants or exhibition/render/Bootstrap workload."}


func commands(current: SimWorld, label: String, record: Dictionary) -> Array[SimCommand]:
	if Dictionary(record.initial).is_empty():
		for actor: PlayerState in current.players:
			var key := str(actor.entity_id)
			record.initial[key] = _actor_row(actor)
			record.minimum_stamina[key] = actor.stamina
			record.minimum_flux[key] = actor.flux
	if label == "missing_command": return []
	if label == "wrong_tick": return [SimCommand.new(current.tick + 1, 1)]
	if label == "paid_status_death":
		var victim_press := 0
		if int(record.direct_hit_tick) >= 0 and not bool(record.pending_requested):
			victim_press = SimCommand.PRESSED_SPELL_1
			record.pending_requested = true
		return _record_requests(current, [SimCommand.new(current.tick, 1, 0, 0, 0, victim_press, 0, -1000),
			SimCommand.new(current.tick, 2, 0, 0, 0, SimCommand.PRESSED_SPELL_1 if current.tick == 0 else 0, -1000, 0)], record)
	if label == "paid_black_ice":
		var move := -1000 if not current.hex_court.products.is_empty() else 0
		return _record_requests(current, [SimCommand.new(current.tick, 1, 0, 0, 0, SimCommand.PRESSED_SPELL_1 if current.tick == 0 else 0, 1000, 0, ICE_CENTER.x, ICE_CENTER.y),
			SimCommand.new(current.tick, 2, move, 0)], record)
	if label == "campus_wall": return [_wall_command(current, record)]
	var direction := Vector2i.ZERO
	var held := 0
	var pressed := 0
	var target := Vector2i(-1, -1)
	if label in ["fire_default", "fire_close", "mantle"] and current.tick >= int(record.next_cast_tick):
		var actor := current.player()
		var ready := actor.pending_cast_wire_id == 0 and actor.cast_recovery_ticks == 0 and actor.spell_cooldown_for_wire(actor.spell_wire_id(1)) == 0
		if label != "fire_close" or ready:
			pressed = SimCommand.PRESSED_SPELL_1
			record.next_cast_tick = current.tick + 120
	if label == "fire_close": target = Vector2i(1_736_000, 880_000)
	if label == "legacy_paid" and current.tick == 0: pressed = SimCommand.PRESSED_SPELL_1
	if label == "movement_chain":
		direction = Vector2i(1000, 0) if current.tick < 55 else (Vector2i(0, -1000) if current.tick < 105 else Vector2i.ZERO)
		held = SimCommand.HELD_SPRINT if current.tick < 40 else 0
		if current.tick == 40: pressed = SimCommand.PRESSED_SLIDE
		elif current.tick == 45: pressed = SimCommand.PRESSED_JUMP
		elif current.tick == 55: pressed = SimCommand.PRESSED_EVADE
		elif current.tick == 62: pressed = SimCommand.PRESSED_SPELL_1
	return _record_requests(current, [SimCommand.new(current.tick, 1, direction.x, direction.y, held, pressed, 1000, 0, target.x, target.y)], record)


func _record_requests(current: SimWorld, inputs: Array[SimCommand], record: Dictionary) -> Array[SimCommand]:
	for command: SimCommand in inputs:
		var slot := command.first_pressed_spell_slot()
		if slot == 0: continue
		var actor := current.player(command.entity_id)
		record.requested_casts = int(record.requested_casts) + 1
		record.requests.append({"tick":current.tick, "entity":actor.entity_id, "wire":actor.spell_wire_id(slot),
			"position":[actor.position_x, actor.position_y], "cursor":[command.aim_target_x, command.aim_target_y],
			"flux_before":actor.flux, "pending_before":actor.pending_cast_wire_id,
			"cooldown_before":actor.spell_cooldown_for_wire(actor.spell_wire_id(slot)), "recovery_before":actor.cast_recovery_ticks})
	return inputs


func _wall_command(current: SimWorld, record: Dictionary) -> SimCommand:
	var actor := current.player()
	if current.tick == 0: return SimCommand.new(current.tick, 1, 0, -1000, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
	if current.tick == 1: return SimCommand.new(current.tick, 1, 0, -1000)
	var phase := int(record.wall_phase)
	if phase == 0:
		if actor.wall_contact_id == 115 and actor.movement_commitment_ticks == 0:
			record.wall_phase = 1
			record.wall_wait = 0
			return SimCommand.new(current.tick, 1, 1000, 0, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
		record.wall_wait = int(record.wall_wait) + 1
		if int(record.wall_wait) > 60: record.wall_error = "No ordinary authored-wall contact within approach bound"
		return SimCommand.new(current.tick, 1, 0, -1000)
	if phase == 1:
		if actor.movement_commitment_ticks == 0:
			record.wall_phase = 2
			return SimCommand.new(current.tick, 1, 0, 1000)
		record.wall_wait = int(record.wall_wait) + 1
		if int(record.wall_wait) > 60: record.wall_error = "Wall commitment did not finish within held-route bound"
		return SimCommand.new(current.tick, 1, 1000, 0, SimCommand.HELD_JUMP)
	return SimCommand.new(current.tick, 1)


func observe(current: SimWorld, label: String, record: Dictionary, observed: Dictionary) -> void:
	record.attempted_ticks = int(record.attempted_ticks) + 1
	record.completed_tick = current.tick
	record.last_error = current.last_error
	for key: String in BRANCHES: record.branches[key] = int(record.branches[key]) + int(observed.get(key, 0))
	var counts: PackedInt64Array = observed.get("executions", PackedInt64Array())
	if counts.size() != 7: record.resource_errors.append("Observer did not return exactly seven execution lanes")
	else:
		for index: int in 7: record.executions[index] = int(record.executions[index]) + counts[index]
	for actor: PlayerState in current.players:
		var key := str(actor.entity_id)
		var initial: Dictionary = record.initial[key]
		record.minimum_stamina[key] = mini(int(record.minimum_stamina[key]), actor.stamina)
		record.minimum_flux[key] = mini(int(record.minimum_flux[key]), actor.flux)
		record.final[key] = _actor_row(actor)
		if actor.stamina < 0 or actor.flux < 0 or actor.stamina > actor.stamina_maximum or actor.flux > actor.flux_maximum:
			record.resource_errors.append("Finite resource bound failed at tick %d actor %d" % [current.tick, actor.entity_id])
		if actor.entity_id != 1: continue
		var displacement := absi(actor.position_x - int(initial.x)) + absi(actor.position_y - int(initial.y))
		record.maximum_displacement = maxi(int(record.maximum_displacement), displacement)
		record.sprint_seen = bool(record.sprint_seen) or actor.sprinting
		record.air_seen = bool(record.air_seen) or actor.is_airborne()
		record.slide_seen = bool(record.slide_seen) or actor.slide_ticks > 0
		record.air_dodge_seen = bool(record.air_dodge_seen) or actor.air_dodge_ticks > 0
		record.chain_seen = bool(record.chain_seen) or actor.movement_chain_count >= 3
		record.wall_contact_seen = bool(record.wall_contact_seen) or actor.wall_contact_id == 115
		record.wall_skim_seen = bool(record.wall_skim_seen) or (actor.wall_skim_ticks > 0 and actor.wall_skim_surface_id == 115)
		record.wall_exit_seen = bool(record.wall_exit_seen) or (int(record.wall_phase) == 2 and actor.wall_skim_ticks == 0 and actor.is_airborne() and actor.velocity_y > 0)
		if label == "paid_status_death":
			record.alive_paid_pending_seen = bool(record.alive_paid_pending_seen) or (actor.health > 0 and actor.pending_cast_wire_id == MixtureCatalog.wire_for(16, "heavy") and actor.pending_cast_ticks > 0 and current.hex_court.pending.has(1))
	for event: Dictionary in current.combat_events:
		var kind := String(event.get("type", ""))
		if kind == "cast_started":
			record.admissions = int(record.admissions) + 1
			var owner := str(int(event.entity_id))
			record.admissions_by_actor[owner] = int(record.admissions_by_actor.get(owner, 0)) + 1
		elif kind == "cast_refused": record.refusals = int(record.refusals) + 1
		elif kind == "projectile_spawned":
			record.releases = int(record.releases) + 1
			var wire := str(int(event.wire_id))
			record.releases_by_wire[wire] = int(record.releases_by_wire.get(wire, 0)) + 1
		elif kind == "projectile_hit" and int(event.get("target_id", 0)) == 1:
			record.direct_hit_tick = current.tick
		elif kind == "spell_status_hit" and int(event.get("target_id", 0)) == 1:
			record.burn_damage = int(record.burn_damage) + int(event.damage)
		elif kind == "hex_pressure" and int(event.get("entity_id", 0)) == 1:
			record.ground_damage = int(record.ground_damage) + int(event.amount)
		if kind in ["cast_started", "cast_refused", "projectile_spawned", "projectile_hit", "spell_status_hit", "hex_pressure", "defeated"]:
			record.events.append({"completed_tick":current.tick, "event":event.duplicate(true)})
	record.flight_seen = bool(record.flight_seen) or not current.projectiles.is_empty()
	if current.hex_court != null:
		record.matter_paid = int(current.hex_court.metrics.matter_paid)
		record.matter_expired = int(current.hex_court.metrics.matter_expired)
		for cast: Dictionary in current.hex_court.casts.values():
			record.ground_seen = bool(record.ground_seen) or not Dictionary(cast.get("ground_parts", {})).is_empty()
		record.product_seen = bool(record.product_seen) or not current.hex_court.products.is_empty()
		for product: Dictionary in current.hex_court.products.values():
			record.product_321_seen = bool(record.product_321_seen) or int(product.get("recipe_wire_id", 0)) == 321
		if label == "paid_status_death" and current.player().health == 0 and int(record.death_tick) < 0:
			record.death_tick = current.tick
			record.death_expired_matter = int(record.matter_expired) - int(record.previous_matter_expired)
			record.death_cleared_pending = current.player().pending_cast_wire_id == 0 and current.player().pending_cast_ticks == 0 and not current.hex_court.pending.has(1)
			record.death_ground_damage = int(record.ground_damage)
		record.previous_matter_expired = int(record.matter_expired)
	if label == "paid_black_ice":
		var target := current.player(2)
		if target.control_state == PlayerState.ControlState.SLOWED and target.control_ticks > 0 and target.slow_ratio == 650:
			record.black_ice_slow_seen = true
			record.direct_chill_at_field_slow = bool(record.direct_chill_at_field_slow) or Status.active(target, 2)


func _actor_row(actor: PlayerState) -> Dictionary:
	return {"x":actor.position_x, "y":actor.position_y, "health":actor.health,
		"flux":actor.flux, "stamina":actor.stamina, "pending_wire":actor.pending_cast_wire_id,
		"pending_ticks":actor.pending_cast_ticks, "champion_wire":actor.champion_wire_id}


func validate(label: String, record: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for problem: String in record.resource_errors: errors.append(problem)
	var expected_ticks := 0
	for item: Dictionary in CASES:
		if String(item.label) == label: expected_ticks = int(item.ticks)
	_need(int(record.attempted_ticks) == expected_ticks, "Exact bounded attempted-tick count", errors)
	_need(int(record.completed_tick) == (0 if label == "wrong_tick" else expected_ticks), "Actual completion matches success/failure contract", errors)
	if label == "wrong_tick":
		_need(String(record.last_error).contains("command tick 1 does not match world tick 0"), "Actual wrong-tick failure occurs before actor processing", errors)
		_need(int(record.branches.actors_entered) == 0 and int(record.admissions) == 0, "Failed prefix does not invent actor/cast work", errors)
		return errors
	_need(String(record.last_error).is_empty(), "Successful routes leave no authority error", errors)
	if label in ["fire_default", "fire_close", "mantle", "movement_chain", "legacy_paid", "paid_status_death", "paid_black_ice"]:
		_need(int(record.admissions) > 0 and int(record.releases) > 0, "Actual paid admission and release occur", errors)
		_need(int(record.requested_casts) == int(record.admissions) + int(record.refusals), "Every explicit cast request has an accounted ordinary outcome", errors)
		_need(bool(record.flight_seen), "Actual paid flight persists across a completed step", errors)
		_need(int(record.minimum_flux["1"]) < int(record.initial["1"].flux), "At least one real local admission spends finite Flux", errors)
		_need(int(record.branches.admission_offers) > 0, "Actual admission-offer branch executes", errors)
		if label != "legacy_paid":
			_need(int(record.matter_paid) == 600 * int(record.admissions), "Accepted casts own exact finite paid material", errors)
			_need(int(record.branches.release_results) > 0, "Actual Hex release-binding branch executes", errors)
	if label in ["fire_default", "fire_close", "mantle"]:
		_need(int(record.requested_casts) == 4, "Four ordinary 120-tick opportunities are retained", errors)
		_need(bool(record.ground_seen), "Actual funded ground is reached", errors)
	if label == "fire_close":
		var prior_tick := -120
		for request: Dictionary in record.requests:
			_need(int(request.tick) - prior_tick >= 120 and int(request.pending_before) == 0 and int(request.cooldown_before) == 0 and int(request.recovery_before) == 0, "Close Fire retains real readiness plus minimum 120-tick cadence", errors)
			_need(request.cursor == [1_736_000, 880_000], "Close Fire uses the exact ordinary 200px cursor", errors)
			prior_tick = int(request.tick)
	if label == "mantle": _need(int(record.refusals) > 0, "Fixed-cadence Mantle retains real ordinary refusal cost", errors)
	if label == "legacy_paid":
		_need(int(record.executions[2]) == 0 and int(record.branches.release_results) == 0, "Legacy omits only Hex-specific child/release work", errors)
	if label == "garden_idle":
		_need(int(record.maximum_displacement) == 0 and int(record.admissions) == 0 and int(record.matter_paid) == 0, "Main-world Garden idle has no hidden movement or exhibit casting", errors)
	if label == "missing_command": _need(int(record.branches.missing_command) == 1, "Absent input actually synthesizes one neutral actor command", errors)
	if label == "dead_at_entry":
		_need(int(record.branches.dead_at_entry) == 1 and int(record.branches.dead_after_status) == 0, "Prepared dead actor takes only the entry death exit", errors)
		_need(int(record.executions[0]) == 1 and int(record.executions[1]) == 0, "Dead entry has setup but no later child work", errors)
	if label == "movement_chain":
		_need(bool(record.sprint_seen) and bool(record.slide_seen) and bool(record.air_seen) and bool(record.air_dodge_seen) and bool(record.chain_seen), "Real paid sprint/slide/jump/air-dodge chain occurs", errors)
		_need(int(record.maximum_displacement) > 100_000 and int(record.minimum_stamina["1"]) < int(record.initial["1"].stamina), "Movement actually traverses and consumes finite reserve", errors)
	if label == "paid_status_death":
		_need(int(record.admissions) == 2 and int(record.refusals) == 0 and int(record.direct_hit_tick) > 0, "One actual Fire and one actual Heavy admission surround the real contact", errors)
		_need(bool(record.alive_paid_pending_seen) and int(record.death_tick) > int(record.direct_hit_tick), "Paid Heavy is genuinely pending before subsequent death", errors)
		_need(int(record.branches.dead_after_status) == 1 and int(record.burn_damage) > 0 and int(record.death_ground_damage) == 0, "One real Burn pulse takes the post-status death exit without ground attribution", errors)
		_need(bool(record.death_cleared_pending) and int(record.death_expired_matter) == 600, "Completed death retires exactly the unfired paid reservation stock", errors)
		_need(int(record.releases_by_wire.get(str(MixtureCatalog.wire_for(16, "heavy")), 0)) == 0, "Cancelled Heavy never releases", errors)
		_need(int(record.initial["1"].flux) - int(record.final["1"].flux) == int(CombatTuning.cast_definition_view(MixtureCatalog.wire_for(16, "heavy")).flux_cost), "No refund in the explicitly no-regeneration death control", errors)
	if label == "campus_wall":
		_need(String(record.wall_error).is_empty(), String(record.wall_error), errors)
		_need(bool(record.wall_contact_seen) and bool(record.wall_skim_seen) and bool(record.wall_exit_seen), "Ordinary input reaches wall115, paid skim and outward paid exit", errors)
		_need(int(record.minimum_stamina["1"]) < int(record.initial["1"].stamina), "Authored wall route consumes real finite reserve", errors)
	if label == "paid_black_ice":
		_need(bool(record.product_seen) and bool(record.product_321_seen) and bool(record.black_ice_slow_seen), "Real paid mask36 creates recipe321 and legal movement enters its finite slow", errors)
		_need(not bool(record.direct_chill_at_field_slow), "Field-only branch does not borrow a direct-hit Chilled status", errors)
	return errors


func _need(value: bool, message: String, errors: Array[String]) -> void:
	if not value: errors.append(message)
