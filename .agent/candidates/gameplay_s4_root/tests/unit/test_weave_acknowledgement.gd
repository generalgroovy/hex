extends FluxTestSuite


const BootstrapScript: Script = preload("res://src/app/bootstrap.gd")


# No-auto fixture: exercise the inherited acknowledgement state machine without
# running Bootstrap._ready(), opening sockets, or touching the player profile.
class AckHarness:
	extends "res://src/app/bootstrap.gd"
	var save_calls: int = 0
	var saved_mode: String = ""

	func _ready() -> void:
		pass

	func _process(_delta: float) -> void:
		pass

	func _draw() -> void:
		pass

	func _save_confirmed_weave(_state: PlayerState, mode: String) -> void:
		save_calls += 1
		saved_mode = mode


func run() -> int:
	var node := _fixture()
	_test_matching_state_requires_ack(node)
	_test_wrong_ack_and_refusal_are_ignored(node)
	_test_correct_ack_completes_matching_state(node)
	_test_ack_waits_for_authoritative_state(node)
	_test_deadline_clears_without_save(node)
	_test_acknowledgement_codec()
	node.free()
	return finish("weave-acknowledgement")


func _fixture() -> AckHarness:
	var node := AckHarness.new()
	node.ability_catalog = AbilityCatalog.new()
	check(node.ability_catalog.load_from_file(BootstrapScript.ABILITY_CATALOG_PATH), "ack fixture loads the canonical ability catalog")
	node.champion_catalog = ChampionCatalog.new()
	check(node.champion_catalog.load_from_file(BootstrapScript.CHAMPION_CATALOG_PATH, node.ability_catalog), "ack fixture loads the canonical character catalog")
	node.world = SimWorld.new(120, 91, CollisionWorld.new(3_072_000, 1_728_000))
	check(node.champion_catalog.apply_to_player(node.world.player(), node.champion_catalog.default_champion_id), "ack fixture applies a canonical twelve-slot character")
	node.session_transport = SessionTransport.new()
	node.session_transport.local_entity_id = SessionTransport.SERVER_PEER_ID
	node.spell_loom_editor = SpellLoomEditor.new()
	node.preferences_persistence_allowed = false
	node.preference_overrides_are_transient = true
	return node


func _arm(
	node: AckHarness,
	requested: PackedInt32Array,
	sequence: int,
	acknowledged: bool = false,
	deadline_tick: int = -1,
	save: bool = true,
) -> void:
	node.save_calls = 0
	node.saved_mode = ""
	node.spell_loom_editor.starter_preview = {"notice": "fixture preview"}
	node.pending_weave_request = {
		"champion": node.world.player().champion_wire_id,
		"wires": requested.duplicate(),
		"mode": CharacterWeaveLibrary.MODE_STARTER,
		"save": save,
		"sequence": sequence,
		"acknowledged": acknowledged,
		"deadline_tick": node.world.tick + 600 if deadline_tick < 0 else deadline_tick,
	}


func _confirmation(node: AckHarness, sequence: int, champion_wire_id: int = -1) -> Dictionary:
	return {
		"type": "station_confirmed",
		"entity_id": SessionTransport.SERVER_PEER_ID,
		"action": SessionTransport.REQUEST_WEAVE_APPLY,
		"sequence": sequence,
		"champion_wire_id": node.world.player().champion_wire_id if champion_wire_id < 0 else champion_wire_id,
	}


func _refusal(sequence: int) -> Dictionary:
	return {
		"type": "request_refused",
		"entity_id": SessionTransport.SERVER_PEER_ID,
		"action": SessionTransport.REQUEST_WEAVE_APPLY,
		"sequence": sequence,
		"reason": SessionRequestPolicy.REFUSED_UNAVAILABLE,
	}


func _test_matching_state_requires_ack(node: AckHarness) -> void:
	var current := node.world.player().spell_wire_ids.duplicate()
	_arm(node, current, 41)
	node._complete_pending_weave()
	check(not node.pending_weave_request.is_empty(), "a no-op weave matching current authority remains pending without an acknowledgement")
	check(not bool(node.pending_weave_request.get("acknowledged", false)), "matching state cannot invent its own acknowledgement")
	check(node.spell_loom_editor.starter_preview_active(), "the preview remains quarantined while authority has not acknowledged")
	equal(node.save_calls, 0, "matching state alone cannot save a local weave")


func _test_wrong_ack_and_refusal_are_ignored(node: AckHarness) -> void:
	var current := node.world.player().spell_wire_ids.duplicate()
	_arm(node, current, 52)
	node.station_notice = "Still waiting for request 52."
	node._ingest_session_feedback([_confirmation(node, 51)])
	check(not node.pending_weave_request.is_empty(), "a confirmation for another request cannot clear the current request")
	check(not bool(node.pending_weave_request.get("acknowledged", false)), "a wrong-sequence confirmation cannot acknowledge the current request")
	equal(node.station_notice, "Still waiting for request 52.", "a wrong-sequence confirmation cannot report success for the current request")
	node._ingest_session_feedback([_confirmation(node, 52, node.world.player().champion_wire_id + 1)])
	check(not bool(node.pending_weave_request.get("acknowledged", false)), "a confirmation for another character cannot acknowledge the current request")
	equal(node.station_notice, "Still waiting for request 52.", "a wrong-character confirmation cannot report success for the current request")
	node._ingest_session_feedback([_refusal(51)])
	check(not node.pending_weave_request.is_empty(), "a refusal for another request cannot clear the current request")
	equal(node.station_notice, "Still waiting for request 52.", "a wrong-sequence refusal cannot report failure for the current request")
	equal(node.save_calls, 0, "unmatched feedback cannot save")
	node._ingest_session_feedback([_refusal(52)])
	check(node.pending_weave_request.is_empty(), "the matching refusal clears the exact pending request")
	check(node.spell_loom_editor.starter_preview_active(), "a refused starter request remains available to review or cancel")
	equal(node.save_calls, 0, "a matching refusal never saves")


