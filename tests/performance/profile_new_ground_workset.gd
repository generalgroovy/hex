extends SceneTree
@warning_ignore_start("integer_division")
## Synthetic scheduling work over real paid fields; not admitted player capacity.

const Fixture = preload("res://tests/unit/test_hex_new_ground_workset.gd")
const Workset = preload("res://src/sim/hex/hex_contact_workset.gd")
const PATH_COUNTS := [8, 32, 128]
const FIELD_COUNT := 8
const FIRST_SOURCE := 8401
const WARMUPS := 20
const SAMPLES := 60
const SOURCE_PATHS := [
	"tests/performance/profile_new_ground_workset.gd", "tests/unit/test_hex_new_ground_workset.gd",
	"src/sim/hex/hex_projectile_combat.gd", "src/sim/hex/hex_contact_workset.gd",
	"src/sim/hex/hex_chemistry_world.gd", "src/sim/hex/hex_cast_parts.gd",
	"src/sim/hex/hex_trail_emitter.gd", "src/sim/hex/hex_footprint.gd",
	"src/sim/hex/hex_grid.gd", "src/sim/hex/hex_recipe_policy.gd",
	"src/sim/combat/strength_budget.gd", "src/sim/combat/combat_tuning.gd",
	"content/abilities/foundation_abilities_v1.json",
]

var fixture_suite := Fixture.new()
var assertions := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var output := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	_check(output.begins_with("res://.godot/new-ground-workset-profile-") and output.ends_with(".json") and not ".." in output and not FileAccess.file_exists(output), "fresh contained receipt required")
	if failures > 0: quit(1); return
	var sources_before := _source_hashes()
	for path: String in sources_before:
		_check(String(sources_before[path]).length() == 64, "source hash exists: " + path)
	var catalog := AbilityCatalog.new()
	_check(catalog.load_from_file(Fixture.ABILITY_PATH), "production paid definitions load")
	if failures > 0: quit(1); return
	var setup_started := Time.get_ticks_usec()
	var fixture: Dictionary = fixture_suite._world()
	_check(fixture.get("world") is SimWorld and fixture.get("court") is HexChemistryWorld, "real unified fixture was constructed")
	if failures > 0: quit(1); return
	var world: SimWorld = fixture.world
	var court: HexChemistryWorld = fixture.court
	for index: int in FIELD_COUNT:
		fixture_suite._field(court, catalog, index + 1, FIRST_SOURCE + index, court.origin + Vector2i(index * 120_000 - 420_000, 0))
	_check(fixture_suite.failures == 0, "all reserve/pay/bind/deposit fixture assertions pass")
	_check(court.conservation_valid() and court.products.is_empty() and int(court.metrics.reactions) == 0, "eight separated paid fields remain conserved and unreacted")
	_check(HexProjectileCombat._ground_fields(world).size() == FIELD_COUNT, "all eight live fields enter the scheduling workload")
	if failures > 0: quit(1); return
	var setup_us := Time.get_ticks_usec() - setup_started
	var state_before := world.state_hash()
	var cases: Array[Dictionary] = []
	for count: int in PATH_COUNTS:
		var row := _measure(world, count)
		_check(_case_complete(row, count), "complete case schema, samples, counts and equality: %d paths" % count)
		cases.append(row)
		print("NEW_GROUND_WORKSET_PROFILE paths=%d cases=%d failures=%d" % [count, cases.size(), failures])
		if failures > 0: break
	var complete := _cases_complete(cases)
	_check(complete, "all three expected cases completed every warmup and measured pair")
	_check(world.state_hash() == state_before and court.conservation_valid(), "profiling never mutated paid authority")
	_check(sources_before == _source_hashes(), "profiled source stayed unchanged")
	var receipt := {
		"schema_version": 1, "diagnostic_version": "new-ground-workset-cpu-pairs-v1",
		"status": "passed" if failures == 0 else "failed", "complete_case_set": complete,
		"engine": Engine.get_version_info(),
		"hardware": {"os": OS.get_name(), "cpu": OS.get_processor_name(), "logical_processors": OS.get_processor_count(), "display_server": DisplayServer.get_name()},
		"settings": {"paid_fields": FIELD_COUNT, "path_counts": PATH_COUNTS, "warmup_pairs_per_case": WARMUPS, "measured_pairs_per_case": SAMPLES, "order": "ABBA repeated; rotating source order across each eight-pair block", "formation_time": 0.0, "preexisting_queue_events": 3},
		"setup_us_excluded": setup_us, "state_sha256": state_before, "cases": cases,
		"source_sha256": sources_before, "assertions": assertions, "fixture_assertions": fixture_suite.assertions, "failures": failures,
		"scope": "Synthetic path-scheduling CPU diagnostic over eight production-reserved, paid, released and deposited ground sources. 8/32/128 are prospective path dictionaries, not players, admitted projectiles or a legal larger simulated lobby. No authority, geometry, resource or capacity limits are changed.",
		"timing_semantics": "Both arms use Callable dispatch with identical plans, formation time, selected source and preseeded queue. Timers include the complete scheduling call: field preparation, plan probes, interval/witness work, filtering and queue insertion. Queue allocation/seeding, draining, complete event-byte comparison, immutable-state checks, fixture/source accounting and quantiles are outside timers. Counts for field preparation and interval candidates are structural expectations, checked by untimed live-field/contact enumeration, not invasive instrumentation.",
		"performance_acceptance": "NOT_ESTABLISHED. Same-process paired function cost only; not an end-to-end step/frame/network gain or supported player-capacity result. Verification outside timers can influence cache/allocation state in later samples.",
	}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null: push_error("Cannot open new-ground receipt: " + output); quit(1); return
	file.store_string(JSON.stringify(receipt, "\t") + "\n")
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK: push_error("Cannot finish new-ground receipt: " + output); quit(1); return
	print("NEW_GROUND_WORKSET_PROFILE %s: %d cases; %d assertions; output=%s" % ["PASS" if failures == 0 else "FAIL", cases.size(), assertions, output])
	quit(0 if failures == 0 else 1)


