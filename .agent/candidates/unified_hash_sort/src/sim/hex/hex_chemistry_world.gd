class_name HexChemistryWorld
extends RefCounted
@warning_ignore_start("integer_division")

const Grid = preload("res://src/sim/hex/hex_grid.gd")
const StrengthLedger = preload("res://src/sim/combat/strength_budget.gd")
const Policy = preload("res://src/sim/hex/hex_recipe_policy.gd")
const Parts = preload("res://src/sim/hex/hex_cast_parts.gd")
const MAX_CELLS := 127
const MAX_CASTS := 64
const MAX_PRODUCTS := 32
const MATTER_PER_CAST := 600
const WATER_TICKS := 720
const FIRE_TICKS := 480
const IGNITION_TICKS := 24
const COOLING_TICKS := 60
const STEAM_TICKS := 600
const MEDIUM_RADIUS := 64_000
const MEDIUM_FORMATION_TICKS := 24
const MEDIUM_ACTIVE_TICKS := 360
const MEDIUM_DECAY_TICKS := 60
const CONFLAGRATION_WIRE := 309
const STEAM_WIRE := 310
const FLOOD_WIRE := 316
const PULSE_TICKS := 30
const STEAM_HEIGHT := 48_000
const EXPOSURE_CAP := 240
const COVERAGE := {"rapid": 1, "bolt": 3, "spray": 5, "heavy": 7}
const WATER := 3
const FIRE := 2

var origin := Vector2i.ZERO
var cells: Dictionary = {}
var casts: Dictionary = {}
var products: Dictionary = {}
var pending: Dictionary = {}
var sources: Dictionary = {}
var exposure: Dictionary = {}
var flow_carry: Dictionary = {} # "product:actor" -> Vector2i numerator remainder.
var next_cast_id := 1
var next_product_id := 1
var current_tick := 0 # Last processed authority tick, not wall-clock time.
var render_revision := 0 # Geometry/layout only; layer changes never rebuild topology.
var value_revision := 0
var _render_polygon_revision := -1 # Presentation cache, excluded from authority hash.
var _render_polygons: Dictionary = {}
var chemistry_enabled := false
var collision: CollisionWorld = null # Trusted worldbone, never remote geometry.
var next_ground_part_id := 1
var metrics := {"requested": 0, "admitted": 0, "refused": 0, "deposited": 0, "reactions": 0, "modifiers": 0, "matter_paid": 0, "matter_consumed": 0, "matter_expired": 0, "exposure_queries": 0}


# Geometry belongs to the world/scenario, not the chemistry implementation.
# A new instance starts unconfigured; reconfiguration cannot orphan paid state.
func configure_geometry(requested_origin: Vector2i, eligible_cells: Array[Vector2i]) -> bool:
	if not Grid._query_point_valid(requested_origin) or eligible_cells.is_empty() or eligible_cells.size() > MAX_CELLS or not casts.is_empty() or not products.is_empty() or not pending.is_empty() or not sources.is_empty() or int(metrics.matter_paid) != 0:
		return false
	var prepared := {}
	var ordered := eligible_cells.duplicate()
	ordered.sort_custom(Grid._cell_less)
	for cell: Vector2i in ordered:
		if absi(cell.x) > 256 or absi(cell.y) > 256 or not Grid._query_point_valid(Grid.center(cell) + requested_origin) or prepared.has(cell):
			return false
		var layers := {"terrain": 0, "elevation": 0, "structure": 0}
		for element: int in range(1, 9): layers[Policy.ingredient_layer(element)] = {}
		for wire: int in range(301, 337): layers[Policy.product_layer(wire)] = {}
		prepared[cell] = layers
	origin = requested_origin
	cells = prepared
	_render_polygon_revision = -1
	_render_polygons.clear()
	return true


static func family(wire_id: int) -> String:
	var definition := CombatTuning.cast_definition(wire_id)
	if definition.get("shape", "") == "spray":
		return "spray"
	if definition.get("shape", "") != "projectile":
		return ""
	if bool(definition.get("repeat_while_held", false)):
		return "rapid"
	return "heavy" if int(definition.get("blast_radius", 0)) > 0 else "bolt"


func view(cell: Vector2i, tick: float) -> Dictionary:
	var result := {"fire_phase": "none", "steam_heat": 1000}
	if not cells.has(cell): return result
	for material: String in material_layers():
		var quantity := 0
		var present := false
		for region: Dictionary in render_regions(cell, material, tick):
			present = true
			quantity += int(region.quantity)
			if material == "fire": result.fire_phase = region.phase
			if material == "steam": result.steam_heat = maxi(int(result.steam_heat), int(region.intensity))
		result[material + "_quantity"] = quantity
		result[material + "_present"] = present
	return result

static func material_layers() -> Array[String]:
	var result: Array[String] = []
	for element: int in range(1, 9): result.append(Policy.ingredient_layer(element))
	for wire: int in range(301, 337): result.append(Policy.product_layer(wire))
	return result


func admission_reason(wire_id: int) -> String:
	if not chemistry_enabled or cells.is_empty():
		return "hex_court_preparation"
	var definition := CombatTuning.cast_definition(wire_id)
	if Policy.ingredient_layer(int(definition.get("element_wire_id", 0))).is_empty() or not COVERAGE.has(family(wire_id)):
		return "hex_unsupported_delivery"
	if casts.size() >= MAX_CASTS or _product_capacity_after_cast() > MAX_PRODUCTS:
		return "hex_capacity"
	return ""


func reserved_products() -> int:
	return products.size() + _live_unspent_cast_count()


func _product_capacity_after_cast() -> int:
	return products.size() + _live_unspent_cast_count() + 1


func _live_unspent_cast_count() -> int:
	var result := 0
	for id: int in casts:
		var record: Dictionary = casts[id]
		if not record.has("ledger") or record.ledger.is_empty() or int(record.ledger.remaining_strength) > 0:
			result += 1
	return result


