extends FluxTestSuite

const Recovery = preload("res://src/sim/entities/resource_recovery.gd")

func run() -> int:
	for tick_rate: int in [120]:
		_test_separate_resources(tick_rate)
		_test_health_recovery_delay(tick_rate)
		_test_flux_spend_and_recovery(tick_rate)
		_test_recovery_curve(tick_rate)
		_test_independent_quiet_clocks(tick_rate)
		_test_all_movement_spends_reset_quiet(tick_rate)
		_test_stamina_quiet_recovery(tick_rate)
		_test_chemistry_recovery_seal(tick_rate)
		_test_sprint_exact_tick_admission(tick_rate)
		_test_sprint_paid_cast_coexistence(tick_rate)
		_test_depleted_sprint_recovery_cycles(tick_rate)
	return finish("player-resources")


func _test_chemistry_recovery_seal(tick_rate: int) -> void:
	var config := SimConfig.new(tick_rate)
	var state := PlayerState.new()
	state.health -= 10_000
	state.flux -= 20_000
	state.chemistry_regen_block_ticks = 10
	state.flux_recovery_idle_ticks = 120
	var before_health := state.health
	var before_flux := state.flux
	PlayerResourcesSystem.step(state, config)
	equal(state.health, before_health, "Blightsoil blocks positive Health recovery")
	equal(state.flux, before_flux, "Blightsoil blocks positive Flux recovery")
	equal(state.flux_recovery_idle_ticks, 121, "recovery seal does not erase quiet age")
	check(PlayerResourcesSystem.spend_flux(state, 1000, config), "recovery seal does not prohibit affordable spending")
	equal(state.flux, before_flux - 1000, "sealed spending retains its exact cost")
	state.chemistry_regen_block_ticks = 0
	state.flux_recovery_delay_ticks = 0
	PlayerResourcesSystem.step(state, config)
	check(state.health > before_health, "Health recovery resumes after the seal")
	check(state.flux > before_flux - 1000, "Flux recovery resumes after the seal")


func _step_empty(world: SimWorld, ticks: int) -> void:
	var all_steps_succeeded: bool = true
	for _index: int in range(ticks):
		all_steps_succeeded = world.step([SimCommand.new(world.tick, 1)]) and all_steps_succeeded
	check(all_steps_succeeded, "%d empty resource ticks step" % ticks)


func _test_separate_resources(tick_rate: int) -> void:
	var world := SimWorld.new(tick_rate)
	var state: PlayerState = world.player()
	var initial_flux: int = state.flux
	var initial_health: int = state.health
	var all_steps_succeeded: bool = true
	for _index: int in range(tick_rate / 2):
		all_steps_succeeded = world.step([SimCommand.new(world.tick, 1, 1000, 0, SimCommand.HELD_SPRINT)]) and all_steps_succeeded
	check(all_steps_succeeded, "%d Hz sprint resource ticks step" % tick_rate)
	check(state.stamina < state.stamina_maximum, "%d Hz movement spends Stamina" % tick_rate)
	equal(state.flux, initial_flux, "%d Hz movement never spends Flux" % tick_rate)
	equal(state.health, initial_health, "%d Hz movement never spends Health" % tick_rate)


func _test_health_recovery_delay(tick_rate: int) -> void:
	var world := SimWorld.new(tick_rate)
	var state: PlayerState = world.player()
	check(PlayerResourcesSystem.damage(state, 10_000, world.config), "%d Hz damage applies" % tick_rate)
	equal(state.health, 90_000, "%d Hz damage is exact" % tick_rate)
	var recovery_delay: int = world.config.milliseconds_to_ticks(PlayerTuning.HEALTH_RECOVERY_DELAY_MS)
	_step_empty(world, recovery_delay - 1)
	equal(state.health, 90_000, "%d Hz Health does not recover during delay" % tick_rate)
	_step_empty(world, tick_rate)
	check(state.health > 90_000, "%d Hz Health recovers after 5.5 second delay" % tick_rate)
	check(state.health <= state.health_maximum, "%d Hz Health recovery is bounded" % tick_rate)


