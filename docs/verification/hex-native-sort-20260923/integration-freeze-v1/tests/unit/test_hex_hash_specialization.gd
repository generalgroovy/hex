extends FluxTestSuite


const World = preload("res://src/sim/hex/hex_chemistry_world.gd")
const FrozenOracle = preload("res://tests/support/hex_stable_cells_candidate.gd")
const CanonicalBytes = preload("res://src/sim/core/canonical_bytes.gd")
const Grid = preload("res://src/sim/hex/hex_grid.gd")
const EXPECTED_EQUIVALENCE_CASES := 45

var equivalence_cases_completed := 0


func run() -> int:
	_test_core_and_nested_cases()
	_test_malformed_metadata_cases()
	_test_material_layer_and_tie_cases()
	_test_fast_path_mutation_cases()
	_test_layer_transition_and_empty_world_cases()
	_test_native_key_order_cases()
	equal(equivalence_cases_completed, EXPECTED_EQUIVALENCE_CASES, "all production hash equivalence cases complete")
	return finish("hex-hash-specialization")


func _test_core_and_nested_cases() -> void:
	var topology: Array[Vector2i] = [Vector2i(3, -7), Vector2i(-12, 4), Vector2i.ZERO, Vector2i(-2, -11)]
	var world := _configured_world(Vector2i(-240_000, 360_000), topology, "core equivalence fixture")
	if world == null:
		return
	world.cells[Vector2i(3, -7)].terrain = -17
	world.cells[Vector2i(-12, 4)].elevation = 9
	world.cells[Vector2i.ZERO].structure = 4
	_assert_equivalent(world, "integral metadata and negative cells")
	var original_hash := world.state_hash()
	var reversed := {}
	for index: int in range(topology.size() - 1, -1, -1):
		reversed[topology[index]] = world.cells[topology[index]]
	world.cells = reversed
	_assert_equivalent(world, "reordered cell insertion")
	equal(world.state_hash(), original_hash, "reordered insertion preserves the published hash")

	world.cells[topology[0]]["extra_scalar"] = 17
	world.cells[topology[1]]["extra_empty"] = {}
	world.cells[topology[2]]["extra_mixed"] = {4: ["opaque", null, true], "4": {Vector2i(-1, 2): false}, Vector2i(4, -3): [1, {2: "nested"}]}
	world.cells[topology[3]][World.material_layers()[0]][77_001] = 23
	_assert_equivalent(world, "extras mixed nested values and nonempty layer fallback")

	world.cells[topology[0]].terrain = {}
	world.cells[topology[1]].elevation = [3, null, {2: false}]
	world.cells[topology[2]].erase("structure")
	_assert_equivalent(world, "malformed and missing metadata fallback")

	var before_cells: Dictionary = world.cells.duplicate(true)
	var before_hash := world.state_hash()
	var nested: Dictionary = world.cells[topology[2]].extra_mixed
	nested["mutation"] = [Vector2i(8, -5), {9: "visible"}]
	check(world.state_hash() != before_hash, "nested public mutation is visible to the next production hash call")
	_assert_equivalent(world, "between-call nested mutation")
	world.cells = before_cells
	_assert_equivalent(world, "restored nested authority")
	equal(world.state_hash(), before_hash, "deep restoration recovers the original published hash")


func _test_malformed_metadata_cases() -> void:
	var metadata_values: Array[Dictionary] = [
		{"type": "float", "value": 2.5},
		{"type": "boolean", "value": true},
		{"type": "null", "value": null},
		{"type": "string", "value": "direct-metadata"},
	]
	var metadata_keys: Array[String] = ["terrain", "elevation", "structure"]
	var malformed_cells: Array[Vector2i] = [Vector2i(-5, 8)]
	for metadata_key: String in metadata_keys:
		for value_case: Dictionary in metadata_values:
			var malformed := _configured_world(Vector2i(-24_000, 36_000), malformed_cells, "%s %s metadata fixture" % [metadata_key, value_case.type])
			if malformed == null:
				continue
			malformed.cells[Vector2i(-5, 8)][metadata_key] = value_case.value
			_assert_equivalent(malformed, "%s metadata with %s value" % [metadata_key, value_case.type])

	var missing_cells: Array[Vector2i] = [Vector2i(9, -6)]
	var missing := _configured_world(Vector2i(12_000, -18_000), missing_cells, "missing metadata fixture")
	if missing == null:
		return
	for metadata_key: String in metadata_keys:
		var missing_record: Dictionary = missing.cells[Vector2i(9, -6)].duplicate(true)
		missing_record.erase(metadata_key)
		missing.cells[Vector2i(9, -6)] = missing_record
		_assert_equivalent(missing, "missing %s metadata" % metadata_key)
		missing.cells[Vector2i(9, -6)] = World._new_empty_cell()


