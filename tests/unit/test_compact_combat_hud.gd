extends FluxTestSuite

# Compile the native profiling wrappers in the regular gate as well: changing
# a production draw signature must not silently strand performance diagnostics.
const DrawProfile = preload("res://tests/support/hex_draw_component_harness.gd")


func run() -> int:
	check(DrawProfile.TimedHud.new() is CompactCombatHud, "native draw attribution wrappers match current production signatures")
	_test_repository_hud()
	_test_fail_closed_contract()
	_test_recovery_and_float_status()
	_test_withered_recovery_labels()
	_test_resource_bar_readability()
	_test_fractional_resource_transitions()
	_test_resource_inspection_panel()
	_test_spell_family_labels()
	_test_all_payload_card_layouts()
	_test_retained_card_layouts()
	_test_retained_panel_geometry()
	_test_shared_top_third_portraits()
	_test_quiet_authoritative_readiness()
	_test_paid_startup_progress()
	_test_casting_card_hierarchy()
	_test_compact_practice_card()
	_test_truthful_bindings()
	_test_hidden_cast_status()
	_test_jump_preparation_lifecycle()
	_test_jump_preparation_costs_and_interruptions()
	_test_jump_preparation_geometry()
	_test_multiline_session_geometry()
	return finish("compact-combat-hud")


func _test_retained_panel_geometry() -> void:
	var hud := CompactCombatHud.new()
	var rectangle := Rect2(16, 32, 142, 70)
	var expected := PackedVector2Array([Vector2(22,32), Vector2(152,32), Vector2(158,38), Vector2(158,96), Vector2(152,102), Vector2(22,102), Vector2(16,96), Vector2(16,38)])
	var geometry := hud._panel_geometry(rectangle, 6)
	equal(geometry.points, expected, "retained panel preserves the prior eight exact cut-corner vertices")
	var outline := expected.duplicate()
	outline.append(expected[0])
	equal(geometry.outline, outline, "retained outline keeps the original closed point order")
	var arrays: Array = geometry.mesh.surface_get_arrays(0)
	var native_points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for index: int in expected.size():
		equal(native_points[index], Vector3(expected[index].x, expected[index].y, 0), "native panel mesh uses the exact screen plane")
	equal(arrays[Mesh.ARRAY_INDEX], Geometry2D.triangulate_polygon(expected), "native panel uses the engine's exact polygon triangulation")
	var mesh_id: int = geometry.mesh.get_instance_id()
	for frame: int in 30:
		equal(hud._panel_geometry(rectangle, 6).mesh.get_instance_id(), mesh_id, "unchanged panel geometry retains its GPU mesh")
	equal(hud._panel_geometry_builds, 1, "ordinary frames do not rebuild HUD panel geometry")
	check(hud._panel_geometry(Rect2(17,32,142,70),6).mesh.get_instance_id() != mesh_id, "new screen placement rebuilds geometry")
	check(hud._panel_geometry(rectangle,5).mesh.get_instance_id() != mesh_id, "changed authored corner step rebuilds geometry")
	for variant: int in 160:
		hud._panel_geometry(Rect2(16+variant,32,142,70),6)
		check(hud._panel_geometries.size() <= CompactCombatHud.MAX_PANEL_GEOMETRIES, "resizes cannot accumulate unbounded HUD mesh history")
	equal(hud._panel_geometry(rectangle, 6).mesh.get_instance_id(), mesh_id, "cache saturation cannot evict previously submitted panel RIDs")
	var overflow := hud._panel_geometry(Rect2(999,999,142,70),6)
	check(overflow.mesh == null and overflow.points.size() == 8, "overflow retains the exact legacy polygon path without another GPU allocation")


func _test_retained_card_layouts() -> void:
	var hud := CompactCombatHud.new()
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "cached card fixture uses actual spell catalog")
	var font := ThemeDB.fallback_font
	var rect := Rect2(720, 600, 142, 70)
	var ability := catalog.ability_from_wire(140)
	check(not ability.is_empty(), "cached card fixture has an actual playable spell")
	var card := hud._spell_card_layout(0, ability, "1", rect, font)
	equal(card, CompactCombatHud.spell_card_model(ability, "1", rect, font), "retained card exactly matches uncached layout")
	var builds: int = hud._spell_card_layout_builds
	for index: int in 30:
		equal(hud._spell_card_layout(0, ability.duplicate(true), "1", rect, font), card, "equivalent fresh catalog views retain identical text")
	equal(hud._spell_card_layout_builds, builds, "ordinary resource/cooldown frames do not reshape static text")
	ability.flux_cost = int(ability.get("flux_cost", 0)) + 7
	equal(hud._spell_card_layout(0, ability, "1", rect, font), CompactCombatHud.spell_card_model(ability, "1", rect, font), "changed spell metadata refreshes cached cost and layout")
	equal(hud._spell_card_layout(0, ability, "Mouse 5", rect, font), CompactCombatHud.spell_card_model(ability, "Mouse 5", rect, font), "binding change reshapes the key and title")
	var moved := Rect2(30, 60, 160, 70)
	equal(hud._spell_card_layout(0, ability, "Mouse 5", moved, font), CompactCombatHud.spell_card_model(ability, "Mouse 5", moved, font), "window resize refreshes card placement")
	for slot: int in PlayerState.SPELL_SLOT_COUNT:
		hud._spell_card_layout(slot, ability, str(slot), rect, font)
	for slot: int in [-1, 99]: hud._spell_card_layout(slot, ability, str(slot), rect, font)
	equal(hud._spell_card_layouts.size(), PlayerState.SPELL_SLOT_COUNT, "HUD cache cannot grow beyond the twelve real spell slots")


func _test_multiline_session_geometry() -> void:
	for viewport: Vector2 in [Vector2(960, 540), Vector2(1280, 720), Vector2(1920, 1080)]:
		for lines: int in range(1, 7):
			var panel := CompactCombatHud.session_panel(viewport, 16, 248, 34, lines)
			check(panel.size == Vector2(248, 34 + (lines - 1) * 14), "session panel preserves readable row pitch")
			check(Rect2(Vector2.ZERO, viewport).encloses(panel), "standings stay inside supported viewport")
			check(panel.end.y + 28 < viewport.y - 134, "standings and feedback leave resource/footer space")
	check(CompactCombatHud.session_panel(Vector2(960, 540), 16, 248, 34, 99).size.y == 104, "session panel remains bounded to six lines")


