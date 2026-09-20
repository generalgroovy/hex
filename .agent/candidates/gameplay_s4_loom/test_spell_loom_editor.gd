extends FluxTestSuite


const STARTER_ABILITY_PATH := "res://content/abilities/foundation_abilities_v1.json"
const STARTER_CHAMPION_PATH := "res://content/champions/foundation_champions_v1.json"


func run() -> int:
	_test_canonical_slot_weaving()
	_test_three_spell_kit_weaving()
	_test_editor_navigation_and_encoding()
	_test_drag_and_drop()
	_test_catalog_layout_and_details()
	_test_starter_preview_contract()
	return finish("spell-loom-editor")


func _test_starter_preview_contract() -> void:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file(STARTER_ABILITY_PATH), "starter preview ability catalog validates")
	var champions := ChampionCatalog.new()
	check(champions.load_from_file(STARTER_CHAMPION_PATH, abilities), "starter preview champion catalog validates")
	if not abilities.last_error.is_empty() or not champions.last_error.is_empty():
		return
	var state := PlayerState.new()
	check(champions.apply_to_player(state, "oh_tipi"), "starter preview uses an equipped canonical character")
	check(state.place_proven_spell(11, 176), "starter preview begins from an explicit custom weave")
	var before := state.spell_wire_ids.duplicate()
	var editor := SpellLoomEditor.new()
	editor.open_editor(state, abilities)
	check(editor.prepare_starter_preview(state, champions, abilities), "starter button prepares a pure twelve-slot comparison")
	check(editor.starter_preview_active(), "prepared comparison opens the second-stage overlay")
	equal(Array(state.spell_wire_ids), Array(before), "preparing a starter never mutates the current weave")
	var rows: Array = editor.starter_preview.get("rows", [])
	equal(rows.size(), PlayerState.SPELL_SLOT_COUNT, "preview exposes all twelve before-to-after rows")
	for slot_index: int in range(rows.size()):
		var row: Dictionary = rows[slot_index]
		equal(int(row.get("slot_index", -1)), slot_index, "preview row preserves its exact slot index")
		equal(String(row.get("slot_label", "")), PlayerState.spell_slot_label(slot_index), "preview row uses the player-facing slot label")
		check(int(row.get("after_wire_id", 0)) > 0 and not String(row.get("after_name", "")).is_empty(), "preview row resolves its proposed spell")
		var element := String(row.get("after_element", ""))
		equal(bool(row.get("court_supported", false)), element == "water" or element == "fire", "only Water and Fire claim a supported Hex Court material")
		equal(String(row.get("court_tag", "")), SpellLoomEditor.starter_court_tag(element), "each proposed spell carries its honest court tag")
		var card := SpellLoomEditor.starter_preview_slot_rect(slot_index)
		check(SpellLoomEditor.STARTER_PREVIEW_RECT.encloses(card), "every preview card fits inside the 1280 by 720 overlay")
		for earlier: int in range(slot_index):
			check(not card.intersects(SpellLoomEditor.starter_preview_slot_rect(earlier)), "preview cards do not overlap")
	check(not editor.select_at(SpellLoomEditor.slot_rect(0).get_center()), "preview quarantines the underlying slot picker")
	equal(editor.request_value(), 0, "preview quarantines ordinary assign requests")
	check(not editor.apply_to_state(state), "preview cannot bypass root atomic authority")
	equal(Array(state.spell_wire_ids), Array(before), "quarantined assign leaves the weave unchanged")
	var request := editor.request_starter_apply()
	equal(String(request.get("action", "")), "apply_character_starter_kit", "Apply creates the dedicated root action")
	equal(Array(request.get("expected_wire_ids", PackedInt32Array())), Array(before), "root action carries the stale-preview guard")
	var requested_wire_ids: PackedInt32Array = request.get("wire_ids", PackedInt32Array())
	equal(requested_wire_ids.size(), PlayerState.SPELL_SLOT_COUNT, "root action carries exactly twelve proposed wires")
	requested_wire_ids[0] = 0
	var retained_wire_ids: PackedInt32Array = editor.starter_preview.get("after_wire_ids", PackedInt32Array())
	check(retained_wire_ids.size() == PlayerState.SPELL_SLOT_COUNT and retained_wire_ids[0] > 0, "caller mutation cannot alter the retained preview")
	editor.close_editor()
	check(editor.is_open and not editor.starter_preview_active(), "ordinary close cancels the overlay before it can close the Loom")
	equal(Array(state.spell_wire_ids), Array(before), "close quarantine leaves the custom weave unchanged")
	check(editor.prepare_starter_preview(state, champions, abilities), "preview can be prepared again after a quarantined close")
	editor.cancel_starter_preview()
	check(not editor.starter_preview_active(), "Cancel closes the preview")
	equal(Array(state.spell_wire_ids), Array(before), "Cancel leaves the custom weave unchanged")
	equal(SpellLoomEditor.starter_court_tag("water"), "HEX COURT: WATER", "Water is marked as a supported court material")
	equal(SpellLoomEditor.starter_court_tag("fire"), "HEX COURT: FIRE", "Fire is marked as a supported court material")
	equal(SpellLoomEditor.starter_court_tag("ice"), "HEX EFFECT PENDING", "unsupported Hex effects are explicitly flagged")
	check(SpellLoomEditor.PANEL_RECT.encloses(SpellLoomEditor.STARTER_BUTTON_RECT), "starter entry button stays inside the existing modal")
	check(not SpellLoomEditor.STARTER_BUTTON_RECT.intersects(SpellLoomEditor.CLOSE_RECT), "starter entry does not cover Close")
	check(SpellLoomEditor.STARTER_PREVIEW_RECT.encloses(SpellLoomEditor.STARTER_PREVIEW_APPLY_RECT), "Apply stays inside the preview")
	check(SpellLoomEditor.STARTER_PREVIEW_RECT.encloses(SpellLoomEditor.STARTER_PREVIEW_CANCEL_RECT), "Cancel stays inside the preview")


