extends FluxTestSuite


const ABILITY_PATH: String = "res://content/abilities/foundation_abilities_v1.json"
const CHAMPION_PATH: String = "res://content/champions/foundation_champions_v1.json"
const Recovery = preload("res://src/sim/entities/resource_recovery.gd")


func run() -> int:
	_test_repository_catalog()
	_test_all_promoted_kits_execute()
	_test_affinity_point_budget_and_treevor_exception()
	_test_shared_affinity_pairs()
	_test_existing_single_lane_bolt_primaries()
	_test_disabled_spell_admission_fails_closed()
	_test_profiles_are_authoritative()
	_test_modest_size_stamina_reserve()
	for tick_rate: int in [120]:
		_test_profiles_execute_at_rate(tick_rate)
	_test_invalid_profiles_fail_closed()
	return finish("champion-catalog")


func _catalog() -> ChampionCatalog:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file(ABILITY_PATH), "ability catalog loads for champions")
	var catalog := ChampionCatalog.new()
	check(catalog.load_from_file(CHAMPION_PATH, abilities), "champion catalog validates: %s" % catalog.last_error)
	return catalog


func _test_all_promoted_kits_execute() -> void:
	var catalog := _catalog()
	var cases := 0
	for champion_id: String in catalog.ordered_champion_ids():
		for slot: int in range(3):
			for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
				var world := SimWorld.new(120, 1, CollisionWorld.new(6_000_000, 6_000_000))
				check(catalog.apply_to_player(world.player(), champion_id), champion_id + " applies before eight-direction casting")
				var state := world.player()
				state.position_x = 3_000_000
				state.position_y = 3_000_000
				for stat: String in catalog.champion(champion_id)["stats"]:
					equal(int(state.get(stat)), int(catalog.champion(champion_id)["stats"][stat]), "all body-stat values reach authority: " + champion_id + "/" + stat)
				var wire := state.spell_wire_id(slot + 1)
				var definition := CombatTuning.cast_definition(wire)
				check(CombatTuning.runtime_wire_ids().has(wire), champion_id + " starts with executable spells")
				var before_flux := state.flux
				var bits: int = [SimCommand.PRESSED_SPELL_1, SimCommand.PRESSED_SPELL_2, SimCommand.PRESSED_SPELL_3][slot]
				check(world.step([SimCommand.new(0, 1, 0, 0, 0, bits, direction.x, direction.y)]), champion_id + " accepts configured spell input")
				equal(before_flux - state.flux, int(definition["flux_cost"]), champion_id + " pays the exact compiled cost once")
				var starts := 0
				for event: Dictionary in world.combat_events:
					if event.get("type") == "cast_started": starts += 1
				equal(starts, 1, "one press accepts exactly one paid startup")
				var releases := 0
				var release_kind: String = {"projectile": "projectile_spawned", "beam": "beam_fired", "spray": "spray_fired", "field": "field_spawned"}.get(String(definition["shape"]), "")
				var expected_releases := (definition.get("projectile_rotations", [Vector2i(1000, 0)]) as Array).size() if definition["shape"] == "projectile" else 1
				for _tick: int in range(world.config.milliseconds_to_ticks(int(definition["startup_ms"])) + 1):
					check(world.step([SimCommand.new(world.tick, 1, 0, 0, 0, 0, direction.x, direction.y)]), "kit completes authoritative startup without error")
					for event: Dictionary in world.combat_events:
						check(event.get("type") != "cast_refused", "accepted startup cannot silently become a refused cast")
						if event.get("type") == release_kind:
							releases += 1
							equal(int(event.get("wire_id", event.get("source_wire_id", 0))), wire, "paid release retains exact starter identity")
					if releases > 0: break
				equal(releases, expected_releases, "every paid starter releases its actual lane/shape count: " + champion_id)
				equal(state.pending_cast_wire_id, 0, "paid startup clears on real release")
				for projectile: ProjectileState in world.projectiles:
					check(projectile.velocity_x * direction.x + projectile.velocity_y * direction.y > 0, "live projectile follows requested screen-cardinal direction")
				check(state.has_valid_spell_slots(), "kit casting preserves valid global slots")
				cases += 1
	equal(cases, 30 * 3 * 8, "all thirty profiles, three starter slots and eight directions execute")


