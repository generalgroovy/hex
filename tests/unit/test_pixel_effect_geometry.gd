extends FluxTestSuite
# Explicit retained 36-sequence archive geometry; live63 uses Hex occupied cells.

const Mask = preload("res://src/presentation/pixel_effect_geometry.gd")
const Chemistry = preload("res://tests/support/archive_chemistry_visual_fixture.gd")
const Reaction = preload("res://src/sim/chemistry/element_reaction_state.gd")


func run() -> int:
	_test_all_shapes()
	_test_safe_holes_and_paths()
	_test_worldbone_and_cache()
	_test_texture_clipping()
	return finish("pixel-effect-geometry")


func _state(wire: int, direction: Vector2i = Vector2i(1000, 0)) -> ElementReactionState:
	var definition := Chemistry.recipe(wire)
	var state := Reaction.new()
	state.entity_id = 4000
	state.recipe_wire_id = wire
	state.position_x = 500000
	state.position_y = 500000
	state.radius = int(definition.radius)
	state.length = int(definition.length)
	state.direction_x = direction.x
	state.direction_y = direction.y
	var endpoint := Vector2i(state.position_x, state.position_y) + Chemistry.scaled(direction, state.length)
	state.endpoint_x = endpoint.x
	state.endpoint_y = endpoint.y
	state.created_tick = 10
	state.active_tick = 20
	state.decay_tick = 320
	state.expiry_tick = 380
	return state


func _test_all_shapes() -> void:
	var config := SimConfig.new()
	var masks := Mask.new()
	for wire: int in range(301, 337):
		for direction: Vector2i in [Vector2i(1000, 0), Vector2i(707, 707), Vector2i(0, 1000), Vector2i(-707, 707), Vector2i(-1000, 0), Vector2i(-707, -707), Vector2i(0, -1000), Vector2i(707, -707)]:
			var state := _state(wire, direction)
			if wire in [313, 319, 328]:
				state.path_points = PackedInt64Array([500000, 500000, state.endpoint_x, state.endpoint_y])
			var before := state.canonical_values()
			var mask := masks.archive_reaction_mask(state, Chemistry.recipe(wire), 47, config)
			check(not mask.is_empty(), "wire %d builds a geometry mask" % wire)
			equal(state.canonical_values(), before, "mask generation never mutates authoritative state")
			var bounds: Rect2 = mask.bounds
			for y: int in range(13):
				for x: int in range(13):
					var point := bounds.position + bounds.size * Vector2((float(x) + 0.37) / 13.0, (float(y) + 0.61) / 13.0)
					var expected := Chemistry.contains(state, Vector2i((point * 1000.0).round()), 47, config)
					var actual := Mask.contains_point(mask.polygons, point)
					check(actual == expected or _boundary_distance(mask.boundaries, point) <= 1.0, "wire %d occupancy agrees with simulation within one world pixel at %s" % [wire, point])
			check(not (mask.boundaries as Array).is_empty(), "occupied wire %d exposes external boundaries" % wire)
			for loop: PackedVector2Array in mask.boundaries:
				equal(loop[0], loop[loop.size() - 1], "every boundary is explicitly closed")
				check(loop.size() >= 4, "boundary has at least three distinct points")
	check(masks.archive_reaction_mask(null, {}, 20, config).is_empty(), "missing state fails closed")
	var state := _state(303)
	check(masks.archive_reaction_mask(state, Chemistry.recipe(301), 20, config).is_empty(), "mismatched recipe fails closed")
	check(masks.archive_reaction_mask(state, Chemistry.recipe(303), 9, config).is_empty(), "unborn masks are hidden")
	check(masks.archive_reaction_mask(state, Chemistry.recipe(303), 380, config).is_empty(), "expired masks disappear immediately")
	for radius: float in [1.0, 8.0, 24.0, 72.0, 100.0]:
		var polygon := Mask.circle_polygon(Vector2.ZERO, radius)
		for index: int in range(polygon.size()):
			var middle := (polygon[index] + polygon[(index + 1) % polygon.size()]) * 0.5
			check(radius - middle.length() <= 0.21, "circle chord error stays below the one-pixel requirement")


