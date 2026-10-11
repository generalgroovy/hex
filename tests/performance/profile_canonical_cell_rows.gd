extends "res://tests/performance/profile_capture_pipeline.gd"

const RowsBefore = preload("res://tests/support/frozen_hex_canonical_state_e17.gd")
const RowsCurrent = preload("res://src/sim/hex/hex_canonical_state.gd")
const RowsOracle = preload("res://tests/support/hex_canonical_pre_e9.gd")
const ROWS_ORACLE_PATH := "tests/support/frozen_hex_canonical_state_e17.gd"
const ROWS_ORACLE_SHA256 := "ee49233bb2ad575303eab9a0139f591c0068c32670536926595e765ea39f578c"
const ROWS_PROFILE_PATH := "tests/performance/profile_canonical_cell_rows.gd"
const ROWS_VERSION := "canonical-cell-rows-v1"
const ROWS_CHECKS: Array[String] = ["bytes_exact", "hash_exact", "mutable_ownership", "source_unchanged"]


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output_path = argument.trim_prefix("--output=")
		else: _check(false, "unknown canonical row probe argument")
	_check(output_path.begins_with("res://.godot/canonical-cell-rows-") and output_path.ends_with(".json") and output_path.get_base_dir() == "res://.godot" and not ".." in output_path and not FileAccess.file_exists(output_path), "fresh scoped canonical row receipt")
	var before := _rows_sources()
	_check(_hashes_valid(before) and before[ROWS_ORACLE_PATH] == ROWS_ORACLE_SHA256, "all dependencies and frozen pre-E18 helper hash")
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "actual abilities load")
	_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "actual champions load")
	_check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "actual campus loads")
	definition = HexWorldDefinition.from_campus(layout)
	_check(definition != null and definition.eligible_cells.size() == EXPECTED_TOPOLOGY_CELLS, "actual 11337-cell campus")
	if failures > 0:
		quit(1)
		return
	var records: Array[Dictionary] = []
	for offset: int in CASE_LABELS.size(): records.append(_rows_case(CASE_LABELS[offset], offset))
	var after := _rows_sources()
	_check(before == after, "sources unchanged throughout canonical row diagnostic")
	var receipt := {
		"profile_version": ROWS_VERSION, "engine": Engine.get_version_info().get("string", ""),
		"source_sha256_before": before, "source_sha256_after": after, "sources_unchanged": before == after,
		"samples": PUBLICATION_SAMPLES, "records": records,
		"scope": "Seven alternating case-counterbalanced pre-E18/current chemistry-hash pairs on the SAME concrete world, using actual empty, distributed-paid40, dense-paid40 and active-Rampart fixtures with eight champions and 11337 cells. Both helper Scripts retain their exact-concrete admission and independently warmed one-topology immutable byte templates.",
		"timing": "Each timer encloses only helper.state_hash(world.hex_court). Setup, full-byte independent legacy oracle checks, ownership/mutation tests, source guards, statistics and evidence bookkeeping occur outside timers. Both arms hash all legacy bytes. This is a warm hash-level comparison, NOT a capture/publication/network or sustained-performance claim.",
		"oracle": "Private pre-E18 helper mechanically reverses only the local quote memo, direct row-writer call and helper. All other preceding streaming/admission/fallback semantics remain unchanged. Frozen pre-E9 whole-document conversion independently proves exact complete canonical bytes.",
		"performance_acceptance": "NOT_ESTABLISHED",
	}
	receipt.receipt_complete = _rows_records_complete(records)
	receipt.diagnostic_status = "PASS" if failures == 0 else "FAIL"
	receipt.failures = failures
	_check(_rows_receipt_valid(receipt), "complete native canonical row receipt")
	_check(_rows_receipt_valid(JSON.parse_string(JSON.stringify(receipt))), "complete serialized canonical row receipt")
	_rows_guards(receipt)
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	_check(output != null, "canonical row receipt opens")
	if output != null:
		receipt.assertions = assertions
		receipt.failures = failures
		receipt.diagnostic_status = "PASS" if failures == 0 else "FAIL"
		output.store_string(JSON.stringify(receipt, "\t") + "\n")
		output.close()
	print("%s: canonical-cell-rows; %d assertions; %d failures; output=%s" % ["PASS" if failures == 0 else "FAIL", assertions, failures, output_path])
	quit(1 if failures > 0 else 0)