func _measure(world: SimWorld, count: int) -> Dictionary:
	var plans := _plans(world.hex_court.origin, count)
	var plan_bytes := var_to_bytes(plans)
	var state_before := world.state_hash()
	var source_contacts := {}
	for source: int in range(FIRST_SOURCE, FIRST_SOURCE + FIELD_COUNT): source_contacts[source] = 0
	for plan: Dictionary in plans:
		for contact: Dictionary in HexProjectileCombat._field_contacts(plan, world):
			var source := int(contact.field_source)
			_check(source_contacts.has(source), "preflight contacts refer to the eight admitted fields")
			if source_contacts.has(source): source_contacts[source] += 1
	for source: int in source_contacts:
		_check(int(source_contacts[source]) == count, "every synthetic path actually crosses source %d" % source)
	if failures > 0: return {}
	var calls: Array[Callable] = [fixture_suite._old_enqueue_new_ground, HexProjectileCombat._enqueue_new_ground]
	var reference_us := PackedInt64Array()
	var candidate_us := PackedInt64Array()
	var delta_us := PackedInt64Array()
	var measured_sources := {}
	var completed_pairs := 0
	var equal_queues := 0
	var inserted := 0
	for pair: int in range(WARMUPS + SAMPLES):
		var source := FIRST_SOURCE + (pair % FIELD_COUNT + pair / FIELD_COUNT) % FIELD_COUNT
		var order: Array[int] = [0, 1]
		if pair % 4 in [1, 2]: order.reverse()
		var outputs: Array[Dictionary] = [{}, {}]
		for arm: int in order:
			outputs[arm] = _batch(calls[arm], plans, source, world)
			_check(world.state_hash() == state_before and var_to_bytes(plans) == plan_bytes, "each scheduling arm leaves authority and plans unchanged")
		var reference: Array[Dictionary] = fixture_suite._drain_new_ground(outputs[0].queue)
		var candidate: Array[Dictionary] = fixture_suite._drain_new_ground(outputs[1].queue)
		_check(reference.size() == count + 3 and candidate.size() == count + 3, "both arms insert nonempty expected contact counts")
		_check(var_to_bytes(reference) == var_to_bytes(candidate), "complete ordered queues match byte-for-byte")
		if failures > 0: break
		completed_pairs += 1
		if pair < WARMUPS: continue
		reference_us.append(int(outputs[0].us)); candidate_us.append(int(outputs[1].us))
		delta_us.append(int(outputs[1].us) - int(outputs[0].us))
		measured_sources[source] = int(measured_sources.get(source, 0)) + 1
		equal_queues += 1
		inserted += candidate.size() - 3
	return {
		"schema_version": 1, "synthetic_paths": count, "live_paid_fields": FIELD_COUNT,
		"warmup_pairs_completed": mini(WARMUPS, completed_pairs), "measured_pairs_completed": maxi(0, completed_pairs - WARMUPS),
		"reference_us": _quantiles(reference_us), "candidate_us": _quantiles(candidate_us), "paired_candidate_minus_reference_us": _quantiles(delta_us),
		"measured_source_counts": measured_sources, "equal_queue_pairs": equal_queues, "inserted_contacts_per_arm": inserted,
		"field_contact_queries_per_arm": count * reference_us.size(),
		"reference_field_preparations": count * reference_us.size(), "candidate_field_preparations": candidate_us.size(),
		"reference_interval_candidates": FIELD_COUNT * count * reference_us.size(), "candidate_interval_candidates": count * candidate_us.size(),
		"untimed_contacts_per_source": source_contacts, "authority_unchanged": world.state_hash() == state_before,
		"plans_unchanged": var_to_bytes(plans) == plan_bytes, "state_sha256": state_before,
	}


