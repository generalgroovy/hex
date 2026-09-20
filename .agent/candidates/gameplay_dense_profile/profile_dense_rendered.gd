extends SceneTree


const Workload = preload("res://tests/performance/dense_profile_workload.gd")
const RenderHarness = preload("res://tests/performance/dense_profile_render_harness.gd")

var failures := 0
var assertions := 0
var output_path := ""


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	call_deferred("_run")


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	_check(output_path.begins_with("res://.godot/dense-rendered-") and output_path.ends_with(".json") and not ".." in output_path and not FileAccess.file_exists(output_path), "fresh scoped native-rendered receipt")
	if failures > 0:
		_finish([])
		return
	var cases: Array[Dictionary] = [
		{"variant": "ordinary", "use_hex": false, "reduced": false},
		{"variant": "hex", "use_hex": true, "reduced": false},
		{"variant": "hex", "use_hex": true, "reduced": true},
		{"variant": "ordinary", "use_hex": false, "reduced": true},
	]
	var results: Array[Dictionary] = []
	var references := {}
	for definition: Dictionary in cases:
		var result: Dictionary = await _measure(bool(definition.use_hex), bool(definition.reduced))
		results.append(result)
		var variant: String = definition.variant
		if references.has(variant):
			_check(result.invariant_outcome == references[variant], "%s normal/reduced rendering preserves identical authority outcome" % variant)
		else:
			references[variant] = result.invariant_outcome
	var expected_command_sha256 := ""
	for result: Dictionary in results:
		var command_sha256 := String((result.get("observation", {}) as Dictionary).get("command_sha256", ""))
		if expected_command_sha256.is_empty():
			expected_command_sha256 = command_sha256
		else:
			_check(command_sha256 == expected_command_sha256, "all native cases receive the same complete command payload timeline")
	_finish(results)


