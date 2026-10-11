class_name CharacterSelectionModel
extends RefCounted


# Presentation intent only. The host must resolve the wire against its own
# catalog and validate the actor/station/round again when accepting a request.
const Overview = preload("res://src/app/character_overview_model.gd")
const GRID_COLUMNS := 6
const GRID_ROWS := 5
const SIZE_ORDER := ["small", "middle", "large"]
const MAX_RACES := 64
const MAX_IDENTITIES := 512
const ATTUNEMENT_TIMEOUT_MS := 5000

var overview: Dictionary = {}
var race_index := 0
var character_index := 0
var equipped_id := ""
var pending_wire := 0
var status_message := ""
var last_error := ""
var _pending_context: Array = []
var _pending_deadline_ms := -1
var _observed_context: Array = []
var _observed_authority_id := ""
var _observed_authority_ready := false
var _display_cells: Array[Vector2i] = []
var _display_indices: Dictionary = {}


func configure(champions: ChampionCatalog, roster: ChampionRosterPlan) -> bool:
	# Configuration starts a new catalog lifetime. Pending requests, navigation
	# and equipped labels must never leak from a previous (possibly failed) one.
	race_index = 0
	character_index = 0
	equipped_id = ""
	_clear_pending_attunement()
	_observed_context.clear()
	_observed_authority_id = ""
	_observed_authority_ready = false
	_display_cells.clear()
	_display_indices.clear()
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
	_rebuild_display_order()
	return true


func races() -> Array:
	return overview.get("rows", [])


func open_for(champion_id: String) -> void:
	equipped_id = champion_id
	_clear_pending_attunement()
	status_message = "Inspect freely. Attune / Enter / A changes character, then restores its saved weave (starter if uncustomized)."
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
	if _display_cells.is_empty():
		return
	var index := maxi(0, display_index(race_index, character_index))
	var column := clampi(index % GRID_COLUMNS + column_delta, 0, GRID_COLUMNS - 1)
	var row := clampi(index / GRID_COLUMNS + row_delta, 0, (_display_cells.size() - 1) / GRID_COLUMNS)
	select_display_index(mini(row * GRID_COLUMNS + column, _display_cells.size() - 1))


func display_cells() -> Array[Vector2i]:
	# References into the immutable overview, never a reordered authority catalog.
	return _display_cells.duplicate()


func display_index(race: int, character: int) -> int:
	return int(_display_indices.get(Vector2i(race, character), -1))


func select_display_index(index: int) -> void:
	if index < 0 or index >= _display_cells.size():
		return
	var cell := _display_cells[index]
	select_cell(cell.x, cell.y)


func change_size_group(delta: int) -> void:
	var selected := selected_entry()
	if selected.is_empty():
		return
	var group := SIZE_ORDER.find(String(selected["body_type"]))
	var target := clampi(group + delta, 0, SIZE_ORDER.size() - 1)
	if target == group:
		return
	for index: int in range(_display_cells.size()):
		var cell := _display_cells[index]
		if String(characters(cell.x)[cell.y]["body_type"]) == SIZE_ORDER[target]:
			select_display_index(index)
			return


func _rebuild_display_order() -> void:
	_display_cells.clear()
	_display_indices.clear()
	for race: int in range(races().size()):
		for character: int in range(characters(race).size()):
			_display_cells.append(Vector2i(race, character))
	_display_cells.sort_custom(_display_cell_before)
	for index: int in range(_display_cells.size()):
		_display_indices[_display_cells[index]] = index


func _display_cell_before(left: Vector2i, right: Vector2i) -> bool:
	return Overview._size_then_name_before(characters(left.x)[left.y], characters(right.x)[right.y])


func change_race_page(delta: int) -> void:
	# Retained for callers using the old navigation seam. All cards stay visible;
	# the old paging keys now jump focus between Small / Middle / Large groups.
	change_size_group(delta)


func race_page() -> int:
	return 0


func race_page_count() -> int:
	return 1


func character_page() -> int:
	return 0


func visible_race_indices() -> Array[int]:
	var result: Array[int] = []
	for index: int in range(races().size()):
		result.append(index)
	return result


func visible_character_indices(race: int) -> Array[int]:
	var result: Array[int] = []
	var entries := characters(race)
	for index: int in range(entries.size()):
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
	_clear_pending_attunement()
	# Identity acknowledgement is not a weave acknowledgement: a guest's saved
	# twelve-slot restore can still be awaiting its separate host confirmation.
	status_message = "Attuned: %s. Resource percentages preserved; check the Spell Loom for your current weave." % String(entry["display_name"])


func refuse(reason: String) -> void:
	_clear_pending_attunement()
	status_message = reason if not reason.is_empty() else "Attunement refused. Return to the Gallery during Wellspring free practice."


# The caller binds the current local session identity before sending the intent.
# This is only a UI lifetime: expiry never cancels or retries a host request.
func bind_pending_attunement(context: Array, now_ms: int) -> bool:
	if pending_wire <= 0 or not _pending_context.is_empty() or not _valid_attunement_context(context) or now_ms < 0:
		return false
	_pending_context = context.duplicate(true)
	_pending_deadline_ms = now_ms + ATTUNEMENT_TIMEOUT_MS
	return true


