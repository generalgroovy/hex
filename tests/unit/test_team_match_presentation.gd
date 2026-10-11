extends FluxTestSuite


const Teams = preload("res://src/presentation/team_match_presentation.gd")
const RoundText = preload("res://src/presentation/session_round_label.gd")


func run() -> int:
	_test_locked_team_standings()
	_test_team_results_and_departure()
	_test_respawn_and_observers()
	_test_actor_markers()
	_test_marker_lookup()
	_test_hearth_disclosure()
	_test_hud_bounds()
	return finish("team-match-presentation")


func _state(mode: int = SessionRound.Mode.TRIOS) -> Dictionary:
	var ids: Array[int] = [2, 4, 6, 8]
	if mode == SessionRound.Mode.TRIOS:
		ids.assign([2, 3, 4, 5, 6, 8])
	var entries: Array[Dictionary] = []
	for index: int in ids.size():
		entries.append({"entity_id": ids[index], "score": 0, "team_id": 1 + index % 2, "present": true, "respawn_ticks": 0, "protection_ticks": 0})
	return {"mode": mode, "phase": SessionRound.Phase.ACTIVE, "remaining_ticks": 10_800, "score_limit": 3,
		"winner_entity_id": 0, "winner_team_id": 0, "team_scores": {1: 2, 2: 1}, "entries": entries}


func _test_locked_team_standings() -> void:
	for mode: int in [SessionRound.Mode.DUOS, SessionRound.Mode.TRIOS]:
		var state := _state(mode)
		var before := state.duplicate(true)
		var label := Teams.format(state, 6, 120)
		var lines := label.split("\n")
		equal(lines.size(), 4, "both team sizes keep header, totals and two full roster rows")
		equal(lines[0], "%s | 90s | FIRST 3" % ["2v2" if mode == SessionRound.Mode.DUOS else "3v3"], "actual team mode is explicit")
		equal(lines[1], "AMBER 2 | TEAL 1", "scores come from explicit earned team totals, not current individual sums")
		equal(lines[2], "AMBER: P2 P4 YOU P6" if mode == SessionRound.Mode.TRIOS else "AMBER: P2 YOU P6", "Amber uses locked sparse roster assignments, not entity parity")
		equal(lines[3], "TEAL: P3 P5 P8" if mode == SessionRound.Mode.TRIOS else "TEAL: P4 P8", "Teal keeps every locked participant visible")
		for entry: Dictionary in state.entries:
			equal(label.count("P%d" % int(entry.entity_id)), 1, "each real roster id appears exactly once in standings")
		equal(label.count("YOU"), 1, "local champion is named once in the correct team")
		equal(state, before, "team formatting cannot mutate authority entries or totals")
		(state.entries as Array).reverse()
		equal(Teams.format(state, 6, 120), label, "packet order cannot move a player between roster positions")
		equal(RoundText.format(state, {2: "Same", 3: "Same", 4: "Same", 5: "Same", 6: "Same", 8: "Same"}, 6, 120), label, "normal HUD formatter uses unambiguous ids even with duplicate names")
	equal(Teams.format({}, 1, 120), "", "missing state cannot invent teams")
	var legacy := _state()
	legacy.mode = SessionRound.Mode.FREE_FOR_ALL
	equal(Teams.format(legacy, 1, 120), "", "FFA never enters team rendering")


func _test_team_results_and_departure() -> void:
	var state := _state()
	state.entries[0].present = false
	state.entries[0].score = 2
	state.entries[0].respawn_ticks = 216
	var label := Teams.format(state, 2, 120)
	check(label.contains("AMBER 2 | TEAL 1"), "departed scorer cannot erase earned team points")
	check(label.contains("AMBER: P2 LEFT P4 P6"), "departed frozen roster id remains explicit")
	check(not label.contains("YOU"), "a new observer reusing a departed id cannot claim the historical team's identity")
	check(not label.contains("RETURN IN"), "permanent departure cannot promise a respawn")
	state.phase = SessionRound.Phase.RESULT
	state.remaining_ticks = 720
	state.winner_team_id = 1
	equal(Teams.format(state, 6, 120).split("\n")[0], "AMBER WINS | HEARTH IN 6s", "team winner is not confused with the zero individual winner id")
	state.winner_team_id = 2
	equal(Teams.format(state, 6, 120).split("\n")[0], "TEAL WINS | HEARTH IN 6s", "opposing team victory is explicit")
	state.winner_team_id = 0
	state.team_scores = {1: 3, 2: 3}
	label = Teams.format(state, 6, 120)
	equal(label.split("\n")[0], "DRAW | HEARTH IN 6s", "simultaneous threshold draw does not invent a team winner")
	equal(label.split("\n")[1], "AMBER 3 | TEAL 3", "both teams' sealed final totals remain visible")
	check(not label.contains("RETURN IN"), "result suppresses all stale respawn clocks")
	state.remaining_ticks = 1
	check(Teams.format(state, 6, 120).begins_with("DRAW | HEARTH IN 1s"), "team result seconds round up")
	state.phase = SessionRound.Phase.HEARTH
	equal(Teams.format(state, 6, 120), "", "old result roster is not reused as Hearth assignment")


