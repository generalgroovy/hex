extends FluxTestSuite


func run() -> int:
	_test_readiness_and_countdown()
	_test_presence_cancels_countdown()
	_test_packet_validation()
	return finish("session-hearth")


func _test_readiness_and_countdown() -> void:
	var hearth := SessionHearth.new()
	hearth.bind_host()
	equal(hearth.connected_count(), 1, "Hearth begins with the connected host")
	check(not hearth.all_connected_ready(), "solo host cannot start shared practice")
	check(hearth.connect_entity(2), "guest enters Hearth presence")
	check(hearth.toggle_ready(1), "host becomes ready")
	check(hearth.toggle_ready(2), "guest becomes ready")
	check(hearth.all_connected_ready(), "two connected ready travellers satisfy start gate")
	check(not hearth.start_countdown(2, 100, 180), "guest cannot start host-owned countdown")
	check(hearth.start_countdown(1, 100, 180), "ready host starts bounded countdown")
	check(not hearth.toggle_ready(2), "readiness is sealed during countdown")
	equal(hearth.countdown_remaining(160), 120, "countdown remaining is simulation-tick based")
	check(not hearth.countdown_completed(279), "countdown does not complete early")
	check(hearth.countdown_completed(280), "countdown completes on exact host tick")
	var packet := hearth.capture(160, 4)
	check(SessionHearth.validate_packet(packet), "Hearth state captures to bounded packed values")
	var decoded := SessionHearth.decoded(packet)
	equal(int(decoded.get("maximum_players", 0)), 4, "Hearth packet carries sealed capacity")
	equal((decoded.get("entries", []) as Array).size(), 2, "Hearth packet carries the roster")
	check(bool(SessionHearth.entry(packet, 2).get("ready", false)), "Hearth packet exposes guest readiness")
	hearth.clear_after_start()
	check(not hearth.countdown_active() and not hearth.is_ready(1) and not hearth.is_ready(2), "practice start clears countdown and readiness")


func _test_presence_cancels_countdown() -> void:
	var hearth := SessionHearth.new()
	hearth.bind_host()
	check(hearth.connect_entity(2), "presence fixture connects guest")
	check(hearth.toggle_ready(1) and hearth.toggle_ready(2), "presence fixture readies pair")
	check(hearth.start_countdown(1, 0, 180), "presence fixture starts countdown")
	check(hearth.suspend_entity(2), "disconnect marks guest returning")
	check(not hearth.countdown_active(), "return reservation cancels countdown")
	equal(hearth.returning_count(), 1, "returning traveller remains visible")
	check(not hearth.is_ready(2), "returning traveller cannot remain ready")
	check(hearth.connect_entity(2), "return reconnects exact Hearth entry")
	check(not hearth.is_ready(2), "return must ready again")
	check(hearth.remove_entity(2), "expiry removes Hearth entry")
	equal(hearth.presence_by_entity.size(), 1, "expiry leaves only host")


func _test_packet_validation() -> void:
	var hearth := SessionHearth.new()
	hearth.bind_host()
	var valid := hearth.capture(0, 8)
	check(SessionHearth.validate_packet(valid), "minimal host Hearth packet validates")
	for mutation: Callable in [
		func(values: PackedInt32Array) -> void: values[0] = 99,
		func(values: PackedInt32Array) -> void: values[1] = 32,
		func(values: PackedInt32Array) -> void: values[2] = 361,
		func(values: PackedInt32Array) -> void: values[1] = 8 | (9 << SessionHearth.COUNT_SHIFT),
		func(values: PackedInt32Array) -> void: values[3] = 9 | (SessionHearth.STATUS_CONNECTED << SessionHearth.STATUS_SHIFT),
		func(values: PackedInt32Array) -> void: values[3] = 1 | (SessionHearth.STATUS_RETURNING << SessionHearth.STATUS_SHIFT),
		func(values: PackedInt32Array) -> void: values[3] = 1 | (SessionHearth.STATUS_CONNECTED << SessionHearth.STATUS_SHIFT) | (2 << SessionHearth.READY_SHIFT),
	]:
		var malformed := valid.duplicate()
		mutation.call(malformed)
		check(not SessionHearth.validate_packet(malformed), "malformed Hearth packet fails closed")
