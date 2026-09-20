extends SceneTree
@warning_ignore_start("integer_division")

# Native-display companion to profile_unified_wellspring.gd. The workload script
# is instantiated only as a library of fixture/command/accounting helpers; its
# SceneTree _initialize/_run entry points are never invoked.
const WorkloadScript = preload("res://tests/performance/profile_unified_wellspring.gd")
const BootstrapHarness = preload("res://tests/support/chemistry_coach_harness.gd")
const CASES: Array[String] = ["sustained-distributed", "dense-crucible"]
const MODES: Array[String] = ["normal", "reduced"]
const SAMPLE_TICKS := 720
const TICKS_PER_PRESENT_FRAME := 2
const PRESENTATION_HZ := 60
const FRAME_BUDGET_US := 16_667
const WARMUP_TICKS := 120
const CLEANUP_LIMIT := 2_400
const WIDTH := 1280
const HEIGHT := 720


class RenderHarness extends BootstrapHarness:
	var draw_submission_us := 0
	var draw_invocations := 0

	func _draw() -> void:
		var started := Time.get_ticks_usec()
		super._draw()
		draw_submission_us = Time.get_ticks_usec() - started
		draw_invocations += 1


var failures := 0
var assertions := 0
var output_path := ""
var workload: Variant


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	_check(DisplayServer.get_name() != "headless", "render profile uses a native display backend")
	_check(output_path.begins_with("res://.godot/unified-wellspring-render-profile-") and output_path.ends_with(".json") and not ".." in output_path and not FileAccess.file_exists(output_path), "receipt path is fresh and scoped")
	root.size = Vector2i(WIDTH, HEIGHT)
	root.visible = true

	workload = WorkloadScript.new()
	workload.sample_ticks = SAMPLE_TICKS
	_check(workload.abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "production ability catalogue loads")
	_check(workload.champions.load_from_file("res://content/champions/foundation_champions_v1.json", workload.abilities), "production champion catalogue loads")
	_check(workload.layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "normal Wellspring campus loads")
	workload.definition = HexWorldDefinition.from_campus(workload.layout)
	_check(workload.definition != null, "normal campus produces one trusted whole-hex definition")
	if failures > 0:
		quit(1)
		return

	var runs: Array[Dictionary] = []
	var matched_authority := {}
	for case_name: String in CASES:
		# Reverse the visual-mode order in the second case to balance cache order.
		var order: Array[String] = MODES.duplicate()
		if case_name == "dense-crucible":
			order.reverse()
		for mode: String in order:
			var result: Dictionary = await _measure(case_name, mode)
			runs.append(result)
			var authority := _deterministic_authority(result)
			if not matched_authority.has(case_name):
				matched_authority[case_name] = authority
			else:
				_check(authority == matched_authority[case_name], case_name + " normal and reduced rendering preserve identical authority input and state traces")
			print("UNIFIED_WELLSPRING_RENDER_PROFILE_RESULT ", JSON.stringify(result))

	var receipt := {
		"schema_version": 1,
		"workload_version": "unified-wellspring-render-profile-v1",
		"authority_workload_version": "unified-wellspring-profile-v1",
		"engine": Engine.get_version_info()["string"],
		"display_server": DisplayServer.get_name(),
		"window": {"width": WIDTH, "height": HEIGHT, "presentation_hz": PRESENTATION_HZ},
		"seed": WorkloadScript.SEED,
		"warmup_ticks": WARMUP_TICKS,
		"sample_ticks": SAMPLE_TICKS,
		"ticks_per_present_frame": TICKS_PER_PRESENT_FRAME,
		"present_frames_per_run": SAMPLE_TICKS / TICKS_PER_PRESENT_FRAME,
		"cases": CASES,
		"modes": MODES,
		"runs": runs,
		"source_sha256": _source_hashes(),
		"assertions": assertions + int(workload.assertions),
		"failures": failures + int(workload.failures),
		"scope": "Native-window production Bootstrap draw path at 1280x720 and 60 presentation frames per second. Every measured frame advances the unchanged legal eight-champion workload by two real 120 Hz authority ticks. Normal and reduced modes use fresh matched worlds and identical commands; no state injection, resource refill, cooldown bypass, capacity override, fake scene, socket, physical input, or preference persistence.",
		"measurement_semantics": "present_frame_elapsed_us spans queue_redraw through RenderingServer.frame_post_draw and includes frame scheduling/render completion. bootstrap_draw_submission_us is CPU time inside Bootstrap._draw while it submits CanvasItem commands. two_tick_sim_us and presentation_prepare_us are separately timed on the main thread. Hashing, trace construction, event/inventory accounting, monitor reads, and assertions are outside all reported timers. Godot Performance render counters are samples, not CPU/GPU duration attribution.",
		"performance_acceptance": "NOT_ESTABLISHED; native rendered diagnostic measurements depend on this machine, display backend, driver, window state, and build. They do not establish release capacity or human visual acceptance.",
	}
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	_check(output != null, "render profile receipt opens")
	if output != null:
		receipt.assertions = assertions + int(workload.assertions)
		receipt.failures = failures + int(workload.failures)
		output.store_string(JSON.stringify(receipt, "\t") + "\n")
		output.close()
	print("%s: unified-wellspring-render-profile; %d assertions; %d failures; output=%s" % ["PASS" if int(receipt.failures) == 0 else "FAIL", int(receipt.assertions), int(receipt.failures), output_path])
	workload.free()
	quit(1 if int(receipt.failures) > 0 else 0)


