extends FluxTestSuite
@warning_ignore_start("integer_division")

const Floor = preload("res://src/presentation/hex_stone_floor.gd")
const Presenter = preload("res://src/presentation/hex_court_presenter.gd")
const Grid = preload("res://src/sim/hex/hex_grid.gd")


func run() -> int:
	_test_ordered_geometry_and_palette()
	_test_actual_source_invalidation()
	_test_residency_bounds_and_fallback()
	return finish("hex-stone-floor")


func _floor() -> RefCounted:
	return Floor.new(Presenter.STONE_DARK, Presenter.STONE_LOW, Presenter.STONE_BASE, Presenter.STONE_HIGH, Presenter.STONE_LIGHT)


func _fixture(count: int = 7, origin: Vector2 = Vector2(640.25, 480.75)) -> Dictionary:
	var cells: Array[Vector2i] = []
	var centers := {}
	var vertices := {}
	var records := {}
	for index: int in count:
		var cell := Vector2i(index - count / 2, index % 3 - 1)
		cells.append(cell)
		centers[cell] = origin + Vector2(Grid.center(cell)) / 1000.0
		var polygon := PackedVector2Array()
		for point: Vector2i in Grid.vertices(cell): polygon.append(origin + Vector2(point) / 1000.0)
		vertices[cell] = polygon
		records[cell] = {"terrain": index % 5, "elevation": index % 6 - 1}
	return {"cells": cells, "centers": centers, "vertices": vertices, "records": records}


func _entry(floor: RefCounted, fixture: Dictionary, reduced: bool = false) -> Dictionary:
	return floor._prepare_entry(fixture.cells, fixture.centers, fixture.vertices, fixture.records, reduced)


func _test_ordered_geometry_and_palette() -> void:
	var floor := _floor()
	var palette: Image = floor._palette_image()
	equal(palette.get_format(), Image.FORMAT_RGBAF, "stone palette retains fractional authored color values")
	for reduced: bool in [false, true]:
		for origin: Vector2 in [Vector2.ZERO, Vector2(640.25, 480.75), Vector2(-99.75, -30.25)]:
			var fixture := _fixture(19, origin)
			var before := var_to_bytes(fixture)
			var geometry: Dictionary = Floor._geometry(fixture.cells, fixture.centers, fixture.vertices, fixture.records, reduced)
			var expected_points := PackedVector3Array()
			var expected_colors: Array[Color] = []
			var expected_indices := PackedInt32Array()
			# Reconstruct the old renderer's per-cell primitive stream independently;
			# retained triangles must keep its exact interleaved fill/mark ordering.
			for cell: Vector2i in fixture.cells:
				var record: Dictionary = fixture.records[cell]
				var elevation := clampi(int(record.elevation), 0, 3)
				var seed := Presenter._cell_seed(cell, int(record.terrain) * 17 + elevation * 31)
				var color := Presenter.STONE_BASE.lerp(Presenter.STONE_HIGH, 0.06 * float(elevation))
				if seed % 5 == 0: color = color.lerp(Presenter.STONE_LOW, 0.08)
				var polygon: PackedVector2Array = fixture.vertices[cell]
				_append_reference(expected_points, expected_colors, expected_indices, polygon, Geometry2D.triangulate_polygon(polygon), color)
				var center: Vector2 = fixture.centers[cell]
				for mark_index: int in range(1 if reduced else 3):
					var mark_seed := Presenter._mix(seed + mark_index * 97)
					var offset := Vector2(float(posmod(mark_seed, 31) - 15), float(posmod(mark_seed >> 6, 25) - 12))
					var length := 3.0 + float(posmod(mark_seed >> 12, 4))
					var start := (center + offset).round()
					var end := (center + offset + Vector2(length, 0)).round()
					# Horizontal width2 line expands exactly one pixel up and down.
					var line := PackedVector2Array([start + Vector2(0, 1), start - Vector2(0, 1), end - Vector2(0, 1), end + Vector2(0, 1)])
					color = Color(Presenter.STONE_LIGHT if mark_seed & 1 else Presenter.STONE_DARK, 0.12 if reduced else 0.16)
					_append_reference(expected_points, expected_colors, expected_indices, line, PackedInt32Array([0, 1, 2, 0, 2, 3]), color)
			check(not geometry.is_empty(), "valid original stone geometry is admitted")
			equal(geometry.points, expected_points, "stone and every mark preserve exact painter order and pixel positions")
			equal(geometry.indices, expected_indices, "stone triangulation and mark triangle order match the original primitives")
			for index: int in expected_colors.size():
				var sample: Vector2 = geometry.uv[index]
				equal(sample.y, 0.5, "every color sample is centered in its single palette row")
				var palette_index := int(floorf(sample.x * float(Floor.PALETTE_SIZE)))
				equal(palette.get_pixel(palette_index, 0), expected_colors[index], "float texture samples the exact original primitive color and opacity")
			equal(var_to_bytes(fixture), before, "mesh preparation does not mutate topology or authoritative records")
			var entry := _entry(floor, fixture, reduced)
			check(not entry.is_empty(), "bounded real source obtains a native mesh")
			var arrays: Array = (entry.mesh as ArrayMesh).surface_get_arrays(0)
			equal(arrays[Mesh.ARRAY_VERTEX], expected_points, "native mesh contains the complete ordered primitive stream")
			equal(arrays[Mesh.ARRAY_INDEX], expected_indices, "native mesh retains the exact triangulation")


