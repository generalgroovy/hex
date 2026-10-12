extends FluxTestSuite


const World = preload("res://src/sim/hex/hex_chemistry_world.gd")
const Snapshot = preload("res://src/net/hex_world_snapshot.gd")
const ChemistrySnapshot = preload("res://src/net/hex_chemistry_snapshot.gd")
const LegacyTrustedCells = preload("res://tests/support/hex_trusted_cells_legacy_oracle.gd")
const CanonicalBytes = preload("res://src/sim/core/canonical_bytes.gd")
const FrozenCapture = preload("res://tests/support/expanded_world_snapshot_reference.gd")
const ABILITY_PATH := "res://content/abilities/foundation_abilities_v1.json"


class CaptureRetentionActor:
	extends PlayerState
	var canonical_calls := 0
	func canonical_values() -> PackedInt64Array:
		canonical_calls += 1
		return super.canonical_values()


func run() -> int:
	_test_trusted_cells_valid_and_canonical_equivalence()
	_test_trusted_cells_malformed_equivalence()
	_test_trusted_cells_bounds_and_mutation_visibility()
	_test_configured_cell_shape_and_ownership()
	_test_prepare_revision_compatibility()
	_test_canonical_row_cache_mutations()
	_test_geometry_template_isolation()
	_test_capture_player_retention()
	return finish("hex-snapshot-optimization")


