extends RefCounted
## Bounded, atomic paid fusion. One terminal can perform at most one upgrade;
## descendants inherit every spent pool, actor latch and earliest expiry.
@warning_ignore_start("integer_division")
const Funding = preload("res://src/sim/hex/hex_reaction_funding.gd")
const Policy = preload("res://src/sim/hex/hex_recipe_policy.gd")
const Footprint = preload("res://src/sim/hex/hex_footprint.gd")
const Budget = preload("res://src/sim/combat/strength_budget.gd")
const Damage = preload("res://src/sim/hex/hex_reaction_damage.gd")
const MAX_SOURCES := 12
const MAX_CONTACTS := 12


static func try_ingredient(world: HexChemistryWorld, record: Dictionary, selected: Array[Vector2i], point: Vector2i, tick: int) -> bool:
	if not bool(record.get("paid", false)) or not Budget.validate(record.get("ledger", {})): return false
	var strength := int(record.ledger.remaining_strength)
	if strength <= 0: return false
	var incoming := {}
	for cell: Vector2i in selected: incoming[cell] = 1
	var ids: Array = world.products.keys()
	ids.sort()
	for id: int in ids:
		var parent: Dictionary = world.products[id]
		if tick >= int(parent.decay_tick) or int(record.source) in parent.source_ids: continue
		var old_mask := int(parent.element_mask)
		var mask := old_mask | int(record.get("element_mask",Policy.element_bit(int(record.element))))
		if mask == old_mask: continue
		var witness := Footprint.shared_selected_contact(incoming, world.coverage(parent), world.origin, point)
		if witness.is_empty(): continue
		var sources: Array = parent.source_ids.duplicate()
		sources.append(int(record.source))
		var plan := _plan(world, [parent], sources, mask, witness.point, tick)
		if plan.is_empty(): continue
		var funded := int(parent.funded_strength) + strength
		if funded > Damage.MAX_FUNDED_STRENGTH: continue
		var funding := Funding.add(plan.inherited.source_funding, int(record.source), int(record.wire), strength)
		if funding.is_empty(): continue
		plan.inherited.source_funding = funding
		# No mutation precedes all geometry, capacity, lifetime and provenance checks.
		var quantity := Budget.consume_remaining(record.ledger)
		if quantity <= 0: return false
		world._sync_consumed_cast(record)
		record.reacted = true
		world.metrics.matter_consumed += quantity
		_commit(world, [parent], plan, mini(int(parent.strength), strength), int(parent.quantity) + quantity,
			funded, int(parent.damage_budget_remaining) + strength * Damage.DAMAGE_PER_STRENGTH, tick)
		return true
	return false


static func try_products(world: HexChemistryWorld, product_id: int, tick: int) -> int:
	if not world.products.has(product_id): return product_id
	var incoming: Dictionary = world.products[product_id]
	var ids: Array = world.products.keys()
	ids.sort()
	for other_id: int in ids:
		if other_id == product_id: continue
		var other: Dictionary = world.products[other_id]
		if tick >= int(other.decay_tick): continue
		var first_mask := int(incoming.element_mask)
		var second_mask := int(other.element_mask)
		var mask := first_mask | second_mask
		# Both parents contribute a new element. Recasting a subset cannot refresh.
		if mask == first_mask or mask == second_mask: continue
		var sources: Array = incoming.source_ids.duplicate()
		var shared := false
		for source: int in other.source_ids:
			if source in sources: shared = true; break
			sources.append(source)
		if shared: continue
		var witness := Footprint.shared_selected_contact(world.coverage(incoming), world.coverage(other), world.origin, incoming.position)
		if witness.is_empty(): continue
		var plan := _plan(world, [incoming, other], sources, mask, witness.point, tick)
		if plan.is_empty(): continue
		var funded := int(incoming.funded_strength) + int(other.funded_strength)
		if funded > Damage.MAX_FUNDED_STRENGTH: continue
		return _commit(world, [incoming, other], plan, mini(int(incoming.strength), int(other.strength)),
			int(incoming.quantity) + int(other.quantity), funded,
			int(incoming.damage_budget_remaining) + int(other.damage_budget_remaining), tick)
	return product_id


