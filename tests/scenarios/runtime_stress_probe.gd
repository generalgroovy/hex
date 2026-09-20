extends SceneTree


# Standalone production-path diagnostic, deliberately outside the ordinary Full
# suite. Fixture injection is offline only; it does not raise Farflow capacity.
# --quick selects the legal eight-actor journey only.
# --require-network-clear turns observed legal-load transport gaps into failure.
# --stages adds a subsystem-timed mirror, checked against real step each tick.
const StageSampler = preload("res://tests/scenarios/runtime_stage_sampler.gd")
const CampusLayout = preload("res://src/content/sanctum_campus_layout.gd")
const SEED: int = 608_120
const WARMUP_TICKS: int = 120
const LEGAL_TICKS: int = 720
const FIXTURE_TICKS: int = 120
const CLEANUP_LIMIT: int = 1_200
const TICK_BUDGET_US: int = 8_333

var failures: int = 0
var assertions: int = 0
var abilities := AbilityCatalog.new()
var champions := ChampionCatalog.new()
var legal_network_gaps: int = 0
var executed_scenarios: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if OS.get_cmdline_user_args().has("--collision-only"):
		var suite := preload("res://tests/unit/test_collision_broadphase.gd").new()
		quit(suite.run())
		return
	var abilities_loaded := abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json")
	_check(abilities_loaded, "ability content loads: %s" % abilities.last_error)
	var champions_loaded := champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities)
	_check(champions_loaded, "champion content loads: %s" % champions.last_error)
	if failures > 0:
		quit(1)
		return
	if OS.get_cmdline_user_args().has("--chemistry-stages") and not OS.get_cmdline_user_args().has("--stages"):
		_check(false, "chemistry attribution requires the separate --stages mirror")
		quit(1)
		return
	var source_hashes := _source_hashes()
	for path: String in source_hashes:
		print("RUNTIME_SOURCE ", JSON.stringify({"path":path,"sha256":source_hashes[path]}))
	print("RUNTIME_PROBE_META ", JSON.stringify({
		"version": 1, "engine": Engine.get_version_info()["string"],
		"protocol": SimConfig.PROTOCOL_VERSION, "snapshot_schema": SessionSnapshot.SCHEMA_VERSION,
		"seed": SEED, "tick_rate": 120, "cpu": OS.get_processor_name(),
		"ability_sha256": FileAccess.get_sha256("res://content/abilities/foundation_abilities_v1.json"),
		"champion_sha256": FileAccess.get_sha256("res://content/champions/foundation_champions_v1.json"),
		"sim_world_sha256": FileAccess.get_sha256("res://src/sim/core/sim_world.gd"),
		"stage_mirror_enabled": OS.get_cmdline_user_args().has("--stages"),
		"chemistry_mirror_enabled": OS.get_cmdline_user_args().has("--chemistry-stages"),
		"source_inventory_sha256": CanonicalContent.sha256(source_hashes),
		"source_records": source_hashes.size(),
		"source_scope": "all filesystem files under src, content, tests/scenarios, plus project.godot; headless runtime/fixture identity, not image assets or export identity",
		"warmup_ticks": WARMUP_TICKS,
		"map_mode": "sanctum_campus_g2_v1" if OS.get_cmdline_user_args().has("--real-map") else "fixed_synthetic",
		"measurement": "SimWorld.step only; snapshots timed separately; no rendered FPS or socket/network capacity claim",
	}))
	_run_pair("legal-eight-burst", 8, 0, 0, 0, true)
	# Explicitly selected: keep the established --quick workload unchanged.
	if OS.get_cmdline_user_args().has("--scenario=legal-eight-mixed-deliveries"):
		_run_pair("legal-eight-mixed-deliveries", 8, 0, 0, 0, true)
	if OS.get_cmdline_user_args().has("--scenario=legal-eight-field-opening"):
		_run_pair("legal-eight-field-opening", 8, 0, 0, 0, true)
	if not OS.get_cmdline_user_args().has("--quick"):
		_run_pair("admitted-eight-envelope", 8, SimConfig.MAX_ACTIVE_PROJECTILES, SimConfig.MAX_ACTIVE_FIELDS, 64, false)
		_run_pair("eight-256-projectiles-open", 8, 256, 16, 0, false)
		_run_pair("eight-256-projectiles-16-fields", 8, 256, 16, 64, false)
		_run_pair("offline-32-256-projectiles", 32, 256, 16, 64, false)
		_run_pair("offline-64-1024-projectiles", 64, 1024, 32, 64, false)
	if OS.get_cmdline_user_args().has("--require-network-clear"):
		_check(legal_network_gaps == 0, "legal eight-player load has no omitted danger or rejected snapshot")
	_check(executed_scenarios > 0, "at least one known scenario was selected")
	print("%s: runtime-stress-probe; %d assertions; %d failures; legal network-gap samples=%d" % [
		"PASS" if failures == 0 else "FAIL", assertions, failures, legal_network_gaps,
	])
	if legal_network_gaps > 0:
		print("DIAGNOSTIC: legal eight-player network coverage is NOT accepted; use --require-network-clear as its fail-closed gate.")
	quit(0 if failures == 0 else 1)


