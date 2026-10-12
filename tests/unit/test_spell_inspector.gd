extends FluxTestSuite
const Inspector = preload("res://src/presentation/spell_inspector_model.gd")
const Mixtures = preload("res://src/content/mixture_catalog.gd")
const Perks = preload("res://src/sim/entities/identity_perk_policy.gd")

func run() -> int:
	var config := SimConfig.new()
	var state := PlayerState.new(1)
	var before := state.canonical_values()
	for mask: int in range(1,64):
		for family: String in Mixtures.FAMILIES:
			var wire := Mixtures.wire_for(mask,family)
			var source := CombatTuning.cast_definition(wire)
			var row := Inspector.inspect(wire,state)
			equal(row.flux,float(source.flux_cost)/1000.0,"cost uses compiled rules, not UI copy")
			equal(row.damage,float(source.damage)/1000.0,"damage/pool stays in Health units")
			var timing := Perks.spell_timing(state,source,config,SpellStatusPolicy.startup_ratio(state))
			equal(row.startup_ticks,timing.startup_ticks,"current preparation matches admission projection")
			equal(row.cooldown_ticks,timing.cooldown_ticks,"current repeat delay matches release projection")
			var expected_cycle := float(int(timing.startup_ticks)+int(timing.cooldown_ticks))/config.tick_rate
			equal(row.cycle,expected_cycle,"cycle converts the total authoritative ticks once, before display rounding")
			var metrics := Inspector.metrics(wire,state)
			equal(metrics.size(),6,"both layouts receive all six metrics")
			equal(float(metrics[0].value),float(source.flux_cost)/1000.0,"displayed Flux round-trips the exact compiled milli-unit cost")
			if int(source.flux_cost)%1000==0:
				equal(String(metrics[0].value),str(int(source.flux_cost)/1000),"whole Flux costs retain the compact integer presentation")
			equal(metrics[3],{"label":"FIRE EVERY","value":"%.2f s min" % expected_cycle},"cycle metric preserves its label and independently summed tick value")
			check(Inspector.comparison(wire,wire,state)[0].begins_with("Already equipped"),"same spell cannot invent an advantage")
			check(Inspector.timing_note(wire,state).contains("before payment") and Inspector.timing_note(wire,state).contains("at release"),"two actual clocks are explained")
		equal(state.canonical_values(),before,"inspection cannot mutate gameplay")
	var dark := Mixtures.wire_for(32,"bolt")
	var fire := Mixtures.wire_for(2,"mantle")
	var comparison := Inspector.comparison(fire,dark,state)
	check(comparison[2].contains("Hit") and comparison[2].contains("pool"),"comparison distinguishes damage geometries")
	check(comparison[-1].contains("not sustained damage rates"),"shared pools are not misrepresented as DPS")
	var fire_timing := Perks.spell_timing(state,CombatTuning.cast_definition(fire),config,SpellStatusPolicy.startup_ratio(state))
	var dark_timing := Perks.spell_timing(state,CombatTuning.cast_definition(dark),config,SpellStatusPolicy.startup_ratio(state))
	var selected_cycle := float(int(fire_timing.startup_ticks)+int(fire_timing.cooldown_ticks))/config.tick_rate
	var equipped_cycle := float(int(dark_timing.startup_ticks)+int(dark_timing.cooldown_ticks))/config.tick_rate
	check(comparison[1].ends_with("cast cycle %.2fs -> %.2fs." % [equipped_cycle,selected_cycle]),"equipped comparison uses the same once-converted authoritative tick totals")
	check(Inspector.inspect(-1).is_empty(),"invalid wires have no invented facts")
	_test_live_timing_mutation()
	return finish("spell-inspector")


func _test_live_timing_mutation() -> void:
	var abilities := AbilityCatalog.new()
	var champions := ChampionCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"),"comparison loads real spells")
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json",abilities),"comparison loads real identity")
	var state := PlayerState.new(1)
	check(champions.apply_to_player(state,String(champions.champion_ids_by_wire[10])),"high Flux champion is configured through catalog")
	state.position_x=5_000_000
	state.position_y=5_000_000
	state.spawn_protection_ticks=0
	var wire := Mixtures.wire_for(2,"heavy")
	check(state.place_proven_spell(0,wire),"comparison equips Heavy before real payment")
	var source := CombatTuning.cast_definition(wire)
	state.flux=state.flux_maximum*2/3+int(source.flux_cost)/2
	var before := Inspector.inspect(wire,state)
	var transition := ActionTransitionPolicy.new()
	check(transition.load_from_file(),"comparison uses real cast transition")
	var config := SimConfig.new()
	var arena := CollisionWorld.new(10_000_000,10_000_000)
	CombatSystem.step_player(state,SimCommand.new(0,1,0,0,0,SimCommand.PRESSED_SPELL_1),config,1000,2000,arena,[],transition)
	equal(state.pending_cast_wire_id,wire,"projection fixture crosses threshold through paid admission")
	equal(state.pending_cast_ticks,int(before.startup_ticks),"shown preparation agrees with admitted timer")
	var after_payment := Inspector.inspect(wire,state)
	check(int(after_payment.startup_ticks)>int(before.startup_ticks),"same object loses high Flux startup advantage after payment")
	check(int(after_payment.cooldown_ticks)<int(before.cooldown_ticks),"same object projects changed release cooldown")
	var pending := state.pending_cast_ticks
	SpellStatusPolicy.apply_hit(state,Mixtures.wire_for(1,"bolt"),1,2,state.team_id+1,1000,config,Vector2i(1000,0))
	check(SpellStatusPolicy.active(state,0),"Fractured fixture applies through status admission")
	var fractured := Inspector.inspect(wire,state)
	check(int(fractured.startup_ticks)>int(after_payment.startup_ticks),"same object reflects Fractured for the next preparation")
	equal(state.pending_cast_ticks,pending,"inspection cannot retime an already paid cast")
