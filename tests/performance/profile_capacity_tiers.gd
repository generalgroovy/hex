extends "res://tests/performance/profile_unified_wellspring.gd"
@warning_ignore_start("integer_division")

# Sim-only companion to the existing paid eight-actor fixture. A requested tier
# never changes a production cap or fabricates actors beyond the fixture.
const CAPACITY_TIERS: Array[int] = [8, 16, 32, 64]
const PAID_FIXTURE_PLAYERS := 8

var requested_tiers: Array[int] = [8, 16, 32, 64]


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--players="):
			requested_tiers.clear()
			for value: String in argument.trim_prefix("--players=").split(",", false):
				_check(value.is_valid_int() and int(value) in CAPACITY_TIERS, "requested capacity tier is 8, 16, 32 or 64")
				if value.is_valid_int() and int(value) in CAPACITY_TIERS and int(value) not in requested_tiers:
					requested_tiers.append(int(value))
		elif argument.begins_with("--ticks="):
			sample_ticks = int(argument.trim_prefix("--ticks="))
		elif argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	_check(not requested_tiers.is_empty(), "at least one capacity tier is requested")
	_check(sample_ticks in [720, 7200], "capacity sample is six or sixty simulated seconds")
	_check(output_path.begins_with("res://.godot/capacity-tiers-") and output_path.ends_with(".json") and not ".." in output_path and not FileAccess.file_exists(output_path), "capacity receipt is fresh and scoped")
	if failures > 0:
		quit(1)
		return

	var limits := _capacity_limits()
	var measured_tier_requested := false
	for tier: int in requested_tiers:
		if _capacity_blockers(tier, limits).is_empty():
			measured_tier_requested = true
	if measured_tier_requested:
		_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "capacity ability catalogue loads")
		_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "capacity champion catalogue loads")
		_check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "capacity campus loads")
		definition = HexWorldDefinition.from_campus(layout)
		_check(definition != null, "capacity campus has trusted whole-hex topology")
	if failures > 0:
		quit(1)
		return

	var tiers: Array[Dictionary] = []
	for tier: int in requested_tiers:
		var blockers := _capacity_blockers(tier, limits)
		if not blockers.is_empty():
			tiers.append({"requested_players": tier, "status": "UNSUPPORTED", "blockers": blockers, "simulated_players": 0, "runs": []})
			print("CAPACITY_TIERS players=%d status=UNSUPPORTED; no fixture created" % tier)
			continue
		var runs: Array[Dictionary] = []
		for case_name: String in CASES:
			var first := _capacity_measure(case_name, false)
			var reversed := _capacity_measure(case_name, true)
			_check(first.deterministic == reversed.deterministic, case_name + " capacity trace and counters preserve reversed command order")
			runs.append(first)
			runs.append(reversed)
		tiers.append({"requested_players": tier, "status": "MEASURED_SIM_ONLY", "simulated_players": PAID_FIXTURE_PLAYERS, "runs": runs})

	var hashes := _source_hashes()
	for path: String in ["tests/performance/profile_capacity_tiers.gd", "src/net/session_charter.gd", "src/net/session_hearth.gd", "src/net/session_round.gd", "src/net/session_snapshot.gd", "src/sim/core/sim_config.gd"]:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	var receipt := {
		"schema_version": 1, "diagnostic_version": "capacity-tiers-sim-only-v1",
		"workload_version": "unified-wellspring-profile-v1", "engine": Engine.get_version_info()["string"],
		"seed": SEED, "tick_rate": TICK_RATE, "warmup_ticks": WARMUP_TICKS, "sample_ticks": sample_ticks,
		"production_limits": limits, "tiers": tiers, "source_sha256": hashes,
		"scope": "Paid fixed eight-champion campus fixture and unchanged production SimWorld.step only. No sockets, snapshots, event-publication queue, rendering, player-cap overrides, resource refills, cooldown bypass or synthetic high-tier authority. Unsupported tiers are not simulated.",
		"timing_semantics": "Only SimWorld.step is timed. Command construction, event counters, per-tick canonical hash/trace, occupancy and invariants run outside each timer but may influence later allocation/cache behavior. No cleanup or lifetime-completion claim. Raw event counts are not published-event delivery counts.",
		"performance_acceptance": "NOT_ESTABLISHED; even a passing simulation budget is not full-frame, network, renderer, physical-client or release capacity acceptance.",
	}
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	_check(output != null, "capacity receipt opens")
	if output != null:
		receipt.assertions = assertions
		receipt.failures = failures
		output.store_string(JSON.stringify(receipt, "\t") + "\n")
		output.close()
	print("%s: capacity-tiers diagnostic; %d assertions; %d failures; output=%s; capacity_acceptance=NOT_ESTABLISHED" % ["PASS" if failures == 0 else "FAIL", assertions, failures, output_path])
	quit(1 if failures > 0 else 0)


