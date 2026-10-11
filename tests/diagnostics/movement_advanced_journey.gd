extends "movement_cast_journey.gd"

# Separate lead-scheduled entrypoint. Keep the frozen source-v2 helper beside
# this external script for PCK runs; runtime res:// paths resolve from the pack.
const ADVANCED_PREFIX := "movement-advanced-"
const WALL_ID := 115
const WALL_START := Vector2i(400_000, 1790_000)
var open_anchor := Vector2i.ZERO
var route_in_progress := false
var route_evidence: Dictionary = {}


func _run() -> void:
	facts = {
		"passed": true, "checks": [], "cases": [], "body_profiles": {},
		"float_routes": 0, "double_jump_routes": 0, "dodge_fastfall_routes": 0, "wall_routes": 0,
		"scope": "twelve real Bootstrap input and unified SimWorld advanced routes; catalog-gated flight and no raw air/contact/mode seeding",
		"gaps": ["full direction matrix", "flight natural timeout and exhaustion", "forced hit interruption", "fresh C fast-fall", "wall corners/gaps/lockout", "low Stamina", "mouse endpoint casts", "physical devices", "native scheduler/rendering", "network lifecycle"],
	}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		if argument.begins_with("--isolated-root="): isolated_root = argument.trim_prefix("--isolated-root=")
	var run_root := _normalized(isolated_root)
	if not isolated_root.is_absolute_path() or not isolated_root.replace("\\", "/").trim_suffix("/").get_file().begins_with(ADVANCED_PREFIX) \
		or not _normalized(OS.get_user_data_dir()).begins_with(run_root + "/") \
		or not output.is_absolute_path() or not _normalized(output).begins_with(run_root + "/") \
		or FileAccess.file_exists(output) or FileAccess.file_exists(PlayerPreferences.DEFAULT_PATH):
		push_error("Advanced journey requires fresh movement-advanced-* isolated root, output and redirected user-data")
		quit(2)
		return
	facts.user_data_dir = OS.get_user_data_dir()
	facts.output = output
	facts.runtime_identity = JSON.parse_string(FileAccess.get_file_as_string("res://content/runtime/runtime_build_identity_v1.json"))
	game = JourneyBootstrap.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	if not _check(game.world != null and game.world.hex_court is HexChemistryWorld, "real bootstrap binds Wellspring authority"):
		await _finish()
		return
	facts.bootstrap_profile = _profile_receipt(game.world.player())
	water_heavy = int(game.ability_catalog.ability(game.ability_catalog.spell_id_at("water", "heavy")).get("wire_id", 0))
	open_anchor = _find_clear_anchor(game.world)
	if not _check(water_heavy > 0 and open_anchor != Vector2i.ZERO, "current Water Heavy and clear open campus anchor resolve"):
		await _finish()
		return
	facts.open_anchor = [open_anchor.x, open_anchor.y]
	facts.water_heavy_wire = water_heavy
	if not await _finish_guard() or not await _remap_spell():
		_check(false, "actual Controls setup completed")
		await _finish()
		return
	var bodies: Dictionary = {}
	var flying_bodies: Dictionary = {}
	for champion_id: String in game.champion_catalog.ordered_champion_ids():
		var champion: Dictionary = game.champion_catalog.champions_by_id[champion_id]
		var body := String(champion.body_type)
		var flier := String(champion.ancestry) in ["sylph", "wyrmborn", "angel", "demon"]
		if flier and not flying_bodies.has(body): flying_bodies[body] = champion_id
		elif not flier and not bodies.has(body): bodies[body] = champion_id
	_check(bodies.size() == 3 and flying_bodies.size() == 3, "three real catalog nonflying and flying size profiles selected")
	for body: String in bodies:
		for route: String in ["flight-release", "double-jump", "dodge-fastfall", "wall-release"]:
			if not bool(facts.passed): break
			context = body + "/" + route
			anchor = WALL_START if route == "wall-release" else open_anchor
			var champion_id := String(flying_bodies[body]) if route in ["flight-release", "dodge-fastfall"] else String(bodies[body])
			if not await _new_case(champion_id):
				_check(false, "new advanced case setup completed")
				break
			route_in_progress = true
			route_evidence = {"name": context, "start": [anchor.x, anchor.y], "profile": _profile_receipt(game.world.player())}
			var successful := false
			if route == "flight-release": successful = await _float_release_route()
			elif route == "double-jump": successful = await _double_jump_route()
			elif route == "dodge-fastfall": successful = await _dodge_fastfall_route()
			else: successful = _wall_route()
			_check(successful, "advanced route reached its final acceptance checks")
			route_in_progress = false
			route_evidence["passed"] = successful and bool(facts.passed)
			route_evidence["starts"] = starts
			route_evidence["releases"] = releases
			route_evidence["tick"] = game.world.tick
			facts.cases.append(route_evidence.duplicate(true))
			_release_all()
			await process_frame
	_check(int(facts.float_routes) == 3 and int(facts.double_jump_routes) == 3 and int(facts.dodge_fastfall_routes) == 3 and int(facts.wall_routes) == 3, "exactly twelve advanced routes complete across three actual sizes and both race capability branches")
	completed_run = true
	await _finish()


