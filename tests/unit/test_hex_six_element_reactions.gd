extends FluxTestSuite

const Policy = preload("res://src/sim/hex/hex_recipe_policy.gd")
const Effects = preload("res://src/sim/hex/hex_product_effects.gd")
const Fusion = preload("res://src/sim/hex/hex_reaction_fusion.gd")
const Damage = preload("res://src/sim/hex/hex_reaction_damage.gd")
const Funding = preload("res://src/sim/hex/hex_reaction_funding.gd")
const Snapshot = preload("res://src/net/hex_world_snapshot.gd")
const ChemistrySnapshot = preload("res://src/net/hex_chemistry_snapshot.gd")
const CENTER := Vector2i(800_000, 800_000)
var config := SimConfig.new(120)
var catalog := AbilityCatalog.new()


func run() -> int:
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "live six-element spell catalog loads")
	_test_all_definitions_and_paid_reachability()
	_test_actual_pool_with_perks_and_protection()
	_test_transfer_and_refusals()
	_test_permutation_reachability()
	_test_product_partitions()
	_test_self_product_upgrades()
	_test_partial_source_funding()
	_test_split_fusion_revalidates_queued_siblings()
	_test_legacy_network_admission()
	_test_fusion_warning_boundary()
	_test_composite_snapshot_lifetime_boundaries()
	_test_inherited_pair_snapshot_routes()
	return finish("hex-six-element-reactions")


func _test_all_definitions_and_paid_reachability() -> void:
	equal(Policy.active_wire_ids().size(), 63, "all57 distinct subsets plus6 self reactions are authored")
	equal(HexChemistryWorld.material_layers().slice(0, 6), ["water", "fire", "wind", "earth", "light", "dark"], "authority material order matches the canonical renderer surface")
	var seen := {}
	var forming_snapshots := 0
	var active_snapshots := 0
	for wire: int in Policy.active_wire_ids():
		var definition := Policy.runtime_definition(wire)
		check(not definition.is_empty() and definition.is_read_only(), "%d immutable executable definition" % wire)
		check(int(definition.pulse_damage) > 0, "%d has an actual damaging attack" % wire)
		check(not String(definition.purpose).is_empty() and not String(definition.counter).is_empty(), "%d has role and counter" % wire)
		check(int(definition.archive_recipe_wire) >= 301 and int(definition.archive_recipe_wire) <= 336, "%d uses retained art without adding selectable elements" % wire)
		var fixture := _form(definition.elements)
		var world: HexChemistryWorld = fixture.world
		var product: Dictionary = fixture.product
		if product.is_empty(): continue
		equal(int(product.recipe_wire_id), wire, "%d is reached by paid real terminal inputs" % wire)
		equal(int(product.quantity), definition.elements.size() * 600, "%d transfers exactly all paid source matter" % wire)
		equal(int(product.funded_strength), definition.elements.size() * 5, "%d records actual Bolt strength contributions" % wire)
		equal(Funding.total(product.source_funding), int(product.funded_strength), "%d funding triples sum to the exact scalar" % wire)
		equal(product.source_funding.size(), product.source_ids.size() * 3, "%d preserves one funding triple per source" % wire)
		equal(int(product.damage_budget_remaining), definition.elements.size() * 20_000, "%d has linear finite damage capacity" % wire)
		check(world.conservation_valid(), "%d all source and product quantities conserve" % wire)
		seen[wire] = true
		if wire > 400 and _complete_snapshot_roundtrip(world, null, "%d forming" % wire): forming_snapshots += 1
		var actor := _actor(90)
		var point := _inside(world, product)
		actor.position_x = point.x; actor.position_y = point.y
		actor.velocity_x = 3000 # Mirrorwater and moving-trigger controls are reachable.
		var health_before := actor.health
		var events: Array[Dictionary] = []
		var first := int(product.active_tick)
		var last := int(product.decay_tick) - 1
		for tick: int in range(first, last + 1):
			var previous := Vector2i(actor.position_x, actor.position_y)
			# Keep current-driven fixtures in their exact selected cell.
			actor.position_x = point.x; actor.position_y = point.y
			if wire == 321 and tick > first:
				actor.position_x = CENTER.x + 600_000
			world.apply_product_effects([actor], tick, config, CollisionWorld.new(2_000_000, 2_000_000), events, {actor.entity_id: previous})
			world.advance([actor], {actor.entity_id: {"point": previous, "height": 0}}, tick, config, events)
			if actor.health < health_before: break
		check(actor.health < health_before, "%d delivers actual Health loss through live product effect route" % wire)
		equal(int(product.damage_budget_remaining), definition.elements.size() * 20_000 - (health_before - actor.health), "%d debits actual realized Health loss" % wire)
		if wire > 400 and _complete_snapshot_roundtrip(world, actor, "%d after actual effect" % wire): active_snapshots += 1
		var pool := int(product.damage_budget_remaining)
		var protected := _actor(91)
		protected.spawn_protection_ticks = 20
		protected.position_x = point.x; protected.position_y = point.y
		world.apply_product_effects([protected], last, config, CollisionWorld.new(2_000_000, 2_000_000), [], {})
		equal(protected.health, 1_000_000, "%d respects spawn protection" % wire)
		equal(int(product.damage_budget_remaining), pool, "%d protection cannot spend or refresh pool" % wire)
	equal(seen.size(), 63, "every authored recipe had a funded runtime witness")
	equal(forming_snapshots, 42, "all42 actual paid composites roundtrip complete authority during formation")
	equal(active_snapshots, 42, "all42 actual paid composites roundtrip complete authority after their actual attack")
	for retired: int in [5, 6]:
		for active: int in [1, 2, 3, 4, 7, 8]: equal(Policy.recipe_wire(retired, active), 0, "retired selectable ingredient refuses")


