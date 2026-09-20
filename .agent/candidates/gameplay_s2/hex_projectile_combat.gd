class_name HexProjectileCombat
extends RefCounted
@warning_ignore_start("integer_division")

# Ordered combat for the explicitly solo hex migration world. Production
# legacy chemistry uses its existing separate adapter until migrated.
static func sync_strength(world: SimWorld) -> bool:
	for shot: ProjectileState in world.projectiles:
		var ledger: Dictionary = world.hex_court.ledger_for_source(shot.source_cast_id)
		if ledger.is_empty() or not StrengthBudget.validate(ledger):
			world.last_error = "hex projectile has no valid paid source ledger"
			return false
		shot.initial_strength = int(ledger.initial_strength)
		shot.remaining_strength = int(ledger.remaining_strength)
	return true


static func _source(shot: ProjectileState) -> int:
	return shot.source_cast_id if shot.source_cast_id > 0 else shot.entity_id


# Instantaneous pulses all occupy time zero. Pair order is stable source ID,
# including simultaneous pulses; every pair is revalidated after subtraction.
static func resolve_sprays(world: SimWorld) -> void:
	if not sync_strength(world): return
	var pulses: Array[Dictionary] = []
	var requests := {}
	var retained: Array[Dictionary] = []
	for event: Dictionary in world.combat_events:
		if event.get("type", "") != "spray_requested":
			retained.append(event)
			continue
		var source := int(event.source_cast_id)
		var origin := Vector2i(int(event.origin_x), int(event.origin_y))
		var aim := Vector2i(int(event.aim_x), int(event.aim_y))
		var definition := CombatSystem.spray_request_definition(event)
		var endpoint := origin + ElementChemistrySystem.scaled(aim, int(definition.range))
		var wall := ContinuousContact.wall_contact(origin, endpoint, int(definition.radius), world.collision)
		if not wall.is_empty(): endpoint = wall.center
		var offset := endpoint - origin
		var reach := SimCommand._integer_square_root(offset.x * offset.x + offset.y * offset.y)
		if reach <= 0:
			retained.append({"type": "cast_blocked", "entity_id": int(event.owner_id), "wire_id": int(event.source_wire_id)})
			continue
		definition.range = reach
		var pulse := {"source": source, "owner": int(event.owner_id), "wire": int(event.source_wire_id),
			"origin": origin, "aim": aim, "endpoint": endpoint, "definition": definition,
			"footprint": HexFootprint.sector(origin, aim, reach, int(definition.cone_cosine_squared_per_million))}
		pulses.append(pulse)
		requests[source] = pulse
	world.combat_events = retained
	var contacts: Array[Dictionary] = []
	for index: int in pulses.size():
		var pulse: Dictionary = pulses[index]
		for shot: ProjectileState in world.projectiles:
			if _source(shot) == int(pulse.source): continue
			var point := footprint_contact(pulse.footprint, HexFootprint.disk(Vector2i(shot.position_x, shot.position_y), shot.radius))
			if point.is_empty(): continue
			contacts.append({"first": mini(int(pulse.source), _source(shot)), "second": maxi(int(pulse.source), _source(shot)),
				"a": int(pulse.source), "b": _source(shot), "point": point.point})
		for other_index: int in range(index + 1, pulses.size()):
			var other: Dictionary = pulses[other_index]
			var point := footprint_contact(pulse.footprint, other.footprint)
			if point.is_empty(): continue
			contacts.append({"first": mini(int(pulse.source), int(other.source)), "second": maxi(int(pulse.source), int(other.source)),
				"a": int(pulse.source), "b": int(other.source), "point": point.point})
	contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.first) < int(b.first) if int(a.first) != int(b.first) else int(a.second) < int(b.second))
	for contact: Dictionary in contacts:
		var pulse: Dictionary = requests[int(contact.a)]
		if not SprayInterception.clear_ray(pulse.origin, contact.point, world.collision, [], world.tick): continue
		if requests.has(int(contact.b)) and not SprayInterception.clear_ray(requests[int(contact.b)].origin, contact.point, world.collision, [], world.tick): continue
		var outcome: Dictionary = world.hex_court.resolve_contact(int(contact.a), int(contact.b), contact.point, world.tick)
		if not bool(outcome.get("accepted", false)): continue
		world.combat_events.append({"type": "hex_clash", "source_wire_id": int(pulse.wire), "owner_id": int(pulse.owner),
			"x": contact.point.x, "y": contact.point.y, "matched_strength": int(outcome.matched_strength),
			"first_remaining": int(outcome.first.post_strength), "second_remaining": int(outcome.second.post_strength),
			"recipe_wire_id": int(outcome.get("recipe_wire_id", 0)), "reaction_id": int(outcome.get("reaction_id", 0))})
	pulses.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.source) < int(b.source))
	for pulse: Dictionary in pulses:
		var ledger: Dictionary = world.hex_court.ledger_for_source(int(pulse.source))
		if ledger.is_empty() or int(ledger.remaining_strength) <= 0: continue
		var owner: PlayerState = world.player(int(pulse.owner))
		if owner == null or owner.health <= 0: continue
		var definition: Dictionary = pulse.definition
		definition.damage = int(definition.damage) * int(ledger.remaining_strength) / int(ledger.initial_strength)
		CombatSystem._resolve_spray(owner, int(pulse.wire), definition, pulse.origin, pulse.aim, pulse.endpoint,
			world.players, world.config, world.collision, world.combat_events, [], world.tick)
		world.combat_events.append({"type": "projectile_terminal", "spray_reservation": true,
			"source_cast_id": int(pulse.source), "source_wire_id": int(pulse.wire), "owner_id": owner.entity_id, "team_id": owner.team_id,
			"element_wire_id": int(definition.element_wire_id), "position": pulse.endpoint, "direction": pulse.aim,
			"strength": int(ledger.flight_quantity), "reaction_strength": int(ledger.initial_strength),
			"initial_strength": int(ledger.initial_strength), "remaining_strength": int(ledger.remaining_strength)})
	var survivors: Array[ProjectileState] = []
	for shot: ProjectileState in world.projectiles:
		var ledger: Dictionary = world.hex_court.ledger_for_source(_source(shot))
		if not ledger.is_empty() and int(ledger.remaining_strength) > 0:
			shot.remaining_strength = int(ledger.remaining_strength)
			survivors.append(shot)
	world.projectiles = survivors


