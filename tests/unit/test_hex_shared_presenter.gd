extends FluxTestSuite


const Presenter = preload("res://src/presentation/hex_court_presenter.gd")
const Policy = preload("res://src/sim/hex/hex_recipe_policy.gd")
const Mixtures = preload("res://src/content/mixture_catalog.gd")

class StyleCounter extends HexCourtPresenter:
	var evaluations := 0
	func _shared_material_style(material: String, region: Dictionary, reduced: bool) -> Dictionary:
		evaluations += 1
		return super._shared_material_style(material, region, reduced)


# Fabricated rendering authority fixture. It exercises the shared view/region
# contract only and does not claim that the corresponding recipes execute yet.
class SharedRegionCourt:
	extends RefCounted
	var regions_by_material: Dictionary = {}

	func render_regions(_cell: Vector2i, material: String, _tick: float) -> Array:
		return (regions_by_material.get(material, []) as Array).duplicate(true)


func run() -> int:
	_test_complete_stable_material_catalog()
	_test_call_local_style_reuse()
	_test_shared_region_schema_and_whole_cell_coverage()
	_test_source_native_styles_and_reduced_coverage()
	_test_coherent_edges_and_meaningful_boundaries()
	_test_overlapping_regions_preserve_boundaries()
	_test_overlapping_ring_preserves_hole()
	_test_overlapping_region_semantic_boundaries()
	_test_earth_pillar_stays_inside_authority()
	_test_legacy_material_styles_remain_exact()
	_test_combat_phase_contrast()
	_test_compact_paid_material_frames()
	return finish("hex-shared-presenter")


func _test_call_local_style_reuse() -> void:
	var presenter := _configured_presenter()
	var memo := {}
	for material: String in Presenter.MATERIALS:
		for phase: String in ["forming", "ignition", "active", "decaying", "cooling", "custom"]:
			for danger: bool in [false, true]:
				for reduced: bool in [false, true]:
					for intensity: float in [0.0, 350.0, 713.125, 713.126, 1000.0, 1500.0]:
						var region := {"phase":phase, "danger":danger, "intensity":intensity}
						var expected := presenter._shared_material_style(material, region, reduced)
						var actual := presenter._shared_style_for_draw(memo, material, region, reduced)
						equal(var_to_bytes(actual), var_to_bytes(expected), "call-local style exactly matches uncached style for every material/input")
						check(actual.is_read_only(), "memoized style cannot be poisoned by a caller")
						check(memo.size() <= Presenter.DRAW_STYLE_LIMIT, "even generic phases/intensities cannot grow memo beyond64 entries")
	var counter := StyleCounter.new()
	check(counter.configure(presenter._language), "style-work counter configures")
	# Configuration validates the native surface palettes once. Measure draw
	# memoization relative to that setup work, not the lifetime counter.
	var setup_evaluations := counter.evaluations
	var repeated := {}
	for index: int in 500:
		counter._shared_style_for_draw(repeated, "earth", {"phase":"active", "intensity":1000, "owner":index, "footprint_id":index, "direction":Vector2i(index, 1000)}, false)
	var first_draw_evaluations := counter.evaluations - setup_evaluations
	equal(first_draw_evaluations, 1, "500 equal styles use one evaluation, regardless of separately evaluated ownership and geometry")
	var next_draw := {}
	counter._shared_style_for_draw(next_draw, "earth", {"phase":"active", "intensity":1000}, false)
	equal(counter.evaluations - setup_evaluations, 2, "a new draw evaluates its own style instead of retaining a previous draw's memo")
	for index: int in 500:
		counter._shared_style_for_draw(next_draw, "earth", {"phase":"active", "intensity":1000, "owner":index}, false)
	equal(counter.evaluations - setup_evaluations, 2, "a second draw also reuses its style across500 matching regions")
	counter._shared_style_for_draw(next_draw, "earth", {"phase":"active", "intensity":800}, false)
	equal(counter.evaluations - setup_evaluations, 3, "changed style inputs still require a fresh evaluation within the same draw")
	print("STYLE MEMO: setup=%d first_draw=%d second_draw_and_changed_input=%d" % [setup_evaluations, first_draw_evaluations, counter.evaluations - setup_evaluations - first_draw_evaluations])
	var region := {"phase":"active", "danger":false, "intensity":800}
	var old := presenter._shared_style_for_draw({}, "earth", region, false)
	presenter._language.elements.earth.base = "#123456"
	var changed := presenter._shared_style_for_draw({}, "earth", region, false)
	check(old.base != changed.base, "a new draw sees palette mutations immediately")
	equal(changed, presenter._shared_material_style("earth", region, false), "fresh draw cannot reuse the previous palette")
	check(presenter._shared_style_for_draw({}, "unknown", region, false).is_empty(), "unknown material remains rejected")


