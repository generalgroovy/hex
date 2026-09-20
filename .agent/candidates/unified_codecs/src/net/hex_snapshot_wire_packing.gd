class_name HexSnapshotWirePacking
extends RefCounted


const CAST_ROW_SIZE := 33
const PRODUCT_ROW_SIZE := 28
const MAX_CELLS := 127
const MAX_CASTS := 64
const MAX_PRODUCTS := 32
const MAX_U16 := 65_535
const KEYS: Array[String] = [
	"schema", "topology_hash", "authority_hash", "header",
	"cast_ids", "casts", "cast_allocations",
	"product_ids", "products", "product_sources", "product_allocations",
	"cast_parts", "product_states", "pending", "sources", "exposure", "flow_carry", "metrics",
]


# Converts the detached validation codec into transport-sized typed lanes. The
# trusted caller supplies topology order; remote data never carries coordinates.
static func pack(detached: Dictionary, cell_count: int) -> Dictionary:
	if cell_count < 1 or cell_count > MAX_CELLS:
		return {}
	for name: String in ["topology_hash", "authority_hash"]:
		if typeof(detached.get(name)) != TYPE_STRING:
			return {}
	var header: Variant = _i32(detached.get("header"), 5)
	var casts_result: Variant = _rows(detached.get("casts"), CAST_ROW_SIZE)
	var products_result: Variant = _rows(detached.get("products"), PRODUCT_ROW_SIZE)
	if header == null or casts_result == null or products_result == null:
		return {}
	var cast_ids := _row_ids(detached.get("casts"), CAST_ROW_SIZE)
	var product_ids := _row_ids(detached.get("products"), PRODUCT_ROW_SIZE)
	var cast_plane: Variant = _dense_plane(detached.get("cast_cells"), cast_ids, cell_count)
	var product_plane: Variant = _dense_plane(detached.get("product_cells"), product_ids, cell_count)
	if cast_plane == null or product_plane == null:
		return {}
	var provenance: Variant = _pack_variable_rows(detached.get("product_sources"))
	var cast_parts: Variant = _pack_variable_rows(detached.get("cast_parts"))
	var product_states: Variant = _pack_variable_rows(detached.get("product_states"))
	if provenance == null or cast_parts == null or product_states == null:
		return {}
	var pending: Variant = _i32(detached.get("pending"))
	var sources: Variant = _i32(detached.get("sources"))
	var exposure: Variant = _i32(detached.get("exposure"))
	var carry: Variant = _i32(detached.get("flow_carry"))
	if pending == null or sources == null or exposure == null or carry == null:
		return {}
	var metrics_value: Variant = detached.get("metrics")
	if typeof(metrics_value) != TYPE_PACKED_INT64_ARRAY:
		return {}
	return {
		"schema": int(detached.get("schema", 0)),
		"topology_hash": String(detached.topology_hash),
		"authority_hash": String(detached.authority_hash),
		"header": header,
		"cast_ids": cast_ids, "casts": casts_result, "cast_allocations": cast_plane,
		"product_ids": product_ids, "products": products_result,
		"product_sources": provenance, "product_allocations": product_plane,
		"cast_parts": cast_parts, "product_states": product_states,
		"pending": pending, "sources": sources, "exposure": exposure,
		"flow_carry": carry, "metrics": (metrics_value as PackedInt64Array).duplicate(),
	}


static func unpack(packed: Dictionary, cell_count: int) -> Dictionary:
	if not _shape_valid(packed) or cell_count < 1 or cell_count > MAX_CELLS:
		return {}
	var cast_ids: PackedInt32Array = packed.cast_ids
	var product_ids: PackedInt32Array = packed.product_ids
	var casts: PackedInt32Array = packed.casts
	var products: PackedInt32Array = packed.products
	if casts.size() != cast_ids.size() * CAST_ROW_SIZE or products.size() != product_ids.size() * PRODUCT_ROW_SIZE:
		return {}
	if not _ids_match_rows(cast_ids, casts, CAST_ROW_SIZE) or not _ids_match_rows(product_ids, products, PRODUCT_ROW_SIZE):
		return {}
	var cast_cells: Variant = _sparse_plane(packed.cast_allocations, cast_ids, cell_count)
	var product_cells: Variant = _sparse_plane(packed.product_allocations, product_ids, cell_count)
	var product_sources: Variant = _unpack_variable_rows(packed.product_sources, product_ids)
	var cast_parts: Variant = _unpack_variable_rows(packed.cast_parts, cast_ids)
	var product_states: Variant = _unpack_variable_rows(packed.product_states, product_ids)
	if cast_cells == null or product_cells == null or product_sources == null or cast_parts == null or product_states == null:
		return {}
	return {
		"schema": int(packed.schema),
		"topology_hash": String(packed.topology_hash),
		"authority_hash": String(packed.authority_hash),
		"header": PackedInt64Array(Array(packed.header)),
		"casts": _unflatten(casts, CAST_ROW_SIZE),
		"cast_cells": cast_cells,
		"products": _unflatten(products, PRODUCT_ROW_SIZE),
		"product_sources": product_sources,
		"product_cells": product_cells,
		"cast_parts": cast_parts,
		"product_states": product_states,
		"pending": PackedInt64Array(Array(packed.pending)),
		"sources": PackedInt64Array(Array(packed.sources)),
		"exposure": PackedInt64Array(Array(packed.exposure)),
		"flow_carry": PackedInt64Array(Array(packed.flow_carry)),
		"metrics": (packed.metrics as PackedInt64Array).duplicate(),
	}


