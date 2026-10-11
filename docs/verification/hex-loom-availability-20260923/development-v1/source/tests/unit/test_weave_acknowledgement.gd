extends FluxTestSuite


const BootstrapScript: Script = preload("res://src/app/bootstrap.gd")


# No-auto fixture: exercise the inherited acknowledgement state machine without
# running Bootstrap._ready(), opening sockets, or touching the player profile.
class AckHarness:
	extends "res://src/app/bootstrap.gd"
	var save_calls: int = 0
	var saved_mode: String = ""
	var forced_round_phase: int = -1

	func _ready() -> void:
		pass

	func _process(_delta: float) -> void:
		pass

	func _draw() -> void:
		pass

	func _save_confirmed_weave(_state: PlayerState, mode: String) -> void:
		save_calls += 1
		saved_mode = mode

	func _current_round_state() -> Dictionary:
		return {"phase": forced_round_phase} if forced_round_phase >= 0 else super._current_round_state()


func run() -> int:
	var node := _fixture()
	_test_offline_ui_request(node)
	_test_assignment_availability(node)
	_test_matching_state_requires_ack(node)
	_test_wrong_ack_and_refusal_are_ignored(node)
	_test_correct_ack_completes_matching_state(node)
	_test_ack_waits_for_authoritative_state(node)
	_test_deadline_clears_without_save(node)
	_test_pending_recovery(node)
	_test_legacy_active_cast_refusal(node)
	_test_acknowledgement_codec()
	node.free()
	return finish("weave-acknowledgement")


func _test_offline_ui_request(node: AckHarness) -> void:
	(Engine.get_main_loop() as SceneTree).root.add_child(node)
	node.campus_layout = SanctumCampusLayout.new()
	check(node.campus_layout.load_from_file(BootstrapScript.CAMPUS_LAYOUT_PATH), "ordinary request loads actual station geometry")
	node.authoritative_session = AuthoritativeSession.new()
	node.authoritative_session.world = node.world
	var position: Array = node.campus_layout.stations_by_id["spell-loom"].position
	node.world.player().position_x = int(position[0]) * 1000
	node.world.player().position_y = (int(position[1]) + 48) * 1000
	node.session_transport.local_entity_id = 0
	node._update_station_focus()
	node._activate_focused_station()
	check(node.spell_loom_editor.is_open, "ordinary station opens Loom")
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_RIGHT
	node._handle_spell_loom_input(event)
	event.keycode = KEY_ENTER
	node._handle_spell_loom_input(event)
	check(node.pending_weave_request.is_empty(), "offline actor1 request confirms with transport id0")
	equal(node.save_calls, 1, "ordinary confirmed UI assignment saves once")
	event.keycode = KEY_ESCAPE
	node._handle_spell_loom_input(event)
	check(not node.spell_loom_editor.is_open, "Escape closes after actual offline assignment")
	node.pending_weave_request.clear()
	node.session_transport.local_entity_id = 1


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


