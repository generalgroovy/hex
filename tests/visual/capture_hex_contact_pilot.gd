extends "res://tests/visual/capture_unified_wellspring.gd"

# Isolated A/B presentation clock experiment; production files and atlases untouched.
const CHAMPION := "s_wayne"
const CANDIDATE_STRIDE := 36.771
const SAMPLE_TICKS: Array[int] = [23, 47, 71, 87, 103, 127, 159]
const RIG_PATH := "res://art_batches/character_style_v1/wireframe_motion_v2/rig-data.json"
var rig_phases: Dictionary = {}
var trace: Array[Dictionary] = []
var stance_tracks := {"baseline": {}, "candidate": {}}
var completed_stances: Array[Dictionary] = []
var candidate_phase := 0.0
var observed_cast := false
var paid_before := 0


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.begins_with("res://.godot/hex-contact-pilot-") or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("visible renderer and fresh contained hex-contact-pilot output required")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK or not _load_rig():
		_fail("pilot output or existing rig unavailable")
		return
	root.size = Vector2i(WIDTH, HEIGHT)
	root.visible = true
	game = BootstrapScene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.preference_overrides_are_transient = true
	game.preferences_persistence_allowed = false
	game.requested_capture_reduced_effects = false
	if game.element_audio != null:
		game.element_audio.set_process(false)
	game.world = game._new_wellspring_world(120)
	game.authoritative_session.world = game.world
	var world: SimWorld = game.world
	var actor: PlayerState = world.player(ACTOR_ID)
	if not game.champion_catalog.apply_to_player(actor, CHAMPION):
		_fail("Small champion unavailable")
		return
	game.selected_champion_id = CHAMPION
	if String(game.cartoon_champion_presenter.champions[CHAMPION].body_type) != "small":
		_fail("pilot champion is not the source Small body")
		return
	var start := _open_walk_start()
	if start == Vector2i.ZERO:
		_fail("source campus has no clear bounded eastward walk lane")
		return
	actor.reset_for_spawn(start)
	actor.spawn_protection_ticks = 0
	actor.aim_x = 1000
	actor.aim_y = 0
	var wire := int(game.ability_catalog.ability(game.ability_catalog.spell_id_at("water", "bolt")).wire_id)
	if not actor.place_proven_spell(0, wire):
		_fail("legal paid cast fixture could not equip Water Bolt")
		return
	game.actor_motion_history.clear()
	_sync_pilot()
	game._update_character_gaits(1.0 / 120.0)
	paid_before = int(world.hex_court.metrics.get("matter_paid", 0))
	var previous_point := Vector2(actor.position_x, actor.position_y) / 1000.0
	var previous_ground := ActorMotionHistory._ground_locomotion(actor)
	var previous_baseline_phase: float = game.actor_motion_history.gait_phase(ACTOR_ID)
	var body_height := float(game.cartoon_champion_presenter.champions[CHAMPION].get("height", 58.0))
	var baseline_stride := MinimalChampionMotion.locomotion_stride_pixels(body_height)
	if not is_equal_approx(baseline_stride, 75.4):
		_fail("source Small presentation stride differs from reviewed 75.4px")
		return
	var total_distance := 0.0
	var cap_samples := 0
	for step_index: int in 160:
		var moving_input := not (step_index >= 48 and step_index < 72)
		var pressed := int(SimCommand.SPELL_PRESSED_BITS[0]) if step_index == 96 else 0
		var target := Vector2i(actor.position_x + 128000, actor.position_y)
		var command := SimCommand.new(world.tick, ACTOR_ID, 1000 if moving_input else 0, 0, 0, pressed, 1000, 0, target.x, target.y)
		if not world.step([command]):
			_fail("ordinary pilot walking/casting command failed")
			return
		_sync_pilot()
		game._update_character_gaits(1.0 / 120.0)
		var point := Vector2(actor.position_x, actor.position_y) / 1000.0
		var distance := point.distance_to(previous_point)
		var ground := ActorMotionHistory._ground_locomotion(actor)
		var speed := Vector2(actor.velocity_x, actor.velocity_y).length() / 1000.0
		var candidate_before := candidate_phase
		var candidate_delta := 0.0
		var baseline_delta := 0.0
		var plausible_distance := minf(ActorMotionHistory.SNAP_DISTANCE_PIXELS, speed / 120.0 * 2.0 + 2.0)
		if ground and previous_ground and speed > 0.0 and distance <= plausible_distance:
			baseline_delta = minf(distance / baseline_stride, ActorMotionHistory.MAX_WALK_GAIT_CYCLES_PER_SECOND / 120.0)
			candidate_delta = minf(distance / CANDIDATE_STRIDE, ActorMotionHistory.MAX_WALK_GAIT_CYCLES_PER_SECOND / 120.0)
			if distance / CANDIDATE_STRIDE > ActorMotionHistory.MAX_WALK_GAIT_CYCLES_PER_SECOND / 120.0:
				cap_samples += 1
			candidate_phase = fposmod(candidate_phase + candidate_delta, 1.0)
		var baseline_phase: float = game.actor_motion_history.gait_phase(ACTOR_ID)
		if not is_equal_approx(baseline_phase, fposmod(previous_baseline_phase + baseline_delta, 1.0)):
			_fail("production gait clock reset or diverged during stop/restart/cast trace")
			return
		var baseline := _measure("baseline", actor, baseline_phase, point)
		var candidate := _measure("candidate", actor, candidate_phase, point)
		observed_cast = observed_cast or actor.pending_cast_wire_id == wire
		total_distance += distance
		trace.append({"step": step_index, "tick": world.tick, "input_move_x": command.move_x, "pressed": pressed, "state": Array(actor.canonical_values()), "world_hash": world.state_hash(), "root": [point.x, point.y], "distance": distance, "speed": speed, "ground_locomotion": ground, "baseline_phase": baseline_phase, "candidate_phase": candidate_phase, "candidate_before": candidate_before, "candidate_delta": candidate_delta, "baseline": baseline, "candidate": candidate})
		if step_index in SAMPLE_TICKS:
			if not await _capture_comparison(step_index, baseline_phase, candidate_phase):
				return
		previous_point = point
		previous_ground = ground
		previous_baseline_phase = baseline_phase
	for variant: String in ["baseline", "candidate"]:
		for side: String in ["l", "r"]:
			_close_stance(variant, side, "trace_end_partial")
	if total_distance <= 0.0 or not observed_cast or int(world.hex_court.metrics.get("matter_paid", 0)) != paid_before + 600 or not world.hex_court.conservation_valid():
		_fail("pilot requires real movement plus one accepted paid cast and conserved matter")
		return
	var source_paths := ["res://tests/visual/capture_hex_contact_pilot.gd", RIG_PATH, "res://src/presentation/actor_motion_history.gd", "res://src/presentation/minimal_champion_motion.gd", "res://src/presentation/cartoon_champion_presenter.gd", "res://src/presentation/wireframe_body_presenter.gd", "res://assets/sprites/wireframe_motion_v2/manifest.json", "res://assets/sprites/wireframe_motion_v2/small-locomotion.png"]
	var sources: Array[Dictionary] = []
	for path: String in source_paths:
		sources.append({"path": path, "sha256": FileAccess.get_sha256(path)})
	var receipt := {
		"status": "isolated_clock_comparison_only", "promotion": "NOT_PROMOTED",
		"runtime_identity": JSON.parse_string(FileAccess.get_file_as_string(RuntimeBuildIdentity.MANIFEST_PATH)),
		"champion": CHAMPION, "direction": "east aim/east walking", "baseline_stride": MinimalChampionMotion.locomotion_stride_pixels(58.0), "candidate_stride": CANDIDATE_STRIDE,
		"walk_cycle_cap": ActorMotionHistory.MAX_WALK_GAIT_CYCLES_PER_SECOND, "candidate_cap_samples": cap_samples,
		"root_trace_method": "one actual SimWorld command trace; each A/B draw uses identical world state/hash and differs only in temporary presentation gait phase",
		"input_schedule": "east walk steps0-47; release movement48-71; restart72-159; paid Water Bolt press96",
		"accepted_cast_observed": observed_cast, "production_phase_continuity_checked_each_tick": true, "matter_paid_delta": int(world.hex_court.metrics.get("matter_paid", 0)) - paid_before,
		"frames": frames, "trace": trace, "stances": completed_stances, "summaries": {"baseline": _summary("baseline"), "candidate": _summary("candidate")},
		"sources": sources, "render_scale": "unchanged native gameplay camera settings", "camera_zoom_percent": game.player_preferences.camera_zoom_percent,
		"measurement": "modelled ground-space ankle anchor from exported rig projection and actual selected held frame, plus production presenter offset; camera motion excluded by construction",
		"limitations": ["Not pixel-tracked rendered shoe contact", "Eight held frames; no interpolation or foot locking", "Export frame anchor and live pivot bob are included through points/offset; shoe sole extent not measured", "Groundedness uses source ankle z, not independently authored contact intervals", "Stop/trace-end stances may be partial and are labeled", "Only Small E/E walking; no gait or size expansion", "No network/performance/human acceptance", "No runtime or atlas promotion", "No one-pixel foot-lock claim"],
	}
	var file := FileAccess.open(output + "/capture-receipt.json", FileAccess.WRITE)
	if file == null:
		_fail("could not write contact pilot receipt")
		return
	file.store_string(JSON.stringify(receipt, "  ") + "\n")
	file.close()
	print("PASS isolated hex contact pilot frames=", frames.size(), " paid_cast=", observed_cast, " promotion=NOT_PROMOTED")
	quit(0)


