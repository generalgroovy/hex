extends SceneTree


# Real live-presenter draw calls in an isolated viewport; explicit legal-state
# fixtures, not a simulated match or an assertion of human visual acceptance.
const SIZE := Vector2i(1280, 720)


func _initialize() -> void:
	root.hide()
	_run.call_deferred()


func _run() -> void:
	var output := ""
	var magic_manifest := PixelMagicLibrary.MANIFEST_PATH
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument.begins_with("--magic-manifest="):
			magic_manifest = argument.trim_prefix("--magic-manifest=")
	if not output.begins_with("res://.godot/diagnostics/material-") or ".." in output or DirAccess.dir_exists_absolute(output):
		push_error("Provide a new --output=res://.godot/diagnostics/material-NAME")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sheet := MaterialSheet.new()
	sheet.steam_reduced = OS.get_cmdline_user_args().has("--reduced-steam")
	sheet.with_actor = OS.get_cmdline_user_args().has("--with-actor")
	sheet.spell_footprints = OS.get_cmdline_user_args().has("--spell-footprints")
	if not sheet.configure(magic_manifest) or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Material fixture configuration failed")
		sheet.free()
		quit(1)
		return
	viewport.add_child(sheet)
	for phase_tick: int in [100, 112, 124]:
		sheet.tick = phase_tick
		sheet.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var rendered := viewport.get_texture().get_image()
		if rendered == null or rendered.get_size() != SIZE or rendered.save_png(output.path_join("materials-%d.png" % phase_tick)) != OK:
			push_error("Material fixture failed real rendering")
			quit(1)
			return
	print("PASS: 3 actual1280x720 material frames:8 elements normal/reduced/zero budget +Steam phase fixtures")
	print("Pixel manifest SHA256: ", sheet.presenter.library.content_hash)
	quit(0)


class MaterialSheet:
	extends Node2D
	const Chemistry = preload("res://src/sim/chemistry/element_chemistry_system.gd")
	var presenter := ElementChemistryPresenter.new()
	var language := VisualLanguage.new()
	var config := SimConfig.new(120)
	var deposits: Array = []
	var steam: ElementReactionState
	var tick := 100
	var steam_reduced := false
	var with_actor := false
	var spell_footprints := false
	var spells: PixelSpellEffects
	var champion := CartoonChampionPresenter.new()
	var actor := PlayerState.new()
	var font: Font = ThemeDB.fallback_font


	func configure(magic_manifest: String) -> bool:
		var pixels := PixelMagicLibrary.new()
		if not pixels.load_from_file(magic_manifest):
			push_error(pixels.last_error)
			return false
		if not language.load_from_file() or not presenter.configure(language, pixels):
			return false
		spells = PixelSpellEffects.new(pixels)
		if with_actor and not champion.configure(language):
			push_error(champion.last_error)
			return false
		for element: int in range(1, 9):
			Chemistry.deposit_terminal(deposits, 3000 + element, 1000 + element, 100, 1, 1, element, Vector2i(500000, 500000), 0, config)
		steam = Chemistry.form_reaction(deposits[1], deposits[2], 4000, 0, config)
		# Legal fully expanded active-state fixture; this is not an extra visual radius.
		steam.radius = 90000
		return steam != null


	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color("202b2b"))
		label(Vector2(24, 30), "FLUX / ACTUAL PIXEL MATERIAL / 1:1 WORLD PIXELS", 22)
		label(Vector2(24, 57), "Runtime pixel material. Exact authority masks, phases and budgets. Tick %d / 120Hz." % tick, 16)
		for index: int in range(8):
			label(Vector2(124 + 142 * index, 88), presenter.ELEMENTS[index + 1].capitalize(), 18, language.element_color(presenter.ELEMENTS[index + 1]))
		for row: int in range(3):
			var reduced := row == 1
			presenter.library.begin_frame(reduced)
			presenter.begin_frame(config, null, Rect2(), deposits, reduced)
			if row == 2:
				for element: int in range(1, 9):
					for unused: int in range(100):
						presenter.library.take_decoration(PixelMagicLibrary.element_asset_id(element, "deposit_active", false))
			label(Vector2(18, 152 + row * 116), (["Field", "Spray", "Budget0"] if spell_footprints else ["Normal", "Reduced", "Budget0"])[row], 16)
			for index: int in range(8):
				var anchor := Vector2(156 + 142 * index, 162 + row * 116)
				draw_set_transform(anchor - Vector2(500, 500))
				if spell_footprints:
					var element: String = presenter.ELEMENTS[index + 1]
					if row == 1:
						spells.spray(self, element, Vector2(470,500), Vector2(536,500), 820000, tick, steam_reduced, 1.0)
					else:
						spells.field(self, element, Vector2(500,500), 32.0, tick, steam_reduced)
				else:
					presenter.draw_deposit(self, deposits[index], tick, reduced)
				draw_set_transform(Vector2.ZERO)
		label(Vector2(24, 457), "STEAM / EXACT PHASE AND CONCEALMENT / " + ("REDUCED" if steam_reduced else "NORMAL"), 20)
		var times: Array[int] = [steam.created_tick + 16, tick, steam.decay_tick - config.milliseconds_to_ticks(350), steam.decay_tick + 30, steam.expiry_tick]
		var titles := ["FORMING", "CONCEALING", "THIN / NO CONCEAL", "DECAY", "EXPIRED"]
		for index: int in range(times.size()):
			presenter.library.begin_frame(steam_reduced)
			presenter.begin_frame(config, null, Rect2(), deposits, steam_reduced)
			label(Vector2(35 + index * 250, 488), titles[index], 15)
			draw_set_transform(Vector2(125 + index * 250, 580) - Vector2(500, 500))
			presenter.draw_reaction(self, steam, Chemistry.recipe(310), times[index], steam_reduced)
			if with_actor:
				champion.draw(self, actor, "oh_tipi", Vector2(500, 500), 0, config, true)
			draw_set_transform(Vector2.ZERO)
		label(Vector2(24, 692), "Actual actor after ground material; concealment visibility is not simulated." if with_actor else "Native material carries occupied area: no range rings. Reduced/zero decoration preserve the material footprint.", 15)


	func label(at: Vector2, value: String, size: int, color: Color = Color("e9ddbc")) -> void:
		draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
