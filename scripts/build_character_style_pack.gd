extends SceneTree

# Isolated standard resource assembly. No pose synthesis or live registry writes.
# Existing source pixels are cropped/registered only. Any background removal
# requires an explicit source-hash-locked rule; partial reviews are never atlases.
const Importer := preload("res://reference/art/neutral_body_templates_v1/build_pack.gd")
const ROOT := "res://art_batches/character_style_v1/"
const CATALOG := "res://content/champions/foundation_champions_v1.json"
const HEIGHTS := {"small": 58, "middle": 68, "large": 76}


func _initialize() -> void:
	var spec_path := ""
	var output := ""
	var inspect_only := false
	var partial_review := false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--spec="):
			spec_path = argument.trim_prefix("--spec=")
		elif argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument == "--inspect":
			inspect_only = true
		elif argument == "--review":
			partial_review = true
		else:
			_abort("Expected --spec=res://... [--output=res://...] [--inspect|--review]")
			return
	if output.is_empty():
		output = spec_path.get_base_dir().path_join("review-v1" if partial_review else "candidate-v1")
	if not safe_path(spec_path) or not safe_path(output):
		_abort("Both paths must stay inside " + ROOT)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(spec_path))
	if not parsed is Dictionary:
		_abort("Invalid source-layout JSON")
		return
	var spec: Dictionary = parsed
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	var identity := resolve_identity(spec, catalog.get("champions", []))
	if not String(identity.error).is_empty():
		_abort(String(identity.error))
		return
	var sources: Dictionary = {}
	for entry: Dictionary in spec.get("pages", []):
		var source_id := String(entry.get("id", ""))
		if not source_id.is_valid_identifier() or sources.has(source_id) or sources.size() >= 80:
			_abort("Empty, duplicate or excessive source page IDs")
			return
		var path := String(entry.get("path", ""))
		if not safe_path(path) or not FileAccess.file_exists(path):
			_abort("Missing or unsafe source " + path)
			return
		if FileAccess.get_sha256(path) != String(entry.get("sha256", "")):
			_abort("Source hash mismatch: " + path)
			return
		var image := Image.new()
		if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
			_abort("Cannot decode " + path)
			return
		var source := inspect_source(image, entry)
		if not String(source.error).is_empty():
			_abort(path + ": " + String(source.error))
			return
		source.path = path
		source.sha256 = entry.sha256
		sources[String(entry.id)] = source
	var assembled := assemble(sources, identity, partial_review or inspect_only)
	if not String(assembled.error).is_empty():
		_abort(String(assembled.error))
		return
	for source_id: String in sources:
		if FileAccess.get_sha256(String(sources[source_id].path)) != String(sources[source_id].sha256):
			_abort("Source changed during assembly")
			return
	if inspect_only:
		print("INSPECT PASS: ", assembled.manifest.frame_count, "/80 cells; ", identity.champion_id, " ", identity.body, ". Visual QA is not certified.")
		quit(0)
		return
	if DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output):
		_abort("Refusing to overwrite candidate: " + output)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_abort("Cannot create isolated candidate directory")
		return
	var atlas: Image = assembled.image
	var atlas_path := output.path_join(String(identity.champion_id) + ("-partial-review.png" if partial_review else ".png"))
	if atlas.save_png(atlas_path) != OK:
		_abort("Cannot save atlas")
		return
	var manifest: Dictionary = assembled.manifest
	manifest.source_spec = spec_path
	manifest.live_promotion = false
	manifest.path = atlas_path
	manifest.sha256 = FileAccess.get_sha256(atlas_path)
	manifest.rgba_sha256 = Importer.bytes_sha256(atlas.get_data())
	manifest.visual_review = spec.get("visual_review", {})
	for record: Dictionary in manifest.sources:
		var source: Dictionary = sources[String(record.id)]
		if int(source.get("removed_pixels", 0)) == 0:
			continue
		var mask_path := output.path_join(String(record.id) + "-removal-mask.png")
		var mask: Image = source.removal_mask
		if mask.save_png(mask_path) != OK:
			_abort("Cannot save exact background-removal mask")
			return
		record.removal_mask_path = mask_path
		record.removal_mask_sha256 = FileAccess.get_sha256(mask_path)
	var file := FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	if file == null:
		_abort("Cannot save manifest")
		return
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	file.close()
	print("PACK PASS: ", atlas_path, "; ", manifest.frame_count, "/80 cells; ", atlas.get_size(), "; nearest; pivot48/84; one ", identity.body, "-body scale")
	print("CANDIDATE ONLY: anatomy, opposite-foot contacts and headings require review; no live files changed.")
	quit(0)


