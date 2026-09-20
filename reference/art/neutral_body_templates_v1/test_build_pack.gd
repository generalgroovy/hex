extends SceneTree

const Builder = preload("res://reference/art/neutral_body_templates_v1/build_pack.gd")
var assertions := 0
var failures := 0


func _initialize() -> void:
	var cardinal := _fixture(Vector2i(80, 80), "cardinal_core")
	var original_hash := Builder.bytes_sha256(cardinal.get_data())
	var prepared := Builder.inspect_source(cardinal, "cardinal_core")
	_check(String(prepared.error).is_empty(), "actual alpha source accepted")
	_check(Builder.bytes_sha256(cardinal.get_data()) == original_hash, "import does not mutate source image")
	_check(prepared.import_mode == "actual_alpha" and prepared.original_alpha.transparent_pixels > 0, "source alpha evidence retained")
	_check(prepared.poses.size() == 16, "all four by four core source cells accounted for")
	var masters: Dictionary = {}
	for source_id: String in Builder.PAGE_SPECS:
		var spec: Dictionary = Builder.PAGE_SPECS[source_id]
		var factor := 2 if source_id.begins_with("diagonal") else 1
		var source := _fixture(Vector2i(80 * factor, spec.states.size() * 20 * factor), source_id)
		masters[source_id] = Builder.inspect_source(source, source_id)
	var packed := Builder.assemble(masters)
	_check(String(packed.error).is_empty(), "six differently sized master canvases combine")
	if not String(packed.error).is_empty():
		_finish()
		return
	for body: String in Builder.HEIGHTS:
		var page: Image = packed.images[body]
		var body_data: Dictionary = packed.manifest.bodies[body]
		_check(page.get_size() == Vector2i(768, 960), "runtime compatibility page dimensions")
		_check(page.get_format() == Image.FORMAT_RGBA8, "runtime page is RGBA8")
		_check(body_data.frames.size() == 80, "ten poses have eight real direction cells")
		_check(page.get_pixel(0, 0).a == 0.0, "atlas exterior is truly transparent")
		var south := _frame(body_data.frames, "grounded", "south")
		var diagonal_frame := _frame(body_data.frames, "grounded", "south_east")
		_check(south.output_visible_bounds[3] == Builder.HEIGHTS[body], "south idle sets exact approved body height")
		_check(south.output_visible_bounds == diagonal_frame.output_visible_bounds, "source canvas normalization preserves shared body units")
		_check(south.output_visible_bounds[1] + south.output_visible_bounds[3] == 84, "shared feet pivot is preserved")
		var slide := _frame(body_data.frames, "slide", "south")
		_check(slide.output_visible_bounds[3] < south.output_visible_bounds[3], "crouch remains physically lower; never stretched to idle height")
		for frame: Dictionary in body_data.frames:
			var values: Array = frame.output_visible_bounds
			_check(Rect2i(1, 1, 94, 94).encloses(Rect2i(values[0], values[1], values[2], values[3])), "every output cell retains unclipped transparent gutter")
	for matte: Color in [Color.WHITE, Color.MAGENTA]:
		var matte_image := _fixture(Vector2i(80, 80), "cardinal_core", matte)
		var source_hash := Builder.bytes_sha256(matte_image.get_data())
		var matte_result := Builder.inspect_source(matte_image, "cardinal_core")
		_check(String(matte_result.error).is_empty(), "uniform permitted matte is accepted")
		_check(matte_result.import_mode == "solid_matte", "matte import mode is explicit")
		_check(matte_result.original_alpha.minimum == 255, "opaque original alpha is recorded truthfully")
		_check(Builder.bytes_sha256(matte_image.get_data()) == source_hash, "matte source remains immutable")
		var colored_center := Vector2i(9, 10)
		matte_image.set_pixelv(colored_center, matte)
		var island := Builder.inspect_source(matte_image, "cardinal_core")
		var island_pixels: Image = island.poses[0].image
		_check(island_pixels.get_pixel(3, 6).a == 1.0, "enclosed same-color subject highlight is not erased by matte flood")
	var checkerboard := _fixture(Vector2i(80, 80), "cardinal_core", Color.WHITE)
	checkerboard.set_pixel(1, 0, Color(0.85, 0.85, 0.85))
	_check(not String(Builder.inspect_source(checkerboard, "cardinal_core").error).is_empty(), "painted checkerboard rejected even when all four corners are white")
	var other_matte := _fixture(Vector2i(80, 80), "cardinal_core", Color.BLACK)
	_check(not String(Builder.inspect_source(other_matte, "cardinal_core").error).is_empty(), "unapproved background color rejected")
	var clipped := _fixture(Vector2i(80, 80), "cardinal_core")
	clipped.set_pixel(0, 8, Color.BLACK)
	_check(not String(Builder.inspect_source(clipped, "cardinal_core").error).is_empty(), "clipped source cell rejected")
	var empty := _fixture(Vector2i(80, 80), "cardinal_core")
	empty.fill_rect(Rect2i(0, 0, 20, 20), Color.TRANSPARENT)
	_check(not String(Builder.inspect_source(empty, "cardinal_core").error).is_empty(), "missing pose rejected")
	var odd := Builder.inspect_source(_fixture(Vector2i(83, 87), "cardinal_core"), "cardinal_core")
	_check(String(odd.error).is_empty() and odd.poses.size() == 16, "nondivisible source grid uses complete proportional boundaries")
	var last := Builder.proportional_region(Vector2i(83, 87), 3, 3)
	_check(last.end == Vector2i(83, 87), "final cell reaches exact source extent")
	var enormous: Dictionary = masters.duplicate(true)
	var enormous_pose := Image.create(160, 160, false, Image.FORMAT_RGBA8)
	enormous_pose.fill(Color.BLACK)
	enormous.diagonal_core.poses[0].image = enormous_pose
	_check(not String(Builder.assemble(enormous).error).is_empty(), "oversized fixed-scale pose fails rather than silently shrinking the template")
	var incomplete: Dictionary = masters.duplicate(true)
	incomplete.erase("diagonal_phase_b")
	_check(not String(Builder.assemble(incomplete).error).is_empty(), "missing phase-B master rejected")
	for state: String in Builder.ACTION_ALIASES.values():
		_check(state in Builder.STATES, "every semantic alias targets one of the actual ten pose rows")
	_finish()


func _fixture(size: Vector2i, source_id: String, background: Color = Color.TRANSPARENT) -> Image:
	# Synthetic test rectangles are import fixtures, never produced art assets.
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(background)
	var factor := size.x / 80
	var spec: Dictionary = Builder.PAGE_SPECS[source_id]
	for row: int in range(spec.states.size()):
		for column: int in range(4):
			var cell := Builder.proportional_region(size, column, row, spec.states.size())
			var height := (6 if spec.states[row] == "slide" else 12) * factor
			var width := 8 * factor
			var offset := Vector2i(6 * factor, 16 * factor - height)
			image.fill_rect(Rect2i(cell.position + offset, Vector2i(width, height)), Color(0.2, 0.3, 0.4, 1.0))
	return image


func _frame(frames: Array, state: String, direction: String) -> Dictionary:
	for frame: Dictionary in frames:
		if frame.state == state and frame.direction == direction:
			return frame
	return {}


func _check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		print("FAIL: " + label)


func _finish() -> void:
	print("neutral-body-pack: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)
