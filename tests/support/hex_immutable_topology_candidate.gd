extends RefCounted

# NON-SHIPPING representation experiment. No production caller depends on this
# file. Admission/import deliberately retain production validation and all of its
# cost. Only clone_state() demonstrates warm shared-topology ownership; legacy
# projection/prepare still allocate every cell and are not a sparse codec.
const Codec = preload("res://src/net/hex_chemistry_snapshot.gd")
const Oracle = preload("res://tests/support/hex_stable_cells_candidate.gd")
const META: Array[String] = ["terrain", "elevation", "structure"]
const DYNAMIC: Array[String] = ["casts", "products", "pending", "sources", "exposure", "flow_carry", "metrics"]
const SCALARS: Array[String] = ["next_cast_id", "next_product_id", "next_ground_part_id", "current_tick", "render_revision", "value_revision", "chemistry_enabled"]


static func admit_topology(world: HexChemistryWorld, map_hash: String, definition_hash: String) -> Dictionary:
	if world == null or map_hash.is_empty() or definition_hash.is_empty(): return {}
	var ordered := Codec._trusted_cells(world)
	if ordered.is_empty(): return {}
	var indices := {}
	var metadata := {}
	var strings: Array[String] = []
	var by_string := {}
	for index: int in ordered.size():
		var cell: Vector2i = ordered[index]
		if absi(cell.x) > 256 or absi(cell.y) > 256 or not HexGrid._query_point_valid(HexGrid.center(cell) + world.origin): return {}
		indices[cell] = index
		var record := {}
		for key: String in META: record[key] = world.cells[cell][key]
		metadata[cell] = record
		strings.append(str(cell))
		by_string[str(cell)] = cell
	strings.sort()
	var legacy_order: Array[Vector2i] = []
	for key: String in strings: legacy_order.append(by_string[key])
	var bytes := Codec._topology_bytes(world, ordered)
	# PackedByteArray has no recursive read-only contract. Store immutable integer
	# elements and return a new packed buffer from topology_bytes(), never an alias.
	var byte_values: Array[int] = []
	for value: int in bytes: byte_values.append(value)
	var result := {
		"origin": world.origin, "numeric_cells": ordered, "indices": indices,
		"metadata": metadata, "legacy_hash_cells": legacy_order,
		"map_hash": map_hash, "definition_hash": definition_hash,
		"byte_values": byte_values, "fingerprint": CanonicalBytes.sha256_hex(bytes),
	}
	_freeze(result)
	return result


static func topology_bytes(topology: Dictionary) -> PackedByteArray:
	return PackedByteArray(topology.byte_values)


# A checked adapter from today's public mutable authority. Scanning current
# topology and producer roundtrip are intentionally NOT omitted from this cost.
static func import_world(world: HexChemistryWorld, topology: Dictionary, map_hash: String, definition_hash: String) -> Dictionary:
	if not _matches_topology(world, topology, map_hash, definition_hash): return {}
	if Codec.capture(world).is_empty(): return {}
	return _copy_dynamic(world, topology)


static func clone_state(state: Dictionary) -> Dictionary:
	if state.is_empty(): return {}
	var result := {"topology": state.topology, "materials": (state.materials as Dictionary).duplicate(true)}
	for field: String in DYNAMIC: result[field] = (state[field] as Dictionary).duplicate(true)
	for field: String in SCALARS: result[field] = state[field]
	return result


static func set_amount(state: Dictionary, cell: Vector2i, layer: String, owner: int, amount: int) -> bool:
	if state.is_empty() or not state.topology.indices.has(cell) or not HexChemistryWorld.material_layers().has(layer) or owner <= 0 or amount < 0: return false
	if not state.materials.has(cell): state.materials[cell] = {}
	if not state.materials[cell].has(layer): state.materials[cell][layer] = {}
	state.materials[cell][layer][owner] = amount
	return true


