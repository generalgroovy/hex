extends SceneTree
@warning_ignore_start("integer_division")
## Paired CPU attribution; no drawing/GPU, simulation or player-capacity claim.

const MovementReference = preload("res://tests/support/pixel_movement_reference.gd")
const Reference = preload("res://tests/support/pixel_descriptor_reference.gd")
const COUNTS := [8, 16, 32, 64]
const ACTIONS := ["idle", "walk", "jump", "moving_pending_cast", "moving_recovery_cast", "standing_pending_cast"]
const STAGES := ["bank_descriptor", "production_movement_frame"]
const WARMUPS := 40
const SAMPLES := 240
const SOURCE_PATHS := [
	"tests/performance/profile_pixel_descriptor_reuse.gd", "tests/support/pixel_descriptor_reference.gd",
	"tests/support/pixel_movement_reference.gd",
	"src/presentation/pixel_flipbook_presenter.gd", "src/presentation/pixel_action_bank.gd",
	"src/presentation/cartoon_champion_presenter.gd", "src/presentation/fullbody_cast_presenter.gd",
	"src/presentation/minimal_champion_motion.gd", "src/presentation/jump_presentation.gd",
	"src/sim/entities/player_state.gd", "src/sim/core/sim_config.gd",
	"src/sim/combat/combat_tuning.gd", "src/sim/combat/combat_definition_table.gd",
	"src/sim/movement/movement_tuning.gd", "content/abilities/foundation_abilities_v1.json",
	"content/visual/minimal_champion_motion_v1.json", "content/champions/foundation_champions_v1.json",
	"assets/sprites/fullbody_cast_v1/motions.json",
	"assets/sprites/pixel_cast_v1/manifest.json", "assets/sprites/pixel_actions_v1/manifest.json",
]

var failures := 0
var assertions := 0
var config := SimConfig.new(120)
var reduced := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var output := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		elif argument == "--reduced": reduced = true
	_check(output.begins_with("res://.godot/pixel-descriptor-profile-") and output.ends_with(".json") and not ".." in output and not FileAccess.file_exists(output), "fresh contained JSON receipt required")
	if failures > 0: quit(1); return
	var source_before := _source_hashes()
	var setup_started := Time.get_ticks_usec()
	var language := VisualLanguage.new()
	var presenters: Array[CartoonChampionPresenter] = [MovementReference.new(), CartoonChampionPresenter.new()]
	_check(language.load_from_file(), "production visual language admits")
	for presenter: CartoonChampionPresenter in presenters:
		_check(presenter.configure(language) and presenter.enable_fullbody_art(false, true), "production fixed banks admit: " + presenter.last_error)
	if failures > 0: quit(1); return
	var bank: RefCounted = presenters[1].fullbody_art.pixel_pilot
	_check(bank != null and bank.action_bank != null, "both fixed banks required before profiling")
	if failures > 0: quit(1); return
	var setup_us := Time.get_ticks_usec() - setup_started
	var ids: Array = bank.entries.keys()
	ids.sort()
	_check(ids.size() == 30, "fixture cycles thirty actually admitted art identities")
	_check(not bank.has_method("descriptor_template_count") and not bank.action_bank.has_method("descriptor_template_count"), "rejected persistent descriptor caches are absent")
	var cases: Array[Dictionary] = []
	for stage: String in STAGES:
		for count: int in COUNTS:
			for action: String in ACTIONS:
				var row := _measure(presenters, bank, ids, stage, count, action)
				_check(_case_complete(row, stage, count, action), "full measured case completed with exact descriptor checks")
				cases.append(row)
				print("PIXEL_DESCRIPTOR_PROFILE stage=%s objects=%d action=%s cases=%d failures=%d" % [stage, count, action, cases.size(), failures])
				if failures > 0: break
			if failures > 0: break
		if failures > 0: break
	_check(source_before == _source_hashes(), "all profiled source bytes stayed unchanged")
	for presenter: CartoonChampionPresenter in presenters:
		_check(presenter.fullbody_art.meshes.is_empty() and presenter.fullbody_art.render_meshes.is_empty(), "all measured paths stayed on stateless fixed-pixel routes")
	var complete := cases.size() == STAGES.size() * COUNTS.size() * ACTIONS.size()
	var index := 0
	if complete:
		for stage: String in STAGES:
			for count: int in COUNTS:
				for action: String in ACTIONS:
					complete = complete and _case_complete(cases[index], stage, count, action)
					index += 1
	_check(complete, "all forty-eight case identities contain forty warmups and240 measured pairs")
	var receipt := {
		"schema_version":2, "diagnostic_version":"pixel-preparation-subtraction-v2", "status":"passed" if failures == 0 else "failed",
		"engine":Engine.get_version_info(), "hardware":{"os":OS.get_name(), "cpu":OS.get_processor_name(), "logical_processors":OS.get_processor_count(), "display_server":DisplayServer.get_name()},
		"settings":{"warmup_pairs":WARMUPS, "measured_pairs":SAMPLES, "state_tick_rate":120, "reduced_effects":reduced, "order":"ABBA repeated; reference first at pair modulo4 0/3, candidate first at1/2"},
		"complete_case_set":complete, "cases":cases, "admitted_identities":ids, "setup_including_atlas_admission_us_excluded":setup_us,
		"persistent_descriptor_cache":"REJECTED_AND_REMOVED", "rejected_cache_evidence":"docs/engineering-evidence-20261003/rejected-descriptor-cache/rejection.json",
		"source_sha256":source_before, "assertions":assertions, "failures":failures,
		"scope":"Synthetic fixed-pixel CPU preparation only. Counts are render objects cycling thirty admitted identities, not admitted simulation players or supported multiplayer capacity. Bank stage isolates descriptor construction; production stage compares the frozen preceding movement wrapper/Fullbody routing against discarded-work removal and immutable definition reads. All objects are queried; there is no offscreen saving in these rows.",
		"timing_semantics":"Actor loop and retained output assignments are timed; fixture creation, state byte checks, exact complete descriptor comparison, quantiles and resource admission are outside timers. A separate post-pair deep-copy diagnostic measures copying the final descriptor arrays; it is not added to either arm. No drawing, GPU, camera, live history, networking or physical input is measured.",
		"memory_semantics":"No persistent descriptor templates are present. Rejected v1 allocation measurements and source copies remain in the separate rejected-cache evidence. This v2 probe adds no production actor/history/descriptor caches.",
		"performance_acceptance":"NOT_ESTABLISHED. CPU attribution cannot establish rendered FPS, frame pacing,120Hz acceptance or64-player support.",
	}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null: push_error("Cannot open fresh descriptor profile receipt"); quit(1); return
	file.store_string(JSON.stringify(receipt, "\t") + "\n")
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK: push_error("Cannot finish descriptor profile receipt"); quit(1); return
	print("PIXEL_DESCRIPTOR_PROFILE %s: %d cases; %d assertions; output=%s" % ["PASS" if failures == 0 else "FAIL", cases.size(), assertions, output])
	quit(0 if failures == 0 else 1)


