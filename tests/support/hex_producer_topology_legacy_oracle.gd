extends RefCounted

# Pre-bridge orchestration/topology oracle, with explicit protocol60 schema5 field migration.
# Source hashes at extraction: chemistry dfaed467ac6e9d985ab844b1bb15be41601e8b7cc9ded874cb70fb2664dd59e1
# world 2143b4748239ab315db4f676a84011cf45999ce7b29e306da5e7e48a1a986469
# Low-level typed lane codecs, world hash and collision cloning are intentionally
# shared current-schema dependencies. No candidate context/helper is called here.
const Codec = preload("res://src/net/hex_chemistry_snapshot.gd")
const Net = preload("res://src/net/hex_world_snapshot.gd")
const World = preload("res://src/sim/hex/hex_chemistry_world.gd")
const WirePacking = preload("res://src/net/hex_snapshot_wire_packing.gd")
const DynamicCollision = preload("res://src/sim/hex/hex_collision_world.gd")


static func trusted_cells(world: HexChemistryWorld) -> Array[Vector2i]:
	if world.cells.is_empty() or world.cells.size() > Codec.MAX_TOPOLOGY_CELLS or not Codec._world_point_valid(world.origin):
		return []
	var result: Array[Vector2i] = []
	var material_layers: Array[String] = World.material_layers()
	for key: Variant in world.cells:
		if not key is Vector2i:
			return []
		var cell: Vector2i = key
		var record_value: Variant = world.cells[cell]
		if not record_value is Dictionary:
			return []
		var record: Dictionary = record_value
		# Exact three-key metadata records need no temporary comparison dictionary.
		# get() yields null for missing keys, so all old type/missing checks remain.
		if typeof(record.get("terrain")) != TYPE_INT or typeof(record.get("elevation")) != TYPE_INT \
			or typeof(record.get("structure")) != TYPE_INT:
			return []
		if record.size() == 3:
			result.append(cell)
			continue
		for layer: String in material_layers:
			if record.has(layer) and not record[layer] is Dictionary:
				return []
		result.append(cell)
	result.sort() # Native Vector2i order is the same x-then-y canonical order.
	return result


static func topology_bytes(world: HexChemistryWorld, ordered_cells: Array[Vector2i]) -> PackedByteArray:
	var bytes := PackedByteArray()
	# Exact little-endian canonical bytes with one allocation, not six grows and
	# interpreted helper calls per cell. Public producer/incoming validation stays.
	bytes.resize((3 + ordered_cells.size() * 5) * 8)
	bytes.encode_s64(0, world.origin.x)
	bytes.encode_s64(8, world.origin.y)
	bytes.encode_s64(16, ordered_cells.size())
	var offset := 24
	for cell: Vector2i in ordered_cells:
		var record: Dictionary = world.cells[cell]
		bytes.encode_s64(offset, cell.x)
		bytes.encode_s64(offset + 8, cell.y)
		bytes.encode_s64(offset + 16, int(record.terrain))
		bytes.encode_s64(offset + 24, int(record.elevation))
		bytes.encode_s64(offset + 32, int(record.structure))
		offset += 40
	return bytes


