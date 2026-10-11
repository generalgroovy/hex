extends SceneTree


# Native helper board, not a played match: isolated semantic contact fixtures
# use all 32 CURRENT runtime spells with the production HexCourtPresenter cue
# renderer and HexCombatLabel. No boot, profile, sockets, payment or audio.
const LabelModel = preload("res://src/presentation/hex_combat_label.gd")
const Feedback = preload("res://src/presentation/combat_feedback_model.gd")
const SIZE := Vector2i(1280, 1000)
const SOURCE_PATHS := [
	"res://src/presentation/hex_combat_label.gd",
	"res://src/presentation/hex_court_presenter.gd",
	"res://src/presentation/combat_feedback_model.gd",
	"res://src/app/bootstrap.gd",
	"res://content/abilities/foundation_abilities_v1.json",
	"res://tests/visual/capture_hex_combat_labels.gd",
]


func _initialize() -> void:
	root.hide()
	_run.call_deferred()


func _run() -> void:
	var output := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.begins_with("res://.godot/hex-combat-labels-native-") or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("Provide a fresh native --output=res://.godot/hex-combat-labels-native-NAME directory")
		return
	var sheet := LabelSheet.new()
	if not sheet.configure() or DirAccess.make_dir_recursive_absolute(output) != OK:
		sheet.free()
		_fail("Could not configure current-runtime hex combat label board")
		return
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(sheet)
	var frames: Array[Dictionary] = []
	for elapsed: float in [0.0, 0.275, 0.50]:
		for reduced: bool in [false, true]:
			sheet.elapsed = elapsed
			sheet.reduced = reduced
			sheet.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var rendered := viewport.get_texture().get_image()
			var path := output.path_join("labels-%03dms-%s.png" % [roundi(elapsed * 1000.0), "reduced" if reduced else "normal"])
			if rendered == null or rendered.get_size() != SIZE or rendered.save_png(path) != OK:
				_fail("Current hex label board did not save a native 1280x1000 image")
				return
			frames.append({"path": path, "sha256": FileAccess.get_sha256(path), "elapsed_seconds": elapsed, "reduced": reduced})
			print("RENDERED ", path)
	var sources: Array[Dictionary] = []
	for path: String in SOURCE_PATHS:
		sources.append({"path": path, "sha256": FileAccess.get_sha256(path)})
	var receipt := FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE)
	if receipt == null:
		_fail("Could not save native label-board receipt")
		return
	receipt.store_string(JSON.stringify({
		"status": "passed", "frames": frames, "cases": sheet.cases, "sources": sources,
		"scope": "Native helper board: 32 isolated synthetic contacts from the current 8-element, 4-family catalog; production hex impact and label helpers; 3 ages in normal/reduced effects. Gray actor-spacing proxies, not character art. No real casts, payment, visibility integration, played match, audio, multiplayer, balance, performance or human readability acceptance. Gameplay cue cap remains 24.",
	}, "\t") + "\n")
	receipt.close()
	print("PASS hex-combat-labels helper board: 6 native frames, 32 isolated current-runtime cases; not a played match")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


class LabelSheet:
	extends Node2D

	var catalog := AbilityCatalog.new()
	var language := VisualLanguage.new()
	var presenter := HexCourtPresenter.new()
	var cues: Array[Dictionary] = []
	var cases: Array[Dictionary] = []
	var elapsed := 0.0
	var reduced := false


	func configure() -> bool:
		if not catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json") or not language.load_from_file() or not presenter.configure(language):
			return false
		for row: int in range(AbilityCatalog.DISPLAY_ELEMENT_IDS.size()):
			var element := String(AbilityCatalog.DISPLAY_ELEMENT_IDS[row])
			for column: int in range(AbilityCatalog.SPELL_MATRIX_FAMILIES.size()):
				var family := String(AbilityCatalog.SPELL_MATRIX_FAMILIES[column])
				var ability := catalog.ability(catalog.spell_id_at(element, family))
				if ability.is_empty() or int(ability.wire_id) not in catalog.runtime_wire_ids:
					return false
				var kind := "spray_hit" if family == "spray" else "projectile_hit"
				var event := {"type": kind, "source_wire_id": int(ability.wire_id), "owner_id": 1, "target_id": 2, "damage": 3125}
				var description := Feedback.describe(event, catalog)
				cues.append({
					"event_type": kind, "source_wire_id": int(ability.wire_id),
					"position": Vector2(230 + column * 285, 181 + row * 96),
					"label": description.label, "color": language.element_color(element, "bright"),
					"duration": 0.55, "remaining": 0.55,
				})
				cases.append({"element": element, "family": family, "source_wire_id": int(ability.wire_id), "event_type": kind, "label": description.label, "synthetic_reported_damage": 3125})
		return cues.size() == 32


	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color("17201d"))
		_text(Vector2(20, 30), "H.E.X. / CURRENT COMBAT LABEL HELPERS / %s / %d ms" % ["REDUCED" if reduced else "NORMAL", roundi(elapsed * 1000.0)], 18)
		_text(Vector2(20, 55), "Controlled native helper board: current 8 elements x 4 families, not a played or paid-cast sequence.", 13)
		for column: int in range(AbilityCatalog.SPELL_MATRIX_FAMILIES.size()):
			_text(Vector2(198 + column * 285, 86), String(AbilityCatalog.SPELL_MATRIX_FAMILIES[column]).to_upper(), 13)
		for row: int in range(AbilityCatalog.DISPLAY_ELEMENT_IDS.size()):
			var top := 104.0 + float(row * 96)
			draw_rect(Rect2(88, top, 1168, 89), Color("827153") if row % 2 else Color("263c32"))
			_text(Vector2(12, top + 49), String(AbilityCatalog.DISPLAY_ELEMENT_IDS[row]).to_upper(), 11)
		for cue: Dictionary in cues:
			cue.remaining = float(cue.duration) - elapsed
			var anchor: Vector2 = cue.position
			# Explicit spacing proxy: no claim of current playable character art.
			draw_rect(Rect2(anchor + Vector2(-5, -34), Vector2(10, 9)), Color("9c9c90"))
			draw_rect(Rect2(anchor + Vector2(-9, -23), Vector2(18, 18)), Color("666f67"))
			draw_line(anchor + Vector2(-13, 0), anchor + Vector2(13, 0), Color("bec3ac"), 1.0)
			presenter.draw_cue(self, cue, reduced)
			LabelModel.draw(self, cue, reduced, language.ramp_color("worldbone", 0))
		_text(Vector2(20, 907), "Gray blocks are actor-spacing proxies; crosses are current HexCourtPresenter impacts. Original 11px labels at 100% scale.", 12)
		_text(Vector2(20, 932), "Both modes retain exact reported damage, centered placement and lifetime fade; reduced effects removes optional upward drift.", 12)
		_text(Vector2(20, 957), "32 isolated cases are shown for comparison. Gameplay still caps cues at 24; no gameplay, visibility or audio acceptance is claimed.", 12)


	func _text(at: Vector2, value: String, size: int) -> void:
		draw_string(ThemeDB.fallback_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("e9e3c9"))
