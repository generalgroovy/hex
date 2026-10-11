extends FluxTestSuite


const MODES: Array[int] = [SessionRound.Mode.DUOS, SessionRound.Mode.TRIOS]


func run() -> int:
	_test_exact_counts_and_atomic_rejection()
	_test_sparse_rosters_and_default_ffa()
	_test_hostile_team_points_and_shared_threshold()
	_test_complete_tick_draws_and_timeouts()
	_test_departure_ledger_and_forfeit()
	_test_authoritative_admission_reconnect_observer_and_rematch()
	_test_packet_fail_closed()
	_test_charter_contract()
	return finish("team-round")


func _ids(mode: int) -> Array[int]:
	if mode == SessionRound.Mode.DUOS:
		return [1, 4, 6, 8]
	return [1, 2, 4, 5, 7, 8]


func _world(ids: Array[int]) -> SimWorld:
	var world := SimWorld.new(120, 731, CollisionWorld.new(3_000_000, 2_000_000))
	for entity_id: int in ids:
		if entity_id != 1:
			world.players.append(PlayerState.new(entity_id))
	return world


func _definition() -> Dictionary:
	return {
		"bounds": [400, 300, 1200, 900], "score_limit": 3, "round_seconds": 15,
		"result_seconds": 2, "respawn_ms": 500, "spawn_protection_ms": 250,
		"spawns": [[500, 400], [1500, 400], [500, 1100], [1500, 1100], [500, 750], [1500, 750], [700, 550], [1300, 550]],
	}


func _defeat(round: SessionRound, world: SimWorld, owner_id: int, target_id: int) -> Array[Dictionary]:
	var target := world.player(target_id)
	if target != null:
		target.health = 0
	return round.advance(world, [{"type": "champion_defeated", "owner_id": owner_id, "target_id": target_id}])


func _respawn(round: SessionRound, world: SimWorld) -> void:
	for respawn_tick: int in round.respawn_tick_by_entity.values():
		world.tick = maxi(world.tick, respawn_tick)
	round.advance(world, [])


func _test_exact_counts_and_atomic_rejection() -> void:
	for mode: int in MODES:
		var required := SessionRound.required_players(mode)
		for count: int in range(1, 9):
			var entrants: Array[int] = []
			for entity_id: int in range(1, count + 1):
				entrants.append(entity_id)
			var world := _world(entrants)
			var round := SessionRound.new()
			round.configured_result_ticks = 927
			var original_actor := world.player().canonical_values()
			var began := round.begin(world, entrants, _definition(), mode)
			equal(began, count == required, "mode %d admits exactly %d, rejects count %d" % [mode, required, count])
			if count != required:
				equal(round.phase, SessionRound.Phase.HEARTH, "wrong count leaves Hearth unchanged")
				equal(round.serial, 0, "wrong count does not consume round identity")
				equal(round.configured_result_ticks, 927, "wrong count cannot mutate result configuration")
				equal(world.player().canonical_values(), original_actor, "wrong count cannot mutate a champion")
		var ids := _ids(mode)
		var world := _world(ids)
		var duplicate := ids.duplicate()
		duplicate[duplicate.size() - 1] = duplicate[0]
		var missing := ids.duplicate()
		missing[missing.size() - 1] = 3
		for entrants: Array[int] in [duplicate, missing]:
			var round := SessionRound.new()
			round.configured_result_ticks = 927
			check(not round.begin(world, entrants, _definition(), mode), "duplicate or missing champion cannot start team round")
			equal(round.configured_result_ticks, 927, "validation after arena parsing is atomic")
		check(not SessionRound.new().begin(world, ids, _definition(), 99), "unknown mode has no FFA fallback")


