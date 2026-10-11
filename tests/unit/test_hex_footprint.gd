extends FluxTestSuite


func run() -> int:
	_test_disk_predicates_and_cells()
	_test_sector_predicates_and_cells()
	_test_intersection_uses_one_parameter_interval()
	_test_visuals_are_inscribed_and_cell_clipped()
	_test_invalid_inputs_fail_closed()
	_test_boolean_contact_matches_exhaustive()
	_test_reduced_sector_signs()
	_test_sector_early_out_matches_reference()
	_test_local_polygon_ownership()
	_test_spray_contact_pruning()
	return finish("hex-footprint")


func _test_local_polygon_ownership() -> void:
	var selected := {}
	for cell: Vector2i in HexGrid.disk(Vector2i.ZERO, 8): selected[cell] = 1
	var origin := Vector2i(-35000, 61000)
	var random := RandomNumberGenerator.new()
	random.seed = 284791
	for index: int in 600:
		var point := {"x":float(random.randi_range(-240000,240000)),"y":float(random.randi_range(-240000,240000))}
		if index < 200:
			var cell: Vector2i = selected.keys()[index % selected.size()]
			var vertex: Vector2i = HexGrid.vertices(cell)[index % 6] + origin
			point = {"x":float(vertex.x) + [-0.000001,0.0,0.000001][index % 3],"y":float(vertex.y)}
		var owners: Array[Vector2i] = []
		for cell: Vector2i in selected:
			var polygon: Array[Vector2i] = []
			for vertex: Vector2i in HexGrid.vertices(cell): polygon.append(vertex + origin)
			if HexFootprint._float_point_in_polygon(point,polygon): owners.append(cell)
		owners.sort_custom(HexGrid._cell_less)
		var expected := {"cell":owners[0]} if not owners.is_empty() else {}
		equal(HexFootprint._nearest_polygon_cell(point,selected,origin),expected,"local ownership matches exhaustive cells including vertex ties")
		var seed := HexGrid.world_to_cell(Vector2i(roundi(float(point.x)-origin.x),roundi(float(point.y)-origin.y)))
		var canonical: Array[Vector2i] = []
		for candidate: Vector2i in HexGrid.disk(seed,2):
			if HexFootprint._float_point_in_polygon(point,HexFootprint._world_cell_polygon(candidate,origin)): canonical.append(candidate)
		canonical.sort_custom(HexGrid._cell_less)
		equal(HexFootprint._scalar_canonical_owner(point,origin),canonical[0] if not canonical.is_empty() else seed,"four-cell continuous owner matches old nineteen-cell exhaustive predicate")
	var polygon := HexFootprint._world_cell_polygon(Vector2i(2,-3),origin)
	check(polygon.is_read_only(),"cached geometry cannot be mutated by callers")
	var expected_polygon: Array[Vector2i] = []
	for vertex: Vector2i in HexGrid.vertices(Vector2i(2,-3)): expected_polygon.append(vertex+origin)
	equal(polygon,expected_polygon,"cached geometry preserves exact integer vertices")


func _test_spray_contact_pruning() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 381262103
	for index: int in 240:
		var origin := Vector2i(random.randi_range(-400000,400000),random.randi_range(-400000,400000))
		var selected := {}
		for cell: Vector2i in HexGrid.disk(Vector2i.ZERO,random.randi_range(1,6)):
			selected[cell] = int(random.randf() > 0.2)
		var start := origin + Vector2i(random.randi_range(-350000,350000),random.randi_range(-350000,350000))
		var shape := HexFootprint.disk(start,random.randi_range(1,180000))
		if index % 3 != 0:
			var aim: Vector2i = [Vector2i(1000,0),Vector2i(0,-1000),Vector2i(707,707),Vector2i(-707,707)][index%4]
			shape = HexFootprint.sector(start,aim,random.randi_range(1,380000),500000)
		if index % 11 == 0:
			# Closed radial/hex vertex contacts and exact shared edges.
			start = origin + HexGrid.LOCAL_VERTICES[index % 6]
			shape = HexFootprint.disk(start,0)
		var preferred := start if index % 2 == 0 else origin
		equal(HexFootprint.contact_shape_selected(shape,selected,origin,preferred),_reference_shape_contact(shape,selected,origin,preferred),"pruned Spray/field contact preserves full witness, tie and quantization record")


