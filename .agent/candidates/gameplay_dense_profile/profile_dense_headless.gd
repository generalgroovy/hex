extends SceneTree

@warning_ignore_start("integer_division")


const Workload = preload("res://tests/performance/dense_profile_workload.gd")
const SNAPSHOT_INTERVAL_TICKS := 2

var failures := 0
var assertions := 0
var output_path := ""
var abilities := AbilityCatalog.new()
var champions := ChampionCatalog.new()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	_check(output_path.begins_with("res://.godot/dense-headless-") and output_path.ends_with(".json") and not ".." in output_path and not FileAccess.file_exists(output_path), "fresh scoped headless receipt")
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "production ability catalog loads")
	_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "production champion catalog loads")
	if failures > 0:
		_finish([])
		return
	var results: Array[Dictionary] = []
	var references := {}
	var order: Array[Dictionary] = []
	for repetition: int in range(Workload.REPETITIONS):
		var variants: Array[String] = ["hex", "ordinary"]
		if repetition % 2 == 1:
			variants.reverse()
		for variant: String in variants:
			var result := _measure(variant == "hex", repetition + 1)
			results.append(result)
			order.append({"sequence": order.size() + 1, "repetition": repetition + 1, "variant": variant})
			var invariant: Dictionary = result.invariant_outcome
			if references.has(variant):
				_check(invariant == references[variant], "%s repetitions retain identical workload outcomes" % variant)
			else:
				references[variant] = invariant
	for repetition: int in range(Workload.REPETITIONS):
		var ordinary: Dictionary = {}
		var hex: Dictionary = {}
		for item: Dictionary in results:
			if int(item.get("repetition", 0)) != repetition + 1:
				continue
			if String(item.get("variant", "")) == "ordinary":
				ordinary = item
			elif String(item.get("variant", "")) == "hex":
				hex = item
		_check(not ordinary.is_empty() and not hex.is_empty(), "both matched variants complete repetition %d" % (repetition + 1))
		if ordinary.is_empty() or hex.is_empty():
			continue
		_check(ordinary.observation.command_ticks == hex.observation.command_ticks and ordinary.observation.spell_intent_ticks == hex.observation.spell_intent_ticks and ordinary.observation.command_sha256 == hex.observation.command_sha256, "matched variants receive the same complete command payload timeline")
	_finish(results, order)


