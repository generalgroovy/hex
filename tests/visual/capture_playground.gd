extends "res://tests/visual/capture_unified_wellspring.gd"

# Native production views of the three new rooms, not an illustrated mockup.
func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.begins_with("res://.godot/playground-native-") or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("visible display and fresh playground output required")
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(WIDTH, HEIGHT)
	game = BootstrapScene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.preference_overrides_are_transient = true
	game.preferences_persistence_allowed = false
	if game.element_audio != null: game.element_audio.set_process(false)
	game.world = game._new_wellspring_world(120)
	game.authoritative_session.world = game.world
	var world: SimWorld = game.world
	var actor: PlayerState = game.world.player()
	game.champion_catalog.apply_to_player(actor, "oh_tipi")
	for room: Dictionary in [
		{"name":"chain-courtyard", "point":Vector2i(1432_000,1840_000)},
		{"name":"cover-garden", "point":Vector2i(2544_000,1840_000)},
		{"name":"open-laboratory", "point":Vector2i(2000_000,1840_000)},
	]:
		actor.reset_for_spawn(room.point)
		actor.spawn_protection_ticks = 0
		for step: int in 24:
			if not world.step([SimCommand.new(world.tick, 1, 1000, 0, 0, 0, 0, 1000)]):
				_fail("playground ordinary movement failed")
				return
			_sync()
		await _capture_frame(String(room.name), "ordinary-walk", false)
	if failed: return
	var receipt := {"status":"passed", "map_hash":game.campus_layout.content_hash, "frames":frames,
		"scope":"three native production room views after 24 ordinary movement ticks each; not a human feel or performance gate"}
	var file := FileAccess.open(output + "/receipt.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt,"\t") + "\n")
	file.close()
	print("PASS playground-native frames=", frames.size())
	quit(0)
