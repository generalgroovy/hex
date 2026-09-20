class_name AuthoritativeSession
extends RefCounted

const WorldEnvelope = preload("res://src/net/world_snapshot_envelope.gd")
const HexSnapshot = preload("res://src/net/hex_world_snapshot.gd")

const REMOTE_INPUT_TIMEOUT_MS: int = 250
const EVENT_REDUNDANCY_SNAPSHOTS: int = 4
const EVENT_PRIORITY_ACTIONABLE: int = 2
const EVENT_PRIORITY_OUTCOME: int = 1
const EVENT_PRIORITY_COSMETIC: int = 0
const ACTIONABLE_EVENT_TYPES: Array[String] = [
	"cast_refused", "cast_blocked",
	"station_confirmed", "champion_attuned", "request_refused", "ready_changed",
	"practice_countdown", "practice_started", "practice_cancelled",
	"round_knockout", "round_respawned", "round_finished", "round_returning",
]
const OUTCOME_EVENT_TYPES: Array[String] = [
	"spray_intercepted", "hex_clash",
	"cast_started", "projectile_hit", "edgeweave", "social_emote", "spray_hit", "field_triggered",
]
const SPAWN_OFFSETS: Array[Vector2i] = [
	Vector2i(72, 0),
	Vector2i(-72, 0),
	Vector2i(0, 72),
	Vector2i(0, -72),
	Vector2i(72, 72),
	Vector2i(-72, 72),
	Vector2i(72, -72),
]

var world: SimWorld
var champion_catalog: ChampionCatalog
var spawn: Vector2i
var names_by_entity: Dictionary[int, String] = {}
var latest_input_by_entity: Dictionary[int, Dictionary] = {}
var last_processed_input_sequence_by_entity: Dictionary[int, int] = {}
var pending_combat_events: Array[Dictionary] = []
var next_event_id: int = 1
var pending_combat_event_overflow_count: int = 0
var pending_combat_event_overflow_remaining_snapshots: int = 0
var snapshot_capture_pending_ack: bool = false
var last_error: String = ""
var charter_id: String = SessionCharter.DEFAULT_ID
var hearth: SessionHearth = SessionHearth.new()
var session_round: SessionRound = SessionRound.new()
var world_epoch: int = 0


func bind(
	new_world: SimWorld,
	new_champion_catalog: ChampionCatalog,
	spawn_pixels: Vector2i,
	host_name: String,
	existing_roster: Array[Dictionary] = [],
	requested_charter_id: String = SessionCharter.DEFAULT_ID,
) -> bool:
	last_error = ""
	if new_world == null or not new_world.is_valid() or new_champion_catalog == null:
		return _fail("Authoritative session requires a valid world and champion catalog")
	var safe_host_name := SessionTransport._validated_player_name(host_name)
	if safe_host_name.is_empty():
		return _fail("Authoritative host name is invalid")
	if not SessionCharter.is_valid_id(requested_charter_id):
		return _fail("Authoritative session charter is invalid")
	world = new_world
	champion_catalog = new_champion_catalog
	spawn = spawn_pixels
	names_by_entity = {SessionTransport.SERVER_PEER_ID: safe_host_name}
	latest_input_by_entity = {}
	last_processed_input_sequence_by_entity = {}
	pending_combat_events = []
	next_event_id = 1
	pending_combat_event_overflow_count = 0
	pending_combat_event_overflow_remaining_snapshots = 0
	snapshot_capture_pending_ack = false
	charter_id = requested_charter_id
	hearth = SessionHearth.new()
	hearth.bind_host()
	session_round = SessionRound.new()
	session_round.bind_hearth()
	world_epoch = 0
	_apply_charter_team(new_world.player())
	return register_peers(existing_roster) == existing_roster.size()


