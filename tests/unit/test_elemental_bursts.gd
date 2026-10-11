extends FluxTestSuite


const ABILITY_PATH := "res://content/abilities/foundation_abilities_v1.json"
const CHAMPION_PATH := "res://content/champions/foundation_champions_v1.json"
const ARCHIVED_BURST_IDS: Array[String] = [
	"rill-burst", "stone-burst", "cinder-fan", "gale-burst",
	"rime-burst", "arc-burst", "prism-burst", "eclipse-burst",
]
const ARCHIVED_BURST_WIRES: Array[int] = [148, 147, 146, 149, 150, 151, 152, 153]
const ORIGINAL_TRAVELLING_WIRES: Array[int] = [140, 181, 182, 145, 179, 180, 163, 185, 186, 159, 183, 184, 173, 191, 192, 142, 193, 194]


func run() -> int:
	_test_archived_first_eight_contract()
	_test_retired_bursts_fail_live_weaving()
	_test_archived_projectile_data_remains_well_formed()
	_test_readable_runtime_projectile_travel_at_120_hz()
	_test_inverse_launch_strength_and_family_tradeoffs()
	return finish("elemental-bursts")


func _catalog() -> AbilityCatalog:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(ABILITY_PATH), "ability catalog loads for archived Burst records: %s" % catalog.last_error)
	return catalog


func _test_archived_first_eight_contract() -> void:
	var catalog := _catalog()
	equal(ARCHIVED_BURST_IDS.size(), 8, "archived first-eight Burst identities remain complete")
	equal(CombatTuning.ELEMENTAL_BURST_WIRE_IDS.size(), 8, "stable Burst protocol adapters remain complete")
	for index: int in range(ARCHIVED_BURST_IDS.size()):
		var ability: Dictionary = catalog.ability(ARCHIVED_BURST_IDS[index])
		var wire_id := ARCHIVED_BURST_WIRES[index]
		equal(int(ability.get("wire_id", 0)), wire_id, "archived Burst keeps its stable wire")
		equal(AbilityCatalog._spell_family(ability), "burst", "archived Burst keeps its preserved authored family identity")
		equal(String(ability.get("runtime_status", "")), "catalog_only", "archived Burst is explicitly unavailable")
		var normalized_angles := PackedFloat32Array(ability.get("projectile_angles_degrees", []))
		equal(normalized_angles, PackedFloat32Array([-24.0, -12.0, 0.0, 12.0, 24.0]), "archived Burst keeps its exact five readable lanes")
		check(not catalog.runtime_wire_ids.has(wire_id), "archived Burst is absent from catalog runtime admission")
		check(not CombatTuning.is_runtime_wire_id(wire_id), "archived Burst is absent from compiled runtime admission")
		check(CombatTuning.cast_definition(wire_id).is_empty(), "archived Burst has no live cast definition")


func _test_retired_bursts_fail_live_weaving() -> void:
	var abilities := _catalog()
	var champions := ChampionCatalog.new()
	check(champions.load_from_file(CHAMPION_PATH, abilities), "champion catalog loads for retired Burst refusal checks")
	for champion_id: String in ["oh_tipi", "s_wayne", "red_baron"]:
		var state := PlayerState.new()
		check(champions.apply_to_player(state, champion_id), "%s applies before retired Burst refusal checks" % champion_id)
		for wire_id: int in ARCHIVED_BURST_WIRES:
			var before_slots := PackedInt32Array(state.spell_wire_ids)
			var before_cooldowns := PackedInt32Array(state.spell_cooldown_ticks)
			var before_flux := state.flux
			check(not state.place_proven_spell(11, wire_id), "%s cannot weave archived Burst wire %d" % [champion_id, wire_id])
			equal(state.spell_wire_ids, before_slots, "retired Burst refusal preserves all twelve positions")
			equal(state.spell_cooldown_ticks, before_cooldowns, "retired Burst refusal preserves cooldown ownership")
			equal(state.flux, before_flux, "retired Burst refusal spends no Flux")


