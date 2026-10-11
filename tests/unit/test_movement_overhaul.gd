extends FluxTestSuite
@warning_ignore_start("integer_division")


func run() -> int:
	equal(MovementTuning.EVADE_INTENT_POLICY_ID, "evade-current-intent-directional-dodge-neutral-fast-fall-v1", "same-build compatibility names the exact Evade intent policy")
	_test_continuous_angles_and_accumulated_turns()
	_test_one_intent_and_commitment()
	_test_evade_current_intent_and_chords()
	_test_jump_slide_chord_priority()
	_test_jump_slide_commitment_and_repeat_controls()
	_test_held_jump_slide_wall_priority()
	_test_jump_slide_wall_release_priority()
	_test_held_jump_slide_flight_and_takeoff()
	_test_discarded_held_jump_routes()
	_test_consumed_wall_hold_and_owner_guards()
	_test_fresh_held_jump_recovery()
	_test_held_slide_buffer_ownership()
	_test_cancel_fresh_jump_edge()
	_test_held_jump_owner_prediction()
	_test_air_families_and_slow()
	_test_slide_entry_momentum()
	_test_paid_slide_boost_routes()
	_test_landing_slide_buffer()
	_test_landing_slide_buffer_guards()
	_test_landing_slide_prediction()
	_test_deliberate_second_jump_flight_contract()
	_test_carried_slide_and_fresh_fast_fall()
	_test_no_op_redirect_and_stale_roll()
	_test_paid_redirect_during_dodge_recovery()
	_test_dodge_recovery_momentum_loss()
	_test_dodge_recovery_loss_prediction()
	_test_dodge_redirect_guards_and_walls()
	_test_dodge_redirect_moving_cast_and_replication()
	_test_locked_sustain_and_wall_exits()
	_test_late_recovery_jump_buffer()
	_test_recovery_jump_buffer_guards()
	_test_recovery_jump_prediction()
	_test_slow_cannot_cancel_forced_control()
	_test_wavedash_landing_protection()
	_test_fast_fall_wavedash_routes()
	_test_fast_fall_wavedash_window_and_guards()
	_test_fast_fall_wavedash_prediction()
	_test_fast_fall_wavedash_snapshot()
	_test_profile_routes_and_repeat_hashes()
	return finish("movement-overhaul")


func _state() -> PlayerState:
	var state := PlayerState.new(1)
	state.position_x = 5_000_000
	state.position_y = 5_000_000
	return state


func _arena() -> CollisionWorld:
	return CollisionWorld.new(10_000_000, 10_000_000)


func _tick(state: PlayerState, direction: Vector2i = Vector2i.ZERO, held: int = 0, pressed: int = 0, arena: CollisionWorld = null) -> void:
	MovementSystem.step(state, SimCommand.new(0, 1, direction.x, direction.y, held, pressed), SimConfig.new(120), arena if arena != null else _arena())


func _prediction_authority_world(state: PlayerState, config: SimConfig) -> SimWorld:
	# Exact prediction packets include the resources and cast clocks that drive
	# identity windows, so use the real authority stage order for these routes.
	var world := SimWorld.new(config.tick_rate, 922, _arena())
	world.players.clear()
	world.players.append(state)
	return world


func _wait_commitment(state: PlayerState, direction: Vector2i = Vector2i.ZERO, arena: CollisionWorld = null) -> void:
	for _index: int in range(state.movement_commitment_ticks):
		_tick(state, direction, 0, 0, arena)


func _test_continuous_angles_and_accumulated_turns() -> void:
	for tiny: Vector2i in [Vector2i(1, 1), Vector2i(1, 2), Vector2i(-2, 1), Vector2i(1000, 1)]:
		var normalized := MovementSystem._direction(tiny.x, tiny.y, Vector2i.ZERO)
		check(normalized.length_squared() <= 1_000_000, "tiny continuous inputs cannot create a super-unit speed vector")
	for input: Vector2i in [Vector2i(1000, 1), Vector2i(1000, 200), Vector2i(600, 800), Vector2i(-800, 600), Vector2i(-200, -1000)]:
		var state := _state()
		for _index: int in range(40):
			_tick(state, input)
		var cross := state.velocity_x * input.y - state.velocity_y * input.x
		check(absi(cross) <= 1_000_000, "continuous analog direction preserves slope instead of snapping to a visual sector")
		check(Vector2i(state.facing_x, state.facing_y) != Vector2i(signi(input.x) * 707, signi(input.y) * 707), "non-diagonal analog facing is not eight-way quantized")
	for ratio: int in [MovementTuning.WAVE_DASH_STEERING]:
		for requested: Vector2i in [Vector2i(0, -1000), Vector2i(-1000, 0)]:
			var value := Vector2i(1000, 0)
			var command := SimCommand.new(0, 1, requested.x, requested.y)
			var slowed_on_turn := false
			for _index: int in range(24):
				value = MovementSystem._steer(value, requested, command, ratio)
				slowed_on_turn = slowed_on_turn or value.length_squared() < 700_000
			check(value.x * requested.x + value.y * requested.y > 950_000, "accumulated wavedash steering completes a perpendicular or opposite turn")
			check(slowed_on_turn, "sharp carving trades speed before completing the turn")


func _test_one_intent_and_commitment() -> void:
	var state := _state()
	state.velocity_x = MovementTuning.BASE_SPEED
	_tick(state, Vector2i(1000, 0), 0, SimCommand.PRESSED_JUMP | SimCommand.PRESSED_EVADE | SimCommand.PRESSED_SLIDE | SimCommand.PRESSED_TECHNIQUE)
	check(state.is_rolling(), "simultaneous chord chooses explicit Evade")
	equal(state.movement_chain_count, 1, "one chord accepts exactly one paid activation")
	equal(state.stamina, state.stamina_maximum - MovementTuning.ROLL_COST, "discarded chord actions cannot pay later")
	equal(state.jump_buffer_ticks + state.slide_buffer_ticks + state.technique_buffer_ticks, 0, "lower-priority chord intents do not remain latent")
	_tick(state, Vector2i(1000, 0), 0, SimCommand.PRESSED_JUMP)
	check(state.is_rolling() and state.jump_buffer_ticks > 0, "early Jump waits for paid roll commitment")
	_tick(state, Vector2i(1000, 0), 0, SimCommand.PRESSED_SLIDE)
	equal(state.jump_buffer_ticks, 0, "newer Slide replaces older buffered Jump")
	_wait_commitment(state, Vector2i(1000, 0))
	equal(state.hop_ticks, 0, "superseded Jump never materializes")
	var grounded := _state()
	_tick(grounded, Vector2i(1000, 0), 0, SimCommand.PRESSED_TECHNIQUE)
	equal(grounded.technique_buffer_ticks, 0, "meaningless ground Technique expires in its original context")
	_tick(grounded, Vector2i(1000, 0), 0, SimCommand.PRESSED_JUMP)
	_wait_commitment(grounded)
	equal(grounded.movement_chain_count, 1, "old ground Technique cannot become a later paid air turn")
	var landing := _state()
	landing.hop_ticks = 4
	landing.air_height = 3000
	landing.air_vertical_velocity = -80_000
	landing.hop_stage = 1
	landing.air_dodge_cooldown_ticks = 5
	landing.air_dodge_used = true
	var before := landing.stamina
	_tick(landing, Vector2i(1000, 0), 0, SimCommand.PRESSED_EVADE)
	check(landing.evade_buffer_airborne, "unready airborne Evade remembers its original context")
	for _index: int in range(6):
		_tick(landing, Vector2i(1000, 0))
	check(not landing.is_rolling(), "failed air dodge never becomes an unintended grounded roll")
	equal(landing.evade_buffer_ticks, 0, "cross-context evade is consumed without payment")
	equal(landing.stamina, before, "context change cannot charge a different movement action")


func _test_evade_current_intent_and_chords() -> void:
	var ground_neutral := _state()
	ground_neutral.facing_x = 0
	ground_neutral.facing_y = -1000
	_tick(ground_neutral, Vector2i.ZERO, 0, SimCommand.PRESSED_EVADE)
	check(ground_neutral.is_rolling(), "grounded neutral Q retains the existing roll")
	equal(Vector2i(ground_neutral.air_dodge_x, ground_neutral.air_dodge_y), Vector2i(0, -1000), "grounded neutral roll retains its documented facing fallback")
	var changed := _state()
	changed.air_height = 120_000
	changed.air_vertical_velocity = 100_000
	changed.hop_ticks = MovementSystem._remaining_air_ticks(changed, SimConfig.new(120))
	changed.hop_stage = 1
	changed.movement_commitment_ticks = 2
	_tick(changed, Vector2i(1000, 0), 0, SimCommand.PRESSED_EVADE)
	check(changed.evade_buffer_ticks > 0 and changed.air_dodge_ticks == 0, "Q waits behind the existing movement commitment")
	_tick(changed, Vector2i(-1000, 0))
	equal(Vector2i(changed.air_dodge_x, changed.air_dodge_y), Vector2i(-1000, 0), "buffered Q uses current direction at admission, not press-time direction")
	var released := _state()
	released.air_height = 120_000
	released.air_vertical_velocity = 100_000
	released.hop_ticks = MovementSystem._remaining_air_ticks(released, SimConfig.new(120))
	released.hop_stage = 1
	released.movement_commitment_ticks = 2
	_tick(released, Vector2i(1000, 0), 0, SimCommand.PRESSED_EVADE)
	_tick(released, Vector2i.ZERO)
	check(released.fast_falling and released.air_dodge_ticks == 0, "directional press becomes fast-fall when current admission intent is neutral")
	var directed := _state()
	directed.air_height = 120_000
	directed.air_vertical_velocity = 100_000
	directed.hop_ticks = MovementSystem._remaining_air_ticks(directed, SimConfig.new(120))
	directed.hop_stage = 1
	directed.movement_commitment_ticks = 2
	_tick(directed, Vector2i.ZERO, 0, SimCommand.PRESSED_EVADE)
	_tick(directed, Vector2i(0, 1000))
	equal(Vector2i(directed.air_dodge_x, directed.air_dodge_y), Vector2i(0, 1000), "neutral press becomes screen-down planar dodge when current admission intent is directional")
	for pressed: int in [
		SimCommand.PRESSED_EVADE | SimCommand.PRESSED_SLIDE,
		SimCommand.PRESSED_EVADE | SimCommand.PRESSED_JUMP | SimCommand.PRESSED_SLIDE,
	]:
		var chord := _state()
		chord.air_height = 120_000
		chord.air_vertical_velocity = 100_000
		chord.hop_ticks = MovementSystem._remaining_air_ticks(chord, SimConfig.new(120))
		chord.hop_stage = 1
		_tick(chord, Vector2i(1000, 0), SimCommand.HELD_FAST_FALL | SimCommand.HELD_JUMP, pressed)
		check(chord.air_dodge_ticks > 0 and not chord.fast_fall_armed, "directional Q owns a Q+Jump+C chord without a second fast-fall admission")
		check(chord.slide_held_last_tick, "suppressed C is still remembered as held")
		_tick(chord, Vector2i(1000, 0), SimCommand.HELD_FAST_FALL | SimCommand.HELD_JUMP)
		check(chord.air_dodge_ticks > 0 and not chord.fast_fall_armed, "carried C cannot rearm after the Q chord")
	var neutral_chord := _state()
	neutral_chord.air_height = 120_000
	neutral_chord.air_vertical_velocity = 100_000
	neutral_chord.hop_ticks = MovementSystem._remaining_air_ticks(neutral_chord, SimConfig.new(120))
	neutral_chord.hop_stage = 1
	var neutral_stamina := neutral_chord.stamina
	_tick(neutral_chord, Vector2i.ZERO, SimCommand.HELD_FAST_FALL, SimCommand.PRESSED_EVADE | SimCommand.PRESSED_SLIDE)
	check(neutral_chord.fast_falling and neutral_chord.air_dodge_ticks == 0, "neutral Q owns Q+C as one vertical fast-fall")
	equal(neutral_chord.stamina, neutral_stamina, "neutral Q+C cannot charge an air dodge or another movement action")
	var buffered_chord := _state()
	buffered_chord.air_height = 120_000
	buffered_chord.air_vertical_velocity = 100_000
	buffered_chord.hop_ticks = MovementSystem._remaining_air_ticks(buffered_chord, SimConfig.new(120))
	buffered_chord.hop_stage = 1
	buffered_chord.movement_commitment_ticks = 2
	_tick(buffered_chord, Vector2i(1000, 0), SimCommand.HELD_FAST_FALL, SimCommand.PRESSED_EVADE | SimCommand.PRESSED_SLIDE)
	check(buffered_chord.evade_buffer_ticks > 0 and not buffered_chord.fast_fall_armed, "C cannot bypass commitment while the higher-priority Q chord is buffered")
	_tick(buffered_chord, Vector2i(1000, 0), SimCommand.HELD_FAST_FALL)
	check(buffered_chord.air_dodge_ticks > 0 and not buffered_chord.fast_fall_armed, "buffered directional Q admits once while carried C stays suppressed")
	var already_armed := _state()
	already_armed.air_height = 120_000
	already_armed.air_vertical_velocity = -MovementTuning.AIR_FAST_FALL_SPEED
	already_armed.hop_ticks = MovementSystem._remaining_air_ticks(already_armed, SimConfig.new(120))
	already_armed.hop_stage = 1
	already_armed.fast_fall_armed = true
	already_armed.fast_falling = true
	_tick(already_armed, Vector2i(-1000, 0), 0, SimCommand.PRESSED_EVADE)
	check(already_armed.air_dodge_ticks > 0 and not already_armed.fast_fall_armed, "directional Q retains the existing rule that paid air dodge replaces an armed C fast-fall")
	var cast_world := SimWorld.new(120, 71, _arena())
	var caster := cast_world.player()
	caster.position_x = 5_000_000
	caster.position_y = 5_000_000
	caster.air_height = 120_000
	caster.air_vertical_velocity = 100_000
	caster.hop_ticks = MovementSystem._remaining_air_ticks(caster, cast_world.config)
	caster.hop_stage = 1
	var flux_before := caster.flux
	check(cast_world.step([SimCommand.new(0, 1, 0, 0, 0, SimCommand.PRESSED_EVADE | SimCommand.PRESSED_SPELL_1)]), "production world accepts simultaneous neutral Q and cast input")
	check(caster.fast_falling and caster.pending_cast_wire_id != 0, "movement resolves neutral Q before unchanged combat policy admits the cast")
	check(caster.flux < flux_before, "Q fast-fall does not bypass the cast's existing positive Flux payment")