static func _plan(world: HexChemistryWorld, parents: Array, sources: Array, mask: int, point: Vector2i, tick: int) -> Dictionary:
	if sources.size() > MAX_SOURCES: return {}
	sources.sort()
	for index: int in sources.size():
		if int(sources[index]) <= 0 or index > 0 and sources[index] == sources[index - 1]: return {}
	var wire := Policy.wire_for_mask(mask)
	if wire <= 0: return {}
	var policy := Policy.runtime_definition(wire)
	# Historical sources may already be retired by sync_flights. The product's
	# immutable ownership and aim are the authority for its descendants.
	var dominant: Dictionary = parents[0]
	for parent: Dictionary in parents:
		if int(parent.ancestry_created_tick) < int(dominant.ancestry_created_tick) or (int(parent.ancestry_created_tick) == int(dominant.ancestry_created_tick) and int(parent.id) < int(dominant.id)):
			dominant = parent
	var funding := Funding.merge(parents)
	if funding.is_empty(): return {}
	var inherited := {"owner": int(dominant.owner), "team": int(dominant.team), "flow_aim": Vector2i(dominant.flow_aim), "source_funding": funding}
	var shape := Policy.selection_shape(wire, point, inherited.flow_aim)
	var selected := world.select_cells(shape)
	if selected.is_empty(): return {}
	var expiry := 2_147_483_647
	var ancestry := tick
	var contacts := {}
	for parent: Dictionary in parents:
		expiry = mini(expiry, int(parent.expiry_tick))
		ancestry = mini(ancestry, int(parent.ancestry_created_tick))
		for actor_id: int in parent.contacts:
			var used := bool(parent.contacts[actor_id].get("effect_used", false))
			if contacts.has(actor_id): used = used or bool(contacts[actor_id].effect_used)
			contacts[actor_id] = {"inside": false, "entered": -1, "last_pulse": -1, "effect_used": used}
	if contacts.size() > MAX_CONTACTS: return {}
	var active := tick + int(policy.formation_ticks)
	# Full warning and one active tick take priority over a harmless fade.
	# Never extend the earliest ancestor expiry to fit a larger combination.
	if expiry - active < 2: return {}
	var decay_tail := mini(int(policy.decay_ticks), expiry - active - 1)
	var decay := mini(active + int(policy.active_ticks), expiry - maxi(1, decay_tail))
	if decay <= active: return {}
	return {"wire": wire, "mask": mask, "sources": sources, "point": point, "selected": selected,
		"expiry": expiry, "decay": decay, "ancestry": ancestry, "contacts": contacts, "inherited": inherited}


static func _commit(world: HexChemistryWorld, parents: Array, plan: Dictionary, strength: int, quantity: int, funded: int, remaining: int, tick: int) -> int:
	for parent: Dictionary in parents:
		var id := int(parent.id)
		for cell: Vector2i in parent.cells: world.erase_cell_amount(cell, String(parent.material), id)
		world._clear_product_flow_carry(id)
		world.products.erase(id)
	var product_id := world._create_product(int(plan.wire), plan.sources, plan.point, plan.selected, strength, quantity, tick, plan.inherited)
	var product: Dictionary = world.products[product_id]
	product.element_mask = int(plan.mask)
	product.ancestry_created_tick = int(plan.ancestry)
	product.funded_strength = funded
	product.damage_budget_remaining = remaining
	product.contacts = plan.contacts
	product.decay_tick = int(plan.decay)
	product.expiry_tick = int(plan.expiry)
	product.expires = int(plan.expiry)
	world.metrics.reactions += 1
	world.value_revision += 1
	return product_id
