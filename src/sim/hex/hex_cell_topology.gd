class_name HexCellTopology
extends RefCounted

# Package-owned geometry. Construction is the only write phase. Borrowed Array
# and Dictionary values are recursively read-only; packed bytes are copied out.
# There is deliberately no API for adopting a caller's claimed-trusted handle.
var _data: Dictionary = {}
var _bytes := PackedByteArray()


static func build(requested_origin: Vector2i, ordered: Array[Vector2i]) -> HexCellTopology:
	var result := HexCellTopology.new()
	var metadata := {}
	var indices := {}
	var numeric := ordered.duplicate()
	var blank := {"terrain": 0, "elevation": 0, "structure": 0}
	blank.make_read_only()
	var string_cells: Dictionary = {}
	var strings: Array[String] = []
	for index: int in numeric.size():
		var cell: Vector2i = numeric[index]
		metadata[cell] = blank
		indices[cell] = index
		strings.append(str(cell))
		string_cells[str(cell)] = cell
	strings.sort()
	var legacy: Array = []
	var offsets := {}
	var texts := PackedStringArray()
	var cursor := 1
	for text: String in strings:
		var cell: Vector2i = string_cells[text]
		legacy.append(cell)
		var row := "[[%d,%d],[[\"elevation\",0],[\"structure\",0],[\"terrain\",0]]]" % [cell.x, cell.y]
		offsets[cell] = Vector2i(cursor, row.length())
		cursor += row.length() + 1
		texts.append(row)
	var bytes := PackedByteArray()
	bytes.resize((3 + numeric.size() * 5) * 8)
	bytes.encode_s64(0, requested_origin.x)
	bytes.encode_s64(8, requested_origin.y)
	bytes.encode_s64(16, numeric.size())
	var offset := 24
	for cell: Vector2i in numeric:
		bytes.encode_s64(offset, cell.x)
		bytes.encode_s64(offset + 8, cell.y)
		# Newly configured maps have exactly these three zero-valued metadata
		# lanes. Compatibility edits detach; they cannot change shared geometry.
		bytes.encode_s64(offset + 16, 0)
		bytes.encode_s64(offset + 24, 0)
		bytes.encode_s64(offset + 32, 0)
		offset += 40
	for value: Variant in [metadata, indices, numeric, legacy, offsets]: value.make_read_only()
	result._bytes = bytes
	result._data = {"origin": requested_origin, "metadata": metadata, "indices": indices,
		"numeric": numeric, "legacy": legacy, "offsets": offsets,
		"blank_json": "[" + ",".join(texts) + "]", "fingerprint": CanonicalBytes.sha256_hex(bytes)}
	result._data.make_read_only()
	return result


func origin_value() -> Vector2i:
	return _data.origin


func numeric_cells() -> Array[Vector2i]:
	return _data.numeric


func cell_indices() -> Dictionary:
	return _data.indices


func metadata() -> Dictionary:
	return _data.metadata


func legacy_cells() -> Array:
	return _data.legacy


func topology_bytes() -> PackedByteArray:
	return _bytes.duplicate()


func fingerprint() -> String:
	return _data.fingerprint


func canonical_cells_json(overrides: Dictionary) -> String:
	var blank: String = _data.blank_json
	if overrides.is_empty(): return blank
	var keys: Array = overrides.keys()
	var offsets: Dictionary = _data.offsets
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return offsets[a].x < offsets[b].x)
	var pieces := PackedStringArray()
	var cursor := 0
	for cell: Vector2i in keys:
		var span: Vector2i = offsets[cell]
		pieces.append(blank.substr(cursor, span.x - cursor))
		pieces.append(overrides[cell])
		cursor = span.x + span.y
	pieces.append(blank.substr(cursor))
	return "".join(pieces)
