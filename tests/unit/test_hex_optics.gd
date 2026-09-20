extends FluxTestSuite


const ABILITY_PATH := "res://content/abilities/foundation_abilities_v1.json"
const ELEMENT_NAMES := ["", "earth", "fire", "water", "wind", "ice", "charge", "light", "dark"]
var _next_source := 20_000


func run() -> int:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(ABILITY_PATH), "optics fixture loads the production ability catalog: %s" % catalog.last_error)
	if not catalog.last_error.is_empty():
		return finish("hex-optics")
	_test_prism_reflects_once(catalog)
	_test_lightbend_rotates_light_once(catalog)
	_test_lens_splits_one_finite_light_source(catalog)
	_test_constructs_use_selected_hex_cover(catalog)
	_test_grounding_absorption_cannot_reappear_in_heavy_blast(catalog)
	_test_insufficient_mist_capacity_leaves_later_contact_available(catalog)
	_test_parent_terminal_precedes_child_clash(catalog)
	_test_new_ground_contact_starts_at_terminal_time(catalog)
	return finish("hex-optics")


func _test_prism_reflects_once(catalog: AbilityCatalog) -> void:
	var fixture := _world()
	var world: SimWorld = fixture.world
	var court: HexCourt = fixture.court
	var product := _form_product(world, catalog, 307, court.origin, Vector2i(1000, 0))
	_activate(world)
	var start := court.origin - Vector2i(220_000, 0)
	var shot := _shot(world, court, catalog, "water", "bolt", start, Vector2i(52_800_000, 0))
	HexProjectileCombat.advance(world)
	check(shot.velocity_x < 0 and shot.velocity_y == 0, "Crystal Prism reflects the incoming velocity across its authored normal")
	check(shot.position_x < int(product.position.x), "reflected flight spends the remainder of the same tick on the reflected side")
	equal(_events(world, "hex_optical_contact").size(), 1, "multi-hex Prism coverage reflects one projectile only once")
	equal(int(court.ledger_for_source(shot.source_cast_id).flight_quantity), 600, "reflection changes motion without spending source stock")
	check(court.conservation_valid(), "reflected paid source and formed Prism remain conserved")


func _test_lightbend_rotates_light_once(catalog: AbilityCatalog) -> void:
	var fixture := _world()
	var world: SimWorld = fixture.world
	var court: HexCourt = fixture.court
	_form_product(world, catalog, 325, court.origin, Vector2i(0, 1000))
	_activate(world)
	var original_velocity := Vector2i(52_800_000, 0)
	var light := _shot(world, court, catalog, "light", "bolt", court.origin - Vector2i(220_000, 0), original_velocity)
	HexProjectileCombat.advance(world)
	var once := ElementChemistrySystem.rotated_fifteen(original_velocity, 1)
	equal(Vector2i(light.velocity_x, light.velocity_y), once, "Lightbend rotates Light by exactly positive15 degrees")
	check(Vector2i(light.velocity_x, light.velocity_y) != ElementChemistrySystem.rotated_fifteen(once, 1), "multi-cell traversal cannot apply a second15-degree rotation")
	equal(_events(world, "hex_optical_contact").size(), 1, "Lightbend records one optical contact for the source")
	equal(int(court.ledger_for_source(light.source_cast_id).flight_quantity), 600, "Lightbend motion leaves finite matter untouched")

	fixture = _world()
	world = fixture.world
	court = fixture.court
	_form_product(world, catalog, 325, court.origin, Vector2i(0, 1000))
	_activate(world)
	var fire := _shot(world, court, catalog, "fire", "bolt", court.origin - Vector2i(220_000, 0), original_velocity)
	HexProjectileCombat.advance(world)
	equal(Vector2i(fire.velocity_x, fire.velocity_y), original_velocity, "Lightbend does not rotate non-Light flight")
	equal(_events(world, "hex_optical_contact").size(), 0, "ineligible non-Light traversal creates no optical contact")


