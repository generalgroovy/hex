extends RefCounted
## Explicit bounded bug reproduction. No telemetry upload or earned-save access.
const Replay = preload("res://src/sim/replay/current_world_replay.gd")
var replay = Replay.new()
var recording := false
var notice := ""
var _world: SimWorld
var _previous_hash := ""


func start(world: SimWorld, offline: bool, continuous_overrides: bool) -> bool:
	if not offline or continuous_overrides:
		notice = "Replay needs offline play with continuous developer overrides off."
		return false
	var candidate = Replay.new()
	if not candidate.begin(world):
		notice = candidate.last_error
		return false
	replay = candidate
	_world = world
	_previous_hash = world.state_hash()
	recording = true
	notice = "Recording up to 60 seconds with diagnostic overhead. World changes or reset tools stop recording. Export from Developer tools."
	return true


func before_tick(world: SimWorld) -> void:
	if not recording: return
	if world != _world or world.state_hash() != _previous_hash:
		stop("Recording stopped before an out-of-tick world change; the preceding commands remain available to export.")


func after_tick(commands: Array[SimCommand], world: SimWorld) -> void:
	if not recording: return
	if world != _world or not replay.append_tick(commands, world):
		stop(replay.last_error)
		return
	_previous_hash = String(replay.frames[-1].hash)
	if replay.frames.size() >= Replay.MAX_FRAMES: stop("60-second replay ready to export.")


func stop(reason: String = "Recording stopped; the captured replay remains available to export.") -> void:
	if recording: notice = reason
	recording = false
	_world = null


func export_recording(folder: String = "user://diagnostics") -> Dictionary:
	stop()
	if replay.frames.is_empty(): return {"ok": false, "notice": "Record gameplay before exporting a replay."}
	var bytes: PackedByteArray = replay.encode()
	if bytes.is_empty(): return {"ok": false, "notice": "Replay exceeds the bounded export size; no file was written."}
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) != OK:
		return {"ok": false, "notice": "Could not create the local diagnostics folder."}
	var target := "%s/replay-%d-%d.hexreplay" % [folder, Time.get_unix_time_from_system(), Time.get_ticks_usec()]
	if FileAccess.file_exists(target): return {"ok": false, "notice": "Diagnostic filename already exists; retry export."}
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null: return {"ok": false, "notice": "Could not open the local diagnostic file."}
	file.store_buffer(bytes)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or FileAccess.get_file_as_bytes(target) != bytes:
		return {"ok": false, "notice": "Diagnostic export failed; the recording remains in memory.", "path": target}
	return {"ok": true, "notice": "Replay exported locally; deterministic verification has not run. " + ProjectSettings.globalize_path(target),
		"path": target, "bytes": bytes.size(), "sha256": FileAccess.get_sha256(target), "frames": replay.frames.size(), "verified": false}
