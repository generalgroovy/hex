class_name HexExpandedDelivery
extends RefCounted
## Persistent delivery state lives exclusively on replicated ProjectileState.
const Parts = preload("res://src/sim/hex/hex_cast_parts.gd")
const Perks = preload("res://src/sim/entities/identity_perk_policy.gd")

static func initialize(shot: ProjectileState, config: SimConfig) -> void:
	var family := MixtureCatalog.family_for_wire(shot.source_wire_id)
	if family in ["mantle","fuse"]: shot.delivery_damage_remaining = shot.damage
	if family == "split":
		shot.delivery_ticks = config.milliseconds_to_ticks(int(CombatTuning.cast_definition_view(shot.source_wire_id).get("split_delay_ms", 250)))
	if family == "mantle":
		shot.velocity_x = 0
		shot.velocity_y = 0
		shot.remaining_distance = -1

static func stationary(shot: ProjectileState) -> bool:
	return MixtureCatalog.family_for_wire(shot.source_wire_id) == "mantle" or shot.delivery_phase == 1

static func arm(shot: ProjectileState, config: SimConfig) -> void:
	shot.delivery_phase = 1
	shot.delivery_ticks = config.milliseconds_to_ticks(600)
	shot.lifetime_ticks = shot.delivery_ticks+1
	shot.velocity_x = 0
	shot.velocity_y = 0
	shot.remainder_x = 0
	shot.remainder_y = 0
	shot.remaining_distance = -1
	shot.range_subunit = 0

static func prepare(world: SimWorld) -> Array[ProjectileState]:
	var held: Array[ProjectileState] = []
	var moving: Array[ProjectileState] = []
	var children: Array[ProjectileState] = []
	for shot: ProjectileState in world.projectiles.duplicate():
		var ledger: Dictionary = world.hex_court.ledger_for_source(shot.source_cast_id)
		if ledger.is_empty() or int(ledger.remaining_strength) <= 0 or world.hex_court.flight_quantity(shot.source_cast_id,shot.entity_id) <= 0: continue
		var family := MixtureCatalog.family_for_wire(shot.source_wire_id)
		if family == "mantle":
			var owner: PlayerState = world.player(shot.owner_id)
			if owner == null or owner.health <= 0:
				retire(world,shot)
				continue
			shot.previous_x = shot.position_x
			shot.previous_y = shot.position_y
			shot.position_x = owner.position_x
			shot.position_y = owner.position_y
			apply_area(world,shot,shot.radius,4000,owner.air_height)
			var record: Dictionary = world.hex_court.casts.get(int(world.hex_court.sources.get(shot.source_cast_id,0)),{})
			for part: Dictionary in record.get("ground_parts",{}).values():
				if not bool(part.trail) or world.tick >= int(part.expiry_tick): continue
				var point: Vector2i = part.footprint.get("center",Vector2i(shot.position_x,shot.position_y))
				shot.position_x = point.x
				shot.position_y = point.y
				apply_area(world,shot,HexTrailEmitter.RADIUS,2000)
			shot.position_x = owner.position_x
			shot.position_y = owner.position_y
			shot.lifetime_ticks -= 1
			if shot.lifetime_ticks <= 0 or shot.delivery_damage_remaining <= 0: retire(world,shot)
			else: held.append(shot)
		elif family == "fuse" and shot.delivery_phase == 1:
			shot.delivery_ticks = maxi(0,shot.delivery_ticks-1)
			shot.lifetime_ticks = maxi(1,shot.lifetime_ticks-1)
			if shot.delivery_ticks == 0:
				apply_area(world,shot,int(CombatTuning.cast_definition_view(shot.source_wire_id).blast_radius),shot.delivery_damage_remaining)
				retire(world,shot)
			else: held.append(shot)
		else:
			if family == "split" and shot.delivery_phase == 0:
				shot.delivery_ticks = maxi(0,shot.delivery_ticks-1)
				if shot.delivery_ticks == 0 and world.projectiles.size() < SimConfig.MAX_ACTIVE_PROJECTILES and world.available_cast_capacity(shot.owner_id).x > 0:
					var child := split(world,shot)
					if child != null:
						children.append(child)
						# Reserve immediately so another parent sees owner/global/pending limits.
						world.projectiles.append(child)
			moving.append(shot)
	moving.append_array(children)
	moving.append_array(held) # Stationary spells still own physical capacity.
	world.projectiles = moving
	return held

