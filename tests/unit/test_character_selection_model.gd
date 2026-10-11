extends FluxTestSuite


const Model = preload("res://src/app/character_selection_model.gd")


func run() -> int:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "selection abilities load")
	var champions := ChampionCatalog.new()
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "selection champions load")
	var roster := ChampionRosterPlan.new()
	check(roster.load_from_files(), "selection roster loads")
	var model := Model.new()
	check(model.configure(champions, roster), "selection model accepts validated catalogs")
	var champion_hash := champions.content_hash
	var roster_hash := roster.content_hash
	var canonical_ids := champions.ordered_champion_ids().duplicate()
	var roster_ids := roster.ordered_ids.duplicate()
	_test_display_order(model)
	model.open_for(champions.default_champion_id)
	check(model.status_message.contains("saved weave") and model.status_message.contains("starter if uncustomized"), "opening explains saved-weave restoration instead of promising a reset")
	equal(String(model.selected_entry()["id"]), champions.default_champion_id, "opening focuses the current champion")
	equal(model.equipped_id, champions.default_champion_id, "equipped identity remains separate from browsing")
	equal(model.request_selection(), 0, "same-champion confirmation is a no-op, preserving configured spells")
	var seen: Dictionary = {}
	var last_race := ""
	for race: int in range(model.races().size()):
		var race_id := String(model.races()[race]["race_id"])
		check(last_race.is_empty() or race_id > last_race, "backing overview race rows retain their canonical alphabetical order")
		last_race = race_id
		model.select_cell(race, 0)
		equal(model.visible_race_indices().size(), model.races().size(), "legacy race references no longer filter the visible roster")
		check(race in model.visible_race_indices(), "every backing race remains addressable without paging")
		if model.characters().is_empty():
			equal(model.request_selection(), 0, "empty races cannot send a wire")
		for character: int in range(model.characters().size()):
			model.select_cell(race, character)
			var entry := model.selected_entry()
			var champion_id := String(entry["id"])
			check(not seen.has(champion_id), "every identity appears once")
			seen[champion_id] = true
			check(character in model.visible_character_indices(race), "focused character is always visible")
			var before_equipped := model.equipped_id
			var wire := model.request_selection()
			if bool(entry["selectable"]) and champion_id != before_equipped:
				equal(wire, int(champions.champion(champion_id)["wire_id"]), "request uses actual stable catalog wire, never card index")
				equal(model.request_selection(), 0, "pending selection prevents request spam")
				equal(model.equipped_id, before_equipped, "request does not optimistically mutate equipped identity")
				model.confirm_equipped(champion_id)
				equal(model.equipped_id, champion_id, "authority acknowledgement updates equipped identity")
				equal(model.pending_wire, 0, "acknowledgement clears pending intent")
			else:
				equal(wire, 0, "planned, placeholder and already-equipped cards emit no request")
			var description := " ".join(model.detail_paragraphs())
			if "wind" in entry["affinities"]:
				check(description.contains("Air %d" % int((entry["affinity_points"] as Dictionary).get("wind", 0))), "Gallery renders the wind affinity with its player-facing Air label")
			if bool(entry["stats_available"]):
				for obsolete: String in ["no unique ability", "no unique racial passive", "no race bonus", "race-bonus claim"]:
					check(not description.to_lower().contains(obsolete), "Gallery cannot deny the working identity perks: %s / %s" % [champion_id, obsolete])
				for scope: String in ["race", "character"]:
					var perk: Dictionary = entry.identity_perks[scope]
					for field: String in ["name", "summary", "window", "counter"]:
						check(description.contains(String(perk[field])), "Gallery Details preserves %s perk %s for %s" % [scope, field, champion_id])
				var actor := PlayerState.new()
				check(champions.apply_to_player(actor, champion_id), "Gallery movement description is compared with playable authority")
				if actor.flight_capable:
					var duration := String.num(float(actor.float_max_duration_ms) / 1000.0, 1)
					check(description.contains("flight instead of a double jump") and description.contains("up to %s s per airtime" % duration), "flying identities disclose their exclusive air action and size-specific limit")
					check(description.contains("release the first jump, then press again and hold Jump"), "Gallery explains deliberate second airborne Jump for flight")
					check(description.contains("Stamina cost and drain") and description.contains("no invulnerability"), "flight is never advertised as free or immune")
					check(not description.contains("this ancestry cannot fly"), "flying identities cannot inherit ordinary double-jump copy")
					equal(Model.air_action_summary(entry), "Air: paid flight up to %s s; no double jump." % duration, "first-screen flight comparison uses actual applied size allowance")
				else:
					check(description.contains("one paid double jump per airtime") and description.contains("this ancestry cannot fly"), "non-flying identities disclose their actual air action")
					check(not description.contains("flight instead of a double jump") and not description.contains(" s per airtime"), "non-flying identities never display an unusable flight allowance")
					equal(Model.air_action_summary(entry), "Air: one paid double jump; no flight.", "first-screen ordinary ancestry comparison matches actual applied capability")
				check(not description.contains("all movement actions remain available"), "Gallery never promises race-exclusive actions to every identity")
				check(description.contains("Hurtbox radius: %d px" % (champions.body_type_profiles.hurt_radius(String(entry["body_type"])) / 1000)), "Gallery hurtbox is derived from validated body data")
				check(description.contains("Wall clearance: 18 px for every size"), "Gallery distinguishes hurtbox from shared navigation clearance")
				for stat: String in entry["stat_lines"]:
					check(description.contains(stat), "details preserve source-derived full statistics")
				check(description.contains("saved weave") and description.contains("twelve-slot starter if uncustomized") and description.contains("resource percentages"), "details explain current saved-weave and resource preservation behavior")
				check(description.contains("waits for host confirmation") and description.contains("currently equipped spells"), "guest identity confirmation never implies an already-applied saved weave")
				check(description.contains("current character leaves its weave unchanged") and description.contains("explicit starter preview"), "no-op attunement cannot be mistaken for the deliberate Loom reset")
				check(not description.contains("Starting primary:") and not description.contains("Starting active"), "legacy three-alias kit is not advertised as the equipped twelve")
				check(description.contains("do not increase spell damage or reduce Flux cost") and description.contains("all 504 spells in the Range"), "affinity numbers cannot imply nonexistent power or equipment restrictions")
				var families := {"bolt": 0, "heavy": 0, "rapid": 0, "spray": 0}
				var bolt_elements := {}
				var heavy_element := ""
				for spell_wire: int in actor.spell_wire_ids:
					var spell := abilities.ability_from_wire(spell_wire)
					var family := AbilityCatalog._spell_family(spell)
					families[family] = int(families.get(family, 0)) + 1
					if family == "bolt": bolt_elements[String(spell.element)] = true
					if family == "heavy" and heavy_element.is_empty(): heavy_element = String(spell.element)
				equal(actor.spell_wire_ids.size(), 12, "actual character initialization fills the advertised twelve positions")
				equal(families, {"bolt": 6, "heavy": 2, "rapid": 2, "spray": 2}, "all thirty live starters include six Bolts, dominant Heavy and five experiments")
				for element: String in AbilityCatalog.DISPLAY_ELEMENT_IDS:
					check(bolt_elements.has(element), "advertised starter actually includes every element Bolt")
				var highest_affinity := String(entry.affinities[0])
				for element: String in entry.affinities:
					if int(entry.affinity_points[element]) > int(entry.affinity_points[highest_affinity]):
						highest_affinity = element
				equal(heavy_element, highest_affinity, "first advertised Heavy follows strongest affinity with first-listed ties")
				equal(AbilityCatalog._spell_family(abilities.ability_from_wire(actor.spell_wire_ids[entry.affinities.size()])), "heavy", "dominant Heavy follows the authored affinity Bolts")
				for affinity_index: int in entry.affinities.size():
					var early_spell := abilities.ability_from_wire(actor.spell_wire_ids[affinity_index])
					equal(AbilityCatalog._spell_family(early_spell), "bolt", "starter begins with affinity Bolts")
					equal(String(early_spell.element), String(entry.affinities[affinity_index]), "starter affinity order remains authored")
				equal(AbilityCatalog._spell_family(abilities.ability_from_wire(actor.spell_wire_ids[11])), "heavy", "last experiment is a second Heavy")
				check(String(abilities.ability_from_wire(actor.spell_wire_ids[11]).element) != heavy_element, "experimental Heavy never duplicates dominant Heavy")
			else:
				check(description.contains("No playable stats") and not description.contains("Health "), "planning record never invents statistics")
	equal(seen.size(), roster.ordered_ids.size(), "current and future roster counts come from validated data")
	equal(champions.content_hash, champion_hash, "browsing does not mutate playable authority")
	equal(roster.content_hash, roster_hash, "browsing does not mutate identity registry")
	equal(champions.ordered_champion_ids(), canonical_ids, "UI sort never reorders the canonical champion wire inventory")
	equal(roster.ordered_ids, roster_ids, "UI sort never reorders the identity registry")
	model.move_selection(999, 999)
	equal(model.display_index(model.race_index, model.character_index), 29, "navigation cannot overflow the final flat-grid card")
	model.move_selection(-999, -999)
	equal(model.display_index(model.race_index, model.character_index), 0, "navigation cannot underflow the first flat-grid card")
	model.change_race_page(999)
	equal(String(model.selected_entry().body_type), "large", "legacy page shortcut now focuses the final size group")
	equal(model.race_page_count(), 1, "all current identities share one unpaginated roster")
	equal(model.race_page(), 0, "legacy paging cannot hide another part of the roster")
	model.refuse("Move closer to the Gallery.")
	equal(model.pending_wire, 0, "refusal unlocks selection")
	equal(model.status_message, "Move closer to the Gallery.", "host refusal remains actionable")
	_test_future_rows(model)
	var invalid := Model.new()
	check(not invalid.configure(null, null), "unvalidated inputs fail closed")
	equal(invalid.request_selection(), 0, "failed configuration cannot emit a selection")
	_test_reconfiguration(champions, roster)
	_test_capability_fallbacks()
	_test_confirmation_copy(champions, roster)
	return finish("character-selection-model")


