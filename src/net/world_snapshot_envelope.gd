class_name WorldSnapshotEnvelope
extends RefCounted


const SessionSnapshotCodec = preload("res://src/net/session_snapshot.gd")
const HexSnapshotCodec = preload("res://src/net/hex_world_snapshot.gd")

const SCHEMA_VERSION: int = 1
const WORLD_LEGACY: int = 1
const WORLD_HEX: int = 2
const WORLD_KIND_LEGACY: int = WORLD_LEGACY
const WORLD_KIND_HEX: int = WORLD_HEX
const MAX_RAW_BYTES: int = 65_536
const MAX_EPOCH: int = 0x7fffffff
const MAX_TICK: int = 0x7fffffff
const ENVELOPE_KEYS: Array[String] = ["schema", "world_kind", "world_epoch", "tick", "authority", "session"]
const SESSION_KEYS: Array[String] = ["names", "events", "hearth", "round", "overflow"]


static func wrap_legacy(snapshot: Dictionary, world_epoch: int = 0) -> Dictionary:
	if not _counter_valid(world_epoch) or typeof(snapshot.get("tick")) != TYPE_INT:
		return {}
	var envelope := {
		"schema": SCHEMA_VERSION,
		"world_kind": WORLD_LEGACY,
		"world_epoch": world_epoch,
		"tick": int(snapshot.tick),
		"authority": snapshot.duplicate(true),
		"session": {},
	}
	return envelope if validate(envelope) else {}


static func wrap_hex(authority: Dictionary, session: Dictionary, world_epoch: int) -> Dictionary:
	if not _counter_valid(world_epoch) or typeof(authority.get("header")) != TYPE_PACKED_INT64_ARRAY:
		return {}
	var header: PackedInt64Array = authority.header as PackedInt64Array
	if header.size() < 2:
		return {}
	var envelope := {
		"schema": SCHEMA_VERSION,
		"world_kind": WORLD_HEX,
		"world_epoch": world_epoch,
		"tick": int(header[1]),
		"authority": authority.duplicate(true),
		"session": session.duplicate(true),
	}
	return envelope if validate(envelope) else {}


static func make_hex_session(
	names_value: Variant,
	events_value: Variant,
	hearth_value: Variant,
	round_value: Variant,
	overflow_value: Variant,
) -> Dictionary:
	var session := {
		"names": names_value.duplicate(true) if names_value is Array else names_value,
		"events": events_value.duplicate(true) if events_value is Array else events_value,
		"hearth": hearth_value.duplicate() if hearth_value is PackedInt32Array else hearth_value,
		"round": round_value.duplicate() if round_value is PackedInt32Array else round_value,
		"overflow": overflow_value.duplicate() if overflow_value is PackedInt32Array else overflow_value,
	}
	return session if _hex_session_shape_valid(session) else {}


static func validate(envelope: Dictionary) -> bool:
	if envelope.size() != ENVELOPE_KEYS.size():
		return false
	for key: String in ENVELOPE_KEYS:
		if not envelope.has(key):
			return false
	if typeof(envelope.schema) != TYPE_INT or int(envelope.schema) != SCHEMA_VERSION:
		return false
	if typeof(envelope.world_kind) != TYPE_INT or typeof(envelope.world_epoch) != TYPE_INT or typeof(envelope.tick) != TYPE_INT:
		return false
	if not _counter_valid(int(envelope.world_epoch)) or not _counter_valid(int(envelope.tick)):
		return false
	if not envelope.authority is Dictionary or not envelope.session is Dictionary:
		return false
	var authority_value: Dictionary = envelope.authority as Dictionary
	var session_value: Dictionary = envelope.session as Dictionary
	match int(envelope.world_kind):
		WORLD_LEGACY:
			if not session_value.is_empty() or not SessionSnapshotCodec.validate(authority_value) or int(authority_value.tick) != int(envelope.tick):
				return false
		WORLD_HEX:
			if not _hex_authority_valid(authority_value) or not _hex_session_valid(session_value, authority_value):
				return false
			var header: PackedInt64Array = authority_value.header as PackedInt64Array
			if int(header[1]) != int(envelope.tick):
				return false
		_:
			return false
	return byte_size(envelope) <= MAX_RAW_BYTES


static func byte_size(envelope: Dictionary) -> int:
	var encoded: PackedByteArray = var_to_bytes(envelope)
	return encoded.size() if not encoded.is_empty() else -1


