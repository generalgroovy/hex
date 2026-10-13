extends "res://scripts/profile-gameplay.gd"
## Isolated enclosing-profiler cleanup proof, not the application's close path.

const SELF_PATH := "res://.godot/iteration-20261013/verify-completed-stage-cleanup.gd"
const OUTPUT_ROOT := "res://.godot/iteration-20261013/t7-cleanup-runs"
const CONTROLLED_ERROR := "HEX_T7_CONTROLLED_PROFILER_FAILURE"
const Packet = preload("res://src/net/hex_world_snapshot.gd")
const WATCHED := [SELF_PATH, "res://scripts/profile-gameplay.gd",
	"res://src/sim/core/sim_world.gd", "res://src/sim/core/sim_config.gd",
	"res://src/app/bootstrap.gd", "res://src/presentation/cast_startup_witness.gd",
	"res://src/net/hex_world_snapshot.gd", "res://src/content/runtime_build_identity.gd",
	"res://content/runtime/runtime_build_identity_v1.json",
	"res://content/abilities/foundation_abilities_v1.json",
	"res://content/champions/foundation_champions_v1.json"]

class CountedWorld extends SimWorld:
	var begin_calls := 0
	var end_calls := 0
	func profile_cumulative_begin() -> bool:
		begin_calls += 1
		return super.profile_cumulative_begin()
	func profile_cumulative_end() -> void:
		end_calls += 1
		super.profile_cumulative_end()

var cleanup_mode := ""
var owned_directory := ""
var output_authorized := false
var setup_complete := false
var invoked := false
var cleanup_checks := 0
var cleanup_errors: Array[String] = []
var cleanup_sources: Dictionary = {}
var observed_world: CountedWorld
var state_before := ""
var packet_before := PackedByteArray()
var events_before := PackedByteArray()
var counters_before: Dictionary = {}
var immediate_cleanup: Dictionary = {}
var expected_error := ""
var enclosing_finalizations := 0
var partial_before_finalize := ""


func _initialize() -> void:
	# Deliberately do not schedule the inherited game/art/profile bootstrap.
	_cleanup_probe.call_deferred()


