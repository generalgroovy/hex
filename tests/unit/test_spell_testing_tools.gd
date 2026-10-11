extends FluxTestSuite

const RangeModel = preload("res://src/app/spell_training_range.gd")
const Dev = preload("res://src/app/developer_testing_session.gd")
const TestingPanelScript = preload("res://src/presentation/spell_testing_panel.gd")
const Intro = preload("res://src/app/optional_introduction.gd")
const Mixtures = preload("res://src/content/mixture_catalog.gd")
const Expansion = preload("res://src/app/element_expansion_controller.gd")
var abilities: AbilityCatalog

class MissingWorldOwner extends Node:
	# A partially initialized owner intentionally has no viewport/menu methods.
	# Missing-world guards must run before any owner-dependent callback.
	var world: SimWorld


func run() -> int:
	abilities = AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "testing tools use live abilities")
	_test_controller_lifecycle()
	_test_range()
	_test_developer()
	_test_panel()
	_test_panel_feedback()
	_test_intro_layout()
	_test_challenge_layout()
	_test_introduction()
	_test_paid_intro_events()
	return finish("spell-testing-tools")


func _world() -> SimWorld:
	var world := SimWorld.new()
	check(HexCourtPractice.configure(world, abilities), "isolated practice world configures")
	return world


func _test_range() -> void:
	var world := _world()
	var actor := world.player()
	var range_model := RangeModel.new()
	check(not range_model.begin(actor, false), "network practice cannot borrow loadout")
	var original := actor.spell_wire_ids.duplicate()
	actor.set_spell_cooldown(int(original[4]), 80)
	check(range_model.begin(actor, true, 100), "local range snapshots original weave")
	check(not range_model.begin(actor, true, 100), "second begin cannot replace saved original with loaner")
	var rows := RangeModel.entries(abilities)
	equal(rows.size(), 504, "all63 mixtures by8 deliveries can be selected")
	var pairs := {}
	var before := actor.canonical_values()
	for row: Dictionary in rows:
		var request := range_model.preview(int(row.mask), String(row.family), abilities)
		check(not request.is_empty(), "each of504 loans prepares a valid request")
		if request.is_empty(): continue
		var key := "%d/%s" % [row.mask, row.family]
		check(not pairs.has(key), "every mask/delivery appears exactly once")
		pairs[key] = true
		equal(int(request.wire_ids[0]), int(row.wire), "requested spell enters slot1")
		equal(request.expected_wire_ids, original, "request guards current authority")
		check(not bool(request.save), "loaner does not request persistence")
		equal(actor.canonical_values(), before, "preview never equips or spends")
		if String(row.family) == "fuse": check(String(request.warning).contains("delay"), "Fuse delay is explicit before equip")
	var request := range_model.preview(63, "fuse", abilities)
	check(CharacterWeavePolicy.apply(actor, request.wire_ids), "loaner enters through ordinary validated policy")
	actor.set_spell_cooldown(int(request.selected_wire), 10)
	check(range_model.preview(62, "fuse", abilities).is_empty(), "selection cannot remove a cooling loaner to erase its clock")
	check(not range_model.restore(PlayerState.new(1), 120), "different actor cannot consume restoration")
	check(range_model.restore(actor, 120), "ending isolated practice restores original weave even if loaner cools")
	equal(actor.spell_wire_ids, original, "exact original positions restored")
	equal(actor.spell_cooldown_for_wire(int(original[4])), 80, "retained real cooldown is never shortened by snapshot restoration")
	check(not range_model.active, "restore closes loaner session")
	check(not range_model.restore(actor, 140), "restore is single-use")


