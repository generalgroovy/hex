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


static func sample(
	state: PlayerState,
	config: SimConfig,
	interpolation_alpha: float = 0.0,
	reduced_motion: bool = false,
) -> Sample:
	var result := Sample.new()
	if state == null or config == null or state.landing_ticks <= 0 or state.landing_intensity <= 0:
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
	if pixel_movement == null:
		pixel_movement = PixelMovement.new()
	if pixel_movement.ready():
		var age := floori(landing.normalized_phase * ceilf(MovementTuning.LANDING_WINDOW_MS * 0.12))
		var reduced := landing.ring_width == REDUCED_RING_WIDTH
		pixel_movement.stamp(canvas,"landing_contact",center,age,reduced)
		pixel_movement.stamp(canvas,"landing_dust",center,age,reduced,0.0,0.5 if reduced else 0.7)
		return
	var color := language.ramp_color("warm_stone", 4)
	var angle := landing.travel_direction.angle()
	# Open contact arcs and sparse backward puffs leave the feet and forward
	# escape lane clear; this draws no new collision or protection boundary.
	for side_sign: float in [-1.0, 1.0]:
		var start := angle + side_sign * 0.85
		canvas.draw_arc(center, landing.ring_radius, start, start + side_sign * 0.75, 7, Color(color, landing.ring_opacity * 0.54), landing.ring_width)
	for offset: Vector2 in landing.puff_offsets:
		var puff := center + offset
		canvas.draw_circle(puff, landing.puff_radius, Color(color, landing.puff_opacity * 0.24))
		canvas.draw_arc(puff, landing.puff_radius, angle + 0.8, angle + 5.4, 8, Color(color, landing.puff_opacity), landing.ring_width)
		canvas.draw_arc(puff - landing.travel_direction * landing.puff_radius * 0.48, landing.puff_radius * 0.65, angle + 1.1, angle + 4.7, 6, Color(color, landing.puff_opacity * 0.72), landing.ring_width)
		canvas.draw_line(puff - landing.travel_direction * landing.puff_radius, puff - landing.travel_direction * (landing.puff_radius + 3.0), Color(color, landing.puff_opacity * 0.65), landing.ring_width)
