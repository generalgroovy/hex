extends RefCounted

# Offline construction only. Fixed bone lengths and anatomical names survive
# every pose/yaw; none of these diagrams are sprite art or gameplay authority.
const HEIGHTS := {"small": 58, "middle": 68, "large": 76}
const DIRECTIONS := ["south", "south_east", "east", "north_east", "north", "north_west", "west", "south_west"]
const STATES := ["grounded", "jump", "cast", "hit", "walk", "sprint", "slide", "roll", "walk_b", "sprint_b"]
const BOARD_STATES := ["grounded", "jump", "cast", "hit", "walk", "walk_b", "sprint", "sprint_b", "slide", "roll"]
const BONES := [["hip_l", "knee_l"], ["knee_l", "ankle_l"], ["ankle_l", "toe_l"], ["hip_r", "knee_r"], ["knee_r", "ankle_r"], ["ankle_r", "toe_r"], ["shoulder_l", "elbow_l"], ["elbow_l", "hand_l"], ["shoulder_r", "elbow_r"], ["elbow_r", "hand_r"]]
const THIGH := 0.20
const SHIN := 0.23
const HUMERUS := 0.17
const FOREARM := 0.15
const FOOT := 0.08
const TORSO := 0.30
const HEAD_RADIUS := 0.103
const DEPTH_SCALE := 0.450533624 # sin(55deg) *0.55; stylized construction camera.
const SOUTH_STANDING_SPAN := 0.895 + HEAD_RADIUS + FOOT * DEPTH_SCALE


static func two_bone(start: Vector3, target: Vector3, first: float, second: float, bend_hint: Vector3) -> Dictionary:
	if not start.is_finite() or not target.is_finite() or not bend_hint.is_finite() \
		or not is_finite(first) or not is_finite(second) or first <= 0.0 or second <= 0.0:
		return {}
	var delta := target - start
	var distance := delta.length()
	if distance <= 0.000001 or distance > first + second + 0.000001 or distance < absf(first - second) - 0.000001:
		return {} # Never stretch or shorten a bone to hide an unreachable goal.
	var axis := delta / distance
	var bend := bend_hint - axis * bend_hint.dot(axis)
	if bend.length_squared() <= 0.00000001:
		return {} # Ambiguous plane is an authored-input error, not random knee flip.
	bend = bend.normalized()
	var along := (first * first - second * second + distance * distance) / (2.0 * distance)
	var across := sqrt(maxf(0.0, first * first - along * along))
	return {"joint": start + axis * along + bend * across, "end": target}


static func landmarks(state: String) -> Dictionary:
	if not STATES.has(state):
		return {}
	# Coordinates: x anatomical right, y forward, z height. A plants LEFT.
	var gait := state in ["walk", "walk_b", "sprint", "sprint_b"]
	var sprint := state.begins_with("sprint")
	var sign_a := -1.0 if state.ends_with("_b") else 1.0
	var stride := (0.27 if sprint else 0.17) if gait else 0.0
	var hip_height := 0.32 if sprint else (0.38 if gait else 0.43)
	var lean := 0.22 if sprint else 0.0
	if state == "jump":
		hip_height = 0.45
	elif state == "hit":
		hip_height = 0.40
		lean = -0.16
	elif state == "slide":
		hip_height = 0.16
		lean = -0.55
	elif state == "roll":
		hip_height = 0.20
		lean = 0.80
	var up := Vector3(0, sin(lean), cos(lean))
	var forward_axis := Vector3(0, cos(lean), -sin(lean))
	var pelvis := Vector3(0, 0, hip_height)
	var shoulders := pelvis + up * TORSO
	var head := shoulders + up * 0.165
	var result := {"head": head, "neck": shoulders + up * 0.05, "pelvis": pelvis, "nose": head + forward_axis * 0.11}
	for side: String in ["l", "r"]:
		var lateral := -1.0 if side == "l" else 1.0
		var leg_phase := sign_a if side == "l" else -sign_a
		var support := gait and leg_phase > 0
		var forward := stride * leg_phase
		var hip := pelvis + Vector3(lateral * 0.09, 0, 0)
		var ankle := Vector3(lateral * 0.09, forward, 0.03 if gait and not support else 0.0)
		if state == "jump":
			ankle = Vector3(lateral * 0.09, -0.10, 0.18)
		elif state == "slide":
			ankle = Vector3(lateral * 0.09, 0.35, 0)
		elif state == "roll":
			ankle = Vector3(lateral * 0.09, 0.16, 0.11)
		var leg := two_bone(hip, ankle, THIGH, SHIN, Vector3(0, 1, 0))
		if leg.is_empty():
			return {}
		result["hip_" + side] = hip
		result["knee_" + side] = leg.joint
		result["ankle_" + side] = ankle
		result["toe_" + side] = ankle + Vector3(0, FOOT, 0)
		var shoulder := shoulders + Vector3(lateral * 0.16, 0, 0)
		var hand := shoulder + Vector3(lateral * 0.02, -forward * 0.70, -0.23 if sprint else -0.28)
		if state == "jump":
			hand = shoulder + Vector3(lateral * 0.08, 0.04, -0.05)
		elif state == "cast" and side == "r":
			hand = shoulder + Vector3(0, 0.28, -0.075)
		elif state == "hit":
			hand = shoulder + Vector3(lateral * 0.04, 0.08, -0.06)
		elif state == "slide":
			hand = shoulder + Vector3(lateral * 0.07, -0.10, -0.25)
		elif state == "roll":
			hand = pelvis + Vector3(lateral * 0.05, 0.19, 0.26)
		var arm := two_bone(shoulder, hand, HUMERUS, FOREARM, Vector3(lateral, 0.3, -0.15))
		if arm.is_empty():
			return {}
		result["shoulder_" + side] = shoulder
		result["elbow_" + side] = arm.joint
		result["hand_" + side] = hand
	return result