func _begin_float() -> bool:
	var actor: PlayerState = game.world.player()
	var world: SimWorld = game.world
	_set_travel(Vector2i.ZERO)
	_set_aim(Vector2i(0, -1000))
	var before := actor.stamina
	if not _check(actor.flight_capable, "actual selected catalog race authorizes flight"): return false
	_key(_binding(&"jump"), true)
	if not _tick(): return false
	if not _check(actor.jumpsquat_active and not actor.is_airborne() and actor.stamina == before, "held ground Jump prepares exposed anticipation without payment"): return false
	_key(_binding(&"jump"), false)
	if not _tick(): return false
	if not _check(actor.is_airborne() and actor.air_height > 0 and actor.stamina < before, "real Jump release pays and creates height"): return false
	# Reach near the actual apex before Float so the later dodge commitment has
	# enough real airtime. No height, velocity or timer is assigned by the test.
	var waited := 0
	while (actor.movement_commitment_ticks > 0 or actor.air_vertical_velocity > 2 * world.config.per_tick(MovementTuning.VERTICAL_GRAVITY)) and waited < MAX_PHASE_TICKS:
		if not _tick(): return false
		waited += 1
	if not _check(waited < MAX_PHASE_TICKS and actor.is_airborne(), "held Jump reaches its real airborne admission window"): return false
	_key(_binding(&"jump"), false)
	if not _tick(): return false
	await process_frame
	var height := actor.air_height
	var cost := MovementSystem._movement_action_cost(actor, MovementTuning.FLOAT_COST)
	before = actor.stamina
	_key(_binding(&"jump"), true)
	if not _tick(): return false
	if not _check(actor.air_floating and actor.float_used and actor.air_height == height, "fresh airborne Jump buys Float without another lift"): return false
	_check(before - actor.stamina == cost + world.config.per_tick(MovementTuning.FLOAT_DRAIN_PER_SECOND), "Float admission pays chain-scaled startup and first sustain tick")
	_check(actor.float_ticks > 0 and actor.float_ticks <= world.config.milliseconds_to_ticks(actor.float_max_duration_ms), "Float clock is bounded by actual profile duration")
	_check(not MovementSystem.is_combat_intangible(actor, world.config) and MovementSystem.avoids_ground_effects(actor), "active flight clears ground effects without blanket immunity")
	route_evidence["float_height"] = height
	route_evidence["float_start_cost"] = cost
	route_evidence["float_duration_ms"] = actor.float_max_duration_ms
	return bool(facts.passed)


