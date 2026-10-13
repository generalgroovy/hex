extends "res://scripts/profile-gameplay.gd"
## Isolated native CPU comparison. No rendering, GPU, foreground or FPS claim.

const PreviousProfile = preload("res://.godot/iteration-20261013/T7-before/scripts/profile-gameplay.gd")
const CurrentProfile = preload("res://scripts/profile-gameplay.gd")
const PreviousStep = preload("res://.godot/iteration-20261013/t7-cost/reference_step.gd")
const Packet = preload("res://src/net/hex_world_snapshot.gd")
const BEFORE_WORLD := "res://.godot/iteration-20261013/T7-before/src/sim/core/sim_world.gd"
const BEFORE_PROFILE := "res://.godot/iteration-20261013/T7-before/scripts/profile-gameplay.gd"
const REFERENCE_STEP := "res://.godot/iteration-20261013/t7-cost/reference_step.gd"
const SELF := "res://.godot/iteration-20261013/t7-cost/compare-completed-stages.gd"
const ORIGIN := Vector2i(600000, 500000)
const CYCLES := 66
const WARMUPS := 2
const STEP_COUNTS: Array[int] = [0, 1, 8]
const WATCHED: Array[String] = [SELF, REFERENCE_STEP, BEFORE_WORLD, BEFORE_PROFILE,
	"res://src/sim/core/sim_world.gd", "res://scripts/profile-gameplay.gd",
	"res://src/app/bootstrap.gd", "res://src/net/hex_world_snapshot.gd",
	"res://src/presentation/cast_startup_witness.gd", "res://src/sim/entities/player_state.gd",
	"res://src/sim/core/sim_config.gd", "res://src/sim/core/action_transition_policy.gd",
	"res://src/content/ability_catalog.gd", "res://src/content/champion_catalog.gd",
	"res://src/sim/hex/hex_chemistry_world.gd", "res://src/sim/hex/hex_projectile_combat.gd",
	"res://src/sim/combat/combat_system.gd", "res://src/sim/movement/movement_system.gd",
	"res://content/abilities/foundation_abilities_v1.json", "res://content/champions/foundation_champions_v1.json"]

class PreviousGame extends PreviousProfile.TimedGame:
	func _ready() -> void: set_process(false)
	func _draw() -> void: pass
	func _prepare_terrain_frame() -> void: terrain_loading = false
	func _advance_player_camera(_delta: float, _blocked: bool) -> void: pass

class CurrentGame extends CurrentProfile.TimedGame:
	func _ready() -> void: set_process(false)
	func _draw() -> void: pass
	func _prepare_terrain_frame() -> void: terrain_loading = false
	func _advance_player_camera(_delta: float, _blocked: bool) -> void: pass

class NoSave extends PlayerPreferences:
	var saves := 0
	func save_to_file(_path: String = DEFAULT_PATH) -> bool:
		saves += 1
		return true

var t7_abilities := AbilityCatalog.new()
var t7_champions := ChampionCatalog.new()
var t7_errors: Array[String] = []
var t7_cases: Array[Dictionary] = []
var t7_sources: Dictionary = {}
var t7_output := ""
var t7_reverse := false
var t7_assertions := 0
var t7_serial := 0
var t7_mouse_mode := Input.MOUSE_MODE_VISIBLE

func _initialize() -> void:
	_t7_run.call_deferred()

func _finalize() -> void:
	if is_instance_valid(game): game.end_completed_stage_case()

func _t7_check(value: bool, message: String) -> bool:
	t7_assertions += 1
	if not value: t7_errors.append(message)
	return value

