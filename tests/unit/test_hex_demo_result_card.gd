extends FluxTestSuite


const Card = preload("res://src/presentation/hex_demo_result_card.gd")
var catalog := AbilityCatalog.new()


func run() -> int:
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "learning card uses real production Bolt wires")
	_test_observation_and_current_truth()
	_test_restored_slots_and_bindings()
	_test_missing_and_unbound()
	_test_cancel_and_abort_are_not_success()
	_test_all_first_ten_pairs()
	_test_layout_and_long_bindings()
	return finish("hex-demo-result-card")


func _wire(element: String) -> int:
	return int(catalog.ability(catalog.spell_id_at(element, "bolt")).wire_id)


func _result(first: String = "water", second: String = "fire") -> Dictionary:
	var recipe_wire := HexRecipePolicy.recipe_wire(int(AbilityCatalog.DISPLAY_ELEMENT_WIRES[first]), int(AbilityCatalog.DISPLAY_ELEMENT_WIRES[second]))
	return {"outcome": "complete", "message": "Paid demo complete.", "actor_id": 1,
		"recipe_wire_id": recipe_wire, "elements": PackedStringArray([first, second]), "wires": PackedInt32Array([_wire(first), _wire(second)]),
		"paid_casts": 2, "paid_matter": 1_200, "paid_flux": 12_000, "weave_restored": true,
		"observed_product": {"id": 44, "recipe_wire_id": recipe_wire, "name": HexRecipePolicy.definition(recipe_wire).name,
			"quantity": 1_200, "cell_count": 3, "source_ids": [20, 21]}}


func _actor() -> PlayerState:
	var actor := PlayerState.new()
	actor.spell_wire_ids.fill(0)
	actor.spell_wire_ids[6] = _wire("water")
	actor.spell_wire_ids[11] = _wire("fire")
	return actor


func _empty_preferences() -> PlayerPreferences:
	var preferences := PlayerPreferences.new()
	for action: StringName in preferences.keyboard_bindings: preferences.keyboard_bindings[action] = 0
	for action: StringName in preferences.mouse_bindings: preferences.mouse_bindings[action] = 0
	for action: StringName in preferences.controller_bindings: preferences.controller_bindings[action] = PlayerPreferences.unbound_controller_binding()
	return preferences


func _words(card: Dictionary) -> String:
	return "\n".join(card.get("lines", PackedStringArray()))


func _test_observation_and_current_truth() -> void:
	var result := _result()
	var actor := _actor()
	var preferences := PlayerPreferences.new()
	var before_actor := actor.canonical_values()
	var before_result := var_to_bytes(result)
	var before_preferences := var_to_bytes([preferences.keyboard_bindings, preferences.mouse_bindings, preferences.controller_bindings])
	var view := Card.build(result, actor, preferences)
	equal(String(view.title), "CHEMISTRY OBSERVED", "successful card labels observation rather than progression")
	var text := _words(view)
	check(text.contains("Steam / 1200 matter across 3 whole hexes"), "card reports the observed quantity and cells")
	check(text.contains("12.0 Flux") and text.contains("No refund"), "card retains gross paid outcome")
	check(text.to_lower().contains("visible capped scald pressure"), "Steam card teaches the current visible bounded attack")
	check(text.contains("cool with a fresh Water cast"), "Steam gives the actual production counter")
	check(text.contains("two separate paid Bolts") and text.contains("No world reset"), "manual retry preserves paid separate sources and world state")
	equal(actor.canonical_values(), before_actor, "building a card never equips loaners or casts")
	equal(var_to_bytes(result), before_result, "presentation never rewrites the terminal receipt")
	equal(var_to_bytes([preferences.keyboard_bindings, preferences.mouse_bindings, preferences.controller_bindings]), before_preferences, "presentation never changes bindings")
	var vortex := Card.build(_result("wind", "wind"), actor, preferences)
	check(_words(vortex).contains("use the center opening, jump, or leave between pulses"), "current Vortex teaches its actual annular opening and timed escape")
	check(Card.build({}, actor, preferences).is_empty(), "dismissed or absent result produces no card")