static func byte_size(value: Variant) -> int:
	# Transport uses Godot Variant serialization, including type headers and
	# four-byte padding. A sum of scalar payload sizes understates this bound.
	return var_to_bytes(value).size() if _wire_value_valid(value, 0) else -1


static func validate_structure(value: Dictionary, cell_count: int = -1) -> bool:
	if not _shape_valid(value) or (cell_count != -1 and (cell_count < 1 or cell_count > MAX_CELLS)):
		return false
	if int(value.schema) != 2 or (value.header as PackedInt32Array).size() != 5:
		return false
	var cast_ids: PackedInt32Array = value.cast_ids
	var product_ids: PackedInt32Array = value.product_ids
	var header: PackedInt32Array = value.header
	if cast_ids.size() > MAX_CASTS or product_ids.size() > MAX_PRODUCTS \
		or header[0] < 0 or header[1] not in [0, 1] or header[2] <= 0 or header[3] <= 0 or header[4] <= 0:
		return false
	if (value.casts as PackedInt32Array).size() != cast_ids.size() * CAST_ROW_SIZE or (value.products as PackedInt32Array).size() != product_ids.size() * PRODUCT_ROW_SIZE:
		return false
	if not _ids_match_rows(cast_ids, value.casts, CAST_ROW_SIZE) or not _ids_match_rows(product_ids, value.products, PRODUCT_ROW_SIZE):
		return false
	if cell_count == -1:
		var cast_cell_count := _plane_cell_count(value.cast_allocations, cast_ids.size())
		var product_cell_count := _plane_cell_count(value.product_allocations, product_ids.size())
		if cast_cell_count < -1 or product_cell_count < -1 or (cast_cell_count >= 0 and product_cell_count >= 0 and cast_cell_count != product_cell_count):
			return false
	elif _sparse_plane(value.cast_allocations, cast_ids, cell_count) == null or _sparse_plane(value.product_allocations, product_ids, cell_count) == null:
		return false
	return _unpack_variable_rows(value.product_sources, product_ids) != null \
		and _unpack_variable_rows(value.cast_parts, cast_ids) != null \
		and _unpack_variable_rows(value.product_states, product_ids) != null


# Returns -1 for a canonical empty plane, -2 for malformed data, otherwise the
# topology column count inferred solely for transport structure validation.
static func _plane_cell_count(value: PackedByteArray, id_count: int) -> int:
	if value.size() < 2:
		return -2
	var count := value.decode_u16(0)
	if count == 0:
		return -1 if value.size() == 2 else -2
	if count > id_count or (value.size() - 2) % count != 0:
		return -2
	var row_bytes := int((value.size() - 2) / count)
	if row_bytes < 4 or (row_bytes - 2) % 2 != 0:
		return -2
	var cells := int((row_bytes - 2) / 2)
	if cells < 1 or cells > MAX_CELLS:
		return -2
	var previous := -1
	for row: int in count:
		var row_index := value.decode_u16(2 + row * row_bytes)
		if row_index <= previous or row_index >= id_count:
			return -2
		previous = row_index
	return cells


static func _wire_value_valid(value: Variant, depth: int) -> bool:
	if depth > 8: return false
	match typeof(value):
		TYPE_INT, TYPE_BOOL, TYPE_STRING, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY:
			return true
		TYPE_ARRAY:
			for child: Variant in value:
				if not _wire_value_valid(child, depth + 1): return false
			return true
		TYPE_DICTIONARY:
			for key: Variant in value:
				if typeof(key) != TYPE_STRING or not _wire_value_valid(value[key], depth + 1): return false
			return true
	return false


static func _rows(value: Variant, width: int) -> Variant:
	if not value is Array:
		return null
	var result := PackedInt32Array()
	for row_value: Variant in value:
		var row: Variant = _i32(row_value, width)
		if row == null:
			return null
		result.append_array(row)
	return result


