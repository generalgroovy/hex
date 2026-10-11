extends FluxTestSuite


const STARTER_ABILITY_PATH := "res://content/abilities/foundation_abilities_v1.json"
const STARTER_CHAMPION_PATH := "res://content/champions/foundation_champions_v1.json"
const Mixtures = preload("res://src/content/mixture_catalog.gd")


func _all_forms(editor: SpellLoomEditor) -> void:
	editor.basic_forms_only = false
	editor.set_family_filter("")
	editor.set_element_mask(0)


func _reveal(editor: SpellLoomEditor, index: int) -> void:
	var wire := int(editor.available_wire_ids[index])
	editor.basic_forms_only = false
	editor.set_element_mask(Mixtures.mask_for_wire(wire))
	editor.set_family_filter(Mixtures.family_for_wire(wire))
	editor.selected_spell_index = index
	editor._reveal_selection()


func run() -> int:
	_test_canonical_slot_weaving()
	_test_three_spell_kit_weaving()
	_test_editor_navigation_and_encoding()
	_test_drag_and_drop()
	_test_filtered_slot_drag_visibility()
	_test_catalog_layout_and_details()
	_test_header_text_clearance()
	_test_key_first_loadout()
	_test_element_filter_contract()
	_test_starter_preview_contract()
	_test_spatial_navigation_and_preview()
	_test_metric_guidance_and_control_details()
	_test_wheel_navigation()
	_test_feedback_projection()
	_test_migration_preview_contract()
	_test_all_masks_pages_and_locks()
	return finish("spell-loom-editor")


