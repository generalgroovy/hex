extends RefCounted
## Existing native contact keys, rigidly tilted about their registered feet.
## This descriptor reads attachment; it never predicts or grants wall movement.

const HEIGHTS := {"small": 58, "middle": 63, "large": 68}
const PIVOT := Vector2(64, 104)
const CELL := Vector2(128, 128)
const MOVING_LEAN_DEGREES := 11.0
const BRACED_LEAN_DEGREES := 7.0


static func is_attached(state: PlayerState) -> bool:
	return state != null and state.health > 0 and state.wall_skim_ticks > 0 \
		and state.wall_skim_surface_id > 0 and Vector2i(state.wall_x, state.wall_y) != Vector2i.ZERO \
		and state.air_dodge_ticks <= 0 and state.impact_recovery_ticks <= 0 and not state.jumpsquat_active \
		and state.control_state in [PlayerState.ControlState.FREE, PlayerState.ControlState.SLOWED] \
		and state.movement_mode not in [PlayerState.MovementMode.LAUNCHED, PlayerState.MovementMode.GRAPPLED,
			PlayerState.MovementMode.IMPACT_RECOVERY, PlayerState.MovementMode.STUNNED,
			PlayerState.MovementMode.ROOTED, PlayerState.MovementMode.CHARGING]


static func frame(id: String, entry: Dictionary, texture: Texture2D, aim: int, travel: int,
		step: int, normal: Vector2, moving: bool, reduced: bool) -> Dictionary:
	if texture == null or texture.get_size() != Vector2(1024, 512) or entry.is_empty() or not HEIGHTS.has(entry.get("body")) \
		or aim < 0 or aim >= 8 or travel < 0 or travel >= 8 or step < 0 or step >= 4 \
		or not normal.is_finite() or normal.length_squared() < 0.001:
		return {}
	var n := normal.normalized()
	# The original whole-body rows stay intact: no waist mismatch or limb warp.
	# Blocked/reduced states hold a braced neutral; only real travel alternates.
	var row: int = [1, 0, 2, 0][step] if moving and not reduced else 0
	var angle := deg_to_rad(MOVING_LEAN_DEGREES if moving else BRACED_LEAN_DEGREES) * -n.x
	var region := Rect2(travel * 128, row * 128, 128, 128)
	var transform := Transform2D(angle, Vector2.ZERO)
	var points := PackedVector2Array()
	for corner: Vector2 in [-PIVOT, Vector2(64, -104), Vector2(64, 24), Vector2(-64, 24)]:
		points.append(transform * corner)
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points: bounds = bounds.expand(point)
	return {"pixel_body_pilot": true, "fullbody_art": true, "wallrun_pose": true,
		"visual_mode": "pixel_cast", "texture": texture, "source_region": region,
		"components": [], "body_type": entry.body, "display_height": HEIGHTS[entry.body],
		"offset": Vector2.ZERO, "squat_depth": 0, "pivot": PIVOT, "cell_size": CELL,
		"action": "wallrun", "aim_index": aim, "travel_index": travel, "pose_facing_index": travel,
		"wall_normal": n, "wall_lean_radians": angle, "wall_contact_row": row,
		"wall_braced": not moving, "motion_phase": float(step) / 4.0,
		"body_bounds": bounds, "rigid_pose_fallback": false, "pixel_action_key": false,
		"independent_cast_pose": false, "all_action_art_complete": false,
		"art_pose_quality": "native whole-body contact keys with bounded rigid wall lean",
		"frame_id": "%s/wallrun/%d/%d/%d/%d/%d" % [id, travel, row, roundi(n.x * 1000), roundi(n.y * 1000), int(moving)]}


static func draw(canvas: CanvasItem, value: Dictionary, anchor: Vector2, tint: Color) -> void:
	# Supply rotated world vertices, leaving the caller's camera transform
	# untouched. Replacing draw_set_transform here would discard its zoom/origin.
	var source: Rect2 = value.source_region
	var texture: Texture2D = value.texture
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for corner: Vector2 in [Vector2.ZERO, Vector2(CELL.x, 0), CELL, Vector2(0, CELL.y)]:
		points.append(anchor + (corner - PIVOT).rotated(float(value.wall_lean_radians)))
		uvs.append((source.position + corner) / texture.get_size())
	canvas.draw_polygon(points, PackedColorArray([tint]), uvs, texture)