static func chemistry_capture(world: HexChemistryWorld) -> Dictionary:
	if world == null:
		return {}
	var ordered_cells := trusted_cells(world)
	if ordered_cells.is_empty():
		return {}
	var cell_indices := {}
	for index: int in ordered_cells.size():
		cell_indices[ordered_cells[index]] = index

	var cast_rows: Array[PackedInt64Array] = []
	var cast_cells := PackedInt64Array()
	var cast_parts: Array[PackedInt64Array] = []
	for id: int in Codec._sorted_int_keys(world.casts):
		var record: Dictionary = world.casts[id]
		var aim: Vector2i = record.get("aim", Vector2i.ZERO)
		var footprint_values := Codec._encode_footprint(record.get("footprint", {}))
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
		row.append(int(record.get("element_mask", 0)))
		cast_rows.append(row)
		var allocations: Dictionary = record.get("cells", {})
		for cell: Vector2i in Codec._sorted_cells(allocations.keys()):
			if not cell_indices.has(cell):
				return {}
			if int(allocations[cell]) > 0:
				cast_cells.append_array(PackedInt64Array([id, int(cell_indices[cell]), int(allocations[cell])]))
		var encoded_parts := Codec._encode_cast_parts(record, cell_indices)
		if encoded_parts.is_empty():
			return {}
		cast_parts.append(encoded_parts)

	var product_rows: Array[PackedInt64Array] = []
	var product_sources: Array[PackedInt64Array] = []
	var product_cells := PackedInt64Array()
	var product_states: Array[PackedInt64Array] = []
	for id: int in Codec._sorted_int_keys(world.products):
		var product: Dictionary = world.products[id]
		var footprint_values := Codec._encode_footprint(product.get("footprint", {}))
		var flow_aim: Vector2i = product.get("flow_aim", Vector2i.ZERO)
		var row := PackedInt64Array([
			id, int(product.get("recipe_wire_id", 0)), Codec._material_code(String(product.get("material", ""))),
			int(product.get("strength", 0)), int(product.get("quantity", 0)),
			int(product.get("created", 0)), int(product.get("formation_tick", 0)),
			int(product.get("active_tick", 0)), int(product.get("decay_tick", 0)),
			int(product.get("expiry_tick", 0)), int(product.get("expires", 0)),
			int(product.get("intensity", 0)), int(bool(product.get("heated", false))),
			int(bool(product.get("cooled", false))), flow_aim.x, flow_aim.y,
			int(product.get("flow_units_per_second", 0)), int(product.get("common_wall_clearance", 0)),
			int(product.get("pulse_ms", 0)), int(product.get("pulse_damage", 0)),
			int(String(product.get("geometry_override", "")) == "whole_hex"),
		])
		row.append_array(footprint_values)
		row.append_array(PackedInt64Array([int(product.get("element_mask", 0)), int(product.get("ancestry_created_tick", -1)), int(product.get("funded_strength", 0)), int(product.get("damage_budget_remaining", -1))]))
		product_rows.append(row)
		var source_row := PackedInt64Array([id])
		var funding_value: Variant = product.get("source_funding")
		if typeof(funding_value) != TYPE_PACKED_INT64_ARRAY: return {}
		source_row.append_array(funding_value)
		product_sources.append(source_row)
		var allocations: Dictionary = product.get("cells", {})
		for cell: Vector2i in Codec._sorted_cells(allocations.keys()):
			if not cell_indices.has(cell):
				return {}
			if int(allocations[cell]) > 0:
				product_cells.append_array(PackedInt64Array([id, int(cell_indices[cell]), int(allocations[cell])]))
		var encoded_state := Codec._encode_product_state(product, cell_indices)
		if encoded_state.is_empty():
			return {}
		product_states.append(encoded_state)

	var snapshot := {
		"schema": Codec.SCHEMA_VERSION,
		"topology_hash": topology_hash(world, ordered_cells),
		"authority_hash": world.state_hash(),
		"header": PackedInt64Array([world.current_tick, int(world.chemistry_enabled), world.next_cast_id, world.next_product_id, world.next_ground_part_id]),
		"casts": cast_rows,
		"cast_cells": cast_cells,
		"products": product_rows,
		"product_sources": product_sources,
		"product_cells": product_cells,
		"cast_parts": cast_parts,
		"product_states": product_states,
		"pending": Codec._encode_pairs(world.pending),
		"sources": Codec._encode_pairs(world.sources),
		"exposure": Codec._encode_pairs(world.exposure),
		"flow_carry": Codec._encode_flow(world.flow_carry),
		"metrics": Codec._encode_metrics(world.metrics),
	}
	if Codec.encoded_size(snapshot) > Codec.MAX_ENCODED_BYTES:
		return {}
	return snapshot


# Rejection leaves target untouched. All parsing and cross-ledger validation is
# performed in a fresh world configured from trusted local topology.


static func chemistry_prepare(snapshot: Dictionary, topology: HexChemistryWorld) -> HexChemistryWorld:
	if not Codec._snapshot_shape_valid(snapshot):
		return null
	var wire_size := Codec.encoded_size(snapshot)
	if wire_size < 0 or wire_size > Codec.MAX_ENCODED_BYTES:
		return null
	var ordered_cells := trusted_cells(topology)
	if ordered_cells.is_empty():
		return null
	var topology_bytes := topology_bytes(topology, ordered_cells)
	if snapshot.topology_hash != CanonicalBytes.sha256_hex(topology_bytes):
		return null
	if not Codec._hash_string_valid(snapshot.authority_hash):
		return null

	var prepared := Codec._copy_trusted_geometry(topology, ordered_cells, topology_bytes)
	if prepared == null:
		return null

	var header: PackedInt64Array = snapshot.header
	if header.size() != Codec.HEADER_SIZE or not Codec._in_range(header[0], 0, Codec.MAX_TICK) or not Codec._is_flag(header[1]) \
		or not Codec._in_range(header[2], 1, Codec.MAX_ID) or not Codec._in_range(header[3], 1, Codec.MAX_ID):
		return null
	prepared.current_tick = header[0]
	prepared.chemistry_enabled = bool(header[1])
	prepared.next_cast_id = header[2]
	prepared.next_product_id = header[3]
	if not Codec._in_range(header[4], 1, Codec.MAX_ID):
		return null
	prepared.next_ground_part_id = header[4]

	if not Codec._decode_casts(snapshot.casts, prepared):
		return null
	if not Codec._decode_cast_cells(snapshot.cast_cells, prepared, ordered_cells):
		return null
	if not Codec._decode_cast_parts(snapshot.cast_parts, prepared, ordered_cells):
		return null
	if not Codec._decode_products(snapshot.products, snapshot.product_sources, prepared):
		return null
	if not Codec._decode_product_cells(snapshot.product_cells, prepared, ordered_cells):
		return null
	if not Codec._decode_product_states(snapshot.product_states, prepared, ordered_cells):
		return null
	if not Codec._decode_mappings(snapshot, prepared):
		return null
	if not Codec._decode_metrics(snapshot.metrics, prepared):
		return null
	if not Codec._validate_relations(prepared):
		return null
	if prepared.state_hash() != snapshot.authority_hash:
		return null
	return prepared


