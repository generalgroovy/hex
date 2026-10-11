extends SceneTree

const Before = preload("res://tests/support/hex_polygon_before_cache.gd")
const ITERATIONS := 20000
const PAIRS := 5
const SOURCES := ["res://src/sim/hex/hex_chemistry_world.gd", "res://src/sim/hex/hex_grid.gd",
	"res://tests/support/hex_polygon_before_cache.gd", "res://tests/performance/profile_hex_polygon_cache.gd"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var hashes := {}
	for path: String in SOURCES: hashes[path] = FileAccess.get_sha256(path)
	var before := Before.new()
	var current := HexChemistryWorld.new()
	before.origin = Vector2i(1536000, 880000)
	current.origin = before.origin
	var cells := HexGrid.disk(Vector2i.ZERO, 3)
	for cell: Vector2i in cells:
		if before.whole_cell_polygon(cell) != current.whole_cell_polygon(cell):
			push_error("Geometry differential failed"); quit(1); return
	var rows: Array[Dictionary] = []
	var expected_checksum := 0.0
	for pair: int in PAIRS:
		var row := {}
		for kind: String in (["before", "current"] if pair % 2 == 0 else ["current", "before"]):
			var object: RefCounted = before if kind == "before" else current
			var checksum := 0.0
			var started := Time.get_ticks_usec()
			for index: int in ITERATIONS:
				var polygon: PackedVector2Array = object.whole_cell_polygon(cells[index % cells.size()])
				checksum += polygon[0].x
			var elapsed := Time.get_ticks_usec() - started
			row[kind + "_total_us"] = elapsed
			row[kind + "_us_per_call"] = float(elapsed) / ITERATIONS
			if expected_checksum == 0.0: expected_checksum = checksum
			if checksum != expected_checksum:
				push_error("Geometry checksum changed"); quit(1); return
		rows.append(row)
	for path: String in hashes:
		if hashes[path] != FileAccess.get_sha256(path): push_error("Source moved during geometry profile"); quit(1); return
	print(JSON.stringify({"profile": "whole-cell-polygon-cache", "iterations_per_sample": ITERATIONS, "pairs": rows,
		"engine": Engine.get_version_info().get("string", ""), "source_sha256": hashes,
		"cache": current.render_polygon_cache_stats(), "checksum": expected_checksum,
		"scope": "Warm pure geometry reads at37 repeated coordinates, alternating before/current order; includes loop, dispatch, detached writable results and checksum. No rendered-frame or simulation speedup claim."}))
	quit(0)
