# Historical p59-era benchmark with preserved pre-expansion snapshot oracles.
# Retained for history only: this script is not current-schema performance
# evidence for protocol60, schema5, or the expanded status/delivery lanes.
extends "res://tests/performance/profile_publication_stages.gd"

const CaptureBefore = preload("res://tests/support/frozen_hex_world_snapshot_e16.gd")
const CAPTURE_ORACLE_PATH := "tests/support/frozen_hex_world_snapshot_e16.gd"
const CAPTURE_ORACLE_SHA256 := "6bb78eecc0a23098ca0eb1a317d3c593718644d0da80c27dd3520b0753a61ca1"
const CAPTURE_PROFILE_PATH := "tests/performance/profile_capture_pipeline.gd"
const CAPTURE_PROFILE_VERSION := "capture-pipeline-v1"
const CAPTURE_STAGES: Array[String] = ["packed_grammar", "serialize_compress", "inflate_parse", "strict_decode", "full_reconstruct"]
const CAPTURE_OPERATIONS: Array[String] = ["capture", "publication"]
const CAPTURE_CHECKS: Array[String] = ["capture_exact", "publication_exact", "current_strict_prepare", "continuation", "source_unchanged", "topology_ownership"]


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output_path = argument.trim_prefix("--output=")
		else: _check(false, "unknown capture probe argument")
	_check(output_path.begins_with("res://.godot/capture-pipeline-") and output_path.ends_with(".json") and output_path.get_base_dir() == "res://.godot" and not ".." in output_path and not FileAccess.file_exists(output_path), "fresh scoped capture receipt")
	var before: Dictionary = _capture_sources()
	_check(_hashes_valid(before) and before[CAPTURE_ORACLE_PATH] == CAPTURE_ORACLE_SHA256, "all dependencies and immutable E16 oracle hash")
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "actual abilities load")
	_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "actual champions load")
	_check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "actual campus loads")
	definition = HexWorldDefinition.from_campus(layout)
	_check(definition != null and definition.eligible_cells.size() == EXPECTED_TOPOLOGY_CELLS, "actual 11337-cell campus")
	if failures > 0:
		quit(1)
		return
	var records: Array[Dictionary] = []
	for index: int in CASE_LABELS.size(): records.append(_capture_case(CASE_LABELS[index], index))
	var after: Dictionary = _capture_sources()
	_check(before == after, "source files unchanged throughout capture diagnostic")
	var receipt: Dictionary = {
		"profile_version": CAPTURE_PROFILE_VERSION, "engine": Engine.get_version_info().get("string", ""),
		"source_sha256_before": before, "source_sha256_after": after, "sources_unchanged": before == after,
		"samples": PUBLICATION_SAMPLES, "records": records,
		"scope": "Exact inherited empty, distributed-paid40, dense-paid40 and active-Rampart fixtures: eight real champions, 11337 cells, ordinary paid input, independently replayed legacy twin. Seven alternating case-counterbalanced frozen/current pairs. Frozen E16 world codec has only its class_name removed; shared unchanged chemistry, wire, collision and simulation primitives are not independently reimplemented.",
		"timing": "Capture pairs time the entire codec capture. Publication pairs use the same strict public metadata/wrap/packetization/outgoing-encoding composition, changing only the capture codec. They isolate E17 and do not time the optimized SessionTransport factory, fanout, sockets or host guards. All assertions, hashes, comparisons, sample recording, fixture setup and fresh ProducerRoundtrip construction for the reconstruction substage occur outside timers.",
		"stages": "Pre-change diagnostics use the frozen codec: packed grammar validates with the old compression default bound; serialize_compress is Variant serialization plus DEFLATE without grammar validation; inflate_parse is bounded DEFLATE plus bytes_to_var; strict_decode retains decoded packed lanes; full_reconstruct is the entire old outer _prepare_core with a fresh one-shot producer established outside the timer, including inflate/parse/decode, chemistry/actor/collision reconstruction, relations and hash validation. These overlap and must not be summed.",
		"limits": "Warm seven-sample diagnostics are not sustained percentiles, rendered performance, network, publication cadence or capacity acceptance. Metadata is final-tick events only. Memory observations are process-global. Current strict preparation of both outputs plus 16 identical continuation steps is correctness evidence, not timed gameplay performance.",
		"performance_acceptance": "NOT_ESTABLISHED",
	}
	receipt.receipt_complete = _capture_records_complete(records)
	receipt.diagnostic_status = "PASS" if failures == 0 else "FAIL"
	receipt.failures = failures
	_check(_capture_receipt_valid(receipt), "complete native capture receipt")
	_check(_capture_receipt_valid(JSON.parse_string(JSON.stringify(receipt))), "complete serialized capture receipt")
	_capture_receipt_guards(receipt)
	var output: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	_check(output != null, "capture receipt opens")
	if output != null:
		receipt.assertions = assertions
		receipt.failures = failures
		receipt.diagnostic_status = "PASS" if failures == 0 else "FAIL"
		output.store_string(JSON.stringify(receipt, "\t") + "\n")
		output.close()
	print("%s: capture-pipeline; %d assertions; %d failures; output=%s" % ["PASS" if failures == 0 else "FAIL", assertions, failures, output_path])
	quit(1 if failures > 0 else 0)


