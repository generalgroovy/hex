class_name VisualAccessibilityFilter
extends CanvasLayer


const CATALOG_PATH: String = "res://content/visual/accessibility_profiles_v1.json"
const SHADER_PATH: String = "res://assets/shaders/visual_accessibility.gdshader"
const REQUIRED_PROFILE_IDS: Array[String] = [
	"standard",
	"high_contrast",
	"grayscale",
	"protanopia",
	"deuteranopia",
	"tritanopia",
]
const PLAYER_PROFILE_IDS: Array[String] = ["standard", "high_contrast"]

var data: Dictionary = {}
var profiles_by_id: Dictionary = {}
var content_hash: String = ""
var current_profile_id: String = "standard"
var last_error: String = ""
var overlay: ColorRect
var shader_material: ShaderMaterial


func configure() -> bool:
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		return _fail("Accessibility profile catalog is missing")
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return _fail("Accessibility profile catalog must be one JSON object")
	data = parsed
	if int(data.get("schema_version", 0)) != 1:
		return _fail("Accessibility profile catalog requires schema_version 1")
	profiles_by_id = {}
	var shader_modes: Dictionary = {}
	for value: Variant in data.get("profiles", []):
		if not value is Dictionary:
			return _fail("Accessibility profiles must be objects")
		var profile: Dictionary = value
		var profile_id := String(profile.get("id", ""))
		var kind := String(profile.get("kind", ""))
		var shader_mode := int(profile.get("shader_mode", -1))
		if profile_id.is_empty() or profiles_by_id.has(profile_id):
			return _fail("Accessibility profile IDs must be non-empty and unique")
		if kind not in ["player", "review"] or shader_mode < 0 or shader_modes.has(shader_mode):
			return _fail("Accessibility profiles require a unique non-negative shader mode and valid kind")
		profiles_by_id[profile_id] = profile
		shader_modes[shader_mode] = true
	if _sorted_strings(profiles_by_id.keys()) != _sorted_strings(REQUIRED_PROFILE_IDS):
		return _fail("Accessibility profile coverage must match the required live/review set")
	if _string_array(data.get("player_cycle", [])) != PLAYER_PROFILE_IDS:
		return _fail("Accessibility player cycle must remain Standard then High Contrast")
	if _sorted_strings(data.get("review_only", [])) != _sorted_strings(["grayscale", "protanopia", "deuteranopia", "tritanopia"]):
		return _fail("Accessibility review-only profile set is incomplete")
	var screen_filter: Dictionary = data.get("screen_filter", {})
	if (
		String(screen_filter.get("shader_path", "")) != SHADER_PATH
		or String(screen_filter.get("provenance", "")).is_empty()
		or String(screen_filter.get("license", "")).is_empty()
		or int(screen_filter.get("maximum_passes", 0)) != 1
	):
		return _fail("Accessibility screen filter requires exact path, provenance, license and one-pass budget")
	var reduced: Dictionary = data.get("reduced_effects", {})
	if not bool(reduced.get("preserve_shape_timing_impact", false)) or int(reduced.get("maximum_particle_percent", 0)) != 35:
		return _fail("Reduced-effects contract must preserve shape/timing/impact at the 35 percent density budget")
	var shader_resource: Resource = load(SHADER_PATH)
	if not shader_resource is Shader:
		return _fail("Accessibility screen shader is missing or invalid")
	shader_material = ShaderMaterial.new()
	shader_material.shader = shader_resource as Shader
	overlay = ColorRect.new()
	overlay.name = "VisualAccessibilityScreenFilter"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.material = shader_material
	add_child(overlay)
	layer = 120
	content_hash = "%s:%s" % [FileAccess.get_sha256(CATALOG_PATH), FileAccess.get_sha256(SHADER_PATH)]
	return set_profile("standard")


func set_profile(profile_id: String) -> bool:
	if not profiles_by_id.has(profile_id) or overlay == null or shader_material == null:
		last_error = "Unknown or unavailable accessibility profile: %s" % profile_id
		return false
	current_profile_id = profile_id
	shader_material.set_shader_parameter("profile_mode", int((profiles_by_id[profile_id] as Dictionary).get("shader_mode", 0)))
	overlay.visible = profile_id != "standard"
	last_error = ""
	return true


func player_profile_label(profile_id: String) -> String:
	if profile_id not in PLAYER_PROFILE_IDS or not profiles_by_id.has(profile_id):
		return "UNKNOWN"
	return String((profiles_by_id[profile_id] as Dictionary).get("label", profile_id)).to_upper()


static func player_profile_for(high_contrast: bool) -> String:
	return "high_contrast" if high_contrast else "standard"


static func parse_capture_profile(argument: String) -> String:
	if not argument.begins_with("--capture-visual-profile="):
		return ""
	var profile_id := argument.trim_prefix("--capture-visual-profile=").strip_edges().to_lower()
	return profile_id if profile_id in REQUIRED_PROFILE_IDS else ""


static func has_reduced_effects_capture_argument(argument: String) -> bool:
	return argument == "--capture-reduced-effects"


func _fail(message: String) -> bool:
	last_error = message
	data = {}
	profiles_by_id = {}
	content_hash = ""
	return false


static func _string_array(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if values is Array:
		for value: Variant in values:
			result.append(String(value))
	return result


static func _sorted_strings(values: Variant) -> Array[String]:
	var result := _string_array(values)
	result.sort()
	return result
