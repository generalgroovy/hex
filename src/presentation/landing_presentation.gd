class_name LandingPresentation
extends RefCounted
const PixelMovement = preload("res://src/presentation/pixel_movement_effects.gd")
static var pixel_movement: RefCounted


const BASE_SHADOW_SCALE := Vector2(0.90, 0.32)
const MAXIMUM_SHADOW_SCALE := Vector2(1.28, 0.24)
const MINIMUM_RING_RADIUS: float = 7.0
const MAXIMUM_RING_RADIUS: float = 28.0
const NORMAL_MAXIMUM_OPACITY: float = 0.72
const REDUCED_MAXIMUM_OPACITY: float = 0.50
const NORMAL_RING_WIDTH: float = 2.0
const REDUCED_RING_WIDTH: float = 1.0


class Sample:
	extends RefCounted

	var active: bool = false
	var normalized_phase: float = 0.0
	var intensity_ratio: float = 0.0
	var ring_radius: float = MINIMUM_RING_RADIUS
	var ring_opacity: float = 0.0
	var ring_width: float = NORMAL_RING_WIDTH
	var shadow_scale: Vector2 = BASE_SHADOW_SCALE
	var travel_direction := Vector2.DOWN
	var puff_offsets: Array[Vector2] = []
	var puff_radius: float = 0.0
	var puff_opacity: float = 0.0
	var reduced_effects: bool = false
	var contact_offsets := PackedVector2Array()
	var contact_width: int = 0
	var contact_height: int = 2
	var contact_opacity: float = 0.0
	var dust_offset := Vector2.ZERO


static func sample(
	state: PlayerState,
	config: SimConfig,
	interpolation_alpha: float = 0.0,
	reduced_motion: bool = false,
) -> Sample:
	var result := Sample.new()
	if state == null or config == null or state.health <= 0 or state.landing_ticks <= 0 or state.landing_intensity <= 0:
		return result
	# Forced-impact recovery also owns this timer while physical height may
	# remain airborne. Heel contacts and the landing shadow require real ground.
	if state.is_airborne():
		return result
	var total_ticks: int = config.milliseconds_to_ticks(MovementTuning.LANDING_WINDOW_MS)
	if total_ticks <= 0:
		return result
	result.active = true
	var bounded_alpha := clampf(interpolation_alpha, 0.0, 1.0)
	var elapsed_ticks := float(total_ticks - state.landing_ticks) + bounded_alpha
	result.normalized_phase = clampf(elapsed_ticks / float(total_ticks), 0.0, 1.0)
	result.intensity_ratio = clampf(float(state.landing_intensity) / 1000.0, 0.0, 1.0)
	var motion_ratio: float = 0.55 if reduced_motion else 1.0
	var pulse: float = (1.0 - result.normalized_phase) * result.intensity_ratio * motion_ratio
	result.ring_radius = lerpf(
		MINIMUM_RING_RADIUS,
		MAXIMUM_RING_RADIUS,
		result.normalized_phase * result.intensity_ratio * motion_ratio,
	)
	var maximum_opacity := REDUCED_MAXIMUM_OPACITY if reduced_motion else NORMAL_MAXIMUM_OPACITY
	result.ring_opacity = maximum_opacity * result.intensity_ratio * (1.0 - result.normalized_phase)
	result.ring_width = REDUCED_RING_WIDTH if reduced_motion else NORMAL_RING_WIDTH
	result.shadow_scale = BASE_SHADOW_SCALE.lerp(MAXIMUM_SHADOW_SCALE, pulse)
	result.travel_direction = motion_direction(state)
	var side := result.travel_direction.orthogonal()
	var distance := 5.0 + result.normalized_phase * (7.0 if reduced_motion else 14.0)
	var spread := 4.0 + result.normalized_phase * 7.0
	var count := 1 if reduced_motion else 3
	for index: int in range(count):
		var side_sign := float(index - 1) if count == 3 else 0.0
		result.puff_offsets.append(-result.travel_direction * distance + side * side_sign * spread)
	result.puff_radius = (3.5 + result.normalized_phase * 3.0) * (0.65 + result.intensity_ratio * 0.35)
	result.puff_opacity = result.ring_opacity * 0.80
	result.reduced_effects = reduced_motion
	# Two compact heel contacts give impact a readable shape and force, without
	# drawing a circular protection/attack boundary. No emitter or event survives
	# this accepted landing window. Reduced Effects keeps its geometry still.
	var settle := 1.0 - pow(1.0 - result.normalized_phase, 3.0)
	var span := 8.0 + result.intensity_ratio * 3.0
	if not reduced_motion:
		span += settle * 4.0 * result.intensity_ratio
	result.contact_offsets = PackedVector2Array([
		-side * span - result.travel_direction * 2.0,
		side * span - result.travel_direction * 2.0,
	])
	result.contact_width = 3 + roundi(3.0 * result.intensity_ratio)
	# The floor mark compresses and settles, not the actor. Reduced Effects
	# retains a still two-pixel contact with the same accepted timing/force.
	result.contact_height = 2 if reduced_motion else 1 + roundi((1.0 - settle) * (1.0 + result.intensity_ratio))
	result.contact_opacity = (0.35 + result.intensity_ratio * 0.45) * (1.0 - result.normalized_phase)
	if reduced_motion:
		result.contact_opacity *= 0.78
	result.dust_offset = -result.travel_direction * (2.0 + result.intensity_ratio * 2.0)
	return result


static func motion_direction(state: PlayerState) -> Vector2:
	if state == null:
		return Vector2.DOWN
	var direction := Vector2(state.velocity_x, state.velocity_y)
	if direction.length_squared() <= 1.0:
		direction = Vector2(state.facing_x, state.facing_y)
	return direction.normalized() if direction.length_squared() > 0.0 else Vector2.DOWN


static func draw(canvas: CanvasItem, center: Vector2, landing: Sample, language: VisualLanguage) -> void:
	if canvas == null or landing == null or language == null or not landing.active:
		return
	var ink := language.ramp_color("warm_stone", 0)
	var light := language.ramp_color("warm_stone", 4)
	# Axis-aligned, snapped two-tone blocks retain native-pixel edges even when
	# coast direction is diagonal. The open center leaves feet/threats visible.
	for offset: Vector2 in landing.contact_offsets:
		var origin := (center + offset - Vector2(float(landing.contact_width) * 0.5, 1.0)).round()
		canvas.draw_rect(Rect2(origin - Vector2.ONE, Vector2(landing.contact_width + 2, landing.contact_height + 2)), Color(ink, landing.contact_opacity))
		canvas.draw_rect(Rect2(origin, Vector2(landing.contact_width, landing.contact_height)), Color(light, landing.contact_opacity))
	if pixel_movement == null:
		pixel_movement = PixelMovement.new()
	if pixel_movement.ready():
		var age := floori(landing.normalized_phase * ceilf(MovementTuning.LANDING_WINDOW_MS * 0.12))
		pixel_movement.stamp(canvas, "landing_dust", center + landing.dust_offset, age, landing.reduced_effects, 0.0, landing.puff_opacity * 0.75)
