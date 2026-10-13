extends HexCourtPresenter
## Ignored same-call membership reuse; derived presenters retain the old path.
const OCCUPIED_MEMBERSHIP_SCRIPT_PATH := "res://.godot/iteration-20261013/occupied-render-membership/candidate_court.gd"
var _prepared_occupied_court_id: int = 0

func draw_ground(canvas: CanvasItem, court: RefCounted, tick: float, reduced: bool, draw_district_base: bool = true) -> bool:
	_cover_surface_regions.clear()
	_edge_prefixes.clear()
	_magic_surface_glows = 0
	if canvas == null or court == null or _language == null or not is_finite(tick) or not court.has_method("view"):
		return false
	if not _prepare_court(court, draw_district_base):
		return false
	# A changed native setter can emit a synchronous property-list signal.
	var occupied_filter_unchanged := canvas.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# The normal campus already supplies its floor. After validated membership
	# is empty there is no material to prepare or submit; leave the standalone
	# diagnostic court's apron/base path intact. No tick/revision cache: a cast,
	# restore or direct coverage change is observed by _prepare_court each call.
	if _cells.is_empty() and not draw_district_base:
		return true
	var previous_occupied_court_id := _prepared_occupied_court_id
	_prepared_occupied_court_id = int(court.get_instance_id()) if occupied_filter_unchanged and not draw_district_base and get_script().resource_path == OCCUPIED_MEMBERSHIP_SCRIPT_PATH and (court.get_script() == HexChemistryWorldScript or court.get_script() == HexCourtScript) else 0
	var frame: Dictionary = _prepare_draw_bundle(court, tick)
	_prepared_occupied_court_id = previous_occupied_court_id
	var views: Dictionary = frame.get("views", {})
	var regions: Dictionary = frame.get("regions", {})
	if regions.is_empty() and not views.is_empty() and _has_active_material(views):
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
	_draw_mirror_product(canvas, regions.get("conflagration", {}), "conflagration", tick, reduced)
	for material: String in PRODUCT_MATERIALS:
		if material not in ["steam", "conflagration"]:
			_draw_shared_material(canvas, regions.get(material, {}), material, tick, reduced)
	if draw_district_base:
		_draw_outer_rim(canvas)
	return true


# Repaint only the visible physical cover after opaque terrain replacement.
# Reuses this frame's canonical prepared regions; never redraws other layers.

func _prepare_draw_bundle(court: RefCounted, tick: float) -> Dictionary:
	# Consume before downstream virtual work; direct/nested calls get no token.
	var prepared_occupied_court_id := _prepared_occupied_court_id
	_prepared_occupied_court_id = 0
	var previous := _compact_draw_bundle
	var floor_cells := _cells
	# The standalone Range still draws every eligible floor cell. Material work
	# follows only current paid coverage, intersected with the prepared view. The
	# known HexCourt compatibility class adds topology only, with no view override.
	# Arbitrary subclasses/generic contracts keep their complete existing queries.
	if court.get_script() == HexChemistryWorldScript or court.get_script() == HexCourtScript:
		var world: HexChemistryWorld = court as HexChemistryWorld
		var aggregate_coverage := true
		# Legacy/directly authored ground parts may have no aggregate coverage.
		# Preserve their complete prepared-view fallback instead of hiding them.
		# Ordinary paid records always carry a Dictionary aggregate, even empty.
		for cast_id: int in world.casts:
			if not world.casts[cast_id].get("coverage") is Dictionary:
				aggregate_coverage = false
				break
		if aggregate_coverage and prepared_occupied_court_id != int(court.get_instance_id()):
			var material_cells: Array[Vector2i] = []
			for cell: Vector2i in world.occupied_cells():
				if _cell_set.has(cell): material_cells.append(cell)
			material_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
			_cells = material_cells
	_compact_draw_bundle = true
	var result := _prepare_frame_bundle(court, tick)
	_compact_draw_bundle = previous
	_cells = floor_cells
	return result
