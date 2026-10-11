class_name SessionHearth
extends RefCounted


const SCHEMA_VERSION: int = 1
const STATUS_CONNECTED: int = 1
const STATUS_RETURNING: int = 2
const MIN_PLAYERS_TO_START: int = 2
const MAX_PLAYERS: int = 8
const MAX_COUNTDOWN_TICKS: int = 360
const HEADER_VALUES: int = 3
const ENTRY_VALUES: int = 1
const CAPACITY_MASK: int = 0xff
const COUNT_SHIFT: int = 8
const ENTITY_MASK: int = 0x0f
const STATUS_SHIFT: int = 4
const STATUS_MASK: int = 0x03
const READY_SHIFT: int = 6
const ENTRY_MASK: int = 0x7f

var presence_by_entity: Dictionary[int, int] = {}
var ready_by_entity: Dictionary[int, bool] = {}
var countdown_end_tick: int = -1


func bind_host() -> void:
	presence_by_entity = {SessionCharter.HOST_ENTITY_ID: STATUS_CONNECTED}
	ready_by_entity = {SessionCharter.HOST_ENTITY_ID: false}
	countdown_end_tick = -1


func connect_entity(entity_id: int) -> bool:
	if entity_id < SessionCharter.HOST_ENTITY_ID or entity_id > MAX_PLAYERS:
		return false
	presence_by_entity[entity_id] = STATUS_CONNECTED
	ready_by_entity[entity_id] = false
	cancel_countdown()
	return true


func suspend_entity(entity_id: int) -> bool:
	if entity_id <= SessionCharter.HOST_ENTITY_ID or not presence_by_entity.has(entity_id):
		return false
	presence_by_entity[entity_id] = STATUS_RETURNING
	ready_by_entity[entity_id] = false
	cancel_countdown()
	return true


func remove_entity(entity_id: int) -> bool:
	if entity_id <= SessionCharter.HOST_ENTITY_ID or not presence_by_entity.has(entity_id):
		return false
	presence_by_entity.erase(entity_id)
	ready_by_entity.erase(entity_id)
	cancel_countdown()
	return true


func toggle_ready(entity_id: int) -> bool:
	if countdown_end_tick >= 0 or int(presence_by_entity.get(entity_id, 0)) != STATUS_CONNECTED:
		return false
	ready_by_entity[entity_id] = not bool(ready_by_entity.get(entity_id, false))
	return true


func is_ready(entity_id: int) -> bool:
	return int(presence_by_entity.get(entity_id, 0)) == STATUS_CONNECTED and bool(ready_by_entity.get(entity_id, false))


func connected_count() -> int:
	var result: int = 0
	for status: int in presence_by_entity.values():
		if status == STATUS_CONNECTED:
			result += 1
	return result


func returning_count() -> int:
	var result: int = 0
	for status: int in presence_by_entity.values():
		if status == STATUS_RETURNING:
			result += 1
	return result


func all_connected_ready(required_count: int = 0) -> bool:
	if connected_count() < MIN_PLAYERS_TO_START:
		return false
	if required_count != 0 and (required_count not in [4, 6] or connected_count() != required_count or returning_count() > 0):
		return false
	for entity_id: int in presence_by_entity:
		if int(presence_by_entity[entity_id]) == STATUS_CONNECTED and not bool(ready_by_entity.get(entity_id, false)):
			return false
	return true


func connected_entity_ids() -> Array[int]:
	var result: Array[int] = []
	for entity_id: int in presence_by_entity:
		if int(presence_by_entity[entity_id]) == STATUS_CONNECTED:
			result.append(entity_id)
	result.sort()
	return result


func start_countdown(requester_entity_id: int, world_tick: int, duration_ticks: int, required_count: int = 0) -> bool:
	if (
		requester_entity_id != SessionCharter.HOST_ENTITY_ID
		or world_tick < 0
		or duration_ticks < 1
		or duration_ticks > MAX_COUNTDOWN_TICKS
		or countdown_end_tick >= 0
		or not all_connected_ready(required_count)
	):
		return false
	countdown_end_tick = world_tick + duration_ticks
	return true


func countdown_active() -> bool:
	return countdown_end_tick >= 0


func countdown_remaining(world_tick: int) -> int:
	return maxi(0, countdown_end_tick - world_tick) if countdown_end_tick >= 0 else 0


