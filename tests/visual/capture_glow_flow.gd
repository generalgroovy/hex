extends SceneTree


# Native production drawing with real paid commands. The supervising shell owns
# isolated APPDATA and the engine lease. No physical input or human-feel claim.
const BootstrapScene = preload("res://scenes/bootstrap/bootstrap.tscn")
const SIZE := Vector2i(1280, 720)
const CROP_SIZE := Vector2i(320, 160)
const DELTA := 1.0 / 120.0
const CHAMPIONS := ["s_wayne", "oh_tipi", "red_baron"]
const MODES := ["walk", "sprint", "slide"]
const SOURCE_PATHS := [
	"res://src/app/bootstrap.gd",
	"res://src/presentation/character_movement_trail.gd",
	"res://src/presentation/cartoon_champion_presenter.gd",
	"res://src/presentation/fullbody_cast_presenter.gd",
	"res://src/presentation/pixel_flipbook_presenter.gd",
	"res://src/presentation/pixel_action_bank.gd",
	"res://content/runtime/runtime_build_identity_v1.json",
	"res://tests/visual/capture_glow_flow.gd",
]

var output := ""
var viewport: SubViewport
var game: Node2D
var board: NativeBoard
var frames: Array[Dictionary] = []
var cases: Array[Dictionary] = []
var source_hashes := {}
var lane := {}
var failed := false


func _initialize() -> void:
	root.unfocusable = true
	root.mode = Window.MODE_MINIMIZED
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.begins_with("res://.godot/glow-flow-native-") \
			or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("Provide native rendering and a fresh --output=res://.godot/glow-flow-native-NAME directory")
		return
	if "--pixel-cast" not in OS.get_cmdline_user_args():
		_fail("This bounded production capture requires --pixel-cast")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("Could not create the fresh native evidence directory")
		return
	for path: String in SOURCE_PATHS:
		source_hashes[path] = FileAccess.get_sha256(path)
	viewport = SubViewport.new()
	root.mode = Window.MODE_MINIMIZED
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	game = BootstrapScene.instantiate()
	game.set_process(false)
	viewport.add_child(game)
	game.set_process(false)
	game.set_process_unhandled_input(false)
	game.preference_overrides_are_transient = true
	game.preferences_persistence_allowed = false
	game.application_input_active = true # Hidden capture window has no physical focus.
	game.controls_input_guard_frames = 0
	game.player_preferences.reduced_motion = false
	if game.element_audio != null:
		game.element_audio.silence()
		game.element_audio.set_process(false)
		game.element_audio.volume_percent = 0
	await process_frame
	if game.world == null or game.world.hex_court == null or game.cartoon_champion_presenter.fullbody_art == null \
			or game.cartoon_champion_presenter.fullbody_art.pixel_pilot == null:
		_fail("Production pixel-cast Wellspring failed to boot")
		return
	board = NativeBoard.new()
	board.hide()
	viewport.add_child(board)
	for row: int in range(CHAMPIONS.size()):
		for column: int in range(MODES.size()):
			if not await _movement_case(row, column):
				return
	game.hide()
	board.show()
	for reduced: bool in [false, true]:
		board.reduced = reduced
		board.queue_redraw()
		await process_frame
		await process_frame
		RenderingServer.force_draw(false)
		if not _store(viewport.get_texture().get_image(), "movement-board-" + ("reduced" if reduced else "normal"), "unscaled-native-crop-board"):
			return
	for path: String in SOURCE_PATHS:
		if String(source_hashes[path]).length() != 64 or FileAccess.get_sha256(path) != source_hashes[path]:
			_fail("Capture source changed while the engine was running: " + path)
			return
	if cases.size() != 9 or frames.size() != 6:
		_fail("Incomplete three-size movement matrix or bounded six-image evidence set")
		return
	var receipt := FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE)
	if receipt == null:
		_fail("Could not write native capture receipt")
		return
	receipt.store_string(JSON.stringify({
		"status": "passed", "cases": cases, "frames": frames, "sources": source_hashes,
		"runtime_identity": JSON.parse_string(FileAccess.get_file_as_string(RuntimeBuildIdentity.MANIFEST_PATH)),
		"display": {"server": DisplayServer.get_name(), "minimized_root": root.mode == Window.MODE_MINIMIZED, "unfocusable": root.unfocusable, "viewport": [1280, 720], "update_always": true},
		"method": "Production Bootstrap scene and _draw; scripted real SimWorld.step commands at120Hz; half-tick interpolated displayed positions; normal/reduced screenshots share the same authority hash. Scenario setup selects real champion identities and a collision-checked clear lane. No velocity, movement-mode or trail injection. Crops are320x160 native pixels without resizing; two boards plus four full frames.",
		"scope": "Three real body sizes x walk/sprint/paid slide. Actual stamina payment, live bounded trail history, reduced suppression, same-frame Spell Loom cleanup and paid-to-idle decay. Spell projectile/glow coverage is NOT_RUN by this movement-first harness.",
		"limitations": "Scripted native keyframes only: not physical input, continuous-video or human feel acceptance; not network, dense performance, all-direction or all-character acceptance. Hidden-window focus is intentionally admitted for scripted drawing; genuine focus-loss handling is not exercised here.",
	}, "\t") + "\n")
	receipt.close()
	print("PASS glow-flow native:9 real movement cases; normal/reduced same-state renders;6 retained images; menu/idle cleanup")
	quit(0)