func _test_sparse_rosters_and_default_ffa() -> void:
	for mode: int in MODES:
		var ids := _ids(mode)
		var world := _world(ids)
		var round := SessionRound.new()
		var scrambled := ids.duplicate()
		scrambled.reverse()
		check(round.begin(world, scrambled, _definition(), mode), "sparse unsorted roster starts team mode")
		for index: int in range(ids.size()):
			var entity_id := ids[index]
			var expected_team := (index % 2) + 1
			equal(world.player(entity_id).team_id, expected_team, "combat team uses sorted position, not entity parity")
			equal(round.team_by_entity[entity_id], expected_team, "frozen team ledger matches combat authority")
			equal(round.spawn_by_entity[entity_id].x, 500_000 if expected_team == 1 else 1_500_000, "alternating authored slots separate west and east teams")
			equal(round.scores_by_entity[entity_id], 0, "each frozen teammate starts with zero personal points")
		var decoded := SessionRound.decoded(round.capture(world))
		equal(int(decoded.get("mode", -1)), mode, "packet explicitly identifies Duos or Trios")
		equal(decoded.get("team_scores", {}), {1: 0, 2: 0}, "packet supplies both team totals")
		check(not decoded.is_empty(), "exact team roster produces a strict valid packet")
	var ids: Array[int] = [1, 4, 6, 8]
	var world := _world(ids)
	var ffa := SessionRound.new()
	check(ffa.begin(world, ids, _definition()), "omitting mode retains the FFA contract")
	for entity_id: int in ids:
		equal(world.player(entity_id).team_id, entity_id, "default FFA retains distinct sparse combat teams")
	check(ffa.scores_by_team.is_empty(), "FFA never accumulates hidden team points")
	check(SessionRound.validate_packet(ffa.capture(world)), "FFA remains valid in explicit v2 schema")


func _test_hostile_team_points_and_shared_threshold() -> void:
	for mode: int in MODES:
		var ids := _ids(mode)
		var world := _world(ids)
		var round := SessionRound.new()
		check(round.begin(world, ids, _definition(), mode), "hostile scoring fixture begins")
		for owner_id: int in [0, ids[1], ids[3], 3]:
			var events := _defeat(round, world, owner_id, ids[1])
			equal(round.scores_by_team, {1: 0, 2: 0}, "environment, self, ally and nonparticipant earn no team point")
			equal(int(events[0].get("credited_team_id", -1)), 0, "uncredited defeat exposes no credited team")
			check(not bool(events[0].get("scored", true)), "uncredited defeat is explicit")
			check(round.respawn_tick_by_entity.has(ids[1]), "uncredited defeat still schedules a normal respawn")
			_respawn(round, world)
			check(world.player(ids[1]).health > 0, "uncredited defeat respawns the actor normally")
		_defeat(round, world, ids[0], ids[1])
		_respawn(round, world)
		_defeat(round, world, ids[2], ids[3])
		equal(round.scores_by_team[1], 2, "different teammates contribute to one shared score")
		equal(round.scores_by_entity[ids[0]], 1, "first teammate retains personal contribution")
		equal(round.scores_by_entity[ids[2]], 1, "second teammate retains personal contribution")
		_respawn(round, world)
		var final_events := _defeat(round, world, ids[2], ids[1])
		equal(round.phase, SessionRound.Phase.RESULT, "shared threshold ends round without a personal threshold")
		equal(round.winner_entity_id, 0, "team result never invents an individual winner")
		equal(round.winner_team_id, 1, "whole team wins the shared score result")
		equal(round.result_reason, SessionRound.ResultReason.SCORE_LIMIT, "team threshold has an explicit score-limit reason")
		equal(int(final_events.back().get("winner_team_id", 0)), 1, "semantic finish event carries the team winner")
		check(SessionRound.validate_packet(round.capture(world)), "shared score result serializes consistently")
		var forged_winner := round.capture(world)
		forged_winner[8] = 2
		check(not SessionRound.validate_packet(forged_winner), "score-limit packet rejects a winner inconsistent with earned team totals")
		var forged_draw := round.capture(world)
		forged_draw[8] = 0
		check(not SessionRound.validate_packet(forged_draw), "unequal team score-limit result cannot forge a draw")
		var forged_timeout := round.capture(world)
		forged_timeout[11] = SessionRound.ResultReason.TIMEOUT
		check(not SessionRound.validate_packet(forged_timeout), "reached score-limit cannot claim a timeout result")
		round.remove_participant(ids[2], world)
		equal(round.winner_team_id, 1, "winner survives its scorer's later RESULT departure")
		check(SessionRound.validate_packet(round.capture(world)), "score-limit result remains valid after scorer departure")


