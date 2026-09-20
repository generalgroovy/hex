extends FluxTestSuite

var catalog := AbilityCatalog.new()

func run() -> int:
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "current catalogue loads")
	_paid_terminal()
	_targeted_terminal()
	_negation()
	_reservations()
	_visibility_and_wire()
	return finish("spray-interception")

func _wire(element: String, family: String) -> int:
	return int(catalog.ability(catalog.spell_id_at(element, family)).wire_id)

func _world() -> SimWorld:
	var world := SimWorld.new(120, 443, CollisionWorld.new(4000000, 4000000))
	world.player().position_x = 1000000
	world.player().position_y = 1000000
	world.player().champion_wire_id = 1
	world.player().flux_recovery_per_second = 0
	check(world.player().place_proven_spell(0, _wire("water", "spray")), "Water Spray equipped")
	return world

func _command(world: SimWorld, pressed: int = 0) -> SimCommand:
	return SimCommand.new(world.tick, 1, 0, 0, 0, pressed, 1000, 0)

func _paid_terminal() -> void:
	for element: String in AbilityCatalog.DISPLAY_ELEMENT_IDS:
		var world := _world()
		var wire := _wire(element, "spray")
		check(world.player().place_proven_spell(0, wire), "each Spray equips")
		var before := world.player().flux
		check(world.step([_command(world, SimCommand.PRESSED_SPELL_1)]), "paid startup enters authority")
		var released := false
		for index: int in range(100):
			check(world.step([_command(world)]), "Spray startup/release remains valid")
			if not world.deposits.is_empty():
				released = true
				break
		check(released, "%s Spray leaves one surviving ingredient" % element)
		equal(world.deposits.size(), 1, "visual grains do not multiply ingredients")
		if released:
			equal(world.deposits[0].reaction_strength, 3, "integer strength stays separate from quantity")
			equal(world.deposits[0].source_cast_id, 1000, "one allocated cast ID follows the pulse")
			equal(world.deposits[0].strength, 1000, "one shared material budget")
		equal(before - world.player().flux, int(CombatTuning.cast_definition(wire).flux_cost), "one payment")
		equal(world.next_projectile_id, 1001, "deferred pulse advances identity before later release")
		equal(world._deferred_spray_slots(), 0, "terminal consumption discharges reservation")

func _targeted_terminal() -> void:
	var world := _world()
	check(world.player().place_proven_spell(1, _wire("earth", "spray")), "Earth target test equips")
	for pressed: int in [SimCommand.PRESSED_SPELL_1, SimCommand.PRESSED_SPELL_2]:
		var command := _command(world, pressed)
		command.aim_target_x = 1260000
		command.aim_target_y = 1000000
		check(world.step([command]), "ground-targeted Spray starts")
		for index: int in range(60):
			check(world.step([_command(world)]), "targeted Spray resolves normally")
		if pressed == SimCommand.PRESSED_SPELL_1:
			equal(world.deposits.size(), 1, "Water leaves one targeted ingredient")
			if not world.deposits.is_empty():
				equal(world.deposits[0].position_x, 1260000, "Spray stops at the selected ground distance")
	check(not world.reactions.is_empty(), "Water and Earth at the same reachable point react")
	var request := {"source_wire_id": _wire("water", "spray"), "origin_x": 1000000, "origin_y": 1000000, "target_x": 1100000, "target_y": 1000000}
	equal(int(CombatSystem.spray_request_definition(request).range), 100000, "interception and actor resolution use the same shortened reach")
	request.target_x = 3000000
	equal(int(CombatSystem.spray_request_definition(request).range), int(CombatTuning.cast_definition(_wire("water", "spray")).range), "ground target cannot extend authored reach")
	# Movement during startup retargets the release, including non-square distance.
	var moving := _world()
	var target := PlayerState.new(2)
	target.team_id = 2
	target.position_x = 1100000
	target.position_y = 1050000
	target.spawn_protection_ticks = 0
	moving.players.append(target)
	var health := target.health
	var cast := _command(moving, SimCommand.PRESSED_SPELL_1)
	cast.aim_target_x = target.position_x
	cast.aim_target_y = target.position_y
	check(moving.step([cast]), "oblique targeted startup")
	while moving.player().pending_cast_ticks > 1:
		var travel := SimCommand.new(moving.tick, 1, 0, -1, 0, 0, 1000, 0)
		check(moving.step([travel]), "move independently during targeted startup")
	check(moving.step([_command(moving)]), "oblique targeted release")
	check(target.health < health, "selected oblique actor remains inside release after movement")
	for event: Dictionary in moving.combat_events:
		if String(event.type) == "spray_fired":
			var packed := SessionSnapshot.encode_event(event)
			check(SessionSnapshot._valid_event_values(packed), "targeted range is valid on wire")
			equal(int(SessionSnapshot.decode_event(packed).range), int(event.range), "guest receives actual pulse reach")


