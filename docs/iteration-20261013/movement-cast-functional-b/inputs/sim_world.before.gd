class_name SimWorld
extends RefCounted


const MAP_ID: String = "foundation-arena-v1"
const MAP_HASH: String = "worldbone:none;bounds:1280x720;rails:v1"
const TrainingTargetSystemScript = preload("res://src/sim/combat/training_target_system.gd")

var config: SimConfig
var collision: CollisionWorld
var reaction_movement: ReactionMovementWorld
var transition_policy: ActionTransitionPolicy
var tick: int = 0
var seed: int = 1
var map_id: String = MAP_ID
var map_hash: String = MAP_HASH
var players: Array[PlayerState] = []
var projectiles: Array[ProjectileState] = []
var fields: Array[FieldState] = []
var deposits: Array[ElementDepositState] = []
var reactions: Array[ElementReactionState] = []
var next_deposit_id: int = 3000
var next_reaction_id: int = 4000
var next_projectile_id: int = 1000
var next_field_id: int = 2000
var combat_events: Array[Dictionary] = []
var last_error: String = ""
var hex_court: RefCounted = null # Explicit solo migration world; never co-simulate old chemistry.
var profile_enabled := false # Diagnostic only; excluded from authority/snapshots.
var profile_stages_us: Dictionary = {}

# Explicit, full-observer diagnostics. Reuses the existing stage timestamps;
# never contributes to authority, snapshots, or the default/light observer path.
const PROFILE_CUMULATIVE_STAGES: Array[String] = [
	"surfaces_expiry", "command_order", "movement_cast_admission", "spray_contacts",
	"projectile_contacts", "terminal_deposits", "actor_product_effects",
	"chemistry_exposure", "finalize",
]
var _profile_cumulative_enabled := false
var _profile_cumulative_epoch: int = 0
var _profile_cumulative_attempted_steps: int = 0
var _profile_cumulative_completed_steps: int = 0
var _profile_cumulative_failed_steps: int = 0
var _profile_cumulative_elapsed_us: Dictionary = {}
var _profile_cumulative_executions: Dictionary = {}


func profile_cumulative_begin() -> bool:
	if not profile_enabled:
		return false
	profile_cumulative_reset()
	_profile_cumulative_enabled = true
	return true


func profile_cumulative_end() -> void:
	_profile_cumulative_enabled = false


func profile_cumulative_reset() -> void:
	_profile_cumulative_epoch += 1
	_profile_cumulative_attempted_steps = 0
	_profile_cumulative_completed_steps = 0
	_profile_cumulative_failed_steps = 0
	_profile_cumulative_elapsed_us.clear()
	_profile_cumulative_executions.clear()
	for label: String in PROFILE_CUMULATIVE_STAGES:
		_profile_cumulative_elapsed_us[label] = 0
		_profile_cumulative_executions[label] = 0


func profile_cumulative_snapshot() -> Dictionary:
	# Caller-owned fixed-size copies; no live dictionary or authority reference.
	var elapsed_us: Dictionary = {}
	var executions: Dictionary = {}
	for label: String in PROFILE_CUMULATIVE_STAGES:
		elapsed_us[label] = int(_profile_cumulative_elapsed_us.get(label, 0))
		executions[label] = int(_profile_cumulative_executions.get(label, 0))
	return {
		"schema": "hex.sim.completed-stages.v1", "enabled": _profile_cumulative_enabled,
		"profile_enabled": profile_enabled, "world_id": str(get_instance_id()),
		"epoch": _profile_cumulative_epoch, "tick": tick, "hex_mode": hex_court != null,
		"attempted_steps": _profile_cumulative_attempted_steps,
		"completed_steps": _profile_cumulative_completed_steps,
		"failed_steps": _profile_cumulative_failed_steps,
		"elapsed_us": elapsed_us, "executions": executions,
	}


func _profile_cumulative_failed(epoch: int) -> bool:
	if epoch > 0 and epoch == _profile_cumulative_epoch and _profile_cumulative_enabled and profile_enabled:
		_profile_cumulative_failed_steps += 1
	return false


func _profile_cumulative_commit(epoch: int) -> void:
	if epoch != _profile_cumulative_epoch or not _profile_cumulative_enabled or not profile_enabled:
		return
	# Commit only after tick/finalize succeeds. A failed step's already measured
	# prefixes remain in the legacy last-step output, never in these totals.
	for label: String in PROFILE_CUMULATIVE_STAGES:
		if profile_stages_us.has(label):
			_profile_cumulative_elapsed_us[label] += int(profile_stages_us[label])
			_profile_cumulative_executions[label] += 1
	_profile_cumulative_completed_steps += 1


