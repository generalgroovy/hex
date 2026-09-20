extends "res://tests/scenarios/runtime_stress_probe.gd"

# Bounded same-input investigation, not an optimization or FPS benchmark.
# Production SimWorld.step is timed alone; all observation happens afterward.
const DrillSampler = preload("res://tests/scenarios/runtime_drill_sampler.gd")
const DrillCombat = preload("res://tests/scenarios/runtime_drill_combat.gd")
const COPIED_SIM_WORLD_SHA256 := "bc5358c17609ae86e052f5fbba383bef0c4d70452b8f4f9a6e997eca98c18cbb"
const COPIED_COMBAT_SHA256 := "7af2a66ab510565910f504a5c7d0b94723190d745d3f440ee9b8a50f0ce2ea96"
const CURRENT_CHEMISTRY_SHA256 := "d7e3b5aa669b0f29b97a5588753c0a0be1472c868af2990c7b0b911492701653"


func _run() -> void:
	var source_hashes := _source_hashes()
	_check(String(source_hashes.get("src/sim/core/sim_world.gd", "")) == COPIED_SIM_WORLD_SHA256, "current SimWorld source guard matches")
	_check(String(source_hashes.get("src/sim/combat/combat_system.gd", "")) == COPIED_COMBAT_SHA256, "current combat source guard matches")
	_check(String(source_hashes.get("src/sim/chemistry/element_chemistry_system.gd", "")) == CURRENT_CHEMISTRY_SHA256, "current P3 chemistry source guard matches")
	if failures > 0:
		push_error("Projectile drill source guard failed; review copied bodies before measuring")
		quit(1)
		return
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "abilities load: %s" % abilities.last_error)
	_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "champions load: %s" % champions.last_error)
	if failures > 0:
		quit(1)
		return
	var source_inventory_sha256 := CanonicalContent.sha256(source_hashes)
	for path: String in source_hashes:
		print("PROJECTILE_DRILL_SOURCE ", JSON.stringify({"path":path, "sha256":source_hashes[path]}))
	var field_opening := OS.get_cmdline_user_args().has("--fields")
	var real_map := OS.get_cmdline_user_args().has("--real-map")
	print("PROJECTILE_DRILL_META ", JSON.stringify({
		"version":2, "engine":Engine.get_version_info()["string"], "cpu":OS.get_processor_name(), "seed":SEED,
		"protocol":SimConfig.PROTOCOL_VERSION, "snapshot_schema":SessionSnapshot.SCHEMA_VERSION,
		"scenario":"legal-eight-field-opening" if field_opening else "legal-eight-mixed-deliveries",
		"map_mode_requested":"sanctum_campus_g2_v1" if real_map else "fixed_synthetic_zero_obstacles",
		"repeats":2, "warmup_ticks":WARMUP_TICKS, "sample_ticks_per_repeat":LEGAL_TICKS,
		"source_inventory_sha256":source_inventory_sha256, "source_records":source_hashes.size(),
		"source_scope":"all files under src, content, tests/scenarios, plus project.godot; headless runtime identity, not art or export identity",
		"comparison":"production SimWorld.step versus a source-guarded mirror whose projectile loop calls current ElementChemistrySystem.projectile_interaction",
		"command_order":"repeat 1 production forward/mirror reverse; repeat 2 production reverse/mirror forward",
		"timing_scope":"production_us is SimWorld.step only; mirror, exact checks, trace, snapshots, packet codec, and output are outside",
		"projectile_timer_scope":"candidate and Frostway batch capture; travel math; move plus position/range update; actual production chemistry interaction; actor scan plus hit effects/events; terminal resolution",
		"projectile_timer_limits":"mirror-only timers include instrumentation overhead and omit surrounding iteration, sorting, branches, and some control work; buckets are not an additive full decomposition",
		"snapshot_scope":"every other measured tick; validation, exact overflow, MTU packetization and reversed-fragment reconstruction use no sockets",
	}))
	var reference: Dictionary = {}
	for repeat_index: int in range(2):
		var result := _run_repeat(repeat_index, field_opening, real_map, source_inventory_sha256, source_hashes.size())
		if repeat_index == 0:
			reference = result
		else:
			_check(result.measurement_trace_sha256 == reference.measurement_trace_sha256, "measured traces agree across command orders")
			_check(result.full_trace_sha256 == reference.full_trace_sha256, "full lifecycle traces agree across command orders")
			_check(result.final_hash == reference.final_hash, "final hashes agree across command orders")
			_check(result.event_counts == reference.event_counts, "lifecycle event totals agree across command orders")
			_check(result.cleanup_ticks == reference.cleanup_ticks, "cleanup lengths agree across command orders")
		print("PROJECTILE_DRILL_RESULT ", JSON.stringify(result))
	print("%s: runtime-projectile-drill; %d assertions; %d failures" % ["PASS" if failures == 0 else "FAIL", assertions, failures])
	quit(0 if failures == 0 else 1)