static func depth(point: Vector3, direction: String) -> float:
	var index := DIRECTIONS.find(direction)
	if index < 0 or not point.is_finite():
		return NAN
	var yaw := deg_to_rad(index * 45.0)
	return point.x * sin(yaw) + point.y * cos(yaw)


static func project(point: Vector3, direction: String, height: float) -> Vector2:
	var index := DIRECTIONS.find(direction)
	if index < 0 or not point.is_finite() or not is_finite(height) or height <= 0.0:
		return Vector2.ZERO
	var yaw := deg_to_rad(index * 45.0)
	# Front anatomical right is screen-left. One SOUTH calibration factor applies
	# to every size/state/yaw, never one scale per pose.
	var x := -point.x * cos(yaw) + point.y * sin(yaw)
	return Vector2(x, depth(point, direction) * DEPTH_SCALE - point.z) * height / SOUTH_STANDING_SPAN


static func pose(body: String, state: String, direction: String) -> Dictionary:
	if not HEIGHTS.has(body) or not DIRECTIONS.has(direction):
		return {}
	var source := landmarks(state)
	if source.is_empty():
		return {}
	var points := {}
	var height := float(HEIGHTS[body])
	var bottom := -INF
	for key: String in source:
		points[key] = project(source[key], direction, height)
		bottom = maxf(bottom, (points[key] as Vector2).y)
	var anchor := Vector2(48, 83 - bottom) # Translation only; actual lowest landmark.
	for key: String in points:
		points[key] += anchor
	var torso_corners := PackedVector2Array()
	var chest: Vector3 = (source.nose - source.head).normalized()
	for key: String in ["shoulder_l", "shoulder_r", "hip_r", "hip_l"]:
		for offset: float in [-0.065, 0.065]:
			torso_corners.append(anchor + project(source[key] + chest * offset, direction, height))
	var chains: Array[Dictionary] = []
	for side: String in ["l", "r"]:
		for kind: String in ["leg", "arm"]:
			var keys: Array = ["hip_" + side, "knee_" + side, "ankle_" + side, "toe_" + side] if kind == "leg" else ["shoulder_" + side, "elbow_" + side, "hand_" + side]
			var average := 0.0
			for key: String in keys:
				average += depth(source[key], direction)
			chains.append({"kind": kind, "side": side, "keys": keys, "depth": average / keys.size()})
	chains.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.depth) < float(b.depth))
	return {"body": body, "direction": direction, "state": state, "points": points, "landmarks": source,
		"chains": chains, "torso_depth": depth((source.neck + source.pelvis) * 0.5, direction), "torso_corners": torso_corners,
		"contact": "right" if state.ends_with("_b") else ("left" if state in ["walk", "sprint"] else "not_applicable"),
		"height": HEIGHTS[body], "pixels_per_unit": height / SOUTH_STANDING_SPAN, "finished_art": false}