func _test_feedback_projection() -> void:
	var editor := SpellLoomEditor.new()
	var no_op := {"enabled": false, "reason": "Already in this slot. Choose another spell or target slot."}
	var outcomes: Array[String] = [
		"Twelve spell positions applied.",
		"Weave works for this session; saved file could not be updated.",
		"Confirmation timed out. Check the current weave before retrying; no local save was made.",
		"Request could not be sent. Your current weave is unchanged.",
		"That request is unavailable. Your previous weave remains usable; wait for active actions and cooldowns before replacing a spell.",
	]
	for outcome: String in outcomes:
		editor.status_message = outcome
		for starter: bool in [false, true]:
			var lines := SpellLoomPresenter.feedback_lines(editor, no_op, starter)
			equal(lines.size(), 2, "outcome and disabled-action guidance remain separate")
			equal(lines[0].text, outcome, "renderer projection keeps the exact transaction outcome even when assignment is disabled")
			equal(lines[1].text, no_op.reason, "renderer projection also explains why the next assignment is unavailable")
			for line: Dictionary in lines:
				var font_size: int = line.font_size
				var extent := ThemeDB.fallback_font.get_string_size(line.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
				check(extent.x <= float(line.width), "complete outcome and guidance fit without elision")
				var bounds := Rect2(line.position - Vector2(0, ThemeDB.fallback_font.get_ascent(font_size)), Vector2(line.width, ThemeDB.fallback_font.get_height(font_size)))
				check((SpellLoomEditor.STARTER_PREVIEW_RECT if starter else SpellLoomEditor.PANEL_RECT).encloses(bounds), "feedback remains inside its actual panel")
				check(not bounds.intersects(SpellLoomEditor.STARTER_PREVIEW_APPLY_RECT if starter else SpellLoomEditor.ASSIGN_RECT), "feedback does not overlap the existing apply button")
				check(bounds.position.y > (572.0 if starter else 620.0), "feedback clears starter cards or ordinary spell detail")
				check(bounds.end.y < (614.0 if starter else 670.0), "feedback clears starter buttons or ordinary navigation")
			equal(editor.status_message, outcome, "presentation leaves the retained outcome unchanged")
		var enabled := SpellLoomPresenter.feedback_lines(editor, {"enabled": true})
		equal(enabled.size(), 1, "enabled assignment retains outcome without inventing an advisory")
		equal(enabled[0].text, outcome, "enabled projection preserves the exact outcome")
	editor.status_message = String(no_op.reason)
	equal(SpellLoomPresenter.feedback_lines(editor, no_op).size(), 1, "identical outcome and advisory are not duplicated")
	editor.status_message = ""
	check(SpellLoomPresenter.feedback_lines(editor, {"enabled": true}).is_empty(), "empty feedback does not invent a transaction result")
	for outcome: String in outcomes.slice(2):
		editor.starter_preview = {"notice": "Apply sent. Waiting for authority; this request can no longer be cancelled.", "before_wire_ids": PackedInt32Array([1, 2]), "after_wire_ids": PackedInt32Array([2, 1])}
		var before: PackedInt32Array = editor.starter_preview.before_wire_ids.duplicate()
		var after: PackedInt32Array = editor.starter_preview.after_wire_ids.duplicate()
		editor.complete_starter_apply(false)
		editor.status_message = outcome # Same exact outcome ownership as bootstrap.
		check(editor.starter_preview_active(), "failed apply retains the read-only comparison")
		check(not String(editor.starter_preview.notice).contains("Waiting") and not String(editor.starter_preview.notice).contains("no longer be cancelled"), "completed failure cannot retain a pending or noncancellable notice")
		equal(SpellLoomPresenter.feedback_lines(editor, {"enabled": true}, true)[0].text, outcome, "starter renderer exposes refusal, send failure and timeout outcomes")
		equal(editor.starter_preview.before_wire_ids, before, "feedback recovery does not change the expected weave")
		equal(editor.starter_preview.after_wire_ids, after, "feedback recovery does not change the proposed weave")
		editor.cancel_starter_preview()
		equal(editor.status_message, "Starter preview closed. No new request was sent.", "closing an unconfirmed comparison makes no claim about earlier authority")
		check(not editor.starter_preview_active(), "neutral close still discards the local comparison")


func _test_key_first_loadout() -> void:
	var preferences := PlayerPreferences.new()
	# This fixture deliberately tests a truly unbound button, not keyboard-only
	# unbinding while the default controller assignment remains usable.
	preferences.controller_bindings[&"spell_1"] = PlayerPreferences.unbound_controller_binding()
	for key: int in [KEY_1, KEY_T, KEY_KP_ENTER, KEY_MEDIAPLAY, 0]:
		preferences.keyboard_bindings[&"spell_1"] = key
		preferences.keyboard_bindings[&"spell_layer_ctrl"] = KEY_SHIFT
		for slot: int in 12:
			var cap := SpellLoomPresenter.slot_keycap(slot, preferences)
			var full := SpellLoomPresenter.slot_binding_label(slot, preferences)
			check(ThemeDB.fallback_font.get_string_size(cap.label, HORIZONTAL_ALIGNMENT_LEFT, -1, cap.font_size).x <= SpellLoomEditor.slot_rect(slot).size.x - 18, "saved keycaps fit without crossing cards")
			check(String(cap.label) == full or (String(cap.label).ends_with("...") and full.begins_with(String(cap.label).trim_suffix("..."))), "elided keycaps remain truthful prefixes, never default bindings")
			check(int(cap.font_size) >= 10 and int(cap.font_size) <= 16, "keycap never shrinks below existing small-text size")
			if key == 0 and slot % 4 == 0: equal(cap.label, "Not bound", "unbound chords remain explicit on the card")
	preferences.keyboard_bindings[&"spell_1"] = KEY_T
	equal(SpellLoomPresenter.slot_keycap(0, preferences).label, "T", "primary card reflects remapped key")
	equal(SpellLoomPresenter.slot_keycap(4, preferences).label, "Shift+T", "modifier card reflects remapped layer and key")
	equal(SpellLoomPresenter.slot_binding_label(0, null), "Binding unavailable", "unknown settings remain explicit in full label")
	var unavailable := SpellLoomPresenter.slot_keycap(0, null)
	check(String(unavailable.label).begins_with("Binding"), "unknown settings never invent an assigned keycap")
	for family: String in AbilityCatalog.SPELL_MATRIX_FAMILIES:
		var heading := SpellLoomPresenter.family_heading(family)
		check(heading.begins_with(family.to_upper() + " / "), "delivery role supplements rather than replaces delivery name")
		check(ThemeDB.fallback_font.get_string_size(heading, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x <= SpellLoomEditor.SPELL_PICKER_WIDTH - 10, "delivery role fits column header")


func _test_spatial_navigation_and_preview() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(STARTER_ABILITY_PATH), "UX metrics use real definitions")
	var editor := SpellLoomEditor.new()
	var state := PlayerState.new()
	editor.open_editor(state, catalog)
	editor.set_element_mask(0)
	editor.selected_spell_index = 0
	editor.navigate_grid(0, 1)
	equal(editor.selected_spell_index, 4, "down preserves family and selects the next element row")
	editor.selected_spell_index = 3
	editor.navigate_grid(1, 0)
	equal(editor.selected_spell_index, 3, "right edge never wraps diagonally")
	editor.cycle_focus()
	equal(editor.focus_area, "slots", "Tab toggles explicit pane focus")
	editor.selected_slot_index = 0
	editor.navigate_grid(0, 1)
	equal(editor.selected_slot_index, 4, "slot down follows the visible modifier row")
	editor.set_element_filter("water")
	equal(editor.selected_element_filter, "water", "filter is keyboard/controller reachable")
	equal(editor.focus_area, "spells", "filter selects its own pane")
	editor.cycle_focus()
	editor.select_at(SpellLoomEditor.element_filter_rect(1).get_center())
	equal(editor.focus_area, "spells", "mouse filter returns spatial input to its visible spell row")
	editor.set_element_filter("water")
	editor.selected_spell_index = 2
	editor.navigate_grid(0, 1)
	equal(editor.selected_spell_index, 2, "single filter row cannot jump into invisible spells")
	for unused: int in range(64): editor.cycle_element_filter(1)
	equal(editor.selected_element_filter, "water", "all64 masks including All are reachable in a bounded cycle")
	editor.set_element_mask(0)
	state.spell_wire_ids = PackedInt32Array(editor.available_wire_ids.slice(0, 12))
	var before := state.spell_wire_ids.duplicate()
	editor.selected_slot_index = 0
	editor.selected_spell_index = 0
	equal(editor.assignment_preview(state).kind, "unchanged", "same-slot preview explicitly predicts no change")
	editor.selected_spell_index = 1
	equal(editor.assignment_preview(state).kind, "swap", "equipped spell previews both-slot swap")
	equal(editor.assignment_preview(state).other_slot, 1, "swap identifies exact source slot")
	editor.selected_spell_index = editor.available_wire_ids.size() - 1
	equal(editor.assignment_preview(state).kind, "replace", "new spell previews replacement only")
	equal(state.spell_wire_ids, before, "all navigation and preview are read-only")
	for index: int in editor.available_wire_ids.size():
		var ability := catalog.ability_from_wire(editor.available_wire_ids[index])
		var definition := CombatTuning.cast_definition(int(ability.wire_id))
		var metrics := SpellLoomPresenter.spell_metrics(ability)
		equal(metrics.size(), 6, "each live spell has six comparable truthful metrics")
		var config := SimConfig.new()
		var cycle := config.milliseconds_to_ticks(int(definition.startup_ms)) + config.milliseconds_to_ticks(int(definition.cooldown_ms))
		var speed := int(definition.get("speed", 0))
		var family := String(definition.get("family", ""))
		var reach := float(definition.get("range", 0)) / 1000.0
		if reach <= 0.0: reach = float(speed) * float(definition.lifetime_ms) / 1000000.0
		var expected: Array[Dictionary] = [
			{"label": "FLUX / CAST", "value": str(int(definition.flux_cost) / 1000)},
			{"label": "STRENGTH", "value": str(int(definition.reaction_strength))},
			{"label": "SPEED", "value": "Follows caster" if String(definition.get("family", "")) == "mantle" else String.num(float(speed) / 1000.0, 1) + " px/s" if speed > 0 else "Instant fan"},
			{"label": "FIRE EVERY", "value": "%.2f s min" % (float(cycle) / config.tick_rate)},
			{"label": "SHARED POOL" if family in ["mantle", "fuse", "split"] else "DIRECT HIT", "value": String.num(float(definition.damage) / 1000.0, 2) + " HP"},
			{"label": "DURATION" if family == "mantle" else "NOM. REACH", "value": "%.2f s" % (float(definition.lifetime_ms) / 1000.0) if family == "mantle" else "%.0f px" % reach},
		]
		equal(metrics, expected, "all six metrics and their qualified labels match the exact compiled wire %d" % int(ability.wire_id))
		var edited_layout := ability.duplicate(true)
		for field: String in ["flux_cost", "reaction_strength", "speed", "startup_ms", "cooldown_ms", "damage", "range", "lifetime_ms"]:
			edited_layout[field] = 1
		equal(SpellLoomPresenter.spell_metrics(edited_layout), metrics, "uncompiled layout edits cannot invent different runtime metrics")
		for metric: Dictionary in metrics:
			check(ThemeDB.fallback_font.get_string_size(String(metric.label), HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x <= 94, "metric label fits its existing native card column")
			check(ThemeDB.fallback_font.get_string_size(String(metric.value), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x <= 108, "metric value fits its native card column")


func _test_metric_guidance_and_control_details() -> void:
	var font := ThemeDB.fallback_font
	var size := SpellLoomPresenter.METRICS_HINT_FONT_SIZE
	var hint := SpellLoomPresenter.METRICS_HINT
	check(hint.contains("Nominal reach") and hint.contains("cursor/cover can shorten it"), "nominal travel distance never promises exact cursor or covered reach")
	check(hint.contains("Burst, then rest") and hint.contains("faster Flux recovery"), "one short hint teaches the depleted-hold recovery tradeoff")
	var extent := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	check(extent.x <= SpellLoomPresenter.METRICS_HINT_WIDTH, "complete reach and Flux hint fits without shrinking or elision")
	var bounds := Rect2(SpellLoomPresenter.METRICS_HINT_POSITION - Vector2(0, font.get_ascent(size)), Vector2(extent.x, font.get_height(size)))
	check(SpellLoomEditor.PANEL_RECT.encloses(bounds), "helper line stays inside the unchanged Loom panel")
	check(bounds.position.y > 539.0 - font.get_ascent(12) + font.get_height(12), "helper line clears the second metric row")
	check(bounds.end.y < SpellLoomEditor.DETAIL_DIVIDER_Y, "helper line clears the existing detail divider")
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(STARTER_ABILITY_PATH), "control guidance uses the complete validated runtime catalog")
	var launch_count := 0
	for wire: int in catalog.runtime_wire_ids:
		var ability := catalog.ability_from_wire(wire)
		if AbilityCatalog._spell_family(ability) != "spray": continue
		var definition := CombatTuning.cast_definition(wire)
		var detail := SpellLoomPresenter.family_detail(ability)
		var launches := int(definition.hit_control_state) == PlayerState.ControlState.LAUNCHED and int(definition.hit_control_duration_ms) > 0 and int(definition.hit_control_speed) > 0
		equal(detail.contains("Launch on hit:"), launches, "Spray only advertises launch when the compiled spell actually applies it")
		if launches:
			launch_count += 1
			equal(wire, CombatTuning.TIDELINE_WIRE_ID, "Water Spray owns the current unique launch advantage")
			check(detail.contains("Launch on hit: %dms at %spx/s." % [int(definition.hit_control_duration_ms), String.num(float(definition.hit_control_speed) / 1000.0, 1)]), "launch duration and speed come from its compiled effect")
		var edited_layout := ability.duplicate(true)
		edited_layout.hit_control_state = PlayerState.ControlState.FREE if launches else PlayerState.ControlState.LAUNCHED
		edited_layout.hit_control_duration_ms = 0 if launches else 999
		edited_layout.hit_control_speed = 0 if launches else 999000
		equal(SpellLoomPresenter.family_detail(edited_layout), detail, "uncompiled control edits cannot hide Water launch or invent it for another Spray")
		check(font.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x <= 930, "variant behavior fits the existing full-size detail row")
	equal(launch_count, 1, "only one of six current Sprays claims launch")
	# Live Bolts intentionally share a whole-number speed. Exercise fractional
	# formatting through a separate validated/compiled catalog, not stale balance.
	var fractional_catalog := AbilityCatalog.new()
	fractional_catalog.data = catalog.data.duplicate(true)
	for ability: Dictionary in fractional_catalog.data.abilities:
		if String(ability.get("id", "")) == "rillshot":
			ability.speed = 345600
	var valid := fractional_catalog.validate()
	check(valid, "fractional display fixture remains valid authored fixed-point data: " + fractional_catalog.last_error)
	if not valid: return
	var fractional_table := CombatDefinitionTable.new()
	var compiled := fractional_table.compile(fractional_catalog)
	check(compiled, "fractional display fixture compiles through the production definition table: " + fractional_table.last_error)
	if not compiled: return
	var original_table := CombatDefinitionTable.default_table()
	var original_definition := original_table.definition(CombatTuning.RILLSHOT_WIRE_ID)
	CombatDefinitionTable._default_instance = fractional_table
	var fractional_metrics := SpellLoomPresenter.spell_metrics(fractional_catalog.ability_from_wire(CombatTuning.RILLSHOT_WIRE_ID))
	CombatDefinitionTable._default_instance = original_table
	equal(fractional_metrics[2].value, "345.6 px/s", "fractional projectile speed is not silently truncated to an integer")
	equal(CombatTuning.cast_definition(CombatTuning.RILLSHOT_WIRE_ID), original_definition, "precision fixture restores the original live compiled definition")


func _test_wheel_navigation() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(STARTER_ABILITY_PATH), "wheel navigation uses the real spell library")
	if not catalog.last_error.is_empty():
		return
	var state := PlayerState.new()
	var before := state.canonical_values()
	var editor := SpellLoomEditor.new()
	editor.open_editor(state, catalog)
	_all_forms(editor)
	editor.selected_slot_index = 7
	editor.selected_spell_index = 4
	editor.focus_area = "slots"
	editor.navigate_wheel(1, editor.spell_rect(4).get_center())
	equal(editor.focus_area, "spells", "wheel over library takes focus from slots")
	equal(editor.selected_spell_index, 5, "library wheel advances the selected spell")
	equal(editor.selected_slot_index, 7, "library wheel preserves the exact destination slot")
	equal(SpellLoomEditor.decode_slot_index(editor.request_value()), 7, "library wheel keeps canonical assignment destination")
	equal(SpellLoomEditor.wire_id_for_library_index(SpellLoomEditor.decode_library_index(editor.request_value())), editor.selected_wire_id(), "library wheel retains canonical spell wire mapping")
	editor.navigate_wheel(-1, SpellLoomEditor.slot_rect(7).get_center())
	equal(editor.focus_area, "slots", "wheel over slots takes focus from library")
	equal(editor.selected_slot_index, 6, "slot wheel changes only the destination")
	equal(editor.selected_spell_index, 5, "slot wheel preserves selected library spell")
	var outside := Vector2(30, 30)
	editor.navigate_wheel(1, outside)
	equal(editor.selected_slot_index, 7, "wheel outside both grids follows slot focus")
	editor.cycle_focus()
	editor.navigate_wheel(-1, outside)
	equal(editor.selected_spell_index, 4, "wheel outside both grids follows library focus")
	equal(editor.selected_slot_index, 7, "focused library wheel also preserves destination")
	editor.focus_area = "slots"
	editor.navigate_wheel(1, editor.spell_rect(0).end - Vector2(0, 10) + Vector2(2, 0))
	equal(editor.focus_area, "spells", "internal library gutter still belongs to library")
	editor.navigate_wheel(1, SpellLoomEditor.slot_rect(0).end - Vector2(0, 10) + Vector2(2, 0))
	equal(editor.focus_area, "slots", "internal slot gutter still belongs to slots")
	for boundary: int in [0, PlayerState.SPELL_SLOT_COUNT - 1]:
		editor.selected_slot_index = boundary
		editor.navigate_wheel(-1 if boundary == 0 else 1, SpellLoomEditor.slot_rect(boundary).get_center())
		equal(editor.selected_slot_index, boundary, "slot wheel clamps at each end without wrapping")
	var destination := editor.selected_slot_index
	for boundary: int in [0, editor.available_wire_ids.size() - 1]:
		editor.selected_spell_index = boundary
		editor._reveal_selection()
		editor.navigate_wheel(-1 if boundary == 0 else 1, editor.spell_rect(boundary).get_center())
		equal(editor.selected_spell_index, boundary, "library wheel clamps at each end without wrapping")
		equal(editor.selected_slot_index, destination, "library boundary never moves the destination")
	check(editor.set_element_filter("fire"), "wheel filter selects a non-first canonical element")
	var filtered := editor.visible_spell_indices()
	editor.selected_spell_index = filtered[0]
	editor.navigate_wheel(1, editor.spell_rect(filtered[0]).get_center())
	equal(editor.selected_spell_index, filtered[1], "filtered wheel advances within visible canonical indices")
	for boundary: int in [0, filtered.size() - 1]:
		editor.selected_spell_index = filtered[boundary]
		editor.navigate_wheel(-1 if boundary == 0 else 1, editor.spell_rect(filtered[boundary]).get_center())
		equal(editor.selected_spell_index, filtered[boundary], "filtered wheel cannot leave its visible row")
	equal(editor.selected_slot_index, destination, "filtered wheel leaves destination untouched")
	editor.pointer_down(editor.spell_rect(filtered[0]).get_center(), state)
	editor.pointer_move(SpellLoomEditor.slot_rect(0).get_center())
	check(editor.dragging, "wheel cancellation fixture has an active drag")
	editor.navigate_wheel(1, editor.spell_rect(filtered[0]).get_center())
	check(not editor.dragging and editor.drag_spell_index == -1, "wheel cancels drag without submitting an assignment")
	var selected_spell := editor.selected_spell_index
	editor.starter_preview = {"active": true}
	editor.navigate_wheel(1, SpellLoomEditor.slot_rect(0).get_center())
	equal(editor.selected_slot_index, destination, "starter preview quarantines wheel destination changes")
	equal(editor.selected_spell_index, selected_spell, "starter preview quarantines wheel library changes")
	editor.starter_preview.clear()
	editor.available_wire_ids = PackedInt32Array()
	editor.navigate_wheel(1, outside)
	equal(editor.selected_slot_index, destination, "empty focused library never redirects wheel to slots")
	equal(editor.selected_spell_index, selected_spell, "empty library wheel is a safe no-op")
	equal(state.canonical_values(), before, "all wheel navigation leaves equipped spells and authority untouched")


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
	var unsent_preview := editor.starter_preview.duplicate(true)
	editor.complete_starter_apply(false)
	equal(editor.starter_preview, unsent_preview, "refusal before submission preserves the complete unsent preview and its original notice")
	equal(String(editor.starter_preview.notice), "Applying replaces your custom weave. Cancel keeps every slot. Apply is the only save step.", "unsent preview retains the authored replacement and cancellation warning")
	editor.status_message = "Synchronizing the world. Your weave is unchanged."
	var sync_feedback := SpellLoomPresenter.feedback_lines(editor, {"enabled": false, "reason": "Synchronizing the world. Your weave is unchanged."}, true)
	check(sync_feedback.size() == 1 and String(sync_feedback[0].text).begins_with("Synchronizing"), "unsent preview still shows current synchronization feedback without replacing its notice")
	equal(Array(state.spell_wire_ids), Array(before), "preparing a starter never mutates the current weave")
	var rows: Array = editor.starter_preview.get("rows", [])
	equal(rows.size(), PlayerState.SPELL_SLOT_COUNT, "preview exposes all twelve before-to-after rows")
	for slot_index: int in range(rows.size()):
		var row: Dictionary = rows[slot_index]
		equal(int(row.get("slot_index", -1)), slot_index, "preview row preserves its exact slot index")
		equal(String(row.get("slot_label", "")), PlayerState.spell_slot_label(slot_index), "preview row uses the player-facing slot label")
		check(int(row.get("after_wire_id", 0)) > 0 and not String(row.get("after_name", "")).is_empty(), "preview row resolves its proposed spell")
		var element := String(row.get("after_element", ""))
		equal(bool(row.get("court_supported", false)), element in SpellLoomEditor.Elements.IDS, "every enabled canonical spell is identified as Hex Court ingredient material")
		equal(String(row.get("court_tag", "")), SpellLoomEditor.starter_court_tag(element), "each proposed spell carries its honest court tag")
		var card := SpellLoomEditor.starter_preview_slot_rect(slot_index)
		check(SpellLoomEditor.STARTER_PREVIEW_RECT.encloses(card), "every preview card fits inside the 1280 by 720 overlay")
		for earlier: int in range(slot_index):
			check(not card.intersects(SpellLoomEditor.starter_preview_slot_rect(earlier)), "preview cards do not overlap")
	check(not editor.select_at(SpellLoomEditor.slot_rect(0).get_center()), "preview quarantines the underlying slot picker")
	equal(editor.request_value(), 0, "preview quarantines ordinary assign requests")
	check(editor.requested_wire_ids(state).is_empty(), "preview cannot build an ordinary assignment beside its atomic apply request")
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
	equal(SpellLoomEditor.starter_court_tag("ice"), "HEX EFFECT UNAVAILABLE", "Ice is an effect style, never an independent live ingredient")
	equal(SpellLoomEditor.starter_court_tag("wind"), "HEX COURT: AIR", "internal wind is consistently presented as Air")
	equal(SpellLoomEditor.starter_court_tag("spirit"), "HEX EFFECT UNAVAILABLE", "deferred elements remain unavailable")
	check(SpellLoomEditor.PANEL_RECT.encloses(SpellLoomEditor.STARTER_BUTTON_RECT), "starter entry button stays inside the existing modal")
	check(not SpellLoomEditor.STARTER_BUTTON_RECT.intersects(SpellLoomEditor.CLOSE_RECT), "starter entry does not cover Close")
	check(SpellLoomEditor.STARTER_PREVIEW_RECT.encloses(SpellLoomEditor.STARTER_PREVIEW_APPLY_RECT), "Apply stays inside the preview")
	check(SpellLoomEditor.STARTER_PREVIEW_RECT.encloses(SpellLoomEditor.STARTER_PREVIEW_CANCEL_RECT), "Cancel stays inside the preview")


func _test_drag_and_drop() -> void:
	var editor := SpellLoomEditor.new()
	var state := PlayerState.new()
	editor.open_editor(state)
	equal(editor.visible_spell_indices().size(), 4, "first opening shows selected slot's element and core forms")
	for index: int in range(editor.available_wire_ids.size()):
		_reveal(editor, index)
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
	_reveal(editor, 0)
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


func _test_filtered_slot_drag_visibility() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(STARTER_ABILITY_PATH), "filtered slot drags use the real four-family library")
	if not catalog.last_error.is_empty():
		return
	var runtime_wires := CombatTuning.runtime_wire_ids()
	for index: int in range(runtime_wires.size()):
		var state := PlayerState.new()
		var wire: int = runtime_wires[index]
		var source := index % PlayerState.SPELL_SLOT_COUNT
		var target := (source + 5) % PlayerState.SPELL_SLOT_COUNT
		check(state.place_proven_spell(source, wire), "each family and element can be equipped for a filtered drag")
		var displaced_wire := state.spell_wire_id(target + 1)
		check(state.set_spell_cooldown(wire, 17), "dragged spell has a paid cooldown to preserve")
		check(state.set_spell_cooldown(displaced_wire, 23), "displaced spell has its own cooldown to preserve")
		var before := state.canonical_values()
		var before_wires := state.spell_wire_ids.duplicate()
		var editor := SpellLoomEditor.new()
		editor.open_editor(state, catalog)
		var element := String(catalog.ability_from_wire(wire).element)
		var other_element := "fire" if element == "water" else "water"
		check(editor.set_element_filter(other_element), "fixture hides the equipped source spell with another element filter")
		var previous_selection := editor.selected_spell_index
		editor.pointer_down(SpellLoomEditor.slot_rect(source).get_center(), state)
		check(not editor.pointer_up(Vector2.ZERO), "off-filter drag outside the slot grid cancels")
		equal(editor.selected_element_filter, other_element, "cancelled drag keeps the player's filter")
		equal(editor.selected_spell_index, previous_selection, "cancelled drag keeps the visible library choice")
		editor.pointer_down(SpellLoomEditor.slot_rect(source).get_center(), state)
		check(editor.pointer_up(SpellLoomEditor.slot_rect(target).get_center()), "off-filter equipped spell drops into another slot")
		equal(editor.selected_slot_index, target, "filtered drag keeps the exact destination across all twelve positions")
		equal(editor.selected_wire_id(), wire, "filtered drag keeps canonical source identity")
		equal(editor.selected_element_filter, "", "successful off-filter drop reveals the full library")
		equal(editor.status_message, "Selected spell revealed. Review the target slot.", "revealed library cannot retain the previous element filter's footer")
		check(editor.selected_spell_index in editor.visible_spell_indices(), "dropped spell has a visible library highlight")
		check(editor.spell_rect(editor.selected_spell_index).has_area(), "dropped spell has a painted and selectable card")
		equal(editor.assignment_preview(state).kind, "swap", "visible selection still previews the authoritative swap")
		equal(editor.assignment_preview(state).other_slot, source, "swap preview retains its exact source slot")
		var requested := editor.requested_wire_ids(state)
		var expected := before_wires.duplicate()
		expected[source] = displaced_wire
		expected[target] = wire
		equal(requested, expected, "revealing the card changes neither swap nor untouched slot identities")
		equal(state.canonical_values(), before, "filter recovery and request construction never mutate authority")
		check(CharacterWeavePolicy.apply(state, requested), "ordinary authority accepts the complete unique swap")
		equal(state.spell_cooldown_for_wire(wire), 17, "revealed source keeps its paid cooldown")
		equal(state.spell_cooldown_for_wire(displaced_wire), 23, "revealed swap keeps the displaced spell cooldown")
		check(editor.set_element_mask(Mixtures.mask_for_wire(wire)), "same-mixture drag retains an intentionally focused library")
		editor.pointer_down(SpellLoomEditor.slot_rect(target).get_center(), state)
		check(editor.pointer_up(SpellLoomEditor.slot_rect(source).get_center()), "visible equipped spell can be dragged back")
		equal(editor.selected_element_mask, Mixtures.mask_for_wire(wire), "already visible dropped spell does not reset the mixture filter")
		check(editor.selected_spell_index in editor.visible_spell_indices(), "same-element drop also preserves visible selection")
		editor.cycle_focus()
		editor.navigate_grid(1, 0)
		check(editor.selected_spell_index in editor.visible_spell_indices(), "keyboard navigation after a drop stays on visible cards")


