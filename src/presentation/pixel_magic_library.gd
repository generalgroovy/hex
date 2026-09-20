class_name PixelMagicLibrary
extends RefCounted

# Presentation-only, immutable prepared frames. Authority chooses the effect,
# phase, occupied geometry and lifetime; a held last pose can never extend them.
const MANIFEST_PATH := "res://art_batches/pixel_v1/magic/manifest.json"
const PACK_ROOT := "res://art_batches/pixel_v1/magic"
const PAGE_PATHS := ["export/magic_00.png", "export/magic_01.png", "export/magic_02.png"]
const PAGE_SIZE := Vector2i(1024, 1024)
const DECODED_BYTES := 12_582_912
const ELEMENTS := ["earth", "fire", "water", "wind", "ice", "charge", "light", "dark"]
const EFFECTS := ["hand_prepare", "hand_release", "flight", "flight_tail", "impact", "deposit_formation", "deposit_active", "deposit_decay", "beam_body", "beam_start", "beam_end", "spray_grain", "burst_release", "field_tile"]
const MOVEMENT := ["air_dash_afterimage_mask", "float_budget_tick", "float_wing", "jump_takeoff", "landing_contact", "landing_dust", "protection_badge", "protection_corner", "slide_dust", "slide_trail", "walljump_burst", "wallrun_sparks"]
const GEOMETRY := ["boundary_formation", "boundary_active", "boundary_decay", "connected_node", "unconnected_node"]
const PHASES := ["formation", "active", "decay"]
const VARIANTS := ["normal", "reduced"]
const LAYERS := ["attack_cap", "attack_material", "caller_body_alpha_mask", "concealment_material", "essential_boundary", "essential_link_state", "essential_protection", "finite_deposit_material", "ground_material", "harmless_cast_detail", "harmless_movement", "harmless_trail", "projectile_core", "reaction_material", "terminal_contact"]
const SOURCE_PATHS := ["src/sim/chemistry/element_chemistry_system.gd", "content/reactions/first_eight_element_reactions_v1.json", "content/visual/visual_language_v1.json", "content/visual/foundation_spell_visuals_v1.json", "content/visual/spell_animation_skeletons_v1.json"]
const Chemistry = preload("res://src/sim/chemistry/element_chemistry_system.gd")

static var _shared: PixelMagicLibrary
var last_error := ""
var content_hash := ""
var source_hash_differences: Array[String] = []
var _assets: Dictionary = {}
var _reactions: Dictionary = {}
var _textures: Dictionary = {}
var _empty: Dictionary = {}
var _decoration_limit := 192
var _decoration_used := 0
var _decoration_by_asset: Dictionary = {}


static func default_library() -> PixelMagicLibrary:
	if _shared == null:
		_shared = PixelMagicLibrary.new()
		_shared.load_from_file()
	return _shared


func _init() -> void:
	_empty.make_read_only()


func load_from_file(path: String = MANIFEST_PATH) -> bool:
	_clear()
	if not FileAccess.file_exists(path):
		return _fail("Magic manifest is missing: %s" % path)
	var source := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(source)
	if not parsed is Dictionary:
		return _fail("Magic manifest root must be an object")
	if not load_from_manifest(parsed, path.get_base_dir()):
		return false
	content_hash = source.sha256_text()
	return true


