extends "res://tests/performance/profile_capture_pipeline.gd"

const RECONSTRUCTION_PROFILE_PATH := "tests/performance/profile_capture_reconstruction.gd"
const RECONSTRUCTION_VERSION := "capture-reconstruction-v1"
const RECONSTRUCTION_STAGES: Array[String] = [
	"outer_actors", "producer_consume", "collision_clone", "collision_surfaces",
	"world_constructor", "outer_relations", "outer_hash",
	"chemistry_encoded_size", "chemistry_relations", "chemistry_hash",
]
const RECONSTRUCTION_CHECKS: Array[String] = ["hash_exact", "snapshot_exact", "chemistry_exact", "collision_exact", "ownership", "source_unchanged"]


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output_path = argument.trim_prefix("--output=")
		else: _check(false, "unknown reconstruction probe argument")
	_check(output_path.begins_with("res://.godot/capture-reconstruction-") and output_path.ends_with(".json") and output_path.get_base_dir() == "res://.godot" and not ".." in output_path and not FileAccess.file_exists(output_path), "fresh scoped reconstruction receipt")
	var before := _reconstruction_sources()
	_check(_hashes_valid(before) and before[CAPTURE_ORACLE_PATH] == CAPTURE_ORACLE_SHA256, "dependencies and immutable E16 oracle hash")
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "actual abilities load")
	_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "actual champions load")
	_check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "actual campus loads")
	definition = HexWorldDefinition.from_campus(layout)
	_check(definition != null and definition.eligible_cells.size() == EXPECTED_TOPOLOGY_CELLS, "actual 11337-cell campus")
	if failures > 0:
		quit(1)
		return
	var records: Array[Dictionary] = []
	for label: String in CASE_LABELS: records.append(_reconstruction_case(label))
	var after := _reconstruction_sources()
	_check(before == after, "source files unchanged throughout reconstruction diagnostic")
	var receipt := {
		"profile_version": RECONSTRUCTION_VERSION, "engine": Engine.get_version_info().get("string", ""),
		"source_sha256_before": before, "source_sha256_after": after, "sources_unchanged": before == after,
		"samples": PUBLICATION_SAMPLES, "records": records,
		"scope": "Same four actual eight-champion 11337-cell fixtures and paid inputs as capture-pipeline-v1. Frozen E16 snapshot bytes equal current capture; actual current strict preparation is the result oracle. Production sources are not instrumented or changed.",
		"timing": "One warmup then seven fresh reconstruction samples. Existing current helpers execute in reconstruction order. Each timer encloses only its named call; actor/chemistry results feed fresh collision and world construction. A fresh one-shot ProducerRoundtrip and detached input duplicate are created before timers; source checks, assertions, comparison snapshots, statistics and evidence bookkeeping are outside timers. world_constructor includes the existing action-policy file load, validation and hash.",
		"overlap": "The first seven stages are separate calls within reconstruction, not the full capture cost. They omit outer admission, inflation, strict packed decode, field assignments, dynamic-collision constructor and timer overhead. The final three chemistry diagnostics run afterward on the completed fresh result: they overlap work inside producer_consume and MUST NOT be added to it or treated as exclusive subtractions. Warm diagnostics are not a total-pipeline benchmark.",
		"performance_acceptance": "NOT_ESTABLISHED",
	}
	receipt.receipt_complete = _reconstruction_records_complete(records)
	receipt.diagnostic_status = "PASS" if failures == 0 else "FAIL"
	receipt.failures = failures
	_check(_reconstruction_receipt_valid(receipt), "complete native reconstruction receipt")
	_check(_reconstruction_receipt_valid(JSON.parse_string(JSON.stringify(receipt))), "complete serialized reconstruction receipt")
	_reconstruction_guards(receipt)
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	_check(output != null, "reconstruction receipt opens")
	if output != null:
		receipt.assertions = assertions
		receipt.failures = failures
		receipt.diagnostic_status = "PASS" if failures == 0 else "FAIL"
		output.store_string(JSON.stringify(receipt, "\t") + "\n")
		output.close()
	print("%s: capture-reconstruction; %d assertions; %d failures; output=%s" % ["PASS" if failures == 0 else "FAIL", assertions, failures, output_path])
	quit(1 if failures > 0 else 0)


