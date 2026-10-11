extends SceneTree
@warning_ignore_start("integer_division")
# Native arranged-render equivalence only; no gameplay, FPS or paid-hit claims.
# Two independent <=512px viewports. No game/transport/progression is created.
const Court = preload("res://src/presentation/hex_court_presenter.gd")
const CourtBefore = preload("res://tests/support/hex_paid_outline_reference.gd")
const HudBefore = preload("res://tests/support/hud_panel_reference.gd")
const Grid = preload("res://src/sim/hex/hex_grid.gd")
const SIZE := Vector2i(512, 384)
const SOURCE_PATHS := ["res://src/presentation/hex_court_presenter.gd", "res://src/presentation/compact_combat_hud.gd", "res://tests/support/hex_paid_outline_reference.gd", "res://tests/support/hud_panel_reference.gd", "res://scripts/verify-render-equivalence.gd"]
var output := ""
var candidate: Board
var reference: Board
var candidate_view: SubViewport
var reference_view: SubViewport
var results: Array[Dictionary] = []
var failures := 0
var sources: Dictionary = {}
var checker_hash := ""

class Fixture extends RefCounted:
	var origin := Vector2i.ZERO
	var render_revision := 0
	var cells: Dictionary = {}
	var material := ""
	var wire := 0
	var phase := "active"
	var variant := 0
	func _init() -> void:
		cells[Vector2i.ZERO] = {}
		for cell: Vector2i in Grid.neighbors(Vector2i.ZERO): cells[cell] = {}
	func view(_cell: Vector2i, _tick: float) -> Dictionary:
		return {material + "_quantity": 100, material + "_present": true, "fire_phase": phase, "steam_heat": 1000}
	func render_regions(cell: Vector2i, requested: String, _tick: float) -> Array[Dictionary]:
		if requested != material: return []
		var polygon := PackedVector2Array()
		for point: Vector2i in Grid.vertices(cell): polygon.append(Vector2(point))
		var actual_phase := phase
		if material == "fire": actual_phase = "ignition" if phase == "forming" else "cooling" if phase == "decaying" else phase
		var owner := 2 if variant == 1 and cell.x > 0 else 1
		var row := {"material": material, "recipe_wire_id": wire, "footprint_id": 1,
			"polygon": polygon, "phase": actual_phase, "quantity": 100, "intensity": 1000,
			"danger": phase == "active" and variant != 2, "owner_key": owner, "owner": owner,
			"source_ids": [owner], "active_tick": 200, "decay_tick": 500, "expiry_tick": 720, "direction": Vector2i(1000, 0)}
		var rows: Array[Dictionary] = [row]
		if variant == 3:
			var overlap := row.duplicate(true)
			overlap.footprint_id = 2
			overlap.intensity = 500
			overlap.owner = 3
			overlap.owner_key = 3
			overlap.source_ids = [3]
			overlap.decay_tick = 560
			rows.append(overlap)
		return rows

