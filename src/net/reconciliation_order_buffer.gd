class_name ReconciliationOrderBuffer
extends RefCounted


const Prediction = preload("res://src/net/client_prediction.gd")
const Envelope = preload("res://src/net/world_snapshot_envelope.gd")
const Transport = preload("res://src/net/session_transport.gd")

# This matches SessionTransport.MAX_QUEUED_RECONCILIATIONS. Transport can
# deliver at most two completed packets at once, and application staging must
# not introduce a second, larger unbounded queue. When full, keep newer ticks.
const MAX_PACKETS := Transport.MAX_QUEUED_RECONCILIATIONS

var active_epoch: int = -1
var last_released_tick: int = -1
var last_released_sequence: int = -1
var _packets: Array[Dictionary] = []


func configure_epoch(epoch: int) -> bool:
	if epoch < 0 or epoch > Envelope.MAX_EPOCH:
		return false
	if epoch == active_epoch:
		return true
	reset(epoch)
	return true


func reset(epoch: int = -1) -> void:
	active_epoch = epoch
	last_released_tick = -1
	last_released_sequence = -1
	_packets.clear()


func offer_many(packets: Array[Dictionary]) -> int:
	var accepted := 0
	for packet: Dictionary in packets:
		if offer(packet):
			accepted += 1
	return accepted


func offer(packet: Dictionary) -> bool:
	if active_epoch < 0 or not Prediction.validate_packet(packet):
		return false
	var packet_epoch := _packet_epoch(packet)
	if packet_epoch != active_epoch:
		return false
	var tick := int(packet.tick)
	var sequence := int(packet.sequence)
	if (last_released_tick >= 0 and tick <= last_released_tick) or sequence < last_released_sequence:
		return false
	for queued: Dictionary in _packets:
		var queued_tick := int(queued.tick)
		var queued_sequence := int(queued.sequence)
		if (queued_tick < tick and queued_sequence > sequence) or (queued_tick > tick and queued_sequence < sequence):
			return false
	for index: int in range(_packets.size()):
		if int(_packets[index].tick) != tick:
			continue
		# A duplicate tick can only improve its acknowledgement cursor. Keeping
		# the larger cursor is deterministic under packet duplication/reordering.
		if sequence <= int(_packets[index].sequence):
			return false
		_packets[index] = packet.duplicate(true)
		_sort_and_bound()
		return true
	_packets.append(packet.duplicate(true))
	_sort_and_bound()
	return _packets.any(func(value: Dictionary) -> bool: return int(value.tick) == tick and int(value.sequence) == sequence)


# A packet is released only against the full snapshot whose geometry owns the
# same epoch and tick. Calling before either half arrives is harmless: an exact
# packet may still be offered and released while that snapshot remains current.
func take_exact(epoch: int, snapshot_tick: int) -> Dictionary:
	if epoch != active_epoch or snapshot_tick < 0 or (last_released_tick >= 0 and snapshot_tick <= last_released_tick):
		return {}
	var selected_packet := {}
	var retained: Array[Dictionary] = []
	for packet: Dictionary in _packets:
		var tick := int(packet.tick)
		if tick < snapshot_tick:
			continue
		if tick == snapshot_tick:
			if int(packet.sequence) >= last_released_sequence:
				selected_packet = packet
			continue
		retained.append(packet)
	_packets = retained
	if selected_packet.is_empty():
		return {}
	var sequence := int(selected_packet.sequence)
	if sequence < last_released_sequence:
		return {}
	last_released_tick = snapshot_tick
	last_released_sequence = sequence
	return selected_packet.duplicate(true)


func size() -> int:
	return _packets.size()


func has_tick(tick: int) -> bool:
	return _packets.any(func(packet: Dictionary) -> bool: return int(packet.tick) == tick)


func _sort_and_bound() -> void:
	_packets.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.tick) < int(right.tick) if int(left.tick) != int(right.tick) else int(left.sequence) < int(right.sequence)
	)
	while _packets.size() > MAX_PACKETS:
		_packets.pop_front()


func _packet_epoch(packet: Dictionary) -> int:
	if packet.has("world_epoch"):
		return int(packet.world_epoch) if typeof(packet.world_epoch) == TYPE_INT else -1
	# SessionTransport keeps the historical epoch-zero packet view for legacy
	# callers. Missing epoch metadata is therefore valid only in epoch zero.
	return 0
