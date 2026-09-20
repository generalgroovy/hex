extends FluxTestSuite


func run() -> int:
	equal(MovementTuning.EVADE_INTENT_POLICY_ID, "evade-current-intent-directional-dodge-neutral-fast-fall-v1", "same-build compatibility names the exact Evade intent policy")
	_test_continuous_angles_and_accumulated_turns()
	_test_one_intent_and_commitment()
	_test_evade_current_intent_and_chords()
	_test_air_families_and_slow()
	_test_carried_slide_and_fresh_fast_fall()
	_test_no_op_redirect_and_stale_roll()
	_test_locked_sustain_and_wall_exits()
	_test_slow_cannot_cancel_forced_control()
	_test_wavedash_landing_protection()
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
	for ratio: int in [MovementTuning.SLIDE_STEERING, MovementTuning.WAVE_DASH_STEERING]:
		for requested: Vector2i in [Vector2i(0, -1000), Vector2i(-1000, 0)]:
			var value := Vector2i(1000, 0)
			var command := SimCommand.new(0, 1, requested.x, requested.y)
			var slowed_on_turn := false
			for _index: int in range(24):
				value = MovementSystem._steer(value, requested, command, ratio)
				slowed_on_turn = slowed_on_turn or value.length_squared() < 700_000
			check(value.x * requested.x + value.y * requested.y > 950_000, "accumulated slide/wavedash steering completes a perpendicular or opposite turn")
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
	_tick(expiring, Vector2i.ZERO, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
	MovementSystem.apply_control_state(expiring, PlayerState.ControlState.SLOWED, 50, Vector2i.ZERO, 0, SimConfig.new(120), 700)
	for _index: int in range(5):
		_tick(expiring, Vector2i.ZERO, SimCommand.HELD_JUMP)
		equal(expiring.velocity_x, 280_000, "midair slow preserves exact coast ratio")
	_tick(expiring, Vector2i.ZERO, SimCommand.HELD_JUMP)
	equal(expiring.velocity_x, 400_000, "slow expiry restores stored momentum, not a damped remnant")


func _test_carried_slide_and_fresh_fast_fall() -> void:
	for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		var state := _state()
		state.velocity_x = direction.x * 410_000 / 1000
		state.velocity_y = direction.y * 410_000 / 1000
		_tick(state, direction, SimCommand.HELD_SLIDE, SimCommand.PRESSED_SLIDE)
		for _index: int in range(5):
			_tick(state, direction, SimCommand.HELD_SLIDE)
		_tick(state, direction, SimCommand.HELD_SLIDE | SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
		equal(state.hop_mode, PlayerState.MovementMode.SLIDE_JUMP, "held C converts legally into slidejump")
		for _index: int in range(3):
			_tick(state, direction, SimCommand.HELD_SLIDE | SimCommand.HELD_JUMP)
			check(not state.fast_falling and not state.fast_fall_armed, "carried C cannot fastfall after takeoff")
		_tick(state, direction, SimCommand.HELD_JUMP)
		_tick(state, direction, SimCommand.HELD_JUMP, SimCommand.PRESSED_SLIDE)
		check(state.fast_falling and state.fast_fall_armed, "fresh airborne wheel-down pulse commits fastfall without a held bit")
		_tick(state, direction, SimCommand.HELD_JUMP)
		check(state.fast_falling or (state.air_height == 0 and state.landing_intensity == MovementTuning.LANDING_SLIDE_JUMP_INTENSITY), "one-shot fastfall stays committed through its immediate low-hop landing")


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
	check(roller.float_used, "committed air dodge can spend, not replenish, remaining Float")
	equal(roller.air_dodge_ticks, 0, "double jump cleanly leaves dodge and its protection clock")


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
