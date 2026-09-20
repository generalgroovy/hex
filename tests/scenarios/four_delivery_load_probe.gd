extends "res://tests/scenarios/runtime_stress_probe.gd"
@warning_ignore_start("integer_division")

# Current legal commands only. No cap, health, Flux or cooldown overrides.
# The inherited historical workload and instrumented mirrors are never run.
const FAMILIES: Array[String] = ["bolt", "heavy", "spray", "rapid"]
const ELEMENT_IDS: Array[String] = ["water", "earth", "fire", "wind", "ice", "charge", "light", "dark"]
const CASES: Array[String] = ["campus-normal", "open-pressure", "corridor-pressure", "cluster-pressure"]
var load_ticks: int = 720
var load_output: String = ""


func _run() -> void:
	var selected := "all"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			load_output = argument.trim_prefix("--output=")
		elif argument.begins_with("--ticks="):
			load_ticks = int(argument.trim_prefix("--ticks="))
		elif argument.begins_with("--case="):
			selected = argument.trim_prefix("--case=")
	_check(load_ticks in [720, 7200], "bounded six-second diagnostic or sixty-second simulated soak")
	_check(selected == "all" or selected in CASES, "known workload selected")
	_check(load_output.begins_with("res://.godot/four-delivery-load-") and not ".." in load_output and not FileAccess.file_exists(load_output), "fresh scoped receipt destination")
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "current ability catalogue loads")
	_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "current champion catalogue loads")
	if failures > 0:
		quit(1)
		return
	var identity: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RuntimeBuildIdentity.MANIFEST_PATH))
	var results: Array[Dictionary] = []
	for case_name: String in CASES:
		if selected != "all" and case_name != selected:
			continue
		var reference: Dictionary = {}
		for repetition: int in range(2):
			var result := _measure_current(case_name, repetition == 1)
			result["repeat"] = repetition + 1
			if repetition == 0:
				reference = result
			else:
				for key: String in ["trace_sha256", "final_hash", "cleanup_ticks", "paid_by_wire", "released_by_wire", "event_counts", "refusals", "pressed_inputs", "held_input_ticks", "event_queue_accepted", "unencodable_emitted_events", "event_queue_evictions"]:
					_check(result[key] == reference[key], case_name + " reversed input order preserves " + key)
			results.append(result)
			print("LOAD_RESULT ", JSON.stringify(result))
	var receipt := FileAccess.open(load_output, FileAccess.WRITE)
	_check(receipt != null, "load evidence file opens")
	if receipt != null:
		receipt.store_string(JSON.stringify({"schema_version": 1, "workload_version": "four-delivery-load-v1", "runtime_identity": identity,
			"engine": Engine.get_version_info()["string"], "cpu": OS.get_processor_name(), "logical_processors": OS.get_processor_count(),
			"seed": SEED, "tick_rate": 120, "warmup_ticks": WARMUP_TICKS, "sample_ticks": load_ticks,
			"source_hashes": _source_hashes(), "results": results, "assertions": assertions, "failures": failures,
			"scope": "Headless SimWorld.step plus production event retention and snapshot encoding; no sockets, rendering or physical input. Quantiles include all measured ticks, including refused/exhausted periods.",
			"not_measured": ["rendered_frame_time", "input_to_visible_latency", "allocation_rate", "process_working_set", "socket_backpressure", "candidate_pair_counts", "exact_contact_tests", "spatial_index_overhead"],
			"capacity_acceptance": "NOT_ESTABLISHED; B1 has no direct attack interception and no enlarged footprints or doubled lifetimes"
		}, "  "))
		receipt.close()
	print("%s: four-delivery-load; %d assertions; %d failures" % ["PASS" if failures == 0 else "FAIL", assertions, failures])
	quit(0 if failures == 0 else 1)


