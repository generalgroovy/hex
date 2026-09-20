extends FluxTestSuite


const CATALOG_PATH: String = "res://content/materials/foundation_materials_v1.json"
const YARD_PATH: String = "res://content/maps/sanctum_material_yard_v1.json"


func run() -> int:
	_test_repository_content()
	_test_invalid_catalogs_fail_closed()
	_test_invalid_yards_fail_closed()
	return finish("material-content")


func _test_repository_content() -> void:
	var registry := MaterialRegistry.new()
	check(registry.load_from_file(CATALOG_PATH), "foundation material registry validates: %s" % registry.last_error)
	equal(registry.materials_by_id.size(), 11, "foundation registry has eleven occupancy materials")
	equal(registry.wire_id("empty"), 1, "empty wire id is stable")
	equal(registry.wire_id("worldbone"), 2, "worldbone wire id is stable")
	equal(registry.material_id(11), "rubble", "wire lookup is reversible")
	check(bool(registry.material("worldbone").get("immutable", false)), "worldbone is immutable")
	check(not bool(registry.material("stone").get("immutable", true)), "ordinary stone remains mutable")
	check((registry.data.get("cell_fields", []) as Array).has("charge"), "Charge is an independent cell field")
	equal(registry.content_hash.length(), 64, "material catalog has a canonical SHA-256 hash")

	var yard := MaterialYardDefinition.new()
	check(yard.load_from_file(YARD_PATH, registry), "Sanctum Material Yard validates: %s" % yard.last_error)
	equal(yard.width, 128, "yard width is bounded to 128")
	equal(yard.height, 128, "yard height is bounded to 128")
	equal(yard.chunk_size, 16, "yard chunk size is authored")
	equal(yard.max_awake_cells_per_second, 30_720, "yard work budget is authored per real second")
	equal(yard.content_hash.length(), 64, "yard has a canonical SHA-256 hash")


func _test_invalid_catalogs_fail_closed() -> void:
	var valid := MaterialRegistry.new()
	check(valid.load_from_file(CATALOG_PATH), "valid catalog loads for negative tests")

	var duplicate_wire := MaterialRegistry.new()
	duplicate_wire.data = valid.data.duplicate(true)
	var duplicate_materials: Array = duplicate_wire.data.get("materials", [])
	(duplicate_materials[2] as Dictionary)["wire_id"] = int((duplicate_materials[1] as Dictionary).get("wire_id", 0))
	check(not duplicate_wire.validate(), "duplicate material wire ids fail closed")
	check(duplicate_wire.last_error.contains("wire ids"), "duplicate wire failure is diagnosable")

	var mutable_worldbone := MaterialRegistry.new()
	mutable_worldbone.data = valid.data.duplicate(true)
	for value: Variant in mutable_worldbone.data.get("materials", []):
		var material: Dictionary = value
		if String(material.get("id", "")) == "worldbone":
			material["immutable"] = false
	check(not mutable_worldbone.validate(), "mutable worldbone fails closed")
	check(mutable_worldbone.last_error.contains("worldbone"), "worldbone failure is diagnosable")

	var missing_charge := MaterialRegistry.new()
	missing_charge.data = valid.data.duplicate(true)
	(missing_charge.data.get("cell_fields", []) as Array).erase("charge")
	check(not missing_charge.validate(), "missing Charge field fails closed")
	check(missing_charge.last_error.contains("charge"), "missing field failure is diagnosable")

	var undeclared_required := MaterialRegistry.new()
	undeclared_required.data = valid.data.duplicate(true)
	(undeclared_required.data.get("required_material_ids", []) as Array).erase("rubble")
	check(not undeclared_required.validate(), "undeclared foundation material fails closed")
	check(undeclared_required.last_error.contains("rubble"), "required-material failure is diagnosable")


func _test_invalid_yards_fail_closed() -> void:
	var registry := MaterialRegistry.new()
	check(registry.load_from_file(CATALOG_PATH), "catalog loads for yard negative tests")
	var valid := MaterialYardDefinition.new()
	check(valid.load_from_file(YARD_PATH, registry), "valid yard loads for negative tests")

	var wrong_size := MaterialYardDefinition.new()
	wrong_size.data = valid.data.duplicate(true)
	wrong_size.data["width"] = 127
	check(not wrong_size.validate(registry), "non-128 yard fails closed")

	var overlap := MaterialYardDefinition.new()
	overlap.data = valid.data.duplicate(true)
	(overlap.data.get("seed_rects", []) as Array).append({
		"x": 0, "y": 0, "width": 1, "height": 1, "material": "stone"
	})
	check(not overlap.validate(registry), "overlapping seed rectangles fail closed")
	check(overlap.last_error.contains("overlap"), "overlap failure is diagnosable")

	var broken_perimeter := MaterialYardDefinition.new()
	broken_perimeter.data = valid.data.duplicate(true)
	(broken_perimeter.data.get("seed_rects", []) as Array).remove_at(0)
	check(not broken_perimeter.validate(registry), "incomplete worldbone perimeter fails closed")
	check(broken_perimeter.last_error.contains("perimeter"), "perimeter failure is diagnosable")

	var unknown_material := MaterialYardDefinition.new()
	unknown_material.data = valid.data.duplicate(true)
	((unknown_material.data.get("seed_rects", []) as Array)[5] as Dictionary)["material"] = "missing"
	check(not unknown_material.validate(registry), "unknown seeded material fails closed")
	check(unknown_material.last_error.contains("unknown"), "unknown material failure is diagnosable")

	var undeclared_seed := MaterialYardDefinition.new()
	undeclared_seed.data = valid.data.duplicate(true)
	(undeclared_seed.data.get("required_seed_materials", []) as Array).erase("rubble")
	check(not undeclared_seed.validate(registry), "undeclared required seed material fails closed")
	check(undeclared_seed.last_error.contains("rubble"), "required-seed failure is diagnosable")
