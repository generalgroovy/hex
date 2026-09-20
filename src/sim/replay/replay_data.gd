class_name ReplayData
extends RefCounted


const FORMAT_VERSION: int = 1

var protocol_version: int = SimConfig.PROTOCOL_VERSION
var tick_rate: int
var seed: int
var map_id: String = SimWorld.MAP_ID
var map_hash: String = SimWorld.MAP_HASH
var commands: Array[SimCommand] = []
var expected_hashes := PackedStringArray()


func _init(requested_tick_rate: int = SimConfig.TICK_RATE, requested_seed: int = 1) -> void:
	tick_rate = requested_tick_rate
	seed = requested_seed


func append(command: SimCommand, expected_hash: String) -> void:
	commands.append(command.copy())
	expected_hashes.append(expected_hash)


func verify() -> Dictionary:
	if protocol_version != SimConfig.PROTOCOL_VERSION:
		return {"ok": false, "tick": -1, "error": "replay protocol version mismatch"}
	if not SimConfig.is_supported_tick_rate(tick_rate):
		return {"ok": false, "tick": -1, "error": "unsupported replay tick rate"}
	if commands.size() != expected_hashes.size():
		return {"ok": false, "tick": -1, "error": "replay command/hash length mismatch"}
	var world := SimWorld.new(tick_rate, seed)
	for index: int in range(commands.size()):
		if not world.step([commands[index]]):
			return {"ok": false, "tick": index, "error": world.last_error}
		var actual: String = world.state_hash()
		if actual != expected_hashes[index]:
			return {"ok": false, "tick": index, "error": "state hash mismatch", "expected": expected_hashes[index], "actual": actual}
	return {"ok": true, "tick": commands.size(), "error": ""}


static func record(command_log: Array[SimCommand], requested_tick_rate: int, requested_seed: int = 1) -> ReplayData:
	var replay := ReplayData.new(requested_tick_rate, requested_seed)
	var world := SimWorld.new(requested_tick_rate, requested_seed)
	if not world.is_valid():
		return replay
	for command: SimCommand in command_log:
		if not world.step([command]):
			return replay
		replay.append(command, world.state_hash())
	return replay
