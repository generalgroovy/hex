class_name HeavyBlastPresenter
extends RefCounted

# Aftermath only: damage already resolved. This does not replace the 16px pixel
# impact or the 32px deposit. A deposit consumed by chemistry leaves no cue.
const DURATION_TICKS: int = 36
const RAY_COUNT: int = 64
const CACHE_LIMIT: int = 64
const SEARCH_STEPS: int = 8
const INK := Color("eddbb6")
var _cache: Dictionary = {}
var _order: Array[String] = []
var _stats := {"builds": 0, "cache_hits": 0, "line_checks": 0}


func stats() -> Dictionary:
	var result := _stats.duplicate()
	result["cache_entries"] = _cache.size()
	return result


func draw(canvas: CanvasItem, deposit: ElementDepositState, world_tick: int, config: SimConfig, collision: CollisionWorld, reactions: Array[ElementReactionState], reduced: bool = false) -> void:
	if canvas == null:
		return
	var cue := model(deposit, world_tick, config, collision, reactions, reduced)
	if cue.is_empty():
		return
	if not (cue.spokes as PackedVector2Array).is_empty():
		canvas.draw_multiline(cue.spokes, Color(INK, float(cue.opacity) * 0.20), 1.0, false)
	if not (cue.boundary_ticks as PackedVector2Array).is_empty():
		canvas.draw_multiline(cue.boundary_ticks, Color(INK, float(cue.opacity)), 1.0, false)


func model(deposit: ElementDepositState, world_tick: int, config: SimConfig, collision: CollisionWorld, reactions: Array[ElementReactionState], _reduced: bool = false) -> Dictionary:
	if deposit == null or config == null or not config.is_valid() or not deposit.validate():
		return {}
	var age := world_tick - deposit.created_tick
	if age < 0 or age >= DURATION_TICKS or world_tick >= deposit.expiry_tick:
		return {}
	var definition := CombatTuning.cast_definition(deposit.source_wire_id)
	var radius := int(definition.get("blast_radius", 0))
	if radius <= 0 or int(definition.get("blast_damage", 0)) <= 0 or radius > 120_000:
		return {}
	var origin := Vector2i(deposit.position_x, deposit.position_y)
	var key_values: Array = [origin, radius, deposit.radius]
	var extent := Rect2(Vector2(origin - Vector2i(radius, radius)), Vector2.ONE * radius * 2)
	if collision != null:
		key_values.append(Vector2i(collision.width, collision.height))
		for obstacle: CollisionWorld.Obstacle in collision.obstacle_view():
			var bounds := Rect2(obstacle.minimum_x, obstacle.minimum_y, obstacle.maximum_x - obstacle.minimum_x, obstacle.maximum_y - obstacle.minimum_y)
			if extent.intersects(bounds, true):
				key_values.append(bounds)
	# Include every active positive-health obstacle used by the real predicate.
	# Contacts, pulses and capacity never change cover shape and must not churn
	# this expensive cache. Death/phase and every geometry field still invalidate.
	for reaction: ElementReactionState in reactions:
		if reaction.health > 0 and reaction.active(world_tick):
			key_values.append([reaction.recipe_wire_id, reaction.position_x, reaction.position_y,
				reaction.origin_x, reaction.origin_y, reaction.direction_x, reaction.direction_y,
				reaction.radius, reaction.length, reaction.endpoint_x, reaction.endpoint_y,
				reaction.created_tick, reaction.active_tick, reaction.decay_tick, reaction.expiry_tick,
				reaction.path_points])
	var key := str(key_values)
	var geometry: Dictionary
	if _cache.has(key):
		_stats.cache_hits += 1
		geometry = _cache[key]
	else:
		geometry = _build(origin, radius, deposit.radius, world_tick, config, collision, reactions)
		_stats.builds += 1
		if _order.size() >= CACHE_LIMIT:
			_cache.erase(_order.pop_front())
		_order.append(key)
		_cache[key] = geometry
	# A static footprint fades monotonically. Reduced effects retain the same
	# essential information, never a weaker/missing damage-radius explanation.
	return {"origin": Vector2(origin) / 1000.0, "radius": float(radius) / 1000.0,
		"boundary_ticks": geometry.boundary_ticks, "spokes": geometry.spokes,
		"opacity": 0.72 * float(DURATION_TICKS - age) / DURATION_TICKS,
		"age_ticks": age, "duration_ticks": DURATION_TICKS, "aftermath_only": true}


func _build(origin: Vector2i, radius: int, deposit_radius: int, tick: int, config: SimConfig, collision: CollisionWorld, reactions: Array[ElementReactionState]) -> Dictionary:
	var boundary := PackedVector2Array()
	var spokes := PackedVector2Array()
	for index: int in range(RAY_COUNT):
		var direction := Vector2.from_angle(TAU * index / RAY_COUNT)
		var reach := float(radius)
		if not _clear(origin, origin + Vector2i((direction * reach).round()), tick, config, collision, reactions):
			var low := 0.0
			var high := reach
			for _search: int in range(SEARCH_STEPS):
				var middle := (low + high) * 0.5
				if _clear(origin, origin + Vector2i((direction * middle).round()), tick, config, collision, reactions):
					low = middle
				else:
					high = middle
			reach = low
		# Short radial ticks cannot connect across a hidden wedge like a circle
		# chord could. Leave the original central impact/deposit visibly separate.
		if reach <= deposit_radius + 4000:
			continue
		var end := Vector2(origin + Vector2i((direction * reach).round())) / 1000.0
		var start := end - direction * 2.0
		boundary.append_array(PackedVector2Array([start, end]))
		if index % 8 == 0 and reach > deposit_radius + 10_000:
			spokes.append_array(PackedVector2Array([Vector2(origin) / 1000.0 + direction * float(deposit_radius + 6000) / 1000.0, start - direction * 2.0]))
	return {"boundary_ticks": boundary, "spokes": spokes}


func _clear(origin: Vector2i, point: Vector2i, tick: int, config: SimConfig, collision: CollisionWorld, reactions: Array[ElementReactionState]) -> bool:
	_stats.line_checks += 1
	return CombatSystem.blast_clear_line(origin, point, collision, reactions, tick, config)