func _test_developer() -> void:
	var world := _world()
	var actor := world.player()
	var dev := Dev.new()
	check(not dev.enter(false, true), "network dev entry refuses")
	check(not dev.enter(true, false), "competitive/nonpractice entry refuses")
	check(dev.enter(true, true), "offline developer session is explicit")
	for id: String in Dev.TOGGLES: check(dev.set_toggle(id, true), "declared toggle is reachable")
	check(not dev.set_toggle("time_scale", true), "no arbitrary simulation-speed override")
	actor.flux = 1
	actor.stamina = 1
	actor.spawn_protection_ticks = 30
	actor.set_spell_cooldown(actor.spell_wire_id(1), 99)
	check(dev.apply_continuous(world, true, true), "continuous cheats require admitted local sandbox")
	equal(actor.flux, actor.flux_maximum, "Flux toggle refills real resource")
	equal(actor.stamina, actor.stamina_maximum, "Stamina toggle refills real resource")
	equal(actor.spell_cooldown_for_wire(actor.spell_wire_id(1)), 0, "cooldown toggle clears real owning clock")
	check(dev.all_spells_enabled() and dev.freezes_rival(), "session flags expose explicit policy")
	world.tick = 31
	actor.spawn_protection_ticks = 0
	dev.apply_continuous(world, true, true)
	equal(actor.spawn_protection_ticks, 2, "immortality uses actual short damage-guard lease")
	dev.set_toggle("immortality", false)
	equal(actor.spawn_protection_ticks, 0, "disabling restores expired natural protection, not cheat ticks")
	var before := world.state_hash()
	check(not dev.apply("refill", world, false, true), "network action refuses")
	equal(world.state_hash(), before, "network refusal does not fill resources")
	check(not dev.active and not dev.all_spells_enabled(), "network boundary clears developer flags")
	check(not Dev.apply_practice_action("reset_targets", world, true, false), "Hearth cannot masquerade as isolated practice")
	world.player(2).health = 0
	check(Dev.apply_practice_action("reset_targets", world, true, true), "explicit Range Reset revives only target actors")
	equal(world.player(2).health, world.player(2).health_maximum, "target reset restores actual health")
	check(Dev.apply_practice_action("clear_shots", world, true, true), "field clear uses finite retirement path")
	check(world.hex_court.casts.is_empty() and world.hex_court.products.is_empty(), "field clear retires all paid matter")
	check(String(dev.view().characters).contains("already available"), "character option is truthful")


func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event


