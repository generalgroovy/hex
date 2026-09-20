extends FluxTestSuite


func run() -> int:
	_test_knockout_respawn_result_and_packet()
	_test_timeout_draw_and_bounds()
	_test_participant_departure()
	_test_definition_and_packet_fail_closed()
	return finish("session-round")


func _world() -> SimWorld:
	var world := SimWorld.new(120, 21, CollisionWorld.new(3_000_000, 2_000_000))
	var guest := PlayerState.new(2)
	guest.team_id = 2
	world.players.append(guest)
	return world


func _definition() -> Dictionary:
	return {
		"bounds": [400, 300, 1200, 900],
		"score_limit": 3,
		"round_seconds": 15,
		"result_seconds": 2,
		"respawn_ms": 500,
		"spawn_protection_ms": 250,
		"spawns": [[500, 400], [1500, 1100]],
	}


func _test_knockout_respawn_result_and_packet() -> void:
	var world := _world()
	var round := SessionRound.new()
	round.bind_hearth()
	world.deposits.append(ElementDepositState.new())
	world.reactions.append(ElementReactionState.new())
	check(round.begin(world, [2, 1], _definition()), "round begins with sorted validated participants")
	check(world.deposits.is_empty() and world.reactions.is_empty(), "new round clears all previous elemental matter and reactions")
	equal(round.phase, SessionRound.Phase.ACTIVE, "round enters active phase")
	equal(round.serial, 1, "round receives a monotonic serial")
	equal(Vector2i(world.player().position_x, world.player().position_y), Vector2i(500_000, 400_000), "host receives first authored spawn")
	equal(Vector2i(world.player(2).position_x, world.player(2).position_y), Vector2i(1_500_000, 1_100_000), "guest receives second authored spawn")
	equal(world.player().team_id, 1, "court assigns host a distinct combat team")
	equal(world.player(2).team_id, 2, "court assigns guest a distinct combat team")
	check(world.player().spawn_protection_ticks > 0, "round spawn grants bounded protection")

	for expected_score: int in range(1, 4):
		world.player(2).health = 0
		if expected_score == 3:
			world.deposits.append(ElementDepositState.new())
			world.reactions.append(ElementReactionState.new())
			world.projectiles.append(ProjectileState.new(5000, 1, 1, CombatTuning.RILLSHOT_WIRE_ID, 2, Vector2i(700_000, 500_000), Vector2i(1, 0), 5_000, 1_000, 30))
			check(CombatTuning.cast_definition(CombatTuning.RIMEWAKE_WIRE_ID).is_empty(), "retired Field has no authority definition before round cleanup")
			# Imported stale state must still be cleared when a result seals.
			world.fields.append(FieldState.new(6000, 1, 1, CombatTuning.RIMEWAKE_WIRE_ID, 5, Vector2i(700_000, 500_000), 72_000, 30, PlayerState.ControlState.SLOWED, 700, 650))
		var emitted := round.advance(world, [{"type": "champion_defeated", "owner_id": 1, "target_id": 2, "projectile_id": 1000 + expected_score}])
		check(emitted.any(func(event: Dictionary) -> bool: return String(event.get("type", "")) == "round_knockout"), "knockout %d emits semantic round feedback" % expected_score)
		equal(int(round.scores_by_entity.get(1, 0)), expected_score, "knockout %d increments only the owner score" % expected_score)
		if expected_score < 3:
			world.tick = int(round.respawn_tick_by_entity[2])
			var respawn_events := round.advance(world, [])
			check(respawn_events.any(func(event: Dictionary) -> bool: return String(event.get("type", "")) == "round_respawned"), "defeated guest respawns after exact delay")
			equal(world.player(2).health, world.player(2).health_maximum, "respawn restores Health")
			check(world.player(2).spawn_protection_ticks > 0, "respawn restores protection")
	equal(round.phase, SessionRound.Phase.RESULT, "score limit seals the result")
	equal(round.winner_entity_id, 1, "score-limit winner is authoritative")
	equal(world.player().velocity_x, 0, "result freezes participant movement")
	equal(world.projectiles.size(), 0, "result clears unresolved projectiles")
	equal(world.fields.size(), 0, "result clears unresolved stale retired Field state")
	check(world.deposits.is_empty() and world.reactions.is_empty(), "sealed round removes elemental matter and reactions before return")
	var packet := round.capture(world)
	check(SessionRound.validate_packet(packet), "result captures to a bounded packed packet")
	var decoded := SessionRound.decoded(packet)
	equal(int(decoded.get("winner_entity_id", 0)), 1, "winner survives round packet")
	equal((decoded.get("entries", []) as Array).size(), 2, "round packet carries both scores")
	check(not round.return_due(world.tick), "result does not return early")
	world.tick = round.result_end_tick
	check(round.return_due(world.tick), "result returns on its exact tick")


