extends SceneTree

const Bootstrap = preload("res://src/app/bootstrap.gd")
var output := ""
var game: Node
var assertions := 0
var failures: Array[String] = []
var records: Array[Dictionary] = []

class ReferenceCanvas extends Node2D:
	var renderer: SanctumCampusRenderer
	var layout: SanctumCampusLayout
	var focus := Vector2(-1000000, -1000000)
	func _draw() -> void:
		renderer.draw(self, layout, 0, focus, true)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
		push_error("Native backend and fresh absolute output directory required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	game = Bootstrap.new()
	game.preference_overrides_are_transient = true
	game.preferences_persistence_allowed = false
	root.add_child(game)
	await process_frame
	if not game.campus_renderer.prepare_overview():
		push_error("Station-reference overview must be prepared before any drawing")
		game.queue_free()
		quit(1)
		return
	game.set_process(false)
	if game.element_audio != null: game.element_audio.set_process(false)
	var current: SubViewport = game.pov_terrain_backdrop
	var legacy := _reference_viewport(Vector2(-1000000, -1000000))
	# Finite distant focus uses the ordinary existing live fade (zero titles),
	# independently of the new cache-only title exclusion argument.
	var far_live := _reference_viewport(Vector2(1000000, 1000000))
	await process_frame
	await RenderingServer.frame_post_draw
	var current_image := current.get_texture().get_image()
	var legacy_image := legacy.get_texture().get_image()
	var far_image := far_live.get_texture().get_image()
	_check(current_image.get_data() == far_image.get_data(), "cached terrain equals ordinary distant-live rendering without station titles")
	_check(current_image.get_data() != legacy_image.get_data(), "legacy sentinel cache visibly differs from corrected cache")
	for station: Dictionary in game.campus_layout.stations_by_id.values():
		var point := Vector2(station.position[0], station.position[1])
		var width := ThemeDB.fallback_font.get_string_size(String(station.title), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var crop := Rect2i(Vector2i(point + Vector2(-width / 2 - 7, 19)), Vector2i(ceili(width) + 14, 23))
		var before := legacy_image.get_region(crop)
		var after := current_image.get_region(crop)
		var changed := _changed(before, after)
		_check(changed > 16, "static title removed from cache for " + String(station.id))
		before.save_png(output.path_join(String(station.id) + "-cache-legacy.png"))
		after.save_png(output.path_join(String(station.id) + "-cache-current.png"))
		records.append({"station":station.id,"cache_changed_pixels":changed})
	# Positive control: ordinary live rendering must still draw a nearby title.
	var nearby_station: Dictionary = game.campus_layout.stations_by_id.values()[0]
	var nearby_point := Vector2(nearby_station.position[0], nearby_station.position[1])
	var near_live := _reference_viewport(nearby_point)
	await process_frame
	await RenderingServer.frame_post_draw
	var near_image := near_live.get_texture().get_image()
	var near_width := ThemeDB.fallback_font.get_string_size(String(nearby_station.title), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var near_crop := Rect2i(Vector2i(nearby_point + Vector2(-near_width / 2 - 7, 19)), Vector2i(ceili(near_width) + 14, 23))
	var near_title := near_image.get_region(near_crop)
	var near_blank := current_image.get_region(near_crop)
	var near_changed := _changed(near_title, near_blank)
	_check(near_changed > 16, "nearby live station title remains visible")
	near_title.save_png(output.path_join("nearby-live-title.png"))
	near_blank.save_png(output.path_join("nearby-cache-without-title.png"))
	records.append({"station":nearby_station.id,"nearby_live_title_pixels":near_changed})
	var actor: PlayerState = game._local_player_state()
	# Isolated starting placement only; this fixture changes no gameplay rule.
	actor.position_x = 496000
	actor.position_y = 1040000
	game.current_position = Vector2(496, 1040)
	game.previous_position = game.current_position
	game.accumulator_seconds = 0.0
	game._reset_motion_history()
	var authority: String = game.world.state_hash()
	for zoom: int in [50,75,100]:
		game.player_preferences.set_camera_zoom_percent(zoom)
		for reduced: bool in [false,true]:
			game.requested_capture_reduced_effects = reduced
			for old_cache: bool in [true,false]:
				game.pov_terrain_backdrop = legacy if old_cache else current
				game.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				var name := "range-%d-%s-%s.png" % [zoom,"reduced" if reduced else "normal","legacy" if old_cache else "current"]
				root.get_texture().get_image().save_png(output.path_join(name))
				_check(game.world.state_hash() == authority, "draw preserves authority: " + name)
	game.pov_terrain_backdrop = current
	legacy.queue_free()
	far_live.queue_free()
	near_live.queue_free()
	var receipt := {"status":"passed" if failures.is_empty() else "failed","assertions":assertions,"failures":failures,"stations":records,"gameplay_frames":12,"scope":"Native cache and isolated legacy-cache A/B, not historical build or paid movement proof. All other current draw code is identical.","runtime_identity":JSON.parse_string(FileAccess.get_file_as_string("res://content/runtime/runtime_build_identity_v1.json"))}
	var file := FileAccess.open(output.path_join("receipt.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt,"\t"))
	file.close()
	print("STATION_FOG_LABELS ",JSON.stringify(receipt))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _reference_viewport(focus: Vector2) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.size = game.campus_layout.canvas_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(viewport)
	var canvas := ReferenceCanvas.new()
	canvas.renderer = game.campus_renderer
	canvas.layout = game.campus_layout
	canvas.focus = focus
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(canvas)
	return viewport

func _changed(a: Image,b: Image) -> int:
	var count := 0
	for y: int in a.get_height():
		for x: int in a.get_width():
			if a.get_pixel(x,y) != b.get_pixel(x,y): count += 1
	return count

func _check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures.append(message)
