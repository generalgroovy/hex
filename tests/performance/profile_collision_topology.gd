# Historical p59-era benchmark with preserved pre-expansion snapshot oracles.
# Retained for history only: this script is not current-schema performance
# evidence for protocol60, schema5, or the expanded status/delivery lanes.
extends "res://tests/performance/profile_sealed_topology.gd"
@warning_ignore_start("integer_division")

const CollisionOracle = preload("res://tests/support/hex_collision_pre_e7.gd")
const SnapshotBefore = preload("res://tests/support/hex_world_snapshot_pre_e7e8.gd")
const COLLISION_ARMS: Array[String] = ["frozen", "candidate"]
const COLLISION_OPERATIONS: Array[String] = ["base_clone", "constructor", "first_admission", "warm_refresh"]
const AUTHORITY_OPERATIONS: Array[String] = ["chemistry_hash", "world_hash", "chemistry_encode", "chemistry_prepare", "wire_unpack", "hex_inflate", "hex_decompress", "hex_compress"]
const COMPLETE_OPERATIONS: Array[String] = ["world_capture", "world_prepare", "strict_wire_decode"]
const CASE_LABELS: Array[String] = ["empty", "distributed-paid40", "dense-paid40", "active-rampart"]
const RAMPART_STEP_LIMIT := 360
const QUERY_CELL_LIMIT := 3


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output_path = argument.trim_prefix("--output=")
	_check(output_path.begins_with("res://.godot/collision-topology-") and output_path.ends_with(".json") and not ".." in output_path and not FileAccess.file_exists(output_path), "collision topology receipt path is fresh and scoped")
	if failures > 0:
		quit(1)
		return
	var sources_before: Dictionary = _collision_sources()
	_check(_hashes_valid(sources_before), "complete collision profile dependencies hash before setup")
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "unchanged abilities load")
	_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "unchanged champions load")
	_check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "actual campus loads")
	definition = HexWorldDefinition.from_campus(layout)
	_check(definition != null and definition.eligible_cells.size() == EXPECTED_TOPOLOGY_CELLS, "exact current 11337-cell campus topology builds")
	if failures > 0:
		quit(1)
		return
	var records: Array[Dictionary] = []
	for index: int in CASE_LABELS.size():
		var record: Dictionary = _collision_case(CASE_LABELS[index], index)
		_check(_collision_case_complete(record, CASE_LABELS[index], index), "all collision and authority stages complete for " + CASE_LABELS[index])
		records.append(record)
	var complete: bool = _collision_records_complete(records)
	_check(complete, "all four bounded collision states complete")
	_collision_receipt_guards(records)
	var sources_after: Dictionary = _collision_sources()
	var unchanged: bool = _hashes_valid(sources_after) and sources_before == sources_after
	_check(unchanged, "all source hashes remain unchanged during profile")
	var receipt: Dictionary = {
		"schema_version": 1, "profile_version": "collision-topology-v1", "engine": Engine.get_version_info().get("string", ""),
		"seed": SEED, "map_hash": definition.map_hash, "definition_hash": definition.definition_hash,
		"topology_cells": EXPECTED_TOPOLOGY_CELLS, "sample_pairs": SAMPLE_PAIRS, "warmup_ticks": WARMUP_TICKS,
		"records": records, "receipt_complete": complete, "sources_unchanged": unchanged,
		"source_sha256_before": sources_before, "source_sha256_after": sources_after,
		"assertions": assertions, "failures": failures, "diagnostic_status": "PASS" if failures == 0 else "FAIL",
		"scope": "Actual 11337-cell campus and eight actual champions: empty, ordinary distributed/dense paid40, and a declared initial Earth Bolt loadout reaching active Rampart through one ordinary paid press and at most360 subsequent steps. Each authority has an independent legacy-storage replay twin for frozen snapshot/canonical compatibility checks. No products, paid matter, collision geometry or authority fields are injected.",
		"collision_baseline": "Both collision arms read the SAME unchanged SEALED authority and receive fresh ordinary HexCollisionWorld destinations. The frozen pre-E7 helper owns preceding configure/set logic; candidate calls current set_hex_surfaces. Base clone and constructor are identical current APIs in both arms and are stage-cost controls, not claimed implementation comparisons.",
		"collision_timing": "Three alternating, case-counterbalanced pairs. Each pair times base clone, constructor, first set_hex_surfaces, then one warm same-tick set_hex_surfaces on that destination. Timers exclude equality/query checks, source hashes, observers and returned-object disposal. First admission includes topology validation/index construction when the arm performs it; warm refresh reuses exactly that arm's first-admitted destination. Query work never runs between first admission and warm refresh.",
		"authority_timing": "Three current-API inclusive observations per named stage on the sealed source. Chemistry encode is _capture_for_outer_roundtrip; chemistry_prepare is complete strict _prepare. Wire unpack, envelope-only inflate, complete decompression and compression call existing production APIs without reconstructed validators. Inclusive timings overlap and MUST NOT be summed or subtracted as independent costs.",
		"complete_pair_timing": "Three alternating pairs on the SAME sealed source compare frozen E6 complete capture/public prepare with current complete operations, retaining preceding collision configuration through a frozen adapter. The separate strict_wire_decode pair compares current fused strict_decode against the preceding unchanged validate_structure followed by unpack. Snapshot equality and prepared authority/collision result checks run after timers. Shared primitive codecs are unchanged dependencies, not an independently reimplemented decoder.",
		"oracle_scope": "Frozen preceding full capture/prepare and independent original chemistry canonical bytes are evaluated only on the separately replayed legacy twin outside timers. Frozen collision methods compare complete topology/indices/sets/faces/components, insertion order, occluders and all fields of a bounded movement/sweep/LOS/contact query matrix. Frozen full snapshot orchestration still shares unchanged low-level codecs and current collision queries; this is explicitly supplemented by the separate frozen collision-state comparison.",
		"query_scope": "All eight actor-to-target paths plus canonical first three solid and first three cover cells, horizontal/vertical/diagonal/inside-escape paths, radii0/5000/18000, and all six face approaches for each selected solid. Full geometry/index structures are compared without truncation; queries are bounded samples, not exhaustive spatial proof.",
		"sampling_limit": "Three observations/pairs per stage and state; p95/p99 are sample-limited maxima. Setup and initial oracle work warm shared caches; no cold-process claim. Authority timings guide the next engineering slice but establish no capacity threshold.",
		"memory_semantics": "Process static/peak observations include both replay twins, oracle work, receipt data and caches; unavailable values are null. No arm-attributed allocation or memory-saving claim.",
		"performance_acceptance": "NOT_ESTABLISHED. No rendered, physical-network, full hosting lifecycle, 120Hz simulation, 60Hz envelopes, or16/32/64-player acceptance is established.",
	}
	var output: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	_check(output != null, "collision topology receipt opens")
	if output != null:
		receipt.assertions = assertions
		receipt.failures = failures
		receipt.diagnostic_status = "PASS" if failures == 0 else "FAIL"
		output.store_string(JSON.stringify(receipt, "\t") + "\n")
		output.close()
	print("%s: collision-topology; %d assertions; %d failures; output=%s" % ["PASS" if failures == 0 else "FAIL", assertions, failures, output_path])
	quit(1 if failures > 0 else 0)


