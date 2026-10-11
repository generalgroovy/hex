extends FluxTestSuite


const RoundText = preload("res://src/presentation/session_round_label.gd")


func run() -> int:
	_test_standings_identity_and_purity()
	_test_eight_player_bounds_and_order()
	_test_respawn_uses_authority_ticks()
	_test_result_and_idle_labels()
	_test_knockout_credit()
	_test_team_knockout_credit()
	return finish("session-round-label")


func _state(count: int = 4) -> Dictionary:
	var entries: Array[Dictionary] = []
	for entity_id: int in range(1, count + 1):
		entries.append({"entity_id": entity_id, "score": 0, "respawn_ticks": 0, "protection_ticks": 0})
	return {
		"phase": SessionRound.Phase.ACTIVE,
		"serial": 7,
		"remaining_ticks": 10_800,
		"winner_entity_id": 0,
		"score_limit": 3,
		"entries": entries,
	}


func _test_standings_identity_and_purity() -> void:
	var state := _state()
	var names := {1: "SharedPrefixOne", 2: "SharedPrefixTwo", 3: "SharedPrefixOne", 4: "SharedPrefixTwo"}
	var state_before := state.duplicate(true)
	var names_before := names.duplicate(true)
	var label := RoundText.format(state, names, 3, 120)
	var lines := label.split("\n")
	equal(lines.size(), 3, "four-way standings occupy header and two score rows")
	equal(lines[0], "COURT | 90s | FIRST 3", "header preserves court time and score target")
	equal(lines[1], "P1 SHAR 0 | P2 SHAR 0", "shared-prefix rivals keep stable unique entity labels")
	equal(lines[2], "YOU P3 0 | P4 SHAR 0", "local identity is explicit without hiding the fourth rival")
	equal(label.count("YOU P"), 1, "local participant occurs exactly once in standings")
	for entity_id: int in range(1, 5):
		equal(label.count("P%d " % entity_id), 1, "each four-way participant is present exactly once")
	equal(state, state_before, "formatting cannot mutate authority state or entry order")
	equal(names, names_before, "formatting cannot mutate accepted names")
	var identical_names := {1: "Traveller", 2: "Traveller", 3: "Traveller", 4: "Traveller"}
	var duplicate_label := RoundText.format(state, identical_names, 0, 120)
	for entity_id: int in range(1, 5):
		check(duplicate_label.contains("P%d TRAV 0" % entity_id), "identical accepted names remain distinguishable")
	check(not duplicate_label.contains("YOU"), "observer is not invented as a round participant")


func _test_eight_player_bounds_and_order() -> void:
	var state := _state(8)
	var names := {}
	state.score_limit = 15
	for entry: Dictionary in state.entries:
		entry.score = 15
		names[int(entry.entity_id)] = "WWWWWWWWWWWWWWW"
	(state.entries as Array).reverse()
	var label := RoundText.format(state, names, 8, 120)
	var lines := label.split("\n")
	equal(lines.size(), 5, "generic eight-player round keeps every standing in four bounded rows")
	equal(lines[1], "P1 WWWW 15 | P2 WWWW 15", "equal scores sort by entity independent of packet entry order")
	equal(lines[4], "P7 WWWW 15 | YOU P8 15", "eighth participant is neither truncated nor summarized away")
	for entity_id: int in range(1, 9):
		equal(label.count("P%d " % entity_id), 1, "generic slot %d appears exactly once" % entity_id)
	_assert_text_width(label)
	for entry: Dictionary in state.entries:
		names[int(entry.entity_id)] = "ＭＭＭＭＭＭＭＭＭＭＭＭＭＭＭ"
	_assert_text_width(RoundText.format(state, names, 0, 120))
	state.entries[0].score = 1
	state.entries[1].score = 3
	var ranked := RoundText.format(state, names, 0, 120).split("\n")
	check(ranked[1].begins_with("P1 "), "lower-scoring entries cannot displace the leading tied entities")
	var sparse := _state(2)
	sparse.entries[1].entity_id = 8
	sparse.entries[1].score = 2
	equal(RoundText.format(sparse, {}, 8, 120).split("\n")[1], "YOU P8 2 | P1 0", "sparse participants rank by score while preserving their real entity ids")
	var unsafe_names := {1: "\n\tA|B\u2028C", 2: "\u202eEVIL\u202c", 3: 42, 4: "   "}
	var bounded := RoundText.format(_state(), unsafe_names, 0, 120)
	equal(bounded.split("\n").size(), 3, "player names cannot create extra presentation lines")
	check(bounded.contains("P1 A/BC 0") and bounded.contains("P2 EVIL 0"), "name delimiters and bidi controls cannot forge score rows")
	check(bounded.contains("P3 0 | P4 0"), "missing or nontext names retain stable identifier fallbacks")
	_assert_text_width(bounded)


