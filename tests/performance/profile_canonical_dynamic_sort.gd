extends "res://tests/performance/profile_capture_pipeline.gd"

const SortBefore = preload("res://tests/support/hex_dynamic_sort_pre_native.gd")
const SortOracle = preload("res://tests/support/hex_canonical_pre_e9.gd")
const SortCurrent = preload("res://src/sim/hex/hex_canonical_state.gd")
const SortThreshold = preload("res://tests/support/hex_dynamic_sort_threshold_candidate.gd")
const SORT_BASELINE_PATH := "tests/support/hex_dynamic_sort_pre_native.gd"
const SORT_BASELINE_SHA256 := "5022abe9ff49a00686cd72a90d1acf12bc96fa1cebb1924f0e478648a81f4644"
const SORT_PROFILE_PATH := "tests/performance/profile_canonical_dynamic_sort.gd"
const SORT_VERSION := "canonical-dynamic-sort-v3"
const SORT_THRESHOLDS: Array[int] = [4, 8, 16]
const SORT_MAP_TYPES: Array[String] = ["empty", "string", "int", "vector2i", "mixed", "other"]
const SORT_OBSERVATIONS: Array[String] = ["chemistry_hash", "world_capture"]
const SORT_CHECKS: Array[String] = ["dynamic_bytes_exact", "whole_state_exact", "capture_restores", "source_unchanged"]


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output_path = argument.trim_prefix("--output=")
		else: _check(false, "unknown dynamic sort profile argument")
	_check(output_path.begins_with("res://.godot/canonical-dynamic-sort-") and output_path.ends_with(".json") and output_path.get_base_dir() == "res://.godot" and not ".." in output_path and not FileAccess.file_exists(output_path), "fresh scoped dynamic sort receipt")
	var before := _sort_sources()
	_check(_hashes_valid(before) and before[SORT_BASELINE_PATH] == SORT_BASELINE_SHA256, "complete sources and frozen immediately preceding sorter")
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "actual abilities load")
	_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "actual champions load")
	_check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "actual campus loads")
	definition = HexWorldDefinition.from_campus(layout)
	_check(definition != null and definition.eligible_cells.size() == EXPECTED_TOPOLOGY_CELLS, "actual 11337-cell campus")
	if failures > 0:
		quit(1)
		return
	var records: Array[Dictionary] = []
	for offset: int in CASE_LABELS.size(): records.append(_sort_case(CASE_LABELS[offset], offset))
	var after := _sort_sources()
	_check(before == after, "sources unchanged throughout dynamic sort profile")
	var receipt := {
		"profile_version": SORT_VERSION, "engine": Engine.get_version_info().get("string", ""),
		"source_sha256_before": before, "source_sha256_after": after, "sources_unchanged": before == after,
		"samples": PUBLICATION_SAMPLES, "records": records, "thresholds": SORT_THRESHOLDS.duplicate(),
		"scope": "Seven alternating case-counterbalanced old/current dynamic canonical conversion pairs on the SAME actual eight-champion, 11337-cell empty/distributed-paid40/dense-paid40/active-Rampart fixtures. The inputs are the live header and seven dynamic authority lanes used by the production canonical stream, without a materialized full-cell compatibility view.",
		"paired_timing": "Each pair times conversion of each dynamic/header lane by the frozen immediately preceding sorter or production HexChemistryWorld._stable, followed by JSON.stringify and UTF-8 conversion. The production specialized cell-row writer and cached topology stream are excluded. No per-call input clones or memoized dynamic state. This isolates the changed sorter in actual nested authority, NOT complete state_hash, capture or publication speedup.",
		"current_observations": "Separate candidate-only chemistry_hash and world_capture observations run after all paired samples. They use actual complete production APIs, include fresh preparation where the API owns it, and overlap. They have NO same-process old full-pipeline arm and must not be reported as a paired speedup, summed, or compared as exclusive stages.",
		"adaptive_pairs": "Test-only per-map thresholds4/8/16 retain the immediately preceding comparator below the threshold while recursively selecting every child independently. Seven alternating frozen/adaptive pairs per threshold; threshold-block order rotates by fixture. Comparisons include only dynamic conversion/JSON, not the production specialized cell row writer. Exact map-type/count histograms count traversal occurrences, including repeated aliases, rather than unique object identities. Histogram collection/recheck is outside timers. Thresholds are experimental, not selected production policy.",
		"checks": "Independent original naive stable comparator checks dynamic bytes; independent pre-E9 whole-document oracle checks full canonical bytes/hash. Strict production prepare restores each captured result; source/session bytes and separate legacy-storage twin remain unchanged. Setup, independent oracles, checks, statistics and sample bookkeeping are outside timers.",
		"limits": "Warm diagnostic samples only. p95/p99 are seven-sample maxima, not sustained tails. No rendered, network, full-session, 60Hz publication, 120Hz simulation or player-capacity acceptance. Use a separate frozen-source pre/post publication/load comparison for end-to-end effect.",
		"performance_acceptance": "NOT_ESTABLISHED",
	}
	receipt.receipt_complete = _sort_records_complete(records)
	receipt.diagnostic_status = "PASS" if failures == 0 else "FAIL"
	receipt.failures = failures
	_check(_sort_receipt_valid(receipt), "complete native dynamic sort receipt")
	_check(_sort_receipt_valid(JSON.parse_string(JSON.stringify(receipt))), "complete serialized dynamic sort receipt")
	_sort_guards(receipt)
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	_check(output != null, "dynamic sort receipt opens")
	if output != null:
		receipt.assertions = assertions
		receipt.failures = failures
		receipt.diagnostic_status = "PASS" if failures == 0 else "FAIL"
		output.store_string(JSON.stringify(receipt, "\t") + "\n")
		output.close()
	print("%s: canonical-dynamic-sort; %d assertions; %d failures; output=%s" % ["PASS" if failures == 0 else "FAIL", assertions, failures, output_path])
	quit(1 if failures > 0 else 0)


