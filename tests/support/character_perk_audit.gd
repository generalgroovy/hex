extends RefCounted

const Perks = preload("res://src/content/character_perk_catalog.gd")
const LOWER_BENEFITS := ["incoming_damage_ratio", "knockback_ratio", "movement_cost_ratio", "spell_startup_ratio", "spell_cooldown_ratio"]

# Root's integration suite can call this after loading the production roster.
# This verifies identity coverage and meaningful mechanism signatures, not feel.
static func errors(champions: ChampionCatalog) -> Array[String]:
	var result: Array[String] = []
	var ids := {}
	var signatures := {}
	var rows := Perks.all()
	if rows.size() != 30: result.append("character perk count is not30")
	if champions == null or champions.champions_by_id.size() != rows.size():
		result.append("perk coverage differs from the production roster")
		return result
	for row: Dictionary in rows:
		var id := String(row.champion_id)
		var source: Dictionary = champions.champions_by_id.get(id, {})
		if source.is_empty() or int(source.get("wire_id", 0)) != int(row.wire_id): result.append("identity mismatch: " + id)
		if ids.has(id): result.append("duplicate character: " + id)
		ids[id] = true
		var signature := Perks.mechanical_signature(row)
		if signatures.has(signature): result.append("duplicate mechanism independent of percentage: " + id)
		signatures[signature] = true
		if String(row.name).length() > 24 or String(row.summary).length() > 90: result.append("compact identity copy exceeds Gallery allowance: " + id)
		for text_key: String in ["name", "summary", "window", "counter", "reference"]:
			if String(row.get(text_key, "")).is_empty(): result.append("missing " + text_key + ": " + id)
		if not String(row.reference).begins_with("https://"): result.append("missing primary reference URL: " + id)
		if id == "nico_lai" and (not String(row.counter).contains(String(source.get("display_name", ""))) or String(row.counter).contains("Nico")):
			result.append("Quiet Circuit guidance must use the current roster display name")
		if id == "juul_i_yaina" and (not String(row.window).contains("air dodge has finished") or not String(row.summary).contains("dodge finished")):
			result.append("Last Ember Step guidance must distinguish a completed dodge from its active timer")
		for token: String in String(row.condition).split("&"):
			if not Perks.CONDITION_LABELS.has(token): result.append("unknown condition token: " + token)
		var benefit := false
		var drawback := false
		for effect: String in row.effects:
			var amount := int(row.effects[effect])
			if not Perks.EFFECT_LABELS.has(effect): result.append("unknown runtime effect: " + effect)
			if amount < 850 or amount > 1200 or amount == 1000: result.append("unbounded or no-op modifier: " + id)
			if effect == "incoming_damage_ratio" and amount < 900: result.append("excess damage resistance: " + id)
			var favorable := amount < 1000 if effect in LOWER_BENEFITS else amount > 1000
			benefit = benefit or favorable
			drawback = drawback or not favorable
		if not benefit or not drawback: result.append("missing active benefit or tradeoff: " + id)
		# Mutating a UI copy cannot alter the hot-path authored authority.
		var original := Perks.raw_definition(int(row.wire_id)).duplicate(true)
		row.effects.clear()
		if Perks.raw_definition(int(row.wire_id)) != original: result.append("public copy mutates shared authority: " + id)
	return result
