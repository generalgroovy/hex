extends RefCounted
## Bounded offline experiments through ordinary SimWorld commands. These report
## what these fixtures do, not a PvP tier list or a balance acceptance.
@warning_ignore_start("integer_division")
const Mixtures = preload("res://src/content/mixture_catalog.gd")
const DamageEvent = preload("res://src/sim/combat/combat_damage_event.gd")
const Perks = preload("res://src/sim/entities/identity_perk_policy.gd")
const RivalPolicy = preload("res://src/app/signature_rival_policy.gd")
const CAST_TICKS := 720
const DRAIN_TICKS := 360
const TARGET_HEALTH := 2000000 # Diagnostic durability only; prevents a DPS ceiling from target death.


static func build(abilities: AbilityCatalog, champions: ChampionCatalog) -> Array[Dictionary]:
	var bolt_rotation: Array[int] = []
	for mask: int in [1,2,4,8,16,32,3,5,6,9,10,12]: bolt_rotation.append(Mixtures.wire_for(mask,"bolt"))
	var weave: Array[int] = []
	for pair: Array in [[2,"bolt"],[4,"bolt"],[2,"heavy"],[4,"heavy"],[2,"rapid"],[4,"rapid"],[4,"spray"],[1,"spray"],[2,"mantle"],[6,"fuse"],[10,"split"],[48,"rebound"]]:
		weave.append(Mixtures.wire_for(int(pair[0]),String(pair[1])))
	var cases: Array[Dictionary] = [
		{"id":"fire_bolt_open", "wires":[Mixtures.wire_for(2,"bolt")], "target":"stationary", "cover":false},
		{"id":"steam_bolt_open", "wires":[Mixtures.wire_for(6,"bolt")], "target":"stationary", "cover":false},
		{"id":"all_six_bolt_open", "wires":[Mixtures.wire_for(63,"bolt")], "target":"stationary", "cover":false},
		{"id":"twelve_bolts_open", "wires":bolt_rotation, "target":"stationary", "cover":false},
		{"id":"twelve_forms_open", "wires":weave, "target":"stationary", "cover":false},
		{"id":"twelve_bolts_moving", "wires":bolt_rotation, "target":"moving", "cover":false},
		{"id":"twelve_bolts_cover", "wires":bolt_rotation, "target":"stationary", "cover":true},
		{"id":"twelve_forms_cover", "wires":weave, "target":"stationary", "cover":true},
		{"id":"rapid_small_open", "wires":[Mixtures.wire_for(16,"rapid")], "target":"stationary", "cover":false, "size_exemplar":"s_wayne"},
		{"id":"rapid_large_open", "wires":[Mixtures.wire_for(16,"rapid")], "target":"stationary", "cover":false, "size_exemplar":"ba_djoh"},
		{"id":"rapid_small_moving", "wires":[Mixtures.wire_for(16,"rapid")], "target":"moving", "cover":false, "size_exemplar":"s_wayne"},
		{"id":"rapid_large_moving", "wires":[Mixtures.wire_for(16,"rapid")], "target":"moving", "cover":false, "size_exemplar":"ba_djoh"},
		{"id":"fire_bolt_opposed", "wires":[Mixtures.wire_for(2,"bolt")], "target":"stationary", "cover":false, "opposition":true},
		{"id":"fire_bolt_opposed_strafe", "wires":[Mixtures.wire_for(2,"bolt")], "target":"moving", "cover":false, "opposition":true, "actor_route":"strafe"},
		{"id":"mantle_close_pursuit", "wires":[Mixtures.wire_for(8,"mantle")], "target":"moving", "cover":false, "distance":60000, "actor_route":"pursue"},
		{"id":"fuse_moving", "wires":[Mixtures.wire_for(6,"fuse")], "target":"moving", "cover":false},
		{"id":"split_open", "wires":[Mixtures.wire_for(10,"split")], "target":"stationary", "cover":false},
		{"id":"split_corridor", "wires":[Mixtures.wire_for(10,"split")], "target":"stationary", "cover":false, "corridor":true},
		{"id":"rebound_bank_cover", "wires":[Mixtures.wire_for(48,"rebound")], "target":"stationary", "cover":true, "bank":true},
		{"id":"spray_close", "wires":[Mixtures.wire_for(1,"spray")], "target":"moving", "cover":false, "distance":140000},
		{"id":"split_led_open", "wires":[Mixtures.wire_for(10,"split")], "target":"stationary", "cover":false, "lead_fan":true},
		{"id":"rebound_bank_route", "wires":[Mixtures.wire_for(48,"rebound")], "target":"stationary", "cover":true, "bank":true, "bank_surface":true},
		{"id":"rebound_direct_blocked", "wires":[Mixtures.wire_for(48,"rebound")], "target":"stationary", "cover":true, "bank_surface":true},
	]
	var result: Array[Dictionary] = []
	for scenario: Dictionary in cases: result.append(_run(scenario,abilities,champions))
	return result


