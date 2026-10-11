extends SceneTree
## Native offscreen render equivalence, not remote-play acceptance or a
## game/FPS/authority-capacity test. Both admitted pixel and wireframe paths run.
## Two independent production presenters draw the same eight synthetic actors;
## only the candidate applies the production pure body rejection policy.

const Policy = preload("res://src/presentation/character_viewport_policy.gd")
const SIZE := Vector2i(640, 400)
const IDS := ["s_wayne", "oh_tipi", "red_baron"]


class Board:
	extends Node2D
	var presenter: CartoonChampionPresenter
	var config := SimConfig.new(120)
	var actors: Array[PlayerState] = []
	var grounds: Array[Vector2] = []
	var ids: Array[String] = []
	var camera := Vector2.ZERO
	var zoom_percent := 100
	var tick := 120.0
	var reduced := false
	var culling := false
	var skipped := 0
	var body_queries := 0
	var draw_cpu_us := 0
	var failed := false

	func _draw() -> void:
		var started := Time.get_ticks_usec()
		skipped = 0
		body_queries = 0
		PixelMagicLibrary.default_library().begin_frame(reduced)
		draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE)), Color("23392d"))
		var zoom := PixelPresentation.zoom_scale(zoom_percent)
		var translation := PixelPresentation.snapped_canvas_origin(camera, zoom_percent)
		draw_set_transform(translation, 0, Vector2.ONE * zoom)
		for index: int in actors.size():
			var state := actors[index]
			var ground := grounds[index]
			var jump := JumpPresentation.sample(state, config, 0.5, reduced, state.air_height)
			var anchor := ground - Vector2(0, jump.body_lift_pixels)
			# The production gate intentionally leaves these independent cues on
			# their original path. A long name can enter while its body is outside.
			draw_set_transform(PixelPresentation.world_to_screen(ground, camera, zoom_percent), 0, jump.shadow_scale * zoom)
			draw_circle(Vector2.ZERO, 18, Color(0.03, 0.07, 0.04, jump.shadow_opacity))
			draw_set_transform(translation, 0, Vector2.ONE * zoom)
			var landing := LandingPresentation.sample(state, config, 0.0, reduced)
			LandingPresentation.draw(self, ground, landing, presenter.language)
			if culling and Policy.can_skip_body(presenter, ids[index], state, config, anchor, ground, camera, Rect2(Vector2.ZERO, Vector2(SIZE)), zoom_percent):
				skipped += 1
			else:
				body_queries += 1
				if not presenter.draw(self, state, ids[index], anchor, tick, config, reduced, ground, fposmod(tick / 48.0, 1.0)):
					failed = true
			var name := "REMOTE TRAVELLER %d LONG LABEL" % index
			var width := ThemeDB.fallback_font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			draw_string(ThemeDB.fallback_font, anchor + Vector2(-width * 0.5, -43), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("ead9b6"))
			draw_rect(Rect2(anchor + Vector2(-22, -37), Vector2(44, 4)), Color("d9634f"))
			draw_line(anchor, anchor + Vector2(state.aim_x, state.aim_y) * 0.032, Color("ead9b6"), 2)
		draw_cpu_us = Time.get_ticks_usec() - started


func _initialize() -> void:
	root.hide()
	_run.call_deferred()


func _run() -> void:
	var output := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	# Mounted release packs have a read-only res:// filesystem. An external
	# lead-owned capture may instead target a fresh, normalized .godot sibling.
	var absolute_capture: bool = output.is_absolute_path() and output == output.simplify_path() \
		and output.get_base_dir().get_file() == ".godot" and output.get_file().begins_with("character-viewport-")
	if (not output.begins_with("res://.godot/character-viewport-") and not absolute_capture) or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("Provide a fresh character-viewport-NAME directory under .godot")
		return
	var language := VisualLanguage.new()
	if not language.load_from_file():
		_fail("Production visual language unavailable")
		return
	var views: Array[SubViewport] = []
	var boards: Array[Board] = []
	for candidate: bool in [false, true]:
		var viewport := SubViewport.new()
		viewport.size = SIZE
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var board := Board.new()
		board.culling = candidate
		board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		viewport.add_child(board)
		views.append(viewport)
		boards.append(board)
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("Cannot create contained diagnostic directory")
		return
	var rows: Array[Dictionary] = []
	var total_skipped := 0
	var skipped_by_mode := {"fixed_pixel": 0, "legacy_wireframe": 0}
	var active_mode := ""
	for render_case: Dictionary in _render_cases():
		var renderer_mode := String(render_case.renderer_mode)
		if renderer_mode != active_mode:
			# Admit two fresh production presenters per mode; no pixel/rig cache
			# or remembered wall contact leaks into the independent legacy pass.
			for board: Board in boards:
				var presenter := CartoonChampionPresenter.new()
				if not presenter.configure(language):
					_fail("Production wireframe admission failed: " + presenter.last_error)
					return
				if renderer_mode == "fixed_pixel" and not presenter.enable_fullbody_art(false, true):
					_fail("Production pixel-cast admission failed: " + presenter.last_error)
					return
				board.presenter = presenter
				board.tick = 120.0
				board.failed = false
			active_mode = renderer_mode
		for board: Board in boards:
			_populate(board, String(render_case.scenario), int(render_case.zoom), bool(render_case.reduced))
			board.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var reference := views[0].get_texture().get_image()
		var candidate := views[1].get_texture().get_image()
		if reference == null or candidate == null or boards[0].failed or boards[1].failed:
			_fail("Native body fixture failed to render")
			return
		reference.convert(Image.FORMAT_RGBA8)
		candidate.convert(Image.FORMAT_RGBA8)
		var identical := reference.get_data() == candidate.get_data()
		var name := "%s-%s-z%d-%s" % [renderer_mode, render_case.scenario, render_case.zoom, "reduced" if render_case.reduced else "normal"]
		var comparison := Image.create(SIZE.x * 2, SIZE.y, false, Image.FORMAT_RGBA8)
		comparison.blit_rect(reference, Rect2i(Vector2i.ZERO, SIZE), Vector2i.ZERO)
		comparison.blit_rect(candidate, Rect2i(Vector2i.ZERO, SIZE), Vector2i(SIZE.x, 0))
		if comparison.save_png(output.path_join(name + ".png")) != OK:
			_fail("Cannot save side-by-side native fixture")
			return
		rows.append({"case": name, "renderer_mode": renderer_mode, "rgba_equal": identical, "actors": boards[0].actors.size(), "reference_body_queries": boards[0].body_queries, "candidate_body_queries": boards[1].body_queries, "skipped_bodies": boards[1].skipped, "reference_draw_cpu_us": boards[0].draw_cpu_us, "candidate_draw_cpu_us": boards[1].draw_cpu_us})
		total_skipped += boards[1].skipped
		skipped_by_mode[renderer_mode] += boards[1].skipped
		if not identical:
			if not _write_receipt(output, rows, false, total_skipped):
				_fail("Cannot save failed comparison receipt: " + name)
				return
			_fail("Culled/native reference pixels differ: " + name)
			return
	for renderer_mode: String in skipped_by_mode:
		if int(skipped_by_mode[renderer_mode]) <= 0:
			_fail("Fixture never exercised early rejection for " + renderer_mode)
			return
	if not _write_receipt(output, rows, true, total_skipped):
		_fail("Cannot save successful comparison receipt")
		return
	print("CHARACTER_VIEWPORT_NATIVE PASS: ", rows.size(), " exact RGBA comparisons; ", total_skipped, " rejected body queries; left=unculled right=candidate")
	quit(0)