func _run_pair(label: String, actor_count: int, projectile_count: int, field_count: int, obstacle_count: int, legal_casts: bool) -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--scenario=") and argument.trim_prefix("--scenario=") != label:
			return
	executed_scenarios += 1
	var reference: Dictionary = {}
	for repeat_index: int in range(2):
		var result := _run_scenario(label, actor_count, projectile_count, field_count, obstacle_count, legal_casts, repeat_index == 1)
		if repeat_index == 0:
			reference = result
		else:
			_check(result["checkpoints"] == reference["checkpoints"], "%s repeat hashes agree with reversed command order" % label)
			_check(result["final_hash"] == reference["final_hash"], "%s final clean-world hash agrees" % label)
			_check(result["expiry_events"] == reference["expiry_events"], "%s lifecycle event counts repeat" % label)
			_check(result["measurement_trace_sha256"] == reference["measurement_trace_sha256"], "%s every measured state/event/id trace agrees" % label)
			_check(result["full_trace_sha256"] == reference["full_trace_sha256"], "%s warmup through cleanup trace agrees" % label)
		result["repeat"] = repeat_index + 1
		# Bounded lines keep the checked wrapper's durable log scan responsive.
		for tick_detail: Dictionary in result.chemistry_raw_ticks:
			tick_detail["repeat"] = repeat_index + 1
			print("RUNTIME_CHEMISTRY_TICK ", JSON.stringify(tick_detail))
		result.erase("chemistry_raw_ticks")
		print("RUNTIME_PROBE_RESULT ", JSON.stringify(result))


