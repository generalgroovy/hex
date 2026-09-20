extends SceneTree

# Offline candidate exporter. This file never writes live assets or presentation
# code. It derives every pose from the current shared W2 fixed-bone rig.
const Guide := preload("res://art_batches/character_style_v1/template_v2/pose_guide_model.gd")
const HERE := "res://art_batches/character_style_v1/wireframe_melee_v1/"
const W2_RIG := "res://art_batches/character_style_v1/wireframe_motion_v2/rig-data.json"
const W2_MANIFEST := "res://assets/sprites/wireframe_motion_v2/manifest.json"
const OUT := HERE + "rig-data.json"

const BODIES := ["small", "middle", "large"]
const DISPLAY_HEIGHTS := {"small": 58, "middle": 63, "large": 68}
const GAITS := [
	{"id": "idle", "travel_offset": null},
	{"id": "forward", "travel_offset": 0},
	{"id": "strafe_right", "travel_offset": 2},
	{"id": "backward", "travel_offset": 4},
	{"id": "strafe_left", "travel_offset": 6},
]
const ATTACKS := [
	{"id": "punch", "physical_kind": 1},
	{"id": "kick", "physical_kind": 2},
]
const PHASES := [
	{"id": "startup", "physical_phase": 1},
	{"id": "active", "physical_phase": 2},
	{"id": "recovery", "physical_phase": 3},
]


func _initialize() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(W2_RIG))
	if not parsed is Dictionary:
		push_error("W2 rig data is missing or invalid")
		quit(1)
		return
	var source_data: Dictionary = parsed
	var source_index := _index_sources(source_data)
	var poses: Array[Dictionary] = []
	for body: String in BODIES:
		for aim: int in range(8):
			for gait_index: int in range(GAITS.size()):
				var gait: Dictionary = GAITS[gait_index]
				var source := _source_pose(source_index, body, aim, gait)
				assert(not source.is_empty(), "Missing fixed W2 source pose")
				for attack_index: int in range(ATTACKS.size()):
					var attack: Dictionary = ATTACKS[attack_index]
					for phase_index: int in range(PHASES.size()):
						var phase: Dictionary = PHASES[phase_index]
						var pose := _melee_pose(source, String(attack.id), String(phase.id))
						pose["gait"] = String(gait.id)
						pose["gait_index"] = gait_index
						pose["attack"] = String(attack.id)
						pose["attack_index"] = attack_index
						pose["physical_kind"] = int(attack.physical_kind)
						pose["physical_phase_name"] = String(phase.id)
						pose["physical_phase"] = int(phase.physical_phase)
						pose["physical_phase_index"] = phase_index
						poses.append(pose)
	assert(poses.size() == 720)
	var data := {
		"schema_version": 1,
		"candidate_only": true,
		"status": "rig_export_complete_pending_python_bake_and_native_review",
		"rig_source": W2_RIG,
		"rig_source_sha256": FileAccess.get_sha256(W2_RIG),
		"runtime_manifest_source": W2_MANIFEST,
		"runtime_manifest_sha256": FileAccess.get_sha256(W2_MANIFEST),
		"pose_guide_source": "res://art_batches/character_style_v1/template_v2/pose_guide_model.gd",
		"pose_guide_sha256": FileAccess.get_sha256("res://art_batches/character_style_v1/template_v2/pose_guide_model.gd"),
		"cell": [96, 96],
		"pivot": [48, 84],
		"bodies": BODIES,
		"reference_heights": Guide.HEIGHTS,
		"display_heights": DISPLAY_HEIGHTS,
		"head_radius": Guide.HEAD_RADIUS,
		"head_offset": Guide.HEAD_OFFSET,
		"neck_offset": Guide.NECK_OFFSET,
		"standing_span": Guide.SOUTH_STANDING_SPAN,
		"directions": Guide.DIRECTIONS,
		"gaits": GAITS,
		"attacks": ATTACKS,
		"phases": PHASES,
		"bone_lengths": source_data.bone_lengths,
		"frame_count": poses.size(),
		"pose_policy": "W2 source torso/head/current relative gait retained; fixed-length IK changes attack limbs; one shared 48/84 pivot; no per-frame scale or magic pixels",
		"timeline_contract": {
			"physical_kind": {"none": 0, "punch": 1, "kick": 2},
			"physical_phase": {"none": 0, "startup": 1, "active": 2, "recovery": 3},
			"physical_phase_ticks_remaining": "nonnegative integer",
			"physical_phase_ticks_total": "positive integer while active",
			"physical_aim_x": "latched signed fixed world component",
			"physical_aim_y": "latched signed fixed world component",
			"physical_sequence_id": "monotonic per-actor integer",
			"movement_policy": "attacks remain freely movable; gait follows the current idle/forward/right/back/left travel-to-aim relationship; paid slide/roll/air-dodge/wall-jump may interrupt without creating a free attack-spam cancel",
		},
		"poses": poses,
	}
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	if file == null:
		push_error("Could not write melee candidate rig data")
		quit(1)
		return
	file.store_string(JSON.stringify(data) + "\n")
	print("PASS: exported 720 fixed-bone melee poses (3 bodies x 8 aims x 5 gaits x 2 attacks x 3 phases)")
	quit(0)


