extends FluxTestSuite


const Presenter = preload("res://src/presentation/hex_court_presenter.gd")


# Fabricated rendering authority fixture. It exercises the shared view/region
# contract only and does not claim that the corresponding recipes execute yet.
class SharedRegionCourt:
	extends RefCounted
	var regions_by_material: Dictionary = {}

	func render_regions(_cell: Vector2i, material: String, _tick: float) -> Array:
		return (regions_by_material.get(material, []) as Array).duplicate(true)


func run() -> int:
	_test_complete_stable_material_catalog()
	_test_shared_region_schema_and_whole_cell_coverage()
	_test_source_native_styles_and_reduced_coverage()
	_test_coherent_edges_and_meaningful_boundaries()
	_test_earth_pillar_stays_inside_authority()
	_test_legacy_material_styles_remain_exact()
	return finish("hex-shared-presenter")


func _configured_presenter() -> HexCourtPresenter:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "shared visual language loads for generalized hex materials")
	var presenter := Presenter.new()
	check(presenter.configure(language), "generalized presenter accepts the canonical visual language")
	return presenter


func _test_complete_stable_material_catalog() -> void:
	equal(Presenter.INGREDIENT_MATERIALS, ["earth", "fire", "water", "wind", "ice", "charge", "light", "dark"], "all eight ingredient layers use stable element names")
	equal(Presenter.PRODUCT_MATERIALS.size(), 36, "compiled stable pairs expose exactly thirty-six presentation materials")
	equal(Presenter.MATERIALS.size(), 44, "shared material query covers eight ingredients and thirty-six products")
	var presenter := _configured_presenter()
	var seen_names := {}
	var seen_wires := {}
	for index: int in Presenter.PRODUCT_ROWS.size():
		var row: Array = Presenter.PRODUCT_ROWS[index]
		var name := String(row[0])
		var wire := int(row[1])
		equal(name, Presenter.PRODUCT_MATERIALS[index], "product material order follows its stable recipe wire")
		equal(wire, 301 + index, "product recipe wire remains contiguous and explicit")
		check(not seen_names.has(name) and not seen_wires.has(wire), "product names and wires are unique")
		seen_names[name] = true
		seen_wires[wire] = true
		var descriptor := presenter._material_descriptor(name)
		equal(int(descriptor.wire_id), wire, "product descriptor retains its exact compiled recipe identity")
		check(String(descriptor.first) in Presenter.INGREDIENT_MATERIALS and String(descriptor.second) in Presenter.INGREDIENT_MATERIALS, "product palette names two active source elements")
		check(not String(descriptor.shape).is_empty(), "product keeps an authored presentation shape vocabulary")
		check(not String(descriptor.cadence).is_empty(), "product motion cadence derives from its two VisualLanguage sources")
	equal(Presenter.PRODUCT_MATERIALS[0], "fortify", "first stable product is Fortify")
	equal(Presenter.PRODUCT_MATERIALS[-1], "umbral_field", "last stable product is Umbral Field")


