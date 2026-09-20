class_name MinimalChampionMotion
extends RefCounted


const DEFAULT_PATH := "res://content/visual/minimal_champion_motion_v1.json"
const EXPECTED_ID := "minimal-champion-motion-v1"
const EXPECTED_AUTHORITY := "presentation only; motion samples never change simulation position, collision, timing or outcomes"
const REQUIRED_MOTIONS := ["idle", "walk", "sprint", "low", "air", "cast", "hit"]
const REQUIRED_ACCENTS := ["counter_strafe", "double_jump", "slide", "slide_jump", "air_dodge", "roll", "wave_dash", "wall_kick", "vault", "superglide", "fast_fall", "wall_skim", "impact_recovery"]
const ALLOWED_ACCENT_KINDS := ["brake_ticks", "lift_ring", "ground_wake", "speed_fins", "ground_chevron", "kick_burst", "crest_arc", "fall_lines", "wall_sparks", "recovery_brace"]
const LOCOMOTION_FULL_STRIDE_HEIGHT_RATIO := 1.30


class Sample:
	extends RefCounted

	var offset := Vector2.ZERO
	var scale := Vector2.ONE
	var aura_scale := 1.0


var profiles: Dictionary = {}
var movement_accents: Dictionary = {}
var content_hash := ""
var last_error := ""


