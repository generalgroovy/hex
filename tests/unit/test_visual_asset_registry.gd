extends FluxTestSuite


func run() -> int:
	_test_repository_registry()
	_test_public_paths()
	_test_invalid_registry_fails_closed()
	return finish("visual-asset-registry")


func _test_repository_registry() -> void:
	var registry := VisualAssetRegistry.new()
	check(registry.load_from_file(), "repository visual registry validates: %s" % registry.last_error)
	equal(registry.skeletons.size(), 5, "all five skeleton size atlases exist")
	check(registry.champions.has("nico_lai"), "first champion candidate is registered")
	check(registry.environment.has("sanctum_tiles"), "Sanctum tile kit is registered")
	check(registry.environment.has("nexus_to_conservatory"), "first authored visual slice is registered")
	check(registry.spell_animation_skeletons.has("manifest"), "spell animation skeleton manifest is centrally registered")
	equal((registry.materials.get("order", []) as Array).size(), 11, "all foundation material tiles are registered")
	equal((registry.icons["elements"].get("order", []) as Array).size(), 8, "all enabled element icons are registered")
	equal((registry.icons["abilities"].get("order", []) as Array).size(), 6, "all foundation ability icons are registered")


func _test_public_paths() -> void:
	var registry := VisualAssetRegistry.new()
	check(registry.load_from_file(), "registry loads for public path tests")
	check(FileAccess.file_exists(registry.champion_atlas_path("nico_lai")), "Nico Lai runtime atlas path resolves")
	check(FileAccess.file_exists(registry.champion_atlas_path("nico_lai", true)), "Nico Lai debug atlas path resolves")
	check(FileAccess.file_exists(registry.nexus_preview_path()), "Nexus-to-Conservatory preview path resolves")
	equal(registry.champion_atlas_path("missing"), "", "unknown champion fails closed")


func _test_invalid_registry_fails_closed() -> void:
	var registry := VisualAssetRegistry.new()
	registry.data = {
		"schema_version": 1,
		"character_contract": {"cell_size": [64, 64], "pivot": [16, 28], "directions": []},
		"skeletons": {},
	}
	check(not registry.validate(), "invalid visual contract fails closed")
	check(not registry.last_error.is_empty(), "visual validation failure is diagnosable")
