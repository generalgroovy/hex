extends FluxTestSuite

var catalog := AbilityCatalog.new()
var layout := SanctumCampusLayout.new()
var definition: HexWorldDefinition
const TARGET := Vector2i(1504_000, 1344_000)
const SPAWN := TARGET + Vector2i(0, 96_000)
const CLASH_NORTH := TARGET - Vector2i(0, 96_000)
const ELEMENTS := AbilityCatalog.DISPLAY_ELEMENT_IDS
const OFFENSIVE_ELEMENTS := AbilityCatalog.DISPLAY_ELEMENT_IDS

func run() -> int:
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "paid matrix uses production catalogue")
	check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "paid matrix uses normal campus topology")
	definition = HexWorldDefinition.from_campus(layout)
	check(definition != null, "normal campus shared definition exists")
	if definition == null: return finish("unified-hex-paid-matrix")
	equal(OFFENSIVE_ELEMENTS.size(), 6, "paid offense matrix covers exactly the six live elements")
	_test_retired_admission()
	for element: String in OFFENSIVE_ELEMENTS:
		for delivery: String in ["bolt", "heavy", "rapid", "spray"]:
			_test_direct_offense(element, delivery)
	for element: String in ELEMENTS:
		for delivery: String in ["bolt", "heavy", "rapid", "spray"]:
			_test_delivery(element, delivery)
	var pair_count := 0
	for first: int in ElementRules.WIRE_IDS:
		for second: int in ElementRules.WIRE_IDS:
			if second < first: continue
			pair_count += 1
			_test_pair(first, second)
			_test_pair(second, first)
			_test_projectile_clash_pair(first, second)
			_test_projectile_clash_pair(second, first)
			_test_paid_deposit(first, second)
			_test_paid_deposit(second, first)
	equal(pair_count, 21, "all live pair and self reactions receive paid formation, clash and terminal routes in both orders")
	return finish("unified-hex-paid-matrix")


func _test_retired_admission() -> void:
	var world := _world()
	for retired: int in [101, 167, 170, 171, 187, 188, 189, 190]:
		check(not world.player().place_proven_spell(0, retired), "retired Ice/Charge spell cannot enter live paid slots")
		check(not world.hex_court.reserve_cast(world.player().entity_id, retired), "retired wire cannot create a live material reservation")
	equal(int(world.hex_court.metrics.matter_paid), 0, "retired admission cannot manufacture paid matter")
	equal(world.hex_court.pending.size() + world.hex_court.casts.size(), 0, "retired admission leaves no pending or source state")

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


func _test_direct_offense(element: String, delivery: String) -> void:
	var world := _world()
	var wire := _equip(world, element, delivery)
	var cast := CombatTuning.cast_definition(wire)
	check(int(cast.damage) > 0, "every element/delivery has positive direct damage")
	var target := PlayerState.new(2)
	target.team_id = world.player().team_id + 1
	target.reset_for_spawn(TARGET)
	target.spawn_protection_ticks = 0
	world.players.append(target)
	var health := target.health
	_paid_cast(world)
	check(target.health < health, "%s %s damages a hostile target through a real paid cast" % [element, delivery])
	check(world.hex_court.conservation_valid(), "direct offense retains finite ingredient accounting")