func _index_sources(data: Dictionary) -> Dictionary:
	var result := {}
	for pose: Dictionary in data.poses:
		var state: String = pose.state
		if state == "grounded":
			result[_source_key(String(pose.body), state, int(pose.aim), -1, -1)] = pose
		elif state == "locomotion" and int(pose.phase) == 0:
			result[_source_key(String(pose.body), state, int(pose.aim), int(pose.travel), 0)] = pose
	return result


func _source_key(body: String, state: String, aim: int, travel: int, phase: int) -> String:
	return "%s/%s/%d/%d/%d" % [body, state, aim, travel, phase]


func _source_pose(index: Dictionary, body: String, aim: int, gait: Dictionary) -> Dictionary:
	if gait.travel_offset == null:
		return index.get(_source_key(body, "grounded", aim, -1, -1), {})
	var travel := posmod(aim + int(gait.travel_offset), 8)
	return index.get(_source_key(body, "locomotion", aim, travel, 0), {})


func _v(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


func _store_v(target: Dictionary, key: String, value: Vector3) -> void:
	target[key] = [value.x, value.y, value.z]


func _melee_pose(source: Dictionary, attack: String, phase: String) -> Dictionary:
	var pose: Dictionary = source.duplicate(true)
	pose["source_state"] = String(source.state)
	pose["source_travel"] = int(source.travel)
	pose["source_motion_phase"] = int(source.phase)
	pose["state"] = "melee"
	var landmarks: Dictionary = pose.landmarks
	var pelvis := _v(landmarks.pelvis)
	var shoulder_mid := (_v(landmarks.shoulder_l) + _v(landmarks.shoulder_r)) * 0.5
	var up := (shoulder_mid - pelvis).normalized()
	var right := (_v(landmarks.shoulder_r) - _v(landmarks.shoulder_l)).normalized()
	var forward := up.cross(right).normalized()
	var changed: Array[String] = []
	if attack == "punch":
		_pose_punch(landmarks, phase, up, right, forward, changed)
	else:
		assert(attack == "kick")
		_pose_kick(landmarks, phase, int(pose.aim), up, right, forward, changed)
	_reproject(pose, changed)
	_refresh_chain_depths(pose)
	_validate_fixed_bones(pose)
	return pose


func _pose_punch(landmarks: Dictionary, phase: String, up: Vector3, right: Vector3, forward: Vector3, changed: Array[String]) -> void:
	var strike_shoulder := _v(landmarks.shoulder_r)
	var strike_hand: Vector3
	if phase == "startup":
		strike_hand = strike_shoulder + right * 0.045 - forward * 0.105 - up * 0.095
	elif phase == "active":
		strike_hand = strike_shoulder + right * 0.015 + forward * 0.292 - up * 0.025
	else:
		assert(phase == "recovery")
		strike_hand = strike_shoulder - right * 0.015 + forward * 0.175 - up * 0.115
	_set_arm(landmarks, "r", strike_hand, up, right, forward, changed)
	var guard_shoulder := _v(landmarks.shoulder_l)
	var guard_forward := 0.105 if phase == "active" else 0.135
	var guard_hand := guard_shoulder + right * 0.035 + forward * guard_forward - up * 0.105
	_set_arm(landmarks, "l", guard_hand, up, right, forward, changed)


func _pose_kick(landmarks: Dictionary, phase: String, aim: int, up: Vector3, right: Vector3, forward: Vector3, changed: Array[String]) -> void:
	var hip := _v(landmarks.hip_r)
	var ankle: Vector3
	var bend_hint := forward + up * 0.45 - right * 0.15
	var foot_axis := forward
	if phase == "startup":
		ankle = hip + right * 0.018 + forward * 0.115 - up * 0.185
	elif phase == "active":
		# A modest outward hip angle keeps toward/away kicks readable beside the
		# torso and support leg. Reach stays fixed; this is no per-frame scale.
		if aim == 4:
			# North needs a little more silhouette separation under foreshortening.
			ankle = hip + right * 0.175 + forward * 0.325 - up * 0.060
		else:
			ankle = hip + right * 0.105 + forward * 0.345 - up * 0.060
		bend_hint = forward + up * 0.38 + right * 0.30
		foot_axis = (forward * 0.925 + right * 0.380).normalized()
	else:
		assert(phase == "recovery")
		ankle = hip - right * 0.012 + forward * 0.175 - up * 0.145
	var leg := Guide.two_bone(hip, ankle, Guide.THIGH, Guide.SHIN, bend_hint)
	assert(not leg.is_empty(), "Kick leg must remain reachable without bone scaling")
	_store_v(landmarks, "knee_r", leg.joint)
	_store_v(landmarks, "ankle_r", ankle)
	_store_v(landmarks, "toe_r", ankle + foot_axis * Guide.FOOT)
	changed.append_array(["knee_r", "ankle_r", "toe_r"])
	for side: String in ["l", "r"]:
		var lateral := -1.0 if side == "l" else 1.0
		var shoulder := _v(landmarks["shoulder_" + side])
		var hand := shoulder - right * lateral * 0.025 + forward * (0.145 if side == "l" else 0.115) - up * (0.090 if phase == "active" else 0.115)
		_set_arm(landmarks, side, hand, up, right, forward, changed)


func _set_arm(landmarks: Dictionary, side: String, hand: Vector3, up: Vector3, right: Vector3, forward: Vector3, changed: Array[String]) -> void:
	var lateral := -1.0 if side == "l" else 1.0
	var shoulder := _v(landmarks["shoulder_" + side])
	var arm := Guide.two_bone(shoulder, hand, Guide.HUMERUS, Guide.FOREARM, right * lateral + forward * 0.30 - up * 0.12)
	assert(not arm.is_empty(), "Melee arm must remain reachable without bone scaling")
	_store_v(landmarks, "elbow_" + side, arm.joint)
	_store_v(landmarks, "hand_" + side, hand)
	changed.append("elbow_" + side)
	changed.append("hand_" + side)


func _reproject(pose: Dictionary, changed: Array[String]) -> void:
	var landmarks: Dictionary = pose.landmarks
	var points: Dictionary = pose.points
	var body: String = pose.body
	var direction: String = pose.direction
	var height := float(Guide.HEIGHTS[body])
	var pelvis := _v(landmarks.pelvis)
	var pelvis_point := Vector2(float(points.pelvis[0]), float(points.pelvis[1]))
	var anchor := pelvis_point - Guide.project(pelvis, direction, height)
	for key: String in changed:
		var projected := anchor + Guide.project(_v(landmarks[key]), direction, height)
		points[key] = [projected.x, projected.y]


func _refresh_chain_depths(pose: Dictionary) -> void:
	var landmarks: Dictionary = pose.landmarks
	var direction: String = pose.direction
	for chain: Dictionary in pose.chains:
		var total := 0.0
		for key: String in chain["keys"]:
			total += Guide.depth(_v(landmarks[key]), direction)
		chain.depth = total / float((chain["keys"] as Array).size())
	(pose.chains as Array).sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.depth) < float(b.depth))


func _validate_fixed_bones(pose: Dictionary) -> void:
	var landmarks: Dictionary = pose.landmarks
	for side: String in ["l", "r"]:
		for bone: Array in [
			["hip_" + side, "knee_" + side, Guide.THIGH],
			["knee_" + side, "ankle_" + side, Guide.SHIN],
			["ankle_" + side, "toe_" + side, Guide.FOOT],
			["shoulder_" + side, "elbow_" + side, Guide.HUMERUS],
			["elbow_" + side, "hand_" + side, Guide.FOREARM],
		]:
			var actual := _v(landmarks[bone[0]]).distance_to(_v(landmarks[bone[1]]))
			assert(absf(actual - float(bone[2])) < 0.00001, "Melee pose changed a fixed bone length")
