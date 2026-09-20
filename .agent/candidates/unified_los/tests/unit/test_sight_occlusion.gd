extends FluxTestSuite


func run() -> int:
	_test_right_facing_shadow()
	_test_left_facing_shadow()
	_test_convex_hex_shadow()
	_test_invalid_shadow_inputs()
	_test_viewport_cover_radius()
	_test_projected_ground_geometry()
	_test_rear_awareness_and_opaque_lines()
	return finish("sight-occlusion")


func _test_right_facing_shadow() -> void:
	var shadow := SightOcclusion.shadow_polygon(Vector2.ZERO, Rect2(100, -20, 40, 40), 1000.0)
	equal(shadow.size(), 4, "right-side building produces one bounded shadow quad")
	var boundary := Rect2(100, -20, 40, 40).grow(0.1)
	check(boundary.has_point(shadow[0]), "first tangent belongs to the building boundary")
	check(boundary.has_point(shadow[3]), "second tangent belongs to the building boundary")
	check(shadow[1].x > shadow[0].x and shadow[2].x > shadow[3].x, "right-side shadow projects away from the viewer")
	check(is_equal_approx(shadow[1].length(), 1000.0), "first shadow ray reaches the bounded outer distance")
	check(is_equal_approx(shadow[2].length(), 1000.0), "second shadow ray reaches the bounded outer distance")


func _test_left_facing_shadow() -> void:
	var shadow := SightOcclusion.shadow_polygon(Vector2(300, 100), Rect2(100, 80, 40, 40), 800.0)
	equal(shadow.size(), 4, "left-side building produces one bounded shadow quad")
	check(shadow[1].x < shadow[0].x and shadow[2].x < shadow[3].x, "left-side shadow projects away from the viewer")


func _test_convex_hex_shadow() -> void:
	var center := Vector2(120, 0)
	var hex := PackedVector2Array()
	for local: Vector2i in HexGrid.LOCAL_VERTICES:
		hex.append(center + Vector2(local) / 1000.0)
	var shadow := SightOcclusion.shadow_convex_polygon(Vector2.ZERO, hex, 900.0)
	equal(shadow.size(), 4, "one six-face pillar produces one bounded tangent shadow")
	if shadow.size() != 4:
		return
	check(hex.find(shadow[0]) >= 0 and hex.find(shadow[3]) >= 0, "both near shadow tangents are actual Hex vertices")
	check(shadow[0] not in [Vector2(88, -36.95), Vector2(152, -36.95), Vector2(152, 36.95), Vector2(88, 36.95)] and shadow[3] not in [Vector2(88, -36.95), Vector2(152, -36.95), Vector2(152, 36.95), Vector2(88, 36.95)], "shadow never substitutes empty AABB corners")
	check(is_equal_approx(shadow[1].length(), 900.0) and is_equal_approx(shadow[2].length(), 900.0), "both Hex silhouette rays reach the bounded outer distance")
	var offset := Vector2(-310, 220)
	var translated := PackedVector2Array()
	for point: Vector2 in hex:
		translated.append(point + offset)
	var translated_shadow := SightOcclusion.shadow_convex_polygon(offset, translated, 900.0)
	equal(translated_shadow.size(), 4, "translated Hex retains a valid shadow")
	for index: int in range(mini(shadow.size(), translated_shadow.size())):
		check((translated_shadow[index] - offset).is_equal_approx(shadow[index]), "convex shadow translation preserves exact silhouette geometry")
	equal(SightOcclusion.shadow_convex_polygon(center, hex, 900.0).size(), 0, "observer inside pillar produces no invalid shadow")
	var face_midpoint := (hex[1] + hex[2]) * 0.5
	equal(SightOcclusion.shadow_convex_polygon(face_midpoint, hex, 900.0).size(), 0, "observer on an opaque face produces no zero-length shadow ray")