func _test_capture_player_retention() -> void:
	var source := _capture_retention_fixture()
	if source == null: return
	_capture_retention_pair(source, true, "one concrete champion")
	for entity_id: int in range(2, Snapshot.MAX_ACTORS + 1):
		var actor := PlayerState.new(entity_id)
		actor.team_id = entity_id
		if entity_id > Snapshot.MAX_PLAYERS:
			actor.actor_kind = PlayerState.ActorKind.TRAINING_TARGET
			actor.movement_speed_ratio = 0
		source.players.append(actor)
	source.players.reverse()
	var original_order := source.players.duplicate()
	var accepted := _capture_retention_pair(source, true, "reversed eight champions and four targets")
	equal(source.players, original_order, "retention never sorts or replaces live actors")
	if accepted.is_empty(): return
	var actor := source.player(1)
	actor.health -= 1
	actor.primary_cooldown_ticks = 7
	actor.spell_cooldown_ticks[0] = 19
	var changed := _capture_retention_pair(source, true, "same actor has new health and distinct cooldown lanes")
	check(var_to_bytes(changed) != var_to_bytes(accepted), "next capture reads changed actor instead of retained prior admission")
	var left := Snapshot.prepare(changed, source)
	var right := Snapshot.prepare(changed, source)
	check(left != null and right != null, "retained capture independently prepares two strict receivers")
	if left != null and right != null:
		check(left.player(1) != actor and left.player(1) != right.player(1), "retained admission never exports a source or sibling actor alias")
		var expected_values := actor.canonical_values()
		left.player(1).health -= 1
		left.player(1).spell_wire_ids[0] = 0
		left.player(1).spell_cooldown_ticks[0] += 1
		equal(actor.canonical_values(), expected_values, "restored scalar and packed spell mutations leave the source intact")
		equal(right.player(1).canonical_values(), expected_values, "restored scalar and packed spell mutations leave the sibling intact")
		equal(var_to_bytes(Snapshot.capture(source)), var_to_bytes(changed), "receiver mutation cannot contaminate a later capture")
	var saved_health := actor.health
	actor.health = -1
	_capture_retention_pair(source, false, "malformed live scalar still rejects")
	actor.health = saved_health
	var saved_position := actor.position_x
	actor.position_x = Snapshot.MAX_ID + 1
	_capture_retention_pair(source, false, "64-bit live value rejects before int32 narrowing")
	actor.position_x = saved_position
	var saved_spell := actor.spell_wire_ids[1]
	actor.spell_wire_ids[1] = actor.spell_wire_ids[0]
	_capture_retention_pair(source, false, "duplicate live spell still rejects")
	actor.spell_wire_ids[1] = saved_spell
	var target := source.player(Snapshot.MAX_ACTORS)
	target.pending_cast_wire_id = target.primary_wire_id
	_capture_retention_pair(source, false, "retained target still cannot have a pending cast")
	target.pending_cast_wire_id = 0
	target.entity_id = 1
	_capture_retention_pair(source, false, "retained actor set still rejects duplicate identities")
	target.entity_id = Snapshot.MAX_ACTORS
	target.actor_kind = PlayerState.ActorKind.CHAMPION
	target.movement_speed_ratio = 1000
	_capture_retention_pair(source, false, "retained actor set still rejects nine champions")
	target.actor_kind = PlayerState.ActorKind.TRAINING_TARGET
	target.movement_speed_ratio = 0
	source.players.append(PlayerState.new(Snapshot.MAX_ACTORS + 1))
	_capture_retention_pair(source, false, "retained actor count still rejects thirteen actors")
	source.players.pop_back()
	_capture_retention_pair(source, true, "same source recovers after every rejected actor mutation")
	for key: String in ["map_id", "map_hash", "transition_hash", "state_hash"]:
		var bad_identity := changed.duplicate(true)
		bad_identity[key] = "invalid"
		check(Snapshot._decode_outer_lanes(bad_identity, source).is_empty(), "shared outer framing retains " + key + " refusal")
		check(Snapshot.prepare(bad_identity, source) == null, "strict public prepare retains " + key + " refusal")
	for index: int in [0, 1, 3, 4, 5, 6, 7]:
		var bad_header := changed.duplicate(true)
		var header: PackedInt64Array = bad_header.header.duplicate()
		header[index] = -1
		bad_header.header = header
		check(Snapshot._decode_outer_lanes(bad_header, source).is_empty(), "shared outer framing retains header %d refusal" % index)
		check(Snapshot.prepare(bad_header, source) == null, "strict public prepare retains header %d refusal" % index)
	var bad_player := changed.duplicate(true)
	var player_rows: PackedInt32Array = bad_player.players.duplicate()
	player_rows[16] = 2
	bad_player.players = player_rows
	check(Snapshot.prepare(bad_player, source) == null and not Snapshot.validate_wire_structure(bad_player), "public mutable player bytes still receive complete strict row validation")
	var fallback_results: Array[Dictionary] = []
	var fallback_calls: Array[int] = []
	for use_frozen: bool in [true, false]:
		var fallback := _capture_retention_fixture()
		if fallback == null: return
		var extension := CaptureRetentionActor.new(1)
		fallback.players = [extension]
		check(not Snapshot._producer_reuse_eligible(fallback), "actor extension never enters capture-local retention")
		var result := FrozenCapture.capture(fallback) if use_frozen else Snapshot.capture(fallback)
		check(not result.is_empty(), "unchanged actor extension still captures through strict fallback")
		fallback_results.append(result)
		fallback_calls.append(extension.canonical_calls)
	equal(var_to_bytes(fallback_results[0]), var_to_bytes(fallback_results[1]), "fallback output bytes stay identical to schema-adapted predecessor capture")
	equal(fallback_calls[0], fallback_calls[1], "retention does not remove or add live extension canonical callbacks")
	check(fallback_calls[1] > 0, "fallback actually invoked the actor extension")


func _capture_retention_fixture() -> SimWorld:
	var source := SimWorld.new()
	var chemistry := World.new()
	if not chemistry.configure_geometry(Vector2i(160_000, 360_000), [Vector2i(-1, 0), Vector2i.ZERO, Vector2i(1, 0)]):
		check(false, "capture retention fixture configures concrete sealed geometry")
		return null
	chemistry.chemistry_enabled = true
	chemistry.collision = source.collision
	source.hex_court = chemistry
	return source


func _capture_retention_pair(source: SimWorld, accepted: bool, label: String) -> Dictionary:
	check(Snapshot._producer_reuse_eligible(source), label + " exercises the concrete retention branch")
	var expected := FrozenCapture.capture(source)
	var actual := Snapshot.capture(source)
	equal(not expected.is_empty(), accepted, label + " frozen acceptance is explicit")
	equal(not actual.is_empty(), accepted, label + " preserves acceptance or refusal")
	equal(var_to_bytes(actual), var_to_bytes(expected), label + " preserves exact canonical snapshot bytes")
	return actual


