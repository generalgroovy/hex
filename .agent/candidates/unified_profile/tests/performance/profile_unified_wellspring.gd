extends SceneTree
@warning_ignore_start("integer_division")

# Bounded headless diagnostic for the normal unified Wellspring authority.
# This owns no acceptance threshold: it records real paid-command work, the
# production event queue, and the production combined snapshot wire path.
const SEED := 906_190
const TICK_RATE := 120
const WARMUP_TICKS := 120
const CLEANUP_LIMIT := 2_400
const TICK_BUDGET_US := 8_333
const SNAPSHOT_PERIOD_TICKS := 2
const CASES: Array[String] = ["sustained-distributed", "dense-crucible"]
const ELEMENTS: Array[String] = ["earth", "fire", "water", "wind"]
const FAMILIES: Array[String] = ["bolt", "heavy", "spray", "rapid"]
const CRUCIBLE_REFERENCE := Vector2i(1_504_000, 1_344_000)

var failures := 0
var assertions := 0
var sample_ticks := 720
var output_path := ""
var abilities := AbilityCatalog.new()
var champions := ChampionCatalog.new()
var layout := SanctumCampusLayout.new()
var definition: HexWorldDefinition


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ticks="):
			sample_ticks = int(argument.trim_prefix("--ticks="))
		elif argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	_check(sample_ticks in [720, 7200], "profile is the bounded six-second diagnostic or sixty-second simulated soak")
	_check(output_path.begins_with("res://.godot/unified-wellspring-profile-") and output_path.ends_with(".json") and not ".." in output_path and not FileAccess.file_exists(output_path), "receipt path is fresh and scoped")
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "production ability catalogue loads")
	_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "production champion catalogue loads")
	_check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "normal Wellspring campus loads")
	definition = HexWorldDefinition.from_campus(layout)
	_check(definition != null, "normal campus produces one trusted whole-hex definition")
	if failures > 0:
		quit(1)
		return

	var runs: Array[Dictionary] = []
	for case_name: String in CASES:
		var reference: Dictionary = {}
		for repetition: int in range(2):
			var result := _measure(case_name, repetition == 1)
			result.repeat = repetition + 1
			result.reverse_command_order = repetition == 1
			if repetition == 0:
				reference = _deterministic_result(result)
			else:
				_check(_deterministic_result(result) == reference, case_name + " reverse command order preserves all deterministic counters and hashes")
			runs.append(result)
			print("UNIFIED_WELLSPRING_PROFILE_RESULT ", JSON.stringify(result))

	var identity_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(RuntimeBuildIdentity.MANIFEST_PATH))
	var receipt := {
		"schema_version": 1,
		"workload_version": "unified-wellspring-profile-v1",
		"runtime_identity": identity_value if identity_value is Dictionary else {},
		"engine": Engine.get_version_info()["string"],
		"seed": SEED,
		"tick_rate": TICK_RATE,
		"warmup_ticks": WARMUP_TICKS,
		"sample_ticks": sample_ticks,
		"cases": CASES,
		"repetitions_per_case": 2,
		"source_sha256": _source_hashes(),
		"runs": runs,
		"assertions": assertions,
		"failures": failures,
		"scope": "Headless normal-campus SimWorld.step, authoritative event retention, and 60 Hz combined envelope capture plus production wire packing. No sockets, rendering, physical input, state injection, resource refill, cooldown bypass, or capacity override.",
		"performance_acceptance": "NOT_ESTABLISHED; diagnostic measurements depend on this machine and headless execution and do not establish rendered, networked, or release capacity.",
	}
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	_check(output != null, "profile receipt opens")
	if output != null:
		output.store_string(JSON.stringify(receipt, "\t") + "\n")
		output.close()
	print("%s: unified-wellspring-profile; %d assertions; %d failures; output=%s" % ["PASS" if failures == 0 else "FAIL", assertions, failures, output_path])
	quit(1 if failures > 0 else 0)


