extends FluxTestSuite

const Chemistry = preload("res://src/sim/chemistry/element_chemistry_system.gd")
const STRENGTHS: Array[int] = [1, 3, 5, 15]
var config := SimConfig.new(120)

func run() -> int:
	_test_paid_provenance()
	_test_exact_deposit_matching()
	_test_sibling_admission()
	_test_optical_inheritance()
	return finish("reaction-strength-provenance")

func _deposit(id: int, cast_id: int, element: int, reaction_strength: int, quantity: int = 1000, trail: bool = false) -> ElementDepositState:
	var deposits: Array = []
	equal(Chemistry.deposit_terminal(deposits, id, cast_id, 140, 1, 1, element,
		Vector2i(500000, 500000), 0, config, Vector2i(1000, 0), quantity, trail, reaction_strength), 1,
		"bounded ingredient admission preserves a separate reaction strength")
	return deposits[0]

func _test_paid_provenance() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "real catalogue loads")
	for element: String in AbilityCatalog.DISPLAY_ELEMENT_IDS:
		for family: String in ["bolt", "heavy", "rapid"]:
			var ability := catalog.ability(catalog.spell_id_at(element, family))
			var wire := int(ability.wire_id)
			var expected := int(ability.reaction_strength)
			var world := SimWorld.new(120, 851, CollisionWorld.new(8000000, 8000000))
			world.player().champion_wire_id = 1
			world.player().position_x = 1000000
			world.player().position_y = 1000000
			world.player().flux_recovery_per_second = 0
			check(world.player().place_proven_spell(0, wire), "real spell is equipped before paid release")
			var seen_projectile := false
			var seen_trail := false
			var seen_terminal := false
			var coherent := true
			var stepped := true
			var before_flux := world.player().flux
			for step: int in range(400):
				var command := SimCommand.new(world.tick, 1, 0, 0, 0, SimCommand.PRESSED_SPELL_1 if step == 0 else 0, 1000, 0)
				command.aim_target_x = 1600000
				command.aim_target_y = 1000000
				stepped = world.step([command]) and stepped
				for shot: ProjectileState in world.projectiles:
					seen_projectile = true
					coherent = coherent and shot.reaction_strength == expected and shot.source_cast_id > 0
				for deposit: ElementDepositState in world.deposits:
					coherent = coherent and deposit.reaction_strength == expected
					seen_trail = seen_trail or deposit.is_trail()
					seen_terminal = seen_terminal or not deposit.is_trail()
				if seen_projectile and world.projectiles.is_empty():
					break
			check(stepped and world.last_error.is_empty(), "%s/%s paid simulation finishes without capacity loss" % [element, family])
			check(seen_projectile and seen_terminal and coherent, "%s/%s cast, trails and terminal retain the exact authored integer" % [element, family])
			equal(seen_trail, family != "rapid", "Rapid trail exclusion does not use a strength threshold")
			equal(before_flux - world.player().flux, int(CombatTuning.cast_definition(wire).flux_cost), "strength propagation adds no resource charge or reward")

func _test_exact_deposit_matching() -> void:
	for first: int in range(1, 9):
		for second: int in range(first, 9):
			for strength_a: int in STRENGTHS:
				for strength_b: int in STRENGTHS:
					for reversed: bool in [false, true]:
						var a := _deposit(3000, 1000, first, strength_a, 400)
						var b := _deposit(3001, 1001, second, strength_b, 1000)
						var before_a := a.canonical_values()
						var before_b := b.canonical_values()
						var deposits: Array = [b, a] if reversed else [a, b]
						var reactions: Array = []
						var events: Array = []
						var next := Chemistry.step(deposits, reactions, [], null, config, 0, 4000, events)
						if strength_a == strength_b:
							equal(next, 4001, "equal reaction strength admits exactly one recipe despite unequal material quantities")
							check(reactions.size() == 1 and deposits.is_empty(), "equal inputs spend only their single shared chemistry payloads")
							equal(reactions[0].recipe_wire_id, Chemistry.recipe_wire(first, second), "all36 recipes keep their elemental identity")
						else:
							equal(next, 4000, "unequal persistent strengths allocate no reaction")
							check(reactions.is_empty() and events.is_empty() and deposits.size() == 2, "unequal matter stays present without dominance or feedback multiplication")
							equal(a.canonical_values(), before_a, "first unequal ingredient is unchanged in both storage orders")
							equal(b.canonical_values(), before_b, "second unequal ingredient is unchanged in both storage orders")

