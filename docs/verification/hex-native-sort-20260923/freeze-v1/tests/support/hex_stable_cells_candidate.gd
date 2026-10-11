extends RefCounted

# Test-only candidate plus an independent frozen copy of the current published
# state-hash projection and generic _stable behavior. No result or source
# reference survives a call.
const World = preload("res://src/sim/hex/hex_chemistry_world.gd")
const Canonical = preload("res://src/sim/core/canonical_bytes.gd")


static func candidate_hash(world: HexChemistryWorld) -> String:
	return Canonical.sha256_hex(candidate_bytes(world))


static func candidate_bytes(world: HexChemistryWorld) -> PackedByteArray:
	var stable_value: Array = []
	for value: Variant in [world.origin, world.current_tick, world.chemistry_enabled, world.next_cast_id, world.next_product_id, world.next_ground_part_id]:
		stable_value.append(World._stable(value))
	stable_value.append(_candidate_stable_cells(world))
	for value: Variant in [world.casts, world.products, world.pending, world.sources, world.exposure, world.flow_carry, world.metrics]:
		stable_value.append(World._stable(value))
	return _bytes_for_stable_value(stable_value)


static func frozen_original_hash(world: HexChemistryWorld) -> String:
	return Canonical.sha256_hex(frozen_original_bytes(world))


static func frozen_original_bytes(world: HexChemistryWorld) -> PackedByteArray:
	var compact_cells := {}
	var empty_cell := World._new_empty_cell()
	for cell: Vector2i in world.cells:
		var record: Dictionary = world.cells[cell]
		var empty_compact := {}
		for metadata_key: String in ["terrain", "elevation", "structure"]:
			var metadata_value: Variant = record.get(metadata_key)
			empty_cell[metadata_key] = metadata_value
			if not metadata_value is Dictionary or not metadata_value.is_empty():
				empty_compact[metadata_key] = metadata_value
		if record == empty_cell:
			compact_cells[cell] = empty_compact
			continue
		# Keep the frozen oracle's fallback loop independent from the candidate
		# helper so malformed/extras equivalence cannot pass through shared code.
		var compact := {}
		for key: String in record:
			var value: Variant = record[key]
			if not value is Dictionary or not value.is_empty():
				compact[key] = value
		compact_cells[cell] = compact
	var stable_value: Variant = _stable_original([
		world.origin, world.current_tick, world.chemistry_enabled,
		world.next_cast_id, world.next_product_id, world.next_ground_part_id,
		compact_cells, world.casts, world.products, world.pending, world.sources,
		world.exposure, world.flow_carry, world.metrics,
	])
	return _bytes_for_stable_value(stable_value)


static func _candidate_stable_cells(world: HexChemistryWorld) -> Array:
	var keys: Array = world.cells.keys()
	var formatted_keys := {}
	for key: Variant in keys:
		formatted_keys[key] = str(key)
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return String(formatted_keys[a]) < String(formatted_keys[b]))
	var result: Array = []
	var empty_cell := World._new_empty_cell()
	# Typed iteration/assignment deliberately matches the production method's
	# unsupported-shape behavior instead of making invalid keys/records accepted.
	for cell: Vector2i in keys:
		var record: Dictionary = world.cells[cell]
		var terrain: Variant = record.get("terrain")
		var elevation: Variant = record.get("elevation")
		var structure: Variant = record.get("structure")
		empty_cell.terrain = terrain
		empty_cell.elevation = elevation
		empty_cell.structure = structure
		if typeof(terrain) == TYPE_INT and typeof(elevation) == TYPE_INT and typeof(structure) == TYPE_INT and record == empty_cell:
			# This is exactly the generic _stable result for one Vector2i key and
			# the three alphabetically sorted integral metadata keys.
			result.append([
				[cell.x, cell.y],
				[["elevation", elevation], ["structure", structure], ["terrain", terrain]],
			])
		else:
			# Extras, malformed metadata, missing layers, and all nonempty records
			# retain the published projection and production generic _stable path.
			result.append([World._stable(cell), World._stable(_candidate_compact_record(record))])
	return result


static func _candidate_compact_record(record: Dictionary) -> Dictionary:
	var compact := {}
	# Typed String iteration matches the published production fallback exactly;
	# unsupported non-String record keys are not made into accepted inputs.
	for key: String in record:
		var value: Variant = record[key]
		if not value is Dictionary or not value.is_empty():
			compact[key] = value
	return compact


static func _stable_original(value: Variant) -> Variant:
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
			result.append([_stable_original(key), _stable_original(value[key])])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_stable_original(item))
		return result
	return value


static func _bytes_for_stable_value(stable_value: Variant) -> PackedByteArray:
	var bytes := PackedByteArray()
	Canonical.append_string(bytes, JSON.stringify(stable_value))
	return bytes
