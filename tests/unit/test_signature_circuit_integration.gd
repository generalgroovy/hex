extends FluxTestSuite

const Fixture = preload("res://tests/support/solo_trial_harness.gd")
const Counterplay = preload("res://tests/unit/test_signature_progression.gd")


func run() -> int:
	# Real match startup configures the process-global InputMap. Preserve the
	# exact caller action set, bindings and deadzones before fixture setup.
	var previous_input_map := _capture_input_map()
	var previous_mouse := Input.mouse_mode
	var game := Fixture.new()
	check(game.configure_trial_fixture(), "circuit fixture loads actual world and catalogs")
	(Engine.get_main_loop() as SceneTree).root.add_child(game)
	game.preferences_persistence_allowed = false
	game.preference_overrides_are_transient = true
	game.element_expansion.game = game
	game.local_navigation.configure(game)
	check(game.champion_catalog.apply_to_player(game.world.player(), "oh_tipi"), "circuit starts with the authored legal player kit")
	game.character_weaves.remember_actor(game.world.player())
	var normal_weave := game.world.player().spell_wire_ids.duplicate()
	var saved_weaves: Dictionary = game.character_weaves.session_weaves.duplicate(true)
	check(game.element_expansion.progression.configure(game.champion_catalog, game.ability_catalog, "user://circuit-integration-missing-%d.json" % Time.get_ticks_usec(), false), "circuit progression stays in memory")
	var expansion: RefCounted = game.element_expansion
	game.session_transport.mode = SessionTransport.Mode.CONNECTING
	check(not expansion.start_circuit(), "network-owned session cannot start local circuit")
	game.session_transport.mode = SessionTransport.Mode.OFFLINE
	game.tick_rate = 60
	check(not expansion.start_circuit(), "circuit cannot mislabel a nonstandard tick-rate session")
	game.tick_rate = 120
	check(expansion.start_circuit(), "actual controller starts first district rival")
	equal(String(expansion.challenge.definition.id), "wa_bidi", "first encounter is the real Rapid rival")
	check(game.interception_practice_active and expansion.challenge_active, "existing trial authority owns the encounter")
	check(not expansion.apply_circuit_action("circuit-next"), "live fight cannot advance")
	var counterplay := Counterplay.new()
	var previous_wire := 0
	for stage: int in 3:
		var rival_paid := 0
		var stepped := true
		var learned_paid := false
		var learned_released := false
		for unused: int in 8641:
			if expansion.challenge.trial.is_finished(): break
			var rival: SimCommand = expansion.rival_command()
			var player_command: SimCommand = counterplay._counter_command(game.world, expansion.challenge)
			if stage > 0 and game.world.tick == InterceptionPractice.READY_END:
				var target: PlayerState = game.world.player(2)
				var player: PlayerState = game.world.player(1)
				player_command = SimCommand.new(game.world.tick, 1, 0, 0, 0, SimCommand.PRESSED_SPELL_1, target.position_x-player.position_x, target.position_y-player.position_y, target.position_x, target.position_y)
			var commands: Array[SimCommand] = [player_command, rival]
			if rival == null or not game.world.step(commands):
				stepped = false
				break
			for event: Dictionary in game.world.combat_events:
				if String(event.get("type", "")) == "cast_started" and int(event.get("entity_id", 0)) == 2: rival_paid += 1
				if int(event.get("wire_id",event.get("source_wire_id",0))) == previous_wire:
					if String(event.get("type", "")) == "cast_started" and int(event.get("entity_id",0)) == 1: learned_paid = true
					if String(event.get("type", "")) in ["projectile_spawned","spray_fired"] and int(event.get("owner_id",0)) == 1: learned_released = true
			expansion.after_step()
		check(stepped and rival_paid > 0, "circuit leg includes real stepped paid rival pressure")
		if stage > 0: check(learned_paid and learned_released, "previous earned signature actually pays and releases in next encounter")
		equal(expansion.challenge.trial.phase, "victory", "ordinary paid counterplay wins leg %d" % stage)
		check(bool(expansion.challenge.reward.get("ok", false)), "only the real owned defeat supplies circuit reward")
		var result: Dictionary = expansion.circuit_view()
		equal(int(result.stage), stage, "result names the actual current leg")
		check(bool(result.result.get("qualified", false)), "circuit accepts actual clean challenge result")
		check(not bool(result.result.reward.saved), "memory-only fixture never claims persistent save")
		equal(expansion.progression.learned_ids().size(), stage + 1, "exactly one earned signature per completed leg")
		expansion.after_step()
		equal(expansion.circuit_view(), result, "duplicate observer callback leaves result and reward unchanged")
		previous_wire = int(expansion.challenge.definition.signature_wire)
		if stage < 2:
			check(expansion.apply_circuit_action("circuit-next-learned"), "explicit learned-spell choice admits next real encounter")
			equal(game.world.player().spell_wire_ids[0], previous_wire, "earned signature occupies temporary first slot")
			equal(game.world.player().health, game.world.player().health_maximum, "next encounter explicitly starts fresh health")
			equal(game.character_weaves.session_weaves, saved_weaves, "temporary signature does not rewrite normal weave")
	check(bool(expansion.circuit_view().complete), "third real victory completes bounded circuit")
	check(not expansion.apply_circuit_action("circuit-next"), "completion cannot fabricate a fourth rival")
	check(expansion.apply_circuit_action("circuit-try"), "completed route opens exact learned spell in Range")
	check(expansion.training.active and not bool(expansion.circuit_view().active), "Range transition releases circuit ownership")
	equal(MixtureCatalog.wire_for(expansion.training.selected_mask, expansion.training.selected_family), previous_wire, "practice preselects real final signature")
	check(game._start_match(120), "return uses real production transition")
	equal(game.world.player().spell_wire_ids, normal_weave, "normal saved weave returns unchanged")
	equal(expansion.progression.learned_ids().size(), 3, "earned spells survive leaving route and Range")
	check(expansion.start_circuit(), "a new optional route can begin")
	var rejected_world: SimWorld = game.world
	check(not expansion.start_challenge("not-a-rival"), "bad rival request rejects before transition")
	check(game.world == rejected_world and bool(expansion.circuit_view().active), "failed candidate does not destroy current route")
	game.world.player(2).health = 0
	game.world.tick += 1
	expansion.after_step()
	check(not bool(expansion.challenge.reward.get("ok", false)), "bare test health edit cannot counterfeit earned victory")
	check(not expansion.apply_circuit_action("circuit-next-learned"), "unqualified terminal result cannot equip or advance")
	check(expansion.apply_circuit_action("circuit-retry"), "unqualified attempt can retry the same real rival")
	equal(String(expansion.challenge.definition.id), "wa_bidi", "retry does not skip a leg")
	check(game._start_match(120), "external return cancels route")
	check(not bool(expansion.circuit_view().active) and expansion._circuit_spell_wire == 0, "external transition clears circuit-only state")
	game.free()
	_restore_input_map(previous_input_map)
	var restored_input_map := _capture_input_map()
	var before_actions: Array = previous_input_map.keys()
	var after_actions: Array = restored_input_map.keys()
	before_actions.sort()
	after_actions.sort()
	equal(after_actions, before_actions, "circuit teardown restores the original InputMap action set, including absent actions")
	for action: StringName in before_actions:
		if not restored_input_map.has(action): continue
		equal(restored_input_map[action].deadzone, previous_input_map[action].deadzone, "circuit teardown restores the exact action deadzone: %s" % action)
		equal(var_to_bytes_with_objects(restored_input_map[action].events), var_to_bytes_with_objects(previous_input_map[action].events), "circuit teardown restores ordered complete event bindings: %s" % action)
	Input.mouse_mode = previous_mouse
	equal(Input.mouse_mode, previous_mouse, "circuit teardown restores the caller mouse mode")
	return finish("signature-circuit-integration")


func _capture_input_map() -> Dictionary:
	var result := {}
	for action: StringName in InputMap.get_actions():
		var events: Array[InputEvent] = []
		for event: InputEvent in InputMap.action_get_events(action):
			events.append(event.duplicate(true))
		result[action] = {"deadzone": InputMap.action_get_deadzone(action), "events": events}
	return result


func _restore_input_map(snapshot: Dictionary) -> void:
	for action: StringName in InputMap.get_actions():
		if not snapshot.has(action):
			Input.action_release(action)
			InputMap.erase_action(action)
	for action: StringName in snapshot:
		if not InputMap.has_action(action):
			InputMap.add_action(action, float(snapshot[action].deadzone))
		InputMap.action_erase_events(action)
		for event: InputEvent in snapshot[action].events:
			InputMap.action_add_event(action, event.duplicate(true))
		InputMap.action_set_deadzone(action, float(snapshot[action].deadzone))
