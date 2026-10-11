extends FluxTestSuite


const ChampionRosterPlanScript = preload("res://src/content/champion_roster_plan.gd")


func run() -> int:
	var roster = ChampionRosterPlanScript.new()
	check(roster.load_from_files(), "canonical champion roster plan validates: %s" % roster.last_error)
	if roster.ordered_ids.is_empty():
		return finish("champion-roster-plan")
	equal(roster.data["status"], "canonical_identity_availability_registry", "registry describes live canonical identity and availability rather than planned-only content")
	equal(int(roster.data["schema_version"]), 1, "status clarification does not invent a structural schema change")
	var affinity_metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(String(roster.data["affinity_catalog"])))
	equal(affinity_metadata["status"], "canonical_six_element_affinity_allocation", "affinity metadata describes current six-element allocations")
	var stale_status = ChampionRosterPlanScript.new()
	stale_status.data = roster.data.duplicate(true)
	stale_status.data["status"] = "design_locked_nonselectable_registry"
	check(not stale_status.validate(), "obsolete planned-only status cannot silently reappear in live identity authority")
	equal(roster.ordered_ids.size(), 30, "roster plan contains thirty named playable identities with no reserved placeholder")
	equal(roster.ids_by_availability("planned").size(), 0, "all named entries have explicit baseline implementations")
	equal(roster.data["allowed_ancestries"].size(), 21, "Spiderkin replaces the unused ancestry slot instead of inventing an extra race")
	check("spiderkin" in roster.data["allowed_ancestries"] and "arachnoid" not in roster.data["allowed_ancestries"], "canonical active race vocabulary uses Spiderkin")
	for newcomer: Array in [["luuh_i_zeh", "Luuh I Zeh", "spiderkin", "small", {"dark": 2, "water": 1}], ["juul_i_yaina", "Juul I Yaina", "demon", "small", {"water": 2, "wind": 1}], ["faab_i_yaina", "Faab I Yaina", "angel", "middle", {"fire": 2, "light": 1}], ["joh_haynes", "Joh Haynes", "orc", "large", {"earth": 2, "fire": 1}]]:
		var identity: Dictionary = roster.entry(String(newcomer[0]))
		equal(identity.get("display_name"), newcomer[1], "newcomer preserves the exact reference name")
		equal(identity.get("ancestry"), newcomer[2], "newcomer preserves the assigned ancestry")
		equal(identity.get("body_role"), newcomer[3], "newcomer preserves the documented body class")
		equal(identity.get("availability"), "playable", "documented newcomer is implemented with explicit temporary art")
		var actual_points: Dictionary = roster.affinity_entry(String(newcomer[0])).get("affinity_points", {})
		var expected_points: Dictionary = newcomer[4]
		equal(actual_points.size(), expected_points.size(), "newcomer keeps exactly the documented affinity set")
		for element: String in expected_points:
			equal(int(actual_points.get(element, 0)), int(expected_points[element]), "newcomer preserves the exact v4 affinity strength")
	equal(roster.ids_by_availability("playable").size(), 30, "every named identity is promoted")
	equal(roster.ids_by_availability("placeholder"), [], "no reserved placeholder remains in the current roster")
	check(roster.entry("unnamed_angel").is_empty() and roster.affinity_entry("unnamed_angel").is_empty(), "unnamed Angel is absent from both current registries")
	equal(roster.entry("faab_i_yaina").get("availability"), "playable", "Faab I Yaina remains the named playable Angel")
	equal(roster.entry("sai_laas").get("display_name"), "Sai Laas", "new Nymph keeps the exact requested name")
	equal(roster.entry("sai_laas").get("ancestry"), "nymph", "Sai Laas is a Nymph")
	equal(roster.entry("sai_laas").get("body_role"), "small", "Sai Laas shares the existing Small Nymph baseline")
	check(not roster.entry("sai_laas").has("gender"), "unspecified Sai Laas gender is not invented")
	equal(roster.affinity_entry("sai_laas").get("affinity_points"), {"wind": 2.0, "fire": 1.0}, "Sai Laas has the existing three-point Air/Fire specialist allocation (JSON numeric values)")
	equal(String(roster.entry("s_wayne").get("ancestry", "")), "hobbit", "S. Wayne remains a Hobbit")
	equal(String(roster.entry("haara").get("ancestry", "")), "nymph", "Haara remains a Nymph")
	equal(String(roster.entry("wa_bidi").get("ancestry", "")), "goblin", "Wa Bidi remains a Goblin")
	for newcomer: Array in [["h_le_ne", "H. Lenee", "stoneborn", "middle", {"earth": 1, "wind": 1, "fire": 1}], ["fimu_yashiha", "Mifu", "treefolk", "small", {"water": 1, "wind": 1, "light": 1}]]:
		var identity: Dictionary = roster.entry(String(newcomer[0]))
		equal(identity.get("display_name"), newcomer[1], "new portrait character has its exact requested name")
		equal(identity.get("ancestry"), newcomer[2], "new portrait character has the requested race")
		equal(identity.get("body_role"), newcomer[3], "new portrait character uses its explicit existing body class")
		equal(identity.get("gender"), "female", "both requested portrait characters are female")
		equal(identity.get("availability"), "playable", "new named character is present in Gallery selection")
		var actual_points: Dictionary = roster.affinity_entry(String(newcomer[0])).get("affinity_points", {})
		var expected_points: Dictionary = newcomer[4]
		equal(actual_points.size(), expected_points.size(), "new portrait character has exactly its three requested affinities")
		for element: String in expected_points:
			equal(int(actual_points.get(element, 0)), int(expected_points[element]), "requested element uses the existing equal-point generalist rule")
	equal(String(roster.entry("spai_si").get("ancestry", "")), "demon", "Spai Si remains a Demon")
	for champion_id: String in ["juul_i_yaina", "faab_i_yaina", "spai_si"]:
		equal(String(roster.entry(champion_id).get("gender", "")), "male", "user-specified male identity is retained: " + champion_id)
	equal(String(roster.entry("wa_bidi").get("gender", "")), "female", "Wa Bidi retains the user-specified female identity")
	equal(roster.entry("juul_i_yaina").get("appearance", {}).get("hair", ""), "curly dark hair", "Juul retains curly dark hair")
	equal(roster.entry("faab_i_yaina").get("appearance", {}).get("hair", ""), "bald", "Faab retains a bald head")
	equal(String(roster.entry("hesus_christo").get("ancestry", "")), "elf", "Hesus Christo remains an Elf")
	equal(String(roster.entry("djonah_thaan").get("ancestry", "")), "vampire", "Djonah Thaan remains a Vampire")
	equal(String(roster.entry("nico_lai").get("display_name", "")), "Waka Aren Si", "legacy Nico technical ID resolves to the canonical display name")
	equal(String(roster.entry("donnok").get("display_name", "")), "Don Doko Don", "legacy Donnok technical ID resolves to the canonical display name")
	var mutable_copy := roster.entry("oh_tipi")
	mutable_copy["display_name"] = "Mutated"
	equal(String(roster.entry("oh_tipi").get("display_name", "")), "Oh Tipi", "roster lookup returns a defensive copy")

	var duplicate = ChampionRosterPlanScript.new()
	duplicate.data = roster.data.duplicate(true)
	((duplicate.data["champions"] as Array)[1] as Dictionary)["id"] = "oh_tipi"
	check(not duplicate.validate(), "duplicate roster identities fail closed")
	check(not duplicate.last_error.is_empty(), "invalid roster identity reports one cause")

	var placeholder_plan = ChampionRosterPlanScript.new()
	placeholder_plan.data = roster.data.duplicate(true)
	((placeholder_plan.data["champions"] as Array)[0] as Dictionary)["availability"] = "placeholder"
	check(not placeholder_plan.validate(), "a placeholder cannot silently reappear in the all-playable registry")

	var stale_name = ChampionRosterPlanScript.new()
	stale_name.data = roster.data.duplicate(true)
	((stale_name.data["champions"] as Array)[9] as Dictionary)["display_name"] = "Nico Lai"
	check(not stale_name.validate(), "stale player-facing identity fails linked-catalog validation")
	check(stale_name.entry("oh_tipi").is_empty(), "failed validation never exposes a partially populated roster")
	var bad_shape = ChampionRosterPlanScript.new()
	bad_shape.data = roster.data.duplicate(true)
	bad_shape.data["champions"] = "not an array"
	check(not bad_shape.validate(), "malformed roster collection fails without a script error")
	var archived := {"ancestry": "sylph", "elements": ["wind"], "atlas": "old-art.png"}
	var adapted: Dictionary = roster.visual_metadata("wa_bidi", archived)
	equal(adapted["ancestry"], "goblin", "shared visual adapter uses current identity")
	equal(adapted["archive_ancestry"], "sylph", "shared adapter preserves asset provenance")
	equal(adapted["atlas"], "old-art.png", "identity adaptation never silently replaces asset paths")
	(adapted["archive_elements"] as Array).append("ice")
	equal(archived["elements"], ["wind"], "archive metadata is deeply copied")
	(adapted["elements"] as Array).clear()
	equal(roster.affinity_entry("wa_bidi")["affinities"], ["fire", "wind"], "adapter cannot mutate canonical affinities")
	check(roster.visual_metadata("missing", archived).is_empty(), "unknown visual identity fails closed")
	_test_full_cast_candidate(roster)
	return finish("champion-roster-plan")


