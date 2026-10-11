extends FluxTestSuite

const World = preload("res://src/sim/hex/hex_chemistry_world.gd")
const Stream = preload("res://src/sim/hex/hex_canonical_state.gd")
const Oracle = preload("res://tests/support/hex_canonical_pre_e9.gd")
const FIELDS: Array[String] = ["casts", "products", "pending", "sources", "exposure", "flow_carry", "metrics"]

class ByteOverride:
	extends HexChemistryWorld
	func _state_hash_bytes() -> PackedByteArray:
		return "extension owns its canonical bytes: 水".to_utf8_buffer()

class SpoofedTopology:
	extends HexChemistryWorld
	var alleged: HexCellTopology
	var admission_calls := 0
	func immutable_topology() -> HexCellTopology:
		admission_calls += 1
		return alleged
	func dynamic_cell_keys() -> Array:
		return []

class ReentrantKey:
	extends RefCounted
	var nested_world: HexChemistryWorld
	var calls := 0
	func _to_string() -> String:
		calls += 1
		# The nested world has no opaque keys, so there is no recursive cycle.
		nested_world.state_hash()
		return "reentrant-key"


func run() -> int:
	_test_empty_and_sparse()
	_test_dense_override_order()
	_test_live_lanes_and_unicode()
	_test_unsupported_live_layers()
	_test_compatibility_mutations()
	_test_shared_topology_and_cache_replacement()
	_test_extension_fallback()
	_test_reentrant_key_keeps_invocation_template()
	_test_paid_product_and_zero_coverage()
	return finish("hex-canonical-topology-bytes")


func _world() -> HexChemistryWorld:
	var world := World.new()
	var cells: Array[Vector2i] = [Vector2i(10, 0), Vector2i(-2, 1), Vector2i.ZERO,
		Vector2i(2, 0), Vector2i(-10, 0), Vector2i(1, -10), Vector2i(1, -2)]
	check(world.configure_geometry(Vector2i(640_000, 480_000), cells), "streaming fixture admits immutable geometry")
	world.chemistry_enabled = true
	return world


func _assert_exact(world: HexChemistryWorld, label: String, accelerated: bool = true) -> void:
	var topology := world.immutable_topology()
	var before := _authority_bytes(world)
	var original := Oracle.state_bytes(world)
	check(world._state_hash_bytes() == original, label + " unchanged full-document path matches independent frozen bytes")
	var candidate := Stream.canonical_bytes(world)
	if accelerated:
		check(candidate == original, label + " streaming fragments assemble exact frozen canonical bytes")
		check(candidate.size() >= 8, label + " streaming bytes include their length prefix")
		if candidate.size() >= 8:
			equal(candidate.decode_s64(0), candidate.size() - 8, label + " framing uses UTF-8 bytes rather than characters")
		equal(Stream.state_hash(world), Oracle.hash_bytes(original), label + " direct stream preserves the complete SHA256")
	else:
		check(candidate.is_empty() and Stream.state_hash(world).is_empty(), label + " unsupported shape declines specialization")
	equal(world.state_hash(), Oracle.hash_bytes(original), label + " public hash equals independent original SHA256")
	check(_authority_bytes(world) == before, label + " reads preserve every public authority lane")
	check(world.immutable_topology() == topology, label + " reads preserve storage ownership")


func _authority_bytes(world: HexChemistryWorld) -> PackedByteArray:
	var records: Dictionary = {}
	for cell: Vector2i in world.cell_keys(): records[cell] = world.cell_record(cell).duplicate(true)
	var value: Array = [world.origin, world.current_tick, world.chemistry_enabled,
		world.next_cast_id, world.next_product_id, world.next_ground_part_id,
		world.render_revision, world.value_revision, records]
	for field: String in FIELDS: value.append(world.get(field).duplicate(true))
	return var_to_bytes(value)


