extends SceneTree
const Harness = preload("res://tests/support/chemistry_coach_harness.gd")
var output := ""
var game: Node2D
var viewport: SubViewport
var records: Array[Dictionary] = []
var failed := false
var paid := 0
var paid_cast_ledger: Array[Dictionary] = []
var tracked_strength_source := 0
var strength_history: Array[Dictionary] = []
var strength_clashes: Array[Dictionary] = []
var strength_scenario: Dictionary = {}
var strength_field_footprints: Dictionary = {}
var strength_field_sources: Array[int] = []
var strength_cache_checks: Array[Dictionary] = []

const HEAVY_ACTOR := 1
const BOLT_ACTOR := 3
const SPRAY_ACTOR := 4
const WATER_HEAVY_SLOT := 3
const FIRE_BOLT_SLOT := 2
const FIRE_SPRAY_SLOT := 8
const WATER_HEAVY_WIRE := 181
const FIRE_BOLT_WIRE := 145
const FIRE_SPRAY_WIRE := 154
const LANE_Y := 480_000
const HEAVY_START := Vector2i(180_000, LANE_Y)
const BOLT_START := Vector2i(900_000, LANE_Y)
const SPRAY_START := Vector2i(650_000, LANE_Y)
const HEAVY_TARGET := Vector2i(950_000, LANE_Y)
const BOLT_TARGET := Vector2i(470_000, LANE_Y)
const SPRAY_TARGET := Vector2i(1_030_000, LANE_Y)