func _test_casting_card_hierarchy() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "casting hierarchy uses live catalog")
	var active: Dictionary = catalog.ability(catalog.spell_id_at("water", "heavy"))
	var other: Dictionary = catalog.ability(catalog.spell_id_at("fire", "bolt"))
	var state := PlayerState.new()
	state.pending_cast_wire_id = int(active.wire_id)
	state.pending_cast_ticks = 12
	state.flux = state.flux_maximum
	var before := state.canonical_values()
	var visible := CompactCombatHud.spell_display_status(state, active)
	check(visible.casting and not visible.waiting, "only the paid spell receives active card emphasis")
	equal(visible.label, "CASTING", "paid cast keeps explicit text, not color-only feedback")
	equal(visible.progress, CompactCombatHud.spell_readiness(state, active).progress, "active card keeps exact authority-owned fill")
	var waiting := CompactCombatHud.spell_display_status(state, other)
	check(waiting.waiting and not waiting.casting, "other spells are unavailable during shared commitment")
	equal(waiting.kind, "waiting", "otherwise available spells cannot claim ready during a paid cast")
	equal(waiting.label, "", "other cards do not repeat FINISH CAST")
	equal(waiting.progress, 0.0, "waiting card cannot borrow casting or full ready fill")
	equal(CompactCombatHud.cast_wait_label(state), "OTHER SPELLS WAIT", "shared restriction remains explicit once above visible row")
	equal(state.canonical_values(), before, "display projection cannot rewrite paid authority")
	state.flux = 0
	visible = CompactCombatHud.spell_display_status(state, active, 120, Vector2i.ZERO)
	equal(visible.kind, "startup", "paid spell does not require payment or capacity again")
	equal(visible.label, "CASTING", "zero remaining Flux cannot hide active casting")
	state.set_spell_cooldown(int(other.wire_id), 60)
	waiting = CompactCombatHud.spell_display_status(state, other, 120, Vector2i.ZERO)
	equal(waiting.kind, "cooldown", "other card retains its own cooldown ahead of resource restrictions")
	equal(waiting.label, "0.5s", "waiting cooldown remains readable instead of shared warning")
	check(waiting.waiting and not waiting.casting, "secondary cooldown is not a claim that a new cast is allowed")
	state.set_spell_cooldown(int(other.wire_id), 0)
	waiting = CompactCombatHud.spell_display_status(state, other, 120, Vector2i.ZERO)
	equal(waiting.kind, "capacity", "other card retains authored capacity before Flux")
	equal(waiting.label, "MATERIAL LIMIT", "secondary capacity denial remains explicit")
	waiting = CompactCombatHud.spell_display_status(state, other)
	equal(waiting.kind, "flux", "other card retains its unpaid Flux requirement")
	equal(waiting.label, "NEED %d F" % int(other.flux_cost), "other card never borrows active cast's payment")
	equal(CompactCombatHud.spell_summary_label(other), "BOLT · %d F" % int(other.flux_cost), "family and authored price remain unchanged")
	state.pending_cast_wire_id = 0
	equal(CompactCombatHud.cast_wait_label(state), "", "shared cue disappears immediately on authoritative release")
	equal(CompactCombatHud.spell_display_status(state, other).kind, "flux", "release restores ordinary unpaid restriction")
	var controlled := CompactCombatHud.spell_display_status(state, other, 120, Vector2i.ZERO, "control_stunned")
	equal(controlled.kind, "control", "control still precedes cooldown, capacity and Flux without paid commitment")
	check(not controlled.waiting and not controlled.casting, "control is not fabricated paid startup")
	state.flux = state.flux_maximum
	var gate_only := CompactCombatHud.spell_display_status(state, other, 120, Vector2i(-1, -1), "startup_commitment")
	check(gate_only.waiting and not gate_only.casting and gate_only.kind == "waiting", "gate-only commitment cannot invent a matching paid card")
	equal(CompactCombatHud.cast_wait_label(state, "startup_commitment"), "SPELLS WAIT", "gate-only cue does not invent paid identity")
	state.health = 0
	state.pending_cast_wire_id = int(active.wire_id)
	var unavailable := CompactCombatHud.spell_display_status(state, active)
	equal(unavailable.label, "UNAVAILABLE", "death overrides lingering paid identity")
	check(not unavailable.waiting and not unavailable.casting, "dead card has no startup emphasis")
	equal(CompactCombatHud.cast_wait_label(state), "", "death removes global waiting cue")
	equal(CompactCombatHud.spell_display_status(null, other).kind, "unavailable", "missing player is safe")
	equal(CompactCombatHud.spell_display_status(state, {}).kind, "unavailable", "empty ability stays explicit")
	state.health = state.health_maximum
	state.flux = state.flux_maximum
	for slot: int in PlayerState.SPELL_SLOT_COUNT:
		state.spell_wire_ids.fill(int(other.wire_id))
		state.spell_wire_ids[slot] = int(active.wire_id)
		before = state.canonical_values()
		for position: int in PlayerState.SPELL_SLOT_COUNT:
			var status := CompactCombatHud.spell_display_status(state, catalog.ability_from_wire(state.spell_wire_id(position + 1)))
			equal(status.casting, position == slot, "paid emphasis follows actual wire through all twelve positions")
			equal(status.waiting, position != slot, "all other positions retain shared commitment")
		for layer: int in 3:
			var hidden := CompactCombatHud.hidden_cast_status(state, catalog, layer, PlayerPreferences.new())
			equal(hidden.is_empty(), slot / PlayerState.SPELL_BUTTON_COUNT == layer, "layer changes retain the existing paid identity/binding cue")
		equal(state.canonical_values(), before, "all-slot presentation leaves authority byte values unchanged")
	for label: String in ["OTHER SPELLS WAIT", "SPELLS WAIT"]:
		check(ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x <= 346.0, "shared cue fits even beside the maximum-width rebound layer tab")


func _test_hidden_cast_status() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "hidden cast uses live catalog")
	var state := PlayerState.new()
	var preferences := PlayerPreferences.new()
	preferences.keyboard_bindings[&"spell_1"] = KEY_T
	preferences.keyboard_bindings[&"spell_layer_ctrl"] = KEY_SHIFT
	for element: String in AbilityCatalog.DISPLAY_ELEMENT_IDS:
		for family: String in AbilityCatalog.SPELL_MATRIX_FAMILIES:
			var ability: Dictionary = catalog.abilities_by_id[catalog.spell_id_at(element, family)]
			state.pending_cast_wire_id = int(ability.wire_id)
			state.pending_cast_ticks = 1
			for slot: int in PlayerState.SPELL_SLOT_COUNT:
				state.spell_wire_ids.fill(0)
				state.spell_wire_ids[slot] = state.pending_cast_wire_id
				var before := state.canonical_values()
				for layer: int in 3:
					var result := CompactCombatHud.hidden_cast_status(state, catalog, layer, preferences)
					if slot / PlayerState.SPELL_BUTTON_COUNT == layer:
						equal(result, {}, "visible paid cast needs no duplicate cue")
					else:
						equal(result.get("wire_id"), state.pending_cast_wire_id, "hidden cue identifies actual paid spell")
						equal(result.get("slot"), slot, "hidden cue identifies actual slot")
						equal(result.get("progress"), CompactCombatHud.spell_readiness(state, ability).progress, "hidden cue shares authoritative progress")
						equal(result.get("element"), ability.element, "hidden cue preserves element color identity")
					equal(state.canonical_values(), before, "hidden cue cannot change authority")
	state.spell_wire_ids.fill(0)
	state.spell_wire_ids[4] = state.pending_cast_wire_id
	check(String(CompactCombatHud.hidden_cast_status(state,catalog,0,preferences).label).ends_with("Shift+T"), "hidden chord respects remapping")
	preferences.keyboard_bindings[&"spell_layer_ctrl"] = 0
	check(String(CompactCombatHud.hidden_cast_status(state,catalog,0,preferences).label).ends_with("PAD LB+T"), "hidden chord retains the saved controller modifier when keyboard modifier is unbound")
	preferences.controller_bindings[&"spell_layer_ctrl"] = PlayerPreferences.unbound_controller_binding()
	check(String(CompactCombatHud.hidden_cast_status(state,catalog,0,preferences).label).ends_with("Not bound"), "hidden unbound chord is truthful")
	state.spell_wire_ids[0] = state.pending_cast_wire_id
	equal(CompactCombatHud.hidden_cast_status(state,catalog,0,preferences), {}, "duplicate visible fixture never adds redundant cue")
	state.spell_wire_ids.fill(0)
	equal(CompactCombatHud.hidden_cast_status(state,catalog,0,preferences).slot, -1, "legacy active cast has no fabricated binding")
	for ticks: int in [-10,0,10000]:
		state.pending_cast_ticks = ticks
		var result := CompactCombatHud.hidden_cast_status(state,catalog,0,preferences)
		check(float(result.progress) >= 0.0 and float(result.progress) <= 1.0, "outlying startup ticks cannot overrun cue")
	equal(CompactCombatHud.hidden_cast_status(state,catalog,0,preferences,60).progress, 0.0, "unsupported rate cannot advertise invented timing")
	state.health = 0
	equal(CompactCombatHud.hidden_cast_status(state,catalog,0,preferences), {}, "dead player has no paid cue")
	state.health = 1
	state.pending_cast_wire_id = 999999
	equal(CompactCombatHud.hidden_cast_status(state,catalog,0,preferences), {}, "unknown spell is not presented")
	state.pending_cast_wire_id = 0
	equal(CompactCombatHud.hidden_cast_status(state,catalog,0,preferences), {}, "cleared authoritative cast immediately removes cue")
	equal(CompactCombatHud.hidden_cast_status(null,catalog,0,preferences), {}, "null state safe")
	equal(CompactCombatHud.hidden_cast_status(state,null,0,preferences), {}, "null catalog safe")
	state.pending_cast_wire_id = 101
	for layer: int in [-1,3,100]:
		equal(CompactCombatHud.hidden_cast_status(state,catalog,layer,preferences), {}, "invalid visible layer has no misleading cue")