func _sort_case(label: String, offset: int) -> Dictionary:
	print("DYNAMIC_SORT_FIXTURE " + label)
	var fixture := _collision_fixture(label)
	if fixture.is_empty(): return {}
	var world: SimWorld = fixture.worlds.sealed
	var session := _publication_session(world)
	var source_before := _publication_source_bytes(session)
	var expected_whole := SortOracle.state_bytes(world.hex_court)
	var expected_hash := SortOracle.hash_bytes(expected_whole)
	var expected_world_hash := world.state_hash()
	var lanes := _sort_lanes(world.hex_court)
	var histogram := _sort_histogram(lanes)
	var original: Array = []
	for lane: Variant in lanes: original.append(SortOracle._stable(lane))
	var expected_dynamic := JSON.stringify(original).to_utf8_buffer()
	var checks := {"dynamic_bytes_exact": true, "whole_state_exact": true, "capture_restores": true, "source_unchanged": true}
	checks.whole_state_exact = SortCurrent.canonical_bytes(world.hex_court) == expected_whole \
		and world.hex_court.state_hash() == expected_hash and SortOracle.state_bytes(fixture.worlds.legacy.hex_court) == expected_whole
	for arm: String in COLLISION_ARMS: _check(_sort_dynamic_bytes(arm, lanes) == expected_dynamic, "untimed exact dynamic conversion warmup " + arm)
	var samples := {"frozen": PackedInt64Array(), "candidate": PackedInt64Array()}
	var pairs: Array[Dictionary] = []
	for index: int in PUBLICATION_SAMPLES:
		var order := _collision_order(index + offset)
		var row := {"order": order.duplicate(), "samples_us": {}}
		for arm: String in order:
			var started := Time.get_ticks_usec()
			var actual := _sort_dynamic_bytes(arm, lanes)
			var elapsed := Time.get_ticks_usec() - started
			var observations: PackedInt64Array = samples[arm]
			observations.append(elapsed)
			samples[arm] = observations
			row.samples_us[arm] = elapsed
			checks.dynamic_bytes_exact = bool(checks.dynamic_bytes_exact) and actual == expected_dynamic
			_check(actual == expected_dynamic, label + " " + arm + " exact dynamic bytes")
		pairs.append(row)
		var source_exact := _publication_source_bytes(session) == source_before and _storage_modes_valid(fixture.worlds)
		checks.source_unchanged = bool(checks.source_unchanged) and source_exact
		_check(source_exact, label + " alternating pair preserves authority/session bytes and storage")
	var paired := {"frozen": _stats(samples.frozen), "candidate": _stats(samples.candidate), "pairs": pairs, "exact": bool(checks.dynamic_bytes_exact)}
	_check(_capture_pairs_complete(paired, offset), label + " complete exact dynamic pair samples")
	var adaptive := {}
	var threshold_order: Array[int] = []
	for position: int in SORT_THRESHOLDS.size():
		var threshold_index := (position + offset) % SORT_THRESHOLDS.size()
		var threshold := SORT_THRESHOLDS[threshold_index]
		threshold_order.append(threshold)
		adaptive[str(threshold)] = _sort_threshold_pairs(lanes, expected_dynamic, threshold, offset + threshold_index + 1, label)
	_check(_sort_histogram(lanes) == histogram, label + " actual dictionary distribution unchanged after all sorter arms")
	var current_stages := {}
	for operation: String in SORT_OBSERVATIONS:
		var observations := PackedInt64Array()
		for index: int in PUBLICATION_SAMPLES:
			var started := Time.get_ticks_usec()
			var result: Variant = world.hex_court.state_hash() if operation == "chemistry_hash" else HexWorldSnapshot.capture(world)
			observations.append(Time.get_ticks_usec() - started)
			if operation == "chemistry_hash":
				checks.whole_state_exact = bool(checks.whole_state_exact) and result == expected_hash
				_check(result == expected_hash, label + " current complete chemistry hash")
			else:
				var prepared: SimWorld = HexWorldSnapshot.prepare(result, world)
				var restored := prepared != null and prepared.state_hash() == expected_world_hash and SortOracle.state_bytes(prepared.hex_court) == expected_whole
				checks.capture_restores = bool(checks.capture_restores) and restored
				_check(restored, label + " current complete capture strictly reconstructs exact authority")
		current_stages[operation] = _stats(observations)
	checks.source_unchanged = bool(checks.source_unchanged) and _publication_source_bytes(session) == source_before and _storage_modes_valid(fixture.worlds)
	for key: String in SORT_CHECKS: _check(bool(checks[key]), label + " " + key)
	print("DYNAMIC_SORT_PAIR %s frozen_p50_us=%d candidate_p50_us=%d" % [label, paired.frozen.statistics_us.p50, paired.candidate.statistics_us.p50])
	return {
		"case": label, "actors": world.players.size(), "topology_cells": world.hex_court.cell_count(),
		"tick": world.tick, "paid_steps": fixture.paid_steps, "paid_metrics": world.hex_court.metrics.duplicate(true),
		"active_ramparts": _active_ramparts(world.hex_court, world.tick), "trace_sha256": fixture.trace_sha256,
		"state_hash": expected_world_hash, "chemistry_hash": expected_hash, "canonical_bytes": expected_whole.size(),
		"dynamic_bytes": expected_dynamic.size(), "dynamic_sha256": CanonicalBytes.sha256_hex(expected_dynamic),
		"checks": checks, "paired_dynamic_conversion": paired, "current_only_observations": current_stages,
		"map_histogram": histogram, "threshold_order": threshold_order, "adaptive_pairs": adaptive,
	}