static func safe_path(path: String) -> bool:
	return path.begins_with(ROOT) and path.simplify_path() == path and not path.contains("\\") and not path.ends_with("/")


static func inspect_source(original: Image, entry: Dictionary) -> Dictionary:
	var source_id := String(entry.get("id", ""))
	if not source_id.is_valid_identifier() or original == null or original.is_empty():
		return {"error": "Unknown or empty source"}
	var source: Image = original.duplicate()
	source.convert(Image.FORMAT_RGBA8)
	var data := source.get_data()
	var alpha_min := 255
	var alpha_max := 0
	var transparent := 0
	var partial := 0
	for index: int in range(3, data.size(), 4):
		alpha_min = mini(alpha_min, data[index])
		alpha_max = maxi(alpha_max, data[index])
		if data[index] == 0:
			transparent += 1
		elif data[index] < 255:
			partial += 1
	var mode := "actual_alpha" if alpha_min < 255 else "solid_matte"
	var matte := source.get_pixel(0, 0)
	var rule: Dictionary = entry.get("background_removal", {})
	if not rule.is_empty():
		if rule.get("method", "") != "edge_connected_neutral_checker" or int(rule.get("minimum_channel", 0)) < 160 \
			or int(rule.get("minimum_channel", 0)) > 220 or int(rule.get("maximum_spread", 255)) < 0 \
			or int(rule.get("maximum_spread", 255)) > 24 or String(rule.get("authorization", "")).is_empty():
			return {"error": "Unsupported or unreviewed background-removal rule"}
		if mode == "solid_matte":
			mode = "reviewed_neutral_checker"
	if mode == "solid_matte" and matte != Color.MAGENTA and matte != Color.WHITE:
		return {"error": "Opaque source needs exact uniform #FF00FF or #FFFFFF; observed #" + matte.to_html(true) + ". No automatic chroma tolerance."}
	var cells: Array = entry.get("cells", [])
	if cells.is_empty() or cells.size() > 80 or float(entry.get("reference_cell_width", 0.0)) <= 0.0:
		return {"error": "Incorrect explicit cell metadata"}
	var regions: Array[Rect2i] = []
	var poses: Array[Dictionary] = []
	var semantic_slots: Dictionary = {}
	var removed_pixels := 0
	var removal_mask := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_L8)
	removal_mask.fill(Color.BLACK)
	for index: int in range(cells.size()):
		var cell_spec: Dictionary = cells[index]
		var values: Array = cell_spec.get("rect", [])
		if values.size() != 4:
			return {"error": "Each cell requires explicit [x,y,width,height]"}
		var region := Rect2i(int(values[0]), int(values[1]), int(values[2]), int(values[3]))
		if not region.has_area() or not Rect2i(Vector2i.ZERO, source.get_size()).encloses(region):
			return {"error": "Cell rectangle escapes source"}
		for prior: Rect2i in regions:
			if prior.intersects(region):
				return {"error": "Overlapping source rectangles"}
		regions.append(region)
		var state := String(cell_spec.get("state", ""))
		var direction := String(cell_spec.get("direction", ""))
		var semantic := state + "/" + direction
		if not Importer.STATES.has(state) or not Importer.DIRECTIONS.has(direction) or semantic_slots.has(semantic):
			return {"error": "Unknown or duplicate explicit state/direction"}
		semantic_slots[semantic] = true
		var cell := source.get_region(region)
		if mode == "reviewed_neutral_checker":
			if not checker_perimeter(cell, rule):
				return {"error": semantic + ": reviewed checker rule does not match the complete cell perimeter"}
			removed_pixels += remove_checker_background(cell, rule)
			if not Importer._perimeter_is_background(cell, "actual_alpha", matte):
				return {"error": semantic + ": background removal did not produce empty gutter"}
		elif not Importer._perimeter_is_background(cell, mode, matte):
			return {"error": state + "/" + direction + ": cell edge is not uniform empty background; crop, clipping or matte defect"}
		if mode == "solid_matte":
			Importer._remove_edge_matte(cell, matte)
		if mode in ["solid_matte", "reviewed_neutral_checker"]:
			var cleaned_data := cell.get_data()
			for pixel: int in range(cell.get_width() * cell.get_height()):
				if cleaned_data[pixel * 4 + 3] == 0:
					removal_mask.set_pixel(region.position.x + pixel % cell.get_width(), region.position.y + floori(float(pixel) / cell.get_width()), Color.WHITE)
					if mode == "solid_matte":
						removed_pixels += 1
		var bounds: Rect2i = Importer._visible_bounds(cell)
		if not bounds.has_area():
			return {"error": state + "/" + direction + ": empty cell"}
		if not Rect2i(1, 1, cell.get_width() - 2, cell.get_height() - 2).encloses(bounds):
			return {"error": state + "/" + direction + ": clipped pose"}
		poses.append({"state": state, "direction": direction, "image": cell.get_region(bounds),
			"cell_region": values, "visible_bounds": Importer._rect_values(bounds)})
	return {"error": "", "poses": poses, "path": "", "sha256": "", "size": [source.get_width(), source.get_height()],
		"cell_width": float(entry.reference_cell_width), "original_alpha": {"minimum": alpha_min, "maximum": alpha_max,
		"transparent_pixels": transparent, "partial_pixels": partial}, "import_mode": mode, "matte": matte.to_html(true),
		"background_removal": rule, "removed_pixels": removed_pixels, "removal_mask": removal_mask}