func load_from_file(path: String = DEFAULT_PATH) -> bool:
	profiles.clear()
	movement_accents.clear()
	content_hash = ""
	last_error = ""
	if not FileAccess.file_exists(path):
		return _fail("Minimal champion motion data does not exist: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("Minimal champion motion data cannot be opened")
	var source := file.get_as_text()
	var parsed: Variant = JSON.parse_string(source)
	if not parsed is Dictionary:
		return _fail("Minimal champion motion root must be an object")
	var data: Dictionary = parsed
	if int(data.get("schema_version", -1)) != 1 or String(data.get("id", "")) != EXPECTED_ID:
		return _fail("Minimal champion motion identity is unsupported")
	if String(data.get("authority", "")) != EXPECTED_AUTHORITY or int(data.get("base_hz", 0)) != 60:
		return _fail("Minimal champion motion must remain presentation-only at the 60 Hz visual base")
	profiles = data.get("profiles", {})
	if profiles.is_empty():
		return _fail("Minimal champion motion requires at least one profile")
	for profile_id: String in profiles:
		if not _validate_profile(profile_id, profiles[profile_id]):
			profiles.clear()
			return false
	movement_accents = data.get("movement_accents", {})
	for accent_id: String in REQUIRED_ACCENTS:
		if not movement_accents.has(accent_id) or not _validate_accent(accent_id, movement_accents[accent_id]):
			profiles.clear()
			movement_accents.clear()
			return false
	content_hash = source.sha256_text()
	return true


func has_profile(profile_id: String) -> bool:
	return profiles.has(profile_id)


func accent(state: PlayerState) -> Dictionary:
	if state == null:
		return {}
	var accent_id := String(PlayerState.MovementMode.keys()[state.movement_mode]).to_lower()
	return (movement_accents.get(accent_id, {}) as Dictionary).duplicate(true)


func accent_by_id(accent_id: String) -> Dictionary:
	return (movement_accents.get(accent_id, {}) as Dictionary).duplicate(true)


func sample(profile_id: String, motion_id: String, elapsed_ticks_at_60: float, reduced_motion: bool = false) -> Sample:
	var result := Sample.new()
	if not profiles.has(profile_id):
		return result
	var profile: Dictionary = profiles[profile_id]
	if not profile.has(motion_id):
		return result
	var motion: Dictionary = profile[motion_id]
	var duration := float(motion.get("duration_ticks", 1))
	var elapsed := maxf(0.0, elapsed_ticks_at_60)
	var phase := fposmod(elapsed, duration) / duration if bool(motion.get("loop", false)) else minf(elapsed / duration, 1.0)
	var keyframes: Array = motion.get("keyframes", [])
	var left: Dictionary = keyframes[0]
	var right: Dictionary = keyframes[keyframes.size() - 1]
	for index: int in range(keyframes.size() - 1):
		var candidate_left: Dictionary = keyframes[index]
		var candidate_right: Dictionary = keyframes[index + 1]
		if phase >= float(candidate_left.get("at", 0.0)) and phase <= float(candidate_right.get("at", 1.0)):
			left = candidate_left
			right = candidate_right
			break
	var span := maxf(0.0001, float(right.get("at", 1.0)) - float(left.get("at", 0.0)))
	var blend := clampf((phase - float(left.get("at", 0.0))) / span, 0.0, 1.0)
	blend = smoothstep(0.0, 1.0, blend)
	result.offset = _vector2(left.get("offset", []), Vector2.ZERO).lerp(_vector2(right.get("offset", []), Vector2.ZERO), blend)
	# Body dimensions belong to the three atlas templates. Motion may translate
	# the pose and animate detached aura layers, but never resize body pixels.
	result.scale = Vector2.ONE
	result.aura_scale = lerpf(float(left.get("aura", 1.0)), float(right.get("aura", 1.0)), blend)
	if reduced_motion:
		result.offset *= 0.35
		result.aura_scale = lerpf(1.0, result.aura_scale, 0.35)
	return result


func locomotion_pivot_offset(profile_id: String, motion_id: String, elapsed_ticks_at_60: float, direction: Vector2, response: float, reduced_motion: bool = false) -> Vector2:
	if motion_id not in ["walk", "sprint"] or not profiles.has(profile_id):
		return Vector2.ZERO
	var profile: Dictionary = profiles[profile_id]
	var duration := float((profile.get(motion_id, {}) as Dictionary).get("duration_ticks", 1))
	var phase := fposmod(maxf(0.0, elapsed_ticks_at_60), maxf(1.0, duration)) / maxf(1.0, duration)
	var strength := clampf(response, 0.0, 1.0) * (0.25 if reduced_motion else 1.0)
	# Contact A and B remain discrete crisp atlas frames. This tiny continuous
	# pivot path returns to zero at both foot plants; body scale never changes.
	var airborne_fraction := pow(sin(TAU * phase), 2.0)
	var bob := -airborne_fraction * (1.25 if motion_id == "sprint" else 0.85)
	var lean := direction.normalized() * sin(4.0 * PI * phase) * 0.35
	return (Vector2(0.0, bob) + lean) * strength


func locomotion_contact_frame(profile_id: String, motion_id: String, elapsed_ticks_at_60: float, phase_seed: int = 0) -> int:
	if motion_id not in ["walk", "sprint"] or not profiles.has(profile_id):
		return 0
	var profile: Dictionary = profiles[profile_id]
	if not profile.has(motion_id):
		return 0
	var duration := float((profile[motion_id] as Dictionary).get("duration_ticks", 1))
	if duration <= 0.0:
		return 0
	var phase := fposmod(maxf(0.0, elapsed_ticks_at_60) + float(phase_seed), duration) / duration
	return 1 if phase >= 0.5 else 0


static func locomotion_stride_pixels(body_height: float) -> float:
	# Two contacts per full cycle: each step travels 0.65 body heights. Using
	# 0.65 for the *whole* cycle would flicker two-frame art at ~17 contacts/sec.
	var height := body_height if is_finite(body_height) else 68.0
	return clampf(height, 40.0, 96.0) * LOCOMOTION_FULL_STRIDE_HEIGHT_RATIO


func locomotion_elapsed_at_phase(profile_id: String, motion_id: String, normalized_phase: float) -> float:
	if motion_id not in ["walk", "sprint"] or not profiles.has(profile_id) or not is_finite(normalized_phase):
		return 0.0
	var duration := float((profiles[profile_id].get(motion_id, {}) as Dictionary).get("duration_ticks", 1))
	return fposmod(normalized_phase, 1.0) * duration


static func motion_id(state: PlayerState) -> String:
	if state.movement_mode in [PlayerState.MovementMode.LAUNCHED, PlayerState.MovementMode.GRAPPLED, PlayerState.MovementMode.STUNNED, PlayerState.MovementMode.IMPACT_RECOVERY] \
		or state.control_state in [PlayerState.ControlState.LAUNCHED, PlayerState.ControlState.GRAPPLED, PlayerState.ControlState.STUNNED]:
		return "hit"
	if state.pending_cast_wire_id > 0 or state.movement_mode == PlayerState.MovementMode.CHARGING or state.last_event.begins_with("cast_start_"):
		return "cast"
	if state.is_airborne() or state.movement_mode in [
		PlayerState.MovementMode.HOP,
		PlayerState.MovementMode.DOUBLE_JUMP,
		PlayerState.MovementMode.SLIDE_JUMP,
		PlayerState.MovementMode.AIR_DODGE,
		PlayerState.MovementMode.WALL_KICK,
		PlayerState.MovementMode.VAULT,
		PlayerState.MovementMode.SUPERGLIDE,
		PlayerState.MovementMode.FAST_FALL,
	]:
		return "air"
	if state.movement_mode in [PlayerState.MovementMode.SLIDE, PlayerState.MovementMode.ROLL, PlayerState.MovementMode.WAVE_DASH, PlayerState.MovementMode.WALL_SKIM]:
		return "low"
	if state.movement_mode == PlayerState.MovementMode.SPRINT:
		return "sprint"
	if state.movement_mode in [PlayerState.MovementMode.WALK, PlayerState.MovementMode.SLOWED]:
		return "walk"
	return "idle"


static func elapsed_for_state(state: PlayerState, motion_id_value: String, visual_tick: float, config: SimConfig) -> float:
	if state == null or config == null:
		return maxf(0.0, visual_tick)
	if motion_id_value == "air":
		var timer := _air_timer(state, config)
		if timer.y > 0:
			return float(timer.y - timer.x) * 60.0 / float(config.tick_rate)
	if motion_id_value == "cast" and state.pending_cast_wire_id > 0:
		var definition := CombatTuning.cast_definition(state.pending_cast_wire_id)
		var total := config.milliseconds_to_ticks(int(definition.get("startup_ms", 0)))
		if total > 0:
			return float(maxi(0, total - state.pending_cast_ticks)) * 60.0 / float(config.tick_rate)
	return maxf(0.0, visual_tick)


static func _air_timer(state: PlayerState, config: SimConfig) -> Vector2i:
	if state.hop_ticks > 0:
		var duration_ms := MovementTuning.HOP_DURATION_MS
		if state.hop_mode == PlayerState.MovementMode.DOUBLE_JUMP:
			duration_ms = MovementTuning.DOUBLE_JUMP_DURATION_MS
		elif state.hop_mode == PlayerState.MovementMode.SLIDE_JUMP:
			duration_ms = MovementTuning.SLIDE_JUMP_DURATION_MS
		return Vector2i(state.hop_ticks, config.milliseconds_to_ticks(duration_ms))
	if state.air_dodge_ticks > 0:
		return Vector2i(state.air_dodge_ticks, config.milliseconds_to_ticks(MovementTuning.AIR_DODGE_DURATION_MS))
	if state.vault_ticks > 0:
		return Vector2i(state.vault_ticks, config.milliseconds_to_ticks(MovementTuning.VAULT_DURATION_MS))
	if state.superglide_ticks > 0:
		return Vector2i(state.superglide_ticks, config.milliseconds_to_ticks(MovementTuning.SUPERGLIDE_DURATION_MS))
	return Vector2i.ZERO


static func tick_at_visual_rate(simulation_tick: int, tick_rate: int, interpolation_alpha: float = 0.0) -> float:
	if tick_rate <= 0:
		return 0.0
	return (float(simulation_tick) + clampf(interpolation_alpha, 0.0, 1.0)) * 60.0 / float(tick_rate)


func _validate_profile(profile_id: String, value: Variant) -> bool:
	if profile_id.is_empty() or not value is Dictionary:
		return _fail("Champion motion profile must be a named object")
	var profile: Dictionary = value
	for motion_id: String in REQUIRED_MOTIONS:
		if not profile.has(motion_id) or not _validate_motion(profile_id, motion_id, profile[motion_id]):
			return false
	return true


func _validate_motion(profile_id: String, motion_id: String, value: Variant) -> bool:
	if not value is Dictionary:
		return _fail("Champion motion must be an object: %s/%s" % [profile_id, motion_id])
	var motion: Dictionary = value
	var duration := int(motion.get("duration_ticks", 0))
	var keyframes: Array = motion.get("keyframes", [])
	if duration < 8 or duration > 180 or keyframes.size() < 2 or keyframes.size() > 6:
		return _fail("Champion motion duration/keyframe budget is invalid: %s/%s" % [profile_id, motion_id])
	var previous_at := -1.0
	for index: int in range(keyframes.size()):
		if not keyframes[index] is Dictionary:
			return _fail("Champion motion keyframe must be an object: %s/%s" % [profile_id, motion_id])
		var keyframe: Dictionary = keyframes[index]
		var at := float(keyframe.get("at", -1.0))
		var offset := _vector2(keyframe.get("offset", []), Vector2(99.0, 99.0))
		var scale := _vector2(keyframe.get("scale", []), Vector2.ZERO)
		var aura := float(keyframe.get("aura", 0.0))
		if at <= previous_at or offset.abs().x > 4.0 or offset.abs().y > 4.0 \
			or scale.x < 0.94 or scale.x > 1.06 or scale.y < 0.94 or scale.y > 1.06 \
			or aura < 0.8 or aura > 1.2:
			return _fail("Champion motion keyframe exceeds minimal-motion bounds: %s/%s" % [profile_id, motion_id])
		previous_at = at
	if not is_equal_approx(float((keyframes[0] as Dictionary).get("at", -1.0)), 0.0) \
		or not is_equal_approx(float((keyframes[keyframes.size() - 1] as Dictionary).get("at", -1.0)), 1.0):
		return _fail("Champion motion must begin at zero and end at one: %s/%s" % [profile_id, motion_id])
	return true


func _validate_accent(accent_id: String, value: Variant) -> bool:
	if not value is Dictionary:
		return _fail("Movement accent must be an object: %s" % accent_id)
	var accent: Dictionary = value
	if String(accent.get("kind", "")) not in ALLOWED_ACCENT_KINDS:
		return _fail("Movement accent kind is unsupported: %s" % accent_id)
	if not language_ramp_is_declared(String(accent.get("ramp", ""))):
		return _fail("Movement accent ramp is unsupported: %s" % accent_id)
	var index := int(accent.get("index", -1))
	var opacity := float(accent.get("opacity", 0.0))
	if index < 0 or index > 4 or opacity < 0.25 or opacity > 0.65:
		return _fail("Movement accent value is unsafe: %s" % accent_id)
	return true


static func language_ramp_is_declared(ramp_id: String) -> bool:
	return ramp_id in ["aged_brass", "warm_stone", "deep_water", "garden", "timber", "worldbone", "parchment", "indigo_roof", "health", "flux", "stamina"]


static func _vector2(value: Variant, fallback: Vector2) -> Vector2:
	if not value is Array or value.size() != 2:
		return fallback
	return Vector2(float(value[0]), float(value[1]))


func _fail(message: String) -> bool:
	last_error = message
	return false