func _test_drag_and_drop() -> void:
	var editor := SpellLoomEditor.new()
	var state := PlayerState.new()
	editor.open_editor(state)
	equal(editor.visible_spell_indices().size(), 32, "complete four-family matrix fits at once")
	for index: int in range(editor.available_wire_ids.size()):
		for slot: int in range(PlayerState.SPELL_SLOT_COUNT):
			var before := Array(state.spell_wire_ids)
			editor.pointer_down(editor.spell_rect(index).get_center(), state)
			editor.pointer_move(SpellLoomEditor.slot_rect(slot).get_center())
			check(editor.dragging, "catalog drag starts after pointer threshold")
			check(editor.pointer_up(SpellLoomEditor.slot_rect(slot).get_center()), "each spell drops into every slot")
			equal(editor.selected_slot_index, slot, "drop selects exact destination")
			equal(editor.selected_wire_id(), editor.available_wire_ids[index], "drop retains source identity")
			equal(Array(state.spell_wire_ids), before, "pointer cannot bypass simulation authority")
			check(editor.apply_to_state(state), "canonical assignment accepts drop")
			equal(state.spell_wire_id(slot + 1), editor.available_wire_ids[index], "destination receives requested spell")
			check(state.has_valid_spell_slots(), "every drop preserves unique valid slots")
	var before := Array(state.spell_wire_ids)
	editor.pointer_down(editor.spell_rect(0).get_center(), state)
	check(not editor.pointer_up(Vector2.ZERO), "outside drop cancels")
	equal(Array(state.spell_wire_ids), before, "outside drop changes nothing")
	editor.pointer_down(editor.spell_rect(0).get_center(), state)
	check(not editor.pointer_up(editor.spell_rect(0).get_center()), "a click only selects")
	editor.pointer_down(SpellLoomEditor.slot_rect(3).get_center(), state)
	var source_wire := state.spell_wire_id(4)
	check(editor.pointer_up(SpellLoomEditor.slot_rect(9).get_center()), "equipped spell can drag between slots")
	equal(editor.selected_wire_id(), source_wire, "slot drag retains equipped identity")
	editor.pointer_down(editor.spell_rect(0).get_center(), state)
	editor.close_editor()
	check(not editor.pointer_up(SpellLoomEditor.slot_rect(0).get_center()), "closing cancels a pending drag")
	equal(SpellLoomEditor.slot_at(Vector2(SpellLoomEditor.GRID_X + SpellLoomEditor.GRID_CELL_WIDTH - 4, SpellLoomEditor.GRID_Y + 10)), -1, "gap is not a drop target")


