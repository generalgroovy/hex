class_name SpellLoomEditor
extends RefCounted


const CharacterStarterKitScript = preload("res://src/content/character_starter_kit.gd")
const GridNavigation = preload("res://src/app/ui_grid_navigation.gd")
const Elements = preload("res://src/content/element_rules.gd")


const LIBRARY_CAPACITY: int = SessionTransport.MAX_SPELL_LIBRARY_SIZE
const VISIBLE_SPELL_COUNT: int = 16
const LIBRARY_TOP: float = 184.0
const PAGE_PREVIOUS_RECT := Rect2(564, 454, 76, 28)
const PAGE_NEXT_RECT := Rect2(1112, 454, 76, 28)
const MORE_FORMS_RECT := Rect2(1072, 104, 116, 28)
const FAMILY_FILTERS: Array[String] = ["", "bolt", "heavy", "rapid", "spray", "mantle", "fuse", "split", "rebound"]
const PANEL_RECT := Rect2(24, 20, 1232, 680)
const GRID_X: float = 48.0
const GRID_Y: float = 154.0
const GRID_CELL_WIDTH: float = 110.0
const GRID_CELL_HEIGHT: float = 86.0
const MATRIX_LABEL_X: float = 498.0
const SPELL_PICKER_X: float = 564.0
const SPELL_PICKER_WIDTH: float = 156.0
const SPELL_PICKER_HEIGHT: float = 64.0
const FILTER_X: float = 564.0
const FILTER_Y: float = 104.0
const FILTER_WIDTH: float = 72.0
const FILTER_HEIGHT: float = 28.0
const DETAIL_DIVIDER_Y: float = 565.0
const ASSIGN_RECT := Rect2(1018, 624, 210, 38)
const CLOSE_RECT := Rect2(1200, 34, 34, 32)
const STARTER_BUTTON_RECT := Rect2(960, 66, 220, 34)
const COMPARE_RECT := Rect2(748, 66, 198, 34)
const STARTER_PREVIEW_RECT := Rect2(88, 52, 1104, 620)
const STARTER_PREVIEW_APPLY_RECT := Rect2(858, 614, 142, 38)
const STARTER_PREVIEW_CANCEL_RECT := Rect2(1016, 614, 142, 38)
const STARTER_CARD_ORIGIN := Vector2(112, 158)
const STARTER_CARD_SIZE := Vector2(516, 64)
const STARTER_CARD_COLUMN_PITCH: float = 540.0
const STARTER_CARD_ROW_PITCH: float = 70.0
const ELEMENT_FILTERS: Array[String] = ["", "water", "fire", "wind", "earth", "light", "dark"]

var is_open: bool = false
var selected_slot_index: int = 0
var selected_spell_index: int = 0
var available_wire_ids := PackedInt32Array(CombatTuning.runtime_wire_ids())
var element_by_wire: Dictionary = {}
var mask_by_wire: Dictionary = {}
var family_by_wire: Dictionary = {}
var blocked_reason_by_wire: Dictionary = {}
var selected_element_filter: String = ""
var selected_element_mask: int = 0
var selected_family_filter: String = ""
var page_index: int = 0
var basic_forms_only: bool = true
var opened_once: bool = false
var status_message: String = "Drag a spell onto a slot, or select both and choose Assign."
var drag_spell_index: int = -1
var drag_origin := Vector2.ZERO
var pointer_position := Vector2.ZERO
var dragging: bool = false
var starter_preview: Dictionary = {}
var focus_area: String = "spells"
var reading_options_open := false
var compare_equipped: bool = false


func open_editor(state: PlayerState = null, catalog: AbilityCatalog = null) -> void:
	is_open = true
	focus_area = "spells"
	configure_for_catalog(catalog)
	if not opened_once and state != null:
		var first_wire := state.spell_wire_id(selected_slot_index + 1)
		set_element_mask(int(mask_by_wire.get(first_wire, 4)))
		if String(family_by_wire.get(first_wire, "bolt")) in ["mantle", "fuse", "split", "rebound"]: basic_forms_only = false
		selected_spell_index = maxi(0, available_wire_ids.find(first_wire))
		_coerce_selection_to_filter()
	opened_once = true
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
	if slot_delta != 0: focus_area = "slots"
	elif spell_delta != 0: focus_area = "spells"
	selected_slot_index = posmod(selected_slot_index + slot_delta, PlayerState.SPELL_SLOT_COUNT)
	var visible := filtered_spell_indices()
	if not visible.is_empty() and spell_delta != 0:
		var position := visible.find(selected_spell_index)
		if position < 0:
			position = 0
		selected_spell_index = visible[posmod(position + spell_delta, visible.size())]
		_reveal_selection()
	status_message = "Assign to %s with Enter / A." % PlayerState.spell_slot_label(selected_slot_index)