func _test_repository_catalog() -> void:
	var catalog := _catalog()
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file(ABILITY_PATH), "ability catalog reloads for authored-kit affinity checks")
	equal(catalog.default_champion_id, "oh_tipi", "Oh Tipi is the safe first-run champion")
	equal(catalog.ordered_champion_ids().slice(0, 5), ["oh_tipi", "s_wayne", "red_baron", "grace_reava", "wa_bidi"], "original five wire identities remain stable")
	equal(catalog.ordered_champion_ids().size(), 30, "all thirty named identities are playable without a reserved placeholder")
	equal(catalog.next_champion_id("oh_tipi"), "s_wayne", "champion cycle advances")
	equal(catalog.next_champion_id("s_wayne"), "red_baron", "champion cycle reaches the large foundation champion")
	equal(catalog.next_champion_id("wa_bidi"), "steezo", "existing wire five continues into the newly implemented roster")
	equal(catalog.next_champion_id("joh_haynes"), "h_le_ne", "existing final wire continues into H. Lenee without renumbering")
	equal(catalog.next_champion_id("h_le_ne"), "fimu_yashiha", "new characters retain append-only wire order")
	equal(catalog.next_champion_id("fimu_yashiha"), "sai_laas", "Sai Laas appends after stable Mifu wire 29")
	equal(catalog.next_champion_id("sai_laas"), "oh_tipi", "complete named champion cycle wraps")
	equal(catalog.champion_id_from_wire(30), "sai_laas", "Sai Laas owns the next free champion wire without renumbering")
	equal(catalog.champion("sai_laas").get("display_name"), "Sai Laas", "Sai Laas uses the exact requested display name")
	equal(catalog.champion("sai_laas").get("ancestry"), "nymph", "Sai Laas uses the requested Nymph race")
	equal(catalog.champion("sai_laas").get("body_type"), "small", "Sai Laas uses the conservative existing Nymph size baseline")
	equal(catalog.champion("sai_laas").get("affinity_points"), {"wind": 2.0, "fire": 1.0}, "Sai Laas follows the three-point Air/Fire specialist contract (JSON numeric values)")
	equal(catalog.champion("sai_laas").get("stats"), catalog.champion("haara").get("stats"), "Sai Laas copies the existing Small Nymph stats, including 620 Stamina")
	equal(catalog.champion("sai_laas")["foundation_kit"], {"primary": "gale-needle", "active_1": "pressure-shell", "active_2": "ember-sweep"}, "Sai Laas uses existing Air Bolt/Heavy and Fire Spray")
	check(catalog.champion("unnamed_angel").is_empty(), "removed placeholder never becomes an extra selectable character")
	equal(catalog.champion("h_le_ne").get("display_name"), "H. Lenee", "H. Lenee keeps the existing compatibility identity")
	equal(catalog.champion("fimu_yashiha").get("display_name"), "Mifu", "Mifu keeps the existing compatibility identity")
	equal(int(catalog.champion("h_le_ne").get("wire_id", 0)), 28, "H. Lenee rename preserves wire 28")
	equal(int(catalog.champion("fimu_yashiha").get("wire_id", 0)), 29, "Mifu rename preserves wire 29")
	equal(catalog.champion("h_le_ne").get("affinities"), ["earth", "wind", "fire"], "H. Lenee retains Earth, Air and Fire")
	equal(catalog.champion("fimu_yashiha").get("affinities"), ["water", "wind", "light"], "Mifu replaces Fire with Air using the stable wind content ID")
	equal(catalog.affinity_strength("fimu_yashiha", "wind"), 1, "Mifu has one Air affinity point")
	equal(catalog.affinity_strength("fimu_yashiha", "fire"), 0, "Mifu no longer has innate Fire affinity")
	equal(catalog.champion("fimu_yashiha")["foundation_kit"]["active_2"], "squall", "Mifu starter Spray follows the existing first-other-affinity kit rule")
	check(catalog.champion("h_lenee").is_empty() and catalog.champion("mifu").is_empty(), "display-name updates do not create duplicate technical identities")
	equal(String(catalog.champion("oh_tipi").get("ancestry")), "seakin", "Oh Tipi is a Seakin")
	equal(String(catalog.champion("s_wayne").get("ancestry")), "hobbit", "S. Wayne is a Hobbit")
	equal(String(catalog.champion("red_baron").get("ancestry")), "undead", "The Red Baron is Undead")
	equal(String(catalog.champion("oh_tipi").get("body_type")), "middle", "Oh Tipi uses the middle reusable body type")
	equal(String(catalog.champion("s_wayne").get("body_type")), "small", "S. Wayne uses the small reusable body type")
	equal(String(catalog.champion("red_baron").get("body_type")), "large", "The Red Baron uses the large reusable body type")
	equal(ChampionCatalog.SUPPORTED_BODY_TYPES, ["small", "middle", "large"], "runtime exposes exactly three body types")
	equal(catalog.champion("oh_tipi").get("affinities", []), ["water", "charge"], "Oh Tipi owns Water/Charge")
	equal(catalog.affinity_strength("oh_tipi", "water"), 2, "Oh Tipi has primary Water strength 2")
	equal(catalog.affinity_strength("oh_tipi", "charge"), 1, "Oh Tipi has secondary Charge strength 1")
	equal(catalog.affinity_strength("oh_tipi", "ice"), 0, "Oh Tipi has no innate Ice affinity")
	equal(catalog.champion("s_wayne").get("affinities", []), ["dark", "light"], "S. Wayne keeps Dark/Light")
	equal(catalog.affinity_strength("s_wayne", "dark"), 2, "S. Wayne has primary Dark strength 2")
	equal(catalog.affinity_strength("s_wayne", "light"), 1, "S. Wayne has secondary Light strength 1")
	equal(catalog.champion("red_baron").get("affinities", []), ["fire", "ice"], "The Red Baron owns Fire/Ice")
	equal(catalog.affinity_strength("red_baron", "fire"), 2, "The Red Baron has primary Fire strength 2")
	equal(catalog.affinity_strength("red_baron", "ice"), 1, "The Red Baron has secondary Ice strength 1")
	for champion_id: String in catalog.ordered_champion_ids():
		var kit_wires: Dictionary = catalog.kit_wires_by_champion[champion_id]
		var seen_wires: Dictionary = {}
		for slot_name: String in ["primary", "active_1", "active_2"]:
			var wire_id := int(kit_wires[slot_name])
			if slot_name == "active_2" and wire_id == 0:
				continue
			check(CombatTuning.is_runtime_wire_id(wire_id), "every authored kit wire is admitted by the four-family runtime: %s/%s" % [champion_id, slot_name])
			check(not seen_wires.has(wire_id), "every authored kit is distinct: %s/%s" % [champion_id, slot_name])
			var ability: Dictionary = abilities.ability_from_wire(wire_id)
			check(String(ability.get("element", "")) in (catalog.champion(champion_id).get("affinities", []) as Array), "every authored kit spell follows a champion affinity: %s/%s" % [champion_id, slot_name])
			seen_wires[wire_id] = true


