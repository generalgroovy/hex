extends FluxTestSuite

const Physical = preload("res://.agent/candidates/gameplay_s5/src/sim/combat/physical_attack_system.gd")
const Tuning = preload("res://.agent/candidates/gameplay_s5/src/sim/combat/physical_attack_tuning.gd")


class AttackWorld extends RefCounted:
	var players: Array = []
	var config := SimConfig.new(120)
	var collision := CollisionWorld.new(1_280_000, 960_000)
	var combat_events: Array[Dictionary] = []
	var tick := 0


func run() -> int:
	_test_exact_tuning_and_atomic_load()
	_test_start_cost_priority_and_aim()
	_test_exact_phases_and_single_hit()
	_test_buffer_and_paid_movement_cancellation()
	_test_target_gates_cover_height_and_size()
	_test_wall_knockback_and_guard()
	return finish("physical-attack-system")


func _test_exact_tuning_and_atomic_load() -> void:
	var tuning := Tuning.new()
	check(tuning.load_from_file(), "candidate physical tuning loads: %s" % tuning.last_error)
	check(tuning.is_valid(), "candidate physical tuning is complete and hashed")
	var punch: Dictionary = tuning.profile(Tuning.PUNCH)
	var kick: Dictionary = tuning.profile(Tuning.KICK)
	equal([punch.stamina_cost, punch.damage, punch.startup_ticks, punch.active_ticks, punch.recovery_ticks, punch.reach, punch.half_arc_cosine_squared, punch.knockback], [14_000, 6_000, 6, 4, 16, 48_000, 750_000, 7_000], "Punch uses the exact S5 trial profile")
	equal([kick.stamina_cost, kick.damage, kick.startup_ticks, kick.active_ticks, kick.recovery_ticks, kick.reach, kick.half_arc_cosine_squared, kick.knockback], [35_000, 12_000, 12, 6, 28, 64_000, 500_000, 30_000], "Kick uses the exact S5 trial profile")
	var isolated := punch.duplicate(true)
	isolated.damage = 1
	equal(int(tuning.profile(Tuning.PUNCH).damage), 6_000, "profile callers cannot mutate validated tuning")

	var original_hash := tuning.content_hash
	var original_punch := tuning.profile(Tuning.PUNCH)
	var path := "user://physical-attacks-invalid-test.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "isolated malformed tuning fixture opens")
	if file != null:
		file.store_string('{"version":1,"attacks":[]}')
		file.close()
	check(not tuning.load_from_file(path), "malformed tuning fails closed")
	equal(tuning.content_hash, original_hash, "failed tuning reload preserves the last valid hash")
	equal(tuning.profile(Tuning.PUNCH), original_punch, "failed tuning reload preserves the last valid profiles atomically")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_start_cost_priority_and_aim() -> void:
	Tuning.reset_shared_for_tests()
	var actor := PlayerState.new(1)
	actor.aim_x = 0
	actor.aim_y = -1000
	var config := SimConfig.new(120)
	var events: Array[Dictionary] = []
	var both := SimCommand.new(0, actor.entity_id, 0, 0, 0, Physical.PRESSED_PUNCH_BIT | Physical.PRESSED_KICK_BIT)
	var before := actor.stamina
	var result: Dictionary = Physical.begin_tick(actor, both, config, 0, events)
	check(result.started and int(result.kind) == Physical.Kind.PUNCH, "simultaneous physical buttons deterministically choose Punch")
	equal(int(result.consumed_pressed_actions), Physical.PHYSICAL_PRESSED_BITS, "both dedicated command bits are consumed by the physical system")
	equal(actor.stamina, before - 14_000, "accepted Punch pays Stamina exactly once")
	equal(Vector2i(actor.physical_aim_x, actor.physical_aim_y), Vector2i(0, -1000), "accepted start latches continuous aim")
	equal(actor.physical_phase, Physical.Phase.STARTUP, "accepted attack begins in startup")
	check(events.size() == 1 and events[0].type == "physical_attack_started", "accepted attack emits one start event")

	var poor := PlayerState.new(2)
	poor.stamina = 34_999
	events.clear()
	result = Physical.begin_tick(poor, _command(poor, Physical.PRESSED_KICK_BIT), config, 0, events)
	check(not result.started and result.reason == &"stamina", "insufficient Kick Stamina is refused")
	equal(poor.stamina, 34_999, "Stamina refusal makes no partial spend")
	equal(poor.physical_phase, Physical.Phase.NONE, "Stamina refusal creates no hidden attack phase")
	check(events.size() == 1 and events[0].type == "physical_attack_refused", "Stamina refusal is explicit")


