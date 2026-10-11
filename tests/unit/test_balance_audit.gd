extends FluxTestSuite

const Model = preload("res://scripts/balance-audit-model.gd")
const OUTPUT := "res://.godot/balance-audit.json"


func run() -> int:
	var cached_before: Dictionary = Model.json_safe(CombatTuning.cast_definition(140))
	var report: Dictionary = Model.build()
	equal(report.get("status"), "diagnostic_not_balance_acceptance", "offline report is diagnostic, never a fairness acceptance")
	if report.get("status") != "diagnostic_not_balance_acceptance": return finish("balance-audit")
	var canonical := CanonicalContent.stringify(report)
	equal(CanonicalContent.stringify(Model.build()), canonical, "repeated offline builds are deterministic")
	check(not canonical.contains('"balanced"'), "diagnostic report contains no fabricated balanced flag")
	check(String(report.scope.acceptance).contains("Audit correctness only"), "test success expressly concerns audit correctness")
	check(String(report.scope.same_delivery_groups).contains("chemistry is NOT equivalent"), "delivery grouping cannot claim elemental equivalence")
	check(String(report.scope.identical_stat_groups).contains("NOT identical full kits"), "equal stats cannot imply equal characters")
	_json_safe(report)
	equal(report.spells.size(), 504, "all504 active compiled spells are covered")
	equal(report.characters.size(), 30, "all thirty current characters are covered")
	equal(report.races.size(), ChampionCatalog.SUPPORTED_ANCESTRIES.size(), "every supported race has a count, including any unrepresented race")
	equal(report.recipes.size(), 63, "all sixty-three resolved nonempty ingredient subsets are covered")
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file(Model.ABILITIES), "independent production ability catalog loads")
	var champions := ChampionCatalog.new()
	check(champions.load_from_file(Model.CHAMPIONS, abilities), "independent production champion catalog loads")
	var combat := CombatDefinitionTable.new()
	check(combat.compile(abilities), "independent production combat table compiles")
	equal(report.hashes.abilities, abilities.content_hash, "ability identity matches authority")
	equal(report.hashes.champions, champions.content_hash, "character identity matches authority")
	equal(report.hashes.combat_definitions, combat.content_hash, "compiled identity matches authority")
	equal(report.hashes.body_profiles, champions.body_type_profiles.content_hash, "body identity matches authority")
	equal(report.hashes.resolved_recipes, CanonicalContent.sha256(report.recipes), "resolved recipe rows own their semantic hash")
	for hash_value: String in report.hashes.values(): equal(hash_value.length(), 64, "every recorded source identity is SHA-256")
	var spell_profiles := {}
	for index: int in report.spells.size():
		var row: Dictionary = report.spells[index]
		equal(row.wire_id, combat.runtime_wire_ids()[index], "spell row order matches the exact playable wire order")
		equal(row.id, abilities.ability_from_wire(int(row.wire_id)).id, "spell identity comes from its exact catalog wire")
		equal(row.element, abilities.ability_from_wire(int(row.wire_id)).element, "element identity remains explicit outside delivery grouping")
		var definition := combat.definition(int(row.wire_id))
		for key: String in definition: equal(row[key], Model.json_safe(definition[key]), "every reported combat value comes from compilation")
		var family:=String(definition.family)
		var expected_strength:Dictionary={"bolt":5,"heavy":15,"rapid":1,"spray":3,"mantle":8,"fuse":10,"split":8,"rebound":6}
		equal(int(definition.reaction_strength),int(expected_strength[family]),"added ingredients cannot multiply paid family strength")
		check(int(definition.flux_cost)>0 and int(definition.damage)>0,"every new or retained delivery has a positive paid damaging job")
		if family=="mantle":equal(int(definition.damage),16_000,"Mantle shared touch/trail pot has explicit16k ceiling")
		if family=="fuse":equal(int(definition.blast_damage),20_000,"Fuse shared blast pot has explicit20k ceiling")
		if family=="split":equal(int(definition.damage),14_000,"Split divides rather than duplicates the14k parent quote")
		if family=="rebound":equal(int(definition.remaining_bounces),2,"Rebound remains bounded to two banks")
		var clock := SimConfig.new()
		equal(row.cycle_ticks, clock.milliseconds_to_ticks(int(definition.startup_ms)) + clock.milliseconds_to_ticks(int(definition.cooldown_ms)), "cycle includes separately rounded startup and cooldown")
		definition.erase("element_wire_id")
		spell_profiles[row.wire_id] = Model.json_safe(definition)
	_groups(report.same_delivery_groups, spell_profiles)
	var stats_by_id := {}
	for index: int in report.characters.size():
		var row: Dictionary = report.characters[index]
		equal(row.id, champions.ordered_champion_ids()[index], "character row order follows production wires")
		var actor := PlayerState.new()
		check(champions.apply_to_player(actor, String(row.id)), "authority applies the exact character to a fresh fixture")
		for stat: String in BodyTypeProfileCatalog.STAT_NAMES: equal(row.stats[stat], actor.get(stat), "character stat equals actual applied authority")
		equal(row.ancestry, champions.champion(String(row.id)).ancestry, "race identity comes from the real character catalog")
		equal(row.body_type, champions.champion(String(row.id)).body_type, "body type is source-derived")
		equal(row.affinity_points, champions.champion(String(row.id)).affinity_points, "stat grouping does not erase differing affinities")
		equal(row.hurt_radius, actor.radius, "hurtbox uses the applied fixed body radius")
		equal(row.movement_collision_radius, MovementTuning.PLAYER_RADIUS, "movement clearance is not confused with body hurtbox")
		equal(row.flight_capable, actor.flight_capable, "race flight capability comes from character application")
		equal(row.float_max_duration_ms, actor.float_max_duration_ms, "body air allowance comes from character application")
		equal(row.starter_wire_ids, Array(actor.spell_wire_ids), "report retains distinct starter kits beside stat grouping")
		stats_by_id[row.id] = row.stats
	_groups(report.identical_stat_groups, stats_by_id)
	var represented := 0
	for index: int in report.races.size():
		var race: Dictionary = report.races[index]
		equal(race.ancestry, ChampionCatalog.SUPPORTED_ANCESTRIES[index], "supported ancestry order is complete and stable")
		var expected_ids: Array = []
		var expected_air: Array = []
		for character: Dictionary in report.characters:
			if character.ancestry != race.ancestry: continue
			expected_ids.append(character.id)
			if not expected_air.has(character.flight_capable): expected_air.append(character.flight_capable)
		equal(race.character_ids, expected_ids, "race membership is exact, without omitted or duplicated characters")
		equal(race.represented_count, expected_ids.size(), "race representation count matches members")
		equal(race.observed_flight_capabilities, expected_air, "unrepresented races would not receive guessed air capability")
		represented += int(race.represented_count)
	equal(represented, 30, "race partition accounts for every character once")
	for index: int in report.recipes.size():
		var resolved := Model.Recipes.definition(Model.Recipes.active_wire_ids()[index])
		equal(report.recipes[index], Model.json_safe(resolved), "every purpose, counter, phase, base damage, health and capacity matches resolved policy")
		check(not String(resolved.purpose).is_empty() and not String(resolved.counter).is_empty(), "each recipe retains its decision and counterplay")
	var output := FileAccess.open(OUTPUT, FileAccess.WRITE)
	check(output != null, "test alone opens the disposable offline diagnostic report")
	if output != null:
		output.store_string(JSON.stringify(report, "\t") + "\n")
		output.close()
		check(JSON.parse_string(FileAccess.get_file_as_string(OUTPUT)) is Dictionary, "saved diagnostic report is readable JSON")
	report.spells[0].damage = -1
	report.same_delivery_groups[0].members.clear()
	report.characters[0].stats.clear()
	report.recipes[0].purpose = "edited detached report"
	equal(CanonicalContent.stringify(Model.build()), canonical, "nested report edits cannot change later builds or authoritative content")
	equal(Model.json_safe(CombatTuning.cast_definition(140)), cached_before, "offline audit leaves the production compiled cache untouched")
	return finish("balance-audit")


func _groups(groups: Array, profiles: Dictionary) -> void:
	var seen := {}
	var seen_signatures := {}
	for group: Dictionary in groups:
		equal(group.signature, CanonicalContent.sha256(group.profile), "group signature describes its exact restricted profile")
		check(not seen_signatures.has(group.signature), "identical profiles share one group, not duplicate buckets")
		seen_signatures[group.signature] = true
		check(not group.members.is_empty(), "diagnostic groups contain actual members")
		for member: Variant in group.members:
			check(profiles.has(member) and not seen.has(member), "group membership is known and unique")
			equal(group.profile, profiles.get(member), "each grouped member has the same declared profile")
			seen[member] = true
	equal(seen.size(), profiles.size(), "grouping covers every profile exactly once")


func _json_safe(value: Variant) -> void:
	check(typeof(value) in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_ARRAY, TYPE_DICTIONARY], "report contains only JSON-safe values")
	if value is Dictionary:
		for key: Variant in value:
			check(key is String, "JSON object keys are strings")
			_json_safe(value[key])
	elif value is Array:
		for child: Variant in value: _json_safe(child)
