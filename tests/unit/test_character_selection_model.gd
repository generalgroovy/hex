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
	model.open_for(champions.default_champion_id)
	equal(String(model.selected_entry()["id"]), champions.default_champion_id, "opening focuses the current champion")
	equal(model.equipped_id, champions.default_champion_id, "equipped identity remains separate from browsing")
	equal(model.request_selection(), 0, "same-champion confirmation is a no-op, preserving configured spells")
	var seen: Dictionary = {}
	var last_race := ""
	for race: int in range(model.races().size()):
		var race_id := String(model.races()[race]["race_id"])
		check(last_race.is_empty() or race_id > last_race, "race columns are alphabetical")
		last_race = race_id
		model.select_cell(race, 0)
		check(model.visible_race_indices().size() <= Model.COLUMNS_PER_PAGE, "race pages never exceed seven columns")
		check(race in model.visible_race_indices(), "focused race is always visible")
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
				check(description.contains("Hurtbox radius: %d px" % (champions.body_type_profiles.hurt_radius(String(entry["body_type"])) / 1000)), "Gallery hurtbox is derived from validated body data")
				check(description.contains("Wall clearance: 18 px for every size"), "Gallery distinguishes hurtbox from shared navigation clearance")
				for stat: String in entry["stat_lines"]:
					check(description.contains(stat), "details preserve source-derived full statistics")
				check(description.contains("starting spell setup") and description.contains("resource percentages"), "attunement consequences are explained")
			else:
				check(description.contains("No playable stats") and not description.contains("Health "), "planning record never invents statistics")
	equal(seen.size(), roster.ordered_ids.size(), "current and future roster counts come from validated data")
	equal(champions.content_hash, champion_hash, "browsing does not mutate playable authority")
	equal(roster.content_hash, roster_hash, "browsing does not mutate identity registry")
	model.move_selection(999, 999)
	equal(model.race_index, model.races().size() - 1, "navigation cannot overflow races")
	model.move_selection(-999, -999)
	equal(model.race_index, 0, "navigation cannot underflow races")
	equal(model.character_index, 0, "navigation cannot underflow cards")
	model.change_race_page(999)
	equal(model.race_page(), model.race_page_count() - 1, "race paging remains bounded")
	model.refuse("Move closer to the Gallery.")
	equal(model.pending_wire, 0, "refusal unlocks selection")
	equal(model.status_message, "Move closer to the Gallery.", "host refusal remains actionable")
	_test_future_rows(model)
	var invalid := Model.new()
	check(not invalid.configure(null, null), "unvalidated inputs fail closed")
	equal(invalid.request_selection(), 0, "failed configuration cannot emit a selection")
	_test_reconfiguration(champions, roster)
	return finish("character-selection-model")


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
	for index: int in range(12):
		model.select_cell(0, index)
		var visible: Array = model.visible_character_indices(0)
		check(index in visible and visible.size() <= Model.ROWS_PER_PAGE, "twelve future same-race identities paginate without shrinking cards")
		equal(model.request_selection(), 0, "synthetic future identity cannot become playable through display paging")
	model.select_cell(0, 11)
	model.move_selection(0, 1)
	check(model.character_index < maxi(1, model.characters().size()), "horizontal navigation clamps across sparse columns")