func _cleanup_probe() -> void:
	cleanup_mode = _option("--cleanup-case")
	owned_directory = _option("--cleanup-directory").trim_suffix("/")
	if not _cleanup_check(cleanup_mode in ["normal", "failure", "io"], "Known cleanup case"):
		quit(2); return
	if not _cleanup_check(owned_directory.get_base_dir() == OUTPUT_ROOT
		and owned_directory.get_file().begins_with(cleanup_mode + "-")
		and owned_directory.get_file().is_valid_filename()
		and not ".." in owned_directory
		and not DirAccess.dir_exists_absolute(owned_directory)
		and not FileAccess.file_exists(owned_directory), "Fresh exact owned output directory"):
		quit(2); return
	if not _cleanup_check(DirAccess.make_dir_recursive_absolute(owned_directory) == OK, "Create only the owned output directory"):
		quit(2); return
	output_authorized = true
	for path: String in WATCHED:
		cleanup_sources[path] = FileAccess.get_sha256(path)
		_cleanup_check(String(cleanup_sources[path]).length() == 64, "Watched source exists: " + path)
	if not cleanup_errors.is_empty(): quit(2); return
	var abilities := AbilityCatalog.new()
	var champions := ChampionCatalog.new()
	_cleanup_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "Actual abilities load")
	_cleanup_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "Actual champions load")
	if not cleanup_errors.is_empty(): quit(2); return
	observed_world = CountedWorld.new(120, 613, CollisionWorld.new(2_000_000, 2_000_000))
	var origin := Vector2i(600_000, 500_000)
	var chemistry := HexChemistryWorld.new()
	_cleanup_check(chemistry.configure_geometry(origin, HexGrid.disk(Vector2i.ZERO, 8)), "Finite real chemistry geometry")
	chemistry.chemistry_enabled = true
	observed_world.hex_court = chemistry
	_cleanup_check(champions.apply_to_player(observed_world.player(), "oh_tipi"), "Normal authored actor resources")
	observed_world.player().reset_for_spawn(origin)
	var wire := MixtureCatalog.wire_for(2, "bolt")
	_cleanup_check(observed_world.player().place_proven_spell(0, wire), "Actual Fire Bolt equipped")
	game = TimedGame.new()
	game.world = observed_world
	game.all_fixed_steps = true
	game.light_observer = false
	all_fixed_steps = true
	light_observer = false
	observed_world.profile_enabled = true
	_cleanup_check(not game.is_inside_tree(), "TimedGame never enters the application tree")
	_cleanup_check(game.begin_completed_stage_case(), "Actual full-observer case begins")
	var flux_before := observed_world.player().flux
	var commands: Array[SimCommand] = [SimCommand.new(0, 1, 0, 0, 0, SimCommand.PRESSED_SPELL_1, 1000, 0)]
	_cleanup_check(observed_world.step(commands), "One real successful paid step")
	_cleanup_check(observed_world.player().flux == flux_before - int(CombatTuning.cast_definition_view(wire).flux_cost), "Ordinary Flux payment retained")
	_cleanup_check(int(chemistry.metrics.admitted) == 1 and int(chemistry.metrics.matter_paid) == 600, "Finite paid chemistry admission")
	_cleanup_check(chemistry.conservation_valid(), "Paid matter conserves before cleanup")
	state_before = observed_world.state_hash()
	var packet := Packet.capture(observed_world)
	_cleanup_check(not packet.is_empty(), "Strict paid snapshot exists before cleanup")
	packet_before = var_to_bytes(packet)
	events_before = var_to_bytes(observed_world.combat_events)
	counters_before = observed_world.profile_cumulative_snapshot()
	_cleanup_check(bool(counters_before.enabled) and int(counters_before.completed_steps) == 1
		and int(counters_before.attempted_steps) == 1 and int(counters_before.failed_steps) == 0,
		"Cumulative counters have one completed step before cleanup")
	_cleanup_check(observed_world.begin_calls == 1 and observed_world.end_calls == 0, "No preemptive cleanup call")
	for stage: String in SimWorld.PROFILE_CUMULATIVE_STAGES:
		_cleanup_check(int(counters_before.executions[stage]) == 1, "Real completed stage: " + stage)
	if not cleanup_errors.is_empty(): quit(2); return
	setup_complete = true
	output_path = owned_directory.path_join("profile.json")
	report = {"schema": "hex.completed-stage-cleanup-fixture.v1", "complete": true, "case": cleanup_mode}
	invoked = true
	match cleanup_mode:
		"normal":
			quit(0)
		"failure":
			expected_error = CONTROLLED_ERROR
			_fail(CONTROLLED_ERROR)
			immediate_cleanup = _cleanup_boundary("after_inherited_fail", 1)
			var partial_path := output_path + ".partial.json"
			partial_before_finalize = FileAccess.get_file_as_string(partial_path)
			var partial: Variant = JSON.parse_string(partial_before_finalize)
			_cleanup_check(partial is Dictionary and partial.get("complete") == false
				and partial.get("error") == expected_error, "Inherited failure writes its real partial report")
		"io":
			var blocked_path := owned_directory.path_join("directory-is-not-a-report")
			_cleanup_check(DirAccess.make_dir_absolute(blocked_path) == OK, "Create owned directory as real invalid file target")
			expected_error = "Could not open benchmark receipt: " + blocked_path
			_cleanup_check(not _write_report(blocked_path), "Inherited report write reports the actual OS open failure")
			immediate_cleanup = _cleanup_boundary("after_inherited_report_io_failure", 1)
			_cleanup_check(DirAccess.dir_exists_absolute(blocked_path), "Rejected report target stays a directory")
			_cleanup_check(not FileAccess.file_exists(output_path + ".partial.json"), "Report I/O failure does not recurse into a partial report")


