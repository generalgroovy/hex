extends SceneTree
## Ignored experiment: actual paid steps and separately instrumented work counts.

const ROOT := "res://.godot/iteration-20261013/trail-crowded/"
const CountedTrial = preload("res://.godot/iteration-20261013/trail-crowded/counted_world.gd")
const Trial = preload("res://.godot/iteration-20261013/trail-crowded/trial_world.gd")
const Reference = preload("res://.godot/iteration-20261013/trail-crowded/reference_emitter.gd")
const Candidate = preload("res://.godot/iteration-20261013/trail-crowded/candidate_emitter.gd")
const RefCounts = preload("res://.godot/iteration-20261013/trail-crowded/reference_instrumented.gd")
const NewCounts = preload("res://.godot/iteration-20261013/trail-crowded/candidate_instrumented.gd")
const RefLegacy = preload("res://.godot/iteration-20261013/trail-crowded/reference_legacy_controls.gd")
const NewLegacy = preload("res://.godot/iteration-20261013/trail-crowded/candidate_legacy_controls.gd")
const Packet = preload("res://src/net/hex_world_snapshot.gd")
const ORIGIN := Vector2i(700000, 700000)
const TICKS := 960
const WARMUP_TICKS := 24
const CASES: Array[String] = ["crowded_paid"]
const WATCHED: Array[String] = [
	ROOT + "compare-trail-crowded.gd", ROOT + "counted_world.gd", ROOT + "trial_world.gd", ROOT + "reference_emitter.gd", ROOT + "candidate_emitter.gd",
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

func _world(_case_name: String, emitter: Script) -> Trial:
	var counted := emitter == RefCounts or emitter == NewCounts
	var world: Trial = CountedTrial.new(120, 911, CollisionWorld.new(2400000, 1800000)) if counted else Trial.new(120, 911, CollisionWorld.new(2400000, 1800000))
	world.trial_emitter = emitter
	var court := HexChemistryWorld.new()
	_check(court.configure_geometry(ORIGIN, HexGrid.disk(Vector2i.ZERO, 24)), "Separate finite1801-cell sustained workload configures identically in each arm.")
	court.chemistry_enabled = true
	world.hex_court = court
	for index: int in 3:
		var actor: PlayerState = world.player() if index == 0 else PlayerState.new(index + 1)
		_check(champions.apply_to_player(actor, "oh_tipi"), "Ordinary finite profile applies to all three actors.")
		actor.reset_for_spawn(ORIGIN + Vector2i(0, (index - 1) * 240000))
		actor.team_id = 1
		_check(actor.place_proven_spell(0, MixtureCatalog.wire_for(2, "rapid" if index == 0 else "mantle")), "Actual ordinary unrelated Rapid and two Mantles equip before the route.")
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

func _commands(world: SimWorld, _case_name: String) -> Array[SimCommand]:
	var commands: Array[SimCommand] = []
	for actor: PlayerState in world.players:
		var wire := actor.spell_wire_id(1)
		var spell: Dictionary = CombatTuning.cast_definition_view(wire)
		# Readiness only requests ordinary inputs; authoritative admission still
		# owns capacity, payment, cooldown and the actual emitted source.
		var ready := world.tick >= 32 + (actor.entity_id - 1) * 3 and actor.pending_cast_ticks == 0 and actor.cast_recovery_ticks == 0 and actor.spell_cooldown_for_wire(wire) == 0 and actor.flux >= int(spell.flux_cost)
		var direction := 1 if posmod(world.tick - 32, 160) < 80 else -1
		var moving := world.tick >= 32
		var held := SimCommand.HELD_SPRINT if moving and posmod(world.tick - 32, 160) < 32 else 0
		commands.append(SimCommand.new(world.tick, actor.entity_id, direction * 1000 if moving else 0, 0, held, SimCommand.PRESSED_SPELL_1 if ready else 0, direction * 1000, 0, actor.position_x + direction * 300000, actor.position_y))
	return commands

func _command_rows(commands: Array[SimCommand]) -> Array[Array]:
	var rows: Array[Array] = []
	for command: SimCommand in commands:
		rows.append([command.tick, command.entity_id, command.move_x, command.move_y, command.held_actions, command.pressed_actions, command.aim_x, command.aim_y, command.aim_target_x, command.aim_target_y])
	return rows

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
	var witness := {"flight": false, "ground": false, "air_mantle": false, "trails": 0, "concurrent_two_mantles_and_rapid": 0, "late_sampled_positive": 0}
	var admissions := {1: 0, 2: 0, 3: 0}
	var attempts := {1: 0, 2: 0, 3: 0}
	var refusals: Array[Dictionary] = []
	var minimum_flux := {1: right.player(1).flux, 2: right.player(2).flux, 3: right.player(3).flux}
	var minimum_stamina := {1: right.player(1).stamina, 2: right.player(2).stamina, 3: right.player(3).stamina}
	for frame: int in TICKS:
		if not failures.is_empty(): break
		var candidate_first := (frame % 2 == 0) != reverse_order
		var order: Array = ["candidate", "reference"] if candidate_first else ["reference", "candidate"]
		var times: Dictionary = {}
		var actual_order: Array[String] = []
		var actual_commands: Dictionary = {}
		for side: String in order:
			var chosen: Trial = right if side == "candidate" else left
			var commands := _commands(chosen, case_name)
			actual_commands[side] = _command_rows(commands)
			var started := Time.get_ticks_usec() if not counted else 0
			var success := chosen.step(commands)
			var elapsed := Time.get_ticks_usec() - started if not counted else 0
			actual_order.append(side)
			times[side] = {"step_us": elapsed, "emitter_us": chosen.last_emitter_usec, "emitted": chosen.last_emitted}
			_check(success, "Ordinary paid step succeeds: %s/%s/%d: %s" % [case_name, side, frame, chosen.last_error])
		if counted and oracle != null: _check(oracle.step(_commands(oracle, case_name)), "Canonical control uses the same real command sequence.")
		_check(actual_order == order, "Actual paired call order retained.")
		_check(actual_commands.reference == actual_commands.candidate, "Every ordinary requested command is exactly paired.")
		for command_row: Array in actual_commands.candidate:
			if int(command_row[5]) != 0: attempts[int(command_row[1])] += 1
		var emitter_input: Dictionary = (right as CountedTrial).emitter_input.duplicate(true) if counted else (cases[0].rows[frame].emitter_input as Dictionary).duplicate(true)
		if counted: _check(emitter_input == (left as CountedTrial).emitter_input, "Separate counted pass observes exact paired pre-emitter conditions.")
		witness.concurrent_two_mantles_and_rapid += 1 if int(emitter_input.mantle_owners) >= 2 and int(emitter_input.unrelated_flights) > 0 else 0
		witness.late_sampled_positive += 1 if int(emitter_input.first_sampled_index) > 0 and right.last_emitted > 0 else 0
		for actor: PlayerState in right.players:
			minimum_flux[actor.entity_id] = mini(int(minimum_flux[actor.entity_id]), actor.flux)
			minimum_stamina[actor.entity_id] = mini(int(minimum_stamina[actor.entity_id]), actor.stamina)
			_check(actor.health > 0 and actor.flux >= 0 and actor.stamina >= 0, "All actors retain finite ordinary resources and survive the bounded route.")
		for event: Dictionary in right.combat_events:
			if String(event.get("type", "")) == "cast_started": admissions[int(event.entity_id)] += 1
			if String(event.get("type", "")) == "cast_refused": refusals.append({"tick":right.tick,"event":event.duplicate(true)})
		_check(left.state_hash() == right.state_hash() and left.combat_events == right.combat_events, "Every completed paid state and event sequence match.")
		if counted and oracle != null: _check(oracle.state_hash() == left.state_hash() and oracle.combat_events == left.combat_events, "Redirected reference matches unmodified canonical authority.")
		var a: Dictionary = Packet.capture(left)
		var b: Dictionary = Packet.capture(right)
		_check(not a.is_empty() and not b.is_empty() and var_to_bytes(a) == var_to_bytes(b), "Every completed strict packet is nonempty and byte-identical.")
		_check(left.hex_court.conservation_valid() and right.hex_court.conservation_valid(), "Paid ledger conserves on every completed step.")
		var completed_hash := right.state_hash()
		if not counted:
			_check(completed_hash == String(cases[0].rows[frame].state_hash) and actual_commands.candidate == cases[0].rows[frame].commands and right.last_emitted == int(cases[0].rows[frame].candidate.emitted), "Every pristine timed boundary matches the separately classified paid trajectory.")
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
		rows.append({"tick": frame, "warmup": frame < WARMUP_TICKS, "actual_order": actual_order, "reference": times.reference, "candidate": times.candidate, "flights_after_step": right.projectiles.size(), "emitter_input": emitter_input, "commands": actual_commands.candidate, "state_hash":completed_hash})
	var paid: int = right.hex_court.metrics.admitted
	_check(paid == int(admissions[1]) + int(admissions[2]) + int(admissions[3]), "Every actual paid admission is assigned to one of the three ordinary actors.")
	_check(int(attempts[1]) + int(attempts[2]) + int(attempts[3]) == paid + refusals.size(), "Every actual ordinary cast attempt has an admission or explicit refusal outcome.")
	_check(int(right.hex_court.metrics.matter_paid) == paid * 600, "Every source retains its exact finite600 matter admission.")
	for owner: int in admissions:
		_check(int(admissions[owner]) > 1, "Each ordinary actor genuinely pays multiple casts without a grant.")
		_check(int(minimum_flux[owner]) < right.player(owner).flux_maximum and int(minimum_stamina[owner]) < right.player(owner).stamina_maximum, "Movement and casting actually spend finite resources per actor.")
	_check(bool(witness.flight) and bool(witness.ground) and int(witness.trails) > 0, "Sustained paid flight, actual ground and finite trails all occur.")
	_check(int(witness.concurrent_two_mantles_and_rapid) > 0, "The actual emitter sees two distinct Mantle owners and an unrelated real flight together.")
	_check(int(witness.late_sampled_positive) > 0, "A sampled Mantle behind an earlier skipped flight actually emits through the unchanged positive path.")
	var counts: Dictionary = {}
	if counted:
		counts = {"reference": RefCounts.preparation_counts.duplicate(), "candidate": NewCounts.preparation_counts.duplicate()}
		_check(int(counts.candidate.counts) > 0 and int(counts.candidate.counts) < int(counts.reference.counts), "Sustained route retains genuine positive preparation and avoided no-op preparation.")
	else:
		_check(right.state_hash() == String(cases[0].endpoint_hash) and admissions == cases[0].admissions and witness == cases[0].witness, "Pristine timing reproduces the exact independently counted episode.")
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
	cases.append({"case": case_name, "instrumented_work_counts_only": counted, "ticks": right.tick, "court_cells": right.hex_court.cell_count(), "paid_metrics": right.hex_court.metrics.duplicate(true), "admissions": admissions, "attempts": attempts, "refusals": refusals, "minimum_flux":minimum_flux, "minimum_stamina":minimum_stamina, "paid_boundaries": paid_boundaries, "witness": witness, "preparation": counts, "summary": summary, "rows": rows, "endpoint_hash": right.state_hash()})
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
	var result := {"schema": "hex.trail-crowded-experiment.v1", "passed": failures.is_empty(), "checks": checks, "errors": failures, "reverse_initial_order": reverse_order, "correctness_only": correctness_only, "sources": sources, "cases": cases, "scope": "Ignored candidate only. Pristine emitter comparison shares current constructors and exact current SimWorld.step with one identically redirected call; a separate counter pass also compares canonical steps from a strict initial packet. One separate sustained960-tick three-actor workload uses readiness-driven ordinary input, finite resources and natural regeneration, no mid-run grants; legacy direct-emitter controls are separately prepared finite-ledger compatibility fixtures. All paid state/event/packet/conservation comparisons occur outside measured intervals. Instrumented copies count work only and contribute no timing. Native cost mode reports synchronous whole-step and nested emitter CPU; the two must not be added. First24 ticks are retained warmup, not discarded from authority. One finite960-tick episode per process/order. Pre-emitter classifications are collected only in the separate counted pass and joined to pristine timing by verified deterministic tick; positive sampled/emitted/owner-cap/late-eligible strata must be reported separately, microsecond clocks, no rendering, foreground, GPU, FPS, physical input or dominant-bottleneck claim."}
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