static func _run(scenario: Dictionary, abilities: AbilityCatalog, champions: ChampionCatalog) -> Dictionary:
	var world := SimWorld.new()
	if not champions.apply_to_player(world.player(),"oh_tipi") or not HexCourtPractice.configure(world,abilities):
		return {"id":scenario.id,"error":"cannot configure ordinary diagnostic court"}
	var actor := world.player()
	var target := world.player(2)
	target.health_maximum = TARGET_HEALTH
	target.health = TARGET_HEALTH
	var size_exemplar := String(scenario.get("size_exemplar", ""))
	if not size_exemplar.is_empty():
		var size_actor := PlayerState.new()
		if not champions.apply_to_player(size_actor, size_exemplar): return {"id":scenario.id,"error":"invalid body-size exemplar"}
		target.radius = size_actor.radius # Only hurt size varies in this matched experiment.
	if scenario.has("distance"):
		target.position_y = actor.position_y-int(scenario.distance)
		target.training_spawn_y = target.position_y
	var opposed := bool(scenario.get("opposition", false))
	if opposed:
		target.flux_maximum = PlayerTuning.FLUX_MAXIMUM
		target.flux = target.flux_maximum
		target.flux_recovery_per_second = PlayerTuning.FLUX_RECOVERY_PER_SECOND
		target.spell_wire_ids.fill(0)
		if not target.place_proven_spell(0, Mixtures.wire_for(16,"rapid")): return {"id":scenario.id,"error":"opponent cannot equip its paid attack"}
	actor.spell_wire_ids.fill(0)
	for index: int in scenario.wires.size():
		if not actor.place_proven_spell(index,int(scenario.wires[index])): return {"id":scenario.id,"error":"cannot equip diagnostic weave"}
	if bool(scenario.cover): world.collision.add_obstacle(CollisionWorld.Obstacle.new(90,520000,570000,760000,615000))
	if bool(scenario.get("bank_surface", false)):
		# A side face permits two clear reflected legs around the original cover.
		# The matched direct-aim control receives exactly the same solid geometry.
		world.collision.add_obstacle(CollisionWorld.Obstacle.new(93,300000,350000,320000,900000))
	if bool(scenario.get("corridor", false)):
		world.collision.add_obstacle(CollisionWorld.Obstacle.new(91,530000,350000,580000,760000))
		world.collision.add_obstacle(CollisionWorld.Obstacle.new(92,700000,350000,750000,760000))
	var result := {"id":String(scenario.id), "wire_ids":scenario.wires.duplicate(), "slots":scenario.wires.size(),
		"target_motion":String(scenario.target), "solid_cover":bool(scenario.cover), "cast_ticks":CAST_TICKS, "drain_ticks":DRAIN_TICKS,
		"target_radius":target.radius, "size_exemplar":size_exemplar, "size_scope":"Exemplar supplies hurt radius only; all other target properties stay matched.",
		"corridor":bool(scenario.get("corridor", false)), "bank_aim":bool(scenario.get("bank", false)), "actor_route":String(scenario.get("actor_route", "stationary")),
		"opposed":opposed, "opponent_paid_casts":0, "opponent_paid_flux":0, "damage_taken":0,
		"actor_distance_travelled":0, "perk_active_ticks":{},
		"paid_casts":0, "paid_flux":0, "damage":0, "direct_damage":0, "ground_damage":0, "status_damage":0, "self_damage":0, "hit_events":0, "first_hit_tick":-1,
		"first_flux_wait_tick":-1, "flux_wait_ticks":0, "ready_wait_ticks":0, "refused_casts":0,
		"peak_projectiles":0, "peak_products":0, "active_status_ticks":[0,0,0,0,0,0],
		"valid_bank_requests":0, "split_events":0, "bank_events":0, "delivery_hits":[],
		"direct_route_blocked":not ContinuousContact.wall_contact(Vector2i(actor.position_x,actor.position_y),Vector2i(target.position_x,target.position_y),int(CombatTuning.cast_definition_view(int(scenario.wires[0])).radius),world.collision).is_empty()}
	var by_wire := {}
	var recipes := {}
	var flight_witnesses := {}
	var cursor := 0
	var actor_previous := Vector2i(actor.position_x,actor.position_y)
	for tick: int in range(CAST_TICKS+DRAIN_TICKS):
		_observe_delivery_flights(world,flight_witnesses)
		var slot := -1
		var flux_wait := false
		if tick < CAST_TICKS and actor.pending_cast_wire_id == 0:
			for offset: int in range(scenario.wires.size()):
				var index := posmod(cursor+offset,scenario.wires.size())
				var wire := int(scenario.wires[index])
				if actor.spell_cooldown_for_wire(wire)>1: continue
				if actor.flux<int(CombatTuning.cast_definition_view(wire).flux_cost):
					flux_wait = true
					continue
				slot = index
				break
			if slot<0:
				result.flux_wait_ticks += int(flux_wait)
				result.ready_wait_ticks += int(not flux_wait)
				if flux_wait and int(result.first_flux_wait_tick)<0: result.first_flux_wait_tick = tick
		var delta := Vector2i(target.position_x-actor.position_x,target.position_y-actor.position_y)
		var pressed := SimCommand.SPELL_PRESSED_BITS[slot] if slot>=0 else 0
		# Ground targets are explicit only for Fuse; other families retain their
		# authored travel so a cursor endpoint cannot erase their delivery identity.
		var ground := Vector2i(target.position_x,target.position_y) if slot>=0 and Mixtures.family_for_wire(int(scenario.wires[slot]))=="fuse" else Vector2i(-1,-1)
		var target_move := (1000 if posmod(tick,240)<120 else -1000) if String(scenario.target)=="moving" else 0
		var actor_move := Vector2i.ZERO
		if String(scenario.get("actor_route", "")) == "strafe": actor_move.x = 1000 if posmod(tick,240)<120 else -1000
		if String(scenario.get("actor_route", "")) == "pursue" and delta.length_squared() > 30000*30000: actor_move = SimCommand._normalized_direction(delta.x,delta.y)
		var aim := RivalPolicy.committed_aim(Vector2i(actor.position_x,actor.position_y),Vector2i(target.position_x,target.position_y),CombatTuning.cast_definition_view(int(scenario.wires[0])),world.collision) if bool(scenario.get("bank",false)) else delta
		if bool(scenario.get("lead_fan",false)):
			# At this close range, a 7.5-degree command compensates the actual
			# muzzle/pre-fork offset. The paid probe preserves the 15-degree miss.
			aim = Vector2i((delta.x*991-delta.y*131)/1000,(delta.x*131+delta.y*991)/1000)
		if pressed != 0 and bool(scenario.get("bank",false)) and RivalPolicy.bank_target(Vector2i(actor.position_x,actor.position_y),Vector2i(target.position_x,target.position_y),CombatTuning.cast_definition_view(int(scenario.wires[0])),world.collision) != Vector2i(-1,-1):
			result.valid_bank_requests += 1
		var opponent_pressed := SimCommand.SPELL_PRESSED_BITS[0] if opposed and tick<CAST_TICKS and posmod(tick,30)==0 else 0
		var commands: Array[SimCommand] = [SimCommand.new(tick,1,actor_move.x,actor_move.y,0,pressed,aim.x,aim.y,ground.x,ground.y),SimCommand.new(tick,2,target_move,0,0,opponent_pressed,-delta.x,-delta.y)]
		if not world.step(commands): return {"id":scenario.id,"error":world.last_error}
		_observe_delivery_flights(world,flight_witnesses)
		var actor_point := Vector2i(actor.position_x,actor.position_y)
		result.actor_distance_travelled += int((actor_point-actor_previous).length())
		actor_previous = actor_point
		for perk: Dictionary in Perks.active_rows(actor):
			var id := String(perk.id)
			result.perk_active_ticks[id] = int(result.perk_active_ticks.get(id,0))+1
		for event: Dictionary in world.combat_events:
			var kind := String(event.get("type",""))
			var projectile_id := int(event.get("projectile_id",0))
			if kind=="projectile_split" and int(event.get("owner_id",0))==1 and flight_witnesses.has(projectile_id):
				var parent: Dictionary = flight_witnesses[projectile_id]
				parent.split = true
				var child_id := int(event.get("child_id",0))
				if flight_witnesses.has(child_id) and int(flight_witnesses[child_id].source)==int(parent.source):
					flight_witnesses[child_id].split = true
				result.split_events += 1
			elif kind=="projectile_rebounded" and flight_witnesses.has(projectile_id):
				flight_witnesses[projectile_id].banked = true
				result.bank_events += 1
			elif kind=="projectile_hit" and int(event.get("owner_id",0))==1 and int(event.get("target_id",0))==2 and int(event.get("damage",0))>0 and flight_witnesses.has(projectile_id):
				var witness: Dictionary = flight_witnesses[projectile_id]
				if bool(witness.paid) and (bool(witness.split) or bool(witness.banked)) and int(witness.wire)==int(event.get("source_wire_id",0)):
					result.delivery_hits.append({"projectile_id":projectile_id,"source_id":int(witness.source),"wire_id":int(witness.wire),
						"split":bool(witness.split),"banked":bool(witness.banked),"damage":int(event.damage),"hit_tick":tick,
						"initial_strength":int(witness.initial_strength),"last_observed_strength":int(witness.remaining_strength),
						"last_observed_remaining_distance":int(witness.remaining_distance)})
			if kind=="cast_started" and int(event.get("entity_id",0))==1:
				var wire := int(event.wire_id)
				result.paid_casts += 1
				result.paid_flux += int(CombatTuning.cast_definition_view(wire).flux_cost)
				by_wire[wire] = int(by_wire.get(wire,0))+1
				cursor = posmod(slot+1,scenario.wires.size())
			elif kind=="cast_started" and int(event.get("entity_id",0))==2:
				result.opponent_paid_casts += 1
				result.opponent_paid_flux += int(CombatTuning.cast_definition_view(int(event.wire_id)).flux_cost)
			elif kind=="cast_refused" and int(event.get("entity_id",0))==1: result.refused_casts += 1
			var damage := DamageEvent.amount(event)
			if damage>0 and int(event.get("owner_id",0))==1 and DamageEvent.target_id(event)==2:
				result.damage += damage
				var category := "status_damage" if kind=="spell_status_hit" else ("ground_damage" if kind in ["hex_pressure","hex_conflagration","chemistry_hit"] else "direct_damage")
				result[category] += damage
				result.hit_events += 1
				if int(result.first_hit_tick)<0: result.first_hit_tick = tick
			elif damage>0 and DamageEvent.target_id(event)==1:
				result.damage_taken += damage
				if int(event.get("owner_id",0))==1: result.self_damage += damage
		result.peak_projectiles = maxi(int(result.peak_projectiles),world.projectiles.size())
		result.peak_products = maxi(int(result.peak_products),world.hex_court.products.size())
		for product: Dictionary in world.hex_court.products.values(): recipes[int(product.recipe_wire_id)] = true
		for channel: int in range(6): result.active_status_ticks[channel] += int(SpellStatusPolicy.active(target,channel))
	result["cast_counts_by_wire"] = by_wire
	var recipe_ids := recipes.keys()
	recipe_ids.sort()
	result["recipe_wire_ids_seen"] = recipe_ids
	result["remaining_flux"] = actor.flux
	result["actor_health_remaining"] = actor.health
	result["opponent_flux_remaining"] = target.flux
	result["target_health_loss"] = TARGET_HEALTH-target.health
	result["live_projectiles_end"] = world.projectiles.size()
	result["damage_per_flux_permille"] = int(result.damage)*1000/maxi(1,int(result.paid_flux))
	result["world_hash"] = world.state_hash()
	result["matter_paid"] = int(world.hex_court.metrics.matter_paid)
	result["conservation_valid"] = world.hex_court.conservation_valid()
	return result


