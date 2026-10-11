extends "res://tests/performance/profile_capture_pipeline.gd"

const LeafDynamic = preload("res://tests/support/hex_dynamic_leaf_candidate.gd")
const LeafCandidate = preload("res://tests/support/hex_canonical_leaf_candidate.gd")
const LeafCurrent = preload("res://src/sim/hex/hex_canonical_state.gd")
const LeafBefore = preload("res://tests/support/frozen_hex_canonical_pre_leaf.gd")
const LeafOracle = preload("res://tests/support/hex_canonical_pre_e9.gd")
const LeafTests = preload("res://tests/unit/test_hex_canonical_leaf_candidate.gd")
const LEAF_PROFILE := "tests/performance/profile_canonical_leaf_candidate.gd"
const LEAF_VERSION := "canonical-coordinate-leaf-v3"
const LEAF_ORACLE_PATH := "tests/support/hex_canonical_pre_e9.gd"
const LEAF_ORACLE_SHA256 := "48d5471984bf1461ae2e8067c1dc2f49680dfb2208a64634ebb791dcd5bcb36f"
const LEAF_BASELINE_PATH := "tests/support/frozen_hex_canonical_pre_leaf.gd"
const LEAF_BASELINE_SHA256 := "f59aed162a15c824e37971a30b4cdbc274725f7ecb4482c10bbfc8373a6bc6c3"
const LEAF_STAGES: Array[String] = ["stable_tree", "json_stringify", "utf8", "current_parts", "candidate_parts", "hash_updates"]
const LEAF_OPERATIONS: Array[String] = ["dynamic_document", "complete_hash"]
const LEAF_CHECKS: Array[String] = ["bytes_exact", "hash_exact", "capture_exact", "publication_exact", "strict_restore", "continuation", "ownership", "source_unchanged"]
var integration_label := "unmodified-production"


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output_path = argument.trim_prefix("--output=")
		elif argument.begins_with("--label="): integration_label = argument.trim_prefix("--label=")
		else: _check(false, "unknown leaf-candidate profile argument")
	_check(output_path.begins_with("res://.godot/canonical-leaf-") and output_path.ends_with(".json") and output_path.get_base_dir() == "res://.godot" and not ".." in output_path and not FileAccess.file_exists(output_path), "fresh scoped leaf receipt")
	_check(integration_label in ["unmodified-production", "A1", "B1", "B2", "A2"], "explicit integration observation label")
	var before := _leaf_sources()
	_check(_hashes_valid(before) and before.get(LEAF_ORACLE_PATH) == LEAF_ORACLE_SHA256, "complete source inventory and fixed independent oracle")
	_check(before.get(LEAF_BASELINE_PATH) == LEAF_BASELINE_SHA256, "exact frozen preceding canonical helper")
	var unit := LeafTests.new()
	_check(unit.run() == 0, "independent leaf candidate unit suite")
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "actual abilities load")
	_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "actual champions load")
	_check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "actual campus loads")
	definition = HexWorldDefinition.from_campus(layout)
	_check(definition != null and definition.eligible_cells.size() == EXPECTED_TOPOLOGY_CELLS, "actual 11337-cell campus")
	if failures > 0:
		quit(1)
		return
	var records: Array[Dictionary] = []
	for offset: int in CASE_LABELS.size(): records.append(_leaf_case(CASE_LABELS[offset], offset))
	var after := _leaf_sources()
	_check(before == after, "all source files unchanged throughout diagnostic")
	var receipt := {
		"profile_version": LEAF_VERSION, "engine": Engine.get_version_info().get("string", ""),
		"integration_label": integration_label, "source_sha256_before": before, "source_sha256_after": after,
		"sources_unchanged": before == after, "samples": PUBLICATION_SAMPLES, "records": records,
		"scope": "Same four real eight-champion/11337-cell paid fixtures and independent legacy-storage twin. Seven alternating frozen-before/candidate document and whole-hash pairs. Candidate is isolated test support; no production hook is installed by this script.",
		"stages": "Stable-tree, stringify and UTF-8 time sequential non-overlapping operations for the dynamic document only. Parts timers are inclusive full fragment construction. Hash-update timer consumes already built current fragments. Stage samples are separate diagnostics; do not sum inclusive stages or infer publication improvement from helper pairs.",
		"complete_path": "production_observations times real HexWorldSnapshot.capture and the actual owned SessionTransport publication pipeline, including the outer eligibility guard and outgoing encoding. These use whatever production source hash is recorded for this process, NOT a test-injected candidate. A/B/B/A requires the integration owner to install/remove the documented single assembly substitution between separate processes.",
		"correctness": "Independent pre-E9 full bytes, exact E16/current capture, exact complete envelope/packet/encoded bytes, current strict restore and 16 continuation steps; tests, fixture setup, source hashes and receipt bookkeeping are outside timers.",
		"admission": "admitted_leaf_count=-1 means the candidate used its unchanged whole-document fallback. admission_diagnostic names the first callback-free rejection. leaf_entries and potential_avoided_arrays describe qualifying shapes only, NOT measured or actual allocation removal; in fallback no leaf substitution occurred. Eligible admission still does not prove substitution because token collisions can independently trigger fallback.",
		"limits": "Warm seven-sample diagnostics, not sustained p95/p99, FPS, network, 120Hz or capacity acceptance. Source-stage timers have one-microsecond resolution and may legitimately record zero. No per-arm memory claim.",
		"performance_acceptance": "NOT_ESTABLISHED",
	}
	receipt.receipt_complete = _leaf_records_valid(records)
	_check(receipt.receipt_complete, "complete independently checked leaf receipt")
	_check(_leaf_records_valid(JSON.parse_string(JSON.stringify(records))), "serialized leaf records remain complete")
	_leaf_receipt_guards(records)
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	_check(output != null, "fresh leaf receipt opens")
	if output != null:
		receipt.assertions = assertions
		receipt.failures = failures
		receipt.diagnostic_status = "PASS" if failures == 0 else "FAIL"
		output.store_string(JSON.stringify(receipt, "\t") + "\n")
		output.close()
	print("%s: canonical-leaf-candidate; %d assertions; %d failures; output=%s" % ["PASS" if failures == 0 else "FAIL", assertions, failures, output_path])
	quit(1 if failures > 0 else 0)