func _measure(use_hex: bool, repetition: int) -> Dictionary:
	var variant := "hex" if use_hex else "ordinary"
	var world: SimWorld = Workload.create_world(use_hex, abilities, champions)
	_check(world != null and world.is_valid(), "%s dense fixture starts valid" % variant)
	if world == null:
		return {"variant": variant, "repetition": repetition, "invariant_outcome": {}}
	_check(world.players.size() == Workload.EMITTER_COUNT, "%s uses four fixture emitters" % variant)
	_check(world.collision.width == Workload.MAP_WIDTH and world.collision.height == Workload.MAP_HEIGHT and world.collision.obstacle_view().is_empty(), "%s uses the matched empty court" % variant)
	var session := _local_session(world)
	_check(session != null, "%s binds local AuthoritativeSession fixture state" % variant)
	if session == null:
		return {"variant": variant, "repetition": repetition, "invariant_outcome": {}}
	for warmup_tick: int in range(Workload.WARMUP_TICKS):
		if not world.step(Workload.commands(world, warmup_tick, false)):
			_check(false, "%s warmup completes" % variant)
			break
	var observation := Workload.new_observation()
	var command_hash := HashingContext.new()
	_check(command_hash.start(HashingContext.HASH_SHA256) == OK, "%s command digest initializes" % variant)
	var peaks := Workload.new_peaks()
	var sim_us := PackedInt64Array()
	var retention_us := PackedInt64Array()
	var snapshot_build_us := PackedInt64Array()
	var snapshot_encode_us := PackedInt64Array()
	var diagnostic_build_us := PackedInt64Array()
	var monitor_peaks := Workload.monitor_snapshot()
	var memory_start := Workload.monitor_snapshot()
	var deadline_misses := 0
	var event_queue_accepted := 0
	var event_queue_evictions := 0
	var unencodable_events := 0
	var snapshot_rejections := 0
	var snapshot_raw_bytes_total := 0
	var snapshot_raw_bytes_peak := 0
	var packet_bytes_total := 0
	var packet_bytes_peak := 0
	var packet_count := 0
	var packet_count_peak := 0
	var snapshot_samples := 0
	var pending_event_peak := 0
	var diagnostic_bytes_total := 0
	var diagnostic_bytes_peak := 0
	var diagnostic_samples := 0
	var measured_ticks := 0
	for sample_tick: int in range(Workload.SAMPLE_TICKS):
		var commands_value: Array[SimCommand] = Workload.commands(world, sample_tick, true)
		if not Workload.hash_commands(command_hash, commands_value):
			_check(false, "%s command digest update succeeds" % variant)
		Workload.observe_commands(commands_value, observation)
		var sim_started := Time.get_ticks_usec()
		var stepped := world.step(commands_value)
		var sim_elapsed := Time.get_ticks_usec() - sim_started
		sim_us.append(sim_elapsed)
		deadline_misses += int(sim_elapsed > Workload.TICK_BUDGET_US)
		measured_ticks += 1
		if not stepped:
			_check(false, "%s measured tick %d succeeds" % [variant, sample_tick])
			break
		Workload.observe_events(world.combat_events, observation)
		Workload.observe_peaks(world, peaks)
		if use_hex:
			if sample_tick % SNAPSHOT_INTERVAL_TICKS == 0:
				var diagnostic_started := Time.get_ticks_usec()
				var diagnostic := Workload.court_canonical_diagnostic_bytes(world.hex_court)
				diagnostic_build_us.append(Time.get_ticks_usec() - diagnostic_started)
				diagnostic_samples += 1
				diagnostic_bytes_total += diagnostic.size()
				diagnostic_bytes_peak = maxi(diagnostic_bytes_peak, diagnostic.size())
				_check(CanonicalBytes.sha256_hex(diagnostic) == world.hex_court.state_hash(), "hex diagnostic bytes exactly match court state hash")
		else:
			var overflow_before := session.pending_combat_event_overflow_count
			var retention_started := Time.get_ticks_usec()
			var accepted := session.record_combat_events(world.combat_events)
			retention_us.append(Time.get_ticks_usec() - retention_started)
			event_queue_accepted += accepted
			unencodable_events += world.combat_events.size() - accepted
			event_queue_evictions += maxi(0, session.pending_combat_event_overflow_count - overflow_before)
			pending_event_peak = maxi(pending_event_peak, session.pending_combat_events.size())
			if sample_tick % SNAPSHOT_INTERVAL_TICKS == 0:
				snapshot_samples += 1
				var capture_started := Time.get_ticks_usec()
				var snapshot := session.capture_snapshot()
				snapshot_build_us.append(Time.get_ticks_usec() - capture_started)
				var raw_size := var_to_bytes(snapshot).size()
				snapshot_raw_bytes_total += raw_size
				snapshot_raw_bytes_peak = maxi(snapshot_raw_bytes_peak, raw_size)
				var encode_started := Time.get_ticks_usec()
				var packets := SessionTransport._snapshot_wire_packets(snapshot)
				snapshot_encode_us.append(Time.get_ticks_usec() - encode_started)
				if snapshot.is_empty() or not SessionSnapshot.validate(snapshot) or packets.is_empty():
					snapshot_rejections += 1
				else:
					packet_count_peak = maxi(packet_count_peak, packets.size())
					for packet: Dictionary in packets:
						var byte_count := var_to_bytes(packet).size()
						packet_bytes_total += byte_count
						packet_bytes_peak = maxi(packet_bytes_peak, byte_count)
						packet_count += 1
					session.acknowledge_snapshot()
		Workload.merge_monitor_peaks(monitor_peaks, Workload.monitor_snapshot())
	var memory_end := Workload.monitor_snapshot()
	observation.command_sha256 = command_hash.finish().hex_encode()
	var final_hash := world.state_hash()
	var conservation: Variant = world.hex_court.conservation_valid() if use_hex else null
	var final_inventory: Dictionary = Workload.inventory(world)
	var authority_metrics: Dictionary = world.hex_court.metrics.duplicate(true) if use_hex else {}
	var actor_outcomes: Array[Dictionary] = []
	for actor: PlayerState in world.players:
		actor_outcomes.append({"entity_id": actor.entity_id, "health": actor.health, "flux": actor.flux, "position": [actor.position_x, actor.position_y], "alive": actor.health > 0})
	_check(measured_ticks == Workload.SAMPLE_TICKS, "%s never shortens the measured sample" % variant)
	_check(observation.command_ticks == Workload.SAMPLE_TICKS * Workload.EMITTER_COUNT, "%s offers every fixture command without early drop" % variant)
	_check(observation.cast_started > 0, "%s produces actual paid starts" % variant)
	for family: String in ["bolt", "heavy", "rapid", "spray"]:
		_check(int(observation.started_by_family.get(family, 0)) > 0, "%s starts %s" % [variant, family])
	for element: String in ["water", "fire"]:
		_check(int(observation.started_by_element.get(element, 0)) > 0, "%s starts %s" % [variant, element])
	if use_hex:
		_check(bool(conservation), "hex finite matter remains conserved")
		_check(peaks.hex_products > 0 and diagnostic_samples == Workload.SAMPLE_TICKS / SNAPSHOT_INTERVAL_TICKS, "hex reaches products and emits every diagnostic state sample")
	else:
		_check(event_queue_evictions == 0 and unencodable_events == 0, "ordinary production event retention has no eviction or dropped event")
		_check(snapshot_rejections == 0 and snapshot_samples == Workload.SAMPLE_TICKS / SNAPSHOT_INTERVAL_TICKS, "ordinary local snapshots build and encode every scheduled sample without rejection")
	var invariant := {
		"final_hash": final_hash,
		"observation": observation,
		"peaks": peaks,
		"final_inventory": final_inventory,
		"authority_metrics": authority_metrics,
		"actors": actor_outcomes,
		"conservation": conservation,
		"event_queue_accepted": event_queue_accepted,
		"event_queue_evictions": event_queue_evictions,
		"unencodable_events": unencodable_events,
		"snapshot_rejections": snapshot_rejections,
		"snapshot_raw_bytes_total": snapshot_raw_bytes_total,
		"packet_bytes_total": packet_bytes_total,
		"packet_count": packet_count,
		"packet_count_peak": packet_count_peak,
		"snapshot_samples": snapshot_samples,
		"diagnostic_bytes_total": diagnostic_bytes_total,
		"diagnostic_samples": diagnostic_samples,
	}
	return {
		"variant": variant, "repetition": repetition,
		"warmup_ticks_excluded": Workload.WARMUP_TICKS, "sample_ticks": measured_ticks,
		"sim_step_us": Workload.percentiles(sim_us), "sim_over_8333us_count": deadline_misses,
		"event_retention_us": Workload.percentiles(retention_us),
		"snapshot_build_us": Workload.percentiles(snapshot_build_us),
		"snapshot_encode_us": Workload.percentiles(snapshot_encode_us),
		"hex_canonical_diagnostic_build_us": Workload.percentiles(diagnostic_build_us),
		"observation": observation, "peaks": peaks, "final_inventory": final_inventory, "authority_metrics": authority_metrics, "actors": actor_outcomes,
		"ordinary_network_instrumentation": {
			"applicable": not use_hex, "event_queue_accepted": event_queue_accepted,
			"event_queue_evictions": event_queue_evictions, "unencodable_events": unencodable_events,
			"pending_event_peak": pending_event_peak, "snapshot_rejections": snapshot_rejections,
			"snapshot_raw_bytes_total": snapshot_raw_bytes_total, "snapshot_raw_bytes_peak": snapshot_raw_bytes_peak,
			"encoded_packet_bytes_total": packet_bytes_total, "encoded_packet_bytes_peak": packet_bytes_peak,
			"encoded_packet_count": packet_count, "packets_per_snapshot_peak": packet_count_peak,
			"snapshot_samples": snapshot_samples,
		},
		"hex_state_diagnostic": {
			"applicable": use_hex, "network_supported": false, "samples": diagnostic_samples,
			"canonical_bytes_total": diagnostic_bytes_total, "canonical_bytes_peak": diagnostic_bytes_peak,
			"label": "exact HexCourt canonical state bytes; diagnostic only; absent from SessionSnapshot",
		},
		"memory_start": memory_start, "memory_end": memory_end, "monitor_peaks": monitor_peaks,
		"conservation_outside_timing": conservation, "final_state_hash_outside_timing": final_hash,
		"invariant_outcome": invariant,
	}


