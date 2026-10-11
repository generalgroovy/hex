extends RefCounted


# Frozen immediately preceding dynamic canonical sorter. Keep this independent
# of HexChemistryWorld._stable and its new primitive-key admission. The older
# naive comparator in test_hex_canonical_sort remains a second byte oracle.
static func stable(value: Variant) -> Variant:
	if value is Vector2i:
		return [value.x, value.y]
	if value is Dictionary:
		if value.is_empty():
			return []
		var keys: Array = value.keys()
		var string_keys := not keys.is_empty()
		for key: Variant in keys:
			if typeof(key) != TYPE_STRING:
				string_keys = false
				break
		if string_keys:
			keys.sort()
		else:
			var formatted_keys := {}
			for key: Variant in keys:
				formatted_keys[key] = str(key)
			keys.sort_custom(func(a: Variant, b: Variant) -> bool: return String(formatted_keys[a]) < String(formatted_keys[b]))
		var result: Array = []
		for key: Variant in keys:
			result.append([stable(key), stable(value[key])])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(stable(item))
		return result
	return value
