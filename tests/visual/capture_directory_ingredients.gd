extends "res://tests/visual/capture_unified_wellspring.gd"

# One real paid Bolt per fresh world: native material identity, not a damage test.
func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.begins_with("res://.godot/directory-ingredients-") or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("fresh native ingredient output required")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("cannot create output")
		return
	root.size = Vector2i(WIDTH,HEIGHT)
	game = BootstrapScene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.preference_overrides_are_transient = true
	game.preferences_persistence_allowed = false
	if game.element_audio != null: game.element_audio.set_process(false)
	for element: String in AbilityCatalog.DISPLAY_ELEMENT_IDS:
		game.world = game._new_wellspring_world(120)
		game.authoritative_session.world = game.world
		var world: SimWorld = game.world
		var actor: PlayerState = world.player()
		game.champion_catalog.apply_to_player(actor,"oh_tipi")
		actor.reset_for_spawn(Vector2i(1536_000,880_000))
		actor.spawn_protection_ticks = 0
		var wire := int(game.ability_catalog.ability(game.ability_catalog.spell_id_at(element,"bolt")).wire_id)
		if not actor.place_proven_spell(0,wire):
			_fail("could not equip paid ingredient Bolt")
			return
		for tick: int in 66:
			var pressed := int(SimCommand.SPELL_PRESSED_BITS[0]) if tick == 0 else 0
			if not world.step([SimCommand.new(world.tick,1,0,0,0,pressed,-1000,-124,1431_000,867_000)]):
				_fail("paid ingredient step failed")
				return
		var authority: HexChemistryWorld = game.world.hex_court
		var ground := 0
		for cast: Dictionary in authority.casts.values(): ground += int(cast.ground)
		if int(authority.metrics.matter_paid) != 600 or ground <= 0 or not authority.conservation_valid():
			_fail("ingredient did not produce conserved paid ground: "+element)
			return
		_sync()
		for reduced: bool in [false,true]:
			game.requested_capture_reduced_effects = reduced
			if (await _capture_frame(element+"-reduced" if reduced else element+"-normal","paid-ingredient",reduced)).is_empty() or failed: return
	if failed or frames.size() != 16:
		_fail("incomplete ingredient capture")
		return
	var file := FileAccess.open(output+"/receipt.json",FileAccess.WRITE)
	if file == null:
		_fail("cannot save ingredient receipt")
		return
	file.store_string(JSON.stringify({"status":"passed","frames":frames,"paid_casts":8,"runtime_identity":JSON.parse_string(FileAccess.get_file_as_string(RuntimeBuildIdentity.MANIFEST_PATH)),"scope":"eight single paid Bolt deposits, normal/reduced native render; no injected effect state; not damage/phase/dense-scene/human acceptance"},"\t")+"\n")
	file.close()
	print("PASS directory-ingredients frames=",frames.size())
	quit(0)