func _rows_case(label: String, offset: int) -> Dictionary:
	print("CANONICAL_ROWS_FIXTURE " + label)
	var fixture: Dictionary = _collision_fixture(label)
	if fixture.is_empty(): return {}
	var world: SimWorld = fixture.worlds.sealed
	var session: AuthoritativeSession = _publication_session(world)
	var source_before := _publication_source_bytes(session)
	var original: PackedByteArray = RowsOracle.state_bytes(world.hex_court)
	var expected_hash: String = RowsOracle.hash_bytes(original)
	var checks := {"bytes_exact": true, "hash_exact": true, "mutable_ownership": false, "source_unchanged": true}
	checks.bytes_exact = RowsBefore.canonical_bytes(world.hex_court) == original and RowsCurrent.canonical_bytes(world.hex_court) == original \
		and RowsOracle.state_bytes(fixture.worlds.legacy.hex_court) == original
	for arm: String in COLLISION_ARMS:
		_check(_rows_hash(arm, world.hex_court) == expected_hash, "untimed exact hash warmup " + arm)
	var observations := {"frozen": PackedInt64Array(), "candidate": PackedInt64Array()}
	var rows: Array[Dictionary] = []
	for index: int in PUBLICATION_SAMPLES:
		var order: Array[String] = _collision_order(index + offset)
		var row := {"order": order.duplicate(), "samples_us": {}}
		for arm: String in order:
			var started := Time.get_ticks_usec()
			var result: String = _rows_hash(arm, world.hex_court)
			var elapsed: int = Time.get_ticks_usec() - started
			var samples: PackedInt64Array = observations[arm]
			samples.append(elapsed)
			observations[arm] = samples
			row.samples_us[arm] = elapsed
			checks.hash_exact = bool(checks.hash_exact) and result == expected_hash
			_check(result == expected_hash, label + " timed " + arm + " exact independently expected hash")
			var bytes: PackedByteArray = RowsBefore.canonical_bytes(world.hex_court) if arm == "frozen" else RowsCurrent.canonical_bytes(world.hex_court)
			checks.bytes_exact = bool(checks.bytes_exact) and bytes == original
			_check(bytes == original, label + " untimed full framed bytes " + arm)
			var source_exact: bool = _publication_source_bytes(session) == source_before and _storage_modes_valid(fixture.worlds)
			checks.source_unchanged = bool(checks.source_unchanged) and source_exact
			_check(source_exact, label + " pair leaves complete source/session unchanged")
		rows.append(row)
	checks.mutable_ownership = _rows_mutation_check(world)
	checks.source_unchanged = bool(checks.source_unchanged) and _publication_source_bytes(session) == source_before
	for key: String in ROWS_CHECKS: _check(bool(checks[key]), label + " " + key)
	var paired := {"frozen": _stats(observations.frozen), "candidate": _stats(observations.candidate), "pairs": rows, "exact": bool(checks.hash_exact) and bool(checks.bytes_exact)}
	_check(_capture_pairs_complete(paired, offset), "exact alternating canonical hash pair receipt")
	print("CANONICAL_ROWS_PAIR %s frozen_p50_us=%d candidate_p50_us=%d" % [label, paired.frozen.statistics_us.p50, paired.candidate.statistics_us.p50])
	return {
		"case": label, "actors": world.players.size(), "topology_cells": world.hex_court.cell_count(),
		"tick": world.tick, "paid_steps": fixture.paid_steps, "paid_metrics": world.hex_court.metrics.duplicate(true),
		"active_ramparts": _active_ramparts(world.hex_court, world.tick), "state_hash": world.state_hash(),
		"trace_sha256": fixture.trace_sha256, "chemistry_hash": expected_hash, "canonical_bytes": original.size(),
		"checks": checks, "paired": paired,
	}


func _rows_hash(arm: String, world: HexChemistryWorld) -> String:
	return RowsBefore.state_hash(world) if arm == "frozen" else RowsCurrent.state_hash(world)


