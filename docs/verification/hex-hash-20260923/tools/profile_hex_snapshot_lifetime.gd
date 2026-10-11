extends "res://tests/performance/profile_unified_wellspring.gd"
@warning_ignore_start("integer_division")

# Isolated repeat diagnostic for the source-backed Hex snapshot replacement
# boundary. It does not run sockets, the application scheduler, or a lifecycle.
const ITERATIONS := 32
const ACTIVE_WORKLOAD_TICKS := 40
const EXPECTED_TOPOLOGY_CELLS := 2_766
const EXPECTED_ACTIVE_CELLS := 29
const EXPECTED_STORED_MATERIAL_CELLS := 49
const LOCAL_ENTITY_ID := 2

var iterations_completed := 0


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	_check(
		output_path.begins_with("res://.godot/hex-snapshot-lifetime-")
			and output_path.ends_with(".json")
			and not ".." in output_path
			and not FileAccess.file_exists(output_path),
		"lifetime receipt path is fresh and scoped",
	)
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "production ability catalogue loads")
	_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "production champion catalogue loads")
	_check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "normal Wellspring campus loads")
	definition = HexWorldDefinition.from_campus(layout)
	_check(definition != null and definition.eligible_cells.size() == EXPECTED_TOPOLOGY_CELLS, "lifetime profile uses the genuine 2,766-cell campus topology")
	if failures > 0:
		_finish({})
		return

	var fixture: Dictionary = _fixture("dense-crucible")
	var template: SimWorld = fixture.world
	var targets: Dictionary = fixture.targets
	for unused: int in range(WARMUP_TICKS):
		_check(template.step(_commands(template, targets, "dense-crucible", false, false)), "neutral warmup advances")
	for unused: int in range(ACTIVE_WORKLOAD_TICKS):
		_check(template.step(_commands(template, targets, "dense-crucible", true, false)), "authored paid workload advances")
	var court: HexChemistryWorld = template.hex_court
	var occupancy: Dictionary = _occupancy(court, template.tick)
	_check(template.players.size() == 8, "lifetime fixture retains eight production champion actors")
	_check(court.cells.size() == EXPECTED_TOPOLOGY_CELLS, "lifetime fixture retains the exact campus topology")
	_check(int(court.metrics.admitted) == 8 and int(court.metrics.matter_paid) == 4_800, "lifetime fixture retains eight legal paid admissions")
	_check(int(occupancy.active_cells) == EXPECTED_ACTIVE_CELLS, "lifetime fixture retains exactly 29 active cells")
	_check(_nonempty_material_cells(court) == EXPECTED_STORED_MATERIAL_CELLS, "lifetime fixture retains exactly 49 stored material-cell records")
	_check(court.conservation_valid(), "lifetime fixture conserves paid matter")
	if failures > 0:
		_finish({})
		return

	var expected_world_hash: String = template.state_hash()
	var expected_hex_hash: String = court.state_hash()
	var baseline_snapshot: Dictionary = HexWorldSnapshot.capture(template)
	var baseline_bytes: PackedByteArray = var_to_bytes(baseline_snapshot)
	_check(expected_world_hash.length() == 64 and expected_hex_hash.length() == 64, "frozen source hashes are complete")
	_check(not baseline_snapshot.is_empty() and not baseline_bytes.is_empty(), "baseline actual world capture is populated")
	_check(String(baseline_snapshot.get("state_hash", "")) == expected_world_hash, "baseline snapshot names the exact frozen source hash")
	if failures > 0:
		_finish({})
		return

	var memory_start: Dictionary = _memory_observation()
	var lifetime: Dictionary = _measure_lifetime(template, baseline_snapshot, baseline_bytes, expected_world_hash, expected_hex_hash)
	_check(iterations_completed == ITERATIONS, "all %d replacement iterations complete" % ITERATIONS)
	_check(_lifetime_result_complete(lifetime), "lifetime result contains every timing, memory, ownership, and release sample")
	_check(template.state_hash() == expected_world_hash and court.state_hash() == expected_hex_hash, "all lifetime iterations leave the frozen paid source unchanged")
	if failures > 0:
		_finish({})
		return

	var receipt: Dictionary = {
		"schema_version": 1,
		"profile_version": "hex-snapshot-lifetime-v1",
		"workload_version": "unified-wellspring-profile-v1/dense-crucible-first-40",
		"engine": Engine.get_version_info().get("string", ""),
		"seed": SEED,
		"warmup_ticks": WARMUP_TICKS,
		"active_workload_ticks": ACTIVE_WORKLOAD_TICKS,
		"iterations": ITERATIONS,
		"iterations_completed": iterations_completed,
		"topology_cells": court.cells.size(),
		"world_tick": template.tick,
		"authority_hash": expected_world_hash,
		"hex_authority_hash": expected_hex_hash,
		"snapshot_wire_bytes": HexWorldSnapshot.byte_size(baseline_snapshot),
		"snapshot_variant_bytes": baseline_bytes.size(),
		"workload": {
			"actors": template.players.size(),
			"metrics": court.metrics.duplicate(true),
			"occupancy": occupancy.duplicate(true),
			"stored_material_cells": _nonempty_material_cells(court),
		},
		"lifetime": lifetime,
		"process_memory_bytes": {
			"start": memory_start,
			"end": _memory_observation(),
		},
		"source_sha256": _source_hashes(),
		"assertions": assertions,
		"failures": failures,
		"scope": "Single-process isolated repeat diagnostic of actual HexWorldSnapshot.capture/prepare and ClientPrediction.bind_hex_world calls on one unchanged legal 2,766-cell, eight-actor, 29-active/49-stored authority. The frozen source also serves as the trusted template, so host capture and client-style replacement are intentionally combined in one process; memory levels are not a role-separated network heap. It is not the application scheduler, actual 60 Hz snapshot cadence, sockets, the 300-second network lifecycle, rendered performance, multiplayer capacity, allocation attribution, or acceptance.",
		"retention_limit": "Known retained cardinalities describe only the explicitly held template/source, current replica, and current prediction authority. Weak references cover only explicitly tracked prepared/replaced replicas and prediction authorities. Capture's internal validation candidate is not exposed for weak tracking. Static-memory changes or slopes do not prove a leak, liveness, reachability, allocator retention, or cause.",
		"memory_reporting": "Every memory observation calls OS.get_static_memory_usage and OS.get_static_memory_peak_usage outside timers. A nonpositive value is reported as null with the matching availability flag false; it is not presented as zero measured usage. Replacement follows production order: install the prepared replica and verify the superseded replica releases before prediction bind; then bind and verify the superseded prediction authority releases. after_helper_scope additionally observes release of call-local snapshot/byte/weak-reference structures. The retained baseline snapshot/byte buffer and growing 32-row receipt arrays are diagnostic observer overhead included in static memory.",
		"timing_semantics": "Each inclusive stage timer surrounds one complete named production call. Equality, byte/hash/ownership checks, weak-release checks, memory sampling, fixture work, and the one reversible independence mutation are outside stage timers. Every iteration captures and reconstructs the same frozen legally admitted source; no fictitious paid admissions are added.",
	}
	_finish(receipt)


