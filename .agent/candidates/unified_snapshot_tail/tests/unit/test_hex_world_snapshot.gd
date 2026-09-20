extends FluxTestSuite


const Snapshot = preload("res://src/net/hex_world_snapshot.gd")
const ChemistrySnapshot = preload("res://src/net/hex_chemistry_snapshot.gd")
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
	_test_source_location_and_seed(catalog)
	_test_split_flight_bijection(catalog)
	_test_saturated_authority(catalog)
	return finish("hex-world-snapshot")


func _test_split_flight_bijection(catalog: AbilityCatalog) -> void:
	var world := SimWorld.new()
	check(HexCourtPractice.configure(world, catalog, false), "split-flight fixture configures")
	var initial := _advance_to_rich_capture(world)
	if initial.is_empty() or world.projectiles.is_empty():
		return
	var parent: ProjectileState = world.projectiles[0]
	var child_id := world.next_projectile_id
	world.next_projectile_id += 1
	check(world.hex_court.split_flight(parent.source_cast_id, parent.entity_id, child_id), "one source partitions into two positive flight branches")
	var ledger: Dictionary = world.hex_court.ledger_for_source(parent.source_cast_id)
	var child_row := Snapshot._capture_projectile(parent, ledger)
	child_row[0] = child_id
	var decoded: Variant = Snapshot._decode_projectiles(child_row, PackedInt32Array([child_id, 0]))
	check(decoded != null and decoded.size() == 1, "split fixture constructs the matching second projectile row")
	if decoded == null or decoded.is_empty():
		return
	world.projectiles.append(decoded[0])
	var snapshot := Snapshot.capture(world)
	check(not snapshot.is_empty(), "multiple live projectile rows for one source capture when flight_parts is bijective")
	if snapshot.is_empty():
		return
	var missing_branch := snapshot.duplicate(true)
	var rows: PackedInt32Array = missing_branch.projectiles
	missing_branch.projectiles = rows.slice(0, rows.size() - Snapshot.PROJECTILE_ROW_SIZE)
	var grazes: PackedInt32Array = missing_branch.projectile_grazes
	missing_branch.projectile_grazes = grazes.slice(0, grazes.size() - 2)
	_rejects_without_mutation(missing_branch, catalog, "flight_parts branch with no projectile row")


func _test_paid_sequence_round_trip(catalog: AbilityCatalog) -> void:
	var original := SimWorld.new()
	check(HexCourtPractice.configure(original, catalog, false), "production world configures the current Water/Fire court")
	var snapshot := _advance_to_rich_capture(original)
	check(not snapshot.is_empty(), "real paid SimCommand sequence reaches one capture with flight, pending cast, and product authority")
	if snapshot.is_empty():
		return
	_check_chemistry_outer_capture_equivalence(original, "ordinary paid authority")
	check(Snapshot.byte_size(snapshot) > 0 and Snapshot.byte_size(snapshot) <= Snapshot.MAX_RAW_BYTES, "complete world capture fits the unchanged 32768-byte raw guard")
	check(Snapshot.validate_wire_structure(snapshot), "transport validator accepts the exact typed v2 envelope without topology")
	equal(int(snapshot.epoch), 0, "schema reserves epoch zero until a real reset epoch exists")
	equal((snapshot.players as PackedInt32Array).size(), Snapshot.PLAYER_VALUE_COUNT, "solo fixture carries all 136 scalar, 12 spell, and 12 cooldown values")
	equal((snapshot.projectiles as PackedInt32Array).size() % Snapshot.PROJECTILE_ROW_SIZE, 0, "every flight carries one complete mutable projectile row")

	var trusted := SimWorld.new()
	check(HexCourtPractice.configure(trusted, catalog, false), "independent restore target supplies its own map, collision, and topology")
	var prepared := Snapshot.prepare(snapshot, trusted)
	check(prepared != null, "valid capture prepares in a temporary SimWorld")
	if prepared == null:
		return
	check(prepared.collision != trusted.collision and prepared.collision is HexCollisionWorld, "prepare clones the trusted worldbone into fresh dynamic hex collision authority")
	check(prepared.reaction_movement == prepared.collision, "prepared movement and collision share the decoded dynamic surface instance")
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
	var packed_hex: Dictionary = Snapshot._decompress_hex(bad_source.hex)
	var sources: PackedInt32Array = packed_hex.sources.duplicate()
	sources[1] = 0x7fffffff
	packed_hex.sources = sources
	bad_source.hex = Snapshot._compress_hex(packed_hex)
	_rejects_without_mutation(bad_source, catalog, "orphan compact hex source mapping")

	var legacy_state := snapshot.duplicate(true)
	legacy_state.fields = PackedInt32Array([1])
	_rejects_without_mutation(legacy_state, catalog, "nonzero legacy field authority in a hex world")

	var forged_hash := snapshot.duplicate(true)
	forged_hash.state_hash = "0".repeat(64)
	_rejects_without_mutation(forged_hash, catalog, "forged complete-world hash")

	# This remains a fully well-formed wire snapshot. Only the captured player
	# lane differs from the producer state represented by state_hash, proving the
	# retained outer prepare catches a valid-looking omission or stale lane.
	var stale_player_lane := snapshot.duplicate(true)
	var stale_player_values: PackedInt32Array = stale_player_lane.players.duplicate()
	stale_player_values[4] += 1
	stale_player_lane.players = stale_player_values
	check(Snapshot.validate_wire_structure(stale_player_lane), "well-formed stale player lane passes transport-only structure checks")
	_rejects_without_mutation(stale_player_lane, catalog, "well-formed player lane with stale producer hash")

	var wrong_hex_size := snapshot.duplicate(true)
	var envelope: Dictionary = wrong_hex_size.hex.duplicate(true)
	envelope["size"] = int(envelope["size"]) + 1
	wrong_hex_size.hex = envelope
	check(not Snapshot.validate_wire_structure(wrong_hex_size), "compressed envelope rejects a false uncompressed size before topology")
	_rejects_without_mutation(wrong_hex_size, catalog, "false compressed-hex size")

	var oversized := snapshot.duplicate(true)
	var oversized_bytes := PackedByteArray()
	oversized_bytes.resize(Snapshot.MAX_RAW_BYTES)
	oversized.hex = {"schema": Snapshot.SCHEMA_VERSION, "size": 1, "bytes": oversized_bytes}
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
	var packed_hex: Dictionary = Snapshot._decompress_hex(remote_topology.hex)
	packed_hex.topology_hash = "0".repeat(64)
	remote_topology.hex = Snapshot._compress_hex(packed_hex)
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
	equal(packet_bytes, var_to_bytes(snapshot).size(), "wire bound includes actual Variant headers and padding")