func _initialize() -> void:
	root.hide()
	_run.call_deferred()

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if not output.begins_with("res://.godot/hex-court-") or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("fresh contained output required")
		return
	DirAccess.make_dir_recursive_absolute(output)
	game = Harness.new()
	if not game.configure_fixture(true):
		_fail("production fixture failed")
		return
	game.material_registry = MaterialRegistry.new()
	game.material_yard = MaterialYardDefinition.new()
	if not game.material_registry.load_from_file(game.MATERIAL_CATALOG_PATH) or not game.material_yard.load_from_file(game.MATERIAL_YARD_PATH, game.material_registry):
		_fail("court return content failed")
		return
	game.player_preferences.set_camera_zoom_percent(75)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(game)
	await _capture("ordinary-wellspring")
	if not _reset(): return
	await _capture("dry-court")
	var water_point := HexCourt.ORIGIN + HexGrid.center(Vector2i(-2, 0))
	var fire_point := HexCourt.ORIGIN + HexGrid.center(Vector2i(2, -1))
	if not _cast(2, fire_point): return
	if not _terminal(): return
	await _capture("fire-ignition")
	_advance(30)
	await _capture("fire-active")
	if not _cast(1, water_point) or not _terminal(): return
	await _capture("water-and-fire")
	if not _cast(2, water_point) or not _terminal(): return
	if game.world.hex_court.products.size() != 1:
		_fail("paid Water and Fire did not make one Steam product")
		return
	await _capture("steam-forming")
	_advance(24)
	await _capture("steam-normal")
	game.player_preferences.reduced_motion = true
	await _capture("steam-reduced")
	game.player_preferences.reduced_motion = false
	if not _cast(2, water_point) or not _terminal(): return
	await _capture("steam-heated")
	if not _cast(1, water_point) or not _terminal(): return
	await _capture("steam-cooled-fixed-footprint")
	if game.world.hex_court.metrics.modifiers != 2:
		_fail("paid fresh Fire and Water must each modify once")
		return
	for entry: Array in [[1, "flood"], [2, "conflagration"]]:
		if not _reset() or not _cast(int(entry[0]), water_point) or not _terminal(): return
		if not _cast(int(entry[0]), water_point) or not _terminal(): return
		if game.world.hex_court.products.size() != 1:
			_fail("paid mirror did not create one product")
			return
		await _capture(String(entry[1]) + "-forming")
		_advance(24)
		await _capture(String(entry[1]) + "-active")
		game.player_preferences.reduced_motion = true
		await _capture(String(entry[1]) + "-reduced")
		game.player_preferences.reduced_motion = false
	# Each family uses the same real command path. Resets are the actual retry action.
	for entry: Array in [[5, "rapid"], [1, "bolt"], [3, "heavy"], [7, "spray"]]:
		if not _reset() or not _cast(int(entry[0]), water_point): return
		var world: SimWorld = game.world
		for _index: int in range(360):
			if not world.projectiles.is_empty() or world.hex_court.pending.is_empty(): break
			_step()
		await _capture(String(entry[1]) + "-release")
		if not _terminal(): return
		await _capture(String(entry[1]) + "-ground")
	for entry: Array in [["off-center-edge", Vector2i(-97_000, 2000)], ["off-center-vertex", Vector2i(-127_000, 35_950)]]:
		if not _reset() or not _cast(3, HexCourt.ORIGIN + entry[1]) or not _terminal(): return
		await _capture(String(entry[0]))
		game.player_preferences.reduced_motion = true
		await _capture(String(entry[0]) + "-reduced")
		game.player_preferences.reduced_motion = false
	# Actual continuous movement through a fresh paid Steam patch, then exit.
	if not _reset(): return
	var close_point := HexCourt.ORIGIN + HexGrid.center(Vector2i(-1, 3))
	if not _cast(1, close_point) or not _terminal() or not _cast(2, close_point) or not _terminal(): return
	for _index: int in range(44):
		_step(0, -1000)
	await _capture("steam-walk-through")
	for _index: int in range(70):
		_step(1000, 0)
	await _capture("steam-exit")
	if not await _capture_strength_traverse(): return
	game._start_match(120)
	game.controls_input_guard_frames = 0
	if game.world.hex_court != null:
		_fail("return did not restore Wellspring")
		return
	await _capture("returned-wellspring")
	if failed: return
	if records.size() != 37:
		_fail("the 31 retained captures plus six strength captures must total 37")
		return
	var file := FileAccess.open(output + "/capture-receipt.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"status": "passed",
		"scope": "S3 paid Water Heavy 15 traverses pre-existing paid Fire Bolt 5 disk then Fire Spray 3 sector; six drawn-tick-settled normal/reduced strength frames; retains all 31 S2 captures; not human acceptance or rendered performance",
		"paid_casts": paid,
		"paid_cast_ledger": paid_cast_ledger,
		"strength_scenario": strength_scenario,
		"frames": records,
	}, "  "))
	file.close()
	print("PASS: hex court capture %d frames; %d paid casts; authority unchanged by drawing" % [records.size(), paid])
	game.queue_free()
	await process_frame
	quit(0)

func _reset() -> bool:
	if not game._start_hex_court():
		_fail("court entry/reset failed")
		return false
	game.controls_input_guard_frames = 0
	return true

func _cast(slot: int, target: Vector2i) -> bool:
	return _cast_actor(1, slot, target)

