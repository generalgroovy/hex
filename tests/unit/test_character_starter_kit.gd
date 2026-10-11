extends FluxTestSuite


const StarterKit = preload("res://src/content/character_starter_kit.gd")
const ABILITY_PATH := "res://content/abilities/foundation_abilities_v1.json"
const CHAMPION_PATH := "res://content/champions/foundation_champions_v1.json"
const LOADOUT_PATH := "res://content/loadouts/foundation_practitioner_v1.json"


func run() -> int:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file(ABILITY_PATH), "starter test ability catalog validates: %s" % abilities.last_error)
	var champions := ChampionCatalog.new()
	check(champions.load_from_file(CHAMPION_PATH, abilities), "starter test champion catalog validates: %s" % champions.last_error)
	var roster := ChampionRosterPlan.new()
	check(roster.load_from_files(), "starter test canonical affinity roster validates: %s" % roster.last_error)
	if not abilities.last_error.is_empty() or not champions.last_error.is_empty() or not roster.last_error.is_empty():
		return finish("character-starter-kit")
	_test_all_canonical_champions(champions, abilities, roster)
	_test_exact_representative_kits(champions, abilities)
	_test_budget_boundary(champions, abilities)
	_test_projection_does_not_mutate_sources(champions, abilities)
	_test_failures(abilities)
	return finish("character-starter-kit")


func _test_all_canonical_champions(champions: ChampionCatalog, abilities: AbilityCatalog, roster: ChampionRosterPlan) -> void:
	var champion_ids := champions.ordered_champion_ids()
	equal(champion_ids.size(), 30, "starter generator covers all thirty playable champions")
	for champion_id: String in champion_ids:
		var champion: Dictionary = champions.champion(champion_id)
		var canonical: Dictionary = roster.affinity_entry(champion_id)
		equal(champion.get("affinities", []), canonical.get("affinities", []), "%s uses canonical authored affinity order" % champion_id)
		equal(champion.get("affinity_points", {}), canonical.get("affinity_points", {}), "%s uses canonical affinity strengths" % champion_id)
		var result: Dictionary = StarterKit.build(champions, abilities, champion_id)
		check(bool(result.get("valid", false)), "%s starter generates: %s" % [champion_id, String(result.get("error", ""))])
		if not bool(result.get("valid", false)):
			continue
		var spell_ids: Array = result["spell_ids"]
		var wire_ids: PackedInt32Array = result["wire_ids"]
		equal(spell_ids.size(), PlayerState.SPELL_SLOT_COUNT, "%s starter fills twelve positions" % champion_id)
		equal(wire_ids.size(), PlayerState.SPELL_SLOT_COUNT, "%s starter exposes twelve wire identities" % champion_id)
		var unique_ids: Dictionary = {}
		var unique_wires: Dictionary = {}
		var bolt_elements: Dictionary = {}
		for slot_index: int in range(spell_ids.size()):
			var spell_id := String(spell_ids[slot_index])
			var spell: Dictionary = abilities.ability(spell_id)
			var wire_id := int(wire_ids[slot_index])
			check(not unique_ids.has(spell_id), "%s starter spell IDs are unique at %s" % [champion_id, PlayerState.spell_slot_label(slot_index)])
			check(not unique_wires.has(wire_id), "%s starter wires are unique at %s" % [champion_id, PlayerState.spell_slot_label(slot_index)])
			check(not spell.is_empty() and String(spell.get("runtime_status", "")) == "playable", "%s starter slot is playable at %s" % [champion_id, PlayerState.spell_slot_label(slot_index)])
			equal(int(spell.get("wire_id", 0)), wire_id, "%s starter ID and wire agree at %s" % [champion_id, PlayerState.spell_slot_label(slot_index)])
			check(abilities.runtime_wire_ids.has(wire_id), "%s starter wire is admitted at %s" % [champion_id, PlayerState.spell_slot_label(slot_index)])
			for element_id: String in AbilityCatalog.DISPLAY_ELEMENT_IDS:
				if spell_id == abilities.spell_id_at(element_id, "bolt"):
					bolt_elements[element_id] = true
					break
			unique_ids[spell_id] = true
			unique_wires[wire_id] = true
		equal(unique_ids.size(), PlayerState.SPELL_SLOT_COUNT, "%s starter contains no duplicate spell IDs" % champion_id)
		equal(bolt_elements.size(), AbilityCatalog.DISPLAY_ELEMENT_IDS.size(), "%s starter contains one Bolt for every active element" % champion_id)
		for element_id: String in AbilityCatalog.DISPLAY_ELEMENT_IDS:
			check(bolt_elements.has(element_id), "%s starter includes the %s Bolt" % [champion_id, element_id])
		_test_ordering(champion_id, champion, abilities, spell_ids)
		var state := PlayerState.new(1)
		state.spell_wire_ids = wire_ids.duplicate()
		check(state.has_valid_spell_slots(), "%s starter satisfies the ordinary twelve-position runtime validator" % champion_id)