func _run_scenario(label: String, actor_count: int, projectile_count: int, field_count: int, obstacle_count: int, legal_casts: bool, reverse_commands: bool) -> Dictionary:
	var mixed_deliveries := label == "legal-eight-mixed-deliveries"
	var field_opening := label == "legal-eight-field-opening"
	var world := _make_world(actor_count, obstacle_count, mixed_deliveries, field_opening)
	var mirror: SimWorld = _make_world(actor_count, obstacle_count, mixed_deliveries, field_opening) if OS.get_cmdline_user_args().has("--stages") else null
	var stage_samples := {}
	var chemistry_samples := {}
	var chemistry_totals := {}
	var chemistry_ticks: Array[Dictionary] = []
	var measurement_trace := HashingContext.new()
	measurement_trace.start(HashingContext.HASH_SHA256)
	var full_trace := HashingContext.new()
	full_trace.start(HashingContext.HASH_SHA256)
	var slowest_stages: Array[Dictionary] = []
	if mirror != null:
		for stage: String in StageSampler.STAGES:
			stage_samples[stage] = PackedInt64Array()
		if OS.get_cmdline_user_args().has("--chemistry-stages"):
			for phase: String in StageSampler.CHEMISTRY_SUBPHASES:
				chemistry_samples[phase] = PackedInt64Array()
	_check(world.is_valid(), "%s world starts valid" % label)
	for _warmup: int in range(WARMUP_TICKS):
		_check(world.step(_commands(world, false, reverse_commands, false, field_opening)), "%s warmup step" % label)
		full_trace.update(_trace_bytes(world))
		if mirror != null:
			_check(bool(StageSampler.measured_step(mirror, _commands(mirror, false, reverse_commands, false, field_opening)).ok), "%s mirror warmup step" % label)
			_check(world.state_hash() == mirror.state_hash() and world.combat_events == mirror.combat_events and world.next_reaction_id == mirror.next_reaction_id, "warmup mirror state/events/id agree")
	if not legal_casts:
		_seed_load(world, projectile_count, field_count)
		if mirror != null:
			_seed_load(mirror, projectile_count, field_count)
	var samples := PackedInt64Array()
	var snapshot_samples := PackedInt64Array()
	var integrated_tick_samples := PackedInt64Array()
	var memory_samples := PackedInt64Array()
	var memory_start := OS.get_static_memory_usage()
	var memory_peak_start := OS.get_static_memory_peak_usage()
	var checkpoints: Array[String] = []
	var peak_projectiles := world.projectiles.size()
	var peak_fields := world.fields.size()
	var peak_deposits := world.deposits.size()
	var peak_reactions := world.reactions.size()
	var peak_events := 0
	var peak_raw_bytes := 0
	var peak_wire_bytes := 0
	var peak_datagram_bytes := 0
	var peak_datagram_count := 0
	var rejected_packets := 0
	var snapshot_count := 0
	var overflow_samples := 0
	var maximum_overflow := PackedInt32Array([0, 0, 0, 0])
	var expiry_events := PackedInt32Array([0, 0])
	var over_budget_ticks := 0
	var paid_starts := {"heavy": 0, "rapid": 0, "burst": 0}
	var actual_releases := {"heavy": 0, "rapid": 0, "burst": 0}
	var paid_actors := {"heavy": {}, "rapid": {}, "burst": {}}
	var cast_refusals := {}
	var field_phase_samples := {}
	var field_observations := {"paid_starts":0,"releases":0,"triggers":0,"presence_ticks":0,"instance_ticks":0,"world_cap_ticks":0,"owner_cap_instance_ticks":0,"peak_pending":0,"peak_per_owner":0,"minimum_actor_flux":2147483647,"authored_flux_paid":0,"formation_reaction_instance_ticks":0,"active_reaction_instance_ticks":0,"decay_reaction_instance_ticks":0,"field_wires":{},"paid_by_family":{},"releases_by_family":{},"refusals_by_family":{}}
	var sample_ticks := LEGAL_TICKS if legal_casts else FIXTURE_TICKS
	for sample_index: int in range(sample_ticks):
		# Match the production renderer's read-only obstacle access each frame;
		# this must not accidentally disable the optimized simulation path.
		world.collision.obstacle_view()
		var commands := _commands(world, legal_casts, reverse_commands, mixed_deliveries, field_opening)
		var capture_this_tick := actor_count <= SessionSnapshot.MAX_PLAYERS and sample_index % 2 == 0
		var snapshot: Dictionary = {}
		var packets: Array[Dictionary] = []
		var integrated_started_us := Time.get_ticks_usec()
		var started_us := integrated_started_us
		var stepped := world.step(commands)
		var elapsed_us := Time.get_ticks_usec() - started_us
		samples.append(elapsed_us)
		if capture_this_tick:
			started_us = Time.get_ticks_usec()
			snapshot = SessionSnapshot.capture(world, {}, world.combat_events)
			packets = SessionTransport._snapshot_wire_packets(snapshot)
			snapshot_samples.append(Time.get_ticks_usec() - started_us)
			integrated_tick_samples.append(Time.get_ticks_usec() - integrated_started_us)
			snapshot_count += 1
		if elapsed_us > TICK_BUDGET_US:
			over_budget_ticks += 1
		_check(stepped, "%s sample step" % label)
		var canonical_hash := world.state_hash()
		measurement_trace.update((canonical_hash + ":" + str(world.next_reaction_id) + ":" + JSON.stringify(world.combat_events) + "\n").to_utf8_buffer())
		full_trace.update((canonical_hash + ":" + str(world.next_reaction_id) + ":" + JSON.stringify(world.combat_events) + "\n").to_utf8_buffer())
		if field_opening:
			_observe_field_opening(world,field_observations,cast_refusals)
		if mixed_deliveries:
			for event: Dictionary in world.combat_events:
				var kind := String(event.get("type", ""))
				var wire := int(event.get("wire_id", 0))
				var family := "rapid" if wire >= 180 and wire <= 194 and wire % 2 == 0 else ("heavy" if wire >= 179 and wire <= 193 else "burst")
				if kind == "cast_started":
					paid_starts[family] += 1
					paid_actors[family][int(event["entity_id"])] = true
				if kind == "projectile_spawned": actual_releases[family] += 1
				if kind == "cast_refused":
					var reason := String(event.get("reason", "unknown"))
					cast_refusals[reason] = int(cast_refusals.get(reason, 0)) + 1
		if mirror != null:
			var stage_result: Dictionary = StageSampler.measured_step(mirror, commands)
			_check(bool(stage_result.ok), "%s stage mirror step" % label)
			_check(canonical_hash == mirror.state_hash(), "%s stage mirror canonical state agrees at tick %d" % [label, world.tick])
			_check(world.combat_events == mirror.combat_events, "%s stage mirror events agree at tick %d" % [label, world.tick])
			_check(world.next_reaction_id == mirror.next_reaction_id, "%s stage mirror next reaction id agrees at tick %d" % [label, world.tick])
			var detail: Dictionary = stage_result.get("chemistry_detail", {})
			if not detail.is_empty():
				_check(detail.times.size() == StageSampler.CHEMISTRY_SUBPHASES.size(), "chemistry observer returns exactly the expected subphases")
				for phase: String in StageSampler.CHEMISTRY_SUBPHASES:
					_check(detail.times.has(phase), "chemistry observer includes expected phase: %s" % phase)
				_check(_canonical_entities(world.deposits) == _canonical_entities(mirror.deposits), "chemistry mirror ordered deposit values agree")
				_check(_canonical_entities(world.reactions) == _canonical_entities(mirror.reactions), "chemistry mirror ordered reaction values agree")
				for phase: String in detail.times:
					var phase_values: PackedInt64Array = chemistry_samples.get(phase, PackedInt64Array())
					phase_values.append(int(detail.times[phase]))
					chemistry_samples[phase] = phase_values
				for counter: String in detail.counts:
					chemistry_totals[counter] = int(chemistry_totals.get(counter, 0)) + int(detail.counts[counter])
				chemistry_ticks.append({"tick": world.tick, "times_us": detail.times, "counts": detail.counts})
			if field_opening:
				_record_field_phase(world,elapsed_us,stage_result.times,field_phase_samples)
			var sum_us := 0
			for stage: String in StageSampler.STAGES:
				var duration := int(stage_result.times[stage])
				var stage_values: PackedInt64Array = stage_samples[stage]
				stage_values.append(duration)
				stage_samples[stage] = stage_values
				sum_us += duration
			slowest_stages.append({"tick": world.tick, "production_us": elapsed_us, "stage_sum_us": sum_us, "times_us": stage_result.times, "projectiles": world.projectiles.size(), "fields": world.fields.size(), "deposits": world.deposits.size(), "reactions": world.reactions.size()})
			slowest_stages.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.stage_sum_us) > int(b.stage_sum_us))
			if slowest_stages.size() > 8:
				slowest_stages.resize(8)
		peak_projectiles = maxi(peak_projectiles, world.projectiles.size())
		peak_fields = maxi(peak_fields, world.fields.size())
		peak_deposits = maxi(peak_deposits, world.deposits.size())
		peak_reactions = maxi(peak_reactions, world.reactions.size())
		peak_events = maxi(peak_events, world.combat_events.size())
		_count_expiry(world, expiry_events)
		if sample_index % 60 == 0:
			checkpoints.append(world.state_hash())
		if capture_this_tick:
			_check(SessionSnapshot.validate(snapshot), "%s authoritative snapshot validates" % label)
			var overflow: PackedInt32Array = snapshot["overflow"]
			_check(overflow[0] == maxi(0, world.projectiles.size() - SessionSnapshot.MAX_PROJECTILES), "%s projectile overflow is exact" % label)
			_check(overflow[1] == maxi(0, world.fields.size() - SessionSnapshot.MAX_FIELDS), "%s field overflow is exact" % label)
			for overflow_index: int in range(4):
				maximum_overflow[overflow_index] = maxi(maximum_overflow[overflow_index], overflow[overflow_index])
			var missing_danger := overflow[0] > 0 or overflow[1] > 0
			if missing_danger:
				overflow_samples += 1
			peak_raw_bytes = maxi(peak_raw_bytes, var_to_bytes(snapshot).size())
			# Measure the rejected envelope too; an empty production packet must
			# never be mistaken for a zero-byte successful transmission.
			var raw := var_to_bytes(snapshot)
			var candidate := {"kind": SessionTransport.PACKET_SNAPSHOT, "raw_size": raw.size(), "payload": raw.compress(FileAccess.COMPRESSION_FASTLZ)}
			peak_wire_bytes = maxi(peak_wire_bytes, var_to_bytes(candidate).size())
			if packets.is_empty():
				rejected_packets += 1
			else:
				peak_datagram_count = maxi(peak_datagram_count, packets.size())
				var client := SessionTransport.new()
				client.mode = SessionTransport.Mode.CLIENT
				packets.reverse()
				for packet_index: int in range(packets.size()):
					var encoded := var_to_bytes(packets[packet_index])
					peak_datagram_bytes = maxi(peak_datagram_bytes, encoded.size())
					_check(encoded.size() <= SessionTransport.ENET_MTU_BYTES, "%s every fragment fits one MTU" % label)
					client._handle_packet(SessionTransport.SERVER_PEER_ID, encoded)
					if packet_index < packets.size() - 1:
						_check(client.incoming_snapshots.is_empty(), "%s incomplete reversed fragments publish no partial frame" % label)
				var received := client.take_snapshots()
				_check(received.size() == 1 and received[0] == snapshot, "%s accepted reversed fragments reconstruct exactly one complete snapshot" % label)
			if legal_casts and (missing_danger or packets.is_empty()):
				legal_network_gaps += 1
		memory_samples.append(OS.get_static_memory_usage())
	_check(peak_projectiles >= (1 if field_opening else (40 if legal_casts else projectile_count)), "%s requested projectile load was actually reached" % label)
	if field_opening:
		_check(peak_fields == SimConfig.MAX_ACTIVE_FIELDS, "legal paid opening reaches the existing world Field cap")
		_check(int(field_observations.peak_per_owner) == SimConfig.MAX_FIELDS_PER_PLAYER, "legal paid opening reaches the existing owner Field cap")
		_check(int(field_observations.triggers) >= 8, "Fields really trigger on opposing actors, not only empty-space fixtures")
		_check((field_observations.field_wires as Dictionary).size() == 8, "all eight real elemental Field identities release")
		_check(int(cast_refusals.get("capacity",0)) >= 8, "a fifth Field attempt is refused before payment for every capped owner")
	if mixed_deliveries:
		for family: String in ["heavy", "rapid", "burst"]:
			_check((paid_actors[family] as Dictionary).size() == 8 and int(actual_releases[family]) >= 8, "%s all eight actors really pay for %s and actual projectiles release" % [label, family])
	if not legal_casts:
		_check(world.projectiles.size() == projectile_count, "%s full projectile fixture survived the measurement window" % label)
		_check(world.fields.size() == field_count, "%s full field fixture survived the measurement window" % label)
	var cleanup_ticks := 0
	while cleanup_ticks < CLEANUP_LIMIT and (not world.projectiles.is_empty() or not world.fields.is_empty() or _has_pending_cast(world) or ((mixed_deliveries or field_opening) and (not world.deposits.is_empty() or not world.reactions.is_empty()))):
		_check(world.step(_commands(world, false, reverse_commands, false, field_opening)), "%s cleanup step" % label)
		full_trace.update(_trace_bytes(world))
		if mirror != null:
			_check(bool(StageSampler.measured_step(mirror, _commands(mirror, false, reverse_commands, false, field_opening)).ok), "chemistry mirror cleanup step")
			_check(world.state_hash() == mirror.state_hash() and world.combat_events == mirror.combat_events and world.next_reaction_id == mirror.next_reaction_id, "cleanup mirror state/events/id agree")
		peak_events = maxi(peak_events, world.combat_events.size())
		_count_expiry(world, expiry_events)
		cleanup_ticks += 1
	_check(world.projectiles.is_empty() and world.fields.is_empty() and not _has_pending_cast(world), "%s all projectiles/fields/pending casts expire without forced clearing" % label)
	if mixed_deliveries or field_opening:
		_check(world.deposits.is_empty() and world.reactions.is_empty(), "%s terminal matter and reactions also expire without forced clearing" % label)
	if not legal_casts:
		_check(expiry_events[0] == projectile_count and expiry_events[1] == field_count, "%s every injected asset emits exactly one expiry" % label)
	_check(world.combat_events.size() <= projectile_count + field_count + actor_count * 5, "%s events remain tick-scoped during simultaneous expiry" % label)
	_check(world.step([]), "%s one idle step after cleanup" % label)
	full_trace.update(_trace_bytes(world))
	if mirror != null:
		_check(bool(StageSampler.measured_step(mirror, []).ok), "mirror idle step after cleanup")
		_check(world.state_hash() == mirror.state_hash() and world.combat_events == mirror.combat_events and world.next_reaction_id == mirror.next_reaction_id, "final mirror state/events/id agree")
	_check(world.combat_events.is_empty(), "%s previous expiry event batch is released on next tick" % label)
	var stage_report := {}
	var chemistry_report := {}
	for phase: String in chemistry_samples:
		_check((chemistry_samples[phase] as PackedInt64Array).size() == sample_ticks, "every chemistry phase includes every measured tick")
		chemistry_report[phase] = _percentiles(chemistry_samples[phase])
	for stage: String in stage_samples:
		_check((stage_samples[stage] as PackedInt64Array).size() == sample_ticks, "%s every stage includes every measured tick" % label)
		stage_report[stage] = _percentiles(stage_samples[stage])
	if field_opening:
		for family: String in ["heavy","rapid","burst"]:
			actual_releases[family] = int(field_observations.releases_by_family.get(family,0))
	var field_phase_report := {}
	for phase: String in field_phase_samples:
		var bucket: Dictionary = field_phase_samples[phase]
		field_phase_report[phase] = {"ticks":(bucket.step as PackedInt64Array).size()}
		for stage: String in bucket:
			field_phase_report[phase][stage+"_us"] = _percentiles(bucket[stage])
	return {
		"scenario": label, "actor_count": actor_count, "obstacle_count": world.collision.obstacle_view().size(),
		"map_id": world.map_id, "map_hash": world.map_hash,
		"obstacle_path": "live sanctum campus indexed collision" if OS.get_cmdline_user_args().has("--real-map") else ("legacy linear" if OS.get_cmdline_user_args().has("--linear-obstacles") else "indexed with bounded/small-map fallback"),
		"source": "ordinary paid spell commands" if legal_casts else "offline initial-state load fixture; ordinary authoritative updates",
		"sample_ticks": sample_ticks, "tick_us": _percentiles(samples), "ticks_over_8333_us": over_budget_ticks,
		"peak_projectiles": peak_projectiles, "peak_fields": peak_fields, "peak_events": peak_events,
		"peak_deposits": peak_deposits, "peak_reactions": peak_reactions,
		"paid_starts_by_delivery": field_observations.paid_by_family if field_opening else paid_starts, "projectile_releases_by_delivery": actual_releases, "cast_refusals_by_reason": cast_refusals,
		"field_opening_observations": field_observations if field_opening else {},
		"field_phase_timings": field_phase_report,
		"authority_caps": {"projectiles":SimConfig.MAX_ACTIVE_PROJECTILES,"fields":SimConfig.MAX_ACTIVE_FIELDS,"owner_projectiles":SimConfig.MAX_PROJECTILES_PER_PLAYER,"owner_fields":SimConfig.MAX_FIELDS_PER_PLAYER,"deposits":ElementChemistrySystem.MAX_DEPOSITS,"reactions":ElementChemistrySystem.MAX_REACTIONS},
		"stage_mirror_us": stage_report, "slowest_stage_samples": slowest_stages,
		"chemistry_subphase_us": chemistry_report, "chemistry_counter_totals": chemistry_totals,
		"chemistry_raw_ticks": chemistry_ticks,
		"chemistry_measurement_limits": "instrumented mirror only; pair_gate_clear_line nested in pair_admission; construction/path LOS remains embedded and uncounted; inventory and active counts are instance-ticks; pair-gate LOS samples are upper bounds; occupied rejects count only LOS-clear pairs; static memory is not transient allocations",
		"measurement_trace_sha256": measurement_trace.finish().hex_encode(),
		"full_trace_sha256": full_trace.finish().hex_encode(),
		"snapshot_samples": snapshot_count, "snapshot_capture_and_pack_us": _percentiles(snapshot_samples),
		"sim_plus_every_other_snapshot_us": _percentiles(integrated_tick_samples),
		"static_memory_bytes": {"start":memory_start,"samples":_percentiles(memory_samples),"end":OS.get_static_memory_usage(),"peak_start":memory_peak_start,"peak_end":OS.get_static_memory_peak_usage()},
		"peak_snapshot_raw_bytes": peak_raw_bytes, "peak_candidate_wire_bytes": peak_wire_bytes,
		"peak_datagram_bytes": peak_datagram_bytes, "peak_datagram_count": peak_datagram_count,
		"snapshot_rejections": rejected_packets, "danger_overflow_samples": overflow_samples,
		"maximum_overflow_projectiles_fields_events_targets": Array(maximum_overflow),
		"network_scope": "eight-player presentation envelope" if actor_count <= SessionSnapshot.MAX_PLAYERS else "not attempted; above supported lobby ceiling",
		"expiry_events": Array(expiry_events), "cleanup_ticks": cleanup_ticks,
		"checkpoints": checkpoints, "final_hash": world.state_hash(),
	}