# Explicit data entry point supports fail-closed validation tests without
# creating/replacing any candidate manifest or image files.
func load_from_manifest(document: Dictionary, pack_root: String = PACK_ROOT) -> bool:
	_clear()
	if not validate_manifest(document):
		return false
	var pages: Dictionary = {}
	for page: Dictionary in document["atlases"]:
		var relative := String(page["path"])
		var full_path := pack_root.path_join(relative)
		if not FileAccess.file_exists(full_path) or FileAccess.get_sha256(full_path) != String(page["sha256"]):
			return _fail("Magic raw PNG hash differs or source bytes are unavailable: %s" % relative)
		var bytes := FileAccess.get_file_as_bytes(full_path)
		if bytes.size() != int(page["png_bytes"]):
			return _fail("Magic PNG byte count differs: %s" % relative)
		var source_image := Image.new()
		if source_image.load_png_from_buffer(bytes) != OK or source_image.get_size() != PAGE_SIZE or source_image.get_format() != Image.FORMAT_RGBA8 or source_image.has_mipmaps():
			return _fail("Magic source PNG must be an unmipped RGBA8 1024px page: %s" % relative)
		if not ResourceLoader.exists(full_path, "Texture2D"):
			return _fail("Magic texture has not been imported: %s" % relative)
		var texture := ResourceLoader.load(full_path, "Texture2D") as Texture2D
		if texture == null or texture.get_size() != Vector2(PAGE_SIZE):
			return _fail("Magic imported texture dimensions differ: %s" % relative)
		var imported_image := texture.get_image()
		if imported_image == null or imported_image.has_mipmaps():
			return _fail("Magic imported texture cannot contain mipmaps: %s" % relative)
		if imported_image.is_compressed() and imported_image.decompress() != OK:
			return _fail("Magic imported texture pixels are unavailable: %s" % relative)
		imported_image.convert(Image.FORMAT_RGBA8)
		if imported_image.get_data() != source_image.get_data():
			return _fail("Magic imported pixels differ from the validated lossless PNG: %s" % relative)
		pages[relative] = texture
	# Source-file byte hashes are audit evidence, not a gameplay compatibility
	# gate: comments, source export remapping or unrelated refactors may differ.
	# The actual supported recipe geometry/timing was checked structurally above.
	for recorded: Dictionary in document["source_files"]:
		var source_path := "res://" + String(recorded["path"])
		if not FileAccess.file_exists(source_path) or FileAccess.get_sha256(source_path) != String(recorded["sha256"]):
			source_hash_differences.append(String(recorded["path"]))
	var prepared_assets: Dictionary = {}
	for authored: Dictionary in document["assets"]:
		var prepared := authored.duplicate(true)
		var frames: Array[Dictionary] = []
		var ends: Array[int] = []
		var elapsed := 0
		var texture: Texture2D = pages[String(authored["path"])]
		for frame: Dictionary in authored["frames"]:
			var rect: Array = frame["rect"]
			var pivot := Vector2(float(frame["pivot_px"][0]), float(frame["pivot_px"][1]))
			var size := Vector2(float(rect[2]), float(rect[3]))
			var sampled := {"texture": texture, "region": Rect2(float(rect[0]), float(rect[1]), size.x, size.y), "pivot": pivot, "size": size, "local_rect": Rect2(-pivot, size), "index": frames.size(), "duration_ticks": int(frame["duration_ticks"])}
			var uv_start := Vector2(float(rect[0]), float(rect[1])) / Vector2(PAGE_SIZE)
			var uv_end := (Vector2(float(rect[0]), float(rect[1])) + size) / Vector2(PAGE_SIZE)
			sampled["uvs"] = PackedVector2Array([uv_start, Vector2(uv_end.x, uv_start.y), uv_end, Vector2(uv_start.x, uv_end.y)])
			sampled.make_read_only()
			frames.append(sampled)
			elapsed += int(frame["duration_ticks"])
			ends.append(elapsed)
		frames.make_read_only()
		ends.make_read_only()
		prepared["sampled_frames"] = frames
		prepared["frame_ends"] = ends
		prepared["total_ticks"] = elapsed
		_freeze(prepared)
		prepared_assets[String(authored["id"])] = prepared
	var prepared_reactions: Dictionary = {}
	for authored: Dictionary in document["reactions"]:
		var prepared := authored.duplicate(true)
		_freeze(prepared)
		prepared_reactions[int(authored["wire_id"])] = prepared
	prepared_assets.make_read_only()
	prepared_reactions.make_read_only()
	pages.make_read_only()
	_assets = prepared_assets
	_reactions = prepared_reactions
	_textures = pages
	content_hash = JSON.stringify(document).sha256_text()
	return true


