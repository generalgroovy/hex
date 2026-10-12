class_name CombatSystem
extends RefCounted
@warning_ignore_start("integer_division")
const Perks = preload("res://src/sim/entities/identity_perk_policy.gd")


static func step_player(
	state: PlayerState,
	command: SimCommand,
	config: SimConfig,
	projectile_id: int,
	field_id: int,
	world: CollisionWorld,
	events: Array[Dictionary],
	transition_policy: ActionTransitionPolicy,
	available_projectiles: int = -1,
	available_fields: int = -1,
	admission_policy: RefCounted = null,
) -> Variant:
	for property_name: StringName in [
		&"cast_recovery_ticks", &"edgeweave_cooldown_ticks",
	]:
		state.set(property_name, maxi(0, int(state.get(property_name)) - 1))
	state.advance_spell_cooldowns()

	var requested_spell_slot: int = command.first_pressed_spell_slot()
	var requested_spell_wire_id: int = state.spell_wire_id(requested_spell_slot)
	var pressed_cast_intent := requested_spell_slot > 0 or command.has_pressed(SimCommand.PRESSED_ACTIVE_1)
	var requested_wire_id := requested_spell_wire_id
	if requested_spell_slot == 0 and command.has_pressed(SimCommand.PRESSED_ACTIVE_1):
		requested_wire_id = state.active_1_wire_id
	var held_slot := 0 if pressed_cast_intent else _first_held_repeating_slot(state, command)
	var repeating_slot := held_slot > 0
	if repeating_slot:
		requested_spell_slot = held_slot
		requested_wire_id = state.spell_wire_id(held_slot)
		requested_spell_wire_id = requested_wire_id
	var held_primary_intent := not pressed_cast_intent and not repeating_slot and command.has_held(SimCommand.HELD_PRIMARY)
	if held_primary_intent:
		requested_wire_id = state.primary_wire_id

	if state.pending_cast_wire_id != 0:
		# Release must also reject stale or injected disabled casts.
		if not CombatTuning.is_runtime_wire_id(state.pending_cast_wire_id):
			_refuse_cast(state, state.pending_cast_wire_id, 0, "kit", events)
			state.pending_cast_wire_id = 0
			state.pending_cast_ticks = 0
			return null
		if pressed_cast_intent:
			_refuse_cast(state, requested_wire_id, requested_spell_slot, transition_policy.cast_gate_reason(state), events)
		state.pending_cast_ticks = maxi(0, state.pending_cast_ticks - 1)
		if state.pending_cast_ticks == 0:
			return _release_cast(state, config, projectile_id, field_id, world, events)
		return null
	var gate_reason := transition_policy.cast_gate_reason(state)
	if not gate_reason.is_empty() and (pressed_cast_intent or held_primary_intent or repeating_slot):
		if pressed_cast_intent:
			_refuse_cast(state, requested_wire_id, requested_spell_slot, gate_reason, events)
		return null

	if requested_spell_slot > 0 and requested_spell_wire_id == 0:
		_refuse_cast(state, 0, requested_spell_slot, "empty_slot", events)
		return null
	if not pressed_cast_intent and not held_primary_intent and not repeating_slot:
		return null
	if not CombatTuning.is_runtime_wire_id(requested_wire_id) or (state.spell_slot_index_for_wire(requested_wire_id) < 0 and requested_wire_id not in state.kit_spell_wire_ids()):
		_refuse_cast(state, requested_wire_id, requested_spell_slot, "kit", events)
		return null
	if state.spell_cooldown_for_wire(requested_wire_id) > 0:
		if pressed_cast_intent:
			_refuse_cast(state, requested_wire_id, requested_spell_slot, "cooldown", events)
		return null
	var definition := CombatTuning.cast_definition_view(requested_wire_id)
	if definition.is_empty():
		_refuse_cast(state, requested_wire_id, requested_spell_slot, "kit", events)
		return null
	if admission_policy == null and String(definition.get("family", "")) in ["mantle", "fuse", "split", "rebound"]:
		_refuse_cast(state, requested_wire_id, requested_spell_slot, "requires_hex_authority", events)
		return null
	if admission_policy != null:
		var reason: String = admission_policy.admission_reason(requested_wire_id)
		if not reason.is_empty():
			# Held capacity retries follow the ordinary silent capacity/Flux gates.
			# Preparation, unsupported delivery and extension errors stay explicit.
			if pressed_cast_intent or reason != "hex_capacity":
				_refuse_cast(state, requested_wire_id, requested_spell_slot, reason, events)
			return null
	var required_capacity := cast_capacity_requirement(requested_wire_id)
	if (available_projectiles >= 0 and required_capacity.x > available_projectiles) \
		or (available_fields >= 0 and required_capacity.y > available_fields):
		if pressed_cast_intent:
			_refuse_cast(state, requested_wire_id, requested_spell_slot, "capacity", events)
		return null
	if admission_policy != null and not admission_policy.reserve_cast(state.entity_id, requested_wire_id):
		# Preserve the existing failure taxonomy without requerying the policy.
		if pressed_cast_intent:
			_refuse_cast(state, requested_wire_id, requested_spell_slot, "hex_capacity", events)
		return null
	var admission_timing := Perks.spell_timing(state, definition, config, SpellStatusPolicy.startup_ratio(state))
	var admission_startup_ms := maxi(1, int(definition["startup_ms"]) * int(admission_timing.startup_ratio) / 1000)
	admission_startup_ms = maxi(1,admission_startup_ms*SpellStatusPolicy.startup_ratio(state)/1000)
	if not PlayerResourcesSystem.spend_flux(state, int(definition["flux_cost"]), config):
		if admission_policy != null:
			admission_policy.cancel_pending(state.entity_id)
		if pressed_cast_intent:
			_refuse_cast(state, requested_wire_id, requested_spell_slot, "flux", events)
		return null
	_begin_cast(state, requested_wire_id, admission_startup_ms, config, command)
	if admission_policy != null:
		admission_policy.commit_payment(state.entity_id)
	events.append({"type": "cast_started", "entity_id": state.entity_id, "wire_id": requested_wire_id})
	return null