func _measure(case_name: String, reverse_order: bool) -> Dictionary:
	var fixture := _fixture(case_name)
	var world: SimWorld = fixture.world
	var targets: Dictionary = fixture.targets
	var session := AuthoritativeSession.new()
	var host: PlayerState = world.player(1)
	var spawn_pixels := Vector2i(host.position_x / SimConfig.FIXED_SCALE, host.position_y / SimConfig.FIXED_SCALE)
	_check(session.bind(world, champions, spawn_pixels, "Profile Host"), case_name + " binds the production authoritative session")
	for actor: PlayerState in world.players:
		actor.team_id = 1 # One real team keeps the intended workload alive without health injection.
		session.names_by_entity[actor.entity_id] = "Profile %d" % actor.entity_id
		_check(session.hearth.connect_entity(actor.entity_id), case_name + " snapshot Hearth includes champion %d" % actor.entity_id)
	for unused: int in range(WARMUP_TICKS):
		_check(world.step(_commands(world, targets, case_name, false, reverse_order)), case_name + " warmup advances")

	var step_times := PackedInt64Array()
	var host_times := PackedInt64Array()
	var snapshot_times := PackedInt64Array()
	step_times.resize(sample_ticks)
	host_times.resize(sample_ticks)
	snapshot_times.resize((sample_ticks + SNAPSHOT_PERIOD_TICKS - 1) / SNAPSHOT_PERIOD_TICKS)
	var trace := HashingContext.new()
	trace.start(HashingContext.HASH_SHA256)
	var requested_pressed := {}
	var requested_held_ticks := {}
	var admitted := {}
	var released := {}
	var refusals := {}
	var event_counts := {}
	var publication := {
		"capture_attempts": 0, "cleanup_capture_attempts": 0, "rejections": 0,
		"fragments": 0, "fragmented_envelopes": 0, "raw_bytes": 0,
		"wire_bytes": 0, "accepted_events": 0, "evicted_events": 0,
		"unencodable_events": 0, "mtu_violations": 0,
	}
	var peaks := {
		"projectiles": 0, "pending_casts": 0, "casts": 0, "products": 0,
		"active_cells": 0, "source_quantity": 0, "product_quantity": 0,
		"events_per_tick": 0, "retained_events": 0, "snapshot_raw_bytes": 0,
		"fragments_per_envelope": 0, "datagram_bytes": 0, "static_memory_bytes": OS.get_static_memory_usage(),
	}
	var inventory := {
		"projectile_instance_ticks": 0, "pending_cast_instance_ticks": 0,
		"cast_instance_ticks": 0, "product_instance_ticks": 0,
		"active_cell_instance_ticks": 0, "source_quantity_instance_ticks": 0,
		"product_quantity_instance_ticks": 0, "alive_actor_instance_ticks": 0,
		"ticks_with_authority_work": 0,
	}
	var deadlines := {"step": 0, "host": 0}
	var static_start := OS.get_static_memory_usage()
	var process_peak_start := OS.get_static_memory_peak_usage()
	var clashes := 0
	var deaths := 0
	var previous_alive := world.players.size()
	var sample_end_hash := ""

	for index: int in range(sample_ticks):
		var commands := _commands(world, targets, case_name, true, reverse_order)
		_count_requested(world, commands, requested_pressed, requested_held_ticks)
		var host_started := Time.get_ticks_usec()
		var step_started := host_started
		var stepped := world.step(commands)
		step_times[index] = Time.get_ticks_usec() - step_started
		_check(stepped, case_name + " measured SimWorld step succeeds")
		var queue_delta := _record_events(session, world.combat_events, event_counts, admitted, released, refusals)
		publication.accepted_events += int(queue_delta.accepted)
		publication.unencodable_events += int(queue_delta.unencodable)
		publication.evicted_events += int(queue_delta.evicted)
		clashes += int(queue_delta.clashes)
		if index % SNAPSHOT_PERIOD_TICKS == 0:
			var capture_started := Time.get_ticks_usec()
			_capture_publication(session, publication, peaks, false)
			snapshot_times[index / SNAPSHOT_PERIOD_TICKS] = Time.get_ticks_usec() - capture_started
		host_times[index] = Time.get_ticks_usec() - host_started
		deadlines.step += int(step_times[index] > TICK_BUDGET_US)
		deadlines.host += int(host_times[index] > TICK_BUDGET_US)
		trace.update(_trace_bytes(world))
		var occupancy := _occupancy(world.hex_court, world.tick)
		var alive := _alive_count(world)
		deaths += maxi(0, previous_alive - alive)
		previous_alive = alive
		_accumulate_inventory(world, occupancy, alive, inventory, peaks)
		peaks.events_per_tick = maxi(int(peaks.events_per_tick), world.combat_events.size())
		peaks.retained_events = maxi(int(peaks.retained_events), session.pending_combat_events.size())
		peaks.static_memory_bytes = maxi(int(peaks.static_memory_bytes), OS.get_static_memory_usage())
	if sample_ticks > 0:
		sample_end_hash = world.state_hash()
	var static_end := OS.get_static_memory_usage()
	var cleanup_ticks := 0
	while cleanup_ticks < CLEANUP_LIMIT and _cleanup_pending(world, session):
		_check(world.step(_commands(world, targets, case_name, false, reverse_order)), case_name + " cleanup advances authored expiry")
		var queue_delta := _record_events(session, world.combat_events, event_counts, admitted, released, refusals)
		publication.accepted_events += int(queue_delta.accepted)
		publication.unencodable_events += int(queue_delta.unencodable)
		publication.evicted_events += int(queue_delta.evicted)
		clashes += int(queue_delta.clashes)
		if cleanup_ticks % SNAPSHOT_PERIOD_TICKS == 0:
			_capture_publication(session, publication, peaks, true)
		trace.update(_trace_bytes(world))
		cleanup_ticks += 1

	var metrics: Dictionary = world.hex_court.metrics.duplicate(true)
	var final_occupancy := _occupancy(world.hex_court, world.tick)
	var simulated_seconds := float(sample_ticks) / float(TICK_RATE)
	var alive_expected := sample_ticks * world.players.size()
	deaths = world.players.size() - _alive_count(world)
	_check(cleanup_ticks < CLEANUP_LIMIT, case_name + " pending casts, finite chemistry, and event redundancy drain within the bound")
	_check(not _cleanup_pending(world, session), case_name + " cleanup leaves no hidden live authority or retained events")
	_check(world.hex_court.conservation_valid(), case_name + " paid matter remains conserved")
	_check(requested_pressed.size() == 12 and requested_held_ticks.size() == 4, case_name + " authored timeline requests all first-four Bolt, Heavy, Spray, and Rapid wires")
	_check(int(metrics.admitted) > 0 and int(metrics.matter_paid) == int(metrics.admitted) * HexChemistryWorld.MATTER_PER_CAST, case_name + " workload contains positive real paid admissions")
	_check(not released.is_empty(), case_name + " admitted casts produce real authored releases")
	_check(int(inventory.alive_actor_instance_ticks) == alive_expected and deaths == 0, case_name + " all eight actual champions remain alive without health refill")
	_check(int(publication.mtu_violations) == 0 and int(publication.rejections) == 0, case_name + " every combined envelope validates and packs within production bounds")
	if case_name == "dense-crucible":
		_check(clashes > 0 and int(metrics.reactions) > 0, "dense Crucible actually processes clashes and products")
	else:
		_check(int(peaks.active_cells) > 0, "distributed workload creates live whole-hex occupancy")

	return {
		"case": case_name,
		"sample_ticks": sample_ticks,
		"step_us": _percentiles(step_times),
		"host_step_event_retention_and_60hz_envelope_us": _percentiles(host_times),
		"envelope_capture_and_wire_pack_us": _percentiles(snapshot_times),
		"deadline_misses_over_8333us": deadlines,
		"requested_pressed_by_wire": requested_pressed,
		"requested_held_ticks_by_wire": requested_held_ticks,
		"admitted_by_wire": admitted,
		"refusals_by_wire_and_reason": refusals,
		"released_by_wire": released,
		"processed_clashes": clashes,
		"processed_products": int(metrics.reactions),
		"workload_totals": {
			"requested_pressed": _sum_counts(requested_pressed),
			"requested_held_ticks": _sum_counts(requested_held_ticks),
			"admitted": int(metrics.admitted),
			"refusals": int(metrics.refused),
			"releases": _sum_counts(released),
			"processed_clashes": clashes,
			"processed_products": int(metrics.reactions),
			"active_cell_instance_ticks": int(inventory.active_cell_instance_ticks),
			"source_quantity_instance_ticks": int(inventory.source_quantity_instance_ticks),
			"contact_queries": int(metrics.exposure_queries),
		},
		"event_counts": event_counts,
		"authority_metrics": metrics,
		"publication": publication,
		"peaks": peaks,
		"inventory_totals": inventory,
		"alive_work": {
			"deaths": deaths,
			"alive_end": _alive_count(world),
			"alive_actor_instance_ticks": int(inventory.alive_actor_instance_ticks),
			"alive_actor_instance_ticks_per_simulated_second": float(inventory.alive_actor_instance_ticks) / simulated_seconds,
			"mean_alive_actors": float(inventory.alive_actor_instance_ticks) / float(sample_ticks),
			"ticks_with_authority_work": int(inventory.ticks_with_authority_work),
			"work_ticks_per_simulated_second": float(inventory.ticks_with_authority_work) / simulated_seconds,
		},
		"final_occupancy_after_cleanup": final_occupancy,
		"contact_queries": int(metrics.exposure_queries),
		"cleanup_ticks": cleanup_ticks,
		"sample_end_hash": sample_end_hash,
		"final_hash": world.state_hash(),
		"trace_sha256": trace.finish().hex_encode(),
		"static_memory_bytes": {
			"start": static_start, "sample_end": static_end,
			"after_cleanup": OS.get_static_memory_usage(), "sampled_peak": int(peaks.static_memory_bytes),
			"process_peak_before": process_peak_start, "process_peak_after": OS.get_static_memory_peak_usage(),
		},
		"input_semantics": "Pressed intents and held Rapid input-ticks are reported separately. Held cooldown, recovery, Flux, and capacity nonadmission may be silent and is exposed by the admitted count rather than fabricated as a refusal.",
		"contact_semantics": "contact_queries is the authoritative hex exposure-query counter; processed_clashes counts emitted real hex_clash outcomes. It is not an invented narrowphase-call estimate.",
		"measurement_scope": "Timing covers real SimWorld.step; host timing adds production event retention and every-other-tick envelope capture/packing. Cleanup is excluded from quantiles but included in terminal counters and hashes.",
	}


