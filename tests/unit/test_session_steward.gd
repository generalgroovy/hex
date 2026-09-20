extends FluxTestSuite


func run() -> int:
	_test_guest_selection()
	_test_explicit_confirmation()
	return finish("session-steward")


func _test_guest_selection() -> void:
	var steward := SessionSteward.new()
	var roster: Array[Dictionary] = [
		{"peer_id": 31, "entity_id": 4, "name": "Moss"},
		{"peer_id": 19, "entity_id": 2, "name": "River"},
		{"peer_id": 0, "entity_id": 3, "name": "Returning"},
		{"peer_id": 44, "entity_id": 4, "name": "Duplicate"},
	]
	equal(steward.cycle_guest(roster), 2, "Ledger selects the lowest connected guest first")
	equal(steward.cycle_guest(roster), 4, "Ledger cycles guests in stable entity order")
	equal(steward.cycle_guest(roster), 2, "Ledger wraps without selecting host or returning reservations")
	check(steward.reconcile_roster(roster), "selected connected guest remains valid")
	check(not steward.reconcile_roster([{"peer_id": 31, "entity_id": 4, "name": "Moss"}]), "removed selection is cleared")
	equal(steward.selected_entity_id, 0, "stale guest cannot remain an administrative target")
	equal(steward.cycle_guest([]), 0, "empty Ledger fails closed")


func _test_explicit_confirmation() -> void:
	var steward := SessionSteward.new()
	steward.cycle_guest([{"peer_id": 19, "entity_id": 2, "name": "River"}])
	equal(steward.request_release(100, 360), SessionSteward.Decision.ARMED, "first Parting Bell press only arms release")
	check(steward.is_armed(SessionSteward.Action.RELEASE_GUEST, 2, 101), "release confirmation names the selected guest")
	equal(steward.request_close(120, 360), SessionSteward.Decision.ARMED, "different action replaces rather than confirms release")
	check(not steward.is_armed(SessionSteward.Action.RELEASE_GUEST, 2), "close cannot accidentally confirm guest release")
	equal(steward.request_close(460, 360), SessionSteward.Decision.CONFIRMED, "second matching press within the inclusive window confirms close")
	check(not steward.is_armed(SessionSteward.Action.CLOSE_COMPANY), "confirmation is consumed exactly once")
	equal(steward.request_release(500, 360), SessionSteward.Decision.ARMED, "release can be armed again")
	check(steward.expire(861), "confirmation expires after its bounded window")
	equal(steward.request_release(862, 360), SessionSteward.Decision.ARMED, "expired second press rearms instead of confirming")
	steward.cycle_guest([{"peer_id": 20, "entity_id": 3, "name": "Reed"}])
	check(not steward.is_armed(SessionSteward.Action.RELEASE_GUEST, 2), "changing selection disarms the prior target")
	equal(steward.request_release(-1, 360), SessionSteward.Decision.REFUSED, "invalid tick fails closed")
	equal(steward.request_release(10, 0), SessionSteward.Decision.REFUSED, "zero confirmation window fails closed")
