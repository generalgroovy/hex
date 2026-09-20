class_name HexCourt
extends RefCounted
@warning_ignore_start("integer_division")

const Grid = preload("res://src/sim/hex/hex_grid.gd")
const StrengthLedger = preload("res://src/sim/combat/strength_budget.gd")
const ORIGIN := Vector2i(640_000, 480_000)
const RADIUS := 6
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

var origin := ORIGIN
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
var metrics := {"requested": 0, "admitted": 0, "refused": 0, "deposited": 0, "reactions": 0, "modifiers": 0, "matter_paid": 0, "matter_consumed": 0, "matter_expired": 0, "exposure_queries": 0}


func _init() -> void:
	for cell: Vector2i in Grid.disk(Vector2i.ZERO, RADIUS):
		cells[cell] = {"terrain": 0, "elevation": 0, "structure": 0, "water": {}, "fire": {}, "steam": {}, "conflagration": {}, "flood": {}}


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
	var result := {"water_quantity": 0, "fire_quantity": 0, "steam_quantity": 0, "conflagration_quantity": 0, "flood_quantity": 0, "fire_phase": "none", "steam_heat": 1000}
	if not cells.has(cell):
		return result
	var record: Dictionary = cells[cell]
	var phase_rank := 0
	for layer: String in ["water", "fire"]:
		for id: int in record[layer]:
			if not casts.has(id) or tick >= int(casts[id].expires):
				continue
			result[layer + "_quantity"] += int(record[layer][id])
			if layer == "fire":
				var phase := _fire_phase(casts[id], int(tick))
				var rank := {"none": 0, "cooling": 1, "ignition": 2, "active": 3}[phase] as int
				if rank > phase_rank:
					phase_rank = rank
					result.fire_phase = phase
	for layer: String in ["steam", "conflagration", "flood"]:
		for id: int in record[layer]:
			if not products.has(id) or tick >= int(products[id].expiry_tick):
				continue
			var previous_quantity: int = int(result[layer + "_quantity"])
			result[layer + "_quantity"] += int(record[layer][id])
			if layer == "steam":
				result.steam_heat = int(products[id].intensity) if previous_quantity == 0 else maxi(int(result.steam_heat), int(products[id].intensity))
	return result


func admission_reason(wire_id: int) -> String:
	if not chemistry_enabled:
		return "hex_court_preparation"
	var definition := CombatTuning.cast_definition(wire_id)
	if int(definition.get("element_wire_id", 0)) not in [WATER, FIRE] or not COVERAGE.has(family(wire_id)):
		return "hex_water_fire_only"
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
	casts[id] = {"id": id, "owner": owner_id, "wire": wire_id, "element": int(definition.element_wire_id), "strength": int(definition.reaction_strength), "budget": MATTER_PER_CAST, "unallocated": MATTER_PER_CAST, "ground": 0, "consumed": 0, "expired": 0, "paid": false, "source": 0, "reacted": false, "ledger": {}, "cells": {}, "created": current_tick, "expires": 0, "origin": origin}
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


func bind_release(owner_id: int, source_cast_id: int, release_origin: Vector2i = ORIGIN, release_aim: Vector2i = Vector2i(0, -1000)) -> void:
	if not pending.has(owner_id):
		return
	var id: int = pending[owner_id]
	var record: Dictionary = casts[id]
	assert(record.paid and source_cast_id > 0 and not sources.has(source_cast_id), "release must bind one paid unique runtime source")
	record.source = source_cast_id
	record.origin = release_origin
	record.aim = release_aim
	record.ledger = StrengthLedger.make(source_cast_id, int(record.strength), MATTER_PER_CAST)
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
	return HexFootprint.selected_cells(terminal_footprint(event, record), origin, cells)


