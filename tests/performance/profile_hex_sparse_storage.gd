extends SceneTree
## Isolated ABBA comparison; not a frame-rate/capacity acceptance test.

func _initialize() -> void:
	var campus := SanctumCampusLayout.new()
	assert(campus.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"))
	var definition := HexWorldDefinition.from_campus(campus)
	var court := HexChemistryWorld.new()
	assert(court.configure_geometry(definition.origin, definition.eligible_cells))
	var selected: Array[Vector2i] = []
	for cell: Vector2i in court.cells:
		selected.append(cell)
		if selected.size() == 7: break
	var record := {"id":1,"element":2,"cells":{}}
	for cell: Vector2i in selected: record.cells[cell] = 1
	# Use the actual layer selector contract rather than duplicating it.
	record["element_wire_id"] = 2
	var local_times: Array[int] = []
	var exhaustive_times: Array[int] = []
	for sample: int in 80:
		for local: bool in [false,true,true,false]:
			var before := Time.get_ticks_usec()
			court._rebuild_cast_layers(record, selected if local else null)
			var elapsed := Time.get_ticks_usec()-before
			if sample >= 8:
				if local: local_times.append(elapsed)
				else: exhaustive_times.append(elapsed)
	local_times.sort()
	exhaustive_times.sort()
	var sparse := court.cells.duplicate(true)
	court._rebuild_cast_layers(record)
	assert(court.cells == sparse)
	var material_dictionaries := 0
	for cell: Vector2i in court.cells:
		for value: Variant in court.cells[cell].values():
			if value is Dictionary: material_dictionaries += 1
	print(JSON.stringify({"scope":"isolated seven-cell rebuild ABBA; no frame-rate claim", "topology_cells":court.cells.size(), "old_empty_material_dictionaries":court.cells.size()*44, "sparse_material_dictionaries":material_dictionaries,"equivalent":true,"samples_each":local_times.size(),"local_p50_us":local_times[local_times.size()/2],"local_p95_us":local_times[int(local_times.size()*0.95)],"exhaustive_p50_us":exhaustive_times[exhaustive_times.size()/2],"exhaustive_p95_us":exhaustive_times[int(exhaustive_times.size()*0.95)]}))
	var warm_times: Array[int] = []
	var cold_times: Array[int] = []
	var hash_value := court.state_hash()
	for sample: int in 16:
		for warm: bool in [false,true,true,false]:
			if not warm: court._hash_cell_order.clear()
			var before := Time.get_ticks_usec()
			var value := court.state_hash()
			var elapsed := Time.get_ticks_usec()-before
			assert(value == hash_value)
			if sample >= 2:
				if warm: warm_times.append(elapsed)
				else: cold_times.append(elapsed)
	warm_times.sort()
	cold_times.sort()
	print(JSON.stringify({"scope":"whole chemistry hash; validated topology order cache only; no simulation capacity claim","samples_each":warm_times.size(),"warm_p50_us":warm_times[warm_times.size()/2],"warm_p95_us":warm_times[int(warm_times.size()*.95)],"cold_p50_us":cold_times[cold_times.size()/2],"cold_p95_us":cold_times[int(cold_times.size()*.95)]}))
	quit()
