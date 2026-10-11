extends FluxTestSuite


const BootstrapScript = preload("res://src/app/bootstrap.gd")
const Card = preload("res://src/presentation/hex_demo_result_card.gd")


class ResultHarness:
	extends "res://src/app/bootstrap.gd"
	# Inherit real view, eligibility, reconciliation, notifications and input.
	# Suppress only automatic boot/frame work and rendering: no sockets, audio,
	# settings IO or competing simulation loop belongs in this integration test.
	func _ready() -> void:
		set_process(false)
		set_process_unhandled_input(true)
	func _draw() -> void:
		pass


class NoSavePreferences:
	extends PlayerPreferences
	var save_attempts := 0
	func save_to_file(_path: String = DEFAULT_PATH) -> bool:
		save_attempts += 1
		return true


func run() -> int:
	_test_paid_completion_reaches_inactive_view()
	_test_real_context_invalidation()
	_test_actual_input_dismissal()
	_test_frame_and_draw_hooks()
	return finish("demo-result-integration")


func _configure(node: Node) -> bool:
	node.preference_overrides_are_transient = true
	node.preferences_persistence_allowed = false
	node.ability_catalog = AbilityCatalog.new()
	node.campus_layout = SanctumCampusLayout.new()
	if not node.ability_catalog.load_from_file(node.ABILITY_CATALOG_PATH) or not node.campus_layout.load_from_file(node.CAMPUS_LAYOUT_PATH):
		return false
	node.world = node._new_wellspring_world(120)
	if node.world == null:
		return false
	node.session_transport = SessionTransport.new()
	node.authoritative_session = AuthoritativeSession.new()
	node.authoritative_session.world = node.world
	node.session_round_values = node.authoritative_session.session_round.capture(node.world)
	node.spectator_focus = SpectatorFocus.new()
	node.controls_editor = ControlBindingEditor.new()
	node.spell_loom_editor = SpellLoomEditor.new()
	node.player_compendium = node.PlayerCompendiumScript.new()
	node.character_selection_grid = node.CharacterSelectionGridScript.new()
	node.player_preferences = NoSavePreferences.new()
	node.application_input_active = true
	node.controls_input_guard_frames = 0
	var actor: PlayerState = node.world.player()
	actor.reset_for_spawn(HexPlaygroundDemo.BENCH)
	actor.spawn_protection_ticks = 0
	actor.flux_recovery_per_second = 0
	actor.health_recovery_per_second = 0
	var restored := actor.spell_wire_ids.duplicate()
	restored.reverse()
	return CharacterWeavePolicy.apply(actor, restored) and node.world.is_valid()


func _paid_result(node: Node) -> bool:
	var actor: PlayerState = node.world.player()
	var weave_before := actor.spell_wire_ids.duplicate()
	var flux_before := actor.flux
	var paid_before := int(node.world.hex_court.metrics.matter_paid)
	check(node.hex_playground_demo.begin(node.world, actor.entity_id, "water", "fire", node.ability_catalog), "integration starts the actual two-Bolt paid demo")
	for unused: int in 900:
		if not node.hex_playground_demo.is_active():
			break
		var command: SimCommand = node.hex_playground_demo.command(node.world)
		if command == null:
			break
		# Dynamic Bootstrap properties cannot supply typed-array inference at
		# this call boundary; preserve SimWorld's actual command contract.
		var commands: Array[SimCommand] = [command]
		if not node.world.step(commands):
			check(false, "actual demo commands remain accepted by the production whole-hex world")
			return false
	check(not node.hex_playground_demo.is_active(), "the real paid demo reaches its finite inactive state")
	var result: Dictionary = node.hex_playground_demo.terminal_result()
	if result.is_empty():
		check(false, "actual demo retains a terminal receipt")
		return false
	equal(String(result.outcome), "complete", "integration uses observed production chemistry, not a fabricated result")
	equal(int(result.paid_casts), 2, "integration paid two ordinary casts")
	equal(int(node.world.hex_court.metrics.matter_paid), paid_before + 1200, "world records both actual ingredient payments")
	equal(actor.flux, flux_before - int(result.paid_flux), "recorded gross Flux equals actual spending with fixture recovery disabled")
	equal(actor.spell_wire_ids, weave_before, "real completion restores the exact reversed original weave")
	check(not result.observed_product.is_empty(), "integration result contains an actually formed product")
	return String(result.outcome) == "complete"


func _assert_read_only(node: Node, label: String) -> void:
	var before: String = node.world.state_hash()
	var actor_before: PackedInt64Array = node.world.player().canonical_values()
	var preferences: Dictionary = node.player_preferences.to_dictionary().duplicate(true)
	var view: Dictionary = node._demo_result_view()
	check(not view.is_empty(), label + " exposes a real retained result through bootstrap")
	node._reconcile_demo_result()
	check(not node._demo_result_view().is_empty(), label + " remains visible after normal reconciliation")
	check(not node._gameplay_input_blocked(), label + " does not take gameplay ownership")
	check(node.hex_playground_demo.command(node.world) == null, label + " cannot generate another automatic command")
	equal(node.world.state_hash(), before, label + " leaves all world authority unchanged")
	equal(node.world.player().canonical_values(), actor_before, label + " leaves weave, resources and cooldowns unchanged")
	equal(node.player_preferences.to_dictionary(), preferences, label + " cannot rewrite bindings")