func countdown_completed(world_tick: int) -> bool:
	return countdown_end_tick >= 0 and world_tick >= countdown_end_tick


func cancel_countdown() -> bool:
	var changed := countdown_end_tick >= 0
	countdown_end_tick = -1
	return changed


func clear_after_start() -> void:
	countdown_end_tick = -1
	for entity_id: int in ready_by_entity:
		ready_by_entity[entity_id] = false


func capture(world_tick: int, maximum_players: int) -> PackedInt32Array:
	if maximum_players < MIN_PLAYERS_TO_START or maximum_players > MAX_PLAYERS:
		return PackedInt32Array()
	var entity_ids: Array[int] = []
	for entity_id: int in presence_by_entity:
		entity_ids.append(entity_id)
	entity_ids.sort()
	var result := PackedInt32Array([
		SCHEMA_VERSION,
		maximum_players | (entity_ids.size() << COUNT_SHIFT),
		countdown_remaining(world_tick),
	])
	for entity_id: int in entity_ids:
		result.append(
			entity_id
			| (int(presence_by_entity[entity_id]) << STATUS_SHIFT)
			| ((1 if is_ready(entity_id) else 0) << READY_SHIFT)
		)
	return result if validate_packet(result) else PackedInt32Array()


static func validate_packet(values: PackedInt32Array) -> bool:
	if values.size() < HEADER_VALUES or values[0] != SCHEMA_VERSION:
		return false
	var maximum_players := maximum_players_from_packet(values)
	if maximum_players < MIN_PLAYERS_TO_START or maximum_players > MAX_PLAYERS:
		return false
	if values[2] < 0 or values[2] > MAX_COUNTDOWN_TICKS:
		return false
	var count := entry_count(values)
	if count < 1 or count > maximum_players or values.size() != HEADER_VALUES + count * ENTRY_VALUES:
		return false
	var previous_entity_id: int = 0
	for index: int in range(count):
		var offset := HEADER_VALUES + index * ENTRY_VALUES
		var packed_entry := values[offset]
		if packed_entry < 0 or packed_entry > ENTRY_MASK:
			return false
		var entity_id := packed_entry & ENTITY_MASK
		var status := (packed_entry >> STATUS_SHIFT) & STATUS_MASK
		var ready := (packed_entry >> READY_SHIFT) & 1
		if entity_id <= previous_entity_id or entity_id < 1 or entity_id > MAX_PLAYERS:
			return false
		if status not in [STATUS_CONNECTED, STATUS_RETURNING] or ready not in [0, 1]:
			return false
		if status == STATUS_RETURNING and ready != 0:
			return false
		if entity_id == SessionCharter.HOST_ENTITY_ID and status != STATUS_CONNECTED:
			return false
		previous_entity_id = entity_id
	return true


static func decoded(values: PackedInt32Array) -> Dictionary:
	if not validate_packet(values):
		return {}
	var entries: Array[Dictionary] = []
	for index: int in range(entry_count(values)):
		var offset := HEADER_VALUES + index * ENTRY_VALUES
		var packed_entry := values[offset]
		entries.append({
			"entity_id": packed_entry & ENTITY_MASK,
			"status": (packed_entry >> STATUS_SHIFT) & STATUS_MASK,
			"ready": ((packed_entry >> READY_SHIFT) & 1) == 1,
		})
	return {
		"maximum_players": maximum_players_from_packet(values),
		"countdown_ticks": values[2],
		"entries": entries,
	}


static func maximum_players_from_packet(values: PackedInt32Array) -> int:
	return values[1] & CAPACITY_MASK if values.size() >= HEADER_VALUES else 0


static func entry_count(values: PackedInt32Array) -> int:
	return (values[1] >> COUNT_SHIFT) & CAPACITY_MASK if values.size() >= HEADER_VALUES else 0


static func entity_id_at(values: PackedInt32Array, index: int) -> int:
	if index < 0 or index >= entry_count(values):
		return 0
	return values[HEADER_VALUES + index * ENTRY_VALUES] & ENTITY_MASK


static func entry(values: PackedInt32Array, entity_id: int) -> Dictionary:
	var state := decoded(values)
	for candidate: Dictionary in state.get("entries", []):
		if int(candidate.get("entity_id", 0)) == entity_id:
			return candidate
	return {}
