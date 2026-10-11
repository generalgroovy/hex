extends FluxTestSuite

var config := SimConfig.new(120)
var arena := CollisionWorld.new(10_000_000, 10_000_000)


func run() -> int:
	_test_release_jump_and_charge()
	_test_gathered_jump_inputs()
	_test_paid_sprint_gather_profiles()
	_test_slide_charge_momentum()
	_test_gathered_action_exits()
	_test_gather_wall_contacts()
	_test_gather_field_modifiers()
	_test_gather_prediction_replay()
	_test_jumpsquat_external_displacement()
	_test_air_budget_and_flight()
	_test_height_matrix()
	_test_wall_hold_release()
	_test_cancel_and_crouch()
	_test_action_chords()
	_test_air_slide_technique_chord()
	_test_wall_slide_technique_chord()
	_test_replay_and_spawn()
	return finish("movement-checkpoint1")


func _state() -> PlayerState:
	var state := PlayerState.new(1)
	state.position_x = 5_000_000
	state.position_y = 5_000_000
	return state


func _step(state: PlayerState, direction: Vector2i = Vector2i.ZERO, held: int = 0, pressed: int = 0, world: CollisionWorld = null) -> void:
	MovementSystem.step(state, SimCommand.new(0, 1, direction.x, direction.y, held, pressed), config, arena if world == null else world)
	check(state.air_height >= 0 and state.air_height <= MovementTuning.AIR_MAX_HEIGHT, "height remains bounded")
	check(state.air_vertical_velocity >= -MovementTuning.AIR_TERMINAL_FALL_SPEED and state.air_vertical_velocity <= MovementTuning.CHARGED_JUMP_VERTICAL_SPEED, "vertical velocity remains bounded")
	check(state.stamina >= 0 and state.stamina <= state.stamina_maximum, "stamina remains bounded")


