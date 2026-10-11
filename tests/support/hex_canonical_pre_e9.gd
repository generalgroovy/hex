extends RefCounted

# Frozen semantic oracle for the protocol-56 projection before E9. Deliberately
# uses the original comparator, whole-document recursion and explicit framing,
# not the production canonical serializer, topology text, streaming or SHA helper.
# Reads full membership without requesting the writable compatibility .cells view.
static func state_bytes(world: RefCounted) -> PackedByteArray:
	var compact_cells: Dictionary = {}
	for cell: Vector2i in world.cell_keys():
		var record: Dictionary = world.cell_record(cell)
		var compact: Dictionary = {}
		for key: String in record:
			var value: Variant = record[key]
			if not value is Dictionary or not value.is_empty(): compact[key] = value
		compact_cells[cell] = compact
	var value: Array = [world.origin, world.current_tick, world.chemistry_enabled,
		world.next_cast_id, world.next_product_id, world.next_ground_part_id,
		compact_cells, world.casts, world.products, world.pending, world.sources,
		world.exposure, world.flow_carry, world.metrics]
	var payload: PackedByteArray = JSON.stringify(_stable(value)).to_utf8_buffer()
	var framed := PackedByteArray()
	framed.resize(8)
	framed.encode_s64(0, payload.size())
	framed.append_array(payload)
	return framed


static func state_hash(world: RefCounted) -> String:
	return hash_bytes(state_bytes(world))


static func hash_bytes(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK: return ""
	if context.update(bytes) != OK: return ""
	return context.finish().hex_encode()


static func _stable(value: Variant) -> Variant:
	if value is Vector2i: return [value.x, value.y]
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		var result: Array = []
		for key: Variant in keys: result.append([_stable(key), _stable(value[key])])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(_stable(item))
		return result
	return value
