class_name HexProjectileCombat
extends RefCounted
@warning_ignore_start("integer_division")
const Workset = preload("res://src/sim/hex/hex_contact_workset.gd")

# Ordered continuous combat over the shared, finite hex chemistry authority.
static func sync_strength(world: SimWorld) -> bool:
	if world.hex_court is HexChemistryWorld and world.hex_court.collision == null:
		world.hex_court.collision = world.collision.base_world if world.collision is HexCollisionWorld else world.collision
	for shot: ProjectileState in world.projectiles:
		var ledger: Dictionary = world.hex_court.ledger_for_source(shot.source_cast_id)
		if ledger.is_empty() or not StrengthBudget.validate(ledger):
			world.last_error = "hex projectile has no valid paid source ledger"
			return false
		shot.initial_strength = int(ledger.initial_strength)
		shot.remaining_strength = int(ledger.remaining_strength)
		if world.hex_court.flight_quantity(_source(shot), shot.entity_id) <= 0:
			world.last_error = "hex projectile has no allocated flight branch"
			return false
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
	var bounds: CollisionWorld = null
	for event: Dictionary in world.combat_events:
		if event.get("type", "") != "spray_requested":
			retained.append(event)
			continue
		var source := int(event.source_cast_id)
		var origin := Vector2i(int(event.origin_x), int(event.origin_y))
		var aim := Vector2i(int(event.aim_x), int(event.aim_y))
		var definition := CombatSystem.spray_request_definition(event)
		var endpoint := origin + ElementChemistrySystem.scaled(aim, int(definition.range))
		var requested_shape := HexFootprint.sector(origin, aim, int(definition.range), int(definition.cone_cosine_squared_per_million))
		# Keep the authored fan even when its center meets a narrow pillar. Only
		# world bounds shorten this envelope; cover clips each queried ray below.
		if bounds == null: bounds = CollisionWorld.new(world.collision.width, world.collision.height)
		var wall := ContinuousContact.wall_contact(origin, endpoint, int(definition.radius), bounds)
		if not wall.is_empty(): endpoint = wall.center
		var offset := endpoint - origin
		var reach := SimCommand._integer_square_root(offset.x * offset.x + offset.y * offset.y)
		if reach <= 0:
			retained.append({"type": "cast_blocked", "entity_id": int(event.owner_id), "wire_id": int(event.source_wire_id)})
			continue
		definition.range = reach
		var pulse := {"source": source, "owner": int(event.owner_id), "wire": int(event.source_wire_id),
			"origin": origin, "aim": aim, "endpoint": endpoint, "definition": definition,
			"requested_shape": requested_shape,
			"footprint": HexFootprint.sector(origin, aim, reach, int(definition.cone_cosine_squared_per_million))}
		pulses.append(pulse)
		requests[source] = pulse
	world.combat_events = retained
	var contacts: Array[Dictionary] = []
	# No contact has resolved yet: every pulse sees the same initial field set.
	# Resolution below still revalidates each source after strength/coverage edits.
	var initial_fields: Array[Dictionary] = []
	if not pulses.is_empty(): initial_fields = _ground_fields(world)
	for index: int in pulses.size():
		var pulse: Dictionary = pulses[index]
		for shot: ProjectileState in world.projectiles:
			if _source(shot) == int(pulse.source): continue
			var point := footprint_contact(pulse.footprint, HexFootprint.disk(Vector2i(shot.position_x, shot.position_y), shot.radius))
			if point.is_empty(): continue
			contacts.append({"first": mini(int(pulse.source), _source(shot)), "second": maxi(int(pulse.source), _source(shot)),
				"a": int(pulse.source), "b": _source(shot), "point": point.point, "witness": point, "other_wire": shot.source_wire_id})
		for other_index: int in range(index + 1, pulses.size()):
			var other: Dictionary = pulses[other_index]
			var point := footprint_contact(pulse.footprint, other.footprint)
			if point.is_empty(): continue
			contacts.append({"first": mini(int(pulse.source), int(other.source)), "second": maxi(int(pulse.source), int(other.source)),
				"a": int(pulse.source), "b": int(other.source), "point": point.point, "witness": point, "kind": "pulse", "other_wire": int(other.wire)})
		# Phase-zero field interception is source-owned and analytic. Iterating
		# records rather than storage cells deduplicates multi-cell footprints.
		for field: Dictionary in initial_fields:
			if int(field.source) == int(pulse.source): continue
			var point := HexFootprint.contact_shape_selected(pulse.footprint, HexChemistryWorld.coverage(field), world.hex_court.origin, pulse.origin)
			if point.is_empty() or not _spray_contact_visible(pulse, point, world.collision): continue
			contacts.append({"first": mini(int(pulse.source), int(field.source)), "second": maxi(int(pulse.source), int(field.source)),
				"a": int(pulse.source), "b": int(field.source), "point": point.point, "witness": point, "kind": "field",
				"other_wire": int(field.wire), "quantization_outside": bool(point.get("quantization_outside", false))})
	contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.first) < int(b.first) if int(a.first) != int(b.first) else int(a.second) < int(b.second))
	for contact: Dictionary in contacts:
		var pulse: Dictionary = requests[int(contact.a)]
		if String(contact.get("kind", "")) == "field":
			var current_field := _ground_field_for_source(world, int(contact.b))
			if current_field.is_empty(): continue
			var current_point := HexFootprint.contact_shape_selected(pulse.footprint, HexChemistryWorld.coverage(current_field), world.hex_court.origin, pulse.origin)
			if current_point.is_empty(): continue
			contact.point = current_point.point
			contact.witness = current_point
			contact.quantization_outside = bool(current_point.get("quantization_outside", false))
		if not _spray_contact_visible(pulse, contact.witness, world.collision): continue
		if requests.has(int(contact.b)) and not _spray_contact_visible(requests[int(contact.b)], contact.witness, world.collision): continue
		var outcome: Dictionary = world.hex_court.resolve_contact(int(contact.a), int(contact.b), contact.point, world.tick)
		if not bool(outcome.get("accepted", false)): continue
		var clash_event := {"type": "hex_clash", "source_wire_id": int(pulse.wire), "other_wire_id": int(contact.other_wire), "owner_id": int(pulse.owner),
			"x": contact.point.x, "y": contact.point.y, "matched_strength": int(outcome.matched_strength),
			"first_remaining": int(outcome.first.post_strength), "second_remaining": int(outcome.second.post_strength),
			"recipe_wire_id": int(outcome.get("recipe_wire_id", 0)), "reaction_id": int(outcome.get("reaction_id", outcome.get("product_id", 0)))}
		if String(contact.get("kind", "")) == "field":
			clash_event.contact_kind = "field"
			clash_event.field_source_id = int(contact.b)
			clash_event.contact_quantization_outside = bool(contact.get("quantization_outside", false))
		world.combat_events.append(clash_event)
	pulses.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.source) < int(b.source))
	for pulse: Dictionary in pulses:
		var ledger: Dictionary = world.hex_court.ledger_for_source(int(pulse.source))
		if ledger.is_empty() or int(ledger.remaining_strength) <= 0: continue
		var owner: PlayerState = world.player(int(pulse.owner))
		# A released pulse belongs to this phase even if another pulse has just
		# killed its owner. Captured origin/aim and its paid ledger remain valid.
		if owner == null: continue
		var definition: Dictionary = pulse.definition
		definition.source_cast_id = int(pulse.source)
		definition.damage = int(definition.damage) * int(ledger.remaining_strength) / int(ledger.initial_strength)
		CombatSystem._resolve_spray(owner, int(pulse.wire), definition, pulse.origin, pulse.aim, pulse.endpoint,
			world.players, world.config, world.collision, world.combat_events, [], world.tick)
		_damage_spray_cover(world, pulse, int(definition.damage))
		world.combat_events.append({"type": "projectile_terminal", "spray_reservation": true,
			"source_cast_id": int(pulse.source), "source_wire_id": int(pulse.wire), "owner_id": owner.entity_id, "team_id": owner.team_id,
			"element_wire_id": int(definition.element_wire_id), "position": pulse.endpoint, "direction": pulse.aim,
			"strength": int(ledger.flight_quantity), "reaction_strength": int(ledger.initial_strength),
			"initial_strength": int(ledger.initial_strength), "remaining_strength": int(ledger.remaining_strength)})
		var terminal_event: Dictionary = world.combat_events.back()
		world.hex_court.deposit_terminal(terminal_event, world.tick, world.collision)
		terminal_event.hex_committed = true
	var survivors: Array[ProjectileState] = []
	for shot: ProjectileState in world.projectiles:
		var ledger: Dictionary = world.hex_court.ledger_for_source(_source(shot))
		if not ledger.is_empty() and int(ledger.remaining_strength) > 0 and world.hex_court.flight_quantity(_source(shot), shot.entity_id) > 0:
			shot.remaining_strength = int(ledger.remaining_strength)
			survivors.append(shot)
	world.projectiles = survivors
	if world.collision is HexCollisionWorld: world.collision.refresh_surfaces(world.tick)