func _test_shared_region_schema_and_whole_cell_coverage() -> void:
	var presenter := _configured_presenter()
	var cell := Vector2i.ZERO
	var fixed_polygon := _fixed_hex(cell)
	presenter._cells = [cell]
	presenter._vertices[cell] = _display_polygon(fixed_polygon)
	var court := SharedRegionCourt.new()
	var views := {cell: {}}
	for material: String in Presenter.MATERIALS:
		views[cell][material + "_quantity"] = 1
		var wire := 0 if material in Presenter.INGREDIENT_MATERIALS else 301 + Presenter.PRODUCT_MATERIALS.find(material)
		court.regions_by_material[material] = [{
			"footprint_id": 900 + Presenter.MATERIALS.find(material), "polygon": fixed_polygon,
			"phase": "active", "danger": material == "magma", "intensity": 875, "quantity": 12_345,
			"owner": 7, "source_ids": [101, 102], "expiry_tick": 600, "recipe_wire_id": wire,
			"direction": Vector2i(600, -800),
		}]
	var regions := presenter._collect_render_regions(court, views, 120.0)
	equal(regions.size(), 44, "one shared authority call prepares every ingredient and stable product material")
	for material: String in Presenter.MATERIALS:
		check(regions.has(material), "shared output retains the requested material key")
		equal((regions[material] as Dictionary).size(), 1, "active material retains its one selected cell")
		var prepared: Dictionary = ((regions[material] as Dictionary)[cell] as Array)[0]
		equal(prepared.fixed_polygon, fixed_polygon, "authority keeps the exact full-cell fixed polygon")
		equal(prepared.polygon, _display_polygon(fixed_polygon), "display conversion preserves all six authority vertices")
		equal(int(prepared.quantity), 12_345, "material quantity survives preparation")
		equal(int(prepared.owner), 7, "owner survives preparation")
		equal(prepared.source_ids, [101, 102], "source provenance survives preparation")
		equal(int(prepared.recipe_wire_id), 0 if material in Presenter.INGREDIENT_MATERIALS else 301 + Presenter.PRODUCT_MATERIALS.find(material), "recipe identity survives preparation")
		equal(prepared.direction, Vector2i(600, -800), "authored direction survives preparation")
	var corrupt: Dictionary = (court.regions_by_material["magma"] as Array)[0].duplicate(true)
	corrupt.recipe_wire_id = 303
	check(presenter._prepare_region(corrupt, "magma", _display_polygon(fixed_polygon)).is_empty(), "product material rejects a mismatched recipe identity")
	corrupt = (court.regions_by_material["magma"] as Array)[0].duplicate(true)
	corrupt.direction = [600, -800]
	check(presenter._prepare_region(corrupt, "magma", _display_polygon(fixed_polygon)).is_empty(), "material direction rejects a non-vector transport value")


func _test_source_native_styles_and_reduced_coverage() -> void:
	var presenter := _configured_presenter()
	var region := {"phase": "active", "danger": false, "intensity": 1000}
	for material: String in Presenter.MATERIALS:
		if material in ["water", "fire", "steam", "flood", "conflagration"]:
			continue
		var normal := presenter._shared_material_style(material, region, false)
		var reduced := presenter._shared_material_style(material, region, true)
		check(not normal.is_empty() and not reduced.is_empty(), "every new material has a source-derived presentation style")
		equal(normal.shape, reduced.shape, "reduced mode preserves the material silhouette vocabulary")
		equal(normal.phase, reduced.phase, "reduced mode preserves authoritative phase")
		equal(normal.mark_count, reduced.mark_count, "reduced mode preserves at least one identity mark per selected cell")
		check(float(normal.fill_opacity) > 0.0 and float(reduced.fill_opacity) > 0.0, "both modes retain visible whole-cell coverage")
		check(not bool(reduced.motion) and bool(normal.motion), "reduced mode removes motion without deleting coverage")
		check(normal.base != Color.MAGENTA and normal.bright != Color.MAGENTA, "shared material colors resolve through VisualLanguage source elements")
	for material: String in Presenter.ATMOSPHERIC_MATERIALS:
		if material in ["steam"]:
			continue
		var atmosphere := presenter._shared_material_style(material, region, false)
		check(bool(atmosphere.atmospheric), "atmospheric material is explicitly classified")
		check(float(atmosphere.fill_opacity) <= 0.18, "atmospheric coverage remains transparent in normal mode")
		var intense_atmosphere := presenter._shared_material_style(material, {"phase": "active", "danger": true, "intensity": 10_000}, false)
		check(float(intense_atmosphere.fill_opacity) <= 0.22, "high intensity cannot turn an atmosphere into an opaque floor")
	check(Presenter._cadence_rate("snapping") > Presenter._cadence_rate("weighty"), "VisualLanguage snapping cadence moves faster than weighty Earth cadence")


