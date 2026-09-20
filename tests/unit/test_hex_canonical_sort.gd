extends FluxTestSuite


const HexAuthority = preload("res://src/sim/hex/hex_chemistry_world.gd")
const CanonicalBytes = preload("res://src/sim/core/canonical_bytes.gd")
const TrailEmitter = preload("res://src/sim/hex/hex_trail_emitter.gd")
const ABILITY_PATH := "res://content/abilities/foundation_abilities_v1.json"


func run() -> int:
	_test_string_key_order()
	_test_mixed_key_order()
	_test_randomized_nested_maps()
	var catalog := AbilityCatalog.new()
	var loaded := catalog.load_from_file(ABILITY_PATH)
	check(loaded, "paid canonical-sort fixture loads production abilities: %s" % catalog.last_error)
	if loaded:
		_test_real_paid_authority(catalog)
	return finish("hex-canonical-sort")


func _test_string_key_order() -> void:
	var controls := {}
	var keys: Array[String] = [
		"", "\t", "\n", "control" + String.chr(1), "A", "a", "aa", "aA",
		"z", "ß", "ä", "Ω", "風", "水", "🙂",
	]
	for index: int in keys.size():
		controls[keys[index]] = {"index": index, "nested": {"z": -index, "a": index}}
	_assert_matches_legacy(controls, "Unicode and control String keys")
	_assert_matches_legacy({}, "empty dictionary remains on the legacy path")


func _test_mixed_key_order() -> void:
	var mixed := {}
	mixed["10"] = "String"
	mixed[10] = "int"
	mixed[Vector2i(1, -2)] = "Vector2i"
	mixed[StringName("named-key")] = "StringName"
	mixed[false] = "bool"
	mixed[2.5] = "float"
	mixed["alpha"] = {1: "integer child", "1": "String child"}
	_assert_matches_legacy(mixed, "mixed String/int/Vector2i/StringName/bool/float keys")

	var integers := {20: "twenty", 3: "three", -4: "negative", 11: "eleven"}
	var vectors := {
		Vector2i(2, 0): "east",
		Vector2i(-1, 4): "northwest",
		Vector2i.ZERO: "origin",
	}
	_assert_matches_legacy(integers, "homogeneous integer keys")
	_assert_matches_legacy(vectors, "homogeneous Vector2i keys")


func _test_randomized_nested_maps() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5A17C0DE
	for fixture_index: int in range(64):
		var value: Dictionary = _random_map(rng, 3, fixture_index * 1000)
		_assert_matches_legacy(value, "randomized nested map %d" % fixture_index)


func _test_real_paid_authority(catalog: AbilityCatalog) -> void:
	var world := SimWorld.new()
	check(HexCourtPractice.configure(world, catalog, true), "real paid fixture configures the full radius-six court")
	if not (world.hex_court is HexChemistryWorld):
		return
	var authority: HexChemistryWorld = world.hex_court
	check(authority.cells.size() == HexGrid.disk(Vector2i.ZERO, HexCourt.RADIUS).size(), "fixture hashes every trusted court cell")

	var center := authority.origin + HexGrid.center(Vector2i.ZERO)
	var water_wire := _wire(catalog, "water", "bolt")
	var fire_wire := _wire(catalog, "fire", "bolt")
	var first_bound := _bind_paid(authority, 1, 8_001, water_wire, center)
	var second_bound := _bind_paid(authority, 2, 8_002, fire_wire, center)
	check(first_bound, "first real paid source binds")
	check(second_bound, "second real paid source binds")
	if not first_bound or not second_bound:
		return
	var reaction := authority.resolve_contact(8_001, 8_002, center, 0)
	check(bool(reaction.get("accepted", false)), "two real paid sources form a product")
	check(not authority.products.is_empty(), "paid fixture includes product dictionaries")
	if not bool(reaction.get("accepted", false)) or authority.products.is_empty():
		return

	var trail_source := 8_008 # Divisible by the eight-tick sampler at tick zero.
	var trail_point := center + Vector2i(80_000, 0)
	var trail_bound := _bind_paid(authority, 1, trail_source, fire_wire, trail_point)
	check(trail_bound, "third real paid source binds for a trail")
	if not trail_bound:
		return
	var definition := CombatTuning.cast_definition(fire_wire)
	var shot := ProjectileState.new(
		trail_source, 1, 1, fire_wire, int(definition.element_wire_id),
		trail_point, Vector2i(120_000, 0), int(definition.radius), int(definition.damage), 600
	)
	shot.source_cast_id = trail_source
	shot.reaction_strength = int(definition.reaction_strength)
	shot.initial_strength = shot.reaction_strength
	shot.remaining_strength = shot.reaction_strength
	world.projectiles.append(shot)
	equal(TrailEmitter.emit(world), 1, "real paid projectile creates one finite trail part")
	var trail_record: Dictionary = authority.casts[int(authority.sources[trail_source])]
	check(int(trail_record.get("trail_spent", 0)) > 0 and not trail_record.ground_parts.is_empty(), "paid fixture includes trail dictionaries")
	check(authority.conservation_valid(), "product and trail fixture preserves paid matter")

	_assert_world_matches_legacy(authority, "full paid cells/products/trails authority")
	var previous_hash := authority.state_hash()
	for mutation_index: int in range(4):
		if mutation_index == 0:
			authority.metrics["requested"] = int(authority.metrics.get("requested", 0)) + 1
		elif mutation_index == 1:
			var first_cell: Vector2i = authority.cells.keys()[0]
			authority.cells[first_cell]["elevation"] = int(authority.cells[first_cell].get("elevation", 0)) + 1
		elif mutation_index == 2:
			var product_id: int = int(authority.products.keys()[0])
			authority.products[product_id]["intensity"] = int(authority.products[product_id].intensity) + 1
		else:
			var first_cell: Vector2i = authority.cells.keys()[0]
			authority.cells[first_cell].water[999999] = 1
		var mutated_hash := authority.state_hash()
		check(mutated_hash != previous_hash, "direct nested mutation %d cannot reuse a stale hash" % mutation_index)
		_assert_world_matches_legacy(authority, "directly mutated paid authority %d" % mutation_index)
		previous_hash = mutated_hash