func _assert_exact_bytes(world: HexChemistryWorld, label: String) -> void:
	equal(world._state_hash_bytes(), world._generic_state_hash_bytes(), label + " exact cold/warm canonical bytes")
	_assert_legacy_hash(world, label + " independent frozen hash oracle")
	equal(world._state_hash_bytes(), world._generic_state_hash_bytes(), label + " repeated canonical bytes")


func _test_canonical_row_cache_mutations() -> void:
	var world := _trusted_fixture(Vector2i(31_000, -73_000), [Vector2i(-2, 1), Vector2i.ZERO, Vector2i(11, -3)])
	if world == null: return
	World._canonical_blank_rows.clear()
	_assert_exact_bytes(world, "empty cache")
	var saved := world.state_hash()
	var original: Dictionary = world.cells.duplicate(true)
	for index: int in 96:
		var cell: Vector2i = world.cells.keys()[index % 3]
		world.cells[cell].terrain = index - 48
		world.cells[cell].elevation = -index
		world.cells[cell].structure = index * 3
		if index % 2 == 0: world.set_cell_amount(cell, "water", 9001, index + 1)
		else: world.erase_cell_amount(cell, "water", 9001)
		world.current_tick = index
		_assert_exact_bytes(world, "direct metadata and material mutation %d" % index)
		check(World._canonical_blank_rows.size() <= World.MAX_CELLS, "canonical cache stays bounded")
	for value: Variant in [-2_147_483_648, 2_147_483_647, -2_147_483_649, 2_147_483_648, 4.5, true, "quoted\"text", {}]:
		world.cells[Vector2i.ZERO].terrain = value
		_assert_exact_bytes(world, "int32 boundary or typed fallback " + str(value))
	world.cells = original.duplicate(true)
	world.cells[Vector2i.ZERO]["unusual"] = {"nested": [Vector2i(-3, 4), "escaped\n\"value", {"deep": [1, 2]}]}
	world.metrics["opaque"] = ["__hex_canonical_cells__", {"later": [Vector2i(7, 8)]}]
	_assert_exact_bytes(world, "whole-call arbitrary nested fallback and marker collision")
	world.cells[Vector2i.ZERO].erase("unusual")
	_assert_exact_bytes(world, "return from fallback with opaque suffix at original depth")
	world.metrics.erase("opaque")
	world.current_tick = 0
	equal(world.state_hash(), saved, "direct restoration recovers original hash")
	var reordered := {}
	var keys: Array = world.cells.keys()
	keys.reverse()
	for cell: Vector2i in keys: reordered[cell] = world.cells[cell].duplicate(true)
	world.cells = reordered
	_assert_exact_bytes(world, "reverse insertion")
	equal(world.state_hash(), saved, "canonical bytes ignore insertion order")
	world.cells.erase(Vector2i(-2, 1))
	world.cells[Vector2i(-3, 2)] = World._new_empty_cell()
	_assert_exact_bytes(world, "same-size topology key replacement")
	var other := _trusted_fixture(Vector2i.ZERO, [Vector2i.ZERO])
	other.cells[Vector2i.ZERO].terrain = 311
	_assert_exact_bytes(other, "independent world shares only pure cached text")
	_assert_exact_bytes(world, "other world cannot alter original authority")
	# Exercise eviction without configuring an illegal oversized authority world.
	World._canonical_blank_rows.clear()
	for index: int in World.MAX_CELLS:
		World._canonical_blank_rows[Vector2i(index + 1000, 1000)] = [0, 0, 0, "unused"]
	_assert_exact_bytes(world, "bounded eviction")
	check(World._canonical_blank_rows.size() <= World.MAX_CELLS, "eviction retains hard cache bound")


