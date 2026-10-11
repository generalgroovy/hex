extends SceneTree

const IDS := ["s_wayne", "oh_tipi", "red_baron"]
var output := ""

class Board:
	extends Node2D
	var presenter: CartoonChampionPresenter
	var config := SimConfig.new(120)
	var actors: Array[PlayerState] = []
	var champions: Array[String] = []
	var labels: Array[String] = []
	var columns := 8
	var phase := 0.0
	var title := ""
	var failed := false
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 720), Color("23392d"))
		draw_string(ThemeDB.fallback_font, Vector2(20, 30), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("ead9b6"))
		for index: int in actors.size():
			var x := 80 + (index % columns) * (1120 / columns)
			var y := (175 if columns == 8 else 240) + (index / columns) * (150 if columns == 8 else 245)
			var ground := Vector2(x, y)
			var state := actors[index]
			var jump := JumpPresentation.sample(state, config)
			draw_set_transform(ground, 0, jump.shadow_scale)
			draw_circle(Vector2.ZERO, 16, Color(0.03, 0.07, 0.04, jump.shadow_opacity))
			draw_set_transform(Vector2.ZERO)
			var anchor := ground - Vector2(0, jump.body_lift_pixels)
			if not presenter.draw(self, state, champions[index], anchor, phase * 60, config, false, ground, phase):
				failed = true
			draw_string(ThemeDB.fallback_font, ground + Vector2(-50, 36), labels[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ead9b6"))
			if columns == 3:
				draw_string(ThemeDB.fallback_font, ground + Vector2(-50, 54), "height %.1f / squat %d" % [state.air_height / 1000.0, state.jumpsquat_ticks], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("b6c9bd"))


func _initialize() -> void:
	root.hide()
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if not output.begins_with("res://.godot/movement-checkpoint1-") or ".." in output or DirAccess.dir_exists_absolute(output):
		fail("Provide a new --output=res://.godot/movement-checkpoint1-NAME")
		return
	var language := VisualLanguage.new()
	var presenter := CartoonChampionPresenter.new()
	var catalog := ChampionCatalog.new()
	var abilities := AbilityCatalog.new()
	if not language.load_from_file() or not presenter.configure(language) or not abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json") or not catalog.load_from_file("res://content/champions/foundation_champions_v1.json", abilities):
		fail("Production presentation/catalog setup failed")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		fail("Cannot create contained output")
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := Board.new()
	board.presenter = presenter
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(board)
	for champion: String in IDS:
		for direction_index: int in 8:
			var state := PlayerState.new()
			catalog.apply_to_player(state, champion)
			var travel: Vector2i = EightDirectionResolver.FIXED_VECTORS[direction_index]
			state.movement_mode = PlayerState.MovementMode.SLIDE
			state.slide_ticks = 24
			state.slide_x = travel.x
			state.slide_y = travel.y
			state.velocity_x = travel.x * 300
			state.velocity_y = travel.y * 300
			state.aim_x = -travel.x
			state.aim_y = -travel.y
			board.actors.append(state)
			board.champions.append(champion)
			board.labels.append(champion + " / " + EightDirectionResolver.DIRECTION_ORDER[direction_index])
	board.title = "All 24 slides: travel direction, cursor points opposite. Controlled production poses."
	if not await save_frame(board, viewport, "slide-directions"):
		return
	board.actors.clear()
	board.champions.clear()
	board.labels.clear()
	board.columns = 3
	var worlds: Array[SimWorld] = []
	for flight: bool in [false, true]:
		for champion: String in IDS:
			var world := SimWorld.new(120)
			catalog.apply_to_player(world.player(), champion)
			world.player().flight_capable = flight # Explicit capability fixture, not roster assertion.
			worlds.append(world)
			board.actors.append(world.player())
			board.champions.append(champion)
			board.labels.append(champion + (" / flight fixture" if flight else " / double jump"))
	var receipt: Array[Dictionary] = []
	for tick: int in 144:
		for world: SimWorld in worlds:
			var held := SimCommand.HELD_JUMP if tick < 24 or (tick >= 42 and tick < 100 and world.player().flight_capable) else 0
			var pressed := SimCommand.PRESSED_JUMP if tick in [0, 42] else 0
			var commands: Array[SimCommand] = [SimCommand.new(world.tick, 1, 1000, 0, held, pressed, -1000, 0)]
			if not world.step(commands):
				fail("Actual movement command failed")
				return
		if tick % 4 != 0:
			continue
		board.phase = float(tick) / 120.0
		board.title = "Actual paid simulation, 120 Hz: squat -> release jump -> double jump / held flight -> release"
		var states: Array = []
		for actor: PlayerState in board.actors:
			states.append(actor.canonical_values())
		if not await save_frame(board, viewport, "motion-%03d" % tick):
			return
		receipt.append({"tick": tick, "states": states})
	var file := FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"frames": 37, "motion_frames": receipt, "frame_interval_ms": 1000.0 / 30.0, "authority": "Six actual 120Hz isolated simulations rendered with production presenter", "slides": "24 controlled poses, not physical-input acceptance", "flight": "Capability forced solely for size presentation comparison", "human_acceptance": "pending", "network": "not_started", "profiles": "not_used"}, "  "))
	file.close()
	print("PASS: 24-direction slide sheet and 36 actual motion sequence frames")
	quit(0)


func save_frame(board: Board, viewport: SubViewport, name: String) -> bool:
	var before: Array = []
	for state: PlayerState in board.actors:
		before.append(state.canonical_values())
	board.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	for index: int in board.actors.size():
		if board.actors[index].canonical_values() != before[index]:
			fail("Presentation mutated authority")
			return false
	if board.failed or viewport.get_texture().get_image().save_png(output.path_join(name + ".png")) != OK:
		fail("Frame failed")
		return false
	return true


func fail(message: String) -> void:
	push_error(message)
	quit(1)
