extends SceneTree

@warning_ignore_start("integer_division")


# Matched local-simulation profile. Both variants use the same production
# AbilityCatalog, HexCourtPractice loadout, empty 1280x960 map, seed, actor and
# command timeline. The only variant is whether HexCourt remains authoritative.
const SEED: int = 915_2026
const TICK_RATE: int = 120
const WARMUP_TICKS: int = 240
const SAMPLE_TICKS: int = 2_400
const REPETITIONS: int = 3
const TICK_BUDGET_US: int = 8_333
const MICRO_ITERATIONS: int = 300
const MAP_WIDTH: int = 1_280_000
const MAP_HEIGHT: int = 960_000
const PATCHES: Array[Vector2i] = [
	Vector2i.ZERO,
	Vector2i(1, 0),
	Vector2i(0, -1),
	Vector2i(-1, 1),
]

var failures: int = 0
var assertions: int = 0
var abilities: AbilityCatalog = AbilityCatalog.new()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_path: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	_check(
		output_path.begins_with("res://.godot/hex-profile-")
		and output_path.ends_with(".json")
		and not ".." in output_path
		and not FileAccess.file_exists(output_path),
		"fresh scoped JSON output path",
	)
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "production ability catalog loads")
	if failures > 0:
		_finish(output_path, {}, [], [])
		return

	var microbenchmarks: Dictionary = {}
	var results: Array[Dictionary] = []
	var execution_order: Array[Dictionary] = []
	var reference_outcomes: Dictionary = {}
	for repetition: int in range(REPETITIONS):
		var variants: Array[String] = ["hex", "ordinary"]
		if repetition % 2 != 0:
			variants.reverse()
		for variant: String in variants:
			var use_hex: bool = variant == "hex"
			var result: Dictionary = _measure_variant(use_hex, repetition + 1)
			results.append(result)
			execution_order.append({"sequence": execution_order.size() + 1, "repetition": repetition + 1, "variant": variant})
			var outcome: Dictionary = result["deterministic_outcome"]
			if reference_outcomes.has(variant):
				_check(outcome == reference_outcomes[variant], "%s repetition preserves deterministic outcome" % variant)
			else:
				reference_outcomes[variant] = outcome
	# Keep the geometry microbenchmark after matched SimWorld runs so it cannot
	# prime only the hex variant before the comparison.
	microbenchmarks = _measure_hex_grid_microbenchmarks()
	_finish(output_path, microbenchmarks, results, execution_order)