static func _first_held_repeating_slot(state: PlayerState, command: SimCommand) -> int:
	if (command.held_actions & SimCommand.SPELL_ACTION_MASK) == 0:
		return 0
	# Single-press families and empty positions do not own held intent. Among
	# repeating positions, the lowest slot keeps deterministic priority even
	# when its ordinary cooldown/resource/capacity gate refuses admission.
	for index: int in range(SimCommand.SPELL_HELD_BITS.size()):
		if command.has_held(SimCommand.SPELL_HELD_BITS[index]) and bool(CombatTuning.cast_definition_view(state.spell_wire_id(index + 1)).get("repeat_while_held", false)):
			return index + 1
	return 0


static func cast_capacity_requirement(wire_id: int) -> Vector2i:
	var definition := CombatTuning.cast_definition_view(wire_id)
	match String(definition.get("shape", "")):
		"projectile":
			return Vector2i((definition.get("projectile_rotations", [Vector2i(1000, 0)]) as Array).size(), 0)
		"field":
			return Vector2i(0, 1)
		"spray":
			return Vector2i(1, 0) # One shared terminal ingredient, reserved before payment.
	return Vector2i.ZERO


static func _refuse_cast(
	state: PlayerState,
	wire_id: int,
	slot: int,
	reason: String,
	events: Array[Dictionary],
) -> void:
	events.append({
		"type": "cast_refused",
		"entity_id": state.entity_id,
		"wire_id": wire_id,
		"reason": reason,
		"slot": slot,
	})
	state.last_event = "cast_refused_%s_%d" % [reason, wire_id]


static func advance_projectiles(
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
	var survivors: Array[ProjectileState] = []
	var ordered_players: Array[PlayerState] = players.duplicate()
	ordered_players.sort_custom(func(left: PlayerState, right: PlayerState) -> bool: return left.entity_id < right.entity_id)
	var projectile_reactions: Array[ElementReactionState] = []
	var frostway_lanes := PackedInt32Array()
	if not projectiles.is_empty():
		projectile_reactions = _projectile_reaction_candidates(reactions, current_tick)
		frostway_lanes = FrostwayFieldPolicy.capture(reactions, current_tick)
	for projectile: ProjectileState in projectiles:
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
		if projectile.remaining_distance >= 0:
			var length := sqrt(float(delta.x) * float(delta.x) + float(delta.y) * float(delta.y))
			var step_subunits := roundi(length * ProjectileState.RANGE_SUBUNITS)
			var available := projectile.remaining_distance * ProjectileState.RANGE_SUBUNITS - projectile.range_subunit
			if step_subunits >= available:
				var fraction := float(available) / maxf(1.0, length * ProjectileState.RANGE_SUBUNITS)
				delta = ContinuousContact.point_at(Vector2i.ZERO, delta, fraction)
				projectile.remaining_distance = 0
				projectile.range_subunit = 0
			else:
				var spent := projectile.range_subunit + step_subunits
				projectile.remaining_distance -= spent / ProjectileState.RANGE_SUBUNITS
				projectile.range_subunit = spent % ProjectileState.RANGE_SUBUNITS
		var travel_start := Vector2i(projectile.position_x, projectile.position_y)
		var travel_end := travel_start + delta
		var wall_contact := ContinuousContact.wall_contact(travel_start, travel_end, projectile.radius, world)
		var result := CollisionWorld.MoveResult.new(travel_end)
		var terminal_point: Variant = null
		if not wall_contact.is_empty():
			result = CollisionWorld.MoveResult.new(wall_contact.center, wall_contact.normal, int(wall_contact.id))
			terminal_point = wall_contact.point
		projectile.position_x = result.position.x
		projectile.position_y = result.position.y
		if not projectile_reactions.is_empty():
			var split_capacity := mini(available_chemistry_slots, int(owner_material_slots.get(projectile.owner_id, 0)))
			var interaction := ElementChemistrySystem.projectile_interaction(projectile, projectile_reactions, world, config, current_tick, split_capacity)
			if bool(interaction.get("blocked", false)):
				_rewind_heavy_cover_contact(projectile, config, world, reactions, current_tick)
				_explode_projectile(projectile, ordered_players, config, world, reactions, current_tick, events)
				_emit_terminal(projectile, events, "construct")
				continue
			if interaction.get("split_velocity", Vector2i.ZERO) != Vector2i.ZERO and split_capacity > 0:
				var child := ProjectileState.new(0, projectile.owner_id, projectile.team_id, projectile.source_wire_id, projectile.element_wire_id,
					Vector2i(projectile.position_x, projectile.position_y), interaction["split_velocity"], projectile.radius,
					int(interaction.get("split_damage", 0)), projectile.lifetime_ticks, projectile.hit_control_state,
					projectile.hit_control_duration_ms, projectile.hit_control_speed, projectile.hit_control_slow_ratio)
				child.remaining_distance = projectile.remaining_distance
				child.range_subunit = projectile.range_subunit
				child.source_cast_id = projectile.source_cast_id if projectile.source_cast_id > 0 else projectile.entity_id
				child.reaction_strength = projectile.reaction_strength
				# Quantity1 stays with the parent; a paid damage-only child must not
				# mint a second unit or receive a separate chemistry cast identity.
				child.material_strength = projectile.material_strength / 2
				projectile.material_strength -= child.material_strength
				child.chemistry_interaction_mask = projectile.chemistry_interaction_mask
				child.grazed_entity_ids = projectile.grazed_entity_ids.duplicate()
				events.append({"type": "chemistry_projectile_split", "projectile": child})
				available_chemistry_slots -= 1
				owner_material_slots[projectile.owner_id] = split_capacity - 1

		var hit_entity_id: int = 0
		var earliest_target: PlayerState = null
		var earliest_fraction := 2.0
		for target: PlayerState in ordered_players:
			if target.entity_id == projectile.owner_id or target.team_id == projectile.team_id or target.health <= 0 or target.spawn_protection_ticks > 0:
				continue
			var hit_radius: int = target.radius + projectile.radius
			var fraction := ContinuousContact.circle_toi(travel_start, Vector2i(projectile.position_x, projectile.position_y), Vector2i(target.position_x, target.position_y), hit_radius)
			if fraction >= 0.0:
				if MovementSystem.is_combat_intangible(target, config) or MovementSystem.avoids_ordinary_projectiles(target):
					target.last_event = "evaded_projectile"
					continue
				if fraction < earliest_fraction and (wall_contact.is_empty() or fraction < 1.0):
					earliest_target = target
					earliest_fraction = fraction
		if earliest_target != null:
			var target: PlayerState = earliest_target
			var swept_end := Vector2i(projectile.position_x, projectile.position_y)
			var center := ContinuousContact.point_at(travel_start, swept_end, earliest_fraction)
			projectile.position_x = center.x
			projectile.position_y = center.y
			terminal_point = ContinuousContact.circle_contact(travel_start, swept_end, earliest_fraction, Vector2i(target.position_x, target.position_y), target.radius)
			var health_before := target.health
			PlayerResourcesSystem.damage(target, projectile.damage, config)
			SpellStatusPolicy.apply_hit(target,projectile.source_wire_id,projectile.source_cast_id,projectile.owner_id,projectile.team_id,health_before-target.health,config,SimCommand._normalized_direction(projectile.velocity_x,projectile.velocity_y))
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
				"damage": health_before - target.health,
				"contact_position": terminal_point,
			})
			if target.actor_kind == PlayerState.ActorKind.CHAMPION and target.health == 0:
				events.append({
					"type": "champion_defeated",
					"projectile_id": projectile.entity_id,
					"owner_id": projectile.owner_id,
					"target_id": target.entity_id,
				})

		_resolve_edgeweave(projectile, ordered_players, hit_entity_id, config, events)
		if hit_entity_id != 0:
			_explode_projectile(projectile, ordered_players, config, world, reactions, current_tick, events, hit_entity_id, terminal_point)
			_emit_terminal(projectile, events, "actor", terminal_point)
			continue
		if not wall_contact.is_empty():
			events.append({"type": "projectile_impact", "projectile_id": projectile.entity_id, "wall_id": result.wall_id, "contact_position": terminal_point})
			_explode_projectile(projectile, ordered_players, config, world, reactions, current_tick, events, 0, terminal_point)
			_emit_terminal(projectile, events, "obstacle", terminal_point)
			continue
		projectile.lifetime_ticks = maxi(0, projectile.lifetime_ticks - 1)
		if projectile.lifetime_ticks == 0 or projectile.remaining_distance == 0:
			events.append({"type": "projectile_expired", "projectile_id": projectile.entity_id})
			_explode_projectile(projectile, ordered_players, config, world, reactions, current_tick, events)
			_emit_terminal(projectile, events, "range")
			continue
		survivors.append(projectile)
	return survivors


