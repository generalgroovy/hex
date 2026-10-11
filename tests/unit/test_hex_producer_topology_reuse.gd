extends "res://tests/unit/test_hex_world_snapshot.gd"

const Legacy = preload("res://tests/support/hex_producer_topology_legacy_oracle.gd")

class AlternatePlayer:
	extends PlayerState

class ReentrantConfig:
	extends SimConfig
	var court: HexChemistryWorld
	var cell := Vector2i.ZERO
	var checks := 0
	func is_valid() -> bool:
		checks += 1
		if checks == 2 and court != null: court.cells[cell].terrain += 1
		return super.is_valid()


func run() -> int:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(ABILITY_PATH), "producer bridge uses unchanged abilities")
	if not catalog.last_error.is_empty(): return finish("hex-producer-topology-reuse")
	var world := _concrete_fixture(catalog)
	if world == null: return finish("hex-producer-topology-reuse")
	_test_exact_capture_and_detachment(world)
	_test_mutation_visibility(world)
	_test_public_refusals(world)
	_test_one_shot_operation(world)
	_test_subclass_fallback(world)
	_test_reentrant_config_fallback(world)
	return finish("hex-producer-topology-reuse")


func _concrete_fixture(catalog: AbilityCatalog) -> SimWorld:
	var original := SimWorld.new()
	check(HexCourtPractice.configure(original, catalog, false), "producer fixture configures ordinary paid practice")
	var snapshot := _advance_to_rich_capture(original)
	check(not snapshot.is_empty(), "producer fixture reaches paid flights/products/pending state")
	if snapshot.is_empty(): return null
	var world := Legacy.prepare(snapshot, original)
	check(world != null and world.state_hash() == original.state_hash(), "frozen restore yields concrete production classes with identical authority")
	if world != null: check(Snapshot._producer_reuse_eligible(world), "concrete fixture exercises optimized producer route")
	return world


func _assert_capture_equal(world: SimWorld, accepted: bool, label: String, cold: bool = false) -> void:
	var before := world.state_hash()
	if cold: _clear_geometry_cache()
	var expected := Legacy.capture(world)
	if cold: _clear_geometry_cache()
	var actual := Snapshot.capture(world)
	equal(actual, expected, label + " exact complete snapshot dictionary equals frozen pre-bridge oracle")
	equal(var_to_bytes(actual), var_to_bytes(expected), label + " exact complete transport bytes")
	equal(not actual.is_empty(), accepted, label + " preserves acceptance/refusal")
	equal(world.state_hash(), before, label + " leaves source authority unchanged")
	if not actual.is_empty():
		var old_restore := Legacy.prepare(actual, world)
		var new_restore := Snapshot.prepare(actual, world)
		check(old_restore != null and new_restore != null, label + " both strict incoming routes restore")
		if old_restore != null and new_restore != null:
			equal(new_restore.state_hash(), old_restore.state_hash(), label + " complete restored authority agrees")


func _test_exact_capture_and_detachment(world: SimWorld) -> void:
	_assert_capture_equal(world, true, "cold producer", true)
	_assert_capture_equal(world, true, "warm producer")
	var snapshot := Snapshot.capture(world)
	var first := Snapshot.prepare(snapshot, world)
	var second := Snapshot.prepare(snapshot, world)
	check(first != null and second != null, "repeated public restores succeed")
	if first == null or second == null: return
	var before := world.state_hash()
	var cell: Vector2i = first.hex_court.cells.keys()[0]
	first.hex_court.cells[cell].terrain += 1
	first.hex_court.casts.clear()
	first.player(1).health -= 1
	equal(second.state_hash(), before, "restore geometry/dynamic/actor mutation does not reach sibling")
	equal(world.state_hash(), before, "restore mutation does not reach source")
	var third := Snapshot.prepare(snapshot, world)
	check(third != null and third.state_hash() == before, "restore mutation cannot poison exact-byte blank cache")
	var command := SimCommand.new(world.tick, 1, 0, 0, 0, 0, 0, -1000, 640_000, 480_000)
	check(second.step([command]) and third.step([command]), "two independent restores continue through ordinary simulation")
	equal(second.state_hash(), third.state_hash(), "subsequent state remains deterministic")
	_assert_capture_equal(second, true, "mutating continuation")