func _test_invalid_shadow_inputs() -> void:
	equal(SightOcclusion.shadow_polygon(Vector2(10, 10), Rect2(0, 0, 20, 20), 500.0).size(), 0, "viewer inside building produces no invalid polygon")
	equal(SightOcclusion.shadow_polygon(Vector2.ZERO, Rect2(20, 20, 0, 10), 500.0).size(), 0, "empty building produces no shadow")
	equal(SightOcclusion.shadow_polygon(Vector2.ZERO, Rect2(20, 20, 10, 10), 0.0).size(), 0, "non-positive range produces no shadow")
	equal(SightOcclusion.shadow_convex_polygon(Vector2.ZERO, PackedVector2Array([Vector2(20, 20), Vector2(30, 30)]), 500.0).size(), 0, "fewer than three convex points fail closed")
	equal(SightOcclusion.shadow_convex_polygon(Vector2.ZERO, PackedVector2Array([Vector2(20, 20), Vector2(30, 30), Vector2(40, 40)]), 500.0).size(), 0, "zero-area polygon fails closed")
	equal(SightOcclusion.shadow_convex_polygon(Vector2.ZERO, PackedVector2Array([Vector2(20, 20), Vector2(40, 20), Vector2(30, 25), Vector2(40, 40), Vector2(20, 40)]), 500.0).size(), 0, "non-convex polygon fails closed")
	equal(SightOcclusion.shadow_convex_polygon(Vector2.ZERO, PackedVector2Array([Vector2(20, 20), Vector2(NAN, 30), Vector2(20, 40)]), 500.0).size(), 0, "nonfinite polygon vertex fails closed")
	equal(SightOcclusion.shadow_convex_polygon(Vector2.ZERO, PackedVector2Array([Vector2(20, 20), Vector2(40, 20), Vector2(30, 40)]), INF).size(), 0, "nonfinite outer distance fails closed")


func _test_viewport_cover_radius() -> void:
	var viewport := Rect2(0, 0, 1280, 720)
	var center := viewport.get_center()
	var centered_radius := SightOcclusion.viewport_cover_radius(center, viewport)
	check(centered_radius > center.length(), "mask outer edges cover the viewport corners")
	check(centered_radius < 740.0, "centered mask remains viewport-bounded")
	for origin: Vector2 in [center, Vector2.ZERO, Vector2(-1500, 240), Vector2(1920, 1080)]:
		for segments: int in [3, 24, 96]:
			var radius := SightOcclusion.viewport_cover_radius(origin, viewport, segments)
			var inset_radius := radius * cos(PI / float(segments))
			for corner: Vector2 in [viewport.position, Vector2(viewport.end.x, viewport.position.y), viewport.end, Vector2(viewport.position.x, viewport.end.y)]:
				check(inset_radius > origin.distance_to(corner), "polygon edge covers corner for origin %s and %d segments" % [origin, segments])
	check(720.0 * 0.75 < centered_radius, "ordinary sight range still needs its outer mask")
	check(4096.0 * 0.75 > centered_radius, "screen-covering sight range can skip all outer mask quads")
	equal(SightOcclusion.viewport_cover_radius(center, viewport, 0), SightOcclusion.viewport_cover_radius(center, viewport, 3), "degenerate segment count clamps to a valid polygon")
	for size: Vector2 in [Vector2(2560, 720), Vector2(720, 1280), Vector2(3840, 2160)]:
		var screen := Rect2(Vector2(30, -20), size)
		var radius := SightOcclusion.viewport_cover_radius(screen.get_center(), screen)
		check(radius * cos(PI / 96.0) > size.length() * 0.5, "translated wide/tall/4K viewport corners remain covered")
		for zoom: float in [0.5, 0.75, 1.0]:
			var sight_range := 4096.0 * zoom
			if sight_range >= radius:
				check(sight_range * cos(PI / 96.0) > size.length() * 0.5, "skipped annulus cannot intersect the screen at zoom %s" % zoom)
			else:
				check(radius > sight_range, "retained annulus never reverses radii at zoom %s" % zoom)