func _test_complete_tick_draws_and_timeouts() -> void:
	for mode: int in MODES:
		for reverse_order: bool in [false, true]:
			var ids := _ids(mode)
			var world := _world(ids)
			var round := SessionRound.new()
			check(round.begin(world, ids, _definition(), mode), "team threshold trade begins")
			for _point: int in range(2):
				_defeat(round, world, ids[0], ids[1])
				_respawn(round, world)
				_defeat(round, world, ids[1], ids[0])
				_respawn(round, world)
			var events: Array[Dictionary] = [
				{"type": "champion_defeated", "owner_id": ids[2], "target_id": ids[1]},
				{"type": "champion_defeated", "owner_id": ids[3], "target_id": ids[0]},
			]
			if reverse_order:
				events.reverse()
			events.append(events[0].duplicate())
			world.tick = round.round_end_tick
			var emitted := round.advance(world, events)
			equal(round.scores_by_team, {1: 3, 2: 3}, "both teams score the complete threshold tick exactly once")
			equal(round.winner_team_id, 0, "simultaneous threshold trade draws regardless of iteration order")
			var forged_winner := round.capture(world)
			forged_winner[8] = 1
			check(not SessionRound.validate_packet(forged_winner), "tied score-limit result rejects a fabricated team winner")
			equal(emitted.filter(func(event: Dictionary) -> bool: return event.type == "round_finished").size(), 1, "threshold/deadline coincidence emits exactly one result")
			equal(emitted.filter(func(event: Dictionary) -> bool: return event.type == "round_knockout").size(), 2, "duplicate victim earns no second point")
			check(round.advance(world, events).is_empty(), "sealed result cannot process another trade")
			check(SessionRound.validate_packet(round.capture(world)), "complete tied result has valid team totals")
		for earned_point: bool in [false, true]:
			var ids := _ids(mode)
			var world := _world(ids)
			var round := SessionRound.new()
			check(round.begin(world, ids, _definition(), mode), "team timeout fixture begins")
			if earned_point:
				_defeat(round, world, ids[1], ids[0])
			world.tick = round.round_end_tick
			round.advance(world, [])
			equal(round.winner_team_id, 2 if earned_point else 0, "deadline uses team leader or explicit draw")
			equal(round.result_reason, SessionRound.ResultReason.TIMEOUT, "deadline has an explicit timeout reason")
			check(SessionRound.validate_packet(round.capture(world)), "timeout result is a strict valid packet")
			var forged_limit := round.capture(world)
			forged_limit[11] = SessionRound.ResultReason.SCORE_LIMIT
			check(not SessionRound.validate_packet(forged_limit), "below-threshold timeout cannot claim a score-limit result")