func asset(asset_id: String) -> Dictionary:
	return _assets.get(asset_id, _empty)


func reaction(wire_id: int) -> Dictionary:
	return _reactions.get(wire_id, _empty)


func asset_count() -> int:
	return _assets.size()


func page_count() -> int:
	return _textures.size()


# The owning canvas calls this exactly once before all world draw passes.
# Individual presenters must not reset the shared budget midway through a frame.
func begin_frame(reduced: bool = false) -> void:
	_decoration_limit = 96 if reduced else 192
	_decoration_used = 0
	_decoration_by_asset.clear()


func take_decoration(asset_id: String) -> bool:
	var metadata := asset(asset_id)
	if metadata.is_empty():
		return false
	var layer := String(metadata["layer_role"])
	if layer.begins_with("essential_") or layer == "projectile_core":
		return true # Essential geometry/core information can never be rationed.
	var count := int(_decoration_by_asset.get(asset_id, 0))
	if _decoration_used >= _decoration_limit or count >= int(metadata["intended_simultaneous_instance_budget"]):
		return false
	_decoration_by_asset[asset_id] = count + 1
	_decoration_used += 1
	return true


func decoration_remaining() -> int:
	return maxi(0, _decoration_limit - _decoration_used)


func decoration_stats() -> Dictionary:
	return {"used": _decoration_used, "limit": _decoration_limit}


func frame_index(asset_id: String, phase_age_ticks: int, authority_alive: bool = true) -> int:
	if not authority_alive or phase_age_ticks < 0 or not _assets.has(asset_id):
		return -1
	var prepared: Dictionary = _assets[asset_id]
	var ends: Array[int] = prepared["frame_ends"]
	var elapsed := phase_age_ticks
	var total := int(prepared["total_ticks"])
	if bool(prepared["loop"]):
		elapsed %= total
	elif elapsed >= total:
		return -1 if prepared["end_behavior"] == "hide" else ends.size() - 1
	for index: int in range(ends.size()):
		if elapsed < ends[index]:
			return index
	return -1


func sample(asset_id: String, phase_age_ticks: int, authority_alive: bool = true) -> Dictionary:
	var index := frame_index(asset_id, phase_age_ticks, authority_alive)
	return _empty if index < 0 else _assets[asset_id]["sampled_frames"][index]


func rotation_for(asset_id: String, requested_angle: float) -> float:
	return requested_angle if is_finite(requested_angle) and asset(asset_id).get("direction") == "east" else 0.0


# Call inside _draw. All vertices remain in caller coordinates: camera/zoom
# draw transforms, canvas position and modulation are never overwritten.
# Geometry clipping and body-only afterimage masking belong to the caller.
func draw_stamp(canvas: CanvasItem, asset_id: String, anchor: Vector2, phase_age_ticks: int, angle: float = 0.0, opacity: float = 1.0, scale: float = 1.0, authority_alive: bool = true) -> bool:
	if canvas == null or not anchor.is_finite() or not is_finite(opacity) or not is_finite(scale) or scale <= 0.0 or scale > 8.0 or opacity <= 0.0:
		return false
	var sampled := sample(asset_id, phase_age_ticks, authority_alive)
	if sampled.is_empty() or asset(asset_id).get("layer_role") == "caller_body_alpha_mask":
		return false # A stencil must never be drawn as replacement body pixels.
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tint := Color(1.0, 1.0, 1.0, clampf(opacity, 0.0, 1.0))
	var rotation := rotation_for(asset_id, angle)
	var pivot: Vector2 = sampled["pivot"]
	var size: Vector2 = sampled["size"]
	if is_zero_approx(rotation):
		canvas.draw_texture_rect_region(sampled["texture"], Rect2(anchor - pivot * scale, size * scale), sampled["region"], tint)
	else:
		var vertices := PackedVector2Array([
			anchor + (-pivot * scale).rotated(rotation),
			anchor + ((Vector2(size.x, 0.0) - pivot) * scale).rotated(rotation),
			anchor + ((size - pivot) * scale).rotated(rotation),
			anchor + ((Vector2(0.0, size.y) - pivot) * scale).rotated(rotation),
		])
		canvas.draw_polygon(vertices, PackedColorArray([tint]), sampled["uvs"], sampled["texture"])
	return true