func _measure(presenters: Array[CartoonChampionPresenter], bank: RefCounted, ids: Array, stage: String, count: int, action: String) -> Dictionary:
	var fixture := _fixture(ids, count, action)
	var authority_before := _authority_bytes(fixture.actors)
	var reference_times := PackedInt64Array()
	var candidate_times := PackedInt64Array()
	var deltas := PackedInt64Array()
	var copy_times := PackedInt64Array()
	var completed := 0
	var exact_checks := 0
	for pair: int in range(WARMUPS + SAMPLES):
		var outputs: Array[Dictionary] = [{}, {}]
		var order: Array[int] = [0, 1]
		if pair % 4 in [1, 2]: order.reverse()
		for arm: int in order:
			outputs[arm] = _batch(presenters[arm], bank, fixture, pair, stage, arm == 0)
			_check(_authority_bytes(fixture.actors) == authority_before, "every reference/candidate query preserves actor authority")
			_check(outputs[arm].frames.size() == count, "all objects produced a descriptor")
		for actor: int in count:
			var reference: Dictionary = outputs[0].frames[actor]
			var candidate: Dictionary = outputs[1].frames[actor]
			_check(reference.get("pixel_body_pilot", false) and not String(reference.get("frame_id", "")).is_empty(), "reference is admitted nonempty fixed art")
			_check(Reference.same_descriptor(candidate, reference), "complete frame keys/types/values and texture objects match exactly")
			if pair >= WARMUPS: exact_checks += 1
		if failures > 0: break
		completed += 1
		if pair >= WARMUPS:
			reference_times.append(int(outputs[0].us)); candidate_times.append(int(outputs[1].us))
			deltas.append(int(outputs[1].us) - int(outputs[0].us))
			var copied := _copy_batch(outputs[1].frames)
			copy_times.append(int(copied.us))
			_check(Reference.same_descriptor(copied.frames, outputs[1].frames), "separate copy diagnostic retains all values")
	var reference_summary := _quantiles(reference_times)
	var candidate_summary := _quantiles(candidate_times)
	return {"stage":stage, "synthetic_render_objects":count, "action":action, "warmup_pairs_completed":mini(completed, WARMUPS),
		"measured_pairs_completed":maxi(0, completed - WARMUPS), "exact_descriptor_checks":exact_checks,
		"reference_batch_us":reference_summary, "candidate_batch_us":candidate_summary, "paired_candidate_minus_reference_us":_quantiles(deltas),
		"isolated_final_descriptor_deepcopy_batch_us":_quantiles(copy_times),
		"candidate_median_change_percent":100.0 * (float(candidate_summary.p50) / float(reference_summary.p50) - 1.0) if int(reference_summary.p50) > 0 else null,
		"authority_unchanged":_authority_bytes(fixture.actors) == authority_before, "authority_sha256":CanonicalBytes.sha256_hex(authority_before)}


