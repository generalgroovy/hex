extends RefCounted
## Authored names plus compositional mechanics for all 42 higher-order subsets.
## Each element contributes an executable secondary rule; paid stock and damage
## pools belong to the runtime product, never this immutable recipe description.
@warning_ignore_start("integer_division")
const Footprint = preload("res://src/sim/hex/hex_footprint.gd")
const ELEMENT_WIRES := [1, 2, 3, 4, 7, 8]
const ELEMENT_IDS := ["earth", "fire", "water", "wind", "light", "dark"]
const NAMES := {
	7: "Caldera",
	11: "Cinder Cyclone",
	13: "Silt Surge",
	14: "Thunderhead",
	15: "Tempest Forge",
	19: "Sunforge",
	21: "Geode Spring",
	22: "Scalding Halo",
	23: "Opaline Furnace",
	25: "Prism Gale",
	26: "Corona Arc",
	27: "Daybreak Engine",
	28: "Aurora Current",
	29: "Glacial Cathedral",
	30: "Stormglass",
	31: "Prismatic Monsoon",
	35: "Ashen Mire",
	37: "Gravefrost",
	38: "Night Boil",
	39: "Volcanic Undertow",
	41: "Burial Gale",
	42: "Black Thunder",
	43: "Funeral Storm",
	44: "Sleet Veil",
	45: "Winter Sepulcher",
	46: "Night Tempest",
	47: "Abyssal Tempest",
	49: "Obsidian Crown",
	50: "Eclipse Flare",
	51: "Eclipse Crucible",
	52: "Dusk Mirror",
	53: "Onyx Tide",
	54: "Eventide Cauldron",
	55: "Eventide Forge",
	56: "Twilight Gyre",
	57: "Twilight Bastion",
	58: "Corona Eclipse",
	59: "Eclipse Engine",
	60: "Moonless Aurora",
	61: "Obsidian Aurora",
	62: "Celestial Tempest",
	63: "Convergence",
}

static func elements(mask: int) -> Array[int]:
	var result: Array[int] = []
	for index: int in range(6):
		if mask & (1 << index): result.append(ELEMENT_WIRES[index])
	return result


static func definition(mask: int) -> Dictionary:
	if not NAMES.has(mask): return {}
	var wires := elements(mask)
	var earth := bool(mask & 1)
	var fire := bool(mask & 2)
	var water := bool(mask & 4)
	var air := bool(mask & 8)
	var light := bool(mask & 16)
	var dark := bool(mask & 32)
	var boundary := light and dark
	var shape := Footprint.KIND_ANNULUS if boundary else Footprint.KIND_CAPSULE if air else Footprint.KIND_DISK
	var trigger := "crossing" if boundary else "activation" if fire else "dwell" if dark else "moving" if light else "pulse"
	var ingredients: Array[String] = []
	var roles: Array[String] = []
	for index: int in range(6):
		if mask & (1 << index): ingredients.append(ELEMENT_IDS[index])
	if earth: roles.append("70% ground acceleration and braking")
	if fire: roles.append("one 14 px electrical discharge along the cast direction")
	if water: roles.append("75% ground speed and 65% physical projectile travel")
	if air: roles.append("grounded flow along the cast direction")
	if light: roles.append("continuous reveal")
	if dark: roles.append("recovery denial" if light else "concealment with movement reveal")
	var counter := "leave the marked footprint; formation is clipped by map walls"
	if boundary: counter = "avoid the marked ring or use its safe center; one crossing hit per actor"
	elif trigger == "activation": counter = "leave the electrical lane during formation; its burst occurs once"
	elif trigger == "dwell": counter = "leave before one second of continuous exposure; movement reveals occupants"
	elif trigger == "moving": counter = "hold still between pulses or leave; the field still reveals you"
	elif earth: counter = "jump across or leave between pulses; ground traction ends on exit"
	return {
		"wire_id": 400 + mask, "id": "compound_%02d" % mask, "name": NAMES[mask],
		"elements": wires, "ingredient_layers": ingredients, "product_layer": "compound_%02d" % mask,
		"archive_recipe_wire": 335 if boundary else 313 if trigger == "activation" else 336 if trigger == "dwell" else 320 if trigger == "moving" else 302 if earth else 323,
		"element_mask": mask, "arity": wires.size(), "composite": true,
		"geometry_kind": "annulus" if boundary else "corridor" if air else "disk", "selection_kind": shape,
		"formation_ticks": 48 + 6 * (wires.size() - 3), "active_ticks": 300, "decay_ticks": 48,
		"radius": 60_000 if boundary else 14_000 if air else 48_000,
		"length": 40_000 if boundary else 135_000 if air else 0,
		"quantity_policy": "finite_parent_transfer", "pulse_ticks": 0 if trigger in ["activation", "crossing"] else 60,
		"pulse_damage": 9_000 if fire else 6_000, "trigger": trigger,
		"ground_only": earth and not light, "maximum_height": 0 if earth and not light else 256_000,
		"respects_protection": true, "flow_speed": 25_000 if air else 0, "flow_kind": "directional_steering" if air else "none",
		"ground_acceleration_ratio": 700 if earth else 1000, "ground_braking_ratio": 700 if earth else 1000,
		"ground_target_ratio": 750 if water else 1000, "projectile_speed_ratio": 650 if water else 1000,
		"slow_ratio": 1000, "health": 0, "capacity": 0, "motion_speed": 0, "footprint_motion": "stationary",
		"reveals": light, "conceals": dark and not light, "blocks_recovery": dark and light,
		"effect_once_per_actor": boundary or fire, "discharge_impulse": 14_000 if fire else 0, "purpose": "%s attack; %s" % [trigger.capitalize(), "; ".join(roles)],
		"counter": counter, "trigger_eligibility": "distinct_paid_sources_new_element", "trigger_modes": ["product_ingredient", "product_product"],
		"implementation_status": "runtime_implemented", "requires_canonical_capsule": false, "selection_activation_ready": true,
		"selection_proposal": "canonical_" + shape,
		"phase_ticks": PackedInt64Array([48 + 6 * (wires.size() - 3), 300, 48]),
	}