func _test_canonical_slot_weaving() -> void:
	var state := PlayerState.new()
	check(state.has_valid_spell_slots(), "new player begins with a valid twelve-spell subset")
	var before := state.spell_wire_ids.duplicate()
	var moving := state.spell_wire_id(2)
	var displaced := state.spell_wire_id(12)
	check(state.set_spell_cooldown(moving, 17), "equipped spell owns an independent cooldown")
	check(state.place_proven_spell(11, moving), "equipped spell can move to Alt+4")
	var expected := before.duplicate()
	expected[1] = displaced
	expected[11] = moving
	equal(state.spell_wire_ids, expected, "swap changes exactly the two involved slots")
	equal(state.spell_cooldown_for_wire(moving), 17, "cooldown follows identity through a weave")
	check(not state.place_proven_spell(-1, moving), "negative slot fails closed")
	check(not state.place_proven_spell(0, 65000), "unproven spell fails closed")
	check(not state.place_proven_spell(0, 170), "retired Ice spell cannot be assigned")
	check(not state.place_proven_spell(0, 166), "retired Charge spell cannot be assigned")
	equal(state.spell_wire_ids, expected, "rejected requests preserve all slots")
	for wire: int in CombatTuning.runtime_wire_ids():
		if wire in state.spell_wire_ids: continue
		var removed := state.spell_wire_id(4)
		check(state.place_proven_spell(3, wire), "another canonical library spell can replace a slot")
		equal(state.spell_wire_id(4), wire, "replacement occupies only its requested slot")
		check(state.spell_slot_index_for_wire(removed) < 0, "displaced spell leaves the selected subset")
		break
	check(state.has_valid_spell_slots(), "all accepted edits preserve a unique twelve-position weave")