# Frozen pre-optimization enumeration: deliberately visits all selected cells.
func _reference_shape_contact(shape: Dictionary, stored_cells: Dictionary, grid_origin: Vector2i, preferred: Vector2i) -> Dictionary:
	var primitives := HexFootprint._primitive_parts(shape)
	var candidates := HexFootprint._common_point_candidates(primitives)
	candidates.append({"x":float(preferred.x),"y":float(preferred.y)})
	for primitive: Dictionary in primitives:
		candidates.append(HexFootprint._closest_point_in_primitive(primitive,preferred))
	for cell: Vector2i in HexFootprint._active_selected_cells(stored_cells):
		var polygon := HexFootprint._world_cell_polygon(cell,grid_origin)
		var center := HexGrid.center(cell)+grid_origin
		candidates.append({"x":float(center.x),"y":float(center.y)})
		candidates.append(HexFootprint._closest_point_in_polygon(preferred,polygon))
		for vertex: Vector2i in polygon: candidates.append({"x":float(vertex.x),"y":float(vertex.y)})
		for edge: int in polygon.size():
			var start: Vector2i = polygon[edge]
			var end: Vector2i = polygon[(edge+1)%polygon.size()]
			var interval := HexFootprint._segment_interval(shape,start,end)
			if not bool(interval.get("hit",false)): continue
			for amount: float in [float(interval.low),float(interval.high),(float(interval.low)+float(interval.high))*0.5]:
				candidates.append(HexFootprint._segment_scalar_point(start,end,amount))
	HexFootprint._sort_scalar_points_by_preference(candidates,preferred)
	for point: Dictionary in candidates:
		if not HexFootprint._scalar_in_all(primitives,point): continue
		var owner := HexFootprint._scalar_canonical_owner(point,grid_origin)
		if HexFootprint._selected_cell_active(stored_cells,owner):
			return HexFootprint._quantized_selected_witness(shape,stored_cells,grid_origin,point,owner)
		var fallback := HexFootprint._nearest_polygon_cell(point,stored_cells,grid_origin)
		if not fallback.is_empty() and HexFootprint._positive_area_in_cell(shape,Vector2i(fallback.cell),grid_origin):
			return HexFootprint._quantized_selected_witness(shape,stored_cells,grid_origin,point,Vector2i(fallback.cell))
	return {}


func _test_sector_early_out_matches_reference() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 529810
	for index: int in 1600:
		var aim := Vector2i(random.randi_range(-1000,1000),random.randi_range(-1000,1000))
		if aim == Vector2i.ZERO: aim = Vector2i(1,1)
		var squared := aim.x*aim.x+aim.y*aim.y
		var threshold := random.randi_range(1,squared-1)
		var origin := Vector2i(random.randi_range(-600000,600000),random.randi_range(-600000,600000))
		var start := origin+Vector2i(random.randi_range(-24000,24000),random.randi_range(-24000,24000))
		var reach := random.randi_range(1,512000)
		var shape := HexFootprint.sector(start,aim,reach,threshold)
		var cell := Vector2i(random.randi_range(-13,13),random.randi_range(-13,13))
		equal(HexFootprint._sector_positive_area_in_cell(shape,cell,origin),_reference_sector_cell(shape,cell,origin),"early sector witnesses/separation preserve the prior exact predicate")
	# Cardinal/diagonal slivers, cone-side ties and arc tangencies.
	for aim: Vector2i in [Vector2i(1000,0),Vector2i(0,-1000),Vector2i(707,707)]:
		for radius: int in [12000,13856,24000,27712,64000]:
			for threshold: int in [1,aim.length_squared()/2,aim.length_squared()-1]:
				for cell: Vector2i in HexGrid.disk(Vector2i.ZERO,3):
					var shape := HexFootprint.sector(Vector2i.ZERO,aim,radius,threshold)
					equal(HexFootprint._sector_positive_area_in_cell(shape,cell,Vector2i.ZERO),_reference_sector_cell(shape,cell,Vector2i.ZERO),"boundary sector agrees with unchanged reference")