func _capacity_limits() -> Dictionary:
	return {
		"transport": SessionTransport.MAX_PLAYERS, "charter": SessionCharter.MAX_SUPPORTED_PLAYERS,
		"default_charter": SessionCharter.maximum_players(SessionCharter.DEFAULT_ID),
		"hearth": SessionHearth.MAX_PLAYERS, "round": SessionRound.MAX_PLAYERS,
		"legacy_snapshot": SessionSnapshot.MAX_PLAYERS, "hex_snapshot": HexWorldSnapshot.MAX_PLAYERS,
		"paid_fixture": PAID_FIXTURE_PLAYERS,
	}


func _capacity_blockers(tier: int, limits: Dictionary) -> Array[String]:
	var reasons: Array[String] = []
	for label: String in limits:
		if tier > int(limits[label]):
			reasons.append("%s supports at most %d players" % [label, int(limits[label])])
	if tier != PAID_FIXTURE_PLAYERS and tier <= int(limits.paid_fixture):
		reasons.append("existing paid fixture has exactly eight actors; no smaller surrogate")
	return reasons


func _capacity_measure(case_name: String, reverse_order: bool) -> Dictionary:
	print("CAPACITY_TIERS stage=fixture case=%s reverse=%s" % [case_name, str(reverse_order)])
	var fixture := _fixture(case_name)
	var world: SimWorld = fixture.world
	var targets: Dictionary = fixture.targets
	_check(world.players.size() == PAID_FIXTURE_PLAYERS, "capacity fixture contains exactly eight real champions")
	for unused: int in range(WARMUP_TICKS):
		_check(world.step(_commands(world, targets, case_name, false, reverse_order)), "capacity neutral warmup advances")
	var times := PackedInt64Array()
	var missed := 0
	var requested_pressed := {}
	var requested_held := {}
	var events := {}
	var admitted := {}
	var refused := {}
	var released := {}
	var alive_ticks := 0
	var peaks := {"projectiles": 0, "casts": 0, "products": 0, "active_cells": 0}
	var trace := HashingContext.new()
	trace.start(HashingContext.HASH_SHA256)
	for index: int in range(sample_ticks):
		var commands := _commands(world, targets, case_name, true, reverse_order)
		_count_requested(world, commands, requested_pressed, requested_held)
		var started := Time.get_ticks_usec()
		var advanced := world.step(commands)
		var elapsed := Time.get_ticks_usec() - started
		times.append(elapsed)
		missed += int(elapsed > TICK_BUDGET_US)
		_check(advanced, "capacity paid tick advances")
		if not advanced: break
		for event: Dictionary in world.combat_events:
			var kind := String(event.get("type", "unknown"))
			var wire := str(int(event.get("wire_id", event.get("source_wire_id", 0))))
			_count_key(events, kind)
			if kind == "cast_started": _count_key(admitted, wire)
			elif kind == "cast_refused": _count_key(refused, wire + ":" + String(event.get("reason", "unknown")))
			elif kind in ["projectile_spawned", "spray_fired"]: _count_key(released, wire)
		alive_ticks += _alive_count(world)
		peaks.projectiles = maxi(int(peaks.projectiles), world.projectiles.size())
		peaks.casts = maxi(int(peaks.casts), world.hex_court.casts.size())
		peaks.products = maxi(int(peaks.products), world.hex_court.products.size())
		peaks.active_cells = maxi(int(peaks.active_cells), int(_occupancy(world.hex_court, world.tick).active_cells))
		trace.update(_trace_bytes(world))
		if (index + 1) % 120 == 0:
			print("CAPACITY_TIERS case=%s reverse=%s sample=%d/%d" % [case_name, str(reverse_order), index + 1, sample_ticks])
	_check(times.size() == sample_ticks, "capacity completes requested sample ticks")
	_check(world.hex_court.conservation_valid(), "capacity paid matter remains conserved")
	_check(int(world.hex_court.metrics.admitted) > 0 and int(world.hex_court.metrics.matter_paid) > 0, "capacity contains real paid casts")
	_check(alive_ticks == PAID_FIXTURE_PLAYERS * sample_ticks, "capacity retains eight alive actors throughout paid sample")
	return {
		"case": case_name, "reverse_command_order": reverse_order,
		"step_us": _percentiles(times), "deadline_misses_over_8333us": missed,
		"sim_budget_status": "PASS" if missed == 0 and times.size() == sample_ticks else "FAILED",
		"deterministic": {
			"case": case_name, "sample_ticks": times.size(), "alive_actor_ticks": alive_ticks,
			"requested_pressed_by_wire": requested_pressed, "requested_held_ticks_by_wire": requested_held,
			"raw_event_counts": events, "admitted_by_wire": admitted, "refused_by_wire_and_reason": refused,
			"released_by_wire": released, "peaks": peaks, "authority_metrics": world.hex_court.metrics.duplicate(true),
			"final_hash": world.state_hash(), "trace_sha256": trace.finish().hex_encode(),
		},
	}
