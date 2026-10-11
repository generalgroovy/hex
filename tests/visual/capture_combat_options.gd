extends "res://tests/visual/capture_unified_wellspring.gd"

# Native renderer acceptance for the seven revised pairs. All matter comes
# from two ordinary paid Bolt commands, never injected effect dictionaries.
const COMBAT_PAIRS := [
	["thermal-shock", "fire", "ice", 312],
	["plasma-arc", "fire", "charge", 313],
	["solar-flare", "fire", "light", 314],
	["superconduct", "ice", "charge", 328],
	["arcflash", "charge", "light", 332],
	["radiance", "light", "light", 334],
	["penumbra", "light", "dark", 335],
]
const TARGET := Vector2i(1504_000, 1344_000)


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.begins_with("res://.godot/combat-options-native-") or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("fresh native combat output required")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("cannot create combat output")
		return
	root.size = Vector2i(WIDTH, HEIGHT)
	game = BootstrapScene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.preference_overrides_are_transient = true
	game.preferences_persistence_allowed = false
	if game.element_audio != null: game.element_audio.set_process(false)
	for pair: Array in COMBAT_PAIRS:
		game.world = game._new_wellspring_world(120)
		game.authoritative_session.world = game.world
		var world: SimWorld = game.world
		var actor: PlayerState = world.player()
		game.champion_catalog.apply_to_player(actor, "oh_tipi")
		actor.reset_for_spawn(TARGET + Vector2i(0, 96_000))
		actor.spawn_protection_ticks = 0
		var payments: Array[Dictionary] = []
		for ordinal: int in 2:
			var wire := int(game.ability_catalog.ability(game.ability_catalog.spell_id_at(String(pair[ordinal + 1]), "bolt")).wire_id)
			if not actor.place_proven_spell(0, wire):
				_fail("could not equip paid combat Bolt")
				return
			var flux_before := actor.flux
			var matter_before := int(world.hex_court.metrics.matter_paid)
			if not world.step([SimCommand.new(world.tick, 1, 0, 0, 0, int(SimCommand.SPELL_PRESSED_BITS[0]), 0, -1000, TARGET.x, TARGET.y)]):
				_fail("paid combat command failed")
				return
			if actor.flux >= flux_before or int(world.hex_court.metrics.matter_paid) != matter_before + 600:
				_fail("combat command did not pay exactly one cast")
				return
			payments.append({"wire": wire, "accepted_tick": world.tick - 1, "flux_before": flux_before, "flux_after": actor.flux, "matter": 600})
			for unused: int in 300:
				if ordinal == 1 and not _product_for(int(pair[3])).is_empty(): break
				if ordinal == 0 and actor.pending_cast_wire_id == 0 and world.projectiles.is_empty(): break
				if not _neutral_step(): return
			if ordinal == 0:
				for unused: int in 36:
					if not _neutral_step(): return
		var product := _product_for(int(pair[3]))
		if product.is_empty() or int(product.quantity) != 1200 or product.source_ids.size() != 2 or product.source_ids[0] == product.source_ids[1] or not world.hex_court.conservation_valid():
			_fail("two real paid sources did not form a conserved combat pair")
			return
		if world.tick >= int(product.active_tick):
			_fail("capture missed the harmless formation window")
			return
		_sync()
		if not await _phase_frames(String(pair[0]), "formation"): return
		while world.tick <= int(product.active_tick):
			if not _neutral_step(): return
		if world.tick >= int(product.decay_tick):
			_fail("capture missed the active window")
			return
		if not await _phase_frames(String(pair[0]), "active"): return
		cases.append({"label": pair[0], "recipe_wire_id": pair[3], "paid_casts": payments, "product": HexChemistryWorld._stable(product), "selected_cells": _selected_cells(product, world.hex_court), "conservation_valid": world.hex_court.conservation_valid()})
		while world.tick <= int(product.decay_tick):
			if not _neutral_step(): return
		if not await _phase_frames(String(pair[0]), "decaying"): return
	if failed or frames.size() != 42 or cases.size() != 7:
		_fail("combat captures incomplete")
		return
	var sources := _source_manifest()
	for path: String in ["res://src/sim/hex/hex_product_effects.gd", "res://src/sim/movement/movement_tuning.gd", "res://tests/visual/capture_combat_options.gd"]:
		sources.append({"path": path, "sha256": FileAccess.get_sha256(path)})
	var file := FileAccess.open(output + "/receipt.json", FileAccess.WRITE)
	if file == null:
		_fail("cannot save combat receipt")
		return
	file.store_string(JSON.stringify({"status": "passed", "frames": frames, "cases": cases, "sources": sources, "runtime_identity": JSON.parse_string(FileAccess.get_file_as_string(RuntimeBuildIdentity.MANIFEST_PATH)), "scope": "seven revised reactions formed from fourteen paid Bolts, formation/active/decay normal/reduced native frames; no effect injection; not human balance, audio, multiplayer or performance acceptance"}, "\t") + "\n")
	file.close()
	print("PASS combat-options native frames=", frames.size(), " paid_casts=14")
	quit(0)


func _phase_frames(label: String, phase: String) -> bool:
	for reduced: bool in [false, true]:
		game.requested_capture_reduced_effects = reduced
		if (await _capture_frame(label + "-" + phase + ("-reduced" if reduced else "-normal"), "paid-combat-" + phase, reduced)).is_empty() or failed:
			return false
	return true
