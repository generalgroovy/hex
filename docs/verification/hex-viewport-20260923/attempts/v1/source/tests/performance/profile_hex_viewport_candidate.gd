extends "res://tests/performance/profile_hex_draw_components.gd"
@warning_ignore_start("integer_division")

const ViewportPresenter = preload("res://tests/support/hex_viewport_harness.gd")
const ViewportCandidate = preload("res://tests/support/hex_viewport_candidate.gd")
const BootstrapScript = preload("res://src/app/bootstrap.gd")
const Grid = preload("res://src/sim/hex/hex_grid.gd")
const CYCLES := 4
const BLOCK_SAMPLES := 5
const SAMPLES_PER_ARM := CYCLES * 2 * BLOCK_SAMPLES
const EXPECTED_TIMING_CASES := 4
const EXPECTED_PIXEL_CASES := 55 # 16 legal camera/mode + 7 synthetic materials/practice + 32 boundary/corner.
const EXPECTED_VISIBILITY_CASES := 103 # 7 fail-open + 8 directions * 4 relations * 3 zoom levels.
const EXPECTED_FALLBACK_CASES := 3

var visibility_cases_completed := 0
var pixel_cases_completed := 0
var timing_cases_completed := 0
var receipt_path_valid := false
var fallback_cases_completed := 0
var completed_pixel_evidence: Array[Dictionary] = []
var completed_timing_evidence: Array[Dictionary] = []


class GenericCourt extends RefCounted:
	var origin := Vector2i.ZERO
	var cells := {Vector2i.ZERO: {}}
	var render_revision := 0
	var active_view := false

	func occupied_cells() -> Dictionary:
		return {Vector2i.ZERO: 1}

	func view(_cell: Vector2i, _tick: float) -> Dictionary:
		return {"fire_phase": "none", "steam_heat": 1000, "water_present": active_view, "water_quantity": 1 if active_view else 0}

	func render_regions(_cell: Vector2i, _material: String, _tick: float) -> Array[Dictionary]:
		return []


class DerivedWorld extends HexChemistryWorld:
	func view(cell: Vector2i, tick: float) -> Dictionary:
		var result: Dictionary = super.view(cell, tick)
		result["subclass_marker"] = "viewport-fallback"
		return result


class NativeHarness extends CoachHarness:
	var forced_camera_origin := Vector2.INF
	var draw_invocations := 0
	var total_draw_us := 0

	func install_timers() -> bool:
		var presenter := ViewportPresenter.new()
		if not presenter.configure(visual_language):
			return false
		hex_court_presenter = presenter
		return true

	func _camera_origin(focus_position: Vector2) -> Vector2:
		return forced_camera_origin if forced_camera_origin.is_finite() else super._camera_origin(focus_position)

	func _draw() -> void:
		var began: int = Time.get_ticks_usec()
		super._draw()
		total_draw_us = Time.get_ticks_usec() - began
		draw_invocations += 1


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	receipt_path_valid = output_path.begins_with("res://.godot/hex-viewport-candidate-") and output_path.ends_with(".json") and not ".." in output_path and not FileAccess.file_exists(output_path)
	_check(receipt_path_valid, "viewport receipt path is fresh and scoped")
	_check(DisplayServer.get_name() != "headless" and root.get_visible_rect().size == Vector2(1280, 720), "native 1280x720 display is active")
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "production ability catalogue loads")
	_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "production champion catalogue loads")
	_check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "production campus loads")
	definition = HexWorldDefinition.from_campus(layout)
	_check(definition != null and definition.eligible_cells.size() == 2_766, "production campus retains 2,766 cells")
	var captures: String = output_path.trim_suffix(".json") + "-frames"
	_check(not DirAccess.dir_exists_absolute(captures), "representative capture directory is fresh")
	if failures > 0:
		_finish({})
		return
	_check(DirAccess.make_dir_recursive_absolute(captures) == OK, "representative capture directory opens")
	var source_before: Dictionary = _candidate_source_hashes()
	var identity_before: Dictionary = _runtime_identity()
	var identity_sha_before: String = FileAccess.get_sha256(RuntimeBuildIdentity.MANIFEST_PATH)
	_check(_hashes_complete(source_before) and not identity_before.is_empty() and identity_sha_before.length() == 64, "source and runtime identity guards are complete before native work")
	_visibility_equivalence_cases()
	_check(visibility_cases_completed == EXPECTED_VISIBILITY_CASES, "all %d visibility boundary/fail-open cases complete" % EXPECTED_VISIBILITY_CASES)
	_public_fallback_cases()
	_check(fallback_cases_completed == EXPECTED_FALLBACK_CASES, "default, generic, subclass and malformed return behavior completes")
	if failures > 0:
		_finish({})
		return

	var legal_worlds: Dictionary = {}
	for case_name: String in ["sustained-distributed", "dense-crucible"]:
		var fixture: Dictionary = _fixture(case_name)
		var world: SimWorld = fixture.world
		for unused: int in range(WARMUP_TICKS):
			_check(world.step(_commands(world, fixture.targets, case_name, false, false)), case_name + " neutral warmup advances")
		for unused: int in range(ACTIVE_TICKS):
			_check(world.step(_commands(world, fixture.targets, case_name, true, false)), case_name + " legal paid work advances")
		_check(world.players.size() == 8 and world.hex_court.conservation_valid() and int(world.hex_court.metrics.admitted) > 0, case_name + " is a conserved paid eight-actor tick-160 scene")
		legal_worlds[case_name] = world
	if failures > 0:
		_finish({})
		return

	var pixel_cases: Array[Dictionary] = []
	pixel_cases.append_array(await _legal_pixel_matrix(legal_worlds["dense-crucible"], captures))
	var synthetic_world: SimWorld = _synthetic_material_world()
	_check(synthetic_world != null, "synthetic material-extreme world builds")
	if synthetic_world != null:
		_frame_ownership_case(synthetic_world.hex_court, float(synthetic_world.tick))
		pixel_cases.append_array(await _synthetic_material_pixel_matrix(synthetic_world, captures))
	var boundary_world: SimWorld = _boundary_world()
	_check(boundary_world != null, "synthetic boundary world builds")
	if boundary_world != null:
		pixel_cases.append_array(await _boundary_pixel_matrix(boundary_world, captures))
	_check(pixel_cases_completed == EXPECTED_PIXEL_CASES and pixel_cases.size() == EXPECTED_PIXEL_CASES, "all %d full-frame RGBA8 oracle cases complete" % EXPECTED_PIXEL_CASES)
	for result: Dictionary in pixel_cases:
		_check(_pixel_case_complete(result), String(result.get("case", "pixel")) + " has exact pixels, result, authority, regions and counts")
	if failures > 0:
		_finish({})
		return

	var timing_cases: Array[Dictionary] = []
	for case_name: String in ["sustained-distributed", "dense-crucible"]:
		var modes: Array[String] = ["normal", "reduced"]
		if case_name == "dense-crucible":
			modes.reverse()
		for mode: String in modes:
			timing_cases.append(await _timing_case(legal_worlds[case_name], case_name, mode))
	_check(timing_cases_completed == EXPECTED_TIMING_CASES and timing_cases.size() == EXPECTED_TIMING_CASES, "all four legal timing cases complete")
	for result: Dictionary in timing_cases:
		_check(_timing_case_complete(result), String(result.get("case", "timing")) + " has every alternating block and sample")
	var source_after: Dictionary = _candidate_source_hashes()
	var identity_after: Dictionary = _runtime_identity()
	var identity_sha_after: String = FileAccess.get_sha256(RuntimeBuildIdentity.MANIFEST_PATH)
	_check(source_after == source_before, "all profiled sources remain byte-identical")
	_check(identity_after == identity_before and identity_sha_after == identity_sha_before, "runtime identity remains byte-identical")
	if failures > 0:
		_finish({})
		return

	var receipt: Dictionary = {
		"schema_version": 1,
		"profile_version": "hex-viewport-candidate-native-abba-v1",
		"engine": Engine.get_version_info().get("string", ""),
		"display_server": DisplayServer.get_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"platform": {"os": OS.get_name(), "processor": OS.get_processor_name(), "logical_processor_count": OS.get_processor_count()},
		"viewport": [1280, 720],
		"map_hash": definition.map_hash,
		"definition_hash": definition.definition_hash,
		"cycles": CYCLES,
		"block_samples": BLOCK_SAMPLES,
		"samples_per_arm_per_timing_case": SAMPLES_PER_ARM,
		"batch_size": 1,
		"order": "ABBA on even cycles; BAAB on odd cycles",
		"visibility_cases_completed": visibility_cases_completed,
		"fallback_cases_completed": fallback_cases_completed,
		"pixel_cases_completed": pixel_cases_completed,
		"timing_cases_completed": timing_cases_completed,
		"pixel_cases": pixel_cases,
		"timing_cases": timing_cases,
		"source_sha256": source_before,
		"runtime_identity": identity_before,
		"runtime_identity_path": RuntimeBuildIdentity.MANIFEST_PATH,
		"runtime_identity_sha256": identity_sha_before,
		"assertions": assertions,
		"failures": failures,
		"scope": "Test-only native full-frame RGBA8 oracle and legal paid-scene CPU submission timing for conservative material-region rejection. Full D6 preparation, validation, cover extraction, semantic edge counts, cover repaint, apron, stone, rim, authority and Bootstrap drawing remain active. Synthetic boundary/material cases are pixel controls only and are not gameplay workloads.",
		"timing_semantics": "Legal timing uses frozen tick-160 eight-actor distributed/dense paid states, four balanced ABBA/BAAB cases and 40 samples per arm. Candidate diagnostics, region hashing, image readback, exact pixel comparisons, authority hashes, fixture setup and source/identity checks are outside the presenter and Bootstrap CPU timers. present_elapsed includes rendering completion and is not additive. No GPU, sustained cadence, network, capacity, export or release claim.",
	}
	_finish(receipt)