func _reconstruction_case(label: String) -> Dictionary:
	print("RECONSTRUCTION_FIXTURE " + label)
	var fixture: Dictionary = _collision_fixture(label)
	if fixture.is_empty(): return {}
	var world: SimWorld = fixture.worlds.sealed
	var source_collision_world := world.collision as HexCollisionWorld
	var session: AuthoritativeSession = _publication_session(world)
	var source_before := _publication_source_bytes(session)
	var source_collision := _collision_descriptor(world.collision)
	var snapshot: Dictionary = CaptureBefore.capture(world)
	_check(not snapshot.is_empty() and var_to_bytes(snapshot) == var_to_bytes(HexWorldSnapshot.capture(world)) and var_to_bytes(snapshot) == var_to_bytes(CaptureBefore.capture(fixture.worlds.legacy)), "frozen/current and independent legacy fixture snapshots exact")
	if snapshot.is_empty(): return {}
	var expected: SimWorld = HexWorldSnapshot.prepare(snapshot, world)
	_check(expected != null, "actual current preparation succeeds")
	if expected == null: return {}
	var expected_bytes := var_to_bytes(HexWorldSnapshot.capture(expected))
	_check(expected_bytes == var_to_bytes(snapshot), "actual prepared world recaptures exact source snapshot")
	var packed: Dictionary = CaptureBefore._inflate_hex(snapshot.hex)
	var detached: Dictionary = HexWorldSnapshot.WirePacking.strict_decode(packed, world.hex_court.cell_count())
	_check(not detached.is_empty(), "strict detached input")
	if detached.is_empty(): return {}
	var input_before := var_to_bytes([snapshot, detached])
	var expected_chemistry := var_to_bytes(detached)
	var expected_collision := _collision_descriptor(expected.collision)
	var checks := {}
	for key: String in RECONSTRUCTION_CHECKS: checks[key] = true
	var observations := {}
	for stage: String in RECONSTRUCTION_STAGES: observations[stage] = PackedInt64Array()
	for index: int in PUBLICATION_SAMPLES + 1:
		var sample := _reconstruction_sample(world, snapshot, detached)
		_check(not sample.is_empty(), "all reconstruction component calls succeed")
		if sample.is_empty(): return {}
		var prepared: SimWorld = sample.world
		var prepared_collision := prepared.collision as HexCollisionWorld
		var result_checks := {
			"hash_exact": sample.outer_hash == snapshot.state_hash and prepared.state_hash() == expected.state_hash(),
			"snapshot_exact": var_to_bytes(HexWorldSnapshot.capture(prepared)) == expected_bytes,
			"chemistry_exact": var_to_bytes(HexWorldSnapshot.ChemistrySnapshot._capture_for_outer_roundtrip(prepared.hex_court)) == expected_chemistry,
			"collision_exact": _collision_descriptor(prepared.collision) == expected_collision,
			"ownership": prepared != expected and prepared.hex_court != expected.hex_court and prepared.hex_court != world.hex_court
				and prepared.hex_court.immutable_topology() == world.hex_court.immutable_topology() and prepared.players[0] != expected.players[0]
				and prepared_collision != source_collision_world and prepared_collision.base_world != source_collision_world.base_world,
			"source_unchanged": _publication_source_bytes(session) == source_before and _collision_descriptor(world.collision) == source_collision
				and var_to_bytes([snapshot, detached]) == input_before and _storage_modes_valid(fixture.worlds),
		}
		for key: String in RECONSTRUCTION_CHECKS:
			checks[key] = bool(checks[key]) and bool(result_checks[key])
			_check(bool(result_checks[key]), label + " reconstruction " + key)
		if index > 0:
			for stage: String in RECONSTRUCTION_STAGES:
				var samples: PackedInt64Array = observations[stage]
				samples.append(int(sample.times[stage]))
				observations[stage] = samples
	var stages := {}
	for stage: String in RECONSTRUCTION_STAGES:
		stages[stage] = _stats(observations[stage])
		print("RECONSTRUCTION_STAGE %s %s p50_us=%d" % [label, stage, stages[stage].statistics_us.p50])
	return {
		"case": label, "actors": world.players.size(), "topology_cells": world.hex_court.cell_count(),
		"tick": world.tick, "paid_steps": fixture.paid_steps, "paid_metrics": world.hex_court.metrics.duplicate(true),
		"active_ramparts": _active_ramparts(world.hex_court, world.tick), "base_obstacles": source_collision_world.base_world.obstacle_view().size(),
		"state_hash": String(snapshot.state_hash), "trace_sha256": fixture.trace_sha256,
		"snapshot_sha256": CanonicalBytes.sha256_hex(expected_bytes), "snapshot_bytes": expected_bytes.size(),
		"checks": checks, "stages": stages,
	}


