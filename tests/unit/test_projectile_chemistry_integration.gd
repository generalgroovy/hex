extends FluxTestSuite

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
	equal(bolts.size(), 8, "all eight elements have a real single-lane paid projectile")
	if bolts.size() != 8:
		return finish("projectile-chemistry-integration")
	_test_locked_point_and_retained_projectiles()
	_test_terminal_deposits()
	_test_clearance_is_not_immunity()
	_test_all_paid_pairs()
	_test_admission_before_payment()
	_test_pending_reservations_and_replay()
	_test_archived_beam_optics()
	_test_extreme_cursor_snapshot()
	return finish("projectile-chemistry-integration")

func _world() -> SimWorld:
	var world := SimWorld.new(120, 809, CollisionWorld.new(8_000_000, 8_000_000))
	_configure_actor(world.player())
	return world

func _configure_actor(actor: PlayerState) -> void:
	actor.champion_wire_id = 1
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
	check(world.projectiles.size() + world.deposits.size() <= 128 and world.reactions.size() <= 32, "live matter and reaction envelopes remain bounded")

func _start(world: SimWorld, wire: int, target: Vector2i) -> void:
	var actor := world.player()
	check(actor.place_proven_spell(0, wire), "actual spell is woven before casting")
	var before := actor.flux
	_step(world, [_command(world, actor, SimCommand.PRESSED_SPELL_1, target)])
	equal(actor.flux, before - int(CombatTuning.cast_definition(wire)["flux_cost"]), "accepted startup spends its real positive Flux cost")
	equal(Vector2i(actor.pending_cast_target_x, actor.pending_cast_target_y), target, "accepted startup locks exact cursor coordinates")

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
		for _index: int in range(160):
			_step(world)
			if world.projectiles.is_empty():
				break
		check(world.projectiles.is_empty() and not world.deposits.is_empty(), "real target-range expiration deposits persistent element matter")
		check(world.reactions.is_empty(), "one cast cannot react with itself through its shared cast identity")
		if expected_lanes == 1 and not world.deposits.is_empty():
			var terminals := world.deposits.filter(func(value: ElementDepositState) -> bool: return not value.is_trail())
			equal(terminals.size(), 1, "single projectile has exactly one terminal, separately from earlier flight trails")
			if terminals.size() == 1:
				check(absi(terminals[0].position_x - target.x) <= 3 and absi(terminals[0].position_y - target.y) <= 3, "single projectile terminates at the captured point within fixed-point rounding")

func _test_terminal_deposits() -> void:
	var wall := _world()
	wall.collision.add_obstacle(CollisionWorld.Obstacle.new(7, 1_150_000, 900_000, 1_170_000, 1_100_000))
	_start(wall, int(bolts[3]), Vector2i(1_500_000, 1_000_000))
	for _index: int in range(120):
		_step(wall)
		if not wall.deposits.is_empty():
			break
	check(not wall.deposits.is_empty(), "solid obstacle impact creates a terminal element deposit")
	if not wall.deposits.is_empty():
		check(wall.deposits[0].position_x <= 1_150_000, "wall impact never places matter through the solid worldbone")
	var expired := _world()
	var projectile := ProjectileState.new(1000, 1, 1, int(bolts[3]), 3, Vector2i(1_300_000, 1_000_000), Vector2i(120_000, 0), 10_000, 1000, 1)
	projectile.source_cast_id = 1000
	expired.projectiles.append(projectile)
	_step(expired)
	check(expired.projectiles.is_empty() and expired.deposits.size() == 1, "legacy untargeted lifetime expiration still deposits matter")
	for _index: int in range(610):
		_step(expired)
	check(expired.deposits.is_empty() and expired.reactions.is_empty(), "terminal matter expires without residual actors or reactions")

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
		world.projectiles.append(ProjectileState.new(1000, 1, 1, int(bolts[3]), 3, Vector2i(1_198_000, 1_000_000), Vector2i(720_000, 0), 10_000, 5000, 30))
		_step(world)
		equal(victim.health, before if height > 18_000 else before - 5000, "only sufficient physical height clears the ground projectile plane")
		check(PlayerResourcesSystem.damage(victim, 1000, world.config), "ground-projectile clearance never becomes universal damage immunity")

