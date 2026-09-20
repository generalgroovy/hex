class_name InterceptionPractice
extends RefCounted
@warning_ignore_start("integer_division")


# A stateless, caller-owned practice opponent. The caller creates the actors,
# applies these source-derived loadouts, owns teams/reset/session exclusivity,
# and passes the resulting ordinary commands through SimWorld.step.
const TICKS_PER_SECOND: int = 120
const DURATION_TICKS: int = 72 * TICKS_PER_SECOND

const READY_END: int = 4 * TICKS_PER_SECOND
const RAPID_SINGLE_END: int = 18 * TICKS_PER_SECOND
const MUD_BREAK_END: int = 24 * TICKS_PER_SECOND
const RAPID_PRESSURE_END: int = 40 * TICKS_PER_SECOND
const STRONGER_WARNING_END: int = 44 * TICKS_PER_SECOND
const BOLT_READ_END: int = 56 * TICKS_PER_SECOND
const RECENTER_END: int = 60 * TICKS_PER_SECOND
const FINAL_MIX_END: int = 68 * TICKS_PER_SECOND

const PLAYER_SPAWN_PX := Vector2i(2256, 1216)
const OPPONENT_SPAWN_PX := Vector2i(2832, 1216)
const ARENA_ID := "proving-court-v1"
const PLAYER_CHAMPION_ID := "s_wayne"
const OPPONENT_CHAMPION_ID := "oh_tipi"

const PHASE_READY := "ready"
const PHASE_RAPID_SINGLE := "rapid_single"
const PHASE_MUD_BREAK := "mud_break"
const PHASE_RAPID_PRESSURE := "rapid_pressure"
const PHASE_STRONGER_WARNING := "stronger_warning"
const PHASE_BOLT_READ := "bolt_read"
const PHASE_RECENTER := "recenter"
const PHASE_FINAL_MIX := "final_mix"
const PHASE_CLEAR := "clear"
const PHASE_COMPLETE := "complete"


static func spawn_contract(layout: SanctumCampusLayout) -> Dictionary:
	if layout == null or String(layout.arena_definition.get("id", "")) != ARENA_ID:
		return {}
	var spawns: Array = layout.arena_definition.get("spawns", [])
	if spawns.size() < 6:
		return {}
	var player_spawn := SanctumCampusLayout._parse_point(spawns[4])
	var opponent_spawn := SanctumCampusLayout._parse_point(spawns[5])
	if player_spawn != PLAYER_SPAWN_PX or opponent_spawn != OPPONENT_SPAWN_PX:
		return {} # A changed court must be reviewed instead of using stale anchors.
	var bounds := SanctumCampusLayout._parse_bounds(layout.arena_definition.get("bounds", []))
	if not bounds.has_point(player_spawn) or not bounds.has_point(opponent_spawn):
		return {}
	return {
		"arena_id": ARENA_ID,
		"bounds": bounds,
		"player_spawn_px": player_spawn,
		"opponent_spawn_px": opponent_spawn,
		"player_spawn_fixed": player_spawn * SimConfig.FIXED_SCALE,
		"opponent_spawn_fixed": opponent_spawn * SimConfig.FIXED_SCALE,
	}


static func player_profile(catalog: AbilityCatalog) -> Dictionary:
	var requested := [
		["water_spray", "water", "spray", 1],
		["earth_spray", "earth", "spray", 2],
		["fire_bolt", "fire", "bolt", 3],
		["fire_rapid", "fire", "rapid", 4],
	]
	return _profile(catalog, PLAYER_CHAMPION_ID, requested)


static func opponent_profile(catalog: AbilityCatalog) -> Dictionary:
	var requested := [
		["rapid", "water", "rapid", 1],
		["bolt", "water", "bolt", 2],
		["heavy", "water", "heavy", 3],
	]
	return _profile(catalog, OPPONENT_CHAMPION_ID, requested)


