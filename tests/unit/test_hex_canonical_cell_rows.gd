extends FluxTestSuite

const World = preload("res://src/sim/hex/hex_chemistry_world.gd")
const Stream = preload("res://src/sim/hex/hex_canonical_state.gd")
const Oracle = preload("res://tests/support/hex_canonical_pre_e9.gd")
const IDS: Array[int] = [-2_147_483_648, -101, -11, -2, -1, 0, 1, 2, 10, 11, 100, 2_147_483_647]

class ByteOverride:
	extends HexChemistryWorld
	func _state_hash_bytes() -> PackedByteArray:
		return "extension remains authoritative: 水".to_utf8_buffer()

class ReentrantKey:
	extends RefCounted
	var nested_world: HexChemistryWorld
	var calls := 0
	func _to_string() -> String:
		calls += 1
		nested_world.state_hash()
		return "reentrant-row-test"


func run() -> int:
	_test_integer_order_and_insertion()
	_test_escaped_names_and_quote_bound()
	_test_live_aliases_and_zero_coverage()
	_test_unsupported_and_subclass_fallback()
	_test_reentrant_suffix()
	return finish("hex-canonical-cell-rows")


func _world() -> HexChemistryWorld:
	var world := World.new()
	check(world.configure_geometry(Vector2i(640_000, 480_000), HexGrid.disk(Vector2i.ZERO, 2)), "cell-row fixture admits immutable geometry")
	world.chemistry_enabled = true
	return world


func _assert_exact(world: HexChemistryWorld, label: String, admitted: bool = true) -> void:
	var topology := world.immutable_topology()
	var before: PackedByteArray = _authority_bytes(world)
	var original: PackedByteArray = Oracle.state_bytes(world)
	var candidate: PackedByteArray = Stream.canonical_bytes(world)
	if admitted:
		check(candidate == original, label + " exact independently frozen full canonical bytes")
		check(candidate.size() >= 8, label + " includes byte-length framing")
		if candidate.size() >= 8: equal(candidate.decode_s64(0), candidate.size() - 8, label + " UTF-8 byte length")
		equal(Stream.state_hash(world), Oracle.hash_bytes(original), label + " streaming SHA256")
	else:
		check(candidate.is_empty() and Stream.state_hash(world).is_empty(), label + " declines specialized writer")
	equal(world.state_hash(), Oracle.hash_bytes(original), label + " public canonical hash")
	check(world._state_hash_bytes() == original, label + " unchanged compatibility serializer")
	check(_authority_bytes(world) == before and world.immutable_topology() == topology, label + " source and topology ownership unchanged")


func _authority_bytes(world: HexChemistryWorld) -> PackedByteArray:
	var rows := {}
	for cell: Vector2i in world.cell_keys(): rows[cell] = world.cell_record(cell).duplicate(true)
	return var_to_bytes([rows, world.origin, world.current_tick, world.next_cast_id, world.next_product_id,
		world.next_ground_part_id, world.value_revision, world.render_revision, world.chemistry_enabled])


func _test_integer_order_and_insertion() -> void:
	for shift: int in IDS.size():
		var world := _world()
		var cells: Array = world.cell_keys().duplicate()
		if shift % 2 == 1: cells.reverse()
		for cell: Vector2i in cells:
			for index: int in IDS.size():
				var owner: int = IDS[(index + shift) % IDS.size()]
				world.set_cell_amount(cell, "water", owner, IDS[(index * 5 + shift) % IDS.size()])
			world.set_cell_amount(cell, "fire", 19, -2_147_483_648)
			world.set_cell_amount(cell, "steam", -19, 2_147_483_647)
		_assert_exact(world, "permuted signed owner rows " + str(shift))
	# Equal logical values with opposite insertion order must remain identical.
	var left := _world()
	var right := _world()
	for index: int in IDS.size():
		left.set_cell_amount(Vector2i.ZERO, "water", IDS[index], IDS[index])
		right.set_cell_amount(Vector2i.ZERO, "water", IDS[IDS.size() - index - 1], IDS[IDS.size() - index - 1])
	equal(left.state_hash(), right.state_hash(), "decimal-lexicographic owner ordering is insertion-independent")