func _measure_variant(use_hex: bool, repetition: int) -> Dictionary:
	var variant: String = "hex" if use_hex else "ordinary"
	# The default constructor supplies the one actor required by the production
	# practice configurator; configure() then replaces its temporary map with the
	# exact empty 1280x960 court collision world used by both variants.
	var world: SimWorld = SimWorld.new(TICK_RATE, SEED)
	_check(HexCourtPractice.configure(world, abilities, false), "%s practice loadout configures" % variant)
	# HexCourtPractice supplies the exact production court actor/loadout/map
	# dimensions. Removing only the new authority yields the ordinary comparator.
	if not use_hex:
		world.hex_court = null
	world.map_id = "hex-profile-matched-empty"
	world.map_hash = "1280x960;no-obstacles;water-fire-eight-slot-v1"
	_check(world.collision.width == MAP_WIDTH and world.collision.height == MAP_HEIGHT, "%s uses matched map dimensions" % variant)
	_check(world.collision.obstacle_view().is_empty(), "%s matched map has no obstacles" % variant)
	_check(world.is_valid(), "%s matched world starts valid" % variant)
	var actor: PlayerState = world.player()
	_check(actor != null and actor.has_valid_spell_slots(), "%s uses the complete validated practice loadout" % variant)
	var initial_flux: int = actor.flux
	var minimum_flux: int = actor.flux
	for warmup_index: int in range(WARMUP_TICKS):
		if not world.step([_command(world, warmup_index, false)]):
			_check(false, "%s warmup step %d succeeds" % [variant, warmup_index])
			break

	var step_times: PackedInt64Array = PackedInt64Array()
	step_times.resize(SAMPLE_TICKS)
	var requested: Dictionary = {"total_spell_intent_ticks": 0, "pressed": 0, "held_rapid": 0, "pending_at_input": 0, "cooldown_at_input": 0}
	var events: Dictionary = {"cast_started": 0, "cast_refused": 0, "refusals_by_reason": {}, "started_by_family": {}, "started_by_element": {}, "started_by_wire": {}}
	var peaks: Dictionary = {
		"projectiles": 0,
		"active_hex_cells": 0,
		"hex_water_layer_entries": 0,
		"hex_fire_layer_entries": 0,
		"hex_steam_layer_entries": 0,
		"hex_casts": 0,
		"hex_pending": 0,
		"hex_products": 0,
	}
	var deadline_misses: int = 0
	var measured_ticks: int = 0
	var exposure_before: int = int(world.hex_court.metrics.get("exposure_queries", 0)) if world.hex_court != null else 0
	for sample_index: int in range(SAMPLE_TICKS):
		var command: SimCommand = _command(world, sample_index, true)
		_observe_input(actor, command, requested)
		var started_us: int = Time.get_ticks_usec()
		var stepped: bool = world.step([command])
		var elapsed_us: int = Time.get_ticks_usec() - started_us
		step_times[sample_index] = elapsed_us
		measured_ticks += 1
		deadline_misses += int(elapsed_us > TICK_BUDGET_US)
		if not stepped:
			_check(false, "%s measured step %d succeeds" % [variant, sample_index])
			break
		_observe_events(world.combat_events, events)
		_observe_peaks(world, peaks)
		minimum_flux = mini(minimum_flux, actor.flux)

	# Canonical state and conservation are deliberately outside the timed step.
	var final_state_hash: String = world.state_hash()
	var authority_valid: bool = world.is_valid()
	var conservation: Dictionary = {
		"applicable": world.hex_court != null,
		"valid": world.hex_court.conservation_valid() if world.hex_court != null else null,
		"ordinary_authority_note": "Legacy ordinary chemistry has no finite HexCourt matter ledger." if world.hex_court == null else "",
	}
	var exposure_after: int = int(world.hex_court.metrics.get("exposure_queries", 0)) if world.hex_court != null else 0
	var exposure_queries: int = exposure_after - exposure_before
	_check(measured_ticks == SAMPLE_TICKS, "%s completes all measured ticks" % variant)
	_check(authority_valid, "%s authority remains valid after measurement" % variant)
	if use_hex:
		_check(bool(conservation.valid), "hex paid matter remains conserved")
	_check(int(events.cast_started) > 0, "%s command stream produces paid casts" % variant)
	for family: String in ["bolt", "heavy", "rapid", "spray"]:
		_check(int(events.started_by_family.get(family, 0)) > 0, "%s actually starts %s" % [variant, family])
	for element: String in ["water", "fire"]:
		_check(int(events.started_by_element.get(element, 0)) > 0, "%s actually starts %s" % [variant, element])
	_check(int(peaks.projectiles) > 0, "%s reaches live projectile work" % variant)
	if use_hex:
		_check(int(peaks.active_hex_cells) > 0 and int(peaks.hex_products) > 0, "hex workload reaches layered cells and products")

	var deterministic_outcome: Dictionary = {
		"final_state_hash": final_state_hash,
		"requested": requested,
		"events": events,
		"peaks": peaks,
		"exposure_queries": exposure_queries,
		"initial_flux": initial_flux,
		"minimum_flux": minimum_flux,
		"final_flux": actor.flux,
		"final_position": [actor.position_x, actor.position_y],
		"conservation": conservation,
		"authority_valid": authority_valid,
	}
	return {
		"variant": variant,
		"repetition": repetition,
		"warmup_ticks_excluded": WARMUP_TICKS,
		"sample_ticks": measured_ticks,
		"step_us": _percentiles(step_times),
		"over_8333us_count": deadline_misses,
		"requested_commands": requested,
		"actual_events": events,
		"peaks": peaks,
		"total_exposure_queries": exposure_queries,
		"state_hash_outside_timing": final_state_hash,
		"authority_valid_outside_timing": authority_valid,
		"conservation_outside_timing": conservation,
		"resource_observation": {"initial_flux": initial_flux, "minimum_flux": minimum_flux, "final_flux": actor.flux},
		"deterministic_outcome": deterministic_outcome,
	}


