class_name PhysicalAttackTuning
extends RefCounted

## Validated, bounded S5 physical attack content.
##
## The candidate path is intentionally isolated. Promotion changes DEFAULT_PATH
## to res://content/combat/physical_attacks_v1.json after moving the JSON there.

const DEFAULT_PATH := "res://.agent/candidates/gameplay_s5/content/combat/physical_attacks_v1.json"
const VERSION := 1
const COMPATIBILITY_ID := "physical-attacks-s5-v1"
const PUNCH := 1
const KICK := 2
const REQUIRED_IDS := {"punch": PUNCH, "kick": KICK}
const MAX_BYTES := 16_384

static var _shared: PhysicalAttackTuning

var last_error := ""
var content_hash := ""
var tick_rate := 0
var height_tolerance := 0
var buffer_window_ticks := 0
var knockback_guard_ticks := 0
var _profiles: Dictionary = {}


func load_from_file(path: String = DEFAULT_PATH) -> bool:
	var candidate_error := ""
	if path.is_empty() or not FileAccess.file_exists(path):
		candidate_error = "physical attack tuning file is unavailable"
	else:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			candidate_error = "physical attack tuning file cannot be opened"
		elif file.get_length() <= 0 or file.get_length() > MAX_BYTES:
			candidate_error = "physical attack tuning file size is invalid"
		else:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if not parsed is Dictionary:
				candidate_error = "physical attack tuning JSON is malformed"
			else:
				var staged := _validate_and_stage(parsed)
				candidate_error = String(staged.error)
				if candidate_error.is_empty():
					tick_rate = int(staged.tick_rate)
					height_tolerance = int(staged.height_tolerance)
					buffer_window_ticks = int(staged.buffer_window_ticks)
					knockback_guard_ticks = int(staged.knockback_guard_ticks)
					_profiles = staged.profiles
					content_hash = CanonicalContent.sha256(parsed)
					last_error = ""
					return true
	last_error = candidate_error
	return false


func is_valid() -> bool:
	return (
		last_error.is_empty()
		and content_hash.length() == 64
		and tick_rate == 120
		and height_tolerance == 24_000
		and buffer_window_ticks == 10
		and knockback_guard_ticks == 48
		and _profiles.size() == 2
	)


func profile(kind: int) -> Dictionary:
	return (_profiles.get(kind, {}) as Dictionary).duplicate(true)


static func shared() -> PhysicalAttackTuning:
	if _shared == null:
		var candidate := PhysicalAttackTuning.new()
		candidate.load_from_file()
		_shared = candidate
	return _shared


static func reset_shared_for_tests() -> void:
	_shared = null


func _validate_and_stage(value: Dictionary) -> Dictionary:
	var exact_keys := ["version", "compatibility_id", "tick_rate", "height_tolerance", "buffer_window_ticks", "knockback_guard_ticks", "attacks"]
	if not _has_exact_keys(value, exact_keys):
		return {"error": "physical attack tuning root schema is invalid"}
	if not _whole(value.version) or int(value.version) != VERSION or String(value.compatibility_id) != COMPATIBILITY_ID:
		return {"error": "physical attack tuning identity is invalid"}
	if not _whole(value.tick_rate) or int(value.tick_rate) != 120:
		return {"error": "physical attacks require the 120 Hz authority"}
	if not _whole(value.height_tolerance) or int(value.height_tolerance) != 24_000:
		return {"error": "physical attack height tolerance is invalid"}
	if not _whole(value.buffer_window_ticks) or int(value.buffer_window_ticks) != 10:
		return {"error": "physical attack buffer window is invalid"}
	if not _whole(value.knockback_guard_ticks) or int(value.knockback_guard_ticks) != 48:
		return {"error": "physical attack knockback guard is invalid"}
	if not value.attacks is Array or value.attacks.size() != REQUIRED_IDS.size():
		return {"error": "physical attack tuning must contain Punch and Kick exactly once"}

	var staged_profiles := {}
	var seen_ids := {}
	var attack_keys := ["id", "kind", "stamina_cost", "damage", "startup_ticks", "active_ticks", "recovery_ticks", "reach", "half_arc_cosine_squared", "knockback"]
	for raw: Variant in value.attacks:
		if not raw is Dictionary or not _has_exact_keys(raw, attack_keys):
			return {"error": "physical attack entry schema is invalid"}
		var id := String(raw.id)
		if not REQUIRED_IDS.has(id) or seen_ids.has(id) or not _whole(raw.kind) or int(raw.kind) != int(REQUIRED_IDS[id]):
			return {"error": "physical attack ID or kind is invalid"}
		for key: String in ["stamina_cost", "damage", "startup_ticks", "active_ticks", "recovery_ticks", "reach", "half_arc_cosine_squared", "knockback"]:
			if not _whole(raw[key]):
				return {"error": "physical attack %s is not an integer" % key}
		var profile := {
			"id": id,
			"kind": int(raw.kind),
			"stamina_cost": int(raw.stamina_cost),
			"damage": int(raw.damage),
			"startup_ticks": int(raw.startup_ticks),
			"active_ticks": int(raw.active_ticks),
			"recovery_ticks": int(raw.recovery_ticks),
			"reach": int(raw.reach),
			"half_arc_cosine_squared": int(raw.half_arc_cosine_squared),
			"knockback": int(raw.knockback),
		}
		if not _profile_bounds_valid(profile):
			return {"error": "physical attack numeric bounds are invalid for %s" % id}
		seen_ids[id] = true
		staged_profiles[int(profile.kind)] = profile
	if seen_ids.size() != REQUIRED_IDS.size():
		return {"error": "physical attack tuning is incomplete"}
	return {
		"error": "",
		"tick_rate": int(value.tick_rate),
		"height_tolerance": int(value.height_tolerance),
		"buffer_window_ticks": int(value.buffer_window_ticks),
		"knockback_guard_ticks": int(value.knockback_guard_ticks),
		"profiles": staged_profiles,
	}


static func _profile_bounds_valid(profile: Dictionary) -> bool:
	return (
		int(profile.stamina_cost) > 0 and int(profile.stamina_cost) <= 100_000
		and int(profile.damage) > 0 and int(profile.damage) <= 100_000
		and int(profile.startup_ticks) > 0 and int(profile.startup_ticks) <= 120
		and int(profile.active_ticks) > 0 and int(profile.active_ticks) <= 120
		and int(profile.recovery_ticks) > 0 and int(profile.recovery_ticks) <= 240
		and int(profile.reach) >= 1_000 and int(profile.reach) <= 128_000
		and int(profile.half_arc_cosine_squared) > 0 and int(profile.half_arc_cosine_squared) < 1_000_000
		and int(profile.knockback) > 0 and int(profile.knockback) <= 128_000
	)


static func _whole(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT) or (typeof(value) == TYPE_FLOAT and is_equal_approx(value, floor(value)))


static func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key: String in expected:
		if not value.has(key):
			return false
	return true
