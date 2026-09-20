class_name SpellLoomEditor
extends RefCounted


const CharacterStarterKitScript = preload("res://src/content/character_starter_kit.gd")


const LIBRARY_CAPACITY: int = SessionTransport.MAX_SPELL_LIBRARY_SIZE
const VISIBLE_SPELL_COUNT: int = 32
const PANEL_RECT := Rect2(24, 20, 1232, 680)
const GRID_X: float = 48.0
const GRID_Y: float = 154.0
const GRID_CELL_WIDTH: float = 110.0
const GRID_CELL_HEIGHT: float = 86.0
const MATRIX_LABEL_X: float = 498.0
const SPELL_PICKER_X: float = 564.0
const SPELL_PICKER_WIDTH: float = 156.0
const SPELL_PICKER_HEIGHT: float = 43.0
const FILTER_X: float = 564.0
const FILTER_Y: float = 104.0
const FILTER_WIDTH: float = 72.0
const FILTER_HEIGHT: float = 28.0
const DETAIL_DIVIDER_Y: float = 565.0
const ASSIGN_RECT := Rect2(1018, 624, 210, 38)
const CLOSE_RECT := Rect2(1200, 34, 34, 32)
const STARTER_BUTTON_RECT := Rect2(960, 66, 220, 34)
const STARTER_PREVIEW_RECT := Rect2(88, 52, 1104, 620)
const STARTER_PREVIEW_APPLY_RECT := Rect2(858, 614, 142, 38)
const STARTER_PREVIEW_CANCEL_RECT := Rect2(1016, 614, 142, 38)
const STARTER_CARD_ORIGIN := Vector2(112, 158)
const STARTER_CARD_SIZE := Vector2(516, 64)
const STARTER_CARD_COLUMN_PITCH: float = 540.0
const STARTER_CARD_ROW_PITCH: float = 70.0
const ELEMENT_FILTERS: Array[String] = ["", "water", "earth", "fire", "wind", "ice", "charge", "light", "dark"]

var is_open: bool = false
var selected_slot_index: int = 0
var selected_spell_index: int = 0
var available_wire_ids := PackedInt32Array(CombatTuning.runtime_wire_ids())
var element_by_wire: Dictionary = {}
var selected_element_filter: String = ""
var status_message: String = "Drag a spell onto a slot, or select both and choose Assign."
var drag_spell_index: int = -1
var drag_origin := Vector2.ZERO
var pointer_position := Vector2.ZERO
var dragging: bool = false
var starter_preview: Dictionary = {}


func open_editor(_state: PlayerState = null, catalog: AbilityCatalog = null) -> void:
	is_open = true
	configure_for_catalog(catalog)
	cancel_drag()
	cancel_starter_preview(false)
	status_message = "Drag a spell onto a slot, or select both and choose Assign."


func close_editor() -> void:
	if starter_preview_active():
		cancel_starter_preview()
		return
	is_open = false
	cancel_drag()
	cancel_starter_preview(false)
	status_message = ""


func move_selection(slot_delta: int, spell_delta: int) -> void:
	if starter_preview_active():
		return
	cancel_drag()
	selected_slot_index = posmod(selected_slot_index + slot_delta, PlayerState.SPELL_SLOT_COUNT)
	var visible := visible_spell_indices()
	if not visible.is_empty() and spell_delta != 0:
		var position := visible.find(selected_spell_index)
		if position < 0:
			position = 0
		selected_spell_index = visible[posmod(position + spell_delta, visible.size())]
	status_message = "Assign to %s with Enter / A." % PlayerState.spell_slot_label(selected_slot_index)


func select_at(position: Vector2) -> bool:
	if starter_preview_active():
		return false
	var filter := element_filter_at(position)
	if filter >= 0:
		set_element_filter(ELEMENT_FILTERS[filter])
		return true
	var slot := slot_at(position)
	if slot >= 0:
		selected_slot_index = slot
		return true
	for index: int in visible_spell_indices():
		if spell_rect(index).has_point(position):
			selected_spell_index = index
			return true
	return false


