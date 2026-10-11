extends "res://tests/performance/profile_unified_wellspring.gd"

## Bounded simulation-only diagnostic. Never a host/render/network capacity gate.
## Reuses the existing eight-player paid workload without resource/cap overrides.
func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output_path = argument.trim_prefix("--output=")
	if not output_path.begins_with("res://.godot/fine-grid-steps-") or not output_path.ends_with(".json") or ".." in output_path or FileAccess.file_exists(output_path):
		quit(1)
		return
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "production abilities load")
	_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "production champions load")
	_check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "production map loads")
	definition = HexWorldDefinition.from_campus(layout)
	if failures > 0 or definition == null:
		quit(1)
		return
	var runs: Array[Dictionary] = []
	var trace_enabled := OS.get_cmdline_user_args().has("--trace")
	var stages_enabled := OS.get_cmdline_user_args().has("--stages")
	for reverse_order: bool in [false, true]:
		var fixture := _fixture("dense-crucible")
		var world: SimWorld = fixture.world
		world.profile_enabled = stages_enabled
		for actor: PlayerState in world.players: actor.team_id = 1
		for unused: int in WARMUP_TICKS:
			_check(world.step(_commands(world, fixture.targets, "dense-crucible", false, reverse_order)), "warmup advances")
		var times: Array[int] = []
		var peak_flights := 0
		var peak_casts := 0
		var peak_products := 0
		var peak_events := 0
		var deadlines := 0
		var tick_samples: Array[Dictionary] = []
		var trace := HashingContext.new()
		trace.start(HashingContext.HASH_SHA256)
		for unused: int in 720:
			var commands := _commands(world, fixture.targets, "dense-crucible", true, reverse_order)
			var started := Time.get_ticks_usec()
			var stepped := world.step(commands)
			var elapsed := Time.get_ticks_usec() - started
			_check(stepped, "paid simulation advances")
			times.append(elapsed)
			deadlines += int(elapsed > TICK_BUDGET_US)
			tick_samples.append({"tick":world.tick-1,"us":elapsed,"stages":world.profile_stages_us.duplicate(),"flights":world.projectiles.size(),"products":world.hex_court.products.size(),"events":world.combat_events.size()})
			peak_flights = maxi(peak_flights, world.projectiles.size())
			peak_casts = maxi(peak_casts, world.hex_court.casts.size())
			peak_products = maxi(peak_products, world.hex_court.products.size())
			peak_events = maxi(peak_events, world.combat_events.size())
			# Deliberately outside the measured step. A final hash alone cannot
			# detect a transient contact/event difference that later disappears.
			if trace_enabled:
				_trace_tick(trace, world)
		_check(peak_flights > 0 and peak_products > 0, "workload exercised real projectiles and reactions")
		_check(world.hex_court.conservation_valid(), "paid finite matter conserved")
		times.sort()
		var result := {"reverse_command_order":reverse_order, "sample_ticks":720, "step_p50_us":times[360], "step_p95_us":times[684], "step_max_us":times[-1], "ticks_over_8333_us":deadlines, "peak_flights":peak_flights, "peak_casts":peak_casts, "peak_products":peak_products, "peak_events_per_tick":peak_events, "metrics":world.hex_court.metrics.duplicate(true), "final_hash":world.state_hash()}
		result.authority_event_trace_sha256 = trace.finish().hex_encode() if trace_enabled else "NOT_RUN"
		result.step_p99_us = times[712]
		result.tick_samples = tick_samples
		runs.append(result)
		var summary := result.duplicate()
		summary.erase("tick_samples")
		print("FINE_GRID_STEP_RESULT ", JSON.stringify(summary))
	_check(runs[0].final_hash == runs[1].final_hash, "reverse command order preserves authoritative state")
	if trace_enabled:
		_check(runs[0].authority_event_trace_sha256 == runs[1].authority_event_trace_sha256, "every measured tick preserves authority and ordered events under reversed commands")
	var receipt := {"status":"passed" if failures == 0 else "failed", "assertions":assertions, "failures":failures, "runtime_identity":JSON.parse_string(FileAccess.get_file_as_string(RuntimeBuildIdentity.MANIFEST_PATH)), "topology_cells":definition.eligible_cells.size(), "runs":runs, "scope":"120 warmup and720 measured ticks per run, eight real paid casters, production first-four elements/four deliveries; simulation step only. No event retention, snapshots, sockets, rendering, physical input, long soak or extreme capacity acceptance. No resource refill or cap override.", "script_sha256":FileAccess.get_sha256("res://tests/performance/profile_fine_grid_steps.gd")}
	receipt.source_sha256 = _source_hashes()
	receipt.entry_script = get_script().resource_path
	receipt.entry_sha256 = FileAccess.get_sha256(get_script().resource_path)
	receipt.workload = _workload_description()
	receipt.trace_encoding = "native-variant-full-authority-and-events-v1" if trace_enabled else "NOT_RUN"
	receipt.scope += " Optional trace is sampled outside step timing; no trace hash is used by gameplay or networking. Manifest identity may be stale during development; source hashes identify the measured files."
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(receipt, "\t") + "\n")
	file.close()
	quit(1 if failures > 0 else 0)


func _workload_description() -> String:
	return "Original mixed-family eight-caster cadence."


func _trace_tick(trace: HashingContext, world: SimWorld) -> void:
	# Test-only native encoding avoids rebuilding/sorting 11k empty JSON cells
	# every tick. Include every authority field, including all cell metadata.
	# This is intentionally insertion-order-sensitive, NOT a wire/protocol hash.
	# The canonical final hash is checked separately. Exact old/new byte equality
	# is a stronger requirement than semantic equality for this fixed workload.
	var court: HexChemistryWorld = world.hex_court
	trace.update(world._state_hash_with_verified_hex_hash("").to_utf8_buffer())
	trace.update(var_to_bytes([court.origin, court.current_tick, court.chemistry_enabled,
		court.next_cast_id, court.next_product_id, court.next_ground_part_id, court.cells,
		court.casts, court.products, court.pending, court.sources, court.exposure,
		court.flow_carry, court.metrics, world.combat_events]))