# Frozen pre-optimization control flow, intentionally independent of new
# center-witness/early-separation branches. Shared exact scalar primitives stay.
func _reference_sector_cell(shape: Dictionary, cell: Vector2i, grid_origin: Vector2i) -> bool:
	var reach := int(shape.range)
	var aim: Vector2i = shape.aim
	var threshold := int(shape.cosine_squared)
	var side_squared := aim.x*aim.x+aim.y*aim.y-threshold
	if side_squared <= 0 or reach <= 0: return false
	var origin: Vector2i = shape.start
	if not HexFootprint._disk_positive_area_in_cell(HexFootprint.disk(origin,reach),cell,grid_origin): return false
	var polygon := HexFootprint._world_cell_polygon(cell,grid_origin)
	for vertex: Vector2i in polygon:
		if HexFootprint._sector_strictly_contains_integer(shape,vertex): return true
	for edge: int in polygon.size():
		if HexFootprint._sector_edge_closest_point_strictly_inside(shape,polygon[edge],polygon[(edge+1)%polygon.size()]): return true
	for side: int in [-1,1]:
		var inside := false
		for vertex: Vector2i in polygon:
			if HexFootprint._sector_half_plane_sign(vertex-origin,aim,threshold,side_squared,side)>0:
				inside=true;break
		if not inside: return false
	var clipped: Array[Dictionary] = []
	for vertex: Vector2i in polygon: clipped.append(HexFootprint._scalar_point(float(vertex.x),float(vertex.y)))
	var a := sqrt(float(side_squared))
	var b := sqrt(float(threshold))
	clipped = HexFootprint._clip_scalar_polygon_positive(clipped,origin,a*aim.x-b*aim.y,a*aim.y+b*aim.x)
	clipped = HexFootprint._clip_scalar_polygon_positive(clipped,origin,a*aim.x+b*aim.y,a*aim.y-b*aim.x)
	if clipped.size()<3 or HexFootprint._scalar_polygon_area_twice(clipped)<=0.0: return false
	if HexGrid._point_in_cell(origin-grid_origin,cell): return true
	for edge: int in polygon.size():
		var interval := HexFootprint._sector_selection_edge_interval(shape,polygon[edge],polygon[(edge+1)%polygon.size()])
		if bool(interval.get("hit",false)) and float(interval.high)>float(interval.low): return true
	return false


func _test_reduced_sector_signs() -> void:
	# Large exact equality and adjacent integer witnesses take the guarded
	# arbitrary-precision path whenever floating products cannot separate them.
	for side: int in [-1,1]:
		for delta: int in [-1,0,1]:
			var offset := Vector2i(8000000,(-8000000+delta)*side)
			equal(HexFootprint._sector_half_plane_sign(offset,Vector2i(1000,0),500000,500000,side),signi(delta),"large equality/neighbor preserves exact sign")
	var random := RandomNumberGenerator.new()
	random.seed=991448
	for aim: Vector2i in [Vector2i(1000,0),Vector2i(0,-1000),Vector2i(-707,707),Vector2i(913,-407),Vector2i(1,1)]:
		var squared := aim.x*aim.x+aim.y*aim.y
		for threshold: int in [1,squared/2,squared-1]:
			for unused: int in 200:
				var offset := Vector2i(random.randi_range(-8000000,8000000),random.randi_range(-8000000,8000000))
				for side: int in [-1,1]:
					var projection := offset.x*aim.x+offset.y*aim.y
					var cross := (aim.x*offset.y-aim.y*offset.x)*side
					var expected := 0
					if projection==0: expected=signi(cross)
					elif cross==0 or (projection>0)==(cross>0): expected=signi(projection)
					else:
						var left := HexGrid._nat_multiply(HexGrid._nat(squared-threshold),HexGrid._nat_multiply(HexGrid._nat(absi(projection)),HexGrid._nat(absi(projection))))
						var right := HexGrid._nat_multiply(HexGrid._nat(threshold),HexGrid._nat_multiply(HexGrid._nat(absi(cross)),HexGrid._nat(absi(cross))))
						var compare := HexGrid._nat_compare(left,right)
						if compare!=0: expected=signi(projection) if compare>0 else signi(cross)
					equal(HexFootprint._sector_half_plane_sign(offset,aim,threshold,squared-threshold,side),expected,"reduced int64/fallback sign matches original exact natural products")