func _test_lens_splits_one_finite_light_source(catalog: AbilityCatalog) -> void:
	var fixture := _world()
	var world: SimWorld = fixture.world
	var court: HexCourt = fixture.court
	_form_product(world, catalog, 329, court.origin, Vector2i(0, 1000))
	_activate(world)
	var original_damage := int(CombatTuning.cast_definition(_wire(catalog, "light", "bolt")).damage)
	var light := _shot(world, court, catalog, "light", "bolt", court.origin - Vector2i(220_000, 0), Vector2i(52_800_000, 0))
	HexProjectileCombat.advance(world)
	equal(world.projectiles.size(), 2, "Crystal Lens creates one additional Light branch")
	var damage_total := 0
	var branch_quantities: Array[int] = []
	var record: Dictionary = court.casts[int(court.sources[light.source_cast_id])]
	for branch: ProjectileState in world.projectiles:
		damage_total += branch.damage
		branch_quantities.append(int(record.flight_parts.get(branch.entity_id, 0)))
	branch_quantities.sort()
	equal(damage_total, original_damage, "Lens divides existing damage without multiplying it")
	equal(branch_quantities, [300, 300], "one600-unit source is partitioned evenly between parent and child")
	equal(int(record.ledger.flight_quantity), 600, "splitting changes branch ownership without changing aggregate flight stock")
	equal(court.casts.size(), 3, "Lens adds no cast or paid source while preserving its two formation sources")
	equal(_events(world, "hex_optical_contact").size(), 1, "Lens splits the Light source once despite whole-hex coverage")
	check(court.conservation_valid(), "Lens parent and child retain one conserved source ledger")


func _test_constructs_use_selected_hex_cover(catalog: AbilityCatalog) -> void:
	for wire: int in [301, 329, 305, 306]:
		var fixture := _world()
		var world: SimWorld = fixture.world
		var court: HexCourt = fixture.court
		var product := _form_product(world, catalog, wire, court.origin, Vector2i(0, 1000))
		_activate(world)
		var health_before := int(product.health)
		var start := court.origin - Vector2i(220_000, 0)
		var velocity := Vector2i(52_800_000, 0)
		var shot := _shot(world, court, catalog, "fire", "bolt", start, velocity)
		var expected_contact := HexProjectileCombat._product_contact(product, start, start + velocity / world.config.tick_rate, shot.radius, court.origin)
		check(not expected_contact.is_empty(), "construct recipe%d exposes continuous selected-hex cover" % wire)
		HexProjectileCombat.advance(world)
		equal(world.projectiles.size(), 0, "construct contact terminates non-optical flight for recipe%d" % wire)
		check(int(product.health) < health_before, "construct recipe%d loses observable health" % wire)
		var terminals := _events(world, "projectile_terminal", shot.entity_id)
		equal(terminals.size(), 1, "construct recipe%d emits exactly one terminal" % wire)
		if not terminals.is_empty():
			equal(terminals[0].position, expected_contact.point,
				"construct recipe%d terminates at the continuous selected-hex cover TOI" % wire)
		equal(int(court.ledger_for_source(shot.source_cast_id).deposited_quantity), 600, "construct terminal keeps all source stock in authority")
		check(court.conservation_valid(), "construct recipe%d preserves paid matter" % wire)