func _load_rig() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RIG_PATH))
	if not parsed is Dictionary:
		return false
	for value: Variant in parsed.get("poses", []):
		if not value is Dictionary:
			continue
		var pose: Dictionary = value
		if String(pose.get("body", "")) == "small" and String(pose.get("state", "")) == "locomotion" and int(pose.get("aim", -1)) == 2 and int(pose.get("travel", -1)) == 2:
			rig_phases[int(pose.phase)] = {"points": pose.points.duplicate(true), "landmarks": pose.landmarks.duplicate(true)}
	return rig_phases.size() == 8


func _open_walk_start() -> Vector2i:
	for y: int in [1200000, 1100000, 1000000, 900000, 800000, 1400000]:
		for x: int in [1200000, 1000000, 800000, 600000]:
			var valid := true
			for offset: int in range(0, 769000, 16000):
				if not game.world.collision.can_occupy(Vector2i(x + offset, y), MovementTuning.PLAYER_RADIUS):
					valid = false
					break
			if valid:
				return Vector2i(x, y)
	return Vector2i.ZERO


func _sync_pilot() -> void:
	game.accumulator_seconds = 0.0
	game.current_position = game._player_position()
	game.previous_position = game.current_position
	game.previous_air_height = game.world.player(ACTOR_ID).air_height
	game._update_combat_cues(1.0 / 120.0)
	game._ingest_combat_cues(game.world.combat_events)
	game.actor_motion_history.capture(game.world.players)


