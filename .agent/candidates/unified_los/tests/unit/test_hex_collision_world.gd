extends FluxTestSuite
@warning_ignore_start("integer_division")

const Geometry = preload("res://src/sim/hex/hex_convex_geometry.gd")
const HexWorld = preload("res://src/sim/hex/hex_collision_world.gd")

func run() -> int:
	_six_faces()
	_corner_and_clearance()
	_composite_and_escape()
	_movement_contacts()
	_composite_regressions()
	_pillar_los_policy()
	_prediction_geometry()
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

func _movement_contacts() -> void:
	var origin := Vector2i(1_000_000, 1_000_000)
	var points := Geometry.polygon(Vector2i.ZERO, origin)
	var config := SimConfig.new()
	for hurt_radius: int in [17_000, 18_000, 19_000]:
		for face: int in 6:
			var world := HexWorld.new(CollisionWorld.new(2_000_000, 2_000_000))
			check(world.configure_hexes(origin, HexGrid.disk(Vector2i.ZERO, 2), [Vector2i.ZERO]), "movement fixture configures one physical pillar")
			var normal: Vector2i = Geometry.NORMALS[face]
			var midpoint := Vector2i((points[face].x + points[(face + 1) % 6].x) / 2, (points[face].y + points[(face + 1) % 6].y) / 2)
			var contact := midpoint + Vector2i(signi(normal.x), signi(normal.y)) * 18_001
			var state := PlayerState.new(2)
			state.radius = hurt_radius
			state.position_x = contact.x
			state.position_y = contact.y
			state.air_height = 12_000
			state.hop_ticks = 40
			state.hop_stage = 1
			var tangent := Vector2i(-normal.y, normal.x)
			# Choose a supported eight-way intent into-and-along this face.
			var intent: Vector2i = EightDirectionResolver.FIXED_VECTORS[EightDirectionResolver.classify_index(tangent.x - normal.x, tangent.y - normal.y)]
			world.begin_actor(contact, MovementTuning.PLAYER_RADIUS)
			var stamina_before := state.stamina
			MovementSystem.step(state, SimCommand.new(1, 2, intent.x, intent.y, 0, SimCommand.PRESSED_TECHNIQUE), config, world)
			check(state.wall_skim_ticks > 0, "all six faces accept paid wallrun for each body size")
			check(state.stamina < stamina_before, "hex wallrun pays ordinary stamina")
			equal(state.wall_skim_surface_id, HexWorld.FACE_ID_BASE + int(world._solid[Vector2i.ZERO]) * 8 + face, "wallrun attaches to exact stable face ID")
			check(Vector2i(state.velocity_x, state.velocity_y) != Vector2i.ZERO, "oblique face retains nonzero tangent velocity")
			var remaining := state.wall_skim_ticks
			world.begin_actor(Vector2i(state.position_x, state.position_y), MovementTuning.PLAYER_RADIUS)
			MovementSystem.step(state, SimCommand.new(2, 2, intent.x, intent.y), config, world)
			check(state.wall_skim_ticks > 0 and state.wall_skim_ticks < remaining, "wallrun continues on existing finite clock")
			state.movement_commitment_ticks = 0
			stamina_before = state.stamina
			world.begin_actor(Vector2i(state.position_x, state.position_y), MovementTuning.PLAYER_RADIUS)
			MovementSystem.step(state, SimCommand.new(3, 2, normal.x, normal.y, SimCommand.HELD_JUMP, SimCommand.PRESSED_JUMP), config, world)
			check(state.stamina < stamina_before and state.hop_stage == 2, "walljump pays and uses existing air budget on every face")
			check(state.velocity_x * normal.x + state.velocity_y * normal.y > 0, "walljump exits away from physical pillar")
			state.wall_skim_ticks = 10
			state.wall_skim_surface_id = HexWorld.FACE_ID_BASE + int(world._solid[Vector2i.ZERO]) * 8 + face
			state.wall_contact_id = state.wall_skim_surface_id
			state.air_dodge_used = true
			state.float_used = true
			state.air_redirects_remaining = 0
			world.configure_hexes(origin, HexGrid.disk(Vector2i.ZERO, 2), [])
			ReactionMovementWorld.clear_stale_contact(state, world)
			MovementSystem.step(state, SimCommand.new(4, 2), config, world)
			equal(state.wall_skim_ticks, 0, "destroyed pillar ends live wall attachment")
			check(state.air_dodge_used and state.float_used and state.air_redirects_remaining == 0, "destruction never grants a fresh air budget")
	var world := HexWorld.new(CollisionWorld.new(2_000_000, 2_000_000))
	world.configure_hexes(origin, HexGrid.disk(Vector2i.ZERO, 2), [Vector2i.ZERO])
	var start := origin - Vector2i(100_000, 0)
	var finish := origin + Vector2i(100_000, 0)
	check(not ContinuousContact.wall_contact(start, finish, 5000, world).is_empty(), "standard projectile contact dispatches to hex geometry")
	check(not SprayInterception.clear_ray(start, finish, world, [], 0), "standard Spray obstruction dispatches to hex geometry")
	var corner := origin + Vector2i(30_000, -34_000)
	check(SprayInterception.clear_ray(corner, corner + Vector2i(1000, 0), world, [], 0), "standard Spray ray passes an empty bounding rectangle corner")