func register_peers(events: Array[Dictionary]) -> int:
	if world == null or champion_catalog == null:
		return 0
	var registered: int = 0
	for event: Dictionary in events:
		var entity_id := int(event.get("entity_id", 0))
		var safe_name := SessionTransport._validated_player_name(String(event.get("name", "")))
		if entity_id < 2 or entity_id > SessionTransport.MAX_PLAYERS or safe_name.is_empty():
			continue
		var existing_state: PlayerState = world.player(entity_id)
		if existing_state != null and bool(event.get("resumed", false)):
			names_by_entity[entity_id] = safe_name
			last_processed_input_sequence_by_entity[entity_id] = -1
			existing_state.last_event = "farflow_return"
			_apply_charter_team(existing_state)
			hearth.connect_entity(entity_id)
			registered += 1
			continue
		if existing_state != null:
			continue
		var state := PlayerState.new(entity_id)
		var champion_id := "s_wayne" if entity_id % 2 == 0 else champion_catalog.default_champion_id
		if not champion_catalog.apply_to_player(state, champion_id):
			continue
		var spawn_position := _spawn_position(entity_id, MovementTuning.PLAYER_RADIUS)
		state.position_x = spawn_position.x
		state.position_y = spawn_position.y
		_apply_charter_team(state)
		if session_round != null and session_round.phase != SessionRound.Phase.HEARTH:
			state.health = 0
			state.last_event = "round_wait"
		else:
			state.last_event = "farflow_arrival"
		world.players.append(state)
		names_by_entity[entity_id] = safe_name
		last_processed_input_sequence_by_entity[entity_id] = -1
		hearth.connect_entity(entity_id)
		if bool(event.get("reserved", false)):
			hearth.suspend_entity(entity_id)
			state.last_event = "farflow_returning"
		registered += 1
	world.players.sort_custom(func(left: PlayerState, right: PlayerState) -> bool: return left.entity_id < right.entity_id)
	return registered


func set_charter(requested_charter_id: String) -> bool:
	if world == null or not SessionCharter.is_valid_id(requested_charter_id):
		return false
	charter_id = requested_charter_id
	for state: PlayerState in world.players:
		_apply_charter_team(state)
	return true


func _apply_charter_team(state: PlayerState) -> void:
	if state != null and state.actor_kind == PlayerState.ActorKind.CHAMPION:
		state.team_id = SessionCharter.team_for_champion(charter_id, state.entity_id)


func suspend_peers(events: Array[Dictionary]) -> int:
	if world == null:
		return 0
	var suspended: int = 0
	for event: Dictionary in events:
		if not bool(event.get("reserved", false)):
			continue
		var entity_id := int(event.get("entity_id", 0))
		var state: PlayerState = world.player(entity_id)
		if state == null or state.actor_kind != PlayerState.ActorKind.CHAMPION:
			continue
		latest_input_by_entity.erase(entity_id)
		state.primary_held = false
		state.last_event = "farflow_returning"
		hearth.suspend_entity(entity_id)
		suspended += 1
	return suspended


func remove_peers(events: Array[Dictionary]) -> int:
	if world == null:
		return 0
	var removed: int = 0
	for event: Dictionary in events:
		var entity_id := int(event.get("entity_id", 0))
		var round_events: Array[Dictionary] = session_round.remove_participant(entity_id, world) if session_round != null else []
		if not round_events.is_empty():
			record_combat_events(round_events)
		for index: int in range(world.players.size() - 1, -1, -1):
			var state: PlayerState = world.players[index]
			if state.entity_id == entity_id and state.actor_kind == PlayerState.ActorKind.CHAMPION:
				world.players.remove_at(index)
				removed += 1
				break
		names_by_entity.erase(entity_id)
		latest_input_by_entity.erase(entity_id)
		last_processed_input_sequence_by_entity.erase(entity_id)
		hearth.remove_entity(entity_id)
	return removed


func ingest_inputs(inputs: Array[Dictionary]) -> int:
	if world == null:
		return 0
	var accepted: int = 0
	for packet: Dictionary in inputs:
		var entity_id := int(packet.get("entity_id", 0))
		if entity_id < 2 or entity_id > SessionTransport.MAX_PLAYERS or world.player(entity_id) == null:
			continue
		var merged: Dictionary = packet.duplicate(true)
		if latest_input_by_entity.has(entity_id):
			merged["pressed"] = int(merged.get("pressed", 0)) | int(latest_input_by_entity[entity_id].get("pressed", 0))
		merged["received_tick"] = world.tick
		latest_input_by_entity[entity_id] = merged
		accepted += 1
	return accepted


