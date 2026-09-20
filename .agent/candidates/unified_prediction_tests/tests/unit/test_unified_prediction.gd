extends FluxTestSuite
@warning_ignore_start("integer_division")


const Prediction = preload("res://src/net/client_prediction.gd")
const Geometry = preload("res://src/sim/hex/hex_convex_geometry.gd")
const ORIGIN := Vector2i(1_000_000, 1_000_000)
const SNAPSHOT_TICK := 20
const ACTOR_ID := 2


func run() -> int:
	_test_detached_binding_tick_contract_and_reset()
	_test_true_six_face_pillar_parity()
	_test_ground_modifier_and_flow_parity_without_replica_mutation()
	return finish("unified-prediction")


func _test_detached_binding_tick_contract_and_reset() -> void:
	var replica := _world([_product(1, 301)])
	var actor := _actor(ORIGIN + Vector2i(120_000, 0))
	replica.players = [actor]
	var prediction := Prediction.new()
	check(prediction.configure(replica.config, replica.collision, ACTOR_ID), "hex prediction configures against the trusted replica collision")
	check(prediction.bind_hex_world(replica), "prediction binds a detached whole-hex world")
	check(prediction.hex_authority != replica.hex_court, "prediction never aliases the authoritative whole-hex object")
	check(prediction.collision != replica.collision and prediction.collision is HexCollisionWorld, "prediction rebuilds a detached dynamic collision world")
	equal(prediction.hex_context_tick, SNAPSHOT_TICK, "bound geometry records the exact snapshot tick")
	equal(prediction.hex_authority.products, replica.hex_court.products, "detached authority begins with the exact product state")

	var same_tick := Prediction.capture_packet(actor, SNAPSHOT_TICK, -1)
	check(prediction.reconcile(same_tick, "whole_hex_snapshot"), "the actor packet reconciles at the bound hex snapshot tick")
	var predicted_before := prediction.predicted_state.canonical_values()
	var mismatched := Prediction.capture_packet(actor, SNAPSHOT_TICK + 1, -1)
	check(not prediction.reconcile(mismatched, "wrong_hex_tick"), "a packet from another tick refuses before replaying against stale geometry")
	equal(prediction.predicted_state.canonical_values(), predicted_before, "tick mismatch leaves the predicted actor unchanged")
	equal(prediction.last_authoritative_tick, SNAPSHOT_TICK, "tick mismatch cannot advance the reconciliation cursor")

	prediction.reset()
	check(prediction.hex_authority == null and prediction.hex_context_tick == -1, "reset discards the old detached products and their tick")
	var clean_source := _world([])
	clean_source.players = [_actor(ORIGIN)]
	var clean_snapshot := HexWorldSnapshot.capture(clean_source)
	check(not clean_snapshot.is_empty(), "live snapshot codec captures the valid product-free whole-hex world")
	var clean := HexWorldSnapshot.prepare(clean_snapshot, clean_source)
	check(clean != null and clean != clean_source, "live snapshot codec prepares a detached authoritative replica")
	if clean == null:
		return
	check(prediction.configure(clean.config, clean.collision, ACTOR_ID), "prediction reconfigures after reset")
	check(prediction.bind_hex_world(clean), "prediction binds a new product-free detached snapshot")
	check(prediction.hex_authority.products.is_empty(), "a reset and rebind cannot retain products from the previous snapshot")
	check(prediction.collision.can_occupy(ORIGIN, MovementTuning.PLAYER_RADIUS), "old pillar geometry is absent after reset")
	check(prediction.reconcile(Prediction.capture_packet(clean.player(ACTOR_ID), SNAPSHOT_TICK, -1)), "clean same-tick actor packet reconciles after reset")


