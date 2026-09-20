extends "res://tests/performance/profile_unified_wellspring.gd"
@warning_ignore_start("integer_division")

# Bounded decomposition probe for the unified snapshot stack. The inherited
# _initialize dispatches to this override; the profiler's four-run _run is never
# entered. Each measured component receives the same live authority state.
const PROBE_STEPS := 40
const REPETITIONS := 3
const PROBE_CASES: Array[String] = ["sustained-distributed", "dense-crucible"]


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	_check(output_path.begins_with("res://.godot/unified-snapshot-cost-") and output_path.ends_with(".json") and not ".." in output_path and not FileAccess.file_exists(output_path), "probe receipt path is fresh and scoped")

	var global_setup_started := Time.get_ticks_usec()
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "production ability catalogue loads")
	_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "production champion catalogue loads")
	_check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "normal Wellspring campus loads")
	definition = HexWorldDefinition.from_campus(layout)
	_check(definition != null, "normal campus produces one trusted whole-hex definition")
	var global_setup_us := Time.get_ticks_usec() - global_setup_started
	print("UNIFIED_SNAPSHOT_COST stage=global_setup complete elapsed_us=%d failures=%d" % [global_setup_us, failures])
	if failures > 0:
		quit(1)
		return

	var cases: Array[Dictionary] = []
	for case_name: String in PROBE_CASES:
		var result := _probe_case(case_name)
		cases.append(result)
		print("UNIFIED_SNAPSHOT_COST stage=case_complete case=%s tick=%d failures=%d" % [case_name, int(result.get("tick", -1)), failures])

	var receipt := {
		"schema_version": 1,
		"probe_version": "unified-snapshot-cost-v1",
		"workload_version": "unified-wellspring-profile-v1",
		"engine": Engine.get_version_info()["string"],
		"seed": SEED,
		"warmup_ticks": WARMUP_TICKS,
		"probe_steps": PROBE_STEPS,
		"component_repetitions": REPETITIONS,
		"global_setup_us": global_setup_us,
		"cases": cases,
		"source_sha256": _probe_source_hashes(),
		"assertions": assertions,
		"failures": failures,
		"scope": "Bounded headless diagnostic of the unchanged normal-campus eight-champion authority after 120 neutral ticks and the first 40 ordinary paid workload ticks. No capacity, state, resource, cooldown, lifetime, snapshot, or transport limit is overridden.",
		"timing_semantics": "Each component contains three direct inclusive calls against an identical authority state. Nested work remains visible in its production caller: world capture includes chemistry capture, and envelope capture includes world capture. Setup, command construction, event accounting, validation, equality checks, byte accounting, and round-trip reconstruction are outside component timers.",
		"performance_acceptance": "NOT_ESTABLISHED; these diagnostic component timings identify local snapshot work and do not establish capacity, release performance, or network delivery performance.",
	}
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	_check(output != null, "probe receipt opens")
	if output != null:
		receipt.assertions = assertions
		receipt.failures = failures
		output.store_string(JSON.stringify(receipt, "\t") + "\n")
		output.close()
	print("%s: unified-snapshot-cost; %d assertions; %d failures; output=%s" % ["PASS" if failures == 0 else "FAIL", assertions, failures, output_path])
	quit(1 if failures > 0 else 0)