func _test_respawn_uses_authority_ticks() -> void:
	var state := _state()
	state.entries[2].respawn_ticks = 216
	equal(RoundText.format(state, {}, 3, 120).split("\n")[-1], "YOU P3 RETURN IN 1.8s", "authored 1.8-second respawn reads the local authority entry")
	state.entries[2].respawn_ticks = 13
	equal(RoundText.format(state, {}, 3, 120).split("\n")[-1], "YOU P3 RETURN IN 0.2s", "fractional tenths round up rather than promising an early return")
	state.entries[2].respawn_ticks = 1
	equal(RoundText.format(state, {}, 3, 120).split("\n")[-1], "YOU P3 RETURN IN 0.1s", "last authority tick remains visibly nonzero")
	state.entries[2].respawn_ticks = 61
	equal(RoundText.format(state, {}, 3, 60).split("\n")[-1], "YOU P3 RETURN IN 1.1s", "countdown honors the supplied fixed tick rate")
	check(not RoundText.format(state, {}, 8, 120).contains("RETURN IN"), "late observer never inherits another participant's respawn")
	state.entries[2].respawn_ticks = 0
	state.entries[2].protection_ticks = 144
	check(not RoundText.format(state, {}, 3, 120).contains("RETURN IN"), "authoritative respawn clears the timer even while ward protection remains")
	state.entries[2].respawn_ticks = 1
	equal(RoundText.format(state, {}, 3, 0).split("\n")[-1], "YOU P3 RETURN IN 1.0s", "invalid presentation rate is bounded away from division by zero")


func _test_result_and_idle_labels() -> void:
	equal(RoundText.format({}, {}, 1, 120), "", "missing state does not invent a court")
	var state := _state()
	state.phase = SessionRound.Phase.HEARTH
	equal(RoundText.format(state, {}, 1, 120), "", "Hearth retains the ordinary session label")
	state.phase = SessionRound.Phase.RESULT
	state.remaining_ticks = 720
	state.entries[0].respawn_ticks = 216
	var draw_label := RoundText.format(state, {}, 1, 120)
	equal(draw_label.split("\n")[0], "DRAW | HEARTH IN 6s", "draw and return time are explicit")
	check(not draw_label.contains("RETURN IN"), "sealed result never shows a stale participant respawn")
	equal(draw_label.split("\n").size(), 3, "result retains all four final standings")
	state.winner_entity_id = 4
	var winner_label := RoundText.format(state, {4: "WWWWWWWWWWWWWWW"}, 1, 120)
	equal(winner_label.split("\n")[0], "P4 WWWW WINS | HEARTH IN 6s", "winner keeps unique id and bounded name")
	_assert_text_width(winner_label)
	state.winner_entity_id = 1
	equal(RoundText.format(state, {}, 1, 120).split("\n")[0], "YOU P1 WINS | HEARTH IN 6s", "local victory is clearly identified")
	state.remaining_ticks = 1
	check(RoundText.format(state, {}, 1, 120).begins_with("YOU P1 WINS | HEARTH IN 1s"), "result return seconds also round up")
	state.phase = 99
	equal(RoundText.format(state, {}, 1, 120), "", "unknown phases do not masquerade as an active or result round")