func _test_true_six_face_pillar_parity() -> void:
	var polygon := Geometry.polygon(Vector2i.ZERO, ORIGIN)
	for face: int in 6:
		var replica := _world([_product(1, 301)])
		var host := _world([_product(1, 301)])
		var midpoint := Vector2i(
			(polygon[face].x + polygon[(face + 1) % 6].x) / 2,
			(polygon[face].y + polygon[(face + 1) % 6].y) / 2,
		)
		var normal: Vector2i = Geometry.NORMALS[face]
		var contact := midpoint + Vector2i(signi(normal.x), signi(normal.y)) * 18_001
		var replica_actor := _actor(contact)
		replica_actor.air_height = 12_000
		replica_actor.hop_ticks = 40
		replica_actor.hop_stage = 1
		var host_actor := _copy_actor(replica_actor)
		replica.players = [replica_actor]
		host.players = [host_actor]
		var tangent := Vector2i(-normal.y, normal.x)
		var intent: Vector2i = EightDirectionResolver.FIXED_VECTORS[
			EightDirectionResolver.classify_index(tangent.x - normal.x, tangent.y - normal.y)
		]
		var command := SimCommand.new(SNAPSHOT_TICK, ACTOR_ID, intent.x, intent.y, 0, SimCommand.PRESSED_TECHNIQUE, intent.x, intent.y)

		var replica_actor_before := replica_actor.canonical_values()
		var replica_products_before := replica.hex_court.products.duplicate(true)
		var replica_flow_before := replica.hex_court.flow_carry.duplicate(true)
		var prediction := Prediction.new()
		check(prediction.configure(replica.config, replica.collision, ACTOR_ID), "face %d prediction configures" % face)
		check(prediction.bind_hex_world(replica), "face %d prediction binds detached pillar geometry" % face)
		equal(prediction.collision._faces.size(), 6, "one active whole hex exposes six physical faces")
		check(prediction.reconcile(Prediction.capture_packet(replica_actor, SNAPSHOT_TICK, -1)), "face %d same-tick packet reconciles" % face)
		check(prediction.queue_input(1, command), "face %d movement enters prediction" % face)
		_host_step(host, command)

		_assert_prediction_state(prediction.predicted_state, host_actor, "pillar face %d" % face)
		var expected_surface := HexCollisionWorld.FACE_ID_BASE + int((replica.collision as HexCollisionWorld)._solid[Vector2i.ZERO]) * 8 + face
		equal(prediction.predicted_state.wall_skim_surface_id, expected_surface, "prediction attaches to the exact canonical pillar face %d" % face)
		check(prediction.predicted_state.wall_skim_ticks > 0, "true pillar face %d supports the normal paid wallrun" % face)
		equal(replica_actor.canonical_values(), replica_actor_before, "face %d prediction never mutates the replica actor" % face)
		equal(replica.hex_court.products, replica_products_before, "face %d prediction never mutates replica products" % face)
		equal(replica.hex_court.flow_carry, replica_flow_before, "face %d prediction never writes flow state into the replica" % face)


func _test_ground_modifier_and_flow_parity_without_replica_mutation() -> void:
	var products := [_product(1, 303), _product(2, 316)]
	var replica := _world(products)
	var host := _world([_product(1, 303), _product(2, 316)])
	var replica_actor := _actor(ORIGIN)
	var host_actor := _copy_actor(replica_actor)
	replica.players = [replica_actor]
	host.players = [host_actor]
	var command := SimCommand.new(SNAPSHOT_TICK, ACTOR_ID, 1000, 0, 0, 0, 1000, 0)
	var modifier := HexProductEffects.pre_movement(replica.hex_court, replica_actor, SNAPSHOT_TICK, ORIGIN, replica.config)
	equal(int(modifier.acceleration_ratio), 700, "fixture uses the production Mud acceleration ratio")
	equal(int(modifier.braking_ratio), 700, "fixture uses the production Mud braking ratio")

	var replica_actor_before := replica_actor.canonical_values()
	var replica_products_before := replica.hex_court.products.duplicate(true)
	var replica_flow_before := replica.hex_court.flow_carry.duplicate(true)
	var replica_cells_before := replica.hex_court.cells.duplicate(true)
	var prediction := Prediction.new()
	check(prediction.configure(replica.config, replica.collision, ACTOR_ID), "modifier/flow prediction configures")
	check(prediction.bind_hex_world(replica), "modifier/flow prediction binds detached products")
	check(prediction.reconcile(Prediction.capture_packet(replica_actor, SNAPSHOT_TICK, -1)), "modifier/flow packet reconciles at the product tick")
	check(prediction.queue_input(1, command), "modifier/flow input advances prediction")
	_host_step(host, command)

	_assert_prediction_state(prediction.predicted_state, host_actor, "Mud and Flood")
	equal(prediction.hex_authority.flow_carry, host.hex_court.flow_carry, "predicted Flood fractional carry exactly matches authority")
	check(prediction.hex_authority.flow_carry.has("2:2"), "real Flood actor flow records a bounded product/actor carry")
	var dry := _actor(ORIGIN)
	MovementSystem.step(dry, command, SimConfig.new(120), CollisionWorld.new(2_000_000, 2_000_000), 1000, 1000, 1000)
	check(host_actor.velocity_x < dry.velocity_x, "Mud changes real ground acceleration rather than only reporting a modifier")
	check(host_actor.position_x > ORIGIN.x, "Flood applies real grounded directional movement after ordinary motion")

	equal(replica_actor.canonical_values(), replica_actor_before, "prediction leaves the authoritative replica actor untouched")
	equal(replica.hex_court.products, replica_products_before, "prediction leaves authoritative product contacts and phases untouched")
	equal(replica.hex_court.flow_carry, replica_flow_before, "prediction stores Flood carry only in its detached authority")
	equal(replica.hex_court.cells, replica_cells_before, "prediction never retile-writes the authoritative replica cells")


