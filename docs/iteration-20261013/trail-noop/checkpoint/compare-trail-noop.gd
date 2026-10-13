extends SceneTree
## Ignored experiment: actual paid steps and separately instrumented work counts.

const ROOT := "res://.godot/iteration-20261013/trail-noop/"
const Trial = preload("res://.godot/iteration-20261013/trail-noop/trial_world.gd")
const Reference = preload("res://.godot/iteration-20261013/trail-noop/reference_emitter.gd")
const Candidate = preload("res://.godot/iteration-20261013/trail-noop/candidate_emitter.gd")
const RefCounts = preload("res://.godot/iteration-20261013/trail-noop/reference_instrumented.gd")
const NewCounts = preload("res://.godot/iteration-20261013/trail-noop/candidate_instrumented.gd")
const RefLegacy = preload("res://.godot/iteration-20261013/trail-noop/reference_legacy_controls.gd")
const NewLegacy = preload("res://.godot/iteration-20261013/trail-noop/candidate_legacy_controls.gd")
const Packet = preload("res://src/net/hex_world_snapshot.gd")
const ORIGIN := Vector2i(700000, 700000)
const TICKS := 240
const WARMUP_TICKS := 24
const CASES: Array[String] = ["empty", "fire_bolt", "fire_rapid", "fire_heavy", "mantle_ground", "mantle_air", "mixed_late_eligible"]
const WATCHED: Array[String] = [
	ROOT + "compare-trail-noop.gd", ROOT + "trial_world.gd", ROOT + "reference_emitter.gd", ROOT + "candidate_emitter.gd",
	ROOT + "reference_instrumented.gd", ROOT + "candidate_instrumented.gd", ROOT + "reference_legacy_controls.gd", ROOT + "candidate_legacy_controls.gd",
	ROOT + "before/hex_trail_emitter.gd", ROOT + "before/sim_world.gd", ROOT + "before/test_hex_trail_emitter.gd",
	"res://src/sim/hex/hex_trail_emitter.gd", "res://src/sim/core/sim_world.gd", "res://src/sim/core/sim_config.gd",
	"res://src/sim/hex/hex_chemistry_world.gd", "res://src/sim/hex/hex_cast_parts.gd", "res://src/sim/hex/hex_projectile_combat.gd",
	"res://src/sim/combat/combat_system.gd", "res://src/sim/movement/movement_system.gd", "res://src/net/hex_world_snapshot.gd",
	"res://content/abilities/foundation_abilities_v1.json", "res://content/champions/foundation_champions_v1.json",
]
var abilities := AbilityCatalog.new()
var champions := ChampionCatalog.new()
var failures: Array[String] = []
var checks := 0
var cases: Array[Dictionary] = []
var sources: Dictionary = {}
var output := ""
var output_authorized := false
var reverse_order := false
var correctness_only := false

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok

func _option(key: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(key + "="): return arg.substr(key.length() + 1)
	return ""

func _run() -> void:
	output = _option("--output")
	reverse_order = OS.get_cmdline_user_args().has("--reverse-order")
	correctness_only = OS.get_cmdline_user_args().has("--correctness-only")
	if not _check(output.get_base_dir() == ROOT + "runs" and output.get_file().begins_with("probe-") and output.get_file().ends_with(".json") and output.get_file().is_valid_filename() and not ".." in output and not FileAccess.file_exists(output) and not DirAccess.dir_exists_absolute(output), "Fresh exact owned probe output required."): quit(1); return
	if not _check(DirAccess.make_dir_recursive_absolute(output.get_base_dir()) == OK, "Owned output directory creates."): quit(1); return
	output_authorized = true
	if not _check(correctness_only or DisplayServer.get_name() != "headless", "Cost mode requires native engine; no rendering/FPS claim."): _finish(); return
	for path: String in WATCHED:
		if not _check(FileAccess.file_exists(path), "Missing watched file: " + path): _finish(); return
		sources[path] = FileAccess.get_sha256(path)
	if not _check(sources[ROOT + "before/hex_trail_emitter.gd"] == "ce4e45d9ce1bb00712f9f37a0c694b1c68e9dbdb539aa957702d3ae4d92101db", "Exact emitter predecessor drift."): _finish(); return
	if not _check(sources[ROOT + "before/sim_world.gd"] == "2a8e32069c800d70644f222d4ce1e2378e3b2c79991e7e5d58b4de2df4548a1e", "Exact current step predecessor drift."): _finish(); return
	if not _check(sources["res://src/sim/hex/hex_trail_emitter.gd"] == sources[ROOT + "before/hex_trail_emitter.gd"] and sources["res://src/sim/core/sim_world.gd"] == sources[ROOT + "before/sim_world.gd"], "Canonical sources must remain the frozen predecessor."): _finish(); return
	_verify_transforms()
	if not failures.is_empty(): _finish(); return
	if not _check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "Ability catalog loads."): _finish(); return
	if not _check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "Champion catalog loads."): _finish(); return
	# These are existing prepared finite-ledger compatibility controls. They are
	# separate from the ordinary paid routes below, not presented as player inputs.
	var old_suite := RefLegacy.new()
	var new_suite := NewLegacy.new()
	_check(old_suite.run() == 0 and new_suite.run() == 0, "Both unchanged legacy control suites pass.")
	_check(old_suite.assertions == new_suite.assertions, "Prepared compatibility coverage remains equal.")
	_direct_skipped_control()
	if not failures.is_empty(): _finish(); return
	for case_name: String in CASES:
		_run_case(case_name, true)
		if not failures.is_empty(): _finish(); return
		if not correctness_only: _run_case(case_name, false)
		if not failures.is_empty(): _finish(); return
		await process_frame
	_finish()

