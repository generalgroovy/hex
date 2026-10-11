extends HexChemistryWorld


const INT32_MIN := -2_147_483_648
const INT32_MAX := 2_147_483_647


# Test-only detached clone. No authority reference or cross-call data is retained.
static func from_world(source: HexChemistryWorld) -> HexChemistryWorld:
	if source == null:
		return null
	var candidate: HexChemistryWorld = new()
	candidate.origin = source.origin
	candidate.current_tick = source.current_tick
	candidate.chemistry_enabled = source.chemistry_enabled
	candidate.next_cast_id = source.next_cast_id
	candidate.next_product_id = source.next_product_id
	candidate.next_ground_part_id = source.next_ground_part_id
	candidate.cells = source.cells.duplicate(true)
	candidate.casts = source.casts.duplicate(true)
	candidate.products = source.products.duplicate(true)
	candidate.pending = source.pending.duplicate(true)
	candidate.sources = source.sources.duplicate(true)
	candidate.exposure = source.exposure.duplicate(true)
	candidate.flow_carry = source.flow_carry.duplicate(true)
	candidate.metrics = source.metrics.duplicate(true)
	return candidate


func _state_hash_bytes() -> PackedByteArray:
	var keys: Array = cells.keys()
	var formatted_keys: Array[String] = []
	var keys_by_text: Dictionary = {}
	for key: Variant in keys:
		# Preserve the current production behavior for every unsupported/colliding
		# key shape rather than creating another accepted hash domain.
		if not key is Vector2i:
			return super._state_hash_bytes()
		var formatted: String = str(key)
		if keys_by_text.has(formatted):
			return super._state_hash_bytes()
		formatted_keys.append(formatted)
		keys_by_text[formatted] = key
	formatted_keys.sort()

	var cell_parts := PackedStringArray()
	cell_parts.append("[")
	var first := true
	var empty_cell: Dictionary = _new_empty_cell()
	for formatted: String in formatted_keys:
		var cell: Vector2i = keys_by_text[formatted]
		var record: Dictionary = cells[cell]
		if _is_int32_empty_record(record, empty_cell):
			if not first:
				cell_parts.append(",")
			first = false
			cell_parts.append(_empty_cell_json(cell, record))
			continue
		# Per-entry JSON has a shallower recursion context than the production
		# whole-document call. Keep it strictly within the ordinary shallow cell
		# schema; arbitrary/malformed/deep authority delegates the entire call.
		if not _is_bounded_ordinary_record(record, empty_cell):
			return super._state_hash_bytes()
		if not first:
			cell_parts.append(",")
		first = false
		cell_parts.append(JSON.stringify(_stable_cell_projection(cell, record)))
	cell_parts.append("]")

	var prefix: Array = []
	for value: Variant in [origin, current_tick, chemistry_enabled, next_cast_id, next_product_id, next_ground_part_id]:
		prefix.append(_stable(value))
	var suffix: Array = []
	for value: Variant in [casts, products, pending, sources, exposure, flow_carry, metrics]:
		suffix.append(_stable(value))
	var prefix_json: String = JSON.stringify(prefix)
	var suffix_json: String = JSON.stringify(suffix)
	var document_parts := PackedStringArray()
	document_parts.append(prefix_json.substr(0, prefix_json.length() - 1))
	document_parts.append(",")
	document_parts.append("".join(cell_parts))
	document_parts.append(",")
	document_parts.append(suffix_json.substr(1))
	var bytes := PackedByteArray()
	CanonicalBytes.append_string(bytes, "".join(document_parts))
	return bytes


func _is_bounded_ordinary_record(record: Dictionary, empty_cell: Dictionary) -> bool:
	if record.size() != empty_cell.size():
		return false
	for expected_key: String in empty_cell:
		if not record.has(expected_key):
			return false
	for metadata_key: String in ["terrain", "elevation", "structure"]:
		var metadata: Variant = record[metadata_key]
		if typeof(metadata) != TYPE_INT or int(metadata) < INT32_MIN or int(metadata) > INT32_MAX:
			return false
	for key: String in record:
		if key in ["terrain", "elevation", "structure"]:
			continue
		var layer: Variant = record[key]
		if not layer is Dictionary:
			return false
		for part_id: Variant in layer:
			var amount: Variant = layer[part_id]
			if typeof(part_id) != TYPE_INT or typeof(amount) != TYPE_INT:
				return false
			if int(part_id) < INT32_MIN or int(part_id) > INT32_MAX or int(amount) < INT32_MIN or int(amount) > INT32_MAX:
				return false
	return true


func _is_int32_empty_record(record: Dictionary, empty_cell: Dictionary) -> bool:
	var terrain: Variant = record.get("terrain")
	var elevation: Variant = record.get("elevation")
	var structure: Variant = record.get("structure")
	if typeof(terrain) != TYPE_INT or typeof(elevation) != TYPE_INT or typeof(structure) != TYPE_INT:
		return false
	if int(terrain) < INT32_MIN or int(terrain) > INT32_MAX:
		return false
	if int(elevation) < INT32_MIN or int(elevation) > INT32_MAX:
		return false
	if int(structure) < INT32_MIN or int(structure) > INT32_MAX:
		return false
	empty_cell.terrain = terrain
	empty_cell.elevation = elevation
	empty_cell.structure = structure
	return record == empty_cell


func _empty_cell_json(cell: Vector2i, record: Dictionary) -> String:
	# Punctuation and field names are fixed. Every integer is still formatted by
	# Godot's JSON implementation; general strings never use handwritten escaping.
	return "[[%s,%s],[[\"elevation\",%s],[\"structure\",%s],[\"terrain\",%s]]]" % [
		JSON.stringify(cell.x),
		JSON.stringify(cell.y),
		JSON.stringify(record.elevation),
		JSON.stringify(record.structure),
		JSON.stringify(record.terrain),
	]


func _stable_cell_projection(cell: Vector2i, record: Dictionary) -> Array:
	var compact: Dictionary = {}
	for key: String in record:
		var value: Variant = record[key]
		if not value is Dictionary or not value.is_empty():
			compact[key] = value
	return [_stable(cell), _stable(compact)]