static func topology_hash(world: HexChemistryWorld, ordered: Array[Vector2i]) -> String:
	return CanonicalBytes.sha256_hex(topology_bytes(world, ordered))


static func capture(world: SimWorld) -> Dictionary:
	if not Net._trusted_world_valid(world):
		return {}
	# The complete outer prepare() below validates this deterministic chemistry
	# encoding in trusted topology, so do not pay for the nested chemistry-only
	# reconstruction here. Incoming paths still use the public strict validators.
	var detached := chemistry_capture(world.hex_court)
	if detached.is_empty():
		return {}
	# The producer just computed this from live chemistry. No mutation or re-entry
	# occurs before the outer canonical bytes are assembled below.
	var verified_hex_hash: String = String(detached.authority_hash)
	var packed_hex := WirePacking.pack(detached, world.hex_court.cells.size())
	if packed_hex.is_empty():
		return {}

	var player_values := PackedInt32Array()
	var ordered_players: Array[PlayerState] = world.players.duplicate()
	ordered_players.sort_custom(func(left: PlayerState, right: PlayerState) -> bool: return left.entity_id < right.entity_id)
	for state: PlayerState in ordered_players:
		var values := state.canonical_values()
		if values.size() != Net.PLAYER_VALUE_COUNT or not Net._valid_player_values(values):
			return {}
		player_values.append_array(PackedInt32Array(Array(values)))

	var projectile_values := PackedInt32Array()
	var graze_values := PackedInt32Array()
	for shot: ProjectileState in world.projectiles:
		var ledger: Dictionary = world.hex_court.ledger_for_source(shot.source_cast_id)
		var cast_id: int = int(world.hex_court.sources.get(shot.source_cast_id, 0))
		var cast: Dictionary = world.hex_court.casts.get(cast_id, {})
		if ledger.is_empty() or not StrengthBudget.validate(ledger) or cast.is_empty() or not cast.flight_parts.has(shot.entity_id) or int(cast.flight_parts[shot.entity_id]) <= 0:
			return {}
		if shot.initial_strength != int(ledger.initial_strength) or shot.remaining_strength != int(ledger.remaining_strength):
			return {} # Projection must already agree; capture never repairs live state.
		var row := Net._capture_projectile(shot, ledger)
		if row.is_empty():
			return {}
		projectile_values.append_array(row)
		graze_values.append(shot.entity_id)
		graze_values.append(shot.grazed_entity_ids.size())
		for grazed_id: int in shot.grazed_entity_ids:
			if grazed_id < 1 or grazed_id > Net.MAX_ID:
				return {}
			graze_values.append(grazed_id)

	var snapshot := {
		"schema": Net.SCHEMA_VERSION,
		"epoch": Net.RESERVED_EPOCH,
		"header": PackedInt64Array([
			SimConfig.PROTOCOL_VERSION, world.tick, world.seed,
			world.next_projectile_id, world.next_field_id, world.next_deposit_id, world.next_reaction_id,
			int(world.hex_court.current_tick),
		]),
		"map_id": world.map_id,
		"map_hash": world.map_hash,
		"transition_hash": world.transition_policy.content_hash,
		"state_hash": world._state_hash_with_verified_hex_hash(verified_hex_hash),
		"players": player_values,
		"projectiles": projectile_values,
		"projectile_grazes": graze_values,
		"fields": PackedInt32Array(),
		"deposits": PackedInt32Array(),
		"reactions": PackedInt32Array(),
		"dynamic_physics": PackedInt32Array(),
		"hex": Net._compress_hex(packed_hex),
	}
	if snapshot.hex.is_empty():
		return {}
	var prepared := prepare(snapshot, world)
	# prepare() already reconstructs the complete world and verifies its hash
	# against snapshot.state_hash. This synchronous producer has no mutation or
	# re-entry point after that captured hash, so repeating both full hashes here
	# adds no malformed-state rejection.
	return snapshot if prepared != null else {}