func _collision_case(label: String, offset: int) -> Dictionary:
	print("COLLISION_TOPOLOGY fixture=%s" % label)
	var fixture: Dictionary = _collision_fixture(label)
	if fixture.is_empty(): return {}
	var sealed: SimWorld = fixture.worlds.sealed
	var legacy: SimWorld = fixture.worlds.legacy
	var topology: HexCellTopology = sealed.hex_court.immutable_topology()
	var before: String = sealed.state_hash()
	var before_base: PackedByteArray = var_to_bytes(_base_descriptor((sealed.collision as HexCollisionWorld).base_world))
	var frozen_bytes: PackedByteArray = FrozenHash.frozen_original_bytes(legacy.hex_court)
	_check(sealed.hex_court._state_hash_bytes() == frozen_bytes and legacy.hex_court._state_hash_bytes() == frozen_bytes, label + " original complete chemistry bytes match both representations")
	var expected: Dictionary = Legacy.capture(legacy)
	var detached: Dictionary = Legacy.chemistry_capture(legacy.hex_court)
	_check(not expected.is_empty() and not detached.is_empty(), label + " frozen preceding complete producers accept independently replayed legacy authority")
	if expected.is_empty() or detached.is_empty(): return {}
	var expected_bytes: PackedByteArray = var_to_bytes(expected)
	var restored: SimWorld = Legacy.prepare(expected, legacy)
	_check(restored != null and restored.state_hash() == before, label + " frozen full public preparation independently restores exact authority")
	var memory_before: Dictionary = _memory()
	var collision: Dictionary = _measure_collision(sealed, fixture.targets, offset)
	var authority: Dictionary = _measure_authority_stages(sealed, expected, detached, before)
	var complete_operations: Dictionary = _measure_complete_pairs(sealed, expected, detached, offset)
	var sources_unchanged: bool = sealed.state_hash() == before and legacy.state_hash() == before and sealed.hex_court.immutable_topology() == topology and legacy.hex_court.immutable_topology() == null
	var base_unchanged: bool = var_to_bytes(_base_descriptor((sealed.collision as HexCollisionWorld).base_world)) == before_base
	_check(sources_unchanged and base_unchanged, label + " all observers preserve sealed authority, legacy twin and immutable map")
	return {
		"completed": true, "case": label, "order_offset": offset, "tick": sealed.tick,
		"topology_cells": sealed.hex_court.cell_count(), "actors": sealed.players.size(), "paid_steps": fixture.paid_steps,
		"trace_sha256": fixture.trace_sha256, "state_hash": before, "chemistry_bytes_sha256": CanonicalBytes.sha256_hex(frozen_bytes),
		"snapshot_bytes_sha256": CanonicalBytes.sha256_hex(expected_bytes), "snapshot_bytes": expected_bytes.size(),
		"paid_metrics": sealed.hex_court.metrics.duplicate(true), "active_ramparts": _active_ramparts(sealed.hex_court, sealed.tick),
		"collision": collision, "authority": authority, "complete_operations": complete_operations, "sources_unchanged": sources_unchanged, "base_unchanged": base_unchanged,
		"memory_before": memory_before, "memory_after": _memory(),
	}