func _test_affinity_point_budget_and_treevor_exception() -> void:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file(ABILITY_PATH), "ability catalog loads for affinity budget")
	var source := ChampionCatalog.new()
	check(source.load_from_file(CHAMPION_PATH, abilities), "champion source loads for affinity budget")

	var ordinary := ChampionCatalog.new()
	ordinary.data = source.data.duplicate(true)
	(ordinary.data["champions"][0] as Dictionary)["affinities"] = ["water", "charge", "ice"]
	(ordinary.data["champions"][0] as Dictionary)["affinity_points"] = {"water": 1, "charge": 1, "ice": 1}
	check(ordinary.validate(abilities), "any champion may split the same three-point budget across three affinities")

	var bad_total := ChampionCatalog.new()
	bad_total.data = source.data.duplicate(true)
	(bad_total.data["champions"][0] as Dictionary)["affinity_points"] = {"water": 1, "charge": 1}
	check(not bad_total.validate(abilities), "ordinary champion must spend exactly three affinity points")
	check(bad_total.last_error.contains("must total"), "bad affinity-point total is diagnosable")

	var treevor_candidate := ChampionCatalog.new()
	treevor_candidate.data = source.data.duplicate(true)
	(treevor_candidate.data["champions"] as Array).assign((treevor_candidate.data["champions"] as Array).filter(func(entry: Dictionary) -> bool: return entry["id"] != ChampionCatalog.TREEVOR_CHAMPION_ID))
	var treevor: Dictionary = (treevor_candidate.data["champions"][0] as Dictionary).duplicate(true)
	treevor["id"] = ChampionCatalog.TREEVOR_CHAMPION_ID
	treevor["wire_id"] = 99
	treevor["display_name"] = "Treevor the Mason"
	treevor["ancestry"] = "treefolk"
	treevor["body_type"] = "large"
	treevor["affinities"] = ["earth", "wind", "fire"]
	treevor["affinity_points"] = {"earth": 1, "wind": 1, "fire": 1}
	treevor["stats"] = (treevor_candidate.data["champions"][2] as Dictionary)["stats"].duplicate(true)
	(treevor_candidate.data["champions"] as Array).append(treevor)
	check(treevor_candidate.validate(abilities), "Treevor may split the same three-point budget 1+1+1: %s" % treevor_candidate.last_error)


