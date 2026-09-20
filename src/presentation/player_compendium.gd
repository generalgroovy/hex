class_name PlayerCompendium
extends RefCounted


# This is a read-only projection: navigation cannot equip a spell, select a
# champion, pause the shared world or change any authoritative gameplay value.
const Guide = preload("res://src/presentation/movement_guide_model.gd")
const Overview = preload("res://src/app/character_overview_model.gd")
const ChemistryGuide = preload("res://src/presentation/chemistry_guide_model.gd")
const HexPolicy = preload("res://src/sim/hex/hex_recipe_policy.gd")
const MOVEMENT := 0
const CHARACTERS := 1
const CHEMISTRY := 2
const ROWS_PER_PAGE := 10
const LINES_PER_PAGE := 14
const FONT_SIZE := 18
const LINE_HEIGHT := 25
const DETAIL_WIDTH := 770.0
const PAIR_LINES_PER_PAGE := 12
const PHASE_STRIP := Rect2(402, 193, 794, 18)
const PANEL := Rect2(48, 44, 1184, 632)
const LIST_RECT := Rect2(72, 164, 298, 400)
const MOVEMENT_TAB := Rect2(72, 112, 230, 34)
const CHARACTERS_TAB := Rect2(312, 112, 230, 34)
const CHEMISTRY_TAB := Rect2(552, 112, 230, 34)
const CLOSE_RECT := Rect2(1116, 64, 92, 32)
const PREVIOUS_ROWS := Rect2(72, 572, 140, 34)
const NEXT_ROWS := Rect2(226, 572, 144, 34)
const PREVIOUS_DETAIL := Rect2(402, 572, 154, 34)
const NEXT_DETAIL := Rect2(1032, 572, 164, 34)
const INK := Color("141a17ee")
const PARCHMENT := Color("eee0b8")
const MUTED := Color("b7b69e")
const BRASS := Color("b79351")
const OVERVIEW_TOGGLE := Rect2(882, 112, 200, 34)
const PRIMER_RECT := Rect2(72, 166, 116, 34)
const MOVE_COLUMNS := [72.0, 305.0, 573.0, 686.0, 828.0, 1050.0, 1208.0]
const MOVE_HEADERS := ["Technique", "Current input", "Base start", "Base /s", "Protection window", "Cooldown"]

var is_open := false
var tab := MOVEMENT
var selected_row := 0
var selected_character := 0
var detail_page := 0
var show_details := false
var selected_element_column := 0
var visual_language: VisualLanguage
var device := ControlBindingEditor.DEVICE_KEYBOARD
var movement_rows: Array[Dictionary] = []
var chemistry_rows: Array[Dictionary] = []
var overview: Dictionary = {}
var summary: Array[String] = []
var _wrapped_lines: Array[String] = []
var _cache_key := ""
var _summary_maximum := -1
var _summary_recovery := -1
var _summary_chain := -1


func configure(champions: ChampionCatalog, roster: ChampionRosterPlan) -> bool:
	overview = Overview.build(champions, roster)
	chemistry_rows = ChemistryGuide.entries()
	chemistry_rows[0].lines = unified_chemistry_primer()
	visual_language = VisualLanguage.new()
	return bool(overview.get("valid", false)) and visual_language.load_from_file()


func open_panel(selected_tab: int, preferences: PlayerPreferences, state: PlayerState = null, input_device: int = ControlBindingEditor.DEVICE_KEYBOARD) -> void:
	is_open = true
	device = input_device
	movement_rows = Guide.entries(preferences, device)
	summary = Guide.summary_lines(state)
	_summary_maximum = -1
	refresh_status(state)
	set_tab(selected_tab)


func refresh_status(state: PlayerState) -> void:
	if state == null:
		return
	var chain := mini(state.movement_chain_count, MovementTuning.MOVEMENT_CHAIN_MAXIMUM_STEPS) if state.movement_chain_reset_ticks > 0 else 0
	if _summary_maximum == state.stamina_maximum and _summary_recovery == state.stamina_recovery_per_second and _summary_chain == chain:
		return
	_summary_maximum = state.stamina_maximum
	_summary_recovery = state.stamina_recovery_per_second
	_summary_chain = chain
	summary = Guide.summary_lines(state)
	_cache_key = ""


func set_tab(value: int) -> void:
	tab = clampi(value, MOVEMENT, CHEMISTRY)
	selected_row = 0
	show_details = false
	selected_element_column = 0
	_reset_detail()


func compact_overview() -> bool:
	return tab != CHARACTERS and not show_details


func toggle_details() -> void:
	if tab == CHARACTERS:
		return
	show_details = not show_details
	detail_page = 0
	_cache_key = ""


func move_column(delta: int) -> void:
	if tab == CHEMISTRY:
		selected_element_column = clampi(selected_element_column + delta, 0, 7)
		if selected_row == 0:
			selected_row = 1
		detail_page = 0
		_cache_key = ""
	else:
		move_character(delta)


static func movement_overview_rect(row: int) -> Rect2:
	return Rect2(72, 190 + row * 23, 1136, 23) if row >= 0 and row < 16 else Rect2()


static func chemistry_overview_rect(row: int, column: int) -> Rect2:
	return Rect2(192 + column * 127, 211 + row * 42, 127, 42) if row >= 0 and row < 8 and column >= 0 and column < 8 else Rect2()


