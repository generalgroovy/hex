extends "res://tests/unit/test_hex_world_snapshot.gd"

# Explicit current-schema adapter retains predecessor capture/prepare ordering;
# the byte-exact E16 schema4 implementation remains preserved as historical evidence.
const Predecessor = preload("res://tests/support/expanded_world_snapshot_reference.gd")
const Packing = preload("res://src/net/hex_snapshot_wire_packing.gd")

class TracedWorld:
	extends SimWorld
	var trace: Array[String] = []
	func is_valid() -> bool:
		trace.append("world.valid")
		return super.is_valid()
	func state_hash() -> String:
		trace.append("world.hash")
		return super.state_hash()

class TracedActor:
	extends PlayerState
	var trace: Array[String] = []
	var court: HexChemistryWorld
	var armed := false
	func canonical_values() -> PackedInt64Array:
		trace.append("actor.values")
		if armed:
			armed = false
			court.metrics.requested += 1
			court.metrics.refused += 1
		return super.canonical_values()

class TracedOpaqueKey:
	extends RefCounted
	var trace: Array[String] = []
	func _to_string() -> String:
		trace.append("opaque.string")
		return "opaque-owned-capture"


func run() -> int:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(ABILITY_PATH), "owned capture uses unchanged production abilities")
	if not catalog.last_error.is_empty(): return finish("hex-owned-capture")
	var empty := _owned_fixture(catalog)
	_capture_pair(empty, true, "empty sealed source")
	_test_actual_outer_boundary(empty)
	var rich := _owned_fixture(catalog)
	var reached := _advance_to_rich_capture(rich)
	check(not reached.is_empty(), "owned fixture reaches actual paid pending/flight/product authority")
	if not reached.is_empty():
		_capture_pair(rich, true, "paid sealed source")
		_test_detachment_and_continuation(rich)
		_test_persistent_mutations(rich)
		_test_public_bytes(rich)
		_test_inner_byte_boundary(rich)
		_test_one_shot_rows(rich)
		_test_maximum_actors(rich)
	_test_fallback_trace(catalog)
	_test_opaque_fallback(catalog)
	return finish("hex-owned-capture")


func _owned_fixture(catalog: AbilityCatalog, requested: SimWorld = null) -> SimWorld:
	var world := SimWorld.new() if requested == null else requested
	check(HexCourtPractice.configure(world, catalog, false), "owned fixture configures ordinary practice")
	var selected: Array[Vector2i] = []
	for cell: Vector2i in world.hex_court.cell_keys(): selected.append(cell)
	var court := HexChemistryWorld.new()
	check(court.configure_geometry(world.hex_court.origin, selected), "owned fixture seals exact concrete geometry")
	court.chemistry_enabled = true
	var base: CollisionWorld = world.collision
	var collision := HexCollisionWorld.new(base)
	check(collision.set_hex_surfaces(court, world.tick), "owned fixture installs concrete collision")
	court.collision = base
	world.hex_court = court
	world.collision = collision
	world.reaction_movement = collision
	return world


func _capture_pair(world: SimWorld, accepted: bool, label: String) -> Dictionary:
	check(Snapshot._producer_reuse_eligible(world), label + " exercises the concrete precompression route")
	var expected := Predecessor.capture(world)
	var actual := Snapshot.capture(world)
	equal(not expected.is_empty(), accepted, label + " frozen acceptance expectation is explicit")
	equal(not actual.is_empty(), accepted, label + " preserves acceptance/refusal")
	equal(actual, expected, label + " exact frozen dictionary")
	equal(var_to_bytes(actual), var_to_bytes(expected), label + " exact frozen Variant bytes, types and insertion order")
	if not actual.is_empty():
		equal(actual.keys(), Snapshot.SNAPSHOT_KEYS, label + " published outer key order")
		equal(actual.hex.keys(), ["schema", "size", "bytes"], label + " compressed envelope key order")
		check(Snapshot.validate_wire_structure(actual), label + " strict public wire admission succeeds")
		var restored := Snapshot.prepare(actual, world)
		var old_restored := Predecessor.prepare(actual, world)
		check(restored != null and old_restored != null, label + " both byte-driven receivers accept")
		if restored != null and old_restored != null:
			equal(restored.state_hash(), world.state_hash(), label + " complete reconstructed authority agrees")
			equal(restored.state_hash(), old_restored.state_hash(), label + " frozen reconstruction agrees")
	return actual