func _test_shared_affinity_pairs() -> void:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file(ABILITY_PATH), "ability catalog loads for canonical shared pairs")
	var source := ChampionCatalog.new()
	check(source.load_from_file(CHAMPION_PATH, abilities), "champion source loads for canonical shared pairs")

	var candidate := ChampionCatalog.new()
	candidate.data = source.data.duplicate(true)
	var duplicate_pair: Dictionary = (candidate.data["champions"][0] as Dictionary).duplicate(true)
	duplicate_pair["id"] = "duplicate_pair_fixture"
	duplicate_pair["wire_id"] = 98
	duplicate_pair["display_name"] = "Duplicate Pair Fixture"
	duplicate_pair["affinities"] = ["charge", "water"]
	duplicate_pair["affinity_points"] = {"charge": 2, "water": 1}
	(candidate.data["champions"] as Array).append(duplicate_pair)
	check(candidate.validate(abilities), "shared two-affinity sets remain legal as declared by the canonical plan")
	equal(candidate.affinity_strength("duplicate_pair_fixture", "charge"), 2, "shared pair still preserves its exact independent point allocation")
	duplicate_pair["affinities"] = ["water", "water"]
	duplicate_pair["affinity_points"] = {"water": 3}
	check(not candidate.validate(abilities), "duplicate elements inside one profile still fail closed")


func _test_existing_single_lane_bolt_primaries() -> void:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file(ABILITY_PATH), "real shared spell catalog loads for starter-primary admission")
	var source := ChampionCatalog.new()
	check(source.load_from_file(CHAMPION_PATH, abilities), "live named roster validates before primary eligibility checks")
	var matrix: Dictionary = abilities.data["spell_matrix"]
	for element: String in AbilityCatalog.FIRST_EIGHT_ELEMENTS:
		var bolt_id := String((matrix["cells"][element] as Array)[0])
		var candidate := ChampionCatalog.new()
		candidate.data = source.data.duplicate(true)
		(candidate.data["champions"][0] as Dictionary)["foundation_kit"]["primary"] = bolt_id
		check(candidate.validate(abilities), "existing %s single-lane Bolt can initialize the starter primary: %s" % [element, candidate.last_error])
		if not candidate.last_error.is_empty(): continue
		var world := SimWorld.new(120)
		check(candidate.apply_to_player(world.player(), "oh_tipi"), "candidate Bolt kit applies in an isolated existing player state")
		var before := world.player().flux
		check(world.step([SimCommand.new(0, 1, 0, 0, SimCommand.HELD_PRIMARY, 0, 1000, 0)]), "real held-primary input accepts an elemental Bolt")
		equal(world.player().flux, before - int(CombatTuning.cast_definition(world.player().primary_wire_id)["flux_cost"]), "newly eligible starter Bolt still pays its ordinary spell cost")
		var released := false
		for _tick: int in range(20):
			check(world.step([]), "accepted existing Bolt completes its ordinary startup")
			if not world.projectiles.is_empty():
				released = true
				break
		check(released, "new starter-primary eligibility uses the real existing projectile kernel")
		if released: equal(world.projectiles.size(), 1, "starter Bolt emits a single lane")
	for forbidden: String in ["cinder-shell", "ember-stream", "cinder-fan", "cinderline", "ember-sweep", "hearthring", "vector-lance"]:
		var candidate := ChampionCatalog.new()
		candidate.data = source.data.duplicate(true)
		(candidate.data["champions"][0] as Dictionary)["foundation_kit"]["primary"] = forbidden
		check(not candidate.validate(abilities), "starter-primary exception cannot admit other delivery forms: " + forbidden)
		check(candidate.last_error.contains("kit slot is invalid"), "unsupported starter primary reports the exact kit boundary")


