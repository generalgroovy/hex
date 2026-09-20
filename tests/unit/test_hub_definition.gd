extends FluxTestSuite


const HUB_PATH: String = "res://content/maps/sanctum_hub_v1.json"


func run() -> int:
	_test_repository_definition()
	_test_fast_travel_policy()
	_test_invalid_definition_fails_closed()
	return finish("hub-definition")


func _test_repository_definition() -> void:
	var hub := HubDefinition.new()
	check(hub.load_from_file(HUB_PATH), "repository hub definition validates: %s" % hub.last_error)
	equal(hub.data.get("id"), "sanctum-hub-v1", "hub id is stable")
	check(hub.districts_by_id.size() >= 8, "hub has at least eight combined districts")
	check(hub.travel_nodes_by_id.size() >= 8, "hub exposes a distributed fast-travel network")
	check(hub.districts_by_id.has("movement-conservatory"), "movement district exists")
	check(hub.districts_by_id.has("alchemical-proving-grounds"), "chemistry and combat district exists")
	check(hub.districts_by_id.has("foundry-deep"), "undercroft district exists")
	for district_id: String in hub.districts_by_id:
		var district: Dictionary = hub.districts_by_id[district_id]
		check((district.get("functions", []) as Array).size() >= 2, "%s combines related functions" % district_id)
		check((district.get("entrances", []) as Array).size() >= 2, "%s has multiple entrances" % district_id)
		check(not (district.get("movement_routes", []) as Array).is_empty(), "%s has a deep-movement route" % district_id)


func _test_fast_travel_policy() -> void:
	var hub := HubDefinition.new()
	check(hub.load_from_file(HUB_PATH), "hub loads for travel tests")
	var unlocked := {"nexus-fountain": true, "conservatory-spire": true}
	check(hub.can_fast_travel("nexus-fountain", "conservatory-spire", unlocked), "attuned destination is available from a safe state")
	check(not hub.can_fast_travel("nexus-fountain", "wayfarer-gate", unlocked), "unattuned destination is refused")
	check(not hub.can_fast_travel("nexus-fountain", "missing-node", unlocked), "unknown destination is refused")
	check(not hub.can_fast_travel("nexus-fountain", "nexus-fountain", unlocked), "same-node travel is refused")
	check(not hub.can_fast_travel("nexus-fountain", "conservatory-spire", unlocked, "", false), "unclear destination is refused")
	for blocked_state: String in ["combat", "timed_trial", "transition", "material_reset"]:
		check(not hub.can_fast_travel("nexus-fountain", "conservatory-spire", unlocked, blocked_state), "travel is refused during %s" % blocked_state)


func _test_invalid_definition_fails_closed() -> void:
	var hub := HubDefinition.new()
	hub.data = {
		"schema_version": 99,
		"id": "invalid",
	}
	check(not hub.validate(), "unsupported schema fails closed")
	check(hub.last_error.contains("schema"), "schema failure is diagnosable")
