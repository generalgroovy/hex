extends FluxTestSuite

var catalog := AbilityCatalog.new()
var layout := SanctumCampusLayout.new()
var definition: HexWorldDefinition
const TARGET := Vector2i(1504_000, 1344_000)
const SPAWN := TARGET + Vector2i(0, 96_000)
const CLASH_NORTH := TARGET - Vector2i(0, 96_000)
const ELEMENTS := ["earth", "fire", "water", "wind"]

func run() -> int:
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "paid matrix uses production catalogue")
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
			_test_projectile_clash_pair(first, second)
			_test_projectile_clash_pair(second, first)
	return finish("unified-hex-paid-matrix")

func _world() -> SimWorld:
	var world := SimWorld.new(120, 731, layout.build_collision_world(), String(layout.data.id), layout.content_hash)
	check(definition.bind_world(world), "one shared authority binds the ordinary campus")
	check(world.collision.can_occupy(SPAWN, MovementTuning.PLAYER_RADIUS), "paid firing anchor clears actual workshop worldbone")
	world.player().reset_for_spawn(SPAWN)
	world.player().spawn_protection_ticks = 0
	return world

func _equip(world: SimWorld, element: String, delivery: String) -> int:
	return _equip_actor(world.player(), element, delivery)

func _equip_actor(actor: PlayerState, element: String, delivery: String) -> int:
	var wire := int(catalog.ability(catalog.spell_id_at(element, delivery)).get("wire_id", 0))
	check(wire > 0 and actor.place_proven_spell(0, wire), "%s %s legal spell equips without replacing custom slots" % [element, delivery])
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
	var foot: Vector2i = HexGrid.center(selected) + world.hex_court.origin
	actor.reset_for_spawn(foot)
	actor.team_id = 99 # Observable hostile damage without injecting any effect state.
	actor.spawn_protection_ticks = 0
	var start_health := actor.health
	var start_position: Vector2i = foot
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