func _capture_case(label: String, offset: int) -> Dictionary:
	print("CAPTURE_FIXTURE " + label)
	var fixture: Dictionary = _collision_fixture(label)
	if fixture.is_empty(): return {}
	var world: SimWorld = fixture.worlds.sealed
	var session: AuthoritativeSession = _publication_session(world)
	var encoder := SessionTransport.new()
	var expected: Dictionary = CaptureBefore.capture(world)
	_check(not expected.is_empty() and var_to_bytes(expected) == var_to_bytes(CaptureBefore.capture(fixture.worlds.legacy)), "frozen E16 exact legacy/sealed fixture authority")
	if expected.is_empty(): return {}
	var expected_bytes: PackedByteArray = var_to_bytes(expected)
	var expected_publication: Dictionary = _capture_publish(expected, session, encoder)
	_check(expected_publication.size() == 3 and not expected_publication.get("packets", []).is_empty(), "frozen complete publication succeeds")
	if expected_publication.is_empty(): return {}
	var expected_publication_bytes: PackedByteArray = var_to_bytes(expected_publication)
	var actual_publication: Dictionary = SessionTransport._capture_session_packets(session)
	_check(not actual_publication.is_empty() and var_to_bytes(actual_publication.envelope) == var_to_bytes(expected_publication.envelope) and var_to_bytes(actual_publication.packets) == var_to_bytes(expected_publication.packets), "actual production factory has identical complete envelope/packet bytes")
	var source_before: PackedByteArray = _publication_source_bytes(session)
	var chemistry: Dictionary = CaptureBefore.ChemistrySnapshot._capture_for_outer_roundtrip(world.hex_court)
	var packed: Dictionary = CaptureBefore.WirePacking.pack(chemistry, world.hex_court.cell_count())
	_check(not chemistry.is_empty() and not packed.is_empty() and var_to_bytes(CaptureBefore._inflate_hex(expected.hex)) == var_to_bytes(packed), "frozen stage inputs describe exact captured chemistry")
	var stage_inputs: PackedByteArray = var_to_bytes([expected, expected_publication, chemistry, packed])
	var memory_before: Dictionary = _memory()
	var stages: Dictionary = _capture_substages(world, expected, chemistry, packed)
	var pairs: Dictionary = {}
	var checks: Dictionary = {}
	for operation: String in CAPTURE_OPERATIONS:
		pairs[operation] = _capture_pairs(operation, session, encoder, expected_bytes if operation == "capture" else expected_publication_bytes, source_before, offset)
		var complete: bool = _capture_pairs_complete(pairs[operation], offset)
		checks[operation + "_exact"] = complete
		_check(complete, "capture pair complete before statistics reporting")
		if complete:
			print("CAPTURE_PAIR %s %s frozen_p50_us=%d candidate_p50_us=%d" % [label, operation, pairs[operation].frozen.statistics_us.p50, pairs[operation].candidate.statistics_us.p50])
	var frozen_snapshot: Dictionary = CaptureBefore.capture(world)
	var candidate_snapshot: Dictionary = HexWorldSnapshot.capture(world)
	var left: SimWorld = HexWorldSnapshot.prepare(frozen_snapshot, world)
	var right: SimWorld = HexWorldSnapshot.prepare(candidate_snapshot, world)
	checks.current_strict_prepare = left != null and right != null and left.state_hash() == world.state_hash() and right.state_hash() == world.state_hash()
	checks.topology_ownership = checks.current_strict_prepare and left.hex_court != world.hex_court and right.hex_court != world.hex_court and left.hex_court != right.hex_court \
		and left.hex_court.immutable_topology() == world.hex_court.immutable_topology() and right.hex_court.immutable_topology() == world.hex_court.immutable_topology()
	var continuation: bool = bool(checks.current_strict_prepare)
	var continuation_trace := HashingContext.new()
	continuation_trace.start(HashingContext.HASH_SHA256)
	if continuation:
		continuation = _collision_descriptor(left.collision) == _collision_descriptor(right.collision)
		for unused: int in 16:
			var commands: Array[SimCommand] = _commands(left, fixture.targets, "dense-crucible", false, false)
			continuation = left.step(commands) and right.step(commands) and left.state_hash() == right.state_hash() and left.combat_events == right.combat_events and continuation
			continuation_trace.update((left.state_hash() + JSON.stringify(FrozenHash._stable_original(left.combat_events))).to_utf8_buffer())
	checks.continuation = continuation
	checks.source_unchanged = _publication_source_bytes(session) == source_before and _storage_modes_valid(fixture.worlds) and var_to_bytes([expected, expected_publication, chemistry, packed]) == stage_inputs
	for key: String in CAPTURE_CHECKS: _check(bool(checks[key]), label + " " + key)
	return {
		"case": label, "actors": world.players.size(), "topology_cells": world.hex_court.cell_count(), "tick": world.tick,
		"paid_steps": fixture.paid_steps, "paid_metrics": world.hex_court.metrics.duplicate(true), "active_ramparts": _active_ramparts(world.hex_court, world.tick),
		"state_hash": String(expected.state_hash), "trace_sha256": fixture.trace_sha256, "snapshot_bytes": expected_bytes.size(), "snapshot_sha256": CanonicalBytes.sha256_hex(expected_bytes),
		"publication_sha256": CanonicalBytes.sha256_hex(expected_publication_bytes), "published_events": expected_publication.envelope.session.events.size(),
		"wire": _publication_wire_evidence(expected_publication.encoded), "continuation_steps": 16 if continuation else 0, "continuation_sha256": continuation_trace.finish().hex_encode(),
		"checks": checks, "substages": stages, "operations": pairs, "memory_before": memory_before, "memory_after": _memory(),
	}