func _fixture(case_name: String) -> Dictionary:
	var world := SimWorld.new(TICK_RATE, SEED, layout.build_collision_world(), String(layout.data.id), layout.content_hash)
	_check(definition.bind_world(world), case_name + " binds HexWorldDefinition to the actual campus")
	world.players.clear()
	var geometry := _case_geometry(case_name)
	var positions: Array = geometry.positions
	var targets: Dictionary = geometry.targets
	var champion_ids := champions.ordered_champion_ids()
	_check(champion_ids.size() >= 8, "production catalogue supplies eight actual champions")
	for index: int in range(8):
		var actor := PlayerState.new(index + 1)
		_check(champions.apply_to_player(actor, champion_ids[index]), case_name + " applies actual champion %d" % (index + 1))
		actor.reset_for_spawn(positions[index])
		actor.spawn_protection_ticks = 0
		actor.team_id = 1
		var element := ELEMENTS[index % ELEMENTS.size()]
		for slot: int in range(FAMILIES.size()):
			var ability := abilities.ability(abilities.spell_id_at(element, FAMILIES[slot]))
			var wire := int(ability.get("wire_id", 0))
			_check(wire > 0 and actor.place_proven_spell(slot, wire), case_name + " equips legal %s %s" % [element, FAMILIES[slot]])
			_check(actor.spell_wire_id(slot + 1) == wire, case_name + " keeps %s in authored weave slot %d" % [FAMILIES[slot], slot + 1])
		_check(actor.has_valid_spell_slots(), case_name + " champion retains a valid twelve-position weave")
		_check(world.collision.can_occupy(positions[index], MovementTuning.PLAYER_RADIUS), case_name + " champion position is a clear trusted district cell")
		var aim_target: Vector2i = targets[index + 1]
		_check(world.collision.can_occupy(aim_target, 12_000), case_name + " authored aim target is a clear trusted district cell")
		world.players.append(actor)
	_check(world.is_valid() and world.hex_court != null and world.hex_court.conservation_valid(), case_name + " normal unified world starts valid")
	return {"world": world, "targets": targets}


