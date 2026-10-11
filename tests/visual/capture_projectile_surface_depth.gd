extends SceneTree
## Arranged production projectile rendering; no battle/performance claim.

const Effects = preload("res://src/presentation/pixel_spell_effects.gd")
const Facets = preload("res://src/presentation/hex_projectile_facets.gd")
const SOURCES := ["res://src/presentation/pixel_spell_effects.gd", "res://src/presentation/hex_projectile_facets.gd",
	"res://src/presentation/hex_court_presenter.gd", "res://src/presentation/foundation_spell_presenter.gd",
	"res://src/presentation/pixel_magic_library.gd", "res://src/presentation/visual_language.gd",
	"res://tests/visual/capture_projectile_surface_depth.gd", "res://content/abilities/element_mixtures_v1.json"]
var output := ""

class Board:
	extends Node2D
	var language: VisualLanguage
	var foundation: FoundationSpellPresenter
	var court: HexCourtPresenter
	var config := SimConfig.new(120)
	var title := ""
	var reduced := false
	var shots: Array[Dictionary] = []
	var failure := ""

	func add_shot(mask: int, family: String, at: Vector2, ratio: float, age: int, direction: Vector2) -> void:
		var wire := MixtureCatalog.wire_for(mask, family)
		var definition := CombatTuning.cast_definition_view(wire)
		var life := config.milliseconds_to_ticks(int(definition.lifetime_ms))
		var shot := ProjectileState.new(shots.size() + 1, 1, 1, wire, int(definition.element_wire_id), Vector2i(at * 1000), Vector2i(direction * 280000), int(definition.radius), int(definition.damage), life - age)
		shot.initial_strength = int(definition.reaction_strength)
		shot.remaining_strength = maxi(1, roundi(float(shot.initial_strength) * ratio))
		shot.delivery_damage_remaining = shot.damage
		shot.remaining_bounces = int(definition.get("remaining_bounces", 0))
		shots.append({"shot": shot, "before": shot.canonical_values(), "at": at,
			"label": "%s / %s / %d%%" % [family.to_upper(), "+".join(Effects.mixture_elements(mask)), roundi(ratio * 100)]})

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 720), Color("34443b"))
		for y: int in range(80, 720, 36): draw_line(Vector2(0, y), Vector2(1280, y), Color("3e5044"), 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(24, 30), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("ece2c3"))
		draw_string(ThemeDB.fallback_font, Vector2(24, 53), "Production materials: northwest light, fixed UVs, bounded elevation; circles below are diagnostic physical contact radii.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("b9cbb7"))
		for entry: Dictionary in shots:
			var shot: ProjectileState = entry.shot
			var radius := float(shot.radius) / SimConfig.FIXED_SCALE
			draw_arc(entry.at, radius, 0, TAU, 48, Color(0.84, 0.86, 0.75, 0.24), 1.0)
			if not foundation.draw_expanded_projectile(self, shot, 200, reduced, 1.0):
				if not court.draw_projectile(self, shot, 200.0, 1.0, reduced): failure = "production draw refused a live shot"
			if shot.canonical_values() != entry.before: failure = "render changed canonical projectile"
			draw_string(ThemeDB.fallback_font, entry.at + Vector2(-135, 48), entry.label, HORIZONTAL_ALIGNMENT_CENTER, 270, 11, Color("e2d7b7"))
		# Large pure-material close-ups reveal the per-vertex cuts at native pixels.
		for index: int in ElementRules.WIRE_IDS.size():
			var wire: int = ElementRules.WIRE_IDS[index]
			var at := Vector2(100 + index * 210, 646)
			var element := ElementRules.id_from_wire(wire)
			if not Facets.draw(self, at, Vector2(1, -0.25), 28.0, 70.0, wire, language.element_color(element, "bright")):
				failure = "material close-up refused"
			draw_string(ThemeDB.fallback_font, at + Vector2(-80, 40), element + " / facet close-up", HORIZONTAL_ALIGNMENT_CENTER, 160, 11, Color("c6d4bb"))


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.begins_with("res://.godot/projectile-depth-native-") or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("Native backend and fresh --output=res://.godot/projectile-depth-native-NAME required"); return
	if DirAccess.make_dir_recursive_absolute(output) != OK: _fail("Cannot create capture directory"); return
	var hashes := {}
	for path: String in SOURCES:
		hashes[path] = FileAccess.get_sha256(path)
		if String(hashes[path]).length() != 64: _fail("Missing source " + path); return
	var abilities := AbilityCatalog.new()
	var language := VisualLanguage.new()
	var foundation := FoundationSpellPresenter.new()
	var court := HexCourtPresenter.new()
	if not abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json") or not language.load_from_file() or not foundation.configure(language, abilities) or not court.configure(language):
		_fail("Production presentation admission failed"); return
	root.visible = true
	root.mode = Window.MODE_MINIMIZED
	var viewport := SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := Board.new()
	board.language = language
	board.foundation = foundation
	board.court = court
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(board)
	var records: Array[Dictionary] = []
	for page: String in ["identities", "strength", "phases"]:
		board.shots.clear()
		for row: int in 3:
			for column: int in 4:
				var mask: int = [1, 2, 4, 8, 16, 32, 3, 7, 15, 31, 63, 42][row * 4 + column] if page == "identities" else [3, 7, 21, 63][column]
				var family: String = ["bolt", "heavy", "rebound"][row] if page == "identities" else "heavy"
				var ratio: float = [1.0, 0.5, 0.04][row] if page == "strength" else 1.0
				var age: int = [0, 8, 16][row] if page == "phases" else 8
				board.add_shot(mask, family, Vector2(160 + column * 320, 150 + row * 155), ratio, age, Vector2.from_angle(float(column) * PI * 0.5))
		for reduced: bool in [false, true]:
			board.reduced = reduced
			foundation.begin_frame(board.config, null)
			for zoom: float in [1.0, 0.75]:
				board.title = "PROJECTILE DEPTH / %s / reduced=%s / zoom=%s" % [page, reduced, zoom]
				viewport.size = Vector2i(Vector2(1280, 720) * zoom)
				viewport.canvas_transform = Transform2D.IDENTITY.scaled(Vector2.ONE * zoom)
				board.queue_redraw()
				await process_frame
				await process_frame
				RenderingServer.force_draw(false)
				if not board.failure.is_empty(): _fail(board.failure); return
				var path := "%s-reduced-%d-zoom-%d.png" % [page, int(reduced), roundi(zoom * 100)]
				var pixels := viewport.get_texture().get_image()
				if pixels == null or pixels.save_png(output.path_join(path)) != OK: _fail("Cannot save capture"); return
				records.append({"path": path, "sha256": FileAccess.get_sha256(output.path_join(path)), "shots": board.shots.size()})
	for path: String in hashes:
		if hashes[path] != FileAccess.get_sha256(path): _fail("Source changed during capture: " + path); return
	var file := FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE)
	if file == null: _fail("Cannot write receipt"); return
	file.store_string(JSON.stringify({"status": "captured_needs_visual_review", "source_hashes": hashes, "images": records,
		"authority_unchanged": true, "geometry": Effects.material_geometry_stats(),
		"scope": "Six ingredients and six mixture counts, four headings, three strength levels, three material ages, both effects modes and both supported zooms.",
		"limitations": "Arranged production rendering; no physical play, sustained performance, occlusion or human motion acceptance."}, "\t") + "\n")
	file.close()
	print("PASS projectile depth capture: ", records.size(), " images require independent review")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