func _test_respawn_and_observers() -> void:
	var state := _state()
	for fixture: Vector3i in [Vector3i(216, 120, 18), Vector3i(13, 120, 2), Vector3i(1, 120, 1), Vector3i(61, 60, 11), Vector3i(1, 0, 10)]:
		state.entries[4].respawn_ticks = fixture.x
		@warning_ignore("integer_division")
		var whole: int = fixture.z / 10
		equal(Teams.format(state, 6, fixture.y).split("\n")[-1], "YOU P6 RETURN IN %d.%ds" % [whole, fixture.z % 10], "team respawn uses authoritative ticks rounded up at supplied rate")
	check(not Teams.format(state, 1, 120).contains("YOU"), "late observer receives neither participant identity nor respawn")
	state.entries[4].respawn_ticks = 0
	state.entries[4].protection_ticks = 144
	check(not Teams.format(state, 6, 120).contains("RETURN IN"), "post-respawn protection does not prolong the return clock")


func _test_actor_markers() -> void:
	var state := _state()
	var before := state.duplicate(true)
	equal(Teams.actor_marker(state, 6, 6).label, "YOU P6 AMBER", "local marker combines self, unique id and team name")
	equal(Teams.actor_marker(state, 2, 6).label, "ALLY P2 AMBER", "an ally is recognizable without reading color")
	equal(Teams.actor_marker(state, 8, 6).label, "ENEMY P8 TEAL", "a hostile team is recognizable without reading color")
	equal(Teams.actor_marker(state, 8, 1).label, "TEAL P8", "observer sees neutral team identity, not an invented enemy")
	equal(Teams.actor_marker(state, 1, 6), {}, "late observer or practice actor cannot acquire a roster marker")
	equal(Teams.team_for_entity(state, 4), 1, "lookup reads locked entry team rather than numeric parity")
	equal(Teams.team_for_entity(state, 8), 2, "two even ids can belong to opposing teams")
	equal(Teams.team_for_entity(state, 7), 0, "nonparticipant has no round-owned team")
	equal(state, before, "marker reads never alter authority or presentation input")
	state.entries[0].present = false
	equal(Teams.actor_marker(state, 2, 6), {}, "permanently departed actor gets no live marker")
	equal(Teams.actor_marker(state, 8, 2).relation, "", "departed observer does not claim an active ally/enemy perspective")
	state.phase = SessionRound.Phase.RESULT
	equal(Teams.actor_marker(state, 4, 6).relation, "ALLY", "result retains the locked teams until return")
	state.phase = SessionRound.Phase.HEARTH
	equal(Teams.actor_marker(state, 4, 6), {}, "Hearth has no fake locked combat marker")


