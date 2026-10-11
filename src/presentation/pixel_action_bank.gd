extends RefCounted
## Additive, reviewed whole-body keys. No pose synthesis, waist split or mesh.
## Subset coverage is explicit; unsupported identities/actions return fallback.
const PATH := "res://assets/sprites/pixel_actions_v1/"
const DIRECTIONS := ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
const ROWS := ["jumpsquat", "rise", "fall", "land"]
const HEIGHTS := {"small":58, "middle":63, "large":68}
const ACTION_ROWS := {"jumpsquat":0, "jump":1, "double_jump":1, "walljump":1,
	"slide_jump":1, "fall":2, "fast_fall":2, "land":3}
var entries: Dictionary = {}
var textures: Dictionary = {}
var last_error := ""
var bounded_residency := false
var page_load_count := 0


func configure(parent_entries: Dictionary) -> bool:
	if not FileAccess.file_exists(PATH+"manifest.json"): return _fail("Missing optional pixel action manifest")
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH+"manifest.json"))
	var error := manifest_error(value, parent_entries)
	if not error.is_empty(): return _fail(error)
	if bounded_residency:
		entries.clear(); textures.clear(); last_error = ""
		for entry: Dictionary in value.characters:
			var page := _load_page(entry)
			if page == null: return _fail(last_error)
			entries[entry.id] = entry.duplicate(true)
		return true
	var pages := {}
	for entry: Dictionary in value.characters:
		if not ResourceLoader.exists(PATH+String(entry.atlas)): return _fail("Missing optional pixel action atlas")
		pages[entry.atlas] = load(PATH+String(entry.atlas)) as Texture2D
	return admit(value, parent_entries, pages)


static func manifest_error(value: Variant, parent_entries: Dictionary) -> String:
	if not value is Dictionary or value.get("id") != "hex-pixel-actions-v1" or value.get("schema_version") != 1:
		return "Invalid pixel action identity/schema"
	if not _pair(value.get("cell"),128,128) or not _pair(value.get("pivot"),64,104) or value.get("directions") != DIRECTIONS or value.get("rows") != ROWS:
		return "Invalid pixel action geometry/direction/row contract"
	var characters: Variant = value.get("characters")
	if not characters is Array or characters.is_empty() or characters.size() > 64:
		return "Invalid pixel action roster capacity"
	var seen := {}
	var leaves := {}
	for entry: Variant in characters:
		if not entry is Dictionary: return "Invalid pixel action entry"
		var id: Variant = entry.get("id")
		if not id is String or not parent_entries.has(id) or seen.has(id): return "Pixel action identity mismatch"
		if entry.get("body") != parent_entries[id].get("body") or not HEIGHTS.has(entry.get("body")): return "Pixel action size mismatch"
		var leaf: Variant = entry.get("atlas")
		if not leaf is String or leaf.is_empty() or leaf != leaf.get_file() or ".." in leaf or ":" in leaf or "/" in leaf or "\\" in leaf or not leaf.ends_with(".png"):
			return "Unsafe pixel action atlas path"
		if leaves.has(leaf.to_lower()): return "Duplicate pixel action page"
		var digest: Variant = entry.get("rgba_sha256")
		if not digest is String or digest.length() != 64: return "Invalid pixel action digest"
		for character: String in digest:
			if character not in "0123456789abcdef": return "Invalid pixel action digest"
		seen[id] = true
		leaves[leaf.to_lower()] = true
	return ""


static func _pair(value: Variant, x: int, y: int) -> bool:
	# JSON decodes geometry as floats; require exact numeric values rather than
	# typed Array equality, while rejecting booleans/strings/fractional geometry.
	if not value is Array or value.size() != 2: return false
	for index: int in 2:
		if not value[index] is int and not value[index] is float: return false
		if not is_finite(float(value[index])) or float(value[index]) != float(x if index==0 else y): return false
	return true


func admit(value: Variant, parent_entries: Dictionary, pages: Dictionary) -> bool:
	entries.clear(); textures.clear(); last_error = ""
	var error := manifest_error(value, parent_entries)
	if not error.is_empty(): return _fail(error)
	var admitted := {}
	var loaded := {}
	for entry: Dictionary in value.characters:
		var texture := pages.get(entry.atlas) as Texture2D
		var page_error := _page_error(texture, entry)
		if not page_error.is_empty(): return _fail(page_error)
		admitted[entry.id] = entry.duplicate(true)
		loaded[entry.id] = texture
	entries = admitted; textures = loaded
	return true


static func _page_error(texture: Texture2D, entry: Dictionary) -> String:
	if texture == null or Vector2i(texture.get_size()) != Vector2i(1024,512): return "Pixel action atlas dimensions"
	var pixels := texture.get_image()
	if pixels == null: return "Unreadable pixel action page"
	if pixels.is_compressed() and pixels.decompress() != OK: return "Compressed pixel action page"
	pixels.convert(Image.FORMAT_RGBA8)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256); hash.update(pixels.get_data())
	if hash.finish().hex_encode() != entry.rgba_sha256: return "Pixel action pixels changed"
	for row: int in 4:
		for column: int in 8:
			if not pixels.get_region(Rect2i(column*128,row*128,128,128)).get_used_rect().has_area(): return "Empty required pixel action cell"
	return ""


func _load_page(entry: Dictionary) -> Texture2D:
	var page := ResourceLoader.load(PATH+String(entry.atlas), "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	page_load_count += 1
	last_error = _page_error(page, entry)
	return page if last_error.is_empty() else null


func prepare_character_pages(ids: Array[String]) -> bool:
	if not bounded_residency: return true
	if ids.size() > 15:
		last_error = "Pixel action residency capacity exceeded"
		return false
	var staged := {}
	for id: String in ids:
		# The optional action bank intentionally supports a subset of identities.
		if not entries.has(id): continue
		var page: Texture2D = textures.get(id)
		if page == null: page = _load_page(entries[id])
		if page == null: return false
		staged[id] = page
	textures = staged
	last_error = ""
	return true


func frame(id: String, action: String, aim: int, travel: int, phase: float, casting: bool) -> Dictionary:
	if not entries.has(id) or not textures.has(id) or not ACTION_ROWS.has(action) or aim < 0 or aim > 7 or travel < 0 or travel > 7 or not is_finite(phase): return {}
	var texture: Texture2D = textures[id]
	var row: int = ACTION_ROWS[action]
	return {"texture":texture, "pixel_body_pilot":true, "fullbody_art":true, "wireframe_body":false,
		"visual_mode":"pixel_cast", "body_type":entries[id].body, "pixel_action_key":true,
		"display_height":HEIGHTS[entries[id].body],
		"components":[{"texture":texture, "source_region":Rect2(aim*128,row*128,128,128), "destination_region":Rect2(0,0,128,128)}],
		"cell_size":Vector2(128,128), "pivot":Vector2(64,104), "offset":Vector2.ZERO, "squat_depth":0,
		"action":action, "aim_index":aim, "travel_index":travel, "motion_phase":phase,
		"art_pose_quality":"authored fixed-pixel jump key", "independent_cast_pose":false,
		"cast_overlay_requested":casting, "all_action_art_complete":false,
		"frame_id":"%s/action/%d/%d" % [id,aim,row]}


func _fail(error: String) -> bool:
	entries.clear(); textures.clear(); last_error=error
	return false
