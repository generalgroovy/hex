extends "res://src/presentation/hex_court_presenter.gd"

# Test-only A/B seam. Baseline calls actual production draw_ground. The candidate
# changes only its frame preparation block; all draw/cover helpers are inherited.
const FrameCandidate = preload("res://tests/support/hex_render_frame_candidate.gd")
var candidate_enabled := false
var draw_ground_us := 0

func draw_ground(canvas: CanvasItem, court: RefCounted, tick: float, reduced: bool, draw_district_base: bool = true) -> bool:
	var began: int = Time.get_ticks_usec()
	var result: bool = _candidate_ground(canvas, court, tick, reduced, draw_district_base) if candidate_enabled else super.draw_ground(canvas, court, tick, reduced, draw_district_base)
	draw_ground_us = Time.get_ticks_usec() - began
	return result

func _candidate_ground(canvas: CanvasItem, court: RefCounted, tick: float, reduced: bool, draw_district_base: bool) -> bool:
	_cover_surface_regions.clear()
	if canvas == null or court == null or _language == null or not is_finite(tick) or not court.has_method("view"):
		return false
	if court.get_script() != FrameCandidate.World:
		return super.draw_ground(canvas, court, tick, reduced, draw_district_base)
	if not _prepare_court(court, draw_district_base):
		return false
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var frame: Dictionary = FrameCandidate.candidate_bundle(court as HexChemistryWorld, self, tick)
	if frame.is_empty():
		return false
	var views: Dictionary = frame.views
	var regions: Dictionary = frame.regions
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
	if draw_district_base:
		_draw_outer_rim(canvas)
	return true
