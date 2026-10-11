extends SceneTree
## Production native drawing with arranged attachment fields, not physical play.

const NORMALS := [Vector2i(1000, 0), Vector2i(-1000, 0), Vector2i(0, 1000), Vector2i(0, -1000),
	Vector2i(866, 500), Vector2i(866, -500), Vector2i(-866, 500), Vector2i(-866, -500)]
const ROWS := ["contact A", "neutral pass", "contact B", "blocked brace", "release jump", "forced control"]
const SOURCES := ["res://src/presentation/pixel_wallrun_pose.gd", "res://src/presentation/fullbody_cast_presenter.gd",
	"res://src/presentation/pixel_flipbook_presenter.gd", "res://src/presentation/cartoon_champion_presenter.gd",
	"res://src/presentation/actor_motion_history.gd", "res://src/presentation/pixel_aerial_pose.gd",
	"res://src/presentation/jump_presentation.gd", "res://src/presentation/pixel_movement_effects.gd",
	"res://src/sim/movement/movement_tuning.gd", "res://content/champions/foundation_champions_v1.json",
	"res://assets/sprites/pixel_cast_v1/manifest.json", "res://tests/visual/capture_wallrun_readability.gd"]
var output := ""

class Board:
	extends Node2D
	var presenter: CartoonChampionPresenter
	var catalog: ChampionCatalog
	var config := SimConfig.new(120)
	var fixtures: Array[Dictionary] = []
	var reduced := false
	var title := ""
	var size := Vector2i(1280, 1100)
	var failed := false

	func add(id: String, normal: Vector2i, kind: int, at: Vector2, reverse: bool = false) -> void:
		var state := PlayerState.new(fixtures.size() + 1)
		if not catalog.apply_to_player(state, id): failed = true; return
		state.spawn_protection_ticks = 0
		state.air_height = 36_000
		state.wall_x = normal.x
		state.wall_y = normal.y
		state.wall_skim_x = -normal.y * (-1 if reverse else 1)
		state.wall_skim_y = normal.x * (-1 if reverse else 1)
		state.wall_skim_surface_id = 7
		state.wall_skim_ticks = config.milliseconds_to_ticks(MovementTuning.WALL_SKIM_DURATION_MS)
		state.movement_mode = PlayerState.MovementMode.WALL_SKIM
		state.hop_mode = PlayerState.MovementMode.WALL_SKIM
		state.velocity_x = state.wall_skim_x * 300
		state.velocity_y = state.wall_skim_y * 300
		state.aim_x = -state.wall_skim_x
		state.aim_y = -state.wall_skim_y
		var phase := 0.0 if kind == 0 else (0.25 if kind == 1 else 0.5)
		if kind == 3:
			state.velocity_x = 0; state.velocity_y = 0
			state.wall_skim_ticks = 1
		elif kind == 4:
			state.wall_skim_ticks = 0
			state.hop_mode = PlayerState.MovementMode.WALL_KICK
			state.movement_mode = PlayerState.MovementMode.WALL_KICK
			state.air_vertical_velocity = 520_000
		elif kind == 5:
			state.control_state = PlayerState.ControlState.ROOTED
		var before := state.canonical_values()
		var tangent := Vector2i(state.wall_skim_x, state.wall_skim_y)
		var frame := presenter.movement_frame(id, state, 9000, config, reduced, phase, tangent)
		fixtures.append({"id": id, "state": state, "normal": Vector2(normal).normalized(), "at": at,
			"phase": phase, "travel": tangent, "kind": kind, "before": before,
			"frame": {"action": frame.get("action"), "wallrun_pose": frame.get("wallrun_pose", false),
				"lean": frame.get("wall_lean_radians", 0.0), "row": frame.get("wall_contact_row", -1),
				"source": str(frame.get("source_region", Rect2())), "aim": frame.get("aim_index"),
				"travel": frame.get("travel_index")}})

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(size)), Color("37483e"))
		draw_string(ThemeDB.fallback_font, Vector2(12, 23), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("e2d6af"))
		draw_string(ThemeDB.fallback_font, Vector2(12, 42), "Original whole-body pixels / actual contact fields / opposing aim / no physical trajectory or human acceptance", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("b9c4b3"))
		for fixture: Dictionary in fixtures:
			var floor_anchor: Vector2 = fixture.at
			var state: PlayerState = fixture.state
			var sample := JumpPresentation.sample(state, config, 0.0, reduced)
			var body_anchor := floor_anchor - Vector2(0, sample.body_lift_pixels)
			var normal: Vector2 = fixture.normal
			var tangent := Vector2(-normal.y, normal.x)
			# A deliberately schematic section of the actual contact plane, not
			# a new map asset or proof of occlusion against the production campus.
			var contact := floor_anchor - normal * 18.0
			draw_line(contact - tangent * 50, contact + tangent * 50, Color("26322e"), 10)
			draw_line(contact - tangent * 50 + Vector2(0, -36), contact + tangent * 50 + Vector2(0, -36), Color("9d9c76"), 3)
			draw_line(contact, contact + Vector2(0, -36), Color("6e775d"), 2)
			draw_set_transform(floor_anchor, 0.0, Vector2(1, 0.34))
			draw_circle(Vector2.ZERO, 18, Color(0.04, 0.07, 0.06, 0.35))
			draw_set_transform(Vector2.ZERO)
			if not presenter.draw(self, state, fixture.id, body_anchor, 9000, config, reduced, floor_anchor, fixture.phase, fixture.travel): failed = true
			if state.canonical_values() != fixture.before: failed = true
			draw_string(ThemeDB.fallback_font, floor_anchor + Vector2(-70, 31), String(fixture.id).replace("_", " "), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("e2d6af"))
			draw_string(ThemeDB.fallback_font, floor_anchor + Vector2(-70, 45), ROWS[int(fixture.kind)], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("c5cdbb"))


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.begins_with("res://.godot/wallrun-native-") or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("Native backend and a fresh --output=res://.godot/wallrun-native-NAME are required"); return
	if DirAccess.make_dir_recursive_absolute(output) != OK: _fail("Cannot create capture directory"); return
	var hashes := {}
	for path: String in SOURCES:
		hashes[path] = FileAccess.get_sha256(path)
		if String(hashes[path]).length() != 64: _fail("Missing capture source " + path); return
	var abilities := AbilityCatalog.new()
	var catalog := ChampionCatalog.new()
	var language := VisualLanguage.new()
	var presenter := CartoonChampionPresenter.new()
	if not abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json") or not catalog.load_from_file("res://content/champions/foundation_champions_v1.json", abilities) or not language.load_from_file() or not presenter.configure(language, CartoonChampionPresenter.DEFAULT_PATH, CartoonChampionPresenter.DEFAULT_OVERRIDE_PATH, false) or not presenter.enable_fullbody_art(true, true):
		_fail("Production character presenter admission failed: " + presenter.last_error); return
	var ids := catalog.ordered_champion_ids()
	for id: String in ids:
		for folder: String in ["pixel_cast_v1", "pixel_actions_v1"]:
			var path := "res://assets/sprites/" + folder + "/" + id + ".png"
			hashes[path] = FileAccess.get_sha256(path)
	root.visible = true
	root.mode = Window.MODE_MINIMIZED
	var viewport := SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := Board.new()
	board.presenter = presenter; board.catalog = catalog
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(board)
	var images: Array[Dictionary] = []
	for reduced: bool in [false, true]:
		board.reduced = reduced
		for kind: String in ["contact", "roster"]:
			board.fixtures.clear()
			if kind == "contact":
				board.size = Vector2i(1280, 1120)
				for row: int in ROWS.size():
					for column: int in NORMALS.size():
						var id: String = ["s_wayne", "oh_tipi", "red_baron"][(row + column) % 3]
						board.add(id, NORMALS[column], row, Vector2(80 + column * 160, 165 + row * 172), column % 2 == 0)
			else:
				board.size = Vector2i(1280, 930)
				for index: int in ids.size(): board.add(ids[index], NORMALS[index % 8], 0 if index % 2 == 0 else 2, Vector2(105 + (index % 6) * 210, 165 + (index / 6) * 174), index % 2 == 0)
			for zoom: float in [1.0, 0.75]:
				board.title = "Wall contact / " + kind + " / reduced=" + str(reduced) + " / zoom=" + str(zoom)
				viewport.size = Vector2i(Vector2(board.size) * zoom)
				viewport.canvas_transform = Transform2D.IDENTITY.scaled(Vector2.ONE * zoom)
				board.queue_redraw()
				await process_frame; await process_frame
				RenderingServer.force_draw(false)
				if board.failed: _fail("Production draw or authority immutability failed"); return
				var leaf := "%s-reduced-%d-zoom-%d.png" % [kind, int(reduced), roundi(zoom * 100)]
				var pixels := viewport.get_texture().get_image()
				if pixels == null or pixels.save_png(output.path_join(leaf)) != OK: _fail("Capture image failed"); return
				var records: Array[Dictionary] = []
				for fixture: Dictionary in board.fixtures: records.append({"id": fixture.id, "kind": ROWS[int(fixture.kind)], "frame": fixture.frame, "authority_hash": JSON.stringify(fixture.before).sha256_text()})
				images.append({"path": leaf, "sha256": FileAccess.get_sha256(output.path_join(leaf)), "records": records})
	for path: String in hashes:
		if FileAccess.get_sha256(path) != hashes[path]: _fail("Source changed during capture: " + path); return
	var file := FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE)
	if file == null: _fail("Cannot write capture receipt"); return
	file.store_string(JSON.stringify({"status": "captured_needs_visual_review", "source_hashes": hashes, "images": images, "authority_unchanged": true,
		"scope": "Production native draw; thirty identities, eight cardinal/hex normals, tangent-facing contact keys, blocked/release/forced-control states, both effect profiles,1x/0.75x",
		"limitations": "Schematic wall sections and arranged state fields; not campus occlusion, input routes, continuous animation, networking, performance or human acceptance."}, "\t") + "\n")
	file.close()
	print("PASS wallrun native capture: ", images.size(), " images; independent visual review required")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
