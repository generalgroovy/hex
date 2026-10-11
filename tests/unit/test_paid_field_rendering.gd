extends FluxTestSuite

const Marks = preload("res://src/presentation/retro_material_marks.gd")
const BeforeMarks = preload("res://tests/support/retro_material_marks_before_paid_mesh.gd")
const Court = preload("res://src/presentation/hex_court_presenter.gd")
const BeforeCourt = preload("res://tests/support/hex_court_before_paid_mesh.gd")
const GlowCache = preload("res://src/presentation/hex_surface_glow_cache.gd")
const BeforeGlow = preload("res://tests/support/hex_magic_glow_before_paid_mesh.gd")
const Grid = preload("res://src/sim/hex/hex_grid.gd")

func run() -> int:
	_test_native_texture_identity()
	_test_exact_geometry_and_residency()
	_test_fresh_dynamic_seams()
	_test_region_preparation_current_inputs()
	_test_grouped_boundary_counts()
	_test_retained_surface_glow()
	return finish("paid-field-rendering")

func _polygon(offset: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2i in Grid.vertices(Vector2i.ZERO): result.append(Vector2(point) / 1000.0 + offset)
	return result

func _test_native_texture_identity() -> void:
	var current := Marks.new()
	var before := BeforeMarks.new()
	equal(Marks.MASKS, BeforeMarks.MASKS, "all original native silhouettes remain exact")
	equal(Marks.ANIMATED_MASKS, BeforeMarks.ANIMATED_MASKS, "all original animation frames remain exact")
	for kind: String in BeforeMarks.MASKS:
		for frame: int in [-1, 0, 1, 2, 3]:
			for seed: int in [-1, 0, 1, 2]:
				for padded: bool in [false, true]:
					var palette: Array[Color] = [Color(0.11,0.23,0.37,0.81), Color(0.44,0.53,0.62,0.47), Color(0.83,0.92,0.99,0.97)]
					var actual: Texture2D = current.texture_for(kind,palette[0],palette[1],palette[2],frame,padded,seed)
					var expected: Texture2D = before.texture_for(kind,palette[0],palette[1],palette[2],frame,padded,seed)
					check(actual != null and expected != null, "every original native stamp resolves")
					if actual == null or expected == null: continue
					equal(actual.get_image().get_data(), expected.get_image().get_data(), "cached prefix preserves exact RGBA texels, variants and padding")
					equal(current.order, before.order, "original bounded FIFO order remains exact")
	# Exact colors sharing one HTML key retain the old first-entry behavior.
	for amount: float in [0.5001, 0.5002]:
		var actual: Texture2D = current.texture_for("fire",Color(amount,0.2,0.3),Color.WHITE,Color.BLACK,1,true)
		var expected: Texture2D = before.texture_for("fire",Color(amount,0.2,0.3),Color.WHITE,Color.BLACK,1,true)
		equal(actual.get_image().get_data(), expected.get_image().get_data(), "HTML-color quantization behavior is unchanged")
	for index: int in 210:
		var tint := Color(float(index)/211.0, 0.2, 0.4, 0.7)
		current.texture_for("steam",tint,Color.WHITE,Color.BLACK,index,true)
		before.texture_for("steam",tint,Color.WHITE,Color.BLACK,index,true)
		equal(current.order, before.order, "prefix capacity does not change texture eviction or full key")
	check(int(current.geometry_stats().texture_prefixes) <= 192, "palette prefixes have a strict192-entry bound")
	equal(current.texture_for("absent",Color.WHITE,Color.WHITE,Color.WHITE,0), null, "unknown material remains refused")

func _test_exact_geometry_and_residency() -> void:
	var current := Marks.new()
	var court := Court.new()
	var before := BeforeCourt.new()
	for offset: Vector2 in [Vector2.ZERO,Vector2(0.25,0.75),Vector2(8100.125,8090.875)]:
		for reverse: bool in [false,true]:
			var polygon := _polygon(offset)
			if reverse: polygon.reverse()
			var original := polygon.duplicate()
			var mesh: ArrayMesh = current._region_mesh(polygon)
			check(mesh != null, "finite six-point geometry admits a retained mesh")
			if mesh == null: continue
			var arrays := mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var expected := PackedVector3Array()
			for point: Vector2 in original: expected.append(Vector3(point.x,point.y,0.0))
			equal(vertices,expected,"mesh preserves absolute unrounded ordered vertices")
			equal(arrays[Mesh.ARRAY_TEX_UV],BeforeMarks.region_uv(original),"mesh preserves independently frozen exact UV mapping")
			equal(arrays[Mesh.ARRAY_INDEX],Geometry2D.triangulate_polygon(original),"triangles retain native ordered polygon triangulation")
			equal(current._region_mesh(original),mesh,"same exact polygon reuses its resident RID")
			var layout: Dictionary = court._region_layout(original)
			var center: Vector2 = before._polygon_centroid(original)
			equal(layout.center,center,"geometry cache equals original centroid")
			equal(layout.clearance,before._polygon_clearance(center,original),"geometry cache equals original clearance")
			check(layout.is_read_only(),"shared geometry values cannot be mutated by consumers")
			polygon[0] += Vector2(2,1)
			equal(current._region_mesh(original),mesh,"caller mutation cannot corrupt retained geometry key")
			check(current._region_mesh(polygon) != mesh,"different current geometry never reuses old RID")
			var changed: Dictionary = court._region_layout(polygon)
			equal(changed.center,before._polygon_centroid(polygon),"same-count geometry mutation is immediately observed")
	var first: ArrayMesh = current._region_mesh(_polygon())
	for index: int in 530:
		current._region_mesh(_polygon(Vector2(index*65,100)))
		court._region_layout(_polygon(Vector2(index*65,100)))
	equal(int(current.geometry_stats().meshes),512,"retained mesh count never exceeds512")
	equal(current._region_mesh(_polygon(Vector2(90000,90000))),null,"overflow explicitly requests exact original drawing fallback")
	equal(current._region_mesh(_polygon()),first,"capacity never evicts a still-referenced native mesh")
	equal(court._region_layouts.size(),512,"geometry-only cache remains bounded")
	var overflow := _polygon(Vector2(90000.25,90000.75))
	equal(court._region_layout(overflow).center,before._polygon_centroid(overflow),"uncached geometry stays exact at capacity")
	for invalid: PackedVector2Array in [PackedVector2Array(),PackedVector2Array([Vector2.ZERO]),PackedVector2Array([Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO])]:
		equal(Marks.new()._region_mesh(invalid),null,"invalid mesh never submits fabricated geometry")

	for count: int in [5,7,8192]:
		var too_many := PackedVector2Array()
		for index: int in count: too_many.append(Vector2.from_angle(float(index)*TAU/float(count))*20.0)
		equal(Marks.new()._region_mesh(too_many),null,"non-six polygon cannot allocate an unbounded mesh")
		equal(Marks.region_uv(too_many),BeforeMarks.region_uv(too_many),"rejected vertex count retains original draw fallback admission")

func _test_fresh_dynamic_seams() -> void:
	var current := Court.new()
	var before := BeforeCourt.new()
	var row := {"material":"fire","phase":"active","danger":true,"owner_key":{"owner":1,"team":2},"footprint_id":4,"intensity":750,"expiry_tick":400,"decay_tick":350}
	for material: String in ["fire","steam","conflagration","cinderveil","compound_63"]:
		row.material = material
		for field: String in ["phase","danger","owner_key","footprint_id","intensity","expiry_tick","decay_tick"]:
			var values: Array = ["forming","active","decaying"] if field == "phase" else [false,true] if field == "danger" else [null,1,[1,2],{"owner":1,"team":2},{"team":2,"owner":1}] if field == "owner_key" else [0,1,300,400]
			for value: Variant in values:
				row[field] = value
				equal(current._region_edge_prefix(row),before._region_edge_prefix(row),"current %s/%s preserves exact owner/phase/budget seam semantics" % [material,field])
	for index: int in 540:
		row.owner_key = index
		equal(current._region_edge_prefix(row),before._region_edge_prefix(row),"uncached prefix overflow remains exact")
	equal(current._edge_prefixes.size(),512,"dynamic seam key count remains bounded")
	check(not current.draw_ground(null,null,0,false),"invalid draw remains refused")
	equal(current._edge_prefixes.size(),0,"every new draw discards previous dynamic seam identities")

func _source_region(offset: Vector2 = Vector2.ZERO) -> Dictionary:
	var fixed := PackedVector2Array()
	for point: Vector2 in _polygon(offset): fixed.append(point*1000.0)
	return {"polygon":fixed,"phase":"active","footprint_id":1,"danger":true,"intensity":750,
		"owner":1,"owner_key":{"owner":1,"team":2},"source_ids":[1,2],"quantity":400,
		"expiry_tick":500,"active_tick":50,"decay_tick":450,"recipe_wire_id":309,
		"direction":Vector2i(1000,0),"material":"conflagration"}

func _test_region_preparation_current_inputs() -> void:
	var current := Court.new()
	var before := BeforeCourt.new()
	var source := _source_region(Vector2(1.25,3.75))
	var expected := _polygon(Vector2(1.25,3.75))
	var original := source.duplicate(true)
	equal(current._prepare_region(source,"conflagration",expected),before._prepare_region(source,"conflagration",expected),"cold conversion equals frozen region model")
	for field: String in ["phase","danger","intensity","owner","owner_key","source_ids","quantity","expiry_tick","active_tick","decay_tick","footprint_id","direction"]:
		var variants: Array = [0,1,900]
		if field == "phase": variants = ["forming","active","decaying",""]
		elif field == "danger": variants = [false,true]
		elif field == "owner_key": variants = [null,[1,2],{"owner":2,"team":1}]
		elif field == "source_ids": variants = [[],[1],[4,3,2]]
		elif field == "direction": variants = [Vector2i.ZERO,Vector2i(0,-1000),Vector2i(-1000,0)]
		for value: Variant in variants:
			source = original.duplicate(true)
			source[field] = value
			equal(current._prepare_region(source,"conflagration",expected),before._prepare_region(source,"conflagration",expected),"warm geometry reads fresh %s" % field)
	source = original.duplicate(true)
	var first: Dictionary = current._prepare_region(source,"conflagration",expected)
	source.source_ids.append(99)
	equal(first.source_ids,[1,2],"published source ID arrays remain detached from later source mutation")
	equal(current._prepare_region(source,"conflagration",expected).source_ids,[1,2,99],"warm conversion observes newly changed source IDs")
	# Source vertices are copied-on-write; no caller may mutate a retained key or
	# a later returned geometry array by changing an earlier result.
	var returned: PackedVector2Array = first.polygon
	returned[0] += Vector2(19,11)
	first.polygon = returned
	equal(current._prepare_region(original,"conflagration",expected),before._prepare_region(original,"conflagration",expected),"caller mutation of returned pixels cannot poison geometry cache")
	var altered_fixed: PackedVector2Array = original.polygon.duplicate()
	altered_fixed[0] += Vector2(11000,19000)
	source.polygon = altered_fixed
	equal(current._prepare_region(source,"conflagration",expected),{},"warm original expected cell refuses changed source geometry")
	equal(current._prepare_region(original,"conflagration",expected),before._prepare_region(original,"conflagration",expected),"failed new geometry does not poison resident valid pair")
	var expected_changed := expected.duplicate()
	expected_changed[0] += Vector2(3,0)
	equal(current._prepare_region(original,"conflagration",expected_changed),{},"same source cannot reuse validation against a different expected cell")
	for expected_variant: PackedVector2Array in [PackedVector2Array(),expected,expected.slice(0,5),PackedVector2Array([Vector2.ZERO])]:
		equal(current._prepare_region(original,"conflagration",expected_variant),before._prepare_region(original,"conflagration",expected_variant),"optional expected-cell cardinality keeps published validation semantics")
	var reversed_expected := expected.duplicate()
	reversed_expected.reverse()
	equal(current._prepare_region(original,"conflagration",reversed_expected),before._prepare_region(original,"conflagration",reversed_expected),"vertex-order independent validation keeps original output order")
	# Previously accepted geometry must not skip unrelated current validation.
	for missing: String in ["polygon","phase","footprint_id","danger","intensity","expiry_tick"]:
		source = original.duplicate(true); source.erase(missing)
		equal(current._prepare_region(source,"conflagration",expected),before._prepare_region(source,"conflagration",expected),"warm geometry does not hide missing "+missing)
	for field: String in ["direction","source_ids","material","recipe_wire_id","polygon"]:
		source = original.duplicate(true)
		source[field] = "wrong" if field != "recipe_wire_id" else 310
		equal(current._prepare_region(source,"conflagration",expected),{},"warm geometry does not hide invalid "+field)
	for value: Variant in [null,12,[],"region"]:
		equal(current._prepare_region(value,"conflagration",expected),{},"non-dictionary records remain refused")
	for count: int in [0,5,7]:
		source = original.duplicate(true)
		var invalid := PackedVector2Array()
		for index: int in count: invalid.append(Vector2(index,index))
		source.polygon = invalid
		equal(current._prepare_region(source,"conflagration",expected),{},"wrong raw vertex count remains refused")
	for invalid_value: float in [NAN,INF,-INF]:
		source = original.duplicate(true)
		var invalid: PackedVector2Array = source.polygon.duplicate()
		invalid[0] = Vector2(invalid_value,0)
		source.polygon = invalid
		equal(current._prepare_region(source,"conflagration",expected),{},"nonfinite raw geometry remains refused")
	for index: int in 530:
		var offset := Vector2(index*51.25,index*0.75)
		source = _source_region(offset)
		var cell := _polygon(offset)
		equal(current._prepare_region(source,"conflagration",cell),before._prepare_region(source,"conflagration",cell),"all conversions remain exact beyond bounded geometry capacity")
	equal(current._prepare_region(original,"conflagration",expected),before._prepare_region(original,"conflagration",expected),"old validated geometry remains exact after cache capacity")

	var stats: Dictionary = current.region_geometry_cache_stats()
	equal(stats.entries,512,"validated geometry entries have an exact512 bound")
	equal(stats.builds,512,"each retained fixed/expected pair builds once")
	check(int(stats.hits)>0 and int(stats.fallbacks)>0 and int(stats.rejections)>0,"warm hits, exact overflow and malformed rejection all execute")
	for key: Array in current._pixel_region_polygons:
		check(key.is_read_only(),"retained fixed/expected pair container is read-only")
		equal((key[0] as PackedVector2Array).size(),6,"every stored source key has exactlysixvertices")
		equal((key[1] as PackedVector2Array).size(),6,"every stored expected key has exactlysixvertices")

func _test_grouped_boundary_counts() -> void:
	var current := Court.new()
	var before := BeforeCourt.new()
	var first := current._prepare_region(_source_region(),"conflagration",_polygon())
	var next_fixed := PackedVector2Array()
	var next_pixels := PackedVector2Array()
	for point: Vector2i in Grid.vertices(Vector2i(1,0)):
		next_fixed.append(Vector2(point)); next_pixels.append(Vector2(point)/1000.0)
	var second_source := _source_region()
	second_source.polygon = next_fixed
	second_source.footprint_id = 2
	var second := current._prepare_region(second_source,"conflagration",next_pixels)
	for duplicate_count: int in [1,2,6]:
		var first_rows: Array[Dictionary] = []
		for _index: int in duplicate_count: first_rows.append(first.duplicate(true))
		var second_rows: Array[Dictionary] = [second.duplicate(true)]
		var grouped := {Vector2i.ZERO:first_rows,Vector2i(1,0):second_rows}
		equal(current._region_edge_counts(grouped),before._region_edge_counts(grouped),"same-cell repeated footprint edges count once per current prefix")
		for field: String in ["phase","danger","owner_key","expiry_tick","intensity","footprint_id","decay_tick"]:
			var changed := grouped.duplicate(true)
			changed[Vector2i.ZERO][0][field] = "decaying" if field == "phase" else false if field == "danger" else {"team":9,"owner":8} if field == "owner_key" else 501
			equal(current._region_edge_counts(changed),before._region_edge_counts(changed),"warm edge pass immediately observes fresh "+field)
		var regrouped := {Vector2i.ZERO:second_rows,Vector2i(1,0):first_rows}
		equal(current._region_edge_counts(regrouped),before._region_edge_counts(regrouped),"same region count with changed cell grouping retains exact edge counts")
		first_rows.reverse()
		equal(current._region_edge_counts(grouped),before._region_edge_counts(grouped),"current ordered region traversal retains exact edge counts")

	# More than64 distinct region identities in one cell retains the original
	# per-edge dedup/count/insertion-order path after the transient guard fills.
	var many: Array[Dictionary] = []
	for index: int in 140:
		var region := first.duplicate(true)
		region.owner_key = index%70
		many.append(region)
	var overflow := {Vector2i.ZERO:many,Vector2i(1,0):[second]}
	equal(current._region_edge_counts(overflow),before._region_edge_counts(overflow),"same-cell identity overflow keeps original counts")
	equal(current._region_edge_counts(overflow).keys(),before._region_edge_counts(overflow).keys(),"same-cell identity overflow keeps exact insertion order")

	# Mantle's unified compound keeps distinct paid footprints while compatible
	# same-owner/phase overlaps contribute only one side of each cell boundary.
	var compound_rows: Array[Dictionary] = []
	for index: int in 6:
		var region := first.duplicate(true)
		region.material = "compound_63"
		region.recipe_wire_id = 463
		region.footprint_id = 100+index
		region.source_ids = [200+index]
		compound_rows.append(region)
	var compound := {Vector2i.ZERO:compound_rows}
	var one_compound := {Vector2i.ZERO:[compound_rows[0]]}
	equal(current._region_edge_counts(compound),before._region_edge_counts(compound),"six distinct paid Mantle footprints retain frozen unified boundary counts")
	equal(current._region_edge_counts(compound).keys(),before._region_edge_counts(compound).keys(),"six distinct paid Mantle footprints retain exact boundary insertion order")
	equal(current._region_edge_counts(compound),before._region_edge_counts(one_compound),"compatible same-cell Mantle footprints count one side rather than six")

func _test_retained_surface_glow() -> void:
	var current := GlowCache.new()
	for offset: Vector2 in [Vector2.ZERO,Vector2(0.25,0.75),Vector2(8125.125,7090.875)]:
		for reverse: bool in [false,true]:
			var polygon := _polygon(offset)
			if reverse: polygon.reverse()
			var original := polygon.duplicate()
			var insets: Array[PackedVector2Array] = current.geometry_for_polygon(polygon)
			equal(insets.size(),2,"exact glow geometry retains bothoriginal layers")
			if insets.size() != 2: continue
			var entry: Dictionary = current._geometry_entry(polygon)
			check(entry.is_read_only() and (entry.meshes as Array).is_read_only() and (entry.polygons as Array).is_read_only(),"published retained glow containers are immutable")
			for layer: int in 2:
				var expected: PackedVector2Array = BeforeGlow.surface_polygon(original,layer)
				equal(insets[layer],expected,"each glow inset is byte-exact old convex geometry")
				var mesh: ArrayMesh = entry.meshes[layer]
				var arrays := mesh.surface_get_arrays(0)
				var vertices := PackedVector3Array()
				for point: Vector2 in expected: vertices.append(Vector3(point.x,point.y,0.0))
				equal(arrays[Mesh.ARRAY_VERTEX],vertices,"glow mesh uses exact unrounded inset vertices")
				equal(arrays[Mesh.ARRAY_INDEX],Geometry2D.triangulate_polygon(expected),"glow indices preserve native polygon triangulation")
				var changed := insets[layer]
				changed[0] += Vector2(19,17)
				insets[layer] = changed
				equal(current.geometry_for_polygon(original)[layer],expected,"public inset mutation cannot poison retained glow")
			polygon[0] += Vector2(1,1)
			equal(current.geometry_for_polygon(original)[0],BeforeGlow.surface_polygon(original,0),"caller mutation cannot poison retained glow key")
	var first: Dictionary = current._geometry_entry(_polygon())
	for index: int in 280: current.geometry_for_polygon(_polygon(Vector2(index*53,100)))
	equal(current.stats().entries,256,"retained glow is bounded to256 exact polygons")
	equal(current.stats().meshes,512,"each retained glow has exactlytwo meshes")
	equal(current._geometry_entry(_polygon()).meshes[0],first.meshes[0],"capacity never evicts an in-flight glow RID")
	equal(current.geometry_for_polygon(_polygon(Vector2(90000,90000))).size(),0,"uncached glow at capacity requests original static fallback")
	check(int(current.stats().hits)>0,"retained glow positive reuse executes")
	var invalids: Array[PackedVector2Array] = [PackedVector2Array(),PackedVector2Array([Vector2.ZERO]),PackedVector2Array([Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO,Vector2.ZERO])]
	var bowtie := _polygon()
	var original_point := bowtie[1]
	bowtie[1] = bowtie[4]; bowtie[4] = original_point
	invalids.append(bowtie)
	for invalid: PackedVector2Array in invalids:
		equal(GlowCache.new().geometry_for_polygon(invalid).size(),0,"malformed/crossed glow never caches invented geometry")
		equal(BeforeGlow.surface_polygon(invalid,0).size(),0,"malformed glow refusal has an independent original witness")
	for opacity: float in [0.0,-1.0,NAN,INF]:
		equal(current.draw_surface(null,_polygon(),Color.WHITE,Color.WHITE,opacity),0,"null/invalid glow admission remainsquiet")
