extends FluxTestSuite

const Rival = preload("res://src/app/solo_duel_rival.gd")
var abilities := AbilityCatalog.new()
var champions := ChampionCatalog.new()
var campus := SanctumCampusLayout.new()
var profile: Dictionary
var bounds: Rect2i


func run() -> int:
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "rival uses current abilities")
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "rival uses ordinary champion stats")
	check(campus.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "rival uses real court")
	profile = InterceptionPractice.opponent_profile(abilities)
	var pixels: Rect2i = InterceptionPractice.spawn_contract(campus).bounds
	bounds = Rect2i(pixels.position * SimConfig.FIXED_SCALE, pixels.size * SimConfig.FIXED_SCALE)
	_test_schedule()
	_test_commitment_and_refusal()
	_test_ordinary_paid_pressure()
	return finish("solo-duel-rival")


func _world() -> SimWorld:
	var world := SimWorld.new(120, 60106, campus.build_collision_world(), String(campus.data.id), campus.content_hash)
	var definition := HexWorldDefinition.from_campus(campus)
	check(definition.bind_world(world), "fixture binds production whole-hex authority")
	check(not InterceptionShowcase.configure(world, champions, abilities, campus).is_empty(), "fixture equips actual paid practice kit")
	return world


func _command(world: SimWorld, tick: int) -> SimCommand:
	return Rival.command_for_tick(tick, 0, world.player(2), world.player(1), profile.slots, bounds)


func _test_schedule() -> void:
	equal(Rival.READY_END, 480, "four-second readiness is unchanged")
	equal(Rival.DURATION_TICKS, 8640, "72-second deadline is unchanged")
	check(Rival.status(9, 10).is_empty() and Rival.status(0, -1).is_empty(), "invalid timing refuses")
	for transition: Array in [[0, Rival.READY], [479, Rival.READY], [480, Rival.WINDUP], [575, Rival.WINDUP], [576, Rival.PRESSURE], [791, Rival.PRESSURE], [792, Rival.RECOVER], [960, Rival.WINDUP], [8640, Rival.COMPLETE]]:
		var tick := int(transition[0])
		equal(Rival.status(tick, 0).phase, transition[1], "exact boundary %d" % tick)
		equal(Rival.status(tick + 137, 137), Rival.status(tick, 0), "retry offset preserves phase %d" % tick)
	equal(Rival.status(480, 0).telegraph, "heavy", "windup names its actual heavy")
	equal(Rival.status(576, 0).telegraph, "volley", "pressure names mixed paid volley")
	var world := _world()
	var player_before := world.player(1).canonical_values()
	var rival_before := world.player(2).canonical_values()
	var slots_before: Dictionary = profile.slots.duplicate(true)
	var heavy_edges := 0
	var bolt_edges := 0
	var rapid_ticks := 0
	var quiet_valid := true
	var bounded := true
	var deterministic := true
	for tick: int in range(Rival.DURATION_TICKS + 1):
		var command := _command(world, tick)
		if command == null:
			check(false, "valid live actors always produce a bounded command")
			return
		var phase := String(Rival.status(tick, 0).phase)
		heavy_edges += int(command.first_pressed_spell_slot() == int(profile.slots.heavy))
		bolt_edges += int(command.first_pressed_spell_slot() == int(profile.slots.bolt))
		rapid_ticks += int(command.first_held_spell_slot() == int(profile.slots.rapid))
		bounded = bounded and absi(command.move_x) <= 1000 and absi(command.move_y) <= 1000
		if phase in [Rival.READY, Rival.RECOVER, Rival.COMPLETE]:
			quiet_valid = quiet_valid and command.held_actions == 0 and command.pressed_actions == 0 and command.move_x == 0 and command.move_y == 0
		if tick % 31 == 0:
			deterministic = deterministic and command.canonical_bytes() == _command(world, tick).canonical_bytes()
	equal(heavy_edges, 17, "one finite Heavy edge per active four-second loop")
	equal(bolt_edges, 34, "two finite Bolt edges per loop")
	equal(rapid_ticks, 918, "17 short 54-tick Rapid windows, never perpetual held fire")
	check(quiet_valid and bounded and deterministic, "neutral phases, bounded axes and deterministic commands hold for entire deadline")
	equal(world.player(1).canonical_values(), player_before, "policy never mutates player authority")
	equal(world.player(2).canonical_values(), rival_before, "policy never mutates rival health, resources, cooldowns or position")
	equal(profile.slots, slots_before, "policy does not rewrite loadout mapping")


