extends FluxTestSuite

const Policy = preload("res://src/sim/hex/hex_recipe_policy.gd")
const CENTER := Vector2i(1_000_000, 1_000_000)

var abilities := AbilityCatalog.new()
var bolts: Dictionary[int, int] = {}

func run() -> int:
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "production spell catalog loads for end-to-end chemistry")
	for wire: int in abilities.runtime_wire_ids:
		var definition := CombatTuning.cast_definition(wire)
		if String(definition.get("shape", "")) == "projectile" and (definition.get("projectile_rotations", [Vector2i(1000, 0)]) as Array).size() == 1:
			var element := int(definition["element_wire_id"])
			if not bolts.has(element):
				bolts[element] = wire
	equal(bolts.size(), 6, "all six elements have a real single-lane paid projectile")
	if bolts.size() != 6:
		return finish("projectile-chemistry-integration")
	_test_locked_point_and_retained_projectiles()
	_test_terminal_deposits()
	_test_clearance_is_not_immunity()
	_test_all_paid_pairs()
	_test_admission_before_payment()
	_test_pending_reservations_and_replay()
	_test_retired_inputs()
	_test_extreme_cursor_snapshot()
	return finish("projectile-chemistry-integration")

func _world() -> SimWorld:
	var world := SimWorld.new(120, 809, CollisionWorld.new(8_000_000, 8_000_000))
	world.hex_court = HexChemistryWorld.new()
	check(world.hex_court.configure_geometry(CENTER, HexGrid.disk(Vector2i.ZERO, 24)), "paid integration topology configures")
	world.hex_court.chemistry_enabled = true
	_configure_actor(world.player())
	return world

func _configure_actor(actor: PlayerState) -> void:
	actor.champion_wire_id = 0
	actor.spawn_protection_ticks = 0
	actor.position_x = 1_000_000
	actor.position_y = 1_000_000
	actor.team_id = 1
	actor.flux_maximum = 160_000
	actor.flux = 160_000
	actor.flux_recovery_per_second = 0
	actor.health_recovery_per_second = 0

func _command(world: SimWorld, actor: PlayerState, pressed: int = 0, target: Vector2i = Vector2i(-1, -1), aim: Vector2i = Vector2i(1000, 0)) -> SimCommand:
	var command := SimCommand.new(world.tick, actor.entity_id, 0, 0, 0, pressed, aim.x, aim.y)
	command.aim_target_x = target.x
	command.aim_target_y = target.y
	return command

func _step(world: SimWorld, commands: Array[SimCommand] = []) -> void:
	check(world.step(commands), "real authoritative cast/chemistry tick executes: %s" % world.last_error)
	check(world.last_error.is_empty(), "reserved terminal deposit never disappears behind a silent admission error")
	check(world.hex_court.conservation_valid(), "every authoritative tick conserves finite paid Hex matter")
	check(world.deposits.is_empty() and world.reactions.is_empty(), "the live authority never co-simulates legacy chemistry")

func _start(world: SimWorld, wire: int, target: Vector2i) -> void:
	var actor := world.player()
	check(actor.place_proven_spell(0, wire), "actual spell is woven before casting")
	var before := actor.flux
	_step(world, [_command(world, actor, SimCommand.PRESSED_SPELL_1, target)])
	equal(actor.flux, before - int(CombatTuning.cast_definition(wire)["flux_cost"]), "accepted startup spends its real positive Flux cost")
	equal(Vector2i(actor.pending_cast_target_x, actor.pending_cast_target_y), target, "accepted startup locks exact cursor coordinates")

func _flight_watch_ticks(config: SimConfig, wire: int, target_distance: float) -> int:
	var definition := CombatTuning.cast_definition(wire)
	var speed := int(definition["speed"])
	var lifetime_ticks := config.milliseconds_to_ticks(int(definition["lifetime_ms"]))
	check(speed > 0 and lifetime_ticks > 0, "finite-range fixture has positive authored travel and lifetime")
	if speed <= 0 or lifetime_ticks <= 0: return 0
	check(target_distance <= speed * int(definition["lifetime_ms"]) / 1000.0, "requested fixture target lies within the authored projectile lifetime reach")
	# Measure the requested caster-to-cursor distance independently of the
	# spawned projectile's remaining range/timer. Omitting muzzle clearance
	# makes this conservative; two ticks cover fixed-point travel and dispatch.
	var travel_ticks := ceili(target_distance * config.tick_rate / speed)
	return mini(travel_ticks, lifetime_ticks) + 2

