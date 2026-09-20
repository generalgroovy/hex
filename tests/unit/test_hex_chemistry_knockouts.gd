extends FluxTestSuite


const ABILITY_PATH := "res://content/abilities/foundation_abilities_v1.json"
const CHAMPION_PATH := "res://content/champions/foundation_champions_v1.json"


func run() -> int:
	var abilities := AbilityCatalog.new()
	var champions := ChampionCatalog.new()
	check(abilities.load_from_file(ABILITY_PATH), "chemistry knockout fixture loads abilities")
	check(champions.load_from_file(CHAMPION_PATH, abilities), "chemistry knockout fixture loads champions")
	if not abilities.last_error.is_empty() or not champions.last_error.is_empty():
		return finish("hex-chemistry-knockouts")
	_test_fire_and_steam_schedule_owned_respawns(abilities, champions)
	_test_conflagration_reaches_result_and_return(abilities, champions)
	_test_self_knockout_and_training_target(abilities, champions)
	_test_pressure_ties_and_multicell_deduplication(abilities)
	return finish("hex-chemistry-knockouts")


func _test_fire_and_steam_schedule_owned_respawns(abilities: AbilityCatalog, champions: ChampionCatalog) -> void:
	for kind: String in ["fire", "steam"]:
		var fixture := _round_fixture(abilities, champions, 3)
		var world: SimWorld = fixture.world
		var session: AuthoritativeSession = fixture.session
		var target: PlayerState = world.player(2)
		if kind == "fire":
			_paid_terminal(world.hex_court, abilities, 1, "fire", 41_001, Vector2i(target.position_x, target.position_y), 0)
			world.tick = HexChemistryWorld.PULSE_TICKS
		else:
			_paid_terminal(world.hex_court, abilities, 1, "water", 42_001, Vector2i(target.position_x, target.position_y), 0)
			_paid_terminal(world.hex_court, abilities, 1, "fire", 42_002, Vector2i(target.position_x, target.position_y), 0)
			world.tick = HexChemistryWorld.PULSE_TICKS
		target.health = 1
		check(world.step([]), "%s lethal pressure advances through SimWorld" % kind)
		var defeats := _events(world.combat_events, "champion_defeated")
		equal(defeats.size(), 1, "%s emits exactly one champion defeat" % kind)
		if not defeats.is_empty():
			equal(int(defeats[0].owner_id), 1, "%s defeat retains its paid source owner" % kind)
			equal(int(defeats[0].target_id), 2, "%s defeat identifies the damaged champion" % kind)
		var pressure := _events(world.combat_events, "hex_pressure")
		check(not pressure.is_empty() and int(pressure[0].owner_id) == 1, "%s diagnostic pressure retains source ownership" % kind)
		if kind == "fire" and not pressure.is_empty():
			check(int(pressure[0].source_id) == 41_001 and int(pressure[0].cast_id) > 0 and int(pressure[0].product_id) == 0, "Fire pressure identifies its paid cast source")
		if kind == "steam" and not pressure.is_empty():
			check(int(pressure[0].product_id) > 0 and int(pressure[0].source_id) == 0, "Steam pressure identifies its finite product")
		session.advance_round(world.combat_events)
		equal(int(session.session_round.scores_by_entity.get(1, 0)), 1, "%s knockout awards its source owner" % kind)
		check(session.session_round.respawn_tick_by_entity.has(2), "%s knockout schedules the defeated champion" % kind)
		var respawn_tick := int(session.session_round.respawn_tick_by_entity.get(2, -1))
		world.tick = respawn_tick
		var respawn_events := session.advance_round([])
		check(respawn_events.any(func(event: Dictionary) -> bool: return String(event.get("type", "")) == "round_respawned" and int(event.get("entity_id", 0)) == 2), "%s knockout completes its scheduled respawn" % kind)
		equal(target.health, target.health_maximum, "%s respawn restores champion health" % kind)
		check(world.hex_court.conservation_valid(), "%s knockout preserves paid chemistry accounting" % kind)