func _profile_stage(label: String, started: int) -> int:
	if not profile_enabled: return 0
	var now := Time.get_ticks_usec()
	profile_stages_us[label] = now - started
	return now


func _init(
	requested_tick_rate: int = SimConfig.TICK_RATE,
	requested_seed: int = 1,
	requested_collision: CollisionWorld = null,
	requested_map_id: String = MAP_ID,
	requested_map_hash: String = MAP_HASH,
) -> void:
	config = SimConfig.new(requested_tick_rate)
	seed = requested_seed
	map_id = requested_map_id
	map_hash = requested_map_hash
	collision = requested_collision if requested_collision != null else CollisionWorld.new()
	reaction_movement = collision if collision is HexCollisionWorld else ReactionMovementWorld.new(collision)
	if config.is_valid():
		transition_policy = ActionTransitionPolicy.new()
		if not transition_policy.load_from_file():
			last_error = transition_policy.last_error
			return
		if requested_collision == null:
			collision.add_obstacle(CollisionWorld.Obstacle.new(1, 560_000, 250_000, 620_000, 470_000, false))
			collision.add_obstacle(CollisionWorld.Obstacle.new(2, 820_000, 300_000, 900_000, 380_000, true))
		players.append(PlayerState.new(1))
	else:
		last_error = "unsupported tick rate: %d; FLUX requires 120 Hz" % requested_tick_rate


func is_valid() -> bool:
	return config.is_valid() and transition_policy != null and transition_policy.content_hash.length() == 64 and last_error.is_empty()


func player(entity_id: int = 1) -> PlayerState:
	for candidate: PlayerState in players:
		if candidate.entity_id == entity_id:
			return candidate
	return null