func _test_assignment_availability(node: AckHarness) -> void:
	var actor := node.world.player()
	node.spell_loom_editor.open_editor(actor, node.ability_catalog)
	for index: int in range(node.spell_loom_editor.available_wire_ids.size()):
		if node.spell_loom_editor.available_wire_ids[index] not in actor.spell_wire_ids:
			node.spell_loom_editor.selected_spell_index = index
			break
	var requested := node.spell_loom_editor.requested_wire_ids(actor)
	check(not requested.is_empty(), "availability fixture builds the exact ordinary requested weave")
	_place_at_station(node, actor, "spell-loom")
	var availability := node._loom_assignment_availability(actor, requested)
	check(bool(availability.get("enabled", false)), "Spell Loom station exposes assignment during Wellspring")
	_place_at_station(node, actor, "champion-loom")
	check(bool(node._loom_assignment_availability(actor, requested).get("enabled", false)), "eligible Gallery station preserves whole-weave admission")
	actor.position_x = 400_000
	actor.position_y = 400_000
	availability = node._loom_assignment_availability(actor, requested)
	check(not bool(availability.get("enabled", true)) and String(availability.get("reason", "")).contains("Spell Loom or Gallery"), "remote inspection reports the exact station requirement before submit")
	var before := actor.canonical_values()
	var retained_status := "Previous confirmation remains visible."
	node.spell_loom_editor.status_message = retained_status
	node._submit_whole_weave(actor, actor.spell_wire_ids, requested, CharacterWeaveLibrary.MODE_CUSTOM, false)
	check(node.pending_weave_request.is_empty() and actor.canonical_values() == before, "disabled remote assignment sends no request and mutates no authority")
	equal(node.spell_loom_editor.status_message, retained_status, "advisory availability does not overwrite retained confirmation feedback")
	_place_at_station(node, actor, "spell-loom")
	node.forced_round_phase = SessionRound.Phase.ACTIVE
	availability = node._loom_assignment_availability(actor, requested)
	check(not bool(availability.get("enabled", true)) and String(availability.get("reason", "")).contains("Wellspring free practice"), "active round reports the exact free-practice requirement")
	node.forced_round_phase = SessionRound.Phase.HEARTH
	actor.pending_cast_wire_id = actor.spell_wire_ids[0]
	actor.pending_cast_ticks = 2
	availability = node._loom_assignment_availability(actor, requested)
	check(not bool(availability.get("enabled", true)) and String(availability.get("reason", "")).contains("active action"), "paid active action disables assignment before request")
	actor.pending_cast_wire_id = 0
	actor.pending_cast_ticks = 0
	actor.health = 0
	availability = node._loom_assignment_availability(actor, requested)
	check(not bool(availability.get("enabled", true)) and String(availability.get("reason", "")).contains("alive"), "dead actor receives a specific assignment reason")
	actor.health = actor.health_maximum
	var cooling_slot := -1
	for slot: int in range(actor.spell_wire_ids.size()):
		if actor.spell_wire_ids[slot] not in actor.kit_spell_wire_ids():
			cooling_slot = slot
			break
	var replacement := 0
	for wire: int in CombatTuning.runtime_wire_ids():
		if wire not in actor.spell_wire_ids and wire not in actor.kit_spell_wire_ids():
			replacement = wire
			break
	check(cooling_slot >= 0 and replacement > 0, "availability fixture finds one removable non-legacy spell")
	if cooling_slot >= 0 and replacement > 0:
		var cooling_wire: int = actor.spell_wire_ids[cooling_slot]
		actor.set_spell_cooldown(cooling_wire, 3)
		var cooling_request := actor.spell_wire_ids.duplicate()
		cooling_request[cooling_slot] = replacement
		availability = node._loom_assignment_availability(actor, cooling_request)
		check(not bool(availability.get("enabled", true)) and String(availability.get("reason", "")).contains("cooldown"), "cooling removed spell reports the exact retry condition")
		actor.set_spell_cooldown(cooling_wire, 0)
	check(node.spell_loom_editor.prepare_starter_preview(actor, node.champion_catalog, node.ability_catalog), "availability fixture opens a read-only starter preview")
	var preview_requested := node._loom_presented_request(actor)
	var changed := actor.spell_wire_ids.duplicate()
	var first: int = changed[0]
	changed[0] = changed[1]
	changed[1] = first
	check(CharacterWeavePolicy.apply(actor, changed), "stale-preview fixture changes authority through the pure weave policy")
	availability = node._loom_assignment_availability(actor, preview_requested, true)
	check(not bool(availability.get("enabled", true)) and String(availability.get("reason", "")).contains("reopen the starter preview"), "stale starter preview reports an explicit refresh action")
	node.spell_loom_editor.cancel_starter_preview(false)
	node.pending_weave_request = {"sequence": 91}
	availability = node._loom_assignment_availability(actor, requested)
	check(not bool(availability.get("enabled", true)) and String(availability.get("reason", "")).contains("authority confirmation"), "pending confirmation keeps assignment quarantined")
	node.pending_weave_request.clear()
	node.client_request_sequence = 0x7fffffff
	availability = node._loom_assignment_availability(actor, requested)
	check(not bool(availability.get("enabled", true)) and String(availability.get("reason", "")).contains("Restart the session"), "exhausted request sequence is unavailable before submit")
	node.client_request_sequence = 0
	var original_map_id: String = node.world.map_id
	node.world.map_id = "hex-court-v1"
	actor.position_x = 400_000
	actor.position_y = 400_000
	availability = node._loom_assignment_availability(actor, actor.spell_wire_ids)
	check(bool(availability.get("enabled", false)), "isolated offline Hex Court retains its station-free Loom exception")
	node.world.map_id = original_map_id
	node.forced_round_phase = -1
	node.spell_loom_editor.close_editor()