func _fixture(ids: Array, count: int, action: String) -> Dictionary:
	var bank_action := "walk" if action.begins_with("moving_") else ("idle" if action == "standing_pending_cast" else action)
	var casting := action.contains("cast")
	var actors: Array[PlayerState] = []
	var names: Array[String] = []
	var aims: Array[int] = []
	var travels: Array[int] = []
	for index: int in count:
		var actor := PlayerState.new(index + 1)
		var aim_index := index % 8
		var travel_index := (index * 3 + 1) % 8
		var aim: Vector2i = EightDirectionResolver.FIXED_VECTORS[aim_index]
		var travel: Vector2i = EightDirectionResolver.FIXED_VECTORS[travel_index]
		actor.aim_x = aim.x; actor.aim_y = aim.y; actor.facing_x = aim.x; actor.facing_y = aim.y
		if bank_action != "idle":
			actor.velocity_x = travel.x * 200; actor.velocity_y = travel.y * 200
			actor.movement_mode = PlayerState.MovementMode.WALK
		if bank_action == "jump":
			actor.air_height = 90000; actor.air_vertical_velocity = 1000
			actor.hop_ticks = 10; actor.hop_mode = PlayerState.MovementMode.HOP
		if action.ends_with("pending_cast"):
			actor.pending_cast_wire_id = 1; actor.pending_cast_ticks = 4
		elif action == "moving_recovery_cast": actor.cast_recovery_ticks = 4
		actors.append(actor); names.append(ids[index % ids.size()]); aims.append(aim_index); travels.append(travel_index)
	return {"actors":actors, "ids":names, "aims":aims, "travels":travels, "bank_action":bank_action, "casting":casting}


func _batch(presenter: CartoonChampionPresenter, bank: RefCounted, fixture: Dictionary, pair: int, stage: String, reference: bool) -> Dictionary:
	var frames: Array[Dictionary] = []
	frames.resize(fixture.actors.size())
	var tick := 120.0 + float(pair)
	var phase := float(pair % 48) / 48.0
	var started := Time.get_ticks_usec()
	for index: int in fixture.actors.size():
		if stage == "production_movement_frame":
			frames[index] = presenter.movement_frame(fixture.ids[index], fixture.actors[index], tick, config, reduced, phase)
		elif reference:
			frames[index] = Reference.ground_frame(bank, fixture.ids[index], fixture.bank_action, fixture.aims[index], fixture.travels[index], phase, fixture.casting, 1.0, reduced)
		else:
			frames[index] = bank.frame(fixture.ids[index], fixture.bank_action, fixture.aims[index], fixture.travels[index], phase, fixture.casting, 1.0, reduced)
	return {"us":Time.get_ticks_usec() - started, "frames":frames}


func _copy_batch(source: Array) -> Dictionary:
	var frames: Array[Dictionary] = []
	frames.resize(source.size())
	var started := Time.get_ticks_usec()
	for index: int in source.size(): frames[index] = source[index].duplicate(true)
	return {"us":Time.get_ticks_usec() - started, "frames":frames}


func _case_complete(row: Dictionary, stage: String, count: int, action: String) -> bool:
	if row.get("stage") != stage or row.get("synthetic_render_objects") != count or row.get("action") != action: return false
	if row.get("warmup_pairs_completed") != WARMUPS or row.get("measured_pairs_completed") != SAMPLES or row.get("exact_descriptor_checks") != count * SAMPLES: return false
	if row.get("authority_unchanged") != true or String(row.get("authority_sha256", "")).length() != 64: return false
	for key: String in ["reference_batch_us", "candidate_batch_us", "paired_candidate_minus_reference_us", "isolated_final_descriptor_deepcopy_batch_us"]:
		var summary: Variant = row.get(key)
		if not summary is Dictionary or summary.size() != 5 or summary.get("samples") != SAMPLES: return false
		for field: String in ["samples", "p50", "p95", "p99", "max"]:
			if typeof(summary.get(field)) != TYPE_INT: return false
		if summary.p50 > summary.p95 or summary.p95 > summary.p99 or summary.p99 > summary.max: return false
		if key != "paired_candidate_minus_reference_us" and summary.p50 < 0: return false
	return true


func _authority_bytes(actors: Array[PlayerState]) -> PackedByteArray:
	var values: Array = []
	for actor: PlayerState in actors: values.append([actor.canonical_values(), actor.last_event])
	return var_to_bytes(values)


func _quantiles(samples: PackedInt64Array) -> Dictionary:
	if samples.is_empty(): return {"samples":0, "p50":0, "p95":0, "p99":0, "max":0}
	var ordered := samples.duplicate()
	ordered.sort()
	var result := {"samples":ordered.size(), "max":ordered[-1]}
	for percentile: int in [50, 95, 99]: result["p%d" % percentile] = ordered[clampi((ordered.size() * percentile + 99) / 100 - 1, 0, ordered.size() - 1)]
	return result


func _source_hashes() -> Dictionary:
	var result := {}
	for path: String in SOURCE_PATHS: result[path] = FileAccess.get_sha256("res://" + path)
	return result


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("pixel descriptor profile: " + message)