func _double_jump_route() -> bool:
	var actor: PlayerState = game.world.player()
	if not _check(not actor.flight_capable, "actual selected catalog race uses double jump rather than flight"): return false
	_set_travel(Vector2i.ZERO)
	_set_aim(Vector2i(0, -1000))
	_key(_binding(&"jump"), true)
	if not _tick(): return false
	if not _check(actor.jumpsquat_active and not actor.is_airborne(), "nonflier begins real grounded anticipation"): return false
	_key(_binding(&"jump"), false)
	if not _tick(): return false
	if not _check(actor.is_airborne(), "nonflier jump release takes off"): return false
	var waited := 0
	while actor.movement_commitment_ticks > 0 and waited < MAX_PHASE_TICKS:
		if not _tick(): return false
		waited += 1
	if not _check(waited < MAX_PHASE_TICKS and actor.is_airborne(), "real first arc reaches second-jump admission"): return false
	var before := actor.stamina
	var cost := MovementSystem._movement_action_cost(actor, MovementTuning.DOUBLE_JUMP_COST)
	var flux_before := actor.flux
	_key(_binding(&"jump"), true)
	_key(spell_key, true)
	if not _tick(): return false
	_key(_binding(&"jump"), false)
	_key(spell_key, false)
	_check(actor.double_jump_used and not actor.air_floating and actor.hop_mode == PlayerState.MovementMode.DOUBLE_JUMP, "fresh airborne key press creates real double-jump lift")
	_check(before - actor.stamina == cost and actor.air_vertical_velocity > 0, "double jump pays the exact continuation cost and rises")
	if not _cast_started(flux_before): return false
	waited = 0
	while actor.pending_cast_wire_id != 0 and waited < MAX_PHASE_TICKS:
		if not _tick(): return false
		waited += 1
	if not _check(waited < MAX_PHASE_TICKS and actor.is_airborne(), "double-jump cast completes while the physical arc continues"): return false
	if not _cast_released(Vector2i(0, -1000)): return false
	await process_frame
	before = actor.stamina
	var vertical_before := actor.air_vertical_velocity
	_key(_binding(&"jump"), true)
	if not _tick(): return false
	_check(actor.double_jump_used and not actor.air_floating and actor.air_vertical_velocity < vertical_before and actor.stamina == before, "third press cannot buy flight or another upward impulse")
	_key(_binding(&"jump"), false)
	# The refused fresh edge retains a bounded landing buffer by design; allow
	# it to expire during the real high double-jump arc before proving landing.
	for unused: int in range(game.world.config.milliseconds_to_ticks(MovementTuning.INPUT_BUFFER_MS)):
		if not _tick(): return false
	if not _land(): return false
	_check(not actor.double_jump_used, "real landing restores the next double jump")
	if bool(facts.passed): facts.double_jump_routes += 1
	return bool(facts.passed)


func _float_release_route() -> bool:
	if not await _begin_float(): return false
	var actor: PlayerState = game.world.player()
	var world: SimWorld = game.world
	var height := actor.air_height
	var stamina_before := actor.stamina
	var remainder_before := actor.stamina_remainder
	var tick_before := world.tick
	var flux_before := actor.flux
	_key(spell_key, true)
	if not _tick(): return false
	_key(spell_key, false)
	if not _cast_started(flux_before): return false
	while actor.pending_cast_wire_id != 0 and world.tick - tick_before < MAX_PHASE_TICKS:
		if not _tick(): return false
		if not _check(actor.air_floating and actor.air_height == height, "paid cast startup retains Float at its earned height"): return false
	if not _cast_released(Vector2i(0, -1000)): return false
	@warning_ignore("integer_division")
	var expected_drain: int = -(remainder_before - (world.tick - tick_before) * MovementTuning.FLOAT_DRAIN_PER_SECOND) / world.config.tick_rate
	_check(stamina_before - actor.stamina == expected_drain, "held Float across casting pays exact fractional sustain")
	_key(_binding(&"jump"), false)
	if not _tick(): return false
	_check(not actor.air_floating and not MovementSystem.is_combat_intangible(actor, world.config) and actor.air_height < height, "Jump release immediately ends Float/protection and resumes descent")
	await process_frame
	_key(_binding(&"jump"), true)
	if not _tick(): return false
	_check(not actor.air_floating and actor.float_used, "fresh Jump cannot rebuy spent Float in the same airtime")
	_key(_binding(&"jump"), false)
	if not _land(): return false
	if bool(facts.passed): facts.float_routes += 1
	return bool(facts.passed)


