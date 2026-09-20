extends RefCounted

# TEST ONLY: source-derived SimWorld.step orchestration with an observed
# projectile loop. The runner checks exact state/events after EVERY tick.
const DrillCombat = preload("res://tests/scenarios/runtime_drill_combat.gd")
const Targets = preload("res://src/sim/combat/training_target_system.gd")
const STAGES := ["commands", "movement_context", "resources", "movement", "capacity", "casts", "instant_casts", "fields", "projectiles", "terminals", "trails", "chemistry", "discharge", "payloads", "targets"]

static func measured_step(world: SimWorld, commands: Array[SimCommand]) -> Dictionary:
	var times := {}
	for stage: String in STAGES:
		times[stage] = 0
	var started := Time.get_ticks_usec()
	if not world.is_valid():
		return {"ok": false, "times": times}
	var ordered: Array[SimCommand] = commands.duplicate()
	ordered.sort_custom(func(left: SimCommand, right: SimCommand) -> bool: return left.entity_id < right.entity_id)
	var by_entity: Dictionary[int, SimCommand] = {}
	world.combat_events = []
	for command: SimCommand in ordered:
		if command.tick != world.tick:
			world.last_error = "command tick %d does not match world tick %d" % [command.tick, world.tick]
			return {"ok": false, "times": times}
		if by_entity.has(command.entity_id):
			world.last_error = "duplicate command for entity %d at tick %d" % [command.entity_id, world.tick]
			return {"ok": false, "times": times}
		if world.player(command.entity_id) == null:
			world.last_error = "unknown entity %d" % command.entity_id
			return {"ok": false, "times": times}
		by_entity[command.entity_id] = command
	var actors: Array[PlayerState] = world.players.duplicate()
	actors.sort_custom(func(left: PlayerState, right: PlayerState) -> bool: return left.entity_id < right.entity_id)
	times.commands = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	world.reaction_movement.set_surfaces(ReactionMovementWorld.capture_surfaces(world.reactions, world.tick), world.tick)
	var frostway_lanes := FrostwayFieldPolicy.capture(world.reactions, world.tick)
	var capacitor_lanes := CapacitorFieldPolicy.capture(world.reactions, world.tick)
	times.movement_context = Time.get_ticks_usec() - started
	for state: PlayerState in actors:
		if state.health <= 0:
			started = Time.get_ticks_usec()
			world._idle_defeated(state)
			times.resources += Time.get_ticks_usec() - started
			continue
		var command: SimCommand = by_entity.get(state.entity_id, null)
		if command == null:
			command = SimCommand.new(world.tick, state.entity_id, 0, 0, 0, 0, state.aim_x, state.aim_y)
		state.aim_x = command.aim_x
		state.aim_y = command.aim_y
		state.primary_held = command.has_held(SimCommand.HELD_PRIMARY)
		started = Time.get_ticks_usec()
		PlayerResourcesSystem.step(state, world.config)
		times.resources += Time.get_ticks_usec() - started
		started = Time.get_ticks_usec()
		world.reaction_movement.begin_actor(Vector2i(state.position_x, state.position_y), MovementTuning.PLAYER_RADIUS)
		ReactionMovementWorld.clear_stale_contact(state, world.reaction_movement)
		var point := Vector2i(state.position_x, state.position_y)
		var ground_ratio := FrostwayFieldPolicy.movement_ratio(frostway_lanes, point, world.tick)
		if ground_ratio == 1000:
			ground_ratio = CapacitorFieldPolicy.movement_ratio(capacitor_lanes, point, world.tick)
		MovementSystem.step(state, command, world.config, world.reaction_movement, ground_ratio)
		times.movement += Time.get_ticks_usec() - started
		started = Time.get_ticks_usec()
		var capacity := Vector2i.ZERO
		var admission_offer: Dictionary = {}
		if state.pending_cast_wire_id == 0 and (command.first_pressed_spell_slot() > 0 or command.first_held_spell_slot() > 0 or command.has_pressed(SimCommand.PRESSED_ACTIVE_1) or command.has_held(SimCommand.HELD_PRIMARY)):
			admission_offer = world._cast_admission_offer(state.entity_id)
			capacity = admission_offer.capacity
		times.capacity += Time.get_ticks_usec() - started
		started = Time.get_ticks_usec()
		var spawned: Variant = CombatSystem.step_player(state, command, world.config, world.next_projectile_id, world.next_field_id, world.collision, world.combat_events, world.transition_policy, capacity.x, capacity.y)
		if not admission_offer.is_empty() and state.pending_cast_wire_id != 0:
			world._commit_trail_reclamation(state, admission_offer)
		world._store_combat_result(spawned)
		times.casts += Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	CombatSystem.resolve_instant_casts(world.players, world.config, world.collision, world.combat_events, world.reactions, world.tick)
	times.instant_casts = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	world.fields.sort_custom(func(left: FieldState, right: FieldState) -> bool: return left.entity_id < right.entity_id)
	world.fields = CombatSystem.advance_fields(world.fields, world.players, world.config, world.combat_events)
	times.fields = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	world.projectiles.sort_custom(func(left: ProjectileState, right: ProjectileState) -> bool: return left.entity_id < right.entity_id)
	var owner_slots := world._owner_material_slots()
	var free_slots := world._free_material_slots()
	times.capacity += Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	world.projectiles = DrillCombat.measured_advance_projectiles(world.projectiles, world.players, world.config, world.collision, world.combat_events, world.reactions, world.tick, free_slots, owner_slots)
	times.projectiles = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	world._consume_projectile_terminals()
	times.terminals = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	world._seed_projectile_trails()
	times.trails = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	world.next_reaction_id = ElementChemistrySystem.step(world.deposits, world.reactions, world.players, world.collision, world.config, world.tick, world.next_reaction_id, world.combat_events)
	times.chemistry = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	if CapacitorFieldPolicy.discharge_due(capacitor_lanes, world.tick):
		world.reaction_movement.set_surfaces(ReactionMovementWorld.capture_surfaces(world.reactions, world.tick), world.tick)
		for state: PlayerState in actors:
			world.reaction_movement.begin_actor(Vector2i(state.position_x, state.position_y), MovementTuning.PLAYER_RADIUS)
			CapacitorFieldPolicy.apply_discharge(capacitor_lanes, state, world.tick, world.reaction_movement)
	times.discharge = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	world._exhaust_reacted_cast_payloads()
	times.payloads = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	for state: PlayerState in actors:
		Targets.step_target(state, world.config)
	times.targets = Time.get_ticks_usec() - started
	world.tick += 1
	return {"ok": true, "times": times}
