class_name DenseProfileWorkload
extends RefCounted

@warning_ignore_start("integer_division")


const SEED := 9_156_026
const TICK_RATE := 120
const MAP_WIDTH := 1_280_000
const MAP_HEIGHT := 960_000
const WARMUP_TICKS := 240
const SAMPLE_TICKS := 2_400
const REPETITIONS := 3
const RENDER_WARMUP_FRAMES := 120
const RENDER_SAMPLE_FRAMES := 600
const SIM_TICKS_PER_RENDER_FRAME := 2
const TICK_BUDGET_US := 8_333
const EMITTER_COUNT := 4
const LOADOUT: Array = HexCourtPractice.LOADOUT
const STARTS: Array[Vector2i] = [
	Vector2i(300_000, 480_000),
	Vector2i(980_000, 480_000),
	Vector2i(640_000, 220_000),
	Vector2i(640_000, 740_000),
]
const PATCHES: Array[Vector2i] = [
	Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 1),
]


static func create_world(use_hex: bool, abilities: AbilityCatalog, champions: ChampionCatalog) -> SimWorld:
	if abilities == null or champions == null:
		return null
	var world := SimWorld.new(TICK_RATE, SEED, CollisionWorld.new(MAP_WIDTH, MAP_HEIGHT), "dense-profile-empty", "1280x960;no-obstacles;four-water-fire-emitters-v1")
	world.players.clear()
	var wires := PackedInt32Array()
	for pair: Array in LOADOUT:
		var definition: Dictionary = abilities.ability(abilities.spell_id_at(String(pair[0]), String(pair[1])))
		var wire := int(definition.get("wire_id", 0))
		if wire <= 0 or not CombatTuning.is_runtime_wire_id(wire):
			return null
		wires.append(wire)
	for index: int in range(EMITTER_COUNT):
		var actor := PlayerState.new(index + 1)
		if not champions.apply_to_player(actor, "oh_tipi"):
			return null
		actor.reset_for_spawn(STARTS[index])
		actor.team_id = 1 if index % 2 == 0 else 2
		actor.spawn_protection_ticks = 0
		actor.spell_wire_ids.fill(0)
		actor.spell_cooldown_ticks.fill(0)
		for slot: int in range(wires.size()):
			if not actor.place_proven_spell(slot, wires[slot]):
				return null
		actor.primary_wire_id = wires[4]
		actor.active_1_wire_id = wires[0]
		actor.active_2_wire_id = 0
		world.players.append(actor)
	if use_hex:
		world.hex_court = HexCourt.new()
		world.hex_court.chemistry_enabled = true
	else:
		world.hex_court = null
	return world if world.is_valid() else null


# Four explicitly unnetworked fixture emitters. Every actor receives one legal
# command per tick even after death/resource exhaustion; paid starts and
# refusals expose the actual production result without shortening the sample.
static func commands(world: SimWorld, timeline_tick: int, active: bool) -> Array[SimCommand]:
	var result: Array[SimCommand] = []
	for actor: PlayerState in world.players:
		var local_phase := posmod(timeline_tick + (actor.entity_id - 1) * 30, 480)
		var pressed := 0
		var held := 0
		if active:
			match local_phase:
				0: pressed = SimCommand.SPELL_PRESSED_BITS[0]
				60: pressed = SimCommand.SPELL_PRESSED_BITS[1]
				120: pressed = SimCommand.SPELL_PRESSED_BITS[2]
				180: pressed = SimCommand.SPELL_PRESSED_BITS[3]
				360: pressed = SimCommand.SPELL_PRESSED_BITS[6]
				420: pressed = SimCommand.SPELL_PRESSED_BITS[7]
			if local_phase >= 240 and local_phase < 270:
				held = SimCommand.SPELL_HELD_BITS[4]
			elif local_phase >= 300 and local_phase < 330:
				held = SimCommand.SPELL_HELD_BITS[5]
		var movement := _movement(actor.entity_id, timeline_tick)
		var patch: Vector2i = PATCHES[posmod(timeline_tick / 120 + actor.entity_id - 1, PATCHES.size())]
		var target := HexCourt.ORIGIN + HexGrid.center(patch)
		# The full command payload is derived from the timeline and fixture ID,
		# never from a variant's evolving authority state. Absolute targets still
		# land on the same production hex patches while the fixed aim vector stays
		# byte-for-byte matched if chemistry changes an actor position.
		var authored_aim: Vector2i = target - STARTS[actor.entity_id - 1]
		result.append(SimCommand.new(
			world.tick, actor.entity_id, movement.x, movement.y, held, pressed,
			authored_aim.x, authored_aim.y,
			target.x, target.y))
	return result