func _cleanup_boundary(label: String, expected_ends: int) -> Dictionary:
	var snapshot := observed_world.profile_cumulative_snapshot()
	var expected := counters_before.duplicate(true)
	expected.enabled = false
	_cleanup_check(snapshot == expected, label + ": only accumulation enablement changes")
	_cleanup_check(observed_world.begin_calls == 1 and observed_world.end_calls == expected_ends, label + ": exact delegated lifecycle call count")
	_cleanup_check(observed_world.state_hash() == state_before, label + ": canonical state unchanged")
	_cleanup_check(var_to_bytes(Packet.capture(observed_world)) == packet_before, label + ": strict packet bytes unchanged")
	_cleanup_check(var_to_bytes(observed_world.combat_events) == events_before, label + ": events unchanged")
	_cleanup_check(observed_world.hex_court.conservation_valid(), label + ": paid matter still conserved")
	return {"label": label, "snapshot": snapshot, "begin_calls": observed_world.begin_calls, "end_calls": observed_world.end_calls,
		"state_hash": observed_world.state_hash(), "packet_sha256": _cleanup_digest(packet_before)}


func _finalize() -> void:
	enclosing_finalizations += 1
	# Exercise the inherited enclosing cleanup before inspecting its result.
	super._finalize()
	var final_boundary: Dictionary = {}
	if setup_complete:
		final_boundary = _cleanup_boundary("after_inherited_finalize", 1 if cleanup_mode == "normal" else 2)
		_cleanup_check(enclosing_finalizations == 1 and invoked, "One actual enclosing finalization follows the selected call")
		_cleanup_check(failed == (cleanup_mode != "normal"), "Original profiler failure flag preserved")
		_cleanup_check(viewport_timing_owned.is_empty() and viewport_timing_pending.is_empty(), "No unrelated viewport measurement owner retained")
		if cleanup_mode != "normal":
			_cleanup_check(report.get("complete") == false and report.get("error") == expected_error, "Original failure report state preserved")
		if cleanup_mode == "failure":
			_cleanup_check(FileAccess.get_file_as_string(output_path + ".partial.json") == partial_before_finalize,
				"Finalization leaves the inherited partial report bytes intact")
	for path: String in cleanup_sources:
		_cleanup_check(FileAccess.get_sha256(path) == cleanup_sources[path], "Watched source unchanged: " + path)
	var released: WeakRef
	if is_instance_valid(game):
		released = weakref(game)
		game.free()
		game = null
		_cleanup_check(released.get_ref() == null, "Never-entered owned Node is freed after inherited cleanup")
	if output_authorized:
		_write_cleanup_receipt(final_boundary)


func _write_cleanup_receipt(final_boundary: Dictionary) -> void:
	var receipt := {"schema": "hex.completed-stage-enclosing-cleanup.v1", "passed": cleanup_errors.is_empty() and setup_complete,
		"case": cleanup_mode, "checks": cleanup_checks, "errors": cleanup_errors, "sources": cleanup_sources,
		"expected_exit_code": 0 if cleanup_mode == "normal" else 1, "expected_error_text": expected_error,
		"enclosing_finalizations": enclosing_finalizations, "before": counters_before,
		"immediate": immediate_cleanup, "after_finalize": final_boundary,
		"scope": "Actual inherited profiler enclosing cleanup in three separate native processes. Real paid world and completed-step counters; TimedGame never enters the tree. Failure and I/O cases intentionally exit1 and emit their exact expected error. Side-channel receipt is independent of the inherited report path. No application bootstrap, art, LAN, saves, full player-close lifecycle, foreground or performance claim."}
	var path := owned_directory.path_join("receipt.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: printerr("HEX_T7_CLEANUP_RECEIPT_OPEN_FAILED"); return
	var text := JSON.stringify(receipt, "\t") + "\n"
	file.store_string(text)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or FileAccess.get_file_as_string(path) != text:
		printerr("HEX_T7_CLEANUP_RECEIPT_VERIFY_FAILED")
		return
	print("HEX_T7_CLEANUP ", cleanup_mode, " ", cleanup_checks, " checks, ", cleanup_errors.size(), " errors; ", path)


func _cleanup_check(condition: bool, message: String) -> bool:
	cleanup_checks += 1
	if not condition: cleanup_errors.append(message)
	return condition


static func _cleanup_digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
