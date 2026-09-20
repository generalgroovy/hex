extends FluxTestSuite


const Policy = preload("res://src/sim/hex/hex_recipe_policy.gd")
const Footprint = preload("res://src/sim/hex/hex_footprint.gd")
const LegacyChemistry = preload("res://src/sim/chemistry/element_chemistry_system.gd")

const FIRST_TEN := {
	"1:1": 301, "1:2": 302, "1:3": 303, "1:4": 304,
	"2:2": 309, "2:3": 310, "2:4": 311,
	"3:3": 316, "3:4": 317,
	"4:4": 322,
}


func run() -> int:
	_test_all_pairs_are_explicit_and_symmetric()
	_test_all_definitions_are_bounded_and_layered()
	_test_first_ten_contracts()
	_test_water_fire_parity()
	_test_later_rows_preserve_compiled_values()
	_test_selection_uses_exact_canonical_geometry()
	return finish("hex-recipe-policy")


func _test_all_pairs_are_explicit_and_symmetric() -> void:
	var wires := {}
	for first: int in range(1, 9):
		for second: int in range(first, 9):
			var wire := Policy.recipe_wire(first, second)
			check(wire >= 301 and wire <= 336, "element pair %d/%d owns a stable recipe wire" % [first, second])
			equal(Policy.recipe_wire(second, first), wire, "element pair %d/%d is symmetric" % [first, second])
			check(not wires.has(wire), "element pair %d/%d does not alias another recipe" % [first, second])
			wires[wire] = Vector2i(first, second)
	equal(wires.size(), 36, "all thirty-six unordered first-eight pairs are present exactly once")
	for wire: int in range(301, 337):
		check(wires.has(wire), "stable recipe wire %d is reachable" % wire)
	var expected_ingredient_layers := {1: "earth", 2: "fire", 3: "water", 4: "wind", 5: "ice", 6: "charge", 7: "light", 8: "dark"}
	for element: int in range(1, 9):
		equal(Policy.ingredient_layer(element), expected_ingredient_layers[element], "element %d has its exact explicit ingredient layer" % element)
	equal(Policy.ingredient_layer(0), "", "zero cannot fall through to an ingredient layer")
	equal(Policy.ingredient_layer(9), "", "a deferred element cannot fall through to an ingredient layer")
	equal(Policy.recipe_wire(0, 2), 0, "invalid first ingredient cannot form a recipe")
	equal(Policy.recipe_wire(3, 9), 0, "invalid second ingredient cannot form a recipe")

	var first_ten_wires: Array[int] = []
	for key: String in FIRST_TEN:
		var elements := key.split(":")
		var wire: int = FIRST_TEN[key]
		equal(Policy.recipe_wire(int(elements[0]), int(elements[1])), wire, "first-four pair %s keeps stable wire %d" % [key, wire])
		first_ten_wires.append(wire)
	first_ten_wires.sort()
	var declared := Policy.FIRST_TEN_WIRES.duplicate()
	declared.sort()
	equal(first_ten_wires, declared, "the explicit first-four matrix contains the ten intended recipe IDs")