func _test_actual_pool_with_perks_and_protection() -> void:
	for identity: int in [0, 15, 19]:
		var product := {"damage_budget_remaining": 1001}
		var actor := _actor(2)
		actor.champion_wire_id = identity
		actor.health_maximum = 1_000_000
		actor.cast_recovery_ticks = 2
		var before := actor.health
		var actual := Damage.apply(product, actor, 100_000, config)
		check(actual > 0 and actual <= 1001, "mitigation/vulnerability never exceeds exact shared pool")
		equal(actual, before - actor.health, "pool debit uses actual pre-hit perk window Health delta")
		equal(int(product.damage_budget_remaining), 1001 - actual, "exact finite remainder survives rounding")
		while int(product.damage_budget_remaining) > 0: Damage.apply(product, actor, 100_000, config)
		equal(Damage.apply(product, actor, 10_000, config), 0, "exhausted pool cannot mint damage")
	var lethal := _actor(3)
	lethal.health = 7
	var product := {"damage_budget_remaining": 100}
	equal(Damage.apply(product, lethal, 10_000, config), 7, "lethal loss spends only remaining Health")
	equal(product.damage_budget_remaining, 93, "overkill leaves the exact unspent pool")


func _test_transfer_and_refusals() -> void:
	var fixture := _form([1, 2])
	var world: HexChemistryWorld = fixture.world
	var parent: Dictionary = fixture.product
	var parent_id := int(parent.id)
	var expiry := int(parent.expiry_tick)
	parent.damage_budget_remaining = 1234
	world.sync_flights([], [])
	check(world.sources.is_empty(), "real tick cleanup retires consumed source records before later fusion")
	parent.contacts[90] = {"inside": true, "entered": int(parent.active_tick), "last_pulse": int(parent.active_tick), "effect_used": true}
	_deposit(world, 3, 3, _inside(world, parent), 3)
	equal(world.products.size(), 1, "one ingredient upgrade atomically replaces its parent")
	check(not world.products.has(parent_id), "spent parent cannot remain damaging in parallel")
	var child: Dictionary = world.products.values()[0]
	equal(child.recipe_wire_id, 407, "Earth Fire Water mask has exact stable wire")
	equal(child.damage_budget_remaining, 21_234, "fusion carries unspent parent pool plus fresh paid strength only")
	equal(child.expiry_tick, expiry, "fusion does not extend earliest expiry")
	equal(child.owner, parent.owner, "retired source cleanup cannot change child owner")
	equal(child.team, parent.team, "retired source cleanup cannot change child team")
	equal(child.flow_aim, parent.flow_aim, "retired source cleanup cannot rotate a descendant corridor")
	check(bool(child.contacts[90].effect_used), "fusion inherits spent actor crossing latch")
	var before_quantity := int(child.quantity)
	var before_pool := int(child.damage_budget_remaining)
	_deposit(world, 4, 1, _inside(world, child), 4)
	equal(int(world.products[int(child.id)].quantity), before_quantity, "already-present element cannot upgrade or refresh compound")
	equal(int(world.products[int(child.id)].damage_budget_remaining), before_pool, "duplicate element does not mint pool")
	check(world.conservation_valid(), "refused duplicate remains ordinary paid material")
	var source: Dictionary = world.casts[int(world.sources[4])]
	var stock_before := int(source.ledger.remaining_strength)
	var selected: Array[Vector2i] = []
	for cell: Vector2i in child.coverage: selected.append(cell)
	check(not Fusion.try_ingredient(world, source, selected, child.position, expiry), "expired ancestor cannot be revived")
	equal(int(source.ledger.remaining_strength), stock_before, "lifetime refusal is atomic before source consumption")
	var spent := _actor(90)
	var fresh := _actor(91)
	var point := _inside(world, child)
	for actor: PlayerState in [spent, fresh]:
		actor.position_x = point.x; actor.position_y = point.y
	var pool_before := int(child.damage_budget_remaining)
	world.apply_product_effects([spent, fresh], int(child.active_tick), config, CollisionWorld.new(2_000_000, 2_000_000), [], {})
	equal(spent.health, 1_000_000, "new activation warning cannot refresh an inherited spent actor attack")
	equal(fresh.health, 995_500, "same activation still damages a fresh actor by the exact half-strength4500 quote")
	equal(int(child.damage_budget_remaining), pool_before - 4500, "only the eligible fresh actor spends the shared pool")
	check(bool(child.contacts[91].effect_used), "activation records its new actor latch for any descendant")


