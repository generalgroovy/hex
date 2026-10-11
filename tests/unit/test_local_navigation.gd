extends FluxTestSuite

const Navigation = preload("res://src/app/local_navigation_controller.gd")
const Quality = preload("res://src/presentation/render_quality.gd")
class Harness extends "res://src/app/bootstrap.gd":
	func _ready() -> void:
		set_process(false)
	func _draw() -> void:
		pass

func run() -> int:
	var unowned := Navigation.new()
	check(not unowned.open_map(), "unconfigured map refuses without owner access")
	check(not unowned.handle_input(InputEventKey.new()), "unconfigured navigation ignores input")
	check(not unowned.travel("unknown"), "unconfigured travel refuses without mutation")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	(Engine.get_main_loop() as SceneTree).root.add_child(viewport)
	var game := Harness.new()
	viewport.add_child(game)
	if not _configure(game):
		check(false, "navigation fixture loads the real expanded world")
		viewport.free()
		return finish("local-navigation")
	var nav: RefCounted = game.local_navigation
	var actor: PlayerState = game.world.player()
	actor.health -= 1234
	actor.flux -= 4567
	actor.stamina -= 3456
	actor.spell_cooldown_ticks[0] = 77
	var resources := [actor.health, actor.flux, actor.stamina, actor.spell_cooldown_ticks.duplicate(), actor.spell_wire_ids.duplicate()]
	var cells_paid := int(game.world.hex_court.metrics.matter_paid)
	for destination: Dictionary in game.campus_layout.travel_destinations():
		check(nav.open_map(), "real map opens for " + String(destination.id))
		check(game._gameplay_input_blocked(), "map owns command input")
		check(nav.travel(String(destination.id)), "actual travel reaches " + String(destination.id))
		var expected := Vector2i(int(destination.position[0]), int(destination.position[1])) * SimConfig.FIXED_SCALE
		equal(Vector2i(actor.position_x, actor.position_y), expected, "arrival uses trusted authored coordinates")
		check(game.world.collision.can_occupy(expected, actor.radius), "arrival clears actual actor collision")
		equal([actor.health, actor.flux, actor.stamina, actor.spell_cooldown_ticks, actor.spell_wire_ids], resources, "travel preserves resources, cooldowns and loadout")
		equal(game.previous_position, game.current_position, "teleport cannot smear actor interpolation across the world")
		check(not game.player_camera.initialized, "camera snaps after travel")
		check(not nav.blocks_gameplay(), "arrival closes both navigation surfaces")
	equal(int(game.world.hex_court.metrics.matter_paid), cells_paid, "travel never creates paid matter")
	var before := actor.canonical_values()
	check(not nav.travel("not-an-authored-destination"), "unknown travel id fails closed")
	equal(actor.canonical_values(), before, "unknown destination cannot reset actor state")
	var target: String = String(game.campus_layout.travel_destinations()[0].id)
	actor.pending_cast_ticks = 1
	_rejected(nav, actor, target, "spell startup")
	actor.pending_cast_ticks = 0
	actor.air_height = 1000
	_rejected(nav, actor, target, "airborne action")
	actor.air_height = 0
	actor.health_recovery_delay_ticks = 1
	_rejected(nav, actor, target, "recent damage")
	actor.health_recovery_delay_ticks = 0
	actor.spell_status_values[0] = 1
	_rejected(nav, actor, target, "active status")
	actor.spell_status_values[0] = 0
	game.interception_practice_active = true
	_rejected(nav, actor, target, "isolated duel")
	game.interception_practice_active = false
	game.element_expansion.challenge_active = true
	_rejected(nav, actor, target, "signature challenge")
	game.element_expansion.challenge_active = false
	var shot := ProjectileState.new(999, actor.entity_id, actor.team_id, 140, 1, Vector2i(actor.position_x, actor.position_y), Vector2i.RIGHT, 1000, 1000, 60)
	game.world.projectiles.append(shot)
	_rejected(nav, actor, target, "live owned projectile")
	game.world.projectiles.clear()
	game.session_transport.mode = SessionTransport.Mode.HOSTING
	_rejected(nav, actor, target, "online host")
	game.session_transport.mode = SessionTransport.Mode.OFFLINE
	var destination: Dictionary = game.campus_layout.travel_destination(target)
	var other := PlayerState.new()
	other.entity_id = 2
	other.position_x = int(destination.position[0]) * SimConfig.FIXED_SCALE
	other.position_y = int(destination.position[1]) * SimConfig.FIXED_SCALE
	game.world.players.append(other)
	_rejected(nav, actor, target, "occupied destination")
	game.world.players.erase(other)
	var original_collision: HexCollisionWorld = game.world.collision
	var occupied_collision := HexCollisionWorld.new(original_collision.base_world)
	var occupied_cell := HexGrid.world_to_cell(Vector2i(int(destination.position[0]), int(destination.position[1])) * SimConfig.FIXED_SCALE)
	check(occupied_collision.configure_hexes(Vector2i.ZERO, game.world.hex_court.immutable_topology().numeric_cells(), [occupied_cell]), "live Rampart collision fixture installs at authored arrival")
	game.world.collision = occupied_collision
	_rejected(nav, actor, target, "active Rampart at destination")
	game.world.collision = original_collision
	_test_input(game)
	var font := ThemeDB.fallback_font
	for size: Vector2 in [Vector2(960, 540), Vector2(1280, 720)]:
		var rows: Array[Dictionary] = nav.entries()
		var panel: Rect2 = Navigation.menu_rect(size, rows.size())
		check(Rect2(Vector2.ZERO, size).encloses(panel), "compact menu fits supported size")
		for index: int in rows.size():
			check(panel.encloses(Navigation.row_rect(size, rows.size(), index)), "every menu action remains in panel")
			check(font.get_string_size(String(rows[index].label), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x <= 220, "actual menu action label fits its budget")
	game.world = null # Teardown cannot accidentally save a production weave.
	viewport.free()
	return finish("local-navigation")

func _configure(game: Node) -> bool:
	game.preferences_persistence_allowed = false
	game.preference_overrides_are_transient = true
	game.ability_catalog = AbilityCatalog.new()
	game.campus_layout = SanctumCampusLayout.new()
	if not game.ability_catalog.load_from_file(game.ABILITY_CATALOG_PATH) or not game.campus_layout.load_from_file(game.CAMPUS_LAYOUT_PATH): return false
	game.world = game._new_wellspring_world(120)
	if game.world == null: return false
	game.session_transport = SessionTransport.new()
	game.authoritative_session = AuthoritativeSession.new()
	game.authoritative_session.world = game.world
	game.session_round_values = game.authoritative_session.session_round.capture(game.world)
	game.player_preferences = PlayerPreferences.new()
	game.controls_editor = ControlBindingEditor.new()
	game.spell_loom_editor = SpellLoomEditor.new()
	game.player_compendium = game.PlayerCompendiumScript.new()
	game.character_selection_grid = game.CharacterSelectionGridScript.new()
	game.input_router = InputRouter.new(1)
	game.element_expansion.game = game
	game.local_navigation.configure(game)
	game.application_input_active = true
	game.world.player().reset_for_spawn(game.campus_layout.spawn * SimConfig.FIXED_SCALE)
	return true

func _rejected(nav: RefCounted, actor: PlayerState, destination: String, label: String) -> void:
	var before := actor.canonical_values()
	check(not nav.travel(destination), label + " refuses travel")
	equal(actor.canonical_values(), before, label + " preserves every actor field")

func _test_input(game: Node) -> void:
	var nav: RefCounted = game.local_navigation
	var key := InputEventKey.new()
	key.keycode = KEY_M
	key.pressed = true
	game.controls_input_guard_frames = 0
	game._unhandled_input(key)
	check(nav.map_panel.is_open, "actual Bootstrap M opens map")
	var release := InputEventKey.new()
	release.keycode = KEY_SPACE
	release.pressed = false
	check(nav.handle_input(release), "map consumes releases to prevent buffered jump leaks")
	key.keycode = KEY_ESCAPE
	game._unhandled_input(key)
	check(not nav.map_panel.is_open, "Escape closes map")
	game.controls_input_guard_frames = 0
	game._unhandled_input(key)
	check(nav.menu_open, "Escape opens compact menu in freeplay")
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_A
	joy.pressed = true
	game._unhandled_input(joy)
	check(nav.map_panel.is_open, "controller confirms World map from menu")
	joy.button_index = JOY_BUTTON_B
	game._unhandled_input(joy)
	check(not nav.blocks_gameplay(), "controller B closes map")
	game.controls_input_guard_frames = 0
	joy.button_index = JOY_BUTTON_BACK
	game._unhandled_input(joy)
	check(nav.menu_open and not game.player_compendium.is_open, "controller Back opens the consolidated Menu directly")
	nav.close()
	game.controls_input_guard_frames = 0
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Navigation.MENU_ENTRY.get_center() * game._ui_scale()
	game._unhandled_input(click)
	check(nav.menu_open, "single visible Menu button opens through pointer")
	nav.close()
	var previous_quality: String = Quality.profile
	var previous_cap := Engine.max_fps
	var tick_before: int = game.world.tick
	nav.activate("performance")
	check(nav.performance_panel.is_open and game._gameplay_input_blocked(), "Performance owns input through actual navigation")
	key.keycode = KEY_RIGHT
	game._unhandled_input(key)
	equal(game.player_preferences.render_quality, "standard", "actual keyboard event applies visual detail")
	equal(game.world.tick, tick_before, "local performance changes cannot advance or replace authority")
	key.keycode = KEY_DOWN
	game._unhandled_input(key)
	key.keycode = KEY_RIGHT
	game._unhandled_input(key)
	equal(Engine.max_fps, 120, "actual cap event reaches engine presentation setting")
	key.keycode = KEY_ESCAPE
	game._unhandled_input(key)
	check(not nav.blocks_gameplay() and game.controls_input_guard_frames > 0, "closing Performance quarantines confirm input")
	Quality.set_profile(previous_quality)
	Engine.max_fps = previous_cap
	game.controls_input_guard_frames = 0
	game.controls_editor.open_editor()
	key.keycode = KEY_M
	check(not nav.handle_input(key), "Controls M retains reduced effects priority")
	game.controls_editor.close_editor()
	game.player_preferences.keyboard_bindings[&"emote"] = KEY_M
	check(not nav.handle_input(key), "custom gameplay M binding retains priority")
