class_name SessionRound
extends RefCounted


enum Phase {
	HEARTH,
	ACTIVE,
	RESULT,
}

const SCHEMA_VERSION: int = 1
const MIN_PLAYERS: int = 2
const MAX_PLAYERS: int = 8
const MIN_SCORE_LIMIT: int = 1
const MAX_SCORE_LIMIT: int = 15
const MIN_ROUND_SECONDS: int = 15
const MAX_ROUND_SECONDS: int = 600
const MIN_RESULT_SECONDS: int = 2
const MAX_RESULT_SECONDS: int = 30
const MIN_RESPAWN_MS: int = 500
const MAX_RESPAWN_MS: int = 10_000
const MIN_PROTECTION_MS: int = 250
const MAX_PROTECTION_MS: int = 5_000
const HEADER_VALUES: int = 7
const ENTRY_VALUES: int = 3
const ENTITY_MASK: int = 0x0f
const SCORE_SHIFT: int = 4
const SCORE_MASK: int = 0x0f

var phase: int = Phase.HEARTH
var serial: int = 0
var score_limit: int = 3
var round_end_tick: int = -1
var result_end_tick: int = -1
var winner_entity_id: int = 0
var scores_by_entity: Dictionary[int, int] = {}
var respawn_tick_by_entity: Dictionary[int, int] = {}
var spawn_by_entity: Dictionary[int, Vector2i] = {}
var arena_bounds := Rect2i()
var respawn_ticks: int = 0
var protection_ticks: int = 0
var configured_result_ticks: int = 1


func bind_hearth() -> void:
	phase = Phase.HEARTH
	round_end_tick = -1
	result_end_tick = -1
	winner_entity_id = 0
	scores_by_entity = {}
	respawn_tick_by_entity = {}
	spawn_by_entity = {}
	arena_bounds = Rect2i()
	respawn_ticks = 0
	protection_ticks = 0


func begin(world: SimWorld, participant_ids: Array[int], definition: Dictionary) -> bool:
	if world == null or not world.is_valid() or phase != Phase.HEARTH:
		return false
	var parsed := _parse_definition(definition, world)
	if parsed.is_empty():
		return false
	var ordered: Array[int] = []
	for entity_id: int in participant_ids:
		var state: PlayerState = world.player(entity_id)
		if (
			entity_id < 1
			or entity_id > MAX_PLAYERS
			or ordered.has(entity_id)
			or state == null
			or state.actor_kind != PlayerState.ActorKind.CHAMPION
		):
			return false
		ordered.append(entity_id)
	ordered.sort()
	if ordered.size() < MIN_PLAYERS or ordered.size() > MAX_PLAYERS:
		return false
	var spawn_points: Array = parsed["spawn_points"]
	if spawn_points.size() < ordered.size():
		return false

	serial += 1
	phase = Phase.ACTIVE
	score_limit = int(parsed["score_limit"])
	round_end_tick = world.tick + world.config.milliseconds_to_ticks(int(parsed["round_seconds"]) * 1000)
	result_end_tick = -1
	winner_entity_id = 0
	scores_by_entity = {}
	respawn_tick_by_entity = {}
	spawn_by_entity = {}
	arena_bounds = parsed["bounds"]
	respawn_ticks = world.config.milliseconds_to_ticks(int(parsed["respawn_ms"]))
	protection_ticks = world.config.milliseconds_to_ticks(int(parsed["protection_ms"]))
	world.projectiles = []
	world.fields = []
	world.deposits.clear()
	world.reactions.clear()
	for index: int in range(ordered.size()):
		var entity_id := ordered[index]
		var spawn_position: Vector2i = spawn_points[index]
		scores_by_entity[entity_id] = 0
		spawn_by_entity[entity_id] = spawn_position
		var participant: PlayerState = world.player(entity_id)
		participant.team_id = entity_id
		participant.reset_for_spawn(spawn_position, protection_ticks)
	return true


