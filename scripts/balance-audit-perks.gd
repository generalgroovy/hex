extends RefCounted
## Offline condition-specific consumer probes, not natural activation frequency
## or a playtest. Fixture state is prepared once; the actual runtime consumer
## determines measured outcomes and can close the prepared window.
@warning_ignore_start("integer_division")
const Perks = preload("res://src/sim/entities/identity_perk_policy.gd")
const Races = preload("res://src/content/race_perk_catalog.gd")
const Characters = preload("res://src/content/character_perk_catalog.gd")
const Fixtures = preload("res://tests/support/identity_perk_scenarios.gd")


static func build(champions: ChampionCatalog) -> Array[Dictionary]:
	var rows := Races.all()
	rows.append_array(Characters.all())
	var result: Array[Dictionary] = []
	for row: Dictionary in rows:
		var wire := int(row.get("wire_id",0))
		if row.has("ancestry"):
			for candidate: int in champions.champion_ids_by_wire:
				if Races.ancestry_for_wire(candidate)==String(row.ancestry):
					wire = candidate
					break
		if wire <= 0: return [{"error":"missing real champion for perk "+String(row.id)}]
		var observations: Array[Dictionary] = []
		var nonzero := 0
		var useful := 0
		for effect: String in row.effects:
			var probe := _probe(champions,wire,row,effect)
			if probe.has("error"): return [probe]
			observations.append(probe)
			if int(probe.delta)!=0: nonzero += 1
			if bool(probe.favorable): useful += 1
		result.append({"id":String(row.id), "name":String(row.name), "champion_wire_id":wire,
			"condition":String(row.condition), "window":String(row.window), "counter":String(row.counter),
			"kind":"ancestry" if row.has("ancestry") else "character", "observations":observations,
			"nonzero_consumer_deltas":nonzero, "favorable_consumer_deltas":useful, "needs_followup":useful==0,
			"scope":"Prepared condition probes compare the real combined identity with the same champion stats and identities disabled. Deltas can include both passives; they are not individual causal attribution or natural gameplay activation.",
			"scenario":"Prepare "+String(row.window)+" Then exercise each listed runtime consumer without changing the fixture mid-probe.",
			"reference":String(row.reference)})
	return result


static func _actor(champions: ChampionCatalog, wire: int, row: Dictionary, enabled: bool) -> PlayerState:
	var state := PlayerState.new(1)
	if not champions.apply_to_player(state,champions.champion_id_from_wire(wire)): return null
	state.position_x = 5000000
	state.position_y = 5000000
	state.health = state.health_maximum/2
	state.flux = state.flux_maximum/2
	state.stamina = state.stamina_maximum/2
	state.spawn_protection_ticks = 0
	if not Fixtures.prepare(state,String(row.condition)): return null
	if not enabled: state.champion_wire_id = 0
	return state


static func _probe(champions: ChampionCatalog, wire: int, row: Dictionary, effect: String) -> Dictionary:
	var active := _actor(champions,wire,row,true)
	var control := _actor(champions,wire,row,false)
	var reserve_note := "Default prepared resource window."
	if effect=="spell_cooldown_ratio" and String(row.condition).split("&").has("high_flux") and active!=null:
		# Cooldown samples release, after the real payment. Start stocked so a
		# useful high-Flux release is measured; the separate inspector regression
		# deliberately crosses the threshold and proves loss of this benefit.
		active.flux = active.flux_maximum
		control.flux = control.flux_maximum
		reserve_note = "Initial full Flux; ordinary Heavy payment must leave the high-Flux release condition active."
	# Braking is observable only with momentum to lose. This is part of the
	# initial prepared condition, never a mid-probe velocity grant.
	if effect=="ground_braking_ratio" and active!=null and active.velocity_x==0:
		active.velocity_x = MovementTuning.BASE_SPEED/2
		control.velocity_x = active.velocity_x
	if active == null or control == null or not Perks.condition_matches(active,String(row.condition)):
		return {"error":"cannot prepare explicit perk window "+String(row.id)}
	var config := SimConfig.new()
	var ratio := Perks.ratio(active,effect)
	var enabled_value := _consume(active,effect,config)
	var control_value := _consume(control,effect,config)
	if enabled_value < 0 or control_value < 0:
		return {"error":"runtime consumer refused prepared perk window "+String(row.id)+": "+effect}
	var lower_is_favorable := effect in ["incoming_damage_ratio","knockback_ratio","movement_cost_ratio","spell_startup_ratio","spell_cooldown_ratio"]
	var favorable := enabled_value < control_value if lower_is_favorable else enabled_value > control_value
	var result := {"effect":effect, "authored_ratio":int(row.effects[effect]), "combined_ratio_before":ratio,
		"enabled":enabled_value, "control":control_value, "delta":enabled_value-control_value,
		"favorable":favorable, "lower_is_favorable":lower_is_favorable,
		"prepared_reserve":reserve_note,
		"window_active_after":Perks.condition_matches(active,String(row.condition)),
		"measurement":"Actual runtime consumer output in fixed simulation units; lower is favorable only for cost/damage/knockback/timing.",
		"result":"observed_difference" if enabled_value!=control_value else "zero_or_suppressed_in_this_context"}
	if effect in ["spell_startup_ratio","spell_cooldown_ratio"]:
		var fresh := _actor(champions,wire,row,true)
		var rapid := Perks.spell_timing(fresh,CombatTuning.cast_definition_view(MixtureCatalog.wire_for(2,"rapid")),config)
		result["rapid_startup_ticks"] = int(rapid.startup_ticks)
		result["rapid_cooldown_ticks"] = int(rapid.cooldown_ticks)
		result["rapid_suppressed_pairs"] = rapid.suppressed_pairs
	return result