static func footprint_contact(first: Dictionary, second: Dictionary) -> Dictionary:
	if not HexFootprint.intersects(first, second): return {}
	var primitives := HexFootprint._primitive_parts(first)
	primitives.append_array(HexFootprint._primitive_parts(second))
	var candidates := HexFootprint._common_point_candidates(primitives)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.x) < float(b.x) if float(a.x) != float(b.x) else float(a.y) < float(b.y))
	for point: Dictionary in candidates:
		if HexFootprint._scalar_in_all(primitives, point):
			return {"point": Vector2i(roundi(float(point.x)), roundi(float(point.y)))}
	return {}


static func _eligible(shot: ProjectileState, target: PlayerState, config: SimConfig) -> bool:
	return target.entity_id != shot.owner_id and target.team_id != shot.team_id \
		and target.health > 0 and target.spawn_protection_ticks == 0 \
		and not MovementSystem.is_combat_intangible(target, config) \
		and target.air_height < MovementTuning.GROUND_PROJECTILE_CLEARANCE_HEIGHT


static func _ordered(a: Dictionary, b: Dictionary) -> bool:
	if float(a.fraction) != float(b.fraction): return float(a.fraction) < float(b.fraction)
	if int(a.priority) != int(b.priority): return int(a.priority) < int(b.priority)
	if int(a.first) != int(b.first): return int(a.first) < int(b.first)
	return int(a.second) < int(b.second)