func _trace_bytes(world: SimWorld) -> PackedByteArray:
	return (world.state_hash() + ":" + str(world.next_reaction_id) + ":" + JSON.stringify(world.combat_events) + "\n").to_utf8_buffer()


func _canonical_entities(entities: Array) -> Array:
	var values: Array = []
	for entity: Variant in entities:
		values.append(entity.canonical_values())
	return values


func _source_hashes() -> Dictionary:
	var hashes := {}
	var paths: Array[String] = ["project.godot"]
	for directory: String in ["src", "content", "tests/scenarios"]:
		_collect_source_files(directory, paths)
	paths.sort()
	for path: String in paths:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	return hashes


func _collect_source_files(directory: String, paths: Array[String]) -> void:
	for filename: String in DirAccess.get_files_at("res://" + directory):
		paths.append(directory.path_join(filename))
	for child: String in DirAccess.get_directories_at("res://" + directory):
		_collect_source_files(directory.path_join(child), paths)


func _make_world(actor_count: int, obstacle_count: int, mixed_deliveries: bool = false, field_opening: bool = false) -> SimWorld:
	var use_real_map := OS.get_cmdline_user_args().has("--real-map")
	var layout = CampusLayout.new() if use_real_map else null
	var layout_loaded := layout != null and layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json")
	if use_real_map:
		_check(layout_loaded, "live Sanctum campus loads for real-map runtime probe: %s" % layout.last_error)
	var collision := layout.build_collision_world() if layout_loaded else CollisionWorld.new(12_000_000, 6_000_000)
	if not use_real_map:
		for index: int in range(obstacle_count):
			var x := 7_000_000 + (index % 8) * 400_000
			@warning_ignore("integer_division")
			var y := 3_000_000 + (index / 8) * 300_000
			collision.add_obstacle(CollisionWorld.Obstacle.new(index + 1, x, y, x + 160_000, y + 160_000))
	var map_id := String(layout.data.get("id", "")) if layout_loaded else "runtime-stress-v1"
	var map_hash: String = layout.content_hash if layout_loaded else "offline-fixture:12000x6000;obstacles:%d" % obstacle_count
	var world := SimWorld.new(120, SEED, collision, map_id, map_hash)
	world.players.clear()
	var champion_ids := champions.ordered_champion_ids()
	for index: int in range(actor_count):
		var state := PlayerState.new(index + 1)
		_check(champions.apply_to_player(state, champion_ids[index % champion_ids.size()]), "fixture uses validated champion stats")
		if layout_loaded:
			var spawn_value: Array = (layout.arena_definition.get("spawns", []) as Array)[index % 8]
			state.position_x = int(spawn_value[0]) * SimConfig.FIXED_SCALE
			state.position_y = int(spawn_value[1]) * SimConfig.FIXED_SCALE
		else:
			state.position_x = 1_000_000 + (index % 8) * 600_000
			@warning_ignore("integer_division")
			state.position_y = 2_000_000 + (index / 8) * 300_000
		state.team_id = index + 1
		_check(state.place_proven_spell(0, CombatTuning.ELEMENTAL_BURST_WIRE_IDS[index % 8]), "fixture equips a real elemental Burst")
		if mixed_deliveries:
			_check(state.place_proven_spell(0, 179 + (index % 8) * 2), "mixed fixture equips the actual elemental Heavy")
			_check(state.place_proven_spell(1, 180 + (index % 8) * 2), "mixed fixture equips the actual elemental Rapid")
			_check(state.place_proven_spell(2, CombatTuning.ELEMENTAL_BURST_WIRE_IDS[index % 8]), "mixed fixture keeps the actual elemental Wave")
		if field_opening:
			# Four paired lanes make the existing non-damaging Fields actually
			# trigger in the synthetic fixture. The live-map switch keeps its
			# validated arena spawns. Neither path bypasses payment or cooldowns.
			if not layout_loaded:
				@warning_ignore("integer_division")
				state.position_x = 1_000_000 + (index / 2) * 600_000
				state.position_y = 2_000_000 + (index % 2) * 220_000
			var other_elements := ["fire","water","earth","wind","charge","light","dark"]
			for slot: int in range(5):
				var element := "ice" if slot == 0 else String(other_elements[(index+slot-1)%7])
				var definition := abilities.ability(abilities.spell_id_at(element,"field"))
				_check(int(definition.get("flux_cost",0)) > 0, "Field opening uses a positive-cost authored spell")
				_check(state.place_proven_spell(slot,int(definition.wire_id)), "Field opening equips real independent Field slots")
			_check(state.place_proven_spell(5,179+(index%8)*2), "Field opening equips a real Heavy")
			_check(state.place_proven_spell(6,180+(index%8)*2), "Field opening equips a real Rapid")
			_check(state.place_proven_spell(7,CombatTuning.ELEMENTAL_BURST_WIRE_IDS[index%8]), "Field opening equips a real Wave")
		world.players.append(state)
	if OS.get_cmdline_user_args().has("--linear-obstacles") and not use_real_map:
		var legacy_array := collision.obstacles
		_check(legacy_array.size() == obstacle_count, "explicit linear-reference benchmark preserves all obstacles")
	return world