func _test_all_definitions_are_bounded_and_layered() -> void:
	var numeric_fields: Array[String] = [
		"formation_ticks", "active_ticks", "decay_ticks", "radius", "length",
		"pulse_ticks", "pulse_damage", "maximum_height", "flow_speed", "slow_ratio",
		"health", "capacity", "motion_speed",
	]
	var product_layers := {}
	for wire: int in range(301, 337):
		var contract := Policy.definition(wire)
		check(not contract.is_empty(), "wire %d has one policy definition" % wire)
		equal(int(contract.wire_id), wire, "wire %d definition retains its stable identity" % wire)
		check(String(contract.product_layer) == Policy.product_layer(wire) and not String(contract.product_layer).is_empty(), "wire %d has an explicit product layer" % wire)
		check(not product_layers.has(String(contract.product_layer)), "wire %d product layer does not alias another product" % wire)
		product_layers[String(contract.product_layer)] = wire
		var elements: Array = contract.elements
		equal(contract.ingredient_layers, [Policy.ingredient_layer(int(elements[0])), Policy.ingredient_layer(int(elements[1]))], "wire %d names both ingredient layers explicitly" % wire)
		for field: String in numeric_fields:
			check(typeof(contract.get(field)) == TYPE_INT, "wire %d field %s is a finite integer" % [wire, field])
		check(int(contract.formation_ticks) > 0 and int(contract.active_ticks) > 0 and int(contract.decay_ticks) > 0, "wire %d has finite positive lifecycle phases" % wire)
		equal(contract.phase_ticks, PackedInt64Array([int(contract.formation_ticks), int(contract.active_ticks), int(contract.decay_ticks)]), "wire %d publishes formation, active, and decay ticks in order" % wire)
		check(int(contract.radius) >= 0 and int(contract.radius) <= Footprint.MAX_DISK_RADIUS, "wire %d radius stays within canonical footprint bounds" % wire)
		check(int(contract.length) >= 0 and int(contract.length) <= Footprint.MAX_SECTOR_RANGE, "wire %d length stays within canonical footprint bounds" % wire)
		check(int(contract.pulse_ticks) >= 0 and int(contract.pulse_damage) >= 0, "wire %d pulse contract is bounded and nonnegative" % wire)
		check(int(contract.maximum_height) >= 0 and int(contract.maximum_height) <= Policy.MAX_EFFECT_HEIGHT, "wire %d height eligibility is explicit and bounded" % wire)
		check(int(contract.flow_speed) >= 0 and int(contract.flow_speed) <= 100_000, "wire %d flow is explicitly bounded" % wire)
		check(int(contract.slow_ratio) > 0 and int(contract.slow_ratio) <= 1000, "wire %d slow ratio cannot immobilize or accelerate implicitly" % wire)
		check(typeof(contract.ground_only) == TYPE_BOOL and typeof(contract.respects_protection) == TYPE_BOOL, "wire %d has explicit ground and protection eligibility" % wire)
		check(not String(contract.quantity_policy).is_empty() and not String(contract.counter).is_empty() and not String(contract.purpose).is_empty(), "wire %d has quantity, counter, and purpose contracts" % wire)
		equal(String(contract.trigger_eligibility), "distinct_paid_sources", "wire %d requires distinct paid source eligibility" % wire)
		equal(String(contract.implementation_status), "policy_only", "wire %d metadata does not claim an implemented effect" % wire)
		var selection := Policy.selection_shape(wire, Vector2i(640_137, 480_251), Vector2i(600, 800))
		if bool(contract.selection_activation_ready):
			check(Footprint.validate(selection), "wire %d produces only currently supported canonical selection geometry" % wire)
			check(not bool(contract.requires_canonical_capsule), "wire %d ready selection does not hide a capsule dependency" % wire)
		else:
			check(selection.is_empty(), "wire %d cannot substitute another primitive for pending capsule geometry" % wire)
			check(bool(contract.requires_canonical_capsule), "wire %d records its unresolved canonical capsule dependency" % wire)
			equal(String(contract.selection_proposal), "pending_canonical_capsule", "wire %d explicitly defers activation to canonical capsule support" % wire)
	equal(product_layers.size(), 36, "all thirty-six products have distinct explicit layers")
	equal(Policy.product_layer(300), "", "wire below the stable range has no product layer")
	equal(Policy.product_layer(337), "", "wire above the stable range has no product layer")
	equal(Policy.definition(300), {}, "wire below the stable range has no definition")
	equal(Policy.definition(337), {}, "wire above the stable range has no definition")


