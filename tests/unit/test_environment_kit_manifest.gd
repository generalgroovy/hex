extends FluxTestSuite


const MANIFEST_PATH: String = "res://content/assets/sanctum_modular_kit_candidate_v2.json"


func run() -> int:
	_test_repository_candidate()
	_test_candidate_fails_closed()
	return finish("environment-kit-manifest")


func _test_repository_candidate() -> void:
	var manifest := EnvironmentKitManifest.new()
	check(manifest.load_from_file(MANIFEST_PATH), "G2 environment candidate validates: %s" % manifest.last_error)
	equal(String(manifest.data.get("status")), "candidate", "generated sheet remains a candidate")
	check(not bool(manifest.data.get("runtime_approved", true)), "candidate is not runtime approved")
	equal(String(manifest.data.get("authority")), "presentation-only", "candidate cannot define gameplay")
	equal(manifest.modules_by_id.size(), 12, "candidate declares twelve unique modules")
	for required_id: String in ["warm-stone-ground", "worldbone-cliff", "ordinary-stone-path", "water-shore-corner", "garden-edge", "brass-bridge", "low-vault-rail", "academy-door-wall", "blue-green-roof", "attunement-shrine", "archive-orrey", "proving-basin"]:
		check(manifest.modules_by_id.has(required_id), "candidate module exists: %s" % required_id)
		var output: Dictionary = (manifest.modules_by_id[required_id] as Dictionary).get("output", {})
		check(String(output.get("path", "")).begins_with("res://assets/concept/"), "candidate crop remains excluded: %s" % required_id)
		var pivot: Array = output.get("pivot", [])
		check(pivot.size() == 2 and int(pivot[0]) >= 0 and int(pivot[1]) >= 0, "candidate pivot is bounded: %s" % required_id)


func _test_candidate_fails_closed() -> void:
	var source := EnvironmentKitManifest.new()
	check(source.load_from_file(MANIFEST_PATH), "candidate loads as invalid-manifest source")
	var mutations: Array[Callable] = [
		func(data: Dictionary) -> void: data["status"] = "approved",
		func(data: Dictionary) -> void: data["runtime_approved"] = true,
		func(data: Dictionary) -> void: data["authority"] = "collision",
		func(data: Dictionary) -> void: (data["generator"] as Dictionary)["license_review"] = "",
		func(data: Dictionary) -> void: (data["files"]["source"] as Dictionary)["sha256"] = "0".repeat(64),
		func(data: Dictionary) -> void: (data["files"]["alpha_candidate"] as Dictionary)["path"] = "res://assets/environment/kit.png",
		func(data: Dictionary) -> void: (data["modules"][1] as Dictionary)["id"] = String((data["modules"][0] as Dictionary)["id"]),
		func(data: Dictionary) -> void: (data["modules"][1] as Dictionary)["column"] = 0,
		func(data: Dictionary) -> void: (data["modules"][1] as Dictionary)["row"] = 4,
		func(data: Dictionary) -> void: ((data["modules"][1] as Dictionary)["output"] as Dictionary)["sha256"] = "0".repeat(64),
		func(data: Dictionary) -> void: ((data["modules"][1] as Dictionary)["output"] as Dictionary)["pivot"] = [9999, 9999],
	]
	for mutation: Callable in mutations:
		var candidate := EnvironmentKitManifest.new()
		candidate.data = source.data.duplicate(true)
		mutation.call(candidate.data)
		check(not candidate.validate(), "invalid environment candidate mutation fails closed")
		check(not candidate.last_error.is_empty(), "invalid environment candidate is diagnosable")