func _test_restored_slots_and_bindings() -> void:
	var actor := _actor()
	var preferences := _empty_preferences()
	preferences.keyboard_bindings[&"spell_3"] = KEY_T
	preferences.keyboard_bindings[&"spell_layer_ctrl"] = KEY_SHIFT
	preferences.mouse_bindings[&"spell_4"] = MOUSE_BUTTON_MIDDLE
	preferences.controller_bindings[&"spell_layer_alt"] = {"kind": "button", "index": JOY_BUTTON_RIGHT_SHOULDER, "direction": 0}
	var view := Card.build(_result(), actor, preferences)
	check(bool(view.retry_ready), "equipped spells with real saved chords have usable manual instructions")
	equal(int(view.retry_steps[0].slot), 6, "first hint resolves the restored slot, not demo loaner slot zero")
	equal(int(view.retry_steps[1].slot), 11, "second hint resolves restored layer three, not loaner slot one")
	equal(String(view.retry_steps[0].binding), "Shift+T", "manual hint uses the current remapped keyboard modifier")
	equal(String(view.retry_steps[1].binding), "PAD RB+MOUSE M", "manual hint preserves mixed-device saved chord")
	preferences.keyboard_bindings[&"spell_3"] = KEY_Y
	equal(String(Card.build(_result(), actor, preferences).retry_steps[0].binding), "Shift+Y", "rebinding does not leave a cached stale retry key")
	actor.spell_wire_ids[6] = 0
	actor.spell_wire_ids[0] = _wire("water")
	preferences.keyboard_bindings[&"spell_1"] = KEY_Z
	actor.set_spell_cooldown(_wire("water"), 32)
	var updated := Card.build(_result(), actor, preferences)
	equal(int(updated.retry_steps[0].slot), 0, "a changed current weave is resolved on each read")
	check(_words(updated).contains("Z after its cooldown"), "live paid cooldown is not advertised as ready for immediate casting")
	var mirror := _result("water", "water")
	var mirror_view := Card.build(mirror, actor, preferences)
	equal(int(mirror_view.retry_steps[0].slot), int(mirror_view.retry_steps[1].slot), "same-element pair repeats one restored slot, never invents a duplicate")
	equal(mirror_view.retry_steps.size(), 2, "same-element recipe still teaches two separate paid casts")


func _test_missing_and_unbound() -> void:
	var actor := _actor()
	actor.spell_wire_ids[6] = 0
	var preferences := _empty_preferences()
	var view := Card.build(_result(), actor, preferences)
	check(not bool(view.retry_ready), "missing or unbound spells are not presented as usable")
	equal(int(view.retry_steps[0].slot), -1, "missing restored Bolt has no invented position")
	check(_words(view).contains("Water Bolt is absent from your restored weave. Equip it in Spell Loom"), "missing loaner guides explicit manual equipping")
	check(_words(view).contains("Not bound. Assign its button and modifier in Controls"), "unbound input guides explicit Controls recovery")
	preferences.keyboard_bindings[&"spell_4"] = KEY_T
	check(not bool(Card.build(_result(), actor, preferences).retry_steps[1].available), "a bound base button does not conceal an unbound required modifier")
	check(_words(Card.build(_result(), actor, null)).contains("Binding unavailable"), "missing preferences never synthesize default controls")
	check(not bool(Card.build(_result(), null, preferences).retry_ready), "missing actor cannot receive live manual cast hints")
	actor.health = 0
	check(_words(Card.build(_result(), actor, preferences)).contains("living free-practice actor"), "defeated actor receives honest recovery guidance")


func _test_cancel_and_abort_are_not_success() -> void:
	for outcome: String in ["canceled", "aborted"]:
		var result := _result()
		result.outcome = outcome
		result.message = "Paid demo stopped: first Bolt was refused (capacity)."
		result.observed_product = {}
		result.paid_casts = 0
		result.paid_matter = 0
		result.paid_flux = 0
		var view := Card.build(result, _actor(), PlayerPreferences.new())
		check(String(view.title) != "CHEMISTRY OBSERVED", "unsuccessful terminal state is not promoted to success")
		check(_words(view).contains("No selected two-source reaction was observed"), "unsuccessful run explicitly states lack of observation")
		check(_words(view).contains("If Steam forms:"), "unobserved recipe behavior is conditional, not fabricated")
		check(_words(view).contains("refused (capacity)"), "actual refusal reason remains visible")
		check(_words(view).contains("0 / 2 Bolts / 0.0 Flux / 0 matter"), "zero admission is reported without an invented cost")