func _commands(world: SimWorld, allow_casts: bool, reverse_order: bool, mixed_deliveries: bool = false, field_opening: bool = false) -> Array[SimCommand]:
	var commands: Array[SimCommand] = []
	for state: PlayerState in world.players:
		# Parallel lanes keep actors alive and exercise real geometric target
		# checks. No health refill, cooldown bypass or per-tick state rewrite.
		var direction := 1000 if world.tick % 240 < 120 else -1000
		var pressed := SimCommand.PRESSED_SPELL_1 if allow_casts and world.tick % 120 == 0 else 0
		var held := 0
		var aim_y := -1000
		if mixed_deliveries and allow_casts:
			var phase := (world.tick - WARMUP_TICKS) % 240
			pressed = SimCommand.PRESSED_SPELL_1 if phase == 0 else (SimCommand.PRESSED_SPELL_3 if phase == 60 else 0)
			held = SimCommand.SPELL_HELD_BITS[1] if phase >= 120 and phase < 200 else 0
		if field_opening:
			var phase := world.tick-WARMUP_TICKS
			direction = 0 if phase < 240 else direction
			aim_y = 1000 if state.entity_id%2 == 1 else -1000
			pressed = 0
			held = 0
			if allow_casts:
				if phase in [0,60,120,180,240]:
					@warning_ignore("integer_division")
					pressed = SimCommand.SPELL_PRESSED_BITS[phase/60]
				elif phase == 330:
					pressed = SimCommand.SPELL_PRESSED_BITS[7]
				elif phase == 420:
					pressed = SimCommand.SPELL_PRESSED_BITS[5]
				held = SimCommand.SPELL_HELD_BITS[6] if phase >= 252 and phase < 312 else 0
		commands.append(SimCommand.new(world.tick, state.entity_id, direction, 0, held, pressed, 0, aim_y))
	if reverse_order:
		commands.reverse()
	return commands