func _test_permutation_reachability() -> void:
	# All720 ordered six-input paths must reach the same mechanical contract;
	# contact position and world time remain legitimate order-dependent facts.
	var permutations: Array = []
	_permutations([1, 2, 3, 4, 7, 8], [], permutations)
	equal(permutations.size(), 720, "all six-element input orders enumerated")
	for order: Array in permutations:
		var fixture := _form(order)
		var product: Dictionary = fixture.product
		if product.is_empty(): continue
		equal(int(product.recipe_wire_id), 463, "input order%s reaches Convergence" % str(order))
		equal(int(product.damage_budget_remaining), 120_000, "ordering cannot increase six paid Bolt contributions")
		equal(int(product.quantity), 3600, "all input orders conserve six paid material stocks")


func _test_product_partitions() -> void:
	# Every unordered disjoint split with at least two elements on both sides.
	for mask: int in range(1, 64):
		var elements := Policy.elements_for_mask(mask)
		if elements.size() < 4: continue
		for left: int in range(1, mask):
			if (left & mask) != left: continue
			var right := mask ^ left
			if left >= right or Policy.elements_for_mask(left).size() < 2 or Policy.elements_for_mask(right).size() < 2: continue
			var world := _world()
			var a := _funded_product(world, Policy.wire_for_mask(left), 1)
			var b := _funded_product(world, Policy.wire_for_mask(right), 7)
			if a.is_empty() or b.is_empty(): continue
			world.sync_flights([], [])
			check(world.sources.is_empty(), "product partition keeps only historical provenance after cleanup")
			var expected_pool := int(a.damage_budget_remaining) + int(b.damage_budget_remaining)
			var result := Fusion.try_products(world, int(b.id), 10)
			equal(world.products.size(), 1, "disjoint partition atomically merges")
			equal(int(world.products[result].recipe_wire_id), 400 + mask, "partition union owns exact subset identity")
			equal(int(world.products[result].damage_budget_remaining), expected_pool, "partition cannot refresh damage")
			check(world.conservation_valid(), "partition conserves every paid source")


func _funded_product(world: HexChemistryWorld, wire: int, first_source: int) -> Dictionary:
	var definition := Policy.runtime_definition(wire)
	var sources: Array = []
	for index: int in definition.elements.size():
		var source := first_source + index
		var element := int(definition.elements[index])
		var spell := int(catalog.ability(catalog.spell_id_at(Policy.ingredient_layer(element), "bolt")).wire_id)
		check(world.reserve_cast(source, spell), "partition source reserves")
		world.commit_payment(source); world.bind_release(source, source, CENTER, Vector2i(1000, 0), 1)
		var record: Dictionary = world.casts[int(world.sources[source])]
		var quantity := StrengthBudget.consume_remaining(record.ledger)
		world._sync_consumed_cast(record); world.metrics.matter_consumed += quantity
		sources.append(source)
	var selected := world.select_cells(Policy.selection_shape(wire, CENTER, Vector2i(1000, 0)))
	var id := world._create_product(wire, sources, CENTER, selected, 5, sources.size() * 600, 1)
	var product: Dictionary = world.products[id]
	product.funded_strength = sources.size() * 5
	product.damage_budget_remaining = sources.size() * 20_000
	return product


