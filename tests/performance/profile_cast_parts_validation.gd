extends "res://tests/performance/profile_capture_pipeline.gd"

const ValidationBefore = preload("res://tests/support/hex_cast_parts_pre_validation_aggregate.gd")
const ValidationCurrent = preload("res://src/sim/hex/hex_cast_parts.gd")
const ValidationFixtures = preload("res://tests/support/hex_cast_parts_validation_fixture.gd")
const VALIDATION_ORACLE_PATH := "tests/support/hex_cast_parts_pre_validation_aggregate.gd"
const VALIDATION_ORACLE_SHA256 := "41b362359ed9fdb0f406a42f805535caa15941ff02a072fc92957075650df1c3"
const VALIDATION_PROFILE_PATH := "tests/performance/profile_cast_parts_validation.gd"
const VALIDATION_VERSION := "cast-parts-validation-v1"
const VALIDATION_BATCH := 16
const VALIDATION_SYNTHETIC: Array[String] = ["synthetic-flight", "synthetic-overlap", "synthetic-disjoint", "synthetic-wide-zero-coverage"]


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output_path = argument.trim_prefix("--output=")
		else: _check(false, "unknown cast validation profile argument")
	_check(output_path.begins_with("res://.godot/cast-parts-validation-") and output_path.ends_with(".json") and output_path.get_base_dir() == "res://.godot" and not ".." in output_path and not FileAccess.file_exists(output_path), "fresh scoped validator receipt")
	var before := _validation_sources()
	_check(_hashes_valid(before) and before[VALIDATION_ORACLE_PATH] == VALIDATION_ORACLE_SHA256, "complete sources and frozen preceding validation oracle")
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "actual abilities load")
	_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "actual champions load")
	_check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "actual campus loads")
	definition = HexWorldDefinition.from_campus(layout)
	_check(definition != null and definition.eligible_cells.size() == EXPECTED_TOPOLOGY_CELLS, "actual11337-cell campus")
	if failures > 0:
		quit(1)
		return
	var records: Array[Dictionary] = []
	for offset: int in CASE_LABELS.size():
		var fixture := _collision_fixture(CASE_LABELS[offset])
		if fixture.is_empty():
			records.append({})
			continue
		var world: SimWorld = fixture.worlds.sealed
		var source_hash := world.state_hash()
		var casts: Array[Dictionary] = []
		for cast: Dictionary in world.hex_court.casts.values():
			if not cast.ledger.is_empty(): casts.append(cast)
		var result := _validation_case(CASE_LABELS[offset], casts, offset)
		result.paid_fixture = true
		result.paid_steps = fixture.paid_steps
		result.tick = world.tick
		result.actors = world.players.size()
		result.topology_cells = world.hex_court.cell_count()
		result.active_ramparts = _active_ramparts(world.hex_court, world.tick)
		result.paid_metrics = world.hex_court.metrics.duplicate(true)
		result.state_hash = source_hash
		result.trace_sha256 = fixture.trace_sha256
		result.world_unchanged = world.state_hash() == source_hash and _storage_modes_valid(fixture.worlds)
		_check(result.world_unchanged, "validator observations preserve complete paid fixture")
		records.append(result)
	for index: int in VALIDATION_SYNTHETIC.size():
		var cast := ValidationFixtures.record(0, 1, false)
		if index == 1: cast = ValidationFixtures.record(4, 152, true, true)
		elif index == 2: cast = ValidationFixtures.record(4, 152, false, true)
		elif index == 3: cast = ValidationFixtures.record(16, 511, true, true)
		var casts: Array[Dictionary] = [cast]
		var result := _validation_case(VALIDATION_SYNTHETIC[index], casts, CASE_LABELS.size() + index)
		result.paid_fixture = false
		records.append(result)
	var after := _validation_sources()
	_check(before == after, "sources unchanged throughout exclusive validator diagnostic")
	var receipt := {
		"profile_version": VALIDATION_VERSION, "engine": Engine.get_version_info().get("string", ""),
		"source_sha256_before": before, "source_sha256_after": after, "sources_unchanged": before == after,
		"pairs": PUBLICATION_SAMPLES, "batch_repetitions": VALIDATION_BATCH, "records": records,
		"scope": "Four actual paid eight-champion campus states from existing unchanged fixtures, plus four explicitly synthetic legal ledger shapes. Actual cases select every cast with a nonempty source ledger; empty is a zero-call control. Synthetic wide coverage has zero allocations and overlapping parts; it is not paid gameplay or capacity evidence.",
		"timing": "Seven alternating case-counterbalanced frozen/current pairs. Each timer executes 16 passes of the selected record array, calling only the complete Parts.validate and adding its boolean result to an integer. This exclusive isolated-validator scope includes loop/dispatch/checksum overhead but excludes fixture creation, mutations, source/oracle assertions, copies, hashing, captures, statistics and receipt work. Samples are batch microseconds, not per-call tails. The empty zero-call control may measure zero microseconds; samples are never clamped.",
		"oracle": "Frozen preceding validate, source/ground/ownership checks and sorted temporary aggregation are independent copies. Budget and footprint primitives are shared unchanged dependencies. Every result and exact source bytes/insertion order are checked outside timers.",
		"limits": "No simulation-step, complete snapshot/publication, rendered, memory, network or capacity speedup follows from this microbenchmark. No opaque-extra fixture is timed; differential unit tests separately preserve ignored opaque footprint extras without formatting or mutation. Seven warm pairs do not establish sustained tail performance.",
		"performance_acceptance": "NOT_ESTABLISHED",
	}
	receipt.receipt_complete = _validation_records_complete(records)
	receipt.diagnostic_status = "PASS" if failures == 0 else "FAIL"
	receipt.failures = failures
	_check(_validation_receipt_valid(receipt), "complete native isolated validation receipt")
	_check(_validation_receipt_valid(JSON.parse_string(JSON.stringify(receipt))), "complete serialized isolated validation receipt")
	_validation_guards(receipt)
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	_check(output != null, "exclusive validation receipt opens")
	if output != null:
		receipt.assertions = assertions
		receipt.failures = failures
		receipt.diagnostic_status = "PASS" if failures == 0 else "FAIL"
		output.store_string(JSON.stringify(receipt, "\t") + "\n")
		output.close()
	print("%s: cast-parts-validation; %d assertions; %d failures; output=%s" % ["PASS" if failures == 0 else "FAIL", assertions, failures, output_path])
	quit(1 if failures > 0 else 0)