func _test_escaped_names_and_quote_bound() -> void:
	var world := _world()
	var names: Array[String] = ["", "quote\"", "slash\\", "line\n\t\r", String.chr(1), "水🙂ß", "A", "a", "__hex_canonical_cells__", "[/]"]
	for index: int in 80: names.append("extra_" + str(index) + "_水")
	for index: int in names.size():
		world.set_cell_amount(Vector2i.ZERO, names[index], IDS[index % IDS.size()], index - 40)
		world.set_cell_amount(Vector2i(1, 0), names[index], index, 0)
	_assert_exact(world, "more than 64 arbitrary escaped layer names")
	var quoted_names := {}
	for index: int in names.size():
		var compact := {names[index]: {IDS[index % IDS.size()]: index - 40}, "terrain": 0, "structure": 0, "elevation": 0}
		var cell := Vector2i(index - 45, 45 - index)
		var expected := JSON.stringify([Oracle._stable(cell), Oracle._stable(compact)]).to_utf8_buffer()
		check(Stream._cell_row_bytes(cell, compact, quoted_names) == expected, "direct escaped row matches independent stable conversion " + str(index))
		check(quoted_names.size() <= 64, "quote memo remains bounded within call")
	equal(quoted_names.size(), 64, "quote memo stops retaining names at exact cap")
	var returned := Stream.canonical_bytes(world)
	check(not returned.is_empty(), "diagnostic byte assembly succeeds before alias mutation")
	if not returned.is_empty(): returned[returned.size() - 1] ^= 1
	_assert_exact(world, "returned-byte mutation cannot reach template or next quote memo")


func _test_live_aliases_and_zero_coverage() -> void:
	var world := _world()
	var empty_hash := world.state_hash()
	world.set_cell_amount(Vector2i.ZERO, "water", 17, 0)
	_assert_exact(world, "zero owner remains present")
	check(world.state_hash() != empty_hash, "zero-quantity coverage changes authority")
	var layer: Dictionary = world.cell_record(Vector2i.ZERO).water
	var revision: int = world.value_revision
	for quantity: int in IDS:
		layer[17] = quantity
		layer[-10] = 0
		_assert_exact(world, "retained nested alias quantity " + str(quantity))
		equal(world.value_revision, revision, "fresh hashing does not depend on revision invalidation")
	layer.clear()
	_assert_exact(world, "empty nested layer is omitted")
	equal(world.state_hash(), empty_hash, "cleared sparse row recovers exact empty hash")
	layer[0] = 0
	_assert_exact(world, "same alias repopulation is freshly hashed")


func _test_unsupported_and_subclass_fallback() -> void:
	var world := _world()
	world.set_cell_amount(Vector2i.ZERO, "water", 17, 1)
	var layer: Dictionary = world.cell_record(Vector2i.ZERO).water
	for value: Variant in [2_147_483_648, -2_147_483_649, 2.5, null, true, "水", [1, 2], {"deep": 0}]:
		layer[17] = value
		_assert_exact(world, "unsupported mutable quantity " + str(value), false)
	layer[17] = 1
	layer["17"] = 0
	_assert_exact(world, "String owner cannot enter int32 writer", false)
	layer.erase("17")
	layer[2_147_483_648] = 0
	_assert_exact(world, "wide owner cannot enter int32 writer", false)
	layer.erase(2_147_483_648)
	_assert_exact(world, "corrected retained alias re-enters exact writer")
	world.cells[Vector2i.ZERO].terrain = -2_147_483_649
	_assert_exact(world, "public metadata edit retains generic compatibility fallback", false)
	var extension := ByteOverride.new()
	check(extension.configure_geometry(Vector2i.ZERO, HexGrid.disk(Vector2i.ZERO, 1)), "extension geometry configures")
	check(Stream.canonical_bytes(extension).is_empty(), "subclass never enters direct row writer")
	equal(extension.state_hash(), Oracle.hash_bytes(extension._state_hash_bytes()), "subclass byte override remains authoritative")


func _test_reentrant_suffix() -> void:
	var world := _world()
	world.set_cell_amount(Vector2i.ZERO, "water", 12, 0)
	world.set_cell_amount(Vector2i(1, -1), "fire", -101, 23)
	var nested := World.new()
	check(nested.configure_geometry(Vector2i.ZERO, HexGrid.disk(Vector2i.ZERO, 1)), "nested distinct topology configures")
	var key := ReentrantKey.new()
	key.nested_world = nested
	world.metrics[key] = "opaque suffix 水"
	var original := Oracle.state_bytes(world)
	var previous_calls: int = key.calls
	check(Stream.canonical_bytes(world) == original, "suffix callback replacing template preserves already-written sparse rows")
	check(key.calls > previous_calls, "candidate genuinely invokes opaque suffix callback")
	equal(world.state_hash(), Oracle.hash_bytes(original), "reentrant public hash preserves independent frozen bytes")
	world.metrics.erase(key)
	key.nested_world = null