func _reconstruction_sample(source: SimWorld, snapshot: Dictionary, detached: Dictionary) -> Dictionary:
	# Setup is deliberately outside all component timers; consume remains the
	# actual public one-shot proof, not a replacement decoder or alleged trust flag.
	var producer := HexWorldSnapshot.ChemistrySnapshot.ProducerRoundtrip.new(source.hex_court)
	var local_detached: Dictionary = detached.duplicate(true)
	var header: PackedInt64Array = snapshot.header
	var times := {}
	var started := Time.get_ticks_usec()
	var actors: Dictionary = HexWorldSnapshot._decode_outer_lanes(snapshot, source)
	times.outer_actors = Time.get_ticks_usec() - started
	if actors.is_empty(): return {}
	started = Time.get_ticks_usec()
	var chemistry: HexChemistryWorld = producer.consume(local_detached, source.hex_court)
	times.producer_consume = Time.get_ticks_usec() - started
	if chemistry == null or chemistry.current_tick != header[7]: return {}
	chemistry.value_revision = 1
	started = Time.get_ticks_usec()
	var base: CollisionWorld = HexWorldSnapshot._clone_base_collision(source.collision)
	times.collision_clone = Time.get_ticks_usec() - started
	if base == null: return {}
	var collision := HexWorldSnapshot.DynamicCollision.new(base)
	chemistry.collision = base
	started = Time.get_ticks_usec()
	var surfaces: bool = collision.set_hex_surfaces(chemistry, header[1])
	times.collision_surfaces = Time.get_ticks_usec() - started
	if not surfaces: return {}
	started = Time.get_ticks_usec()
	var prepared := SimWorld.new(source.config.tick_rate, header[2], collision, source.map_id, source.map_hash)
	times.world_constructor = Time.get_ticks_usec() - started
	if not prepared.is_valid() or prepared.transition_policy.content_hash != snapshot.transition_hash: return {}
	prepared.tick = header[1]
	prepared.seed = header[2]
	prepared.next_projectile_id = header[3]
	prepared.next_field_id = header[4]
	prepared.next_deposit_id = header[5]
	prepared.next_reaction_id = header[6]
	prepared.hex_court = chemistry
	prepared.players = actors.players
	prepared.projectiles = actors.projectiles
	prepared.fields = []
	prepared.deposits = []
	prepared.reactions = []
	prepared.combat_events = []
	prepared.last_error = ""
	started = Time.get_ticks_usec()
	var relations: bool = HexWorldSnapshot._validate_relations(prepared)
	times.outer_relations = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	var outer_hash: String = prepared._state_hash_with_verified_hex_hash(String(local_detached.authority_hash))
	times.outer_hash = Time.get_ticks_usec() - started
	# These supplementary calls overlap consume's validation/hash work. They are
	# diagnostic costs on the completed fresh result, never subtracted from consume.
	started = Time.get_ticks_usec()
	var encoded_size: int = HexWorldSnapshot.ChemistrySnapshot.encoded_size(local_detached)
	times.chemistry_encoded_size = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	var chemistry_relations: bool = HexWorldSnapshot.ChemistrySnapshot._validate_relations(chemistry)
	times.chemistry_relations = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	var chemistry_hash: String = chemistry.state_hash()
	times.chemistry_hash = Time.get_ticks_usec() - started
	if not relations or not chemistry_relations or outer_hash != snapshot.state_hash or chemistry_hash != local_detached.authority_hash: return {}
	if encoded_size <= 0 or encoded_size > HexWorldSnapshot.ChemistrySnapshot.MAX_ENCODED_BYTES: return {}
	return {"world": prepared, "outer_hash": outer_hash, "times": times}


