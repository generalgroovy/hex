extends SceneTree
@warning_ignore_start("integer_division")
## Arranged render fixtures, not paid chemistry, physical play or FPS evidence.
## Production-only preloads let this same external script inspect a preserved PCK.
const Presenter = preload("res://src/presentation/hex_court_presenter.gd")
const Grid = preload("res://src/sim/hex/hex_grid.gd")
const Language = preload("res://src/presentation/visual_language.gd")
const Catalog = preload("res://src/content/ability_catalog.gd")
const SIZE := Vector2i(1280, 720)
const PHASES := ["forming", "active", "decaying"]
const WARMUP_FRAMES := 12
const TIMED_FRAMES := 120
const PAIRED_TIMED_FRAMES := 30
var output := ""
var viewport: SubViewport
var board: Board
var finishing := false


class Fixture:
	extends RefCounted
	var origin := Vector2i.ZERO
	var render_revision := 0
	var cells: Dictionary = {}
	var material := ""
	var wire := 0
	var phase := "active"
	var polygons: Dictionary = {}
	var expected_cells: Array[Vector2i] = []

	func _init(name: String, recipe_wire: int, selected_cells: Array[Vector2i] = []) -> void:
		material = name
		wire = recipe_wire
		var selected: Array[Vector2i] = selected_cells.duplicate()
		if selected.is_empty():
			selected.append(Vector2i.ZERO)
			selected.append_array(Grid.neighbors(Vector2i.ZERO))
		selected.sort()
		expected_cells = selected.duplicate()
		for cell: Vector2i in selected:
			cells[cell] = {"terrain": 0, "elevation": 0, "structure": 0}
			var polygon := PackedVector2Array()
			for point: Vector2i in Grid.vertices(cell): polygon.append(Vector2(point))
			polygons[cell] = polygon

	func view(_cell: Vector2i, _tick: float) -> Dictionary:
		return {material + "_quantity": 100, material + "_present": true,
			"fire_phase": phase if material == "fire" else "none", "steam_heat": 1000}

	func render_regions(cell: Vector2i, requested: String, _tick: float) -> Array[Dictionary]:
		if requested != material or not polygons.has(cell): return []
		var actual_phase := phase
		if material == "fire": actual_phase = "ignition" if phase == "forming" else ("cooling" if phase == "decaying" else phase)
		return [{"material": material, "recipe_wire_id": wire, "footprint_id": 1,
			"polygon": polygons[cell], "phase": actual_phase, "quantity": 100, "intensity": 1000,
			"danger": phase == "active" and (wire > 0 or material == "fire"),
			"owner": 1, "source_ids": [1], "expiry_tick": 720, "direction": Vector2i(1000, 0)}]

	func description() -> Dictionary:
		var rows: Array = []
		for cell: Vector2i in cells:
			var vertices: Array = []
			for point: Vector2 in polygons[cell]: vertices.append([int(point.x), int(point.y)])
			rows.append({"cell": [cell.x, cell.y], "fixed_polygon": vertices})
		return {"material": material, "recipe_wire": wire, "phase": phase, "cells": rows,
			"region_count": cells.size(), "geometry_sha256": JSON.stringify(rows).sha256_text()}

	func geometry_valid() -> bool:
		if expected_cells.size() not in [7, 672] or cells.size() != expected_cells.size() or polygons.size() != expected_cells.size(): return false
		for cell: Vector2i in expected_cells:
			if not cells.has(cell) or not polygons.has(cell): return false
			var expected := PackedVector2Array()
			for point: Vector2i in Grid.vertices(cell): expected.append(Vector2(point))
			if polygons[cell] != expected: return false
		return true


