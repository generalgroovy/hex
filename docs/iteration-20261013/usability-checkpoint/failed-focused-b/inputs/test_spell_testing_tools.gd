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


class GuideInputHarness extends "res://src/app/bootstrap.gd":
	func _ready() -> void:
		set_process(false)
		set_process_unhandled_input(true)
	func _draw() -> void:
		pass


func run() -> int:
	abilities = AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "testing tools use live abilities")
	_test_controller_lifecycle()
	_test_nonmodal_guide_pointer_handoff()
	_test_remapped_convenience_hints()
	_test_range()
	_test_developer()
	_test_panel()
	_test_panel_feedback()
	_test_range_scenario_controls()
	_test_intro_layout()
	_test_challenge_layout()
	_test_introduction()
	_test_paid_intro_events()
	_test_tactical_gates()
	return finish("spell-testing-tools")


func _test_nonmodal_guide_pointer_handoff() -> void:
	InputRouter.ensure_input_map()
	var saved_events := {}
	for action: StringName in PlayerPreferences.DEFAULT_MOUSE_BINDINGS:
		saved_events[action]=InputMap.action_get_events(action).duplicate()
	var previous_mouse_mode := Input.mouse_mode
	for intent: String in ["skip","details"]:
		for remapped: bool in [false,true]:
			var viewport := SubViewport.new()
			viewport.size=Vector2i(960,540) if intent=="details" else Vector2i(1280,720)
			viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
			viewport.handle_input_locally=true
			(Engine.get_main_loop() as SceneTree).root.add_child(viewport)
			var game := GuideInputHarness.new()
			game.preferences_persistence_allowed=false
			game.preference_overrides_are_transient=true
			game.world=_world()
			game.world.player().flux_recovery_per_second=0
			game.player_preferences=PlayerPreferences.new()
			game.player_preferences.ui_text_percent=200 if intent=="details" else 100
			game.controls_editor=ControlBindingEditor.new()
			game.spell_loom_editor=SpellLoomEditor.new()
			game.player_compendium=game.PlayerCompendiumScript.new()
			game.character_selection_grid=game.CharacterSelectionGridScript.new()
			game.input_router=InputRouter.new()
			game.element_expansion.game=game
			game.local_navigation.configure(game)
			viewport.add_child(game)
			viewport.notify_mouse_entered()
			var binding: StringName=&"spell_1" if remapped else &"punch"
			if remapped:
				game.player_preferences.mouse_bindings[&"punch"]=0
				game.player_preferences.mouse_bindings[&"spell_1"]=MOUSE_BUTTON_LEFT
			check(game.input_router.configure_mouse_bindings(game.player_preferences.mouse_bindings),"guide handoff uses a valid current mouse map")
			check(game.element_expansion.guide.start(game.world),"pointer route begins with actual optional guidance")
			check(not game._gameplay_input_blocked(),"guide alone is nonmodal before the click")
			var logical: Vector2=Vector2(viewport.size)/game._ui_scale()
			var box: Rect2=game.element_expansion.guide.skip_rect(logical,ThemeDB.fallback_font) if intent=="skip" else game.element_expansion.guide.geometry(logical,ThemeDB.fallback_font).details
			var click := InputEventMouseButton.new()
			click.button_index=MOUSE_BUTTON_LEFT
			click.pressed=true
			click.position=box.get_center()*game._ui_scale()
			var before := game.world.state_hash()
			Input.parse_input_event(click)
			Input.flush_buffered_events()
			viewport.push_input(click,true)
			check(viewport.is_input_handled(),"actual inherited input consumes guide "+intent)
			equal(game.world.state_hash(),before,"guide click cannot itself mutate gameplay authority")
			check(game.input_router.quarantined_actions.has(binding),"consumed guide click quarantines its live physical binding")
			equal(game.controls_input_guard_frames,2,"guide click uses the existing two-frame handoff")
			equal(game.element_expansion.guide.active,intent!="skip","Skip and Details retain their distinct guide intent")
			if intent=="details": check(game.element_expansion.guide.detail_page,"compact pointer opens the existing explanation")
			var actor: PlayerState=game.world.player()
			var initial_flux := actor.flux
			for sample: int in 6:
				var command: SimCommand=game._sample_gameplay_command(game.world.tick,Vector2.ZERO,Vector2.RIGHT,game._gameplay_input_blocked())
				check(not command.has_pressed(SimCommand.PRESSED_SPELL_1),"held UI pointer never becomes a spell during or after guard")
				check(not game.input_router._paid_action_down(binding),"held UI pointer remains quarantined after guard")
				check(game.world.step([command]),"ordinary paid world accepts neutral UI handoff commands")
				game.controls_input_guard_frames=maxi(0,game.controls_input_guard_frames-1)
			equal(actor.flux,initial_flux,"holding a consumed guide pointer spends no Flux")
			equal(int(game.world.hex_court.metrics.matter_paid),0,"holding guide controls admits no paid source")
			click=click.duplicate()
			click.pressed=false
			Input.parse_input_event(click); Input.flush_buffered_events(); viewport.push_input(click,true)
			var release: SimCommand=game._sample_gameplay_command(game.world.tick,Vector2.ZERO,Vector2.RIGHT,false)
			check(not release.has_pressed(SimCommand.PRESSED_SPELL_1),"release cannot manufacture a spell")
			check(game.world.step([release]),"release advances through ordinary world")
			check(not game.input_router.quarantined_actions.has(binding),"actual release rearms the physical binding")
			click=click.duplicate()
			click.position=Vector2(viewport.size.x-8,8)
			click.pressed=true
			Input.parse_input_event(click); Input.flush_buffered_events(); viewport.push_input(click,true)
			var fresh: SimCommand=game._sample_gameplay_command(game.world.tick,Vector2.ZERO,Vector2.RIGHT,false)
			check(game.input_router._paid_action_down(binding),"fresh world click is available normally")
			equal(fresh.has_pressed(SimCommand.PRESSED_SPELL_1),remapped,"only a live remapped spell creates a spell edge; default Punch remains dormant")
			check(game.world.step([fresh]),"fresh world click uses the ordinary paid command path")
			if remapped:
				equal(initial_flux-actor.flux,int(CombatTuning.cast_definition_view(actor.spell_wire_id(1)).flux_cost),"first deliberate fresh spell pays exactly once")
				check(actor.pending_cast_wire_id==actor.spell_wire_id(1),"fresh paid admission owns the configured spell")
			else: equal(actor.flux,initial_flux,"dormant Punch binding invents no combat authority")
			click=click.duplicate()
			click.pressed=false
			Input.parse_input_event(click); Input.flush_buffered_events(); viewport.push_input(click,true)
			game.world=null
			viewport.free()
	for action: StringName in saved_events:
		Input.action_release(action)
		InputMap.action_erase_events(action)
		for event: InputEvent in saved_events[action]: InputMap.action_add_event(action,event)
	Input.mouse_mode=previous_mouse_mode

