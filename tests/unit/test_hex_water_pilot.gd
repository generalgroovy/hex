extends FluxTestSuite

const Water = preload("res://src/presentation/hex_water_material_presenter.gd")
const Court = preload("res://src/presentation/hex_court_presenter.gd")
const Grid = preload("res://src/sim/hex/hex_grid.gd")


func run() -> int:
	var water := Water.new()
	check(water.configure(), "both Water candidate resources load and verify: " + water.last_error)
	check(water.ready(), "Water resource verification completes")
	equal(water.evidence().textures.size(), 2, "normal/reduced decoded resource evidence retained")
	var polygon := PackedVector2Array()
	for vertex: Vector2i in Grid.vertices(Vector2i.ZERO): polygon.append(Vector2(vertex) / 1000.0)
	var original := polygon.duplicate()
	for phase: String in Water.ROWS:
		for column: int in 8:
			var sample := Water.sampling(polygon, phase, column * 8.0, 0, false)
			check(not sample.is_empty(), "canonical complete hex maps to Water source cell")
			equal(sample.polygon, polygon, "texture is clipped to the exact supplied canonical polygon")
			equal(sample.frame, Vector2i(column, Water.ROWS.find(phase)), "source row follows authority phase and column follows cosmetic tick")
			var reduced := Water.sampling(polygon, phase, column * 8.0, 0, true)
			equal(reduced.frame.y, sample.frame.y, "reduced never changes authoritative phase")
			equal(reduced.frame.x, 0, "reduced holds representative source motion frame")
			for uv: Vector2 in sample.uv:
				check(uv.x >= float(column) / 8.0 - 0.00001 and uv.x <= float(column + 1) / 8.0 + 0.00001, "UV remains within selected column")
				check(uv.y >= float(sample.frame.y) / 3.0 - 0.00001 and uv.y <= float(sample.frame.y + 1) / 3.0 + 0.00001, "UV remains within selected phase row")
	equal(polygon, original, "sampling does not mutate authority geometry")
	check(Water.sampling(polygon, "expired", 0.0, 0, false).is_empty(), "unknown/expired phase does not invent a motif")
	check(Water.sampling(polygon, "active", NAN, 0, false).is_empty(), "nonfinite tick refuses sampling")
	var too_large := PackedVector2Array()
	# The texture adapter remains 48px wide; the canonical grid is now 24px.
	# Cross its actual sampling bound rather than assuming two grid widths do.
	var overscale := Water.DISPLAY_CELL.x / (float(Grid.HALF_WIDTH) * 2.0 / 1000.0) + 0.01
	for point: Vector2 in polygon: too_large.append(point * overscale)
	check(Water.sampling(too_large, "active", 0.0, 0, false).is_empty(), "unapproved larger geometry cannot bleed into neighboring atlas cells")
	var shifted := PackedVector2Array()
	for point: Vector2 in polygon: shifted.append(point + Vector2(1504, 1344))
	var local_sample := Water.sampling(polygon, "active", 16.0, 3, false)
	var shifted_sample := Water.sampling(shifted, "active", 16.0, 3, false)
	for index: int in 6:
		check((local_sample.uv[index] as Vector2).is_equal_approx(shifted_sample.uv[index]), "UV is invariant under world translation")
	var language := VisualLanguage.new()
	check(language.load_from_file(), "shared semantic language loads")
	var court := Court.new()
	check(court.configure(language), "existing court configuration accepts isolated Water presenter")
	var region := {"phase": "active", "danger": true, "intensity": 600, "owner": 7, "expiry_tick": 800, "footprint_id": 12, "polygon": polygon}
	var before := region.duplicate(true)
	var normal := court._water_region_style(region, false)
	var reduced := court._water_region_style(region, true)
	equal(normal.phase, reduced.phase, "normal/reduced retain semantic phase")
	equal(normal.danger, reduced.danger, "normal/reduced retain danger meaning")
	equal(normal.edge_opacity, reduced.edge_opacity, "complete-cell essential outline remains equally visible")
	equal(region, before, "Water style leaves provenance and expiry untouched")
	court.water_motifs_enabled = false
	equal(court._water_region_style(region, false), normal, "baseline toggle changes only inner marks")
	return finish("hex-water-pilot")
