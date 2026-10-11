extends RefCounted


# Diagnostic only: the immediately preceding comparator remains below the
# selected map size. Each nested map makes its own decision, without any cache.
static func stable(value: Variant, minimum_count: int) -> Variant:
	if value is Vector2i: return [value.x, value.y]
	if value is Dictionary:
		if value.is_empty(): return []
		var keys: Array = value.keys()
		var string_keys := true
		for key: Variant in keys:
			if typeof(key) != TYPE_STRING:
				string_keys = false
				break
		if string_keys:
			keys.sort()
		else:
			var key_type := typeof(keys[0])
			var native_keys := keys.size() >= minimum_count and key_type in [TYPE_INT, TYPE_VECTOR2I]
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
		var result: Array = []
		for key: Variant in keys: result.append([stable(key, minimum_count), stable(value[key], minimum_count)])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(stable(item, minimum_count))
		return result
	return value
