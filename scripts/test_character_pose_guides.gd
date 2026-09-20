extends SceneTree

const Guide := preload("res://art_batches/character_style_v1/template_v2/pose_guide_model.gd")
var assertions := 0
var failures := 0


func _initialize() -> void:
	var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art_batches/character_style_v1/template_v2/contract.json"))
	var runtime_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/visual/foundation_champion_visuals_v1.json"))
	check(contract.body_build_order == Guide.HEIGHTS.keys(), "construction order matches production contract")
	check(contract.rows == Guide.STATES, "construction states match current atlas grammar")
	check(contract.cell == runtime_contract.cell and contract.feet_pivot == runtime_contract.pivot, "construction registration matches runtime")
	check(int(contract.camera_elevation_degrees) == int(runtime_contract.art_camera.elevation_degrees), "construction camera matches runtime")
	for body: String in Guide.HEIGHTS:
		check(int(contract.standing_height_pixels[body]) == int(Guide.HEIGHTS[body]), "guide height matches production")
		check(int(runtime_contract.body_template_contract.templates[body].reference_height) == int(Guide.HEIGHTS[body]), "guide height matches runtime")
	for index: int in range(8):
		check(contract.directions[index].id == Guide.DIRECTIONS[index], "guide direction order matches production")
		check(int(contract.directions[index].yaw_degrees) == index * 45, "explicit eighth-turn yaw")
	for body: String in Guide.HEIGHTS:
		for direction: String in Guide.DIRECTIONS:
			for state: String in Guide.STATES:
				var data := Guide.pose(body, state, direction)
				check(data.points.size() == 18, "fixed landmark count")
				check(not data.finished_art, "construction never claims artwork")
				for point: Vector2 in data.points.values():
					check(point.is_finite(), "finite landmark")
				for side: String in ["l", "r"]:
					for link: Array in [["hip_", "knee_", Guide.THIGH], ["knee_", "ankle_", Guide.SHIN], ["ankle_", "toe_", Guide.FOOT], ["shoulder_", "elbow_", Guide.HUMERUS], ["elbow_", "hand_", Guide.FOREARM]]:
						var bone_length: float = (data.landmarks[String(link[0]) + side] as Vector3).distance_to(data.landmarks[String(link[1]) + side])
						check(absf(bone_length - float(link[2])) < 0.00001, "every size/heading/pose preserves normalized anatomy")
				var twice := Guide.pose(body, state, direction)
				check(data == twice, "pure deterministic guide")
	for gait: String in ["walk", "sprint"]:
		var a := Guide.landmarks(gait)
		var b := Guide.landmarks(gait + "_b")
		check(a.ankle_l.y > a.ankle_r.y and b.ankle_r.y > b.ankle_l.y, "actual support chains oppose")
		check(a.knee_l.y > a.knee_r.y and b.knee_r.y > b.knee_l.y, "knees oppose with ankles")
		check(a.hand_r.y > a.hand_l.y and b.hand_l.y > b.hand_r.y, "opposite arm counter swing")
		for direction: String in Guide.DIRECTIONS:
			var pa := Guide.pose("middle", gait, direction)
			var pb := Guide.pose("middle", gait + "_b", direction)
			check(pa.points.ankle_l != pb.points.ankle_l, "anatomical left ankle moves in every heading")
			check(pa.points.ankle_r != pb.points.ankle_r, "anatomical right ankle moves in every heading")
	check(Guide.pose("huge", "walk", "south").is_empty(), "old size rejected")
	check(Guide.pose("middle", "vault", "south").is_empty(), "unsupported pose rejected")
	check(Guide.pose("middle", "walk", "sideways").is_empty(), "ambiguous heading rejected")
	check(Guide.project(Vector3.RIGHT, "south", 1).x < 0, "front anatomical right is screen left")
	check(Guide.project(Vector3.RIGHT, "north", 1).x > 0, "back anatomical right is screen right")
	check(Guide.project(Vector3(0, 1, 0), "north_east", 1).x > 0 and Guide.project(Vector3(0, 1, 0), "north_east", 1).y < 0, "NE forward projects up right")
	_test_fixed_volume_and_guards()
	print("Pose construction guides: ", assertions, " assertions, ", failures, " failures")
	quit(0 if failures == 0 else 1)