func _place_at_station(node: AckHarness, actor: PlayerState, station_id: String) -> void:
	var position: Array = node.campus_layout.stations_by_id[station_id].position
	actor.position_x = int(position[0]) * 1000
	actor.position_y = (int(position[1]) + 48) * 1000


func _arm(
	node: AckHarness,
	requested: PackedInt32Array,
	sequence: int,
	acknowledged: bool = false,
	deadline_ms: int = -1,
	save: bool = true,
) -> void:
	node.save_calls = 0
	node.saved_mode = ""
	node.spell_loom_editor.starter_preview = {"notice": "fixture preview"}
	node.pending_weave_request = {
		"actor": node.world.player().entity_id,
		"context": node._weave_session_context(),
		"champion": node.world.player().champion_wire_id,
		"wires": requested.duplicate(),
		"mode": CharacterWeaveLibrary.MODE_STARTER,
		"save": save,
		"sequence": sequence,
		"acknowledged": acknowledged,
		"deadline_ms": Time.get_ticks_msec() + 5000 if deadline_ms < 0 else deadline_ms,
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
	_arm(node, current, 85, false, 0)
	node._complete_pending_weave()
	check(node.pending_weave_request.is_empty(), "wall-clock expiry recovers an unacknowledged request without simulation advancement")
	equal(node.save_calls, 0, "deadline expiry cannot write a local weave")
	check(node.spell_loom_editor.starter_preview_active(), "deadline expiry leaves the proposal available for an explicit retry or cancel")
	check(node.spell_loom_editor.status_message.contains("no local save"), "deadline feedback states that no local save occurred")
	_arm(node, current, 86, true, 0)
	node._complete_pending_weave()
	equal(node.save_calls, 1, "matching accepted authority saves even at the UI deadline")


func _test_pending_recovery(node: AckHarness) -> void:
	var wires := node.world.player().spell_wire_ids.duplicate()
	_arm(node, wires, 100)
	node.spell_loom_editor.is_open = true
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_ENTER
	node._handle_spell_loom_input(event)
	equal(int(node.pending_weave_request.sequence), 100, "rapid repeats cannot replace a pending request")
	event.keycode = KEY_ESCAPE
	node._handle_spell_loom_input(event)
	check(not node.spell_loom_editor.is_open, "Escape safely closes an unresponsive panel")
	check(not node.pending_weave_request.is_empty(), "closing does not revoke authority or forget an in-flight transaction")
	node._ingest_session_feedback([_confirmation(node, 100)])
	equal(node.save_calls, 1, "late confirmation after closing still saves accepted authority")
	node._ingest_session_feedback([_confirmation(node, 100)])
	equal(node.save_calls, 1, "duplicate confirmation cannot save twice")
	_arm(node, wires, 101)
	node.session_transport.world_epoch += 1
	node._ingest_session_feedback([_confirmation(node, 101)])
	equal(node.save_calls, 0, "old-session acknowledgement cannot persist")
	node._complete_pending_weave()
	check(node.pending_weave_request.is_empty(), "session transition clears stale pending without ticks")
	_arm(node, wires, 102)
	var wrong_actor := _confirmation(node, 102)
	wrong_actor.entity_id = 2
	node._ingest_session_feedback([wrong_actor])
	check(not bool(node.pending_weave_request.acknowledged), "another actor cannot confirm the request")
	node.world.player().champion_wire_id += 1
	node._complete_pending_weave()
	check(node.pending_weave_request.is_empty(), "character change invalidates pending transaction")
	node.world.player().champion_wire_id -= 1


func _test_legacy_active_cast_refusal(node: AckHarness) -> void:
	var actor := node.world.player()
	actor.pending_cast_wire_id = actor.spell_wire_ids[2]
	actor.pending_cast_ticks = 3
	var before := actor.canonical_values()
	node._handle_session_requests([{"entity_id": actor.entity_id, "action": SessionTransport.REQUEST_SPELL_EQUIP, "value": 1}])
	equal(actor.canonical_values(), before, "legacy equip cannot discard an already-paid pending cast")
	actor.pending_cast_wire_id = 0
	actor.pending_cast_ticks = 0


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
