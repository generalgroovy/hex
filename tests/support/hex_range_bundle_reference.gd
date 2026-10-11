extends HexCourtPresenter

# Exact preparation before Range floor/material traversal separation.
# Source SHA256: 5b19c0732c48cd2c30736ed91e49af0b5c11b931c68c2b25f3807fa837b07876

func _prepare_draw_bundle(court: RefCounted, tick: float) -> Dictionary:
	var previous := _compact_draw_bundle
	_compact_draw_bundle = true
	var result := _prepare_frame_bundle(court, tick)
	_compact_draw_bundle = previous
	return result


func _prepare_frame_bundle(court: RefCounted, tick: float) -> Dictionary:
	if court.get_script() != HexChemistryWorldScript:
		return _current_frame_bundle(court, tick)
	var materials: Array[String] = HexChemistryWorld.material_layers()
	if materials != MATERIALS:
		return _current_frame_bundle(court, tick)
	var world: HexChemistryWorld = court as HexChemistryWorld
	var views: Dictionary = {}
	var regions: Dictionary = {}
	if not _compact_draw_bundle:
		for material: String in materials: regions[material] = {}
	if _cells.is_empty():
		return {"views": views, "regions": regions}

	var zero_view: Dictionary = {"fire_phase": "none", "steam_heat": 1000}
	if not _compact_draw_bundle:
		for material: String in materials:
			zero_view[material + "_quantity"] = 0
			zero_view[material + "_present"] = false
	var preparation_failed := false
	for cell: Vector2i in _cells:
		if not world.has_cell(cell):
			views[cell] = {"fire_phase": "none", "steam_heat": 1000}
			continue
		var view: Dictionary = zero_view.duplicate()
		var record_value: Variant = world.cell_record_value(cell)
		if not record_value is Dictionary:
			return _current_frame_bundle(court, tick)
		var record: Dictionary = record_value
		# Sparse authority stores only present layers. Keep the stable output
		# schema, but do work for actual materials rather than44 empty slots.
		for key: Variant in record:
			if typeof(key) not in [TYPE_STRING, TYPE_STRING_NAME] or _material_wire(String(key)) < 0:
				continue
			var material: String = key
			var layer_value: Variant = record[material]
			if not layer_value is Dictionary:
				return _current_frame_bundle(court, tick)
			if (layer_value as Dictionary).is_empty():
				continue
			var raw: Array[Dictionary] = world.render_regions(cell, material, tick)
			if raw.is_empty():
				continue
			var quantity := 0
			for region: Dictionary in raw:
				quantity += int(region.quantity)
				if material == "fire":
					view.fire_phase = region.phase
				elif material == "steam":
					view.steam_heat = maxi(int(view.steam_heat), int(region.intensity))
			view[material + "_quantity"] = quantity
			view[material + "_present"] = true
			if preparation_failed:
				continue
			var prepared: Array[Dictionary] = []
			for value: Dictionary in raw:
				var expected_polygon: PackedVector2Array = _vertices.get(cell, PackedVector2Array())
				var prepared_region: Dictionary = _prepare_region(value, material, expected_polygon)
				if prepared_region.is_empty():
					preparation_failed = true
					break
				prepared.append(prepared_region)
			if not preparation_failed:
				prepared.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.footprint_id) < int(b.footprint_id))
				if not regions.has(material): regions[material] = {}
				(regions[material] as Dictionary)[cell] = prepared
		views[cell] = view
	return {"views": views, "regions": {} if preparation_failed else regions}



# Exact pre-retention floor method, independent of the candidate mesh helper.
func _draw_apron(canvas: CanvasItem, reduced: bool) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, APRON_SIZE), APRON_BASE, true)
	var step := 112 if reduced else 78
	for y: int in range(step / 2, int(APRON_SIZE.y), step):
		for x: int in range(step / 2, int(APRON_SIZE.x), step):
			var seed := _mix(x * 19_349_663 ^ y * 73_856_093 ^ 271)
			var anchor := Vector2(
				float(x + posmod(seed, 25) - 12),
				float(y + posmod(seed >> 6, 21) - 10),
			).round()
			if seed % 5 == 0:
				var pebble_size := Vector2(4 + posmod(seed >> 11, 4), 2)
				canvas.draw_rect(Rect2(anchor - pebble_size * 0.5, pebble_size), Color(STONE_LOW, 0.38), true)
				canvas.draw_line(anchor - Vector2(1, 1), anchor + Vector2(2, -1), Color(STONE_HIGH, 0.30), 1.0)
				continue
			var blade_height := 4.0 + float(posmod(seed >> 12, 4))
			var sway := -2.0 if seed & 1 else 2.0
			canvas.draw_line(anchor, anchor + Vector2(sway, -blade_height), Color(APRON_GRASS, 0.54), 2.0)
			if not reduced and seed % 3 == 0:
				canvas.draw_line(anchor + Vector2(2, 0), anchor + Vector2(4 - sway, -blade_height + 1), Color(APRON_LIGHT, 0.32), 1.0)


# Exact pre-retention floor method, independent of the candidate mesh helper.
func _draw_stone(canvas: CanvasItem, court: RefCounted, reduced: bool) -> void:
	var cells: Dictionary = (court as HexChemistryWorld).topology_cells_view() if court.get_script() == HexChemistryWorldScript else court.get("cells")
	for cell: Vector2i in _cells:
		var record: Dictionary = cells.get(cell, {})
		var terrain := int(record.get("terrain", 0))
		var elevation := clampi(int(record.get("elevation", 0)), 0, 3)
		var seed := _cell_seed(cell, terrain * 17 + elevation * 31)
		var fill := STONE_BASE.lerp(STONE_HIGH, 0.06 * float(elevation))
		fill = fill.lerp(STONE_LOW, 0.08) if seed % 5 == 0 else fill
		canvas.draw_colored_polygon(_vertices[cell], fill)
		var center: Vector2 = _centers[cell]
		var mark_count := 1 if reduced else 3
		for mark_index: int in range(mark_count):
			var mark_seed := _mix(seed + mark_index * 97)
			var offset := Vector2(float(posmod(mark_seed, 31) - 15), float(posmod(mark_seed >> 6, 25) - 12))
			var length := 3.0 + float(posmod(mark_seed >> 12, 4))
			var color := Color(STONE_LIGHT if mark_seed & 1 else STONE_DARK, 0.12 if reduced else 0.16)
			canvas.draw_line((center + offset).round(), (center + offset + Vector2(length, 0)).round(), color, 2.0)


# Exact pre-retention floor method, independent of the candidate mesh helper.
func _draw_outer_rim(canvas: CanvasItem) -> void:
	for cell: Vector2i in _cells:
		var polygon: PackedVector2Array = _vertices[cell]
		for edge_index: int in range(6):
			if _cell_set.has(cell + EDGE_NEIGHBORS[edge_index]):
				continue
			var start := polygon[edge_index]
			var finish := polygon[(edge_index + 1) % 6]
			canvas.draw_line(start + Vector2(0, 4), finish + Vector2(0, 4), Color(STONE_DARK, 0.92), 5.0)
			canvas.draw_line(start, finish, Color(RIM_BRASS, 0.72), 3.0)
			canvas.draw_line(start, finish, Color(STONE_LIGHT, 0.46), 1.0)
