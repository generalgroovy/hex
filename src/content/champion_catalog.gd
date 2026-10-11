class_name ChampionCatalog
extends RefCounted


const SUPPORTED_SCHEMA_VERSION: int = 2
const TREEVOR_CHAMPION_ID: String = "treevor_mason"
const AFFINITY_POINT_BUDGET: int = 3
const SUPPORTED_ANCESTRIES: Array[String] = [
	"human", "dwarf", "gnome", "hobbit", "elf", "orc", "troll", "minotaur",
	"seakin", "wyrmborn", "stoneborn", "treefolk", "sylph", "undead", "goblin",
	"nymph", "spiderkin", "vampire", "demon", "angel", "werewolf",
]
const SUPPORTED_BODY_TYPES: Array[String] = ["small", "middle", "large"]
const STAT_BOUNDS: Dictionary = {
	"health_maximum": Vector2i(60_000, 160_000),
	"health_recovery_per_second": Vector2i(0, 8_000),
	"flux_maximum": Vector2i(60_000, 160_000),
	"flux_recovery_per_second": Vector2i(5_000, 50_000),
	"stamina_maximum": Vector2i(300_000, 800_000),
	"stamina_recovery_per_second": Vector2i(10_000, 50_000),
	"movement_speed_ratio": Vector2i(850, 1150),
}

var data: Dictionary = {}
var last_error: String = ""
var content_hash: String = ""
var default_champion_id: String = ""
var champions_by_id: Dictionary[String, Dictionary] = {}
var champion_ids_by_wire: Dictionary[int, String] = {}
var kit_wires_by_champion: Dictionary[String, Dictionary] = {}
var starter_wires_by_champion: Dictionary[String, PackedInt32Array] = {}
var body_type_profiles := BodyTypeProfileCatalog.new()