func advance(world: SimWorld, events: Array[Dictionary]) -> Array[Dictionary]:
	var emitted: Array[Dictionary] = []
	if world == null:
		return emitted
	if phase == Phase.RESULT:
		_freeze_participants(world)
		return emitted
	if phase != Phase.ACTIVE:
		return emitted
	for event: Dictionary in events:
		if String(event.get("type", "")) != "champion_defeated":
			continue
		var target_id := int(event.get("target_id", 0))
		var owner_id := int(event.get("owner_id", 0))
		if not scores_by_entity.has(target_id) or respawn_tick_by_entity.has(target_id):
			continue
		respawn_tick_by_entity[target_id] = world.tick + respawn_ticks
		var target: PlayerState = world.player(target_id)
		if target != null:
			target.last_event = "defeated"
		if scores_by_entity.has(owner_id) and owner_id != target_id:
			scores_by_entity[owner_id] = mini(score_limit, int(scores_by_entity[owner_id]) + 1)
		emitted.append({
			"type": "round_knockout",
			"owner_id": owner_id,
			"target_id": target_id,
			"score": int(scores_by_entity.get(owner_id, 0)),
		})
		if int(scores_by_entity.get(owner_id, 0)) >= score_limit:
			_finish(world, owner_id)
			emitted.append({"type": "round_finished", "winner_id": winner_entity_id})
			return emitted

	_enforce_bounds(world)
	var respawning: Array[int] = []
	for entity_id: int in respawn_tick_by_entity:
		if world.tick >= int(respawn_tick_by_entity[entity_id]):
			respawning.append(entity_id)
	respawning.sort()
	for entity_id: int in respawning:
		var state: PlayerState = world.player(entity_id)
		if state != null and spawn_by_entity.has(entity_id):
			state.reset_for_spawn(spawn_by_entity[entity_id], protection_ticks)
			emitted.append({"type": "round_respawned", "entity_id": entity_id})
		respawn_tick_by_entity.erase(entity_id)

	if world.tick >= round_end_tick:
		_finish(world, _leading_entity())
		emitted.append({"type": "round_finished", "winner_id": winner_entity_id})
	return emitted


func remove_participant(entity_id: int, world: SimWorld) -> Array[Dictionary]:
	if world == null:
		return []
	if not scores_by_entity.has(entity_id):
		return []
	scores_by_entity.erase(entity_id)
	respawn_tick_by_entity.erase(entity_id)
	spawn_by_entity.erase(entity_id)
	if phase == Phase.ACTIVE and scores_by_entity.size() < MIN_PLAYERS:
		var survivor := int(scores_by_entity.keys()[0]) if scores_by_entity.size() == 1 else 0
		_finish(world, survivor)
		return [{"type": "round_finished", "winner_id": winner_entity_id}]
	return []


func return_due(world_tick: int) -> bool:
	return phase == Phase.RESULT and result_end_tick >= 0 and world_tick >= result_end_tick


func active() -> bool:
	return phase == Phase.ACTIVE


func capture(world: SimWorld) -> PackedInt32Array:
	if world == null:
		return PackedInt32Array()
	var world_tick := world.tick
	var entity_ids: Array[int] = scores_by_entity.keys()
	entity_ids.sort()
	var remaining := 0
	if phase == Phase.ACTIVE:
		remaining = maxi(0, round_end_tick - world_tick)
	elif phase == Phase.RESULT:
		remaining = maxi(0, result_end_tick - world_tick)
	var result := PackedInt32Array([
		SCHEMA_VERSION,
		phase,
		serial,
		remaining,
		winner_entity_id,
		score_limit,
		entity_ids.size(),
	])
	for entity_id: int in entity_ids:
		result.append(entity_id | (int(scores_by_entity[entity_id]) << SCORE_SHIFT))
		result.append(maxi(0, int(respawn_tick_by_entity.get(entity_id, -1)) - world_tick))
		var state: PlayerState = world.player(entity_id)
		result.append(state.spawn_protection_ticks if state != null else 0)
	return result if validate_packet(result) else PackedInt32Array()