func _collision_fixture(label: String) -> Dictionary:
	var case_name: String = "sustained-distributed" if label == "distributed-paid40" else "dense-crucible"
	var worlds: Dictionary = {}
	var targets: Dictionary = {}
	for arm: String in ARMS:
		var fixture: Dictionary = _fixture(case_name)
		var world: SimWorld = fixture.world
		if label == "active-rampart":
			var earth: Dictionary = abilities.ability(abilities.spell_id_at("earth", "bolt"))
			var wire: int = int(earth.get("wire_id", 0))
			for actor: PlayerState in world.players:
				_check(wire > 0 and actor.place_proven_spell(0, wire) and actor.has_valid_spell_slots(), "Rampart fixture equips a legal initial Earth Bolt slot")
		if arm == "legacy":
			var borrowed: Dictionary = world.hex_court.cells
			_check(borrowed.size() == EXPECTED_TOPOLOGY_CELLS, "only legacy replay twin materializes compatibility storage")
		worlds[arm] = world
		targets[arm] = fixture.targets
	_check(targets.legacy == targets.sealed and _storage_modes_valid(worlds), "independent twins start with matching targets and intended storage modes")
	for unused: int in WARMUP_TICKS:
		for arm: String in ARMS:
			var world: SimWorld = worlds[arm]
			_check(world.step(_commands(world, targets[arm], case_name, false, false)), "neutral warmup advances")
	var legacy: SimWorld = worlds.legacy
	var sealed: SimWorld = worlds.sealed
	var trace: HashingContext = HashingContext.new()
	trace.start(HashingContext.HASH_SHA256)
	var steps: int = 0
	var limit: int = 0 if label == "empty" else RAMPART_STEP_LIMIT if label == "active-rampart" else 40
	for index: int in limit:
		for arm: String in _order(index):
			var world: SimWorld = worlds[arm]
			var active: bool = label != "active-rampart" or index == 0
			_check(world.step(_commands(world, targets[arm], case_name, active, false)), "ordinary paid input and subsequent lifecycle advance")
		steps += 1
		var state_hash: String = legacy.state_hash()
		_check(sealed.state_hash() == state_hash and sealed.combat_events == legacy.combat_events, "each paid/lifecycle step preserves twin full hashes and events")
		trace.update((state_hash + JSON.stringify(FrozenHash._stable_original(legacy.combat_events))).to_utf8_buffer())
		if label == "active-rampart" and _active_ramparts(sealed.hex_court, sealed.tick) > 0: break
	_check(legacy.state_hash() == sealed.state_hash() and _storage_modes_valid(worlds), "prepared fixture matches complete authority without candidate detachment")
	_check(sealed.hex_court.conservation_valid() and legacy.hex_court.conservation_valid(), "both replay representations conserve paid matter")
	_check(_alive_count(sealed) == 8 and _alive_count(legacy) == 8, "all actual champions remain alive without refill")
	if label != "empty": _check(int(sealed.hex_court.metrics.admitted) > 0 and int(sealed.hex_court.metrics.matter_paid) > 0, "nonempty fixture contains positive ordinary paid admissions")
	if label == "active-rampart":
		_check(_active_ramparts(sealed.hex_court, sealed.tick) > 0, "ordinary Earth Bolt inputs reach active Rampart within the fixed step bound")
		if _active_ramparts(sealed.hex_court, sealed.tick) == 0: return {}
	return {"worlds": worlds, "targets": targets.sealed, "paid_steps": steps, "trace_sha256": trace.finish().hex_encode()}


