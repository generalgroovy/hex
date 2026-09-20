extends SceneTree

# Candidate-only export. The existing fixed-bone rig remains the editable source.
const Guide := preload("res://art_batches/character_style_v1/template_v2/pose_guide_model.gd")
const OUT := "res://art_batches/character_style_v1/wireframe_base_v1/rig-data.json"


func _initialize() -> void:
	var poses: Array = []
	for body: String in Guide.HEIGHTS:
		for state: String in Guide.STATES:
			for direction: String in Guide.DIRECTIONS:
				var pose := Guide.pose(body, state, direction)
				var points := {}
				var landmarks := {}
				for key: String in pose.points:
					var p: Vector2 = pose.points[key]
					var v: Vector3 = pose.landmarks[key]
					points[key] = [p.x, p.y]
					landmarks[key] = [v.x, v.y, v.z]
				var corners: Array = []
				for p: Vector2 in pose.torso_corners:
					corners.append([p.x, p.y])
				poses.append({"body": body, "state": state, "direction": direction,
					"points": points, "landmarks": landmarks, "torso_corners": corners,
					"chains": pose.chains, "torso_depth": pose.torso_depth,
					"pixels_per_unit": pose.pixels_per_unit, "contact": pose.contact})
	var source := "res://art_batches/character_style_v1/template_v2/pose_guide_model.gd"
	var data := {"schema": 1, "status": "candidate_only_not_accepted",
		"rig_source": source, "rig_sha256": FileAccess.get_sha256(source),
		"cell": [96, 96], "pivot": [48, 84], "last_opaque_y": 83,
		"heights": Guide.HEIGHTS, "directions": Guide.DIRECTIONS, "rows": Guide.STATES,
		"head_radius": Guide.HEAD_RADIUS, "bone_lengths": {"thigh": Guide.THIGH,
			"shin": Guide.SHIN, "humerus": Guide.HUMERUS, "forearm": Guide.FOREARM,
			"foot": Guide.FOOT, "torso": Guide.TORSO}, "poses": poses}
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	if file == null:
		push_error("Could not export candidate rig data")
		quit(1)
		return
	file.store_string(JSON.stringify(data, "\t") + "\n")
	print("PASS: exported 240 fixed-bone candidate poses; no runtime registration")
	quit(0)