func _test_boolean_contact_matches_exhaustive() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 728102
	for dense: bool in [false,true]:
		var coverage := {}
		for cell: Vector2i in HexGrid.disk(Vector2i.ZERO,7):
			if dense or random.randi_range(0,3)==0: coverage[cell] = random.randi_range(0,2)
		for origin: Vector2i in [Vector2i.ZERO,Vector2i(-37111,82519)]:
			for index: int in 400:
				var start := origin+Vector2i(random.randi_range(-200000,200000),random.randi_range(-200000,200000))
				var end := start+Vector2i(random.randi_range(-8000,8000),random.randi_range(-8000,8000)) if index%2==0 else origin+Vector2i(random.randi_range(-250000,250000),random.randi_range(-250000,250000))
				if index%9==0: end=start
				var expected := not HexFootprint.traversed_selected_cells(coverage,origin,start,end).is_empty()
				equal(HexFootprint.touches_selected(coverage,origin,start,end),expected,"local boolean agrees with exhaustive positive-cell clip")
				equal(HexFootprint.touches_selected(coverage,origin,end,start),expected,"reversed path retains canonical contact")
	for owner: Vector2i in [Vector2i.ZERO,Vector2i(-1,0),Vector2i(0,-1)]:
		var selected := {owner:1}
		for point: Vector2i in HexGrid.vertices(Vector2i.ZERO):
			for delta: Vector2i in [Vector2i.ZERO,Vector2i.ONE,Vector2i(-1,1),Vector2i(50000,0),Vector2i(0,-50000)]:
				var end := point+delta
				equal(HexFootprint.touches_selected(selected,Vector2i.ZERO,point,end),not HexFootprint.traversed_selected_cells(selected,Vector2i.ZERO,point,end).is_empty(),"face/vertex ties retain exact canonical owner")
	check(not HexFootprint.touches_selected({Vector2i.ZERO:1},Vector2i.ZERO,Vector2i(9000000,0),Vector2i.ZERO),"invalid path cannot use endpoint shortcut")


func _test_disk_predicates_and_cells() -> void:
	var footprint := HexFootprint.disk(Vector2i(11_000, 0), 2_000)
	check(HexFootprint.validate(footprint), "bounded disk validates")
	check(HexFootprint.contains(footprint, Vector2i(13_000, 0)), "disk includes exact point tangency")
	check(not HexFootprint.contains(footprint, Vector2i(13_001, 0)), "disk excludes a one-unit radial miss")
	check(HexFootprint.segment_intersects(footprint, Vector2i(9_000, 2_000), Vector2i(13_000, 2_000)), "disk includes exact segment tangency")
	check(not HexFootprint.segment_intersects(footprint, Vector2i(9_000, 2_001), Vector2i(13_000, 2_001)), "disk excludes a one-unit segment miss")
	var cells := HexFootprint.intersected_cells(footprint, Vector2i.ZERO)
	equal(cells, [Vector2i.ZERO, Vector2i(1, 0)], "off-center disk clips across the touched shared face without nearest-N expansion")
	var negative := HexFootprint.intersected_cells(HexFootprint.disk(Vector2i(-12_000, -6_928), 0), Vector2i.ZERO)
	check(negative.size() >= 3 and negative.has(Vector2i.ZERO) and negative.has(Vector2i(-1, 0)), "zero-radius negative vertex retains every closed polygon contact")