func _composite_regressions() -> void:
	var origin := Vector2i(1_000_000, 1_000_000)
	var base := CollisionWorld.new(2_000_000, 2_000_000)
	base.add_obstacle(CollisionWorld.Obstacle.new(1, 200_000, 200_000, 300_000, 300_000))
	var world := HexWorld.new(base)
	world.configure_hexes(origin, HexGrid.disk(Vector2i.ZERO, 2), [Vector2i.ZERO])
	for query: Array in [[Vector2i(100_000, 250_000), Vector2i(82_000, 0)], [Vector2i(250_000, 250_000), Vector2i(100_000, 0)], [Vector2i(150_000, 150_000), Vector2i(200_000, 200_000)], [Vector2i(50_000, 50_000), Vector2i(-100_000, -100_000)]]:
		var expected := base.move_box(query[0], query[1], 18_000)
		world.begin_actor(query[0], 18_000)
		var actual := world.move_box(query[0], query[1], 18_000)
		equal(actual.position, expected.position, "distant pillar preserves worldbone tangency, overlap escape, corner and boundary positions")
		equal(actual.wall_normal, expected.wall_normal, "distant pillar preserves worldbone contact normals")
		equal(actual.wall_id, expected.wall_id, "distant pillar preserves worldbone identity")
	check(not world.configure_hexes(origin, HexGrid.disk(Vector2i.ZERO, 1), [Vector2i.ZERO]), "live topology cannot remap stored face IDs")
	var tip_start := origin - Vector2i(0, 100_000)
	world.begin_actor(tip_start, 18_000)
	var tip := world.move_box(tip_start, Vector2i(0, 100_000), 18_000)
	equal(tip.wall_id, 0, "square support contact at hex tip never aliases a runnable face")
	equal(tip.position.y, origin.y - 54_950, "top tip still blocks at exact common clearance")
	check(not world.hex_segment_clear(origin + Vector2i(32_000, -10_000), origin + Vector2i(32_000, 10_000)), "collinear partial face blocks sight and Spray")
	var constraints: Array[Vector2i] = [Vector2i(500, -866), Vector2i(-1000, 0)]
	for velocity: Vector2i in [Vector2i(100_000, 100_000), Vector2i(-100_000, 100_000), Vector2i(0, -100_000)]:
		var clipped := Geometry.clip_motion(velocity, constraints)
		for normal: Vector2i in constraints:
			check(clipped.x * normal.x + clipped.y * normal.y >= 0, "corner projection preserves every blocking face constraint")
		check(clipped.length_squared() <= velocity.length_squared() + 200_000, "corner projection cannot create meaningful speed")


