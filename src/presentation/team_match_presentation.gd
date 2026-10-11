class_name TeamMatchPresentation
extends RefCounted


# Presentation only: locked assignments and earned totals come from decoded
# SessionRound state. Hearth assignments are explicitly labelled previews.
const TEAM_IDS: Array[int] = [1, 2]


static func is_team_round(state: Dictionary) -> bool:
	return int(state.get("mode", SessionRound.Mode.FREE_FOR_ALL)) in [SessionRound.Mode.DUOS, SessionRound.Mode.TRIOS]


static func team_name(team_id: int) -> String:
	return "AMBER" if team_id == 1 else "TEAL" if team_id == 2 else ""


static func format(state: Dictionary, local_id: int, tick_rate: int) -> String:
	var phase := int(state.get("phase", SessionRound.Phase.HEARTH))
	if not is_team_round(state) or phase not in [SessionRound.Phase.ACTIVE, SessionRound.Phase.RESULT]:
		return ""
	var entries := _entries(state)
	if entries.is_empty():
		return ""
	var safe_rate := maxi(1, tick_rate)
	var seconds := _seconds_rounded_up(int(state.get("remaining_ticks", 0)), safe_rate)
	var lines: Array[String] = []
	if phase == SessionRound.Phase.ACTIVE:
		lines.append("%s | %ds | FIRST %d" % [_mode_label(int(state.mode)), seconds, int(state.get("score_limit", 0))])
	else:
		var winner := team_name(int(state.get("winner_team_id", 0)))
		lines.append("%s | HEARTH IN %ds" % ["DRAW" if winner.is_empty() else winner + " WINS", seconds])
	var scores: Dictionary = state.get("team_scores", {})
	lines.append("AMBER %d | TEAL %d" % [int(scores.get(1, 0)), int(scores.get(2, 0))])
	lines.append_array(_roster_lines(entries, local_id))
	if phase == SessionRound.Phase.ACTIVE:
		for entry: Dictionary in entries:
			var respawn := maxi(0, int(entry.get("respawn_ticks", 0)))
			if int(entry.entity_id) == local_id and bool(entry.get("present", true)) and respawn > 0:
				lines.append("YOU P%d RETURN IN %ss" % [local_id, _tenths_label(respawn, safe_rate)])
	return "\n".join(lines)


static func team_for_entity(state: Dictionary, entity_id: int) -> int:
	if not is_team_round(state):
		return 0
	for entry: Dictionary in _entries(state):
		if int(entry.entity_id) == entity_id:
			return int(entry.team_id)
	return 0


# The label is meaningful without color: local participants see YOU/ALLY/ENEMY,
# while observers see the neutral team name. Never label a practice actor or a
# late observer as an enemy merely because it is not the local champion.
static func actor_marker(state: Dictionary, entity_id: int, local_id: int) -> Dictionary:
	if not is_team_round(state) or int(state.get("phase", SessionRound.Phase.HEARTH)) not in [SessionRound.Phase.ACTIVE, SessionRound.Phase.RESULT]:
		return {}
	var actor_team := 0
	var local_team := 0
	for entry: Dictionary in _entries(state):
		if not bool(entry.get("present", true)):
			continue
		if int(entry.entity_id) == entity_id:
			actor_team = int(entry.team_id)
		if int(entry.entity_id) == local_id:
			local_team = int(entry.team_id)
	if actor_team == 0:
		return {}
	return _marker_for_team(actor_team, entity_id, local_team, local_id)


# One draw-local lookup: normalize/sort the frozen roster once for every actor.
# No retained cache, so a new snapshot, departure or observer reuse is immediate.
static func marker_lookup(state: Dictionary, local_id: int) -> Dictionary:
	if not is_team_round(state) or int(state.get("phase", SessionRound.Phase.HEARTH)) not in [SessionRound.Phase.ACTIVE, SessionRound.Phase.RESULT]:
		return {}
	var entries := _entries(state)
	var local_team := 0
	for entry: Dictionary in entries:
		if int(entry.entity_id) == local_id and bool(entry.get("present", true)):
			local_team = int(entry.team_id)
			break
	var markers := {}
	for entry: Dictionary in entries:
		if not bool(entry.get("present", true)):
			continue
		var entity_id := int(entry.entity_id)
		markers[entity_id] = _marker_for_team(int(entry.team_id), entity_id, local_team, local_id)
	return markers


static func _marker_for_team(actor_team: int, entity_id: int, local_team: int, local_id: int) -> Dictionary:
	var relation := "YOU" if entity_id == local_id else "ALLY" if actor_team == local_team else "ENEMY" if local_team > 0 else ""
	var label := "%s P%d" % [team_name(actor_team), entity_id]
	if not relation.is_empty():
		label = "%s P%d %s" % [relation, entity_id, team_name(actor_team)]
	return {"team_id": actor_team, "team_name": team_name(actor_team), "relation": relation, "label": label}


