class_name HexChemistrySnapshot
extends RefCounted

@warning_ignore_start("integer_division")

const World = preload("res://src/sim/hex/hex_chemistry_world.gd")
const Grid = preload("res://src/sim/hex/hex_grid.gd")
const Footprint = preload("res://src/sim/hex/hex_footprint.gd")
const StrengthLedger = preload("res://src/sim/combat/strength_budget.gd")
const CanonicalBytes = preload("res://src/sim/core/canonical_bytes.gd")

const SCHEMA_VERSION := 1
const MAX_ELIGIBLE_CELLS := 127
const MAX_CAST_CELL_ROWS := World.MAX_CASTS * MAX_ELIGIBLE_CELLS
const MAX_PRODUCT_CELL_ROWS := World.MAX_PRODUCTS * MAX_ELIGIBLE_CELLS
const MAX_TRACKED_ACTORS := 64
const MAX_FLOW_ROWS := World.MAX_PRODUCTS * MAX_TRACKED_ACTORS
# Detached local allocation guard. Transport/fragment limits are separate and
# this schema is not registered with SessionSnapshot or the network protocol.
const MAX_ENCODED_BYTES := 1_048_576
const MAX_ID := 1_999_999_999
const MAX_OWNER_ID := 10_000
const MAX_TICK := 1_999_999_999
const MAX_COUNTER := 9_000_000_000_000_000
const MAX_FLOW_CARRY_COMPONENT := 1_000_000_000

const CAST_ROW_SIZE := 33
const PRODUCT_ROW_SIZE := 28
const HEADER_SIZE := 4
const METRIC_NAMES: Array[String] = [
	"requested", "admitted", "refused", "deposited", "reactions",
	"modifiers", "matter_paid", "matter_consumed", "matter_expired",
	"exposure_queries",
]
const SNAPSHOT_KEYS: Array[String] = [
	"schema", "topology_hash", "authority_hash", "header", "casts",
	"cast_cells", "products", "product_sources", "product_cells",
	"pending", "sources", "exposure", "flow_carry", "metrics",
]