func _test_disabled_spell_admission_fails_closed() -> void:
	var state := PlayerState.new()
	var before_slots := PackedInt32Array(state.spell_wire_ids)
	var before_cooldowns := PackedInt32Array(state.spell_cooldown_ticks)
	var before_flux := state.flux
	for disabled_wire_id: int in [110, 146, 155, 156]:
		check(not state.place_proven_spell(0, disabled_wire_id), "catalog-only spell cannot enter a runtime weave: %d" % disabled_wire_id)
		equal(state.spell_wire_ids, before_slots, "rejected disabled wire preserves every weave position")
		equal(state.spell_cooldown_ticks, before_cooldowns, "rejected disabled wire preserves cooldown ownership")
		equal(state.flux, before_flux, "rejected disabled wire spends no resource")


func _test_profiles_are_authoritative() -> void:
	var catalog := _catalog()
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file(ABILITY_PATH), "canonical starter dependency loads")
	var state := PlayerState.new()
	check(catalog.apply_to_player(state, "oh_tipi"), "Oh Tipi profile applies")
	equal(state.champion_wire_id, 1, "Oh Tipi owns stable wire id 1")
	equal(state.primary_wire_id, CombatTuning.RILLSHOT_WIRE_ID, "Oh Tipi equips Rillshot")
	equal(state.active_1_wire_id, CombatTuning.TIDELINE_WIRE_ID, "Oh Tipi equips Tideline")
	equal(state.active_2_wire_id, 167, "Oh Tipi equips affinity-aligned Spark Shower as the third proven spell")
	equal(state.spell_wire_ids, CharacterStarterKit.build(catalog, abilities, "oh_tipi").wire_ids, "Oh Tipi initializes its canonical affinity-derived twelve")
	equal(state.health, 108_000, "Oh Tipi starts at authored maximum Health")
	equal(state.stamina_maximum, 660_000, "Oh Tipi has the Middle 660-point Stamina reserve")
	state.health = 54_000
	state.flux = 52_000
	state.stamina = 54_000
	state.flux_recovery_idle_ticks = 180
	state.stamina_recovery_idle_ticks = 120
	check(catalog.apply_to_player(state, "s_wayne", true), "S. Wayne profile applies with ratios preserved")
	equal(state.flux_recovery_idle_ticks, 0, "champion switch resets Flux quiet age for the new profile")
	equal(state.stamina_recovery_idle_ticks, 0, "champion switch resets Stamina quiet age for the new profile")
	equal(state.champion_wire_id, 2, "S. Wayne owns stable wire id 2")
	equal(state.primary_wire_id, CombatTuning.ECLIPSE_DISC_WIRE_ID, "S. Wayne equips Eclipse Disc")
	equal(state.active_1_wire_id, 174, "S. Wayne equips affinity-aligned Radiant Veil")
	equal(state.active_2_wire_id, 0, "S. Wayne does not expose an unfinished third spell")
	equal(state.spell_wire_ids, CharacterStarterKit.build(catalog, abilities, "s_wayne").wire_ids, "S. Wayne initializes its canonical affinity-derived twelve")
	equal(state.health, 45_000, "Health ratio survives an in-world champion switch")
	equal(state.flux, 56_000, "Flux ratio survives an in-world champion switch")
	equal(state.stamina, 50_727, "Stamina ratio survives the Middle-to-Small reserve change with integer truncation")
	equal(state.movement_speed_ratio, 1060, "S. Wayne owns the faster ground profile")
	check(catalog.apply_to_player(state, "red_baron"), "The Red Baron profile applies")
	equal(state.champion_wire_id, 3, "The Red Baron owns stable wire id 3")
	equal(state.primary_wire_id, CombatTuning.CINDERBOLT_WIRE_ID, "The Red Baron equips Cinderbolt")
	equal(state.active_1_wire_id, 171, "The Red Baron equips affinity-aligned Sleet")
	equal(state.active_2_wire_id, 154, "The Red Baron equips affinity-aligned Ember Sweep")
	equal(state.spell_wire_ids, CharacterStarterKit.build(catalog, abilities, "red_baron").wire_ids, "The Red Baron initializes its canonical affinity-derived twelve")
	equal(state.health_maximum, 132_000, "large body owns the deepest Health reserve")
	equal(state.stamina_maximum, 700_000, "large body owns the modestly deeper 700-point Stamina reserve")
	equal(state.movement_speed_ratio, 910, "large body pays for staying power with deliberate ground speed")


