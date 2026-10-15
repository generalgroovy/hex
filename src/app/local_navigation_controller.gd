extends RefCounted
## Local navigation and menu routing. Travel never refills or changes a weave.

const MapPanel = preload("res://src/presentation/wellspring_map_panel.gd")
const Attunement = preload("res://src/app/champion_attunement.gd")
const PerformancePanel = preload("res://src/presentation/performance_panel.gd")
const MENU_ENTRY := Rect2(20, 52, 154, 28)
var game
var menu_open := false
var selected := 0
var map_panel := MapPanel.new()
var performance_panel := PerformancePanel.new()
var _stick_latched := false

func configure(owner: Node) -> void:
	game = owner

func blocks_gameplay() -> bool:
	return menu_open or map_panel.is_open or performance_panel.is_open

func close() -> void:
	if game != null and game.campus_renderer != null: game.campus_renderer.clear_terrain_prefetch()
	menu_open = false
	map_panel.close()
	performance_panel.close()
	_stick_latched = false

func entries() -> Array[Dictionary]:
	var rows: Array[Dictionary] = [{"id": "map", "label": "World map", "hint": "M"}]
	if game == null: return rows
	# Lead with a short playable route; the existing map, lessons and full tools
	# remain ordinary menu actions with the same input and availability rules.
	rows.push_front({"id": "expansion-circuit", "label": "Rival Circuit · 3 rivals", "hint": ""})
	if game._is_hex_practice():
		rows.append_array([
			{"id": "expansion-introduction", "label": "Skip introduction" if game.element_expansion.guide.active else "Introduction", "hint": "F5" if game.element_expansion.shortcut_available(KEY_F5) else ""},
			{"id": "expansion-range", "label": "Change Range spell", "hint": "F6" if game.element_expansion.shortcut_available(KEY_F6) else ""},
			{"id": "expansion-tactics", "label": "Tactical lessons", "hint": ""},
			{"id": "loom", "label": "Spell Loom", "hint": ""},
			{"id": "characters", "label": "Characters", "hint": ""},
			{"id": "reset_court", "label": "Reset practice court", "hint": ""},
			{"id": "return", "label": "Return to Wellspring", "hint": ""},
		])
	else:
		rows.append_array([
			{"id": "expansion-introduction", "label": "Skip introduction" if game.element_expansion.guide.active else "Introduction", "hint": "F5" if game.element_expansion.shortcut_available(KEY_F5) else ""},
			{"id": "expansion-range", "label": "Spell Range", "hint": "F6" if game.element_expansion.shortcut_available(KEY_F6) else ""},
			{"id": "expansion-tactics", "label": "Tactical lessons", "hint": ""},
			{"id": "expansion-challenges", "label": "Signature Challenges", "hint": "Shift+F6" if game.element_expansion.shortcut_available(KEY_F6) else ""},
			{"id": "duel", "label": "Practice duel", "hint": ""},
			{"id": "chemistry", "label": "Chemistry demos", "hint": ""},
		])
	rows.append_array([
		{"id": "compendium", "label": "Compendium", "hint": "F4"},
		{"id": "controls", "label": "Controls & settings", "hint": ""},
		{"id": "performance", "label": "Display & text size", "hint": ""},
		{"id": "expansion-developer", "label": "Developer tools", "hint": "Shift+F5" if game.element_expansion.shortcut_available(KEY_F5) else ""},
	])
	var progress: Dictionary = game.element_expansion.progression.view()
	if game.element_expansion.guide.active: rows.append({"id":"expansion-guide-details","label":"Guide action / explanation","hint":""})
	if bool(progress.get("can_retry_save",false)): rows.append({"id":"expansion-retry-save","label":"Retry progress save","hint":"Unsaved"})
	if bool(progress.get("can_recover_backup",false)): rows.append({"id":"expansion-recover-save","label":"Recover progress backup","hint":""})
	if not game.element_expansion.offline():
		rows = rows.filter(func(row: Dictionary) -> bool: return String(row.id) in ["map", "compendium", "controls", "performance"])
	return rows

static func menu_rect(viewport: Vector2, count: int) -> Rect2:
	var size := Vector2(minf(360,viewport.x-24), 82 + mini(count,menu_page_size(viewport)) * 34)
	return Rect2((viewport - size) * 0.5, size)