func _test_departure_ledger_and_forfeit() -> void:
	for mode: int in MODES:
		var ids := _ids(mode)
		var world := _world(ids)
		var round := SessionRound.new()
		check(round.begin(world, ids, _definition(), mode), "departure ledger fixture begins")
		_defeat(round, world, ids[2], ids[1])
		_respawn(round, world)
		check(round.remove_participant(ids[2], world).is_empty(), "one teammate departure does not forfeit a populated team")
		check(not round.is_participant(ids[2]), "permanent departure removes scoring eligibility")
		equal(round.scores_by_team[1], 1, "departing scorer cannot erase earned team points")
		equal(round.scores_by_entity[ids[2]], 1, "departed player's personal contribution remains visible")
		equal(round.team_by_entity[ids[2]], 1, "departure cannot reshuffle the frozen assignment")
		var decoded := SessionRound.decoded(round.capture(world))
		var departed_entry: Dictionary = decoded.entries[2]
		check(not bool(departed_entry.present), "wire ledger explicitly marks departed member absent")
		_defeat(round, world, ids[2], ids[1])
		equal(round.scores_by_team[1], 1, "departed owner cannot earn more team points")
		_respawn(round, world)
		for index: int in range(0, ids.size(), 2):
			round.remove_participant(ids[index], world)
		equal(round.phase, SessionRound.Phase.RESULT, "only whole-team departure ends the round")
		equal(round.winner_team_id, 2, "surviving team wins forfeiture even when trailing on points")
		equal(round.result_reason, SessionRound.ResultReason.FORFEIT, "whole-team departure has explicit forfeit reason")
		equal(round.scores_by_team, {1: 1, 2: 0}, "forfeit preserves earned scores without synthetic points")
		check(SessionRound.validate_packet(round.capture(world)), "forfeit serializes the complete frozen ledger")
		for entity_id: int in ids:
			round.remove_participant(entity_id, world)
		equal(round.winner_team_id, 2, "later RESULT departures do not rewrite the sealed winner")
		equal(round.scores_by_team, {1: 1, 2: 0}, "all departures preserve the sealed final totals")
		check(SessionRound.validate_packet(round.capture(world)), "result remains valid with an entirely absent frozen roster")
		round.bind_hearth()
		check(round.team_by_entity.is_empty() and round.departed_by_entity.is_empty() and round.scores_by_team.is_empty(), "Hearth clears the old round ledger only at lifecycle boundary")
		check(round.begin(world, ids, _definition(), mode), "same roster can start the next team round")
		equal(round.serial, 2, "rematch receives the next serial")
		equal(round.scores_by_team, {1: 0, 2: 0}, "rematch resets both team totals")