func _test_exact_phases_and_single_hit() -> void:
	var actor := PlayerState.new(10)
	actor.team_id = 1
	actor.position_x = 200_000
	actor.position_y = 200_000
	var target := PlayerState.new(11)
	target.team_id = 2
	target.position_x = 250_000
	target.position_y = 200_000
	var world := AttackWorld.new()
	world.players = [target, actor]
	var before_health := target.health
	Physical.begin_tick(actor, _command(actor, Physical.PRESSED_PUNCH_BIT), world.config, 0, world.combat_events)
	actor.aim_x = -1000
	actor.aim_y = 0
	for tick: int in range(1, 6):
		world.tick = tick
		Physical.begin_tick(actor, _command(actor), world.config, tick, world.combat_events)
		equal(actor.physical_phase, Physical.Phase.STARTUP, "Punch remains startup through paid tick %d" % tick)
	world.tick = 6
	Physical.begin_tick(actor, _command(actor), world.config, 6, world.combat_events)
	equal(actor.physical_phase, Physical.Phase.ACTIVE, "Punch becomes active after exactly six startup ticks")
	var contacts := Physical.resolve_all(world)
	equal(contacts.size(), 1, "first active tick uses latched aim and confirms one eligible target contact")
	equal(target.health, before_health - 6_000, "Punch applies exact damage once")
	equal(contacts[0].target_position_before_knockback, Vector2i(250_000, 200_000), "contact captures the target point before knockback for future infusion")
	equal(target.control_state, PlayerState.ControlState.FREE, "physical knockback adds no stun or control lock")
	Physical.resolve_all(world)
	equal(target.health, before_health - 6_000, "the same sequence cannot hit one target twice during active frames")
	for tick: int in range(7, 10):
		Physical.begin_tick(actor, _command(actor), world.config, tick, world.combat_events)
	equal(actor.physical_phase, Physical.Phase.ACTIVE, "Punch owns exactly four active ticks including its first contact tick")
	Physical.begin_tick(actor, _command(actor), world.config, 10, world.combat_events)
	equal(actor.physical_phase, Physical.Phase.RECOVERY, "Punch enters recovery after four active ticks")
	for tick: int in range(11, 27):
		Physical.begin_tick(actor, _command(actor), world.config, tick, world.combat_events)
	equal(actor.physical_phase, Physical.Phase.NONE, "Punch releases after exactly sixteen recovery ticks")


func _test_buffer_and_paid_movement_cancellation() -> void:
	var actor := PlayerState.new(20)
	var config := SimConfig.new(120)
	var events: Array[Dictionary] = []
	var before := actor.stamina
	Physical.begin_tick(actor, _command(actor, Physical.PRESSED_KICK_BIT), config, 0, events)
	equal(actor.stamina, before - 35_000, "Kick pays once at accepted start")
	actor.slide_ticks = 2
	Physical.begin_tick(actor, _command(actor), config, 1, events)
	equal(actor.physical_phase, Physical.Phase.NONE, "paid Slide interrupts the physical phase before contact")
	equal(actor.physical_recovery_lock_ticks, 28, "interrupted Kick retains its complete recovery debt")
	equal(actor.stamina, before - 35_000, "interruption does not refund or double-charge Kick")
	for movement: String in ["roll", "air_dodge", "wall_kick"]:
		var interrupted := PlayerState.new(21)
		Physical.begin_tick(interrupted, _command(interrupted, Physical.PRESSED_PUNCH_BIT), config, 0, events)
		if movement == "wall_kick":
			interrupted.hop_ticks = 2
			interrupted.hop_mode = PlayerState.MovementMode.WALL_KICK
		else:
			interrupted.air_dodge_ticks = 2
			interrupted.movement_mode = PlayerState.MovementMode.ROLL if movement == "roll" else PlayerState.MovementMode.AIR_DODGE
		Physical.begin_tick(interrupted, _command(interrupted), config, 1, events)
		equal(interrupted.physical_phase, Physical.Phase.NONE, "%s interrupts before physical contact" % movement)
		equal(interrupted.physical_recovery_lock_ticks, 16, "%s retains the paid Punch recovery debt" % movement)
	actor.slide_ticks = 0
	actor.physical_recovery_lock_ticks = 10
	var buffered := Physical.begin_tick(actor, _command(actor, Physical.PRESSED_KICK_BIT), config, 2, events)
	check(buffered.buffered and actor.physical_buffer_kind == Physical.Kind.KICK, "first valid input buffers inside the last ten recovery ticks")
	Physical.begin_tick(actor, _command(actor, Physical.PRESSED_PUNCH_BIT), config, 3, events)
	equal(actor.physical_buffer_kind, Physical.Kind.KICK, "later input cannot replace the first buffered attack")
	actor.physical_recovery_lock_ticks = 1
	var stamina_before_release := actor.stamina
	var released := Physical.begin_tick(actor, _command(actor), config, 4, events)
	check(released.started and actor.physical_kind == Physical.Kind.KICK, "buffer releases when recovery debt reaches zero")
	equal(actor.stamina, stamina_before_release - 35_000, "buffer payment occurs once at actual accepted start")

	actor.physical_buffer_kind = Physical.Kind.PUNCH
	actor.physical_buffer_ticks = 5
	actor.health = 0
	Physical.begin_tick(actor, _command(actor), config, 5, events)
	equal([actor.physical_phase, actor.physical_buffer_kind, actor.physical_recovery_lock_ticks], [Physical.Phase.NONE, Physical.Kind.NONE, 0], "death clears attack, buffer and delayed recovery state")
	var modal := PlayerState.new(22)
	_arm_active(modal, Physical.Kind.KICK, Vector2i(1000, 0), 1)
	modal.physical_buffer_kind = Physical.Kind.PUNCH
	modal.physical_buffer_ticks = 5
	Physical.cancel(modal, &"modal", 6, events, true)
	equal([modal.physical_phase, modal.physical_buffer_kind, modal.physical_recovery_lock_ticks], [Physical.Phase.NONE, Physical.Kind.NONE, 28], "modal cancellation clears delayed input while preserving live recovery debt")