func _measure(use_hex: bool, reduced: bool) -> Dictionary:
	var variant := "hex" if use_hex else "ordinary"
	var mode := "reduced" if reduced else "normal"
	var game = RenderHarness.new()
	var configured: bool = game.configure_dense_profile(use_hex, reduced)
	_check(configured, "%s/%s production render harness configures" % [variant, mode])
	if not configured:
		game.free()
		return {"variant": variant, "effects_mode": mode, "invariant_outcome": {}}
	root.add_child(game)
	var combat_cue_peak := game.combat_cues.size()
	for warmup_frame: int in range(Workload.RENDER_WARMUP_FRAMES):
		for sub_tick: int in range(Workload.SIM_TICKS_PER_RENDER_FRAME):
			var timeline_tick := warmup_frame * Workload.SIM_TICKS_PER_RENDER_FRAME + sub_tick
			_check(game.world.step(Workload.commands(game.world, timeline_tick, false)), "%s/%s render warmup step succeeds" % [variant, mode])
			game.profile_sync_after_step()
		await _render_once(game)
	var observation := Workload.new_observation()
	var command_hash := HashingContext.new()
	_check(command_hash.start(HashingContext.HASH_SHA256) == OK, "%s/%s command digest initializes" % [variant, mode])
	var peaks := Workload.new_peaks()
	var sim_us := PackedInt64Array()
	var draw_submission_us := PackedInt64Array()
	var frame_elapsed_us := PackedInt64Array()
	var monitor_peaks := Workload.monitor_snapshot()
	var memory_start := Workload.monitor_snapshot()
	var deadline_misses := 0
	for frame_index: int in range(Workload.RENDER_SAMPLE_FRAMES):
		for sub_tick: int in range(Workload.SIM_TICKS_PER_RENDER_FRAME):
			var timeline_tick := frame_index * Workload.SIM_TICKS_PER_RENDER_FRAME + sub_tick
			var commands_value: Array[SimCommand] = Workload.commands(game.world, timeline_tick, true)
			if not Workload.hash_commands(command_hash, commands_value):
				_check(false, "%s/%s command digest update succeeds" % [variant, mode])
			Workload.observe_commands(commands_value, observation)
			var sim_started := Time.get_ticks_usec()
			var stepped := game.world.step(commands_value)
			var sim_elapsed := Time.get_ticks_usec() - sim_started
			sim_us.append(sim_elapsed)
			deadline_misses += int(sim_elapsed > Workload.TICK_BUDGET_US)
			_check(stepped, "%s/%s measured sim step succeeds" % [variant, mode])
			Workload.observe_events(game.world.combat_events, observation)
			Workload.observe_peaks(game.world, peaks)
			game.profile_sync_after_step()
			combat_cue_peak = maxi(combat_cue_peak, game.combat_cues.size())
		var authority_before := game.world.state_hash() if frame_index % 60 == 0 else ""
		var rendered: Dictionary = await _render_once(game)
		draw_submission_us.append(int(rendered.draw_cpu_us))
		frame_elapsed_us.append(int(rendered.frame_elapsed_us))
		if not authority_before.is_empty():
			_check(game.world.state_hash() == authority_before, "%s/%s draw does not mutate authority" % [variant, mode])
		Workload.merge_monitor_peaks(monitor_peaks, Workload.monitor_snapshot())
	var memory_end := Workload.monitor_snapshot()
	observation.command_sha256 = command_hash.finish().hex_encode()
	var final_hash := game.world.state_hash()
	var conservation: Variant = game.world.hex_court.conservation_valid() if use_hex else null
	var final_inventory: Dictionary = Workload.inventory(game.world)
	var authority_metrics: Dictionary = game.world.hex_court.metrics.duplicate(true) if use_hex else {}
	var actor_outcomes: Array[Dictionary] = []
	for actor: PlayerState in game.world.players:
		actor_outcomes.append({"entity_id": actor.entity_id, "health": actor.health, "flux": actor.flux, "position": [actor.position_x, actor.position_y], "alive": actor.health > 0})
	_check(observation.command_ticks == Workload.RENDER_SAMPLE_FRAMES * Workload.SIM_TICKS_PER_RENDER_FRAME * Workload.EMITTER_COUNT, "%s/%s retains every render-timeline command" % [variant, mode])
	_check(observation.cast_started > 0, "%s/%s contains actual paid casts" % [variant, mode])
	if use_hex:
		_check(bool(conservation) and peaks.hex_products > 0, "%s/%s reaches conserved product geometry" % [variant, mode])
	var invariant := {"final_hash": final_hash, "observation": observation, "peaks": peaks, "final_inventory": final_inventory, "authority_metrics": authority_metrics, "actors": actor_outcomes, "conservation": conservation}
	var result := {
		"variant": variant, "effects_mode": mode,
		"viewport": [1280, 720], "warmup_frames_excluded": Workload.RENDER_WARMUP_FRAMES,
		"sample_frames": Workload.RENDER_SAMPLE_FRAMES, "sim_ticks_per_frame": Workload.SIM_TICKS_PER_RENDER_FRAME,
		"sim_step_us": Workload.percentiles(sim_us), "sim_over_8333us_count": deadline_misses,
		"draw_cpu_submission_us": Workload.percentiles(draw_submission_us),
		"frame_post_draw_elapsed_us": Workload.percentiles(frame_elapsed_us),
		"observation": observation, "peaks": peaks, "final_inventory": final_inventory, "authority_metrics": authority_metrics, "actors": actor_outcomes,
		"memory_start": memory_start, "memory_end": memory_end, "monitor_peaks": monitor_peaks,
		"presentation_queue_peaks": {"combat_cues": combat_cue_peak, "projectiles": int(peaks.projectiles), "hex_products": int(peaks.hex_products)},
		"conservation_outside_timing": conservation, "final_state_hash_outside_timing": final_hash,
		"invariant_outcome": invariant,
	}
	game.queue_free()
	await process_frame
	return result


func _render_once(game) -> Dictionary:
	game.profile_prepare_render_frame()
	var draws_before: int = game.profiled_draw_count
	var started := Time.get_ticks_usec()
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var elapsed := Time.get_ticks_usec() - started
	_check(game.profiled_draw_count > draws_before, "queued frame invokes production draw submission")
	return {"draw_cpu_us": game.last_draw_cpu_us, "frame_elapsed_us": elapsed}