# Only current published authority may complete an attunement. Neither a
# selected card nor an unsequenced feedback event proves the host accepted it.
# Call even when the Gallery is closed, including disconnect/synchronization.
func reconcile_attunement(context: Array, authoritative_champion_id: String, now_ms: int, authority_ready: bool = true) -> String:
	if not _valid_attunement_context(context) or now_ms < 0:
		return ""
	_observed_context = context.duplicate(true)
	var entry: Dictionary = overview.get("entries_by_id", {}).get(authoritative_champion_id, {})
	_observed_authority_ready = authority_ready and not entry.is_empty() and bool(entry.get("selectable", false))
	_observed_authority_id = authoritative_champion_id if _observed_authority_ready else ""
	if _observed_authority_ready:
		equipped_id = authoritative_champion_id
	if pending_wire <= 0 or _pending_context.is_empty():
		return ""
	# A new session cannot complete an old request, even if its character happens
	# to match. The visible equipped badge may still follow its actual authority.
	if context != _pending_context:
		_clear_pending_attunement()
		status_message = "Session changed. Check the current character before attuning again."
		return "context_changed"
	# Fresh matching authority wins at the deadline; timing is not cancellation.
	if _observed_authority_ready and int(entry.get("wire_id", 0)) == pending_wire:
		confirm_equipped(authoritative_champion_id)
		return "confirmed"
	if now_ms >= _pending_deadline_ms:
		_clear_pending_attunement()
		status_message = "Confirmation timed out. Check your current character before retrying; the host request was not cancelled."
		return "timed_out"
	return ""


# Feedback packets do not carry an attunement request sequence. They may describe
# an older change, so never use them to override fresh authority or another wire's
# pending intent. Existing non-network callers can retain confirm_equipped().
func confirm_attunement_feedback(champion_id: String, context: Array) -> bool:
	if context != _observed_context or not _observed_authority_ready or champion_id != _observed_authority_id:
		return false
	var entry: Dictionary = overview.get("entries_by_id", {}).get(champion_id, {})
	if pending_wire > 0 and (context != _pending_context or int(entry.get("wire_id", 0)) != pending_wire):
		return false
	if pending_wire > 0: confirm_equipped(champion_id)
	return true


func _clear_pending_attunement() -> void:
	pending_wire = 0
	_pending_context = []
	_pending_deadline_ms = -1


static func _valid_attunement_context(context: Array) -> bool:
	# Bootstrap supplies mode, local entity, world epoch and peer instance ID.
	# Keep only primitive values; no live network/world aliases are retained.
	if context.size() != 4: return false
	for value: Variant in context:
		if typeof(value) != TYPE_INT: return false
	return true


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
		result.append_array(Overview.perk_detail_paragraphs(entry))
		result.append("Affinity points guide starter spell choices; they do not increase spell damage or reduce Flux cost. Every character can try all 504 spells in the Range. Defeat rivals to learn their 30 signature spells.")
		if String(entry["air_action"]) == "flight":
			var duration := String.num(float(entry["flight_duration_ms"]) / 1000.0, 1)
			result.append("Air action: release the first jump, then press again and hold Jump while airborne for flight instead of a double jump; up to %s s per airtime, with a Stamina cost and drain. Flight adds no invulnerability." % duration)
		else:
			result.append("Air action: one paid double jump per airtime; this ancestry cannot fly.")
		for line: String in entry["stat_lines"]:
			result.append(line)
		result.append("Recovery values are base rates; unused Flux and Stamina recover faster.")
		result.append("Playstyle: " + String(entry["playstyle"]))
		result.append("Body role: " + String(entry["body_profile"].get("role", "")).capitalize())
		result.append("Hurtbox radius: %d px. Wall clearance: 18 px for every size; size does not lock shared movement actions." % (int(entry["hurt_radius"]) / 1000))
		# The old three foundation aliases are not today's twelve-slot weave.
		# CharacterStarterKit owns the generated pattern; the Loom shows the
		# exact positions and its explicit starter preview before replacement.
		result.append("The twelve-slot starter contains six element Bolts, one Heavy for the strongest affinity (first listed on a tie), and five Rapid/Spray/Heavy experiments. Customize all twelve positions at the Spell Loom.")
		result.append("Attuning preserves resource percentages and restores this character's saved weave, or its twelve-slot starter if uncustomized. Online weave restoration waits for host confirmation; the Spell Loom shows currently equipped spells.")
		result.append("Selecting your current character leaves its weave unchanged. Use the Spell Loom's explicit starter preview to review a reset before applying it. Every attack still costs Flux.")
	else:
		result.append(String(entry["note"]))
		result.append("No playable stats or accepted body art are implied by this identity record.")
	if not String(entry.get("reserved_future_affinity", "")).is_empty():
		result.append("Future affinity, not active: " + AbilityCatalog.element_display_name(String(entry["reserved_future_affinity"])))
	result.append(Overview.RACE_RULE_NOTE)
	return result


static func air_action_summary(entry: Dictionary) -> String:
	# Capabilities were resolved by applying the actual catalog to a detached
	# actor in Overview.build, not by maintaining a second ancestry allowlist.
	if not bool(entry.get("stats_available", false)):
		return "Air action: not available."
	match String(entry.get("air_action", "")):
		"flight":
			var duration_ms := int(entry.get("flight_duration_ms", 0))
			if duration_ms <= 0:
				return "Air: paid flight; duration unavailable."
			return "Air: paid flight up to %s s; no double jump." % String.num(float(duration_ms) / 1000.0, 1)
		"double_jump":
			return "Air: one paid double jump; no flight."
	return "Air action: unavailable; check Details."