class Board:
	extends Node2D
	var presenter := Presenter.new()
	var fixtures: Array[Fixture] = []
	var stress_fixture: Fixture
	var hit_wires: Array[int] = []
	var page := 0
	var reduced := false
	var phase := "active"
	var hits := false
	var stress := false
	var tick := 96.0
	var failed := false
	var draw_serial := 0
	var draw_cpu_usec := 0
	var last_error := ""

	func configure() -> bool:
		last_error = ""
		var language := Language.new()
		var catalog := Catalog.new()
		if not language.load_from_file():
			last_error = "VisualLanguage load: " + language.last_error
			return false
		if not catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"):
			last_error = "AbilityCatalog load: " + catalog.last_error
			return false
		if not presenter.configure(language):
			last_error = "HexCourtPresenter rejected the loaded visual language"
			return false
		for index: int in Presenter.MATERIALS.size():
			fixtures.append(Fixture.new(Presenter.MATERIALS[index], 0 if index < 8 else 301 + index - 8))
			if not fixtures[-1].geometry_valid():
				last_error = "Invalid seven-cell geometry: " + Presenter.MATERIALS[index]
				return false
		var stress_cells: Array[Vector2i] = []
		for row: int in 24:
			for column: int in 28: stress_cells.append(Vector2i(column, row))
		stress_fixture = Fixture.new("water", 0, stress_cells)
		if not stress_fixture.geometry_valid():
			last_error = "Invalid672-cell Water stress geometry"
			return false
		for element: String in Presenter.INGREDIENT_MATERIALS:
			var wire := 0
			for candidate: int in catalog.runtime_wire_ids:
				var ability := catalog.ability_from_wire(candidate)
				if String(ability.get("element", "")) == element and Catalog._spell_family(ability) == "bolt":
					wire = candidate
					break
			if wire == 0:
				last_error = "No runtime %s bolt among%d catalog wires" % [element, catalog.runtime_wire_ids.size()]
				return false
			hit_wires.append(wire)
		if fixtures.size() != 44 or hit_wires.size() != 8:
			last_error = "Gallery inventory mismatch: %d materials, %d hit wires" % [fixtures.size(), hit_wires.size()]
			return false
		return true

	func _draw() -> void:
		draw_serial += 1
		draw_cpu_usec = 0
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color("202b2b"))
		label(Vector2(24, 32), "H.E.X. / ARRANGED MATERIAL GALLERY / " + ("REDUCED" if reduced else "NORMAL"), 23)
		label(Vector2(24, 57), "Presentation fixtures only; not paid reactions, natural recipe footprints, playtest or FPS proof.", 16)
		if stress:
			label(Vector2(24, 80), "STRESS / 672 contiguous canonical Water cells / 28x24 axial grid / 1x native / active", 16)
			draw_rect(Rect2(16, 102, 1248, 576), Color("a49679"))
			draw_set_transform(Vector2(150, 150))
			var started := Time.get_ticks_usec()
			if not presenter.draw_ground(self, stress_fixture, tick, reduced, false): failed = true
			draw_cpu_usec = Time.get_ticks_usec() - started
			draw_set_transform(Vector2.ZERO)
			label(Vector2(24, 704), "Arranged pressure case above512 unique polygons; timing is warmed CPU submission, not paid density or FPS acceptance.", 15)
			return
		label(Vector2(24, 80), "ACTUAL HIT CUES / reported damage 3, 9, 14 / native scale" if hits else "Page %d / 6 | %s | seven contiguous canonical hexes | 1x native + 2x detail" % [page + 1, phase.to_upper()], 16)
		for slot: int in 8:
			var index := slot if hits else page * 8 + slot
			if index >= fixtures.size(): break
			var card := Vector2(20 + slot % 4 * 312, 102 + slot / 4 * 286)
			draw_rect(Rect2(card, Vector2(300, 270)), Color("a49679"))
			draw_rect(Rect2(card, Vector2(300, 34)), Color("34403a"))
			label(card + Vector2(12, 23), fixtures[index].material.replace("_", " ").to_upper(), 16)
			if hits:
				for tier: int in 3:
					var damage: int = [3000, 9000, 14000][tier]
					var anchor := card + Vector2(54 + tier * 96, 144)
					var cue := {"kind": "impact", "event_type": "projectile_hit", "source_wire_id": hit_wires[index],
						"position": anchor, "damage": damage, "age_ticks": 6, "duration": 0.55, "remaining": 0.50}
					var started := Time.get_ticks_usec()
					if not presenter.draw_cue(self, cue, reduced): failed = true
					draw_cpu_usec += Time.get_ticks_usec() - started
					label(anchor + Vector2(-12, 66), str(damage / 1000), 16, Color("28332e"))
			else:
				var fixture: Fixture = fixtures[index]
				fixture.phase = phase
				for magnification: int in [1, 2]:
					var anchor := card + Vector2(64 if magnification == 1 else 210, 143)
					draw_set_transform(anchor, 0, Vector2.ONE * magnification)
					var started := Time.get_ticks_usec()
					if not presenter.draw_ground(self, fixture, tick, reduced, false): failed = true
					draw_cpu_usec += Time.get_ticks_usec() - started
					draw_set_transform(Vector2.ZERO)
					label(card + Vector2(53 if magnification == 1 else 199, 244), "%dx" % magnification, 15, Color("28332e"))
		label(Vector2(24, 704), "Same coverage in all modes/phases. Cosmetic preparation/decay marks may occupy less than the legal whole-cell footprint.", 15)

	func label(point: Vector2, value: String, size: int, color: Color = Color("eee5cd")) -> void:
		draw_string(ThemeDB.fallback_font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

	func cache_metadata() -> Dictionary:
		for property: Dictionary in presenter.get_property_list():
			if String(property.name) == "material_surface":
				var helper: Variant = presenter.get("material_surface")
				if helper is RefCounted and helper.has_method("stats"): return helper.call("stats")
		return {"available": false, "reason": "Preserved presenter has no material-surface diagnostics"}

	func set_material_surfaces(enabled: bool) -> bool:
		for property: Dictionary in presenter.get_property_list():
			if String(property.name) == "material_surfaces_enabled" and int(property.type) == TYPE_BOOL:
				presenter.set("material_surfaces_enabled", enabled)
				return presenter.get("material_surfaces_enabled") == enabled
		return false


func _initialize() -> void:
	root.hide()
	_run.call_deferred()


func _run() -> void:
	var paired_only := false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		if argument == "--paired-only": paired_only = true
	var normalized := output.replace("\\", "/")
	var permitted := normalized.begins_with("res://.godot/hex-material-gallery-") or (output.is_absolute_path() and normalized.contains("/.godot/hex-material-gallery-"))
	if not permitted or ".." in output or not output.get_file().begins_with("hex-material-gallery-") or DirAccess.dir_exists_absolute(output) or DisplayServer.get_name() == "headless":
		_fail("Provide a fresh native --output=res://.godot/hex-material-gallery-NAME or absolute equivalent")
		return
	board = Board.new()
	if not board.configure():
		_fail("Gallery configuration failed: " + board.last_error)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("Cannot create fresh gallery directory")
		return
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	viewport.add_child(board)
	if paired_only:
		await _run_paired()
		return
	var frames: Array[Dictionary] = []
	for reduced: bool in [false, true]:
		board.reduced = reduced
		for phase: String in PHASES:
			board.phase = phase
			for page: int in 6:
				board.page = page
				if not await _render(): return
				var leaf := "%s-%s-%02d.png" % ["reduced" if reduced else "normal", phase, page + 1]
				if not _save(leaf): return
				var samples: Array[Dictionary] = []
				for index: int in range(page * 8, mini((page + 1) * 8, board.fixtures.size())):
					samples.append(board.fixtures[index].description())
				frames.append({"image": leaf, "mode": "reduced" if reduced else "normal", "phase": phase,
					"native_scale": 1, "detail_scale": 2, "samples": samples, "draw_cpu_usec": board.draw_cpu_usec})
		board.hits = true
		if not await _render(): return
		var leaf := "hits-%s.png" % ("reduced" if reduced else "normal")
		if not _save(leaf): return
		frames.append({"image": leaf, "mode": "reduced" if reduced else "normal", "public_path": "HexCourtPresenter.draw_cue",
			"source_wires": board.hit_wires, "reported_damage": [3000, 9000, 14000], "age_ticks": 6})
		board.hits = false
	var timings: Array[Dictionary] = []
	board.page = 0
	board.phase = "active"
	for stress: bool in [false, true]:
		board.stress = stress
		for reduced: bool in [false, true]:
			board.reduced = reduced
			for _warm: int in WARMUP_FRAMES:
				if not await _render(): return
			var before := board.cache_metadata()
			var samples: Array[int] = []
			for _frame: int in TIMED_FRAMES:
				if not await _render(): return
				samples.append(board.draw_cpu_usec)
			if stress:
				var leaf := "stress-672-%s.png" % ("reduced" if reduced else "normal")
				if not _save(leaf): return
				var geometry := board.stress_fixture.description()
				frames.append({"image": leaf, "mode": "reduced" if reduced else "normal", "phase": "active", "native_scale": 1,
					"cell_count": 672, "axial_q": [0, 27], "axial_r": [0, 23], "geometry_sha256": geometry.geometry_sha256})
			samples.sort()
			var total := 0
			for elapsed: int in samples: total += elapsed
			timings.append({"case": "stress-672" if stress else "ingredients-page", "mode": "reduced" if reduced else "normal",
				"frames": TIMED_FRAMES, "warmup_frames": WARMUP_FRAMES, "unique_polygons": 672 if stress else 7,
				"scope": "CPU public draw_ground submission only; labels/readback excluded; not GPU/FPS/capacity",
				"draw_ground_calls_per_frame": 1 if stress else 16, "cell_submissions_per_frame": 672 if stress else 112,
				"mean_usec": float(total) / samples.size(), "median_usec": samples[samples.size() / 2],
				"p95_usec": samples[ceili(samples.size() * 0.95) - 1], "max_usec": samples[-1], "cache_before": before, "cache_after": board.cache_metadata()})
	var presenter_source: String = board.presenter.get_script().source_code
	var receipt := {"capture_succeeded": true, "scope": "Arranged production renderer samples, not paid chemistry, natural recipe footprints, physical play or human acceptance",
		"viewport": [SIZE.x, SIZE.y], "ingredients": 8, "products": 36, "cells_per_sample": 7,
		"visibility": "All arranged regions visible; no player, fog or collision occlusion fixture", "frames": frames,
		"timings": timings, "surface_cache": board.cache_metadata(), "renderer": RenderingServer.get_video_adapter_name(),
		"probe_source_sha256": String(get_script().source_code).sha256_text(),
		"presenter_source_available": not presenter_source.is_empty(),
		"presenter_source_sha256": presenter_source.sha256_text() if not presenter_source.is_empty() else "unavailable",
		"comparison": "Run this identical external script against source and preserved PCK; compare matching filenames and timing scope"}
	var file := FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE)
	if file == null:
		_fail("Cannot save gallery receipt")
		return
	file.store_string(JSON.stringify(receipt, "\t") + "\n")
	file.close()
	print("CAPTURE ONLY:40 arranged material/hit/stress boards;480 warmed CPU submission samples;not paid gameplay or FPS acceptance")
	finishing = true
	_finish.call_deferred(0)