func _test_canonical_slot_weaving() -> void:
	var state := PlayerState.new()
	check(state.has_valid_spell_slots(), "new player begins with a valid twelve-spell subset of the runtime library")
	equal(Array(state.spell_wire_ids), [101, 140, 181, 182, 141, 159, 183, 184, 160, 145, 179, 180], "champion kit leads a representative twelve-spell weave from the row-major library")
	check(state.set_spell_cooldown(CombatTuning.RILLSHOT_WIRE_ID, 17), "equipped global spell owns an independent cooldown")
	check(state.place_proven_spell(11, CombatTuning.RILLSHOT_WIRE_ID), "global spell can move to Alt+4")
	equal(Array(state.spell_wire_ids), [101, 180, 181, 182, 141, 159, 183, 184, 160, 145, 179, 140], "moving a global spell swaps with the selected position")
	equal(state.spell_cooldown_for_wire(CombatTuning.RILLSHOT_WIRE_ID), 17, "cooldown follows spell identity through a weave")
	check(state.place_proven_spell(11, state.primary_wire_id), "champion spell can swap into an occupied global position")
	equal(Array(state.spell_wire_ids), [140, 180, 181, 182, 141, 159, 183, 184, 160, 145, 179, 101], "occupied weave preserves every equipped spell exactly once")
	equal(state.spell_cooldown_for_wire(CombatTuning.RILLSHOT_WIRE_ID), 17, "swapping does not transfer cooldown to the displaced spell")
	check(not state.place_proven_spell(-1, state.primary_wire_id), "negative slot fails closed")
	check(not state.place_proven_spell(0, 65_000), "unproven spell fails closed")
	check(state.has_valid_spell_slots(), "rejected weaves preserve canonical slot validity")
	var subset := PlayerState.new()
	check(subset.has_valid_spell_slots(), "a unique twelve-position subset remains valid as the global library grows past twelve")
	var displaced_wire := subset.spell_wire_id(4)
	check(subset.place_proven_spell(3, 154), "a proven spell outside the current weave can replace an occupied position")
	equal(subset.spell_wire_id(4), 154, "new global selection occupies the requested position")
	check(subset.spell_slot_index_for_wire(displaced_wire) < 0, "replaced spell leaves the selected twelve-position subset")


func _test_editor_navigation_and_encoding() -> void:
	var state := PlayerState.new()
	var editor := SpellLoomEditor.new()
	editor.open_editor()
	check(editor.is_open, "Spell Loom opens explicitly")
	editor.move_selection(-1, -1)
	equal(editor.selected_slot_index, 11, "weave-position navigation wraps")
	equal(editor.selected_spell_index, CombatTuning.runtime_wire_ids().size() - 1, "global spell navigation wraps")
	equal(editor.selected_wire_id(), 176, "wrapped selection resolves through stable runtime order")
	equal(editor.request_value(), 736, "Alt+4 final matrix spell has a bounded request encoding")
	equal(SpellLoomEditor.decode_slot_index(736), 11, "request decodes position deterministically")
	equal(SpellLoomEditor.decode_library_index(736), 31, "request decodes the final global library index deterministically")
	equal(SpellLoomEditor.wire_id_for_library_index(31), 176, "final cell resolves the canonical matrix wire")
	equal(SpellLoomEditor.wire_id_for_library_index(32), 0, "unoccupied library capacity is not a playable spell")
	equal(SpellLoomEditor.decode_slot_index(769), -1, "request above twelve by sixty-four fails closed")
	equal(SpellLoomEditor.decode_slot_index(0), -1, "invalid request value fails closed")
	check(editor.apply_to_state(state), "offline editor applies through canonical state method")
	equal(state.spell_wire_id(12), 176, "selected global spell occupies Alt+4")
	check(editor.select_at(Vector2(SpellLoomEditor.GRID_X + SpellLoomEditor.GRID_CELL_WIDTH * 2 + 4, SpellLoomEditor.GRID_Y + SpellLoomEditor.GRID_CELL_HEIGHT + 4)), "mouse selects a visible weave cell")
	equal(editor.selected_slot_index, 6, "mouse grid selection resolves Ctrl+3")
	editor.close_editor()
	check(not editor.is_open, "Spell Loom closes explicitly")