static func slot_rect(index: int) -> Rect2:
	return Rect2(GRID_X + (index % 4) * GRID_CELL_WIDTH, GRID_Y + (index / 4) * GRID_CELL_HEIGHT, GRID_CELL_WIDTH - 8, GRID_CELL_HEIGHT - 8)


static func starter_preview_slot_rect(index: int) -> Rect2:
	if index < 0 or index >= PlayerState.SPELL_SLOT_COUNT:
		return Rect2()
	return Rect2(
		STARTER_CARD_ORIGIN + Vector2((index / 6) * STARTER_CARD_COLUMN_PITCH, (index % 6) * STARTER_CARD_ROW_PITCH),
		STARTER_CARD_SIZE,
	)


func spell_rect(index: int) -> Rect2:
	var visible := visible_spell_indices()
	var visible_index := visible.find(index)
	if visible_index < 0:
		return Rect2()
	var columns := matrix_columns()
	var row := visible_index / columns
	var column := visible_index % columns
	return Rect2(SPELL_PICKER_X + column * SPELL_PICKER_WIDTH, GRID_Y + row * SPELL_PICKER_HEIGHT, SPELL_PICKER_WIDTH - 6, SPELL_PICKER_HEIGHT - 5)


static func element_filter_rect(index: int) -> Rect2:
	if index < 0 or index >= ELEMENT_FILTERS.size():
		return Rect2()
	return Rect2(FILTER_X + index * FILTER_WIDTH, FILTER_Y, FILTER_WIDTH - 4, FILTER_HEIGHT)


static func element_filter_at(position: Vector2) -> int:
	for index: int in range(ELEMENT_FILTERS.size()):
		if element_filter_rect(index).has_point(position):
			return index
	return -1


static func element_filter_label(element_id: String) -> String:
	return "All" if element_id.is_empty() else AbilityCatalog.element_display_name(element_id)


static func matrix_columns() -> int:
	return AbilityCatalog.SPELL_MATRIX_FAMILIES.size()


static func matrix_cell_count() -> int:
	return matrix_columns() * AbilityCatalog.FIRST_EIGHT_ELEMENTS.size()


static func slot_at(position: Vector2) -> int:
	for index: int in range(PlayerState.SPELL_SLOT_COUNT):
		if slot_rect(index).has_point(position):
			return index
	return -1


func pointer_down(position: Vector2, state: PlayerState) -> void:
	cancel_drag()
	pointer_position = position
	if starter_preview_active():
		return
	var filter := element_filter_at(position)
	if filter >= 0:
		set_element_filter(ELEMENT_FILTERS[filter])
		return
	drag_origin = position
	for index: int in visible_spell_indices():
		if spell_rect(index).has_point(position):
			selected_spell_index = index
			drag_spell_index = index
			return
	var slot := slot_at(position)
	if slot >= 0:
		selected_slot_index = slot
		if state != null:
			drag_spell_index = available_wire_ids.find(state.spell_wire_id(slot + 1))


func pointer_move(position: Vector2) -> void:
	pointer_position = position
	if starter_preview_active():
		return
	if drag_spell_index >= 0 and position.distance_squared_to(drag_origin) >= 36.0:
		dragging = true


func pointer_up(position: Vector2) -> bool:
	if starter_preview_active():
		pointer_position = position
		cancel_drag()
		return false
	pointer_move(position)
	var target := slot_at(position)
	var assign := dragging and drag_spell_index >= 0 and target >= 0
	if assign:
		selected_slot_index = target
		selected_spell_index = drag_spell_index
	elif dragging:
		status_message = "Drop cancelled. Your spells are unchanged."
	cancel_drag()
	return assign


func cancel_drag() -> void:
	drag_spell_index = -1
	dragging = false


func request_value() -> int:
	if starter_preview_active():
		return 0
	# Wire requests always use the canonical library, never filtered UI positions.
	var library_index := CombatTuning.runtime_wire_ids().find(selected_wire_id())
	return selected_slot_index * LIBRARY_CAPACITY + library_index + 1 if library_index >= 0 else 0


