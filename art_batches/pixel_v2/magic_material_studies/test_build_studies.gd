extends SceneTree
const Builder = preload("build_studies.gd")
var assertions := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for name: String in Builder.NAMES:
		var source := fixture(Vector2i(256, 128), false)
		var before := source.get_data()
		var result: Dictionary = Builder.prepare_page(source, name)
		check(result.error == "", "valid alpha fixture " + name + ": " + String(result.error))
		check(source.get_data() == before, "immutable source " + name)
		if result.error != "":
			continue
		check(result.image.get_size() == Vector2i(128, 64), "fixed packed dimensions")
		check(result.metadata.frames.size() == 8, "exact eight frames")
		check(result.metadata.transform.per_frame_fit == false, "no frame-fitting")
		check(result.metadata.source.alpha.removed_pixels == 0, "native alpha no chromakey")
		for index: int in range(8):
			check(result.metadata.frames[index].pivot_px == [16, 26], "stable nominal pivot")
			check(result.metadata.frames[index].rect == Builder.rect_values(Builder.output_region(index)), "exact row-major rectangle")
			check(result.metadata.frames[index].duration_ticks > 0, "positive duration")
			var sheet_shift: Array = result.metadata.transform.translation_output_px
			var row_shift: Array = result.metadata.source_layout_calibration.row_translation_output_px[1 if index >= 4 else 0]
			check(result.metadata.frames[index].translation_output_px == [sheet_shift[0] + row_shift[0], sheet_shift[1] + row_shift[1]], "same approved row translation for all four cells")
		var twice: Dictionary = Builder.prepare_page(source, name)
		check(result.image.get_data() == twice.image.get_data(), "deterministic pixels")
		check(result.metadata == twice.metadata, "deterministic metadata")
	for size: Vector2i in [Vector2i(258, 129), Vector2i(1774, 887)]:
		var result: Dictionary = Builder.prepare_page(fixture(size, false), "water")
		check(result.error == "", "odd source dimensions accepted")
		var region_area := 0
		for index: int in range(8):
			region_area += Builder.source_region(size, index).get_area()
		check(region_area == size.x * size.y, "rounded cells cover page exactly")
	var matte := fixture(Vector2i(256, 128), true)
	var matte_before := matte.get_data()
	var cleaned: Dictionary = Builder.prepare_page(matte, "fire")
	check(cleaned.error == "", "known magenta-family fixture accepted: " + String(cleaned.error))
	check(matte.get_data() == matte_before, "matte source unchanged")
	if cleaned.error == "":
		check(cleaned.metadata.source.alpha.removed_pixels > 0, "edge matte removed")
		check(cleaned.metadata.source.alpha.removed_rgb_min == [236, 14, 233], "exact removed color range")
		check(cleaned.metadata.transform.translation_output_px == [0, -3], "one explicit Fire sheet correction")
		check(cleaned.metadata.alpha.transparent_pixels > 0, "real output transparency")
		var invalid: Image = cleaned.image.duplicate()
		invalid.set_pixel(0, 0, Color.WHITE)
		check(Builder.validate_packed(invalid).error != "", "packed edge clipping rejected")
	# Approved palettes exclude this family: enclosed holes are matte too.
	var enclosed := fixture(Vector2i(256, 128), true)
	enclosed.set_pixel(32, 36, Color(236.0/255.0, 14.0/255.0, 233.0/255.0))
	var island: Dictionary = Builder.prepare_page(enclosed, "water")
	check(island.error == "" and island.metadata.source.alpha.removed_enclosed_pixels == 1 and island.metadata.source.alpha.retained_matte_family_pixels == 0, "edge and enclosed matte removal counted separately")
	var drift := fixture(Vector2i(256, 128), false)
	var bottom_row := drift.get_region(Rect2i(0, 64, 256, 64))
	drift.fill_rect(Rect2i(0, 64, 256, 64), Color(0, 0, 0, 0))
	drift.blit_rect(bottom_row, Rect2i(0, 0, 256, 64), Vector2i(0, 52))
	var drift_result: Dictionary = Builder.prepare_page(drift, "water")
	check(drift_result.error == "", "row drift preserved as reviewable source")
	if drift_result.error == "":
		check(drift_result.metadata.raw_layout_qa.row_visible_bottom_delta_px == -6.0, "reports raw six-pixel row drift")
		check(drift_result.metadata.layout_qa.row_visible_bottom_delta_px == 0.0, "applies only explicit shared bottom-row calibration")
		check(drift_result.metadata.source_layout_calibration.row_translation_output_px == [[0,0],[0,6]], "calibration recorded honestly")
	for background: Color in [Color.WHITE, Color.GRAY, Color(0.8, 0.4, 0.8), Color(1.0, 0.0, 0.3)]:
		var invalid := fixture(Vector2i(256, 128), true)
		invalid.set_pixel(0, 0, background)
		check(Builder.prepare_page(invalid, "water").error != "", "unapproved matte rejected")
	var checker := fixture(Vector2i(256, 128), true)
	for y: int in range(8):
		for x: int in range(64):
			checker.set_pixel(x, y, Color.WHITE if (x+y)%2 == 0 else Color.GRAY)
	check(Builder.prepare_page(checker, "water").error != "", "baked checkerboard rejected")
	var clipped := fixture(Vector2i(256, 128), false)
	clipped.set_pixel(32, 0, Color.WHITE)
	check(Builder.prepare_page(clipped, "water").error != "", "source margin clipping rejected")
	var shift_clip := fixture(Vector2i(256, 128), false)
	shift_clip.fill_rect(Rect2i(28, 2, 8, 10), Color.WHITE)
	check(Builder.prepare_page(shift_clip, "fire").error != "", "root correction cannot silently clip top pixels")
	var empty := fixture(Vector2i(256, 128), false)
	empty.fill_rect(Rect2i(0, 0, 64, 64), Color.TRANSPARENT)
	check(Builder.prepare_page(empty, "water").error != "", "empty frame rejected")
	check(Builder.prepare_page(fixture(Vector2i(256, 128), false), "../fire").error != "", "unknown path/name rejected")
	check(Builder.prepare_page(Image.create(128, 128, false, Image.FORMAT_RGBA8), "water").error != "", "wrong aspect rejected")
	check(Builder.frame_durations("steam_formation").is_empty(), "interactions explicitly outside current scope")
	var manifest: Dictionary = Builder.make_manifest({"fire": {}}, ["fire"], ["water"])
	check(manifest.built_names == ["fire"] and manifest.missing_names.size() == 7, "partial pack reports only basic-element missing coverage")
	check(not manifest.all_studies_built and not manifest.full_magic_kit and not manifest.runtime_integrated, "no false completion or integration")
	check(manifest.out_of_scope_names.size() == 3 and manifest.scope_stop_reason == "stopped_before_first_level_interactions", "Steam is out of scope, not missing deliverable")
	check(Builder.parse_arguments(PackedStringArray(["--names=fire,water", "--validate-only"])).names == ["fire", "water"], "explicit subset")
	for args: PackedStringArray in [PackedStringArray(["--names"]), PackedStringArray(["--names=fire,fire"]), PackedStringArray(["--names=unknown"]), PackedStringArray(["--names=steam_active"]), PackedStringArray(["--names=fire,"]), PackedStringArray(["--output=elsewhere"])]:
		check(Builder.parse_arguments(args).error != "", "invalid CLI rejected")
	print("magic-studies-packer: %d assertions, %d failures; no output files written" % [assertions, failures])
	quit(0 if failures == 0 else 1)


func fixture(size: Vector2i, matte: bool) -> Image:
	var result := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	result.fill(Color(236.0/255.0, 14.0/255.0, 233.0/255.0) if matte else Color.TRANSPARENT)
	for index: int in range(8):
		var region: Rect2i = Builder.source_region(size, index)
		var shape := Rect2i(region.position + Vector2i(region.size.x * 0.35, region.size.y * 0.40), Vector2i(region.size.x * 0.30, region.size.y * 0.30))
		result.fill_rect(shape, Color(0.7, 0.3 + float(index) * 0.03, 0.1))
	return result


func check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		print("FAIL: " + label)