func _seed_load(world: SimWorld, projectile_count: int, field_count: int) -> void:
	var bolt := CombatTuning.cast_definition(CombatTuning.PRIMARY_WIRE_ID)
	var field_definition := CombatTuning.cast_definition(CombatTuning.RIMEWAKE_WIRE_ID)
	for index: int in range(projectile_count):
		var position := Vector2i(1_000_000 + (index % 64) * 4_000, 100_000 + (index % 31) * 9_000)
		world.projectiles.append(ProjectileState.new(world.next_projectile_id, 1, 1, CombatTuning.PRIMARY_WIRE_ID,
			int(bolt["element_wire_id"]), position, Vector2i(int(bolt["speed"]), 0), int(bolt["radius"]),
			int(bolt["damage"]), world.config.milliseconds_to_ticks(int(bolt["lifetime_ms"]))))
		world.next_projectile_id += 1
	for index: int in range(field_count):
		world.fields.append(FieldState.new(world.next_field_id, 1, 1, CombatTuning.RIMEWAKE_WIRE_ID,
			int(field_definition["element_wire_id"]), Vector2i(1_000_000 + index * 20_000, 900_000),
			int(field_definition["radius"]), world.config.milliseconds_to_ticks(int(field_definition["lifetime_ms"])),
			int(field_definition["hit_control_state"]), int(field_definition["hit_control_duration_ms"]),
			int(field_definition["hit_control_slow_ratio"])))
		world.next_field_id += 1


