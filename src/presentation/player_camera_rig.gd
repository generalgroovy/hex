class_name PlayerCameraRig
extends RefCounted

# Presentation only. Gameplay remains on the authoritative ground plane.
# Follow the already interpolated feet without additional input lag; ease only
# the bounded framing offset. There is no camera shake, zoom pumping or trail.
const ZOOM_PERCENT: int = 75
const ZOOM: float = 0.75
const AIM_LEAD_PIXELS: float = 36.0
const VELOCITY_LEAD_SECONDS: float = 0.06
const MAX_VELOCITY_LEAD_PIXELS: float = 24.0
const MAX_COMBINED_LEAD_PIXELS: float = 48.0
const LEAD_HALF_LIFE_SECONDS: float = 0.22
const TELEPORT_DISTANCE_PIXELS: float = 192.0
const POINTER_DEAD_ZONE_PIXELS: float = 36.0

var origin := Vector2.ZERO
var framing_offset := Vector2.ZERO
var initialized: bool = false
var _previous_feet := Vector2.ZERO
var _was_suspended: bool = false
var _arrow := PackedVector2Array()


func clear() -> void:
	initialized = false
	framing_offset = Vector2.ZERO
	_was_suspended = false


# Call once per rendered frame, never from draw queries or per catch-up tick.
# look_intent is raw controller aim OR mouse_look_intent(), NOT world aim
# reconstructed using this camera. Actual spell aim still uses screen_to_world.
# Modal UI / lost focus freezes framing; resume and explicit focus changes snap.
func advance(
	feet: Vector2,
	velocity_pixels_per_second: Vector2,
	look_intent: Vector2,
	delta_seconds: float,
	viewport_pixels: Vector2,
	world_bounds: Rect2,
	reserved_ui_top: float = 112.0,
	suppress_look_ahead: bool = false,
	suspended: bool = false,
	force_snap: bool = false,
) -> Vector2:
	if not _valid_geometry(feet, viewport_pixels, world_bounds):
		return origin
	if suspended and initialized:
		_was_suspended = true
		return origin
	var discontinuity := initialized and feet.distance_squared_to(_previous_feet) > TELEPORT_DISTANCE_PIXELS * TELEPORT_DISTANCE_PIXELS
	if not initialized or force_snap or discontinuity or _was_suspended:
		framing_offset = Vector2.ZERO
		initialized = true
		_was_suspended = suspended
	elif suppress_look_ahead:
		# Stable feet-following remains smooth through existing actor interpolation;
		# disabling the anticipatory pan avoids extra screen motion entirely.
		framing_offset = Vector2.ZERO
	elif is_finite(delta_seconds) and delta_seconds > 0.0:
		var target := desired_offset(velocity_pixels_per_second, look_intent)
		var blend := 1.0 - pow(0.5, delta_seconds / LEAD_HALF_LIFE_SECONDS)
		framing_offset = framing_offset.lerp(target, blend)
	_previous_feet = feet
	origin = clamped_origin(feet + framing_offset, viewport_pixels, world_bounds, reserved_ui_top)
	return origin


static func desired_offset(velocity_pixels_per_second: Vector2, look_intent: Vector2) -> Vector2:
	var velocity := velocity_pixels_per_second if velocity_pixels_per_second.is_finite() else Vector2.ZERO
	var look := look_intent if look_intent.is_finite() else Vector2.ZERO
	return (look.limit_length(1.0) * AIM_LEAD_PIXELS + (velocity * VELOCITY_LEAD_SECONDS).limit_length(MAX_VELOCITY_LEAD_PIXELS)).limit_length(MAX_COMBINED_LEAD_PIXELS)


static func focus_screen_anchor(viewport_pixels: Vector2, reserved_ui_top: float = 112.0) -> Vector2:
	var top := clampf(reserved_ui_top, 0.0, viewport_pixels.y) if is_finite(reserved_ui_top) else 0.0
	return Vector2(viewport_pixels.x * 0.5, (viewport_pixels.y + top) * 0.5)