func _test_safe_holes_and_paths() -> void:
	var masks := Mask.new()
	var config := SimConfig.new()
	for wire: int in [309, 322]:
		var state := _state(wire)
		var mask := masks.archive_reaction_mask(state, Chemistry.recipe(wire), 20, config)
		equal((mask.boundaries as Array).size(), 2, "ring exposes outer and inner edges without wedge seams")
		check(not Mask.contains_point(mask.polygons, Vector2(500, 500)), "ring safe centre is never filled")
		check(Mask.contains_point(mask.polygons, Vector2(540, 500)), "ring occupied band retains material")
	for wire: int in [313, 319, 328]:
		var state := _state(wire)
		var mask := masks.archive_reaction_mask(state, Chemistry.recipe(wire), 20, config)
		equal(Mask.contains_point(mask.polygons, Vector2(500, 500)), wire == 319, "only unlinked Water retains its real disk")
		state.path_points = PackedInt64Array([500000, 500000, 560000, 500000, 560000, 560000])
		mask = masks.archive_reaction_mask(state, Chemistry.recipe(wire), 20, config)
		check(Mask.contains_point(mask.polygons, Vector2(560, 530)), "linked path follows actual bent point list")
		equal((mask.boundaries as Array).size(), 1, "connected path union has no internal join boundary")
		var centre_count := 0
		for piece: PackedVector2Array in mask.polygons:
			if Geometry2D.is_point_in_polygon(Vector2(559.125, 501.625), piece): centre_count += 1
		equal(centre_count, 1, "overlapping path caps do not double-stamp material")
	var hail := _state(323)
	# Deliberately non-collinear endpoint proves pulse position does not use a
	# visual endpoint lerp: the simulation advances by direction * length.
	hail.endpoint_y += 20000
	var hail_mask := masks.archive_reaction_mask(hail, Chemistry.recipe(323), 47, config)
	var pulse_x := 500.0 + float(hail.length) / 2000.0
	equal(hail_mask.hail_position, Vector2(pulse_x, 500), "one Hail pulse uses exact source direction and integer clock")
	check(not Mask.contains_point(hail_mask.polygons, Vector2(520, 500)), "Hail warning lane is not falsely occupied behind the pulse")
	var outside_lane := Vector2(pulse_x, 530)
	check(outside_lane.distance_to(hail_mask.hail_position) < float(Chemistry.extent(25000)) / 1000.0, "lane exclusion probe is inside the enlarged pulse disk")
	check(not Chemistry.contains(hail, Vector2i(outside_lane * 1000), 47, config) and not Mask.contains_point(hail_mask.polygons, outside_lane), "Hail pulse remains intersected with real noncollinear lane width")
	var cover := _state(307, Vector2i(707, 707))
	var cover_mask := masks.archive_reaction_mask(cover, Chemistry.recipe(307), 20, config)
	check(Mask.contains_point(cover_mask.polygons, Vector2(480, 520)), "optical cover lies perpendicular to direction")
	check(not Mask.contains_point(cover_mask.polygons, Vector2(520, 520)), "optical cover does not invent outgoing rays")


func _test_worldbone_and_cache() -> void:
	var config := SimConfig.new()
	var masks := Mask.new()
	var collision := CollisionWorld.new(1000000, 1000000)
	collision.add_obstacle(CollisionWorld.Obstacle.new(1, 520000, 480000, 528000, 520000))
	collision.add_obstacle(CollisionWorld.Obstacle.new(2, 900000, 900000, 910000, 910000))
	var state := _state(309)
	var mask := masks.archive_reaction_mask(state, Chemistry.recipe(309), 20, config, collision)
	check(not Mask.contains_point(mask.polygons, Vector2(550, 500)), "worldbone shadow removes material beyond the obstacle")
	check(not Mask.contains_point(mask.polygons, Vector2(524, 510)), "obstacle footprint cannot contain material")
	check(Mask.contains_point(mask.polygons, Vector2(460, 500)), "unoccluded ring remains visible")
	check(not Mask.contains_point(mask.polygons, Vector2(500, 500)), "clipped ring never fills its safe hole")
	equal(int(masks.stats().relevant_colliders), 1, "far colliders are excluded before polygon work")
	check(not collision.get("_obstacle_array_exposed"), "rendering uses read-only obstacle view without disabling broadphase")
	var before := int(masks.stats().builds)
	masks.archive_reaction_mask(state, Chemistry.recipe(309), 21, config, collision)
	equal(int(masks.stats().builds), before, "ordinary animation ticks reuse static geometry mask")
	equal(int(masks.stats().cache_hits), 1, "cache reuse is measurable")
	(collision.obstacle_view()[0] as CollisionWorld.Obstacle).minimum_x = 518000
	masks.archive_reaction_mask(state, Chemistry.recipe(309), 21, config, collision)
	equal(int(masks.stats().builds), before + 1, "obstacle geometry changes invalidate cached clipping")
	var disk := _state(303)
	var disk_mask := masks.archive_reaction_mask(disk, Chemistry.recipe(303), 21, config, collision)
	for y: int in range(25):
		for x: int in range(25):
			var point := Vector2(436.25 + float(x) * 5.1, 436.625 + float(y) * 5.1)
			var fixed_point := Vector2i((point * 1000.0).round())
			var expected := Chemistry.contains(disk, fixed_point, 21, config) and Chemistry.clear_line(Vector2i(500000, 500000), fixed_point, collision)
			check(expected == Mask.contains_point(disk_mask.polygons, point) or _boundary_distance(disk_mask.boundaries, point) <= 1.0, "wall-clipped disk agrees with actual line-of-sight occupancy within one pixel")
	check(not (disk_mask.boundaries as Array).is_empty(), "worldbone clipping retains closed occupied boundary loops")
	var deposit_mask := masks.disk_mask(Vector2(500, 500), 62.0, collision)
	for point: Vector2 in [Vector2(550, 500), Vector2(500, 500), Vector2(460, 500), Vector2(520, 510), Vector2(500, 550)]:
		equal(Mask.contains_point(deposit_mask.polygons, point), Mask.contains_point(disk_mask.polygons, point), "deposit disk reuses real disk geometry and worldbone without fabricated reaction state")
	var disk_builds := int(masks.stats().builds)
	masks.disk_mask(Vector2(500, 500), 62.0, collision)
	equal(int(masks.stats().builds), disk_builds, "deposit disks share the bounded geometry cache")
	check(masks.disk_mask(Vector2(INF, 0), 10.0).is_empty(), "nonfinite deposit position fails closed")
	check(masks.disk_mask(Vector2.ZERO, 0.0).is_empty(), "empty deposit radius fails closed")
	var spell_disk := masks.clip_spell_mask([Mask.circle_polygon(Vector2(500, 500), 62.0)], Vector2(500, 500), Rect2(438, 438, 124, 124), collision)
	equal(spell_disk.polygons, deposit_mask.polygons, "generic spell clipping reuses identical worldbone and disk geometry")
	check(masks.clip_spell_mask([], Vector2.ZERO, Rect2()).is_empty(), "empty generic spell geometry fails closed")
	var gap_world := CollisionWorld.new(1000000, 1000000)
	gap_world.add_obstacle(CollisionWorld.Obstacle.new(11, 400000, 450000, 493000, 470000))
	gap_world.add_obstacle(CollisionWorld.Obstacle.new(12, 507000, 450000, 600000, 470000))
	var cone := PackedVector2Array([Vector2(500, 400), Vector2(600, 600), Vector2(400, 600)])
	var thin := masks.clip_spell_mask([cone], Vector2(500, 400), Rect2(400, 400, 200, 200), gap_world)
	var thick := masks.clip_spell_mask([cone], Vector2(500, 400), Rect2(400, 400, 200, 200), gap_world, 9.0)
	check(Mask.contains_point(thin.polygons, Vector2(500, 550)), "zero-width sight ray fits through a14px gap")
	check(not Mask.contains_point(thick.polygons, Vector2(500, 550)), "9px spray half-width cannot falsely pass a14px gap")
	disk.position_x = 20000
	var edge_mask := masks.archive_reaction_mask(disk, Chemistry.recipe(303), 21, config, collision)
	check(not Mask.contains_point(edge_mask.polygons, Vector2(-10, 500)), "material does not extend beyond the authoritative world envelope")
	for index: int in range(140):
		state.position_y = 500000 + index * 100
		masks.archive_reaction_mask(state, Chemistry.recipe(309), 21, config)
	equal(int(masks.stats().cache_entries), Mask.CACHE_LIMIT, "mask cache cannot grow beyond128 entries")
	masks.clear_cache()
	equal(int(masks.stats().cache_entries), 0, "restart can reset all visual masks")


