extends FluxTestSuite

var catalog := AbilityCatalog.new()
var layout := SanctumCampusLayout.new()
var definition: HexWorldDefinition
const TARGET := Vector2i(1504_000, 1344_000)
const SPAWN := TARGET + Vector2i(0, 180_000)
const ELEMENTS := ["earth", "fire", "water", "wind"]

func run() -> int:
	check(catalog.load_from_file("res://content/abilities/ability_catalog_v1.json"), "paid matrix uses production catalogue")
	check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "paid matrix uses normal campus topology")
	definition = HexWorldDefinition.from_campus(layout)
	check(definition != null, "normal campus shared definition exists")
	if definition == null: return finish("unified-hex-paid-matrix")
	for element: String in ELEMENTS:
		for delivery: String in ["bolt", "heavy", "rapid", "spray"]:
			_test_delivery(element, delivery)
	for first: int in range(1, 5):
		for second: int in range(first, 5):
			_test_pair(first, second)
			_test_pair(second, first)
	return finish("unified-hex-paid-matrix")

func _world() -> SimWorld:
	var world := SimWorld.new(120, 731, layout.build_collision_world(), String(layout.data.id), layout.content_hash)
	check(definition.bind_world(world), "one shared authority binds the ordinary campus")
	world.player().reset_for_spawn(SPAWN)
	world.player().spawn_protection_ticks = 0
	return world

func _equip(world: SimWorld, element: String, delivery: String) -> int:
	var wire := int(catalog.ability(catalog.spell_id_at(element, delivery)).get("wire_id", 0))
	check(wire > 0 and world.player().place_proven_spell(0, wire), "%s %s legal spell equips without replacing custom slots" % [element, delivery])
	return wire

func _paid_cast(world: SimWorld) -> void:
	var before := world.player().flux
	var paid := int(world.hex_court.metrics.matter_paid)
	var command := SimCommand.new(world.tick, 1, 0, 0, 0, int(SimCommand.SPELL_PRESSED_BITS[0]), 0, -1000, TARGET.x, TARGET.y)
	check(world.step([command]), "real paid input advances")
	check(world.player().flux < before, "admitted input pays positive Flux")
	equal(int(world.hex_court.metrics.matter_paid), paid + 600, "one real admission reserves exactly600 material")
	for unused: int in 300:
		if world.player().pending_cast_wire_id == 0 and world.projectiles.is_empty(): break
		check(world.step([]), "real startup flight and terminal complete")
	check(world.hex_court.conservation_valid(), "real paid flight and contact conserve finite stock")
	check(world.player().pending_cast_wire_id == 0 and world.projectiles.is_empty(), "delivery terminates in bounded time")

func _test_delivery(element: String, delivery: String) -> void:
	var world := _world()
	var wire := _equip(world, element, delivery)
	_paid_cast(world)
	var found := false
	for record: Dictionary in world.hex_court.casts.values():
		if int(record.wire) != wire: continue
		found = true
		equal(int(record.ground), 600, "unopposed terminal retains the exact finite paid budget")
		check(not record.coverage.is_empty(), "delivery selects actual campus hexes")
		for cell: Vector2i in record.coverage:
			check(world.hex_court.cells[cell][element].has(int(record.id)), "correct elemental layer contains paid allocation")
			var regions: Array = world.hex_court.render_regions(cell, element, world.tick)
			check(not regions.is_empty(), "selected whole hex has production presentation data")
	check(found, "%s %s produced persistent authoritative ingredient" % [element, delivery])
	equal(world.fields.size() + world.deposits.size() + world.reactions.size(), 0, "no legacy chemistry accompanies the shared cast")
	print("UNIFIED PAID SPELL: %s %s wire=%d cells=%d" % [element, delivery, wire, world.hex_court.casts.size()])

func _test_pair(first: int, second: int) -> void:
	var world := _world()
	_equip(world, ELEMENTS[first - 1], "bolt")
	_paid_cast(world)
	for unused: int in 36: check(world.step([]), "first source remains independently live while recovery completes")
	_equip(world, ELEMENTS[second - 1], "bolt")
	_paid_cast(world)
	var wire := HexRecipePolicy.recipe_wire(first, second)
	var product: Dictionary = {}
	for candidate: Dictionary in world.hex_court.products.values():
		if int(candidate.recipe_wire_id) == wire: product = candidate
	check(not product.is_empty(), "real paid %d+%d forms stable recipe%d" % [first, second, wire])
	if product.is_empty(): return
	equal(int(product.quantity), 1200, "equal paid sources transfer exactly two finite budgets once")
	equal(product.source_ids.size(), 2, "mirror or mixed reaction names two distinct paid sources")
	check(product.source_ids[0] != product.source_ids[1], "no source reacts with itself")
	while world.tick <= int(product.active_tick): check(world.step([]), "formation advances to actual active phase")
	var actor := world.player()
	var cells: Array = product.coverage.keys()
	var selected: Vector2i = cells[0]
	var foot := HexGrid.center(selected) + world.hex_court.origin
	actor.reset_for_spawn(foot)
	actor.team_id = 99 # Observable hostile damage without injecting any effect state.
	actor.spawn_protection_ticks = 0
	var start_health := actor.health
	var start_position := foot
	var before_position: Vector2i = product.position
	var did_effect := false
	for unused: int in 100:
		check(world.step([]), "active product executes through the real simulation")
		if wire in [302, 309, 310, 311] and actor.health < start_health: did_effect = true
		if wire in [304, 316, 317, 322] and Vector2i(actor.position_x, actor.position_y) != start_position: did_effect = true
		if wire == 303:
			var ratios := HexProductEffects.pre_movement(world.hex_court, actor, world.tick, null, world.config)
			if int(ratios.acceleration_ratio) == 700 and int(ratios.braking_ratio) == 700: did_effect = true
		if wire == 301 and not world.collision.can_occupy(foot, 18_000): did_effect = true
		if did_effect: break
	check(did_effect, "recipe%d has an observable distinct gameplay outcome" % wire)
	if wire == 311: check(product.position != before_position, "Firestorm advances without cloning material")
	check(world.hex_court.conservation_valid(), "active effects preserve source/product accounting")
	print("UNIFIED PAID PAIR: %d+%d recipe=%d quantity=%d cells=%d outcome=%s" % [first, second, wire, int(product.quantity), product.coverage.size(), str(did_effect)])