static func authority(envelope: Dictionary) -> Dictionary:
	return (envelope.authority as Dictionary).duplicate(true) if validate(envelope) else {}


# One synchronous, fully validated projection, not a reusable trust token. It
# contains no authority or writable envelope aliases and is never accepted as
# an input that bypasses validation. Public individual getters stay unchanged.
static func metadata(envelope: Dictionary) -> Dictionary:
	if not validate(envelope):
		return {}
	var session: Dictionary = envelope.session
	var names_value: Array = []
	if int(envelope.world_kind) == WORLD_LEGACY:
		session = envelope.authority
		for player: Array in session.players:
			names_value.append([player[0], player[1], player[2]])
	else:
		names_value = (session.names as Array).duplicate(true)
	return {
		"world_kind": int(envelope.world_kind), "world_epoch": int(envelope.world_epoch), "tick": int(envelope.tick),
		"names": names_value, "events": (session.events as Array).duplicate(true),
		"hearth": (session.hearth as PackedInt32Array).duplicate(),
		"round": (session.round as PackedInt32Array).duplicate(),
		"overflow": (session.overflow as PackedInt32Array).duplicate(),
	}


static func names(envelope: Dictionary) -> Array:
	if not validate(envelope):
		return []
	if int(envelope.world_kind) == WORLD_LEGACY:
		var result: Array = []
		for player_value: Variant in (envelope.authority as Dictionary).players:
			var player: Array = player_value as Array
			result.append([player[0], player[1], player[2]])
		return result
	return ((envelope.session as Dictionary).names as Array).duplicate(true)


static func events(envelope: Dictionary) -> Array:
	if not validate(envelope):
		return []
	if int(envelope.world_kind) == WORLD_LEGACY:
		return ((envelope.authority as Dictionary).events as Array).duplicate(true)
	return ((envelope.session as Dictionary).events as Array).duplicate(true)


static func hearth(envelope: Dictionary) -> PackedInt32Array:
	if not validate(envelope):
		return PackedInt32Array()
	if int(envelope.world_kind) == WORLD_LEGACY:
		return ((envelope.authority as Dictionary).hearth as PackedInt32Array).duplicate()
	return ((envelope.session as Dictionary).hearth as PackedInt32Array).duplicate()


static func round_state(envelope: Dictionary) -> PackedInt32Array:
	if not validate(envelope):
		return PackedInt32Array()
	if int(envelope.world_kind) == WORLD_LEGACY:
		return ((envelope.authority as Dictionary).round as PackedInt32Array).duplicate()
	return ((envelope.session as Dictionary).round as PackedInt32Array).duplicate()


static func overflow(envelope: Dictionary) -> PackedInt32Array:
	if not validate(envelope):
		return PackedInt32Array()
	if int(envelope.world_kind) == WORLD_LEGACY:
		return ((envelope.authority as Dictionary).overflow as PackedInt32Array).duplicate()
	return ((envelope.session as Dictionary).overflow as PackedInt32Array).duplicate()


static func _hex_authority_valid(authority_value: Dictionary) -> bool:
	if not HexSnapshotCodec.validate_wire_structure(authority_value):
		return false
	return _hex_authority_header_valid(authority_value)


# Only the envelope's additional header/ordered-actor constraints. Public
# validation above always validates every authority lane first. The owned
# publication factory calls this only on its own fresh HexSnapshot.capture().
static func _hex_authority_header_valid(authority_value: Dictionary) -> bool:
	if typeof(authority_value.get("header")) != TYPE_PACKED_INT64_ARRAY or typeof(authority_value.get("players")) != TYPE_PACKED_INT32_ARRAY:
		return false
	var header: PackedInt64Array = authority_value.header as PackedInt64Array
	var players: PackedInt32Array = authority_value.players as PackedInt32Array
	if header.size() != 8 or int(authority_value.get("epoch", -1)) != HexSnapshotCodec.RESERVED_EPOCH:
		return false
	if not _counter_valid(int(header[1])) or players.is_empty() or players.size() % HexSnapshotCodec.PLAYER_VALUE_COUNT != 0:
		return false
	@warning_ignore("integer_division")
	var actor_count: int = players.size() / HexSnapshotCodec.PLAYER_VALUE_COUNT
	if actor_count < 1 or actor_count > HexSnapshotCodec.MAX_ACTORS:
		return false
	var previous_entity_id: int = 0
	for offset: int in range(0, players.size(), HexSnapshotCodec.PLAYER_VALUE_COUNT):
		var entity_id: int = players[offset]
		var actor_kind: int = players[offset + 2]
		if entity_id <= previous_entity_id or entity_id < 1 or entity_id > HexSnapshotCodec.MAX_ID or actor_kind not in [PlayerState.ActorKind.CHAMPION, PlayerState.ActorKind.TRAINING_TARGET]:
			return false
		previous_entity_id = entity_id
	return true