func step(commands: Array[SimCommand]) -> bool:
	var cumulative_epoch := 0
	if profile_enabled and _profile_cumulative_enabled:
		cumulative_epoch = _profile_cumulative_epoch
		_profile_cumulative_attempted_steps += 1
	if not is_valid():
		return _profile_cumulative_failed(cumulative_epoch)
	var profile_started := Time.get_ticks_usec() if profile_enabled else 0
	if profile_enabled: profile_stages_us.clear()
	if hex_court != null:
		if not deposits.is_empty() or not reactions.is_empty() or not fields.is_empty():
			last_error = "hex court rejects concurrent legacy chemistry state"
			return _profile_cumulative_failed(cumulative_epoch)
		hex_court.expire_at(tick)
		hex_court.fracture_products(tick)
		if not (collision is HexCollisionWorld):
			collision = HexCollisionWorld.new(collision)
			reaction_movement = collision
		hex_court.collision = collision.base_world
		if not collision.set_hex_surfaces(hex_court, tick):
			last_error = "invalid trusted hex physics topology"
			return _profile_cumulative_failed(cumulative_epoch)
		hex_court.move_products(tick, collision)
	profile_started = _profile_stage("surfaces_expiry", profile_started)
	var ordered: Array[SimCommand] = commands.duplicate()
	ordered.sort_custom(func(left: SimCommand, right: SimCommand) -> bool: return left.entity_id < right.entity_id)
	var commands_by_entity: Dictionary[int, SimCommand] = {}
	var hex_paths: Dictionary = {}
	combat_events = []
	for command: SimCommand in ordered:
		if command.tick != tick:
			last_error = "command tick %d does not match world tick %d" % [command.tick, tick]
			return _profile_cumulative_failed(cumulative_epoch)
		if commands_by_entity.has(command.entity_id):
			last_error = "duplicate command for entity %d at tick %d" % [command.entity_id, tick]
			return _profile_cumulative_failed(cumulative_epoch)
		if player(command.entity_id) == null:
			last_error = "unknown entity %d" % command.entity_id
			return _profile_cumulative_failed(cumulative_epoch)
		commands_by_entity[command.entity_id] = command
	var ordered_players: Array[PlayerState] = players.duplicate()
	ordered_players.sort_custom(func(left: PlayerState, right: PlayerState) -> bool: return left.entity_id < right.entity_id)
	if hex_court == null:
		reaction_movement.set_surfaces(ReactionMovementWorld.capture_surfaces(reactions, tick), tick)
	var frostway_lanes := FrostwayFieldPolicy.capture(reactions, tick) if hex_court == null else PackedInt32Array()
	var capacitor_lanes := CapacitorFieldPolicy.capture(reactions, tick) if hex_court == null else PackedInt32Array()
	profile_started = _profile_stage("command_order", profile_started)
	for state: PlayerState in ordered_players:
		if hex_court != null:
			hex_paths[state.entity_id] = {"point": Vector2i(state.position_x, state.position_y), "height": state.air_height}
		if state.health <= 0:
			_idle_defeated(state)
			continue
		var command: SimCommand = commands_by_entity.get(state.entity_id, null)
		if command == null:
			command = SimCommand.new(tick, state.entity_id, 0, 0, 0, 0, state.aim_x, state.aim_y)
		state.aim_x = command.aim_x
		state.aim_y = command.aim_y
		state.primary_held = command.has_held(SimCommand.HELD_PRIMARY)
		PlayerResourcesSystem.step(state, config)
		SpellStatusPolicy.advance(state,config,combat_events)
		if state.health <= 0: continue
		reaction_movement.begin_actor(Vector2i(state.position_x, state.position_y), MovementTuning.PLAYER_RADIUS)
		ReactionMovementWorld.clear_stale_contact(state, reaction_movement)
		var point := Vector2i(state.position_x, state.position_y)
		var ground_ratio := FrostwayFieldPolicy.movement_ratio(frostway_lanes, point, tick)
		if ground_ratio == 1000:
			ground_ratio = CapacitorFieldPolicy.movement_ratio(capacitor_lanes, point, tick)
		var acceleration_ratio := 1000
		var braking_ratio := 1000
		if hex_court != null:
			var modifiers := HexProductEffects.pre_movement(hex_court, state, tick, point, config)
			ground_ratio = int(modifiers.ground_target_ratio)
			acceleration_ratio = int(modifiers.acceleration_ratio)
			braking_ratio = int(modifiers.braking_ratio)
		ground_ratio = mini(ground_ratio,SpellStatusPolicy.movement_ratio(state))
		MovementSystem.step(state, command, config, reaction_movement, ground_ratio, acceleration_ratio, braking_ratio)
		var capacity := Vector2i.ZERO
		var admission_offer: Dictionary = {}
		if state.pending_cast_wire_id == 0 and (command.first_pressed_spell_slot() > 0 or command.first_held_spell_slot() > 0 or command.has_pressed(SimCommand.PRESSED_ACTIVE_1) or command.has_held(SimCommand.HELD_PRIMARY)):
			admission_offer = _cast_admission_offer(state.entity_id)
			capacity = admission_offer.capacity
		var spawned: Variant = CombatSystem.step_player(
			state, command, config, next_projectile_id, next_field_id, collision, combat_events, transition_policy, capacity.x, capacity.y, hex_court
		)
		if hex_court != null:
			var released: bool = spawned is ProjectileState or (spawned is Dictionary and spawned.has("instant_cast_id")) or (spawned is Array and not spawned.is_empty())
			if released:
				var release_direction := Vector2i(state.pending_cast_aim_x, state.pending_cast_aim_y)
				if spawned is Array and not spawned.is_empty():
					var released_shot: ProjectileState = spawned[0]
					release_direction = SimCommand._normalized_direction(released_shot.velocity_x, released_shot.velocity_y)
				elif spawned is Dictionary:
					for release_event: Dictionary in combat_events:
						if int(release_event.get("source_cast_id", 0)) == next_projectile_id and release_event.has("aim_x"):
							release_direction = Vector2i(int(release_event.aim_x), int(release_event.aim_y))
				hex_court.bind_release(state.entity_id, next_projectile_id, Vector2i(state.position_x, state.position_y), release_direction, state.team_id)
		if not admission_offer.is_empty() and state.pending_cast_wire_id != 0:
			# The existing combat admission path has accepted and paid for the
			# whole cast. Refusals never reach this commit, including Flux/control
			# and cooldown failures. Commit before the next owner's admission.
			_commit_trail_reclamation(state, admission_offer)
		_store_combat_result(spawned)
	profile_started = _profile_stage("movement_cast_admission", profile_started)
	if hex_court != null:
		HexProjectileCombat.resolve_sprays(self)
		if not last_error.is_empty(): return _profile_cumulative_failed(cumulative_epoch)
	else:
		SprayInterception.resolve(self)
		CombatSystem.resolve_instant_casts(players, config, collision, combat_events, reactions, tick)
	profile_started = _profile_stage("spray_contacts", profile_started)
	fields.sort_custom(func(left: FieldState, right: FieldState) -> bool: return left.entity_id < right.entity_id)
	fields = CombatSystem.advance_fields(fields, players, config, combat_events)
	projectiles.sort_custom(func(left: ProjectileState, right: ProjectileState) -> bool: return left.entity_id < right.entity_id)
	if hex_court != null:
		HexProjectileCombat.advance(self)
		if not last_error.is_empty(): return _profile_cumulative_failed(cumulative_epoch)
	else:
		var owner_material_slots := _owner_material_slots()
		projectiles = CombatSystem.advance_projectiles(projectiles, players, config, collision, combat_events, reactions, tick, _free_material_slots(), owner_material_slots)
	profile_started = _profile_stage("projectile_contacts", profile_started)
	_consume_projectile_terminals()
	profile_started = _profile_stage("terminal_deposits", profile_started)
	if hex_court == null:
		next_reaction_id = ElementChemistrySystem.step(deposits, reactions, players, collision, config, tick, next_reaction_id, combat_events)
	else:
		# Mantle alone spends a bounded25% trail allocation from its paid stock.
		HexTrailEmitter.emit(self,"mantle")
		hex_court.apply_product_effects(players, tick, config, collision, combat_events, hex_paths)
		profile_started = _profile_stage("actor_product_effects", profile_started)
		hex_court.advance(players, hex_paths, tick, config, combat_events)
		# The following sync already retires a defeated owner's unfired paid
		# stock. Clear its matching actor reservation at this same boundary so
		# every completed Hex step retains the strict snapshot relation.
		for state: PlayerState in ordered_players:
			if state.health <= 0:
				state.pending_cast_wire_id = 0
				state.pending_cast_ticks = 0
		hex_court.sync_flights(players, projectiles)
	profile_started = _profile_stage("chemistry_exposure", profile_started)
	# Discharge follows combat/chemistry, using the current temporary cover view.
	# One shared helper predicts this finite movement without any control reset.
	if CapacitorFieldPolicy.discharge_due(capacitor_lanes, tick):
		reaction_movement.set_surfaces(ReactionMovementWorld.capture_surfaces(reactions, tick), tick)
		for state: PlayerState in ordered_players:
			reaction_movement.begin_actor(Vector2i(state.position_x, state.position_y), MovementTuning.PLAYER_RADIUS)
			CapacitorFieldPolicy.apply_discharge(capacitor_lanes, state, tick, reaction_movement, config)
	if hex_court == null:
		_exhaust_reacted_cast_payloads()
	for state: PlayerState in ordered_players:
		TrainingTargetSystemScript.step_target(state, config)
	tick += 1
	_profile_stage("finalize", profile_started)
	if cumulative_epoch > 0:
		_profile_cumulative_commit(cumulative_epoch)
	return true


