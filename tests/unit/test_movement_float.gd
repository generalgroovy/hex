extends FluxTestSuite


var config := SimConfig.new(120)
var arena := CollisionWorld.new(10_000_000, 10_000_000)


func run() -> int:
	_test_held_float_all_directions()
	_test_fractional_drain_and_exhaustion()
	_test_interruptions_and_budgets()
	_test_recovery_spend_hooks()
	_test_replay()
	_test_size_caps_and_wall_chain()
	return finish("movement-float")


func _air_state() -> PlayerState:
	var state := PlayerState.new(1)
	state.position_x = 5_000_000
	state.position_y = 5_000_000
	state.air_height = 50_000
	state.air_vertical_velocity = -100_000
	state.hop_stage = 1
	state.hop_ticks = MovementSystem._remaining_air_ticks(state, config)
	return state


func _step(state: PlayerState, direction: Vector2i = Vector2i.ZERO, held: int = 0, pressed: int = 0, collision: CollisionWorld = null) -> void:
	MovementSystem.step(state, SimCommand.new(0, 1, direction.x, direction.y, held, pressed), config, arena if collision == null else collision)


func _begin(state: PlayerState, direction: Vector2i = Vector2i.ZERO) -> void:
	_step(state, direction, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
	check(state.air_floating, "fresh airborne Jump enters affordable Float")
	check(state.float_used, "Float spends its independent once-per-airtime allowance")


func _test_held_float_all_directions() -> void:
	for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		var state := _air_state()
		var height := state.air_height
		var starting_stamina := state.stamina
		_begin(state, direction)
		var health_before := state.health
		check(not PlayerResourcesSystem.damage(state, 1000, config), "active Float rejects real authoritative damage")
		equal(state.health, health_before, "Float damage refusal preserves health")
		for tick: int in range(1, 121):
			_step(state, direction if tick < 60 else -direction, SimCommand.HELD_JUMP)
			equal(state.air_height, height, "held Float maintains exact current height without extra lift")
			equal(state.air_vertical_velocity, 0, "held Float has zero vertical speed")
			check(MovementSystem.is_combat_intangible(state, config), "held affordable Float remains protected beyond the old short jump window")
			equal(state.stamina_recovery_idle_ticks, 0, "every paid Float tick resets Stamina recovery age")
		check(state.velocity_x * direction.x + state.velocity_y * direction.y < 0, "Float freely steers and reverses in every direction")
		equal(starting_stamina - state.stamina, MovementTuning.FLOAT_COST + 100_833, "121 Float ticks preserve exact fractional100-per-second drain")
		var before_release := state.stamina
		_step(state)
		check(not state.air_floating and not MovementSystem.is_combat_intangible(state, config), "release removes Float and protection on the same simulation tick")
		check(PlayerResourcesSystem.damage(state, 1000, config), "released Float is damageable immediately")
		check(state.air_height < height and state.air_vertical_velocity < 0, "release immediately resumes descending from current height")
		equal(state.stamina, before_release, "release does not charge optional sustain")
		_step(state, direction, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
		check(not state.air_floating and state.float_used, "fresh repress cannot rearm Float during the same airtime")
		state.jump_buffer_ticks = 0
		for _index: int in range(40):
			_step(state)
		check(state.air_height == 0 and state.hop_stage == 0, "only actual landing restores second-air-action budget")


func _test_fractional_drain_and_exhaustion() -> void:
	var exact_start := _air_state()
	exact_start.stamina = MovementTuning.FLOAT_COST + config.per_tick(MovementTuning.FLOAT_DRAIN_PER_SECOND)
	var before := exact_start.stamina
	_step(exact_start, Vector2i.ZERO, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
	check(not exact_start.air_floating and not MovementSystem.is_combat_intangible(exact_start, config), "exact-empty startup cannot buy an unmaintainable protection state")
	equal(exact_start.stamina, before, "unmaintainable Float startup refuses without payment")
	var state := _air_state()
	_begin(state)
	state.stamina = 1667
	state.stamina_remainder = 0
	_step(state, Vector2i.ZERO, SimCommand.HELD_JUMP)
	equal(state.stamina, 834, "first fractional tick consumes833")
	_step(state, Vector2i.ZERO, SimCommand.HELD_JUMP)
	equal(state.stamina, 1, "second fractional tick consumes833")
	_step(state, Vector2i.ZERO, SimCommand.HELD_JUMP)
	check(not state.air_floating and not MovementSystem.is_combat_intangible(state, config), "unaffordable834-unit fractional tick immediately ends protection")
	equal(state.stamina, 1, "insufficient remainder cannot underflow or purchase a partial protected tick")
	var zero := _air_state()
	_begin(zero)
	zero.stamina = 833
	zero.stamina_remainder = 0
	_step(zero, Vector2i.ZERO, SimCommand.HELD_JUMP)
	equal(zero.stamina, 0, "exact maintenance exhaustion reaches zero")
	check(not zero.air_floating and not MovementSystem.is_combat_intangible(zero, config), "zero resource removes Float immediately, not one tick later")
	var prior_fraction := _air_state()
	prior_fraction.stamina = MovementTuning.FLOAT_COST + 834
	prior_fraction.stamina_remainder = -119
	_begin(prior_fraction)
	equal(prior_fraction.stamina, 1, "startup clears prior fraction once, then pays its exact833-unit first Float tick")
	var long_hold := _air_state()
	long_hold.float_max_duration_ms = MovementTuning.FLOAT_SMALL_DURATION_MS
	_begin(long_hold)
	for _index: int in range(180):
		_step(long_hold, Vector2i.ZERO, SimCommand.HELD_JUMP)
		check(long_hold.air_floating, "long paid Float remains active beyond127ticks")
		equal(long_hold.jump_sustain_ticks, 0, "long Float never overflows ordinary jump sustain snapshot age")


func _test_interruptions_and_budgets() -> void:
	for control: int in [PlayerState.ControlState.ROOTED, PlayerState.ControlState.STUNNED, PlayerState.ControlState.LAUNCHED, PlayerState.ControlState.GRAPPLED, PlayerState.ControlState.CHARGING]:
		var state := _air_state()
		_begin(state)
		MovementSystem.apply_control_state(state, control, 300, Vector2i(1000, 0), 100_000, config)
		check(not state.air_floating and not MovementSystem.is_combat_intangible(state, config), "forced control interrupts Float and protection immediately")
		var before := state.stamina
		_step(state, Vector2i.ZERO, SimCommand.HELD_JUMP)
		equal(state.stamina, before, "forced control stops optional Float maintenance")
		check(state.float_used, "forced control cannot restore spent Float budget")
	var dodge := _air_state()
	_begin(dodge)
	for _index: int in range(dodge.movement_commitment_ticks):
		_step(dodge, Vector2i.ZERO, SimCommand.HELD_JUMP)
	_step(dodge, Vector2i(1000, 0), SimCommand.HELD_JUMP, SimCommand.PRESSED_EVADE)
	check(not dodge.air_floating and dodge.air_dodge_used, "air dodge interrupts Float and spends its own independent airtime allowance")
	check(dodge.float_used, "air dodge cannot restore Float budget")
	check(dodge.air_height < 50_000, "dodge exits stationary Float into actual descent")
	var collision := CollisionWorld.new(10_000_000, 10_000_000)
	collision.add_obstacle(CollisionWorld.Obstacle.new(7, 5_020_000, 4_000_000, 5_048_000, 6_000_000))
	var wall := _air_state()
	wall.position_x = 5_000_000
	_begin(wall, Vector2i(1000, 0))
	for _index: int in range(wall.movement_commitment_ticks):
		_step(wall, Vector2i(1000, 0), SimCommand.HELD_JUMP, 0, collision)
	check(wall.air_floating and wall.position_x <= 5_002_000, "Float preserves floor-plan collision while held at a wall")
	_step(wall, Vector2i(0, 1000), SimCommand.HELD_JUMP, SimCommand.PRESSED_TECHNIQUE, collision)
	check(wall.wall_skim_ticks > 0 and not wall.air_floating, "wallrun deliberately interrupts Float")
	check(not MovementSystem.is_combat_intangible(wall, config), "wallrun inherits no Float protection")
	check(wall.float_used, "wall attachment cannot replenish Float")
	var falling := _air_state()
	_begin(falling)
	_step(falling, Vector2i.ZERO, SimCommand.HELD_JUMP, SimCommand.PRESSED_SLIDE)
	check(not falling.air_floating and falling.fast_falling, "fresh airborne Slide interrupts Float into fast fall")
	check(not MovementSystem.is_combat_intangible(falling, config), "fastfall exit has no leftover Float protection")


func _test_recovery_spend_hooks() -> void:
	var state := PlayerState.new(1)
	state.position_x = 5_000_000
	state.position_y = 5_000_000
	state.stamina = 100_000
	for _index: int in range(360):
		_step(state)
	equal(state.stamina_recovery_idle_ticks, 360, "unused Stamina recovery reaches its bounded quiet-time cap")
	_step(state, Vector2i(1000, 0), SimCommand.HELD_SPRINT)
	equal(state.stamina_recovery_idle_ticks, 0, "sprint resets accumulated Stamina recovery even without an action edge")
	state.stamina_recovery_idle_ticks = 360
	_step(state, Vector2i(1000, 0), 0, SimCommand.PRESSED_JUMP)
	equal(state.stamina_recovery_idle_ticks, 0, "positive movement startup resets accumulated recovery")
	state.stamina_recovery_idle_ticks = 360
	_step(state, Vector2i.ZERO, SimCommand.HELD_JUMP)
	equal(state.stamina_recovery_idle_ticks, 0, "held jump maintenance resets accumulated recovery")


func _test_replay() -> void:
	var first := SimWorld.new(120, 9, arena)
	var repeat := SimWorld.new(120, 9, arena)
	for tick: int in range(420):
		var move := Vector2i(707, -707) if tick < 200 else Vector2i(-707, 707)
		var held := SimCommand.HELD_JUMP if tick < 200 and tick != 19 else 0
		var pressed := SimCommand.PRESSED_JUMP if tick in [0, 20] else 0
		for world: SimWorld in [first, repeat]:
			check(world.step([SimCommand.new(tick, 1, move.x, move.y, held, pressed)]), "Float and ramp replay tick executes")
		equal(first.state_hash(), repeat.state_hash(), "canonical replay matches through Float, release, landing and ramp recovery")


func _test_size_caps_and_wall_chain() -> void:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "Float body-cap ability content loads")
	var catalog := ChampionCatalog.new()
	check(catalog.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "Float body-cap champion content loads")
	for champion_id: String in catalog.ordered_champion_ids():
		var champion_state := _air_state()
		check(catalog.apply_to_player(champion_state, champion_id), "actual champion applies canonical Float duration")
		var body := String(catalog.champions_by_id[champion_id]["body_type"])
		equal(champion_state.float_max_duration_ms, MovementTuning.float_duration_ms(body), "actual champion duration comes from its canonical body type, not resource size or sprite radius")
		champion_state.float_used = true
		champion_state.float_ticks = 100
		check(catalog.apply_to_player(champion_state, champion_id, true), "midair attunement retains valid resource ratios")
		check(champion_state.float_used and champion_state.float_ticks == 100, "attunement cannot refill or extend Float")
	for body: String in ["small", "middle", "large"]:
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			var state := _air_state()
			state.float_max_duration_ms = MovementTuning.float_duration_ms(body)
			var maximum_ticks := config.milliseconds_to_ticks(state.float_max_duration_ms)
			var original_height := state.air_height
			_begin(state, direction)
			equal(state.float_ticks, maximum_ticks - 1, "activation consumes the first bounded Float tick")
			for age: int in range(1, maximum_ticks - 1):
				_step(state, direction, SimCommand.HELD_JUMP)
				check(state.air_floating and state.float_used, "each size remains active only within its paid hard cap")
				equal(state.air_height, original_height, "size cap never changes activation height")
			equal(state.float_ticks, 1, "last permitted Float state has one remaining tick")
			var paid := state.stamina
			_step(state, direction, SimCommand.HELD_JUMP)
			check(not state.air_floating and state.float_ticks == 0 and state.float_used, "hard expiry removes Float but preserves spent allowance on that tick")
			check(not MovementSystem.is_combat_intangible(state, config), "hard expiry immediately removes true invulnerability")
			check(state.air_height < original_height, "expired Float resumes descent immediately")
			equal(state.stamina, paid, "expiry never charges an unavailable protected tick")
			_step(state)
			_step(state, direction, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
			check(not state.air_floating, "fresh repress cannot extend any body size cap")
			MovementSystem._land(state, config)
			check(not state.float_used and state.float_ticks == 0, "actual landing restores independent Float budget")
	for normal: Vector2i in [Vector2i.RIGHT * 1000, Vector2i.LEFT * 1000, Vector2i.UP * 1000, Vector2i.DOWN * 1000]:
		var wall := _air_state()
		wall.wall_memory_ticks = 12
		wall.wall_contact_id = 7
		wall.wall_x = normal.x
		wall.wall_y = normal.y
		_step(wall, normal, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP)
		check(wall.hop_stage == 2 and not wall.float_used, "wall jump spends only its finite lift budget, leaving Float ready")
		for _index: int in range(wall.movement_commitment_ticks):
			_step(wall, normal, SimCommand.HELD_JUMP)
		_step(wall, normal)
		_begin(wall, normal)
		equal(wall.hop_stage, 2, "Float after wall jump cannot restore another wall lift")
		for _index: int in range(wall.movement_commitment_ticks):
			_step(wall, normal, SimCommand.HELD_JUMP)
		_step(wall, normal, SimCommand.HELD_JUMP, SimCommand.PRESSED_EVADE)
		check(wall.air_dodge_used and not wall.air_floating and wall.float_used, "wall jump to Float to air dash is legal without any budget refill")
	var status := _air_state()
	status.air_height = 0
	status.air_vertical_velocity = 0
	status.hop_ticks = 0
	status.stamina = 100_000
	status.chemistry_regen_block_ticks = 3
	status.chemistry_reveal_ticks = 3
	status.chemistry_conceal_ticks = 3
	status.stamina_recovery_idle_ticks = 100
	var original_stamina := status.stamina
	_step(status)
	equal(status.stamina, original_stamina, "chemistry blocks positive Stamina recovery without consuming resource")
	check(status.stamina_recovery_idle_ticks > 100, "regen block does not fake use or reset quiet recovery")
	equal(status.chemistry_reveal_ticks, 2, "chemistry reveal ages once per authoritative step")
	equal(status.chemistry_conceal_ticks, 2, "chemistry conceal ages once per authoritative step")
	status.float_used = true
	status.float_ticks = 10
	status.air_floating = true
	status.reset_for_spawn(Vector2i(5_000_000, 5_000_000))
	check(not status.float_used and not status.air_floating and status.float_ticks == 0, "respawn clears active and spent Float while retaining champion duration")
	equal(status.chemistry_regen_block_ticks + status.chemistry_reveal_ticks + status.chemistry_conceal_ticks, 0, "respawn clears all chemistry status timers")