func _test_mutation_visibility(world: SimWorld) -> void:
	var court: HexChemistryWorld = world.hex_court
	var cells := court.cells.duplicate(true)
	var origin := court.origin
	var cell: Vector2i = court.cells.keys()[0]
	for metadata: String in ["terrain", "elevation", "structure"]:
		court.cells[cell][metadata] = 2_147_483_649
		_assert_capture_equal(world, true, "changed signed64 " + metadata)
		court.cells = cells.duplicate(true)
	court.origin.x += 1
	_assert_capture_equal(world, true, "changed origin between producer calls")
	court.origin = origin
	var reverse := {}
	var keys := court.cells.keys()
	keys.reverse()
	for key: Vector2i in keys: reverse[key] = court.cells[key].duplicate(true)
	court.cells = reverse
	_assert_capture_equal(world, true, "reversed cell insertion order")
	court.cells = cells.duplicate(true)
	# These well-typed malformed authorities must be refused by both producers.
	court.cells[cell].terrain = 3.0
	_assert_capture_equal(world, false, "malformed metadata type")
	court.cells = cells.duplicate(true)
	court.cells[cell].water = 7
	_assert_capture_equal(world, false, "malformed layer type")
	court.cells = cells.duplicate(true)
	court.set_cell_amount(cell, "water", 900_001, 1)
	_assert_capture_equal(world, false, "orphan reverse material")
	court.cells = cells.duplicate(true)
	court.metrics.matter_paid += 1
	_assert_capture_equal(world, false, "broken paid conservation")
	court.metrics.matter_paid -= 1
	var source_key: int = court.sources.keys()[0]
	var source_value: int = court.sources[source_key]
	court.sources.erase(source_key)
	_assert_capture_equal(world, false, "removed paid source mapping")
	court.sources[source_key] = source_value
	# Replace an unused key without changing count. Every capture must admit the
	# new topology rather than trust source identity, cell count or revision.
	var empty: Vector2i = cell
	for key: Vector2i in court.cells:
		if court.cells[key].size() == 3:
			empty = key
			break
	court.cells.erase(empty)
	court.cells[Vector2i(30, 30)] = {"terrain": 0, "elevation": 0, "structure": 0}
	_assert_capture_equal(world, true, "same-count valid topology substitution")
	court.cells = cells.duplicate(true)
	_assert_capture_equal(world, true, "restored exact topology after refusals")


func _test_public_refusals(world: SimWorld) -> void:
	var snapshot := Snapshot.capture(world)
	var bad_hash := snapshot.duplicate(true)
	bad_hash.state_hash = "0".repeat(64)
	var bad_epoch := snapshot.duplicate(true)
	bad_epoch.epoch = 1
	var bad_owner := snapshot.duplicate(true)
	var actors: PackedInt32Array = bad_owner.players.duplicate()
	actors[0] = 99
	bad_owner.players = actors
	var bad_map := snapshot.duplicate(true)
	bad_map.map_hash = "wrong-map"
	var bad_count := snapshot.duplicate(true)
	bad_count.projectiles = PackedInt32Array([1])
	for malformed: Dictionary in [bad_hash, bad_epoch, bad_owner, bad_map, bad_count]:
		var before := world.state_hash()
		check(Snapshot.prepare(malformed, world) == null and Legacy.prepare(malformed, world) == null, "public malformed envelope refuses in both routes")
		equal(world.state_hash(), before, "public refusal cannot publish partial authority")
	var cell: Vector2i = world.hex_court.cells.keys()[0]
	world.hex_court.cells[cell].terrain += 1
	var changed := world.state_hash()
	check(Snapshot.prepare(snapshot, world) == null and Legacy.prepare(snapshot, world) == null, "incoming public prepare revalidates nested metadata despite prior producer admission")
	equal(world.state_hash(), changed, "changed trusted geometry remains untouched on refusal")
	world.hex_court.cells[cell].terrain -= 1


