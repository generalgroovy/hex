extends FluxTestSuite

const Chemistry = preload("res://src/sim/chemistry/element_chemistry_system.gd")
const CENTER := Vector2i(1_000_000, 1_000_000)
const WIRES := {1: 159, 2: 145, 3: 140, 4: 163, 7: 173, 8: 142}
var config := SimConfig.new(120)


func run() -> int:
	_test_compatibility_roles_expiry()
	_test_compatibility_promotion()
	_test_same_tick_compatibility_ordering()
	_test_live_paid_replay()
	_test_legacy_state_exclusion()
	return finish("element-trails")


func _make(element: int, id: int, trail: bool, source: int = -1) -> ElementDepositState:
	var values: Array = []
	equal(Chemistry.deposit_terminal(values, id, id if source < 0 else source, int(WIRES[element]), 1, 1, element, CENTER, 0, config, Vector2i(1000, 0), 1000, trail), 1, "compatibility fixture creates a canonical material role")
	return values[0]


func _test_compatibility_roles_expiry() -> void:
	# These reserved-radius packet roles remain readable. They are not evidence
	# that current paid projectiles emit optional trails.
	for element: int in ElementRules.WIRE_IDS:
		var trail := _make(element, element, true)
		var terminal := _make(element, element + 100, false)
		check(trail.is_trail() and trail.validate(), "all six compatibility trail roles validate")
		equal(trail.radius, 20000, "compatibility flight material has exactly20px radius")
		equal(terminal.radius, 40000, "compatibility full terminal radius remains40px")
		equal(trail.strength, 250, "compatibility trail quantity cannot equal full terminal stock")
		equal(trail.expiry_tick, config.milliseconds_to_ticks(Chemistry.TRAIL_LIFE_MS[element]), "compatibility trail lifetime remains bounded")
		var decoded := ElementDepositState.from_values(trail.canonical_values())
		check(decoded != null and decoded.is_trail(), "reserved role roundtrips")
		if decoded != null: equal(decoded.canonical_values(), trail.canonical_values(), "all trail fields survive exactly")
		var values: Array = [trail]
		Chemistry.step(values, [], [], null, config, trail.expiry_tick - 1, 4000, [])
		equal(values.size(), 1, "single compatibility trail survives its final tick")
		Chemistry.step(values, [], [], null, config, trail.expiry_tick, 4000, [])
		check(values.is_empty(), "compatibility trail expires at the exact boundary")
		for item: Array in [[10, 17000], [11, 251], [13, 181]]:
			var bad := trail.canonical_values(); bad[int(item[0])] = int(item[1])
			check(ElementDepositState.from_values(bad) == null, "oversized or malformed reserved trail is refused")
	for element: int in [5, 6]:
		var values: Array = []
		equal(Chemistry.deposit_terminal(values, 1, 1, 170 if element == 5 else 101, 1, 1, element, CENTER, 0, config, Vector2i(1000, 0), 1000, true), -1, "retired ingredient cannot seed a compatibility trail")
		check(values.is_empty(), "retired trail refusal leaves no material")


func _test_compatibility_promotion() -> void:
	var trail := _make(3, 1, true, 10)
	var values: Array = [trail]
	equal(Chemistry.deposit_terminal(values, 2, 10, 140, 1, 1, 3, CENTER + Vector2i(2, 2), 20, config), 1, "compatibility terminal replaces its own earlier same-cell trail")
	equal(values.size(), 1, "promotion cannot duplicate stock")
	equal(values[0].entity_id, 2, "replacement receives a new identity")
	check(not values[0].is_trail(), "promoted material is a terminal")
	var before: PackedInt64Array = values[0].canonical_values()
	equal(Chemistry.deposit_terminal(values, 3, 10, 140, 1, 1, 3, CENTER + Vector2i(3, 3), 21, config), 0, "duplicate terminal coalesces")
	equal(values[0].canonical_values(), before, "coalescing cannot refresh lifetime or strength")
	# Core pair compatibility is retained; higher combinations require Hex.
	var source_a := _make(2, 5, true, 40)
	var source_b := _make(3, 6, false, 40)
	var same: Array = [source_a, source_b]
	var reactions: Array = []
	Chemistry.step(same, reactions, [], null, config, 0, 4000, [])
	check(reactions.is_empty() and same.size() == 2, "a cast cannot react with its own optional fragment")


