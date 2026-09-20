extends FluxTestSuite


func run() -> int:
	_test_catalog()
	_test_rules()
	return finish("session-charter")


func _test_catalog() -> void:
	equal(SessionCharter.PROFILE_ORDER.size(), 3, "three concise Farflow charters are available")
	equal(SessionCharter.DEFAULT_ID, "open_commons", "social Commons is the safe default")
	check(SessionCharter.catalog_hash().length() == 64, "charter catalog has a compatibility hash")
	var distinct_hashes: Dictionary[String, bool] = {}
	for profile_id: String in SessionCharter.PROFILE_ORDER:
		var profile := SessionCharter.definition(profile_id)
		check(SessionCharter.validate_definition(profile), "charter definition validates: %s" % profile_id)
		var profile_hash := SessionCharter.profile_hash(profile_id)
		check(SessionCharter.validate_assignment(profile_id, profile_hash), "charter assignment validates its exact hash: %s" % profile_id)
		distinct_hashes[profile_hash] = true
	equal(distinct_hashes.size(), SessionCharter.PROFILE_ORDER.size(), "each charter has a distinct rule identity")
	check(not SessionCharter.validate_assignment("open_commons", SessionCharter.profile_hash("duel_knot")), "cross-charter hash substitution fails closed")
	check(SessionCharter.definition("unknown").is_empty(), "unknown charter has no permissive fallback definition")
	equal(SessionCharter.next_id("open_commons"), "sparring_circle", "charter order advances deterministically")
	equal(SessionCharter.next_id("duel_knot"), "open_commons", "charter order wraps to the safe default")


func _test_rules() -> void:
	equal(SessionCharter.maximum_players("open_commons"), 8, "Commons supports the public eight-player cap")
	equal(SessionCharter.maximum_players("sparring_circle"), 4, "Sparring Circle is intentionally smaller")
	equal(SessionCharter.maximum_players("duel_knot"), 2, "Duel Knot admits one pair")
	equal(SessionCharter.team_for_champion("open_commons", 2), 1, "Commons travellers share a no-harm team")
	equal(SessionCharter.team_for_champion("sparring_circle", 2), 2, "Sparring travellers retain individual combat teams")
	check(SessionCharter.team_for_champion("sparring_circle", 2) != 900, "Sparring guest cannot share the practice actor team")
	check(SessionCharter.can_reset_practice("open_commons", 2), "Commons guest may ring the shared practice bell")
	check(SessionCharter.can_reset_practice("sparring_circle", 4), "Sparring guest may ring the shared practice bell")
	check(SessionCharter.can_reset_practice("duel_knot", 1), "Duel host may restore the court")
	check(not SessionCharter.can_reset_practice("duel_knot", 2), "Duel guest cannot unilaterally reset the court")