static func _projectile_reaction_candidates(reactions: Array[ElementReactionState], tick: int) -> Array[ElementReactionState]:
	# Only this synchronous projectile batch owns the list. Wires/tick are fixed;
	# active reactions may decay from earlier hits, so the query still rechecks
	# active(). Preserve references/order/duplicates and all original Heavy paths.
	var candidates: Array[ElementReactionState] = []
	for reaction: ElementReactionState in reactions:
		if reaction.active(tick) and reaction.recipe_wire_id in [301,305,306,307,320,325,329,335]:
			candidates.append(reaction)
	return candidates


static func _rewind_heavy_cover_contact(projectile: ProjectileState, config: SimConfig, world: CollisionWorld, reactions: Array[ElementReactionState], tick: int) -> void:
	if int(CombatTuning.cast_definition(projectile.source_wire_id).get("blast_radius", 0)) <= 0:
		return
	var start := Vector2i(projectile.previous_x, projectile.previous_y)
	var end := Vector2i(projectile.position_x, projectile.position_y)
	if blast_clear_line(start, end, world, reactions, tick, config) or not blast_clear_line(start, start, world, reactions, tick, config):
		return
	# Chemistry detects swept contact before the terminal pass. Its sampled end
	# may be inside surviving cover: rewind only this new shell to the last clear
	# point so exposed-side splash works without leaking through the shield.
	# Integer bisection is bounded and deterministic; a projectile born inside
	# cover is never teleported outside. Destroyed cover no longer blocks it.
	var low := 0
	var high := 1024
	for _iteration: int in range(10):
		var middle := (low + high) / 2
		var point := start + Vector2i((end.x - start.x) * middle / 1024, (end.y - start.y) * middle / 1024)
		if blast_clear_line(start, point, world, reactions, tick, config):
			low = middle
		else:
			high = middle
	projectile.position_x = start.x + (end.x - start.x) * low / 1024
	projectile.position_y = start.y + (end.y - start.y) * low / 1024


static func _explode_projectile(projectile: ProjectileState, ordered_players: Array[PlayerState], config: SimConfig, world: CollisionWorld, reactions: Array[ElementReactionState], tick: int, events: Array[Dictionary], excluded_id: int = 0, impact_point: Variant = null) -> void:
	var definition := CombatTuning.cast_definition(projectile.source_wire_id)
	var radius := int(definition.get("blast_radius", 0))
	# Optical damage splits cannot manufacture full-strength secondary blasts.
	var damage := mini(projectile.damage, int(definition.get("blast_damage", 0)))
	if radius <= 0 or damage <= 0:
		return
	var origin: Vector2i = impact_point if impact_point is Vector2i else Vector2i(projectile.position_x, projectile.position_y)
	for target: PlayerState in ordered_players:
		if target.entity_id in [excluded_id, projectile.owner_id] or target.team_id == projectile.team_id or target.health <= 0 or target.spawn_protection_ticks > 0 or MovementSystem.is_combat_intangible(target, config) or MovementSystem.avoids_ground_effects(target):
			continue
		var point := Vector2i(target.position_x, target.position_y)
		var reach := radius + target.radius
		if (point - origin).length_squared() > reach * reach or not blast_clear_line(origin, point, world, reactions, tick, config):
			continue
		# This terminal blast occupies the ground layer. Low profile is exposed;
		# height clearance and paid dodge protection are independent escapes.
		var health_before := target.health
		PlayerResourcesSystem.damage(target, damage, config)
		events.append({"type":"projectile_hit", "projectile_id":projectile.entity_id,
			"source_wire_id":projectile.source_wire_id, "owner_id":projectile.owner_id,
			"target_id":target.entity_id, "damage":health_before - target.health})
		if target.actor_kind == PlayerState.ActorKind.CHAMPION and target.health == 0:
			events.append({"type":"champion_defeated", "projectile_id":projectile.entity_id,
				"owner_id":projectile.owner_id, "target_id":target.entity_id})