func _test_truthful_bindings() -> void:
	var preferences := PlayerPreferences.new()
	preferences.keyboard_bindings[&"spell_1"] = KEY_T
	preferences.keyboard_bindings[&"spell_layer_ctrl"] = KEY_SHIFT
	equal(CompactCombatHud.button_binding_label(0, preferences), "T", "HUD shows actual remapped spell key, not slot number")
	equal(CompactCombatHud.binding_layer_label(1, preferences), "Shift SPELLS", "HUD shows actual remapped layer modifier")
	preferences.keyboard_bindings[&"spell_1"] = 0
	equal(CompactCombatHud.button_binding_label(0, preferences), "PAD UP", "unbound keyboard spell still shows its saved controller input")
	preferences.controller_bindings[&"spell_1"] = PlayerPreferences.unbound_controller_binding()
	equal(CompactCombatHud.button_binding_label(0, preferences), "-", "spell unbound on every device never advertises a working input")
	equal(CompactCombatHud.button_binding_label(0, null), "?", "missing preferences are unknown, not default bindings")
	preferences.keyboard_bindings[&"spell_layer_ctrl"] = 0
	equal(CompactCombatHud.binding_layer_label(1, preferences), "PAD LB SPELLS", "layer shows saved controller modifier when keyboard is unbound")
	preferences.controller_bindings[&"spell_layer_ctrl"] = PlayerPreferences.unbound_controller_binding()
	equal(CompactCombatHud.binding_layer_label(1, preferences), "LAYER UNBOUND", "unbound layer is explicit")


func _test_quiet_authoritative_readiness() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "readiness uses the live catalog")
	var state := PlayerState.new()
	state.flux = state.flux_maximum
	for element: String in AbilityCatalog.DISPLAY_ELEMENT_IDS:
		for family: String in AbilityCatalog.SPELL_MATRIX_FAMILIES:
			var ability: Dictionary = catalog.abilities_by_id[catalog.spell_id_at(element, family)]
			var need := CombatSystem.cast_capacity_requirement(int(ability.wire_id))
			var ready := CompactCombatHud.spell_readiness(state, ability, 120, need)
			equal(ready.kind, "ready", "all 24 runtime catalog cells become ready at their exact offer")
			equal(ready.label, "", "ready cells do not repeat the same word four times")
			if need.x > 0 or need.y > 0:
				var short_offer := need - (Vector2i(1, 0) if need.x > 0 else Vector2i(0, 1))
				equal(CompactCombatHud.spell_readiness(state, ability, 120, short_offer).kind, "capacity", "readiness checks complete family capacity, not one projectile")
	var bolt: Dictionary = catalog.ability(catalog.spell_id_at("fire", "bolt"))
	check(not bolt.is_empty(), "canonical Bolt available for exact boundaries")
	state.flux = int(bolt.flux_cost) * 1000 - 1
	equal(CompactCombatHud.spell_readiness(state, bolt).kind, "flux", "one milli-Flux below cost cannot claim readiness")
	state.set_spell_cooldown(int(bolt.wire_id), 60)
	equal(CompactCombatHud.spell_readiness(state, bolt).kind, "cooldown", "cooldown precedes capacity and Flux just like admission")
	state.pending_cast_wire_id = int(bolt.wire_id)
	equal(CompactCombatHud.spell_readiness(state, bolt).label, "CASTING", "startup commitment is visible on the actual casting slot")
	state.pending_cast_wire_id = 0
	equal(CompactCombatHud.spell_readiness(state, bolt, 120, Vector2i(-1, -1), "control_stunned").kind, "control", "blocked control uses the authoritative caller gate")
	state.flux_recovery_delay_ticks = 84
	equal(CompactCombatHud.quiet_resource_label(state, "FLUX"), "FLUX", "routine recovery waits do not churn compact labels")
	state.chemistry_regen_block_ticks = 1
	equal(CompactCombatHud.quiet_resource_label(state, "FLUX"), "FLUX SEALED", "meaningful recovery denial remains explicit")
	equal(CompactCombatHud.protection_status(state), "", "ordinary movement never advertises invulnerability")
	state.spawn_protection_ticks = 1
	equal(CompactCombatHud.protection_status(state), "PROTECTED / SPAWN", "one remaining protected tick still has an exact cue")
	state.spawn_protection_ticks = 0
	state.air_floating = true
	state.flight_capable = true
	state.air_height = 40_000
	state.hop_ticks = 1
	state.float_ticks = 1
	state.stamina = 1000
	equal(CompactCombatHud.protection_status(state), "", "flight height does not advertise universal protection")
	state.chemistry_regen_block_ticks = 0
	state.float_ticks = 120
	equal(CompactCombatHud.quiet_resource_label(state, "STAMINA"), "STAMINA FLY 1.0s", "finite flight time stays visible without pointer inspection")
	state.stamina = 0
	equal(CompactCombatHud.protection_status(state), "", "exhaustion removes protection immediately without visual interpolation")
	state.spawn_protection_ticks = 1
	state.health = 0
	equal(CompactCombatHud.protection_status(state), "", "dead states never advertise protection")
	equal(CompactCombatHud.spell_readiness(state, bolt).kind, "unavailable", "dead actor cannot claim cast readiness")


func _test_paid_startup_progress() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "startup progress uses the live catalog")
	var config := SimConfig.new()
	var state := PlayerState.new()
	state.flux = 0 # Payment already happened; do not require the cost again.
	for element: String in AbilityCatalog.DISPLAY_ELEMENT_IDS:
		for family: String in AbilityCatalog.SPELL_MATRIX_FAMILIES:
			var ability := catalog.ability(catalog.spell_id_at(element, family))
			var wire := int(ability.wire_id)
			var total := config.milliseconds_to_ticks(int(ability.startup_ms))
			state.pending_cast_wire_id = wire
			for remaining: int in [total, floori(float(total) * 0.5), 1, 0, total + 1, -1]:
				state.pending_cast_ticks = remaining
				var before := state.canonical_values()
				var readiness := CompactCombatHud.spell_readiness(state, ability)
				var expected := clampf(1.0 - float(remaining) / float(maxi(1, total)), 0.0, 1.0)
				equal(readiness.kind, "startup", "paid startup remains startup until authority releases it")
				equal(readiness.label, "CASTING", "only the matching pending wire reports casting")
				check(is_equal_approx(float(readiness.progress), expected), "startup fill follows authoritative remaining ticks for %s/%s" % [element, family])
				equal(state.canonical_values(), before, "HUD startup sampling never changes paid player state")
	var bolt := catalog.ability(catalog.spell_id_at("fire", "bolt"))
	state.pending_cast_wire_id = int(bolt.wire_id)
	state.pending_cast_ticks = 1
	var other := catalog.ability(catalog.spell_id_at("water", "bolt"))
	check(not other.is_empty() and int(other.wire_id) != state.pending_cast_wire_id, "other-slot fixture uses a distinct current spell")
	equal(CompactCombatHud.spell_readiness(state, other), {"kind": "startup", "label": "FINISH CAST", "progress": 0.0}, "unrelated slots never borrow the active cast fill")
	for invalid_rate: int in [-1, 0, 60, 240]:
		equal(CompactCombatHud.spell_readiness(state, bolt, invalid_rate).progress, 0.0, "unsupported simulation rates cannot invent startup progress")
	var tiny := bolt.duplicate(true)
	tiny.startup_ms = 1
	state.pending_cast_ticks = config.milliseconds_to_ticks(1)
	equal(state.pending_cast_ticks, 1, "positive sub-tick startup quantizes to the authoritative minimum tick")
	equal(CompactCombatHud.spell_readiness(state, tiny).progress, 0.0, "minimum-tick startup begins empty")
	state.pending_cast_ticks = 0
	equal(CompactCombatHud.spell_readiness(state, tiny).progress, 1.0, "minimum-tick startup reaches full at its release boundary")
	tiny.startup_ms = 0
	equal(CompactCombatHud.spell_readiness(state, tiny), {"kind": "startup", "label": "CASTING", "progress": 1.0}, "zero-ms startup stays finite and full without falsely claiming a released cast")
	state.pending_cast_wire_id = 0
	equal(CompactCombatHud.spell_readiness(state, bolt, 120, Vector2i(-1, -1), "startup_commitment"), {"kind": "startup", "label": "FINISH CAST", "progress": 0.0}, "gate-only commitment cannot fabricate a matching paid cast")
	state.set_spell_cooldown(int(bolt.wire_id), config.milliseconds_to_ticks(int(bolt.cooldown_ms)))
	var released := CompactCombatHud.spell_readiness(state, bolt)
	equal(released.kind, "cooldown", "authoritative release switches the existing track back to cooldown")
	equal(released.progress, 0.0, "fresh cooldown does not retain a full startup track")
	state.set_spell_cooldown(int(bolt.wire_id), 0)
	equal(CompactCombatHud.spell_readiness(state, bolt).kind, "flux", "after release the next unpaid cast still requires its own Flux")


