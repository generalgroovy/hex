extends FluxTestSuite
const Session = preload("res://src/app/diagnostic_replay_session.gd")


func run() -> int:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "diagnostic replay catalog")
	var world := SimWorld.new()
	check(HexCourtPractice.configure(world, abilities), "diagnostic uses actual paid practice")
	var session := Session.new()
	check(not session.start(world, false, false), "network replay recording is not silently partial")
	check(not session.start(world, true, true), "continuous overrides cannot pretend to be command-only recording")
	check(not bool(session.export_recording().ok), "empty recording cannot export")
	check(session.start(world, true, false), "explicit local recording begins")
	for tick: int in 90:
		session.before_tick(world)
		var commands: Array[SimCommand] = [SimCommand.new(tick, 1, 0, 0, 0, SimCommand.PRESSED_SPELL_2 if tick == 1 else 0, 0, -1000)]
		check(world.step(commands), "ordinary paid command advances")
		session.after_tick(commands, world)
	check(session.recording, "ordinary authority does not stop valid recording")
	check(bool(session.replay.verify(world).ok), "collected live command recording verifies")
	world.player().flux = world.player().flux_maximum
	session.before_tick(world)
	check(not session.recording, "external refill ends recording before a false reproducibility claim")
	equal(session.replay.frames.size(), 90, "out-of-tick mutation preserves preceding recorded ticks")
	var folder := "user://diagnostic-replay-test-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var export: Dictionary = session.export_recording(folder)
	check(bool(export.ok) and not bool(export.verified), "export distinguishes captured bytes from a verification receipt")
	check(FileAccess.file_exists(String(export.get("path", ""))), "explicit export writes actual bounded local bytes")
	equal(FileAccess.get_file_as_bytes(String(export.get("path", ""))), session.replay.encode(), "export readback matches recording")
	var second: Dictionary = session.export_recording(folder)
	check(bool(second.ok) and String(second.path) != String(export.path), "second export cannot overwrite an earlier report")
	for name: String in DirAccess.open(folder).get_files(): DirAccess.remove_absolute(ProjectSettings.globalize_path(folder + "/" + name))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
	return finish("diagnostic-replay")
