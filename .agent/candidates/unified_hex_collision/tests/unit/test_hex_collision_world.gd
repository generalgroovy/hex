extends FluxTestSuite
@warning_ignore_start("integer_division")

const Geometry = preload("res://src/sim/hex/hex_convex_geometry.gd")
const HexWorld = preload("res://src/sim/hex/hex_collision_world.gd")

func run() -> int:
	_six_faces()
	_corner_and_clearance()
	_composite_and_escape()
	return finish("hex-collision-world")

func _six_faces() -> void:
	for origin: Vector2i in [Vector2i.ZERO, Vector2i(-300_000, -210_000), Vector2i(1_500_000, 1_300_000)]:
		var points := Geometry.polygon(Vector2i.ZERO, origin)
		for face: int in 6:
			var midpoint := Vector2i((points[face].x + points[(face + 1) % 6].x) / 2, (points[face].y + points[(face + 1) % 6].y) / 2)
			var normal: Vector2i = Geometry.NORMALS[face]
			var outside := midpoint + normal * 100
			var inside := midpoint - normal * 100
			var circle_hit := Geometry.sweep_circle(outside, inside, 5000, Vector2i.ZERO, origin)
			check(not circle_hit.is_empty(), "fast circular projectile contacts each actual hex face")
			if circle_hit.is_empty(): continue
			equal(int(circle_hit.face), face, "circle hit reports canonical face")
			equal(circle_hit.normal, normal, "circle hit reports shared normalized face normal")
			check((circle_hit.point - midpoint).length_squared() <= 4, "physical impact remains on exact face at translated coordinates")
			var box_hit := Geometry.sweep_box(outside, inside, 18_000, Vector2i.ZERO, origin)
			check(not box_hit.is_empty(), "common square wall clearance hits each hex face continuously")
			if box_hit.is_empty(): continue
			equal(int(box_hit.face), face, "square sweep preserves physical hex face identity")
			var contact_point: Vector2i = box_hit.center
			var probe := contact_point + Vector2i(signi(normal.x), signi(normal.y)) * 2
			check(not Geometry.box_overlaps(probe, 18_000, Vector2i.ZERO, origin), "conservative contact side is clear")
			check(Geometry.box_overlaps(contact_point - Vector2i(signi(normal.x), signi(normal.y)) * 2, 18_000, Vector2i.ZERO, origin), "other side of square contact plane is blocked")
			var nearby := Geometry.nearby_face(probe, 18_000, 4, Vector2i.ZERO, origin, face)
			check(not nearby.is_empty(), "each real face is available for wall attachment")

func _corner_and_clearance() -> void:
	check(not Geometry.box_overlaps(Vector2i(30_000, -34_000), 0, Vector2i.ZERO, Vector2i.ZERO), "empty corner of bounding rectangle is traversable")
	check(Geometry.sweep_circle(Vector2i(30_000, -34_000), Vector2i(31_000, -34_000), 1000, Vector2i.ZERO, Vector2i.ZERO).is_empty(), "projectile passes empty rectangle corner")
	check(not Geometry.box_overlaps(Vector2i(0, -54_950), 18_000, Vector2i.ZERO, Vector2i.ZERO), "square bottom face tangency at hex top is clear")
	check(Geometry.box_overlaps(Vector2i(0, -54_949), 18_000, Vector2i.ZERO, Vector2i.ZERO), "one fixed unit penetration at hex tip is blocked")
	check(Geometry.sweep_box(Vector2i(50_000, 0), Vector2i(50_000, 10_000), 18_000, Vector2i.ZERO, Vector2i.ZERO).is_empty(), "square may slide exactly along the vertical face")
	check(Geometry.sweep_box(Vector2i(50_000, 0), Vector2i(60_000, 0), 18_000, Vector2i.ZERO, Vector2i.ZERO).is_empty(), "square separates from exact contact")
	check(not Geometry.sweep_box(Vector2i(50_000, 0), Vector2i(49_999, 0), 18_000, Vector2i.ZERO, Vector2i.ZERO).is_empty(), "inward motion from exact face is blocked")
	check(Geometry.sweep_box(Vector2i(60_000, 0), Vector2i(50_000, 0), 18_000, Vector2i.ZERO, Vector2i.ZERO).is_empty(), "ending at exact tangency does not report positive movement collision")
	var overlap := Geometry.sweep_circle(Vector2i(34_000, 0), Vector2i(35_000, 0), 5000, Vector2i.ZERO, Vector2i.ZERO)
	check(not overlap.is_empty() and float(overlap.fraction) == 0.0, "initial strict face overlap is a projectile contact even when separating")
	var tangent := Geometry.tangent(Vector2i(50_000, 60_000), Vector2i(500, -866))
	check(tangent != Vector2i.ZERO, "oblique contact retains tangent movement")
	check(absi(tangent.x * 500 - tangent.y * 866) <= 1400, "integer tangent projection has bounded final rounding")