static func _plan(shot: ProjectileState, world: SimWorld) -> Dictionary:
	shot.previous_x = shot.position_x
	shot.previous_y = shot.position_y
	var start := Vector2i(shot.position_x, shot.position_y)
	var tx := shot.remainder_x + shot.velocity_x
	var ty := shot.remainder_y + shot.velocity_y
	var delta := Vector2i(tx / world.config.tick_rate, ty / world.config.tick_rate)
	shot.remainder_x = tx - delta.x * world.config.tick_rate
	shot.remainder_y = ty - delta.y * world.config.tick_rate
	var finish := start + delta
	var terminal := 1.0
	var reason := "" if shot.lifetime_ticks > 1 else "range"
	if shot.remaining_distance >= 0:
		var distance := sqrt(float(delta.x) * float(delta.x) + float(delta.y) * float(delta.y))
		var amount := roundi(distance * ProjectileState.RANGE_SUBUNITS)
		var available := shot.remaining_distance * ProjectileState.RANGE_SUBUNITS - shot.range_subunit
		if amount >= available:
			terminal = float(available) / maxf(1.0, distance * ProjectileState.RANGE_SUBUNITS)
			shot.remaining_distance = 0
			shot.range_subunit = 0
			reason = "range"
		else:
			var spent := shot.range_subunit + amount
			shot.remaining_distance -= spent / ProjectileState.RANGE_SUBUNITS
			shot.range_subunit = spent % ProjectileState.RANGE_SUBUNITS
	var wall := ContinuousContact.wall_contact(start, finish, shot.radius, world.collision)
	if not wall.is_empty() and float(wall.fraction) <= terminal:
		terminal = float(wall.fraction)
		reason = "obstacle"
	return {"entity_id": shot.entity_id, "source_id": _source(shot), "shot": shot,
		"start": start, "finish": finish, "radius": shot.radius, "remaining_strength": shot.remaining_strength,
		"terminal_fraction": terminal, "terminal_inclusive": reason != "obstacle", "reason": reason, "wall": wall}


static func advance(world: SimWorld) -> void:
	if not sync_strength(world): return
	var plans: Array[Dictionary] = []
	var by_id := {}
	var queue: Array[Dictionary] = []
	for shot: ProjectileState in world.projectiles:
		if shot.remaining_strength <= 0: continue
		var plan := _plan(shot, world)
		plans.append(plan)
		by_id[shot.entity_id] = plan
		if not String(plan.reason).is_empty():
			queue.append({"kind": "terminal", "fraction": plan.terminal_fraction,
				"priority": 0 if plan.reason == "obstacle" else 3, "first": shot.entity_id, "second": 0})
		for target: PlayerState in world.players:
			if not _eligible(shot, target, world.config): continue
			var fraction := ContinuousContact.circle_toi(plan.start, plan.finish, Vector2i(target.position_x, target.position_y), shot.radius + target.radius)
			if fraction < 0.0 or fraction > float(plan.terminal_fraction): continue
			queue.append({"kind": "actor", "fraction": fraction, "priority": 2,
				"first": shot.entity_id, "second": target.entity_id})
	var ordered_contacts := ProjectileContactOrder.plan(plans)
	if not bool(ordered_contacts.accepted):
		world.last_error = "invalid hex projectile contact plan: %s" % str(ordered_contacts.reason)
		return
	for contact: Dictionary in ordered_contacts.contacts:
		queue.append({"kind": "clash", "fraction": contact.fraction, "priority": 1,
			"first": contact.entity_a_id, "second": contact.entity_b_id, "point": contact.point})
	queue.sort_custom(_ordered)
	var ended := {}
	for event: Dictionary in queue:
		if ended.has(int(event.first)): continue
		var plan: Dictionary = by_id[int(event.first)]
		var shot: ProjectileState = plan.shot
		var ledger: Dictionary = world.hex_court.ledger_for_source(_source(shot))
		if ledger.is_empty() or int(ledger.remaining_strength) <= 0:
			ended[shot.entity_id] = true
			continue
		shot.remaining_strength = int(ledger.remaining_strength)
		if event.kind == "clash":
			if ended.has(int(event.second)): continue
			var other: ProjectileState = by_id[int(event.second)].shot
			if not SprayInterception.clear_ray(ContinuousContact.point_at(plan.start, plan.finish, event.fraction), event.point, world.collision, [], world.tick): continue
			var outcome: Dictionary = world.hex_court.resolve_contact(_source(shot), _source(other), event.point, world.tick)
			if not bool(outcome.get("accepted", false)): continue
			_record_clash(world, shot, other.source_wire_id, event.point, outcome)
			if int(outcome.first.post_strength) == 0: ended[shot.entity_id] = true
			if int(outcome.second.post_strength) == 0: ended[other.entity_id] = true
			continue
		var center := ContinuousContact.point_at(plan.start, plan.finish, event.fraction)
		shot.position_x = center.x
		shot.position_y = center.y
		var point := center
		if event.kind == "actor":
			var target: PlayerState = world.player(int(event.second))
			if target == null or not _eligible(shot, target, world.config): continue
			point = ContinuousContact.circle_contact(plan.start, plan.finish, event.fraction, Vector2i(target.position_x, target.position_y), target.radius)
			var damage := scaled_damage(shot)
			if not PlayerResourcesSystem.damage(target, damage, world.config): continue
			if target.health > 0 and shot.hit_control_duration_ms > 0:
				MovementSystem.apply_control_state(target, shot.hit_control_state, shot.hit_control_duration_ms,
					SimCommand._normalized_direction(shot.velocity_x, shot.velocity_y), shot.hit_control_speed, world.config, shot.hit_control_slow_ratio)
			world.combat_events.append({"type": "projectile_hit", "projectile_id": shot.entity_id, "source_wire_id": shot.source_wire_id,
				"owner_id": shot.owner_id, "target_id": target.entity_id, "damage": damage, "contact_position": point})
			if target.actor_kind == PlayerState.ActorKind.CHAMPION and target.health == 0:
				world.combat_events.append({"type": "champion_defeated", "projectile_id": shot.entity_id, "owner_id": shot.owner_id, "target_id": target.entity_id})
			_terminal(world, shot, point, "actor", target.entity_id)
		else:
			if plan.reason == "obstacle":
				point = plan.wall.point
				world.combat_events.append({"type": "projectile_impact", "projectile_id": shot.entity_id, "wall_id": int(plan.wall.id), "contact_position": point})
			else:
				world.combat_events.append({"type": "projectile_expired", "projectile_id": shot.entity_id})
			_terminal(world, shot, point, plan.reason)
		ended[shot.entity_id] = true
	var survivors: Array[ProjectileState] = []
	for plan: Dictionary in plans:
		var shot: ProjectileState = plan.shot
		if ended.has(shot.entity_id): continue
		var ledger: Dictionary = world.hex_court.ledger_for_source(_source(shot))
		if ledger.is_empty() or int(ledger.remaining_strength) <= 0: continue
		shot.remaining_strength = int(ledger.remaining_strength)
		shot.position_x = plan.finish.x
		shot.position_y = plan.finish.y
		shot.lifetime_ticks -= 1
		survivors.append(shot)
	world.projectiles = survivors


