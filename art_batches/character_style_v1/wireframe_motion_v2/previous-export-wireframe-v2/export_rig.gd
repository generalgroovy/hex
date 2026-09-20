extends SceneTree

const Guide := preload("res://art_batches/character_style_v1/template_v2/pose_guide_model.gd")
const OUT := "res://art_batches/character_style_v1/wireframe_motion_v2/rig-data.json"


func _initialize() -> void:
	var poses: Array = []
	for body: String in ["small", "middle", "large"]:
		for state: String in Guide.STATES:
			for aim: int in range(8):
				poses.append(_pack(Guide.landmarks(state), body, aim, -1, -1, state))
		for travel: int in range(8):
			for aim: int in range(8):
				for phase: int in range(8):
					poses.append(_pack(_motion(travel, aim, phase), body, aim, travel, phase, "locomotion"))
					poses.append(_pack(_motion(travel, aim, phase, true), body, aim, travel, phase, "sprint_locomotion"))
	var source := "res://art_batches/character_style_v1/template_v2/pose_guide_model.gd"
	var data := {"schema_version": 2, "rig_source": source, "rig_sha256": FileAccess.get_sha256(source),
		"heights": Guide.HEIGHTS, "directions": Guide.DIRECTIONS, "base_rows": Guide.STATES,
		"head_radius": Guide.HEAD_RADIUS, "cell": [96, 96], "pivot": [48, 84], "phases": 8,
		"bone_lengths": {"thigh": Guide.THIGH, "shin": Guide.SHIN, "foot": Guide.FOOT,
			"humerus": Guide.HUMERUS, "forearm": Guide.FOREARM, "torso": Guide.TORSO},
		"motion_policy": "Pelvis, chest and head face aim; zero waist yaw twist. Travel-oriented alternating foot plants; reduced lateral stride prevents crossed feet. Separate eight-phase walk and sprint banks share exact skeletal proportions; sprint has a longer stride, stronger lean and higher swing lift.",
		"poses": poses}
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	if file == null:
		push_error("Could not export wireframe motion data")
		quit(1)
		return
	file.store_string(JSON.stringify(data) + "\n")
	print("PASS: 240 base + 1536 walk + 1536 sprint move/aim/phase poses exported using fixed-bone IK")
	quit(0)


func _motion(travel: int, aim: int, phase: int, sprinting: bool = false) -> Dictionary:
	var relative := deg_to_rad((travel - aim) * 45.0)
	var travel_axis := Vector3(-sin(relative), cos(relative), 0)
	var stride := (0.208 if sprinting else 0.165) * (1.0 - 0.65 * absf(sin(relative)))
	var t := float(phase) / 8.0
	var lean := 0.22 if sprinting else 0.09
	var up := Vector3(travel_axis.x * lean, travel_axis.y * lean, 1.0).normalized()
	var forward := (Vector3(0, 1, 0) - up * up.y).normalized()
	var right := forward.cross(up).normalized()
	var pelvis := Vector3(0, 0, 0.390 + (-0.015 if sprinting else 0.005) * cos(TAU * 2.0 * t))
	var shoulders := pelvis + up * Guide.TORSO
	var head := shoulders + up * 0.165
	var result := {"pelvis": pelvis, "head": head, "neck": shoulders + up * 0.05,
		"nose": head + forward * 0.11}
	for side: String in ["l", "r"]:
		var lateral := -1.0 if side == "l" else 1.0
		var leg_t := fposmod(t + (0.5 if side == "r" else 0.0), 1.0)
		var along := cos(TAU * leg_t) * stride
		var swing_envelope := pow(maxf(0.0, -sin(TAU * leg_t)), 2.0)
		var lift := swing_envelope * (0.105 if sprinting else 0.085)
		var hip := pelvis + Vector3(lateral * 0.09, 0, 0)
		var ankle := Vector3(lateral * 0.09, 0, lift) + travel_axis * along
		var leg := Guide.two_bone(hip, ankle, Guide.THIGH, Guide.SHIN, Vector3(0, 1, 0))
		assert(not leg.is_empty(), "Unreachable locomotion leg")
		result["hip_" + side] = hip
		result["knee_" + side] = leg.joint
		result["ankle_" + side] = ankle
		# Flat support foot; airborne foot plantarflexes smoothly and cannot fold
		# into the shin. Floor is an explicit art-rig angle, not a medical claim.
		var shin: Vector3 = leg.joint - ankle
		var ankle_pitch := minf(-0.20 * swing_envelope, atan2(shin.z, shin.y) - deg_to_rad(55.0)) if swing_envelope > 0.000001 else 0.0
		var foot_axis := Vector3(0, cos(ankle_pitch), sin(ankle_pitch))
		result["toe_" + side] = ankle + foot_axis * Guide.FOOT
		var shoulder := shoulders + right * lateral * 0.16
		var hand := shoulder + right * (-lateral * 0.035) + forward * (0.23 if side == "r" else 0.17) - up * (0.10 if side == "r" else 0.16)
		if sprinting:
			hand += forward * sin(TAU * 2.0 * t) * 0.012
		var arm := Guide.two_bone(shoulder, hand, Guide.HUMERUS, Guide.FOREARM, right * lateral + forward * 0.3 - up * 0.15)
		assert(not arm.is_empty(), "Unreachable aim-ready arm")
		result["shoulder_" + side] = shoulder
		result["elbow_" + side] = arm.joint
		result["hand_" + side] = hand
	return result