func _visibility_equivalence_cases() -> void:
	var visible := Rect2(Vector2.ZERO, Vector2(1280, 720))
	var valid_region := {"polygon": PackedVector2Array([Vector2(10, 10), Vector2(20, 10), Vector2(20, 20), Vector2(10, 20)])}
	for malformed: Dictionary in [
		{},
		{"polygon": []},
		{"polygon": PackedVector2Array()},
		{"polygon": PackedVector2Array([Vector2.ZERO, Vector2.ONE])},
		{"polygon": PackedVector2Array([Vector2.ZERO, Vector2.ONE, Vector2(2, 2)])},
		{"polygon": PackedVector2Array([Vector2.ZERO, Vector2(INF, 0), Vector2.ONE])},
	]:
		_check(ViewportCandidate.region_visible(malformed, visible), "malformed/degenerate polygon fails open")
		visibility_cases_completed += 1
	var overflow := Rect2(Vector2(2.0e38, 0), Vector2(2.0e38, 10))
	_check(not overflow.end.is_finite(), "overflow fixture has a nonfinite rectangle end")
	_check(ViewportCandidate.region_visible(valid_region, overflow), "nonfinite rectangle end fails open")
	visibility_cases_completed += 1
	for zoom_percent: int in [50, 75, 100]:
		var zoom: float = float(zoom_percent) / 100.0
		var grown: Rect2 = ViewportCandidate.grown_visible_world_rect(visible, zoom)
		for direction: String in ["left", "right", "top", "bottom", "top-left", "top-right", "bottom-left", "bottom-right"]:
			for relation: String in ["inside", "equal", "outside", "cross"]:
				var region: Dictionary = _analytic_boundary_region(grown, visible, direction, relation, zoom)
				var expected: bool = relation != "outside"
				_check(ViewportCandidate.region_visible(region, grown) == expected, "%s %s at %d%% uses inclusive conservative bounds" % [direction, relation, zoom_percent])
				visibility_cases_completed += 1