func _test_sector_predicates_and_cells() -> void:
	var footprint := HexFootprint.sector(Vector2i.ZERO, Vector2i(1_000, 0), 80_000, 500_000)
	check(HexFootprint.validate(footprint), "45-degree convex sector validates")
	check(HexFootprint.contains(footprint, Vector2i(30_000, 30_000)), "sector includes its exact rational cone boundary")
	check(not HexFootprint.contains(footprint, Vector2i(30_000, 30_001)), "sector excludes one unit beyond the cone boundary")
	check(HexFootprint.contains(footprint, Vector2i(80_000, 0)), "sector includes the radial endpoint")
	check(not HexFootprint.contains(footprint, Vector2i(80_001, 0)), "sector excludes one unit beyond range")
	check(HexFootprint.segment_intersects(footprint, Vector2i(40_000, -60_000), Vector2i(40_000, 60_000)), "segment crosses the sector interior")
	check(not HexFootprint.segment_intersects(footprint, Vector2i(-20_000, -5_000), Vector2i(-20_000, 5_000)), "segment behind the explicit origin misses")
	var cells := HexFootprint.intersected_cells(footprint, Vector2i.ZERO)
	check(cells.has(Vector2i.ZERO) and cells.has(Vector2i(1, 0)), "sector selects polygons it actually intersects")
	check(not cells.has(Vector2i(-1, 0)), "sector does not authorize the cell behind its origin merely because a range disk touches it")


func _test_intersection_uses_one_parameter_interval() -> void:
	var left := HexFootprint.disk(Vector2i(-10_000, 0), 6_000)
	var right := HexFootprint.disk(Vector2i(10_000, 0), 6_000)
	var empty_overlap := HexFootprint.intersection(left, right)
	var path_start := Vector2i(-20_000, 0)
	var path_end := Vector2i(20_000, 0)
	check(HexFootprint.segment_intersects(left, path_start, path_end), "control segment crosses first primitive")
	check(HexFootprint.segment_intersects(right, path_start, path_end), "control segment crosses second primitive")
	check(not HexFootprint.segment_intersects(empty_overlap, path_start, path_end), "separate primitive intervals cannot fabricate composite contact")
	check(not HexFootprint.intersects(left, right), "separated disks have no product overlap")
	equal(HexFootprint.intersected_cells(empty_overlap, Vector2i.ZERO), [], "disjoint disks inside the same hex cannot fabricate an occupied product cell")
	var overlapping := HexFootprint.intersection(HexFootprint.disk(Vector2i.ZERO, 10_000), HexFootprint.disk(Vector2i(12_000, 0), 10_000))
	check(HexFootprint.segment_intersects(overlapping, path_start, path_end), "shared parameter interval detects a real lens crossing")
	check(HexFootprint.contains(overlapping, Vector2i(6_000, 0)), "composite membership requires both primitives")
	check(HexFootprint.intersects(overlapping.parts[0], overlapping.parts[1]), "tangent-inclusive disk overlap is exact")
	equal(HexFootprint.intersected_cells(overlapping, Vector2i.ZERO), [Vector2i.ZERO], "small disk lens wholly inside one hex still selects its containing cell")
	var modifier := HexFootprint.disk(Vector2i(6_000, 0), 3_000)
	var modified_product := HexFootprint.intersection(overlapping, modifier)
	check(HexFootprint.validate(modified_product), "one primitive modifier may refine a two-parent product")
	check(HexFootprint.intersects(modifier, overlapping), "primitive-versus-product overlap filters a shared analytic witness against all leaves")
	check(HexFootprint.contains(modified_product, Vector2i(6_000, 0)), "three-leaf composite membership is simultaneous")
	equal(HexFootprint.intersected_cells(modified_product, Vector2i.ZERO), [Vector2i.ZERO], "three-leaf region wholly inside a cell retains that cell")
	check(not HexFootprint.intersects(HexFootprint.disk(Vector2i(25_000, 0), 2_000), overlapping), "primitive outside a product lens cannot match either parent independently")


