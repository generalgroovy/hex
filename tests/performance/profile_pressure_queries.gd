extends SceneTree

const OldFootprint = preload("res://tests/support/hex_pressure_footprint_oracle.gd")
const OldCollision = preload("res://tests/support/hex_pressure_collision_oracle.gd")
var failures := 0
var checks := 0
var results: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool) -> void:
	checks += 1
	if not value: failures += 1

func _pair(name: String, before: Callable, after: Callable) -> void:
	_check(before.call() == after.call())
	for unused: int in 3:
		before.call()
		after.call()
	var times := [[], []]
	# 32 samples per arm, alternating ABBA / BAAB; no FPS inference.
	for block: int in 16:
		for arm: int in ([0,1,1,0] if block % 2 == 0 else [1,0,0,1]):
			var start := Time.get_ticks_usec()
			var value: Variant = before.call() if arm == 0 else after.call()
			times[arm].append(Time.get_ticks_usec() - start)
			_check(value == before.call()) # Equality work outside measured interval.
	for samples: Array in times: samples.sort()
	results.append({"name":name, "samples_per_arm":32, "before_p50_us":times[0][16], "after_p50_us":times[1][16], "before_p95_us":times[0][30], "after_p95_us":times[1][30]})

func _run() -> void:
	var output := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if not output.begins_with("res://.godot/headroom-") or not output.ends_with(".json") or ".." in output or FileAccess.file_exists(output):
		quit(2)
		return
	for sparse: bool in [false, true]:
		var cells := {}
		for cell: Vector2i in HexGrid.disk(Vector2i.ZERO, 8):
			if not sparse or posmod(cell.x * 3 + cell.y, 4) == 0: cells[cell] = 1
		var shape := HexFootprint.sector(Vector2i(-210000, 23000), Vector2i(1000, 0), 460000, 500000)
		_pair("Spray/selected " + ("sparse" if sparse else "dense"),
			func(): return OldFootprint.contact_shape_selected(shape, cells, Vector2i.ZERO, shape.start),
			func(): return HexFootprint.contact_shape_selected(shape, cells, Vector2i.ZERO, shape.start))
	var topology := HexGrid.disk(Vector2i.ZERO, 12)
	var field := {}
	for cell: Vector2i in topology: field[cell] = 1
	_pair("24 short flight/field intervals",
		func(): return _intervals(field, false), func(): return _intervals(field, true))
	var occupied: Array[Vector2i] = []
	for cell: Vector2i in topology:
		if posmod(cell.x + cell.y, 3) == 0: occupied.append(cell)
	var old := OldCollision.new(CollisionWorld.new())
	var current := HexCollisionWorld.new(CollisionWorld.new())
	_check(old.configure_hexes(Vector2i.ZERO, topology, occupied))
	_check(current.configure_hexes(Vector2i.ZERO, topology, occupied))
	_pair("24 wall-attachment queries / 157 pillars",
		func(): return _walls(old), func(): return _walls(current))
	_pair("24 circle sweeps / 157 pillars",
		func(): return _sweeps(old), func(): return _sweeps(current))
	var table := CombatDefinitionTable.default_table()
	_pair("320 definition reads", func(): return _definitions(table, false), func(): return _definitions(table, true))
	var hashes := {}
	for path: String in [get_script().resource_path, "res://tests/support/hex_pressure_footprint_oracle.gd", "res://tests/support/hex_pressure_collision_oracle.gd",
		"res://src/sim/hex/hex_footprint.gd", "res://src/sim/hex/hex_collision_world.gd", "res://src/sim/combat/combat_definition_table.gd"]:
		hashes[path] = FileAccess.get_sha256(path)
	var receipt := {"status":"passed" if failures == 0 else "failed", "checks":checks, "failures":failures, "results":results, "hashes":hashes,
		"scope":"Synthetic CPU queries only; frozen checkpoint control flow vs current, ABBA/BAAB. Not paid gameplay load, rendered FPS, network or capacity acceptance."}
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt, "\t") + "\n")
	file.close()
	print(JSON.stringify(receipt))
	quit(1 if failures else 0)

func _walls(world: RefCounted) -> Array:
	var output := []
	for i: int in 24:
		output.append(world.nearby_hex_face(Vector2i(i * 4000 - 48000, -178000), 18000, 8000))
	return output

func _sweeps(world: RefCounted) -> Array:
	var output := []
	for i: int in 24:
		var start := Vector2i(i * 4000 - 48000, -178000)
		output.append(world.hex_wall_contact(start, start + Vector2i(2700, 1300), 12000))
	return output

func _definitions(table: CombatDefinitionTable, borrowed: bool) -> Array:
	var output := []
	for unused: int in 10:
		for wire: int in table.runtime_wire_ids():
			var definition := table.definition_view(wire) if borrowed else table.definition(wire)
			output.append([definition.family, definition.flux_cost, definition.reaction_strength])
	return output


func _intervals(field: Dictionary, current: bool) -> Array:
	var output := []
	for i: int in 24:
		var start := Vector2i(i * 1000 - 12000, 2200)
		var finish := start + Vector2i(1700, 1500)
		output.append(HexFootprint.selected_segment_interval(field, Vector2i.ZERO, start, finish) if current else OldFootprint.selected_segment_interval(field, Vector2i.ZERO, start, finish))
	return output
