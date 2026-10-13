class_name CartoonChampionPresenter
extends RefCounted


const DEFAULT_PATH := "res://content/visual/foundation_champion_visuals_v1.json"
const PixelMovement = preload("res://src/presentation/pixel_movement_effects.gd")
const WallPose = preload("res://src/presentation/pixel_wallrun_pose.gd")
const GroundSkid = preload("res://src/presentation/ground_skid_presentation.gd")
const WireframeBody = preload("res://src/presentation/wireframe_body_presenter.gd")
const FullbodyCast = preload("res://src/presentation/fullbody_cast_presenter.gd")
const EXPECTED_ID := "foundation-champion-visuals-v15-motion-facing"
const EXPECTED_AUTHORITY := "presentation only; hitboxes, movement, casts and outcomes remain authoritative elsewhere"
const REQUIRED_FOUNDATION := ["oh_tipi", "s_wayne", "red_baron"]
const ATLAS_PATH := "res://assets/sprites/champions_v3/foundation/runtime_atlas_eight_v15.png"
const PROPORTION_REFERENCE_PATH := "res://assets/concept/foundation-proportion-reference-small-to-large-v3.png"
const EXPECTED_BODY_TYPES: Array[String] = ["small", "middle", "large"]
const EXPECTED_CARDINAL_DIRECTIONS: Array[String] = ["south", "east", "north", "west"]
const EXPECTED_DIRECTIONS: Array[String] = [
	"south", "south_east", "east", "north_east",
	"north", "north_west", "west", "south_west",
]
const EXPECTED_DIAGONAL_DIRECTIONS: Array[String] = ["south_east", "north_east", "north_west", "south_west"]
const EXPECTED_DIAGONAL_CORE_STATES: Array[String] = ["grounded", "cast", "hit"]
const EXPECTED_DIAGONAL_LOCOMOTION_STATES: Array[String] = ["walk", "sprint"]
const EXPECTED_DIAGONAL_STATES: Array[String] = ["grounded", "jump", "cast", "hit", "walk", "sprint", "slide", "roll", "walk_b", "sprint_b"]
const EXPECTED_RELATIVE_GAITS: Array[String] = ["idle", "forward", "backward", "strafe_left", "strafe_right"]
const EXPECTED_DIAGONAL_EVASION_STATES: Array[String] = ["jump", "slide", "roll"]
const EXPECTED_CARDINAL_STATES: Array[String] = ["grounded", "jump", "cast", "hit", "walk", "sprint", "slide", "roll"]
const EXPECTED_ATLAS_STATES: Array[String] = ["grounded", "jump", "cast", "hit", "walk", "sprint", "slide", "roll", "walk_b", "sprint_b"]
const EXPECTED_PHASE_STATES: Array[String] = ["walk", "sprint"]
const EXPECTED_SEMANTIC_ACTIONS: Array[String] = [
	"idle", "walk", "sprint", "jump", "double_jump", "slide", "slide_jump", "air_dodge",
	"wave_dash", "wall_kick", "vault", "superglide", "launched", "grappled", "charging",
	"stunned", "rooted", "slowed", "fast_fall", "wall_skim", "impact_recovery", "roll",
	"cast", "cast_recovery", "attack_primary", "defend", "interact", "taunt", "defeated",
]
const EXPECTED_EXCLUDED_LAYERS: Array[String] = ["spell", "element", "projectile", "aura", "shadow", "environment", "equipment", "focus"]
const CELL_SIZE := Vector2(96.0, 96.0)
const PIVOT := Vector2(48.0, 84.0)
const BODY_TYPE_RENDER_SCALE := {
	"small": 1.00,
	"middle": 1.00,
	"large": 1.00,
}
const HAND_CAST_HEIGHT := 27.0
const HAND_CAST_FORWARD := 4.0
const HAND_CAST_SIDE := 7.0
const LIVE_CATALOG_PATH := "res://content/champions/foundation_champions_v1.json"
const MAX_LIVE_RECIPES := 64
const DEFAULT_OVERRIDE_PATH := "res://content/visual/champion_page_overrides_v1.json"
const OVERRIDE_ID := "champion-complete-page-overrides-v1"
const MAX_RESIDENT_OVERRIDE_PAGES := 8
const OVERRIDE_DIMENSIONS := Vector2i(768, 960)
const PORTRAIT_SIZE := Vector2i(32, 32)

var language: VisualLanguage
var champions: Dictionary = {}
var content_hash := ""
var atlas_hash := ""
var last_error := ""
var atlas: Texture2D
var motion: MinimalChampionMotion
var cardinal_animation_contract: Dictionary = {}
var diagonal_core_contract: Dictionary = {}
var diagonal_locomotion_contract: Dictionary = {}
var diagonal_evasion_contract: Dictionary = {}
var locomotion_phase_contract: Dictionary = {}
var atlas_directions: Array = []
var extension_atlases: Dictionary[String, Texture2D] = {}
var extension_page_capacity: int = 0
var atlas_states: Array = []
var semantic_state_aliases: Dictionary = {}
var body_templates: Dictionary = {}
var shared_style_contract: Dictionary = {}
var pixel_movement := PixelMovement.new()
var override_page_ids: Array[String] = []
var _override_pages: Dictionary = {}
var _override_textures: Dictionary[String, Texture2D] = {}
var _inspection_texture: Texture2D
var _inspection_champion_id := ""
var _override_portraits: Dictionary = {}
var _baseline_portraits: Dictionary = {}
var _baseline_identity_pages: Dictionary = {}
var configuration_generation: int = 0
var wireframe_mode: bool = true
var wireframe_body := WireframeBody.new()
var _wireframe_portraits: Dictionary = {}
var fullbody_art: RefCounted


func enable_fullbody_art(use_pixel_pilot: bool = false, use_full_cast: bool = false, bounded_residency: bool = false) -> bool:
	var candidate := FullbodyCast.new()
	if not candidate.configure(champions.keys(), bounded_residency):
		last_error = candidate.last_error
		return false
	if (use_pixel_pilot or use_full_cast) and not candidate.enable_pixel_pilot(champions.keys(), use_full_cast):
		last_error = candidate.last_error
		return false
	fullbody_art = candidate
	if bounded_residency:
		# Fullbody owns every admitted identity and its explicit same-identity
		# action fallback. Tiny Fullbody portraits are already independently built.
		# Wireframe is only sampled when fullbody_art == null; release its pages.
		wireframe_body.clear()
		_wireframe_portraits.clear()
	configuration_generation += 1
	return true


func configure_fullbody_startup(visual_language: VisualLanguage, use_pixel_pilot: bool = false, use_full_cast: bool = false, path: String = DEFAULT_PATH) -> bool:
	# This explicit startup route is chosen only after Fullbody flags are known.
	# Validate an unpublished candidate, so a late Fullbody/page rejection cannot
	# revoke a working eager fallback or an already prepared active identity.
	var candidate: CartoonChampionPresenter = get_script().new()
	if not candidate._configure_validated(visual_language, path, true):
		last_error = candidate.last_error
		return false
	if not candidate.enable_fullbody_art(use_pixel_pilot, use_full_cast, true):
		last_error = candidate.last_error
		return false
	candidate.atlas_hash = FileAccess.get_sha256(FullbodyCast.PATH + "manifest.json")
	var art_identity := candidate.atlas_hash
	if candidate.fullbody_art.pixel_pilot != null:
		art_identity += JSON.stringify(candidate.fullbody_art.pixel_pilot.entries)
		if candidate.fullbody_art.pixel_pilot.action_bank != null:
			art_identity += JSON.stringify(candidate.fullbody_art.pixel_pilot.action_bank.entries)
	candidate.content_hash = (candidate.content_hash + art_identity).sha256_text()
	var next_generation := configuration_generation + 1
	# Startup only: transfer owned references after every validation has passed.
	# Reflection here avoids a second manually maintained list of presenter fields;
	# frame sampling and active-page preparation do not use this path.
	for property: Dictionary in candidate.get_property_list():
		if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			set(property.name, candidate.get(property.name))
	configuration_generation = next_generation
	last_error = ""
	return true


func configure(visual_language: VisualLanguage, path: String = DEFAULT_PATH, override_path: String = DEFAULT_OVERRIDE_PATH, use_wireframe: bool = true) -> bool:
	configuration_generation += 1
	fullbody_art = null
	wireframe_mode = use_wireframe
	wireframe_body.clear()
	_wireframe_portraits.clear()
	if _configure_validated(visual_language, path) and (wireframe_mode or _configure_overrides(override_path)):
		return true
	# A rejected reload may not expose a half-validated page set to callers.
	champions.clear()
	extension_atlases.clear()
	extension_page_capacity = 0
	atlas = null
	atlas_hash = ""
	content_hash = ""
	_clear_overrides()
	_baseline_identity_pages.clear()
	_baseline_portraits.clear()
	wireframe_body.clear()
	_wireframe_portraits.clear()
	return false