func _case_geometry(case_name: String) -> Dictionary:
	var cells: Array[Vector2i] = definition.eligible_cells.duplicate()
	var positions: Array[Vector2i] = []
	var targets := {}
	if case_name == "dense-crucible":
		var center_cell := cells[0]
		var best_distance := 0x7fffffffffffffff
		for cell: Vector2i in cells:
			var distance := (definition.origin + HexGrid.center(cell) - CRUCIBLE_REFERENCE).length_squared()
			if distance < best_distance:
				best_distance = distance
				center_cell = cell
		var endpoint := definition.origin + HexGrid.center(center_cell)
		var ring: Array[Vector2i] = []
		for cell: Vector2i in cells:
			var distance := (definition.origin + HexGrid.center(cell) - endpoint).length_squared()
			if distance >= 96_000 * 96_000 and distance <= 360_000 * 360_000:
				ring.append(cell)
		if ring.size() < 8:
			for cell: Vector2i in cells:
				if cell != center_cell and cell not in ring:
					ring.append(cell)
		_check(ring.size() >= 8, "dense Crucible has eight trusted firing cells")
		for index: int in range(8):
			var cell := ring[index * ring.size() / 8]
			positions.append(definition.origin + HexGrid.center(cell))
			targets[index + 1] = endpoint
	else:
		_check(cells.size() >= 16, "distributed case has enough trusted district cells")
		for index: int in range(8):
			var position_index := index * cells.size() / 8
			var target_index := posmod(position_index + cells.size() / 2 + index, cells.size())
			positions.append(definition.origin + HexGrid.center(cells[position_index]))
			targets[index + 1] = definition.origin + HexGrid.center(cells[target_index])
	return {"positions": positions, "targets": targets}