func commands_for_tick(local_command: SimCommand) -> Array[SimCommand]:
	var commands: Array[SimCommand] = []
	if world == null or local_command == null:
		return commands
	var host_input_locked := _round_input_locked(SessionTransport.SERVER_PEER_ID)
	commands.append(SimCommand.new(
		world.tick,
		SessionTransport.SERVER_PEER_ID,
		0 if host_input_locked else local_command.move_x,
		0 if host_input_locked else local_command.move_y,
		0 if host_input_locked else local_command.held_actions,
		0 if host_input_locked else local_command.pressed_actions,
		local_command.aim_x,
		local_command.aim_y,
		local_command.aim_target_x,
		local_command.aim_target_y,
	))
	var remote_ids: Array[int] = []
	for state: PlayerState in world.players:
		if state.actor_kind == PlayerState.ActorKind.CHAMPION and state.entity_id > SessionTransport.SERVER_PEER_ID:
			remote_ids.append(state.entity_id)
	remote_ids.sort()
	var timeout_ticks := world.config.milliseconds_to_ticks(REMOTE_INPUT_TIMEOUT_MS)
	for entity_id: int in remote_ids:
		var state: PlayerState = world.player(entity_id)
		var packet: Dictionary = latest_input_by_entity.get(entity_id, {})
		var stale: bool = packet.is_empty() or world.tick - int(packet.get("received_tick", world.tick)) > timeout_ticks or _round_input_locked(entity_id)
		commands.append(SimCommand.new(
			world.tick,
			entity_id,
			0 if stale else int(packet.get("move_x", 0)),
			0 if stale else int(packet.get("move_y", 0)),
			0 if stale else int(packet.get("held", 0)),
			0 if stale else int(packet.get("pressed", 0)),
			state.aim_x if stale else int(packet.get("aim_x", state.aim_x)),
			state.aim_y if stale else int(packet.get("aim_y", state.aim_y)),
			-1 if stale else int(packet.get("aim_target_x", -1)),
			-1 if stale else int(packet.get("aim_target_y", -1)),
		))
		if not packet.is_empty():
			if not stale:
				last_processed_input_sequence_by_entity[entity_id] = int(packet.get("sequence", -1))
			packet["pressed"] = 0
			if stale:
				packet["move_x"] = 0
				packet["move_y"] = 0
				packet["held"] = 0
			latest_input_by_entity[entity_id] = packet
	return commands


func _round_input_locked(entity_id: int) -> bool:
	if session_round == null or session_round.phase == SessionRound.Phase.HEARTH:
		return false
	# Every nonparticipant remains an inert next-gathering observer. During the
	# result, participants are frozen as well. This is host authority, not a
	# cooperative client convention.
	return not session_round.scores_by_entity.has(entity_id) or session_round.phase == SessionRound.Phase.RESULT


func input_locked(entity_id: int) -> bool:
	return _round_input_locked(entity_id)


func capture_snapshot() -> Dictionary:
	if world == null or world.hex_court != null:
		return {}
	var snapshot := SessionSnapshot.capture(
		world,
		names_by_entity,
		pending_combat_events,
		hearth.capture(world.tick, SessionCharter.maximum_players(charter_id)),
		session_round.capture(world),
	)
	if snapshot.is_empty():
		return {}
	var overflow: PackedInt32Array = snapshot["overflow"]
	overflow[2] = pending_combat_event_overflow_count
	snapshot["overflow"] = overflow
	snapshot_capture_pending_ack = true
	return snapshot