func _test_combat_phase_contrast() -> void:
	var presenter := _configured_presenter()
	for material: String in Presenter.PRODUCT_MATERIALS:
		if String(presenter._material_descriptor(material).visual_material) not in Presenter.COMBAT_PHASE_MATERIALS: continue
		for reduced: bool in [false, true]:
			var forming := presenter._shared_material_style(material, {"phase":"forming", "danger":false, "intensity":1000}, reduced)
			var active := presenter._shared_material_style(material, {"phase":"active", "danger":true, "intensity":1000}, reduced)
			var decay := presenter._shared_material_style(material, {"phase":"decaying", "danger":false, "intensity":1000}, reduced)
			equal(float(forming.mark_scale), 0.72, "preparation has a smaller material stamp in both effects settings")
			equal(float(active.mark_scale), 1.0, "active pressure retains its full native mark and footprint")
			equal(float(decay.mark_scale), 0.40, "harmless decay shrinks only the material stamp")
			check(active.bright.get_luminance() > forming.bright.get_luminance() + 0.12, "active material is clearly brighter than preparing material")
			check(forming.dark.get_luminance() < 0.20 and forming.bright.get_luminance() < 0.33, "warning ink stays dark against the pale Wellspring floor, including Light")
			check(float(decay.fill_opacity) < float(forming.fill_opacity) * 0.5, "decay cannot resemble a newly forming field")
			check(float(decay.edge_opacity) < float(forming.edge_opacity), "decay boundary is distinctly quieter than warning")
			equal(active.shape, forming.shape, "elemental silhouette remains the same across phases")
			equal(active.mark_count, decay.mark_count, "no added mark count or particle layer")
			for style: Dictionary in [forming, active, decay]:
				check(float(style.mark_scale) > 0.0 and float(style.mark_scale) <= 1.0, "phase cues never enlarge affected geometry")
	# Unrelated utility/cover and ingredient grammar stays untouched.
	for material: String in ["water", "earth", "fire", "wind", "light", "dark", "fortify", "flood", "mirrorwater"]:
		var style := presenter._shared_material_style(material, {"phase":"forming", "danger":false, "intensity":1000}, true)
		equal(float(style.mark_scale), 1.0, "unrelated material marks keep their original scale")


func _configured_presenter() -> HexCourtPresenter:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "shared visual language loads for generalized hex materials")
	var presenter := Presenter.new()
	check(presenter.configure(language), "generalized presenter accepts the canonical visual language")
	return presenter