func _public_fallback_cases() -> void:
	var language := VisualLanguage.new()
	_check(language.load_from_file(), "fallback controls load production visual language")
	var presenter := ViewportPresenter.new()
	_check(presenter.configure(language), "fallback controls configure viewport presenter")
	var canvas := Node2D.new()
	var visible := Rect2(Vector2.ZERO, Vector2(1280, 720))
	var generic := GenericCourt.new()
	var generic_baseline: bool = presenter.draw_ground(canvas, generic, 0.0, false, false)
	var generic_candidate: bool = presenter.draw_ground_visible(canvas, generic, 0.0, false, false, visible, 1.0, {}, false)
	_check(generic_baseline and generic_candidate, "generic inactive court preserves successful default and explicit-visible returns")
	fallback_cases_completed += 1
	var malformed := GenericCourt.new()
	malformed.active_view = true
	var malformed_baseline: bool = presenter.draw_ground(canvas, malformed, 0.0, false, false)
	var malformed_candidate: bool = presenter.draw_ground_visible(canvas, malformed, 0.0, false, false, visible, 1.0, {}, false)
	_check(not malformed_baseline and not malformed_candidate, "malformed active view without regions preserves fail-closed return")
	fallback_cases_completed += 1
	var derived := DerivedWorld.new()
	_check(derived.configure_geometry(Vector2i.ZERO, [Vector2i.ZERO]), "derived fallback control configures")
	var derived_baseline: bool = presenter.draw_ground(canvas, derived, 0.0, false, false)
	var derived_candidate: bool = presenter.draw_ground_visible(canvas, derived, 0.0, false, false, visible, 1.0, {}, false)
	_check(derived_baseline and derived_candidate, "derived world keeps generic presentation path and return")
	_check(presenter._prepare_court(derived, true), "derived full membership prepares without drawing")
	var derived_frame: Dictionary = presenter._prepare_frame_bundle(derived, 0.0)
	_check(derived_frame.get("views", {}).get(Vector2i.ZERO, {}).get("subclass_marker", "") == "viewport-fallback", "derived view override remains observed")
	fallback_cases_completed += 1
	canvas.free()


func _frame_ownership_case(court: HexChemistryWorld, tick: float) -> void:
	var language := VisualLanguage.new()
	_check(language.load_from_file(), "frame ownership control loads visual language")
	var presenter := ViewportPresenter.new()
	_check(presenter.configure(language) and presenter._prepare_court(court, false), "frame ownership control prepares synthetic court")
	var first: Dictionary = presenter._prepare_frame_bundle(court, tick)
	var second: Dictionary = presenter._prepare_frame_bundle(court, tick)
	_check(not first.is_empty() and var_to_bytes(first) == var_to_bytes(second), "independent frame bundles begin byte-identical")
	var mutated := false
	for material_value: Variant in (first.get("regions", {}) as Dictionary).values():
		if not material_value is Dictionary:
			continue
		for rows_value: Variant in (material_value as Dictionary).values():
			if rows_value is Array and not rows_value.is_empty():
				var region: Dictionary = rows_value[0]
				region.source_ids.append(999_999)
				mutated = true
				break
		if mutated:
			break
	_check(mutated and var_to_bytes(first) != var_to_bytes(second), "mutating one prepared output does not alias the independent output")


func _analytic_boundary_region(grown: Rect2, visible: Rect2, direction: String, relation: String, zoom: float) -> Dictionary:
	var size := Vector2(20, 20)
	var position := visible.get_center() - size * 0.5
	var epsilon := 0.001
	var inside_delta := epsilon if relation == "inside" else 0.0 if relation == "equal" else -epsilon
	var crosses := relation == "cross"
	if direction.contains("left"):
		position.x = visible.position.x - size.x + 1.0 / zoom if crosses else grown.position.x - size.x + inside_delta
	if direction.contains("right"):
		position.x = visible.end.x - 1.0 / zoom if crosses else grown.end.x - inside_delta
	if direction.contains("top"):
		position.y = visible.position.y - size.y + 1.0 / zoom if crosses else grown.position.y - size.y + inside_delta
	if direction.contains("bottom"):
		position.y = visible.end.y - 1.0 / zoom if crosses else grown.end.y - inside_delta
	var polygon := PackedVector2Array([position, position + Vector2(size.x, 0), position + size, position + Vector2(0, size.y)])
	return {"polygon": polygon}