static func row_rect(viewport: Vector2, count: int, index: int) -> Rect2:
	var panel := menu_rect(viewport,count)
	return Rect2(panel.position + Vector2(14, 48 + posmod(index,menu_page_size(viewport)) * 34), Vector2(panel.size.x-28, 30))

static func menu_page_size(viewport: Vector2) -> int:
	return maxi(1,floori((viewport.y-106)/34))

static func page_rect(viewport: Vector2, count: int, direction: int) -> Rect2:
	var panel := menu_rect(viewport,count)
	return Rect2(panel.end-Vector2(100 if direction < 0 else 54,32),Vector2(40,24))

func visible_menu_indices(viewport: Vector2, count: int) -> Array:
	var size := menu_page_size(viewport)
	var first := floori(float(selected) / size) * size
	return range(first,mini(count,first+size))

func open_menu() -> void:
	if game == null or game.world == null: return
	map_panel.close()
	performance_panel.close()
	menu_open = true
	selected = 0
	_handoff()

func open_map() -> bool:
	if game == null or game.world == null or game.campus_layout == null: return false
	var actor: PlayerState = game._local_player_state()
	if actor == null: return false
	menu_open = false
	performance_panel.close()
	map_panel.open(game.campus_layout, Vector2i(actor.position_x, actor.position_y), travel_availability())
	map_panel.set_location_visible(not game._is_hex_practice())
	_handoff()
	return map_panel.is_open

func travel_availability() -> Dictionary:
	if game == null or game.world == null or game.session_transport == null: return _refusal("The world is still loading.")
	if game.session_transport.mode != SessionTransport.Mode.OFFLINE: return _refusal("Fast travel is available in offline free exploration.")
	if game._is_hex_practice() or game.interception_practice_active or game.element_expansion.challenge_active or game.hex_playground_demo.is_active(): return _refusal("Return to Wellspring before travelling.")
	if int(game._current_round_state().get("phase", SessionRound.Phase.HEARTH)) != SessionRound.Phase.HEARTH: return _refusal("Finish the current round before travelling.")
	var actor: PlayerState = game._local_player_state()
	if not Attunement.is_available(actor): return _refusal("Land and finish the current action to travel.")
	if actor.health_recovery_delay_ticks > 0: return _refusal("Recover from the last hit before travelling.")
	for index: int in range(0, actor.spell_status_values.size(), 8):
		if actor.spell_status_values[index] > 0: return _refusal("Wait for the current status effect to end.")
	for shot: ProjectileState in game.world.projectiles:
		if shot.owner_id == actor.entity_id: return _refusal("Let your active spell finish before travelling.")
	return {"enabled": true, "reason": ""}

func travel(destination_id: String) -> bool:
	if game != null: game._cancel_element_garden_arrival()
	var available := travel_availability()
	if not bool(available.enabled):
		map_panel.set_availability(available)
		return false
	# Resolve against trusted authored content at commit time, never event coordinates.
	var destination: Dictionary = game.campus_layout.travel_destination(destination_id)
	var values: Array = destination.get("position", [])
	if values.size() != 2: return false
	var point := Vector2i(int(values[0]), int(values[1])) * SimConfig.FIXED_SCALE
	var actor: PlayerState = game._local_player_state()
	if not game.world.collision.can_occupy(point, actor.radius):
		map_panel.set_message("This arrival point is currently blocked.")
		return false
	for other: PlayerState in game.world.players:
		if other.entity_id != actor.entity_id and other.health > 0:
			var separation := point - Vector2i(other.position_x, other.position_y)
			if separation.length_squared() < float((actor.radius + other.radius) * (actor.radius + other.radius)):
				map_panel.set_message("The arrival point is occupied.")
				return false
	actor.position_x = point.x
	actor.position_y = point.y
	actor.position_remainder_x = 0
	actor.position_remainder_y = 0
	actor.velocity_x = 0
	actor.velocity_y = 0
	actor.air_velocity_x = 0
	actor.air_velocity_y = 0
	MovementSystem.cancel_jump_intent(actor)
	actor.jump_buffer_ticks = 0
	actor.technique_buffer_ticks = 0
	actor.slide_buffer_ticks = 0
	actor.evade_buffer_ticks = 0
	actor.movement_chain_count = 0
	actor.movement_chain_reset_ticks = 0
	actor.wall_memory_ticks = 0
	actor.wall_contact_id = 0
	actor.movement_mode = PlayerState.MovementMode.IDLE
	actor.sprinting = false
	actor.last_event = "map_travel"
	game.current_position = Vector2(point) / SimConfig.FIXED_SCALE
	game.previous_position = game.current_position
	game._reset_motion_history()
	game.focused_station_id = ""
	game.expanded_station_id = ""
	game.station_notice = String(destination.get("label", destination_id))
	game.station_notice_seconds = 2.0
	close()
	_handoff()
	game._request_element_garden_arrival()
	return true

