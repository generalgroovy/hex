extends FluxTestSuite

const Run = preload("res://src/app/solo_duel_trial.gd")
const TrialPanel = preload("res://src/presentation/solo_duel_trial_panel.gd")
const Harness = preload("res://tests/support/solo_trial_harness.gd")


func run() -> int:
	_test_bookkeeping()
	_test_input_and_geometry()
	_test_actual_paid_win_and_bootstrap_lifecycle()
	_test_directory_admission()
	return finish("solo-duel-trial")


func _fixture_world() -> SimWorld:
	var world := SimWorld.new()
	world.player().position_x = 100000
	world.player().position_y = 100000
	world.player().team_id = 1
	var opponent := PlayerState.new(2)
	opponent.position_x = 200000
	opponent.position_y = 100000
	opponent.team_id = 2
	world.players.append(opponent)
	return world


func _test_bookkeeping() -> void:
	var model := Run.new()
	check(not model.begin(null, Rect2i(0,0,800,600)), "null trial refuses")
	var world := _fixture_world()
	check(model.begin(world, Rect2i(0,0,800,600)), "two opposing living actors begin a local trial")
	equal(model.phase, Run.READY, "fresh attempt starts with four-second countdown")
	check(model.blocks_gameplay() and not model.is_finished(), "countdown blocks gameplay without becoming a result")
	check(not model.observe(world), "unstepped tick cannot count a batch twice")
	world.tick = 480
	world.combat_events = [{"type":"projectile_spawned", "owner_id":2, "projectile_id":17},
		{"type":"cast_started", "entity_id":1},
		{"type":"spray_intercepted", "owner_id":1, "projectile_id":17, "outcome":1},
		{"type":"spray_intercepted", "owner_id":1, "projectile_id":17, "outcome":1},
		{"type":"spray_intercepted", "owner_id":1, "projectile_id":18, "outcome":1},
		{"type":"spray_intercepted", "owner_id":2, "projectile_id":17, "outcome":1}]
	var before := world.state_hash()
	check(model.observe(world), "new authoritative tick is observed")
	equal(world.state_hash(), before, "bookkeeping never writes simulation authority")
	equal(model.phase, Run.ACTIVE, "exact countdown boundary enables combat")
	equal(model.interceptions, 1, "only known enemy successful interceptions count, once per projectile")
	equal(model.paid_casts, 1, "paid cast tally comes from accepted local cast events")
	check(not model.observe(world), "duplicate tick cannot duplicate score")
	world.tick += 1
	world.combat_events = [{"type":"spray_intercepted", "owner_id":1, "projectile_id":17, "outcome":2}]
	model.observe(world)
	equal(model.interceptions, 1, "a stopped Spray never increases clean interceptions")
	world.player(2).health = 0 # Unit transition fixture, not gameplay success proof.
	world.tick += 1
	model.observe(world)
	equal(model.phase, Run.VICTORY, "actual observed opponent defeat ends the run")
	var final_view: Dictionary = model.view()
	world.tick += 900
	world.player().health = 0
	check(not model.observe(world), "terminal result is immutable")
	equal(model.view(), final_view, "later authority cannot rewrite frozen result")
	for outcome: String in [Run.DEFEATED, Run.TIMEOUT, Run.LEFT_COURT]:
		world = _fixture_world()
		check(model.begin(world, Rect2i(0,0,800,600)), "retry begins cleanly after a result")
		world.tick = 8640 if outcome == Run.TIMEOUT else 1
		if outcome == Run.DEFEATED:
			world.player().health = 0
			world.player(2).health = 0
		elif outcome == Run.LEFT_COURT:
			world.player().position_x = 800000
		model.observe(world)
		equal(model.phase, outcome, "mutual defeat, timeout and exact outer boundary have explicit outcomes")
		equal(model.interceptions, 0, "retry clears prior score")
	world = _fixture_world()
	check(model.begin(world, Rect2i(0,0,800,600)), "fresh authority binds")
	var impostor := _fixture_world()
	impostor.tick = 10
	check(not model.observe(impostor), "a different world cannot finish the run")
	model.reset()
	equal(model.phase, Run.IDLE, "return removes local run")


func _test_input_and_geometry() -> void:
	for size: Vector2 in [Vector2(1280,720), Vector2(960,540)]:
		var boxes := TrialPanel.geometry(size)
		check(Rect2(Vector2.ZERO, size).encloses(boxes.panel), "trial panel fits supported compact viewport")
		check((boxes.panel as Rect2).encloses(boxes.primary) and (boxes.panel as Rect2).encloses(boxes.secondary), "both result actions stay inside panel")
		check(not (boxes.primary as Rect2).intersects(boxes.secondary), "trial actions never overlap")
	equal(TrialPanel.intent(_key(KEY_ENTER), Vector2.ZERO, Vector2(1280,720), 0), "primary", "Enter activates selected start/retry")
	equal(TrialPanel.intent(_key(KEY_ENTER), Vector2.ZERO, Vector2(1280,720), 1), "secondary", "Enter respects return selection")
	equal(TrialPanel.intent(_key(KEY_ESCAPE), Vector2.ZERO, Vector2(1280,720), 0), "cancel", "Escape closes or returns")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_DPAD_RIGHT
	pad.pressed = true
	equal(TrialPanel.intent(pad, Vector2.ZERO, Vector2(1280,720), 0), "toggle", "D-pad moves result selection")
	pad.button_index = JOY_BUTTON_A
	equal(TrialPanel.intent(pad, Vector2.ZERO, Vector2(1280,720), 0), "primary", "A starts or retries")