func _form(elements: Array) -> Dictionary:
	var world := _world()
	for index: int in elements.size():
		var point := CENTER if world.products.is_empty() else _inside(world, world.products.values()[0])
		_deposit(world, index + 1, int(elements[index]), point, index + 1)
		world.sync_flights([], [])
	check(world.products.size() == 1, "paid recipe path%s forms exactly one final product" % str(elements))
	return {"world": world, "product": {} if world.products.is_empty() else world.products.values()[0]}


func _world() -> HexChemistryWorld:
	var world := HexChemistryWorld.new()
	check(world.configure_geometry(CENTER, HexGrid.disk(Vector2i.ZERO, 20)), "finite chemistry test topology configures")
	world.chemistry_enabled = true
	return world


func _deposit(world: HexChemistryWorld, source: int, element: int, point: Vector2i, tick: int) -> void:
	world.current_tick = tick
	var wire := int(catalog.ability(catalog.spell_id_at(Policy.ingredient_layer(element), "bolt")).wire_id)
	check(world.reserve_cast(source, wire), "funded source reserves")
	world.commit_payment(source)
	world.bind_release(source, source, point, Vector2i(1000, 0), 1)
	var definition := CombatTuning.cast_definition(wire)
	world.deposit_terminal({"source_cast_id": source, "source_wire_id": wire, "owner_id": source, "team_id": 1,
		"element_wire_id": element, "position": point, "direction": Vector2i(1000, 0), "strength": 1000,
		"reaction_strength": int(definition.reaction_strength)}, tick)


func _inside(world: HexChemistryWorld, product: Dictionary) -> Vector2i:
	var cells: Array = product.coverage.keys()
	cells.sort_custom(HexGrid._cell_less)
	return world.origin + HexGrid.center(cells[0])


func _actor(id: int) -> PlayerState:
	var actor := PlayerState.new()
	actor.entity_id = id; actor.team_id = 99; actor.health = 1_000_000; actor.health_maximum = 1_000_000
	actor.spawn_protection_ticks = 0; actor.champion_wire_id = 0
	return actor


func _permutations(remaining: Array, prefix: Array, result: Array) -> void:
	if remaining.is_empty(): result.append(prefix); return
	for index: int in remaining.size():
		var rest := remaining.duplicate(); var next := prefix.duplicate()
		next.append(rest[index]); rest.remove_at(index)
		_permutations(rest, next, result)


func _test_self_product_upgrades() -> void:
	for order: Array in [[1,1,2], [3,3,8], [1,1,2,3,4,7,8]]:
		var fixture := _form(order)
		var mask := 0
		for element: int in order: mask |= Policy.element_bit(element)
		equal(int(fixture.product.recipe_wire_id), Policy.wire_for_mask(mask), "self-product accepts a genuinely new element")
		equal(int(fixture.product.damage_budget_remaining), order.size() * 20_000, "self-product upgrade retains linear paid funding")
	var world := _world()
	var source := 1
	var result := 0
	for element: int in [1,2,3,4,7,8]:
		var product := _funded_product(world, Policy.recipe_wire(element, element), source)
		source += 2
		world.sync_flights([], [])
		result = Fusion.try_products(world, int(product.id), 10)
	equal(world.products.size(), 1, "six paid self-products combine without duplicate ancestors")
	equal(int(world.products[result].recipe_wire_id), 463, "six self-products reach full Convergence")
	equal(world.products[result].source_ids.size(), 12, "maximum provenance is exactly twelve distinct paid sources")
	equal(int(world.products[result].funded_strength), 60, "all twelve actual Bolt contributions retained")
	equal(int(world.products[result].damage_budget_remaining), 240_000, "twelve-source damage remains additive rather than exponential")
	check(world.conservation_valid(), "maximum-source fusion conserves every paid material unit")