func _test_release_jump_and_charge() -> void:
	for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		var state := _state()
		state.velocity_x = direction.x * 500
		state.velocity_y = direction.y * 500
		_step(state, direction, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
		check(state.jumpsquat_active and not state.is_airborne(), "held press anticipates on ground")
		check(not MovementSystem.avoids_ordinary_projectiles(state), "jumpsquat does not duck projectiles")
		for _index: int in range(40):
			_step(state, Vector2i.ZERO, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
		equal(state.jumpsquat_ticks, config.milliseconds_to_ticks(MovementTuning.JUMPSQUAT_CHARGE_MS), "charge and key repeats are bounded")
		var charged_carry := Vector2i(state.velocity_x, state.velocity_y)
		check(charged_carry.length() > 290_000 and charged_carry.length() < 300_000, "full preparation gradually lowers earned speed instead of planting")
		_step(state)
		check(state.is_airborne() and not state.jumpsquat_active, "release launches")
		equal(Vector2i(state.velocity_x, state.velocity_y), charged_carry, "neutral charged release carries only the remaining momentum")
		check(not MovementSystem.is_combat_intangible(state, config), "jump has no blanket invulnerability")
		check(not MovementSystem.avoids_ground_effects(state), "first takeoff tick remains in ground-contact band")
		var charged_apex := state.air_height
		for _index: int in range(65):
			_step(state)
			charged_apex = maxi(charged_apex, state.air_height)
		check(charged_apex > 58_000 and charged_apex < 62_000, "charged apex is about sixty pixels")
		var tap := _state()
		_step(tap, direction, 0, SimCommand.PRESSED_JUMP)
		check(tap.is_airborne() and not tap.jumpsquat_active, "same-command tap press/release launches")
		var tap_apex := tap.air_height
		for _index: int in range(50):
			_step(tap)
			tap_apex = maxi(tap_apex, tap.air_height)
		check(tap_apex > 45_000 and tap_apex < 49_000, "tap arc is longer than old thirty-pixel jump")
		check(tap_apex < charged_apex, "bounded held anticipation buys a visibly higher arc")
		var coasting_tap := _state()
		coasting_tap.velocity_x = direction.x * 500
		coasting_tap.velocity_y = direction.y * 500
		var carried := Vector2i(coasting_tap.velocity_x, coasting_tap.velocity_y)
		_step(coasting_tap, Vector2i.ZERO, 0, SimCommand.PRESSED_JUMP)
		check(coasting_tap.is_airborne(), "complete neutral tap launches without a held preparation tick")
		equal(Vector2i(coasting_tap.velocity_x, coasting_tap.velocity_y), carried, "complete tap preserves earned momentum in all eight directions")


func _check_gathered(state: PlayerState, previous: Vector2i, drag: int = 5000) -> void:
	var remaining := Vector2i(state.velocity_x, state.velocity_y)
	check(remaining.length() <= previous.length(), "held preparation never creates speed")
	check(remaining.length() >= maxf(0.0, previous.length() - drag - 2), "held preparation cannot remove more than one bounded drag tick")
	if previous.length() > drag:
		check(remaining.length() > 0 and remaining.x * previous.x + remaining.y * previous.y > 0, "gather keeps actual travel rather than stopping or reversing it")
		check(absf(Vector2(remaining).cross(Vector2(previous))) <= previous.length() * 2, "neutral/opposed/perpendicular input cannot redirect gathering momentum")
	for field: StringName in [&"air_velocity_x", &"air_velocity_y", &"hop_speed", &"movement_action_speed"]:
		equal(state.get(field), 0, "gather clears inactive impulse store " + String(field))
	check(state.jumpsquat_active and not state.is_airborne() and not state.sprinting, "held preparation stays grounded without sprinting")


func _gather_catalog() -> ChampionCatalog:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "momentum matrix loads actual ability content")
	var catalog := ChampionCatalog.new()
	check(catalog.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "momentum matrix loads actual champion profiles")
	return catalog


func _gather_profiles(catalog: ChampionCatalog) -> Array[String]:
	var selected: Dictionary = {}
	for champion_id: String in catalog.ordered_champion_ids():
		var body := String(catalog.champions_by_id[champion_id]["body_type"])
		if not selected.has(body): selected[body] = champion_id
	equal(selected.size(), 3, "gather matrix covers actual small, middle and large profiles")
	var result: Array[String] = []
	for body: String in ["small", "middle", "large"]:
		if selected.has(body): result.append(String(selected[body]))
	return result


func _test_gathered_jump_inputs() -> void:
	var catalog := _gather_catalog()
	for champion_id: String in _gather_profiles(catalog):
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			for input: Vector2i in [Vector2i.ZERO, direction, -direction, Vector2i(-direction.y, direction.x)]:
				var state := _state()
				check(catalog.apply_to_player(state, champion_id), "gather applies actual profile")
				state.velocity_x = direction.x * 500
				state.velocity_y = direction.y * 500
				state.air_velocity_x = -210_000
				state.air_velocity_y = 170_000
				state.position_remainder_x = 119
				state.position_remainder_y = -119
				state.hop_speed = 500_000
				state.movement_action_speed = 840_000
				state.aim_x = -direction.y
				state.aim_y = direction.x
				var radius := state.radius
				var anchor := Vector2i(state.position_x, state.position_y)
				var stamina := state.stamina
				for tick: int in range(41):
					var previous := Vector2i(state.velocity_x, state.velocity_y)
					MovementSystem.step(state, SimCommand.new(tick, 1, input.x, input.y, SimCommand.HELD_JUMP | SimCommand.HELD_SPRINT, SimCommand.PRESSED_JUMP, -direction.y, direction.x), config, arena)
					_check_gathered(state, previous)
					if tick == 0:
						check(Vector2i(state.position_x, state.position_y) != anchor, "first held preparation tick preserves visible travel")
					equal(state.radius, radius, "gather preserves the actual profile hurt radius")
					equal(Vector2i(state.aim_x, state.aim_y), Vector2i(-direction.y, direction.x), "gather travel cannot turn independent aim")
				var carried := Vector2i(state.velocity_x, state.velocity_y)
				equal(state.jumpsquat_ticks, config.milliseconds_to_ticks(MovementTuning.JUMPSQUAT_CHARGE_MS), "all-direction held preparation caps at 300 ms")
				equal(state.stamina, stamina, "held movement and Sprint cannot drain or boost gathering")
				_step(state, input)
				check(state.is_airborne(), "directed charged release still launches")
				var velocity := Vector2i(state.velocity_x, state.velocity_y)
				var steering_step := config.per_tick(MovementTuning.ACCELERATION * MovementTuning.COUNTER_STRAFE_MULTIPLIER / 1000)
				check((velocity - carried).length() <= steering_step + 2, "release changes inherited travel by at most one normal counter-strafe tick")
				if input == Vector2i.ZERO:
					equal(velocity, carried, "neutral release inherits the exact remaining vector")
				if input == -direction:
					check(velocity.x * carried.x + velocity.y * carried.y > 0 and velocity.length() < carried.length(), "opposed release brakes inherited travel before reversing")


func _test_paid_sprint_gather_profiles() -> void:
	var catalog := _gather_catalog()
	for champion_id: String in _gather_profiles(catalog):
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			var state := _state()
			check(catalog.apply_to_player(state, champion_id), "sprint gather uses actual size speed and resource profile")
			var initial_stamina := state.stamina
			for _tick: int in range(45):
				_step(state, direction, SimCommand.HELD_SPRINT)
			check(state.sprinting and state.stamina < initial_stamina, "gather route earns incoming speed through actual paid sprint")
			var paid := state.stamina
			var incoming := Vector2i(state.velocity_x, state.velocity_y)
			for tick: int in range(12):
				var previous := Vector2i(state.velocity_x, state.velocity_y)
				_step(state, direction, SimCommand.HELD_JUMP | SimCommand.HELD_SPRINT, SimCommand.PRESSED_JUMP if tick == 0 else 0)
				_check_gathered(state, previous)
			var carried := Vector2i(state.velocity_x, state.velocity_y)
			check(carried.length() > incoming.length() - 60_010 and carried.length() < incoming.length() - 59_900, "one hundred milliseconds of gathering loses about sixty pixels per second in every heading")
			equal(state.stamina, paid, "gathering stops sprint payment without refund or extra boost")
			var cost := MovementSystem._movement_action_cost(state, MovementTuning.HOP_COST)
			_step(state)
			equal(state.stamina, paid - cost, "sprint gather release pays its actual profile jump price exactly once")
			equal(Vector2i(state.velocity_x, state.velocity_y), carried, "real sprint route carries its actual remaining momentum on neutral release")


func _test_slide_charge_momentum() -> void:
	for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		var state := _state()
		state.velocity_x = direction.x * 840
		state.velocity_y = direction.y * 840
		_step(state, direction, SimCommand.HELD_SLIDE, SimCommand.PRESSED_SLIDE)
		for _tick: int in range(5):
			_step(state, direction, SimCommand.HELD_SLIDE)
		check(Vector2i(state.velocity_x, state.velocity_y).length() > 750_000, "standalone Slide retains earned momentum minus friction")
		var anchor := Vector2i(state.position_x, state.position_y)
		var cooldown := state.slide_cooldown_ticks
		var stamina := state.stamina
		var chain := state.movement_chain_count
		var previous := Vector2i(state.velocity_x, state.velocity_y)
		_step(state, direction, SimCommand.HELD_SLIDE | SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
		_check_gathered(state, previous)
		check(Vector2i(state.position_x, state.position_y) != anchor, "Slide to gather keeps earned travel on admission")
		equal(state.movement_chain_count, chain, "preparation admission preserves the existing paid chain")
		for _tick: int in range(40):
			previous = Vector2i(state.velocity_x, state.velocity_y)
			_step(state, direction, SimCommand.HELD_SLIDE | SimCommand.HELD_JUMP)
			_check_gathered(state, previous)
		equal(state.slide_ticks, 0, "held preparation ends the former slide timer")
		equal(state.slide_cooldown_ticks, maxi(0, cooldown - 41), "preparation neither clears nor refreshes paid Slide cooldown")
		equal(state.stamina, stamina, "held preparation stops optional Slide sustain without a refund")
		equal(state.movement_chain_count, 0, "held preparation does not extend the naturally expiring chain premium")
		check(state.jumpsquat_active and not MovementSystem.is_low_profile(state), "charging slidejump is vulnerable grounded anticipation")
		var cost := MovementSystem._movement_action_cost(state, MovementTuning.SLIDE_JUMP_COST)
		var carried := Vector2i(state.velocity_x, state.velocity_y)
		_step(state)
		equal(state.hop_mode, PlayerState.MovementMode.SLIDE_JUMP, "release preserves the paid slidejump family after gathering")
		equal(state.stamina, stamina - cost, "gathered slidejump pays its unchanged current price once")
		equal(Vector2i(state.velocity_x, state.velocity_y), carried, "neutral charged slidejump carries only its remaining live momentum")
		check(state.is_airborne(), "charged slidejump launches normally")


func _test_gathered_action_exits() -> void:
	for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		for action: int in [SimCommand.PRESSED_SLIDE, SimCommand.PRESSED_EVADE]:
			for exit_kind: String in ["cancel", "unfunded", "release"]:
				var state := _state()
				state.stamina_recovery_per_second = 0
				state.velocity_x = direction.x * 840
				state.velocity_y = direction.y * 840
				_step(state, direction, 0, action)
				for _tick: int in range(state.movement_commitment_ticks):
					_step(state)
				check(state.slide_ticks > 0 or state.is_rolling(), "fixture retains a real paid ground action after commitment")
				var previous := Vector2i(state.velocity_x, state.velocity_y)
				var cooldown := state.slide_cooldown_ticks if action == SimCommand.PRESSED_SLIDE else state.air_dodge_cooldown_ticks
				_step(state, -direction, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
				_check_gathered(state, previous)
				equal(state.slide_ticks + state.air_dodge_ticks, 0, "held preparation ends prior Slide/Roll rather than pausing its impulse")
				check(not MovementSystem.is_combat_intangible(state, config), "gathering cannot preserve roll protection")
				equal(state.slide_cooldown_ticks if action == SimCommand.PRESSED_SLIDE else state.air_dodge_cooldown_ticks, cooldown - 1, "gathering keeps the previous action's spent cooldown")
				if exit_kind == "unfunded": state.stamina = 0
				var before := state.stamina
				previous = Vector2i(state.velocity_x, state.velocity_y)
				_step(state, Vector2i.ZERO, 0, SimCommand.PRESSED_CANCEL_MOVEMENT if exit_kind == "cancel" else 0)
				equal(state.is_airborne(), exit_kind == "release", "only funded uncancelled preparation releases a jump")
				if exit_kind != "release": equal(state.stamina, before, "cancel/refusal neither charges nor refunds")
				check(Vector2i(state.velocity_x, state.velocity_y).length() > 0, "cancel/refusal/release retains legal live momentum")
				previous = Vector2i(state.velocity_x, state.velocity_y)
				var exit_ticks := 40
				if exit_kind != "release":
					# Excess ground carry uses its gentler drag until the ordinary
					# walk floor, then the normal release brake. Derive a finite
					# deadline from both rates, with two ticks for integer diagonal
					# normalization and the rate transition; never wait unboundedly.
					var floor_speed := MovementTuning.BASE_SPEED * state.movement_speed_ratio / 1000.0
					var excess_speed := maxf(0.0, previous.length() - floor_speed)
					var ordinary_speed := minf(previous.length(), floor_speed)
					exit_ticks = ceili(excess_speed / config.per_tick(MovementTuning.GROUND_CARRY_DRAG_PER_SECOND)) + ceili(ordinary_speed / config.per_tick(MovementTuning.DECELERATION)) + 2
				for _tick: int in range(exit_ticks):
					_step(state)
					var remaining := Vector2i(state.velocity_x, state.velocity_y)
					check(remaining.length() <= previous.length(), "exit cannot resurrect old ground-action speed")
					previous = remaining
					check(not state.jumpsquat_active and state.slide_ticks == 0 and state.air_dodge_ticks == 0, "exited preparation leaves no latent action")
				if exit_kind != "release":
					equal(previous, Vector2i.ZERO, "cancel/refusal returns to ordinary finite ground braking")


func _test_gather_wall_contacts() -> void:
	for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		var state := _state()
		state.velocity_x = direction.x * 840
		state.velocity_y = direction.y * 840
		_step(state, Vector2i.ZERO, SimCommand.HELD_SLIDE, SimCommand.PRESSED_SLIDE)
		for _tick: int in range(state.movement_commitment_ticks):
			_step(state, Vector2i.ZERO, SimCommand.HELD_SLIDE)
		var collision := CollisionWorld.new(10_000_000, 10_000_000)
		var normal := Vector2i(signi(direction.x), 0) if direction.x != 0 else Vector2i(0, signi(direction.y))
		var center := Vector2i(state.position_x, state.position_y) + normal * (MovementTuning.PLAYER_RADIUS + 2000)
		var extent := Vector2i(1000, 100_000) if normal.x != 0 else Vector2i(100_000, 1000)
		collision.add_obstacle(CollisionWorld.Obstacle.new(71, center.x - extent.x, center.y - extent.y, center.x + extent.x, center.y + extent.y))
		_step(state, Vector2i.ZERO, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP, collision)
		check(state.jumpsquat_active and not state.is_airborne(), "actual gather collision preserves held release intent")
		equal(state.velocity_x * normal.x + state.velocity_y * normal.y, 0, "real wall clips gathering normal velocity")
		check(collision.can_occupy(Vector2i(state.position_x, state.position_y), MovementTuning.PLAYER_RADIUS), "gather cannot penetrate the normal eighteen-pixel wall clearance")
		if direction.x != 0 and direction.y != 0:
			check(state.velocity_y != 0, "diagonal gather contact retains legal tangent travel")
		equal(state.hop_mode, PlayerState.MovementMode.HOP, "collision retires Slide family without canceling preparation")
		for _tick: int in range(3):
			_step(state, -direction, SimCommand.HELD_JUMP, 0, collision)
			equal(state.velocity_x * normal.x + state.velocity_y * normal.y, 0, "held opposing input cannot resurrect blocked Slide impulse")
		var carried := Vector2i(state.velocity_x, state.velocity_y)
		_step(state, Vector2i.ZERO, 0, 0, collision)
		check(state.is_airborne(), "wall-clipped gather can legally release its paid hop")
		equal(Vector2i(state.velocity_x, state.velocity_y), carried, "wall release inherits only legal tangent or zero velocity")


func _test_gather_field_modifiers() -> void:
	for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		for slow: int in [250, 700, 1000]:
			for braking: int in [700, 1000]:
				var state := _state()
				state.velocity_x = direction.x * 500
				state.velocity_y = direction.y * 500
				if slow != 1000:
					check(MovementSystem.apply_control_state(state, PlayerState.ControlState.SLOWED, 2000, Vector2i.ZERO, 0, config, slow), "gather accepts the existing hostile slow")
				var drag := config.per_tick(MovementTuning.JUMPSQUAT_DRAG_PER_SECOND * slow / 1000 * braking / 1000)
				for tick: int in range(16):
					var previous := Vector2i(state.velocity_x, state.velocity_y)
					MovementSystem.step(state, SimCommand.new(tick, 1, direction.x, direction.y, SimCommand.HELD_JUMP | SimCommand.HELD_SPRINT, SimCommand.PRESSED_JUMP if tick == 0 else 0), config, arena, 1250, 700, braking)
					_check_gathered(state, previous, drag)
					check(previous.length() - Vector2i(state.velocity_x, state.velocity_y).length() >= drag - 8, "ground braking and hostile slow scale only the bounded gather drag")
				var remaining := Vector2i(state.velocity_x, state.velocity_y)
				_step(state)
				check((Vector2i(state.velocity_x, state.velocity_y) - remaining).length() <= 2, "release retains hostile slow exactly once rather than restoring lost speed")
	var resting := _state()
	for tick: int in range(160):
		MovementSystem.step(resting, SimCommand.new(tick, 1, 1000, 0, SimCommand.HELD_JUMP | SimCommand.HELD_SPRINT, SimCommand.PRESSED_JUMP if tick == 0 else 0), config, arena, 1250)
		equal(Vector2i(resting.velocity_x, resting.velocity_y), Vector2i.ZERO, "gathering from rest cannot exploit a speed lane or sprint for free acceleration")
	var stopping := _state()
	stopping.velocity_x = 500_000
	for tick: int in range(110):
		_step(stopping, Vector2i(1000, 0), SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP if tick == 0 else 0)
		equal(stopping.velocity_x, maxi(0, 500_000 - (tick + 1) * 5000), "long hold reaches exact finite rest without negative speed or repeated charge acceleration")


func _test_gather_prediction_replay() -> void:
	var catalog := _gather_catalog()
	for champion_id: String in _gather_profiles(catalog):
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			for from_slide: bool in [false, true]:
				var authority := _state()
				check(catalog.apply_to_player(authority, champion_id), "gather prediction applies actual profile")
				authority.entity_id = 2
				authority.velocity_x = direction.x * 700
				authority.velocity_y = direction.y * 700
				var prediction := ClientPrediction.new()
				check(prediction.configure(config, arena, 2), "gather prediction uses unchanged state schema")
				check(prediction.reconcile(ClientPrediction.capture_packet(authority, 0, -1)), "gather prediction starts from earned momentum")
				var packets: Array[Dictionary] = []
				for tick: int in range(30):
					var held := SimCommand.HELD_SLIDE if from_slide and tick < 6 else SimCommand.HELD_JUMP if tick < 20 else 0
					var pressed := SimCommand.PRESSED_SLIDE if from_slide and tick == 0 else SimCommand.PRESSED_JUMP if tick == (6 if from_slide else 0) else 0
					var command := SimCommand.new(tick, 2, 0, 0, held, pressed, -direction.y, direction.x)
					check(prediction.queue_input(tick + 1, command), "earned gather route enters prediction")
					authority.aim_x = command.aim_x
					authority.aim_y = command.aim_y
					PlayerResourcesSystem.step(authority, config)
					MovementSystem.step(authority, command, config, arena)
					var packet := ClientPrediction.capture_packet(authority, tick + 1, tick + 1)
					packets.append(packet)
					check(ClientPrediction.validate_packet(packet), "moving preparation fits strict unchanged prediction fields")
					equal(ClientPrediction.capture_packet(prediction.predicted_state, tick + 1, tick + 1).values, packet.values, "gather authority and prediction agree on every movement scalar")
					if tick == 24:
						check(prediction.reconcile(packets[12], authority.last_event), "delayed mid-gather acknowledgement replays the paid release")
						equal(ClientPrediction.capture_packet(prediction.predicted_state, tick + 1, tick + 1).values, packet.values, "delayed gather replay preserves exact residual motion and paid budgets")
				check(prediction.reconcile(packets.back(), authority.last_event), "final gather acknowledgement completes")
				equal(prediction.pending_count(), 0, "gather replay leaves no pending input")


func _test_jumpsquat_external_displacement() -> void:
	for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		for control: int in [PlayerState.ControlState.LAUNCHED, PlayerState.ControlState.GRAPPLED, PlayerState.ControlState.CHARGING]:
			var state := _state()
			_step(state, Vector2i.ZERO, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
			var anchor := Vector2i(state.position_x, state.position_y)
			check(MovementSystem.apply_control_state(state, control, 200, direction, 400_000, config), "forced-control fixture applies")
			_step(state, Vector2i.ZERO, SimCommand.HELD_JUMP)
			check(not state.jumpsquat_active and Vector2i(state.position_x, state.position_y) != anchor, "forced control cancels gathering and still displaces the actor")
		var flowing := _state()
		var chemistry := HexChemistryWorld.new()
		var events: Array = []
		_step(flowing, Vector2i.ZERO, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
		var origin := Vector2i(flowing.position_x, flowing.position_y)
		HexProductEffects._apply_ground_push(chemistry, 1, {"flow_aim": direction, "flow_speed": 120_000}, flowing, HexProductEffects.MISTCURRENT, config, arena, events)
		var pushed := Vector2i(flowing.position_x, flowing.position_y)
		check(pushed != origin and not events.is_empty(), "external field flow still moves an actively gathering actor")
		_step(flowing, direction, SimCommand.HELD_JUMP)
		_check_gathered(flowing, Vector2i.ZERO)
		equal(Vector2i(flowing.position_x, flowing.position_y), pushed, "gathering cannot undo external displacement or create self-motion from rest")


func _test_air_budget_and_flight() -> void:
	var state := _state()
	_step(state, Vector2i.ZERO, 0, SimCommand.PRESSED_JUMP)
	for _index: int in range(12):
		_step(state)
	_step(state, Vector2i.ZERO, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
	check(state.double_jump_used and not state.air_floating, "nonflier receives real second lift")
	equal(state.hop_mode, PlayerState.MovementMode.DOUBLE_JUMP, "second lift has explicit animation mode")
	for _index: int in range(11):
		_step(state, Vector2i.ZERO, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
	var before := state.air_vertical_velocity
	_step(state)
	_step(state, Vector2i.ZERO, 0, SimCommand.PRESSED_JUMP)
	check(state.air_vertical_velocity < before, "third tap cannot refresh second-jump budget")
	for _index: int in range(100):
		_step(state)
	check(not state.is_airborne() and not state.double_jump_used, "only landing restores second jump")
	for duration: int in [MovementTuning.FLOAT_SMALL_DURATION_MS, MovementTuning.FLOAT_MIDDLE_DURATION_MS, MovementTuning.FLOAT_LARGE_DURATION_MS]:
		var flier := _state()
		flier.flight_capable = true
		flier.float_max_duration_ms = duration
		_step(flier, Vector2i.ZERO, 0, SimCommand.PRESSED_JUMP)
		for _index: int in range(12):
			_step(flier)
		_step(flier, Vector2i.ZERO, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
		check(flier.air_floating and flier.float_used and not flier.double_jump_used, "capability selects flight instead of second jump")
		check(not MovementSystem.is_combat_intangible(flier, config), "flight is height avoidance, not invulnerability")
		var height := flier.air_height
		for _index: int in range(20):
			_step(flier, Vector2i(1000, 0), SimCommand.HELD_JUMP)
		equal(flier.air_height, height, "held flight maintains clearance")
		check(flier.position_x > 5_000_000, "flight steers horizontally")
		for _index: int in range(config.milliseconds_to_ticks(duration)):
			_step(flier, Vector2i.ZERO, SimCommand.HELD_JUMP)
		check(not flier.air_floating, "held flight expires on its finite clock")
		check(not flier.double_jump_used, "flight exhaustion never buys a double jump")
	var switched := _state()
	switched.flight_capable = true
	switched.air_height = 40_000
	switched.hop_ticks = MovementSystem._remaining_air_ticks(switched, config)
	_step(switched, Vector2i.ZERO, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
	check(switched.air_floating, "flight-capability fixture starts flight")
	switched.flight_capable = false
	_step(switched, Vector2i.ZERO, SimCommand.HELD_JUMP)
	check(not switched.air_floating and switched.float_used, "capability loss ends flight without refunding its budget")


func _test_height_matrix() -> void:
	var state := _state()
	for height: int in [0, 17_999, 18_000, 60_000]:
		state.air_height = height
		equal(MovementSystem.avoids_ground_effects(state), height >= 18_000, "ground effects use actual clearance")
		equal(MovementSystem.avoids_ordinary_projectiles(state), height >= 18_000, "ordinary projectile plane uses same clearance")
	state.wall_skim_ticks = 20
	check(not MovementSystem.avoids_ground_effects(state) and not MovementSystem.avoids_ordinary_projectiles(state), "wallrun remains exposed even when drawn high")
	state.wall_skim_ticks = 0
	state.air_height = 0
	state.slide_ticks = 20
	check(MovementSystem.avoids_ordinary_projectiles(state) and not MovementSystem.avoids_ground_effects(state), "slide ducks shots but touches ground hazards")
	check(not MovementSystem.is_combat_intangible(state, config), "slide never gives blanket immunity")
	state.slide_ticks = 0
	state.crouching = true
	check(MovementSystem.is_low_profile(state), "crouch shares low exposure profile")
	state.jumpsquat_active = true
	check(not MovementSystem.is_low_profile(state), "anticipation overrides low profile")


func _test_wall_hold_release() -> void:
	var world := CollisionWorld.new(10_000_000, 10_000_000)
	world.add_obstacle(CollisionWorld.Obstacle.new(7, 5_020_000, 4_000_000, 5_048_000, 6_000_000))
	var state := _state()
	_step(state, Vector2i.ZERO, 0, SimCommand.PRESSED_JUMP, world)
	for _index: int in range(12):
		_step(state, Vector2i.ZERO, 0, 0, world)
	_step(state, Vector2i(0, 1000), SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP, world)
	check(state.wall_skim_ticks > 0 and not state.double_jump_used, "eligible wall hold wins over second jump")
	check(not state.wallrun_armed, "attachment consumes held-key arm")
	_step(state, Vector2i(0, 1000), 0, 0, world)
	equal(state.hop_mode, PlayerState.MovementMode.WALL_KICK, "wall release launches walljump")
	check(state.velocity_x < 0 and state.velocity_y > 0, "walljump preserves requested tangent and legal outward component")
	check(not state.double_jump_used, "walljump does not consume or refill double-jump budget")
	for tangent_y: int in [-1000, 1000]:
		var neutral := _state()
		neutral.air_height = 40_000
		neutral.hop_ticks = MovementSystem._remaining_air_ticks(neutral, config)
		_step(neutral, Vector2i(0, tangent_y), SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP, world)
		check(neutral.wall_skim_ticks > 0 and neutral.facing_y == tangent_y, "neutral-release fixture first establishes actual tangential run and facing")
		neutral.aim_x = 0
		neutral.aim_y = -tangent_y
		var neutral_release := SimCommand.new(0, 1, 0, 0, 0, 0, 0, -tangent_y)
		MovementSystem.step(neutral, neutral_release, config, world)
		equal(neutral.hop_mode, PlayerState.MovementMode.WALL_KICK, "neutral release still admits paid walljump")
		check(neutral.velocity_x < 0 and neutral.velocity_y == 0, "neutral walljump is pure outward normal despite prior tangent and opposite cursor")
		equal(Vector2i(neutral.hop_x, neutral.hop_y), Vector2i(-1000, 0), "neutral release cannot inherit either facing or aiming tangent")
	var removed := _state()
	removed.air_height = 40_000
	removed.wall_skim_ticks = 30
	removed.wall_skim_surface_id = 999
	removed.jump_held_last_tick = true
	_step(removed, Vector2i.ZERO, 0, 0, world)
	check(removed.hop_mode != PlayerState.MovementMode.WALL_KICK, "deleted wall cannot grant release impulse")


func _test_cancel_and_crouch() -> void:
	var state := _state()
	_step(state, Vector2i.ZERO, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
	_step(state, Vector2i.ZERO, 0, SimCommand.PRESSED_CANCEL_MOVEMENT)
	check(not state.is_airborne() and not state.jumpsquat_active, "focus/modal cancellation is not jump release")
	_step(state, Vector2i.ZERO, SimCommand.HELD_SLIDE, SimCommand.PRESSED_SLIDE)
	check(state.crouching and MovementSystem.is_low_profile(state), "stationary C crouches without a slide impulse")
	for _index: int in range(60):
		_step(state, Vector2i(1000, 0), SimCommand.HELD_SLIDE | SimCommand.HELD_SPRINT)
	equal(state.velocity_x, MovementTuning.BASE_SPEED * MovementTuning.CROUCH_SPEED_RATIO / 1000, "crouch travel is bounded and cannot sprint")
	_step(state)
	check(not state.crouching, "release restores ordinary exposure")
	_step(state, Vector2i.ZERO, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
	MovementSystem.apply_control_state(state, PlayerState.ControlState.STUNNED, 100, Vector2i.ZERO, 0, config)
	_step(state)
	check(not state.is_airborne() and not state.jumpsquat_active, "hard control cancels anticipation")


func _test_replay_and_spawn() -> void:
	var a := _state()
	var b := _state()
	for tick: int in range(120):
		var held := SimCommand.HELD_JUMP if tick < 15 or (tick >= 30 and tick < 45) else 0
		var pressed := SimCommand.PRESSED_JUMP if tick in [0, 30] else 0
		_step(a, Vector2i(707, 707), held, pressed)
		_step(b, Vector2i(707, 707), held, pressed)
		equal(a.canonical_values(), b.canonical_values(), "replayed height/input state is deterministic")
	a.flight_capable = true
	a.double_jump_used = true
	a.jumpsquat_active = true
	a.jumpsquat_ticks = 20
	a.crouching = true
	a.reset_for_spawn(Vector2i(5_000_000, 5_000_000))
	check(a.flight_capable and not a.double_jump_used and not a.jumpsquat_active and not a.crouching and a.jumpsquat_ticks == 0, "spawn preserves catalog capability and clears transient budgets")


func _test_action_chords() -> void:
	var state := _state()
	_step(state, Vector2i.ZERO, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
	_step(state, Vector2i(1000, 0), SimCommand.HELD_JUMP, SimCommand.PRESSED_EVADE | SimCommand.PRESSED_JUMP)
	check(state.is_rolling() and not state.jumpsquat_active, "evade cancels rather than retaining squat in a chord")
	_step(state)
	check(not state.is_airborne(), "release after cancelled anticipation does not jump out of roll")
	var flier := _state()
	flier.flight_capable = true
	_step(flier, Vector2i.ZERO, 0, SimCommand.PRESSED_JUMP)
	for _index: int in range(12):
		_step(flier)
	_step(flier, Vector2i(1000, 0), SimCommand.HELD_JUMP, SimCommand.PRESSED_EVADE | SimCommand.PRESSED_JUMP)
	check(flier.air_dodge_used and not flier.float_used, "explicit air dodge owns chord before automatic flight")
	var wall := _state()
	wall.air_height = 40_000
	wall.wall_skim_ticks = 30
	wall.wall_skim_surface_id = 7
	wall.wall_contact_id = 7
	wall.wall_x = -1000
	wall.wall_skim_y = 1000
	wall.jump_held_last_tick = true
	var world := CollisionWorld.new(10_000_000, 10_000_000)
	world.add_obstacle(CollisionWorld.Obstacle.new(7, 5_020_000, 4_000_000, 5_048_000, 6_000_000))
	_step(wall, Vector2i(0, 1000), SimCommand.HELD_SLIDE, SimCommand.PRESSED_SLIDE, world)
	check(wall.wall_skim_ticks == 0 and wall.fast_falling, "fresh C detaches wallrun into fast-fall without walljump")


func _air_chord_state(direction: Vector2i) -> PlayerState:
	var state := _state()
	state.air_height = 40_000
	state.air_vertical_velocity = 100_000
	state.hop_ticks = MovementSystem._remaining_air_ticks(state, config)
	state.hop_stage = 1
	state.air_redirects_remaining = 1
	state.air_velocity_x = -direction.y * 400
	state.air_velocity_y = direction.x * 400
	state.velocity_x = state.air_velocity_x
	state.velocity_y = state.air_velocity_y
	state.hop_speed = 400_000
	return state


func _test_air_slide_technique_chord() -> void:
	for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		for held: int in [0, SimCommand.HELD_SLIDE]:
			var slide := _air_chord_state(direction)
			var chord := _air_chord_state(direction)
			var technique := _air_chord_state(direction)
			var stamina_before := chord.stamina
			_step(slide, direction, held, SimCommand.PRESSED_SLIDE)
			_step(chord, direction, held, SimCommand.PRESSED_SLIDE | SimCommand.PRESSED_TECHNIQUE)
			_step(technique, direction, 0, SimCommand.PRESSED_TECHNIQUE)
			check(technique.last_event == "air_redirect" and technique.stamina < stamina_before, "Technique-only positive control can buy the perpendicular air turn")
			check(chord.fast_falling and chord.last_event == "fast_fall", "Slide wins the airborne Technique chord and immediately fast-falls")
			equal(chord.stamina, stamina_before, "airborne Slide chord cannot buy the discarded Technique")
			equal(chord.air_redirects_remaining, 1, "discarded Technique preserves the finite redirect opportunity")
			equal(chord.movement_chain_count, 0, "free Slide chord adds no paid chain premium")
			equal(chord.technique_buffer_ticks, 0, "discarded Technique cannot wait as a latent paid action")
			equal(chord.canonical_values(), slide.canonical_values(), "Slide chord exactly matches standalone Slide authority")
			for _tick: int in range(config.milliseconds_to_ticks(MovementTuning.INPUT_BUFFER_MS) + 1):
				_step(slide, direction, held)
				_step(chord, direction, held)
				equal(chord.canonical_values(), slide.canonical_values(), "discarded Technique never returns during or after the buffer window")


func _test_wall_slide_technique_chord() -> void:
	var world := CollisionWorld.new(10_000_000, 10_000_000)
	world.add_obstacle(CollisionWorld.Obstacle.new(7, 5_020_000, 4_000_000, 5_048_000, 6_000_000))
	var direction := Vector2i(0, 1000)
	for attached: bool in [false, true]:
		var slide := _air_chord_state(direction)
		var chord := _air_chord_state(direction)
		var technique := _air_chord_state(direction)
		if attached:
			for state: PlayerState in [slide, chord, technique]:
				_step(state, direction, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP, world)
				check(state.wall_skim_ticks > 0, "wall chord fixture enters a real paid wallrun")
		var stamina_before := chord.stamina
		_step(slide, direction, SimCommand.HELD_SLIDE, SimCommand.PRESSED_SLIDE, world)
		_step(chord, direction, SimCommand.HELD_SLIDE, SimCommand.PRESSED_SLIDE | SimCommand.PRESSED_TECHNIQUE, world)
		_step(technique, direction, 0, SimCommand.PRESSED_TECHNIQUE, world)
		if not attached:
			check(technique.wall_skim_ticks > 0 and technique.stamina < stamina_before, "Technique-only positive control can buy the nearby wallrun")
		check(chord.wall_skim_ticks == 0 and chord.fast_falling, "Slide chord fast-falls beside or from a wall without a Technique detour")
		equal(chord.stamina, stamina_before, "wall Slide chord preserves already paid costs without a new spend")
		equal(chord.technique_buffer_ticks, 0, "wall Slide chord discards the lower-priority buffer")
		equal(chord.canonical_values(), slide.canonical_values(), "wall Slide chord matches the standalone finite fast-fall exit")