# Phase-zero pulses all see the initial physical surfaces. Their health writes
# commit before continuous flight; breaking cover does not let the same pulse
# damage an actor through it. One pulse damages one closest construct once.
static func _damage_spray_cover(world: SimWorld, pulse: Dictionary, damage: int) -> void:
	var best := {}
	var best_distance := 0x7fffffffffffffff
	var ids: Array = world.hex_court.products.keys()
	ids.sort()
	for id: int in ids:
		var product: Dictionary = world.hex_court.products[id]
		if int(product.recipe_wire_id) not in [301, 305, 306, 307, 329] or int(product.health) <= 0 or world.tick < int(product.active_tick) or world.tick >= int(product.decay_tick): continue
		var contact := HexFootprint.contact_shape_selected(pulse.requested_shape, HexChemistryWorld.coverage(product), world.hex_court.origin, pulse.origin)
		if contact.is_empty(): continue
		var hit := ContinuousContact.wall_contact(pulse.origin, contact.point, 0, world.collision)
		if hit.is_empty() or not hit.has("cell") or not HexChemistryWorld.coverage(product).has(hit.cell): continue
		var distance: int = (Vector2i(hit.point) - Vector2i(pulse.origin)).length_squared()
		if distance < best_distance:
			best_distance = distance
			best = product
	if best.is_empty(): return
	var absorbed := mini(int(best.capacity), damage) if int(best.recipe_wire_id) == 306 and int(pulse.definition.element_wire_id) == 6 else 0
	best.capacity -= absorbed
	best.health = maxi(0, int(best.health) - damage + absorbed)
	if int(best.health) == 0: best.decay_tick = world.tick
	world.hex_court.value_revision += 1