static func resolve_identity(spec: Dictionary, entries: Array) -> Dictionary:
	var kind_value: Variant = spec.get("asset_kind", "champion")
	if not kind_value is String:
		return {"error": "Character art asset_kind must be a string"}
	var asset_kind: String = kind_value
	if asset_kind == "neutral_body_template":
		# Neutral construction assets have a separate explicit namespace. They
		# never impersonate a catalog champion or make a missing identity valid.
		var template_id: Variant = spec.get("champion_id")
		var body: Variant = spec.get("body")
		var height: Variant = spec.get("standing_height")
		if not template_id is String or not body is String or not HEIGHTS.has(body) \
			or template_id != "template_" + body \
			or (not height is int and not height is float) or not is_finite(float(height)) \
			or float(height) != float(HEIGHTS[body]):
			return {"error": "Neutral asset requires exact template_small/middle/large ID, matching explicit body and standing height"}
		return {"error": "", "asset_kind": asset_kind, "champion_id": template_id,
			"display_name": String(body).capitalize() + " neutral body template", "body": body, "standing_height": HEIGHTS[body]}
	if asset_kind != "champion":
		return {"error": "Unknown character art asset_kind"}
	var requested := String(spec.get("champion_id", spec.get("champion", "")))
	for entry: Dictionary in entries:
		if requested != String(entry.get("id", "")) and requested != String(entry.get("display_name", "")):
			continue
		var body := String(entry.get("body_type", ""))
		if not HEIGHTS.has(body) or String(spec.get("body", body)) != body or int(spec.get("standing_height", HEIGHTS[body])) != int(HEIGHTS[body]):
			return {"error": "Body/standing height must match the canonical three-size profile"}
		return {"error": "", "asset_kind": asset_kind, "champion_id": String(entry.id), "display_name": String(entry.display_name), "body": body, "standing_height": HEIGHTS[body]}
	return {"error": "Unknown canonical named champion: " + requested}


