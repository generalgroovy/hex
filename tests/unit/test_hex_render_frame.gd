extends FluxTestSuite


const Presenter = preload("res://src/presentation/hex_court_presenter.gd")
const Grid = preload("res://src/sim/hex/hex_grid.gd")
const FrozenOracle = preload("res://tests/support/hex_render_frame_candidate.gd")
const Mixtures = preload("res://src/content/mixture_catalog.gd")
const EXPECTED_EQUIVALENCE_CASES := 16

var equivalence_cases_completed := 0


class EmptyDrawProbe:
	extends HexCourtPresenter
	var bundle_calls := 0
	func _prepare_frame_bundle(court: RefCounted, tick: float) -> Dictionary:
		bundle_calls += 1
		return super._prepare_frame_bundle(court, tick)


class FloorDrawProbe:
	extends HexCourtPresenter
	var bundle_cells: Array[int] = []
	var floor_cells: Array[int] = []
	var apron_calls := 0
	var rim_calls := 0
	var active_scans := 0
	func _prepare_frame_bundle(court: RefCounted, tick: float) -> Dictionary:
		bundle_cells.append(_cells.size())
		return super._prepare_frame_bundle(court, tick)
	func _draw_apron(_canvas: CanvasItem, _reduced: bool) -> void:
		apron_calls += 1
	func _draw_stone(_canvas: CanvasItem, _court: RefCounted, _reduced: bool) -> void:
		floor_cells.append(_cells.size())
	func _draw_outer_rim(_canvas: CanvasItem) -> void:
		rim_calls += 1
	func _has_active_material(views: Dictionary) -> bool:
		active_scans += 1
		return super._has_active_material(views)


class DerivedCourt:
	extends HexChemistryWorld

	func view(cell: Vector2i, tick: float) -> Dictionary:
		var result: Dictionary = super.view(cell, tick)
		result["subclass_marker"] = "preserved-by-generic-path"
		return result


class GenericCourt:
	extends RefCounted
	var cells := {Vector2i.ZERO: {}}
	var origin := Vector2i(640_000, 480_000)
	var render_revision := 1

	func view(_cell: Vector2i, _tick: float) -> Dictionary:
		return {"fire_phase": "none", "steam_heat": 1000, "water_quantity": 3, "water_present": true}

	func render_regions(cell: Vector2i, material: String, _tick: float) -> Array:
		if cell != Vector2i.ZERO or material != "water":
			return []
		var polygon := PackedVector2Array()
		for point: Vector2i in Grid.vertices(cell):
			polygon.append(Vector2(point + origin))
		return [{
			"footprint_id": 41, "polygon": polygon, "phase": "active", "danger": false,
			"intensity": 1000, "quantity": 3, "owner": 7, "source_ids": [91],
			"expiry_tick": 200, "recipe_wire_id": 0, "direction": Vector2i(0, -1000), "material": material,
		}]


func run() -> int:
	_test_exact_base_equivalence()
	_test_mutation_visibility_and_ownership()
	_test_fallbacks_and_fail_closed_preparation()
	_test_empty_occupied_membership()
	_test_empty_campus_draw()
	_test_range_floor_and_occupied_materials()
	_test_ground_parts_without_aggregate_coverage()
	equal(equivalence_cases_completed, EXPECTED_EQUIVALENCE_CASES, "all integrated render-frame equivalence cases complete")
	return finish("hex-render-frame")


func _test_exact_base_equivalence() -> void:
	equal(Presenter.MATERIALS, HexChemistryWorld.material_layers(), "presenter and exact court retain the measured 8+36 material order")
	var court: HexChemistryWorld = _rich_court()
	var presenter: HexCourtPresenter = _prepared_presenter(court, true)
	for tick: float in [19.5, 20.0, 34.0, 40.0, 70.0, 100.0]:
		_assert_exact_base(court, presenter, tick, "integral/fractional phase boundary %.1f" % tick)