func _test_editor_navigation_and_encoding() -> void:
	var state := PlayerState.new()
	var editor := SpellLoomEditor.new()
	editor.open_editor()
	_all_forms(editor)
	check(editor.is_open, "Spell Loom opens explicitly")
	editor.move_selection(-1, -1)
	equal(editor.selected_slot_index, 11, "weave-position navigation wraps")
	equal(editor.selected_spell_index, CombatTuning.runtime_wire_ids().size() - 1, "global spell navigation wraps")
	var final_index := CombatTuning.runtime_wire_ids().size() - 1
	var final_wire := int(CombatTuning.runtime_wire_ids()[final_index])
	var encoded := 11 * SpellLoomEditor.LIBRARY_CAPACITY + final_index + 1
	equal(editor.selected_wire_id(), final_wire, "wrapped selection resolves through stable runtime order")
	equal(editor.request_value(), encoded, "Alt+4 final spell has a bounded request encoding")
	equal(SpellLoomEditor.decode_slot_index(encoded), 11, "request decodes position deterministically")
	equal(SpellLoomEditor.decode_library_index(encoded), final_index, "request decodes final global library index deterministically")
	equal(SpellLoomEditor.wire_id_for_library_index(final_index), final_wire, "last library index resolves the exact canonical spell")
	equal(SpellLoomEditor.wire_id_for_library_index(final_index + 1), 0, "unused protocol capacity is not a playable spell")
	equal(SpellLoomEditor.decode_slot_index(PlayerState.SPELL_SLOT_COUNT * SpellLoomEditor.LIBRARY_CAPACITY + 1), -1, "request above twelve bounded library lanes fails closed")
	equal(SpellLoomEditor.decode_slot_index(0), -1, "invalid request value fails closed")
	var before_request := state.spell_wire_ids.duplicate()
	var requested := editor.requested_wire_ids(state)
	equal(requested.size(), PlayerState.SPELL_SLOT_COUNT, "selected assignment builds one complete proposed weave")
	equal(requested[11], final_wire, "proposed weave places the exact selected spell in the exact selected slot")
	equal(Array(state.spell_wire_ids), Array(before_request), "building a proposed weave cannot mutate authority")
	check(SpellLoomPresenter.assignment_is_enabled({}), "legacy presenter calls remain assignment-enabled without an availability model")
	check(not SpellLoomPresenter.assignment_is_enabled({"enabled": false, "reason": "Stand beside the Spell Loom."}), "presenter disables assignment from the caller policy")
	equal(SpellLoomPresenter.assignment_disabled_reason({"enabled": false, "reason": "Stand beside the Spell Loom."}), "Stand beside the Spell Loom.", "presenter retains the caller's specific refusal reason")
	check(editor.apply_to_state(state), "offline editor applies through canonical state method")
	equal(state.spell_wire_id(12), final_wire, "selected global spell occupies Alt+4")
	check(editor.select_at(Vector2(SpellLoomEditor.GRID_X + SpellLoomEditor.GRID_CELL_WIDTH * 2 + 4, SpellLoomEditor.GRID_Y + SpellLoomEditor.GRID_CELL_HEIGHT + 4)), "mouse selects a visible weave cell")
	equal(editor.selected_slot_index, 6, "mouse grid selection resolves Ctrl+3")
	editor.close_editor()
	check(not editor.is_open, "Spell Loom closes explicitly")