# Topology is intentionally absent. Cell coordinates and scenario-owned static
# fields come from the trusted target; allocation rows address their stable
# lexicographic indices and are accepted only under the matching fingerprint.
static func capture(world: HexChemistryWorld) -> Dictionary:
	if world == null:
		return {}
	var ordered_cells := _trusted_cells(world)
	if ordered_cells.is_empty():
		return {}
	var cell_indices := {}
	for index: int in ordered_cells.size():
		cell_indices[ordered_cells[index]] = index

	var cast_rows: Array[PackedInt64Array] = []
	var cast_cells := PackedInt64Array()
	for id: int in _sorted_int_keys(world.casts):
		var record: Dictionary = world.casts[id]
		var aim: Vector2i = record.get("aim", Vector2i.ZERO)
		var footprint_values := _encode_footprint(record.get("footprint", {}))
		var ledger: Dictionary = record.get("ledger", {})
		var has_ledger := not ledger.is_empty()
		var row := PackedInt64Array([
			id, int(record.get("owner", 0)), int(record.get("wire", 0)),
			int(record.get("element", 0)), int(record.get("strength", 0)),
			int(record.get("budget", 0)), int(record.get("unallocated", 0)),
			int(record.get("ground", 0)), int(record.get("consumed", 0)),
			int(record.get("expired", 0)), int(bool(record.get("paid", false))),
			int(record.get("source", 0)), int(bool(record.get("reacted", false))),
			int(record.get("created", 0)), int(record.get("expires", 0)),
			int(record.get("origin", Vector2i.ZERO).x), int(record.get("origin", Vector2i.ZERO).y),
			int(record.has("aim")), aim.x, aim.y,
		])
		row.append_array(footprint_values)
		row.append(int(has_ledger))
		row.append(int(ledger.get("remaining_strength", 0)))
		row.append(int(ledger.get("flight_quantity", 0)))
		row.append(int(ledger.get("deposited_quantity", 0)))
		row.append(int(ledger.get("consumed_quantity", 0)))
		row.append(int(ledger.get("expired_quantity", 0)))
		cast_rows.append(row)
		var allocations: Dictionary = record.get("cells", {})
		for cell: Vector2i in _sorted_cells(allocations.keys()):
			if not cell_indices.has(cell):
				return {}
			cast_cells.append_array(PackedInt64Array([id, int(cell_indices[cell]), int(allocations[cell])]))

	var product_rows: Array[PackedInt64Array] = []
	var product_sources: Array[PackedInt64Array] = []
	var product_cells := PackedInt64Array()
	for id: int in _sorted_int_keys(world.products):
		var product: Dictionary = world.products[id]
		var footprint_values := _encode_footprint(product.get("footprint", {}))
		var flow_aim: Vector2i = product.get("flow_aim", Vector2i.ZERO)
		var row := PackedInt64Array([
			id, int(product.get("recipe_wire_id", 0)), _material_code(String(product.get("material", ""))),
			int(product.get("strength", 0)), int(product.get("quantity", 0)),
			int(product.get("created", 0)), int(product.get("formation_tick", 0)),
			int(product.get("active_tick", 0)), int(product.get("decay_tick", 0)),
			int(product.get("expiry_tick", 0)), int(product.get("expires", 0)),
			int(product.get("intensity", 0)), int(bool(product.get("heated", false))),
			int(bool(product.get("cooled", false))), flow_aim.x, flow_aim.y,
			int(product.get("flow_units_per_second", 0)), int(product.get("common_wall_clearance", 0)),
			int(product.get("pulse_ms", 0)), int(product.get("pulse_damage", 0)),
			int(String(product.get("geometry_override", "")) == "medium_disk_64000"),
		])
		row.append_array(footprint_values)
		product_rows.append(row)
		var source_row := PackedInt64Array([id])
		for source_value: Variant in product.get("source_ids", []):
			source_row.append(int(source_value))
		product_sources.append(source_row)
		var allocations: Dictionary = product.get("cells", {})
		for cell: Vector2i in _sorted_cells(allocations.keys()):
			if not cell_indices.has(cell):
				return {}
			product_cells.append_array(PackedInt64Array([id, int(cell_indices[cell]), int(allocations[cell])]))

	var snapshot := {
		"schema": SCHEMA_VERSION,
		"topology_hash": _topology_hash(world, ordered_cells),
		"authority_hash": world.state_hash(),
		"header": PackedInt64Array([world.current_tick, int(world.chemistry_enabled), world.next_cast_id, world.next_product_id]),
		"casts": cast_rows,
		"cast_cells": cast_cells,
		"products": product_rows,
		"product_sources": product_sources,
		"product_cells": product_cells,
		"pending": _encode_pairs(world.pending),
		"sources": _encode_pairs(world.sources),
		"exposure": _encode_pairs(world.exposure),
		"flow_carry": _encode_flow(world.flow_carry),
		"metrics": _encode_metrics(world.metrics),
	}
	if encoded_size(snapshot) > MAX_ENCODED_BYTES:
		return {}
	var prepared := _prepare(snapshot, world)
	if prepared == null or prepared.state_hash() != world.state_hash():
		return {}
	return snapshot


# Rejection leaves target untouched. All parsing and cross-ledger validation is
# performed in a fresh world configured from trusted local topology.
static func restore(snapshot: Dictionary, target: HexChemistryWorld) -> bool:
	if target == null:
		return false
	var prepared := _prepare(snapshot, target)
	if prepared == null:
		return false
	var next_value_revision: int = target.value_revision + 1
	target.origin = prepared.origin
	target.cells = prepared.cells
	target.casts = prepared.casts
	target.products = prepared.products
	target.pending = prepared.pending
	target.sources = prepared.sources
	target.exposure = prepared.exposure
	target.flow_carry = prepared.flow_carry
	target.next_cast_id = prepared.next_cast_id
	target.next_product_id = prepared.next_product_id
	target.current_tick = prepared.current_tick
	target.chemistry_enabled = prepared.chemistry_enabled
	target.metrics = prepared.metrics
	target.value_revision = next_value_revision
	target._render_polygon_revision = -1
	target._render_polygons.clear()
	return true


static func validate(snapshot: Dictionary, trusted_topology: HexChemistryWorld) -> bool:
	return trusted_topology != null and _prepare(snapshot, trusted_topology) != null