static func validate_packet(values: PackedInt32Array) -> bool:
	if values.size() < HEADER_VALUES or values[0] != SCHEMA_VERSION:
		return false
	var packet_phase := values[1]
	var count := values[6]
	if packet_phase < Phase.HEARTH or packet_phase > Phase.RESULT or values[2] < 0:
		return false
	if values[3] < 0 or values[3] > 100_000 or values[4] < 0 or values[4] > MAX_PLAYERS:
		return false
	if values[5] < MIN_SCORE_LIMIT or values[5] > MAX_SCORE_LIMIT:
		return false
	if count < 0 or count > MAX_PLAYERS or values.size() != HEADER_VALUES + count * ENTRY_VALUES:
		return false
	if packet_phase == Phase.HEARTH and (count != 0 or values[4] != 0):
		return false
	if packet_phase == Phase.ACTIVE and count < MIN_PLAYERS:
		return false
	if packet_phase == Phase.RESULT and count < 1:
		return false
	if packet_phase != Phase.RESULT and values[4] != 0:
		return false
	var previous_entity_id := 0
	for index: int in range(count):
		var offset := HEADER_VALUES + index * ENTRY_VALUES
		var entity_id := values[offset] & ENTITY_MASK
		var score := (values[offset] >> SCORE_SHIFT) & SCORE_MASK
		if (
			values[offset] < 0
			or values[offset] > (ENTITY_MASK | (SCORE_MASK << SCORE_SHIFT))
			or entity_id <= previous_entity_id
			or entity_id > MAX_PLAYERS
			or score > values[5]
		):
			return false
		if values[offset + 1] < 0 or values[offset + 1] > 2_000 or values[offset + 2] < 0 or values[offset + 2] > 1_000:
			return false
		previous_entity_id = entity_id
	return true


static func decoded(values: PackedInt32Array) -> Dictionary:
	if not validate_packet(values):
		return {}
	var entries: Array[Dictionary] = []
	for index: int in range(values[6]):
		var offset := HEADER_VALUES + index * ENTRY_VALUES
		entries.append({
			"entity_id": values[offset] & ENTITY_MASK,
			"score": (values[offset] >> SCORE_SHIFT) & SCORE_MASK,
			"respawn_ticks": values[offset + 1],
			"protection_ticks": values[offset + 2],
		})
	return {
		"phase": values[1],
		"serial": values[2],
		"remaining_ticks": values[3],
		"winner_entity_id": values[4],
		"score_limit": values[5],
		"entries": entries,
	}


func _finish(world: SimWorld, winner_id: int) -> void:
	_finish_tick(world.tick, winner_id)
	world.projectiles = []
	world.fields = []
	world.deposits.clear()
	world.reactions.clear()
	_freeze_participants(world)


func _finish_tick(world_tick: int, winner_id: int) -> void:
	phase = Phase.RESULT
	winner_entity_id = winner_id if scores_by_entity.has(winner_id) else 0
	result_end_tick = world_tick + _result_ticks()
	respawn_tick_by_entity = {}


func _freeze_participants(world: SimWorld) -> void:
	for entity_id: int in scores_by_entity:
		var state: PlayerState = world.player(entity_id)
		if state == null:
			continue
		state.velocity_x = 0
		state.velocity_y = 0
		state.primary_held = false
		state.pending_cast_wire_id = 0
		state.pending_cast_ticks = 0
		state.sprinting = false
		state.movement_mode = PlayerState.MovementMode.IDLE