func _test_target_gates_cover_height_and_size() -> void:
	var world := AttackWorld.new()
	var attacker := PlayerState.new(30)
	attacker.team_id = 1
	attacker.position_x = 300_000
	attacker.position_y = 300_000
	_arm_active(attacker, Physical.Kind.PUNCH, Vector2i(1000, 0), 1)
	var legal := _target(31, 2, Vector2i(360_000, 300_000))
	legal.air_height = 24_000
	var too_high := _target(32, 2, Vector2i(350_000, 300_000))
	too_high.air_height = 24_001
	var ally := _target(33, 1, Vector2i(350_000, 300_000))
	var protected := _target(34, 2, Vector2i(350_000, 300_000))
	protected.spawn_protection_ticks = 1
	var behind := _target(35, 2, Vector2i(250_000, 300_000))
	var intangible := _target(36, 2, Vector2i(350_000, 300_000))
	intangible.air_height = 1_000
	intangible.air_floating = true
	intangible.float_ticks = 1
	world.players = [attacker, legal, too_high, ally, protected, behind, intangible]
	var contacts := Physical.resolve_all(world)
	equal(contacts.size(), 1, "team, protection, intangibility, height and arc gates leave only the legal target")
	equal(int(contacts[0].target_id), legal.entity_id, "height exactly 24px remains eligible")

	var covered_world := AttackWorld.new()
	var covered_attacker := PlayerState.new(40)
	covered_attacker.team_id = 1
	covered_attacker.position_x = 400_000
	covered_attacker.position_y = 400_000
	_arm_active(covered_attacker, Physical.Kind.KICK, Vector2i(1000, 0), 1)
	var covered := _target(41, 2, Vector2i(460_000, 400_000))
	covered_world.players = [covered_attacker, covered]
	covered_world.collision.add_obstacle(CollisionWorld.Obstacle.new(1, 425_000, 370_000, 435_000, 430_000))
	var covered_health := covered.health
	equal(Physical.resolve_all(covered_world).size(), 0, "existing solid cover blocks a physical contact")
	equal(covered.health, covered_health, "covered target takes no hidden damage")

	# Attack reach is independent of attacker body radius. Target hurt radius is
	# the only body-size term in radial eligibility.
	for attacker_radius: int in [12_000, 18_000, 24_000]:
		var size_world := AttackWorld.new()
		var size_attacker := PlayerState.new(50 + attacker_radius / 1000)
		size_attacker.team_id = 1
		size_attacker.radius = attacker_radius
		size_attacker.position_x = 500_000
		size_attacker.position_y = 500_000
		_arm_active(size_attacker, Physical.Kind.PUNCH, Vector2i(1000, 0), 1)
		var size_target := _target(90 + attacker_radius / 1000, 2, Vector2i(565_000, 500_000))
		size_target.radius = 18_000
		size_world.players = [size_attacker, size_target]
		equal(Physical.resolve_all(size_world).size(), 1, "attacker radius %d does not alter the shared Punch reach" % attacker_radius)
	for target_radius: int in [17_000, 18_000, 19_000]:
		var hurt_world := AttackWorld.new()
		var hurt_attacker := PlayerState.new(120 + target_radius / 1000)
		hurt_attacker.team_id = 1
		hurt_attacker.position_x = 500_000
		hurt_attacker.position_y = 600_000
		_arm_active(hurt_attacker, Physical.Kind.KICK, Vector2i(1000, 0), 1)
		var hurt_target := _target(150 + target_radius / 1000, 2, Vector2i(582_000, 600_000))
		hurt_target.radius = target_radius
		hurt_world.players = [hurt_attacker, hurt_target]
		equal(Physical.resolve_all(hurt_world).size(), 0 if target_radius == 17_000 else 1, "target hurt radius %d alone controls the Kick reach boundary" % target_radius)


