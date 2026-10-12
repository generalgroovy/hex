extends RefCounted
## Bounded diagnostic replay of an admitted Hex world, not a save-game grant.
## A caller supplies its trusted map; replay bytes never define collision rules.
const Snapshot = preload("res://src/net/hex_world_snapshot.gd")
const FORMAT := 1
const MAX_FRAMES := 7200
const MAX_BYTES := 8 * 1024 * 1024
const COMMAND_FIELDS := ["tick", "entity_id", "move_x", "move_y", "held_actions", "pressed_actions", "aim_x", "aim_y", "aim_target_x", "aim_target_y"]
var header := {}
var initial := {}
var frames: Array[Dictionary] = []
var last_error := ""


func begin(world: SimWorld) -> bool:
	header.clear()
	initial.clear()
	frames.clear()
	last_error = ""
	if world == null or world.hex_court == null: return _fail("Replay requires an admitted current Hex world.")
	var identity := RuntimeBuildIdentity.load_current(SimConfig.PROTOCOL_VERSION, SessionSnapshot.SCHEMA_VERSION)
	if not bool(identity.get("ok", false)): return _fail("Replay runtime identity is unavailable.")
	initial = Snapshot.capture(world)
	if initial.is_empty(): return _fail("Initial world does not admit a complete snapshot.")
	header = {"format": FORMAT, "protocol": SimConfig.PROTOCOL_VERSION, "snapshot_schema": Snapshot.SCHEMA_VERSION,
		"runtime": String(identity.runtime_source_sha256), "map_id": world.map_id, "map_hash": world.map_hash,
		"tick_rate": world.config.tick_rate, "seed": world.seed, "first_tick": world.tick}
	return true


func append_tick(commands: Array[SimCommand], after: SimWorld) -> bool:
	if header.is_empty() or after == null: return _fail("Replay has no initial world.")
	if frames.size() >= MAX_FRAMES: return _fail("Replay reached its 60-second recording limit.")
	var tick := int(header.first_tick) + frames.size()
	if after.tick != tick + 1 or after.map_id != header.map_id or after.map_hash != header.map_hash:
		return _fail("Replay world changed or a tick was skipped.")
	var lanes := PackedInt64Array()
	var seen := {}
	for command: SimCommand in commands:
		if command == null or command.tick != tick or seen.has(command.entity_id) or after.player(command.entity_id) == null:
			return _fail("Replay command set is not the actual single-tick actor set.")
		seen[command.entity_id] = true
		for field: String in COMMAND_FIELDS: lanes.append(int(command.get(field)))
	if commands.size() > Snapshot.MAX_ACTORS or _decode_commands(lanes, tick) == null:
		return _fail("Replay command set exceeds supported bounds.")
	frames.append({"commands": lanes, "hash": after.state_hash()})
	return true


func verify(trusted_world: SimWorld) -> Dictionary:
	var admission := _admit(trusted_world)
	if not admission.is_empty(): return {"ok": false, "tick": -1, "error": admission}
	var replay_world := Snapshot.prepare(initial, trusted_world)
	if replay_world == null: return {"ok": false, "tick": -1, "error": "Initial snapshot refused by the trusted map."}
	for index: int in frames.size():
		var tick := int(header.first_tick) + index
		var commands: Variant = _decode_commands(frames[index].get("commands"), tick)
		if commands == null: return {"ok": false, "tick": tick, "error": "Invalid replay command lanes."}
		if not replay_world.step(commands): return {"ok": false, "tick": tick, "error": replay_world.last_error}
		var actual := replay_world.state_hash()
		if actual != frames[index].hash:
			return {"ok": false, "tick": tick, "frame": index, "error": "First divergent tick.", "expected": frames[index].hash, "actual": actual}
	return {"ok": true, "tick": replay_world.tick, "frames": frames.size(), "error": "", "final_hash": replay_world.state_hash()}


func encode() -> PackedByteArray:
	if header.is_empty() or initial.is_empty() or frames.size() > MAX_FRAMES: return PackedByteArray()
	var bytes := var_to_bytes({"header": header, "initial": initial, "frames": frames})
	return bytes if bytes.size() <= MAX_BYTES else PackedByteArray()