func _negation() -> void:
	for family: String in ["rapid", "bolt", "heavy"]:
		for reversed: bool in [false, true]:
			var world := _world()
			check(world.step([_command(world, SimCommand.PRESSED_SPELL_1)]), "interception pulse paid")
			while world.player().pending_cast_ticks > 1:
				check(world.step([_command(world)]), "paid startup ticks normally")
			var wire := _wire("fire", family)
			var definition := CombatTuning.cast_definition(wire)
			for index: int in range(2):
				var shot := ProjectileState.new(2000 + index, 2, 2, wire, 2, Vector2i(1060000 + index * 10000, 1000000), Vector2i(-200000, 0), 5000, 9000, 120)
				shot.source_cast_id = 2000
				shot.reaction_strength = int(definition.reaction_strength)
				world.projectiles.append(shot)
			if reversed:
				world.projectiles.reverse()
			check(world.step([_command(world)]), "release resolves against the actual flight list")
			var outcomes: Array[Dictionary] = []
			for event: Dictionary in world.combat_events:
				if String(event.type) == "spray_intercepted":
					outcomes.append(event)
			equal(outcomes.size(), 1, "whole cast consumes one clash confirmation")
			if not outcomes.is_empty():
				equal(int(outcomes[0].projectile_id), 2000, "stable entity order independent of input storage")
				equal(int(outcomes[0].outcome), 1 if family == "rapid" else 2, "integer dominance decides outcome")
			equal(world.projectiles.size(), 0 if family == "rapid" else 2, "negated cast loses every flight sibling")
			equal(world.deposits.size(), 1 if family == "rapid" else 0, "negated pulse cannot later deposit")
			for event: Dictionary in world.combat_events:
				if family != "rapid":
					check(String(event.type) not in ["spray_fired", "spray_hit"], "negated pulse cannot damage or claim release")

func _reservations() -> void:
	var world := _world()
	for index: int in range(16):
		var deposit := ElementDepositState.new()
		deposit.entity_id = 3000 + index
		deposit.owner_id = 1
		deposit.source_cast_id = 4000 + index
		deposit.strength = 1000
		deposit.expiry_tick = 600
		world.deposits.append(deposit)
	var before := world.player().flux
	check(world.step([_command(world, SimCommand.PRESSED_SPELL_1)]), "full material state refuses cleanly")
	equal(world.player().flux, before, "capacity refusal spends no Flux")
	equal(world.player().pending_cast_wire_id, 0, "capacity refusal starts no pending cast")
	equal(world.player().spell_cooldown_for_wire(_wire("water", "spray")), 0, "capacity refusal starts no cooldown")
	world = _world()
	world.combat_events.append({"type": "spray_requested", "owner_id": 1})
	equal(world._deferred_spray_slots(), 1, "release request retains its material reservation")
	equal(world.available_cast_capacity(1).x, 15, "later same-owner admission sees deferred release")
	world.combat_events.assign([{"type": "projectile_terminal", "spray_reservation": true, "owner_id": 1}])
	equal(world.available_cast_capacity(1).x, 15, "terminal handoff retains the same reservation")
	equal(int(world._owner_material_slots()[1]), 15, "split offer cannot steal paid terminal")

func _visibility_and_wire() -> void:
	var collision := CollisionWorld.new(4000000, 4000000)
	collision.add_obstacle(CollisionWorld.Obstacle.new(1, 1050000, 990000, 1050001, 1010000))
	check(not SprayInterception.clear_ray(Vector2i(1000000, 1000000), Vector2i(1100000, 1000000), collision, [], 0), "one-unit worldbone cannot be skipped")
	check(SprayContactGeometry.segment_intersects_circle(Vector2i(0, 125000), Vector2i(100000, 125000), Vector2i(50000, 0), 125000), "maximum valid cover radius includes tangent")
	check(SprayContactGeometry.segment_intersects_circle(Vector2i(99900000, 99999999), Vector2i(100100000, 99999999), Vector2i(100050000, 100000000), 125000), "derived cover endpoints outside center envelope remain queryable")
	var event := {"type": "spray_intercepted", "owner_id": 1, "source_wire_id": _wire("water", "spray"), "projectile_id": 2000, "other_wire_id": _wire("fire", "rapid"), "x": 1200000, "y": 1000000, "outcome": 1, "event_id": 9}
	var encoded := SessionSnapshot.encode_event(event)
	check(SessionSnapshot._valid_event_values(encoded), "new authoritative outcome validates")
	equal(SessionSnapshot.decode_event(encoded), event, "outcome round trip preserves every field")
	encoded[7] = 3
	check(not SessionSnapshot._valid_event_values(encoded), "unimplemented direct equality outcome is not admitted")