func _t7_run() -> void:
	t7_output = _option("--t7-output")
	t7_reverse = OS.get_cmdline_user_args().has("--t7-reverse")
	if not _t7_check(not t7_output.is_empty(), "Explicit fresh output path required."): _t7_finish(); return
	if not _t7_check(not FileAccess.file_exists(t7_output), "Output must not overwrite prior evidence."): quit(1); return
	if not _t7_check(DisplayServer.get_name() != "headless", "Run this isolated helper with a native window; functional headless proof is separate."): _t7_finish(); return
	if not _t7_check(FileAccess.get_sha256(BEFORE_WORLD) == "9c10e37bed4261e4f44a85c5c31017550246a266450e8722dda12c32bb37aee6", "Predecessor world drift."): _t7_finish(); return
	if not _t7_check(FileAccess.get_sha256(BEFORE_PROFILE) == "fcd56f52e0b0926527f9f57d5bca347624570a0743579b9b7944802a95f35af0", "Predecessor profiler drift."): _t7_finish(); return
	var old_text := FileAccess.get_file_as_string(BEFORE_WORLD).replace("\r\n", "\n")
	var start := old_text.find("func step(commands: Array[SimCommand]) -> bool:")
	var stop := old_text.find("\n\n\nfunc available_cast_capacity", start)
	if not _t7_check(start >= 0 and stop > start, "Original step boundaries missing."): _t7_finish(); return
	var expected := "extends SimWorld\n\n" + old_text.substr(start, stop - start) + "\n"
	if not _t7_check(FileAccess.get_file_as_string(REFERENCE_STEP) == expected, "Reference must be the exact predecessor step body with only an extends header."): _t7_finish(); return
	for path: String in WATCHED:
		if not _t7_check(FileAccess.file_exists(path), "Missing watched dependency: " + path): _t7_finish(); return
		t7_sources[path] = FileAccess.get_sha256(path)
	if not _t7_check(t7_abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "Ability catalog failed."): _t7_finish(); return
	if not _t7_check(t7_champions.load_from_file("res://content/champions/foundation_champions_v1.json", t7_abilities), "Champion catalog failed."): _t7_finish(); return
	InputRouter.ensure_input_map()
	t7_mouse_mode = Input.mouse_mode
	root.size = Vector2i(1280, 720)
	for contrast: String in ["default_step", "light_observer", "full_legacy", "full_cumulative"]:
		for workload: String in ["idle", "paid_fire", "paid_mantle"]:
			await _t7_case(contrast, workload)
			if not t7_errors.is_empty(): _t7_finish(); return
	_t7_failed_cleanup()
	_t7_finish()

func _t7_world(previous: bool, workload: String) -> SimWorld:
	var collision := CollisionWorld.new(2000000, 2000000)
	# Ordinary impact at an authored-distance static wall keeps the finite paid
	# deposit inside this bounded native fixture's actual Hex geometry.
	collision.add_obstacle(CollisionWorld.Obstacle.new(1, ORIGIN.x + 180000, ORIGIN.y - 300000, ORIGIN.x + 196000, ORIGIN.y + 300000, false))
	var world: SimWorld = PreviousStep.new(120, 2718, collision) if previous else SimWorld.new(120, 2718, collision)
	var court := HexChemistryWorld.new()
	_t7_check(court.configure_geometry(ORIGIN, HexGrid.disk(Vector2i.ZERO, 8)), "Finite Hex geometry must configure.")
	court.chemistry_enabled = true
	world.hex_court = court
	_t7_check(t7_champions.apply_to_player(world.player(), "oh_tipi"), "Ordinary champion resources required.")
	world.player().reset_for_spawn(ORIGIN)
	world.player().spawn_protection_ticks = 0
	var wire := MixtureCatalog.wire_for(63, "mantle") if workload == "paid_mantle" else MixtureCatalog.wire_for(2, "bolt")
	_t7_check(world.player().place_proven_spell(0, wire), "Ordinary finite spell slot must equip.")
	return world

func _t7_node(world: SimWorld, previous: bool, mode: String, workload: String) -> Variant:
	var node: Variant = PreviousGame.new() if previous else CurrentGame.new()
	node.preference_overrides_are_transient = true
	node.world = world
	node.input_router = InputRouter.new(1)
	node.player_preferences = NoSave.new()
	node.session_steward = SessionSteward.new()
	node.campus_layout = SanctumCampusLayout.new()
	node.ability_catalog = t7_abilities
	node.champion_catalog = t7_champions
	node.authoritative_session = AuthoritativeSession.new()
	_t7_check(node.authoritative_session.bind(world, t7_champions, Vector2i(600, 500), "T7 Host"), "Fixture session binding failed.")
	node.session_transport = SessionTransport.new()
	node.observation_budget = PreviousProfile.ObservationBudget.new() if previous else ObservationBudget.new()
	node.light_observer = mode == "light_observer"
	if not previous: node.all_fixed_steps = mode == "full_cumulative"
	node.recording = true
	node.casting = workload != "idle"
	node.sustained = true
	root.add_child(node)
	node.expected_window_size = node.get_window().size
	return node

