extends SceneTree


# Hidden actual-render fixture using inherited production ingestion and drawing.
# It is not a played match or evidence of human readability/comfort acceptance.
const SIZE := Vector2i(1280, 720)


func _initialize() -> void:
	root.hide()
	_run.call_deferred()


func _run() -> void:
	var output := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if not output.begins_with("res://.godot/combat-feedback-v1/render-") or ".." in output or DirAccess.dir_exists_absolute(output):
		push_error("Provide a new --output=res://.godot/combat-feedback-v1/render-NAME directory")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sheet := FeedbackSheet.new()
	if not sheet.configure() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Cannot configure live combat feedback capture")
		sheet.free()
		quit(1)
		return
	viewport.add_child(sheet)
	for kind: String in ["beam_fired", "spray_hit", "field_triggered"]:
		for reduced: bool in [false, true]:
			sheet.prepare(kind, reduced)
			sheet.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var rendered := viewport.get_texture().get_image()
			var path := output.path_join(kind + ("-reduced" if reduced else "-normal") + ".png")
			if rendered == null or rendered.get_size() != SIZE or rendered.save_png(path) != OK:
				push_error("Combat feedback fixture did not save a real1280x720 image")
				quit(1)
				return
			print("RENDERED " + path)
	print("PASS: 6 actual1280x720 captures;8 elements x3 contact families x normal/reduced; inherited live cue hook and draw path")
	quit(0)


class FeedbackSheet:
	extends "res://tests/support/combat_feedback_harness.gd"
	var event_kind := ""


	func configure() -> bool:
		ability_catalog = AbilityCatalog.new()
		visual_language = VisualLanguage.new()
		foundation_spell_presenter = FoundationSpellPresenter.new()
		player_preferences = PlayerPreferences.new()
		player_preferences.set_camera_zoom_percent(100)
		world = SimWorld.new(120)
		return ability_catalog.load_from_file(ABILITY_CATALOG_PATH) and visual_language.load_from_file() and foundation_spell_presenter.configure(visual_language, ability_catalog)


	func prepare(kind: String, reduced: bool) -> void:
		event_kind = kind
		requested_capture_reduced_effects = reduced
		combat_cues.clear()
		world.players.resize(1)
		var family := "beam" if kind == "beam_fired" else ("field" if kind == "field_triggered" else "spray")
		for index: int in range(8):
			var element := AbilityCatalog.FIRST_EIGHT_ELEMENTS[index]
			var ability := ability_catalog.ability(ability_catalog.spell_id_at(element, family))
			var center := Vector2(170 + (index % 4) * 312, 235 + floori(float(index) / 4.0) * 265)
			var target := PlayerState.new(index + 2)
			target.position_x = roundi(center.x * 1000.0)
			target.position_y = roundi(center.y * 1000.0)
			world.players.append(target)
			world.player().position_x = roundi((center.x - 80.0) * 1000.0)
			world.player().position_y = target.position_y
			var event := {"type": kind, "source_wire_id": int(ability.wire_id), "owner_id": 1, "target_id": target.entity_id, "damage": int(ability.get("damage", 0)), "hit_count": 2, "field_id": 4000 + index, "origin_x": world.player().position_x, "origin_y": target.position_y, "end_x": target.position_x, "end_y": target.position_y}
			_ingest_combat_cues([event])
		_update_combat_cues(4.0 / 120.0)


	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color("202b2b"))
		text_at(Vector2(24, 34), "FLUX / TRUTHFUL COMBAT FEEDBACK / " + ("REDUCED" if _reduced_effects_enabled() else "NORMAL"), 21)
		text_at(Vector2(24, 61), event_kind + " · actual production hook/draw path · original11px labels at100%zoom · 4/120s after contact", 15)
		for index: int in range(8):
			var element := AbilityCatalog.FIRST_EIGHT_ELEMENTS[index]
			var corner := Vector2(22 + (index % 4) * 312, 88 + floori(float(index) / 4.0) * 265)
			draw_rect(Rect2(corner, Vector2(300, 247)), Color("162222"))
			text_at(corner + Vector2(16, 28), element.to_upper(), 15, visual_language.element_color(element, "bright"))
			ElementGlyphRenderer.draw(self, visual_language, corner + Vector2(273, 24), element, 8.0, visual_language.element_color(element, "bright"))
		_draw_combat_cues(Vector2.ZERO)
		draw_set_transform(Vector2.ZERO)
		text_at(Vector2(24, 652), "Contact is not a promise of Slow or Launch. Beam damage is not carried by the guest event; no base damage is guessed.", 15)
		text_at(Vector2(24, 680), "Explicit event fixtures, not a match playthrough. Existing effect geometry/lifetimes unchanged; human feel/comfort acceptance remains open.", 14)


	func text_at(at: Vector2, value: String, size: int, color: Color = Color("e2d8b2")) -> void:
		draw_string(ThemeDB.fallback_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)