static func snapshot_hash(snapshot: Dictionary) -> String:
	if not _snapshot_shape_valid(snapshot):
		return ""
	var bytes := PackedByteArray()
	CanonicalBytes.append_string(bytes, JSON.stringify(_ordered_snapshot(snapshot)))
	return CanonicalBytes.sha256_hex(bytes)


static func encoded_size(snapshot: Dictionary) -> int:
	if not _snapshot_shape_valid(snapshot):
		return -1
	return JSON.stringify(_ordered_snapshot(snapshot)).to_utf8_buffer().size()


static func _prepare(snapshot: Dictionary, topology: HexChemistryWorld) -> HexChemistryWorld:
	if not _snapshot_shape_valid(snapshot):
		return null
	var wire_size := encoded_size(snapshot)
	if wire_size < 0 or wire_size > MAX_ENCODED_BYTES:
		return null
	var ordered_cells := _trusted_cells(topology)
	if ordered_cells.is_empty() or snapshot.topology_hash != _topology_hash(topology, ordered_cells):
		return null
	if not _hash_string_valid(snapshot.authority_hash):
		return null

	var prepared := World.new()
	var configured: bool = prepared.configure_geometry(topology.origin, ordered_cells)
	if not configured:
		return null
	for cell: Vector2i in ordered_cells:
		for property_name: String in ["terrain", "elevation", "structure"]:
			prepared.cells[cell][property_name] = topology.cells[cell][property_name]

	var header: PackedInt64Array = snapshot.header
	if header.size() != HEADER_SIZE or not _in_range(header[0], 0, MAX_TICK) or not _is_flag(header[1]) \
		or not _in_range(header[2], 1, MAX_ID) or not _in_range(header[3], 1, MAX_ID):
		return null
	prepared.current_tick = header[0]
	prepared.chemistry_enabled = bool(header[1])
	prepared.next_cast_id = header[2]
	prepared.next_product_id = header[3]

	if not _decode_casts(snapshot.casts, prepared):
		return null
	if not _decode_cast_cells(snapshot.cast_cells, prepared, ordered_cells):
		return null
	if not _decode_products(snapshot.products, snapshot.product_sources, prepared):
		return null
	if not _decode_product_cells(snapshot.product_cells, prepared, ordered_cells):
		return null
	if not _decode_mappings(snapshot, prepared):
		return null
	if not _decode_metrics(snapshot.metrics, prepared):
		return null
	if not _validate_relations(prepared):
		return null
	if prepared.state_hash() != snapshot.authority_hash:
		return null
	return prepared