func _sort_lanes(world: HexChemistryWorld) -> Array:
	return [world.origin, world.current_tick, world.chemistry_enabled, world.next_cast_id,
		world.next_product_id, world.next_ground_part_id, world.casts, world.products,
		world.pending, world.sources, world.exposure, world.flow_carry, world.metrics]


func _sort_dynamic_bytes(arm: String, lanes: Array) -> PackedByteArray:
	var stable: Array = []
	for lane: Variant in lanes:
		stable.append(SortBefore.stable(lane) if arm == "frozen" else HexChemistryWorld._stable(lane))
	return JSON.stringify(stable).to_utf8_buffer()


func _sort_threshold_pairs(lanes: Array, expected: PackedByteArray, threshold: int, offset: int, label: String) -> Dictionary:
	var samples := {"frozen": PackedInt64Array(), "candidate": PackedInt64Array()}
	var pairs: Array[Dictionary] = []
	var exact := true
	# Warm this helper outside timing, just as the production/frozen pair is warm.
	var warm: Array = []
	for lane: Variant in lanes: warm.append(SortThreshold.stable(lane, threshold))
	_check(JSON.stringify(warm).to_utf8_buffer() == expected, label + " threshold %d exact warmup" % threshold)
	for index: int in PUBLICATION_SAMPLES:
		var order := _collision_order(index + offset)
		var row := {"order": order.duplicate(), "samples_us": {}}
		for arm: String in order:
			var started := Time.get_ticks_usec()
			var stable: Array = []
			for lane: Variant in lanes:
				stable.append(SortBefore.stable(lane) if arm == "frozen" else SortThreshold.stable(lane, threshold))
			var actual := JSON.stringify(stable).to_utf8_buffer()
			var elapsed := Time.get_ticks_usec() - started
			var observations: PackedInt64Array = samples[arm]
			observations.append(elapsed)
			samples[arm] = observations
			row.samples_us[arm] = elapsed
			exact = exact and actual == expected
			_check(actual == expected, label + " threshold %d %s exact bytes" % [threshold, arm])
		pairs.append(row)
	var paired := {"frozen": _stats(samples.frozen), "candidate": _stats(samples.candidate), "pairs": pairs, "exact": exact}
	_check(_capture_pairs_complete(paired, offset), label + " threshold %d complete alternating pairs" % threshold)
	print("DYNAMIC_SORT_THRESHOLD %s minimum_count=%d frozen_p50_us=%d candidate_p50_us=%d" % [label, threshold, paired.frozen.statistics_us.p50, paired.candidate.statistics_us.p50])
	return paired