func _test_panel() -> void:
	var panel := TestingPanelScript.new()
	check(panel.open_range(abilities), "range selector opens")
	var canonical_before: Array[Dictionary] = Mixtures.all()
	var last_count := 0
	var last_mask := 0
	for index: int in 63:
		panel.selected_index = index
		var selection: Dictionary = panel.view().selection
		var mask := int(selection.element_mask)
		var count: int = selection.elements.size()
		if index < 6: equal(mask, [1, 2, 4, 8, 16, 32][index], "first six Range rows teach each singleton before any combination")
		check(count > last_count or (count == last_count and mask > last_mask), "Range orders ingredient count first, stable mask second")
		last_count = count
		last_mask = mask
	equal(last_mask, 63, "full six-element mixture remains the final reachable choice")
	equal(Mixtures.all(), canonical_before, "presentation ordering never changes the canonical catalog")
	for mask: int in range(1, 64):
		check(panel.open_range(abilities, mask, "fuse"), "every prior selection can reopen after presentation sorting")
		equal(int(panel.view().selection.element_mask), mask, "reopen resolves actual mask rather than mask-minus-one index")
	check(panel.open_range(abilities), "panel returns to its ordinary default after ordering controls")
	for viewport: Vector2 in [Vector2(960, 540), Vector2(1280, 720)]:
		var geometry := TestingPanelScript.geometry(viewport)
		check(Rect2(Vector2.ZERO, viewport).encloses(geometry.panel), "modal fits native supported viewport")
		equal((geometry.panel as Rect2).size.y, 508.0 if viewport.y == 540 else 520.0, "compact Range keeps the existing small-window height and removes the unused large-window gap")
		var last_row: Rect2 = geometry.left
		last_row.position.y += (TestingPanelScript.PAGE_SIZE - 1) * 40
		check(last_row.end.y < (geometry.panel as Rect2).end.y - 102 - ThemeDB.fallback_font.get_ascent(12), "all seven mixture rows clear the actual footer glyphs")
		for rect: Rect2 in geometry.buttons + geometry.utilities: check((geometry.panel as Rect2).encloses(rect), "all actionable utility buttons remain inside modal")
		for mixture: Dictionary in Mixtures.all():
			var mask := int(mixture.element_mask)
			var paragraphs := TestingPanelScript.payload_paragraphs(mixture)
			equal(String(paragraphs[0]).begins_with("TWO MATCHING PAID SOURCES:"), (mask & (mask - 1)) == 0, "single ingredient never promises an instant self-reaction field")
			for family: String in Mixtures.FAMILIES:
				var source := CombatTuning.cast_definition(Mixtures.wire_for(mask, family))
				var teaching := TestingPanelScript.spell_paragraphs(mixture, family)
				equal(teaching.size(), 5, "every selected delivery shows ingredients, payment/timing, hit status, field and counter")
				var ingredients := PackedStringArray()
				for element: String in mixture.elements: ingredients.append(AbilityCatalog.element_display_name(element))
				equal(teaching[0], "INGREDIENTS: " + " + ".join(ingredients), "Range retains every actual canonical ingredient display name")
				equal(teaching[1], "%d Flux | %.2fs prepare | %.2fs cooldown" % [int(source.flux_cost) / 1000, float(source.startup_ms) / 1000.0, float(source.cooldown_ms) / 1000.0], "Range quotes compiled cost/timers with fixed-unit and millisecond conversions")
				for channel: int in SpellStatusPolicy.BITS.size():
					equal(teaching[2].contains(SpellStatusPolicy.NAMES[channel]), (mask & SpellStatusPolicy.BITS[channel]) != 0, "hit status names match only actual selected ingredients")
				check(teaching[2].begins_with("ON DAMAGING HIT:"), "hit statuses are explicitly separate from terrain field formation")
				equal(teaching.slice(3), paragraphs, "complete source field purpose and counter survive extra spell teaching")
				var font := ThemeDB.fallback_font
				var right: Rect2 = geometry.right
				var y := right.position.y + 74
				var last_bottom := right.position.y + 29 + right.size.y
				var footer_top := (geometry.panel as Rect2).end.y - 102 - font.get_ascent(12)
				for paragraph: String in teaching:
					var wrapped := TestingPanelScript._wrap(paragraph, font, 12, right.size.x - 8)
					equal(" ".join(wrapped), paragraph, "Range wrapping never drops metadata or a counter")
					for line: String in wrapped:
						var extent := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
						var bounds := Rect2(Vector2(right.position.x, y - font.get_ascent(12)), extent)
						check(extent.x <= right.size.x - 8 and (geometry.panel as Rect2).encloses(bounds), "all504 actual metadata glyphs fit the readable12px column")
						check(bounds.position.y >= last_bottom and bounds.end.y <= footer_top - 4, "all504 explanations clear delivery controls, other lines and exact footer glyph bounds at both sizes")
						last_bottom = bounds.end.y
						y += 18
					y += 4
		for index: int in Mixtures.FAMILIES.size():
			var rect := TestingPanelScript.family_rect(index, geometry.right)
			check((geometry.panel as Rect2).encloses(rect), "all eight delivery targets fit their four-column two-row block")
			check(ThemeDB.fallback_font.get_string_size(String(Mixtures.FAMILIES[index]).capitalize(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x <= rect.size.x - 18, "every full delivery name fits native14px with no abbreviation")
			for earlier: int in index: check(not rect.intersects(TestingPanelScript.family_rect(earlier, geometry.right)), "delivery targets never overlap")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		for index: int in 3:
			click.position = (geometry.utilities[index] as Rect2).get_center()
			equal(String(panel.handle_input(click, viewport).action), ["reset_cooldowns", "reset_targets", "clear_shots"][index], "Range reset and clear tools are genuinely clickable")
	panel.selected_index = 62
	for index: int in 8:
		panel.family_index = index
		var action := panel.handle_input(_key(KEY_ENTER), Vector2(960, 540))
		equal(int(action.mask), 63, "last mixture stays reachable")
		equal(String(action.family), String(Mixtures.FAMILIES[index]), "every delivery is an explicit user activation")
	panel.selected_index = 6
	panel.handle_input(_key(KEY_PAGEDOWN), Vector2(960, 540))
	equal(panel.selected_index, 13, "paging retains relative row")
	panel.handle_input(_key(KEY_TAB), Vector2(960, 540))
	var family_before := panel.family_index
	panel.handle_input(_key(KEY_DOWN), Vector2(960, 540))
	equal(panel.family_index, posmod(family_before + 1, 8), "keyboard navigates delivery column")
	var dev := Dev.new()
	dev.enter(true, true)
	panel.open_developer(dev.view())
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = (TestingPanelScript.geometry(Vector2(960, 540)).buttons[3] as Rect2).get_center()
	equal(String(panel.handle_input(click, Vector2(960, 540)).action), "leave_developer", "visible developer exit is not merely close-menu")
	var viewport := Vector2(960, 540)
	var intro := Intro.new()
	check(Rect2(Vector2.ZERO, viewport).encloses(intro.skip_rect(viewport, ThemeDB.fallback_font)), "nonmodal Skip stays on screen")


func _test_panel_feedback() -> void:
	var panel := TestingPanelScript.new()
	check(panel.open_range(abilities, 63, "fuse"), "feedback uses the actual Range modal")
	var font := ThemeDB.fallback_font
	var world := _world()
	var before := world.state_hash()
	for text: String in ["Finish the active action before changing your weave.", "Practice tool applied: reset cooldowns", "Wait for the removed spell's cooldown before replacing it.", "That loaner is still cooling. Wait, or use Range Reset before changing it."]:
		panel.set_message(text)
		equal(panel.view().message, text, "refusal and tool feedback preserve the complete readable reason")
		for viewport: Vector2 in [Vector2(960, 540), Vector2(1280, 720)]:
			var geometry := TestingPanelScript.geometry(viewport)
			var feedback: Rect2 = geometry.feedback
			var bounds := Rect2(feedback.position + Vector2(0, 15 - font.get_ascent(12)), Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, font.get_height(12)))
			check(feedback.encloses(bounds) and (geometry.panel as Rect2).encloses(feedback), "full refusal glyphs fit actual12px font inside the modal at both sizes")
			check(bounds.position.y > (geometry.panel as Rect2).position.y + 51 + font.get_descent(12), "feedback clears the actual description glyphs")
			check(bounds.end.y < (geometry.left as Rect2).position.y and bounds.end.y < (geometry.right as Rect2).position.y, "feedback remains above list and delivery targets")
	check(panel.open_range(abilities), "Range reopens after a refusal")
	equal(panel.message, "", "new Range open clears stale refusal")
	panel.set_message("previous refusal")
	panel.open_developer({})
	equal(panel.message, "", "new Developer open clears another mode's refusal")
	var champions := ChampionCatalog.new()
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "challenge feedback reset uses validated champions")
	panel.set_message("previous refusal")
	check(panel.open_challenges(champions, abilities, SignatureProgression.new()), "challenge modal opens after prior feedback")
	equal(panel.message, "", "new challenge open clears another mode's refusal")
	equal(world.state_hash(), before, "modal feedback never advances or changes gameplay authority")