static func _decode_casts(rows: Array, prepared: HexChemistryWorld) -> bool:
	if rows.size() > World.MAX_CASTS:
		return false
	var previous_id := 0
	for row_value: Variant in rows:
		if typeof(row_value) != TYPE_PACKED_INT64_ARRAY:
			return false
		var row: PackedInt64Array = row_value
		if row.size() != CAST_ROW_SIZE:
			return false
		var id: int = row[0]
		if id <= previous_id or not _in_range(id, 1, MAX_ID):
			return false
		previous_id = id
		if not _in_range(row[1], 1, MAX_OWNER_ID) or not _in_range(row[2], 100, 999) \
			or row[3] not in [World.WATER, World.FIRE] or not _in_range(row[4], StrengthLedger.MIN_STRENGTH, StrengthLedger.MAX_STRENGTH):
			return false
		if row[5] != World.MATTER_PER_CAST:
			return false
		for quantity_index: int in [6, 7, 8, 9]:
			if not _in_range(row[quantity_index], 0, World.MATTER_PER_CAST):
				return false
		if row[6] + row[7] + row[8] + row[9] != World.MATTER_PER_CAST or not _is_flag(row[10]) or not _is_flag(row[12]):
			return false
		if not _in_range(row[11], 0, MAX_ID) or not _in_range(row[13], 0, MAX_TICK) or not _in_range(row[14], 0, MAX_TICK):
			return false
		if not _world_point_valid(Vector2i(row[15], row[16])) or not _is_flag(row[17]) or not _is_flag(row[27]):
			return false
		if row[17] == 1 and not _aim_valid(Vector2i(row[18], row[19])):
			return false
		var definition := CombatTuning.cast_definition(row[2])
		if int(definition.get("element_wire_id", 0)) != row[3] or int(definition.get("reaction_strength", 0)) != row[4] or not World.COVERAGE.has(World.family(row[2])):
			return false
		var footprint := _decode_footprint(row.slice(20, 27))
		if row[20] != 0 and footprint.is_empty():
			return false
		if row[20] == 0:
			for footprint_index: int in range(21, 27):
				if row[footprint_index] != 0:
					return false
		var record := {
			"id": id, "owner": row[1], "wire": row[2], "element": row[3], "strength": row[4],
			"budget": row[5], "unallocated": row[6], "ground": row[7], "consumed": row[8], "expired": row[9],
			"paid": bool(row[10]), "source": row[11], "reacted": bool(row[12]), "ledger": {}, "cells": {},
			"created": row[13], "expires": row[14], "origin": Vector2i(row[15], row[16]),
		}
		if row[17] == 1:
			record.aim = Vector2i(row[18], row[19])
		elif row[18] != 0 or row[19] != 0:
			return false
		if row[20] != 0:
			record.footprint = footprint
		if row[27] == 1:
			if not bool(record.paid) or row[11] <= 0 or row[17] != 1:
				return false
			var ledger := StrengthLedger.make(row[11], row[4], row[5])
			ledger.remaining_strength = row[28]
			ledger.flight_quantity = row[29]
			ledger.deposited_quantity = row[30]
			ledger.consumed_quantity = row[31]
			ledger.expired_quantity = row[32]
			if not StrengthLedger.validate(ledger) or row[6] != row[29] or row[7] != row[30] or row[8] != row[31] or row[9] != row[32]:
				return false
			record.ledger = ledger
		else:
			for ledger_index: int in range(28, CAST_ROW_SIZE):
				if row[ledger_index] != 0:
					return false
			if row[6] != World.MATTER_PER_CAST or row[7] != 0 or row[8] != 0 or row[9] != 0 \
				or row[11] != 0 or row[14] != 0 or row[17] != 0 or row[20] != 0 or bool(record.reacted):
				return false
		if row[7] > 0 and (row[20] == 0 or row[14] <= row[13]):
			return false
		prepared.casts[id] = record
	return true


static func _decode_cast_cells(values: PackedInt64Array, prepared: HexChemistryWorld, cells: Array[Vector2i]) -> bool:
	if values.size() % 3 != 0 or values.size() / 3 > MAX_CAST_CELL_ROWS:
		return false
	var seen := {}
	var previous := Vector2i(-1, -1)
	for offset: int in range(0, values.size(), 3):
		var id: int = values[offset]
		var cell_index: int = values[offset + 1]
		var amount: int = values[offset + 2]
		var order := Vector2i(id, cell_index)
		if (offset > 0 and (order.x < previous.x or (order.x == previous.x and order.y <= previous.y))) \
			or not prepared.casts.has(id) or not _in_range(cell_index, 0, cells.size() - 1) or not _in_range(amount, 1, World.MATTER_PER_CAST):
			return false
		previous = order
		var key := "%d:%d" % [id, cell_index]
		if seen.has(key):
			return false
		seen[key] = true
		var cell: Vector2i = cells[cell_index]
		var record: Dictionary = prepared.casts[id]
		record.cells[cell] = amount
		prepared.cells[cell][_cast_layer(record)][id] = amount
	return true