func _source_hashes() -> Dictionary:
	var result := {}
	for path: String in [
		"res://tests/performance/dense_profile_workload.gd",
		"res://tests/performance/dense_profile_render_harness.gd",
		"res://tests/performance/profile_dense_rendered.gd",
		"res://tests/support/chemistry_coach_harness.gd", "res://src/app/bootstrap.gd",
		"res://src/presentation/hex_court_presenter.gd", "res://src/presentation/element_chemistry_presenter.gd",
		"res://src/presentation/foundation_spell_presenter.gd", "res://src/presentation/burst_projectile_presenter.gd",
		"res://src/sim/core/sim_world.gd", "res://src/sim/hex/hex_court.gd", "res://src/sim/hex/hex_court_practice.gd",
		"res://content/abilities/foundation_abilities_v1.json", "res://project.godot",
	]:
		result[path.trim_prefix("res://")] = FileAccess.get_sha256(path)
	return result


func _finish(results: Array[Dictionary]) -> void:
	var receipt := {
		"schema_version": 1, "workload_version": "dense-paid-rendered-v1",
		"runtime_identity": JSON.parse_string(FileAccess.get_file_as_string(RuntimeBuildIdentity.MANIFEST_PATH)),
		"engine": Engine.get_version_info()["string"],
		"renderer": RenderingServer.get_current_rendering_driver_name(),
		"hardware": {"cpu": OS.get_processor_name(), "logical_processors": OS.get_processor_count(), "os": OS.get_name()},
		"settings": {"seed": Workload.SEED, "tick_rate": Workload.TICK_RATE, "map_world_units": [Workload.MAP_WIDTH, Workload.MAP_HEIGHT], "obstacles": 0, "emitters": Workload.EMITTER_COUNT, "viewport": [1280, 720], "warmup_frames_excluded": Workload.RENDER_WARMUP_FRAMES, "sample_frames_per_case": Workload.RENDER_SAMPLE_FRAMES, "sim_ticks_per_frame": Workload.SIM_TICKS_PER_RENDER_FRAME, "command_line_fixed_fps_override": false, "project_max_fps": int(ProjectSettings.get_setting("application/run/max_fps", 0)), "effects_modes": ["normal", "reduced"]},
		"source_hashes": _source_hashes(), "results": results,
		"assertions": assertions, "failures": failures,
		"scope": "Native local Godot rendering into the 1280x720 main window. Four unnetworked fixtures use the matched paid command timeline. No sockets, remote client, lobby, physical input, installer, publication or player-count support claim.",
		"render_geometry": "Both variants use the same empty collision court and solid empty-map backing. Ordinary draws production legacy chemistry/projectiles/actors/cues; hex additionally draws production canonical court geometry. Normal and reduced modes receive identical authority inputs.",
		"timing_semantics": "Two 120Hz simulation steps are measured separately per rendered frame. Bootstrap._draw CPU submission and queue_redraw-to-frame_post_draw elapsed time are separate distributions. The wrapper injects no --fixed-fps override; the recorded project max-FPS setting still applies. Elapsed frame samples can include driver, compositor and scheduling waits and are not an FPS capacity claim.",
		"memory_semantics": "Godot static memory and Performance monitors include the harness, presentation caches and retained report arrays. They do not establish allocation rate, OS working set, VRAM residency or remote-client cost.",
		"mutation_policy": "No resource refill, maximum increase, cooldown clearing, direct projectile/field/product insertion, retained-state eviction or early sample termination.",
	}
	if output_path.is_empty():
		failures += 1
	else:
		var file := FileAccess.open(output_path, FileAccess.WRITE)
		_check(file != null, "native-rendered receipt opens")
		if file != null:
			receipt.assertions = assertions
			receipt.failures = failures
			file.store_string(JSON.stringify(receipt, "  "))
			file.close()
	print("%s: dense-native-rendered-profile; %d assertions; %d failures" % ["PASS" if failures == 0 else "FAIL", assertions, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		print("FAIL: ", message)