func _test_modest_size_stamina_reserve() -> void:
	var catalog := _catalog()
	var baselines := {
		"oh_tipi": [114_400, 660_000, 19_000, 30_000, 108_000, 980, 1800],
		"s_wayne": [123_200, 620_000, 23_000, 28_000, 90_000, 1060, 2200],
		"red_baron": [105_600, 700_000, 17_000, 32_000, 132_000, 910, 1200],
		"grace_reava": [132_000, 620_000, 21_000, 29_000, 92_000, 1030, 1800],
		"wa_bidi": [116_600, 620_000, 25_000, 32_000, 98_000, 1050, 1800],
	}
	var reserves := {"small": 620_000, "middle": 660_000, "large": 700_000}
	for champion_id: String in catalog.ordered_champion_ids():
		var profile := catalog.champion(champion_id)
		equal(int(profile["stats"]["stamina_maximum"]), int(reserves[profile["body_type"]]), champion_id + " uses the exact modest body-size reserve")
	equal(int(reserves["middle"]) - int(reserves["small"]), 40_000, "Small-to-Middle reserve difference is exactly forty Stamina points")
	equal(int(reserves["large"]) - int(reserves["middle"]), 40_000, "Middle-to-Large reserve difference is exactly forty Stamina points")
	var roster := ChampionRosterPlan.new()
	check(roster.load_from_files(), "modest reserve overview roster loads")
	var overview := CharacterOverviewModel.build(catalog, roster)
	check(bool(overview["valid"]), "modest body reserves remain representable in character overview")
	var config := SimConfig.new(120)
	var collision := CollisionWorld.new(2_000_000, 2_000_000)
	for champion_id: String in baselines:
		var before: Array = baselines[champion_id]
		var state := PlayerState.new()
		check(catalog.apply_to_player(state, champion_id), champion_id + " applies the modest Stamina candidate")
		equal(state.flux_maximum, int(before[0]), champion_id + " keeps the same Flux reserve")
		equal(state.stamina_maximum, int(before[1]), champion_id + " receives the exact authored size reserve")
		equal(state.flux_recovery_per_second, int(before[2]), champion_id + " keeps the same Flux recovery commitment")
		equal(state.stamina_recovery_per_second, int(before[3]), champion_id + " keeps the same Stamina recovery commitment")
		equal(state.health_maximum, int(before[4]), champion_id + " gains no Health advantage from reserve tuning")
		equal(state.movement_speed_ratio, int(before[5]), champion_id + " preserves body movement tempo")
		equal(state.health_recovery_per_second, int(before[6]), champion_id + " keeps the same Health recovery rate")
		var displayed: Dictionary = overview["entries_by_id"][champion_id]
		equal(int(displayed["stats"]["stamina_maximum"]), state.stamina_maximum, champion_id + " overview shows the actual size-based maximum")
		var stamina_line := String((displayed["stat_lines"] as Array)[2])
		check(stamina_line.contains("Stamina %s" % String.num(float(state.stamina_maximum) / 1000.0, 2)), champion_id + " readable resource line uses current Stamina points")
		check(stamina_line.contains("recovery %s/s" % String.num(float(state.stamina_recovery_per_second) / 1000.0, 2)), champion_id + " readable resource line keeps the real absolute recovery rate")
		var guide := MovementGuideModel.summary_lines(state)
		check(guide[0].contains("%s maximum" % String.num(float(state.stamina_maximum) / 1000.0, 1).trim_suffix(".0")), champion_id + " movement guide does not show the smaller default reserve")
		state.flux = state.flux_maximum - 1
		state.stamina = state.stamina_maximum - 1
		PlayerResourcesSystem.step(state, config)
		MovementSystem.step(state, SimCommand.new(0, state.entity_id), config, collision)
		equal(state.flux, state.flux_maximum, champion_id + " clamps Flux at the new authoritative maximum")
		equal(state.stamina, state.stamina_maximum, champion_id + " clamps Stamina at the new authoritative maximum")
		state.stamina = 0
		state.stamina_remainder = 0
		state.stamina_recovery_delay_ticks = 0
		state.stamina_recovery_idle_ticks = 0
		for tick: int in range(120):
			MovementSystem.step(state, SimCommand.new(tick, state.entity_id), config, collision)
		equal(state.stamina, _quiet_second_recovery(int(before[3])), champion_id + " one second follows the independent quiet ramp over its unchanged base rate")
	equal(ChampionCatalog.STAT_BOUNDS["stamina_maximum"], Vector2i(300_000, 800_000), "expanded Stamina resource envelope remains finite")
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file(ABILITY_PATH), "ability catalog loads for reserve bound rejection")
	var outside := ChampionCatalog.new()
	outside.data = catalog.data.duplicate(true)
	(outside.data["champions"][0]["stats"] as Dictionary)["stamina_maximum"] = 800_001
	check(not outside.validate(abilities), "resource values above the expanded cap fail closed")
	check(outside.last_error.contains("stamina_maximum"), "rejected oversized Stamina is diagnosable")