func _test_material_layer_and_tie_cases() -> void:
	var material_layer: String = World.material_layers()[0]
	var layer_cells: Array[Vector2i] = [Vector2i(6, -9)]
	var missing_layer := _configured_world(Vector2i(-30_000, 42_000), layer_cells, "missing material layer fixture")
	if missing_layer != null:
		missing_layer.cells[Vector2i(6, -9)].erase(material_layer)
		_assert_equivalent(missing_layer, "missing material layer")

	var malformed_layer_values: Array[Dictionary] = [
		{"type": "float", "value": 2.5},
		{"type": "boolean", "value": true},
		{"type": "null", "value": null},
		{"type": "string", "value": "direct-layer"},
	]
	for value_case: Dictionary in malformed_layer_values:
		var malformed_layer := _configured_world(Vector2i(-30_000, 42_000), layer_cells, "malformed material layer %s fixture" % value_case.type)
		if malformed_layer == null:
			continue
		malformed_layer.cells[Vector2i(6, -9)][material_layer] = value_case.value
		_assert_equivalent(malformed_layer, "material layer with %s value" % value_case.type)

	var tie_cells: Array[Vector2i] = [Vector2i(-4, 11)]
	for int_key_first: bool in [true, false]:
		var order_label := "integer-first" if int_key_first else "string-first"
		var tie_world := _configured_world(Vector2i(54_000, -66_000), tie_cells, "%s tie fixture" % order_label)
		if tie_world == null:
			continue
		var nested_tie := {}
		if int_key_first:
			nested_tie[4] = "integer-key"
			nested_tie["4"] = "string-key"
		else:
			nested_tie["4"] = "string-key"
			nested_tie[4] = "integer-key"
		tie_world.cells[Vector2i(-4, 11)]["equal_format_tie"] = nested_tie
		_assert_equivalent(tie_world, "%s nested integer/string equal-format tie" % order_label)


func _test_fast_path_mutation_cases() -> void:
	var metadata_keys: Array[String] = ["terrain", "elevation", "structure"]
	var fast_path_cells: Array[Vector2i] = [Vector2i(7, -13)]
	var world := _configured_world(Vector2i(-72_000, 84_000), fast_path_cells, "empty fast-path mutation fixture")
	if world == null:
		return
	var original_hash := world.state_hash()
	for metadata_index: int in metadata_keys.size():
		var metadata_key: String = metadata_keys[metadata_index]
		world.cells[Vector2i(7, -13)][metadata_key] = 101 + metadata_index
		_assert_equivalent(world, "empty fast-path %s integer mutation" % metadata_key)
		check(world.state_hash() != original_hash, "empty fast-path %s integer mutation changes the published hash" % metadata_key)
		world.cells[Vector2i(7, -13)][metadata_key] = 0
		_assert_equivalent(world, "empty fast-path %s integer restoration" % metadata_key)
		equal(world.state_hash(), original_hash, "empty fast-path %s integer restoration recovers the published hash" % metadata_key)


func _test_layer_transition_and_empty_world_cases() -> void:
	var material_layer: String = World.material_layers()[0]
	var transition_cells: Array[Vector2i] = [Vector2i(-8, 14)]
	var world := _configured_world(Vector2i(90_000, -102_000), transition_cells, "material layer transition fixture")
	if world != null:
		var original_hash := world.state_hash()
		_assert_equivalent(world, "empty material layer before transition")
		world.cells[Vector2i(-8, 14)][material_layer][880_001] = 37
		_assert_equivalent(world, "material layer empty to nonempty transition")
		check(world.state_hash() != original_hash, "nonempty material layer changes the published hash")
		world.cells[Vector2i(-8, 14)][material_layer].erase(880_001)
		_assert_equivalent(world, "material layer nonempty to empty restoration")
		equal(world.state_hash(), original_hash, "empty material layer restoration recovers the published hash")

	var empty_world := World.new()
	check(empty_world.cells.is_empty(), "empty cells dictionary fixture starts empty")
	_assert_equivalent(empty_world, "empty cells dictionary")


