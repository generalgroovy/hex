extends FluxTestSuite
const Policy = preload("res://src/sim/hex/hex_recipe_policy.gd")
const Footprint = preload("res://src/sim/hex/hex_footprint.gd")

func run() -> int:
	var wires := Policy.active_wire_ids()
	equal(wires.size(), 63, "six-element grammar contains63 definitions")
	var pair_wires := {}
	for first: int in [1,2,3,4,7,8]:
		for second: int in [1,2,3,4,7,8]:
			var wire := Policy.recipe_wire(first, second)
			check(wire > 0, "every live pair resolves")
			equal(Policy.recipe_wire(second, first), wire, "pair order is symmetric")
			pair_wires[wire] = true
	equal(pair_wires.size(), 21, "six self plus15 cross pairs retain sparse IDs")
	for mask: int in range(1, 64):
		var wire := Policy.wire_for_mask(mask)
		check(wire in wires, "all nonempty element subsets have a canonical recipe")
		equal(Policy.mask_for_wire(wire), mask, "wire and element mask are inverse")
	for wire: int in wires:
		var contract := Policy.runtime_definition(wire)
		equal(contract, Policy.definition(wire), "shared and detached contract agree")
		check(contract.is_read_only(), "runtime contract is immutable")
		for key: Variant in contract:
			if contract[key] is Dictionary or contract[key] is Array: check(contract[key].is_read_only(), "nested contract is immutable")
		var detached := Policy.definition(wire)
		detached.radius = -1; detached.elements[0] = 999
		check(int(Policy.runtime_definition(wire).radius) > 0, "authoring cannot poison shared geometry")
		check(int(contract.pulse_damage) > 0, "every recipe has damaging execution")
		equal(String(contract.product_layer), Policy.product_layer(wire), "product material matches exact live identity")
		check(String(contract.footprint_motion) == "stationary", "reaction footprints never move after formation")
		check(int(contract.formation_ticks) > 0 and int(contract.active_ticks) > 0 and int(contract.decay_ticks) > 0, "every recipe has warning and finite lifecycle")
		for aim: Vector2i in [Vector2i(1000,0),Vector2i(0,-1000),Vector2i(600,800)]:
			var shape := Policy.selection_shape(wire, Vector2i(640000,480000), aim)
			check(Footprint.validate(shape), "every direction uses canonical valid geometry")
	for retired: int in [305,306,312,313,318,319,323,324,327,328,329,330,331,332,333]:
		check(Policy.definition(retired).is_empty(), "retired standalone Ice/Charge recipes cannot execute")
	for retired: int in [5,6]:
		equal(Policy.ingredient_layer(retired), "", "Ice/Charge are derived effects, not ingredients")
		equal(Policy.recipe_wire(retired, 3), 0, "retired ingredient fails closed")
	equal(int(Policy.definition(316).ground_target_ratio), 750, "Water self freezes ground travel to75 percent")
	equal(int(Policy.definition(316).projectile_speed_ratio), 650, "frozen material slows physical shots to65 percent")
	equal(String(Policy.definition(335).selection_kind), Footprint.KIND_ANNULUS, "Penumbra's safe interior is real geometry")
	return finish("hex-recipe-policy")