func _test_same_tick_compatibility_ordering() -> void:
	for trail_first_id: bool in [false, true]:
		for reverse_input: bool in [false, true]:
			var trail := _make(3, 10 if trail_first_id else 11, true, 1000)
			var terminal := _make(2, 11 if trail_first_id else 10, false, 2000)
			var before_trail := trail.canonical_values(); var before_terminal := terminal.canonical_values()
			var values: Array = [terminal, trail] if reverse_input else [trail, terminal]
			var products: Array = []
			for tick: int in [0, 1]:
				equal(Chemistry.step(values, products, [], null, config, tick, 4000, []), 4000, "same-created-tick compatibility trail never spends another terminal")
				check(products.is_empty() and values.size() == 2, "aging alone does not change same-tick eligibility")
				equal(trail.canonical_values(), before_trail, "rejected trail remains exact")
				equal(terminal.canonical_values(), before_terminal, "rejected terminal remains exact")


func _world() -> SimWorld:
	var world := SimWorld.new(120, 772, CollisionWorld.new(8000000, 8000000))
	world.hex_court = HexChemistryWorld.new()
	check(world.hex_court.configure_geometry(CENTER, HexGrid.disk(Vector2i.ZERO, 20)), "live trail-free topology configures")
	world.hex_court.chemistry_enabled = true
	var actor := world.player()
	actor.position_x = CENTER.x; actor.position_y = CENTER.y
	actor.champion_wire_id = 0; actor.spawn_protection_ticks = 0
	actor.flux_recovery_per_second = 0
	return world


func _test_live_paid_replay() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "trail-free acceptance uses the live catalog")
	for element: String in ElementRules.IDS:
		for family: String in ["bolt", "rapid"]:
			var wire := int(catalog.ability(catalog.spell_id_at(element, family)).wire_id)
			var left := _world(); var right := _world()
			check(left.player().place_proven_spell(0, wire) and right.player().place_proven_spell(0, wire), "live spell is woven in both worlds")
			var before := left.player().flux
			var reached_terminal := false
			for step: int in range(180):
				var command := SimCommand.new(left.tick, 1, 0, 0, 0, SimCommand.PRESSED_SPELL_1 if step == 0 else 0, 1000, 0, CENTER.x + 200000, CENTER.y)
				check(left.step([command]) and right.step([command.copy()]), "same paid input executes in both authorities")
				equal(left.state_hash(), right.state_hash(), "paid flight/terminal replay preserves exact IDs, resources and geometry")
				for record: Dictionary in left.hex_court.casts.values():
					equal(int(record.trail_spent), 0, "live path never allocates optional trail budget")
					for part: Dictionary in record.ground_parts.values():
						check(not bool(part.trail), "every live ground part is terminal stock")
						equal(int(part.quantity), 600, "trail-free travel leaves the whole paid600-unit terminal")
						reached_terminal = true
				check(left.hex_court.conservation_valid(), "no source refill occurs during trail-free travel")
				if reached_terminal: break
			check(reached_terminal, "%s/%s reaches a real terminal" % [element, family])
			equal(left.player().flux, before - int(CombatTuning.cast_definition(wire).flux_cost), "terminal costs exactly one actual cast")
			var replica := _world()
			check(HexWorldSnapshot.restore(HexWorldSnapshot.capture(left), replica), "trail-free terminal reaches a validated replica")
			equal(replica.state_hash(), left.state_hash(), "replica preserves complete authority including the full terminal ledger")


func _test_legacy_state_exclusion() -> void:
	# Live Hex cannot silently coexist with the optional-trail compatibility loop.
	var world := _world()
	world.deposits.append(_make(3, 3000, true))
	var before := world.deposits[0].canonical_values()
	check(not world.step([]), "concurrent legacy material is refused before simulation")
	check(world.last_error.contains("rejects concurrent legacy chemistry"), "mixed-authority refusal is explicit")
	equal(world.deposits[0].canonical_values(), before, "refusal does not opportunistically reclaim or erase the legacy source")
	equal(int(world.hex_court.metrics.matter_paid), 0, "refused mixed state cannot issue new Hex budget")