func _test_three_spell_kit_weaving() -> void:
	var state := PlayerState.new()
	state.primary_wire_id = CombatTuning.RILLSHOT_WIRE_ID
	state.active_1_wire_id = CombatTuning.TIDELINE_WIRE_ID
	state.active_2_wire_id = 145 # Canonical Fire Bolt.
	state.reset_spell_slots_to_kit()
	equal(Array(state.spell_wire_ids.slice(0,3)), [140,141,145], "three canonical kit spells keep their initial positions")
	check(state.has_valid_spell_slots(), "twelve-position weave validates canonically")
	var before := state.spell_wire_ids.duplicate()
	var displaced := before[11]
	check(state.place_proven_spell(11,145), "third kit spell can move to Alt+4")
	before[2] = displaced
	before[11] = 145
	equal(state.spell_wire_ids,before,"moving third spell changes exactly two positions")
	var editor := SpellLoomEditor.new()
	editor.open_editor(state)
	_all_forms(editor)
	editor.selected_spell_index = 0
	equal(editor.available_wire_ids.size(),504,"every character has the complete63 by8 library")
	editor.move_selection(-1,-1)
	var last_index := CombatTuning.runtime_wire_ids().size() - 1
	equal(editor.selected_wire_id(),int(CombatTuning.runtime_wire_ids()[last_index]),"library wrapping preserves final stable identity")
	equal(editor.request_value(),11 * SpellLoomEditor.LIBRARY_CAPACITY + last_index + 1,"global request uses bounded protocol lane")
	equal(SpellLoomEditor.decode_library_index(editor.request_value()),last_index,"request resolves final active spell")