func _test_fixed_volume_and_guards() -> void:
	for state: String in Guide.STATES:
		var rig := Guide.landmarks(state)
		check(rig.size() == 18, "all authored IK goals remain reachable")
		for side: String in ["l", "r"]:
			for link: Array in [["hip_", "knee_", Guide.THIGH], ["knee_", "ankle_", Guide.SHIN], ["ankle_", "toe_", Guide.FOOT], ["shoulder_", "elbow_", Guide.HUMERUS], ["elbow_", "hand_", Guide.FOREARM]]:
				var length: float = (rig[String(link[0]) + side] as Vector3).distance_to(rig[String(link[1]) + side])
				check(absf(length - float(link[2])) < 0.00001, state + "/" + side + " preserves exact bone length")
		var shoulders: Vector3 = (rig.shoulder_l + rig.shoulder_r) * 0.5
		check(absf(shoulders.distance_to(rig.pelvis) - Guide.TORSO) < 0.00001, "torso leans rigidly, never shrinks for crouch")
		check(absf((rig.shoulder_l as Vector3).distance_to(rig.shoulder_r) - 0.32) < 0.00001, "shoulder width is constant")
		check(absf((rig.hip_l as Vector3).distance_to(rig.hip_r) - 0.18) < 0.00001, "hip width is constant")
		check(absf((rig.head as Vector3).distance_to(shoulders) - 0.165) < 0.00001, "head/neck offset remains rigid")
		check(absf((rig.nose as Vector3).distance_to(rig.head) - 0.11) < 0.00001, "head facing marker cannot stretch on recoil")
		for direction: String in Guide.DIRECTIONS:
			var small := Guide.pose("small", state, direction)
			for body: String in ["middle", "large"]:
				var other := Guide.pose(body, state, direction)
				for key: String in small.points:
					var normalized_small: Vector2 = (small.points[key] - Vector2(48, 83)) / 58.0
					var normalized_other: Vector2 = (other.points[key] - Vector2(48, 83)) / float(Guide.HEIGHTS[body])
					check(normalized_small.distance_to(normalized_other) < 0.00001, "all three sizes use the same pose, not per-pose rescaling")
			var order: Array = small.chains
			for index: int in range(order.size() - 1):
				check(float(order[index].depth) <= float(order[index + 1].depth), "painter chains are sorted by camera depth")
			if direction in ["east", "west"]:
				var expected_near := "r" if direction == "east" else "l"
				check(order.back().side == expected_near, "profile near anatomy follows yaw, not a fixed color")
	for gait: String in ["walk", "sprint"]:
		var a := Guide.landmarks(gait)
		var b := Guide.landmarks(gait + "_b")
		check(a.ankle_l.z == 0.0 and a.ankle_r.z > 0.0 and b.ankle_r.z == 0.0 and b.ankle_l.z > 0.0, "A/B visibly exchange support and raised passing foot")
		for key: String in ["head", "neck", "pelvis"]:
			check(a[key] == b[key], "paired contacts retain the same rigid body volume")
	var valid := Guide.two_bone(Vector3.ZERO, Vector3(0, 0, -0.4), 0.20, 0.23, Vector3(0, 1, 0))
	check(not valid.is_empty(), "reachable two-bone target accepted")
	check(Guide.two_bone(Vector3.ZERO, Vector3(0, 0, -0.5), 0.20, 0.23, Vector3(0, 1, 0)).is_empty(), "unreachable target rejects instead of stretching")
	check(Guide.two_bone(Vector3.ZERO, Vector3(0, 0, -0.01), 0.20, 0.23, Vector3(0, 1, 0)).is_empty(), "overfolded target rejects instead of shrinking")
	check(Guide.two_bone(Vector3.ZERO, Vector3.ZERO, 0.20, 0.23, Vector3(0, 1, 0)).is_empty(), "coincident IK endpoint is not a valid bend plane")
	check(Guide.two_bone(Vector3.ZERO, Vector3(0, 0, -0.4), 0.20, 0.23, Vector3(0, 0, 1)).is_empty(), "parallel bend hint rejects ambiguous knee flipping")
	check(Guide.two_bone(Vector3.INF, Vector3.ZERO, 0.20, 0.23, Vector3(0, 1, 0)).is_empty(), "infinite IK input rejects")
	check(Guide.two_bone(Vector3.ZERO, Vector3(0, 0, -0.4), NAN, 0.23, Vector3(0, 1, 0)).is_empty(), "NaN bone length rejects")
	check(Guide.project(Vector3.INF, "south", 58) == Vector2.ZERO, "infinite landmark fails closed")
	check(Guide.project(Vector3.ONE, "south", NAN) == Vector2.ZERO, "NaN scale fails closed")
	check(Guide.project(Vector3.ONE, "south", INF) == Vector2.ZERO, "infinite scale fails closed")
	check(Guide.project(Vector3.ONE, "south", -1) == Vector2.ZERO, "negative scale fails closed")
	check(is_nan(Guide.depth(Vector3.ONE, "invalid")), "invalid heading is not a valid depth")


func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(message)