func load_from_file(path: String, abilities: AbilityCatalog) -> bool:
	last_error = ""
	data = {}
	body_type_profiles = BodyTypeProfileCatalog.new()
	if not body_type_profiles.load_from_file():
		return _fail(body_type_profiles.last_error)
	if not FileAccess.file_exists(path):
		return _fail("champion catalog does not exist: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("champion catalog cannot be opened: %s" % path)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return _fail("champion catalog root must be an object")
	data = parsed
	return validate(abilities)


func validate(abilities: AbilityCatalog) -> bool:
	last_error = ""
	content_hash = ""
	default_champion_id = ""
	champions_by_id = {}
	champion_ids_by_wire = {}
	kit_wires_by_champion = {}
	starter_wires_by_champion = {}
	if body_type_profiles.content_hash.is_empty() and not body_type_profiles.load_from_file():
		return _fail(body_type_profiles.last_error)
	if abilities == null or not abilities.last_error.is_empty() or abilities.content_hash.is_empty():
		return _fail("champion catalog requires a valid ability catalog")
	if int(data.get("schema_version", 0)) != SUPPORTED_SCHEMA_VERSION:
		return _fail("unsupported champion catalog schema")
	if String(data.get("id", "")).is_empty():
		return _fail("champion catalog id is required")
	for value: Variant in data.get("champions", []):
		if not value is Dictionary:
			return _fail("every champion must be an object")
		var champion: Dictionary = value
		var champion_id := String(champion.get("id", ""))
		var wire_id := int(champion.get("wire_id", 0))
		if champion_id.is_empty() or champions_by_id.has(champion_id):
			return _fail("champion ids must be non-empty and unique: %s" % champion_id)
		if wire_id <= 0 or champion_ids_by_wire.has(wire_id):
			return _fail("champion wire ids must be positive and unique: %d" % wire_id)
		if String(champion.get("display_name", "")).is_empty():
			return _fail("champion display name is required: %s" % champion_id)
		if not SUPPORTED_ANCESTRIES.has(String(champion.get("ancestry", ""))):
			return _fail("champion ancestry is unsupported: %s" % champion_id)
		if not SUPPORTED_BODY_TYPES.has(String(champion.get("body_type", ""))):
			return _fail("champion body type is unsupported: %s" % champion_id)
		if String(champion.get("playstyle", "")).is_empty():
			return _fail("champion needs a concise playstyle: %s" % champion_id)

		var affinities: Array = champion.get("affinities", [])
		if affinities.size() < 2 or affinities.size() > 3:
			return _fail("champion requires two or three affinities within the same three-point budget: %s" % champion_id)
		var affinity_set: Dictionary = {}
		for affinity_value: Variant in affinities:
			var affinity := String(affinity_value)
			if affinity_set.has(affinity) or not abilities.elements_by_id.has(affinity):
				return _fail("champion affinities must be known and unique: %s" % champion_id)
			if not bool((abilities.elements_by_id[affinity] as Dictionary).get("runtime_enabled", false)):
				return _fail("champion affinity is not runtime-enabled: %s" % affinity)
			affinity_set[affinity] = true

		var affinity_points: Dictionary = champion.get("affinity_points", {})
		if affinity_points.size() != affinities.size():
			return _fail("affinity_points must match champion affinities: %s" % champion_id)
		var affinity_point_total := 0
		for affinity: String in affinity_set:
			if not affinity_points.has(affinity):
				return _fail("affinity_points must include every champion affinity: %s/%s" % [champion_id, affinity])
			var strength := int(affinity_points[affinity])
			if strength < 1 or strength > 2:
				return _fail("affinity strength must be 1 or 2: %s/%s" % [champion_id, affinity])
			affinity_point_total += strength
		for point_key: Variant in affinity_points.keys():
			if not affinity_set.has(String(point_key)):
				return _fail("affinity_points cannot contain undeclared affinity: %s/%s" % [champion_id, String(point_key)])
		if affinity_point_total != AFFINITY_POINT_BUDGET:
			return _fail("champion affinity points must total %d: %s" % [AFFINITY_POINT_BUDGET, champion_id])

		# The canonical affinity plan permits shared pairs. Identity, body role,
		# kit and visual recipe distinguish champions; never rewrite documented
		# affinities merely to force a globally unique two-element combination.

		var stats: Dictionary = champion.get("stats", {})
		for stat_name: String in STAT_BOUNDS:
			if not stats.has(stat_name):
				return _fail("champion stat is missing: %s/%s" % [champion_id, stat_name])
			var bounds: Vector2i = STAT_BOUNDS[stat_name]
			var stat_value := int(stats[stat_name])
			if stat_value < bounds.x or stat_value > bounds.y:
				return _fail("champion stat is outside safe bounds: %s/%s" % [champion_id, stat_name])
		if not body_type_profiles.accepts(String(champion.get("body_type", "")), stats):
			return _fail("champion stats contradict the reusable body-type role: %s" % champion_id)
		var kit: Dictionary = champion.get("foundation_kit", {})
		var kit_wires: Dictionary = {}
		for slot_name: String in ["primary", "active_1"]:
			var ability_id := String(kit.get(slot_name, ""))
			var ability: Dictionary = abilities.ability(ability_id)
			var expected_kind := "primary" if slot_name == "primary" else "active"
			var accepted_kind := String(ability.get("slot_kind", "")) == expected_kind
			if slot_name == "primary" and not accepted_kind:
				# Matrix Bolts are legacy-labelled active spells, but all eight
				# ordinary single-lane Bolts can initialize the primary channel.
				# This does not broaden starter primaries to Heavy/Rapid/Wave or
				# instant/area forms, nor change freely woven spell-slot access.
				var angles: Variant = ability.get("projectile_angles_degrees", [0])
				accepted_kind = String(ability.get("family", "")) == "bolt" \
					and String(ability.get("shape", "")) == "projectile" \
					and String(ability.get("runtime_status", "")) == "playable" \
					and abilities.runtime_wire_ids.has(int(ability.get("wire_id", 0))) \
					and angles is Array and (angles as Array).size() == 1 and angles[0] == 0
			var ability_wire_id := int(ability.get("wire_id", 0))
			if ability.is_empty() or not accepted_kind \
					or String(ability.get("runtime_status", "")) != "playable" \
					or not abilities.runtime_wire_ids.has(ability_wire_id):
				return _fail("champion kit slot is invalid: %s/%s" % [champion_id, slot_name])
			kit_wires[slot_name] = ability_wire_id
		if kit_wires["primary"] == kit_wires["active_1"]:
			return _fail("champion kit spells must be unique: %s" % champion_id)
		kit_wires["active_2"] = 0
		var active_2_id := String(kit.get("active_2", ""))
		if not active_2_id.is_empty():
			var active_2: Dictionary = abilities.ability(active_2_id)
			var active_2_wire_id := int(active_2.get("wire_id", 0))
			if active_2.is_empty() or String(active_2.get("slot_kind", "")) != "active" \
					or String(active_2.get("runtime_status", "")) != "playable" \
					or not abilities.runtime_wire_ids.has(active_2_wire_id):
				return _fail("champion kit slot is invalid: %s/active_2" % champion_id)
			kit_wires["active_2"] = active_2_wire_id
			if kit_wires["active_2"] in [kit_wires["primary"], kit_wires["active_1"]]:
				return _fail("champion kit spells must be unique: %s" % champion_id)
		champions_by_id[champion_id] = champion
		champion_ids_by_wire[wire_id] = champion_id
		kit_wires_by_champion[champion_id] = kit_wires
	default_champion_id = String(data.get("default_champion_id", ""))
	if not champions_by_id.has(default_champion_id):
		return _fail("default champion must resolve")
	if champions_by_id.size() < 2:
		return _fail("foundation slice requires at least two champions")
	content_hash = CanonicalContent.sha256({"abilities": abilities.content_hash, "body_types": body_type_profiles.content_hash, "champions": data})
	if content_hash.length() != 64: return _fail("champion catalog hash failed")
	for champion_id: String in ordered_champion_ids():
		var starter := CharacterStarterKit.build(self, abilities, champion_id)
		if not bool(starter.get("valid", false)): return _fail(String(starter.get("error", "starter generation failed")))
		starter_wires_by_champion[champion_id] = (starter.wire_ids as PackedInt32Array).duplicate()
	return true


func champion(champion_id: String) -> Dictionary:
	return champions_by_id.get(champion_id, {})


func affinity_strength(champion_id: String, element_id: String) -> int:
	var champion_data: Dictionary = champion(champion_id)
	if champion_data.is_empty():
		return 0
	var affinity_points: Dictionary = champion_data.get("affinity_points", {})
	return int(affinity_points.get(element_id, 0))


func champion_id_from_wire(wire_id: int) -> String:
	return champion_ids_by_wire.get(wire_id, "")


func ordered_champion_ids() -> Array[String]:
	var wire_ids: Array[int] = champion_ids_by_wire.keys()
	wire_ids.sort()
	var result: Array[String] = []
	for wire_id: int in wire_ids:
		result.append(champion_ids_by_wire[wire_id])
	return result


func next_champion_id(champion_id: String) -> String:
	var ordered := ordered_champion_ids()
	var current_index: int = ordered.find(champion_id)
	return ordered[(current_index + 1) % ordered.size()] if current_index >= 0 else default_champion_id


func apply_to_player(state: PlayerState, champion_id: String, preserve_resource_ratios: bool = false) -> bool:
	if state == null or not champions_by_id.has(champion_id):
		return false
	var champion_data: Dictionary = champions_by_id[champion_id]
	var stats: Dictionary = champion_data["stats"]
	var old_health_maximum := maxi(1, state.health_maximum)
	var old_flux_maximum := maxi(1, state.flux_maximum)
	var old_stamina_maximum := maxi(1, state.stamina_maximum)
	var old_health := state.health
	var old_flux := state.flux
	var old_stamina := state.stamina
	state.champion_wire_id = int(champion_data["wire_id"])
	state.flight_capable = String(champion_data["ancestry"]) in ["sylph", "wyrmborn", "angel", "demon"]
	# Changing identity never replenishes spent air actions or releases a queued jump.
	MovementSystem.cancel_jump_intent(state)
	state.radius = body_type_profiles.hurt_radius(String(champion_data["body_type"]))
	state.float_max_duration_ms = MovementTuning.float_duration_ms(String(champion_data["body_type"]))
	# Attunement cannot refill or lengthen an already spent airborne allowance.
	state.float_ticks = mini(state.float_ticks, (state.float_max_duration_ms * 120 + 999) / 1000)
	state.health_maximum = int(stats["health_maximum"])
	state.health_recovery_per_second = int(stats["health_recovery_per_second"])
	state.flux_maximum = int(stats["flux_maximum"])
	state.flux_recovery_per_second = int(stats["flux_recovery_per_second"])
	state.stamina_maximum = int(stats["stamina_maximum"])
	state.stamina_recovery_per_second = int(stats["stamina_recovery_per_second"])
	state.movement_speed_ratio = int(stats["movement_speed_ratio"])
	var kit_wires: Dictionary = kit_wires_by_champion[champion_id]
	state.primary_wire_id = int(kit_wires["primary"])
	state.active_1_wire_id = int(kit_wires["active_1"])
	state.active_2_wire_id = int(kit_wires["active_2"])
	state.spell_wire_ids = starter_wires_by_champion[champion_id].duplicate()
	state.spell_cooldown_ticks = PackedInt32Array()
	state.spell_cooldown_ticks.resize(PlayerState.SPELL_SLOT_COUNT)
	state.spell_cooldown_ticks.fill(0)
	state.pending_cast_wire_id = 0
	state.pending_cast_ticks = 0
	state.pending_cast_target_x = -1
	state.pending_cast_target_y = -1
	state.cast_recovery_ticks = 0
	state.primary_cooldown_ticks = 0
	state.active_1_cooldown_ticks = 0
	state.active_2_cooldown_ticks = 0
	if preserve_resource_ratios:
		state.health = clampi(old_health * state.health_maximum / old_health_maximum, 0, state.health_maximum)
		state.flux = clampi(old_flux * state.flux_maximum / old_flux_maximum, 0, state.flux_maximum)
		state.stamina = clampi(old_stamina * state.stamina_maximum / old_stamina_maximum, 0, state.stamina_maximum)
	else:
		state.health = state.health_maximum
		state.flux = state.flux_maximum
		state.stamina = state.stamina_maximum
	state.health_recovery_remainder = 0
	state.flux_recovery_remainder = 0
	state.stamina_remainder = 0
	state.health_recovery_delay_ticks = 0
	state.flux_recovery_delay_ticks = 0
	state.stamina_recovery_delay_ticks = 0
	state.flux_recovery_idle_ticks = 0
	state.stamina_recovery_idle_ticks = 0
	state.last_event = "champion_%s" % champion_id
	return true


func _fail(message: String) -> bool:
	last_error = message
	return false