func _test_header_text_clearance() -> void:
	var font := ThemeDB.fallback_font
	var font_size := SpellLoomPresenter.HEADER_FONT_SIZE
	var font_ascent := font.get_ascent(font_size)
	var font_height := font.get_height(font_size)
	var subtitle_size := font.get_string_size(SpellLoomPresenter.SUBTITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var subtitle := Rect2(SpellLoomPresenter.SUBTITLE_POSITION - Vector2(0, font_ascent), Vector2(subtitle_size.x, font_height))
	check(SpellLoomEditor.PANEL_RECT.encloses(subtitle), "actual-font Loom instructions remain inside the native panel")
	check(subtitle.end.x + 16.0 <= SpellLoomPresenter.LIBRARY_HEADING_POSITION.x, "Loom instructions end before the right-column heading with a clear gutter")
	for visible_count: int in [4, 16]:
		var heading_text := "SPELLS  /  %d OF 504" % visible_count
		var heading_size := font.get_string_size(heading_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var heading := Rect2(SpellLoomPresenter.LIBRARY_HEADING_POSITION - Vector2(0, font_ascent), Vector2(heading_size.x, font_height))
		check(not subtitle.intersects(heading), "actual-font instructions and filtered/full library heading never overlap")
		check(not heading.intersects(SpellLoomEditor.STARTER_BUTTON_RECT), "library heading stays clear of the starter-kit action")
	check(not subtitle.intersects(SpellLoomEditor.STARTER_BUTTON_RECT), "instructions stay clear of the starter-kit action")


func _test_catalog_layout_and_details() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "four-family catalog loads for Loom layout")
	var editor := SpellLoomEditor.new()
	editor.open_editor(null, catalog)
	_all_forms(editor)
	equal(SpellLoomEditor.matrix_columns(), 4, "compact library retains four painted columns")
	equal(SpellLoomEditor.matrix_cell_count(), 504, "matrix enumerates all mixtures and deliveries")
	equal(SpellLoomEditor.VISIBLE_SPELL_COUNT, 16, "each page bounds readable cards to four rows")
	equal(editor.spell_rect(15).position, Vector2(1032, 376), "last card on first page stays above pagination")
	var widest_name := ""
	for wire: int in editor.available_wire_ids:
		var candidate := String(catalog.ability_from_wire(wire).display_name)
		if ThemeDB.fallback_font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x > ThemeDB.fallback_font.get_string_size(widest_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x:
			widest_name = candidate
	for index: int in editor.available_wire_ids.size():
		_reveal(editor, index)
		var rect := editor.spell_rect(index)
		check(SpellLoomEditor.PANEL_RECT.encloses(rect), "every spell target fits inside the 720p panel")
		check(rect.end.y < SpellLoomEditor.DETAIL_DIVIDER_Y, "all four-family spells clear the detail footer")
		check(not rect.intersects(SpellLoomEditor.CLOSE_RECT) and not rect.intersects(SpellLoomEditor.ASSIGN_RECT), "spell targets never overlap action buttons")
		check(editor.select_at(rect.get_center()), "each displayed cell is selectable at its exact painted center")
		equal(editor.selected_spell_index, index, "each painted center resolves only its own spell")
		var ability := catalog.ability_from_wire(editor.available_wire_ids[index])
		equal(int(ability.element_mask), editor.selected_element_mask, "cell ingredients agree with selected exact mixture")
		equal(AbilityCatalog._spell_family(ability), editor.selected_family_filter, "cell delivery agrees with selected family")
		for other: int in editor.visible_spell_indices():
			if other == index: continue
			check(not rect.intersects(editor.spell_rect(other)), "spell hit targets cannot overlap")
		for slot: int in range(PlayerState.SPELL_SLOT_COUNT):
			check(not rect.intersects(SpellLoomEditor.slot_rect(slot)), "picker and twelve-slot weave stay separate")
		var name := String(ability.display_name)
		for layout: Dictionary in [{"width":rect.size.x - 11,"font_size":14,"lines":2},{"width":SpellLoomEditor.slot_rect(0).size.x - 8,"font_size":13,"lines":3}]:
			var lines := SpellLoomPresenter.name_lines(name, float(layout.width), int(layout.font_size))
			check(lines.size() <= int(layout.lines), "complete names fit two library lines or three equipped-slot lines at readable unchanged sizes")
			equal(" ".join(lines), name, "every current spell name is retained, not silently abbreviated")
			for line: String in lines:
				check(ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, int(layout.font_size)).x <= float(layout.width), "wrapped name fits within its target")
		var font := ThemeDB.fallback_font
		var picker_lines := SpellLoomPresenter.name_lines(name, rect.size.x - 11, SpellLoomPresenter.PICKER_NAME_FONT_SIZE)
		var name_bottom := rect.position.y
		for line: int in picker_lines.size():
			var baseline := rect.position + Vector2(8, SpellLoomPresenter.PICKER_NAME_BASELINE + line * SpellLoomPresenter.PICKER_NAME_LINE_STEP)
			var text_size := font.get_string_size(picker_lines[line], HORIZONTAL_ALIGNMENT_LEFT, -1, SpellLoomPresenter.PICKER_NAME_FONT_SIZE)
			var bounds := Rect2(baseline - Vector2(0, font.get_ascent(SpellLoomPresenter.PICKER_NAME_FONT_SIZE)), text_size)
			check(rect.encloses(bounds), "complete native name glyph bounds fit their card")
			check(bounds.position.y >= name_bottom, "native library name lines never overlap each other")
			name_bottom = maxf(name_bottom, bounds.end.y)
		for info: Dictionary in [{"text":"%dF" % int(ability.flux_cost),"x":8.0},{"text":"SLOT 12","x":77.0}]:
			var baseline := rect.position + Vector2(float(info.x), SpellLoomPresenter.PICKER_INFO_BASELINE)
			var text_size := font.get_string_size(String(info.text), HORIZONTAL_ALIGNMENT_LEFT, -1, SpellLoomPresenter.PICKER_INFO_FONT_SIZE)
			var bounds := Rect2(baseline - Vector2(0, font.get_ascent(SpellLoomPresenter.PICKER_INFO_FONT_SIZE)), text_size)
			check(rect.encloses(bounds), "full cost and equipped-slot glyph bounds remain inside each card")
			check(bounds.position.y >= name_bottom, "card metadata does not obscure a full spell name")
			for scale_factor: float in [0.75,1.0,1.5]:
				check(Rect2(rect.position*scale_factor,rect.size*scale_factor).encloses(Rect2(bounds.position*scale_factor,bounds.size*scale_factor)), "native metadata bounds survive every supported Loom scale")
				check(SpellLoomPresenter.PICKER_INFO_FONT_SIZE*scale_factor >= 9.0, "small-window metadata retains at least nine rendered pixels per nominal font unit")
		check(rect.end.y < SpellLoomEditor.PAGE_PREVIOUS_RECT.position.y, "four readable rows stay above pagination and metrics")
		var slot_rect := SpellLoomEditor.slot_rect(0)
		var slot_lines := SpellLoomPresenter.name_lines(name, slot_rect.size.x - SpellLoomPresenter.SLOT_NAME_PADDING * 2, SpellLoomPresenter.SLOT_NAME_FONT_SIZE)
		var last_bottom := slot_rect.position.y + 22.0
		for line: int in slot_lines.size():
			var at := slot_rect.position + Vector2(SpellLoomPresenter.SLOT_NAME_PADDING, SpellLoomPresenter.SLOT_NAME_BASELINE + line * SpellLoomPresenter.SLOT_NAME_LINE_STEP)
			var extent := font.get_string_size(slot_lines[line], HORIZONTAL_ALIGNMENT_LEFT, -1, SpellLoomPresenter.SLOT_NAME_FONT_SIZE)
			var bounds := Rect2(at - Vector2(0, font.get_ascent(SpellLoomPresenter.SLOT_NAME_FONT_SIZE)), extent)
			check(slot_rect.encloses(bounds) and bounds.position.y >= last_bottom, "all504 equipped names fit real glyph bounds beneath keycap with no line overlap")
			last_bottom = bounds.end.y
		var assignment_copy := widest_name + " → " + name
		check(font.get_string_size(assignment_copy, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x <= 408, "complete current-to-selected names fit the compact assignment preview even with the widest current spell")
		var detail := SpellLoomPresenter.family_detail(ability)
		check(detail.contains("Initial strength %d" % int(ability.reaction_strength)), "Loom detail reads each validated ability's authored reaction strength")
		check(ThemeDB.fallback_font.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x <= 930, "family behavior detail fits without smaller text")
	for slot: int in range(PlayerState.SPELL_SLOT_COUNT):
		var rect := SpellLoomEditor.slot_rect(slot)
		equal(rect.position, Vector2(48 + slot % 4 * 110, 154 + slot / 4 * 86), "four-by-three slot arrangement is preserved")
		check(rect.end.x < SpellLoomEditor.MATRIX_LABEL_X, "slot names and element row labels have separate space")
		for other: int in range(slot):
			check(not rect.intersects(SpellLoomEditor.slot_rect(other)), "weave hit targets cannot overlap")
	equal(editor.spell_rect(-1), Rect2(), "negative cell has no hit area")
	equal(editor.spell_rect(editor.available_wire_ids.size()), Rect2(), "unoccupied library position has no hit area")
	equal(SpellLoomPresenter.family_label("spray"), "Spray", "runtime family label uses the four-family name")
	equal(AbilityCatalog.element_display_name("wind"), "Air", "Loom row labels translate the wind element for players")
	var heavy := catalog.ability_from_wire(179).duplicate(true)
	equal(SpellLoomPresenter.family_detail(heavy), "Heavy: 20 Flux / 120px splash radius. Initial strength 15. Slow shell; blast at impact or endpoint.", "Heavy detail teaches real cost, splash radius and authored initial strength")
	heavy["blast_radius"] = 42000
	heavy["flux_cost"] = 21
	heavy["reaction_strength"] = 7
	equal(SpellLoomPresenter.family_detail(heavy), "Heavy: 21 Flux / 42px splash radius. Initial strength 15. Slow shell; blast at impact or endpoint.", "Heavy teaching reads editable layout values while initial strength remains the validated compiled definition")
	var rapid := catalog.ability_from_wire(180).duplicate(true)
	var bolt := catalog.ability_from_wire(145).duplicate(true)
	check(SpellLoomPresenter.family_detail(bolt).contains("Hold to repeat; release stops new casts."), "Bolt advertises its authored held behavior")
	bolt.repeat_while_held = false
	check(SpellLoomPresenter.family_detail(bolt).contains("Press for one shot."), "Bolt teaching follows the authored trigger instead of hard-coding it")
	check(SpellLoomPresenter.family_detail(rapid).contains("hold the spell key / 2 Flux per shot") and SpellLoomPresenter.family_detail(rapid).contains("Initial strength 1; always trail-free"), "Rapid detail teaches held-key firing, source strength and explicit trail exclusion")
	rapid["repeat_while_held"] = false
	rapid["flux_cost"] = 4
	check(SpellLoomPresenter.family_detail(rapid).contains("press the spell key / 4 Flux per shot"), "Rapid teaching follows catalog repeat and cost settings")
	var spray := catalog.ability_from_wire(141).duplicate(true)
	check(SpellLoomPresenter.family_detail(spray).contains("Spray: 300px range / 16 Flux") and SpellLoomPresenter.family_detail(spray).contains("Initial strength 3; paid ingredient fan"), "Spray teaching reads the live range, cost and generalized paid finite ingredient strength")
	var retired_wire := 110
	check(retired_wire not in editor.available_wire_ids, "catalog-only Vector Lance is absent from the runtime picker")
	equal(SpellLoomPresenter.family_detail(catalog.ability_from_wire(retired_wire)), "This authored catalog entry is disabled for runtime selection.", "retired catalog entry has an honest non-runtime descriptor")
	editor.available_wire_ids.append(retired_wire)
	editor.selected_spell_index = editor.available_wire_ids.size() - 1
	equal(editor.request_value(), 0, "catalog-only authored spell cannot encode a runtime request")
	var state := PlayerState.new()
	check(not editor.apply_to_state(state), "catalog-only authored spell is rejected by state authority")


func _test_element_filter_contract() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(STARTER_ABILITY_PATH), "element filter uses the validated spell matrix")
	if not catalog.last_error.is_empty():
		return
	var editor := SpellLoomEditor.new()
	editor.open_editor(null, catalog)
	equal(editor.selected_element_filter, "", "Loom opens with the complete library visible")
	equal(editor.visible_spell_indices().size(), 16, "All starts with a bounded first page")
	equal(editor.filtered_spell_indices().size(), 252, "core forms cover all63 mixtures before More Forms")
	for element: String in SpellLoomEditor.Elements.IDS:
		check(editor.set_element_filter(element), "every canonical element is a valid filter")
		var visible := editor.visible_spell_indices()
		equal(visible.size(), 4, "%s filter exposes exactly four delivery families" % element)
		for visible_index: int in range(visible.size()):
			var library_index := int(visible[visible_index])
			var wire_id := int(editor.available_wire_ids[library_index])
			equal(String(catalog.ability_from_wire(wire_id).element), element, "filtered cells retain their canonical element identity")
			var rectangle := editor.spell_rect(library_index)
			check(rectangle.has_area() and rectangle.position.y == SpellLoomEditor.LIBRARY_TOP, "filtered family row stays compact at the library top")
			equal(rectangle.position.x, SpellLoomEditor.SPELL_PICKER_X + visible_index * SpellLoomEditor.SPELL_PICKER_WIDTH, "filtered cells preserve Bolt/Heavy/Rapid/Spray order")
		check(editor.selected_spell_index in visible, "filter selection always points to one visible canonical spell")
		var before_wire := editor.selected_wire_id()
		editor.move_selection(0, 1)
		check(editor.selected_wire_id() != before_wire and editor.selected_spell_index in visible, "Left/Right navigation cycles only the shown element row")
	check(not editor.set_element_filter("spirit"), "unknown and deferred element filters fail closed")
	equal(editor.selected_element_filter, "dark", "rejected filter cannot change the active view")
	check(editor.select_at(SpellLoomEditor.element_filter_rect(3).get_center()), "Air filter button shares the ordinary Loom hit path")
	equal(editor.selected_element_mask, 40, "Air button adds Air to the already selected Dark ingredient")
	check(editor.select_at(SpellLoomEditor.element_filter_rect(6).get_center()), "toggling Dark again removes just that ingredient")
	equal(editor.selected_element_filter, "wind", "single remaining Air stores the canonical internal wind id")
	equal(SpellLoomEditor.element_filter_label("wind"), "Air", "filter label never exposes internal wind terminology")
	var selected_wire := editor.selected_wire_id()
	var request := editor.request_value()
	check(request > 0, "filtered selection still emits a canonical weave request")
	equal(SpellLoomEditor.wire_id_for_library_index(SpellLoomEditor.decode_library_index(request)), selected_wire, "filter positions never replace canonical wire identity")
	check(editor.select_at(SpellLoomEditor.element_filter_rect(0).get_center()), "All filter is directly clickable")
	equal(editor.visible_spell_indices().size(), 16, "All restores the first bounded page without changing the weave")
	for filter_index: int in range(SpellLoomEditor.ELEMENT_FILTERS.size()):
		var rectangle := SpellLoomEditor.element_filter_rect(filter_index)
		check(SpellLoomEditor.PANEL_RECT.encloses(rectangle), "every filter target fits the native 1280x720 Loom")
		for earlier: int in range(filter_index):
			check(not rectangle.intersects(SpellLoomEditor.element_filter_rect(earlier)), "element filter hit targets never overlap")


func _test_all_masks_pages_and_locks() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(STARTER_ABILITY_PATH), "paged library uses real504 catalog")
	var state := PlayerState.new()
	var editor := SpellLoomEditor.new()
	editor.open_editor(state, catalog)
	var first_wire := state.spell_wire_id(1)
	equal(editor.selected_element_mask, Mixtures.mask_for_wire(first_wire), "default entry focuses actual first slot's ingredient set")
	check(editor.basic_forms_only, "basic delivery choices appear first")
	var font := ThemeDB.fallback_font
	var previous_preview := SpellLoomPresenter.ASSIGNMENT_PREVIEW_RECT
	var target_label_top := SpellLoomPresenter.TARGET_BASELINE - font.get_ascent(13)
	check(SpellLoomPresenter.TARGET_BASELINE + font.get_descent(13) < SpellLoomEditor.DETAIL_DIVIDER_Y, "full target-binding glyphs stay above the detail divider")
	for payload: Dictionary in Mixtures.all():
		var mask := int(payload.element_mask)
		var prefix := "Matching matter: " if (mask & (mask - 1)) == 0 else "Payload field: "
		var lines := SpellLoomPresenter._wrap_payload(prefix + String(payload.purpose), 432)
		lines.append_array(SpellLoomPresenter._wrap_payload("Counter: " + String(payload.counter), 432))
		check(lines.size() <= 4, "all63 full payload rules fit four lines without truncating a counter")
		equal(" ".join(lines), prefix + String(payload.purpose) + " Counter: " + String(payload.counter), "rule wrap preserves every source word")
		for index: int in lines.size():
			var extent := font.get_string_size(lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
			var bounds := Rect2(Vector2(48, SpellLoomPresenter.PAYLOAD_BASELINE + index * SpellLoomPresenter.PAYLOAD_LINE_STEP - font.get_ascent(12)), Vector2(extent.x, font.get_height(12)))
			check(extent.x <= 432 and SpellLoomEditor.PANEL_RECT.encloses(bounds), "actual12px payload glyphs fit left panel")
			check(not bounds.intersects(previous_preview) and bounds.end.y <= target_label_top, "payload glyphs clear compact assignment and actual target-binding baseline")
			check(font.get_height(12) <= SpellLoomPresenter.PAYLOAD_LINE_STEP, "complete field/counter lines never overlap")
	_all_forms(editor)
	equal(editor.page_count(), 32, "all504 readable cards remain reachable across32 bounded pages")
	var before := state.canonical_values()
	var seen := {}
	for page: int in editor.page_count():
		if page > 0: editor.change_page(1)
		var visible := editor.visible_spell_indices()
		check(visible.size() > 0 and visible.size() <= 16, "each page has a bounded nonempty set")
		for index: int in visible:
			check(not seen.has(index), "paging visits each canonical spell once")
			seen[index] = true
			var rect := editor.spell_rect(index)
			check(rect.has_area() and not rect.intersects(SpellLoomEditor.PAGE_NEXT_RECT), "painted card has reachable nonoverlapping pointer geometry")
			for other: int in visible:
				if other < index: check(not rect.intersects(editor.spell_rect(other)), "every actual page card has a disjoint hit target")
			check(editor.select_at(rect.get_center()), "every paged card responds at its visible center")
			equal(editor.selected_spell_index, index, "pointer preserves canonical index across pages")
	equal(seen.size(), 504, "all504 are genuinely reachable through pages")
	for mask: int in range(64):
		check(editor.set_element_mask(mask), "every nonempty mixture and All is filterable")
		equal(editor.filtered_spell_indices().size(), 504 if mask == 0 else 8, "exact mixture has every delivery once")
		for family: String in Mixtures.FAMILIES:
			check(editor.set_family_filter(family), "every delivery has a real filter")
			var expected := 63 if mask == 0 else 1
			equal(editor.filtered_spell_indices().size(), expected, "mask and delivery filters compose without omissions")
			for index: int in editor.filtered_spell_indices():
				var wire := int(editor.available_wire_ids[index])
				equal(Mixtures.family_for_wire(wire), family, "filtered wire preserves delivery")
				if mask > 0: equal(Mixtures.mask_for_wire(wire), mask, "filtered wire preserves exact ingredients")
			editor.set_family_filter("")
	check(not editor.set_element_mask(-1) and not editor.set_element_mask(64), "invalid ingredient masks refuse")
	check(not editor.set_family_filter("unknown"), "invalid delivery refuses")
	var locked_wire := Mixtures.wire_for(63, "rebound")
	_reveal(editor, editor.available_wire_ids.find(locked_wire))
	editor.blocked_reason_by_wire[locked_wire] = "Defeat its rival first; Range can borrow it."
	check(not editor.apply_to_state(state), "locked signature cannot use direct local apply")
	equal(editor.status_message, editor.unavailable_reason(locked_wire), "lock explains unlock and testing routes")
	equal(state.canonical_values(), before, "all filters/pages/pointer/lock inspection leave authority unchanged")
	editor.blocked_reason_by_wire.clear()
	check(editor.apply_to_state(state), "removing admitted lock allows ordinary assignment")
	equal(state.spell_wire_id(editor.selected_slot_index + 1), locked_wire, "unlocked spell enters chosen actual slot")


func _test_migration_preview_contract() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(STARTER_ABILITY_PATH),"migration preview uses real spell definitions")
	var state := PlayerState.new()
	var current := state.spell_wire_ids.duplicate()
	var proposed := PackedInt32Array(CombatTuning.runtime_wire_ids().slice(0,12))
	var original := proposed.duplicate()
	original[0] = 170
	var proposal := {"required":true,"valid":true,"migration_id":"six-elements-v1","champion_id":"oh_tipi","before_wire_ids":original,"after_wire_ids":proposed,"notice":"Review replacements before Apply."}
	var editor := SpellLoomEditor.new()
	editor.open_editor(state,catalog)
	check(editor.prepare_migration_preview(state,catalog,proposal),"valid migration opens explicit comparison")
	equal(editor.starter_preview.rows[0].before_wire_id,170,"original saved Ice choice remains visible in comparison")
	equal(editor.starter_preview.before_wire_ids,current,"optimistic guard uses current authority, not archived save")
	var request := editor.request_starter_apply()
	equal(request.action,"apply_character_weave_migration","reviewed migration has its own root intent")
	equal(request.original_saved_wire_ids,original,"original provenance survives to root validation")
	equal(request.wire_ids,proposed,"Apply carries exactly reviewed replacement slots")
	request.wire_ids[0] = 0
	check(editor.starter_preview.after_wire_ids[0] != 0,"caller cannot mutate stored migration preview")
	check(not editor.apply_to_state(state),"migration cannot bypass root authority/save")
	editor.cancel_starter_preview()
	equal(state.spell_wire_ids,current,"preview and Cancel never mutate current state")
	var invalid := proposal.duplicate(true)
	invalid.after_wire_ids[1] = invalid.after_wire_ids[0]
	check(not editor.prepare_migration_preview(state,catalog,invalid),"duplicate migration replacement fails closed")
	invalid = proposal.duplicate(true)
	invalid.after_wire_ids[0] = 170
	check(not editor.prepare_migration_preview(state,catalog,invalid),"retired alias cannot survive in proposed output")
	for key: String in ["before_wire_ids", "after_wire_ids"]:
		for malformed: Variant in ["not slots", {}, [], 12, null]:
			invalid = proposal.duplicate(true)
			invalid[key] = malformed
			check(not editor.prepare_migration_preview(state, catalog, invalid), "malformed %s fails closed before typed assignment" % key)
			check(not editor.starter_preview_active(), "malformed migration leaves no actionable preview")
			check(editor.request_starter_apply().is_empty(), "malformed migration cannot emit Apply")
			equal(state.spell_wire_ids, current, "malformed migration preserves current authority")