func _local_session(world: SimWorld) -> AuthoritativeSession:
	var session := AuthoritativeSession.new()
	if not session.bind(world, champions, Vector2i(640, 710), "Dense Fixture Host", [], "sparring_circle"):
		return null
	for actor: PlayerState in world.players:
		session.names_by_entity[actor.entity_id] = "Fixture %d" % actor.entity_id
		session.hearth.connect_entity(actor.entity_id)
	return session


func _source_hashes() -> Dictionary:
	var result := {}
	for path: String in [
		"res://tests/performance/dense_profile_workload.gd",
		"res://tests/performance/profile_dense_headless.gd",
		"res://src/sim/core/sim_world.gd", "res://src/sim/combat/combat_system.gd",
		"res://src/sim/hex/hex_grid.gd", "res://src/sim/hex/hex_footprint.gd",
		"res://src/sim/hex/hex_court.gd", "res://src/sim/hex/hex_court_practice.gd",
		"res://src/net/authoritative_session.gd",
		"res://src/net/session_snapshot.gd", "res://src/net/session_transport.gd",
		"res://content/abilities/foundation_abilities_v1.json",
		"res://content/champions/foundation_champions_v1.json", "res://project.godot",
	]:
		result[path.trim_prefix("res://")] = FileAccess.get_sha256(path)
	return result