func _verify_transforms() -> void:
	var before := FileAccess.get_file_as_string(ROOT + "before/hex_trail_emitter.gd").replace("\r\n", "\n").replace("class_name HexTrailEmitter\n", "")
	_check(FileAccess.get_file_as_string(ROOT + "reference_emitter.gd") == before, "Reference differs only by removed global class registration.")
	var candidate := FileAccess.get_file_as_string(ROOT + "candidate_emitter.gd")
	var marker := candidate.find("\n\n\n## Ignored preflight:")
	var gate := "\tif not _has_sample_candidate(world, only_family):\n\t\treturn 0\n"
	_check(marker >= 0 and candidate.substr(0, marker).strip_edges() == before.replace("\tvar counts := _live_trail_counts(authority, world.tick)", gate + "\tvar counts := _live_trail_counts(authority, world.tick)").strip_edges(), "Candidate positive body is byte-identical apart from the preflight gate.")
	var original_world := FileAccess.get_file_as_string(ROOT + "before/sim_world.gd").replace("\r\n", "\n")
	var start := original_world.find("func step(commands: Array[SimCommand]) -> bool:")
	var stop := original_world.find("\n\n\nfunc available_cast_capacity", start)
	var trial := FileAccess.get_file_as_string(ROOT + "trial_world.gd")
	var trial_start := trial.find("func step(commands: Array[SimCommand]) -> bool:")
	_check(start >= 0 and stop > start and trial_start >= 0, "Exact step boundaries exist.")
	if start >= 0 and stop > start and trial_start >= 0:
		_check(trial.substr(trial_start).strip_edges() == original_world.substr(start, stop - start).replace("HexTrailEmitter.emit(self,\"mantle\")", "_trial_emit()").strip_edges(), "Only one trail dispatch is redirected in the current step body.")
	for side: String in ["reference", "candidate"]:
		var expected := FileAccess.get_file_as_string(ROOT + side + "_emitter.gd")
		expected = expected.replace("extends RefCounted\n", "extends RefCounted\n\nstatic var preparation_counts := {\"emit\": 0, \"counts\": 0, \"parts\": 0, \"sort\": 0, \"preflight\": 0}\n")
		expected = expected.replace("static func emit(world: SimWorld, only_family: String = \"\") -> int:\n", "static func emit(world: SimWorld, only_family: String = \"\") -> int:\n\tpreparation_counts.emit += 1\n")
		expected = expected.replace("\tvar ordered: Array[ProjectileState] = world.projectiles.duplicate()", "\tpreparation_counts.sort += 1\n\tvar ordered: Array[ProjectileState] = world.projectiles.duplicate()")
		expected = expected.replace("static func _live_trail_counts(authority: HexChemistryWorld, tick: int) -> Dictionary:\n", "static func _live_trail_counts(authority: HexChemistryWorld, tick: int) -> Dictionary:\n\tpreparation_counts.counts += 1\n")
		expected = expected.replace("\t\tfor part_value: Variant in record.get(\"ground_parts\", {}).values():\n", "\t\tfor part_value: Variant in record.get(\"ground_parts\", {}).values():\n\t\t\tpreparation_counts.parts += 1\n")
		expected = expected.replace("\tfor projectile: ProjectileState in world.projectiles:\n", "\tfor projectile: ProjectileState in world.projectiles:\n\t\tpreparation_counts.preflight += 1\n")
		_check(FileAccess.get_file_as_string(ROOT + side + "_instrumented.gd") == expected, "Work-count copy has only declared counter insertions: " + side)
		var legacy := FileAccess.get_file_as_string(ROOT + "before/test_hex_trail_emitter.gd").replace("\r\n", "\n").replace("res://src/sim/hex/hex_trail_emitter.gd", ROOT + side + "_emitter.gd")
		_check(FileAccess.get_file_as_string(ROOT + side + "_legacy_controls.gd") == legacy, "All original direct-emitter assertions retained: " + side)