func _test_paid_completion_reaches_inactive_view() -> void:
	# This case constructs the production script itself, with no overridden path.
	var node := BootstrapScript.new()
	var configured := _configure(node)
	check(configured, "real BootstrapScript fixture loads normal catalog and campus authority")
	if not configured:
		node.free()
		return
	var completed: bool = _paid_result(node) == true
	check(completed, "paid integration helper must reach completion, including when a script error aborts it")
	if completed:
		_assert_read_only(node, "offline completion")
		node.session_transport.mode = SessionTransport.Mode.HOSTING
		_assert_read_only(node, "authoritative Hearth host completion")
	check(node.input_router == null and node.element_audio == null, "read-only result integration creates no InputMap writer or audio playback")
	node.free()


func _cancelled_result(node: Node) -> void:
	# Refresh through the real public lifecycle, never by assigning result fields.
	check(node.hex_playground_demo.begin(node.world, 1, "water", "fire", node.ability_catalog), "context fixture begins a legal finite demo")
	node.hex_playground_demo.cancel(node.world)
	equal(String(node.hex_playground_demo.terminal_result().outcome), "canceled", "context fixture has an actual canceled terminal result")
	check(not node._demo_result_view().is_empty(), "eligible context starts with a visible retained card")


func _assert_invalidated(node: Node, label: String) -> void:
	var before: String = node.world.state_hash()
	var preferences: Dictionary = node.player_preferences.to_dictionary().duplicate(true)
	check(node._demo_result_view().is_empty(), label + " immediately hides the card")
	node._reconcile_demo_result()
	check(not node.hex_playground_demo.has_terminal_result(), label + " clears the actual retained result rather than merely hiding it")
	check(node.hex_playground_demo.command(node.world) == null, label + " does not create an automatic retry")
	equal(node.world.state_hash(), before, label + " changes no simulation authority")
	equal(node.player_preferences.to_dictionary(), preferences, label + " changes no saved preferences")


func _test_real_context_invalidation() -> void:
	var node := BootstrapScript.new()
	var configured := _configure(node)
	check(configured, "context gates use the actual unbooted BootstrapScript")
	if not configured:
		node.free()
		return
	for panel: RefCounted in [node.controls_editor, node.spell_loom_editor, node.player_compendium, node.character_selection_grid, node.service_directory]:
		_cancelled_result(node)
		panel.set("is_open", true)
		_assert_invalidated(node, "Controls/Loom/Compendium/Gallery/service modal")
		panel.set("is_open", false)
		check(node._demo_result_view().is_empty(), "closing a modal does not resurrect discarded instructions")
	for property: String in ["join_address_editor_open", "hex_playground_open", "solo_trial_menu_open", "interception_practice_active"]:
		_cancelled_result(node)
		node.set(property, true)
		_assert_invalidated(node, property)
		node.set(property, false)
	_cancelled_result(node)
	node._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not node.application_input_active, "actual focus notification updates eligibility")
	_assert_invalidated(node, "application focus loss")
	node._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	node.controls_input_guard_frames = 0
	_cancelled_result(node)
	node.controls_input_guard_frames = 1
	_assert_invalidated(node, "modal input rearm guard")
	node.controls_input_guard_frames = 0
	for accepted: bool in [false, true]:
		_cancelled_result(node)
		node.session_transport.mode = SessionTransport.Mode.CLIENT
		node.session_transport.accepted = accepted
		_assert_invalidated(node, "connecting/connected client session")
		node.session_transport.mode = SessionTransport.Mode.OFFLINE
		node.session_transport.accepted = false
	_cancelled_result(node)
	node.session_transport.mode = SessionTransport.Mode.CLIENT
	node.session_transport.accepted = true
	node.spectator_focus.active = true
	node.spectator_focus.focus_entity_id = 1
	check(node._is_spectating(), "spectator invalidation reaches the actual production spectator predicate")
	_assert_invalidated(node, "spectator camera")
	node.spectator_focus.reset()
	node.session_transport.mode = SessionTransport.Mode.OFFLINE
	node.session_transport.accepted = false
	_test_round_invalidation(node)
	_cancelled_result(node)
	var old_world: SimWorld = node.world
	node.world = node._new_wellspring_world(120)
	node.authoritative_session.world = node.world
	var replacement_before: String = node.world.state_hash()
	node._reconcile_demo_result()
	check(not node.hex_playground_demo.has_terminal_result(), "same-ID actor in replacement world loses stale result context")
	check(node._demo_result_view().is_empty(), "replacement world cannot show the previous run's card after reconciliation")
	equal(node.world.state_hash(), replacement_before, "world replacement reconciliation is read-only")
	check(old_world != node.world, "replacement-world fixture actually changes authority identity")
	node.free()