static func _row_ids(value: Variant, width: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	if not value is Array:
		return result
	for row_value: Variant in value:
		if typeof(row_value) != TYPE_PACKED_INT64_ARRAY or row_value.size() != width:
			return PackedInt32Array()
		result.append(int(row_value[0]))
	return result


static func _i32(value: Variant, exact_size: int = -1) -> Variant:
	if typeof(value) != TYPE_PACKED_INT64_ARRAY:
		return null
	var source: PackedInt64Array = value
	if exact_size >= 0 and source.size() != exact_size:
		return null
	var result := PackedInt32Array()
	for number: int in source:
		if number < -0x80000000 or number > 0x7fffffff:
			return null
		result.append(number)
	return result


static func _dense_plane(value: Variant, ids: PackedInt32Array, cell_count: int) -> Variant:
	if typeof(value) != TYPE_PACKED_INT64_ARRAY:
		return null
	var sparse: PackedInt64Array = value
	if sparse.size() % 3 != 0:
		return null
	var id_indices := {}
	for index: int in ids.size():
		if ids[index] <= 0 or id_indices.has(ids[index]):
			return null
		id_indices[ids[index]] = index
	var active_indices := {}
	for offset: int in range(0, sparse.size(), 3):
		if not id_indices.has(sparse[offset]): return null
		active_indices[int(id_indices[sparse[offset]])] = true
	var ordered: Array = active_indices.keys()
	ordered.sort()
	var result := PackedByteArray()
	var row_offsets := {}
	# Retained, already-consumed provenance ledgers own no allocation plane.
	# Encode only nonempty rows, preserving all their trusted cell columns.
	var row_bytes := 2 + cell_count * 2
	result.resize(2 + ordered.size() * row_bytes)
	result.encode_u16(0, ordered.size())
	for row: int in ordered.size():
		var index: int = ordered[row]
		var offset := 2 + row * row_bytes
		result.encode_u16(offset, index)
		row_offsets[index] = offset + 2
	for offset: int in range(0, sparse.size(), 3):
		var id: int = sparse[offset]
		var cell_index: int = sparse[offset + 1]
		var amount: int = sparse[offset + 2]
		if not id_indices.has(id) or cell_index < 0 or cell_index >= cell_count or amount <= 0 or amount > MAX_U16:
			return null
		var byte_offset: int = int(row_offsets[int(id_indices[id])]) + cell_index * 2
		if result.decode_u16(byte_offset) != 0:
			return null
		result.encode_u16(byte_offset, amount)
	return result


static func _sparse_plane(value: Variant, ids: PackedInt32Array, cell_count: int) -> Variant:
	if typeof(value) != TYPE_PACKED_BYTE_ARRAY:
		return null
	var plane: PackedByteArray = value
	if plane.size() < 2:
		return null
	var count := plane.decode_u16(0)
	var row_bytes := 2 + cell_count * 2
	if count > ids.size() or plane.size() != 2 + count * row_bytes: return null
	var result := PackedInt64Array()
	var previous_index := -1
	for row: int in count:
		var offset := 2 + row * row_bytes
		var row_index := plane.decode_u16(offset)
		if row_index <= previous_index or row_index >= ids.size(): return null
		previous_index = row_index
		var nonempty := false
		for cell_index: int in cell_count:
			var amount := plane.decode_u16(offset + 2 + cell_index * 2)
			if amount > 0:
				nonempty = true
				result.append_array(PackedInt64Array([ids[row_index], cell_index, amount]))
		if not nonempty: return null
	return result


static func _pack_variable_rows(value: Variant) -> Variant:
	if not value is Array:
		return null
	var result := PackedInt32Array()
	for row_value: Variant in value:
		var row: Variant = _i32(row_value)
		if row == null or row.size() < 1:
			return null
		result.append(row[0])
		result.append(row.size() - 1)
		for index: int in range(1, row.size()):
			result.append(row[index])
	return result


static func _unpack_variable_rows(values: PackedInt32Array, expected_ids: PackedInt32Array) -> Variant:
	var result: Array[PackedInt64Array] = []
	var offset := 0
	for expected_id: int in expected_ids:
		if offset + 2 > values.size() or values[offset] != expected_id:
			return null
		var count: int = values[offset + 1]
		offset += 2
		if count < 0 or offset + count > values.size():
			return null
		var row := PackedInt64Array([expected_id])
		for index: int in count:
			row.append(values[offset + index])
		result.append(row)
		offset += count
	return result if offset == values.size() else null


static func _unflatten(values: PackedInt32Array, width: int) -> Array[PackedInt64Array]:
	var result: Array[PackedInt64Array] = []
	for offset: int in range(0, values.size(), width):
		result.append(PackedInt64Array(Array(values.slice(offset, offset + width))))
	return result


static func _ids_match_rows(ids: PackedInt32Array, values: PackedInt32Array, width: int) -> bool:
	var previous := 0
	for index: int in ids.size():
		if ids[index] <= previous or values[index * width] != ids[index]:
			return false
		previous = ids[index]
	return true


static func _shape_valid(value: Dictionary) -> bool:
	if value.size() != KEYS.size():
		return false
	for key: String in KEYS:
		if not value.has(key):
			return false
	if typeof(value.schema) != TYPE_INT or typeof(value.topology_hash) != TYPE_STRING or typeof(value.authority_hash) != TYPE_STRING:
		return false
	for key: String in ["header", "cast_ids", "casts", "product_ids", "products", "product_sources", "cast_parts", "product_states", "pending", "sources", "exposure", "flow_carry"]:
		if typeof(value[key]) != TYPE_PACKED_INT32_ARRAY:
			return false
	return typeof(value.cast_allocations) == TYPE_PACKED_BYTE_ARRAY \
		and typeof(value.product_allocations) == TYPE_PACKED_BYTE_ARRAY \
		and typeof(value.metrics) == TYPE_PACKED_INT64_ARRAY