func _test_ordering(champion_id: String, champion: Dictionary, abilities: AbilityCatalog, spell_ids: Array) -> void:
	var affinities: Array = champion["affinities"]
	var points: Dictionary = champion["affinity_points"]
	for affinity_index: int in range(affinities.size()):
		var affinity := String(affinities[affinity_index])
		equal(String(spell_ids[affinity_index]), abilities.spell_id_at(affinity, "bolt"), "%s begins with authored-order affinity Bolt %s" % [champion_id, affinity])
	var maximum_strength := 0
	for affinity_value: Variant in affinities:
		maximum_strength = maxi(maximum_strength, int(points[String(affinity_value)]))
	var tied_highest: Array[String] = []
	for affinity_value: Variant in affinities:
		var affinity := String(affinity_value)
		if int(points[affinity]) == maximum_strength:
			tied_highest.append(affinity)
	var heavy_index := affinities.size()
	equal(String(spell_ids[heavy_index]), abilities.spell_id_at(tied_highest.front(), "heavy"), "%s Heavy uses the strongest affinity and authored tie-break" % champion_id)
	equal(PlayerState.spell_slot_label(heavy_index), "3" if affinities.size() == 2 else "4", "%s Heavy occupies the requested plain slot" % champion_id)
	var remaining_elements: Array[String] = []
	for element_id: String in AbilityCatalog.DISPLAY_ELEMENT_IDS:
		if element_id not in affinities:
			remaining_elements.append(element_id)
	for remaining_index: int in range(remaining_elements.size()):
		var slot_index := heavy_index + 1 + remaining_index
		equal(String(spell_ids[slot_index]), abilities.spell_id_at(remaining_elements[remaining_index], "bolt"), "%s remaining Bolt %d follows canonical element order" % [champion_id, remaining_index])
	var priority_elements: Array[String] = []
	for affinity_value: Variant in affinities:
		priority_elements.append(String(affinity_value))
	priority_elements.append_array(remaining_elements)
	for experiment_index: int in range(StarterKit.EXPERIMENT_FAMILIES.size()):
		var expected_id := abilities.spell_id_at(priority_elements[experiment_index], StarterKit.EXPERIMENT_FAMILIES[experiment_index])
		equal(String(spell_ids[7 + experiment_index]), expected_id, "%s experiment %d uses exact Rapid/Spray/Rapid/Spray/Heavy priority policy" % [champion_id, experiment_index])


func _test_exact_representative_kits(champions: ChampionCatalog, abilities: AbilityCatalog) -> void:
	var two_affinity: Dictionary = StarterKit.build(champions, abilities, "oh_tipi")
	equal(two_affinity["spell_ids"], [
		"rillshot", "cinderbolt", "tide-shell", "gale-needle",
		"flintshot", "dawn-needle", "eclipse-disc", "rill-stream",
		"ember-sweep", "gale-stream", "shard-gale", "dawn-shell",
	], "Oh Tipi starter is the exact two-affinity reference weave")
	var three_affinity: Dictionary = StarterKit.build(champions, abilities, "grace_reava")
	equal(three_affinity["spell_ids"], [
		"gale-needle", "rillshot", "dawn-needle", "pressure-shell",
		"cinderbolt", "flintshot", "eclipse-disc", "gale-stream",
		"tideline", "glint-stream", "ember-sweep", "boulder-shell",
	], "Grace Reava starter is the exact three-affinity tie-order reference weave")


func _test_budget_boundary(champions: ChampionCatalog, abilities: AbilityCatalog) -> void:
	var starter: Dictionary = StarterKit.build(champions, abilities, "oh_tipi")
	var raw_points := 0
	for spell_id: String in starter["spell_ids"]:
		raw_points += int(abilities.ability(spell_id).get("points", 0))
	equal(raw_points, 33, "six authored Bolts, dominant Heavy and five experiments resolve to 33 catalog points")
	check(raw_points > 13, "the twelve-position weave is intentionally outside the separate thirteen-point active-build budget")
	var loadout := LoadoutDefinition.new()
	check(loadout.load_from_file(LOADOUT_PATH, abilities), "the independent three-active competitive loadout still validates: %s" % loadout.last_error)
	check(loadout.active_points <= int(loadout.data.get("active_budget", 0)), "the thirteen-point rule remains scoped to the three catalog actives")


