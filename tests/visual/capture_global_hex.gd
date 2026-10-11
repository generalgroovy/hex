extends "res://tests/visual/capture_unified_wellspring.gd"

# Real paid inputs at the Nexus spawn, with no practice targets in the world.
func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.begins_with("res://.godot/global-hex-") or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("visible display and fresh contained output required")
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(WIDTH, HEIGHT)
	root.visible = true
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
	actor.reset_for_spawn(Vector2i(1_536_000, 880_000))
	actor.spawn_protection_ticks = 0
	for slot: int in 2:
		var element := "water" if slot == 0 else "fire"
		var wire := int(game.ability_catalog.ability(game.ability_catalog.spell_id_at(element, "bolt")).wire_id)
		if not actor.place_proven_spell(slot, wire):
			_fail("free-cast fixture could not equip legal Bolt")
			return
	_sync()
	if (await _capture_frame("01-before-free-casts", "before", false)).is_empty() or failed: return
	var target := Vector2i(1_431_000, 867_000)
	var steps := PackedInt64Array()
	for frame: int in 150:
		var pressed := int(SimCommand.SPELL_PRESSED_BITS[0]) if frame == 0 else int(SimCommand.SPELL_PRESSED_BITS[1]) if frame == 80 else 0
		var started := Time.get_ticks_usec()
		if not world.step([SimCommand.new(game.world.tick, 1, 0, 0, 0, pressed, -1000, -124, target.x, target.y)]):
			_fail("free cast step failed")
			return
		steps.append(Time.get_ticks_usec() - started)
		_sync()
		if frame == 65:
			if (await _capture_frame("02-water-away-from-dummy", "paid-water", false)).is_empty() or failed: return
	var authority: HexChemistryWorld = game.world.hex_court
	var product := _product_for(310)
	if product.is_empty() or int(authority.metrics.matter_paid) != 1200 or not authority.conservation_valid() or game.world.players.size() != 1:
		_fail("two paid target-free Bolts did not form conserved Steam")
		return
	game.requested_capture_reduced_effects = false
	if (await _capture_frame("03-steam-normal", "steam", false)).is_empty() or failed: return
	game.requested_capture_reduced_effects = true
	if (await _capture_frame("04-steam-reduced", "steam", true)).is_empty() or failed: return
	game.requested_capture_reduced_effects = false
	var before_exposure := int(authority.exposure.get(1, 0))
	var peak_exposure := before_exposure
	var crossing_trace: Array[Dictionary] = []
	for frame: int in 75:
		if not world.step([SimCommand.new(game.world.tick, 1, -1000, 0, 0, 0, -1000, 0)]):
			_fail("ordinary actor crossing failed")
			return
		_sync()
		var exposure := int(authority.exposure.get(1, 0))
		peak_exposure = maxi(peak_exposure, exposure)
		crossing_trace.append({"tick": world.tick, "x": actor.position_x, "y": actor.position_y, "exposure": exposure})
		if frame in [20, 40, 60]:
			if (await _capture_frame("05-crossing-%02d" % frame, "crossing", false)).is_empty() or failed: return
	# A narrower field can be fully crossed and its exposure decay to zero before
	# this fixed75-tick route ends. Prove actual entry, not a lingering penalty.
	if peak_exposure <= before_exposure:
		_fail("ordinary champion did not enter Steam")
		return
	if failed or frames.size() != 7:
		_fail("incomplete paid field capture")
		return
	steps.sort()
	var receipt := {
		"status": "passed", "runtime_identity": JSON.parse_string(FileAccess.get_file_as_string(RuntimeBuildIdentity.MANIFEST_PATH)),
		"scope": "Native normal Wellspring; real paid Water/Fire Bolts at Nexus spawn; no targets; actual movement into Steam; local only",
		"topology_cells": authority.cells.size(), "paid_material": authority.metrics.matter_paid,
		"product": HexChemistryWorld._stable(product), "exposure_after": authority.exposure.get(1, 0),
		"peak_exposure": peak_exposure, "crossing_trace": crossing_trace,
		"step_p95_us": steps[int(ceil(steps.size() * 0.95)) - 1], "frames": frames,
		"display": DisplayServer.get_name(), "sources": _source_manifest(),
	}
	var file := FileAccess.open(output + "/receipt.json", FileAccess.WRITE)
	if file == null:
		_fail("cannot save paid field receipt")
		return
	file.store_string(JSON.stringify(receipt, "\t") + "\n")
	file.close()
	print("PASS global-hex-native frames=", frames.size(), " cells=", authority.cells.size())
	quit(0)
