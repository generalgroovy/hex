extends RefCounted

## Per-tick scratch only. No authority, wire data, limits or collision policy.
class OrderedQueue:
	extends RefCounted
	var _items: Array = []
	var _next_serial := 0
	var _before: Callable
	func _init(before: Callable) -> void:
		_before = before
	func is_empty() -> bool:
		return _items.is_empty()
	func _less(a: Array, b: Array) -> bool:
		if _before.call(a[0], b[0]): return true
		if _before.call(b[0], a[0]): return false
		return int(a[1]) < int(b[1])
	func append(event: Dictionary) -> void:
		var entry := [event, _next_serial]
		_next_serial += 1
		var index := _items.size()
		_items.append(entry)
		while index > 0:
			var parent := (index - 1) >> 1
			if not _less(entry, _items[parent]): break
			_items[index] = _items[parent]
			index = parent
		_items[index] = entry
	func pop_front() -> Dictionary:
		var result: Dictionary = _items[0][0]
		var last: Array = _items.pop_back()
		if _items.is_empty(): return result
		var index := 0
		while index * 2 + 1 < _items.size():
			var child := index * 2 + 1
			if child + 1 < _items.size() and _less(_items[child + 1], _items[child]): child += 1
			if not _less(_items[child], last): break
			_items[index] = _items[child]
			index = child
		_items[index] = last
		return result

class SpatialPlans:
	extends RefCounted
	const BUCKET_SIZE := 128_000
	var _buckets: Dictionary = {}
	var _keys_by_id: Dictionary = {}
	var _plans: Dictionary = {}
	var _ranks: Dictionary = {}
	func _init(plans: Array[Dictionary]) -> void:
		for plan: Dictionary in plans: update(plan)
	static func bounds(plan: Dictionary) -> Rect2i:
		var start: Vector2i = plan.start
		var finish: Vector2i = plan.finish
		var radius := int(plan.radius)
		var low := Vector2i(mini(start.x,finish.x)-radius,mini(start.y,finish.y)-radius)
		var high := Vector2i(maxi(start.x,finish.x)+radius,maxi(start.y,finish.y)+radius)
		return Rect2i(low,high-low)
	static func _keys(rect: Rect2i) -> Array[Vector2i]:
		var result: Array[Vector2i] = []
		for y: int in range(floori(float(rect.position.y)/BUCKET_SIZE),floori(float(rect.end.y)/BUCKET_SIZE)+1):
			for x: int in range(floori(float(rect.position.x)/BUCKET_SIZE),floori(float(rect.end.x)/BUCKET_SIZE)+1): result.append(Vector2i(x,y))
		return result
	static func overlaps(first: Rect2i, second: Rect2i) -> bool:
		# Rect2i.intersects excludes borders. TOI contacts own closed endpoints.
		return first.position.x <= second.end.x and second.position.x <= first.end.x and first.position.y <= second.end.y and second.position.y <= first.end.y
	func update(plan: Dictionary) -> void:
		var id := int(plan.entity_id)
		for key: Vector2i in _keys_by_id.get(id,[]):
			_buckets[key].erase(id)
			if _buckets[key].is_empty(): _buckets.erase(key)
		if not _ranks.has(id): _ranks[id] = _ranks.size()
		_plans[id] = plan
		var keys := _keys(bounds(plan))
		_keys_by_id[id] = keys
		for key: Vector2i in keys:
			if not _buckets.has(key): _buckets[key] = {}
			_buckets[key][id] = true
	func query(plan: Dictionary) -> Array[Dictionary]:
		var rect := bounds(plan)
		var seen := {}
		for key: Vector2i in _keys(rect):
			for id: int in _buckets.get(key,{}):
				if overlaps(rect,bounds(_plans[id])): seen[id] = true
		var ids: Array = seen.keys()
		ids.sort_custom(func(a: int,b: int) -> bool: return int(_ranks[a]) < int(_ranks[b]))
		var result: Array[Dictionary] = []
		for id: int in ids: result.append(_plans[id])
		return result