func _test_compact_practice_card() -> void:
	var view := {"kind": "reaction", "title": "STEAM", "phase": "ACTIVE", "lines": PackedStringArray(["Fire + Water", "Conceals distant silhouettes; no damage.", "Counter: Radiance reveals."])}
	var original := view.duplicate(true)
	var quiet := PracticeCoachCard.model(view, Vector2(1280, 720), Vector2.ZERO)
	equal(quiet.lines, PackedStringArray(["Conceals distant silhouettes; no damage."]), "quiet reaction coach leads with actual effect")
	equal(quiet.panel.size.y, 82.0, "quiet coach uses one brief line instead of a three-line panel")
	var expanded := PracticeCoachCard.model(view, Vector2(1280, 720), quiet.panel.position + Vector2(10, 10))
	equal(expanded.lines.size(), 3, "pointer inspection reveals recipe, effect and counter")
	equal(view, original, "presentation never rewrites source teaching")
	view.kind = "float"
	equal(PracticeCoachCard.model(view, Vector2(1280, 720), Vector2.ZERO).lines[0], "Fire + Water", "movement views preserve their binding-first instruction")
	check(PracticeCoachCard.model({}, Vector2(1280, 720), Vector2.ZERO).is_empty(), "missing practice observation stays quiet")


func _test_shared_top_third_portraits() -> void:
	var hud := CompactCombatHud.new()
	check(hud.portrait_source("oh_tipi").is_empty(), "HUD without art does not invent a portrait")
	var language := VisualLanguage.new()
	check(language.load_from_file(), "portrait consumer language loads")
	var art := CartoonChampionPresenter.new()
	check(art.configure(language), "portrait consumers use all currently admitted pages")
	hud.champion_art = art
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "portrait Gallery ability dependency loads")
	var champions := ChampionCatalog.new()
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "portrait Gallery current roster loads")
	var roster := ChampionRosterPlan.new()
	check(roster.load_from_files(), "portrait Gallery roster plan loads")
	var gallery := preload("res://src/presentation/character_selection_grid.gd").new()
	check(gallery.configure(champions, roster, art), "Gallery borrows the same portrait presenter as the HUD")
	var body_types: Dictionary = {}
	for champion_id: String in art.champions:
		var frame := hud.portrait_source(champion_id)
		var gallery_frame: Dictionary = gallery.portrait_source(champion_id)
		equal(frame["texture"], gallery_frame["texture"], "HUD and Gallery share the exact cached top-third pixels for " + champion_id)
		equal(frame["region"], Rect2(0, 0, 32, 32), "HUD draws the compact padded crop, never a distorted atlas rectangle")
		var occupied: Rect2 = frame["occupied_model_region"]
		equal(frame["source_region"], Rect2(occupied.position, Vector2(occupied.size.x, ceilf(occupied.size.y / 3.0))), "both UI consumers show the whole width of the upper anatomical third")
		body_types[art.champions[champion_id]["body_type"]] = true
		if art.wireframe_mode:
			equal(frame.get("visual_mode"), "wireframe_body", "HUD and Gallery identify the active skeleton mode")
			equal(frame.get("body_type"), art.champions[champion_id]["body_type"], "shared portrait belongs to the selected identity's size")
			equal(frame.get("template_source_id"), "", "neutral portrait never borrows another named character's identity")
			check(frame.get("temporary_body_template", false), "neutral size template is clearly labeled before later detailed skins")
		elif champion_id in art.override_page_ids:
			check(frame.get("complete_page_override", false), "HUD can display accepted art before that actor enters the world")
		else:
			var source_id := String(art.champions[champion_id].get("template_source_id", ""))
			if not source_id.is_empty():
				check(frame.get("temporary_body_template", false), "unpromoted alias portraits retain honest template labels")
				equal(frame.get("template_source_id"), source_id, "portrait sharing does not change character identity")
	for body: String in ["small", "middle", "large"]:
		check(body_types.has(body), "portrait consumers cover body size " + body)
	equal(art.override_resident_count(), 0, "all HUD and Gallery portrait reads leave the max-eight world-page cache empty")
	equal(art.MAX_RESIDENT_OVERRIDE_PAGES, 8, "portrait refinement preserves the world-page admission bound")
	check(hud.portrait_source("unknown").is_empty(), "HUD unknown art fails closed")


func _test_spell_family_labels() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "HUD family labels use the validated current catalog")
	var expected_labels: Array[String] = ["BOLT", "HEAVY", "RAPID", "SPRAY", "MANTLE", "FUSE", "SPLIT", "REBOUND"]
	for element: String in AbilityCatalog.DISPLAY_ELEMENT_IDS:
		for index: int in range(AbilityCatalog.SPELL_MATRIX_FAMILIES.size()):
			var id := catalog.spell_id_at(element, AbilityCatalog.SPELL_MATRIX_FAMILIES[index])
			var ability: Dictionary = catalog.abilities_by_id[id]
			var label := CompactCombatHud.spell_summary_label(ability)
			equal(label, "%s · %d F" % [expected_labels[index], int(ability["flux_cost"])], "hotbar differentiates every family without changing displayed Flux cost")
			check(ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x <= 102.0, "larger family and price fit beside the glyph in the 142px hotbar cell")
			var header := CompactCombatHud.spell_header_label(ability)
			equal(header, "AIR" if element == "wind" else element.to_upper(), "live hotbar names the element explicitly instead of clipping a fantasy name")
			check(ThemeDB.fallback_font.get_string_size(header, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x <= 102.0, "larger element heading fits beside the keycap")
	equal(CompactCombatHud.spell_header_label({}), "EMPTY", "empty slot remains explicit without overlapping its glyph")
	equal(CompactCombatHud.spell_summary_label(catalog.ability_from_wire(179)), "HEAVY · 20 F", "heavy shell is recognizable from the hotbar")
	equal(CompactCombatHud.spell_summary_label(catalog.ability_from_wire(180)), "RAPID · 2 F", "rapid stream is recognizable from the hotbar")
	equal(CompactCombatHud.spell_summary_label(catalog.ability_from_wire(141)), "SPRAY · 16 F", "spray cone is recognizable from the hotbar")
	equal(CompactCombatHud.spell_summary_label(catalog.ability_from_wire(110)), "DISABLED", "catalog-only Vector Lance cannot resemble a live hotbar spell")
	equal(CompactCombatHud.spell_summary_label({}), "DISABLED", "missing family metadata fails closed")


func _text_bounds(font: Font, value: String, at: Vector2, size: int) -> Rect2:
	return Rect2(at - Vector2(0, font.get_ascent(size)), Vector2(font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x, font.get_ascent(size) + font.get_descent(size)))


func _test_all_payload_card_layouts() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "all504 HUD cards use the actual validated catalog")
	var font := ThemeDB.fallback_font
	var card_rect := Rect2(23, 41, 142, 70)
	var authored: Variant = JSON.parse_string(FileAccess.get_file_as_string(MixtureCatalog.PATH))
	var names := {}
	for row: Dictionary in authored.mixtures: names[int(row.element_mask)] = String(row.display_name)
	var state := PlayerState.new(1)
	state.champion_wire_id = 0
	var seen := {}
	for mask: int in range(1,64):
		for family: String in ["bolt", "heavy", "rapid", "spray", "mantle", "fuse", "split", "rebound"]:
			var wire := MixtureCatalog.wire_for(mask, family)
			var ability := catalog.ability_from_wire(wire)
			var original := ability.duplicate(true)
			var mixed := (mask & (mask - 1)) != 0
			var expected := String(names[mask]) if mixed else ("AIR" if String(ability.element) == "wind" else String(ability.element).to_upper())
			for binding: String in ["1", "MOUSE X1", "PAD R2+"]:
				var model := CompactCombatHud.spell_card_model(ability, binding, card_rect, font)
				equal(model.wire_id, wire, "card retains its actual stable spell identity")
				equal(model.element_mask, mask, "card cannot substitute its representative palette for the payload")
				equal(model.header, expected, "complete authored payload name is preserved; original singleton headers stay unchanged")
				equal(model.summary, "%s · %d F" % [family.to_upper(), int(ability.flux_cost)], "all8 families show their actual authored positive cost")
				check(int(ability.flux_cost) > 0 and model.summary != "DISABLED", "every live504 card remains enabled without implying free casting")
				equal(model.key_label, binding, "wider mouse/controller binding remains explicit")
				check(card_rect.encloses(model.key_box) and card_rect.encloses(model.track), "binding and timing track remain inside the142x70 card")
				var key_bounds := _text_bounds(font,binding,model.key_at,10)
				check(model.key_box.encloses(key_bounds), "actual binding glyphs fit their keycap")
				var lines := PackedStringArray()
				var heading_bounds: Array[Rect2] = []
				for heading: Dictionary in model.headings:
					lines.append(String(heading.text))
					var bounds := _text_bounds(font,heading.text,heading.at,12)
					check(bounds.size.x <= float(heading.width), "complete payload line fits actual12px font without truncation")
					check(card_rect.encloses(bounds), "actual payload glyph height stays inside card")
					check(not bounds.intersects(model.key_box), "payload name never overlaps the saved binding")
					for prior: Rect2 in heading_bounds: check(not prior.intersects(bounds), "two payload lines have distinct actual font bounds")
					heading_bounds.append(bounds)
				equal(" ".join(lines), expected, "wrapped heading reconstructs every word without abbreviation or clipping")
				check(lines.size() >= 1 and lines.size() <= 2, "payload uses at most two heading lines")
				var summary_bounds := _text_bounds(font,model.summary,model.summary_at,10)
				check(summary_bounds.size.x <= float(model.summary_width) and card_rect.encloses(summary_bounds), "actual family and cost fit their reserved row")
				for title_bounds: Rect2 in heading_bounds: check(not title_bounds.intersects(summary_bounds), "full payload name remains separate from family/cost")
				for label: String in ["CASTING", "0.5s", "MATERIAL LIMIT", "NEED %d F" % int(ability.flux_cost)]:
					var bounds := _text_bounds(font,label,model.status_at,10)
					check(bounds.size.x <= float(model.status_width) and card_rect.encloses(bounds), "startup/cooldown/refusal labels retain actual-font space")
					check(not bounds.intersects(summary_bounds) and not bounds.intersects(model.track), "timing/refusal text does not collide with family or timing bar")
				equal(ability, original, "layout reads catalog data without mutation")
			state.pending_cast_wire_id = wire
			state.pending_cast_ticks = 1
			var actor_before := state.canonical_values()
			var paid := CompactCombatHud.spell_display_status(state,ability)
			equal(paid.label,"CASTING","every payload/family can still display its actual paid preparation")
			equal(state.canonical_values(),actor_before,"identity layout and status cannot advance paid authority")
			seen[wire] = true
			state.pending_cast_wire_id = 0
	equal(seen.size(),504,"actual-font matrix covers every distinct live spell")
	for wire: int in [101,170,171,167,110]:
		equal(CompactCombatHud.spell_summary_label(catalog.ability_from_wire(wire)),"DISABLED","retired/candidate identities remain explicitly disabled")
	var convergence := catalog.ability_from_wire(MixtureCatalog.wire_for(63,"mantle"))
	equal(CompactCombatHud.spell_header_label(convergence),"Convergence","native fullsix Mantle regression cannot say WATER")
	equal(CompactCombatHud.spell_summary_label(convergence),"MANTLE · 28 F","native fullsix Mantle regression cannot say DISABLED")