static func erase_amount(state: Dictionary, cell: Vector2i, layer: String, owner: int) -> void:
	if state.is_empty() or not state.materials.has(cell) or not state.materials[cell].has(layer): return
	state.materials[cell][layer].erase(owner)
	if state.materials[cell][layer].is_empty(): state.materials[cell].erase(layer)
	if state.materials[cell].is_empty(): state.materials.erase(cell)


# Compatibility/oracle boundary only. This is expressly O(topology + state),
# not the proposed eventual sparse production hash or sparse restore.
static func legacy_world(state: Dictionary) -> HexChemistryWorld:
	if state.is_empty(): return null
	var result := _blank_world(state.topology)
	for cell: Vector2i in state.materials:
		if not result.cells.has(cell): return null
		for layer: String in state.materials[cell]:
			result.cells[cell][layer] = (state.materials[cell][layer] as Dictionary).duplicate(true)
	for field: String in DYNAMIC: result.set(field, (state[field] as Dictionary).duplicate(true))
	for field: String in SCALARS: result.set(field, state[field])
	return result


static func legacy_bytes(state: Dictionary) -> PackedByteArray:
	var world := legacy_world(state)
	return PackedByteArray() if world == null else Oracle.frozen_original_bytes(world)


# Keeps strict production decoder/relations/hash checks. Returns a detached
# candidate only after complete success; no target exists to partially mutate.
static func prepare_snapshot(snapshot: Dictionary, topology: Dictionary, map_hash: String, definition_hash: String) -> Dictionary:
	if not _identity_matches(topology, map_hash, definition_hash): return {}
	var world := Codec._prepare(snapshot, _blank_world(topology))
	if world == null: return {}
	return _copy_dynamic(world, topology)


static func _blank_world(topology: Dictionary) -> HexChemistryWorld:
	var world := HexChemistryWorld.new()
	world.origin = topology.origin
	for cell: Vector2i in topology.numeric_cells:
		world.cells[cell] = (topology.metadata[cell] as Dictionary).duplicate(true)
	return world


static func _copy_dynamic(world: HexChemistryWorld, topology: Dictionary) -> Dictionary:
	var result := {"topology": topology, "materials": {}}
	for cell: Vector2i in world.cells:
		var layers := {}
		for layer: String in world.cells[cell]:
			if layer in META: continue
			var entries: Dictionary = world.cells[cell][layer]
			if not entries.is_empty(): layers[layer] = entries.duplicate(true)
		if not layers.is_empty(): result.materials[cell] = layers
	for field: String in DYNAMIC: result[field] = (world.get(field) as Dictionary).duplicate(true)
	for field: String in SCALARS: result[field] = world.get(field)
	return result


static func _identity_matches(topology: Dictionary, map_hash: String, definition_hash: String) -> bool:
	return not topology.is_empty() and topology.is_read_only() and topology.get("map_hash", "") == map_hash and topology.get("definition_hash", "") == definition_hash


static func _matches_topology(world: HexChemistryWorld, topology: Dictionary, map_hash: String, definition_hash: String) -> bool:
	if world == null or not _identity_matches(topology, map_hash, definition_hash): return false
	if world.origin != topology.origin or world.cells.size() != topology.numeric_cells.size(): return false
	var layers := HexChemistryWorld.material_layers()
	for cell: Variant in world.cells:
		if not cell is Vector2i or not topology.indices.has(cell) or not world.cells[cell] is Dictionary: return false
		var record: Dictionary = world.cells[cell]
		for key: String in META:
			if typeof(record.get(key)) != TYPE_INT or record[key] != topology.metadata[cell][key]: return false
		for layer: Variant in record:
			if typeof(layer) != TYPE_STRING: return false
			if layer in META: continue
			if not layers.has(layer) or not record[layer] is Dictionary: return false
			for owner: Variant in record[layer]:
				if typeof(owner) != TYPE_INT or owner <= 0 or typeof(record[layer][owner]) != TYPE_INT or record[layer][owner] < 0: return false
	return true


static func _freeze(value: Variant) -> void:
	if value is Dictionary:
		for child: Variant in value.values(): _freeze(child)
		value.make_read_only()
	elif value is Array:
		for child: Variant in value: _freeze(child)
		value.make_read_only()