static func _profile(catalog: AbilityCatalog, champion_id: String, requested: Array) -> Dictionary:
	if catalog == null or catalog.content_hash.is_empty():
		return {}
	var wires := {}
	var spell_ids := {}
	var spell_names := {}
	var slots := {}
	for request: Array in requested:
		var role := String(request[0])
		var element := String(request[1])
		var family := String(request[2])
		var slot := int(request[3])
		var spell_id := catalog.spell_id_at(element, family)
		var definition := catalog.ability(spell_id)
		var resolved_family := AbilityCatalog._spell_family(definition)
		if (
			definition.is_empty()
			or String(definition.get("runtime_status", "")) != "playable"
			or String(definition.get("element", "")) != element
			or resolved_family != family
			or int(definition.get("flux_cost", 0)) <= 0
			or int(definition.get("wire_id", 0)) <= 0
		):
			return {}
		wires[role] = int(definition["wire_id"])
		spell_ids[role] = spell_id
		spell_names[role] = String(definition.get("display_name", spell_id))
		slots[role] = slot
	return {
		"champion_id": champion_id,
		"wires": wires,
		"spell_ids": spell_ids,
		"spell_names": spell_names,
		"slots": slots,
	}


static func status(world_tick: int, start_tick: int) -> Dictionary:
	if world_tick < 0 or start_tick < 0 or world_tick < start_tick:
		return {}
	var elapsed := world_tick - start_tick
	var phase := _phase(elapsed)
	var phase_end := _phase_end(elapsed)
	return {
		"phase": phase,
		"elapsed_ticks": mini(elapsed, DURATION_TICKS),
		"remaining_ticks": maxi(0, phase_end - elapsed),
		"total_remaining_ticks": maxi(0, DURATION_TICKS - elapsed),
		"progress_milli": clampi(elapsed * 1000 / DURATION_TICKS, 0, 1000),
		"telegraph": _telegraph(phase, elapsed),
		"pressure": phase in [PHASE_RAPID_SINGLE, PHASE_RAPID_PRESSURE, PHASE_BOLT_READ, PHASE_FINAL_MIX],
		"break": phase in [PHASE_MUD_BREAK, PHASE_STRONGER_WARNING, PHASE_RECENTER, PHASE_CLEAR],
		"complete": phase == PHASE_COMPLETE,
	}


static func retry_start_tick(world_tick: int) -> int:
	return maxi(0, world_tick)


static func command_for_tick(
	world_tick: int,
	start_tick: int,
	opponent: PlayerState,
	player: PlayerState,
	slots: Dictionary,
) -> SimCommand:
	var current := status(world_tick, start_tick)
	if current.is_empty() or opponent == null or player == null or opponent.entity_id <= 0 or player.entity_id <= 0 or opponent.entity_id == player.entity_id or player.position_x < 0 or player.position_y < 0 or not _valid_slots(slots):
		return null
	var phase := String(current["phase"])
	var elapsed := int(current["elapsed_ticks"])
	var held := 0
	var pressed := 0
	if _rapid_held(phase, elapsed):
		held |= SimCommand.SPELL_HELD_BITS[int(slots["rapid"]) - 1]
	if _bolt_pressed(phase, elapsed):
		pressed |= SimCommand.SPELL_PRESSED_BITS[int(slots["bolt"]) - 1]
	if _heavy_pressed(phase, elapsed):
		pressed |= SimCommand.SPELL_PRESSED_BITS[int(slots["heavy"]) - 1]
	var movement := _movement(phase, elapsed, Vector2i(opponent.position_x, opponent.position_y))
	var aim := Vector2i(player.position_x - opponent.position_x, player.position_y - opponent.position_y)
	return SimCommand.new(
		world_tick,
		opponent.entity_id,
		movement.x,
		movement.y,
		held,
		pressed,
		aim.x,
		aim.y,
		player.position_x,
		player.position_y,
	)


static func _valid_slots(slots: Dictionary) -> bool:
	var seen := {}
	for role: String in ["rapid", "bolt", "heavy"]:
		var slot := int(slots.get(role, 0))
		if slot < 1 or slot > SimCommand.SPELL_PRESSED_BITS.size() or seen.has(slot):
			return false
		seen[slot] = true
	return true


