class_name BodyTypeProfileCatalog
extends RefCounted


const DEFAULT_PATH := "res://content/champions/body_type_profiles_v1.json"
const EXPECTED_ID := "body-type-profiles-v1-equal-budget"
const BODY_TYPES: Array[String] = ["small", "middle", "large"]
const HURT_RADII := {"small": 17_000, "middle": 18_000, "large": 19_000}
const STAT_NAMES: Array[String] = [
	"health_maximum",
	"health_recovery_per_second",
	"flux_maximum",
	"flux_recovery_per_second",
	"stamina_maximum",
	"stamina_recovery_per_second",
	"movement_speed_ratio",
]

var data: Dictionary = {}
var profiles: Dictionary = {}
var shared_rules: Dictionary = {}
var content_hash := ""
var last_error := ""


func load_from_file(path: String = DEFAULT_PATH) -> bool:
	data.clear()
	profiles.clear()
	shared_rules.clear()
	content_hash = ""
	last_error = ""
	if not FileAccess.file_exists(path):
		return _fail("body-type profile catalog does not exist: %s" % path)
	var source := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(source)
	if not parsed is Dictionary:
		return _fail("body-type profile catalog root must be an object")
	data = parsed
	if not validate():
		return false
	content_hash = source.sha256_text()
	return true


func validate() -> bool:
	last_error = ""
	profiles.clear()
	shared_rules.clear()
	if int(data.get("schema_version", -1)) != 1 or String(data.get("id", "")) != EXPECTED_ID:
		return _fail("body-type profile identity is unsupported")
	if String(data.get("authority", "")) != "simulation bounds and player-facing role contract; body type never grants automatic damage":
		return _fail("body-type profiles must preserve the no-automatic-damage rule")
	var rules_value: Variant = data.get("shared_rules", {})
	var profiles_value: Variant = data.get("profiles", {})
	if not rules_value is Dictionary or not profiles_value is Dictionary:
		return _fail("body-type shared rules and profiles must be objects")
	shared_rules = rules_value
	profiles = profiles_value
	if int(shared_rules.get("competitive_budget", 0)) != 100 \
		or String(shared_rules.get("collision_radius_policy", "")) != "shared_foundation_radius" \
		or String(shared_rules.get("hurt_radius_policy", "")) != "fixed_body_profile_independent_of_animation" \
		or shared_rules.get("visual_template_order", []) != BODY_TYPES \
		or String(shared_rules.get("visual_size_authority", "")) != "presentation_only_no_hidden_reach_evasion_or_damage" \
		or (shared_rules.get("universal_movement", []) as Array).size() < 10:
		return _fail("body types require one equal budget, shared collision policy and universal movement access")
	var visual_heights: Dictionary = shared_rules.get("visual_template_height_pixels", {})
	var expected_visual_heights := {"small": 58, "middle": 68, "large": 76}
	for body_type: String in BODY_TYPES:
		if not visual_heights.has(body_type) or int(visual_heights[body_type]) != int(expected_visual_heights[body_type]):
			return _fail("body-type visual height progression is unsupported: %s" % body_type)
	if profiles.keys().size() != BODY_TYPES.size():
		return _fail("body-type catalog must define exactly small, middle and large")
	for body_type: String in BODY_TYPES:
		if not profiles.has(body_type) or not profiles[body_type] is Dictionary:
			return _fail("body-type profile is missing: %s" % body_type)
		var profile: Dictionary = profiles[body_type]
		var hurt_value: Variant = profile.get("hurt_radius", null)
		if not (hurt_value is int or hurt_value is float) or float(hurt_value) != float(HURT_RADII[body_type]):
			return _fail("body-type hurt radius is unsupported: %s" % body_type)
		if String(profile.get("role", "")).is_empty() \
			or (profile.get("strengths", []) as Array).size() < 2 \
			or (profile.get("tradeoffs", []) as Array).size() < 2:
			return _fail("body-type profile needs a role, strengths and tradeoffs: %s" % body_type)
		var bounds: Dictionary = profile.get("stat_bounds", {})
		if bounds.size() != STAT_NAMES.size():
			return _fail("body-type stat bounds are incomplete: %s" % body_type)
		for stat_name: String in STAT_NAMES:
			var interval: Variant = bounds.get(stat_name, [])
			if not interval is Array or (interval as Array).size() != 2 \
				or int((interval as Array)[0]) < 0 or int((interval as Array)[1]) < int((interval as Array)[0]):
				return _fail("body-type stat interval is invalid: %s/%s" % [body_type, stat_name])
	return true


func accepts(body_type: String, stats: Dictionary) -> bool:
	if not profiles.has(body_type):
		return false
	var bounds: Dictionary = (profiles[body_type] as Dictionary).get("stat_bounds", {})
	for stat_name: String in STAT_NAMES:
		var interval: Array = bounds.get(stat_name, [])
		var value := int(stats.get(stat_name, -1))
		if interval.size() != 2 or value < int(interval[0]) or value > int(interval[1]):
			return false
	return true


func role(body_type: String) -> String:
	return String((profiles.get(body_type, {}) as Dictionary).get("role", ""))


func hurt_radius(body_type: String) -> int:
	return int((profiles.get(body_type, {}) as Dictionary).get("hurt_radius", 0))


func _fail(message: String) -> bool:
	last_error = message
	return false