# Presentation and previews consume the same stored whole-cell coverage as gameplay.
func render_regions(cell: Vector2i, material: String, tick: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not cells.has(cell) or material not in ["water", "fire", "steam", "conflagration", "flood"]: return result
	if _render_polygon_revision != value_revision:
		_render_polygons.clear()
		_render_polygon_revision = value_revision
	for id: int in cells[cell][material]:
		var record: Dictionary = products.get(id, {}) if material in ["steam", "conflagration", "flood"] else casts.get(id, {})
		var expiry: int = int(record.get("expiry_tick", record.get("expires", 0)))
		if record.is_empty() or tick >= expiry or not record.has("footprint"): continue
		var cache_key := "%s:%d:%d:%d" % [material, id, cell.x, cell.y]
		if not _render_polygons.has(cache_key):
			_render_polygons[cache_key] = whole_cell_polygon(cell)
		var polygon: PackedVector2Array = _render_polygons[cache_key]
		var phase := "active"
		if material == "water":
			if tick < int(record.created) + IGNITION_TICKS: phase = "forming"
			elif tick >= int(record.expires) - COOLING_TICKS: phase = "decaying"
		elif material == "fire": phase = _fire_phase(record, int(tick))
		elif material in ["steam", "conflagration", "flood"] and tick < int(record.active_tick): phase = "forming"
		elif material in ["steam", "conflagration", "flood"] and tick >= int(record.decay_tick): phase = "decaying"
		result.append({"footprint_id": id, "polygon": polygon, "phase": phase,
			"danger": material in ["steam", "conflagration", "flood"] and phase == "active" or material == "fire" and phase == "active",
			"intensity": int(record.get("intensity", 1000)), "owner": int(record.get("owner", 0)), "source_ids": record.get("source_ids", []), "expiry_tick": expiry,
			"recipe_wire_id": int(record.get("recipe_wire_id", 0)),
			"direction": record.get("flow_aim", Vector2i(0, -1000)),
			"material": material})
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
	if not sources.has(source):
		return
	var id: int = sources[source]
	var record: Dictionary = casts[id]
	if not record.paid or not StrengthLedger.validate(record.ledger) or int(record.ledger.flight_quantity) <= 0:
		return # Fragments, duplicate terminal events and trails share this spend.
	assert(int(event.source_wire_id) == int(record.wire) and int(event.reaction_strength) == int(record.strength), "terminal cannot mutate immutable provenance")
	record.footprint = terminal_footprint(event, record)
	record.aim = event.get("direction", Vector2i(0, -1000))
	var selected := HexFootprint.selected_cells(record.footprint, origin, cells)
	if selected.is_empty():
		_expire_live(record) # A paid shot may legitimately miss the court.
		return
	_try_modifier(record, selected, tick)
	if int(record.ledger.flight_quantity) <= 0:
		return
	record.created = tick
	record.expires = tick + (WATER_TICKS if int(record.element) == WATER else FIRE_TICKS)
	var amount: int = StrengthLedger.deposit(record.ledger)
	assert(amount > 0, "one terminal moves one remaining flight allocation")
	_sync_cast_ledger(record)
	var layer := _layer(record)
	for index: int in selected.size():
		var quantity := amount / selected.size() + int(index < amount % selected.size())
		assert(quantity > 0, "authored paid stock must cover every selected cell")
		var cell: Vector2i = selected[index]
		cells[cell][layer][id] = quantity
		record.cells[cell] = quantity
	metrics.deposited += 1
	value_revision += 1
	_try_ground_reactions(record, event.position, tick)


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
		var witness: Dictionary = HexFootprint.shared_selected_contact(record.cells, other.cells, origin, point)
		if witness.is_empty():
			continue
		resolve_contact(int(record.source), int(other.source), witness.point, tick)


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
		if int(product.recipe_wire_id) != STEAM_WIRE:
			continue
		var heating := int(record.element) == FIRE
		if int(product.expiry_tick) <= tick or int(record.source) in product.source_ids or bool(product.heated if heating else product.cooled):
			continue
		var touches := false
		for cell: Vector2i in selected:
			if product.cells.has(cell) and int(product.cells[cell]) > 0:
				touches = true
				break
		if not touches:
			continue
		var consumed_strength: int = int(record.ledger.remaining_strength)
		var amount: int = StrengthLedger.consume_remaining(record.ledger)
		if amount <= 0:
			continue
		_sync_cast_ledger(record)
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


func resolve_contact(source_a: int, source_b: int, point: Vector2i, tick: int) -> Dictionary:
	if source_a == source_b or not sources.has(source_a) or not sources.has(source_b):
		return {"accepted": false, "reason": &"unknown_source"}
	var first: Dictionary = casts.get(int(sources[source_a]), {})
	var second: Dictionary = casts.get(int(sources[source_b]), {})
	if first.is_empty() or second.is_empty() or not bool(first.paid) or not bool(second.paid):
		return {"accepted": false, "reason": &"invalid_source"}
	var recipe_wire_id: int = _recipe_wire(int(first.element), int(second.element))
	if recipe_wire_id == 0:
		return {"accepted": false, "reason": &"unsupported_pair"}
	var footprint := HexFootprint.disk(point, MEDIUM_RADIUS)
	var selected := HexFootprint.selected_cells(footprint, origin, cells)
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
	assert(quantity > 0, "admitted budget600 strength contact always transfers positive matter")
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
	products[id] = {
		"id": id,
		"recipe_wire_id": recipe_wire_id,
		"material": material,
		"strength": matched_strength,
		"source_ids": parent_sources.duplicate(),
		"footprint": HexFootprint.disk(point, MEDIUM_RADIUS),
		"cells": allocations,
		"quantity": quantity,
		"created": tick,
		"formation_tick": tick,
		"active_tick": tick + MEDIUM_FORMATION_TICKS,
		"decay_tick": tick + MEDIUM_FORMATION_TICKS + MEDIUM_ACTIVE_TICKS,
		"expiry_tick": tick + MEDIUM_FORMATION_TICKS + MEDIUM_ACTIVE_TICKS + MEDIUM_DECAY_TICKS,
		"expires": tick + MEDIUM_FORMATION_TICKS + MEDIUM_ACTIVE_TICKS + MEDIUM_DECAY_TICKS,
		"intensity": mini(1500, matched_strength * 100),
		"heated": false,
		"cooled": false,
		"flow_aim": oldest_aim,
		"flow_units_per_second": 40_000 if recipe_wire_id == FLOOD_WIRE else 0,
		"common_wall_clearance": 18_000 if recipe_wire_id == FLOOD_WIRE else 0,
		"pulse_ms": 600 if recipe_wire_id == CONFLAGRATION_WIRE else 0,
		"pulse_damage": 8_000 if recipe_wire_id == CONFLAGRATION_WIRE else 0,
		"geometry_override": "medium_disk_64000",
	}
	for cell: Vector2i in allocations:
		cells[cell][material][id] = int(allocations[cell])
	return id


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
	if first_element == FIRE and second_element == FIRE:
		return CONFLAGRATION_WIRE
	if first_element == WATER and second_element == WATER:
		return FLOOD_WIRE
	if first_element in [FIRE, WATER] and second_element in [FIRE, WATER]:
		return STEAM_WIRE
	return 0


static func _product_material(recipe_wire_id: int) -> String:
	return String({CONFLAGRATION_WIRE: "conflagration", STEAM_WIRE: "steam", FLOOD_WIRE: "flood"}.get(recipe_wire_id, ""))


static func _equal_allocations(selected: Array[Vector2i], quantity: int) -> Dictionary:
	var ordered := selected.duplicate()
	ordered.sort_custom(Grid._cell_less)
	var result := {}
	for index: int in ordered.size():
		var amount := quantity / ordered.size() + int(index < quantity % ordered.size())
		if amount > 0:
			result[ordered[index]] = amount
	return result


func _sync_consumed_cast(record: Dictionary) -> void:
	var old_ground: int = int(record.ground)
	var new_ground: int = int(record.ledger.deposited_quantity)
	if old_ground != new_ground:
		_retile_cast_proportionally(record, old_ground, new_ground)
	_sync_cast_ledger(record)


func _sync_cast_ledger(record: Dictionary) -> void:
	record.unallocated = int(record.ledger.flight_quantity)
	record.ground = int(record.ledger.deposited_quantity)
	record.consumed = int(record.ledger.consumed_quantity)
	record.expired = int(record.ledger.expired_quantity)


func _retile_cast_proportionally(record: Dictionary, old_total: int, new_total: int) -> void:
	assert(old_total >= new_total and old_total > 0, "partial contact only subtracts deposited matter")
	var ordered: Array[Vector2i] = []
	for cell: Vector2i in record.cells:
		ordered.append(cell)
	ordered.sort_custom(Grid._cell_less)
	var old_allocations: Dictionary = record.cells.duplicate(true)
	for cell: Vector2i in ordered:
		cells[cell][_layer(record)].erase(int(record.id))
	record.cells.clear()
	var cumulative_old := 0
	var cumulative_new := 0
	for cell: Vector2i in ordered:
		cumulative_old += int(old_allocations[cell])
		var next_cumulative: int = new_total * cumulative_old / old_total
		var amount: int = next_cumulative - cumulative_new
		cumulative_new = next_cumulative
		if amount <= 0:
			continue
		record.cells[cell] = amount
		cells[cell][_layer(record)][int(record.id)] = amount
	assert(cumulative_new == new_total, "proportional retile preserves the exact deposited remainder")
	value_revision += 1


func _expire_live(record: Dictionary) -> int:
	if not record.has("ledger") or record.ledger.is_empty():
		_expire_unallocated(record)
		return 0
	var moved: int = StrengthLedger.expire(record.ledger)
	if moved < 0:
		return moved
	if not record.cells.is_empty():
		for cell: Vector2i in record.cells:
			cells[cell][_layer(record)].erase(int(record.id))
		record.cells.clear()
	_sync_cast_ledger(record)
	if bool(record.paid):
		metrics.matter_expired += moved
	if moved > 0:
		value_revision += 1
	return moved


func _retile_product(product: Dictionary, selected: Array[Vector2i]) -> void:
	var id: int = product.id
	var material: String = product.material
	for cell: Vector2i in product.cells:
		cells[cell][material].erase(id)
	selected.sort_custom(Grid._cell_less)
	product.cells = {}
	var total: int = product.quantity
	for index: int in selected.size():
		var amount := total / selected.size() + int(index < total % selected.size())
		assert(amount > 0, "product stock must cover every selected cell")
		product.cells[selected[index]] = amount
		cells[selected[index]][material][id] = amount


func _take_ground(record: Dictionary, cell: Vector2i, amount: int) -> void:
	assert(amount > 0 and int(record.cells.get(cell, 0)) >= amount)
	record.ground -= amount
	record.consumed += amount
	metrics.matter_consumed += amount
	var remaining: int = record.cells[cell] - amount
	if remaining == 0:
		record.cells.erase(cell)
		cells[cell][_layer(record)].erase(int(record.id))
	else:
		record.cells[cell] = remaining
		cells[cell][_layer(record)][int(record.id)] = remaining


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
	return HexFootprint.contains_selected(record.cells, origin, point)


func apply_product_effects(players: Array[PlayerState], tick: int, config: SimConfig, collision: CollisionWorld, events: Array[Dictionary], paths: Dictionary = {}) -> void:
	if not config.is_valid() or collision == null:
		return
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
				if actor.health <= 0 or actor.air_height > 0 or not _ground_path_touches(product, actor, paths):
					continue
				var damage: int = int(product.pulse_damage) * int(product.intensity) / 1000
				if damage > 0 and PlayerResourcesSystem.damage(actor, damage, config):
					events.append({"type": "hex_conflagration", "entity_id": actor.entity_id, "product_id": product_id, "amount": damage})
		elif recipe_wire_id == FLOOD_WIRE:
			for actor: PlayerState in players:
				if actor.spawn_protection_ticks > 0 or MovementSystem.is_combat_intangible(actor, config): continue
				if actor.health <= 0 or actor.air_height > 0 or not _ground_path_touches(product, actor, paths):
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


func _ground_path_touches(record: Dictionary, actor: PlayerState, paths: Dictionary) -> bool:
	var finish := Vector2i(actor.position_x, actor.position_y)
	var previous: Variant = paths.get(actor.entity_id, finish)
	var start: Vector2i = previous if previous is Vector2i else previous.point
	if previous is Dictionary and int(previous.height) > 0: start = finish
	return bool(HexFootprint.selected_segment_interval(record.cells, origin, start, finish).get("hit", false))


func _clear_product_flow_carry(product_id: int) -> void:
	var prefix := "%d:" % product_id
	for key: String in flow_carry.keys():
		if key.begins_with(prefix):
			flow_carry.erase(key)


func expire_at(tick: int) -> void:
	current_tick = tick
	for id: int in casts.keys():
		var record: Dictionary = casts[id]
		if int(record.expires) > 0 and tick >= int(record.expires) and int(record.ground) > 0:
			_expire_live(record)
			if int(record.unallocated) == 0:
				sources.erase(int(record.source))
				casts.erase(id)
	for id: int in products.keys():
		var product: Dictionary = products[id]
		if tick >= int(product.expiry_tick):
			for cell: Vector2i in product.cells:
				cells[cell][product.material].erase(id)
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
	var touched := Grid.swept_cells(start - origin, finish - origin, 0)
	metrics.exposure_queries += 1
	var steam_density := {}
	var fire_damage := 0
	for cell: Vector2i in touched:
		if not cells.has(cell) or not bool(HexFootprint.selected_segment_interval({cell: 1}, origin, start, finish).get("hit", false)):
			continue
		var record: Dictionary = cells[cell]
		if actor.air_height == 0:
			for cast_id: int in record.fire:
				if casts.has(cast_id) and _fire_phase(casts[cast_id], tick) == "active" :
					fire_damage = maxi(fire_damage, 4000 * int(record.fire[cast_id]) / MATTER_PER_CAST)
		if actor.air_height <= STEAM_HEIGHT:
			for product_id: int in record.steam:
				if tick < int(products[product_id].active_tick) or tick >= int(products[product_id].decay_tick): continue
				steam_density[product_id] = maxi(int(steam_density.get(product_id, 0)), int(record.steam[product_id]))
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
	for projectile: ProjectileState in projectiles:
		live[projectile.source_cast_id if projectile.source_cast_id > 0 else projectile.entity_id] = true
	var live_pending := {}
	for actor: PlayerState in players:
		if actor.health > 0 and actor.pending_cast_wire_id > 0:
			live_pending[actor.entity_id] = actor.pending_cast_wire_id
	for id: int in casts.keys():
		var record: Dictionary = casts[id]
		var has_ledger: bool = record.has("ledger") and not record.ledger.is_empty()
		if (has_ledger and int(record.ledger.flight_quantity) > 0) or (not has_ledger and int(record.unallocated) > 0):
			var in_startup := int(record.source) == 0 and int(live_pending.get(int(record.owner), 0)) == int(record.wire)
			if not in_startup and not live.has(int(record.source)):
				if has_ledger:
					_expire_live(record)
				else:
					_expire_unallocated(record)
		if int(record.ground) == 0 and int(record.unallocated) == 0:
			if int(pending.get(int(record.owner), 0)) == id:
				pending.erase(int(record.owner))
			sources.erase(int(record.source))
			casts.erase(id)


func conservation_valid() -> bool:
	# Validate both directions: an orphan or wrong-layer entry must not be
	# invisible to the cast-to-cell accounting walk below.
	for cell: Vector2i in cells:
		for layer: String in ["water", "fire"]:
			for id: int in cells[cell][layer]:
				if not casts.has(id) or _layer(casts[id]) != layer or int(casts[id].cells.get(cell, 0)) != int(cells[cell][layer][id]):
					return false
		for layer: String in ["steam", "conflagration", "flood"]:
			for id: int in cells[cell][layer]:
				if not products.has(id) or String(products[id].material) != layer or int(products[id].cells.get(cell, 0)) != int(cells[cell][layer][id]):
					return false
	var live := 0
	for id: int in casts:
		var record: Dictionary = casts[id]
		var total := 0
		for cell: Vector2i in record.cells:
			var amount: int = record.cells[cell]
			if int(cells[cell][_layer(record)].get(id, 0)) != amount or amount <= 0:
				return false
			total += amount
		if not record.has("ledger") or record.ledger.is_empty():
			if total != int(record.ground) or int(record.unallocated) + total + int(record.consumed) + int(record.expired) != int(record.budget):
				return false
		elif not StrengthLedger.validate(record.ledger) or total != int(record.ledger.deposited_quantity) or int(record.unallocated) != int(record.ledger.flight_quantity) or int(record.consumed) != int(record.ledger.consumed_quantity) or int(record.expired) != int(record.ledger.expired_quantity):
			return false
		if record.paid:
			live += int(record.unallocated) + total
	for id: int in products:
		var total := 0
		for cell: Vector2i in products[id].cells:
			if int(products[id].cells[cell]) <= 0 or int(cells[cell][products[id].material].get(id, 0)) != int(products[id].cells[cell]):
				return false
			total += int(products[id].cells[cell])
		if total != int(products[id].quantity):
			return false
	return live + int(metrics.matter_consumed) + int(metrics.matter_expired) == int(metrics.matter_paid)


static func _layer(record: Dictionary) -> String:
	return "water" if int(record.element) == WATER else "fire"


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
	CanonicalBytes.append_string(bytes, JSON.stringify(_stable([origin, current_tick, chemistry_enabled, next_cast_id, next_product_id, cells, casts, products, pending, sources, exposure, flow_carry, metrics])))
	return CanonicalBytes.sha256_hex(bytes)
