extends SceneTree
## Native immediate-vs-retained exact RGBA test. No Bootstrap, network or saves.
## Each changed state is compared after its first frame_post_draw; no extra
## stabilization frame or forced redraw can hide stale retained commands.
const Retained = preload("res://src/presentation/retained_campus_canvas.gd")
const SIZE := Vector2i(512, 384)
const SOURCE_PATHS := ["res://src/presentation/retained_campus_canvas.gd", "res://src/presentation/sanctum_campus_renderer.gd", "res://src/presentation/wellspring_illustrated_kit.gd", "res://src/presentation/wellspring_terrain_stream.gd", "res://content/maps/sanctum_campus_g2_v1.json", "res://scripts/verify-retained-campus.gd"]

class Board extends Node2D:
	var renderer: SanctumCampusRenderer
	var layout: SanctumCampusLayout
	var retained: Node2D
	var parameters := {}
	var serial := 0
	func prepare(value: Dictionary) -> bool:
		parameters = value.duplicate()
		if retained != null and not retained.present(renderer, layout, value.tick, value.focus, value.reduced, value.titles, value.view, value.details, value.context, value.transform): return false
		queue_redraw()
		return true
	func _draw() -> void:
		if parameters.is_empty(): return
		serial += 1
		if retained == null:
			draw_set_transform_matrix(parameters.transform)
			renderer.draw(self, layout, parameters.tick, parameters.focus, parameters.reduced, parameters.titles, parameters.view, parameters.details, parameters.context)
			draw_set_transform(Vector2.ZERO)
		# A live opaque/translucent foreground witness must stay above every
		# campus layer. This detects a painter-order change behind/above parent.
		draw_rect(Rect2(228, 164, 56, 56), Color(0.9, 0.1, 0.6, 0.65))
		draw_line(Vector2(16, 16), Vector2(496, 368), Color(0.1, 0.9, 0.7, 0.4), 2)

var output := ""
var renderer := SanctumCampusRenderer.new()
var layout := SanctumCampusLayout.new()
var candidate: Board
var reference: Board
var candidate_view: SubViewport
var reference_view: SubViewport
var results: Array[Dictionary] = []
var source_before := {}
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	output = option("--output")
	var expected_data := option("--verify-user-data").replace("\\", "/").simplify_path().trim_suffix("/")
	var actual_data := OS.get_user_data_dir().replace("\\", "/").simplify_path().trim_suffix("/")
	if DisplayServer.get_name() == "headless" or expected_data.is_empty() or expected_data.to_lower() != actual_data.to_lower() or not OS.get_cmdline_user_args().has("--no-lan-discovery"):
		fail("Native display, exact isolated --verify-user-data and --no-lan-discovery are required."); return
	if not output.is_absolute_path() or DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output) or DirAccess.make_dir_recursive_absolute(output) != OK:
		fail("Choose a fresh absolute output directory."); return
	for path: String in SOURCE_PATHS: source_before[path] = FileAccess.get_sha256(path)
	var language := VisualLanguage.new()
	if not language.load_from_file() or not layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json") or not renderer.configure(language) or not renderer.configure_campus(layout):
		fail("Real campus/renderer admission failed: " + renderer.last_error); return
	candidate = Board.new()
	reference = Board.new()
	for board: Board in [candidate, reference]:
		board.renderer = renderer
		board.layout = layout
	candidate.retained = Retained.new()
	candidate.add_child(candidate.retained)
	candidate_view = viewport(candidate)
	reference_view = viewport(reference)
	var centers: Array[Vector2] = [Vector2(1536, 880), Vector2(4880, 720), Rect2(SanctumCampusLayout._parse_bounds(layout.arena_definition.bounds)).get_center()]
	for landmark: Dictionary in layout.data.landmarks:
		if bool(landmark.get("worldbone", false)):
			centers.append(Vector2(SanctumCampusLayout._parse_point(landmark.position)))
			if centers.size() >= 7: break
	for group: Dictionary in layout.practice_groups_by_id.values():
		centers.append(Vector2(SanctumCampusLayout._parse_point(group.label_anchor)))
		if centers.size() >= 9: break
	for index: int in centers.size():
		var zoom := 0.75 if index % 2 == 0 else 1.0
		var view := Rect2(centers[index] - Vector2(SIZE) / zoom / 2.0, Vector2(SIZE) / zoom)
		if not await ready(view): fail("Actual terrain did not become ready."); return
		var values := {"tick": 120, "focus": centers[index], "reduced": false, "titles": true, "details": true, "context": "", "view": view, "transform": Transform2D(0.0, Vector2.ONE * zoom, 0.0, -view.position * zoom)}
		if not await compare("view-%d/initial" % index, values): return
		var before: Dictionary = candidate.retained.stats()
		if not await compare("view-%d/retained-repeat" % index, values): return
		var after: Dictionary = candidate.retained.stats()
		for name: String in Retained.LAYER_NAMES:
			if int(before.layers[name].draws) != int(after.layers[name].draws): fail("Unchanged retained layer redrew: " + name); return
		values.tick = 127
		if not await compare("view-%d/animated" % index, values): return
		values.focus += Vector2(157.25, -64.75)
		if not await compare("view-%d/proximity" % index, values): return
		values.titles = false
		values.details = false
		values.context = SanctumCampusRenderer.SIGNATURE_CHALLENGE_CONTEXT
		if not await compare("view-%d/context" % index, values): return
		values.reduced = true
		if not await compare("view-%d/reduced" % index, values): return
		values.view.position += Vector2(1.25, -2.5)
		values.transform.origin = -Vector2(values.view.position) * zoom
		if not await ready(values.view): fail("Moved terrain view unavailable."); return
		if not await compare("view-%d/fractional-camera" % index, values): return
		candidate.retained.deactivate()
		if candidate.retained.visible: fail("Deactivated campus remains visible."); return
		if not await compare("view-%d/reactivated" % index, values): return
	var source_after := {}
	for path: String in SOURCE_PATHS:
		source_after[path] = FileAccess.get_sha256(path)
		if source_after[path] != source_before[path]: fail("Source changed during native pixel comparison: " + path); return
	var receipt := {"schema": "retained-campus-exact-rgba-v1", "passed": failures == 0, "comparisons": results.size(), "failures": failures,
		"scope": "Two native512x384 views, first submitted frame after each state change, same current source immediate and retained paths, exact RGBA equality. Proves tested painter order and invalidation cases, not performance, physical frame pacing or all possible camera/game states.",
		"engine": Engine.get_version_info(), "display_server": DisplayServer.get_name(), "source_before": source_before, "source_after": source_after, "layer_stats": candidate.retained.stats(), "results": results}
	var file := FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE)
	if file == null: fail("Could not write native comparison receipt."); return
	var text := JSON.stringify(receipt, "\t")
	file.store_string(text)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or FileAccess.get_file_as_string(output.path_join("receipt.json")) != text: fail("Native receipt read-back failed."); return
	renderer.finish_terrain_shutdown()
	candidate_view.queue_free()
	reference_view.queue_free()
	await process_frame
	print("RETAINED_CAMPUS_EQUIVALENCE_COMPLETE comparisons=%d failures=%d" % [results.size(), failures])
	quit(0 if failures == 0 else 1)