func _movement_case(row: int, column: int) -> bool:
	game.world = game._new_wellspring_world(120)
	if game.world == null:
		_fail("Could not rebuild the production Wellspring movement case")
		return false
	game.authoritative_session.world = game.world
	game.combat_cues.clear()
	game.station_notice_seconds = 0.0
	game.requested_capture_reduced_effects = false
	game.application_input_active = true
	game.controls_input_guard_frames = 0
	game.spell_loom_editor.close_editor()
	var actor: PlayerState = game.world.player()
	var champion: String = CHAMPIONS[row]
	var mode: String = MODES[column]
	if not game.champion_catalog.apply_to_player(actor, champion):
		_fail("Could not admit requested size identity: " + champion)
		return false
	game.selected_champion_id = champion
	if lane.is_empty():
		lane = _clear_lane()
	if lane.is_empty():
		_fail("No collision-checked straight capture lane remains in the production campus")
		return false
	actor.reset_for_spawn(lane.spawn)
	actor.spawn_protection_ticks = 0
	var direction: Vector2i = lane.direction
	actor.aim_x = direction.x
	actor.aim_y = direction.y
	game.current_position = game._player_position()
	game.previous_position = game.current_position
	game.accumulator_seconds = 0.0
	game._reset_motion_history()
	game._prepare_active_character_pages()
	game.player_camera.clear()
	for unused: int in range(120):
		game.player_camera.advance(game.current_position, Vector2.ZERO, Vector2(direction), DELTA, Vector2(SIZE), Rect2(Vector2.ZERO, Vector2(game.campus_layout.canvas_size)))
	var initial_stamina := actor.stamina
	var initial_flux := actor.flux
	var slide_payment := 0
	for step: int in range(64):
		var held := SimCommand.HELD_SPRINT if mode != "walk" else 0
		var pressed := 0
		if mode == "slide" and step >= 36:
			held |= SimCommand.HELD_SLIDE
			if step == 36:
				pressed = SimCommand.PRESSED_SLIDE
		var before_step := actor.stamina
		if not await _advance(SimCommand.new(game.world.tick, actor.entity_id, direction.x, direction.y, held, pressed, direction.x, direction.y)):
			return false
		if pressed != 0:
			slide_payment = before_step - actor.stamina
	var expected_mode: int = PlayerState.MovementMode.WALK if mode == "walk" else (PlayerState.MovementMode.SPRINT if mode == "sprint" else PlayerState.MovementMode.SLIDE)
	var live_segments: int = game.character_movement_trail.segment_count(actor.entity_id)
	if actor.movement_mode != expected_mode or live_segments <= 0 or actor.flux != initial_flux \
			or (mode != "walk" and actor.stamina >= initial_stamina) \
			or (mode == "slide" and slide_payment < MovementTuning.SLIDE_COST):
		_fail("Real %s/%s action, payment or live trail positive control failed (mode=%d segments=%d payment=%d)" % [champion, mode, actor.movement_mode, live_segments, slide_payment])
		return false
	var authority_hash: String = game.world.state_hash()
	var entry := {"champion": champion, "size_index": row, "movement": mode, "tick": game.world.tick,
		"world_hash": authority_hash, "stamina_before": initial_stamina, "stamina_after": actor.stamina,
		"slide_entry_payment": slide_payment, "normal_segments": live_segments, "phases": []}
	for reduced: bool in [false, true]:
		game.requested_capture_reduced_effects = reduced
		if not await _redraw():
			return false
		var count: int = game.character_movement_trail.segment_count()
		if (reduced and count != 0) or game.world.state_hash() != authority_hash:
			_fail("Reduced draw retained trail history or a draw mutated authority")
			return false
		var rendered := viewport.get_texture().get_image()
		if not _add_crop(rendered, row, column, reduced):
			return false
		entry.phases.append({"reduced": reduced, "segments": count, "world_hash": game.world.state_hash()})
		if row == 1 and mode == "slide":
			if not _store(rendered, "middle-slide-" + ("reduced" if reduced else "normal"), "production-full-frame"):
				return false
	if row == 1 and mode == "slide":
		if not await _cleanup_case(actor, direction, entry):
			return false
	cases.append(entry)
	print("PAID movement ", champion, " ", mode, " segments=", live_segments, " stamina=", initial_stamina - actor.stamina)
	return true


