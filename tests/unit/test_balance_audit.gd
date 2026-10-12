extends FluxTestSuite

const Model = preload("res://scripts/balance-audit-model.gd")
const OUTPUT := "res://.godot/balance-audit.json"


func run() -> int:
	var cached_before: Dictionary = Model.json_safe(CombatTuning.cast_definition(140))
	var report: Dictionary = Model.build()
	equal(report.get("status"), "diagnostic_not_balance_acceptance", "offline report is diagnostic, never a fairness acceptance")
	if report.get("status") != "diagnostic_not_balance_acceptance": return finish("balance-audit")
	var canonical := CanonicalContent.stringify(report)
	var round_trip: Variant = JSON.parse_string(JSON.stringify(report))
	check(round_trip is Dictionary,"complete scenario report survives JSON round trip")
	if round_trip is Dictionary:
		equal(_json_difference(report,round_trip),"","JSON preserves every diagnostic value, key and structure despite its numeric type normalization")
		var wire_fixture: Dictionary = Model.json_safe({140: 7, 160: 3})
		var decoded_wire_fixture: Dictionary = JSON.parse_string(JSON.stringify(wire_fixture))
		equal(decoded_wire_fixture.keys(),["140","160"],"numeric wire IDs remain distinct string object keys")
		equal(int(decoded_wire_fixture["140"])+int(decoded_wire_fixture["160"]),10,"numeric-key counts survive JSON serialization")
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
	_test_tactical_decisions(report)
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
		var mixture := Model.Mixtures.definition(Model.Mixtures.mask_for_wire(int(row.wire_id)))
		equal(int(row.ingredient_count),mixture.elements.size(),"composition exposes actual ingredients rather than representative colour")
		equal(int(row.status_duration_ticks),SimConfig.new().milliseconds_to_ticks(int(definition.status_duration_ms)),"status reach is measured in the actual timer units")
		check(int(row.direct_damage_per_flux_permille)>0,"each delivery exposes a finite paid damage comparison")
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
	_test_rotation_scenarios(report,champions)
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