func _test_complete_stable_material_catalog() -> void:
	equal(Presenter.INGREDIENT_MATERIALS, ["water", "fire", "wind", "earth", "light", "dark"], "six canonical ingredients retain stable sparse wire identities")
	equal(Presenter.PRODUCT_MATERIALS.size(), 63, "all 63 live combinations have explicit presentation materials")
	equal(Presenter.MATERIALS.size(), 69, "shared material query covers six ingredients plus63 products")
	equal(HexChemistryWorld.material_layers(), Presenter.MATERIALS, "strict world and presenter admit the same ordered live surface contract")
	var presenter := _configured_presenter()
	var seen_names := {}
	var seen_wires := {}
	var wires: Array[int] = Policy.active_wire_ids()
	for index: int in wires.size():
		var wire: int = wires[index]
		var definition := Policy.definition(wire)
		var name := String(definition.product_layer)
		equal(name, Presenter.PRODUCT_MATERIALS[index], "product render order follows live policy without contiguous-wire arithmetic")
		check(not seen_names.has(name) and not seen_wires.has(wire), "product names and wires are unique")
		seen_names[name] = true
		seen_wires[wire] = true
		var descriptor := presenter._material_descriptor(name)
		equal(int(descriptor.wire_id), wire, "product descriptor retains actual live recipe identity")
		var archived: Dictionary = Presenter.ArchiveContract.REACTIONS[int(definition.archive_recipe_wire) - 301]
		equal([descriptor.first, descriptor.second], archived.elements, "palette sources belong to the explicit archive alias, including derived Ice/Charge styles")
		equal(String(descriptor.shape), String(archived.shape), "archived motif is separate from the authoritative occupied footprint")
		check(not String(descriptor.cadence).is_empty(), "product cadence derives from preserved VisualLanguage styles")
	equal(Presenter.PRODUCT_MATERIALS[0], "fortify", "first retained stable product is Rampart")
	equal(Presenter.PRODUCT_MATERIALS[-1], "compound_63", "all-six Convergence remains inspectable and renderable")


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
		var wire := 0 if material in Presenter.INGREDIENT_MATERIALS else Policy.active_wire_ids()[Presenter.PRODUCT_MATERIALS.find(material)]
		court.regions_by_material[material] = [{
			"footprint_id": 900 + Presenter.MATERIALS.find(material), "polygon": fixed_polygon,
			"phase": "active", "danger": material == "magma", "intensity": 875, "quantity": 12_345,
			"owner": 7, "source_ids": [101, 102], "expiry_tick": 600, "recipe_wire_id": wire,
			"direction": Vector2i(600, -800),
		}]
	var regions := presenter._collect_render_regions(court, views, 120.0)
	equal(regions.size(), 69, "one shared authority call prepares every ingredient and stable product material")
	for material: String in Presenter.MATERIALS:
		check(regions.has(material), "shared output retains the requested material key")
		equal((regions[material] as Dictionary).size(), 1, "active material retains its one selected cell")
		var prepared: Dictionary = ((regions[material] as Dictionary)[cell] as Array)[0]
		equal(prepared.fixed_polygon, fixed_polygon, "authority keeps the exact full-cell fixed polygon")
		equal(prepared.polygon, _display_polygon(fixed_polygon), "display conversion preserves all six authority vertices")
		equal(int(prepared.quantity), 12_345, "material quantity survives preparation")
		equal(int(prepared.owner), 7, "owner survives preparation")
		equal(prepared.source_ids, [101, 102], "source provenance survives preparation")
		equal(int(prepared.recipe_wire_id), 0 if material in Presenter.INGREDIENT_MATERIALS else Policy.active_wire_ids()[Presenter.PRODUCT_MATERIALS.find(material)], "recipe identity survives preparation")
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
	for material: String in Presenter.MATERIALS:
		if not bool(presenter._material_descriptor(material).atmospheric) or material == "steam":
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