static func assemble(sources: Dictionary, identity: Dictionary, allow_partial: bool = false) -> Dictionary:
	if not String(identity.get("error", "")).is_empty() or not HEIGHTS.has(identity.get("body", "")):
		return {"error": "Valid canonical identity required"}
	var slots: Dictionary = {}
	var source_records: Array[Dictionary] = []
	var reference: Dictionary = {}
	for source_id: String in sources:
		var source: Dictionary = sources[source_id]
		if not String(source.get("error", "")).is_empty():
			return {"error": "Invalid inspected source: " + source_id}
		var record := source.duplicate()
		record.erase("poses")
		record.erase("error")
		record.erase("removal_mask")
		record.id = source_id
		source_records.append(record)
		for pose: Dictionary in source.poses:
			var slot := String(pose.state) + "/" + String(pose.direction)
			if slots.has(slot):
				return {"error": "Duplicate pose across pages: " + slot}
			slots[slot] = {"pose": pose, "source_id": source_id, "cell_width": source.cell_width}
			if slot == "grounded/south":
				reference = slots[slot]
	if reference.is_empty() or slots.size() > 80 or (not allow_partial and slots.size() != 80):
		return {"error": "Full atlas requires80 unique poses; every review requires grounded/south reference"}
	var body_scale := float(HEIGHTS[identity.body]) / float(reference.pose.image.get_height())
	var columns := mini(8, slots.size()) if allow_partial else 8
	var rows := ceili(float(slots.size()) / columns) if allow_partial else 10
	var image := Image.create(columns * 96, rows * 96, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var frames: Array[Dictionary] = []
	for state: String in Importer.STATES:
		for direction: String in Importer.DIRECTIONS:
			var key := state + "/" + direction
			if not slots.has(key):
				continue
			var slot: Dictionary = slots[key]
			var pose: Dictionary = slot.pose
			var normalization := float(reference.cell_width) / float(slot.cell_width)
			var pixels: Image = pose.image.duplicate()
			var scaled := Vector2i(maxi(1, roundi(pixels.get_width() * normalization * body_scale)), maxi(1, roundi(pixels.get_height() * normalization * body_scale)))
			pixels.resize(scaled.x, scaled.y, Image.INTERPOLATE_NEAREST)
			# Nearest sampling can drop a sparse outermost toe/cloth pixel.
			# Register the pixels that actually survived, not the resized canvas.
			# This removes transparent padding only; scale/anatomy stay untouched.
			var occupied := pixels.get_used_rect()
			if not occupied.has_area():
				return {"error": key + ": source disappears at fixed body scale"}
			var offset := Vector2i(48 - floori(occupied.size.x / 2.0), 84 - occupied.size.y)
			if not Rect2i(1, 1, 94, 94).encloses(Rect2i(offset, occupied.size)):
				return {"error": key + ": exceeds fixed-scale96px cell; no per-pose fitting"}
			var position := Vector2i(frames.size() % columns, floori(float(frames.size()) / columns)) * 96
			image.blit_rect(pixels, occupied, position + offset)
			frames.append({"state": state, "direction": direction, "source": slot.source_id, "source_rect": pose.cell_region,
				"source_visible_bounds": pose.visible_bounds, "source_cell_width_normalization": normalization,
				"resampled_dimensions": [scaled.x, scaled.y], "resampled_occupied_bounds": Importer._rect_values(occupied),
				"output_region": [position.x, position.y, 96, 96], "output_visible_bounds": [offset.x, offset.y, occupied.size.x, occupied.size.y]})
	return {"error": "", "image": image, "manifest": {"schema_version": 2, "id": String(identity.champion_id) + "-style-pilot",
		"asset_kind": identity.get("asset_kind", "champion"),
		"champion_id": identity.champion_id, "display_name": identity.display_name, "body_type": identity.body, "standing_height": HEIGHTS[identity.body],
		"status": "partial_review_only" if allow_partial else "complete_candidate_visual_qa_pending", "complete_coverage": slots.size() == 80,
		"live_promotion": false, "frame_count": slots.size(), "required_frame_count": 80, "body_scale": body_scale,
		"dimensions": [image.get_width(), image.get_height()], "cell": [96, 96], "pivot": [48, 84], "sampling": "nearest",
		"states": Importer.STATES, "directions": Importer.DIRECTIONS, "scale_policy": "one body scale after page cell-width normalization",
		"registration_policy": "visible bottom center at shared pivot; source anatomy drift not compensated",
		"sources": source_records, "frames": frames}}


static func is_checker(color: Color, rule: Dictionary) -> bool:
	var low := minf(color.r, minf(color.g, color.b)) * 255.0
	var high := maxf(color.r, maxf(color.g, color.b)) * 255.0
	return color.a > 0.0 and low >= float(rule.minimum_channel) and high - low <= float(rule.maximum_spread) + 0.001


static func checker_perimeter(cell: Image, rule: Dictionary) -> bool:
	for x: int in range(cell.get_width()):
		if not is_checker(cell.get_pixel(x, 0), rule) or not is_checker(cell.get_pixel(x, cell.get_height() - 1), rule):
			return false
	for y: int in range(cell.get_height()):
		if not is_checker(cell.get_pixel(0, y), rule) or not is_checker(cell.get_pixel(cell.get_width() - 1, y), rule):
			return false
	return true


static func remove_checker_background(cell: Image, rule: Dictionary) -> int:
	var pending := PackedInt32Array([0])
	var visited := PackedByteArray()
	visited.resize(cell.get_width() * cell.get_height())
	var cursor := 0
	var removed := 0
	while cursor < pending.size():
		var index := int(pending[cursor])
		cursor += 1
		if visited[index] != 0:
			continue
		visited[index] = 1
		var x := index % cell.get_width()
		var y := floori(float(index) / cell.get_width())
		if not is_checker(cell.get_pixel(x, y), rule):
			continue
		cell.set_pixel(x, y, Color.TRANSPARENT)
		removed += 1
		if x > 0:
			pending.append(index - 1)
		if x + 1 < cell.get_width():
			pending.append(index + 1)
		if y > 0:
			pending.append(index - cell.get_width())
		if y + 1 < cell.get_height():
			pending.append(index + cell.get_width())
	return removed


func _abort(message: String) -> void:
	push_error("Character style pack: " + message)
	quit(1)