func _test_flux_spend_and_recovery(tick_rate: int) -> void:
	var world := SimWorld.new(tick_rate)
	var state: PlayerState = world.player()
	check(PlayerResourcesSystem.spend_flux(state, 25_000, world.config), "%d Hz legal Flux spend succeeds" % tick_rate)
	equal(state.flux, 75_000, "%d Hz Flux cost is exact" % tick_rate)
	check(not PlayerResourcesSystem.spend_flux(state, 80_000, world.config), "%d Hz unaffordable Flux spend fails" % tick_rate)
	var recovery_delay: int = world.config.milliseconds_to_ticks(PlayerTuning.FLUX_RECOVERY_DELAY_MS)
	_step_empty(world, recovery_delay - 1)
	equal(state.flux, 75_000, "%d Hz Flux does not recover during delay" % tick_rate)
	_step_empty(world, tick_rate)
	check(state.flux > 75_000, "%d Hz Flux recovers after its delay" % tick_rate)
	check(state.flux <= state.flux_maximum, "%d Hz Flux recovery is bounded" % tick_rate)


func _test_recovery_curve(tick_rate: int) -> void:
	var config := SimConfig.new(tick_rate)
	var maximum := Recovery.maximum_idle_ticks(tick_rate)
	equal(maximum, 360, "quiet clocks cap at three seconds after their spend delay")
	equal(Recovery.rate_per_second(20_000, 0, tick_rate), 20_000, "newly quiet resource starts at authored base rate")
	equal(Recovery.rate_per_second(20_000, maximum / 2, tick_rate), 40_000, "halfway quiet resource reaches exactly double rate")
	equal(Recovery.rate_per_second(20_000, maximum, tick_rate), 60_000, "fully quiet resource reaches exactly triple rate")
	equal(Recovery.rate_per_second(20_000, maximum * 10, tick_rate), 60_000, "oversized quiet input cannot exceed triple rate")
	equal(Recovery.rate_per_second(20_000, -10, tick_rate), 20_000, "negative quiet input cannot reduce base recovery")
	equal(Recovery.rate_per_second(-1, maximum, tick_rate), 0, "invalid negative recovery cannot turn into spending")
	equal(Recovery.advance_idle(100, 1, tick_rate), 100, "delay pauses quiet age rather than creating idle credit")
	equal(Recovery.advance_idle(maximum, 0, tick_rate), maximum, "quiet clock cannot grow unbounded")
	var state := PlayerState.new()
	state.flux_maximum = 1_000_000
	state.flux = 0
	state.flux_recovery_delay_ticks = 3
	PlayerResourcesSystem.step(state, config)
	PlayerResourcesSystem.step(state, config)
	equal(state.flux_recovery_idle_ticks, 0, "spend delay elapses before quiet ramp starts")
	equal(state.flux, 0, "resource remains unchanged during its delay")
	state.flux_recovery_delay_ticks = 0
	var previous_second_gain := 0
	for second: int in range(3):
		var before := state.flux
		for _tick: int in range(tick_rate):
			PlayerResourcesSystem.step(state, config)
		var gain := state.flux - before
		check(gain > previous_second_gain, "quiet second %d restores more than the previous interval" % (second + 1))
		previous_second_gain = gain
	equal(state.flux_recovery_idle_ticks, maximum, "real resource stepping reaches the finite quiet cap")
	var before_capped_second := state.flux
	for _tick: int in range(tick_rate):
		PlayerResourcesSystem.step(state, config)
	equal(state.flux - before_capped_second, state.flux_recovery_per_second * 3, "sustained quiet restores exactly triple base per second")
	state.flux = state.flux_maximum - 1
	PlayerResourcesSystem.step(state, config)
	equal(state.flux, state.flux_maximum, "boosted refill clamps at actual resource maximum")
	state.health = 10_000
	state.health_recovery_remainder = 0
	state.health_recovery_delay_ticks = 0
	var before_health := state.health
	for _tick: int in range(tick_rate):
		PlayerResourcesSystem.step(state, config)
	equal(state.health - before_health, state.health_recovery_per_second, "fully quiet resources never accelerate Health recovery")


