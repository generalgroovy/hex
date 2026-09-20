extends "res://src/sim/chemistry/element_chemistry_system.gd"
@warning_ignore_start("integer_division")

# TEST ONLY: source-derived interaction/entry/line bodies with observation only.
# Combat supplies the current batch-local active/wire candidate list. Every
# paired tick checks exact canonical state and ordered events. Timings nest and
# include counter/timer overhead; never sum nested buckets as total work.
static var counts: Dictionary = {}
static var times: Dictionary = {}
static var wires: Dictionary = {}

static func reset() -> void:
	counts = {"interaction_calls":0,"reactions_visited":0,"active_reactions_visited":0,"eligible_reactions":0,"entry_calls":0,"bounds_rejected":0,"contains_samples":0,"entry_hits":0,"clear_line_calls":0,"clear_line_samples":0,"reaction_id_assignments":0,"already_masked_after_geometry":0}
	times = {"interaction_us":0,"entry_us":0,"bounds_us":0,"contains_us":0,"clear_line_us":0}
	wires = {}

static func measured_interaction(projectile: ProjectileState,reactions: Array,collision: CollisionWorld,config: SimConfig,tick: int,available_projectiles: int = 0) -> Dictionary:
	var began := Time.get_ticks_usec()
	counts.interaction_calls += 1
	var response := {"blocked":false,"reflected":false,"bent":false,"split_velocity":Vector2i.ZERO,"split_damage":0,"reaction_id":0}
	var start := Vector2i(projectile.previous_x,projectile.previous_y)
	var end := Vector2i(projectile.position_x,projectile.position_y)
	for result: ElementReactionState in reactions:
		counts.reactions_visited += 1
		if not result.active(tick):
			continue
		counts.active_reactions_visited += 1
		var wire := result.recipe_wire_id
		if wire not in [301,305,306,307,320,325,329,335]:
			continue
		counts.eligible_reactions += 1
		wires[wire] = int(wires.get(wire,0))+1
		var entry_began := Time.get_ticks_usec()
		var entry := measured_entry(result,start,end,tick,config)
		times.entry_us += Time.get_ticks_usec()-entry_began
		if not bool(entry.hit):
			continue
		var line_began := Time.get_ticks_usec()
		var line_clear := measured_clear_line(start,Vector2i(result.position_x,result.position_y),collision)
		times.clear_line_us += Time.get_ticks_usec()-line_began
		if not line_clear:
			continue
		response["reaction_id"] = result.entity_id
		counts.reaction_id_assignments += 1
		if wire in [301,305,306] or (wire == 329 and projectile.element_wire_id != 7):
			if result.health <= 0:
				continue
			if wire == 306 and projectile.element_wire_id == 6 and result.capacity > 0:
				var absorbed := mini(result.capacity,projectile.damage)
				result.capacity -= absorbed
				projectile.damage -= absorbed
				# Capacity absorbs first; residual damage hits the physical node,
				# never both the node and an actor behind it (same rule as beams).
				response["blocked"] = true
				if projectile.damage > 0:
					result.health = maxi(0,result.health-projectile.damage)
			else:
				result.health = maxi(0,result.health-projectile.damage)
				response["blocked"] = true
			if result.health == 0:
				result.decay_tick = mini(result.decay_tick,tick)
			times.interaction_us += Time.get_ticks_usec()-began
			return response
		var bit: int = 1 << (wire-301)
		if (projectile.chemistry_interaction_mask & bit) != 0:
			counts.already_masked_after_geometry += 1
			continue
		if wire in [320,335]:
			# The observer marker is a state event, not damage or optical bending.
			result.pulse_index = tick
			projectile.chemistry_interaction_mask |= bit
			continue
		if wire == 307:
			var normal := Vector2i(result.direction_x,result.direction_y)
			var velocity := Vector2i(projectile.velocity_x,projectile.velocity_y)
			var dot: int = (velocity.x*normal.x+velocity.y*normal.y)/1000
			velocity -= scaled(normal,2*dot)
			projectile.velocity_x = velocity.x
			projectile.velocity_y = velocity.y
			response["reflected"] = true
		elif wire in [325,329] and projectile.element_wire_id == 7:
			if wire == 329 and (available_projectiles <= 0 or projectile.damage < 2):
				continue # No capacity means no split and no material/damage loss.
			var velocity := Vector2i(projectile.velocity_x,projectile.velocity_y)
			var turned := rotated_fifteen(velocity,1)
			projectile.velocity_x = turned.x
			projectile.velocity_y = turned.y
			response["bent"] = true
			if wire == 329:
				var child_damage := projectile.damage/2
				projectile.damage -= child_damage
				response["split_damage"] = child_damage
				response["split_velocity"] = rotated_fifteen(velocity,-1)
		else:
			continue
		projectile.chemistry_interaction_mask |= bit
		projectile.remainder_x = 0
		projectile.remainder_y = 0
		times.interaction_us += Time.get_ticks_usec()-began
		return response
	times.interaction_us += Time.get_ticks_usec()-began
	return response

static func measured_entry(result: ElementReactionState,start: Vector2i,end: Vector2i,tick: int,config: SimConfig) -> Dictionary:
	counts.entry_calls += 1
	var began := Time.get_ticks_usec()
	var overlaps := _entry_bounds_overlap(result,start,end)
	times.bounds_us += Time.get_ticks_usec()-began
	if not overlaps:
		counts.bounds_rejected += 1
		return {"hit":false,"point":end}
	var delta := end-start
	var count := mini(512,maxi(1,(SimCommand._integer_square_root(delta.length_squared())+1999)/2000))
	for index: int in range(count+1):
		var point := start+scaled(delta,index*1000/count)
		counts.contains_samples += 1
		var sample_began := Time.get_ticks_usec()
		var inside := contains(result,point,tick,config)
		times.contains_us += Time.get_ticks_usec()-sample_began
		if inside:
			counts.entry_hits += 1
			return {"hit":true,"point":point}
	return {"hit":false,"point":end}

static func measured_clear_line(start: Vector2i,end: Vector2i,collision: CollisionWorld) -> bool:
	counts.clear_line_calls += 1
	if collision == null:
		return true
	# Swept AABB axis ordering is not a ray test. Sample a bounded line at
	# <=2px intervals, matching ordinary beam contact clearance semantics.
	var delta := end-start
	var distance := SimCommand._integer_square_root(delta.length_squared())
	var count := mini(512,maxi(1,(distance+1999)/2000))
	for index: int in range(1,count+1):
		counts.clear_line_samples += 1
		if not collision.can_occupy(start+scaled(delta,index*1000/count),0):
			return false
	return true
