extends "res://tests/visual/capture_warm_style_trails.gd"

const TrialHarness = preload("res://tests/support/solo_trial_harness.gd")
const TrialRun = preload("res://src/app/solo_duel_trial.gd")
const Rival = preload("res://src/app/solo_duel_rival.gd")


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if not output.begins_with("res://.godot/solo-duel-trial-") or ".." in output or DirAccess.dir_exists_absolute(output):
		fail("Provide a fresh res://.godot/solo-duel-trial- output directory")
		return
	node = TrialHarness.new()
	if not node.configure_trial_fixture(true) or DirAccess.make_dir_recursive_absolute(output) != OK:
		fail("Trial render fixture could not configure")
		return
	node.player_preferences.set_camera_zoom_percent(75)
	node.player_preferences.pov_mode = PlayerPreferences.POV_FULL
	var trial_champions: Array[String] = ["oh_tipi", "s_wayne"]
	if not node.cartoon_champion_presenter.enable_fullbody_art(false, true):
		fail("Production pixel-cast artwork admission failed")
		return
	if not node.cartoon_champion_presenter.prepare_override_pages(trial_champions):
		fail("Practice champion artwork could not prepare")
		return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(node)
	if not await capture("01-entry", {"kind":"normal_trial_entry"}): return
	if not node._open_solo_trial_menu():
		fail("Production briefing would not open")
		return
	if not await capture("02-briefing", {"kind":"loaner_disclosure_and_actual_bindings"}): return
	viewport.size = Vector2i(960, 540)
	if not await capture("03-briefing-compact", {"kind":"compact_loaner_disclosure"}): return
	viewport.size = Vector2i(1280, 720)
	if not node._start_interception_trial():
		fail("Production paid trial setup refused")
		return
	if not await capture("04-countdown", {"kind":"four_second_authority_countdown"}): return
	var paid_casts := 0
	var paid_hits := 0
	var active_captured := false
	var captured_rival_phases := {}
	var pause_tail_captured := false
	while node.solo_trial.is_running():
		var command := TrialHarness.attacking_command(node.world, node.solo_trial.phase == TrialRun.READY)
		if not node.step_trial(command):
			fail("Ordinary paid attack step refused")
			return
		for event: Dictionary in node.world.combat_events:
			if String(event.get("type", "")) == "cast_started" and int(event.get("entity_id", 0)) == 1: paid_casts += 1
			if String(event.get("type", "")) == "projectile_hit" and int(event.get("owner_id", 0)) == 1 and int(event.get("target_id", 0)) == 2: paid_hits += 1
		node._update_combat_cues(1.0 / 120.0)
		node._ingest_combat_cues(node.world.combat_events)
		var rival_status := Rival.status(node.world.tick, int(node.interception_practice_setup.start_tick))
		var rival_phase := String(rival_status.get("phase", ""))
		var world_tell: Dictionary = node._solo_rival_world_tell(node.world.player(2))
		var phase_cue_ready := rival_phase != Rival.RECOVER or String(world_tell.get("kind", "")) == "pause"
		if phase_cue_ready and rival_phase in [Rival.WINDUP, Rival.PRESSURE, Rival.RECOVER] and not captured_rival_phases.has(rival_phase):
			captured_rival_phases[rival_phase] = true
			if not await capture("05-rival-" + rival_phase, {"kind":"ordinary_paid_rival_phase", "tick":node.world.tick, "policy":rival_status, "world_tell":world_tell}): return
			node.requested_capture_reduced_effects = true
			if not await capture("05-rival-" + rival_phase + "-reduced", {"kind":"same_authority_reduced_effects", "tick":node.world.tick, "policy":rival_status, "world_tell":world_tell}): return
			node.requested_capture_reduced_effects = false
		if not pause_tail_captured and String(world_tell.get("kind", "")) == "pause" and int(world_tell.get("segments", 0)) == 1:
			pause_tail_captured = true
			if not await capture("05-pause-last-segment", {"kind":"ordinary_paid_pause_last_segment", "tick":node.world.tick, "world_tell":world_tell}): return
			viewport.size = Vector2i(960, 540)
			if not await capture("05-pause-compact", {"kind":"same_authority_compact_pause", "tick":node.world.tick, "world_tell":world_tell}): return
			viewport.size = Vector2i(1280, 720)
		if not active_captured and node.world.tick >= 650:
			active_captured = true
			if not await capture("05-active-paid-combat", {"kind":"ordinary_paid_live_trial", "tick":node.world.tick}): return
	if node.solo_trial.phase != TrialRun.VICTORY or paid_casts <= 0 or paid_hits <= 0 or captured_rival_phases.size() != 3 or not pause_tail_captured:
		fail("Ordinary paid actions did not actually clear the trial")
		return
	var victory: Dictionary = node.solo_trial.view()
	if not await capture("06-real-victory", {"kind":"real_paid_victory", "results":victory, "paid_casts":paid_casts, "paid_hits":paid_hits}): return
	viewport.size = Vector2i(960, 540)
	if not await capture("07-victory-compact", {"kind":"real_paid_victory_compact"}): return
	viewport.size = Vector2i(1280, 720)
	if not node._start_interception_trial():
		fail("Retry after victory refused")
		return
	while node.solo_trial.is_running():
		var leaving: bool = node.solo_trial.phase == TrialRun.ACTIVE
		var command := SimCommand.new(node.world.tick, 1, -1000 if leaving else 0, 0, 0, 0, 1000, 0)
		if not node.step_trial(command):
			fail("Ordinary movement could not test court exit")
			return
	if node.solo_trial.phase != TrialRun.LEFT_COURT:
		fail("Walking over the marked boundary did not end the attempt")
		return
	if not await capture("08-left-court", {"kind":"real_ordinary_movement_boundary_loss"}): return
	# These two terminal render fixtures are explicitly staged to isolate layout.
	# They are not claimed as separate full human/duration/paid-defeat playthroughs.
	for outcome: String in [TrialRun.DEFEATED, TrialRun.TIMEOUT]:
		if not node._start_interception_trial():
			fail("Terminal fixture setup refused")
			return
		if outcome == TrialRun.DEFEATED:
			node.world.player().health = 0
			node.world.tick = 1
		else:
			node.world.tick = InterceptionPractice.DURATION_TICKS
		node.solo_trial.observe(node.world)
		if not await capture("09-" + outcome, {"kind":"explicitly_staged_terminal_layout", "phase":outcome}): return
	if not node._start_match(120):
		fail("Return to Wellspring refused")
		return
	if not await capture("10-return", {"kind":"production_return_to_selected_champion_and_weave"}): return
	var receipt := FileAccess.open(output.path_join("trial-receipt.json"), FileAccess.WRITE)
	receipt.store_string(JSON.stringify({"schema_version":1, "frames":records,
		"render_path":"actual production Bootstrap drawing in native Godot SubViewport with admitted pixel-cast artwork",
		"victory":victory, "paid_casts":paid_casts, "paid_hits":paid_hits,
		"victory_source":"fresh production whole-hex world, real paid equipped Fire Bolt commands and normal opponent commands only",
		"boundary_source":"ordinary leftward movement until crossing actual marked court",
		"staged_terminal_layouts":["defeated", "timeout"],
		"input":"synthetic ordinary commands; not physical keyboard/controller acceptance",
		"authority_unchanged_by_draw":true, "human_acceptance":"not_run", "network":"not_started"}, "  "))
	receipt.close()
	print("SOLO_DUEL_TRIAL_CAPTURE ", JSON.stringify({"output":output, "frames":records.size(), "victory":victory, "paid_casts":paid_casts, "paid_hits":paid_hits}))
	quit(0)