func available_cast_capacity(owner_id: int) -> Vector2i:
	var limits := _cast_capacity_limits(owner_id)
	return Vector2i(maxi(0, mini(limits.x, limits.y)), maxi(0, limits.z))


func available_cast_offer(owner_id: int) -> Vector2i:
	# Read-only HUD preview of the exact virtual capacity offered to combat.
	# available_cast_capacity() still reports physical, unreclaimed inventory.
	return _cast_admission_offer(owner_id).capacity


func _cast_capacity_limits(owner_id: int) -> Vector3i:
	# Separate immutable projectile slots from reclaimable material slots.
	# Keep raw deficits so an offer cannot hide over-cap imported/test state.
	var reserved_projectiles := projectiles.size()
	reserved_projectiles += _deferred_spray_slots()
	var reserved_fields := fields.size()
	var owner_projectiles := 0
	owner_projectiles += _deferred_spray_slots(owner_id)
	var owner_fields := 0
	var owner_deposits := 0
	for deposit: ElementDepositState in deposits:
		if deposit.owner_id == owner_id:
			owner_deposits += 1
	for projectile: ProjectileState in projectiles:
		if projectile.owner_id == owner_id:
			owner_projectiles += 1
	for field: FieldState in fields:
		if field.owner_id == owner_id:
			owner_fields += 1
	for state: PlayerState in players:
		if state.health <= 0 or state.pending_cast_wire_id == 0:
			continue
		var requirement := CombatSystem.cast_capacity_requirement(state.pending_cast_wire_id)
		reserved_projectiles += requirement.x
		reserved_fields += requirement.y
		if state.entity_id == owner_id:
			owner_projectiles += requirement.x
			owner_fields += requirement.y
	return Vector3i(
		mini(SimConfig.MAX_ACTIVE_PROJECTILES - reserved_projectiles, SimConfig.MAX_PROJECTILES_PER_PLAYER - owner_projectiles),
		mini(ElementChemistrySystem.MAX_DEPOSITS - deposits.size() - reserved_projectiles, ElementChemistrySystem.MAX_OWNER_DEPOSITS - owner_deposits - owner_projectiles),
		mini(SimConfig.MAX_ACTIVE_FIELDS - reserved_fields, SimConfig.MAX_FIELDS_PER_PLAYER - owner_fields),
	)


