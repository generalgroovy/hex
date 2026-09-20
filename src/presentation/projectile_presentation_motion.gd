class_name ProjectilePresentationMotion
extends RefCounted


const MIN_TRAIL_PIXELS := 8.0
const MAX_TRAIL_PIXELS := 28.0
const TRAIL_SECONDS := 0.026
const MINIMUM_VISUAL_DIAMETER := 28.0
const MAXIMUM_VISUAL_DIAMETER := 46.0
const VISUAL_TO_COLLISION_RATIO := 2.75


static func interpolated_position(projectile: ProjectileState, alpha: float) -> Vector2:
	if projectile == null:
		return Vector2.ZERO
	var previous := Vector2(float(projectile.previous_x), float(projectile.previous_y)) / SimConfig.FIXED_SCALE
	var current := Vector2(float(projectile.position_x), float(projectile.position_y)) / SimConfig.FIXED_SCALE
	return previous.lerp(current, clampf(alpha, 0.0, 1.0))


static func travel_direction(projectile: ProjectileState) -> Vector2:
	if projectile == null:
		return Vector2.DOWN
	var velocity := Vector2(float(projectile.velocity_x), float(projectile.velocity_y))
	if velocity.length_squared() > 0.0:
		return velocity.normalized()
	var delta := Vector2(
		float(projectile.position_x - projectile.previous_x),
		float(projectile.position_y - projectile.previous_y),
	)
	return delta.normalized() if delta.length_squared() > 0.0 else Vector2.DOWN


static func trail_length(projectile: ProjectileState, reduced_effects: bool) -> float:
	if projectile == null:
		return MIN_TRAIL_PIXELS
	var speed_pixels_per_second := Vector2(
		float(projectile.velocity_x),
		float(projectile.velocity_y),
	).length() / SimConfig.FIXED_SCALE
	var length := clampf(speed_pixels_per_second * TRAIL_SECONDS, MIN_TRAIL_PIXELS, MAX_TRAIL_PIXELS)
	return length * (0.62 if reduced_effects else 1.0)


static func visual_diameter(projectile: ProjectileState) -> float:
	if projectile == null:
		return MINIMUM_VISUAL_DIAMETER
	var radius := float(projectile.radius) / SimConfig.FIXED_SCALE
	return clampf(radius * VISUAL_TO_COLLISION_RATIO, MINIMUM_VISUAL_DIAMETER, MAXIMUM_VISUAL_DIAMETER)


static func leading_point(projectile: ProjectileState) -> Vector2:
	if projectile == null:
		return Vector2.ZERO
	var radius := float(projectile.radius) / SimConfig.FIXED_SCALE
	return travel_direction(projectile) * (radius + 3.0)