static func _decode_products(rows: Array, source_rows: Array, prepared: HexChemistryWorld) -> bool:
	if rows.size() > World.MAX_PRODUCTS or source_rows.size() != rows.size():
		return false
	var sources_by_product := {}
	var previous_source_id := 0
	for row_value: Variant in source_rows:
		if typeof(row_value) != TYPE_PACKED_INT64_ARRAY:
			return false
		var row: PackedInt64Array = row_value
		if row.size() < 3 or row.size() > World.MAX_CASTS + 1 or row[0] <= previous_source_id:
			return false
		previous_source_id = row[0]
		var historical: Array = []
		var seen := {}
		for index: int in range(1, row.size()):
			var source_id: int = row[index]
			if not _in_range(source_id, 1, MAX_ID) or seen.has(source_id):
				return false
			seen[source_id] = true
			historical.append(source_id)
		sources_by_product[row[0]] = historical

	var previous_id := 0
	for row_value: Variant in rows:
		if typeof(row_value) != TYPE_PACKED_INT64_ARRAY:
			return false
		var row: PackedInt64Array = row_value
		if row.size() != PRODUCT_ROW_SIZE:
			return false
		var id: int = row[0]
		if id <= previous_id or not _in_range(id, 1, MAX_ID) or not sources_by_product.has(id):
			return false
		previous_id = id
		var material := _material_name(row[2])
		if _recipe_material(row[1]) != material or material.is_empty():
			return false
		if not _in_range(row[3], 1, StrengthLedger.MAX_STRENGTH) or not _in_range(row[4], 1, World.MAX_CASTS * World.MATTER_PER_CAST):
			return false
		for tick_index: int in range(5, 11):
			if not _in_range(row[tick_index], 0, MAX_TICK):
				return false
		if row[6] != row[5] or row[7] != row[5] + World.MEDIUM_FORMATION_TICKS or row[8] < row[7] or row[8] >= row[9] or row[10] != row[9]:
			return false
		if row[8] > row[5] + World.MEDIUM_FORMATION_TICKS + World.MEDIUM_ACTIVE_TICKS or row[9] > row[5] + World.MEDIUM_FORMATION_TICKS + World.MEDIUM_ACTIVE_TICKS + World.MEDIUM_DECAY_TICKS:
			return false
		if not _in_range(row[11], 0, 1500) or not _is_flag(row[12]) or not _is_flag(row[13]) or not _aim_valid(Vector2i(row[14], row[15])):
			return false
		var historical_sources: Array = sources_by_product[id]
		if historical_sources.size() != 2 + row[12] + row[13]:
			return false
		var flood := row[1] == World.FLOOD_WIRE
		var conflagration := row[1] == World.CONFLAGRATION_WIRE
		if row[16] != (40_000 if flood else 0) or row[17] != (18_000 if flood else 0) \
			or row[18] != (600 if conflagration else 0) or row[19] != (8_000 if conflagration else 0) or row[20] != 1:
			return false
		var footprint := _decode_footprint(row.slice(21, 28))
		if footprint.is_empty() or String(footprint.get("kind", "")) != Footprint.KIND_DISK or int(footprint.radius) != World.MEDIUM_RADIUS:
			return false
		prepared.products[id] = {
			"id": id, "recipe_wire_id": row[1], "material": material, "strength": row[3],
			"source_ids": historical_sources, "footprint": footprint, "cells": {}, "quantity": row[4],
			"created": row[5], "formation_tick": row[6], "active_tick": row[7], "decay_tick": row[8],
			"expiry_tick": row[9], "expires": row[10], "intensity": row[11], "heated": bool(row[12]),
			"cooled": bool(row[13]), "flow_aim": Vector2i(row[14], row[15]), "flow_units_per_second": row[16],
			"common_wall_clearance": row[17], "pulse_ms": row[18], "pulse_damage": row[19],
			"geometry_override": "medium_disk_64000",
		}
	return sources_by_product.size() == prepared.products.size()


static func _decode_product_cells(values: PackedInt64Array, prepared: HexChemistryWorld, cells: Array[Vector2i]) -> bool:
	if values.size() % 3 != 0 or values.size() / 3 > MAX_PRODUCT_CELL_ROWS:
		return false
	var previous := Vector2i(-1, -1)
	for offset: int in range(0, values.size(), 3):
		var id: int = values[offset]
		var cell_index: int = values[offset + 1]
		var amount: int = values[offset + 2]
		var order := Vector2i(id, cell_index)
		if (offset > 0 and (order.x < previous.x or (order.x == previous.x and order.y <= previous.y))) \
			or not prepared.products.has(id) or not _in_range(cell_index, 0, cells.size() - 1) \
			or not _in_range(amount, 1, World.MAX_CASTS * World.MATTER_PER_CAST):
			return false
		previous = order
		var cell: Vector2i = cells[cell_index]
		var product: Dictionary = prepared.products[id]
		product.cells[cell] = amount
		prepared.cells[cell][product.material][id] = amount
	return true