static func blast_clear_line(origin: Vector2i, point: Vector2i, world: CollisionWorld, reactions: Array[ElementReactionState], tick: int, config: SimConfig) -> bool:
	if not ElementChemistrySystem.clear_line(origin, point, world):
		return false
	for cover: ElementReactionState in reactions:
		if cover.health > 0 and cover.active(tick) and ElementChemistrySystem._segment_enters(cover, origin, point, tick, config):
			return false
	return true


static func _emit_terminal(projectile: ProjectileState, events: Array[Dictionary], reason: String, impact_point: Variant = null) -> void:
	events.append({
		"type": "projectile_terminal", "projectile_id": projectile.entity_id,
		"source_cast_id": projectile.source_cast_id if projectile.source_cast_id > 0 else projectile.entity_id,
		"source_wire_id": projectile.source_wire_id, "owner_id": projectile.owner_id, "team_id": projectile.team_id,
		"element_wire_id": projectile.element_wire_id, "position": impact_point if impact_point is Vector2i else Vector2i(projectile.position_x, projectile.position_y),
		"direction": SimCommand._normalized_direction(projectile.velocity_x, projectile.velocity_y),
		"strength": projectile.material_strength, "reaction_strength": projectile.reaction_strength, "reason": reason,
		"initial_strength": projectile.initial_strength if projectile.initial_strength > 0 else projectile.reaction_strength,
		"remaining_strength": projectile.remaining_strength if projectile.initial_strength > 0 else projectile.reaction_strength,
	})


static func _begin_cast(state: PlayerState, wire_id: int, startup_ms: int, config: SimConfig, command: SimCommand = null) -> void:
	# Caller samples perks before payment. This fixed timer cannot be retimed by moving.
	state.pending_cast_wire_id = wire_id
	state.pending_cast_ticks = config.milliseconds_to_ticks(startup_ms)
	state.pending_cast_aim_x = state.aim_x
	state.pending_cast_aim_y = state.aim_y
	state.pending_cast_target_x = command.aim_target_x if command != null else -1
	state.pending_cast_target_y = command.aim_target_y if command != null else -1
	state.last_event = "cast_start_%d" % wire_id


static func _release_cast(
	state: PlayerState,
	config: SimConfig,
	projectile_id: int,
	field_id: int,
	world: CollisionWorld,
	events: Array[Dictionary],
) -> Variant:
	var wire_id: int = state.pending_cast_wire_id
	var definition := CombatTuning.cast_definition(wire_id)
	if definition.is_empty():
		state.pending_cast_wire_id = 0
		state.pending_cast_ticks = 0
		return null
	var release_timing := Perks.spell_timing(state, definition, config, SpellStatusPolicy.startup_ratio(state))
	if not state.set_spell_cooldown(wire_id, int(release_timing.cooldown_ticks)):
		state.pending_cast_wire_id = 0
		state.pending_cast_ticks = 0
		return null
	state.cast_recovery_ticks = config.milliseconds_to_ticks(int(definition["recovery_ms"]))
	var shape := String(definition.get("shape", ""))
	if shape in ["beam", "spray"]:
		_queue_instant_cast(state, wire_id, shape, events, projectile_id)
		return {"instant_cast_id": projectile_id} if shape == "spray" else null
	if shape == "field":
		return _release_field(state, wire_id, field_id, definition, config, world, events)
	return _release_projectiles(state, wire_id, projectile_id, definition, config, world, events)


static func _release_projectiles(
	state: PlayerState,
	wire_id: int,
	first_projectile_id: int,
	definition: Dictionary,
	config: SimConfig,
	world: CollisionWorld,
	events: Array[Dictionary],
) -> Array[ProjectileState]:
	var speed := int(definition["speed"])
	var radius := int(definition["radius"])
	var base_direction := Vector2i(state.pending_cast_aim_x, state.pending_cast_aim_y)
	var locked_distance := -1
	if state.pending_cast_target_x >= 0 and state.pending_cast_target_y >= 0:
		var locked_delta := Vector2i(state.pending_cast_target_x - state.position_x, state.pending_cast_target_y - state.position_y)
		locked_distance = SimCommand._integer_square_root(locked_delta.x * locked_delta.x + locked_delta.y * locked_delta.y)
		if locked_delta != Vector2i.ZERO:
			base_direction = SimCommand._normalized_direction(locked_delta.x, locked_delta.y)
	var rotations: Array = definition.get("projectile_rotations", [Vector2i(1000, 0)])
	var angles: Array = definition.get("projectile_angles_degrees", [0])
	@warning_ignore("integer_division")
	var spawn_distance: int = MovementTuning.PLAYER_RADIUS + radius + CombatTuning.PROJECTILE_SPAWN_CLEARANCE
	if locked_distance >= 0:
		spawn_distance = mini(spawn_distance, locked_distance)
	if String(definition.get("family","")) == "mantle": spawn_distance = 0
	var directions: Array[Vector2i] = []
	var spawn_positions: Array[Vector2i] = []
	for rotation_value: Variant in rotations:
		var direction := _rotate_fixed_direction(base_direction, rotation_value as Vector2i)
		@warning_ignore("integer_division")
		var spawn_position := Vector2i(
			state.position_x + direction.x * spawn_distance / 1000,
			state.position_y + direction.y * spawn_distance / 1000,
		)
		directions.append(direction)
		spawn_positions.append(spawn_position)
	state.pending_cast_wire_id = 0
	state.pending_cast_ticks = 0
	var release_origin := Vector2i(state.position_x, state.position_y)
	for spawn_position: Vector2i in spawn_positions:
		# A clear muzzle endpoint can be beyond a thin wall inside the spawn
		# clearance. Require line of sight before creating the projectile there.
		# This is a center-line check, not a full-radius sweep from inside the
		# caster: Heavy is wider than actor clearance and must still fire away
		# from an adjacent wall. Spawn occupancy and subsequent flight keep their
		# existing full-radius collision and tangency semantics.
		var clearance := MovementTuning.PLAYER_RADIUS if String(definition.get("family","")) == "mantle" else radius
		if not world.can_occupy(spawn_position, clearance) or not ContinuousContact.wall_contact(release_origin, spawn_position, 0, world).is_empty():
			events.append({"type": "cast_blocked", "entity_id": state.entity_id, "wire_id": wire_id})
			state.last_event = "cast_blocked_%d" % wire_id
			return []
	var projectiles: Array[ProjectileState] = []
	for lane_index: int in range(directions.size()):
		var direction := directions[lane_index]
		@warning_ignore("integer_division")
		var velocity := Vector2i(direction.x * speed / 1000, direction.y * speed / 1000)
		var projectile_id := first_projectile_id + lane_index
		var projectile := ProjectileState.new(
			projectile_id,
			state.entity_id,
			state.team_id,
			wire_id,
			int(definition["element_wire_id"]),
			spawn_positions[lane_index],
			velocity,
			radius,
			int(definition["damage"]),
			config.milliseconds_to_ticks(int(definition["lifetime_ms"])),
			int(definition["hit_control_state"]),
			int(definition["hit_control_duration_ms"]),
			int(definition["hit_control_speed"]),
			int(definition["hit_control_slow_ratio"]),
			int(definition.get("remaining_bounces",0)),
		)
		projectile.source_cast_id = first_projectile_id
		projectile.reaction_strength = int(definition["reaction_strength"])
		projectile.material_strength = 1000 / maxi(1, directions.size())
		projectile.remaining_distance = maxi(0, locked_distance - spawn_distance) if locked_distance >= 0 else -1
		# A faster flight retains its authored muzzle-to-terminal distance. The
		# existing replicated budget also keeps a nearer cursor endpoint binding.
		if definition.has("range"):
			projectile.remaining_distance = mini(projectile.remaining_distance, int(definition.range)) if projectile.remaining_distance >= 0 else int(definition.range)
		HexExpandedDelivery.initialize(projectile,config)
		projectiles.append(projectile)
		events.append({
			"type": "projectile_spawned",
			"projectile_id": projectile_id,
			"owner_id": state.entity_id,
			"wire_id": wire_id,
			"lane_index": lane_index,
			"lane_angle_degrees": int(angles[lane_index]) if lane_index < angles.size() else 0,
			"lane_count": directions.size(),
		})
	state.last_event = "cast_release_%d" % wire_id
	return projectiles