func _test_archived_projectile_data_remains_well_formed() -> void:
	# This is an archived-data fixture only. It inspects retained catalog geometry
	# and constructs passive state directly; it never equips or casts a Burst.
	var catalog := _catalog()
	var baseline_signature: Array = []
	for index: int in range(ARCHIVED_BURST_IDS.size()):
		var ability: Dictionary = catalog.ability(ARCHIVED_BURST_IDS[index])
		var element_id := String(ability.get("element", ""))
		var element_wire_id := int((catalog.elements_by_id[element_id] as Dictionary).get("wire_id", 0))
		var signature := [
			int(ability.get("speed", 0)), int(ability.get("radius", 0)),
			int(ability.get("damage", 0)), int(ability.get("lifetime_ms", 0)),
			ability.get("projectile_angles_degrees", []),
		]
		if baseline_signature.is_empty():
			baseline_signature = signature
		else:
			equal(signature, baseline_signature, "archived Burst elements retain common geometry without becoming playable")
		var projectile := ProjectileState.new(
			9000 + index, 1, 1, ARCHIVED_BURST_WIRES[index], element_wire_id,
			Vector2i(500_000, 600_000), Vector2i(int(ability.get("speed", 0)), 0),
			int(ability.get("radius", 0)), int(ability.get("damage", 0)),
			SimConfig.new(120).milliseconds_to_ticks(int(ability.get("lifetime_ms", 0))))
		equal(projectile.source_wire_id, ARCHIVED_BURST_WIRES[index], "archived Burst wire survives passive state construction")
		equal(projectile.element_wire_id, element_wire_id, "archived Burst element survives passive state construction")
		check(projectile.radius > 0 and projectile.damage > 0 and projectile.lifetime_ticks > 0, "archived Burst data still forms a bounded passive projectile record")


func _test_readable_runtime_projectile_travel_at_120_hz() -> void:
	var previous_tuning := {
		"arc-primary": [460_800, 2500], "rillshot": [432_000, 2400],
		"cinderbolt": [403_200, 2610], "eclipse-disc": [374_400, 3334],
	}
	var previous_families := {"heavy": [240_000, 3000], "rapid": [456_000, 1418], "bolt": [345_600, 3334]}
	# Exact current values are independent of the implementation. The preceding
	# checkpoint above supplies an A/B reach and reaction-time positive control.
	var current_tuning := {
		"arc-primary": [360_000, 3200, 12_000, 8000], "rillshot": [360_000, 2880, 14_000, 9000],
		"cinderbolt": [360_000, 2924, 16_000, 10_000], "eclipse-disc": [360_000, 3468, 18_000, 11_000],
	}
	var current_families := {"heavy": [180_000, 4000, 30_000, 24_000], "rapid": [600_000, 1080, 4000, 3000], "bolt": [360_000, 3200, 16_000, 10_000]}
	var catalog := _catalog()
	var projectile_count := 0
	# This historical A/B oracle covers the original six singleton Bolt/Heavy/
	# Rapid rows only. Expanded delivery travel, warning/branch state and finite
	# retirement use actual paid Hex paths in elemental-spell-expansion and
	# spell-delivery-expansion; they have no preceding legacy travel baseline.
	for index: int in ORIGINAL_TRAVELLING_WIRES.size():
		var wire_id := ORIGINAL_TRAVELLING_WIRES[index]
		check(wire_id in catalog.runtime_wire_ids, "every original travelling wire remains admitted")
		var definition := CombatTuning.projectile_definition(wire_id)
		check(not definition.is_empty(), "the original travelling wire retains a projectile definition")
		if definition.is_empty():
			continue
		var ability := catalog.ability_from_wire(wire_id)
		var ability_id := String(ability.get("id", ""))
		var family := String(definition.family)
		equal(family, ["bolt", "heavy", "rapid"][index % 3], "independent original wire order preserves each of the three travelling families")
		equal(int(definition.element_mask), [4, 2, 8, 1, 16, 32][index / 3], "historical travel comparison retains the exact singleton payload")
		check(previous_families.has(family) and current_families.has(family), "historical comparison refuses an unrelated delivery instead of aborting the test")
		if not previous_families.has(family) or not current_families.has(family): continue
		projectile_count += 1
		var before: Array = previous_tuning.get(ability_id, previous_families[family])
		var expected: Array = current_tuning.get(ability_id, current_families[family])
		var speed := int(definition.get("speed", 0))
		var lifetime_ms := int(definition.get("lifetime_ms", 0))
		equal([speed, lifetime_ms, int(definition.radius), int(definition.damage)], expected, ability_id + " compiles its exact authored speed, lifetime, collision radius and damage")
		var baseline := _sample_projectile_travel(definition, int(before[0]), int(before[1]))
		var candidate := _sample_projectile_travel(definition, speed, lifetime_ms)
		check(bool(candidate["expired"]), ability_id + " expires on the authoritative projectile path")
		if family == "heavy":
			check(int(candidate.reaction_ticks) > int(baseline.reaction_ticks), "the stronger Heavy gives strictly more time to react across300 world units")
		elif family == "rapid":
			check(int(candidate.reaction_ticks) < int(baseline.reaction_ticks), "the lighter precision Rapid visibly reaches300 world units sooner")
		else:
			equal(int(candidate.reaction_ticks), 100, "every Bolt has the same middle-speed300px travel time at120Hz")
		check(absi(int(candidate["travel"]) - int(baseline["travel"])) <= 5000, ability_id + " preserves terminal reach within five world units")
	equal(projectile_count, 18, "all six Bolts, six Heavies, and six Rapids are independently checked")