func _leaf_case(label: String, offset: int) -> Dictionary:
	print("LEAF_FIXTURE " + label)
	var fixture: Dictionary = _collision_fixture(label)
	if fixture.is_empty(): return {}
	var world: SimWorld = fixture.worlds.sealed
	var session := _publication_session(world)
	var encoder := SessionTransport.new()
	var expected := LeafOracle.state_bytes(world.hex_court)
	var expected_hash := LeafOracle.hash_bytes(expected)
	var expected_document := JSON.stringify(LeafOracle._stable(LeafDynamic.lanes(world.hex_court)))
	var checks := {}
	checks.bytes_exact = LeafCurrent.canonical_bytes(world.hex_court) == expected and LeafCandidate.canonical_bytes(world.hex_court) == expected and LeafOracle.state_bytes(fixture.worlds.legacy.hex_court) == expected
	checks.hash_exact = LeafBefore.state_hash(world.hex_court) == expected_hash and LeafCurrent.state_hash(world.hex_court) == expected_hash and LeafCandidate.state_hash(world.hex_court) == expected_hash
	var snapshot: Dictionary = CaptureBefore.capture(world)
	var expected_capture := var_to_bytes(snapshot)
	var expected_publication := _capture_publish(snapshot, session, encoder)
	_check(not snapshot.is_empty() and not expected_publication.is_empty(), "independent preceding codec and complete reference publication")
	if snapshot.is_empty() or expected_publication.is_empty(): return {}
	var source_before := _publication_source_bytes(session)
	var pairs := {}
	for operation: String in LEAF_OPERATIONS:
		pairs[operation] = _leaf_pairs(operation, world.hex_court, expected_document if operation == "dynamic_document" else expected_hash, offset)
	var substages := _leaf_substages(world.hex_court, expected_document, expected_hash)
	var observations := {"world_capture": PackedInt64Array(), "owned_publication": PackedInt64Array()}
	checks.capture_exact = true
	checks.publication_exact = true
	for index: int in PUBLICATION_SAMPLES + 1:
		var started := Time.get_ticks_usec()
		var actual := HexWorldSnapshot.capture(world)
		var elapsed := Time.get_ticks_usec() - started
		if index > 0: _leaf_sample(observations, "world_capture", elapsed)
		checks.capture_exact = bool(checks.capture_exact) and var_to_bytes(actual) == expected_capture
		started = Time.get_ticks_usec()
		var published := _publication_pipeline(session, encoder, "owned")
		elapsed = Time.get_ticks_usec() - started
		if index > 0: _leaf_sample(observations, "owned_publication", elapsed)
		checks.publication_exact = bool(checks.publication_exact) and _publication_pair_result_valid(published, var_to_bytes(expected_publication.envelope), var_to_bytes(expected_publication.packets), expected_publication.encoded)
	var left := HexWorldSnapshot.prepare(snapshot, world)
	var right := HexWorldSnapshot.prepare(HexWorldSnapshot.capture(world), world)
	checks.strict_restore = left != null and right != null and left.state_hash() == world.state_hash() and right.state_hash() == world.state_hash()
	checks.ownership = bool(checks.strict_restore) and left.hex_court != right.hex_court and left.hex_court != world.hex_court and right.hex_court != world.hex_court and left.players[0] != right.players[0] and left.hex_court.immutable_topology() == world.hex_court.immutable_topology() and right.hex_court.immutable_topology() == world.hex_court.immutable_topology()
	var continuation := bool(checks.strict_restore)
	var trace := HashingContext.new()
	trace.start(HashingContext.HASH_SHA256)
	if continuation:
		continuation = _collision_descriptor(left.collision) == _collision_descriptor(right.collision)
		for unused: int in 16:
			var commands := _commands(left, fixture.targets, "dense-crucible", false, false)
			continuation = left.step(commands) and right.step(commands) and left.state_hash() == right.state_hash() and left.combat_events == right.combat_events and continuation
			var oracle := LeafOracle.state_bytes(right.hex_court)
			continuation = LeafCandidate.canonical_bytes(right.hex_court) == oracle and LeafCandidate.state_hash(right.hex_court) == LeafOracle.hash_bytes(oracle) and continuation
			trace.update((left.state_hash() + JSON.stringify(FrozenHash._stable_original(left.combat_events))).to_utf8_buffer())
	checks.continuation = continuation
	checks.source_unchanged = _publication_source_bytes(session) == source_before and _storage_modes_valid(fixture.worlds)
	for key: String in LEAF_CHECKS: _check(bool(checks[key]), label + " " + key)
	var production := {"world_capture": _stats(observations.world_capture), "owned_publication": _stats(observations.owned_publication)}
	print("LEAF_PAIRS %s document=%d/%d hash=%d/%d owned=%d" % [label, pairs.dynamic_document.frozen.statistics_us.p50, pairs.dynamic_document.candidate.statistics_us.p50, pairs.complete_hash.frozen.statistics_us.p50, pairs.complete_hash.candidate.statistics_us.p50, production.owned_publication.statistics_us.p50])
	var leaf_entries := _leaf_entry_count(LeafDynamic.lanes(world.hex_court))
	var admitted_count := LeafDynamic.admitted_leaf_count(LeafDynamic.lanes(world.hex_court))
	return {"case": label, "actors": world.players.size(), "topology_cells": world.hex_court.cell_count(),
		"tick": world.tick, "paid_steps": fixture.paid_steps, "paid_metrics": world.hex_court.metrics.duplicate(true), "active_ramparts": _active_ramparts(world.hex_court, world.tick),
		"state_hash": world.state_hash(), "chemistry_hash": expected_hash, "trace_sha256": fixture.trace_sha256,
		"canonical_bytes": expected.size(), "snapshot_sha256": CanonicalBytes.sha256_hex(expected_capture),
		"publication_sha256": CanonicalBytes.sha256_hex(var_to_bytes([expected_publication.envelope, expected_publication.packets, expected_publication.encoded])),
		"continuation_sha256": trace.finish().hex_encode(), "continuation_steps": 16 if continuation else 0,
		"admitted_leaf_count": admitted_count, "admission_status": "fallback" if admitted_count < 0 else "no-leaves" if admitted_count == 0 else "eligible",
		"admission_diagnostic": LeafDynamic.admission_diagnostic(LeafDynamic.lanes(world.hex_court)),
		"leaf_entries": leaf_entries, "potential_avoided_arrays": leaf_entries * 2,
		"dynamic_document_utf8_bytes": expected_document.to_utf8_buffer().size(),
		"pairs": pairs, "substages": substages, "production_observations": production, "checks": checks}