func _test_correct_ack_completes_matching_state(node: AckHarness) -> void:
	var current := node.world.player().spell_wire_ids.duplicate()
	_arm(node, current, 63)
	node._ingest_session_feedback([_confirmation(node, 63)])
	check(node.pending_weave_request.is_empty(), "the exact acknowledgement completes an already matching authoritative weave")
	check(not node.spell_loom_editor.starter_preview_active(), "successful authority acknowledgement closes the starter preview")
	equal(node.save_calls, 1, "one confirmed matching weave invokes one local save")
	equal(node.saved_mode, CharacterWeaveLibrary.MODE_STARTER, "the acknowledged request retains its requested save mode")


func _test_ack_waits_for_authoritative_state(node: AckHarness) -> void:
	var requested := node.world.player().spell_wire_ids.duplicate()
	requested.reverse()
	_arm(node, requested, 74)
	node._ingest_session_feedback([_confirmation(node, 74)])
	check(not node.pending_weave_request.is_empty(), "an exact acknowledgement waits when the authoritative weave has not arrived")
	check(bool(node.pending_weave_request.get("acknowledged", false)), "the matching acknowledgement is retained while state catches up")
	equal(node.save_calls, 0, "acknowledgement without matching state cannot save")
	check(CharacterWeavePolicy.apply(node.world.player(), requested), "fixture applies the later authoritative twelve-slot state")
	node._complete_pending_weave()
	check(node.pending_weave_request.is_empty(), "the acknowledged request completes after matching authority arrives")
	equal(node.save_calls, 1, "the delayed matching authority saves exactly once")


func _test_deadline_clears_without_save(node: AckHarness) -> void:
	var current := node.world.player().spell_wire_ids.duplicate()
	var deadline := node.world.tick + 1
	_arm(node, current, 85, true, deadline)
	node.world.tick = deadline
	node._complete_pending_weave()
	check(node.pending_weave_request.is_empty(), "an expired request clears even when state and acknowledgement match")
	equal(node.save_calls, 0, "deadline expiry cannot write a local weave")
	check(node.spell_loom_editor.starter_preview_active(), "deadline expiry leaves the proposal available for an explicit retry or cancel")
	check(node.spell_loom_editor.status_message.contains("no local save"), "deadline feedback states that no local save occurred")


func _test_acknowledgement_codec() -> void:
	var confirmation := {
		"type": "station_confirmed",
		"event_id": 901,
		"entity_id": 2,
		"action": SessionTransport.REQUEST_WEAVE_APPLY,
		"sequence": 97,
		"champion_wire_id": 30,
	}
	var encoded := SessionSnapshot.encode_event(confirmation)
	check(not encoded.is_empty() and SessionSnapshot._valid_event_values(encoded), "bounded weave acknowledgement validates for snapshot transport")
	var decoded := SessionSnapshot.decode_event(encoded)
	equal(int(decoded.get("sequence", 0)), 97, "weave acknowledgement round-trips its exact request sequence")
	equal(int(decoded.get("champion_wire_id", 0)), 30, "weave acknowledgement round-trips its exact character wire")

	var refused := SessionSnapshot.encode_event({
		"type": "request_refused",
		"event_id": 902,
		"entity_id": 2,
		"action": SessionTransport.REQUEST_WEAVE_APPLY,
		"reason": SessionRequestPolicy.REFUSED_UNAVAILABLE,
		"sequence": 98,
	})
	check(SessionSnapshot._valid_event_values(refused), "bounded weave refusal validates for snapshot transport")
	equal(int(SessionSnapshot.decode_event(refused).get("sequence", 0)), 98, "weave refusal round-trips its exact request sequence")

	for invalid_sequence: int in [0, 0x80000000]:
		var invalid_confirmation := confirmation.duplicate(true)
		invalid_confirmation.sequence = invalid_sequence
		check(not SessionSnapshot._valid_event_values(SessionSnapshot.encode_event(invalid_confirmation)), "weave acknowledgement rejects out-of-range sequence %d" % invalid_sequence)
		var invalid_refusal := {
			"type": "request_refused",
			"entity_id": 2,
			"action": SessionTransport.REQUEST_WEAVE_APPLY,
			"reason": SessionRequestPolicy.REFUSED_UNAVAILABLE,
			"sequence": invalid_sequence,
		}
		check(not SessionSnapshot._valid_event_values(SessionSnapshot.encode_event(invalid_refusal)), "weave refusal rejects out-of-range sequence %d" % invalid_sequence)