func _test_knockout_credit() -> void:
	var state := _state()
	var names := {1: "Alpha", 2: "Beta", 3: "Gamma", 4: "Delta"}
	var participants: Array = state.entries
	equal(RoundText.knockout_notice(1, 2, participants, names), "P1 ALPH scores against P2 BETA.", "rival participant knockout reports its credited score")
	for owner_id: int in [0, 2, 8]:
		equal(RoundText.knockout_notice(owner_id, 2, participants, names), "P2 BETA was knocked out.", "environment, self and nonparticipant defeats do not invent points")
	equal(RoundText.knockout_notice(1, 8, participants, names), "P8 was knocked out.", "a nonparticipant target cannot create a score notice")
	state.phase = SessionRound.Phase.RESULT
	state.winner_entity_id = 0
	state.entries[0].score = 3
	state.entries[1].score = 3
	equal(RoundText.knockout_notice(1, 2, participants, names), "P1 ALPH scores against P2 BETA.", "first valid trade receipt still scores after the result seals as a draw")
	equal(RoundText.knockout_notice(2, 1, participants, names), "P2 BETA scores against P1 ALPH.", "reverse trade receipt does not depend on winner identity")
	equal(RoundText.knockout_notice(1, 1, participants, names), "P1 ALPH was knocked out.", "positive final score is not evidence that a self knockout earned a point")
	var before := participants.duplicate(true)
	RoundText.knockout_notice(4, 3, participants, names)
	equal(participants, before, "feedback formatting cannot mutate round participants")


func _assert_text_width(label: String) -> void:
	for line: String in label.split("\n"):
		check(ThemeDB.fallback_font.get_string_size(line.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x <= 228.0, "complete round line fits the existing 228px font11 text lane: " + line)


func _test_team_knockout_credit() -> void:
	var state := _state()
	state.mode = SessionRound.Mode.DUOS
	state.team_scores = {1: 2, 2: 1}
	state.winner_team_id = 0
	for index: int in (state.entries as Array).size():
		state.entries[index].team_id = 1 + index % 2
		state.entries[index].present = true
	var names := {1: "Alpha", 2: "Beta", 3: "Gamma", 4: "Delta"}
	var participants: Array = state.entries
	equal(RoundText.knockout_notice(1, 2, participants, names, state), "AMBER +1: P1 ALPH defeats P2 BETA.", "hostile team knockout names the credited team")
	equal(RoundText.knockout_notice(2, 1, participants, names, state, {"scored": true, "credited_team_id": 2}), "TEAL +1: P2 BETA defeats P1 ALPH.", "explicit opposite-team event credit is preserved")
	for owner_id: int in [0, 1, 3, 8]:
		equal(RoundText.knockout_notice(owner_id, 1, participants, names, state), "P1 ALPH was knocked out.", "environment, self, ally and outsider cannot claim a team point")
	equal(RoundText.knockout_notice(3, 1, participants, names), "P1 ALPH was knocked out.", "locked ally fields prevent fabricated credit even before caller supplies mode")
	equal(RoundText.knockout_notice(1, 2, participants, names, state, {"scored": false, "credited_team_id": 0}), "P2 BETA was knocked out.", "explicit uncredited event overrides a hostile roster inference")
	equal(RoundText.knockout_notice(1, 2, participants, names, state, {"scored": true, "credited_team_id": 2}), "P2 BETA was knocked out.", "mismatched team credit cannot masquerade as another team's point")
	state.phase = SessionRound.Phase.RESULT
	state.team_scores = {1: 3, 2: 3}
	equal(RoundText.knockout_notice(1, 2, participants, names, state), "AMBER +1: P1 ALPH defeats P2 BETA.", "sealed team draw still reports its valid final hostile knockout")
	equal(RoundText.knockout_notice(3, 1, participants, names, state, {"scored": true, "credited_team_id": 1}), "P1 ALPH was knocked out.", "even a contradictory event cannot label allied damage as a point")
	var before := state.duplicate(true)
	RoundText.knockout_notice(4, 3, participants, names, state)
	equal(state, before, "team knockout presentation leaves the decoded authority untouched")