func _test_commitment_and_refusal() -> void:
	var world := _world()
	var opponent := world.player(2)
	var player := world.player(1)
	var sampled := _command(world, Rival.READY_END)
	equal(Vector2i(sampled.move_x, sampled.move_y), Vector2i.ZERO, "Heavy tell holds position")
	# Fixture accepts the aim exactly as SimWorld does; policy itself does not.
	opponent.aim_x = sampled.aim_x
	opponent.aim_y = sampled.aim_y
	player.position_y += 100000
	var heavy := _command(world, Rival.READY_END + Rival.WINDUP_TICKS)
	equal(Vector2i(heavy.aim_x, heavy.aim_y), Vector2i(sampled.aim_x, sampled.aim_y), "Heavy retains observed tell direction despite target movement")
	equal(Vector2i(heavy.aim_target_x, heavy.aim_target_y), Vector2i(-1, -1), "commitment is direction only, not a fictional target lock")
	equal(Vector2i(heavy.move_x, heavy.move_y), Vector2i.ZERO, "Heavy release starts from stationary tell")
	var pressure_tick := Rival.READY_END + Rival.WINDUP_TICKS + Rival.RAPID_START
	var moving := _command(world, pressure_tick)
	check(moving.move_x != 0 or moving.move_y != 0, "paid pressure includes ordinary movement")
	equal(moving.first_held_spell_slot(), int(profile.slots.rapid), "Rapid burst requests its real held family")
	for bad: Dictionary in [{}, {"rapid":1,"bolt":1,"heavy":3}, {"rapid":1,"bolt":2,"heavy":13}, {"rapid":1,"bolt":2,"heavy":3.0}, {"rapid":2,"bolt":1,"heavy":3}]:
		check(Rival.command_for_tick(pressure_tick, 0, opponent, player, bad, bounds) == null, "invalid or wrong-family slot mapping refuses")
	check(Rival.command_for_tick(pressure_tick, 0, null, player, profile.slots, bounds) == null, "missing rival refuses")
	opponent.team_id = player.team_id
	check(_command(world, pressure_tick) == null, "same-team state refuses")
	opponent.team_id = 2
	opponent.health = 0
	check(_command(world, pressure_tick) == null, "dead rival refuses")
	opponent.health = 1 # Unit validation fixture, never gameplay success proof.
	opponent.position_x = bounds.end.x + 1
	var returning := _command(world, pressure_tick)
	check(returning != null and returning.move_x < 0 and returning.first_held_spell_slot() == 0 and returning.first_pressed_spell_slot() == 0, "displaced rival steers back without attacking rather than going inert")
	for point: Vector2i in [bounds.position, Vector2i(bounds.end.x - 1, bounds.position.y), bounds.end - Vector2i.ONE]:
		opponent.position_x = point.x
		opponent.position_y = point.y
		var command := _command(world, pressure_tick)
		var toward := bounds.get_center() - point
		check(command != null and command.move_x * toward.x + command.move_y * toward.y > 0, "court edge steering points inward")
	player.position_x = bounds.end.x
	check(_command(world, pressure_tick) == null, "player outside trial court refuses")


func _test_ordinary_paid_pressure() -> void:
	var world := _world()
	var opponent := world.player(2)
	var player := world.player(1)
	var original_health := player.health
	var paid := {"heavy":0, "bolt":0, "rapid":0}
	var hits := 0
	var heavy_paid_exactly := false
	var steps_valid := true
	# No teleports, damage injection, resource refills or skipped authority ticks:
	# a motionless ordinary champion must actually be threatened by this policy.
	while world.tick < Rival.READY_END + Rival.CYCLE_TICKS * 2 and player.health > 0:
		var command := _command(world, world.tick)
		if command == null:
			steps_valid = false
			break
		var flux_before := opponent.flux
		steps_valid = world.step([SimCommand.new(world.tick, 1), command]) and steps_valid
		for event: Dictionary in world.combat_events:
			if String(event.get("type", "")) == "cast_started" and int(event.get("entity_id", 0)) == 2:
				for role: String in paid:
					if int(event.get("wire_id", 0)) == int(profile.wires[role]):
						paid[role] += 1
						if role == "heavy" and int(paid.heavy) == 1:
							heavy_paid_exactly = opponent.flux == flux_before - int(CombatTuning.cast_definition_view(int(profile.wires.heavy)).flux_cost)
			if String(event.get("type", "")) == "projectile_hit" and int(event.get("owner_id", 0)) == 2 and int(event.get("target_id", 0)) == 1 and int(event.get("damage", 0)) > 0:
				hits += 1
	check(steps_valid, "production simulation accepts uninterrupted rival commands")
	check(int(paid.heavy) > 0 and int(paid.bolt) > 0 and int(paid.rapid) > 0, "all three announced families pay and start through ordinary combat")
	check(heavy_paid_exactly, "first Heavy pays the exact authored Flux cost")
	check(hits > 0 and player.health < original_health, "ordinary stationary player takes real paid projectile damage")
	check(world.next_projectile_id > 1, "policy pressure releases real allocated projectiles")
	# Explicit insufficient-Flux unit fixture proves commands cannot bypass cost.
	world = _world()
	opponent = world.player(2)
	opponent.flux = 0
	world.tick = Rival.READY_END + Rival.WINDUP_TICKS
	var refused := _command(world, world.tick)
	check(refused != null and opponent.flux == 0, "policy never refills a dry rival")
	check(world.step([SimCommand.new(world.tick, 1), refused]), "dry command still follows ordinary step")
	var admitted := false
	for event: Dictionary in world.combat_events:
		admitted = admitted or (String(event.get("type", "")) == "cast_started" and int(event.get("entity_id", 0)) == 2)
	check(not admitted and opponent.pending_cast_wire_id == 0, "insufficient Flux is refused by ordinary admission")