func _cast_admission_offer(owner_id: int) -> Dictionary:
	var limits := _cast_capacity_limits(owner_id)
	var eligible: Array[ElementDepositState] = []
	# Reclamation cannot help an immutable projectile limit, so avoid querying
	# optional material unless it could actually increase admission capacity.
	if limits.x > maxi(0, limits.y):
		var protected_ids := {}
		for reaction: ElementReactionState in reactions:
			if tick < reaction.expiry_tick:
				for linked_id: int in reaction.linked_deposit_ids:
					protected_ids[linked_id] = true
		for deposit: ElementDepositState in deposits:
			if deposit.owner_id == owner_id and deposit.is_trail() and deposit.strength > 0 and tick >= deposit.created_tick and tick < deposit.expiry_tick and not protected_ids.has(deposit.entity_id):
				eligible.append(deposit)
		eligible.sort_custom(func(a: ElementDepositState, b: ElementDepositState) -> bool:
			return a.created_tick < b.created_tick if a.created_tick != b.created_tick else a.entity_id < b.entity_id)
	return {"capacity": Vector2i(maxi(0, mini(limits.x, limits.y + eligible.size())), maxi(0, limits.z)),
		"material_slots": limits.y, "eligible_trails": eligible}


func _commit_trail_reclamation(state: PlayerState, offer: Dictionary) -> void:
	var required := CombatSystem.cast_capacity_requirement(state.pending_cast_wire_id).x
	if required <= 0:
		return # Instant spells and Fields never erase chemistry ingredients.
	var needed := maxi(0, required - int(offer.material_slots))
	if needed == 0:
		return
	var eligible: Array = offer.eligible_trails
	assert(needed <= eligible.size(), "accepted whole cast must have a complete material reclamation offer")
	var reclaimed_ids := PackedInt64Array()
	for index: int in range(needed):
		var deposit: ElementDepositState = eligible[index]
		reclaimed_ids.append(deposit.entity_id)
		deposits.erase(deposit)
	combat_events.append({"type": "cast_trails_reclaimed", "owner_id": state.entity_id,
		"wire_id": state.pending_cast_wire_id, "deposit_ids": reclaimed_ids, "count": needed})


func _owner_material_slots() -> Dictionary:
	# One fresh post-cast inventory, equivalent to each owner's capacity.x.
	# Sequential pre-payment admission uses a fresh reclaim-aware offer.
	# x counts live/pending projectiles; y counts deposits. Orphan objects still
	# consume global capacity, and repeated player entries retain pending counts.
	if players.size() <= 1:
		var single_owner := {}
		for state: PlayerState in players:
			single_owner[state.entity_id] = available_cast_capacity(state.entity_id).x
		return single_owner
	var counts_by_owner := {}
	for state: PlayerState in players:
		counts_by_owner[state.entity_id] = Vector2i(_deferred_spray_slots(state.entity_id), 0)
	var reserved_projectiles := projectiles.size() + _deferred_spray_slots()
	for projectile: ProjectileState in projectiles:
		if counts_by_owner.has(projectile.owner_id):
			var counts: Vector2i = counts_by_owner[projectile.owner_id]
			counts.x += 1
			counts_by_owner[projectile.owner_id] = counts
	for deposit: ElementDepositState in deposits:
		if counts_by_owner.has(deposit.owner_id):
			var counts: Vector2i = counts_by_owner[deposit.owner_id]
			counts.y += 1
			counts_by_owner[deposit.owner_id] = counts
	for state: PlayerState in players:
		if state.health > 0 and state.pending_cast_wire_id != 0:
			var pending := CombatSystem.cast_capacity_requirement(state.pending_cast_wire_id).x
			reserved_projectiles += pending
			var counts: Vector2i = counts_by_owner[state.entity_id]
			counts.x += pending
			counts_by_owner[state.entity_id] = counts
	var global_slots := mini(SimConfig.MAX_ACTIVE_PROJECTILES-reserved_projectiles,ElementChemistrySystem.MAX_DEPOSITS-deposits.size()-reserved_projectiles)
	var result := {}
	for state: PlayerState in players:
		var counts: Vector2i = counts_by_owner[state.entity_id]
		result[state.entity_id] = maxi(0,mini(global_slots,mini(SimConfig.MAX_PROJECTILES_PER_PLAYER-counts.x,ElementChemistrySystem.MAX_OWNER_DEPOSITS-counts.x-counts.y)))
	return result