func _test_overlapping_regions_preserve_boundaries() -> void:
	var presenter := _configured_presenter()
	var left_cell := Vector2i.ZERO
	var right_cell := Vector2i(1, 0)
	var first := _boundary_region(presenter, left_cell, 44)
	var second := _boundary_region(presenter, left_cell, 45, {"intensity": 900, "expiry_tick": 950})
	var single := presenter._region_edge_counts({left_cell: [first]})
	var overlapping := {left_cell: [first, second]}
	var before := var_to_bytes(overlapping)
	var counts := presenter._region_edge_counts(overlapping)
	equal(counts.size(), 6, "same-cell overlap retains exactly six boundary segments")
	for key: String in counts:
		equal(int(counts[key]), 1, "two compatible records in one cell cannot erase an exterior edge")
	equal(counts, single, "same-cell overlap has the same exterior as one selected hex")
	equal(var_to_bytes(overlapping), before, "boundary counting preserves independent record metadata and lifetime")

	var right := _boundary_region(presenter, right_cell, 45, {"intensity": 900, "expiry_tick": 950})
	var adjacent := {left_cell: [first, second], right_cell: [right, right.duplicate(true)]}
	counts = presenter._region_edge_counts(adjacent)
	equal(counts.size(), 11, "two overlapping neighboring cells retain eleven unique segments")
	var exterior := 0
	var internal := 0
	for key: String in counts:
		if int(counts[key]) == 1: exterior += 1
		elif int(counts[key]) == 2: internal += 1
		else: check(false, "compatible edge counts represent distinct cells, never source multiplicity")
	equal(exterior, 10, "overlapping adjacent records retain all ten exterior edges")
	equal(internal, 1, "only the real shared cell edge is hidden")

	# Model independent authoritative membership updates. This presenter test
	# checks fresh-frame boundaries, not the simulation's expiry clock.
	var surviving_pair := {left_cell: [second], right_cell: [right]}
	equal(presenter._region_edge_counts(surviving_pair), counts, "removing an expired overlap preserves the surviving footprint boundary")
	equal(presenter._region_edge_counts({left_cell: [first]}), single, "removing neighboring coverage restores its former internal edge as exterior")
	equal(presenter._region_edge_counts({}), {}, "final coverage expiry leaves no retained boundary counts")


func _test_overlapping_ring_preserves_hole() -> void:
	var presenter := _configured_presenter()
	var ring := {}
	var reference := {}
	var exemplar: Dictionary = {}
	for cell: Vector2i in HexGrid.AXIAL_DIRECTIONS:
		var first := _boundary_region(presenter, cell, 44)
		var second := _boundary_region(presenter, cell, 45, {"intensity": 900, "expiry_tick": 950})
		ring[cell] = [first, second]
		reference[cell] = [first]
		exemplar = first
	var before := var_to_bytes(ring)
	var counts := presenter._region_edge_counts(ring)
	equal(counts, presenter._region_edge_counts(reference), "overlapping ring preserves the same union boundary as singly occupied ring cells")
	equal(counts.size(), 30, "six-cell ring retains its thirty unique cell segments")
	var exterior := 0
	var internal := 0
	for key: String in counts:
		if int(counts[key]) == 1: exterior += 1
		elif int(counts[key]) == 2: internal += 1
		else: check(false, "ring edge counts cannot grow with overlapping records")
	equal(exterior, 24, "overlapping ring retains eighteen outer and six hole-facing edges")
	equal(internal, 6, "ring hides exactly the six genuinely shared cell edges")
	var hole := _fixed_hex(Vector2i.ZERO)
	for index: int in hole.size():
		var key := presenter._region_edge_key(exemplar, hole[index], hole[(index + 1) % hole.size()])
		equal(int(counts.get(key, 0)), 1, "each safe-center hole edge remains visible despite duplicate coverage outside it")
	check(not ring.has(Vector2i.ZERO), "boundary calculation cannot fill the safe center cell")
	equal(var_to_bytes(ring), before, "ring boundary calculation preserves every independent record")


