extends SceneTree

# Explicit active-state fixtures through the live presenter, not new artwork or
# a simulation playthrough. Offscreen SubViewport keeps the desktop untouched.
const SIZE := Vector2i(1280, 840)
const OUTPUT_PREFIX := "res://.godot/diagnostics/"
const Presenter = preload("res://src/presentation/element_chemistry_presenter.gd")
const Chemistry = preload("res://src/sim/chemistry/element_chemistry_system.gd")
const Deposit = preload("res://src/sim/chemistry/element_deposit_state.gd")


func _initialize() -> void:
	root.hide()
	_run.call_deferred()


func _run() -> void:
	var output := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if not output.begins_with(OUTPUT_PREFIX + "thin-") or ".." in output or DirAccess.dir_exists_absolute(output):
		push_error("Provide a new --output=res://.godot/diagnostics/thin-NAME directory")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sheet := ThinSheet.new()
	if not sheet.configure() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Cannot prepare live thin-chemistry fixture/output")
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
		if rendered == null or rendered.is_empty() or rendered.get_size() != SIZE:
			push_error("Real offscreen rendering did not produce the required image")
			quit(1)
			return
		var path := output.path_join("active_%02d.png" % age)
		if rendered.save_png(path) != OK:
			push_error("Could not save thin-chemistry PNG")
			quit(1)
			return
		print("RENDERED %s | %s" % [path, str(sheet.counts)])
	print("PASS: 4 actual 1280x840 renderer frames; 4 thin-link fixtures x normal/reduced")
	quit(0)


class ThinSheet:
	extends Node2D
	var presenter := Presenter.new()
	var config := SimConfig.new(120)
	var fixtures: Array = []
	var deposits: Array = []
	var age := 0
	var counts: Array = []
	var font: Font = ThemeDB.fallback_font

	func configure() -> bool:
		var language := VisualLanguage.new()
		if not language.load_from_file() or not presenter.configure(language):
			return false
		for wire: int in [313, 328]:
			for diagonal: bool in [false, true]:
				var recipe := Chemistry.recipe(wire)
				var inputs: Array = []
				for index: int in range(2):
					Chemistry.deposit_terminal(inputs, 3000 + index, 1000 + index, 100, 1, 1, int(recipe.elements[index]), Vector2i(512000, 512000), 0, config)
				var state := Chemistry.form_reaction(inputs[0], inputs[1], 4000 + fixtures.size(), 0, config)
				var direction := Vector2i(800, 600) if diagonal else Vector2i(1000, 0)
				var endpoint := Vector2i(512000, 512000) + direction * 160
				state.path_points = PackedInt64Array([512000, 512000, endpoint.x, endpoint.y])
				state.endpoint_x = endpoint.x
				state.endpoint_y = endpoint.y
				state.direction_x = direction.x
				state.direction_y = direction.y
				var deposit := Deposit.new()
				deposit.entity_id = 3010 + fixtures.size()
				deposit.strength = 1000
				deposit.expiry_tick = 1000
				deposits.append(deposit)
				state.linked_deposit_ids = PackedInt64Array([deposit.entity_id])
				fixtures.append({"state": state, "recipe": recipe, "name": recipe.name + (" / diagonal" if diagonal else " / horizontal, between tile rows")})
		return true


	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color("202b2b"))
		label(Vector2(24, 32), "THIN CHEMISTRY / actual presenter + immutable pixel pack", 22, Color("ead9ad"))
		label(Vector2(24, 57), "Active age %d ticks | native 1:1 pixels | material away from source must survive grid offsets" % age, 16, Color("b3c2bc"))
		counts.clear()
		for column: int in range(2):
			var reduced := column == 1
			var left := float(24 + column * 640)
			presenter.library.begin_frame(reduced)
			presenter.begin_frame(config, null, Rect2(), deposits, reduced)
			label(Vector2(left, 88), "REDUCED / alternating subset" if reduced else "NORMAL / 32px path stamps", 18, Color("d7b36e"))
			for row: int in range(fixtures.size()):
				var item: Dictionary = fixtures[row]
				var top := float(106 + row * 170)
				draw_rect(Rect2(left, top, 592, 158), Color("40504a"), false, 1.0)
				label(Vector2(left + 12, top + 23), item.name, 15, Color("d9dbbd"))
				var anchor := Vector2(left + 92, top + 47)
				draw_set_transform(anchor - Vector2(512, 512))
				presenter.draw_reaction(self, item.state, item.recipe, item.state.active_tick + age, reduced)
				draw_set_transform(Vector2.ZERO)
				label(anchor + Vector2(-68, 6), "source", 12, Color("9aaea6"))
			counts.append(presenter.stats())
		label(Vector2(24, 821), "No invented rays. Only stored live paths; true mask clipping and normal shared budgets. Static acceptance fixtures, not a playthrough.", 14, Color("b3c2bc"))


	func label(at: Vector2, value: String, size: int, color: Color) -> void:
		draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