func _test_locked_point_and_retained_projectiles() -> void:
	for wire: int in [int(bolts[3]), 179, 180]:
		var world := _world()
		var target := Vector2i(1_300_000, 1_000_000)
		_start(world, wire, target)
		for _index: int in range(80):
			_step(world, [_command(world, world.player(), 0, Vector2i(1_000_000, 2_000_000), Vector2i(0, 1000))])
			if not world.projectiles.is_empty():
				break
		var expected_lanes := (CombatTuning.cast_definition(wire).get("projectile_rotations", [Vector2i(1000, 0)]) as Array).size()
		equal(world.projectiles.size(), expected_lanes, "startup mouse movement cannot cancel or alter the authored lane count")
		if world.projectiles.is_empty():
			continue
		var first_id := world.projectiles[0].source_cast_id
		var remaining := world.projectiles[0].remaining_distance
		var total_strength := 0
		for projectile: ProjectileState in world.projectiles:
			check(projectile.velocity_x > 0, "release continues toward locked east point rather than new south aim")
			equal(projectile.source_cast_id, first_id, "all cast fragments share exactly one cast identity")
			check(first_id > 0 and projectile.remaining_distance >= 0, "real release gives a finite cursor range and positive source identity")
			check(absi(projectile.remaining_distance - remaining) <= 10, "all lanes share target-range budget within one integer normalization step")
			total_strength += projectile.material_strength
		equal(total_strength, 1000, "A retained projectile carries one material strength instead of multiplying matter per lane")
		if expected_lanes > 1:
			check(world.projectiles[0].velocity_y * world.projectiles[-1].velocity_y < 0, "Burst preserves opposing spread lanes rather than converging every lane onto the cursor")
		var requested_distance := (target - Vector2i(world.player().position_x, world.player().position_y)).length()
		for _index: int in range(_flight_watch_ticks(world.config, wire, requested_distance)):
			_step(world)
			if world.projectiles.is_empty():
				break
		check(world.projectiles.is_empty() and not _parts(world).is_empty(), "real target-range expiration deposits persistent element matter")
		check(world.hex_court.products.is_empty(), "one cast cannot react with itself through its shared cast identity")
		if expected_lanes == 1:
			var terminals := _parts(world)
			equal(terminals.size(), 1, "single projectile has exactly one terminal")
			if terminals.size() == 1:
				var point: Vector2i = terminals[0].footprint.center
				check(absi(point.x - target.x) <= 3 and absi(point.y - target.y) <= 3, "single projectile terminates at the captured point within fixed-point rounding")


func _parts(world: SimWorld) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in world.hex_court.casts.values():
		for part: Dictionary in record.ground_parts.values():
			result.append(part)
	return result


func _fund_shot(world: SimWorld, id: int, at: Vector2i, velocity: Vector2i, life: int, damage: int = -1) -> ProjectileState:
	var wire := int(bolts[3])
	var definition := CombatTuning.cast_definition(wire)
	check(world.hex_court.reserve_cast(1, wire), "fixture reserves one actual live source")
	world.hex_court.commit_payment(1)
	world.hex_court.bind_release(1, id, at, Vector2i(1000, 0), 1)
	var shot := ProjectileState.new(id, 1, 1, wire, 3, at, velocity, int(definition.radius), int(definition.damage) if damage < 0 else damage, life)
	shot.source_cast_id = id
	shot.reaction_strength = int(definition.reaction_strength)
	world.projectiles.append(shot)
	world.next_projectile_id = maxi(world.next_projectile_id, id + 1)
	return shot


func _test_terminal_deposits() -> void:
	var wall := _world()
	wall.collision.add_obstacle(CollisionWorld.Obstacle.new(7, 1_150_000, 900_000, 1_170_000, 1_100_000))
	_start(wall, int(bolts[3]), Vector2i(1_500_000, 1_000_000))
	for unused: int in range(120):
		_step(wall)
		if not _parts(wall).is_empty(): break
	var parts := _parts(wall)
	check(not parts.is_empty(), "solid obstacle impact creates one real terminal")
	if not parts.is_empty():
		equal(parts[0].footprint.center.x, 1_150_000, "terminal is the exact near wall contact, not the radius-offset center")
		for cell: Vector2i in parts[0].coverage:
			check(wall.hex_court.origin.x + HexGrid.center(cell).x <= 1_150_000, "worldbone prevents selecting material through the far side")
	var expired := _world()
	_fund_shot(expired, 1000, CENTER + Vector2i(300000, 0), Vector2i(120000, 0), 1)
	_step(expired)
	check(expired.projectiles.is_empty() and _parts(expired).size() == 1, "untargeted lifetime expiration transfers the actual paid ledger to ground")
	var terminal: Dictionary = _parts(expired)[0]
	equal(int(terminal.expiry_tick) - int(terminal.created), 720, "Water terminal retains the independently specified six-second paid lifetime")
	while expired.tick < int(terminal.expiry_tick): _step(expired)
	check(not expired.hex_court.casts.is_empty() and _parts(expired).size() == 1, "paid stock still exists after the exact last live tick")
	equal(int(expired.hex_court.metrics.matter_expired), 0, "expiry cannot consume stock one tick early")
	_step(expired)
	check(expired.hex_court.casts.is_empty() and expired.hex_court.products.is_empty(), "terminal stock expires without residual source or product")
	equal(int(expired.hex_court.metrics.matter_expired), 600, "expiry retires exactly one paid600-unit stock")