func _cast_actor(actor_id: int, slot: int, target: Vector2i) -> bool:
	var world: SimWorld = game.world
	var actor := world.player(actor_id)
	if actor == null or slot < 1 or slot > PlayerState.SPELL_SLOT_COUNT:
		_fail("fixture cast actor/slot missing: %d/%d" % [actor_id, slot])
		return false
	for _index: int in range(180):
		if actor.pending_cast_wire_id == 0 and actor.spell_cooldown_ticks[slot - 1] == 0: break
		_step()
	var wire := actor.spell_wire_id(slot)
	var cost := int(CombatTuning.cast_definition(wire).flux_cost)
	var before := actor.flux
	var matter_before := int(world.hex_court.metrics.matter_paid) if world.hex_court != null else 0
	var regenerated := PlayerState.new(actor.entity_id)
	for field: String in ["flux", "flux_maximum", "flux_recovery_delay_ticks", "flux_recovery_idle_ticks", "flux_recovery_remainder", "flux_recovery_per_second", "chemistry_regen_block_ticks"]:
		regenerated.set(field, actor.get(field))
	PlayerResourcesSystem.step(regenerated, world.config)
	var delta := target - Vector2i(actor.position_x, actor.position_y)
	var command := SimCommand.new(world.tick, actor_id, 0, 0, 0, int(SimCommand.SPELL_PRESSED_BITS[slot - 1]), delta.x, delta.y, target.x, target.y)
	if not world.step([command]) or actor.flux != regenerated.flux - cost or cost <= 0:
		_fail("real paid cast failed: actor %d slot %d, Flux %d to %d" % [actor_id, slot, before, actor.flux])
		return false
	if world.hex_court == null or int(world.hex_court.metrics.matter_paid) != matter_before + HexCourt.MATTER_PER_CAST:
		_fail("accepted cast did not commit exactly one authoritative matter budget")
		return false
	paid += 1
	var cast_id := int(world.hex_court.pending.get(actor_id, 0))
	paid_cast_ledger.append({
		"actor_id": actor_id,
		"slot": slot,
		"wire_id": wire,
		"cast_id": cast_id,
		"press_tick": world.tick - 1,
		"target": [target.x, target.y],
		"aim": [command.aim_x, command.aim_y],
		"flux_before": before,
		"flux_after": actor.flux,
		"display_flux_cost": float(cost) / float(SimConfig.FIXED_SCALE),
		"fixed_flux_cost": cost,
		"matter_paid": HexCourt.MATTER_PER_CAST,
	})
	_record_strength_authority()
	_sync()
	return true

func _terminal() -> bool:
	var world: SimWorld = game.world
	for _index: int in range(420):
		if world.hex_court.pending.is_empty() and world.projectiles.is_empty(): return not failed
		_step()
	_fail("paid terminal did not finish")
	return false

func _advance(ticks: int) -> void:
	for _index: int in range(ticks): _step()

func _step(move_x: int = 0, move_y: int = 0) -> void:
	var world: SimWorld = game.world
	if not world.step([SimCommand.new(world.tick, 1, move_x, move_y, 0, 0, world.player().aim_x, world.player().aim_y)]):
		_fail("continuous world step failed")
	if world.hex_court != null and not world.hex_court.conservation_valid(): _fail("matter conservation failed")
	_record_strength_authority()
	_sync()

func _sync() -> void:
	game.current_position = game._player_position()
	game.previous_position = game.current_position
	game.previous_air_height = game.world.player().air_height
	game._update_combat_cues(1.0 / 120.0)
	game._ingest_combat_cues(game.world.combat_events)

func _capture(label: String) -> void:
	var before: String = game.world.state_hash()
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var frame := viewport.get_texture().get_image()
	if frame == null or frame.is_empty() or frame.save_png(output + "/" + label + ".png") != OK or game.world.state_hash() != before:
		_fail("capture failed or mutated authority: " + label)
		return
	var record := {"file": label + ".png", "tick": game.world.tick, "world_hash": before, "health": game.world.player().health, "flux": game.world.player().flux}
	record.projectiles = _projectile_receipt()
	if game.world.hex_court != null:
		var court: HexCourt = game.world.hex_court
		record.metrics = court.metrics.duplicate(true)
		record.cast_ledgers = HexCourt._stable(court.casts)
		record.products = HexCourt._stable(court.products)
		record.exposure = HexCourt._stable(court.exposure)
	records.append(record)