func _probe_case(case_name: String) -> Dictionary:
	var fixture_started := Time.get_ticks_usec()
	var fixture: Dictionary = _fixture(case_name)
	var world: SimWorld = fixture.world
	var targets: Dictionary = fixture.targets
	var session := AuthoritativeSession.new()
	var host: PlayerState = world.player(1)
	var spawn_pixels := Vector2i(host.position_x / SimConfig.FIXED_SCALE, host.position_y / SimConfig.FIXED_SCALE)
	_check(session.bind(world, champions, spawn_pixels, "Probe Host"), case_name + " binds the production authoritative session")
	for actor: PlayerState in world.players:
		actor.team_id = 1
		session.names_by_entity[actor.entity_id] = "Probe %d" % actor.entity_id
		_check(session.hearth.connect_entity(actor.entity_id), case_name + " snapshot Hearth includes champion %d" % actor.entity_id)
	var fixture_setup_us := Time.get_ticks_usec() - fixture_started
	print("UNIFIED_SNAPSHOT_COST stage=fixture case=%s complete elapsed_us=%d actors=%d" % [case_name, fixture_setup_us, world.players.size()])

	var warmup_started := Time.get_ticks_usec()
	for unused: int in range(WARMUP_TICKS):
		_check(world.step(_commands(world, targets, case_name, false, false)), case_name + " neutral warmup advances")
	var warmup_us := Time.get_ticks_usec() - warmup_started
	print("UNIFIED_SNAPSHOT_COST stage=warmup case=%s complete elapsed_us=%d tick=%d" % [case_name, warmup_us, world.tick])

	var step_times := PackedInt64Array()
	step_times.resize(PROBE_STEPS)
	var requested_pressed := {}
	var requested_held := {}
	var admitted := {}
	var released := {}
	var refusals := {}
	var event_counts := {}
	var processed_clashes := 0
	for index: int in range(PROBE_STEPS):
		var commands: Array[SimCommand] = _commands(world, targets, case_name, true, false)
		_count_requested(world, commands, requested_pressed, requested_held)
		var step_started := Time.get_ticks_usec()
		var stepped := world.step(commands)
		step_times[index] = Time.get_ticks_usec() - step_started
		_check(stepped, case_name + " paid probe timeline step succeeds")
		var event_delta: Dictionary = _record_events(session, world.combat_events, event_counts, admitted, released, refusals)
		processed_clashes += int(event_delta.clashes)
	var stable_hash := world.state_hash()
	_check(stable_hash.length() == 64 and world.hex_court.conservation_valid(), case_name + " reaches a valid conserved probe state")
	_check(int(world.hex_court.metrics.admitted) > 0 and int(world.hex_court.metrics.matter_paid) > 0, case_name + " first 40 ordinary timeline steps contain real paid admissions")
	print("UNIFIED_SNAPSHOT_COST stage=paid_steps case=%s complete tick=%d hash=%s admitted=%d" % [case_name, world.tick, stable_hash.left(12), int(world.hex_court.metrics.admitted)])

	var state_hash_stage := _probe_state_hash(case_name, world, stable_hash)
	var chemistry_stage := _probe_chemistry_capture(case_name, world, stable_hash)
	var world_stage := _probe_world_capture(case_name, world, stable_hash)
	# One normal preflight puts the session into the same pending-ack state used
	# by all three measured envelope calls. It does not alter world authority.
	var envelope_preflight: Dictionary = session.capture_envelope()
	_check(WorldSnapshotEnvelope.validate(envelope_preflight), case_name + " envelope preflight validates")
	_check(world.state_hash() == stable_hash, case_name + " envelope preflight leaves authority unchanged")
	var envelope_stage := _probe_envelope_capture(case_name, world, session, stable_hash)
	var packet_stage := _probe_packet_packing(case_name, world, envelope_preflight, stable_hash)

	var chemistry_snapshot: Dictionary = chemistry_stage.sample
	var restored_chemistry: HexChemistryWorld = HexWorldSnapshot._blank_trusted_hex(world.hex_court)
	var chemistry_restored := restored_chemistry != null and HexChemistrySnapshot.restore(chemistry_snapshot, restored_chemistry)
	var restored_chemistry_hash := restored_chemistry.state_hash() if chemistry_restored else ""
	_check(chemistry_restored, case_name + " chemistry snapshot restores into identical trusted topology")
	_check(restored_chemistry_hash == world.hex_court.state_hash(), case_name + " chemistry round trip reproduces the exact court hash")
	_check(chemistry_restored and HexChemistrySnapshot.capture(restored_chemistry) == chemistry_snapshot, case_name + " chemistry recapture reproduces the exact typed snapshot")
	var world_snapshot: Dictionary = world_stage.sample
	var restored_world: SimWorld = HexWorldSnapshot.prepare(world_snapshot, world)
	var restored_world_hash := restored_world.state_hash() if restored_world != null else ""
	_check(restored_world_hash == stable_hash, case_name + " world snapshot round trip reproduces the exact authority hash")
	_check(restored_world != null and HexWorldSnapshot.capture(restored_world) == world_snapshot, case_name + " world recapture reproduces the exact typed snapshot")
	var envelope: Dictionary = envelope_stage.sample
	_check(WorldSnapshotEnvelope.validate(envelope) and envelope == envelope_preflight and envelope.authority == world_snapshot, case_name + " envelope contains the exact deterministic world snapshot and session lanes")
	var decoded_envelope := _decode_packets(packet_stage.sample)
	_check(decoded_envelope == envelope_preflight, case_name + " production wire packets reconstruct the exact canonical envelope")
	_check(world.state_hash() == stable_hash, case_name + " all captures and round trips leave source authority unchanged")
	print("UNIFIED_SNAPSHOT_COST stage=roundtrip case=%s complete chemistry=true world=true envelope=true packets=%d" % [case_name, int(packet_stage.packet_count)])

	chemistry_stage.erase("sample")
	world_stage.erase("sample")
	envelope_stage.erase("sample")
	packet_stage.erase("sample")
	return {
		"case": case_name,
		"tick": world.tick,
		"authority_hash": stable_hash,
		"fixture_setup_us": fixture_setup_us,
		"warmup_us": warmup_us,
		"individual_step_us": _percentiles(step_times),
		"workload": {
			"requested_pressed_by_wire": requested_pressed,
			"requested_held_ticks_by_wire": requested_held,
			"admitted_by_wire": admitted,
			"released_by_wire": released,
			"refusals_by_wire_and_reason": refusals,
			"event_counts": event_counts,
			"processed_clashes": processed_clashes,
			"authority_metrics": world.hex_court.metrics.duplicate(true),
			"occupancy": _occupancy(world.hex_court, world.tick),
		},
		"components": {
			"world_state_hash": state_hash_stage,
			"hex_chemistry_snapshot_capture": chemistry_stage,
			"hex_world_snapshot_capture": world_stage,
			"authoritative_session_capture_envelope": envelope_stage,
			"session_transport_envelope_wire_packets": packet_stage,
		},
		"roundtrip": {
			"chemistry_hash": restored_chemistry_hash,
			"world_hash": restored_world_hash,
			"decoded_envelope_equal": decoded_envelope == envelope_preflight,
		},
	}


