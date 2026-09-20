extends SceneTree
@warning_ignore_start("integer_division")

# Dense authority microbenchmark, not a SimWorld, render-frame, network or FPS
# measurement. Fixture admission commits finite matter through the public court
# lifecycle; it does not run or charge a player spell command/Flux transaction.
const REPETITIONS := 3
const SAMPLE_TICKS := 600
const MICRO_ITERATIONS := 120
const MATERIALS := ["water", "fire", "steam", "conflagration", "flood"]
var failures := 0
var assertions := 0
var catalog := AbilityCatalog.new()
var source_id := 10_000


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	_check(output.begins_with("res://.godot/whole-hex-profile-") and output.ends_with(".json") and not ".." in output and not FileAccess.file_exists(output), "fresh scoped output path")
	_check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "production catalog loads")
	if failures > 0:
		quit(1)
		return
	var runs: Array[Dictionary] = []
	for repetition: int in range(REPETITIONS):
		runs.append(_measure(repetition + 1))
		if repetition > 0: _check(runs[repetition].outcome == runs[0].outcome, "fresh repetition deterministic outcome")
	var hashes := {}
	for path: String in ["tests/performance/profile_whole_hex.gd", "src/sim/hex/hex_court.gd", "src/sim/hex/hex_grid.gd", "src/sim/hex/hex_footprint.gd", "src/sim/combat/strength_budget.gd"]:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	var receipt := {"kind": "dense_finite_authority_microbenchmark", "tick_rate": 120, "repetitions": REPETITIONS,
		"sample_ticks_per_repeat": SAMPLE_TICKS, "runs": runs, "source_sha256": hashes, "assertions": assertions, "failures": failures,
		"limits": "Public paid matter fixture, not player Flux admission or a full SimWorld step. Paths are supplied by this harness. No health, strength, lifetime, or budget overrides/refills. Headless region generation is not GPU rendering, FPS, network capacity or release evidence."}
	var file := FileAccess.open(output, FileAccess.WRITE)
	_check(file != null, "output opens")
	if file != null:
		file.store_string(JSON.stringify(receipt, "\t") + "\n")
		file.close()
	print("WHOLE_HEX_PROFILE assertions=%d failures=%d output=%s" % [assertions, failures, output])
	quit(1 if failures > 0 else 0)


func _measure(repetition: int) -> Dictionary:
	source_id = 10_000
	var court := HexCourt.new()
	court.chemistry_enabled = true
	var counts := {"requested": 0, "admitted": 0, "denied": 0, "denied_reasons": {}}
	var water := _wire("water", "rapid")
	var fire := _wire("fire", "rapid")
	# Explicit flight contacts create independent products without depositing
	# incoming modifiers into existing Steam. Sources are paid once, exhausted by
	# the contact, then receive duplicate-safe terminal notifications and cleanup.
	for index: int in range(24):
		var first_wire := fire if index % 3 == 1 else water
		var second_wire := water if index % 3 == 2 else fire
		var first := _admit(court, first_wire, counts)
		var second := _admit(court, second_wire, counts)
		var point := court.origin + Vector2i((index % 4 - 2) * 12_000, (index / 4 % 2) * 12_000)
		if first > 0 and second > 0:
			var result := court.resolve_contact(first, second, point, 0)
			_check(bool(result.get("accepted", false)), "paid pair creates finite medium")
			_terminal(court, first_wire, first, point)
			_terminal(court, second_wire, second, point)
		court.sync_flights([], [])
	# Distant isolated Rapid cells retain finite Water/Fire ingredients; they do
	# not immediately turn into products or consume a Steam modifier channel.
	var outer: Array[Vector2i] = [Vector2i(-4, 0), Vector2i(4, 0), Vector2i(0, -4), Vector2i(0, 4), Vector2i(-4, 4), Vector2i(4, -4), Vector2i(-2, -2), Vector2i(2, 2)]
	for index: int in range(outer.size()):
		var wire := water if index % 2 == 0 else fire
		var source := _admit(court, wire, counts)
		if source > 0: _terminal(court, wire, source, court.origin + HexGrid.center(outer[index]))
	var denied_source := _admit(court, water, counts)
	_check(denied_source == 0 and int(counts.denied) > 0, "dense reservation cap refuses without payment")
	_check(court.products.size() == 24 and court.casts.size() == 8, "dense fixture has 24 products and 8 live ingredients")
	_check(court.conservation_valid(), "dense fixture conserves paid matter")
	var initial := _occupancy(court)
	var micro := _micro(court)
	var players: Array[PlayerState] = []
	for index: int in range(8): players.append(PlayerState.new(index + 1))
	var config := SimConfig.new(120)
	var collision := CollisionWorld.new(1_280_000, 960_000)
	var accepts_paths := false
	for method: Dictionary in court.get_method_list():
		if String(method.name) == "apply_product_effects": accepts_paths = method.args.size() >= 6
	var samples := PackedInt64Array()
	var active_samples := PackedInt64Array()
	var occupancy_samples: Array[Dictionary] = []
	var event_counts := {}
	var misses := 0
	var conservation := true
	for tick: int in range(SAMPLE_TICKS):
		var paths := {}
		for index: int in range(players.size()):
			var actor: PlayerState = players[index]
			var phase := (tick + index * 11) % 120
			var x := -280_000 + (phase if phase < 60 else 120 - phase) * 9_333
			var point := court.origin + Vector2i(x, (index % 4 - 2) * 18_000)
			paths[actor.entity_id] = {"point": Vector2i(actor.position_x, actor.position_y) if tick > 0 else point, "height": actor.air_height}
			actor.position_x = point.x
			actor.position_y = point.y
		var events: Array[Dictionary] = []
		var begin := Time.get_ticks_usec()
		court.expire_at(tick)
		if accepts_paths:
			court.callv("apply_product_effects", [players, tick, config, collision, events, paths])
		else:
			court.callv("apply_product_effects", [players, tick, config, collision, events])
		court.advance(players, paths, tick, config, events)
		court.sync_flights(players, [])
		var elapsed := Time.get_ticks_usec() - begin
		samples.append(elapsed)
		if tick >= HexCourt.MEDIUM_FORMATION_TICKS and tick < HexCourt.MEDIUM_FORMATION_TICKS + HexCourt.MEDIUM_ACTIVE_TICKS: active_samples.append(elapsed)
		misses += int(elapsed > 8_333)
		conservation = court.conservation_valid() and conservation
		for event: Dictionary in events:
			var kind := String(event.get("type", "unknown"))
			event_counts[kind] = int(event_counts.get(kind, 0)) + 1
		if tick % 60 == 0 or tick == SAMPLE_TICKS - 1:
			var occupancy := _occupancy(court)
			occupancy.tick = tick
			occupancy.alive_actors = players.filter(func(actor: PlayerState) -> bool: return actor.health > 0).size()
			occupancy_samples.append(occupancy)
	_check(conservation, "every measured tick conserves finite material")
	var health: Array[int] = []
	for actor: PlayerState in players: health.append(actor.health)
	var outcome := {"court_hash": court.state_hash(), "counts": counts, "occupancy": occupancy_samples, "events": event_counts, "final_health": health, "conservation": conservation}
	return {"repetition": repetition, "initial_occupancy": initial, "fixture_admission": counts, "adapter_accepts_paths": accepts_paths,
		"adapter_us": _stats(samples), "active_medium_window_adapter_us": _stats(active_samples), "over_8333us": misses,
		"selection_and_regions": micro, "outcome": outcome}