func _current_world(case_name: String) -> SimWorld:
	var collision := CollisionWorld.new(6_000_000, 4_000_000)
	var layout = CampusLayout.new()
	var map_hash := "synthetic-load-v1:" + case_name
	if case_name == "campus-normal":
		_check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "real campus loads")
		collision = layout.build_collision_world()
		map_hash = layout.content_hash
	elif case_name == "corridor-pressure":
		collision.add_obstacle(CollisionWorld.Obstacle.new(1, 500000, 500000, 5400000, 650000))
		collision.add_obstacle(CollisionWorld.Obstacle.new(2, 500000, 1200000, 5400000, 1350000))
	var world := SimWorld.new(120, SEED, collision, case_name, map_hash)
	world.players.clear()
	var champion_ids := champions.ordered_champion_ids()
	for index: int in range(8):
		var actor := PlayerState.new(index + 1)
		_check(champions.apply_to_player(actor, champion_ids[index]), "use real champion stats")
		actor.team_id = index + 1
		actor.position_x = 1000000 + index * 500000
		actor.position_y = 2000000
		if case_name == "campus-normal":
			var position: Array = layout.arena_definition["spawns"][index]
			actor.position_x = int(position[0]) * 1000
			actor.position_y = int(position[1]) * 1000
		elif case_name == "corridor-pressure":
			actor.position_y = 1000000
		elif case_name == "cluster-pressure":
			actor.position_x = 2000000 + (index % 4) * 90000
			@warning_ignore("integer_division")
			actor.position_y = 2000000 + (index / 4) * 90000
		for slot: int in range(4):
			var definition := abilities.ability(abilities.spell_id_at(ELEMENT_IDS[index], FAMILIES[slot]))
			_check(not definition.is_empty() and CombatTuning.is_runtime_wire_id(int(definition.get("wire_id", 0))), "retained family/element is live")
			_check(actor.place_proven_spell(slot, int(definition.get("wire_id", 0))), "equip validated live spell")
		world.players.append(actor)
	return world


func _current_commands(world: SimWorld, case_name: String, active: bool, reverse_order: bool) -> Array[SimCommand]:
	var commands: Array[SimCommand] = []
	var phase := posmod(world.tick - WARMUP_TICKS, 480 if case_name == "campus-normal" else 240)
	var heavy_phase := 90 if case_name == "campus-normal" else 30
	var spray_phase := 210 if case_name == "campus-normal" else 90
	var rapid_begin := 300 if case_name == "campus-normal" else 132
	var rapid_end := 420 if case_name == "campus-normal" else 228
	for actor: PlayerState in world.players:
		var pressed := 0
		if active:
			pressed = SimCommand.SPELL_PRESSED_BITS[0] if phase == 0 else (SimCommand.SPELL_PRESSED_BITS[1] if phase == heavy_phase else (SimCommand.SPELL_PRESSED_BITS[2] if phase == spray_phase else 0))
		var held := SimCommand.SPELL_HELD_BITS[3] if active and phase >= rapid_begin and phase < rapid_end else 0
		var moving := 1000 if world.tick % 60 < 30 else -1000
		if case_name != "campus-normal":
			moving = 0
		var target_x := actor.position_x
		var target_y := maxi(0, actor.position_y - 500000)
		if case_name == "campus-normal":
			# Aim into the actual court, not through its outer buildings. Short
			# lateral excursions retain the authored arena spawn clearance.
			target_x = 2544000
			target_y = 1212000
		elif case_name == "cluster-pressure":
			target_x = 2135000
			target_y = 1650000
		commands.append(SimCommand.new(world.tick, actor.entity_id, moving, 0, held, pressed, target_x - actor.position_x, target_y - actor.position_y, target_x, target_y))
	if reverse_order:
		commands.reverse()
	return commands


func _count_key(counts: Dictionary, key: String, amount: int = 1) -> void:
	counts[key] = int(counts.get(key, 0)) + amount