func _commands(world: SimWorld, targets: Dictionary, case_name: String, active: bool, reverse_order: bool) -> Array[SimCommand]:
	var commands: Array[SimCommand] = []
	var sample_tick := world.tick - WARMUP_TICKS
	for actor: PlayerState in world.players:
		var offset := 0 if case_name == "dense-crucible" else (actor.entity_id - 1) * 60
		var phase := posmod(sample_tick + offset, 480)
		var pressed := 0
		var held := 0
		if active:
			if phase == 0:
				pressed = SimCommand.SPELL_PRESSED_BITS[0]
			elif phase == 120:
				pressed = SimCommand.SPELL_PRESSED_BITS[1]
			elif phase == 240:
				pressed = SimCommand.SPELL_PRESSED_BITS[2]
			elif phase >= 336 and phase < 396:
				held = SimCommand.SPELL_HELD_BITS[3]
		var target: Vector2i = targets[actor.entity_id]
		var aim := target - Vector2i(actor.position_x, actor.position_y)
		commands.append(SimCommand.new(world.tick, actor.entity_id, 0, 0, held, pressed, aim.x, aim.y, target.x, target.y))
	if reverse_order:
		commands.reverse()
	return commands


func _count_requested(world: SimWorld, commands: Array[SimCommand], pressed: Dictionary, held: Dictionary) -> void:
	for command: SimCommand in commands:
		var actor := world.player(command.entity_id)
		var slot := command.first_pressed_spell_slot()
		if slot > 0:
			_count_key(pressed, str(actor.spell_wire_id(slot)))
		slot = command.first_held_spell_slot()
		if slot > 0:
			_count_key(held, str(actor.spell_wire_id(slot)))


