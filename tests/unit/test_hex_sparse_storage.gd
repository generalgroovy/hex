extends FluxTestSuite

func run() -> int:
	var world := HexChemistryWorld.new()
	check(world.configure_geometry(Vector2i.ZERO, HexGrid.disk(Vector2i.ZERO, 3)), "sparse fixture configures")
	for cell: Vector2i in world.cells:
		equal(world.cells[cell].size(), 3, "untouched cell allocates metadata only")
	var source := {"id":1,"element":2,"cells":{Vector2i.ZERO:10,Vector2i.RIGHT:20}}
	world._rebuild_cast_layers(source)
	world.set_cell_amount(Vector2i.ZERO,"fire",2,30)
	var previous: Array = source.cells.keys()
	source.cells = {Vector2i.LEFT:15}
	world._rebuild_cast_layers(source,previous)
	equal(world.cells[Vector2i.ZERO].fire,{2:30},"local removal preserves another cast sharing its layer")
	check(not world.cells[Vector2i.RIGHT].has("fire"),"last owner releases the empty material dictionary")
	equal(world.cells[Vector2i.LEFT].fire,{1:15},"new footprint receives the changed allocation")
	var local_result := world.cells.duplicate(true)
	world._rebuild_cast_layers(source)
	equal(world.cells,local_result,"footprint-local rebuild equals exhaustive repair")
	var warm := world._stable_hash_cells()
	world._hash_cell_order.clear()
	equal(world._stable_hash_cells(),warm,"warm key-order cache preserves exact canonical records")
	world.cells.erase(Vector2i(3,0))
	world.cells[Vector2i(4,0)] = {"terrain":0,"elevation":0,"structure":0}
	var changed := world._stable_hash_cells()
	check(changed != warm,"same-count topology replacement is not hidden by cached order")
	world._hash_cell_order.clear()
	equal(world._stable_hash_cells(),changed,"revalidated membership equals cold canonical order")
	world.cells[Vector2i.ZERO].terrain = 7
	check(world._stable_hash_cells() != changed,"cached order never caches mutable values")
	return finish("hex-sparse-storage")