func _test_authoritative_admission_reconnect_observer_and_rematch() -> void:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "team lifecycle loads abilities")
	var champions := ChampionCatalog.new()
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "team lifecycle loads champions")
	for mode: int in MODES:
		var charter := "duos" if mode == SessionRound.Mode.DUOS else "trios"
		var ids := _ids(mode)
		var world := _world([1])
		check(champions.apply_to_player(world.player(), "oh_tipi"), "team lifecycle applies host")
		var session := AuthoritativeSession.new()
		check(session.bind(world, champions, Vector2i(1280, 720), "Host", [], charter), "team charter binds authority")
		for index: int in range(1, ids.size() - 1):
			equal(session.register_peers([{"entity_id": ids[index], "name": "Player %d" % ids[index]}]), 1, "team guest joins")
		for entity_id: int in session.hearth.connected_entity_ids():
			check(session.toggle_ready(entity_id), "incomplete team roster can signal readiness")
		check(not session.can_start_practice(), "ready but incomplete team roster cannot begin countdown")
		check(not session.start_practice_countdown(1), "host cannot bypass exact-count gate")
		check(not session.begin_round(_definition()), "direct begin cannot bypass exact-count gate")
		var final_id: int = ids.back()
		equal(session.register_peers([{"entity_id": final_id, "name": "Final"}]), 1, "last exact-count entrant joins")
		check(session.toggle_ready(final_id), "last entrant confirms readiness")
		check(session.can_start_practice(), "exact ready team roster can start")
		check(not session.start_practice_countdown(final_id), "guest cannot start the team countdown")
		check(session.start_practice_countdown(1), "host starts exact team countdown")
		equal(session.suspend_peers([{"entity_id": final_id, "reserved": true}]), 1, "countdown participant reserves reconnect slot")
		check(not session.practice_countdown_active(), "reservation loss cancels team countdown")
		check(not session.begin_round(_definition()), "returning reservation cannot count as an entrant")
		equal(session.register_peers([{"entity_id": final_id, "name": "Final", "resumed": true}]), 1, "reserved participant reconnects before begin")
		check(session.toggle_ready(final_id), "resumed entrant must ready again")
		check(session.start_practice_countdown(1), "team countdown can restart after reserved reconnect")
		world.tick += world.config.milliseconds_to_ticks(3000)
		check(session.practice_countdown_completed(), "exact-count team countdown completes on deadline")
		check(session.begin_round(_definition()), "authority routes charter into a team round")
		session.clear_practice_start()
		equal(session.session_round.mode, mode, "authority never starts FFA for a team charter")
		check(not session.set_charter("open_commons"), "live charter mutation cannot overwrite frozen team assignments")
		var round := session.session_round
		_defeat(round, world, ids[2], ids[1])
		var before := round.capture(world)
		var actor := world.player(ids[1])
		equal(session.suspend_peers([{"entity_id": ids[1], "reserved": true}]), 1, "defeated teammate reserves reconnect")
		equal(session.register_peers([{"entity_id": ids[1], "name": "Returned", "resumed": true}]), 1, "defeated teammate resumes")
		check(world.player(ids[1]) == actor, "reserved reconnect preserves the existing actor")
		equal(round.capture(world), before, "reserved reconnect preserves complete frozen roster, team totals and respawn clock")
		_respawn(round, world)
		equal(session.remove_peers([{"entity_id": ids[2]}]), 1, "scorer leaves permanently")
		equal(round.scores_by_team[1], 1, "authority departure preserves earned team score")
		equal(session.register_peers([{"entity_id": ids[2], "name": "Replacement"}]), 1, "vacated transport slot can admit a waiting observer")
		check(session.input_locked(ids[2]), "reused entity ID does not reactivate departed round participation")
		equal(world.player(ids[2]).health, 0, "replacement waits for the next gathering")
		check(not round.is_participant(ids[2]), "historical score row is not an admission capability")
		_defeat(round, world, ids[2], ids[1])
		equal(round.scores_by_team[1], 1, "reused observer ID cannot add to its historical team contribution")
		world.tick = round.round_end_tick
		session.advance_round([])
		equal(round.winner_team_id, 1, "timeout retains departed scorer's earned result")
		var final_before := round.capture(world)
		session.suspend_peers([{"entity_id": ids[1], "reserved": true}])
		session.register_peers([{"entity_id": ids[1], "name": "Returned", "resumed": true}])
		equal(round.capture(world), final_before, "RESULT reconnect preserves the sealed team result")
		var replacement_world := _world([1])
		check(session.replace_world(replacement_world, Vector2i(1280, 720)), "real world replacement returns team charter to Hearth")
		equal(session.session_round.phase, SessionRound.Phase.HEARTH, "replacement closes the old team result")
		for entity_id: int in ids:
			var hearth_actor := session.world.player(entity_id)
			var expected_hearth_team := SessionCharter.team_for_champion(charter, entity_id)
			equal(hearth_actor.team_id, expected_hearth_team, "intermediate Hearth restores charter team instead of leaking completed match team")
			if entity_id == 1:
				continue
			var actor_before := hearth_actor.canonical_values()
			var hearth_round_before := session.session_round.capture(session.world)
			var return_name: String = session.names_by_entity[entity_id]
			equal(session.suspend_peers([{"entity_id": entity_id, "reserved": true}]), 1, "Hearth traveller reserves its return after team result")
			equal(session.register_peers([{"entity_id": entity_id, "name": return_name, "resumed": true}]), 1, "Hearth traveller resumes after team result")
			equal(hearth_actor.team_id, expected_hearth_team, "Hearth reconnect uses the same charter team as initial return")
			equal(hearth_actor.canonical_values(), actor_before, "Hearth reconnect cannot silently change team, loadout or resources")
			equal(session.session_round.capture(session.world), hearth_round_before, "Hearth reconnect cannot resurrect completed team-round state")
		check(session.begin_round(_definition()), "waiting replacement joins only the next exact-count round")
		equal(session.session_round.serial, 2, "real rematch advances serial exactly once")
		check(session.session_round.is_participant(ids[2]), "waiting observer becomes a genuine next-round participant")
		equal(session.session_round.scores_by_team, {1: 0, 2: 0}, "real rematch starts fresh team totals")