func _t7_case(contrast: String, workload: String) -> void:
	var left := _t7_world(contrast != "full_cumulative", workload)
	var right := _t7_world(false, workload)
	var profile_existing := contrast in ["full_legacy", "full_cumulative"]
	left.profile_enabled = profile_existing
	right.profile_enabled = profile_existing
	var a: Variant = null
	var b: Variant = null
	var begin_left_us := 0
	var begin_right_us := 0
	if contrast != "default_step":
		a = _t7_node(left, contrast != "full_cumulative", "full_legacy" if contrast == "full_cumulative" else contrast, workload)
		b = _t7_node(right, false, contrast, workload)
		if contrast == "full_cumulative":
			var begin_started := Time.get_ticks_usec()
			var begin_ok: bool = a.begin_completed_stage_case()
			begin_left_us = Time.get_ticks_usec() - begin_started
			_t7_check(begin_ok, "Unrequested case setup should succeed.")
			begin_started = Time.get_ticks_usec()
			begin_ok = b.begin_completed_stage_case()
			begin_right_us = Time.get_ticks_usec() - begin_started
			_t7_check(begin_ok, "Requested case must begin accumulation.")
	var rows: Array[Dictionary] = []
	var witness := {"flight": false, "ground": false, "active_products": false, "max_paid_cells": 0}
	var boundary_hash := ""
	for cycle: int in CYCLES:
		for count: int in STEP_COUNTS:
			await process_frame
			var before_tick := left.tick
			if not _t7_check(right.tick == before_tick, "Paired worlds must start at the same tick."): break
			var candidate_first: bool = ((cycle * STEP_COUNTS.size() + STEP_COUNTS.find(count)) % 2 == 0) != t7_reverse
			var orders: Array = ["candidate", "reference"] if candidate_first else ["reference", "candidate"]
			var observed: Array[String] = []
			var times: Dictionary = {}
			for side: String in orders:
				observed.append(side)
				t7_serial += 1
				var chosen: SimWorld = right if side == "candidate" else left
				var node: Variant = b if side == "candidate" else a
				var started := Time.get_ticks_usec()
				var success := true
				if contrast == "default_step":
					for unused: int in count:
						var pressed := SimCommand.PRESSED_SPELL_1 if workload != "idle" and chosen.tick % 120 == 0 else 0
						var commands: Array[SimCommand] = [SimCommand.new(chosen.tick, 1, 0, 0, 0, pressed, 1000, 0)]
						if not chosen.step(commands): success = false; break
				else:
					node._process(0.0 if count == 0 else 1.0 / 120.0 if count == 1 else 0.1)
				var whole_us := Time.get_ticks_usec() - started
				var inner_us := whole_us if contrast == "default_step" else roundi(float(node.process_ms.back()) * 1000.0)
				times[side] = {"whole_call_us": whole_us, "inner_process_us": inner_us, "outside_inner_us": whole_us - inner_us, "invocation_serial": t7_serial}
				_t7_check(success and chosen.last_error.is_empty(), "Ordinary measured step failed: " + chosen.last_error)
				_t7_check(chosen.tick - before_tick == count, "Actual controlled group must complete its declared0/1/8 steps.")
				_t7_check(whole_us >= inner_us, "Whole observer clock must enclose the process clock.")
			_t7_check(observed == orders, "Actual invocation order must match paired order.")
			boundary_hash = left.state_hash()
			_t7_check(right.state_hash() == boundary_hash, "Complete authority must match after every process group.")
			_t7_check(right.combat_events == left.combat_events, "Process-boundary combat event order must match.")
			var packet_a: Dictionary = Packet.capture(left)
			var packet_b: Dictionary = Packet.capture(right)
			_t7_check(not packet_a.is_empty() and not packet_b.is_empty() and var_to_bytes(packet_a) == var_to_bytes(packet_b), "Exact current packets must match outside clocks.")
			_t7_check(left.hex_court.conservation_valid() and right.hex_court.conservation_valid(), "Finite paid authority must conserve matter.")
			var cells: int = right.hex_court.occupied_cells().size()
			witness.flight = bool(witness.flight) or not right.projectiles.is_empty()
			witness.ground = bool(witness.ground) or cells > 0
			witness.active_products = bool(witness.active_products) or not right.hex_court.products.is_empty()
			witness.max_paid_cells = maxi(int(witness.max_paid_cells), cells)
			if contrast == "full_cumulative":
				var last: Dictionary = b.all_fixed_step_samples.back()
				_t7_check(bool(last.delta.valid) and int(last.delta.completed_steps) == count, "Actual cumulative row must account for this group.")
			else:
				_t7_check(not bool(right.profile_cumulative_snapshot().enabled) and int(right.profile_cumulative_snapshot().attempted_steps) == 0, "Default/light/unrequested modes must not collect new counters.")
			rows.append({"cycle": cycle, "steps": count, "warmup": cycle < WARMUPS, "candidate_first": candidate_first, "actual_order": observed, "tick_before": before_tick, "tick_after": right.tick, "reference": times.reference, "candidate": times.candidate})
			if not t7_errors.is_empty(): break
		if not t7_errors.is_empty(): break
	var endpoints: Dictionary = {"case_begin_reference_us": begin_left_us, "case_begin_candidate_us": begin_right_us}
	if contrast == "full_cumulative":
		game = b as TimedGame
		capture = {"tick_before": 0}
		var endpoint_started := Time.get_ticks_usec()
		var stage_summary: Dictionary = _completed_stage_summary()
		endpoints.completed_summary_us = Time.get_ticks_usec() - endpoint_started
		_t7_check(bool(stage_summary.valid), "Actual production endpoint summary must admit every process group.")
		endpoint_started = Time.get_ticks_usec()
		var raw_copy: Array[Dictionary] = game.all_fixed_step_samples.duplicate(true)
		endpoints.raw_deep_copy_us = Time.get_ticks_usec() - endpoint_started
		endpoint_started = Time.get_ticks_usec()
		var raw_json := JSON.stringify({"summary": stage_summary, "raw": raw_copy})
		endpoints.raw_json_serialize_us = Time.get_ticks_usec() - endpoint_started
		endpoints.raw_json_bytes = raw_json.to_utf8_buffer().size()
		endpoints.raw_records = raw_copy.size()
		endpoints.stage_summary = stage_summary
		b.end_completed_stage_case()
		_t7_check(not bool(right.profile_cumulative_snapshot().enabled), "Case endpoint must disable cumulative collection.")
		game = null
	if workload != "idle":
		_t7_check(int(right.hex_court.metrics.admitted) > 0 and int(right.hex_court.metrics.matter_paid) > 0, "Measured persistent workload must really admit and pay.")
		_t7_check(bool(witness.ground), "Measured paid route must reach real finite ground.")
		if workload == "paid_fire": _t7_check(bool(witness.flight), "Paid Fire must witness released flight.")
	var summary: Dictionary = {}
	for count: int in STEP_COUNTS:
		var reference: Array[float] = []
		var candidate: Array[float] = []
		var delta: Array[float] = []
		for row: Dictionary in rows:
			if bool(row.warmup) or int(row.steps) != count: continue
			reference.append(float(row.reference.whole_call_us))
			candidate.append(float(row.candidate.whole_call_us))
			delta.append(float(row.candidate.whole_call_us) - float(row.reference.whole_call_us))
		_t7_check(reference.size() == CYCLES - WARMUPS, "Every group must retain exactly64 measured pairs.")
		summary[str(count)] = {"reference_whole_us": _t7_stats(reference), "candidate_whole_us": _t7_stats(candidate), "paired_delta_us": _t7_stats(delta)}
	var attempts: int = 0 if workload == "idle" else ceili(float(right.tick) / 120.0) if contrast == "default_step" else int(b.attempts)
	t7_cases.append({"contrast": contrast, "workload": workload, "tick_end": right.tick, "synthetic_command_attempts": attempts, "summary": summary, "witness": witness, "court_metrics": right.hex_court.metrics.duplicate(true), "court_metric_scope": "Court metrics retain their native meaning; refused does not count earlier combat cooldown/control refusals. No per-command outcome is reconstructed from a last-step event.", "boundary_authority_hash": boundary_hash, "endpoints": endpoints, "rows": rows})
	for node: Variant in [a, b]:
		if node == null: continue
		node.recording = false
		node.casting = false
		node.session_transport.stop()
		_t7_check((node.player_preferences as NoSave).saves == 0, "Fixture must not save user preferences.")
		node.free()
	print("T7 COST CASE ", contrast, "/", workload, " ticks=", right.tick, " admitted=", right.hex_court.metrics.admitted, " refused=", right.hex_court.metrics.refused)