static func footprint_contact(first: Dictionary, second: Dictionary) -> Dictionary:
	var preferred: Vector2i = first.get("start", first.get("center", Vector2i.ZERO))
	return HexFootprint.contact_point(first, second, preferred)


# Test the selected contact ray, never the fan's center ray. The existing
# bounded nearest-witness selection remains conservative for a field whose
# nearest witness is shadowed even if another part of that same field is clear.
# Retain the scalar witness: a wall wins an exact tie, but not a fractional
# pre-wall contact rounded onto its face. Doubling the integer segment lets the
# analytic query see a wall just beyond that rounded endpoint without stepping.
static func _spray_contact_visible(pulse: Dictionary, witness: Dictionary, collision: CollisionWorld) -> bool:
	var origin: Vector2i = pulse.origin
	var delta: Vector2i = Vector2i(witness.point) - origin
	var wall := ContinuousContact.wall_contact(origin, origin + delta * 2, int(pulse.definition.radius), collision)
	if wall.is_empty(): return true
	var x := float(witness.get("continuous_x", int(witness.point.x))) - float(origin.x)
	var y := float(witness.get("continuous_y", int(witness.point.y))) - float(origin.y)
	var reach_squared := float(delta.length_squared()) * 4.0 * float(wall.fraction) * float(wall.fraction)
	var tolerance := maxf(1.0, reach_squared) * HexFootprint.PARAMETER_EPSILON
	return x * x + y * y < reach_squared - tolerance


static func _eligible(shot: ProjectileState, target: PlayerState, config: SimConfig) -> bool:
	return _hostile_target(shot,target) \
		and not MovementSystem.is_combat_intangible(target, config) \
		and not MovementSystem.avoids_ordinary_projectiles(target)


static func _hostile_target(shot: ProjectileState, target: PlayerState) -> bool:
	return target.entity_id!=shot.owner_id and target.team_id!=shot.team_id and target.health>0 and target.spawn_protection_ticks==0


static func _ordered(a: Dictionary, b: Dictionary) -> bool:
	if float(a.fraction) != float(b.fraction): return float(a.fraction) < float(b.fraction)
	if int(a.priority) != int(b.priority): return int(a.priority) < int(b.priority)
	if int(a.first) != int(b.first): return int(a.first) < int(b.first)
	return int(a.second) < int(b.second)