func _free_material_slots() -> int:
	var reserved := projectiles.size() + deposits.size() + _deferred_spray_slots()
	for state: PlayerState in players:
		if state.health > 0 and state.pending_cast_wire_id != 0:
			reserved += CombatSystem.cast_capacity_requirement(state.pending_cast_wire_id).x
	return maxi(0, mini(ElementChemistrySystem.MAX_DEPOSITS - reserved, SimConfig.MAX_ACTIVE_PROJECTILES - projectiles.size()))


func _deferred_spray_slots(owner_id: int = -1) -> int:
	# A release is queued before later actors seek admission. Its paid ingredient
	# stays reserved until terminal consumption, including optical split admission.
	var count := 0
	for event: Dictionary in combat_events:
		if owner_id >= 0 and int(event.get("owner_id", 0)) != owner_id:
			continue
		if String(event.get("type", "")) == "spray_requested" or bool(event.get("spray_reservation", false)):
			count += 1
	return count


func _seed_projectile_trails() -> void:
	# Optional ground ingredients use spare capacity only, after real impacts and
	# prism children have consumed their already-paid reservations. No new IDs,
	# timers or client-only history are needed for deterministic snapshot replay.
	if projectiles.is_empty():
		return
	var global_slots := _free_material_slots()
	if global_slots <= ElementChemistrySystem.TRAIL_CAST_RESERVE:
		return
	var owner_slots := _owner_material_slots()
	for projectile: ProjectileState in projectiles:
		# Rapid retains terminal matter but is explicitly trail-free. This is a
		# delivery rule, independent of its cast-owned reaction strength.
		if projectile.material_strength <= 0 or String(CombatTuning.cast_definition(projectile.source_wire_id).get("family", "")) == "rapid":
			continue
		if (tick + projectile.entity_id) % ElementChemistrySystem.TRAIL_SAMPLE_TICKS != 0:
			continue
		var slots := int(owner_slots.get(projectile.owner_id, 0))
		if global_slots <= ElementChemistrySystem.TRAIL_CAST_RESERVE or slots <= ElementChemistrySystem.TRAIL_CAST_RESERVE:
			continue
		var admitted := ElementChemistrySystem.deposit_terminal(deposits, next_deposit_id,
			projectile.source_cast_id if projectile.source_cast_id > 0 else projectile.entity_id,
			projectile.source_wire_id, projectile.owner_id, projectile.team_id, projectile.element_wire_id,
			Vector2i(projectile.position_x, projectile.position_y), tick, config,
			SimCommand._normalized_direction(projectile.velocity_x, projectile.velocity_y),
			mini(projectile.material_strength, ElementChemistrySystem.TRAIL_STRENGTH), true, projectile.reaction_strength)
		if admitted > 0:
			next_deposit_id += 1
			global_slots -= 1
			owner_slots[projectile.owner_id] = slots - 1


func _exhaust_reacted_cast_payloads() -> void:
	if projectiles.is_empty():
		return
	var spent_casts := {}
	for reaction: ElementReactionState in reactions:
		if reaction.created_tick == tick:
			spent_casts[reaction.source_a] = true
			spent_casts[reaction.source_b] = true
	if spent_casts.is_empty():
		return
	for projectile: ProjectileState in projectiles:
		if spent_casts.has(projectile.source_cast_id if projectile.source_cast_id > 0 else projectile.entity_id):
			# Canonical zero keeps damage/flight but prevents chemistry refill,
			# even after the originating reaction and all old trails have expired.
			projectile.material_strength = 0