func _test_intro_layout() -> void:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(CompactCombatHud.DEFAULT_PATH))
	check(source is Dictionary and source.get("layout") is Dictionary, "intro clearance reads the actual authored combat HUD layout")
	if not source is Dictionary or not source.get("layout") is Dictionary: return
	var hud: Dictionary = source.layout
	var font := ThemeDB.fallback_font
	var intro := Intro.new()
	for viewport: Vector2 in [Vector2(960, 540), Vector2(1280, 720)]:
		# These are CompactCombatHud.draw's actual resource/header formulas,
		# sourced from its validated JSON, not a guessed rectangle for this test.
		var margin := float(hud.margin)
		var resources := Rect2(margin, viewport.y - margin - float(hud.resource_height), float(hud.resource_width), float(hud.resource_height))
		var header := Rect2(margin, margin, float(hud.header_width), float(hud.header_height))
		var preparation := CompactCombatHud.jump_preparation_panel(resources, viewport)
		var heights: Dictionary = {}
		for bindings: Dictionary in [{"move":"W/A/S/D", "jump":"Space", "cast":"1"}, {"move":"Up / Left / Down / Right", "jump":"Right Ctrl", "cast":"Shift+PageDown"}]:
			intro.configure_bindings(bindings)
			for step: int in range(Intro.STEP_COUNT + 1):
				intro.step = step
				var data := intro.view()
				var layout := intro.geometry(viewport, font)
				var box: Rect2 = layout.box
				var skip: Rect2 = layout.skip
				heights[box.size.y] = true
				equal(box.position, Vector2(16, 110), "changing lesson or bindings keeps the reading anchor stable")
				check(Rect2(Vector2.ZERO, viewport).encloses(box) and box.encloses(skip), "one introduction layout contains painting and its actual Skip hit area")
				equal(intro.skip_rect(viewport, font), skip, "Skip input and painting share identical measured geometry")
				check(not box.intersects(resources) and not box.intersects(header) and not box.intersects(preparation), "all lessons keep Health, Flux, Stamina and jump preparation readable")
				check(not box.intersects(Rect2(viewport * 0.5 - Vector2(16, 16), Vector2(32, 32))), "guide leaves the central actor area clear even at960")
				var title := "%d/%d  %s" % [mini(step + 1, Intro.STEP_COUNT), Intro.STEP_COUNT, data.title]
				var title_bounds := Rect2(box.position + Vector2(12, 24 - font.get_ascent(15)), font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15))
				check(box.encloses(title_bounds), "every complete lesson title fits the actual15px font")
				var lines := intro.body_lines(font, viewport)
				equal(" ".join(lines), String(data.instruction) + " " + String(data.explanation), "guide reflow retains all teaching words")
				var last_bottom := title_bounds.end.y
				for index: int in lines.size():
					var bounds := Rect2(box.position + Vector2(12, 46 + index * 18 - font.get_ascent(12)), font.get_string_size(lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 12))
					check(box.encloses(bounds) and bounds.position.y >= last_bottom and bounds.end.y <= skip.position.y - 4, "all source lesson lines fit actual font bounds without title/Skip overlap")
					last_bottom = bounds.end.y
				check(skip.position.y - last_bottom >= 8.0 and skip.position.y - last_bottom < 9.0, "guide reserves only eight pixels plus rounding between actual text and Skip")
				equal(box.end.y - skip.end.y, 12.0, "Skip retains its compact bottom margin")
				equal(intro.view(), data, "measuring layout never advances or changes the lesson")
		check(heights.size() > 1, "shorter lessons genuinely reduce card height rather than retaining a fixed empty body")