static func _movement(entity_id: int, timeline_tick: int) -> Vector2i:
	var inward := posmod(timeline_tick / 60, 2) == 0
	var sign := 1 if inward else -1
	match entity_id:
		1: return Vector2i(1000 * sign, 0)
		2: return Vector2i(-1000 * sign, 0)
		3: return Vector2i(0, 1000 * sign)
		_: return Vector2i(0, -1000 * sign)


static func new_observation() -> Dictionary:
	return {
		"command_ticks": 0, "command_sha256": "", "spell_intent_ticks": 0, "pressed_intents": 0,
		"held_rapid_intents": 0, "admitted_casts": 0, "cast_started": 0, "cast_refused": 0,
		"started_by_family": {}, "started_by_element": {}, "started_by_wire": {},
		"refusals_by_reason": {}, "events_by_type": {},
	}


static func observe_commands(commands_value: Array[SimCommand], observation: Dictionary) -> void:
	observation.command_ticks += commands_value.size()
	for command: SimCommand in commands_value:
		var slot := command.first_pressed_spell_slot()
		var pressed := slot > 0
		if slot == 0:
			slot = command.first_held_spell_slot()
		if slot == 0:
			continue
		observation.spell_intent_ticks += 1
		observation.pressed_intents += int(pressed)
		observation.held_rapid_intents += int(not pressed)


static func hash_commands(context: HashingContext, commands_value: Array[SimCommand]) -> bool:
	for command: SimCommand in commands_value:
		if context.update(command.canonical_bytes()) != OK:
			return false
	return true


static func observe_events(events: Array[Dictionary], observation: Dictionary) -> void:
	for event: Dictionary in events:
		var kind := String(event.get("type", "unknown"))
		_increment(observation.events_by_type, kind)
		if kind == "cast_started":
			observation.admitted_casts += 1
			observation.cast_started += 1
			var wire := int(event.get("wire_id", 0))
			var definition: Dictionary = CombatTuning.cast_definition(wire)
			_increment(observation.started_by_wire, str(wire))
			_increment(observation.started_by_family, HexCourt.family(wire))
			_increment(observation.started_by_element, "water" if int(definition.get("element_wire_id", 0)) == HexCourt.WATER else "fire")
		elif kind == "cast_refused":
			observation.cast_refused += 1
			_increment(observation.refusals_by_reason, String(event.get("reason", "unknown")))


static func new_peaks() -> Dictionary:
	return {
		"projectiles": 0, "legacy_deposits": 0, "legacy_reactions": 0,
		"fields": 0, "combat_events": 0, "hex_casts": 0, "hex_products": 0,
		"hex_pending": 0, "hex_held_infusions": 0, "active_hex_cells": 0,
		"hex_water_entries": 0, "hex_fire_entries": 0, "hex_product_entries": 0,
	}


