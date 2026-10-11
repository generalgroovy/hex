extends SceneTree

# Lead-scheduled source or external-script/PCK diagnostic. Uses inherited real
# Bootstrap input routing and unified SimWorld, but no frame/render scheduler.
# Profiles, initial actor/kit/resource state and the clear lane are fixtures.
class JourneyBootstrap:
	extends "res://src/app/bootstrap.gd"
	func _draw() -> void:
		pass

const DIRECTIONS = preload("res://src/presentation/eight_direction_resolver.gd")
const MAX_PHASE_TICKS := 480
const PROFILE_PREFIX := "movement-cast-"
var game: Node
var output := ""
var isolated_root := ""
var anchor := Vector2i.ZERO
var water_heavy := 0
var spell_key := KEY_J
var context := "setup"
var held_keys: Dictionary = {}
var starts := 0
var releases := 0
var flux_refusals := 0
var release_direction := Vector2i.ZERO
var last_command: SimCommand
var tick_in_progress := false
var completed_run := false
var facts := {
	"passed": true, "checks": [], "cases": [], "router_samples": 0,
	"paid_transition_cases": 0, "focus_cases": 0, "low_flux_cases": 0,
	"body_profiles": {},
	"scope": "production Bootstrap events/sample -> unified SimWorld.step; no rendered or physical-device acceptance",
	"fixture_setup": "initial profile/kit/resources and collision-checked campus anchor; no movement-mode seeding",
	"gaps": ["full 192-pair physics journey", "mouse endpoint release geometry", "Float/air-dodge/fastfall/wall transitions", "low-Stamina boundary", "Rapid hold-repeat focus recovery", "native frame scheduler", "physical keyboard/controller", "network lifecycle", "visual animation acceptance"],
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		if argument.begins_with("--isolated-root="): isolated_root = argument.trim_prefix("--isolated-root=")
	# Refuse before Bootstrap can load/save preferences. The runner must redirect
	# APPDATA/user-data under its fresh movement-cast-* run directory explicitly.
	var actual_user := _normalized(OS.get_user_data_dir())
	var run_root := _normalized(isolated_root)
	var output_path := _normalized(output)
	if not isolated_root.is_absolute_path() or not isolated_root.replace("\\", "/").trim_suffix("/").get_file().begins_with(PROFILE_PREFIX) \
		or not actual_user.begins_with(run_root + "/") or not output_path.begins_with(run_root + "/") \
		or FileAccess.file_exists(output) or FileAccess.file_exists(PlayerPreferences.DEFAULT_PATH):
		push_error("Provide fresh --output and --isolated-root=<absolute movement-cast-* directory>, with user-data redirected beneath that directory")
		quit(2)
		return
	facts.user_data_dir = OS.get_user_data_dir()
	facts.output = output
	var identity: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/runtime/runtime_build_identity_v1.json"))
	facts.runtime_identity = identity if identity is Dictionary else {}
	game = JourneyBootstrap.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	if not _check(game.world != null and game.world.hex_court is HexChemistryWorld, "normal Bootstrap creates unified Wellspring authority"):
		await _finish()
		return
	# Capture untouched normal boot before any explicit diagnostic profile setup.
	facts.bootstrap_profile = _profile_receipt(game.world.player())
	water_heavy = int(game.ability_catalog.ability(game.ability_catalog.spell_id_at("water", "heavy")).get("wire_id", 0))
	if not _check(water_heavy > 0 and CombatTuning.is_runtime_wire_id(water_heavy), "Water Heavy is derived from the enabled current catalog"):
		await _finish()
		return
	anchor = _find_clear_anchor(game.world)
	if not _check(anchor != Vector2i.ZERO, "campus has an actual collision-clear eight-direction fixture lane"):
		await _finish()
		return
	facts.anchor = [anchor.x, anchor.y]
	facts.default_evade_key = int(game.player_preferences.keyboard_bindings[&"evade"])
	facts.water_heavy_wire = water_heavy
	if not await _finish_guard() or not await _remap_spell():
		_check(false, "setup helper did not complete")
		await _finish()
		return
	if not bool(facts.passed):
		await _finish()
		return
	var bodies: Dictionary = {}
	for champion_id: String in game.champion_catalog.ordered_champion_ids():
		var body := String(game.champion_catalog.champions_by_id[champion_id].body_type)
		if not bodies.has(body): bodies[body] = champion_id
	_check(bodies.size() == 3, "three real catalog body profiles selected")
	facts.champions = bodies.duplicate()
	for body: String in bodies:
		context = body + "/router-matrix"
		if not await _new_case(String(bodies[body])): break
		_sample_direction_matrix()
		for travel_index: int in range(8):
			if not bool(facts.passed): break
			# Each direction and each aim is physically exercised, independently.
			# Complete 8x8 router samples above; only orthogonal pairs get this route.
			var aim_index := posmod(travel_index + 2, 8)
			context = "%s/%s/aim-%s" % [body, DIRECTIONS.DIRECTION_ORDER[travel_index], DIRECTIONS.DIRECTION_ORDER[aim_index]]
			if not await _new_case(String(bodies[body])): break
			await _paid_route(travel_index, aim_index, travel_index == 0)
		if not bool(facts.passed): break
		context = body + "/low-flux"
		if not await _new_case(String(bodies[body])): break
		await _low_flux_route()
		if not bool(facts.passed): break
	_check(int(facts.router_samples) == 192, "exactly three sizes x eight travel x eight independent aim router samples")
	_check(int(facts.paid_transition_cases) == 24, "24 actual paid slide-jump and spell transition journeys")
	_check(int(facts.focus_cases) == 3 and int(facts.low_flux_cases) == 3, "each size covers focus/rearm and low-Flux branches")
	completed_run = true
	await _finish()


func _remap_spell() -> bool:
	context = "controls-remap"
	game.controls_editor.open_editor()
	game.controls_editor.selected_action_index = ControlBindingEditor.ACTIONS.find(&"spell_1")
	game.controls_editor.selected_device = ControlBindingEditor.DEVICE_KEYBOARD
	game.controls_editor.begin_capture()
	_key(spell_key, true)
	_check(not game.controls_editor.capturing and int(game.player_preferences.keyboard_bindings[&"spell_1"]) == spell_key, "actual Controls input captures J for the numbered spell action")
	_key(spell_key, false)
	var loaded := PlayerPreferences.new()
	_check(loaded.load_from_file() and int(loaded.keyboard_bindings[&"spell_1"]) == spell_key, "committed remap reloads from isolated preferences")
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	_check(not game.controls_editor.is_open, "Escape closes actual Controls")
	return await _finish_guard()


func _new_case(champion_id: String) -> bool:
	_release_all()
	await process_frame
	var world := SimWorld.new(120, 20260923, game.campus_layout.build_collision_world(), String(game.campus_layout.data.id), game.campus_layout.content_hash)
	var definition := HexWorldDefinition.from_campus(game.campus_layout)
	if not _check(definition != null and definition.bind_world(world), "new case binds unchanged complete campus chemistry"):
		return false
	game.world = world
	game.authoritative_session.world = world
	var actor: PlayerState = world.player()
	if not _check(game.champion_catalog.apply_to_player(actor, champion_id), "real champion profile applies"):
		return false
	actor.reset_for_spawn(anchor)
	var profile := _profile_receipt(actor)
	facts.body_profiles[champion_id] = profile
	_check(actor.stamina_maximum == int(profile.catalog_stamina_maximum) and actor.radius == int(profile.catalog_hurt_radius), "applied profile matches accepted catalog stamina and hurt radius")
	actor.spawn_protection_ticks = 0
	actor.flux_recovery_per_second = 0 # Fixture isolates payment/refusal from recovery.
	actor.stamina_recovery_per_second = 0
	if not _check(actor.place_proven_spell(0, water_heavy), "initial fixture equips current Water Heavy without seeding a movement state"):
		return false
	game.input_router = InputRouter.new(actor.entity_id)
	_check(game.input_router.configure_keyboard_bindings(game.player_preferences.keyboard_bindings), "case restores effective saved keyboard bindings")
	_check(game.input_router.configure_mouse_bindings(game.player_preferences.mouse_bindings), "case restores effective mouse bindings")
	_check(game.input_router.configure_controller_bindings(game.player_preferences.controller_bindings), "case restores effective controller bindings")
	game.input_router.configure_movement_reference(PlayerPreferences.MOVEMENT_WORLD_RELATIVE)
	game.previous_position = Vector2(anchor) / 1000.0
	game.current_position = game.previous_position
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	starts = 0
	releases = 0
	flux_refusals = 0
	release_direction = Vector2i.ZERO
	if not await _finish_guard(): return false
	return bool(facts.passed)


func _profile_receipt(actor: PlayerState) -> Dictionary:
	var champion_id: String = game.champion_catalog.champion_id_from_wire(actor.champion_wire_id)
	var champion: Dictionary = game.champion_catalog.champion(champion_id)
	var body := String(champion.get("body_type", "unknown"))
	var stats: Dictionary = champion.get("stats", {})
	return {
		"champion_id": champion_id, "champion_wire_id": actor.champion_wire_id,
		"body_type": body, "stamina_maximum": actor.stamina_maximum,
		"flight_capable": actor.flight_capable,
		"hurt_radius": actor.radius,
		"catalog_stamina_maximum": int(stats.get("stamina_maximum", -1)),
		"catalog_hurt_radius": game.champion_catalog.body_type_profiles.hurt_radius(body) if not champion.is_empty() else -1,
	}


func _sample_direction_matrix() -> void:
	var actor: PlayerState = game.world.player()
	var radius := actor.radius
	for travel_index: int in range(8):
		_set_travel(DIRECTIONS.FIXED_VECTORS[travel_index])
		for aim_index: int in range(8):
			_set_aim(DIRECTIONS.FIXED_VECTORS[aim_index])
			var command: SimCommand = game._sample_gameplay_command(game.world.tick, Vector2(anchor) / 1000.0, Vector2.ZERO, game._gameplay_input_blocked())
			_check(Vector2i(command.move_x, command.move_y) == DIRECTIONS.FIXED_VECTORS[travel_index], "router travel " + DIRECTIONS.DIRECTION_ORDER[travel_index])
			_check(DIRECTIONS.classify_index(command.aim_x, command.aim_y) == aim_index and command.aim_target_x == -1, "router independent controller aim " + DIRECTIONS.DIRECTION_ORDER[aim_index])
			_check((command.pressed_actions & ~SimCommand.PRESSED_CANCEL_MOVEMENT) == 0 and command.held_actions == 0, "orientation sampling creates no paid action; input reset may emit cancellation")
			facts.router_samples += 1
	_check(actor.radius == radius, "sampling aim/travel does not resize the body")
	_release_all()


func _paid_route(travel_index: int, aim_index: int, focus_case: bool) -> void:
	var actor: PlayerState = game.world.player()
	var direction: Vector2i = DIRECTIONS.FIXED_VECTORS[travel_index]
	var aim: Vector2i = DIRECTIONS.FIXED_VECTORS[aim_index]
	var cost := int(CombatTuning.cast_definition(water_heavy).flux_cost)
	var radius := actor.radius
	if not _enter_slide(direction, aim): return
	var stamina_before := actor.stamina
	var flux_before := actor.flux
	_key(_binding(&"jump"), true)
	if not _tick(): return
	_check(actor.jumpsquat_active and not actor.is_airborne(), "real held Jump prepares grounded slide-jump anticipation")
	_key(_binding(&"jump"), false)
	_key(spell_key, true)
	if not _tick(): return
	_check(actor.hop_ticks > 0 and actor.hop_mode == PlayerState.MovementMode.SLIDE_JUMP and actor.slide_ticks == 0, "actual Jump release converts paid slide into slide-jump")
	_check(actor.stamina < stamina_before, "slide-jump consumes real Stamina")
	_check(starts == 1 and actor.pending_cast_wire_id == water_heavy and actor.flux == flux_before - cost, "same sampled command starts exactly one positive-cost Water Heavy")
	_check(Vector2i(actor.pending_cast_aim_x, actor.pending_cast_aim_y) == aim and actor.pending_cast_target_x == -1, "startup captures independent directional aim without stale cursor endpoint")
	_check(actor.velocity_x * direction.x + actor.velocity_y * direction.y > 0, "cast does not erase slide-jump travel")
	_check(actor.radius == radius and game.world.hex_court.conservation_valid(), "cast preserves body and paid material invariants")
	_key(_binding(&"jump"), false)
	_key(_binding(&"slide"), false)
	if focus_case:
		await _focus_continuation(cost, aim_index)
	else:
		_key(spell_key, false)
		var wait_ticks := 0
		while actor.pending_cast_wire_id != 0 and wait_ticks < MAX_PHASE_TICKS and bool(facts.passed):
			if not _tick(): return
			wait_ticks += 1
		_check(wait_ticks < MAX_PHASE_TICKS and releases == 1, "paid moving startup produces exactly one projectile release")
		_check(release_direction != Vector2i.ZERO and DIRECTIONS.classify_index(release_direction.x, release_direction.y) == aim_index, "released projectile follows committed independent aim")
		_check(starts == 1 and actor.flux == flux_before - cost, "holding movement through release adds no spell payment")
	if bool(facts.passed): facts.paid_transition_cases += 1
	facts.cases.append({"name": context, "travel": DIRECTIONS.DIRECTION_ORDER[travel_index], "aim": DIRECTIONS.DIRECTION_ORDER[aim_index], "focus": focus_case, "starts": starts, "releases": releases, "tick": game.world.tick, "passed": bool(facts.passed)})
	_release_all()
	await process_frame


func _enter_slide(direction: Vector2i, aim: Vector2i) -> bool:
	_set_travel(direction)
	_set_aim(aim)
	var actor: PlayerState = game.world.player()
	var origin := Vector2i(actor.position_x, actor.position_y)
	for unused: int in range(24):
		if not _tick(): return false
	var traveled := Vector2i(actor.position_x, actor.position_y) - origin
	if not _check(traveled.x * direction.x + traveled.y * direction.y > 0, "physical directions create real ordinary travel"):
		return false
	var stamina_before := actor.stamina
	_key(_binding(&"slide"), true)
	if not _tick(): return false
	if not _check(actor.slide_ticks > 0 and actor.stamina < stamina_before, "physical Slide enters a paid slide from actual velocity"):
		return false
	var minimum: int = game.world.config.milliseconds_to_ticks(MovementTuning.SLIDE_JUMP_MINIMUM_COMMITMENT_MS)
	for unused: int in range(minimum):
		if not _tick(): return false
	return _check(actor.slide_ticks > 0 and actor.movement_commitment_ticks == 0, "source-derived slide commitment completes before the fresh jump/cast")


func _focus_continuation(cost: int, aim_index: int) -> void:
	var actor: PlayerState = game.world.player()
	var paid_flux := actor.flux
	var paid_matter := int(game.world.hex_court.metrics.matter_paid)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_set_aim(Vector2i.ZERO) # Neutral right stick must retain previous ownership.
	var wait_ticks := 0
	while actor.pending_cast_wire_id != 0 and wait_ticks < MAX_PHASE_TICKS and bool(facts.passed):
		if not _tick(): return
		_check(last_command.move_x == 0 and last_command.move_y == 0 and last_command.held_actions == 0 and (last_command.pressed_actions & ~SimCommand.PRESSED_CANCEL_MOVEMENT) == 0, "focus loss sends only neutral movement plus an optional explicit cancellation edge")
		wait_ticks += 1
	_check(wait_ticks > 0 and wait_ticks < MAX_PHASE_TICKS and releases == 1, "already-paid startup completes once while unfocused shared time advances")
	_check(starts == 1 and actor.flux == paid_flux and int(game.world.hex_court.metrics.matter_paid) == paid_matter, "focus loss neither refunds nor buys another cast")
	_check(release_direction != Vector2i.ZERO and DIRECTIONS.classify_index(release_direction.x, release_direction.y) == aim_index, "unfocused release retains captured independent aim")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	if not await _finish_guard(): return
	if not _tick(): return
	_check(last_command.move_x != 0 or last_command.move_y != 0, "ordinary direction can resume independently of paid input")
	_set_travel(Vector2i.ZERO) # Stay in the clear lane while waiting for cooldown.
	var cooldown_wait := 0
	while actor.spell_cooldown_for_wire(water_heavy) > 0 and cooldown_wait < MAX_PHASE_TICKS and bool(facts.passed):
		if not _tick(): return
		_check(last_command.held_actions == 0 and last_command.pressed_actions == 0, "held spell remains quarantined after focus guard")
		cooldown_wait += 1
	if not _tick(): return
	_check(cooldown_wait < MAX_PHASE_TICKS and starts == 1 and actor.flux == paid_flux, "held remapped key never resumes casting when cooldown clears")
	_key(spell_key, false)
	if not _tick(): return
	await process_frame
	_key(spell_key, true)
	if not _tick(): return
	_check(starts == 2 and actor.pending_cast_wire_id == water_heavy and actor.flux == paid_flux - cost, "release and fresh remapped press admit exactly one new paid cast")
	_check(DIRECTIONS.classify_index(actor.pending_cast_aim_x, actor.pending_cast_aim_y) == aim_index and actor.pending_cast_target_x == -1, "neutral controller keeps intentional aim after focus return")
	_key(spell_key, false)
	_set_travel(Vector2i.ZERO)
	wait_ticks = 0
	while actor.pending_cast_wire_id != 0 and wait_ticks < MAX_PHASE_TICKS and bool(facts.passed):
		if not _tick(): return
		wait_ticks += 1
	_check(wait_ticks < MAX_PHASE_TICKS and releases == 2 and game.world.hex_court.conservation_valid(), "fresh rearmed cast also releases once with conserved paid material")
	if bool(facts.passed): facts.focus_cases += 1


func _low_flux_route() -> void:
	var actor: PlayerState = game.world.player()
	var cost := int(CombatTuning.cast_definition(water_heavy).flux_cost)
	actor.flux = cost - 1 # Explicit low-resource initial fixture; no runtime tuning.
	if not _enter_slide(Vector2i(0, -1000), Vector2i(1000, 0)): return
	var paid_matter := int(game.world.hex_court.metrics.matter_paid)
	_key(_binding(&"jump"), true)
	if not _tick(): return
	_check(actor.jumpsquat_active and not actor.is_airborne(), "low-Flux jump still prepares anticipation")
	_key(_binding(&"jump"), false)
	_key(spell_key, true)
	if not _tick(): return
	_check(actor.hop_mode == PlayerState.MovementMode.SLIDE_JUMP and actor.hop_ticks > 0, "low Flux does not prevent independently affordable slide-jump")
	_check(flux_refusals == 1 and starts == 0 and actor.pending_cast_wire_id == 0 and actor.flux == cost - 1, "one-unit-below-cost spell refuses visibly with no Flux spend")
	_check(int(game.world.hex_court.metrics.matter_paid) == paid_matter and game.world.hex_court.pending.is_empty() and game.world.hex_court.casts.is_empty(), "unaffordable input cancels chemistry reservation without creating paid matter")
	_key(_binding(&"jump"), false)
	_key(_binding(&"slide"), false)
	_key(spell_key, false)
	if not _tick(): return
	# This is a setup boundary for rearm acceptance, not a claim about recovery.
	actor.flux = cost
	await process_frame
	_key(spell_key, true)
	if not _tick(): return
	_check(starts == 1 and actor.pending_cast_wire_id == water_heavy and actor.flux == 0, "fresh physical press at exact authored cost admits and spends exactly once")
	_key(spell_key, false)
	var wait_ticks := 0
	while actor.pending_cast_wire_id != 0 and wait_ticks < MAX_PHASE_TICKS and bool(facts.passed):
		if not _tick(): return
		wait_ticks += 1
	_check(wait_ticks < MAX_PHASE_TICKS and releases == 1 and game.world.hex_court.conservation_valid(), "exact-cost recovery fixture reaches one real release and valid ledger")
	if bool(facts.passed): facts.low_flux_cases += 1
	facts.cases.append({"name": context, "starts": starts, "releases": releases, "flux_refusals": flux_refusals, "passed": bool(facts.passed)})
	_release_all()
	await process_frame


func _tick() -> bool:
	if not bool(facts.passed): return false
	if not _check(not tick_in_progress, "previous world-step helper completed"):
		return false
	# Leave this marker set if a script error aborts the helper unexpectedly.
	# The next call and final receipt then fail closed even before log scanning.
	tick_in_progress = true
	var succeeded := _advance_tick()
	if not _check(succeeded, "world-step helper completed successfully"):
		return false
	tick_in_progress = false
	return true


func _advance_tick() -> bool:
	var world: SimWorld = game.world
	var actor: PlayerState = world.player()
	var position := Vector2(actor.position_x, actor.position_y) / 1000.0
	# Deliberately irrelevant stale cursor: controller ownership must suppress it.
	last_command = game._sample_gameplay_command(world.tick, position, Vector2.ZERO, game._gameplay_input_blocked())
	if not _check(last_command != null, "production sampler returns a command"): return false
	var commands: Array[SimCommand] = [last_command]
	var tick_before := world.tick
	if not _check(world.step(commands), "world step succeeds: " + world.last_error): return false
	if not _check(world.tick == tick_before + 1, "world step advances exactly one authority tick"): return false
	for event: Dictionary in world.combat_events:
		if int(event.get("wire_id", 0)) != water_heavy: continue
		if String(event.get("type", "")) == "cast_started": starts += 1
		elif String(event.get("type", "")) == "cast_refused" and String(event.get("reason", "")) == "flux": flux_refusals += 1
		elif String(event.get("type", "")) == "projectile_spawned":
			releases += 1
			for shot: ProjectileState in world.projectiles:
				if shot.entity_id == int(event.projectile_id): release_direction = Vector2i(shot.velocity_x, shot.velocity_y)
	return true


func _finish_guard() -> bool:
	while game.controls_input_guard_frames > 0:
		if not _tick(): return false
		_check(last_command.move_x == 0 and last_command.move_y == 0 and (last_command.pressed_actions & ~SimCommand.PRESSED_CANCEL_MOVEMENT) == 0 and last_command.held_actions == 0, "application guard sends only neutral commands and explicit movement cancellation")
		game.controls_input_guard_frames -= 1
		await process_frame
	return bool(facts.passed)


func _set_travel(direction: Vector2i) -> void:
	for pair: Array in [[&"move_left", direction.x < 0], [&"move_right", direction.x > 0], [&"move_up", direction.y < 0], [&"move_down", direction.y > 0]]:
		_key(_binding(pair[0]), bool(pair[1]))


func _set_aim(direction: Vector2i) -> void:
	for axis: int in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
		var event := InputEventJoypadMotion.new()
		event.device = 0
		event.axis = axis
		event.axis_value = float(direction.x if axis == JOY_AXIS_RIGHT_X else direction.y) / 1000.0
		_deliver(event)


func _binding(action: StringName) -> int:
	return int(game.player_preferences.keyboard_bindings[action])


func _key(code: int, down: bool) -> void:
	if code == 0: return
	if bool(held_keys.get(code, false)) == down: return
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	held_keys[code] = down
	_deliver(event)


func _deliver(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	game._unhandled_input(event)


func _release_all() -> void:
	if game == null: return
	for code: int in held_keys.keys(): _key(code, false)
	_set_aim(Vector2i.ZERO)
	for action: StringName in InputRouter.PAID_ACTIONS: Input.action_release(action)
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"spell_layer_ctrl", &"spell_layer_alt", &"aim_left", &"aim_right", &"aim_up", &"aim_down"]:
		Input.action_release(action)
	if game.input_router != null: game.input_router.discard_transient_movement_input()


func _find_clear_anchor(world: SimWorld) -> Vector2i:
	var preferred := Vector2i(1504_000, 1344_000)
	var candidates: Array[Vector2i] = [preferred]
	var cells: Array = world.hex_court.cells.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x if a.y == b.y else a.y < b.y)
	for cell: Vector2i in cells: candidates.append(world.hex_court.origin + HexGrid.center(cell))
	for point: Vector2i in candidates:
		var clear := world.collision.can_occupy(point, MovementTuning.PLAYER_RADIUS)
		for direction: Vector2i in DIRECTIONS.FIXED_VECTORS:
			for distance: int in range(32_000, 256_001, 32_000):
				if not world.collision.can_occupy(point + ElementChemistrySystem.scaled(direction, distance), MovementTuning.PLAYER_RADIUS):
					clear = false
					break
			if not clear: break
		if clear: return point
	return Vector2i.ZERO


func _check(condition: bool, message: String) -> bool:
	facts.checks.append({"passed": condition, "case": context, "message": message})
	if not condition:
		facts.passed = false
		print("MOVEMENT_CAST_FAILURE ", context, ": ", message)
	return condition


func _normalized(path: String) -> String:
	return path.replace("\\", "/").simplify_path().trim_suffix("/").to_lower()


func _finish() -> void:
	_check(completed_run, "complete required journey reached its final acceptance checks")
	_check(not tick_in_progress, "no world-step helper was abandoned by a script error")
	_release_all()
	if game != null:
		game.preference_overrides_are_transient = true
		game.preferences_persistence_allowed = false
		game.queue_free()
		await process_frame
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write movement/cast receipt: " + output)
		quit(2)
		return
	file.store_string(JSON.stringify(facts, "  ") + "\n")
	file.close()
	print("MOVEMENT_CAST_JOURNEY passed=%s router_samples=%d paid_routes=%d focus=%d low_flux=%d checks=%d" % [facts.passed, facts.router_samples, facts.paid_transition_cases, facts.focus_cases, facts.low_flux_cases, facts.checks.size()])
	quit(0 if bool(facts.passed) else 1)