func _test_challenge_layout() -> void:
	var notices := WellspringInteractionPresenter.new()
	var font := ThemeDB.fallback_font
	var champions := ChampionCatalog.new()
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "challenge layout reads every real rival")
	var controller := Expansion.new()
	check(not controller.entry_buttons_visible(), "compact Menu owns discovery without a duplicate persistent practice strip")
	controller.challenge_active = true
	check(not controller.entry_buttons_visible(), "challenges also keep the old shortcut painting and hit areas absent")
	for viewport: Vector2 in [Vector2(960, 540), Vector2(1280, 720)]:
		var box := Expansion.challenge_banner_rect(viewport)
		check(Rect2(Vector2.ZERO, viewport).encloses(box), "challenge instructions remain on screen")
		check(not box.intersects(Rect2(viewport * 0.5 - Vector2(24, 40), Vector2(48, 80))), "challenge instructions leave the central movement silhouette clear")
		for row: Dictionary in SignatureChallengeCatalog.rows(champions, abilities):
			var message := "Defeat %s to learn %s. %s" % [String(row.name), String(row.spell_name), String(row.counter)]
			var notice: Rect2 = notices.notice_layout(viewport, message).rect
			check(not box.intersects(notice) and box.position.y >= notice.end.y + 8, "every rival's real notice clears the challenge card")
			var title := String(row.spell_name)
			var bounds := Rect2(box.position + Vector2(14, 23 - font.get_ascent(16)), font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16))
			check(box.encloses(bounds), "every full signature title fits its actual16px font")
		var longest_notice: Rect2 = notices.notice_layout(viewport, "Practice feedback. ".repeat(40)).rect
		check(not box.intersects(longest_notice) and box.position.y >= longest_notice.end.y + 8, "bounded three-line notices cannot collide with challenge instructions")
		for footer: String in ["Esc / Back: return · Shift+F6: rivals · Shift+F5: tools", "DEV PRACTICE · Esc: return · Shift+F5: tools"]:
			var bounds := Rect2(box.position + Vector2(14, 76 - font.get_ascent(11)), font.get_string_size(footer, HORIZONTAL_ALIGNMENT_LEFT, -1, 11))
			check(box.encloses(bounds), "return, next rival and developer keys remain fully readable")