func _test_geometry_template_isolation() -> void:
	var source := _trusted_fixture(Vector2i(40_000, -20_000), [Vector2i(-1, 0), Vector2i.ZERO, Vector2i(1, 0)])
	if source == null: return
	ChemistrySnapshot._blank_topology_bytes.clear()
	ChemistrySnapshot._blank_topology_cells.clear()
	var snapshot := ChemistrySnapshot.capture(source)
	check(not snapshot.is_empty(), "cold geometry template captures")
	var first := ChemistrySnapshot._prepare(snapshot, source)
	var second := ChemistrySnapshot._prepare(snapshot, source)
	check(first != null and second != null, "warm geometry template restores independently")
	if first == null or second == null: return
	first.cells[Vector2i.ZERO].terrain = 55
	first.set_cell_amount(Vector2i.ZERO, "water", 777, 3)
	equal(second.cells, source.cells, "mutable first restore cannot affect sibling or source")
	var third := ChemistrySnapshot._prepare(snapshot, source)
	check(third != null and third.cells == source.cells, "mutable restore cannot poison cached template")
	source.cells[Vector2i.ZERO].terrain = 55
	check(ChemistrySnapshot._prepare(snapshot, source) == null, "changed metadata invalidates old snapshot fingerprint")
	var updated := ChemistrySnapshot.capture(source)
	var updated_world := ChemistrySnapshot._prepare(updated, source)
	check(updated_world != null and updated_world.cells == source.cells, "new metadata gets a fresh validated template")
	source.cells[Vector2i.ZERO].terrain = 55.0
	check(ChemistrySnapshot.capture(source).is_empty(), "equal numeric value with wrong type is not hidden by geometry cache")
	source.cells[Vector2i.ZERO].terrain = 55
	source.origin.x += 1000
	check(ChemistrySnapshot._prepare(updated, source) == null, "origin is part of exact template identity")
	source.origin.x -= 1000
	source.cells[Vector2i.ZERO]["fire"] = 0
	check(ChemistrySnapshot._prepare(updated, source) == null, "malformed layer still rejected on cache hit")
	source.cells[Vector2i.ZERO].erase("fire")
	source.cells.erase(Vector2i(1, 0))
	source.cells[Vector2i(257, 0)] = World._new_empty_cell()
	var expanded := ChemistrySnapshot.capture(source)
	check(not expanded.is_empty(), "axial257 is deliberately legal in the expanded shared384 domain")
	check(ChemistrySnapshot._prepare(expanded, source) != null, "expanded legal geometry warms its exact validated template")
	source.cells.erase(Vector2i(257, 0))
	# Counter-offset keeps the world point inside8m; only the axial385 boundary
	# is invalid, so this cannot pass merely because world-space overflow refuses.
	var invalid_axial := Vector2i(385, -200)
	check(HexGrid._query_point_valid(source.origin + HexGrid.center(invalid_axial)), "one-past axial control isolates axial admission from world-coordinate bounds")
	source.cells[invalid_axial] = World._new_empty_cell()
	check(ChemistrySnapshot.capture(source).is_empty(), "invalid geometry never admitted by warm template")
	check(ChemistrySnapshot._prepare(expanded, source) == null, "warm snapshot template cannot conceal newly invalid axial geometry")


func _test_trusted_cells_valid_and_canonical_equivalence() -> void:
	var topology: Array[Vector2i] = [Vector2i(2, -3), Vector2i(-4, 1), Vector2i.ZERO, Vector2i(-1, -2)]
	var world := _trusted_fixture(Vector2i(-240_000, 360_000), topology)
	if world == null:
		return
	_assert_trusted_equivalent(world, topology.size(), "ordinary negative and mixed-coordinate topology")
	var expected := topology.duplicate()
	expected.sort_custom(HexGrid._cell_less)
	equal(ChemistrySnapshot._trusted_cells(world), expected, "candidate retains canonical lexicographic cell ordering")

	var reversed := {}
	for index: int in range(topology.size() - 1, -1, -1):
		var cell := topology[index]
		reversed[cell] = world.cells[cell]
	world.cells = reversed
	_assert_trusted_equivalent(world, topology.size(), "reversed insertion order")
	equal(ChemistrySnapshot._trusted_cells(world), expected, "reversed insertion produces the same canonical ordering")

	world.cells[topology[0]]["accepted_extra_scalar"] = 17
	world.cells[topology[1]]["accepted_extra_dictionary"] = {4: ["opaque", null]}
	world.set_cell_amount(topology[2], World.material_layers()[0], 91_101, 23)
	_assert_trusted_equivalent(world, topology.size(), "accepted extras and nonempty authored layer")


