extends SceneTree


# Arranged native presenter board, not paid casts, a played match or a benchmark.
const SIZE := Vector2i(1280, 720)
const ORIGIN := Vector2(400, 400)
const REQUESTED_REACH := 280_000
const WALL := Rect2(480, 340, 20, 25)
const SOURCE_PATHS := [
	"res://src/presentation/hex_court_presenter.gd",
	"res://src/sim/combat/combat_system.gd",
	"res://src/sim/world/collision_world.gd",
	"res://content/abilities/foundation_abilities_v1.json",
	"res://content/visual/visual_language_v1.json",
	"res://tests/visual/capture_spray_cover.gd",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var output := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.begins_with("res://.godot/spray-cover-") or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("Provide a fresh native --output=res://.godot/spray-cover-NAME directory")
		return
	var sources := {}
	for path: String in SOURCE_PATHS:
		sources[path] = FileAccess.get_sha256(path)
	var board := SprayBoard.new()
	if not board.configure() or DirAccess.make_dir_recursive_absolute(output) != OK:
		board.free()
		_fail("Could not prepare all eight current Spray cover fixtures")
		return
	root.size = SIZE
	root.title = "H.E.X. / arranged Spray cover presentation"
	root.visible = true
	root.add_child(board)
	var frames: Array[Dictionary] = []
	var geometry_before := var_to_bytes(board.cues)
	for reduced: bool in [false, true]:
		board.reduced = reduced
		board.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var rendered := root.get_texture().get_image()
		var path := output.path_join("spray-cover-%s-1280x720.png" % ("reduced" if reduced else "normal"))
		if board.drawn_count != 8 or var_to_bytes(board.cues) != geometry_before or rendered == null or rendered.get_size() != SIZE or rendered.save_png(path) != OK:
			_fail("Spray board draw/save failed or changed its admitted geometry")
			return
		frames.append({"path": path, "sha256": FileAccess.get_sha256(path), "width": SIZE.x, "height": SIZE.y,
			"reduced_effects": reduced, "drawn_cases": board.drawn_count, "geometry_unchanged": true})
		print("RENDERED ", path)
	for path: String in SOURCE_PATHS:
		if String(sources[path]).length() != 64 or FileAccess.get_sha256(path) != sources[path]:
			_fail("Spray fixture source changed during capture: " + path)
			return
	var receipt := {"status": "passed", "frames": frames, "cases": board.cases, "sources": sources,
		"scope": "Arranged native 8-element production Spray presenter board at 75% scale. Known narrow side wall, requested 280px reach, live catalog radius/cone/palette, normal and Reduced Effects. No played or paid-cast sequence, input, historical cover reconstruction, gameplay, performance or human acceptance claim. Process stderr must be checked separately."}
	var receipt_path := output.path_join("receipt.json")
	var file := FileAccess.open(receipt_path, FileAccess.WRITE)
	if file == null:
		_fail("Could not write Spray fixture receipt")
		return
	file.store_string(JSON.stringify(receipt, "\t") + "\n")
	file.close()
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(receipt_path))
	if not decoded is Dictionary or decoded.get("status", "") != "passed" or decoded.get("frames", []).size() != 2 or decoded.get("cases", []).size() != 8:
		_fail("Spray fixture serialized receipt is incomplete")
		return
	for entry: Dictionary in decoded.cases:
		if not bool(entry.get("clipped_side", false)) or not bool(entry.get("clear_center", false)) or not bool(entry.get("source_unchanged", false)) or entry.get("endpoints", []).size() != 5:
			_fail("Spray fixture serialized geometry validation is incomplete")
			return
	print("PASS spray-cover native fixture: 8 validated geometries, 2 frames; not gameplay/performance acceptance")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