func decode(bytes: PackedByteArray, trusted_world: SimWorld) -> bool:
	if bytes.is_empty() or bytes.size() > MAX_BYTES: return _fail("Replay bytes exceed the diagnostic limit.")
	# bytes_to_var never instantiates encoded objects (full_objects is disabled).
	var data: Variant = bytes_to_var(bytes)
	if not data is Dictionary or data.size() != 3 or not data.get("header") is Dictionary or not data.get("initial") is Dictionary or not data.get("frames") is Array:
		return _fail("Replay container is malformed.")
	var candidate = get_script().new()
	candidate.header = data.header.duplicate(true)
	candidate.initial = data.initial.duplicate(true)
	if data.frames.size() > MAX_FRAMES: return _fail("Replay has too many frames.")
	for frame: Variant in data.frames:
		if not frame is Dictionary: return _fail("Replay frame is malformed.")
		candidate.frames.append(frame.duplicate(true))
	var error: String = candidate._admit(trusted_world)
	if not error.is_empty(): return _fail(error)
	if Snapshot.prepare(candidate.initial, trusted_world) == null: return _fail("Initial replay snapshot was refused.")
	header = candidate.header
	initial = candidate.initial
	frames = candidate.frames
	last_error = ""
	return true


func _admit(world: SimWorld) -> String:
	if world == null or world.hex_court == null or header.size() != 9: return "Replay requires the trusted current map."
	var identity := RuntimeBuildIdentity.load_current(SimConfig.PROTOCOL_VERSION, SessionSnapshot.SCHEMA_VERSION)
	if not bool(identity.get("ok", false)): return "Current runtime identity unavailable."
	if header.get("format") != FORMAT or header.get("protocol") != SimConfig.PROTOCOL_VERSION or header.get("snapshot_schema") != Snapshot.SCHEMA_VERSION:
		return "Replay version differs from the current runtime."
	if header.get("runtime") != identity.runtime_source_sha256: return "Replay runtime source differs."
	if header.get("map_id") != world.map_id or header.get("map_hash") != world.map_hash: return "Replay map identity differs."
	if header.get("tick_rate") != world.config.tick_rate or header.get("seed") != world.seed: return "Replay simulation settings differ."
	if typeof(header.get("first_tick")) != TYPE_INT or int(header.first_tick) < 0 or frames.size() > MAX_FRAMES: return "Replay frame bounds invalid."
	if not Snapshot.validate_wire_structure(initial) or int(initial.header[1]) != int(header.first_tick): return "Replay initial snapshot is malformed."
	for index: int in frames.size():
		var frame := frames[index]
		if frame.size() != 2 or not frame.get("hash") is String or String(frame.hash).length() != 64 or _decode_commands(frame.get("commands"), int(header.first_tick) + index) == null:
			return "Replay frame is malformed."
	return ""


static func _decode_commands(value: Variant, tick: int) -> Variant:
	if not value is PackedInt64Array or value.size() % 10 != 0 or value.size() > Snapshot.MAX_ACTORS * 10: return null
	var result: Array[SimCommand] = []
	var seen := {}
	for offset: int in range(0, value.size(), 10):
		var entity := int(value[offset + 1])
		if int(value[offset]) != tick or entity < 1 or entity > Snapshot.MAX_ID or seen.has(entity): return null
		if absi(value[offset + 2]) > 1000 or absi(value[offset + 3]) > 1000: return null
		if value[offset + 4] < 0 or value[offset + 4] > 0xffff or value[offset + 5] < 0 or value[offset + 5] > 0x3ffff: return null
		if absi(value[offset + 6]) > 1000 or absi(value[offset + 7]) > 1000 or (value[offset + 6] == 0 and value[offset + 7] == 0): return null
		for lane: int in [8, 9]:
			if value[offset + lane] < -1 or value[offset + lane] > 100_000_000: return null
		if (value[offset + 8] == -1) != (value[offset + 9] == -1): return null
		var command := SimCommand.new()
		# Preserve already normalized integer aim exactly, without normalizing twice.
		for lane: int in COMMAND_FIELDS.size(): command.set(COMMAND_FIELDS[lane], int(value[offset + lane]))
		seen[entity] = true
		result.append(command)
	return result


func _fail(message: String) -> bool:
	last_error = message
	return false