func capture_envelope() -> Dictionary:
	if world == null:
		return {}
	if world.hex_court == null:
		var legacy := capture_snapshot()
		return WorldEnvelope.wrap_legacy(legacy, world_epoch) if not legacy.is_empty() else {}
	var authority := HexSnapshot.capture(world)
	if authority.is_empty():
		return {}
	var names: Array = []
	var champions: Array[PlayerState] = []
	for state: PlayerState in world.players:
		if state.actor_kind == PlayerState.ActorKind.CHAMPION:
			champions.append(state)
	champions.sort_custom(func(left: PlayerState, right: PlayerState) -> bool: return left.entity_id < right.entity_id)
	for state: PlayerState in champions:
		var safe_name := SessionSnapshot._safe_name(String(names_by_entity.get(state.entity_id, "Traveller %d" % state.entity_id)))
		var safe_event := SessionSnapshot._safe_event_name(state.last_event)
		if safe_name.is_empty():
			return {}
		names.append([state.entity_id, safe_name, safe_event])
	var events: Array[PackedInt64Array] = []
	var first_event_index := maxi(0, pending_combat_events.size() - SessionSnapshot.MAX_EVENTS)
	for index: int in range(first_event_index, pending_combat_events.size()):
		var encoded := SessionSnapshot.encode_event(pending_combat_events[index])
		if encoded.is_empty():
			return {}
		events.append(encoded)
	var session := WorldEnvelope.make_hex_session(
		names,
		events,
		hearth.capture(world.tick, SessionCharter.maximum_players(charter_id)),
		session_round.capture(world),
		PackedInt32Array([0, 0, pending_combat_event_overflow_count, 0]),
	)
	if session.is_empty():
		return {}
	var envelope := WorldEnvelope.wrap_hex(authority, session, world_epoch)
	if envelope.is_empty():
		return {}
	snapshot_capture_pending_ack = true
	return envelope


func toggle_ready(entity_id: int) -> bool:
	return hearth.toggle_ready(entity_id) if hearth != null else false


func can_start_practice() -> bool:
	return hearth != null and hearth.all_connected_ready()


func start_practice_countdown(entity_id: int) -> bool:
	if hearth == null or world == null:
		return false
	return hearth.start_countdown(entity_id, world.tick, world.config.milliseconds_to_ticks(3000))


func practice_countdown_active() -> bool:
	return hearth != null and hearth.countdown_active()


func practice_countdown_completed() -> bool:
	return hearth != null and world != null and hearth.countdown_completed(world.tick)


func clear_practice_start() -> void:
	if hearth != null:
		hearth.clear_after_start()


func begin_round(arena_definition: Dictionary) -> bool:
	if session_round == null or hearth == null or world == null:
		return false
	return session_round.begin(world, hearth.connected_entity_ids(), arena_definition)


func advance_round(events: Array[Dictionary]) -> Array[Dictionary]:
	if session_round == null or world == null:
		return []
	var emitted := session_round.advance(world, events)
	for event: Dictionary in emitted:
		world.combat_events.append(event)
	return emitted


func round_return_due() -> bool:
	return session_round != null and world != null and session_round.return_due(world.tick)


func capture_reconciliation(entity_id: int) -> Dictionary:
	if world == null:
		return {}
	var state: PlayerState = world.player(entity_id)
	if state == null or state.actor_kind != PlayerState.ActorKind.CHAMPION or entity_id <= SessionTransport.SERVER_PEER_ID:
		return {}
	return ClientPrediction.capture_packet(
		state,
		world.tick,
		int(last_processed_input_sequence_by_entity.get(entity_id, -1)),
		[] if world.hex_court != null else world.reactions,
	)


