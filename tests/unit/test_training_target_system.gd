extends FluxTestSuite


const TrainingTargetSystemScript = preload("res://src/sim/combat/training_target_system.gd")


func run() -> int:
	_test_exact_lifecycle()
	_test_identity_and_cleanup()
	_test_independent_targets_and_repeated_death()
	_test_champion_exclusion_and_fail_closed()
	_test_world_and_snapshot_lifecycle()
	return finish("training-target-system")


func _test_world_and_snapshot_lifecycle() -> void:
	var world := SimWorld.new(120, 608, CollisionWorld.new(4_000_000, 2_000_000))
	world.player().champion_wire_id = 1
	var target := _target()
	world.players.append(target)
	world.projectiles.append(ProjectileState.new(
		1000, 1, 1, CombatTuning.RILLSHOT_WIRE_ID, 2,
		Vector2i(target.position_x - 10_000, target.position_y), Vector2i(600_000, 0),
		8_000, target.health_maximum, 30,
	))
	check(world.step([]), "real combat defeat steps successfully")
	equal(target.health, 0, "production projectile defeats the training actor")
	equal(target.training_respawn_ticks, 360, "world hook arms target lifecycle exactly once")
	var replica := SimWorld.new(120, 608, CollisionWorld.new(4_000_000, 2_000_000))
	for elapsed: int in range(361):
		if elapsed in [0, 180, 359, 360]:
			var snapshot := SessionSnapshot.capture(world, {1: "Host"})
			check(SessionSnapshot.apply_to_world(snapshot, replica), "live/dead/protected target snapshot applies")
			var guest_target := replica.player(target.entity_id)
			check(guest_target != null, "late join retains stable target identity")
			if guest_target != null:
				equal(guest_target.health, target.health, "target health matches authority at each lifecycle boundary")
				equal(guest_target.training_respawn_ticks, target.training_respawn_ticks, "target countdown matches authority")
				equal(guest_target.spawn_protection_ticks, target.spawn_protection_ticks, "target readiness protection matches authority")
				equal(Vector2i(guest_target.training_spawn_x, guest_target.training_spawn_y), Vector2i(target.training_spawn_x, target.training_spawn_y), "authored return anchor survives late join")
		if elapsed < 360:
			check(world.step([]), "ordinary authoritative ticks advance target lifecycle")
	equal(target.health, target.health_maximum, "real world restores target at three seconds")
	equal(target.spawn_protection_ticks, 30, "real world return carries honest readiness grace")
	var before := world.state_hash()
	target.training_respawn_ticks = 1
	check(world.state_hash() != before, "target countdown participates in deterministic state hash")
	target.training_respawn_ticks = 0


func _target(entity_id: int = 900) -> PlayerState:
	var state := PlayerState.new(entity_id)
	state.actor_kind = PlayerState.ActorKind.TRAINING_TARGET
	state.team_id = entity_id
	state.position_x = 2368_000
	state.position_y = 352_000
	state.training_spawn_x = state.position_x
	state.training_spawn_y = state.position_y
	state.health_maximum = 80_000
	state.health = state.health_maximum
	state.health_recovery_per_second = 0
	state.flux_maximum = 0
	state.flux = 0
	state.flux_recovery_per_second = 0
	state.stamina_maximum = 0
	state.stamina = 0
	state.stamina_recovery_per_second = 0
	state.movement_speed_ratio = 0
	return state


func _test_exact_lifecycle() -> void:
	var config := SimConfig.new(120)
	var target := _target()
	equal(TrainingTargetSystemScript.step_target(target, config), "", "living target has no lifecycle side effect")
	target.health = 0
	equal(TrainingTargetSystemScript.step_target(target, config), TrainingTargetSystemScript.DOWN_EVENT, "first defeated observation announces exactly one countdown")
	equal(target.training_respawn_ticks, 360, "three seconds means 360 authoritative ticks")
	for elapsed: int in range(1, 360):
		equal(TrainingTargetSystemScript.step_target(target, config), "", "countdown cannot emit repeated defeat or early respawn")
		equal(target.health, 0, "target stays defeated throughout the full wait")
		equal(target.training_respawn_ticks, 360 - elapsed, "countdown advances exactly once per fixed tick")
	equal(TrainingTargetSystemScript.step_target(target, config), TrainingTargetSystemScript.RESPAWN_EVENT, "target returns at exactly three seconds after defeat")
	equal(target.training_respawn_ticks, 0, "respawn consumes its countdown")
	equal(target.health, 80_000, "respawn restores authored Health")
	equal(target.spawn_protection_ticks, 30, "respawn supplies exactly 250 ms protection")
	equal(TrainingTargetSystemScript.step_target(target, config), "", "living target cannot double-respawn")
	equal(target.spawn_protection_ticks, 30, "target helper does not also advance living resource timers")