func _command(world: SimWorld, timeline_tick: int, active: bool) -> SimCommand:
	var actor: PlayerState = world.player()
	var movement_phase: int = posmod(timeline_tick / 60, 2)
	var movement_y: int = -1000 if movement_phase == 0 else 1000
	var target_cell: Vector2i = PATCHES[posmod(timeline_tick / 120, PATCHES.size())]
	var target: Vector2i = HexCourt.ORIGIN + HexGrid.center(target_cell)
	var held: int = 0
	var pressed: int = 0
	if active:
		var phase: int = posmod(timeline_tick, 480)
		match phase:
			0:
				pressed = SimCommand.SPELL_PRESSED_BITS[0] # Water Bolt
			60:
				pressed = SimCommand.SPELL_PRESSED_BITS[1] # Fire Bolt
			120:
				pressed = SimCommand.SPELL_PRESSED_BITS[2] # Water Heavy
			180:
				pressed = SimCommand.SPELL_PRESSED_BITS[3] # Fire Heavy
			360:
				pressed = SimCommand.SPELL_PRESSED_BITS[6] # Water Spray
			420:
				pressed = SimCommand.SPELL_PRESSED_BITS[7] # Fire Spray
		if phase >= 240 and phase < 270:
			held = SimCommand.SPELL_HELD_BITS[4] # Water Rapid
		elif phase >= 300 and phase < 330:
			held = SimCommand.SPELL_HELD_BITS[5] # Fire Rapid
	return SimCommand.new(
		world.tick,
		actor.entity_id,
		0,
		movement_y,
		held,
		pressed,
		target.x - actor.position_x,
		target.y - actor.position_y,
		target.x,
		target.y,
	)


func _observe_input(actor: PlayerState, command: SimCommand, requested: Dictionary) -> void:
	var slot: int = command.first_pressed_spell_slot()
	var pressed: bool = slot > 0
	if slot == 0:
		slot = command.first_held_spell_slot()
	if slot == 0:
		return
	requested.total_spell_intent_ticks += 1
	requested.pressed += int(pressed)
	requested.held_rapid += int(not pressed)
	requested.pending_at_input += int(actor.pending_cast_wire_id > 0)
	requested.cooldown_at_input += int(int(actor.spell_cooldown_ticks[slot - 1]) > 0)


func _observe_events(combat_events: Array[Dictionary], observed: Dictionary) -> void:
	for event: Dictionary in combat_events:
		var kind: String = String(event.get("type", ""))
		if kind == "cast_started":
			observed.cast_started += 1
			var wire: int = int(event.get("wire_id", 0))
			var definition: Dictionary = CombatTuning.cast_definition(wire)
			var family: String = HexCourt.family(wire)
			var element: String = "water" if int(definition.get("element_wire_id", 0)) == HexCourt.WATER else "fire"
			_increment(observed.started_by_family, family)
			_increment(observed.started_by_element, element)
			_increment(observed.started_by_wire, str(wire))
		elif kind == "cast_refused":
			observed.cast_refused += 1
			_increment(observed.refusals_by_reason, String(event.get("reason", "unknown")))