static func _phase(elapsed: int) -> String:
	if elapsed < READY_END:
		return PHASE_READY
	if elapsed < RAPID_SINGLE_END:
		return PHASE_RAPID_SINGLE
	if elapsed < MUD_BREAK_END:
		return PHASE_MUD_BREAK
	if elapsed < RAPID_PRESSURE_END:
		return PHASE_RAPID_PRESSURE
	if elapsed < STRONGER_WARNING_END:
		return PHASE_STRONGER_WARNING
	if elapsed < BOLT_READ_END:
		return PHASE_BOLT_READ
	if elapsed < RECENTER_END:
		return PHASE_RECENTER
	if elapsed < FINAL_MIX_END:
		return PHASE_FINAL_MIX
	if elapsed < DURATION_TICKS:
		return PHASE_CLEAR
	return PHASE_COMPLETE


static func _phase_end(elapsed: int) -> int:
	for boundary: int in [READY_END, RAPID_SINGLE_END, MUD_BREAK_END, RAPID_PRESSURE_END, STRONGER_WARNING_END, BOLT_READ_END, RECENTER_END, FINAL_MIX_END, DURATION_TICKS]:
		if elapsed < boundary:
			return boundary
	return DURATION_TICKS


static func _telegraph(phase: String, elapsed: int) -> String:
	if phase == PHASE_RAPID_SINGLE:
		return "rapid" if posmod(elapsed - READY_END, 360) < 120 else ""
	if phase == PHASE_RAPID_PRESSURE:
		return "rapid" if posmod(elapsed - MUD_BREAK_END, 180) < 48 else ""
	if phase == PHASE_STRONGER_WARNING:
		return "bolt"
	if phase == PHASE_BOLT_READ:
		return "bolt" if posmod(elapsed - STRONGER_WARNING_END, 360) < 120 else ""
	if phase == PHASE_FINAL_MIX:
		var local := elapsed - RECENTER_END
		if local < 120 or (local >= 600 and local < 660):
			return "rapid"
		if local >= 240 and local < 300:
			return "bolt"
		if local >= 360 and local < 540:
			return "heavy"
	return ""


static func _rapid_held(phase: String, elapsed: int) -> bool:
	if phase == PHASE_RAPID_SINGLE:
		var cycle := posmod(elapsed - READY_END, 360)
		return cycle >= 120 and cycle < 174
	if phase == PHASE_RAPID_PRESSURE:
		var cycle := posmod(elapsed - MUD_BREAK_END, 180)
		return cycle >= 48 and cycle < 114
	if phase == PHASE_FINAL_MIX:
		var local := elapsed - RECENTER_END
		return (local >= 120 and local < 210) or (local >= 660 and local < 750)
	return false


static func _bolt_pressed(phase: String, elapsed: int) -> bool:
	if phase == PHASE_BOLT_READ:
		return posmod(elapsed - STRONGER_WARNING_END, 360) == 120
	return phase == PHASE_FINAL_MIX and elapsed - RECENTER_END == 300


static func _heavy_pressed(phase: String, elapsed: int) -> bool:
	return phase == PHASE_FINAL_MIX and elapsed - RECENTER_END == 540


static func _movement(phase: String, elapsed: int, current_position: Vector2i) -> Vector2i:
	var anchor := OPPONENT_SPAWN_PX * SimConfig.FIXED_SCALE
	var target := anchor
	if phase in [PHASE_RAPID_SINGLE, PHASE_RAPID_PRESSURE, PHASE_BOLT_READ, PHASE_FINAL_MIX]:
		var side := 1 if posmod(elapsed / 240, 2) == 0 else -1
		target.y += side * 64 * SimConfig.FIXED_SCALE
	var delta := target - current_position
	return Vector2i(_axis(delta.x), _axis(delta.y))


static func _axis(delta: int) -> int:
	if absi(delta) <= 16 * SimConfig.FIXED_SCALE:
		return 0
	return 500 if delta > 0 else -500
