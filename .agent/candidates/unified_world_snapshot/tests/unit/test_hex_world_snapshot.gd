extends FluxTestSuite


const Snapshot = preload("res://src/net/hex_world_snapshot.gd")
const ABILITY_PATH := "res://content/abilities/foundation_abilities_v1.json"


func run() -> int:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(ABILITY_PATH), "world snapshot fixtures load the production ability catalog: %s" % catalog.last_error)
	if not catalog.last_error.is_empty():
		return finish("hex-world-snapshot")
	_test_paid_sequence_round_trip(catalog)
	_test_corruptions_reject_atomically(catalog)
	_test_trusted_map_and_reserved_epoch(catalog)
	_test_legal_actor_boundary_and_packet_size(catalog)
	return finish("hex-world-snapshot")


func _test_paid_sequence_round_trip(catalog: AbilityCatalog) -> void:
	var original := SimWorld.new()
	check(HexCourtPractice.configure(original, catalog, false), "production world configures the current Water/Fire court")
	var snapshot := _advance_to_rich_capture(original)
	check(not snapshot.is_empty(), "real paid SimCommand sequence reaches one capture with flight, pending cast, and product authority")
	if snapshot.is_empty():
		return
	check(Snapshot.byte_size(snapshot) > 0 and Snapshot.byte_size(snapshot) <= Snapshot.MAX_RAW_BYTES, "complete world capture fits the unchanged 32768-byte raw guard")
	equal(int(snapshot.epoch), 0, "schema reserves epoch zero until a real reset epoch exists")
	equal((snapshot.players as PackedInt32Array).size(), Snapshot.PLAYER_VALUE_COUNT, "solo fixture carries all 136 scalar, 12 spell, and 12 cooldown values")
	equal((snapshot.projectiles as PackedInt32Array).size() % Snapshot.PROJECTILE_ROW_SIZE, 0, "every flight carries one complete mutable projectile row")

	var trusted := SimWorld.new()
	check(HexCourtPractice.configure(trusted, catalog, false), "independent restore target supplies its own map, collision, and topology")
	var prepared := Snapshot.prepare(snapshot, trusted)
	check(prepared != null, "valid capture prepares in a temporary SimWorld")
	if prepared == null:
		return
	check(prepared.collision == trusted.collision, "prepare retains caller-trusted collision authority")
	check(prepared.hex_court != original.hex_court and prepared.players[0] != original.players[0], "prepare owns fresh mutable world, chemistry, and actor state")
	equal(prepared.state_hash(), original.state_hash(), "temporary decode reproduces the complete SimWorld state hash")
	check(Snapshot.restore(snapshot, trusted), "validated temporary authority swaps atomically into the target")
	equal(trusted.state_hash(), original.state_hash(), "restore retains the exact complete world hash")

	var next_tick := original.tick
	var next_command := SimCommand.new(next_tick, 1, 0, 0, 0, 0, 0, -1000, 640_000, 480_000)
	check(original.step([next_command]) and trusted.step([next_command]), "original and restored worlds accept the identical next command")
	equal(trusted.state_hash(), original.state_hash(), "restored world produces the identical subsequent state")


func _test_corruptions_reject_atomically(catalog: AbilityCatalog) -> void:
	var source := SimWorld.new()
	check(HexCourtPractice.configure(source, catalog, false), "malformation fixture configures")
	var snapshot := _advance_to_rich_capture(source)
	if snapshot.is_empty():
		return

	var bad_bool := snapshot.duplicate(true)
	var player_values: PackedInt32Array = bad_bool.players.duplicate()
	player_values[16] = 2
	bad_bool.players = player_values
	_rejects_without_mutation(bad_bool, catalog, "non-boolean player flag")

	var bad_next_id := snapshot.duplicate(true)
	var header: PackedInt64Array = bad_next_id.header.duplicate()
	var projectiles: PackedInt32Array = bad_next_id.projectiles
	header[3] = projectiles[0]
	bad_next_id.header = header
	_rejects_without_mutation(bad_next_id, catalog, "next projectile ID that aliases a live flight")

	var bad_mask := snapshot.duplicate(true)
	var projectile_values: PackedInt32Array = bad_mask.projectiles.duplicate()
	projectile_values[25] = 32
	bad_mask.projectiles = projectile_values
	_rejects_without_mutation(bad_mask, catalog, "chemistry mask above the explicit high-five-bit lane")

	var bad_owner := snapshot.duplicate(true)
	projectile_values = bad_owner.projectiles.duplicate()
	projectile_values[1] = 999
	bad_owner.projectiles = projectile_values
	_rejects_without_mutation(bad_owner, catalog, "projectile with no owning champion")

	var bad_source := snapshot.duplicate(true)
	var packed_hex: Dictionary = bad_source.hex.duplicate(true)
	var sources: PackedInt32Array = packed_hex.sources.duplicate()
	sources[1] = 0x7fffffff
	packed_hex.sources = sources
	bad_source.hex = packed_hex
	_rejects_without_mutation(bad_source, catalog, "orphan compact hex source mapping")

	var legacy_state := snapshot.duplicate(true)
	legacy_state.fields = PackedInt32Array([1])
	_rejects_without_mutation(legacy_state, catalog, "nonzero legacy field authority in a hex world")

	var forged_hash := snapshot.duplicate(true)
	forged_hash.state_hash = "0".repeat(64)
	_rejects_without_mutation(forged_hash, catalog, "forged complete-world hash")

	var oversized := snapshot.duplicate(true)
	var oversized_hex: Dictionary = oversized.hex.duplicate(true)
	var oversized_plane := PackedByteArray()
	oversized_plane.resize(Snapshot.MAX_RAW_BYTES)
	oversized_hex.cast_allocations = oversized_plane
	oversized.hex = oversized_hex
	check(Snapshot.byte_size(oversized) > Snapshot.MAX_RAW_BYTES, "oversized corruption actually crosses the unchanged raw-byte limit")
	_rejects_without_mutation(oversized, catalog, "raw payload above 32768 bytes")