func handle_input(event: InputEvent) -> bool:
	if game == null or game.world == null: return false
	var viewport: Vector2 = game.get_viewport_rect().size / game._ui_scale()
	var transformed := event
	if event is InputEventMouse:
		transformed = event.duplicate()
		transformed.position = event.position / game._ui_scale()
	if performance_panel.is_open:
		var setting: Dictionary = performance_panel.handle_input(transformed, viewport, game.player_preferences)
		if setting.has("close"): close(); _handoff()
		elif not setting.is_empty():
			performance_panel.message = "Saved." if game._change_performance_preferences(setting) else "Applied for this session; saved profile kept."
		return true
	if map_panel.is_open:
		map_panel.set_availability(travel_availability())
		var intent: Dictionary = map_panel.handle_input(transformed, viewport)
		match String(intent.get("action", "")):
			"close": close(); _handoff()
			"travel": travel(String(intent.get("destination_id", "")))
		return true
	if menu_open:
		var rows := entries()
		var confirm := false
		if event is InputEventKey and event.pressed and not event.echo:
			var menu_key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			match menu_key:
				KEY_ESCAPE: close(); _handoff()
				KEY_UP: selected = posmod(selected - 1, rows.size())
				KEY_DOWN, KEY_TAB: selected = posmod(selected + (-1 if event.shift_pressed else 1), rows.size())
				KEY_ENTER, KEY_KP_ENTER: confirm = true
		elif event is InputEventJoypadButton and event.pressed:
			match event.button_index:
				JOY_BUTTON_B, JOY_BUTTON_BACK: close(); _handoff()
				JOY_BUTTON_DPAD_UP: selected = posmod(selected - 1, rows.size())
				JOY_BUTTON_DPAD_DOWN: selected = posmod(selected + 1, rows.size())
				JOY_BUTTON_A: confirm = true
		elif event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y:
			if absf(event.axis_value) < 0.35: _stick_latched = false
			elif absf(event.axis_value) > 0.6 and not _stick_latched:
				selected = posmod(selected + (1 if event.axis_value > 0 else -1), rows.size())
				_stick_latched = true
		elif transformed is InputEventMouseButton and transformed.pressed:
			if transformed.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]: selected = posmod(selected+(-1 if transformed.button_index==MOUSE_BUTTON_WHEEL_UP else 1),rows.size())
			elif transformed.button_index == MOUSE_BUTTON_LEFT:
				if rows.size()>menu_page_size(viewport) and page_rect(viewport,rows.size(),-1).has_point(transformed.position): selected=posmod(selected-menu_page_size(viewport),rows.size())
				elif rows.size()>menu_page_size(viewport) and page_rect(viewport,rows.size(),1).has_point(transformed.position): selected=posmod(selected+menu_page_size(viewport),rows.size())
				else:
					for index: int in visible_menu_indices(viewport,rows.size()):
						if row_rect(viewport, rows.size(), index).has_point(transformed.position): selected = index; confirm = true; break
		if confirm: activate(String(rows[selected].id))
		return true
	# Existing modal/capture input and custom gameplay bindings keep priority.
	if game._gameplay_input_blocked() or game.element_expansion.challenge_active: return false
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if not game.player_preferences.keyboard_bindings.values().has(key):
			if key == KEY_ESCAPE: open_menu(); return true
			if key == KEY_M: open_map(); return true
	if transformed is InputEventMouseButton and transformed.button_index == MOUSE_BUTTON_LEFT and transformed.pressed and MENU_ENTRY.has_point(transformed.position):
		open_menu()
		return true
	return false