func _dodge_fastfall_route() -> bool:
	if not await _begin_float(): return false
	var actor: PlayerState = game.world.player()
	var world: SimWorld = game.world
	var waited := 0
	while actor.movement_commitment_ticks > 0 and waited < MAX_PHASE_TICKS:
		if not _tick(): return false
		waited += 1
	if not _check(waited < MAX_PHASE_TICKS and actor.air_floating, "Float commitment completes while real height is held"): return false
	_key(_binding(&"jump"), false)
	_set_travel(Vector2i(1000, 0))
	var cost := MovementSystem._movement_action_cost(actor, MovementTuning.AIR_DODGE_COST)
	var stamina_before := actor.stamina
	var flux_before := actor.flux
	_key(_binding(&"evade"), true)
	_key(spell_key, true)
	if not _tick(): return false
	_key(_binding(&"evade"), false)
	_key(spell_key, false)
	_check(actor.air_dodge_ticks > 0 and actor.air_dodge_used and actor.float_used and not actor.air_floating, "directional Evade buys one air dodge and preserves spent Float allowance")
	_check(stamina_before - actor.stamina == cost and Vector2i(actor.air_dodge_x, actor.air_dodge_y) == Vector2i(1000, 0), "air dodge pays chain-scaled cost and follows travel independently of aim")
	if not _cast_started(flux_before): return false
	# Submit fresh neutral intent on the first tick admission becomes available,
	# before ordinary gravity lands this short, physically earned jump.
	waited = 0
	while actor.movement_commitment_ticks > 1 and waited < MAX_PHASE_TICKS:
		if not _tick(): return false
		waited += 1
	if not _check(waited < MAX_PHASE_TICKS and actor.is_airborne(), "dodge remains airborne at its source-derived exit boundary"): return false
	_set_travel(Vector2i.ZERO)
	await process_frame
	stamina_before = actor.stamina
	_key(_binding(&"evade"), true)
	if not _tick(): return false
	_key(_binding(&"evade"), false)
	_check(last_command.move_x == 0 and last_command.move_y == 0 and last_command.has_pressed(SimCommand.PRESSED_EVADE), "fresh Evade reaches authority with genuinely neutral travel")
	_check(actor.fast_falling or (actor.air_height == 0 and actor.landing_intensity >= MovementTuning.LANDING_FAST_FALL_BONUS), "neutral Evade takes vertical fast-fall, including immediate real landing")
	_check(actor.stamina == stamina_before, "neutral fast-fall is free and buys no second air dodge")
	if not _finish_cast_and_land(Vector2i(0, -1000)): return false
	route_evidence["air_dodge_cost"] = cost
	if bool(facts.passed): facts.dodge_fastfall_routes += 1
	return bool(facts.passed)


func _wall_route() -> bool:
	var actor: PlayerState = game.world.player()
	var world: SimWorld = game.world
	if not _preflight_wall(world): return false
	_set_travel(Vector2i(0, -1000))
	_set_aim(Vector2i(0, 1000)) # Shoot away from the wall; tangent travel stays east.
	_key(_binding(&"jump"), true)
	if not _tick(): return false
	if not _check(actor.jumpsquat_active and not actor.is_airborne(), "wall approach prepares real grounded anticipation"): return false
	_key(_binding(&"jump"), false)
	if not _tick(): return false
	var waited := 0
	while (actor.wall_contact_id != WALL_ID or actor.movement_commitment_ticks > 0) and waited < 60:
		if not _tick(): return false
		waited += 1
	if not _check(waited < 60 and actor.is_airborne() and actor.air_height > 0 and actor.wall_contact_id == WALL_ID, "real Jump/north approach acquires existing wall115 while airborne"): return false
	_set_travel(Vector2i(1000, 0))
	var cost := MovementSystem._movement_action_cost(actor, MovementTuning.WALL_SKIM_COST)
	var stamina_before := actor.stamina
	var flux_before := actor.flux
	var stage := actor.hop_stage
	var redirects := actor.air_redirects_remaining
	var spent_float := actor.float_used
	_key(_binding(&"jump"), true)
	_key(spell_key, true)
	if not _tick(): return false
	_key(spell_key, false)
	_check(actor.wall_skim_ticks > 0 and actor.wall_skim_surface_id == WALL_ID and actor.hop_stage == stage, "held tangent Jump attaches to the real wall without replenishing lift")
	_check(stamina_before - actor.stamina == cost and actor.air_redirects_remaining == redirects and actor.float_used == spent_float, "wallrun spends chain-scaled Stamina and preserves airtime budgets")
	if not _cast_started(flux_before): return false
	waited = 0
	while actor.pending_cast_wire_id != 0 and waited < MAX_PHASE_TICKS:
		if not _tick(): return false
		if not _check(actor.wall_skim_ticks > 0 and actor.wall_skim_surface_id == WALL_ID, "wallrun remains on its finite actual face through cast startup"): return false
		waited += 1
	if not _cast_released(Vector2i(0, 1000)): return false
	if not _check(actor.position_x < 620_000, "bounded wall segment stays before the authored corner"): return false
	while actor.movement_commitment_ticks > 0 and waited < MAX_PHASE_TICKS:
		if not _tick(): return false
		waited += 1
	if not _check(waited < MAX_PHASE_TICKS, "wallrun exit commitment completes"): return false
	stamina_before = actor.stamina
	var walljump_cost := MovementSystem._movement_action_cost(actor, MovementTuning.HOP_COST)
	_set_travel(Vector2i(0, 1000))
	_key(_binding(&"jump"), false)
	if not _tick(): return false
	_check(actor.wall_skim_ticks == 0 and actor.is_airborne() and actor.hop_mode == PlayerState.MovementMode.WALL_KICK and actor.jump_protection_ticks == 0 and actor.velocity_y > 0, "Jump release walljumps in legal outward movement direction without blanket immunity")
	_check(stamina_before - actor.stamina == walljump_cost and actor.float_used == spent_float and actor.air_redirects_remaining == redirects and not actor.double_jump_used, "walljump pays its exact continuation cost without spending or replenishing independent air budgets")
	if not _land(): return false
	route_evidence["wall_surface"] = WALL_ID
	route_evidence["wallrun_cost"] = cost
	route_evidence["walljump_cost"] = walljump_cost
	if bool(facts.passed): facts.wall_routes += 1
	return bool(facts.passed)