# Fundamental deposited casts are the only persistent interception layer.
# The court cap bounds this scan to 64 records, and each source appears once
# even when its footprint occupies several storage cells.
static func _ground_fields(world: SimWorld) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (world.hex_court is HexChemistryWorld):
		return result
	var ids: Array = world.hex_court.casts.keys()
	ids.sort()
	for cast_id: int in ids:
		var record: Dictionary = world.hex_court.casts[cast_id]
		var field := _interceptable_field(record, world)
		if not field.is_empty(): result.append(field)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.source) < int(b.source) if int(a.source) != int(b.source) else int(a.id) < int(b.id))
	return result


static func _eligible_ground_field(record: Dictionary, world: SimWorld) -> bool:
	var ledger: Dictionary = record.get("ledger", {})
	return (
		bool(record.get("paid", false))
		and StrengthBudget.validate(ledger)
		and int(record.get("source", 0)) > 0
		and int(record.get("ground", 0)) > 0
		and int(ledger.deposited_quantity) > 0
		and int(ledger.remaining_strength) > 0
		and int(record.get("expires", 0)) > world.tick
		and HexFootprint.validate(record.get("footprint", {}))
	)


static func _ground_field_for_source(world: SimWorld, source_id: int) -> Dictionary:
	if not (world.hex_court is HexChemistryWorld) or not world.hex_court.sources.has(source_id): return {}
	var record: Dictionary = world.hex_court.casts.get(int(world.hex_court.sources[source_id]), {})
	return _interceptable_field(record, world)


static func _interceptable_field(record: Dictionary, world: SimWorld) -> Dictionary:
	if not _eligible_ground_field(record, world): return {}
	var selected := HexTrailEmitter.terminal_coverage(record)
	if selected.is_empty(): return {}
	var field := record.duplicate()
	field.coverage = selected
	return field


# Projectiles in this resolver occupy the authored ground-flight layer; their
# center path, rather than their actor/projectile collision radius, determines
# field eligibility. Earliest entry remains a continuous parameter while
# HexFootprint supplies its bounded, stored-union-aware fixed-grid witness.
static func _field_contacts(plan: Dictionary, world: SimWorld, prepared_fields: Variant = null) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var source_id: int = int(plan.source_id)
	# null means a fresh query; an empty prepared set is a valid empty result.
	var fields: Array = _ground_fields(world) if prepared_fields == null else prepared_fields
	for field: Dictionary in fields:
		var field_source: int = int(field.source)
		if field_source == source_id:
			continue
		var interval: Dictionary = HexFootprint.selected_segment_interval(HexChemistryWorld.coverage(field), world.hex_court.origin, plan.start, plan.finish)
		if not bool(interval.get("hit", false)):
			continue
		var fraction: float = float(interval.low)
		var terminal_fraction: float = (float(plan.terminal_fraction) - float(plan.get("time", 0.0))) / maxf(1e-12, 1.0 - float(plan.get("time", 0.0)))
		# Cover wins an exact tie. Ordinary range/lifetime endpoints remain
		# inclusive, matching projectile-projectile contact ordering.
		if fraction > terminal_fraction or (String(plan.reason) == "obstacle" and fraction >= terminal_fraction):
			continue
		result.append({
			"fraction": fraction,
			"field_source": field_source,
			"field_cast_id": int(field.id),
			"point": interval.point,
			"quantization_outside": bool(interval.get("quantization_outside", false)),
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a.fraction) != float(b.fraction): return float(a.fraction) < float(b.fraction)
		return int(a.field_source) < int(b.field_source))
	return result


static func _plan(shot: ProjectileState, world: SimWorld) -> Dictionary:
	shot.previous_x = shot.position_x
	shot.previous_y = shot.position_y
	var start := Vector2i(shot.position_x, shot.position_y)
	var ratio := 1000
	for product: Dictionary in world.hex_court.products.values():
		if world.tick >= int(product.active_tick) and world.tick < int(product.decay_tick) and world.hex_court.contains_stored(product, start):
			ratio = mini(ratio, int(HexRecipePolicy.runtime_definition(int(product.recipe_wire_id)).get("projectile_speed_ratio", 1000)))
	var tx := shot.remainder_x + shot.velocity_x * ratio / 1000
	var ty := shot.remainder_y + shot.velocity_y * ratio / 1000
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
	var wall := ContinuousContact.wall_contact(start, finish, shot.radius, world.collision.base_world if world.collision is HexCollisionWorld else world.collision)
	return {"entity_id": shot.entity_id, "source_id": _source(shot), "shot": shot,
		"start": start, "finish": finish, "radius": shot.radius, "remaining_strength": shot.remaining_strength,
		"terminal_fraction": terminal, "terminal_inclusive": reason != "obstacle", "reason": reason, "wall": wall}