func _capture_publish(snapshot: Dictionary, session: AuthoritativeSession, encoder: SessionTransport) -> Dictionary:
	if snapshot.is_empty(): return {}
	var metadata: Dictionary = AuthoritativeSession._capture_hex_session_metadata(session)
	if metadata.is_empty(): return {}
	var envelope: Dictionary = PublicationEnvelope.wrap_hex(snapshot, metadata, session.world_epoch)
	if envelope.is_empty(): return {}
	session.snapshot_capture_pending_ack = true
	var packets: Array[Dictionary] = SessionTransport._envelope_wire_packets(envelope)
	return {"envelope": envelope, "packets": packets, "encoded": _publication_encode(encoder, packets)}


func _capture_pair_value(operation: String, arm: String, session: AuthoritativeSession, encoder: SessionTransport) -> Dictionary:
	var snapshot: Dictionary = CaptureBefore.capture(session.world) if arm == "frozen" else HexWorldSnapshot.capture(session.world)
	return snapshot if operation == "capture" else _capture_publish(snapshot, session, encoder)


func _capture_pairs(operation: String, session: AuthoritativeSession, encoder: SessionTransport, expected_bytes: PackedByteArray, source_before: PackedByteArray, offset: int) -> Dictionary:
	var observations: Dictionary = {"frozen": PackedInt64Array(), "candidate": PackedInt64Array()}
	var exact: bool = true
	for arm: String in COLLISION_ARMS:
		_check(var_to_bytes(_capture_pair_value(operation, arm, session, encoder)) == expected_bytes, "untimed capture pipeline warmup " + operation + " " + arm)
	var rows: Array[Dictionary] = []
	for index: int in PUBLICATION_SAMPLES:
		var order: Array[String] = _collision_order(index + offset)
		var row: Dictionary = {"order": order.duplicate(), "samples_us": {}}
		for arm: String in order:
			var started: int = Time.get_ticks_usec()
			var value: Dictionary = _capture_pair_value(operation, arm, session, encoder)
			var elapsed: int = Time.get_ticks_usec() - started
			var samples: PackedInt64Array = observations[arm]
			samples.append(elapsed)
			observations[arm] = samples
			row.samples_us[arm] = elapsed
			var matches: bool = var_to_bytes(value) == expected_bytes
			exact = matches and exact
			_check(matches, "timed " + operation + " " + arm + " exact full bytes")
			_check(_publication_source_bytes(session) == source_before, "timed observer preserves complete source/session")
		rows.append(row)
	return {"frozen": _stats(observations.frozen), "candidate": _stats(observations.candidate), "pairs": rows, "exact": exact}