func _consume_projectile_terminals() -> void:
	var public_events: Array[Dictionary] = []
	for event: Dictionary in combat_events:
		match String(event.get("type", "")):
			"projectile_terminal":
				if hex_court != null:
					if not bool(event.get("hex_committed", false)):
						hex_court.deposit_terminal(event, tick)
					continue
				if int(event["strength"]) <= 0:
					continue
				var admitted := ElementChemistrySystem.deposit_terminal(deposits, next_deposit_id, int(event["source_cast_id"]), int(event["source_wire_id"]), int(event["owner_id"]), int(event["team_id"]), int(event["element_wire_id"]), event["position"], tick, config, event["direction"], int(event["strength"]), false, int(event["reaction_strength"]))
				if admitted > 0:
					next_deposit_id += 1
				elif admitted < 0:
					# Admitted casts reserve this slot before payment; refusal is an invariant failure.
					last_error = "reserved terminal material slot unavailable"
			"chemistry_projectile_split":
				var child: ProjectileState = event["projectile"]
				child.entity_id = next_projectile_id
				next_projectile_id += 1
				projectiles.append(child)
			_:
				public_events.append(event)
	combat_events = public_events


func _store_combat_result(spawned: Variant) -> void:
	if spawned is Dictionary and spawned.has("instant_cast_id"):
		next_projectile_id += 1
	elif spawned is ProjectileState:
		projectiles.append(spawned)
		next_projectile_id += 1
	elif spawned is Array:
		var stored_count := 0
		for value: Variant in spawned:
			if value is ProjectileState:
				projectiles.append(value)
				stored_count += 1
		next_projectile_id += stored_count
	elif spawned is FieldState:
		fields.append(spawned)
		next_field_id += 1


static func _idle_defeated(state: PlayerState) -> void:
	state.spell_status_values.fill(0)
	state.velocity_x = 0
	state.velocity_y = 0
	state.primary_held = false
	state.pending_cast_wire_id = 0
	state.pending_cast_ticks = 0
	state.sprinting = false
	state.movement_mode = PlayerState.MovementMode.IDLE


func state_hash() -> String:
	var verified_hex_hash: String = String(hex_court.state_hash()) if hex_court != null else ""
	return _state_hash_with_verified_hex_hash(verified_hex_hash)


# Snapshot reconstruction may call this only with a chemistry hash already
# recomputed and verified against detached authority. It owns no cache and still
# assembles every outer canonical field in the published byte order.
func _state_hash_with_verified_hex_hash(verified_hex_hash: String) -> String:
	var payload := PackedByteArray()
	if hex_court != null:
		CanonicalBytes.append_string(payload, verified_hex_hash)
	for value: int in [SimConfig.PROTOCOL_VERSION, config.tick_rate, tick, seed, next_projectile_id, next_field_id, next_deposit_id, next_reaction_id]:
		CanonicalBytes.append_i64(payload, value)
	CanonicalBytes.append_string(payload, map_id)
	CanonicalBytes.append_string(payload, map_hash)
	CanonicalBytes.append_string(payload, transition_policy.content_hash)
	var ordered: Array[PlayerState] = players.duplicate()
	ordered.sort_custom(func(left: PlayerState, right: PlayerState) -> bool: return left.entity_id < right.entity_id)
	CanonicalBytes.append_i64(payload, ordered.size())
	for state: PlayerState in ordered:
		for value: int in state.canonical_values():
			CanonicalBytes.append_i64(payload, value)
	CanonicalBytes.append_i64(payload, projectiles.size())
	for projectile: ProjectileState in projectiles:
		for value: int in projectile.canonical_values():
			CanonicalBytes.append_i64(payload, value)
	CanonicalBytes.append_i64(payload, fields.size())
	for field: FieldState in fields:
		for value: int in field.canonical_values():
			CanonicalBytes.append_i64(payload, value)
	CanonicalBytes.append_i64(payload, deposits.size())
	for deposit: ElementDepositState in deposits:
		for value: int in deposit.canonical_values():
			CanonicalBytes.append_i64(payload, value)
	CanonicalBytes.append_i64(payload, reactions.size())
	for reaction: ElementReactionState in reactions:
		for value: int in reaction.canonical_values():
			CanonicalBytes.append_i64(payload, value)
	return CanonicalBytes.sha256_hex(payload)