func _test_overlapping_region_semantic_boundaries() -> void:
	var presenter := _configured_presenter()
	var left_cell := Vector2i.ZERO
	var right_cell := Vector2i(1, 0)
	var first := _boundary_region(presenter, left_cell, 44)
	var overlap := _boundary_region(presenter, left_cell, 45)
	for changed_field: String in ["owner", "phase", "danger"]:
		var overrides := {}
		overrides[changed_field] = 4 if changed_field == "owner" else "decaying" if changed_field == "phase" else false
		var changed := _boundary_region(presenter, right_cell, 46, overrides)
		var counts := presenter._region_edge_counts({left_cell: [first, overlap], right_cell: [changed, changed.duplicate(true)]})
		equal(counts.size(), 12, "%s difference retains both sides of the neighboring boundary" % changed_field)
		for key: String in counts:
			equal(int(counts[key]), 1, "%s boundary cannot merge while same-cell duplicates are removed" % changed_field)
		var same_cell := _boundary_region(presenter, left_cell, 46, overrides)
		equal(presenter._region_edge_counts({left_cell: [first, overlap, same_cell]}).size(), 12, "%s distinction survives deduplication inside one cell" % changed_field)


func _boundary_region(presenter: HexCourtPresenter, cell: Vector2i, footprint_id: int, overrides: Dictionary = {}) -> Dictionary:
	var source := {
		"footprint_id": footprint_id, "polygon": _fixed_hex(cell), "phase": "active",
		"danger": true, "intensity": 700, "owner": 3, "expiry_tick": 800,
		"recipe_wire_id": 304, "quantity": 5000, "source_ids": [footprint_id * 2],
		"direction": Vector2i.RIGHT,
	}
	for key: String in overrides: source[key] = overrides[key]
	return presenter._prepare_region(source, "dustfront")


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


func _paid_render_court(mask: int, self_pair: bool) -> HexChemistryWorld:
	var court := HexChemistryWorld.new()
	check(court.configure_geometry(Vector2i(128000, 96000), Presenter.HexGrid.disk(Vector2i.ZERO, 2)), "paid render witness has bounded real eligible topology")
	court.chemistry_enabled = true
	var wire := Mixtures.wire_for(mask, "bolt")
	var definition := CombatTuning.cast_definition_view(wire)
	check(not definition.is_empty(), "paid render witness uses a current compiled Bolt")
	for unused: int in range(2 if self_pair else 1):
		var source := court.next_cast_id
		check(court.reserve_cast(1, wire), "render witness reserves ordinary finite source")
		court.commit_payment(1)
		court.bind_release(1, source, court.origin, Vector2i(1000, 0), 1)
		court.deposit_terminal({"source_cast_id":source,"source_wire_id":wire,"projectile_id":source,
			"owner_id":1,"team_id":1,"element_wire_id":int(definition.element_wire_id),
			"position":court.origin,"direction":Vector2i(1000,0),"strength":1000,
			"reaction_strength":int(definition.reaction_strength)},0)
	court.sync_flights([], [])
	check(court.conservation_valid(), "render witness is admitted by actual finite paid-matter authority")
	return court


func _expanded_compact_frame(compact: Dictionary) -> Dictionary:
	# Independent published schema: absence means zero, not another source value.
	var views := {}
	for cell: Vector2i in compact.views:
		var value := {"fire_phase":"none", "steam_heat":1000}
		for material: String in Presenter.MATERIALS:
			value[material + "_quantity"] = 0
			value[material + "_present"] = false
		for key: Variant in compact.views[cell]: value[key] = compact.views[cell][key]
		views[cell] = value
	var regions := {}
	for material: String in Presenter.MATERIALS:
		regions[material] = compact.regions.get(material, {})
	return {"views":views,"regions":regions}


func _assert_compact_frame(presenter: HexCourtPresenter, court: HexChemistryWorld, tick: float) -> Dictionary:
	var before := var_to_bytes([court.cells, court.casts, court.products, court.origin, court.current_tick])
	var dense := presenter._prepare_frame_bundle(court, tick)
	var compact := presenter._prepare_draw_bundle(court, tick)
	equal(var_to_bytes(_expanded_compact_frame(compact)), var_to_bytes(dense), "sparse draw preserves every published quantity, phase, danger, owner, source, lifetime, direction and complete polygon")
	for cell: Vector2i in compact.views:
		check((compact.views[cell] as Dictionary).size() <= 4, "single paid material stores only its two live values plus two common phase values")
	check(compact.regions.size() <= 1, "single-material draw allocates no68 empty material maps")
	equal(var_to_bytes([court.cells,court.casts,court.products,court.origin,court.current_tick]), before, "render bundle construction leaves paid authority byte-for-byte unchanged")
	return compact