func _rows_mutation_check(source: SimWorld) -> bool:
	# Mutations are isolated to a fresh strict reconstruction, never the paid
	# timed fixture. The retained nested alias changes without revision updates.
	var prepared := HexWorldSnapshot.prepare(HexWorldSnapshot.capture(source), source)
	if prepared == null or prepared.hex_court == source.hex_court or prepared.players[0] == source.players[0]: return false
	var child: HexChemistryWorld = prepared.hex_court
	if child.immutable_topology() != source.hex_court.immutable_topology(): return false
	var before: String = child.state_hash()
	var cell: Vector2i = child.cell_keys()[0]
	child.set_cell_amount(cell, "__canonical_row_probe__", 19, 0)
	var alias: Dictionary = child.cell_record(cell)["__canonical_row_probe__"]
	var revision: int = child.value_revision
	for value: int in [0, -2_147_483_648, 2_147_483_647, 7]:
		alias[19] = value
		var expected: PackedByteArray = RowsOracle.state_bytes(child)
		if RowsBefore.canonical_bytes(child) != expected or RowsCurrent.canonical_bytes(child) != expected: return false
		if RowsBefore.state_hash(child) != RowsOracle.hash_bytes(expected) or child.state_hash() != RowsOracle.hash_bytes(expected): return false
		if child.value_revision != revision or child.state_hash() == before: return false
	alias.clear()
	return child.state_hash() == before and RowsBefore.state_hash(child) == before


func _rows_records_complete(records: Variant) -> bool:
	if not records is Array or records.size() != CASE_LABELS.size(): return false
	for offset: int in CASE_LABELS.size():
		var record: Variant = records[offset]
		if not record is Dictionary or record.get("case") != CASE_LABELS[offset] or record.get("actors") != 8 or record.get("topology_cells") != EXPECTED_TOPOLOGY_CELLS: return false
		if not _canonical_keys(record.get("checks"), ROWS_CHECKS): return false
		for key: String in ROWS_CHECKS:
			if record.checks[key] != true: return false
		for key: String in ["state_hash", "trace_sha256", "chemistry_hash"]:
			if not _hash_valid(record.get(key)): return false
		for key: String in ["tick", "paid_steps", "active_ramparts"]:
			if not _publication_integer(record.get(key)): return false
		if record.tick != WARMUP_TICKS + record.paid_steps or not _publication_integer(record.get("canonical_bytes"), 8): return false
		if offset == 0 and record.paid_steps != 0: return false
		if offset in [1, 2] and record.paid_steps != 40: return false
		if offset == 3 and (record.paid_steps < 1 or record.paid_steps > RAMPART_STEP_LIMIT or record.active_ramparts < 1): return false
		if not record.get("paid_metrics") is Dictionary: return false
		if offset > 0 and (record.paid_metrics.get("admitted", 0) <= 0 or record.paid_metrics.get("matter_paid", 0) <= 0): return false
		if not _capture_pairs_complete(record.get("paired"), offset): return false
	return true


func _rows_receipt_valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("profile_version") != ROWS_VERSION or value.get("samples") != PUBLICATION_SAMPLES: return false
	if value.get("diagnostic_status") != "PASS" or value.get("failures") != 0 or value.get("receipt_complete") != true or value.get("sources_unchanged") != true: return false
	if not value.get("source_sha256_before") is Dictionary or not value.get("source_sha256_after") is Dictionary or not _hashes_valid(value.source_sha256_before): return false
	if value.source_sha256_before != value.source_sha256_after or value.source_sha256_before.get(ROWS_ORACLE_PATH) != ROWS_ORACLE_SHA256 or not value.source_sha256_before.has(ROWS_PROFILE_PATH): return false
	return _rows_records_complete(value.get("records"))


func _rows_guards(receipt: Dictionary) -> void:
	if not _rows_receipt_valid(receipt): return
	for mutation: String in ["case", "sample", "fractional", "order", "bytes", "ownership", "source", "oracle"]:
		var broken: Dictionary = receipt.duplicate(true)
		match mutation:
			"case": broken.records.pop_back()
			"sample": broken.records[0].paired.frozen.samples_us.pop_back()
			"fractional": broken.records[0].paired.candidate.statistics_us.p50 += 0.5
			"order": broken.records[0].paired.pairs[0].order.reverse()
			"bytes": broken.records[0].checks.bytes_exact = false
			"ownership": broken.records[0].checks.mutable_ownership = false
			"source": broken.sources_unchanged = false
			"oracle": broken.source_sha256_before[ROWS_ORACLE_PATH] = "0".repeat(64)
		_check(not _rows_receipt_valid(broken), "native canonical row receipt rejects " + mutation)
		_check(not _rows_receipt_valid(JSON.parse_string(JSON.stringify(broken))), "JSON canonical row receipt rejects " + mutation)


func _rows_sources() -> Dictionary:
	var result := _capture_sources()
	for path: String in [ROWS_PROFILE_PATH, ROWS_ORACLE_PATH, "tests/support/hex_canonical_pre_e9.gd"]:
		result[path] = FileAccess.get_sha256("res://" + path)
	return result