func _sort_histogram(lanes: Array) -> Dictionary:
	var result := {"dictionary_occurrences": 0, "entry_occurrences": 0, "by_type_and_count": {}}
	for type_name: String in SORT_MAP_TYPES: result.by_type_and_count[type_name] = {}
	_sort_count_maps(lanes, result)
	return result


func _sort_count_maps(value: Variant, result: Dictionary) -> void:
	if value is Dictionary:
		var type_name := "empty"
		if not value.is_empty():
			var keys: Array = value.keys()
			var key_type := typeof(keys[0])
			var homogeneous := true
			for key: Variant in keys:
				if typeof(key) != key_type: homogeneous = false
			type_name = "mixed" if not homogeneous else "string" if key_type == TYPE_STRING else "int" if key_type == TYPE_INT else "vector2i" if key_type == TYPE_VECTOR2I else "other"
		var counts: Dictionary = result.by_type_and_count[type_name]
		var size_key := str(value.size())
		counts[size_key] = int(counts.get(size_key, 0)) + 1
		result.dictionary_occurrences += 1
		result.entry_occurrences += value.size()
		for key: Variant in value:
			_sort_count_maps(key, result)
			_sort_count_maps(value[key], result)
	elif value is Array:
		for child: Variant in value: _sort_count_maps(child, result)


func _sort_histogram_valid(value: Variant) -> bool:
	if not _canonical_keys(value, ["dictionary_occurrences", "entry_occurrences", "by_type_and_count"]): return false
	if not _publication_integer(value.dictionary_occurrences) or not _publication_integer(value.entry_occurrences) or not _canonical_keys(value.by_type_and_count, SORT_MAP_TYPES): return false
	var dictionaries := 0
	var entries := 0
	for type_name: String in SORT_MAP_TYPES:
		var counts: Variant = value.by_type_and_count[type_name]
		if not counts is Dictionary: return false
		for key: Variant in counts:
			if not key is String or not key.is_valid_int() or str(key.to_int()) != key or key.to_int() < 0 or not _publication_integer(counts[key], 1): return false
			if (type_name == "empty") != (key == "0"): return false
			dictionaries += int(counts[key])
			entries += int(counts[key]) * key.to_int()
	return dictionaries == value.dictionary_occurrences and entries == value.entry_occurrences


func _sort_records_complete(records: Variant) -> bool:
	if not records is Array or records.size() != CASE_LABELS.size(): return false
	for offset: int in CASE_LABELS.size():
		var record: Variant = records[offset]
		if not record is Dictionary or record.get("case") != CASE_LABELS[offset] or record.get("actors") != 8 or record.get("topology_cells") != EXPECTED_TOPOLOGY_CELLS: return false
		if not _canonical_keys(record.get("checks"), SORT_CHECKS): return false
		for key: String in SORT_CHECKS:
			if record.checks[key] != true: return false
		for key: String in ["state_hash", "trace_sha256", "chemistry_hash", "dynamic_sha256"]:
			if not _hash_valid(record.get(key)): return false
		for key: String in ["tick", "paid_steps", "active_ramparts"]:
			if not _publication_integer(record.get(key)): return false
		if record.tick != WARMUP_TICKS + record.paid_steps: return false
		for key: String in ["canonical_bytes", "dynamic_bytes"]:
			if not _publication_integer(record.get(key), 8): return false
		if offset == 0 and record.paid_steps != 0: return false
		if offset in [1, 2] and record.paid_steps != 40: return false
		if offset == 3 and (record.paid_steps < 1 or record.paid_steps > RAMPART_STEP_LIMIT or record.active_ramparts < 1): return false
		if not record.get("paid_metrics") is Dictionary: return false
		if offset > 0 and (record.paid_metrics.get("admitted", 0) <= 0 or record.paid_metrics.get("matter_paid", 0) <= 0): return false
		if not _capture_pairs_complete(record.get("paired_dynamic_conversion"), offset): return false
		if not _canonical_keys(record.get("current_only_observations"), SORT_OBSERVATIONS): return false
		for operation: String in SORT_OBSERVATIONS:
			if not _capture_samples_complete(record.current_only_observations[operation]): return false
		if not _sort_histogram_valid(record.get("map_histogram")) or not _canonical_keys(record.get("adaptive_pairs"), ["4", "8", "16"]): return false
		var expected_order: Array[int] = []
		for position: int in SORT_THRESHOLDS.size(): expected_order.append(SORT_THRESHOLDS[(position + offset) % SORT_THRESHOLDS.size()])
		if not _sort_integer_array_matches(record.get("threshold_order"), expected_order): return false
		for index: int in SORT_THRESHOLDS.size():
			if not _capture_pairs_complete(record.adaptive_pairs[str(SORT_THRESHOLDS[index])], offset + index + 1): return false
	return true