func _test_pair(first: int, second: int) -> void:
	var world := _world()
	_equip(world, HexRecipePolicy.ingredient_layer(first), "bolt")
	_paid_cast(world)
	for unused: int in 36: check(world.step([]), "first source remains independently live while recovery completes")
	_equip(world, HexRecipePolicy.ingredient_layer(second), "bolt")
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
	while world.tick < int(product.active_tick): check(world.step([]), "formation advances to just before actual activation")
	var actor := world.player()
	var cells: Array = product.coverage.keys()
	# Prefer a reproducible point in the fixed authored region.
	var observation: Vector2i = product.position
	if wire == 311:
		# Stand ahead of the sector apex until the next real damage pulse.
		observation += Vector2i(product.flow_aim) * 24
	var selected := HexGrid.world_to_cell(observation - world.hex_court.origin)
	if not product.coverage.has(selected): selected = cells[0]
	var foot: Vector2i = HexGrid.center(selected) + world.hex_court.origin
	check(world.hex_court.contains_stored(product, foot), "observable effect actor starts inside actual selected coverage")
	actor.reset_for_spawn(foot)
	actor.team_id = 99 # Observable hostile damage without injecting any effect state.
	actor.spawn_protection_ticks = 0
	var start_health := actor.health
	var start_position: Vector2i = foot
	var before_position: Vector2i = product.position
	var before_coverage: Dictionary = product.coverage.duplicate()
	var before_footprint: Dictionary = product.footprint.duplicate(true)
	var did_effect := false
	# Five seconds independently bounds the longest authored active phase. Use
	# actual walking for movement/exit-triggered recipes rather than injecting a latch.
	for unused: int in 600:
		var move_x := 0
		if wire == 320: move_x = 1000 if unused % 32 < 16 else -1000
		elif wire == 321: move_x = 1000
		check(world.step([SimCommand.new(world.tick, actor.entity_id, move_x, 0)]), "active product executes through the real simulation")
		if actor.health < start_health: did_effect = true
		if wire in [304, 317, 322] and Vector2i(actor.position_x, actor.position_y) != start_position: did_effect = true
		if wire == 316 and int(HexProductEffects.pre_movement(world.hex_court, actor, world.tick, null, world.config).ground_target_ratio) == 750: did_effect = true
		if wire == 303:
			var ratios := HexProductEffects.pre_movement(world.hex_court, actor, world.tick, null, world.config)
			if int(ratios.acceleration_ratio) == 700 and int(ratios.braking_ratio) == 700: did_effect = true
		if wire == 301 and not world.collision.can_occupy(foot, 18_000): did_effect = true
		if did_effect: break
	check(did_effect, "recipe%d has an observable distinct gameplay outcome" % wire)
	if not did_effect:
		print("PAID EFFECT DIAGNOSTIC recipe=%d foot=%s final=%s health=%d/%d product=%s contact=%s" % [wire, foot, Vector2i(actor.position_x, actor.position_y), actor.health, start_health, product.position, product.get("contacts", {})])
	equal(product.position, before_position, "paid reaction anchor remains stationary through active effects")
	equal(product.coverage, before_coverage, "paid reaction coverage does not drift or grow")
	equal(product.footprint, before_footprint, "paid reaction selection shape remains fixed")
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

	var first_wire := _equip_actor(south, ElementRules.id_from_wire(first), "bolt")
	var second_wire := _equip_actor(north, ElementRules.id_from_wire(second), "bolt")
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
	var source_records := {}
	var projectile_wires := {}
	for unused: int in 120:
		for shot: ProjectileState in world.projectiles:
			projectile_wires[shot.entity_id] = shot.source_wire_id
			var id := int(world.hex_court.sources[shot.source_cast_id])
			source_records[shot.source_cast_id] = world.hex_court.casts[id]
		check(world.step([]), "opposing paid Bolt startups and flights advance through SimWorld")
		saw_two_flights = saw_two_flights or world.projectiles.size() == 2
		for event: Dictionary in world.combat_events:
			if String(event.get("type", "")) == "hex_clash" and not event.has("contact_kind"):
				clash = event.duplicate(true)
		if not clash.is_empty(): break
	check(saw_two_flights, "both paid projectile entities coexist before continuous clash resolution")
	check(not clash.is_empty(), "real opposing projectiles clash before actor or terminal contact")
	if clash.is_empty(): return
	var flight_ids: Array = projectile_wires.keys()
	flight_ids.sort()
	equal(int(clash.source_wire_id), int(projectile_wires[flight_ids[0]]), "ordered contact uses the lower released projectile ID despite distinct authored startup times")
	equal(int(clash.other_wire_id), int(projectile_wires[flight_ids[1]]), "ordered contact uses the other actual released projectile wire")
	check(first_wire in projectile_wires.values() and second_wire in projectile_wires.values(), "actual released flights retain both requested elements")
	equal(int(clash.recipe_wire_id), expected_recipe, "ordered projectile contact selects the canonical six-element recipe")
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
		var record: Dictionary = source_records.get(source_id, {})
		check(not world.hex_court.sources.has(source_id), "fully spent source is removed from live authority without dropping product provenance")
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
		elements.sort()
		equal(elements, PackedInt32Array([mini(first, second), maxi(first, second)]), "two paid source ingredients survive as the exact symmetric pair provenance")
	equal(int(world.hex_court.metrics.matter_consumed), 1200, "clash accounting records the complete product transfer")
	check(world.hex_court.conservation_valid(), "paid projectile clash conserves both source budgets and product matter")
	print("UNIFIED PAID CLASH: %d+%d recipe=%d quantity=%d sources=%s" % [first, second, expected_recipe, int(product.quantity), str(product.source_ids)])