func reserve_cast(owner_id: int, wire_id: int) -> bool:
	if pending.has(owner_id) or not admission_reason(wire_id).is_empty():
		return false
	var definition := CombatTuning.cast_definition(wire_id)
	var id := next_cast_id
	next_cast_id += 1
	casts[id] = {"id": id, "owner": owner_id, "team": owner_id, "wire": wire_id, "element": int(definition.element_wire_id), "strength": int(definition.reaction_strength), "budget": MATTER_PER_CAST, "unallocated": MATTER_PER_CAST, "ground": 0, "consumed": 0, "expired": 0, "paid": false, "source": 0, "reacted": false, "ledger": {}, "cells": {}, "coverage": {}, "flight_parts": {}, "ground_parts": {}, "created": current_tick, "expires": 0, "origin": origin, "trail_spent": 0}
	pending[owner_id] = id
	return true


func commit_payment(owner_id: int) -> void:
	assert(pending.has(owner_id), "payment must own a reservation")
	var record: Dictionary = casts[pending[owner_id]]
	assert(not record.paid, "one payment per reservation")
	record.paid = true
	metrics.matter_paid += MATTER_PER_CAST


func cancel_pending(owner_id: int) -> void:
	if not pending.has(owner_id):
		return
	var id: int = pending[owner_id]
	var record: Dictionary = casts[id]
	if record.paid:
		_expire_unallocated(record)
	casts.erase(id)
	pending.erase(owner_id)


func bind_release(owner_id: int, source_cast_id: int, release_origin: Variant = null, release_aim: Vector2i = Vector2i(0, -1000), team_id: int = -1) -> void:
	if (release_origin != null and not release_origin is Vector2i) or not pending.has(owner_id):
		return
	var id: int = pending[owner_id]
	var record: Dictionary = casts[id]
	assert(record.paid and source_cast_id > 0 and not sources.has(source_cast_id), "release must bind one paid unique runtime source")
	record.source = source_cast_id
	record.origin = origin if release_origin == null else release_origin
	record.aim = release_aim
	record.team = owner_id if team_id < 0 else team_id
	record.ledger = StrengthLedger.make_partitioned(source_cast_id, int(record.strength), MATTER_PER_CAST)
	Parts.initialize(record, source_cast_id)
	assert(StrengthLedger.validate(record.ledger), "bound source creates one valid immutable ledger")
	sources[source_cast_id] = id
	pending.erase(owner_id)


func ledger_for_source(source_id: int) -> Dictionary:
	# The returned dictionary is the authoritative nested record. Callers that
	# only inspect it must duplicate; resolve_contact owns mutation.
	if not sources.has(source_id):
		return {}
	var record: Dictionary = casts.get(int(sources[source_id]), {})
	if record.is_empty() or not record.has("ledger") or not StrengthLedger.validate(record.ledger):
		return {}
	return record.ledger


# Absolute fixed world coordinates for selection only; live cells own coverage.
func terminal_footprint(event: Dictionary, record: Dictionary) -> Dictionary:
	var point: Vector2i = event.position
	var delivery := family(int(record.wire))
	var definition := CombatTuning.cast_definition(int(record.wire))
	# Spray collision range is the exact authored pulse geometry. Its remaining
	# strength separately controls direct damage and deposited density.
	if delivery == "spray":
		var start: Vector2i = record.origin
		var delta := point - start
		var reach := SimCommand._integer_square_root(delta.x * delta.x + delta.y * delta.y)
		return HexFootprint.sector(start, event.get("direction", Vector2i(0, -1000)), reach, int(definition.get("cone_cosine_squared_per_million", 820000)))
	var radius := 12_000 if delivery == "rapid" else 34_000
	if delivery == "heavy":
		radius = int(definition.get("blast_radius", 84_000))
	# A weakened radial projectile cannot deposit beyond the matching terminal
	# blast. Scalar Float64 evaluates the square root and roundi quantizes the
	# world-fixed radius exactly once. Empty ledgers are retained only for pure
	# preview fixtures; every admitted runtime terminal has a valid bound ledger.
	if record.has("ledger") and not record.ledger.is_empty():
		assert(StrengthLedger.validate(record.ledger), "terminal footprint requires a valid source ledger")
		var initial_strength: int = int(record.ledger.initial_strength)
		var remaining_strength: int = int(record.ledger.remaining_strength)
		radius = roundi(float(radius) * sqrt(float(remaining_strength) / float(initial_strength)))
	return HexFootprint.disk(point, radius)


func footprint(event: Dictionary, record: Dictionary) -> Array[Vector2i]:
	return select_cells(terminal_footprint(event, record))


# Worldbone occlusion participates in eligibility once, during selection.
# Whole-cell membership never performs another actor-distance or sight test.
func select_cells(shape: Dictionary, eligible: Variant = null) -> Array[Vector2i]:
	var membership: Dictionary = cells if eligible == null else eligible
	var selected := HexFootprint.selected_cells(shape, origin, membership)
	if collision == null: return selected
	var anchor: Vector2i = shape.get("center", shape.get("start", origin))
	var visible: Array[Vector2i] = []
	for cell: Vector2i in selected:
		if ContinuousContact.wall_contact(anchor, origin + HexGrid.center(cell), 0, collision).is_empty(): visible.append(cell)
	return visible


