extends RefCounted

# Offline projection and isolated command experiments; no live-world mutation,
# file writes or runtime hook.
const ABILITIES := "res://content/abilities/foundation_abilities_v1.json"
const CHAMPIONS := "res://content/champions/foundation_champions_v1.json"
const Recipes = preload("res://src/sim/hex/hex_recipe_policy.gd")
const Mixtures = preload("res://src/content/mixture_catalog.gd")
const Scenarios = preload("res://scripts/balance-audit-scenarios.gd")
const Tactics = preload("res://src/content/recipe_tactical_catalog.gd")
const PerkProbes = preload("res://scripts/balance-audit-perks.gd")


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
		var mixture := Mixtures.definition(Mixtures.mask_for_wire(wire))
		row["ingredient_count"] = mixture.elements.size()
		row["direct_damage_per_flux_permille"] = int(compiled.damage)*1000/maxi(1,int(compiled.flux_cost))
		row["status_duration_ticks"] = config.milliseconds_to_ticks(int(compiled.status_duration_ms))
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
	var scenarios: Array = json_safe(Scenarios.build(abilities,champions))
	for scenario: Dictionary in scenarios:
		if scenario.has("error"): return _failure(String(scenario.id)+": "+String(scenario.error))
	var tactics: Array = json_safe(Tactics.all())
	if tactics.size() != 63: return _failure("tactical decision catalog is incomplete")
	var recipe_mechanics_groups := {}
	for decision: Dictionary in tactics:
		_group(recipe_mechanics_groups,decision.mechanics,int(decision.element_mask))
	var perk_probes: Array = json_safe(PerkProbes.build(champions))
	for probe: Dictionary in perk_probes:
		if probe.has("error"): return _failure(String(probe.error))
	if perk_probes.size()!=51: return _failure("perk consumer diagnostic is incomplete")
	return {"status": "diagnostic_not_balance_acceptance", "schema_version": 3, "tick_rate": config.tick_rate,
		"scope": {"acceptance": "Audit correctness only; no fairness, viability, human feel or competitive balance acceptance.",
			"same_delivery_groups": "Identical compiled delivery excluding element only; chemistry is NOT equivalent.",
			"identical_stat_groups": "Seven applied stats only; NOT identical full kits, body geometry or air capability.",
			"cycle_ticks": "Same-wire minimum startup plus release-owned cooldown; not sustainable resource-limited throughput.",
			"recipe_damage": "Resolved base pulse_damage only; quantity, strength, exposure, eligibility and special effects still apply.",
			"composition": "All 504 compiled spells expose ingredient count, direct damage per paid Flux and quantized status duration. This does not price terrain utility.",
			"rotation_scenarios": "Twenty-three deterministic 6-second command windows plus 3-second drain use an isolated ordinary Hex court, Oh Tipi, a 2,000-Health training target, normal resources, independent spell clocks and no mid-run grants. Explicit experiments vary hurt size, paid opposition, moving targets, actor routes, close delivery placement, banks and corridors. Delivery witnesses join actual paid flight identities, fork/reflection events and direct target hits; requested bank flags alone prove no successful bank. Damage is observed owned event loss; status ticks are exposure, not additive stacks. These fixtures are not a sustainable DPS or PvP ranking.",
			"tactical_decisions": "All 63 rows derive timing, footprint, headline, counter, shared direct-hit descriptions and eight delivery costs from resolved runtime policies. Simpler-subset comparisons report changed rules, not superiority. Counter scenarios are proposed evaluation prompts, not executed results.",
			"recipe_mechanics_groups":"Groups resolved ground-policy fields after removing display and ingredient identity. Shared ground mechanics are explicitly visible; direct-hit statuses, costs and composition inputs can still differ. Distinct names alone do not prove distinct tactical choices.",
			"perk_probes":"All21 ancestry and30 personal perks receive condition-specific prepared fixtures and actual runtime consumer comparisons against identical champion stats with identity disabled. Favorable means a measured consumer direction, not isolated attribution, naturally reached gameplay or player preference. Zero and suppressed effects remain explicit.",
			"units": "Flux/Health/Stamina and distances use milli-units; ratios use permille. Named ms/ticks fields retain their units; matter/capacity keep recipe-specific units."},
		"hashes": {"abilities": abilities.content_hash, "champions": champions.content_hash,
			"body_profiles": champions.body_type_profiles.content_hash, "combat_definitions": combat.content_hash,
			"resolved_recipes": CanonicalContent.sha256(reactions),
			"tactical_decisions": CanonicalContent.sha256(tactics),
			"perk_probes": CanonicalContent.sha256(perk_probes),
			"champion_application_source": FileAccess.get_file_as_string("res://src/content/champion_catalog.gd").sha256_text(),
			"scenario_source": FileAccess.get_file_as_string("res://scripts/balance-audit-scenarios.gd").sha256_text(),
			"identity_policy_source": FileAccess.get_file_as_string("res://src/sim/entities/identity_perk_policy.gd").sha256_text(),
			"movement_tuning_source": FileAccess.get_file_as_string("res://src/sim/movement/movement_tuning.gd").sha256_text()},
		"spells": spells, "same_delivery_groups": _ordered_groups(delivery_groups),
		"characters": characters, "identical_stat_groups": _ordered_groups(stat_groups),
		"races": races.values(), "recipes": reactions, "rotation_scenarios":scenarios, "tactical_decisions":tactics,
		"recipe_mechanics_groups":_ordered_groups(recipe_mechanics_groups), "perk_probes":perk_probes}


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
		for key: Variant in value: result[str(key)] = json_safe(value[key])
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