func _measure(case_name: String, mode: String) -> Dictionary:
	var fixture: Dictionary = workload._fixture(case_name)
	var world: SimWorld = fixture.world
	var targets: Dictionary = fixture.targets
	var node := RenderHarness.new()
	root.add_child(node)
	_check(node.configure_fixture(true), case_name + " " + mode + " configures the normal Bootstrap render stack")
	if node.visual_accessibility_filter == null:
		node.visual_accessibility_filter = VisualAccessibilityFilter.new()
		_check(node.visual_accessibility_filter.configure(), case_name + " " + mode + " configures the production accessibility filter")
		node.add_child(node.visual_accessibility_filter)
	node.world = world
	node.authoritative_session = AuthoritativeSession.new()
	node.authoritative_session.world = world
	node.session_round_values = node.authoritative_session.session_round.capture(world)
	node.session_names_by_entity.clear()
	for actor: PlayerState in world.players:
		node.session_names_by_entity[actor.entity_id] = "Profile %d" % actor.entity_id
	node.requested_capture_reduced_effects = mode == "reduced"
	node.player_preferences.reduced_motion = false
	node.input_router.entity_id = 1
	var champion_ids: Array[String] = []
	for actor: PlayerState in world.players:
		champion_ids.append(workload.champions.champion_id_from_wire(actor.champion_wire_id))
	_check(node.cartoon_champion_presenter.prepare_override_pages(champion_ids), case_name + " " + mode + " prepares all eight production champion pages")
	node.accumulator_seconds = 0.0
	node.current_position = node._player_position()
	node.previous_position = node.current_position
	node._reset_motion_history()

	# Equal rendered warmup for both modes. It advances ordinary neutral commands;
	# measured demand still starts exactly where the headless workload starts.
	for unused_frame: int in range(WARMUP_TICKS / TICKS_PER_PRESENT_FRAME):
		for unused_tick: int in range(TICKS_PER_PRESENT_FRAME):
			var warmup_step: Dictionary = _step_and_sync(node, workload._commands(world, targets, case_name, false, false))
			_check(bool(warmup_step.stepped), case_name + " " + mode + " warmup authority step succeeds")
		node._prepare_active_character_pages()
		node._update_character_gaits(1.0 / float(PRESENTATION_HZ))
		var warmup_drew_once: bool = await _present(node)
		_check(warmup_drew_once, "one Bootstrap draw executes for each requested warmup presentation frame")

	var frame_count := SAMPLE_TICKS / TICKS_PER_PRESENT_FRAME
	var present_times := PackedInt64Array()
	var sim_times := PackedInt64Array()
	var prepare_times := PackedInt64Array()
	var draw_submission_times := PackedInt64Array()
	var draw_calls := PackedInt64Array()
	var primitives := PackedInt64Array()
	var objects := PackedInt64Array()
	var video_memory := PackedInt64Array()
	present_times.resize(frame_count)
	sim_times.resize(frame_count)
	prepare_times.resize(frame_count)
	draw_submission_times.resize(frame_count)
	draw_calls.resize(frame_count)
	primitives.resize(frame_count)
	objects.resize(frame_count)
	video_memory.resize(frame_count)
	var requested_pressed := {}
	var requested_held_ticks := {}
	var admitted := {}
	var released := {}
	var refusals := {}
	var event_counts := {}
	var peaks := {
		"projectiles": 0, "pending_casts": 0, "casts": 0, "products": 0,
		"active_cells": 0, "source_quantity": 0, "product_quantity": 0,
	}
	var inventory := {
		"projectile_instance_ticks": 0, "pending_cast_instance_ticks": 0,
		"cast_instance_ticks": 0, "product_instance_ticks": 0,
		"active_cell_instance_ticks": 0, "source_quantity_instance_ticks": 0,
		"product_quantity_instance_ticks": 0, "alive_actor_instance_ticks": 0,
		"ticks_with_authority_work": 0,
	}
	var trace := HashingContext.new()
	trace.start(HashingContext.HASH_SHA256)
	var clashes := 0
	var sample_end_hash := ""
	var frame_deadline_misses := 0
	var draw_mutations := 0
	var draw_authority_checks := 0

	for frame_index: int in range(frame_count):
		var frame_sim_us := 0
		var frame_prepare_us := 0
		var frame_events: Array[Dictionary] = []
		for unused_tick: int in range(TICKS_PER_PRESENT_FRAME):
			var commands: Array[SimCommand] = workload._commands(world, targets, case_name, true, false)
			workload._count_requested(world, commands, requested_pressed, requested_held_ticks)
			var measured_step: Dictionary = _step_and_sync(node, commands)
			_check(bool(measured_step.stepped), case_name + " " + mode + " measured authority step succeeds")
			frame_sim_us += int(measured_step.sim_us)
			frame_prepare_us += int(measured_step.presentation_us)
			clashes += _record_events(world.combat_events, event_counts, admitted, released, refusals)
			for event: Dictionary in world.combat_events:
				frame_events.append(event.duplicate(true))
			var occupancy: Dictionary = workload._occupancy(world.hex_court, world.tick)
			workload._accumulate_inventory(world, occupancy, workload._alive_count(world), inventory, peaks)
		sim_times[frame_index] = frame_sim_us
		var prepare_started := Time.get_ticks_usec()
		node._prepare_active_character_pages()
		node._update_character_gaits(1.0 / float(PRESENTATION_HZ))
		prepare_times[frame_index] = frame_prepare_us + Time.get_ticks_usec() - prepare_started
		var audit_draw := frame_index % PRESENTATION_HZ == 0 or frame_index == frame_count - 1
		var before_draw := world.state_hash() if audit_draw else ""
		var present_started := Time.get_ticks_usec()
		var exactly_one_draw: bool = await _present(node)
		present_times[frame_index] = Time.get_ticks_usec() - present_started
		_check(exactly_one_draw, "one Bootstrap draw executes for each requested measured presentation frame")
		draw_submission_times[frame_index] = node.draw_submission_us
		draw_calls[frame_index] = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives[frame_index] = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		objects[frame_index] = int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		video_memory[frame_index] = int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
		frame_deadline_misses += int(present_times[frame_index] > FRAME_BUDGET_US)
		var frame_hash := world.state_hash()
		trace.update((frame_hash + ":" + JSON.stringify(frame_events) + "\n").to_utf8_buffer())
		if audit_draw:
			draw_authority_checks += 1
			draw_mutations += int(frame_hash != before_draw)
		sample_end_hash = frame_hash

	var cleanup_ticks := 0
	while cleanup_ticks < CLEANUP_LIMIT and _authority_pending(world):
		_check(world.step(workload._commands(world, targets, case_name, false, false)), case_name + " " + mode + " cleanup advances authored expiry")
		clashes += _record_events(world.combat_events, event_counts, admitted, released, refusals)
		cleanup_ticks += 1
	var metrics: Dictionary = world.hex_court.metrics.duplicate(true)
	var final_occupancy: Dictionary = workload._occupancy(world.hex_court, world.tick)
	var deaths: int = world.players.size() - int(workload._alive_count(world))
	var final_hash := world.state_hash()
	trace.update(("cleanup:" + final_hash + ":" + JSON.stringify(world.combat_events) + "\n").to_utf8_buffer())
	_check(draw_mutations == 0, case_name + " " + mode + " production drawing never mutates authority")
	_check(cleanup_ticks < CLEANUP_LIMIT and not _authority_pending(world), case_name + " " + mode + " finite authority drains within the authored bound")
	_check(world.hex_court.conservation_valid(), case_name + " " + mode + " paid matter remains conserved")
	_check(requested_pressed.size() == 12 and requested_held_ticks.size() == 4, case_name + " " + mode + " requests the full first-four four-family workload")
	_check(int(metrics.admitted) > 0 and int(metrics.matter_paid) == int(metrics.admitted) * HexChemistryWorld.MATTER_PER_CAST, case_name + " " + mode + " contains positive real paid admissions")
	_check(deaths == 0 and int(inventory.alive_actor_instance_ticks) == SAMPLE_TICKS * world.players.size(), case_name + " " + mode + " keeps all eight actual champions alive without refill")
	if case_name == "dense-crucible":
		_check(clashes > 0 and int(metrics.reactions) > 0, mode + " dense Crucible processes real clashes and products")
	else:
		_check(int(peaks.active_cells) > 0, mode + " distributed workload creates live whole-hex occupancy")

	var result := {
		"case": case_name,
		"visual_mode": mode,
		"sample_ticks": SAMPLE_TICKS,
		"present_frames": frame_count,
		"present_frame_elapsed_us": workload._percentiles(present_times),
		"two_tick_sim_us": workload._percentiles(sim_times),
		"presentation_prepare_us": workload._percentiles(prepare_times),
		"bootstrap_draw_submission_us": workload._percentiles(draw_submission_times),
		"frame_deadline_misses_over_16667us": frame_deadline_misses,
		"render_monitors": {
			"draw_calls_per_frame": workload._percentiles(draw_calls),
			"primitives_per_frame": workload._percentiles(primitives),
			"objects_per_frame": workload._percentiles(objects),
			"video_memory_bytes": workload._percentiles(video_memory),
		},
		"requested_pressed_by_wire": requested_pressed,
		"requested_held_ticks_by_wire": requested_held_ticks,
		"admitted_by_wire": admitted,
		"refusals_by_wire_and_reason": refusals,
		"released_by_wire": released,
		"processed_clashes": clashes,
		"processed_products": int(metrics.reactions),
		"workload_totals": {
			"requested_pressed": workload._sum_counts(requested_pressed),
			"requested_held_ticks": workload._sum_counts(requested_held_ticks),
			"admitted": int(metrics.admitted),
			"refusals": int(metrics.refused),
			"releases": workload._sum_counts(released),
			"processed_clashes": clashes,
			"processed_products": int(metrics.reactions),
			"active_cell_instance_ticks": int(inventory.active_cell_instance_ticks),
			"source_quantity_instance_ticks": int(inventory.source_quantity_instance_ticks),
			"product_quantity_instance_ticks": int(inventory.product_quantity_instance_ticks),
			"contact_queries": int(metrics.exposure_queries),
		},
		"event_counts": event_counts,
		"authority_metrics": metrics,
		"peaks": peaks,
		"inventory_totals": inventory,
		"alive_work": {
			"deaths": deaths,
			"alive_end": workload._alive_count(world),
			"alive_actor_instance_ticks": int(inventory.alive_actor_instance_ticks),
			"mean_alive_actors": float(inventory.alive_actor_instance_ticks) / float(SAMPLE_TICKS),
			"ticks_with_authority_work": int(inventory.ticks_with_authority_work),
		},
		"final_occupancy_after_cleanup": final_occupancy,
		"contact_queries": int(metrics.exposure_queries),
		"cleanup_ticks": cleanup_ticks,
		"sample_end_hash": sample_end_hash,
		"final_hash": final_hash,
		"trace_sha256": trace.finish().hex_encode(),
		"draw_authority_checks": draw_authority_checks,
		"draw_authority_mutations": draw_mutations,
		"measurement_scope": "Quantiles contain 360 native present frames after 60 equal warmup frames. Each measured present frame owns exactly two consecutive real SimWorld steps. The matched trace hashes authority plus both ticks' events once per presented frame; draw nonmutation is audited at one-second boundaries and the final frame. Observer hashing/accounting and untimed, unrendered cleanup are excluded from timing quantiles.",
	}
	root.remove_child(node)
	node.free()
	await process_frame
	return result