static func _consume(state: PlayerState, effect: String, config: SimConfig) -> int:
	match effect:
		"incoming_damage_ratio":
			var before := state.health
			PlayerResourcesSystem.damage(state,10000,config)
			return before-state.health
		"knockback_ratio":
			MovementSystem.apply_control_state(state,PlayerState.ControlState.LAUNCHED,200,Vector2i(1000,0),400000,config)
			return state.control_speed
		"health_recovery_ratio", "flux_recovery_ratio":
			var resource := "health" if effect=="health_recovery_ratio" else "flux"
			var before := int(state.get(resource))
			PlayerResourcesSystem.step(state,config)
			return int(state.get(resource))-before
		"stamina_recovery_ratio":
			var before := state.stamina
			MovementSystem._apply_stamina_rate(state,state.stamina_recovery_per_second,config)
			return state.stamina-before
		"movement_cost_ratio":
			var cost := MovementSystem._movement_action_cost(state,MovementTuning.DOUBLE_JUMP_COST)
			if state.stamina < cost: return -1
			var before := state.stamina
			MovementSystem._spend_movement_action(state,cost,config)
			return before-state.stamina
		"air_steering_ratio":
			MovementSystem._apply_air_velocity(state,SimCommand.new(0,1,0,1000),Vector2i(0,1000),config)
			return state.air_velocity_y
		"ground_acceleration_ratio":
			MovementSystem._apply_ground_velocity(state,SimCommand.new(0,1,0,1000),Vector2i(0,1000),config,false)
			return state.velocity_y
		"ground_braking_ratio":
			var before := state.velocity_x
			if state.jumpsquat_active:
				MovementSystem._apply_jumpsquat_drag(state,config,1000)
			else:
				var held := SimCommand.HELD_SPRINT if state.sprinting else 0
				MovementSystem._apply_ground_velocity(state,SimCommand.new(0,1,-1000,0,held),Vector2i(-1000,0),config,false)
			return before-state.velocity_x
		"ground_speed_ratio":
			var held := SimCommand.HELD_SPRINT if state.sprinting else 0
			for tick: int in range(32):
				MovementSystem._apply_ground_velocity(state,SimCommand.new(tick,1,1000,0,held),Vector2i(1000,0),config,false)
			return state.velocity_x
		"spell_startup_ratio", "spell_cooldown_ratio":
			var wire := MixtureCatalog.wire_for(2,"heavy")
			state.place_proven_spell(0,wire)
			var transition := ActionTransitionPolicy.new()
			if not transition.load_from_file(): return -1
			var arena := CollisionWorld.new(10000000,10000000)
			CombatSystem.step_player(state,SimCommand.new(0,1,0,0,0,SimCommand.PRESSED_SPELL_1),config,1000,2000,arena,[],transition)
			if state.pending_cast_wire_id != wire: return -1
			var startup := state.pending_cast_ticks
			if effect=="spell_startup_ratio": return startup
			for tick: int in range(startup):
				CombatSystem.step_player(state,SimCommand.new(tick+1,1),config,1000,2000,arena,[],transition)
			return state.spell_cooldown_for_wire(wire)
	return -1