func _leaf_pairs(operation: String, world: HexChemistryWorld, expected: String, offset: int) -> Dictionary:
	var observations := {"frozen": PackedInt64Array(), "candidate": PackedInt64Array()}
	var rows: Array[Dictionary] = []
	var exact := true
	for index: int in PUBLICATION_SAMPLES:
		var order := _collision_order(index + offset)
		var row := {"order": order.duplicate(), "samples_us": {}}
		for arm: String in order:
			var started := Time.get_ticks_usec()
			var actual: String
			if operation == "dynamic_document": actual = LeafDynamic.baseline_document(world) if arm == "frozen" else LeafDynamic.document(world)
			else: actual = LeafBefore.state_hash(world) if arm == "frozen" else LeafCandidate.state_hash(world)
			var elapsed := Time.get_ticks_usec() - started
			var samples: PackedInt64Array = observations[arm]
			samples.append(elapsed)
			observations[arm] = samples
			row.samples_us[arm] = elapsed
			exact = actual == expected and exact
			_check(actual == expected, "paired " + operation + " " + arm + " independent exact result")
		rows.append(row)
	return {"frozen": _stats(observations.frozen), "candidate": _stats(observations.candidate), "pairs": rows, "exact": exact}


func _leaf_substages(world: HexChemistryWorld, expected_document: String, expected_hash: String) -> Dictionary:
	var observations := {}
	for stage: String in LEAF_STAGES: observations[stage] = PackedInt64Array()
	var values := LeafDynamic.lanes(world)
	var prepared_parts := LeafCurrent._parts(world)
	for unused: int in PUBLICATION_SAMPLES:
		var started := Time.get_ticks_usec()
		var stable: Array = []
		for value: Variant in values: stable.append(world._stable(value))
		_leaf_sample(observations, "stable_tree", Time.get_ticks_usec() - started)
		started = Time.get_ticks_usec()
		var document := JSON.stringify(stable)
		_leaf_sample(observations, "json_stringify", Time.get_ticks_usec() - started)
		started = Time.get_ticks_usec()
		var encoded := document.to_utf8_buffer()
		_leaf_sample(observations, "utf8", Time.get_ticks_usec() - started)
		_check(document == expected_document and encoded == expected_document.to_utf8_buffer(), "baseline separated stage output exact")
		for arm: String in ["current_parts", "candidate_parts"]:
			started = Time.get_ticks_usec()
			var parts: Dictionary = LeafCurrent._parts(world) if arm == "current_parts" else LeafCandidate._parts(world)
			var elapsed := Time.get_ticks_usec() - started
			var samples: PackedInt64Array = observations[arm]
			samples.append(elapsed)
			observations[arm] = samples
			_check(not parts.is_empty(), "inclusive fragment stage produces fragments")
		started = Time.get_ticks_usec()
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		for fragment: PackedByteArray in prepared_parts.fragments: context.update(fragment)
		var hash_value := context.finish().hex_encode()
		_leaf_sample(observations, "hash_updates", Time.get_ticks_usec() - started)
		_check(hash_value == expected_hash, "hash-update stage consumes exact full fragments")
	var result := {}
	for stage: String in LEAF_STAGES: result[stage] = _stats(observations[stage])
	return result


