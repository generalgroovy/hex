extends FluxTestSuite


class ControlsHarness:
	extends "res://src/app/bootstrap.gd"
	func _ready() -> void:
		set_process(false)
		set_process_unhandled_input(false)
	func _draw() -> void:
		pass


class FixturePreferences:
	extends PlayerPreferences
	var fixture_path: String
	var save_count: int = 0
	func save_to_file(_path: String = DEFAULT_PATH) -> bool:
		# Even an accidental teardown save can only address this owned fixture.
		save_count += 1
		return super.save_to_file(fixture_path)


func run() -> int:
	InputRouter.ensure_input_map()
	var previous_mouse_mode := Input.mouse_mode
	var node := ControlsHarness.new()
	node.world = SimWorld.new(120, 20260913, CollisionWorld.new(3_072_000, 1_728_000))
	node.input_router = InputRouter.new(1)
	node.session_transport = SessionTransport.new()
	node.controls_editor = ControlBindingEditor.new()
	node.spell_loom_editor = SpellLoomEditor.new()
	node.player_compendium = node.PlayerCompendiumScript.new()
	var prefs := FixturePreferences.new()
	prefs.fixture_path = "res://.godot/controls-round-trip-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	node.player_preferences = prefs
	(Engine.get_main_loop() as SceneTree).root.add_child(node)
	node.controls_editor.open_editor()
	node.controls_editor.selected_action_index = ControlBindingEditor.ACTIONS.find(&"jump")
	node.controls_editor.selected_device = ControlBindingEditor.DEVICE_KEYBOARD
	node.controls_editor.begin_capture()
	_send_key(node, KEY_F4, true)
	check(node.controls_editor.capturing and not node.player_compendium.is_open, "fixed F4 is rejected by the real capture route without opening another modal")
	equal(prefs.keyboard_bindings[&"jump"], KEY_SPACE, "rejected fixed key leaves jump unchanged")
	equal(prefs.save_count, 0, "rejected binding does not persist a profile")
	_send_key(node, KEY_F4, false)
	_send_key(node, KEY_J, true)
	check(not node.controls_editor.capturing, "usable key completes real binding capture")
	equal(prefs.save_count, 1, "binding commit persists through the real bootstrap save path")
	var loaded := PlayerPreferences.new()
	check(loaded.load_from_file(prefs.fixture_path), "saved binding reloads from its isolated file")
	equal(loaded.keyboard_bindings[&"jump"], KEY_J, "reloaded profile contains the actual captured key")
	_send_key(node, KEY_ESCAPE, true)
	check(not node.controls_editor.is_open and node.controls_input_guard_frames == 2, "real Escape closes Controls with the two-frame input guard")
	_send_key(node, KEY_ESCAPE, false)
	for _frame: int in range(2):
		var blocked := node._gameplay_input_blocked()
		node.controls_input_guard_frames -= 1
		equal(node._sample_gameplay_command(0, Vector2.ZERO, Vector2.RIGHT, blocked).pressed_actions, SimCommand.PRESSED_CANCEL_MOVEMENT, "closing emits only safe movement cancellation, never a paid action")
	_send_key(node, KEY_J, false)
	node._sample_gameplay_command(0, Vector2.ZERO, Vector2.RIGHT, false)
	_send_key(node, KEY_J, true)
	check(Input.is_action_pressed(&"jump"), "repressed physical key enters the saved InputMap action")
	var command := node._sample_gameplay_command(0, Vector2.ZERO, Vector2.RIGHT, false)
	check(command.has_pressed(SimCommand.PRESSED_JUMP), "release and repress of saved key reaches the real gameplay command")
	var stamina_before := node.world.player().stamina
	check(node.world.step([command]), "saved key advances the real authoritative world")
	check(node.world.player().jumpsquat_active and not node.world.player().is_airborne() and node.world.player().stamina == stamina_before, "saved held key prepares an unpaid grounded jump")
	_send_key(node, KEY_J, false)
	check(node.world.step([node._sample_gameplay_command(node.world.tick, Vector2.ZERO, Vector2.RIGHT, false)]), "saved key release advances authority")
	check(node.world.player().is_airborne() and node.world.player().stamina < stamina_before, "saved key release admits the ordinary paid jump")
	_send_key(node, KEY_F4, true)
	check(node.player_compendium.is_open, "F4 retains its fixed Compendium action after Controls closes")
	equal(node._sample_gameplay_command(node.world.tick, Vector2.ZERO, Vector2.RIGHT, node._gameplay_input_blocked()).pressed_actions, SimCommand.PRESSED_CANCEL_MOVEMENT, "Compendium shortcut delivers only cancellation, never a paid action")
	_send_key(node, KEY_F4, false)
	node.preferences_persistence_allowed = false
	check(not node._save_player_preferences_if_persistent(), "failed initial profile preservation blocks later settings saves")
	equal(prefs.save_count, 1, "blocked settings save never calls the disk writer")
	node.preference_overrides_are_transient = true
	node.free()
	equal(prefs.save_count, 1, "teardown does not save after the explicit binding commit")
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(prefs.fixture_path)) == OK, "only the owned round-trip fixture is removed")
	var restore := InputRouter.new(1)
	restore.configure_keyboard_bindings(PlayerPreferences.DEFAULT_KEYBOARD_BINDINGS)
	restore.configure_mouse_bindings(PlayerPreferences.DEFAULT_MOUSE_BINDINGS)
	restore.configure_controller_bindings(PlayerPreferences.DEFAULT_CONTROLLER_BINDINGS)
	Input.mouse_mode = previous_mouse_mode
	return finish("controls-round-trip")


func _send_key(node: Node, code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	node._unhandled_input(event)