static func advance(world: SimWorld) -> void:
	if not sync_strength(world): return
	var stationary := HexExpandedDelivery.prepare(world)
	var plans: Array[Dictionary] = []
	var by_id := {}
	var queue := Workset.OrderedQueue.new(_ordered)
	var scheduled_pairs := {}
	# Borrow only while scheduling the initial paths. Repaths/children use fresh
	# queries because an earlier event may have exhausted or retiled a field.
	var initial_fields: Array[Dictionary] = []
	if not world.projectiles.is_empty(): initial_fields = _ground_fields(world)
	for shot: ProjectileState in world.projectiles:
		if HexExpandedDelivery.stationary(shot): continue
		if shot.remaining_strength <= 0: continue
		var plan := _plan(shot, world)
		plan.time = 0.0
		plan.generation = 0
		plans.append(plan)
		by_id[shot.entity_id] = plan
		_enqueue_path(plan, world, queue, initial_fields)
	var spatial := Workset.SpatialPlans.new(plans)
	for plan: Dictionary in plans: _enqueue_pairs(plan, spatial, queue, scheduled_pairs)
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
			var query_time := maxf(float(plan.time), float(event.get("formed_after", plan.time)))
			var query_start := _plan_point(plan, query_time)
			var interval := HexFootprint.selected_segment_interval(HexChemistryWorld.coverage(field), world.hex_court.origin, query_start, plan.finish)
			if not bool(interval.get("hit", false)): continue
			var fraction := query_time + (1.0 - query_time) * float(interval.low)
			if fraction > float(plan.terminal_fraction): continue
			if fraction > float(event.fraction):
				event.fraction = fraction
				event.point = interval.point
				queue.append(event)
				continue
			if not SprayInterception.clear_ray(query_start, interval.point, world.collision, [], world.tick): continue
			var outcome: Dictionary = world.hex_court.resolve_contact(_source(shot), int(event.second), interval.point, world.tick)
			if bool(outcome.get("accepted", false)):
				_record_field_clash(world, shot, int(field.wire), int(event.second), interval.point, outcome, bool(interval.get("quantization_outside", false)))
				if int(outcome.first.post_strength) == 0: ended[shot.entity_id] = true
			continue
		if event.kind == "avoid":
			# The same ordered swept witness as a hit, after earlier walls, fields,
			# clashes and targets. Observation cannot move or consume this shot.
			var target := world.player(int(event.second))
			if target!=null and _hostile_target(shot,target) and not _eligible(shot,target,world.config):
				target.last_event = "evaded_projectile"
			continue
		var center := _plan_point(plan, float(event.fraction))
		shot.position_x = center.x
		shot.position_y = center.y
		if shot.delivery_phase == 1: continue
		var delivery_family := MixtureCatalog.family_for_wire(shot.source_wire_id)
		if delivery_family == "fuse" and String(event.kind) in ["actor","wall","range"]:
			HexExpandedDelivery.arm(shot,world.config)
			plan.finish = center
			stationary.append(shot)
			ended[shot.entity_id] = true
			world.combat_events.append({"type":"fuse_armed","projectile_id":shot.entity_id,"source_wire_id":shot.source_wire_id,"owner_id":shot.owner_id,"x":center.x,"y":center.y,"delay_ticks":shot.delivery_ticks})
			continue
		if delivery_family == "rebound" and event.kind == "wall" and shot.remaining_bounces > 0:
			var normal: Vector2i = plan.wall.get("normal",Vector2i.ZERO)
			var velocity := _reflected(Vector2i(shot.velocity_x,shot.velocity_y),normal)
			shot.velocity_x = velocity.x
			shot.velocity_y = velocity.y
			shot.remaining_bounces -= 1
			shot.remainder_x = 0
			shot.remainder_y = 0
			var remainder: Vector2i = plan.finish-center
			var nudged := center+Vector2i(signi(normal.x),signi(normal.y))
			_repath(plan,nudged,nudged+_reflected(remainder,normal),float(event.fraction),world)
			_enqueue_path(plan,world,queue)
			spatial.update(plan)
			_enqueue_pairs(plan,spatial,queue,scheduled_pairs)
			world.combat_events.append({"type":"projectile_rebounded","projectile_id":shot.entity_id,"remaining_bounces":shot.remaining_bounces})
			continue
		if event.kind == "product":
			var product: Dictionary = world.hex_court.products.get(int(event.second), {})
			if not _product_eligible(product, shot, world.tick): continue
			var wire := int(product.recipe_wire_id)
			if wire in [301, 305, 306] or (wire == 329 and not _has_element(shot, 16)):
				if delivery_family == "fuse":
					HexExpandedDelivery.arm(shot,world.config)
					stationary.append(shot)
					ended[shot.entity_id] = true
					continue
				var damage := scaled_damage(shot)
				var absorbed := mini(int(product.capacity), damage) if wire == 306 and shot.element_wire_id == 6 else 0
				product.capacity -= absorbed
				product.health = maxi(0, int(product.health) - damage + absorbed)
				if absorbed > 0: shot.damage = ((damage - absorbed) * shot.initial_strength + shot.remaining_strength - 1) / maxi(1, shot.remaining_strength)
				if int(product.health) == 0: product.decay_tick = world.tick
				world.collision.refresh_surfaces(world.tick)
				_terminal(world, shot, event.point, "construct")
				ended[shot.entity_id] = true
				_enqueue_new_ground(plans, ended, queue, float(event.fraction), _source(shot), world)
				continue
			shot.chemistry_interaction_mask |= 1 << (wire - 301)
			if wire == 317:
				if world.hex_court.suppress_source(_source(shot), int(product.id)) <= 0:
					shot.chemistry_interaction_mask &= ~(1 << (wire - 301))
				continue
			if wire in [320, 335]:
				# Non-deflecting crossings retain their once-only interaction mask.
				# pulse_index belongs to actor-effect cadence, not optical contact.
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
				child.delivery_phase = shot.delivery_phase
				child.delivery_ticks = shot.delivery_ticks
				child.delivery_damage_remaining = shot.delivery_damage_remaining / 2
				shot.delivery_damage_remaining -= child.delivery_damage_remaining
				child.contact_entity_ids = shot.contact_entity_ids.duplicate()
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
			spatial.update(plan)
			_enqueue_pairs(plan, spatial, queue, scheduled_pairs)
			if child != null:
				var child_plan := {"entity_id": child.entity_id, "source_id": _source(child), "shot": child, "radius": child.radius,
					"remaining_strength": child.remaining_strength, "terminal_fraction": plan.terminal_fraction, "terminal_inclusive": true,
					"reason": plan.reason, "generation": -1}
				_repath(child_plan, center, center + ElementChemistrySystem.rotated_fifteen(original_remaining, -1), float(event.fraction), world)
				plans.append(child_plan)
				by_id[child.entity_id] = child_plan
				_enqueue_path(child_plan, world, queue)
				spatial.update(child_plan)
				_enqueue_pairs(child_plan, spatial, queue, scheduled_pairs)
			world.combat_events.append({"type": "hex_optical_contact", "projectile_id": shot.entity_id, "reaction_id": int(product.id), "recipe_wire_id": wire})
			continue
		if event.kind == "actor":
			var target := world.player(int(event.second))
			if target == null or not _eligible(shot, target, world.config): continue
			var local_fraction := (float(event.fraction) - float(plan.time)) / maxf(1e-12, 1.0 - float(plan.time))
			var point := ContinuousContact.circle_contact(plan.start, plan.finish, local_fraction, Vector2i(target.position_x, target.position_y), target.radius)
			var damage := scaled_damage(shot)
			var health_before := target.health
			if not PlayerResourcesSystem.damage(target, damage, world.config): continue
			SpellStatusPolicy.apply_hit(target,shot.source_wire_id,_source(shot),shot.owner_id,shot.team_id,health_before-target.health,world.config,SimCommand._normalized_direction(shot.velocity_x,shot.velocity_y))
			if target.health > 0 and shot.hit_control_duration_ms > 0:
				MovementSystem.apply_control_state(target, shot.hit_control_state, shot.hit_control_duration_ms, SimCommand._normalized_direction(shot.velocity_x, shot.velocity_y), shot.hit_control_speed, world.config, shot.hit_control_slow_ratio)
			world.combat_events.append({"type": "projectile_hit", "projectile_id": shot.entity_id, "source_wire_id": shot.source_wire_id, "owner_id": shot.owner_id, "target_id": target.entity_id, "damage": health_before - target.health, "contact_position": point})
			if target.actor_kind == PlayerState.ActorKind.CHAMPION and target.health == 0:
				world.combat_events.append({"type": "champion_defeated", "projectile_id": shot.entity_id, "owner_id": shot.owner_id, "target_id": target.entity_id})
			_terminal(world, shot, point, "actor", target.entity_id)
		else:
			var point: Vector2i = event.get("point", center)
			world.combat_events.append({"type": "projectile_impact" if event.kind == "wall" else "projectile_expired", "projectile_id": shot.entity_id, "wall_id": int(event.get("wall_id", 0)), "contact_position": point})
			_terminal(world, shot, point, "obstacle" if event.kind == "wall" else "range")
		ended[shot.entity_id] = true
		_enqueue_new_ground(plans, ended, queue, float(event.fraction), _source(shot), world)
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
	for held: ProjectileState in stationary:
		var held_ledger: Dictionary = world.hex_court.ledger_for_source(_source(held))
		if held_ledger.is_empty() or int(held_ledger.remaining_strength) <= 0 or world.hex_court.flight_quantity(_source(held),held.entity_id) <= 0: continue
		held.remaining_strength = int(held_ledger.remaining_strength)
		survivors.append(held)
	world.projectiles = survivors


