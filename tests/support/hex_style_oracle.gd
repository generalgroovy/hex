extends HexCourtPresenter
## Test-only pre-simplification draw loop. Shares current geometry, deliberately
## recalculates the unmodified raw style for each region; no production fallback.

func _draw_shared_material(canvas: CanvasItem, regions_by_cell: Dictionary, material: String, tick: float, reduced: bool) -> void:
	if regions_by_cell.is_empty():
		return
	var edge_counts := _region_edge_counts(regions_by_cell)
	for cell: Vector2i in regions_by_cell:
		for region: Dictionary in regions_by_cell[cell]:
			var style := _shared_material_style(material, region, reduced)
			if style.is_empty():
				continue
			canvas.draw_colored_polygon(region.polygon, Color(style.base, style.fill_opacity))
			_draw_region_outline(canvas, region, edge_counts, Color(style.edge, style.edge_opacity), style.edge_width)
			var seed := _cell_seed(cell, int(region.footprint_id) * 1597 + int(style.wire_id))
			_draw_shared_material_mark(canvas, region, style, tick, seed, reduced)