func _pack(source: Dictionary, body: String, aim: int, travel: int, phase: int, state: String) -> Dictionary:
	var direction: String = Guide.DIRECTIONS[aim]
	var height := float(Guide.HEIGHTS[body])
	var points := {}
	var landmarks := {}
	var lowest := -INF
	for key: String in source:
		var p := Guide.project(source[key], direction, height)
		lowest = maxf(lowest, p.y)
	var anchor := Vector2(48, 83 - lowest)
	for key: String in source:
		var p := anchor + Guide.project(source[key], direction, height)
		var v: Vector3 = source[key]
		points[key] = [p.x, p.y]
		landmarks[key] = [v.x, v.y, v.z]
	var chains: Array = []
	for side: String in ["l", "r"]:
		for kind: String in ["leg", "arm"]:
			var keys: Array = ["hip_" + side, "knee_" + side, "ankle_" + side, "toe_" + side] if kind == "leg" else ["shoulder_" + side, "elbow_" + side, "hand_" + side]
			var average := 0.0
			for key: String in keys:
				average += Guide.depth(source[key], direction)
			chains.append({"kind": kind, "side": side, "keys": keys, "depth": average / keys.size()})
	chains.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.depth) < float(b.depth))
	var shoulder_mid: Vector3 = (source.shoulder_l + source.shoulder_r) * 0.5
	var up: Vector3 = (shoulder_mid - source.pelvis).normalized()
	var right: Vector3 = (source.shoulder_r - source.shoulder_l).normalized()
	var forward: Vector3 = up.cross(right).normalized()
	var mesh_points: Array = []
	var mesh_depths: Array = []
	# Three eight-vertex rings are real fixed 3D torso volume, including profile depth.
	for ring: Array in [[0.30, 0.16, 0.12], [0.11, 0.105, 0.085], [0.015, 0.105, 0.09]]:
		for i: int in range(8):
			var angle := TAU * float(i) / 8.0
			var v: Vector3 = source.pelvis + up * float(ring[0]) + right * cos(angle) * float(ring[1]) + forward * sin(angle) * float(ring[2])
			var p := anchor + Guide.project(v, direction, height)
			mesh_points.append([p.x, p.y])
			mesh_depths.append(Guide.depth(v, direction))
	var mesh_faces: Array = []
	for ring: int in range(2):
		for i: int in range(8):
			var indices := [ring * 8 + i, ring * 8 + (i + 1) % 8, (ring + 1) * 8 + (i + 1) % 8, (ring + 1) * 8 + i]
			var average := 0.0
			for vertex: int in indices:
				average += float(mesh_depths[vertex])
			mesh_faces.append({"indices": indices, "depth": average / 4.0})
	mesh_faces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.depth) < float(b.depth))
	var sternum: Array = []
	for z: float in [0.27, 0.06]:
		var p := anchor + Guide.project(source.pelvis + up * z + forward * (0.115 if z > 0.2 else 0.092), direction, height)
		sternum.append([p.x, p.y])
	return {"body": body, "state": state, "direction": direction, "aim": aim, "travel": travel, "phase": phase,
		"points": points, "landmarks": landmarks, "chains": chains,
		"pixels_per_unit": height / Guide.SOUTH_STANDING_SPAN,
		"torso_depth": Guide.depth((shoulder_mid + source.pelvis) * 0.5, direction),
		"mesh_points": mesh_points, "mesh_faces": mesh_faces, "sternum": sternum,
		"waist_yaw_twist_degrees": 0 if state in ["locomotion", "sprint_locomotion"] else null}
