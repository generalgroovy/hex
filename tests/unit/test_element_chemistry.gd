extends FluxTestSuite

const Chemistry = preload("res://src/sim/chemistry/element_chemistry_system.gd")
const Policy = preload("res://src/sim/hex/hex_recipe_policy.gd")
const Archive = preload("res://src/presentation/archive_magic_contract.gd")
const WIRES := {1: 159, 2: 145, 3: 140, 4: 163, 7: 173, 8: 142}
var config := SimConfig.new(120)


# Compatibility containers still cross a packet boundary. Their former36-effect
# actor loop is not the live Hex authority. The63-reaction and product-effects
# suites separately qualify current finite damage, geometry and source funding.
func run() -> int:
	_test_projection()
	_test_deposits()
	_test_pairs()
	_test_archive_boundary()
	_test_capacity_expiry()
	return finish("element-chemistry")


func _deposit(id: int, element: int, strength: int = 1000) -> ElementDepositState:
	var values: Array = []
	equal(Chemistry.deposit_terminal(values, id, id, int(WIRES[element]), 1, 1, element, Vector2i(500000, 500000), 0, config, Vector2i(1000, 0), strength), 1, "canonical compatibility ingredient admits")
	return values[0]


func _test_projection() -> void:
	equal(Policy.active_wire_ids().size(), 63, "six self products and every nonempty combination have one definition")
	for wire: int in Policy.active_wire_ids():
		var live := Policy.definition(wire)
		var view := Chemistry.recipe(wire)
		check(not view.is_empty(), "compatibility metadata projects every live recipe")
		for key: String in ["id", "name", "wire_id", "elements", "radius", "length", "health"]:
			equal(view[key], live[key], "metadata retains authoritative " + key)
		equal(view.shape, live.geometry_kind, "metadata uses current geometry rather than archived visual identity")
		for pair: Array in [["formation_ms", "formation_ticks"], ["active_ms", "active_ticks"], ["decay_ms", "decay_ticks"]]:
			equal(config.milliseconds_to_ticks(int(view[pair[0]])), int(live[pair[1]]), "phase projection preserves the exact120Hz duration")
		for element: int in live.elements:
			check(ElementRules.is_active_wire(element), "projected ingredient belongs to the six canonical elements")
	for retired: int in [305, 306, 312, 313, 318, 319, 323, 324, 327, 328, 329, 330, 331, 332, 333]:
		check(Chemistry.recipe(retired).is_empty(), "retired recipe cannot masquerade as live metadata")
	for retired_element: int in [0, 5, 6, 9]:
		equal(Chemistry.recipe_wire(retired_element, 3), 0, "retired ingredients cannot resolve a live pair")


func _test_deposits() -> void:
	for element: int in ElementRules.WIRE_IDS:
		for strength: int in [1, 250, 1000]:
			var value := _deposit(element, element, strength)
			check(value.validate(), "matching live spell and element validate")
			equal(value.radius, 30000 + strength * 10, "compatibility radius has an independent30..40px quantity oracle")
			var copy := ElementDepositState.from_values(value.canonical_values())
			check(copy != null, "valid ingredient roundtrips")
			if copy != null: equal(copy.canonical_values(), value.canonical_values(), "all fifteen values roundtrip exactly")
	var seed := _deposit(1, 3).canonical_values()
	for item: Array in [[0, 0], [1, 0], [2, 101], [3, 0], [4, 0], [5, 5], [5, 6], [6, -1], [7, 100000001], [8, 1001], [10, 20001], [10, 29999], [10, 40001], [11, 0], [11, 1001], [12, -1], [13, 0], [13, 601], [14, 0], [14, 16]]:
		var bad := seed.duplicate()
		bad[int(item[0])] = int(item[1])
		check(ElementDepositState.from_values(bad) == null, "malformed ingredient field%d=%d fails closed" % [item[0], item[1]])
	var mismatch := seed.duplicate(); mismatch[2] = 145
	check(ElementDepositState.from_values(mismatch) == null, "a Fire spell cannot authenticate a Water ingredient")
	var zero_aim := seed.duplicate(); zero_aim[8] = 0; zero_aim[9] = 0
	check(ElementDepositState.from_values(zero_aim) == null, "zero direction cannot enter canonical state")
	check(ElementDepositState.from_values(seed.slice(0, 14)) == null, "truncated ingredient is refused")