func _reconstruction_records_complete(records: Variant) -> bool:
	if not records is Array or records.size() != CASE_LABELS.size(): return false
	for offset: int in CASE_LABELS.size():
		var record: Variant = records[offset]
		if not record is Dictionary or record.get("case") != CASE_LABELS[offset] or record.get("actors") != 8 or record.get("topology_cells") != EXPECTED_TOPOLOGY_CELLS: return false
		if not _canonical_keys(record.get("checks"), RECONSTRUCTION_CHECKS) or not _canonical_keys(record.get("stages"), RECONSTRUCTION_STAGES): return false
		for key: String in RECONSTRUCTION_CHECKS:
			if record.checks[key] != true: return false
		for key: String in ["state_hash", "trace_sha256", "snapshot_sha256"]:
			if not _hash_valid(record.get(key)): return false
		for key: String in ["tick", "paid_steps", "active_ramparts", "base_obstacles"]:
			if not _publication_integer(record.get(key)): return false
		if record.tick != WARMUP_TICKS + record.paid_steps or not _publication_integer(record.get("snapshot_bytes"), 1) or record.snapshot_bytes > CaptureBefore.MAX_RAW_BYTES: return false
		if offset == 0 and record.paid_steps != 0: return false
		if offset in [1, 2] and record.paid_steps != 40: return false
		if offset == 3 and (record.paid_steps < 1 or record.paid_steps > RAMPART_STEP_LIMIT or record.active_ramparts < 1): return false
		if not record.get("paid_metrics") is Dictionary: return false
		if offset > 0 and (record.paid_metrics.get("admitted", 0) <= 0 or record.paid_metrics.get("matter_paid", 0) <= 0): return false
		for stage: String in RECONSTRUCTION_STAGES:
			var observation: Variant = record.stages[stage]
			if not _canonical_keys(observation, ["samples_us", "statistics_us"]) or not observation.samples_us is Array or observation.samples_us.size() != PUBLICATION_SAMPLES: return false
			for sample: Variant in observation.samples_us:
				if not _publication_integer(sample): return false
			if not _publication_statistics_complete(observation.statistics_us, observation.samples_us): return false
	return true


func _reconstruction_receipt_valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("profile_version") != RECONSTRUCTION_VERSION or value.get("samples") != PUBLICATION_SAMPLES: return false
	if value.get("diagnostic_status") != "PASS" or value.get("failures") != 0 or value.get("receipt_complete") != true or value.get("sources_unchanged") != true: return false
	if not value.get("source_sha256_before") is Dictionary or not value.get("source_sha256_after") is Dictionary or not _hashes_valid(value.source_sha256_before): return false
	if value.source_sha256_before != value.source_sha256_after or value.source_sha256_before.get(CAPTURE_ORACLE_PATH) != CAPTURE_ORACLE_SHA256 or not value.source_sha256_before.has(RECONSTRUCTION_PROFILE_PATH): return false
	return _reconstruction_records_complete(value.get("records"))


func _reconstruction_guards(receipt: Dictionary) -> void:
	if not _reconstruction_receipt_valid(receipt): return
	for mutation: String in ["case", "stage", "sample", "fractional", "statistic", "ownership", "source", "oracle"]:
		var broken: Dictionary = receipt.duplicate(true)
		match mutation:
			"case": broken.records.pop_back()
			"stage": broken.records[0].stages.erase("producer_consume")
			"sample": broken.records[0].stages.outer_hash.samples_us.pop_back()
			"fractional": broken.records[0].stages.outer_hash.statistics_us.p50 += 0.5
			"statistic": broken.records[0].stages.outer_hash.statistics_us.p50 = true
			"ownership": broken.records[0].checks.ownership = false
			"source": broken.sources_unchanged = false
			"oracle": broken.source_sha256_before[CAPTURE_ORACLE_PATH] = "0".repeat(64)
		_check(not _reconstruction_receipt_valid(broken), "native reconstruction receipt rejects " + mutation)
		_check(not _reconstruction_receipt_valid(JSON.parse_string(JSON.stringify(broken))), "JSON reconstruction receipt rejects " + mutation)


func _reconstruction_sources() -> Dictionary:
	var result := _capture_sources()
	result[RECONSTRUCTION_PROFILE_PATH] = FileAccess.get_sha256("res://" + RECONSTRUCTION_PROFILE_PATH)
	return result