func _legal_pixel_matrix(world: SimWorld, captures: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var viewport := Vector2i(1280, 720)
	var canvas: Vector2i = layout.canvas_size
	var focuses: Array[Dictionary] = [
		{"label": "center", "value": Vector2(canvas) * 0.5},
		{"label": "left", "value": Vector2(0, canvas.y * 0.5)},
		{"label": "right", "value": Vector2(canvas.x, canvas.y * 0.5)},
		{"label": "top", "value": Vector2(canvas.x * 0.5, 0)},
		{"label": "bottom", "value": Vector2(canvas.x * 0.5, canvas.y)},
		{"label": "top-left", "value": Vector2.ZERO},
		{"label": "top-right", "value": Vector2(canvas.x, 0)},
		{"label": "bottom-left", "value": Vector2(0, canvas.y)},
		{"label": "bottom-right", "value": Vector2(canvas)},
	]
	for focus: Dictionary in focuses:
		var camera_origin: Vector2 = BootstrapScript.camera_origin_for(focus.value, viewport, canvas, layout.reserved_ui_top, 75)
		result.append(await _pixel_control(world, "legal-camera-" + String(focus.label), "normal", 75, camera_origin, captures, String(focus.label) in ["center", "top-left", "bottom-right"]))
	for zoom_percent: int in [50, 100]:
		var center_origin: Vector2 = BootstrapScript.camera_origin_for(Vector2(canvas) * 0.5, viewport, canvas, layout.reserved_ui_top, zoom_percent)
		result.append(await _pixel_control(world, "legal-center-%d" % zoom_percent, "normal", zoom_percent, center_origin, captures, false))
	result.append(await _pixel_control(world, "snapped-half-step-50", "normal", 50, Vector2(123, 77), captures, false))
	result.append(await _pixel_control(world, "snapped-half-step-100", "normal", 100, Vector2(123.5, 77.5), captures, false))
	for zoom_percent: int in [50, 75, 100]:
		var reduced_origin: Vector2 = BootstrapScript.camera_origin_for(Vector2(canvas) * 0.5, viewport, canvas, layout.reserved_ui_top, zoom_percent)
		result.append(await _pixel_control(world, "legal-reduced-center-%d" % zoom_percent, "reduced", zoom_percent, reduced_origin, captures, zoom_percent == 75))
	return result


func _synthetic_material_pixel_matrix(world: SimWorld, captures: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var court: HexChemistryWorld = world.hex_court
	for mode: String in ["normal", "reduced"]:
		for zoom_percent: int in [50, 75, 100]:
			var anchor_material := "water" if zoom_percent == 50 else "magma" if zoom_percent == 75 else "fortify"
			var anchor_cell: Vector2i = _material_cell(court, anchor_material)
			var camera_origin: Vector2 = _left_crossing_camera(court, anchor_cell, zoom_percent)
			var positive := {"cell": anchor_cell, "material": anchor_material}
			result.append(await _direct_pixel_control(world, "synthetic-material-extremes-%s-%d" % [mode, zoom_percent], mode, zoom_percent, camera_origin, captures, zoom_percent == 75, false, true, positive))
	var fortify_cell: Vector2i = _material_cell(court, "fortify")
	result.append(await _direct_pixel_control(world, "synthetic-practice-district-base", "normal", 75, _left_crossing_camera(court, fortify_cell, 75), captures, true, true, true, {"cell": fortify_cell, "material": "fortify"}))
	return result


func _boundary_pixel_matrix(world: SimWorld, captures: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var court: HexChemistryWorld = world.hex_court
	var occupied_keys: Array = court.occupied_cells().keys()
	_check(not occupied_keys.is_empty(), "synthetic boundary fixture has an occupied cell")
	if occupied_keys.is_empty():
		return result
	var occupied: Vector2i = occupied_keys[0]
	for direction: String in ["left", "right", "top", "bottom", "top-left", "top-right", "bottom-left", "bottom-right"]:
		for relation: String in ["inside", "equal", "outside", "cross"]:
			_position_boundary_cell(court, occupied, direction, relation)
			var positive: Dictionary = {"cell": occupied, "material": "water"} if relation == "cross" else {}
			var relation_label: String = "cross-polygon-14px" if relation == "cross" and direction.contains("-") else relation
			var row: Dictionary = await _direct_pixel_control(world, "synthetic-boundary-%s-%s" % [direction, relation_label], "normal", 100, Vector2.ZERO, captures, direction == "top-left" and relation in ["equal", "outside"], false, false, positive)
			var diagnostics: Dictionary = row.get("diagnostics", {})
			var expected_rejected := 1 if relation == "outside" else 0
			_check(int(diagnostics.get("full_total", -1)) == 1 and int(diagnostics.get("rejected_total", -1)) == expected_rejected, "%s %s native boundary retains/rejects the expected one region" % [direction, relation])
			result.append(row)
	return result


func _direct_pixel_control(world: SimWorld, label: String, mode: String, zoom_percent: int, camera_origin: Vector2, captures: String, save_images: bool, draw_district_base: bool, repaint_cover: bool, positive_control: Dictionary) -> Dictionary:
	var language := VisualLanguage.new()
	_check(language.load_from_file(), label + " direct canvas loads visual language")
	var presenter := ViewportPresenter.new()
	_check(presenter.configure(language), label + " direct canvas configures presenter")
	var canvas: Node2D = ViewportPresenter.new_ground_canvas()
	canvas.presenter = presenter
	canvas.court = world.hex_court
	canvas.tick = float(world.tick)
	canvas.reduced = mode == "reduced"
	canvas.draw_district_base = draw_district_base
	canvas.repaint_cover = repaint_cover
	canvas.camera_origin = camera_origin
	canvas.zoom_percent = zoom_percent
	root.add_child(canvas)
	canvas.show()
	var expected_hash: String = world.state_hash()
	var prepared_first: Dictionary = _prepared_frame(presenter, world.hex_court, float(world.tick), draw_district_base)
	var prepared_second: Dictionary = _prepared_frame(presenter, world.hex_court, float(world.tick), draw_district_base)
	var prepared_bytes: PackedByteArray = var_to_bytes(prepared_first)
	_check(not prepared_first.is_empty() and prepared_bytes == var_to_bytes(prepared_second), label + " independent pre-draw frame bundles are byte-identical")
	var disabled_pixels := PackedByteArray()
	if not positive_control.is_empty():
		var positive_cell: Vector2i = positive_control.cell
		var positive_material: String = positive_control.material
		var saved_layer: Dictionary = world.hex_court.cells[positive_cell][positive_material].duplicate(true)
		world.hex_court.cells[positive_cell][positive_material].clear()
		for unused: int in range(2):
			_check(await _present_direct(canvas), label + " material-disabled control draws")
		disabled_pixels = root.get_texture().get_image().get_data()
		world.hex_court.cells[positive_cell][positive_material] = saved_layer
		_check(world.state_hash() == expected_hash, label + " positive-control material restores exact authority")
	canvas.candidate_enabled = false
	canvas.diagnostics_enabled = false
	for unused: int in range(4):
		_check(await _present_direct(canvas), label + " direct baseline warmup draws")
	var baseline: Image = root.get_texture().get_image()
	var baseline_result: bool = canvas.last_result
	var baseline_cover_bytes: PackedByteArray = var_to_bytes(presenter._cover_surface_regions)
	var baseline_cover_count: int = canvas.cover_region_count
	canvas.candidate_enabled = true
	canvas.diagnostics_enabled = false
	for unused: int in range(3):
		_check(await _present_direct(canvas), label + " direct candidate warmup draws")
	canvas.diagnostics_enabled = true
	_check(await _present_direct(canvas), label + " direct candidate control draws")
	var candidate: Image = root.get_texture().get_image()
	var candidate_result: bool = canvas.last_result
	var diagnostics: Dictionary = canvas.last_diagnostics.duplicate(true)
	var candidate_cover_bytes: PackedByteArray = var_to_bytes(presenter._cover_surface_regions)
	var candidate_cover_count: int = canvas.cover_region_count
	var pixels_equal: bool = baseline.get_format() == Image.FORMAT_RGBA8 and candidate.get_format() == Image.FORMAT_RGBA8 and baseline.get_size() == candidate.get_size() and baseline.get_data() == candidate.get_data()
	_check(pixels_equal, label + " direct full-frame RGBA8 bytes match")
	_check(baseline_result == candidate_result, label + " direct draw result matches")
	_check(baseline_cover_bytes == candidate_cover_bytes and baseline_cover_count == candidate_cover_count, label + " complete cover storage/repaint inputs match")
	_check(String(diagnostics.get("regions_sha256", "")) == _bytes_hash(var_to_bytes(prepared_second.regions)), label + " candidate region hash matches independent prepared output")
	_check(world.state_hash() == expected_hash, label + " direct controls preserve authority")
	_check(bool(diagnostics.get("counts_complete", false)), label + " direct controls account for every prepared region")
	var positive_visible := true
	if not positive_control.is_empty():
		positive_visible = not disabled_pixels.is_empty() and disabled_pixels != baseline.get_data()
		_check(positive_visible, label + " visible target material changes pixels against disabled control")
	if repaint_cover:
		_check(candidate_cover_count > 0, label + " exercises complete active physical-cover repaint")
	if save_images:
		_check(baseline.save_png(captures + "/" + label + "-baseline.png") == OK, label + " representative direct baseline saves")
		_check(candidate.save_png(captures + "/" + label + "-candidate.png") == OK, label + " representative direct candidate saves")
	pixel_cases_completed += 1
	var translation: Vector2 = PixelPresentation.snapped_canvas_origin(camera_origin, zoom_percent)
	var result: Dictionary = {"case": label, "surface": "direct-ground-native", "mode": mode, "zoom_percent": zoom_percent, "camera_origin": [camera_origin.x, camera_origin.y], "snapped_translation": [translation.x, translation.y], "visible_world_rect": diagnostics.get("visible_world_rect", []), "grown_visible_world_rect": diagnostics.get("grown_visible_world_rect", []), "world_hash": expected_hash, "draw_result": candidate_result, "rgba_sha256": _bytes_hash(candidate.get_data()), "pixel_equal": pixels_equal, "positive_visible_control": positive_visible, "prepared_frame_sha256": _bytes_hash(prepared_bytes), "cover_sha256": _bytes_hash(candidate_cover_bytes), "cover_region_count": candidate_cover_count, "diagnostics": diagnostics, "representative_png": save_images}
	canvas.queue_free()
	await process_frame
	await process_frame
	completed_pixel_evidence.append(result)
	return result


func _present_direct(canvas: Variant) -> bool:
	var before: int = canvas.draw_invocations
	canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return canvas.draw_invocations == before + 1


func _prepared_frame(presenter: ViewportPresenter, court: HexChemistryWorld, tick: float, include_empty: bool) -> Dictionary:
	if not presenter._prepare_court(court, include_empty):
		return {}
	return presenter._prepare_frame_bundle(court, tick)


func _material_cell(court: HexChemistryWorld, material: String) -> Vector2i:
	for cell: Vector2i in court.cells:
		if court.cells[cell].has(material) and court.cells[cell][material] is Dictionary and not court.cells[cell][material].is_empty():
			return cell
	return Vector2i.ZERO


func _left_crossing_camera(court: HexChemistryWorld, cell: Vector2i, zoom_percent: int) -> Vector2:
	var polygon: PackedVector2Array = court.whole_cell_polygon(cell)
	var maximum_x := -INF
	var center := Vector2.ZERO
	for fixed_point: Vector2 in polygon:
		var point: Vector2 = fixed_point / 1000.0
		maximum_x = maxf(maximum_x, point.x)
		center += point
	center /= float(polygon.size())
	var zoom := float(zoom_percent) / 100.0
	return Vector2(maximum_x - 1.0 / zoom, center.y - 360.0 / zoom)


func _pixel_control(world: SimWorld, label: String, mode: String, zoom_percent: int, camera_origin: Vector2, captures: String, save_images: bool) -> Dictionary:
	var node := NativeHarness.new()
	var ready: bool = _configure_node(node, world, mode, true)
	_check(ready, label + " native harness configures")
	if not ready:
		node.queue_free()
		await process_frame
		return {}
	var presenter: ViewportPresenter = node.hex_court_presenter
	node.player_preferences.set_camera_zoom_percent(zoom_percent)
	node.forced_camera_origin = camera_origin
	node.show()
	var expected_hash: String = world.state_hash()
	var prepared_first: Dictionary = _prepared_frame(presenter, world.hex_court, float(world.tick), false)
	var prepared_second: Dictionary = _prepared_frame(presenter, world.hex_court, float(world.tick), false)
	_check(not prepared_first.is_empty() and var_to_bytes(prepared_first) == var_to_bytes(prepared_second), label + " Bootstrap control frame bundles are independently byte-identical")
	presenter.candidate_enabled = false
	presenter.diagnostics_enabled = false
	presenter.cover_repaint_calls = 0
	for unused: int in range(4):
		_check(await _present(node), label + " baseline warmup draw completes")
	var baseline: Image = root.get_texture().get_image()
	var baseline_result: bool = presenter.last_result
	var baseline_cover_repaints: int = presenter.cover_repaint_calls
	var baseline_cover_bytes: PackedByteArray = var_to_bytes(presenter._cover_surface_regions)
	presenter.candidate_enabled = true
	presenter.cover_repaint_calls = 0
	presenter.diagnostics_enabled = false
	for unused: int in range(3):
		_check(await _present(node), label + " candidate warmup draw completes")
	presenter.diagnostics_enabled = true
	_check(await _present(node), label + " candidate draw completes")
	var candidate: Image = root.get_texture().get_image()
	var candidate_result: bool = presenter.last_result
	var candidate_cover_repaints: int = presenter.cover_repaint_calls
	var diagnostics: Dictionary = presenter.last_diagnostics.duplicate(true)
	var candidate_cover_bytes: PackedByteArray = var_to_bytes(presenter._cover_surface_regions)
	var pixels_equal: bool = baseline.get_format() == Image.FORMAT_RGBA8 and candidate.get_format() == Image.FORMAT_RGBA8 and baseline.get_size() == candidate.get_size() and baseline.get_data() == candidate.get_data()
	_check(pixels_equal, label + " preserves complete RGBA8 bytes")
	_check(baseline_result == candidate_result, label + " preserves draw_ground return value")
	_check(baseline_cover_repaints == candidate_cover_repaints, label + " preserves unculled cover repaint invocation count")
	_check(baseline_cover_bytes == candidate_cover_bytes, label + " preserves complete cover storage bytes")
	_check(String(diagnostics.get("regions_sha256", "")) == _bytes_hash(var_to_bytes(prepared_second.regions)), label + " candidate regions match independent prepared bytes")
	if label.begins_with("synthetic-material-extremes"):
		_check(candidate_cover_repaints > 0, label + " exercises physical-cover POV repaint")
	_check(world.state_hash() == expected_hash, label + " preserves frozen authority")
	_check(bool(diagnostics.get("counts_complete", false)), label + " accounts for every prepared region")
	var translation: Vector2 = PixelPresentation.snapped_canvas_origin(camera_origin, zoom_percent)
	if save_images:
		_check(baseline.save_png(captures + "/" + label + "-baseline.png") == OK, label + " representative baseline saves")
		_check(candidate.save_png(captures + "/" + label + "-candidate.png") == OK, label + " representative candidate saves")
	pixel_cases_completed += 1
	var result: Dictionary = {
		"case": label, "mode": mode, "zoom_percent": zoom_percent,
		"camera_origin": [camera_origin.x, camera_origin.y], "snapped_translation": [translation.x, translation.y],
		"visible_world_rect": diagnostics.get("visible_world_rect", []), "grown_visible_world_rect": diagnostics.get("grown_visible_world_rect", []),
		"world_hash": expected_hash, "draw_result": candidate_result,
		"rgba_sha256": _bytes_hash(candidate.get_data()), "pixel_equal": pixels_equal,
		"prepared_frame_sha256": _bytes_hash(var_to_bytes(prepared_first)), "cover_sha256": _bytes_hash(candidate_cover_bytes),
		"diagnostics": diagnostics, "cover_repaint_calls": candidate_cover_repaints, "positive_visible_control": true, "representative_png": save_images,
	}
	node.queue_free()
	await process_frame
	await process_frame
	completed_pixel_evidence.append(result)
	return result


func _timing_case(world: SimWorld, case_name: String, mode: String) -> Dictionary:
	var node := NativeHarness.new()
	var ready: bool = _configure_node(node, world, mode, true)
	_check(ready, case_name + " " + mode + " timing harness configures")
	if not ready:
		node.queue_free()
		await process_frame
		return {}
	var presenter: ViewportPresenter = node.hex_court_presenter
	node.player_preferences.set_camera_zoom_percent(75)
	node.forced_camera_origin = Vector2.INF
	node.show()
	var expected_hash: String = world.state_hash()
	presenter.candidate_enabled = false
	presenter.diagnostics_enabled = false
	for unused: int in range(3):
		_check(await _present(node), "production timing warmup completes")
	var expected_image: Image = root.get_texture().get_image()
	var expected_pixels: PackedByteArray = expected_image.get_data()
	var expected_result: bool = presenter.last_result
	presenter.candidate_enabled = true
	for unused: int in range(3):
		_check(await _present(node), "candidate timing warmup completes")
		_check(root.get_texture().get_image().get_data() == expected_pixels, "candidate timing warmup preserves pixels")
	var rows: Array[Dictionary] = []
	var samples: Dictionary = {"production_current": {"ground": PackedInt64Array(), "draw": PackedInt64Array(), "present": PackedInt64Array()}, "candidate": {"ground": PackedInt64Array(), "draw": PackedInt64Array(), "present": PackedInt64Array()}}
	for cycle: int in range(CYCLES):
		var order: Array[bool] = []
		if cycle % 2 == 0:
			order.assign([false, true, true, false])
		else:
			order.assign([true, false, false, true])
		for block: int in range(order.size()):
			presenter.candidate_enabled = order[block]
			presenter.diagnostics_enabled = false
			var arm := "candidate" if order[block] else "production_current"
			for sample_index: int in range(BLOCK_SAMPLES):
				var began: int = Time.get_ticks_usec()
				var presented: bool = await _present(node)
				var present_us: int = Time.get_ticks_usec() - began
				var image: Image = root.get_texture().get_image()
				var pixel_equal: bool = image.get_format() == Image.FORMAT_RGBA8 and image.get_data() == expected_pixels
				_check(presented and pixel_equal and presenter.last_result == expected_result, "%s %s cycle %d block %d sample %d is exact" % [case_name, mode, cycle, block, sample_index])
				_check(world.state_hash() == expected_hash, "timed draw leaves authority unchanged")
				var ground_us: int = presenter.draw_ground_us
				var draw_us: int = node.total_draw_us
				_check(ground_us <= draw_us, "ground timer remains inside full Bootstrap draw")
				rows.append({"cycle": cycle, "block": block, "index": sample_index, "arm": arm, "ground_us": ground_us, "draw_us": draw_us, "present_us": present_us})
				for key: String in ["ground", "draw", "present"]:
					var values: PackedInt64Array = samples[arm][key]
					values.append(ground_us if key == "ground" else draw_us if key == "draw" else present_us)
					samples[arm][key] = values
	var summary: Dictionary = {}
	for arm: String in ["production_current", "candidate"]:
		summary[arm] = {}
		for key: String in ["ground", "draw", "present"]:
			summary[arm][key] = _percentiles(samples[arm][key])
	timing_cases_completed += 1
	var result: Dictionary = {"case": case_name, "mode": mode, "world_tick": world.tick, "world_hash": expected_hash, "actors": world.players.size(), "topology_cells": world.hex_court.cells.size(), "paid_metrics": world.hex_court.metrics.duplicate(true), "occupancy": _occupancy(world.hex_court, world.tick), "rows": rows, "samples": samples, "summary_us": summary, "rgba_sha256": _bytes_hash(expected_pixels), "draw_result": expected_result}
	node.queue_free()
	await process_frame
	await process_frame
	completed_timing_evidence.append(result)
	return result


func _synthetic_material_world() -> SimWorld:
	var fixture: Dictionary = _fixture("dense-crucible")
	var world: SimWorld = fixture.world
	var court: HexChemistryWorld = world.hex_court
	_clear_material_state(court)
	var ordered: Array = court.cells.keys()
	ordered.sort_custom(Grid._cell_less)
	var chosen: Array[Vector2i] = []
	for index: int in range(12):
		chosen.append(ordered[ordered.size() / 2 - 6 + index])
	_add_ingredient(court, 101, 1001, "water", chosen[0], 1_000)
	_add_ingredient(court, 102, 1002, "fire", chosen[1], 1_000)
	_add_product(court, 201, "steam", 310, [chosen[2]], 1, 1_600)
	var cohesive_pair: Array[Vector2i] = _adjacent_pair(court, {})
	var excluded: Dictionary = {cohesive_pair[0]: true, cohesive_pair[1]: true} if cohesive_pair.size() == 2 else {}
	var differing_pair: Array[Vector2i] = _adjacent_pair(court, excluded)
	_check(cohesive_pair.size() == 2 and differing_pair.size() == 2, "synthetic material fixture has distinct adjacent semantic pairs")
	if cohesive_pair.size() != 2 or differing_pair.size() != 2:
		return null
	_add_product(court, 202, "magma", 302, cohesive_pair, 2, 1_400)
	_add_product(court, 203, "magma", 302, [differing_pair[0]], 3, 900)
	_add_product(court, 209, "magma", 302, [differing_pair[1]], 9, 900)
	_add_product(court, 204, "fortify", 301, [chosen[6]], 4, 1_500)
	_add_product(court, 205, "flood", 316, [chosen[7]], 5, 1_300)
	_add_product(court, 206, "conflagration", 309, [chosen[8]], 6, 1_300)
	_add_product(court, 207, "firestorm", 311, [chosen[9]], 7, 1_100)
	_add_product(court, 208, "static_shroud", 333, [chosen[10]], 8, 1_100)
	world.tick = 50
	court.current_tick = 50
	court.render_revision += 1
	_check(world.tick == court.current_tick and world.tick > 10 and world.tick < 200, "synthetic products draw in their active interval")
	return world


func _boundary_world() -> SimWorld:
	var fixture: Dictionary = _fixture("dense-crucible")
	var world: SimWorld = fixture.world
	var court: HexChemistryWorld = world.hex_court
	_clear_material_state(court)
	var ordered: Array = court.cells.keys()
	ordered.sort_custom(Grid._cell_less)
	_add_ingredient(court, 301, 3001, "water", ordered[ordered.size() / 2], 1_000)
	court.current_tick = 50
	court.render_revision += 1
	return world


func _clear_material_state(court: HexChemistryWorld) -> void:
	court.casts.clear()
	court.products.clear()
	court.pending.clear()
	court.sources.clear()
	court.exposure.clear()
	court.flow_carry.clear()
	for cell: Vector2i in court.cells:
		for material: String in HexChemistryWorld.material_layers():
			court.cells[cell][material].clear()


func _add_ingredient(court: HexChemistryWorld, cast_id: int, part_id: int, material: String, cell: Vector2i, quantity: int) -> void:
	court.casts[cast_id] = {"owner": cast_id, "source": part_id, "aim": Vector2i(1000, -250), "ground_parts": {part_id: {"created": 0, "expiry_tick": 300, "coverage": {cell: 1}, "cells": {cell: quantity}}}}
	court.cells[cell][material][cast_id] = quantity


func _add_product(court: HexChemistryWorld, product_id: int, material: String, wire_id: int, selected_cells: Array, owner: int, intensity: int) -> void:
	var cell_values: Dictionary = {}
	for cell_value: Variant in selected_cells:
		var cell: Vector2i = cell_value
		cell_values[cell] = intensity
		court.cells[cell][material][product_id] = intensity
	court.products[product_id] = {"active_tick": 10, "decay_tick": 200, "expiry_tick": 300, "intensity": intensity, "cells": cell_values, "owner": owner, "source_ids": [product_id + 1_000], "recipe_wire_id": wire_id, "flow_aim": Vector2i(1000, 0)}


func _adjacent_pair(court: HexChemistryWorld, excluded: Dictionary) -> Array[Vector2i]:
	var ordered: Array = court.cells.keys()
	ordered.sort_custom(Grid._cell_less)
	for cell_value: Variant in ordered:
		var cell: Vector2i = cell_value
		if excluded.has(cell):
			continue
		for neighbor: Vector2i in Grid.neighbors(cell):
			if court.cells.has(neighbor) and not excluded.has(neighbor):
				return [cell, neighbor]
	return []


func _position_boundary_cell(court: HexChemistryWorld, cell: Vector2i, direction: String, relation: String) -> void:
	var vertices: Array[Vector2i] = Grid.vertices(cell)
	var minimum: Vector2i = vertices[0]
	var maximum: Vector2i = vertices[0]
	for vertex: Vector2i in vertices:
		minimum = minimum.min(vertex)
		maximum = maximum.max(vertex)
	var grown := Rect2(Vector2(-9, -9), Vector2(1298, 738))
	var visible := Rect2(Vector2.ZERO, Vector2(1280, 720))
	var target_min := Vector2(640, 360) - Vector2(maximum - minimum) / 2000.0
	var target_max := target_min + Vector2(maximum - minimum) / 1000.0
	var epsilon := 0.001
	var inside_delta := epsilon if relation == "inside" else 0.0 if relation == "equal" else -epsilon
	# Pointy-hex AABB corners contain no polygon. Use a separately labelled
	# deeper corner crossing, retaining one-pixel crossings at straight edges.
	var cross_inset := 14.0 if direction.contains("-") else 1.0
	if direction.contains("left"):
		target_max.x = visible.position.x + cross_inset if relation == "cross" else grown.position.x + inside_delta
		target_min.x = target_max.x - float(maximum.x - minimum.x) / 1000.0
	if direction.contains("right"):
		target_min.x = visible.end.x - cross_inset if relation == "cross" else grown.end.x - inside_delta
	if direction.contains("top"):
		target_max.y = visible.position.y + cross_inset if relation == "cross" else grown.position.y + inside_delta
		target_min.y = target_max.y - float(maximum.y - minimum.y) / 1000.0
	if direction.contains("bottom"):
		target_min.y = visible.end.y - cross_inset if relation == "cross" else grown.end.y - inside_delta
	court.origin = Vector2i(roundi(target_min.x * 1000.0) - minimum.x, roundi(target_min.y * 1000.0) - minimum.y)
	court.render_revision += 1


func _pixel_case_complete(result: Dictionary) -> bool:
	if result.is_empty() or not bool(result.get("pixel_equal", false)) or not bool(result.get("positive_visible_control", false)) \
		or String(result.get("rgba_sha256", "")).length() != 64 or String(result.get("world_hash", "")).length() != 64 \
		or String(result.get("prepared_frame_sha256", "")).length() != 64 or String(result.get("cover_sha256", "")).length() != 64:
		return false
	var diagnostics: Variant = result.get("diagnostics")
	return diagnostics is Dictionary and bool(diagnostics.get("counts_complete", false)) and String(diagnostics.get("regions_sha256", "")).length() == 64


func _timing_case_complete(result: Dictionary) -> bool:
	if result.is_empty() or String(result.get("world_hash", "")).length() != 64 or String(result.get("rgba_sha256", "")).length() != 64:
		return false
	var rows: Variant = result.get("rows")
	if not rows is Array or rows.size() != SAMPLES_PER_ARM * 2:
		return false
	var counts := {"production_current": 0, "candidate": 0}
	var flattened: Dictionary = {
		"production_current": {"ground": PackedInt64Array(), "draw": PackedInt64Array(), "present": PackedInt64Array()},
		"candidate": {"ground": PackedInt64Array(), "draw": PackedInt64Array(), "present": PackedInt64Array()},
	}
	for flat_index: int in range(rows.size()):
		var row: Variant = rows[flat_index]
		if not row is Dictionary:
			return false
		var cycle: int = flat_index / (4 * BLOCK_SAMPLES)
		var within_cycle: int = flat_index % (4 * BLOCK_SAMPLES)
		var block: int = within_cycle / BLOCK_SAMPLES
		var sample_index: int = within_cycle % BLOCK_SAMPLES
		var expected_order: Array[String] = []
		if cycle % 2 == 0:
			expected_order.assign(["production_current", "candidate", "candidate", "production_current"])
		else:
			expected_order.assign(["candidate", "production_current", "production_current", "candidate"])
		var arm: String = String(row.get("arm", ""))
		if int(row.get("cycle", -1)) != cycle or int(row.get("block", -1)) != block or int(row.get("index", -1)) != sample_index or arm != expected_order[block]:
			return false
		if int(row.get("ground_us", 0)) <= 0 or int(row.get("draw_us", 0)) <= 0 or int(row.get("present_us", 0)) <= 0:
			return false
		counts[arm] = int(counts[arm]) + 1
		for key: String in ["ground", "draw", "present"]:
			var values: PackedInt64Array = flattened[arm][key]
			values.append(int(row.get(key + "_us", 0)))
			flattened[arm][key] = values
	if int(counts.production_current) != SAMPLES_PER_ARM or int(counts.candidate) != SAMPLES_PER_ARM:
		return false
	var samples: Variant = result.get("samples")
	var summary: Variant = result.get("summary_us")
	if not samples is Dictionary or not summary is Dictionary:
		return false
	for arm: String in ["production_current", "candidate"]:
		for key: String in ["ground", "draw", "present"]:
			var sample_values: Variant = samples[arm][key]
			var flattened_values: Variant = flattened[arm][key]
			if typeof(sample_values) != TYPE_PACKED_INT64_ARRAY or typeof(flattened_values) != TYPE_PACKED_INT64_ARRAY or sample_values != flattened_values:
				return false
			if not summary[arm][key] is Dictionary or int(summary[arm][key].get("samples", -1)) != SAMPLES_PER_ARM:
				return false
	return true


func _candidate_source_hashes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in [
		"tests/performance/profile_hex_viewport_candidate.gd",
		"tests/performance/profile_hex_draw_components.gd",
		"tests/support/hex_viewport_candidate.gd",
		"tests/support/hex_viewport_harness.gd",
		"tests/support/chemistry_coach_harness.gd",
		"src/app/bootstrap.gd",
		"src/presentation/hex_court_presenter.gd",
		"src/presentation/hex_water_material_presenter.gd",
		"src/presentation/pixel_presentation.gd",
		"src/presentation/visual_language.gd",
		"src/sim/hex/hex_chemistry_world.gd",
		"src/sim/hex/hex_grid.gd",
		"content/maps/sanctum_campus_g2_v1.json",
	]:
		result[path] = FileAccess.get_sha256("res://" + path)
	return result


func _hashes_complete(hashes: Dictionary) -> bool:
	if hashes.size() != 13:
		return false
	for value: Variant in hashes.values():
		if typeof(value) != TYPE_STRING or String(value).length() != 64:
			return false
	return true


func _runtime_identity() -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(RuntimeBuildIdentity.MANIFEST_PATH))
	return value.duplicate(true) if value is Dictionary else {}


func _finish(receipt: Dictionary) -> void:
	if receipt.is_empty() and receipt_path_valid:
		receipt = {
			"schema_version": 1,
			"profile_version": "hex-viewport-candidate-native-abba-v1",
			"partial": true,
			"visibility_cases_completed": visibility_cases_completed,
			"pixel_cases_completed": pixel_cases_completed,
			"timing_cases_completed": timing_cases_completed,
			"pixel_cases": completed_pixel_evidence,
			"timing_cases": completed_timing_evidence,
			"source_sha256": _candidate_source_hashes(),
			"runtime_identity": _runtime_identity(),
		}
	if not receipt.is_empty() and receipt_path_valid:
		receipt.assertions = assertions
		receipt.failures = failures
		var output := FileAccess.open(output_path, FileAccess.WRITE)
		_check(output != null, "viewport receipt opens")
		if output != null:
			receipt.assertions = assertions
			receipt.failures = failures
			output.store_string(JSON.stringify(receipt, "\t") + "\n")
			output.close()
	print("%s: hex-viewport-candidate; %d assertions; %d failures; output=%s" % ["PASS" if failures == 0 else "FAIL", assertions, failures, output_path])
	quit(1 if failures > 0 else 0)
