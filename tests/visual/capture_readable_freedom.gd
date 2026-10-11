extends "res://tests/visual/capture_unified_wellspring.gd"

# Controlled actor-state UI fixtures and a production projectile-renderer board.
# No physical-input, paid-cast, frame-rate or human acceptance claim is made.
class ProjectileBoard extends Node2D:
	var presenter := HexCourtPresenter.new()
	var rows: Array[Dictionary] = []
	var reduced := false
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 720), Color("26352c"))
		draw_string(ThemeDB.fallback_font, Vector2(24, 28), "H.E.X. PROJECTILE SPECIMEN / actual 75% scale / " + ("REDUCED" if reduced else "NORMAL"), HORIZONTAL_ALIGNMENT_LEFT, 1220, 18, Color("f0dfbc"))
		draw_string(ThemeDB.fallback_font, Vector2(24, 52), "Each family: full strength, then minimum surviving strength. Static frames test direction read, not gameplay.", HORIZONTAL_ALIGNMENT_LEFT, 1220, 13, Color("c8cfbd"))
		for index: int in rows.size():
			var entry: Dictionary = rows[index]
			var anchor := Vector2(85 + (index % 8) * 157, 116 + (index / 8) * 100)
			draw_set_transform(anchor, 0, Vector2.ONE * 0.75)
			presenter.draw_projectile(self, entry.shot, 0.0, 1.0, reduced)
			draw_set_transform(Vector2.ZERO)
			draw_string(ThemeDB.fallback_font, anchor + Vector2(-65, 33), entry.label, HORIZONTAL_ALIGNMENT_LEFT, 150, 11, Color("e4d4b5"))


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.begins_with("res://.godot/readable-freedom-native-") or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("fresh native readable-freedom output required")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("cannot create capture output")
		return
	root.size = Vector2i(WIDTH, HEIGHT)
	# A native-rendered SubViewport gives the fixture its own pointer without
	# moving the user's OS cursor or relying on the capture window owning focus.
	var stage := SubViewport.new()
	stage.size = Vector2i(WIDTH, HEIGHT)
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(stage)
	var screen := TextureRect.new()
	screen.texture = stage.get_texture()
	screen.size = Vector2(WIDTH, HEIGHT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(screen)
	game = BootstrapScene.instantiate()
	stage.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.preference_overrides_are_transient = true
	game.preferences_persistence_allowed = false
	if game.element_audio != null: game.element_audio.set_process(false)
	var bounds := Rect2i()
	for area: Dictionary in game.campus_layout.data.activity_areas:
		if String(area.id) == "south-movement-loop": bounds = SanctumCampusLayout._parse_bounds(area.bounds)
	if not bounds.has_area():
		_fail("actual movement area missing")
		return
	var anchor := (bounds.position + Vector2i(100, 100)) * 1000
	var actor: PlayerState = game.world.player()
	var views: Array[Dictionary] = []
	for fixture: String in ["air-affordable", "air-spent", "air-underfunded", "controller-spent", "crucible"]:
		actor.reset_for_spawn(anchor)
		actor.spawn_protection_ticks = 0
		actor.air_height = 20_000
		actor.hop_ticks = 30
		actor.double_jump_used = true
		game.movement_practice_device = ControlBindingEditor.DEVICE_KEYBOARD
		if fixture in ["air-spent", "controller-spent"]: actor.air_dodge_used = true
		if fixture == "air-underfunded": actor.stamina = 0
		if fixture == "controller-spent": game.movement_practice_device = ControlBindingEditor.DEVICE_CONTROLLER
		if fixture == "crucible":
			var group: Dictionary = game.campus_layout.practice_groups_by_id["crucible-experiment"]
			var point: Array = group.firing_anchors[0]
			actor.reset_for_spawn(Vector2i(int(point[0]), int(point[1])) * 1000)
		_sync()
		game.player_camera.clear()
		for unused: int in 240:
			game.player_camera.advance(game.current_position, Vector2.ZERO, Vector2.DOWN, 1.0 / 120.0, Vector2(WIDTH, HEIGHT), Rect2(0,0,3072,2304))
		for expanded: bool in [false, true]:
			# Processing is frozen for deterministic screenshots, so startup focus
			# rearm cannot tick down. Model an active, rearmed fixture explicitly.
			game.application_input_active = true
			game.controls_input_guard_frames = 0
			var pointer := Vector2(WIDTH - 220, 100) if expanded else Vector2(20, HEIGHT - 20)
			var event := InputEventMouseMotion.new()
			event.position = pointer
			event.global_position = pointer
			stage.push_input(event, true) # Viewport-local event, never OS cursor warping.
			# Pointer inspection must not change the controller-label fixture.
			game.movement_practice_device = ControlBindingEditor.DEVICE_CONTROLLER if fixture == "controller-spent" else ControlBindingEditor.DEVICE_KEYBOARD
			var view: Dictionary = game._chemistry_practice_view() if fixture == "crucible" else game._movement_practice_view()
			if view.is_empty() or bool(PracticeCoachCard.model(view, Vector2(WIDTH, HEIGHT), stage.get_mouse_position()).expanded) != expanded:
				_fail("practice fixture failed: %s expanded=%s view=%s pointer=%s blocked=%s" % [fixture, expanded, view, stage.get_mouse_position(), game._gameplay_input_blocked()])
				return
			var label := fixture + ("-expanded" if expanded else "-compact")
			if (await _capture_frame(label, "controlled-practice-state", false)).is_empty() or failed: return
			if game._gameplay_input_blocked():
				_fail("practice fixture lost admission during rendering")
				return
			views.append({"label":label, "view":view, "expanded":expanded})
	game.visible = false
	var board := ProjectileBoard.new()
	if not board.presenter.configure(game.visual_language):
		_fail("production projectile presenter unavailable")
		return
	var entity_id := 1
	for family: String in ["rapid", "bolt", "heavy"]:
		for weakened: bool in [false, true]:
			for element: String in ["water", "earth", "fire", "wind", "ice", "charge", "light", "dark"]:
				var ability: Dictionary = game.ability_catalog.ability(game.ability_catalog.spell_id_at(element, family))
				var cast: Dictionary = CombatTuning.cast_definition(int(ability.wire_id))
				var angle := deg_to_rad(float((entity_id % 8) * 45) + 22.5)
				var direction := Vector2.RIGHT.rotated(angle)
				var shot := ProjectileState.new(entity_id, 1, 1, int(ability.wire_id), int(cast.element_wire_id), Vector2i.ZERO, Vector2i(direction * int(cast.speed)), int(cast.radius), int(cast.damage), 120)
				shot.source_cast_id = entity_id
				shot.initial_strength = int(cast.reaction_strength)
				shot.remaining_strength = 1 if weakened else shot.initial_strength
				shot.reaction_strength = shot.remaining_strength
				board.rows.append({"shot":shot, "label":"%s %s %d/%d" % ["Air" if element == "wind" else element.capitalize(), family, shot.remaining_strength, shot.initial_strength]})
				entity_id += 1
	root.add_child(board)
	for reduced: bool in [false, true]:
		board.reduced = reduced
		board.queue_redraw()
		if (await _capture_frame("projectiles-" + ("reduced" if reduced else "normal"), "production-renderer-controlled-specimen", reduced)).is_empty() or failed: return
	if frames.size() != 12 or views.size() != 10 or board.rows.size() != 48:
		_fail("incomplete practice or projectile specimens")
		return
	var file := FileAccess.open(output + "/receipt.json", FileAccess.WRITE)
	if file == null:
		_fail("cannot write capture receipt")
		return
	file.store_string(JSON.stringify({"status":"passed", "scope":"controlled actor-state native practice cards and actual 75%-scale production projectile specimens; not paid simulation, physical input, performance or human acceptance", "runtime_identity":JSON.parse_string(FileAccess.get_file_as_string(RuntimeBuildIdentity.MANIFEST_PATH)), "frames":frames, "views":views}, "\t") + "\n")
	file.close()
	print("PASS readable-freedom native frames=", frames.size())
	quit(0)