func _test_display_order(model: Model) -> void:
	var expected: Array[String] = [
		"grace_reava", "haara", "juul_i_yaina", "luuh_i_zeh", "fimu_yashiha", "s_wayne",
		"sai_laas", "steezo", "wa_bidi", "nico_lai", "biggy_bob", "djonah_thaan",
		"donnok", "faab_i_yaina", "h_le_ne", "hesus_christo", "jan_wicked", "leaf_hidden",
		"oh_tipi", "spai_si", "ba_djoh", "dr_apex", "fluup", "grimm_bow",
		"ha_rekt", "joh_haynes", "oll_i", "red_baron", "treevor_mason", "urzh",
	]
	var cells := model.display_cells()
	equal(cells.size(), Model.GRID_COLUMNS * Model.GRID_ROWS, "all thirty live characters fill the six-by-five grid")
	var actual: Array[String] = []
	for index: int in range(cells.size()):
		var cell := cells[index]
		actual.append(String(model.characters(cell.x)[cell.y].id))
		equal(model.display_index(cell.x, cell.y), index, "flat card index maps back to its exact overview entry")
		model.select_display_index(index)
		equal(String(model.selected_entry().id), expected[index], "flat selection resolves the expected stable identity")
		var row := index / Model.GRID_COLUMNS
		var column := index % Model.GRID_COLUMNS
		for delta: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			model.select_display_index(index)
			model.move_selection(delta.y, delta.x)
			var target := clampi(row + delta.y, 0, Model.GRID_ROWS - 1) * Model.GRID_COLUMNS + clampi(column + delta.x, 0, Model.GRID_COLUMNS - 1)
			equal(model.display_index(model.race_index, model.character_index), target, "spatial navigation follows the visible grid and clamps at every edge")
	equal(actual, expected, "visible order is Small, Middle, Large then name across ancestry boundaries")
	cells.clear()
	equal(model.display_cells().size(), 30, "callers cannot mutate the cached presentation order")
	model.select_display_index(0)
	model.change_size_group(1)
	equal(String(model.selected_entry().id), "biggy_bob", "next size jumps directly to the first Middle character")
	model.change_size_group(1)
	equal(String(model.selected_entry().id), "ba_djoh", "next size jumps directly to the first Large character")
	model.change_size_group(-1)
	equal(String(model.selected_entry().id), "biggy_bob", "previous size returns directly to the first Middle character")
	model.change_size_group(-1)
	equal(String(model.selected_entry().id), "grace_reava", "previous size reaches the first Small character")
	equal(model.display_cells().size(), 30, "size shortcuts move focus without filtering or paging any card")