static func _hex_session_shape_valid(session: Dictionary) -> bool:
	if session.size() != SESSION_KEYS.size():
		return false
	for key: String in SESSION_KEYS:
		if not session.has(key):
			return false
	if not session.names is Array or not session.events is Array:
		return false
	if typeof(session.hearth) != TYPE_PACKED_INT32_ARRAY or typeof(session.round) != TYPE_PACKED_INT32_ARRAY or typeof(session.overflow) != TYPE_PACKED_INT32_ARRAY:
		return false
	var names_value: Array = session.names as Array
	if names_value.is_empty() or names_value.size() > SessionSnapshotCodec.MAX_PLAYERS:
		return false
	var previous_entity_id: int = 0
	for row_value: Variant in names_value:
		if not row_value is Array or (row_value as Array).size() != 3:
			return false
		var row: Array = row_value as Array
		if typeof(row[0]) != TYPE_INT or typeof(row[1]) != TYPE_STRING or typeof(row[2]) != TYPE_STRING:
			return false
		var entity_id: int = int(row[0])
		if entity_id <= previous_entity_id or entity_id < 1 or entity_id > SessionSnapshotCodec.MAX_PLAYERS:
			return false
		if SessionSnapshotCodec._safe_name(String(row[1])) != String(row[1]) or SessionSnapshotCodec._safe_event_name(String(row[2])) != String(row[2]):
			return false
		previous_entity_id = entity_id
	var events_value: Array = session.events as Array
	if events_value.size() > SessionSnapshotCodec.MAX_EVENTS:
		return false
	for event_value: Variant in events_value:
		if typeof(event_value) != TYPE_PACKED_INT64_ARRAY or not SessionSnapshotCodec._valid_event_values(event_value as PackedInt64Array):
			return false
	var overflow_value: PackedInt32Array = session.overflow as PackedInt32Array
	if overflow_value.size() != 4:
		return false
	for count: int in overflow_value:
		if count < 0:
			return false
	return SessionHearth.validate_packet(session.hearth) and SessionRound.validate_packet(session.round)


static func _hex_session_valid(session: Dictionary, authority_value: Dictionary) -> bool:
	if not _hex_session_shape_valid(session):
		return false
	var champion_ids: Array[int] = []
	var champion_teams: Dictionary[int, int] = {}
	var champion_health: Dictionary[int, int] = {}
	var players: PackedInt32Array = authority_value.players as PackedInt32Array
	for offset: int in range(0, players.size(), HexSnapshotCodec.PLAYER_VALUE_COUNT):
		if players[offset + 2] == PlayerState.ActorKind.CHAMPION:
			champion_ids.append(players[offset])
			champion_teams[int(players[offset])] = int(players[offset + 1])
			champion_health[int(players[offset])] = int(players[offset + 33])
	if champion_ids.size() != (session.names as Array).size() or SessionHearth.entry_count(session.hearth) != champion_ids.size():
		return false
	for index: int in champion_ids.size():
		var name_row: Array = (session.names as Array)[index] as Array
		if int(name_row[0]) != champion_ids[index] or SessionHearth.entity_id_at(session.hearth, index) != champion_ids[index]:
			return false
	var champion_set := {}
	for entity_id: int in champion_ids:
		champion_set[entity_id] = true
	var decoded_round: Dictionary = SessionRound.decoded(session.round)
	for entry_value: Variant in decoded_round.get("entries", []):
		if not entry_value is Dictionary:
			return false
		var entity_id := int(entry_value.get("entity_id", 0))
		if not bool(entry_value.get("present", true)):
			if champion_set.has(entity_id) and int(champion_health[entity_id]) != 0:
				return false
			continue # Frozen departed team ledger; a reused ID must be an inactive observer.
		if not champion_set.has(entity_id):
			return false
		if int(decoded_round.get("mode", 0)) != SessionRound.Mode.FREE_FOR_ALL and int(champion_teams[entity_id]) != int(entry_value.team_id):
			return false
	return true


static func _counter_valid(value: int) -> bool:
	return value >= 0 and value <= MAX_EPOCH
