class_name ChemistryGuideModel
extends RefCounted

const Elements = preload("res://src/content/element_rules.gd")
const Policy = preload("res://src/sim/hex/hex_recipe_policy.gd")
# Sparse wire positions are preserved; retired ingredients have no menu label.
const ELEMENTS: Array[String] = ["", "Earth", "Fire", "Water", "Air", "", "", "Light", "Dark"]
const ELEMENT_IDS: Array[String] = ["", "earth", "fire", "water", "wind", "", "", "light", "dark"]
const DISPLAY_WIRES: Array[int] = Elements.WIRE_IDS


static func entries() -> Array[Dictionary]:
	var rows: Array[Dictionary] = [{"title": "Start here", "recipes": [], "lines": [
		"Six elements: Water, Fire, Air, Earth, Light and Dark. Ice and Charge are derived effects, not extra spell choices.",
		"Spell = ingredients + delivery. Every one of the 63 ingredient sets works with Bolt, Heavy, Rapid, Spray, Mantle, Fuse, Split and Rebound.",
		"Damaging hits can Fracture focus, Burn, Chill, Gust, Reveal or Wither. These statuses have finite timers and do not multiply a mixture's damage.",
		"A mixed payload can create its named field on a valid terminal. Singles form reactions by meeting a separate paid source. The Range lets you try either route.",
		"Choose two separate paid casts from the same family for a direct strength match. Overlap their surviving matter before it expires.",
		"Every recipe damages and adds its own situational effect. Read its warning, active window and counter before committing.",
		"The pair table has 21 pair/self recipes. Combine further with distinct elements to inspect all 63 recipes.",
	]}]
	for element_wire: int in DISPLAY_WIRES:
		var recipes: Array[Dictionary] = []
		var lines: Array[String] = ["PAIR TABLE / both orders are equivalent"]
		for other_wire: int in DISPLAY_WIRES:
			var definition := Policy.definition(Policy.recipe_wire(element_wire, other_wire))
			if definition.is_empty():
				continue
			recipes.append(definition)
			lines.append("%s + %s = %s" % [ELEMENTS[element_wire], ELEMENTS[other_wire], String(definition.name)])
			lines.append(String(definition.purpose))
			lines.append("Counter: " + String(definition.counter))
		rows.append({"title": ELEMENTS[element_wire], "recipes": recipes, "lines": lines})
	return rows


static func matrix_cell(row: int, column: int) -> Dictionary:
	if row < 0 or row >= DISPLAY_WIRES.size() or column < 0 or column >= DISPLAY_WIRES.size():
		return {}
	var first_wire := DISPLAY_WIRES[row]
	var second_wire := DISPLAY_WIRES[column]
	var wire := Policy.recipe_wire(first_wire, second_wire)
	var definition := Policy.definition(wire)
	if definition.is_empty():
		return {}
	return {"first": ELEMENTS[first_wire], "second": ELEMENTS[second_wire],
		"first_wire": first_wire, "second_wire": second_wire, "name": String(definition.name), "wire_id": wire,
		"effect": String(definition.purpose), "counter": String(definition.counter),
		"formation_ms": int(definition.formation_ticks) * 1000 / Policy.TICK_RATE,
		"active_ms": int(definition.active_ticks) * 1000 / Policy.TICK_RATE,
		"decay_ms": int(definition.decay_ticks) * 1000 / Policy.TICK_RATE}


static func pair_lines(row: int, column: int) -> Array[String]:
	var cell := matrix_cell(row, column)
	if cell.is_empty():
		return []
	var lines := definition_lines(Policy.definition(int(cell.wire_id)))
	lines.push_front("CREATE: overlap surviving matter from two separate paid casts before expiry. Try %s Bolt + %s Bolt for a simple equal-strength match; unequal sources leave unmatched stock." % [cell.first, cell.second])
	return lines


static func definition_lines(definition: Dictionary) -> Array[String]:
	if definition.is_empty():
		return ["Choose a valid combination to inspect its current rules."]
	var tell := "TELL: nominal %.2f s forming warning, %.2f s active and %.2f s harmless decay." % [float(definition.formation_ticks) / Policy.TICK_RATE, float(definition.active_ticks) / Policy.TICK_RATE, float(definition.decay_ticks) / Policy.TICK_RATE]
	var lines: Array[String] = [String(definition.purpose), "COUNTER: " + String(definition.counter), tell]
	if Policy.elements_for_mask(Policy.mask_for_wire(int(definition.wire_id))).size() > 1:
		lines.append("COMBINING: existing fields can shorten the active time or change the fading time. Active damage never lasts longer than shown. Read the field's current phase.")
	lines.append("FINITE STOCK: every hit spends the shared damage pool. New paid strength can add stock; fusion transfers only surviving parent stock and keeps the earliest parent expiry. Previously spent stock never returns.")
	var damage := int(definition.get("pulse_damage", 0))
	var cadence := int(definition.get("pulse_ticks", 0))
	if int(definition.get("wire_id", 0)) == 310:
		lines.append("STEAM DAMAGE: up to 12 Health per pressure pulse every %.2f s. Density, exposure and paid strength determine actual damage, bounded by the shared pool." % (float(cadence) / Policy.TICK_RATE))
	elif damage > 0:
		lines.append("BASE DAMAGE: %.1f Health%s; paid strength scales the hit up to 1.5x, bounded by the shared damage pool." % [float(damage) / 1000.0, " every %.2f s" % (float(cadence) / Policy.TICK_RATE) if cadence > 0 else " per valid trigger"])
	if int(definition.get("flow_speed", 0)) > 0:
		lines.append("FLOW: %s at %.0f px/s." % [String(definition.get("flow_kind", "")).replace("_", " "), float(definition.flow_speed) / 1000.0])
	if int(definition.get("slow_ratio", 1000)) != 1000:
		lines.append("MOVEMENT: %.0f%% target ratio%s." % [float(definition.slow_ratio) / 10.0, " on the ground" if bool(definition.get("ground_only", false)) else ""])
	return lines