func _test_actual_paid_win_and_bootstrap_lifecycle() -> void:
	var node := Harness.new()
	check(node.configure_trial_fixture(), "real Bootstrap lifecycle fixture configures without saved preference writes")
	(Engine.get_main_loop() as SceneTree).root.add_child(node)
	var original_champion := node.selected_champion_id
	var original_weave := node.world.player().spell_wire_ids.duplicate()
	var before := node.world
	node.session_transport.mode = SessionTransport.Mode.CONNECTING
	check(not node._start_interception_trial(), "online/connect-in-progress refuses trial")
	check(node.world == before, "online refusal preserves exact current world")
	node.session_transport.mode = SessionTransport.Mode.OFFLINE
	check(node._open_solo_trial_menu(), "visible local entry opens deliberate briefing")
	check(node.solo_trial_menu_open and node._gameplay_input_blocked(), "briefing quarantines gameplay")
	check(node._start_interception_trial(), "production start prepares ordinary whole-hex world and paid loaner kit")
	equal(node.selected_champion_id, original_champion, "loaner does not overwrite selected champion")
	equal(node.world.players.size(), 2, "trial contains exactly player and real opponent")
	equal(node.session_names_by_entity.get(2, ""), "Oh Tipi", "trial rival world label identifies the actual champion")
	check(node.world.hex_court != null, "trial uses current whole-hex authority, not obsolete legacy chemistry")
	check(not node._solo_trial_frozen(), "ready trial is not frozen")
	var opponent_start := node.world.player(2).health
	var casts := 0
	var hits := 0
	var all_steps := true
	while node.solo_trial.is_running() and node.world.tick < InterceptionPractice.DURATION_TICKS:
		var command := Harness.attacking_command(node.world, node.solo_trial.phase == Run.READY)
		if not node.step_trial(command):
			all_steps = false
			break
		for event: Dictionary in node.world.combat_events:
			if String(event.get("type", "")) == "cast_started" and int(event.get("entity_id", 0)) == 1: casts += 1
			if String(event.get("type", "")) == "projectile_hit" and int(event.get("owner_id", 0)) == 1 and int(event.get("target_id", 0)) == 2: hits += 1
	print("SOLO_DUEL_ENCOUNTER phase=%s ticks=%d player_health=%d rival_health=%d paid_casts=%d hits=%d interceptions=%d" % [node.solo_trial.phase, node.world.tick, node.world.player(1).health, node.world.player(2).health, casts, hits, node.solo_trial.interceptions])
	check(all_steps, "every ordinary real trial step is admitted")
	check(casts > 0 and hits > 0, "success path includes actual paid player casts and opposing actor hits")
	check(opponent_start > 0 and node.world.player(2).health == 0, "ordinary paid attacks defeat the initially living rival")
	equal(node.solo_trial.phase, Run.VICTORY, "real paid combat can clear the trial before the deadline")
	check(node._solo_trial_frozen(), "result freezes only the actual completed offline trial")
	var result_tick := node.world.tick
	check(not node.step_trial(Harness.attacking_command(node.world)), "finished local trial refuses another helper step")
	equal(node.world.tick, result_tick, "no post-result authority tick is consumed")
	check(node._start_interception_trial(), "retry goes through actual production start")
	equal(node.world.tick, 0, "retry owns a fresh authority clock")
	equal(node.solo_trial.interceptions, 0, "retry clears results")
	check(node.world.player().health == node.world.player().health_maximum and node.world.player(2).health == node.world.player(2).health_maximum, "retry starts fresh champions, not mid-encounter resource cheats")
	check(node._start_match(120), "return goes through production Wellspring lifecycle")
	equal(node.selected_champion_id, original_champion, "return keeps the previously selected champion")
	equal(node.world.player().spell_wire_ids, original_weave, "return restores exact pre-trial weave, not the loaner")
	check(not node.interception_practice_active and node.solo_trial.phase == Run.IDLE, "return clears trial ownership")
	check(not node.session_names_by_entity.has(2), "return clears trial rival name instead of leaking into other sessions")
	node.free()


func _test_directory_admission() -> void:
	var node := Harness.new()
	check(node.configure_trial_fixture(), "directory trial fixture configures")
	(Engine.get_main_loop() as SceneTree).root.add_child(node)
	var door_id := ""
	for id: String in node.campus_layout.stations_by_id:
		if String(node.campus_layout.stations_by_id[id].get("command", "")) == "impact_practice": door_id = id
	check(not door_id.is_empty(), "trial reuses existing real practice front door")
	var door := SanctumCampusLayout._parse_point(node.campus_layout.stations_by_id[door_id].position)
	node.world.player().position_x = door.x * 1000
	node.world.player().position_y = (door.y + 12) * 1000
	node.focused_station_id = door_id
	node._open_focused_service_directory()
	check(node.service_directory.is_open, "normal interact directory opens")
	var trial_index := -1
	for index: int in node.service_directory.entries.size():
		if String(node.service_directory.entries[index].id) == node.SOLO_TRIAL_STATION: trial_index = index
	check(trial_index >= 0, "trial is a real visible navigable practice card")
	if trial_index >= 0:
		node.service_directory.selected_index = trial_index
		node._refresh_directory_availability()
		check(node.service_directory.selected_available(), "offline player at real door can select trial")
		var pad := InputEventJoypadButton.new()
		pad.button_index = JOY_BUTTON_A
		pad.pressed = true
		node._handle_service_directory_input(pad)
		check(node.solo_trial_menu_open and not node.service_directory.is_open, "controller A dispatches card into briefing without a gameplay input")
		node.solo_trial_menu_open = false
		node._open_focused_service_directory()
		node.world.player().position_x = 100000
		node._dispatch_directory_station(node.SOLO_TRIAL_STATION)
		check(not node.solo_trial_menu_open, "stale card revalidates actual front-door reach")
	node.free()


func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event