func _test_paid_deposit(first: int, second: int) -> void:
	var world := _world()
	_equip(world, ElementRules.id_from_wire(first), "bolt")
	_paid_cast(world)
	var field: Dictionary = world.hex_court.casts.values()[0]
	var selected: Dictionary = HexTrailEmitter.terminal_coverage(field)
	var endpoint := Vector2i.ZERO
	var firing_point := Vector2i.ZERO
	var found := false
	# Find a real clear campus approach whose center never enters the stored
	# field, while the terminal selection disk overlaps one of its whole cells.
	for dx: int in range(-160_000, 160_001, 16_000):
		for dy: int in range(-96_000, 96_001, 16_000):
			var point := TARGET + Vector2i(dx, dy)
			var start := point + Vector2i(0, 96_000)
			if not world.collision.can_occupy(start, MovementTuning.PLAYER_RADIUS): continue
			if not ContinuousContact.wall_contact(start, point, 10_000, world.collision).is_empty(): continue
			if bool(HexFootprint.selected_segment_interval(selected, world.hex_court.origin, start, point).get("hit", false)): continue
			var cells: Array[Vector2i] = world.hex_court.select_cells(HexFootprint.disk(point, 34_000))
			var overlaps := false
			for cell: Vector2i in cells:
				if selected.has(cell): overlaps = true
			if not overlaps: continue
			endpoint = point
			firing_point = start
			found = true
			break
		if found: break
	check(found, "real campus provides a clear approach with terminal-only whole-cell overlap")
	if not found: return
	for unused: int in 36: check(world.step([]), "deposit fixture waits real recovery without refilling resources")
	_equip(world, ElementRules.id_from_wire(second), "bolt")
	var actor := world.player()
	actor.position_x = firing_point.x
	actor.position_y = firing_point.y
	actor.velocity_x = 0
	actor.velocity_y = 0
	var before_flux := actor.flux
	var before_paid := int(world.hex_court.metrics.matter_paid)
	var before_clashes := 0
	var request := SimCommand.new(world.tick, actor.entity_id, 0, 0, 0, int(SimCommand.SPELL_PRESSED_BITS[0]), 0, -1000, endpoint.x, endpoint.y)
	check(world.step([request]), "second terminal-only source starts via actual paid input")
	check(actor.flux < before_flux and int(world.hex_court.metrics.matter_paid) == before_paid + 600, "terminal-only path pays a fresh finite source")
	for unused: int in 180:
		for event: Dictionary in world.combat_events:
			if String(event.get("type", "")) == "hex_clash": before_clashes += 1
		if actor.pending_cast_wire_id == 0 and world.projectiles.is_empty(): break
		check(world.step([]), "terminal-only flight completes through continuous production motion")
	equal(before_clashes, 0, "center never intersects the field or another flight before terminal material selection")
	var expected := HexRecipePolicy.recipe_wire(first, second)
	var product: Dictionary = {}
	for candidate: Dictionary in world.hex_court.products.values():
		if int(candidate.recipe_wire_id) == expected: product = candidate
	check(not product.is_empty(), "paid overlapping terminal ingredients form recipe%d in order%d+%d" % [expected, first, second])
	if product.is_empty(): return
	equal(int(product.quantity), 1200, "ground-only product owns the two finite600-unit sources")
	equal(product.source_ids.size(), 2, "ground-only mirror and mixed pairs retain distinct source identity")
	check(world.hex_court.conservation_valid(), "ground-only paid formation conserves source and product quantities")
	print("UNIFIED PAID DEPOSIT: %d+%d recipe=%d quantity=%d endpoint=%s" % [first, second, expected, int(product.quantity), str(endpoint)])