func _measure_lifetime(template: SimWorld, baseline_snapshot: Dictionary, baseline_bytes: PackedByteArray, expected_world_hash: String, expected_hex_hash: String) -> Dictionary:
	var prediction := ClientPrediction.new()
	_check(prediction.configure(template.config, template.collision, LOCAL_ENTITY_ID), "persistent prediction context configures once outside timers")
	if prediction.local_entity_id != LOCAL_ENTITY_ID:
		return {}

	var capture_times := PackedInt64Array()
	var prepare_times := PackedInt64Array()
	var bind_times := PackedInt64Array()
	var rows: Array[Dictionary] = []
	# This is the only strong holder for the current replica. The iteration helper
	# replaces it before prediction bind, matching Bootstrap's world assignment.
	var current := {"replica": null}

	for iteration: int in ITERATIONS:
		var row: Dictionary = _replacement_iteration(
			template, baseline_snapshot, baseline_bytes, current, prediction,
			expected_world_hash, expected_hex_hash, iteration,
		)
		_check(not row.is_empty(), "replacement iteration %d returns a complete scoped result" % iteration)
		if row.is_empty():
			break
		row.memory["after_helper_scope"] = _memory_observation()
		rows.append(row)
		capture_times.append(int(row.inclusive_us.capture))
		prepare_times.append(int(row.inclusive_us.prepare))
		bind_times.append(int(row.inclusive_us.prediction_bind))
		iterations_completed += 1

	var final_replica_id: int = current.replica.get_instance_id() if current.replica != null else 0
	var final_replica_hex_id: int = current.replica.hex_court.get_instance_id() if current.replica != null and current.replica.hex_court != null else 0
	var final_prediction_hex_id := prediction.hex_authority.get_instance_id() if prediction.hex_authority != null else 0
	var final_replica_weak: WeakRef = weakref(current.replica) if current.replica != null else null
	var final_replica_hex_weak: WeakRef = weakref(current.replica.hex_court) if current.replica != null and current.replica.hex_court != null else null
	var final_prediction_hex_weak: WeakRef = weakref(prediction.hex_authority) if prediction.hex_authority != null else null
	current.replica = null
	prediction.reset()
	var final_release := {
		"replica_id": final_replica_id,
		"replica_hex_id": final_replica_hex_id,
		"prediction_hex_id": final_prediction_hex_id,
		"replica_released": _weak_released(final_replica_weak),
		"replica_hex_released": _weak_released(final_replica_hex_weak),
		"prediction_hex_released": _weak_released(final_prediction_hex_weak),
		"memory_after_release": _memory_observation(),
	}
	_check(bool(final_release.replica_released), "final tracked replica releases after the scoped current reference clears")
	_check(bool(final_release.replica_hex_released), "final tracked replica authority releases after the scoped current reference clears")
	_check(bool(final_release.prediction_hex_released), "final tracked prediction authority releases after reset")

	return {
		"rows": rows,
		"inclusive_stage_us": {
			"capture": _timing_result(capture_times),
			"prepare": _timing_result(prepare_times),
			"prediction_bind": _timing_result(bind_times),
		},
		"known_retained_topology_fields": {
			"names": ["template", "current_replica", "current_prediction_authority"],
			"expected_each_cells": EXPECTED_TOPOLOGY_CELLS,
			"count": 3,
			"claim_limit": "These three named fields are not a count of all live or unreachable worlds.",
		},
		"final_tracked_release": final_release,
	}