func _test_mutation_visibility_and_ownership() -> void:
	var court: HexChemistryWorld = _rich_court()
	var presenter: HexCourtPresenter = _prepared_presenter(court, true)
	var tick := 50.25
	var baseline: Dictionary = presenter._prepare_frame_bundle(court, tick)
	_assert_exact_base(court, presenter, tick, "direct mutation baseline")
	var original_intensity: int = court.products[21].intensity
	court.products[21].intensity = original_intensity + 777
	var mutated: Dictionary = presenter._prepare_frame_bundle(court, tick)
	check(var_to_bytes(mutated) != var_to_bytes(baseline), "direct authority mutation is visible to the next production bundle")
	_assert_exact_base(court, presenter, tick, "direct mutation visible")
	court.products[21].intensity = original_intensity
	_assert_exact_base(court, presenter, tick, "direct mutation restored")
	equal(var_to_bytes(presenter._prepare_frame_bundle(court, tick)), var_to_bytes(baseline), "restoration recovers exact bundle bytes")

	var authority_bytes: PackedByteArray = _authority_bytes(court)
	var first: Dictionary = presenter._prepare_frame_bundle(court, tick)
	var second: Dictionary = presenter._prepare_frame_bundle(court, tick)
	var second_bytes: PackedByteArray = var_to_bytes(second)
	var views: Dictionary = first.views
	var cell_view: Dictionary = views[Vector2i.ZERO]
	cell_view.fire_quantity = int(cell_view.fire_quantity) + 99
	views[Vector2i.ZERO] = cell_view
	first.views = views
	var regions: Dictionary = first.regions
	var fire_by_cell: Dictionary = regions.fire
	var fire_regions: Array = fire_by_cell[Vector2i.ZERO]
	var region: Dictionary = fire_regions[0]
	region.quantity = int(region.quantity) + 88
	var source_ids: Array = region.source_ids
	source_ids.append(999)
	region.source_ids = source_ids
	fire_regions[0] = region
	fire_by_cell[Vector2i.ZERO] = fire_regions
	regions.fire = fire_by_cell
	first.regions = regions
	check(var_to_bytes(first) != second_bytes, "selected production output mutation changes the selected bundle")
	equal(var_to_bytes(second), second_bytes, "separate production bundle owns independent nested output")
	equal(_authority_bytes(court), authority_bytes, "production output cannot alias mutable authority")
	equivalence_cases_completed += 1


func _test_fallbacks_and_fail_closed_preparation() -> void:
	var tick := 50.25
	var iterable_layer: HexChemistryWorld = _rich_court()
	var iterable_layer_presenter: HexCourtPresenter = _prepared_presenter(iterable_layer, true)
	iterable_layer.cells[Vector2i.ZERO].fire = [11, 12]
	_assert_exact_base(iterable_layer, iterable_layer_presenter, tick, "renderable Array material lane retains current fallback")

	var iterable_cell: HexChemistryWorld = _rich_court()
	var iterable_cell_presenter: HexCourtPresenter = _prepared_presenter(iterable_cell, true)
	iterable_cell.cells[Vector2i.RIGHT] = []
	_assert_exact_base(iterable_cell, iterable_cell_presenter, tick, "renderable Array cell record retains current fallback")

	var rejected: HexChemistryWorld = _rich_court()
	var rejected_presenter: HexCourtPresenter = _prepared_presenter(rejected, true)
	rejected.products[21].flow_aim = "invalid"
	var rejected_bundle: Dictionary = _assert_exact_base(rejected, rejected_presenter, tick, "invalid region metadata retains complete views and fails regions closed")
	check(not rejected_bundle.views.is_empty() and rejected_bundle.regions.is_empty(), "prepare-region rejection keeps views and returns empty regions")

	var derived := DerivedCourt.new()
	var one_cell: Array[Vector2i] = [Vector2i.ZERO]
	check(derived.configure_geometry(Vector2i.ZERO, one_cell), "derived fallback fixture configures")
	var derived_presenter: HexCourtPresenter = _prepared_presenter(derived, true)
	_assert_oracle(derived_presenter._prepare_frame_bundle(derived, 0.0), FrozenOracle.current_bundle(derived, derived_presenter, 0.0), _authority_bytes(derived), derived, "subclass retains original path")

	var generic := GenericCourt.new()
	var generic_presenter: HexCourtPresenter = _configured_presenter()
	check(generic_presenter._prepare_court(generic, true), "generic fallback presenter prepares")
	var generic_before: PackedByteArray = var_to_bytes(generic.cells)
	var generic_actual: Dictionary = generic_presenter._prepare_frame_bundle(generic, 0.0)
	var generic_expected: Dictionary = _old_generic_bundle(generic, generic_presenter, 0.0)
	check(generic_actual == generic_expected and var_to_bytes(generic_actual) == var_to_bytes(generic_expected), "generic duck-typed court retains exact old bundle")
	equal(var_to_bytes(generic.cells), generic_before, "generic fallback leaves source unchanged")
	equivalence_cases_completed += 1