func _admit(court: HexCourt, wire: int, counts: Dictionary) -> int:
	source_id += 1
	counts.requested += 1
	var reason := court.admission_reason(wire)
	if not court.reserve_cast(source_id, wire):
		counts.denied += 1
		counts.denied_reasons[reason] = int(counts.denied_reasons.get(reason, 0)) + 1
		return 0
	court.commit_payment(source_id)
	court.bind_release(source_id, source_id, court.origin, Vector2i(1000, 0))
	counts.admitted += 1
	return source_id


func _terminal(court: HexCourt, wire: int, source: int, point: Vector2i) -> void:
	var definition := CombatTuning.cast_definition(wire)
	court.deposit_terminal({"source_cast_id": source, "source_wire_id": wire, "reaction_strength": int(definition.reaction_strength), "position": point, "direction": Vector2i(1000, 0)}, 0)


func _wire(element: String, delivery: String) -> int:
	return int(catalog.ability(catalog.spell_id_at(element, delivery)).get("wire_id", 0))


func _occupancy(court: HexCourt) -> Dictionary:
	var layers := {}
	var live_cells := 0
	for material: String in MATERIALS: layers[material] = 0
	for cell: Vector2i in court.cells:
		var live := false
		for material: String in MATERIALS:
			for amount: int in court.cells[cell][material].values():
				if amount > 0:
					layers[material] += 1
					live = true
		live_cells += int(live)
	return {"live_cells": live_cells, "layer_entries": layers, "sources": court.sources.size(), "casts": court.casts.size(), "products": court.products.size(), "paid": int(court.metrics.matter_paid), "consumed": int(court.metrics.matter_consumed), "expired": int(court.metrics.matter_expired)}


func _micro(court: HexCourt) -> Dictionary:
	var selection := PackedInt64Array()
	var regions := PackedInt64Array()
	var selected_count := 0
	var region_count := 0
	for index: int in range(MICRO_ITERATIONS):
		# Route through the real court selector in both source versions: after
		# migration its selector can differ from the retained analytic helper.
		var preview_record := {"wire": _wire("water", "heavy" if index % 2 == 0 else "spray"), "origin": court.origin}
		var endpoint := court.origin + Vector2i(index * 137 % 32_000, index * 73 % 18_000) if index % 2 == 0 else court.origin + Vector2i(160_000, 0)
		var event := {"position": endpoint, "direction": Vector2i(1000, 0)}
		var begin := Time.get_ticks_usec()
		selected_count += court.footprint(event, preview_record).size()
		selection.append(Time.get_ticks_usec() - begin)
		begin = Time.get_ticks_usec()
		for cell: Vector2i in court.cells:
			for material: String in MATERIALS: region_count += court.render_regions(cell, material, 30).size()
		regions.append(Time.get_ticks_usec() - begin)
	return {"iterations": MICRO_ITERATIONS, "disk_sector_selection_us": _stats(selection), "all_material_region_sweep_us": _stats(regions), "first_region_sweep_us": regions[0], "selected_cell_checksum": selected_count, "region_checksum": region_count, "region_note": "First region sweep includes cold cache; later sweeps use the real unchanged court cache. Does not draw frames."}


func _stats(values: PackedInt64Array) -> Dictionary:
	var ordered := values.duplicate()
	ordered.sort()
	return {"samples": ordered.size(), "p50": ordered[(ordered.size() * 50 + 99) / 100 - 1], "p95": ordered[(ordered.size() * 95 + 99) / 100 - 1], "p99": ordered[(ordered.size() * 99 + 99) / 100 - 1], "max": ordered[-1]}


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("whole-hex profile: " + message)