func _test_visuals_are_inscribed_and_cell_clipped() -> void:
	var center := Vector2i(31_000, 0)
	var radius := HexFootprint.MAX_RADIUS
	var footprint := HexFootprint.disk(center, radius)
	var polygon := HexFootprint.visual_polygon(footprint, Vector2i.ZERO, Vector2i.ZERO)
	check(polygon.size() >= 3, "bounded display approximation clips to a visible cell polygon")
	for point: Vector2 in polygon:
		var offset := point - Vector2(center)
		check(offset.length_squared() <= float(radius) * float(radius) + 0.01, "display clipping never paints outside the authoritative disk")
		check(_float_point_in_hex(point, HexGrid.vertices(Vector2i.ZERO)), "display polygon stays inside its selected hex")
	var full := HexFootprint.visual_polygon(HexFootprint.disk(Vector2i.ZERO, 10_000), Vector2i.ZERO, Vector2i.ZERO)
	var minimum_radius := INF
	for point: Vector2 in full:
		minimum_radius = minf(minimum_radius, point.length())
	check(10_000.0 - minimum_radius <= 250.0, "inscribed display error remains at most one quarter pixel")


func _test_invalid_inputs_fail_closed() -> void:
	var too_large := HexFootprint.disk(Vector2i.ZERO, HexFootprint.MAX_RADIUS + 1)
	check(not HexFootprint.validate(too_large), "oversized authoritative disk is rejected")
	check(not HexFootprint.contains(too_large, Vector2i.ZERO), "invalid disk cannot authorize a point")
	equal(HexFootprint.intersected_cells(too_large, Vector2i.ZERO), [], "invalid disk cannot select cells")
	check(not HexFootprint.validate(HexFootprint.sector(Vector2i.ZERO, Vector2i.ZERO, 10_000, 500_000)), "zero-aim sector is rejected")
	check(not HexFootprint.validate(HexFootprint.sector(Vector2i.ZERO, Vector2i(1_000, 0), -1, 500_000)), "negative-range sector is rejected")
	check(HexFootprint.validate(HexFootprint.sector(Vector2i.ZERO, Vector2i(1_000, 0), 380_000, 820_000)), "authored 380 px Spray range stays inside the proved sector envelope")
	check(HexFootprint.validate(HexFootprint.sector(Vector2i.ZERO, Vector2i(1_000, 0), HexFootprint.MAX_SECTOR_RANGE, 820_000)), "sector accepts its 512 px geometry ceiling")
	check(not HexFootprint.validate(HexFootprint.sector(Vector2i.ZERO, Vector2i(1_000, 0), HexFootprint.MAX_SECTOR_RANGE + 1, 820_000)), "sector rejects one unit beyond its geometry ceiling")
	var primitive := HexFootprint.disk(Vector2i.ZERO, 1_000)
	var three_way := HexFootprint.intersection(HexFootprint.intersection(primitive, primitive), primitive)
	check(HexFootprint.validate(three_way), "one modifier may intersect a two-parent product within the explicit three-leaf bound")
	check(not HexFootprint.validate(HexFootprint.intersection(three_way, primitive)), "a third composite level fails closed")


func _float_point_in_hex(point: Vector2, vertices: Array[Vector2i]) -> bool:
	for index: int in range(vertices.size()):
		var a := Vector2(vertices[index])
		var b := Vector2(vertices[(index + 1) % vertices.size()])
		if (b - a).cross(point - a) < -0.01:
			return false
	return true