func _test_withered_recovery_labels() -> void:
	var state := PlayerState.new(1)
	state.champion_wire_id = 0
	state.spawn_protection_ticks = 0
	state.health = 54_000
	state.flux = 50_000
	state.stamina = 50_000
	state.health_recovery_delay_ticks = 0
	state.flux_recovery_delay_ticks = 0
	state.stamina_recovery_delay_ticks = 0
	var config := SimConfig.new(120)
	var health_before := state.health
	check(PlayerResourcesSystem.damage(state,4000,config),"finite Dark impact causes actual Health loss before its status")
	SpellStatusPolicy.apply_hit(state,142,700,2,2,health_before-state.health,config,Vector2i.ZERO)
	state.health_recovery_delay_ticks = 0 # Isolate the otherwise-ready recovery gate.
	check(SpellStatusPolicy.active(state,5),"real successful Dark hit admits Withered")
	var before := state.canonical_values()
	equal(CompactCombatHud.quiet_resource_label(state,"HEALTH"),"HEALTH SEALED","Withered is explicit on the actual Health bar")
	equal(CompactCombatHud.quiet_resource_label(state,"FLUX"),"FLUX SEALED","Withered is explicit on the actual Flux bar")
	equal(CompactCombatHud.flux_status_label(state,120),"FLUX SEALED","inspection cannot claim a blocked Flux recovery rate")
	equal(CompactCombatHud.quiet_resource_label(state,"STAMINA"),"STAMINA","Withered cannot claim an unrelated Stamina seal")
	equal(state.canonical_values(),before,"reading recovery labels cannot consume or prolong a status")
	PlayerResourcesSystem.step(state,config)
	equal(state.health,50_000,"same real status actually blocks ready Health restoration")
	equal(state.flux,50_000,"same real status actually blocks ready Flux restoration")
	var stamina_before := state.stamina
	MovementSystem.step(state,SimCommand.new(0,state.entity_id),config,CollisionWorld.new())
	check(state.stamina > stamina_before,"Withered still permits otherwise ready grounded Stamina recovery")
	var events: Array[Dictionary] = []
	for unused: int in 120: SpellStatusPolicy.advance(state,config,events,false)
	check(not SpellStatusPolicy.active(state,5),"finite real Withered window expires")
	equal(CompactCombatHud.quiet_resource_label(state,"HEALTH"),"HEALTH","expiry removes Health seal immediately")
	equal(CompactCombatHud.quiet_resource_label(state,"FLUX"),"FLUX","expiry removes Flux seal immediately")
	PlayerResourcesSystem.step(state,config)
	check(state.health > 50_000 and state.flux > 50_000,"actual restoration resumes after the displayed seal ends")
	state.chemistry_regen_block_ticks = 2
	for resource: String in ["HEALTH","FLUX","STAMINA"]:
		equal(CompactCombatHud.quiet_resource_label(state,resource),resource+" SEALED","terrain recovery denial retains its distinct three-resource scope")
	state.chemistry_regen_block_ticks = 0
	state.spawn_protection_ticks = 2
	SpellStatusPolicy.apply_hit(state,142,701,2,2,4000,config,Vector2i.ZERO)
	equal(CompactCombatHud.quiet_resource_label(state,"FLUX"),"FLUX","protected hit cannot fabricate a Withered seal")


func _test_repository_hud() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "visual language loads for compact HUD")
	var hud := CompactCombatHud.new()
	check(hud.configure(language), "compact HUD validates: %s" % hud.last_error)
	check(hud.content_hash.length() == 64, "compact HUD has a stable content hash")
	var layout: Dictionary = hud.data.get("layout", {})
	equal(int(layout.get("spell_cell_width", 0)) * PlayerState.SPELL_BUTTON_COUNT + int(layout.get("spell_cell_gap", 0)) * 3, 586, "HUD declares exactly four compact spell cells")
	equal(int(layout.get("panel_corner_step", 0)), language.ui_metric("corner_step"), "HUD framing follows the shared stepped-corner token")
	check(int(hud.data.get("maximum_view_coverage_percent", 0)) <= int((language.data.get("budgets", {}) as Dictionary).get("maximum_combat_hud_coverage_percent", 0)), "HUD coverage stays inside the visual budget")
	var state := PlayerState.new()
	equal(CompactCombatHud.flux_status_label(state, 120), "FLUX", "full Flux keeps the quiet canonical label")
	state.flux -= 10_000
	state.flux_recovery_delay_ticks = 84
	equal(CompactCombatHud.flux_status_label(state, 120), "FLUX WAIT 0.7s", "combat delay is visible in the compact HUD")
	state.flux_recovery_delay_ticks = 0
	equal(CompactCombatHud.flux_status_label(state, 120), "FLUX +20/s", "active Flux recovery shows its current rate in the compact HUD")
	state.flux = 5_999
	check(not CompactCombatHud.spell_is_affordable(state, {"flux_cost": 6}), "HUD compares authored whole-Flux cost against milli-unit state")
	state.flux = 6_000
	check(CompactCombatHud.spell_is_affordable(state, {"flux_cost": 6}), "HUD affordability becomes ready at the exact milli-unit boundary")
	state = PlayerState.new()
	equal(CompactCombatHud.stamina_status_label(state, 120), "STAMINA", "neutral Stamina keeps the compact label")
	state.jumpsquat_active = true
	equal(CompactCombatHud.stamina_status_label(state, 120), "STAMINA RELEASE TO JUMP", "ground preparation teaches release without invented sustain drain")
	state.jumpsquat_active = false
	state.hop_ticks = SimConfig.new(120).milliseconds_to_ticks(MovementTuning.VARIABLE_JUMP_MINIMUM_MS) + 1
	state.air_height = 20_000
	state.air_vertical_velocity = 500_000
	state.jump_held_last_tick = true
	equal(CompactCombatHud.stamina_status_label(state, 120), "STAMINA", "ordinary held airborne Jump does not invent retired sustain spending")
	state.jump_held_last_tick = false
	equal(CompactCombatHud.stamina_status_label(state, 120), "STAMINA", "tap jump does not claim a sustain drain")
	state.jump_held_last_tick = true
	state.air_vertical_velocity = -300_000
	equal(CompactCombatHud.stamina_status_label(state, 120), "STAMINA", "descent never advertises the retired timer-derived jump drain")
	state.air_vertical_velocity = 500_000
	state.air_dodge_ticks = 10
	equal(CompactCombatHud.stamina_status_label(state, 120), "STAMINA", "air dodge does not advertise jump sustain")
	state.air_dodge_ticks = 0
	state.wall_skim_ticks = 10
	equal(CompactCombatHud.stamina_status_label(state, 120), "STAMINA", "wall attachment does not advertise jump sustain")
	state.wall_skim_ticks = 0
	state.control_state = PlayerState.ControlState.STUNNED
	equal(CompactCombatHud.stamina_status_label(state, 120), "STAMINA", "forced control cannot claim optional sustain spending")
	state.control_state = PlayerState.ControlState.FREE
	state.stamina = 0
	equal(CompactCombatHud.stamina_status_label(state, 120), "STAMINA", "exhausted jump does not advertise an unaffordable drain")
	state.stamina = state.stamina_maximum
	state.air_height = 0
	state.air_vertical_velocity = 0
	state.hop_ticks = 0
	state.slide_ticks = SimConfig.new(120).milliseconds_to_ticks(MovementTuning.SLIDE_MINIMUM_MS) + 1
	state.slide_held_last_tick = true
	equal(CompactCombatHud.stamina_status_label(state, 120), "STAMINA  SLIDE -45/s", "paid slide sustain is explicit without relying on color")
	state.slide_ticks = 0
	state.movement_chain_count = 2
	state.movement_chain_reset_ticks = 20
	equal(CompactCombatHud.stamina_status_label(state, 120), "STAMINA  NEXT +20%", "active movement-chain escalation is explicit without relying on color")


