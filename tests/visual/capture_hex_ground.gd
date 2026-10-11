extends "res://tests/visual/capture_unified_wellspring.gd"

# Native production views, not a painted mockup. All matter below comes from
# one real paid Heavy cast per room. No physical play, FPS or human acceptance.
const GROUND_SOURCES := [
	"res://src/presentation/hex_environment_layout.gd",
	"res://src/presentation/wellspring_illustrated_kit.gd",
	"res://assets/environment/wellspring_v3/surfaces.png",
	"res://content/maps/sanctum_campus_g2_v1.json",
	"res://tests/visual/capture_hex_ground.gd",
]
const ROOMS := [
	{"id": "commons", "spawn": Vector2i(1536_000, 960_000), "element": "fire"},
	{"id": "chemistry", "spawn": Vector2i(1504_000, 1440_000), "element": "water"},
	{"id": "movement", "spawn": Vector2i(544_000, 672_000), "element": "charge"},
]
var source_hashes := {}


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=").replace("\\", "/")
	var valid_output := output.begins_with("res://.godot/hex-ground-native-") or output.is_absolute_path()
	if DisplayServer.get_name() == "headless" or not valid_output or ".." in output or DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output):
		_fail("Native display and a fresh absolute or res://.godot/hex-ground-native-NAME output are required")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("Could not create native ground evidence directory")
		return
	for path: String in GROUND_SOURCES: source_hashes[path] = FileAccess.get_sha256(path)
	root.size = Vector2i(WIDTH, HEIGHT)
	root.visible = true
	root.title = "H.E.X. / continuous authored ground"
	game = BootstrapScene.instantiate()
	game.preference_overrides_are_transient = true
	game.preferences_persistence_allowed = false
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	if game.element_audio != null:
		game.element_audio.set_process(false)
		game.element_audio.volume_percent = 0
	game.show_debug_overlay = false
	game.hex_playground_open = false
	game.player_preferences.set_camera_zoom_percent(75)
	for room: Dictionary in ROOMS:
		if not await _capture_room(room): return
	for path: String in GROUND_SOURCES:
		if source_hashes[path] != FileAccess.get_sha256(path):
			_fail("Ground evidence source changed during capture: " + path)
			return
	if frames.size() != ROOMS.size() * 4 or cases.size() != ROOMS.size():
		_fail("Ground evidence matrix is incomplete")
		return
	var kit: WellspringIllustratedKit = game.campus_renderer.illustrated_kit
	var file := FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE)
	if file == null:
		_fail("Could not write native ground receipt")
		return
	file.store_string(JSON.stringify({"status": "passed", "sources": source_hashes, "frames": frames, "cases": cases,
		"map_hash": game.campus_layout.content_hash, "ground_hash": kit.content_hash,
		"setup_ms": kit.ground_generation_ms, "cached_builds": kit.cached_terrain_builds,
		"authored_bytes": kit.hex_terrain.authored_tile_bytes, "stamp_bytes": kit.hex_terrain.stamp_bytes,
		"native_copy_count": kit.hex_terrain.authored_copy_count,
		"scope": "Three native production districts at75percent camera; quiet and paid Heavy impact matter, normal/reduced frozen at identical ticks; no injected deposits, field geometry or projectile records. Scenario actors are controlled setup. No physical input, human visual acceptance, multiplayer or FPS/performance acceptance."}, "\t") + "\n")
	file.close()
	print("PASS hex-ground native:3 districts,3 paid Heavy casts,12 frozen normal/reduced production frames")
	quit(0)


