class_name HexRenderFrameCandidate
extends RefCounted


# Test-only frame preparation for the exact base HexChemistryWorld contract.
# Generic and subclass courts retain the presenter's current duck-typed path.
const World = preload("res://src/sim/hex/hex_chemistry_world.gd")
const Presenter = preload("res://src/presentation/hex_court_presenter.gd")


static func current_bundle(court: HexChemistryWorld, presenter: HexCourtPresenter, tick: float) -> Dictionary:
	var views: Dictionary = {}
	for cell: Vector2i in presenter._cells:
		views[cell] = court.view(cell, tick)
	return {"views": views, "regions": presenter._collect_render_regions(court, views, tick)}


static func candidate_bundle(court: HexChemistryWorld, presenter: HexCourtPresenter, tick: float) -> Dictionary:
	if court == null or presenter == null or court.get_script() != World or not is_finite(tick):
		return {}
	var materials: Array[String] = World.material_layers()
	if materials != Presenter.MATERIALS:
		return {}
	var views: Dictionary = {}
	var regions: Dictionary = {}
	for material: String in materials:
		regions[material] = {}
	if presenter._cells.is_empty():
		return {"views": views, "regions": regions}

	# Scalars only: duplicate once per existing cell so output dictionaries retain
	# the exact current field order without sharing mutable nested authority data.
	var zero_view: Dictionary = {"fire_phase": "none", "steam_heat": 1000}
	for material: String in materials:
		zero_view[material + "_quantity"] = 0
		zero_view[material + "_present"] = false
	var preparation_failed := false
	for cell: Vector2i in presenter._cells:
		if not court.cells.has(cell):
			views[cell] = {"fire_phase": "none", "steam_heat": 1000}
			continue
		var view: Dictionary = zero_view.duplicate()
		var record_value: Variant = court.cells[cell]
		if not record_value is Dictionary:
			return current_bundle(court, presenter, tick)
		var record: Dictionary = record_value
		for material: String in materials:
			if not record.has(material):
				continue
			var layer_value: Variant = record[material]
			if not layer_value is Dictionary:
				return current_bundle(court, presenter, tick)
			if (layer_value as Dictionary).is_empty():
				continue
			var raw: Array[Dictionary] = court.render_regions(cell, material, tick)
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
				var expected_polygon: PackedVector2Array = presenter._vertices.get(cell, PackedVector2Array())
				var prepared_region: Dictionary = presenter._prepare_region(value, material, expected_polygon)
				if prepared_region.is_empty():
					preparation_failed = true
					break
				prepared.append(prepared_region)
			if not preparation_failed:
				prepared.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.footprint_id) < int(b.footprint_id))
				(regions[material] as Dictionary)[cell] = prepared
		views[cell] = view
	return {"views": views, "regions": {} if preparation_failed else regions}