static func split(world: SimWorld, shot: ProjectileState) -> ProjectileState:
	if shot.damage < 2 or not world.hex_court.split_flight(shot.source_cast_id,shot.entity_id,world.next_projectile_id): return null
	var original := Vector2i(shot.velocity_x,shot.velocity_y)
	var child_damage := shot.damage/2
	shot.damage -= child_damage
	var child := ProjectileState.new(world.next_projectile_id,shot.owner_id,shot.team_id,shot.source_wire_id,shot.element_wire_id,Vector2i(shot.position_x,shot.position_y),ElementChemistrySystem.rotated_fifteen(original,-1),shot.radius,child_damage,shot.lifetime_ticks)
	world.next_projectile_id += 1
	child.source_cast_id = shot.source_cast_id
	child.reaction_strength = shot.reaction_strength
	child.initial_strength = shot.initial_strength
	child.remaining_strength = shot.remaining_strength
	child.remaining_distance = shot.remaining_distance
	child.range_subunit = shot.range_subunit
	child.material_strength = shot.material_strength/2
	shot.material_strength -= child.material_strength
	child.chemistry_interaction_mask = shot.chemistry_interaction_mask
	child.grazed_entity_ids = shot.grazed_entity_ids.duplicate()
	child.contact_entity_ids = shot.contact_entity_ids.duplicate()
	shot.delivery_phase = 2
	child.delivery_phase = 2
	var left := ElementChemistrySystem.rotated_fifteen(original,1)
	shot.velocity_x = left.x
	shot.velocity_y = left.y
	shot.remainder_x = 0
	shot.remainder_y = 0
	world.combat_events.append({"type":"projectile_split","projectile_id":shot.entity_id,"child_id":child.entity_id,"source_wire_id":shot.source_wire_id,"owner_id":shot.owner_id})
	return child

static func apply_area(world: SimWorld, shot: ProjectileState, radius: int, quote: int, height: int = 0) -> void:
	var origin := Vector2i(shot.position_x,shot.position_y)
	var ordered: Array[PlayerState] = world.players.duplicate()
	ordered.sort_custom(func(a: PlayerState,b: PlayerState)->bool:return a.entity_id<b.entity_id)
	for target: PlayerState in ordered:
		if shot.delivery_damage_remaining <= 0 or shot.contact_entity_ids.size() >= 12: break
		if target.entity_id == shot.owner_id or target.team_id == shot.team_id or target.health <= 0 or target.spawn_protection_ticks > 0 or MovementSystem.is_combat_intangible(target,world.config): continue
		if shot.contact_entity_ids.has(target.entity_id): continue
		if height == 0 and MovementSystem.avoids_ground_effects(target): continue
		if height > 0 and absi(height-target.air_height) > 20_000: continue
		var point := Vector2i(target.position_x,target.position_y)
		if (point-origin).length_squared() > (radius+target.radius)*(radius+target.radius): continue
		if not SprayInterception.clear_ray(origin,point,world.collision,[],world.tick): continue
		var raw_quote := quote*shot.remaining_strength/maxi(1,shot.initial_strength)
		# Preserve the authored quote; cap only the final, perk-scaled pool debit.
		var ratio := Perks.ratio(target,"incoming_damage_ratio")
		var maximum_quote := ((shot.delivery_damage_remaining+1)*1000-1)/ratio
		var damage := mini(raw_quote,maximum_quote)
		var before := target.health
		if damage<=0 or not PlayerResourcesSystem.damage(target,damage,world.config): continue
		var loss := before-target.health
		shot.delivery_damage_remaining -= loss
		shot.contact_entity_ids.append(target.entity_id)
		shot.contact_entity_ids.sort()
		SpellStatusPolicy.apply_hit(target,shot.source_wire_id,shot.source_cast_id,shot.owner_id,shot.team_id,loss,world.config,SimCommand._normalized_direction(point.x-origin.x,point.y-origin.y))
		world.combat_events.append({"type":"projectile_hit","projectile_id":shot.entity_id,"source_wire_id":shot.source_wire_id,"owner_id":shot.owner_id,"target_id":target.entity_id,"damage":loss})
		if target.actor_kind == PlayerState.ActorKind.CHAMPION and target.health == 0: world.combat_events.append({"type":"champion_defeated","projectile_id":shot.entity_id,"owner_id":shot.owner_id,"target_id":target.entity_id})

static func retire(world: SimWorld, shot: ProjectileState) -> void:
	# Deposit only the branch's still-owned material; never another damage blast.
	CombatSystem._emit_terminal(shot,world.combat_events,"range",Vector2i(shot.position_x,shot.position_y))
	var event: Dictionary = world.combat_events.back()
	world.hex_court.deposit_terminal(event,world.tick)
	event.hex_committed = true