func _cleanup_case(actor: PlayerState, direction: Vector2i, entry: Dictionary) -> bool:
	game.requested_capture_reduced_effects = false
	for unused: int in range(16):
		if not await _advance(SimCommand.new(game.world.tick, actor.entity_id, direction.x, direction.y, SimCommand.HELD_SLIDE, 0, direction.x, direction.y)):
			return false
	var before_menu: int = game.character_movement_trail.segment_count()
	if before_menu <= 0:
		_fail("Menu cleanup needs a live trail positive control")
		return false
	game.spell_loom_editor.open_editor(actor, game.ability_catalog)
	if not await _redraw() or game.character_movement_trail.segment_count() != 0:
		_fail("Same-frame menu opening did not remove trail history")
		return false
	if not _store(viewport.get_texture().get_image(), "middle-menu-cleanup", "production-full-frame-menu"):
		return false
	game.spell_loom_editor.close_editor()
	for unused: int in range(120):
		if not await _advance(SimCommand.new(game.world.tick, actor.entity_id, 0, 0, 0, 0, direction.x, direction.y)):
			return false
	if game.character_movement_trail.segment_count() != 0 or Vector2(actor.velocity_x, actor.velocity_y).length_squared() > 1.0:
		_fail("Released paid movement did not settle without a persistent wake")
		return false
	if not _store(viewport.get_texture().get_image(), "middle-idle-cleanup", "production-full-frame-idle"):
		return false
	entry["cleanup"] = {"segments_before_menu": before_menu, "menu_segments": 0, "idle_segments": 0, "idle_tick": game.world.tick}
	return true