func _test_empty_occupied_membership() -> void:
	var court := HexChemistryWorld.new()
	var one_cell: Array[Vector2i] = [Vector2i.ZERO]
	check(court.configure_geometry(Vector2i.ZERO, one_cell), "empty occupied-only fixture configures")
	var presenter: HexCourtPresenter = _prepared_presenter(court, false)
	equal(presenter._cells.size(), 0, "empty occupied-only presenter has no cells")
	_assert_exact_base(court, presenter, 0.0, "empty occupied-only production bundle")


func _test_empty_campus_draw() -> void:
	var court := HexChemistryWorld.new()
	var one_cell: Array[Vector2i] = [Vector2i.ZERO]
	check(court.configure_geometry(Vector2i.ZERO, one_cell), "idle draw fixture uses valid topology")
	var language := VisualLanguage.new()
	check(language.load_from_file(), "idle draw uses validated production visual language")
	var presenter := EmptyDrawProbe.new()
	check(presenter.configure(language), "idle presenter configures")
	var canvas := Node2D.new()
	var before := _authority_bytes(court)
	presenter._cover_surface_regions["fortify"] = {Vector2i.ZERO: []}
	check(presenter.draw_ground(canvas, court, 0.0, false, false), "empty normal campus succeeds without draw commands")
	check(presenter.draw_ground(canvas, court, 100.5, true, false), "empty Reduced Effects campus also succeeds")
	equal(presenter.bundle_calls, 0, "no empty material bundles are allocated or dispatched")
	check(presenter._cover_surface_regions.is_empty(), "idle shortcut clears prior cover repaint state")
	equal(canvas.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "idle path preserves the canvas sampling contract")
	equal(_authority_bytes(court), before, "idle drawing cannot mutate authority")
	check(not presenter.draw_ground(null, court, 0.0, false, false), "idle shortcut cannot bypass invalid canvas rejection")
	check(not presenter.draw_ground(canvas, court, NAN, false, false), "idle shortcut cannot bypass invalid time rejection")
	# Membership is still freshly consulted, including direct changes without a
	# render revision bump; no cached empty flag can hide the next paid field.
	var rich := _rich_court()
	check(presenter._prepare_court(rich, false), "fresh occupied membership observed after empty draw")
	check(not presenter._cells.is_empty(), "newly occupied authority leaves the idle shortcut")
	check(presenter._prepare_court(court, true) and not presenter._cells.is_empty(), "standalone base keeps eligible empty ground cells")
	canvas.free()


func _assert_exact_base(court: HexChemistryWorld, presenter: HexCourtPresenter, tick: float, label: String) -> Dictionary:
	var before: PackedByteArray = _authority_bytes(court)
	var actual: Dictionary = presenter._prepare_frame_bundle(court, tick)
	var expected: Dictionary = FrozenOracle.current_bundle(court, presenter, tick)
	_assert_oracle(actual, expected, before, court, label)
	return actual


func _assert_oracle(actual: Dictionary, expected: Dictionary, before: PackedByteArray, court: HexChemistryWorld, label: String) -> void:
	check(actual == expected, label + " production structure equals frozen old oracle")
	equal(var_to_bytes(actual), var_to_bytes(expected), label + " production preserves exact Variant bytes and order")
	equal(_authority_bytes(court), before, label + " production and oracle leave authority unchanged")
	equivalence_cases_completed += 1


func _old_generic_bundle(court: GenericCourt, presenter: HexCourtPresenter, tick: float) -> Dictionary:
	var views: Dictionary = {}
	for cell: Vector2i in presenter._cells:
		var value: Variant = court.view(cell, tick)
		views[cell] = value if value is Dictionary else {}
	return {"views": views, "regions": presenter._collect_render_regions(court, views, tick)}


func _configured_presenter() -> HexCourtPresenter:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "render-frame test loads production visual language")
	var presenter := Presenter.new()
	check(presenter.configure(language), "render-frame presenter configures")
	return presenter