func _test_empty_and_sparse() -> void:
	var world := _world()
	_assert_exact(world, "cold empty geometry with lexical-looking coordinates")
	_assert_exact(world, "warm empty geometry")
	var empty_hash := world.state_hash()
	world.set_cell_amount(Vector2i.ZERO, "water", 700_001, 0)
	_assert_exact(world, "explicit zero-quantity material owner")
	check(world.state_hash() != empty_hash, "zero quantity coverage cannot disappear from canonical hash")
	var layer: Dictionary = world.cell_record(Vector2i.ZERO).water
	layer[700_001] = 17
	_assert_exact(world, "direct public material alias changes without revision")
	layer[700_002] = 0
	layer[-20] = 13
	world.set_cell_amount(Vector2i(-10, 0), "fire", 42, 31)
	world.set_cell_amount(Vector2i(10, 0), "steam", 9, 0)
	_assert_exact(world, "multiple replacement spans and reverse layer owners")
	layer.clear()
	_assert_exact(world, "empty live alias is projected away while sparse row remains")
	world.erase_cell_amount(Vector2i.ZERO, "water", 700_001)
	world.erase_cell_amount(Vector2i(-10, 0), "fire", 42)
	world.erase_cell_amount(Vector2i(10, 0), "steam", 9)
	_assert_exact(world, "all sparse ownership removed")
	equal(world.state_hash(), empty_hash, "dynamic clearing restores exact blank-map hash")
	var exposed := Stream.canonical_bytes(world)
	exposed[exposed.size() - 1] ^= 1
	equal(world.state_hash(), empty_hash, "diagnostic returned bytes cannot mutate shared immutable template")
	var unconfigured := World.new()
	_assert_exact(unconfigured, "unconfigured legacy world", false)


func _test_live_lanes_and_unicode() -> void:
	var world := _world()
	for index: int in FIELDS.size():
		var field: String = FIELDS[index]
		var lane: Dictionary = world.get(field)
		var before := world.state_hash()
		lane["opaque"] = {"array": [Vector2i(-23, 7), "水🙂ß\n\t" + String.chr(1),
			"__hex_canonical_cells__", null, true, 2.5], "index": index}
		_assert_exact(world, "fresh opaque Unicode mutation in " + field)
		check(world.state_hash() != before, field + " never reuses a dynamic lane hash")
		lane.opaque.array.append({4: "integer", "4": "string", StringName("name"): false})
		_assert_exact(world, "same-reference deep mutation in " + field)
	world.current_tick = 99
	world.next_cast_id = 100
	world.next_product_id = 101
	world.next_ground_part_id = 102
	world.chemistry_enabled = false
	_assert_exact(world, "all scalar lanes stay live with multibyte suffix")


func _test_dense_override_order() -> void:
	var world := _world()
	var keys: Array = world.cell_keys().duplicate()
	keys.reverse()
	for cell: Vector2i in keys:
		world.set_cell_amount(cell, "water", 2_147_483_647, 2_147_483_647)
		world.set_cell_amount(cell, "fire", -2_147_483_648, -2_147_483_648)
		world.set_cell_amount(cell, "steam", 0, 0)
	_assert_exact(world, "all row spans replaced in reverse insertion order with int32 boundaries")
	var dense_hash := world.state_hash()
	var other := _world()
	keys.reverse()
	for cell: Vector2i in keys:
		other.set_cell_amount(cell, "steam", 0, 0)
		other.set_cell_amount(cell, "fire", -2_147_483_648, -2_147_483_648)
		other.set_cell_amount(cell, "water", 2_147_483_647, 2_147_483_647)
	_assert_exact(other, "all row spans replaced in forward insertion order")
	equal(other.state_hash(), dense_hash, "fresh map identity and dynamic insertion order preserve identical canonical authority")


func _test_unsupported_live_layers() -> void:
	var world := _world()
	world.set_cell_amount(Vector2i.ZERO, "water", 17, 1)
	var layer: Dictionary = world.cell_record(Vector2i.ZERO).water
	for value: Variant in [2_147_483_648, -2_147_483_649, 2.5, null, true, "水", {"nested": [1, 2]}]:
		layer[17] = value
		_assert_exact(world, "unsupported externally mutable quantity " + str(value), false)
	layer[17] = 1
	layer["17"] = 0
	_assert_exact(world, "mixed integer/string owner keys", false)
	layer.erase("17")
	layer[2_147_483_648] = 0
	_assert_exact(world, "wide integer owner key", false)
	layer.erase(2_147_483_648)
	_assert_exact(world, "corrected same-reference layer re-enters specialization")


