extends SceneTree
@warning_ignore_start("integer_division")
## Synthetic render-preparation CPU batches, never player/session capacity.

const Policy = preload("res://src/presentation/character_viewport_policy.gd")
const COUNTS := [8, 16, 32, 64]
const VISIBLE_PERCENT := [100, 50, 0]
const ACTIONS := ["idle", "walk", "jump"]
const WARMUPS := 60
const SAMPLES := 300
const VIEW := Rect2(0, 0, 1280, 720)
const CAMERA := Vector2(123.4, -59.7)
const SOURCE_PATHS := [
	"tests/performance/profile_character_viewport.gd", "src/presentation/character_viewport_policy.gd",
	"src/presentation/cartoon_champion_presenter.gd", "src/presentation/fullbody_cast_presenter.gd",
	"src/presentation/pixel_flipbook_presenter.gd", "src/presentation/pixel_action_bank.gd",
	"src/presentation/minimal_champion_motion.gd", "src/presentation/jump_presentation.gd",
	"src/presentation/pixel_presentation.gd", "src/sim/entities/player_state.gd",
	"assets/sprites/pixel_cast_v1/manifest.json", "assets/sprites/pixel_actions_v1/manifest.json",
]

var config := SimConfig.new(120)
var zoom_percent := 75
var reduced := false
var failures := 0
var assertions := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var output := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		elif argument.begins_with("--zoom="): zoom_percent = int(argument.trim_prefix("--zoom="))
		elif argument == "--reduced": reduced = true
	_check(output.begins_with("res://.godot/character-viewport-profile-") and output.ends_with(".json") and not ".." in output and not FileAccess.file_exists(output), "fresh contained JSON receipt required")
	_check(zoom_percent in PixelPresentation.SUPPORTED_ZOOM, "zoom is 50, 75 or 100 percent")
	if failures > 0: quit(1); return
	var source_before := _source_hashes()
	var setup_started := Time.get_ticks_usec()
	var language := VisualLanguage.new()
	_check(language.load_from_file(), "production visual language loads")
	var presenters: Array[CartoonChampionPresenter] = []
	for _arm: int in 2:
		var presenter := CartoonChampionPresenter.new()
		_check(presenter.configure(language) and presenter.enable_fullbody_art(false, true), "production fullbody and full-cast banks admit: " + presenter.last_error)
		presenters.append(presenter)
	if failures > 0: quit(1); return
	var ids: Array = presenters[0].champions.keys()
	ids.sort()
	_check(ids.size() == 30, "fixture cycles the current thirty admitted identities")
	_check(presenters[1].champions.keys().size() == ids.size(), "paired presenters admit the same roster")
	for presenter: CartoonChampionPresenter in presenters:
		var actions: RefCounted = presenter.fullbody_art.pixel_pilot.action_bank
		_check(actions != null, "jump requires the admitted fixed-pixel action bank")
		if actions != null:
			for id: String in ids:
				_check(actions.entries.has(id) and actions.textures.has(id), "fixed jump route exists for " + id)
	if failures > 0: quit(1); return
	var setup_us := Time.get_ticks_usec() - setup_started
	var cases: Array[Dictionary] = []
	for count: int in COUNTS:
		for visible: int in VISIBLE_PERCENT:
			for action: String in ACTIONS:
				var row := _measure(presenters, ids, count, visible, action)
				_check(_case_complete(row, count, visible, action), "case completed every warmup/sample and passed its receipt schema")
				cases.append(row)
				print("CHARACTER_VIEWPORT_PROFILE actors=%d visible=%d action=%s cases=%d failures=%d" % [count, visible, action, cases.size(), failures])
				if failures > 0: break
			if failures > 0: break
		if failures > 0: break
	_check(source_before == _source_hashes(), "profiled source files remain unchanged throughout run")
	for presenter: CartoonChampionPresenter in presenters:
		_check(presenter.fullbody_art.meshes.is_empty() and presenter.fullbody_art.render_meshes.is_empty(), "all measured frames stayed on stateless fixed-pixel routes")
	# GDScript runtime errors can abort a helper and return an empty Dictionary
	# without incrementing our assertion counter. Never infer success from that
	# counter alone: require the entire expected case/sample matrix explicitly.
	var complete_case_set := _cases_complete(cases)
	_check(complete_case_set, "all 36 expected case identities have 300 complete paired samples")
	var receipt := {
		"schema_version": 2, "diagnostic_version": "character-viewport-cpu-pairs-v2",
		"status": "passed" if failures == 0 else "failed", "engine": Engine.get_version_info(),
		"hardware": {"os": OS.get_name(), "cpu": OS.get_processor_name(), "logical_processors": OS.get_processor_count(), "display_server": DisplayServer.get_name()},
		"settings": {"viewport_pixels": [1280, 720], "camera_origin": [CAMERA.x, CAMERA.y], "zoom_percent": zoom_percent, "reduced_effects": reduced, "state_tick_rate": config.tick_rate, "warmup_pairs_per_case": WARMUPS, "measured_pairs_per_case": SAMPLES, "order": "ABBA repeated: reference first at pair modulo4 0/3, candidate first at1/2"},
		"setup_us_excluded": setup_us, "admitted_identities": ids, "cases": cases, "complete_case_set": complete_case_set,
		"source_sha256": source_before, "assertions": assertions, "failures": failures,
		"scope": "Synthetic render-preparation CPU only. Each count is PlayerState presentation objects cycling thirty admitted art identities, not admitted simulation actors, connected clients, lobby slots or supported player capacity. Both arms use real production movement_frame; candidate adds can_skip_body and omits only wholly offscreen frame queries.",
		"timing_semantics": "Per-batch timers include the actor loop, query count and retained frame-array assignments. Candidate includes the policy decision; reference calls movement_frame unconditionally. Setup/texture admission, fixture creation, canonical state checks, visible frame-ID equality and percentile work are outside timers. Fixed states vary aim/travel per actor; presentation tick/gait phase advance per pair. No drawing, GPU completion, live history, camera interpolation, simulation, networking or physical input.",
		"performance_acceptance": "NOT_ESTABLISHED. All-visible rows estimate the added decision cost. Quantiles are CPU diagnostics on this machine, not FPS, total-frame, multiplayer or release-capacity evidence.",
	}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write character viewport CPU receipt: " + output)
		quit(1); return
	file.store_string(JSON.stringify(receipt, "\t") + "\n")
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		push_error("Cannot finish character viewport CPU receipt: " + output)
		quit(1); return
	print("CHARACTER_VIEWPORT_PROFILE %s: %d cases; %d assertions; output=%s; capacity=NOT_ESTABLISHED" % ["PASS" if failures == 0 else "FAIL", cases.size(), assertions, output])
	quit(0 if failures == 0 else 1)


