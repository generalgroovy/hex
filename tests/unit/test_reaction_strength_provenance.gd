extends FluxTestSuite

const Chemistry = preload("res://src/sim/chemistry/element_chemistry_system.gd")
const Policy = preload("res://src/sim/hex/hex_recipe_policy.gd")
const Funding = preload("res://src/sim/hex/hex_reaction_funding.gd")
const CENTER := Vector2i(1_000_000, 1_000_000)
const STRENGTHS := {"rapid": 1, "spray": 3, "bolt": 5, "heavy": 15, "mantle": 8, "fuse": 10, "split": 8, "rebound": 6}
var config := SimConfig.new(120)
var catalog := AbilityCatalog.new()


func run() -> int:
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "real six-element catalog loads")
	_test_paid_provenance()
	_test_exact_source_matching()
	_test_compatibility_sibling_admission()
	_test_branch_ownership()
	return finish("reaction-strength-provenance")


func _court() -> HexChemistryWorld:
	var court := HexChemistryWorld.new()
	check(court.configure_geometry(CENTER, HexGrid.disk(Vector2i.ZERO, 18)), "provenance topology configures")
	court.chemistry_enabled = true
	return court


func _wire(element: String, family: String) -> int:
	return int(catalog.ability(catalog.spell_id_at(element, family)).wire_id)


func _bind(court: HexChemistryWorld, source: int, wire: int) -> Dictionary:
	check(court.reserve_cast(source, wire), "source reserves an actual live spell")
	court.commit_payment(source); court.bind_release(source, source, CENTER, Vector2i(1000, 0), 1)
	return court.casts[int(court.sources[source])]


func _test_paid_provenance() -> void:
	for element: String in ElementRules.IDS:
		for family: String in ["bolt", "heavy", "rapid", "spray"]:
			var wire := _wire(element, family)
			var expected := int(STRENGTHS[family])
			var world := SimWorld.new(120, 851, CollisionWorld.new(8000000, 8000000))
			world.hex_court = _court()
			var actor := world.player()
			actor.champion_wire_id = 0; actor.position_x = CENTER.x; actor.position_y = CENTER.y
			actor.spawn_protection_ticks = 0; actor.flux_recovery_per_second = 0
			check(actor.place_proven_spell(0, wire), "real spell is equipped before paid release")
			var seen_terminal := false
			var seen_source := false
			var before_flux := actor.flux
			for step: int in range(240):
				var command := SimCommand.new(world.tick, 1, 0, 0, 0, SimCommand.PRESSED_SPELL_1 if step == 0 else 0, 1000, 0, CENTER.x + 120000, CENTER.y)
				check(world.step([command]), "paid provenance executes: " + world.last_error)
				for record: Dictionary in world.hex_court.casts.values():
					equal(int(record.strength), expected, "paid source retains the independently authored family strength")
					if not record.ledger.is_empty():
						seen_source = true
						equal(int(record.ledger.initial_strength), expected, "release binds the exact immutable initial strength")
						equal(int(record.ledger.remaining_strength), expected, "uncontested travel does not spend reaction strength")
						for part: Dictionary in record.ground_parts.values():
							seen_terminal = true
							check(not bool(part.trail), "original24 singleton spells retain trail-free paid terminals; Mantle transfer is separately exercised by elemental-spell-expansion")
							equal(int(part.quantity), 600, "one terminal owns only its actual600-unit paid stock")
				check(world.hex_court.conservation_valid(), "every paid propagation tick conserves material")
				if seen_terminal: break
			check(seen_source and seen_terminal, "%s/%s reaches a bound source and terminal" % [element, family])
			equal(before_flux - actor.flux, int(CombatTuning.cast_definition(wire).flux_cost), "provenance adds no resource charge or reward")
			check(world.deposits.is_empty() and world.reactions.is_empty(), "live acceptance uses only the unified authority")