func _test_coherent_edges_and_meaningful_boundaries() -> void:
	var presenter := _configured_presenter()
	var left_cell := Vector2i.ZERO
	var right_cell := Vector2i(1, 0)
	var common := {
		"footprint_id": 44, "phase": "active", "danger": false, "intensity": 700,
		"owner": 3, "expiry_tick": 800, "recipe_wire_id": 304, "quantity": 5000,
		"source_ids": [91], "direction": Vector2i.RIGHT,
	}
	var left_source := common.duplicate(true)
	left_source.polygon = _fixed_hex(left_cell)
	var right_source := common.duplicate(true)
	right_source.polygon = _fixed_hex(right_cell)
	right_source.footprint_id = 45
	right_source.intensity = 900
	right_source.expiry_tick = 950
	var left := presenter._prepare_region(left_source, "dustfront")
	var right := presenter._prepare_region(right_source, "dustfront")
	var counts := presenter._region_edge_counts({left_cell: [left], right_cell: [right]})
	var shared_key := ""
	for key: String in counts:
		if int(counts[key]) == 2:
			shared_key = key
			break
	check(not shared_key.is_empty(), "same-owner and same-phase material regions hide their internal edge across source records")
	var outer_edges := 0
	for key: String in counts:
		if int(counts[key]) == 1:
			outer_edges += 1
	equal(outer_edges, 10, "coherent pair retains all ten outer and hole-facing edges")
	var changed_source := right_source.duplicate(true)
	changed_source.owner = 4
	var changed := presenter._prepare_region(changed_source, "dustfront")
	var split_counts := presenter._region_edge_counts({left_cell: [left], right_cell: [changed]})
	var doubled := false
	for key: String in split_counts:
		if int(split_counts[key]) > 1:
			doubled = true
	check(not doubled, "ownership change keeps the shared boundary visible")
	changed_source = right_source.duplicate(true)
	changed_source.phase = "decaying"
	changed = presenter._prepare_region(changed_source, "dustfront")
	split_counts = presenter._region_edge_counts({left_cell: [left], right_cell: [changed]})
	for key: String in split_counts:
		check(int(split_counts[key]) == 1, "phase change keeps each side of its boundary distinct")


func _test_earth_pillar_stays_inside_authority() -> void:
	var polygon := _display_polygon(_fixed_hex(Vector2i.ZERO))
	var geometry := Presenter._earth_pillar_geometry(polygon, 7.0)
	equal((geometry.top as PackedVector2Array).size(), 6, "Earth pillar has one actual six-vertex top")
	equal((geometry.faces as Array).size(), 6, "Earth pillar has six explicit side faces")
	check(float(geometry.height) > 0.0, "Earth pillar retains visible height")
	for point: Vector2 in geometry.top:
		check(_inside_convex_hex(point, polygon), "Earth pillar top remains inside the selected hex")
	for face_value: Variant in geometry.faces:
		var face: PackedVector2Array = face_value
		equal(face.size(), 4, "each Earth side face is a bounded quadrilateral")
		for point: Vector2 in face:
			check(_inside_convex_hex(point, polygon), "Earth side face never paints hazard authority outside the cell")


func _test_legacy_material_styles_remain_exact() -> void:
	var presenter := _configured_presenter()
	var water := presenter._water_region_style({"phase": "active", "danger": false, "intensity": 1000}, false)
	equal(water.base, presenter._language.element_color("water", "base"), "Water retains its canonical saturated base")
	equal(float(water.fill_opacity), 0.60, "Water normal opacity remains unchanged")
	var fire := presenter._fire_region_style({"phase": "active", "danger": true, "intensity": 1000}, false)
	equal(float(fire.fill_opacity), 0.18, "Fire active opacity remains unchanged")
	equal(fire.edge, fire.danger_color, "Fire danger edge remains unchanged")
	var steam := presenter._steam_region_style({"phase": "active", "danger": true, "intensity": 1000}, 1500, false)
	equal(steam.palette_phase, "hot", "Steam heat still selects the established hot palette")
	equal(int(steam.mark_count), 2, "Steam retains two identity curls")


func _fixed_hex(cell: Vector2i) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2i in HexGrid.vertices(cell):
		result.append(Vector2(point))
	return result


func _display_polygon(fixed_polygon: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in fixed_polygon:
		result.append(point / 1000.0)
	return result


func _inside_convex_hex(point: Vector2, polygon: PackedVector2Array) -> bool:
	var sign := 0
	for index: int in polygon.size():
		var cross := (polygon[(index + 1) % polygon.size()] - polygon[index]).cross(point - polygon[index])
		if absf(cross) <= 0.0001:
			continue
		var current := 1 if cross > 0.0 else -1
		if sign != 0 and current != sign:
			return false
		sign = current
	return true
