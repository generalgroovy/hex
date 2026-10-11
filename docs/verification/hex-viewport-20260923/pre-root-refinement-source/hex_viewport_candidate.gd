extends "res://src/presentation/hex_court_presenter.gd"

# Test-only explicit visible-rectangle entry. The inherited draw_ground remains
# the unchanged default/no-cull path for existing and generic callers.
const PixelPresentationScript = preload("res://src/presentation/pixel_presentation.gd")
const REGION_MARGIN_WORLD := 8.0


static func visible_world_rect(camera_origin: Vector2, viewport_size: Vector2, zoom_percent: int) -> Rect2:
	var zoom: float = PixelPresentationScript.zoom_scale(zoom_percent)
	if not camera_origin.is_finite() or not viewport_size.is_finite() or viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or not is_finite(zoom) or zoom <= 0.0:
		return Rect2()
	var translation: Vector2 = PixelPresentationScript.snapped_canvas_origin(camera_origin, zoom_percent)
	return Rect2(-translation / zoom, viewport_size / zoom)


static func grown_visible_world_rect(visible_world: Rect2, zoom: float) -> Rect2:
	if not _rect_valid(visible_world) or not is_finite(zoom) or zoom <= 0.0:
		return Rect2()
	return visible_world.grow(REGION_MARGIN_WORLD + 1.0 / zoom)


static func region_visible(region: Dictionary, grown_visible_world: Rect2) -> bool:
	if not _rect_valid(grown_visible_world):
		return true
	var polygon_value: Variant = region.get("polygon")
	if typeof(polygon_value) != TYPE_PACKED_VECTOR2_ARRAY:
		return true
	var polygon: PackedVector2Array = polygon_value
	if polygon.size() < 3:
		return true
	var minimum: Vector2 = polygon[0]
	var maximum: Vector2 = polygon[0]
	if not minimum.is_finite():
		return true
	for point: Vector2 in polygon:
		if not point.is_finite():
			return true
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	var bounds := Rect2(minimum, maximum - minimum)
	if not bounds.end.is_finite() or bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or absf(_polygon_twice_area(polygon)) <= 0.0001:
		return true
	return bounds.position.x <= grown_visible_world.end.x and bounds.end.x >= grown_visible_world.position.x \
		and bounds.position.y <= grown_visible_world.end.y and bounds.end.y >= grown_visible_world.position.y


func draw_ground_visible(canvas: CanvasItem, court: RefCounted, tick: float, reduced: bool, draw_district_base: bool, visible_world: Rect2, zoom: float, diagnostics: Dictionary, collect_diagnostics: bool = false) -> bool:
	diagnostics.clear()
	_cover_surface_regions.clear()
	if canvas == null or court == null or _language == null or not is_finite(tick) or not court.has_method("view"):
		return false
	if not _prepare_court(court, draw_district_base):
		return false
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var frame: Dictionary = _prepare_frame_bundle(court, tick)
	var views: Dictionary = frame.get("views", {})
	var regions: Dictionary = frame.get("regions", {})
	if regions.is_empty() and _has_active_material(views):
		return false
	for material: String in ["fortify", "permafrost", "grounding_network", "crystal_prism", "crystal_lens"]:
		var active := {}
		for cell: Vector2i in regions.get(material, {}):
			var selected: Array[Dictionary] = []
			for region: Dictionary in regions[material][cell]:
				if String(region.phase) == "active": selected.append(region)
			if not selected.is_empty(): active[cell] = selected
		_cover_surface_regions[material] = active
	var grown_visible: Rect2 = grown_visible_world_rect(visible_world, zoom)
	if collect_diagnostics:
		_begin_diagnostics(diagnostics, regions, visible_world, grown_visible, zoom)
	if draw_district_base:
		_draw_apron(canvas, reduced)
		_draw_stone(canvas, court, reduced)
	_candidate_draw_water(canvas, views, regions.get("water", {}), tick, reduced, grown_visible, diagnostics, collect_diagnostics)
	_candidate_draw_fire(canvas, views, regions.get("fire", {}), tick, reduced, grown_visible, diagnostics, collect_diagnostics)
	for material: String in INGREDIENT_MATERIALS:
		if material not in ["water", "fire"]:
			_candidate_draw_shared_material(canvas, regions.get(material, {}), material, tick, reduced, grown_visible, diagnostics, collect_diagnostics)
	_candidate_draw_steam(canvas, views, regions.get("steam", {}), tick, reduced, grown_visible, diagnostics, collect_diagnostics)
	_candidate_draw_mirror_product(canvas, regions.get("flood", {}), "flood", tick, reduced, grown_visible, diagnostics, collect_diagnostics)
	_candidate_draw_mirror_product(canvas, regions.get("conflagration", {}), "conflagration", tick, reduced, grown_visible, diagnostics, collect_diagnostics)
	for material: String in PRODUCT_MATERIALS:
		if material not in ["steam", "flood", "conflagration"]:
			_candidate_draw_shared_material(canvas, regions.get(material, {}), material, tick, reduced, grown_visible, diagnostics, collect_diagnostics)
	if draw_district_base:
		_draw_outer_rim(canvas)
	if collect_diagnostics:
		_finish_diagnostics(diagnostics)
	return true