func _replacement_iteration(template: SimWorld, baseline_snapshot: Dictionary, baseline_bytes: PackedByteArray, current: Dictionary, prediction: ClientPrediction, expected_world_hash: String, expected_hex_hash: String, iteration: int) -> Dictionary:
	var previous_replica_id: int = current.replica.get_instance_id() if current.replica != null else 0
	var previous_replica_hex_id: int = current.replica.hex_court.get_instance_id() if current.replica != null and current.replica.hex_court != null else 0
	var previous_prediction_hex_id := prediction.hex_authority.get_instance_id() if prediction.hex_authority != null else 0
	var previous_replica_weak: WeakRef = weakref(current.replica) if current.replica != null else null
	var previous_replica_hex_weak: WeakRef = weakref(current.replica.hex_court) if current.replica != null and current.replica.hex_court != null else null
	var previous_prediction_hex_weak: WeakRef = weakref(prediction.hex_authority) if prediction.hex_authority != null else null

	var memory_before: Dictionary = _memory_observation()
	var capture_started := Time.get_ticks_usec()
	var snapshot: Dictionary = HexWorldSnapshot.capture(template)
	var capture_us := Time.get_ticks_usec() - capture_started
	var memory_after_capture: Dictionary = _memory_observation()
	if snapshot.is_empty():
		_check(false, "iteration %d actual world capture succeeds" % iteration)
		return {}
	var snapshot_bytes: PackedByteArray = var_to_bytes(snapshot)
	_check(snapshot == baseline_snapshot and snapshot_bytes == baseline_bytes, "iteration %d actual capture preserves exact Variant bytes" % iteration)
	_check(String(snapshot.get("state_hash", "")) == expected_world_hash, "iteration %d actual capture preserves the frozen authority hash" % iteration)

	var prepare_started := Time.get_ticks_usec()
	var prepared: SimWorld = HexWorldSnapshot.prepare(snapshot, template)
	var prepare_us := Time.get_ticks_usec() - prepare_started
	var memory_after_prepare: Dictionary = _memory_observation()
	if prepared == null:
		_check(false, "iteration %d actual world prepare succeeds" % iteration)
		return {}
	_check(prepared != template and prepared.hex_court != template.hex_court, "iteration %d prepared replica owns an independent topology authority" % iteration)
	_check(prepared.state_hash() == expected_world_hash and prepared.hex_court.state_hash() == expected_hex_hash, "iteration %d prepared replica preserves exact world and Hex hashes" % iteration)

	# Bootstrap assigns world = candidate before binding prediction. The holder is
	# the sole old-replica owner, so this assignment exposes that exact boundary.
	current.replica = prepared
	var previous_replica_released := _weak_released(previous_replica_weak)
	var previous_replica_hex_released := _weak_released(previous_replica_hex_weak)
	_check(previous_replica_released, "iteration %d superseded tracked replica releases before prediction bind" % iteration)
	_check(previous_replica_hex_released, "iteration %d superseded tracked replica authority releases before prediction bind" % iteration)
	var memory_after_replica_replace: Dictionary = _memory_observation()

	var bind_started := Time.get_ticks_usec()
	var bound := prediction.bind_hex_world(prepared)
	var bind_us := Time.get_ticks_usec() - bind_started
	var memory_after_bind: Dictionary = _memory_observation()
	if not bound or prediction.hex_authority == null:
		_check(false, "iteration %d actual prediction bind succeeds" % iteration)
		return {}
	var previous_prediction_hex_released := _weak_released(previous_prediction_hex_weak)
	_check(previous_prediction_hex_released, "iteration %d superseded tracked prediction authority releases after bind" % iteration)
	_check(prediction.hex_authority != prepared.hex_court and prediction.hex_authority != template.hex_court, "iteration %d prediction owns an independent Hex authority" % iteration)
	_check(prediction.hex_authority.state_hash() == expected_hex_hash, "iteration %d prediction authority preserves the exact frozen Hex hash" % iteration)
	_check(template.state_hash() == expected_world_hash and template.hex_court.state_hash() == expected_hex_hash, "iteration %d capture/prepare/bind leaves the frozen source unchanged" % iteration)
	if iteration == 0:
		_verify_independent_mutation(template, prepared, prediction, expected_world_hash, expected_hex_hash)

	var row := {
		"iteration": iteration,
		"inclusive_us": {
			"capture": capture_us,
			"prepare": prepare_us,
			"prediction_bind": bind_us,
		},
		"memory": {
			"before_capture": memory_before,
			"after_capture": memory_after_capture,
			"after_prepare": memory_after_prepare,
			"after_replica_replace_before_bind": memory_after_replica_replace,
			"after_prediction_bind": memory_after_bind,
		},
		"known_retained": {
			"template_world_id": template.get_instance_id(),
			"template_hex_id": template.hex_court.get_instance_id(),
			"template_cells": template.hex_court.cells.size(),
			"replica_world_id": prepared.get_instance_id(),
			"replica_hex_id": prepared.hex_court.get_instance_id(),
			"replica_cells": prepared.hex_court.cells.size(),
			"prediction_hex_id": prediction.hex_authority.get_instance_id(),
			"prediction_cells": prediction.hex_authority.cells.size(),
		},
		"hashes": {
			"source_world": expected_world_hash,
			"source_hex": expected_hex_hash,
			"replica_world": prepared.state_hash(),
			"replica_hex": prepared.hex_court.state_hash(),
			"prediction_hex": prediction.hex_authority.state_hash(),
		},
		"superseded_release": {
			"had_previous": previous_replica_id != 0,
			"replica_id": previous_replica_id,
			"replica_hex_id": previous_replica_hex_id,
			"prediction_hex_id": previous_prediction_hex_id,
			"replica_released_before_bind": previous_replica_released,
			"replica_hex_released_before_bind": previous_replica_hex_released,
			"prediction_hex_released_after_bind": previous_prediction_hex_released,
		},
	}
	_check(int(row.known_retained.template_cells) == EXPECTED_TOPOLOGY_CELLS and int(row.known_retained.replica_cells) == EXPECTED_TOPOLOGY_CELLS and int(row.known_retained.prediction_cells) == EXPECTED_TOPOLOGY_CELLS, "iteration %d three known retained topology fields each contain 2,766 cells" % iteration)
	return row


