extends FluxTestSuite


func run() -> int:
	_test_repository_kit()
	_test_fail_closed_contract()
	return finish("wellspring-environment-kit")


func _test_repository_kit() -> void:
	var kit := WellspringEnvironmentKit.new()
	check(kit.load_from_file(), "Wellspring environment kit validates: %s" % kit.last_error)
	equal(kit.modules_by_id.size(), 16, "environment kit has exactly sixteen reusable modules")
	equal(kit.textures_by_id.size(), 16, "every environment module imports as a nearest-sampled texture")
	check(kit.content_hash.length() == 64, "environment kit exposes a stable content identity")
	for module_id: String in WellspringEnvironmentKit.REQUIRED_MODULES:
		check(kit.texture(module_id) != null, "%s is runtime-addressable" % module_id)


func _test_fail_closed_contract() -> void:
	var source := WellspringEnvironmentKit.new()
	check(source.load_from_file(WellspringEnvironmentKit.MANIFEST_PATH, false), "valid environment manifest loads before mutation")
	var kit := WellspringEnvironmentKit.new()
	kit.data = source.data.duplicate(true)
	(kit.data["budgets"] as Dictionary)["decoded_rgba_bytes"] = 1
	check(not kit.validate(false), "incorrect decoded-memory budget fails closed")
	check(not kit.last_error.is_empty(), "environment refusal is actionable")