func _capture_substages(world: SimWorld, snapshot: Dictionary, chemistry: Dictionary, packed: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for stage: String in CAPTURE_STAGES:
		var samples := PackedInt64Array()
		for index: int in PUBLICATION_SAMPLES + 1:
			# ProducerRoundtrip is single-use. Set up its witness outside the
			# reconstruction timer, matching its earlier position in capture.
			var producer: HexChemistrySnapshot.ProducerRoundtrip = null
			if stage == "full_reconstruct": producer = CaptureBefore.ChemistrySnapshot.ProducerRoundtrip.new(world.hex_court)
			var started: int = Time.get_ticks_usec()
			var value: Variant
			match stage:
				"packed_grammar": value = CaptureBefore.WirePacking.validate_structure(packed)
				"serialize_compress": value = var_to_bytes(packed).compress(FileAccess.COMPRESSION_DEFLATE)
				"inflate_parse": value = CaptureBefore._inflate_hex(snapshot.hex)
				"strict_decode": value = CaptureBefore.WirePacking.strict_decode(packed, world.hex_court.cell_count())
				"full_reconstruct": value = CaptureBefore._prepare_core(snapshot, world, producer)
			var elapsed: int = Time.get_ticks_usec() - started
			if index > 0: samples.append(elapsed)
			match stage:
				"packed_grammar": _check(typeof(value) == TYPE_BOOL and value, "old packed grammar accepts exact fixture")
				"serialize_compress": _check(value == snapshot.hex.bytes, "old compression bytes exact")
				"inflate_parse": _check(value is Dictionary and var_to_bytes(value) == var_to_bytes(packed), "old inflate/parse exact")
				"strict_decode": _check(value is Dictionary and var_to_bytes(value) == var_to_bytes(chemistry), "old strict packed decode exact")
				"full_reconstruct": _check(value != null and value.state_hash() == world.state_hash() and value.hex_court.immutable_topology() == world.hex_court.immutable_topology(), "old complete reconstruction exact with shared immutable topology")
		result[stage] = _stats(samples)
		print("CAPTURE_SUBSTAGE %s p50_us=%d" % [stage, result[stage].statistics_us.p50])
	return result


func _capture_samples_complete(value: Variant) -> bool:
	if not _canonical_keys(value, ["samples_us", "statistics_us"]) or not value.samples_us is Array or value.samples_us.size() != PUBLICATION_SAMPLES: return false
	for sample: Variant in value.samples_us:
		if not _publication_integer(sample, 1): return false
	return _publication_statistics_complete(value.statistics_us, value.samples_us)


func _capture_records_complete(records: Variant) -> bool:
	if not records is Array or records.size() != CASE_LABELS.size(): return false
	for offset: int in CASE_LABELS.size():
		var record: Variant = records[offset]
		if not record is Dictionary or record.get("case") != CASE_LABELS[offset] or record.get("actors") != 8 or record.get("topology_cells") != EXPECTED_TOPOLOGY_CELLS: return false
		if not _canonical_keys(record.get("checks"), CAPTURE_CHECKS): return false
		for key: String in CAPTURE_CHECKS:
			if record.checks[key] != true: return false
		for key: String in ["state_hash", "trace_sha256", "snapshot_sha256", "publication_sha256", "continuation_sha256"]:
			if not _hash_valid(record.get(key)): return false
		for key: String in ["tick", "paid_steps", "active_ramparts", "published_events"]:
			if not _publication_integer(record.get(key)): return false
		if record.get("continuation_steps") != 16 or not _publication_integer(record.get("snapshot_bytes"), 1) or record.snapshot_bytes > CaptureBefore.MAX_RAW_BYTES: return false
		if record.tick != WARMUP_TICKS + record.paid_steps or record.published_events > SessionSnapshot.MAX_EVENTS: return false
		if offset == 0 and record.paid_steps != 0: return false
		if offset in [1, 2] and record.paid_steps != 40: return false
		if offset == 3 and (record.paid_steps < 1 or record.paid_steps > RAMPART_STEP_LIMIT or record.active_ramparts < 1): return false
		if not record.get("paid_metrics") is Dictionary: return false
		if offset > 0 and (record.paid_metrics.get("admitted", 0) <= 0 or record.paid_metrics.get("matter_paid", 0) <= 0): return false
		if not _publication_wire_complete(record.get("wire")) or not _canonical_keys(record.get("substages"), CAPTURE_STAGES) or not _canonical_keys(record.get("operations"), CAPTURE_OPERATIONS): return false
		for stage: String in CAPTURE_STAGES:
			if not _capture_samples_complete(record.substages[stage]): return false
		for operation: String in CAPTURE_OPERATIONS:
			if not _capture_pairs_complete(record.operations[operation], offset): return false
	return true


func _capture_pairs_complete(paired: Variant, offset: int) -> bool:
	if not _canonical_keys(paired, ["frozen", "candidate", "pairs", "exact"]) or paired.exact != true or not paired.pairs is Array or paired.pairs.size() != PUBLICATION_SAMPLES: return false
	for arm: String in COLLISION_ARMS:
		if not _capture_samples_complete(paired[arm]): return false
	for index: int in PUBLICATION_SAMPLES:
		var row: Variant = paired.pairs[index]
		if not _canonical_keys(row, ["order", "samples_us"]) or row.order != _collision_order(index + offset) or not _canonical_keys(row.samples_us, COLLISION_ARMS): return false
		for arm: String in COLLISION_ARMS:
			if not _publication_integer(row.samples_us[arm], 1) or row.samples_us[arm] != paired[arm].samples_us[index]: return false
	return true


func _capture_receipt_valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("profile_version") != CAPTURE_PROFILE_VERSION or value.get("samples") != PUBLICATION_SAMPLES: return false
	if value.get("diagnostic_status") != "PASS" or value.get("failures") != 0 or value.get("receipt_complete") != true or value.get("sources_unchanged") != true: return false
	if not value.get("source_sha256_before") is Dictionary or not value.get("source_sha256_after") is Dictionary or not _hashes_valid(value.source_sha256_before): return false
	if value.source_sha256_before != value.source_sha256_after or value.source_sha256_before.get(CAPTURE_ORACLE_PATH) != CAPTURE_ORACLE_SHA256 or not value.source_sha256_before.has(CAPTURE_PROFILE_PATH): return false
	return _capture_records_complete(value.get("records"))


func _capture_receipt_guards(receipt: Dictionary) -> void:
	if not _capture_receipt_valid(receipt):
		_check(false, "valid receipt before negative capture guards")
		return
	for mutation: String in ["case", "stage", "sample", "fractional", "statistic", "statistic-extra", "pair", "order", "ownership", "continuation", "wire", "source", "oracle"]:
		var broken: Dictionary = receipt.duplicate(true)
		match mutation:
			"case": broken.records.pop_back()
			"stage": broken.records[0].substages.erase("inflate_parse")
			"sample": broken.records[0].substages.packed_grammar.samples_us.pop_back()
			"fractional": broken.records[0].substages.packed_grammar.statistics_us.p50 += 0.5
			"statistic": broken.records[0].substages.packed_grammar.statistics_us.p50 = true
			"statistic-extra": broken.records[0].substages.packed_grammar.statistics_us["extra"] = 0
			"pair": broken.records[0].operations.capture.pairs.pop_back()
			"order": broken.records[0].operations.capture.pairs[0].order.reverse()
			"ownership": broken.records[0].checks.topology_ownership = false
			"continuation": broken.records[0].continuation_steps = 15
			"wire": broken.records[0].wire.total_bytes = -1
			"source": broken.sources_unchanged = false
			"oracle": broken.source_sha256_before[CAPTURE_ORACLE_PATH] = "0".repeat(64)
		_check(not _capture_receipt_valid(broken), "native receipt rejects " + mutation)
		_check(not _capture_receipt_valid(JSON.parse_string(JSON.stringify(broken))), "JSON receipt rejects " + mutation)


func _capture_sources() -> Dictionary:
	var result: Dictionary = _publication_sources()
	for path: String in [CAPTURE_PROFILE_PATH, CAPTURE_ORACLE_PATH]: result[path] = FileAccess.get_sha256("res://" + path)
	return result