func _test_independent_quiet_clocks(tick_rate: int) -> void:
	var world := SimWorld.new(tick_rate, 1, CollisionWorld.new(2_000_000, 2_000_000))
	var state := world.player()
	state.position_x = 1_000_000
	state.position_y = 1_000_000
	state.flux_recovery_idle_ticks = 180
	state.stamina_recovery_idle_ticks = 120
	for rejected_amount: int in [0, -1, state.flux + 1]:
		check(not PlayerResourcesSystem.spend_flux(state, rejected_amount, world.config), "refused or free Flux attempt does not spend")
		equal(state.flux_recovery_idle_ticks, 180, "refused or free Flux attempt preserves quiet age")
		equal(state.stamina_recovery_idle_ticks, 120, "refused Flux attempt cannot reset movement quiet age")
	check(PlayerResourcesSystem.spend_flux(state, 1, world.config), "even the smallest positive Flux payment succeeds when affordable")
	equal(state.flux_recovery_idle_ticks, 0, "positive Flux payment immediately resets its quiet clock")
	equal(state.stamina_recovery_idle_ticks, 120, "Flux payment leaves Stamina quiet clock independent")
	var before_flux := state.flux
	check(world.step([SimCommand.new(world.tick, 1, 1000, 0, SimCommand.HELD_SPRINT)]), "actual sprint samples independent resource clocks")
	equal(state.stamina_recovery_idle_ticks, 0, "actual sprint spend resets only Stamina quiet age")
	equal(state.flux, before_flux, "sprint cannot spend Flux or bypass its recovery delay")
	state.flux_recovery_idle_ticks = 240
	state.stamina_recovery_idle_ticks = 240
	state.flux_recovery_delay_ticks = 0
	state.stamina_recovery_delay_ticks = 0
	check(world.step([SimCommand.new(world.tick, 1, 1000, 0)]), "free ordinary movement samples quiet clocks")
	equal(state.flux_recovery_idle_ticks, 241, "free movement continues Flux quiet time")
	equal(state.stamina_recovery_idle_ticks, 241, "free movement continues Stamina quiet time")
	state.air_height = 50_000
	state.air_vertical_velocity = -100_000
	state.hop_ticks = 30
	var before_stamina := state.stamina
	check(world.step([SimCommand.new(world.tick, 1)]), "free airborne coast remains deterministic")
	equal(state.stamina_recovery_idle_ticks, 242, "free coasting still counts as not using Stamina")
	equal(state.stamina, before_stamina, "quiet age does not falsely enable airborne Stamina refill")
	state.reset_for_spawn(Vector2i.ZERO)
	equal(state.flux_recovery_idle_ticks, 0, "respawn resets Flux quiet clock")
	equal(state.stamina_recovery_idle_ticks, 0, "respawn resets Stamina quiet clock")


func _test_all_movement_spends_reset_quiet(tick_rate: int) -> void:
	var config := SimConfig.new(tick_rate)
	var collision := CollisionWorld.new(2_000_000, 2_000_000)
	for action: String in ["jump_hold", "slide_hold", "float_hold"]:
		var state := PlayerState.new()
		state.position_x = 1_000_000
		state.position_y = 1_000_000
		state.stamina_recovery_idle_ticks = config.tick_rate * 2
		state.flux_recovery_idle_ticks = 360
		var held := SimCommand.HELD_JUMP
		if action == "slide_hold":
			state.slide_ticks = 40
			state.slide_held_last_tick = true
			state.movement_action_speed = 400_000
			held = SimCommand.HELD_SLIDE
		else:
			state.hop_ticks = 30
			state.air_height = 50_000
			state.air_vertical_velocity = 300_000
			state.jump_held_last_tick = true
			if action == "float_hold":
				state.flight_capable = true
				state.air_floating = true
				state.float_used = true
				state.float_ticks = 120
				state.hop_stage = 2
				state.air_vertical_velocity = 0
		var before := state.stamina
		MovementSystem.step(state, SimCommand.new(0, 1, 0, 0, held), config, collision)
		if action == "jump_hold":
			equal(state.stamina, before, "ordinary nonflier held Jump has no hidden airborne sustain payment")
			equal(state.stamina_recovery_idle_ticks, config.tick_rate * 2 + 1, "free held Jump continues Stamina quiet time")
			check(not state.air_floating and state.air_height > 0, "ordinary held Jump retains its ballistic arc without granting flight")
		else:
			check(state.stamina < before, action + " pays a real positive held cost")
			equal(state.stamina_recovery_idle_ticks, 0, action + " resets Stamina quiet clock every paid tick")
		equal(state.flux_recovery_idle_ticks, 360, action + " cannot reset Flux quiet clock")