func _command_jump_state(direction: Vector2i, spend_air_jump: bool = false, flight: bool = false) -> PlayerState:
	var state := _state()
	state.flight_capable = flight
	_tick(state, direction, 0, SimCommand.PRESSED_JUMP)
	_wait_commitment(state, direction)
	check(state.is_airborne(), "Jump chord fixture enters real paid airborne movement")
	if spend_air_jump:
		_tick(state, direction, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
		check(state.float_used if flight else state.double_jump_used, "Jump chord fixture spends its real once-per-airtime action")
		for _index: int in range(state.movement_commitment_ticks):
			_tick(state, direction, SimCommand.HELD_JUMP if flight else 0)
		if flight:
			_tick(state, direction)
			check(not state.air_floating and state.float_used, "released flight retains its spent allowance")
	return state


func _test_jump_slide_chord_priority() -> void:
	for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		for flight: bool in [false, true]:
			var jump := _command_jump_state(direction, true, flight)
			var chord := _command_jump_state(direction, true, flight)
			var slide := _command_jump_state(direction, true, flight)
			var before := chord.stamina
			_tick(jump, direction, 0, SimCommand.PRESSED_JUMP)
			_tick(chord, direction, 0, SimCommand.PRESSED_JUMP | SimCommand.PRESSED_SLIDE)
			_tick(slide, direction, 0, SimCommand.PRESSED_SLIDE)
			check(jump.jump_buffer_ticks > 0 and not jump.fast_fall_armed, "spent Jump-only control retains only its bounded landing buffer")
			check(slide.fast_falling and slide.air_height < jump.air_height, "Slide-only positive control still immediately fast-falls")
			equal(slide.stamina, before, "standalone airborne Slide remains free")
			check(not chord.fast_fall_armed and not chord.fast_falling, "higher-priority spent Jump suppresses lower-priority Slide even when Jump cannot admit")
			equal(chord.stamina, before, "refused Jump chord neither charges nor refunds an action")
			equal(chord.canonical_values(), jump.canonical_values(), "spent Jump plus Slide matches Jump-only authority on the chord tick")
			for _index: int in range(SimConfig.new(120).milliseconds_to_ticks(MovementTuning.INPUT_BUFFER_MS) + 1):
				_tick(jump, direction)
				_tick(chord, direction)
				_tick(slide, direction)
				equal(chord.canonical_values(), jump.canonical_values(), "discarded Slide cannot force landing and spend the remaining Jump buffer")
			check(jump.is_airborne() and chord.is_airborne(), "ordinary spent-air arc outlasts this bounded Jump buffer")
			equal(chord.jump_buffer_ticks, 0, "spent Jump chord expires without a forced landing bounce")
			check(not slide.is_airborne() and slide.hop_stage == 0, "Slide-only control lands without a hidden follow-up Jump")
		var available := _command_jump_state(direction)
		var available_chord := _command_jump_state(direction)
		_tick(available, direction, 0, SimCommand.PRESSED_JUMP)
		_tick(available_chord, direction, 0, SimCommand.PRESSED_JUMP | SimCommand.PRESSED_SLIDE)
		check(available_chord.double_jump_used and not available_chord.fast_fall_armed, "available Jump chord admits exactly one paid double jump")
		equal(available_chord.canonical_values(), available.canonical_values(), "available Jump chord preserves standalone Jump payment and trajectory")


func _test_jump_slide_commitment_and_repeat_controls() -> void:
	for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		var buffered := _command_jump_state(direction)
		_tick(buffered, direction, 0, SimCommand.PRESSED_EVADE)
		for _index: int in range(buffered.movement_commitment_ticks - 2):
			_tick(buffered, direction)
		check(buffered.air_dodge_ticks > 0 and buffered.movement_commitment_ticks == 2, "buffered Jump chord fixture keeps two real paid dodge commitment ticks")
		_tick(buffered, direction, SimCommand.HELD_FAST_FALL, SimCommand.PRESSED_JUMP | SimCommand.PRESSED_SLIDE)
		check(buffered.jump_buffer_ticks > 0 and not buffered.fast_fall_armed, "Slide cannot bypass commitment while the higher-priority Jump chord waits")
		check(buffered.slide_held_last_tick, "suppressed chord Slide still records its held state")
		_tick(buffered, direction, SimCommand.HELD_FAST_FALL)
		check(buffered.double_jump_used and not buffered.fast_fall_armed, "buffered Jump admits once while carried Slide stays suppressed")
		_tick(buffered, direction, SimCommand.HELD_FAST_FALL)
		check(not buffered.fast_fall_armed, "carried Slide cannot rearm after the Jump grace tick expires")
		var repeated := _command_jump_state(direction, true)
		var slide_only := _command_jump_state(direction, true)
		for state: PlayerState in [repeated, slide_only]:
			_tick(state, direction, SimCommand.HELD_JUMP)
		var held := SimCommand.HELD_JUMP | SimCommand.HELD_FAST_FALL
		_tick(repeated, direction, held, SimCommand.PRESSED_JUMP | SimCommand.PRESSED_SLIDE)
		_tick(slide_only, direction, held, SimCommand.PRESSED_SLIDE)
		check(repeated.fast_falling and repeated.jump_buffer_ticks == 0, "ignored held-Jump repeat cannot suppress a genuine fresh Slide")
		equal(repeated.canonical_values(), slide_only.canonical_values(), "held-repeat filtering preserves exact standalone Slide authority")
		var latched := _command_jump_state(direction, true)
		_tick(latched, direction, 0, SimCommand.PRESSED_SLIDE)
		check(latched.fast_fall_armed, "prior-latch control enters a real free fast-fall")
		var previous_velocity := latched.air_vertical_velocity
		_tick(latched, direction, 0, SimCommand.PRESSED_JUMP | SimCommand.PRESSED_SLIDE)
		check(latched.fast_fall_armed and latched.fast_falling, "suppressing a fresh lower-priority edge does not erase an earlier admitted fast-fall")
		check(latched.air_vertical_velocity <= previous_velocity, "prior admitted fast-fall continues its existing fall trajectory")


func _wall_chord_arena(normal: Vector2i) -> CollisionWorld:
	var arena := _arena()
	var lower := Vector2i(4_000_000, 4_000_000)
	var upper := Vector2i(6_000_000, 6_000_000)
	if normal.x < 0: lower.x = 5_020_000
	elif normal.x > 0: upper.x = 4_980_000
	elif normal.y < 0: lower.y = 5_020_000
	else: upper.y = 4_980_000
	arena.add_obstacle(CollisionWorld.Obstacle.new(31, lower.x, lower.y, upper.x, upper.y))
	return arena


func _command_wall_approach(direction: Vector2i, arena: CollisionWorld, flight: bool) -> PlayerState:
	var state := _state()
	state.flight_capable = flight
	_tick(state, direction, 0, SimCommand.PRESSED_JUMP, arena)
	_wait_commitment(state, direction, arena)
	check(state.is_airborne() and state.air_height >= MovementTuning.GROUND_PROJECTILE_CLEARANCE_HEIGHT, "wall chord fixture approaches an actual runnable face after a real paid ground jump")
	equal(state.movement_chain_count, 1, "wall approach has paid exactly one movement action")
	return state


func _test_held_jump_slide_wall_priority() -> void:
	# Four mirrored faces and both tangents exercise eight physical approaches.
	# Test discrete wheel edges, held-only edges, and an ordinary pressed+held C.
	for normal: Vector2i in [Vector2i(-1000, 0), Vector2i(1000, 0), Vector2i(0, -1000), Vector2i(0, 1000)]:
		var arena := _wall_chord_arena(normal)
		for sign_value: int in [-1, 1]:
			var direction := Vector2i(-normal.y, normal.x) * sign_value
			for flight: bool in [false, true]:
				for slide_edges: Vector2i in [Vector2i(SimCommand.PRESSED_SLIDE, 0), Vector2i(0, SimCommand.HELD_FAST_FALL), Vector2i(SimCommand.PRESSED_SLIDE, SimCommand.HELD_FAST_FALL)]:
					var jump := _command_wall_approach(direction, arena, flight)
					var chord := _command_wall_approach(direction, arena, flight)
					var slide := _command_wall_approach(direction, arena, flight)
					var before := chord.stamina
					var wall_cost := MovementSystem._movement_action_cost(chord, MovementTuning.WALL_SKIM_COST)
					_tick(jump, direction, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP, arena)
					_tick(chord, direction, SimCommand.HELD_JUMP | slide_edges.y, SimCommand.PRESSED_JUMP | slide_edges.x, arena)
					_tick(slide, direction, SimCommand.HELD_JUMP | slide_edges.y, slide_edges.x, arena)
					check(jump.wall_skim_ticks > 0 and jump.wall_skim_surface_id == 31, "Jump-only control admits the contacted wall before its aerial fallback")
					check(chord.wall_skim_ticks > 0 and chord.wall_skim_surface_id == 31, "discarded Slide cannot replace held Jump wall admission with a paid aerial fallback")
					equal(chord.stamina, before - wall_cost, "held Jump chord pays exactly the unchanged chain-adjusted wallrun cost")
					equal(chord.movement_chain_count, 2, "held wall chord admits exactly one new paid action")
					check(not chord.double_jump_used and not chord.float_used, "wall chord leaves the race-specific aerial allowance unspent")
					check(not chord.fast_fall_armed and chord.air_vertical_velocity == 0, "wall chord retains attached height instead of lifting or falling")
					equal(Vector2i(chord.velocity_x, chord.velocity_y), Vector2i(jump.velocity_x, jump.velocity_y), "wall chord preserves standalone Jump tangent momentum")
					check(slide.fast_falling and slide.wall_skim_ticks == 0 and not slide.float_used and not slide.double_jump_used, "genuine Slide-only edge suppresses automatic wall and flight admission")
					equal(slide.stamina, before, "standalone Slide fast-fall remains free without a hidden wall or flight charge")
					# The only legitimate command-state difference is the held-Slide latch.
					# Release that key on both routes before comparing all authoritative fields.
					_tick(jump, direction, SimCommand.HELD_JUMP, 0, arena)
					_tick(chord, direction, SimCommand.HELD_JUMP, 0, arena)
					equal(chord.canonical_values(), jump.canonical_values(), "wall chord and Jump-only continuation have identical authority, resources and timers")
					var attached_stamina := chord.stamina
					_tick(jump, direction, SimCommand.HELD_JUMP | slide_edges.y, slide_edges.x, arena)
					_tick(chord, direction, SimCommand.HELD_JUMP | slide_edges.y, SimCommand.PRESSED_JUMP | slide_edges.x, arena)
					check(chord.fast_falling and chord.wall_skim_ticks == 0, "ignored held-Jump repeat cannot suppress genuine Slide wall detachment")
					equal(chord.stamina, attached_stamina, "held-repeat wall fast-fall does not buy an extra action")
					equal(chord.canonical_values(), jump.canonical_values(), "held-repeat filtering preserves exact Slide-only wall-exit authority")


func _test_jump_slide_wall_release_priority() -> void:
	for normal: Vector2i in [Vector2i(-1000, 0), Vector2i(1000, 0), Vector2i(0, -1000), Vector2i(0, 1000)]:
		var arena := _wall_chord_arena(normal)
		for sign_value: int in [-1, 1]:
			var tangent := Vector2i(-normal.y, normal.x) * sign_value
			for release_direction: Vector2i in [Vector2i.ZERO, tangent]:
				for slide_edges: Vector2i in [Vector2i(SimCommand.PRESSED_SLIDE, 0), Vector2i(0, SimCommand.HELD_FAST_FALL), Vector2i(SimCommand.PRESSED_SLIDE, SimCommand.HELD_FAST_FALL)]:
					var jump := _command_wall_approach(tangent, arena, false)
					var chord := _command_wall_approach(tangent, arena, false)
					var slide := _command_wall_approach(tangent, arena, false)
					for state: PlayerState in [jump, chord, slide]:
						_tick(state, tangent, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP, arena)
						for _index: int in range(state.movement_commitment_ticks):
							_tick(state, tangent, SimCommand.HELD_JUMP, 0, arena)
						check(state.wall_skim_ticks > 0 and state.jump_held_last_tick, "wall release fixture retains actual paid contact through its initial commitment")
					var before := chord.stamina
					var kick_cost := MovementSystem._movement_action_cost(chord, MovementTuning.HOP_COST)
					# A same-command Jump impulse can coincide with releasing the held key.
					_tick(jump, release_direction, 0, SimCommand.PRESSED_JUMP, arena)
					_tick(chord, release_direction, slide_edges.y, SimCommand.PRESSED_JUMP | slide_edges.x, arena)
					_tick(slide, release_direction, slide_edges.y, slide_edges.x, arena)
					check(jump.wall_skim_ticks == 0 and jump.hop_mode == PlayerState.MovementMode.WALL_KICK, "Jump-only release control admits its paid wall kick")
					check(chord.wall_skim_ticks == 0 and chord.hop_mode == PlayerState.MovementMode.WALL_KICK, "discarded Slide cannot swallow the effective Jump wall-release edge")
					equal(chord.stamina, before - kick_cost, "wall-release chord pays exactly the unchanged chain-adjusted kick cost")
					equal(chord.movement_chain_count, 3, "wall-release chord admits exactly one paid successor")
					check(not chord.fast_fall_armed and not chord.double_jump_used and not chord.float_used, "wall-release chord preserves fast-fall and race-specific air allowances")
					equal(Vector2i(chord.velocity_x, chord.velocity_y), Vector2i(jump.velocity_x, jump.velocity_y), "neutral and tangent wall-release chords retain standalone kick momentum")
					check(chord.velocity_x * normal.x + chord.velocity_y * normal.y > 0, "wall-release chord launches legally outward from every mirrored face")
					check(slide.fast_falling and slide.wall_skim_ticks == 0, "Slide-only release detaches as fast-fall instead of buying a wall kick")
					equal(slide.stamina, before, "Slide-only wall release retains its free fast-fall cost")
					_tick(jump, release_direction, 0, 0, arena)
					_tick(chord, release_direction, 0, 0, arena)
					equal(chord.canonical_values(), jump.canonical_values(), "wall-release chord continuation matches every standalone Jump authority field")


func _test_held_jump_slide_flight_and_takeoff() -> void:
	for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		for slide_edges: Vector2i in [Vector2i(SimCommand.PRESSED_SLIDE, 0), Vector2i(0, SimCommand.HELD_FAST_FALL), Vector2i(SimCommand.PRESSED_SLIDE, SimCommand.HELD_FAST_FALL)]:
			var jump := _command_jump_state(direction, false, true)
			var chord := _command_jump_state(direction, false, true)
			var slide := _command_jump_state(direction, false, true)
			var before := chord.stamina
			_tick(jump, direction, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
			_tick(chord, direction, SimCommand.HELD_JUMP | slide_edges.y, SimCommand.PRESSED_JUMP | slide_edges.x)
			_tick(slide, direction, SimCommand.HELD_JUMP | slide_edges.y, slide_edges.x)
			check(chord.air_floating and chord.float_used and not chord.fast_fall_armed, "fresh effective Jump chord admits ordinary paid flight away from walls")
			equal(chord.stamina, jump.stamina, "flight chord pays the same activation and fractional sustain as Jump-only")
			equal(chord.air_height, jump.air_height, "flight chord holds exactly the standalone admission height")
			check(slide.fast_falling and not slide.float_used, "Slide-only positive control does not waste the flight allowance")
			equal(slide.stamina, before, "Slide-only held chord cannot spend flight before free fast-fall")
			_tick(jump, direction, SimCommand.HELD_JUMP)
			_tick(chord, direction, SimCommand.HELD_JUMP)
			equal(chord.canonical_values(), jump.canonical_values(), "flight hold and lower-priority Slide chord preserve identical buffer and commitment authority")
			for held: int in [0, SimCommand.HELD_JUMP]:
				var ground := _state()
				var ground_chord := _state()
				_tick(ground, direction, held, SimCommand.PRESSED_JUMP)
				_tick(ground_chord, direction, held | slide_edges.y, SimCommand.PRESSED_JUMP | slide_edges.x)
				_tick(ground, direction)
				_tick(ground_chord, direction)
				equal(ground_chord.canonical_values(), ground.canonical_values(), "shared Slide priority preserves instant and held-preparation ground takeoff")


func _held_jump_catalog() -> ChampionCatalog:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "held-intent tests load actual abilities")
	var catalog := ChampionCatalog.new()
	check(catalog.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "held-intent tests load actual champion permissions")
	return catalog


func _paid_profile_jump(catalog: ChampionCatalog, champion_id: String, direction: Vector2i, arena: CollisionWorld) -> PlayerState:
	var state := _state()
	check(catalog.apply_to_player(state, champion_id), "held-intent route applies the actual profile")
	_tick(state, direction, 0, SimCommand.PRESSED_JUMP, arena)
	_wait_commitment(state, direction, arena)
	check(state.is_airborne() and not state.float_used and not state.double_jump_used, "held-intent route begins with one real paid ground jump")
	return state


func _test_discarded_held_jump_routes() -> void:
	var config := SimConfig.new(120)
	var catalog := _held_jump_catalog()
	# Every actual profile: all eight open-air headings and both tangents of
	# four real mirrored walls. No position/velocity/air-budget injection.
	for champion_id: String in catalog.ordered_champion_ids():
		for normal: Vector2i in [Vector2i.ZERO, Vector2i.LEFT * 1000, Vector2i.RIGHT * 1000, Vector2i.UP * 1000, Vector2i.DOWN * 1000]:
			var arena := _arena() if normal == Vector2i.ZERO else _wall_chord_arena(normal)
			var directions: Array[Vector2i] = []
			if normal == Vector2i.ZERO:
				directions.assign(EightDirectionResolver.FIXED_VECTORS)
			else:
				directions.assign([Vector2i(-normal.y, normal.x), Vector2i(normal.y, -normal.x)])
			for direction: Vector2i in directions:
				var state := _paid_profile_jump(catalog, champion_id, direction, arena)
				var reference := _paid_profile_jump(catalog, champion_id, direction, arena)
				var before := state.stamina
				var cost := MovementSystem._movement_action_cost(state, MovementTuning.AIR_DODGE_COST)
				_tick(state, direction, SimCommand.HELD_JUMP, SimCommand.PRESSED_EVADE | SimCommand.PRESSED_JUMP, arena)
				_tick(reference, direction, 0, SimCommand.PRESSED_EVADE, arena)
				equal(state.stamina, before - cost, "Evade owns the chord and pays exactly one adjusted dodge cost")
				check(not state.wallrun_armed and state.air_dodge_used, "discarded Jump hold is disarmed without losing the paid dodge")
				for _index: int in range(config.milliseconds_to_ticks(MovementTuning.AIR_DODGE_DURATION_MS) + 1):
					_tick(state, direction, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP, arena)
					_tick(reference, direction, 0, 0, arena)
					check(not state.air_floating and state.wall_skim_ticks == 0, "ignored held Jump cannot buy delayed flight or wallrun after dodge")
					equal(state.stamina, reference.stamina, "held repeat never adds hidden Stamina payment")
					equal(state.movement_chain_count, reference.movement_chain_count, "discarded hold never advances the paid chain")
					for field: StringName in [&"air_dodge_ticks", &"air_dodge_cooldown_ticks", &"air_dodge_used", &"double_jump_used", &"float_used", &"air_redirects_remaining", &"air_height", &"velocity_x", &"velocity_y"]:
						equal(state.get(field), reference.get(field), "discarded hold preserves Evade-only authority: " + String(field))
				check(state.is_airborne(), "real dodge route remains airborne for its deliberate follow-up")
				_tick(state, direction, 0, 0, arena)
				check(state.wallrun_armed, "actual Jump release rearms held air intent")
				before = state.stamina
				var base_cost := MovementTuning.WALL_SKIM_COST if normal != Vector2i.ZERO else MovementTuning.FLOAT_COST if state.flight_capable else MovementTuning.DOUBLE_JUMP_COST
				cost = MovementSystem._movement_action_cost(state, base_cost)
				var cooldown := state.air_dodge_cooldown_ticks
				_tick(state, direction, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP, arena)
				var sustain := config.per_tick(MovementTuning.FLOAT_DRAIN_PER_SECOND) if normal == Vector2i.ZERO and state.flight_capable else 0
				equal(state.stamina, before - cost - sustain, "release/repress buys exactly its intended paid continuation")
				equal(state.air_dodge_cooldown_ticks, cooldown - 1, "new Jump does not restart or refund the existing dodge cooldown")
				check(state.air_dodge_used, "new Jump cannot replenish spent dodge allowance")
				if normal != Vector2i.ZERO:
					check(state.wall_skim_ticks > 0 and not state.float_used and not state.double_jump_used, "fresh held Jump chooses actual wall contact before racial fallback")
				else:
					check(state.air_floating if state.flight_capable else state.double_jump_used, "fresh held Jump restores the correct race-authorized air action")


func _test_consumed_wall_hold_and_owner_guards() -> void:
	var config := SimConfig.new(120)
	for normal: Vector2i in [Vector2i.LEFT * 1000, Vector2i.RIGHT * 1000, Vector2i.UP * 1000, Vector2i.DOWN * 1000]:
		var arena := _wall_chord_arena(normal)
		var tangent := Vector2i(-normal.y, normal.x)
		for exit_kind: String in ["expiry", "away", "technique", "removed", "cancel"]:
			var state := _command_wall_approach(tangent, arena, true)
			_tick(state, tangent, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP, arena)
			check(state.wall_skim_ticks > 0 and not state.wallrun_armed, "real held wallrun consumes the air-intent latch")
			var before := state.stamina
			var current_arena := _arena() if exit_kind == "removed" else arena
			if exit_kind == "expiry":
				for _index: int in range(state.wall_skim_ticks):
					_tick(state, tangent, SimCommand.HELD_JUMP, 0, current_arena)
			elif exit_kind == "technique":
				for _index: int in range(state.movement_commitment_ticks):
					_tick(state, tangent, SimCommand.HELD_JUMP, 0, current_arena)
				_tick(state, tangent, SimCommand.HELD_JUMP, SimCommand.PRESSED_TECHNIQUE, current_arena)
			else:
				_tick(state, normal if exit_kind == "away" else tangent, SimCommand.HELD_JUMP, SimCommand.PRESSED_CANCEL_MOVEMENT if exit_kind == "cancel" else 0, current_arena)
			check(state.wall_skim_ticks == 0 and not state.air_floating, "wall exit ends attachment without silently purchasing unused Flight: " + exit_kind)
			for _index: int in range(maxi(2, state.movement_commitment_ticks)):
				_tick(state, normal, SimCommand.HELD_JUMP, 0, current_arena)
				check(not state.air_floating and not state.float_used, "consumed wall hold stays unspent through recovery: " + exit_kind)
				equal(state.stamina, before, "consumed wall hold adds no hidden flight activation or sustain")
			_tick(state, normal, 0, 0, current_arena)
			var cost := MovementSystem._movement_action_cost(state, MovementTuning.FLOAT_COST)
			_tick(state, normal, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP, current_arena)
			check(state.air_floating and state.float_used, "deliberate release/repress still permits unused Flight after wall exit")
			equal(state.stamina, before - cost - config.per_tick(MovementTuning.FLOAT_DRAIN_PER_SECOND), "deliberate wall-to-Flight continuation pays activation and first sustain once")
	for owner: int in [SimCommand.PRESSED_EVADE, SimCommand.PRESSED_SLIDE, SimCommand.PRESSED_TECHNIQUE]:
		var state := _state()
		state.flight_capable = true
		_tick(state, Vector2i(1000, 0), 0, SimCommand.PRESSED_JUMP)
		while state.movement_commitment_ticks > 2:
			_tick(state, Vector2i(1000, 0), SimCommand.HELD_JUMP)
		var before := state.stamina
		# Jump is a held repeat here, so the fresh other action owns the chord.
		_tick(state, Vector2i(1000, 0), SimCommand.HELD_JUMP, owner | SimCommand.PRESSED_JUMP)
		check(not state.wallrun_armed, "effective non-Jump owner disarms a carried Jump even when repeated press bits accompany it")
		for _index: int in range(3):
			_tick(state, Vector2i(1000, 0), SimCommand.HELD_JUMP)
			check(not state.air_floating and not state.float_used, "newest movement owner cannot resume the superseded flight hold")
		if owner == SimCommand.PRESSED_TECHNIQUE:
			equal(state.stamina, before, "same-direction Technique refusal still owns intent without spending on Flight")
	var refused := _command_jump_state(Vector2i(1000, 0), false, true)
	refused.stamina = MovementSystem._movement_action_cost(refused, MovementTuning.FLOAT_COST) + config.per_tick(MovementTuning.FLOAT_DRAIN_PER_SECOND) + 1
	var before := refused.stamina
	_tick(refused, Vector2i(1000, 0), SimCommand.HELD_JUMP, SimCommand.PRESSED_EVADE | SimCommand.PRESSED_JUMP)
	check(not refused.air_dodge_used, "low-funds chord really refuses the more expensive dodge")
	for _index: int in range(config.milliseconds_to_ticks(MovementTuning.INPUT_BUFFER_MS) + 1):
		_tick(refused, Vector2i(1000, 0), SimCommand.HELD_JUMP)
	check(not refused.float_used and not refused.air_floating, "expired refused Evade cannot fall through into affordable Flight")
	equal(refused.stamina, before, "refused owner cannot make a later hidden cheaper purchase")


func _test_fresh_held_jump_recovery() -> void:
	var catalog := _held_jump_catalog()
	var config := SimConfig.new(120)
	var flight_profiles := 0
	for champion_id: String in catalog.ordered_champion_ids():
		var candidate := _state()
		check(catalog.apply_to_player(candidate, champion_id), "flight recovery selects actual permissions")
		if not candidate.flight_capable:
			continue
		flight_profiles += 1
		for control: int in _recovery_controls():
			for fresh: bool in [false, true]:
				var state := _paid_recovery_fixture(control, Vector2i(1000, 0), true, 2, catalog, champion_id)
				var before := state.stamina
				var cost := MovementSystem._movement_action_cost(state, MovementTuning.FLOAT_COST)
				_tick(state, Vector2i(1000, 0), SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP if fresh else 0)
				check(not state.wallrun_armed and not state.air_floating, "locked held Jump cannot rearm automatic flight early")
				equal(state.stamina, before, "locked flight request never pays early")
				_tick(state, Vector2i(1000, 0), SimCommand.HELD_JUMP)
				equal(state.air_floating, fresh, "only a fresh live recovery buffer owns Flight at legal unlock")
				equal(state.float_used, fresh, "old held intent cannot spend the independent flight allowance")
				equal(state.stamina, before - cost - config.per_tick(MovementTuning.FLOAT_DRAIN_PER_SECOND) if fresh else before, "fresh flight buffer pays the unchanged exact activation and sustain")
				equal(state.movement_chain_count, 2 if fresh else 1, "recovery admits exactly the explicitly buffered paid continuation")
	check(flight_profiles > 0, "recovery matrix includes every actual flight-capable profile")


func _test_held_slide_buffer_ownership() -> void:
	var catalog := _held_jump_catalog()
	var config := SimConfig.new(120)
	var held_both := SimCommand.HELD_JUMP | SimCommand.HELD_FAST_FALL
	for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		for control: int in _recovery_controls():
			var held_only := _paid_recovery_fixture(control, direction, true, 3, catalog, "grace_reava")
			var pressed := _paid_recovery_fixture(control, direction, true, 3, catalog, "grace_reava")
			var before := held_only.stamina
			for state: PlayerState in [held_only, pressed]:
				_tick(state, direction, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
				equal(_recovery_ticks(state), 2, "held-Slide replacement fixture has two locked ticks and a genuine new Jump")
				check(state.jump_buffer_ticks > 0 and state.flight_capable, "actual Grace route owns an affordable unspent flight buffer")
			_tick(held_only, direction, held_both)
			_tick(pressed, direction, held_both, SimCommand.PRESSED_SLIDE)
			equal(held_only.jump_buffer_ticks, 0, "fresh held-only Slide clears the older Jump before the final locked tick")
			equal(held_only.canonical_values(), pressed.canonical_values(), "held-only and pressed Slide have identical replacement authority during recovery")
			for state: PlayerState in [held_only, pressed]:
				_tick(state, direction, held_both)
				equal(_recovery_ticks(state), 0, "held-only Slide does not change the original recovery deadline")
				check(not state.air_floating and not state.float_used and not state.fast_fall_armed, "unlock cannot resurrect Jump or replay a Slide edge already suppressed by forced recovery")
				equal(state.stamina, before, "superseded Jump cannot charge Flight on unlock")
				equal(state.movement_chain_count, 1, "supersession adds no paid continuation")
			equal(held_only.canonical_values(), pressed.canonical_values(), "carried Slide holds preserve exact pressed-edge behavior at unlock")
			# Releasing Jump, while continuing to hold Slide, rearms a genuinely
			# new Jump without rearming the old Slide edge or granting free lift.
			for state: PlayerState in [held_only, pressed]:
				_tick(state, direction, SimCommand.HELD_FAST_FALL)
				var cost := MovementSystem._movement_action_cost(state, MovementTuning.FLOAT_COST)
				_tick(state, direction, held_both, SimCommand.PRESSED_JUMP)
				check(state.air_floating and state.float_used and not state.fast_fall_armed, "genuine Jump after Slide can still buy its intended flight")
				equal(state.stamina, before - cost - config.per_tick(MovementTuning.FLOAT_DRAIN_PER_SECOND), "fresh post-Slide flight pays the unchanged activation and first sustain")
			equal(held_only.canonical_values(), pressed.canonical_values(), "fresh post-Slide continuation remains identical across edge encodings")
			var jump := _paid_recovery_fixture(control, direction, true, 2, catalog, "grace_reava")
			var chord := _paid_recovery_fixture(control, direction, true, 2, catalog, "grace_reava")
			_tick(jump, direction, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
			_tick(chord, direction, held_both, SimCommand.PRESSED_JUMP)
			equal(chord.jump_buffer_ticks, jump.jump_buffer_ticks, "effective fresh Jump still outranks a simultaneous held-only Slide edge")
			for state: PlayerState in [jump, chord]:
				_tick(state, direction, SimCommand.HELD_JUMP)
				check(state.air_floating and not state.fast_fall_armed, "Jump-owned recovery chord retains its legal paid flight")
			equal(chord.canonical_values(), jump.canonical_values(), "discarded held-only Slide cannot change genuine Jump recovery authority")
		var committed := _state()
		var committed_pressed := _state()
		for state: PlayerState in [committed, committed_pressed]:
			check(catalog.apply_to_player(state, "grace_reava"), "commitment control uses actual Grace")
			_tick(state, direction, 0, SimCommand.PRESSED_JUMP)
			_tick(state, direction, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
			check(state.jump_buffer_ticks > 0 and state.movement_commitment_ticks > 0, "real paid takeoff contains a pending Jump behind its unchanged commitment")
		_tick(committed, direction, held_both)
		_tick(committed_pressed, direction, held_both, SimCommand.PRESSED_SLIDE)
		equal(committed.jump_buffer_ticks, 0, "held-only Slide replaces older Jump during voluntary commitment too")
		equal(committed.canonical_values(), committed_pressed.canonical_values(), "held-only Slide matches pressed Slide through ordinary fast-fall and landing")
	var authority := _paid_recovery_fixture(PlayerState.ControlState.ROOTED, Vector2i(1000, 0), true, 3, catalog, "grace_reava")
	authority.entity_id = 2
	var authority_world := _prediction_authority_world(authority, config)
	var prediction := ClientPrediction.new()
	check(prediction.configure(config, _arena(), 2), "held-only Slide prediction uses unchanged movement fields")
	check(prediction.reconcile(ClientPrediction.capture_packet(authority, 0, -1)), "held-only Slide prediction restores the actual paid recovery")
	var packets: Array[Dictionary] = []
	for index: int in range(7):
		var held := SimCommand.HELD_JUMP if index == 0 else SimCommand.HELD_FAST_FALL if index == 3 else held_both
		var pressed := SimCommand.PRESSED_JUMP if index in [0, 4] else 0
		var command := SimCommand.new(index, 2, 1000, 0, held, pressed)
		check(prediction.queue_input(index + 1, command), "held-only replacement enters actual client prediction")
		check(authority_world.step([command]), "full authority stages advance held-only Slide prediction route")
		var packet := ClientPrediction.capture_packet(authority, index + 1, index + 1)
		packets.append(packet)
		equal(ClientPrediction.capture_packet(prediction.predicted_state, index + 1, index + 1).values, packet.values, "held-only Slide authority and prediction match every buffer, budget and timer")
		if index == 2:
			check(not authority.float_used and authority.jump_buffer_ticks == 0, "prediction route cannot spend the superseded recovery Jump")
			check(prediction.reconcile(packets[0], authority.last_event), "delayed acknowledgement restores old Jump then replays held-only replacement")
			equal(ClientPrediction.capture_packet(prediction.predicted_state, index + 1, index + 1).values, packet.values, "replayed held-only edge removes the old Jump exactly once")
	check(authority.air_floating and authority.float_used, "prediction route retains the subsequent genuine paid Jump")
	check(prediction.reconcile(packets.back(), authority.last_event), "held-only replacement final acknowledgement succeeds")
	equal(prediction.pending_count(), 0, "held-only replacement leaves no latent prediction inputs")


func _test_cancel_fresh_jump_edge() -> void:
	var catalog := _held_jump_catalog()
	var config := SimConfig.new(120)
	for locked: bool in [false, true]:
		for fresh_edge: bool in [false, true]:
			var direction := Vector2i(1000, 0)
			var state := _paid_recovery_fixture(PlayerState.ControlState.ROOTED, direction, true, 3, catalog, "grace_reava") if locked else _paid_profile_jump(catalog, "grace_reava", direction, _arena())
			var before := state.stamina
			var cost := MovementSystem._movement_action_cost(state, MovementTuning.FLOAT_COST)
			_tick(state, direction, SimCommand.HELD_JUMP, SimCommand.PRESSED_CANCEL_MOVEMENT)
			check(not state.wallrun_armed and not state.jump_held_last_tick and state.jump_buffer_ticks == 0, "cancel clears anticipation without immediately rearming held admission")
			# The input router quarantines old holds and filters echoes. A new
			# explicit edge here can represent release/repress between sim ticks;
			# it must not require an additional sampled neutral command.
			_tick(state, direction, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP if fresh_edge else 0)
			if locked:
				equal(_recovery_ticks(state), 1, "fresh post-cancel edge cannot bypass the original remaining lock")
				check(not state.air_floating, "post-cancel Flight waits for legal control")
				equal(state.stamina, before, "post-cancel buffering cannot spend early")
				_tick(state, direction, SimCommand.HELD_JUMP)
			equal(state.air_floating, fresh_edge, "explicit fresh post-cancel edge is valid; held-only continuation remains suppressed")
			equal(state.float_used, fresh_edge, "only the explicit new gesture spends the flight allowance")
			equal(state.stamina, before - cost - config.per_tick(MovementTuning.FLOAT_DRAIN_PER_SECOND) if fresh_edge else before, "post-cancel admission preserves exact paid resource semantics")
			equal(state.movement_chain_count, 2 if fresh_edge else 1, "post-cancel input admits at most one intentional continuation")


func _test_held_jump_owner_prediction() -> void:
	var config := SimConfig.new(120)
	for recovery: bool in [false, true]:
		var authority := _paid_recovery_fixture(PlayerState.ControlState.ROOTED, Vector2i(1000, 0), true, 3) if recovery else _command_jump_state(Vector2i(1000, 0))
		authority.flight_capable = true
		authority.entity_id = 2
		var authority_world := _prediction_authority_world(authority, config)
		var prediction := ClientPrediction.new()
		check(prediction.configure(config, _arena(), 2), "held-owner prediction uses the unchanged movement schema")
		check(prediction.reconcile(ClientPrediction.capture_packet(authority, 0, -1)), "held-owner prediction restores the real paid predecessor")
		var packets: Array[Dictionary] = []
		for index: int in range(29):
			var held := SimCommand.HELD_JUMP if recovery or index != 24 else 0
			var pressed := SimCommand.PRESSED_JUMP if (recovery and index == 0) or (not recovery and index == 25) else 0
			if not recovery and index == 0:
				pressed = SimCommand.PRESSED_EVADE | SimCommand.PRESSED_JUMP
			var command := SimCommand.new(index, 2, 1000, 0, held, pressed)
			check(prediction.queue_input(index + 1, command), "held-owner command enters client prediction")
			check(authority_world.step([command]), "full authority stages advance held-owner prediction route")
			var packet := ClientPrediction.capture_packet(authority, index + 1, index + 1)
			packets.append(packet)
			equal(ClientPrediction.capture_packet(prediction.predicted_state, index + 1, index + 1).values, packet.values, "every held-owner flag, buffer, budget, cooldown and payment matches prediction")
			if index == 23:
				check(prediction.reconcile(packets[1], authority.last_event), "delayed acknowledgement replays consumed intent or fresh recovery ownership")
				equal(ClientPrediction.capture_packet(prediction.predicted_state, index + 1, index + 1).values, packet.values, "delayed replay cannot resurrect a discarded hold")
			if not recovery and index == 23:
				check(not authority.float_used and not authority.wallrun_armed, "replayed discarded chord remains unpaid through dodge expiry")
		check(authority.air_floating and authority.float_used, "prediction route actually reaches fresh paid Flight")
		check(prediction.reconcile(packets.back(), authority.last_event), "final held-owner acknowledgement drains history")
		equal(prediction.pending_count(), 0, "held-owner replay leaves no latent input history")


func _test_air_families_and_slow() -> void:
	for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		for ratio: int in [250, 700, 1000]:
			var reference := PackedInt64Array()
			for mode: int in [PlayerState.MovementMode.HOP, PlayerState.MovementMode.DOUBLE_JUMP, PlayerState.MovementMode.SLIDE_JUMP, PlayerState.MovementMode.WALL_KICK]:
				var state := _state()
				state.hop_ticks = 36
				state.air_height = 150_000
				state.air_vertical_velocity = 300_000
				state.hop_mode = mode
				state.hop_speed = 600_000
				state.air_velocity_x = direction.x * 600_000 / 1000
				state.air_velocity_y = direction.y * 600_000 / 1000
				state.velocity_x = state.air_velocity_x
				state.velocity_y = state.air_velocity_y
				MovementSystem.apply_control_state(state, PlayerState.ControlState.SLOWED, 2000, Vector2i.ZERO, 0, SimConfig.new(120), ratio)
				var coast := Vector2i(state.velocity_x, state.velocity_y)
				for _index: int in range(5):
					_tick(state, Vector2i.ZERO, SimCommand.HELD_JUMP)
					equal(Vector2i(state.velocity_x, state.velocity_y), coast, "neutral airborne slow is applied once, never ignored or compounded")
				for _index: int in range(24):
					_tick(state, -direction, SimCommand.HELD_JUMP)
				check(state.velocity_x * direction.x + state.velocity_y * direction.y < 0, "every air family brakes and reverses under continuous opposition")
				var result := PackedInt64Array([state.velocity_x, state.velocity_y, state.air_velocity_x, state.air_velocity_y, state.hop_speed])
				if reference.is_empty():
					reference = result
				else:
					equal(result, reference, "all lift families share exactly the same coast/brake/turn model")
	var expiring := _state()
	expiring.velocity_x = 400_000
	_tick(expiring, Vector2i.ZERO, 0, SimCommand.PRESSED_JUMP)
	MovementSystem.apply_control_state(expiring, PlayerState.ControlState.SLOWED, 50, Vector2i.ZERO, 0, SimConfig.new(120), 700)
	for _index: int in range(5):
		_tick(expiring, Vector2i.ZERO, SimCommand.HELD_JUMP)
		equal(expiring.velocity_x, 280_000, "midair slow preserves exact coast ratio")
	_tick(expiring, Vector2i.ZERO, SimCommand.HELD_JUMP)
	equal(expiring.velocity_x, 400_000, "slow expiry restores stored momentum, not a damped remnant")


func _test_slide_entry_momentum() -> void:
	var config := SimConfig.new(120)
	for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		for input: Vector2i in [Vector2i.ZERO, direction, -direction, Vector2i(-direction.y, direction.x)]:
			for held: int in [0, SimCommand.HELD_SLIDE]:
				var state := _state()
				state.velocity_x = direction.x * 840
				state.velocity_y = direction.y * 840
				state.facing_x = -direction.x
				state.facing_y = -direction.y
				state.aim_x = -direction.y
				state.aim_y = direction.x
				# Independent first-tick limits: neutral/forward retain heading;
				# side/opposed input can spend only their time-based carve/brake.
				var incoming_speed := 840_000 if direction.x == 0 or direction.y == 0 else 839_873
				var expected_speed := mini(MovementTuning.MAX_AUTHORED_SPEED, incoming_speed + MovementTuning.SLIDE_ENTRY_BOOST) - config.per_tick(MovementTuning.SLIDE_DRAG_PER_SECOND)
				var unsteered_velocity := Vector2i(direction.x * expected_speed / 1000, direction.y * expected_speed / 1000)
				var stamina := state.stamina
				_tick(state, input, held, SimCommand.PRESSED_SLIDE)
				var actual_velocity := Vector2i(state.velocity_x, state.velocity_y)
				if input == Vector2i.ZERO or input == direction:
					equal(Vector2i(state.slide_x, state.slide_y), direction, "neutral/forward slide entry carries the actual incoming heading")
					equal(actual_velocity, unsteered_velocity, "neutral/forward slide keeps bounded radial speed minus one drag tick")
					equal(state.movement_action_speed, expected_speed, "neutral/forward entry grants exactly its one paid bounded boost minus drag")
				else:
					var rate := MovementTuning.SLIDE_BRAKE_PER_SECOND if input == -direction else MovementTuning.SLIDE_CARVE_PER_SECOND
					check((actual_velocity - unsteered_velocity).length() <= config.per_tick(rate) + 2, "opposite/perpendicular entry cannot abruptly erase inherited momentum")
					check(actual_velocity.length() <= unsteered_velocity.length(), "carving/braking cannot accelerate the slide")
					check(absf(actual_velocity.length() - state.movement_action_speed) < 2, "the carried budget records actual post-carve speed, not hidden pre-turn speed")
					check(Vector2i(state.slide_x, state.slide_y).length_squared() <= 1_000_000, "carved heading remains a bounded unit direction")
				check(state.velocity_x * direction.x + state.velocity_y * direction.y > 0, "opposing entry must brake before reversing the incoming lane")
				var sustain_cost := config.per_tick(MovementTuning.SLIDE_SUSTAIN_DRAIN_PER_SECOND) if held != 0 else 0
				equal(state.stamina, stamina - MovementTuning.SLIDE_COST - sustain_cost, "Slide still pays its activation and only requested sustain")
				equal(state.slide_cooldown_ticks, config.milliseconds_to_ticks(MovementTuning.SLIDE_COOLDOWN_MS), "slide entry keeps full paid cooldown")
				equal(state.movement_commitment_ticks, config.milliseconds_to_ticks(MovementTuning.SLIDE_JUMP_MINIMUM_COMMITMENT_MS), "slide entry keeps minimum commitment")
				equal(state.slide_ticks, config.milliseconds_to_ticks(MovementTuning.SLIDE_DURATION_MS if held != 0 else MovementTuning.SLIDE_MINIMUM_MS), "held and released slide duration stay unchanged")
				equal(state.movement_chain_count, 1, "one slide entry buys one chain action")
	var capped := _state()
	capped.velocity_x = 1_200_000
	_tick(capped, Vector2i.ZERO, 0, SimCommand.PRESSED_SLIDE)
	equal(capped.velocity_x, MovementTuning.MAX_AUTHORED_SPEED - config.per_tick(MovementTuning.SLIDE_DRAG_PER_SECOND), "carried overspeed still obeys the existing global cap")
	equal(capped.velocity_y, 0, "capped neutral slide keeps actual heading")
	# Complete taps still carry the exact Slide impulse into real collision;
	# held-gather collision is covered by movement-checkpoint1.
	for direction: Vector2i in [Vector2i(1000, 0), Vector2i(0, 1000), Vector2i(-1000, 0), Vector2i(0, -1000)]:
		var state := _state()
		var world := _arena()
		state.velocity_x = direction.x * 840
		state.velocity_y = direction.y * 840
		_tick(state, direction, SimCommand.HELD_SLIDE, SimCommand.PRESSED_SLIDE, world)
		for _tick_index: int in range(state.movement_commitment_ticks):
			_tick(state, Vector2i.ZERO, SimCommand.HELD_SLIDE, 0, world)
		var carried := Vector2i(state.velocity_x, state.velocity_y)
		_tick(state, Vector2i.ZERO, 0, SimCommand.PRESSED_JUMP, world)
		equal(Vector2i(state.velocity_x, state.velocity_y), carried, "complete Slide Jump tap keeps exact earned momentum")
		check(state.is_airborne() and state.hop_mode == PlayerState.MovementMode.SLIDE_JUMP, "complete Slide Jump tap preserves its paid family")
		var center := Vector2i(state.position_x, state.position_y) + direction * (MovementTuning.PLAYER_RADIUS + 2000) / 1000
		var extent := Vector2i(1000, 100_000) if direction.x != 0 else Vector2i(100_000, 1000)
		world.add_obstacle(CollisionWorld.Obstacle.new(71, center.x - extent.x, center.y - extent.y, center.x + extent.x, center.y + extent.y))
		_tick(state, Vector2i.ZERO, 0, 0, world)
		equal(Vector2i(state.velocity_x, state.velocity_y), Vector2i.ZERO, "head-on collision still clips earned Slide Jump momentum")
		_tick(state, Vector2i.ZERO, 0, 0, world)
		equal(Vector2i(state.velocity_x, state.velocity_y), Vector2i.ZERO, "neutral coast cannot restore the clipped impulse")


func _test_carried_slide_and_fresh_fast_fall() -> void:
	for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		var state := _state()
		state.velocity_x = direction.x * 410_000 / 1000
		state.velocity_y = direction.y * 410_000 / 1000
		_tick(state, direction, SimCommand.HELD_SLIDE, SimCommand.PRESSED_SLIDE)
		for _index: int in range(5):
			_tick(state, direction, SimCommand.HELD_SLIDE)
		_tick(state, direction, SimCommand.HELD_SLIDE | SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
		check(state.jumpsquat_active and not state.is_airborne(), "held Jump prepares slidejump before release")
		_tick(state, direction, SimCommand.HELD_SLIDE)
		equal(state.hop_mode, PlayerState.MovementMode.SLIDE_JUMP, "held C converts legally into slidejump")
		for _index: int in range(3):
			_tick(state, direction, SimCommand.HELD_SLIDE | SimCommand.HELD_JUMP)
			check(not state.fast_falling and not state.fast_fall_armed, "carried C cannot fastfall after takeoff")
		_tick(state, direction, SimCommand.HELD_JUMP)
		_tick(state, direction, SimCommand.HELD_JUMP, SimCommand.PRESSED_SLIDE)
		check(state.fast_falling and state.fast_fall_armed, "fresh airborne wheel-down pulse commits fastfall without a held bit")
		_tick(state, direction, SimCommand.HELD_JUMP)
		check(state.fast_falling or (state.air_height == 0 and state.landing_intensity == MovementTuning.LANDING_SLIDE_JUMP_INTENSITY), "one-shot fastfall stays committed through its immediate low-hop landing")


func _dynamic_jump_fixture(catalog: ChampionCatalog, champion_id: String, direction: Vector2i) -> PlayerState:
	var state := _state()
	check(catalog.apply_to_player(state, champion_id), "dynamic chain uses the actual character profile")
	for _index: int in range(40):
		_tick(state, direction, SimCommand.HELD_SPRINT)
	_tick(state, Vector2i.ZERO, 0, SimCommand.PRESSED_JUMP)
	_wait_commitment(state)
	check(state.is_airborne() and MovementSystem._planar_speed(state) > MovementTuning.SLIDE_ENTRY_SPEED, "real sprint-jump supplies eligible carried speed before descent")
	return state


func _test_paid_slide_boost_routes() -> void:
	var catalog := _held_jump_catalog()
	var config := SimConfig.new(120)
	for champion_id: String in ["s_wayne", "spai_si", "fluup"]:
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			for slow_ratio: int in [1000, 550]:
				var state := _state()
				check(catalog.apply_to_player(state, champion_id), "paid boost tests the real small/middle/large profile")
				for _index: int in range(40):
					_tick(state, direction, SimCommand.HELD_SPRINT)
				if slow_ratio < 1000:
					MovementSystem.apply_control_state(state, PlayerState.ControlState.SLOWED, 1000, Vector2i.ZERO, 0, config, slow_ratio)
					_tick(state, direction, SimCommand.HELD_SPRINT)
				var entry := MovementSystem._retained_speed(state, 0)
				var before := state.stamina
				var cost := MovementSystem._movement_action_cost(state, MovementTuning.SLIDE_COST)
				_tick(state, Vector2i.ZERO, 0, SimCommand.PRESSED_SLIDE)
				var expected := mini(MovementTuning.MAX_AUTHORED_SPEED, entry + 90_000) - config.per_tick(MovementTuning.SLIDE_DRAG_PER_SECOND)
				equal(state.movement_action_speed, expected, "paid entry adds exactly90 units/s before one tick of drag, bounded by900")
				equal(state.stamina, before - cost, "boost has the same positive profile-adjusted Slide purchase")
				check(MovementSystem._planar_speed(state) <= expected * slow_ratio / 1000, "hostile slow applies once after the bounded entry impulse")
				check(not MovementSystem.is_combat_intangible(state, config), "boost adds no timed dodge immunity")
				for _index: int in range(6):
					var budget := state.movement_action_speed
					_tick(state, -direction)
					check(state.movement_action_speed < budget, "counter-steering spends the boosted budget each real tick")
				var budget := state.movement_action_speed
				_tick(state)
				check(state.movement_action_speed <= budget, "neutral release cannot renew the entry boost")
	# Repeated fresh presses buy no more than one impulse per full cooldown,
	# and finite reserves stop admission even with uninterrupted eligible travel.
	var spam := _state()
	spam.stamina = 80_000
	spam.stamina_recovery_per_second = 0
	var accepted := 0
	var previous_admission := -1000
	for index: int in range(600):
		_tick(spam, Vector2i(1000, 0), 0, SimCommand.PRESSED_SLIDE)
		if spam.last_event == "slide" and spam.slide_cooldown_ticks == config.milliseconds_to_ticks(MovementTuning.SLIDE_COOLDOWN_MS):
			accepted += 1
			check(index - previous_admission >= config.milliseconds_to_ticks(MovementTuning.SLIDE_COOLDOWN_MS), "repeated edges never bypass the complete Slide cooldown")
			previous_admission = index
		check(MovementSystem._planar_speed(spam) <= MovementTuning.MAX_AUTHORED_SPEED, "repeated Slide intent never exceeds the authored speed cap")
	check(accepted > 1 and accepted <= 3, "finite80 Stamina buys multiple useful bursts and then stops buying them")
	equal(spam.stamina, 80_000 - accepted * MovementTuning.SLIDE_COST, "repeated purchase accounting has no refund or hidden free burst")


func _test_landing_slide_buffer() -> void:
	var catalog := _held_jump_catalog()
	var config := SimConfig.new(120)
	for champion_id: String in ["s_wayne", "spai_si", "fluup"]:
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			var state := _dynamic_jump_fixture(catalog, champion_id, direction)
			var before := state.stamina
			_tick(state, Vector2i.ZERO, 0, SimCommand.PRESSED_SLIDE)
			check(state.fast_falling and state.slide_buffer_ticks > 0, "fresh airborne Slide owns a finite landing buffer and free descent")
			equal(state.stamina, before, "airborne Slide input itself is still free")
			var landed := false
			var purchased := false
			for _index: int in range(config.milliseconds_to_ticks(MovementTuning.INPUT_BUFFER_MS)):
				var grounded := not state.is_airborne()
				var cost := MovementSystem._movement_action_cost(state, MovementTuning.SLIDE_COST)
				_tick(state)
				if state.slide_ticks > 0:
					check(grounded and landed, "buffered purchase begins only after actual ground contact")
					equal(state.stamina, before - cost, "landing Slide pays the current chain and identity adjusted cost exactly once")
					equal(state.slide_buffer_ticks, 0, "successful landing purchase consumes its sole buffered intent")
					check(not MovementSystem.is_combat_intangible(state, config), "landing chain gains low profile but no dodge immunity")
					purchased = true
					break
				landed = landed or not state.is_airborne()
			check(purchased, "real sprint-jump-fastfall produces one paid landing Slide in all headings and body sizes")
			if not purchased: continue
			var payment := state.stamina
			for _index: int in range(state.movement_commitment_ticks):
				_tick(state)
			var momentum := Vector2i(state.velocity_x, state.velocity_y)
			var jump_cost := MovementSystem._movement_action_cost(state, MovementTuning.SLIDE_JUMP_COST)
			_tick(state, Vector2i.ZERO, 0, SimCommand.PRESSED_JUMP)
			check(state.is_airborne() and state.hop_mode == PlayerState.MovementMode.SLIDE_JUMP, "timed landing Slide chains into the existing paid Slide Jump")
			equal(Vector2i(state.velocity_x, state.velocity_y), momentum, "Slide Jump carries the real remaining landing impulse without another speed bonus")
			equal(state.stamina, payment - jump_cost, "three-action chain pays its second continuation premium")


func _test_landing_slide_buffer_guards() -> void:
	var catalog := _held_jump_catalog()
	var config := SimConfig.new(120)
	for guard: String in ["cooldown", "empty", "slow_entry", "expired", "commitment", "cancel", "newer_evade", "chord", "held_repeat", "active_dodge"]:
		var state := _dynamic_jump_fixture(catalog, "s_wayne", Vector2i(1000, 0))
		if guard == "cooldown": state.slide_cooldown_ticks = 100
		elif guard == "empty":
			state.stamina = 0
			state.stamina_recovery_delay_ticks = 100
		elif guard == "slow_entry":
			state.velocity_x = 0
			state.velocity_y = 0
			state.air_velocity_x = 0
			state.air_velocity_y = 0
		elif guard == "expired": state.air_height = MovementTuning.AIR_MAX_HEIGHT
		elif guard == "commitment": state.movement_commitment_ticks = 30
		elif guard == "held_repeat": state.slide_held_last_tick = true
		elif guard == "active_dodge":
			_tick(state, Vector2i(1000, 0), 0, SimCommand.PRESSED_EVADE)
		var before := state.stamina
		var held := SimCommand.HELD_FAST_FALL if guard == "held_repeat" else 0
		var pressed := 0 if guard == "held_repeat" else SimCommand.PRESSED_SLIDE
		if guard == "chord": pressed |= SimCommand.PRESSED_EVADE
		_tick(state, Vector2i.ZERO, held, pressed)
		if guard in ["cancel", "newer_evade"]:
			_tick(state, Vector2i.ZERO, 0, SimCommand.PRESSED_CANCEL_MOVEMENT if guard == "cancel" else SimCommand.PRESSED_EVADE)
		for _index: int in range(50):
			_tick(state, Vector2i.ZERO, held)
			equal(state.slide_ticks, 0, guard + " cannot purchase a buffered landing Slide")
		check(not state.is_airborne(), guard + " guard still reaches actual ground")
		equal(state.slide_buffer_ticks, 0, guard + " leaves no deferred Slide purchase")
		check(state.stamina >= before, guard + " causes no unexpected Slide payment")
		check(not MovementSystem.is_combat_intangible(state, config), guard + " leaves no revived dodge protection")


func _test_landing_slide_prediction() -> void:
	var catalog := _held_jump_catalog()
	var config := SimConfig.new(120)
	for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		var authority := _dynamic_jump_fixture(catalog, "spai_si", direction)
		authority.entity_id = 2
		var world := _prediction_authority_world(authority, config)
		var prediction := ClientPrediction.new()
		check(prediction.configure(config, _arena(), 2), "landing Slide uses existing serialized action-buffer fields")
		check(prediction.reconcile(ClientPrediction.capture_packet(authority, 0, -1)), "predictor restores a real sprint-jump before fresh descent")
		var packets: Array[Dictionary] = []
		var saw_slide := false
		for index: int in range(22):
			var command := SimCommand.new(index, 2, 0, 0, 0, SimCommand.PRESSED_SLIDE if index == 0 else 0)
			check(prediction.queue_input(index + 1, command), "landing chain command enters real input prediction")
			check(world.step([command]), "all authority stages advance the same landing chain")
			var packet := ClientPrediction.capture_packet(authority, index + 1, index + 1)
			packets.append(packet)
			equal(ClientPrediction.capture_packet(prediction.predicted_state, index + 1, index + 1).values, packet.values, "exact resources, boosts, landing, cost, cooldown and all state fields match authority")
			saw_slide = saw_slide or authority.slide_ticks > 0
			if index == 9:
				check(prediction.reconcile(packets[0], authority.last_event), "delayed acknowledgement replays the unspent prelanding buffer")
				equal(ClientPrediction.capture_packet(prediction.predicted_state, index + 1, index + 1).values, packet.values, "replayed landing purchases precisely the same bounded impulse")
		check(saw_slide, "prediction comparison actually crossed a new paid landing Slide")
		check(prediction.reconcile(packets.back(), authority.last_event), "final acknowledgement retires every buffered command")
		equal(prediction.pending_count(), 0, "landing chain leaves no speculative input behind")


func _test_deliberate_second_jump_flight_contract() -> void:
	var catalog := _held_jump_catalog()
	var config := SimConfig.new(120)
	var perks := preload("res://src/sim/entities/identity_perk_policy.gd")
	for champion_id: String in catalog.ordered_champion_ids():
		var state := _state()
		check(catalog.apply_to_player(state, champion_id), "first/second Jump uses real profile " + champion_id)
		_tick(state, Vector2i.ZERO, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
		for _index: int in range(4):
			_tick(state, Vector2i.ZERO, SimCommand.HELD_JUMP)
			check(state.jumpsquat_active and not state.is_airborne() and not state.air_floating, "first held Jump is ordinary grounded preparation for " + champion_id)
		_tick(state)
		_wait_commitment(state)
		for _index: int in range(2):
			_tick(state)
			check(state.is_airborne() and not state.air_floating and not state.float_used and not state.double_jump_used, "first released Jump cannot automatically spend the second air action for " + champion_id)
			check(not perks._matches(state, "flight_active"), "flight passive cannot trigger from an ordinary first jump")
		var before := state.stamina
		var cost := MovementSystem._movement_action_cost(state, MovementTuning.DOUBLE_JUMP_COST)
		_tick(state, Vector2i.ZERO, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
		if state.flight_capable:
			check(state.air_floating and state.float_ticks > 0 and state.float_used and not state.double_jump_used, "deliberate airborne second Jump buys flight for " + champion_id)
			check(perks._matches(state, "flight_active"), "actual accepted flight owns its existing passive window")
			equal(state.stamina, before - cost - config.per_tick(MovementTuning.FLOAT_DRAIN_PER_SECOND), "second Jump pays flight admission and the first held sustain tick")
			var height := state.air_height
			var deadline := state.float_ticks
			for _index: int in range(4):
				_tick(state, Vector2i.ZERO, SimCommand.HELD_JUMP)
				equal(state.air_height, height, "holding the accepted second Jump sustains real flight height")
				check(state.float_ticks < deadline, "held flight spends rather than renews its finite clock")
				deadline = state.float_ticks
			_tick(state)
			check(not state.air_floating and state.float_used and state.float_ticks == 0, "release ends flight without refunding its airtime allowance")
			check(not perks._matches(state, "flight_active"), "flight passive ends immediately when held flight ends")
		else:
			check(state.double_jump_used and not state.air_floating and not state.float_used, "nonflyer receives a real second jump instead of flight: " + champion_id)
			check(state.air_vertical_velocity > 0, "nonflyer second Jump is actual upward lift")
			equal(state.stamina, before - cost, "nonflyer pays the second-jump cost without flight sustain")
			_tick(state)
		var after_used := state.stamina
		_tick(state, Vector2i.ZERO, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
		for _index: int in range(config.milliseconds_to_ticks(MovementTuning.INPUT_BUFFER_MS)):
			_tick(state, Vector2i.ZERO, SimCommand.HELD_JUMP)
			check(not state.air_floating, "a third Jump cannot restart an already spent second air action after commitment unlocks")
			check(state.stamina >= after_used, "refused third Jump cannot create another paid purchase")
		equal(state.jump_buffer_ticks, 0, "refused third press expires without a deferred flight purchase")
		check(not MovementSystem.is_combat_intangible(state, config), "jump and flight poses never imply timed dodge protection")


func _test_no_op_redirect_and_stale_roll() -> void:
	var state := _state()
	state.velocity_x = 400_000
	_tick(state, Vector2i(1000, 0), 0, SimCommand.PRESSED_JUMP)
	_wait_commitment(state)
	var before := state.stamina
	_tick(state, Vector2i(1000, 0), 0, SimCommand.PRESSED_TECHNIQUE)
	equal(state.stamina, before, "same-direction air turn is free refusal, not a paid no-op")
	equal(state.air_redirects_remaining, 1, "refused no-op retains the finite redirect")
	_tick(state, Vector2i(-1000, 0), 0, SimCommand.PRESSED_TECHNIQUE)
	check(state.velocity_x < 0, "paid sharp reverse immediately changes momentum")
	equal(state.air_redirects_remaining, 0, "meaningful sharp turn consumes the finite redirect")
	check(state.stamina < before, "meaningful sharp turn pays its positive adjusted cost")
	var roller := _state()
	roller.stamina_maximum = 160_000
	roller.stamina = roller.stamina_maximum
	_tick(roller, Vector2i(1000, 0), 0, SimCommand.PRESSED_EVADE)
	_wait_commitment(roller)
	_tick(roller, Vector2i(1000, 0), 0, SimCommand.PRESSED_JUMP)
	check(roller.is_airborne() and not roller.is_rolling(), "committed roll can enter Jump without stale roll timer")
	_wait_commitment(roller)
	roller.air_dodge_cooldown_ticks = 0 # Isolate the mode discriminator from shared cooldown.
	_tick(roller, Vector2i(0, 1000), 0, SimCommand.PRESSED_EVADE)
	equal(roller.hop_mode, PlayerState.MovementMode.AIR_DODGE, "air dodge explicitly owns its mode after a historical roll")
	check(roller.is_airborne() and not roller.is_rolling(), "historical roll never makes air dodge grounded")
	_wait_commitment(roller)
	_tick(roller, Vector2i(0, 1000), 0, SimCommand.PRESSED_JUMP)
	check(roller.double_jump_used, "committed air dodge can spend, not replenish, remaining double jump")
	equal(roller.air_dodge_ticks, 0, "double jump cleanly leaves dodge and its protection clock")


func _late_dodge_state(direction: Vector2i = Vector2i(1000, 0), remaining_commitment: int = 1) -> PlayerState:
	var state := _state()
	state.velocity_x = direction.x * 400
	state.velocity_y = direction.y * 400
	_tick(state, direction, 0, SimCommand.PRESSED_JUMP)
	_wait_commitment(state)
	_tick(state, direction, 0, SimCommand.PRESSED_EVADE)
	while state.movement_commitment_ticks > remaining_commitment:
		_tick(state)
	return state


func _test_paid_redirect_during_dodge_recovery() -> void:
	for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		var state := _late_dodge_state(direction)
		var ordinary := _late_dodge_state(direction)
		var before := state.stamina
		var speed_before := state.movement_action_speed
		var cost := MovementSystem._movement_action_cost(state, MovementTuning.AIR_REDIRECT_COST)
		check(state.is_airborne() and state.air_dodge_ticks > 1 and state.movement_commitment_ticks == 1, "paid route reaches the last committed dodge tick while airborne")
		_tick(state, -direction, 0, SimCommand.PRESSED_TECHNIQUE)
		_tick(ordinary, -direction)
		equal(state.stamina, before - cost, "late-dodge redirect pays exactly its chained Stamina cost")
		equal(state.air_redirects_remaining, 0, "late-dodge redirect consumes its finite air turn")
		check(state.velocity_x * direction.x + state.velocity_y * direction.y < 0, "paid late-dodge reverse changes actual velocity on its admission tick")
		check(ordinary.velocity_x * direction.x + ordinary.velocity_y * direction.y > 0, "ordinary steering cannot impersonate the paid sharp reverse")
		equal(state.air_dodge_ticks, ordinary.air_dodge_ticks, "redirect does not restart or cancel the existing dodge duration")
		equal(state.air_dodge_cooldown_ticks, ordinary.air_dodge_cooldown_ticks, "redirect preserves the dodge cooldown clock")
		check(state.movement_action_speed > ordinary.movement_action_speed, "paid reverse avoids the ordinary counter-steering momentum loss")
		check(state.movement_action_speed <= speed_before - SimConfig.new(120).per_tick(MovementTuning.AIR_DODGE_DRAG_PER_SECOND), "paid reverse cannot enlarge the remaining dodge budget or remove its drag")
		equal(MovementSystem.is_combat_intangible(state, SimConfig.new(120)), MovementSystem.is_combat_intangible(ordinary, SimConfig.new(120)), "redirect cannot renew dodge protection")
		check(not MovementSystem.is_combat_intangible(state, SimConfig.new(120)), "first legal dodge redirect is outside the purchased protection window")
		check(state.air_dodge_used and not state.double_jump_used and not state.float_used, "redirect preserves every other per-airtime allowance")
		var paid := state.stamina
		_tick(state, direction, 0, SimCommand.PRESSED_TECHNIQUE)
		equal(state.stamina, paid, "another sharp turn cannot purchase a second per-airtime redirect")
		equal(state.air_redirects_remaining, 0, "recovery never refreshes the consumed air turn")
	for ratio: int in [500, 750]:
		var slowed := _late_dodge_state()
		check(MovementSystem.apply_control_state(slowed, PlayerState.ControlState.SLOWED, 1000, Vector2i.ZERO, 0, SimConfig.new(120), ratio), "late-dodge fixture accepts an ordinary hostile slow")
		_tick(slowed, Vector2i(-1000, 0), 0, SimCommand.PRESSED_TECHNIQUE)
		check(slowed.velocity_x < 0, "hostile slow cannot swallow an otherwise legal paid dodge redirect")
		equal(slowed.velocity_x, slowed.air_velocity_x * ratio / 1000, "redirect applies the existing slow exactly once to output velocity")


func _test_dodge_recovery_momentum_loss() -> void:
	var catalog := _held_jump_catalog()
	var config := SimConfig.new(120)
	var drag := config.per_tick(MovementTuning.AIR_DODGE_DRAG_PER_SECOND)
	for champion_id: String in ["s_wayne", "spai_si", "fluup"]:
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			for slow_ratio: int in [1000, 550]:
				for turn: Vector2i in [-direction, Vector2i(-direction.y, direction.x)]:
					var state := _profile_late_dodge_state(catalog, champion_id, direction)
					if slow_ratio < 1000:
						check(MovementSystem.apply_control_state(state, PlayerState.ControlState.SLOWED, 1000, Vector2i.ZERO, 0, config, slow_ratio), "recovery fixture receives an ordinary slow")
					var paid := state.stamina
					var cooldown := state.air_dodge_cooldown_ticks
					var duration := state.air_dodge_ticks
					var old_budget := state.movement_action_speed
					_tick(state, turn)
					var braked_speed := Vector2(state.air_velocity_x, state.air_velocity_y).length()
					check(braked_speed < old_budget - drag, "recovery counter-steer and side carve actually remove additional momentum")
					check(state.movement_action_speed <= braked_speed, "remaining paid budget cannot hide speed already lost in recovery steering")
					equal(state.air_dodge_ticks, duration - 1, "recovery steering cannot extend dodge duration")
					check(not MovementSystem.is_combat_intangible(state, config), "recovery steering stays outside the original protection window")
					equal(state.velocity_x, state.air_velocity_x * slow_ratio / 1000, "steered horizontal output applies slow once")
					equal(state.velocity_y, state.air_velocity_y * slow_ratio / 1000, "steered vertical output applies slow once")
					_tick(state)
					var released_speed := Vector2(state.air_velocity_x, state.air_velocity_y).length()
					check(released_speed <= braked_speed - drag + 2, "neutral release cannot resurrect pre-turn dodge speed for any heading or profile")
					equal(state.stamina, paid, "free recovery steering does not refund or add to the original paid cost")
					equal(state.air_dodge_cooldown_ticks, cooldown - 2, "steer and release preserve the existing cooldown clock")
					check(state.air_dodge_used and not state.double_jump_used and not state.float_used, "recovery preserves all finite airborne action allowances")
				var neutral := _profile_late_dodge_state(catalog, champion_id, direction)
				for _index: int in range(3):
					var expected_budget := neutral.movement_action_speed - drag
					var expected_velocity := Vector2i(neutral.air_dodge_x * expected_budget / 1000, neutral.air_dodge_y * expected_budget / 1000)
					_tick(neutral)
					equal(neutral.movement_action_speed, expected_budget, "neutral recovery preserves the existing exact deceleration budget")
					equal(Vector2i(neutral.air_velocity_x, neutral.air_velocity_y), expected_velocity, "neutral recovery preserves exact directional velocity")
	var committed := _late_dodge_state(Vector2i(1000, 0), 2)
	var committed_budget := committed.movement_action_speed
	_tick(committed, Vector2i(-1000, 0))
	equal(committed.movement_action_speed, committed_budget - drag, "opposed input during paid commitment cannot brake early")
	equal(committed.velocity_x, committed.movement_action_speed, "commitment still owns the original dodge lane")
	var analog := _late_dodge_state(MovementSystem._direction(832, 555, Vector2i.ZERO))
	_tick(analog, Vector2i(-832, -555))
	var analog_speed := Vector2(analog.air_velocity_x, analog.air_velocity_y).length()
	_tick(analog)
	check(Vector2(analog.air_velocity_x, analog.air_velocity_y).length() <= analog_speed - drag + 2, "continuous analog recovery keeps its spent momentum too")


func _profile_late_dodge_state(catalog: ChampionCatalog, champion_id: String, direction: Vector2i) -> PlayerState:
	var state := _state()
	check(catalog.apply_to_player(state, champion_id), "recovery route applies actual champion profile " + champion_id)
	state.velocity_x = direction.x * 400
	state.velocity_y = direction.y * 400
	_tick(state, direction, 0, SimCommand.PRESSED_JUMP)
	_wait_commitment(state)
	_tick(state, direction, 0, SimCommand.PRESSED_EVADE)
	while state.movement_commitment_ticks > 1:
		_tick(state)
	check(state.is_airborne() and state.air_dodge_ticks > 3, "profile route reaches a real paid airborne dodge recovery")
	return state


func _test_dodge_recovery_loss_prediction() -> void:
	var config := SimConfig.new(120)
	for slow_ratio: int in [1000, 550]:
		var authority := _late_dodge_state(Vector2i(707, 707))
		authority.entity_id = 2
		if slow_ratio != 1000:
			MovementSystem.apply_control_state(authority, PlayerState.ControlState.SLOWED, 1000, Vector2i.ZERO, 0, config, slow_ratio)
		var authority_world := _prediction_authority_world(authority, config)
		var prediction := ClientPrediction.new()
		check(prediction.configure(config, _arena(), 2), "dodge recovery uses unchanged prediction schema")
		check(prediction.reconcile(ClientPrediction.capture_packet(authority, 0, -1)), "prediction restores the paid pre-recovery state")
		var packets: Array[Dictionary] = []
		for index: int in range(10):
			var move := Vector2i(-707, -707) if index < 2 else Vector2i.ZERO
			var command := SimCommand.new(index, 2, move.x, move.y)
			check(prediction.queue_input(index + 1, command), "brake and release enter real prediction")
			check(authority_world.step([command]), "full authority stages advance dodge recovery prediction route")
			var packet := ClientPrediction.capture_packet(authority, index + 1, index + 1)
			packets.append(packet)
			equal(ClientPrediction.capture_packet(prediction.predicted_state, index + 1, index + 1).values, packet.values, "recovery momentum, payment, timers and protection match authority exactly")
			if index == 4:
				check(prediction.reconcile(packets[0], authority.last_event), "delayed brake acknowledgement replays release without stale carry")
				equal(ClientPrediction.capture_packet(prediction.predicted_state, index + 1, index + 1).values, packet.values, "replayed recovery retains exactly the already reduced dodge budget")
		check(prediction.reconcile(packets.back(), authority.last_event), "final recovery acknowledgement succeeds")
		equal(prediction.pending_count(), 0, "no recovery command remains pending")


func _test_dodge_redirect_guards_and_walls() -> void:
	var buffered := _late_dodge_state(Vector2i(1000, 0), 2)
	var before := buffered.stamina
	var cost := MovementSystem._movement_action_cost(buffered, MovementTuning.AIR_REDIRECT_COST)
	_tick(buffered, Vector2i(-1000, 0), 0, SimCommand.PRESSED_TECHNIQUE)
	equal(buffered.stamina, before, "last still-committed dodge tick cannot pay for an early redirect")
	check(buffered.velocity_x > 0 and buffered.technique_buffer_ticks > 0, "early sharp turn waits in the existing bounded input buffer")
	_tick(buffered, Vector2i(-1000, 0))
	equal(buffered.stamina, before - cost, "buffered sharp turn pays once on the first legal recovery tick")
	check(buffered.velocity_x < 0, "buffered redirect takes effect on its actual admission tick")
	for refusal: String in ["same_direction", "stamina", "spent", "cancel", "rooted"]:
		var state := _late_dodge_state()
		var pressed := SimCommand.PRESSED_TECHNIQUE
		var direction := Vector2i(1000, 0) if refusal == "same_direction" else Vector2i(-1000, 0)
		if refusal == "stamina": state.stamina = MovementSystem._movement_action_cost(state, MovementTuning.AIR_REDIRECT_COST) - 1
		if refusal == "spent": state.air_redirects_remaining = 0
		if refusal == "cancel": pressed |= SimCommand.PRESSED_CANCEL_MOVEMENT
		if refusal == "rooted": MovementSystem.apply_control_state(state, PlayerState.ControlState.ROOTED, 1000, Vector2i.ZERO, 0, SimConfig.new(120))
		var stamina := state.stamina
		var remaining := state.air_redirects_remaining
		_tick(state, direction, 0, pressed)
		equal(state.stamina, stamina, refusal + " cannot create an extra redirect payment")
		equal(state.air_redirects_remaining, remaining, refusal + " cannot consume or renew the air-turn allowance")
	for direction: Vector2i in [Vector2i(1000, 0), Vector2i(0, 1000), Vector2i(-1000, 0), Vector2i(0, -1000)]:
		var state := _late_dodge_state(direction)
		var arena := _arena()
		var x := state.position_x
		var y := state.position_y
		var gap := MovementTuning.PLAYER_RADIUS + 1000
		# Non-runnable solids isolate redirect collision from paid wall attachment.
		if direction.x > 0: arena.add_obstacle(CollisionWorld.Obstacle.new(31, x - gap - 20_000, y - 100_000, x - gap, y + 100_000, false, false))
		elif direction.x < 0: arena.add_obstacle(CollisionWorld.Obstacle.new(31, x + gap, y - 100_000, x + gap + 20_000, y + 100_000, false, false))
		elif direction.y > 0: arena.add_obstacle(CollisionWorld.Obstacle.new(31, x - 100_000, y - gap - 20_000, x + 100_000, y - gap, false, false))
		else: arena.add_obstacle(CollisionWorld.Obstacle.new(31, x - 100_000, y + gap, x + 100_000, y + gap + 20_000, false, false))
		var stamina := state.stamina
		var price := MovementSystem._movement_action_cost(state, MovementTuning.AIR_REDIRECT_COST)
		_tick(state, -direction, 0, SimCommand.PRESSED_TECHNIQUE, arena)
		equal(state.stamina, stamina - price, "blocked redirected travel still pays its admitted sharp-turn cost")
		check(arena.can_occupy(Vector2i(state.position_x, state.position_y), MovementTuning.PLAYER_RADIUS), "redirect respects common eighteen-pixel solid clearance")
		equal(state.velocity_x * direction.x + state.velocity_y * direction.y, 0, "solid contact clips redirected normal velocity")
		equal(state.air_dodge_ticks, 0, "real redirected wall impact ends the dodge through existing collision authority")
		equal(state.air_redirects_remaining, 0, "wall contact never refunds the spent redirect")
		check(state.air_dodge_used and not MovementSystem.is_combat_intangible(state, SimConfig.new(120)), "redirected wall impact grants neither a replacement dodge nor protection")


func _test_dodge_redirect_moving_cast_and_replication() -> void:
	var world := SimWorld.new(120, 817, _arena())
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "moving-cast replication uses the real spell catalog")
	check(HexCourtPractice.configure(world, abilities, false), "moving-cast replication uses complete paid hex authority")
	world.players[0] = _late_dodge_state()
	var actor := world.player()
	actor.champion_wire_id = 1
	actor.position_x = 640_000
	actor.position_y = 710_000
	check(actor.place_proven_spell(0, 179), "moving-cast redirect fixture equips a real Heavy")
	var flux := actor.flux
	var stamina := actor.stamina
	var cost := MovementSystem._movement_action_cost(actor, MovementTuning.AIR_REDIRECT_COST)
	check(world.step([SimCommand.new(world.tick, 1, -1000, 0, 0, SimCommand.PRESSED_TECHNIQUE | SimCommand.PRESSED_SPELL_1, 0, -1000)]), "paid redirect and independently aimed Heavy share one legal authority tick")
	check(actor.velocity_x < 0 and actor.pending_cast_wire_id == 179, "sharp movement turn and paid spell startup both take effect")
	equal(actor.stamina, stamina - cost, "moving cast cannot waive the redirect price")
	equal(actor.flux, flux - int(CombatTuning.cast_definition(179).flux_cost), "redirect cannot waive the Heavy price")
	equal(Vector2i(actor.pending_cast_aim_x, actor.pending_cast_aim_y), Vector2i(0, -1000), "westward dodge turn never retargets northward committed spell aim")
	var packet := HexWorldSnapshot.capture(world)
	check(not packet.is_empty(), "redirect plus paid pending reservation fits the unchanged complete authority schema")
	var replica := HexWorldSnapshot.prepare(packet, world)
	if replica == null:
		check(false, "redirect plus paid pending cast restores through complete snapshot authority")
		return
	equal(replica.state_hash(), world.state_hash(), "complete paid movement and cast authority roundtrips without loss")
	for property_name: StringName in [&"air_dodge_x", &"air_dodge_y", &"air_dodge_ticks", &"air_dodge_cooldown_ticks", &"air_redirects_remaining", &"movement_action_speed", &"pending_cast_aim_x", &"pending_cast_aim_y"]:
		equal(replica.player().get(property_name), actor.get(property_name), "snapshot retains corrected existing state: " + String(property_name))
	var saw_release := false
	for _index: int in range(world.config.milliseconds_to_ticks(int(CombatTuning.cast_definition(179).startup_ms)) + 2):
		for current: SimWorld in [world, replica]:
			check(current.step([SimCommand.new(current.tick, 1, 0, 1000, 0, 0, 1000, 0)]), "snapshot continuation advances moving cast with a new visual aim")
		equal(world.player().canonical_values(), replica.player().canonical_values(), "redirect movement and pending cast replay identically after snapshot restoration")
		equal(world.state_hash(), replica.state_hash(), "complete hex ownership, paid reservation and projectile authority replay identically")
		for projectile: ProjectileState in world.projectiles:
			if projectile.source_wire_id == 179:
				saw_release = true
				check(projectile.velocity_x == 0 and projectile.velocity_y < 0, "released Heavy retains paid northward aim despite movement and later eastward cursor")
	check(saw_release, "combined paid route actually releases its Heavy")


func _test_locked_sustain_and_wall_exits() -> void:
	for control: int in [PlayerState.ControlState.ROOTED, PlayerState.ControlState.STUNNED, PlayerState.ControlState.GRAPPLED, PlayerState.ControlState.CHARGING]:
		for action: int in [SimCommand.PRESSED_JUMP, SimCommand.PRESSED_SLIDE]:
			var state := _state()
			state.velocity_x = 400_000
			_tick(state, Vector2i(1000, 0), SimCommand.HELD_JUMP | SimCommand.HELD_SLIDE, action)
			MovementSystem.apply_control_state(state, control, 1000, Vector2i.ZERO, 0, SimConfig.new(120))
			var before := state.stamina
			for _index: int in range(8):
				_tick(state, Vector2i(1000, 0), SimCommand.HELD_JUMP | SimCommand.HELD_SLIDE)
				equal(state.stamina, before, "locked voluntary sustain never continues charging")
	var arena := _arena()
	arena.add_obstacle(CollisionWorld.Obstacle.new(7, 5_020_000, 4_000_000, 5_048_000, 6_000_000))
	var wall := _state()
	wall.position_x = 5_002_000
	wall.hop_ticks = 20
	wall.air_height = 20_000
	wall.hop_stage = 2
	wall.double_jump_used = true
	wall.float_used = true
	wall.air_redirects_remaining = 0
	wall.wall_contact_id = 7
	wall.wall_memory_ticks = 12
	wall.wall_x = -1000
	_tick(wall, Vector2i(0, 1000), 0, SimCommand.PRESSED_TECHNIQUE, arena)
	check(wall.wall_skim_ticks > 0 and wall.is_airborne(), "wallrun is attached airborne state")
	equal(wall.hop_stage, 2, "wallrun preserves spent double jump")
	equal(wall.air_redirects_remaining, 0, "wallrun preserves spent redirect")
	equal(wall.wall_air_ticks, 20, "wallrun records the remaining original air clock")
	_tick(wall, Vector2i(-1000, 0), 0, 0, arena)
	check(wall.wall_skim_ticks == 0 and wall.hop_ticks > 0, "outward detach has a real airborne successor")
	equal(wall.hop_stage, 2, "detach cannot replenish jump budget")
	equal(wall.jump_protection_ticks, 0, "detach has no new protection")
	_wait_commitment(wall, Vector2i(-1000, 0), arena)
	var before := wall.stamina
	_tick(wall, Vector2i(-1000, 0), 0, SimCommand.PRESSED_JUMP, arena)
	equal(wall.stamina, before, "spent wall air budget refuses unpaid third lift")
	# Newest neutral Technique cancels the pending landing Jump, then observe
	# the unassisted descent. A fresh paid ground Jump at landing remains legal.
	_tick(wall, Vector2i.ZERO, 0, SimCommand.PRESSED_TECHNIQUE, arena)
	for _index: int in range(20):
		_tick(wall, Vector2i(-1000, 0), 0, 0, arena)
	check(not wall.is_airborne(), "wall detach necessarily reaches ground")


func _recovery_controls() -> Array[int]:
	return [PlayerState.ControlState.ROOTED, PlayerState.ControlState.STUNNED, PlayerState.ControlState.GRAPPLED, PlayerState.ControlState.CHARGING, PlayerState.ControlState.LAUNCHED]


func _recovery_ticks(state: PlayerState) -> int:
	return maxi(state.control_ticks, state.impact_recovery_ticks)


func _paid_recovery_fixture(control: int, direction: Vector2i, airborne: bool, remaining: int, catalog: ChampionCatalog = null, champion_id: String = "") -> PlayerState:
	var state := _state()
	var config := SimConfig.new(120)
	if catalog != null:
		check(catalog.apply_to_player(state, champion_id), "late recovery uses an actual body profile and race permission")
	if airborne:
		_tick(state, direction, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
		for _index: int in range(config.milliseconds_to_ticks(MovementTuning.JUMPSQUAT_CHARGE_MS)):
			_tick(state, direction, SimCommand.HELD_JUMP)
		_tick(state, direction)
		check(state.is_airborne() and not state.double_jump_used, "recovery route begins with a real paid charged jump")
	else:
		_tick(state, direction, 0, SimCommand.PRESSED_EVADE)
		check(state.is_rolling(), "ground recovery route begins with a real paid roll")
	equal(state.movement_chain_count, 1, "recovery fixture has exactly one paid predecessor")
	var duration_ms := 25 if control == PlayerState.ControlState.LAUNCHED else 200
	check(MovementSystem.apply_control_state(state, control, duration_ms, direction, 420_000, config), "real interruption enters the requested control state")
	# LAUNCHED must reach its actual impact recovery, not an invented timer.
	while state.control_state == PlayerState.ControlState.LAUNCHED:
		_tick(state, direction)
	while _recovery_ticks(state) > remaining:
		_tick(state, direction)
	equal(_recovery_ticks(state), remaining, "fixture reaches the exact original recovery deadline")
	equal(state.is_airborne(), airborne, "paid recovery route retains its intended ground or air context")
	return state


func _test_late_recovery_jump_buffer() -> void:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "recovery ability content loads")
	var catalog := ChampionCatalog.new()
	check(catalog.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "recovery champion content loads")
	var selected: Dictionary = {}
	for champion_id: String in catalog.ordered_champion_ids():
		var candidate := _state()
		check(catalog.apply_to_player(candidate, champion_id), "recovery profile selection applies real race permissions")
		var body := String(catalog.champions_by_id[champion_id]["body_type"])
		if not candidate.flight_capable and not selected.has(body):
			selected[body] = champion_id
	equal(selected.size(), 3, "late Jump covers actual small, middle and large nonflying profiles")
	for body: String in selected:
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			for control: int in _recovery_controls():
				for airborne: bool in [false, true]:
					for held: bool in [false, true]:
						var state := _paid_recovery_fixture(control, direction, airborne, 2, catalog, selected[body])
						var before := state.stamina
						var cost := MovementSystem._movement_action_cost(state, MovementTuning.DOUBLE_JUMP_COST if airborne else MovementTuning.HOP_COST)
						var held_actions := SimCommand.HELD_JUMP if held else 0
						_tick(state, direction, held_actions, SimCommand.PRESSED_JUMP)
						equal(_recovery_ticks(state), 1, "late Jump cannot shorten the final locked tick")
						equal(state.jump_buffer_ticks, SimConfig.new(120).milliseconds_to_ticks(MovementTuning.INPUT_BUFFER_MS), "fresh Jump keeps the existing 100 ms buffer during recovery")
						equal(state.stamina, before, "locked Jump cannot spend early")
						check(not state.jumpsquat_active and not state.double_jump_used, "locked input starts neither anticipation nor aerial lift")
						var carried_before_unlock := Vector2i(state.velocity_x, state.velocity_y)
						_tick(state, direction, held_actions)
						equal(_recovery_ticks(state), 0, "admission occurs on the original unlock tick")
						if held and not airborne:
							check(state.jumpsquat_active and not state.is_airborne(), "held buffered ground Jump prepares instead of auto-launching")
							var carried_after_unlock := Vector2i(state.velocity_x, state.velocity_y)
							check(carried_after_unlock.length() <= carried_before_unlock.length() and carried_after_unlock.length() >= maxf(0.0, carried_before_unlock.length() - SimConfig.new(120).per_tick(MovementTuning.JUMPSQUAT_DRAG_PER_SECOND) - 2), "buffered held preparation applies one bounded gather drag tick")
							equal(state.stamina, before, "held anticipation has no invented payment")
							_tick(state, direction)
						equal(state.stamina, before - cost, "first legal release pays the original chain-adjusted Jump price once")
						equal(state.movement_chain_count, 2, "buffered Jump adds exactly one paid continuation")
						check(state.is_airborne() and not state.jumpsquat_active, "legal buffered tap or held release creates the requested lift")
						equal(state.double_jump_used, airborne, "air continuation consumes, and ground takeoff does not invent, double-jump allowance")
						equal(state.jump_buffer_ticks, 0, "admitted Jump consumes its buffer")
						check(not MovementSystem.is_combat_intangible(state, SimConfig.new(120)), "recovery Jump grants no protection window")


func _test_recovery_jump_buffer_guards() -> void:
	var config := SimConfig.new(120)
	var window := config.milliseconds_to_ticks(MovementTuning.INPUT_BUFFER_MS)
	var direction := Vector2i(1000, 0)
	for control: int in _recovery_controls():
		for airborne: bool in [false, true]:
			for remaining: int in [window, window + 1]:
				var state := _paid_recovery_fixture(control, direction, airborne, remaining)
				var before := state.stamina
				var cost := MovementSystem._movement_action_cost(state, MovementTuning.DOUBLE_JUMP_COST if airborne else MovementTuning.HOP_COST)
				_tick(state, direction, 0, SimCommand.PRESSED_JUMP)
				while _recovery_ticks(state) > 0:
					var locked_next_tick := _recovery_ticks(state) > 1
					_tick(state, direction)
					if locked_next_tick:
						equal(state.stamina, before, "buffer boundary never buys an early recovery cancel")
				var admitted := remaining == window
				equal(state.movement_chain_count, 2 if admitted else 1, "100 ms window has an exact last valid tick and no extension")
				equal(state.stamina, before - cost if admitted else before, "expired buffer has no delayed payment")
				equal(state.jump_buffer_ticks, 0, "admitted or expired Jump leaves no latent repeat")
			for guard: String in ["cancel", "newer", "relock", "repeat", "empty", "spent"]:
				if guard == "spent" and not airborne:
					continue
				var state := _paid_recovery_fixture(control, direction, airborne, 3)
				if guard == "empty": state.stamina = 0
				if guard == "spent": state.double_jump_used = true
				var before := state.stamina
				var held_actions := SimCommand.HELD_JUMP if guard == "repeat" else 0
				if guard == "repeat":
					# Genuine held input precedes a new interruption. Only a release
					# plus fresh edge may create another Jump, never key repeat.
					_tick(state, direction, held_actions, SimCommand.PRESSED_JUMP)
					check(MovementSystem.apply_control_state(state, PlayerState.ControlState.STUNNED, 25, direction, 0, config), "new interruption cancels the earlier held Jump")
				_tick(state, direction, held_actions, SimCommand.PRESSED_JUMP)
				if guard == "relock":
					check(MovementSystem.apply_control_state(state, PlayerState.ControlState.ROOTED, 25, direction, 0, config), "new hard control clears the preceding buffered intent")
				var next_pressed := SimCommand.PRESSED_CANCEL_MOVEMENT if guard == "cancel" else SimCommand.PRESSED_TECHNIQUE if guard == "newer" else 0
				# Neutral Technique is a deliberate no-op replacement, not a paid tech.
				if guard == "newer": state.stamina = 0
				var expected_stamina := state.stamina
				_tick(state, Vector2i.ZERO, held_actions, next_pressed)
				while _recovery_ticks(state) > 0:
					_tick(state, Vector2i.ZERO, held_actions, SimCommand.PRESSED_JUMP if guard == "repeat" else 0)
				check(not state.jumpsquat_active, guard + " cannot auto-prepare after recovery")
				equal(state.movement_chain_count, 1, guard + " cannot create a paid Jump continuation")
				equal(state.stamina, expected_stamina, guard + " cannot spend or refund recovery resources")
				if guard in ["cancel", "newer", "relock", "repeat"]:
					equal(state.jump_buffer_ticks, 0, guard + " clears or ignores the old Jump")
				if guard == "spent":
					check(state.double_jump_used and state.stamina == before, "recovery cannot replenish a spent aerial allowance")
	# Admission of hard control still cancels preparation that started beforehand.
	var prepared := _state()
	_tick(prepared, direction, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
	check(prepared.jumpsquat_active, "pre-interruption held preparation actually begins")
	check(MovementSystem.apply_control_state(prepared, PlayerState.ControlState.STUNNED, 25, direction, 0, config), "preparation receives a real interruption")
	for _index: int in range(4):
		_tick(prepared, direction, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
	check(not prepared.jumpsquat_active and not prepared.is_airborne(), "interrupted held preparation never resumes from key repeats")
	equal(prepared.movement_chain_count, 0, "interrupted unspent preparation creates no paid action")


func _test_recovery_jump_prediction() -> void:
	var config := SimConfig.new(120)
	for control: int in _recovery_controls():
		for airborne: bool in [false, true]:
			var authority := _paid_recovery_fixture(control, Vector2i(1000, 0), airborne, 3)
			authority.entity_id = 2
			var authority_world := _prediction_authority_world(authority, config)
			var prediction := ClientPrediction.new()
			check(prediction.configure(config, _arena(), 2), "recovery prediction configures with unchanged authority fields")
			check(prediction.reconcile(ClientPrediction.capture_packet(authority, 0, -1)), "recovery prediction restores the paid locked state")
			var packets: Array[Dictionary] = []
			for index: int in range(8):
				var pressed := SimCommand.PRESSED_JUMP if index == 0 else 0
				var command := SimCommand.new(index, 2, 0, -1000, 0, pressed)
				check(prediction.queue_input(index + 1, command), "late recovery input enters prediction")
				check(authority_world.step([command]), "full authority stages advance recovery Jump prediction route")
				var packet := ClientPrediction.capture_packet(authority, index + 1, index + 1)
				packets.append(packet)
				equal(ClientPrediction.capture_packet(prediction.predicted_state, index + 1, index + 1).values, packet.values, "prediction exactly matches every buffer, lock, payment and movement field")
				if index == 3:
					check(prediction.reconcile(packets[1], authority.last_event), "delayed locked acknowledgement replays the legal unlock")
					equal(ClientPrediction.capture_packet(prediction.predicted_state, index + 1, index + 1).values, packet.values, "late Jump replay agrees after restoring an in-lock buffer")
			equal(authority.movement_chain_count, 2, "prediction route actually admits one paid post-recovery Jump")
			check(prediction.reconcile(packets.back(), authority.last_event), "final recovery acknowledgement drains history")
			equal(prediction.pending_count(), 0, "no late recovery intent remains in prediction history")


func _test_slow_cannot_cancel_forced_control() -> void:
	var config := SimConfig.new(120)
	var policy := ActionTransitionPolicy.new()
	check(policy.load_from_file(), "forced-control overlap uses the live cast policy")
	for control: int in [PlayerState.ControlState.LAUNCHED, PlayerState.ControlState.GRAPPLED, PlayerState.ControlState.CHARGING, PlayerState.ControlState.STUNNED, PlayerState.ControlState.ROOTED]:
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			var state := _state()
			check(MovementSystem.apply_control_state(state, control, 50, direction, 420_000, config), "hard control is accepted before overlapping slow")
			var before := state.canonical_values()
			check(not MovementSystem.apply_control_state(state, PlayerState.ControlState.SLOWED, 650, Vector2i.ZERO, 0, config, 550), "lower-priority slow cannot replace an active hard-control clock")
			check(state.canonical_values() == before, "refused slow changes no velocity, timer, resource, protection or air allowance")
			equal(policy.cast_gate_reason(state), "control_%s" % ActionTransitionPolicy.control_state_id(control), "slow cannot reopen casting during forced control")
			for _tick_index: int in range(config.milliseconds_to_ticks(50)):
				_tick(state)
			equal(state.control_ticks, 0, "hard control expires on its original deadline")
			check(MovementSystem.apply_control_state(state, PlayerState.ControlState.SLOWED, 650, Vector2i.ZERO, 0, config, 550), "a fresh slow may apply after hard-control expiry")
			equal(state.slow_ratio, 550, "post-expiry slow uses its authored ratio without a deferred stack")
	var chemistry := preload("res://src/sim/chemistry/element_chemistry_system.gd")
	var victim := _state()
	victim.team_id = 2
	var at := Vector2i(victim.position_x, victim.position_y)
	var deposits: Array = []
	for element: int in [1, 3]:
		equal(chemistry.deposit_terminal(deposits, element, element, 100, 1, 1, element, at, 0, config), 1, "real Earth/Water terminal ingredients admit")
	var reactions: Array = []
	var events: Array = []
	chemistry.step(deposits, reactions, [], _arena(), config, 0, 4000, events)
	equal(reactions.size(), 1, "real terminal ingredients form one Mud reaction")
	var mud: ElementReactionState = reactions[0]
	equal(mud.recipe_wire_id, 303, "overlap fixture uses authoritative Mud")
	var tideline := CombatTuning.cast_definition(141)
	check(MovementSystem.apply_control_state(victim, int(tideline["hit_control_state"]), int(tideline["hit_control_duration_ms"]), Vector2i(1000, 0), int(tideline["hit_control_speed"]), config), "actual Tideline control definition applies")
	_tick(victim)
	var launched := victim.canonical_values()
	chemistry.step(deposits, reactions, [victim], _arena(), config, mud.active_tick, 4001, events)
	check(victim.canonical_values() == launched, "active Mud cannot erase the accepted Tideline launch")
	equal(policy.cast_gate_reason(victim), "control_launched", "Mud contact leaves the Tideline casting gate intact")
	var field := FieldState.new(2000, 3, 1, 158, 3, at, 85000, 100, PlayerState.ControlState.SLOWED, 650, 700)
	var field_events: Array[Dictionary] = []
	CombatSystem.advance_fields([field], [victim], config, field_events)
	check(victim.canonical_values() == launched, "an actual slowing Field cannot replace forced launch either")
	check(field.has_affected(victim.entity_id), "one-shot Field contact is consumed, not queued for a later hidden slow")
	var already_slow := _state()
	already_slow.velocity_x = 100_000
	MovementSystem.apply_control_state(already_slow, PlayerState.ControlState.SLOWED, 100, Vector2i.ZERO, 0, config, 700)
	check(MovementSystem.apply_control_state(already_slow, PlayerState.ControlState.SLOWED, 200, Vector2i.ZERO, 0, config, 550), "existing slow-to-slow updates remain accepted")
	equal(already_slow.velocity_x, 55000, "stronger slow preserves one proportional scale, without compounding")
	equal(already_slow.control_ticks, config.milliseconds_to_ticks(200), "ordinary slow replacement retains its authored duration")


func _test_wavedash_landing_protection() -> void:
	for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		var state := _state()
		state.hop_ticks = 8
		state.air_height = 12_000
		state.air_vertical_velocity = -120_000
		state.hop_stage = 1
		state.hop_x = direction.x
		state.hop_y = direction.y
		_tick(state, direction, 0, SimCommand.PRESSED_EVADE)
		check(state.wave_dash_queued, "same-direction low dodge earns wavedash without angle requirement")
		var protected_ticks := 0
		for _index: int in range(60):
			if MovementSystem.is_combat_intangible(state, SimConfig.new(120)):
				protected_ticks += 1
			if state.wave_dash_ticks > 0:
				check(not MovementSystem.is_combat_intangible(state, SimConfig.new(120)), "wavedash landing cannot refresh dodge protection")
			_tick(state, direction)
		check(protected_ticks > 0 and protected_ticks <= SimConfig.new(120).milliseconds_to_ticks(MovementTuning.AIR_DODGE_INVULNERABILITY_MS), "real landing ends protection no later than the purchased dodge window")


func _fast_fall_dodge_fixture(catalog: ChampionCatalog, champion_id: String, direction: Vector2i) -> PlayerState:
	var state := _state()
	check(catalog.apply_to_player(state, champion_id), "fast-fall route applies actual profile costs and air permissions")
	_tick(state, direction, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
	var hop_cost := MovementSystem._movement_action_cost(state, MovementTuning.HOP_COST)
	_tick(state, direction)
	_wait_commitment(state, direction)
	check(state.is_airborne() and state.air_vertical_velocity > 0, "fast-fall route starts from an actual released Jump, still rising")
	var dodge_cost := MovementSystem._movement_action_cost(state, MovementTuning.AIR_DODGE_COST)
	check(hop_cost > 0 and dodge_cost > 0, "both original actions retain positive contextual Stamina prices")
	_tick(state, direction, 0, SimCommand.PRESSED_EVADE)
	check(state.air_dodge_used and state.air_dodge_ticks > 0 and not state.wave_dash_queued, "paid high dodge cannot qualify through the original natural landing forecast")
	equal(state.stamina, state.stamina_maximum - hop_cost - dodge_cost, "Jump then Evade pays exactly its two chain- and identity-adjusted quotes before any landing conversion")
	return state


func _test_fast_fall_wavedash_routes() -> void:
	var catalog := _held_jump_catalog()
	var config := SimConfig.new(120)
	var bodies: Dictionary = {}
	for champion_id: String in catalog.ordered_champion_ids():
		bodies[String(catalog.champions_by_id[champion_id]["body_type"])] = true
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			for slide_edge: Vector2i in [Vector2i(SimCommand.PRESSED_SLIDE, 0), Vector2i(0, SimCommand.HELD_FAST_FALL)]:
				var state := _fast_fall_dodge_fixture(catalog, champion_id, direction)
				var paid_stamina := state.stamina
				var dodge_cooldown := state.air_dodge_cooldown_ticks
				var entry_speed := MovementSystem._planar_speed(state)
				var landing_age := 0
				for age: int in range(1, 20):
					_tick(state, direction, slide_edge.y, slide_edge.x if age == 1 else 0)
					equal(state.stamina, paid_stamina, "deliberate descent and actual landing add no hidden purchase")
					if not state.is_airborne():
						landing_age = age
						break
					check(state.fast_falling and state.air_dodge_used, "fresh Slide changes height without refunding the paid airborne dodge")
				check(landing_age > 0 and landing_age < config.milliseconds_to_ticks(MovementTuning.WAVE_DASH_INPUT_WINDOW_MS), "real fast-fall reaches ground inside the existing short dodge clock")
				equal(state.last_event, "wave_dash", "real high-dodge then fresh fast-fall earns the grounded route")
				equal(state.wave_dash_ticks, config.milliseconds_to_ticks(MovementTuning.WAVE_DASH_DURATION_MS), "new route receives only the existing finite wavedash")
				equal(state.movement_commitment_ticks, config.milliseconds_to_ticks(MovementTuning.WAVE_DASH_COMMITMENT_MS), "ground contact retains the existing landing commitment")
				equal(state.air_dodge_cooldown_ticks, dodge_cooldown - landing_age, "landing never refreshes or removes the original dodge cooldown")
				equal(state.movement_chain_count, 2, "fast-fall conversion is not an extra paid chain action")
				check(not MovementSystem.is_combat_intangible(state, config), "grounded fast-fall wavedash cannot renew aerial protection")
				check(MovementSystem._planar_speed(state) > MovementTuning.SLIDE_ENTRY_SPEED and MovementSystem._planar_speed(state) <= entry_speed, "landing preserves useful earned travel without inventing speed")
				check(not state.double_jump_used and not state.float_used and not state.air_dodge_used and state.air_redirects_remaining == 0, "only actual landing resets airtime allowances and grants no redirect")
				# Both available exits must wait for the same paid landing commitment.
				var exit_action := SimCommand.PRESSED_JUMP if slide_edge.x != 0 else SimCommand.PRESSED_SLIDE
				var exit_cost := MovementSystem._movement_action_cost(state, MovementTuning.HOP_COST if exit_action == SimCommand.PRESSED_JUMP else MovementTuning.SLIDE_COST)
				var commitment := state.movement_commitment_ticks
				for age: int in range(1, commitment + 1):
					_tick(state, direction, 0, exit_action if age == 1 else 0)
					if age < commitment:
						equal(state.stamina, paid_stamina, "buffered exit cannot buy a cancel before landing commitment ends")
						check(not state.is_airborne() and state.slide_ticks == 0, "buffered exit cannot leave the earned ground route early")
				check(state.is_airborne() if exit_action == SimCommand.PRESSED_JUMP else state.slide_ticks > 0, "fresh buffered Jump or Slide chains on the first legal landing tick")
				equal(state.stamina, paid_stamina - exit_cost, "grounded follow-up pays its unchanged continuation cost once")
				equal(state.movement_chain_count, 3, "deliberate landing follow-up remains a three-purchase route")
	equal(bodies.size(), 3, "fast-fall route covers the complete actual roster and all three body sizes")


func _test_fast_fall_wavedash_window_and_guards() -> void:
	var catalog := _held_jump_catalog()
	var config := SimConfig.new(120)
	var direction := Vector2i(1000, 0)
	var window := config.milliseconds_to_ticks(MovementTuning.WAVE_DASH_INPUT_WINDOW_MS)
	# Actual delayed-command routes exercise useful timing, not injected height.
	for slide_delay: int in range(1, 13):
		var state := _fast_fall_dodge_fixture(catalog, "grace_reava", direction)
		var paid_stamina := state.stamina
		var landing_age := -1
		for age: int in range(1, 45):
			_tick(state, direction, 0, SimCommand.PRESSED_SLIDE if age == slide_delay else 0)
			if not state.is_airborne():
				landing_age = age
				break
		check(landing_age > 0, "every delayed fast-fall route reaches actual ground")
		equal(state.wave_dash_ticks > 0, landing_age < window, "actual landing, not fast-fall press time, owns the finite dodge conversion window")
		equal(state.stamina, paid_stamina, "late descent cannot purchase or refund movement")
	# Boundary isolation uses a real paid predecessor, then places only its final
	# contact/timer to either side of the last eligible simulation tick.
	for elapsed: int in [window - 1, window]:
		var boundary := _fast_fall_dodge_fixture(catalog, "grace_reava", direction)
		boundary.air_height = 1
		boundary.air_vertical_velocity = -MovementTuning.AIR_FAST_FALL_SPEED
		boundary.air_dodge_ticks = config.milliseconds_to_ticks(MovementTuning.AIR_DODGE_DURATION_MS) - elapsed + 1
		_tick(boundary, direction, 0, SimCommand.PRESSED_SLIDE)
		equal(boundary.wave_dash_ticks > 0, elapsed < window, "last opening-window tick qualifies and the immediately following tick does not")
	for refusal: String in ["no_slide", "chord", "cancel", "neutral", "poor", "spent", "rooted", "stunned", "charging", "grappled", "launched", "impact", "wall"]:
		var state := _fast_fall_dodge_fixture(catalog, "grace_reava", direction)
		var arena := _arena()
		var pressed := SimCommand.PRESSED_SLIDE
		var held := 0
		if refusal in ["poor", "spent"]:
			# Refuse a genuine first dodge from an otherwise real paid Jump.
			state = _paid_profile_jump(catalog, "grace_reava", direction, arena)
			if refusal == "poor": state.stamina = MovementSystem._movement_action_cost(state, MovementTuning.AIR_DODGE_COST) - 1
			else: state.air_dodge_used = true
			_tick(state, direction, 0, SimCommand.PRESSED_EVADE)
			check(state.air_dodge_ticks == 0, "unaffordable or spent dodge never starts a convertible paid action")
		if refusal == "no_slide": pressed = 0
		if refusal == "neutral":
			state = _paid_profile_jump(catalog, "grace_reava", direction, arena)
			_tick(state, Vector2i.ZERO, 0, SimCommand.PRESSED_EVADE)
			check(state.fast_falling and state.air_dodge_ticks == 0, "neutral Evade remains a free descent, not a paid directional dodge")
			pressed = 0
		if refusal == "chord":
			# Start over so the losing held Slide is captured with the Evade edge.
			state = _paid_profile_jump(catalog, "grace_reava", direction, arena)
			_tick(state, direction, SimCommand.HELD_FAST_FALL, SimCommand.PRESSED_EVADE | SimCommand.PRESSED_SLIDE)
			pressed = 0
			held = SimCommand.HELD_FAST_FALL
		if refusal == "cancel": pressed |= SimCommand.PRESSED_CANCEL_MOVEMENT
		if refusal in ["rooted", "stunned", "charging", "grappled", "launched", "impact"]:
			_tick(state, direction, 0, SimCommand.PRESSED_SLIDE)
			var control := PlayerState.ControlState.ROOTED
			if refusal == "stunned": control = PlayerState.ControlState.STUNNED
			elif refusal == "charging": control = PlayerState.ControlState.CHARGING
			elif refusal == "grappled": control = PlayerState.ControlState.GRAPPLED
			elif refusal == "launched": control = PlayerState.ControlState.LAUNCHED
			MovementSystem.apply_control_state(state, control, 1000, Vector2i.ZERO, 0, config)
			if refusal == "impact": MovementSystem._begin_impact_recovery(state, config)
			pressed = 0
		if refusal == "wall":
			var face := state.position_x + MovementTuning.PLAYER_RADIUS + 1000
			arena.add_obstacle(CollisionWorld.Obstacle.new(32, face, state.position_y - 100_000, face + 20_000, state.position_y + 100_000, false, false))
		var before := state.stamina
		for age: int in range(40):
			_tick(state, direction, held, pressed if age == 0 else 0, arena)
			equal(state.wave_dash_ticks, 0, refusal + " cannot manufacture a fast-fall wavedash")
			if not state.is_airborne(): break
		check(not state.is_airborne(), refusal + " control reaches real ground without a deferred conversion")
		equal(state.stamina, before, refusal + " preserves payment without a phantom landing purchase/refund")
		check(not MovementSystem.is_combat_intangible(state, config), refusal + " landing has no renewed dodge protection")
	var cancelled := _fast_fall_dodge_fixture(catalog, "grace_reava", direction)
	_tick(cancelled, direction, 0, SimCommand.PRESSED_SLIDE)
	var paid := cancelled.stamina
	_tick(cancelled, direction, 0, SimCommand.PRESSED_CANCEL_MOVEMENT)
	check(cancelled.fast_falling and cancelled.air_dodge_ticks > 0, "cancel clears new input without undoing the already committed paid dodge and descent")
	for _index: int in range(12):
		if not cancelled.is_airborne(): break
		_tick(cancelled, direction)
	check(cancelled.wave_dash_ticks > 0, "accepted physical descent still converts on its original clock after input cancellation")
	equal(cancelled.stamina, paid, "cancelled input cannot refund or repurchase the committed route")


func _test_fast_fall_wavedash_prediction() -> void:
	var catalog := _held_jump_catalog()
	var config := SimConfig.new(120)
	for slow_ratio: int in [1000, 550]:
		var authority := _fast_fall_dodge_fixture(catalog, "grace_reava", Vector2i(1000, 0))
		authority.entity_id = 2
		if slow_ratio != 1000:
			MovementSystem.apply_control_state(authority, PlayerState.ControlState.SLOWED, 1000, Vector2i.ZERO, 0, config, slow_ratio)
		var authority_world := _prediction_authority_world(authority, config)
		var prediction := ClientPrediction.new()
		check(prediction.configure(config, _arena(), 2), "fast-fall wavedash uses the unchanged prediction state schema")
		check(prediction.reconcile(ClientPrediction.capture_packet(authority, 0, -1)), "prediction restores the real paid high dodge")
		var packets: Array[Dictionary] = []
		var saw_wavedash := false
		for index: int in range(18):
			var command := SimCommand.new(index, 2, 1000, 0, 0, SimCommand.PRESSED_SLIDE if index == 0 else 0)
			var already_grounded := authority.wave_dash_ticks > 0
			var expected_velocity := authority.movement_action_speed * slow_ratio / 1000
			check(prediction.queue_input(index + 1, command), "fresh fast-fall command enters actual prediction")
			check(authority_world.step([command]), "full authority stages advance fast-fall wavedash prediction route")
			if already_grounded:
				equal(authority.velocity_x, expected_velocity, "landing retains unslowed momentum and applies the current hostile slow exactly once")
				check(not MovementSystem.is_combat_intangible(authority, config), "continued ground travel never restores dodge protection")
			var packet := ClientPrediction.capture_packet(authority, index + 1, index + 1)
			packets.append(packet)
			saw_wavedash = saw_wavedash or authority.wave_dash_ticks > 0
			equal(ClientPrediction.capture_packet(prediction.predicted_state, index + 1, index + 1).values, packet.values, "all landing, payment, momentum, cooldown and protection fields match prediction")
			if index == 8:
				check(prediction.reconcile(packets[1], authority.last_event), "delayed prelanding acknowledgement replays actual ground conversion")
				equal(ClientPrediction.capture_packet(prediction.predicted_state, index + 1, index + 1).values, packet.values, "replayed conversion produces the exact authoritative state")
		check(saw_wavedash, "ordinary and slowed paid routes both reach the new legal landing conversion")
		check(prediction.reconcile(packets.back(), authority.last_event), "final fast-fall route acknowledgement succeeds")
		equal(prediction.pending_count(), 0, "conversion leaves no latent prediction inputs")


func _test_fast_fall_wavedash_snapshot() -> void:
	var catalog := _held_jump_catalog()
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "snapshot route loads real paid-court abilities")
	var world := SimWorld.new(120, 818, _arena())
	var repeat := SimWorld.new(120, 818, _arena())
	for current: SimWorld in [world, repeat]:
		check(HexCourtPractice.configure(current, abilities, false), "snapshot route uses complete hex authority")
		check(catalog.apply_to_player(current.player(), "grace_reava"), "snapshot route uses actual Grace")
	var saw_wavedash := false
	for index: int in range(36):
		var held := SimCommand.HELD_JUMP if index == 0 else 0
		var pressed := SimCommand.PRESSED_JUMP if index in [0, 24] else SimCommand.PRESSED_EVADE if index == 12 else SimCommand.PRESSED_SLIDE if index == 13 else 0
		for current: SimWorld in [world, repeat]:
			check(current.step([SimCommand.new(current.tick, 1, 1000, 0, held, pressed)]), "real paid fast-fall route advances through complete world authority")
		equal(repeat.state_hash(), world.state_hash(), "complete world hashes repeat before and after actual fast-fall landing")
		saw_wavedash = saw_wavedash or world.player().wave_dash_ticks > 0
		if index == 13:
			check(world.player().fast_falling and not world.player().wave_dash_queued and world.player().is_airborne(), "snapshot is captured after accepted descent but before its previously unqualified landing")
			var packet := HexWorldSnapshot.capture(world)
			check(not packet.is_empty(), "fast-fall predecessor fits the unchanged complete snapshot")
			var restored := HexWorldSnapshot.prepare(packet, world)
			if restored == null:
				check(false, "complete prelanding snapshot restores")
				return
			repeat = restored
			equal(repeat.state_hash(), world.state_hash(), "prelanding snapshot preserves exact paid authority without a new wavedash field")
	check(saw_wavedash, "complete-world route actually uses the new grounded conversion")
	equal(world.player().movement_chain_count, 3, "restored route retains the genuine paid Jump after landing commitment")


func _test_profile_routes_and_repeat_hashes() -> void:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "route ability content loads")
	var catalog := ChampionCatalog.new()
	check(catalog.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "route champion content loads")
	var selected: Dictionary = {}
	for champion_id: String in catalog.ordered_champion_ids():
		var body := String(catalog.champions_by_id[champion_id]["body_type"])
		if not selected.has(body):
			selected[body] = champion_id
	equal(selected.size(), 3, "route fixtures cover actual small, middle and large champion stats")
	for body: String in selected:
		var minimum_remaining := 999_999
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			for reverse: bool in [false, true]:
				var first := SimWorld.new(120, 41, _arena())
				var repeat := SimWorld.new(120, 41, _arena())
				for world: SimWorld in [first, repeat]:
					check(catalog.apply_to_player(world.player(), selected[body]), "real champion stats apply to movement route")
					world.player().position_x = 5_000_000
					world.player().position_y = 5_000_000
				for tick: int in range(90):
					var move := -direction if reverse and tick >= 55 else direction
					var pressed := SimCommand.PRESSED_SLIDE if tick == 40 else SimCommand.PRESSED_JUMP if tick == 45 else SimCommand.PRESSED_EVADE if tick == 55 else 0
					var held := SimCommand.HELD_SPRINT if tick < 40 else 0
					for world: SimWorld in [first, repeat]:
						check(world.step([SimCommand.new(tick, 1, move.x, move.y, held, pressed)]), "legal route tick succeeds")
						var state := world.player()
						check(state.stamina >= 0, "paid route cannot underflow resource reserve")
						check(state.velocity_x * state.velocity_x + state.velocity_y * state.velocity_y <= MovementTuning.MAX_AUTHORED_SPEED * MovementTuning.MAX_AUTHORED_SPEED, "route cannot farm velocity beyond authority cap")
					equal(first.player().canonical_values(), repeat.player().canonical_values(), "every route tick has identical complete canonical state on replay")
					if tick == 55:
						equal(first.player().movement_chain_count, 3, "three-action chase/escape route is affordable for every body and direction")
						check(first.player().velocity_x * move.x + first.player().velocity_y * move.y > 0, "paid exit chooses the intended chase or escape lane")
						minimum_remaining = mini(minimum_remaining, first.player().stamina)
				check(first.state_hash() == repeat.state_hash(), "complete world hash repeats after route")
		print("movement route ", body, " champion=", selected[body], " minimum Stamina after Slide-Jump-Evade=", minimum_remaining)
		check(minimum_remaining > 10_000, "route leaves a meaningful reserve without economy reductions")
