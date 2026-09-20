extends SceneTree

# Actual presenters and immutable atlas pixels. Explicit fixtures, not a match.
const SIZE := Vector2i(1280, 900)


func _initialize() -> void:
	root.hide()
	_run.call_deferred()


func _run() -> void:
	var output := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if not output.begins_with("res://.godot/artwork-20260908/material-") or ".." in output or DirAccess.dir_exists_absolute(output):
		push_error("Provide a new --output=res://.godot/artwork-20260908/material-NAME directory")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sheet := MaterialSheet.new()
	if not sheet.configure() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Cannot prepare material acceptance fixture")
		sheet.free()
		quit(1)
		return
	viewport.add_child(sheet)
	for mode: int in range(4):
		sheet.mode = mode
		sheet.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var rendered := viewport.get_texture().get_image()
		var path := output.path_join(["normal", "reduced", "zero-decoration", "expired"][mode] + ".png")
		if rendered == null or rendered.get_size() != SIZE or rendered.save_png(path) != OK:
			push_error("Material fixture did not produce a real1280x900 PNG")
			quit(1)
			return
		print("RENDERED %s | decoration %s | chemistry %s" % [path, sheet.pixels.library.decoration_stats(), sheet.chemistry.stats()])
	print("PASS: 4 actual renderer pages;8 elements, current6px/19.2px projectile weight, deposits, Field mask probes, finite impacts")
	quit(0)


class MaterialSheet:
	extends Node2D
	const Chemistry = preload("res://src/sim/chemistry/element_chemistry_system.gd")
	var pixels := PixelSpellEffects.new()
	var chemistry := ElementChemistryPresenter.new()
	var language := VisualLanguage.new()
	var config := SimConfig.new(120)
	var deposits: Array = []
	var mode := 0
	var font: Font = ThemeDB.fallback_font


	func configure() -> bool:
		if not language.load_from_file() or not chemistry.configure(language) or not pixels.ready():
			return false
		for element: int in range(1, 9):
			Chemistry.deposit_terminal(deposits, 3000 + element, 1000 + element, 100, 1, 1, element, Vector2i(500000, 500000), 0, config)
		return deposits.size() == 8


	func _draw() -> void:
		var reduced := mode == 1
		var expired := mode == 3
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color("202b2b"))
		label(Vector2(24, 31), "FLUX / ELEMENT MATERIAL WEIGHT / " + ["NORMAL", "REDUCED", "ZERO DECORATION", "EXPIRED"][mode], 22)
		label(Vector2(24, 58), "Live presenters, original pixels, native1:1 scale; current projectile/contact sizes and fixed48px Field clipping probes.", 16)
		pixels.library.begin_frame(reduced)
		chemistry.begin_frame(config, null, Rect2(), deposits, reduced)
		if mode == 2:
			for element: String in pixels.ELEMENTS:
				for unused: int in range(100):
					pixels.library.take_decoration(pixels.asset_id(element, "field_tile", reduced))
		for index: int in range(8):
			var element: String = pixels.ELEMENTS[index]
			var x := float(89 + index * 154)
			panel(Rect2(x - 66, 81, 144, 693))
			label(Vector2(x - 52, 106), element.capitalize(), 18, language.element_color(element))
			label(Vector2(x - 53, 132), "Rapid6 / Heavy19.2", 12)
			if not expired:
				pixels.flight(self, element, Vector2(x - 30, 175), Vector2.RIGHT, 6.0, 12, reduced)
				pixels.flight(self, element, Vector2(x + 32, 175), Vector2.RIGHT, 19.2, 12, reduced)
			label(Vector2(x - 51, 241), "Terminal matter", 14)
			var deposit: ElementDepositState = deposits[index]
			draw_set_transform(Vector2(x, 307) - Vector2(500, 500))
			chemistry.draw_deposit(self, deposit, deposit.expiry_tick if expired else 100, reduced)
			draw_set_transform(Vector2.ZERO)
			label(Vector2(x - 60, 387), "48px mask probe", 12)
			if not expired:
				pixels.field(self, element, Vector2(x, 459), 48.0, 60, reduced)
			label(Vector2(x - 55, 562), "Contact6 / 19.2", 13)
			pixels.impact(self, element, Vector2(x - 30, 624), 43 if expired else 8, reduced, 6.0)
			pixels.impact(self, element, Vector2(x + 32, 624), 43 if expired else 8, reduced, 19.2)
			label(Vector2(x - 57, 716), "one-shot / no AoE", 13)
		label(Vector2(24, 811), "Core silhouettes survive optional-budget exhaustion. Field/deposit marks remain clipped to their exact existing masks.", 17)
		label(Vector2(24, 837), "Heavy contact art is cosmetic: its real84px explosion boundary is a separate gameplay cue, not this64px atlas cell.", 16)
		label(Vector2(24, 865), "Expired page: deposits/impacts queried at expiry; removed projectile/Field owners are not drawn. Not a simulated playthrough.", 15)


	func panel(rect: Rect2) -> void:
		draw_rect(rect, Color("394842"))
		draw_rect(rect, Color("728276"), false, 1.0)


	func label(at: Vector2, value: String, size: int, color: Color = Color("e9ddbc")) -> void:
		draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