func _test_marker_lookup() -> void:
	for mode: int in [SessionRound.Mode.DUOS, SessionRound.Mode.TRIOS]:
		var state := _state(mode)
		var expected_teams := {2: 1, 4: 2, 6: 1, 8: 2}
		if mode == SessionRound.Mode.TRIOS:
			expected_teams = {2: 1, 3: 2, 4: 1, 5: 2, 6: 1, 8: 2}
		for phase: int in [SessionRound.Phase.ACTIVE, SessionRound.Phase.RESULT]:
			state.phase = phase
			for local_id: int in [0, 1, 2, 3, 4, 5, 6, 8]:
				var before := state.duplicate(true)
				var lookup := Teams.marker_lookup(state, local_id)
				equal(lookup.size(), expected_teams.size(), "one lookup includes every present locked actor for both team sizes and phases")
				for entity_id: int in range(0, 10):
					var actual: Dictionary = lookup.get(entity_id, {})
					equal(actual, Teams.actor_marker(state, entity_id, local_id), "batched and single-actor paths return exactly equivalent marker dictionaries")
					if not expected_teams.has(entity_id):
						check(actual.is_empty(), "lookup never invents an outsider marker")
						continue
					var team_id: int = expected_teams[entity_id]
					var local_team := int(expected_teams.get(local_id, 0))
					var relation := "YOU" if entity_id == local_id else "" if local_team == 0 else "ALLY" if team_id == local_team else "ENEMY"
					var name := "AMBER" if team_id == 1 else "TEAL"
					var label := "%s P%d" % [name, entity_id] if relation.is_empty() else "%s P%d %s" % [relation, entity_id, name]
					equal(actual, {"team_id": team_id, "team_name": name, "relation": relation, "label": label}, "batch markers also match the independent explicit sparse-roster identity contract")
				equal(state, before, "batch and single-actor reads leave source state unchanged")
		var ordered_lookup := Teams.marker_lookup(state, 6)
		(state.entries as Array).reverse()
		equal(Teams.marker_lookup(state, 6), ordered_lookup, "input order cannot alter a locked actor's identity")
		var before_mutation := state.duplicate(true)
		ordered_lookup[2]["label"] = "Changed presentation copy"
		equal(state, before_mutation, "returned marker mutation cannot reach source entries")
		check(Teams.marker_lookup(state, 6)[2].label != "Changed presentation copy", "successive lookups do not share mutable marker dictionaries")
		for entry: Dictionary in state.entries:
			if int(entry.entity_id) == 2:
				entry.present = false
		var reused := Teams.marker_lookup(state, 2)
		equal(reused.size(), expected_teams.size() - 1, "reused departed identity is absent from the live marker map")
		check(not reused.has(2), "historical local id cannot acquire a YOU marker")
		for entity_id: int in reused:
			equal(reused[entity_id].relation, "", "reused observer sees no invented ally or enemy relationship")
			equal(reused[entity_id], Teams.actor_marker(state, entity_id, 2), "departure semantics remain exactly equivalent in both APIs")
		state.phase = SessionRound.Phase.HEARTH
		check(Teams.marker_lookup(state, 6).is_empty(), "Hearth never exposes a locked combat marker lookup")
		state.phase = SessionRound.Phase.ACTIVE
		state.mode = SessionRound.Mode.FREE_FOR_ALL
		check(Teams.marker_lookup(state, 6).is_empty(), "FFA cannot fabricate a team marker lookup")
	check(Teams.marker_lookup({}, 1).is_empty(), "missing round returns an empty lookup")


