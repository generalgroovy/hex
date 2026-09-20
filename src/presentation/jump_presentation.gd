class_name JumpPresentation
extends RefCounted


const NORMAL_REFERENCE_LIFT_PIXELS: float = 76.0
const REDUCED_HEIGHT_RATIO: float = 0.18
const MAXIMUM_INTERPOLATION_STEP: int = 32_000
const GROUND_SHADOW_SCALE := Vector2(0.90, 0.32)
const NORMAL_APEX_SHADOW_SCALE := Vector2(1.50, 0.56)
const REDUCED_APEX_SHADOW_SCALE := Vector2(1.18, 0.42)
const GROUND_SHADOW_OPACITY: float = 0.22
const NORMAL_APEX_SHADOW_OPACITY: float = 0.52
const REDUCED_APEX_SHADOW_OPACITY: float = 0.48


class Sample:
	extends RefCounted

	var active: bool = false
	var normalized_phase: float = 0.0
	var arc_ratio: float = 0.0
	var body_lift_pixels: float = 0.0
	var shadow_scale: Vector2 = GROUND_SHADOW_SCALE
	var shadow_opacity: float = GROUND_SHADOW_OPACITY
	var protection_active: bool = false
	var protection_remaining_ratio: float = 0.0


static func sample(
	state: PlayerState,
	config: SimConfig,
	interpolation_alpha: float = 0.0,
	reduced_motion: bool = false,
	previous_height: int = -1,
) -> Sample:
	var result := Sample.new()
	if state == null or config == null:
		return result
	result.protection_remaining_ratio = protection_ratio(state, config)
	result.protection_active = result.protection_remaining_ratio > 0.0
	if state.health <= 0 or state.air_height <= 0:
		return result
	result.active = true
	# Physical height survives Float, dodge and wall-mode changes. Only
	# the previous accepted height is interpolated: never restart a timer arc,
	# extrapolate a new position, smooth facing, or delay protection changes.
	var physical_height := float(state.air_height)
	if previous_height >= 0 and absi(previous_height - state.air_height) <= MAXIMUM_INTERPOLATION_STEP:
		physical_height = lerpf(float(previous_height), physical_height, clampf(interpolation_alpha, 0.0, 1.0))
	var height_pixels := maxf(0.0, physical_height) / float(SimConfig.FIXED_SCALE)
	result.arc_ratio = clampf(height_pixels / NORMAL_REFERENCE_LIFT_PIXELS, 0.0, 1.0)
	result.normalized_phase = result.arc_ratio * 0.5 if state.air_vertical_velocity >= 0 else 1.0 - result.arc_ratio * 0.5
	result.body_lift_pixels = height_pixels * (REDUCED_HEIGHT_RATIO if reduced_motion else 1.0)
	var apex_scale := REDUCED_APEX_SHADOW_SCALE if reduced_motion else NORMAL_APEX_SHADOW_SCALE
	var apex_opacity := REDUCED_APEX_SHADOW_OPACITY if reduced_motion else NORMAL_APEX_SHADOW_OPACITY
	result.shadow_scale = GROUND_SHADOW_SCALE.lerp(apex_scale, result.arc_ratio)
	result.shadow_opacity = lerpf(GROUND_SHADOW_OPACITY, apex_opacity, result.arc_ratio)
	return result


static func protection_ratio(state: PlayerState, config: SimConfig) -> float:
	if state == null or config == null or state.health <= 0:
		return 0.0
	if state.spawn_protection_ticks > 0:
		return 1.0
	if not MovementSystem.is_combat_intangible(state, config):
		return 0.0
	if state.air_floating:
		return 1.0
	var total := 0
	var remaining := 0
	if state.hop_ticks > 0 and state.air_dodge_ticks <= 0:
		total = config.milliseconds_to_ticks(MovementTuning.JUMP_INVULNERABILITY_MS)
		remaining = state.jump_protection_ticks
	elif state.slide_ticks > 0:
		total = config.milliseconds_to_ticks(MovementTuning.SLIDE_INVULNERABILITY_MS)
		remaining = total - (config.milliseconds_to_ticks(MovementTuning.SLIDE_COOLDOWN_MS) - state.slide_cooldown_ticks)
	elif state.air_dodge_ticks > 0:
		var duration := MovementTuning.ROLL_DURATION_MS if state.is_rolling() else MovementTuning.AIR_DODGE_DURATION_MS
		var protection := MovementTuning.ROLL_INVULNERABILITY_MS if state.is_rolling() else MovementTuning.AIR_DODGE_INVULNERABILITY_MS
		total = config.milliseconds_to_ticks(protection)
		remaining = total - (config.milliseconds_to_ticks(duration) - state.air_dodge_ticks)
	return clampf(float(remaining) / float(maxi(1, total)), 0.0, 1.0)


static func takeoff_contract(state: PlayerState, config: SimConfig, reduced: bool = false) -> Dictionary:
	var result := {"active": false, "phase": 0.0, "radius": 0.0, "opacity": 0.0}
	# This short brass floor accent is not a protection boundary. It is sampled
	# from the accepted takeoff opening, never a repeating animation clock.
	if state == null or config == null or state.health <= 0 or state.air_floating or state.air_height <= 0 or state.air_vertical_velocity <= 0 or state.jump_protection_ticks <= 0 or state.air_dodge_ticks > 0 or state.wall_skim_ticks > 0:
		return result
	var total := config.milliseconds_to_ticks(MovementTuning.JUMP_INVULNERABILITY_MS)
	var phase := clampf(1.0 - float(state.jump_protection_ticks) / float(maxi(1, total)), 0.0, 1.0)
	result["active"] = true
	result["phase"] = phase
	result["radius"] = lerpf(9.0, 18.0 if reduced else 27.0, phase)
	result["opacity"] = (0.48 if reduced else 0.76) * (1.0 - phase * 0.8)
	return result
