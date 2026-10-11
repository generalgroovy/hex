extends FluxTestSuite


var config := SimConfig.new(120)
var arena := CollisionWorld.new(10_000_000, 10_000_000)


func run() -> int:
	equal(MovementTuning.STAMINA_MAXIMUM, 560_000, "default Stamina reserve is exactly five times112000")
	equal(MovementTuning.STAMINA_RECOVERY_PER_SECOND, 27_000, "extra reserve does not silently increase recovery")
	_test_physical_arc_and_float()
	_test_fresh_jump_edge()
	_test_dodge_decay_and_airtime_allowance()
	_test_evade_direction_and_neutral_fast_fall()
	_test_evade_float_wall_and_landing_transitions()
	_test_contact_and_forced_control()
	_test_fast_fall_and_landing_windows()
	_test_landing_readiness()
	_test_replay_and_canonical_reset()
	return finish("movement-height")


func _state() -> PlayerState:
	var state := PlayerState.new(1)
	state.position_x = 5_000_000
	state.position_y = 5_000_000
	return state


func _step(state: PlayerState, move: Vector2i = Vector2i.ZERO, held: int = 0, pressed: int = 0, collision: CollisionWorld = null) -> void:
	MovementSystem.step(state, SimCommand.new(0, 1, move.x, move.y, held, pressed), config, arena if collision == null else collision)
	check(state.air_height >= 0 and state.air_height <= MovementTuning.AIR_MAX_HEIGHT, "physical height stays within shared bounds")
	check(state.air_vertical_velocity >= -MovementTuning.AIR_TERMINAL_FALL_SPEED and state.air_vertical_velocity <= MovementTuning.CHARGED_JUMP_VERTICAL_SPEED, "vertical speed stays bounded")
	check(absi(state.air_height_remainder) < 2 * config.tick_rate, "vertical integration remainder is canonical and bounded")


