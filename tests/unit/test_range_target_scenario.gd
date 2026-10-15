extends FluxTestSuite

const Scenario = preload("res://src/app/range_target_scenario.gd")
const RangeSession = preload("res://src/app/spell_training_range.gd")
const RangeScenarioPanel = preload("res://src/presentation/range_scenario_panel.gd")
const Garden = preload("res://src/app/element_garden_exhibition.gd")


func run() -> int:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"),"Range scenario loads paid spells")
	var champions := ChampionCatalog.new()
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json",abilities),"Range scenario uses real size exemplars")
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"),"Garden preset uses actual map plots")
	var garden := Garden.new()
	check(garden.configure(layout.element_garden_plots()),"actual harmless Garden configures")
	var world := SimWorld.new()
	check(HexCourtPractice.configure(world,abilities),"Range has ordinary paid Hex authority")
	var before := world.state_hash()
	for plot: Dictionary in garden.plots():
		var info: Dictionary = garden.nearest_info(plot.center)
		var preset := RangeSession.garden_preset(info,"fuse")
		equal(int(preset.mask),int(plot.mask),"nearest actual plot keeps its exact1..63 ingredient selection")
		equal(int(preset.wire),MixtureCatalog.wire_for(int(plot.mask),"fuse"),"Range preset keeps the selected existing delivery")
		check(bool(preset.requires_paid_cast) and not String(preset.try).is_empty(),"every preset teaches a repeatable paid counter test")
	equal(world.state_hash(),before,"inspecting all63 harmless plots injects no material, cast, resource or reward into live authority")
	check(RangeSession.garden_preset({},"bolt").is_empty() and RangeSession.garden_preset({"mask":64},"bolt").is_empty(),"unknown or missing plot fails closed")
	var scenario := Scenario.new()
	check(not scenario.begin(world,champions,false),"online world cannot acquire local practice mutations")
	equal(world.state_hash(),before,"rejected online configuration leaves authority intact")
	check(scenario.begin(world,champions,true),"fresh isolated Range gets one finite target budget")
	check(not scenario.moving and not scenario.firing,"fresh Range keeps the stationary nonfiring target familiar")
	var target := world.player(2)
	var radii := {}
	var resources := [target.health,target.flux,target.stamina,target.spell_cooldown_ticks.duplicate()]
	for unused: int in 3:
		radii[String(scenario.view().size)] = target.radius
		check(scenario.cycle_size(),"explicit target size setting is admitted locally")
	check(int(radii.Small)<int(radii.Medium) and int(radii.Medium)<int(radii.Large),"size variants use distinct authored hurt radii")
	equal([target.health,target.flux,target.stamina,target.spell_cooldown_ticks],resources,"size switches never refill or erase cooldowns")
	check(world.player().place_proven_spell(0,MixtureCatalog.wire_for(63,"bolt")),"all-six Range experiment equips an ordinary paid spell")
	var origin := Vector2i(target.position_x,target.position_y)
	var saw_movement := false
	var saw_target_shot := false
	var saw_player_shot := false
	var observed_status_ticks: Array[int] = [0, 0, 0, 0, 0, 0]
	var saw_overlapping_statuses := false
	var saw_status := false
	for tick: int in range(600):
		if tick==180:
			var toggle_hash: String = world.state_hash()
			check(scenario.set_moving(true) and scenario.set_firing(true),"target starts readable motion and paid return fire only on explicit toggles")
			equal(world.state_hash(), toggle_hash, "target behavior toggles do not directly mutate paid authority")
		var actor := world.player()
		var aim := Vector2i(target.position_x-actor.position_x,target.position_y-actor.position_y)
		var pressed := SimCommand.PRESSED_SPELL_1 if tick in [0,240,480] else 0
		var rival := scenario.command()
		check(rival!=null,"Range planner supplies bounded ordinary target intent")
		if rival==null: break
		check(world.step([SimCommand.new(world.tick,1,0,0,0,pressed,aim.x,aim.y),rival]),"Range options run through whole paid simulation ticks")
		var status_count := 0
		for channel: int in 6:
			if target.spell_status_values[channel * SpellStatusPolicy.STRIDE] > 0:
				observed_status_ticks[channel] += 1
				status_count += 1
		# Keep all600 paid observations and independent status counts; sample the
		# expensive whole-world purity hash at actual status and command boundaries.
		var purity_boundary := tick in [0, 179, 180, 240, 480, 599] or (status_count > 0 and not saw_status) or (status_count > 1 and not saw_overlapping_statuses)
		var observation_hash: String = world.state_hash() if purity_boundary else ""
		scenario.observe()
		if purity_boundary:
			equal(world.state_hash(), observation_hash, "status observation preserves paid authority at boundary tick%d" % tick)
		saw_status = saw_status or status_count > 0
		saw_overlapping_statuses = saw_overlapping_statuses or status_count > 1
		for event: Dictionary in world.combat_events:
			if String(event.get("type",""))=="projectile_spawned":
				saw_target_shot = saw_target_shot or int(event.get("owner_id",0))==2
				saw_player_shot = saw_player_shot or int(event.get("owner_id",0))==1
		saw_movement = saw_movement or Vector2i(target.position_x,target.position_y)!=origin
	var measured := scenario.view()
	check(saw_movement and saw_target_shot and saw_player_shot,"settings produce real motion and paid released pressure on both sides")
	check(int(measured.statistics.player_casts)>0 and int(measured.statistics.player_flux)>0 and int(measured.statistics.target_flux)>0,"diagnostic counts only accepted paid admissions")
	check(int(measured.statistics.damage_to_target)>0,"selected mixture produces actual target damage")
	equal(int(measured.statistics.damage_to_target),int(measured.statistics.direct_damage)+int(measured.statistics.ground_damage)+int(measured.statistics.status_damage),"damage categories reconcile every observed owned loss")
	for exposure: int in measured.statistics.status_ticks: check(exposure>0,"actual all-six paid hit exposes every separate status")
	equal(measured.tick_rate, world.config.tick_rate, "public status duration uses the actual simulation cadence")
	equal(measured.statistics.status_ticks, observed_status_ticks, "each status counts actual completed active target ticks independently")
	check(saw_overlapping_statuses, "paid mixture genuinely exposes overlapping channels")
	var display_hash := world.state_hash()
	var status_text: String = RangeScenarioPanel.paragraphs(measured)[3]
	for channel: int in 6:
		var expected := "%s %.2fs" % [SpellStatusPolicy.NAMES[channel], float(observed_status_ticks[channel]) / world.config.tick_rate]
		check(status_text.contains(expected), "Range modal exposes the real paid duration for " + SpellStatusPolicy.NAMES[channel])
	check(status_text.contains("in this window") and status_text.contains("Channels can overlap"), "duration wording does not add simultaneous status times or claim balance strength")
	equal(world.state_hash(), display_hash, "formatting the detached Range evidence cannot change authority")
	scenario.observe()
	equal(scenario.view(),measured,"repeated observation cannot double count one authoritative tick")
	before = world.state_hash()
	check(not scenario.begin(world,champions,true),"repeated begin cannot refill the active target budget")
	equal(world.state_hash(),before,"refused re-entry preserves spent target resources")
	var intent := scenario.command()
	var behavior_before := [intent.move_x,intent.move_y,intent.held_actions]
	check(scenario.reset_statistics(),"explicit measurement reset is available")
	intent = scenario.command()
	equal([intent.move_x,intent.move_y,intent.held_actions],behavior_before,"statistics reset cannot restart the target's movement or firing rhythm")
	equal(world.state_hash(),before,"reset statistics never resets target health, resources, projectiles, timers or effects")
	equal(int(scenario.view().statistics.player_casts),0,"measurement reset clears observation counters only")
	equal(scenario.view().statistics.status_ticks, [0, 0, 0, 0, 0, 0], "reset clears the status window without clearing live effects")
	equal(RangeScenarioPanel.paragraphs(scenario.view())[3], "No target status observed in this window.", "cleared observation has an explicit empty result")
	measured.statistics.clear()
	check(not scenario.view().statistics.is_empty(),"public measurement view is detached")
	scenario.close()
	check(scenario.command()==null and scenario.view().is_empty() and not scenario.reset_statistics(),"leaving Range retires its command and statistics authority")
	return finish("range-target-scenario")