func _test_partial_source_funding() -> void:
	var world := _world()
	var heavy_wire := int(catalog.ability(catalog.spell_id_at("earth", "heavy")).wire_id)
	var rapid_wire := int(catalog.ability(catalog.spell_id_at("fire", "rapid")).wire_id)
	check(world.reserve_cast(1, heavy_wire), "one Heavy source reserves its exact fifteen strength")
	world.commit_payment(1); world.bind_release(1, 1, CENTER, Vector2i(1000, 0), 1)
	for index: int in range(15):
		var source := index + 2
		check(world.reserve_cast(source, rapid_wire), "one distinct Rapid pays for each partial contact")
		world.commit_payment(source); world.bind_release(source, source, CENTER, Vector2i(1000, 0), 1)
		var outcome := world.resolve_contact(1, source, CENTER, index + 1)
		check(bool(outcome.get("accepted", false)), "partial strength contact is admitted")
		var product: Dictionary = world.products[int(outcome.product_id)]
		equal(product.source_funding, PackedInt64Array([1, heavy_wire, 1, source, rapid_wire, 1]), "partial contact funds only the two actual one-strength deltas")
		equal(int(product.damage_budget_remaining), 8000, "partial contact cannot quote the whole Heavy definition")
		equal(int(world.ledger_for_source(1).remaining_strength), 14 - index, "Heavy strength declines exactly once per contact")
	var paid_strength := 0
	var pool := 0
	for product: Dictionary in world.products.values():
		paid_strength += Funding.total(product.source_funding)
		pool += int(product.damage_budget_remaining)
	equal(paid_strength, 30, "fifteen partial contacts conserve Heavy15 plus fifteen paid Rapid1 sources")
	equal(pool, 120_000, "fragmentation never rounds up or reissues damage funding")
	check(world.conservation_valid(), "partial contact funding retains the independent matter ledger")
	var steam := _form([3, 2, 2])
	equal(Funding.total(steam.product.source_funding), 15, "Steam heat records its newly paid modifier contribution after parent sources retire")
	equal(int(steam.product.damage_budget_remaining), 60_000, "Steam modifier adds only actual remaining strength")


func _test_split_fusion_revalidates_queued_siblings() -> void:
	for fuses: bool in [false, true]:
		var fixture := _form([1, 2]) if fuses else {"world": _world(), "product": {}}
		var court: HexChemistryWorld = fixture.world
		var point := _inside(court, fixture.product) if fuses else CENTER
		var start := point - Vector2i(100_000, 0)
		var wire := int(catalog.ability(catalog.spell_id_at("water", "bolt")).wire_id)
		check(court.reserve_cast(10, wire), "split source is paid once")
		court.commit_payment(10); court.bind_release(10, 10, start, Vector2i(1000, 0), 1)
		check(court.split_flight(10, 10, 11), "two branches partition the same600-unit paid source")
		var world := SimWorld.new(120, 91, CollisionWorld.new(2_000_000, 2_000_000))
		world.players.clear(); world.projectiles.clear(); world.hex_court = court; world.tick = 10
		court.collision = world.collision
		var definition := CombatTuning.cast_definition(wire)
		for id: int in [10, 11]:
			var branch_start := start + (Vector2i(0, 200_000) if id == 11 else Vector2i.ZERO)
			@warning_ignore("integer_division")
			var shot := ProjectileState.new(id, 10, 1, wire, 3, branch_start, Vector2i(24_000_000, 0), int(definition.radius), int(definition.damage) / 2, 120)
			shot.source_cast_id = 10; shot.reaction_strength = 5; shot.material_strength = 300
			shot.remaining_distance = 100_000 if id == 10 else 200_000
			world.projectiles.append(shot)
		var target := _actor(90)
		target.radius = 18_000
		target.position_x = start.x + 180_000; target.position_y = start.y + 200_000
		world.players.append(target)
		HexProjectileCombat.advance(world)
		var child_hits := 0
		var child_terminals := 0
		for event: Dictionary in world.combat_events:
			if int(event.get("projectile_id", 0)) != 11: continue
			if String(event.type) == "projectile_hit": child_hits += 1
			if String(event.type) == "projectile_terminal": child_terminals += 1
		if fuses:
			equal(target.health, 1_000_000, "earlier branch fusion invalidates a later queued sibling actor hit")
			equal(child_hits, 0, "consumed sibling emits no damaging hit")
			equal(child_terminals, 0, "consumed sibling cannot deposit a later duplicate terminal")
			equal(int(court.ledger_for_source(10).remaining_strength), 0, "fusion consumes the source's actual remaining strength")
			equal(court.flight_quantity(10, 11), 0, "all sibling ownership is retired within the same queue")
			equal(int(court.products.values()[0].damage_budget_remaining), 60_000, "both branch allocations fund exactly one new contribution")
		else:
			equal(int(definition.damage), 9000, "positive split control uses the independently authored Rillshot damage")
			equal(target.health, 995_500, "without fusion the later sibling hits for its exact4500 paid half-damage")
			equal(child_hits, 1, "positive control reaches the queued sibling actor event")
			equal(child_terminals, 1, "positive control deposits the sibling's real remaining branch")
		equal(world.projectiles.size(), 0, "finished or consumed branches cannot survive into the next tick")
		check(court.conservation_valid(), "both event-queue outcomes conserve the one split source")


