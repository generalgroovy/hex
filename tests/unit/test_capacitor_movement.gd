extends FluxTestSuite
@warning_ignore_start("integer_division")

const ORIGIN := Vector2i(600_000, 500_000)
var config := SimConfig.new()

func run() -> int:
	_test_policy_geometry_phases_and_validation()
	_test_ground_targets_and_action_invariants()
	_test_terminal_discharge()
	return finish("capacitor-movement")

func _reaction(direction: Vector2i = Vector2i(1000, 0), id: int = 4000, active_ticks: int = 240) -> ElementReactionState:
	var result := ElementReactionState.new()
	result.entity_id = id
	result.recipe_wire_id = 331
	result.owner_id = 1
	result.team_id = 1
	result.position_x = ORIGIN.x
	result.position_y = ORIGIN.y
	result.origin_x = ORIGIN.x
	result.origin_y = ORIGIN.y
	result.direction_x = direction.x
	result.direction_y = direction.y
	result.created_tick = 0
	result.active_tick = 78
	result.decay_tick = result.active_tick + active_ticks
	result.expiry_tick = result.decay_tick + 54
	result.radius = 30_000
	result.length = 200_000
	result.source_a = 3000
	result.source_b = 3001
	var end := ORIGIN + ElementChemistrySystem.scaled(direction, result.length)
	result.endpoint_x = end.x
	result.endpoint_y = end.y
	return result

func _state(radius: int = 18_000, point: Vector2i = ORIGIN + Vector2i(100_000, 0)) -> PlayerState:
	var state := PlayerState.new(2)
	state.team_id = 2
	state.position_x = point.x
	state.position_y = point.y
	state.radius = radius
	return state

func _copy(state: PlayerState) -> PlayerState:
	return ClientPrediction.restore_state(ClientPrediction.capture_packet(state, 0, -1)["values"])

func _test_policy_geometry_phases_and_validation() -> void:
	var definition := ElementChemistrySystem.recipe(331)
	equal(definition.id, "overload", "stable internal Charge reaction identity retained")
	equal(definition.name, "Capacitor", "player-facing name identifies the finite acceleration lane")
	equal(definition.shape, "corridor", "Capacitor uses the existing stationary capsule geometry")
	equal(definition.formation_ms, 650, "warning remains650ms")
	equal(definition.active_ms, 2000, "active opportunity remains finite at2000ms")
	equal(definition.decay_ms, 450, "terminal matter has450ms harmless decay")
	equal(definition.radius, 30_000, "capsule radius is30px after shared extent policy")
	equal(definition.length, 200_000, "capsule centerline is200px after shared extent policy")
	var expected_policy := {"version": 1, "recipe": 331, "name": "Capacitor", "shape": "stationary_capsule", "radius": 30_000, "length": 200_000, "warning_ms": 650, "active_ms": 2000, "final_warning_ms": 500, "decay_ms": 450, "walk_sprint_target_ratio": 1250, "slide_ratio": 1000, "air_and_forced_control_ratio": 1000, "maximum_speed": MovementTuning.MAX_AUTHORED_SPEED, "query": "center_at_tick_start", "teams": "all", "stacking": "nonstacking", "overlap_precedence": "frostway_750_else_capacitor_1250", "discharge_tick": "decay_tick_minus_one", "discharge_distance": 14_000, "discharge_direction": "cast", "discharge_targets": "grounded_enemy_unprotected", "simultaneous_discharge_cap": 14_000, "simultaneous_discharge_scope": "per_actor_per_tick_lowest_id", "prediction": "required_exact_tick_lanes_v1", "solid": false, "ray_blocking": false, "base_velocity_damage_lifetime_cost_protection_unchanged": true}
	equal(CapacitorFieldPolicy.policy(), expected_policy, "compatibility fingerprint exposes every bounded rule")
	for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		var reaction := _reaction(direction)
		check(reaction.validate(), "Capacitor state validates all eight orientations")
		var rows := CapacitorFieldPolicy.capture([reaction], 77)
		check(CapacitorFieldPolicy.validate(rows, 77), "future exact-tick row validates during warning")
		var center := ORIGIN + ElementChemistrySystem.scaled(direction, 100_000)
		for tick: int in [0, 77, 78, 317, 318, 372]:
			var active := tick >= 78 and tick < 318
			equal(CapacitorFieldPolicy.contains(rows, center, tick), active, "capsule obeys exact active/decay boundary")
			equal(CapacitorFieldPolicy.movement_ratio(rows, center, tick), 1250 if active else 1000, "ground target obeys the same boundary")
		for across: int in [-30_001, -30_000, 0, 30_000, 30_001]:
			var point := center + ElementChemistrySystem.scaled(Vector2i(-direction.y, direction.x), across)
			equal(CapacitorFieldPolicy.contains(rows, point, 78), ElementChemistrySystem.contains(reaction, point, 78, config), "policy capsule matches chemistry including tangency")
	var rows := CapacitorFieldPolicy.capture([_reaction()], 78)
	for fixture: Array in [[0, 0], [0, 2_000_000_000], [1, -1_000_001], [4, 100_000_001], [5, 30001], [6, 200001], [3, ORIGIN.x], [7, -1], [7, 157], [8, 78], [8, 319], [9, 0], [9, 257]]:
		var malformed := rows.duplicate()
		malformed[int(fixture[0])] = int(fixture[1])
		check(not CapacitorFieldPolicy.validate(malformed, 78), "malformed identity/geometry/timing/team fails closed")
	check(not CapacitorFieldPolicy.validate(rows, 318), "stale row cannot be admitted at decay tick")
	var duplicate := rows.duplicate()
	duplicate.append_array(rows)
	check(not CapacitorFieldPolicy.validate(duplicate, 78), "duplicate identities rejected")
	rows.append(0)
	check(not CapacitorFieldPolicy.validate(rows, 78), "truncated row rejected")
	var a := _reaction(Vector2i(1000, 0), 4010)
	var b := _reaction(Vector2i(0, 1000), 4001)
	var sorted := CapacitorFieldPolicy.capture([a, b], 78)
	equal(sorted[0], 4001, "rows sort by reaction identity")
	equal(sorted, CapacitorFieldPolicy.capture([b, a], 78), "authority input order cannot change derived context")
	var trail_rows := CapacitorFieldPolicy.capture([_reaction(Vector2i(1000, 0), 4020, 144)], 78)
	check(CapacitorFieldPolicy.validate(trail_rows, 78), "trail-assisted60percent active duration remains valid")

