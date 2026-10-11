extends "res://tests/visual/capture_unified_wellspring.gd"

# Isolate APPDATA in the supervising shell. These are production movement inputs,
# not injected animation states; native keyframes do not establish human feel.
const BodyArt = preload("res://src/presentation/fullbody_cast_presenter.gd")

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.begins_with("res://.godot/retro-motion-") or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("fresh native motion output required")
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(WIDTH,HEIGHT)
	game = BootstrapScene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.preference_overrides_are_transient = true
	game.preferences_persistence_allowed = false
	if game.element_audio != null: game.element_audio.set_process(false)
	var world: SimWorld = game.world
	if world == null:
		_fail("motion world did not boot")
		return
	var actor := world.player()
	var index := 0
	for champion: String in ["s_wayne","oh_tipi","red_baron"]:
		game.champion_catalog.apply_to_player(actor,champion)
		actor.reset_for_spawn(Vector2i(1536_000,880_000))
		actor.spawn_protection_ticks = 0
		var aim := EightDirectionResolver.fixed_vector(["south_east","north","north_west"][index])
		var seen := {}
		for tick: int in 360:
			var held := SimCommand.HELD_JUMP if tick>=4 and tick<30 else 0
			var pressed := SimCommand.PRESSED_JUMP if tick==4 else 0
			if not world.step([SimCommand.new(world.tick,actor.entity_id,0,0,held,pressed,aim.x,aim.y)]):
				_fail("motion input failed")
				return
			_sync()
			game.station_notice_seconds = 0.0
			var action := BodyArt.action_for_state(actor)
			if action == "jumpsquat" and actor.jumpsquat_ticks < 16: continue
			if action not in ["idle","jumpsquat","jump","land"] or seen.has(action): continue
			seen[action] = true
			if (await _capture_frame(champion+"-"+action,"production-jump-cycle",false)).is_empty() or failed: return
			if action == "land":
				game.requested_capture_reduced_effects = true
				if (await _capture_frame(champion+"-land-reduced","production-jump-cycle",true)).is_empty() or failed: return
				game.requested_capture_reduced_effects = false
			if seen.size() == 4: break
		if seen.size() != 4:
			_fail("missing paid movement phase for "+champion+": "+str(seen))
			return
		index += 1
	if failed or frames.size() != 15:
		_fail("incomplete motion capture")
		return
	var file := FileAccess.open(output+"/receipt.json",FileAccess.WRITE)
	if file == null:
		_fail("cannot save motion receipt")
		return
	file.store_string(JSON.stringify({"status":"passed","frames":frames,"scope":"three sizes, real jumpsquat/release/jump/landing inputs, normal and reduced landing; native keyframes only"},"\t")+"\n")
	file.close()
	print("PASS retro-motion frames=",frames.size())
	quit(0)