func _test_all_paid_pairs() -> void:
	var seen := {}
	for first: int in range(1, 9):
		for second: int in range(first, 9):
			var world := _world()
			var guest := PlayerState.new(2)
			_configure_actor(guest)
			world.players.append(guest)
			check(world.player().place_proven_spell(0, int(bolts[first])) and guest.place_proven_spell(0, int(bolts[second])), "both elemental sources are actual available paid spells")
			var target := Vector2i(1_200_000, 1_000_000)
			_step(world, [_command(world, world.player(), SimCommand.PRESSED_SPELL_1, target), _command(world, guest, SimCommand.PRESSED_SPELL_1, target)])
			check(world.player().flux < 160_000 and guest.flux < 160_000, "both independent reaction inputs pay Flux before matter exists")
			for _index: int in range(240):
				_step(world)
				if not world.reactions.is_empty():
					break
			var expected := ElementChemistrySystem.recipe_wire(first, second)
			check(world.reactions.size() == 1, "paid element pair %d+%d creates one reaction through the complete world pipeline" % [first, second])
			if not world.reactions.is_empty():
				equal(world.reactions[0].recipe_wire_id, expected, "live paid pair produces its exact authored recipe")
				check(world.reactions[0].source_a != world.reactions[0].source_b, "two distinct paid cast identities own every reaction")
				seen[expected] = true
				var replica := SimWorld.new(120, 809)
				check(SessionSnapshot.apply_to_world(SessionSnapshot.capture(world, {}), replica), "actual formed recipe reaches remote presentation through validated snapshot")
		equal(seen.size(), first * (17 - first) / 2, "upper-triangle paid pair coverage advances without duplicate recipes")
	equal(seen.size(), 36, "all 36 recipes are proven through ordinary paid casts, not injected deposits")

func _test_admission_before_payment() -> void:
	var world := _world()
	for index: int in range(16):
		var admitted := ElementChemistrySystem.deposit_terminal(world.deposits, 3000 + index, 2000 + index, int(bolts[3]), 1, 1, 3, Vector2i(2_000_000 + index * 200_000, 2_000_000), 0, world.config)
		equal(admitted, 1, "fixture occupies each legal owner material slot")
	check(world.player().place_proven_spell(0, int(bolts[3])), "capacity test equips a real projectile")
	var before := world.player().flux
	_step(world, [_command(world, world.player(), SimCommand.PRESSED_SPELL_1, Vector2i(1_200_000, 1_000_000))])
	equal(world.player().flux, before, "full terminal-deposit reservation refuses before Flux payment")
	equal(world.player().pending_cast_wire_id, 0, "refused capacity cannot create an unreserved pending cast")
	check(world.combat_events.any(func(event: Dictionary) -> bool: return event.get("type") == "cast_refused" and event.get("reason") == "capacity"), "capacity refusal exposes an actionable authoritative reason")

func _test_pending_reservations_and_replay() -> void:
	var left := _world()
	var right := _world()
	for world: SimWorld in [left, right]:
		for actor_id: int in range(2, 9):
			var actor := PlayerState.new(actor_id)
			_configure_actor(actor)
			world.players.append(actor)
		for actor: PlayerState in world.players:
			check(actor.place_proven_spell(0, 179), "eight-player reservation fixture equips real single-projectile Heavy")
			for index: int in range(15):
				var identifier := actor.entity_id * 20 + index
				equal(ElementChemistrySystem.deposit_terminal(world.deposits, 3000 + identifier, 2000 + identifier, int(bolts[3]), actor.entity_id, 1, 3, Vector2i(2_000_000 + index * 200_000, 2_000_000 + actor.entity_id * 200_000), 0, world.config), 1, "each owner leaves exactly one free real material slot")
	var reached_full := false
	for index: int in range(250):
		var commands_left: Array[SimCommand] = []
		var commands_right: Array[SimCommand] = []
		for actor: PlayerState in left.players:
			var target := Vector2i(1_200_000, 500_000 + actor.entity_id * 70_000)
			commands_left.append(_command(left, actor, SimCommand.PRESSED_SPELL_1 if index == 0 else 0, target))
			commands_right.push_front(_command(right, right.player(actor.entity_id), SimCommand.PRESSED_SPELL_1 if index == 0 else 0, target))
		_step(left, commands_left)
		_step(right, commands_right)
		equal(left.state_hash(), right.state_hash(), "paid eight-player chemistry replay ignores command container order at tick %d" % index)
		if index == 0:
			for actor: PlayerState in left.players:
				check(actor.pending_cast_wire_id == 179 and actor.flux < 160_000, "all eight admitted Heavy startups pay and reserve one complete terminal each")
				equal(left.available_cast_capacity(actor.entity_id).x, 0, "pending casts reserve both global and owner terminal slots before release")
		if left.projectiles.size() + left.deposits.size() == 128:
			reached_full = true
	check(reached_full, "all eight paid Heavy casts reach the complete 128-slot matter envelope without dropping paid terminals")
	check(left.projectiles.is_empty(), "all admitted finite-range lanes terminate without lingering projectiles")