func _measure(presenters: Array[CartoonChampionPresenter], ids: Array, count: int, visible_percent: int, action: String) -> Dictionary:
	var fixture := _fixture(ids, count, visible_percent, action)
	var reference_times := PackedInt64Array()
	var candidate_times := PackedInt64Array()
	var paired_deltas := PackedInt64Array()
	var avoided := 0
	var visible_checks := 0
	var completed_pairs := 0
	var stable_state := _authority_bytes(fixture.actors)
	for pair: int in range(WARMUPS + SAMPLES):
		var outputs: Array[Dictionary] = [{}, {}]
		var order: Array[int] = [0, 1]
		if pair % 4 in [1, 2]: order.reverse()
		for arm: int in order:
			outputs[arm] = _batch(presenters[arm], fixture, pair, arm == 1)
			_check(_authority_bytes(fixture.actors) == stable_state, "frame construction and policy do not mutate actor authority")
		_check(int(outputs[0].queries) == count and int(outputs[1].queries) == int(fixture.visible_count), "both arms execute exactly the intended query count")
		for index: int in count:
			var reference: Dictionary = outputs[0].frames[index]
			_check(bool(reference.get("pixel_body_pilot", false)) and not String(reference.get("frame_id", "")).is_empty(), "reference is an admitted fixed frame with an identity")
			if index < int(fixture.visible_count):
				var candidate: Dictionary = outputs[1].frames[index]
				_check(bool(candidate.get("pixel_body_pilot", false)) and candidate.get("frame_id", "") == reference.get("frame_id", ""), "visible frame identity is unchanged")
				if pair >= WARMUPS: visible_checks += 1
			else:
				_check((outputs[1].frames[index] as Dictionary).is_empty(), "offscreen candidate does not construct a frame")
		if failures > 0: break
		completed_pairs += 1
		if pair >= WARMUPS:
			reference_times.append(int(outputs[0].us))
			candidate_times.append(int(outputs[1].us))
			paired_deltas.append(int(outputs[1].us) - int(outputs[0].us))
			avoided += count - int(outputs[1].queries)
	var reference_summary := _quantiles(reference_times)
	var candidate_summary := _quantiles(candidate_times)
	return {
		"schema_version": 1, "warmup_pairs_completed": mini(WARMUPS, completed_pairs), "measured_pairs_completed": maxi(0, completed_pairs - WARMUPS),
		"synthetic_actors": count, "visible_percent": visible_percent, "visible_actors": fixture.visible_count, "action": action,
		"reference_batch_us": reference_summary, "candidate_batch_us": candidate_summary,
		"paired_candidate_minus_reference_us": _quantiles(paired_deltas),
		"candidate_median_change_percent": 100.0 * (float(candidate_summary.p50) / float(reference_summary.p50) - 1.0) if int(reference_summary.p50) > 0 else null,
		"reference_pose_queries": count * reference_times.size(), "candidate_pose_queries": int(fixture.visible_count) * candidate_times.size(),
		"avoided_pose_queries": avoided, "visible_frame_id_checks": visible_checks,
		"state_bytes_unchanged": _authority_bytes(fixture.actors) == stable_state,
		"state_sha256": CanonicalBytes.sha256_hex(stable_state),
		"same_visible_frame_ids": failures == 0, "source_meshes": [presenters[0].fullbody_art.meshes.size(), presenters[1].fullbody_art.meshes.size()],
		"stream_meshes": [presenters[0].fullbody_art.render_meshes.size(), presenters[1].fullbody_art.render_meshes.size()],
	}