func _test_identity_and_cleanup() -> void:
	var config := SimConfig.new(120)
	var target := _target()
	target.health = 0
	target.training_respawn_ticks = 1
	target.position_x += 180_000
	target.position_y += 70_000
	target.velocity_x = 350_000
	target.velocity_y = -80_000
	target.position_remainder_x = 37
	target.control_state = PlayerState.ControlState.SLOWED
	target.control_ticks = 600
	target.slow_ratio = 350
	target.pending_cast_wire_id = CombatTuning.PRIMARY_WIRE_ID
	target.pending_cast_ticks = 12
	target.cast_recovery_ticks = 15
	target.primary_held = true
	target.hop_ticks = 14
	target.slide_ticks = 9
	target.air_dodge_ticks = 6
	target.health_recovery_delay_ticks = 100
	target.flux = 700
	target.stamina = 400
	var instance_id := target.get_instance_id()
	equal(TrainingTargetSystemScript.step_target(target, config), TrainingTargetSystemScript.RESPAWN_EVENT, "expired target timer executes the existing spawn reset")
	equal(target.get_instance_id(), instance_id, "respawn reuses the same actor object")
	equal(target.entity_id, 900, "stable target entity identity survives")
	equal(target.team_id, 900, "target stays hostile to every champion team")
	equal(target.actor_kind, PlayerState.ActorKind.TRAINING_TARGET, "target cannot turn into a champion on respawn")
	equal(Vector2i(target.position_x, target.position_y), Vector2i(2368_000, 352_000), "displaced target returns to its authored anchor")
	equal(Vector2i(target.training_spawn_x, target.training_spawn_y), Vector2i(2368_000, 352_000), "anchor survives reset")
	equal(Vector2i(target.velocity_x, target.velocity_y), Vector2i.ZERO, "old knockback does not continue after respawn")
	equal(target.position_remainder_x, 0, "fixed-point movement residue is cleared")
	equal(target.control_state, PlayerState.ControlState.FREE, "old control effect is cleared")
	equal(target.control_ticks, 0, "old control duration is cleared")
	equal(target.slow_ratio, 1000, "old slow strength is cleared")
	equal(target.pending_cast_wire_id, 0, "pending cast cannot release after respawn")
	equal(target.pending_cast_ticks + target.cast_recovery_ticks, 0, "cast commitment is cleared")
	check(not target.primary_held, "respawn does not preserve attack input")
	equal(target.hop_ticks + target.slide_ticks + target.air_dodge_ticks, 0, "old movement states are cleared")
	equal(target.health_recovery_per_second, 0, "target does not gain natural Health regeneration")
	equal(target.health_recovery_delay_ticks, 0, "old recovery delay is cleared")
	equal(target.flux_maximum + target.flux + target.flux_recovery_per_second, 0, "target keeps its zero Flux profile")
	equal(target.stamina_maximum + target.stamina + target.stamina_recovery_per_second, 0, "target keeps its zero Stamina profile")
	equal(target.movement_speed_ratio, 0, "target keeps its immobile ordinary-movement profile")


func _test_independent_targets_and_repeated_death() -> void:
	var config := SimConfig.new(120)
	var first := _target(900)
	var second := _target(901)
	first.health = 0
	second.health = 0
	first.training_respawn_ticks = 1
	second.training_respawn_ticks = 121
	equal(TrainingTargetSystemScript.step_target(first, config), TrainingTargetSystemScript.RESPAWN_EVENT, "first target may return while another waits")
	equal(TrainingTargetSystemScript.step_target(second, config), "", "second target countdown is independent")
	equal(second.training_respawn_ticks, 120, "one target respawn cannot reset another target timer")
	first.health = 0
	equal(TrainingTargetSystemScript.step_target(first, config), TrainingTargetSystemScript.DOWN_EVENT, "later defeat begins a fresh complete cycle")
	equal(first.training_respawn_ticks, 360, "later defeat does not inherit a shortened countdown")
	second.reset_for_spawn(Vector2i(second.training_spawn_x, second.training_spawn_y))
	equal(second.training_respawn_ticks, 0, "manual spawn reset cancels a pending automatic reset")
	equal(TrainingTargetSystemScript.step_target(second, config), "", "manual reset cannot trigger a delayed extra respawn")


func _test_champion_exclusion_and_fail_closed() -> void:
	var config := SimConfig.new(120)
	var champion := PlayerState.new(1)
	champion.health = 0
	var before := champion.canonical_values()
	equal(TrainingTargetSystemScript.step_target(champion, config), "", "champion defeats stay owned by round rules")
	equal(champion.canonical_values(), before, "target helper cannot mutate a defeated champion")
	equal(TrainingTargetSystemScript.step_target(null, config), "", "missing target fails closed")
	var target := _target()
	target.health = 0
	equal(TrainingTargetSystemScript.step_target(target, null), "", "missing fixed-tick configuration fails closed")
	equal(target.training_respawn_ticks, 0, "failed helper call cannot arm a timer")