func _test_rotation_scenarios(report: Dictionary, champions: ChampionCatalog) -> void:
	equal(report.rotation_scenarios.size(),23,"bounded experiments preserve twenty controls and add led-branch/banked-hit/blocked-direct comparisons")
	var rows := {}
	var actor := PlayerState.new()
	check(champions.apply_to_player(actor,"oh_tipi"),"diagnostic budget bound uses the same real character")
	for scenario: Dictionary in report.rotation_scenarios:
		check(not rows.has(String(scenario.id)),"experiment identity is unique")
		rows[String(scenario.id)] = scenario
		equal(int(scenario.cast_ticks),720,"each experiment uses the stated six-second command window")
		equal(int(scenario.drain_ticks),360,"existing shots get the same explicit observation tail")
		check(int(scenario.paid_casts)>0 and int(scenario.paid_flux)>0,"experiment measures accepted paid casts")
		equal(int(scenario.damage),int(scenario.target_health_loss),"all owned direct, status and ground events reconcile with actual no-regen target Health loss")
		equal(int(scenario.damage),int(scenario.direct_damage)+int(scenario.ground_damage)+int(scenario.status_damage),"damage categories account for every observed loss without duplication")
		check(int(scenario.slots)>=1 and int(scenario.slots)<=12,"rotation cannot invent a thirteenth slot")
		check(int(scenario.peak_projectiles)<=SimConfig.MAX_ACTIVE_PROJECTILES,"ordinary world capacity still bounds diagnostic pressure")
		check(int(scenario.paid_flux)<=actor.flux_maximum+actor.flux_recovery_per_second*6,"diagnostic cannot spend more than initial reserve plus maximum possible recovery")
		check(int(scenario.remaining_flux)>=0 and int(scenario.remaining_flux)<=actor.flux_maximum,"ordinary resource limits remain intact")
		var accepted := 0
		var wires: Array = scenario.wire_ids
		for key: String in scenario.cast_counts_by_wire:
			check(wires.has(int(key)),"accepted casts belong to one of the equipped twelve positions")
			accepted += int(scenario.cast_counts_by_wire[key])
		equal(accepted,int(scenario.paid_casts),"by-spell counts account for every actual admission")
		equal(scenario.active_status_ticks.size(),6,"status exposure retains all six separate channels")
		for exposure: int in scenario.active_status_ticks:
			check(exposure>=0 and exposure<=1080,"nonstacking exposure is bounded by observed ticks")
		check(not String(scenario.world_hash).is_empty(),"experiment retains a repeatable terminal authority witness")
		check(bool(scenario.conservation_valid),"every diagnostic ends with valid paid conservation")
		equal(int(scenario.matter_paid),(int(scenario.paid_casts)+int(scenario.opponent_paid_casts))*600,"all diagnostic matter comes from counted ordinary admissions")
		for witness: Dictionary in scenario.delivery_hits:
			check(int(witness.projectile_id)>0 and int(witness.source_id)>0 and scenario.wire_ids.has(int(witness.wire_id)),"delivery hit preserves an observed owned source and equipped spell")
			check(int(witness.damage)>0 and int(witness.last_observed_strength)>0 and int(witness.last_observed_strength)<=int(witness.initial_strength),"delivery witness retains positive bounded observed source strength")
			check(int(witness.last_observed_remaining_distance)>=0 and int(witness.last_observed_remaining_distance)<=int(CombatTuning.cast_definition_view(int(witness.wire_id)).range),"witness cannot reset or enlarge authored travel")
	equal(int(rows.twelve_bolts_open.slots),12,"cadence test actually fills every position with distinct spells")
	equal(int(rows.twelve_forms_open.slots),12,"mixed-delivery test also uses a full weave")
	check(int(rows.fire_bolt_open.damage)>0 and int(rows.steam_bolt_open.damage)>0 and int(rows.all_six_bolt_open.damage)>0,"single, pair and six-element fixtures all land real damaging hits")
	for exposure: int in rows.all_six_bolt_open.active_status_ticks: check(exposure>0,"all-six direct hit actually exposes every status channel")
	check(int(rows.fire_bolt_open.active_status_ticks[1])>0 and int(rows.fire_bolt_open.active_status_ticks[2])==0,"Fire-only baseline cannot gain the mixture's Chilled status")
	check(int(rows.steam_bolt_open.active_status_ticks[2])>0,"Water/Fire composition contributes actual Chilled exposure")
	check(int(rows.twelve_bolts_cover.damage)<int(rows.twelve_bolts_open.damage),"solid cover produces a measured counter to a full Bolt rotation")
	check(String(rows.twelve_bolts_moving.world_hash)!=String(rows.twelve_bolts_open.world_hash),"moving-target case actually changes authority instead of relabeling the fixture")
	check(int(rows.rapid_small_open.target_radius)<int(rows.rapid_large_open.target_radius),"matched size experiment uses distinct actual authored hurt radii")
	equal(int(rows.rapid_small_open.target_radius),int(rows.rapid_small_moving.target_radius),"motion experiment preserves its small hurt radius")
	check(int(rows.fire_bolt_opposed.opponent_paid_casts)>0 and int(rows.fire_bolt_opposed.opponent_paid_flux)>0,"opposition actually pays and releases ordinary attack commands")
	check(int(rows.fire_bolt_opposed.damage_taken)>0,"opposition is a real return threat rather than extra dormant content")
	check(int(rows.fire_bolt_opposed_strafe.actor_distance_travelled)>0,"defensive strafe actually moves the paid actor")
	check(int(rows.mantle_close_pursuit.actor_distance_travelled)>0 and int(rows.mantle_close_pursuit.damage)>0,"Mantle gets an actual close pursuit experiment rather than an out-of-range damage comparison")
	check(bool(rows.split_corridor.corridor) and String(rows.split_corridor.world_hash)!=String(rows.split_open.world_hash),"corridor geometry changes the actual authority fixture")
	check(bool(rows.rebound_bank_cover.bank_aim) and bool(rows.rebound_bank_cover.solid_cover),"bank-shot experiment retains genuine solid cover")
	check(int(rows.split_open.split_events)>0 and rows.split_open.delivery_hits.is_empty(),"the original central-gap Split remains a real fork with no successful direct branch hit")
	check(int(rows.split_led_open.split_events)>0 and not rows.split_led_open.delivery_hits.is_empty(),"7.5-degree close-range legal aim makes a real paid branch reach the target")
	for witness: Dictionary in rows.split_led_open.delivery_hits: check(bool(witness.split) and not bool(witness.banked),"Split success belongs to an actual forked trajectory")
	check(bool(rows.rebound_bank_route.direct_route_blocked) and bool(rows.rebound_direct_blocked.direct_route_blocked),"matched bank/direct cases share genuinely occluding cover")
	check(int(rows.rebound_bank_route.valid_bank_requests)>0 and int(rows.rebound_bank_route.bank_events)>0 and not rows.rebound_bank_route.delivery_hits.is_empty(),"bank success requires legal planning, real reflection and same-paid-flight direct target loss")
	for witness: Dictionary in rows.rebound_bank_route.delivery_hits: check(bool(witness.banked) and not bool(witness.split),"Rebound success belongs to the reflected projectile rather than a ground field")
	check(rows.rebound_direct_blocked.delivery_hits.is_empty() and int(rows.rebound_direct_blocked.direct_damage)==0,"same cover defeats the unbanked direct-aim route")
	check(rows.rebound_bank_cover.delivery_hits.is_empty(),"original unsuccessful bank request cannot masquerade as a successful reflected hit")
	check(String(report.scope.rotation_scenarios).contains("not a sustainable DPS or PvP ranking"),"bounded experiment cannot become a fabricated balance verdict")