static func scaled_damage(shot: ProjectileState) -> int:
	return shot.damage * shot.remaining_strength / maxi(1, shot.initial_strength)


static func terminal_radius(shot: ProjectileState) -> int:
	var authored := int(CombatTuning.cast_definition(shot.source_wire_id).get("blast_radius", 0))
	return roundi(float(authored) * sqrt(float(shot.remaining_strength) / maxi(1, shot.initial_strength)))


static func _terminal(world: SimWorld, shot: ProjectileState, point: Vector2i, reason: String, excluded_id: int = 0) -> void:
	var radius := terminal_radius(shot)
	var definition := CombatTuning.cast_definition(shot.source_wire_id)
	var damage := mini(scaled_damage(shot), int(definition.get("blast_damage", 0)) * shot.remaining_strength / maxi(1, shot.initial_strength))
	if radius > 0 and damage > 0:
		for target: PlayerState in world.players:
			if target.entity_id in [shot.owner_id, excluded_id] or target.team_id == shot.team_id or target.health <= 0 or target.spawn_protection_ticks > 0 or MovementSystem.is_combat_intangible(target, world.config): continue
			var target_point := Vector2i(target.position_x, target.position_y)
			if (target_point - point).length_squared() > (radius + target.radius) * (radius + target.radius): continue
			if not SprayInterception.clear_ray(point, target_point, world.collision, [], world.tick): continue
			if PlayerResourcesSystem.damage(target, damage, world.config):
				world.combat_events.append({"type": "projectile_hit", "projectile_id": shot.entity_id, "source_wire_id": shot.source_wire_id,
					"owner_id": shot.owner_id, "target_id": target.entity_id, "damage": damage, "contact_position": point})
	CombatSystem._emit_terminal(shot, world.combat_events, reason, point)


static func _record_clash(world: SimWorld, shot: ProjectileState, other_wire: int, point: Vector2i, outcome: Dictionary) -> void:
	world.combat_events.append({"type": "hex_clash", "source_wire_id": shot.source_wire_id, "other_wire_id": other_wire,
		"owner_id": shot.owner_id, "projectile_id": shot.entity_id, "x": point.x, "y": point.y,
		"matched_strength": int(outcome.matched_strength), "first_remaining": int(outcome.first.post_strength), "second_remaining": int(outcome.second.post_strength),
		"recipe_wire_id": int(outcome.get("recipe_wire_id", 0)), "reaction_id": int(outcome.get("reaction_id", 0))})
