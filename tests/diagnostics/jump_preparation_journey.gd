extends SceneTree
## Owner-run native fixture. Real movement commands; arranged denial inputs.

const Harness = preload("res://tests/support/chemistry_coach_harness.gd")
const VIEWPORT_SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900)]
const FRAME_KINDS: Array[String] = ["half-charge", "full-charge", "need-stamina", "cooldown", "slide-charge", "released", "cancelled", "hover-full"]
var output := ""
var game: Node2D
var stage: SubViewport
var hud: RecordedHud
var frames: Array[Dictionary] = []
var checks := 0


class RecordedHud extends CompactCombatHud:
	var preparation: Dictionary = {}
	var preparation_rectangle := Rect2()
	var resource_rectangle := Rect2()
	var panels: Array[Rect2] = []

	func _draw_resources(canvas: CanvasItem, rectangle: Rect2, state: PlayerState, champion_id: String, champion_name: String, layout: Dictionary, tick_rate: int) -> void:
		resource_rectangle = rectangle
		super._draw_resources(canvas, rectangle, state, champion_id, champion_name, layout, tick_rate)

	func _draw_jump_preparation(canvas: CanvasItem, panel: Rect2, model: Dictionary) -> void:
		preparation = model.duplicate(true)
		preparation_rectangle = panel
		super._draw_jump_preparation(canvas, panel, model)

	func _draw_panel(canvas: CanvasItem, rectangle: Rect2, opacity: float) -> void:
		panels.append(rectangle)
		super._draw_panel(canvas, rectangle, opacity)


func _initialize() -> void:
	root.hide()
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output) or not OS.get_user_data_dir().replace("\\", "/").contains("/hex-probe-"):
		_fail("Native backend, fresh absolute output and wrapper-isolated profile required")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("Cannot create fresh native evidence directory")
		return
	game = Harness.new()
	if not game.configure_fixture(true) or not game.cartoon_champion_presenter.enable_fullbody_art(false, true):
		_fail("Production gameplay/pixel fixture could not configure")
		game.free()
		return
	game.selected_champion_id = "oh_tipi"
	game.player_preferences.pov_mode = PlayerPreferences.POV_FULL
	hud = RecordedHud.new()
	if not hud.configure(game.visual_language):
		_fail("Production HUD could not configure")
		game.free()
		return
	hud.champion_art = game.cartoon_champion_presenter
	game.compact_hud = hud
	stage = SubViewport.new()
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(stage)
	stage.add_child(game)
	game.set_process(false)
	for size: Vector2i in VIEWPORT_SIZES:
		stage.size = size
		await process_frame
		for kind: String in FRAME_KINDS:
			if not _prepare(kind): return
			if not await _capture(kind, size): return
	if not _verify_frame_inventory(): return
	var receipt := FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE)
	if receipt == null:
		_fail("Cannot write jump preparation receipt")
		return
	receipt.store_string(JSON.stringify({"status": "passed", "checks": checks, "frames": frames,
		"runtime_identity": JSON.parse_string(FileAccess.get_file_as_string(RuntimeBuildIdentity.MANIFEST_PATH)),
		"scope": "Inherited production gameplay draw and HUD; real synthetic press/hold/release/slide/cancel commands. Stamina denial and cooldown are arranged fixtures. No-hover captures at two logical viewport sizes plus non-overlapping hover inspection; not physical-window or DPI acceptance. No boot, socket, profile or audio side effects.",
		"not_run": ["physical input", "physical-window sizing and DPI", "human usability", "network transport", "performance"]}, "\t") + "\n")
	receipt.close()
	print("PASS jump preparation native: ", checks, " checks / ", frames.size(), " frames")
	quit(0)


func _prepare(kind: String) -> bool:
	var actor: PlayerState = game.world.player()
	actor.reset_for_spawn(game.fixture_anchor)
	actor.spawn_protection_ticks = 0
	actor.stamina_recovery_per_second = 0
	game.actor_motion_history.clear()
	if kind == "slide-charge":
		actor.velocity_x = MovementTuning.BASE_SPEED
		if not _step(SimCommand.HELD_SLIDE, SimCommand.PRESSED_SLIDE, 1000): return false
		for unused: int in 8:
			if not _step(SimCommand.HELD_SLIDE, 0, 1000): return false
	if not _step(SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP): return false
	var hold_ticks := 18 if kind == "half-charge" else 36
	for unused: int in hold_ticks:
		if not _step(SimCommand.HELD_JUMP): return false
	if not _check(actor.jumpsquat_active, kind + " begins with real grounded preparation"): return false
	if kind == "need-stamina":
		actor.stamina = MovementSystem._movement_action_cost(actor, MovementTuning.HOP_COST) - 1
	elif kind == "cooldown":
		actor.hop_cooldown_ticks = game.world.config.milliseconds_to_ticks(250)
	elif kind == "released":
		var price := int(CompactCombatHud.jump_preparation_status(actor).cost)
		var reserve := actor.stamina
		if not _step(): return false
		if not _check(actor.is_airborne() and actor.stamina == reserve - price, "captured release really launches and pays its displayed price"): return false
	elif kind == "cancelled":
		var reserve := actor.stamina
		if not _step(SimCommand.HELD_JUMP, SimCommand.PRESSED_CANCEL_MOVEMENT): return false
		if not _check(not actor.jumpsquat_active and not actor.is_airborne() and actor.stamina == reserve, "movement cancellation clears preparation without launch or payment"): return false
	elif kind == "hover-full":
		actor.flux -= 10_000
		actor.flux_recovery_delay_ticks = 84
	var view := CompactCombatHud.jump_preparation_status(actor)
	if kind in ["released", "cancelled"]:
		return _check(view.is_empty(), kind + " has no stale preparation model")
	if not _check(not view.is_empty(), kind + " has a preparation model"): return false
	if kind == "half-charge": return _check(view.progress == 0.5, "half-charge is exact authority progress")
	if kind == "need-stamina": return _check(view.kind == "stamina", "one milli-unit short exposes denial")
	if kind == "cooldown": return _check(view.kind == "cooldown", "cooldown cannot advertise release")
	if kind == "slide-charge": return _check(view.slide_jump and actor.slide_ticks == 0 and view.cost == MovementSystem._movement_action_cost(actor, MovementTuning.SLIDE_JUMP_COST), "expired slide timer keeps the real prepared family and price")
	return _check(view.progress == 1.0 and view.kind == "ready", kind + " is fully charged and funded")