func _active_ramparts(court: HexChemistryWorld, tick: int) -> int:
	var count: int = 0
	for product: Dictionary in court.products.values():
		if int(product.recipe_wire_id) == 301 and int(product.health) > 0 and tick >= int(product.active_tick) and tick < int(product.decay_tick): count += 1
	return count


func _measure_collision(source: SimWorld, targets: Dictionary, offset: int) -> Dictionary:
	var observations: Dictionary = {}
	for operation: String in COLLISION_OPERATIONS:
		observations[operation] = {"frozen": PackedInt64Array(), "candidate": PackedInt64Array(), "pairs": []}
	var geometry_hash: String = ""
	var query_hash: String = ""
	var query_count: int = 0
	var face_count: int = 0
	var solid_count: int = 0
	var cover_count: int = 0
	for pair_index: int in SAMPLE_PAIRS:
		var destinations: Dictionary = {}
		var first_descriptors: Dictionary = {}
		var order: Array[String] = _collision_order(pair_index + offset)
		var rows: Dictionary = {}
		for operation: String in COLLISION_OPERATIONS:
			rows[operation] = {"pair": pair_index, "order": order.duplicate(), "samples_us": {}}
		for arm: String in order:
			var started: int = Time.get_ticks_usec()
			var base: CollisionWorld = HexWorldSnapshot._clone_base_collision(source.collision)
			var elapsed: int = Time.get_ticks_usec() - started
			_collision_sample(observations, rows, "base_clone", arm, elapsed)
			_check(base != null, "fresh collision base clone succeeds")
			started = Time.get_ticks_usec()
			var destination: HexCollisionWorld = HexCollisionWorld.new(base)
			elapsed = Time.get_ticks_usec() - started
			_collision_sample(observations, rows, "constructor", arm, elapsed)
			destinations[arm] = destination
			started = Time.get_ticks_usec()
			var admitted: bool = CollisionOracle.set_hex_surfaces(destination, source.hex_court, source.tick) if arm == "frozen" else destination.set_hex_surfaces(source.hex_court, source.tick)
			elapsed = Time.get_ticks_usec() - started
			_collision_sample(observations, rows, "first_admission", arm, elapsed)
			_check(admitted, "fresh " + arm + " collision topology admission succeeds")
			first_descriptors[arm] = _collision_descriptor(destination)
			started = Time.get_ticks_usec()
			var refreshed: bool = CollisionOracle.set_hex_surfaces(destination, source.hex_court, source.tick) if arm == "frozen" else destination.set_hex_surfaces(source.hex_court, source.tick)
			elapsed = Time.get_ticks_usec() - started
			_collision_sample(observations, rows, "warm_refresh", arm, elapsed)
			_check(refreshed, "warm " + arm + " same-state collision refresh succeeds")
		for operation: String in COLLISION_OPERATIONS:
			observations[operation].pairs.append(rows[operation])
		var frozen: HexCollisionWorld = destinations.frozen
		var candidate: HexCollisionWorld = destinations.candidate
		var expected: Dictionary = _collision_descriptor(frozen)
		_check(first_descriptors.frozen == first_descriptors.candidate and first_descriptors.frozen == expected, "first admission is exact before warm refresh and warm refresh preserves it")
		_check(_collision_descriptor(candidate) == expected, "full topology, indices, ordered sets, faces, components and base geometry match frozen collision")
		_check(candidate._topology.is_read_only() and candidate._indices.is_read_only() and not frozen._topology.is_read_only() and not frozen._indices.is_read_only(), "fresh candidate shares read-only admitted topology while frozen baseline builds writable indices")
		_check(frozen._chemistry == source.hex_court and candidate._chemistry == source.hex_court, "both collision arms bind the same sealed source")
		var queries: Array[Dictionary] = _collision_queries(source, targets, frozen)
		var expected_queries: Array = _collision_query_results(frozen, queries)
		var actual_queries: Array = _collision_query_results(candidate, queries)
		_check(actual_queries == expected_queries and var_to_bytes(actual_queries) == var_to_bytes(expected_queries), "every bounded movement, sweep, LOS and face result matches exactly")
		var current_geometry_hash: String = CanonicalBytes.sha256_hex(var_to_bytes(expected))
		var current_query_hash: String = CanonicalBytes.sha256_hex(var_to_bytes(expected_queries))
		if pair_index > 0:
			_check(geometry_hash == current_geometry_hash and query_hash == current_query_hash, "fresh destination repetitions preserve identical geometry and query outputs")
		geometry_hash = current_geometry_hash
		query_hash = current_query_hash
		query_count = queries.size()
		face_count = frozen._faces.size()
		solid_count = frozen._solid.size()
		cover_count = frozen._cover.size()
		_check(source.hex_court.immutable_topology() != null, "collision oracle and candidate never materialize sealed source")
	var stages: Dictionary = {}
	for operation: String in COLLISION_OPERATIONS:
		stages[operation] = {"pairs": observations[operation].pairs, "frozen": _stats(observations[operation].frozen), "candidate": _stats(observations[operation].candidate)}
		print("COLLISION_STAGE %s frozen_p50_us=%d candidate_p50_us=%d" % [operation, stages[operation].frozen.statistics_us.p50, stages[operation].candidate.statistics_us.p50])
	return {"stages": stages, "geometry_sha256": geometry_hash, "query_sha256": query_hash, "query_count": query_count, "faces": face_count, "solid_cells": solid_count, "cover_cells": cover_count}