static func _observe_delivery_flights(world: SimWorld, witnesses: Dictionary) -> void:
	# Detached observations of real authority, never a flight/source grant. Both
	# sides of a step retain the identity when contact removes the live projectile.
	for shot: ProjectileState in world.projectiles:
		if shot.owner_id != 1 or Mixtures.family_for_wire(shot.source_wire_id) not in ["split","rebound"]: continue
		var cast_id := int(world.hex_court.sources.get(shot.source_cast_id,0))
		var record: Dictionary = world.hex_court.casts.get(cast_id,{})
		var paid: bool = bool(record.get("paid",false)) and int(record.get("owner",0))==shot.owner_id and int(record.get("wire",0))==shot.source_wire_id and world.hex_court.flight_quantity(shot.source_cast_id,shot.entity_id)>0
		if not witnesses.has(shot.entity_id):
			witnesses[shot.entity_id] = {"source":shot.source_cast_id,"wire":shot.source_wire_id,"paid":paid,
				"initial_strength":shot.initial_strength,"remaining_strength":shot.remaining_strength,
				"remaining_distance":shot.remaining_distance,"split":false,"banked":false}
		else:
			var row: Dictionary = witnesses[shot.entity_id]
			row.paid = bool(row.paid) and paid and int(row.source)==shot.source_cast_id and int(row.wire)==shot.source_wire_id
			row.remaining_strength = mini(int(row.remaining_strength),shot.remaining_strength)
			row.remaining_distance = mini(int(row.remaining_distance),shot.remaining_distance)
