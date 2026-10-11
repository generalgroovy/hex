class_name HexWireDecodeCandidate
extends RefCounted


# Test-only exact fusion of the current public strict decode contract:
# validate_structure(packed, cell_count), followed by unpack(packed, cell_count).
# Leaf parsing remains owned by the production codec so this candidate cannot
# quietly acquire a different sparse or variable-row grammar.
const WirePacking = preload("res://src/net/hex_snapshot_wire_packing.gd")


static func composed_current(packed: Dictionary, cell_count: int) -> Dictionary:
	if not WirePacking.validate_structure(packed, cell_count):
		return {}
	return WirePacking.unpack(packed, cell_count)


static func strict_decode(packed: Dictionary, cell_count: int) -> Dictionary:
	if not WirePacking._shape_valid(packed) or cell_count < 1 or cell_count > WirePacking.MAX_TOPOLOGY_CELLS:
		return {}
	if int(packed.schema) != 3 or (packed.header as PackedInt32Array).size() != 5:
		return {}

	var header: PackedInt32Array = packed.header
	var cast_ids: PackedInt32Array = packed.cast_ids
	var casts: PackedInt32Array = packed.casts
	var product_ids: PackedInt32Array = packed.product_ids
	var products: PackedInt32Array = packed.products
	if cast_ids.size() > WirePacking.MAX_CASTS or product_ids.size() > WirePacking.MAX_PRODUCTS \
		or header[0] < 0 or header[1] not in [0, 1] \
		or header[2] <= 0 or header[3] <= 0 or header[4] <= 0:
		return {}
	if casts.size() != cast_ids.size() * WirePacking.CAST_ROW_SIZE \
		or products.size() != product_ids.size() * WirePacking.PRODUCT_ROW_SIZE:
		return {}
	if not WirePacking._ids_match_rows(cast_ids, casts, WirePacking.CAST_ROW_SIZE) \
		or not WirePacking._ids_match_rows(product_ids, products, WirePacking.PRODUCT_ROW_SIZE):
		return {}

	var cast_cells: Variant = WirePacking._unpack_sparse_plane(
		packed.cast_allocations, cast_ids, cell_count, WirePacking.MAX_CAST_ALLOCATION_ROWS
	)
	if cast_cells == null:
		return {}
	var product_cells: Variant = WirePacking._unpack_sparse_plane(
		packed.product_allocations, product_ids, cell_count, WirePacking.MAX_PRODUCT_ALLOCATION_ROWS
	)
	if product_cells == null:
		return {}
	var product_sources: Variant = WirePacking._unpack_variable_rows(packed.product_sources, product_ids)
	if product_sources == null:
		return {}
	var cast_parts: Variant = WirePacking._unpack_variable_rows(packed.cast_parts, cast_ids)
	if cast_parts == null:
		return {}
	var product_states: Variant = WirePacking._unpack_variable_rows(packed.product_states, product_ids)
	if product_states == null:
		return {}

	# Match unpack's insertion order and conversions exactly. Every nested row is
	# reconstructed, and metrics is duplicated, so callers receive fresh output.
	return {
		"schema": int(packed.schema),
		"topology_hash": String(packed.topology_hash),
		"authority_hash": String(packed.authority_hash),
		"header": PackedInt64Array(Array(header)),
		"casts": WirePacking._unflatten(casts, WirePacking.CAST_ROW_SIZE),
		"cast_cells": cast_cells,
		"products": WirePacking._unflatten(products, WirePacking.PRODUCT_ROW_SIZE),
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