func _prepared_presenter(court: HexChemistryWorld, include_empty: bool) -> HexCourtPresenter:
	var presenter: HexCourtPresenter = _configured_presenter()
	check(presenter._prepare_court(court, include_empty), "render-frame presenter prepares court membership")
	return presenter


func _rich_court() -> HexChemistryWorld:
	var court := HexChemistryWorld.new()
	var cells: Array[Vector2i] = [Vector2i.ZERO, Vector2i.RIGHT]
	check(court.configure_geometry(Vector2i(640_000, 480_000), cells), "rich integrated render-frame fixture configures")
	var fire_parts: Dictionary = {}
	fire_parts[301] = {"created": 10, "expiry_tick": 100, "coverage": {Vector2i.ZERO: 1}, "cells": {Vector2i.ZERO: 12}}
	fire_parts[299] = {"created": 0, "expiry_tick": 80, "coverage": {Vector2i.ZERO: 1}, "cells": {Vector2i.ZERO: 0}}
	court.casts[11] = {"owner": 2, "source": 101, "aim": Vector2i(900, -100), "ground_parts": fire_parts}
	court.casts[12] = {"owner": 3, "source": 102, "aim": Vector2i(-400, 600), "ground_parts": {
		305: {"created": 5, "expiry_tick": 120, "coverage": {Vector2i.ZERO: 1}, "cells": {Vector2i.ZERO: 7}},
	}}
	court.cells[Vector2i.ZERO].fire = {11: 12, 12: 7}
	court.products[21] = {"active_tick": 20, "decay_tick": 70, "expiry_tick": 100, "intensity": 1_400, "cells": {Vector2i.ZERO: 0}, "owner": 4, "source_ids": [101, 102], "recipe_wire_id": 310, "flow_aim": Vector2i(1000, 0)}
	court.products[22] = {"active_tick": 0, "decay_tick": 90, "expiry_tick": 130, "intensity": 900, "cells": {Vector2i.ZERO: 5}, "owner": 5, "source_ids": [103], "recipe_wire_id": 310, "flow_aim": Vector2i(0, -1000)}
	court.cells[Vector2i.ZERO].steam = {21: 0, 22: 5}
	court.cells[Vector2i.RIGHT].erase("dark")
	court.cells[Vector2i.RIGHT]["extra_layer"] = {999: 1}
	return court


func _authority_bytes(court: HexChemistryWorld) -> PackedByteArray:
	return var_to_bytes([court.cells, court.casts, court.products, court.origin, court.current_tick])