# Presentation and previews consume the same stored whole-cell coverage as gameplay.
func render_regions(cell: Vector2i, material: String, tick: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not cells.has(cell) or not cells[cell].has(material): return result
	var is_product := material not in Policy.INGREDIENT_LAYERS.values()
	for id: int in cells[cell][material]:
		if is_product:
			var product: Dictionary = products.get(id, {})
			if product.is_empty() or tick >= int(product.expiry_tick): continue
			var phase := "forming" if tick < int(product.active_tick) else "decaying" if tick >= int(product.decay_tick) else "active"
			result.append({"footprint_id": id, "polygon": whole_cell_polygon(cell), "phase": phase,
				"danger": phase == "active", "intensity": int(product.intensity), "quantity": int(product.cells[cell]),
				"owner": int(product.owner), "source_ids": product.source_ids.duplicate(), "expiry_tick": int(product.expiry_tick),
				"recipe_wire_id": int(product.recipe_wire_id), "direction": product.flow_aim, "material": material})
		else:
			var record: Dictionary = casts.get(id, {})
			for part_id: int in record.get("ground_parts", {}):
				var part: Dictionary = record.ground_parts[part_id]
				if not part.coverage.has(cell) or tick >= int(part.expiry_tick): continue
				var phase := "forming" if tick < int(part.created) + IGNITION_TICKS else "decaying" if tick >= int(part.expiry_tick) - COOLING_TICKS else "active"
				if material == "fire": phase = "ignition" if phase == "forming" else "cooling" if phase == "decaying" else phase
				result.append({"footprint_id": part_id, "polygon": whole_cell_polygon(cell), "phase": phase,
					"danger": material == "fire" and phase == "active", "intensity": 1000, "quantity": int(part.cells[cell]),
					"owner": int(record.owner), "source_ids": [int(record.source)], "expiry_tick": int(part.expiry_tick),
					"recipe_wire_id": 0, "direction": record.aim, "material": material})
	return result


func whole_cell_polygon(cell: Vector2i) -> PackedVector2Array:
	var result := PackedVector2Array()
	for vertex: Vector2i in Grid.vertices(cell): result.append(Vector2(vertex + origin))
	return result


func preview_regions(event: Dictionary, record: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cell: Vector2i in footprint(event, record):
		result.append({"cell": cell, "polygon": whole_cell_polygon(cell)})
	return result


func deposit_terminal(event: Dictionary, tick: int) -> void:
	var source := int(event.get("source_cast_id", 0))
	if not sources.has(source): return
	var record: Dictionary = casts[int(sources[source])]
	var entity_id := int(event.get("projectile_id", source))
	if not bool(record.paid) or not Parts.validate(record) or not record.flight_parts.has(entity_id): return
	assert(int(event.source_wire_id) == int(record.wire) and int(event.reaction_strength) == int(record.strength), "terminal cannot mutate immutable provenance")
	var shape := terminal_footprint(event, record)
	var selected := select_cells(shape)
	if selected.is_empty():
		var expired: int = Parts.expire_flight(record, entity_id)
		metrics.matter_expired += maxi(0, expired)
		_sync_cast_ledger(record)
		return
	_try_modifier(record, selected, tick)
	if not record.flight_parts.has(entity_id): return
	record.aim = event.get("direction", record.aim)
	var expiry := tick + ingredient_lifetime(int(record.element))
	if int(record.ground) == 0: record.created = tick
	var moved: int = Parts.deposit_flight(record, entity_id, next_ground_part_id, selected, shape, tick, expiry)
	if moved <= 0: return
	next_ground_part_id += 1
	record.footprint = shape
	record.expires = maxi(int(record.expires), expiry)
	_sync_cast_ledger(record)
	_rebuild_cast_layers(record)
	metrics.deposited += 1
	value_revision += 1
	_try_ground_reactions(record, event.position, tick)

static func trail_lifetime(element: int) -> int:
	if element < 1 or element >= ElementChemistrySystem.TRAIL_LIFE_MS.size(): return 0
	return SimConfig.new(120).milliseconds_to_ticks(int(ElementChemistrySystem.TRAIL_LIFE_MS[element]))

static func ingredient_lifetime(element: int) -> int:
	return WATER_TICKS if element == WATER else FIRE_TICKS if element == FIRE else ElementChemistrySystem.ELEMENT_LIFE_MS[element] * 120 / 1000

func _rebuild_cast_layers(record: Dictionary) -> void:
	var layer := _layer(record)
	for cell: Vector2i in cells: cells[cell][layer].erase(int(record.id))
	for cell: Vector2i in record.cells: cells[cell][layer][int(record.id)] = int(record.cells[cell])

static func coverage(record: Dictionary) -> Dictionary:
	if record.has("coverage"): return record.coverage
	var result := {}
	for cell: Vector2i in record.get("cells", {}):
		if int(record.cells[cell]) > 0: result[cell] = 1
	return result


func _try_ground_reactions(record: Dictionary, point: Vector2i, tick: int) -> void:
	var ids: Array = casts.keys()
	ids.sort()
	for other_id: int in ids:
		if int(record.ledger.remaining_strength) <= 0:
			return
		var other: Dictionary = casts[other_id]
		if other_id == int(record.id) or not other.paid or not StrengthLedger.validate(other.get("ledger", {})) or int(other.ledger.remaining_strength) <= 0 or int(other.ledger.deposited_quantity) <= 0 or int(other.expires) <= tick:
			continue
		# Persistent materials react anywhere in the same live selected cell.
		var incoming := {}
		for part: Dictionary in record.ground_parts.values():
			if not bool(part.trail) and int(part.created) == tick:
				for cell: Vector2i in part.coverage: incoming[cell] = 1
		var eligible := HexTrailEmitter.contact_coverage(other, tick)
		var witness: Dictionary = HexFootprint.shared_selected_contact(incoming, eligible, origin, point)
		if witness.is_empty():
			continue
		var trail_contact := not HexTrailEmitter.terminal_coverage(other).has(HexGrid.world_to_cell(witness.point - origin))
		var outcome := resolve_contact(int(record.source), int(other.source), witness.point, tick)
		if trail_contact and bool(outcome.get("accepted", false)) and products.has(int(outcome.get("product_id", 0))):
			var product: Dictionary = products[int(outcome.product_id)]
			var active := int(product.decay_tick) - int(product.active_tick)
			if active >= 120:
				var decay := int(product.expiry_tick) - int(product.decay_tick)
				product.decay_tick = int(product.active_tick) + active * 600 / 1000
				product.expiry_tick = int(product.decay_tick) + decay
				product.expires = product.expiry_tick


# Compatibility entry for the current court tests; new terminals provide their
# physical point directly to _try_ground_reactions.
func _try_reaction(record: Dictionary, tick: int) -> void:
	var point: Vector2i = record.get("origin", origin)
	if record.has("footprint") and String(record.footprint.get("kind", "")) == "disk":
		point = record.footprint.center
	_try_ground_reactions(record, point, tick)


func _try_modifier(record: Dictionary, selected: Array[Vector2i], tick: int) -> bool:
	# Steam modification is a bounded channel operation, not a fundamental
	# element/product clash. Each channel is available once and consumes only the
	# incoming real source's remaining stock.
	var ids: Array = products.keys()
	ids.sort()
	for id: int in ids:
		var product: Dictionary = products[id]
		if int(product.recipe_wire_id) == 317 and tick >= int(product.active_tick) and tick < int(product.decay_tick) and int(record.element) == FIRE:
			for cell: Vector2i in selected:
				if coverage(product).has(cell) and suppress_source(int(record.source), id) > 0: return true
		if int(product.recipe_wire_id) != STEAM_WIRE:
			continue
		if int(record.element) not in [WATER, FIRE]: continue
		var heating := int(record.element) == FIRE
		if int(product.expiry_tick) <= tick or int(record.source) in product.source_ids or bool(product.heated if heating else product.cooled):
			continue
		var touches := false
		for cell: Vector2i in selected:
			if coverage(product).has(cell):
				touches = true
				break
		if not touches:
			continue
		var consumed_strength: int = int(record.ledger.remaining_strength)
		var amount: int = StrengthLedger.consume_remaining(record.ledger)
		if amount <= 0:
			continue
		_sync_consumed_cast(record)
		record.reacted = true
		metrics.matter_consumed += amount
		product.quantity += amount
		product.source_ids.append(int(record.source))
		var expanded: Array[Vector2i] = []
		for cell: Vector2i in product.cells:
			expanded.append(cell)
		if heating:
			product.heated = true
			product.intensity = mini(1500, int(product.intensity) + consumed_strength * 50)
			product.expiry_tick = tick + maxi(1, (int(product.expiry_tick) - tick) / 2)
			product.expires = int(product.expiry_tick)
			product.decay_tick = mini(int(product.decay_tick), maxi(int(product.active_tick), int(product.expiry_tick) - MEDIUM_DECAY_TICKS))
		else:
			product.cooled = true
			# Literal policy: I' = I - min(floor(I/2), 50*S). Thus 750
			# cooled by strength5 becomes500, while strength1 100 becomes50.
			var cooling: int = mini(int(product.intensity) / 2, consumed_strength * 50)
			product.intensity = maxi(0, int(product.intensity) - cooling)
			# Cooling changes paid intensity; it cannot add whole neighboring hexes.
		_retile_product(product, expanded)
		metrics.modifiers += 1
		value_revision += 1
		return true
	return false


func suppress_source(source: int, product_id: int) -> int:
	if not sources.has(source) or not products.has(product_id): return 0
	var product: Dictionary = products[product_id]
	var record: Dictionary = casts[int(sources[source])]
	if int(product.recipe_wire_id) != 317 or int(product.capacity) <= 0 or int(record.element) != FIRE or not Parts.validate(record): return 0
	var ledger: Dictionary = record.ledger
	var strength := int(ledger.remaining_strength)
	for loss: int in range(strength, 0, -1):
		var amount: int = StrengthLedger._quantity_delta(ledger, strength, strength - loss)
		if amount <= 0 or amount > int(product.capacity): continue
		StrengthLedger._apply_consumption(ledger, strength - loss, amount)
		_sync_consumed_cast(record)
		product.capacity -= amount
		metrics.matter_consumed += amount
		value_revision += 1
		return amount
	return 0


func fracture_products(tick: int) -> void:
	for product: Dictionary in products.values():
		if int(product.recipe_wire_id) != 312 or tick < int(product.active_tick) or tick >= int(product.decay_tick) or int(product.pulse_index) >= 0: continue
		product.pulse_index = 0
		for cover: Dictionary in products.values():
			if int(cover.health) <= 0 or tick < int(cover.active_tick) or tick >= int(cover.decay_tick): continue
			var overlaps := false
			for cell: Vector2i in coverage(cover):
				if coverage(product).has(cell): overlaps = true; break
			if not overlaps: continue
			cover.health = maxi(0, int(cover.health) - 30_000)
			if int(cover.health) == 0: cover.decay_tick = tick
			value_revision += 1


func resolve_contact(source_a: int, source_b: int, point: Vector2i, tick: int) -> Dictionary:
	if source_a == source_b or not sources.has(source_a) or not sources.has(source_b):
		return {"accepted": false, "reason": &"unknown_source"}
	var first: Dictionary = casts.get(int(sources[source_a]), {})
	var second: Dictionary = casts.get(int(sources[source_b]), {})
	if first.is_empty() or second.is_empty() or not bool(first.paid) or not bool(second.paid):
		return {"accepted": false, "reason": &"invalid_source"}
	if not Parts.validate(first) or not Parts.validate(second):
		return {"accepted": false, "reason": &"invalid_ownership"}
	var recipe_wire_id: int = _recipe_wire(int(first.element), int(second.element))
	if recipe_wire_id == 0:
		return {"accepted": false, "reason": &"unsupported_pair"}
	var footprint := Policy.selection_shape(recipe_wire_id, point, _oldest_source_aim([source_a, source_b]))
	var selected := select_cells(footprint)
	if selected.is_empty():
		return {"accepted": false, "reason": &"outside_court"}
	if products.size() >= MAX_PRODUCTS:
		return {"accepted": false, "reason": &"product_capacity"}
	var outcome: Dictionary = StrengthLedger.consume_pair(first.ledger, second.ledger)
	if not bool(outcome.accepted):
		return outcome
	_sync_consumed_cast(first)
	_sync_consumed_cast(second)
	var quantity: int = int(outcome.first.consumed_quantity) + int(outcome.second.consumed_quantity)
	if quantity == 0:
		return outcome # Positive strength subtraction can round to zero after partial expiry.
	var product_id := _create_product(
		recipe_wire_id,
		[source_a, source_b],
		point,
		selected,
		int(outcome.matched_strength),
		quantity,
		tick,
	)
	metrics.matter_consumed += quantity
	metrics.reactions += 1
	value_revision += 1
	first.reacted = int(first.ledger.remaining_strength) == 0
	second.reacted = int(second.ledger.remaining_strength) == 0
	outcome.product_id = product_id
	outcome.reaction_id = product_id
	outcome.recipe_wire_id = recipe_wire_id
	outcome.quantity = quantity
	outcome.intensity = mini(1500, int(outcome.matched_strength) * 100)
	return outcome


func _create_product(recipe_wire_id: int, parent_sources: Array, point: Vector2i, selected: Array[Vector2i], matched_strength: int, quantity: int, tick: int) -> int:
	assert(products.size() < MAX_PRODUCTS, "admission retains one product slot per live source")
	var id := next_product_id
	next_product_id += 1
	parent_sources.sort()
	var material := _product_material(recipe_wire_id)
	var allocations := _equal_allocations(selected, quantity)
	var oldest_aim := _oldest_source_aim(parent_sources)
	var policy := Policy.definition(recipe_wire_id)
	var first: Dictionary = casts[int(sources[int(parent_sources[0])])]
	var active := tick + int(policy.formation_ticks)
	var decay := active + int(policy.active_ticks)
	var expiry := decay + int(policy.decay_ticks)
	var selected_membership := {}
	for cell: Vector2i in selected: selected_membership[cell] = 1
	products[id] = {
		"id": id,
		"recipe_wire_id": recipe_wire_id,
		"material": material,
		"strength": matched_strength,
		"source_ids": parent_sources.duplicate(),
		"footprint": Policy.selection_shape(recipe_wire_id, point, oldest_aim),
		"cells": allocations,
		"coverage": selected_membership,
		"quantity": quantity,
		"created": tick,
		"formation_tick": tick,
		"active_tick": active,
		"decay_tick": decay,
		"expiry_tick": expiry,
		"expires": expiry,
		"intensity": mini(1500, matched_strength * 100),
		"heated": false,
		"cooled": false,
		"flow_aim": oldest_aim,
		"flow_units_per_second": int(policy.flow_speed),
		"common_wall_clearance": 18_000,
		"pulse_ms": int(policy.pulse_ticks) * 1000 / 120,
		"pulse_damage": int(policy.pulse_damage),
		"geometry_override": "whole_hex",
		"owner": int(first.owner), "team": int(first.team), "health": int(policy.health), "capacity": int(policy.capacity),
		"position": point, "origin": point, "contacts": {}, "linked_sources": [], "pulse_index": -1,
		"last_motion_tick": tick, "motion_carry": Vector2i.ZERO,
	}
	for cell: Vector2i in allocations:
		cells[cell][material][id] = int(allocations[cell])
	_build_links(products[id])
	return id


func _build_links(product: Dictionary) -> void:
	var element := int({313: 6, 319: 3, 328: 5}.get(int(product.recipe_wire_id), 0))
	if element == 0: return
	var policy := Policy.definition(int(product.recipe_wire_id))
	var previous: Vector2i = product.position
	var membership := coverage(product).duplicate()
	var ids: Array = casts.keys()
	ids.sort()
	for unused: int in range(1 if element == 6 else 4):
		var best := 0
		var best_distance: int = int(policy.length) * int(policy.length) + 1
		for id: int in ids:
			var record: Dictionary = casts[id]
			if int(record.element) != element or int(record.source) in product.source_ids or int(record.source) in product.linked_sources or int(record.ground) <= 0: continue
			var target: Vector2i = record.origin
			for part: Dictionary in record.ground_parts.values():
				target = part.footprint.get("center", part.footprint.get("start", target))
				break
			var distance: int = (target - previous).length_squared()
			if distance < best_distance and (collision == null or SprayInterception.clear_ray(previous, target, collision, [], current_tick)):
				best_distance = distance
				best = id
		if best == 0: break
		var target: Vector2i = casts[best].origin
		for part: Dictionary in casts[best].ground_parts.values():
			target = part.footprint.get("center", part.footprint.get("start", target))
			break
		product.linked_sources.append(int(casts[best].source))
		for cell: Vector2i in select_cells(HexFootprint.capsule(previous, target, int(policy.radius))): membership[cell] = 1
		previous = target
	var selected: Array[Vector2i] = []
	for cell: Vector2i in membership: selected.append(cell)
	_retile_product(product, selected)


func move_products(tick: int, physics: CollisionWorld) -> void:
	for product: Dictionary in products.values():
		var wire := int(product.recipe_wire_id)
		var policy := Policy.definition(wire)
		var speed := int(policy.motion_speed)
		if wire in [304, 317]: speed = 0 # Authored stationary steering corridors.
		if wire in [318, 323] and tick >= int(product.active_tick) and tick < int(product.decay_tick):
			var age := tick - int(product.active_tick)
			var shape := Policy.selection_shape(wire, product.origin, product.flow_aim)
			var selected: Array[Vector2i] = []
			if wire == 318:
				var length := mini(int(policy.length), 25_000 + age * 150_000 / 144)
				shape.end = product.origin + ElementChemistrySystem.scaled(product.flow_aim, length)
				selected = select_cells(shape)
			else:
				var lane := {}
				for cell: Vector2i in select_cells(shape): lane[cell] = 1
				var point: Vector2i = product.origin + ElementChemistrySystem.scaled(product.flow_aim, int(policy.length) * (age % 54) / 54)
				shape = HexFootprint.disk(point, 31_250)
				selected = select_cells(shape, lane)
			if not selected.is_empty():
				product.footprint = shape
				_retile_product(product, selected)
				value_revision += 1
			continue
		if speed <= 0 or tick < int(product.active_tick) or tick >= int(product.decay_tick): continue
		var elapsed := tick - maxi(int(product.last_motion_tick), int(product.active_tick))
		if elapsed <= 0: continue
		product.last_motion_tick = tick
		var numerator: Vector2i = product.motion_carry + product.flow_aim * speed * elapsed
		var delta := Vector2i(numerator.x / 120_000, numerator.y / 120_000)
		product.motion_carry = numerator - delta * 120_000
		var current: Vector2i = product.position
		var target := current + delta
		if physics != null: target = physics.move_box(current, delta, 1000).position
		if target == current: continue
		var shape := Policy.selection_shape(wire, target, product.flow_aim)
		var selected := select_cells(shape)
		if selected.is_empty(): continue # Bounded district edge stops, never refreshes.
		product.position = target
		product.footprint = shape
		_retile_product(product, selected)
		value_revision += 1


func _oldest_source_aim(parent_sources: Array) -> Vector2i:
	var oldest_created := 2_147_483_647
	var oldest_id := 2_147_483_647
	var result := Vector2i(0, -1000)
	for source_value: Variant in parent_sources:
		var cast_id := int(sources.get(int(source_value), 0))
		if not casts.has(cast_id):
			continue
		var record: Dictionary = casts[cast_id]
		if int(record.created) < oldest_created or (int(record.created) == oldest_created and cast_id < oldest_id):
			oldest_created = int(record.created)
			oldest_id = cast_id
			result = record.get("aim", Vector2i(0, -1000))
	return result


static func _recipe_wire(first_element: int, second_element: int) -> int:
	return Policy.recipe_wire(first_element, second_element)


static func _product_material(recipe_wire_id: int) -> String:
	return Policy.product_layer(recipe_wire_id)


static func _equal_allocations(selected: Array[Vector2i], quantity: int) -> Dictionary:
	var ordered := selected.duplicate()
	ordered.sort_custom(Grid._cell_less)
	var result := {}
	for index: int in ordered.size():
		var amount := quantity / ordered.size() + int(index < quantity % ordered.size())
		result[ordered[index]] = amount
	return result


func _sync_consumed_cast(record: Dictionary) -> void:
	var retiled: bool = Parts.retile_after_contact(record, int(record.unallocated), int(record.ground))
	assert(retiled, "prevalidated source partitions must mirror the single ledger transition")
	_sync_cast_ledger(record)
	_rebuild_cast_layers(record)


func _sync_cast_ledger(record: Dictionary) -> void:
	record.unallocated = int(record.ledger.flight_quantity)
	record.ground = int(record.ledger.deposited_quantity)
	record.consumed = int(record.ledger.consumed_quantity)
	record.expired = int(record.ledger.expired_quantity)


func _expire_live(record: Dictionary) -> int:
	if not record.has("ledger") or record.ledger.is_empty():
		_expire_unallocated(record)
		return 0
	var moved: int = StrengthLedger.expire(record.ledger)
	if moved < 0: return moved
	Parts.retile_after_contact(record, int(record.unallocated), int(record.ground))
	_sync_cast_ledger(record)
	_rebuild_cast_layers(record)
	if bool(record.paid): metrics.matter_expired += moved
	if moved > 0: value_revision += 1
	return moved


func _retile_product(product: Dictionary, selected: Array[Vector2i]) -> void:
	var id: int = product.id
	var material: String = product.material
	for cell: Vector2i in product.cells:
		cells[cell][material].erase(id)
	selected.sort_custom(Grid._cell_less)
	product.cells = {}
	product.coverage = {}
	var total: int = product.quantity
	for index: int in selected.size():
		var amount := total / selected.size() + int(index < total % selected.size())
		product.cells[selected[index]] = amount
		product.coverage[selected[index]] = 1
		cells[selected[index]][material][id] = amount


func _expire_unallocated(record: Dictionary) -> void:
	if record.has("ledger") and not record.ledger.is_empty():
		_expire_live(record)
		return
	var amount: int = record.unallocated
	record.unallocated = 0
	record.expired += amount
	if record.paid:
		metrics.matter_expired += amount


# Explicit mirror-product adapter. The caller chooses its position in the solo
# movement pipeline and supplies the same CollisionWorld used for actor motion.
func contains_stored(record: Dictionary, point: Vector2i) -> bool:
	return HexFootprint.contains_selected(coverage(record), origin, point)


func apply_product_effects(players: Array[PlayerState], tick: int, config: SimConfig, collision: CollisionWorld, events: Array[Dictionary], paths: Dictionary = {}) -> void:
	if not config.is_valid() or collision == null:
		return
	var sampled_paths := paths.duplicate(true)
	for actor: PlayerState in players:
		var previous: Variant = sampled_paths.get(actor.entity_id, Vector2i(actor.position_x, actor.position_y))
		if previous is Vector2i: previous = {"point": previous, "height": actor.air_height}
		previous.finish = Vector2i(actor.position_x, actor.position_y)
		sampled_paths[actor.entity_id] = previous
	HexProductEffects.step(self, players, tick, config, collision, events, sampled_paths)
	paths = sampled_paths
	var ground_paths := {}
	var ids: Array = products.keys()
	ids.sort()
	for product_id: int in ids:
		var product: Dictionary = products[product_id]
		if tick < int(product.active_tick) or tick >= int(product.decay_tick) or tick >= int(product.expiry_tick):
			continue
		var recipe_wire_id: int = int(product.recipe_wire_id)
		if recipe_wire_id == CONFLAGRATION_WIRE:
			if (tick - int(product.active_tick)) % config.milliseconds_to_ticks(600) != 0:
				continue
			for actor: PlayerState in players:
				if actor.spawn_protection_ticks > 0 or MovementSystem.is_combat_intangible(actor, config): continue
				if actor.health <= 0 or actor.air_height > 0 or not _ground_path_touches(product, actor, paths, ground_paths):
					continue
				var damage: int = int(product.pulse_damage) * int(product.intensity) / 1000
				if damage > 0 and PlayerResourcesSystem.damage(actor, damage, config):
					events.append({"type": "hex_conflagration", "entity_id": actor.entity_id, "product_id": product_id, "amount": damage})
		elif recipe_wire_id == FLOOD_WIRE:
			for actor: PlayerState in players:
				if actor.spawn_protection_ticks > 0 or MovementSystem.is_combat_intangible(actor, config): continue
				if actor.health <= 0 or actor.air_height > 0 or not _ground_path_touches(product, actor, paths, ground_paths):
					continue
				var key := "%d:%d" % [product_id, actor.entity_id]
				var carry: Vector2i = flow_carry.get(key, Vector2i.ZERO)
				var aim: Vector2i = product.flow_aim
				var denominator: int = config.tick_rate * SimConfig.FIXED_SCALE
				var speed: int = int(product.flow_units_per_second) * int(product.intensity) / 1000
				var numerator_x: int = carry.x + speed * aim.x
				var numerator_y: int = carry.y + speed * aim.y
				var delta := Vector2i(numerator_x / denominator, numerator_y / denominator)
				flow_carry[key] = Vector2i(numerator_x - delta.x * denominator, numerator_y - delta.y * denominator)
				var old_position := Vector2i(actor.position_x, actor.position_y)
				var moved := collision.move_box(old_position, delta, int(product.common_wall_clearance))
				actor.position_x = moved.position.x
				actor.position_y = moved.position.y
				if moved.position != old_position:
					events.append({"type": "hex_flood_flow", "entity_id": actor.entity_id, "product_id": product_id, "delta": moved.position - old_position})


func _ground_path_touches(record: Dictionary, actor: PlayerState, paths: Dictionary, cache: Dictionary) -> bool:
	# Coverage is sampled at the common post-movement position. Subsequent Flood
	# impulses must not resample/re-enter another product in the same pulse step.
	if not cache.has(actor.entity_id):
		var finish := Vector2i(actor.position_x, actor.position_y)
		var previous: Variant = paths.get(actor.entity_id, finish)
		if previous is Dictionary: finish = previous.get("finish", finish)
		var start: Vector2i = previous if previous is Vector2i else previous.point
		if previous is Dictionary and int(previous.height) > 0: start = finish
		if start == finish:
			cache[actor.entity_id] = [Grid.world_to_cell(finish - origin)]
		else:
			var membership := {}
			for cell: Vector2i in cells: membership[cell] = 1
			cache[actor.entity_id] = HexFootprint.traversed_selected_cells(membership, origin, start, finish)
	for cell: Vector2i in cache[actor.entity_id]:
		if coverage(record).has(cell): return true
	return false


func _clear_product_flow_carry(product_id: int) -> void:
	var prefix := "%d:" % product_id
	for key: String in flow_carry.keys():
		if key.begins_with(prefix):
			flow_carry.erase(key)


func expire_at(tick: int) -> void:
	current_tick = tick
	for id: int in casts.keys():
		var record: Dictionary = casts[id]
		for part_id: int in record.ground_parts.keys():
			if tick >= int(record.ground_parts[part_id].expiry_tick):
				var expired: int = Parts.expire_ground(record, part_id)
				metrics.matter_expired += maxi(0, expired)
				_sync_cast_ledger(record)
				_rebuild_cast_layers(record)
				value_revision += 1
	for id: int in products.keys():
		var product: Dictionary = products[id]
		if tick >= int(product.expiry_tick):
			for cell: Vector2i in product.cells: cells[cell][product.material].erase(id)
			_clear_product_flow_carry(id)
			products.erase(id)
			value_revision += 1


func advance(players: Array[PlayerState], paths: Dictionary, tick: int, config: SimConfig, events: Array[Dictionary]) -> void:
	expire_at(tick)
	var hazards := not products.is_empty()
	if not hazards:
		for id: int in casts:
			if int(casts[id].element) == FIRE and int(casts[id].ground) > 0 and _fire_phase(casts[id], tick) == "active":
				hazards = true
				break
	for actor: PlayerState in players:
		if hazards:
			_expose(actor, paths.get(actor.entity_id, Vector2i(actor.position_x, actor.position_y)), tick, config, events)
		else:
			exposure[actor.entity_id] = maxi(0, int(exposure.get(actor.entity_id, 0)) - 2)
	for event: Dictionary in events:
		if event.get("type", "") == "cast_started":
			metrics.requested += 1
			metrics.admitted += 1
		elif event.get("type", "") == "cast_refused":
			metrics.requested += 1
			metrics.refused += 1


func _expose(actor: PlayerState, previous: Variant, tick: int, config: SimConfig, events: Array[Dictionary]) -> void:
	var id := actor.entity_id
	var old_exposure := int(exposure.get(id, 0))
	if actor.health <= 0 or actor.spawn_protection_ticks > 0 or MovementSystem.is_combat_intangible(actor, config):
		exposure[id] = maxi(0, old_exposure - 2)
		return
	var finish := Vector2i(actor.position_x, actor.position_y)
	var start: Vector2i = previous if previous is Vector2i else previous.point
	var previous_height := 0 if previous is Vector2i else int(previous.height)
	# A landing tick uses only the grounded endpoint, never the airborne path.
	if (previous_height > 0 and actor.air_height == 0) or (previous_height > STEAM_HEIGHT and actor.air_height <= STEAM_HEIGHT):
		start = finish
	var membership := {}
	for cell: Vector2i in cells: membership[cell] = 1
	var touched := HexFootprint.traversed_selected_cells(membership, origin, start, finish)
	metrics.exposure_queries += 1
	var steam_density := {}
	var fire_damage := 0
	for cell: Vector2i in touched:
		if not cells.has(cell):
			continue
		var record: Dictionary = cells[cell]
		if actor.air_height == 0:
			for cast_id: int in record.fire:
				if not casts.has(cast_id): continue
				for part: Dictionary in casts[cast_id].ground_parts.values():
					if not part.coverage.has(cell) or tick < int(part.created) + IGNITION_TICKS or tick >= int(part.expiry_tick) - COOLING_TICKS: continue
					# Damage rounds once from the finite part's mean density. Coverage
					# cannot disappear because its integer allocation rounded to zero.
					fire_damage = maxi(fire_damage, maxi(1, 4000 * int(part.quantity) / (MATTER_PER_CAST * part.coverage.size())))
		if actor.air_height <= STEAM_HEIGHT:
			for product_id: int in record.steam:
				if tick < int(products[product_id].active_tick) or tick >= int(products[product_id].decay_tick): continue
				steam_density[product_id] = maxi(int(steam_density.get(product_id, 0)), maxi(1, int(record.steam[product_id])))
	exposure[id] = mini(EXPOSURE_CAP, old_exposure + 1) if not steam_density.is_empty() else maxi(0, old_exposure - 2)
	if tick % PULSE_TICKS != 0:
		return
	var pressure := fire_damage
	for product_id: int in steam_density:
		var density: int = steam_density[product_id]
		var ramp := 2000 + 6000 * int(exposure[id]) / EXPOSURE_CAP
		var normal := mini(8000, ramp * density / 400)
		pressure = maxi(pressure, mini(12000, normal * int(products[product_id].intensity) / 1000))
	if pressure > 0 and PlayerResourcesSystem.damage(actor, pressure, config):
		events.append({"type": "hex_pressure", "entity_id": id, "amount": pressure, "exposure": int(exposure[id])})


func sync_flights(players: Array[PlayerState], projectiles: Array[ProjectileState]) -> void:
	var live := {}
	for projectile: ProjectileState in projectiles: live[projectile.entity_id] = true
	var live_pending := {}
	for actor: PlayerState in players:
		if actor.health > 0 and actor.pending_cast_wire_id > 0: live_pending[actor.entity_id] = actor.pending_cast_wire_id
	for id: int in casts.keys():
		var record: Dictionary = casts[id]
		if not record.ledger.is_empty():
			for entity_id: int in record.flight_parts.keys():
				if not live.has(entity_id):
					var expired: int = Parts.expire_flight(record, entity_id)
					metrics.matter_expired += maxi(0, expired)
					_sync_cast_ledger(record)
		elif int(live_pending.get(int(record.owner), 0)) != int(record.wire):
			_expire_unallocated(record)
		if int(record.ground) == 0 and int(record.unallocated) == 0:
			if int(pending.get(int(record.owner), 0)) == id: pending.erase(int(record.owner))
			sources.erase(int(record.source))
			casts.erase(id)

func flight_quantity(source: int, entity_id: int) -> int:
	if not sources.has(source): return 0
	return int(casts[int(sources[source])].flight_parts.get(entity_id, 0))

func split_flight(source: int, parent_id: int, child_id: int) -> bool:
	return false if not sources.has(source) else Parts.split_flight(casts[int(sources[source])], parent_id, child_id)


func conservation_valid() -> bool:
	if casts.size() > MAX_CASTS or products.size() > MAX_PRODUCTS or cells.size() > MAX_CELLS or reserved_products() > MAX_PRODUCTS: return false
	for cell: Vector2i in cells:
		for element: int in range(1, 9):
			var layer := Policy.ingredient_layer(element)
			for id: int in cells[cell][layer]:
				if not casts.has(id) or int(casts[id].element) != element or not casts[id].cells.has(cell) or int(casts[id].cells[cell]) != int(cells[cell][layer][id]): return false
		for wire: int in range(301, 337):
			var layer := Policy.product_layer(wire)
			for id: int in cells[cell][layer]:
				if not products.has(id) or int(products[id].recipe_wire_id) != wire or not products[id].cells.has(cell) or int(products[id].cells[cell]) != int(cells[cell][layer][id]): return false
	var live := 0
	for id: int in casts:
		var record: Dictionary = casts[id]
		if record.ledger.is_empty():
			if int(record.source) != 0 or not record.cells.is_empty() or int(record.ground) != 0 or int(record.unallocated) + int(record.consumed) + int(record.expired) != int(record.budget): return false
		else:
			if not Parts.validate(record): return false
			if int(record.ground) != int(record.ledger.deposited_quantity) or int(record.unallocated) != int(record.ledger.flight_quantity) or int(record.consumed) != int(record.ledger.consumed_quantity) or int(record.expired) != int(record.ledger.expired_quantity): return false
			for cell: Vector2i in record.cells:
				if not cells.has(cell) or not cells[cell][_layer(record)].has(id) or int(cells[cell][_layer(record)][id]) != int(record.cells[cell]): return false
		if bool(record.paid): live += int(record.unallocated) + int(record.ground)
	var product_total := 0
	for id: int in products:
		var product: Dictionary = products[id]
		var total := 0
		if int(product.quantity) <= 0 or product.cells.size() != product.coverage.size() or product.cells.is_empty(): return false
		for cell: Vector2i in product.cells:
			if not cells.has(cell) or int(product.cells[cell]) < 0 or int(product.coverage.get(cell, 0)) != 1 or not cells[cell][product.material].has(id) or int(cells[cell][product.material][id]) != int(product.cells[cell]): return false
			total += int(product.cells[cell])
		if total != int(product.quantity): return false
		product_total += total
	return live + int(metrics.matter_consumed) + int(metrics.matter_expired) == int(metrics.matter_paid) and product_total <= int(metrics.matter_consumed)


static func _layer(record: Dictionary) -> String:
	return Policy.ingredient_layer(int(record.element))


static func _fire_phase(record: Dictionary, tick: int) -> String:
	if tick >= int(record.expires):
		return "none"
	if tick < int(record.created) + IGNITION_TICKS:
		return "ignition"
	return "cooling" if tick >= int(record.expires) - COOLING_TICKS else "active"


static func _stable(value: Variant) -> Variant:
	if value is Vector2i:
		return [value.x, value.y]
	if value is Dictionary:
		var keys: Array = value.keys()
		var string_keys := not keys.is_empty()
		for key: Variant in keys:
			if typeof(key) != TYPE_STRING:
				string_keys = false
				break
		if string_keys:
			# String's native ordering is the same ordering used by the legacy
			# str(a) < str(b) comparator, without repeated Variant formatting.
			keys.sort()
		else:
			# Preserve the published comparator for empty, numeric, Vector2i,
			# StringName, and mixed dictionaries byte-for-byte.
			keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		var result: Array = []
		for key: Variant in keys:
			result.append([_stable(key), _stable(value[key])])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_stable(item))
		return result
	return value


func state_hash() -> String:
	var bytes := PackedByteArray()
	CanonicalBytes.append_string(bytes, JSON.stringify(_stable([origin, current_tick, chemistry_enabled, next_cast_id, next_product_id, next_ground_part_id, cells, casts, products, pending, sources, exposure, flow_carry, metrics])))
	return CanonicalBytes.sha256_hex(bytes)