func _composite_and_escape() -> void:
	var base := CollisionWorld.new(2_000_000, 2_000_000)
	var world := HexWorld.new(base)
	var origin := Vector2i(1_000_000, 1_000_000)
	var topology := HexGrid.disk(Vector2i.ZERO, 3)
	check(world.configure_hexes(origin, topology, [Vector2i.ZERO, Vector2i(1, 0)]), "adjacent pillars configure in trusted topology")
	equal(world._faces.size(), 10, "adjacent cells omit their two hidden internal faces")
	check(not world.can_occupy(origin, 18_000), "solid center blocks ordinary admission")
	world.begin_actor(origin, 18_000)
	var escaped := world.move_box(origin, Vector2i(160_000, 0), 18_000)
	equal(escaped.position, origin + Vector2i(160_000, 0), "actor beneath newly formed connected pillars can escape through entire component")
	world.begin_actor(escaped.position, 18_000)
	var blocked := world.move_box(escaped.position, Vector2i(-300_000, 0), 18_000)
	equal(blocked.position.x, origin.x + 114_000, "once clear the same component prevents reentry with common18px clearance")
	check(blocked.wall_id >= HexWorld.FACE_ID_BASE, "physical collision supplies stable face ID")
	var id := blocked.wall_id
	check(world.has_live_surface(id), "exposed collided face remains live")
	check(not world.hex_segment_clear(origin + Vector2i(-100_000, 0), origin + Vector2i(200_000, 0)), "pillars block a continuous sight and Spray segment")
	var flight := world.hex_wall_contact(origin + Vector2i(-100_000, 0), origin + Vector2i(200_000, 0), 5000)
	check(not flight.is_empty(), "pillars stop swept projectile")
	equal(flight.point.x, origin.x - 32_000, "projectile physical point is actual hex edge")
	check(world.configure_hexes(origin, topology, []), "expiry clears authority-derived geometry")
	check(not world.has_live_surface(id), "expiry removes attached face identity")
	check(world.can_occupy(origin, 18_000), "expiry leaves no invisible collision")
	check(world.hex_segment_clear(origin + Vector2i(-100_000, 0), origin + Vector2i(200_000, 0)), "expiry removes sight obstruction")
	equal(base.obstacle_view().size(), 0, "temporary geometry never mutates immutable worldbone")
	check(world.configure_hexes(origin, topology, [Vector2i(-1, 0), Vector2i(1, 0)]), "two pillars retain real open gap")
	check(world.can_occupy(origin, 18_000), "64px physical gap fits common36px body clearance")
	world.begin_actor(origin + Vector2i(0, -120_000), 18_000)
	equal(world.move_box(origin + Vector2i(0, -120_000), Vector2i(0, 240_000), 18_000).position, origin + Vector2i(0, 120_000), "continuous traversal through a real gap is not blocked by rectangular substitutes")
