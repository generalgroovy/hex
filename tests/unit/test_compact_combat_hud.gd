extends FluxTestSuite


func run() -> int:
	_test_repository_hud()
	_test_fail_closed_contract()
	_test_recovery_and_float_status()
	_test_spell_family_labels()
	_test_shared_top_third_portraits()
	_test_quiet_authoritative_readiness()
	_test_compact_practice_card()
	return finish("compact-combat-hud")


func _test_quiet_authoritative_readiness() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "readiness uses the live catalog")
	var state := PlayerState.new()
	state.flux = state.flux_maximum
	for element: String in AbilityCatalog.FIRST_EIGHT_ELEMENTS:
		for family: String in AbilityCatalog.SPELL_MATRIX_FAMILIES:
			var ability: Dictionary = catalog.abilities_by_id[catalog.spell_id_at(element, family)]
			var need := CombatSystem.cast_capacity_requirement(int(ability.wire_id))
			var ready := CompactCombatHud.spell_readiness(state, ability, 120, need)
			equal(ready.kind, "ready", "all 32 runtime catalog cells become ready at their exact offer")
			equal(ready.label, "", "ready cells do not repeat the same word four times")
			if need.x > 0 or need.y > 0:
				var short_offer := need - (Vector2i(1, 0) if need.x > 0 else Vector2i(0, 1))
				equal(CompactCombatHud.spell_readiness(state, ability, 120, short_offer).kind, "capacity", "readiness checks complete family capacity, not one projectile")
	var bolt: Dictionary = catalog.ability_from_wire(101)
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
	state.air_height = 40_000
	state.hop_ticks = 1
	state.float_ticks = 1
	state.stamina = 1000
	equal(CompactCombatHud.protection_status(state), "PROTECTED / FLOAT", "active affordable Float is explicit")
	state.chemistry_regen_block_ticks = 0
	state.float_ticks = 120
	equal(CompactCombatHud.quiet_resource_label(state, "STAMINA"), "STAMINA FLOAT 1.0s", "finite protection time stays visible without pointer inspection")
	state.stamina = 0
	equal(CompactCombatHud.protection_status(state), "", "exhaustion removes protection immediately without visual interpolation")
	state.spawn_protection_ticks = 1
	state.health = 0
	equal(CompactCombatHud.protection_status(state), "", "dead states never advertise protection")
	equal(CompactCombatHud.spell_readiness(state, bolt).kind, "unavailable", "dead actor cannot claim cast readiness")


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
	var expected_labels: Array[String] = ["BOLT", "HEAVY", "RAPID", "SPRAY"]
	for element: String in AbilityCatalog.FIRST_EIGHT_ELEMENTS:
		for index: int in range(AbilityCatalog.SPELL_MATRIX_FAMILIES.size()):
			var id := catalog.spell_id_at(element, AbilityCatalog.SPELL_MATRIX_FAMILIES[index])
			var ability: Dictionary = catalog.abilities_by_id[id]
			var label := CompactCombatHud.spell_summary_label(ability)
			equal(label, "%s · %d F" % [expected_labels[index], int(ability["flux_cost"])], "hotbar differentiates every family without changing displayed Flux cost")
			check(ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x <= 122.0, "family and price fit the existing 142px hotbar cell")
	equal(CompactCombatHud.spell_summary_label(catalog.ability_from_wire(179)), "HEAVY · 18 F", "heavy shell is recognizable from the hotbar")
	equal(CompactCombatHud.spell_summary_label(catalog.ability_from_wire(180)), "RAPID · 2 F", "rapid stream is recognizable from the hotbar")
	equal(CompactCombatHud.spell_summary_label(catalog.ability_from_wire(141)), "SPRAY · 16 F", "spray cone is recognizable from the hotbar")
	equal(CompactCombatHud.spell_summary_label(catalog.ability_from_wire(110)), "DISABLED", "catalog-only Vector Lance cannot resemble a live hotbar spell")
	equal(CompactCombatHud.spell_summary_label({}), "DISABLED", "missing family metadata fails closed")


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
	state.hop_ticks = SimConfig.new(120).milliseconds_to_ticks(MovementTuning.VARIABLE_JUMP_MINIMUM_MS) + 1
	state.air_height = 20_000
	state.air_vertical_velocity = 500_000
	state.jump_held_last_tick = true
	equal(CompactCombatHud.stamina_status_label(state, 120), "STAMINA  JUMP -80/s", "paid jump sustain is explicit without relying on color")
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
	state.float_ticks = 216
	equal(CompactCombatHud.stamina_status_label(state, 120), "STAMINA FLOAT 1.8s -100/s", "paid Float shows remaining size-limited duration and drain")
	state.float_ticks = 0
	check(not CompactCombatHud.stamina_status_label(state, 120).contains("FLOAT"), "expired Float cannot advertise protected spending")
	state.float_ticks = 216
	state.air_floating = false
	equal(CompactCombatHud.stamina_status_label(state, 120), "STAMINA", "ending Float removes its paid status immediately")
	state.air_floating = true
	state.control_state = PlayerState.ControlState.STUNNED
	check(not CompactCombatHud.stamina_status_label(state, 120).contains("FLOAT"), "forced control cannot advertise an active Float")
	state.control_state = PlayerState.ControlState.FREE
	state.stamina = 0
	check(not CompactCombatHud.stamina_status_label(state, 120).contains("FLOAT"), "exhaustion cannot advertise protected Float spending")
	# Check the actual smallest resource-bar lane without changing the HUD layout.
	state.air_floating = false
	state.air_height = 0
	state.chemistry_regen_block_ticks = 10
	equal(CompactCombatHud.flux_status_label(state, 120), "FLUX SEALED", "chemistry-blocked Flux never falsely promises recovery")
	equal(CompactCombatHud.stamina_status_label(state, 120), "STAMINA SEALED", "chemistry-blocked Stamina never falsely promises recovery")
	var labels: Array[String] = ["FLUX +150/s", "STAMINA +150/s", "STAMINA FLOAT 1.8s -100/s", "STAMINA SPRINT -34/s", "STAMINA WAIT 0.4s", "STAMINA  NEXT +40%"]
	for label: String in labels:
		var rendered := "%s  792/792" % label
		var measured := ThemeDB.fallback_font.get_string_size(rendered, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		check(measured <= 192.0, label + " fits the existing 204px resource bar without clipping")