func overview_hit(pointer: Vector2) -> bool:
	if not compact_overview():
		return false
	if tab == MOVEMENT:
		for row: int in range(movement_rows.size()):
			if movement_overview_rect(row).has_point(pointer):
				selected_row = row
				_reset_detail()
				return true
	elif tab == CHEMISTRY:
		if PRIMER_RECT.has_point(pointer):
			selected_row = 0
			_reset_detail()
			return true
		for row: int in range(8):
			for column: int in range(8):
				if chemistry_overview_rect(row, column).has_point(pointer):
					selected_row = row + 1
					selected_element_column = column
					_reset_detail()
					return true
	return false


func close_panel() -> void:
	is_open = false


func row_count() -> int:
	if tab == CHEMISTRY:
		return chemistry_rows.size()
	return movement_rows.size() if tab == MOVEMENT else (overview.get("rows", []) as Array).size()


func move_row(delta: int) -> void:
	selected_row = clampi(selected_row + delta, 0, maxi(0, row_count() - 1))
	_reset_detail()


func move_character(delta: int) -> void:
	var entries := _characters()
	if entries.is_empty():
		return
	selected_character = posmod(selected_character + delta, entries.size())
	detail_page = 0
	_cache_key = ""


func visible_row_indices() -> Array[int]:
	var first := (selected_row / ROWS_PER_PAGE) * ROWS_PER_PAGE
	var result: Array[int] = []
	for index: int in range(first, mini(first + ROWS_PER_PAGE, row_count())):
		result.append(index)
	return result


func change_detail_page(delta: int, font: Font) -> void:
	show_details = true
	var pages := detail_pages(font)
	detail_page = clampi(detail_page + delta, 0, maxi(0, pages - 1))


func detail_pages(font: Font) -> int:
	_ensure_wrapped(font)
	return maxi(1, ceili(float(_wrapped_lines.size()) / detail_line_limit()))


func visible_detail_lines(font: Font) -> Array[String]:
	_ensure_wrapped(font)
	detail_page = clampi(detail_page, 0, detail_pages(font) - 1)
	return _wrapped_lines.slice(detail_page * detail_line_limit(), (detail_page + 1) * detail_line_limit())


func detail_line_limit() -> int:
	return PAIR_LINES_PER_PAGE if tab == CHEMISTRY and selected_row > 0 else LINES_PER_PAGE


func chemistry_title() -> String:
	if selected_row == 0:
		return "Start here  /  the first-eight chemistry sandbox"
	var cell := hex_matrix_cell(selected_row - 1, selected_element_column)
	return "%s + %s = %s" % [cell.first, cell.second, cell.name] if not cell.is_empty() else "Reaction unavailable"


func chemistry_phase_strip() -> Array[Dictionary]:
	if tab != CHEMISTRY or selected_row <= 0:
		return []
	var cell := hex_matrix_cell(selected_row - 1, selected_element_column)
	if cell.is_empty():
		return []
	var durations: Array[int] = [int(cell.formation_ticks), int(cell.active_ticks), int(cell.decay_ticks)]
	var labels := ["Warning", "Active effects", "Harmless decay"]
	var total := durations[0] + durations[1] + durations[2]
	var elapsed := 0
	var phases: Array[Dictionary] = []
	for index: int in range(3):
		var left := PHASE_STRIP.position.x + PHASE_STRIP.size.x * float(elapsed) / maxf(1.0, total)
		elapsed += durations[index]
		var right := PHASE_STRIP.position.x + PHASE_STRIP.size.x * float(elapsed) / maxf(1.0, total)
		phases.append({"label": labels[index], "duration_ticks": durations[index], "duration_ms": durations[index] * 1000 / HexPolicy.TICK_RATE, "rectangle": Rect2(left, PHASE_STRIP.position.y, right - left, PHASE_STRIP.size.y)})
	return phases


func detail_paragraphs() -> Array[String]:
	var result: Array[String] = []
	if tab == CHEMISTRY:
		if selected_row > 0:
			return hex_pair_lines(selected_row - 1, selected_element_column)
		if selected_row < chemistry_rows.size():
			for line: String in chemistry_rows[selected_row]["lines"]:
				result.append(line)
			if selected_row == 0:
				result.append_array(spell_catalog_lines())
		return result
	if tab == MOVEMENT:
		if movement_rows.is_empty():
			return result
		result = Guide.detail_lines(movement_rows[selected_row])
		result.append("")
		result.append("SHARED MOVEMENT RULES")
		for line: String in summary:
			result.append("- " + line)
		return result
	var entries := _characters()
	if entries.is_empty():
		return ["No character is assigned to this race yet.", Overview.RACE_RULE_NOTE]
	var entry: Dictionary = entries[selected_character]
	var affinity_labels: Array[String] = []
	for affinity: String in entry["affinities"]:
		affinity_labels.append(AbilityCatalog.element_display_name(affinity))
	result.append("Body: %s | %s affinities: %s" % [String(entry["body_type"]).capitalize(), String(entry["affinity_status"]), ", ".join(affinity_labels)])
	var points: Dictionary = entry["affinity_points"]
	var point_labels: Array[String] = []
	for affinity: String in entry["affinities"]:
		point_labels.append("%s %s" % [AbilityCatalog.element_display_name(affinity), str(points.get(affinity, 0))])
	result.append("Affinity points: " + "; ".join(point_labels))
	if bool(entry["stats_available"]):
		for line: String in entry["stat_lines"]:
			result.append("- " + line)
		result.append("Playstyle: " + String(entry["playstyle"]))
		var profile: Dictionary = entry["body_profile"]
		result.append("Body role: " + String(profile.get("role", "")).capitalize())
		result.append("Strengths: " + _human_list(profile.get("strengths", [])))
		result.append("Tradeoffs: " + _human_list(profile.get("tradeoffs", [])))
		result.append("Hurtbox radius: %d px. Wall clearance: 18 px for every size. Pose changes never resize either footprint." % (int(entry["hurt_radius"]) / 1000))
		var kit: Dictionary = entry["foundation_kit"]
		var kit_keys: Array = kit.keys()
		kit_keys.sort()
		for key: String in kit_keys:
			result.append("Starting %s: %s" % [key.replace("_", " "), str(kit[key]).replace("_", " ")])
		result.append("Change playable champion at the Champion Gallery; configure spells at the Spell Loom.")
	else:
		result.append(String(entry["note"]))
		result.append("This record cannot be selected or used in combat.")
	if not String(entry["reserved_future_affinity"]).is_empty():
		result.append("Future affinity (not active): " + AbilityCatalog.element_display_name(String(entry["reserved_future_affinity"])))
	result.append(Overview.RACE_RULE_NOTE)
	return result