func _test_full_cast_candidate(roster: ChampionRosterPlan) -> void:
	const CANDIDATE_PATH := "res://content/champions/full_cast_candidate_v1.json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CANDIDATE_PATH))
	check(parsed is Dictionary, "isolated full-cast candidate is valid JSON")
	if not parsed is Dictionary: return
	var candidate: Dictionary = parsed
	equal(int(candidate.get("schema_version", 0)), 1, "candidate has its own non-runtime schema")
	equal(String(candidate.get("status", "")), "promoted_baseline_provenance_not_runtime", "candidate records baseline implementation without claiming final visual acceptance")
	equal(candidate.get("runtime_enabled"), false, "candidate is explicitly disabled as live content")
	check(not candidate.has("reserved_placeholder_id"), "current candidate does not retain a removed placeholder reservation")
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "real shared spell catalog validates candidate kit references")
	var live := ChampionCatalog.new()
	check(live.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "live catalog remains independently valid")
	equal(live.ordered_champion_ids().size(), 30, "live catalog explicitly owns the thirty promoted profiles")
	equal(int(candidate.get("current_playable_count", 0)), 30, "provenance current-status count follows the implemented catalog")
	var accidental := ChampionCatalog.new()
	check(not accidental.load_from_file(CANDIDATE_PATH, abilities), "candidate cannot accidentally load as the live ChampionCatalog schema")
	var projected := ChampionCatalog.new()
	# Explicit in-memory projection validates candidate numbers and existing
	# kits without changing paths, selection, or any production catalog file.
	projected.data = {"schema_version": ChampionCatalog.SUPPORTED_SCHEMA_VERSION, "id": "full-cast-candidate-test-projection", "default_champion_id": "oh_tipi", "champions": (candidate.get("champions", []) as Array).map(_migrate_historical_profile)}
	check(projected.validate(abilities), "all candidate stats, weighted affinities, ancestry and kits pass the existing runtime rules: %s" % projected.last_error)
	if not projected.last_error.is_empty(): return
	equal(projected.ordered_champion_ids().size(), 30, "candidate has every named identity and no extra champion")
	check(projected.champion("unnamed_angel").is_empty(), "placeholder is not assigned a candidate playable wire")
	equal((candidate.get("decisions_by_id", {}) as Dictionary).size(), 25, "only the twenty-five added profiles carry new-decision labels")
	equal(candidate.get("shared_runtime_spell_count"), 32, "historical candidate records its original eight-element library")
	var seen := {}
	var baseline_ids := {"small": "s_wayne", "middle": "oh_tipi", "large": "red_baron"}
	var expected_wire := 6
	for id: String in roster.ordered_ids:
		var identity := roster.entry(id)
		if identity["availability"] == "placeholder": continue
		var entry := projected.champion(id)
		check(not entry.is_empty() and not seen.has(id), "named candidate exists exactly once: " + id)
		seen[id] = true
		equal(entry.get("display_name"), identity["display_name"], "candidate preserves canonical display identity")
		equal(entry.get("ancestry"), identity["ancestry"], "candidate preserves canonical ancestry")
		equal(entry.get("body_type"), identity["body_role"], "candidate preserves documented body class")
		equal(entry.get("affinities"), roster.affinity_entry(id)["affinities"], "candidate preserves canonical affinity ordering")
		equal(entry.get("affinity_points"), roster.affinity_entry(id)["affinity_points"], "candidate never invents replacement affinity weights")
		equal(_current_profile_from_provenance(entry), live.champion(id), "every live field agrees with historical provenance except the exact declared perk-copy correction")
		if id in candidate["preserved_live_champion_ids"]:
			equal(entry, live.champion(id), "current live profile remains verbatim in the candidate")
		else:
			var baseline_id := String(baseline_ids[String(identity["body_role"])])
			equal(entry["stats"], live.champion(baseline_id)["stats"], "new candidate numbers are the explicit existing same-body baseline")
			equal(int(entry["wire_id"]), expected_wire, "proposed new wires follow stable roster order without renumbering current champions")
			expected_wire += 1
			var decision: Dictionary = (candidate["decisions_by_id"] as Dictionary)[id]
			equal(decision.get("stat_baseline_champion_id"), baseline_id, "new stats name their real baseline provenance")
			equal(decision.get("individual_balance_approved"), false, "new baseline is not advertised as individual balance approval")
			equal(decision.get("unique_runtime_art_approved"), false, "candidate data does not certify character art")
			equal(decision.get("status"), "implemented_baseline_temporary_art", "implemented baseline is not mislabeled as pending runtime work")
			equal(entry.get("art_status"), "temporary_body_template", "temporary visual reuse is explicit on each added runtime entry")
			equal(entry.get("template_source_id"), baseline_id, "temporary runtime template names the actual same-size source")
		var state := PlayerState.new(1)
		check(projected.apply_to_player(state, id), "candidate can initialize the existing generic player state in isolation")
		check(state.has_valid_spell_slots(), "candidate produces an ordinary valid twelve-slot weave")
		equal(state.proven_spell_wire_ids().size(), 504, "all candidates share the complete authoritative spell vocabulary before local progression filtering")
		for wire: int in state.kit_spell_wire_ids():
			check(CombatTuning.is_runtime_wire_id(wire), "candidate starter kit uses an existing authoritative spell only")
	equal(seen.size(), 30, "all thirty named identities are covered")
	equal(expected_wire, 31, "append-only named champion wire range now ends at 30")
	var invalid := ChampionCatalog.new()
	invalid.data = projected.data.duplicate(true)
	((invalid.data["champions"] as Array)[-1] as Dictionary)["stats"]["stamina_maximum"] = 800_001
	check(not invalid.validate(abilities), "candidate validation retains existing stat caps rather than expanding them")