static func _append_reference(points: PackedVector3Array, colors: Array[Color], indices: PackedInt32Array,
		polygon: PackedVector2Array, triangles: PackedInt32Array, color: Color) -> void:
	var base := points.size()
	for point: Vector2 in polygon:
		points.append(Vector3(point.x, point.y, 0.0))
		colors.append(color)
	for index: int in triangles: indices.append(base + index)


func _test_actual_source_invalidation() -> void:
	for mutation: String in ["terrain", "elevation", "center", "polygon", "order", "membership", "reduced"]:
		var floor := _floor()
		var fixture := _fixture()
		var original := fixture.duplicate(true)
		var first := _entry(floor, fixture)
		var first_mesh: ArrayMesh = first.mesh
		equal(_entry(floor, fixture).mesh, first_mesh, "unchanged layout reuses its resident native mesh")
		var cell: Vector2i = fixture.cells[0]
		match mutation:
			"terrain": fixture.records[cell].terrain = 42
			"elevation": fixture.records[cell].elevation = 2
			"center": fixture.centers[cell] += Vector2(1.25, -0.75)
			"polygon":
				var polygon: PackedVector2Array = fixture.vertices[cell]
				polygon[0] += Vector2(0.25, 0.5)
				fixture.vertices[cell] = polygon
			"order": fixture.cells.reverse()
			"membership":
				var replacement := Vector2i(99, 99)
				fixture.cells[0] = replacement
				fixture.centers[replacement] = fixture.centers[cell]
				fixture.vertices[replacement] = fixture.vertices[cell]
				fixture.records[replacement] = fixture.records[cell].duplicate()
		var changed := _entry(floor, fixture, mutation == "reduced")
		check(not changed.is_empty() and changed.mesh != first_mesh, "direct " + mutation + " change cannot reuse stale floor geometry or color")
		equal(_entry(floor, original).mesh, first_mesh, "exact restoration reuses the original retained mesh after " + mutation)
		equal(floor.stats().layouts, 2, "source mutation retains only the two observed layouts")
	var floor := _floor()
	var fixture := _fixture()
	var first := _entry(floor, fixture)
	fixture.records[fixture.cells[0]].elevation = -99
	fixture.records[fixture.cells[0]].fire = {"quantity": 999}
	equal(_entry(floor, fixture).mesh, first.mesh, "clamped equivalent elevation and unrelated live material do not rebuild stone")


func _test_residency_bounds_and_fallback() -> void:
	var floor := _floor()
	var first: Dictionary = {}
	for index: int in Floor.MAX_LAYOUTS:
		var fixture := _fixture(469, Vector2(index * 8, 0))
		var entry := _entry(floor, fixture)
		check(not entry.is_empty(), "each layout inside both residency limits gets a retained native mesh")
		if index == 0: first = entry
	var stats: Dictionary = floor.stats()
	equal(stats.layouts, Floor.MAX_LAYOUTS, "layout residency never exceeds its explicit bound")
	equal(stats.cells, 469 * Floor.MAX_LAYOUTS, "resident source geometry accounts for every retained cell")
	check(int(stats.cells) <= Floor.MAX_RESIDENT_CELLS, "retained cell memory stays bounded")
	check(_entry(floor, _fixture(1, Vector2(9999, 9999))).is_empty(), "additional layouts request the original drawing path without evicting in-flight meshes")
	equal(_entry(floor, _fixture(469, Vector2.ZERO)).mesh, first.mesh, "overflow preserves all earlier native mesh identities")
	var oversized := _fixture(Floor.MAX_CELLS + 1)
	check(_entry(_floor(), oversized).is_empty(), "oversize generic courts retain the original renderer")
	var malformed := _fixture(1)
	malformed.vertices[malformed.cells[0]] = PackedVector2Array()
	check(_entry(_floor(), malformed).is_empty(), "unsupported polygons fail closed to the original renderer")
	var invalid := _fixture(1)
	invalid.centers[invalid.cells[0]] = Vector2(INF, 0)
	check(_entry(_floor(), invalid).is_empty(), "nonfinite layout never uploads a native mesh")