func _cases_complete(cases: Array[Dictionary]) -> bool:
	if cases.size() != COUNTS.size() * VISIBLE_PERCENT.size() * ACTIONS.size(): return false
	var index := 0
	for count: int in COUNTS:
		for visible: int in VISIBLE_PERCENT:
			for action: String in ACTIONS:
				if not _case_complete(cases[index], count, visible, action): return false
				index += 1
	return true


func _case_complete(row: Dictionary, count: int, visible_percent: int, action: String) -> bool:
	var visible_count := count * visible_percent / 100
	var expected := {"schema_version": 1, "synthetic_actors": count, "visible_percent": visible_percent,
		"visible_actors": visible_count, "warmup_pairs_completed": WARMUPS, "measured_pairs_completed": SAMPLES,
		"reference_pose_queries": count * SAMPLES, "candidate_pose_queries": visible_count * SAMPLES,
		"avoided_pose_queries": (count - visible_count) * SAMPLES, "visible_frame_id_checks": visible_count * SAMPLES}
	for key: String in expected:
		if typeof(row.get(key)) != TYPE_INT or row[key] != expected[key]: return false
	if typeof(row.get("action")) != TYPE_STRING or row.action != action: return false
	for key: String in ["state_bytes_unchanged", "same_visible_frame_ids"]:
		if typeof(row.get(key)) != TYPE_BOOL or not row[key]: return false
	if typeof(row.get("state_sha256")) != TYPE_STRING or String(row.state_sha256).length() != 64: return false
	for key: String in ["reference_batch_us", "candidate_batch_us", "paired_candidate_minus_reference_us"]:
		var summary: Variant = row.get(key)
		if not summary is Dictionary or summary.size() != 5: return false
		for field: String in ["samples", "p50", "p95", "p99", "max"]:
			if typeof(summary.get(field)) != TYPE_INT: return false
		if int(summary.samples) != SAMPLES or summary.p50 > summary.p95 or summary.p95 > summary.p99 or summary.p99 > summary.max: return false
		if key != "paired_candidate_minus_reference_us" and int(summary.p50) < 0: return false
	for key: String in ["source_meshes", "stream_meshes"]:
		var meshes: Variant = row.get(key)
		if not meshes is Array or meshes.size() != 2: return false
		for value: Variant in meshes:
			if typeof(value) != TYPE_INT or value != 0: return false
	return true