func _probe_state_hash(case_name: String, world: SimWorld, stable_hash: String) -> Dictionary:
	var before_hash := world.state_hash()
	_check(before_hash == stable_hash, case_name + " state_hash stage begins from the expected authority")
	var times := PackedInt64Array()
	times.resize(REPETITIONS)
	var outputs: Array[String] = []
	for repetition: int in range(REPETITIONS):
		var started := Time.get_ticks_usec()
		var value := world.state_hash()
		times[repetition] = Time.get_ticks_usec() - started
		outputs.append(value)
	var exact := outputs.size() == REPETITIONS
	for value: String in outputs:
		exact = exact and value == stable_hash
	_check(exact, case_name + " state_hash repetitions are exact")
	print("UNIFIED_SNAPSHOT_COST stage=world_state_hash case=%s complete p50_us=%d p95_us=%d" % [case_name, int(_percentiles(times).p50), int(_percentiles(times).p95)])
	return {"us": _percentiles(times), "output_bytes": stable_hash.to_utf8_buffer().size(), "before_hash": before_hash, "after_hash": world.state_hash()}


func _probe_chemistry_capture(case_name: String, world: SimWorld, stable_hash: String) -> Dictionary:
	var before_hash := world.state_hash()
	_check(before_hash == stable_hash, case_name + " chemistry capture stage begins from the expected authority")
	var times := PackedInt64Array()
	times.resize(REPETITIONS)
	var outputs: Array[Dictionary] = []
	for repetition: int in range(REPETITIONS):
		var started := Time.get_ticks_usec()
		var value := HexChemistrySnapshot.capture(world.hex_court)
		times[repetition] = Time.get_ticks_usec() - started
		outputs.append(value)
	_check(not outputs[0].is_empty() and outputs[1] == outputs[0] and outputs[2] == outputs[0], case_name + " chemistry captures are deterministic")
	_check(String(outputs[0].get("authority_hash", "")) == world.hex_court.state_hash() and world.state_hash() == stable_hash, case_name + " chemistry capture hash validates before and after")
	var encoded_bytes := HexChemistrySnapshot.encoded_size(outputs[0])
	print("UNIFIED_SNAPSHOT_COST stage=hex_chemistry_capture case=%s complete p50_us=%d bytes=%d" % [case_name, int(_percentiles(times).p50), encoded_bytes])
	return {"us": _percentiles(times), "encoded_bytes": encoded_bytes, "before_hash": before_hash, "after_hash": world.state_hash(), "sample": outputs[0]}