# Replaces a completed world as one epoch transition. The detached session may
# mutate the supplied fresh world while validating, but this session remains
# untouched until every roster identity and persistent loadout has been rebuilt.
func replace_world(new_world: SimWorld, spawn_pixels: Vector2i) -> bool:
	last_error = ""
	if world == null or champion_catalog == null:
		return _fail("Authoritative session must be bound before replacing its world")
	if world_epoch >= WorldEnvelope.MAX_EPOCH:
		return _fail("Authoritative world epoch is exhausted")
	if not _replacement_world_valid(new_world):
		return _fail("Replacement world must be a fresh tick-zero authority with independent physics")
	var host_name := String(names_by_entity.get(SessionTransport.SERVER_PEER_ID, ""))
	if SessionTransport._validated_player_name(host_name).is_empty():
		return _fail("Replacement world requires the existing valid host identity")
	var old_champions: Array[PlayerState] = []
	for state: PlayerState in world.players:
		if state.actor_kind == PlayerState.ActorKind.CHAMPION:
			old_champions.append(state)
	old_champions.sort_custom(func(left: PlayerState, right: PlayerState) -> bool: return left.entity_id < right.entity_id)
	if old_champions.is_empty() or old_champions[0].entity_id != SessionTransport.SERVER_PEER_ID:
		return _fail("Replacement world requires the live host champion")
	var roster: Array[Dictionary] = []
	for old_state: PlayerState in old_champions:
		if old_state.entity_id == SessionTransport.SERVER_PEER_ID:
			continue
		var safe_name := SessionTransport._validated_player_name(String(names_by_entity.get(old_state.entity_id, "")))
		if safe_name.is_empty():
			return _fail("Replacement roster contains an invalid player identity")
		roster.append({
			"entity_id": old_state.entity_id,
			"name": safe_name,
			"reserved": int(hearth.presence_by_entity.get(old_state.entity_id, SessionHearth.STATUS_CONNECTED)) == SessionHearth.STATUS_RETURNING,
		})
	var candidate := AuthoritativeSession.new()
	if not candidate.bind(new_world, champion_catalog, spawn_pixels, host_name, roster, charter_id):
		return _fail(candidate.last_error if not candidate.last_error.is_empty() else "Replacement roster could not bind")
	for old_state: PlayerState in old_champions:
		var replacement: PlayerState = candidate.world.player(old_state.entity_id)
		if replacement == null or replacement == old_state or not _restore_persistent_champion(old_state, replacement, champion_catalog):
			return _fail("Replacement roster could not restore champion %d" % old_state.entity_id)
	# A world transition closes the active/result instance while retaining the
	# monotonic round identity for the next begin().
	candidate.session_round.serial = session_round.serial
	candidate.next_event_id = next_event_id
	candidate.world_epoch = world_epoch + 1
	candidate.last_processed_input_sequence_by_entity = {}
	world = candidate.world
	champion_catalog = candidate.champion_catalog
	spawn = candidate.spawn
	names_by_entity = candidate.names_by_entity
	latest_input_by_entity = candidate.latest_input_by_entity
	last_processed_input_sequence_by_entity = candidate.last_processed_input_sequence_by_entity
	pending_combat_events = candidate.pending_combat_events
	next_event_id = candidate.next_event_id
	pending_combat_event_overflow_count = 0
	pending_combat_event_overflow_remaining_snapshots = 0
	snapshot_capture_pending_ack = false
	charter_id = candidate.charter_id
	hearth = candidate.hearth
	session_round = candidate.session_round
	world_epoch = candidate.world_epoch
	return true


func _replacement_world_valid(new_world: SimWorld) -> bool:
	if new_world == null or new_world == world or not new_world.is_valid() or new_world.tick != 0:
		return false
	if not new_world.projectiles.is_empty() or not new_world.fields.is_empty() or not new_world.deposits.is_empty() or not new_world.reactions.is_empty():
		return false
	if new_world.collision == world.collision or new_world.reaction_movement == world.reaction_movement \
		or (new_world.hex_court != null and new_world.hex_court == world.hex_court):
		return false
	var old_base: CollisionWorld = (world.collision as HexCollisionWorld).base_world if world.collision is HexCollisionWorld else world.collision
	var new_base: CollisionWorld = (new_world.collision as HexCollisionWorld).base_world if new_world.collision is HexCollisionWorld else new_world.collision
	if new_base == old_base:
		return false
	if new_world.hex_court != null:
		if not new_world.hex_court is HexChemistryWorld or new_world.hex_court.current_tick != 0:
			return false
		if not new_world.hex_court.casts.is_empty() or not new_world.hex_court.products.is_empty() \
			or not new_world.hex_court.pending.is_empty() or not new_world.hex_court.sources.is_empty() \
			or int(new_world.hex_court.metrics.get("matter_paid", 0)) != 0:
			return false
	return true