func _test_trusted_cells_malformed_equivalence() -> void:
	var metadata_values: Array = [1.5, "1", {}, null, true, []]
	for property_name: String in ["terrain", "elevation", "structure"]:
		var missing := _trusted_fixture(Vector2i.ZERO, [Vector2i.ZERO])
		if missing == null:
			return
		missing.cells[Vector2i.ZERO].erase(property_name)
		_assert_trusted_equivalent(missing, 0, "missing metadata " + property_name)
		for invalid: Variant in metadata_values:
			var malformed := _trusted_fixture(Vector2i.ZERO, [Vector2i.ZERO])
			if malformed == null:
				return
			malformed.cells[Vector2i.ZERO][property_name] = invalid
			_assert_trusted_equivalent(malformed, 0, "%s rejects metadata type %s" % [property_name, type_string(typeof(invalid))])

	var layer := World.material_layers()[0]
	var missing_layer := _trusted_fixture(Vector2i.ZERO, [Vector2i.ZERO])
	if missing_layer == null:
		return
	missing_layer.cells[Vector2i.ZERO].erase(layer)
	_assert_trusted_equivalent(missing_layer, 1, "unallocated material layer is intentionally empty")
	for invalid: Variant in [0, 1.5, "layer", [], null, true]:
		var malformed_layer := _trusted_fixture(Vector2i.ZERO, [Vector2i.ZERO])
		if malformed_layer == null:
			return
		malformed_layer.cells[Vector2i.ZERO][layer] = invalid
		_assert_trusted_equivalent(malformed_layer, 0, "material rejects type " + type_string(typeof(invalid)))

	var wrong_key := _trusted_fixture(Vector2i.ZERO, [Vector2i.ZERO])
	if wrong_key == null:
		return
	wrong_key.cells["0,0"] = wrong_key.cells[Vector2i.ZERO].duplicate(true)
	_assert_trusted_equivalent(wrong_key, 0, "non-Vector2i cell key")
	var wrong_record := _trusted_fixture(Vector2i.ZERO, [Vector2i.ZERO])
	if wrong_record == null:
		return
	wrong_record.cells[Vector2i.ZERO] = []
	_assert_trusted_equivalent(wrong_record, 0, "non-Dictionary cell record")
	for invalid_origin: Vector2i in [Vector2i(HexGrid.MAX_ABS_QUERY_COORDINATE + 1, 0), Vector2i(0, -HexGrid.MAX_ABS_QUERY_COORDINATE - 1)]:
		var bad_origin := _trusted_fixture(Vector2i.ZERO, [Vector2i.ZERO])
		if bad_origin == null:
			return
		bad_origin.origin = invalid_origin
		_assert_trusted_equivalent(bad_origin, 0, "out-of-range trusted origin")