func _leaf_sample(observations: Dictionary, name: String, elapsed: int) -> void:
	var samples: PackedInt64Array = observations[name]
	samples.append(elapsed)
	observations[name] = samples


func _leaf_entry_count(value: Variant) -> int:
	if value is Dictionary:
		if LeafDynamic._coordinate_leaf(value): return value.size()
		var result := 0
		for key: Variant in value: result += _leaf_entry_count(key) + _leaf_entry_count(value[key])
		return result
	if value is Array:
		var result := 0
		for child: Variant in value: result += _leaf_entry_count(child)
		return result
	return 0


func _leaf_records_valid(records: Variant) -> bool:
	if not records is Array or records.size() != CASE_LABELS.size(): return false
	for offset: int in CASE_LABELS.size():
		var row: Variant = records[offset]
		if not row is Dictionary or row.get("case") != CASE_LABELS[offset] or row.get("actors") != 8 or row.get("topology_cells") != EXPECTED_TOPOLOGY_CELLS or row.get("continuation_steps") != 16: return false
		for key: String in ["tick", "paid_steps", "active_ramparts", "leaf_entries", "potential_avoided_arrays", "dynamic_document_utf8_bytes"]:
			if not _publication_integer(row.get(key)): return false
		if row.potential_avoided_arrays != row.leaf_entries * 2 or not _publication_integer(row.get("admitted_leaf_count"), -1): return false
		var expected_status := "fallback" if row.admitted_leaf_count < 0 else "no-leaves" if row.admitted_leaf_count == 0 else "eligible"
		if row.get("admission_status") != expected_status or not row.get("admission_diagnostic") is Dictionary: return false
		if row.admitted_leaf_count >= 0 and not row.admission_diagnostic.is_empty(): return false
		if row.admitted_leaf_count < 0:
			if not _canonical_keys(row.admission_diagnostic, ["reason", "path", "type", "depth"]): return false
			if row.admission_diagnostic.reason not in ["depth-limit", "unsupported-type"] or not _publication_integer(row.admission_diagnostic.depth): return false
			for name: String in ["path", "type"]:
				if not row.admission_diagnostic[name] is String or row.admission_diagnostic[name].is_empty(): return false
		if row.tick != WARMUP_TICKS + row.paid_steps or not row.get("paid_metrics") is Dictionary: return false
		if offset > 0 and (row.paid_metrics.get("admitted", 0) <= 0 or row.paid_metrics.get("matter_paid", 0) <= 0): return false
		if not _canonical_keys(row.get("checks"), LEAF_CHECKS): return false
		for key: String in LEAF_CHECKS:
			if row.checks[key] != true: return false
		for key: String in ["state_hash", "chemistry_hash", "trace_sha256", "snapshot_sha256", "publication_sha256", "continuation_sha256"]:
			if not _hash_valid(row.get(key)): return false
		if not _canonical_keys(row.get("pairs"), LEAF_OPERATIONS) or not _canonical_keys(row.get("substages"), LEAF_STAGES): return false
		for operation: String in LEAF_OPERATIONS:
			if not _capture_pairs_complete(row.pairs[operation], offset): return false
		for stage: String in LEAF_STAGES:
			if not _canonical_keys(row.substages[stage], ["samples_us", "statistics_us"]): return false
			var samples: Variant = row.substages[stage].get("samples_us")
			if not samples is Array or samples.size() != PUBLICATION_SAMPLES: return false
			for sample: Variant in samples:
				if not _publication_integer(sample): return false
			# JSON numbers are floats. Dictionary equality distinguishes their
			# Variant types from native integer statistics; compare each admitted
			# exact integral value instead, never truncate fractional evidence.
			if not _publication_statistics_complete(row.substages[stage].statistics_us, samples): return false
		if not _canonical_keys(row.get("production_observations"), ["world_capture", "owned_publication"]): return false
		for operation: String in ["world_capture", "owned_publication"]:
			if not _capture_samples_complete(row.production_observations[operation]): return false
	return true