func _observe_peaks(world: SimWorld, peaks: Dictionary) -> void:
	peaks.projectiles = maxi(int(peaks.projectiles), world.projectiles.size())
	if world.hex_court == null:
		return
	var inventory: Dictionary = _hex_inventory(world.hex_court)
	for key: String in inventory:
		peaks[key] = maxi(int(peaks[key]), int(inventory[key]))
	peaks.hex_casts = maxi(int(peaks.hex_casts), world.hex_court.casts.size())
	peaks.hex_pending = maxi(int(peaks.hex_pending), world.hex_court.pending.size())
	peaks.hex_products = maxi(int(peaks.hex_products), world.hex_court.products.size())


func _hex_inventory(court: HexCourt) -> Dictionary:
	var result: Dictionary = {"active_hex_cells": 0, "hex_water_layer_entries": 0, "hex_fire_layer_entries": 0, "hex_steam_layer_entries": 0}
	for cell: Vector2i in court.cells:
		var record: Dictionary = court.cells[cell]
		var water: int = (record["water"] as Dictionary).size()
		var fire: int = (record["fire"] as Dictionary).size()
		var steam: int = (record["steam"] as Dictionary).size()
		result.hex_water_layer_entries += water
		result.hex_fire_layer_entries += fire
		result.hex_steam_layer_entries += steam
		result.active_hex_cells += int(water + fire + steam > 0)
	return result


func _measure_hex_grid_microbenchmarks() -> Dictionary:
	var definitions: Array[Dictionary] = [
		{"id": "stationary", "start": Vector2i.ZERO, "end": Vector2i.ZERO, "radius": 0},
		{"id": "interior", "start": Vector2i(-8_000, 0), "end": Vector2i(8_000, 0), "radius": 0},
		{"id": "cross_edge", "start": Vector2i(31_999, 0), "end": Vector2i(32_001, 0), "radius": 0},
		{"id": "fast_path", "start": Vector2i(-512_000, -100_000), "end": Vector2i(512_000, 180_000), "radius": 17_000},
	]
	var results: Array[Dictionary] = []
	var suite_hash: HashingContext = HashingContext.new()
	suite_hash.start(HashingContext.HASH_SHA256)
	for definition: Dictionary in definitions:
		var samples: PackedInt64Array = PackedInt64Array()
		var reference_signature: String = ""
		var sweep_start: Vector2i = definition["start"]
		var sweep_end: Vector2i = definition["end"]
		var sweep_radius: int = int(definition["radius"])
		for iteration: int in range(MICRO_ITERATIONS):
			var started_us: int = Time.get_ticks_usec()
			var cells: Array[Vector2i] = HexGrid.swept_cells(sweep_start, sweep_end, sweep_radius)
			samples.append(Time.get_ticks_usec() - started_us)
			var signature: String = _cell_signature(cells)
			if iteration == 0:
				reference_signature = signature
			else:
				_check(signature == reference_signature, "%s microbenchmark result is deterministic" % String(definition.id))
			suite_hash.update((String(definition.id) + ":" + signature + "\n").to_utf8_buffer())
		var cell_count: int = reference_signature.count(";") + int(not reference_signature.is_empty())
		results.append({
			"id": definition.id,
			"iterations": MICRO_ITERATIONS,
			"start": [sweep_start.x, sweep_start.y],
			"end": [sweep_end.x, sweep_end.y],
			"radius": sweep_radius,
			"cell_count": cell_count,
			"call_us": _percentiles(samples),
			"result_sha256": reference_signature.sha256_text(),
		})
	return {"iterations_per_case": MICRO_ITERATIONS, "cases": results, "deterministic_checksum": suite_hash.finish().hex_encode()}