func _test_source_location_and_seed(catalog: AbilityCatalog) -> void:
	var source := SimWorld.new()
	HexCourtPractice.configure(source, catalog, false)
	var snapshot := _advance_to_rich_capture(source)
	if snapshot.is_empty(): return
	var orphan := snapshot.duplicate(true)
	var orphan_world := Snapshot.prepare(snapshot, source)
	orphan_world.projectiles.clear()
	orphan.projectiles = PackedInt32Array()
	orphan.projectile_grazes = PackedInt32Array()
	orphan.state_hash = orphan_world.state_hash()
	_rejects_without_mutation(orphan, catalog, "recomputed hash with paid flight stock but no live projectile")
	for seed_value: int in [0, -1, 0x100000000]:
		source.seed = seed_value
		var seed_snapshot := Snapshot.capture(source)
		check(not seed_snapshot.is_empty(), "snapshot preserves the existing full signed seed domain")
		if not seed_snapshot.is_empty():
			var restored := Snapshot.prepare(seed_snapshot, source)
			check(restored != null and restored.seed == seed_value, "seed round trip is exact")
	var shot: ProjectileState = source.projectiles[0]
	shot.remaining_distance = 141_000_000
	var diagonal := Snapshot.capture(source)
	check(not diagonal.is_empty(), "current legal diagonal projectile range above100M captures")
	if not diagonal.is_empty():
		var restored := Snapshot.prepare(diagonal, source)
		check(restored != null, "long diagonal range prepares")
		if restored != null:
			check(source.step([]) and restored.step([]), "long diagonal worlds continue")
			equal(source.state_hash(), restored.state_hash(), "long diagonal range and signed seed preserve subsequent state")
	var pending_world := Snapshot.prepare(snapshot, source)
	var pending_id := int(pending_world.hex_court.pending[1])
	pending_world.hex_court.casts[pending_id].paid = false
	check(not Snapshot._validate_relations(pending_world), "resumable pending reservation must have completed payment")
	var deposited_world := Snapshot.prepare(snapshot, source)
	var live: ProjectileState = deposited_world.projectiles[0]
	deposited_world.hex_court.deposit_terminal({"source_cast_id": live.source_cast_id, "source_wire_id": live.source_wire_id, "reaction_strength": live.reaction_strength, "position": Vector2i(800_000, 500_000), "direction": Vector2i(1000, 0)}, deposited_world.hex_court.current_tick)
	check(not Snapshot._validate_relations(deposited_world), "a live projectile cannot reuse deposited source stock")