func _test_native_key_order_cases() -> void:
	var one := _configured_world(Vector2i(-11_000, 13_000), [Vector2i(1, -10)], "one-cell native order fixture")
	if one != null:
		_assert_equivalent(one, "one-cell native string order")

	var lexical_cells: Array[Vector2i] = [
		Vector2i(12, 3), Vector2i(1, 23), Vector2i(2, 0), Vector2i(10, 0),
		Vector2i(-1, 10), Vector2i(-1, 2), Vector2i(1, -10), Vector2i(1, -2),
	]
	var lexical := _configured_world(Vector2i(17_000, -19_000), lexical_cells, "lexicographic-looking position fixture")
	if lexical != null:
		lexical.cells[Vector2i(12, 3)].terrain = -4
		lexical.cells[Vector2i(1, 23)][World.material_layers()[0]][71] = 9
		lexical.cells[Vector2i(-1, 2)]["mixed_extra"] = {4: "integer", "4": "string", Vector2i(1, -2): [null, true, 2.5]}
		_assert_equivalent(lexical, "negative and lexicographic-looking positions")
		var original_hash: String = lexical.state_hash()
		var original_bytes: PackedByteArray = lexical._state_hash_bytes()
		var reversed: Dictionary = {}
		for index: int in range(lexical_cells.size() - 1, -1, -1):
			var cell: Vector2i = lexical_cells[index]
			reversed[cell] = lexical.cells[cell]
		lexical.cells = reversed
		_assert_equivalent(lexical, "reversed lexicographic-looking insertion order")
		equal(lexical.state_hash(), original_hash, "reversed lexicographic insertion preserves the production hash")
		equal(lexical._state_hash_bytes(), original_bytes, "reversed lexicographic insertion preserves exact production bytes")

		var added_cell := Vector2i(3, -4)
		lexical.cells[added_cell] = World._new_empty_cell()
		_assert_equivalent(lexical, "same-world directly added cell")
		check(lexical.state_hash() != original_hash, "same-world added cell is visible without cached key order")
		lexical.cells.erase(added_cell)
		_assert_equivalent(lexical, "same-world directly removed cell")
		equal(lexical.state_hash(), original_hash, "same-world removal restores the production hash")
		equal(lexical._state_hash_bytes(), original_bytes, "same-world removal restores exact production bytes")
		var reordered: Dictionary = {}
		for cell: Vector2i in lexical_cells:
			reordered[cell] = lexical.cells[cell]
		lexical.cells = reordered
		_assert_equivalent(lexical, "same-world second insertion reorder")
		equal(lexical.state_hash(), original_hash, "same-world second reorder retains the production hash")
		equal(lexical._state_hash_bytes(), original_bytes, "same-world second reorder retains exact production bytes")

	var boundary_cells: Array[Vector2i] = []
	var boundary_disk: Array[Vector2i] = Grid.disk(Vector2i.ZERO, 37)
	for index: int in World.MAX_CELLS:
		boundary_cells.append(boundary_disk[index])
	var boundary := _configured_world(Vector2i.ZERO, boundary_cells, "4,096-cell native order boundary fixture")
	if boundary != null:
		_assert_equivalent(boundary, "4,096-cell maximum topology")


func _configured_world(origin: Vector2i, topology: Array[Vector2i], label: String) -> HexChemistryWorld:
	var world := World.new()
	check(world.configure_geometry(origin, topology), label + " configures")
	return world if world.cells.size() == topology.size() else null


func _assert_equivalent(world: HexChemistryWorld, label: String) -> void:
	var source_identity := world.get_instance_id()
	var source_cells: Dictionary = world.cells.duplicate(true)
	var frozen_bytes := FrozenOracle.frozen_original_bytes(world)
	var production_bytes := world._state_hash_bytes()
	check(not frozen_bytes.is_empty(), label + " frozen canonical bytes are populated")
	equal(production_bytes, frozen_bytes, label + " production bytes match the frozen old implementation")
	equal(world.state_hash(), CanonicalBytes.sha256_hex(frozen_bytes), label + " production hash matches the frozen old bytes")
	equal(world.get_instance_id(), source_identity, label + " preserves the source instance")
	equal(world.cells, source_cells, label + " leaves source cell records unchanged")
	equal(FrozenOracle.frozen_original_bytes(world), frozen_bytes, label + " leaves the complete hashed authority unchanged")
	equivalence_cases_completed += 1