func _capture_room(room: Dictionary) -> bool:
	game.world = game._new_wellspring_world(120)
	if game.world == null:
		_fail("Production ground world is unavailable")
		return false
	game.authoritative_session.world = game.world
	game.combat_cues.clear()
	game.station_notice_seconds = 0.0
	var world: SimWorld = game.world
	var actor: PlayerState = world.player()
	var spawn: Vector2i = room.spawn
	var target_point := spawn + Vector2i(0, -96_000)
	if not game.champion_catalog.apply_to_player(actor, "oh_tipi"):
		_fail("Production cast actor unavailable")
		return false
	game.selected_champion_id = "oh_tipi"
	actor.reset_for_spawn(spawn)
	actor.spawn_protection_ticks = 0
	actor.aim_x = 0
	actor.aim_y = -1000
	var target := PlayerState.new(2)
	if not game.champion_catalog.apply_to_player(target, "s_wayne"):
		_fail("Production target actor unavailable")
		return false
	target.reset_for_spawn(target_point)
	target.spawn_protection_ticks = 0
	target.team_id = actor.team_id + 1
	world.players.append(target)
	if not world.collision.can_occupy(spawn, MovementTuning.PLAYER_RADIUS) or not world.collision.can_occupy(target_point, MovementTuning.PLAYER_RADIUS):
		_fail("Ground comparison actors no longer fit existing " + String(room.id) + " geometry")
		return false
	var ability: Dictionary = game.ability_catalog.ability(game.ability_catalog.spell_id_at(String(room.element), "heavy"))
	var wire := int(ability.get("wire_id", 0))
	var cast := CombatTuning.cast_definition(wire)
	if not actor.place_proven_spell(0, wire) or String(cast.get("family", "")) != "heavy":
		_fail("Production paid Heavy is unavailable")
		return false
	_sync()
	game.player_camera.clear()
	for _unused: int in 120:
		game.player_camera.advance(game.current_position, Vector2.ZERO, Vector2.UP, 1.0 / 120.0, Vector2(WIDTH, HEIGHT), Rect2(Vector2.ZERO, Vector2(game.campus_layout.canvas_size)))
	if not await _paired_room_frames(String(room.id) + "-quiet", "ordinary-static-campus"): return false
	var start_flux := actor.flux
	var paid_flux := 0
	var hit_tick := -1
	var initial_health := target.health
	for step: int in 180:
		var command := SimCommand.new(world.tick, 1, 0, 0, 0, int(SimCommand.SPELL_PRESSED_BITS[0]) if step == 0 else 0, 0, -1000, target_point.x, target_point.y)
		if not world.step([command]) or not world.hex_court.conservation_valid():
			_fail("Paid ground comparison step/conservation failed")
			return false
		if step == 0:
			paid_flux = start_flux - actor.flux
			if paid_flux != int(cast.flux_cost) or int(world.hex_court.metrics.get("matter_paid", 0)) != MATTER_PER_CAST:
				_fail("Ground comparison did not pay the exact Heavy Flux/matter cost")
				return false
		for event: Dictionary in world.combat_events:
			if String(event.get("type", "")) == "projectile_hit" and int(event.get("target_id", 0)) == 2: hit_tick = world.tick
		_sync()
		if hit_tick >= 0 and world.tick >= hit_tick + 18: break
	if hit_tick < 0 or target.health >= initial_health or world.hex_court.occupied_cells().is_empty() or not world.projectiles.is_empty():
		_fail("Ground comparison has no completed paid contact and occupied matter")
		return false
	if not await _paired_room_frames(String(room.id) + "-paid-" + String(room.element), "paid-heavy-contact-matter"): return false
	cases.append({"room": room.id, "element": room.element, "wire": wire, "tick": world.tick,
		"flux_paid": paid_flux, "matter_paid": int(world.hex_court.metrics.get("matter_paid", 0)),
		"hit_tick": hit_tick, "target_health_before": initial_health, "target_health_after": target.health,
		"occupied_cells": world.hex_court.occupied_cells().size(), "conservation_valid": true, "world_hash": world.state_hash()})
	return true


func _paired_room_frames(label: String, kind: String) -> bool:
	var before: String = game.world.state_hash()
	for reduced: bool in [false, true]:
		game.requested_capture_reduced_effects = reduced
		if (await _capture_frame(label + ("-reduced" if reduced else "-normal"), kind, reduced)).is_empty(): return false
	if game.world.state_hash() != before:
		_fail("Normal/reduced ground draw changed simulation authority")
		return false
	game.requested_capture_reduced_effects = false
	return true