func _test_sibling_admission() -> void:
	var trail := _deposit(3000, 1000, 3, 5, 250, true)
	var original := trail.canonical_values()
	var deposits: Array = [trail]
	equal(Chemistry.deposit_terminal(deposits, 3001, 1000, 140, 1, 1, 3, Vector2i(500000, 500000), 1, config, Vector2i(1000, 0), 1000, false, 1), -1, "a mismatched terminal cannot overwrite its same-cast trail")
	equal(trail.canonical_values(), original, "failed sibling promotion preserves all paid trail data")
	var malformed := _deposit(3002, 1000, 3, 1)
	deposits.append(malformed)
	equal(Chemistry.deposit_terminal(deposits, 3003, 1000, 140, 1, 1, 3, Vector2i(500000, 500000), 1, config, Vector2i(1000, 0), 1000, true, 5), -1, "early coalescing cannot hide a later inconsistent sibling")
	equal(deposits.size(), 2, "inconsistent input rejection does not erase either existing ingredient")
	deposits = [trail]
	equal(Chemistry.deposit_terminal(deposits, 3004, 1000, 140, 1, 1, 3, Vector2i(500000, 500000), 1, config, Vector2i(1000, 0), 1000, false, 5), 1, "equal cast strength permits ordinary trail-to-terminal promotion")
	equal(deposits[0].reaction_strength, 5, "promotion preserves cast strength while material quantity changes")
	var same: Array = [_deposit(3010, 1010, 2, 15), _deposit(3011, 1010, 3, 15)]
	var reactions: Array = []
	Chemistry.step(same, reactions, [], null, config, 0, 4000, [])
	check(reactions.is_empty() and same.size() == 2, "strength equality never permits same-cast self-combination")

func _test_optical_inheritance() -> void:
	for material: int in range(1001):
		var elements: Array = Chemistry.recipe(329).elements
		var lens := Chemistry.form_reaction(_deposit(3000, 1000, int(elements[0]), 5), _deposit(3001, 1001, int(elements[1]), 5), 4000, 0, config)
		var shot := ProjectileState.new(2000, 1, 1, 173, 7, Vector2i(500000, 500000), Vector2i(120000, 0), 10000, 5001, 200)
		shot.source_cast_id = 0 if material % 2 == 0 else 2000
		shot.reaction_strength = 7 # Test a value, not a family lookup in optics.
		shot.material_strength = material
		var events: Array[Dictionary] = []
		var survivors := CombatSystem.advance_projectiles([shot], [], config, CollisionWorld.new(8000000, 8000000), events, [lens], lens.active_tick, 1, {1: 1})
		var children := events.filter(func(event: Dictionary) -> bool: return event.get("type") == "chemistry_projectile_split")
		check(survivors.size() == 1 and children.size() == 1, "real Lens interaction produces one bounded split")
		if children.size() != 1:
			continue
		var child: ProjectileState = children[0].projectile
		equal(child.reaction_strength, 7, "optical child inherits the unchanged numeric reaction strength even when spent")
		equal(shot.reaction_strength, 7, "split never subtracts or pools parent's reaction strength")
		equal(child.source_cast_id, shot.source_cast_id if shot.source_cast_id > 0 else shot.entity_id, "optical branches share the original identity including a legacy zero-cast parent")
		equal(child.material_strength + shot.material_strength, material, "optical split conserves separate material quantity and cannot refill spent chemistry")
		equal(child.damage + shot.damage, 5001, "reaction strength copying does not multiply odd damage")
