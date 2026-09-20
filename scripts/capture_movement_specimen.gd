extends SceneTree


# Bounded renderer acceptance fixture, not a simulation playthrough. Every
# sprite uses the same presenter, jump and landing samplers as live bootstrap.
const OUTPUT_ARGUMENT := "--movement-specimen-output="
const CHAMPIONS: Array[String] = ["s_wayne", "oh_tipi", "red_baron"]
const BODY_LABELS: Array[String] = ["SMALL / 58 px", "MIDDLE / 68 px", "LARGE / 76 px"]
const DIRECTIONS: Array[String] = ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
const PAGES: Array[String] = ["idle", "walk_a", "walk_b", "sprint_a", "sprint_b", "jump_opening", "jump_apex", "float", "float_released", "air_dodge", "dodge_expired", "slide", "roll", "air_turn", "wallrun", "wall_exit", "landing"]
const FRAME_SIZE := Vector2i(1280, 1024)

var sheet: MovementSheet


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var output := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(OUTPUT_ARGUMENT):
			output = argument.trim_prefix(OUTPUT_ARGUMENT)
	if not output.begins_with("res://.godot/visual-captures/") or ".." in output or DirAccess.dir_exists_absolute(output):
		push_error("Provide a new ignored --movement-specimen-output=res://.godot/visual-captures/name directory")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Cannot create movement specimen output")
		quit(1)
		return
	root.size = FRAME_SIZE
	root.content_scale_size = FRAME_SIZE
	sheet = MovementSheet.new()
	if not sheet.configure():
		push_error("Movement specimen could not load the live art contract")
		sheet.free()
		quit(1)
		return
	root.add_child(sheet)
	for reduced: bool in [false, true]:
		for page: String in PAGES:
			sheet.page = page
			sheet.reduced_effects = reduced
			sheet.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var rendered := root.get_texture().get_image()
			if rendered == null or rendered.is_empty() or rendered.get_size() != FRAME_SIZE:
				push_error("Movement specimen did not produce a real 1280x1024 viewport image")
				quit(1)
				return
			var filename := page + ("_reduced" if reduced else "")
			if rendered.save_png(output.path_join(filename + ".png")) != OK:
				push_error("Movement specimen frame could not be saved")
				quit(1)
				return
			print("RENDERED movement state fixture: %s (3 templates x 8 input directions)" % filename)
	print("PASS: %d actual renderer sheets, %d standard/reduced state-fixture cells; not a simulation or hand-drawn atlas replacement" % [PAGES.size() * 2, PAGES.size() * 2 * CHAMPIONS.size() * DIRECTIONS.size()])
	quit()