func _pillar_los_policy() -> void:
	var origin := Vector2i(1_000_000, 1_000_000)
	var base := CollisionWorld.new(2_000_000, 2_000_000)
	# Presentation deliberately treats some physical campus walls as low and
	# non-occluding. The pillar-only API must never inherit that base collision.
	base.add_obstacle(CollisionWorld.Obstacle.new(1, 200_000, 450_000, 300_000, 550_000))
	var world := HexWorld.new(base)
	var topology := HexGrid.disk(Vector2i.ZERO, 1)
	check(world.configure_hexes(origin, topology, [Vector2i.ZERO]), "LOS fixture configures one trusted physical pillar")
	check(world.hex_pillar_segment_clear(Vector2i(100_000, 500_000), Vector2i(400_000, 500_000)), "pillar-only LOS ignores unrelated immutable low cover")
	check(not world.hex_segment_clear(Vector2i(100_000, 500_000), Vector2i(400_000, 500_000)), "combined gameplay ray still respects immutable collision")
	var polygon := Geometry.polygon(Vector2i.ZERO, origin)
	equal(world.hex_occluders(), [polygon], "presentation receives the exact six-face active polygon")
	for face: int in range(6):
		var midpoint := Vector2i((polygon[face].x + polygon[(face + 1) % 6].x) / 2, (polygon[face].y + polygon[(face + 1) % 6].y) / 2)
		var outside := midpoint + Geometry.NORMALS[face] * 100
		check(not world.hex_pillar_segment_clear(outside, origin), "each actual pillar face is opaque to exact LOS")
	check(not world.hex_pillar_segment_clear(origin, origin), "a point inside the solid polygon is blocked")
	check(not world.hex_pillar_segment_clear(origin + Vector2i(32_000, -10_000), origin + Vector2i(32_000, 10_000)), "collinear face tangency is opaque")
	check(not world.hex_pillar_segment_clear(origin + Vector2i(-10_000, -36_950), origin + Vector2i(10_000, -36_950)), "single-vertex tangency is opaque")
	check(world.hex_pillar_segment_clear(origin + Vector2i(31_000, -35_000), origin + Vector2i(31_000, -30_000)), "ray inside the AABB corner but outside the clear Hex triangle remains visible")
	check(world.configure_hexes(origin, topology, []), "destroyed or expired pillar clears the same trusted topology")
	check(world.hex_pillar_segment_clear(origin - Vector2i(100_000, 0), origin + Vector2i(100_000, 0)), "destruction or expiry immediately restores pillar LOS")
	equal(world.hex_occluders(), [], "destruction or expiry removes the presentation polygon")

func _prediction_geometry() -> void:
	var origin := Vector2i(1_000_000, 1_000_000)
	var authority := HexChemistryWorld.new()
	authority.configure_geometry(origin, HexGrid.disk(Vector2i.ZERO, 2))
	# Explicit geometry fixture only: recipe formation is tested by paid input
	# when Earth is activated. Prediction consumes the same phase/health state.
	authority.products[1] = {"recipe_wire_id": 301, "active_tick": 10, "decay_tick": 20, "health": 32_000, "cells": {Vector2i.ZERO: 1200}}
	var base := CollisionWorld.new(2_000_000, 2_000_000)
	var host := HexWorld.new(base)
	var client := HexWorld.new(base)
	host.set_hex_surfaces(authority, 8)
	client.set_hex_surfaces(authority, 8)
	var state := PlayerState.new(2)
	state.position_x = origin.x - 53_000
	state.position_y = origin.y
	var prediction := ClientPrediction.new()
	check(prediction.configure(SimConfig.new(), client, 2), "prediction accepts trusted physical hex world")
	check(prediction.reaction_movement == client, "prediction retains polygon dispatch instead of wrapping it into AABBs")
	check(prediction.reconcile(ClientPrediction.capture_packet(state, 8, -1)), "prediction initializes ordinary actor authority")
	for tick: int in range(8, 28):
		var command := SimCommand.new(tick, 2, 1000, 0)
		host.refresh_surfaces(tick)
		if tick in [8, 10, 20]:
			var expected_pillar_count := 1 if tick == 10 else 0
			equal(host.hex_occluders().size(), expected_pillar_count, "presentation polygons refresh at physical formation and expiry boundaries")
			equal(host.hex_pillar_segment_clear(origin - Vector2i(100_000, 0), origin + Vector2i(100_000, 0)), expected_pillar_count == 0, "pillar LOS refreshes from the same active phase and health authority")
		host.begin_actor(Vector2i(state.position_x, state.position_y), 18_000)
		ReactionMovementWorld.clear_stale_contact(state, host)
		MovementSystem.step(state, command, SimConfig.new(), host)
		check(prediction.queue_input(tick - 7, command), "predicted input advances across pillar phases")
		equal(Vector2i(prediction.predicted_state.position_x, prediction.predicted_state.position_y), Vector2i(state.position_x, state.position_y), "host and prediction agree through pillar formation and expiry")
		equal(prediction.predicted_state.wall_contact_id, state.wall_contact_id, "host and prediction use identical stable wall IDs")
	check(state.position_x > origin.x - 50_000, "expiry allows traversal beyond the former pillar face")