func _run_repeat(repeat_index: int, field_opening: bool, real_map_requested: bool, source_inventory_sha256: String, source_records: int) -> Dictionary:
	var repeat_number := repeat_index + 1
	var production_reverse := repeat_index == 1
	var world := _make_world(8, 0, not field_opening, field_opening)
	var mirror := _make_world(8, 0, not field_opening, field_opening)
	var real_map_loaded := real_map_requested and world.map_id != "runtime-stress-v1"
	_check(world.map_id == mirror.map_id and world.map_hash == mirror.map_hash, "repeat %d map identities agree" % repeat_number)
	_check(not real_map_requested or real_map_loaded, "repeat %d requested real map is loaded" % repeat_number)
	var full_trace := HashingContext.new()
	full_trace.start(HashingContext.HASH_SHA256)
	var measurement_trace := HashingContext.new()
	measurement_trace.start(HashingContext.HASH_SHA256)
	var samples := PackedInt64Array()
	var snapshot_samples := PackedInt64Array()
	var combat_totals := {}
	var event_counts := {}
	var over_budget := 0
	var snapshot_count := 0
	var snapshot_rejections := 0
	var network_gaps := 0
	var maximum_overflow := PackedInt32Array([0, 0, 0, 0])
	var peak_datagram_bytes := 0
	var peak_datagram_count := 0
	for phase_index: int in range(WARMUP_TICKS + LEGAL_TICKS):
		var measured := phase_index >= WARMUP_TICKS
		var production_commands := _commands(world, measured, production_reverse, measured and not field_opening, field_opening)
		var mirror_commands := _commands(mirror, measured, not production_reverse, measured and not field_opening, field_opening)
		world.collision.obstacle_view()
		mirror.collision.obstacle_view()
		var began := Time.get_ticks_usec()
		var stepped := world.step(production_commands)
		var production_us := Time.get_ticks_usec() - began
		_check(stepped, "repeat %d production tick %d" % [repeat_number, world.tick])
		var snapshot_detail := {}
		var sample_index := phase_index - WARMUP_TICKS
		if measured and sample_index % 2 == 0:
			snapshot_detail = _snapshot_evidence(world, "repeat %d tick %d" % [repeat_number, world.tick])
			snapshot_count += 1
			snapshot_samples.append(int(snapshot_detail.capture_pack_us))
			snapshot_rejections += 1 if bool(snapshot_detail.rejected) else 0
			network_gaps += 1 if bool(snapshot_detail.gap) else 0
			var overflow: Array = snapshot_detail.overflow
			for overflow_index: int in range(4):
				maximum_overflow[overflow_index] = maxi(maximum_overflow[overflow_index], int(overflow[overflow_index]))
			peak_datagram_bytes = maxi(peak_datagram_bytes, int(snapshot_detail.peak_datagram_bytes))
			peak_datagram_count = maxi(peak_datagram_count, int(snapshot_detail.packet_count))
		DrillCombat.reset()
		var observed := DrillSampler.measured_step(mirror, mirror_commands)
		_check(bool(observed.ok), "repeat %d observed tick %d" % [repeat_number, mirror.tick])
		_check_exact_tick(world, mirror, "repeat %d tick %d" % [repeat_number, world.tick])
		_record_tick(world, full_trace, event_counts)
		if not measured:
			continue
		measurement_trace.update(_trace_bytes(world))
		samples.append(production_us)
		over_budget += 1 if production_us > TICK_BUDGET_US else 0
		for key: String in DrillCombat.counts:
			combat_totals[key] = int(combat_totals.get(key, 0)) + int(DrillCombat.counts[key])
		print("PROJECTILE_DRILL_TICK ", JSON.stringify({
			"repeat":repeat_number, "sample_index":sample_index, "tick":world.tick,
			"source_inventory_sha256":source_inventory_sha256, "production_command_order":"reverse" if production_reverse else "forward",
			"production_us":production_us, "stages_us":observed.times, "projectile_nested_us":DrillCombat.times.duplicate(),
			"projectile_counts":DrillCombat.counts.duplicate(), "projectiles_after":world.projectiles.size(),
			"reactions_after":world.reactions.size(), "deposits_after":world.deposits.size(),
			"snapshot_capture_pack_us":int(snapshot_detail.get("capture_pack_us", -1)),
			"snapshot_overflow":snapshot_detail.get("overflow", []), "snapshot_packet_count":int(snapshot_detail.get("packet_count", 0)),
		}))
	var cleanup_ticks := 0
	while cleanup_ticks < CLEANUP_LIMIT and (not world.projectiles.is_empty() or not world.fields.is_empty() or _has_pending_cast(world) or not world.deposits.is_empty() or not world.reactions.is_empty()):
		var production_commands := _commands(world, false, production_reverse, false, field_opening)
		var mirror_commands := _commands(mirror, false, not production_reverse, false, field_opening)
		_check(world.step(production_commands), "repeat %d production cleanup %d" % [repeat_number, cleanup_ticks])
		DrillCombat.reset()
		var observed := DrillSampler.measured_step(mirror, mirror_commands)
		_check(bool(observed.ok), "repeat %d observed cleanup %d" % [repeat_number, cleanup_ticks])
		_check_exact_tick(world, mirror, "repeat %d cleanup tick %d" % [repeat_number, world.tick])
		_record_tick(world, full_trace, event_counts)
		cleanup_ticks += 1
	_check(world.projectiles.is_empty() and world.fields.is_empty() and world.deposits.is_empty() and world.reactions.is_empty() and not _has_pending_cast(world), "repeat %d all material naturally expires" % repeat_number)
	_check(world.step([]), "repeat %d production final idle" % repeat_number)
	DrillCombat.reset()
	var final_observed := DrillSampler.measured_step(mirror, [])
	_check(bool(final_observed.ok), "repeat %d observed final idle" % repeat_number)
	_check_exact_tick(world, mirror, "repeat %d final tick %d" % [repeat_number, world.tick])
	_record_tick(world, full_trace, event_counts)
	_check(world.combat_events.is_empty(), "repeat %d final idle releases prior events" % repeat_number)
	_check(snapshot_count == LEGAL_TICKS / 2, "repeat %d captures every other measured tick" % repeat_number)
	_check(snapshot_rejections == 0, "repeat %d has no snapshot packet rejection" % repeat_number)
	_check(network_gaps == 0, "repeat %d has no projectile/field or transport gap" % repeat_number)
	return {
		"repeat":repeat_number, "scenario":"legal-eight-field-opening" if field_opening else "legal-eight-mixed-deliveries",
		"production_command_order":"reverse" if production_reverse else "forward", "mirror_command_order":"forward" if production_reverse else "reverse",
		"map_mode":"sanctum_campus_g2_v1" if real_map_loaded else "fixed_synthetic_zero_obstacles",
		"real_map_requested":real_map_requested, "real_map_loaded":real_map_loaded, "map_id":world.map_id, "map_hash":world.map_hash,
		"obstacle_count":world.collision.obstacle_view().size(), "source_inventory_sha256":source_inventory_sha256, "source_records":source_records,
		"sample_ticks":samples.size(), "production_step_us":_percentiles(samples), "ticks_over_8333_us":over_budget,
		"projectile_counter_totals":combat_totals, "cleanup_ticks":cleanup_ticks, "event_counts":event_counts,
		"measurement_trace_sha256":measurement_trace.finish().hex_encode(), "full_trace_sha256":full_trace.finish().hex_encode(),
		"snapshot_samples":snapshot_count, "snapshot_capture_and_pack_us":_percentiles(snapshot_samples),
		"snapshot_rejections":snapshot_rejections, "network_gap_samples":network_gaps,
		"maximum_overflow_projectiles_fields_events_targets":Array(maximum_overflow),
		"peak_datagram_bytes":peak_datagram_bytes, "peak_datagram_count":peak_datagram_count,
		"final_hash":world.state_hash(), "final_next_ids":_next_ids(world),
	}