func _test_three_spell_kit_weaving() -> void:
	var state := PlayerState.new()
	state.primary_wire_id = CombatTuning.RILLSHOT_WIRE_ID
	state.active_1_wire_id = CombatTuning.TIDELINE_WIRE_ID
	state.active_2_wire_id = 167 # Spark Shower, the live Charge Spray.
	state.reset_spell_slots_to_kit()
	equal(Array(state.spell_wire_ids), [140, 141, 167, 181, 182, 159, 183, 184, 160, 145, 179, 180], "three champion spells lead a representative row-major twelve-spell weave")
	check(state.has_valid_spell_slots(), "twelve-position weave validates canonically")
	check(state.place_proven_spell(11, state.active_2_wire_id), "third champion spell can move to Alt+4")
	equal(Array(state.spell_wire_ids), [140, 141, 180, 181, 182, 159, 183, 184, 160, 145, 179, 167], "third spell weaving preserves every equipped spell exactly once")
	var editor := SpellLoomEditor.new()
	editor.open_editor(state)
	equal(editor.available_wire_ids.size(), 32, "Oh Tipi can weave every runtime spell")
	editor.move_selection(-1, -1)
	equal(editor.selected_wire_id(), 176, "global navigation is independent of champion kit")
	equal(editor.request_value(), 736, "global weave uses the bounded catalog lane")
	equal(SpellLoomEditor.decode_slot_index(736), 11, "global request value decodes Alt+4")
	equal(SpellLoomEditor.decode_library_index(736), 31, "global request value decodes the final runtime spell")