func _finish(results: Array[Dictionary], order: Array[Dictionary] = []) -> void:
	var receipt := {
		"schema_version": 1, "workload_version": "dense-paid-four-emitter-v1",
		"runtime_identity": JSON.parse_string(FileAccess.get_file_as_string(RuntimeBuildIdentity.MANIFEST_PATH)),
		"engine": Engine.get_version_info()["string"],
		"hardware": {"cpu": OS.get_processor_name(), "logical_processors": OS.get_processor_count(), "os": OS.get_name()},
		"settings": {"seed": Workload.SEED, "tick_rate": Workload.TICK_RATE, "map_world_units": [Workload.MAP_WIDTH, Workload.MAP_HEIGHT], "obstacles": 0, "emitters": Workload.EMITTER_COUNT, "warmup_ticks_excluded": Workload.WARMUP_TICKS, "sample_ticks_per_run": Workload.SAMPLE_TICKS, "repetitions": Workload.REPETITIONS, "alternating_variant_order": true, "ordinary_snapshot_interval_ticks": SNAPSHOT_INTERVAL_TICKS},
		"execution_order": order, "source_hashes": _source_hashes(), "results": results,
		"assertions": assertions, "failures": failures,
		"scope": "One local headless process: matched SimWorld.step for ordinary and solo HexCourt variants. Ordinary additionally measures local production event retention and snapshot build/encode. No sockets, lobby, remote client, rendering, input device, physical multiplayer, installer or capacity claim.",
		"hex_snapshot_boundary": "HexCourt is not represented by SessionSnapshot. Reported HexCourt bytes are exact canonical state-hash bytes labeled diagnostic, never network bytes.",
		"fixture": "Four unnetworked opposing production champion states use the real eight-slot Water/Fire Bolt, Heavy, Rapid and Spray kit on one empty 1280x960 court. Every command follows ordinary Flux, cooldown, startup, health and capacity rules.",
		"mutation_policy": "No resource refill, maximum increase, cooldown clearing, direct projectile/field/product insertion, event eviction, retained-state eviction or early sample termination.",
		"timing_semantics": "SimWorld.step is timed separately. Event retention, snapshot build, snapshot encode and diagnostic serialization each have separate samples. Hashes, conservation, inventory, byte counting, checks and JSON are outside sim timing. Warmup is excluded.",
	}
	if output_path.is_empty():
		failures += 1
	else:
		var file := FileAccess.open(output_path, FileAccess.WRITE)
		_check(file != null, "headless receipt opens")
		if file != null:
			receipt.assertions = assertions
			receipt.failures = failures
			file.store_string(JSON.stringify(receipt, "  "))
			file.close()
	print("%s: dense-headless-profile; %d assertions; %d failures" % ["PASS" if failures == 0 else "FAIL", assertions, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		print("FAIL: ", message)
