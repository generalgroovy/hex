extends SceneTree
@warning_ignore_start("integer_division")

# Isolated mechanical import only. Original sources and pixel_v1 stay untouched.
# A study is eight material frames, NOT a replacement for the live 474-sequence kit.
const ROOT := "res://art_batches/pixel_v2/magic_material_studies"
const NAMES := ["fire", "water", "earth", "wind", "charge", "ice", "light", "dark"]
const OUT_OF_SCOPE_NAMES := ["steam_formation", "steam_active", "steam_decay"]
const SIZE := Vector2i(128, 64)
const CELL := Vector2i(32, 32)
const PIVOT := Vector2i(16, 26)
const MAX_SOURCE_PIXELS := 8_388_608
const ID := "flux-magic-material-studies-v2"
const MATTE_RULE := "R>=170; B>=170; G<=70; abs(R-B)<=65; approved material palettes exclude this family; edge and enclosed matches removed separately"
# One explicit root correction per whole sheet, never independently fitted poses.
# The observed Fire source uses a lower root than the requested nominal anchor.
const SOURCE_PIVOTS := {"fire": Vector2(0.5, 0.9)}
const NOMINAL_SOURCE_PIVOT := Vector2(0.5, 0.8125)
# Explicitly approved source-layout calibration, identical for all four bottom
# cells. This is not inferred from per-frame bounds or a new animation pose.
const BOTTOM_ROW_TRANSLATION := {"fire": Vector2i(0, 1), "water": Vector2i(0, 6), "earth": Vector2i(0, 2), "wind": Vector2i(0, 2), "charge": Vector2i(0, 3), "ice": Vector2i(0, 4), "light": Vector2i(0, 3), "dark": Vector2i(0, 2)}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var parsed := parse_arguments(OS.get_cmdline_user_args())
	if not String(parsed.error).is_empty():
		_abort(parsed.error)
		return
	var selected: Array = parsed.names
	var prepared: Dictionary = {}
	var missing_sources: Array[String] = []
	for name: String in NAMES:
		var path := ROOT.path_join("sources/" + name + ".png")
		if not FileAccess.file_exists(path):
			missing_sources.append(name)
			continue
		if name not in selected:
			continue
		var bytes := FileAccess.get_file_as_bytes(path)
		var source := Image.new()
		if source.load_png_from_buffer(bytes) != OK:
			_abort("Source PNG cannot be decoded: " + name)
			return
		var record := prepare_page(source, name)
		if not String(record.error).is_empty():
			_abort(name + ": " + String(record.error))
			return
		record.metadata.source.path = "sources/" + name + ".png"
		record.metadata.source.sha256 = hash_bytes(bytes)
		record.metadata.source.png_bytes = bytes.size()
		record.png_bytes = (record.image as Image).save_png_to_buffer()
		if record.png_bytes.is_empty():
			_abort("Cannot encode prepared PNG: " + name)
			return
		record.metadata.sha256 = hash_bytes(record.png_bytes)
		prepared[name] = record
	# Validate the entire requested batch, including source stability, before writes.
	for name: String in prepared:
		if FileAccess.get_sha256(ROOT.path_join(prepared[name].metadata.source.path)) != String(prepared[name].metadata.source.sha256):
			_abort("Source changed during preparation: " + name)
			return
	if bool(parsed.validate_only):
		print("Magic studies validation: %d requested pages valid; missing sources: %s; no files written" % [prepared.size(), ", ".join(missing_sources)])
		quit(0)
		return
	if prepared.is_empty():
		_abort("No requested source pages are present; no output or completion claim written")
		return
	var assets := retained_assets()
	for name: String in prepared:
		assets[name] = prepared[name].metadata
	var manifest := make_manifest(assets, selected, missing_sources)
	var directory_error := DirAccess.make_dir_recursive_absolute(ROOT.path_join("packed"))
	if directory_error != OK:
		_abort("Cannot create isolated packed directory: " + error_string(directory_error))
		return
	for name: String in prepared:
		if not write_bytes(ROOT.path_join("packed/" + name + ".png"), prepared[name].png_bytes):
			_abort("Cannot write packed PNG: " + name)
			return
	var serialized := JSON.stringify(manifest, "\t")
	if not write_bytes(ROOT.path_join("packed/manifest.json"), (serialized + "\n").to_utf8_buffer()) \
		or not write_bytes(ROOT.path_join("packed/manifest.js"), ("window.MagicStudyPackedMetadata = " + serialized + ";\n").to_utf8_buffer()):
		_abort("Cannot write isolated manifest metadata")
		return
	print("Magic studies packed: %d new pages, %d valid built pages; missing studies: %s" % [prepared.size(), assets.size(), ", ".join(manifest.missing_names)])
	for name: String in prepared:
		var meta: Dictionary = prepared[name].metadata
		print("%s: 8 frames, %d ticks, alpha=%s, removed-edge=%d, removed-enclosed=%d, sheet-shift=%s, bottom-row-shift=%s, source=%s" % [name, meta.total_ticks, meta.source.alpha.mode, meta.source.alpha.removed_edge_connected_pixels, meta.source.alpha.removed_enclosed_pixels, meta.transform.translation_output_px, meta.source_layout_calibration.row_translation_output_px[1], meta.source.sha256])
	print("Isolated material studies only; anchor/material/loop visual acceptance pending; no live resources or mechanics changed")
	quit(0)