func _test_tactical_gates() -> void:
	var world := _world()
	var guide := Intro.new()
	world.player().movement_chain_count=2
	check(guide.start_tactical(world),"advanced lessons are explicitly optional")
	world.tick+=1
	check(not guide.observe(world,[],{}),"a pre-existing chain is not a newly executed lesson")
	world.player().movement_chain_count=3
	world.tick+=1
	check(guide.observe(world,[],{}),"a newly admitted linked action advances the chain gate")
	var wire := Mixtures.wire_for(63,"fuse")
	world.tick+=1
	check(not guide.observe(world,[{"type":"cast_started","entity_id":1,"wire_id":wire}],{}),"casting a mixed spell without consequence is insufficient")
	world.tick+=1
	var before := world.state_hash()
	check(guide.observe(world,[{"type":"projectile_hit","owner_id":1,"target_id":2,"source_wire_id":wire,"damage":500}],{}),"paid mixed damaging contact advances consequence gate")
	equal(world.state_hash(),before,"tactical observation cannot grant damage or spend resources")
	world.tick+=1
	world.player().last_event="evaded_projectile"
	check(not guide.observe(world,[],{"challenge":false}),"safe Range avoidance cannot replace the rival counter lesson")
	world.player().last_event="walk"
	world.tick+=1
	guide.observe(world,[],{"challenge":true})
	world.player().last_event="evaded_projectile"
	world.tick+=1
	check(guide.observe(world,[],{"challenge":true}),"actual fresh rival avoidance advances the counter gate")
	world.tick+=1
	check(not guide.observe(world,[],{"earned":true,"saved":false}),"unsaved reward remains an explicit recovery task")
	world.tick+=1
	check(guide.observe(world,[],{"earned":true,"saved":true}),"clean earned saved receipt completes lessons")
	check(guide.complete and not guide.active,"completion relinquishes the teaching overlay")
	# Isolate the observer's real ground-event schema. Product creation/payment
	# is exercised by Hex chemistry suites, rather than claimed by this fixture.
	check(guide.start_tactical(world),"ground observer restarts explicitly")
	guide.step=1
	world.hex_court.products[99001]={"owner":1,"recipe_wire_id":HexRecipePolicy.recipe_wire_for_mask(6)}
	world.tick+=1
	check(not guide.observe(world,[{"type":"hex_pressure","owner_id":2,"entity_id":2,"product_id":99001,"amount":75}],{}),"another owner's mixed product cannot satisfy local consequence")
	world.tick+=1
	check(guide.observe(world,[{"type":"hex_pressure","owner_id":1,"entity_id":2,"product_id":99001,"amount":75}],{}),"owned mixed product amount/entity_id counts without inventing a single source spell")
	world.hex_court.products.erase(99001)


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
				var ingredients := PackedStringArray()
				for element: String in mixture.elements: ingredients.append(AbilityCatalog.element_display_name(element))
				check(teaching.has("Ingredients: "+" + ".join(ingredients)), "Range retains every canonical ingredient")
				equal(teaching[0], ("Two matching paid sources: " if (mask & (mask-1))==0 else "Payload field: ")+String(mixture.purpose), "field trigger and purpose precede the ingredient list")
				equal(teaching[1], "Counter: "+String(mixture.counter), "complete counter stays prominent")
				var config := SimConfig.new()
				check(teaching.has("Base: %.2fs prepare / %.2fs cooldown." % [float(config.milliseconds_to_ticks(int(source.startup_ms)))/config.tick_rate,float(config.milliseconds_to_ticks(int(source.cooldown_ms)))/config.tick_rate]), "Range quotes actual quantized base timers")
				var statuses := preload("res://src/content/spell_status_catalog.gd").rows_for_mask(mask)
				for status: Dictionary in statuses:
					check(teaching.has("On damaging hit: "+String(status.summary)+". "+String(status.detail)), "every actual hit status has separate accurate detail")
				var font := ThemeDB.fallback_font
				var right: Rect2 = geometry.right
				var first_y := right.position.y+74
				var count := maxi(1,floori(((geometry.panel as Rect2).end.y-136-first_y)/18))
				var lines: Array[String] = []
				for paragraph: String in teaching:
					var wrapped := TestingPanelScript._wrap(paragraph,font,12,right.size.x-8)
					equal(" ".join(wrapped),paragraph,"pagination preserves every word")
					lines.append_array(wrapped)
				for index: int in lines.size():
					var extent := font.get_string_size(lines[index],HORIZONTAL_ALIGNMENT_LEFT,-1,12)
					var y := first_y+(index%count)*18
					var bounds := Rect2(Vector2(right.position.x,y-font.get_ascent(12)),extent)
					check(extent.x<=right.size.x-8 and (geometry.panel as Rect2).encloses(bounds),"all504 metadata glyphs fit on their accessible detail pages")
					check(bounds.end.y<(geometry.details_previous as Rect2).position.y,"every detail page clears its paging controls")

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
	for id: String in ["record_replay","export_replay"]:
		var index := -1
		for candidate: int in panel._rows.size():
			if panel._rows[candidate].id==id: index=candidate; break
		check(index>=0,"diagnostic recording action appears in Developer rows")
		panel.selected_index=index
		panel.pane=0
		equal(panel.handle_input(_key(KEY_ENTER),Vector2(960,540)),{"action":id},"real Developer row activation returns one diagnostic intent")
		check(not bool(panel._rows[index].toggle),"diagnostic record/export cannot become continuous cheat toggles")

	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = (TestingPanelScript.geometry(Vector2(960, 540)).buttons[3] as Rect2).get_center()
	equal(String(panel.handle_input(click, Vector2(960, 540)).action), "leave_developer", "visible developer exit is not merely close-menu")
	var viewport := Vector2(960, 540)
	var intro := Intro.new()
	check(Rect2(Vector2.ZERO, viewport).encloses(intro.skip_rect(viewport, ThemeDB.fallback_font)), "nonmodal Skip stays on screen")