func _candidate_draw_mirror_product(canvas: CanvasItem, regions_by_cell: Dictionary, material: String, tick: float, reduced: bool, grown_visible: Rect2, diagnostics: Dictionary, collect_diagnostics: bool) -> void:
	var counts := _region_edge_counts(regions_by_cell)
	var base := _language.reaction_color(material, "base")
	var bright := _language.reaction_color(material, "bright")
	var dark := _language.reaction_color(material, "dark")
	for cell: Vector2i in regions_by_cell:
		for region: Dictionary in regions_by_cell[cell]:
			if not region_visible(region, grown_visible):
				if collect_diagnostics: _record_rejected(diagnostics, material)
				continue
			if collect_diagnostics: _record_retained(diagnostics, material)
			var active: bool = region.phase == "active"
			var decaying: bool = region.phase == "decaying"
			var intensity := clampf(float(region.intensity) / 1000.0, 0.1, 1.5)
			var opacity := ((0.19 if reduced else 0.25) + 0.06 * intensity) * (0.45 if decaying else 1.0)
			canvas.draw_colored_polygon(region.polygon, Color(base, opacity))
			_draw_region_outline(canvas, region, counts, Color(bright if active else dark, 0.80 if active else 0.50), 2.0)
			var center := _polygon_centroid(region.polygon)
			var radius := _polygon_clearance(center, region.polygon) - 3.0
			if radius < 5.0: continue
			if material == "flood":
				var direction := Vector2(region.direction).normalized()
				var side := Vector2(-direction.y, direction.x)
				var drift := 0.0 if reduced or not active else sin(tick * 0.08) * minf(2.0, radius * 0.1)
				for offset: float in [-0.30, 0.30]:
					var anchor := center + direction * (radius * offset + drift)
					canvas.draw_line(anchor - direction * radius * 0.18 - side * radius * 0.28, anchor + direction * radius * 0.15, Color(bright, 0.85), 2.0)
					canvas.draw_line(anchor + direction * radius * 0.15, anchor - direction * radius * 0.18 + side * radius * 0.28, Color(bright, 0.85), 2.0)
			else:
				var phase := "active" if active else "cooling" if decaying else "ignition"
				_draw_fire_region_mark(canvas, region.polygon, phase, dark, base, bright, _language.reaction_color(material, "danger"), tick, int(region.footprint_id), reduced)
				if active:
					for offset: float in [-0.45, 0.45]:
						var anchor := center + Vector2(radius * offset, radius * 0.12)
						canvas.draw_line(anchor, anchor + Vector2(0, -radius * 0.35), Color(bright, 0.78), 2.0)


func _candidate_draw_water(canvas: CanvasItem, _views: Dictionary, regions_by_cell: Dictionary, tick: float, reduced: bool, grown_visible: Rect2, diagnostics: Dictionary, collect_diagnostics: bool) -> void:
	var edge_counts := _region_edge_counts(regions_by_cell)
	for cell: Vector2i in regions_by_cell:
		for region: Dictionary in regions_by_cell[cell]:
			if not region_visible(region, grown_visible):
				if collect_diagnostics: _record_rejected(diagnostics, "water")
				continue
			if collect_diagnostics: _record_retained(diagnostics, "water")
			var style := _water_region_style(region, reduced)
			canvas.draw_colored_polygon(region.polygon, Color(style.base, style.fill_opacity))
			_draw_region_outline(canvas, region, edge_counts, Color(style.edge, style.edge_opacity), style.edge_width)
			var seed := _cell_seed(cell, int(region.footprint_id) * 401)
			if not water_motifs_enabled or not water_material.draw_region(canvas, region.polygon, style.phase, tick, seed, reduced):
				_draw_water_region_mark(canvas, region.polygon, style.bright, style.phase, tick, seed, reduced)


func _candidate_draw_fire(canvas: CanvasItem, _views: Dictionary, regions_by_cell: Dictionary, tick: float, reduced: bool, grown_visible: Rect2, diagnostics: Dictionary, collect_diagnostics: bool) -> void:
	var edge_counts := _region_edge_counts(regions_by_cell)
	for cell: Vector2i in regions_by_cell:
		for region: Dictionary in regions_by_cell[cell]:
			if not region_visible(region, grown_visible):
				if collect_diagnostics: _record_rejected(diagnostics, "fire")
				continue
			if collect_diagnostics: _record_retained(diagnostics, "fire")
			var style := _fire_region_style(region, reduced)
			canvas.draw_colored_polygon(region.polygon, Color(style.base, style.fill_opacity))
			_draw_region_outline(canvas, region, edge_counts, Color(style.edge, style.edge_opacity), style.edge_width)
			var seed := _cell_seed(cell, int(region.footprint_id) * 809)
			_draw_fire_region_mark(canvas, region.polygon, style.phase, style.dark, style.base, style.bright, style.danger_color, tick, seed, reduced)