static func parse_arguments(arguments: PackedStringArray) -> Dictionary:
	var result := {"error": "", "names": NAMES.duplicate(), "validate_only": false}
	var names_seen := false
	var index := 0
	while index < arguments.size():
		var value := arguments[index]
		if value == "--validate-only":
			result.validate_only = true
		elif value == "--names" or value.begins_with("--names="):
			if names_seen:
				return failure("--names may appear only once")
			names_seen = true
			if value == "--names":
				index += 1
				if index >= arguments.size():
					return failure("--names requires a comma-separated known-name list")
				value = arguments[index]
			else:
				value = value.trim_prefix("--names=")
			var names: Array[String] = []
			for name: String in value.split(",", true):
				if name not in NAMES or name in names:
					return failure("Unknown, empty or duplicate study name: " + name)
				names.append(name)
			result.names = names
		else:
			return failure("Unsupported argument: " + value)
		index += 1
	return result


static func prepare_page(original: Image, name: String) -> Dictionary:
	if name not in NAMES:
		return failure("Unknown study identity")
	if original == null or original.is_empty() or original.has_mipmaps() or original.is_compressed():
		return failure("Expected a nonempty uncompressed source without mipmaps")
	var source_size := original.get_size()
	if source_size.x != source_size.y * 2 or source_size.x < SIZE.x or source_size.x * source_size.y > MAX_SOURCE_PIXELS:
		return failure("Source must be exact2:1, at least128x64, and at most8,388,608 pixels; odd dimensions are allowed")
	var source: Image = original.duplicate()
	source.convert(Image.FORMAT_RGBA8)
	var original_rgba_hash := hash_bytes(source.get_data())
	var alpha := alpha_summary(source.get_data())
	var mode := "native_alpha" if int(alpha.minimum) < 255 else "approved_magenta_family"
	# All four cell edges plus one target-pixel margin must be empty background.
	# This rejects clipped poses, wrong grids, checkerboards and background drift.
	for frame_index: int in range(8):
		var region := source_region(source_size, frame_index)
		var margin := maxi(1, ceili(float(region.size.x) / 32.0))
		if not margin_is_background(source, region, margin, mode):
			return failure("Frame%d margin is not uniform transparent/magenta-family background; clipped art, wrong grid or checkerboard" % frame_index)
	var extraction := extract_background(source, mode)
	source = extraction.image
	alpha.merge(extraction.alpha, true)
	alpha.mode = mode
	var source_pivot: Vector2 = SOURCE_PIVOTS.get(name, NOMINAL_SOURCE_PIVOT)
	var shift := Vector2i((Vector2(PIVOT) - source_pivot * 32.0).round())
	var source_cells: Array[Dictionary] = []
	for frame_index: int in range(8):
		var region := source_region(source_size, frame_index)
		var bounds := source.get_region(region).get_used_rect()
		if not bounds.has_area():
			return failure("Frame%d is empty after background extraction" % frame_index)
		source_cells.append({"rect": rect_values(region), "visible_bounds": rect_values(bounds)})
	# Exactly ONE resize for the entire page. No visible-bounds-based scaling,
	# trimming-to-fit or independently positioned frames are permitted.
	var normalized: Image = source.duplicate()
	normalized.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_NEAREST)
	var packed := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	packed.fill(Color(0, 0, 0, 0))
	var durations := frame_durations(name)
	var frames: Array[Dictionary] = []
	var raw_frames: Array[Dictionary] = []
	var bottom_shift: Vector2i = BOTTOM_ROW_TRANSLATION.get(name, Vector2i.ZERO)
	for frame_index: int in range(8):
		var region := output_region(frame_index)
		var cell := normalized.get_region(region)
		var bounds := cell.get_used_rect()
		if not bounds.has_area():
			return failure("Frame%d disappears at fixed32px sampling; source correction required" % frame_index)
		raw_frames.append({"visible_bounds": rect_values(Rect2i(bounds.position + shift, bounds.size))})
		var frame_shift := shift + (bottom_shift if frame_index >= 4 else Vector2i.ZERO)
		var translated_bounds := Rect2i(bounds.position + frame_shift, bounds.size)
		if not Rect2i(1, 1, 30, 30).encloses(translated_bounds):
			return failure("Frame%d would clip or lose its1px interior margin at the explicit sheet/row shift%s" % [frame_index, frame_shift])
		var translated := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		translated.fill(Color(0, 0, 0, 0))
		translated.blit_rect(cell, Rect2i(Vector2i.ZERO, CELL), frame_shift)
		packed.blit_rect(translated, Rect2i(Vector2i.ZERO, CELL), region.position)
		frames.append({"index": frame_index, "rect": rect_values(region), "pivot_px": [16, 26], "duration_ticks": durations[frame_index], "visible_bounds": rect_values(translated_bounds), "translation_output_px": [frame_shift.x, frame_shift.y]})
	var validation := validate_packed(packed)
	if not String(validation.error).is_empty():
		return validation
	var total := 0
	for duration: int in durations:
		total += duration
	var metadata := {
		"id": name, "path": "packed/" + name + ".png", "dimensions": [128, 64], "frame_size_px": [32, 32],
		"pivot_px": [16, 26], "tick_rate": 120, "phase_relative": true, "phase": "active",
		"loop": true, "end_behavior": "hold_until_authority_phase_end",
		"total_ticks": total, "authority_phase_ticks": 0, "frames": frames,
		"layout_qa": layout_diagnostics(frames),
		"raw_layout_qa": layout_diagnostics(raw_frames),
		"source_layout_calibration": {"row_translation_output_px": [[0, 0], [bottom_shift.x, bottom_shift.y]], "approved_reason": "explicit generated-source row-origin alignment only; same shift across all four bottom frames; no automatic fit"},
		"rgba_sha256": hash_bytes(packed.get_data()), "alpha": validation.alpha,
		"anchor_status": "nominal_root_correction_pending_visual_acceptance", "runtime_integrated": false,
		"source": {"path": "", "sha256": "", "dimensions": [source_size.x, source_size.y], "rgba_sha256": original_rgba_hash, "alpha": alpha, "cells": source_cells},
		"transform": {"kind": "one_whole_page_nearest_resize_then_shared_sheet_and_explicit_row_translation", "scale": 128.0 / float(source_size.x), "source_pivot_fraction": [source_pivot.x, source_pivot.y], "translation_output_px": [shift.x, shift.y], "same_scale_for_every_frame": true, "per_frame_fit": false},
		"geometry_policy": "material study only; production requires live collision/coverage clipping, authority cancellation and independent essential boundaries",
	}
	return {"error": "", "image": packed, "metadata": metadata}