func _test_fail_closed_contract() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "visual language loads before compact HUD mutation")
	var source := CompactCombatHud.new()
	check(source.configure(language), "valid compact HUD loads before mutation")
	var hud := CompactCombatHud.new()
	hud.language = language
	hud.data = source.data.duplicate(true)
	(hud.data["layout"] as Dictionary)["spell_cell_width"] = 500
	check(not hud.validate(), "oversized compact HUD cell fails closed")
	check(not hud.last_error.is_empty(), "compact HUD failure is actionable")


func _test_recovery_and_float_status() -> void:
	var state := PlayerState.new()
	state.flux -= 10_000
	state.stamina -= 10_000
	state.flux_recovery_idle_ticks = 360
	state.stamina_recovery_idle_ticks = 180
	equal(CompactCombatHud.flux_status_label(state, 120), "FLUX +60/s", "Flux label displays its fully ramped independent rate")
	equal(CompactCombatHud.stamina_status_label(state, 120), "STAMINA +54/s", "Stamina label uses its own halfway-ramped rate")
	state.stamina_recovery_delay_ticks = 46
	equal(CompactCombatHud.stamina_status_label(state, 120), "STAMINA WAIT 0.4s", "Stamina spend delay is distinct from actual recovering")
	state.stamina_recovery_delay_ticks = 0
	state.air_height = 40_000
	state.hop_ticks = 25
	equal(CompactCombatHud.stamina_status_label(state, 120), "STAMINA", "quiet airborne state cannot falsely advertise active ground refill")
	state.air_floating = true
	state.flight_capable = true
	state.float_ticks = 216
	equal(CompactCombatHud.stamina_status_label(state, 120), "STAMINA FLY 1.8s -100/s", "paid Float shows remaining size-limited duration and drain")
	state.float_ticks = 0
	check(not CompactCombatHud.stamina_status_label(state, 120).contains("FLY"), "expired Float cannot advertise flight spending")
	state.float_ticks = 216
	state.air_floating = false
	equal(CompactCombatHud.stamina_status_label(state, 120), "STAMINA", "ending Float removes its paid status immediately")
	state.air_floating = true
	state.flight_capable = true
	state.control_state = PlayerState.ControlState.STUNNED
	check(not CompactCombatHud.stamina_status_label(state, 120).contains("FLY"), "forced control cannot advertise an active Float")
	state.control_state = PlayerState.ControlState.FREE
	state.stamina = 0
	check(not CompactCombatHud.stamina_status_label(state, 120).contains("FLY"), "exhaustion cannot advertise flight spending")
	# Check the unchanged recovery labels before their hover-only presentation.
	state.air_floating = false
	state.air_height = 0
	state.chemistry_regen_block_ticks = 10
	equal(CompactCombatHud.flux_status_label(state, 120), "FLUX SEALED", "chemistry-blocked Flux never falsely promises recovery")
	equal(CompactCombatHud.stamina_status_label(state, 120), "STAMINA SEALED", "chemistry-blocked Stamina never falsely promises recovery")
	var labels: Array[String] = ["FLUX +150/s", "STAMINA +150/s", "STAMINA FLY 2.4s -100/s", "STAMINA RELEASE TO JUMP", "STAMINA  SLIDE -45/s", "STAMINA SPRINT -34/s", "STAMINA WAIT 0.4s", "STAMINA  NEXT +40%"]
	for label: String in labels:
		var measured := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		check(measured <= 250.0, label + " fits the 270px hover panel without shrinking text or competing with amounts")


