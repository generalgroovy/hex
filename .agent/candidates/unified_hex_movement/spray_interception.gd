class_name SprayInterception
extends RefCounted
@warning_ignore_start("integer_division")

# Spray is instantaneous at release: interception is phase zero, before any
# projectile travels or deals damage this tick. It is not a persistent shield.
# This bounded slice resolves unequal direct strength; equal moving/pulse
# contacts remain B2 follow-up. Equal deposited ingredients retain B1 rules.
static func resolve(world: RefCounted) -> void:
	var requests: Array[Dictionary] = []
	for event: Dictionary in world.combat_events:
		if String(event.get("type", "")) == "spray_requested":
			requests.append(event)
	if requests.is_empty() or world.projectiles.is_empty():
		return
	requests.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.source_cast_id) < int(b.source_cast_id))
	var shots: Array = world.projectiles.duplicate()
	shots.sort_custom(func(a: ProjectileState, b: ProjectileState) -> bool: return a.entity_id < b.entity_id)
	var negated_casts := {}
	var outcomes: Array[Dictionary] = []
	for request: Dictionary in requests:
		var cast_id := int(request.source_cast_id)
		var definition := CombatSystem.spray_request_definition(request)
		var strength := int(definition.reaction_strength)
		var origin := Vector2i(int(request.origin_x), int(request.origin_y))
		var direction := Vector2i(int(request.aim_x), int(request.aim_y))
		if CombatSystem._beam_clear_endpoint(origin, direction, int(definition.range), int(definition.radius), world.collision) == origin:
			continue # Preserve the existing whole-pulse blocked-release gate.
		for shot: ProjectileState in shots:
			var shot_cast := shot.source_cast_id if shot.source_cast_id > 0 else shot.entity_id
			if negated_casts.has(cast_id):
				break
			if shot_cast == cast_id or negated_casts.has(shot_cast) or strength == shot.reaction_strength:
				continue
			var center := Vector2i(shot.position_x, shot.position_y)
			if not SprayContactGeometry.sector_intersects_circle(origin, direction, int(definition.range), int(definition.cone_cosine_squared_per_million), center, shot.radius):
				continue
			# This contact requires a clear zero-width ray to the projectile center.
			# Re-read live cover for each contact; never cache mutable cover.
			if not clear_ray(origin, center, world.collision, world.reactions, world.tick):
				continue
			var outcome := 1 if strength > shot.reaction_strength else 2
			negated_casts[shot_cast if outcome == 1 else cast_id] = true
			outcomes.append({"type": "spray_intercepted", "owner_id": int(request.owner_id),
				"source_wire_id": int(request.source_wire_id), "projectile_id": shot.entity_id,
				"other_wire_id": shot.source_wire_id, "x": center.x, "y": center.y, "outcome": outcome})
	# Remove the entire negated flight cast, including optical siblings. Existing
	# deposited ingredients are not projectile targets and are left intact.
	for index: int in range(world.projectiles.size() - 1, -1, -1):
		var shot: ProjectileState = world.projectiles[index]
		if negated_casts.has(shot.source_cast_id if shot.source_cast_id > 0 else shot.entity_id):
			world.projectiles.remove_at(index)
	for index: int in range(world.combat_events.size() - 1, -1, -1):
		var event: Dictionary = world.combat_events[index]
		if String(event.get("type", "")) == "spray_requested" and negated_casts.has(int(event.source_cast_id)):
			world.combat_events.remove_at(index)
	world.combat_events.append_array(outcomes)


static func clear_ray(start: Vector2i, end: Vector2i, collision: CollisionWorld, reactions: Array, tick: int) -> bool:
	if not collision.can_occupy(start, 0) or not collision.can_occupy(end, 0):
		return false
	if collision is HexCollisionWorld and not collision.hex_segment_clear(start, end):
		return false
	for obstacle: CollisionWorld.Obstacle in collision.obstacle_view():
		if segment_rect(start, end, Vector2i(obstacle.minimum_x, obstacle.minimum_y), Vector2i(obstacle.maximum_x, obstacle.maximum_y)):
			return false
	for reaction: ElementReactionState in reactions:
		if not reaction.active(tick) or reaction.health <= 0 or reaction.recipe_wire_id not in [301, 305, 306, 307, 329]:
			continue
		if reaction.recipe_wire_id == 301:
			var bounds := ElementChemistrySystem.rampart_bounds(reaction)
			if segment_rect(start, end, bounds.position, bounds.end):
				return false
		else:
			var origin := Vector2i(reaction.position_x, reaction.position_y)
			var shape := String(ElementChemistrySystem.RECIPE_ROWS[reaction.recipe_wire_id - 301][3])
			if shape in ["cover", "plane", "lens"]:
				var side := ElementChemistrySystem.scaled(Vector2i(-reaction.direction_y, reaction.direction_x), reaction.length / 2)
				if segment_capsule(start, end, origin - side, origin + side, reaction.radius):
					return false
			elif SprayContactGeometry.segment_intersects_circle(start, end, origin, reaction.radius):
				return false
	return true


static func segment_capsule(a: Vector2i, b: Vector2i, c: Vector2i, d: Vector2i, radius: int) -> bool:
	return segments_intersect(a, b, c, d) \
		or SprayContactGeometry.segment_intersects_circle(a, b, c, radius) \
		or SprayContactGeometry.segment_intersects_circle(a, b, d, radius) \
		or SprayContactGeometry.segment_intersects_circle(c, d, a, radius) \
		or SprayContactGeometry.segment_intersects_circle(c, d, b, radius)


static func segment_rect(a: Vector2i, b: Vector2i, low: Vector2i, high: Vector2i) -> bool:
	if maxi(a.x, b.x) < low.x or mini(a.x, b.x) > high.x or maxi(a.y, b.y) < low.y or mini(a.y, b.y) > high.y:
		return false
	if a.x >= low.x and a.x <= high.x and a.y >= low.y and a.y <= high.y:
		return true
	if b.x >= low.x and b.x <= high.x and b.y >= low.y and b.y <= high.y:
		return true
	var top_right := Vector2i(high.x, low.y)
	var bottom_left := Vector2i(low.x, high.y)
	return segments_intersect(a, b, low, top_right) or segments_intersect(a, b, top_right, high) or segments_intersect(a, b, high, bottom_left) or segments_intersect(a, b, bottom_left, low)


static func segments_intersect(a: Vector2i, b: Vector2i, c: Vector2i, d: Vector2i) -> bool:
	if maxi(a.x, b.x) < mini(c.x, d.x) or maxi(c.x, d.x) < mini(a.x, b.x) or maxi(a.y, b.y) < mini(c.y, d.y) or maxi(c.y, d.y) < mini(a.y, b.y):
		return false
	var ab := b - a
	var cd := d - c
	var ac := c - a
	var ad := d - a
	var ca := a - c
	var cb := b - c
	var first := signi(ab.x * ac.y - ab.y * ac.x)
	var second := signi(ab.x * ad.y - ab.y * ad.x)
	var third := signi(cd.x * ca.y - cd.y * ca.x)
	var fourth := signi(cd.x * cb.y - cd.y * cb.x)
	return (first == 0 or second == 0 or first != second) and (third == 0 or fourth == 0 or third != fourth)