static func layout_diagnostics(frames: Array) -> Dictionary:
	var means := [0.0, 0.0]
	for index: int in range(8):
		var bounds: Array = frames[index].visible_bounds
		means[index / 4] += float(int(bounds[1]) + int(bounds[3])) / 4.0
	var delta: float = means[1] - means[0]
	var flags: Array[String] = []
	if absf(delta) >= 2.0:
		flags.append("Possible source row alignment drift: bottom-row visible-base mean differs by %.2f output pixels; no correction applied" % delta)
	return {"row_visible_bottom_mean_px": means, "row_visible_bottom_delta_px": delta, "qa_flags": flags, "measurement_limit": "visible-bounds heuristic, not a semantic root detector or animation-quality verdict"}


static func frame_durations(name: String) -> Array[int]:
	match name:
		"earth": return [18, 6, 18, 6, 18, 6, 18, 6]
		"charge": return [4, 4, 12, 12, 4, 4, 12, 12]
		"light": return [16, 12, 16, 12, 16, 12, 16, 12]
		"fire", "wind", "ice", "dark": return [8, 10, 8, 10, 8, 10, 8, 10]
		"water": return [10, 10, 10, 10, 10, 10, 10, 10]
	return []


static func source_region(size: Vector2i, index: int) -> Rect2i:
	var column := index % 4
	var row := index / 4
	var left := roundi(float(column) * size.x / 4.0)
	var right := roundi(float(column + 1) * size.x / 4.0)
	var top := roundi(float(row) * size.y / 2.0)
	var bottom := roundi(float(row + 1) * size.y / 2.0)
	return Rect2i(left, top, right - left, bottom - top)