func _test_grounding_absorption_cannot_reappear_in_heavy_blast(catalog: AbilityCatalog) -> void:
	var fixture := _world()
	var world: SimWorld = fixture.world
	var court: HexCourt = fixture.court
	var product := _form_product(world, catalog, 306, court.origin, Vector2i(0, 1000))
	_activate(world)
	product.capacity = 1
	var start := court.origin - Vector2i(220_000, 0)
	var velocity := Vector2i(52_800_000, 0)
	var heavy := _shot(world, court, catalog, "charge", "heavy", start, velocity)
	var disposable_source := _reserve(court, catalog, "charge", "bolt", court.origin + HexGrid.center(Vector2i(0, 5)))
	var weakened := court.resolve_contact(heavy.source_cast_id, disposable_source, court.origin + HexGrid.center(Vector2i(0, 5)), world.tick)
	check(bool(weakened.accepted), "real paid clash weakens Heavy before its construct contact")
	var ledger: Dictionary = court.ledger_for_source(heavy.source_cast_id)
	equal(int(ledger.remaining_strength), 10, "strength15 Heavy is reduced to10 through the real source ledger")
	equal(int(ledger.flight_quantity), 400, "partial-strength Heavy owns the cumulative400-unit flight remainder")
	var finish := start + velocity / world.config.tick_rate
	var contact := HexProjectileCombat._product_contact(product, start, finish, heavy.radius, court.origin)
	check(not contact.is_empty(), "Grounding Network fixture has a continuous selected-hex contact")
	var splash_target := _target(world, Vector2i(contact.point) + Vector2i(-30_000, 50_000), 99)
	var definition := CombatTuning.cast_definition(heavy.source_wire_id)
	var pre_absorb_damage := heavy.damage * 10 / 15
	var expected_after_absorb := pre_absorb_damage - 1
	var rebased_damage := (expected_after_absorb * 15 + 10 - 1) / 10
	var expected_splash := mini(rebased_damage * 10 / 15, int(definition.blast_damage) * 10 / 15)
	var health_before := splash_target.health
	HexProjectileCombat.advance(world)
	equal(health_before - splash_target.health, expected_splash, "one absorbed damage unit cannot reappear when partial-strength Heavy recomputes its blast")
	equal(expected_splash, expected_after_absorb, "ceiling rebasing preserves the exact unabsorbed partial-strength damage")
	equal(int(product.capacity), 0, "Grounding Network spends its one remaining absorption unit")
	equal(int(court.ledger_for_source(heavy.source_cast_id).deposited_quantity), 400, "absorbed Heavy deposits only its real surviving400-unit source remainder")
	check(court.conservation_valid(), "partial absorption and Heavy terminal remain conserved")


func _test_insufficient_mist_capacity_leaves_later_contact_available(catalog: AbilityCatalog) -> void:
	var fixture := _world()
	var world: SimWorld = fixture.world
	var court: HexCourt = fixture.court
	var first := _form_product(world, catalog, 317, court.origin - Vector2i(180_000, 0), Vector2i(0, 1000))
	var second := _form_product(world, catalog, 317, court.origin + Vector2i(180_000, 0), Vector2i(0, 1000))
	_activate(world)
	first.capacity = 119 # Fire Bolt's smallest one-strength debit is120 of600.
	second.capacity = 600
	var fire := _shot(world, court, catalog, "fire", "bolt", court.origin - Vector2i(360_000, 0), Vector2i(86_400_000, 0))
	HexProjectileCombat.advance(world)
	equal(int(first.capacity), 119, "insufficient Mist capacity cannot spend a partial strength quantum")
	equal(int(second.capacity), 0, "fresh later Mist still suppresses the source after the first refusal")
	equal(int(court.ledger_for_source(fire.source_cast_id).remaining_strength), 0, "later sufficient Mist consumes the real Fire source")
	check((fire.chemistry_interaction_mask & (1 << (317 - 301))) != 0, "only the successful later Mist contact retains its interaction mask")
	equal(_events(world, "projectile_terminal", fire.entity_id).size(), 0, "Mist-exhausted flight cannot also deposit a terminal")
	check(court.conservation_valid(), "failed then successful suppression conserves all source matter")