func _test_trusted_cells_bounds_and_mutation_visibility() -> void:
	var exact_topology: Array[Vector2i] = []
	for q: int in 128:
		for r: int in 128:
			exact_topology.append(Vector2i(q, r))
	var exact := _trusted_fixture(Vector2i(-2_000_000, -1_000_000), exact_topology)
	if exact == null:
		return
	_assert_trusted_equivalent(exact, 16_384, "historical 16384-cell domain still matches the unchanged 4096-cell oracle")
	var large_topology: Array[Vector2i] = []
	for q: int in range(-128, 128):
		for r: int in range(-128, 128): large_topology.append(Vector2i(q, r))
	var large := _trusted_fixture(Vector2i.ZERO, large_topology)
	if large == null: return
	_assert_trusted_equivalent(large, 65_536, "exact 65536-cell boundary composed from unchanged old-domain oracle batches")

	var oversized := World.new()
	for index: int in range(ChemistrySnapshot.MAX_TOPOLOGY_CELLS + 1):
		oversized.cells[Vector2i(index - 2048, 0)] = {}
	_assert_trusted_equivalent(oversized, 0, "65537-cell topology rejects before record traversal")

	var mutation := _trusted_fixture(Vector2i.ZERO, [Vector2i(-1, 0), Vector2i.ZERO, Vector2i(1, 0)])
	if mutation == null:
		return
	var expected := ChemistrySnapshot._trusted_cells(mutation)
	_assert_trusted_equivalent(mutation, 3, "pre-mutation valid topology")
	var material := World.material_layers()[-1]
	mutation.cells[Vector2i.ZERO][material] = 7
	_assert_trusted_equivalent(mutation, 0, "direct material-shape mutation is visible on next call")
	mutation.cells[Vector2i.ZERO][material] = {}
	equal(ChemistrySnapshot._trusted_cells(mutation), expected, "restoring the material dictionary restores the exact ordered topology")
	mutation.cells[Vector2i.ZERO]["terrain"] = 3.0
	_assert_trusted_equivalent(mutation, 0, "direct metadata-type mutation is visible on next call")
	mutation.cells[Vector2i.ZERO]["terrain"] = 3
	equal(ChemistrySnapshot._trusted_cells(mutation), expected, "restoring integer metadata restores the exact ordered topology")


func _trusted_fixture(origin: Vector2i, topology: Array[Vector2i]) -> HexChemistryWorld:
	var world := World.new()
	check(world.configure_geometry(origin, topology), "trusted-cell fixture configures %d cells" % topology.size())
	return world if world.cells.size() == topology.size() else null


func _assert_trusted_equivalent(world: HexChemistryWorld, expected_size: int, label: String) -> void:
	var before_cells: Dictionary = world.cells.duplicate(true)
	var before_origin: Vector2i = world.origin
	var legacy: Array[Vector2i] = _legacy_sparse_cells(world)
	var candidate: Array[Vector2i] = ChemistrySnapshot._trusted_cells(world)
	equal(candidate, legacy, label + " matches the frozen old implementation")
	equal(candidate.size(), expected_size, label + " has the expected acceptance result")
	equal(world.cells, before_cells, label + " leaves all source cell records unchanged")
	equal(world.origin, before_origin, label + " leaves source origin unchanged")


func _test_configured_cell_shape_and_ownership() -> void:
	var topology: Array[Vector2i] = [Vector2i(-1, 0), Vector2i.ZERO, Vector2i(1, 0)]
	var first := World.new()
	check(first.configure_geometry(Vector2i(120_000, 90_000), topology), "optimized geometry configures the requested trusted topology")
	if first.cells.size() != topology.size():
		return

	var expected_keys: Array = ["terrain", "elevation", "structure"]
	expected_keys.sort()
	for cell: Vector2i in topology:
		var actual_keys: Array = first.cells[cell].keys()
		actual_keys.sort()
		equal(actual_keys, expected_keys, "configured cell contains metadata only until first material deposit")

	var ingredient_layer: String = World.material_layers()[0]
	var product_layer: String = World.material_layers()[-1]
	var empty_hash: String = first.state_hash()
	first.set_cell_amount(topology[0], ingredient_layer, 91_001, 7)
	first.set_cell_amount(topology[1], product_layer, 92_001, 3)
	check(first.state_hash() != empty_hash, "native empty-cell fast path still detects direct orphan material mutations")
	equal(first.cells[topology[0]][ingredient_layer], {91_001: 7}, "first cell owns its nested ingredient dictionary")
	equal(first.cells[topology[1]].get(ingredient_layer, {}), {}, "sibling cell does not alias the first ingredient dictionary")
	equal(first.cells[topology[0]].get(product_layer, {}), {}, "first cell does not alias the sibling product dictionary")
	equal(first.cells[topology[1]][product_layer], {92_001: 3}, "sibling cell owns its nested product dictionary")
	equal(first.cells[topology[2]].get(ingredient_layer, {}), {}, "third cell remains isolated from sibling mutations")
	equal(first.cells[topology[2]].get(product_layer, {}), {}, "third cell retains an independent empty product dictionary")

	var second := World.new()
	check(second.configure_geometry(Vector2i(120_000, 90_000), topology), "second world configures independently from the first")
	if second.cells.size() != topology.size():
		return
	equal(second.cells[topology[0]].get(ingredient_layer, {}), {}, "new world does not inherit the first world's ingredient mutation")
	equal(second.cells[topology[1]].get(product_layer, {}), {}, "new world does not inherit the first world's product mutation")
	equal(second.state_hash(), empty_hash, "independent empty world retains the exact canonical authority hash")
	second.set_cell_amount(topology[0], ingredient_layer, 93_001, 5)
	equal(first.cells[topology[0]][ingredient_layer], {91_001: 7}, "later world mutation cannot alter the first world's nested authority")


	var malformed := World.new()
	check(malformed.configure_geometry(Vector2i(120_000, 90_000), topology), "legacy hash oracle configures independently")
	if malformed.cells.size() != topology.size():
		return
	malformed.cells[topology[0]]["terrain"] = {}
	_assert_legacy_hash(malformed, "empty Dictionary metadata retains the published sparse hash bytes")
	malformed.cells[topology[1]].erase(product_layer)
	_assert_legacy_hash(malformed, "missing authored material key retains the published sparse hash bytes")
	malformed.set_cell_amount(topology[2], ingredient_layer, 94_001, 9)
	_assert_legacy_hash(malformed, "nonempty orphan material retains the published sparse hash bytes")
	malformed.cells[topology[2]]["unexpected_authority"] = {95_001: 4}
	_assert_legacy_hash(malformed, "nonempty unexpected key retains the published sparse hash bytes")