static func _decode_mappings(snapshot: Dictionary, prepared: HexChemistryWorld) -> bool:
	var pending := _decode_pairs(snapshot.pending, World.MAX_CASTS, MAX_OWNER_ID, MAX_ID)
	var sources := _decode_pairs(snapshot.sources, World.MAX_CASTS, MAX_ID, MAX_ID)
	var exposure := _decode_pairs(snapshot.exposure, MAX_TRACKED_ACTORS, MAX_ID, World.EXPOSURE_CAP)
	if pending == null or sources == null or exposure == null:
		return false
	prepared.pending = pending
	prepared.sources = sources
	prepared.exposure = exposure

	var values: PackedInt64Array = snapshot.flow_carry
	if values.size() % 4 != 0 or values.size() / 4 > MAX_FLOW_ROWS:
		return false
	var previous := Vector2i(-1, -1)
	for offset: int in range(0, values.size(), 4):
		var product_id: int = values[offset]
		var actor_id: int = values[offset + 1]
		var order := Vector2i(product_id, actor_id)
		if offset > 0 and (order.x < previous.x or (order.x == previous.x and order.y <= previous.y)):
			return false
		previous = order
		if not prepared.products.has(product_id) or int(prepared.products[product_id].recipe_wire_id) != World.FLOOD_WIRE \
			or not _in_range(actor_id, 1, MAX_ID) or absi(values[offset + 2]) > MAX_FLOW_CARRY_COMPONENT or absi(values[offset + 3]) > MAX_FLOW_CARRY_COMPONENT:
			return false
		prepared.flow_carry["%d:%d" % [product_id, actor_id]] = Vector2i(values[offset + 2], values[offset + 3])
	return true


static func _decode_metrics(values: PackedInt64Array, prepared: HexChemistryWorld) -> bool:
	if values.size() != METRIC_NAMES.size():
		return false
	var decoded := {}
	for index: int in METRIC_NAMES.size():
		if not _in_range(values[index], 0, MAX_COUNTER):
			return false
		decoded[METRIC_NAMES[index]] = values[index]
	if int(decoded.requested) != int(decoded.admitted) + int(decoded.refused):
		return false
	if int(decoded.matter_paid) % World.MATTER_PER_CAST != 0:
		return false
	prepared.metrics = decoded
	return true


static func _validate_relations(world: HexChemistryWorld) -> bool:
	var maximum_cast_id := 0
	var live_unspent := 0
	for id: int in world.casts:
		maximum_cast_id = maxi(maximum_cast_id, id)
		var record: Dictionary = world.casts[id]
		var pending_id: int = int(world.pending.get(int(record.owner), 0))
		if int(record.source) == 0:
			if pending_id != id or not record.ledger.is_empty():
				return false
		else:
			if pending_id != 0 or int(world.sources.get(int(record.source), 0)) != id or not StrengthLedger.validate(record.ledger):
				return false
		if (record.ledger.is_empty() and int(record.unallocated) > 0) or (not record.ledger.is_empty() and int(record.ledger.remaining_strength) > 0):
			live_unspent += 1
	for owner: int in world.pending:
		var cast_id: int = world.pending[owner]
		if not world.casts.has(cast_id) or int(world.casts[cast_id].owner) != owner or int(world.casts[cast_id].source) != 0:
			return false
	for source_id: int in world.sources:
		var cast_id: int = world.sources[source_id]
		if not world.casts.has(cast_id) or int(world.casts[cast_id].source) != source_id:
			return false
	if world.next_cast_id <= maximum_cast_id or world.products.size() + live_unspent > World.MAX_PRODUCTS:
		return false
	var maximum_product_id := 0
	var stored_product_quantity := 0
	for id: int in world.products:
		maximum_product_id = maxi(maximum_product_id, id)
		stored_product_quantity += int(world.products[id].quantity)
	if world.next_product_id <= maximum_product_id:
		return false
	if stored_product_quantity > int(world.metrics.matter_consumed):
		return false
	return world.conservation_valid()