func _test_ground_targets_and_action_invariants() -> void:
	var world := CollisionWorld.new(2_000_000, 1_500_000)
	for radius: int in [17_000, 18_000, 19_000]:
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			var center := ORIGIN + ElementChemistrySystem.scaled(direction, 100_000)
			var first := _reaction(direction, 4000)
			var second := _reaction(direction, 4001)
			var rows := CapacitorFieldPolicy.capture([second, first], 78)
			equal(CapacitorFieldPolicy.movement_ratio(rows, center, 78), 1250, "overlapping Capacitors never compound")
			for held: int in [0, SimCommand.HELD_SPRINT]:
				var boosted := _state(radius, center)
				var normal := _copy(boosted)
				for tick: int in range(78, 150):
					boosted.position_x = center.x
					boosted.position_y = center.y
					var command := SimCommand.new(tick, 2, direction.x, direction.y, held)
					MovementSystem.step(boosted, command, config, world, CapacitorFieldPolicy.movement_ratio(rows, center, tick))
					MovementSystem.step(normal, command, config, world)
				var normal_speed := SimCommand._integer_square_root(normal.velocity_x * normal.velocity_x + normal.velocity_y * normal.velocity_y)
				var boosted_speed := SimCommand._integer_square_root(boosted.velocity_x * boosted.velocity_x + boosted.velocity_y * boosted.velocity_y)
				var expected_speed := mini(MovementTuning.MAX_AUTHORED_SPEED, normal_speed * 1250 / 1000)
				check(absi(boosted_speed - expected_speed) <= 2, "all sizes/directions settle at125percent or the authored speed cap within fixed diagonal quantization")
				check(boosted_speed <= MovementTuning.MAX_AUTHORED_SPEED, "Capacitor never raises the authored speed ceiling")
				equal(boosted.stamina, normal.stamina, "walk/sprint resource drain remains ordinary")
				equal(boosted.control_state, PlayerState.ControlState.FREE, "acceleration does not write a control state")
				equal(boosted.slow_ratio, 1000, "acceleration does not rewrite hostile slow state")
	for action: String in ["slide", "air_dodge", "launched"]:
		var affected := _state()
		affected.velocity_x = 350_000
		var pressed := 0
		var held := 0
		match action:
			"slide":
				pressed = SimCommand.PRESSED_SLIDE
				held = SimCommand.HELD_SLIDE
			"air_dodge":
				affected.air_height = 18_000
				affected.hop_ticks = 30
				affected.hop_stage = 1
				affected.air_velocity_x = affected.velocity_x
				pressed = SimCommand.PRESSED_EVADE
			"launched":
				MovementSystem.apply_control_state(affected, PlayerState.ControlState.LAUNCHED, 500, Vector2i(1000, 0), 350_000, config)
		var normal := _copy(affected)
		var command := SimCommand.new(78, 2, 1000, 0, held, pressed)
		MovementSystem.step(affected, command, config, world, 1250)
		MovementSystem.step(normal, command, config, world, 1000)
		for field: StringName in ClientPrediction.STATE_FIELDS:
			equal(affected.get(field), normal.get(field), "Capacitor bypasses%s resources/protection/control/air budget field%s" % [action, field])