func _test_catalog_layout_and_details() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "four-family catalog loads for Loom layout")
	var editor := SpellLoomEditor.new()
	editor.open_editor(null, catalog)
	equal(SpellLoomEditor.matrix_columns(), 4, "column count derives from catalog family order")
	equal(SpellLoomEditor.matrix_cell_count(), 32, "matrix size derives from catalog elements and families")
	equal(SpellLoomEditor.VISIBLE_SPELL_COUNT, 32, "visible capacity matches the complete runtime library")
	equal(editor.spell_rect(31).position, Vector2(1032, 455), "final spray occupies the fourth column of the eighth row")
	for index: int in editor.visible_spell_indices():
		var rect := editor.spell_rect(index)
		check(SpellLoomEditor.PANEL_RECT.encloses(rect), "every spell target fits inside the 720p panel")
		check(rect.end.y < SpellLoomEditor.DETAIL_DIVIDER_Y, "all four-family spells clear the detail footer")
		check(not rect.intersects(SpellLoomEditor.CLOSE_RECT) and not rect.intersects(SpellLoomEditor.ASSIGN_RECT), "spell targets never overlap action buttons")
		check(editor.select_at(rect.get_center()), "each displayed cell is selectable at its exact painted center")
		equal(editor.selected_spell_index, index, "each painted center resolves only its own spell")
		var ability := catalog.ability_from_wire(editor.available_wire_ids[index])
		equal(String(ability.element), AbilityCatalog.FIRST_EIGHT_ELEMENTS[index / SpellLoomEditor.matrix_columns()], "cell element agrees with row heading")
		equal(AbilityCatalog._spell_family(ability), AbilityCatalog.SPELL_MATRIX_FAMILIES[index % SpellLoomEditor.matrix_columns()], "cell delivery agrees with family heading")
		for other: int in range(index):
			check(not rect.intersects(editor.spell_rect(other)), "spell hit targets cannot overlap")
		for slot: int in range(PlayerState.SPELL_SLOT_COUNT):
			check(not rect.intersects(SpellLoomEditor.slot_rect(slot)), "picker and twelve-slot weave stay separate")
		var name := String(ability.display_name)
		for layout: Vector2 in [Vector2(rect.size.x - 11, 11), Vector2(SpellLoomEditor.slot_rect(0).size.x - 18, 13)]:
			var lines := SpellLoomPresenter.name_lines(name, layout.x, int(layout.y))
			check(lines.size() <= 2, "names use at most two lines without smaller fonts")
			equal(" ".join(lines), name, "every current spell name is retained, not silently abbreviated")
			for line: String in lines:
				check(ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, int(layout.y)).x <= layout.x, "wrapped name fits within its target")
		var detail := SpellLoomPresenter.family_detail(ability)
		check(detail.contains("Reaction strength %d" % int(ability.reaction_strength)), "Loom detail reads each validated ability's authored reaction strength")
		check(ThemeDB.fallback_font.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x <= 930, "family behavior detail fits without smaller text")
	for slot: int in range(PlayerState.SPELL_SLOT_COUNT):
		var rect := SpellLoomEditor.slot_rect(slot)
		equal(rect.position, Vector2(48 + slot % 4 * 110, 154 + slot / 4 * 86), "four-by-three slot arrangement is preserved")
		check(rect.end.x < SpellLoomEditor.MATRIX_LABEL_X, "slot names and element row labels have separate space")
		for other: int in range(slot):
			check(not rect.intersects(SpellLoomEditor.slot_rect(other)), "weave hit targets cannot overlap")
	equal(editor.spell_rect(-1), Rect2(), "negative cell has no hit area")
	equal(editor.spell_rect(32), Rect2(), "unoccupied library position has no hit area")
	equal(SpellLoomPresenter.family_label("spray"), "Spray", "runtime family label uses the four-family name")
	equal(AbilityCatalog.element_display_name("wind"), "Air", "Loom row labels translate the wind element for players")
	var heavy := catalog.ability_from_wire(179).duplicate(true)
	equal(SpellLoomPresenter.family_detail(heavy), "Heavy: 18 Flux / 84px splash radius. Reaction strength 15. Slow shell; blast at impact or endpoint.", "Heavy detail teaches real cost, splash radius and authored reaction strength")
	heavy["blast_radius"] = 42000
	heavy["flux_cost"] = 21
	heavy["reaction_strength"] = 7
	equal(SpellLoomPresenter.family_detail(heavy), "Heavy: 21 Flux / 42px splash radius. Reaction strength 15. Slow shell; blast at impact or endpoint.", "Heavy teaching reads editable layout values while reaction strength remains the validated compiled definition")
	var rapid := catalog.ability_from_wire(180).duplicate(true)
	check(SpellLoomPresenter.family_detail(rapid).contains("hold the spell key / 2 Flux per shot") and SpellLoomPresenter.family_detail(rapid).contains("Reaction strength 1; always trail-free"), "Rapid detail teaches held-key firing, source strength and explicit trail exclusion")
	rapid["repeat_while_held"] = false
	rapid["flux_cost"] = 4
	check(SpellLoomPresenter.family_detail(rapid).contains("press the spell key / 4 Flux per shot"), "Rapid teaching follows catalog repeat and cost settings")
	var spray := catalog.ability_from_wire(141).duplicate(true)
	check(SpellLoomPresenter.family_detail(spray).contains("Spray: 280px range / 16 Flux") and SpellLoomPresenter.family_detail(spray).contains("Reaction strength 3; no chemistry matter"), "Spray teaching reads the live range, cost and noningredient strength")
	var retired_wire := 110
	check(retired_wire not in editor.available_wire_ids, "catalog-only Vector Lance is absent from the runtime picker")
	equal(SpellLoomPresenter.family_detail(catalog.ability_from_wire(retired_wire)), "This authored catalog entry is disabled for runtime selection.", "retired catalog entry has an honest non-runtime descriptor")
	editor.available_wire_ids.append(retired_wire)
	editor.selected_spell_index = editor.available_wire_ids.size() - 1
	equal(editor.request_value(), 0, "catalog-only authored spell cannot encode a runtime request")
	var state := PlayerState.new()
	check(not editor.apply_to_state(state), "catalog-only authored spell is rejected by state authority")