func _step_and_sync(node: RenderHarness, commands: Array[SimCommand]) -> Dictionary:
	var local: PlayerState = node.world.player(1)
	node.previous_position = node.current_position
	node.previous_air_height = local.air_height if local != null else 0
	var sim_started := Time.get_ticks_usec()
	if not node.world.step(commands):
		return {"stepped": false, "sim_us": Time.get_ticks_usec() - sim_started, "presentation_us": 0}
	var sim_us := Time.get_ticks_usec() - sim_started
	var presentation_started := Time.get_ticks_usec()
	node.current_position = node._player_position()
	node.actor_motion_history.capture(node.world.players)
	node._update_combat_cues(1.0 / float(WorkloadScript.TICK_RATE))
	node._ingest_combat_cues(node.world.combat_events)
	return {"stepped": true, "sim_us": sim_us, "presentation_us": Time.get_ticks_usec() - presentation_started}


func _present(node: RenderHarness) -> bool:
	var prior_draws := node.draw_invocations
	node.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return node.draw_invocations == prior_draws + 1


func _record_events(events: Array[Dictionary], counts: Dictionary, admitted: Dictionary, released: Dictionary, refusals: Dictionary) -> int:
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
	return clashes


func _authority_pending(world: SimWorld) -> bool:
	var court: HexChemistryWorld = world.hex_court
	return not world.projectiles.is_empty() or not court.pending.is_empty() or not court.casts.is_empty() or not court.products.is_empty() or not court.sources.is_empty()