func _test_capability_fallbacks() -> void:
	equal(Model.air_action_summary({}), "Air action: not available.", "missing optional entry data cannot fabricate an air action")
	equal(Model.air_action_summary({"stats_available": false, "air_action": "flight", "flight_duration_ms": 2400}), "Air action: not available.", "unavailable identities cannot inherit a playable flight preview")
	equal(Model.air_action_summary({"stats_available": true, "air_action": "future_action"}), "Air action: unavailable; check Details.", "unknown future capabilities are not silently called double jump")
	equal(Model.air_action_summary({"stats_available": true, "air_action": "flight"}), "Air: paid flight; duration unavailable.", "missing flight time is not presented as a free or zero-second allowance")
	equal(Model.air_action_summary({"stats_available": true, "air_action": "flight", "flight_duration_ms": -1}), "Air: paid flight; duration unavailable.", "negative optional flight time cannot become a displayed capability")


func _test_confirmation_copy(champions: ChampionCatalog, roster: ChampionRosterPlan) -> void:
	var model := Model.new()
	check(model.configure(champions, roster), "confirmation-copy fixture configures")
	model.open_for("s_wayne")
	model.equipped_id = "oh_tipi"
	check(model.request_selection() > 0, "confirmation fixture has a real pending identity request")
	var context: Array = [2, 1, 7, 10]
	check(model.bind_pending_attunement(context, 1000), "confirmation fixture binds the current session")
	equal(model.reconcile_attunement(context, "s_wayne", 1100, true), "confirmed", "published identity resolves the pending attunement")
	check(model.status_message.contains("Attuned:") and model.status_message.contains("Resource percentages preserved"), "identity confirmation reports only confirmed character/resource consequences")
	check(not model.status_message.contains("restored") and not model.status_message.contains("applied"), "identity acknowledgement does not claim a pending guest weave has completed")
	check(model.status_message.contains("Spell Loom") and model.status_message.contains("current weave"), "confirmation directs the player to actual equipped spells")
	var confirmed_status := model.status_message
	check(not model.confirm_attunement_feedback("oh_tipi", context), "late feedback for the old identity is ignored")
	equal(model.status_message, confirmed_status, "late identity feedback cannot resurrect obsolete starter-restored messaging")
	check(not model.confirm_attunement_feedback("s_wayne", [2, 1, 6, 10]), "old-session feedback is not current weave evidence")
	equal(model.status_message, confirmed_status, "old-session feedback leaves current confirmation text unchanged")