func _leading_entity() -> int:
	var leader_id := 0
	var leader_score := -1
	var tied := false
	var entity_ids: Array[int] = scores_by_entity.keys()
	entity_ids.sort()
	for entity_id: int in entity_ids:
		var score := int(scores_by_entity[entity_id])
		if score > leader_score:
			leader_id = entity_id
			leader_score = score
			tied = false
		elif score == leader_score:
			tied = true
	return 0 if tied else leader_id


func _result_ticks() -> int:
	return maxi(1, configured_result_ticks)


func _enforce_bounds(world: SimWorld) -> void:
	for entity_id: int in scores_by_entity:
		var state: PlayerState = world.player(entity_id)
		if state == null or state.health <= 0:
			continue
		var minimum_x := arena_bounds.position.x + MovementTuning.PLAYER_RADIUS
		var maximum_x := arena_bounds.end.x - MovementTuning.PLAYER_RADIUS
		var minimum_y := arena_bounds.position.y + MovementTuning.PLAYER_RADIUS
		var maximum_y := arena_bounds.end.y - MovementTuning.PLAYER_RADIUS
		var next_x := clampi(state.position_x, minimum_x, maximum_x)
		var next_y := clampi(state.position_y, minimum_y, maximum_y)
		if next_x != state.position_x:
			state.velocity_x = 0
		if next_y != state.position_y:
			state.velocity_y = 0
		state.position_x = next_x
		state.position_y = next_y


func _parse_definition(definition: Dictionary, world: SimWorld) -> Dictionary:
	var bounds_values: Array = definition.get("bounds", [])
	var spawn_values: Array = definition.get("spawns", [])
	var requested_score_limit := int(definition.get("score_limit", 0))
	var round_seconds := int(definition.get("round_seconds", 0))
	var result_seconds := int(definition.get("result_seconds", 0))
	var respawn_ms := int(definition.get("respawn_ms", 0))
	var protection_ms := int(definition.get("spawn_protection_ms", 0))
	if bounds_values.size() != 4 or spawn_values.size() < MIN_PLAYERS or spawn_values.size() > MAX_PLAYERS:
		return {}
	if requested_score_limit < MIN_SCORE_LIMIT or requested_score_limit > MAX_SCORE_LIMIT:
		return {}
	if round_seconds < MIN_ROUND_SECONDS or round_seconds > MAX_ROUND_SECONDS or result_seconds < MIN_RESULT_SECONDS or result_seconds > MAX_RESULT_SECONDS:
		return {}
	if respawn_ms < MIN_RESPAWN_MS or respawn_ms > MAX_RESPAWN_MS or protection_ms < MIN_PROTECTION_MS or protection_ms > MAX_PROTECTION_MS:
		return {}
	var bounds := Rect2i(
		int(bounds_values[0]) * SimConfig.FIXED_SCALE,
		int(bounds_values[1]) * SimConfig.FIXED_SCALE,
		int(bounds_values[2]) * SimConfig.FIXED_SCALE,
		int(bounds_values[3]) * SimConfig.FIXED_SCALE,
	)
	if bounds.size.x < 320_000 or bounds.size.y < 240_000 or bounds.position.x < 0 or bounds.position.y < 0 or bounds.end.x > world.collision.width or bounds.end.y > world.collision.height:
		return {}
	var spawn_points: Array[Vector2i] = []
	for value: Variant in spawn_values:
		if not value is Array or value.size() != 2:
			return {}
		var point := Vector2i(int(value[0]), int(value[1])) * SimConfig.FIXED_SCALE
		if not bounds.has_point(point) or not world.collision.can_occupy(point, MovementTuning.PLAYER_RADIUS):
			return {}
		spawn_points.append(point)
	configured_result_ticks = world.config.milliseconds_to_ticks(result_seconds * 1000)
	return {
		"bounds": bounds,
		"spawn_points": spawn_points,
		"score_limit": requested_score_limit,
		"round_seconds": round_seconds,
		"respawn_ms": respawn_ms,
		"protection_ms": protection_ms,
	}
