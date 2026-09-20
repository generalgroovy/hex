class_name SessionEventInbox
extends RefCounted


const MAX_SEEN_EVENT_IDS: int = 64

var seen_event_ids: Dictionary[int, bool] = {}


func take_unseen(events: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in events:
		var event_id := int(event.get("event_id", 0))
		if event_id <= 0:
			result.append(event)
			continue
		if seen_event_ids.has(event_id):
			continue
		seen_event_ids[event_id] = true
		result.append(event)
	while seen_event_ids.size() > MAX_SEEN_EVENT_IDS:
		var oldest_id: int = seen_event_ids.keys().min()
		seen_event_ids.erase(oldest_id)
	return result


func reset() -> void:
	seen_event_ids = {}