func _test_legacy_network_admission() -> void:
	var deposit := ElementDepositState.new()
	deposit.entity_id = 1; deposit.source_cast_id = 1; deposit.source_wire_id = 145
	deposit.owner_id = 1; deposit.team_id = 1; deposit.element_wire_id = 2; deposit.expiry_tick = 100
	check(deposit.validate(), "canonical Fire deposit retains positive legacy admission")
	deposit.source_wire_id = 101; deposit.element_wire_id = 6
	check(not deposit.validate() and ElementDepositState.from_values(deposit.canonical_values()) == null, "retired Charge cannot reenter through legacy wire state")
	check(deposit.validate_archive(), "explicit archive tooling can still read a historical deposit")
	deposit.source_wire_id = 145; deposit.element_wire_id = 3
	check(not deposit.validate(), "live source spell cannot claim a different ingredient")
	var reaction := ElementReactionState.new()
	reaction.entity_id = 1; reaction.owner_id = 1; reaction.team_id = 1
	reaction.recipe_wire_id = 301; reaction.source_a = 1; reaction.source_b = 2
	reaction.active_tick = 1; reaction.decay_tick = 50; reaction.expiry_tick = 100; reaction.radius = 30_000
	check(reaction.validate(), "canonical pair retains positive legacy-state admission")
	reaction.recipe_wire_id = 305
	check(not reaction.validate() and ElementReactionState.from_values(reaction.canonical_values()) == null, "retired Ice pair cannot reenter through legacy wire state")
	check(reaction.validate_archive(), "explicit archived pair tooling retains its historical validator")
	reaction.recipe_wire_id = 407
	check(not reaction.validate(), "higher-order authority cannot be truncated into a two-source legacy container")


func _test_fusion_warning_boundary() -> void:
	for fits: bool in [true, false]:
		var fixture := _form([2, 4])
		var world: HexChemistryWorld = fixture.world
		var parent: Dictionary = fixture.product
		var expiry := int(parent.expiry_tick)
		var warning := int(Policy.runtime_definition(411).formation_ticks)
		var tick := expiry - warning - (2 if fits else 1)
		check(tick < int(parent.decay_tick), "short-lived parent is still eligible at the boundary")
		var parent_id := int(parent.id)
		var pool_before := int(parent.damage_budget_remaining)
		_deposit(world, 3, 1, _inside(world, parent), tick)
		if fits:
			var child: Dictionary = world.products.values()[0]
			equal(int(child.recipe_wire_id), 411, "complete warning plus one active tick and one fade tick permits fusion")
			equal(int(child.active_tick), tick + warning, "short parent never shortens the descendant warning")
			equal(int(child.decay_tick), expiry - 1, "only the harmless tail is clipped to one tick")
			equal(int(child.expiry_tick), expiry, "clipped fade never extends inherited expiry")
			equal(int(child.damage_budget_remaining), pool_before + 20_000, "boundary fusion adds only one paid Bolt contribution")
		else:
			check(world.products.has(parent_id), "one fewer remaining tick refuses fusion atomically")
			equal(int(parent.damage_budget_remaining), pool_before, "failed warning fit cannot alter parent funding")
			equal(int(world.ledger_for_source(3).remaining_strength), 5, "failed warning fit retains the new paid source")
		check(world.conservation_valid(), "warning-boundary acceptance and refusal both conserve matter")


func _complete_snapshot_roundtrip(court: HexChemistryWorld, actor: PlayerState, label: String) -> bool:
	var world := SimWorld.new(120, 817, CollisionWorld.new(2_000_000, 2_000_000))
	world.hex_court = court
	world.tick = court.current_tick + 1
	world.player().champion_wire_id = 0
	world.player().position_x = 100_000
	world.player().position_y = 100_000
	if actor != null: world.players.append(actor)
	for product: Dictionary in court.products.values():
		for source: int in product.source_ids: world.next_projectile_id = maxi(world.next_projectile_id, source + 1)
	world.collision = HexCollisionWorld.new(world.collision)
	world.reaction_movement = world.collision
	check(world.collision.set_hex_surfaces(court, world.tick), label + " prepares exact dynamic surfaces")
	var snapshot := Snapshot.capture(world)
	check(not snapshot.is_empty(), label + " captures complete paid funding, contact and actor authority")
	if snapshot.is_empty(): return false
	equal(int(snapshot.header[7]), int(snapshot.header[1]) - 1, label + " stores actual previous-court/next-input clock relation")
	var restored := Snapshot.prepare(snapshot, world)
	check(restored != null, label + " restores through the strict public complete-world codec")
	if restored == null: return false
	equal(restored.state_hash(), world.state_hash(), label + " preserves every authoritative field and exact ancestor expiry")
	return restored.state_hash() == world.state_hash()