func _test_texture_clipping() -> void:
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var frame := {"texture": texture, "region": Rect2(32, 48, 32, 32), "pivot": Vector2(16, 16)}
	var polygon := Mask.rectangle_polygon(Rect2(500, 500, 8, 12))
	var parts := Mask.clipped_frame_parts(frame, Vector2(500, 500), [polygon])
	equal(parts.size(), 1, "texture stamp is intersected rather than painted over the mask")
	for part: Dictionary in parts:
		for index: int in range((part.points as PackedVector2Array).size()):
			var point: Vector2 = part.points[index]
			var uv: Vector2 = part.uvs[index]
			check(point.x >= 500 and point.x <= 508 and point.y >= 500 and point.y <= 512, "clipped raster stays inside occupied rectangle")
			equal(uv, (Vector2(32, 48) + point - Vector2(484, 484)) / 128.0, "UVs preserve actual atlas region and pivot without stretch")
	check(Mask.clipped_frame_parts({}, Vector2.ZERO, [polygon]).is_empty(), "invalid sprite frame fails closed")
	equal(Mask.draw_clipped_frame(null, frame, Vector2.ZERO, [polygon]), 0, "missing draw surface cannot create geometry side effects")
	var rotation := 0.713
	var rotated_parts := Mask.clipped_frame_parts(frame, Vector2(500, 500), [polygon], rotation)
	check(not rotated_parts.is_empty(), "continuous-angle sprite basis is clipped in world space")
	for part: Dictionary in rotated_parts:
		for index: int in range((part.points as PackedVector2Array).size()):
			var point: Vector2 = part.points[index]
			var uv: Vector2 = part.uvs[index]
			check(uv.is_equal_approx((Vector2(32, 48) + (point - Vector2(500, 500)).rotated(-rotation) + Vector2(16, 16)) / 128.0), "rotated sampling preserves continuous aim without changing mask geometry")


func _boundary_distance(loops: Array, point: Vector2) -> float:
	var closest := INF
	for loop: PackedVector2Array in loops:
		for index: int in range(loop.size() - 1):
			closest = minf(closest, point.distance_to(Geometry2D.get_closest_point_to_segment(point, loop[index], loop[index + 1])))
	return closest