func _test_conflagration_reaches_result_and_return(abilities: AbilityCatalog, champions: ChampionCatalog) -> void:
	var fixture := _round_fixture(abilities, champions, 1)
	var world: SimWorld = fixture.world
	var session: AuthoritativeSession = fixture.session
	var target: PlayerState = world.player(2)
	var point := Vector2i(target.position_x, target.position_y)
	_paid_terminal(world.hex_court, abilities, 1, "fire", 43_001, point, 0)
	_paid_terminal(world.hex_court, abilities, 1, "fire", 43_002, point, 0)
	target.health = 1
	world.tick = HexChemistryWorld.MEDIUM_FORMATION_TICKS
	check(world.step([]), "lethal Conflagration advances through SimWorld")
	var defeats := _events(world.combat_events, "champion_defeated")
	var diagnostics := _events(world.combat_events, "hex_conflagration")
	equal(defeats.size(), 1, "Conflagration emits exactly one champion defeat")
	check(not diagnostics.is_empty() and int(diagnostics[0].owner_id) == 1 and int(diagnostics[0].product_id) > 0, "Conflagration diagnostic retains product and owner provenance")
	session.advance_round(world.combat_events)
	equal(int(session.session_round.scores_by_entity.get(1, 0)), 1, "Conflagration knockout awards the product owner")
	equal(session.session_round.phase, SessionRound.Phase.RESULT, "Conflagration knockout can reach the score-limit result")
	equal(session.session_round.winner_entity_id, 1, "Conflagration source owner wins the score-limit result")
	check(not session.round_return_due(), "result observes its configured return delay")
	world.tick = session.session_round.result_end_tick
	check(session.round_return_due(), "Conflagration score-limit result reaches the exact return tick")
	check(world.hex_court.conservation_valid(), "Conflagration knockout preserves both paid source budgets")


func _test_self_knockout_and_training_target(abilities: AbilityCatalog, champions: ChampionCatalog) -> void:
	var self_fixture := _round_fixture(abilities, champions, 3)
	var self_world: SimWorld = self_fixture.world
	var self_session: AuthoritativeSession = self_fixture.session
	var owner: PlayerState = self_world.player(1)
	var owner_point := Vector2i(owner.position_x, owner.position_y)
	_paid_terminal(self_world.hex_court, abilities, 1, "fire", 44_001, owner_point, 0)
	_paid_terminal(self_world.hex_court, abilities, 1, "fire", 44_002, owner_point, 0)
	owner.health = 1
	self_world.tick = HexChemistryWorld.MEDIUM_FORMATION_TICKS
	check(self_world.step([]), "self-Conflagration advances through SimWorld")
	equal(_events(self_world.combat_events, "champion_defeated").size(), 1, "self-Conflagration emits one lifecycle transition")
	self_session.advance_round(self_world.combat_events)
	equal(int(self_session.session_round.scores_by_entity.get(1, 0)), 0, "self-knockout cannot award a score")
	check(self_session.session_round.respawn_tick_by_entity.has(1), "self-knockout still schedules the defeated champion")

	var target_fixture := _round_fixture(abilities, champions, 3)
	var target_world: SimWorld = target_fixture.world
	var training := PlayerState.new(91)
	training.actor_kind = PlayerState.ActorKind.TRAINING_TARGET
	training.team_id = 2
	training.position_x = target_world.hex_court.origin.x
	training.position_y = target_world.hex_court.origin.y
	training.training_spawn_x = training.position_x
	training.training_spawn_y = training.position_y
	training.health = 1
	training.health_maximum = 1
	training.health_recovery_per_second = 0
	target_world.players.append(training)
	_paid_terminal(target_world.hex_court, abilities, 1, "fire", 45_001, Vector2i(training.position_x, training.position_y), 0)
	target_world.tick = HexChemistryWorld.PULSE_TICKS
	check(target_world.step([]), "lethal target pressure advances through SimWorld")
	equal(training.health, 0, "pressure can defeat a training target")
	check(_events(target_world.combat_events, "hex_pressure").any(func(event: Dictionary) -> bool: return int(event.get("entity_id", 0)) == training.entity_id), "target damage keeps its pressure diagnostic")
	equal(_events(target_world.combat_events, "champion_defeated").size(), 0, "training targets cannot emit champion knockout lifecycle events")


