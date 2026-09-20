extends SceneTree

# Isolated resource assembly only. Never replaces a live character, modifies a
# source PNG, derives a new pose, or changes scale to make an action fit.
const PACK_ROOT := "res://reference/art/neutral_body_templates_v1"
const CELL := Vector2i(96, 96)
const PIVOT := Vector2i(48, 84)
const STATES := ["grounded", "jump", "cast", "hit", "walk", "sprint", "slide", "roll", "walk_b", "sprint_b"]
const DIRECTIONS := ["south", "south_east", "east", "north_east", "north", "north_west", "west", "south_west"]
const PAGE_SPECS := {
	"cardinal_core": {"directions": ["south", "east", "north", "west"], "states": ["grounded", "jump", "cast", "hit"]},
	"cardinal_motion": {"directions": ["south", "east", "north", "west"], "states": ["walk", "sprint", "slide", "roll"]},
	"cardinal_phase_b": {"directions": ["south", "east", "north", "west"], "states": ["walk_b", "sprint_b"]},
	"diagonal_core": {"directions": ["south_east", "north_east", "north_west", "south_west"], "states": ["grounded", "jump", "cast", "hit"]},
	"diagonal_motion": {"directions": ["south_east", "north_east", "north_west", "south_west"], "states": ["walk", "sprint", "slide", "roll"]},
	"diagonal_phase_b": {"directions": ["south_east", "north_east", "north_west", "south_west"], "states": ["walk_b", "sprint_b"]},
}
const HEIGHTS := {"small": 58, "middle": 68, "large": 76}
const ACTION_ALIASES := {
	"idle": "grounded", "walk": "walk", "sprint": "sprint", "jump": "jump",
	"float": "jump", "double_jump": "jump", "slide_jump": "jump", "air_dodge": "jump",
	"wall_kick": "jump", "fast_fall": "jump", "slide": "slide", "wave_dash": "slide",
	"wallrun": "slide", "wall_skim": "slide", "roll": "roll", "charging": "cast",
	"cast": "cast", "cast_recovery": "cast", "attack_primary": "cast", "hit": "hit",
	"launched": "hit", "grappled": "hit", "stunned": "hit", "impact_recovery": "hit",
	"rooted": "grounded", "slowed": "walk", "defend": "grounded",
	"interact": "grounded", "taunt": "grounded", "defeated": "hit",
}


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	var source_dir := PACK_ROOT + "/source"
	var index := 0
	while index < arguments.size():
		var argument := arguments[index]
		if argument == "--source-dir" and index + 1 < arguments.size():
			index += 1
			source_dir = arguments[index]
		elif argument.begins_with("--source-dir="):
			source_dir = argument.trim_prefix("--source-dir=")
		else:
			_abort("Only --source-dir <absolute directory or res:// directory> is supported")
			return
		index += 1
	if source_dir.is_empty() or (not source_dir.is_absolute_path() and not source_dir.begins_with("res://")):
		_abort("Source directory must be explicit and absolute; relative paths are not accepted")
		return
	var source_records: Dictionary = {}
	for source_id: String in PAGE_SPECS:
		var path := source_dir.path_join(source_id + ".png")
		if not FileAccess.file_exists(path):
			_abort("Missing immutable source: " + path)
			return
		var bytes := FileAccess.get_file_as_bytes(path)
		var source_image := Image.new()
		if source_image.load_png_from_buffer(bytes) != OK:
			_abort("Cannot decode source PNG: " + path)
			return
		var record := inspect_source(source_image, source_id)
		if not String(record.error).is_empty():
			_abort(path + ": " + String(record.error))
			return
		record.path = path
		record.sha256 = bytes_sha256(bytes)
		source_records[source_id] = record
	var result := assemble(source_records)
	if not String(result.error).is_empty():
		_abort(String(result.error))
		return
	# Build and validate everything before creating any output file.
	for source_id: String in source_records:
		var source: Dictionary = source_records[source_id]
		if FileAccess.get_sha256(String(source.path)) != String(source.sha256):
			_abort("Source changed during assembly: " + String(source.path))
			return
	var output_dir := PACK_ROOT + "/runtime"
	var directory_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if directory_error != OK:
		_abort("Cannot create isolated runtime directory: " + error_string(directory_error))
		return
	var manifest: Dictionary = result.manifest
	for body: String in HEIGHTS:
		var output_path := output_dir.path_join(body + ".png")
		var output_image: Image = result.images[body]
		var save_error := output_image.save_png(output_path)
		if save_error != OK:
			_abort("Cannot save " + output_path + ": " + error_string(save_error))
			return
		manifest.bodies[body].path = output_path
		manifest.bodies[body].sha256 = FileAccess.get_sha256(output_path)
		manifest.bodies[body].rgba_sha256 = bytes_sha256(output_image.get_data())
	var manifest_file := FileAccess.open(output_dir.path_join("manifest.json"), FileAccess.WRITE)
	if manifest_file == null:
		_abort("Cannot write isolated pack manifest")
		return
	manifest_file.store_string(JSON.stringify(manifest, "\t") + "\n")
	manifest_file.close()
	print("Neutral body pack: 3 pages, 240 cells, 96px cell, pivot48/84, standing heights58/68/76; no live resources changed")
	print("Visual anatomy, direction accuracy and opposite-foot animation contacts still require human/flipbook review")
	quit(0)


