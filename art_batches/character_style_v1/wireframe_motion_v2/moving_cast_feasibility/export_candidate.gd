extends SceneTree

const Guide := preload("res://art_batches/character_style_v1/template_v2/pose_guide_model.gd")
const ROOT := "res://art_batches/character_style_v1/wireframe_motion_v2/"


func _initialize() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "rig-data.json"))
	if not parsed is Dictionary:
		push_error("W2 rig data is missing")
		quit(1)
		return
	var data: Dictionary = parsed
	var poses: Array = []
	for source: Dictionary in data["poses"]:
		if source["body"] != "large" or source["state"] != "locomotion":
			continue
		for upper_pose: String in ["neutral", "preparation", "recovery"]:
			var posed := _upper_pose(source, upper_pose)
			# Emit arm deltas only. Copying non-arm JSON through Godot would
			# needlessly reformat tiny source floats; Python keeps those exact.
			var packet := {"travel":int(source["travel"]),"aim":int(source["aim"]),"phase":int(source["phase"]),
				"upper_pose":upper_pose,"landmarks":{},"points":{},"arm_depths":{}}
			if upper_pose != "neutral":
				for joint: String in ["elbow_l","hand_l","elbow_r","hand_r"]:
					packet["landmarks"][joint] = posed["landmarks"][joint]
					packet["points"][joint] = posed["points"][joint]
				for chain: Dictionary in posed["chains"]:
					if chain["kind"] == "arm":
						packet["arm_depths"][chain["side"]] = chain["depth"]
			poses.append(packet)
	assert(poses.size() == 1536)
	data["poses"] = poses
	data["candidate_scope"] = "Large walk only; neutral/preparation/recovery; never a live manifest"
	data["w2_rig_sha256"] = FileAccess.get_sha256(ROOT + "rig-data.json")
	data["w2_runtime_manifest_sha256"] = FileAccess.get_sha256("res://assets/sprites/wireframe_motion_v2/manifest.json")
	var file := FileAccess.open(ROOT + "moving_cast_feasibility/candidate-rig.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data) + "\n")
	print("PASS: 1536 Large walking candidate poses; only elbow/hand IK changes")
	quit(0)


func _v(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


func _upper_pose(source: Dictionary, upper_pose: String) -> Dictionary:
	var pose: Dictionary = source.duplicate(true)
	pose["upper_pose"] = upper_pose
	if upper_pose == "neutral":
		return pose
	var landmarks: Dictionary = pose["landmarks"]
	var points: Dictionary = pose["points"]
	var pelvis := _v(landmarks["pelvis"])
	var shoulder_mid := (_v(landmarks["shoulder_l"]) + _v(landmarks["shoulder_r"])) * 0.5
	var up := (shoulder_mid - pelvis).normalized()
	var right := (_v(landmarks["shoulder_r"]) - _v(landmarks["shoulder_l"])).normalized()
	var forward := up.cross(right).normalized()
	var direction: String = pose["direction"]
	var anchor := Vector2(float(points["pelvis"][0]), float(points["pelvis"][1])) - Guide.project(pelvis, direction, 76.0)
	for side: String in ["l", "r"]:
		var lateral := -1.0 if side == "l" else 1.0
		var shoulder := _v(landmarks["shoulder_" + side])
		var hand := shoulder - right * lateral * 0.055 + forward * 0.155 - up * 0.08
		if upper_pose == "recovery":
			hand = shoulder - right * lateral * 0.02 + forward * (0.285 if side == "r" else 0.205) - up * (0.025 if side == "r" else 0.07)
		var arm := Guide.two_bone(shoulder, hand, Guide.HUMERUS, Guide.FOREARM, right * lateral + forward * 0.25 - up * 0.15)
		assert(not arm.is_empty(), "Moving-cast arm must remain reachable without bone scaling")
		for joint: String in ["elbow_" + side, "hand_" + side]:
			var point: Vector3 = arm["joint"] if joint.begins_with("elbow") else hand
			landmarks[joint] = [point.x, point.y, point.z]
			var projected := anchor + Guide.project(point, direction, 76.0)
			points[joint] = [projected.x, projected.y]
	for chain: Dictionary in pose["chains"]:
		if chain["kind"] != "arm":
			continue
		var depth := 0.0
		for joint: String in chain["keys"]:
			depth += Guide.depth(_v(landmarks[joint]), direction)
		chain["depth"] = depth / float(chain["keys"].size())
	(pose["chains"] as Array).sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["depth"]) < float(b["depth"]))
	return pose