func _test_hearth_disclosure() -> void:
	var ids: Array = [8, 2, 6, 4]
	var before := ids.duplicate()
	var readiness := {2: true, 4: false, 6: true, 8: false}
	var readiness_before := readiness.duplicate()
	var label := Teams.hearth_label("duos", ids, 6, 120, 0, readiness)
	var lines := label.split("\n")
	equal(lines.size(), 5, "team Hearth reserves the sixth rendered row for root's binding-aware action")
	equal(lines[0], "2v2 PREVIEW | 4/4 REQUIRED", "exact-four requirement and provisional teams are explicit before countdown")
	equal(lines[1], "AMBER: P2+ YOU P6+", "Hearth preview shows each real sorted teammate's current ready state")
	equal(lines[2], "TEAL: P4- P8-", "Hearth previews the complete other team and its waiting members")
	equal(lines[3], "+ READY | - WAITING", "per-person readiness symbols have a literal non-color legend")
	equal(ids, before, "preview sorting cannot reorder actual Hearth roster")
	equal(readiness, readiness_before, "formatting cannot toggle any participant's actual readiness")
	readiness[4] = true
	check(Teams.hearth_label("duos", ids, 6, 120, 0, readiness).contains("TEAL: P4+ P8-"), "a real readiness transition updates only that participant's marker")
	check(Teams.hearth_label("duos", ids, 6, 120, 0, {2: 1}).contains("P2?"), "nonboolean readiness cannot falsely claim a ready participant")
	label = Teams.hearth_label("trios", [8, 6, 5, 4, 3, 2], 6, 120, 481, {2: true, 3: true, 4: true, 5: true, 6: true, 8: true})
	equal(label.split("\n")[0], "3v3 PREVIEW | IN 4.1s", "countdown rounds up and keeps provisional status until begin locks teams")
	check(label.contains("AMBER: P2+ P4+ YOU P6+") and label.contains("TEAL: P3+ P5+ P8+"), "all six readiness states remain disclosed during countdown")
	label = Teams.hearth_label("trios", [2, 3, 4, 5, 6], 6, 120, 481)
	check(label.begins_with("3v3 PREVIEW | 5/6 REQUIRED"), "incomplete roster cannot promise a pending match")
	check(not label.contains(" | IN "), "stale countdown cannot hide exact-count shortfall")
	check(label.contains("P2?") and label.contains("? UNKNOWN"), "missing readiness is explicitly unknown rather than invented waiting or ready")
	label = Teams.hearth_label("duos", [1, 2, 3, 4, 5], 1, 120, 481)
	check(label.contains("EXACTLY 4 PLAYERS NEEDED") and not label.contains("AMBER:"), "overfull roster is not misrepresented as a valid 2v2 split")
	equal(Teams.hearth_label("duos", [2, 2, 4, 6], 6, 120), "2v2 | EXACTLY 4 PLAYERS", "invalid duplicate input does not manufacture a roster")
	equal(Teams.hearth_label("sparring_circle", [1, 2, 3, 4], 1, 120), "", "FFA preserves its existing Hearth UI")
	var policy := " ".join(Teams.damage_policy_lines())
	for required_word: String in ["enemy-team", "Ally and self", "no points", "Fire", "Steam", "Conflagration", "allies and you"]:
		check(policy.contains(required_word), "team damage help discloses actual policy: " + required_word)
	check(label.contains("SHARED HAZARDS CAN HURT ALL"), "compact disclosure retains its harm warning before players begin")
	check(Teams.damage_policy_lines().size() <= 5, "full damage help leaves room for a sixth charter/action row")


func _test_hud_bounds() -> void:
	var labels: Array[String] = []
	for mode: int in [SessionRound.Mode.DUOS, SessionRound.Mode.TRIOS]:
		var state := _state(mode)
		state.remaining_ticks = 72_000
		state.score_limit = 15
		state.team_scores = {1: 15, 2: 15}
		state.entries[0].respawn_ticks = 1_200
		labels.append(Teams.format(state, 2, 120))
		for entry: Dictionary in state.entries:
			entry.present = false
		labels.append(Teams.format(state, 8, 120))
		state.phase = SessionRound.Phase.RESULT
		for winner: int in [0, 1, 2]:
			state.winner_team_id = winner
			labels.append(Teams.format(state, 8, 120))
	for hearth_label: String in [
		Teams.hearth_label("duos", [2, 4, 6, 8], 6, 120, 481, {2: true, 4: false, 6: true, 8: false}),
		Teams.hearth_label("trios", [2, 3, 4, 5, 6, 8], 6, 120, 481, {2: true, 3: false, 4: true, 5: false, 6: true, 8: false}),
		Teams.hearth_label("trios", [2, 3, 4, 5, 6, 8], 6, 120),
		Teams.hearth_label("trios", [], 6, 120),
	]:
		check(hearth_label.split("\n").size() <= 5, "all Hearth variants leave the binding/action slot available")
		labels.append(hearth_label + "\nHOST INTERACT STARTS")
	for policy_line: String in Teams.damage_policy_lines():
		check(ThemeDB.fallback_font.get_string_size(policy_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x <= 268.0, "full damage-help line fits the existing expanded station text lane")
	for label: String in labels:
		var lines := label.split("\n")
		check(lines.size() <= 6, "all team information fits the compact HUD row budget")
		for line: String in lines:
			check(ThemeDB.fallback_font.get_string_size(line.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x <= 228.0, "team line fits the existing 228px font11 lane: " + line)
		for viewport: Vector2 in [Vector2(960, 540), Vector2(1280, 720)]:
			var panel := CompactCombatHud.session_panel(viewport, 16, 248, 34, lines.size())
			check(Rect2(Vector2.ZERO, viewport).encloses(panel), "full team scoreboard stays inside each usual viewport")
			check(not panel.intersects(Rect2(16, 16, 312, 34)), "team scoreboard never collides with the character header")
			check(panel.end.y < viewport.y - 134, "team scoreboard leaves the bottom combat controls clear")