func _test_resource_bar_readability() -> void:
	equal(CompactCombatHud.resource_amount_label(0, 108_000), "0/108", "empty resource remains explicit")
	equal(CompactCombatHud.resource_amount_label(1, 108_000), "<1/108", "one positive milli-unit is distinct from empty without promising a whole point")
	equal(CompactCombatHud.resource_amount_label(999, 108_999), "<1/108", "positive fractional quantity is explicit while the maximum retains whole-unit truncation")
	equal(CompactCombatHud.resource_amount_label(1000, 108_000), "1/108", "whole-unit boundary is unchanged")
	equal(CompactCombatHud.resource_amount_label(107_999, 108_000), "107/108", "nearly full resource does not round up")
	equal(CompactCombatHud.resource_amount_label(108_000, 108_000), "108/108", "full resource keeps the exact whole-unit amount")
	equal(CompactCombatHud.resource_amount_label(109_000, 108_000), "109/108", "presentation does not silently clamp an over-maximum source quantity")
	equal(CompactCombatHud.resource_amount_label(792_999, 800_000), "792/800", "three-digit current and maximum remain exact whole units")
	equal(CompactCombatHud.resource_amount_label(-1000, 0), "-1/0", "presentation does not silently clamp source quantities")
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "resource readability uses the current ability catalog")
	var champions := ChampionCatalog.new()
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "resource readability covers the current roster")
	for champion_id: String in champions.champions_by_id:
		var stats: Dictionary = champions.champions_by_id[champion_id]["stats"]
		for resource: String in ["HEALTH", "FLUX", "STAMINA"]:
			var maximum := int(stats[resource.to_lower() + "_maximum"])
			var labels: Array[String] = [resource]
			labels.append(resource + " SEALED")
			if resource == "STAMINA":
				labels.append("STAMINA FLY 2.4s")
			for value: int in [0, 1, 999, 1000, maximum]:
				var amount := CompactCombatHud.resource_amount_label(value, maximum)
				var amount_width := ThemeDB.fallback_font.get_string_size(amount, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
				for label: String in labels:
					var label_width := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
					check(label_width + amount_width + 8.0 <= 192.0, "%s %s and %s fit the real 204px bar with an eight-pixel gap" % [champion_id, label, amount])
	# Include the schema maximum, even if no current champion happens to use it.
	var largest_amount := CompactCombatHud.resource_amount_label(ChampionCatalog.STAT_BOUNDS.stamina_maximum.y, ChampionCatalog.STAT_BOUNDS.stamina_maximum.y)
	var largest_amount_width := ThemeDB.fallback_font.get_string_size(largest_amount, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	for label: String in ["STAMINA SEALED", "STAMINA FLY 2.4s"]:
		check(ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + largest_amount_width + 8.0 <= 192.0, "schema-bounded long status fits beside the largest amount")


func _test_fractional_resource_transitions() -> void:
	var config := SimConfig.new(120)
	var state := PlayerState.new()
	# Fire Bolt's live 10-Health impact divides the full 100-Health reserve,
	# so only ordinary recovery can create the final fractional remainder.
	var hit_damage := int(CombatTuning.cast_definition(CombatTuning.CINDERBOLT_WIRE_ID).get("damage", 0))
	equal(hit_damage, 10_000, "fractional Health fixture uses Fire Bolt's actual live damage")
	if hit_damage <= 0: return
	for unused: int in (state.health - 1) / hit_damage:
		check(PlayerResourcesSystem.damage(state, hit_damage, config), "live damage leaves the last whole-hit reserve")
	equal(state.health, hit_damage, "current live damage reaches one hit of remaining Health")
	# Let ordinary delayed recovery add one sub-point tick, then take the same
	# real hit again. No fixture writes a fabricated fractional Health value.
	for unused: int in config.milliseconds_to_ticks(PlayerTuning.HEALTH_RECOVERY_DELAY_MS):
		PlayerResourcesSystem.step(state, config)
	check(PlayerResourcesSystem.damage(state, hit_damage, config), "same real hit lands after ordinary recovery begins")
	equal(state.health, 16, "the first ordinary recovery tick leaves exactly sixteen milli-Health after the real hit")
	check(state.health > 0 and state.health < 1000, "real damage and recovery leave a living sub-point Health reserve")
	var before := state.canonical_values()
	equal(CompactCombatHud.resource_amount_label(state.health, state.health_maximum), "<1/100", "living low Health never displays defeated zero")
	equal(state.canonical_values(), before, "fractional Health display never alters damage or recovery authority")
	check(PlayerResourcesSystem.damage(state, hit_damage, config), "next actual hit exhausts the remaining Health")
	equal(CompactCombatHud.resource_amount_label(state.health, state.health_maximum), "0/100", "real defeat switches immediately to exact zero")

	state = PlayerState.new()
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "fractional Flux uses current paid Rapid cost")
	var rapid := catalog.ability(catalog.spell_id_at("water", "rapid"))
	var cost := int(rapid.get("flux_cost", 0)) * 1000
	check(cost > 0, "fractional Flux fixture has a positive live price")
	if cost <= 0: return
	for unused: int in state.flux / cost:
		check(PlayerResourcesSystem.spend_flux(state, cost, config), "repeated live-priced payments exhaust Flux")
	equal(state.flux, 0, "live Rapid price reaches genuinely empty Flux")
	equal(CompactCombatHud.resource_amount_label(state.flux, state.flux_maximum), "0/100", "empty Flux remains distinct from recovering fractions")
	for unused: int in config.milliseconds_to_ticks(PlayerTuning.FLUX_RECOVERY_DELAY_MS):
		PlayerResourcesSystem.step(state, config)
	check(state.flux > 0 and state.flux < 1000, "ordinary recovery produces positive sub-point Flux")
	before = state.canonical_values()
	equal(CompactCombatHud.resource_amount_label(state.flux, state.flux_maximum), "<1/100", "first recovery tick is visible without rounding up to a spendable point")
	equal(CompactCombatHud.spell_readiness(state, rapid).kind, "flux", "fractional display does not advertise an unaffordable spell as ready")
	equal(state.canonical_values(), before, "fractional amount and readiness leave exact Flux authority unchanged")

	state = _jump_fixture()
	var collision := CollisionWorld.new(4_000_000, 4_000_000)
	for tick: int in config.tick_rate * 30:
		if state.stamina < 1000: break
		MovementSystem.step(state, SimCommand.new(tick, state.entity_id, 1000, 0, SimCommand.HELD_SPRINT), config, collision)
	check(state.stamina > 0 and state.stamina < 1000, "ordinary sustained sprint reaches a positive sub-point Stamina reserve")
	before = state.canonical_values()
	equal(CompactCombatHud.resource_amount_label(state.stamina, state.stamina_maximum), "<1/%d" % (state.stamina_maximum / 1000), "live sprint spending is not mislabeled as completely exhausted")
	equal(state.canonical_values(), before, "fractional Stamina display cannot change paid movement")


func _test_resource_inspection_panel() -> void:
	equal(CompactCombatHud.resource_detail_lines(null, 120), PackedStringArray(), "missing state does not create inspection copy")
	var state := PlayerState.new()
	equal(CompactCombatHud.resource_detail_lines(state, 120), PackedStringArray(), "full neutral resources do not add a redundant hover panel")
	state.flux -= 10_000
	state.stamina -= 10_000
	state.flux_recovery_idle_ticks = 360
	state.stamina_recovery_idle_ticks = 180
	var before := state.canonical_values()
	equal(CompactCombatHud.resource_detail_lines(state, 120), PackedStringArray(["FLUX +60/s", "STAMINA +54/s"]), "inspection preserves each independent existing recovery rate")
	equal(state.canonical_values(), before, "resource inspection never mutates authority")
	state.chemistry_regen_block_ticks = 10
	equal(CompactCombatHud.resource_detail_lines(state, 120), PackedStringArray(), "SEALED stays on the bars without redundant inspection text")
	state.flux_recovery_delay_ticks = 84
	equal(CompactCombatHud.resource_detail_lines(state, 120), PackedStringArray(["FLUX WAIT 0.7s"]), "existing Flux delay precedence survives while the quiet SEALED cue remains visible")
	state.flux_recovery_delay_ticks = 0
	state.chemistry_regen_block_ticks = 0
	state.flux = state.flux_maximum
	state.air_height = 40_000
	state.hop_ticks = 25
	state.air_floating = true
	state.flight_capable = true
	state.float_ticks = 216
	equal(CompactCombatHud.quiet_resource_label(state, "STAMINA"), "STAMINA FLY 1.8s", "remaining flight time is always visible")
	equal(CompactCombatHud.resource_detail_lines(state, 120), PackedStringArray(["STAMINA FLY 1.8s -100/s"]), "hover retains the exact paid flight drain")
	state.control_state = PlayerState.ControlState.STUNNED
	equal(CompactCombatHud.resource_detail_lines(state, 120), PackedStringArray(), "forced control cannot invent an inspection drain")
	state.health = 0
	equal(CompactCombatHud.resource_detail_lines(state, 120), PackedStringArray(), "dead resources cannot claim recovery")
	# These are logical canvas sizes after the caller's existing UI scaling,
	# including 1920x1080 / 1.5 and the smaller supported window presentation.
	for viewport_size: Vector2 in [Vector2(1280, 720), Vector2(1600, 900), Vector2(960, 540)]:
		var resources := Rect2(16, viewport_size.y - 134, 270, 118)
		var spell_row_and_cues := Rect2(viewport_size.x - 602, viewport_size.y - 110, 586, 94)
		for line_count: int in [1, 2]:
			var panel := CompactCombatHud.resource_detail_panel(resources, viewport_size, line_count)
			check(panel.has_area(), "inspection fits the current logical canvas")
			check(Rect2(Vector2.ZERO, viewport_size).encloses(panel), "inspection never escapes logical canvas bounds")
			equal(panel.size, Vector2(270, 12 + line_count * 16), "inspection uses only the required one or two lines")
			equal(panel.end.y, resources.position.y - 6.0, "inspection is separated above resource bars")
			check(not panel.intersects(spell_row_and_cues), "inspection cannot obscure the hotbar or its casting/layer cues")
		check(not CompactCombatHud.resource_detail_panel(resources, viewport_size, 0).has_area(), "no extra information means no panel")
	check(not CompactCombatHud.resource_detail_panel(Rect2(16, 20, 270, 118), Vector2(320, 180), 2).has_area(), "a canvas with no room above resources cannot draw clipped inspection content")


func _jump_fixture() -> PlayerState:
	var state := PlayerState.new(1)
	state.position_x = 2_000_000
	state.position_y = 2_000_000
	state.stamina_recovery_per_second = 0
	return state


func _jump_step(state: PlayerState, held: int = 0, pressed: int = 0, move_x: int = 0) -> void:
	MovementSystem.step(state, SimCommand.new(0, state.entity_id, move_x, 0, held, pressed), SimConfig.new(120), CollisionWorld.new(4_000_000, 4_000_000))


func _test_jump_preparation_lifecycle() -> void:
	var config := SimConfig.new(120)
	var maximum := config.milliseconds_to_ticks(MovementTuning.JUMPSQUAT_CHARGE_MS)
	for held_ticks: int in [0, maximum / 2, maximum, maximum + 20]:
		var state := _jump_fixture()
		var reserve := state.stamina
		_jump_step(state, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
		check(state.jumpsquat_active, "real held press admits grounded preparation")
		equal(CompactCombatHud.jump_preparation_status(state).progress, 0.0, "new preparation starts with no invented charge")
		for unused: int in held_ticks:
			_jump_step(state, SimCommand.HELD_JUMP)
		var before := state.canonical_values()
		var view := CompactCombatHud.jump_preparation_status(state)
		equal(view.progress, minf(1.0, float(held_ticks) / float(maximum)), "visible charge follows accepted ticks and saturates at the real limit")
		equal(view.title, "JUMP FULL" if held_ticks >= maximum else "JUMP CHARGE", "full-charge text starts only at the authored limit")
		equal(view.kind, "ready", "funded ordinary preparation can be released")
		equal(view.cost, MovementTuning.HOP_COST, "ordinary preparation exposes the actual release price")
		equal(state.canonical_values(), before, "reading the renderer model never advances or spends authority")
		equal(state.stamina, reserve, "holding preparation has no invented hidden payment")
		_jump_step(state)
		check(state.is_airborne() and not state.jumpsquat_active, "real release launches the prepared jump")
		equal(state.stamina, reserve - MovementTuning.HOP_COST, "release pays precisely the displayed cost")
		equal(CompactCombatHud.jump_preparation_status(state), {}, "release immediately removes preparation UI")
	var tap := _jump_fixture()
	_jump_step(tap, 0, SimCommand.PRESSED_JUMP)
	check(tap.is_airborne(), "same-command quick tap still launches")
	check(CompactCombatHud.jump_preparation_status(tap).is_empty(), "instant tap never leaves a stale charge panel")
	var slide := _jump_fixture()
	slide.velocity_x = MovementTuning.BASE_SPEED
	_jump_step(slide, SimCommand.HELD_SLIDE, SimCommand.PRESSED_SLIDE, 1000)
	for unused: int in 8:
		_jump_step(slide, SimCommand.HELD_SLIDE, 0, 1000)
	_jump_step(slide, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
	check(slide.jumpsquat_active and slide.hop_mode == PlayerState.MovementMode.SLIDE_JUMP, "real slide-to-hold retains its prepared family")
	for unused: int in 20:
		_jump_step(slide, SimCommand.HELD_JUMP)
	equal(slide.slide_ticks, 0, "fixture lets the slide timer expire during charge")
	var slide_view := CompactCombatHud.jump_preparation_status(slide)
	check(slide_view.slide_jump, "expired slide timer cannot change prepared family in the cue")
	equal(slide_view.cost, MovementSystem._movement_action_cost(slide, MovementTuning.SLIDE_JUMP_COST), "prepared slide keeps its actual chained release price")
	var slide_reserve := slide.stamina
	_jump_step(slide)
	check(slide.is_airborne() and slide.hop_mode == PlayerState.MovementMode.SLIDE_JUMP, "prepared slide really releases after timer expiry")
	equal(slide.stamina, slide_reserve - int(slide_view.cost), "actual slide release matches the displayed price")
	check(CompactCombatHud.jump_preparation_status(slide).is_empty(), "slide release removes charge UI")


func _test_jump_preparation_costs_and_interruptions() -> void:
	for slide_jump: bool in [false, true]:
		for chain: int in [0, 1, MovementTuning.MOVEMENT_CHAIN_MAXIMUM_STEPS]:
			for offset: int in [-1, 0]:
				var state := _jump_fixture()
				_jump_step(state, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
				state.hop_mode = PlayerState.MovementMode.SLIDE_JUMP if slide_jump else PlayerState.MovementMode.HOP
				state.movement_chain_count = chain
				state.movement_chain_reset_ticks = 100
				var cost := MovementSystem._movement_action_cost(state, MovementTuning.SLIDE_JUMP_COST if slide_jump else MovementTuning.HOP_COST)
				state.stamina = cost + offset
				var view := CompactCombatHud.jump_preparation_status(state)
				equal(view.cost, cost, "every prepared family reads the shared bounded chain cost")
				equal(view.kind, "stamina" if offset < 0 else "ready", "exact milli-unit boundary never rounds an unaffordable release up")
				_jump_step(state)
				equal(state.is_airborne(), offset == 0, "real release agrees with displayed exact-cost boundary")
				equal(state.stamina, cost - 1 if offset < 0 else 0, "denied release spends nothing; funded release spends exactly its price")
				check(CompactCombatHud.jump_preparation_status(state).is_empty(), "both accepted and denied release clear the preparation cue")
	var state := _jump_fixture()
	_jump_step(state, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
	state.hop_cooldown_ticks = 6
	equal(CompactCombatHud.jump_preparation_status(state).kind, "cooldown", "current hop cooldown takes precedence over a release hint")
	equal(CompactCombatHud.jump_preparation_status(state).label, "JUMP WAIT 0.1s", "positive sub-tenth waits never display zero seconds")
	var reserve := state.stamina
	_jump_step(state)
	check(not state.is_airborne() and state.stamina == reserve, "real cooldown refusal does not pay or launch")
	state = _jump_fixture()
	_jump_step(state, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
	state.hop_mode = PlayerState.MovementMode.SLIDE_JUMP
	state.slide_cooldown_ticks = SimConfig.new(120).milliseconds_to_ticks(MovementTuning.SLIDE_COOLDOWN_MS)
	check(int(CompactCombatHud.jump_preparation_status(state).wait_ticks) > 0, "prepared slide uses its own minimum age instead of hop cooldown")
	state.slide_cooldown_ticks = 0
	state.hop_cooldown_ticks = 60
	equal(CompactCombatHud.jump_preparation_status(state).kind, "ready", "irrelevant hop cooldown cannot block a prepared slide cue")
	for interruption: String in ["cancel", "control", "impact", "death", "airborne"]:
		state = _jump_fixture()
		_jump_step(state, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
		reserve = state.stamina
		match interruption:
			"cancel": _jump_step(state, SimCommand.HELD_JUMP, SimCommand.PRESSED_CANCEL_MOVEMENT)
			"control": MovementSystem.apply_control_state(state, PlayerState.ControlState.STUNNED, 200, Vector2i.ZERO, 0, SimConfig.new(120))
			"impact": state.impact_recovery_ticks = 5
			"death": state.health = 0
			"airborne": state.air_height = 1
		check(CompactCombatHud.jump_preparation_status(state).is_empty(), interruption + " cannot retain a misleading grounded release cue")
		equal(state.stamina, reserve, interruption + " presentation does not invent a payment")
	state = _jump_fixture()
	_jump_step(state, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
	state.control_state = PlayerState.ControlState.SLOWED
	check(not CompactCombatHud.jump_preparation_status(state).is_empty(), "slowed but free control retains preparation feedback")
	state.flux -= 10_000
	state.flux_recovery_delay_ticks = 12
	equal(CompactCombatHud.resource_detail_lines(state, 120, true), PackedStringArray(["FLUX WAIT 0.1s"]), "visible preparation suppresses only its duplicate hover instruction")
	check(CompactCombatHud.jump_preparation_status(null).is_empty(), "missing player has no preparation")
	check(CompactCombatHud.jump_preparation_status(state, 60).is_empty(), "unsupported rate cannot invent a charge clock")


func _test_jump_preparation_geometry() -> void:
	for viewport_size: Vector2 in [Vector2(960, 540), Vector2(1280, 720), Vector2(1600, 900)]:
		var resources := Rect2(16, viewport_size.y - 134, 270, 118)
		var preparation := CompactCombatHud.jump_preparation_panel(resources, viewport_size)
		var spells := Rect2(viewport_size.x - 602, viewport_size.y - 110, 586, 94)
		check(Rect2(Vector2.ZERO, viewport_size).encloses(preparation), "preparation fits each logical canvas")
		equal(preparation.size, Vector2(270, 48), "charge cue stays within a fixed small footprint")
		check(not preparation.intersects(resources) and not preparation.intersects(spells), "preparation covers neither resource amounts nor spell cues")
		for lines: int in [1, 2]:
			var details := CompactCombatHud.resource_detail_panel(Rect2(preparation.position, resources.size), viewport_size, lines)
			check(details.has_area() and Rect2(Vector2.ZERO, viewport_size).encloses(details), "hover details remain available above active preparation")
			check(not details.intersects(preparation) and not details.intersects(resources) and not details.intersects(spells), "hover cannot overlap any active lower HUD panel")
	check(not CompactCombatHud.jump_preparation_panel(Rect2(16, 20, 270, 118), Vector2(320, 180)).has_area(), "insufficient canvas space never clips a charge cue")
	for label: String in ["RELEASE TO JUMP · 39.2 ST", "JUMP NEED 39.2 STAMINA", "JUMP WAIT 0.5s"]:
		check(ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x <= 250.0, "longest valid release/cost line fits without shrinking type")
	check(ThemeDB.fallback_font.get_string_size("SLIDE JUMP CHARGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x <= 210.0, "prepared family title leaves room for the separate percentage")
