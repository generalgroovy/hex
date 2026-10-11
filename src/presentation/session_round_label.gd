class_name SessionRoundLabel
extends RefCounted


# Presentation only. Callers provide SessionRound.decoded() state; this helper
# neither admits packets nor changes scores, timers, participants or names.
# Render each returned line separately at font 11 in the 228 px text lane.
const NAME_CHARACTERS: int = 4
const PLAYERS_PER_LINE: int = 2
const TeamPresentation = preload("res://src/presentation/team_match_presentation.gd")


static func format(state: Dictionary, names: Dictionary, local_id: int, tick_rate: int) -> String:
	if TeamPresentation.is_team_round(state):
		return TeamPresentation.format(state, local_id, tick_rate)
	var phase := int(state.get("phase", SessionRound.Phase.HEARTH))
	if phase not in [SessionRound.Phase.ACTIVE, SessionRound.Phase.RESULT]:
		return ""
	var entries := _ordered_entries(state.get("entries", []))
	if entries.is_empty():
		return ""
	var safe_rate := maxi(1, tick_rate)
	var remaining := maxi(0, int(state.get("remaining_ticks", 0)))
	@warning_ignore("integer_division")
	var seconds: int = (remaining + safe_rate - 1) / safe_rate
	var lines: Array[String] = []
	if phase == SessionRound.Phase.ACTIVE:
		lines.append("COURT | %ds | FIRST %d" % [seconds, int(state.get("score_limit", 0))])
	else:
		var winner_id := int(state.get("winner_entity_id", 0))
		var outcome := "DRAW" if winner_id == 0 else "%s WINS" % _identity(winner_id, names, local_id)
		lines.append("%s | HEARTH IN %ds" % [outcome, seconds])
	var row: Array[String] = []
	var local_respawn_ticks := 0
	for entry: Dictionary in entries:
		var entity_id := int(entry.entity_id)
		row.append("%s %d" % [_identity(entity_id, names, local_id), int(entry.score)])
		if entity_id == local_id:
			local_respawn_ticks = maxi(0, int(entry.get("respawn_ticks", 0)))
		if row.size() == PLAYERS_PER_LINE:
			lines.append(" | ".join(row))
			row.clear()
	if not row.is_empty():
		lines.append(" | ".join(row))
	if phase == SessionRound.Phase.ACTIVE and local_respawn_ticks > 0:
		@warning_ignore("integer_division")
		var tenths: int = (local_respawn_ticks * 10 + safe_rate - 1) / safe_rate
		@warning_ignore("integer_division")
		var whole_seconds: int = tenths / 10
		lines.append("YOU P%d RETURN IN %d.%ds" % [local_id, whole_seconds, tenths % 10])
	return "\n".join(lines)


# participants is the current decoded round's entries Array, including RESULT
# entries after a same-tick draw. A positive old score or a nonzero winner is not
# evidence that this knockout scored. Team notices require hostile locked teams;
# an explicit uncredited event overrides any membership-based fallback.
static func knockout_notice(owner_id: int, target_id: int, participants: Array, names: Dictionary, round_state: Dictionary = {}, event: Dictionary = {}) -> String:
	var participant_ids: Array[int] = []
	var teams: Dictionary[int, int] = {}
	for entry: Dictionary in _ordered_entries(participants):
		participant_ids.append(int(entry.entity_id))
		teams[int(entry.entity_id)] = int(entry.get("team_id", 0))
	var target := _identity(target_id, names, 0)
	var uncredited := "%s was knocked out." % target
	if owner_id == target_id or not participant_ids.has(owner_id) or not participant_ids.has(target_id):
		return uncredited
	if event.has("scored") and not bool(event.scored):
		return uncredited
	var owner_team := int(teams.get(owner_id, 0))
	var target_team := int(teams.get(target_id, 0))
	if owner_team > 0 and owner_team == target_team:
		return uncredited
	if TeamPresentation.is_team_round(round_state):
		if owner_team not in TeamPresentation.TEAM_IDS or target_team not in TeamPresentation.TEAM_IDS:
			return uncredited
		if event.has("credited_team_id") and int(event.credited_team_id) != owner_team:
			return uncredited
		return "%s +1: %s defeats %s." % [TeamPresentation.team_name(owner_team), _identity(owner_id, names, 0), target]
	return "%s scores against %s." % [_identity(owner_id, names, 0), target]


static func _ordered_entries(value: Variant) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not value is Array:
		return entries
	var seen: Dictionary[int, bool] = {}
	for item: Variant in value:
		if not item is Dictionary:
			continue
		var entry: Dictionary = item
		var entity_id := int(entry.get("entity_id", 0))
		var score := int(entry.get("score", -1))
		if entity_id < 1 or entity_id > SessionRound.MAX_PLAYERS or seen.has(entity_id) \
			or score < 0 or score > SessionRound.MAX_SCORE_LIMIT:
			continue
		seen[entity_id] = true
		entries.append(entry)
	entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.score) > int(right.score) if int(left.score) != int(right.score) else int(left.entity_id) < int(right.entity_id)
	)
	return entries


static func _identity(entity_id: int, names: Dictionary, local_id: int) -> String:
	if entity_id < 1 or entity_id > SessionRound.MAX_PLAYERS:
		return "A traveller"
	if entity_id == local_id:
		return "YOU P%d" % entity_id
	var name_value: Variant = names.get(entity_id, "")
	var short_name := _short_name(name_value) if name_value is String else ""
	return "P%d" % entity_id if short_name.is_empty() else "P%d %s" % [entity_id, short_name]


static func _short_name(value: String) -> String:
	var result := ""
	for character: String in value.strip_edges().to_upper():
		var codepoint := character.unicode_at(0)
		# Keep player-authored text inside its own identity token. Strip controls,
		# line separators and bidi formatting; a pipe must not invent another row.
		if codepoint < 32 or (codepoint >= 127 and codepoint <= 159) \
			or codepoint in [0x061c, 0x200e, 0x200f, 0x2028, 0x2029] \
			or (codepoint >= 0x202a and codepoint <= 0x202e) \
			or (codepoint >= 0x2066 and codepoint <= 0x2069):
			continue
		result += "/" if character == "|" else character
		if result.length() >= NAME_CHARACTERS:
			break
	return result.strip_edges()