func _test_timeout_draw_and_bounds() -> void:
	var world := _world()
	var round := SessionRound.new()
	round.bind_hearth()
	check(round.begin(world, [1, 2], _definition()), "timeout fixture begins")
	world.player().position_x = 10
	world.player().position_y = 1_900_000
	round.advance(world, [])
	check(world.player().position_x >= round.arena_bounds.position.x + world.player().radius, "active court seals left edge")
	check(world.player().position_y <= round.arena_bounds.end.y - world.player().radius, "active court seals bottom edge")
	world.tick = round.round_end_tick
	var finish_events := round.advance(world, [])
	equal(round.phase, SessionRound.Phase.RESULT, "clock expiry seals result")
	equal(round.winner_entity_id, 0, "equal scores produce an explicit draw")
	check(finish_events.any(func(event: Dictionary) -> bool: return String(event.get("type", "")) == "round_finished"), "clock expiry emits result event")


func _test_participant_departure() -> void:
	var world := _world()
	var round := SessionRound.new()
	round.bind_hearth()
	check(round.begin(world, [1, 2], _definition()), "departure fixture begins")
	var emitted := round.remove_participant(2, world)
	equal(round.phase, SessionRound.Phase.RESULT, "last rival departure resolves active court")
	equal(round.winner_entity_id, 1, "surviving participant owns departure result")
	check(emitted.any(func(event: Dictionary) -> bool: return String(event.get("type", "")) == "round_finished"), "departure emits semantic result")
	check(SessionRound.validate_packet(round.capture(world)), "single-survivor result remains a valid packed state")


func _test_definition_and_packet_fail_closed() -> void:
	var world := _world()
	for mutation: Callable in [
		func(value: Dictionary) -> void: value["score_limit"] = 99,
		func(value: Dictionary) -> void: value["round_seconds"] = 1,
		func(value: Dictionary) -> void: value["spawns"] = [[500, 400]],
		func(value: Dictionary) -> void: value["bounds"] = [0, 0, 100, 100],
		func(value: Dictionary) -> void: value["spawns"] = [[500, 400], [2900, 1900]],
	]:
		var definition := _definition()
		mutation.call(definition)
		var round := SessionRound.new()
		round.bind_hearth()
		check(not round.begin(world, [1, 2], definition), "invalid round definition fails closed")
	var idle := SessionRound.new()
	idle.bind_hearth()
	var valid := idle.capture(world)
	check(SessionRound.validate_packet(valid), "idle Hearth round packet validates")
	for mutation: Callable in [
		func(values: PackedInt32Array) -> void: values[0] = 99,
		func(values: PackedInt32Array) -> void: values[1] = 9,
		func(values: PackedInt32Array) -> void: values[4] = 1,
		func(values: PackedInt32Array) -> void: values[6] = 8,
	]:
		var malformed := valid.duplicate()
		mutation.call(malformed)
		check(not SessionRound.validate_packet(malformed), "malformed round packet fails closed")
	var active := SessionRound.new()
	active.bind_hearth()
	check(active.begin(world, [1, 2], _definition()), "active packet fixture begins")
	var forged_score := active.capture(world)
	forged_score[SessionRound.HEADER_VALUES] |= 0x10000
	check(not SessionRound.validate_packet(forged_score), "round packet rejects unused score-lane bits")