func _test_stamina_quiet_recovery(tick_rate: int) -> void:
	var config := SimConfig.new(tick_rate)
	var collision := CollisionWorld.new(2_000_000, 2_000_000)
	var state := PlayerState.new()
	state.position_x = 1_000_000
	state.position_y = 1_000_000
	state.stamina = 0
	state.stamina_recovery_delay_ticks = 3
	for tick: int in range(2):
		MovementSystem.step(state, SimCommand.new(tick, 1), config, collision)
	equal(state.stamina, 0, "Stamina ramp never bypasses its existing spend delay")
	equal(state.stamina_recovery_idle_ticks, 0, "Stamina quiet clock starts after delay rather than during it")
	state.stamina_recovery_delay_ticks = 0
	var previous_second_gain := 0
	for second: int in range(3):
		var before := state.stamina
		for tick: int in range(tick_rate):
			MovementSystem.step(state, SimCommand.new(tick, 1), config, collision)
		var gain := state.stamina - before
		check(gain > previous_second_gain, "unused Stamina second %d restores progressively faster" % (second + 1))
		previous_second_gain = gain
	equal(state.stamina_recovery_idle_ticks, 360, "actual Stamina stepping reaches the bounded quiet cap")
	var before_capped_second := state.stamina
	for tick: int in range(tick_rate):
		MovementSystem.step(state, SimCommand.new(tick, 1), config, collision)
	equal(state.stamina - before_capped_second, state.stamina_recovery_per_second * 3, "fully quiet Stamina restores exactly triple authored base per second")
	state.stamina = state.stamina_maximum - 1
	MovementSystem.step(state, SimCommand.new(0, 1), config, collision)
	equal(state.stamina, state.stamina_maximum, "triple Stamina recovery cannot overfill the real maximum")
	state.stamina = 0
	state.stamina_recovery_idle_ticks = 180
	MovementSystem.step(state, SimCommand.new(0, 1, 0, 0, 0, SimCommand.PRESSED_JUMP), config, collision)
	equal(state.stamina_recovery_idle_ticks, 181, "unaffordable movement input cannot erase quiet recovery")
	check(state.last_event != "hop", "refused empty-reserve jump did not activate for free")
	state.jump_buffer_ticks = 0
	state.slide_ticks = 30
	state.stamina_recovery_idle_ticks = 180
	MovementSystem.step(state, SimCommand.new(0, 1, 0, 0, 0, SimCommand.PRESSED_SLIDE), config, collision)
	equal(state.slide_ticks, 0, "deliberate Slide brake cancels the active slide")
	equal(state.stamina_recovery_idle_ticks, 181, "free Slide brake preserves the quiet ramp")


func _sprint_resource_fixture(direction: Vector2i, speed_ratio: int, reserve: int, remainder: int) -> PlayerState:
	var state := PlayerState.new(1)
	state.position_x = 5_000_000
	state.position_y = 5_000_000
	state.movement_speed_ratio = speed_ratio
	state.radius = int({900: 19_000, 1000: 18_000, 1100: 17_000}[speed_ratio])
	@warning_ignore("integer_division")
	var walking_speed := MovementTuning.BASE_SPEED * speed_ratio / 1000
	@warning_ignore("integer_division")
	state.velocity_x = direction.x * walking_speed / 1000
	@warning_ignore("integer_division")
	state.velocity_y = direction.y * walking_speed / 1000
	state.stamina = reserve
	state.stamina_remainder = remainder
	state.stamina_recovery_delay_ticks = 20
	state.stamina_recovery_idle_ticks = 180
	return state