func select_at(position: Vector2) -> bool:
	if starter_preview_active():
		return false
	if COMPARE_RECT.has_point(position):
		compare_equipped = not compare_equipped
		return true
	var filter := element_filter_at(position)
	if filter >= 0:
		toggle_element_filter(ELEMENT_FILTERS[filter])
		return true
	if _select_library_control(position): return true
	var slot := slot_at(position)
	if slot >= 0:
		focus_area = "slots"
		selected_slot_index = slot
		return true
	for index: int in visible_spell_indices():
		if spell_rect(index).has_point(position):
			focus_area = "spells"
			selected_spell_index = index
			return true
	return false


# Directional navigation follows the visible row/column; only linear Tab/filter
# traversal wraps. Neither inspection nor navigation changes the equipped weave.
func navigate_grid(horizontal: int, vertical: int) -> void:
	if starter_preview_active():
		return
	cancel_drag()
	if focus_area == "slots":
		selected_slot_index = GridNavigation.neighbor(selected_slot_index, 12, 4, horizontal, vertical)
	else:
		var visible := filtered_spell_indices()
		if not visible.is_empty():
			var index := maxi(0, visible.find(selected_spell_index))
			selected_spell_index = visible[GridNavigation.neighbor(index, visible.size(), matrix_columns(), horizontal, vertical)]
			_reveal_selection()


func navigate_wheel(delta: int, position: Vector2) -> void:
	if delta == 0 or starter_preview_active():
		return
	var visible := visible_spell_indices()
	var slot_bounds := slot_rect(0).merge(slot_rect(PlayerState.SPELL_SLOT_COUNT - 1))
	var library_bounds := Rect2()
	for index: int in visible:
		var cell := spell_rect(index)
		library_bounds = library_bounds.merge(cell) if library_bounds.has_area() else cell
	# Hover owns the pane, including internal gutters. Outside both grids,
	# retain keyboard/controller focus; wheel navigation never wraps at an end.
	if slot_bounds.has_point(position):
		focus_area = "slots"
	elif library_bounds.has_point(position):
		focus_area = "spells"
	cancel_drag()
	if focus_area == "slots":
		selected_slot_index = clampi(selected_slot_index + delta, 0, PlayerState.SPELL_SLOT_COUNT - 1)
	elif not visible.is_empty():
		var filtered := filtered_spell_indices()
		var index := maxi(0, filtered.find(selected_spell_index))
		selected_spell_index = filtered[clampi(index + delta, 0, filtered.size() - 1)]
		_reveal_selection()
	status_message = "Assign to %s with Enter / A." % PlayerState.spell_slot_label(selected_slot_index)


func cycle_focus() -> void:
	if starter_preview_active():
		return
	cancel_drag()
	focus_area = "slots" if focus_area == "spells" else "spells"


func cycle_element_filter(delta: int) -> void:
	if starter_preview_active():
		return
	cancel_drag()
	set_element_mask(posmod(selected_element_mask + delta, 64))
	focus_area = "spells"


func assignment_preview(state: PlayerState) -> Dictionary:
	if state == null or selected_wire_id() <= 0:
		return {"kind": "unavailable", "other_slot": -1}
	var existing := state.spell_wire_ids.find(selected_wire_id())
	return {"kind": "unchanged" if existing == selected_slot_index else ("swap" if existing >= 0 else "replace"), "other_slot": existing}


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
	return Rect2(SPELL_PICKER_X + column * SPELL_PICKER_WIDTH, LIBRARY_TOP + row * SPELL_PICKER_HEIGHT, SPELL_PICKER_WIDTH - 6, SPELL_PICKER_HEIGHT - 5)


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
	return 4