static func output_region(index: int) -> Rect2i:
	return Rect2i((index % 4) * 32, (index / 4) * 32, 32, 32)


static func matte_matches(red: int, green: int, blue: int) -> bool:
	return red >= 170 and blue >= 170 and green <= 70 and absi(red - blue) <= 65


static func margin_is_background(image: Image, region: Rect2i, margin: int, mode: String) -> bool:
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			if x >= region.position.x + margin and x < region.end.x - margin and y >= region.position.y + margin and y < region.end.y - margin:
				continue
			var pixel := image.get_pixel(x, y)
			if mode == "native_alpha":
				if pixel.a8 != 0:
					return false
			elif pixel.a8 != 255 or not matte_matches(pixel.r8, pixel.g8, pixel.b8):
				return false
	return true


static func extract_background(image: Image, mode: String) -> Dictionary:
	var bytes := image.get_data()
	var count := image.get_width() * image.get_height()
	var dropped := 0
	var dropped_enclosed := 0
	var matched := 0
	var minimum := [255, 255, 255]
	var maximum := [0, 0, 0]
	if mode == "approved_magenta_family":
		var eligible := PackedByteArray()
		eligible.resize(count)
		for index: int in range(count):
			var offset := index * 4
			if matte_matches(bytes[offset], bytes[offset + 1], bytes[offset + 2]):
				eligible[index] = 1
				matched += 1
		var queue := PackedInt32Array([0])
		eligible[0] = 0
		var cursor := 0
		var width := image.get_width()
		var offsets := PackedInt32Array([-width, width, -1, 1])
		while cursor < queue.size():
			var index := queue[cursor]
			cursor += 1
			var offset := index * 4
			for channel: int in range(3):
				minimum[channel] = mini(minimum[channel], bytes[offset + channel])
				maximum[channel] = maxi(maximum[channel], bytes[offset + channel])
				bytes[offset + channel] = 0
			bytes[offset + 3] = 0
			dropped += 1
			var x := index % width
			for step: int in offsets:
				if (step == -1 and x == 0) or (step == 1 and x == width - 1):
					continue
				var neighbor := index + step
				if neighbor >= 0 and neighbor < count and eligible[neighbor] == 1:
					eligible[neighbor] = 0
					queue.append(neighbor)
		# Explicit approval: the eight material palettes exclude restricted
		# magenta, so enclosed flame/ribbon holes are matte too, not art pixels.
		for index: int in range(count):
			if eligible[index] != 1:
				continue
			var offset := index * 4
			for channel: int in range(3):
				minimum[channel] = mini(minimum[channel], bytes[offset + channel])
				maximum[channel] = maxi(maximum[channel], bytes[offset + channel])
				bytes[offset + channel] = 0
			bytes[offset + 3] = 0
			dropped_enclosed += 1
	else:
		for offset: int in range(0, bytes.size(), 4):
			if bytes[offset + 3] == 0:
				bytes[offset] = 0
				bytes[offset + 1] = 0
				bytes[offset + 2] = 0
	return {
		"image": Image.create_from_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, bytes),
		"alpha": {"removed_pixels": dropped + dropped_enclosed, "removed_edge_connected_pixels": dropped, "removed_enclosed_pixels": dropped_enclosed, "retained_matte_family_pixels": matched - dropped - dropped_enclosed, "removed_rgb_min": minimum if dropped > 0 else [], "removed_rgb_max": maximum if dropped > 0 else [], "matte_policy": MATTE_RULE if mode == "approved_magenta_family" else "existing_alpha_preserved; hidden_transparent_RGB_zeroed", "fringe_policy": "no fuzzy key or recolor beyond approved magenta family; other partial edges retained for visual QA"},
	}