func _test_sprint_exact_tick_admission(tick_rate: int) -> void:
	var config := SimConfig.new(tick_rate)
	var arena := CollisionWorld.new(10_000_000, 10_000_000)
	equal(MovementTuning.SPRINT_DRAIN_PER_SECOND, 34_000, "sprint boundary oracle uses the unchanged authored drain")
	# Independent exact rows: prior remainder, whole milli-unit debit, next
	# remainder. Both spending debt and positive recovery credit affect the gate.
	var debit_rows: Array[Vector3i] = [
		Vector3i(-119, 284, -39), Vector3i(-80, 284, 0),
		Vector3i(-40, 283, -80), Vector3i(0, 283, -40),
		Vector3i(40, 283, 0), Vector3i(119, 282, -41),
	]
	for speed_ratio: int in [900, 1000, 1100]:
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			for row: Vector3i in debit_rows:
				for reserve: int in [0, 1, row.y - 1, row.y, row.y + 1]:
					var runner := _sprint_resource_fixture(direction, speed_ratio, reserve, row.x)
					var walker := _sprint_resource_fixture(direction, speed_ratio, reserve, row.x)
					var expected_sprint := reserve >= row.y
					var context := "sprint ratio=%d dir=%s reserve=%d remainder=%d" % [speed_ratio, direction, reserve, row.x]
					MovementSystem.step(runner, SimCommand.new(0, 1, direction.x, direction.y, SimCommand.HELD_SPRINT), config, arena)
					MovementSystem.step(walker, SimCommand.new(0, 1, direction.x, direction.y), config, arena)
					equal(runner.sprinting, expected_sprint, context + " requires the full pending tick debit")
					equal(walker.stamina, reserve, context + " walking remains free during recovery delay")
					equal(walker.stamina_remainder, row.x, context + " walking preserves fractional accounting")
					equal(runner.health, walker.health, context + " cannot spend Health")
					equal(runner.flux, walker.flux, context + " cannot spend Flux")
					if expected_sprint:
						equal(runner.stamina, reserve - row.y, context + " exact funds buy one complete sprint tick")
						equal(runner.stamina_remainder, row.z, context + " retains the exact unpaid sub-unit remainder")
						equal(runner.stamina_recovery_delay_ticks, config.milliseconds_to_ticks(MovementTuning.STAMINA_RECOVERY_DELAY_MS), context + " paid sprint resets delay")
						equal(runner.stamina_recovery_idle_ticks, 0, context + " paid sprint resets its quiet ramp")
						check(Vector2i(runner.velocity_x, runner.velocity_y).length_squared() > Vector2i(walker.velocity_x, walker.velocity_y).length_squared(), context + " affordable sprint retains its speed advantage")
					else:
						equal(runner.canonical_values(), walker.canonical_values(), context + " refused sprint is exactly ordinary walking without debit or timer reset")


func _test_sprint_paid_cast_coexistence(tick_rate: int) -> void:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "sprint coexistence uses the production spell catalog")
	var definition := CombatTuning.cast_definition(179)
	check(not definition.is_empty(), "sprint coexistence uses a retained paid Heavy")
	if definition.is_empty(): return
	for reserve: int in [0, 1, 283, 284, 285]:
		var world := SimWorld.new(tick_rate)
		check(HexCourtPractice.configure(world, abilities, false), "sprint coexistence prepares real paid hex authority")
		var state := world.player()
		check(state.place_proven_spell(0, 179), "sprint coexistence equips the real Heavy")
		state.stamina = reserve
		state.stamina_remainder = -80
		state.stamina_recovery_delay_ticks = 20
		state.stamina_recovery_idle_ticks = 180
		state.flux = int(definition.flux_cost)
		state.flux_recovery_delay_ticks = 20
		state.flux_recovery_idle_ticks = 180
		var context := "sprint/cast reserve=%d" % reserve
		check(world.step([SimCommand.new(world.tick, 1, 1000, 0, SimCommand.HELD_SPRINT, SimCommand.PRESSED_SPELL_1, 0, -1000)]), context + " shares one real authority tick")
		equal(state.sprinting, reserve >= 284, context + " sprint independently requires its remainder-aware debit")
		equal(state.stamina, reserve - 284 if reserve >= 284 else reserve, context + " cast cannot waive or invent Stamina payment")
		equal(state.pending_cast_wire_id, 179, context + " affordable casting survives sprint refusal")
		equal(state.flux, 0, context + " admitted Heavy pays its complete exact Flux reserve")
		equal(state.flux_recovery_idle_ticks, 0, context + " actual cast payment resets only its Flux ramp")
		equal(state.stamina_recovery_idle_ticks, 0 if reserve >= 284 else 180, context + " Flux payment cannot reset an unpaid Stamina ramp")
		var released := false
		var starts := 0
		for event: Dictionary in world.combat_events:
			if event.get("type") == "cast_started": starts += 1
		for _tick: int in range(world.config.milliseconds_to_ticks(int(definition.startup_ms)) + 2):
			check(world.step([SimCommand.new(world.tick, 1, 1000, 0)]), context + " release continues after sprint input ends")
			for event: Dictionary in world.combat_events:
				if event.get("type") == "cast_started": starts += 1
			for projectile: ProjectileState in world.projectiles:
				if projectile.source_wire_id == 179:
					released = true
					check(projectile.velocity_x == 0 and projectile.velocity_y < 0, context + " movement cannot retarget the paid northward cast")
		equal(starts, 1, context + " released input cannot buy a second cast")
		check(released, context + " fully paid cast actually releases")
		equal(state.flux, 0, context + " release neither spends again nor refunds the paid cast")