func _test_projected_ground_geometry() -> void:
	var clear: Array[Rect2] = []
	for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		var aim := Vector2(direction).normalized()
		var angle := SightOcclusion.ground_aim_angle(aim)
		var projected := SightOcclusion.project_ground(Vector2.from_angle(angle)).normalized()
		check(projected.is_equal_approx(aim), "projected cone axis exactly follows each screen-cardinal cursor direction")
		var point := Vector2(direction) * 0.7
		check(SightOcclusion.project_ground(SightOcclusion.inverse_project_ground(point)).is_equal_approx(point), "aim and hit positions use inverse-consistent ground projection")
		for width: float in [15.0, 120.0, 360.0]:
			var front := SightOcclusion.project_ground(Vector2.from_angle(angle) * 160.0)
			check(SightOcclusion.point_visible(Vector2.ZERO, front, aim, width, 200.0, clear), "front ray remains visible for every legal angle edge")
			var rear := SightOcclusion.project_ground(Vector2.from_angle(angle + PI) * 71.0)
			check(SightOcclusion.point_visible(Vector2.ZERO, rear, aim, width, 200.0, clear), "near rear awareness is omnidirectional for all eight headings")
			var beyond_rear := SightOcclusion.project_ground(Vector2.from_angle(angle + PI) * 74.0)
			equal(SightOcclusion.point_visible(Vector2.ZERO, beyond_rear, aim, width, 200.0, clear), width == 360.0, "rear awareness ends at its small ground radius")
			if width < 360.0:
				var edge_angle := angle + deg_to_rad(width) * 0.5
				check(SightOcclusion.point_visible(Vector2.ZERO, SightOcclusion.project_ground(Vector2.from_angle(edge_angle) * 160.0), aim, width, 200.0, clear), "cone includes its exact projected angular boundary")
				check(not SightOcclusion.point_visible(Vector2.ZERO, SightOcclusion.project_ground(Vector2.from_angle(edge_angle + 0.01) * 160.0), aim, width, 200.0, clear), "cone excludes points just outside its projected angular boundary")
		for zoom: float in [0.5, 0.75, 1.0]:
			var origin := Vector2(400, 280)
			var quad := SightOcclusion.projected_mask_quad(origin, 72.0 * zoom, 300.0 * zoom, angle, angle + 0.1)
			check(is_equal_approx(SightOcclusion.inverse_project_ground(quad[0] - origin).length(), 72.0 * zoom), "mask opening shares the predicate's projected ground metric at every camera zoom")
	var rear_y := SightOcclusion.project_ground(Vector2(0, 72))
	check(rear_y.y > 58.9 and rear_y.y < 59.1, "72 ground pixels project to the calibrated roughly59px vertical rear reach")
	for size: Vector2 in [Vector2(1280, 720), Vector2(2560, 720), Vector2(720, 1280), Vector2(3840, 2160)]:
		var viewport := Rect2(Vector2.ZERO, size)
		var radius := SightOcclusion.projected_viewport_cover_radius(viewport.get_center(), viewport)
		var ground_corner := SightOcclusion.inverse_project_ground(size * 0.5)
		check(radius * cos(PI / 96.0) > ground_corner.length(), "projected outer polygon covers widescreen/portrait/4K corners")


func _test_rear_awareness_and_opaque_lines() -> void:
	var opaque: Array[Rect2] = [Rect2(-45, -10, 10, 20)]
	check(not SightOcclusion.point_visible(Vector2.ZERO, Vector2(-70, 0), Vector2.RIGHT, 15, 720, opaque), "near rear awareness never bypasses an opaque wall")
	check(not SightOcclusion.point_visible(Vector2.ZERO, Vector2(-70, 0), Vector2.RIGHT, 360, 720, opaque), "360-degree cone still respects opaque walls")
	check(SightOcclusion.point_visible(Vector2.ZERO, Vector2(-30, 0), Vector2.RIGHT, 15, 720, opaque), "near side of an opaque rear wall stays visible")
	check(SightOcclusion.line_clear(Vector2.ZERO, Vector2(-70, 40), opaque), "ray passing clear of the real rectangle remains visible")
	check(not SightOcclusion.line_clear(Vector2.ZERO, Vector2(-40, 0), opaque), "target inside opaque geometry is never revealed")
	check(not SightOcclusion.line_clear(Vector2(-40, 0), Vector2.ZERO, opaque), "invalid observer inside opaque geometry fails closed")
	var clear: Array[Rect2] = []
	check(not SightOcclusion.point_visible(Vector2.ZERO, Vector2(201, 0), Vector2.RIGHT, 360, 200, clear), "full-angle view still obeys finite range")
	check(not SightOcclusion.point_visible(Vector2.ZERO, Vector2(NAN, 0), Vector2.RIGHT, 120, 200, clear), "nonfinite target fails closed")
	check(SightOcclusion.point_visible(Vector2.ZERO, Vector2(120, 0), Vector2.ZERO, 15, 200, clear), "zero vector fallback is deterministic and shared with mask angle")
