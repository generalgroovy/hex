extends SceneTree
## Native synthetic-world regression for atomic terrain texture/UV handoffs.
## This exercises the real backdrop, renderer and frame_post_draw lifecycle;
## its readbacks are test-only, never part of normal play or timing evidence.
const Backdrop = preload("res://src/presentation/pov_terrain_backdrop.gd")
const SAMPLE_SIZE := Vector2(320, 240)
var assertions := 0
var failures := 0
var output := ""


class GridRenderer:
	extends SanctumCampusRenderer
	var draws := 0
	func terrain_ready_for(_visible: Rect2) -> bool:
		return true
	static func cell_color(cell: Vector2i) -> Color:
		return Color8(48 + posmod(cell.x, 4) * 48, 48 + posmod(cell.y, 4) * 48, 64 + posmod(cell.x + cell.y, 4) * 40)
	func draw(canvas: CanvasItem, _layout: SanctumCampusLayout, _tick: int, _focus: Vector2 = Vector2.ZERO, _reduced: bool = false, _titles: bool = true, visible: Rect2 = Rect2(), _details: bool = true, _context: String = "") -> void:
		draws += 1
		var first := Vector2i((visible.position / 64.0).floor())
		var end := Vector2i((visible.end / 64.0).ceil())
		for y: int in range(first.y, end.y):
			for x: int in range(first.x, end.x):
				canvas.draw_rect(Rect2(Vector2(x, y) * 64.0, Vector2.ONE * 64.0), cell_color(Vector2i(x, y)))


class Sampler:
	extends Node2D
	var backdrop: SubViewport
	var view_rect := Rect2(Vector2(100, 100), SAMPLE_SIZE)
	func _draw() -> void:
		if not backdrop.ready_for(view_rect):
			draw_rect(Rect2(Vector2.ZERO, SAMPLE_SIZE), Color.MAGENTA)
			return
		var texture: Texture2D = backdrop.backdrop_texture()
		var scale_ratio: Vector2 = texture.get_size() / backdrop.world_rect.size
		var source := Rect2((view_rect.position - backdrop.world_rect.position) * scale_ratio, view_rect.size * scale_ratio)
		draw_texture_rect_region(texture, Rect2(Vector2.ZERO, SAMPLE_SIZE), source)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.is_absolute_path() or output.begins_with("res://") or output.begins_with("user://") or ".." in output or DirAccess.dir_exists_absolute(output):
		push_error("Native backend and fresh absolute --output directory required")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Cannot create backdrop regression output")
		quit(1)
		return
	var paths: Array[String] = ["res://src/presentation/pov_terrain_backdrop.gd", "res://tests/visual/test_pov_backdrop_transition.gd"]
	var hashes := {}
	for path: String in paths: hashes[path] = FileAccess.get_sha256(path)
	root.size = Vector2i(640, 400)
	root.content_scale_size = Vector2i.ZERO
	root.visible = true
	var renderer := GridRenderer.new()
	var backdrop := Backdrop.new()
	root.add_child(backdrop)
	backdrop.configure(renderer, SanctumCampusLayout.new())
	var sampler := Sampler.new()
	sampler.backdrop = backdrop
	sampler.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(sampler)
	_check(not backdrop.prepare_view(sampler.view_rect), "cold view cannot claim pixels before first render")
	await _frame()
	sampler.queue_redraw()
	await _frame()
	_check(backdrop.ready_for(sampler.view_rect), "real frame_post_draw publishes first capture")
	_check_pixels(root.get_texture().get_image(), sampler.view_rect, "initial")
	var warm_draws := renderer.draws
	for frame: int in 12:
		_check(backdrop.prepare_view(sampler.view_rect), "stationary view remains ready")
		sampler.queue_redraw()
		await _frame()
	_check(renderer.draws == warm_draws, "stationary frames do not rerender the static world")
	var transitions := 0
	var prior_texture: Texture2D = backdrop.backdrop_texture()
	for frame: int in 64:
		sampler.view_rect.position += Vector2(8, 2)
		_check(backdrop.prepare_view(sampler.view_rect), "ordinary movement never drops completed coverage at frame%d" % frame)
		sampler.queue_redraw()
		await _frame()
		_check(backdrop.ready_for(sampler.view_rect), "replacement still covers current view after frame%d" % frame)
		_check_pixels(root.get_texture().get_image(), sampler.view_rect, "movement%d" % frame)
		if prior_texture != backdrop.backdrop_texture():
			transitions += 1
			prior_texture = backdrop.backdrop_texture()
	_check(transitions >= 3, "moving control crosses several actual capture handoffs")
	_check(renderer.draws < 18, "64 moving frames retain terrain instead of redrawing it every frame")
	_check(backdrop.get_child_count() == 2, "native handoffs reuse exactly two targets")
	# Test a pre-render reversal: abandoning a distant pending view must never
	# replace the current ready image on the subsequent real completion signal.
	var retained_rect := backdrop.world_rect
	var retained_texture := backdrop.backdrop_texture()
	_check(not backdrop.prepare_view(Rect2(4400, 4000, 320, 240)), "teleport remains unready while its new pixels are pending")
	_check(backdrop.prepare_view(sampler.view_rect), "immediate return reuses current completed pixels")
	sampler.queue_redraw()
	await _frame()
	_check(backdrop.world_rect == retained_rect and backdrop.backdrop_texture() == retained_texture, "abandoned completion cannot move texture coordinates")
	_check_pixels(root.get_texture().get_image(), sampler.view_rect, "reversal")
	var image := root.get_texture().get_image()
	_check(image.save_png(output.path_join("last-frame.png")) == OK, "native sample image saved")
	for path: String in hashes: _check(hashes[path] == FileAccess.get_sha256(path), "source frozen through native transition regression")
	var receipt := FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE)
	if receipt == null:
		push_error("Cannot save backdrop regression receipt")
		quit(1)
		return
	receipt.store_string(JSON.stringify({"status": "passed" if failures == 0 else "failed", "assertions": assertions, "failures": failures, "transitions": transitions, "terrain_draws": renderer.draws, "source_hashes": hashes, "scope": "Real bounded SubViewport capture, atomic UV/texture publication, 64 moving frames, stationary reuse and canceled teleport; synthetic colored world, not full-game visual or performance qualification."}, "\t") + "\n")
	receipt.close()
	print("pov-backdrop-transition: ", assertions, " assertions, ", failures, " failures; ", transitions, " handoffs; ", renderer.draws, " terrain draws")
	quit(0 if failures == 0 else 1)


func _frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw


func _check_pixels(image: Image, visible: Rect2, label: String) -> void:
	_check(image != null and image.get_width() >= 320 and image.get_height() >= 240, label + " has native pixels")
	if image == null or image.get_width() < 320 or image.get_height() < 240: return
	for y: int in [3, 83, 163, 235]:
		for x: int in [3, 103, 203, 315]:
			var world_pixel := visible.position + Vector2(x, y)
			var expected := GridRenderer.cell_color(Vector2i((world_pixel / 64.0).floor()))
			var actual := image.get_pixel(x, y)
			_check(absf(actual.r - expected.r) <= 1.1 / 255.0 and absf(actual.g - expected.g) <= 1.1 / 255.0 and absf(actual.b - expected.b) <= 1.1 / 255.0, "%s grid sample%d,%d matches its world position without fallback or old-origin pixels" % [label, x, y])


func _check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		print("FAIL: ", label)