func _test_physical_arc_and_float() -> void:
	for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		var full := _state()
		var tap := _state()
		var full_apex := 0
		var tap_apex := 0
		var full_land_tick := -1
		var tap_land_tick := -1
		for tick: int in range(100):
			var pressed := SimCommand.PRESSED_JUMP if tick == 0 else 0
			_step(full, direction, SimCommand.HELD_JUMP if tick < 36 else 0, pressed)
			_step(tap, direction, 0, pressed)
			full_apex = maxi(full_apex, full.air_height)
			tap_apex = maxi(tap_apex, tap.air_height)
			if tick > 36 and full.air_height == 0 and full_land_tick < 0:
				full_land_tick = tick + 1
			if tap.air_height == 0 and tap_land_tick < 0:
				tap_land_tick = tick + 1
			if tick == 30:
				check(not MovementSystem.is_combat_intangible(full, config), "high held apex never extends jump protection")
		check(full_apex >= 58_000 and full_apex <= 61_000, "charged release reaches the bounded sixty-pixel apex")
		check(full_land_tick >= 83 and full_land_tick <= 87, "charged release lands after its longer physical arc")
		check(tap_apex >= 45_000 and tap_apex <= 49_000, "tap arc stays readable and clears the eighteen-pixel projectile plane")
		check(tap_land_tick > 0 and tap_land_tick < full_land_tick, "short hop lands before held hop")
		check(full.stamina <= full.stamina_maximum and tap.stamina <= tap.stamina_maximum, "charge is bounded ground anticipation rather than hidden airborne sustain")
		var double := _state()
		double.flight_capable = true
		_step(double, direction, 0, SimCommand.PRESSED_JUMP)
		for _tick: int in range(16):
			_step(double, direction)
		check(double.air_height > 28_000, "first apex remains real shared height")
		_step(double, direction) # A real release before the next fresh press.
		var before_height := double.air_height
		var before_stamina := double.stamina
		_step(double, direction, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
		check(double.float_used, "one fresh second press consumes the independent Float allowance")
		equal(double.air_height, before_height, "Float preserves current height without adding a second lift")
		check(double.stamina < before_stamina, "Float pays its continuation cost and sustain")
		var double_apex := double.air_height
		for _tick: int in range(80):
			_step(double, direction, SimCommand.HELD_JUMP)
			double_apex = maxi(double_apex, double.air_height)
		equal(double_apex, before_height, "held Float never adds height")
		check(double.air_floating, "affordable held Float survives the former fixed jump duration")
		for _tick: int in range(80):
			_step(double, direction)
		check(not double.is_airborne(), "released Float returns to actual ground")
		print("height direction ", direction, " full=", full_apex, " tap=", tap_apex, " full_ticks=", full_land_tick, " tap_ticks=", tap_land_tick, " float=", double_apex)


func _test_fresh_jump_edge() -> void:
	var state := _state()
	_step(state, Vector2i.ZERO, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
	for _index: int in range(20):
		_step(state, Vector2i.ZERO, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
	check(state.jumpsquat_active and not state.is_airborne(), "repeated held-key edges keep anticipation without automatic takeoff")
	_step(state)
	for _index: int in range(config.milliseconds_to_ticks(MovementTuning.HOP_COMMITMENT_MS)):
		_step(state)
	_step(state, Vector2i.ZERO, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
	check(state.double_jump_used and not state.air_floating, "release and fresh press starts nonflier double jump")
	_step(state)
	for _index: int in range(12):
		_step(state, Vector2i.ZERO, 0, SimCommand.PRESSED_JUMP)
	check(state.double_jump_used and not state.air_floating, "third fresh presses cannot rearm double jump or grant flight")


func _test_dodge_decay_and_airtime_allowance() -> void:
	for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		var state := _state()
		state.air_height = 150_000
		state.air_vertical_velocity = 0
		state.hop_ticks = MovementSystem._remaining_air_ticks(state, config)
		state.hop_stage = 1
		var before_height := state.air_height
		_step(state, direction, 0, SimCommand.PRESSED_EVADE)
		check(state.air_dodge_used, "accepted dodge spends exactly one airtime allowance")
		check(state.air_height < before_height and state.air_height > before_height - 1000, "air dodge preserves the ongoing physical descent")
		var initial_speed := MovementSystem._planar_speed(state)
		var previous_speed := initial_speed
		for _index: int in range(10):
			_step(state)
			var speed := MovementSystem._planar_speed(state)
			check(speed < previous_speed, "directional air burst decays each committed tick")
			previous_speed = speed
		check(initial_speed > 850_000 and previous_speed < 680_000, "dodge has a clear burst then readable deceleration")
		for _index: int in range(5):
			_step(state)
		state.air_dodge_cooldown_ticks = 0 # Cooldown expiry cannot reset airtime budget.
		var before_cost := state.stamina
		_step(state, -direction, 0, SimCommand.PRESSED_EVADE)
		equal(state.stamina, before_cost, "repeated air dodge refuses without paying")
		check(state.air_dodge_used, "cooldown changes cannot manufacture a new aerial dodge")
		var before_turn := Vector2i(state.velocity_x, state.velocity_y)
		_step(state, -direction)
		check(Vector2i(state.velocity_x, state.velocity_y) != before_turn, "post-commit descent remains steerable, not helpless")
		state.evade_buffer_ticks = 0
		for _index: int in range(60):
			_step(state)
		check(not state.is_airborne() and not state.air_dodge_used, "only real landing restores the next airtime dodge")


func _test_evade_direction_and_neutral_fast_fall() -> void:
	for radius: int in [17_000, 18_000, 19_000]:
		for vertical_speed: int in [300_000, -300_000]:
			for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
				var directional := _state()
				directional.radius = radius
				directional.air_height = 120_000
				directional.air_vertical_velocity = vertical_speed
				directional.hop_ticks = MovementSystem._remaining_air_ticks(directional, config)
				directional.hop_stage = 1
				var stamina_before := directional.stamina
				_step(directional, direction, 0, SimCommand.PRESSED_EVADE)
				equal(Vector2i(directional.air_dodge_x, directional.air_dodge_y), direction, "size%d vertical%d Q follows each current planar direction" % [radius, vertical_speed])
				check(directional.air_dodge_used and directional.air_dodge_ticks > 0 and not directional.fast_fall_armed, "directional Q buys only the finite air dodge")
				equal(directional.stamina, stamina_before - MovementTuning.AIR_DODGE_COST, "directional Q pays the unchanged air-dodge cost")
	var neutral := _state()
	neutral.air_height = 120_000
	neutral.air_vertical_velocity = 300_000
	neutral.hop_ticks = MovementSystem._remaining_air_ticks(neutral, config)
	neutral.hop_stage = 2
	neutral.air_dodge_used = true
	neutral.stamina = 0
	neutral.facing_x = -1000
	neutral.facing_y = 0
	neutral.aim_x = 0
	neutral.aim_y = -1000
	neutral.air_velocity_x = 420_000
	neutral.air_velocity_y = -170_000
	neutral.velocity_x = neutral.air_velocity_x
	neutral.velocity_y = neutral.air_velocity_y
	var neutral_velocity := Vector2i(neutral.velocity_x, neutral.velocity_y)
	var neutral_stamina := neutral.stamina
	var neutral_chain := neutral.movement_chain_count
	_step(neutral, Vector2i.ZERO, 0, SimCommand.PRESSED_EVADE)
	check(neutral.fast_falling and neutral.fast_fall_armed, "neutral Q fast-falls even with facing, aim, momentum and spent air dodge")
	equal(Vector2i(neutral.velocity_x, neutral.velocity_y), neutral_velocity, "neutral Q adds no planar dodge impulse to existing momentum")
	check(neutral.air_vertical_velocity <= -MovementTuning.AIR_FAST_FALL_SPEED, "neutral Q reuses the bounded vertical fast-fall speed")
	equal(neutral.stamina, neutral_stamina, "neutral Q has zero resource cost")
	equal(neutral.movement_chain_count, neutral_chain, "neutral Q resets no paid movement budget")
	check(not MovementSystem.is_combat_intangible(neutral, config), "neutral Q adds no protection")
	equal(neutral.evade_buffer_ticks, 0, "neutral Q consumes its one buffered edge")
	var refused := _state()
	refused.air_height = 120_000
	refused.air_vertical_velocity = 100_000
	refused.hop_ticks = MovementSystem._remaining_air_ticks(refused, config)
	refused.hop_stage = 1
	refused.stamina = 0
	_step(refused, Vector2i(1000, 0), 0, SimCommand.PRESSED_EVADE)
	check(refused.air_dodge_ticks == 0 and not refused.fast_fall_armed, "directional Q with no Stamina refuses instead of falling back to neutral behavior")
	check(refused.evade_buffer_ticks > 0, "refused directional Q retains only the existing bounded input buffer")


func _test_evade_float_wall_and_landing_transitions() -> void:
	for duration: int in [MovementTuning.FLOAT_SMALL_DURATION_MS, MovementTuning.FLOAT_MIDDLE_DURATION_MS, MovementTuning.FLOAT_LARGE_DURATION_MS]:
		var floating := _state()
		floating.flight_capable = true
		floating.air_height = 90_000
		floating.hop_ticks = MovementSystem._remaining_air_ticks(floating, config)
		floating.air_floating = true
		floating.float_used = true
		floating.float_ticks = config.milliseconds_to_ticks(duration)
		floating.float_max_duration_ms = duration
		floating.air_dodge_used = true
		floating.air_velocity_x = 310_000
		floating.velocity_x = floating.air_velocity_x
		var float_stamina := floating.stamina
		_step(floating, Vector2i.ZERO, SimCommand.HELD_JUMP, SimCommand.PRESSED_EVADE)
		check(not floating.air_floating and floating.float_used and floating.fast_falling, "neutral Q explicitly exits held size-limited Float into fast-fall")
		check(not MovementSystem.is_combat_intangible(floating, config), "Float-to-fast-fall removes protection immediately")
		equal(floating.stamina, float_stamina, "Float-to-fast-fall buys no extra protected or paid tick")
		_step(floating, Vector2i.ZERO, SimCommand.HELD_JUMP)
		check(not floating.air_floating and floating.float_used, "held Jump cannot re-enter spent Float after neutral Q")
	var reaction := ElementReactionState.new()
	reaction.entity_id = 4900
	reaction.recipe_wire_id = 301
	reaction.owner_id = 1
	reaction.team_id = 1
	reaction.position_x = 600_000
	reaction.position_y = 500_000
	reaction.origin_x = reaction.position_x
	reaction.origin_y = reaction.position_y
	reaction.direction_x = 0
	reaction.direction_y = 1000
	reaction.created_tick = 0
	reaction.active_tick = 22
	reaction.decay_tick = 397
	reaction.expiry_tick = 445
	reaction.radius = 22_500
	reaction.length = 80_000
	reaction.health = 32_000
	reaction.source_a = 4901
	reaction.source_b = 4902
	var layer := ReactionMovementWorld.new(CollisionWorld.new(2_000_000, 1_500_000))
	layer.set_surfaces(ReactionMovementWorld.capture_surfaces([reaction], 22), 22)
	var wall := PlayerState.new(2)
	var rampart_bounds := ElementChemistrySystem.rampart_bounds(reaction)
	# One fixed unit outside the inclusive actor tangent selects the ordinary
	# authoritative surface path instead of the intentional overlap escape.
	wall.position_x = rampart_bounds.position.x - MovementTuning.PLAYER_RADIUS - 1
	wall.position_y = 500_000
	wall.air_height = 80_000
	wall.hop_ticks = MovementSystem._remaining_air_ticks(wall, config)
	wall.hop_stage = 1
	wall.wall_skim_ticks = 20
	wall.wall_skim_surface_id = ReactionMovementWorld.SURFACE_ID_BASE + reaction.entity_id
	wall.wall_contact_id = wall.wall_skim_surface_id
	wall.wall_memory_ticks = 20
	wall.wall_x = -1000
	wall.wall_y = 0
	wall.wall_skim_x = 0
	wall.wall_skim_y = 1000
	wall.movement_action_speed = MovementTuning.WALL_SKIM_SPEED
	wall.movement_commitment_ticks = 0
	layer.begin_actor(Vector2i(wall.position_x, wall.position_y), MovementTuning.PLAYER_RADIUS)
	check(layer.has_live_surface(wall.wall_skim_surface_id), "neutral-Q Rampart fixture admits the exact authoritative surface before movement")
	var wall_stamina := wall.stamina
	_step(wall, Vector2i.ZERO, 0, SimCommand.PRESSED_EVADE, layer)
	check(wall.wall_skim_ticks == 0 and wall.fast_falling, "neutral Q uses the ordinary Rampart wall exit before fast-fall")
	equal(wall.stamina, wall_stamina, "Rampart exit and fast-fall add no movement cost")
	check(layer.obstacle_view().size() == 1, "neutral Q never removes or bypasses the authoritative Rampart surface")
	var landing := _state()
	landing.air_height = 1000
	landing.air_vertical_velocity = -300_000
	landing.hop_ticks = MovementSystem._remaining_air_ticks(landing, config)
	landing.hop_stage = 1
	var landing_stamina := landing.stamina
	_step(landing, Vector2i.ZERO, 0, SimCommand.PRESSED_EVADE)
	check(not landing.is_airborne() and not landing.is_rolling(), "last-airborne-tick neutral Q fast-falls into a normal landing, never a roll")
	equal(landing.stamina, landing_stamina, "last-airborne neutral Q lands without an evade charge")
	equal(landing.evade_buffer_ticks, 0, "landing clears the already-consumed neutral Q intent")


func _test_contact_and_forced_control() -> void:
	var collision := CollisionWorld.new(10_000_000, 10_000_000)
	collision.add_obstacle(CollisionWorld.Obstacle.new(7, 5_020_000, 4_000_000, 5_048_000, 6_000_000))
	var state := _state()
	state.position_x = 5_001_000
	state.air_height = 90_000
	state.air_vertical_velocity = 0
	state.hop_ticks = MovementSystem._remaining_air_ticks(state, config)
	state.hop_stage = 2
	state.air_dodge_used = true
	state.air_velocity_x = 500_000
	_step(state, Vector2i(1000, 0), 0, 0, collision)
	check(state.position_x <= 5_020_000 - state.radius, "height does not bypass worldbone collision")
	check(state.air_height > 80_000 and state.air_dodge_used, "horizontal collision never resets height or aerial allowance")
	var before := state.air_height
	_step(state, Vector2i(0, 1000), 0, SimCommand.PRESSED_TECHNIQUE, collision)
	check(state.wall_skim_ticks > 0, "real airborne contact can attach wallrun")
	equal(state.air_height, before, "wall attachment holds the exact current height")
	equal(state.hop_stage, 2, "wall contact cannot restore second jump")
	check(state.air_dodge_used, "wall contact cannot restore air dodge")
	_step(state, Vector2i(-1000, 0), 0, 0, collision)
	check(state.wall_skim_ticks == 0 and state.air_height > 0, "wall detach continues the same finite fall")
	check(state.air_dodge_used, "wall detach retains spent airtime allowance")
	MovementSystem.apply_control_state(state, PlayerState.ControlState.LAUNCHED, 150, Vector2i(-1000, 0), 300_000, config)
	var launch_height := state.air_height
	_step(state, Vector2i.ZERO, SimCommand.HELD_JUMP, 0, collision)
	check(state.air_height > 0 and state.air_height < launch_height, "forced planar launch does not reset the independent vertical trajectory")
	check(state.air_dodge_used, "forced control cannot replenish aerial dodge before landing")
	equal(state.hop_stage, 2, "forced control cannot replenish second jump before landing")


func _test_fast_fall_and_landing_windows() -> void:
	var state := _state()
	_step(state, Vector2i.ZERO, 0, SimCommand.PRESSED_JUMP)
	for _index: int in range(15):
		_step(state, Vector2i.ZERO, SimCommand.HELD_JUMP)
	var height := state.air_height
	_step(state, Vector2i.ZERO, 0, SimCommand.PRESSED_SLIDE)
	check(state.air_height < height and state.air_vertical_velocity <= -MovementTuning.AIR_FAST_FALL_SPEED, "fresh airborne Slide commits actual fast descent")
	for _index: int in range(15):
		_step(state)
	equal(state.air_height, 0, "fast fall finishes at exact floor height")
	check(not state.fast_fall_armed and not state.fast_falling, "actual landing clears fast fall state")
	var low := _state()
	low.air_height = 15_000
	low.air_vertical_velocity = -300_000
	low.hop_ticks = MovementSystem._remaining_air_ticks(low, config)
	low.hop_stage = 1
	_step(low, Vector2i(1000, 0), 0, SimCommand.PRESSED_EVADE)
	check(low.wave_dash_queued and MovementSystem.is_combat_intangible(low, config), "low descending dodge queues landing conversion with truthful opening protection")
	for _index: int in range(15):
		_step(low, Vector2i(1000, 0))
		if low.air_height == 0:
			check(not MovementSystem.is_combat_intangible(low, config), "real ground contact ends dodge protection without landing refresh")
	check(low.wave_dash_ticks > 0, "near-ground directional dodge retains a useful wavedash")
	check(low.velocity_x <= MovementTuning.AIR_DODGE_SPEED, "landing conversion cannot create extra planar energy")


func _test_replay_and_canonical_reset() -> void:
	var first := SimWorld.new(120, 7, arena)
	var repeat := SimWorld.new(120, 7, arena)
	for world: SimWorld in [first, repeat]:
		world.player().position_x = 5_000_000
		world.player().position_y = 5_000_000
	for tick: int in range(160):
		var direction: Vector2i = EightDirectionResolver.FIXED_VECTORS[(tick / 10) % 8]
		var held := SimCommand.HELD_JUMP if tick != 29 and tick < 65 else 0
		var pressed := SimCommand.PRESSED_JUMP if tick == 0 or tick == 30 else SimCommand.PRESSED_EVADE if tick == 44 else SimCommand.PRESSED_SLIDE if tick == 75 else 0
		for world: SimWorld in [first, repeat]:
			check(world.step([SimCommand.new(tick, 1, direction.x, direction.y, held, pressed)]), "physical trajectory replay tick executes")
		equal(first.state_hash(), repeat.state_hash(), "complete canonical hash repeats through lift, double jump, dodge and fast fall")
		var prediction_values := PackedInt64Array()
		for field: StringName in ClientPrediction.STATE_FIELDS:
			prediction_values.append(int(first.player().get(field)))
		# Keep the independent scalar assembly, then include the complete status
		# suffix that production prediction captures after those movement fields.
		prediction_values.append_array(PackedInt64Array(Array(first.player().spell_status_values)))
		prediction_values[0] = 2 # Prediction packets belong to guests, never host entity1.
		equal(prediction_values.size(), ClientPrediction.STATE_FIELDS.size() + 48, "physical replay packet includes all six eight-value status channels")
		check(ClientPrediction.validate_values(prediction_values), "physical state remains admissible for exact prediction")
		var restored := ClientPrediction.restore_state(prediction_values)
		check(restored != null, "every physical trajectory tick restores through the actual prediction decoder")
		if restored != null:
			equal(restored.spell_status_values, first.player().spell_status_values, "prediction restoration preserves the full status suffix alongside movement")
			equal(ClientPrediction.capture_packet(restored, tick, -1).get("values", PackedInt64Array()), prediction_values, "restored physical trajectory and statuses recapture to every exact prediction value")
		if tick == 0:
			check(not ClientPrediction.validate_values(prediction_values.slice(0, ClientPrediction.STATE_FIELDS.size())), "the preceding scalar-only prediction row is still rejected")
	var command_log: Array[SimCommand] = []
	for replay_tick: int in range(48):
		var replay_held := SimCommand.HELD_JUMP if replay_tick < 12 else 0
		var replay_pressed := SimCommand.PRESSED_JUMP if replay_tick == 0 else SimCommand.PRESSED_EVADE if replay_tick == 8 else 0
		command_log.append(SimCommand.new(replay_tick, 1, 0, 0, replay_held, replay_pressed))
	var replay := ReplayData.record(command_log, 120, 73)
	var replay_result := replay.verify()
	check(replay_result.ok, "recorded neutral-Q fast-fall replays through identical canonical hashes")
	var state := first.player()
	state.air_height = 120_000
	state.air_vertical_velocity = -500_000
	state.air_height_remainder = -117
	state.air_dodge_used = true
	state.jump_held_last_tick = true
	state.reset_for_spawn(Vector2i(5_000_000, 5_000_000))
	equal(state.air_height + state.air_vertical_velocity + state.air_height_remainder, 0, "spawn resets all physical height integrator state")
	check(not state.air_dodge_used and not state.jump_held_last_tick, "spawn resets finite airtime and held-edge state")


func _test_landing_readiness() -> void:
	var state := _state()
	state.air_height = 12_000
	state.air_vertical_velocity = -300_000
	state.hop_ticks = MovementSystem._remaining_air_ticks(state, config)
	state.hop_stage = 2
	state.air_dodge_used = true
	state.hop_cooldown_ticks = 60
	state.float_used = true
	state.double_jump_used = true
	state.air_dodge_cooldown_ticks = 74
	_step(state, Vector2i(1000, 0), 0, SimCommand.PRESSED_JUMP)
	check(state.jump_buffer_ticks > 0, "spent-air Jump buffers a meaningful upcoming landing")
	var saw_ground := false
	var saw_hop := false
	for _index: int in range(12):
		_step(state, Vector2i(1000, 0))
		if state.air_height == 0:
			saw_ground = true
			equal(state.hop_cooldown_ticks, 0, "real landing clears stale hop cooldown")
		if saw_ground and state.hop_stage == 1 and state.air_height > 0:
			saw_hop = true
			break
	check(saw_hop, "buffered landing Jump starts a new real airtime immediately")
	for _index: int in range(state.movement_commitment_ticks):
		_step(state, Vector2i(1000, 0), SimCommand.HELD_JUMP)
	check(state.air_dodge_cooldown_ticks > 0, "fixture still has old ground evade cooldown")
	_step(state, Vector2i(0, 1000), 0, SimCommand.PRESSED_EVADE)
	check(state.air_dodge_ticks > 0 and state.air_dodge_used, "new airtime dodge is ready without waiting old ground evade cooldown")