static func element_asset_id(element_wire_id: int, effect: String, reduced: bool = false) -> String:
	if element_wire_id < 1 or element_wire_id > ELEMENTS.size() or effect not in EFFECTS:
		return ""
	return "magic.%s.%s.%s" % [ELEMENTS[element_wire_id - 1], effect, "reduced" if reduced else "normal"]


static func movement_asset_id(effect: String, reduced: bool = false) -> String:
	return "magic.movement.%s.%s" % [effect, "reduced" if reduced else "normal"] if effect in MOVEMENT else ""


func reaction_asset_id(wire_id: int, phase: String, reduced: bool = false) -> String:
	if not _reactions.has(wire_id) or phase not in PHASES:
		return ""
	return String(_reactions[wire_id]["phases"][phase]["reduced" if reduced else "normal"])


func validate_manifest(document: Dictionary) -> bool:
	last_error = ""
	if not _integer(document.get("schema_version"), 1, 1) or document.get("contract_id") != "flux-pixel-assets-v1" or document.get("namespace") != "magic":
		return _fail("Magic manifest identity is unsupported")
	var rules: Variant = document.get("import_rules")
	if not rules is Dictionary or rules.get("format") != "PNG RGBA8" or rules.get("filter") != "nearest" or rules.get("mipmaps") != false or rules.get("padding_px") != 2 or rules.get("logical_pixel_world_px") != 1:
		return _fail("Magic import rules must retain nearest, unmipped, untrimmed logical pixels")
	var pages: Variant = document.get("atlases")
	if not pages is Array or pages.size() != 3:
		return _fail("Magic registry requires exactly three atlas pages")
	for index: int in range(3):
		var page: Variant = pages[index]
		if not page is Dictionary or page.get("path") != PAGE_PATHS[index] or page.get("mode") != "RGBA" or not _integer(page.get("width"), 1024, 1024) or not _integer(page.get("height"), 1024, 1024) or not _integer(page.get("decoded_bytes"), 4_194_304, 4_194_304) or not _integer(page.get("png_bytes"), 1, 4_194_304) or not _sha256(page.get("sha256")):
			return _fail("Magic atlas path, dimensions, memory or hash metadata is invalid")
	var budgets: Variant = document.get("budgets")
	if not budgets is Dictionary or budgets.get("atlas_pages") != 3 or budgets.get("decoded_rgba_bytes") != DECODED_BYTES or budgets.get("normal_total_material_stamps") != 192 or budgets.get("reduced_total_material_stamps") != 96 or budgets.get("essential_boundaries_are_never_dropped") != true:
		return _fail("Magic prepared-page or decoration budget is invalid")
	var sources: Variant = document.get("source_files")
	if not sources is Array or sources.size() != SOURCE_PATHS.size():
		return _fail("Magic source audit must name the five known authority files")
	for index: int in range(SOURCE_PATHS.size()):
		if not sources[index] is Dictionary or sources[index].get("path") != SOURCE_PATHS[index] or not _sha256(sources[index].get("sha256")):
			return _fail("Magic source audit path/hash is invalid")
	var raw_assets: Variant = document.get("assets")
	if not raw_assets is Array or raw_assets.size() != 474:
		return _fail("Magic manifest requires all 474 normal/reduced sequences")
	var by_id: Dictionary = {}
	for entry: Variant in raw_assets:
		if not entry is Dictionary or not _validate_asset(entry):
			return _fail(last_error if not last_error.is_empty() else "Magic asset must be an object")
		var asset_id := String(entry["id"])
		if by_id.has(asset_id):
			return _fail("Magic asset IDs must be unique")
		by_id[asset_id] = entry
	for variant: String in VARIANTS:
		for element: String in ELEMENTS:
			for effect: String in EFFECTS:
				if not by_id.has("magic.%s.%s.%s" % [element, effect, variant]):
					return _fail("Magic element/effect coverage is incomplete")
		for effect: String in MOVEMENT:
			if not by_id.has("magic.movement.%s.%s" % [effect, variant]):
				return _fail("Magic movement coverage is incomplete")
		for effect: String in GEOMETRY:
			if not by_id.has("magic.geometry.%s.%s" % [effect, variant]):
				return _fail("Magic essential geometry coverage is incomplete")
	return _validate_reactions(document, by_id)