func _observe_field_opening(world: SimWorld,observed: Dictionary,refusals: Dictionary) -> void:
	# Observation is outside the measured production step and never changes the
	# world. Count released live Fields separately from paid startup reservations.
	var by_owner := {}
	for field: FieldState in world.fields:
		by_owner[field.owner_id] = int(by_owner.get(field.owner_id,0))+1
	observed.instance_ticks += world.fields.size()
	observed.presence_ticks += int(not world.fields.is_empty())
	observed.world_cap_ticks += int(world.fields.size() == SimConfig.MAX_ACTIVE_FIELDS)
	var pending := 0
	for actor: PlayerState in world.players:
		var owned := int(by_owner.get(actor.entity_id,0))
		observed.peak_per_owner = maxi(int(observed.peak_per_owner),owned)
		observed.owner_cap_instance_ticks += int(owned == SimConfig.MAX_FIELDS_PER_PLAYER)
		observed.minimum_actor_flux = mini(int(observed.minimum_actor_flux),actor.flux)
		if actor.pending_cast_wire_id != 0 and String(CombatTuning.cast_definition(actor.pending_cast_wire_id).get("shape","")) == "field":
			pending += 1
	observed.peak_pending = maxi(int(observed.peak_pending),pending)
	for reaction: ElementReactionState in world.reactions:
		if world.tick-1 < reaction.active_tick:
			observed.formation_reaction_instance_ticks += 1
		elif reaction.active(world.tick-1):
			observed.active_reaction_instance_ticks += 1
		else:
			observed.decay_reaction_instance_ticks += 1
	for event: Dictionary in world.combat_events:
		var kind := String(event.get("type",""))
		var wire := int(event.get("wire_id",event.get("source_wire_id",0)))
		var definition := abilities.ability_from_wire(wire)
		var family := AbilityCatalog._spell_family(definition) if not definition.is_empty() else "unknown"
		if kind == "cast_started":
			var cost := int(CombatTuning.cast_definition(wire).get("flux_cost",0))
			_check(cost > 0,"every observed cast start pays positive authored Flux")
			observed.authored_flux_paid += cost
			observed.paid_by_family[family] = int(observed.paid_by_family.get(family,0))+1
			observed.paid_starts += int(family == "field")
		elif kind in ["field_spawned","projectile_spawned"]:
			observed.releases_by_family[family] = int(observed.releases_by_family.get(family,0))+1
			if kind == "field_spawned":
				observed.releases += 1
				observed.field_wires[wire] = int(observed.field_wires.get(wire,0))+1
		elif kind == "field_triggered":
			observed.triggers += 1
		elif kind == "cast_refused":
			var reason := String(event.get("reason","unknown"))
			refusals[reason] = int(refusals.get(reason,0))+1
			var key := family+":"+reason
			observed.refusals_by_family[key] = int(observed.refusals_by_family.get(key,0))+1


