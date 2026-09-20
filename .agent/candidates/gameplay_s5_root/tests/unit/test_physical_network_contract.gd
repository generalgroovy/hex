extends FluxTestSuite


func run() -> int:
	_test_input_wire_bits_and_coalescing()
	_test_physical_contact_codec()
	_test_contact_retention_priority()
	return finish("physical-network-contract")


func _test_input_wire_bits_and_coalescing() -> void:
	var packet := {
		"sequence": 1,
		"move_x": 0,
		"move_y": 0,
		"held": 0,
		"pressed": 0,
		"aim_x": 1000,
		"aim_y": 0,
	}
	for pressed: int in [SimCommand.PRESSED_PUNCH, SimCommand.PRESSED_KICK, SimCommand.PRESSED_MODAL_CANCEL]:
		var known := packet.duplicate()
		known["pressed"] = pressed
		check(SessionTransport._valid_input_packet(known), "known physical input bit %d crosses the typed input boundary" % pressed)
	var unknown := packet.duplicate()
	unknown["pressed"] = 1 << 20
	check(not SessionTransport._valid_input_packet(unknown), "unknown input bit20 fails closed")

	var transport := SessionTransport.new()
	for sequence: int in range(1, SessionTransport.MAX_QUEUED_INPUTS_PER_PEER + 1):
		var queued := packet.duplicate()
		queued["sequence"] = sequence
		queued["held"] = SimCommand.HELD_PRIMARY if sequence == SessionTransport.MAX_QUEUED_INPUTS_PER_PEER else 0
		queued["pressed"] = (
			SimCommand.PRESSED_PUNCH | SimCommand.PRESSED_KICK | SimCommand.PRESSED_MODAL_CANCEL
			if sequence == SessionTransport.MAX_QUEUED_INPUTS_PER_PEER else 0
		)
		transport._queue_input(42, queued)
	var replacement := packet.duplicate()
	replacement["sequence"] = SessionTransport.MAX_QUEUED_INPUTS_PER_PEER + 1
	replacement["move_x"] = 731
	replacement["held"] = SimCommand.HELD_SPRINT
	transport._queue_input(42, replacement)
	var retained := transport.take_inputs()
	equal(retained.size(), SessionTransport.MAX_QUEUED_INPUTS_PER_PEER, "saturated physical input lane remains bounded")
	var newest: Dictionary = retained.back()
	equal(int(newest.get("sequence", 0)), SessionTransport.MAX_QUEUED_INPUTS_PER_PEER + 1, "coalescing retains the newest sequence")
	equal(int(newest.get("move_x", 0)), 731, "coalescing retains newest sampled movement")
	equal(int(newest.get("held", 0)), SimCommand.HELD_SPRINT, "coalescing retains newest held state without OR-latching it")
	equal(
		int(newest.get("pressed", 0)),
		SimCommand.PRESSED_PUNCH | SimCommand.PRESSED_KICK | SimCommand.PRESSED_MODAL_CANCEL,
		"coalescing carries all displaced physical edges into the newest packet",
	)


func _test_physical_contact_codec() -> void:
	var contact := {
		"type": "physical_attack_contact",
		"attacker_id": 2,
		"target_id": 900,
		"kind": "kick",
		"sequence_id": 1_234,
		"damage": 8_000,
		"contact_position": Vector2i(-4_321, 8_765),
		"target_position_before_knockback": Vector2i(71_001, -82_002),
		"knockback_delta": Vector2i(-9_003, 10_004),
		"first_contact": true,
		"knockback_guarded": true,
		"wall_id": -2,
	}
	var encoded := PhysicalEventCodec.encode(contact, 77)
	equal(encoded.size(), PhysicalEventCodec.VALUE_COUNT, "physical contact has the exact fixed wire width")
	check(PhysicalEventCodec.validate(encoded), "bounded physical contact validates")
	var decoded := PhysicalEventCodec.decode(encoded)
	equal(int(decoded.get("event_id", 0)), 77, "physical event ID survives its packed header")
	equal(int(decoded.get("attacker_id", 0)), 2, "physical attacker ID survives codec roundtrip")
	equal(int(decoded.get("target_id", 0)), 900, "practice target ID survives codec roundtrip")
	equal(String(decoded.get("kind", "")), "kick", "physical attack kind survives codec roundtrip")
	equal(int(decoded.get("sequence_id", 0)), 1_234, "physical sequence ID survives codec roundtrip")
	equal(int(decoded.get("damage", 0)), 8_000, "physical damage survives codec roundtrip")
	equal(decoded.get("contact_position", Vector2i.ZERO), Vector2i(-4_321, 8_765), "physical contact point survives codec roundtrip")
	equal(decoded.get("target_position_before_knockback", Vector2i.ZERO), Vector2i(71_001, -82_002), "physical pre-knockback target point survives codec roundtrip")
	equal(decoded.get("knockback_delta", Vector2i.ZERO), Vector2i(-9_003, 10_004), "physical knockback delta survives codec roundtrip")
	check(bool(decoded.get("first_contact", false)), "physical first-contact flag survives codec roundtrip")
	check(bool(decoded.get("knockback_guarded", false)), "physical knockback-guard flag survives codec roundtrip")
	equal(int(decoded.get("wall_id", 0)), -2, "physical boundary-wall ID survives codec roundtrip")


func _test_contact_retention_priority() -> void:
	var session := AuthoritativeSession.new()
	var burst: Array[Dictionary] = []
	for contact_index: int in range(8):
		burst.append({
			"type": "physical_attack_contact",
			"attacker_id": 1,
			"target_id": 100 + contact_index,
			"kind": "punch",
			"sequence_id": contact_index + 1,
			"damage": 5_000,
			"contact_position": Vector2i(contact_index, -contact_index),
			"target_position_before_knockback": Vector2i(100_000 + contact_index, 200_000),
			"knockback_delta": Vector2i(10_000, 0),
			"first_contact": true,
			"knockback_guarded": false,
			"wall_id": 0,
		})
	for phase_index: int in range(12):
		burst.append({
			"type": "physical_attack_phase",
			"entity_id": 1,
			"kind": "punch",
			"sequence_id": 100 + phase_index,
			"phase": "active",
			"ticks": 2,
		})
	equal(session.record_combat_events(burst), burst.size(), "all bounded physical events reach retention policy")
	equal(session.pending_combat_events.size(), SessionSnapshot.MAX_EVENTS, "mixed physical burst retains the bounded event lane")
	var retained_contacts: int = 0
	var retained_phases: int = 0
	for event: Dictionary in session.pending_combat_events:
		match String(event.get("type", "")):
			"physical_attack_contact": retained_contacts += 1
			"physical_attack_phase": retained_phases += 1
	equal(retained_contacts, 8, "all outcome-priority physical contacts survive a later cosmetic phase flood")
	equal(retained_phases, SessionSnapshot.MAX_EVENTS - retained_contacts, "only the newest cosmetic phases fill the remaining lane")