func _test_compact_paid_material_frames() -> void:
	var presenter := _configured_presenter()
	var seen_recipes := {}
	var seen_raw := {}
	var residents: Array[HexChemistryWorld] = []
	for mask: int in range(1, 64):
		var singleton: bool = (mask & (mask - 1)) == 0
		var court := _paid_render_court(mask, singleton)
		residents.append(court)
		equal(court.products.size(), 1, "paid source forms one exact current recipe")
		if court.products.size() != 1: continue
		var product_id: int = court.products.keys()[0]
		var product: Dictionary = court.products[product_id]
		equal(int(product.recipe_wire_id), Policy.wire_for_mask(mask), "all63 paid render witnesses preserve the selected mixture recipe")
		seen_recipes[int(product.recipe_wire_id)] = true
		check(presenter._prepare_court(court, false), "paid occupied geometry prepares")
		var active := int(product.active_tick)
		var decay := int(product.decay_tick)
		var expiry := int(product.expiry_tick)
		for tick: float in [float(active)-0.25,float(active),float(decay)-0.25,float(decay),float(expiry)-0.25,float(expiry)]:
			_assert_compact_frame(presenter, court, tick)
		var baseline := _assert_compact_frame(presenter, court, float(active))
		var saved := product.duplicate(true)
		product.damage_budget_remaining = 0
		var spent := _assert_compact_frame(presenter, court, float(active))
		for material: String in spent.regions:
			for cell: Vector2i in spent.regions[material]:
				for region: Dictionary in spent.regions[material][cell]: check(not bool(region.danger), "spent real damage budget immediately becomes harmless in the draw view")
		check(var_to_bytes(spent) != var_to_bytes(baseline), "danger change is visible without geometry revision")
		product.owner = 9
		product.source_ids = [901,902]
		product.flow_aim = Vector2i(0,1000)
		product.intensity = 0
		var changed := _assert_compact_frame(presenter, court, float(active))
		check(var_to_bytes(changed) != var_to_bytes(spent), "owner/provenance/direction/intensity stay fresh independently of geometry cache")
		court.products[product_id] = saved
		equal(var_to_bytes(_assert_compact_frame(presenter,court,float(active))), var_to_bytes(baseline), "direct authority restoration recovers exact draw bytes")
		var independent := presenter._prepare_draw_bundle(court, float(active))
		var independent_bytes := var_to_bytes(independent)
		for material: String in baseline.regions:
			for cell: Vector2i in baseline.regions[material]:
				baseline.regions[material][cell][0].source_ids.append(99999)
				baseline.regions[material][cell][0].polygon[0] += Vector2(100,100)
		equal(var_to_bytes(independent), independent_bytes, "one caller's nested output cannot poison a separate draw")
		equal(var_to_bytes(presenter._prepare_draw_bundle(court,float(active))), independent_bytes, "mutating returned provenance/polygon cannot poison cache or authority")
		if singleton:
			var raw := _paid_render_court(mask, false)
			check(raw.products.is_empty() and raw.casts.size() == 1, "singleton positive control is real raw matter before self-reaction")
			check(presenter._prepare_court(raw,false), "raw occupied material geometry prepares")
			for tick: float in [0.0,23.75,24.0,120.0]:
				var frame := _assert_compact_frame(presenter,raw,tick)
				for material: String in frame.regions: seen_raw[material] = true
	equal(seen_recipes.size(),63,"sparse-path equivalence covers all63 real current recipes")
	equal(seen_raw.size(),6,"sparse-path equivalence also covers all6 actual raw ingredient materials")
	check(int(presenter.geometry_cache_stats().courts)<=64 and int(presenter.geometry_cache_stats().cells)<=8192,"all material witnesses respect the independent geometry budgets")
