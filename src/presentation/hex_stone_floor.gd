extends RefCounted

# Static Range stone only. Each cell's fill and marks remain adjacent in the
# original painter order; paid material, apron and perimeter stay with the caller.
# Resident meshes are never evicted while a CanvasItem might still reference
# them. Exhausting either bound uses the caller's unchanged immediate renderer.
const MAX_LAYOUTS := 8
const MAX_CELLS := 512
const MAX_RESIDENT_CELLS := 4096
const PALETTE_SIZE := 12

var _dark: Color
var _low: Color
var _base: Color
var _high: Color
var _light: Color
var _palette: ImageTexture
var _entries: Array[Dictionary] = []
var _resident_cells := 0
var _hits := 0
var _builds := 0
var _draws := 0
var _fallbacks := 0


func _init(dark: Color, low: Color, base: Color, high: Color, light: Color) -> void:
	_dark = dark
	_low = low
	_base = base
	_high = high
	_light = light


func draw(canvas: CanvasItem, ordered_cells: Array[Vector2i], centers: Dictionary,
		vertices: Dictionary, records: Dictionary, reduced: bool) -> bool:
	if ordered_cells.is_empty(): return true
	var entry := _prepare_entry(ordered_cells, centers, vertices, records, reduced)
	if entry.is_empty():
		_fallbacks += 1
		return false
	if _palette == null: _palette = ImageTexture.create_from_image(_palette_image())
	if _palette == null or _palette.get_width() != PALETTE_SIZE:
		_fallbacks += 1
		return false
	canvas.draw_mesh(entry.mesh, _palette)
	_draws += 1
	return true


func stats() -> Dictionary:
	return {"layouts": _entries.size(), "cells": _resident_cells,
		"hits": _hits, "builds": _builds, "draws": _draws, "fallbacks": _fallbacks}


func _prepare_entry(ordered_cells: Array[Vector2i], centers: Dictionary,
		vertices: Dictionary, records: Dictionary, reduced: bool) -> Dictionary:
	if ordered_cells.is_empty() or ordered_cells.size() > MAX_CELLS: return {}
	for entry: Dictionary in _entries:
		if _matches(entry, ordered_cells, centers, vertices, records, reduced):
			_hits += 1
			return entry
	if _entries.size() >= MAX_LAYOUTS or _resident_cells + ordered_cells.size() > MAX_RESIDENT_CELLS: return {}
	var geometry := _geometry(ordered_cells, centers, vertices, records, reduced)
	if geometry.is_empty(): return {}
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = geometry.points
	arrays[Mesh.ARRAY_TEX_UV] = geometry.uv
	arrays[Mesh.ARRAY_INDEX] = geometry.indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if mesh.get_surface_count() != 1: return {}
	var source_vertices := {}
	var source_centers := {}
	var metadata := PackedInt64Array()
	for cell: Vector2i in ordered_cells:
		source_vertices[cell] = (vertices[cell] as PackedVector2Array).duplicate()
		source_centers[cell] = centers[cell]
		var record: Dictionary = records.get(cell, {})
		metadata.append(int(record.get("terrain", 0)))
		metadata.append(clampi(int(record.get("elevation", 0)), 0, 3))
	var entry := {"cells": ordered_cells.duplicate(), "centers": source_centers,
		"vertices": source_vertices, "metadata": metadata, "reduced": reduced, "mesh": mesh}
	_entries.append(entry)
	_resident_cells += ordered_cells.size()
	_builds += 1
	return entry


static func _matches(entry: Dictionary, ordered_cells: Array[Vector2i], centers: Dictionary,
		vertices: Dictionary, records: Dictionary, reduced: bool) -> bool:
	if bool(entry.reduced) != reduced or entry.cells != ordered_cells: return false
	var offset := 0
	for cell: Vector2i in ordered_cells:
		if not centers.has(cell) or not vertices.has(cell): return false
		if entry.centers[cell] != centers[cell] or entry.vertices[cell] != vertices[cell]: return false
		var record: Dictionary = records.get(cell, {})
		if int(record.get("terrain", 0)) != int(entry.metadata[offset]): return false
		if clampi(int(record.get("elevation", 0)), 0, 3) != int(entry.metadata[offset + 1]): return false
		offset += 2
	return true


