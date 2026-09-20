extends "res://src/sim/combat/combat_system.gd"
@warning_ignore_start("integer_division")

# TEST ONLY: source-derived projectile loop with observation calls around the
# current batch candidate, Frostway, movement, production chemistry, and actor paths.

static var counts: Dictionary = {}
static var times: Dictionary = {}

static func reset() -> void:
	counts = {"projectile_batches":0,"projectiles":0,"input_reactions":0,"reaction_candidates":0,"frostway_rows":0,"move_calls":0,"interaction_calls":0,"actor_candidates":0,"segment_hits":0,"splits":0,"terminals":0}
	counts.merge({"edgeweave_calls":0,"construct_terminals":0,"actor_terminals":0,"wall_terminals":0,"range_terminals":0,"survivors":0})
	times = {"candidate_batch_us":0,"frostway_capture_us":0,"travel_us":0,"move_us":0,"interaction_us":0,"actor_scan_us":0,"resolution_us":0,"edgeweave_us":0,"split_construction_us":0,"terminal_us":0,"expiry_survivor_us":0}

static func measured_advance_projectiles(
	projectiles: Array[ProjectileState],
	players: Array[PlayerState],
	config: SimConfig,
	world: CollisionWorld,
	events: Array[Dictionary],
	reactions: Array[ElementReactionState] = [],
	current_tick: int = 0,
	available_chemistry_slots: int = 0,
	owner_material_slots: Dictionary = {},
) -> Array[ProjectileState]:
	counts.projectile_batches += 1
	counts.projectiles += projectiles.size()
	counts.input_reactions += reactions.size()
	var survivors: Array[ProjectileState] = []
	var ordered_players: Array[PlayerState] = players.duplicate()
	ordered_players.sort_custom(func(left: PlayerState, right: PlayerState) -> bool: return left.entity_id < right.entity_id)
	var projectile_reactions: Array[ElementReactionState] = []
	var frostway_lanes := PackedInt32Array()
	if not projectiles.is_empty():
		var began := Time.get_ticks_usec()
		projectile_reactions = _projectile_reaction_candidates(reactions, current_tick)
		times.candidate_batch_us += Time.get_ticks_usec() - began
		counts.reaction_candidates += projectile_reactions.size()
		began = Time.get_ticks_usec()
		frostway_lanes = FrostwayFieldPolicy.capture(reactions, current_tick)
		times.frostway_capture_us += Time.get_ticks_usec() - began
		counts.frostway_rows += int(frostway_lanes.size() / FrostwayFieldPolicy.ROW_WIDTH)
	for projectile: ProjectileState in projectiles:
		var began := Time.get_ticks_usec()
		projectile.previous_x = projectile.position_x
		projectile.previous_y = projectile.position_y
		# Recompute material context from the current center each authority tick.
		# Never mutate base velocity: exit/expiry restores travel immediately,
		# and duplicate/overlapping lanes cannot exponentially slow a projectile.
		var travel_ratio := FrostwayFieldPolicy.projectile_ratio(frostway_lanes, Vector2i(projectile.position_x, projectile.position_y), current_tick)
		var total_x: int = projectile.remainder_x + projectile.velocity_x * travel_ratio / 1000
		var total_y: int = projectile.remainder_y + projectile.velocity_y * travel_ratio / 1000
		@warning_ignore("integer_division")
		var delta := Vector2i(total_x / config.tick_rate, total_y / config.tick_rate)
		projectile.remainder_x = total_x - delta.x * config.tick_rate
		projectile.remainder_y = total_y - delta.y * config.tick_rate
		var step_distance := SimCommand._integer_square_root(delta.x * delta.x + delta.y * delta.y)
		if projectile.remaining_distance >= 0 and step_distance > projectile.remaining_distance:
			delta = Vector2i(delta.x * projectile.remaining_distance / maxi(1, step_distance), delta.y * projectile.remaining_distance / maxi(1, step_distance))
			step_distance = projectile.remaining_distance
		times.travel_us += Time.get_ticks_usec() - began
		began = Time.get_ticks_usec()
		var result: CollisionWorld.MoveResult = world.move_box(
			Vector2i(projectile.position_x, projectile.position_y),
			delta,
			projectile.radius,
		)
		counts.move_calls += 1
		projectile.position_x = result.position.x
		projectile.position_y = result.position.y
		if projectile.remaining_distance >= 0:
			projectile.remaining_distance = maxi(0, projectile.remaining_distance - step_distance)
		times.move_us += Time.get_ticks_usec() - began
		if not projectile_reactions.is_empty():
			var split_capacity := mini(available_chemistry_slots, int(owner_material_slots.get(projectile.owner_id, 0)))
			began = Time.get_ticks_usec()
			var interaction := ElementChemistrySystem.projectile_interaction(projectile, projectile_reactions, world, config, current_tick, split_capacity)
			times.interaction_us += Time.get_ticks_usec() - began
			counts.interaction_calls += 1
			if bool(interaction.get("blocked", false)):
				began = Time.get_ticks_usec()
				_rewind_heavy_cover_contact(projectile, config, world, reactions, current_tick)
				_explode_projectile(projectile, ordered_players, config, world, reactions, current_tick, events)
				_emit_terminal(projectile, events, "construct")
				counts.terminals += 1
				counts.construct_terminals += 1
				var terminal_elapsed := Time.get_ticks_usec() - began
				times.terminal_us += terminal_elapsed
				times.resolution_us += terminal_elapsed
				continue
			if interaction.get("split_velocity", Vector2i.ZERO) != Vector2i.ZERO and split_capacity > 0:
				began = Time.get_ticks_usec()
				var child := ProjectileState.new(0, projectile.owner_id, projectile.team_id, projectile.source_wire_id, projectile.element_wire_id,
					Vector2i(projectile.position_x, projectile.position_y), interaction["split_velocity"], projectile.radius,
					int(interaction.get("split_damage", 0)), projectile.lifetime_ticks, projectile.hit_control_state,
					projectile.hit_control_duration_ms, projectile.hit_control_speed, projectile.hit_control_slow_ratio)
				child.remaining_distance = projectile.remaining_distance
				child.source_cast_id = projectile.source_cast_id
				child.material_strength = maxi(1, projectile.material_strength / 2) if projectile.material_strength > 0 else 0
				projectile.material_strength = maxi(1, projectile.material_strength - child.material_strength) if projectile.material_strength > 0 else 0
				child.chemistry_interaction_mask = projectile.chemistry_interaction_mask
				child.grazed_entity_ids = projectile.grazed_entity_ids.duplicate()
				events.append({"type": "chemistry_projectile_split", "projectile": child})
				available_chemistry_slots -= 1
				owner_material_slots[projectile.owner_id] = split_capacity - 1
				counts.splits += 1
				var split_elapsed := Time.get_ticks_usec() - began
				times.split_construction_us += split_elapsed
				times.resolution_us += split_elapsed

		began = Time.get_ticks_usec()
		var hit_entity_id: int = 0
		for target: PlayerState in ordered_players:
			if target.entity_id == projectile.owner_id or target.team_id == projectile.team_id or target.health <= 0 or target.spawn_protection_ticks > 0:
				continue
			counts.actor_candidates += 1
			var hit_radius: int = target.radius + projectile.radius
			if _segment_circle_hit(projectile, target, hit_radius):
				counts.segment_hits += 1
				if MovementSystem.is_combat_intangible(target, config) or target.air_height >= MovementTuning.GROUND_PROJECTILE_CLEARANCE_HEIGHT:
					target.last_event = "evaded_projectile"
					continue
				PlayerResourcesSystem.damage(target, projectile.damage, config)
				if target.health > 0 and projectile.hit_control_duration_ms > 0:
					MovementSystem.apply_control_state(
						target,
						projectile.hit_control_state,
						projectile.hit_control_duration_ms,
						SimCommand._normalized_direction(projectile.velocity_x, projectile.velocity_y),
						projectile.hit_control_speed,
						config,
						projectile.hit_control_slow_ratio,
					)
				hit_entity_id = target.entity_id
				events.append({
					"type": "projectile_hit",
					"projectile_id": projectile.entity_id,
					"source_wire_id": projectile.source_wire_id,
					"owner_id": projectile.owner_id,
					"target_id": target.entity_id,
					"damage": projectile.damage,
				})
				if target.actor_kind == PlayerState.ActorKind.CHAMPION and target.health == 0:
					events.append({
						"type": "champion_defeated",
						"projectile_id": projectile.entity_id,
						"owner_id": projectile.owner_id,
						"target_id": target.entity_id,
					})
				break
		times.actor_scan_us += Time.get_ticks_usec() - began

		began = Time.get_ticks_usec()
		_resolve_edgeweave(projectile, ordered_players, hit_entity_id, config, events)
		times.edgeweave_us += Time.get_ticks_usec() - began
		counts.edgeweave_calls += 1
		# Nested intervals retain actual production calls. The enclosing resolution
		# interval includes observer bookkeeping; percentiles must not be added.
		var resolution_began := Time.get_ticks_usec()
		if hit_entity_id != 0:
			_explode_projectile(projectile, ordered_players, config, world, reactions, current_tick, events, hit_entity_id)
			_emit_terminal(projectile, events, "actor")
			counts.terminals += 1
			counts.actor_terminals += 1
			times.terminal_us += Time.get_ticks_usec() - resolution_began
			times.resolution_us += Time.get_ticks_usec() - began
			continue
		if result.wall_normal != Vector2i.ZERO:
			events.append({"type": "projectile_impact", "projectile_id": projectile.entity_id, "wall_id": result.wall_id})
			_explode_projectile(projectile, ordered_players, config, world, reactions, current_tick, events)
			_emit_terminal(projectile, events, "obstacle")
			counts.terminals += 1
			counts.wall_terminals += 1
			times.terminal_us += Time.get_ticks_usec() - resolution_began
			times.resolution_us += Time.get_ticks_usec() - began
			continue
		projectile.lifetime_ticks = maxi(0, projectile.lifetime_ticks - 1)
		if projectile.lifetime_ticks == 0 or projectile.remaining_distance == 0:
			times.expiry_survivor_us += Time.get_ticks_usec() - resolution_began
			resolution_began = Time.get_ticks_usec()
			events.append({"type": "projectile_expired", "projectile_id": projectile.entity_id})
			_explode_projectile(projectile, ordered_players, config, world, reactions, current_tick, events)
			_emit_terminal(projectile, events, "range")
			counts.terminals += 1
			counts.range_terminals += 1
			times.terminal_us += Time.get_ticks_usec() - resolution_began
			times.resolution_us += Time.get_ticks_usec() - began
			continue
		survivors.append(projectile)
		counts.survivors += 1
		times.expiry_survivor_us += Time.get_ticks_usec() - resolution_began
		times.resolution_us += Time.get_ticks_usec() - began
	return survivors