func _deterministic_authority(result: Dictionary) -> Dictionary:
	var deterministic := {}
	for key: String in [
		"case", "sample_ticks", "requested_pressed_by_wire", "requested_held_ticks_by_wire",
		"admitted_by_wire", "refusals_by_wire_and_reason", "released_by_wire",
		"processed_clashes", "processed_products", "workload_totals", "event_counts",
		"authority_metrics", "peaks", "inventory_totals", "alive_work",
		"final_occupancy_after_cleanup", "contact_queries", "cleanup_ticks",
		"sample_end_hash", "final_hash", "trace_sha256", "draw_authority_checks", "draw_authority_mutations",
	]:
		deterministic[key] = result[key]
	return deterministic


func _count_key(counts: Dictionary, key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1


func _source_hashes() -> Dictionary:
	var result := {}
	for path: String in [
		"tests/performance/profile_unified_wellspring_rendered.gd",
		"tests/performance/profile_unified_wellspring.gd",
		"tests/support/chemistry_coach_harness.gd",
		"src/app/bootstrap.gd",
		"src/sim/core/sim_world.gd",
		"src/sim/hex/hex_chemistry_world.gd",
		"src/presentation/hex_court_presenter.gd",
	]:
		result[path] = FileAccess.get_sha256("res://" + path)
	return result


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("unified-wellspring-render-profile: " + message)