func _render_cases() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for renderer_mode: String in ["fixed_pixel", "legacy_wireframe"]:
		for reduced: bool in [false, true]:
			for zoom: int in [50, 75, 100]:
				for scenario: String in ["edges", "high_jump", "landing", "protection", "wall_history", "wall_replay", "rig_fallback", "fast_pan_out", "spectator_return"]:
					result.append({"renderer_mode": renderer_mode, "reduced": reduced, "zoom": zoom, "scenario": scenario})
	return result


func _populate(board: Board, scenario: String, zoom: int, reduced: bool) -> void:
	board.actors.clear()
	board.grounds.clear()
	board.ids.clear()
	board.reduced = reduced
	board.zoom_percent = zoom
	board.camera = Vector2(125.3, -62.7)
	board.tick += 1.0
	var scale := PixelPresentation.zoom_scale(zoom)
	var translation := PixelPresentation.snapped_canvas_origin(board.camera, zoom)
	var anchors := [Vector2(2, 115), Vector2(638, 230), Vector2(235, 26), Vector2(420, 410), Vector2(-120, 315), Vector2(800, 360), Vector2(300, -200), Vector2(320, 620)]
	for index: int in 8:
		var state := PlayerState.new(index + 1)
		var heading: Vector2i = EightDirectionResolver.FIXED_VECTORS[index]
		state.aim_x = heading.x
		state.aim_y = heading.y
		state.velocity_x = -heading.x * 200
		state.velocity_y = -heading.y * 200
		state.movement_mode = PlayerState.MovementMode.WALK
		var ground: Vector2 = (anchors[index] - translation) / scale
		match scenario:
			"high_jump":
				state.air_height = 260000
				state.air_vertical_velocity = 1000
				state.hop_ticks = 10
				ground.y += 180.0
			"landing":
				state.landing_ticks = 12
				state.landing_intensity = 1000
			"protection": state.spawn_protection_ticks = 60
			"wall_history":
				state.wall_memory_ticks = board.config.milliseconds_to_ticks(MovementTuning.WALL_MEMORY_MS)
				state.wall_x = 1000
				state.wall_contact_id = 1
			"wall_replay":
				state.hop_mode = PlayerState.MovementMode.WALL_KICK
				state.movement_commitment_ticks = board.config.milliseconds_to_ticks(MovementTuning.HOP_COMMITMENT_MS) - 2
				state.air_height = 20000
				state.air_vertical_velocity = 1000
				state.hop_ticks = 10
				ground += Vector2(240, 0) # Remembered cue is not at the new body.
			"rig_fallback":
				state.movement_mode = PlayerState.MovementMode.SLIDE
				state.slide_ticks = 12
		board.actors.append(state)
		board.grounds.append(ground)
		board.ids.append(IDS[index % IDS.size()])
	if scenario == "fast_pan_out":
		board.camera += Vector2(10000, 10000)
	# spectator_return restores the exact current camera/anchors on the next
	# draw, with no visibility cache or frozen animation clock to invalidate.


func _write_receipt(output: String, rows: Array[Dictionary], passed: bool, skipped: int) -> bool:
	var receipt := {"status": "passed" if passed else "failed", "scope": "Native presenter/subviewport RGBA equivalence for eight synthetic render actors, separately admitted fixed-pixel and legacy-wireframe paths. CPU fields are single draw-call diagnostics, not remote-play acceptance, FPS, GPU completion, gameplay, networking or authority capacity.", "comparison": "left unculled, right viewport policy", "skipped_body_queries": skipped, "cases": rows}
	var path := output.path_join("receipt.json")
	var serialized := JSON.stringify(receipt, "\t") + "\n"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(serialized)
	file.flush()
	var saved := file.get_error() == OK
	file.close()
	# A successful open alone is not evidence that the full receipt survived
	# serialization/flush. Do not print PASS after any missing/partial write.
	return saved and FileAccess.get_file_as_string(path) == serialized


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