func _test_introduction() -> void:
	var world := _world()
	var intro := Intro.new()
	check(intro.start(world), "optional guide starts on valid authority")
	var hash := world.state_hash()
	check(not intro.observe(world, [], {}), "unstepped input cannot progress lesson")
	equal(world.state_hash(), hash, "guide never mutates world")
	# Synthetic states test each observer gate; actual input journey remains a
	# separate root gate. Merely casting a key or opening a menu is not enough.
	for unused: int in 8:
		world.tick += 1
		world.player().position_x += 10000
		intro.observe(world, [], {})
	equal(intro.step, 1, "real changed position completes movement gate")
	world.tick += 1
	check(not intro.observe(world, [], {}), "ground preparation alone does not count as airborne")
	world.player().air_height = 1000
	world.player().air_vertical_velocity = 1000
	world.tick += 1
	check(intro.observe(world, [], {}), "actual rising height completes jump gate")
	world.tick += 1
	check(not intro.observe(world, [{"type": "cast_started", "entity_id": 2, "wire_id": 140}], {}), "rival cast does not teach player paid input")
	world.tick += 1
	check(intro.observe(world, [{"type": "cast_started", "entity_id": 1, "wire_id": 140}], {}), "actual accepted player cast completes payment gate")
	world.player().flux -= 1000
	world.tick += 1
	intro.observe(world, [], {})
	world.player().flux += 100
	world.player().flux_recovery_delay_ticks = 0
	world.tick += 1
	check(intro.observe(world, [], {}), "observed resource rise after wait completes recovery")
	world.tick += 1
	check(not intro.observe(world, [], {"range": false}), "range invitation cannot self-complete")
	world.tick += 1
	check(intro.observe(world, [], {"range": true}), "actual Range context opens advanced teaching")
	world.tick += 1
	check(not intro.observe(world, [{"type": "cast_started", "entity_id": 1, "wire_id": 140}], {"range": true}), "single element is not advertised as mixed")
	world.tick += 1
	check(intro.observe(world, [{"type": "cast_started", "entity_id": 1, "wire_id": Mixtures.wire_for(63, "fuse")}], {"range": true}), "paid mixed Range spell completes optional lesson")
	check(intro.complete and not intro.active, "complete lesson relinquishes overlay")
	check(intro.start(world), "lesson can restart by explicit choice")
	intro.stop()
	check(not intro.active, "Skip immediately ends nonmodal guidance")


func _test_paid_intro_events() -> void:
	for funded: bool in [false, true]:
		var world := _world()
		var intro := Intro.new()
		check(intro.start(world), "actual paid-input guide fixture starts")
		intro.step = 2 # Isolate the cast lesson; movement gates are checked above.
		if not funded: world.player().flux = 0
		check(world.step([SimCommand.new(world.tick, 1, 0, 0, 0, SimCommand.SPELL_PRESSED_BITS[0], 0, -1000)]), "real normal spell request steps")
		var accepted := false
		for event: Dictionary in world.combat_events:
			if String(event.get("type", "")) == "cast_started" and int(event.get("entity_id", 0)) == 1 and int(event.get("wire_id", 0)) == world.player().spell_wire_id(1): accepted = true
		equal(accepted, funded, "actual cast_started fields appear only after paid admission")
		var before := world.state_hash()
		equal(intro.observe(world, world.combat_events, {}), funded, "lesson advances from real accepted event, never denied input")
		equal(world.state_hash(), before, "actual event observation remains read-only")