func _test_tactical_decisions(report: Dictionary) -> void:
	var mixed_keys := {&"pulse_ticks":12,"pulse_damage":2000,&"active_ticks":72,"name":"display"}
	var mixed_base := {"pulse_ticks":8,&"pulse_damage":1000,"active_ticks":72,&"extra_rule":true}
	equal(Model.Tactics.changed_mechanical_fields(mixed_keys,mixed_base),["extra_rule","pulse_damage","pulse_ticks"],"mixed authored String and compiled StringName keys normalize before ordered comparison")
	equal(Model.Tactics.changed_mechanical_fields(mixed_base,mixed_keys),["extra_rule","pulse_damage","pulse_ticks"],"changed field ordering is independent of dictionary insertion and comparison direction")
	equal(Model.Tactics.changed_mechanical_fields(mixed_keys,mixed_keys),[],"identical mixed-key policies have no changed fields")
	equal(report.tactical_decisions.size(),63,"every ingredient subset has a decision row")
	equal(report.hashes.tactical_decisions,CanonicalContent.sha256(report.tactical_decisions),"decision report carries its exact resolved identity")
	var ground_profiles := {}
	for row: Dictionary in report.tactical_decisions:
		var mask := int(row.element_mask)
		ground_profiles[mask] = row.mechanics
		var recipe := HexRecipePolicy.definition(HexRecipePolicy.wire_for_mask(mask))
		equal(row.headline,recipe.purpose,"headline follows resolved runtime purpose")
		equal(row.counter,recipe.counter,"counter follows resolved runtime behavior")
		equal(row.footprint,recipe.selection_kind,"decision footprint follows actual whole-cell selection")
		equal(int(row.formation_ticks),int(recipe.formation_ticks),"formation comparison uses actual ticks")
		equal(row.deliveries.size(),8,"every tactical row compares every existing delivery")
		equal(row.direct_hit_statuses.size(),int(row.ingredient_count),"direct-hit statuses are separate from battlefield product rules")
		check(not String(row.trigger_label).is_empty() and not String(row.environment).is_empty(),"decision row has a readable trigger and terrain context")
		equal(row.counter_scenario.status,"proposed_evaluation_not_executed_result","teaching prompts never masquerade as executed human or simulation evidence")
		var expected_comparisons := 0 if int(row.ingredient_count)==1 else int(row.ingredient_count)
		equal(row.simpler_comparisons.size(),expected_comparisons,"only immediate nonempty simpler subsets are compared")
		for delivery: Dictionary in row.deliveries:
			var compiled := CombatTuning.cast_definition_view(int(delivery.wire_id))
			equal(int(delivery.flux_cost),int(compiled.flux_cost),"tactical cost uses compiled paid Flux")
			equal(int(delivery.direct_damage_quote),int(compiled.damage),"tactical direct/shared quote is not an invented total field damage")
		for simpler: Dictionary in row.simpler_comparisons:
			equal(int(simpler.element_mask),mask^int(simpler.without_bit),"comparison removes exactly the named ingredient")
			check(not simpler.changed_mechanical_fields.is_empty(),"additional ingredient exposes actual changed resolved rules")
			for delta: Dictionary in simpler.delivery_deltas:
				var chosen := CombatTuning.cast_definition_view(MixtureCatalog.wire_for(mask,String(delta.family)))
				var base := CombatTuning.cast_definition_view(MixtureCatalog.wire_for(int(simpler.element_mask),String(delta.family)))
				equal(int(delta.extra_flux),int(chosen.flux_cost)-int(base.flux_cost),"ingredient cost delta is measured against that exact simpler spell")
	check(Model.Tactics.definition(0).is_empty() and Model.Tactics.definition(64).is_empty(),"out-of-range masks have no guessed tactical identity")
	_groups(report.recipe_mechanics_groups,ground_profiles)
	check(String(report.scope.recipe_mechanics_groups).contains("Distinct names alone do not prove"),"repeated resolved ground mechanics stay visible without an invented uniqueness claim")


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


func _json_difference(expected: Variant, actual: Variant, path: String = "$") -> String:
	# JSON has one number type; CanonicalContent intentionally distinguishes
	# integers and floats for authority. Compare this exported diagnostic's
	# values and shape without turning a failure into a full megabyte dump.
	if typeof(expected) in [TYPE_INT,TYPE_FLOAT] and typeof(actual) in [TYPE_INT,TYPE_FLOAT]:
		return "" if float(expected)==float(actual) else path+": number changed"
	if typeof(expected)!=typeof(actual): return path+": type changed"
	if expected is Dictionary:
		if expected.size()!=actual.size(): return path+": object size changed"
		for key: String in expected:
			if not actual.has(key): return path+"."+key+": missing key"
			var difference := _json_difference(expected[key],actual[key],path+"."+key)
			if not difference.is_empty(): return difference
	elif expected is Array:
		if expected.size()!=actual.size(): return path+": array size changed"
		for index: int in expected.size():
			var difference := _json_difference(expected[index],actual[index],path+"[%d]"%index)
			if not difference.is_empty(): return difference
	elif expected!=actual:
		return path+": value changed"
	return ""