func _test_one_shot_operation(world: SimWorld) -> void:
	var operation := ChemistrySnapshot.ProducerRoundtrip.new(world.hex_court)
	var encoded := operation.snapshot()
	check(not encoded.is_empty(), "producer operation admits actual local source")
	var prepared := operation.consume(encoded, world.hex_court)
	check(prepared != null and prepared.state_hash() == world.hex_court.state_hash(), "operation runs full detached dynamic decode/hash")
	check(operation.consume(encoded, world.hex_court) == null, "consumed operation cannot become a reusable trust cache")
	var tampered := ChemistrySnapshot.ProducerRoundtrip.new(world.hex_court)
	var changed := tampered.snapshot()
	changed.authority_hash = "0".repeat(64)
	check(tampered.consume(changed, world.hex_court) == null, "operation rejects modified roundtrip rather than accepting alleged trusted context")
	var wrong_source := ChemistrySnapshot.ProducerRoundtrip.new(world.hex_court)
	var other := Snapshot.prepare(Snapshot.capture(world), world)
	check(other != null, "one-shot wrong-source fixture restores")
	if other != null: check(wrong_source.consume(wrong_source.snapshot(), other.hex_court) == null, "operation is bound to its actual source instance")
	var stale := ChemistrySnapshot.ProducerRoundtrip.new(world.hex_court)
	world.hex_court.current_tick += 1
	check(stale.consume(stale.snapshot(), world.hex_court) == null, "operation cannot cross an authority tick")
	world.hex_court.current_tick -= 1


func _test_subclass_fallback(world: SimWorld) -> void:
	var actor := world.player(1)
	var alternate := AlternatePlayer.new(1)
	for field: StringName in Snapshot.PLAYER_SCALAR_FIELDS: alternate.set(field, actor.get(field))
	alternate.spell_wire_ids = actor.spell_wire_ids.duplicate()
	alternate.spell_cooldown_ticks = actor.spell_cooldown_ticks.duplicate()
	world.players[0] = alternate
	check(not Snapshot._producer_reuse_eligible(world), "custom actor implementation retains original topology revalidation path")
	_assert_capture_equal(world, true, "custom actor fallback")
	world.players[0] = actor


func _test_reentrant_config_fallback(world: SimWorld) -> void:
	var ordinary := world.config
	var cell: Vector2i = world.hex_court.cells.keys()[0]
	var terrain: int = world.hex_court.cells[cell].terrain
	for warm: bool in [false, true]:
		for arm: String in ["legacy", "candidate"]:
			_clear_geometry_cache()
			if warm: check(not Snapshot.capture(world).is_empty(), "reentrant fixture explicitly warms normal exact-byte cache")
			var configuration := ReentrantConfig.new(ordinary.tick_rate)
			configuration.court = world.hex_court
			configuration.cell = cell
			world.config = configuration
			check(not Snapshot._producer_reuse_eligible(world), "config subclass cannot enter admitted producer reuse")
			var result := Legacy.capture(world) if arm == "legacy" else Snapshot.capture(world)
			check(result.is_empty(), "%s refuses topology changed by second config.is_valid with warm=%s" % [arm, str(warm)])
			equal(configuration.checks, 2, "fixture mutates at the outer prepare validation boundary")
			equal(world.hex_court.cells[cell].terrain, terrain + 1, "same-tick same-size nested geometry mutation actually occurred")
			world.config = ordinary
			world.hex_court.cells[cell].terrain = terrain
			var restored := Snapshot.capture(world)
			check(not restored.is_empty(), "rejected reentrant producer cannot poison later normal capture")
			equal(ChemistrySnapshot._blank_topology_cells[cell].terrain, terrain, "cache remains keyed to its exact admitted metadata")
	_assert_capture_equal(world, true, "post-reentry source recovery")


func _clear_geometry_cache() -> void:
	ChemistrySnapshot._blank_topology_bytes.clear()
	ChemistrySnapshot._blank_topology_cells.clear()