func _test_actual_outer_boundary(world: SimWorld) -> void:
	var original_id := world.map_id
	var initial := Snapshot.capture(world)
	check(not initial.is_empty(), "outer boundary starts with a positive admitted snapshot")
	if initial.is_empty(): return
	var padding := Snapshot.MAX_RAW_BYTES - Snapshot.byte_size(initial)
	check(padding > 0 and padding % 4 == 0, "actual Variant size leaves an aligned exact-boundary fixture")
	world.map_id += "x".repeat(padding)
	var exact := _capture_pair(world, true, "actual serialized outer boundary")
	if not exact.is_empty():
		equal(Snapshot.byte_size(exact), 65_536, "65536 actual bytes are accepted after compression under the expanded status/delivery envelope")
		var over := exact.duplicate(true)
		over.map_id += "xxxx"
		equal(Snapshot.byte_size(over), 65_540, "over-bound fixture changes actual padded bytes by four beyond the65536-byte ceiling")
		check(not Snapshot.validate_wire_structure(over), "public wire path refuses actual over-bound bytes")
		check(Snapshot.prepare(over, world) == null and Predecessor.prepare(over, world) == null, "both public receivers refuse over-bound snapshot")
	world.map_id += "xxxx"
	_capture_pair(world, false, "actual serialized outer boundary plus four")
	world.map_id = original_id
	_capture_pair(world, true, "outer boundary recovery on same source")


func _test_detachment_and_continuation(world: SimWorld) -> void:
	var expected := Predecessor.capture(world)
	var before := world.state_hash()
	var snapshot := Snapshot.capture(world)
	var left := Snapshot.prepare(snapshot, world)
	var right := Predecessor.prepare(snapshot, world)
	check(left != null and right != null, "fresh owned capture prepares independent receivers")
	if left == null or right == null: return
	check(left.players[0] != world.players[0] and left.hex_court != world.hex_court, "no actor or mutable chemistry alias escapes capture")
	left.players[0].health -= 1
	left.hex_court.metrics.requested += 1
	left.hex_court.metrics.refused += 1
	equal(right.state_hash(), before, "prepared actor/chemistry changes do not reach sibling")
	equal(world.state_hash(), before, "prepared changes do not reach live source")
	var actors: PackedInt32Array = snapshot.players
	actors[0] = 999
	var compressed: PackedByteArray = snapshot.hex.bytes
	compressed[0] = compressed[0] ^ 255
	snapshot.hex["size"] += 1
	equal(var_to_bytes(Snapshot.capture(world)), var_to_bytes(expected), "mutating every returned lane cannot poison the next capture")
	var second := Snapshot.prepare(expected, world)
	check(second != null, "independent receiver survives returned snapshot mutation")
	if second == null: return
	var command := SimCommand.new(world.tick, 1, 0, 0, 0, 0, 0, -1000, 640_000, 480_000)
	check(second.step([command]) and right.step([command]), "candidate/frozen receivers advance the identical next command")
	equal(second.state_hash(), right.state_hash(), "candidate/frozen restored continuation is identical")
	_capture_pair(second, true, "restored next-tick source")


func _test_persistent_mutations(world: SimWorld) -> void:
	var court: HexChemistryWorld = world.hex_court
	var actor := world.players[0]
	actor.health -= 1
	_capture_pair(world, true, "same actor reference changed health")
	actor.health += 1
	court.metrics.matter_paid += 1
	_capture_pair(world, false, "same metrics reference broken conservation")
	court.metrics.matter_paid -= 1
	court.metrics["unknown-zero"] = 0
	_capture_pair(world, false, "same metrics reference extra hash-covered zero")
	court.metrics.erase("unknown-zero")
	var source_id: int = court.sources.keys()[0]
	var cast_id: int = court.sources[source_id]
	court.sources.erase(source_id)
	_capture_pair(world, false, "same sources reference lost paid mapping")
	court.sources[source_id] = cast_id
	var saved_next := world.next_projectile_id
	world.next_projectile_id = world.projectiles[0].entity_id
	_capture_pair(world, false, "cross-world next projectile ID aliases live flight")
	world.next_projectile_id = saved_next
	court.current_tick += 1
	_capture_pair(world, false, "inner tick disagrees with outer header")
	court.current_tick -= 1
	var original_rows: Dictionary = court.cells.duplicate(true)
	var cell: Vector2i = court.cells.keys()[0]
	court.cells[cell].water = 7
	_capture_pair(world, false, "same materialized cells reference malformed known layer")
	court.cells = original_rows.duplicate(true)
	court.cells[cell].terrain = 3.0
	_capture_pair(world, false, "same materialized cells reference malformed static metadata")
	court.cells = original_rows.duplicate(true)
	_capture_pair(world, true, "legacy materialized geometry recovery")
	var original_origin := court.origin
	court.origin.x += 1
	_capture_pair(world, true, "same source origin changed without a trust cache")
	court.origin = original_origin
	_capture_pair(world, true, "all persistent source mutations repaired")