class Board extends Node2D:
	var court: HexCourtPresenter
	var hud: CompactCombatHud
	var fixture := Fixture.new()
	var mode := "material"
	var reduced := false
	var rectangle := Rect2()
	var opacity := 1.0
	var serial := 0
	var failed := false
	func _draw() -> void:
		serial += 1
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color("aa9978"))
		# Background checker makes translucent fill/shared-edge changes visible.
		for x: int in range(0, SIZE.x, 32):
			for y: int in range(0, SIZE.y, 32):
				if (x / 32 + y / 32) % 2 == 0: draw_rect(Rect2(x, y, 32, 32), Color("243239"))
		if mode == "blank": return
		if mode == "hud":
			draw_set_transform(Vector2(32, 32) - rectangle.position.floor())
			hud._draw_panel(self, rectangle, opacity)
			draw_set_transform(Vector2.ZERO)
			return
		for variant: int in 4:
			fixture.variant = variant
			var anchor := Vector2(128 if variant % 2 == 0 else 384, 96 if variant < 2 else 288)
			draw_set_transform(anchor, 0.0, Vector2.ONE * (0.75 if variant == 2 else 1.0))
			# Adjacent real Backdraft deadlines straddle the final72-tick warning.
			if not court.draw_ground(self, fixture, 427.0 if variant == 0 else 428.0, reduced, false): failed = true
			draw_set_transform(Vector2.ZERO)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	output = _option("--output")
	var expected := _option("--verify-user-data").replace("\\", "/").simplify_path().trim_suffix("/")
	var actual := OS.get_user_data_dir().replace("\\", "/").simplify_path().trim_suffix("/")
	if DisplayServer.get_name() == "headless" or not OS.get_cmdline_user_args().has("--no-lan-discovery") or expected.is_empty() or expected.to_lower() != actual.to_lower():
		_fail("Native window, --no-lan-discovery and exact isolated --verify-user-data are required"); return
	if not output.is_absolute_path() or DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output):
		_fail("--output requires a fresh absolute directory"); return
	if DirAccess.make_dir_recursive_absolute(output) != OK: _fail("Cannot create fresh output"); return
	for path: String in SOURCE_PATHS:
		sources[path] = FileAccess.get_sha256(path)
		if String(sources[path]).length() != 64: _fail("Cannot hash inspected source: " + path); return
	var language := VisualLanguage.new()
	if not language.load_from_file(): _fail("Visual language unavailable"); return
	candidate = Board.new()
	candidate.court = Court.new()
	candidate.hud = CompactCombatHud.new()
	reference = Board.new()
	reference.court = CourtBefore.new()
	reference.hud = HudBefore.new()
	for board: Board in [candidate, reference]:
		if not board.court.configure(language) or not board.hud.configure(language): _fail("Presenter configuration refused"); return
		if int(board.court.material_surface.stats().textures) <= 0: _fail("Native material bank unavailable; fallback-only equivalence cannot qualify"); return
	candidate_view = _viewport(candidate)
	reference_view = _viewport(reference)
	candidate.mode = "blank"
	reference.mode = "blank"
	if not await _compare("baseline/checker"): return
	for material: String in Court.MATERIALS:
		for phase: String in ["forming", "active", "decaying"]:
			for reduced: bool in [false, true]:
				for board: Board in [candidate, reference]:
					board.mode = "material"
					board.fixture.material = material
					board.fixture.wire = Court._material_wire(material)
					board.fixture.phase = phase
					board.reduced = reduced
				if not await _compare("material/%s/%s/%s" % [material, phase, "reduced" if reduced else "normal"]): return
	# Actual HUD rectangle formulas at both supported logical window sizes. Each
	# full panel is cropped into this same bounded viewport, not scaled to fit.
	for size: Vector2 in [Vector2(1280, 720), Vector2(960, 540)]:
		var panels: Array[Rect2] = [Rect2(16, 16, 312, 34), CompactCombatHud.session_panel(size, 16, 248, 34, 3),
			Rect2(16, size.y - 134, 270, 118), Rect2(size.x - 602, size.y - 86, 142, 70),
			Rect2(size.x - 602, size.y - 110, 112, 20), Rect2(size.x - 484, size.y - 110, 468, 20)]
		for index: int in panels.size():
			for opacity: float in [0.35, 0.95]:
				for board: Board in [candidate, reference]:
					board.mode = "hud"
					board.rectangle = panels[index]
					board.opacity = opacity
				if not await _compare("hud/%dx%d/panel%d/alpha%.2f" % [int(size.x), int(size.y), index, opacity]): return
	# Fill residency through the real geometry helper, then compare a distinct
	# actual panel at fractional placement to cover exact legacy overflow.
	for index: int in CompactCombatHud.MAX_PANEL_GEOMETRIES + 1:
		candidate.hud._panel_geometry(Rect2(index * 3, 120, 310, 37), 6)
	for board: Board in [candidate, reference]:
		board.mode = "hud"
		board.rectangle = Rect2(71.25, 92.75, 312, 34)
		board.opacity = 0.47
	if not await _compare("hud/cap-overflow/fractional-alpha"): return
	for board: Board in [candidate, reference]:
		var stats: Dictionary = board.court.material_surface.stats()
		if int(stats.translated_draws) <= 0 or int(stats.mesh_uploads) + int(stats.mesh_hits) <= 0:
			_fail("No actual native material draws observed; fallback-only result refused"); return
	var unchanged := true
	for path: String in SOURCE_PATHS: unchanged = unchanged and String(sources[path]) == FileAccess.get_sha256(path)
	if not unchanged: failures += 1
	var receipt := {"status": "passed" if failures == 0 else "failed", "scope": "Exact native pixels for arranged material/corner/alpha/source-seam and HUD panel geometry only. Not paid physics, natural recipe geometry, FPS or complete HUD layout acceptance.",
		"engine": Engine.get_version_info(), "renderer": RenderingServer.get_current_rendering_method(), "viewport": [512,384],
		"source_sha256": sources, "sources_unchanged": unchanged, "material_identities": Court.MATERIALS.size(), "comparisons": results.size(), "failed_comparisons": failures,
		"candidate_outline_cache": candidate.court.outline_cache_stats(), "candidate_material_surface": candidate.court.material_surface.stats(), "reference_material_surface": reference.court.material_surface.stats(), "rows": results}
	var file := FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE)
	if file == null: _fail("Cannot write receipt"); return
	file.store_string(JSON.stringify(receipt, "\t") + "\n")
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK: _fail("Receipt write failed"); return
	print("RENDER_EQUIVALENCE ", receipt.status, " comparisons=", results.size(), " mismatches=", failures)
	quit(0 if failures == 0 else 1)

func _viewport(board: Board) -> SubViewport:
	var view := SubViewport.new()
	view.size = SIZE
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	view.add_child(board)
	return view

func _compare(label: String) -> bool:
	var before_candidate := candidate.serial
	var before_reference := reference.serial
	candidate.queue_redraw()
	reference.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	if candidate.failed or reference.failed or candidate.serial <= before_candidate or reference.serial <= before_reference:
		_fail("Both actual presenters must redraw: " + label); return false
	var actual: Image = candidate_view.get_texture().get_image()
	var expected: Image = reference_view.get_texture().get_image()
	if actual == null or expected == null or actual.get_size() != SIZE or expected.get_size() != SIZE:
		_fail("Native viewport capture unavailable: " + label); return false
	actual.convert(Image.FORMAT_RGBA8)
	expected.convert(Image.FORMAT_RGBA8)
	var a := actual.get_data()
	var b := expected.get_data()
	var equal_pixels := a == b
	if label == "baseline/checker": checker_hash = _hash(b)
	elif _hash(a) == checker_hash or _hash(b) == checker_hash:
		_fail("Empty/background-only draw cannot qualify: " + label); return false
	results.append({"label": label, "equal": equal_pixels, "candidate_rgba_sha256": _hash(a), "reference_rgba_sha256": _hash(b)})
	if not equal_pixels:
		failures += 1
		if failures <= 8:
			actual.save_png(output.path_join("mismatch-%03d-candidate.png" % results.size()))
			expected.save_png(output.path_join("mismatch-%03d-reference.png" % results.size()))
	return true

static func _hash(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

static func _option(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix + "="): return argument.substr(prefix.length() + 1)
	return ""

func _fail(message: String) -> void:
	printerr("RENDER_EQUIVALENCE_FAILED: " + message)
	quit(1)