func _test_terminal_discharge() -> void:
	var world := CollisionWorld.new(2_000_000, 1_500_000)
	var rows := CapacitorFieldPolicy.capture([_reaction()], 317)
	check(not CapacitorFieldPolicy.discharge_due(rows, 316), "terminal view is unnecessary before exact discharge tick")
	check(CapacitorFieldPolicy.discharge_due(rows, 317), "terminal view is requested on exact discharge tick")
	check(not CapacitorFieldPolicy.discharge_due(rows, 318), "terminal view is unnecessary during harmless decay")
	var enemy := _state()
	var before := _copy(enemy)
	check(CapacitorFieldPolicy.apply_discharge(rows, enemy, 317, world), "grounded unprotected enemy discharges on final active tick")
	equal(Vector2i(enemy.position_x, enemy.position_y), Vector2i(before.position_x + 14_000, before.position_y), "discharge moves14px along cast direction")
	for field: StringName in ClientPrediction.STATE_FIELDS:
		if field not in [&"position_x", &"position_y"]:
			equal(enemy.get(field), before.get(field), "discharge changes no damage/status/resource/protection field%s" % field)
	var low := _reaction(Vector2i(1000, 0), 4000)
	var high := _reaction(Vector2i(0, 1000), 4001)
	var overlap := _state(18_000, ORIGIN)
	check(CapacitorFieldPolicy.apply_discharge(CapacitorFieldPolicy.capture([high, low], 317), overlap, 317, world), "overlapping terminal fields select one discharge")
	equal(Vector2i(overlap.position_x, overlap.position_y), ORIGIN + Vector2i(14_000, 0), "lowest identity wins and overlapping lanes cannot stack displacement")
	var escaping := _state(18_000, ORIGIN + Vector2i(220_000, 0))
	check(CapacitorFieldPolicy.apply_discharge(rows, escaping, 317, world), "enemy may use terminal push at the capsule end")
	check(not CapacitorFieldPolicy.contains(rows, Vector2i(escaping.position_x, escaping.position_y), 317), "terminal push can complete an escape")
	var wall_reaction := _reaction(Vector2i(1000, 0))
	wall_reaction.position_x = 1_780_000
	wall_reaction.endpoint_x = 1_980_000
	var wall_rows := CapacitorFieldPolicy.capture([wall_reaction], 317)
	var walled := _state(18_000, Vector2i(1_981_000, ORIGIN.y))
	check(CapacitorFieldPolicy.apply_discharge(wall_rows, walled, 317, world), "terminal discharge is consumed against collision bounds")
	check(walled.position_x <= 2_000_000 - MovementTuning.PLAYER_RADIUS, "collision-safe push never crosses world boundary")
	for blocked: String in ["warning", "decay", "air", "protected", "team", "dead"]:
		var state := _state()
		var tick := 317
		match blocked:
			"warning": tick = 77
			"decay": tick = 318
			"air":
				state.air_height = 1
				state.hop_ticks = 1
			"protected": state.spawn_protection_ticks = 1
			"team": state.team_id = 1
			"dead": state.health = 0
		var state_before := _copy(state)
		check(not CapacitorFieldPolicy.apply_discharge(rows, state, tick, world), "%s actor cannot receive terminal discharge" % blocked)
		for field: StringName in ClientPrediction.STATE_FIELDS:
			equal(state.get(field), state_before.get(field), "%s rejection leaves every state field unchanged" % blocked)
	var empty_then_late := _state(18_000, ORIGIN + Vector2i(300_001, 0))
	check(not CapacitorFieldPolicy.apply_discharge(rows, empty_then_late, 317, world), "terminal tick is consumed even when no actor is inside")
	empty_then_late.position_x = ORIGIN.x + 100_000
	check(not CapacitorFieldPolicy.apply_discharge(rows, empty_then_late, 318, world), "late entry cannot repeat a previous discharge")
	var trail_rows := CapacitorFieldPolicy.capture([_reaction(Vector2i(1000, 0), 4020, 144)], 221)
	var trail_enemy := _state()
	check(CapacitorFieldPolicy.apply_discharge(trail_rows, trail_enemy, 221, world), "trail-assisted duration discharges on its own exact decay-minus-one tick")
