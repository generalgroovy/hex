extends HexChemistryWorld


# Test-only world clone whose only behavioral difference is the key-ordering
# implementation inside the existing public state_hash pipeline. Every hashed
# authority field is copied before timing; no source alias or cross-call cache is
# retained.
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


func _stable_hash_cells() -> Array:
	var formatted_keys: Array[String] = []
	var keys_by_text: Dictionary = {}
	for key: Variant in cells:
		# The optimization is deliberately limited to the production Vector2i
		# domain. Unsupported shapes retain the current method's behavior.
		if not key is Vector2i:
			return super._stable_hash_cells()
		var formatted: String = str(key)
		if keys_by_text.has(formatted):
			return super._stable_hash_cells()
		formatted_keys.append(formatted)
		keys_by_text[formatted] = key
	formatted_keys.sort()

	var result: Array = []
	var empty_cell: Dictionary = _new_empty_cell()
	for formatted: String in formatted_keys:
		var cell: Vector2i = keys_by_text[formatted]
		var record: Dictionary = cells[cell]
		var terrain: Variant = record.get("terrain")
		var elevation: Variant = record.get("elevation")
		var structure: Variant = record.get("structure")
		empty_cell.terrain = terrain
		empty_cell.elevation = elevation
		empty_cell.structure = structure
		if typeof(terrain) == TYPE_INT and typeof(elevation) == TYPE_INT and typeof(structure) == TYPE_INT and record == empty_cell:
			result.append([
				[cell.x, cell.y],
				[["elevation", elevation], ["structure", structure], ["terrain", terrain]],
			])
		else:
			var compact: Dictionary = {}
			for key: String in record:
				var value: Variant = record[key]
				if not value is Dictionary or not value.is_empty():
					compact[key] = value
			result.append([_stable(cell), _stable(compact)])
	return result