func _test_wall_knockback_and_guard() -> void:
	var world := AttackWorld.new()
	var first := PlayerState.new(70)
	first.team_id = 1
	first.position_x = 600_000
	first.position_y = 500_000
	_arm_active(first, Physical.Kind.KICK, Vector2i(1000, 0), 1)
	var second := PlayerState.new(71)
	second.team_id = 1
	second.position_x = 600_000
	second.position_y = 500_000
	_arm_active(second, Physical.Kind.KICK, Vector2i(1000, 0), 1)
	var victim := _target(72, 2, Vector2i(650_000, 500_000))
	world.players = [second, victim, first]
	world.collision.add_obstacle(CollisionWorld.Obstacle.new(5, 676_000, 450_000, 700_000, 550_000))
	var contacts := Physical.resolve_all(world)
	equal(contacts.size(), 2, "simultaneous ordered attackers can each confirm one contact")
	check(not bool(contacts[0].knockback_guarded) and bool(contacts[1].knockback_guarded), "contact events distinguish the full first push from a guarded repeat")
	equal(contacts[0].knockback_delta, Vector2i(8_000, 0), "contact event reports the collision-resolved first displacement")
	equal(contacts[1].knockback_delta, Vector2i.ZERO, "blocked guarded repeat reports no fabricated displacement")
	equal(victim.position_x, 658_000, "wall-aware full Kick stops at hurt radius and guarded repeat adds no illegal wall penetration")
	equal(victim.knockback_guard_ticks, 48, "confirmed contact arms the exact 48-tick knockback guard")
	equal(victim.health, victim.health_maximum - 24_000, "knockback guard reduces repeated push without reducing authored damage")
	for hurt_radius: int in [17_000, 18_000, 19_000]:
		var clearance_world := AttackWorld.new()
		var pusher := PlayerState.new(200 + hurt_radius / 1000)
		pusher.team_id = 1
		pusher.position_x = 800_000
		pusher.position_y = 500_000
		_arm_active(pusher, Physical.Kind.KICK, Vector2i(1000, 0), 1)
		var pushed := _target(230 + hurt_radius / 1000, 2, Vector2i(850_000, 500_000))
		pushed.radius = hurt_radius
		clearance_world.players = [pusher, pushed]
		clearance_world.collision.add_obstacle(CollisionWorld.Obstacle.new(10, 876_000, 450_000, 900_000, 550_000))
		Physical.resolve_all(clearance_world)
		equal(pushed.position_x, 858_000, "hurt radius %d retains common 18000 knockback wall clearance" % hurt_radius)


func _command(actor: PlayerState, pressed: int = 0) -> SimCommand:
	return SimCommand.new(0, actor.entity_id, 0, 0, 0, pressed, actor.aim_x, actor.aim_y)


func _target(id: int, team: int, point: Vector2i) -> PlayerState:
	var result := PlayerState.new(id)
	result.team_id = team
	result.position_x = point.x
	result.position_y = point.y
	return result


func _arm_active(actor: PlayerState, kind: int, aim: Vector2i, sequence: int) -> void:
	actor.physical_kind = kind
	actor.physical_phase = Physical.Phase.ACTIVE
	actor.physical_phase_ticks_remaining = 1
	actor.physical_phase_ticks_total = 1
	actor.physical_aim_x = aim.x
	actor.physical_aim_y = aim.y
	actor.physical_sequence_id = sequence
	actor.physical_hit_ids.clear()