func _test_public_bytes(world: SimWorld) -> void:
	var snapshot := Snapshot.capture(world)
	check(not snapshot.is_empty(), "public malformed tests start from positive capture")
	if snapshot.is_empty(): return
	var before := world.state_hash()
	var bad := snapshot.duplicate(true)
	bad.state_hash = "0".repeat(64)
	_assert_public_refusal(bad, world, "outer hash")
	bad = snapshot.duplicate(true)
	bad.epoch = 1
	_assert_public_refusal(bad, world, "reserved epoch")
	bad = snapshot.duplicate(true)
	var actors: PackedInt32Array = bad.players.duplicate()
	actors[16] = 2
	bad.players = actors
	_assert_public_refusal(bad, world, "actor boolean domain")
	bad = snapshot.duplicate(true)
	bad.hex["size"] += 1
	_assert_public_refusal(bad, world, "declared inflate size")
	bad = snapshot.duplicate(true)
	var wrong_type := var_to_bytes(PackedInt32Array([1, 2, 3]))
	bad.hex = {"schema": Snapshot.SCHEMA_VERSION, "size": wrong_type.size(), "bytes": wrong_type.compress(FileAccess.COMPRESSION_DEFLATE)}
	_assert_public_refusal(bad, world, "inflated bytes contain a non-Dictionary Variant")
	var packed: Dictionary = Predecessor._decompress_hex(snapshot.hex)
	for lane: String in ["cast_allocations", "product_allocations", "product_sources", "cast_parts", "product_states"]:
		var malformed := packed.duplicate(true)
		if lane in ["cast_allocations", "product_allocations"]:
			malformed[lane] = PackedByteArray([1])
		else:
			malformed[lane] = PackedInt32Array([1])
		check(Packing.strict_decode(malformed, world.hex_court.cell_count()).is_empty(), lane + " fresh strict decode refuses malformed framing")
		check(Snapshot._compress_hex(malformed).is_empty() and Predecessor._compress_hex(malformed).is_empty(), lane + " public compression still validates caller-owned packed input")
		# Bypass only the test's encoder to prove public prepare still consumes
		# bytes strictly; no alleged-trusted predecoded input enters production.
		var raw := var_to_bytes(malformed)
		bad = snapshot.duplicate(true)
		bad.hex = {"schema": Snapshot.SCHEMA_VERSION, "size": raw.size(), "bytes": raw.compress(FileAccess.COMPRESSION_DEFLATE)}
		_assert_public_refusal(bad, world, lane + " forged envelope")
		check(not Snapshot.validate_wire_structure(bad), lane + " transport validation still rejects")
	equal(world.state_hash(), before, "all malformed public inputs leave authority unchanged")
	equal(var_to_bytes(Snapshot.capture(world)), var_to_bytes(snapshot), "malformed public inputs cannot poison later owned capture")


func _assert_public_refusal(value: Dictionary, world: SimWorld, label: String) -> void:
	check(Snapshot.prepare(value, world) == null, label + " candidate public prepare refuses")
	check(Predecessor.prepare(value, world) == null, label + " frozen public prepare refuses")


func _test_inner_byte_boundary(world: SimWorld) -> void:
	var snapshot := Snapshot.capture(world)
	if snapshot.is_empty():
		check(false, "inner boundary requires positive snapshot")
		return
	var packed := Predecessor._decompress_hex(snapshot.hex)
	var padding := Snapshot.MAX_HEX_UNCOMPRESSED_BYTES - var_to_bytes(packed).size()
	check(padding > 0 and padding % 4 == 0, "synthetic grammar fixture has exact aligned raw-inner headroom")
	# This tests the unchanged public encoding boundary, not legal gameplay
	# capacity: the padded topology hash is intentionally semantically invalid.
	packed.topology_hash += "x".repeat(padding)
	equal(var_to_bytes(packed).size(), 524_288, "raw inner fixture reaches exact actual serialized cap")
	var encoded := Snapshot._compress_hex(packed)
	check(not encoded.is_empty(), "public compression admits grammar exactly at raw byte cap")
	equal(var_to_bytes(encoded), var_to_bytes(Predecessor._compress_hex(packed)), "exact-cap DEFLATE output equals frozen implementation")
	packed.topology_hash += "xxxx"
	equal(var_to_bytes(packed).size(), 524_292, "raw inner fixture exceeds cap by one aligned unit")
	check(Snapshot._compress_hex(packed).is_empty() and Predecessor._compress_hex(packed).is_empty(), "public encoding still refuses raw-inner over-bound bytes")


