extends RefCounted

# Experimental mirror of production; only dynamic-document assembly differs.
const DynamicLeaves = preload("res://tests/support/hex_dynamic_leaf_candidate.gd")

const Canonical = preload("res://src/sim/core/canonical_bytes.gd")
const Topology = preload("res://src/sim/hex/hex_cell_topology.gd")
const WORLD_PATH := "res://src/sim/hex/hex_chemistry_world.gd"
const CELL_MARKER := "__hex_canonical_cells__"

# One bounded, weakly held immutable template. A map/world replacement may miss
# this cache, but no live world or dynamic dictionary is retained here. All bytes
# below derive exclusively from the admitted package-owned topology.
static var _topology_ref: WeakRef
static var _blank_bytes := PackedByteArray()
static var _row_spans: Dictionary = {}
static var _world_script: Script


static func state_hash(world: RefCounted) -> String:
	var parts: Dictionary = _parts(world)
	if parts.is_empty(): return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK: return ""
	for bytes: PackedByteArray in parts.fragments:
		if context.update(bytes) != OK: return ""
	return context.finish().hex_encode()


# Diagnostic byte assembly follows the same fragments as streaming; the old
# world's _state_hash_bytes remains unchanged as a separate compatibility path.
static func canonical_bytes(world: RefCounted) -> PackedByteArray:
	var parts: Dictionary = _parts(world)
	var result := PackedByteArray()
	if parts.is_empty(): return result
	for bytes: PackedByteArray in parts.fragments: result.append_array(bytes)
	return result


static func _parts(world: RefCounted) -> Dictionary:
	# Check the actual script before calling any virtual admission/read helper.
	# An extension cannot opt itself into this path by returning a borrowed handle.
	if world == null or world.get_script() == null: return {}
	# Load lazily to avoid a preload cycle with the concrete world's helper.
	if _world_script == null: _world_script = ResourceLoader.load(WORLD_PATH) as Script
	if _world_script == null or world.get_script() != _world_script: return {}
	var topology: HexCellTopology = world.immutable_topology()
	if topology == null or topology.get_script() != Topology: return {}
	if not _prepare_template(topology): return {}
	# Opaque dynamic Dictionary keys can invoke Object._to_string during stable
	# conversion and re-enter another world's hash. Keep this invocation's admitted
	# template: cache replacement assigns new values and never mutates these bytes
	# or the read-only spans. No full-map duplicate is needed.
	var blank_bytes: PackedByteArray = _blank_bytes
	var row_spans: Dictionary = _row_spans
	var overrides: Dictionary = {}
	var quoted_names: Dictionary = {} # Per invocation, at most 64 escaped names.
	for cell: Vector2i in world.dynamic_cell_keys():
		var row: Dictionary = world.cell_record(cell)
		var compact: Dictionary = {}
		for key: Variant in row:
			if typeof(key) != TYPE_STRING: return {}
			var value: Variant = row[key]
			if key in ["terrain", "elevation", "structure"]:
				if not _int32(value): return {}
				compact[key] = value
				continue
			if not value is Dictionary: return {}
			for id: Variant in value:
				if not _int32(id) or not _int32(value[id]): return {}
			if not value.is_empty(): compact[key] = value
		if not row_spans.has(cell): return {}
		overrides[cell] = _cell_row_bytes(cell, compact, quoted_names)
	var document: String = DynamicLeaves.document(world)
	var marker := JSON.stringify(CELL_MARKER)
	var marker_offset := document.find(marker)
	if marker_offset < 0: return {}
	var prefix := document.substr(0, marker_offset).to_utf8_buffer()
	var suffix := document.substr(marker_offset + marker.length()).to_utf8_buffer()
	var byte_count := prefix.size() + blank_bytes.size() + suffix.size()
	var keys: Array = overrides.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return row_spans[a].x < row_spans[b].x)
	var fragments: Array[PackedByteArray] = []
	# Reserved first fragment is the legacy signed little-endian UTF-8 byte count,
	# not String.length(): opaque later lanes can contain multibyte characters.
	fragments.append(PackedByteArray())
	fragments.append(prefix)
	var cursor := 0
	for cell: Vector2i in keys:
		var span: Vector2i = row_spans[cell]
		var replacement: PackedByteArray = overrides[cell]
		fragments.append(blank_bytes.slice(cursor, span.x))
		fragments.append(replacement)
		byte_count += replacement.size() - span.y
		cursor = span.x + span.y
	# The common empty map borrows all immutable bytes without even slicing them.
	fragments.append(blank_bytes if cursor == 0 else blank_bytes.slice(cursor))
	fragments.append(suffix)
	var header := PackedByteArray()
	Canonical.append_i64(header, byte_count)
	fragments[0] = header
	return {"fragments": fragments}


static func _cell_row_bytes(cell: Vector2i, compact: Dictionary, quoted_names: Dictionary) -> PackedByteArray:
	# _parts admitted only String keys, int32 metadata and int32 owner/quantity
	# maps. Emit that exact shallow stable-pair JSON without recursive temporary
	# Arrays. No dynamic value survives this call; all values are read afresh.
	var names: Array = compact.keys()
	names.sort()
	var entries := PackedStringArray()
	for name: String in names:
		var quoted: String
		if quoted_names.has(name):
			quoted = quoted_names[name]
		else:
			quoted = JSON.stringify(name)
			if quoted_names.size() < 64: quoted_names[name] = quoted
		var value: Variant = compact[name]
		var encoded: String
		if value is Dictionary:
			var owners: Dictionary = value
			var pairs := PackedStringArray()
			if owners.size() == 1:
				for id: int in owners: pairs.append("[" + str(id) + "," + str(owners[id]) + "]")
			else:
				# Legacy ordering compares str(id), not the integer itself. Decimal
				# int32 spellings are unique, including zero and negative values.
				var ids := PackedStringArray()
				for id: int in owners: ids.append(str(id))
				ids.sort()
				for id: String in ids: pairs.append("[" + id + "," + str(owners[id.to_int()]) + "]")
			encoded = "[" + ",".join(pairs) + "]"
		else:
			encoded = str(value)
		entries.append("[" + quoted + "," + encoded + "]")
	return ("[[" + str(cell.x) + "," + str(cell.y) + "],[" + ",".join(entries) + "]]").to_utf8_buffer()


static func _prepare_template(topology: HexCellTopology) -> bool:
	if _topology_ref != null and _topology_ref.get_ref() == topology: return true
	var blank: String = topology.canonical_cells_json({})
	var spans: Dictionary = {}
	var cursor := 1
	for cell: Vector2i in topology.legacy_cells():
		# Admitted topology contains integer coordinates and exactly zero-valued
		# metadata. Its canonical text is ASCII, so character/byte spans coincide.
		var row := "[[%d,%d],[[\"elevation\",0],[\"structure\",0],[\"terrain\",0]]]" % [cell.x, cell.y]
		spans[cell] = Vector2i(cursor, row.length())
		cursor += row.length() + 1
	if cursor != blank.length(): return false
	spans.make_read_only()
	_blank_bytes = blank.to_utf8_buffer()
	_row_spans = spans
	_topology_ref = weakref(topology)
	return true


static func _int32(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= -2_147_483_648 and value <= 2_147_483_647