func _plans(center: Vector2i, count: int) -> Array[Dictionary]:
	var plans: Array[Dictionary] = []
	for index: int in count:
		var y := (index % 3 - 1) * 24_000
		var start := center + Vector2i(-500_000, y)
		var finish := center + Vector2i(500_000, -y)
		if index % 2 == 1:
			var swap := start; start = finish; finish = swap
		plans.append({"entity_id": 1000 + index, "source_id": 9900 + index,
			"start": start, "finish": finish, "time": 0.0, "terminal_fraction": 1.0,
			"reason": "range", "generation": index % 3})
	return plans


func _batch(run: Callable, plans: Array[Dictionary], source: int, world: SimWorld) -> Dictionary:
	var queue := Workset.OrderedQueue.new(HexProjectileCombat._ordered)
	for fraction: float in [0.25, 0.5, 0.75]:
		queue.append({"kind": "sentinel", "fraction": fraction, "priority": 1, "first": 1003, "second": source, "generation": 0, "point": Vector2i.ZERO})
	var started := Time.get_ticks_usec()
	run.call(plans, {}, queue, 0.0, source, world)
	var elapsed := Time.get_ticks_usec() - started
	return {"us": elapsed, "queue": queue}


func _cases_complete(cases: Array[Dictionary]) -> bool:
	if cases.size() != PATH_COUNTS.size(): return false
	for index: int in PATH_COUNTS.size():
		if not _case_complete(cases[index], PATH_COUNTS[index]): return false
	return true


func _case_complete(row: Dictionary, count: int) -> bool:
	var expected := {"schema_version": 1, "synthetic_paths": count, "live_paid_fields": FIELD_COUNT,
		"warmup_pairs_completed": WARMUPS, "measured_pairs_completed": SAMPLES, "equal_queue_pairs": SAMPLES,
		"inserted_contacts_per_arm": count * SAMPLES, "field_contact_queries_per_arm": count * SAMPLES,
		"reference_field_preparations": count * SAMPLES, "candidate_field_preparations": SAMPLES,
		"reference_interval_candidates": FIELD_COUNT * count * SAMPLES, "candidate_interval_candidates": count * SAMPLES}
	for key: String in expected:
		if typeof(row.get(key)) != TYPE_INT or row[key] != expected[key]: return false
	for key: String in ["authority_unchanged", "plans_unchanged"]:
		if typeof(row.get(key)) != TYPE_BOOL or not row[key]: return false
	if typeof(row.get("state_sha256")) != TYPE_STRING or String(row.state_sha256).length() != 64: return false
	for key: String in ["reference_us", "candidate_us", "paired_candidate_minus_reference_us"]:
		var summary: Variant = row.get(key)
		if not summary is Dictionary or summary.size() != 5: return false
		for field: String in ["samples", "p50", "p95", "p99", "max"]:
			if typeof(summary.get(field)) != TYPE_INT: return false
		if summary.samples != SAMPLES or summary.p50 > summary.p95 or summary.p95 > summary.p99 or summary.p99 > summary.max: return false
		if key != "paired_candidate_minus_reference_us" and summary.p50 < 0: return false
	var measured: Variant = row.get("measured_source_counts")
	var contacts: Variant = row.get("untimed_contacts_per_source")
	if not measured is Dictionary or not contacts is Dictionary or measured.size() != FIELD_COUNT or contacts.size() != FIELD_COUNT: return false
	var total := 0
	for source: int in range(FIRST_SOURCE, FIRST_SOURCE + FIELD_COUNT):
		if typeof(measured.get(source)) != TYPE_INT or int(measured[source]) <= 0 or typeof(contacts.get(source)) != TYPE_INT or int(contacts[source]) != count: return false
		total += int(measured[source])
	return total == SAMPLES


func _quantiles(samples: PackedInt64Array) -> Dictionary:
	if samples.is_empty(): return {"samples": 0, "p50": 0, "p95": 0, "p99": 0, "max": 0}
	var ordered := samples.duplicate()
	ordered.sort()
	var result := {"samples": ordered.size(), "max": ordered[-1]}
	for percentile: int in [50, 95, 99]:
		result["p%d" % percentile] = ordered[clampi((ordered.size() * percentile + 99) / 100 - 1, 0, ordered.size() - 1)]
	return result


func _source_hashes() -> Dictionary:
	var result := {}
	for path: String in SOURCE_PATHS: result[path] = FileAccess.get_sha256("res://" + path)
	return result


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("new-ground workset profile: " + message)