func _test_prepare_revision_compatibility() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(ABILITY_PATH), "revision fixture loads the production ability catalog")
	if not catalog.last_error.is_empty():
		return
	var source := SimWorld.new()
	check(HexCourtPractice.configure(source, catalog, false), "revision fixture configures trusted production topology")
	equal(ChemistrySnapshot._trusted_cells(source.hex_court), _legacy_sparse_cells(source.hex_court), "production topology matches frozen validation before capture")
	var verified_hex_hash: String = String(source.hex_court.state_hash())
	equal(source._state_hash_with_verified_hex_hash(verified_hex_hash), source.state_hash(), "verified chemistry hash helper preserves exact outer canonical bytes")
	var snapshot: Dictionary = _rich_snapshot(source)
	check(not snapshot.is_empty(), "revision fixture captures complete paid authority with a live projectile")
	if snapshot.is_empty():
		return
	var prepared: SimWorld = Snapshot.prepare(snapshot, source)
	check(prepared != null, "revision fixture prepares fresh decoded authority")
	if prepared == null:
		return
	equal(ChemistrySnapshot._trusted_cells(prepared.hex_court), _legacy_sparse_cells(prepared.hex_court), "round-tripped topology matches frozen validation")
	equal(prepared.hex_court.value_revision, 1, "direct prepare preserves the former fresh blank-plus-restore invalidation revision")
	equal(prepared.state_hash(), String(snapshot.state_hash), "optimized prepare preserves the published complete-world hash")

	var stale_player: Dictionary = snapshot.duplicate(true)
	var player_values: PackedInt32Array = stale_player.players.duplicate()
	player_values[4] += 1
	stale_player.players = player_values
	check(Snapshot.validate_wire_structure(stale_player), "stale-player oracle remains a well-formed wire snapshot")
	check(Snapshot.prepare(stale_player, source) == null, "verified chemistry hash cannot hide a stale player lane")

	var stale_projectile: Dictionary = snapshot.duplicate(true)
	var projectile_values: PackedInt32Array = stale_projectile.projectiles.duplicate()
	projectile_values[5] += 1
	stale_projectile.projectiles = projectile_values
	check(Snapshot.validate_wire_structure(stale_projectile), "stale-projectile oracle remains a well-formed wire snapshot")
	check(Snapshot.prepare(stale_projectile, source) == null, "verified chemistry hash cannot hide a stale projectile lane")

	var stale_header: Dictionary = snapshot.duplicate(true)
	var header: PackedInt64Array = stale_header.header.duplicate()
	header[2] += 1
	stale_header.header = header
	check(Snapshot.validate_wire_structure(stale_header), "stale-header oracle remains a well-formed wire snapshot")
	check(Snapshot.prepare(stale_header, source) == null, "verified chemistry hash cannot hide a stale outer header")


