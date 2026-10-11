extends RefCounted

# Offline projection only: no world, gameplay mutation, file writes or runtime hook.
const ABILITIES := "res://content/abilities/foundation_abilities_v1.json"
const CHAMPIONS := "res://content/champions/foundation_champions_v1.json"
const Recipes = preload("res://src/sim/hex/hex_recipe_policy.gd")


static func build() -> Dictionary:
	var abilities := AbilityCatalog.new()
	if not abilities.load_from_file(ABILITIES): return _failure(abilities.last_error)
	var champions := ChampionCatalog.new()
	if not champions.load_from_file(CHAMPIONS, abilities): return _failure(champions.last_error)
	var combat := CombatDefinitionTable.new()
	if not combat.compile(abilities): return _failure(combat.last_error)
	var config := SimConfig.new()
	var spells: Array = []
	var delivery_groups := {}
	for wire: int in combat.runtime_wire_ids():
		var ability := abilities.ability_from_wire(wire)
		var compiled := combat.definition(wire)
		var row: Dictionary = json_safe(compiled)
		row.merge({"wire_id": wire, "id": String(ability.id), "name": String(ability.display_name), "element": String(ability.element),
			"cycle_ticks": config.milliseconds_to_ticks(int(compiled.startup_ms)) + config.milliseconds_to_ticks(int(compiled.cooldown_ms))})
		spells.append(row)
		var delivery: Dictionary = json_safe(compiled)
		delivery.erase("element_wire_id")
		_group(delivery_groups, delivery, wire)
	var characters: Array = []
	var stat_groups := {}
	var races := {}
	for ancestry: String in ChampionCatalog.SUPPORTED_ANCESTRIES:
		races[ancestry] = {"ancestry": ancestry, "represented_count": 0, "character_ids": [], "observed_flight_capabilities": []}
	for id: String in champions.ordered_champion_ids():
		var authored := champions.champion(id)
		var actor := PlayerState.new() # Isolated projection target, never an existing actor.
		if not champions.apply_to_player(actor, id): return _failure("cannot project champion " + id)
		var stats := {}
		for stat: String in BodyTypeProfileCatalog.STAT_NAMES: stats[stat] = int(actor.get(stat))
		characters.append({"id": id, "wire_id": int(authored.wire_id), "name": String(authored.display_name),
			"ancestry": String(authored.ancestry), "body_type": String(authored.body_type), "stats": stats,
			"hurt_radius": actor.radius, "movement_collision_radius": MovementTuning.PLAYER_RADIUS,
			"flight_capable": actor.flight_capable, "float_max_duration_ms": actor.float_max_duration_ms,
			"affinities": json_safe(authored.affinities), "affinity_points": json_safe(authored.affinity_points),
			"starter_wire_ids": json_safe(actor.spell_wire_ids)})
		_group(stat_groups, stats, id)
		var race: Dictionary = races[String(authored.ancestry)]
		race.represented_count += 1
		race.character_ids.append(id)
		if not race.observed_flight_capabilities.has(actor.flight_capable): race.observed_flight_capabilities.append(actor.flight_capable)
	var reactions: Array = []
	for wire: int in Recipes.active_wire_ids():
		reactions.append(json_safe(Recipes.definition(wire))) # Resolved overrides, not raw authored rows.
	return {"status": "diagnostic_not_balance_acceptance", "schema_version": 1, "tick_rate": config.tick_rate,
		"scope": {"acceptance": "Audit correctness only; no fairness, viability, human feel or competitive balance acceptance.",
			"same_delivery_groups": "Identical compiled delivery excluding element only; chemistry is NOT equivalent.",
			"identical_stat_groups": "Seven applied stats only; NOT identical full kits, body geometry or air capability.",
			"cycle_ticks": "Same-wire minimum startup plus release-owned cooldown; not sustainable resource-limited throughput.",
			"recipe_damage": "Resolved base pulse_damage only; quantity, strength, exposure, eligibility and special effects still apply.",
			"units": "Flux/Health/Stamina and distances use milli-units; ratios use permille. Named ms/ticks fields retain their units; matter/capacity keep recipe-specific units."},
		"hashes": {"abilities": abilities.content_hash, "champions": champions.content_hash,
			"body_profiles": champions.body_type_profiles.content_hash, "combat_definitions": combat.content_hash,
			"resolved_recipes": CanonicalContent.sha256(reactions),
			"champion_application_source": FileAccess.get_file_as_string("res://src/content/champion_catalog.gd").sha256_text(),
			"movement_tuning_source": FileAccess.get_file_as_string("res://src/sim/movement/movement_tuning.gd").sha256_text()},
		"spells": spells, "same_delivery_groups": _ordered_groups(delivery_groups),
		"characters": characters, "identical_stat_groups": _ordered_groups(stat_groups),
		"races": races.values(), "recipes": reactions}


static func _group(groups: Dictionary, profile: Dictionary, member: Variant) -> void:
	var signature := CanonicalContent.sha256(profile)
	if not groups.has(signature): groups[signature] = {"signature": signature, "profile": profile.duplicate(true), "members": []}
	groups[signature].members.append(member)


static func _ordered_groups(groups: Dictionary) -> Array:
	var keys := groups.keys()
	keys.sort()
	var result: Array = []
	for key: String in keys: result.append(groups[key])
	return result


static func json_safe(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key: Variant in value: result[String(key)] = json_safe(value[key])
		return result
	if value is Array or value is PackedInt32Array or value is PackedInt64Array:
		var result: Array = []
		for child: Variant in value: result.append(json_safe(child))
		return result
	if value is Vector2i: return [value.x, value.y]
	assert(typeof(value) in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING], "audit encountered a non-JSON value")
	return value


static func _failure(reason: String) -> Dictionary:
	return {"status": "diagnostic_failed", "error": reason}