func _validation_case(label: String, casts: Array[Dictionary], offset: int) -> Dictionary:
	var before := var_to_bytes(casts)
	var expected_count := 0
	var ground_parts := 0
	var part_cells := 0
	for cast: Dictionary in casts:
		var expected := ValidationBefore.validate(cast)
		_check(expected and ValidationCurrent.validate(cast) == expected, label + " exact complete validator warmup")
		expected_count += int(expected)
		ground_parts += cast.ground_parts.size()
		for part: Dictionary in cast.ground_parts.values(): part_cells += part.cells.size()
	var samples := {"frozen": PackedInt64Array(), "candidate": PackedInt64Array()}
	var pairs: Array[Dictionary] = []
	var exact := true
	var source_unchanged := true
	for index: int in PUBLICATION_SAMPLES:
		var order := _collision_order(index + offset)
		var row := {"order": order.duplicate(), "samples_us": {}}
		for arm: String in order:
			var valid_count := 0
			var started := Time.get_ticks_usec()
			for repetition: int in VALIDATION_BATCH:
				for cast: Dictionary in casts:
					valid_count += int(ValidationBefore.validate(cast) if arm == "frozen" else ValidationCurrent.validate(cast))
			var elapsed := Time.get_ticks_usec() - started
			var observations: PackedInt64Array = samples[arm]
			observations.append(elapsed)
			samples[arm] = observations
			row.samples_us[arm] = elapsed
			exact = exact and valid_count == expected_count * VALIDATION_BATCH
			_check(valid_count == expected_count * VALIDATION_BATCH, label + " " + arm + " validator checksum matches")
			source_unchanged = source_unchanged and var_to_bytes(casts) == before
			_check(var_to_bytes(casts) == before, label + " " + arm + " exact source bytes and order unchanged")
		pairs.append(row)
	var paired := {"frozen": _stats(samples.frozen), "candidate": _stats(samples.candidate), "pairs": pairs, "exact": exact}
	_check(_validation_pairs_complete(paired, offset, casts.is_empty()), label + " complete exact validator pairs")
	print("CAST_VALIDATION_PAIR %s records=%d parts=%d cells=%d calls_per_sample=%d frozen_p50_us=%d candidate_p50_us=%d" % [label, casts.size(), ground_parts, part_cells, casts.size() * VALIDATION_BATCH, paired.frozen.statistics_us.p50, paired.candidate.statistics_us.p50])
	return {"case": label, "cast_count": casts.size(), "ground_parts": ground_parts, "part_cells": part_cells,
		"calls_per_sample": casts.size() * VALIDATION_BATCH, "source_sha256": CanonicalBytes.sha256_hex(before),
		"source_unchanged": source_unchanged, "paired": paired}


