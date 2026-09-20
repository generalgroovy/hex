class_name SpectatorFocus
extends RefCounted


var active: bool = false
var focus_entity_id: int = 0
var participant_entity_ids: Array[int] = []


func reset() -> void:
	active = false
	focus_entity_id = 0
	participant_entity_ids = []


func reconcile(round_state: Dictionary, local_entity_id: int, available_entity_ids: Array[int]) -> bool:
	var phase := int(round_state.get("phase", SessionRound.Phase.HEARTH))
	if phase not in [SessionRound.Phase.ACTIVE, SessionRound.Phase.RESULT]:
		reset()
		return false
	var available: Dictionary[int, bool] = {}
	for entity_id: int in available_entity_ids:
		if entity_id >= 1 and entity_id <= SessionRound.MAX_PLAYERS:
			available[entity_id] = true
	var next_participants: Array[int] = []
	var entries_value: Variant = round_state.get("entries", [])
	if entries_value is Array:
		for entry_value: Variant in entries_value:
			if not entry_value is Dictionary:
				continue
			var entity_id := int((entry_value as Dictionary).get("entity_id", 0))
			if available.has(entity_id) and not next_participants.has(entity_id):
				next_participants.append(entity_id)
	next_participants.sort()
	if next_participants.is_empty() or next_participants.has(local_entity_id):
		reset()
		return false
	participant_entity_ids = next_participants
	active = true
	if not participant_entity_ids.has(focus_entity_id):
		focus_entity_id = participant_entity_ids[0]
	return true


func cycle_next() -> int:
	if not active or participant_entity_ids.is_empty():
		return 0
	var current_index := participant_entity_ids.find(focus_entity_id)
	focus_entity_id = participant_entity_ids[(current_index + 1) % participant_entity_ids.size()] if current_index >= 0 else participant_entity_ids[0]
	return focus_entity_id