func _test_exact_source_matching() -> void:
	# Current matching consumes the smaller stock, retaining the difference.
	# The preserved old suite required equality; it is not current acceptance.
	for first_index: int in ElementRules.IDS.size():
		for second_index: int in range(first_index, ElementRules.IDS.size()):
			for first_family: String in STRENGTHS:
				for second_family: String in STRENGTHS:
					for reversed: bool in [false, true]:
						var court := _court()
						var first_wire := _wire(ElementRules.IDS[first_index], first_family)
						var second_wire := _wire(ElementRules.IDS[second_index], second_family)
						var first := _bind(court, 1000, first_wire)
						var second := _bind(court, 1001, second_wire)
						var first_strength := int(STRENGTHS[first_family])
						var second_strength := int(STRENGTHS[second_family])
						var matched := mini(first_strength, second_strength)
						var result := court.resolve_contact(1001 if reversed else 1000, 1000 if reversed else 1001, CENTER, 0)
						check(bool(result.accepted), "all21 actual element pairs admit all eight-family strength pairings with finite paid sources")
						if not bool(result.accepted): continue
						equal(int(first.ledger.remaining_strength), first_strength - matched, "first source retains the exact unmatched strength")
						equal(int(second.ledger.remaining_strength), second_strength - matched, "second source retains the exact unmatched strength")
						var product: Dictionary = court.products[int(result.product_id)]
						equal(int(product.recipe_wire_id), Policy.recipe_wire(int(first.element), int(second.element)), "strength never changes elemental recipe identity")
						equal(product.source_funding, PackedInt64Array([1000, first_wire, matched, 1001, second_wire, matched]), "funding stores only actual deltas in stable source order")
						equal(Funding.total(product.source_funding), 2 * matched, "both contributions add linearly")
						equal(int(product.damage_budget_remaining), matched * 8000, "damage pool has an independent two-source numeric oracle")
						@warning_ignore("integer_division")
						var expected_quantity := 600 * matched / first_strength + 600 * matched / second_strength
						equal(int(product.quantity), expected_quantity, "matter transfer is the exact cumulative fraction of each600-unit source")
						check(court.conservation_valid(), "family asymmetry never mints material")
						var before := court.state_hash()
						check(not bool(court.resolve_contact(1000, 1000, CENTER, 1).accepted), "source cannot combine with its sibling")
						equal(court.state_hash(), before, "same-source refusal is atomic")


func _compatibility_deposit(id: int, source: int, reaction_strength: int, trail: bool) -> ElementDepositState:
	var values: Array = []
	equal(Chemistry.deposit_terminal(values, id, source, 140, 1, 1, 3, CENTER, 0, config, Vector2i(1000, 0), 1000, trail, reaction_strength), 1, "compatibility fixture admits a live Water source")
	return values[0]


func _test_compatibility_sibling_admission() -> void:
	# This fifteen-value legacy packet adapter does not simulate live products.
	var trail := _compatibility_deposit(3000, 1000, 5, true)
	var original := trail.canonical_values()
	var deposits: Array = [trail]
	equal(Chemistry.deposit_terminal(deposits, 3001, 1000, 140, 1, 1, 3, CENTER, 1, config, Vector2i(1000, 0), 1000, false, 1), -1, "mismatched sibling cannot overwrite its paid trail")
	equal(trail.canonical_values(), original, "refused promotion preserves every source value")
	deposits.append(_compatibility_deposit(3002, 1000, 1, false))
	equal(Chemistry.deposit_terminal(deposits, 3003, 1000, 140, 1, 1, 3, CENTER, 1, config, Vector2i(1000, 0), 1000, true, 5), -1, "coalescing cannot hide a later inconsistent sibling")
	equal(deposits.size(), 2, "inconsistent input refusal preserves existing records")
	deposits = [trail]
	equal(Chemistry.deposit_terminal(deposits, 3004, 1000, 140, 1, 1, 3, CENTER, 1, config, Vector2i(1000, 0), 1000, false, 5), 1, "equal source strength permits compatibility promotion")
	equal(deposits[0].reaction_strength, 5, "promotion preserves strength while material quantity changes")


func _test_branch_ownership() -> void:
	# Lens is retired. Exercise the retained partition primitive directly without
	# pretending an archived Ice ingredient is a current route.
	for family: String in STRENGTHS:
		var court := _court()
		var record := _bind(court, 1000, _wire("light", family))
		check(court.split_flight(1000, 1000, 1001), "retained branch primitive partitions a paid source")
		equal(record.flight_parts, {1000: 300, 1001: 300}, "branch split conserves the600-unit stock exactly")
		equal(int(record.ledger.remaining_strength), int(STRENGTHS[family]), "branch count never multiplies or subtracts source strength")
		var before := court.state_hash()
		check(not court.split_flight(1000, 1000, 1001), "duplicate child cannot acquire a second allocation")
		equal(court.state_hash(), before, "duplicate branch refusal leaves authority unchanged")
		check(court.conservation_valid(), "retained branch primitive preserves global funding")