func _test_round_invalidation(node: Node) -> void:
	var guest := PlayerState.new(2)
	guest.team_id = 2
	node.world.players.append(guest)
	node.session_transport.mode = SessionTransport.Mode.HOSTING
	var round: SessionRound = node.authoritative_session.session_round
	for phase: int in [SessionRound.Phase.ACTIVE, SessionRound.Phase.RESULT]:
		_cancelled_result(node)
		round.scores_by_entity = {1: 0, 2: 0}
		round.serial = 1
		round.round_end_tick = node.world.tick + 120
		round.result_end_tick = node.world.tick + 120
		round.result_reason = SessionRound.ResultReason.TIMEOUT if phase == SessionRound.Phase.RESULT else SessionRound.ResultReason.NONE
		round.phase = phase
		check(SessionRound.validate_packet(round.capture(node.world)), "host round fixture captures a real valid phase packet")
		equal(int(node._current_round_state().phase), phase, "host authoritative phase overrides stale replica Hearth")
		_assert_invalidated(node, "host ACTIVE/RESULT round")
		round.bind_hearth()
	node.session_transport.mode = SessionTransport.Mode.OFFLINE


func _test_actual_input_dismissal() -> void:
	var previous_mouse_mode := Input.mouse_mode
	for kind: String in ["escape", "click"]:
		var node := ResultHarness.new()
		var configured := _configure(node)
		check(configured, "input fixture keeps inherited production result handlers")
		if not configured:
			node.free()
			continue
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1280, 720)
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		viewport.handle_input_locally = true
		(Engine.get_main_loop() as SceneTree).root.add_child(viewport)
		viewport.add_child(node)
		viewport.notify_mouse_entered()
		var completed: bool = _paid_result(node) == true
		check(completed, kind + " input fixture must finish the real paid demo before dismissal assertions")
		if not completed:
			viewport.free()
			continue
		var before: String = node.world.state_hash()
		var retained: Dictionary = node.hex_playground_demo.terminal_result()
		var echo := InputEventKey.new()
		echo.keycode = KEY_ESCAPE
		echo.pressed = true
		echo.echo = true
		check(not node._handle_demo_result_input(echo), "Escape echo cannot dismiss the lesson")
		echo.echo = false
		echo.pressed = false
		check(not node._handle_demo_result_input(echo), "Escape release cannot dismiss the lesson")
		equal(node.hex_playground_demo.terminal_result(), retained, "ignored input preserves the exact real result")
		var event: InputEvent
		if kind == "escape":
			var key := InputEventKey.new()
			key.keycode = KEY_ESCAPE
			key.physical_keycode = KEY_ESCAPE
			key.pressed = true
			event = key
		else:
			var view: Dictionary = node._demo_result_view()
			var boxes := Card.layout(view, Vector2(viewport.size), Vector2.ZERO, ThemeDB.fallback_font)
			check(not boxes.is_empty(), "close click uses the real visible card geometry")
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.position = (boxes.close as Rect2).get_center()
			click.pressed = false
			check(not node._handle_demo_result_input(click), "close-button release does not consume gameplay input")
			click.pressed = true
			event = click
		viewport.push_input(event, true)
		check(viewport.is_input_handled(), kind + " is consumed through real viewport -> inherited _unhandled_input")
		check(not node.hex_playground_demo.has_terminal_result(), kind + " dismisses the actual model, not a visual copy")
		check(node._demo_result_view().is_empty(), kind + " removes the inactive result view")
		check(not node._gameplay_input_blocked(), kind + " does not leave a modal or input guard behind")
		check(not node.player_compendium.is_open, kind + " cannot fall through to the global Back action")
		check(node.hex_playground_demo.command(node.world) == null, kind + " never generates an automatic retry command")
		check(not node._handle_demo_result_input(event), kind + " repeated dismissal is inert")
		equal(node.world.state_hash(), before, kind + " changes no weave, resources, product or simulation tick")
		var preferences: NoSavePreferences = node.player_preferences
		viewport.free()
		equal(preferences.save_attempts, 0, "input integration and teardown never save fixture preferences")
	Input.mouse_mode = previous_mouse_mode


func _function_body(source: String, name: String) -> String:
	var start := source.find("func " + name + "(")
	if start < 0:
		return ""
	var end := source.find("\nfunc ", start + 1)
	return source.substr(start, (source.length() if end < 0 else end) - start)


func _test_frame_and_draw_hooks() -> void:
	# Runtime handlers above are exercised directly. These narrow wiring checks
	# additionally prevent disconnecting them from the actual frame/draw loop.
	var source := FileAccess.get_file_as_string("res://src/app/bootstrap.gd")
	var frame := _function_body(source, "_process")
	check(frame.contains("_reconcile_demo_result()"), "production frames reconcile stale terminal-result context")
	var drawing := _function_body(source, "_draw_practice_coach")
	check(drawing.contains("var result_view := _demo_result_view()") and drawing.contains("DemoResultCard.draw(self, result_view"), "inactive result builds one view for the actual card drawing branch")
	var input := _function_body(source, "_unhandled_input")
	check(input.find("_handle_demo_result_input(event)") >= 0 and input.find("_handle_demo_result_input(event)") < input.find("_observe_station_activation_device(event)"), "result dismissal runs before ordinary station/global input dispatch")