func _test_first_ten_contracts() -> void:
	for wire: int in [301, 302, 303, 304, 311, 317, 322]:
		var derived := Policy.definition(wire)
		var compiled := LegacyChemistry.recipe(wire)
		equal(int(derived.formation_ticks), _ticks(int(compiled.formation_ms)), "new first-four wire %d derives the compiled formation duration" % wire)
		equal(int(derived.active_ticks), _ticks(int(compiled.active_ms)), "new first-four wire %d derives the compiled active duration" % wire)
		equal(int(derived.decay_ticks), _ticks(int(compiled.decay_ms)), "new first-four wire %d derives the compiled decay duration" % wire)
		equal(int(derived.radius), int(compiled.radius), "new first-four wire %d derives the compiled effect radius" % wire)
		equal(int(derived.length), int(compiled.length), "new first-four wire %d derives the compiled effect length" % wire)
		equal(int(derived.motion_speed), int(compiled.speed), "new first-four wire %d derives the compiled motion speed" % wire)
	var rampart := Policy.definition(301)
	equal(rampart.name, "Rampart", "Earth mirror presents the Rampart contract")
	equal(rampart.cover_shape, "hex_pillar", "Rampart is a true hex pillar rather than an axis rectangle")
	equal(int(rampart.cover_faces), 6, "Rampart publishes all six cover faces")
	check(bool(rampart.stable_face_normals) and bool(rampart.safe_creation_escape), "Rampart requires stable normals and safe initial escape")

	var magma := Policy.definition(302)
	equal(int(magma.pulse_ticks), 48, "Magma retains the existing 400 ms pulse at 120 Hz")
	equal(int(magma.pulse_damage), 5_000, "Magma retains the existing five-point grounded pulse")
	equal(int(magma.slow_ratio), 750, "Magma slow is explicit and bounded")
	check(bool(magma.ground_only) and int(magma.exit_ticks) == 0, "Magma slow is ground-only and ends immediately on exit")

	var mud := Policy.definition(303)
	equal(String(mud.movement_kind), "ground_acceleration_and_braking", "Mud changes grounded acceleration and braking")
	equal(int(mud.ground_acceleration_ratio), 700, "Mud acceleration ratio is explicit")
	equal(int(mud.ground_braking_ratio), 700, "Mud braking ratio is explicit")
	equal(int(mud.slow_ratio), 1000, "Mud does not inherit a blanket speed-ratio slow")
	check(not bool(mud.immobilizes) and int(mud.exit_ticks) == 0, "Mud cannot immobilize or leave a persistent exit penalty")

	var dustfront := Policy.definition(304)
	check(bool(dustfront.transparent), "Dustfront keeps threats visible")
	equal(String(dustfront.flow_kind), "lateral", "Dustfront applies lateral positioning pressure")
	equal(int(dustfront.flow_speed), 25_000, "Dustfront lateral flow is bounded")
	check(not bool(dustfront.traps), "Dustfront cannot advertise an indefinite trap")

	var firestorm := Policy.definition(311)
	equal(int(firestorm.motion_speed), 68_000, "Firestorm retains its compiled advancing-front speed")
	equal(int(firestorm.pulse_damage), 4_000, "Firestorm retains its compiled bounded pulse damage")
	check(bool(firestorm.obstacle_aware_motion), "Firestorm requires obstacle-aware movement")
	check(not bool(firestorm.refreshes_payload) and not bool(firestorm.refreshes_lifetime), "Firestorm cannot clone stock or refresh lifetime while moving")

	var mist := Policy.definition(317)
	check(bool(mist.transparent) and not bool(mist.conceals), "Mistcurrent remains visible steering rather than Steam concealment")
	equal(String(mist.flow_kind), "directional_steering", "Mistcurrent owns a distinct steering flow")
	equal(int(mist.capacity), 600, "Mistcurrent suppression stock is finite")
	equal(int(mist.suppression_quantity), 600, "Mistcurrent publishes the exact finite suppression quantity")
	equal(int(mist.pulse_damage), 0, "Mistcurrent cannot inherit Steam damage")

	var vortex := Policy.definition(322)
	equal(String(vortex.flow_kind), "tangential_rotation", "Vortex owns rotational utility")
	equal(int(vortex.flow_speed), 45_000, "Vortex rotational force is bounded")
	equal(int(vortex.projectile_speed_ratio), 1000, "Vortex redirects without implicitly increasing projectile speed")
	check(not bool(vortex.immobilizes) and not bool(vortex.traps), "Vortex cannot advertise a stun lock or permanent trap")


func _test_water_fire_parity() -> void:
	var expected_layers := {309: "conflagration", 310: "steam", 316: "flood"}
	for wire: int in expected_layers:
		var contract := Policy.definition(wire)
		equal(Policy.product_layer(wire), expected_layers[wire], "wire %d retains its current product layer" % wire)
		equal(int(contract.radius), 64_000, "wire %d retains the exact current 64k medium radius" % wire)
		equal(int(contract.length), 0, "wire %d remains a radial medium" % wire)
		equal(int(contract.formation_ticks), 24, "wire %d retains 24 formation ticks" % wire)
		equal(int(contract.active_ticks), 360, "wire %d retains 360 active ticks" % wire)
		equal(int(contract.decay_ticks), 60, "wire %d retains 60 decay ticks" % wire)
		equal(String(contract.quantity_policy), "matched_source_quantity", "wire %d retains finite matched-source quantity" % wire)
	equal(int(Policy.definition(309).pulse_ticks), 72, "Conflagration keeps its 600 ms pulse period")
	equal(int(Policy.definition(309).pulse_damage), 8_000, "Conflagration keeps its exact eight-point pulse")
	equal(int(Policy.definition(310).maximum_height), 48_000, "Steam keeps the exact 48 px height ceiling")
	equal(Policy.definition(310).modifier_channels, ["heat", "cool"], "Steam retains one finite heat and cool channel")
	equal(int(Policy.definition(310).modifier_uses_per_channel), 1, "Steam channels remain single-use")
	equal(int(Policy.definition(310).exposure_cap), 240, "Steam keeps its capped exposure ledger")
	equal(int(Policy.definition(310).exposure_exit_decay), 2, "Steam keeps explicit exit decay")
	equal(int(Policy.definition(310).exposure_damage_min), 2_000, "Steam keeps the current minimum pressure ramp")
	equal(int(Policy.definition(310).exposure_damage_max), 12_000, "Steam keeps the current maximum pressure cap")
	equal(int(Policy.definition(316).flow_speed), 40_000, "Flood keeps its exact directional flow speed")
	equal(int(Policy.definition(316).common_wall_clearance), 18_000, "Flood keeps common wall clearance")