# Fixed screen-space anchor deliberately avoids the positive feedback loop
# mouse-world-aim -> camera pan -> different mouse-world-aim -> more pan.
static func mouse_look_intent(pointer_pixels: Vector2, viewport_pixels: Vector2, reserved_ui_top: float = 112.0) -> Vector2:
	if not pointer_pixels.is_finite() or not viewport_pixels.is_finite() or viewport_pixels.x <= 0.0 or viewport_pixels.y <= 0.0:
		return Vector2.ZERO
	var displacement := pointer_pixels - focus_screen_anchor(viewport_pixels, reserved_ui_top)
	var distance := displacement.length()
	if distance <= POINTER_DEAD_ZONE_PIXELS:
		return Vector2.ZERO
	var radius := maxf(POINTER_DEAD_ZONE_PIXELS + 1.0, minf(viewport_pixels.x, viewport_pixels.y) * 0.42)
	# A smooth shoulder avoids a sudden framing response just outside the rest
	# zone. This modifies camera intent only; cursor aim is never dead-zoned.
	var amount := clampf((distance - POINTER_DEAD_ZONE_PIXELS) / (radius - POINTER_DEAD_ZONE_PIXELS), 0.0, 1.0)
	return displacement / distance * amount * amount * (3.0 - 2.0 * amount)


static func clamped_origin(focus: Vector2, viewport_pixels: Vector2, world_bounds: Rect2, reserved_ui_top: float = 112.0) -> Vector2:
	var visible_size := viewport_pixels / ZOOM
	var desired := focus - focus_screen_anchor(viewport_pixels, reserved_ui_top) / ZOOM
	var maximum := world_bounds.end - visible_size
	return Vector2(
		world_bounds.position.x + (world_bounds.size.x - visible_size.x) * 0.5 if visible_size.x > world_bounds.size.x else clampf(desired.x, world_bounds.position.x, maximum.x),
		world_bounds.position.y + (world_bounds.size.y - visible_size.y) * 0.5 if visible_size.y > world_bounds.size.y else clampf(desired.y, world_bounds.position.y, maximum.y),
	)


static func screen_to_world(screen_pixels: Vector2, frame_origin: Vector2) -> Vector2:
	# Invert the exact snapped transform used by PixelPresentation. Freeze the
	# frame_origin for both input and drawing; no inverse of a future camera.
	return (screen_pixels - (-frame_origin * ZOOM).round()) / ZOOM


# The drawn view starts at the inverse of the snapped canvas translation, not
# at the unsnapped camera origin. Sight/streaming must include the same edge
# pixels that drawing and mouse input use, including translated viewports.
static func visible_world_rect(viewport_pixels: Rect2, frame_origin: Vector2, zoom: float = ZOOM) -> Rect2:
	if not viewport_pixels.has_area() or not viewport_pixels.position.is_finite() or not viewport_pixels.end.is_finite() or not frame_origin.is_finite() or not is_finite(zoom) or zoom <= 0.0:
		return Rect2()
	return Rect2((viewport_pixels.position - (-frame_origin * zoom).round()) / zoom, viewport_pixels.size / zoom)


# Reuses one three-vertex buffer. Draw at ground height, never at jump height.
# actual_aim is the current unquantized accepted/predicted aim, NOT velocity or
# slide-facing. A two-tone, unanimated chevron is legible without adding a ring.
func ground_arrow(feet_shadow: Vector2, actual_aim: Vector2, enabled: bool = true, shadow_radius: float = 18.0) -> PackedVector2Array:
	if not enabled or not feet_shadow.is_finite() or not actual_aim.is_finite() or actual_aim.length_squared() < 0.000001:
		_arrow.resize(0)
		return _arrow
	if _arrow.size() != 3:
		_arrow.resize(3)
	var aim := actual_aim.normalized()
	var side := Vector2(-aim.y, aim.x)
	var radius := clampf(shadow_radius, 8.0, 30.0) if is_finite(shadow_radius) else 18.0
	var center := feet_shadow + aim * (radius + 8.0)
	_arrow[0] = center + aim * 5.0
	_arrow[1] = center - aim * 3.0 + side * 3.5
	_arrow[2] = center - aim * 3.0 - side * 3.5
	return _arrow


static func _valid_geometry(feet: Vector2, viewport_pixels: Vector2, world_bounds: Rect2) -> bool:
	return feet.is_finite() and viewport_pixels.is_finite() and viewport_pixels.x > 0.0 and viewport_pixels.y > 0.0 and world_bounds.position.is_finite() and world_bounds.size.is_finite() and world_bounds.size.x > 0.0 and world_bounds.size.y > 0.0