func _verify_independent_mutation(template: SimWorld, replica: SimWorld, prediction: ClientPrediction, expected_world_hash: String, expected_hex_hash: String) -> void:
	var keys: Array = replica.hex_court.cells.keys()
	_check(not keys.is_empty(), "independence mutation has one prepared cell")
	if keys.is_empty():
		return
	var cell: Vector2i = keys[0]
	var original_terrain: int = int(replica.hex_court.cells[cell].terrain)
	replica.hex_court.cells[cell].terrain = original_terrain + 1
	_check(replica.hex_court.state_hash() != expected_hex_hash, "prepared-replica mutation is visible only to its own authority")
	_check(template.state_hash() == expected_world_hash and template.hex_court.state_hash() == expected_hex_hash, "prepared-replica mutation cannot alter the frozen source")
	_check(prediction.hex_authority.state_hash() == expected_hex_hash, "prepared-replica mutation cannot alter the detached prediction authority")
	replica.hex_court.cells[cell].terrain = original_terrain
	_check(replica.state_hash() == expected_world_hash and replica.hex_court.state_hash() == expected_hex_hash, "prepared-replica restoration recovers the exact frozen hashes")


func _weak_released(value: Variant) -> bool:
	if value == null:
		return true
	if not value is WeakRef:
		return false
	return value.get_ref() == null