func _fixture(ids: Array, count: int, visible_percent: int, action: String) -> Dictionary:
	var actors: Array[PlayerState] = []
	var names: Array[String] = []
	var grounds: Array[Vector2] = []
	var bodies: Array[Vector2] = []
	var visible_count := count * visible_percent / 100
	var zoom := PixelPresentation.zoom_scale(zoom_percent)
	var translation := PixelPresentation.snapped_canvas_origin(CAMERA, zoom_percent)
	for index: int in count:
		var state := PlayerState.new(index + 1)
		var aim: Vector2i = EightDirectionResolver.FIXED_VECTORS[index % 8]
		var travel: Vector2i = EightDirectionResolver.FIXED_VECTORS[(index * 3 + 1) % 8]
		state.aim_x = aim.x; state.aim_y = aim.y
		state.facing_x = aim.x; state.facing_y = aim.y
		if action != "idle":
			state.velocity_x = travel.x * 200; state.velocity_y = travel.y * 200
			state.movement_mode = PlayerState.MovementMode.WALK
		if action == "jump":
			state.air_height = 90000; state.air_vertical_velocity = 1000
			state.hop_ticks = 10; state.hop_mode = PlayerState.MovementMode.HOP
			# No active takeoff, protection or wall history: this is the fixed route.
			state.movement_commitment_ticks = 0
		var screen_anchor := Vector2(180 + index % 8 * 100, 280 + index / 8 * 42)
		if index >= visible_count: screen_anchor += Vector2(10000, 10000)
		var ground := (screen_anchor - translation) / zoom
		var jump := JumpPresentation.sample(state, config, 0.5, reduced, state.air_height)
		actors.append(state); names.append(ids[index % ids.size()]); grounds.append(ground)
		bodies.append(ground - Vector2(0, jump.body_lift_pixels))
	return {"actors": actors, "ids": names, "grounds": grounds, "bodies": bodies, "visible_count": visible_count}


func _batch(presenter: CartoonChampionPresenter, fixture: Dictionary, pair: int, culling: bool) -> Dictionary:
	var frames: Array[Dictionary] = []
	for _index: int in fixture.actors.size(): frames.append({})
	var queries := 0
	var tick := 120.0 + float(pair)
	var phase := float(pair % 48) / 48.0
	var started := Time.get_ticks_usec()
	for index: int in fixture.actors.size():
		if culling and Policy.can_skip_body(presenter, fixture.ids[index], fixture.actors[index], config, fixture.bodies[index], fixture.grounds[index], CAMERA, VIEW, zoom_percent): continue
		frames[index] = presenter.movement_frame(fixture.ids[index], fixture.actors[index], tick, config, reduced, phase)
		queries += 1
	var elapsed := Time.get_ticks_usec() - started
	return {"us": elapsed, "queries": queries, "frames": frames}


func _authority_bytes(actors: Array[PlayerState]) -> PackedByteArray:
	var values: Array = []
	for actor: PlayerState in actors: values.append([actor.canonical_values(), actor.last_event])
	return var_to_bytes(values)


func _quantiles(samples: PackedInt64Array) -> Dictionary:
	if samples.is_empty(): return {"samples": 0, "p50": 0, "p95": 0, "p99": 0, "max": 0}
	var ordered := samples.duplicate()
	ordered.sort()
	var result := {"samples": ordered.size(), "max": ordered[-1]}
	for percentile: int in [50, 95, 99]:
		result["p%d" % percentile] = ordered[clampi((ordered.size() * percentile + 99) / 100 - 1, 0, ordered.size() - 1)]
	return result


func _source_hashes() -> Dictionary:
	var result := {}
	for path: String in SOURCE_PATHS: result[path] = FileAccess.get_sha256("res://" + path)
	return result


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("character viewport profile: " + message)