func _t7_stats(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {"count": 0}
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var total := 0.0
	for value: float in values: total += value
	var middle := floori(float(sorted.size()) / 2.0)
	var median: float = sorted[middle] if sorted.size() % 2 == 1 else (sorted[middle - 1] + sorted[middle]) / 2.0
	return {"count": values.size(), "mean": total / float(values.size()), "median": median, "p95": sorted[ceili(float(sorted.size()) * 0.95) - 1], "min": sorted.front(), "max": sorted.back()}

func _t7_failed_cleanup() -> void:
	var failed := _t7_world(false, "idle")
	failed.profile_enabled = true
	var node: CurrentGame = _t7_node(failed, false, "full_cumulative", "idle") as CurrentGame
	_t7_check(node.begin_completed_stage_case(), "Failure control enables its own bounded epoch.")
	var before := failed.profile_cumulative_snapshot()
	_t7_check(not failed.step([SimCommand.new(failed.tick + 1, 1)]), "Wrong-tick control must fail after a real measured prefix.")
	var after := failed.profile_cumulative_snapshot()
	_t7_check(int(after.failed_steps) == 1 and after.elapsed_us == before.elapsed_us and after.executions == before.executions, "Failed prefix must not commit elapsed/count lanes.")
	_t7_check(not bool(TimedGame.completed_stage_delta(before, after, 1000000).valid), "Failed partial interval must remain rejected.")
	node.end_completed_stage_case()
	_t7_check(not bool(failed.profile_cumulative_snapshot().enabled), "Explicit native failure cleanup ends accumulation.")
	node.recording = false
	node.session_transport.stop()
	node.free()

func _t7_finish() -> void:
	for path: String in t7_sources:
		_t7_check(FileAccess.get_sha256(path) == t7_sources[path], "Watched source changed: " + path)
	Input.mouse_mode = t7_mouse_mode
	var payload := {"schema": "hex-completed-stage-cpu-comparison-v1", "status": "passed" if t7_errors.is_empty() else "failed", "errors": t7_errors, "assertions": t7_assertions, "reverse_initial_order": t7_reverse, "native_display": DisplayServer.get_name(), "engine": Engine.get_version_info(), "sources": t7_sources, "cases": t7_cases,
		"scope": "Native window, synchronous actual invocation order, controlled0/1/8 simulation groups. No draw/terrain preparation, physical frame/FPS/foreground/GPU claim. Persistent ordinary paid worlds; no refills or cooldown edits. Predecessor step body exact; current constructor/new field allocation and current Bootstrap/helpers shared, including current E13 local cast-witness ingestion in both process arms. This is not the entire predecessor executable. Authority/event/packet equality is checked at process boundaries outside clocks; separate focused regression checks each paid tick. Whole TimedGame call includes new snapshots/delta/history; inner process includes cumulative commit. Case begin, production summary, raw deep copy and JSON endpoints are separate. Failed cleanup tests explicit end after rejection, not the enclosing profiler's quit/report-I/O branches. Warmups retained, not pooled. Timer units are microseconds; generic stat field names are descriptive distributions only."}
	var started := Time.get_ticks_usec()
	var encoded := JSON.stringify(payload, "\t")
	var serialization_usec := Time.get_ticks_usec() - started
	payload.final_serialization_probe_usec = serialization_usec
	payload.final_serialization_probe_bytes = encoded.to_utf8_buffer().size()
	encoded = JSON.stringify(payload, "\t")
	if not t7_output.is_empty():
		DirAccess.make_dir_recursive_absolute(t7_output.get_base_dir())
		var file := FileAccess.open(t7_output, FileAccess.WRITE)
		if file == null: print("T7 COST WRITE FAILED: ", t7_output); quit(1); return
		file.store_string(encoded + "\n")
		file.close()
	print("T7 COST COMPLETE status=", payload.status, " cases=", t7_cases.size(), " checks=", t7_assertions, " errors=", t7_errors.size())
	quit(0 if t7_errors.is_empty() else 1)