static func _trusted_cells(world: HexChemistryWorld) -> Array[Vector2i]:
	if world.cells.is_empty() or world.cells.size() > MAX_ELIGIBLE_CELLS or not _world_point_valid(world.origin):
		return []
	var result: Array[Vector2i] = []
	for key: Variant in world.cells:
		if not key is Vector2i:
			return []
		var cell: Vector2i = key
		var record_value: Variant = world.cells[cell]
		if not record_value is Dictionary:
			return []
		var record: Dictionary = record_value
		for property_name: String in ["terrain", "elevation", "structure"]:
			if not record.has(property_name) or typeof(record[property_name]) != TYPE_INT:
				return []
		for layer: String in ["water", "fire", "steam", "conflagration", "flood"]:
			if not record.has(layer) or not record[layer] is Dictionary:
				return []
		result.append(cell)
	result.sort_custom(Grid._cell_less)
	return result


static func _topology_hash(world: HexChemistryWorld, ordered_cells: Array[Vector2i]) -> String:
	var bytes := PackedByteArray()
	CanonicalBytes.append_i64(bytes, world.origin.x)
	CanonicalBytes.append_i64(bytes, world.origin.y)
	CanonicalBytes.append_i64(bytes, ordered_cells.size())
	for cell: Vector2i in ordered_cells:
		CanonicalBytes.append_i64(bytes, cell.x)
		CanonicalBytes.append_i64(bytes, cell.y)
		CanonicalBytes.append_i64(bytes, int(world.cells[cell].terrain))
		CanonicalBytes.append_i64(bytes, int(world.cells[cell].elevation))
		CanonicalBytes.append_i64(bytes, int(world.cells[cell].structure))
	return CanonicalBytes.sha256_hex(bytes)


static func _encode_footprint(value: Variant) -> PackedInt64Array:
	if not value is Dictionary or value.is_empty():
		return PackedInt64Array([0, 0, 0, 0, 0, 0, 0])
	var footprint: Dictionary = value
	if not Footprint.validate(footprint):
		return PackedInt64Array([0, 0, 0, 0, 0, 0, 0])
	if String(footprint.kind) == Footprint.KIND_DISK:
		return PackedInt64Array([1, footprint.center.x, footprint.center.y, footprint.radius, 0, 0, 0])
	if String(footprint.kind) == Footprint.KIND_SECTOR:
		return PackedInt64Array([2, footprint.start.x, footprint.start.y, footprint.aim.x, footprint.aim.y, footprint.range, footprint.cosine_squared])
	return PackedInt64Array([0, 0, 0, 0, 0, 0, 0])


static func _decode_footprint(values: PackedInt64Array) -> Dictionary:
	if values.size() != 7:
		return {}
	var result := {}
	if values[0] == 0:
		for index: int in range(1, 7):
			if values[index] != 0:
				return {}
		return result
	if values[0] == 1:
		if values[4] != 0 or values[5] != 0 or values[6] != 0:
			return {}
		result = Footprint.disk(Vector2i(values[1], values[2]), values[3])
	elif values[0] == 2:
		result = Footprint.sector(Vector2i(values[1], values[2]), Vector2i(values[3], values[4]), values[5], values[6])
	if result.is_empty() or not Footprint.validate(result):
		return {}
	return result


static func _encode_pairs(values: Dictionary) -> PackedInt64Array:
	var result := PackedInt64Array()
	for key: int in _sorted_int_keys(values):
		result.append_array(PackedInt64Array([key, int(values[key])]))
	return result


static func _decode_pairs(values: PackedInt64Array, maximum_rows: int, maximum_key: int, maximum_value: int) -> Variant:
	if values.size() % 2 != 0 or values.size() / 2 > maximum_rows:
		return null
	var result := {}
	var previous_key := 0
	for offset: int in range(0, values.size(), 2):
		if values[offset] <= previous_key or not _in_range(values[offset], 1, maximum_key) or not _in_range(values[offset + 1], 0, maximum_value):
			return null
		previous_key = values[offset]
		result[values[offset]] = values[offset + 1]
	return result