func _test_range_scenario_controls() -> void:
	var panel := TestingPanelScript.new()
	check(panel.open_range(abilities),"scenario controls live inside existing Range")
	var scenario := {"active":true,"moving":false,"firing":false,"size":"Medium","elapsed_ticks":120,"statistics":{"player_casts":2,"player_flux":4000,"target_casts":0,"target_flux":0,"damage_to_target":3000,"damage_to_player":0,"direct_damage":3000,"ground_damage":0,"status_damage":0},"scope":"Current paid session only."}
	panel.set_range_scenario(scenario)
	scenario.moving=true
	check(not panel._range_scenario.moving,"scenario view cannot be changed through caller alias")
	var viewport := Vector2(480,270)
	panel.readable=true
	panel.handle_input(_key(KEY_T),viewport)
	check(panel.range_setup_open,"keyboard opens Setup without a new world or menu")
	for index: int in 4:
		panel.range_setup_index=index
		equal(panel.handle_input(_key(KEY_ENTER),viewport),{"action":String(TestingPanelScript.ScenarioPanel.ACTIONS[index])},"each setup control dispatches one validated-owner intent")
	var back := InputEventJoypadButton.new()
	back.pressed=true;back.button_index=JOY_BUTTON_B
	panel.handle_input(back,viewport)
	check(not panel.range_setup_open and panel.is_open,"Back returns to Range, preserving the selected mixture")
	for size: Vector2 in [Vector2(480,270),Vector2(960,540)]:
		var geo := TestingPanelScript.ScenarioPanel.geometry(size)
		for key: String in ["body","back","previous","next"]: check((geo.panel as Rect2).encloses(geo[key]),"setup reading and navigation fit at200percent")
		var labels := TestingPanelScript.ScenarioPanel.labels(panel._range_scenario)
		panel.range_setup_open=true
		for index: int in 4:
			var rect: Rect2=geo.controls[index]
			check((geo.panel as Rect2).encloses(rect),"every pointer target stays in visible panel")
			check(ThemeDB.fallback_font.get_string_size(labels[index],HORIZONTAL_ALIGNMENT_LEFT,-1,13).x<=rect.size.x-16,"complete control label fits actual readable font")
			var click := InputEventMouseButton.new()
			click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=rect.get_center()
			equal(panel.handle_input(click,size),{"action":String(TestingPanelScript.ScenarioPanel.ACTIONS[index])},"painted target and emitted intent use the same geometry")
		for text: String in TestingPanelScript.ScenarioPanel.paragraphs(panel._range_scenario):
			var wrapped := panel._wrap(text,ThemeDB.fallback_font,14,geo.body.size.x)
			equal(" ".join(wrapped),text,"statistics pagination preserves complete evidence scope")
		panel.detail_page=0
		panel.handle_input(_key(KEY_PERIOD),size)
		equal(panel.detail_page,1,"physical-key details navigation reaches every statistics paragraph")
	# Every compact-only browsing control is reached through its drawn More target.
	panel.range_setup_index=0
	var compact := TestingPanelScript.ScenarioPanel.geometry(viewport)
	var more := InputEventMouseButton.new()
	more.button_index=MOUSE_BUTTON_LEFT;more.pressed=true;more.position=compact.more.get_center()
	panel.handle_input(more,viewport)
	equal(panel.range_setup_index,4,"More exposes existing refill/reset tools")
	panel.handle_input(more,viewport)
	equal(panel.range_setup_index,8,"More exposes guide and delivery controls")
	var delivery_before: int=panel.family_index
	more.position=compact.controls[3].get_center()
	equal(panel.handle_input(more,viewport),{},"delivery selection never issues a world mutation")
	equal(panel.family_index,posmod(delivery_before+1,8),"actual visible Setup target changes the selected delivery")
	more.position=compact.more.get_center()
	panel.handle_input(more,viewport)
	equal(panel.range_setup_index,12,"More exposes both mixture controls")
	var mixture_before: int=panel.selected_index
	more.position=compact.controls[1].get_center()
	panel.handle_input(more,viewport)
	equal(panel.selected_index,posmod(mixture_before+1,panel._rows.size()),"last Setup page retains pointer mixture selection")
	panel.range_setup_open=false
	panel.pane=0;panel.tool_index=0
	panel.handle_input(_key(KEY_TAB),viewport)
	panel.handle_input(_key(KEY_TAB),viewport)
	equal(panel.tool_index,2,"entering the compact footer focuses the visible Equip action")
	panel.handle_input(_key(KEY_DOWN),viewport)
	equal(panel.tool_index,3,"keyboard focuses the drawn Tools action")
	equal(panel.handle_input(_key(KEY_ENTER),viewport),{},"visible Tools activation cannot emit a hidden refill intent")
	check(panel.range_setup_open,"keyboard Tools opens the same Setup as pointer")
	panel.handle_input(back,viewport)
	var down := InputEventJoypadButton.new()
	down.pressed=true;down.button_index=JOY_BUTTON_DPAD_DOWN
	for expected: int in [4,2,3]:
		panel.handle_input(down,viewport)
		equal(panel.tool_index,expected,"controller footer wraps only visible Equip/Tools/Close")
	var accept := InputEventJoypadButton.new()
	accept.pressed=true;accept.button_index=JOY_BUTTON_A
	equal(panel.handle_input(accept,viewport),{},"controller Tools dispatch cannot spend a refill tool")
	check(panel.range_setup_open,"controller Tools opens the same Setup")
	check(not panel._range_scenario.moving and not panel._range_scenario.firing,"UI intents do not optimistically mutate authoritative scenario state")


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
		for footer: String in ["Esc / Back: return Ãƒâ€šÃ‚Â· Shift+F6: rivals Ãƒâ€šÃ‚Â· Shift+F5: tools", "DEV PRACTICE Ãƒâ€šÃ‚Â· Esc: return Ãƒâ€šÃ‚Â· Shift+F5: tools"]:
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