func _test_clearance_is_not_immunity() -> void:
	for height: int in [17_000, 19_000]:
		var world := _world()
		var victim := PlayerState.new(2)
		_configure_actor(victim)
		victim.team_id = 2
		victim.position_x = 1_200_000
		victim.air_height = height
		victim.hop_stage = 1
		victim.hop_ticks = MovementSystem._remaining_air_ticks(victim, world.config)
		world.players.append(victim)
		check(not MovementSystem.is_combat_intangible(victim, world.config), "height alone is never true combat invulnerability")
		var before := victim.health
		_fund_shot(world, 1000, Vector2i(1_198_000, 1_000_000), Vector2i(720_000, 0), 30, 5000)
		_step(world)
		equal(victim.health, before if height > 18_000 else before - 5000, "only sufficient physical height clears the ground projectile plane")
		check(PlayerResourcesSystem.damage(victim, 1000, world.config), "ground-projectile clearance never becomes universal damage immunity")

func _test_all_paid_pairs() -> void:
	var seen := {}
	for first_index: int in ElementRules.WIRE_IDS.size():
		for second_index: int in range(first_index, ElementRules.WIRE_IDS.size()):
			var first := int(ElementRules.WIRE_IDS[first_index])
			var second := int(ElementRules.WIRE_IDS[second_index])
			var world := _world()
			var guest := PlayerState.new(2)
			_configure_actor(guest)
			world.players.append(guest)
			check(world.player().place_proven_spell(0, int(bolts[first])) and guest.place_proven_spell(0, int(bolts[second])), "both elemental sources are real paid spells")
			var target := CENTER + Vector2i(200000, 0)
			_step(world, [_command(world, world.player(), SimCommand.PRESSED_SPELL_1, target), _command(world, guest, SimCommand.PRESSED_SPELL_1, target)])
			equal(world.player().flux, 160000 - int(CombatTuning.cast_definition(int(bolts[first])).flux_cost), "first reaction input pays its exact full Flux cost")
			equal(guest.flux, 160000 - int(CombatTuning.cast_definition(int(bolts[second])).flux_cost), "second reaction input pays its exact full Flux cost")
			for unused: int in range(240):
				_step(world)
				if not world.hex_court.products.is_empty(): break
			check(world.hex_court.products.size() == 1, "paid pair%d+%d forms through the complete world pipeline" % [first, second])
			if world.hex_court.products.is_empty(): continue
			var product: Dictionary = world.hex_court.products.values()[0]
			var expected := Policy.recipe_wire(first, second)
			equal(int(product.recipe_wire_id), expected, "actual pair produces its exact live recipe")
			equal(product.source_ids.size(), 2, "two distinct paid casts own the result")
			check(product.source_ids[0] != product.source_ids[1], "one cast cannot pay both inputs")
			equal(int(product.funded_strength), 10, "two actual Bolts contribute5+5 strength")
			equal(int(product.damage_budget_remaining), 40000, "formation retains the exact linear unspent pool")
			seen[expected] = true
			var packet := HexWorldSnapshot.capture(world)
			var replica := _world()
			check(HexWorldSnapshot.restore(packet, replica), "paid formed recipe survives validated snapshot")
			equal(replica.state_hash(), world.state_hash(), "remote receives exact complete authority, including finite provenance and geometry")
	equal(seen.size(), 21, "all six self and fifteen cross pairs are proven through ordinary paid casts")


func _test_admission_before_payment() -> void:
	var world := _world()
	for index: int in range(SimConfig.MAX_PROJECTILES_PER_PLAYER):
		_fund_shot(world, 2000 + index, CENTER + Vector2i(300000, index * 5000), Vector2i(120000, 0), 120)
	equal(world.available_cast_capacity(1).x, 0, "sixteen physical owned projectiles consume the real allowance")
	check(world.player().place_proven_spell(0, int(bolts[3])), "capacity test equips a live projectile")
	var before := world.player().flux
	var matter_before := int(world.hex_court.metrics.matter_paid)
	_step(world, [_command(world, world.player(), SimCommand.PRESSED_SPELL_1, CENTER + Vector2i(200000, 0))])
	equal(world.player().flux, before, "physical capacity refusal occurs before payment")
	equal(world.player().pending_cast_wire_id, 0, "refusal leaves no unreserved startup")
	equal(int(world.hex_court.metrics.matter_paid), matter_before, "refusal cannot issue more paid source stock")
	check(world.combat_events.any(func(event: Dictionary) -> bool: return event.get("type") == "cast_refused" and event.get("reason") == "capacity"), "refusal carries its actionable capacity reason")


