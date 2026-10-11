class_name ElementRules
extends RefCounted
## The six live ingredients. Presentation order is independent of stable wires.
## Ice and Charge retain archived art/records, but are not live ingredients.

const IDS: Array[String] = ["water", "fire", "wind", "earth", "light", "dark"]
const WIRE_IDS: Array[int] = [3, 2, 4, 1, 7, 8]
const BY_ID := {"water": 3, "fire": 2, "wind": 4, "earth": 1, "light": 7, "dark": 8}
const NAMES := {"water": "Water", "fire": "Fire", "wind": "Air", "earth": "Earth", "light": "Light", "dark": "Dark"}
const BY_WIRE := {3: "water", 2: "fire", 4: "wind", 1: "earth", 7: "light", 8: "dark"}
const RETIRED_IDS: Array[String] = ["ice", "charge"]
const RETIRED_WIRES: Array[int] = [5, 6]
const FAMILY_COUNT := 8
const SPELL_COUNT := 504
const PAIR_REACTION_COUNT := 21
const REACTION_COUNT := 63
const MASK_BY_WIRE := {1: 1, 2: 2, 3: 4, 4: 8, 7: 16, 8: 32}


static func is_active_id(element_id: String) -> bool:
	return BY_ID.has(element_id)


static func is_active_wire(element_wire: int) -> bool:
	return BY_WIRE.has(element_wire)


static func id_from_wire(element_wire: int) -> String:
	return String(BY_WIRE.get(element_wire, ""))


static func fold_legacy_id(element_id: String) -> String:
	# Local configuration import only. Never use this to admit network state.
	if element_id == "ice": return "water"
	if element_id == "charge": return "fire"
	return element_id if is_active_id(element_id) else ""


static func fold_legacy_wire(element_wire: int) -> int:
	# Validate the historical ID/wire pair before calling this on saved content.
	if element_wire == 5: return 3
	if element_wire == 6: return 2
	return element_wire if is_active_wire(element_wire) else 0