func activate(id: String) -> void:
	close()
	match id:
		"map": open_map()
		"compendium": game._open_player_compendium(0)
		"controls": game.controls_editor.open_editor()
		"performance": performance_panel.open()
		"loom": game._open_spell_loom_editor()
		"characters": game._open_character_gallery()
		"return": game._start_match(game.tick_rate)
		"reset_court": game._start_hex_court()
		"chemistry": game.hex_playground_open = true
		"duel": game._open_solo_trial_menu()
		"expansion-introduction":
			if game.element_expansion.guide.active: game.element_expansion.guide.stop()
			else: game.element_expansion.activate(id)
		_: game.element_expansion.activate(id)
	_handoff()

func draw(canvas: CanvasItem, font: Font, viewport: Vector2) -> void:
	if game == null or game.world == null: return
	if performance_panel.is_open:
		performance_panel.draw(canvas, font, viewport, game.player_preferences)
		return
	if map_panel.is_open:
		var actor: PlayerState = game._local_player_state()
		map_panel.set_location_visible(not game._is_hex_practice())
		if actor != null: map_panel.update_position(Vector2i(actor.position_x, actor.position_y))
		map_panel.set_availability(travel_availability())
		var target := map_panel.model.selected_destination()
		if not target.is_empty() and game.campus_renderer != null:
			var point: Array = target.get("position",[])
			if point.size() == 2:
				var view_size: Vector2 = game.get_viewport_rect().size / game._camera_zoom_scale()
				game.campus_renderer.prefetch_terrain_view(Rect2(Vector2(float(point[0]),float(point[1]))-view_size*0.5,view_size))
		map_panel.draw(canvas, font, viewport)
		return
	if menu_open:
		var rows := entries()
		var rect := menu_rect(viewport, rows.size())
		canvas.draw_rect(rect, Color("14242cf7"))
		canvas.draw_rect(rect, Color("6a9394"), false, 1)
		canvas.draw_string(font, rect.position + Vector2(16, 29), "MENU", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("eee0b8"))
		canvas.draw_string(font, rect.position + Vector2(246, 28), "Esc / B: close", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("acbebd"))
		for index: int in visible_menu_indices(viewport,rows.size()):
			var row := row_rect(viewport, rows.size(), index)
			if selected == index: canvas.draw_rect(row, Color("305157"))
			canvas.draw_string(font, row.position + Vector2(10, 21), String(rows[index].label), HORIZONTAL_ALIGNMENT_LEFT, 220, 15, Color("eee0b8"))
			if game.player_preferences.prompt_device != ControlBindingEditor.DEVICE_CONTROLLER:
				canvas.draw_string(font, row.position + Vector2(228, 20), String(rows[index].hint), HORIZONTAL_ALIGNMENT_RIGHT, 94, 11, Color("acbebd"))
		canvas.draw_string(font, rect.position + Vector2(16, rect.size.y - 13), "↑ ↓ / wheel select · Enter / A", HORIZONTAL_ALIGNMENT_LEFT, 238, 12, Color("acbebd"))
		if rows.size()>menu_page_size(viewport):
			for direction: int in [-1,1]:
				var page := page_rect(viewport,rows.size(),direction)
				canvas.draw_rect(page,Color("305157"))
				canvas.draw_string(font,page.position+Vector2(15,17),"<" if direction<0 else ">",HORIZONTAL_ALIGNMENT_LEFT,20,13,Color("eee0b8"))
	elif not game._gameplay_input_blocked() and not game.element_expansion.challenge_active:
		canvas.draw_rect(MENU_ENTRY, Color("14242cd9"))
		canvas.draw_string(font, MENU_ENTRY.position + Vector2(10, 19), "MENU · Esc / Back", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("eee0b8"))

static func _refusal(reason: String) -> Dictionary:
	return {"enabled": false, "reason": reason}

func _handoff() -> void:
	game.controls_input_guard_frames = 2
	if game.input_router != null: game.input_router.discard_transient_movement_input()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.queue_redraw()