func _validation_records_complete(records: Variant) -> bool:
	if not records is Array or records.size() != CASE_LABELS.size() + VALIDATION_SYNTHETIC.size(): return false
	for index: int in records.size():
		var record: Variant = records[index]
		var paid := index < CASE_LABELS.size()
		var label: String = CASE_LABELS[index] if paid else VALIDATION_SYNTHETIC[index - CASE_LABELS.size()]
		if not record is Dictionary or record.get("case") != label or record.get("paid_fixture") != paid or record.get("source_unchanged") != true or not _hash_valid(record.get("source_sha256")): return false
		for key: String in ["cast_count", "ground_parts", "part_cells", "calls_per_sample"]:
			if not _publication_integer(record.get(key)): return false
		if record.calls_per_sample != record.cast_count * VALIDATION_BATCH: return false
		if paid:
			if record.get("world_unchanged") != true or not _hash_valid(record.get("state_hash")) or not _hash_valid(record.get("trace_sha256")) or not record.get("paid_metrics") is Dictionary: return false
			for key: String in ["tick", "paid_steps", "active_ramparts"]:
				if not _publication_integer(record.get(key)): return false
			if record.get("actors") != 8 or record.get("topology_cells") != EXPECTED_TOPOLOGY_CELLS or record.tick != WARMUP_TICKS + record.paid_steps: return false
			if index == 0 and (record.paid_steps != 0 or record.cast_count != 0): return false
			if index in [1, 2] and record.paid_steps != 40: return false
			if index == 3 and (record.paid_steps < 1 or record.paid_steps > RAMPART_STEP_LIMIT or record.active_ramparts < 1): return false
			if index > 0 and (record.cast_count < 1 or record.paid_metrics.get("admitted", 0) <= 0 or record.paid_metrics.get("matter_paid", 0) <= 0): return false
		elif record.cast_count != 1: return false
		if not _validation_pairs_complete(record.get("paired"), index, record.cast_count == 0): return false
	return true


func _validation_pairs_complete(paired: Variant, offset: int, zero_call_control: bool) -> bool:
	if not _canonical_keys(paired, ["frozen", "candidate", "pairs", "exact"]) or paired.exact != true or not paired.pairs is Array or paired.pairs.size() != PUBLICATION_SAMPLES: return false
	var minimum := 0 if zero_call_control else 1
	for arm: String in COLLISION_ARMS:
		var observation: Variant = paired[arm]
		if not _canonical_keys(observation, ["samples_us", "statistics_us"]) or not observation.samples_us is Array or observation.samples_us.size() != PUBLICATION_SAMPLES: return false
		for sample: Variant in observation.samples_us:
			if not _publication_integer(sample, minimum): return false
		if not _publication_statistics_complete(observation.statistics_us, observation.samples_us): return false
	for index: int in PUBLICATION_SAMPLES:
		var row: Variant = paired.pairs[index]
		if not _canonical_keys(row, ["order", "samples_us"]) or row.order != _collision_order(index + offset) or not _canonical_keys(row.samples_us, COLLISION_ARMS): return false
		for arm: String in COLLISION_ARMS:
			if not _publication_integer(row.samples_us[arm], minimum) or row.samples_us[arm] != paired[arm].samples_us[index]: return false
	return true


func _validation_receipt_valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("profile_version") != VALIDATION_VERSION or value.get("pairs") != PUBLICATION_SAMPLES or value.get("batch_repetitions") != VALIDATION_BATCH: return false
	if value.get("diagnostic_status") != "PASS" or value.get("failures") != 0 or value.get("receipt_complete") != true or value.get("sources_unchanged") != true: return false
	if not value.get("source_sha256_before") is Dictionary or not value.get("source_sha256_after") is Dictionary or not _hashes_valid(value.source_sha256_before): return false
	if value.source_sha256_before != value.source_sha256_after or value.source_sha256_before.get(VALIDATION_ORACLE_PATH) != VALIDATION_ORACLE_SHA256: return false
	for path: String in [VALIDATION_PROFILE_PATH, "tests/support/hex_cast_parts_validation_fixture.gd", "tests/unit/test_hex_cast_parts.gd", "src/sim/hex/hex_cast_parts.gd"]:
		if not value.source_sha256_before.has(path): return false
	return _validation_records_complete(value.get("records"))


func _validation_guards(receipt: Dictionary) -> void:
	if not _validation_receipt_valid(receipt): return
	for mutation: String in ["case", "sample", "fractional", "order", "result", "source", "oracle", "call-count", "workload-kind"]:
		var broken: Dictionary = receipt.duplicate(true)
		match mutation:
			"case": broken.records.pop_back()
			"sample": broken.records[0].paired.frozen.samples_us.pop_back()
			"fractional": broken.records[0].paired.candidate.statistics_us.p50 += 0.5
			"order": broken.records[0].paired.pairs[0].order.reverse()
			"result": broken.records[0].paired.exact = false
			"source": broken.records[0].source_unchanged = false
			"oracle": broken.source_sha256_before[VALIDATION_ORACLE_PATH] = "0".repeat(64)
			"call-count": broken.records[0].calls_per_sample += 1
			"workload-kind": broken.records[-1].paid_fixture = true
		_check(not _validation_receipt_valid(broken), "native validation receipt rejects " + mutation)
		_check(not _validation_receipt_valid(JSON.parse_string(JSON.stringify(broken))), "JSON validation receipt rejects " + mutation)


func _validation_sources() -> Dictionary:
	var result := _capture_sources()
	for path: String in [VALIDATION_PROFILE_PATH, VALIDATION_ORACLE_PATH, "tests/support/hex_cast_parts_validation_fixture.gd", "tests/unit/test_hex_cast_parts.gd"]:
		result[path] = FileAccess.get_sha256("res://" + path)
	return result
