extends RefCounted

# Experimental only. Keep the production whole-document conversion unchanged.
# Large, shallow Vector2i -> int32 leaves can be written without the two
# temporary Arrays per entry used by _stable. JSON still encodes every other
# value at its original depth. Tokens are accepted only when unique in the
# completed JSON; a collision takes the unchanged, callback-free fallback.
const CELL_MARKER := "__hex_canonical_cells__"
const TOKEN_PREFIX := "__hex_scalar_coordinate_leaf_"
const MIN_LEAF_ENTRIES := 8
const MAX_SOURCE_DEPTH := 12


static func lanes(world: RefCounted) -> Array:
	return [world.origin, world.current_tick, world.chemistry_enabled,
		world.next_cast_id, world.next_product_id, world.next_ground_part_id,
		CELL_MARKER, world.casts, world.products, world.pending, world.sources,
		world.exposure, world.flow_carry, world.metrics]


static func baseline_document(world: RefCounted) -> String:
	var stable: Array = []
	for value: Variant in lanes(world): stable.append(world._stable(value))
	return JSON.stringify(stable)


static func document(world: RefCounted) -> String:
	var values := lanes(world)
	# Admission never formats keys, calls methods on values, or caches authority.
	# Rejected inputs reach the original path before any user callback occurs.
	if admitted_leaf_count(values) <= 0: return baseline_document(world)
	var replacements: Array[String] = []
	var transformed: Variant = _stable_with_leaves(values, replacements)
	var encoded := JSON.stringify(transformed)
	for index: int in replacements.size():
		var token := JSON.stringify(_token(index))
		var start := encoded.find(token)
		if start < 0 or encoded.find(token, start + token.length()) >= 0:
			return baseline_document(world)
	# Every replacement consists solely of brackets, commas and signed decimal
	# integers, so none can introduce a token for another replacement.
	for index: int in replacements.size():
		encoded = encoded.replace(JSON.stringify(_token(index)), replacements[index])
	return encoded


static func admitted_leaf_count(value: Variant, depth: int = 0) -> int:
	if depth > MAX_SOURCE_DEPTH: return -1
	if value is Dictionary:
		if _coordinate_leaf(value): return 1
		var result := 0
		for key: Variant in value:
			var key_count := admitted_leaf_count(key, depth + 1)
			if key_count < 0: return -1
			var child_count := admitted_leaf_count(value[key], depth + 1)
			if child_count < 0: return -1
			result += key_count + child_count
		return result
	if value is Array:
		var result := 0
		for child: Variant in value:
			var count := admitted_leaf_count(child, depth + 1)
			if count < 0: return -1
			result += count
		return result
	if typeof(value) in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT,
		TYPE_STRING, TYPE_STRING_NAME, TYPE_VECTOR2I]: return 0
	return -1


static func admission_diagnostic(value: Variant, depth: int = 0, path: String = "lanes") -> Dictionary:
	# Untimed diagnostic only. Do not format opaque values even to name a path.
	if depth > MAX_SOURCE_DEPTH: return {"reason": "depth-limit", "path": path, "type": type_string(typeof(value)), "depth": depth}
	if value is Dictionary:
		if _coordinate_leaf(value): return {}
		for key: Variant in value:
			var rejected_key := admission_diagnostic(key, depth + 1, path + "/key")
			if not rejected_key.is_empty(): return rejected_key
			var label := str(key) if typeof(key) in [TYPE_STRING, TYPE_STRING_NAME, TYPE_INT] else "key-type-" + str(typeof(key))
			var rejected_child := admission_diagnostic(value[key], depth + 1, path + "/" + label)
			if not rejected_child.is_empty(): return rejected_child
		return {}
	if value is Array:
		for index: int in value.size():
			var rejected := admission_diagnostic(value[index], depth + 1, path + "/" + str(index))
			if not rejected.is_empty(): return rejected
		return {}
	if typeof(value) in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT,
		TYPE_STRING, TYPE_STRING_NAME, TYPE_VECTOR2I]: return {}
	return {"reason": "unsupported-type", "path": path, "type": type_string(typeof(value)), "depth": depth}


static func _coordinate_leaf(value: Dictionary) -> bool:
	if value.size() < MIN_LEAF_ENTRIES: return false
	for key: Variant in value:
		if not key is Vector2i: return false
		var amount: Variant = value[key]
		if typeof(amount) != TYPE_INT or amount < -2_147_483_648 or amount > 2_147_483_647: return false
	return true


static func _stable_with_leaves(value: Variant, replacements: Array[String]) -> Variant:
	if value is Vector2i: return [value.x, value.y]
	if value is Dictionary:
		if value.is_empty(): return []
		var keys: Array = _ordered_keys(value)
		if _coordinate_leaf(value):
			var rows := PackedStringArray()
			for key: Vector2i in keys:
				rows.append("[[" + str(key.x) + "," + str(key.y) + "]," + str(value[key]) + "]")
			var token := _token(replacements.size())
			replacements.append("[" + ",".join(rows) + "]")
			return token
		var result: Array = []
		for key: Variant in keys:
			result.append([_stable_with_leaves(key, replacements), _stable_with_leaves(value[key], replacements)])
		return result
	if value is Array:
		var result: Array = []
		for child: Variant in value: result.append(_stable_with_leaves(child, replacements))
		return result
	return value


static func _ordered_keys(value: Dictionary) -> Array:
	# Mechanically retained production ordering. This experiment changes the
	# leaf representation, not key ordering, including equal-formatted mixed keys.
	var keys: Array = value.keys()
	var string_keys := not keys.is_empty()
	for key: Variant in keys:
		if typeof(key) != TYPE_STRING:
			string_keys = false
			break
	if string_keys:
		keys.sort()
	else:
		var key_type := typeof(keys[0])
		var native_keys := key_type in [TYPE_INT, TYPE_VECTOR2I]
		if native_keys:
			for key: Variant in keys:
				if typeof(key) != key_type:
					native_keys = false
					break
		if native_keys:
			var texts: Array[String] = []
			var keys_by_text := {}
			for key: Variant in keys:
				var formatted := str(key)
				if keys_by_text.has(formatted):
					native_keys = false
					break
				texts.append(formatted)
				keys_by_text[formatted] = key
			if native_keys:
				texts.sort()
				keys.clear()
				for formatted: String in texts: keys.append(keys_by_text[formatted])
		if not native_keys:
			var formatted_keys := {}
			for key: Variant in keys: formatted_keys[key] = str(key)
			keys.sort_custom(func(a: Variant, b: Variant) -> bool: return String(formatted_keys[a]) < String(formatted_keys[b]))
	return keys


static func _token(index: int) -> String:
	return TOKEN_PREFIX + str(index) + "__"
