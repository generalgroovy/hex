extends FluxTestSuite


const World = preload("res://src/sim/hex/hex_chemistry_world.gd")
const Snapshot = preload("res://src/net/hex_world_snapshot.gd")
const CanonicalBytes = preload("res://src/sim/core/canonical_bytes.gd")
const ABILITY_PATH := "res://content/abilities/foundation_abilities_v1.json"


func run() -> int:
	_test_configured_cell_shape_and_ownership()
	_test_prepare_revision_compatibility()
	return finish("hex-snapshot-optimization")


func _test_configured_cell_shape_and_ownership() -> void:
	var topology: Array[Vector2i] = [Vector2i(-1, 0), Vector2i.ZERO, Vector2i(1, 0)]
	var first := World.new()
	check(first.configure_geometry(Vector2i(120_000, 90_000), topology), "optimized geometry configures the requested trusted topology")
	if first.cells.size() != topology.size():
		return

	var expected_keys: Array = ["terrain", "elevation", "structure"]
	expected_keys.append_array(World.material_layers())
	expected_keys.sort()
	for cell: Vector2i in topology:
		var actual_keys: Array = first.cells[cell].keys()
		actual_keys.sort()
		equal(actual_keys, expected_keys, "configured cell retains the exact metadata and 44 material-layer shape")

	var ingredient_layer: String = World.material_layers()[0]
	var product_layer: String = World.material_layers()[-1]
	var empty_hash: String = first.state_hash()
	first.cells[topology[0]][ingredient_layer][91_001] = 7
	first.cells[topology[1]][product_layer][92_001] = 3
	check(first.state_hash() != empty_hash, "native empty-cell fast path still detects direct orphan material mutations")
	equal(first.cells[topology[0]][ingredient_layer], {91_001: 7}, "first cell owns its nested ingredient dictionary")
	equal(first.cells[topology[1]][ingredient_layer], {}, "sibling cell does not alias the first ingredient dictionary")
	equal(first.cells[topology[0]][product_layer], {}, "first cell does not alias the sibling product dictionary")
	equal(first.cells[topology[1]][product_layer], {92_001: 3}, "sibling cell owns its nested product dictionary")
	equal(first.cells[topology[2]][ingredient_layer], {}, "third cell remains isolated from sibling mutations")
	equal(first.cells[topology[2]][product_layer], {}, "third cell retains an independent empty product dictionary")

	var second := World.new()
	check(second.configure_geometry(Vector2i(120_000, 90_000), topology), "second world configures independently from the first")
	if second.cells.size() != topology.size():
		return
	equal(second.cells[topology[0]][ingredient_layer], {}, "new world does not inherit the first world's ingredient mutation")
	equal(second.cells[topology[1]][product_layer], {}, "new world does not inherit the first world's product mutation")
	equal(second.state_hash(), empty_hash, "independent empty world retains the exact canonical authority hash")
	second.cells[topology[0]][ingredient_layer][93_001] = 5
	equal(first.cells[topology[0]][ingredient_layer], {91_001: 7}, "later world mutation cannot alter the first world's nested authority")


	var malformed := World.new()
	check(malformed.configure_geometry(Vector2i(120_000, 90_000), topology), "legacy hash oracle configures independently")
	if malformed.cells.size() != topology.size():
		return
	malformed.cells[topology[0]]["terrain"] = {}
	_assert_legacy_hash(malformed, "empty Dictionary metadata retains the published sparse hash bytes")
	malformed.cells[topology[1]].erase(product_layer)
	_assert_legacy_hash(malformed, "missing authored material key retains the published sparse hash bytes")
	malformed.cells[topology[2]][ingredient_layer][94_001] = 9
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
	for step: int in range(560):
		var slot := 0 if step in [0, 160, 260] else 1 if step in [100, 190] else -1
		var pressed := int(SimCommand.SPELL_PRESSED_BITS[slot]) if slot >= 0 else 0
		var command := SimCommand.new(step, 1, 0, 0, 0, pressed, 0, -1000, 640_000, 480_000)
		if not world.step([command]):
			check(false, "paid strict snapshot fixture advances at tick %d" % step)
			return {}
		if world.player(1).pending_cast_wire_id > 0 and not world.projectiles.is_empty() and not world.hex_court.products.is_empty():
			return Snapshot.capture(world)
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