func _world(case_name: String, emitter: Script) -> Trial:
	var world := Trial.new(120, 911, CollisionWorld.new(2400000, 1800000))
	world.trial_emitter = emitter
	var court := HexChemistryWorld.new()
	_check(court.configure_geometry(ORIGIN, HexGrid.disk(Vector2i.ZERO, 24)), "Finite1801-cell paid topology contains the ordinary moving route.")
	court.chemistry_enabled = true
	world.hex_court = court
	var count := 2 if case_name == "mixed_late_eligible" else 1
	for index: int in count:
		var actor: PlayerState = world.player() if index == 0 else PlayerState.new(index + 1)
		_check(champions.apply_to_player(actor, "oh_tipi"), "Ordinary finite profile applies.")
		actor.reset_for_spawn(ORIGIN + Vector2i(0, index * 240000))
		actor.team_id = 1
		var family := "mantle" if case_name.begins_with("mantle") or index == 1 else "heavy" if case_name == "fire_heavy" else "rapid" if case_name == "fire_rapid" else "bolt"
		_check(actor.place_proven_spell(0, MixtureCatalog.wire_for(2, family)), "Actual supported paid spell equips.")
		if index > 0: world.players.append(actor)
	return world

func _direct_skipped_control() -> void:
	# Explicit compatibility fixture, not an ordinary player-paid route: the
	# existing helper funds legal finite records directly. A skipped earlier
	# Rapid must not hide a later sampled Heavy when only_family is empty.
	var factory := RefLegacy.new()
	var left: SimWorld = factory._world()
	var right: SimWorld = factory._world()
	for world: SimWorld in [left, right]:
		var center: Vector2i = world.hex_court.origin + HexGrid.center(Vector2i.ZERO)
		factory._bind_shot(world, 6000, 1, 180, center)
		factory._bind_shot(world, 6008, 1, 179, center)
	_check(factory.failures == 0, "Direct skipped-source fixture funds both legal records.")
	_check(Reference.emit(left) == 1 and Candidate.emit(right) == 1, "An earlier ineligible Rapid does not suppress a later eligible Heavy.")
	_check(left.hex_court.state_hash() == right.hex_court.state_hash() and left.hex_court.casts == right.hex_court.casts and left.hex_court.metrics == right.hex_court.metrics and left.hex_court.next_ground_part_id == right.hex_court.next_ground_part_id, "Direct skipped control preserves exact parts, counters and IDs.")
	_check(left.hex_court.conservation_valid() and right.hex_court.conservation_valid(), "Direct skipped control retains finite stock.")

func _commands(world: SimWorld, case_name: String) -> Array[SimCommand]:
	var commands: Array[SimCommand] = []
	for actor: PlayerState in world.players:
		# The actual cast begins after the declared idle warmup so fast flight is
		# retained in measured rows rather than disappearing into warmup.
		var pressed := SimCommand.PRESSED_SPELL_1 if world.tick == 32 and case_name != "empty" else 0
		if world.tick == 32 and case_name == "mantle_air": pressed |= SimCommand.PRESSED_JUMP
		var moving := world.tick < 96
		# An ordinary cursor300px ahead is captured only by actual admission.
		# The release still owns startup motion, muzzle and authored range clamps.
		commands.append(SimCommand.new(world.tick, actor.entity_id, 1000 if moving else 0, 0, SimCommand.HELD_SPRINT if moving else 0, pressed, 1000, 0, actor.position_x + 300000, actor.position_y))
	return commands