func selected_wire_id(_state: PlayerState = null) -> int:
	return available_wire_ids[selected_spell_index] if selected_spell_index >= 0 and selected_spell_index < available_wire_ids.size() else 0


func configure_for_catalog(catalog: AbilityCatalog) -> void:
	var prior_wire_id := selected_wire_id()
	available_wire_ids = PackedInt32Array()
	element_by_wire.clear()
	var runtime_wires := CombatTuning.runtime_wire_ids()
	for runtime_index: int in range(runtime_wires.size()):
		var wire_id: int = runtime_wires[runtime_index]
		if catalog == null or not catalog.ability_from_wire(wire_id).is_empty():
			available_wire_ids.append(wire_id)
			var element := ""
			if catalog != null:
				element = String(catalog.ability_from_wire(wire_id).get("element", ""))
			elif runtime_index / matrix_columns() < AbilityCatalog.FIRST_EIGHT_ELEMENTS.size():
				element = AbilityCatalog.FIRST_EIGHT_ELEMENTS[runtime_index / matrix_columns()]
			element_by_wire[wire_id] = element
	selected_spell_index = available_wire_ids.find(prior_wire_id)
	if selected_spell_index < 0:
		selected_spell_index = 0
	_coerce_selection_to_filter()


func set_element_filter(element_id: String) -> bool:
	if element_id not in ELEMENT_FILTERS:
		return false
	selected_element_filter = element_id
	_coerce_selection_to_filter()
	status_message = "%s spells shown. Choose a spell, then assign any of your twelve slots." % element_filter_label(element_id)
	return true


func _coerce_selection_to_filter() -> void:
	var visible := visible_spell_indices()
	if visible.is_empty() and not selected_element_filter.is_empty():
		selected_element_filter = ""
		visible = visible_spell_indices()
	if not visible.is_empty() and selected_spell_index not in visible:
		selected_spell_index = visible[0]


func visible_spell_indices() -> PackedInt32Array:
	var result := PackedInt32Array()
	for index: int in range(mini(VISIBLE_SPELL_COUNT, available_wire_ids.size())):
		var wire_id := int(available_wire_ids[index])
		if selected_element_filter.is_empty() or String(element_by_wire.get(wire_id, "")) == selected_element_filter:
			result.append(index)
	return result


func apply_to_state(state: PlayerState) -> bool:
	if starter_preview_active():
		status_message = "Choose Apply or Cancel for the starter preview first."
		return false
	if state == null or not state.place_proven_spell(selected_slot_index, selected_wire_id()):
		status_message = "Could not assign. Your spells are unchanged."
		return false
	status_message = "Assigned to %s. Equipped spells swap positions; cooldowns stay with the spell." % PlayerState.spell_slot_label(selected_slot_index)
	return true