func _capture_strength_traverse() -> bool:
	if not _prepare_strength_fixture(): return false
	var world: SimWorld = game.world
	var court: HexCourt = world.hex_court
	var matter_before := int(court.metrics.matter_paid)
	var paid_receipt_start := paid_cast_ledger.size()
	if not _cast_actor(BOLT_ACTOR, FIRE_BOLT_SLOT, BOLT_TARGET): return false
	if not _terminal(): return false
	var bolt_field := _latest_ground_field(BOLT_ACTOR, FIRE_BOLT_WIRE)
	if bolt_field.is_empty():
		_fail("paid Fire Bolt did not create its strength-5 terminal ground field before Heavy release")
		return false
	if not _cast_actor(SPRAY_ACTOR, FIRE_SPRAY_SLOT, SPRAY_TARGET): return false
	if not _terminal(): return false
	var spray_field := _latest_ground_field(SPRAY_ACTOR, FIRE_SPRAY_WIRE)
	if spray_field.is_empty():
		_fail("paid Fire Spray did not create its strength-3 terminal ground sector before Heavy release")
		return false
	strength_field_sources = [int(bolt_field.source), int(spray_field.source)]
	strength_field_footprints = {
		int(bolt_field.source): bolt_field.footprint.duplicate(true),
		int(spray_field.source): spray_field.footprint.duplicate(true),
	}
	strength_scenario.preexisting_fields = [
		HexCourt._stable(bolt_field.duplicate(true)),
		HexCourt._stable(spray_field.duplicate(true)),
	]
	if not _cast_actor(HEAVY_ACTOR, WATER_HEAVY_SLOT, HEAVY_TARGET): return false
	var heavy: ProjectileState = _wait_for_owned_projectile(HEAVY_ACTOR, WATER_HEAVY_WIRE, 40)
	if heavy == null:
		_fail("paid Water Heavy did not release into the fixture lane")
		return false
	tracked_strength_source = heavy.source_cast_id
	strength_scenario.heavy_source_cast_id = tracked_strength_source
	_record_strength_authority()
	if not _expect_strength(15, "released full-strength Heavy before either field"): return false
	if not await _capture_strength_pair("heavy-strength-full-15"): return false
	if not await _render_strength_probe(15, true): return false
	if not _wait_for_strength(10, 180):
		_fail("Water Heavy did not enter the separate paid Fire Bolt ground field as 15 -> 10")
		return false
	if not await _settle_presenter_size(10): return false
	if not _expect_strength(10, "six-tick settled post-Bolt Heavy"): return false
	if not await _capture_strength_pair("heavy-strength-10"): return false
	if not _wait_for_strength(7, 180):
		_fail("surviving Water Heavy did not enter the later paid Fire Spray ground sector as 10 -> 7")
		return false
	if not await _settle_presenter_size(7): return false
	if not _expect_strength(7, "six-tick settled post-Spray Heavy"): return false
	if not await _capture_strength_pair("heavy-strength-7"): return false
	if not _validate_strength_geometry(): return false
	if not _terminal(): return false
	if not court.conservation_valid():
		_fail("terminal strength fixture failed matter conservation")
		return false
	var paid_delta := int(court.metrics.matter_paid) - matter_before
	var ground_quantity := 0
	for id: int in court.casts:
		ground_quantity += int(court.casts[id].ground)
	if paid_delta != HexCourt.MATTER_PER_CAST * 3 or int(court.metrics.matter_consumed) != 1520 or ground_quantity != 280:
		_fail("terminal 15 -> 10 -> 7 ledger must conserve 1800 as 1520 consumed + 280 ground")
		return false
	strength_scenario.terminal = {
		"tick": world.tick,
		"matter_paid_delta": paid_delta,
		"matter_consumed": int(court.metrics.matter_consumed),
		"matter_expired": int(court.metrics.matter_expired),
		"ground_quantity": ground_quantity,
		"conservation_valid": true,
		"cast_ledgers": HexCourt._stable(court.casts),
		"products": HexCourt._stable(court.products),
	}
	strength_scenario.strength_history = strength_history.duplicate(true)
	strength_scenario.clashes = strength_clashes.duplicate(true)
	strength_scenario.cached_size_checks = strength_cache_checks.duplicate(true)
	strength_scenario.paid_casts = paid_cast_ledger.slice(paid_receipt_start).duplicate(true)
	tracked_strength_source = 0
	return true

