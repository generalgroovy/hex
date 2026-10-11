extends FluxTestSuite

const Fixture = preload("res://tests/support/solo_trial_harness.gd")
const TrialRun = preload("res://src/app/solo_duel_trial.gd")


class ProcessHarness:
	extends "res://src/app/bootstrap.gd"
	# Keep the entire production frame/input/authority flow. Isolate only boot,
	# rendering, OS notifications and the unrelated material diagnostic texture.
	func _ready() -> void:
		set_process(false)
	func _draw() -> void:
		pass
	func _notification(_what: int) -> void:
		pass
	func _refresh_material_preview() -> void:
		pass


func run() -> int:
	var original_mouse_mode := Input.mouse_mode
	var fixture := Fixture.new()
	check(fixture.configure_trial_fixture(), "production frame fixture loads actual current dependencies")
	var node := ProcessHarness.new()
	for property: String in ["ability_catalog", "champion_catalog", "campus_layout", "world", "session_transport", "authoritative_session", "session_round_values", "spectator_focus", "controls_editor", "spell_loom_editor", "player_compendium", "character_selection_grid", "player_preferences", "material_registry", "material_yard", "input_router", "character_weaves", "current_position", "previous_position"]:
		node.set(property, fixture.get(property))
	node.preference_overrides_are_transient = true
	fixture.free()
	(Engine.get_main_loop() as SceneTree).root.add_child(node)
	var original_weave := node.world.player().spell_wire_ids.duplicate()
	var original_champion := node.selected_champion_id
	check(node._start_interception_trial(), "actual frame test enters real production trial")
	Input.action_press(&"spell_3")
	var opponent_paid := 0
	var player_paid := 0
	var frames := 0
	while node.world.tick < 650 and frames < 660:
		node._process(1.0 / 120.0)
		frames += 1
		for event: Dictionary in node.world.combat_events:
			if String(event.get("type", "")) != "cast_started": continue
			if int(event.get("entity_id", 0)) == 2: opponent_paid += 1
			if int(event.get("entity_id", 0)) == 1: player_paid += 1
		if node.world.tick < InterceptionPractice.READY_END:
			equal(node.solo_trial.phase, TrialRun.READY, "production neutral countdown remains READY until its exact authority boundary")
	check(node.world.tick >= 650, "inherited Bootstrap process really advances authority")
	equal(node.solo_trial.phase, TrialRun.ACTIVE, "actual frame loop transitions countdown into active combat")
	check(opponent_paid > 0, "Bootstrap injects the real rival command and admits a paid attack")
	equal(player_paid, 0, "spell held across countdown is quarantined rather than leaking into active gameplay")
	var trial_world := node.world
	node._unhandled_input(_key(KEY_F4))
	check(not node.player_compendium.is_open, "active trial cannot open conflicting Compendium modal")
	Input.action_press(&"reset_match")
	node._process(1.0 / 120.0)
	Input.action_release(&"reset_match")
	check(node.world == trial_world, "ordinary Reset input cannot replace the active trial")
	Input.action_release(&"spell_3")
	node._process(1.0 / 120.0)
	Input.action_press(&"spell_3")
	node._process(1.0 / 120.0)
	var fresh_paid := false
	for event: Dictionary in node.world.combat_events:
		fresh_paid = fresh_paid or (String(event.get("type", "")) == "cast_started" and int(event.get("entity_id", 0)) == 1)
	check(fresh_paid, "release then fresh paid spell press is admitted by the unchanged InputRouter and production frame loop")
	Input.action_release(&"spell_3")
	Input.action_press(&"move_left")
	frames = 0
	while node.solo_trial.is_running() and frames < 240:
		node._process(1.0 / 120.0)
		frames += 1
	Input.action_release(&"move_left")
	equal(node.solo_trial.phase, TrialRun.LEFT_COURT, "ordinary sampled movement crosses the court and ends the live trial")
	var final_tick := node.world.tick
	var final_hash := node.world.state_hash()
	var final_results: Dictionary = node.solo_trial.view()
	Input.action_press(&"spell_4")
	for frame: int in 12:
		node._process(0.1)
	equal(node.world.tick, final_tick, "actual frame loop consumes no authority ticks after terminal result")
	equal(node.world.state_hash(), final_hash, "actual result freeze preserves exact final simulation authority")
	equal(node.solo_trial.view(), final_results, "results remain immutable across later frames")
	check(node._solo_trial_frozen(), "only completed offline attempt owns the freeze")
	node.session_transport.mode = SessionTransport.Mode.CONNECTING
	check(not node._solo_trial_frozen(), "local result flag cannot freeze a transport-owned session")
	node.session_transport.mode = SessionTransport.Mode.OFFLINE
	node._unhandled_input(_key(KEY_ESCAPE))
	check(not node.interception_practice_active and node.solo_trial.phase == TrialRun.IDLE, "real result Escape handler returns and clears trial state")
	equal(node.selected_champion_id, original_champion, "actual result return preserves selected identity")
	equal(node.world.player().spell_wire_ids, original_weave, "actual result return restores the pre-trial weave")
	var return_tick := node.world.tick
	var leaked_casts := 0
	for frame: int in 10:
		node._process(1.0 / 120.0)
		for event: Dictionary in node.world.combat_events:
			if String(event.get("type", "")) == "cast_started" and int(event.get("entity_id", 0)) == 1: leaked_casts += 1
	check(node.world.tick > return_tick, "normal Wellspring authority stepping resumes after leaving results")
	equal(leaked_casts, 0, "spell held on result screen cannot leak through return-to-Wellspring handoff")
	Input.action_release(&"spell_4")
	node.free()
	Input.mouse_mode = original_mouse_mode
	return finish("solo-trial-process")


func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event