static func _rotate_fixed_direction(direction: Vector2i, rotation: Vector2i) -> Vector2i:
	@warning_ignore("integer_division")
	var rotated := Vector2i(
		(direction.x * rotation.x - direction.y * rotation.y) / SimConfig.FIXED_SCALE,
		(direction.x * rotation.y + direction.y * rotation.x) / SimConfig.FIXED_SCALE,
	)
	return SimCommand._normalized_direction(rotated.x, rotated.y)


static func _release_field(
	state: PlayerState,
	wire_id: int,
	field_id: int,
	definition: Dictionary,
	config: SimConfig,
	world: CollisionWorld,
	events: Array[Dictionary],
) -> FieldState:
	var direction := Vector2i(state.pending_cast_aim_x, state.pending_cast_aim_y)
	var maximum_range := int(definition["range"])
	var field_radius := int(definition["radius"])
	var placement := _field_placement(state, direction, maximum_range, field_radius, world)
	state.pending_cast_wire_id = 0
	state.pending_cast_ticks = 0
	if placement == Vector2i.ZERO:
		events.append({"type": "cast_blocked", "entity_id": state.entity_id, "wire_id": wire_id})
		state.last_event = "cast_blocked_%d" % wire_id
		return null
	var field := FieldState.new(
		field_id,
		state.entity_id,
		state.team_id,
		wire_id,
		int(definition["element_wire_id"]),
		placement,
		field_radius,
		config.milliseconds_to_ticks(int(definition["lifetime_ms"])),
		int(definition["hit_control_state"]),
		int(definition["hit_control_duration_ms"]),
		int(definition["hit_control_slow_ratio"]),
	)
	events.append({
		"type": "field_spawned",
		"field_id": field_id,
		"owner_id": state.entity_id,
		"source_wire_id": wire_id,
		"position_x": placement.x,
		"position_y": placement.y,
		"radius": field.radius,
	})
	state.last_event = "cast_release_%d" % wire_id
	return field


static func _field_placement(state: PlayerState, direction: Vector2i, maximum_range: int, field_radius: int, world: CollisionWorld) -> Vector2i:
	const TRACE_STEP: int = 8_000
	var minimum_range := MovementTuning.PLAYER_RADIUS + field_radius
	var distance := maximum_range
	while distance >= minimum_range:
		@warning_ignore("integer_division")
		var candidate := Vector2i(
			state.position_x + direction.x * distance / SimConfig.FIXED_SCALE,
			state.position_y + direction.y * distance / SimConfig.FIXED_SCALE,
		)
		if world.can_occupy(candidate, field_radius):
			return candidate
		distance -= TRACE_STEP
	return Vector2i.ZERO


static func advance_fields(
	fields: Array[FieldState],
	players: Array[PlayerState],
	config: SimConfig,
	events: Array[Dictionary],
) -> Array[FieldState]:
	var survivors: Array[FieldState] = []
	var ordered_players: Array[PlayerState] = players.duplicate()
	ordered_players.sort_custom(func(left: PlayerState, right: PlayerState) -> bool: return left.entity_id < right.entity_id)
	for field: FieldState in fields:
		for target: PlayerState in ordered_players:
			if (
				target.entity_id == field.owner_id
				or target.team_id == field.team_id
				or target.health <= 0
				or target.spawn_protection_ticks > 0
				or MovementSystem.is_combat_intangible(target, config)
				or field.has_affected(target.entity_id)
				or MovementSystem.avoids_ground_effects(target)
			):
				continue
			var offset := Vector2i(target.position_x - field.position_x, target.position_y - field.position_y)
			var contact_radius := target.radius + field.radius
			if offset.length_squared() > contact_radius * contact_radius:
				continue
			MovementSystem.apply_control_state(
				target,
				field.hit_control_state,
				field.hit_control_duration_ms,
				Vector2i.ZERO,
				0,
				config,
				field.hit_control_slow_ratio,
			)
			field.record_affected(target.entity_id)
			events.append({
				"type": "field_triggered",
				"field_id": field.entity_id,
				"owner_id": field.owner_id,
				"source_wire_id": field.source_wire_id,
				"target_id": target.entity_id,
			})
		field.lifetime_ticks = maxi(0, field.lifetime_ticks - 1)
		if field.lifetime_ticks == 0:
			events.append({"type": "field_expired", "field_id": field.entity_id})
			continue
		survivors.append(field)
	return survivors