func _test_reconfiguration(champions: ChampionCatalog, roster: ChampionRosterPlan) -> void:
	var model := Model.new()
	check(model.configure(champions, roster), "reload fixture starts valid")
	model.open_for("s_wayne")
	model.equipped_id = "oh_tipi"
	check(model.request_selection() > 0, "reload fixture has an actual pending request")
	check(not model.configure(null, null), "invalid reload is refused")
	equal(model.pending_wire, 0, "invalid reload discards pending authority intent")
	equal(model.equipped_id, "", "invalid reload does not retain stale equipped identity")
	equal(model.race_index, 0, "invalid reload resets race navigation")
	equal(model.character_index, 0, "invalid reload resets card navigation")
	check(model.selected_entry().is_empty(), "invalid reload has no selectable stale entry")
	check(model.display_cells().is_empty(), "invalid reload releases its cached display projection")
	check(model.configure(champions, roster), "valid data recovers after rejected reload")
	equal(model.status_message, "", "valid reload clears stale acknowledgement text")
	model.open_for("s_wayne")
	model.equipped_id = "oh_tipi"
	check(model.request_selection() > 0, "recovered Gallery can submit a deliberate new request")
	check(model.configure(champions, roster), "successful replacement also resets pending state")
	equal(model.pending_wire, 0, "successful replacement does not inherit a request")
	equal(model.equipped_id, "", "successful replacement waits for fresh equipped identity")


func _test_future_rows(model: RefCounted) -> void:
	# Presentation-only synthetic growth fixture, never loaded as playable data.
	var expanded: Dictionary = model.overview.duplicate(true)
	var first: Dictionary = expanded["rows"][0]
	var seed: Dictionary = (expanded["entries_by_id"].values()[0] as Dictionary).duplicate(true)
	first["champions"] = []
	for index: int in range(12):
		var entry := seed.duplicate(true)
		entry["id"] = "future_%d" % index
		entry["selectable"] = false
		first["champions"].append(entry)
	model.overview = expanded
	model._rebuild_display_order()
	for index: int in range(12):
		model.select_cell(0, index)
		var visible: Array = model.visible_character_indices(0)
		check(index in visible and visible.size() == 12, "same-ancestry identities stay in one flat projection without ancestry paging")
		check(model.display_index(0, index) >= 0, "every synthetic identity has an exact flat-grid reference")
		equal(model.request_selection(), 0, "synthetic future identity cannot become playable through display sorting")
	model.select_cell(0, 11)
	model.move_selection(0, 1)
	check(model.character_index < maxi(1, model.characters().size()), "flat navigation always resolves a valid backing character reference")