func _test_parent_terminal_precedes_child_clash(catalog: AbilityCatalog) -> void:
	var fixture := _world()
	var world: SimWorld = fixture.world
	var court: HexCourt = fixture.court
	var lens := _form_product(world, catalog, 329, court.origin, Vector2i(0, 1000))
	_activate(world)
	var start := court.origin - Vector2i(220_000, 0)
	var velocity := Vector2i(52_800_000, 0)
	var parent := _shot(world, court, catalog, "light", "heavy", start, velocity)
	var finish := start + velocity / world.config.tick_rate
	var lens_contact := HexProjectileCombat._product_contact(lens, start, finish, parent.radius, court.origin)
	check(not lens_contact.is_empty(), "split-order fixture obtains the exact Lens contact")
	var center: Vector2i = lens_contact.point
	var remaining := finish - center
	var parent_finish := center + ElementChemistrySystem.rotated_fifteen(remaining, 1)
	var child_finish := center + ElementChemistrySystem.rotated_fifteen(remaining, -1)
	var parent_target := center + (parent_finish - center) * 65 / 100
	var child_clash := center + (child_finish - center) * 85 / 100
	var actor := _target(world, parent_target, 98)
	actor.radius = 10_000
	_shot(world, court, catalog, "fire", "bolt", child_clash, Vector2i.ZERO)
	HexProjectileCombat.advance(world)
	var record: Dictionary = court.casts[int(court.sources[parent.source_cast_id])]
	equal(int(record.ledger.deposited_quantity), 300, "parent terminal deposits its exact split branch before the child clash")
	equal(int(record.ledger.flight_quantity), 100, "later child clash consumes200 from the remaining300-unit flight branch")
	equal(int(record.ledger.consumed_quantity), 200, "same-tick child clash owns the exact finite debit")
	equal(record.ground_parts.size(), 1, "only the terminated parent becomes a ground part")
	var only_part: Dictionary = record.ground_parts.values()[0]
	equal(int(only_part.quantity), 300, "parent ground ownership cannot be retiled as a later flight deposit")
	equal(_events(world, "hex_clash").size(), 1, "child creates one later clash after the parent terminal")
	check(actor.health < 100_000, "parent branch reaches its earlier actor terminal")
	check(court.conservation_valid(), "parent-ground and child-flight locations conserve one source")


func _test_new_ground_contact_starts_at_terminal_time(catalog: AbilityCatalog) -> void:
	for crosses_after_terminal: bool in [false, true]:
		var fixture := _world()
		var world: SimWorld = fixture.world
		var court: HexCourt = fixture.court
		var y := court.origin.y
		var terminal := _shot(world, court, catalog, "water", "bolt", Vector2i(400_000, y), Vector2i(48_000_000, 0))
		terminal.remaining_distance = 200_000 # Deposits at x600000 and global time0.5.
		var other_start := Vector2i(300_000 if crosses_after_terminal else 500_000, y)
		var other := _shot(world, court, catalog, "fire", "bolt", other_start, Vector2i(48_000_000, 0))
		HexProjectileCombat.advance(world)
		var terminal_ledger: Dictionary = court.ledger_for_source(terminal.source_cast_id)
		var other_ledger: Dictionary = court.ledger_for_source(other.source_cast_id)
		if crosses_after_terminal:
			equal(_field_events(world).size(), 1, "flight crossing after terminal TOI contacts the newly deposited source field")
			equal(int(terminal_ledger.remaining_strength), 0, "later field contact consumes the deposited source")
			equal(int(other_ledger.remaining_strength), 0, "later field contact consumes equal incoming flight")
			check(_has_recipe(court, 310), "post-terminal Water/Fire contact forms one Steam product")
		else:
			equal(_field_events(world).size(), 0, "flight that crossed before terminal TOI is not contacted retroactively")
			equal(int(terminal_ledger.deposited_quantity), 600, "new source field exists after its terminal time")
			equal(int(other_ledger.flight_quantity), 600, "earlier crossing keeps the unrelated flight ledger intact")
		check(court.conservation_valid(), "terminal-time field ordering preserves paid matter")