# Transport-only validation. It proves the exact v2 envelope and typed lane
# lengths without accepting remote topology or constructing gameplay state.


static func prepare(snapshot: Dictionary, trusted_world: SimWorld) -> SimWorld:
	# Decode each transport lane once. validate_wire_structure() remains the
	# transport-only public entry point; repeating it here previously serialized,
	# decompressed, and decoded the same snapshot twice before reconstruction.
	if not Net._snapshot_shape_valid(snapshot) or int(snapshot.epoch) != Net.RESERVED_EPOCH or not Net._trusted_world_valid(trusted_world):
		return null
	var size := Net.byte_size(snapshot)
	if size < 0 or size > Net.MAX_RAW_BYTES:
		return null
	var header: PackedInt64Array = snapshot.header
	if header.size() != 8 or header[0] != SimConfig.PROTOCOL_VERSION or not Net._in_range(header[1], 0, Net.MAX_TICK) \
		or header[7] != maxi(0, header[1] - 1):
		return null
	for index: int in range(3, 7):
		if not Net._in_range(header[index], 1, Net.MAX_ID):
			return null
	if String(snapshot.map_id) != trusted_world.map_id or String(snapshot.map_hash) != trusted_world.map_hash \
		or String(snapshot.transition_hash) != trusted_world.transition_policy.content_hash:
		return null
	if not Net._hash_valid(String(snapshot.state_hash)):
		return null
	var player_values: PackedInt32Array = snapshot.players
	var projectile_values: PackedInt32Array = snapshot.projectiles
	if player_values.is_empty() or player_values.size() % Net.PLAYER_VALUE_COUNT != 0 or player_values.size() / Net.PLAYER_VALUE_COUNT > Net.MAX_ACTORS \
		or projectile_values.size() % Net.PROJECTILE_ROW_SIZE != 0 or projectile_values.size() / Net.PROJECTILE_ROW_SIZE > Net.MAX_PROJECTILES:
		return null
	var decoded_players: Array[PlayerState] = Net._decode_players(player_values)
	if decoded_players.is_empty() or not Net._validate_actor_set(decoded_players):
		return null
	var decoded_projectiles: Variant = Net._decode_projectiles(projectile_values, snapshot.projectile_grazes)
	if decoded_projectiles == null:
		return null

	var packed_hex := Net._decompress_hex(snapshot.hex, trusted_world.hex_court.cells.size())
	if packed_hex.is_empty():
		return null
	var detached := WirePacking.unpack(packed_hex, trusted_world.hex_court.cells.size())
	if detached.is_empty():
		return null
	# Net._prepare() already creates a fresh authority world from trusted topology,
	# validates every detached relation, and verifies the authority hash. Calling
	# restore() here used to allocate a second 1,493-cell blank and copy the first.
	var decoded_hex: HexChemistryWorld = chemistry_prepare(detached, trusted_world.hex_court)
	if decoded_hex == null or decoded_hex.current_tick != header[7]:
		return null
	# The former blank+restore path advanced a fresh target from revision 0 to 1.
	# Preserve that observable presentation invalidation without allocating and
	# copying a second chemistry world.
	decoded_hex.value_revision = 1

	var base_collision := Net._clone_base_collision(trusted_world.collision)
	if base_collision == null:
		return null
	var dynamic_collision := DynamicCollision.new(base_collision)
	decoded_hex.collision = base_collision
	if not dynamic_collision.set_hex_surfaces(decoded_hex, header[1]):
		return null
	var prepared := SimWorld.new(trusted_world.config.tick_rate, header[2], dynamic_collision, trusted_world.map_id, trusted_world.map_hash)
	if not prepared.is_valid() or prepared.transition_policy.content_hash != snapshot.transition_hash:
		return null
	prepared.tick = header[1]
	prepared.seed = header[2]
	prepared.next_projectile_id = header[3]
	prepared.next_field_id = header[4]
	prepared.next_deposit_id = header[5]
	prepared.next_reaction_id = header[6]
	prepared.hex_court = decoded_hex
	prepared.players = decoded_players
	prepared.projectiles = decoded_projectiles
	prepared.fields = []
	prepared.deposits = []
	prepared.reactions = []
	prepared.combat_events = []
	prepared.last_error = ""
	if not Net._validate_relations(prepared):
		return null
	# chemistry_prepare() independently recomputed and verified this
	# chemistry hash above; reuse it only for the exact outer canonical assembly.
	if prepared._state_hash_with_verified_hex_hash(String(detached.authority_hash)) != String(snapshot.state_hash):
		return null
	return prepared
