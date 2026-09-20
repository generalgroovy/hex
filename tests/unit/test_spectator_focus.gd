extends FluxTestSuite


func run() -> int:
	_test_focus_lifecycle()
	_test_focus_validation()
	return finish("spectator-focus")


func _test_focus_lifecycle() -> void:
	var focus := SpectatorFocus.new()
	var active_round := {
		"phase": SessionRound.Phase.ACTIVE,
		"entries": [{"entity_id": 2}, {"entity_id": 1}],
	}
	check(focus.reconcile(active_round, 3, [1, 2, 3]), "late joiner enters spectator focus during an active Court")
	equal(focus.participant_entity_ids, [1, 2], "focus roster is stable and excludes the waiting local actor")
	equal(focus.focus_entity_id, 1, "first replicated participant is the deterministic default focus")
	equal(focus.cycle_next(), 2, "spectator cycles to the next participant")
	equal(focus.cycle_next(), 1, "spectator focus wraps")
	active_round["entries"] = [{"entity_id": 2}]
	check(focus.reconcile(active_round, 3, [2, 3]), "spectating survives a participant departure")
	equal(focus.focus_entity_id, 2, "departed focus reconciles to the remaining participant")
	active_round["phase"] = SessionRound.Phase.RESULT
	check(focus.reconcile(active_round, 3, [2, 3]), "spectator follows the public result phase")
	check(not focus.reconcile({"phase": SessionRound.Phase.HEARTH, "entries": []}, 3, [1, 2, 3]), "Hearth handoff ends spectating")
	equal(focus.focus_entity_id, 0, "Hearth handoff restores local-camera ownership")


func _test_focus_validation() -> void:
	var focus := SpectatorFocus.new()
	var active_round := {
		"phase": SessionRound.Phase.ACTIVE,
		"entries": [{"entity_id": 7}, {"entity_id": 1}, {"entity_id": 1}, "bad"],
	}
	check(focus.reconcile(active_round, 3, [1, 3]), "focus uses only the intersection of round roster and replicated actors")
	equal(focus.participant_entity_ids, [1], "unavailable, duplicate and malformed entries add no camera targets")
	check(not focus.reconcile(active_round, 1, [1, 3]), "a participant never becomes a spectator")
	equal(focus.cycle_next(), 0, "inactive spectator cycling fails closed")