func _prepare_strength_fixture() -> bool:
	if not _reset(): return false
	var world: SimWorld = game.world
	var lead: PlayerState = world.player()
	lead.reset_for_spawn(HEAVY_START)
	lead.team_id = 1
	world.players = [lead]
	for fixture: Array in [[BOLT_ACTOR, BOLT_START], [SPRAY_ACTOR, SPRAY_START]]:
		var actor := PlayerState.new(int(fixture[0]))
		actor.team_id = 1
		actor.champion_wire_id = lead.champion_wire_id
		actor.primary_wire_id = lead.primary_wire_id
		actor.active_1_wire_id = lead.active_1_wire_id
		actor.active_2_wire_id = lead.active_2_wire_id
		actor.spell_wire_ids = lead.spell_wire_ids.duplicate()
		actor.spell_cooldown_ticks = lead.spell_cooldown_ticks.duplicate()
		actor.reset_for_spawn(fixture[1])
		world.players.append(actor)
	for actor: PlayerState in world.players:
		if not actor.has_valid_spell_slots() or not world.collision.can_occupy(Vector2i(actor.position_x, actor.position_y), MovementTuning.PLAYER_RADIUS):
			_fail("strength fixture actor has invalid real loadout or placement: %d" % actor.entity_id)
			return false
	if lead.spell_wire_id(WATER_HEAVY_SLOT) != WATER_HEAVY_WIRE \
		or world.player(BOLT_ACTOR).spell_wire_id(FIRE_BOLT_SLOT) != FIRE_BOLT_WIRE \
		or world.player(SPRAY_ACTOR).spell_wire_id(FIRE_SPRAY_SLOT) != FIRE_SPRAY_WIRE:
		_fail("temporary eight-slot Water/Fire practice kit drifted")
		return false
	var heavy := CombatTuning.cast_definition(WATER_HEAVY_WIRE)
	var bolt := CombatTuning.cast_definition(FIRE_BOLT_WIRE)
	var spray := CombatTuning.cast_definition(FIRE_SPRAY_WIRE)
	if String(heavy.get("family", "")) != "heavy" or int(heavy.get("reaction_strength", 0)) != 15 \
		or int(heavy.get("speed", 0)) != 320_000 or int(heavy.get("radius", 0)) != 19_200 or int(heavy.get("blast_radius", 0)) != 84_000 \
		or String(bolt.get("family", "")) != "bolt" or int(bolt.get("reaction_strength", 0)) != 5 \
		or int(bolt.get("speed", 0)) != 537_600 or int(bolt.get("radius", 0)) != 10_800 \
		or String(spray.get("family", "")) != "spray" or int(spray.get("reaction_strength", 0)) != 3 \
		or int(spray.get("range", 0)) != 380_000 or int(spray.get("radius", 0)) != 9_000 \
		or int(spray.get("cone_cosine_squared_per_million", 0)) != 820_000:
		_fail("authored 15/5/3 strength, speed, collision, blast, or sector geometry drifted")
		return false
	if int(heavy.get("flux_cost", 0)) != 18_000 or int(bolt.get("flux_cost", 0)) != 6_000 or int(spray.get("flux_cost", 0)) != 12_000:
		_fail("compiled strength fixture costs drifted from 18/6/12 display Flux (18000/6000/12000 fixed)")
		return false
	var spray_aim := SimCommand._normalized_direction(SPRAY_TARGET.x - SPRAY_START.x, SPRAY_TARGET.y - SPRAY_START.y)
	var spray_sector := HexFootprint.sector(SPRAY_START, spray_aim, int(spray.range), int(spray.cone_cosine_squared_per_million))
	if not HexFootprint.validate(spray_sector) or not HexFootprint.contains(spray_sector, Vector2i(800_000, LANE_Y)):
		_fail("authored Fire Spray sector does not cover the intended later lane without extending its range")
		return false
	tracked_strength_source = 0
	strength_history.clear()
	strength_clashes.clear()
	strength_field_sources.clear()
	strength_field_footprints.clear()
	strength_cache_checks.clear()
	strength_scenario = {
		"authority": "two paid terminal ground fields exist before one paid Water Heavy; three real SimCommand casts, Flux payments, HexCourt ledgers and field contacts; no projectile or ledger fabrication",
		"teams": "all fixture casters share team 1 so player damage cannot terminate the lane; persistent field interception remains authoritative",
		"placements": {
			"water_heavy_actor_1": [HEAVY_START.x, HEAVY_START.y],
			"fire_bolt_actor_3": [BOLT_START.x, BOLT_START.y],
			"fire_spray_actor_4": [SPRAY_START.x, SPRAY_START.y],
			"lane_y": LANE_Y,
		},
		"targets": {
			"water_heavy": [HEAVY_TARGET.x, HEAVY_TARGET.y],
			"fire_bolt": [BOLT_TARGET.x, BOLT_TARGET.y],
			"fire_spray": [SPRAY_TARGET.x, SPRAY_TARGET.y],
		},
		"authored": {
			"water_heavy": {"wire_id": WATER_HEAVY_WIRE, "strength": 15, "speed": 320000, "collision_radius": 19200, "terminal_radius": 84000, "display_flux_cost": 18, "fixed_flux_cost": 18000},
			"fire_bolt": {"wire_id": FIRE_BOLT_WIRE, "strength": 5, "speed": 537600, "collision_radius": 10800, "display_flux_cost": 6, "fixed_flux_cost": 6000},
			"fire_spray": {"wire_id": FIRE_SPRAY_WIRE, "strength": 3, "range": 380000, "collision_radius": 9000, "cone_cosine_squared": 820000, "display_flux_cost": 12, "fixed_flux_cost": 12000},
		},
		"settle_ticks_per_strength_change": 6,
	}
	_sync()
	return true