func _test_remapped_convenience_hints() -> void:
	InputRouter.ensure_input_map()
	var saved_events := {}
	for action: StringName in InputMap.get_actions():
		saved_events[action] = InputMap.action_get_events(action).duplicate()
	var previous_mouse_mode := Input.mouse_mode
	for mapping: Dictionary in [{"key":KEY_F5,"shift":false},{"key":KEY_F5,"shift":true},{"key":KEY_F6,"shift":false},{"key":KEY_F6,"shift":true}]:
		var keycode: int = int(mapping.key)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1280, 720)
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		viewport.handle_input_locally = true
		(Engine.get_main_loop() as SceneTree).root.add_child(viewport)
		var game := GuideInputHarness.new()
		game.preferences_persistence_allowed = false
		game.preference_overrides_are_transient = true
		game.world = _world()
		game.ability_catalog = abilities
		game.player_preferences = PlayerPreferences.new()
		game.session_transport = SessionTransport.new()
		game.controls_editor = ControlBindingEditor.new()
		game.spell_loom_editor = SpellLoomEditor.new()
		game.player_compendium = game.PlayerCompendiumScript.new()
		game.character_selection_grid = game.CharacterSelectionGridScript.new()
		game.input_router = InputRouter.new()
		game.element_expansion.game = game
		game.local_navigation.configure(game)
		viewport.add_child(game)
		check(game.input_router.configure_keyboard_bindings(game.player_preferences.keyboard_bindings), "remap hint fixture starts from current supported defaults")
		game.element_expansion.refresh_guide_bindings()
		equal(game.element_expansion.guide._bindings.skip, "F5 / Skip guide", "default guide keeps the existing F5 label")
		equal(game.element_expansion.guide._bindings.range, "F6 / Spell Range", "default guide keeps the existing F6 label")
		game.controls_editor.open_editor()
		game.controls_editor.selected_action_index = ControlBindingEditor.ACTIONS.find(&"spell_1")
		game.controls_editor.selected_device = ControlBindingEditor.DEVICE_KEYBOARD
		game.controls_editor.begin_capture()
		_hint_key(viewport, keycode, true)
		equal(game.player_preferences.keyboard_bindings[&"spell_1"], keycode, "real editor capture accepts a supported convenience-key remap")
		_hint_key(viewport, keycode, false)
		_hint_key(viewport, KEY_ESCAPE, true)
		_hint_key(viewport, KEY_ESCAPE, false)
		check(not game.controls_editor.is_open, "actual Escape closes binding editor before gameplay")
		_hint_neutral_steps(game, 4)
		# Open the actual Menu and choose its Introduction row through key events.
		game.local_navigation.open_menu()
		_hint_key(viewport, KEY_DOWN, true)
		_hint_key(viewport, KEY_DOWN, false)
		_hint_key(viewport, KEY_ENTER, true)
		_hint_key(viewport, KEY_ENTER, false)
		check(game.element_expansion.guide.active and not game.local_navigation.menu_open, "Menu remains a working route to Introduction after remapping")
		_hint_neutral_steps(game, 4)
		var before := game.world.state_hash()
		game.element_expansion.refresh_guide_bindings()
		var rows: Array[Dictionary] = game.local_navigation.entries()
		for row: Dictionary in rows:
			if String(row.id) in ["expansion-introduction", "expansion-developer"]:
				equal(String(row.hint), "" if keycode == KEY_F5 else ("F5" if String(row.id) == "expansion-introduction" else "Shift+F5"), "F5 and shifted F5 hints match gameplay ownership")
			if String(row.id) in ["expansion-range", "expansion-challenges"]:
				equal(String(row.hint), "" if keycode == KEY_F6 else ("F6" if String(row.id) == "expansion-range" else "Shift+F6"), "F6 and shifted F6 hints match gameplay ownership")
		equal(game.element_expansion.guide._bindings.skip, "Menu > Skip introduction" if keycode == KEY_F5 else "F5 / Skip guide", "guide advertises an available Skip route")
		equal(game.element_expansion.guide._bindings.range, "Menu > Spell Range" if keycode == KEY_F6 else "F6 / Spell Range", "guide advertises an available Range route")
		if keycode == KEY_F5: check(not game.element_expansion.notice.contains("F5"), "initial lesson notice does not repeat an unavailable shortcut")
		equal(game.world.state_hash(), before, "label projection cannot mutate paid authority")
		var actor: PlayerState = game.world.player()
		var flux_before := actor.flux
		var matter_before := int(game.world.hex_court.metrics.matter_paid)
		_hint_key(viewport, keycode, true, bool(mapping.shift))
		var command: SimCommand = game._sample_gameplay_command(game.world.tick, Vector2.ZERO, Vector2.RIGHT, game._gameplay_input_blocked())
		check(command.has_pressed(SimCommand.PRESSED_SPELL_1), "fresh remapped key still routes to its actual gameplay action")
		check(game.element_expansion.guide.active and not game.element_expansion.panel.is_open and not game.element_expansion.developer.active, "remapped key and Shift variant cannot secretly Skip or open Range/rivals/tools")
		check(game.world.step([command]), "remapped action reaches the ordinary paid world")
		equal(flux_before - actor.flux, int(CombatTuning.cast_definition_view(actor.spell_wire_id(1)).flux_cost), "remapped spell pays its exact ordinary cost")
		check(int(game.world.hex_court.metrics.matter_paid) > matter_before, "remapped action creates actual paid-source ownership")
		var started := 0
		for event: Dictionary in game.world.combat_events:
			if String(event.get("type", "")) == "cast_started" and int(event.get("entity_id", 0)) == actor.entity_id: started += 1
		equal(started, 1, "one deliberate remapped press admits one real cast")
		_hint_key(viewport, keycode, false, bool(mapping.shift))
		_hint_neutral_steps(game, 1)
		# The existing fallback is actionable; no direct guide-stop call is used.
		game.local_navigation.open_menu()
		_hint_key(viewport, KEY_DOWN, true)
		_hint_key(viewport, KEY_DOWN, false)
		_hint_key(viewport, KEY_ENTER, true)
		_hint_key(viewport, KEY_ENTER, false)
		check(not game.element_expansion.guide.active, "Menu Skip works while the gameplay remap is retained")
		game.controls_editor.reset_bindings(game.player_preferences)
		game._commit_control_bindings()
		game.element_expansion.refresh_guide_bindings()
		equal(game.element_expansion.guide._bindings.skip, "F5 / Skip guide", "restoring defaults restores original Skip hint")
		equal(game.element_expansion.guide._bindings.range, "F6 / Spell Range", "restoring defaults restores original Range hint")
		_hint_neutral_steps(game, 4)
		var default_matter := int(game.world.hex_court.metrics.matter_paid)
		_hint_key(viewport, KEY_F5, true)
		_hint_key(viewport, KEY_F5, false)
		check(game.element_expansion.guide.active, "restored default F5 actually opens the Introduction again")
		_hint_neutral_steps(game, 4)
		_hint_key(viewport, KEY_F5, true)
		_hint_key(viewport, KEY_F5, false)
		check(not game.element_expansion.guide.active, "restored default F5 actually performs its advertised Skip action")
		equal(int(game.world.hex_court.metrics.matter_paid), default_matter, "restored convenience key does not become another paid cast")
		game.player_preferences.prompt_device = ControlBindingEditor.DEVICE_CONTROLLER
		game.element_expansion.refresh_guide_bindings()
		equal(game.element_expansion.guide._bindings.skip, "Menu > Skip introduction", "controller retains its existing available Menu route")
		equal(game.element_expansion.guide._bindings.range, "Menu > Spell Range", "controller Range fallback remains unchanged")
		game.world = null
		viewport.free()
	for action: StringName in saved_events:
		Input.action_release(action)
		InputMap.action_erase_events(action)
		for event: InputEvent in saved_events[action]: InputMap.action_add_event(action, event)
	Input.mouse_mode = previous_mouse_mode


func _hint_key(viewport: SubViewport, keycode: int, pressed: bool, shifted: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = pressed
	event.shift_pressed = shifted
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	viewport.push_input(event, true)


func _hint_neutral_steps(game: Node, count: int) -> void:
	for index: int in count:
		var command: SimCommand = game._sample_gameplay_command(game.world.tick, Vector2.ZERO, Vector2.RIGHT, game._gameplay_input_blocked())
		check(not command.has_pressed(SimCommand.PRESSED_SPELL_1), "handoff/release does not become a paid action")
		var commands: Array[SimCommand] = [command]
		check(game.world.step(commands), "handoff guard expires through ordinary neutral steps")
		game.controls_input_guard_frames = maxi(0, game.controls_input_guard_frames - 1)