func _test_profiles_execute_at_rate(tick_rate: int) -> void:
	var catalog := _catalog()
	var roomy_collision := CollisionWorld.new(2_000_000, 2_000_000)
	var oh_world := SimWorld.new(tick_rate, 1, roomy_collision)
	var wayne_world := SimWorld.new(tick_rate, 1, roomy_collision)
	var baron_world := SimWorld.new(tick_rate, 1, roomy_collision)
	var oh_tipi: PlayerState = oh_world.player()
	var s_wayne: PlayerState = wayne_world.player()
	var red_baron: PlayerState = baron_world.player()
	check(catalog.apply_to_player(oh_tipi, "oh_tipi"), "%d Hz Oh Tipi profile applies" % tick_rate)
	check(catalog.apply_to_player(s_wayne, "s_wayne"), "%d Hz S. Wayne profile applies" % tick_rate)
	check(catalog.apply_to_player(red_baron, "red_baron"), "%d Hz Red Baron profile applies" % tick_rate)
	for state: PlayerState in [oh_tipi, s_wayne, red_baron]:
		state.position_x = 1_000_000
		state.position_y = 1_000_000
	for _index: int in range(tick_rate):
		check(oh_world.step([SimCommand.new(oh_world.tick, 1, 1000)]), "%d Hz Oh Tipi movement steps" % tick_rate)
		check(wayne_world.step([SimCommand.new(wayne_world.tick, 1, 1000)]), "%d Hz S. Wayne movement steps" % tick_rate)
		check(baron_world.step([SimCommand.new(baron_world.tick, 1, 1000)]), "%d Hz Red Baron movement steps" % tick_rate)
	check(s_wayne.velocity_x > oh_tipi.velocity_x, "%d Hz S. Wayne reaches the higher authored ground speed" % tick_rate)
	check(s_wayne.position_x > oh_tipi.position_x, "%d Hz S. Wayne gains measurable ground over Oh Tipi" % tick_rate)
	check(oh_tipi.velocity_x > red_baron.velocity_x, "%d Hz the large anchor preserves its deliberate speed tradeoff" % tick_rate)
	check(red_baron.health_maximum > oh_tipi.health_maximum and red_baron.stamina_maximum > oh_tipi.stamina_maximum, "%d Hz the large anchor receives real reserve compensation" % tick_rate)
	oh_tipi.flux = 0
	s_wayne.flux = 0
	red_baron.flux = 0
	for state: PlayerState in [oh_tipi, s_wayne, red_baron]:
		state.flux_recovery_remainder = 0
		state.flux_recovery_idle_ticks = 0
	for _index: int in range(tick_rate):
		PlayerResourcesSystem.step(oh_tipi, oh_world.config)
		PlayerResourcesSystem.step(s_wayne, wayne_world.config)
		PlayerResourcesSystem.step(red_baron, baron_world.config)
	equal(oh_tipi.flux, _quiet_second_recovery(oh_tipi.flux_recovery_per_second), "%d Hz Oh Tipi applies the quiet curve to its authored Flux rate" % tick_rate)
	equal(s_wayne.flux, _quiet_second_recovery(s_wayne.flux_recovery_per_second), "%d Hz S. Wayne applies the quiet curve to its authored Flux rate" % tick_rate)
	equal(red_baron.flux, _quiet_second_recovery(red_baron.flux_recovery_per_second), "%d Hz Red Baron applies the quiet curve to its authored Flux rate" % tick_rate)
	check(oh_world.state_hash() != wayne_world.state_hash(), "%d Hz champion identity changes canonical world state" % tick_rate)
	check(baron_world.state_hash() != oh_world.state_hash(), "%d Hz the large profile changes canonical world state" % tick_rate)