func _run_case(case_name: String, counted: bool) -> void:
	var left := _world(case_name, RefCounts if counted else Reference)
	var right := _world(case_name, NewCounts if counted else Candidate)
	var oracle: SimWorld = null
	if counted:
		# The unmodified canonical step is a third independent dispatch control.
		var prepared := Packet.capture(left)
		oracle = Packet.prepare(prepared, left)
		_check(oracle != null and oracle.state_hash() == left.state_hash(), "Canonical control restores the exact strict initial paid-route state.")
		RefCounts.preparation_counts = {"emit": 0, "counts": 0, "parts": 0, "sort": 0, "preflight": 0}
		NewCounts.preparation_counts = {"emit": 0, "counts": 0, "parts": 0, "sort": 0, "preflight": 0}
	else:
		left.measure_emitter = true
		right.measure_emitter = true
	var rows: Array[Dictionary] = []
	var paid_boundaries: Array[Dictionary] = []
	var witness := {"flight": false, "ground": false, "air_mantle": false, "trails": 0}
	for frame: int in TICKS:
		if not failures.is_empty(): break
		var candidate_first := (frame % 2 == 0) != reverse_order
		var order: Array = ["candidate", "reference"] if candidate_first else ["reference", "candidate"]
		var times: Dictionary = {}
		var actual_order: Array[String] = []
		for side: String in order:
			var chosen: Trial = right if side == "candidate" else left
			var commands := _commands(chosen, case_name)
			var started := Time.get_ticks_usec() if not counted else 0
			var success := chosen.step(commands)
			var elapsed := Time.get_ticks_usec() - started if not counted else 0
			actual_order.append(side)
			times[side] = {"step_us": elapsed, "emitter_us": chosen.last_emitter_usec, "emitted": chosen.last_emitted}
			_check(success, "Ordinary paid step succeeds: %s/%s/%d: %s" % [case_name, side, frame, chosen.last_error])
		if counted and oracle != null: _check(oracle.step(_commands(oracle, case_name)), "Canonical control uses the same real command sequence.")
		_check(actual_order == order, "Actual paired call order retained.")
		_check(left.state_hash() == right.state_hash() and left.combat_events == right.combat_events, "Every completed paid state and event sequence match.")
		if counted and oracle != null: _check(oracle.state_hash() == left.state_hash() and oracle.combat_events == left.combat_events, "Redirected reference matches unmodified canonical authority.")
		var a: Dictionary = Packet.capture(left)
		var b: Dictionary = Packet.capture(right)
		_check(not a.is_empty() and not b.is_empty() and var_to_bytes(a) == var_to_bytes(b), "Every completed strict packet is nonempty and byte-identical.")
		_check(left.hex_court.conservation_valid() and right.hex_court.conservation_valid(), "Paid ledger conserves on every completed step.")
		# Compact arrival evidence is collected after all measured calls. The
		# positions below are the completed-step state, not inferred muzzle data.
		for event: Dictionary in right.combat_events:
			var kind := String(event.get("type", ""))
			if kind not in ["cast_started", "projectile_spawned"]: continue
			var owner_id := int(event.get("entity_id", event.get("owner_id", 0)))
			var actor: PlayerState = right.player(owner_id)
			if actor == null: continue
			var live_flights: Array[Dictionary] = []
			for shot: ProjectileState in right.projectiles:
				if shot.owner_id == owner_id:
					live_flights.append({"id": shot.entity_id, "position": [shot.position_x, shot.position_y], "remaining_distance": shot.remaining_distance})
			paid_boundaries.append({"tick": right.tick, "event": event.duplicate(true), "actor_end_position": [actor.position_x, actor.position_y],
				"locked_cursor_after_step": [actor.pending_cast_target_x, actor.pending_cast_target_y], "live_flights_after_step": live_flights})
		witness.flight = bool(witness.flight) or not right.projectiles.is_empty()
		witness.ground = bool(witness.ground) or not right.hex_court.occupied_cells().is_empty()
		witness.trails = int(witness.trails) + int(right.last_emitted)
		for shot: ProjectileState in right.projectiles:
			if HexChemistryWorld.family(shot.source_wire_id) == "mantle" and right.player(shot.owner_id).air_height > 0: witness.air_mantle = true
		rows.append({"tick": frame, "warmup": frame < WARMUP_TICKS, "actual_order": actual_order, "reference": times.reference, "candidate": times.candidate, "flights_after_step": right.projectiles.size()})
	var paid: int = right.hex_court.metrics.admitted
	_check(paid == (0 if case_name == "empty" else 2 if case_name == "mixed_late_eligible" else 1), "Each ordinary route has exactly its intended paid admissions.")
	_check(int(right.hex_court.metrics.matter_paid) == paid * 600, "Actual matter admission is finite and exact.")
	if case_name != "empty": _check(bool(witness.flight) and bool(witness.ground), "Real paid flight and ground both occur.")
	if case_name in ["mantle_ground", "mantle_air", "mixed_late_eligible"]: _check(int(witness.trails) > 0, "Positive Mantle path genuinely emits finite trails.")
	if case_name == "mantle_air": _check(bool(witness.air_mantle), "Ordinary jump genuinely suppresses airborne Mantle trail eligibility.")
	var counts: Dictionary = {}
	if counted:
		counts = {"reference": RefCounts.preparation_counts.duplicate(), "candidate": NewCounts.preparation_counts.duplicate()}
		if case_name.begins_with("fire_"):
			_check(int(counts.reference.counts) > 0 and int(counts.candidate.counts) == 0 and int(counts.candidate.sort) == 0, "Actual non-Mantle flight skips all candidate preparation.")
		if case_name in ["mantle_ground", "mantle_air", "mixed_late_eligible"]:
			_check(int(counts.candidate.counts) > 0 and int(counts.candidate.counts) < int(counts.reference.counts), "Positive sampled path retained while unsampled preparation falls.")
	var summary: Dictionary = {}
	if not counted:
		for field: String in ["step_us", "emitter_us"]:
			var old_values: Array[float] = []
			var new_values: Array[float] = []
			var deltas: Array[float] = []
			for row: Dictionary in rows:
				if row.warmup: continue
				old_values.append(float(row.reference[field]))
				new_values.append(float(row.candidate[field]))
				deltas.append(float(row.candidate[field]) - float(row.reference[field]))
			summary[field] = {"reference": _stats(old_values), "candidate": _stats(new_values), "paired_delta": _stats(deltas)}
	cases.append({"case": case_name, "instrumented_work_counts_only": counted, "ticks": right.tick, "court_cells": right.hex_court.cell_count(), "paid_metrics": right.hex_court.metrics.duplicate(true), "paid_boundaries": paid_boundaries, "witness": witness, "preparation": counts, "summary": summary, "rows": rows, "endpoint_hash": right.state_hash()})
	print("TRAIL PROBE ", case_name, " counted=", counted, " paid=", paid, " trails=", witness.trails)