func _collision_sample(observations: Dictionary, rows: Dictionary, operation: String, arm: String, elapsed: int) -> void:
	var samples: PackedInt64Array = observations[operation][arm]
	samples.append(elapsed)
	observations[operation][arm] = samples
	rows[operation].samples_us[arm] = elapsed


func _collision_order(index: int) -> Array[String]:
	var result: Array[String] = []
	result.assign(["frozen", "candidate"] if index % 2 == 0 else ["candidate", "frozen"])
	return result


func _base_descriptor(base: CollisionWorld) -> Dictionary:
	var obstacles: Array = []
	for obstacle: CollisionWorld.Obstacle in base.obstacle_view():
		obstacles.append([obstacle.obstacle_id, obstacle.minimum_x, obstacle.minimum_y, obstacle.maximum_x, obstacle.maximum_y, obstacle.vaultable, obstacle.wall_runnable])
	return {"width": base.width, "height": base.height, "obstacles": obstacles}


func _collision_descriptor(world: HexCollisionWorld) -> Dictionary:
	var result: Dictionary = {"origin": world.grid_origin, "base": _base_descriptor(world.base_world), "occluders": world.hex_occluders()}
	for key: String in ["_topology", "_indices", "_solid", "_cover", "_faces", "_components", "_solid_ordered", "_cover_ordered", "_actor_ignored"]:
		var value: Variant = world.get(key)
		result[key] = value.duplicate(true)
		if value is Dictionary: result[key + "_key_order"] = value.keys()
	return result