func _capture_comparison(step_index: int, baseline: float, candidate: float) -> bool:
	var track: ActorMotionHistory.GaitTrack = game.actor_motion_history.gait_tracks.get(ACTOR_ID)
	if track == null:
		_fail("production gait track missing")
		return false
	var before: String = game.world.state_hash()
	track.phase = baseline
	var first := await _capture_frame("step-%03d-baseline" % step_index, "legal_trace_baseline", false)
	track.phase = candidate
	var second := await _capture_frame("step-%03d-candidate" % step_index, "legal_trace_candidate", false)
	track.phase = baseline
	if first.is_empty() or second.is_empty() or before != game.world.state_hash():
		_fail("A/B draw failed or changed simulation")
		return false
	return true


func _measure(variant: String, actor: PlayerState, phase: float, point: Vector2) -> Dictionary:
	var frame: Dictionary = game.cartoon_champion_presenter.movement_frame(CHAMPION, actor, float(game.world.tick), game.world.config, false, phase)
	if String(frame.get("gait_bank", "")) != "walk":
		for side: String in ["l", "r"]:
			_close_stance(variant, side, "left_walk_bank_partial")
		return {"measured": false, "animation_state": frame.get("animation_state", ""), "phase": phase}
	var phase_index := int(frame.get("gait_frame", -1))
	if not rig_phases.has(phase_index):
		return {"measured": false, "reason": "missing exported phase"}
	var pose: Dictionary = rig_phases[phase_index]
	var offset: Vector2 = frame.get("offset", Vector2.ZERO)
	var result := {"measured": true, "phase_index": phase_index, "offset": [offset.x, offset.y], "feet": {}}
	for side: String in ["l", "r"]:
		var joint: Array = pose.points["ankle_" + side]
		var landmark: Array = pose.landmarks["ankle_" + side]
		var grounded := absf(float(landmark[2])) < 0.000001
		var world_point := point + Vector2(float(joint[0]) - 48.0, float(joint[1]) - 84.0) + offset
		var tracks: Dictionary = stance_tracks[variant]
		if not grounded:
			_close_stance(variant, side, "support_released")
		else:
			if not tracks.has(side):
				tracks[side] = {"origin": world_point, "start_tick": game.world.tick, "start_phase": phase_index, "maximum": 0.0, "samples": 0}
			var stance: Dictionary = tracks[side]
			var delta: Vector2 = world_point - (stance.origin as Vector2)
			stance.maximum = maxf(float(stance.maximum), maxf(absf(delta.x), absf(delta.y)))
			stance.samples = int(stance.samples) + 1
		result.feet[side] = {"grounded_model": grounded, "point": [world_point.x, world_point.y], "stance_maximum": float((tracks.get(side, {}) as Dictionary).get("maximum", 0.0))}
	return result


func _close_stance(variant: String, side: String, reason: String) -> void:
	var tracks: Dictionary = stance_tracks[variant]
	if not tracks.has(side):
		return
	var stance: Dictionary = tracks[side]
	completed_stances.append({"variant": variant, "side": side, "start_tick": stance.start_tick, "end_tick": game.world.tick, "start_phase": stance.start_phase, "end_reason": reason, "samples": stance.samples, "maximum_drift_native_pixels": stance.maximum})
	tracks.erase(side)


func _summary(variant: String) -> Dictionary:
	var values: Array[float] = []
	for stance: Dictionary in completed_stances:
		if String(stance.variant) == variant:
			values.append(float(stance.maximum_drift_native_pixels))
	if values.is_empty():
		return {"stance_count": 0}
	values.sort()
	var total := 0.0
	for value: float in values:
		total += value
	return {"stance_count": values.size(), "mean_stance_maximum": total / values.size(), "maximum": values.back(), "partial_stances_included": true}