func _test_packet_fail_closed() -> void:
	for mode: int in MODES:
		var ids := _ids(mode)
		var world := _world(ids)
		var round := SessionRound.new()
		check(round.begin(world, ids, _definition(), mode), "strict team packet fixture begins")
		var valid := round.capture(world)
		check(SessionRound.validate_packet(valid), "positive control validates before every packet mutation")
		for mutation: Callable in [
			func(v: PackedInt32Array) -> void: v[0] = 1,
			func(v: PackedInt32Array) -> void: v[7] = 99,
			func(v: PackedInt32Array) -> void: v[7] = SessionRound.Mode.FREE_FOR_ALL,
			func(v: PackedInt32Array) -> void: v[7] = SessionRound.Mode.TRIOS if mode == SessionRound.Mode.DUOS else SessionRound.Mode.DUOS,
			func(v: PackedInt32Array) -> void: v[8] = 1,
			func(v: PackedInt32Array) -> void: v[8] = 3,
			func(v: PackedInt32Array) -> void: v[9] = -1,
			func(v: PackedInt32Array) -> void: v[9] = 16,
			func(v: PackedInt32Array) -> void: v[10] = 1,
			func(v: PackedInt32Array) -> void: v[4] = 1,
			func(v: PackedInt32Array) -> void: v[6] -= 1,
			func(v: PackedInt32Array) -> void: v[11] = 99,
			func(v: PackedInt32Array) -> void: v[11] = SessionRound.ResultReason.TIMEOUT,
			func(v: PackedInt32Array) -> void: v[SessionRound.HEADER_VALUES + 3] = 2,
			func(v: PackedInt32Array) -> void: v[SessionRound.HEADER_VALUES + 3] = 99,
			func(v: PackedInt32Array) -> void: v[SessionRound.HEADER_VALUES + 4] = 2,
			func(v: PackedInt32Array) -> void: v[SessionRound.HEADER_VALUES + 4] = 0,
			func(v: PackedInt32Array) -> void: v[SessionRound.HEADER_VALUES] |= 1 << SessionRound.SCORE_SHIFT,
			func(v: PackedInt32Array) -> void: v[SessionRound.HEADER_VALUES + SessionRound.ENTRY_VALUES] = v[SessionRound.HEADER_VALUES],
		]:
			var malformed := valid.duplicate()
			mutation.call(malformed)
			check(not SessionRound.validate_packet(malformed), "out-of-range, wrong-mode, unsorted, absent-active or inconsistent team packet fails closed")
			check(SessionRound.decoded(malformed).is_empty(), "malformed team packet has no decoded fallback")
		var truncated := valid.duplicate()
		truncated.resize(truncated.size() - 1)
		check(not SessionRound.validate_packet(truncated), "truncated team entry fails closed")
		var padded := valid.duplicate()
		padded.append(0)
		check(not SessionRound.validate_packet(padded), "trailing team packet values fail closed")
		for entity_id: int in ids:
			if round.team_by_entity[entity_id] == 1:
				round.remove_participant(entity_id, world)
		var result := round.capture(world)
		check(SessionRound.validate_packet(result), "whole-team departure result is positive control")
		var forged_active := result.duplicate()
		forged_active[1] = SessionRound.Phase.ACTIVE
		forged_active[8] = 0
		forged_active[11] = SessionRound.ResultReason.NONE
		check(not SessionRound.validate_packet(forged_active), "empty-team active packet cannot bypass forfeiture")


func _test_charter_contract() -> void:
	for mode: int in MODES:
		var charter := "duos" if mode == SessionRound.Mode.DUOS else "trios"
		var count := SessionRound.required_players(mode)
		var definition := SessionCharter.definition(charter)
		check(SessionCharter.validate_definition(definition), "team charter has a strict valid definition")
		equal(SessionCharter.required_players(charter), count, "team charter publishes its exact required count")
		equal(SessionCharter.maximum_players(charter), count, "team charter capacity matches exact team size")
		equal(SessionCharter.round_mode(charter), mode, "team charter routes to its explicit mode")
		check(SessionCharter.player_damage_enabled(charter), "team charter retains actual combat damage")
		check(not SessionCharter.can_reset_practice(charter, 2), "team guest cannot reset the live court")
		var malformed := definition.duplicate(true)
		malformed["required_players"] = count - 1
		check(not SessionCharter.validate_definition(malformed), "charter cannot claim uneven exact count")
		malformed = definition.duplicate(true)
		malformed["round_mode"] = SessionRound.Mode.FREE_FOR_ALL
		check(not SessionCharter.validate_definition(malformed), "team charter cannot silently route to FFA")
		equal(SessionCharter.team_for_champion(charter, 7), 7, "Hearth charter does not invent parity-based teams before roster lock")