func _step(held: int = 0, pressed: int = 0, move_x: int = 0) -> bool:
	var actor: PlayerState = game.world.player()
	var commands: Array[SimCommand] = [SimCommand.new(game.world.tick, actor.entity_id, move_x, 0, held, pressed, 0, -1000)]
	return _check(game.world.step(commands), "real movement command succeeds")


func _capture(kind: String, size: Vector2i) -> bool:
	var actor: PlayerState = game.world.player()
	game.current_position = Vector2(actor.position_x, actor.position_y) / SimConfig.FIXED_SCALE
	game.previous_position = game.current_position
	game.previous_air_height = actor.air_height
	game.player_camera.clear()
	game._advance_player_camera(0.0, false)
	var scale_factor: float = game._ui_scale()
	var logical_size := Vector2(size) / scale_factor
	var pointer := Vector2(40, size.y - 40) if kind == "hover-full" else Vector2(size) * 0.5
	var motion := InputEventMouseMotion.new()
	motion.position = pointer
	motion.global_position = pointer
	stage.push_input(motion, true) # Viewport-local: never move the user's OS cursor.
	var expected := CompactCombatHud.jump_preparation_status(actor)
	var before: String = game.world.state_hash()
	hud.preparation = {}
	hud.preparation_rectangle = Rect2()
	hud.panels.clear()
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	if not _check(game.world.state_hash() == before, kind + " production drawing leaves canonical authority unchanged"): return false
	if not _check(hud.preparation == expected, kind + " actual renderer consumes the tested pure model"): return false
	var hovered := hud.resource_rectangle.has_point(stage.get_mouse_position() / scale_factor)
	if not _check(hovered == (kind == "hover-full"), kind + " uses the intended no-hover/hover pointer"): return false
	if not expected.is_empty():
		if not _check(hud.preparation_rectangle.has_area() and Rect2(Vector2.ZERO, logical_size).encloses(hud.preparation_rectangle), kind + " actual charge rectangle fits the logical canvas"): return false
		if not _check(not hud.preparation_rectangle.intersects(hud.resource_rectangle), kind + " charge cue preserves resource quantities"): return false
	if kind == "hover-full":
		var lines := CompactCombatHud.resource_detail_lines(actor, 120, true)
		var detail := CompactCombatHud.resource_detail_panel(Rect2(hud.preparation_rectangle.position, hud.resource_rectangle.size), logical_size, lines.size())
		if not _check(hud.panels.has(detail) and not detail.intersects(hud.preparation_rectangle) and not detail.intersects(hud.resource_rectangle), "actual hovered recovery panel remains visible without overlapping charge or bars"): return false
	var image := stage.get_texture().get_image()
	var name := "%s-%dx%d.png" % [kind, size.x, size.y]
	if not _check(image != null and image.get_size() == size and image.save_png(output.path_join(name)) == OK, "native frame saved: " + name): return false
	frames.append({"file": name, "kind": kind, "size": [size.x, size.y], "world_hash": before, "tick": game.world.tick,
		"pointer_over_resources": hovered, "preparation": expected, "stamina": actor.stamina,
		"jumpsquat_ticks": actor.jumpsquat_ticks, "slide_ticks": actor.slide_ticks,
		"authority_unchanged_by_draw": true})
	return true


func _verify_frame_inventory() -> bool:
	var expected := {}
	for size: Vector2i in VIEWPORT_SIZES:
		for kind: String in FRAME_KINDS:
			expected["%s-%dx%d.png" % [kind, size.x, size.y]] = {"kind": kind, "size": [size.x, size.y]}
	if not _check(expected.size() == 16 and frames.size() == 16, "exactly eight kinds at two logical viewport sizes are required before PASS"): return false
	var seen := {}
	for frame: Dictionary in frames:
		var name := String(frame.get("file", ""))
		if not _check(expected.has(name) and not seen.has(name), "native frame record is expected and unique: " + name): return false
		if not _check(frame.get("kind") == expected[name].kind and frame.get("size") == expected[name].size, "native kind-size record matches its expected output: " + name): return false
		if not _check(FileAccess.file_exists(output.path_join(name)), "expected native output exists: " + name): return false
		seen[name] = true
	return _check(seen.size() == expected.size(), "all sixteen unique kind-size outputs are present before PASS")


func _check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition: _fail(message)
	return condition


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