static func alpha_summary(bytes: PackedByteArray) -> Dictionary:
	var result := {"minimum": 255, "maximum": 0, "transparent_pixels": 0, "partial_pixels": 0}
	for offset: int in range(3, bytes.size(), 4):
		var alpha: int = bytes[offset]
		result.minimum = mini(result.minimum, alpha)
		result.maximum = maxi(result.maximum, alpha)
		if alpha == 0:
			result.transparent_pixels += 1
		elif alpha < 255:
			result.partial_pixels += 1
	return result


static func validate_packed(image: Image) -> Dictionary:
	if image == null or image.get_size() != SIZE or image.get_format() != Image.FORMAT_RGBA8 or image.has_mipmaps():
		return failure("Packed output must be unmipped128x64 RGBA8")
	for index: int in range(8):
		var region := output_region(index)
		if not image.get_region(region).get_used_rect().has_area() or not margin_is_background(image, region, 1, "native_alpha"):
			return failure("Packed frame%d empty/clipped/missing transparent margin" % index)
	var bytes := image.get_data()
	for offset: int in range(0, bytes.size(), 4):
		if bytes[offset + 3] == 0 and (bytes[offset] != 0 or bytes[offset + 1] != 0 or bytes[offset + 2] != 0):
			return failure("Packed transparent RGB must be zero")
	return {"error": "", "alpha": alpha_summary(bytes)}


static func retained_assets() -> Dictionary:
	var path := ROOT.path_join("packed/manifest.json")
	var retained := {}
	if not FileAccess.file_exists(path):
		return retained
	var old: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not old is Dictionary or old.get("id") != ID or not old.get("assets") is Dictionary:
		return retained
	for name: String in NAMES:
		var record: Variant = old.assets.get(name)
		if not record is Dictionary or record.get("path") != "packed/" + name + ".png" or not record.get("source") is Dictionary:
			continue
		var source_path := ROOT.path_join("sources/" + name + ".png")
		var packed_path := ROOT.path_join("packed/" + name + ".png")
		if not FileAccess.file_exists(source_path) or not FileAccess.file_exists(packed_path):
			continue
		if FileAccess.get_sha256(source_path) != String(record.source.get("sha256", "")) or FileAccess.get_sha256(packed_path) != String(record.get("sha256", "")):
			continue
		retained[name] = record
	return retained


static func make_manifest(assets: Dictionary, requested: Array, missing_sources: Array) -> Dictionary:
	var built: Array[String] = []
	var missing: Array[String] = []
	for name: String in NAMES:
		if assets.has(name):
			built.append(name)
		else:
			missing.append(name)
	return {
		"schema_version": 1, "id": ID, "status": "isolated_material_studies_not_runtime_integrated",
		"runtime_integrated": false, "visual_accepted": false, "full_magic_kit": false,
		"all_studies_built": missing.is_empty(), "built_names": built, "missing_names": missing,
		"requested_names": requested, "source_missing_names": missing_sources, "assets": assets,
		"out_of_scope_names": OUT_OF_SCOPE_NAMES, "scope_stop_reason": "stopped_before_first_level_interactions",
		"tick_rate": 120, "cell": [32, 32], "pivot": [16, 26], "grid": [4, 2],
		"sampling": "nearest", "atlas_padding": "one transparent pixel INSIDE each32px cell; no live atlas gutter",
		"authority": "preview material art only; existing physics/coverage/phases and gameplay are unchanged",
	}


static func hash_bytes(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()


static func rect_values(rect: Rect2i) -> Array[int]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


static func write_bytes(path: String, bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	var error := file.get_error()
	file.close()
	return error == OK


static func failure(message: String) -> Dictionary:
	return {"error": message}


func _abort(message: String) -> void:
	print("FAIL: Magic studies import: " + message)
	quit(1)
