class_name CharacterSelectionModel
extends RefCounted


# Presentation intent only. The host must resolve the wire against its own
# catalog and validate the actor/station/round again when accepting a request.
const Overview = preload("res://src/app/character_overview_model.gd")
const COLUMNS_PER_PAGE := 7
const ROWS_PER_PAGE := 3
const MAX_RACES := 64
const MAX_IDENTITIES := 512

var overview: Dictionary = {}
var race_index := 0
var character_index := 0
var equipped_id := ""
var pending_wire := 0
var status_message := ""
var last_error := ""


func configure(champions: ChampionCatalog, roster: ChampionRosterPlan) -> bool:
	# Configuration starts a new catalog lifetime. Pending requests, navigation
	# and equipped labels must never leak from a previous (possibly failed) one.
	race_index = 0
	character_index = 0
	equipped_id = ""
	pending_wire = 0
	status_message = ""
	last_error = ""
	overview = Overview.build(champions, roster)
	if not bool(overview.get("valid", false)):
		last_error = String(overview.get("error", "Character data is unavailable."))
		overview = {}
		return false
	if races().is_empty() or races().size() > MAX_RACES or int(overview["champion_count"]) > MAX_IDENTITIES:
		last_error = "Character Gallery exceeds its bounded display contract."
		overview = {}
		return false
	return true


func races() -> Array:
	return overview.get("rows", [])


func open_for(champion_id: String) -> void:
	equipped_id = champion_id
	pending_wire = 0
	status_message = "Preview freely; only selecting a playable card requests attunement."
	race_index = 0
	character_index = 0
	for race: int in range(races().size()):
		var entries := characters(race)
		for index: int in range(entries.size()):
			if String(entries[index]["id"]) == champion_id:
				select_cell(race, index)
				return


func characters(race: int = -1) -> Array:
	var index := race_index if race < 0 else race
	return races()[index]["champions"] if index >= 0 and index < races().size() else []


func selected_entry() -> Dictionary:
	var entries := characters()
	return entries[character_index] if character_index >= 0 and character_index < entries.size() else {}


func select_cell(race: int, character: int) -> void:
	if race < 0 or race >= races().size():
		return
	race_index = race
	character_index = clampi(character, 0, maxi(0, characters().size() - 1))


func move_selection(row_delta: int, column_delta: int) -> void:
	select_cell(clampi(race_index + column_delta, 0, maxi(0, races().size() - 1)), character_index + row_delta)


func change_race_page(delta: int) -> void:
	var page := clampi(race_page() + delta, 0, race_page_count() - 1)
	select_cell(mini(page * COLUMNS_PER_PAGE + race_index % COLUMNS_PER_PAGE, maxi(0, races().size() - 1)), character_index)


func race_page() -> int:
	return race_index / COLUMNS_PER_PAGE


func race_page_count() -> int:
	return maxi(1, ceili(float(races().size()) / COLUMNS_PER_PAGE))


func character_page() -> int:
	return character_index / ROWS_PER_PAGE


func visible_race_indices() -> Array[int]:
	var result: Array[int] = []
	var first := race_page() * COLUMNS_PER_PAGE
	for index: int in range(first, mini(first + COLUMNS_PER_PAGE, races().size())):
		result.append(index)
	return result


func visible_character_indices(race: int) -> Array[int]:
	var result: Array[int] = []
	var entries := characters(race)
	# Only the focused column pages vertically; other columns retain their first
	# rows. This avoids hiding neighboring single-character races while browsing.
	var first := character_page() * ROWS_PER_PAGE if race == race_index else 0
	for index: int in range(first, mini(first + ROWS_PER_PAGE, entries.size())):
		result.append(index)
	return result


func request_selection() -> int:
	var entry := selected_entry()
	if pending_wire != 0:
		status_message = "Waiting for the host; another attunement cannot be queued."
		return 0
	if entry.is_empty() or not bool(entry.get("selectable", false)):
		status_message = "This identity is inspectable, but is not playable yet."
		return 0
	if String(entry["id"]) == equipped_id:
		status_message = "Already attuned. Your current spell setup is unchanged."
		return 0
	var wire := int(entry.get("wire_id", 0))
	if wire <= 0 or wire > 4096:
		status_message = "This identity has no valid playable wire."
		return 0
	pending_wire = wire
	status_message = "Waiting for the host to confirm attunement."
	return wire


func confirm_equipped(champion_id: String) -> void:
	var entry: Dictionary = overview.get("entries_by_id", {}).get(champion_id, {})
	if entry.is_empty() or not bool(entry.get("selectable", false)):
		return
	equipped_id = champion_id
	pending_wire = 0
	status_message = "Attuned: %s. Starting spells restored; resource percentages preserved." % String(entry["display_name"])


func refuse(reason: String) -> void:
	pending_wire = 0
	status_message = reason if not reason.is_empty() else "Attunement refused. Return to the Gallery during Wellspring free practice."


func detail_paragraphs() -> Array[String]:
	var entry := selected_entry()
	if entry.is_empty():
		return ["No champion is assigned to this race yet.", "Empty cells are not selectable.", Overview.RACE_RULE_NOTE]
	var result: Array[String] = ["%s / %s body / %s" % [entry["race"], String(entry["body_type"]).capitalize(), entry["status"]]]
	var affinities: Array[String] = []
	for element: String in entry["affinities"]:
		affinities.append("%s %d" % [AbilityCatalog.element_display_name(element), int(entry["affinity_points"].get(element, 0))])
	result.append("Affinity points: " + ", ".join(affinities))
	if bool(entry["stats_available"]):
		for line: String in entry["stat_lines"]:
			result.append(line)
		result.append("Recovery values are base rates; unused Flux and Stamina recover faster.")
		result.append("Playstyle: " + String(entry["playstyle"]))
		result.append("Body role: " + String(entry["body_profile"].get("role", "")).capitalize())
		result.append("Hurtbox radius: %d px. Wall clearance: 18 px for every size; all movement actions remain available." % (int(entry["hurt_radius"]) / 1000))
		var kit: Dictionary = entry["foundation_kit"]
		for slot: String in ["primary", "active_1", "active_2"]:
			if not String(kit.get(slot, "")).is_empty():
				result.append("Starting %s: %s" % [slot.replace("_", " "), String(kit[slot]).replace("_", " ")])
		result.append("Attuning restores this champion's starting spell setup and preserves resource percentages. Every attack still costs Flux.")
	else:
		result.append(String(entry["note"]))
		result.append("No playable stats or accepted body art are implied by this identity record.")
	if not String(entry.get("reserved_future_affinity", "")).is_empty():
		result.append("Future affinity, not active: " + AbilityCatalog.element_display_name(String(entry["reserved_future_affinity"])))
	result.append(Overview.RACE_RULE_NOTE)
	return result