func _advance(command: SimCommand) -> bool:
	var previous: Vector2 = game._player_position()
	var actor: PlayerState = game.world.player()
	game.previous_air_height = actor.air_height
	var commands: Array[SimCommand] = [command]
	if not game.world.step(commands):
		_fail("Production paid simulation command failed")
		return false
	# Do not copy the older cast-capture _sync reset on every tick: resetting
	# motion history here would erase the effect under review before each draw.
	game.current_position = game._player_position()
	game.previous_position = previous
	game.accumulator_seconds = DELTA * 0.5
	game.actor_motion_history.capture(game.world.players)
	game._update_combat_cues(DELTA)
	game._ingest_combat_cues(game.world.combat_events)
	game._update_character_gaits(DELTA)
	game._advance_player_camera(DELTA, false)
	game.character_movement_trail.begin_frame(DELTA, not game._gameplay_input_blocked() and not game._reduced_effects_enabled())
	return await _redraw()


func _redraw() -> bool:
	var before: String = game.world.state_hash()
	game.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	if game.world.state_hash() != before:
		_fail("Production draw changed authority")
		return false
	return true


func _clear_lane() -> Dictionary:
	for y: int in [880, 1152, 1440, 1664, 640]:
		for x: int in [1536, 1024, 2048, 512]:
			var spawn := Vector2i(x, y) * 1000
			for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
				var clear := true
				for distance: int in range(0, 641, 16):
					if not game.world.collision.can_occupy(spawn + direction * distance * 1000, MovementTuning.PLAYER_RADIUS):
						clear = false
						break
				if clear:
					return {"spawn": spawn, "direction": direction * 1000}
	return {}


func _add_crop(rendered: Image, row: int, column: int, reduced: bool) -> bool:
	if rendered == null or rendered.get_size() != SIZE:
		_fail("Native production viewport readback failed")
		return false
	var point: Vector2 = game.previous_position.lerp(game.current_position, 0.5)
	var origin: Vector2 = game._camera_origin(game._camera_focus_position(point))
	var center := PixelPresentation.world_to_screen(point, origin, PlayerCameraRig.ZOOM_PERCENT)
	var crop := Rect2i(Vector2i(center.round()) - Vector2i(160, 110), CROP_SIZE)
	if not Rect2i(Vector2i.ZERO, SIZE).encloses(crop):
		_fail("Native actor crop fell outside the production viewport")
		return false
	board.samples.append({"row": row, "column": column, "reduced": reduced,
		"texture": ImageTexture.create_from_image(rendered.get_region(crop))})
	return true


func _store(rendered: Image, label: String, kind: String) -> bool:
	var path := output.path_join(label + "-1280x720.png")
	if rendered == null or rendered.get_size() != SIZE or rendered.save_png(path) != OK:
		_fail("Could not save native evidence frame: " + label)
		return false
	frames.append({"file": path.get_file(), "sha256": FileAccess.get_sha256(path), "kind": kind, "width": SIZE.x, "height": SIZE.y})
	return true


func _fail(message: String) -> void:
	failed = true
	push_error(message)
	quit(1)


class NativeBoard:
	extends Node2D
	var samples: Array[Dictionary] = []
	var reduced := false
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 720), Color("18231f"))
		_text(Vector2(24, 30), "H.E.X. / PAID MOVEMENT / " + ("REDUCED" if reduced else "NORMAL"), 20)
		_text(Vector2(24, 53), "Production draw; 320x160 native crops without resizing. Real paid input commands, not injected velocity or poses.", 13)
		for column: int in range(3):
			_text(Vector2(76 + column * 410, 81), ["WALK", "SPRINT", "SLIDE"][column], 15)
		for sample: Dictionary in samples:
			if bool(sample.reduced) != reduced:
				continue
			var at := Vector2(76 + int(sample.column) * 410, 96 + int(sample.row) * 192)
			draw_texture(sample.texture, at)
			_text(at + Vector2(0, 179), ["SMALL / S. Wayne", "MIDDLE / Oh Tipi", "LARGE / Red Baron"][int(sample.row)], 12)
		_text(Vector2(24, 702), "Short neutral movement wakes only. Native keyframes do not establish physical-input, human-feel, network or performance acceptance.", 12)
	func _text(at: Vector2, value: String, size: int) -> void:
		draw_string(ThemeDB.fallback_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("e4ddc8"))