static func observe_peaks(world: SimWorld, peaks: Dictionary) -> void:
	peaks.projectiles = maxi(int(peaks.projectiles), world.projectiles.size())
	peaks.legacy_deposits = maxi(int(peaks.legacy_deposits), world.deposits.size())
	peaks.legacy_reactions = maxi(int(peaks.legacy_reactions), world.reactions.size())
	peaks.fields = maxi(int(peaks.fields), world.fields.size())
	peaks.combat_events = maxi(int(peaks.combat_events), world.combat_events.size())
	if world.hex_court == null:
		return
	var court = world.hex_court
	peaks.hex_casts = maxi(int(peaks.hex_casts), court.casts.size())
	peaks.hex_products = maxi(int(peaks.hex_products), court.products.size())
	peaks.hex_pending = maxi(int(peaks.hex_pending), court.pending.size())
	var held_infusions: Dictionary = _optional_property(court, &"held_infusions", {}) as Dictionary
	peaks.hex_held_infusions = maxi(int(peaks.hex_held_infusions), held_infusions.size())
	var active_cells := 0
	var water_entries := 0
	var fire_entries := 0
	var product_entries := 0
	for cell: Vector2i in court.cells:
		var record: Dictionary = court.cells[cell]
		var water := int((record.water as Dictionary).size())
		var fire := int((record.fire as Dictionary).size())
		var products := int((record.steam as Dictionary).size()) + int((record.conflagration as Dictionary).size()) + int((record.flood as Dictionary).size())
		water_entries += water
		fire_entries += fire
		product_entries += products
		active_cells += int(water + fire + products > 0)
	peaks.active_hex_cells = maxi(int(peaks.active_hex_cells), active_cells)
	peaks.hex_water_entries = maxi(int(peaks.hex_water_entries), water_entries)
	peaks.hex_fire_entries = maxi(int(peaks.hex_fire_entries), fire_entries)
	peaks.hex_product_entries = maxi(int(peaks.hex_product_entries), product_entries)


static func inventory(world: SimWorld) -> Dictionary:
	var result := {
		"projectiles": world.projectiles.size(), "fields": world.fields.size(),
		"legacy_deposits": world.deposits.size(), "legacy_reactions": world.reactions.size(),
		"hex_casts": 0, "hex_products": 0, "hex_pending": 0, "hex_held_infusions": 0,
	}
	if world.hex_court != null:
		result.hex_casts = world.hex_court.casts.size()
		result.hex_products = world.hex_court.products.size()
		result.hex_pending = world.hex_court.pending.size()
		var held: Dictionary = _optional_property(world.hex_court, &"held_infusions", {}) as Dictionary
		result.hex_held_infusions = held.size()
	return result


# Exact bytes hashed by the current/final HexCourt.state_hash implementation.
# This is a local diagnostic serialization only; HexCourt is absent from the
# network snapshot schema and these bytes must never be called a packet.
static func court_canonical_diagnostic_bytes(court) -> PackedByteArray:
	var values: Array = [court.origin, court.current_tick, court.chemistry_enabled, court.next_cast_id, court.next_product_id, court.cells, court.casts, court.products, court.pending]
	if _has_property(court, &"held_infusions"):
		values.append(court.get("held_infusions"))
	values.append_array([court.sources, court.exposure, court.flow_carry, court.metrics])
	var bytes := PackedByteArray()
	CanonicalBytes.append_string(bytes, JSON.stringify(HexCourt._stable(values)))
	return bytes


static func percentiles(values: PackedInt64Array) -> Dictionary:
	var ordered := values.duplicate()
	ordered.sort()
	if ordered.is_empty():
		return {"samples": 0, "p50": 0, "p95": 0, "p99": 0, "max": 0}
	return {
		"samples": ordered.size(),
		"p50": ordered[_percentile_index(ordered.size(), 50)],
		"p95": ordered[_percentile_index(ordered.size(), 95)],
		"p99": ordered[_percentile_index(ordered.size(), 99)],
		"max": ordered[-1],
	}


static func monitor_snapshot() -> Dictionary:
	return {
		"static_memory_bytes": OS.get_static_memory_usage(),
		"static_memory_peak_bytes": OS.get_static_memory_peak_usage(),
		"object_count": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resource_count": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphan_node_count": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"render_objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"render_primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"video_memory_bytes": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		"texture_memory_bytes": int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		"buffer_memory_bytes": int(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)),
	}


static func merge_monitor_peaks(peaks: Dictionary, sample: Dictionary) -> void:
	for key: String in sample:
		peaks[key] = maxi(int(peaks.get(key, 0)), int(sample[key]))


static func _increment(counts: Dictionary, key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1


static func _percentile_index(size: int, percentile: int) -> int:
	return clampi((size * percentile + 99) / 100 - 1, 0, size - 1)


static func _has_property(instance: Object, property_name: StringName) -> bool:
	for descriptor: Dictionary in instance.get_property_list():
		if StringName(descriptor.get("name", &"")) == property_name:
			return true
	return false


static func _optional_property(instance: Object, property_name: StringName, fallback: Variant) -> Variant:
	return instance.get(property_name) if _has_property(instance, property_name) else fallback