static func _queue_instant_cast(
	state: PlayerState,
	wire_id: int,
	shape: String,
	events: Array[Dictionary],
	cast_id: int = 0,
) -> void:
	var release_direction := Vector2i(state.pending_cast_aim_x, state.pending_cast_aim_y)
	if shape == "spray" and state.pending_cast_target_x >= 0 and state.pending_cast_target_y >= 0:
		var delta := Vector2i(state.pending_cast_target_x - state.position_x, state.pending_cast_target_y - state.position_y)
		if delta != Vector2i.ZERO:
			release_direction = SimCommand._normalized_direction(delta.x, delta.y)
	events.append({
		"type": "%s_requested" % shape,
		"owner_id": state.entity_id,
		"source_wire_id": wire_id,
		"source_cast_id": cast_id,
		"target_x": state.pending_cast_target_x,
		"target_y": state.pending_cast_target_y,
		"origin_x": state.position_x,
		"origin_y": state.position_y,
		"aim_x": release_direction.x,
		"aim_y": release_direction.y,
	})
	state.pending_cast_wire_id = 0
	state.pending_cast_ticks = 0
	state.last_event = "cast_release_%d" % wire_id


static func spray_request_definition(request: Dictionary) -> Dictionary:
	var definition := CombatTuning.cast_definition(int(request.source_wire_id)).duplicate()
	var target := Vector2i(int(request.get("target_x", -1)), int(request.get("target_y", -1)))
	if target.x >= 0 and target.y >= 0:
		var delta := target - Vector2i(int(request.origin_x), int(request.origin_y))
		var distance_squared := delta.length_squared()
		var distance := SimCommand._integer_square_root(distance_squared)
		if distance * distance < distance_squared:
			distance += 1 # Inclusive integer envelope contains an oblique target.
		definition["range"] = mini(int(definition.range), distance)
	return definition


static func resolve_instant_casts(
	players: Array[PlayerState],
	config: SimConfig,
	world: CollisionWorld,
	events: Array[Dictionary],
	reactions: Array = [],
	current_tick: int = 0,
) -> void:
	var resolved_events: Array[Dictionary] = []
	for event: Dictionary in events:
		var request_type := String(event.get("type", ""))
		if request_type not in ["beam_requested", "spray_requested"]:
			resolved_events.append(event)
			continue
		var owner: PlayerState = null
		var owner_id := int(event.get("owner_id", 0))
		for candidate: PlayerState in players:
			if candidate.entity_id == owner_id:
				owner = candidate
				break
		if owner == null:
			continue
		var wire_id := int(event.get("source_wire_id", 0))
		var definition := CombatTuning.cast_definition(wire_id)
		var shape := request_type.trim_suffix("_requested")
		if shape == "spray":
			definition = spray_request_definition(event)
		if String(definition.get("shape", "")) != shape:
			continue
		var origin := Vector2i(int(event.get("origin_x", 0)), int(event.get("origin_y", 0)))
		var direction := Vector2i(int(event.get("aim_x", 1000)), int(event.get("aim_y", 0)))
		var endpoint := _beam_clear_endpoint(
			origin,
			direction,
			int(definition["range"]),
			int(definition["radius"]),
			world,
		)
		if endpoint == origin:
			resolved_events.append({"type": "cast_blocked", "entity_id": owner.entity_id, "wire_id": wire_id})
			owner.last_event = "cast_blocked_%d" % wire_id
			continue

		if shape == "spray":
			_resolve_spray(owner, wire_id, definition, origin, direction, endpoint, players, config, world, resolved_events, reactions, current_tick)
			if int(event.get("source_cast_id", 0)) > 0:
				resolved_events.append({"type": "projectile_terminal", "spray_reservation": true,
					"source_cast_id": int(event.source_cast_id), "source_wire_id": wire_id,
					"owner_id": owner.entity_id, "team_id": owner.team_id,
					"element_wire_id": int(definition.element_wire_id), "position": endpoint,
					"direction": direction, "strength": 1000, "reaction_strength": int(definition.reaction_strength)})
			continue
		if not reactions.is_empty() and _resolve_chemistry_beam(owner, wire_id, definition, origin, endpoint, players, config, world, resolved_events, reactions, current_tick):
			continue
		var target: PlayerState = _first_beam_target(owner, origin, endpoint, int(definition["radius"]), players, config)
		var health_before := target.health if target != null else 0
		if target != null:
			endpoint = Vector2i(target.position_x, target.position_y)
			PlayerResourcesSystem.damage(target, int(definition["damage"]), config)
			if target.health > 0 and int(definition["hit_control_duration_ms"]) > 0:
				MovementSystem.apply_control_state(
					target,
					int(definition["hit_control_state"]),
					int(definition["hit_control_duration_ms"]),
					direction,
					int(definition["hit_control_speed"]),
					config,
					int(definition["hit_control_slow_ratio"]),
				)
		resolved_events.append({
			"type": "beam_fired",
			"owner_id": owner.entity_id,
			"source_wire_id": wire_id,
			"target_id": target.entity_id if target != null else 0,
			"end_x": endpoint.x,
			"end_y": endpoint.y,
			"damage": health_before - target.health if target != null else 0,
		})
		if target != null and target.actor_kind == PlayerState.ActorKind.CHAMPION and target.health == 0:
			resolved_events.append({
				"type": "champion_defeated",
				"projectile_id": 0,
				"owner_id": owner.entity_id,
				"target_id": target.entity_id,
			})
	events.clear()
	events.append_array(resolved_events)