static func _plan_point(plan: Dictionary, time: float) -> Vector2i:
	return ContinuousContact.point_at(plan.start, plan.finish, clampf((time - float(plan.time)) / maxf(1e-12, 1.0 - float(plan.time)), 0.0, 1.0))


# A terminal changes authoritative ownership at its TOI, not after the queue.
# New field contacts start at that global time; nothing can hit a field before
# its source actually deposited. Existing queued contacts revalidate normally.
static func _enqueue_new_ground(plans: Array[Dictionary], ended: Dictionary, queue: Workset.OrderedQueue, time: float, new_source: int, world: SimWorld) -> void:
	# This synchronous pass only queues contacts; authority cannot change until
	# it returns to the resolver. Existing fields were already scheduled, so
	# prepare the newly deposited source once instead of querying every field
	# for every surviving path and discarding the unrelated witnesses afterward.
	var new_fields: Array[Dictionary] = []
	for field: Dictionary in _ground_fields(world):
		if int(field.source) == new_source: new_fields.append(field)
	if new_fields.is_empty(): return
	for plan: Dictionary in plans:
		if ended.has(int(plan.entity_id)) or time > float(plan.terminal_fraction): continue
		var probe := plan.duplicate()
		probe.time = maxf(time, float(plan.time))
		probe.start = _plan_point(plan, float(probe.time))
		for field: Dictionary in _field_contacts(probe, world, new_fields):
			if int(field.field_source) != new_source: continue
			var fraction := float(probe.time) + (1.0 - float(probe.time)) * float(field.fraction)
			queue.append({"kind": "field", "fraction": fraction, "priority": 1, "first": int(plan.entity_id),
				"second": int(field.field_source), "generation": int(plan.generation), "point": field.point, "formed_after": float(probe.time)})