func _measure_current(case_name: String, reverse_order: bool) -> Dictionary:
	var world := _current_world(case_name)
	_check(world.is_valid(), "current workload world valid")
	var session := AuthoritativeSession.new()
	_check(session.bind(world, champions, Vector2i(1000, 2000), "Load Host"), "bind production event queue")
	for actor: PlayerState in world.players:
		session.names_by_entity[actor.entity_id] = "Load %d" % actor.entity_id
		_check(session.hearth.connect_entity(actor.entity_id), "snapshot hearth includes every fixture actor")
	for index: int in range(WARMUP_TICKS):
		_check(world.step(_current_commands(world, case_name, false, reverse_order)), "warmup step")
	var tick_times := PackedInt64Array()
	var snapshot_times := PackedInt64Array()
	var host_times := PackedInt64Array()
	tick_times.resize(load_ticks)
	snapshot_times.resize(load_ticks / 2)
	host_times.resize(load_ticks)
	var trace := HashingContext.new()
	trace.start(HashingContext.HASH_SHA256)
	var paid := {}
	var released := {}
	var negated_pulses := {}
	var pressed_inputs := {}
	var held_inputs := {}
	var event_counts := {}
	var refusals := {}
	var peaks := {"projectiles": 0, "deposits": 0, "reactions": 0, "events": 0, "pending_events": 0, "snapshot_raw_bytes": 0, "packets_per_peer": 0, "datagram_bytes": 0, "queued_event_overflow": 0}
	var inventory_totals := {"projectile_instance_ticks": 0, "deposit_instance_ticks": 0, "reaction_instance_ticks": 0, "alive_actor_instance_ticks": 0}
	var deadline_misses := 0
	var host_deadline_misses := 0
	var event_queue_accepted := 0
	var unencodable_events := 0
	var event_queue_evictions := 0
	var snapshot_rejections := 0
	var overflow_samples := 0
	var sent_bytes_per_peer := 0
	var sent_packets_per_peer := 0
	var buckets: Array[Dictionary] = []
	var bucket_paid := 0
	var bucket_released := 0
	var static_memory_start := OS.get_static_memory_usage()
	var static_peak_start := OS.get_static_memory_peak_usage()
	for index: int in range(load_ticks):
		var commands := _current_commands(world, case_name, true, reverse_order)
		for command: SimCommand in commands:
			var slot := command.first_pressed_spell_slot()
			if slot > 0:
				_count_key(pressed_inputs, str(world.player(command.entity_id).spell_wire_id(slot)))
			slot = command.first_held_spell_slot()
			if slot > 0:
				_count_key(held_inputs, str(world.player(command.entity_id).spell_wire_id(slot)))
		var host_started := Time.get_ticks_usec()
		var step_started := host_started
		var stepped := world.step(commands)
		tick_times[index] = Time.get_ticks_usec() - step_started
		var prior_overflow := session.pending_combat_event_overflow_count
		var accepted_events := session.record_combat_events(world.combat_events)
		event_queue_accepted += accepted_events
		unencodable_events += world.combat_events.size() - accepted_events
		event_queue_evictions += maxi(0, session.pending_combat_event_overflow_count - prior_overflow)
		peaks.pending_events = maxi(peaks.pending_events, session.pending_combat_events.size())
		peaks.queued_event_overflow = maxi(peaks.queued_event_overflow, session.pending_combat_event_overflow_count)
		if index % 2 == 0:
			var capture_started := Time.get_ticks_usec()
			var snapshot := session.capture_snapshot()
			var packets := SessionTransport._snapshot_wire_packets(snapshot)
			snapshot_times[index / 2] = Time.get_ticks_usec() - capture_started
			host_times[index] = Time.get_ticks_usec() - host_started
			_check(not snapshot.is_empty() and SessionSnapshot.validate(snapshot), "every captured current snapshot validates")
			if not snapshot.is_empty():
				for count: int in snapshot["overflow"]:
					overflow_samples += int(count > 0)
				peaks.snapshot_raw_bytes = maxi(peaks.snapshot_raw_bytes, var_to_bytes(snapshot).size())
			if packets.is_empty():
				# One failed publication attempt, including an empty capture;
				# do not double-count the same failure at both layers.
				snapshot_rejections += 1
			else:
				peaks.packets_per_peer = maxi(peaks.packets_per_peer, packets.size())
				for packet: Dictionary in packets:
					var bytes := var_to_bytes(packet).size()
					_check(bytes <= SessionTransport.ENET_MTU_BYTES, "encoded packet remains within validated MTU")
					peaks.datagram_bytes = maxi(peaks.datagram_bytes, bytes)
					sent_bytes_per_peer += bytes
					sent_packets_per_peer += 1
				# Local delivery-success model only, not a remote acknowledgement.
				session.acknowledge_snapshot()
		else:
			host_times[index] = Time.get_ticks_usec() - host_started
		_check(stepped, "measured production step")
		deadline_misses += int(tick_times[index] > TICK_BUDGET_US)
		host_deadline_misses += int(host_times[index] > TICK_BUDGET_US)
		trace.update(_trace_bytes(world))
		peaks.projectiles = maxi(peaks.projectiles, world.projectiles.size())
		peaks.deposits = maxi(peaks.deposits, world.deposits.size())
		peaks.reactions = maxi(peaks.reactions, world.reactions.size())
		peaks.events = maxi(peaks.events, world.combat_events.size())
		inventory_totals.projectile_instance_ticks += world.projectiles.size()
		inventory_totals.deposit_instance_ticks += world.deposits.size()
		inventory_totals.reaction_instance_ticks += world.reactions.size()
		var alive := 0
		var minimum_flux := 2147483647
		for actor: PlayerState in world.players:
			alive += int(actor.health > 0)
			minimum_flux = mini(minimum_flux, actor.flux)
		inventory_totals.alive_actor_instance_ticks += alive
		for event: Dictionary in world.combat_events:
			var kind := String(event.get("type", ""))
			var wire := str(int(event.get("wire_id", event.get("source_wire_id", 0))))
			_count_key(event_counts, kind)
			if kind == "cast_started":
				_count_key(paid, wire)
				bucket_paid += 1
			elif kind in ["projectile_spawned", "spray_fired"]:
				_count_key(released, wire)
				bucket_released += 1
			elif kind == "spray_intercepted" and int(event.get("outcome", 0)) == 2:
				_count_key(negated_pulses, wire)
			elif kind == "cast_refused":
				_count_key(refusals, wire + ":" + String(event.get("reason", "unknown")))
		if index % 120 == 119:
			buckets.append({"through_tick": index + 1, "paid_starts": bucket_paid, "releases": bucket_released, "alive": alive, "minimum_flux": minimum_flux, "projectiles": world.projectiles.size(), "deposits": world.deposits.size(), "reactions": world.reactions.size(), "pending_events": session.pending_combat_events.size(), "static_memory_bytes": OS.get_static_memory_usage()})
			bucket_paid = 0
			bucket_released = 0
	var static_memory_end := OS.get_static_memory_usage()
	var cleanup := 0
	while cleanup < CLEANUP_LIMIT and (not world.projectiles.is_empty() or not world.deposits.is_empty() or not world.reactions.is_empty() or _has_pending_cast(world) or not session.pending_combat_events.is_empty()):
		_check(world.step(_current_commands(world, case_name, false, reverse_order)), "natural cleanup step")
		trace.update(_trace_bytes(world))
		session.record_combat_events(world.combat_events)
		if cleanup % 2 == 0:
			var snapshot := session.capture_snapshot()
			if not SessionTransport._snapshot_wire_packets(snapshot).is_empty():
				session.acknowledge_snapshot()
		cleanup += 1
	_check(cleanup < CLEANUP_LIMIT, "effects and event redundancy drain naturally")
	# Coverage is reported, never fabricated by seeding projectiles or refilling Flux.
	_check(paid.size() == 32, "all32 legal family/element cells actually pay")
	for element: String in ELEMENT_IDS:
		for family: String in FAMILIES:
			var definition := abilities.ability(abilities.spell_id_at(element, family))
			var wire := str(int(definition["wire_id"]))
			_check(paid.has(wire) and (released.has(wire) or negated_pulses.has(wire)), "actual paid release or direct negation coverage: " + element + "/" + family)
	_check(peaks.projectiles > 0 and peaks.deposits > 0, "legal attacks and ingredients actually enter the workload")
	return {"case": case_name, "map_sha256": world.map_hash, "tick_us": _percentiles(tick_times), "host_step_queue_plus_every_other_capture_pack_us": _percentiles(host_times), "snapshot_capture_pack_us": _percentiles(snapshot_times),
		"deadline_misses": deadline_misses, "host_deadline_misses": host_deadline_misses, "sample_ticks": load_ticks, "peaks": peaks, "inventory_samples": inventory_totals, "paid_by_wire": paid, "released_by_wire": released,
		"negated_pulses_by_wire": negated_pulses, "event_queue_accepted": event_queue_accepted, "unencodable_emitted_events": unencodable_events, "event_queue_evictions": event_queue_evictions,
		"pressed_inputs": pressed_inputs, "held_input_ticks": held_inputs, "refusals": refusals, "event_counts": event_counts, "snapshot_rejections": snapshot_rejections,
		"overflow_component_samples": overflow_samples, "encoded_bytes_per_peer": sent_bytes_per_peer, "encoded_packets_per_peer": sent_packets_per_peer,
		"static_memory_bytes": {"start": static_memory_start, "end": static_memory_end, "after_cleanup": OS.get_static_memory_usage(), "process_peak_before": static_peak_start, "process_peak_after": OS.get_static_memory_peak_usage()},
		"buckets_120_ticks": buckets, "trace_sha256": trace.finish().hex_encode(), "final_hash": world.state_hash(), "cleanup_ticks": cleanup,
		"input_count_semantics": "pressed spell intents and held Rapid input-ticks are separate; a held tick is not a paid cast. Silent held cooldown/gate/capacity/Flux nonadmission is visible as fewer paid starts, not counted as explicit refusals.",
		"processing_semantics": "event_counts are actual emitted outcomes observed once; entity counts are post-step inventory samples, not exact narrowphase or update-call counters",
		"memory_scope": "Godot process static-memory samples include bounded harness arrays/dictionaries and retained earlier result reports; not allocation rate or OS working set",
		"delivery_model": "production event queue, capture and encoding every other tick; successful local encoding acknowledges retention, no sockets/loss/backpressure injection"}