func _run_paired() -> void:
	# Same presenter and retained caches throughout. ABBA balances simple order
	# drift; it is still a CPU-submission diagnostic, not a GPU/FPS benchmark.
	if not board.set_material_surfaces(true):
		_fail("Paired lane requires a presenter with the material_surfaces_enabled boolean switch")
		return
	var initial_cache := board.cache_metadata()
	if int(initial_cache.get("textures", 0)) <= 0:
		_fail("Paired lane requires a loaded material-surface bank, not two fallback paths")
		return
	board.stress = true
	board.phase = "active"
	var geometry: Dictionary = board.stress_fixture.description()
	var geometry_hash: String = geometry.geometry_sha256
	var blocks: Array[Dictionary] = []
	var pooled: Array[Dictionary] = []
	var frames: Array[Dictionary] = []
	for reduced: bool in [false, true]:
		board.reduced = reduced
		var mode := "reduced" if reduced else "normal"
		var enabled_samples: Array[int] = []
		var fallback_samples: Array[int] = []
		for block_index: int in 4:
			var enabled: bool = block_index in [0, 3]
			if not board.set_material_surfaces(enabled):
				_fail("Paired lane could not select its material-surface mode")
				return
			var cache_before_warm := board.cache_metadata()
			for _warm: int in WARMUP_FRAMES:
				if not await _render(): return
			var cache_before := board.cache_metadata()
			var samples: Array[int] = []
			for _frame: int in PAIRED_TIMED_FRAMES:
				if not await _render(): return
				samples.append(board.draw_cpu_usec)
			var cache_after := board.cache_metadata()
			if not board.stress_fixture.geometry_valid() or String(board.stress_fixture.description().geometry_sha256) != geometry_hash:
				_fail("Paired lane changed its exact canonical stress geometry")
				return
			var summary := _timing_summary(samples)
			summary.merge({"mode": mode, "block": block_index + 1, "lane": "A" if enabled else "B",
				"material_surfaces_enabled": enabled, "warmup_frames": WARMUP_FRAMES,
				"samples_usec": samples, "cache_before_warm": cache_before_warm,
				"cache_before": cache_before, "cache_after": cache_after, "geometry_sha256": geometry_hash})
			blocks.append(summary)
			if enabled: enabled_samples.append_array(samples)
			else: fallback_samples.append_array(samples)
		var enabled_summary := _timing_summary(enabled_samples)
		var fallback_summary := _timing_summary(fallback_samples)
		pooled.append({"mode": mode, "A_enabled": enabled_summary, "B_fallback": fallback_summary,
			"enabled_to_fallback_median_ratio": float(enabled_summary.median_usec) / maxf(1.0, float(fallback_summary.median_usec)),
			"enabled_to_fallback_p95_ratio": float(enabled_summary.p95_usec) / maxf(1.0, float(fallback_summary.p95_usec))})
		var leaf := "paired-stress-672-%s.png" % mode
		if not _save(leaf): return
		frames.append({"image": leaf, "mode": mode, "lane": "A", "material_surfaces_enabled": true,
			"cell_count": 672, "geometry_sha256": geometry_hash})
	var presenter_source: String = board.presenter.get_script().source_code
	var receipt := {"capture_succeeded": true, "lane": "paired-only", "scope": "Same-process arranged CPU public draw_ground submission only; labels/readback excluded; not GPU/FPS/capacity or paid gameplay",
		"viewport": [SIZE.x, SIZE.y], "sequence_per_mode": ["A", "B", "B", "A"],
		"A": "material_surfaces_enabled=true", "B": "material_surfaces_enabled=false; existing fallback",
		"presenter_lifetime": "One configured presenter and its caches retained across all eight blocks",
		"tick": board.tick, "phase": "active", "draw_ground_calls_per_frame": 1, "cell_submissions_per_frame": 672,
		"geometry": geometry, "frames": frames, "blocks": blocks, "pooled": pooled,
		"surface_cache": board.cache_metadata(), "renderer": RenderingServer.get_video_adapter_name(),
		"probe_source_sha256": String(get_script().source_code).sha256_text(),
		"presenter_source_available": not presenter_source.is_empty(),
		"presenter_source_sha256": presenter_source.sha256_text() if not presenter_source.is_empty() else "unavailable"}
	var file := FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE)
	if file == null:
		_fail("Cannot save paired gallery receipt")
		return
	file.store_string(JSON.stringify(receipt, "\t") + "\n")
	file.close()
	print("DIAGNOSTIC ONLY:paired672-cell ABBA Normal/Reduced;240 timed CPU submissions;96 warmups;2 enabled boards;not FPS acceptance")
	finishing = true
	_finish.call_deferred(0)