func _record_events(session: AuthoritativeSession, events: Array[Dictionary], counts: Dictionary, admitted: Dictionary, released: Dictionary, refusals: Dictionary) -> Dictionary:
	var prior_overflow := session.pending_combat_event_overflow_count
	var accepted := session.record_combat_events(events)
	var clashes := 0
	for event: Dictionary in events:
		var kind := String(event.get("type", "unknown"))
		var wire := str(int(event.get("wire_id", event.get("source_wire_id", 0))))
		_count_key(counts, kind)
		if kind == "cast_started":
			_count_key(admitted, wire)
		elif kind in ["projectile_spawned", "spray_fired"]:
			_count_key(released, wire)
		elif kind == "cast_refused":
			_count_key(refusals, wire + ":" + String(event.get("reason", "unknown")))
		elif kind == "hex_clash":
			clashes += 1
	return {
		"accepted": accepted,
		"unencodable": events.size() - accepted,
		"evicted": maxi(0, session.pending_combat_event_overflow_count - prior_overflow),
		"clashes": clashes,
	}


func _capture_publication(session: AuthoritativeSession, publication: Dictionary, peaks: Dictionary, cleanup: bool) -> void:
	publication.capture_attempts += 1
	publication.cleanup_capture_attempts += int(cleanup)
	var envelope := session.capture_envelope()
	var valid := not envelope.is_empty() and WorldSnapshotEnvelope.validate(envelope)
	var packets: Array[Dictionary] = SessionTransport._envelope_wire_packets(envelope) if valid else []
	if not valid or packets.is_empty():
		publication.rejections += 1
		return
	var raw_bytes := WorldSnapshotEnvelope.byte_size(envelope)
	publication.raw_bytes += raw_bytes
	publication.fragments += packets.size()
	publication.fragmented_envelopes += int(packets.size() > 1)
	peaks.snapshot_raw_bytes = maxi(int(peaks.snapshot_raw_bytes), raw_bytes)
	peaks.fragments_per_envelope = maxi(int(peaks.fragments_per_envelope), packets.size())
	for packet: Dictionary in packets:
		var wire_bytes := var_to_bytes(packet).size()
		publication.wire_bytes += wire_bytes
		publication.mtu_violations += int(wire_bytes > SessionTransport.ENET_MTU_BYTES)
		peaks.datagram_bytes = maxi(int(peaks.datagram_bytes), wire_bytes)
	session.acknowledge_snapshot()


func _occupancy(court: HexChemistryWorld, tick: int) -> Dictionary:
	var active := {}
	var source_quantity := 0
	var product_quantity := 0
	for record: Dictionary in court.casts.values():
		if not bool(record.get("paid", false)):
			continue
		source_quantity += maxi(0, int(record.get("unallocated", 0))) + maxi(0, int(record.get("ground", 0)))
		if int(record.get("ground", 0)) > 0 and tick < int(record.get("expires", 0)):
			for cell: Vector2i in HexChemistryWorld.coverage(record):
				active[cell] = true
	for product: Dictionary in court.products.values():
		product_quantity += maxi(0, int(product.get("quantity", 0)))
		if tick >= int(product.get("active_tick", 0)) and tick < int(product.get("decay_tick", 0)) and tick < int(product.get("expiry_tick", 0)):
			for cell: Vector2i in HexChemistryWorld.coverage(product):
				active[cell] = true
	return {"active_cells": active.size(), "source_quantity": source_quantity, "product_quantity": product_quantity}


func _accumulate_inventory(world: SimWorld, occupancy: Dictionary, alive: int, totals: Dictionary, peaks: Dictionary) -> void:
	var court: HexChemistryWorld = world.hex_court
	totals.projectile_instance_ticks += world.projectiles.size()
	totals.pending_cast_instance_ticks += court.pending.size()
	totals.cast_instance_ticks += court.casts.size()
	totals.product_instance_ticks += court.products.size()
	totals.active_cell_instance_ticks += int(occupancy.active_cells)
	totals.source_quantity_instance_ticks += int(occupancy.source_quantity)
	totals.product_quantity_instance_ticks += int(occupancy.product_quantity)
	totals.alive_actor_instance_ticks += alive
	var work := not world.projectiles.is_empty() or not court.pending.is_empty() or not court.casts.is_empty() or not court.products.is_empty()
	totals.ticks_with_authority_work += int(work)
	peaks.projectiles = maxi(int(peaks.projectiles), world.projectiles.size())
	peaks.pending_casts = maxi(int(peaks.pending_casts), court.pending.size())
	peaks.casts = maxi(int(peaks.casts), court.casts.size())
	peaks.products = maxi(int(peaks.products), court.products.size())
	peaks.active_cells = maxi(int(peaks.active_cells), int(occupancy.active_cells))
	peaks.source_quantity = maxi(int(peaks.source_quantity), int(occupancy.source_quantity))
	peaks.product_quantity = maxi(int(peaks.product_quantity), int(occupancy.product_quantity))