func _validate_asset(entry: Dictionary) -> bool:
	var asset_id: Variant = entry.get("id")
	if not asset_id is String or not asset_id.begins_with("magic.") or asset_id.length() > 120 or "/" in asset_id or "\\" in asset_id or ".." in asset_id or entry.get("variant") not in VARIANTS or not asset_id.ends_with("." + String(entry["variant"])):
		return _fail("Magic asset ID/variant is invalid")
	if entry.get("path") not in PAGE_PATHS or entry.get("source_path") != "source/frames/%s.json" % asset_id or not _sha256(entry.get("source_sha256")):
		return _fail("Magic asset paths or source hash are invalid")
	if entry.get("texture_filter") != "nearest" or entry.get("mipmaps") != false or entry.get("atlas_padding_px") != 2 or entry.get("duration_tick_rate") != 120 or typeof(entry.get("loop")) != TYPE_BOOL or entry.get("end_behavior") not in ["hide", "hold_until_authority_phase_end"] or entry.get("direction") not in ["east", "billboard"]:
		return _fail("Magic asset sampling/timing contract is invalid")
	if entry.get("lifecycle_phase") not in ["formation", "active", "decay", "release", "impact", "takeoff", "landing"] or entry.get("layer_role") not in LAYERS or not _integer(entry.get("intended_simultaneous_instance_budget"), 1, 192) or not entry.get("geometry_scaling_rules") is String or String(entry["geometry_scaling_rules"]).is_empty():
		return _fail("Magic phase, layer or composition budget is invalid")
	var attachment: Variant = entry.get("attachment")
	if not attachment is Dictionary or attachment.get("pivot_stable_all_frames") != true or not attachment.get("anchor") is String or String(attachment["anchor"]).is_empty() or entry.get("phase_interrupt_policy") != "authority_first; cancel_sequence_immediately_on_state_change":
		return _fail("Magic attachment must preserve authority-first stable pivots")
	var size: Variant = entry.get("frame_size_px")
	var pivot: Variant = entry.get("pivot_px")
	if not _integer_array(size, 2, 1, 128) or not _integer_array(pivot, 2, 0, 128) or pivot[0] > size[0] or pivot[1] > size[1]:
		return _fail("Magic cell or pivot lies outside its finite logical frame")
	var frames: Variant = entry.get("frames")
	if not frames is Array or frames.is_empty() or frames.size() > 16:
		return _fail("Magic animation requires 1..16 frames")
	for frame: Variant in frames:
		if not frame is Dictionary or not _integer(frame.get("duration_ticks"), 1, 7200) or frame.get("pivot_px") != pivot:
			return _fail("Magic frame requires positive integer duration and unchanged pivot")
		var rect: Variant = frame.get("rect")
		if not _integer_array(rect, 4, 0, 1024) or rect[0] < 2 or rect[1] < 2 or rect[2] != size[0] or rect[3] != size[1] or rect[0] + rect[2] + 2 > 1024 or rect[1] + rect[3] + 2 > 1024:
			return _fail("Magic frame rectangle must retain its size and two-pixel atlas gutter")
	return true