func _test_compatibility_mutations() -> void:
	for mutation: String in ["origin", "metadata", "membership", "extra", "malformed"]:
		var world := _world()
		var original_hash := world.state_hash()
		if mutation == "origin":
			world.origin += Vector2i(1, -1)
		else:
			var cells: Dictionary = world.cells
			if mutation == "metadata": cells[Vector2i.ZERO].terrain = 2_147_483_649
			elif mutation == "membership":
				cells[Vector2i(3, 0)] = cells[Vector2i(2, 0)]
				cells.erase(Vector2i(2, 0))
			elif mutation == "extra": cells[Vector2i.ZERO].opaque = {"水": [false, null, {"n": 8}]}
			else: cells[Vector2i.ZERO].elevation = [3, null, {2: false}]
		check(world.immutable_topology() == null, mutation + " leaves sealed ownership at the existing public boundary")
		_assert_exact(world, mutation + " compatibility mutation", false)
		check(world.state_hash() != original_hash, mutation + " cannot retain stale topology-derived hash")
		if mutation == "metadata":
			world.cells[Vector2i.ZERO].terrain = -1
			_assert_exact(world, "second metadata edit through retained compatibility dictionary", false)


func _test_shared_topology_and_cache_replacement() -> void:
	var source := _world()
	source.set_cell_amount(Vector2i.ZERO, "water", 12, 7)
	var source_hash := source.state_hash()
	var sibling := World.new()
	source.clone_cell_storage_to(sibling)
	sibling.chemistry_enabled = source.chemistry_enabled
	check(source.immutable_topology() == sibling.immutable_topology(), "siblings share only the admitted topology")
	_assert_exact(sibling, "fresh sibling reuses bounded immutable template")
	equal(sibling.state_hash(), source_hash, "same initial sibling authority hashes identically")
	var layer: Dictionary = sibling.cell_record(Vector2i.ZERO).water
	layer[12] = 8
	_assert_exact(sibling, "sibling mutable material alias")
	equal(source.state_hash(), source_hash, "sibling mutation never shares dynamic values with source")
	var other := World.new()
	check(other.configure_geometry(Vector2i.ZERO, HexGrid.disk(Vector2i.ZERO, 3)), "different map admits its own immutable template")
	_assert_exact(other, "different template replaces the bounded shared entry")
	_assert_exact(source, "original topology rebuilds safely after cache replacement")
	_assert_exact(sibling, "same shared topology with independent dynamic state remains exact")
	check(source.configure_geometry(Vector2i(800_000, 600_000), HexGrid.disk(Vector2i.ZERO, 2)), "reconfiguration replaces unpaid geometry without reusing prior identity")
	_assert_exact(source, "same world with newly configured immutable topology")
	var boundary := World.new()
	var full_disk: Array[Vector2i] = HexGrid.disk(Vector2i.ZERO, 148)
	var selected: Array[Vector2i] = []
	for index: int in World.MAX_CELLS: selected.append(full_disk[index])
	check(boundary.configure_geometry(Vector2i.ZERO, selected), "full configured cell bound admits")
	_assert_exact(boundary, "maximum admitted topology retains every dry cell")


func _test_extension_fallback() -> void:
	check(Stream.state_hash(null).is_empty(), "null helper input declines without virtual access")
	check(Stream.state_hash(RefCounted.new()).is_empty(), "scriptless helper input declines without virtual access")
	var extension := ByteOverride.new()
	check(extension.configure_geometry(Vector2i.ZERO, HexGrid.disk(Vector2i.ZERO, 1)), "extension fixture has inherited geometry")
	check(Stream.state_hash(extension).is_empty(), "extension with inherited storage never receives concrete optimization")
	equal(extension.state_hash(), Oracle.hash_bytes(extension._state_hash_bytes()), "extension override retains exact published fallback dispatch")
	var concrete := _world()
	var spoof := SpoofedTopology.new()
	spoof.alleged = concrete.immutable_topology()
	spoof.cells = spoof.alleged.metadata().duplicate(true)
	spoof.cells[Vector2i.ZERO].terrain = 2.5
	check(Stream.canonical_bytes(spoof).is_empty(), "borrowed concrete handle cannot admit a subclass")
	equal(spoof.admission_calls, 0, "actual script gate runs before spoofable topology helper")
	equal(spoof.state_hash(), Oracle.hash_bytes(spoof._state_hash_bytes()), "subclass fallback retains all malformed mutable metadata")