func _stats(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {"count": 0}
	var ordered: Array[float] = values.duplicate()
	ordered.sort()
	var total := 0.0
	for value: float in values: total += value
	var middle := floori(float(ordered.size()) / 2.0)
	var median: float = ordered[middle] if ordered.size() % 2 == 1 else (ordered[middle - 1] + ordered[middle]) / 2.0
	return {"count": values.size(), "mean": total / values.size(), "median": median, "p95": ordered[ceili(ordered.size() * 0.95) - 1], "min": ordered.front(), "max": ordered.back()}

func _finish() -> void:
	for path: String in sources: _check(FileAccess.get_sha256(path) == sources[path], "Watched source remained unchanged: " + path)
	var result := {"schema": "hex.trail-noop-experiment.v1", "passed": failures.is_empty(), "checks": checks, "errors": failures, "reverse_initial_order": reverse_order, "correctness_only": correctness_only, "sources": sources, "cases": cases, "scope": "Ignored candidate only. Pristine emitter comparison shares current constructors and exact current SimWorld.step with one identically redirected call; a separate counter pass also compares canonical steps from a strict initial packet. Actual ordinary finite one-cast routes have no mid-run grants; legacy direct-emitter controls are separately prepared finite-ledger compatibility fixtures. All paid state/event/packet/conservation comparisons occur outside measured intervals. Instrumented copies count work only and contribute no timing. Native cost mode reports synchronous whole-step and nested emitter CPU; the two must not be added. First24 ticks are retained warmup, not discarded from authority. One finite240-tick episode per case/order, microsecond clocks, no rendering, foreground, GPU, FPS, physical input or dominant-bottleneck claim."}
	if output_authorized:
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file == null: print("FAIL: Unable to write trial receipt"); quit(1); return
		file.store_string(JSON.stringify(result, "\t") + "\n")
		file.close()
		var readback: Variant = JSON.parse_string(FileAccess.get_file_as_string(output))
		if not readback is Dictionary or bool(readback.get("passed", true)) != failures.is_empty() or int(readback.get("checks", -1)) != checks: print("FAIL: Receipt readback mismatch"); quit(1); return
	for failure: String in failures: print("FAIL: ", failure)
	print("TRAIL PROBE COMPLETE checks=", checks, " failures=", failures.size(), " cases=", cases.size())
	quit(0 if failures.is_empty() else 1)
