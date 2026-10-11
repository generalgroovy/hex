extends SceneTree
@warning_ignore_start("integer_division")

# Focused CPU microbenchmark, not FPS: genuinely empty occupied membership.
# Frozen prior draw body is independent of the new early-exit implementation.
class PreviousGround extends HexCourtPresenter:
	func draw_ground(canvas: CanvasItem, court: RefCounted, tick: float, reduced: bool, draw_district_base: bool = true) -> bool:
		_cover_surface_regions.clear()
		if canvas == null or court == null or _language == null or not is_finite(tick) or not court.has_method("view"):
			return false
		if not _prepare_court(court, draw_district_base): return false
		canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var frame: Dictionary = _prepare_frame_bundle(court, tick)
		var views: Dictionary = frame.get("views", {})
		var regions: Dictionary = frame.get("regions", {})
		if regions.is_empty() and _has_active_material(views): return false
		for material: String in ["fortify", "permafrost", "grounding_network", "crystal_prism", "crystal_lens"]:
			var active := {}
			for cell: Vector2i in regions.get(material, {}):
				var selected: Array[Dictionary] = []
				for region: Dictionary in regions[material][cell]:
					if String(region.phase) == "active": selected.append(region)
				if not selected.is_empty(): active[cell] = selected
			_cover_surface_regions[material] = active
		if draw_district_base:
			_draw_apron(canvas, reduced)
			_draw_stone(canvas, court, reduced)
		_draw_water(canvas, views, regions.get("water", {}), tick, reduced)
		_draw_fire(canvas, views, regions.get("fire", {}), tick, reduced)
		for material: String in INGREDIENT_MATERIALS:
			if material not in ["water", "fire"]:
				_draw_shared_material(canvas, regions.get(material, {}), material, tick, reduced)
		_draw_steam(canvas, views, regions.get("steam", {}), tick, reduced)
		_draw_mirror_product(canvas, regions.get("flood", {}), "flood", tick, reduced)
		_draw_mirror_product(canvas, regions.get("conflagration", {}), "conflagration", tick, reduced)
		for material: String in PRODUCT_MATERIALS:
			if material not in ["steam", "flood", "conflagration"]:
				_draw_shared_material(canvas, regions.get(material, {}), material, tick, reduced)
		if draw_district_base: _draw_outer_rim(canvas)
		return true


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if not output.begins_with("res://.godot/empty-hex-ground-") or not output.ends_with(".json") or ".." in output or FileAccess.file_exists(output):
		quit(1)
		return
	var layout := SanctumCampusLayout.new()
	var language := VisualLanguage.new()
	if not layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json") or not language.load_from_file():
		quit(1)
		return
	var definition := HexWorldDefinition.from_campus(layout)
	var court := HexChemistryWorld.new()
	var baseline := PreviousGround.new()
	var current := HexCourtPresenter.new()
	if not court.configure_geometry(Vector2i.ZERO, definition.eligible_cells) or not baseline.configure(language) or not current.configure(language):
		quit(1)
		return
	var canvas := Node2D.new()
	var before := var_to_bytes(court.cells)
	var samples := {"before": [], "after": []}
	var failed := false
	# ABBA blocks reduce one-way warmup/order bias; both modes retain semantics.
	for reduced: bool in [false, true]:
		for pass_id: int in 4:
			var order: Array[String] = ["before", "after"]
			if pass_id % 2 == 1: order.reverse()
			for arm: String in order:
				var presenter: HexCourtPresenter = baseline if arm == "before" else current
				for unused: int in 24:
					failed = not presenter.draw_ground(canvas, court, 120.0, reduced, false) or failed
				for unused: int in 96:
					var began := Time.get_ticks_usec()
					var okay := presenter.draw_ground(canvas, court, 120.0, reduced, false)
					samples[arm].append(Time.get_ticks_usec() - began)
					failed = not okay or failed
				failed = not presenter._cells.is_empty() or failed
	failed = not court.occupied_cells().is_empty() or var_to_bytes(court.cells) != before or failed
	var summary := {}
	for arm: String in samples:
		var sorted: Array = samples[arm].duplicate()
		sorted.sort()
		summary[arm] = {"p50_us": sorted[sorted.size() / 2], "p95_us": sorted[ceili(sorted.size() * 0.95) - 1], "max_us": sorted.back(), "samples": sorted.size()}
	var receipt := {"status": "failed" if failed else "passed", "scope": "Headless CPU draw-call microbenchmark with zero occupied membership and no draw commands; not native pixels, GPU, simulation, multiplayer or FPS.", "engine": Engine.get_version_info().string, "topology_cells": court.cells.size(), "occupied_cells": court.occupied_cells().size(), "summary": summary, "samples_us": samples,
		"source_sha256": FileAccess.get_sha256("res://src/presentation/hex_court_presenter.gd"), "diagnostic_sha256": FileAccess.get_sha256(get_script().resource_path)}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		canvas.free()
		quit(1)
		return
	file.store_string(JSON.stringify(receipt, "\t") + "\n")
	file.close()
	canvas.free()
	print("EMPTY_HEX_GROUND: ", summary, "; status=", receipt.status)
	quit(1 if failed else 0)