func _migrate_historical_profile(historical: Dictionary) -> Dictionary:
	var result := historical.duplicate(true)
	var affinities: Array[String] = []
	var points := {}
	for old_element: String in historical.affinities:
		var element := ElementRules.fold_legacy_id(old_element)
		check(not element.is_empty(), "historical affinity has an explicit canonical parent")
		if not affinities.has(element): affinities.append(element)
		points[element] = float(points.get(element, 0.0)) + float(historical.affinity_points[old_element])
	result.affinities = affinities
	result.affinity_points = points
	const SPELLS := {"rimeshard":"rillshot", "frost-shell":"tide-shell", "sleet-stream":"rill-stream", "sleet":"tideline", "arc-primary":"cinderbolt", "thunder-shell":"cinder-shell", "spark-stream":"ember-stream", "spark-shower":"ember-sweep"}
	for slot: String in result.foundation_kit:
		result.foundation_kit[slot] = String(SPELLS.get(result.foundation_kit[slot], result.foundation_kit[slot]))
	for old_element: String in ["ice", "charge"]:
		var pattern := RegEx.new()
		check(pattern.compile("\\b" + old_element + "\\b") == OK, "explicit historical element word replacement compiles")
		result.playstyle = pattern.sub(String(result.playstyle), ElementRules.fold_legacy_id(old_element), true)
	return result


