extends FluxTestSuite


const ABILITY_PATH := "res://content/abilities/foundation_abilities_v1.json"
const CHAMPION_PATH := "res://content/champions/foundation_champions_v1.json"
const ARCHIVED_BURST_IDS: Array[String] = [
	"rill-burst", "stone-burst", "cinder-fan", "gale-burst",
	"rime-burst", "arc-burst", "prism-burst", "eclipse-burst",
]
const ARCHIVED_BURST_WIRES: Array[int] = [148, 147, 146, 149, 150, 151, 152, 153]


func run() -> int:
	_test_archived_first_eight_contract()
	_test_retired_bursts_fail_live_weaving()
	_test_archived_projectile_data_remains_well_formed()
	_test_readable_runtime_projectile_travel_at_120_hz()
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
		"arc-primary": [768_000, 1500, 7000], "rillshot": [720_000, 1440, 8000],
		"cinderbolt": [672_000, 1565, 9000], "eclipse-disc": [624_000, 2000, 11000],
	}
	var previous_families := {"heavy": [400_000, 1800, 16000], "rapid": [760_000, 850, 5000]}
	var catalog := _catalog()
	var projectile_count := 0
	for wire_id: int in catalog.runtime_wire_ids:
		var definition := CombatTuning.projectile_definition(wire_id)
		if definition.is_empty():
			continue
		projectile_count += 1
		var ability := catalog.ability_from_wire(wire_id)
		var ability_id := String(ability.get("id", ""))
		var family := String(ability.get("family", definition.get("delivery_kernel", "")))
		var before: Array = previous_tuning.get(ability_id, previous_families.get(family, [576_000, 2000, 9000]))
		var speed := int(definition.get("speed", 0))
		var lifetime_ms := int(definition.get("lifetime_ms", 0))
		equal(speed * 5, int(before[0]) * 4, ability_id + " slows travel by exactly 20 percent")
		equal(int(definition.get("radius", 0)) * 5, int(before[2]) * 6, ability_id + " enlarges collision radius by exactly 20 percent")
		var baseline := _sample_projectile_travel(definition, int(before[0]), int(before[1]))
		var candidate := _sample_projectile_travel(definition, speed, lifetime_ms)
		check(bool(candidate["expired"]), ability_id + " expires on the authoritative projectile path")
		check(int(candidate["reaction_ticks"]) > int(baseline["reaction_ticks"]), ability_id + " gives more ticks to react across 300 world units")
		check(absi(int(candidate["travel"]) - int(baseline["travel"])) <= 5000, ability_id + " preserves terminal reach within five world units")
	equal(projectile_count, 24, "all eight Bolts, eight Heavies, and eight Rapids retain the readability pass")


func _sample_projectile_travel(definition: Dictionary, speed: int, lifetime_ms: int) -> Dictionary:
	var config := SimConfig.new(120)
	var collision := CollisionWorld.new(3_000_000, 1_200_000)
	var projectile := ProjectileState.new(9900, 1, 1, int(definition.get("wire_id", 0)), int(definition.get("element_wire_id", 0)), Vector2i(500_000, 600_000), Vector2i(speed, 0), int(definition.get("radius", 0)), int(definition.get("damage", 0)), config.milliseconds_to_ticks(lifetime_ms))
	var active: Array[ProjectileState] = [projectile]
	var no_players: Array[PlayerState] = []
	var events: Array[Dictionary] = []
	var flight_ticks := 0
	var reaction_ticks := 0
	while not active.is_empty() and flight_ticks < 360:
		active = CombatSystem.advance_projectiles(active, no_players, config, collision, events)
		flight_ticks += 1
		if reaction_ticks == 0 and projectile.position_x - 500_000 >= 300_000:
			reaction_ticks = flight_ticks
	return {"flight_ticks": flight_ticks, "reaction_ticks": reaction_ticks, "travel": projectile.position_x - 500_000, "expired": events.any(func(event: Dictionary) -> bool: return event.get("type") == "projectile_expired")}