func _candidate_draw_steam(canvas: CanvasItem, views: Dictionary, regions_by_cell: Dictionary, tick: float, reduced: bool, grown_visible: Rect2, diagnostics: Dictionary, collect_diagnostics: bool) -> void:
	var edge_counts := _region_edge_counts(regions_by_cell)
	for cell: Vector2i in regions_by_cell:
		var heat := int((views.get(cell, {}) as Dictionary).get("steam_heat", 1000))
		for region: Dictionary in regions_by_cell[cell]:
			if not region_visible(region, grown_visible):
				if collect_diagnostics: _record_rejected(diagnostics, "steam")
				continue
			if collect_diagnostics: _record_retained(diagnostics, "steam")
			var style := _steam_region_style(region, heat, reduced)
			canvas.draw_colored_polygon(region.polygon, Color(style.base, style.fill_opacity))
			_draw_region_outline(canvas, region, edge_counts, Color(style.dark, style.edge_opacity), style.edge_width)
			if bool(style.danger):
				_draw_region_outline(canvas, region, edge_counts, Color(style.danger_color, style.danger_opacity), 1.0)
			var seed := _cell_seed(cell, int(region.footprint_id) * 1201 + heat)
			_draw_steam_region_mark(canvas, region.polygon, style.dark, style.bright, style.danger_color, style.palette_phase, tick, seed, reduced, bool(style.danger), String(region.phase))


func _candidate_draw_shared_material(canvas: CanvasItem, regions_by_cell: Dictionary, material: String, tick: float, reduced: bool, grown_visible: Rect2, diagnostics: Dictionary, collect_diagnostics: bool) -> void:
	if regions_by_cell.is_empty():
		return
	var edge_counts := _region_edge_counts(regions_by_cell)
	for cell: Vector2i in regions_by_cell:
		for region: Dictionary in regions_by_cell[cell]:
			if not region_visible(region, grown_visible):
				if collect_diagnostics: _record_rejected(diagnostics, material)
				continue
			if collect_diagnostics: _record_retained(diagnostics, material)
			var style := _shared_material_style(material, region, reduced)
			if style.is_empty():
				continue
			canvas.draw_colored_polygon(region.polygon, Color(style.base, style.fill_opacity))
			_draw_region_outline(canvas, region, edge_counts, Color(style.edge, style.edge_opacity), style.edge_width)
			var seed := _cell_seed(cell, int(region.footprint_id) * 1597 + int(style.wire_id))
			_draw_shared_material_mark(canvas, region, style, tick, seed, reduced)


func _begin_diagnostics(diagnostics: Dictionary, regions: Dictionary, visible_world: Rect2, grown_visible: Rect2, zoom: float) -> void:
	var full_by_material := {}
	var retained_by_material := {}
	var rejected_by_material := {}
	var full_total := 0
	for material: String in MATERIALS:
		var count := 0
		for rows_value: Variant in (regions.get(material, {}) as Dictionary).values():
			if rows_value is Array:
				count += rows_value.size()
		full_by_material[material] = count
		retained_by_material[material] = 0
		rejected_by_material[material] = 0
		full_total += count
	diagnostics["visible_world_rect"] = _rect_values(visible_world)
	diagnostics["grown_visible_world_rect"] = _rect_values(grown_visible)
	diagnostics["zoom"] = zoom
	diagnostics["full_by_material"] = full_by_material
	diagnostics["retained_by_material"] = retained_by_material
	diagnostics["rejected_by_material"] = rejected_by_material
	diagnostics["full_total"] = full_total
	diagnostics["retained_total"] = 0
	diagnostics["rejected_total"] = 0
	diagnostics["regions_sha256"] = _bytes_hash(var_to_bytes(regions))


func _record_retained(diagnostics: Dictionary, material: String) -> void:
	diagnostics.retained_by_material[material] = int(diagnostics.retained_by_material.get(material, 0)) + 1
	diagnostics.retained_total = int(diagnostics.retained_total) + 1


func _record_rejected(diagnostics: Dictionary, material: String) -> void:
	diagnostics.rejected_by_material[material] = int(diagnostics.rejected_by_material.get(material, 0)) + 1
	diagnostics.rejected_total = int(diagnostics.rejected_total) + 1


func _finish_diagnostics(diagnostics: Dictionary) -> void:
	diagnostics["counts_complete"] = int(diagnostics.full_total) == int(diagnostics.retained_total) + int(diagnostics.rejected_total)


static func _rect_valid(rectangle: Rect2) -> bool:
	return rectangle.position.is_finite() and rectangle.size.is_finite() and rectangle.end.is_finite() and rectangle.size.x > 0.0 and rectangle.size.y > 0.0


static func _polygon_twice_area(polygon: PackedVector2Array) -> float:
	var result := 0.0
	for index: int in polygon.size():
		result += polygon[index].cross(polygon[(index + 1) % polygon.size()])
	return result


static func _rect_values(rectangle: Rect2) -> Array[float]:
	return [rectangle.position.x, rectangle.position.y, rectangle.size.x, rectangle.size.y]


static func _bytes_hash(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()