static func _repath(plan: Dictionary, start: Vector2i, finish: Vector2i, time: float, world: SimWorld) -> void:
	plan.start = start
	plan.finish = finish
	plan.time = time
	plan.generation = int(plan.generation) + 1
	plan.wall = ContinuousContact.wall_contact(start, finish, int(plan.radius), world.collision.base_world if world.collision is HexCollisionWorld else world.collision)


static func _enqueue_path(plan: Dictionary, world: SimWorld, queue: Workset.OrderedQueue, prepared_fields: Variant = null) -> void:
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
		if not _hostile_target(shot,actor): continue
		var local := ContinuousContact.circle_toi(plan.start, plan.finish, Vector2i(actor.position_x, actor.position_y), shot.radius + actor.radius)
		var fraction := float(plan.time) + (1.0 - float(plan.time)) * local
		if local < 0 or fraction > float(plan.terminal_fraction): continue
		var event := common.duplicate()
		event.merge({"kind": "actor" if _eligible(shot,actor,world.config) else "avoid", "fraction": fraction, "priority": 2, "second": actor.entity_id})
		queue.append(event)
	for field: Dictionary in _field_contacts(plan, world, prepared_fields):
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


static func _enqueue_pairs(plan: Dictionary, spatial: Workset.SpatialPlans, queue: Workset.OrderedQueue, scheduled: Dictionary) -> void:
	for other: Dictionary in spatial.query(plan):
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