func _timing_summary(samples: Array[int]) -> Dictionary:
	var ordered: Array[int] = samples.duplicate()
	ordered.sort()
	var total := 0
	for elapsed: int in ordered: total += elapsed
	return {"frames": ordered.size(), "mean_usec": float(total) / ordered.size(),
		"median_usec": float(ordered[(ordered.size() - 1) / 2] + ordered[ordered.size() / 2]) * 0.5,
		"p95_usec": ordered[ceili(ordered.size() * 0.95) - 1], "max_usec": ordered[-1]}


func _render() -> bool:
	var previous := board.draw_serial
	board.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	if board.failed or board.draw_serial <= previous:
		_fail("Production presenter refused a fixture or native redraw did not occur")
		return false
	return true


func _save(leaf: String) -> bool:
	if not board.stress_fixture.geometry_valid():
		_fail("Renderer changed an arranged stress mask")
		return false
	for fixture: Fixture in board.fixtures:
		if not fixture.geometry_valid():
			_fail("Renderer changed an arranged canonical cell mask")
			return false
	var rendered := viewport.get_texture().get_image()
	if rendered == null or rendered.get_size() != SIZE or rendered.save_png(output.path_join(leaf)) != OK:
		_fail("Native gallery image failed: " + leaf)
		return false
	return true


func _fail(message: String) -> void:
	if finishing: return
	finishing = true
	push_error(message)
	_finish.call_deferred(1)


func _finish(exit_code: int) -> void:
	# Defer until the capture/configuration stack has unwound, then release both
	# unattached configuration failures and the live board's retained draw RIDs.
	if is_instance_valid(board): board.free()
	board = null
	if is_instance_valid(viewport): viewport.free()
	viewport = null
	# Give the rendering server time to process texture/canvas releases before
	# SceneTree shutdown. This is cleanup only, outside all measured samples.
	await process_frame
	await process_frame
	quit(exit_code)