func _check_exact_tick(world: SimWorld, mirror: SimWorld, label: String) -> void:
	_check(world.state_hash() == mirror.state_hash(), "%s state hash agrees" % label)
	_check(world.combat_events == mirror.combat_events, "%s ordered events agree" % label)
	_check(world.next_projectile_id == mirror.next_projectile_id, "%s next projectile id agrees" % label)
	_check(world.next_field_id == mirror.next_field_id, "%s next field id agrees" % label)
	_check(world.next_deposit_id == mirror.next_deposit_id, "%s next deposit id agrees" % label)
	_check(world.next_reaction_id == mirror.next_reaction_id, "%s next reaction id agrees" % label)
	_check(_canonical_entities(world.projectiles) == _canonical_entities(mirror.projectiles), "%s raw ordered projectile values agree" % label)
	_check(_canonical_entities(world.deposits) == _canonical_entities(mirror.deposits), "%s raw ordered deposit values agree" % label)
	_check(_canonical_entities(world.reactions) == _canonical_entities(mirror.reactions), "%s raw ordered reaction values agree" % label)


func _snapshot_evidence(world: SimWorld, label: String) -> Dictionary:
	var began := Time.get_ticks_usec()
	var snapshot := SessionSnapshot.capture(world, {}, world.combat_events)
	var packets: Array[Dictionary] = SessionTransport._snapshot_wire_packets(snapshot)
	var capture_pack_us := Time.get_ticks_usec() - began
	var valid := SessionSnapshot.validate(snapshot)
	_check(valid, "%s snapshot validates" % label)
	if not valid:
		return {"capture_pack_us":capture_pack_us, "overflow":[0, 0, 0, 0], "packet_count":0, "peak_datagram_bytes":0, "rejected":true, "gap":true}
	var target_count := 0
	for state: PlayerState in world.players:
		target_count += 1 if state.actor_kind == PlayerState.ActorKind.TRAINING_TARGET else 0
	var expected_overflow := [maxi(0, world.projectiles.size() - SessionSnapshot.MAX_PROJECTILES), maxi(0, world.fields.size() - SessionSnapshot.MAX_FIELDS), maxi(0, world.combat_events.size() - SessionSnapshot.MAX_EVENTS), maxi(0, target_count - SessionSnapshot.MAX_TARGETS)]
	var overflow: PackedInt32Array = snapshot["overflow"]
	_check(Array(overflow) == expected_overflow, "%s overflow counters are exact" % label)
	var rejected := packets.is_empty()
	_check(not rejected, "%s snapshot packetization is accepted" % label)
	var peak_datagram_bytes := 0
	if not rejected:
		var client := SessionTransport.new()
		client.mode = SessionTransport.Mode.CLIENT
		packets.reverse()
		for packet_index: int in range(packets.size()):
			var encoded := var_to_bytes(packets[packet_index])
			peak_datagram_bytes = maxi(peak_datagram_bytes, encoded.size())
			_check(encoded.size() <= SessionTransport.ENET_MTU_BYTES, "%s fragment fits MTU" % label)
			client._handle_packet(SessionTransport.SERVER_PEER_ID, encoded)
			if packet_index < packets.size() - 1:
				_check(client.incoming_snapshots.is_empty(), "%s incomplete fragments publish no frame" % label)
		var received := client.take_snapshots()
		_check(received.size() == 1 and received[0] == snapshot, "%s reversed fragments reconstruct exactly" % label)
	return {"capture_pack_us":capture_pack_us, "overflow":Array(overflow), "packet_count":packets.size(), "peak_datagram_bytes":peak_datagram_bytes, "rejected":rejected, "gap":rejected or overflow[0] > 0 or overflow[1] > 0}


func _record_tick(world: SimWorld, trace: HashingContext, counts: Dictionary) -> void:
	trace.update(_trace_bytes(world))
	for event: Dictionary in world.combat_events:
		var kind := String(event.get("type", ""))
		counts[kind] = int(counts.get(kind, 0)) + 1


func _next_ids(world: SimWorld) -> Dictionary:
	return {"projectile":world.next_projectile_id, "field":world.next_field_id, "deposit":world.next_deposit_id, "reaction":world.next_reaction_id}