static func inspect_source(source_image: Image, source_id: String) -> Dictionary:
	if not PAGE_SPECS.has(source_id):
		return _failure("Unknown master source identity")
	var spec: Dictionary = PAGE_SPECS[source_id]
	var row_count: int = spec.states.size()
	if source_image == null or source_image.is_empty() or source_image.get_width() < 8 or source_image.get_height() < row_count * 2:
		return _failure("Expected a nonempty four-column by %d-row source" % row_count)
	var source: Image = source_image.duplicate()
	source.convert(Image.FORMAT_RGBA8)
	var bytes := source.get_data()
	var transparent := 0
	var partial := 0
	var alpha_min := 255
	var alpha_max := 0
	for offset: int in range(3, bytes.size(), 4):
		var alpha := int(bytes[offset])
		alpha_min = mini(alpha_min, alpha)
		alpha_max = maxi(alpha_max, alpha)
		if alpha == 0:
			transparent += 1
		elif alpha < 255:
			partial += 1
	var mode := "actual_alpha" if alpha_min < 255 else "solid_matte"
	var matte := source.get_pixel(0, 0)
	if mode == "solid_matte":
		if matte != Color.WHITE and matte != Color.MAGENTA:
			return _failure("Opaque source requires exact solid #FFFFFF or #FF00FF matte; no checkerboard/gradient")
		for corner: Vector2i in [Vector2i.ZERO, Vector2i(source.get_width() - 1, 0), Vector2i(0, source.get_height() - 1), source.get_size() - Vector2i.ONE]:
			if source.get_pixelv(corner) != matte:
				return _failure("Opaque source corners are not one uniform matte")
	var poses: Array[Dictionary] = []
	for row: int in range(row_count):
		for column: int in range(4):
			var region := proportional_region(source.get_size(), column, row, row_count)
			var cell := source.get_region(region)
			var context := "%s/%s/%s" % [source_id, spec.states[row], spec.directions[column]]
			if not _perimeter_is_background(cell, mode, matte):
				return _failure(context + ": source cell edge is not uniform empty background (clipped pose, wrong grid, checkerboard or matte drift)")
			if mode == "solid_matte":
				_remove_edge_matte(cell, matte)
			var bounds := _visible_bounds(cell)
			if not bounds.has_area():
				return _failure(context + ": empty source cell")
			if bounds.position.x <= 0 or bounds.position.y <= 0 or bounds.end.x >= cell.get_width() or bounds.end.y >= cell.get_height():
				return _failure(context + ": source sprite lacks a complete transparent gutter")
			poses.append({
				"state": spec.states[row], "direction": spec.directions[column],
				"image": cell.get_region(bounds), "cell_region": _rect_values(region),
				"visible_bounds": _rect_values(bounds),
			})
	return {
		"error": "", "poses": poses, "path": "", "sha256": "", "size": [source.get_width(), source.get_height()],
		"cell_width": float(source.get_width()) / 4.0,
		"original_alpha": {"minimum": alpha_min, "maximum": alpha_max, "transparent_pixels": transparent, "partial_pixels": partial},
		"import_mode": mode, "matte": matte.to_html(false) if mode == "solid_matte" else "none",
	}