func _configure_validated(visual_language: VisualLanguage, path: String, metadata_only: bool = false) -> bool:
	language = visual_language
	champions.clear()
	content_hash = ""
	atlas_hash = ""
	last_error = ""
	atlas = null
	cardinal_animation_contract.clear()
	diagonal_core_contract.clear()
	diagonal_locomotion_contract.clear()
	diagonal_evasion_contract.clear()
	locomotion_phase_contract.clear()
	atlas_directions.clear()
	extension_atlases.clear()
	extension_page_capacity = 0
	atlas_states.clear()
	semantic_state_aliases.clear()
	body_templates.clear()
	shared_style_contract.clear()
	_clear_overrides()
	_baseline_identity_pages.clear()
	_baseline_portraits.clear()
	motion = MinimalChampionMotion.new()
	if not motion.load_from_file():
		return _fail(motion.last_error)
	if language == null or language.ramps.is_empty():
		return _fail("Cartoon champions require the validated visual language")
	if not FileAccess.file_exists(path):
		return _fail("Cartoon champion recipes do not exist: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("Cartoon champion recipes cannot be opened")
	var source := file.get_as_text()
	var parsed: Variant = JSON.parse_string(source)
	if not parsed is Dictionary:
		return _fail("Cartoon champion recipe root must be an object")
	var data: Dictionary = parsed
	if int(data.get("schema_version", -1)) != 15 or String(data.get("id", "")) != EXPECTED_ID:
		return _fail("Cartoon champion recipe identity is unsupported")
	var art_camera: Dictionary = data.get("art_camera", {})
	if int(art_camera.get("elevation_degrees", 0)) != 55 or String(art_camera.get("ground_axes", "")) != "screen_cardinal":
		return _fail("Champion camera must agree with cardinal campus art")
	if String(data.get("authority", "")) != EXPECTED_AUTHORITY:
		return _fail("Cartoon champion recipes must remain presentation-only")
	if String(data.get("atlas_role", "")) != "body_and_clothing_only":
		return _fail("Cartoon champion atlas must contain body and clothing only")
	if String(data.get("front_pose", "")) != "camera_facing_symmetrical":
		return _fail("Cartoon champion front pose must face the camera symmetrically")
	if String(data.get("direction_policy", "")) != "south_front_camera_facing; south_east_front_three_quarter; east_profile; north_east_back_three_quarter; north_centered_back; north_west_back_three_quarter; west_profile; south_west_front_three_quarter":
		return _fail("Cartoon champion direction policy is unsupported")
	if data.get("excluded_layers", []) != EXPECTED_EXCLUDED_LAYERS:
		return _fail("Cartoon champion excluded-layer contract is invalid")
	if _vector2i(data.get("cell", [])) != Vector2i(96, 96) or _vector2i(data.get("pivot", [])) != Vector2i(48, 84):
		return _fail("Cartoon champion cell/pivot differs from the visual contract")
	if not _validate_body_template_contract(data.get("body_template_contract", {})):
		return false
	if not _validate_shared_style_contract(data.get("shared_style_contract", {})):
		return false
	var atlas_definition: Dictionary = data.get("atlas", {})
	if String(atlas_definition.get("path", "")) != ATLAS_PATH \
		or _vector2i(atlas_definition.get("dimensions", [])) != Vector2i(768, 2880) \
		or atlas_definition.get("champions", []) != REQUIRED_FOUNDATION \
		or atlas_definition.get("directions", []) != EXPECTED_DIRECTIONS \
		or atlas_definition.get("states", []) != EXPECTED_ATLAS_STATES \
		or String(atlas_definition.get("row_layout", "")) != "champion_major_state_minor":
		return _fail("Foundation cartoon atlas layout is unsupported")
	if not _validate_cardinal_animation_contract(data.get("cardinal_animation_contract", {})):
		return false
	if not _validate_diagonal_core_contract(data.get("diagonal_core_contract", {})):
		return false
	if not _validate_diagonal_locomotion_contract(data.get("diagonal_locomotion_contract", {})):
		return false
	if not _validate_diagonal_evasion_contract(data.get("diagonal_evasion_contract", {})):
		return false
	if not _validate_locomotion_phase_contract(data.get("locomotion_phase_contract", {})):
		return false
	if not _validate_semantic_state_aliases(data.get("semantic_state_aliases", {})):
		return false
	atlas_directions = (atlas_definition.get("directions", []) as Array).duplicate()
	atlas_states = (atlas_definition.get("states", []) as Array).duplicate()
	var expected_hash := String(atlas_definition.get("sha256", ""))
	var expected_rgba_hash := String(atlas_definition.get("imported_rgba_sha256", ""))
	if expected_hash.length() != 64 or expected_rgba_hash.length() != 64:
		return _fail("Foundation cartoon atlas hashes are invalid")
	if OS.has_feature("editor") and FileAccess.file_exists(ATLAS_PATH) and expected_hash != _sha256(ATLAS_PATH):
		return _fail("Foundation cartoon source atlas hash is invalid")
	atlas_hash = expected_hash
	champions = data.get("champions", {})
	for champion_id: String in REQUIRED_FOUNDATION:
		if not champions.has(champion_id) or not _validate_recipe(champion_id, champions[champion_id]):
			champions.clear()
			return false
	# Additional champions get bounded per-character pages instead of growing a
	# single texture beyond device limits. Base three-template IDs stay stable.
	var live_source := FileAccess.get_file_as_string(LIVE_CATALOG_PATH)
	var live_data: Variant = JSON.parse_string(live_source)
	if not live_data is Dictionary or not (live_data as Dictionary).get("champions", null) is Array:
		return _fail("Character art requires the live identity catalog")
	var live_entries: Array = (live_data as Dictionary)["champions"]
	var extension_data: Variant = data.get("extension_atlases", {})
	if not _validate_extension_registry(extension_data, live_entries):
		champions.clear()
		return false
	var extensions: Dictionary = extension_data
	if wireframe_mode:
		# Validated identity/body metadata stays intact. Shared size bodies
		# replace only presentation; old character pages stay available for audits.
		for champion_id: String in champions:
			if not _validate_recipe(champion_id, champions[champion_id]):
				return false
		if not _register_temporary_templates(live_entries):
			return false
		if metadata_only:
			# Fullbody admission follows on the unpublished startup candidate. The
			# unused wireframe atlases and their three portraits are never loaded.
			content_hash = (source + live_source).sha256_text()
			return true
		if not wireframe_body.configure():
			return _fail(wireframe_body.last_error)
		for body_type: String in EXPECTED_BODY_TYPES:
			var pixels := wireframe_body.base_texture(body_type).get_image()
			_wireframe_portraits[body_type] = _build_portrait(pixels, Rect2i(0, 0, 96, 96))
			if (_wireframe_portraits[body_type] as Dictionary).is_empty():
				return _fail("Wireframe size lacks a South portrait: " + body_type)
		atlas_hash = wireframe_body.content_hash
		content_hash = (source + live_source + wireframe_body.content_hash).sha256_text()
		return true
	for champion_id: String in champions:
		if champion_id in REQUIRED_FOUNDATION:
			continue
		if not _validate_recipe(champion_id, champions[champion_id]) or not extensions.has(champion_id):
			return _fail("Additional champion lacks a validated recipe/page: " + champion_id)
		if not extensions[champion_id] is Dictionary:
			return _fail("Additional champion page must be an object")
		var page: Dictionary = extensions[champion_id]
		var page_path := String(page.get("path", ""))
		if not page_path.begins_with("res://assets/sprites/champions_v3/") or not ResourceLoader.exists(page_path):
			return _fail("Additional champion page path is invalid: " + champion_id)
		if OS.has_feature("editor") and FileAccess.get_sha256(page_path) != String(page.get("sha256", "")):
			return _fail("Additional champion page source hash changed: " + champion_id)
		var texture := load(page_path) as Texture2D
		if texture == null or texture.get_size() != Vector2(768, 960):
			return _fail("Additional champion page must contain ten eight-direction rows")
		var decoded_page := texture.get_image()
		if decoded_page == null or decoded_page.is_empty():
			return _fail("Additional champion decoded page is unavailable: " + champion_id)
		decoded_page.convert(Image.FORMAT_RGBA8)
		if _bytes_sha256(decoded_page.get_data()) != String(page.get("imported_rgba_sha256", "")):
			return _fail("Additional champion decoded page hash changed: " + champion_id)
		extension_atlases[champion_id] = texture
		_baseline_identity_pages[champion_id] = {
			"path": page_path, "sha256": String(page["sha256"]),
			"imported_rgba_sha256": String(page["imported_rgba_sha256"]),
		}
		_baseline_portraits[champion_id] = _build_portrait(decoded_page, Rect2i(0, 0, 96, 96))
	var atlas_resource: Resource = load(ATLAS_PATH)
	if not atlas_resource is Texture2D:
		champions.clear()
		return _fail("Foundation cartoon atlas cannot be loaded")
	atlas = atlas_resource
	if atlas.get_size() != Vector2(768.0, 2880.0):
		atlas = null
		champions.clear()
		return _fail("Foundation cartoon atlas dimensions are invalid")
	var decoded := atlas.get_image()
	if decoded == null or decoded.is_empty() or decoded.get_format() != Image.FORMAT_RGBA8 \
		or _bytes_sha256(decoded.get_data()) != expected_rgba_hash:
		atlas = null
		champions.clear()
		return _fail("Foundation cartoon decoded atlas hash is invalid")
	# Hash each already-verified foundation identity once. Only short digests
	# survive configuration; no cropped images/textures are retained or drawn.
	# This catches renamed/recompressed crops even though their PNG hash changes.
	for index: int in REQUIRED_FOUNDATION.size():
		var foundation_pixels := decoded.get_region(Rect2i(0, index * OVERRIDE_DIMENSIONS.y, OVERRIDE_DIMENSIONS.x, OVERRIDE_DIMENSIONS.y))
		_baseline_identity_pages[REQUIRED_FOUNDATION[index]] = {
			"imported_rgba_sha256": _bytes_sha256(foundation_pixels.get_data()),
		}
		_baseline_portraits[REQUIRED_FOUNDATION[index]] = _build_portrait(decoded, Rect2i(0, index * OVERRIDE_DIMENSIONS.y, 96, 96))
	# Playtest-only aliases reuse the exact body atlas and motion profile. They do
	# not manufacture race art, duplicate textures, or alter authoritative stats.
	if not _register_temporary_templates(live_entries):
		return false
	for champion_id: String in champions:
		var source_id := String(champions[champion_id].get("template_source_id", ""))
		if not source_id.is_empty():
			_baseline_portraits[champion_id] = _baseline_portraits[source_id]
	content_hash = (source + live_source).sha256_text()
	return true


func _clear_overrides() -> void:
	_inspection_texture = null
	_inspection_champion_id = ""
	override_page_ids.clear()
	_override_pages.clear()
	_override_textures.clear()
	_override_portraits.clear()


func _configure_overrides(path: String) -> bool:
	# An absent optional registry retains the working v15 pages. A present but
	# invalid registry is never silently treated as absent or partially applied.
	if path.is_empty() or (path == DEFAULT_OVERRIDE_PATH and not FileAccess.file_exists(path)):
		return true
	if not FileAccess.file_exists(path):
		return _fail("Complete champion page registry does not exist: " + path)
	var source := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(source)
	if not _validate_override_manifest(parsed):
		return false
	var pages: Dictionary = parsed["pages"]
	var portraits: Dictionary = {}
	# Validate every registered page once, releasing the uncached full texture
	# after its small portrait is extracted. No full-page GPU cache is populated.
	for champion_id: String in pages:
		var texture := _load_verified_override(champion_id, pages[champion_id])
		if texture == null:
			return false
		var pixels := texture.get_image()
		portraits[champion_id] = _build_portrait(pixels, Rect2i(0, 0, 96, 96))
	_override_pages = pages.duplicate(true)
	_override_portraits = portraits
	for champion_id: String in pages:
		override_page_ids.append(champion_id)
	override_page_ids.sort()
	content_hash = (content_hash + source).sha256_text()
	return true


func _validate_override_manifest(value: Variant) -> bool:
	if not value is Dictionary:
		return _fail("Complete champion page registry must be an object")
	var data: Dictionary = value
	if data.get("schema_version") != 1 or data.get("id") != OVERRIDE_ID \
		or data.get("authority") != EXPECTED_AUTHORITY \
		or not _exact_numeric_array(data.get("cell"), [96, 96]) or not _exact_numeric_array(data.get("pivot"), [48, 84]) \
		or not _exact_numeric_array(data.get("dimensions"), [768, 960]) or not _exact_numeric_array(data.get("runtime_scale"), [1, 1]) \
		or data.get("directions") != EXPECTED_DIRECTIONS or data.get("states") != EXPECTED_ATLAS_STATES \
		or data.get("frame_count") != 80 or data.get("row_layout") != "state_major_direction_minor" \
		or data.get("timing") != "existing_minimal_champion_motion" \
		or data.get("sampling") != "nearest_no_mipmaps" or data.get("atlas_role") != "body_and_clothing_only":
		return _fail("Complete champion page registry geometry, timing or authority is unsupported")
	if not data.get("pages") is Dictionary or data["pages"].size() > champions.size():
		return _fail("Complete champion pages exceed the validated live roster")
	var paths: Dictionary = {}
	var source_hashes: Dictionary = {}
	var pixel_hashes: Dictionary = {}
	for key: Variant in data["pages"]:
		if not key is String or not champions.has(key) or not data["pages"][key] is Dictionary:
			return _fail("Complete champion page requires an existing live identity and recipe")
		var page: Dictionary = data["pages"][key]
		if page.get("body_type") != champions[key]["body_type"] or page.get("reference_height") != champions[key]["height"] \
			or page.get("status") != "reviewed_complete_runtime_page":
			return _fail("Complete champion page body registration or approval is invalid: " + key)
		var feet: Variant = page.get("visible_feet_y")
		if not (feet is int or feet is float) or (float(feet) != 83.0 and float(feet) != 84.0):
			return _fail("Complete champion page must declare one exact visible feet baseline: " + key)
		var path := String(page.get("path", ""))
		if not path.begins_with("res://assets/sprites/champions_v3/") or not path.ends_with(".png") \
			or path.simplify_path() != path or "\\" in path or paths.has(path.to_lower()):
			return _fail("Complete champion pages require distinct contained PNG paths: " + key)
		for field: String in ["sha256", "imported_rgba_sha256"]:
			var digest := String(page.get(field, ""))
			if digest.length() != 64 or not digest.is_valid_hex_number(false) or digest != digest.to_lower():
				return _fail("Complete champion page hash is invalid: " + key)
		if _duplicates_other_baseline_identity(key, page):
			return _fail("Complete champion page duplicates another baseline identity: " + key)
		# Renaming the same file (or recompressing the same pixels) must not
		# turn a body-template alias into a supposedly unique accepted identity.
		if source_hashes.has(page["sha256"]) or pixel_hashes.has(page["imported_rgba_sha256"]):
			return _fail("Complete champion pages require distinct identity pixels: " + key)
		paths[path.to_lower()] = true
		source_hashes[page["sha256"]] = true
		pixel_hashes[page["imported_rgba_sha256"]] = true
	return true


func _duplicates_other_baseline_identity(champion_id: String, page: Dictionary) -> bool:
	for baseline_id: String in _baseline_identity_pages:
		if baseline_id == champion_id:
			continue # Deliberate same-identity replacement is not extra coverage.
		var baseline: Dictionary = _baseline_identity_pages[baseline_id]
		for field: String in ["path", "sha256", "imported_rgba_sha256"]:
			var fingerprint := String(baseline.get(field, ""))
			if fingerprint.is_empty():
				continue
			var candidate := String(page.get(field, ""))
			if (candidate.to_lower() == fingerprint.to_lower()) if field == "path" else (candidate == fingerprint):
				return true
	return false


static func _exact_numeric_array(value: Variant, expected: Array) -> bool:
	# JSON numbers decode as floats; reject fractions/strings without treating
	# equivalent serialized integer geometry as a different typed Array.
	if not value is Array or value.size() != expected.size():
		return false
	for index: int in expected.size():
		if not (value[index] is int or value[index] is float) or float(value[index]) != float(expected[index]):
			return false
	return true


func _load_verified_override(champion_id: String, page: Dictionary) -> Texture2D:
	var path := String(page["path"])
	if not ResourceLoader.exists(path):
		_fail("Complete champion imported page is missing: " + champion_id)
		return null
	# Exported Godot PNGs may be remapped to .ctex; decoded RGBA remains mandatory.
	# Source bytes are additionally mandatory and SHA-checked in editor/source runs.
	if OS.has_feature("editor") and (not FileAccess.file_exists(path) or _sha256(path) != String(page["sha256"])):
		_fail("Complete champion source page hash changed: " + champion_id)
		return null
	var texture := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	if texture == null or Vector2i(texture.get_size()) != OVERRIDE_DIMENSIONS:
		_fail("Complete champion page must contain all eighty native cells: " + champion_id)
		return null
	var pixels := texture.get_image()
	if pixels == null or pixels.is_empty() or pixels.has_mipmaps() or pixels.get_format() != Image.FORMAT_RGBA8 \
		or _bytes_sha256(pixels.get_data()) != String(page["imported_rgba_sha256"]):
		_fail("Complete champion decoded RGBA or import settings changed: " + champion_id)
		return null
	if not _validate_override_pixels(pixels, int(page["reference_height"]), int(page["visible_feet_y"])):
		return null
	return texture


func _validate_override_pixels(pixels: Image, height: int, visible_feet_y: int = 84) -> bool:
	if pixels == null or pixels.get_size() != OVERRIDE_DIMENSIONS or height not in [58, 68, 76] or visible_feet_y not in [83, 84]:
		return _fail("Complete champion page dimensions/body guide are invalid")
	# Native image validation is performed on admission, not inside drawing.
	# A matching hash is integrity evidence, not permission for blurred alpha.
	if pixels.get_format() != Image.FORMAT_RGBA8 or pixels.has_mipmaps() or pixels.detect_alpha() != Image.ALPHA_BIT:
		return _fail("Complete champion pages require native binary alpha without mipmaps")
	for row: int in EXPECTED_ATLAS_STATES.size():
		for column: int in EXPECTED_DIRECTIONS.size():
			var used := pixels.get_region(Rect2i(column * 96, row * 96, 96, 96)).get_used_rect()
			if not used.has_area() or not Rect2i(1, 1, 94, 94).encloses(used) \
				or used.end.y != visible_feet_y + 1 or used.size.y < 12 \
				or (row == 0 and column == 0 and (used.size.y < height - 2 or used.size.y > height + 2)) \
				or (row == 0 and column > 0 and (used.size.y < height - 8 or used.size.y > height + 6)):
				return _fail("Complete champion cell is empty, clipped or not registered at its fixed feet/body guide: %d/%d" % [row, column])
	return true


func prepare_override_pages(champion_ids: Array[String]) -> bool:
	if fullbody_art != null and fullbody_art.bounded_residency:
		var ready: bool = fullbody_art.prepare_character_pages(champion_ids)
		last_error = fullbody_art.last_error
		return ready
	# Caller invokes on active-identity changes before drawing, never per draw.
	# Base identities cost no override slot. Invalid preparation preserves the
	# last verified working set atomically and returns an actionable error.
	var requested: Array[String] = []
	for champion_id: String in champion_ids:
		if not champions.has(champion_id):
			return _fail("Cannot prepare an unknown character: " + champion_id)
		if _override_pages.has(champion_id) and champion_id not in requested:
			requested.append(champion_id)
	if requested.size() > MAX_RESIDENT_OVERRIDE_PAGES:
		return _fail("Active complete champion page allowance exceeded")
	var prepared: Dictionary[String, Texture2D] = {}
	for champion_id: String in requested:
		if _override_textures.has(champion_id):
			prepared[champion_id] = _override_textures[champion_id]
		else:
			var texture := _load_verified_override(champion_id, _override_pages[champion_id])
			if texture == null:
				return false
			prepared[champion_id] = texture
	_override_textures = prepared
	last_error = ""
	return true


func override_resident_count() -> int:
	return _override_textures.size()


func inspection_frame(champion_id: String, direction_id: String) -> Dictionary:
	# One borrowed Gallery page, separate from the eight admitted actor pages.
	# Never display an old fallback for a valid but currently nonresident override.
	if not can_present(champion_id) or direction_id not in EXPECTED_DIRECTIONS:
		return {}
	if fullbody_art != null:
		return fullbody_art.inspection_frame(champion_id, EXPECTED_DIRECTIONS.find(direction_id))
	if wireframe_mode:
		return {"texture": texture_for_champion(champion_id), "region": WireframeBody.base_region("grounded", EXPECTED_DIRECTIONS.find(direction_id)), "wireframe_body": true, "visual_mode": "wireframe_body", "body_type": String(champions[champion_id]["body_type"])}
	var texture := texture_for_champion(champion_id)
	var row := int(champions[champion_id].get("atlas_row", -1)) * atlas_states.size()
	if _override_pages.has(champion_id):
		row = 0
		if not _override_textures.has(champion_id):
			if _inspection_champion_id != champion_id:
				_inspection_texture = _load_verified_override(champion_id, _override_pages[champion_id])
				_inspection_champion_id = champion_id if _inspection_texture != null else ""
			texture = _inspection_texture
	if texture == null or row < 0:
		return {}
	return {"texture": texture, "region": Rect2(EXPECTED_DIRECTIONS.find(direction_id) * 96, row * 96, 96, 96)}


func portrait_frame(champion_id: String) -> Dictionary:
	if not can_present(champion_id):
		return {}
	if fullbody_art != null:
		return fullbody_art.portrait_frame(champion_id)
	if wireframe_mode:
		var wireframe: Dictionary = (_wireframe_portraits.get(String(champions[champion_id]["body_type"]), {}) as Dictionary).duplicate()
		wireframe["wireframe_body"] = true
		wireframe["visual_mode"] = "wireframe_body"
		wireframe["body_type"] = String(champions[champion_id]["body_type"])
		wireframe["temporary_body_template"] = true
		wireframe["template_source_id"] = ""
		wireframe["complete_page_override"] = false
		return wireframe
	var has_override := _override_portraits.has(champion_id)
	var frame: Dictionary = (_override_portraits if has_override else _baseline_portraits).get(champion_id, {}).duplicate()
	if frame.is_empty():
		return {}
	var definition: Dictionary = champions[champion_id]
	frame["temporary_body_template"] = not has_override and bool(definition.get("temporary_body_template", false))
	frame["template_source_id"] = "" if has_override else String(definition.get("template_source_id", ""))
	frame["complete_page_override"] = has_override
	return frame


static func _build_portrait(pixels: Image, south_grounded_cell: Rect2i) -> Dictionary:
	# Crop anatomy, never the empty cell: the top ceil(height / 3) rows of the
	# actual front-facing model, retaining its entire occupied width. Work only
	# at verified page admission; no image reads, fitting or GPU uploads in draw.
	if pixels == null or pixels.is_empty() or not south_grounded_cell.has_area() \
		or not Rect2i(Vector2i.ZERO, pixels.get_size()).encloses(south_grounded_cell):
		return {}
	var occupied := pixels.get_region(south_grounded_cell).get_used_rect()
	if not occupied.has_area():
		return {}
	occupied.position += south_grounded_cell.position
	var source := Rect2i(occupied.position, Vector2i(occupied.size.x, ceili(float(occupied.size.y) / 3.0)))
	var crop := pixels.get_region(source)
	var scale := minf(float(PORTRAIT_SIZE.x) / source.size.x, float(PORTRAIT_SIZE.y) / source.size.y)
	var fitted_size := Vector2i(maxi(1, roundi(source.size.x * scale)), maxi(1, roundi(source.size.y * scale)))
	crop.resize(fitted_size.x, fitted_size.y, Image.INTERPOLATE_NEAREST)
	var image := Image.create(PORTRAIT_SIZE.x, PORTRAIT_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var offset := Vector2i((PORTRAIT_SIZE - fitted_size) / 2)
	image.blit_rect(crop, Rect2i(Vector2i.ZERO, fitted_size), offset)
	return {"texture": ImageTexture.create_from_image(image), "region": Rect2(Vector2.ZERO, Vector2(PORTRAIT_SIZE)),
		"source_region": Rect2(source), "occupied_model_region": Rect2(occupied), "content_region": Rect2(Vector2(offset), Vector2(fitted_size))}


func portrait_revision() -> int:
	return configuration_generation


func _validate_extension_registry(value: Variant, live_entries: Array) -> bool:
	extension_page_capacity = 0
	if not value is Dictionary or live_entries.size() > MAX_LIVE_RECIPES:
		return _fail("Additional champion pages require a bounded live registry")
	var live_ids: Dictionary = {}
	for entry_value: Variant in live_entries:
		if not entry_value is Dictionary:
			return _fail("Character art identity must be an object")
		var entry: Dictionary = entry_value
		var champion_id := String(entry.get("id", ""))
		if champion_id.is_empty() or live_ids.has(champion_id):
			return _fail("Character art identities must be nonempty and unique")
		live_ids[champion_id] = true
	for champion_id: String in REQUIRED_FOUNDATION:
		if not live_ids.has(champion_id) or not champions.has(champion_id):
			return _fail("Character art registry lacks a required foundation: " + champion_id)
	var extensions: Dictionary = value
	var capacity := live_ids.size() - REQUIRED_FOUNDATION.size()
	if extensions.size() > capacity:
		return _fail("Additional champion pages exceed the live roster allowance")
	var page_paths: Dictionary = {}
	for key: Variant in extensions:
		if not key is String or key in REQUIRED_FOUNDATION or not live_ids.has(key) or not champions.has(key):
			return _fail("Additional champion page has no matching live recipe: " + str(key))
		if not extensions[key] is Dictionary:
			return _fail("Additional champion page must be an object: " + str(key))
		var page: Dictionary = extensions[key]
		var page_path := String(page.get("path", ""))
		if not page_path.begins_with("res://assets/sprites/champions_v3/") or not page_path.ends_with(".png") \
			or "/../" in page_path or "/./" in page_path or page_paths.has(page_path.to_lower()):
			return _fail("Additional champion pages require distinct contained PNG paths: " + str(key))
		for field: String in ["sha256", "imported_rgba_sha256"]:
			var digest := String(page.get(field, ""))
			if digest.length() != 64:
				return _fail("Additional champion page hash is invalid: " + str(key))
			for index: int in digest.length():
				var digit := digest.unicode_at(index)
				if not (digit >= 48 and digit <= 57) and not (digit >= 97 and digit <= 102):
					return _fail("Additional champion page hash is invalid: " + str(key))
		page_paths[page_path.to_lower()] = true
	for champion_id: String in champions:
		if not live_ids.has(champion_id):
			return _fail("Character art recipe is not in the live roster: " + champion_id)
		if champion_id not in REQUIRED_FOUNDATION and not extensions.has(champion_id):
			return _fail("Additional champion lacks a matching page: " + champion_id)
	extension_page_capacity = capacity
	return true


func _register_temporary_templates(entries: Array) -> bool:
	if entries.size() > MAX_LIVE_RECIPES:
		return _fail("Character presentation capacity exceeded")
	var additions: Dictionary = {}
	for value: Variant in entries:
		if not value is Dictionary:
			return _fail("Character presentation identity must be an object")
		var entry: Dictionary = value
		var champion_id := String(entry.get("id", ""))
		if champions.has(champion_id):
			continue
		var source_id := String(entry.get("template_source_id", ""))
		if champion_id.is_empty() or additions.has(champion_id) or source_id not in REQUIRED_FOUNDATION \
			or String(entry.get("art_status", "")) != "temporary_body_template" \
			or entry.get("unique_runtime_art_approved", true) != false:
			return _fail("Character lacks accepted art or an explicit temporary template: " + champion_id)
		var definition: Dictionary = (champions[source_id] as Dictionary).duplicate(true)
		if String(entry.get("body_type", "")) != String(definition["body_type"]):
			return _fail("Temporary character template must match its body size: " + champion_id)
		definition["display_name"] = entry.get("display_name", "")
		definition["ancestry"] = entry.get("ancestry", "")
		definition["affinities"] = entry.get("affinities", [])
		definition["temporary_body_template"] = true
		definition["template_source_id"] = source_id
		definition["art_status"] = "temporary_body_template"
		if not _validate_recipe(champion_id, definition):
			return false
		additions[champion_id] = definition
	champions.merge(additions)
	return true


func can_present(champion_id: String) -> bool:
	if fullbody_art != null:
		return champions.has(champion_id) and fullbody_art.entries.has(champion_id)
	return champions.has(champion_id) and (not wireframe_mode or wireframe_body.base_texture(String(champions[champion_id]["body_type"])) != null)


func recipe(champion_id: String) -> Dictionary:
	var result := (champions.get(champion_id, {}) as Dictionary).duplicate(true)
	if wireframe_mode and not result.is_empty():
		result["wireframe_body"] = true
		result["art_status"] = "shared_size_skeleton"
		return result
	if _override_pages.has(champion_id):
		result["complete_page_override"] = true
		result["override_resident"] = _override_textures.has(champion_id)
		if _override_textures.has(champion_id):
			result["temporary_body_template"] = false
			result["template_source_id"] = ""
			result["art_status"] = "reviewed_complete_runtime_page"
	return result


func source_region(champion_id: String, state: PlayerState) -> Rect2:
	return source_region_for_animation_state(champion_id, state, silhouette_state(state) if state != null else "")


func source_region_for_animation_state(champion_id: String, state: PlayerState, animation_state: String) -> Rect2:
	if state == null or not champions.has(champion_id):
		return Rect2()
	if wireframe_mode:
		if not can_present(champion_id):
			return Rect2()
		var aim := presentation_facing_vector(state, animation_state)
		return WireframeBody.base_region(animation_state, EightDirectionResolver.classify_index(aim.x, aim.y))
	var row := int((champions[champion_id] as Dictionary).get("atlas_row", -1))
	if row < 0 or row >= REQUIRED_FOUNDATION.size():
		return Rect2()
	var facing_state := animation_state.trim_suffix("_b")
	var facing_vector := presentation_facing_vector(state, facing_state)
	var facing := direction_for_state(animation_state, facing_vector.x, facing_vector.y)
	var state_index := atlas_states.find(animation_state)
	var direction_index := atlas_directions.find(facing)
	if state_index < 0 or direction_index < 0:
		return Rect2()
	var atlas_row := row * atlas_states.size() + state_index
	if _override_textures.has(champion_id):
		atlas_row = state_index
	return Rect2(Vector2(float(direction_index) * CELL_SIZE.x, float(atlas_row) * CELL_SIZE.y), CELL_SIZE)


func draw(
	canvas: CanvasItem,
	state: PlayerState,
	champion_id: String,
	body_anchor: Vector2,
	presentation_tick: float,
	config: SimConfig,
	reduced_effects: bool = false,
	ground_anchor: Vector2 = Vector2.INF,
	locomotion_phase: float = -1.0,
	wall_travel: Vector2i = Vector2i.ZERO,
	cast_timing: Dictionary = {},
) -> bool:
	if canvas == null or state == null or not champions.has(champion_id):
		return false
	var frame := movement_frame(champion_id, state, presentation_tick, config, reduced_effects, locomotion_phase, wall_travel, cast_timing)
	if frame.is_empty():
		return false
	var anchor := body_anchor + (frame["offset"] as Vector2)
	var floor_anchor := ground_anchor if ground_anchor.is_finite() else body_anchor
	var frame_texture: Texture2D = frame.get("texture", texture_for_champion(champion_id))
	if frame_texture == null:
		return false
	var display_height := float(frame["display_height"])
	var protection := protection_contract(state, config, reduced_effects, display_height)
	var body_tint: Color = protection["body_tint"]
	# No ghost bodies or movement trails. Protection and height cues remain.
	_draw_ground_skid_accent(canvas, state, floor_anchor, reduced_effects, locomotion_phase)
	_draw_takeoff_accent(canvas, state, body_anchor if state.hop_mode == PlayerState.MovementMode.DOUBLE_JUMP else floor_anchor, config, reduced_effects)
	_draw_movement_accent(canvas, state, floor_anchor, roundi(presentation_tick), reduced_effects, body_anchor, config)
	# Affinities belong to the loadout/HUD and actual casts, not idle orbiting
	# decorations. Protection and height cues below remain authority-driven.
	var squat_depth := int(frame.get("squat_depth", 0))
	if bool(frame.get("fullbody_art", false)):
		FullbodyCast.draw_frame(canvas, frame, anchor, body_tint)
	elif squat_depth > 0:
		# Bend by translating the upper pose toward planted feet, never resizing
		# the sprite or authority. Integer regions keep pixel edges crisp.
		var source: Rect2 = frame["source_region"]
		var split := 70.0
		canvas.draw_texture_rect_region(frame_texture, Rect2(anchor - PIVOT + Vector2(0, split), Vector2(CELL_SIZE.x, CELL_SIZE.y - split)), Rect2(source.position + Vector2(0, split), Vector2(source.size.x, source.size.y - split)), body_tint)
		canvas.draw_texture_rect_region(frame_texture, Rect2(anchor - PIVOT + Vector2(0, squat_depth), Vector2(CELL_SIZE.x, split)), Rect2(source.position, Vector2(source.size.x, split)), body_tint)
	else:
		canvas.draw_texture_rect_region(frame_texture, Rect2(anchor - PIVOT, CELL_SIZE), frame["source_region"], body_tint)
	_draw_height_cue(canvas, state, anchor, config, display_height)
	_draw_evasion_contour(canvas, state, anchor, config, reduced_effects, display_height)
	return true


func movement_frame(champion_id: String, state: PlayerState, presentation_tick: float, config: SimConfig, reduced_effects: bool = false, locomotion_phase: float = -1.0, wall_travel: Vector2i = Vector2i.ZERO, cast_timing: Dictionary = {}) -> Dictionary:
	if state == null or config == null or not champions.has(champion_id):
		return {}
	# Resolve the actual renderer once before preparing legacy body transforms.
	# Fullbody owns offset/squat (and sometimes source_region); constructing
	# those legacy values only to overwrite them cannot affect the final frame.
	# Keep aura/contact/phase metadata exact and every fallback on its old path.
	var fullbody_frame: Dictionary = {}
	if fullbody_art != null:
		fullbody_frame = fullbody_art.frame(champion_id, state, presentation_tick, config, locomotion_phase, reduced_effects, wall_travel, cast_timing)
		if fullbody_art.bounded_residency and fullbody_frame.is_empty(): return {}
	var prepare_legacy_offset := not fullbody_frame.has("offset")
	var definition: Dictionary = champions[champion_id]
	var animation_state := silhouette_state(state)
	var motion_id := MinimalChampionMotion.motion_id(state)
	# Bare-hand cast effects remain separate. Moving casts must not freeze the
	# legs or replace an airborne/low silhouette with an upright aiming body.
	if animation_state in ["walk", "sprint"]:
		motion_id = animation_state
	elif animation_state in ["slide", "roll"]:
		motion_id = "low"
	elif animation_state == "jump":
		motion_id = "air"
	var motion_elapsed := MinimalChampionMotion.elapsed_for_state(state, motion_id, presentation_tick, config)
	# Contact pose and secondary motion share one seeded phase. Previously the
	# opposite foot could be selected while the torso was still on contact A.
	if motion_id in ["walk", "sprint"]:
		if locomotion_phase >= 0.0 and is_finite(locomotion_phase):
			motion_elapsed = motion.locomotion_elapsed_at_phase(String(definition.get("motion_profile", "")), motion_id, locomotion_phase)
		else:
			# Pure preview/legacy callers without world travel history retain the
			# deterministic timed cycle; the live game supplies a distance phase.
			motion_elapsed += float(maxi(0, state.entity_id) * 3)
	var motion_sample := motion.sample(String(definition.get("motion_profile", "")), motion_id, motion_elapsed, reduced_effects, prepare_legacy_offset)
	if motion_id in ["walk", "sprint"]:
		var response := movement_response_scale(state)
		if prepare_legacy_offset: motion_sample.offset *= response
		motion_sample.aura_scale = lerpf(1.0, motion_sample.aura_scale, response)
		_apply_relative_gait_motion(motion_sample, locomotion_gait(state), reduced_effects, prepare_legacy_offset)
	# Foot plants retain their exact pivot; the between-contact motion is tiny
	# and smooth, never a scale pulse or blended directional atlas frame.
	var pose_offset: Vector2 = fullbody_frame.get("offset", Vector2.ZERO)
	if prepare_legacy_offset:
		pose_offset = motion_sample.offset.round() if motion_id in ["cast", "hit"] else Vector2.ZERO
		if motion_id in ["walk", "sprint"]:
			pose_offset = motion.locomotion_pivot_offset(String(definition.get("motion_profile", "")), motion_id, motion_elapsed, Vector2(state.velocity_x, state.velocity_y), movement_response_scale(state), reduced_effects)
	var contact_frame := 0
	if animation_state in EXPECTED_PHASE_STATES:
		contact_frame = motion.locomotion_contact_frame(String(definition.get("motion_profile", "")), motion_id, motion_elapsed)
		if contact_frame == 1:
			animation_state += "_b"
	var source: Rect2 = fullbody_frame.source_region if fullbody_frame.has("source_region") else source_region_for_animation_state(champion_id, state, animation_state)
	var result := {"animation_state": animation_state, "motion_id": motion_id, "contact_frame": contact_frame, "offset": pose_offset, "scale": Vector2.ONE, "aura_scale": motion_sample.aura_scale, "source_region": source, "display_height": int(definition.get("height", 68))}
	result["squat_depth"] = fullbody_frame.squat_depth if fullbody_frame.has("squat_depth") else JumpPresentation.squat_depth(state, config)
	if wireframe_mode and fullbody_art == null:
		var phase := locomotion_phase
		if phase < 0.0 or not is_finite(phase):
			var duration := motion.locomotion_elapsed_at_phase(String(definition.get("motion_profile", "")), motion_id, 0.5) * 2.0
			phase = motion_elapsed / maxf(1.0, duration)
		var body_travel := Vector2i(state.velocity_x, state.velocity_y)
		if animation_state == "slide":
			body_travel = presentation_facing_vector(state, animation_state)
		var body_frame := wireframe_body.frame(String(definition["body_type"]), animation_state, presentation_facing_vector(state, animation_state), body_travel, phase)
		if body_frame.is_empty():
			return {}
		result.merge(body_frame, true)
	if fullbody_art != null:
		result.merge(fullbody_frame, true)
	return result


func _draw_atlas_candidate(canvas: CanvasItem, state: PlayerState, champion_id: String, animation_state: String, anchor: Vector2) -> void:
	var source := source_region_for_animation_state(champion_id, state, animation_state)
	canvas.draw_texture_rect_region(texture_for_champion(champion_id), Rect2(anchor - PIVOT, CELL_SIZE), source)


func texture_for_champion(champion_id: String) -> Texture2D:
	if fullbody_art != null:
		return fullbody_art.textures.get(champion_id)
	if wireframe_mode:
		return wireframe_body.base_texture(String((champions.get(champion_id, {}) as Dictionary).get("body_type", "")))
	if _override_textures.has(champion_id):
		return _override_textures[champion_id]
	return extension_atlases.get(champion_id, atlas)


func portrait_region(champion_id: String) -> Rect2:
	if not can_present(champion_id):
		return Rect2()
	if wireframe_mode:
		return portrait_frame(champion_id).get("source_region", Rect2())
	# Legacy source-region queries must match texture_for_champion() residency.
	# UI consumers use portrait_frame(), which also works before world admission.
	var cache := _override_portraits if _override_textures.has(champion_id) else _baseline_portraits
	return cache.get(champion_id, {}).get("source_region", Rect2())


func silhouette_state(state: PlayerState) -> String:
	var action := semantic_action(state)
	if state != null and state.health > 0 and state.control_state in [PlayerState.ControlState.FREE, PlayerState.ControlState.SLOWED]:
		if state.jumpsquat_active:
			return "grounded"
		if state.crouching:
			return "slide"
		if state.is_rolling():
			return "roll"
		if state.movement_mode in [PlayerState.MovementMode.SLIDE, PlayerState.MovementMode.WAVE_DASH]:
			return "slide"
		if state.movement_mode == PlayerState.MovementMode.WALL_SKIM:
			return "sprint"
		if state.is_airborne():
			return "jump"
		if state.velocity_x != 0 or state.velocity_y != 0:
			if state.movement_mode in [PlayerState.MovementMode.WALK, PlayerState.MovementMode.SLOWED]:
				return "walk"
			if state.movement_mode == PlayerState.MovementMode.SPRINT:
				return "sprint"
	return atlas_state_for_action(action)


func atlas_state_for_action(action_id: String) -> String:
	return String(semantic_state_aliases.get(action_id, ""))


static func semantic_action(state: PlayerState) -> String:
	if state == null:
		return "idle"
	if state.health <= 0:
		return "defeated"
	match state.control_state:
		PlayerState.ControlState.LAUNCHED:
			return "launched"
		PlayerState.ControlState.GRAPPLED:
			return "grappled"
		PlayerState.ControlState.CHARGING:
			return "charging"
		PlayerState.ControlState.STUNNED:
			return "stunned"
		PlayerState.ControlState.ROOTED:
			return "rooted"
		PlayerState.ControlState.SLOWED:
			return "slowed"
	if state.pending_cast_wire_id > 0 or state.last_event.begins_with("cast_start_"):
		return "cast"
	if state.cast_recovery_ticks > 0:
		return "cast_recovery"
	if state.is_rolling():
		return "roll"
	match state.movement_mode:
		PlayerState.MovementMode.WALK:
			return "walk"
		PlayerState.MovementMode.SPRINT:
			return "sprint"
		PlayerState.MovementMode.HOP:
			return "jump"
		PlayerState.MovementMode.DOUBLE_JUMP:
			return "double_jump"
		PlayerState.MovementMode.SLIDE:
			return "slide"
		PlayerState.MovementMode.SLIDE_JUMP:
			return "slide_jump"
		PlayerState.MovementMode.AIR_DODGE:
			return "air_dodge"
		PlayerState.MovementMode.WAVE_DASH:
			return "wave_dash"
		PlayerState.MovementMode.WALL_KICK:
			return "wall_kick"
		PlayerState.MovementMode.VAULT:
			return "vault"
		PlayerState.MovementMode.SUPERGLIDE:
			return "superglide"
		PlayerState.MovementMode.LAUNCHED:
			return "launched"
		PlayerState.MovementMode.GRAPPLED:
			return "grappled"
		PlayerState.MovementMode.CHARGING:
			return "charging"
		PlayerState.MovementMode.STUNNED:
			return "stunned"
		PlayerState.MovementMode.ROOTED:
			return "rooted"
		PlayerState.MovementMode.SLOWED:
			return "slowed"
		PlayerState.MovementMode.FAST_FALL:
			return "fast_fall"
		PlayerState.MovementMode.WALL_SKIM:
			return "wall_skim"
		PlayerState.MovementMode.IMPACT_RECOVERY:
			return "impact_recovery"
		PlayerState.MovementMode.ROLL:
			return "roll"
	if state.is_airborne():
		return "jump"
	return "idle"


static func cardinal_direction(x: int, y: int) -> String:
	return EightDirectionResolver.nearest_cardinal_id(x, y)


static func direction_for_state(state_id: String, x: int, y: int) -> String:
	if state_id in EXPECTED_DIAGONAL_STATES:
		return EightDirectionResolver.direction_id_from_vector(x, y)
	return cardinal_direction(x, y)


static func presentation_facing_vector(state: PlayerState, _state_id: String = "") -> Vector2i:
	if state == null:
		return Vector2i(0, 1000)
	if _state_id == "slide" and not state.crouching:
		var travel := Vector2i(state.velocity_x, state.velocity_y)
		if Vector2(travel).length_squared() > 1000000.0:
			return travel
		var lane := Vector2i(state.slide_x, state.slide_y)
		if lane != Vector2i.ZERO:
			return lane
		return Vector2i(state.facing_x, state.facing_y)
	# Presentation follows live cursor/controller aim without turn easing or a
	# cast-start latch. Movement facing still owns neutral evasions; pending cast
	# aim still owns the committed shot. Never write either authority field here.
	var aim := Vector2i(state.aim_x, state.aim_y)
	if aim != Vector2i.ZERO:
		return aim
	var movement_facing := Vector2i(state.facing_x, state.facing_y)
	return movement_facing if movement_facing != Vector2i.ZERO else Vector2i(0, 1000)


static func has_combat_facing_intent(state: PlayerState) -> bool:
	return state != null and (
		state.primary_held
		or state.pending_cast_wire_id > 0
		or state.cast_recovery_ticks > 0
		or state.last_event.begins_with("cast_start_")
	)


static func locomotion_gait(state: PlayerState) -> String:
	if state == null or state.movement_mode not in [PlayerState.MovementMode.WALK, PlayerState.MovementMode.SPRINT]:
		return "idle"
	var travel := Vector2i(state.velocity_x, state.velocity_y)
	if travel == Vector2i.ZERO:
		return "idle"
	var facing := presentation_facing_vector(state, "walk")
	return EightDirectionResolver.relative_gait_from_vectors(facing, travel)


static func _apply_relative_gait_motion(sample: MinimalChampionMotion.Sample, gait: String, reduced: bool, include_offset: bool = true) -> void:
	if sample == null or gait in ["idle", "forward"]:
		return
	var strength := 0.35 if reduced else 1.0
	match gait:
		"backward":
			if include_offset:
				sample.offset.x *= -1.0
				sample.offset.y *= lerpf(1.0, 0.72, strength)
			sample.aura_scale = lerpf(1.0, sample.aura_scale, lerpf(1.0, 0.84, strength))
		"strafe_left":
			if include_offset: sample.offset.x -= 0.65 * strength
		"strafe_right":
			if include_offset: sample.offset.x += 0.65 * strength


static func body_type_render_scale(body_type: String) -> float:
	return float(BODY_TYPE_RENDER_SCALE.get(body_type.to_lower(), 1.0))


func _validate_body_template_contract(value: Variant) -> bool:
	body_templates.clear()
	if not value is Dictionary:
		return _fail("Cartoon champion body template contract must be an object")
	var contract: Dictionary = value
	if contract.get("types", []) != EXPECTED_BODY_TYPES \
		or contract.get("template_build_order", []) != EXPECTED_BODY_TYPES \
		or String(contract.get("proportion_reference", "")) != PROPORTION_REFERENCE_PATH \
		or contract.get("ordinary_head_ratio_range", []) != [0.20, 0.23] \
		or String(contract.get("head_measurement_policy", "")) != "ordinary_cranium_excludes_hair_fins_horns_and_ancestry_crowns" \
		or String(contract.get("anatomy_reference_champion", "")) != "red_baron" \
		or _vector2i(contract.get("shared_cell", [])) != Vector2i(96, 96) \
		or _vector2i(contract.get("shared_feet_pivot", [])) != Vector2i(48, 84) \
		or contract.get("runtime_scale", []) != [1.0, 1.0]:
		return _fail("Cartoon champion body template geometry is unsupported")
	if String(contract.get("shared_collision_policy", "")) != "shared_wall_clearance_size_specific_hurtboxes_independent_of_pose_pixels" \
		or String(contract.get("animation_policy", "")) != "pose_and_offset_only_never_rescale_body":
		return _fail("Cartoon champion size lock must remain presentation-only and invariant")
	var templates: Dictionary = contract.get("templates", {})
	var expected_exemplars := {"small": "s_wayne", "middle": "oh_tipi", "large": "red_baron"}
	var expected_heights := {"small": 58, "middle": 68, "large": 76}
	for body_type: String in EXPECTED_BODY_TYPES:
		if not templates.has(body_type) or not templates[body_type] is Dictionary:
			return _fail("Cartoon champion body template is missing: %s" % body_type)
		var template: Dictionary = templates[body_type]
		if String(template.get("exemplar", "")) != String(expected_exemplars[body_type]) \
			or int(template.get("reference_height", 0)) != int(expected_heights[body_type]) \
			or String(template.get("silhouette", "")).is_empty():
			return _fail("Cartoon champion body template is invalid: %s" % body_type)
	body_templates = templates.duplicate(true)
	return true


func _validate_shared_style_contract(value: Variant) -> bool:
	shared_style_contract.clear()
	if not value is Dictionary:
		return _fail("Cartoon champion shared style contract must be an object")
	var contract: Dictionary = value
	if String(contract.get("reference_champion", "")) != "red_baron" \
		or String(contract.get("outline_source", "")) != "shared_64_color_old_world_material_palette" \
		or int(contract.get("outline_radius_pixels", 0)) != 1 \
		or String(contract.get("outline_application", "")) != "cell_bounded_exterior_ink_without_rescale" \
		or int(contract.get("palette_budget", 0)) != 64 \
		or String(contract.get("material_language", "")) != "compact_cartoon_pixel_clusters_with_dark_ink_and_bounded_highlights" \
		or String(contract.get("identity_policy", "")) != "share rendering grammar while preserving ancestry silhouette body template clothing and palette" \
		or String(contract.get("authority", "")) != "presentation_only":
		return _fail("Cartoon champion shared style contract is unsupported")
	shared_style_contract = contract.duplicate(true)
	return true


static func hand_cast_origin(body_anchor: Vector2, aim: Vector2) -> Vector2:
	var direction := aim.normalized() if aim.length_squared() > 0.01 else Vector2.DOWN
	var side := direction.orthogonal()
	return body_anchor + Vector2(0.0, -HAND_CAST_HEIGHT) + direction * HAND_CAST_FORWARD + side * HAND_CAST_SIDE


static func _directional_lean(state: PlayerState, motion_id: String, reduced: bool) -> Vector2:
	if motion_id not in ["walk", "sprint", "low", "air"]:
		return Vector2.ZERO
	var velocity := Vector2(float(state.velocity_x), float(state.velocity_y))
	if velocity.length_squared() < 1.0:
		return Vector2.ZERO
	var amount := 1.0 if motion_id == "walk" else (2.0 if motion_id in ["sprint", "air"] else 2.5)
	if motion_id in ["walk", "sprint"]:
		amount *= movement_response_scale(state)
	if reduced:
		amount *= 0.35
	return velocity.normalized() * amount


static func movement_response_scale(state: PlayerState) -> float:
	if state == null:
		return 0.0
	var reference_speed := float(MovementTuning.BASE_SPEED * state.movement_speed_ratio) / 1000.0
	if state.movement_mode == PlayerState.MovementMode.SPRINT:
		reference_speed *= float(MovementTuning.SPRINT_MULTIPLIER) / 1000.0
	if reference_speed <= 0.0:
		return 0.0
	var speed := Vector2(float(state.velocity_x), float(state.velocity_y)).length()
	return smoothstep(0.0, 1.0, clampf(speed / reference_speed, 0.0, 1.0))


func _draw_ground_skid_accent(canvas: CanvasItem, state: PlayerState, ground_anchor: Vector2, reduced: bool, locomotion_phase: float = -1.0) -> void:
	# Compact contacts replace the intentionally suppressed historical trail.
	# Nothing is retained behind the actor or changes its registered sprite.
	GroundSkid.draw(canvas, ground_anchor, GroundSkid.sample(state, locomotion_phase, reduced), language)


func _draw_takeoff_accent(canvas: CanvasItem, state: PlayerState, ground_anchor: Vector2, config: SimConfig, reduced: bool) -> void:
	var cue := JumpPresentation.takeoff_contract(state, config, reduced)
	if not bool(cue["active"]):
		return
	var takeoff_age := int(cue.get("age", 0))
	if pixel_movement.stamp(canvas,"jump_takeoff",ground_anchor,takeoff_age,reduced):
		return
	var radius := float(cue["radius"])
	var opacity := float(cue["opacity"])
	var color := language.ramp_color("aged_brass", 4)
	for side: float in [-1.0, 1.0]:
		canvas.draw_arc(ground_anchor, radius, side * 0.22, side * 2.86, 12, Color(color, opacity), 1.5)
	if not reduced:
		for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT]:
			canvas.draw_line(ground_anchor + direction * (radius + 3.0), ground_anchor + direction * (radius + 6.0), Color(color, opacity * 0.7), 1.5)


func _draw_height_cue(canvas: CanvasItem, state: PlayerState, anchor: Vector2, config: SimConfig, height: float) -> void:
	var cue := JumpPresentation.height_contract(state, config)
	if not bool(cue["active"]):
		return
	var center := anchor + Vector2(0, -height - 7)
	var ink := Color(0.09, 0.16, 0.20, 0.94)
	var color := Color(0.73, 0.90, 0.95, 1.0)
	# Chevron UP = above ground threats, DOWN = under projectiles. No shield:
	# height clearance is not dodge invulnerability or immunity to tall effects.
	var sign_y := -1.0 if bool(cue["above"]) else 1.0
	var points := PackedVector2Array([center + Vector2(-5, -2 * sign_y), center + Vector2(0, 2 * sign_y), center + Vector2(5, -2 * sign_y)])
	canvas.draw_polyline(points, ink, 4.0)
	canvas.draw_polyline(points, color, 2.0)
	if bool(cue["flight"]):
		var width := 18.0
		canvas.draw_rect(Rect2(center + Vector2(-9, -10), Vector2(width, 3)), ink)
		canvas.draw_rect(Rect2(center + Vector2(-9, -10), Vector2(ceilf(width * float(cue["budget"])), 2)), color)


static func movement_trail_contract(state: PlayerState, config: SimConfig, reduced: bool = false) -> Dictionary:
	var result := {"active": false, "body_anchored": false, "lines": [], "dust": [], "opacity": 0.0}
	if state == null or config == null or state.health <= 0:
		return result
	var dodge := state.air_dodge_ticks > 0 and not state.is_rolling()
	var slide := state.slide_ticks > 0 and not state.is_airborne()
	if not dodge and not slide:
		return result
	var direction := LandingPresentation.motion_direction(state)
	var speed := Vector2(state.velocity_x, state.velocity_y).length()
	if speed <= float(SimConfig.FIXED_SCALE):
		return result
	var side := direction.orthogonal()
	var phase := 0.0
	if dodge:
		var total := config.milliseconds_to_ticks(MovementTuning.AIR_DODGE_DURATION_MS)
		phase = clampf(1.0 - float(state.air_dodge_ticks) / float(maxi(1, total)), 0.0, 1.0)
	var length := (12.0 + (1.0 - phase) * 15.0) if dodge else clampf(speed / 25000.0, 12.0, 25.0)
	length *= 0.6 if reduced else 1.0
	var lines: Array[PackedVector2Array] = []
	var dust: Array[Vector2] = []
	for sign_value: float in [-1.0, 1.0]:
		# Flank placement keeps southward trails outside the lifted/low body,
		# instead of hiding every line behind its crisp opaque silhouette.
		var start := -direction * (10.0 if dodge else 8.0) + side * (24.0 if dodge else 22.0) * sign_value
		lines.append(PackedVector2Array([start - direction * length, start]))
		if not reduced:
			if dodge:
				lines.append(PackedVector2Array([start - direction * (length + 5.0) + side * sign_value * 4.0, start - direction * 10.0 + side * sign_value * 4.0]))
			else:
				dust.append(start - direction * (length + 3.0))
	result["active"] = true
	result["body_anchored"] = dodge
	result["lines"] = lines
	result["dust"] = dust
	result["opacity"] = (0.50 if reduced else 0.72) * (1.0 - phase * 0.42)
	return result


func _draw_movement_accent(canvas: CanvasItem, state: PlayerState, ground_anchor: Vector2, tick: int, reduced: bool, body_anchor: Vector2 = Vector2.INF, config: SimConfig = null) -> void:
	_draw_wall_attachment(canvas, state, body_anchor if body_anchor.is_finite() else ground_anchor, ground_anchor, config)
	if pixel_movement.ready():
		_draw_pixel_movement_accent(canvas,state,ground_anchor,tick * 2,reduced,config,body_anchor)
		return
	var definition := motion.accent(state)
	if definition.is_empty():
		return
	var kind := String(definition.get("kind", ""))
	# The legacy DOUBLE_JUMP adapter is Float, whose state is marked only by
	# the immediate protection layer. Never loop a stale lift ring on release.
	if kind in ["lift_ring", "ground_wake", "speed_fins", "ground_chevron", "fall_lines"]:
		return
	if kind in ["speed_fins", "fall_lines", "recovery_brace"] and body_anchor.is_finite():
		ground_anchor = body_anchor
	var color := language.ramp_color(String(definition.get("ramp", "aged_brass")), int(definition.get("index", 3)))
	var opacity := float(definition.get("opacity", 0.4)) * (0.55 if reduced else 1.0)
	var velocity := Vector2(float(state.velocity_x), float(state.velocity_y))
	var direction := velocity.normalized() if velocity.length_squared() > 1.0 else Vector2(float(state.facing_x), float(state.facing_y)).normalized()
	var side := Vector2(-direction.y, direction.x)
	var phase := float(tick % 12) / 12.0
	match kind:
		"ground_chevron":
			for index: int in range(2):
				var center := ground_anchor - direction * (12.0 + float(index) * 9.0)
				canvas.draw_polyline(PackedVector2Array([center + side * 7.0, center - direction * 6.0, center - side * 7.0]), Color(color, opacity * (1.0 - float(index) * 0.25)), 2.0)
		"kick_burst":
			var contact := ground_anchor - direction * 11.0
			for angle_offset: float in [-0.55, 0.0, 0.55]:
				var ray := (-direction).rotated(angle_offset)
				canvas.draw_line(contact + ray * 4.0, contact + ray * 13.0, Color(color, opacity), 2.0)
		"crest_arc":
			canvas.draw_arc(ground_anchor + Vector2(0, -10), 18.0, PI + 0.25, TAU - 0.25, 12, Color(color, opacity), 2.0)
		"fall_lines":
			for x_offset: float in [-8.0, 0.0, 8.0]:
				canvas.draw_line(ground_anchor + Vector2(x_offset, -28.0), ground_anchor + Vector2(x_offset, -16.0 + phase * 5.0), Color(color, opacity), 2.0)
		"wall_sparks":
			var contact_geometry := wall_contact_geometry(state)
			if contact_geometry.is_empty() or velocity.length_squared() <= 0.0:
				return
			var wall_normal: Vector2 = contact_geometry["normal"]
			var contact := (body_anchor if body_anchor.is_finite() else ground_anchor) + (contact_geometry["offset"] as Vector2)
			var count := 1 if reduced else 3
			for index: int in range(count):
				var spark_direction := wall_normal.rotated(-0.5 + float(index) * 0.5 if count > 1 else 0.0)
				canvas.draw_line(contact, contact + spark_direction * (4.0 + phase * 3.0), Color(color, opacity * (0.7 + phase * 0.3)), 1.0)
		"recovery_brace":
			var contraction := 1.0 - phase
			var impact_center := ground_anchor + Vector2(0, -21) - direction * (6.0 + contraction * 3.0)
			canvas.draw_circle(impact_center, 9.0 + contraction * 3.0, Color(language.ramp_color("worldbone", 0), opacity * 0.28))
			for angle_offset: float in [-0.46, 0.0, 0.46]:
				var ray := (-direction).rotated(angle_offset)
				canvas.draw_line(impact_center + ray * 7.0, impact_center + ray * (15.0 + contraction * 5.0), Color(color, opacity * (0.72 + contraction * 0.28)), 3.0 if not reduced else 2.0)
			for side_sign: float in [-1.0, 1.0]:
				var brace_center := ground_anchor + side * side_sign * (18.0 + contraction * 5.0)
				canvas.draw_arc(brace_center, 7.0, -1.2 if side_sign < 0.0 else 1.9, 1.2 if side_sign < 0.0 else 4.3, 7, Color(color, opacity * (0.6 + contraction * 0.4)), 3.0 if not reduced else 2.0)
			canvas.draw_line(ground_anchor - direction * 10.0, ground_anchor - direction * (19.0 + contraction * 6.0), Color(color, opacity * 0.9), 3.0 if not reduced else 2.0)


static func wall_contact_geometry(state: PlayerState) -> Dictionary:
	if not WallPose.is_attached(state):
		return {}
	var normal := Vector2(state.wall_x, state.wall_y).normalized()
	if normal == Vector2.ZERO:
		return {}
	return {"normal": normal, "offset": -normal * float(MovementTuning.PLAYER_RADIUS) / SimConfig.FIXED_SCALE}


static func wall_attachment_contract(state: PlayerState, config: SimConfig, body_anchor: Vector2, ground_anchor: Vector2) -> Dictionary:
	if config == null or not config.is_valid() or not body_anchor.is_finite() or not ground_anchor.is_finite(): return {}
	var contact := wall_contact_geometry(state)
	if contact.is_empty(): return {}
	var normal: Vector2 = contact.normal
	var duration := maxi(1, config.milliseconds_to_ticks(MovementTuning.WALL_SKIM_DURATION_MS))
	var ratio := clampf(float(state.wall_skim_ticks) / float(duration), 0.0, 1.0)
	return {"contact": body_anchor + (contact.offset as Vector2),
		"floor_contact": ground_anchor + (contact.offset as Vector2), "normal": normal,
		"tangent": Vector2(-normal.y, normal.x), "remaining_ratio": ratio,
		"segments": clampi(ceili(ratio * 3.0), 1, 3),
		"moving": state.velocity_x != 0 or state.velocity_y != 0}


func _draw_wall_attachment(canvas: CanvasItem, state: PlayerState, body_anchor: Vector2, ground_anchor: Vector2, config: SimConfig) -> void:
	var contact := wall_attachment_contract(state, config, body_anchor, ground_anchor)
	if contact.is_empty(): return
	var at: Vector2 = contact.contact
	var tangent: Vector2 = contact.tangent
	var normal: Vector2 = contact.normal
	var ink := language.ramp_color("aged_brass", 0)
	var light := language.ramp_color("aged_brass", 4)
	# A short surface-aligned contact strip, never a shield around the actor.
	# It stays legible in reduced mode and never advances on render time.
	canvas.draw_line(at - tangent * 10.0, at + tangent * 10.0, Color(ink, 0.9), 4.0)
	for segment: int in 3:
		var start := at + tangent * (-8.0 + segment * 6.0) + normal
		canvas.draw_line(start, start + tangent * 4.0, Color(light if segment < int(contact.segments) else ink, 0.92), 2.0)


func clear_motion_contacts() -> void:
	pixel_movement.clear_contacts()


func _draw_pixel_movement_accent(canvas: CanvasItem, state: PlayerState, ground_anchor: Vector2, age: int, reduced: bool, config: SimConfig, body_anchor: Vector2 = Vector2.INF) -> void:
	if state.health <= 0 or config == null:
		return
	var velocity := Vector2(state.velocity_x,state.velocity_y)
	var contact_anchor := body_anchor if body_anchor.is_finite() else ground_anchor
	var walljump := pixel_movement.walljump_contact(state,config,age,contact_anchor)
	if not walljump.is_empty():
		pixel_movement.stamp(canvas,"walljump_burst",walljump.anchor,walljump.age,reduced)
	if state.slide_ticks > 0 and not state.is_airborne() and velocity.length_squared() > 1000000.0:
		pixel_movement.stamp(canvas,"slide_trail",ground_anchor - velocity.normalized() * 14,age,reduced,velocity.angle(),0.65)
		var elapsed := maxi(0,config.milliseconds_to_ticks(MovementTuning.SLIDE_DURATION_MS) - state.slide_ticks)
		pixel_movement.stamp(canvas,"slide_dust",ground_anchor - velocity.normalized() * 14,elapsed,reduced,0.0,0.65)
	var contact := wall_contact_geometry(state)
	if not contact.is_empty() and velocity.length_squared() > 0.0:
		pixel_movement.stamp(canvas,"wallrun_sparks",contact_anchor + (contact.offset as Vector2),age,reduced)


func _draw_evasion_contour(
	canvas: CanvasItem,
	state: PlayerState,
	ground_anchor: Vector2,
	config: SimConfig,
	reduced: bool,
	body_height: float = 68.0,
) -> void:
	if state.health <= 0: return
	if state.spawn_protection_ticks <= 0 and not MovementSystem.is_combat_intangible(state, config):
		var recovery := evasion_recovery_contract(state,config)
		if not recovery.is_empty():
			for line: PackedVector2Array in recovery.lines:
				var points := _offset(line,ground_anchor)
				canvas.draw_polyline(points,Color("181c22"),4.0)
				canvas.draw_polyline(points,Color("e9bc7f"),2.0)
		return
	var contract := protection_contract(state, config, reduced, body_height)
	if not bool(contract["active"]):
		return
	if contract["kind"] == "invulnerable" and pixel_movement.protection(canvas,contract,ground_anchor,reduced):
		return
	var teal := language.ramp_color("deep_water", 4)
	var ink := language.ramp_color("deep_water", 0)
	# The shape, not hue or flashing, communicates protection in every profile.
	# No time interpolation or afterimage is permitted on this layer.
	for segment: PackedVector2Array in contract["brackets"]:
		var points := _offset(segment, ground_anchor)
		canvas.draw_polyline(points, Color(ink, 0.98), 6.0)
		canvas.draw_polyline(points, Color(teal, 1.0), 4.0)
		canvas.draw_polyline(points, Color.WHITE, 1.5)
	var shield := _offset(contract["shield"], ground_anchor)
	if shield.size() >= 3:
		canvas.draw_colored_polygon(shield, Color(ink, 0.98))
		canvas.draw_polyline(shield, Color(teal, 1.0), 4.0)
		canvas.draw_polyline(shield, Color.WHITE, 1.5)
	for line: PackedVector2Array in contract["badge_lines"]:
		var points := _offset(line, ground_anchor)
		canvas.draw_polyline(points, Color(ink, 0.98), 5.0)
		canvas.draw_polyline(points, Color.WHITE, 2.0)
	if int(contract["budget_pips"]) > 0:
		# Stable discrete remaining-window marks; never a flashing/fading tail.
		var top := -clampf(body_height, 40.0, 76.0) - 15.0
		for index: int in 3:
			var box := Rect2(ground_anchor+Vector2(13+index*5,top),Vector2(4,5))
			canvas.draw_rect(box.grow(1),Color(ink,0.98))
			if index < int(contract["budget_pips"]): canvas.draw_rect(box,Color.WHITE)


static func evasion_recovery_contract(state: PlayerState, config: SimConfig) -> Dictionary:
	# Two low flat bars mean the opaque, vulnerable tail of an admitted evade.
	# They never linger after the authoritative action, even at a low frame rate.
	if state == null or config == null or state.health <= 0 or state.air_dodge_ticks <= 0 or state.spawn_protection_ticks > 0 or MovementSystem.is_combat_intangible(state,config): return {}
	return {"kind":"vulnerable_recovery","body_tint":Color.WHITE,"lines":[PackedVector2Array([Vector2(-15,4),Vector2(-5,4)]),PackedVector2Array([Vector2(5,4),Vector2(15,4)])]}


static func protection_contract(state: PlayerState, config: SimConfig, _reduced: bool = false, body_height: float = 68.0) -> Dictionary:
	# Flight and height cues belong exclusively to JumpPresentation.height_contract.
	var result := {"active": false, "kind": "none", "brackets": [], "shield": PackedVector2Array(), "badge_lines": [], "remaining_ratio": 0.0, "body_tint": Color.WHITE, "budget_pips": 0}
	var ratio := JumpPresentation.protection_ratio(state, config)
	if ratio <= 0.0:
		return result
	result["active"] = true
	result["kind"] = "invulnerable" if state.spawn_protection_ticks > 0 else "intangible"
	result["remaining_ratio"] = ratio
	var top := -clampf(body_height, 40.0, 76.0) - 2.0
	var bottom := 2.0
	var brackets: Array[PackedVector2Array] = []
	for side: float in [-1.0, 1.0]:
		var x := 29.0 * side
		brackets.append(PackedVector2Array([Vector2(x - side * 7, top), Vector2(x, top), Vector2(x, top + 9)]))
		brackets.append(PackedVector2Array([Vector2(x - side * 7, bottom), Vector2(x, bottom), Vector2(x, bottom - 9)]))
	result["brackets"] = brackets
	var center := Vector2(0, top - 11.0)
	if result["kind"] == "intangible":
		# Immediately restore opaque pixels on the first vulnerable frame.
		# This is combat avoidance only; the body still collides with walls.
		result["body_tint"] = Color(1,1,1,0.62)
		result["budget_pips"] = clampi(ceili(ratio*3.0),1,3)
		# Timed damage avoidance is a split/slash shape, never a closed spawn
		# shield. This does not claim body phasing through world collisions.
		brackets.clear()
		for side: float in [-1.0, 1.0]:
			var x := 27.0 * side
			brackets.append(PackedVector2Array([Vector2(x - side * 6, top + 5), Vector2(x, top - 1)]))
			brackets.append(PackedVector2Array([Vector2(x - side * 6, bottom + 1), Vector2(x, bottom - 5)]))
		result["badge_lines"] = [PackedVector2Array([center + Vector2(-7, 4), center + Vector2(-1, -4)]), PackedVector2Array([center + Vector2(1, 4), center + Vector2(7, -4)])]
		return result
	result["shield"] = PackedVector2Array([center + Vector2(-5, -4), center + Vector2(5, -4), center + Vector2(4, 2), center + Vector2(0, 6), center + Vector2(-4, 2), center + Vector2(-5, -4)])
	return result


static func evasion_direction(state: PlayerState) -> String:
	if state == null:
		return "south"
	var velocity := Vector2i(state.velocity_x, state.velocity_y)
	if velocity != Vector2i.ZERO:
		return EightDirectionResolver.direction_id_from_vector(velocity.x, velocity.y)
	return EightDirectionResolver.direction_id_from_vector(state.facing_x, state.facing_y)


func _draw_directional_evasion_cue(
	canvas: CanvasItem,
	state: PlayerState,
	ground_anchor: Vector2,
	phase: float,
	color: Color,
	opacity: float,
) -> void:
	var direction_value := EightDirectionResolver.fixed_vector(evasion_direction(state))
	var direction := Vector2(float(direction_value.x), float(direction_value.y)).normalized()
	var side := direction.orthogonal()
	var length := 9.0 + phase * 4.0
	var start := ground_anchor - direction * (15.0 + phase * 3.0)
	for side_sign: float in [-1.0, 1.0]:
		var center := start + side * side_sign * 6.0
		canvas.draw_line(center, center - direction * length, Color(color, opacity * 0.72), 2.0)


func _validate_recipe(champion_id: String, value: Variant) -> bool:
	if not value is Dictionary:
		return _fail("Cartoon champion recipe must be an object: %s" % champion_id)
	var definition: Dictionary = value
	var body_type := String(definition.get("body_type", ""))
	if body_type not in EXPECTED_BODY_TYPES:
		return _fail("Cartoon champion body type is unsupported: %s" % champion_id)
	var body_template: Dictionary = body_templates.get(body_type, {})
	if body_template.is_empty() or (champion_id in REQUIRED_FOUNDATION and String(body_template.get("exemplar", "")) != champion_id) \
		or int(body_template.get("reference_height", 0)) != int(definition.get("height", 0)):
		return _fail("Cartoon champion does not match its reusable body template: %s" % champion_id)
	var atlas_row := int(definition.get("atlas_row", -1))
	var temporary := bool(definition.get("temporary_body_template", false))
	if temporary:
		var source_id := String(definition.get("template_source_id", ""))
		if source_id not in REQUIRED_FOUNDATION or not champions.has(source_id) \
			or atlas_row != int((champions[source_id] as Dictionary).get("atlas_row", -1)) \
			or body_type != String((champions[source_id] as Dictionary).get("body_type", "")):
			return _fail("Temporary recipe must retain its exact body template: " + champion_id)
	if champion_id not in REQUIRED_FOUNDATION and not temporary and atlas_row != 0:
		return _fail("Additional champion page rows must start at zero: " + champion_id)
	if atlas_row < 0 or atlas_row >= REQUIRED_FOUNDATION.size():
		return _fail("Cartoon champion atlas row is unsupported: %s" % champion_id)
	var height := int(definition.get("height", 0))
	var ratio := float(definition.get("head_ratio", 0.0))
	if height < 44 or height > 76 or ratio < 0.20 or ratio > 0.23:
		return _fail("Cartoon champion proportions exceed the gameplay contract: %s" % champion_id)
	var affinities: Array = definition.get("affinities", [])
	if affinities.size() < 2 or affinities.size() > 3:
		return _fail("Cartoon champion must expose two or three affinities: %s" % champion_id)
	for element_id: Variant in affinities:
		if String(element_id) not in VisualLanguage.REQUIRED_ELEMENTS:
			return _fail("Cartoon champion uses an unknown element: %s" % champion_id)
	var features: Array = definition.get("silhouette_features", [])
	if features.size() < 3 or String(definition.get("equipment", "")) != "body_clothing_only":
		return _fail("Cartoon champion lacks a distinct body/clothing read: %s" % champion_id)
	if String(definition.get("casting_origin", "")) != "hands":
		return _fail("Cartoon champion magic must originate from hands: %s" % champion_id)
	var casting_tokens := "%s %s" % [String(definition.get("equipment", "")), " ".join(features)]
	for forbidden_token: String in ["staff", "wand", "scepter", "rod", "focus_orb", "orb", "spell", "aura", "shadow", "projectile", "environment"]:
		if forbidden_token in casting_tokens.to_lower():
			return _fail("Cartoon champion uses a forbidden casting focus: %s" % champion_id)
	var motion_profile := String(definition.get("motion_profile", ""))
	if motion == null or not motion.has_profile(motion_profile):
		return _fail("Cartoon champion lacks a validated minimal-motion profile: %s" % champion_id)
	var materials: Dictionary = definition.get("materials", {})
	for material_id: String in ["outline", "skin_dark", "skin", "armor", "trim", "eye"]:
		var material: Array = materials.get(material_id, [])
		if material.size() != 2 or not language.ramps.has(String(material[0])) or int(material[1]) < 0 or int(material[1]) > 4:
			return _fail("Cartoon champion material is invalid: %s/%s" % [champion_id, material_id])
	return true


func _validate_cardinal_animation_contract(value: Variant) -> bool:
	if not value is Dictionary:
		return _fail("Cartoon champion cardinal animation contract must be an object")
	var contract: Dictionary = value
	if contract.get("directions", []) != EXPECTED_CARDINAL_DIRECTIONS:
		return _fail("Cartoon champion cardinal directions must be south, east, north, west")
	if contract.get("states", []) != EXPECTED_CARDINAL_STATES:
		return _fail("Cartoon champion cardinal action states are incomplete")
	if String(contract.get("coverage", "")) != "every_champion_has_every_state_in_every_cardinal_direction":
		return _fail("Cartoon champion cardinal action coverage is unsupported")
	if String(contract.get("row_layout", "")) != "champion_major_state_minor":
		return _fail("Cartoon champion cardinal atlas row layout is unsupported")
	if String(contract.get("diagonal_policy", "")) != "state_scoped_promoted_diagonals":
		return _fail("Cartoon champion diagonal direction policy is unsupported")
	cardinal_animation_contract = contract.duplicate(true)
	return true


func _validate_diagonal_core_contract(value: Variant) -> bool:
	diagonal_core_contract.clear()
	if not value is Dictionary:
		return _fail("Cartoon champion diagonal core contract must be an object")
	var contract: Dictionary = value
	if contract.get("directions", []) != EXPECTED_DIAGONAL_DIRECTIONS:
		return _fail("Cartoon champion diagonal core directions are incomplete")
	if contract.get("states", []) != EXPECTED_DIAGONAL_CORE_STATES:
		return _fail("Cartoon champion diagonal core states are incomplete")
	if String(contract.get("coverage", "")) != "every_foundation_champion_has_every_diagonal_core_cell":
		return _fail("Cartoon champion diagonal core coverage is unsupported")
	if contract.get("fallback_states", []) != []:
		return _fail("Cartoon champion diagonal core retains obsolete fallback states")
	if String(contract.get("fallback_policy", "")) != "none_all_states_promoted":
		return _fail("Cartoon champion diagonal fallback policy is unsupported")
	diagonal_core_contract = contract.duplicate(true)
	return true


func _validate_diagonal_locomotion_contract(value: Variant) -> bool:
	diagonal_locomotion_contract.clear()
	if not value is Dictionary:
		return _fail("Cartoon champion diagonal locomotion contract must be an object")
	var contract: Dictionary = value
	if contract.get("directions", []) != EXPECTED_DIAGONAL_DIRECTIONS:
		return _fail("Cartoon champion diagonal locomotion directions are incomplete")
	if contract.get("states", []) != EXPECTED_DIAGONAL_LOCOMOTION_STATES:
		return _fail("Cartoon champion diagonal locomotion states are incomplete")
	if String(contract.get("coverage", "")) != "every_foundation_champion_has_every_diagonal_locomotion_cell":
		return _fail("Cartoon champion diagonal locomotion coverage is unsupported")
	if contract.get("gaits", []) != EXPECTED_RELATIVE_GAITS:
		return _fail("Cartoon champion relative gait catalog is incomplete")
	if String(contract.get("facing_policy", "")) != "live_aim_all_poses_independent_of_travel" \
		or String(contract.get("authority", "")) != "presentation_only":
		return _fail("Cartoon champion locomotion facing policy is unsupported")
	diagonal_locomotion_contract = contract.duplicate(true)
	return true


func _validate_diagonal_evasion_contract(value: Variant) -> bool:
	diagonal_evasion_contract.clear()
	if not value is Dictionary:
		return _fail("Cartoon champion diagonal evasion contract must be an object")
	var contract: Dictionary = value
	if contract.get("directions", []) != EXPECTED_DIAGONAL_DIRECTIONS:
		return _fail("Cartoon champion diagonal evasion directions are incomplete")
	if contract.get("states", []) != EXPECTED_DIAGONAL_EVASION_STATES:
		return _fail("Cartoon champion diagonal evasion states are incomplete")
	if String(contract.get("coverage", "")) != "every_foundation_champion_has_every_diagonal_evasion_cell":
		return _fail("Cartoon champion diagonal evasion coverage is unsupported")
	if String(contract.get("art_status", "")) != "reviewed_source_integrated" \
		or String(contract.get("authority", "")) != "presentation_only":
		return _fail("Cartoon champion diagonal evasion policy is unsupported")
	diagonal_evasion_contract = contract.duplicate(true)
	return true


func _validate_locomotion_phase_contract(value: Variant) -> bool:
	locomotion_phase_contract.clear()
	if not value is Dictionary:
		return _fail("Cartoon champion locomotion phase contract must be an object")
	var contract: Dictionary = value
	if contract.get("states", []) != EXPECTED_PHASE_STATES:
		return _fail("Cartoon champion locomotion phase states are incomplete")
	var frame_states: Dictionary = contract.get("frame_states", {})
	if frame_states.get("walk", []) != ["walk", "walk_b"] \
		or frame_states.get("sprint", []) != ["sprint", "sprint_b"]:
		return _fail("Cartoon champion locomotion contact frames are incomplete")
	if String(contract.get("coverage", "")) != "two_contacts_per_champion_per_eight_directions" \
		or String(contract.get("timing", "")) != "motion_profile_half_cycle" \
		or String(contract.get("authority", "")) != "presentation_only":
		return _fail("Cartoon champion locomotion phase policy is unsupported")
	locomotion_phase_contract = contract.duplicate(true)
	return true


func _validate_semantic_state_aliases(value: Variant) -> bool:
	semantic_state_aliases.clear()
	if not value is Dictionary:
		return _fail("Cartoon champion semantic state aliases must be an object")
	var aliases: Dictionary = value
	var actual_actions: Array[String] = []
	for action_id: Variant in aliases.keys():
		if not action_id is String:
			return _fail("Cartoon champion semantic action IDs must be strings")
		actual_actions.append(String(action_id))
	var expected_actions := EXPECTED_SEMANTIC_ACTIONS.duplicate()
	actual_actions.sort()
	expected_actions.sort()
	if actual_actions != expected_actions:
		return _fail("Cartoon champion semantic action coverage is incomplete")
	for action_id: String in expected_actions:
		var atlas_state := String(aliases.get(action_id, ""))
		if atlas_state not in EXPECTED_CARDINAL_STATES:
			return _fail("Cartoon champion semantic action targets an unsupported atlas state: %s" % action_id)
	semantic_state_aliases = aliases.duplicate(true)
	return true


static func _offset(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var output := PackedVector2Array()
	for point: Vector2 in points:
		output.append(point + offset)
	return output


static func _vector2i(value: Variant) -> Vector2i:
	if not value is Array or value.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(value[0]), int(value[1]))


func _fail(message: String) -> bool:
	last_error = message
	return false


static func _sha256(path: String) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(FileAccess.get_file_as_bytes(path)) != OK:
		return ""
	return context.finish().hex_encode()


static func _bytes_sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(bytes) != OK:
		return ""
	return context.finish().hex_encode()