func _test_one_shot_rows(world: SimWorld) -> void:
	var operation := ChemistrySnapshot.ProducerRoundtrip.new(world.hex_court)
	var detached := operation.snapshot()
	var packed := Packing.pack(detached, world.hex_court.cell_count())
	var decoded := Packing.strict_decode(packed, world.hex_court.cell_count())
	check(not detached.is_empty() and not packed.is_empty() and not decoded.is_empty(), "one-shot test uses fresh complete packed/strictly decoded rows")
	if decoded.is_empty(): return
	equal(decoded, detached, "strict packed decoding reproduces the producer equality witness")
	var prepared := operation.consume(decoded, world.hex_court)
	check(prepared != null and prepared.state_hash() == world.hex_court.state_hash(), "precompression rows still run complete one-shot chemistry reconstruction")
	check(operation.consume(decoded, world.hex_court) == null, "consumed proof cannot become persistent trust")
	var tampered := ChemistrySnapshot.ProducerRoundtrip.new(world.hex_court)
	var changed := tampered.snapshot()
	var metrics: PackedInt64Array = changed.metrics.duplicate()
	metrics[0] += 1
	changed.metrics = metrics
	check(tampered.consume(changed, world.hex_court) == null, "detached mutation cannot alter the private producer witness")
	check(tampered.consume(tampered.snapshot(), world.hex_court) == null, "failed consume also exhausts its one-shot proof")


func _test_maximum_actors(world: SimWorld) -> void:
	for id: int in range(2, Snapshot.MAX_ACTORS + 1):
		var actor := PlayerState.new(id)
		actor.team_id = id
		if id > Snapshot.MAX_PLAYERS:
			actor.actor_kind = PlayerState.ActorKind.TRAINING_TARGET
			actor.training_spawn_x = actor.position_x
			actor.training_spawn_y = actor.position_y
		world.players.append(actor)
	_capture_pair(world, true, "unchanged eight champions plus four target boundary")
	world.players.append(PlayerState.new(Snapshot.MAX_ACTORS + 1))
	_capture_pair(world, false, "actor count above unchanged envelope")
	world.players.pop_back()


func _test_fallback_trace(catalog: AbilityCatalog) -> void:
	for mutate: bool in [false, true]:
		var traces: Array = []
		var results: Array = []
		for use_old: bool in [true, false]:
			var world := TracedWorld.new()
			_owned_fixture(catalog, world)
			var original := world.players[0]
			var actor := TracedActor.new(original.entity_id)
			for field: StringName in Snapshot.PLAYER_SCALAR_FIELDS: actor.set(field, original.get(field))
			actor.spell_wire_ids = original.spell_wire_ids.duplicate()
			actor.spell_cooldown_ticks = original.spell_cooldown_ticks.duplicate()
			actor.trace = world.trace
			actor.court = world.hex_court
			actor.armed = mutate
			world.players[0] = actor
			world.trace.clear()
			check(not Snapshot._producer_reuse_eligible(world), "extension actor/world cannot enter precompression")
			var captured := Predecessor.capture(world) if use_old else Snapshot.capture(world)
			traces.append(world.trace.duplicate())
			results.append(captured)
			equal(not captured.is_empty(), not mutate, "extension fallback preserves callback mutation refusal")
			check(not Snapshot.capture(world).is_empty(), "disarmed extension recovers without poisoned producer state")
			actor.court = null
			equal(actor.armed, false, "mutation callback was actually consumed")
		equal(traces[1], traces[0], "extension canonical/hash/valid callback order equals frozen predecessor")
		equal(var_to_bytes(results[1]), var_to_bytes(results[0]), "extension output/refusal bytes equal predecessor")


func _test_opaque_fallback(catalog: AbilityCatalog) -> void:
	var traces: Array = []
	for use_old: bool in [true, false]:
		var world := _owned_fixture(catalog)
		var opaque := TracedOpaqueKey.new()
		world.hex_court.metrics[opaque] = 0
		check(not Snapshot._producer_reuse_eligible(world), "opaque data on otherwise concrete source retains byte-driven fallback")
		check(opaque.trace.is_empty(), "deep admission does not invoke opaque stringification")
		var captured := Predecessor.capture(world) if use_old else Snapshot.capture(world)
		check(captured.is_empty(), "opaque hash-covered extra key is still refused")
		check(not opaque.trace.is_empty(), "opaque test actually reaches the old virtual formatting boundary")
		traces.append(opaque.trace.duplicate())
		world.hex_court.metrics.erase(opaque)
		_capture_pair(world, true, "same opaque source repaired")
	equal(traces[1], traces[0], "opaque callback count and order equal frozen predecessor")