func _test_projection_does_not_mutate_sources(champions: ChampionCatalog, abilities: AbilityCatalog) -> void:
	var champion_before: Dictionary = champions.data.duplicate(true)
	var ability_before: Dictionary = abilities.data.duplicate(true)
	for champion_id: String in champions.ordered_champion_ids():
		check(bool(StarterKit.build(champions, abilities, champion_id).get("valid", false)), "%s repeat preview generates without mutation" % champion_id)
	equal(champions.data, champion_before, "generating every starter leaves the champion source unchanged")
	equal(abilities.data, ability_before, "generating every starter leaves the ability source unchanged")
	var owned: Dictionary = StarterKit.build(champions, abilities, "oh_tipi")
	(owned["spell_ids"] as Array).clear()
	(owned["wire_ids"] as PackedInt32Array).fill(0)
	var rebuilt: Dictionary = StarterKit.build(champions, abilities, "oh_tipi")
	equal((rebuilt["spell_ids"] as Array).size(), PlayerState.SPELL_SLOT_COUNT, "caller mutation cannot alter later starter previews")
	check(not (rebuilt["wire_ids"] as PackedInt32Array).has(0), "caller mutation cannot alter catalog-derived starter wires")


func _test_failures(abilities: AbilityCatalog) -> void:
	var missing_champions: Dictionary = StarterKit.build(null, abilities, "oh_tipi")
	check(not bool(missing_champions["valid"]) and not String(missing_champions["error"]).is_empty(), "missing champion catalog fails with an actionable empty preview")
	equal((missing_champions["spell_ids"] as Array).size(), 0, "failed preview exposes no partial spell IDs")
	equal((missing_champions["wire_ids"] as PackedInt32Array).size(), 0, "failed preview exposes no partial wires")
	var champions := ChampionCatalog.new()
	check(champions.load_from_file(CHAMPION_PATH, abilities), "failure fixtures use a valid champion catalog")
	check(not bool(StarterKit.build(champions, AbilityCatalog.new(), "oh_tipi")["valid"]), "invalid ability catalog fails closed")
	check(not bool(StarterKit.build(champions, abilities, "missing_champion")["valid"]), "unknown champion fails closed")
	var tampered := AbilityCatalog.new()
	check(tampered.load_from_file(ABILITY_PATH), "tampered matrix fixture begins valid")
	# Singleton lookup follows the canonical wire map, not enumeration order.
	tampered.ability_ids_by_wire[140] = "missing-spell"
	var missing_cell: Dictionary = StarterKit.build(champions, tampered, "oh_tipi")
	check(not bool(missing_cell["valid"]) and String(missing_cell["error"]).contains("matrix cell"), "missing matrix cell fails closed with a bounded error")
	equal((missing_cell["spell_ids"] as Array).size(), 0, "matrix failure returns no partial starter")
	var wrong_family := AbilityCatalog.new()
	check(wrong_family.load_from_file(ABILITY_PATH), "wrong-family matrix fixture begins valid")
	# Tideline is the unique playable Water Spray and is absent from Oh Tipi's
	# generated experiments, so this tests family authority rather than duplication.
	wrong_family.ability_ids_by_wire[140] = "tideline"
	var wrong_cell: Dictionary = StarterKit.build(champions, wrong_family, "oh_tipi")
	check(not bool(wrong_cell["valid"]) and String(wrong_cell["error"]).contains("water/bolt"), "post-validation matrix family tamper fails closed through the canonical resolver")
	equal((wrong_cell["spell_ids"] as Array).size(), 0, "wrong-family matrix failure returns no partial starter")
	var enumeration_only := AbilityCatalog.new()
	check(enumeration_only.load_from_file(ABILITY_PATH), "enumeration-cache immunity fixture begins valid")
	var canonical_before: Dictionary = StarterKit.build(champions, enumeration_only, "oh_tipi")
	check(bool(canonical_before["valid"]), "canonical starter is valid before enumeration-only tamper")
	# This cache lists all 504 runtime entries. It is not the authority for a
	# requested singleton/family cell and must not redirect the saved starter.
	for replacement: String in ["missing-spell", "tideline"]:
		enumeration_only.spell_matrix_ids[0] = replacement
		var canonical_after: Dictionary = StarterKit.build(champions, enumeration_only, "oh_tipi")
		check(bool(canonical_after["valid"]), "enumeration-only tamper cannot invalidate the canonical starter")
		equal(canonical_after["spell_ids"], canonical_before["spell_ids"], "enumeration-only tamper cannot redirect any starter spell")
		equal(canonical_after["wire_ids"], canonical_before["wire_ids"], "enumeration-only tamper preserves every starter wire")