func _test_range_floor_and_occupied_materials() -> void:
	var court := HexCourt.new()
	court.chemistry_enabled = true
	var language := VisualLanguage.new()
	check(language.load_from_file(), "Range optimization uses real material palettes")
	var presenter := FloorDrawProbe.new()
	check(presenter.configure(language), "Range probe configures actual presenter")
	var canvas := Node2D.new()
	var full_count := court.cell_count()
	equal(full_count, 469, "real Range compatibility topology is the unchanged twelve-ring court")
	var before := _authority_bytes(court)
	for reduced: bool in [false, true]:
		check(presenter.draw_ground(canvas, court, 0.0, reduced, true), "empty standalone Range still draws its complete floor")
	equal(presenter.bundle_cells, [0,0], "empty Range never prepares a material view for its469 floor cells")
	equal(presenter.floor_cells, [469,469], "material sparsity does not remove even one floor cell")
	equal([presenter.apron_calls,presenter.rim_calls,presenter.active_scans], [2,2,0], "empty floor retains apron/rim and skips the469x69 material scan")
	equal(presenter._cells.size(), full_count, "temporary material membership is restored before floor drawing")
	equal(_authority_bytes(court), before, "empty Range optimization leaves source storage unchanged")
	var public_empty := presenter._prepare_frame_bundle(court, 0.0)
	equal(public_empty.views.size(), full_count, "public Range frame remains dense across the entire floor")
	equal(var_to_bytes(public_empty), var_to_bytes(FrozenOracle.current_bundle(court,presenter,0.0)), "public compatibility frame keeps exact old bytes and material order")

	# Real finite source admission, not a display-only row: active and expired
	# raw matter and a directly cast mixture both use ordinary Hex terminal rules.
	_range_deposit(court, 2)
	check(not court.occupied_cells().is_empty(), "real Fire source occupies Range floor")
	for tick: float in [0.0,23.75,24.0,119.75,120.0,500.0]:
		_assert_range_compact(court,presenter,tick)
	var mixed := HexCourt.new()
	mixed.chemistry_enabled = true
	_range_deposit(mixed, 63)
	equal(mixed.products.size(), 1, "all-six paid terminal forms an actual funded field")
	if mixed.products.size() == 1:
		var id: int = mixed.products.keys()[0]
		var product: Dictionary = mixed.products[id]
		check(presenter._prepare_court(mixed,true), "mixed Range retains complete base membership")
		for tick: float in [float(product.active_tick)-0.25,float(product.active_tick),float(product.decay_tick),float(product.expiry_tick)]:
			_assert_range_compact(mixed,presenter,tick)
		var original := product.duplicate(true)
		var live := presenter._prepare_draw_bundle(mixed,float(product.active_tick))
		product.damage_budget_remaining = 0
		product.owner = 9
		product.source_ids = [901,902]
		product.flow_aim = Vector2i(0,1000)
		var changed := _assert_range_compact(mixed,presenter,float(product.active_tick))
		check(var_to_bytes(changed) != var_to_bytes(live), "same geometry cannot hide direct danger, owner, source or direction changes")
		mixed.products[id] = original.duplicate(true)
		equal(var_to_bytes(_assert_range_compact(mixed,presenter,float(original.active_tick))), var_to_bytes(live), "direct record restoration recovers identical compact bytes")
		# Both removal and restoration change coverage without render_revision.
		mixed.products[id].cells = {}
		if mixed.products[id].has("coverage"): mixed.products[id].coverage = {}
		check(presenter._prepare_draw_bundle(mixed,float(original.active_tick)).views.is_empty(), "direct coverage retirement leaves no cached material traversal")
		mixed.products[id] = original.duplicate(true)
		_assert_range_compact(mixed,presenter,float(original.active_tick))
		presenter._visible_rect = Rect2(-10,-10,20,20)
		check(presenter._prepare_court(mixed,true), "viewport selection still prepares bounded floor membership")
		var visible_cells := presenter._cells.duplicate()
		check(presenter._prepare_draw_bundle(mixed,float(original.active_tick)).views.is_empty(), "offscreen material cannot bypass prepared visibility membership")
		equal(presenter._cells, visible_cells, "compact preparation preserves the exact culled floor selection")
		presenter._visible_rect = Rect2()
		check(presenter._prepare_court(mixed,true), "uncropped Range returns after culled draw")
		_assert_range_compact(mixed,presenter,float(original.active_tick))

	# Only the known no-override compatibility class gains the internal path.
	var derived := DerivedCourt.new()
	check(derived.configure_geometry(Vector2i.ZERO,[Vector2i.ZERO]), "custom derived contract configures")
	check(presenter._prepare_court(derived,true), "custom derived membership prepares")
	var custom := presenter._prepare_draw_bundle(derived,0.0)
	equal(custom.views[Vector2i.ZERO].subclass_marker, "preserved-by-generic-path", "arbitrary overrides remain visible even with empty paid coverage")
	var generic := GenericCourt.new()
	check(presenter._prepare_court(generic,true), "generic custom material prepares")
	equal(var_to_bytes(presenter._prepare_draw_bundle(generic,0.0)), var_to_bytes(_old_generic_bundle(generic,presenter,0.0)), "duck-typed no-coverage contract keeps complete old draw queries")
	canvas.free()


func _range_deposit(court: HexChemistryWorld, mask: int) -> void:
	var wire := Mixtures.wire_for(mask,"bolt")
	var definition := CombatTuning.cast_definition_view(wire)
	var source := court.next_cast_id
	check(court.reserve_cast(1,wire), "Range fixture reserves a real current Bolt")
	court.commit_payment(1)
	court.bind_release(1,source,court.origin,Vector2i(1000,0),1)
	court.deposit_terminal({"source_cast_id":source,"source_wire_id":wire,"projectile_id":source,
		"owner_id":1,"team_id":1,"element_wire_id":int(definition.element_wire_id),
		"position":court.origin,"direction":Vector2i(1000,0),"strength":1000,
		"reaction_strength":int(definition.reaction_strength)},0)
	court.sync_flights([],[])
	check(court.conservation_valid(), "Range rendering witness conserves exact finite paid matter")