static func _resolve_spray(
	owner: PlayerState,
	wire_id: int,
	definition: Dictionary,
	origin: Vector2i,
	direction: Vector2i,
	endpoint: Vector2i,
	players: Array[PlayerState],
	config: SimConfig,
	world: CollisionWorld,
	resolved_events: Array[Dictionary],
	reactions: Array = [],
	current_tick: int = 0,
) -> void:
	var hit_events: Array[Dictionary] = []
	var hit_count: int = 0
	var ordered_players: Array[PlayerState] = players.duplicate()
	ordered_players.sort_custom(func(left: PlayerState, right: PlayerState) -> bool: return left.entity_id < right.entity_id)
	var maximum_range := int(definition["range"])
	var maximum_range_squared := maximum_range * maximum_range
	var cone_threshold := int(definition["cone_cosine_squared_per_million"])
	for target: PlayerState in ordered_players:
		if target.entity_id == owner.entity_id or target.team_id == owner.team_id or target.health <= 0 or target.spawn_protection_ticks > 0:
			continue
		var offset := Vector2i(target.position_x, target.position_y) - origin
		var distance_squared := offset.length_squared()
		if distance_squared <= 0 or distance_squared > maximum_range_squared:
			continue
		var projection := offset.x * direction.x + offset.y * direction.y
		if projection <= 0 or projection * projection < distance_squared * cone_threshold:
			continue
		var distance := SimCommand._integer_square_root(distance_squared)
		var target_direction := SimCommand._normalized_direction(offset.x, offset.y)
		var clear_endpoint := spray_clear_endpoint(origin, target_direction, distance, int(definition["radius"]), world)
		var remaining := Vector2i(target.position_x, target.position_y) - clear_endpoint
		var hit_radius: int = target.radius + int(definition["radius"])
		if remaining.length_squared() > hit_radius * hit_radius:
			continue
		if _spray_cover_intercepts(origin, Vector2i(target.position_x,target.position_y), int(definition["damage"]), reactions, current_tick, config):
			continue
		if MovementSystem.is_combat_intangible(target, config) or MovementSystem.avoids_ordinary_projectiles(target):
			target.last_event = "evaded_spray"
			continue
		var health_before := target.health
		PlayerResourcesSystem.damage(target, int(definition["damage"]), config)
		SpellStatusPolicy.apply_hit(target,wire_id,int(definition.get("source_cast_id",0)),owner.entity_id,owner.team_id,health_before-target.health,config,target_direction)
		if target.health > 0 and int(definition["hit_control_duration_ms"]) > 0:
			MovementSystem.apply_control_state(
				target,
				int(definition["hit_control_state"]),
				int(definition["hit_control_duration_ms"]),
				target_direction,
				int(definition["hit_control_speed"]),
				config,
				int(definition["hit_control_slow_ratio"]),
			)
		hit_events.append({
			"type": "spray_hit",
			"owner_id": owner.entity_id,
			"source_wire_id": wire_id,
			"target_id": target.entity_id,
			"damage": health_before - target.health,
		})
		hit_count += 1
		if target.actor_kind == PlayerState.ActorKind.CHAMPION and target.health == 0:
			hit_events.append({
				"type": "champion_defeated",
				"projectile_id": 0,
				"owner_id": owner.entity_id,
				"target_id": target.entity_id,
			})
	resolved_events.append({
		"type": "spray_fired",
		"owner_id": owner.entity_id,
		"source_wire_id": wire_id,
		"range": maximum_range,
		"end_x": endpoint.x,
		"end_y": endpoint.y,
		"hit_count": hit_count,
	})
	resolved_events.append_array(hit_events)


static func _resolve_chemistry_beam(owner: PlayerState, wire_id: int, definition: Dictionary, origin: Vector2i, endpoint: Vector2i, players: Array[PlayerState], config: SimConfig, world: CollisionWorld, events: Array[Dictionary], reactions: Array, tick: int) -> bool:
	var original_target := _first_beam_target(owner,origin,endpoint,int(definition["radius"]),players,config)
	var first_point := Vector2i(original_target.position_x,original_target.position_y) if original_target != null else Vector2i(-1,-1)
	var optical := ElementChemistrySystem.ray_interaction(origin,endpoint,int(definition["element_wire_id"]),int(definition["damage"]),reactions,tick,0,first_point)
	if not bool(optical["transformed"]):
		return false
	var entry: Vector2i = optical["entry_point"]
	if not bool(optical["blocked"]):
		events.append({"type":"beam_fired","owner_id":owner.entity_id,"source_wire_id":wire_id,"target_id":0,"origin_x":origin.x,"origin_y":origin.y,"end_x":entry.x,"end_y":entry.y,"damage":0})
	for ray: Dictionary in optical["rays"]:
		var ray_origin: Vector2i = ray["origin"]
		var requested_end: Vector2i = ray["end"]
		var ray_delta := requested_end-ray_origin
		var direction := SimCommand._normalized_direction(ray_delta.x,ray_delta.y)
		var distance := SimCommand._integer_square_root(ray_delta.length_squared())
		var ray_end := _beam_clear_endpoint(ray_origin,direction,distance,int(definition["radius"]),world)
		var target := _first_beam_target(owner,ray_origin,ray_end,int(definition["radius"]),players,config)
		var actual_damage := 0
		if target != null:
			ray_end = Vector2i(target.position_x,target.position_y)
			var health_before := target.health
			if PlayerResourcesSystem.damage(target,int(ray["damage"]),config):
				actual_damage = health_before - target.health
			if actual_damage > 0 and target.health > 0 and int(definition["hit_control_duration_ms"]) > 0:
				MovementSystem.apply_control_state(target,int(definition["hit_control_state"]),int(definition["hit_control_duration_ms"]),direction,int(definition["hit_control_speed"]),config,int(definition["hit_control_slow_ratio"]))
		events.append({"type":"beam_fired","owner_id":owner.entity_id,"source_wire_id":wire_id,"target_id":target.entity_id if target != null else 0,"origin_x":ray_origin.x,"origin_y":ray_origin.y,"end_x":ray_end.x,"end_y":ray_end.y,"damage":actual_damage})
		if target != null and target.health == 0 and target.actor_kind == PlayerState.ActorKind.CHAMPION:
			events.append({"type":"champion_defeated","projectile_id":0,"owner_id":owner.entity_id,"target_id":target.entity_id})
	return true


static func _spray_cover_intercepts(origin: Vector2i,endpoint: Vector2i,damage: int,reactions: Array,tick: int,config: SimConfig) -> bool:
	for result: ElementReactionState in reactions:
		if not result.active(tick) or result.health <= 0 or result.recipe_wire_id not in [301,305,306,307,329]:
			continue
		if not ElementChemistrySystem._segment_enters(result,origin,endpoint,tick,config):
			continue
		result.health = maxi(0,result.health-damage)
		if result.health == 0:
			result.decay_tick = mini(result.decay_tick,tick)
		return true
	return false


# Spray's physical radius and shot-cover policy are shared by actor rays and
# cached presentation spokes. One analytic query replaces distance sampling;
# the legacy beam path below deliberately retains its established behavior.
static func spray_clear_endpoint(origin: Vector2i, direction: Vector2i, maximum_range: int, radius: int, world: CollisionWorld) -> Vector2i:
	var endpoint := origin + ElementChemistrySystem.scaled(direction, maximum_range)
	var wall := ContinuousContact.wall_contact(origin, endpoint, radius, world)
	return endpoint if wall.is_empty() else Vector2i(wall.center)