static func hex_matrix_cell(row: int, column: int) -> Dictionary:
	if row < 0 or row >= ChemistryGuide.DISPLAY_WIRES.size() or column < 0 or column >= ChemistryGuide.DISPLAY_WIRES.size():
		return {}
	var first_wire := ChemistryGuide.DISPLAY_WIRES[row]
	var second_wire := ChemistryGuide.DISPLAY_WIRES[column]
	var wire := HexPolicy.recipe_wire(first_wire, second_wire)
	var definition := HexPolicy.definition(wire)
	if definition.is_empty():
		return {}
	return {
		"first": ChemistryGuide.ELEMENTS[first_wire],
		"second": ChemistryGuide.ELEMENTS[second_wire],
		"first_wire": first_wire,
		"second_wire": second_wire,
		"wire_id": wire,
		"name": String(definition.name),
		"effect": _hex_effect_text(wire, definition),
		"counter": String(definition.counter),
		"purpose": String(definition.purpose),
		"formation_ticks": int(definition.formation_ticks),
		"active_ticks": int(definition.active_ticks),
		"decay_ticks": int(definition.decay_ticks),
		"formation_ms": int(definition.formation_ticks) * 1000 / HexPolicy.TICK_RATE,
		"active_ms": int(definition.active_ticks) * 1000 / HexPolicy.TICK_RATE,
		"decay_ms": int(definition.decay_ticks) * 1000 / HexPolicy.TICK_RATE,
		"radius": int(definition.radius),
		"selection_radius": int(definition.get("selection_radius", definition.radius)),
		"length": int(definition.length),
		"pulse_ticks": int(definition.pulse_ticks),
		"pulse_damage": int(definition.pulse_damage),
		"flow_speed": int(definition.flow_speed),
		"flow_kind": String(definition.flow_kind),
		"slow_ratio": int(definition.slow_ratio),
		"ground_only": bool(definition.ground_only),
		"transparent": bool(definition.get("transparent", false)),
		"conceals": bool(definition.get("conceals", false)),
		"quantity_policy": String(definition.quantity_policy),
		"selection_kind": String(definition.selection_kind),
		"health": int(definition.health),
		"capacity": int(definition.capacity),
		"motion_speed": int(definition.motion_speed),
	}


static func hex_pair_lines(row: int, column: int) -> Array[String]:
	var cell := hex_matrix_cell(row, column)
	if cell.is_empty():
		return []
	var lines: Array[String] = [
		String(cell.effect),
		"COUNTER: " + String(cell.counter).capitalize() + ".",
		"PHASES: forming %d ticks (%.2f s) -> active %d ticks (%.2f s) -> harmless decay %d ticks (%.2f s)." % [cell.formation_ticks, float(cell.formation_ticks) / HexPolicy.TICK_RATE, cell.active_ticks, float(cell.active_ticks) / HexPolicy.TICK_RATE, cell.decay_ticks, float(cell.decay_ticks) / HexPolicy.TICK_RATE],
		"SELECTION: %s. Quantity: %s." % [_selection_description(cell), String(cell.quantity_policy).replace("_", " ")],
	]
	if int(cell.pulse_ticks) > 0:
		lines.append("PULSE: every %d ticks (%.2f s)%s." % [cell.pulse_ticks, float(cell.pulse_ticks) / HexPolicy.TICK_RATE, "; %.0f damage" % (float(cell.pulse_damage) / 1000.0) if int(cell.pulse_damage) > 0 else ""])
	elif int(cell.pulse_damage) > 0:
		lines.append("PULSE: one activation attempt; %.0f damage." % (float(cell.pulse_damage) / 1000.0))
	if int(cell.flow_speed) > 0:
		lines.append("FLOW: %s at %.0f px/s." % [String(cell.flow_kind).replace("_", " "), float(cell.flow_speed) / 1000.0])
	if int(cell.slow_ratio) != 1000:
		lines.append("MOVEMENT: %.0f%% target ratio%s." % [float(cell.slow_ratio) / 10.0, " on the ground" if bool(cell.ground_only) else ""])
	lines.append_array(_first_ten_policy_lines(int(cell.wire_id)))
	lines.append("Offline, or the host during Hearth free practice, can request a real paid two-cast demonstration. Reset Wellspring restarts shared practice, retaining equipped weaves while clearing paid fields and practice targets.")
	return lines