func _record_field_phase(world: SimWorld,step_us: int,times: Dictionary,samples: Dictionary) -> void:
	# Conditional timing buckets overlap intentionally: a capped tick also
	# belongs to fields_live, and may contain real projectiles. This avoids
	# mistaking the later no-Field tail for the cost of the saturated opening.
	var phases: Array[String] = []
	if not world.fields.is_empty():
		phases.append("fields_live")
		if world.fields.size() == SimConfig.MAX_ACTIVE_FIELDS:
			phases.append("field_cap")
		if not world.projectiles.is_empty():
			phases.append("fields_and_projectiles")
	elif not world.reactions.is_empty():
		phases.append("reaction_tail")
	for phase: String in phases:
		if not samples.has(phase):
			samples[phase] = {"step":PackedInt64Array(),"projectiles":PackedInt64Array(),"fields":PackedInt64Array(),"chemistry":PackedInt64Array(),"capacity":PackedInt64Array()}
		var bucket: Dictionary = samples[phase]
		for stage: String in bucket:
			var values: PackedInt64Array = bucket[stage]
			values.append(step_us if stage == "step" else int(times[stage]))
			bucket[stage] = values


func _has_pending_cast(world: SimWorld) -> bool:
	for state: PlayerState in world.players:
		if state.pending_cast_wire_id != 0:
			return true
	return false


func _count_expiry(world: SimWorld, totals: PackedInt32Array) -> void:
	for event: Dictionary in world.combat_events:
		if event.get("type") == "projectile_expired":
			totals[0] += 1
		elif event.get("type") == "field_expired":
			totals[1] += 1


func _percentiles(values: PackedInt64Array) -> Dictionary:
	if values.is_empty():
		return {}
	var ordered := values.duplicate()
	ordered.sort()
	return {"median": ordered[ceili(ordered.size() * 0.5) - 1], "p95": ordered[ceili(ordered.size() * 0.95) - 1],
		"p99": ordered[ceili(ordered.size() * 0.99) - 1], "max": ordered[ordered.size() - 1]}


func _check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		print("FAIL: ", label)