func _test_depleted_sprint_recovery_cycles(tick_rate: int) -> void:
	var config := SimConfig.new(tick_rate)
	var arena := CollisionWorld.new(10_000_000, 10_000_000)
	var state := _sprint_resource_fixture(Vector2i(1000, 0), 1000, 1000, 0)
	state.stamina_recovery_idle_ticks = 0
	var paid_ticks := 0
	var recovering_ticks := 0
	var refused_ticks := 0
	for tick: int in range(tick_rate * 6):
		var before := state.stamina
		var remainder := state.stamina_remainder
		@warning_ignore("integer_division")
		var required := (MovementTuning.SPRINT_DRAIN_PER_SECOND - remainder) / tick_rate
		var affordable := before >= required and before > 0
		var delay := state.stamina_recovery_delay_ticks
		var quiet := state.stamina_recovery_idle_ticks
		MovementSystem.step(state, SimCommand.new(tick, 1, 1000, 0, SimCommand.HELD_SPRINT), config, arena)
		equal(state.sprinting, affordable, "depleted held sprint tick %d never purchases an underpaid speed tick" % tick)
		if affordable:
			paid_ticks += 1
			equal(state.stamina, before - required, "every affordable held sprint pays its exact whole-unit debit")
			equal(state.stamina_remainder, remainder - MovementTuning.SPRINT_DRAIN_PER_SECOND + required * tick_rate, "continuous sprint preserves fractional debt")
			equal(state.stamina_recovery_idle_ticks, 0, "each actual sprint payment resets quiet time")
		else:
			refused_ticks += 1
			check(state.stamina >= before, "unaffordable held sprint cannot spend or starve eligible recovery")
			equal(state.stamina_recovery_delay_ticks, maxi(0, delay - 1), "unaffordable retries do not postpone recovery")
			equal(state.stamina_recovery_idle_ticks, Recovery.advance_idle(quiet, maxi(0, delay - 1), tick_rate), "unaffordable retries do not reset the quiet ramp")
			if state.stamina > before: recovering_ticks += 1
		check(state.stamina >= 0 and state.stamina <= state.stamina_maximum, "held depletion and recovery stay within the resource envelope")
	check(paid_ticks > 4 and refused_ticks > 0 and recovering_ticks > 0, "six-second held run includes initial depletion, refusal, recovery and paid resumption")
	var before_release := state.stamina
	for tick: int in range(tick_rate * 4):
		MovementSystem.step(state, SimCommand.new(tick, 1, 1000, 0), config, arena)
		check(not state.sprinting, "released Sprint remains ordinary walking throughout recovery")
	check(state.stamina > before_release, "deliberate Sprint release restores a useful reserve")
	equal(state.stamina_recovery_idle_ticks, Recovery.maximum_idle_ticks(tick_rate), "released Sprint reaches the existing finite quiet-recovery cap")
