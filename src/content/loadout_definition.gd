class_name LoadoutDefinition
extends RefCounted


const SUPPORTED_SCHEMA_VERSION: int = 3
const AFFINITY_POINT_BUDGET: int = 3

var data: Dictionary = {}
var last_error: String = ""
var content_hash: String = ""
var active_points: int = 0
var spell_slot_ids: Array[String] = []
var spell_slot_wire_ids: PackedInt32Array = PackedInt32Array()
var disabled_spell_slots: Array[Dictionary] = []


func load_from_file(path: String, catalog: AbilityCatalog) -> bool:
	last_error = ""
	if not FileAccess.file_exists(path):
		return _fail("loadout does not exist: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("loadout cannot be opened: %s" % path)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return _fail("loadout root must be an object")
	data = parsed
	return validate(catalog)


func validate(catalog: AbilityCatalog) -> bool:
	last_error = ""
	content_hash = ""
	active_points = 0
	spell_slot_ids = []
	spell_slot_wire_ids = PackedInt32Array()
	disabled_spell_slots = []
	if not catalog.last_error.is_empty() or catalog.content_hash.is_empty():
		return _fail("loadout requires a valid ability catalog")
	if int(data.get("schema_version", 0)) != SUPPORTED_SCHEMA_VERSION:
		return _fail("unsupported loadout schema")
	if String(data.get("id", "")).is_empty() or String(data.get("champion_id", "")).is_empty():
		return _fail("loadout and champion ids are required")
	var affinities: Array = data.get("affinities", [])
	if affinities.size() < 2 or affinities.size() > 3:
		return _fail("champion loadout requires two or three affinities")
	var affinity_set: Dictionary = {}
	for value: Variant in affinities:
		var affinity := String(value)
		if affinity_set.has(affinity) or not catalog.elements_by_id.has(affinity):
			return _fail("affinities must be known and unique: %s" % affinity)
		if not bool((catalog.elements_by_id[affinity] as Dictionary).get("runtime_enabled", false)):
			return _fail("loadout affinity is not runtime-enabled: %s" % affinity)
		affinity_set[affinity] = true

	var affinity_points: Dictionary = data.get("affinity_points", {})
	if affinity_points.size() != affinities.size():
		return _fail("affinity_points must match loadout affinities")
	var affinity_point_total := 0
	for affinity: String in affinity_set:
		if not affinity_points.has(affinity):
			return _fail("affinity_points must include every loadout affinity: %s" % affinity)
		var strength := int(affinity_points[affinity])
		if strength < 1 or strength > 2:
			return _fail("loadout affinity strength must be 1 or 2: %s" % affinity)
		affinity_point_total += strength
	for point_key: Variant in affinity_points.keys():
		if not affinity_set.has(String(point_key)):
			return _fail("affinity_points cannot contain undeclared affinity: %s" % String(point_key))
	if affinity_point_total != AFFINITY_POINT_BUDGET:
		return _fail("loadout affinity points must total %d" % AFFINITY_POINT_BUDGET)

	var slots: Dictionary = data.get("slots", {})
	for slot_name: String in ["passive", "primary", "mobility", "ultimate"]:
		if not _validate_slot(catalog, String(slots.get(slot_name, "")), slot_name):
			return false
	var actives: Array = slots.get("actives", [])
	if actives.size() != 3:
		return _fail("loadout requires exactly three catalog actives")
	var active_ids: Dictionary = {}
	for value: Variant in actives:
		var ability_id := String(value)
		if active_ids.has(ability_id):
			return _fail("loadout actives must be unique: %s" % ability_id)
		if not _validate_slot(catalog, ability_id, "active"):
			return false
		active_ids[ability_id] = true
		var ability: Dictionary = catalog.ability(ability_id)
		var effective_points := int(ability.get("points", 0))
		var element_id := String(ability.get("element", ""))
		if affinity_set.has(element_id):
			var strength := int(affinity_points.get(element_id, 0))
			var authored_discount := int(ability.get("affinity_discount", 0))
			var effective_discount := mini(strength, authored_discount)
			effective_points = maxi(1, effective_points - effective_discount)
		active_points += effective_points
	var budget := int(data.get("active_budget", 0))
	if budget != 13:
		return _fail("standard competitive active budget must be 13")
	if active_points > budget:
		return _fail("loadout exceeds active budget: %d/%d" % [active_points, budget])
	var requested_spell_slots: Variant = data.get("spell_slots", [])
	if not requested_spell_slots is Array or requested_spell_slots.size() != PlayerState.SPELL_SLOT_COUNT:
		return _fail("loadout requires exactly twelve spell positions")
	var equipped_spell_ids: Dictionary = {}
	for raw_spell_id: Variant in requested_spell_slots:
		var spell_id := String(raw_spell_id)
		var position := spell_slot_ids.size() + 1
		if spell_id.is_empty():
			spell_slot_ids.append("")
			spell_slot_wire_ids.append(0)
			continue
		var spell: Dictionary = catalog.ability(spell_id)
		if spell.is_empty():
			return _fail("spell slot references unknown ability: %s" % spell_id)
		var slot_kind := String(spell.get("slot_kind", ""))
		if slot_kind not in ["primary", "active", "mobility"]:
			return _fail("ability %s cannot occupy a spell slot" % spell_id)
		if equipped_spell_ids.has(spell_id):
			return _fail("spell slots must be unique: %s" % spell_id)
		equipped_spell_ids[spell_id] = true
		spell_slot_ids.append(spell_id)
		var wire_id := int(spell.get("wire_id", 0))
		if catalog.runtime_wire_ids.has(wire_id):
			spell_slot_wire_ids.append(wire_id)
		else:
			# Known retired entries retain their authored position for recovery and
			# inspection. The runtime projection is zero at that exact position;
			# nothing is substituted or compacted into the player's weave.
			spell_slot_wire_ids.append(0)
			disabled_spell_slots.append({
				"position": position,
				"ability_id": spell_id,
				"wire_id": wire_id,
				"runtime_status": String(spell.get("runtime_status", "catalog_only")),
			})
	content_hash = CanonicalContent.sha256({"catalog_hash": catalog.content_hash, "loadout": data})
	if content_hash.length() != 64:
		return _fail("loadout hash failed")
	return true


func affinity_strength(element_id: String) -> int:
	var affinity_points: Dictionary = data.get("affinity_points", {})
	return int(affinity_points.get(element_id, 0))


func spell_slot_entry(position: int) -> Dictionary:
	if position < 1 or position > PlayerState.SPELL_SLOT_COUNT \
			or spell_slot_ids.size() != PlayerState.SPELL_SLOT_COUNT \
			or spell_slot_wire_ids.size() != PlayerState.SPELL_SLOT_COUNT:
		return {}
	var ability_id := spell_slot_ids[position - 1]
	var wire_id := int(spell_slot_wire_ids[position - 1])
	return {
		"position": position,
		"ability_id": ability_id,
		"wire_id": wire_id,
		"runtime_status": "empty" if ability_id.is_empty() else ("playable" if wire_id > 0 else "catalog_only"),
		"enabled": wire_id > 0,
	}


func _validate_slot(catalog: AbilityCatalog, ability_id: String, expected_kind: String) -> bool:
	var ability: Dictionary = catalog.ability(ability_id)
	if ability.is_empty():
		return _fail("loadout references unknown ability: %s" % ability_id)
	if String(ability.get("slot_kind", "")) != expected_kind:
		return _fail("ability %s cannot occupy %s" % [ability_id, expected_kind])
	if expected_kind in ["primary", "active"] and not catalog.runtime_wire_ids.has(int(ability.get("wire_id", 0))):
		return _fail("ability %s is not runtime-enabled for %s" % [ability_id, expected_kind])
	return true


func _fail(message: String) -> bool:
	last_error = message
	return false