static func matrix_cell_count() -> int:
	return Elements.SPELL_COUNT


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
		toggle_element_filter(ELEMENT_FILTERS[filter])
		return
	if _select_library_control(position): return
	drag_origin = position
	for index: int in visible_spell_indices():
		if spell_rect(index).has_point(position):
			focus_area = "spells"
			selected_spell_index = index
			drag_spell_index = index
			return
	var slot := slot_at(position)
	if slot >= 0:
		focus_area = "slots"
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
		focus_area = "slots"
		selected_slot_index = target
		selected_spell_index = drag_spell_index
		# Equipped slots remain draggable across element filters. Reveal the
		# exact dropped spell so the library highlight matches the next request.
		if selected_spell_index not in visible_spell_indices():
			selected_element_filter = ""
			selected_element_mask = 0
			selected_family_filter = ""
			basic_forms_only = false
			_reveal_selection()
			status_message = "Selected spell revealed. Review the target slot."
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


func requested_wire_ids(state: PlayerState) -> PackedInt32Array:
	if state == null or starter_preview_active():
		return PackedInt32Array()
	var request := request_value()
	var slot := decode_slot_index(request)
	var wire := wire_id_for_library_index(decode_library_index(request))
	if slot < 0 or slot >= state.spell_wire_ids.size() or wire <= 0:
		return PackedInt32Array()
	var requested := state.spell_wire_ids.duplicate()
	var previous := requested.find(wire)
	if previous >= 0:
		requested[previous] = requested[slot]
	requested[slot] = wire
	return requested


func selected_wire_id(_state: PlayerState = null) -> int:
	return available_wire_ids[selected_spell_index] if selected_spell_index >= 0 and selected_spell_index < available_wire_ids.size() else 0


func configure_for_catalog(catalog: AbilityCatalog) -> void:
	var prior_wire_id := selected_wire_id()
	available_wire_ids = PackedInt32Array()
	element_by_wire.clear()
	mask_by_wire.clear()
	family_by_wire.clear()
	var runtime_wires := CombatTuning.runtime_wire_ids()
	for runtime_index: int in range(runtime_wires.size()):
		var wire_id: int = runtime_wires[runtime_index]
		if catalog == null or not catalog.ability_from_wire(wire_id).is_empty():
			available_wire_ids.append(wire_id)
			var definition := CombatTuning.cast_definition_view(wire_id)
			var ability: Dictionary = catalog.ability_from_wire(wire_id) if catalog != null else {}
			var element := String(ability.get("element", Elements.id_from_wire(int(definition.get("element_wire_id", 0)))))
			element_by_wire[wire_id] = element
			mask_by_wire[wire_id] = int(ability.get("element_mask", definition.get("element_mask", Elements.MASK_BY_WIRE.get(int(definition.get("element_wire_id", 0)), 0))))
			family_by_wire[wire_id] = String(ability.get("family", definition.get("family", "")))
	selected_spell_index = available_wire_ids.find(prior_wire_id)
	if selected_spell_index < 0:
		selected_spell_index = 0
	_coerce_selection_to_filter()


func set_element_filter(element_id: String) -> bool:
	if element_id not in ELEMENT_FILTERS:
		return false
	return set_element_mask(0 if element_id.is_empty() else int(Elements.MASK_BY_WIRE[Elements.BY_ID[element_id]]))


func set_element_mask(mask: int) -> bool:
	if mask < 0 or mask > 63: return false
	selected_element_mask = mask
	selected_element_filter = ""
	for element: String in Elements.IDS:
		if int(Elements.MASK_BY_WIRE[Elements.BY_ID[element]]) == mask: selected_element_filter = element
	focus_area = "spells"
	page_index = 0
	_coerce_selection_to_filter()
	status_message = "Combine element buttons to choose a mixture. Choose a delivery, then assign a slot."
	return true


func toggle_element_filter(element: String) -> bool:
	if element not in ELEMENT_FILTERS: return false
	return set_element_mask(0 if element.is_empty() else selected_element_mask ^ int(Elements.MASK_BY_WIRE[Elements.BY_ID[element]]))


func set_family_filter(family: String) -> bool:
	if family not in FAMILY_FILTERS: return false
	selected_family_filter = family
	if family in ["mantle", "fuse", "split", "rebound"]: basic_forms_only = false
	page_index = 0
	_coerce_selection_to_filter()
	return true


