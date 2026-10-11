extends FluxTestSuite

const OldCollision = preload("res://tests/support/hex_pressure_collision_oracle.gd")
const OldFootprint = preload("res://tests/support/hex_pressure_footprint_oracle.gd")

func run() -> int:
	_test_local_collision()
	_test_nearest_witness()
	_test_short_flight_intervals()
	return finish("hex-pressure-headroom")


func _test_short_flight_intervals() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 930921
	var selected := {}
	for cell: Vector2i in HexGrid.disk(Vector2i.ZERO, 8):
		selected[cell] = 0 if posmod(cell.x + cell.y, 4) == 0 else 1
	for origin: Vector2i in [Vector2i.ZERO, Vector2i(-6791000, 5899000)]:
		for i: int in 600:
			var start := origin + Vector2i(rng.randi_range(-240000,240000), rng.randi_range(-240000,240000))
			var finish := start + Vector2i(rng.randi_range(-4000,4000), rng.randi_range(-4000,4000))
			if i % 5 == 0:
				start = origin + HexGrid.LOCAL_VERTICES[i % 6]
				finish = start + Vector2i(i % 3 - 1, (i + 1) % 3 - 1)
			if i % 7 == 0: finish = start
			equal(HexFootprint.selected_segment_interval(selected, origin, start, finish), OldFootprint.selected_segment_interval(selected, origin, start, finish), "strict interior shortcut preserves complete interval and witness")
			equal(HexFootprint.selected_segment_interval(selected, origin, finish, start), OldFootprint.selected_segment_interval(selected, origin, finish, start), "reverse short path preserves exact entry")


func _test_local_collision() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 930174
	var topology := HexGrid.disk(Vector2i.ZERO, 8)
	var occupied: Array[Vector2i] = []
	for cell: Vector2i in topology:
		if posmod(cell.x + cell.y * 3, 5) == 0: occupied.append(cell)
	for origin: Vector2i in [Vector2i.ZERO, Vector2i(-770000, 350011)]:
		var current := HexCollisionWorld.new(CollisionWorld.new())
		var previous := OldCollision.new(CollisionWorld.new())
		check(current.configure_hexes(origin, topology, occupied), "current collision fixture configures")
		check(previous.configure_hexes(origin, topology, occupied), "oracle collision fixture configures")
		for index: int in 160:
			var start := origin + Vector2i(rng.randi_range(-330000, 330000), rng.randi_range(-330000, 330000))
			var finish := start + Vector2i(rng.randi_range(-5000, 5000), rng.randi_range(-5000, 5000))
			if index % 4 == 0: finish = origin + Vector2i(rng.randi_range(-350000, 350000), rng.randi_range(-350000, 350000))
			if index % 7 == 0:
				start = origin + HexGrid.vertices(occupied[index % occupied.size()])[index % 6]
				finish = start + Vector2i(index % 3 - 1, (index + 1) % 3 - 1)
			var radius: int = [0, 15000, 18000, 21000, 60000][index % 5]
			current.begin_actor(start, radius)
			previous.begin_actor(start, radius)
			equal(current._actor_ignored, previous._actor_ignored, "same embedded-component escape")
			equal(current.can_occupy(start, radius), previous.can_occupy(start, radius), "same occupancy")
			equal(current.hex_wall_contact(start, finish, radius), previous.hex_wall_contact(start, finish, radius), "same circle TOI, normal, face and tie")
			equal(current._sweep(start, finish, radius, true), previous._sweep(start, finish, radius, true), "same box TOI, normal, face and tie")
			equal(current.hex_pillar_segment_clear(start, finish), previous.hex_pillar_segment_clear(start, finish), "same pillar visibility")
			equal(current.nearby_hex_face(start, radius, 8000), previous.nearby_hex_face(start, radius, 8000), "same wall attachment including diagonals")
			var moved := current.move_box(start, finish - start, radius)
			var old_moved := previous.move_box(start, finish - start, radius)
			equal([moved.position, moved.wall_normal, moved.wall_id, moved.blocking_normals], [old_moved.position, old_moved.wall_normal, old_moved.wall_id, old_moved.blocking_normals], "same chained movement result")


func _test_nearest_witness() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 930827
	for index: int in 260:
		var origin := Vector2i(rng.randi_range(-7000000, 7000000), rng.randi_range(-7000000, 7000000))
		var selected := {}
		for cell: Vector2i in HexGrid.disk(Vector2i.ZERO, 1 + index % 8):
			if index % 3 == 0 or rng.randi_range(0, 3) == 0: selected[cell] = 0 if index % 11 == 0 else 1
		var start := origin + Vector2i(rng.randi_range(-220000, 220000), rng.randi_range(-220000, 220000))
		var shape := HexFootprint.disk(start, rng.randi_range(0, 256000))
		if index % 3 != 0:
			var aim: Vector2i = [Vector2i(1000,0),Vector2i(707,707),Vector2i(-913,407),Vector2i(0,-1000)][index % 4]
			shape = HexFootprint.sector(start, aim, rng.randi_range(1, 512000), [1, 500000, 900000][index % 3])
		if index % 13 == 0:
			shape = HexFootprint.intersection(shape, HexFootprint.disk(origin, 68000))
		var preferred := start if index % 2 == 0 else origin + Vector2i(17111, -42319)
		equal(HexFootprint.contact_shape_selected(shape, selected, origin, preferred), OldFootprint.contact_shape_selected(shape, selected, origin, preferred), "nearest search preserves complete witness, including quantization and fallback")
		var reversed := {}
		var keys := selected.keys()
		keys.reverse()
		for key: Vector2i in keys: reversed[key] = selected[key]
		equal(HexFootprint.contact_shape_selected(shape, reversed, origin, preferred), OldFootprint.contact_shape_selected(shape, selected, origin, preferred), "insertion order cannot change the exact witness")