func _current_profile_from_provenance(historical: Dictionary) -> Dictionary:
	# Keep the promoted candidate as historical evidence. Only the explicit
	# obsolete perk denial changes; identity, role prose, numbers and kits remain
	# under whole-dictionary equality with the independently loaded live profile.
	const BASELINE_IDS := ["steezo", "treevor_mason", "oll_i", "fluup", "nico_lai",
		"spai_si", "leaf_hidden", "ha_rekt", "dr_apex", "haara", "hesus_christo",
		"grimm_bow", "biggy_bob", "jan_wicked", "ba_djoh", "urzh", "donnok",
		"djonah_thaan", "luuh_i_zeh", "juul_i_yaina", "faab_i_yaina", "joh_haynes"]
	const LATER_IDS := ["h_le_ne", "fimu_yashiha", "sai_laas"]
	var expected := historical.duplicate(true)
	var id := String(historical.get("id", ""))
	var old_suffix := ""
	if id in BASELINE_IDS:
		old_suffix = "no unique ability or race-bonus claim."
	elif id in LATER_IDS:
		old_suffix = "no unique racial passive."
	else:
		return expected
	var old_copy := String(historical.get("playstyle", ""))
	check(old_copy.ends_with(old_suffix), "historical copy must match its exact declared replacement: " + id)
	if old_copy.ends_with(old_suffix):
		expected["playstyle"] = old_copy.trim_suffix(old_suffix) + "race and personal perks apply in their listed windows."
	return expected