func _test_saturated_authority(catalog: AbilityCatalog) -> void:
	# Capacity fixtures exercise the production paid reservation/ledger API.
	# Command-driven continuation is proved separately above; these establish
	# legal envelope sizes without assuming every independent cap is reachable.
	for mode: String in ["ground", "flight", "products"]:
		var world := SimWorld.new()
		HexCourtPractice.configure(world, catalog, false)
		for actor_id: int in range(2, 13):
			var actor := PlayerState.new(actor_id)
			actor.team_id = actor_id
			if actor_id > 8: actor.actor_kind = PlayerState.ActorKind.TRAINING_TARGET
			world.players.append(actor)
		var ordered: Array = world.hex_court.cells.keys()
		ordered.sort_custom(HexGrid._cell_less)
		var wire := int(catalog.ability(catalog.spell_id_at("water", "rapid")).wire_id)
		var count := 63 if mode == "products" else 32
		for index: int in count:
			var owner := index % 8 + 1
			check(world.hex_court.reserve_cast(owner, wire), "legal%s envelope reserves source%d" % [mode, index])
			world.hex_court.commit_payment(owner)
			var source_id := world.next_projectile_id
			world.next_projectile_id += 1
			world.hex_court.bind_release(owner, source_id, Vector2i(640_000, 480_000), Vector2i(0, -1000))
			if mode == "ground":
				world.hex_court.deposit_terminal({"source_cast_id": source_id, "source_wire_id": wire, "reaction_strength": 1, "position": world.hex_court.origin + HexGrid.center(ordered[index]), "direction": Vector2i(0, -1000)}, 0)
			elif mode == "products" and index < 62:
				if index % 2 == 1:
					check(bool(world.hex_court.resolve_contact(source_id - 1, source_id, Vector2i(640_000, 480_000), 0).accepted), "paired paid sources form finite product")
					world.hex_court.sync_flights(world.players, world.projectiles)
			else:
				var shot := ProjectileState.new(source_id, owner, owner, wire, 3, Vector2i(150_000, 150_000), Vector2i(1000, 0), 3000, 1000, 400)
				shot.source_cast_id = source_id
				shot.reaction_strength = 1
				shot.initial_strength = 1
				shot.remaining_strength = 1
				for actor_id: int in range(1, 13):
					if actor_id != owner: shot.grazed_entity_ids.append(actor_id)
				world.projectiles.append(shot)
		equal(world.hex_court.reserved_products(), 32, "%s fixture reaches the combined admission boundary exactly" % mode)
		world.tick = 1
		if mode == "products":
			for actor: PlayerState in world.players:
				actor.position_x = 640_000
				actor.position_y = 480_000
				actor.training_spawn_x = 640_000
				actor.training_spawn_y = 480_000
			for unused: int in 24: check(world.step([]), "dense products advance to active flow through the production simulation")
			equal(world.hex_court.flow_carry.size(), 31 * 12, "dense active packet includes every product and actor flow remainder")
		check(world.hex_court.conservation_valid(), "%s saturated fixture preserves all paid matter" % mode)
		if mode == "products":
			_check_chemistry_outer_capture_equivalence(world, "saturated product authority")
		var snapshot := Snapshot.capture(world)
		check(not snapshot.is_empty(), "%s saturated source authority captures without omission" % mode)
		if snapshot.is_empty(): continue
		var packet_bytes := var_to_bytes(snapshot).size()
		check(packet_bytes <= Snapshot.MAX_RAW_BYTES, "%s saturated authority respects raw32768bytes" % mode)
		print("HEX WORLD PACKET: mode=%s bytes=%d actors=%d flights=%d casts=%d products=%d reserved=%d" % [mode, packet_bytes, world.players.size(), world.projectiles.size(), world.hex_court.casts.size(), world.hex_court.products.size(), world.hex_court.reserved_products()])
		var restored := Snapshot.prepare(snapshot, world)
		check(restored != null, "%s full-capacity packet restores" % mode)
		if restored != null: equal(restored.state_hash(), world.state_hash(), "%s full authority hash remains identical" % mode)


func _check_chemistry_outer_capture_equivalence(world: SimWorld, label: String) -> void:
	var public_snapshot := ChemistrySnapshot.capture(world.hex_court)
	var outer_snapshot := ChemistrySnapshot._capture_for_outer_roundtrip(world.hex_court)
	check(not public_snapshot.is_empty(), "%s public chemistry capture succeeds" % label)
	check(not outer_snapshot.is_empty(), "%s internal outer-roundtrip encoding succeeds" % label)
	if public_snapshot.is_empty() or outer_snapshot.is_empty():
		return
	check(outer_snapshot == public_snapshot, "%s internal encoding equals public capture dictionary" % label)
	equal(var_to_bytes(outer_snapshot), var_to_bytes(public_snapshot), "%s internal encoding preserves exact Variant bytes" % label)


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