func _leaf_receipt_guards(records: Array[Dictionary]) -> void:
	if not _leaf_records_valid(records): return
	for mutation: String in ["case", "exact", "pair", "stage", "ownership", "continuation", "capture", "admission-count", "admission-status", "admission-reason", "potential-arrays", "stage-fractional-sample", "stage-fractional-statistic", "stage-boolean-statistic", "stage-missing-statistic", "stage-extra-statistic", "admission-fractional", "depth-fractional"]:
		var broken: Array[Dictionary] = records.duplicate(true)
		match mutation:
			"case": broken.pop_back()
			"exact": broken[0].pairs.complete_hash.exact = false
			"pair": broken[0].pairs.complete_hash.pairs[0].order.reverse()
			"stage": broken[0].substages.stable_tree.samples_us.pop_back()
			"ownership": broken[0].checks.ownership = false
			"continuation": broken[0].continuation_steps = 0
			"capture": broken[0].production_observations.world_capture.statistics_us.p50 += 1
			"admission-count": broken[1].admitted_leaf_count = -2
			"admission-status": broken[1].admission_status = "unknown"
			"admission-reason": broken[1].admission_diagnostic = {"reason": "unknown"}
			"potential-arrays": broken[1].potential_avoided_arrays += 1
			"stage-fractional-sample": broken[0].substages.stable_tree.samples_us[0] += 0.5
			"stage-fractional-statistic": broken[0].substages.stable_tree.statistics_us.p50 += 0.5
			"stage-boolean-statistic": broken[0].substages.stable_tree.statistics_us.p50 = true
			"stage-missing-statistic": broken[0].substages.stable_tree.statistics_us.erase("p95")
			"stage-extra-statistic": broken[0].substages.stable_tree.statistics_us.extra = 1
			"admission-fractional": broken[1].admitted_leaf_count = -0.5
			"depth-fractional": broken[1].admission_diagnostic.depth += 0.5
		_check(not _leaf_records_valid(broken), "leaf receipt refuses " + mutation)
		_check(not _leaf_records_valid(JSON.parse_string(JSON.stringify(broken))), "serialized leaf receipt refuses " + mutation)


func _leaf_sources() -> Dictionary:
	var result := _capture_sources()
	for path: String in [LEAF_PROFILE, "tests/support/hex_dynamic_leaf_candidate.gd", "tests/support/hex_canonical_leaf_candidate.gd", "tests/support/frozen_hex_canonical_pre_leaf.gd", LEAF_ORACLE_PATH, "tests/unit/test_hex_canonical_leaf_candidate.gd"]:
		result[path] = FileAccess.get_sha256("res://" + path)
	return result