func _test_inverse_launch_strength_and_family_tradeoffs() -> void:
	var catalog := _catalog()
	for element: String in AbilityCatalog.DISPLAY_ELEMENT_IDS:
		var bolt := CombatTuning.cast_definition(int(catalog.ability(catalog.spell_id_at(element, "bolt")).wire_id))
		var heavy := CombatTuning.cast_definition(int(catalog.ability(catalog.spell_id_at(element, "heavy")).wire_id))
		var rapid := CombatTuning.cast_definition(int(catalog.ability(catalog.spell_id_at(element, "rapid")).wire_id))
		var spray := CombatTuning.cast_definition(int(catalog.ability(catalog.spell_id_at(element, "spray")).wire_id))
		for definition: Dictionary in [rapid, bolt, heavy]:
			# This is authored launch tuning, not a per-tick 1/current-speed buff.
			# Reaction strength is conserved chemistry stock, separate from HP damage.
			equal(int(definition.speed) * (int(definition.reaction_strength) + 5), 3_600_000, "all18 effective travelling spells obey speed_px_s=3600/(strength+5)")
		check(int(rapid.speed) > int(bolt.speed) and int(bolt.speed) > int(heavy.speed), "lighter families are strictly faster for every element")
		check(int(rapid.radius) * 3 <= int(bolt.radius) and int(heavy.radius) >= int(bolt.radius) + 12_000, "all families have meaningful actual collider-size separation")
		check(int(rapid.damage) < int(bolt.damage) and int(bolt.damage) < int(heavy.damage), "speed advantage trades away direct hit damage")
		check(int(rapid.flux_cost) < int(bolt.flux_cost) and int(bolt.flux_cost) < int(heavy.flux_cost), "larger commitments pay strictly more Flux per cast")
		check(int(rapid.damage) * (int(bolt.startup_ms) + int(bolt.cooldown_ms)) < int(bolt.damage) * (int(rapid.startup_ms) + int(rapid.cooldown_ms)), "fast low-risk Rapid cannot also dominate Bolt sustained single-target damage")
		check(int(rapid.speed) * int(rapid.lifetime_ms) < int(bolt.speed) * int(bolt.lifetime_ms), "Rapid precision speed does not inherit Bolt reach")
		check(bool(rapid.repeat_while_held) and bool(bolt.repeat_while_held), "only precision travelling families retain held repeat")
		check(not bool(heavy.get("repeat_while_held", false)) and not bool(spray.get("repeat_while_held", false)), "area commitments still require deliberate fresh presses")
		check(not rapid.has("blast_radius") and not bolt.has("blast_radius"), "faster families cannot gain free radial secondary damage")
		equal(int(heavy.blast_radius), 120_000, "Heavy's useful terminal radius grows from84 to120px")
		equal(int(heavy.blast_damage), 18_000, "larger splash retains18 damage below the rewarded24damage direct hit")
		equal(int(spray.cone_cosine_squared_per_million), 500_000, "all six Sprays use a visible90degree close fan")
		equal(int(spray.range), 300_000 if element == "water" else 320_000, "Spray remains a close-area choice instead of a long-range ray")
		equal(int(spray.damage), 14_000 if element == "water" else 10_000, "water displacement and ordinary Spray retain explicit distinct paid impact")
		equal(int(spray.radius), 10_000, "Spray ray-cover probe is independently bounded")


func _sample_projectile_travel(definition: Dictionary, speed: int, lifetime_ms: int) -> Dictionary:
	var config := SimConfig.new(120)
	var collision := CollisionWorld.new(3_000_000, 1_200_000)
	var projectile := ProjectileState.new(9900, 1, 1, int(definition.get("wire_id", 0)), int(definition.get("element_wire_id", 0)), Vector2i(500_000, 600_000), Vector2i(speed, 0), int(definition.get("radius", 0)), int(definition.get("damage", 0)), config.milliseconds_to_ticks(lifetime_ms))
	var active: Array[ProjectileState] = [projectile]
	var no_players: Array[PlayerState] = []
	var events: Array[Dictionary] = []
	var flight_ticks := 0
	var reaction_ticks := 0
	while not active.is_empty() and flight_ticks < config.milliseconds_to_ticks(lifetime_ms) + 2:
		active = CombatSystem.advance_projectiles(active, no_players, config, collision, events)
		flight_ticks += 1
		if reaction_ticks == 0 and projectile.position_x - 500_000 >= 300_000:
			reaction_ticks = flight_ticks
	return {"flight_ticks": flight_ticks, "reaction_ticks": reaction_ticks, "travel": projectile.position_x - 500_000, "expired": events.any(func(event: Dictionary) -> bool: return event.get("type") == "projectile_expired")}