# participant_ids must be the actual eligible Hearth roster, not all world
# actors. Recompute the preview when that roster changes; begin() alone locks it.
static func hearth_label(profile_id: String, participant_ids: Array, local_id: int, tick_rate: int, countdown_ticks: int = 0, ready_by_id: Dictionary = {}) -> String:
	var required := SessionCharter.required_players(profile_id)
	if required not in [4, 6]:
		return ""
	var mode := SessionCharter.round_mode(profile_id)
	var ordered: Array[int] = []
	for value: Variant in participant_ids:
		if typeof(value) != TYPE_INT or int(value) < 1 or int(value) > SessionRound.MAX_PLAYERS or ordered.has(int(value)):
			return "%s | EXACTLY %d PLAYERS" % [_mode_label(mode), required]
		ordered.append(int(value))
	ordered.sort()
	var lines: Array[String] = []
	if countdown_ticks > 0 and ordered.size() == required:
		lines.append("%s PREVIEW | IN %ss" % [_mode_label(mode), _tenths_label(countdown_ticks, maxi(1, tick_rate))])
	else:
		lines.append("%s PREVIEW | %d/%d REQUIRED" % [_mode_label(mode), ordered.size(), required])
	if ordered.size() <= required:
		var preview: Array[Dictionary] = []
		for index: int in ordered.size():
			preview.append({"entity_id": ordered[index], "team_id": 1 + index % 2, "present": true})
		lines.append_array(_roster_lines(preview, local_id, ready_by_id, true))
		var has_unknown := ordered.any(func(entity_id: int) -> bool: return typeof(ready_by_id.get(entity_id)) != TYPE_BOOL)
		lines.append("+ READY | - WAITING" + (" | ? UNKNOWN" if has_unknown else ""))
	else:
		lines.append("EXACTLY %d PLAYERS NEEDED" % required)
	# At most five rows: root owns the sixth, binding-aware ready/start action.
	# The separate bounded help lines name the hazards and explain score policy.
	lines.append("SHARED HAZARDS CAN HURT ALL")
	return "\n".join(lines)


static func damage_policy_lines() -> Array[String]:
	return [
		"Only enemy-team knockouts score.",
		"Ally and self knockouts award no points.",
		"Damage rules vary by attack.",
		"Shared Fire, Steam and Conflagration",
		"can hurt allies and you.",
	]


static func _roster_lines(entries: Array[Dictionary], local_id: int, ready_by_id: Dictionary = {}, show_readiness: bool = false) -> Array[String]:
	var lines: Array[String] = []
	for team_id: int in TEAM_IDS:
		var roster: Array[String] = []
		for entry: Dictionary in entries:
			if int(entry.team_id) != team_id:
				continue
			var entity_id := int(entry.entity_id)
			var present := bool(entry.get("present", true))
			var label := "%sP%d" % ["YOU " if entity_id == local_id and present else "", entity_id]
			if show_readiness:
				var ready: Variant = ready_by_id.get(entity_id)
				label += ("+" if bool(ready) else "-") if typeof(ready) == TYPE_BOOL else "?"
			if not present:
				label += " LEFT"
			roster.append(label)
		lines.append("%s: %s" % [team_name(team_id), " ".join(roster) if not roster.is_empty() else "--"])
	return lines


static func _entries(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var values: Variant = state.get("entries", [])
	if not values is Array:
		return result
	var seen: Dictionary[int, bool] = {}
	for value: Variant in values:
		if not value is Dictionary:
			continue
		var entry: Dictionary = value
		var entity_id := int(entry.get("entity_id", 0))
		if entity_id < 1 or entity_id > SessionRound.MAX_PLAYERS or seen.has(entity_id) or int(entry.get("team_id", 0)) not in TEAM_IDS:
			continue
		seen[entity_id] = true
		result.append(entry)
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left.entity_id) < int(right.entity_id))
	return result


static func _mode_label(mode: int) -> String:
	return "2v2" if mode == SessionRound.Mode.DUOS else "3v3" if mode == SessionRound.Mode.TRIOS else ""


static func _seconds_rounded_up(ticks: int, tick_rate: int) -> int:
	@warning_ignore("integer_division")
	var seconds: int = (maxi(0, ticks) + tick_rate - 1) / tick_rate
	return seconds


static func _tenths_label(ticks: int, tick_rate: int) -> String:
	@warning_ignore("integer_division")
	var tenths: int = (maxi(0, ticks) * 10 + tick_rate - 1) / tick_rate
	@warning_ignore("integer_division")
	var whole: int = tenths / 10
	return "%d.%d" % [whole, tenths % 10]