func _test_trusted_map_and_reserved_epoch(catalog: AbilityCatalog) -> void:
	var source := SimWorld.new()
	check(HexCourtPractice.configure(source, catalog, false), "trusted-map fixture configures")
	var snapshot := _advance_to_rich_capture(source)
	if snapshot.is_empty():
		return

	var target := SimWorld.new()
	check(HexCourtPractice.configure(target, catalog, false), "trusted-map target configures independently")
	target.map_hash = "different-trusted-map"
	var before := target.state_hash()
	check(not Snapshot.restore(snapshot, target), "snapshot cannot replace caller-trusted map identity")
	equal(target.state_hash(), before, "map mismatch rejection leaves the target atomic")

	var future_epoch := snapshot.duplicate(true)
	future_epoch.epoch = 1
	_rejects_without_mutation(future_epoch, catalog, "unsupported nonzero reset epoch")

	var remote_topology := snapshot.duplicate(true)
	var packed_hex: Dictionary = remote_topology.hex.duplicate(true)
	packed_hex.topology_hash = "0".repeat(64)
	remote_topology.hex = packed_hex
	_rejects_without_mutation(remote_topology, catalog, "remote topology fingerprint")


func _test_legal_actor_boundary_and_packet_size(catalog: AbilityCatalog) -> void:
	var world := SimWorld.new()
	check(HexCourtPractice.configure(world, catalog, false), "packet-boundary fixture configures")
	var rich := _advance_to_rich_capture(world)
	if rich.is_empty():
		return
	for entity_id: int in range(2, Snapshot.MAX_PLAYERS + 1):
		var champion := PlayerState.new(entity_id)
		champion.team_id = entity_id
		champion.position_x = 100_000 + entity_id * 20_000
		champion.position_y = 200_000
		world.players.append(champion)
	for entity_id: int in range(Snapshot.MAX_PLAYERS + 1, Snapshot.MAX_ACTORS + 1):
		var target := PlayerState.new(entity_id)
		target.actor_kind = PlayerState.ActorKind.TRAINING_TARGET
		target.team_id = entity_id
		target.position_x = 100_000 + entity_id * 20_000
		target.position_y = 300_000
		target.training_spawn_x = target.position_x
		target.training_spawn_y = target.position_y
		world.players.append(target)
	var unspent := 0
	for cast_id: int in world.hex_court.casts:
		var cast: Dictionary = world.hex_court.casts[cast_id]
		if int(cast.unallocated) > 0 or (not cast.ledger.is_empty() and int(cast.ledger.remaining_strength) > 0):
			unspent += 1
	check(world.hex_court.products.size() + unspent <= 32, "legal boundary uses the current product-plus-unspent envelope rather than impossible simultaneous maxima")
	var snapshot := Snapshot.capture(world)
	check(not snapshot.is_empty(), "eight champions plus four complete target states capture without truncation")
	if snapshot.is_empty():
		return
	equal((snapshot.players as PackedInt32Array).size(), Snapshot.MAX_ACTORS * Snapshot.PLAYER_VALUE_COUNT, "all twelve complete actor states are present")
	var packet_bytes := Snapshot.byte_size(snapshot)
	equal(Snapshot.MAX_RAW_BYTES, 32_768, "world codec retains the unchanged raw transport boundary")
	check(packet_bytes > 0 and packet_bytes <= Snapshot.MAX_RAW_BYTES, "maximum legal actor fixture reports a raw packet within 32768 bytes: %d" % packet_bytes)


func _advance_to_rich_capture(world: SimWorld) -> Dictionary:
	for step: int in range(560):
		var slot := 0 if step in [0, 160, 260] else 1 if step in [100, 190] else -1
		var pressed := int(SimCommand.SPELL_PRESSED_BITS[slot]) if slot >= 0 else 0
		var command := SimCommand.new(step, 1, 0, 0, 0, pressed, 0, -1000, 640_000, 480_000)
		check(world.step([command]), "paid production command advances at tick %d" % step)
		var pending := world.player(1).pending_cast_wire_id > 0
		if pending and not world.projectiles.is_empty() and not world.hex_court.products.is_empty():
			return Snapshot.capture(world)
	return {}


func _rejects_without_mutation(snapshot: Dictionary, catalog: AbilityCatalog, label: String) -> void:
	var target := SimWorld.new()
	check(HexCourtPractice.configure(target, catalog, false), "%s target configures" % label)
	var before := target.state_hash()
	check(not Snapshot.restore(snapshot, target), "%s rejects" % label)
	equal(target.state_hash(), before, "%s rejection is atomic" % label)