func _test_composite_snapshot_lifetime_boundaries() -> void:
	# Real Earth+Water then Fire has a456-tick parent deadline. Its child has
	# only300 active ticks; the rest is harmless ancestry, never an active buff.
	var fixture := _form([1, 3, 2])
	var world: HexChemistryWorld = fixture.world
	var product: Dictionary = fixture.product
	equal(int(product.recipe_wire_id), 407, "actual three-input route reaches the lifetime regression identity")
	equal(int(product.active_tick), 51, "tick3 fusion keeps the complete48-tick warning")
	equal(int(product.decay_tick), 351, "child attack window stays at independently bounded300ticks")
	equal(int(product.expiry_tick), 458, "child preserves its tick2 parent's exact456-tick lifetime")
	check(int(product.expiry_tick) > int(product.decay_tick) + 48, "regression really contains the formerly rejected harmless long tail")
	check(_complete_snapshot_roundtrip(world, null, "Caldera long-tail regression"), "actual long-tail407 is reproducible over the full codec")
	var mask := int(product.element_mask)
	var maximum := 0
	for first_wire: int in Policy.active_wire_ids():
		if first_wire > 336 or (Policy.mask_for_wire(first_wire) & mask) != Policy.mask_for_wire(first_wire): continue
		var first := Policy.definition(first_wire)
		maximum = maxi(maximum, int(first.formation_ticks) + int(first.active_ticks) + int(first.decay_ticks))
	var before := world.state_hash()
	var original_expiry := int(product.expiry_tick)
	var original_ancestry := int(product.ancestry_created_tick)
	var original_decay := int(product.decay_tick)
	for mutation: String in ["expiry", "future_ancestry", "negative_ancestry", "active_extension"]:
		if mutation == "expiry":
			product.expiry_tick = original_ancestry + maximum + 1
			product.expires = product.expiry_tick
		elif mutation == "future_ancestry": product.ancestry_created_tick = int(product.created) + 1
		elif mutation == "negative_ancestry": product.ancestry_created_tick = -1
		else: product.decay_tick = int(product.active_tick) + 301
		# Re-encode the mutated authority so rejection cannot be only a stale hash.
		var malformed := ChemistrySnapshot._capture_for_outer_roundtrip(world)
		check(not malformed.is_empty(), mutation + " produces a concrete fresh-hash candidate")
		check(not ChemistrySnapshot.validate(malformed, world), mutation + " cannot bypass ancestry/active bounds with a fresh authority hash")
		product.expiry_tick = original_expiry; product.expires = original_expiry
		product.ancestry_created_tick = original_ancestry; product.decay_tick = original_decay
		equal(world.state_hash(), before, "negative lifetime fixture restores exact real authority")
	var fresh := _form([1, 3])
	var pair: Dictionary = fresh.product
	pair.expiry_tick += 1; pair.expires = pair.expiry_tick
	var fresh_bad := ChemistrySnapshot._capture_for_outer_roundtrip(fresh.world)
	check(not ChemistrySnapshot.validate(fresh_bad, fresh.world), "fresh pair retains its strict authored expiry bound")
	for invalid_mask: int in [-1, 0, 64, 2_147_483_647]:
		equal(ChemistrySnapshot._maximum_first_lifetime(invalid_mask), 0, "invalid masks cannot grow the metadata memo")
	check(ChemistrySnapshot._maximum_first_lifetimes.size() <= 63, "immutable lifetime metadata memo has a strict63-key bound")