func _palette_image() -> Image:
	# Float texels retain the original fractional mark opacity and lerped colors.
	# ArrayMesh vertex colors are packed to bytes by the engine, which would change
	# those authored values. Every primitive samples exactly one nearest texel.
	var image := Image.create(PALETTE_SIZE, 1, false, Image.FORMAT_RGBAF)
	for elevation: int in 4:
		var fill := _base.lerp(_high, 0.06 * float(elevation))
		image.set_pixel(elevation * 2, 0, fill)
		image.set_pixel(elevation * 2 + 1, 0, fill.lerp(_low, 0.08))
	image.set_pixel(8, 0, Color(_dark, 0.16))
	image.set_pixel(9, 0, Color(_light, 0.16))
	image.set_pixel(10, 0, Color(_dark, 0.12))
	image.set_pixel(11, 0, Color(_light, 0.12))
	return image


static func _geometry(ordered_cells: Array[Vector2i], centers: Dictionary,
		vertices: Dictionary, records: Dictionary, reduced: bool) -> Dictionary:
	var points := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for cell: Vector2i in ordered_cells:
		if not centers.get(cell) is Vector2 or not vertices.get(cell) is PackedVector2Array: return {}
		var center: Vector2 = centers[cell]
		var polygon: PackedVector2Array = vertices[cell]
		if polygon.size() < 3 or polygon.size() > 6 or not center.is_finite(): return {}
		for point: Vector2 in polygon:
			if not point.is_finite(): return {}
		var triangles := Geometry2D.triangulate_polygon(polygon)
		if triangles.size() != (polygon.size() - 2) * 3: return {}
		var record: Dictionary = records.get(cell, {})
		var terrain := int(record.get("terrain", 0))
		var elevation := clampi(int(record.get("elevation", 0)), 0, 3)
		var seed := _mix(cell.x * 73856093 ^ cell.y * 19349663 ^ (terrain * 17 + elevation * 31))
		_append_primitive(points, uv, indices, polygon, triangles, elevation * 2 + (1 if seed % 5 == 0 else 0))
		for mark_index: int in range(1 if reduced else 3):
			var mark_seed := _mix(seed + mark_index * 97)
			var offset := Vector2(float(posmod(mark_seed, 31) - 15), float(posmod(mark_seed >> 6, 25) - 12))
			var length := 3.0 + float(posmod(mark_seed >> 12, 4))
			var start := (center + offset).round()
			var end := (center + offset + Vector2(length, 0)).round()
			# Same positive-width, non-antialiased line quad as CanvasItem.draw_line.
			# Native pixel A/B also covers fractional transforms and overlapping cells.
			var half_width := (start - end).orthogonal().normalized()
			var quad := PackedVector2Array([start + half_width, start - half_width, end - half_width, end + half_width])
			_append_primitive(points, uv, indices, quad, PackedInt32Array([0, 1, 2, 0, 2, 3]), 8 + (2 if reduced else 0) + (1 if mark_seed & 1 else 0))
	return {"points": points, "uv": uv, "indices": indices}


static func _append_primitive(points: PackedVector3Array, uv: PackedVector2Array,
		indices: PackedInt32Array, polygon: PackedVector2Array, triangles: PackedInt32Array, palette_index: int) -> void:
	var base := points.size()
	var sample := Vector2((float(palette_index) + 0.5) / float(PALETTE_SIZE), 0.5)
	for point: Vector2 in polygon:
		points.append(Vector3(point.x, point.y, 0.0))
		uv.append(sample)
	for index: int in triangles: indices.append(base + index)


static func _mix(value: int) -> int:
	var mixed := value ^ (value >> 16)
	mixed *= 2246822519
	mixed ^= mixed >> 13
	mixed *= 3266489917
	return absi(mixed ^ (mixed >> 16))