func _sort_receipt_valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("profile_version") != SORT_VERSION or value.get("samples") != PUBLICATION_SAMPLES or not _sort_integer_array_matches(value.get("thresholds"), SORT_THRESHOLDS): return false
	if value.get("diagnostic_status") != "PASS" or value.get("failures") != 0 or value.get("receipt_complete") != true or value.get("sources_unchanged") != true: return false
	if not value.get("source_sha256_before") is Dictionary or not value.get("source_sha256_after") is Dictionary or not _hashes_valid(value.source_sha256_before): return false
	if value.source_sha256_before != value.source_sha256_after or value.source_sha256_before.get(SORT_BASELINE_PATH) != SORT_BASELINE_SHA256 or not value.source_sha256_before.has(SORT_PROFILE_PATH): return false
	return _sort_records_complete(value.get("records"))


func _sort_integer_array_matches(value: Variant, expected: Array[int]) -> bool:
	# JSON.parse_string uses floating-point numbers and untyped Arrays. Compare
	# the exact integer domain element-by-element instead of container typing.
	# Reject booleans, strings, fractions and nonfinite values before conversion.
	if not value is Array or value.size() != expected.size(): return false
	for index: int in expected.size():
		if not _publication_integer(value[index]) or int(value[index]) != expected[index]: return false
	return true


func _sort_guards(receipt: Dictionary) -> void:
	if not _sort_receipt_valid(receipt): return
	for mutation: String in ["case", "sample", "fractional", "order", "bytes", "restore", "source", "oracle", "observation", "adaptive", "threshold-order", "histogram", "threshold-fractional", "threshold-bool", "threshold-string", "threshold-missing", "threshold-extra", "order-fractional", "order-bool", "order-string"]:
		var broken: Dictionary = receipt.duplicate(true)
		match mutation:
			"case": broken.records.pop_back()
			"sample": broken.records[0].paired_dynamic_conversion.frozen.samples_us.pop_back()
			"fractional": broken.records[0].paired_dynamic_conversion.candidate.statistics_us.p50 += 0.5
			"order": broken.records[0].paired_dynamic_conversion.pairs[0].order.reverse()
			"bytes": broken.records[0].checks.dynamic_bytes_exact = false
			"restore": broken.records[0].checks.capture_restores = false
			"source": broken.sources_unchanged = false
			"oracle": broken.source_sha256_before[SORT_BASELINE_PATH] = "0".repeat(64)
			"observation": broken.records[0].current_only_observations.world_capture.samples_us.pop_back()
			"adaptive": broken.records[0].adaptive_pairs["8"].exact = false
			"threshold-order": broken.records[0].threshold_order.reverse()
			"histogram": broken.records[0].map_histogram.dictionary_occurrences += 1
			"threshold-fractional": broken.thresholds = [4, 8.5, 16]
			"threshold-bool": broken.thresholds = [4, true, 16]
			"threshold-string": broken.thresholds = ["4", 8, 16]
			"threshold-missing": broken.thresholds = [4, 8]
			"threshold-extra": broken.thresholds = [4, 8, 16, 32]
			"order-fractional": broken.records[0].threshold_order = [4, 8.5, 16]
			"order-bool": broken.records[0].threshold_order = [4, true, 16]
			"order-string": broken.records[0].threshold_order = ["4", 8, 16]
		_check(not _sort_receipt_valid(broken), "native dynamic sort receipt rejects " + mutation)
		_check(not _sort_receipt_valid(JSON.parse_string(JSON.stringify(broken))), "JSON dynamic sort receipt rejects " + mutation)


func _sort_sources() -> Dictionary:
	var result := _capture_sources()
	for path: String in [SORT_PROFILE_PATH, SORT_BASELINE_PATH, "tests/unit/test_hex_canonical_sort.gd", "tests/support/hex_canonical_pre_e9.gd", "tests/support/hex_dynamic_sort_threshold_candidate.gd"]:
		result[path] = FileAccess.get_sha256("res://" + path)
	return result