func _test_archived_beam_optics() -> void:
	# Retained low-level regression, not paid/live Beam acceptance.
	var archived_definition := CombatDefinitionTable.new()._compile_definition(abilities.ability_from_wire(143), abilities)
	check(CombatTuning.cast_definition(143).is_empty(), "archive optics does not re-enable Beam")
	for recipe: int in [307, 325, 329]:
		var world := _world()
		var pair: Array = ElementChemistrySystem.recipe(recipe)["elements"]
		var material: Array = []
		for index: int in range(2):
			equal(ElementChemistrySystem.deposit_terminal(material, 3000 + index, 2000 + index, int(bolts[int(pair[index])]), 1, 1, int(pair[index]), Vector2i(1_100_000, 1_000_000), 0, world.config), 1, "archived optical fixture builds genuine bounded optical material")
		var optical := ElementChemistrySystem.form_reaction(material[0], material[1], 4000, 0, world.config)
		world.reactions.append(optical)
		world.tick = optical.active_tick
		var fired: Array[Dictionary] = []
		check(CombatSystem._resolve_chemistry_beam(world.player(), 143, archived_definition, Vector2i(1_000_000,1_000_000), Vector2i(1_500_000,1_000_000), world.players, world.config, world.collision, fired, world.reactions, world.tick), "archived optical primitive resolves")
		equal(fired.size(), 3 if recipe == 329 else 2, "archived Beam routes approach and finite optical continuation(s) for recipe %d" % recipe)
		if fired.size() < 2:
			continue
		var continuation := fired[1]
		check(int(continuation.get("origin_x", 0)) > world.player().position_x, "authoritative continuation begins at optical contact, not caster feet")
		if recipe == 307:
			check(int(continuation["end_x"]) < int(continuation["origin_x"]), "archived Beam reflects from mirror plane")
		else:
			check(int(continuation["end_y"]) > int(continuation["origin_y"]), "archived Beam takes the authored positive refraction path")
		if recipe == 329:
			check(int(fired[2]["end_y"]) < int(fired[2]["origin_y"]), "Lens second lane is a distinct opposing refraction")
		for event: Dictionary in fired:
			var packed := SessionSnapshot.encode_event(event)
			check(SessionSnapshot._valid_event_values(packed), "archived optical segment validates for wire transport")
			var decoded := SessionSnapshot.decode_event(packed)
			equal(Vector2i(decoded.get("origin_x", -1), decoded.get("origin_y", -1)), Vector2i(event["origin_x"], event["origin_y"]), "archived optical segment origin survives snapshot wire exactly")

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
	var packet := SessionSnapshot.capture(world, {})
	check(SessionSnapshot.validate(packet), "maximum legal cursor distance cannot invalidate complete world snapshots")
	var replica := _world()
	check(SessionSnapshot.apply_to_world(packet, replica), "remote receives the admitted extreme-range projectile")
	if not replica.projectiles.is_empty():
		equal(replica.projectiles[0].remaining_distance, world.projectiles[0].remaining_distance, "diagonal distance retains exact authoritative fixed-point units")
	world.projectiles[0].remaining_distance = SessionSnapshot.MAX_PROJECTILE_REMAINING_DISTANCE + 1
	check(SessionSnapshot.capture(world, {}).is_empty(), "distance beyond the finite diagonal envelope still fails closed")
