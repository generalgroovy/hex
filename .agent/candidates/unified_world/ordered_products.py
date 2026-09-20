from pathlib import Path
p=Path(__file__).parent/'src/sim/hex/hex_projectile_combat.gd'
s=p.read_text()
a=s.index('static func advance(');b=s.index('\nstatic func scaled_damage',a)
s=s[:a]+r'''static func advance(world: SimWorld) -> void:
	if not sync_strength(world): return
	var plans: Array[Dictionary] = []
	var by_id := {}
	var queue: Array[Dictionary] = []
	var scheduled_pairs := {}
	for shot: ProjectileState in world.projectiles:
		if shot.remaining_strength <= 0: continue
		var plan := _plan(shot, world)
		plan.time = 0.0
		plan.generation = 0
		plans.append(plan)
		by_id[shot.entity_id] = plan
		_enqueue_path(plan, world, queue)
	for plan: Dictionary in plans: _enqueue_pairs(plan, plans, queue, scheduled_pairs)
	queue.sort_custom(_ordered)
	var ended := {}
	while not queue.is_empty():
		var event: Dictionary = queue.pop_front()
		if ended.has(int(event.first)): continue
		var plan: Dictionary = by_id[int(event.first)]
		if int(event.generation) != int(plan.generation): continue
		var shot: ProjectileState = plan.shot
		var ledger: Dictionary = world.hex_court.ledger_for_source(_source(shot))
		if ledger.is_empty() or int(ledger.remaining_strength) <= 0 or world.hex_court.flight_quantity(_source(shot), shot.entity_id) <= 0:
			ended[shot.entity_id] = true
			continue
		shot.remaining_strength = int(ledger.remaining_strength)
		if event.kind == "clash":
			if ended.has(int(event.second)) or int(event.other_generation) != int(by_id[int(event.second)].generation): continue
			var other: ProjectileState = by_id[int(event.second)].shot
			if world.hex_court.flight_quantity(_source(other), other.entity_id) <= 0: continue
			var outcome: Dictionary = world.hex_court.resolve_contact(_source(shot), _source(other), event.point, world.tick)
			if not bool(outcome.get("accepted", false)): continue
			_record_clash(world, shot, other.source_wire_id, event.point, outcome)
			if int(outcome.first.post_strength) == 0: ended[shot.entity_id] = true
			if int(outcome.second.post_strength) == 0: ended[other.entity_id] = true
			continue
		if event.kind == "field":
			var field := _ground_field_for_source(world, int(event.second))
			if field.is_empty(): continue
			var interval := HexFootprint.selected_segment_interval(HexChemistryWorld.coverage(field), world.hex_court.origin, plan.start, plan.finish)
			if not bool(interval.get("hit", false)): continue
			var fraction := float(plan.time) + (1.0 - float(plan.time)) * float(interval.low)
			if fraction > float(plan.terminal_fraction): continue
			if fraction > float(event.fraction):
				event.fraction = fraction
				event.point = interval.point
				queue.append(event)
				queue.sort_custom(_ordered)
				continue
			if not SprayInterception.clear_ray(plan.start, interval.point, world.collision, [], world.tick): continue
			var outcome: Dictionary = world.hex_court.resolve_contact(_source(shot), int(event.second), interval.point, world.tick)
			if bool(outcome.get("accepted", false)):
				_record_field_clash(world, shot, int(field.wire), int(event.second), interval.point, outcome, bool(interval.get("quantization_outside", false)))
				if int(outcome.first.post_strength) == 0: ended[shot.entity_id] = true
			continue
		var center := _plan_point(plan, float(event.fraction))
		shot.position_x = center.x
		shot.position_y = center.y
		if event.kind == "product":
			var product: Dictionary = world.hex_court.products.get(int(event.second), {})
			if not _product_eligible(product, shot, world.tick): continue
			var wire := int(product.recipe_wire_id)
			if wire in [301, 305, 306] or (wire == 329 and shot.element_wire_id != 7):
				var damage := scaled_damage(shot)
				var absorbed := mini(int(product.capacity), damage) if wire == 306 and shot.element_wire_id == 6 else 0
				product.capacity -= absorbed
				product.health = maxi(0, int(product.health) - damage + absorbed)
				if int(product.health) == 0: product.decay_tick = world.tick
				world.collision.refresh_surfaces(world.tick)
				_terminal(world, shot, event.point, "construct")
				ended[shot.entity_id] = true
				continue
			shot.chemistry_interaction_mask |= 1 << (wire - 301)
			if wire == 317:
				world.hex_court.suppress_source(_source(shot), int(product.id))
				continue
			if wire in [320, 335]:
				product.pulse_index = world.tick
				continue
			var original_velocity := Vector2i(shot.velocity_x, shot.velocity_y)
			var original_remaining: Vector2i = plan.finish - center
			var child: ProjectileState = null
			if wire == 329:
				var available := world.available_cast_capacity(shot.owner_id)
				if shot.damage < 2 or available.x <= 0 or available.y <= 0 or not world.hex_court.split_flight(_source(shot), shot.entity_id, world.next_projectile_id):
					shot.chemistry_interaction_mask &= ~(1 << (wire - 301))
					continue
				var child_damage := shot.damage / 2
				shot.damage -= child_damage
				child = ProjectileState.new(world.next_projectile_id, shot.owner_id, shot.team_id, shot.source_wire_id, shot.element_wire_id, center,
					ElementChemistrySystem.rotated_fifteen(original_velocity, -1), shot.radius, child_damage, shot.lifetime_ticks,
					shot.hit_control_state, shot.hit_control_duration_ms, shot.hit_control_speed, shot.hit_control_slow_ratio, shot.remaining_bounces)
				world.next_projectile_id += 1
				child.remaining_distance = shot.remaining_distance
				child.range_subunit = shot.range_subunit
				child.source_cast_id = _source(shot)
				child.reaction_strength = shot.reaction_strength
				child.initial_strength = shot.initial_strength
				child.remaining_strength = shot.remaining_strength
				child.material_strength = shot.material_strength / 2
				shot.material_strength -= child.material_strength
				child.chemistry_interaction_mask = shot.chemistry_interaction_mask
				child.grazed_entity_ids = shot.grazed_entity_ids.duplicate()
				world.projectiles.append(child)
			if wire == 307:
				var normal: Vector2i = product.flow_aim
				var velocity := _reflected(original_velocity, normal)
				shot.velocity_x = velocity.x
				shot.velocity_y = velocity.y
				_repath(plan, center, center + _reflected(original_remaining, normal), float(event.fraction), world)
			else:
				var velocity := ElementChemistrySystem.rotated_fifteen(original_velocity, 1)
				shot.velocity_x = velocity.x
				shot.velocity_y = velocity.y
				_repath(plan, center, center + ElementChemistrySystem.rotated_fifteen(original_remaining, 1), float(event.fraction), world)
			shot.remainder_x = 0
			shot.remainder_y = 0
			_enqueue_path(plan, world, queue)
			_enqueue_pairs(plan, plans, queue, scheduled_pairs)
			if child != null:
				var child_plan := {"entity_id": child.entity_id, "source_id": _source(child), "shot": child, "radius": child.radius,
					"remaining_strength": child.remaining_strength, "terminal_fraction": plan.terminal_fraction, "terminal_inclusive": true,
					"reason": plan.reason, "generation": -1}
				_repath(child_plan, center, center + ElementChemistrySystem.rotated_fifteen(original_remaining, -1), float(event.fraction), world)
				plans.append(child_plan)
				by_id[child.entity_id] = child_plan
				_enqueue_path(child_plan, world, queue)
				_enqueue_pairs(child_plan, plans, queue, scheduled_pairs)
			world.combat_events.append({"type": "hex_optical_contact", "projectile_id": shot.entity_id, "reaction_id": int(product.id), "recipe_wire_id": wire})
			queue.sort_custom(_ordered)
			continue
		if event.kind == "actor":
			var target := world.player(int(event.second))
			if target == null or not _eligible(shot, target, world.config): continue
			var point := ContinuousContact.circle_surface(center, Vector2i(target.position_x, target.position_y), target.radius)
			var damage := scaled_damage(shot)
			if not PlayerResourcesSystem.damage(target, damage, world.config): continue
			if target.health > 0 and shot.hit_control_duration_ms > 0:
				MovementSystem.apply_control_state(target, shot.hit_control_state, shot.hit_control_duration_ms, SimCommand._normalized_direction(shot.velocity_x, shot.velocity_y), shot.hit_control_speed, world.config, shot.hit_control_slow_ratio)
			world.combat_events.append({"type": "projectile_hit", "projectile_id": shot.entity_id, "source_wire_id": shot.source_wire_id, "owner_id": shot.owner_id, "target_id": target.entity_id, "damage": damage, "contact_position": point})
			if target.actor_kind == PlayerState.ActorKind.CHAMPION and target.health == 0:
				world.combat_events.append({"type": "champion_defeated", "projectile_id": shot.entity_id, "owner_id": shot.owner_id, "target_id": target.entity_id})
			_terminal(world, shot, point, "actor", target.entity_id)
		else:
			var point: Vector2i = event.get("point", center)
			world.combat_events.append({"type": "projectile_impact" if event.kind == "wall" else "projectile_expired", "projectile_id": shot.entity_id, "wall_id": int(event.get("wall_id", 0)), "contact_position": point})
			_terminal(world, shot, point, "obstacle" if event.kind == "wall" else "range")
		ended[shot.entity_id] = true
	var survivors: Array[ProjectileState] = []
	for plan: Dictionary in plans:
		var shot: ProjectileState = plan.shot
		if ended.has(shot.entity_id): continue
		var ledger: Dictionary = world.hex_court.ledger_for_source(_source(shot))
		if ledger.is_empty() or int(ledger.remaining_strength) <= 0 or world.hex_court.flight_quantity(_source(shot), shot.entity_id) <= 0: continue
		shot.remaining_strength = int(ledger.remaining_strength)
		shot.position_x = plan.finish.x
		shot.position_y = plan.finish.y
		shot.lifetime_ticks -= 1
		survivors.append(shot)
	world.projectiles = survivors


static func _plan_point(plan: Dictionary, time: float) -> Vector2i:
	return ContinuousContact.point_at(plan.start, plan.finish, clampf((time - float(plan.time)) / maxf(1e-12, 1.0 - float(plan.time)), 0.0, 1.0))


static func _repath(plan: Dictionary, start: Vector2i, finish: Vector2i, time: float, world: SimWorld) -> void:
	plan.start = start
	plan.finish = finish
	plan.time = time
	plan.generation = int(plan.generation) + 1
	plan.wall = ContinuousContact.wall_contact(start, finish, int(plan.radius), world.collision.base_world if world.collision is HexCollisionWorld else world.collision)


static func _enqueue_path(plan: Dictionary, world: SimWorld, queue: Array[Dictionary]) -> void:
	var common := {"first": int(plan.entity_id), "generation": int(plan.generation)}
	if not plan.wall.is_empty():
		var wall: Dictionary = plan.wall
		var fraction := float(plan.time) + (1.0 - float(plan.time)) * float(wall.fraction)
		if fraction <= float(plan.terminal_fraction):
			var event := common.duplicate()
			event.merge({"kind": "wall", "fraction": fraction, "priority": 0, "second": 0, "point": wall.point, "wall_id": int(wall.id)})
			queue.append(event)
	if not String(plan.reason).is_empty():
		var event := common.duplicate()
		event.merge({"kind": "range", "fraction": float(plan.terminal_fraction), "priority": 3, "second": 0})
		queue.append(event)
	var shot: ProjectileState = plan.shot
	for actor: PlayerState in world.players:
		if not _eligible(shot, actor, world.config): continue
		var local := ContinuousContact.circle_toi(plan.start, plan.finish, Vector2i(actor.position_x, actor.position_y), shot.radius + actor.radius)
		var fraction := float(plan.time) + (1.0 - float(plan.time)) * local
		if local < 0 or fraction > float(plan.terminal_fraction): continue
		var event := common.duplicate()
		event.merge({"kind": "actor", "fraction": fraction, "priority": 2, "second": actor.entity_id})
		queue.append(event)
	for field: Dictionary in _field_contacts(plan, world):
		var fraction := float(plan.time) + (1.0 - float(plan.time)) * float(field.fraction)
		if fraction > float(plan.terminal_fraction): continue
		var event := common.duplicate()
		event.merge({"kind": "field", "fraction": fraction, "priority": 1, "second": int(field.field_source), "point": field.point})
		queue.append(event)
	for product: Dictionary in world.hex_court.products.values():
		if not _product_eligible(product, shot, world.tick): continue
		var hit := _product_contact(product, plan.start, plan.finish, shot.radius, world.hex_court.origin)
		if hit.is_empty(): continue
		var fraction := float(plan.time) + (1.0 - float(plan.time)) * float(hit.fraction)
		if fraction > float(plan.terminal_fraction): continue
		var event := common.duplicate()
		event.merge({"kind": "product", "fraction": fraction, "priority": 0, "second": int(product.id), "point": hit.point})
		queue.append(event)


static func _enqueue_pairs(plan: Dictionary, plans: Array[Dictionary], queue: Array[Dictionary], scheduled: Dictionary) -> void:
	for other: Dictionary in plans:
		if int(plan.entity_id) == int(other.entity_id) or int(plan.source_id) == int(other.source_id): continue
		var low: Dictionary = plan if int(plan.entity_id) < int(other.entity_id) else other
		var high: Dictionary = other if int(plan.entity_id) < int(other.entity_id) else plan
		var key := "%d:%d:%d:%d" % [int(low.entity_id), int(low.generation), int(high.entity_id), int(high.generation)]
		if scheduled.has(key): continue
		scheduled[key] = true
		var start_time := maxf(float(low.time), float(high.time))
		if start_time >= 1.0 or start_time > minf(float(low.terminal_fraction), float(high.terminal_fraction)): continue
		var records: Array = []
		for source_plan: Dictionary in [low, high]:
			var record := source_plan.duplicate()
			record.start = _plan_point(source_plan, start_time)
			record.terminal_fraction = (float(source_plan.terminal_fraction) - start_time) / (1.0 - start_time)
			record.terminal_inclusive = true
			records.append(record)
		var outcome := ProjectileContactOrder.plan(records)
		if not bool(outcome.accepted): continue
		for contact: Dictionary in outcome.contacts:
			queue.append({"kind": "clash", "fraction": start_time + (1.0 - start_time) * float(contact.fraction), "priority": 1,
				"first": int(low.entity_id), "second": int(high.entity_id), "generation": int(low.generation), "other_generation": int(high.generation), "point": contact.point})


static func _product_eligible(product: Dictionary, shot: ProjectileState, tick: int) -> bool:
	if product.is_empty() or tick < int(product.active_tick) or tick >= int(product.decay_tick): return false
	var wire := int(product.recipe_wire_id)
	if wire in [301, 305, 306] or (wire == 329 and shot.element_wire_id != 7): return int(product.health) > 0
	if wire not in [307, 317, 320, 325, 329, 335] or (shot.chemistry_interaction_mask & (1 << (wire - 301))) != 0: return false
	if wire in [325, 329] and shot.element_wire_id != 7: return false
	if wire == 317 and (shot.element_wire_id != 2 or int(product.capacity) <= 0): return false
	return wire not in [307, 329] or int(product.health) > 0


static func _product_contact(product: Dictionary, start: Vector2i, finish: Vector2i, radius: int, origin: Vector2i) -> Dictionary:
	if int(product.recipe_wire_id) in [301, 305, 306, 307, 329]:
		var best := {}
		for cell: Vector2i in HexChemistryWorld.coverage(product):
			var hit := HexConvexGeometry.sweep_circle(start, finish, radius, cell, origin)
			if not hit.is_empty() and (best.is_empty() or float(hit.fraction) < float(best.fraction)): best = hit
		return best
	var interval := HexFootprint.selected_segment_interval(HexChemistryWorld.coverage(product), origin, start, finish)
	return {"fraction": float(interval.low), "point": interval.point} if bool(interval.get("hit", false)) else {}


static func _reflected(value: Vector2i, normal: Vector2i) -> Vector2i:
	var square: int = normal.x * normal.x + normal.y * normal.y
	if square <= 0: return -value
	var dot: int = value.x * normal.x + value.y * normal.y
	return value - Vector2i(2 * dot * normal.x / square, 2 * dot * normal.y / square)

''' + s[b:]
# Static walls are immutable. Dynamic covers participate in the same ordered queue.
a=s.index('\tvar wall := ContinuousContact.wall_contact(start, finish, shot.radius, world.collision)',s.index('static func _plan('))
b=s.index('\n\treturn {"entity_id"',a)
s=s[:a]+'\tvar wall := ContinuousContact.wall_contact(start, finish, shot.radius, world.collision.base_world if world.collision is HexCollisionWorld else world.collision)'+s[b:]
# Preserve Frostway as displacement context, never a velocity rewrite.
s=s.replace('var tx := shot.remainder_x + shot.velocity_x\n\tvar ty := shot.remainder_y + shot.velocity_y', 'var ratio := 1000\n\tfor product: Dictionary in world.hex_court.products.values():\n\t\tif int(product.recipe_wire_id) == 327 and world.tick >= int(product.active_tick) and world.tick < int(product.decay_tick) and world.hex_court.contains_stored(product, start): ratio = 650\n\tvar tx := shot.remainder_x + shot.velocity_x * ratio / 1000\n\tvar ty := shot.remainder_y + shot.velocity_y * ratio / 1000')
p.write_text(s,encoding='utf-8',newline='\n')