func _capture_strength_pair(label: String) -> bool:
	await _capture(label)
	if failed: return false
	game.player_preferences.reduced_motion = true
	await _capture(label + "-reduced")
	game.player_preferences.reduced_motion = false
	return not failed

func _settle_presenter_size(expected_strength: int) -> bool:
	# The first draw discovers the new target. Each following authority tick is
	# drawn so the presenter's six-tick cache interpolation actually advances.
	if not await _render_strength_probe(expected_strength, false): return false
	for index: int in range(6):
		_step()
		if not await _render_strength_probe(expected_strength, index == 5): return false
	return true

func _render_strength_probe(expected_strength: int, require_settled: bool) -> bool:
	var before := game.world.state_hash()
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	if game.world.state_hash() != before:
		_fail("non-recorded presenter settle draw mutated authority")
		return false
	var shot := _projectile_by_source(tracked_strength_source)
	if shot == null:
		_fail("Heavy ended during bounded presenter settle")
		return false
	var cache_value: Variant = game.hex_court_presenter.get("_projectile_size_cache")
	if not cache_value is Dictionary:
		_fail("HexCourtPresenter size cache is unavailable to the capture assertion")
		return false
	var cache: Dictionary = cache_value
	if not cache.has(shot.entity_id):
		_fail("HexCourtPresenter did not retain the drawn Heavy cache entry")
		return false
	var entry: Dictionary = cache[shot.entity_id]
	var expected_size := HexCourtPresenter.strength_scaled_size(float(HexCourtPresenter.FAMILY_SIZE["heavy"]), expected_strength, 15)
	var actual_size := HexCourtPresenter._cached_projectile_size(entry, float(game.world.tick))
	if roundi(float(entry.get("target_size", -1.0)) * 1000.0) != roundi(expected_size * 1000.0):
		_fail("presenter cache target does not match the authoritative Heavy strength")
		return false
	if require_settled and (float(entry.get("end_tick", 1.0e20)) > float(game.world.tick) or not is_equal_approx(actual_size, expected_size)):
		_fail("Heavy presentation size did not settle to strength %d after six drawn ticks" % expected_strength)
		return false
	if require_settled:
		strength_cache_checks.append({
			"tick": game.world.tick,
			"strength": expected_strength,
			"expected_size": expected_size,
			"actual_cached_size": actual_size,
			"target_size": float(entry.target_size),
			"end_tick": float(entry.end_tick),
		})
	return true