static func _beam_clear_endpoint(
	origin: Vector2i,
	direction: Vector2i,
	maximum_range: int,
	radius: int,
	world: CollisionWorld,
) -> Vector2i:
	const TRACE_STEP: int = 2_000
	var endpoint := origin
	var distance: int = TRACE_STEP
	while distance <= maximum_range + TRACE_STEP:
		var bounded_distance := mini(distance, maximum_range)
		@warning_ignore("integer_division")
		var candidate := Vector2i(
			origin.x + direction.x * bounded_distance / SimConfig.FIXED_SCALE,
			origin.y + direction.y * bounded_distance / SimConfig.FIXED_SCALE,
		)
		if not world.can_occupy(candidate, radius):
			break
		endpoint = candidate
		if bounded_distance == maximum_range:
			break
		distance += TRACE_STEP
	return endpoint


static func _first_beam_target(
	owner: PlayerState,
	origin: Vector2i,
	endpoint: Vector2i,
	beam_radius: int,
	players: Array[PlayerState],
	config: SimConfig,
) -> PlayerState:
	var delta := endpoint - origin
	var length_squared: int = delta.length_squared()
	var best: PlayerState = null
	var best_projection: int = length_squared + 1
	var ordered_players: Array[PlayerState] = players.duplicate()
	ordered_players.sort_custom(func(left: PlayerState, right: PlayerState) -> bool: return left.entity_id < right.entity_id)
	for target: PlayerState in ordered_players:
		if target.entity_id == owner.entity_id or target.team_id == owner.team_id or target.health <= 0 or target.spawn_protection_ticks > 0:
			continue
		var offset := Vector2i(target.position_x, target.position_y) - origin
		var projection: int = offset.x * delta.x + offset.y * delta.y
		if projection <= 0 or projection > length_squared or projection >= best_projection:
			continue
		@warning_ignore("integer_division")
		var closest := Vector2i(
			origin.x + delta.x * projection / length_squared,
			origin.y + delta.y * projection / length_squared,
		)
		var separation := Vector2i(target.position_x, target.position_y) - closest
		var hit_radius: int = target.radius + beam_radius
		if separation.length_squared() > hit_radius * hit_radius:
			continue
		if MovementSystem.is_combat_intangible(target, config) or MovementSystem.avoids_ordinary_projectiles(target):
			target.last_event = "evaded_beam"
			continue
		best = target
		best_projection = projection
	return best


static func _reflect_projectile(projectile: ProjectileState, wall_normal: Vector2i) -> void:
	if wall_normal.x != 0:
		projectile.velocity_x = -projectile.velocity_x
		projectile.remainder_x = -projectile.remainder_x
	if wall_normal.y != 0:
		projectile.velocity_y = -projectile.velocity_y
		projectile.remainder_y = -projectile.remainder_y


static func _resolve_edgeweave(
	projectile: ProjectileState,
	players: Array[PlayerState],
	hit_entity_id: int,
	config: SimConfig,
	events: Array[Dictionary],
) -> void:
	if CombatTuning.projectile_definition(projectile.source_wire_id).is_empty():
		return
	for target: PlayerState in players:
		if (
			target.entity_id == projectile.owner_id
			or target.entity_id == hit_entity_id
			or target.team_id == projectile.team_id
			or target.health <= 0
			or target.edgeweave_cooldown_ticks > 0
			or MovementSystem.is_combat_intangible(target, config)
			or target.stamina >= target.stamina_maximum
			or projectile.has_grazed(target.entity_id)
			or target.velocity_x * target.velocity_x + target.velocity_y * target.velocity_y < CombatTuning.EDGEWEAVE_MINIMUM_SPEED * CombatTuning.EDGEWEAVE_MINIMUM_SPEED
		):
			continue
		var hit_radius: int = target.radius + projectile.radius
		if _segment_circle_hit(projectile, target, hit_radius):
			continue
		if not _segment_circle_hit(projectile, target, hit_radius + CombatTuning.EDGEWEAVE_MARGIN):
			continue
		var reward: int = mini(CombatTuning.EDGEWEAVE_REWARD, target.stamina_maximum - target.stamina)
		target.stamina += reward
		target.stamina_remainder = 0
		target.stamina_recovery_delay_ticks = config.milliseconds_to_ticks(MovementTuning.STAMINA_RECOVERY_DELAY_MS)
		target.edgeweave_cooldown_ticks = config.milliseconds_to_ticks(CombatTuning.EDGEWEAVE_COOLDOWN_MS)
		target.last_event = "edgeweave"
		projectile.record_graze(target.entity_id)
		events.append({
			"type": "edgeweave",
			"entity_id": target.entity_id,
			"projectile_id": projectile.entity_id,
			"stamina": reward,
		})


static func _segment_circle_hit(projectile: ProjectileState, target: PlayerState, radius: int) -> bool:
	# The clamped integer closest point stays between the current endpoints.
	# Strict separation preserves tangency; negative radii keep the old square.
	if radius >= 0 and (
		target.position_x < mini(projectile.previous_x, projectile.position_x) - radius
		or target.position_x > maxi(projectile.previous_x, projectile.position_x) + radius
		or target.position_y < mini(projectile.previous_y, projectile.position_y) - radius
		or target.position_y > maxi(projectile.previous_y, projectile.position_y) + radius
	):
		return false
	var delta_x: int = projectile.position_x - projectile.previous_x
	var delta_y: int = projectile.position_y - projectile.previous_y
	var offset_x: int = target.position_x - projectile.previous_x
	var offset_y: int = target.position_y - projectile.previous_y
	var length_squared: int = delta_x * delta_x + delta_y * delta_y
	if length_squared == 0:
		return offset_x * offset_x + offset_y * offset_y <= radius * radius
	var projection: int = clampi(offset_x * delta_x + offset_y * delta_y, 0, length_squared)
	@warning_ignore("integer_division")
	var closest_x: int = projectile.previous_x + delta_x * projection / length_squared
	@warning_ignore("integer_division")
	var closest_y: int = projectile.previous_y + delta_y * projection / length_squared
	var distance_x: int = target.position_x - closest_x
	var distance_y: int = target.position_y - closest_y
	return distance_x * distance_x + distance_y * distance_y <= radius * radius