func _preflight_wall(world: SimWorld) -> bool:
	var found := false
	for obstacle: CollisionWorld.Obstacle in world.collision.obstacle_view():
		if obstacle.obstacle_id == WALL_ID:
			found = obstacle.wall_runnable and obstacle.minimum_x == 352_000 and obstacle.maximum_x == 640_000 and obstacle.maximum_y == 1756_000
	if not _check(found, "unchanged campus wall115 has the expected runnable south face"): return false
	# Exact tangency is the production collision footprint, not the hurt circle.
	var tangent_y := 1756_000 + MovementTuning.PLAYER_RADIUS
	var points: Array[Vector2i] = [WALL_START]
	for y: int in range(tangent_y, WALL_START.y + 1, 1000): points.append(Vector2i(WALL_START.x, y))
	for x: int in range(400_000, 621_000, 4000):
		points.append(Vector2i(x, tangent_y))
		for y: int in range(tangent_y, 1900_001, 8000): points.append(Vector2i(x, y))
	for point: Vector2i in points:
		if not _check(world.collision.can_occupy(point, MovementTuning.PLAYER_RADIUS), "real wall approach/tangent/exit preflight clear at %s" % point): return false
	return true


func _cast_started(flux_before: int) -> bool:
	var actor: PlayerState = game.world.player()
	var cost := int(CombatTuning.cast_definition(water_heavy).flux_cost)
	return _check(starts == 1 and actor.pending_cast_wire_id == water_heavy and actor.flux == flux_before - cost and actor.pending_cast_target_x == -1, "actual spell press pays exactly once and retains controller aim ownership")


func _cast_released(aim: Vector2i) -> bool:
	var world: SimWorld = game.world
	_check(starts == 1 and releases == 1 and world.player().pending_cast_wire_id == 0, "one admitted Water Heavy produces exactly one actual release")
	_check(release_direction != Vector2i.ZERO and DIRECTIONS.classify_index(release_direction.x, release_direction.y) == DIRECTIONS.classify_index(aim.x, aim.y), "projectile follows the committed independent aim")
	return _check(world.hex_court.conservation_valid(), "advanced cast conserves actual paid material") and bool(facts.passed)


func _finish_cast_and_land(aim: Vector2i) -> bool:
	var actor: PlayerState = game.world.player()
	var waited := 0
	while actor.pending_cast_wire_id != 0 and waited < MAX_PHASE_TICKS:
		if not _tick(): return false
		waited += 1
	if not _check(waited < MAX_PHASE_TICKS, "advanced cast reaches finite release"): return false
	return _cast_released(aim) and _land()


func _land() -> bool:
	var actor: PlayerState = game.world.player()
	_key(_binding(&"jump"), false)
	_key(_binding(&"evade"), false)
	_set_travel(Vector2i.ZERO)
	var waited := 0
	while actor.is_airborne() and waited < MAX_PHASE_TICKS:
		if not _tick(): return false
		waited += 1
	return _check(waited < MAX_PHASE_TICKS and actor.air_height == 0 and not actor.air_floating and actor.wall_skim_ticks == 0, "actual advanced route reaches finite ground") and bool(facts.passed)


func _finish() -> void:
	_check(completed_run and not route_in_progress and not tick_in_progress, "all advanced helpers completed without abandoned work")
	_release_all()
	if game != null:
		game.preference_overrides_are_transient = true
		game.preferences_persistence_allowed = false
		game.queue_free()
		await process_frame
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write advanced journey receipt: " + output)
		quit(2)
		return
	file.store_string(JSON.stringify(facts, "  ") + "\n")
	file.close()
	print("MOVEMENT_ADVANCED_JOURNEY passed=%s flight=%d double_jump=%d dodge_fastfall=%d wall=%d checks=%d" % [facts.passed, facts.float_routes, facts.double_jump_routes, facts.dodge_fastfall_routes, facts.wall_routes, facts.checks.size()])
	quit(0 if bool(facts.passed) else 1)