func _world() -> Dictionary:
	var world := SimWorld.new(120, 91, CollisionWorld.new(1_280_000, 960_000))
	world.players.clear()
	var court := HexCourt.new()
	court.chemistry_enabled = true
	world.hex_court = court
	world.collision = HexCollisionWorld.new(world.collision)
	world.reaction_movement = world.collision
	court.collision = (world.collision as HexCollisionWorld).base_world
	world.next_projectile_id = 90_000
	return {"world": world, "court": court}


func _wire(catalog: AbilityCatalog, element: String, family: String) -> int:
	return int(catalog.ability(catalog.spell_id_at(element, family)).get("wire_id", 0))


func _reserve(court: HexCourt, catalog: AbilityCatalog, element: String, family: String, origin: Vector2i, aim: Vector2i = Vector2i(1000, 0)) -> int:
	var wire := _wire(catalog, element, family)
	var source := _next_source
	_next_source += 1
	var owner := source
	check(court.reserve_cast(owner, wire), "fixture reserves one supported paid source")
	court.commit_payment(owner)
	court.bind_release(owner, source, origin, aim, owner)
	return source


func _form_product(world: SimWorld, catalog: AbilityCatalog, recipe_wire: int, point: Vector2i, aim: Vector2i) -> Dictionary:
	var court: HexCourt = world.hex_court
	var policy := HexRecipePolicy.definition(recipe_wire)
	var elements: Array = policy.get("elements", [])
	check(elements.size() == 2, "recipe%d exposes two canonical elements" % recipe_wire)
	if elements.size() != 2:
		return {}
	var first := _reserve(court, catalog, ELEMENT_NAMES[int(elements[0])], "bolt", point, aim)
	var second := _reserve(court, catalog, ELEMENT_NAMES[int(elements[1])], "bolt", point, aim)
	var outcome: Dictionary = court.resolve_contact(first, second, point, 0)
	check(bool(outcome.get("accepted", false)) and int(outcome.get("recipe_wire_id", 0)) == recipe_wire,
		"distinct paid sources form recipe%d" % recipe_wire)
	return court.products.get(int(outcome.get("product_id", 0)), {})


func _activate(world: SimWorld) -> void:
	var court: HexChemistryWorld = world.hex_court
	var tick := 0
	for product: Dictionary in court.products.values():
		tick = maxi(tick, int(product.active_tick))
	world.tick = tick
	court.current_tick = tick
	check((world.collision as HexCollisionWorld).set_hex_surfaces(court, tick), "optics fixture installs trusted hex surfaces")


func _shot(world: SimWorld, court: HexCourt, catalog: AbilityCatalog, element: String, family: String, start: Vector2i, velocity: Vector2i) -> ProjectileState:
	var source := _reserve(court, catalog, element, family, start)
	var wire := _wire(catalog, element, family)
	var definition := CombatTuning.cast_definition(wire)
	var shot := ProjectileState.new(source, source, source, wire, int(definition.element_wire_id), start, velocity,
		int(definition.radius), int(definition.damage), 120)
	shot.source_cast_id = source
	shot.reaction_strength = int(definition.reaction_strength)
	world.projectiles.append(shot)
	return shot


func _target(world: SimWorld, point: Vector2i, id: int) -> PlayerState:
	var actor := PlayerState.new(id)
	actor.team_id = id
	actor.position_x = point.x
	actor.position_y = point.y
	actor.radius = 18_000
	actor.health = 100_000
	actor.spawn_protection_ticks = 0
	world.players.append(actor)
	return actor


func _events(world: SimWorld, kind: String, projectile_id: int = -1) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in world.combat_events:
		if String(event.get("type", "")) == kind and (projectile_id < 0 or int(event.get("projectile_id", -1)) == projectile_id):
			result.append(event)
	return result


func _field_events(world: SimWorld) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in world.combat_events:
		if String(event.get("type", "")) == "hex_clash" and String(event.get("contact_kind", "")) == "field":
			result.append(event)
	return result


func _has_recipe(court: HexCourt, wire: int) -> bool:
	for product: Dictionary in court.products.values():
		if int(product.recipe_wire_id) == wire:
			return true
	return false