func _assert_range_compact(court: HexChemistryWorld, presenter: HexCourtPresenter, tick: float) -> Dictionary:
	var before := _authority_bytes(court)
	var floor_cells := presenter._cells.duplicate()
	var dense := presenter._prepare_frame_bundle(court,tick)
	var compact := presenter._prepare_draw_bundle(court,tick)
	var occupied := court.occupied_cells()
	var expected_cells: Array[Vector2i] = []
	for cell: Vector2i in floor_cells:
		if occupied.has(cell): expected_cells.append(cell)
	equal(compact.views.keys(), expected_cells, "internal Range preparation selects only current occupied cells in original floor order")
	var expanded_views := {}
	for cell: Vector2i in floor_cells:
		var row := {"fire_phase":"none","steam_heat":1000}
		for material: String in Presenter.MATERIALS:
			row[material+"_quantity"] = 0
			row[material+"_present"] = false
		for key: Variant in compact.views.get(cell,{}): row[key] = compact.views[cell][key]
		expanded_views[cell] = row
	var expanded_regions := {}
	for material: String in Presenter.MATERIALS: expanded_regions[material] = compact.regions.get(material,{})
	equal(var_to_bytes({"views":expanded_views,"regions":expanded_regions}), var_to_bytes(dense), "compact internal Range material data reconstructs the exact full public frame")
	equal(presenter._cells,floor_cells,"material preparation never changes floor membership")
	equal(_authority_bytes(court),before,"Range material preparation is read-only")
	return compact


func _test_ground_parts_without_aggregate_coverage() -> void:
	# Preserved direct/legacy records have real cell layers and ground parts,
	# but no aggregate paid-source coverage. Only that missing/invalid aggregate
	# shape falls back: do not claim recovery of arbitrary inconsistent ledgers.
	for standalone: bool in [false,true]:
		var source := _rich_court()
		source.products.clear()
		source.cells[Vector2i.ZERO].erase("steam")
		var court: HexChemistryWorld = HexCourt.new() if standalone else source
		if standalone:
			court.casts = source.casts.duplicate(true)
			court.cells[Vector2i.ZERO].fire = source.cells[Vector2i.ZERO].fire.duplicate(true)
		var presenter := _prepared_presenter(court,true)
		var floor_cells := presenter._cells.duplicate()
		check(court.occupied_cells().is_empty(), "ground-part compatibility fixture deliberately lacks indexed aggregate coverage")
		for aggregate: Variant in [null,17,"missing"]:
			for cast_id: int in court.casts:
				if aggregate is String: court.casts[cast_id].erase("coverage")
				else: court.casts[cast_id].coverage = aggregate
			for tick: float in [0.0,40.0,119.0,130.0]:
				var before := _authority_bytes(court)
				var expected := FrozenOracle.current_bundle(court,presenter,tick)
				var compact := presenter._prepare_draw_bundle(court,tick)
				var views := {}
				for cell: Vector2i in floor_cells:
					var row := {"fire_phase":"none","steam_heat":1000}
					for material: String in Presenter.MATERIALS:
						row[material+"_quantity"] = 0
						row[material+"_present"] = false
					for key: Variant in compact.views.get(cell,{}): row[key] = compact.views[cell][key]
					views[cell] = row
				var regions := {}
				for material: String in Presenter.MATERIALS: regions[material] = compact.regions.get(material,{})
				equal(var_to_bytes({"views":views,"regions":regions}),var_to_bytes(expected),"missing/invalid aggregate keeps exact phase, source, quantity and lifetime from ground parts")
				equal(presenter._cells,floor_cells,"ground-part fallback preserves complete floor selection")
				equal(_authority_bytes(court),before,"ground-part fallback is read-only")
				if tick == 40.0:
					equal(compact.views[Vector2i.ZERO].fire_quantity,19,"ground-part fallback retains the independently authored12+0+7 material quantity")
					equal(compact.regions.fire[Vector2i.ZERO].size(),3,"zero-quantity covered part remains visually present alongside both positive parts")
		# Supplying the actual aggregate returns immediately to sparse traversal.
		for cast_id: int in court.casts: court.casts[cast_id].coverage = {Vector2i.ZERO:1}
		var restored := presenter._prepare_draw_bundle(court,40.0)
		equal(restored.views.keys(),[Vector2i.ZERO],"restored valid aggregate resumes occupied-only material traversal")
		equal(presenter._cells,floor_cells,"restored sparse traversal still retains the complete floor")