func _latest_ground_field(owner_id: int, wire_id: int) -> Dictionary:
	var court: HexCourt = game.world.hex_court
	var ids: Array = court.casts.keys()
	ids.sort()
	ids.reverse()
	for id: int in ids:
		var cast: Dictionary = court.casts[id]
		var ledger: Dictionary = cast.get("ledger", {})
		if int(cast.owner) == owner_id and int(cast.wire) == wire_id and int(cast.source) > 0 \
			and int(cast.ground) == HexCourt.MATTER_PER_CAST and StrengthBudget.validate(ledger) \
			and int(ledger.remaining_strength) == int(cast.strength) and int(ledger.deposited_quantity) == HexCourt.MATTER_PER_CAST \
			and HexFootprint.validate(cast.get("footprint", {})):
			return cast
	return {}

func _wait_for_owned_projectile(owner_id: int, wire_id: int, maximum_ticks: int) -> ProjectileState:
	for _index: int in range(maximum_ticks + 1):
		for shot: ProjectileState in game.world.projectiles:
			if shot.owner_id == owner_id and shot.source_wire_id == wire_id:
				return shot
		if _index < maximum_ticks: _step()
	return null

func _wait_for_strength(expected: int, maximum_ticks: int) -> bool:
	for _index: int in range(maximum_ticks + 1):
		var ledger: Dictionary = game.world.hex_court.ledger_for_source(tracked_strength_source)
		if not ledger.is_empty():
			var remaining := int(ledger.remaining_strength)
			if remaining == expected: return true
			if remaining < expected:
				return false
		if _index < maximum_ticks: _step()
	return false

func _expect_strength(expected: int, context: String) -> bool:
	var ledger: Dictionary = game.world.hex_court.ledger_for_source(tracked_strength_source)
	var shot := _projectile_by_source(tracked_strength_source)
	if ledger.is_empty() or shot == null or int(ledger.remaining_strength) != expected or shot.remaining_strength != expected:
		_fail("%s lost its authoritative projectile/ledger strength %d" % [context, expected])
		return false
	return true