func _probe_world_capture(case_name: String, world: SimWorld, stable_hash: String) -> Dictionary:
	var before_hash := world.state_hash()
	_check(before_hash == stable_hash, case_name + " world capture stage begins from the expected authority")
	var times := PackedInt64Array()
	times.resize(REPETITIONS)
	var outputs: Array[Dictionary] = []
	for repetition: int in range(REPETITIONS):
		var started := Time.get_ticks_usec()
		var value := HexWorldSnapshot.capture(world)
		times[repetition] = Time.get_ticks_usec() - started
		outputs.append(value)
	_check(not outputs[0].is_empty() and outputs[1] == outputs[0] and outputs[2] == outputs[0], case_name + " world captures are deterministic")
	_check(HexWorldSnapshot.validate_wire_structure(outputs[0]) and String(outputs[0].state_hash) == stable_hash and world.state_hash() == stable_hash, case_name + " world capture hash and wire structure validate")
	var encoded_bytes := HexWorldSnapshot.byte_size(outputs[0])
	print("UNIFIED_SNAPSHOT_COST stage=hex_world_capture case=%s complete p50_us=%d bytes=%d" % [case_name, int(_percentiles(times).p50), encoded_bytes])
	return {"us": _percentiles(times), "encoded_bytes": encoded_bytes, "before_hash": before_hash, "after_hash": world.state_hash(), "sample": outputs[0]}


func _probe_envelope_capture(case_name: String, world: SimWorld, session: AuthoritativeSession, stable_hash: String) -> Dictionary:
	var before_hash := world.state_hash()
	_check(before_hash == stable_hash, case_name + " envelope capture stage begins from the expected authority")
	var times := PackedInt64Array()
	times.resize(REPETITIONS)
	var outputs: Array[Dictionary] = []
	for repetition: int in range(REPETITIONS):
		var started := Time.get_ticks_usec()
		var value := session.capture_envelope()
		times[repetition] = Time.get_ticks_usec() - started
		outputs.append(value)
	_check(not outputs[0].is_empty() and outputs[1] == outputs[0] and outputs[2] == outputs[0], case_name + " envelope captures are deterministic")
	_check(WorldSnapshotEnvelope.validate(outputs[0]) and world.state_hash() == stable_hash, case_name + " envelope capture validates without authority mutation")
	var encoded_bytes := WorldSnapshotEnvelope.byte_size(outputs[0])
	print("UNIFIED_SNAPSHOT_COST stage=capture_envelope case=%s complete p50_us=%d bytes=%d" % [case_name, int(_percentiles(times).p50), encoded_bytes])
	return {"us": _percentiles(times), "encoded_bytes": encoded_bytes, "before_hash": before_hash, "after_hash": world.state_hash(), "sample": outputs[0]}


func _probe_packet_packing(case_name: String, world: SimWorld, envelope: Dictionary, stable_hash: String) -> Dictionary:
	var before_hash := world.state_hash()
	_check(before_hash == stable_hash, case_name + " packet stage begins from the expected authority")
	var times := PackedInt64Array()
	times.resize(REPETITIONS)
	var outputs: Array = []
	for repetition: int in range(REPETITIONS):
		var started := Time.get_ticks_usec()
		var value: Array[Dictionary] = SessionTransport._envelope_wire_packets(envelope)
		times[repetition] = Time.get_ticks_usec() - started
		outputs.append(value)
	_check(not outputs[0].is_empty() and outputs[1] == outputs[0] and outputs[2] == outputs[0], case_name + " packet packing repetitions are deterministic")
	_check(world.state_hash() == stable_hash, case_name + " packet packing leaves authority unchanged")
	var wire_bytes := 0
	for packet: Dictionary in outputs[0]:
		var packet_bytes := var_to_bytes(packet).size()
		wire_bytes += packet_bytes
		_check(packet_bytes <= SessionTransport.ENET_MTU_BYTES, case_name + " packet respects the production ENet MTU")
	print("UNIFIED_SNAPSHOT_COST stage=envelope_wire_packets case=%s complete p50_us=%d packets=%d wire_bytes=%d" % [case_name, int(_percentiles(times).p50), outputs[0].size(), wire_bytes])
	return {"us": _percentiles(times), "wire_bytes": wire_bytes, "packet_count": outputs[0].size(), "before_hash": before_hash, "after_hash": world.state_hash(), "sample": outputs[0]}


func _decode_packets(packets: Array) -> Dictionary:
	if packets.size() == 1:
		return SessionTransport._envelope_from_wire_packet(packets[0])
	var decoder := SessionTransport.new()
	var decoded := {}
	for packet: Dictionary in packets:
		var candidate: Dictionary = decoder._envelope_from_fragment(packet)
		if not candidate.is_empty():
			decoded = candidate
	return decoded


func _probe_source_hashes() -> Dictionary:
	var result := {}
	for path: String in [
		"tests/performance/probe_unified_snapshot_cost.gd",
		"tests/performance/profile_unified_wellspring.gd",
		"src/net/hex_chemistry_snapshot.gd",
		"src/net/hex_world_snapshot.gd",
		"src/net/authoritative_session.gd",
		"src/net/session_transport.gd",
	]:
		result[path] = FileAccess.get_sha256("res://" + path)
	return result