static func _hex_effect_text(wire: int, definition: Dictionary) -> String:
	if wire == 310:
		return "Transparent Steam applies visible capped scald pressure while occupied. Exposure falls by 2 per exit tick; Steam does not conceal silhouettes."
	return String(definition.purpose).capitalize() + "."


static func _selection_description(cell: Dictionary) -> String:
	match String(cell.selection_kind):
		"disk":
			return "disk; selection radius %.0f px" % (float(cell.selection_radius) / 1000.0)
		"sector":
			return "sector; directional reach %.0f px" % (float(cell.length) / 1000.0)
		"capsule":
			return "capsule; radius %.0f px / length %.0f px" % [float(cell.radius) / 1000.0, float(cell.length) / 1000.0]
		"annulus":
			return "annulus; inner radius %.0f px / outer radius %.0f px" % [float(cell.length) / 1000.0, float(cell.radius) / 1000.0]
	return String(cell.selection_kind).replace("_", " ")


static func _first_ten_policy_lines(wire: int) -> Array[String]:
	var definition := HexPolicy.definition(wire)
	if definition.is_empty():
		return []
	match wire:
		301:
			return ["POLICY: six-face hex pillar; %.0f health; safe creation escape." % (float(definition.health) / 1000.0)]
		302:
			return ["POLICY: %.0f damage per pulse; %.0f%% ground movement; lowest-ratio stacking; instant exit." % [float(definition.pulse_damage) / 1000.0, float(definition.slow_ratio) / 10.0]]
		303:
			return ["POLICY: %.0f%% ground acceleration and %.0f%% braking; no immobilize; instant exit." % [float(definition.ground_acceleration_ratio) / 10.0, float(definition.ground_braking_ratio) / 10.0]]
		304:
			return ["POLICY: transparent lateral flow at %.0f px/s; does not trap." % (float(definition.flow_speed) / 1000.0)]
		309:
			return ["POLICY: committed ground burn; %.0f damage every %d ticks." % [float(definition.pulse_damage) / 1000.0, int(definition.pulse_ticks)]]
		310:
			return ["POLICY: exposure cap %d; exit decay %d per tick; %.0f-%.0f scald damage; one Heat and one Cool use." % [int(definition.exposure_cap), int(definition.exposure_exit_decay), float(definition.exposure_damage_min) / 1000.0, float(definition.exposure_damage_max) / 1000.0]]
		311:
			return ["POLICY: obstacle-aware front; contact refresh changes neither payload nor lifetime."]
		316:
			return ["POLICY: directional grounded flow at %.0f px/s; common wall clearance %.0f px." % [float(definition.flow_speed) / 1000.0, float(definition.common_wall_clearance) / 1000.0]]
		317:
			return ["POLICY: transparent steering; finite suppression %d of %d capacity; no pulse damage." % [int(definition.suppression_quantity), int(definition.capacity)]]
		322:
			return ["POLICY: tangential rotation at %.0f px/s; projectile speed 100%%; neither immobilizes nor traps." % (float(definition.flow_speed) / 1000.0)]
	return []


static func spell_catalog_lines() -> Array[String]:
	# Stable representative wires share the authored family templates. Costs and
	# geometry come from the same compiled definitions used by spell execution.
	var heavy := CombatTuning.cast_definition(179)
	var rapid := CombatTuning.cast_definition(180)
	var spray := CombatTuning.cast_definition(141)
	if heavy.is_empty() or rapid.is_empty() or spray.is_empty():
		return ["Spell-family details are unavailable until the catalog loads."]
	var elements := AbilityCatalog.FIRST_EIGHT_ELEMENTS.size()
	var families := AbilityCatalog.SPELL_MATRIX_FAMILIES.size()
	return [
		"SPELL FAMILIES / compare them at the Pattern Range",
		"%d elements x %d families = %d selectable spells." % [elements,families,elements*families],
		"Columns: Bolt / Heavy / Rapid / Spray. Your twelve configured spell positions and current bindings are unchanged.",
		"Bolt is single-shot pressure; Heavy adds impact splash; Rapid repeats while held; Spray covers a close cone.",
		"Heavy: %d Flux; %d damage in a %d px-radius blast when the shell stops. Aim between nearby targets to compare splash with a direct hit." % [int(heavy.flux_cost)/SimConfig.FIXED_SCALE,int(heavy.blast_damage)/SimConfig.FIXED_SCALE,int(heavy.blast_radius)/SimConfig.FIXED_SCALE],
		"Rapid: hold its configured spell-slot button to repeat; %d Flux per shot and %d ms cooldown. Release stops firing; every shot still needs Flux and free capacity." % [int(rapid.flux_cost)/SimConfig.FIXED_SCALE,int(rapid.cooldown_ms)],
		"Spray: %d Flux for a widening %d px cone after startup. A surviving paid pulse leaves one finite terminal ingredient at its ground target within reach." % [int(spray.flux_cost)/SimConfig.FIXED_SCALE,int(spray.range)/SimConfig.FIXED_SCALE],
		"Unified Wellspring uses finite strength subtraction for every enabled first-eight ingredient layer. Spray catches weaker Rapid, while an intersecting stronger Bolt or Heavy stops the pulse; surviving matter keeps only its paid remainder.",
		"Chemistry pairs create timed reaction areas from two distinct paid sources through eligible clash, field contact or overlapping deposited matter; they are not standalone spell deliveries.",
		"Wave, Beam, Field and Vector Lance remain authored catalog references, but they are disabled for runtime selection.",
	]