func _test_pairs() -> void:
	var seen := {}
	for first_index: int in ElementRules.WIRE_IDS.size():
		for second_index: int in range(first_index, ElementRules.WIRE_IDS.size()):
			var first := int(ElementRules.WIRE_IDS[first_index])
			var second := int(ElementRules.WIRE_IDS[second_index])
			var a := _deposit(100, first); var b := _deposit(200, second)
			var value := Chemistry.form_reaction(a, b, 4000, 10, config)
			var reverse := Chemistry.form_reaction(b, a, 4000, 10, config)
			equal(value.canonical_values(), reverse.canonical_values(), "stable source ownership makes pair container order-independent")
			equal(value.recipe_wire_id, Policy.recipe_wire(first, second), "pair container resolves current identity")
			check(value.validate(), "current pair fits the bounded legacy display container")
			var copy := ElementReactionState.from_values(value.canonical_values())
			check(copy != null, "current pair container roundtrips")
			if copy != null: equal(copy.canonical_values(), value.canonical_values(), "pair values are preserved exactly")
			check(not value.active(value.active_tick - 1) and value.active(value.active_tick), "forming-to-active boundary is exact")
			check(value.active(value.decay_tick - 1) and not value.active(value.decay_tick), "active-to-harmless boundary is exact")
			seen[value.recipe_wire_id] = true
			value.recipe_wire_id = 463
			check(not value.validate(), "two-source container cannot truncate six-source provenance")
	equal(seen.size(), 21, "all six self and fifteen cross pairs are unique")
	var sample := Chemistry.form_reaction(_deposit(1, 1), _deposit(2, 1), 4000, 0, config).canonical_values()
	for item: Array in [[0, 0], [1, 327], [10, -1], [11, 0], [13, 601], [14, ElementReactionState.MAX_RADIUS + 1], [15, ElementReactionState.MAX_LENGTH + 1], [19, 2], [20, 0]]:
		var bad := sample.duplicate(); bad[int(item[0])] = int(item[1])
		check(ElementReactionState.from_values(bad) == null, "malformed pair container field%d fails closed" % item[0])


func _test_archive_boundary() -> void:
	# Preserved artwork metadata only, never current balance acceptance.
	equal(Archive.REACTIONS.size(), 36, "immutable artwork archive retains all36 historical identities")
	var text := FileAccess.get_file_as_string("res://content/reactions/first_eight_element_reactions_v1.json")
	equal(text.sha256_text(), "4431e33377773874f24037dd8382772903622c38bc2c79e6ed525e5124662cbc", "archived authoring bytes remain exact")
	for row: Dictionary in Archive.REACTIONS:
		check(int(row.formation_ticks) > 0 and int(row.active_ticks) > 0 and int(row.decay_ticks) > 0, "archived art retains complete timing metadata")
	var archive := _deposit(1, 3)
	archive.element_wire_id = 5; archive.source_wire_id = 170
	check(archive.validate_archive() and not archive.validate(), "archive adapter retains Ice imagery without live admission")
	check(ElementDepositState.from_values(archive.canonical_values()) == null, "network decoder cannot opt into archive admission")


func _test_capacity_expiry() -> void:
	var values: Array = []
	for index: int in range(16):
		equal(Chemistry.deposit_terminal(values, index + 1, index + 1, 140, 1, 1, 3, Vector2i(100000 + index * 100000, 500000), 0, config), 1, "compatibility owner envelope accepts each legal slot")
	equal(Chemistry.deposit_terminal(values, 20, 20, 140, 1, 1, 3, Vector2i(2000000, 500000), 0, config), -1, "compatibility envelope refuses its seventeenth source")
	equal(values.size(), 16, "capacity refusal preserves prior material")
	# Spaced cells mean this expiry-only probe never invokes a legacy effect.
	Chemistry.step(values, [], [], null, config, 599, 4000, [])
	equal(values.size(), 16, "Water compatibility stock survives its last tick")
	Chemistry.step(values, [], [], null, config, 600, 4000, [])
	check(values.is_empty(), "compatibility stock expires at the exact deadline")
