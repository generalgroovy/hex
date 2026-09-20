from pathlib import Path
p=Path(__file__).parent/'src/sim/hex/hex_chemistry_world.gd'
s=p.read_text(encoding='utf-8')
def replace(name, body):
    global s
    start=s.index('func '+name+'(')
    if s[max(0,start-7):start]=='static ': start-=7
    end=s.find('\nfunc ',start+5)
    static_end=s.find('\nstatic func ',start+5)
    if static_end>=0 and (end<0 or static_end<end): end=static_end
    if end<0:end=len(s)
    s=s[:start]+body.strip()+'\n\n'+s[end:]

replace('view',r'''
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
''')
replace('render_regions',r'''
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
			for part: Dictionary in record.get("ground_parts", {}).values():
				if not part.coverage.has(cell) or tick >= int(part.expiry_tick): continue
				var phase := "forming" if tick < int(part.created) + IGNITION_TICKS else "decaying" if tick >= int(part.expiry_tick) - COOLING_TICKS else "active"
				if material == "fire": phase = "ignition" if phase == "forming" else "cooling" if phase == "decaying" else phase
				result.append({"footprint_id": int(part.id), "polygon": whole_cell_polygon(cell), "phase": phase,
					"danger": material == "fire" and phase == "active", "intensity": 1000, "quantity": int(part.cells[cell]),
					"owner": int(record.owner), "source_ids": [int(record.source)], "expiry_tick": int(part.expiry_tick),
					"recipe_wire_id": 0, "direction": record.aim, "material": material})
	return result
''')
replace('deposit_terminal',r'''
func deposit_terminal(event: Dictionary, tick: int) -> void:
	var source := int(event.get("source_cast_id", 0))
	if not sources.has(source): return
	var record: Dictionary = casts[int(sources[source])]
	var entity_id := int(event.get("projectile_id", source))
	if not bool(record.paid) or not Parts.validate(record) or not record.flight_parts.has(entity_id): return
	assert(int(event.source_wire_id) == int(record.wire) and int(event.reaction_strength) == int(record.strength), "terminal cannot mutate immutable provenance")
	var shape := terminal_footprint(event, record)
	var selected := HexFootprint.selected_cells(shape, origin, cells)
	if selected.is_empty():
		var expired: int = Parts.expire_flight(record, entity_id)
		metrics.matter_expired += maxi(0, expired)
		_sync_cast_ledger(record)
		return
	_try_modifier(record, selected, tick)
	if not record.flight_parts.has(entity_id): return
	record.aim = event.get("direction", record.aim)
	var expiry := tick + ingredient_lifetime(int(record.element))
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

static func ingredient_lifetime(element: int) -> int:
	return WATER_TICKS if element == WATER else FIRE_TICKS if element == FIRE else 720

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
''')
replace('_recipe_wire',r'''
static func _recipe_wire(first_element: int, second_element: int) -> int:
	return Policy.recipe_wire(first_element, second_element)
''')
replace('_product_material',r'''
static func _product_material(recipe_wire_id: int) -> String:
	return Policy.product_layer(recipe_wire_id)
''')
replace('_layer',r'''
static func _layer(record: Dictionary) -> String:
	return Policy.ingredient_layer(int(record.element))
''')
replace('_sync_consumed_cast',r'''
func _sync_consumed_cast(record: Dictionary) -> void:
	Parts.retile_after_contact(record, int(record.unallocated), int(record.ground))
	_sync_cast_ledger(record)
	_rebuild_cast_layers(record)
''')
replace('_expire_live',r'''
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
''')
replace('expire_at',r'''
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
''')
replace('sync_flights',r'''
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
''')
# Membership is independent of finite integer cell allocation.
s=s.replace('HexFootprint.shared_selected_contact(record.cells, other.cells, origin, point)', 'HexFootprint.shared_selected_contact(coverage(record), coverage(other), origin, point)')
s=s.replace('HexFootprint.contains_selected(record.cells, origin, point)', 'HexFootprint.contains_selected(coverage(record), origin, point)')
s=s.replace('if int(record.cells.get(cell, 0)) > 0: return true', 'if coverage(record).has(cell): return true')
s=s.replace('if product.cells.has(cell) and int(product.cells[cell]) > 0:', 'if coverage(product).has(cell):')
s=s.replace('\t\tvar heating := int(record.element) == FIRE', '\t\tif int(record.element) not in [WATER, FIRE]: continue\n\t\tvar heating := int(record.element) == FIRE')
s=s.replace('\t\t_sync_cast_ledger(record)\n\t\trecord.reacted = true','\t\t_sync_consumed_cast(record)\n\t\trecord.reacted = true')
s=s.replace('var footprint := HexFootprint.disk(point, MEDIUM_RADIUS)', 'var footprint := Policy.selection_shape(recipe_wire_id, point, _oldest_source_aim([source_a, source_b]))')
s=s.replace('assert(quantity > 0, "admitted budget600 strength contact always transfers positive matter")','if quantity == 0:\n\t\treturn outcome # Positive strength subtraction can round to zero after partial expiry.')
s=s.replace('\t\tif amount > 0:\n\t\t\tresult[ordered[index]] = amount','\t\tresult[ordered[index]] = amount')
s=s.replace('\t\tassert(amount > 0, "product stock must cover every selected cell")\n','')
s=s.replace('product.cells = {}\n', 'product.cells = {}\n\tproduct.coverage = {}\n')
s=s.replace('\t\tproduct.cells[selected[index]] = amount', '\t\tproduct.cells[selected[index]] = amount\n\t\tproduct.coverage[selected[index]] = 1')
s=s.replace('[origin, current_tick, chemistry_enabled, next_cast_id, next_product_id,', '[origin, current_tick, chemistry_enabled, next_cast_id, next_product_id, next_ground_part_id,')
p.write_text(s,encoding='utf-8',newline='\n')
