extends FluxTestSuite


const EAST := Vector2i(1000, 0)
const COS_SQUARED_30 := 750_000
const RATIONAL_WEDGE_THRESHOLD := 800_000


func run() -> int:
	_test_point_sector_matches_independent_rational_wedge()
	_test_radial_and_origin_tangency()
	_test_full_circle_side_overlap()
	_test_signed_translation_and_rotation()
	_test_exact_segment_queries()
	_test_contact_metadata_and_bounds()
	return finish("spray-contact-geometry")


func _test_point_sector_matches_independent_rational_wedge() -> void:
	# At threshold 4/5 with east aim, the cone is exactly x >= 0 and
	# x^2 >= 4*y^2. This oracle does not reuse the implementation's surd path.
	for x: int in range(-24, 25):
		for y: int in range(-24, 25):
			var point := Vector2i(x, y)
			var expected := x * x + y * y <= 400 and (point == Vector2i.ZERO or (x >= 0 and x * x >= 4 * y * y))
			equal(SprayContactGeometry.sector_intersects_circle(Vector2i.ZERO, EAST, 20, RATIONAL_WEDGE_THRESHOLD, point, 0), expected, "zero-radius point matches exact rational wedge")
	check(SprayContactGeometry.sector_intersects_circle(Vector2i.ZERO, EAST, 1000, RATIONAL_WEDGE_THRESHOLD, Vector2i(200, 100), 0), "exact cone-side point is included")
	check(not SprayContactGeometry.sector_intersects_circle(Vector2i.ZERO, EAST, 1000, RATIONAL_WEDGE_THRESHOLD, Vector2i(200, 101), 0), "one-unit point outside cone is excluded")


func _test_radial_and_origin_tangency() -> void:
	check(SprayContactGeometry.sector_intersects_circle(Vector2i.ZERO, EAST, 380_000, 820_000, Vector2i(389_000, 0), 9_000), "full projectile radius retains radial-cap tangency")
	check(not SprayContactGeometry.sector_intersects_circle(Vector2i.ZERO, EAST, 380_000, 820_000, Vector2i(389_001, 0), 9_000), "one unit beyond radial tangency misses")
	check(SprayContactGeometry.sector_intersects_circle(Vector2i.ZERO, EAST, 380_000, 820_000, Vector2i(-9_000, 0), 9_000), "circle tangent at Spray origin overlaps")
	check(not SprayContactGeometry.sector_intersects_circle(Vector2i.ZERO, EAST, 380_000, 820_000, Vector2i(-9_001, 0), 9_000), "behind-origin gap misses")


func _test_full_circle_side_overlap() -> void:
	# The 4/5 cone boundary is y=x/2. A center with |x-2y|=2 is less
	# than one unit from the line (2/sqrt(5)); a difference of4 is farther.
	check(SprayContactGeometry.sector_intersects_circle(Vector2i.ZERO, EAST, 900_000, RATIONAL_WEDGE_THRESHOLD, Vector2i(800_000, 400_001), 1), "sub-unit thin side overlap is retained")
	check(not SprayContactGeometry.sector_intersects_circle(Vector2i.ZERO, EAST, 900_000, RATIONAL_WEDGE_THRESHOLD, Vector2i(800_000, 400_002), 1), "one-unit circle with greater-than-one side gap misses")
	check(SprayContactGeometry.sector_intersects_circle(Vector2i.ZERO, EAST, 1_000_000, COS_SQUARED_30, Vector2i(800_000, 461_881), 1), "irrational thirty-degree boundary retains thin continuous overlap")


func _test_signed_translation_and_rotation() -> void:
	var center := Vector2i(-99_000_000, 98_000_000)
	check(SprayContactGeometry.sector_intersects_circle(center, Vector2i(0, -1000), 380_000, 820_000, center + Vector2i(0, -389_000), 9_000), "signed near-limit south radial tangency")
	check(not SprayContactGeometry.sector_intersects_circle(center, Vector2i(0, -1000), 380_000, 820_000, center + Vector2i(0, 20_000), 9_000), "rotated behind-sector circle misses")
	var diagonal := SimCommand._normalized_direction(1, 1)
	check(SprayContactGeometry.sector_intersects_circle(Vector2i(-500_000, -500_000), diagonal, 380_000, 750_000, Vector2i(-250_000, -250_000), 0), "normalized diagonal aim contains its axis")


func _test_exact_segment_queries() -> void:
	check(SprayContactGeometry.segment_intersects_circle(Vector2i(-10, 3), Vector2i(10, 3), Vector2i.ZERO, 3), "segment-circle side tangency is included")
	check(not SprayContactGeometry.segment_intersects_circle(Vector2i(-10, 4), Vector2i(10, 4), Vector2i.ZERO, 3), "one-unit segment-circle gap misses")
	check(SprayContactGeometry.segment_intersects_circle(Vector2i(-100_000_000, -100_000_000), Vector2i(100_000_000, 100_000_000), Vector2i(99_999_999, 100_000_000), 1), "wide cross-product comparison retains signed near-limit tangency")
	check(SprayContactGeometry.segment_intersects_aabb(Vector2i(-10, 0), Vector2i(10, 0), Vector2i(10, 0), Vector2i(20, 20)), "segment-AABB corner tangency is included")
	check(SprayContactGeometry.segment_intersects_aabb(Vector2i(-10, 1), Vector2i(10, 1), Vector2i(-1, 1), Vector2i(1, 1)), "zero-height thin AABB is intersected exactly")
	check(not SprayContactGeometry.segment_intersects_aabb(Vector2i(-10, 0), Vector2i(9, 0), Vector2i(10, 0), Vector2i(20, 20)), "one-unit AABB gap misses")


func _test_contact_metadata_and_bounds() -> void:
	var direct := SprayContactGeometry.sector_circle_contact(Vector2i.ZERO, EAST, 380_000, 820_000, Vector2i(100_000, 0), 9_000)
	check(direct.overlaps and direct.point_available and direct.point == Vector2i(100_000, 0), "interior circle center is an exact integer witness")
	var tangent := SprayContactGeometry.sector_circle_contact(Vector2i.ZERO, EAST, 380_000, 820_000, Vector2i(389_000, 0), 9_000)
	check(tangent.overlaps and not tangent.point_available and tangent.kind == "radial_cap", "irrational-cap-capable contact does not fabricate an integer witness")
	check(not SprayContactGeometry.sector_intersects_circle(Vector2i.ZERO, Vector2i.ZERO, 380_000, 820_000, Vector2i.ZERO, 0), "zero aim fails closed")
	check(not SprayContactGeometry.sector_intersects_circle(Vector2i.ZERO, EAST, SprayContactGeometry.MAX_RANGE + 1, 820_000, Vector2i.ZERO, 0), "unproved range fails closed")
	check(not SprayContactGeometry.sector_intersects_circle(Vector2i.ZERO, EAST, 380_000, 820_000, Vector2i.ZERO, SprayContactGeometry.MAX_CIRCLE_RADIUS + 1), "unproved projectile radius fails closed")