func _world(products: Array) -> SimWorld:
	var base := CollisionWorld.new(2_000_000, 2_000_000)
	var authority := HexChemistryWorld.new()
	check(authority.configure_geometry(ORIGIN, HexGrid.disk(Vector2i.ZERO, 2)), "prediction fixture configures trusted whole-hex topology")
	for product_value: Variant in products:
		var product: Dictionary = (product_value as Dictionary).duplicate(true)
		authority.products[int(product.id)] = product
	authority.current_tick = SNAPSHOT_TICK - 1
	authority.collision = base
	var dynamic := HexCollisionWorld.new(base)
	check(dynamic.set_hex_surfaces(authority, SNAPSHOT_TICK), "prediction fixture compiles current six-face surfaces")
	var world := SimWorld.new(120, 8801, dynamic, "prediction-hex-fixture", "trusted-prediction-worldbone")
	world.tick = SNAPSHOT_TICK
	world.hex_court = authority
	world.collision = dynamic
	world.reaction_movement = dynamic
	world.players = []
	return world


func _product(id: int, wire: int) -> Dictionary:
	var policy := HexRecipePolicy.definition(wire)
	var material := HexRecipePolicy.product_layer(wire)
	return {
		"id": id,
		"recipe_wire_id": wire,
		"material": material,
		"strength": 5,
		"source_ids": [id * 2_000 + 1, id * 2_000 + 2],
		"footprint": HexRecipePolicy.selection_shape(wire, ORIGIN, Vector2i(1000, 0)),
		"cells": {Vector2i.ZERO: 1_200},
		"coverage": {Vector2i.ZERO: 1},
		"quantity": 1_200,
		"created": 0,
		"formation_tick": 0,
		"active_tick": 10,
		"decay_tick": 100,
		"expiry_tick": 120,
		"expires": 120,
		"intensity": 1_000,
		"heated": false,
		"cooled": false,
		"flow_aim": Vector2i(1000, 0),
		"flow_units_per_second": int(policy.get("flow_speed", 0)),
		"common_wall_clearance": MovementTuning.PLAYER_RADIUS,
		"pulse_ms": int(policy.get("pulse_ticks", 0)) * 1000 / 120,
		"pulse_damage": int(policy.get("pulse_damage", 0)),
		"geometry_override": "whole_hex",
		"owner": 1,
		"team": 1,
		"health": int(policy.get("health", 0)),
		"capacity": int(policy.get("capacity", 0)),
		"position": ORIGIN,
		"origin": ORIGIN,
		"contacts": {},
		"linked_sources": [],
		"pulse_index": -1,
		"last_motion_tick": SNAPSHOT_TICK,
		"motion_carry": Vector2i.ZERO,
	}


func _actor(point: Vector2i) -> PlayerState:
	var actor := PlayerState.new(ACTOR_ID)
	actor.team_id = 2
	actor.position_x = point.x
	actor.position_y = point.y
	actor.spawn_protection_ticks = 0
	return actor


func _copy_actor(source: PlayerState) -> PlayerState:
	var packet := Prediction.capture_packet(source, SNAPSHOT_TICK, -1)
	return Prediction.restore_state(packet.values)


func _host_step(world: SimWorld, command: SimCommand) -> void:
	var actor := world.player(ACTOR_ID)
	actor.spawn_protection_ticks = maxi(0, actor.spawn_protection_ticks - 1)
	actor.aim_x = command.aim_x
	actor.aim_y = command.aim_y
	world.hex_court.expire_at(world.tick)
	world.hex_court.fracture_products(world.tick)
	world.hex_court.move_products(world.tick, world.reaction_movement)
	(world.reaction_movement as HexCollisionWorld).refresh_surfaces(world.tick)
	world.reaction_movement.begin_actor(Vector2i(actor.position_x, actor.position_y), MovementTuning.PLAYER_RADIUS)
	ReactionMovementWorld.clear_stale_contact(actor, world.reaction_movement)
	var point := Vector2i(actor.position_x, actor.position_y)
	var modifiers := HexProductEffects.pre_movement(world.hex_court, actor, world.tick, point, world.config)
	var previous := {"point": point, "height": actor.air_height}
	MovementSystem.step(
		actor,
		command,
		world.config,
		world.reaction_movement,
		int(modifiers.ground_target_ratio),
		int(modifiers.acceleration_ratio),
		int(modifiers.braking_ratio),
	)
	var events: Array[Dictionary] = []
	world.hex_court.apply_product_effects([actor], world.tick, world.config, world.reaction_movement, events, {ACTOR_ID: previous})
	world.tick += 1


func _assert_prediction_state(predicted: PlayerState, authoritative: PlayerState, context: String) -> void:
	for property_name: StringName in Prediction.STATE_FIELDS:
		equal(predicted.get(property_name), authoritative.get(property_name), "%s prediction matches authority field %s" % [context, property_name])
