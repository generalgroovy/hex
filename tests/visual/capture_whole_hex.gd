extends "res://tests/visual/capture_hex_court.gd"


# Focused before/after evidence for whole selected-hex coverage. The paid Fire
# Bolt lands on the closed face shared by (0, 0) and (1, 0). The actor then
# walks through that face and beyond the old 34 px analytic disk while its foot
# remains in the second authoritative record.cells hex.
const FIRE_SLOT := 2
const FIRE_WIRE := 145
const FIRST_CELL := Vector2i(0, 0)
const SECOND_CELL := Vector2i(1, 0)
const FACE_TARGET := HexCourt.ORIGIN + Vector2i(HexGrid.HALF_WIDTH, 0)
const WALK_START := HexCourt.ORIGIN
const WALK_TICKS := 48

var walk_trace: Array[Dictionary] = []
var frame_evidence: Array[Dictionary] = []
var pulse_holds: Array[Dictionary] = []
var fire_cast_id := 0
var fire_record: Dictionary = {}


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if not output.begins_with("res://.godot/whole-hex-") or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("whole-hex capture requires a fresh res://.godot/whole-hex-* output")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("whole-hex capture output could not be created")
		return
	game = Harness.new()
	if not game.configure_fixture(true):
		_fail("production Harness fixture failed")
		return
	game.material_registry = MaterialRegistry.new()
	game.material_yard = MaterialYardDefinition.new()
	if not game.material_registry.load_from_file(game.MATERIAL_CATALOG_PATH) \
		or not game.material_yard.load_from_file(game.MATERIAL_YARD_PATH, game.material_registry):
		_fail("court return content failed")
		return
	game.player_preferences.set_camera_zoom_percent(100)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(game)
	if not _reset():
		return
	# Remove the ordinary center training target so the Bolt reaches the exact
	# off-center ground target through normal projectile collision/terminal code.
	game.world.players.resize(1)
	if not _cast(FIRE_SLOT, FACE_TARGET) or not _terminal():
		return
	fire_record = _latest_fire_record()
	if fire_record.is_empty() or int(fire_record.get("wire", 0)) != FIRE_WIRE:
		_fail("paid off-center Fire Bolt did not leave its authoritative ground record")
		return
	fire_cast_id = int(fire_record.id)
	if not fire_record.cells.has(FIRST_CELL) or not fire_record.cells.has(SECOND_CELL):
		_fail("off-center Fire Bolt must select both hexes adjacent to the shared face")
		return
	while HexCourt._fire_phase(fire_record, game.world.tick) != "active":
		_step()
		if game.world.tick >= int(fire_record.expires):
			_fail("Fire expired before the focused walk")
			return
	var actor: PlayerState = game.world.player()
	actor.reset_for_spawn(WALK_START)
	actor.spawn_protection_ticks = 0
	actor.health_maximum = 120_000
	actor.health = actor.health_maximum
	actor.health_recovery_per_second = 0
	_sync()
	_record_walk_step("start")
	if not await _capture_pair("start-first-cell", "first_selected_hex_center"):
		return
	var captured_crossing := false
	var captured_outside_disk := false
	var captured_outer_exit := false
	for _index: int in range(WALK_TICKS):
		_step(1000, 0)
		_record_walk_step("walk")
		var sample: Dictionary = walk_trace.back()
		var sampled_foot: Array = sample.foot_cell
		if not captured_crossing and Vector2i(int(sampled_foot[0]), int(sampled_foot[1])) == SECOND_CELL:
			captured_crossing = true
			if not await _capture_pair("crossed-shared-face", "second_selected_hex_entry"):
				return
		if not captured_outside_disk and bool(sample.selected_cell) and not bool(sample.inside_old_analytic_footprint):
			captured_outside_disk = true
			_hold_through_next_pulse("outside_old_disk_inside_selected")
			if not await _capture_pair("outside-old-disk", "second_selected_hex_beyond_old_disk_after_stationary_pulse"):
				return
		elif captured_outside_disk and not captured_outer_exit and not bool(sample.selected_cell):
			captured_outer_exit = true
			_hold_through_next_pulse("outside_selected_hex")
			if not await _capture_pair("outside-selected-hex", "outer_selected_hex_exit_after_stationary_pulse"):
				return
	if not captured_crossing or not captured_outside_disk or not captured_outer_exit:
		_fail("bounded walk did not cross the shared face, leave the old disk inside the selected hex, and leave the selected hex")
		return
	# Additional AFTER views exercise the other implemented layers through real paid casts.
	if "after-" in output:
		for entry: Array in [["water", [1]], ["steam", [1, 2]], ["flood", [1, 1]], ["conflagration", [2, 2]]]:
			if not _reset(): return
			game.world.players.resize(1)
			for slot: int in entry[1]:
				if not _cast(slot, FACE_TARGET) or not _terminal(): return
			_advance(30)
			game.player_preferences.reduced_motion = false
			await _capture(String(entry[0]) + "-whole-normal")
			game.player_preferences.reduced_motion = true
			await _capture(String(entry[0]) + "-whole-reduced")
		game.player_preferences.reduced_motion = false
	var receipt := FileAccess.open(output.path_join("capture-receipt.json"), FileAccess.WRITE)
	if receipt == null:
		_fail("whole-hex receipt could not be written")
		return
	receipt.store_string(JSON.stringify({
		"schema_version": 1,
		"status": "passed",
		"scope": "actual paid off-center Fire Bolt; same actor continuously walks across its selected-hex boundary; normal/reduced frames; canonical foot cell and Health recorded every step",
		"authority": "production Harness, SimCommand payment/release/projectile/terminal/movement; no field, projectile, ledger, exposure, or damage injection",
		"fire_cast_id": fire_cast_id,
		"fire_record": HexCourt._stable(fire_record),
		"face_target": [FACE_TARGET.x, FACE_TARGET.y],
		"selected_cells": _selected_cells(fire_record),
		"walk_trace": walk_trace,
		"pulse_holds": pulse_holds,
		"frames": frame_evidence,
		"additional_material_frames": records,
		"draw_authority_unchanged": true,
		"network": "not_started",
		"audio": "not_started",
		"human_acceptance": "not_run",
		"rendered_performance": "not_measured_capture_pauses",
	}, "  "))
	receipt.close()
	print("PASS: whole selected-hex before/after capture; %d step samples; %d normal/reduced frames" % [walk_trace.size(), frame_evidence.size()])
	game.queue_free()
	await process_frame
	quit(0)


