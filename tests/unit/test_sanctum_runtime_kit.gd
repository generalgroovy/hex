extends FluxTestSuite


func run() -> int:
	_test_repository_runtime_kit()
	_test_runtime_kit_fails_closed()
	return finish("sanctum-runtime-kit")


func _test_repository_runtime_kit() -> void:
	var kit := SanctumRuntimeKit.new()
	check(kit.load_from_file(), "runtime kit validates and imports: %s" % kit.last_error)
	equal(
		SanctumRuntimeKit.canonical_text_sha256("res://scripts/generate_sanctum_runtime_kit.gd"),
		String((kit.data.get("provenance", {}) as Dictionary).get("generator_sha256", "")),
		"generator provenance hash is stable across platform line endings",
	)
	equal(String(kit.data.get("status")), "runtime-approved", "runtime approval is explicit")
	check(not bool(kit.data.get("release_approved", true)), "release approval remains false")
	equal(String(kit.data.get("authority")), "presentation-only", "runtime kit cannot define gameplay")
	equal(kit.modules_by_id.size(), 8, "runtime kit declares eight unique modules")
	equal(kit.textures_by_id.size(), 8, "all runtime textures import")
	for module_id: String in SanctumRuntimeKit.REQUIRED_MODULES:
		check(kit.module(module_id).has("role"), "runtime module has a role: %s" % module_id)
		check(kit.texture(module_id) != null, "runtime module has an imported texture: %s" % module_id)


func _test_runtime_kit_fails_closed() -> void:
	var source := SanctumRuntimeKit.new()
	check(source.load_from_file(SanctumRuntimeKit.MANIFEST_PATH, false), "runtime kit loads as mutation source")
	var mutations: Array[Callable] = [
		func(data: Dictionary) -> void: data["runtime_approved"] = false,
		func(data: Dictionary) -> void: data["release_approved"] = true,
		func(data: Dictionary) -> void: data["authority"] = "collision",
		func(data: Dictionary) -> void: (data["provenance"] as Dictionary)["third_party_pixel_inputs"] = true,
		func(data: Dictionary) -> void: (data["provenance"] as Dictionary)["generator_sha256"] = "0".repeat(64),
		func(data: Dictionary) -> void: (data["pixel_contract"] as Dictionary)["world_units_per_pixel"] = 2,
		func(data: Dictionary) -> void: (data["modules"][0] as Dictionary)["id"] = "deep-water",
		func(data: Dictionary) -> void: (data["modules"][0] as Dictionary)["path"] = "res://assets/concept/candidate.png",
		func(data: Dictionary) -> void: (data["modules"][0] as Dictionary)["sha256"] = "0".repeat(64),
		func(data: Dictionary) -> void: (data["modules"][0] as Dictionary)["pivot"] = [99, 99],
		func(data: Dictionary) -> void: (data["budgets"] as Dictionary)["maximum_decoded_rgba_bytes"] = 1,
	]
	for mutation: Callable in mutations:
		var kit := SanctumRuntimeKit.new()
		kit.data = source.data.duplicate(true)
		mutation.call(kit.data)
		check(not kit.validate(false), "invalid runtime-kit mutation fails closed")
		check(not kit.last_error.is_empty(), "invalid runtime-kit mutation is diagnosable")