static func assemble(sources: Dictionary) -> Dictionary:
	if sources.size() != PAGE_SPECS.size():
		return _failure("All six cardinal/diagonal core, motion and phase-B master sheets are required")
	for source_id: String in PAGE_SPECS:
		if not sources.has(source_id):
			return _failure("Missing required master: " + source_id)
		var record: Dictionary = sources[source_id]
		if not String(record.get("error", "")).is_empty() or record.get("poses", []).size() != PAGE_SPECS[source_id].states.size() * 4:
			return _failure("Wrong pose count in source master: " + source_id)
	var standing_pose: Image = sources.cardinal_core.poses[0].image
	var standing_height := float(standing_pose.get_height())
	var canonical_cell_width := float(sources.cardinal_core.cell_width)
	if standing_height <= 0.0:
		return _failure("South grounded reference height is invalid")
	var images: Dictionary = {}
	var manifest := {
		"schema_version": 1, "id": "neutral-body-templates-v1", "status": "isolated_import_candidate_not_visual_acceptance",
		"authority": "reference resource assembly only; no live atlas, gameplay, collision or roster changes",
		"cell": [96, 96], "pivot": [48, 84], "directions": DIRECTIONS, "states": STATES,
		"row_layout": "state_major_direction_columns", "action_aliases": ACTION_ALIASES,
		"alias_limitations": "Ten physical poses only; semantic aliases are shared art, not independently authored animations. Float holds the existing jump pose; no new double-jump physics.",
		"sampling": "nearest", "scale_policy": "one fixed scale per body across all six masters; oversized poses fail",
		"source_canonical_cell_width": canonical_cell_width, "sources": {}, "bodies": {},
	}
	for source_id: String in PAGE_SPECS:
		var record: Dictionary = sources[source_id]
		manifest.sources[source_id] = {
			"path": record.path, "sha256": record.sha256, "dimensions": record.size,
			"columns": PAGE_SPECS[source_id].directions, "rows": PAGE_SPECS[source_id].states,
			"original_alpha": record.original_alpha, "import_mode": record.import_mode,
			"matte": record.matte, "cell_width_normalization": canonical_cell_width / float(record.cell_width),
		}
	for body: String in HEIGHTS:
		var scale := float(HEIGHTS[body]) / standing_height
		var page := Image.create(768, 960, false, Image.FORMAT_RGBA8)
		page.fill(Color.TRANSPARENT)
		var metadata: Array[Dictionary] = []
		for source_id: String in PAGE_SPECS:
			var source: Dictionary = sources[source_id]
			var source_factor := canonical_cell_width / float(source.cell_width)
			for pose: Dictionary in source.poses:
				var pixels: Image = pose.image.duplicate()
				var fitted := Vector2i(maxi(1, roundi(pixels.get_width() * source_factor * scale)), maxi(1, roundi(pixels.get_height() * source_factor * scale)))
				var local := Rect2i(Vector2i(PIVOT.x - fitted.x / 2, PIVOT.y - fitted.y), fitted)
				if not Rect2i(1, 1, 94, 94).encloses(local):
					return _failure("%s/%s/%s needs %s at fixed scale%.6f; exceeds96px cell/pivot gutter. Correct source pose; no automatic rescale." % [body, pose.state, pose.direction, fitted, scale])
				pixels.resize(fitted.x, fitted.y, Image.INTERPOLATE_NEAREST)
				var column := DIRECTIONS.find(String(pose.direction))
				var row := STATES.find(String(pose.state))
				var atlas_origin := Vector2i(column * CELL.x, row * CELL.y)
				page.blit_rect(pixels, Rect2i(Vector2i.ZERO, fitted), atlas_origin + local.position)
				metadata.append({"state": pose.state, "direction": pose.direction, "source": source_id,
					"source_cell": pose.cell_region, "source_visible_bounds": pose.visible_bounds,
					"normalized_bounds": [pose.visible_bounds[0] * source_factor, pose.visible_bounds[1] * source_factor, pose.visible_bounds[2] * source_factor, pose.visible_bounds[3] * source_factor], "output_visible_bounds": _rect_values(local),
					"output_region": [atlas_origin.x, atlas_origin.y, 96, 96],
				})
		images[body] = page
		manifest.bodies[body] = {"standing_height": HEIGHTS[body], "scale": scale, "render_scale": 1.0, "dimensions": [768, 960], "frames": metadata}
	return {"error": "", "images": images, "manifest": manifest}