func _quiet_second_recovery(base_rate: int) -> int:
	var total := 0
	for tick: int in range(1, 121):
		total += Recovery.rate_per_second(base_rate, tick, 120)
	return total / 120


func _test_invalid_profiles_fail_closed() -> void:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file(ABILITY_PATH), "ability catalog loads for invalid champion tests")
	var source := ChampionCatalog.new()
	check(source.load_from_file(CHAMPION_PATH, abilities), "champion source loads")
	for mutation: Callable in [
		func(data: Dictionary) -> void: data["schema_version"] = 99,
		func(data: Dictionary) -> void: (data["champions"][0] as Dictionary)["body_type"] = "size_3_medium",
		func(data: Dictionary) -> void: (data["champions"][0] as Dictionary)["wire_id"] = 2,
		func(data: Dictionary) -> void: (data["champions"][0] as Dictionary)["affinities"] = ["water"],
		func(data: Dictionary) -> void: (data["champions"][0] as Dictionary)["affinities"] = ["water", "charge", "ice"],
		func(data: Dictionary) -> void: ((data["champions"][0] as Dictionary)["affinity_points"] as Dictionary)["water"] = 3,
		func(data: Dictionary) -> void: (data["champions"][0] as Dictionary)["affinities"] = ["water", "spirit"],
		func(data: Dictionary) -> void: ((data["champions"][0] as Dictionary)["stats"] as Dictionary)["movement_speed_ratio"] = 5000,
		func(data: Dictionary) -> void: ((data["champions"][0] as Dictionary)["foundation_kit"] as Dictionary)["primary"] = "missing",
	]:
		var candidate := ChampionCatalog.new()
		candidate.data = source.data.duplicate(true)
		mutation.call(candidate.data)
		check(not candidate.validate(abilities), "invalid champion mutation fails closed")
		check(not candidate.last_error.is_empty(), "invalid champion failure is actionable")
	var disabled_kit := ChampionCatalog.new()
	disabled_kit.data = source.data.duplicate(true)
	((disabled_kit.data["champions"][0] as Dictionary)["foundation_kit"] as Dictionary)["active_1"] = "vector-lance"
	check(not disabled_kit.validate(abilities), "known catalog-only spell cannot enter an authored champion kit")
	check(disabled_kit.last_error.contains("kit slot is invalid"), "disabled-kit rejection identifies the authored kit boundary")