func _test_later_rows_preserve_compiled_values() -> void:
	var later_count := 0
	var compiled_damage := {313: 9_000, 315: 3_000, 319: 6_000, 323: 3_000, 324: 5_000, 328: 8_000, 336: 2_000}
	for wire: int in range(301, 337):
		if wire in Policy.FIRST_TEN_WIRES:
			continue
		later_count += 1
		var contract := Policy.definition(wire)
		var compiled := LegacyChemistry.recipe(wire)
		equal(String(contract.id), String(compiled.id), "later wire %d retains its compiled id" % wire)
		equal(String(contract.geometry_kind), String(compiled.shape), "later wire %d retains compiled effect geometry metadata" % wire)
		equal(int(contract.formation_ticks), _ticks(int(compiled.formation_ms)), "later wire %d retains compiled formation time" % wire)
		equal(int(contract.active_ticks), _ticks(int(compiled.active_ms)), "later wire %d retains compiled active time" % wire)
		equal(int(contract.decay_ticks), _ticks(int(compiled.decay_ms)), "later wire %d retains compiled decay time" % wire)
		equal(int(contract.radius), int(compiled.radius), "later wire %d retains compiled radius" % wire)
		equal(int(contract.length), int(compiled.length), "later wire %d retains compiled length" % wire)
		equal(int(contract.motion_speed), int(compiled.speed), "later wire %d retains compiled motion speed" % wire)
		equal(int(contract.pulse_ticks), _ticks(int(compiled.pulse_ms)), "later wire %d retains compiled pulse period" % wire)
		equal(int(contract.health), int(compiled.health), "later wire %d retains compiled health" % wire)
		equal(int(contract.pulse_damage), int(compiled_damage.get(wire, 0)), "later wire %d retains compiled actor pulse damage" % wire)
		if String(contract.geometry_kind) in ["corridor", "growing_strip", "pulse_lane", "bands", "reveal_line", "water_path", "frost_path", "branch", "cover", "plane", "lens"]:
			check(not bool(contract.requires_canonical_capsule) and bool(contract.selection_activation_ready), "later wire %d uses the verified canonical capsule selection primitive" % wire)
			equal(String(Policy.selection_shape(wire, Vector2i(640_137, 480_251), Vector2i(600, 800)).kind), Footprint.KIND_CAPSULE, "later authored path and cover preserve capsule geometry")
	equal(later_count, 26, "the remaining twenty-six definitions are checked against compiled rows without forming legacy reactions")
	equal(int(Policy.definition(306).capacity), 36_000, "Grounding Network retains its compiled finite absorption capacity")


func _test_selection_uses_exact_canonical_geometry() -> void:
	var exact_point := Vector2i(640_137, 480_251)
	var aim := Vector2i(600, 800)
	var directional := {302: true, 304: true, 311: true, 317: true}
	for wire: int in Policy.FIRST_TEN_WIRES:
		var shape := Policy.selection_shape(wire, exact_point, aim)
		check(Footprint.validate(shape), "first-ten wire %d produces canonical selection geometry" % wire)
		if directional.has(wire):
			equal(String(Policy.definition(wire).selection_proposal), "first_four_directional_sector", "directional wire %d marks its authored first-four sector proposal" % wire)
			equal(String(shape.kind), Footprint.KIND_SECTOR, "directional wire %d uses the supported canonical sector" % wire)
			equal(shape.start, exact_point, "directional wire %d starts at the exact continuous contact point" % wire)
			equal(shape.aim, aim, "directional wire %d retains the supplied normalized aim" % wire)
			equal(int(shape.range), int(Policy.definition(wire).length), "directional wire %d retains its authored range" % wire)
			equal(int(shape.cosine_squared), Policy.DIRECTIONAL_COSINE_SQUARED, "directional wire %d uses the explicit bounded cone" % wire)
		elif wire == 322:
			equal(String(shape.kind), Footprint.KIND_ANNULUS, "Vortex preserves its authored center opening during selection")
			equal(shape.center, exact_point, "Vortex keeps the exact continuous contact origin")
		else:
			equal(String(shape.kind), Footprint.KIND_DISK, "radial wire %d uses the supported canonical disk" % wire)
			equal(shape.center, exact_point, "radial wire %d centers on the exact continuous contact point" % wire)
	check(Policy.selection_shape(302, exact_point, Vector2i.ZERO).is_empty(), "directional selection rejects a non-normalized zero aim")
	check(Policy.selection_shape(302, exact_point, Vector2i(1000, 1000)).is_empty(), "directional selection rejects an oversized diagonal aim")
	check(Policy.selection_shape(300, exact_point, aim).is_empty(), "unknown recipe cannot produce selection geometry")


func _ticks(milliseconds: int) -> int:
	return 0 if milliseconds <= 0 else maxi(1, (milliseconds * Policy.TICK_RATE + 999) / 1000)