func _test_all_first_ten_pairs() -> void:
	var pairs := {}
	for first: String in ["water", "earth", "fire", "wind"]:
		for second: String in ["water", "earth", "fire", "wind"]:
			var view := Card.build(_result(first, second), _actor(), PlayerPreferences.new())
			pairs[int(view.recipe_wire_id)] = true
			check(_words(view).contains("Effect: ") and _words(view).contains("Counter: "), "every supported pair has one current effect and a counter")
			var cell := Card._recipe_cell(HexRecipePolicy.definition(int(view.recipe_wire_id)))
			check((view.lines as PackedStringArray).has("Counter: " + String(cell.counter) + "."), "every pair preserves exact current Compendium counter wording and element casing")
			check((view.lines as PackedStringArray).size() <= 10, "result content remains bounded to one short learning card")
	equal(pairs.size(), 10, "all ten unique supported chemistry pairs are covered")


func _test_layout_and_long_bindings() -> void:
	var actor := _actor()
	var preferences := _empty_preferences()
	for action: StringName in [&"spell_3", &"spell_4"]:
		preferences.controller_bindings[action] = {"kind": "button", "index": 31, "direction": 0}
	for action: StringName in [&"spell_layer_ctrl", &"spell_layer_alt"]:
		preferences.controller_bindings[action] = {"kind": "axis", "index": 15, "direction": -1}
	var view := Card.build(_result(), actor, preferences)
	equal(String(view.retry_steps[0].binding), "PAD A15-+PAD B31", "longest numeric saved pad chord retains its exact identities")
	var cases: Array[Dictionary] = [view, Card.build(_result(), actor, _empty_preferences()), Card.build(_result("wind", "wind"), actor, preferences)]
	var aborted := _result()
	aborted.outcome = "aborted"
	aborted.observed_product = {}
	aborted.message = "Paid demo stopped: an ordinary paid cast did not finish within its authored timing window."
	cases.append(Card.build(aborted, actor, _empty_preferences()))
	for viewport: Vector2 in [Vector2(960, 540), Vector2(1280, 720)]:
		for candidate: Dictionary in cases:
			var compact := Card.layout(candidate, viewport, Vector2.ZERO, ThemeDB.fallback_font)
			check(not bool(compact.expanded), "card stays compact away from its hover footprint")
			check(compact.rows.size() <= 4, "default card is three to four short lines rather than the full lesson")
			var expanded := Card.layout(candidate, viewport, Vector2(viewport.x - 60, 106), ThemeDB.fallback_font)
			check(bool(expanded.expanded), "hover opens the full learning card")
			check(bool(expanded.content_fits), "all wrapped learning content fits at the supported narrow/native viewport")
			var panel: Rect2 = expanded.panel
			check(panel.position.x >= 16 and panel.end.x <= viewport.x - 16, "card stays within horizontal viewport margins")
			check(panel.end.y <= viewport.y - 104, "expanded card reserves the bottom combat HUD")
			check(panel.encloses(expanded.close), "close button remains reachable within the expanded card")
			for row: Dictionary in expanded.rows:
				check(ThemeDB.fallback_font.get_string_size(row.text, HORIZONTAL_ALIGNMENT_LEFT, -1, row.font_size).x <= float(expanded.body_width), "every full-text row wraps without horizontal clipping")
				check(float(row.position.y) <= panel.end.y - 6, "every expanded baseline remains inside the card")
			check(int(expanded.body_font_size) >= 10, "supported viewports retain legible learning text")
	var long_chord := "Shift+" + "EXTENDED_SAVED_KEY_NAME_".repeat(6)
	var wrapped: PackedStringArray = Card._wrapped_lines(PackedStringArray([long_chord]), ThemeDB.fallback_font, 12, 452)
	equal("".join(wrapped), long_chord, "an unusually long input token wraps without losing or inventing characters")