func _test_pending_reservations_and_replay() -> void:
	var left := _world(); var right := _world()
	for world: SimWorld in [left, right]:
		for actor_id: int in range(2, 9):
			var actor := PlayerState.new(actor_id)
			_configure_actor(actor)
			world.players.append(actor)
		for actor: PlayerState in world.players:
			check(actor.place_proven_spell(0, 179), "eight-player fixture equips actual Heavy")
	var observed_pending := false
	var observed_release := false
	for index: int in range(180):
		var commands_left: Array[SimCommand] = []
		var commands_right: Array[SimCommand] = []
		for actor: PlayerState in left.players:
			var target := CENTER + Vector2i(200000, -280000 + actor.entity_id * 70000)
			commands_left.append(_command(left, actor, SimCommand.PRESSED_SPELL_1 if index == 0 else 0, target))
			commands_right.push_front(_command(right, right.player(actor.entity_id), SimCommand.PRESSED_SPELL_1 if index == 0 else 0, target))
		_step(left, commands_left); _step(right, commands_right)
		equal(left.state_hash(), right.state_hash(), "eight-player paid replay ignores command container order at tick%d" % index)
		if index == 0:
			equal(left.hex_court.pending.size(), 8, "eight simultaneous startups retain eight independent reservations")
			equal(left.hex_court.reserved_products(), 8, "each startup reserves one possible finite product")
			equal(int(left.hex_court.metrics.matter_paid), 4800, "all eight accepted casts mint exactly eight600-unit stocks")
			for actor: PlayerState in left.players:
				equal(actor.flux, 140000, "each admitted Heavy pays exactly20Flux")
				equal(actor.pending_cast_wire_id, 179, "paid Heavy startup stays pending")
			observed_pending = true
		observed_release = observed_release or left.combat_events.any(func(event: Dictionary) -> bool: return String(event.type) == "projectile_spawned")
	check(observed_pending and observed_release, "replay reaches both real admission and physical flight")
	check(left.projectiles.is_empty() and left.hex_court.pending.is_empty(), "all admitted finite-range lanes finish without losing reservations")


func _test_retired_inputs() -> void:
	# Historical Beam/Lens artwork lives in the explicit archive contract. These
	# identities are not current paid-route or network-event acceptance evidence.
	for wire: int in [143, 170, 189, 190, 171, 101, 187, 188, 167]:
		check(CombatTuning.cast_definition(wire).is_empty(), "retired identity cannot regain current combat admission")
		var world := _world()
		var before: String = world.hex_court.state_hash()
		check(not world.hex_court.reserve_cast(1, wire), "retired delivery cannot reserve finite chemistry stock")
		equal(world.hex_court.state_hash(), before, "retired input refusal preserves all paid state")


func _test_extreme_cursor_snapshot() -> void:
	var world := _world()
	_start(world, int(bolts[3]), Vector2i(100_000_000, 100_000_000))
	for _index: int in range(80):
		_step(world)
		if not world.projectiles.is_empty():
			break
	check(not world.projectiles.is_empty(), "maximum accepted diagonal cursor releases a real paid projectile")
	if world.projectiles.is_empty():
		return
	check(world.projectiles[0].remaining_distance > SessionSnapshot.MAX_ABSOLUTE_POSITION, "diagonal range exceeds one coordinate-axis bound")
	var packet := HexWorldSnapshot.capture(world)
	check(HexWorldSnapshot.prepare(packet, world) != null, "maximum legal cursor distance cannot invalidate complete world snapshots")
	var replica := _world()
	check(HexWorldSnapshot.restore(packet, replica), "remote receives the admitted extreme-range projectile")
	if not replica.projectiles.is_empty():
		equal(replica.projectiles[0].remaining_distance, world.projectiles[0].remaining_distance, "diagonal distance retains exact authoritative fixed-point units")
	world.projectiles[0].remaining_distance = SessionSnapshot.MAX_PROJECTILE_REMAINING_DISTANCE + 1
	check(HexWorldSnapshot.capture(world).is_empty(), "distance beyond the finite diagonal envelope still fails closed")
