extends SceneTree

# Actual live presenters in an offscreen acceptance fixture; not a playthrough.
const SIZE := Vector2i(1280, 900)

func _initialize() -> void:
	root.hide()
	_run.call_deferred()

func _run() -> void:
	var output := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if not output.begins_with("res://.godot/diagnostics/readability-") or ".." in output or DirAccess.dir_exists_absolute(output):
		push_error("Provide a new --output=res://.godot/diagnostics/readability-NAME")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sheet := ReadabilitySheet.new()
	if not sheet.configure() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Cannot configure live readability fixture")
		sheet.free()
		quit(1)
		return
	viewport.add_child(sheet)
	for age: int in [0, 4, 8, 12]:
		sheet.age = age
		sheet.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var rendered := viewport.get_texture().get_image()
		if rendered == null or rendered.get_size() != SIZE or rendered.save_png(output.path_join("readability_%02d.png" % age)) != OK:
			push_error("Readability fixture did not save a real rendered image")
			quit(1)
			return
	print("PASS: 4 actual1280x900 frames; eight flight materials, three Float bodies, normal/reduced concealment windows")
	quit(0)

class ReadabilitySheet:
	extends Node2D
	var language := VisualLanguage.new()
	var pixels := PixelSpellEffects.new()
	var champion := CartoonChampionPresenter.new()
	var chemistry := ElementChemistryPresenter.new()
	var config := SimConfig.new(120)
	var age := 0
	var reactions: Array[ElementReactionState] = []
	var font: Font = ThemeDB.fallback_font
	const Chemistry = preload("res://src/sim/chemistry/element_chemistry_system.gd")

	func configure() -> bool:
		if not language.load_from_file() or not champion.configure(language) or not chemistry.configure(language) or not pixels.ready():
			return false
		for wire: int in [310, 326]:
			var recipe := Chemistry.recipe(wire)
			var deposits: Array = []
			for index: int in range(2):
				Chemistry.deposit_terminal(deposits, 3000 + index, 1000 + index, 100, 1, 1, recipe.elements[index], Vector2i(500000, 500000), 0, config)
			reactions.append(Chemistry.form_reaction(deposits[0], deposits[1], 4000 + reactions.size(), 0, config))
		return true

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color("202b2b"))
		label(Vector2(24, 31), "FLUX / READABILITY CHECKPOINT / actual live presenters", 23)
		label(Vector2(24, 55), "Existing immutable pixels. No changed hitboxes, protection duration, visibility rules or spell costs.", 16)
		label(Vector2(24, 84), "EIGHT ELEMENTS / normal heading trail above, quieter reduced trail below", 17)
		for index: int in range(8):
			var element: String = pixels.ELEMENTS[index]
			var x := float(82 + index * 154)
			panel(Rect2(x - 64, 98, 140, 124))
			label(Vector2(x - 50, 119), element.capitalize(), 17, language.element_color(element))
			for reduced: bool in [false, true]:
				pixels.library.begin_frame(reduced)
				pixels.flight(self, element, Vector2(x + 10, 151 if not reduced else 197), Vector2(1, -0.3), 10, age, reduced)
		label(Vector2(24, 252), "FLOAT / full, half, final tick; protection stays solid while the small time meter drains", 17)
		var ids := ["s_wayne", "oh_tipi", "red_baron"]
		for body: int in range(3):
			var left := float(24 + body * 415)
			panel(Rect2(left, 266, 399, 171))
			label(Vector2(left + 12, 290), ["SMALL / 1.8s", "MIDDLE / 1.5s", "LARGE / 1.2s"][body], 17)
			for phase: int in range(3):
				var state := PlayerState.new(body + 1)
				state.air_height = 22000
				state.air_floating = true
				state.float_used = true
				state.float_max_duration_ms = [1800, 1500, 1200][body]
				var total := config.milliseconds_to_ticks(state.float_max_duration_ms)
				state.float_ticks = total if phase == 0 else total / 2 if phase == 1 else 1
				state.stamina = 100000
				state.facing_y = 1000
				pixels.library.begin_frame(false)
				var anchor := Vector2(left + 69 + phase * 130, 411)
				champion.draw(self, state, ids[body], anchor, age, config, false, anchor + Vector2(0, 22))
		label(Vector2(24, 466), "CONCEALMENT / the boundary stays; material thins exactly when hiding is inactive", 17)
		for column: int in range(4):
			var reduced := column >= 2
			var cleared := column % 2 == 1
			var left := float(24 + column * 312)
			label(Vector2(left + 8, 494), ("Reduced" if reduced else "Normal") + (" / clear window" if cleared else " / concealing"), 16)
			for row: int in range(2):
				var state := reactions[row]
				var tick := state.active_tick + age
				if row == 0:
					tick = state.decay_tick - config.milliseconds_to_ticks(350) + (age if cleared else -1)
				elif cleared:
					tick += config.milliseconds_to_ticks(300)
				var top := float(505 + row * 172)
				panel(Rect2(left, top, 294, 161))
				label(Vector2(left + 10, top + 22), "Steam / 75%" if row == 0 else "Shadowdraft / 1:1", 15)
				pixels.library.begin_frame(reduced)
				chemistry.begin_frame(config, null, Rect2(), [], reduced)
				var scale_factor := 0.75 if row == 0 else 1.0
				var anchor := Vector2(left + 146, top + 94)
				var center := Vector2(state.position_x, state.position_y) / 1000.0
				if row == 1:
					center = (center + Vector2(state.endpoint_x, state.endpoint_y) / 1000.0) * 0.5
				draw_set_transform(anchor - center * scale_factor, 0, Vector2.ONE * scale_factor)
				chemistry.draw_reaction(self, state, Chemistry.recipe(state.recipe_wire_id), tick, reduced)
				draw_set_transform(Vector2.ZERO)
		label(Vector2(24, 875), "Renderer fixtures, not a match screenshot. Four phase samples. Human motion/contrast review and120Hz load acceptance remain separate.", 15)

	func panel(rect: Rect2) -> void:
		draw_rect(rect, Color("394842"))
		draw_rect(rect, Color("728276"), false, 1)

	func label(at: Vector2, value: String, size: int, color: Color = Color("e9ddbc")) -> void:
		draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
