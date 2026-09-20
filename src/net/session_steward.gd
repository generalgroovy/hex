class_name SessionSteward
extends RefCounted


enum Action {
	NONE,
	RELEASE_GUEST,
	CLOSE_COMPANY,
}

enum Decision {
	REFUSED,
	ARMED,
	CONFIRMED,
}

const MIN_CONFIRMATION_TICKS: int = 1
const MAX_CONFIRMATION_TICKS: int = 1_000_000

var selected_entity_id: int = 0
var armed_action: int = Action.NONE
var armed_entity_id: int = 0
var armed_until_tick: int = -1


func reset() -> void:
	selected_entity_id = 0
	_clear_armed()


func cycle_guest(roster: Array[Dictionary]) -> int:
	var entity_ids := _connected_entity_ids(roster)
	if entity_ids.is_empty():
		reset()
		return 0
	var current_index := entity_ids.find(selected_entity_id)
	selected_entity_id = entity_ids[(current_index + 1) % entity_ids.size()] if current_index >= 0 else entity_ids[0]
	_clear_armed()
	return selected_entity_id


func reconcile_roster(roster: Array[Dictionary]) -> bool:
	if selected_entity_id == 0:
		return false
	if _connected_entity_ids(roster).has(selected_entity_id):
		return true
	reset()
	return false


func request_release(current_tick: int, confirmation_ticks: int) -> int:
	if selected_entity_id < 2 or selected_entity_id > SessionTransport.MAX_PLAYERS:
		return Decision.REFUSED
	return _request(Action.RELEASE_GUEST, selected_entity_id, current_tick, confirmation_ticks)


func request_close(current_tick: int, confirmation_ticks: int) -> int:
	return _request(Action.CLOSE_COMPANY, 0, current_tick, confirmation_ticks)


func expire(current_tick: int) -> bool:
	if armed_action == Action.NONE or current_tick <= armed_until_tick:
		return false
	_clear_armed()
	return true


func is_armed(action: int, entity_id: int = 0, current_tick: int = -1) -> bool:
	if current_tick >= 0:
		expire(current_tick)
	return armed_action == action and armed_entity_id == entity_id


func remaining_ticks(current_tick: int) -> int:
	if armed_action == Action.NONE:
		return 0
	return maxi(0, armed_until_tick - current_tick)


func clear_selection() -> void:
	reset()


func _request(action: int, entity_id: int, current_tick: int, confirmation_ticks: int) -> int:
	if (
		action not in [Action.RELEASE_GUEST, Action.CLOSE_COMPANY]
		or current_tick < 0
		or confirmation_ticks < MIN_CONFIRMATION_TICKS
		or confirmation_ticks > MAX_CONFIRMATION_TICKS
	):
		return Decision.REFUSED
	expire(current_tick)
	if armed_action == action and armed_entity_id == entity_id:
		_clear_armed()
		return Decision.CONFIRMED
	armed_action = action
	armed_entity_id = entity_id
	armed_until_tick = current_tick + confirmation_ticks
	return Decision.ARMED


func _clear_armed() -> void:
	armed_action = Action.NONE
	armed_entity_id = 0
	armed_until_tick = -1


static func _connected_entity_ids(roster: Array[Dictionary]) -> Array[int]:
	var result: Array[int] = []
	for entry: Dictionary in roster:
		var peer_id := int(entry.get("peer_id", 0))
		var entity_id := int(entry.get("entity_id", 0))
		if peer_id <= SessionTransport.SERVER_PEER_ID or entity_id < 2 or entity_id > SessionTransport.MAX_PLAYERS or result.has(entity_id):
			continue
		result.append(entity_id)
	result.sort()
	return result