func _cleanup_pending(world: SimWorld, session: AuthoritativeSession) -> bool:
	var court: HexChemistryWorld = world.hex_court
	return (
		not world.projectiles.is_empty()
		or not court.pending.is_empty()
		or not court.casts.is_empty()
		or not court.products.is_empty()
		or not court.sources.is_empty()
		or not session.pending_combat_events.is_empty()
	)


func _alive_count(world: SimWorld) -> int:
	var result := 0
	for actor: PlayerState in world.players:
		result += int(actor.health > 0)
	return result


func _deterministic_result(result: Dictionary) -> Dictionary:
	var keys: Array[String] = [
		"case", "sample_ticks", "requested_pressed_by_wire", "requested_held_ticks_by_wire",
		"admitted_by_wire", "refusals_by_wire_and_reason", "released_by_wire",
		"processed_clashes", "processed_products", "workload_totals", "event_counts", "authority_metrics", "publication",
		"inventory_totals", "alive_work", "final_occupancy_after_cleanup",
		"contact_queries", "cleanup_ticks", "sample_end_hash", "final_hash", "trace_sha256",
	]
	var deterministic := {}
	for key: String in keys:
		deterministic[key] = result[key]
	var deterministic_peaks: Dictionary = result.peaks.duplicate(true)
	deterministic_peaks.erase("static_memory_bytes")
	deterministic["peaks"] = deterministic_peaks
	return deterministic


func _trace_bytes(world: SimWorld) -> PackedByteArray:
	return (world.state_hash() + ":" + JSON.stringify(world.combat_events) + "\n").to_utf8_buffer()


func _percentiles(values: PackedInt64Array) -> Dictionary:
	if values.is_empty():
		return {"samples": 0, "p50": 0, "p95": 0, "p99": 0, "max": 0}
	var ordered := values.duplicate()
	ordered.sort()
	return {
		"samples": ordered.size(),
		"p50": ordered[_percentile_index(ordered.size(), 50)],
		"p95": ordered[_percentile_index(ordered.size(), 95)],
		"p99": ordered[_percentile_index(ordered.size(), 99)],
		"max": ordered[-1],
	}


func _percentile_index(size: int, percentile: int) -> int:
	return clampi((size * percentile + 99) / 100 - 1, 0, size - 1)


func _count_key(counts: Dictionary, key: String, amount: int = 1) -> void:
	counts[key] = int(counts.get(key, 0)) + amount


func _sum_counts(counts: Dictionary) -> int:
	var result := 0
	for value: Variant in counts.values():
		result += int(value)
	return result


func _source_hashes() -> Dictionary:
	var paths: Array[String] = [
		"tests/performance/profile_unified_wellspring.gd",
		"src/sim/core/sim_world.gd",
		"src/sim/hex/hex_chemistry_world.gd",
		"src/sim/hex/hex_projectile_combat.gd",
		"src/sim/hex/hex_product_effects.gd",
		"src/sim/hex/hex_world_definition.gd",
		"src/net/authoritative_session.gd",
		"src/net/hex_world_snapshot.gd",
		"src/net/session_transport.gd",
		"src/net/world_snapshot_envelope.gd",
		"content/abilities/foundation_abilities_v1.json",
		"content/champions/foundation_champions_v1.json",
		"content/maps/sanctum_campus_g2_v1.json",
	]
	var result := {}
	for path: String in paths:
		result[path] = FileAccess.get_sha256("res://" + path)
	return result


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("unified Wellspring profile: " + message)