func _rich_snapshot(world: SimWorld) -> Dictionary:
	var followup_requested := false
	for step: int in range(560):
		var slot := 0 if step in [0, 160, 260] else 1 if step == 100 else -1
		var actor := world.player(1)
		# Keep the same paid route and bounded cast count, but follow the actual
		# remaining flight/recovery rather than the predecessor's tick 190 delay.
		if step > 160 and slot < 0 and not followup_requested and not world.projectiles.is_empty() and not world.hex_court.products.is_empty() and actor.pending_cast_wire_id == 0 and actor.cast_recovery_ticks == 0 and actor.spell_cooldown_for_wire(actor.spell_wire_id(2)) == 0:
			slot = 1
			followup_requested = true
		var pressed := int(SimCommand.SPELL_PRESSED_BITS[slot]) if slot >= 0 else 0
		var command := SimCommand.new(world.tick, 1, 0, 0, 0, pressed, 0, -1000, 640_000, 480_000)
		if not world.step([command]):
			check(false, "paid strict snapshot fixture advances at tick %d" % step)
			return {}
		if world.player(1).pending_cast_wire_id > 0 and not world.projectiles.is_empty() and not world.hex_court.products.is_empty():
			var snapshot := Snapshot.capture(world)
			if not snapshot.is_empty():
				print("PAID STRICT CAPTURE: tick=%d pending=%d flights=%d products=%d matter_paid=%d" % [world.tick, actor.pending_cast_wire_id, world.projectiles.size(), world.hex_court.products.size(), int(world.hex_court.metrics.matter_paid)])
			return snapshot
	return {}


func _assert_legacy_hash(world: World, label: String) -> void:
	equal(world.state_hash(), _legacy_sparse_hash(world), label)


func _legacy_sparse_hash(world: World) -> String:
	var compact_cells := {}
	for cell: Vector2i in world.cells:
		var compact := {}
		for key: String in world.cells[cell]:
			var value: Variant = world.cells[cell][key]
			if not value is Dictionary or not value.is_empty():
				compact[key] = value
		compact_cells[cell] = compact
	var authority := [
		world.origin, world.current_tick, world.chemistry_enabled,
		world.next_cast_id, world.next_product_id, world.next_ground_part_id,
		compact_cells, world.casts, world.products, world.pending, world.sources,
		world.exposure, world.flow_carry, world.metrics,
	]
	var bytes := PackedByteArray()
	CanonicalBytes.append_string(bytes, JSON.stringify(_original_stable(authority)))
	return CanonicalBytes.sha256_hex(bytes)


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

# Adapt representation only: the frozen validator remains unchanged. Each old
# 4096-cell batch gets the empty slots it formerly required; merged results are
# compared against the new bounded topology without copying its validation.
func _legacy_sparse_cells(world: HexChemistryWorld) -> Array[Vector2i]:
	if world.cells.is_empty() or world.cells.size() > 65_536: return []
	var expanded := World.new()
	expanded.origin = world.origin
	var result: Array[Vector2i] = []
	for cell: Variant in world.cells:
		var value: Variant = world.cells[cell]
		if value is Dictionary:
			value = value.duplicate(true)
			for layer: String in World.material_layers():
				if not value.has(layer): value[layer] = {}
		expanded.cells[cell] = value
		if expanded.cells.size() == 4096:
			var batch := LegacyTrustedCells.trusted_cells(expanded)
			if batch.size() != expanded.cells.size(): return []
			result.append_array(batch)
			expanded.cells.clear()
	if not expanded.cells.is_empty():
		var batch := LegacyTrustedCells.trusted_cells(expanded)
		if batch.size() != expanded.cells.size(): return []
		result.append_array(batch)
	result.sort_custom(func(a: Vector2i,b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	return result