func _collision_queries(source: SimWorld, targets: Dictionary, collision: HexCollisionWorld) -> Array[Dictionary]:
	var queries: Array[Dictionary] = []
	for actor: PlayerState in source.players:
		queries.append({"start": Vector2i(actor.position_x, actor.position_y), "finish": targets[actor.entity_id], "radius": MovementTuning.PLAYER_RADIUS})
	var cells: Array = []
	for values: Array in [collision._solid_ordered, collision._cover_ordered]:
		for index: int in mini(QUERY_CELL_LIMIT, values.size()):
			if values[index] not in cells: cells.append(values[index])
	for cell: Vector2i in cells:
		var center: Vector2i = source.hex_court.origin + HexGrid.center(cell)
		for radius: int in [0, 5_000, MovementTuning.PLAYER_RADIUS]:
			for delta: Vector2i in [Vector2i(100_000, 0), Vector2i(0, 100_000), Vector2i(120_000, 80_000)]:
				queries.append({"start": center - delta, "finish": center + delta, "radius": radius})
			queries.append({"start": center, "finish": center + Vector2i(160_000, 0), "radius": radius})
		if collision._solid.has(cell):
			var polygon: Array = HexConvexGeometry.polygon(cell, source.hex_court.origin)
			for face: int in 6:
				var midpoint: Vector2i = Vector2i((polygon[face].x + polygon[(face + 1) % 6].x) / 2, (polygon[face].y + polygon[(face + 1) % 6].y) / 2)
				var normal: Vector2i = HexConvexGeometry.NORMALS[face]
				queries.append({"start": midpoint + normal * 100, "finish": midpoint - normal * 100, "radius": MovementTuning.PLAYER_RADIUS})
	return queries


func _collision_query_results(world: HexCollisionWorld, queries: Array[Dictionary]) -> Array:
	var results: Array = []
	for query: Dictionary in queries:
		var start: Vector2i = query.start
		var finish: Vector2i = query.finish
		var radius: int = query.radius
		world.begin_actor(start, radius)
		var moved: CollisionWorld.MoveResult = world.move_box(start, finish - start, radius)
		results.append({
			"move": [moved.position, moved.wall_normal, moved.wall_id, moved.blocking_normals.duplicate()],
			"actor_ignored": world._actor_ignored.duplicate(), "occupancy": [world.can_occupy(start, radius), world.can_occupy(finish, radius)],
			"sweep": world.hex_wall_contact(start, finish, radius), "segment_clear": world.hex_segment_clear(start, finish),
			"pillar_clear": world.hex_pillar_segment_clear(start, finish), "nearby_face": world.nearby_hex_face(start, radius, 4),
			"live_surface": world.has_live_surface(moved.wall_id),
		})
	return results


func _measure_authority_stages(world: SimWorld, expected: Dictionary, detached: Dictionary, expected_hash: String) -> Dictionary:
	var result: Dictionary = {}
	var court: HexChemistryWorld = world.hex_court
	var chemistry_hash: String = String(detached.authority_hash)
	var packed: Dictionary = HexSnapshotWirePacking.pack(detached, court.cell_count())
	_check(not packed.is_empty(), "frozen detached chemistry packs with current unmodified wire API")
	for operation: String in AUTHORITY_OPERATIONS:
		var samples: PackedInt64Array = PackedInt64Array()
		for unused: int in SAMPLE_PAIRS:
			var started: int = Time.get_ticks_usec()
			var value: Variant
			match operation:
				"chemistry_hash": value = court.state_hash()
				"world_hash": value = world.state_hash()
				"chemistry_encode": value = HexChemistrySnapshot._capture_for_outer_roundtrip(court)
				"chemistry_prepare": value = HexChemistrySnapshot._prepare(detached, court)
				"wire_unpack": value = HexSnapshotWirePacking.unpack(packed, court.cell_count())
				"hex_inflate": value = HexWorldSnapshot._inflate_hex(expected.hex)
				"hex_decompress": value = HexWorldSnapshot._decompress_hex(expected.hex, court.cell_count())
				"hex_compress": value = HexWorldSnapshot._compress_hex(packed)
			var elapsed: int = Time.get_ticks_usec() - started
			samples.append(elapsed)
			match operation:
				"chemistry_hash": _check(value == chemistry_hash, "timed complete chemistry hash is exact")
				"world_hash": _check(value == expected_hash, "timed complete world hash is exact")
				"chemistry_encode", "wire_unpack": _check(value == detached and var_to_bytes(value) == var_to_bytes(detached), "timed detached chemistry/wire stage is exact")
				"chemistry_prepare": _check(value != null and value.state_hash() == chemistry_hash and value.immutable_topology() == court.immutable_topology(), "timed strict chemistry preparation restores exact authority and shares only topology")
				"hex_inflate", "hex_decompress": _check(value == packed and var_to_bytes(value) == var_to_bytes(packed), "timed envelope inflate or complete decompression/validation is exact")
				"hex_compress": _check(value == expected.hex and var_to_bytes(value) == var_to_bytes(expected.hex), "timed complete compression/validation is exact")
		result[operation] = _stats(samples)
		print("AUTHORITY_STAGE %s p50_us=%d max_us=%d" % [operation, result[operation].statistics_us.p50, result[operation].statistics_us.max])
	return result