class MovementSheet:
	extends Node2D

	var language := VisualLanguage.new()
	var presenter := CartoonChampionPresenter.new()
	var config := SimConfig.new(120)
	var page := "idle"
	var reduced_effects := false
	var font: Font = ThemeDB.fallback_font


	func configure() -> bool:
		return language.load_from_file() and presenter.configure(language)


	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, FRAME_SIZE), Color("202b2b"))
		label(Vector2(28, 33), "FLUX / MOVEMENT CONTACT SHEET", 22, Color("ead9ad"))
		label(Vector2(28, 58), "Actual live renderer + authored transparent bodies | explicit state fixtures, not a playthrough", 15, Color("b3c2bc"))
		label(Vector2(28, 86), page.replace("_", " ").to_upper() + (" / REDUCED" if reduced_effects else " / STANDARD"), 20, Color("d7b36e"))
		for direction_index: int in range(8):
			label(Vector2(211 + direction_index * 140, 110), DIRECTIONS[direction_index], 16, Color("d9dbbd"))
		for row: int in range(3):
			var champion_id := CHAMPIONS[row]
			var ground_y := 360.0 + row * 290.0
			label(Vector2(24, ground_y - 62), BODY_LABELS[row], 15, Color("d9dbbd"))
			label(Vector2(24, ground_y - 40), champion_id, 13, Color("9aaea6"))
			for direction_index: int in range(8):
				var ground := Vector2(225.0 + direction_index * 140.0, ground_y)
				var state := fixture(page, EightDirectionResolver.FIXED_VECTORS[direction_index])
				var reduced := reduced_effects
				var jump := JumpPresentation.sample(state, config, 0.0, reduced)
				var landing := LandingPresentation.sample(state, config, 0.0, reduced)
				var visual_tick := phase_tick(champion_id, page)
				draw_rect(Rect2(ground - Vector2(65, 251), Vector2(130, 282)), Color("40504a"), false, 1.0)
				draw_set_transform(ground, 0.0, jump.shadow_scale)
				draw_circle(Vector2.ZERO, 19.0, Color(0.03, 0.06, 0.06, jump.shadow_opacity))
				draw_set_transform(Vector2.ZERO)
				LandingPresentation.draw(self, ground, landing, language)
				var wall := CartoonChampionPresenter.wall_contact_geometry(state)
				if not wall.is_empty():
					var wall_point := ground + (wall["offset"] as Vector2)
					var tangent := (wall["normal"] as Vector2).orthogonal()
					draw_line(wall_point - tangent * 33, wall_point + tangent * 33, Color("778378"), 2.0)
				presenter.draw(self, state, champion_id, ground - Vector2(0, jump.body_lift_pixels), visual_tick, config, reduced, ground)
				draw_line(ground - Vector2(4, 0), ground + Vector2(4, 0), Color("d7b36e"), 1.0)
				draw_line(ground - Vector2(0, 3), ground + Vector2(0, 3), Color("d7b36e"), 1.0)
				label(ground + Vector2(-52, 24), "%d px | %s" % [jump.body_lift_pixels, "protected" if jump.protection_active else "open"], 12, Color("b3c2bc"))
		label(Vector2(28, 1008), "Gold cross = fixed ground anchor. Physical height only; crisp A/B contacts. Brackets + shield mean protection NOW, never a fading memory.", 13, Color("b3c2bc"))


	func label(at: Vector2, value: String, size: int, color: Color) -> void:
		draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


	func phase_tick(champion_id: String, action: String) -> float:
		var motion_id := "walk" if action.begins_with("walk") else "sprint"
		var profile_id := String(presenter.recipe(champion_id)["motion_profile"])
		var duration := float((presenter.motion.profiles[profile_id][motion_id] as Dictionary)["duration_ticks"])
		return duration * (1.75 if action.ends_with("_b") else 1.25) - 3.0


	func fixture(action: String, direction: Vector2i) -> PlayerState:
		var state := PlayerState.new(1)
		state.facing_x = direction.x
		state.facing_y = direction.y
		state.aim_x = -direction.x
		state.aim_y = -direction.y
		state.velocity_x = direction.x * 300
		state.velocity_y = direction.y * 300
		if action.begins_with("walk"):
			state.movement_mode = PlayerState.MovementMode.WALK
		elif action.begins_with("sprint"):
			state.movement_mode = PlayerState.MovementMode.SPRINT
		elif action in ["jump_opening", "jump_apex", "float", "float_released", "air_dodge", "dodge_expired", "air_turn", "wall_exit"]:
			state.movement_mode = PlayerState.MovementMode.HOP
			state.hop_mode = PlayerState.MovementMode.HOP
			state.hop_ticks = config.milliseconds_to_ticks(MovementTuning.HOP_DURATION_MS) / 2
			state.air_height = 75_600
			if action == "jump_opening":
				state.air_height = 25_000
				state.air_vertical_velocity = 480_000
				state.hop_ticks = config.milliseconds_to_ticks(MovementTuning.HOP_DURATION_MS) - 5
				state.jump_sustain_ticks = 0
				state.jump_protection_ticks = config.milliseconds_to_ticks(MovementTuning.JUMP_INVULNERABILITY_MS) - 5
			elif action == "air_turn":
				state.velocity_x *= -1
				state.velocity_y *= -1
			elif action == "wall_exit":
				state.air_height = 35_000
				state.air_vertical_velocity = -150_000
			elif action in ["float", "float_released"]:
				state.air_height = 62_000
				state.air_floating = action == "float"
				state.air_vertical_velocity = 0 if state.air_floating else -100_000
				state.hop_stage = 2
				state.hop_mode = PlayerState.MovementMode.DOUBLE_JUMP
				state.movement_mode = PlayerState.MovementMode.DOUBLE_JUMP
			elif action in ["air_dodge", "dodge_expired"]:
				state.hop_mode = PlayerState.MovementMode.AIR_DODGE
				state.movement_mode = PlayerState.MovementMode.AIR_DODGE
				state.air_dodge_ticks = config.milliseconds_to_ticks(MovementTuning.AIR_DODGE_DURATION_MS) - 5 if action == "air_dodge" else 1
		elif action == "slide":
			state.movement_mode = PlayerState.MovementMode.SLIDE
			state.slide_ticks = 12
		elif action == "roll":
			state.movement_mode = PlayerState.MovementMode.ROLL
			state.hop_mode = PlayerState.MovementMode.ROLL
			state.air_dodge_ticks = config.milliseconds_to_ticks(MovementTuning.ROLL_DURATION_MS) - 5
		elif action == "wallrun":
			state.air_height = 35_000
			state.movement_mode = PlayerState.MovementMode.WALL_SKIM
			state.hop_mode = PlayerState.MovementMode.WALL_SKIM
			state.wall_skim_ticks = config.milliseconds_to_ticks(MovementTuning.WALL_SKIM_DURATION_MS) / 2
			state.wall_skim_surface_id = 7
			state.wall_x = 1000
			state.velocity_x = 0
			state.velocity_y = 300_000
		elif action.begins_with("landing"):
			state.movement_mode = PlayerState.MovementMode.IDLE
			state.landing_ticks = config.milliseconds_to_ticks(MovementTuning.LANDING_WINDOW_MS) * 3 / 4
			state.landing_intensity = 900
		else:
			state.velocity_x = 0
			state.velocity_y = 0
		return state