func _test_pressure_ties_and_multicell_deduplication(abilities: AbilityCatalog) -> void:
	var fire_low := {"damage": 3000, "kind": 0, "stable_id": 10, "owner_id": 1}
	var fire_high := {"damage": 3000, "kind": 0, "stable_id": 20, "owner_id": 2}
	var steam_low := {"damage": 3000, "kind": 1, "stable_id": 1, "owner_id": 3}
	for order: Array in [[steam_low, fire_high, fire_low], [fire_high, fire_low, steam_low], [fire_low, steam_low, fire_high]]:
		var winner := {}
		for candidate: Dictionary in order:
			winner = HexChemistryWorld._stronger_pressure_candidate(winner, candidate)
		equal(int(winner.owner_id), 1, "equal pressure always prefers Fire then its smallest stable source ID")

	var amounts: Array[int] = []
	var owners: Array[int] = []
	for reversed: bool in [false, true]:
		var court := HexCourt.new()
		court.chemistry_enabled = true
		var cast_id := _paid_terminal(court, abilities, 2, "fire", 46_001, court.origin, 0)
		var part: Dictionary = court.casts[cast_id].ground_parts.values()[0]
		check(part.coverage.size() > 1, "paid Bolt supplies a real multi-cell pressure footprint")
		var selected: Array = part.coverage.keys()
		selected.sort_custom(func(left: Vector2i, right: Vector2i) -> bool: return left.x < right.x if left.x != right.x else left.y < right.y)
		if reversed: selected.reverse()
		var start: Vector2i = court.origin + HexGrid.center(selected[0])
		var finish: Vector2i = court.origin + HexGrid.center(selected[selected.size() - 1])
		var actor := PlayerState.new(1)
		actor.team_id = 1
		actor.position_x = finish.x
		actor.position_y = finish.y
		actor.health_recovery_per_second = 0
		var events: Array[Dictionary] = []
		court.advance([actor], {actor.entity_id: start}, HexChemistryWorld.PULSE_TICKS, SimConfig.new(120), events)
		var pressure := _events(events, "hex_pressure")
		equal(pressure.size(), 1, "one paid multi-cell part produces one actor pressure pulse")
		if not pressure.is_empty():
			amounts.append(int(pressure[0].amount))
			owners.append(int(pressure[0].owner_id))
	equal(amounts.size(), 2, "both traversal directions produce an observable pressure pulse")
	if amounts.size() == 2:
		equal(amounts[0], amounts[1], "multi-cell traversal order cannot multiply or change nonlethal pressure")
		equal(owners, [2, 2], "multi-cell traversal retains the same paid source owner")


func _round_fixture(abilities: AbilityCatalog, champions: ChampionCatalog, score_limit: int) -> Dictionary:
	var world := SimWorld.new(120, 91 + score_limit, CollisionWorld.new(1_280_000, 960_000))
	check(champions.apply_to_player(world.player(), "oh_tipi"), "knockout host receives an authored champion")
	check(HexCourtPractice.configure(world, abilities, false), "knockout fixture configures shared hex authority")
	var session := AuthoritativeSession.new()
	check(session.bind(world, champions, Vector2i(640, 710), "Knockout Host", [], "sparring_circle"), "knockout authority binds")
	equal(session.register_peers([{"entity_id": 2, "name": "Knockout Guest"}]), 1, "knockout guest joins the authoritative roster")
	check(session.begin_round({
		"bounds": [0, 0, 1280, 960],
		"score_limit": score_limit,
		"round_seconds": 15,
		"result_seconds": 2,
		"respawn_ms": 500,
		"spawn_protection_ms": 250,
		"spawns": [[900, 700], [640, 480]],
	}), "knockout fixture begins an active round")
	for actor: PlayerState in world.players:
		actor.spawn_protection_ticks = 0
		actor.health_recovery_per_second = 0
	return {"world": world, "session": session}


func _paid_terminal(court: HexChemistryWorld, abilities: AbilityCatalog, owner_id: int, element: String, source_id: int, point: Vector2i, tick: int) -> int:
	var ability_id := abilities.spell_id_at(element, "bolt")
	var wire_id := int(abilities.ability(ability_id).get("wire_id", 0))
	check(wire_id > 0 and court.reserve_cast(owner_id, wire_id), "%s source reserves one real Bolt cast" % element)
	var cast_id := int(court.pending.get(owner_id, 0))
	court.commit_payment(owner_id)
	court.bind_release(owner_id, source_id, point, Vector2i(1000, 0), owner_id)
	var definition := CombatTuning.cast_definition(wire_id)
	court.deposit_terminal({
		"type": "projectile_terminal",
		"projectile_id": source_id,
		"source_cast_id": source_id,
		"source_wire_id": wire_id,
		"owner_id": owner_id,
		"team_id": owner_id,
		"element_wire_id": int(definition.get("element_wire_id", 0)),
		"position": point,
		"direction": Vector2i(1000, 0),
		"strength": 1000,
		"reaction_strength": int(definition.get("reaction_strength", 0)),
	}, tick)
	check(cast_id > 0 and bool(court.casts[cast_id].paid), "%s source retains its committed payment" % element)
	check(court.conservation_valid(), "%s terminal preserves finite source accounting" % element)
	return cast_id


func _events(events: Array, event_type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in events:
		if String(event.get("type", "")) == event_type:
			result.append(event)
	return result