func _measure_complete_pairs(world: SimWorld, expected: Dictionary, detached: Dictionary, offset: int) -> Dictionary:
	var result: Dictionary = {}
	var expected_bytes: PackedByteArray = var_to_bytes(expected)
	var expected_hash: String = String(expected.state_hash)
	var packed: Dictionary = HexSnapshotWirePacking.pack(detached, world.hex_court.cell_count())
	for operation: String in COMPLETE_OPERATIONS:
		var samples: Dictionary = {"frozen": PackedInt64Array(), "candidate": PackedInt64Array()}
		var pairs: Array[Dictionary] = []
		for index: int in SAMPLE_PAIRS:
			var order: Array[String] = _collision_order(index + offset)
			var row: Dictionary = {"pair": index, "order": order.duplicate(), "samples_us": {}}
			var geometries: Dictionary = {}
			for arm: String in order:
				var value: Variant
				var started: int = Time.get_ticks_usec()
				match operation:
					"world_capture":
						value = SnapshotBefore.capture(world) if arm == "frozen" else HexWorldSnapshot.capture(world)
					"world_prepare":
						value = SnapshotBefore.prepare(expected, world) if arm == "frozen" else HexWorldSnapshot.prepare(expected, world)
					"strict_wire_decode":
						if arm == "candidate":
							value = HexSnapshotWirePacking.strict_decode(packed, world.hex_court.cell_count())
						else:
							value = HexSnapshotWirePacking.unpack(packed, world.hex_court.cell_count()) if HexSnapshotWirePacking.validate_structure(packed, world.hex_court.cell_count()) else {}
				var elapsed: int = Time.get_ticks_usec() - started
				var values: PackedInt64Array = samples[arm]
				values.append(elapsed)
				samples[arm] = values
				row.samples_us[arm] = elapsed
				match operation:
					"world_capture":
						_check(value == expected and var_to_bytes(value) == expected_bytes, "paired " + arm + " complete capture equals frozen original full wire bytes")
					"world_prepare":
						var valid: bool = value != null and value.state_hash() == expected_hash and value.hex_court.immutable_topology() == world.hex_court.immutable_topology()
						_check(valid, "paired " + arm + " complete public preparation reconstructs exact authority and topology identity")
						if valid: geometries[arm] = _collision_descriptor(value.collision as HexCollisionWorld)
					"strict_wire_decode":
						_check(value == detached and var_to_bytes(value) == var_to_bytes(detached), "paired " + arm + " strict wire decode preserves every typed detached lane")
			if operation == "world_prepare":
				_check(geometries.size() == 2 and geometries.get("frozen") == geometries.get("candidate"), "paired complete prepares preserve exact collision geometry and insertion order")
			pairs.append(row)
		result[operation] = {"pairs": pairs, "frozen": _stats(samples.frozen), "candidate": _stats(samples.candidate)}
		print("COMPLETE_STAGE %s frozen_p50_us=%d candidate_p50_us=%d" % [operation, result[operation].frozen.statistics_us.p50, result[operation].candidate.statistics_us.p50])
	return result


func _collision_records_complete(records: Array[Dictionary]) -> bool:
	if records.size() != CASE_LABELS.size(): return false
	for index: int in CASE_LABELS.size():
		if not _collision_case_complete(records[index], CASE_LABELS[index], index): return false
	return true


