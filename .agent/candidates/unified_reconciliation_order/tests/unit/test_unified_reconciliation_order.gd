extends FluxTestSuite


const Buffer = preload("res://src/net/reconciliation_order_buffer.gd")
const Prediction = preload("res://src/net/client_prediction.gd")
const ACTOR_ID := 2


func run() -> int:
	_test_reconciliation_waits_for_exact_snapshot()
	_test_snapshot_waits_for_delayed_reconciliation()
	_test_epoch_and_acknowledgement_guards()
	_test_queue_is_bounded_to_transport_capacity()
	return finish("unified-reconciliation-order")


func _test_reconciliation_waits_for_exact_snapshot() -> void:
	var buffer := Buffer.new()
	check(buffer.configure_epoch(7), "buffer accepts the trusted current epoch")
	check(buffer.offer(_packet(40, 5, 7)), "current-epoch reconciliation may arrive before its snapshot")
	equal(buffer.take_exact(7, 39), {}, "future reconciliation cannot run against older snapshot geometry")
	check(buffer.has_tick(40), "future reconciliation remains staged after the older snapshot")
	var released := buffer.take_exact(7, 40)
	check(not released.is_empty(), "matching full snapshot releases the retained reconciliation")
	equal(int(released.sequence), 5, "retained reconciliation preserves its input acknowledgement")
	equal(buffer.size(), 0, "exact release removes the retained packet once")


func _test_snapshot_waits_for_delayed_reconciliation() -> void:
	var buffer := Buffer.new()
	buffer.configure_epoch(4)
	equal(buffer.take_exact(4, 52), {}, "a snapshot without its movement packet remains usable")
	check(buffer.offer(_packet(52, 8, 4)), "matching reconciliation may arrive after the snapshot")
	var released := buffer.take_exact(4, 52)
	check(not released.is_empty(), "late reconciliation releases while its exact snapshot is still current")
	equal(int(released.tick), 52, "late release never substitutes another geometry tick")


func _test_epoch_and_acknowledgement_guards() -> void:
	var buffer := Buffer.new()
	buffer.configure_epoch(8)
	check(not buffer.offer(_packet(60, 9, 7)), "stale-epoch reconciliation is rejected")
	var unstamped := _packet(60, 9, 0)
	unstamped.erase("world_epoch")
	check(not buffer.offer(unstamped), "legacy unstamped packet cannot enter a nonzero epoch")
	check(buffer.offer(_packet(60, 10, 8)), "current-epoch packet is accepted")
	equal(int(buffer.take_exact(8, 60).sequence), 10, "first exact release establishes the acknowledgement floor")
	check(not buffer.offer(_packet(61, 9, 8)), "newer ticks cannot move acknowledgement backwards")
	check(buffer.offer(_packet(61, 10, 8)), "equal acknowledgement remains valid when no input was processed")
	equal(int(buffer.take_exact(8, 61).sequence), 10, "equal acknowledgement releases monotonically")
	check(buffer.offer(_packet(62, 11, 8)), "a larger acknowledgement remains valid")
	equal(int(buffer.take_exact(8, 62).sequence), 11, "larger acknowledgement advances the cursor")
	check(not buffer.offer(_packet(62, 12, 8)), "an authoritative tick can release only once")
	check(buffer.offer(_packet(63, 12, 8)), "packet can stage before a world replacement")
	check(buffer.configure_epoch(9), "new world epoch configures atomically")
	equal(buffer.size(), 0, "epoch change clears every retained reconciliation")
	equal(buffer.last_released_sequence, -1, "epoch change clears the old acknowledgement cursor")
	check(not buffer.offer(_packet(63, 12, 8)), "old epoch cannot re-enter after replacement")


func _test_queue_is_bounded_to_transport_capacity() -> void:
	var buffer := Buffer.new()
	buffer.configure_epoch(12)
	check(buffer.offer(_packet(70, 20, 12)), "first future packet stages")
	check(not buffer.offer(_packet(71, 19, 12)), "queued acknowledgements cannot decrease as ticks advance")
	check(buffer.offer(_packet(71, 21, 12)), "second future packet stages")
	check(buffer.offer(_packet(72, 22, 12)), "newest future packet replaces the oldest at the finite bound")
	equal(buffer.size(), Buffer.MAX_PACKETS, "application staging matches the transport reconciliation bound")
	check(not buffer.has_tick(70) and buffer.has_tick(71) and buffer.has_tick(72), "bounded overflow retains the newest exact ticks")
	check(buffer.offer(_packet(72, 23, 12)), "duplicate tick with a newer acknowledgement replaces its older packet")
	equal(buffer.size(), Buffer.MAX_PACKETS, "duplicate replacement cannot grow the queue")
	equal(int(buffer.take_exact(12, 72).sequence), 23, "duplicate tick releases only the newest acknowledgement")
	buffer.reset()
	equal(buffer.active_epoch, -1, "disconnect reset removes the active epoch")
	equal(buffer.size(), 0, "disconnect reset clears all retained packets")


func _packet(tick: int, sequence: int, epoch: int) -> Dictionary:
	var packet := Prediction.capture_packet(PlayerState.new(ACTOR_ID), tick, sequence)
	packet.world_epoch = epoch
	return packet