func cycle_family_filter(delta: int) -> void:
	set_family_filter(FAMILY_FILTERS[posmod(FAMILY_FILTERS.find(selected_family_filter) + delta, FAMILY_FILTERS.size())])


static func family_filter_rect(index: int) -> Rect2:
	return Rect2(564 + index * 69, 140, 65, 28) if index >= 0 and index < FAMILY_FILTERS.size() else Rect2()


func _select_library_control(position: Vector2) -> bool:
	if MORE_FORMS_RECT.has_point(position):
		basic_forms_only = not basic_forms_only
		if basic_forms_only and selected_family_filter in ["mantle", "fuse", "split", "rebound"]: selected_family_filter = ""
		page_index = 0
		_coerce_selection_to_filter()
		status_message = "Core forms: Bolt, Heavy, Rapid, Spray. More Forms adds four timing and movement tools." if basic_forms_only else "All eight forms available. Each works with every elemental mixture."
		return true
	for index: int in FAMILY_FILTERS.size():
		if family_filter_rect(index).has_point(position):
			set_family_filter(FAMILY_FILTERS[index])
			return true
	if PAGE_PREVIOUS_RECT.has_point(position):
		change_page(-1)
		return true
	if PAGE_NEXT_RECT.has_point(position):
		change_page(1)
		return true
	return false


func _coerce_selection_to_filter() -> void:
	var visible := filtered_spell_indices()
	if not visible.is_empty() and selected_spell_index not in visible:
		selected_spell_index = visible[0]
	_reveal_selection()


func filtered_spell_indices() -> PackedInt32Array:
	var result := PackedInt32Array()
	for index: int in available_wire_ids.size():
		var wire_id := int(available_wire_ids[index])
		if basic_forms_only and String(family_by_wire.get(wire_id, "")) not in ["bolt", "heavy", "rapid", "spray"]: continue
		if (selected_element_mask == 0 or int(mask_by_wire.get(wire_id, 0)) == selected_element_mask) \
			and (selected_family_filter.is_empty() or String(family_by_wire.get(wire_id, "")) == selected_family_filter):
			result.append(index)
	return result


func visible_spell_indices() -> PackedInt32Array:
	var filtered := filtered_spell_indices()
	var first := clampi(page_index, 0, maxi(0, ceili(float(filtered.size()) / VISIBLE_SPELL_COUNT) - 1)) * VISIBLE_SPELL_COUNT
	return filtered.slice(first, mini(first + VISIBLE_SPELL_COUNT, filtered.size()))


func page_count() -> int:
	return maxi(1, ceili(float(filtered_spell_indices().size()) / VISIBLE_SPELL_COUNT))


func change_page(delta: int) -> void:
	if starter_preview_active(): return
	cancel_drag()
	page_index = clampi(page_index + delta, 0, page_count() - 1)
	var visible := visible_spell_indices()
	if not visible.is_empty(): selected_spell_index = visible[0]
	focus_area = "spells"


func _reveal_selection() -> void:
	var index := filtered_spell_indices().find(selected_spell_index)
	page_index = index / VISIBLE_SPELL_COUNT if index >= 0 else 0


func unavailable_reason(wire: int) -> String:
	return String(blocked_reason_by_wire.get(wire, ""))


func apply_to_state(state: PlayerState) -> bool:
	if starter_preview_active():
		status_message = "Choose Apply or Cancel for the starter preview first."
		return false
	if not unavailable_reason(selected_wire_id()).is_empty():
		status_message = unavailable_reason(selected_wire_id())
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