func _validate_strength_geometry() -> bool:
	if strength_clashes.size() != 2:
		_fail("strength fixture must create exactly two field clashes with no per-cell or per-tick drain")
		return false
	var first: Dictionary = strength_clashes[0]
	var second: Dictionary = strength_clashes[1]
	if String(first.get("contact_kind", "")) != "field" or String(second.get("contact_kind", "")) != "field" \
		or int(first.get("source_wire_id", 0)) != WATER_HEAVY_WIRE or int(second.get("source_wire_id", 0)) != WATER_HEAVY_WIRE \
		or int(first.get("other_wire_id", 0)) != FIRE_BOLT_WIRE or int(second.get("other_wire_id", 0)) != FIRE_SPRAY_WIRE \
		or int(first.get("field_source_id", 0)) != strength_field_sources[0] or int(second.get("field_source_id", 0)) != strength_field_sources[1] \
		or int(first.matched_strength) != 5 or int(second.matched_strength) != 3 \
		or int(first.first_remaining) != 10 or int(second.first_remaining) != 7 \
		or int(first.second_remaining) != 0 or int(second.second_remaining) != 0:
		_fail("clash ordering must consume Fire Bolt 5 before Fire Spray 3")
		return false
	var first_point := Vector2i(int(first.x), int(first.y))
	var second_point := Vector2i(int(second.x), int(second.y))
	if first_point.x <= HEAVY_START.x or first_point.x >= SPRAY_START.x or absi(first_point.y - LANE_Y) > 1 \
		or not HexFootprint.contains(strength_field_footprints[strength_field_sources[0]], first_point):
		_fail("paid Heavy/Bolt-field clash left the authored horizontal field footprint")
		return false
	var spray_sector: Dictionary = strength_field_footprints[strength_field_sources[1]]
	if second_point.x <= first_point.x or not HexFootprint.contains(spray_sector, second_point) or absi(second_point.y - LANE_Y) > 1:
		_fail("second contact must be later along travel and inside the exact authored Fire Spray sector")
		return false
	var observed_strengths: Dictionary = {}
	for observation: Dictionary in strength_history:
		observed_strengths[int(observation.remaining_strength)] = true
	for expected: int in [15, 10, 7]:
		if not observed_strengths.has(expected):
			_fail("moving authority receipt missed Heavy strength %d" % expected)
			return false
	for observed: int in observed_strengths:
		if observed not in [15, 10, 7]:
			_fail("persistent field contact drained Heavy outside the exact 15/10/7 sequence")
			return false
	var spray_aim := SimCommand._normalized_direction(SPRAY_TARGET.x - SPRAY_START.x, SPRAY_TARGET.y - SPRAY_START.y)
	strength_scenario.geometry = {
		"fire_bolt_field_contact": [first_point.x, first_point.y],
		"fire_spray_field_contact": [second_point.x, second_point.y],
		"spray_sector_origin": [SPRAY_START.x, SPRAY_START.y],
		"spray_sector_aim": [spray_aim.x, spray_aim.y],
		"spray_sector_range": int(spray_sector.range),
		"contacts_inside_authored_ground_geometry": true,
		"field_sources_consumed_once": strength_field_sources.duplicate(),
	}
	return true

func _record_strength_authority() -> void:
	var world: SimWorld = game.world
	if world.hex_court == null: return
	for event: Dictionary in world.combat_events:
		if String(event.get("type", "")) == "hex_clash" and tracked_strength_source > 0:
			var copy: Dictionary = event.duplicate(true)
			copy.tick = world.tick
			strength_clashes.append(copy)
	if tracked_strength_source <= 0: return
	var ledger: Dictionary = world.hex_court.ledger_for_source(tracked_strength_source)
	var shot := _projectile_by_source(tracked_strength_source)
	if ledger.is_empty() or shot == null: return
	strength_history.append({
		"tick": world.tick,
		"projectile_id": shot.entity_id,
		"source_cast_id": tracked_strength_source,
		"position": [shot.position_x, shot.position_y],
		"collision_radius": shot.radius,
		"initial_strength": int(ledger.initial_strength),
		"remaining_strength": int(ledger.remaining_strength),
		"flight_quantity": int(ledger.flight_quantity),
		"consumed_quantity": int(ledger.consumed_quantity),
	})

func _projectile_by_source(source_id: int) -> ProjectileState:
	for shot: ProjectileState in game.world.projectiles:
		if shot.source_cast_id == source_id:
			return shot
	return null

func _projectile_receipt() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for shot: ProjectileState in game.world.projectiles:
		result.append({
			"projectile_id": shot.entity_id,
			"owner_id": shot.owner_id,
			"source_cast_id": shot.source_cast_id,
			"wire_id": shot.source_wire_id,
			"position": [shot.position_x, shot.position_y],
			"collision_radius": shot.radius,
			"initial_strength": shot.initial_strength,
			"remaining_strength": shot.remaining_strength,
		})
	return result

func _fail(message: String) -> void:
	failed = true
	push_error(message)
	quit(1)