static func _encode_flow(values: Dictionary) -> PackedInt64Array:
	var rows: Array[PackedInt64Array] = []
	for key_value: Variant in values:
		var parts := String(key_value).split(":", false)
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or not values[key_value] is Vector2i:
			return PackedInt64Array()
		var carry: Vector2i = values[key_value]
		rows.append(PackedInt64Array([int(parts[0]), int(parts[1]), carry.x, carry.y]))
	rows.sort_custom(func(left: PackedInt64Array, right: PackedInt64Array) -> bool:
		return left[0] < right[0] if left[0] != right[0] else left[1] < right[1])
	var result := PackedInt64Array()
	for row: PackedInt64Array in rows:
		result.append_array(row)
	return result


static func _encode_metrics(metrics: Dictionary) -> PackedInt64Array:
	var result := PackedInt64Array()
	for name: String in METRIC_NAMES:
		result.append(int(metrics.get(name, 0)))
	return result


static func _snapshot_shape_valid(snapshot: Dictionary) -> bool:
	if snapshot.size() != SNAPSHOT_KEYS.size():
		return false
	for key: String in SNAPSHOT_KEYS:
		if not snapshot.has(key):
			return false
	if typeof(snapshot.schema) != TYPE_INT or snapshot.schema != SCHEMA_VERSION \
		or typeof(snapshot.topology_hash) != TYPE_STRING or typeof(snapshot.authority_hash) != TYPE_STRING:
		return false
	if typeof(snapshot.header) != TYPE_PACKED_INT64_ARRAY or typeof(snapshot.cast_cells) != TYPE_PACKED_INT64_ARRAY \
		or typeof(snapshot.product_cells) != TYPE_PACKED_INT64_ARRAY or typeof(snapshot.pending) != TYPE_PACKED_INT64_ARRAY \
		or typeof(snapshot.sources) != TYPE_PACKED_INT64_ARRAY or typeof(snapshot.exposure) != TYPE_PACKED_INT64_ARRAY \
		or typeof(snapshot.flow_carry) != TYPE_PACKED_INT64_ARRAY or typeof(snapshot.metrics) != TYPE_PACKED_INT64_ARRAY:
		return false
	return typeof(snapshot.casts) == TYPE_ARRAY and typeof(snapshot.products) == TYPE_ARRAY and typeof(snapshot.product_sources) == TYPE_ARRAY


static func _ordered_snapshot(snapshot: Dictionary) -> Array:
	var result: Array = []
	for key: String in SNAPSHOT_KEYS:
		result.append(snapshot[key])
	return result


static func _sorted_int_keys(values: Dictionary) -> Array[int]:
	var result: Array[int] = []
	for key: Variant in values:
		if typeof(key) != TYPE_INT:
			return []
		result.append(key)
	result.sort()
	return result


static func _sorted_cells(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value: Variant in values:
		if not value is Vector2i:
			return []
		result.append(value)
	result.sort_custom(Grid._cell_less)
	return result


static func _material_code(material: String) -> int:
	return {"steam": 1, "conflagration": 2, "flood": 3}.get(material, 0)


static func _material_name(code: int) -> String:
	return String({1: "steam", 2: "conflagration", 3: "flood"}.get(code, ""))


static func _recipe_material(wire_id: int) -> String:
	return String({World.STEAM_WIRE: "steam", World.CONFLAGRATION_WIRE: "conflagration", World.FLOOD_WIRE: "flood"}.get(wire_id, ""))


static func _cast_layer(record: Dictionary) -> String:
	return "water" if int(record.element) == World.WATER else "fire"


static func _in_range(value: int, minimum: int, maximum: int) -> bool:
	return value >= minimum and value <= maximum


static func _is_flag(value: int) -> bool:
	return value == 0 or value == 1


static func _aim_valid(aim: Vector2i) -> bool:
	return absi(aim.x) <= 1_000 and absi(aim.y) <= 1_000 and aim.x * aim.x + aim.y * aim.y > 0


static func _world_point_valid(point: Vector2i) -> bool:
	return absi(point.x) <= Grid.MAX_ABS_QUERY_COORDINATE and absi(point.y) <= Grid.MAX_ABS_QUERY_COORDINATE


static func _hash_string_valid(value: String) -> bool:
	if value.length() != 64:
		return false
	for character: String in value:
		if character not in "0123456789abcdef":
			return false
	return true
