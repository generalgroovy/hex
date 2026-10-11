extends SceneTree
## Native image regression for the actual Bootstrap draw-transform context.
const Harness = preload("res://tests/support/pose_transform_capture.gd")
const Fullbody = preload("res://src/presentation/fullbody_cast_presenter.gd")
var output := ""
var failures := 0
var assertions := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.begins_with("res://.godot/pose-camera-native-") or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("Native backend and fresh --output=res://.godot/pose-camera-native-NAME required"); return
	if DirAccess.make_dir_recursive_absolute(output) != OK: _fail("Cannot create regression directory"); return
	var paths := ["res://src/presentation/pixel_wallrun_pose.gd", "res://src/presentation/pixel_aerial_pose.gd", "res://src/presentation/fullbody_cast_presenter.gd",
		"res://src/presentation/pixel_flipbook_presenter.gd", "res://src/app/bootstrap.gd", "res://tests/support/pose_transform_capture.gd", "res://tests/visual/test_pose_camera_transform.gd"]
	var hashes := {}
	for path: String in paths: hashes[path] = FileAccess.get_sha256(path)
	var abilities := AbilityCatalog.new()
	var catalog := ChampionCatalog.new()
	if not abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json") or not catalog.load_from_file("res://content/champions/foundation_champions_v1.json", abilities): _fail("Catalog admission failed"); return
	var presenter := Fullbody.new()
	if not presenter.configure(catalog.ordered_champion_ids()) or not presenter.enable_pixel_pilot(catalog.ordered_champion_ids(), true): _fail("Native original body admission failed"); return
	root.visible = true; root.mode = Window.MODE_MINIMIZED
	var viewport := SubViewport.new()
	viewport.size = Vector2i(800, 600)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := Harness.new()
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(board)
	var records: Array[Dictionary] = []
	for kind: String in ["wallrun", "ball", "flight"]:
		var state := PlayerState.new(1)
		var id := "grace_reava" if kind == "flight" else "s_wayne"
		if not catalog.apply_to_player(state, id): _fail("Unknown native identity"); return
		state.spawn_protection_ticks = 0
		state.air_height = 40000
		state.air_vertical_velocity = 200000
		state.hop_mode = PlayerState.MovementMode.HOP
		if kind == "wallrun":
			state.wall_skim_ticks = 40; state.wall_skim_surface_id = 7
			state.wall_x = 1000; state.wall_y = 0
			state.wall_skim_x = 0; state.wall_skim_y = 1000
			state.velocity_y = 300000
			state.movement_mode = PlayerState.MovementMode.WALL_SKIM; state.hop_mode = PlayerState.MovementMode.WALL_SKIM
		elif kind == "flight":
			_check(state.flight_capable, "flight route uses a real eligible roster identity")
			state.air_floating = true; state.float_ticks = 24
			state.stamina = state.stamina_maximum
		var before := state.canonical_values()
		for reduced: bool in [false, true]:
			board.capture_frame = presenter.frame(id, state, 9000, SimConfig.new(120), 0.0, reduced)
			_check(bool(board.capture_frame.get("wallrun_pose", false)) if kind == "wallrun" else String(board.capture_frame.get("aerial_pose", "")) == ("open_flight" if kind == "flight" else "tucked_ball"), "actual production pose route selected: " + kind)
			board.use_bootstrap_transform = true
			viewport.canvas_transform = Transform2D.IDENTITY
			board.queue_redraw(); await process_frame; await process_frame
			RenderingServer.force_draw(false)
			var actual := viewport.get_texture().get_image()
			board.use_bootstrap_transform = false
			viewport.canvas_transform = Transform2D(0.0, Vector2.ONE * 0.75, 0.0, -board.capture_camera * 0.75)
			board.queue_redraw(); await process_frame; await process_frame
			RenderingServer.force_draw(false)
			var reference := viewport.get_texture().get_image()
			var mismatch := 0
			var visible := 0
			for y: int in actual.get_height():
				for x: int in actual.get_width():
					var a := actual.get_pixel(x, y)
					var b := reference.get_pixel(x, y)
					if a != b: mismatch += 1
					if b != reference.get_pixel(0, 0): visible += 1
			_check(visible > 180, "reference contains real native body and later sentinel")
			_check(mismatch <= maxi(4, visible / 200), "camera draw context matches external-canvas reference within0.5% edge raster tolerance")
			var sentinel := Vector2i(((board.capture_sentinel + Vector2(8, 8) - board.capture_camera) * 0.75).round())
			_check(actual.get_pixelv(sentinel).r > 0.95 and actual.get_pixelv(sentinel).b > 0.95 and actual.get_pixelv(sentinel).g < 0.05, "later sentinel retains actual Bootstrap origin and75%zoom")
			_check(actual.get_pixelv(Vector2i(board.capture_sentinel + Vector2(8, 8))).g > 0.05, "later sentinel never leaks into untransformed world coordinates")
			_check(state.canonical_values() == before, "camera regression leaves authority untouched")
			var leaf := "%s-reduced-%d.png" % [kind, int(reduced)]
			if actual.save_png(output.path_join(leaf)) != OK: _fail("Cannot save camera regression pixels"); return
			records.append({"path": leaf, "sha256": FileAccess.get_sha256(output.path_join(leaf)), "visible_pixels": visible, "different_pixels": mismatch})
	for path: String in hashes: _check(hashes[path] == FileAccess.get_sha256(path), "source remains frozen through native camera regression")
	var file := FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE)
	if file == null: _fail("Cannot save regression receipt"); return
	file.store_string(JSON.stringify({"status": "passed" if failures == 0 else "failed", "assertions": assertions, "failures": failures, "images": records, "source_hashes": hashes,
		"scope": "Actual Bootstrap camera helper with nonzero origin,75%zoom,wall/ball/flight and post-body sentinel,normal/reduced; isolated native pose,not full world battle."}, "\t") + "\n")
	file.close(); print("pose-camera-transform: ", assertions, " assertions, ", failures, " failures"); quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition: failures += 1; print("FAIL: ", label)


func _fail(message: String) -> void:
	push_error(message); quit(1)