func _test_paid_product_and_zero_coverage() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "paid streaming fixture loads production abilities")
	if not catalog.last_error.is_empty(): return
	var sim := SimWorld.new()
	check(HexCourtPractice.configure(sim, catalog, true), "paid streaming fixture configures ordinary court")
	if not sim.hex_court is HexChemistryWorld: return
	# The diagnostic court is deliberately a HexChemistryWorld subclass. Keep
	# its fallback coverage, then admit the exact same unpaid geometry through
	# the concrete production authority before making ordinary paid actions.
	_assert_exact(sim.hex_court, "compatibility court preserves subclass fallback", false)
	var selected: Array[Vector2i] = []
	for cell: Vector2i in sim.hex_court.cell_keys(): selected.append(cell)
	var world := World.new()
	check(world.configure_geometry(sim.hex_court.origin, selected), "same diagnostic geometry admits concrete sealed authority")
	world.chemistry_enabled = sim.hex_court.chemistry_enabled
	world.collision = sim.collision
	sim.hex_court = world
	check(world.immutable_topology() != null, "paid streaming actions start with concrete admitted topology")
	var water: int = int(catalog.ability(catalog.spell_id_at("water", "bolt")).get("wire_id", 0))
	var fire: int = int(catalog.ability(catalog.spell_id_at("fire", "bolt")).get("wire_id", 0))
	for pair: Vector2i in [Vector2i(water, 81_001), Vector2i(fire, 81_002)]:
		check(world.reserve_cast(1, pair.x), "ordinary paid source reserves")
		world.commit_payment(1)
		world.bind_release(1, pair.y, world.origin, Vector2i(1000, 0), 1)
		check(world.sources.has(pair.y), "ordinary paid source binds")
	if not world.sources.has(81_001) or not world.sources.has(81_002): return
	_assert_exact(world, "two real paid sources before contact")
	var contact: Dictionary = world.resolve_contact(81_001, 81_002, world.origin, 0)
	check(bool(contact.get("accepted", false)) and not world.products.is_empty(), "real paid contact creates a product")
	check(world.conservation_valid(), "paid product fixture preserves conservation")
	_assert_exact(world, "real paid cast and reaction product authority")
	var before := world.state_hash()
	world.set_cell_amount(Vector2i.ZERO, "water", 900_001, 0)
	_assert_exact(world, "paid authority plus explicit orphan zero coverage is still fully hashed")
	check(world.state_hash() != before and not world.conservation_valid(), "hash includes invalid zero owner even when conservation later refuses it")


func _test_reentrant_key_keeps_invocation_template() -> void:
	var world := _world()
	var nested := World.new()
	check(nested.configure_geometry(Vector2i.ZERO, HexGrid.disk(Vector2i.ZERO, 1)), "reentrant key has a distinct admitted geometry")
	var key := ReentrantKey.new()
	key.nested_world = nested
	world.metrics[key] = "opaque dynamic value"
	var original := Oracle.state_bytes(world)
	check(key.calls > 0, "independent legacy comparator executes the reentrant key callback")
	var calls_before := key.calls
	check(Stream.canonical_bytes(world) == original, "empty-row stream retains its own topology across reentrant cache replacement")
	equal(world.state_hash(), Oracle.hash_bytes(original), "empty-row public hash retains original bytes under reentrant callbacks")
	check(key.calls > calls_before, "candidate actually executes the reentrant key callback")
	world.set_cell_amount(Vector2i(-10, 0), "water", 77, 0)
	world.set_cell_amount(Vector2i(10, 0), "fire", 78, 19)
	original = Oracle.state_bytes(world)
	check(Stream.canonical_bytes(world) == original, "sparse override spans retain admitted topology across reentrant cache replacement")
	equal(world.state_hash(), Oracle.hash_bytes(original), "sparse public hash matches independent legacy bytes under callbacks")
	check(world.immutable_topology() != nested.immutable_topology(), "reentrant fixture never substitutes shared topology identity")