func _validate_reactions(document: Dictionary, by_id: Dictionary) -> bool:
	var lifetimes: Variant = document.get("deposit_lifetime_ticks")
	if not lifetimes is Dictionary or lifetimes.size() != 8:
		return _fail("Magic deposit lifetimes are incomplete")
	for index: int in range(ELEMENTS.size()):
		var ticks := int(ceili(float(Chemistry.ELEMENT_LIFE_MS[index + 1]) * 120.0 / 1000.0))
		if not _integer(lifetimes.get(ELEMENTS[index]), ticks, ticks):
			return _fail("Magic deposit lifetime is incompatible with current authority")
	var reactions: Variant = document.get("reactions")
	if not reactions is Array or reactions.size() != 36:
		return _fail("Magic reaction coverage requires 36 stable identities")
	for index: int in range(36):
		var entry: Variant = reactions[index]
		var actual := Chemistry.recipe(301 + index)
		if not entry is Dictionary or entry.get("wire_id") != 301 + index or entry.get("id") != actual["id"] or entry.get("shape") != actual["shape"] or entry.get("elements") != [ELEMENTS[int(actual["elements"][0]) - 1], ELEMENTS[int(actual["elements"][1]) - 1]]:
			return _fail("Magic reaction identity or shape is incompatible with current authority")
		for field: String in ["formation_ms", "active_ms", "decay_ms", "pulse_ms"]:
			if not _integer(entry.get(field), int(actual[field]), int(actual[field])):
				return _fail("Magic reaction timing is incompatible with current authority")
		for phase: String in PHASES:
			var duration := int(ceili(float(actual[phase + "_ms"]) * 120.0 / 1000.0))
			if not _integer(entry.get(phase + "_ticks"), duration, duration):
				return _fail("Magic reaction ticks must use ceiling-rounded 120Hz phase durations")
		for key: String in ["nominal_radius_px", "nominal_length_px", "speed_px_per_second", "cover_health"]:
			var source_key: String = {"nominal_radius_px": "radius", "nominal_length_px": "length", "speed_px_per_second": "speed", "cover_health": "health"}[key]
			var value: Variant = entry.get(key)
			if not _number(value) or float(value) * 1000.0 != float(actual[source_key]):
				return _fail("Magic nominal geometry is incompatible with current authority")
		for key: String in ["phases", "essential_boundary"]:
			var bindings: Variant = entry.get(key)
			if not bindings is Dictionary or bindings.size() != 3:
				return _fail("Magic reaction phases and essential boundaries must be complete")
			for phase: String in PHASES:
				if not bindings.get(phase) is Dictionary or bindings[phase].size() != 2:
					return _fail("Magic reaction phase requires both accessibility variants")
				for variant: String in VARIANTS:
					var expected := "magic.reaction.%s.%s.%s" % [actual["id"], phase, variant] if key == "phases" else "magic.geometry.boundary_%s.%s" % [phase, variant]
					if bindings[phase].get(variant) != expected or not by_id.has(expected) or by_id[expected]["lifecycle_phase"] != phase:
						return _fail("Magic phase binding must refer to its exact prepared lifecycle sequence")
	return true


static func _number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value) and float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= maximum


static func _integer_array(value: Variant, count: int, minimum: int, maximum: int) -> bool:
	if not value is Array or value.size() != count:
		return false
	for item: Variant in value:
		if not _integer(item, minimum, maximum):
			return false
	return true


static func _sha256(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for index: int in range(value.length()):
		if value[index] not in "0123456789abcdef":
			return false
	return true


static func _freeze(value: Variant) -> void:
	if value is Dictionary:
		for child: Variant in value.values():
			_freeze(child)
		if not value.is_read_only():
			value.make_read_only()
	elif value is Array:
		for child: Variant in value:
			_freeze(child)
		if not value.is_read_only():
			value.make_read_only()


func _clear() -> void:
	last_error = ""
	content_hash = ""
	source_hash_differences.clear()
	_assets = {}
	_reactions = {}
	_textures = {}


func _fail(message: String) -> bool:
	last_error = message
	return false