func _cell_signature(cells: Array[Vector2i]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for cell: Vector2i in cells:
		parts.append("%d,%d" % [cell.x, cell.y])
	return ";".join(parts)


func _percentiles(values: PackedInt64Array) -> Dictionary:
	var ordered: PackedInt64Array = values.duplicate()
	ordered.sort()
	if ordered.is_empty():
		return {"samples": 0, "p50": 0, "p95": 0, "p99": 0, "max": 0}
	return {
		"samples": ordered.size(),
		"p50": ordered[_percentile_index(ordered.size(), 50)],
		"p95": ordered[_percentile_index(ordered.size(), 95)],
		"p99": ordered[_percentile_index(ordered.size(), 99)],
		"max": ordered[-1],
	}


func _percentile_index(size: int, percentile: int) -> int:
	return clampi((size * percentile + 99) / 100 - 1, 0, size - 1)


func _increment(counts: Dictionary, key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1


func _source_hashes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in [
		"res://tests/performance/profile_hex_court.gd",
		"res://src/sim/hex/hex_grid.gd",
		"res://src/sim/hex/hex_court.gd",
		"res://src/sim/hex/hex_court_practice.gd",
		"res://src/sim/core/sim_world.gd",
		"res://src/sim/combat/combat_system.gd",
		"res://content/abilities/foundation_abilities_v1.json",
		"res://project.godot",
	]:
		result[path.trim_prefix("res://")] = FileAccess.get_sha256(path)
	return result


func _finish(output_path: String, microbenchmarks: Dictionary, results: Array[Dictionary], execution_order: Array[Dictionary]) -> void:
	var identity: Variant = JSON.parse_string(FileAccess.get_file_as_string(RuntimeBuildIdentity.MANIFEST_PATH))
	var receipt: Dictionary = {
		"schema_version": 1,
		"workload_version": "matched-hex-court-profile-v1",
		"runtime_identity": identity,
		"engine": Engine.get_version_info()["string"],
		"hardware": {"cpu": OS.get_processor_name(), "logical_processors": OS.get_processor_count(), "os": OS.get_name()},
		"settings": {
			"seed": SEED,
			"tick_rate": TICK_RATE,
			"map_dimensions_world_units": [MAP_WIDTH, MAP_HEIGHT],
			"obstacles": 0,
			"warmup_ticks_excluded": WARMUP_TICKS,
			"sample_ticks_per_variant_run": SAMPLE_TICKS,
			"repetitions_per_variant": REPETITIONS,
			"alternating_variant_order": true,
		},
		"execution_order": execution_order,
		"source_hashes": _source_hashes(),
		"microbenchmarks": microbenchmarks,
		"results": results,
		"assertions": assertions,
		"failures": failures,
		"scope": "Local headless SimWorld.step and HexGrid.swept_cells only, on one machine and process. No rendering, host snapshot, packet encoding, sockets, network transport, remote client, installer, publication or physical multiplayer claim.",
		"workload": "Matched production AbilityCatalog plus HexCourtPractice Water/Fire Bolt, Heavy, Rapid and Spray loadout. One genuine actor alternates movement toward/away while targeting the court center and fixed patches. Casts use ordinary Flux payment, cooldown, startup, recovery and capacity paths.",
		"fixture_mutation_policy": "No Flux refill, health refill, cooldown clearing, direct cast insertion, projectile seeding, retained-state eviction or resource/cap increase during warmup or measurement.",
		"timing_semantics": "Only SimWorld.step and each HexGrid.swept_cells call are timed. State hashes, conservation checks, event accounting, inventory scans, checksums and JSON construction are outside timing. Percentiles exclude the 240-tick warmup.",
		"comparison_limit": "Ordinary uses legacy continuous chemistry without HexCourt's finite matter ledger. This is a matched local simulation cost comparison, not behavioral equivalence or a networking/rendered-performance result.",
	}
	if output_path.is_empty():
		failures += 1
	else:
		var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
		_check(file != null, "profile receipt opens")
		if file != null:
			# Refresh counters after the open check so the durable receipt agrees
			# with the process exit summary.
			receipt.assertions = assertions
			receipt.failures = failures
			file.store_string(JSON.stringify(receipt, "  "))
			file.close()
	print("%s: matched-hex-court-profile; %d assertions; %d failures" % ["PASS" if failures == 0 else "FAIL", assertions, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		print("FAIL: ", message)