func prepare_migration_preview(state: PlayerState, ability_catalog: AbilityCatalog, proposal: Dictionary) -> bool:
	cancel_drag()
	starter_preview = {}
	if state == null or ability_catalog == null or not bool(proposal.get("required", false)) or not bool(proposal.get("valid", false)):
		status_message = "Saved-weave update is unavailable. The original save remains unchanged."
		return false
	var original_value: Variant = proposal.get("before_wire_ids", PackedInt32Array())
	var after_value: Variant = proposal.get("after_wire_ids", PackedInt32Array())
	if not original_value is PackedInt32Array or not after_value is PackedInt32Array:
		status_message = "Saved-weave update has invalid slot data. The original save remains unchanged."
		return false
	var original: PackedInt32Array = original_value
	var after: PackedInt32Array = after_value
	if original.size() != PlayerState.SPELL_SLOT_COUNT or after.size() != PlayerState.SPELL_SLOT_COUNT:
		return false
	var rows: Array[Dictionary] = []
	var seen := {}
	for index: int in range(PlayerState.SPELL_SLOT_COUNT):
		var before_ability := ability_catalog.ability_from_wire(original[index])
		var after_ability := ability_catalog.ability_from_wire(after[index])
		var element := String(after_ability.get("element", ""))
		if after_ability.is_empty() or not Elements.is_active_id(element) or seen.has(after[index]) or not CombatTuning.is_runtime_wire_id(after[index]):
			status_message = "Saved-weave update contains an unavailable or duplicate spell. Nothing was sent."
			return false
		seen[after[index]] = true
		rows.append({"slot_index": index, "slot_label": PlayerState.spell_slot_label(index),
			"before_wire_id": original[index], "before_name": String(before_ability.get("display_name", "Saved spell %d" % original[index])),
			"before_element": String(before_ability.get("element", "")), "after_wire_id": after[index],
			"after_name": String(after_ability.get("display_name", "Spell")), "after_element": element,
			"court_tag": starter_court_tag(element), "court_supported": true})
	starter_preview = {"kind": "migration", "migration_id": String(proposal.get("migration_id", "")),
		"champion_id": String(proposal.get("champion_id", "")), "before_wire_ids": state.spell_wire_ids.duplicate(),
		"original_saved_wire_ids": original.duplicate(), "after_wire_ids": after.duplicate(), "rows": rows,
		"notice": String(proposal.get("notice", "Review the six-element replacements. Apply saves; Cancel preserves the original save."))}
	status_message = "Saved-weave preview only. Review replacements before Apply; Cancel preserves the saved original."
	return true


func cancel_starter_preview(show_status: bool = true) -> void:
	starter_preview = {}
	cancel_drag()
	if show_status:
		# Closing a comparison cannot determine whether an earlier timed-out
		# request eventually reached authority. Describe only this local action.
		status_message = "Starter preview closed. No new request was sent."


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
		"action": "apply_character_weave_migration" if String(starter_preview.get("kind", "")) == "migration" else "apply_character_starter_kit",
		"champion_id": String(starter_preview.get("champion_id", "")),
		"migration_id": String(starter_preview.get("migration_id", "")),
		"original_saved_wire_ids": (starter_preview.get("original_saved_wire_ids", PackedInt32Array()) as PackedInt32Array).duplicate(),
		"expected_wire_ids": expected_wire_ids.duplicate(),
		"wire_ids": proposed_wire_ids.duplicate(),
	}


func complete_starter_apply(applied: bool) -> void:
	if applied:
		var migrated := String(starter_preview.get("kind", "")) == "migration"
		starter_preview = {}
		cancel_drag()
		status_message = "Reviewed saved-weave update applied to all twelve slots." if migrated else "Character starter kit applied to all twelve slots."
	else:
		if String(starter_preview.get("notice", "")) == "Apply sent. Waiting for authority; this request can no longer be cancelled.":
			# Only retire an actual in-flight notice. Synchronization can refuse
			# submission before pending tracking starts; its untouched preview must
			# keep the original warning. Timeout itself proves no remote result.
			starter_preview.notice = "Review the result below. Cancel closes this preview without sending another request."
		status_message = "Starter kit was not applied. Review or cancel this preview."


static func starter_court_supported(element_id: String) -> bool:
	return element_id in Elements.IDS


static func starter_court_tag(element_id: String) -> String:
	return "HEX COURT: %s" % AbilityCatalog.element_display_name(element_id).to_upper() if starter_court_supported(element_id) else "HEX EFFECT UNAVAILABLE"


static func decode_slot_index(value: int) -> int:
	return (value - 1) / LIBRARY_CAPACITY if value >= 1 and value <= SessionTransport.MAX_SPELL_EQUIP_VALUE else -1


static func decode_library_index(value: int) -> int:
	return (value - 1) % LIBRARY_CAPACITY if value >= 1 and value <= SessionTransport.MAX_SPELL_EQUIP_VALUE else -1


static func wire_id_for_library_index(library_index: int) -> int:
	var runtime_wire_ids := CombatTuning.runtime_wire_ids()
	return runtime_wire_ids[library_index] if library_index >= 0 and library_index < runtime_wire_ids.size() else 0