func _memory_observation() -> Dictionary:
	var static_bytes := OS.get_static_memory_usage()
	var peak_bytes := OS.get_static_memory_peak_usage()
	return {
		"static_available": static_bytes > 0,
		"static_bytes": static_bytes if static_bytes > 0 else null,
		"peak_available": peak_bytes > 0,
		"peak_bytes": peak_bytes if peak_bytes > 0 else null,
	}


func _lifetime_result_complete(result: Dictionary) -> bool:
	if result.is_empty():
		return false
	var rows_value: Variant = result.get("rows")
	if not rows_value is Array or rows_value.size() != ITERATIONS:
		return false
	for row_value: Variant in rows_value:
		if not row_value is Dictionary:
			return false
		if not row_value.get("inclusive_us") is Dictionary or not row_value.get("known_retained") is Dictionary or not row_value.get("superseded_release") is Dictionary:
			return false
		var release_value: Variant = row_value.get("superseded_release")
		if not release_value is Dictionary:
			return false
		if not bool(release_value.get("replica_released_before_bind", false)) or not bool(release_value.get("replica_hex_released_before_bind", false)) or not bool(release_value.get("prediction_hex_released_after_bind", false)):
			return false
		var memory_value: Variant = row_value.get("memory")
		if not memory_value is Dictionary:
			return false
		for phase: String in ["before_capture", "after_capture", "after_prepare", "after_replica_replace_before_bind", "after_prediction_bind", "after_helper_scope"]:
			if not _memory_observation_complete(memory_value.get(phase)):
				return false
	var stages_value: Variant = result.get("inclusive_stage_us")
	if not stages_value is Dictionary:
		return false
	for stage_name: String in ["capture", "prepare", "prediction_bind"]:
		var stage_value: Variant = stages_value.get(stage_name)
		if not stage_value is Dictionary:
			return false
		var samples_value: Variant = stage_value.get("samples")
		if not samples_value is Array or samples_value.size() != ITERATIONS:
			return false
	var final_value: Variant = result.get("final_tracked_release")
	if not final_value is Dictionary:
		return false
	return (
		bool(final_value.get("replica_released", false))
		and bool(final_value.get("replica_hex_released", false))
		and bool(final_value.get("prediction_hex_released", false))
		and _memory_observation_complete(final_value.get("memory_after_release"))
	)


func _memory_observation_complete(value: Variant) -> bool:
	if not value is Dictionary or not value.has("static_available") or not value.has("static_bytes") or not value.has("peak_available") or not value.has("peak_bytes"):
		return false
	var static_available := bool(value.static_available)
	var peak_available := bool(value.peak_available)
	return (
		(int(value.static_bytes) > 0 if static_available else value.static_bytes == null)
		and (int(value.peak_bytes) > 0 if peak_available else value.peak_bytes == null)
	)


func _timing_result(samples: PackedInt64Array) -> Dictionary:
	return {"inclusive_us": _percentiles(samples), "samples": Array(samples)}


func _nonempty_material_cells(court: HexChemistryWorld) -> int:
	var result := 0
	var layers: Array[String] = HexChemistryWorld.material_layers()
	for cell: Vector2i in court.cells:
		for layer: String in layers:
			var layer_value: Dictionary = court.cells[cell][layer]
			if not layer_value.is_empty():
				result += 1
				break
	return result


func _source_hashes() -> Dictionary:
	var result := {}
	for path: String in [
		"tests/performance/profile_hex_snapshot_lifetime.gd",
		"tests/performance/profile_unified_wellspring.gd",
		"src/net/hex_world_snapshot.gd",
		"src/net/hex_chemistry_snapshot.gd",
		"src/net/hex_snapshot_wire_packing.gd",
		"src/net/client_prediction.gd",
		"src/sim/core/sim_world.gd",
		"src/sim/hex/hex_chemistry_world.gd",
		"content/abilities/foundation_abilities_v1.json",
		"content/champions/foundation_champions_v1.json",
		"content/maps/sanctum_campus_g2_v1.json",
	]:
		result[path] = FileAccess.get_sha256("res://" + path)
	return result


func _finish(receipt: Dictionary) -> void:
	if not receipt.is_empty() and not output_path.is_empty():
		receipt.assertions = assertions
		receipt.failures = failures
		var output := FileAccess.open(output_path, FileAccess.WRITE)
		_check(output != null, "lifetime receipt opens")
		if output != null:
			receipt.assertions = assertions
			receipt.failures = failures
			output.store_string(JSON.stringify(receipt, "\t") + "\n")
			output.close()
	print("%s: hex-snapshot-lifetime; %d assertions; %d failures; completed=%d; output=%s" % ["PASS" if failures == 0 else "FAIL", assertions, failures, iterations_completed, output_path])
	quit(1 if failures > 0 else 0)