static func proportional_region(size: Vector2i, column: int, row: int, row_count: int = 4) -> Rect2i:
	var left := roundi(float(column) * size.x / 4.0)
	var right := roundi(float(column + 1) * size.x / 4.0)
	var top := roundi(float(row) * size.y / row_count)
	var bottom := roundi(float(row + 1) * size.y / row_count)
	return Rect2i(left, top, right - left, bottom - top)


static func _perimeter_is_background(cell: Image, mode: String, matte: Color) -> bool:
	for x: int in range(cell.get_width()):
		for y: int in [0, cell.get_height() - 1]:
			if not _background(cell.get_pixel(x, y), mode, matte):
				return false
	for y: int in range(cell.get_height()):
		for x: int in [0, cell.get_width() - 1]:
			if not _background(cell.get_pixel(x, y), mode, matte):
				return false
	return true


static func _background(color: Color, mode: String, matte: Color) -> bool:
	return color.a == 0.0 if mode == "actual_alpha" else color == matte


static func _remove_edge_matte(cell: Image, matte: Color) -> void:
	var pending: Array[Vector2i] = [Vector2i.ZERO]
	var visited := PackedByteArray()
	visited.resize(cell.get_width() * cell.get_height())
	var cursor := 0
	while cursor < pending.size():
		var point := pending[cursor]
		cursor += 1
		if point.x < 0 or point.y < 0 or point.x >= cell.get_width() or point.y >= cell.get_height():
			continue
		var key := point.y * cell.get_width() + point.x
		if visited[key] != 0:
			continue
		visited[key] = 1
		if cell.get_pixelv(point) != matte:
			continue
		cell.set_pixelv(point, Color.TRANSPARENT)
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			pending.append(point + offset)


static func _visible_bounds(cell: Image) -> Rect2i:
	var low := cell.get_size()
	var high := Vector2i(-1, -1)
	for y: int in range(cell.get_height()):
		for x: int in range(cell.get_width()):
			if cell.get_pixel(x, y).a > 0.0:
				low = Vector2i(mini(low.x, x), mini(low.y, y))
				high = Vector2i(maxi(high.x, x), maxi(high.y, y))
	return Rect2i(low, high - low + Vector2i.ONE) if high.x >= 0 else Rect2i()


static func _rect_values(value: Rect2i) -> Array[int]:
	return [value.position.x, value.position.y, value.size.x, value.size.y]


static func bytes_sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


static func _failure(message: String) -> Dictionary:
	return {"error": message}


func _abort(message: String) -> void:
	push_error("Neutral body pack: " + message)
	quit(1)