static func _has_element(shot: ProjectileState, bit: int) -> bool:
	return (int(CombatTuning.cast_definition_view(shot.source_wire_id).get("element_mask",0)) & bit) != 0


static func _product_eligible(product: Dictionary, shot: ProjectileState, tick: int) -> bool:
	if product.is_empty() or tick < int(product.active_tick) or tick >= int(product.decay_tick): return false
	var wire := int(product.recipe_wire_id)
	if wire in [301, 305, 306] or (wire == 329 and not _has_element(shot, 16)): return int(product.health) > 0
	if wire not in [307, 317, 320, 325, 329, 335] or (shot.chemistry_interaction_mask & (1 << (wire - 301))) != 0: return false
	if wire in [325, 329] and not _has_element(shot, 16): return false
	if wire == 317 and (not _has_element(shot, 2) or int(product.capacity) <= 0): return false
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
		# Range and cover must share the physical impact origin. The flight
		# center can be a full Heavy radius behind it and see around a different
		# side of a corner. Move only one fixed unit toward that free center so
		# an inclusive wall/hex face does not block its own outward blast.
		var blast_origin := point + Vector2i(signi(shot.position_x - point.x), signi(shot.position_y - point.y))
		for target: PlayerState in world.players:
			if target.entity_id in [shot.owner_id, excluded_id] or target.team_id == shot.team_id or target.health <= 0 or target.spawn_protection_ticks > 0 or MovementSystem.is_combat_intangible(target, world.config) or MovementSystem.avoids_ground_effects(target): continue
			var target_point := Vector2i(target.position_x, target.position_y)
			if (target_point - point).length_squared() > (radius + target.radius) * (radius + target.radius): continue
			if not SprayInterception.clear_ray(blast_origin, target_point, world.collision, [], world.tick): continue
			var health_before := target.health
			if PlayerResourcesSystem.damage(target, damage, world.config):
				SpellStatusPolicy.apply_hit(target,shot.source_wire_id,_source(shot),shot.owner_id,shot.team_id,health_before-target.health,world.config,SimCommand._normalized_direction(target_point.x-point.x,target_point.y-point.y))
				world.combat_events.append({"type": "projectile_hit", "projectile_id": shot.entity_id, "source_wire_id": shot.source_wire_id,
					"owner_id": shot.owner_id, "target_id": target.entity_id, "damage": health_before - target.health, "contact_position": point})
				if target.actor_kind == PlayerState.ActorKind.CHAMPION and target.health == 0:
					world.combat_events.append({"type": "champion_defeated", "projectile_id": shot.entity_id, "owner_id": shot.owner_id, "target_id": target.entity_id})
	CombatSystem._emit_terminal(shot, world.combat_events, reason, point)
	var terminal_event: Dictionary = world.combat_events.back()
	world.hex_court.deposit_terminal(terminal_event, world.tick)
	terminal_event.hex_committed = true


static func _record_clash(world: SimWorld, shot: ProjectileState, other_wire: int, point: Vector2i, outcome: Dictionary) -> void:
	world.combat_events.append({"type": "hex_clash", "source_wire_id": shot.source_wire_id, "other_wire_id": other_wire,
		"owner_id": shot.owner_id, "projectile_id": shot.entity_id, "x": point.x, "y": point.y,
		"matched_strength": int(outcome.matched_strength), "first_remaining": int(outcome.first.post_strength), "second_remaining": int(outcome.second.post_strength),
		"recipe_wire_id": int(outcome.get("recipe_wire_id", 0)), "reaction_id": int(outcome.get("reaction_id", outcome.get("product_id", 0)))})


static func _record_field_clash(world: SimWorld, shot: ProjectileState, other_wire: int, field_source_id: int, point: Vector2i, outcome: Dictionary, quantization_outside: bool) -> void:
	world.combat_events.append({"type": "hex_clash", "contact_kind": "field", "source_wire_id": shot.source_wire_id, "other_wire_id": other_wire,
		"owner_id": shot.owner_id, "projectile_id": shot.entity_id, "field_source_id": field_source_id, "x": point.x, "y": point.y,
		"contact_quantization_outside": quantization_outside,
		"matched_strength": int(outcome.matched_strength), "first_remaining": int(outcome.first.post_strength), "second_remaining": int(outcome.second.post_strength),
		"recipe_wire_id": int(outcome.get("recipe_wire_id", 0)), "reaction_id": int(outcome.get("reaction_id", outcome.get("product_id", 0)))})