func handle_event(event: InputEvent, font: Font, pointer: Vector2 = Vector2(-1, -1)) -> bool:
	if not is_open:
		return false
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER:
				toggle_details()
			KEY_ESCAPE, KEY_F4:
				close_panel()
			KEY_TAB:
				set_tab(posmod(tab + (-1 if event.shift_pressed else 1), 3))
			KEY_UP:
				move_row(-1)
			KEY_DOWN:
				move_row(1)
			KEY_HOME:
				move_row(-ROWS_PER_PAGE)
			KEY_END:
				move_row(ROWS_PER_PAGE)
			KEY_LEFT:
				move_column(-1)
			KEY_RIGHT:
				move_column(1)
			KEY_PAGEUP:
				change_detail_page(-1, font)
			KEY_PAGEDOWN:
				change_detail_page(1, font)
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_A:
				toggle_details()
			JOY_BUTTON_BACK, JOY_BUTTON_B:
				close_panel()
			JOY_BUTTON_LEFT_SHOULDER:
				set_tab(posmod(tab - 1, 3))
			JOY_BUTTON_RIGHT_SHOULDER:
				set_tab(posmod(tab + 1, 3))
			JOY_BUTTON_DPAD_UP:
				move_row(-1)
			JOY_BUTTON_DPAD_DOWN:
				move_row(1)
			JOY_BUTTON_DPAD_LEFT:
				move_column(-1)
			JOY_BUTTON_DPAD_RIGHT:
				move_column(1)
			JOY_BUTTON_X:
				change_detail_page(-1, font)
			JOY_BUTTON_Y:
				change_detail_page(1, font)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			move_row(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			move_row(1)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if CLOSE_RECT.has_point(pointer):
				close_panel()
			elif OVERVIEW_TOGGLE.has_point(pointer) and tab != CHARACTERS:
				toggle_details()
			elif overview_hit(pointer):
				pass
			elif MOVEMENT_TAB.has_point(pointer):
				set_tab(MOVEMENT)
			elif CHARACTERS_TAB.has_point(pointer):
				set_tab(CHARACTERS)
			elif CHEMISTRY_TAB.has_point(pointer):
				set_tab(CHEMISTRY)
			elif compact_overview():
				pass # Hidden reader controls must not receive overview clicks.
			elif PREVIOUS_ROWS.has_point(pointer):
				move_row(-ROWS_PER_PAGE)
			elif NEXT_ROWS.has_point(pointer):
				move_row(ROWS_PER_PAGE)
			elif PREVIOUS_DETAIL.has_point(pointer):
				change_detail_page(-1, font)
			elif NEXT_DETAIL.has_point(pointer):
				change_detail_page(1, font)
			elif Rect2(402, 151, 794, 37).has_point(pointer):
				move_character(1)
			elif LIST_RECT.has_point(pointer):
				var first := (selected_row / ROWS_PER_PAGE) * ROWS_PER_PAGE
				selected_row = mini(first + int((pointer.y - LIST_RECT.position.y) / 40.0), row_count() - 1)
				_reset_detail()
	# Swallow all gameplay key/mouse/controller events, including releases. The
	# integration sends neutral commands while this overlay is visible.
	return true


func draw(canvas: CanvasItem, font: Font) -> void:
	canvas.draw_rect(Rect2(0, 0, 1280, 720), Color("07110e88"))
	canvas.draw_rect(PANEL, INK)
	canvas.draw_rect(PANEL, BRASS, false, 2.0)
	_text(canvas, font, Vector2(72, 88), "TRAVELLER'S COMPENDIUM", 26, PARCHMENT)
	_button(canvas, font, CLOSE_RECT, "Close", false)
	_button(canvas, font, MOVEMENT_TAB, "MOVEMENT", tab == MOVEMENT)
	_button(canvas, font, CHARACTERS_TAB, "CHARACTERS", tab == CHARACTERS)
	_button(canvas, font, CHEMISTRY_TAB, "CHEMISTRY", tab == CHEMISTRY)
	if tab != CHARACTERS:
		_button(canvas, font, OVERVIEW_TOGGLE, "Overview" if show_details else "Details  [Enter / A]", show_details)
	if compact_overview():
		_draw_compact_overview(canvas, font)
		return
	canvas.draw_line(Vector2(386, 164), Vector2(386, 607), Color(BRASS, 0.5))
	var indices := visible_row_indices()
	for offset: int in range(indices.size()):
		var index := indices[offset]
		var row_rect := Rect2(72, 164 + offset * 40, 298, 38)
		if index == selected_row:
			canvas.draw_rect(row_rect, Color("4c482bee"))
			canvas.draw_rect(row_rect, BRASS, false, 1.0)
		var label: String
		if tab == MOVEMENT:
			label = String(movement_rows[index]["title"])
		elif tab == CHEMISTRY:
			label = String(chemistry_rows[index]["title"])
		else:
			var race: Dictionary = overview["rows"][index]
			label = "%s  (%d)" % [race["race"], (race["champions"] as Array).size()]
		_text(canvas, font, row_rect.position + Vector2(10, 25), label, 17, PARCHMENT if index == selected_row else MUTED)
	var title := ""
	if tab == MOVEMENT and not movement_rows.is_empty():
		var row: Dictionary = movement_rows[selected_row]
		title = "%s  |  %s" % [row["title"], row["binding"]]
	elif tab == CHARACTERS:
		title = character_title()
	elif tab == CHEMISTRY and not chemistry_rows.is_empty():
		title = chemistry_title()
	var pair_selected := tab == CHEMISTRY and selected_row > 0
	if pair_selected:
		var cell := hex_matrix_cell(selected_row - 1, selected_element_column)
		for index: int in range(2):
			var element_wire := int(cell.first_wire if index == 0 else cell.second_wire)
			var element := ChemistryGuide.ELEMENT_IDS[element_wire]
			ElementGlyphRenderer.draw(canvas, visual_language, Vector2(413 + index * 25, 169), element, 8, visual_language.element_color(element, "bright"))
	_text(canvas, font, Vector2(458 if pair_selected else 402, 176), fit_text(title, font, 738 if pair_selected else 794, 19), 19, PARCHMENT)
	if pair_selected:
		var phases := chemistry_phase_strip()
		var pair := hex_matrix_cell(selected_row - 1, selected_element_column)
		var element := String(ChemistryGuide.ELEMENT_IDS[int(pair.first_wire)])
		var colors := [visual_language.element_phase_color(element, "forming", "bright"), visual_language.element_phase_color(element, "active", "base"), visual_language.element_phase_color(element, "decaying", "dark")]
		if String(pair.name).to_lower() == "steam":
			colors = [visual_language.reaction_phase_color("steam", "forming", "bright"), visual_language.reaction_phase_color("steam", "active", "base"), visual_language.reaction_phase_color("steam", "decaying", "dark")]
		for index: int in range(phases.size()):
			var phase: Dictionary = phases[index]
			canvas.draw_rect(phase.rectangle, colors[index])
			var legend := "%s  %.2fs" % [phase.label, float(phase.duration_ticks) / HexPolicy.TICK_RATE]
			_text(canvas, font, Vector2(402 + index * 265, 235), legend, 15, colors[index])
	var lines := visible_detail_lines(font)
	for index: int in range(lines.size()):
		_text(canvas, font, Vector2(402, (267 if pair_selected else 210) + index * LINE_HEIGHT), lines[index], FONT_SIZE, PARCHMENT)
	_button(canvas, font, PREVIOUS_ROWS, "< Rows", false)
	_button(canvas, font, NEXT_ROWS, "Rows >", false)
	_button(canvas, font, PREVIOUS_DETAIL, "< Details", false)
	_button(canvas, font, NEXT_DETAIL, "Details >", false)
	_text(canvas, font, Vector2(596, 595), "Detail page %d / %d" % [detail_page + 1, detail_pages(font)], 16, MUTED)
	var navigation := "Arrows / D-pad: pair    Wheel: first element    Enter / A: overview" if tab == CHEMISTRY else "Up Down / wheel: rows    Left Right: character"
	_text(canvas, font, Vector2(72, 632), "Tab / LB RB: section    %s    PgUp PgDn / X Y: pages" % navigation, 15, MUTED)
	_text(canvas, font, Vector2(72, 658), "F4 / Back: close  |  Your controls are resting. The shared world does not pause.", 16, BRASS)


func _draw_compact_overview(canvas: CanvasItem, font: Font) -> void:
	if tab == MOVEMENT:
		for column: int in range(MOVE_HEADERS.size()):
			_text(canvas, font, Vector2(MOVE_COLUMNS[column] + 7, 181), MOVE_HEADERS[column], 16, BRASS)
		for row: int in range(movement_rows.size()):
			var rectangle := movement_overview_rect(row)
			canvas.draw_rect(rectangle, Color("4c482bee") if row == selected_row else Color("202a2388") if row % 2 == 0 else Color("141a1788"))
			if row == selected_row:
				canvas.draw_rect(rectangle, BRASS, false, 1.0)
			var cells := Guide.compact_cells(movement_rows[row])
			for column: int in range(cells.size()):
				var width: float = MOVE_COLUMNS[column + 1] - MOVE_COLUMNS[column] - 14.0
				_text(canvas, font, Vector2(MOVE_COLUMNS[column] + 7, rectangle.position.y + 17), fit_text(cells[column], font, width, 16), 16, PARCHMENT if row == selected_row else MUTED)
		_text(canvas, font, Vector2(72, 575), "Base Stamina before combo premiums; hold drain is additional. Body budgets and exact conditions: Details.", 15, BRASS)
	else:
		_button(canvas, font, PRIMER_RECT, "Start here", selected_row == 0)
		for element: int in range(8):
			var element_wire := ChemistryGuide.DISPLAY_WIRES[element]
			var name := ChemistryGuide.ELEMENTS[element_wire]
			var element_id := ChemistryGuide.ELEMENT_IDS[element_wire]
			var color := visual_language.element_color(element_id, "bright")
			var header := Rect2(192 + element * 127, 166, 127, 34)
			canvas.draw_rect(header, Color("202a23"))
			ElementGlyphRenderer.draw(canvas, visual_language, header.position + Vector2(13, 17), element_id, 7, color)
			_text(canvas, font, header.position + Vector2(27, 23), name, 16, color)
			var side := Vector2(72, 211 + element * 42)
			ElementGlyphRenderer.draw(canvas, visual_language, side + Vector2(9, 13), element_id, 7, color)
			_text(canvas, font, side + Vector2(23, 19), name, 16, color)
			_text(canvas, font, side + Vector2(23, 36), "%.1fs matter" % (float(HexChemistryWorld.ingredient_lifetime(element_wire)) / 120.0), 12, MUTED)
		for row: int in range(8):
			for column: int in range(8):
				var rectangle := chemistry_overview_rect(row, column)
				var selected := selected_row == row + 1 and selected_element_column == column
				canvas.draw_rect(rectangle.grow(-1), Color("51472a") if selected else Color("25352b") if row == column else Color("202a23"))
				if selected:
					canvas.draw_rect(rectangle.grow(-1), PARCHMENT, false, 2.0)
				var cell := hex_matrix_cell(row, column)
				var lines := wrap_text(String(cell.get("name", "Unavailable")), font, rectangle.size.x - 12.0, 14)
				for line: int in range(mini(2, lines.size())):
					_text(canvas, font, rectangle.position + Vector2(6, 17 + line * 17), fit_text(lines[line], font, rectangle.size.x - 12, 14), 14, PARCHMENT if selected else MUTED)
		_text(canvas, font, Vector2(72, 570), "Both orders match: 36 reactions. Non-burning ingredients are harmless; active Fire and reactions use authored effects.", 15, BRASS)
	var selected := compact_summary(font)
	for line: int in range(selected.size()):
		_text(canvas, font, Vector2(72, 597 + line * 22), selected[line], 16, PARCHMENT)
	_text(canvas, font, Vector2(72, 648), "Tab / LB RB: section   Arrows / D-pad: select   Enter / A: details   F4 / Back: close", 15, MUTED)
	_text(canvas, font, Vector2(72, 668), "Reading blocks your controls, not the shared world.", 13, BRASS)


func compact_summary(font: Font) -> Array[String]:
	var lines: Array[String] = []
	if tab == MOVEMENT and not movement_rows.is_empty():
		var row: Dictionary = movement_rows[selected_row]
		lines = [String(row.execution), String(row.counter)]
	elif tab == CHEMISTRY and selected_row > 0:
		var cell := hex_matrix_cell(selected_row - 1, selected_element_column)
		lines = ["%s + %s = %s  |  %.2fs form > %.2fs active > %.2fs decay" % [cell.first, cell.second, cell.name, float(cell.formation_ticks) / HexPolicy.TICK_RATE, float(cell.active_ticks) / HexPolicy.TICK_RATE, float(cell.decay_ticks) / HexPolicy.TICK_RATE], String(cell.effect) + " Counter: " + String(cell.counter)]
	else:
		lines = ["Throughout Wellspring: separate paid casts react on eligible ground wherever their matter overlaps; no dummy is required. Matched portions are consumed; unmatched live matter remains.", "All eight ingredient layers use finite matter, selected whole hexes and the current symmetric 36-recipe policy."]
	var result: Array[String] = []
	for line: String in lines:
		result.append(fit_text(line, font, 1136.0, 16))
	return result


static func fit_text(value: String, font: Font, width: float, size: int) -> String:
	if font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
		return value
	var result := value
	while not result.is_empty() and font.get_string_size(result + "...", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		result = result.left(result.length() - 1)
	return result + "..."


func character_title() -> String:
	var entries := _characters()
	if entries.is_empty():
		return "Race awaiting a champion"
	var entry: Dictionary = entries[selected_character]
	var title := "%s  /  %s" % [entry["display_name"], String(entry["status"]).to_upper()]
	if entries.size() > 1:
		title += "  [%d/%d: Left / Right]" % [selected_character + 1, entries.size()]
	return title


static func wrap_text(value: String, font: Font, width: float, size: int = FONT_SIZE) -> Array[String]:
	# Measure the actual loaded font, including a bounded split for a long bind
	# name or translated word. No paragraph is dropped when it spans a page.
	var lines: Array[String] = []
	var limit := maxf(1.0, width)
	for paragraph: String in value.split("\n", true):
		var line := ""
		for word: String in paragraph.split(" ", false):
			var candidate := word if line.is_empty() else line + " " + word
			if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= limit:
				line = candidate
				continue
			if not line.is_empty():
				lines.append(line)
			line = ""
			for character: String in word:
				if not line.is_empty() and font.get_string_size(line + character, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > limit:
					lines.append(line)
					line = ""
				line += character
		lines.append(line)
	return lines


func _ensure_wrapped(font: Font) -> void:
	var key := "%d/%d/%d/%d/%d" % [tab, selected_row, selected_character, selected_element_column, font.get_instance_id()]
	if key == _cache_key:
		return
	_cache_key = key
	_wrapped_lines.clear()
	for paragraph: String in detail_paragraphs():
		_wrapped_lines.append_array(wrap_text(paragraph, font, DETAIL_WIDTH))


func _reset_detail() -> void:
	selected_character = 0
	detail_page = 0
	_cache_key = ""


func _characters() -> Array:
	var rows: Array = overview.get("rows", [])
	return rows[selected_row]["champions"] if tab == CHARACTERS and selected_row >= 0 and selected_row < rows.size() else []


static func _human_list(values: Array) -> String:
	var labels: Array[String] = []
	for value: String in values:
		labels.append(value.replace("_", " "))
	return ", ".join(labels)


static func _text(canvas: CanvasItem, font: Font, position: Vector2, value: String, size: int, color: Color) -> void:
	canvas.draw_string(font, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func _button(canvas: CanvasItem, font: Font, rectangle: Rect2, label: String, active: bool) -> void:
	canvas.draw_rect(rectangle, Color("51472a") if active else Color("202a23"))
	canvas.draw_rect(rectangle, BRASS if active else Color(BRASS, 0.5), false, 1.0)
	_text(canvas, font, rectangle.position + Vector2(12, 23), label, 17, PARCHMENT)


static func unified_chemistry_primer() -> Array[String]:
	return [
		"CAST -> SELECT HEXES -> COMBINE -> COUNTER",
		"1. In the Spell Loom, equip Fire Bolt + Water Bolt. Matching reaction strength is convenient: same-family spells make the direct match. Heavy + Heavy, Rapid + Rapid and Spray + Spray also work.",
		"2. Cast them separately at the same nearby endpoint before the first material expires: Water 6 seconds, Fire 4 seconds. Other ingredients last 3-5 seconds. Overlapping matter and a clear path are required; one cast cannot react with itself.",
		"3. Watch formation -> active -> decay: only the active window applies reaction effects. Each cast supplies a finite 600-unit budget shared by flight, trails and ground material.",
		"4. Choose an element row for its pair effects and counters. Offline, or the host during Hearth free practice, can run the matrix's two real paid casts; it restores the equipped weave afterward. Reset Wellspring restarts shared practice, retains weaves, and clears paid fields and practice targets.",
		"WHOLE HEXES: chemistry works throughout Wellspring, including away from practice targets. The exact impact point and radius select cells. Every selected hex is affected across its applicable layer, including positions beyond the selection disk. Unselected neighbours stay clear. Movement and projectiles remain continuous.",
		"SIGHT: one 360-degree view follows your character, or the character you spectate, within 720 ground units. Aim and camera zoom do not expand sight. Opaque buildings and active solid hex cover hide other characters, their labels and attached feedback. Low cover and transparent Steam do not become walls. F8-F10 no longer change vision.",
		"SPELL IMPACT: direct flight, actor collision and Heavy splash retain their continuous geometry. Every attack costs Flux; element colour alone does not grant another status.",
		"REACTION AREA: a finite reaction outcome, not a selectable spell delivery. Whole-hex elemental and product layers keep independent ownership, quantity and expiry even when they look connected.",
		"PLAIN TERMINAL MATTER: Water, Earth, Air, Ice, Charge, Light and Dark ingredients do not automatically apply their reaction effects. Fire becomes damaging burning ground after its ignition warning; it cools before expiry.",
		"SUBTRACTIVE CONTACT: projectile clashes, projectile-to-field contact and eligible overlapping terminal ingredients consume the smaller remaining strength from both sources. A stronger survivor keeps only its remaining strength and material. A destroyed projectile cannot damage or deposit later.",
		"Rapid 1, Spray 3, Bolt 5, Heavy 15. A surviving paid Spray pulse leaves one finite ingredient at its ground target within reach. It catches weaker Rapid; an intersecting stronger Bolt or Heavy stops the pulse. Moving projectile-to-projectile clashes use ordered continuous contact.",
		"Bolt and Heavy can allocate up to 150 of their 600 units to optional narrow trails. Rapid is explicitly trail-free regardless of reaction strength. A separate terminal can meet an older trail for a shorter sustained reaction; trail + trail never reacts.",
		"A deposit's lifetime is separate from the reaction area's duration. The lower cast identity supplies stable ownership; incoming direction can steer directional products. Connected visuals never refresh budgets or lifetimes.",
		"Reactions do not recursively clone more reactions. Admission reserves finite product capacity before payment. A full reservation budget refuses without spending Flux; no nearest-N cell truncation hides capacity limits.",
		"Steam is transparent capped scald pressure: hot vents mark active whole hexes and terminal brackets signal expiry. Exposure builds while you remain inside and decays after leaving; repeat crossings can meet additional fixed pressure pulses. One finite Fire heating and one Water cooling channel remain. Mistcurrent and Dustfront remain transparent. Later Dark combinations retain their existing concealment and reveal rules; close silhouettes and all dangerous geometry stay readable.",
		"Mud changes grounded acceleration/braking; Magma slows grounded travel while damaging. Flood, Dustfront, Mistcurrent and Vortex move grounded actors against real walls. Jump or Float above each effect's height limit; leaving restores temporary movement ratios immediately.",
		"Rampart alone has actor-solid six-sided faces and supports normal paid wallrun/walljump. Its warning and decay allow passage, and formation around an actor permits escape until clear. Other temporary cover blocks shots, rays and sight where applicable, but remains walk-through and cannot support wall movement.",
		"Linked recipes select separate sources during formation, not later: Plasma Arc needs extra Charge; Superconduct needs extra Ice. Conductive Flood also works locally without links. Missing linked sources stop the linked effect.",
		"Both pair orders share stable recipe identity: ten first-four combinations and 36 first-eight combinations. The live eight-player session uses one shared chemistry authority and reset epoch.",
	]