static func _restore_persistent_champion(source: PlayerState, target: PlayerState, catalog: ChampionCatalog) -> bool:
	if source == null or target == null or source.actor_kind != PlayerState.ActorKind.CHAMPION or source.entity_id != target.entity_id:
		return false
	var champion_id := catalog.champion_id_from_wire(source.champion_wire_id)
	if champion_id.is_empty() or not catalog.apply_to_player(target, champion_id):
		return false
	if not source.has_valid_spell_slots():
		return false
	target.primary_wire_id = source.primary_wire_id
	target.active_1_wire_id = source.active_1_wire_id
	target.active_2_wire_id = source.active_2_wire_id
	target.spell_wire_ids = source.spell_wire_ids.duplicate()
	target.spell_cooldown_ticks = PackedInt32Array()
	target.spell_cooldown_ticks.resize(PlayerState.SPELL_SLOT_COUNT)
	target.spell_cooldown_ticks.fill(0)
	if not target.has_valid_spell_slots():
		return false
	var reset_position := Vector2i(target.position_x, target.position_y)
	target.reset_for_spawn(reset_position)
	target.team_id = source.team_id
	return true


func record_combat_events(events: Array[Dictionary]) -> int:
	var accepted: int = 0
	for event: Dictionary in events:
		if SessionSnapshot.encode_event(event).is_empty():
			continue
		# Any accepted event changes the next event snapshot generation. A send
		# result for an older capture must not age feedback it never contained.
		snapshot_capture_pending_ack = false
		var retained := event.duplicate(true)
		retained["event_id"] = next_event_id
		retained["_remaining_snapshots"] = EVENT_REDUNDANCY_SNAPSHOTS
		next_event_id = 1 if next_event_id >= SessionSnapshot.MAX_EVENT_ID else next_event_id + 1
		pending_combat_events.append(retained)
		if pending_combat_events.size() > SessionSnapshot.MAX_EVENTS:
			_trim_pending_combat_event()
		accepted += 1
	return accepted


func _trim_pending_combat_event() -> void:
	var incoming_index := pending_combat_events.size() - 1
	var incoming_priority := _combat_event_priority(pending_combat_events[incoming_index])
	var oldest_lowest_index: int = -1
	var lowest_priority: int = EVENT_PRIORITY_ACTIONABLE + 1
	for index: int in range(incoming_index):
		var priority := _combat_event_priority(pending_combat_events[index])
		if priority < lowest_priority:
			lowest_priority = priority
			oldest_lowest_index = index
	if oldest_lowest_index >= 0 and lowest_priority <= incoming_priority:
		pending_combat_events.remove_at(oldest_lowest_index)
	else:
		pending_combat_events.pop_back()
	if pending_combat_event_overflow_count < SessionSnapshot.MAX_EVENT_ID:
		pending_combat_event_overflow_count += 1
	pending_combat_event_overflow_remaining_snapshots = EVENT_REDUNDANCY_SNAPSHOTS


static func _combat_event_priority(event: Dictionary) -> int:
	var event_type := String(event.get("type", ""))
	if event_type in ACTIONABLE_EVENT_TYPES:
		return EVENT_PRIORITY_ACTIONABLE
	if event_type in OUTCOME_EVENT_TYPES:
		return EVENT_PRIORITY_OUTCOME
	return EVENT_PRIORITY_COSMETIC


func acknowledge_snapshot() -> void:
	if not snapshot_capture_pending_ack:
		return
	snapshot_capture_pending_ack = false
	for index: int in range(pending_combat_events.size() - 1, -1, -1):
		var event: Dictionary = pending_combat_events[index]
		event["_remaining_snapshots"] = int(event.get("_remaining_snapshots", 1)) - 1
		if int(event["_remaining_snapshots"]) <= 0:
			pending_combat_events.remove_at(index)
		else:
			pending_combat_events[index] = event
	if pending_combat_event_overflow_remaining_snapshots > 0:
		pending_combat_event_overflow_remaining_snapshots -= 1
		if pending_combat_event_overflow_remaining_snapshots == 0:
			pending_combat_event_overflow_count = 0


func _spawn_position(entity_id: int, radius: int) -> Vector2i:
	var base := spawn * SimConfig.FIXED_SCALE
	var offset_index := clampi(entity_id - 2, 0, SPAWN_OFFSETS.size() - 1)
	var candidate := base + SPAWN_OFFSETS[offset_index] * SimConfig.FIXED_SCALE
	return candidate if world.collision.can_occupy(candidate, radius) else base


func _fail(message: String) -> bool:
	last_error = message
	return false
