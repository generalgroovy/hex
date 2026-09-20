extends RefCounted

# Reuse the existing reference grammar, not a second gameplay animation map.
const Contract = preload("res://reference/art/neutral_body_templates_v1/preview/viewer_model.gd")
const SIZE := Vector2i(768, 960)
const CELL := 96
const PIVOT := Vector2(48, 84)
const MAX_FILE_BYTES := 32 * 1024 * 1024
const ALLOWED_BASELINES := [83, 84]


static func inspect(image: Image) -> Dictionary:
	var result := {"valid": false, "errors": [], "warnings": [], "frames": [], "identical_walk_directions": [], "identical_sprint_directions": [], "runtime_visual_acceptance": false,
		"allowed_baseline_y": ALLOWED_BASELINES.duplicate(), "observed_baseline_y": -1, "observed_baseline_values": [], "expected_baseline_y": -1, "baseline_mismatches": []}
	if image == null or image.is_empty() or image.get_size() != SIZE or image.get_format() != Image.FORMAT_RGBA8 or image.has_mipmaps():
		result.errors.append("Required: 768x960 RGBA8 PNG without mipmaps.")
		return result
	var bytes := image.get_data()
	var transparent := 0
	var partial := 0
	var clipped := 0
	var empty := 0
	var baseline_counts: Dictionary = {}
	for row: int in range(10):
		for column: int in range(8):
			var minimum := Vector2i(CELL, CELL)
			var maximum := Vector2i(-1, -1)
			var opaque := 0
			var edges := 0
			for y: int in range(CELL):
				for x: int in range(CELL):
					var alpha: int = bytes[((row * CELL + y) * SIZE.x + column * CELL + x) * 4 + 3]
					if alpha == 0:
						transparent += 1
						continue
					if alpha != 255:
						partial += 1
					opaque += 1
					minimum = minimum.min(Vector2i(x, y))
					maximum = maximum.max(Vector2i(x, y))
					if x == 0 or y == 0 or x == CELL - 1 or y == CELL - 1:
						edges += 1
			var region := Rect2i(column * CELL, row * CELL, CELL, CELL)
			var hash_context := HashingContext.new()
			hash_context.start(HashingContext.HASH_SHA256)
			hash_context.update(image.get_region(region).get_data())
			result.frames.append({"row": Contract.ROWS[row], "direction": Contract.DIRECTIONS[column], "opaque_pixels": opaque, "edge_pixels": edges, "occupied_bottom_y": maximum.y, "bounds": [minimum.x, minimum.y, maximum.x - minimum.x + 1, maximum.y - minimum.y + 1] if opaque > 0 else [], "rgba_sha256": hash_context.finish().hex_encode()})
			if opaque > 0: baseline_counts[maximum.y] = int(baseline_counts.get(maximum.y, 0)) + 1
			empty += 1 if opaque == 0 else 0
			clipped += 1 if edges > 0 else 0
	if transparent == 0: result.errors.append("No transparent pixels: opaque matte is not native alpha.")
	if partial > 0: result.errors.append("%d partially transparent pixels: review filtered edges." % partial)
	if empty > 0: result.errors.append("%d empty semantic cells." % empty)
	if clipped > 0: result.errors.append("%d cells touch a 96px cell edge; inspect clipping or bleed." % clipped)
	var observed: Array = baseline_counts.keys()
	observed.sort()
	result.observed_baseline_values = observed
	result.observed_baseline_y = int(observed[0]) if observed.size() == 1 else -1
	# A dominant admitted baseline identifies the actual outlier even when the
	# first/grounded cell is wrong. A tie (or no admitted baseline) prefers83.
	var expected := 84 if int(baseline_counts.get(84, 0)) > int(baseline_counts.get(83, 0)) else 83
	result.expected_baseline_y = expected
	for frame: Dictionary in result.frames:
		if int(frame.occupied_bottom_y) != expected:
			result.baseline_mismatches.append({"row":frame.row,"direction":frame.direction,"observed_y":frame.occupied_bottom_y,"expected_y":expected})
	if not result.baseline_mismatches.is_empty():
		result.errors.append("Decoded occupied feet must share last-pixel y83 or84 across all80 cells. Observed %s; %d cells differ from expected y%d." % [str(observed),result.baseline_mismatches.size(),expected])
	for direction: int in range(8):
		if result.frames[4 * 8 + direction].rgba_sha256 == result.frames[8 * 8 + direction].rgba_sha256:
			result.identical_walk_directions.append(Contract.DIRECTIONS[direction])
		if result.frames[5 * 8 + direction].rgba_sha256 == result.frames[9 * 8 + direction].rgba_sha256:
			result.identical_sprint_directions.append(Contract.DIRECTIONS[direction])
	if not result.identical_walk_directions.is_empty(): result.warnings.append("Walk A/B are byte-identical in %d directions; no alternating contact demonstrated." % result.identical_walk_directions.size())
	if not result.identical_sprint_directions.is_empty(): result.warnings.append("Sprint A/B are byte-identical in %d directions; no alternating contact demonstrated." % result.identical_sprint_directions.size())
	result.valid = result.errors.is_empty()
	result["transparent_pixels"] = transparent
	result["partial_alpha_pixels"] = partial
	result["decoded_rgba_bytes"] = bytes.size()
	return result


static func admission_summary(result: Dictionary) -> String:
	if not bool(result.get("valid", false)): return "FORMAT FAIL / inspect reported alpha, coverage and decoded-baseline errors."
	return "FORMAT PASS / alpha, 80 cells, last-pixel y%d. Anatomy, facing and alternating legs need human review." % int(result.get("observed_baseline_y", -1))


static func page_count(scale_value: int) -> int:
	return 2 if scale_value == 1 else 10


static func page_cells(scale_value: int, page: int) -> Array:
	var result: Array = []
	if scale_value not in [1, 2] or page < 0 or page >= page_count(scale_value): return result
	var columns := 8 if scale_value == 1 else 4
	var rows := 5 if scale_value == 1 else 2
	var column_start := 0 if scale_value == 1 else (page % 2) * 4
	@warning_ignore("integer_division")
	var row_start := page * 5 if scale_value == 1 else (page / 2) * 2
	for y: int in range(rows):
		for x: int in range(columns):
			result.append({"row": row_start + y, "direction": column_start + x, "slot_x": x, "slot_y": y})
	return result


static func action_row(action: String, frame: int) -> String:
	if action == "Action cycle": return Contract.ROWS[posmod(frame, Contract.ROWS.size())]
	var sequence: Array = Contract.sequence(action)
	return "" if sequence.is_empty() else String(sequence[posmod(frame, sequence.size())])