func _assert_matches_legacy(value: Variant, label: String) -> void:
	var actual: Variant = HexAuthority._stable(value)
	var expected: Variant = _original_stable(value)
	equal(actual, expected, "%s preserves the original stable structure" % label)
	var actual_json := JSON.stringify(actual)
	var expected_json := JSON.stringify(expected)
	equal(actual_json.to_utf8_buffer(), expected_json.to_utf8_buffer(), "%s preserves exact canonical JSON bytes" % label)
	equal(_json_hash(actual_json), _json_hash(expected_json), "%s preserves the canonical hash" % label)


func _assert_world_matches_legacy(authority: HexChemistryWorld, label: String) -> void:
	var canonical_value := _authority_value(authority)
	_assert_matches_legacy(canonical_value, label)
	var oracle_json := JSON.stringify(_original_stable(canonical_value))
	equal(authority.state_hash(), _json_hash(oracle_json), "%s state_hash equals the independent original comparator oracle" % label)


func _authority_value(authority: HexChemistryWorld) -> Array:
	# Protocol53 uses a sparse cell-layer hash projection. Keep the independent
	# legacy sorting oracle, but do not assert protocol52's empty-layer bytes.
	# This projection retains all metadata and every populated layer, including
	# direct orphan mutations; it never derives layers from cast/product records.
	var projected_cells: Dictionary = authority.cells.duplicate(true)
	for record: Dictionary in projected_cells.values():
		for key: Variant in record.keys():
			if record[key] is Dictionary and record[key] == {}: record.erase(key)
	return [
		authority.origin,
		authority.current_tick,
		authority.chemistry_enabled,
		authority.next_cast_id,
		authority.next_product_id,
		authority.next_ground_part_id,
		projected_cells,
		authority.casts,
		authority.products,
		authority.pending,
		authority.sources,
		authority.exposure,
		authority.flow_carry,
		authority.metrics,
	]


# Independent copy of the published pre-optimization algorithm. Do not call
# HexChemistryWorld._stable here: this remains the byte-for-byte regression
# oracle if the production implementation changes again.
func _original_stable(value: Variant) -> Variant:
	if value is Vector2i:
		return [value.x, value.y]
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		var result: Array = []
		for key: Variant in keys:
			result.append([_original_stable(key), _original_stable(value[key])])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_original_stable(item))
		return result
	return value


func _json_hash(json: String) -> String:
	var bytes := PackedByteArray()
	CanonicalBytes.append_string(bytes, json)
	return CanonicalBytes.sha256_hex(bytes)


func _random_map(rng: RandomNumberGenerator, depth: int, serial: int) -> Dictionary:
	var result := {}
	var count := rng.randi_range(2, 7)
	var string_only := rng.randi_range(0, 2) == 0
	for index: int in range(count):
		var key: Variant = _random_string_key(rng, serial + index) if string_only else _random_mixed_key(rng, serial + index)
		var choice := rng.randi_range(0, 4)
		if depth > 0 and choice <= 1:
			result[key] = _random_map(rng, depth - 1, serial + index * 31 + 7)
		elif depth > 0 and choice == 2:
			result[key] = [
				_random_map(rng, depth - 1, serial + index * 37 + 11),
				Vector2i(rng.randi_range(-20, 20), rng.randi_range(-20, 20)),
			]
		elif choice == 3:
			result[key] = rng.randi_range(-1_000_000, 1_000_000)
		else:
			result[key] = _random_string_key(rng, serial + index * 41 + 13)
	return result


func _random_string_key(rng: RandomNumberGenerator, serial: int) -> String:
	var prefix: Array[String] = ["alpha", "Z", "ä", "Ω", "水", "\t", "\n", "control" + String.chr(1)]
	return "%s:%d:%d" % [prefix[rng.randi_range(0, prefix.size() - 1)], serial, rng.randi_range(0, 9999)]


func _random_mixed_key(rng: RandomNumberGenerator, serial: int) -> Variant:
	match posmod(serial, 4):
		0:
			return _random_string_key(rng, serial)
		1:
			return serial - 2_000
		2:
			return Vector2i(serial % 23 - 11, serial % 29 - 14)
		_:
			return StringName("name:%d" % serial)


func _wire(catalog: AbilityCatalog, element: String, family: String) -> int:
	return int(catalog.ability(catalog.spell_id_at(element, family)).get("wire_id", 0))


func _bind_paid(authority: HexChemistryWorld, owner: int, source: int, wire: int, position: Vector2i) -> bool:
	if wire <= 0 or not authority.reserve_cast(owner, wire):
		return false
	authority.commit_payment(owner)
	authority.bind_release(owner, source, position, Vector2i(1000, 0), owner)
	return authority.sources.has(source)