func _latest_fire_record() -> Dictionary:
	var ids: Array = game.world.hex_court.casts.keys()
	ids.sort()
	ids.reverse()
	for id: int in ids:
		var record: Dictionary = game.world.hex_court.casts[id]
		if int(record.get("wire", 0)) == FIRE_WIRE and int(record.get("ground", 0)) > 0:
			return record
	return {}


func _record_walk_step(kind: String) -> void:
	var actor: PlayerState = game.world.player()
	var point := Vector2i(actor.position_x, actor.position_y)
	var local := point - HexCourt.ORIGIN
	var foot_cell := HexGrid.world_to_cell(local)
	walk_trace.append({
		"kind": kind,
		"tick": game.world.tick,
		"position": [point.x, point.y],
		"local_position": [local.x, local.y],
		"foot_cell": [foot_cell.x, foot_cell.y],
		"health": actor.health,
		"selected_cell": fire_record.cells.has(foot_cell),
		"inside_old_analytic_footprint": HexFootprint.contains(fire_record.footprint, point),
		"fire_phase": HexCourt._fire_phase(fire_record, game.world.tick),
		"exposure": int(game.world.hex_court.exposure.get(actor.entity_id, 0)),
	})


func _hold_through_next_pulse(kind: String) -> void:
	var actor: PlayerState = game.world.player()
	var health_before := actor.health
	var start_tick: int = game.world.tick
	var ticks_to_pulse := HexCourt.PULSE_TICKS - posmod(game.world.tick, HexCourt.PULSE_TICKS)
	if ticks_to_pulse <= 0:
		ticks_to_pulse = HexCourt.PULSE_TICKS
	for _index: int in range(ticks_to_pulse + 1):
		_step()
		_record_walk_step(kind)
	pulse_holds.append({
		"kind": kind,
		"start_tick": start_tick,
		"end_tick": game.world.tick,
		"health_before": health_before,
		"health_after": actor.health,
		"health_delta": actor.health - health_before,
	})


func _capture_pair(label: String, kind: String) -> bool:
	for reduced: bool in [false, true]:
		game.player_preferences.reduced_motion = reduced
		var before: String = game.world.state_hash()
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var suffix := "-reduced" if reduced else "-normal"
		var file_name := label + suffix + ".png"
		var frame := viewport.get_texture().get_image()
		if frame == null or frame.is_empty() or frame.save_png(output.path_join(file_name)) != OK or game.world.state_hash() != before:
			_fail("whole-hex frame failed or mutated authority: " + file_name)
			return false
		var actor: PlayerState = game.world.player()
		var point := Vector2i(actor.position_x, actor.position_y)
		var foot := HexGrid.world_to_cell(point - HexCourt.ORIGIN)
		frame_evidence.append({
			"file": file_name,
			"kind": kind,
			"reduced_effects": reduced,
			"tick": game.world.tick,
			"world_hash": before,
			"position": [point.x, point.y],
			"foot_cell": [foot.x, foot.y],
			"health": actor.health,
			"selected_cell": fire_record.cells.has(foot),
			"inside_old_analytic_footprint": HexFootprint.contains(fire_record.footprint, point),
		})
	game.player_preferences.reduced_motion = false
	return true


func _selected_cells(record: Dictionary) -> Array[Array]:
	var selected: Array[Vector2i] = []
	for value: Variant in record.cells.keys():
		if value is Vector2i:
			selected.append(value)
	selected.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	var result: Array[Array] = []
	for cell: Vector2i in selected:
		result.append([cell.x, cell.y])
	return result