func prepare_starter_preview(state: PlayerState, champion_catalog: ChampionCatalog, ability_catalog: AbilityCatalog) -> bool:
	cancel_drag()
	starter_preview = {}
	if state == null or champion_catalog == null or ability_catalog == null:
		status_message = "Starter preview is unavailable because its catalogs are not ready."
		return false
	var champion_id := champion_catalog.champion_id_from_wire(state.champion_wire_id)
	if champion_id.is_empty():
		status_message = "Starter preview is unavailable for this character."
		return false
	var proposal: Dictionary = CharacterStarterKitScript.build(champion_catalog, ability_catalog, champion_id)
	if not bool(proposal.get("valid", false)):
		status_message = String(proposal.get("error", "Starter preview could not be prepared."))
		return false
	var after_value: Variant = proposal.get("wire_ids", PackedInt32Array())
	if not after_value is PackedInt32Array:
		status_message = "Starter preview did not contain an authoritative wire list."
		return false
	var after_wire_ids: PackedInt32Array = after_value
	if after_wire_ids.size() != PlayerState.SPELL_SLOT_COUNT:
		status_message = "Starter preview did not contain exactly twelve spells."
		return false
	var before_wire_ids := PackedInt32Array()
	after_wire_ids = after_wire_ids.duplicate()
	var rows: Array[Dictionary] = []
	for slot_index: int in range(PlayerState.SPELL_SLOT_COUNT):
		var before_wire_id := state.spell_wire_id(slot_index + 1)
		var after_wire_id := int(after_wire_ids[slot_index])
		var before_ability: Dictionary = ability_catalog.ability_from_wire(before_wire_id)
		var after_ability: Dictionary = ability_catalog.ability_from_wire(after_wire_id)
		if after_ability.is_empty():
			starter_preview = {}
			status_message = "Starter preview contains an unavailable spell in %s." % PlayerState.spell_slot_label(slot_index)
			return false
		before_wire_ids.append(before_wire_id)
		var after_element := String(after_ability.get("element", ""))
		rows.append({
			"slot_index": slot_index,
			"slot_label": PlayerState.spell_slot_label(slot_index),
			"before_wire_id": before_wire_id,
			"before_name": String(before_ability.get("display_name", "Empty")),
			"before_element": String(before_ability.get("element", "")),
			"after_wire_id": after_wire_id,
			"after_name": String(after_ability.get("display_name", "Spell")),
			"after_element": after_element,
			"court_tag": starter_court_tag(after_element),
			"court_supported": starter_court_supported(after_element),
		})
	starter_preview = {
		"champion_id": champion_id,
		"before_wire_ids": before_wire_ids,
		"after_wire_ids": after_wire_ids,
		"rows": rows,
		"notice": "Applying replaces your custom weave. Cancel keeps every slot. Apply is the only save step.",
	}
	status_message = "Starter preview only. Review all twelve slots, then choose Apply or Cancel."
	return true


func starter_preview_active() -> bool:
	return not starter_preview.is_empty()


func cancel_starter_preview(show_status: bool = true) -> void:
	starter_preview = {}
	cancel_drag()
	if show_status:
		status_message = "Starter preview cancelled. Your custom weave is unchanged."


func request_starter_apply() -> Dictionary:
	if not starter_preview_active():
		return {}
	var before_value: Variant = starter_preview.get("before_wire_ids", PackedInt32Array())
	var after_value: Variant = starter_preview.get("after_wire_ids", PackedInt32Array())
	if not before_value is PackedInt32Array or not after_value is PackedInt32Array:
		return {}
	var expected_wire_ids: PackedInt32Array = before_value
	var proposed_wire_ids: PackedInt32Array = after_value
	return {
		"action": "apply_character_starter_kit",
		"champion_id": String(starter_preview.get("champion_id", "")),
		"expected_wire_ids": expected_wire_ids.duplicate(),
		"wire_ids": proposed_wire_ids.duplicate(),
	}


func complete_starter_apply(applied: bool) -> void:
	if applied:
		starter_preview = {}
		cancel_drag()
		status_message = "Character starter kit applied to all twelve slots."
	else:
		status_message = "Starter kit was not applied. Review or cancel this preview."


static func starter_court_supported(element_id: String) -> bool:
	return element_id in AbilityCatalog.FIRST_EIGHT_ELEMENTS


static func starter_court_tag(element_id: String) -> String:
	return "HEX COURT: %s" % AbilityCatalog.element_display_name(element_id).to_upper() if starter_court_supported(element_id) else "HEX EFFECT UNAVAILABLE"


static func decode_slot_index(value: int) -> int:
	return (value - 1) / LIBRARY_CAPACITY if value >= 1 and value <= SessionTransport.MAX_SPELL_EQUIP_VALUE else -1


static func decode_library_index(value: int) -> int:
	return (value - 1) % LIBRARY_CAPACITY if value >= 1 and value <= SessionTransport.MAX_SPELL_EQUIP_VALUE else -1


static func wire_id_for_library_index(library_index: int) -> int:
	var runtime_wire_ids := CombatTuning.runtime_wire_ids()
	return runtime_wire_ids[library_index] if library_index >= 0 and library_index < runtime_wire_ids.size() else 0
