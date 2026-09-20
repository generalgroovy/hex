extends SceneTree

const Model = preload("res://tests/visual/character_sheet_qa_model.gd")
const Viewer = preload("res://tests/visual/character_sheet_qa.gd")
var assertions := 0
var failures := 0


func _initialize() -> void:
	for scale_value: int in [1, 2]:
		var seen := {}
		for page: int in range(Model.page_count(scale_value)):
			for cell: Dictionary in Model.page_cells(scale_value, page):
				var key := "%d/%d" % [cell.row, cell.direction]
				check(not seen.has(key), "no cell duplicated across pages")
				seen[key] = true
				check(cell.row >= 0 and cell.row < 10 and cell.direction >= 0 and cell.direction < 8, "page references exact semantic cell")
		check(seen.size() == 80, "every direction/action cell is visible at requested scale")
	check(Model.page_cells(1, -1).is_empty(), "negative page rejected")
	check(Model.page_cells(2, 10).is_empty(), "out-of-range page rejected")
	check(Model.action_row("walk", 0) == "walk" and Model.action_row("walk", 1) == "walk_b", "real walk A/B rows")
	check(Model.action_row("sprint", 2) == "sprint", "sprint contacts loop")
	check(Model.action_row("float", 7) == "jump", "reused Float pose is not fabricated")
	check(Model.action_row("Action cycle", 9) == "sprint_b", "action cycle covers tenth source row")
	var image := Image.create(768, 960, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for row: int in range(10):
		for column: int in range(8):
			image.fill_rect(Rect2i(column * 96 + 30, row * 96 + 30, 30, 54), Color("647b8aff"))
	var before := image.get_data()
	var result := Model.inspect(image)
	check(result.valid and result.frames.size() == 80, "bounded80-cell binary alpha fixture accepted")
	check(image.get_data() == before, "inspection preserves exact source RGBA bytes")
	check(result.observed_baseline_y == 83 and result.expected_baseline_y == 83 and result.observed_baseline_values == [83], "uniform83 actual decoded baseline is reported")
	check(result.baseline_mismatches.is_empty() and result.frames[0].occupied_bottom_y == 83, "all80 uniform83 cells agree, including per-frame evidence")
	check("last-pixel y83" in Model.admission_summary(result), "viewer describes actual decoded baseline, not metadata-only pivot")
	var baseline84 := Image.create(768, 960, false, Image.FORMAT_RGBA8)
	baseline84.fill(Color.TRANSPARENT)
	for row: int in range(10):
		for column: int in range(8):
			baseline84.fill_rect(Rect2i(column * 96 + 30, row * 96 + 31, 30, 54), Color("647b8aff"))
	var result84 := Model.inspect(baseline84)
	check(result84.valid and result84.observed_baseline_y == 84 and result84.baseline_mismatches.is_empty(), "uniform84 is explicitly admitted")
	check("last-pixel y84" in Model.admission_summary(result84), "viewer does not hardcode83 for allowed84 sheet")
	var shifted: Image = image.duplicate()
	shifted.fill_rect(Rect2i(0, 0, 96, 96), Color.TRANSPARENT)
	shifted.fill_rect(Rect2i(30, 29, 30, 54), Color("647b8aff"))
	var shifted_before := shifted.get_data()
	var shifted_result := Model.inspect(shifted)
	check(not shifted_result.valid and shifted_result.observed_baseline_y == -1 and shifted_result.observed_baseline_values == [82,83], "one cell moved up one pixel fails despite valid dimensions and alpha")
	check(shifted_result.baseline_mismatches.size() == 1 and shifted_result.expected_baseline_y == 83, "wrong first cell is the outlier, not the other79")
	check(shifted_result.baseline_mismatches[0] == {"row":"grounded","direction":"south","observed_y":82,"expected_y":83}, "mismatch reports exact semantic slot and measured/expected y")
	check(shifted.get_data() == shifted_before, "rejected inspection never repairs or shifts source pixels")
	check(Model.admission_summary(shifted_result).begins_with("FORMAT FAIL"), "invalid decoded baseline cannot display format pass")
	var mixed: Image = image.duplicate()
	mixed.fill_rect(Rect2i(0, 0, 96, 96), Color.TRANSPARENT)
	mixed.fill_rect(Rect2i(30, 31, 30, 54), Color("647b8aff"))
	var mixed_result := Model.inspect(mixed)
	check(not mixed_result.valid and mixed_result.observed_baseline_values == [83,84] and mixed_result.baseline_mismatches.size() == 1, "individually allowed83/84 may not be mixed in one sheet")
	var uniform82 := Image.create(768, 960, false, Image.FORMAT_RGBA8)
	uniform82.fill(Color.TRANSPARENT)
	for row: int in range(10):
		for column: int in range(8):
			uniform82.fill_rect(Rect2i(column * 96 + 30, row * 96 + 29, 30, 54), Color("647b8aff"))
	var result82 := Model.inspect(uniform82)
	check(not result82.valid and result82.observed_baseline_y == 82 and result82.baseline_mismatches.size() == 80, "consistent but unsupported82 baseline is rejected for all80 cells")
	check(result.decoded_rgba_bytes == 2949120, "single candidate decodes to2.8125MiB, never allcast")
	check(result.identical_walk_directions.size() == 8 and result.identical_sprint_directions.size() == 8, "identical contacts are disclosed instead of marked animated")
	check(not result.runtime_visual_acceptance, "format checks never claim art acceptance")
	var partial: Image = image.duplicate()
	partial.set_pixel(32, 32, Color(1, 1, 1, 0.5))
	check(not Model.inspect(partial).valid, "filtered alpha rejected")
	var clipped: Image = image.duplicate()
	clipped.set_pixel(0, 30, Color.WHITE)
	check(not Model.inspect(clipped).valid, "cell-edge paint reported as clipping")
	var empty: Image = image.duplicate()
	empty.fill_rect(Rect2i(0, 0, 96, 96), Color.TRANSPARENT)
	check(not Model.inspect(empty).valid, "missing pose rejected")
	var opaque: Image = image.duplicate()
	opaque.fill(Color.WHITE)
	check(not Model.inspect(opaque).valid, "opaque matte rejected")
	check(not Model.inspect(Image.create(96, 96, false, Image.FORMAT_RGBA8)).valid, "wrong sheet dimensions rejected")
	var board := Viewer.ReviewBoard.new()
	board._button("1x / 2x")
	check(board.scale_value == 2 and board.page == 0, "scale switch resets valid paging")
	board._button("Previous page")
	check(board.page == 9, "paging wraps across all2x cells")
	board._button("Step")
	check(not board.playing and board.frame == 1, "step pauses before advancing exactly one supplied pose")
	board.free()
	print("%s: character-sheet-qa / %d assertions / %d failures" % ["PASS" if failures == 0 else "FAIL", assertions, failures])
	quit(0 if failures == 0 else 1)


func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		print("FAIL: ", message)