class SprayBoard:
	extends Node2D

	var catalog := AbilityCatalog.new()
	var language := VisualLanguage.new()
	var presenter := HexCourtPresenter.new()
	var cues: Array[Dictionary] = []
	var cases: Array[Dictionary] = []
	var reduced := false
	var drawn_count := 0


	func configure() -> bool:
		if not catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json") or not language.load_from_file() or not presenter.configure(language):
			return false
		var collision := CollisionWorld.new(2_000_000, 2_000_000)
		collision.add_obstacle(CollisionWorld.Obstacle.new(7, 480_000, 340_000, 500_000, 365_000))
		var wires := {}
		for element: String in AbilityCatalog.DISPLAY_ELEMENT_IDS:
			var ability := catalog.ability(catalog.spell_id_at(element, "spray"))
			var wire := int(ability.get("wire_id", 0))
			var definition := CombatTuning.cast_definition(wire)
			if wires.has(wire) or wire not in catalog.runtime_wire_ids or String(definition.get("shape", "")) != "spray" or int(definition.get("range", 0)) < REQUESTED_REACH:
				return false
			wires[wire] = true
			var cue := {"source_wire_id": wire, "kind": "spray", "event_type": "spray_fired", "position": ORIGIN,
				"start": ORIGIN, "end": ORIGIN + Vector2(float(REQUESTED_REACH) / 1000.0, 0), "range": REQUESTED_REACH, "duration": 0.20, "remaining": 0.20}
			var before := var_to_bytes(cue)
			var prepared := HexCourtPresenter.prepare_spray_cue(cue, collision)
			if prepared.is_empty() or prepared.endpoints.size() != 5 or prepared.brace.size() != 2:
				return false
			var clipped_side: bool = prepared.endpoints[0].distance_to(ORIGIN) < float(REQUESTED_REACH) / 1000.0 - 1.0
			var clear_center: bool = prepared.endpoints[2] == cue.end
			var source_unchanged: bool = var_to_bytes(cue) == before
			if not clipped_side or not clear_center or not source_unchanged:
				return false
			var points: Array = []
			for point: Vector2 in prepared.endpoints:
				if not point.is_finite() or point.distance_to(ORIGIN) > float(REQUESTED_REACH) / 1000.0 + 0.001:
					return false
				points.append([point.x, point.y])
			cue["spray_geometry"] = prepared
			cues.append(cue)
			cases.append({"element": element, "source_wire_id": wire, "catalog_range": int(definition.range), "requested_range": REQUESTED_REACH,
				"clearance_radius": int(definition.radius), "cone_cosine_squared_per_million": int(definition.cone_cosine_squared_per_million),
				"clipped_side": clipped_side, "clear_center": clear_center, "source_unchanged": source_unchanged, "endpoints": points})
		return cues.size() == 8 and cases.size() == 8


	func _draw() -> void:
		drawn_count = 0
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color("202b2b"))
		_text(Vector2(22, 30), "H.E.X. / SPRAY COVER / " + ("REDUCED EFFECTS" if reduced else "NORMAL"), 20, Color("eee1c4"))
		_text(Vector2(22, 55), "Arranged production-presenter fixture at 75% scale. Narrow side wall; clear center. Not a played or paid-cast sequence.", 13, Color("c8cfbd"))
		for index: int in cues.size():
			var corner := Vector2(22 + (index % 4) * 312, 80 + floori(float(index) / 4.0) * 282)
			var element := String(cases[index].element)
			draw_rect(Rect2(corner, Vector2(300, 268)), Color("a78f6b") if index % 2 else Color("283b32"))
			_text(corner + Vector2(12, 25), ("AIR" if element == "wind" else element.to_upper()) + " / SPRAY", 15, Color("eee1c4") if index % 2 == 0 else Color("202737"))
			draw_set_transform(corner + Vector2(28, 152) - ORIGIN * 0.75, 0.0, Vector2.ONE * 0.75)
			draw_rect(WALL, Color("4d5150"))
			draw_rect(WALL, Color("d3d8c8"), false, 1.0)
			draw_circle(ORIGIN, 3.0, Color("d3d8c8"))
			if presenter.draw_cue(self, cues[index], reduced):
				drawn_count += 1
			draw_set_transform(Vector2.ZERO)
		_text(Vector2(22, 666), "Gray rectangles are the actual arranged collision boxes. Fan rays and color come from the live production presenter.", 13, Color("c8cfbd"))
		_text(Vector2(22, 690), "Five prepared rays; Reduced Effects draws the same outer/center three. No per-draw cover queries or changed cast geometry.", 13, Color("c8cfbd"))


	func _text(at: Vector2, value: String, font_size: int, color: Color) -> void:
		draw_string(ThemeDB.fallback_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
