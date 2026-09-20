class_name CharacterStarterKit
extends RefCounted


const EXPERIMENT_FAMILIES: Array[String] = ["rapid", "spray", "rapid"]


# Pure preview projection. Applying a starter, preserving a custom weave and
# deciding cooldown behavior belong to the explicit Spell Loom authority.
static func build(champions, abilities: AbilityCatalog, champion_id: String) -> Dictionary:
	if champions == null or champions.content_hash.length() != 64 or not champions.last_error.is_empty():
		return _failure(champion_id, "Character starter kit requires a valid champion catalog.")
	if abilities == null or abilities.content_hash.length() != 64 or not abilities.last_error.is_empty():
		return _failure(champion_id, "Character starter kit requires a valid ability catalog.")
	var champion: Dictionary = champions.champion(champion_id)
	if champion.is_empty():
		return _failure(champion_id, "Character starter kit champion is unknown: %s" % champion_id)
	var affinity_value: Variant = champion.get("affinities", [])
	var point_value: Variant = champion.get("affinity_points", {})
	if not affinity_value is Array or not point_value is Dictionary:
		return _failure(champion_id, "Character starter kit affinities are malformed: %s" % champion_id)
	var affinities: Array = affinity_value
	var affinity_points: Dictionary = point_value
	if affinities.size() < 2 or affinities.size() > 3 or affinity_points.size() != affinities.size():
		return _failure(champion_id, "Character starter kit requires two or three canonical affinities: %s" % champion_id)

	var seen_elements: Dictionary[String, bool] = {}
	var priority_elements: Array[String] = []
	var affinity_point_total := 0
	for affinity_value_entry: Variant in affinities:
		var affinity := String(affinity_value_entry)
		if affinity not in AbilityCatalog.FIRST_EIGHT_ELEMENTS or seen_elements.has(affinity) \
				or not affinity_points.has(affinity):
			return _failure(champion_id, "Character starter kit affinity is unknown or duplicated: %s/%s" % [champion_id, affinity])
		var strength := int(affinity_points[affinity])
		if strength < 1 or strength > 2:
			return _failure(champion_id, "Character starter kit affinity strength is invalid: %s/%s" % [champion_id, affinity])
		affinity_point_total += strength
		seen_elements[affinity] = true
		priority_elements.append(affinity)
	if affinity_point_total != int(champions.AFFINITY_POINT_BUDGET):
		return _failure(champion_id, "Character starter kit affinity points do not match the canonical budget: %s" % champion_id)
	for element_id: String in AbilityCatalog.FIRST_EIGHT_ELEMENTS:
		if not seen_elements.has(element_id):
			priority_elements.append(element_id)
	if priority_elements.size() != AbilityCatalog.FIRST_EIGHT_ELEMENTS.size():
		return _failure(champion_id, "Character starter kit element priority is incomplete: %s" % champion_id)

	var highest_affinity := String(affinities[0])
	for affinity_value_entry: Variant in affinities:
		var affinity := String(affinity_value_entry)
		# A strict comparison preserves authored affinity order for every tie.
		if int(affinity_points[affinity]) > int(affinity_points[highest_affinity]):
			highest_affinity = affinity

	var spell_ids: Array[String] = []
	var wire_ids := PackedInt32Array()
	for affinity_value_entry: Variant in affinities:
		var affinity_bolt_error := _append_matrix_spell(abilities, String(affinity_value_entry), "bolt", spell_ids, wire_ids)
		if not affinity_bolt_error.is_empty():
			return _failure(champion_id, affinity_bolt_error)
	var heavy_error := _append_matrix_spell(abilities, highest_affinity, "heavy", spell_ids, wire_ids)
	if not heavy_error.is_empty():
		return _failure(champion_id, heavy_error)
	for element_id: String in AbilityCatalog.FIRST_EIGHT_ELEMENTS:
		if seen_elements.has(element_id):
			continue
		var remaining_bolt_error := _append_matrix_spell(abilities, element_id, "bolt", spell_ids, wire_ids)
		if not remaining_bolt_error.is_empty():
			return _failure(champion_id, remaining_bolt_error)
	for experiment_index: int in range(EXPERIMENT_FAMILIES.size()):
		var experiment_error := _append_matrix_spell(
			abilities,
			priority_elements[experiment_index],
			EXPERIMENT_FAMILIES[experiment_index],
			spell_ids,
			wire_ids,
		)
		if not experiment_error.is_empty():
			return _failure(champion_id, experiment_error)

	if spell_ids.size() != PlayerState.SPELL_SLOT_COUNT or wire_ids.size() != PlayerState.SPELL_SLOT_COUNT:
		return _failure(champion_id, "Character starter kit did not fill exactly twelve positions: %s" % champion_id)
	return {
		"valid": true,
		"error": "",
		"champion_id": champion_id,
		"spell_ids": spell_ids,
		"wire_ids": wire_ids,
	}


static func _append_matrix_spell(
	abilities: AbilityCatalog,
	element_id: String,
	family_id: String,
	spell_ids: Array[String],
	wire_ids: PackedInt32Array,
) -> String:
	var spell_id := abilities.spell_id_at(element_id, family_id)
	var spell: Dictionary = abilities.ability(spell_id)
	var wire_id := int(spell.get("wire_id", 0))
	if spell_id.is_empty() or spell.is_empty() \
			or String(spell.get("element", "")) != element_id \
			or AbilityCatalog._spell_family(spell) != family_id \
			or String(spell.get("runtime_status", "")) != "playable" \
			or not abilities.runtime_wire_ids.has(wire_id):
		return "Character starter kit matrix cell is unavailable: %s/%s" % [element_id, family_id]
	if spell_ids.has(spell_id) or wire_ids.has(wire_id):
		return "Character starter kit matrix cell is duplicated: %s" % spell_id
	spell_ids.append(spell_id)
	wire_ids.append(wire_id)
	return ""


static func _failure(champion_id: String, message: String) -> Dictionary:
	var empty_spell_ids: Array[String] = []
	return {
		"valid": false,
		"error": message,
		"champion_id": champion_id,
		"spell_ids": empty_spell_ids,
		"wire_ids": PackedInt32Array(),
	}