func viewport(board: Board) -> SubViewport:
	var view := SubViewport.new()
	view.size = SIZE
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	view.add_child(board)
	return view

func ready(view: Rect2) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 30000:
		renderer.prepare_terrain_view(view)
		if renderer.terrain_ready_for(SanctumCampusRenderer.terrain_preparation_rect(view)): return true
		await process_frame
	return false

func compare(label: String, values: Dictionary) -> bool:
	var before_candidate := candidate.serial
	var before_reference := reference.serial
	if not candidate.prepare(values) or not reference.prepare(values): fail("Presenter refused native fixture: " + label); return false
	await process_frame
	await RenderingServer.frame_post_draw
	if candidate.serial <= before_candidate or reference.serial <= before_reference: fail("Comparison did not observe the current submitted frame."); return false
	var actual := candidate_view.get_texture().get_image()
	var expected := reference_view.get_texture().get_image()
	if actual == null or expected == null or actual.get_size() != SIZE or expected.get_size() != SIZE: fail("Native viewport pixels unavailable."); return false
	actual.convert(Image.FORMAT_RGBA8)
	expected.convert(Image.FORMAT_RGBA8)
	var actual_bytes := actual.get_data()
	var expected_bytes := expected.get_data()
	var equal_pixels := actual_bytes == expected_bytes
	results.append({"label": label, "equal": equal_pixels, "candidate_rgba_sha256": hash_bytes(actual_bytes), "reference_rgba_sha256": hash_bytes(expected_bytes)})
	if not equal_pixels:
		failures += 1
		if failures <= 6:
			actual.save_png(output.path_join("mismatch-%02d-actual.png" % failures))
			expected.save_png(output.path_join("mismatch-%02d-reference.png" % failures))
	return true

static func hash_bytes(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()

static func option(name: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(name + "="): return argument.substr(name.length() + 1)
	return ""

func fail(message: String) -> void:
	printerr("RETAINED_CAMPUS_EQUIVALENCE_FAILED: " + message)
	renderer.finish_terrain_shutdown()
	quit(1)