# Two real champions use the ordinary command/admission/startup path. The first
# argument belongs to the south actor and therefore to the lower projectile ID;
# the reversed call proves that the ordered clash is recipe-symmetric.
func _test_projectile_clash_pair(first: int, second: int) -> void:
	var world := _world()
	var south := world.player()
	south.reset_for_spawn(SPAWN)
	south.team_id = 1
	south.spawn_protection_ticks = 0
	var north := PlayerState.new(2)
	north.team_id = 2
	north.reset_for_spawn(CLASH_NORTH)
	north.spawn_protection_ticks = 0
	world.players.append(north)
	check(world.collision.can_occupy(CLASH_NORTH, MovementTuning.PLAYER_RADIUS), "north Crucible clash anchor clears actual campus worldbone")
	check(world.collision.can_occupy(TARGET, 12_000), "Crucible clash midpoint is physically clear")

	var first_wire := _equip_actor(south, ELEMENTS[first - 1], "bolt")
	var second_wire := _equip_actor(north, ELEMENTS[second - 1], "bolt")
	var expected_recipe := HexRecipePolicy.recipe_wire(first, second)
	var south_flux := south.flux
	var north_flux := north.flux
	var paid_before := int(world.hex_court.metrics.matter_paid)
	var pressed := int(SimCommand.SPELL_PRESSED_BITS[0])
	var commands: Array[SimCommand] = [
		SimCommand.new(world.tick, south.entity_id, 0, 0, 0, pressed, 0, -1000, CLASH_NORTH.x, CLASH_NORTH.y),
		SimCommand.new(world.tick, north.entity_id, 0, 0, 0, pressed, 0, 1000, SPAWN.x, SPAWN.y),
	]
	check(world.step(commands), "opposite Crucible commands start two real paid Bolt casts")
	check(south.flux < south_flux and south_flux - south.flux > 0, "south clash actor pays a positive production Flux cost")
	check(north.flux < north_flux and north_flux - north.flux > 0, "north clash actor pays a positive production Flux cost")
	equal(int(world.hex_court.metrics.matter_paid), paid_before + 1200, "two admissions reserve two distinct600 material budgets")
	equal(world.hex_court.pending.size(), 2, "both paid reservations coexist during authored startup")

	var clash: Dictionary = {}
	var saw_two_flights := false
	for unused: int in 120:
		check(world.step([]), "opposing paid Bolt startups and flights advance through SimWorld")
		saw_two_flights = saw_two_flights or world.projectiles.size() == 2
		for event: Dictionary in world.combat_events:
			if String(event.get("type", "")) == "hex_clash" and not event.has("contact_kind"):
				clash = event.duplicate(true)
		if not clash.is_empty(): break
	check(saw_two_flights, "both paid projectile entities coexist before continuous clash resolution")
	check(not clash.is_empty(), "real opposing projectiles clash before actor or terminal contact")
	if clash.is_empty(): return
	equal(int(clash.source_wire_id), first_wire, "lower real projectile retains the south actor's ordered first element")
	equal(int(clash.other_wire_id), second_wire, "ordered clash names the north actor's second element")
	equal(int(clash.recipe_wire_id), expected_recipe, "ordered projectile contact selects the canonical first-four recipe")
	equal(int(clash.matched_strength), 5, "equal production Bolts clash at their authored strength")
	equal(int(clash.first_remaining), 0, "first equal Bolt is exhausted exactly once")
	equal(int(clash.second_remaining), 0, "second equal Bolt is exhausted exactly once")
	equal(world.projectiles.size(), 0, "exhausted clash cannot leave either flight or a terminal clone")
	var terminal_events := 0
	for event: Dictionary in world.combat_events:
		if String(event.get("type", "")) == "projectile_terminal": terminal_events += 1
	equal(terminal_events, 0, "equal projectile clash emits no duplicate terminal deposit")

	var product: Dictionary = world.hex_court.products.get(int(clash.reaction_id), {})
	check(not product.is_empty(), "projectile clash creates an authoritative recipe product")
	if product.is_empty(): return
	equal(world.hex_court.products.size(), 1, "one ordered projectile contact creates exactly one product")
	equal(int(product.recipe_wire_id), expected_recipe, "observable product identity matches the clash event")
	equal(int(product.quantity), 1200, "product owns both finite600 source budgets without duplication")
	equal(product.source_ids.size(), 2, "product records exactly two parent source IDs")
	if product.source_ids.size() != 2: return
	check(int(product.source_ids[0]) != int(product.source_ids[1]), "projectile clash sources remain distinct")
	var owners := {}
	var elements := PackedInt32Array()
	for source_value: Variant in product.source_ids:
		var source_id := int(source_value)
		var cast_id := int(world.hex_court.sources.get(source_id, 0))
		var record: Dictionary = world.hex_court.casts.get(cast_id, {})
		check(not record.is_empty() and bool(record.get("paid", false)), "product parent resolves to a real paid cast")
		if record.is_empty(): continue
		owners[int(record.owner)] = true
		elements.append(int(record.element))
		var ledger: Dictionary = record.get("ledger", {})
		check(StrengthBudget.validate(ledger), "consumed projectile parent retains a valid finite ledger")
		equal(int(ledger.get("budget", 0)), 600, "each projectile parent began with one600 budget")
		equal(int(ledger.get("flight_quantity", -1)), 0, "clash leaves no source quantity in flight")
		equal(int(ledger.get("deposited_quantity", -1)), 0, "projectile clash does not fabricate terminal ground stock")
		equal(int(ledger.get("consumed_quantity", -1)), 600, "each equal source contributes its complete600 budget once")
		equal(int(ledger.get("expired_quantity", -1)), 0, "no paid clash stock escapes through expiry")
	check(owners.has(south.entity_id) and owners.has(north.entity_id), "product provenance contains both real casting champions")
	equal(elements.size(), 2, "both consumed source records retain ingredient provenance")
	if elements.size() == 2:
		equal(int(elements[0]), first, "lower source ID retains the south actor's ordered ingredient")
		equal(int(elements[1]), second, "higher source ID retains the north actor's ordered ingredient")
	equal(int(world.hex_court.metrics.matter_consumed), 1200, "clash accounting records the complete product transfer")
	check(world.hex_court.conservation_valid(), "paid projectile clash conserves both source budgets and product matter")
	print("UNIFIED PAID CLASH: %d+%d recipe=%d quantity=%d sources=%s" % [first, second, expected_recipe, int(product.quantity), str(product.source_ids)])