func _test_controller_lifecycle() -> void:
	for partial_owner: bool in [false, true]:
		var world := _world()
		world.player().flux = 1000
		var controller := Expansion.new()
		var owner: MissingWorldOwner = MissingWorldOwner.new() if partial_owner else null
		controller.game = owner
		check(not controller.configured, "lifecycle control has never configured progression or an owner world")
		check(controller.guide.start(world), "an already-started guide survives owner/world detachment")
		check(controller.developer.enter(true, true), "detached fixture contains an active developer session")
		check(controller.developer.set_toggle("infinite_flux", true), "before-step refusal is tested with a mutating tool enabled")
		check(controller.training.begin(world.player(), true, world.tick), "detached fixture retains a real Range lease")
		check(controller.developer_weave.begin(world.player(), true, world.tick), "detached fixture retains a developer weave lease")
		controller.challenge_active = true
		controller.challenge.tainted = true
		controller.challenge.reward = {"notice": "Existing attempt feedback"}
		controller.notice = "Existing controller feedback"
		var world_before := world.state_hash()
		var input_mode_before := Input.mouse_mode
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = Expansion.entry_rect(1, Vector2(960, 540)).get_center()
		var pad := InputEventJoypadButton.new()
		pad.button_index = JOY_BUTTON_A
		pad.pressed = true
		var events: Array[InputEvent] = [_key(KEY_F6), click, pad]
		for panel_open: bool in [false, true]:
			if panel_open: check(controller.panel.open_range(abilities, 63, "fuse"), "detached input control includes an actually open modal")
			else: controller.panel.close()
			var input_before := _controller_lifecycle_state(controller)
			for event: InputEvent in events:
				check(not controller.handle_input(event), "missing owner/world declines keyboard, pointer and pad before modal dispatch")
				equal(_controller_lifecycle_state(controller), input_before, "declined input cannot close a panel, activate a tool or advance teaching")
				equal(Input.mouse_mode, input_mode_before, "declined input performs no handoff or mouse capture change")
		var callbacks_before := _controller_lifecycle_state(controller)
		controller.before_step()
		controller.after_step()
		controller.refresh_loom()
		check(not controller.prepare_character_change(), "missing owner/world cannot promise a Range resume")
		controller.finish_character_change(false)
		controller.finish_character_change(true)
		check(controller.rival_command() == null, "missing owner/world produces no rival input even during an active attempt")
		equal(_controller_lifecycle_state(controller), callbacks_before, "missing-authority callbacks preserve guide, practice leases, feedback and earned-progress state")
		equal(world.state_hash(), world_before, "detached callbacks never refill, equip, spend, move or step the former world")
		controller.before_transition()
		check(not controller.training.active and not controller.developer_weave.active, "transition still releases both leases without a usable owner")
		check(not controller.developer.active and not controller.developer.all_spells_enabled(), "transition still clears developer session overrides")
		check(not controller.challenge_active and controller.challenge.reward.is_empty() and not controller.challenge.tainted, "transition still clears attempt state")
		check(not controller.panel.is_open and not controller.guide.active and not controller.blocks_gameplay(), "transition closes the modal and guide without retaining a gameplay block")
		equal(controller.progression.view(), callbacks_before.progression, "cleanup does not grant or save progress")
		equal(world.state_hash(), world_before, "cleanup cannot mutate a detached former world")
		if owner != null: owner.free()


func _controller_lifecycle_state(controller) -> Dictionary:
	return {
		"panel": controller.panel.view().duplicate(true),
		"guide": controller.guide.view().duplicate(true),
		"developer": controller.developer.view().duplicate(true),
		"range": controller.training.view().duplicate(true),
		"developer_weave": controller.developer_weave.view().duplicate(true),
		"challenge_active": controller.challenge_active,
		"challenge_tainted": controller.challenge.tainted,
		"reward": controller.challenge.reward.duplicate(true),
		"progression": controller.progression.view().duplicate(true),
		"notice": controller.notice,
	}