func _test_inherited_pair_snapshot_routes() -> void:
	var elements: Array[int] = [1, 2, 3, 4, 7, 8]
	var ingredient_routes := 0
	var product_routes := 0
	for same_tick: bool in [false, true]:
		for first: int in elements:
			for second: int in elements:
				if first == second: continue
				var court := _world()
				_deposit(court, 1, first, CENTER, 1)
				_deposit(court, 2, first, CENTER, 1 if same_tick else 2)
				court.sync_flights([], [])
				check(court.products.size() == 1, "self-to-pair route forms a real paid self product")
				if court.products.size() != 1: continue
				var parent: Dictionary = court.products.values()[0]
				var expiry := int(parent.expiry_tick)
				var ancestry := int(parent.ancestry_created_tick)
				_deposit(court, 3, second, _inside(court, parent), 1 if same_tick else 3)
				court.sync_flights([], [])
				check(court.products.size() == 1, "self product plus distinct paid ingredient replaces one parent")
				if court.products.size() != 1: continue
				var child: Dictionary = court.products.values()[0]
				var wire := Policy.recipe_wire(first, second)
				equal(int(child.recipe_wire_id), wire, "ordered self-to-pair route owns the exact live pair")
				equal(int(child.expiry_tick), expiry, "self-to-pair keeps exact ancestor expiry without a refresh")
				equal(int(child.ancestry_created_tick), ancestry, "self-to-pair preserves ancestry even on same-tick joins")
				equal(child.source_ids.size(), 3, "inherited pair is funded by exactly three distinct real sources")
				equal(int(child.damage_budget_remaining), 60_000, "self-to-pair carries only three paid Bolt budgets")
				if same_tick: equal(int(child.created), ancestry, "same-tick history is a real admitted case, not an invalid ancestry gap")
				if _complete_snapshot_roundtrip(court, null, "self %d plus %d, same tick %s" % [first, second, str(same_tick)]): ingredient_routes += 1
				if first == 3 and second == 2:
					# Water self lasts570 ticks; Steam's own24+360+60 is444.
					# This is a core wire with a real inherited tail, not a >400 case.
					equal(int(child.expiry_tick), 571 if same_tick else 572, "Frostway-to-Steam retains the independent570-tick parent deadline")
					check(int(child.expiry_tick) > int(child.decay_tick) + 60, "core-pair witness really exceeds Steam's normal fade")
					var before := court.state_hash()
					child.expiry_tick = ancestry + 571; child.expires = child.expiry_tick
					var malformed := ChemistrySnapshot._capture_for_outer_roundtrip(court)
					check(not malformed.is_empty() and not ChemistrySnapshot.validate(malformed, court), "inherited core pair refuses a fresh-hash deadline beyond any contained first recipe")
					child.expiry_tick = expiry; child.expires = expiry
					equal(court.state_hash(), before, "core-pair excessive-tail negative restores exact source state")
		for first_index: int in elements.size():
			for second_index: int in range(first_index + 1, elements.size()):
				var first := elements[first_index]
				var second := elements[second_index]
				var court := _world()
				_deposit(court, 1, first, CENTER, 1)
				_deposit(court, 2, first, CENTER, 1 if same_tick else 2)
				court.sync_flights([], [])
				check(court.products.size() == 1, "self partition begins from an actual paid terminal product")
				if court.products.size() != 1: continue
				var parent: Dictionary = court.products.values()[0]
				var point := _inside(court, parent)
				var tick := 1 if same_tick else 3
				court.current_tick = tick
				var spell := int(catalog.ability(catalog.spell_id_at(Policy.ingredient_layer(second), "bolt")).wire_id)
				for source: int in [3, 4]:
					check(court.reserve_cast(source, spell), "self partition reserves a separate paid in-flight source")
					court.commit_payment(source)
					court.bind_release(source, source, point, Vector2i(1000, 0), 1)
				var self_policy := Policy.runtime_definition(Policy.recipe_wire(second, second))
				var second_expiry := tick + int(self_policy.formation_ticks) + int(self_policy.active_ticks) + int(self_policy.decay_ticks)
				var expected_expiry := mini(int(parent.expiry_tick), second_expiry)
				# Public paid source contact creates the second self-product and
				# invokes the real product-plus-product fusion path in one event.
				var outcome := court.resolve_contact(3, 4, point, tick)
				check(bool(outcome.get("accepted", false)), "paid flight contact admits the second self product")
				court.sync_flights([], [])
				check(court.products.size() == 1, "self-plus-self atomically leaves exactly one descendant")
				if court.products.size() != 1: continue
				var child: Dictionary = court.products.values()[0]
				equal(int(child.recipe_wire_id), Policy.recipe_wire(first, second), "two self products reach the exact cross-pair")
				equal(int(child.expiry_tick), expected_expiry, "self-plus-self preserves the earliest of both real deadlines")
				equal(child.source_ids.size(), 4, "self-plus-self retains four disjoint paid sources")
				equal(int(child.damage_budget_remaining), 80_000, "self-plus-self cannot refresh either parent's damage budget")
				check(court.conservation_valid(), "self-plus-self keeps independent paid matter accounting")
				if _complete_snapshot_roundtrip(court, null, "self %d plus self %d, same tick %s" % [first, second, str(same_tick)]): product_routes += 1
	equal(ingredient_routes, 60, "all30 ordered self-to-pair routes roundtrip on same and later ticks")
	equal(product_routes, 30, "all15 unordered self-product partitions roundtrip on same and later ticks")
