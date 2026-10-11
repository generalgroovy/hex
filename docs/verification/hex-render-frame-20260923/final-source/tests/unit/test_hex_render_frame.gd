extends FluxTestSuite


const Presenter = preload("res://src/presentation/hex_court_presenter.gd")
const Grid = preload("res://src/sim/hex/hex_grid.gd")
const FrozenOracle = preload("res://tests/support/hex_render_frame_candidate.gd")
const EXPECTED_EQUIVALENCE_CASES := 16

var equivalence_cases_completed := 0


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