func _collision_case_complete(value: Dictionary, label: String, offset: int) -> bool:
	if value.get("completed") != true or value.get("case") != label or value.get("order_offset") != offset: return false
	if value.get("topology_cells") != EXPECTED_TOPOLOGY_CELLS or value.get("actors") != 8 or value.get("sources_unchanged") != true or value.get("base_unchanged") != true: return false
	var steps: Variant = value.get("paid_steps")
	if typeof(steps) != TYPE_INT or steps < 0 or value.get("tick") != WARMUP_TICKS + steps: return false
	if label == "empty" and steps != 0: return false
	if label in ["distributed-paid40", "dense-paid40"] and steps != 40: return false
	if label == "active-rampart" and (steps < 1 or steps > RAMPART_STEP_LIMIT or value.get("active_ramparts", 0) <= 0): return false
	for key: String in ["trace_sha256", "state_hash", "chemistry_bytes_sha256", "snapshot_bytes_sha256"]:
		if not _hash_valid(value.get(key)): return false
	if value.get("snapshot_bytes", 0) <= 0: return false
	var metrics: Variant = value.get("paid_metrics")
	if not metrics is Dictionary: return false
	if label != "empty" and (metrics.get("admitted", 0) <= 0 or metrics.get("matter_paid", 0) <= 0): return false
	var collision: Variant = value.get("collision")
	if not collision is Dictionary or not _hash_valid(collision.get("geometry_sha256")) or not _hash_valid(collision.get("query_sha256")) or collision.get("query_count", 0) < 8: return false
	if label == "active-rampart" and (collision.get("faces", 0) <= 0 or collision.get("solid_cells", 0) <= 0): return false
	var stages: Variant = collision.get("stages")
	if not stages is Dictionary or stages.size() != COLLISION_OPERATIONS.size(): return false
	for operation: String in COLLISION_OPERATIONS:
		if not _collision_operation_complete(stages.get(operation), offset): return false
	var authority: Variant = value.get("authority")
	if not authority is Dictionary or authority.size() != AUTHORITY_OPERATIONS.size(): return false
	for operation: String in AUTHORITY_OPERATIONS:
		if not _single_stage_complete(authority.get(operation)): return false
	var complete_operations: Variant = value.get("complete_operations")
	if not complete_operations is Dictionary or complete_operations.size() != COMPLETE_OPERATIONS.size(): return false
	for operation: String in COMPLETE_OPERATIONS:
		if not _collision_operation_complete(complete_operations.get(operation), offset): return false
	return true


func _single_stage_complete(value: Variant) -> bool:
	if not value is Dictionary or not value.get("samples_us") is Array or value.samples_us.size() != SAMPLE_PAIRS: return false
	for sample: Variant in value.samples_us:
		if typeof(sample) != TYPE_INT or sample < 0: return false
	return value.get("statistics_us") == _percentiles(PackedInt64Array(value.samples_us))


func _collision_operation_complete(value: Variant, offset: int) -> bool:
	if not value is Dictionary: return false
	for arm: String in COLLISION_ARMS:
		if not _single_stage_complete(value.get(arm)): return false
	var pairs: Variant = value.get("pairs")
	if not pairs is Array or pairs.size() != SAMPLE_PAIRS: return false
	for index: int in SAMPLE_PAIRS:
		var row: Variant = pairs[index]
		if not row is Dictionary or row.get("pair") != index or row.get("order") != _collision_order(index + offset): return false
		if not row.get("samples_us") is Dictionary or row.samples_us.size() != 2: return false
		for arm: String in COLLISION_ARMS:
			if row.samples_us.get(arm, -1) != value[arm].samples_us[index]: return false
	return true


func _collision_receipt_guards(records: Array[Dictionary]) -> void:
	if not _collision_records_complete(records): return
	var broken: Array[Dictionary] = records.duplicate(true)
	broken.pop_back()
	_check(not _collision_records_complete(broken), "collision receipt refuses missing active case")
	broken = records.duplicate(true)
	broken[0].collision.stages.first_admission.candidate.samples_us.pop_back()
	_check(not _collision_records_complete(broken), "collision receipt refuses missing paired sample")
	broken = records.duplicate(true)
	broken[0].collision.stages.warm_refresh.pairs[0].order.reverse()
	_check(not _collision_records_complete(broken), "collision receipt refuses incorrect arm order")
	broken = records.duplicate(true)
	broken[0].complete_operations.erase("world_prepare")
	_check(not _collision_records_complete(broken), "collision receipt refuses missing complete incoming preparation stage")
	broken = records.duplicate(true)
	broken[3].active_ramparts = 0
	_check(not _collision_records_complete(broken), "collision receipt refuses empty substitute for active Rampart")
	broken = records.duplicate(true)
	broken[0].sources_unchanged = false
	_check(not _collision_records_complete(broken), "collision receipt refuses source mutation or candidate detachment")


func _collision_sources() -> Dictionary:
	var result: Dictionary = _sealed_sources()
	for path: String in ["tests/performance/profile_collision_topology.gd", "tests/support/hex_collision_pre_e7.gd", "tests/support/hex_world_snapshot_pre_e7e8.gd"]:
		result[path] = FileAccess.get_sha256("res://" + path)
	return result
