extends HexCourtPresenter

# Frozen pre-optimization boundary path, 2026-09-29. Kept only for exact native
# comparisons and alternating CPU measurements; never used by the game.
func _region_edge_counts(regions_by_cell: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	for cell: Vector2i in regions_by_cell:
		for region: Dictionary in regions_by_cell[cell]:
			var fixed_polygon: PackedVector2Array = region.fixed_polygon
			var prefix := _region_edge_prefix(region)
			for index: int in fixed_polygon.size():
				var key := _region_edge_key(region, fixed_polygon[index], fixed_polygon[(index + 1) % fixed_polygon.size()], prefix)
				counts[key] = int(counts.get(key, 0)) + 1
	return counts


func _draw_region_outline(canvas: CanvasItem, region: Dictionary, edge_counts: Dictionary, color: Color, width: float) -> void:
	var polygon: PackedVector2Array = region.polygon
	var fixed_polygon: PackedVector2Array = region.fixed_polygon
	var center := _polygon_centroid(polygon)
	var prefix := _region_edge_prefix(region)
	for index: int in polygon.size():
		var key := _region_edge_key(region, fixed_polygon[index], fixed_polygon[(index + 1) % fixed_polygon.size()], prefix)
		if int(edge_counts.get(key, 0)) > 1: continue
		for triangle: PackedVector2Array in _inward_edge_triangles(polygon, index, width, center):
			canvas.draw_primitive(triangle, PackedColorArray([color]), PackedVector2Array())
