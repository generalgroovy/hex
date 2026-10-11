extends FluxTestSuite

const Effects = preload("res://src/sim/hex/hex_product_effects.gd")
const ORIGIN := Vector2i(600_000, 500_000)
var config := SimConfig.new(120)


func run() -> int:
	_test_surface_height_matrix()
	_test_landing_sweeps_and_tall_effects()
	_test_modifiers_keep_paid_budgets_separate()
	_test_root_fire_and_steam()
	_test_capacitor_and_legacy()
	return finish("movement-checkpoint1-ground")


func _world() -> HexChemistryWorld:
	var world := HexChemistryWorld.new()
	check(world.configure_geometry(ORIGIN, [Vector2i(-1, 0), Vector2i.ZERO, Vector2i(1, 0)]), "ground exposure fixture geometry")
	return world


func _actor(height: int = 0, slide: bool = false, wall: bool = false) -> PlayerState:
	var actor := PlayerState.new(2)
	actor.team_id = 2
	actor.spawn_protection_ticks = 0
	actor.position_x = ORIGIN.x
	actor.position_y = ORIGIN.y
	actor.air_height = height
	actor.slide_ticks = 10 if slide else 0
	actor.wall_skim_ticks = 10 if wall else 0
	return actor


func _product(wire: int) -> Dictionary:
	# Isolated exposure geometry: the shared paid suites establish funding.
	# An explicit finite pool lets this probe measure clearance, not empty-pool refusal.
	return {"id": 1, "recipe_wire_id": wire, "cells": {Vector2i.ZERO: 100}, "coverage": {Vector2i.ZERO: 1},
		"quantity": 100, "owner": 1, "team": 1, "active_tick": 10, "decay_tick": 100,
		"expiry_tick": 150, "intensity": 1000, "flow_aim": Vector2i(1000, 0),
		"position": ORIGIN, "contacts": {}, "linked_sources": [], "pulse_index": -1,
		"pulse_damage": 8000, "strength": 10, "funded_strength": 20, "damage_budget_remaining": 80_000, "flow_units_per_second": 40000, "common_wall_clearance": 18000}


func _test_surface_height_matrix() -> void:
	for wire: int in [302, 309, 316]:
		for height: int in [0, 1, 17_999, 18_000, 48_001]:
			for wall: bool in [false, true]:
				var world := _world()
				world.products[1] = _product(wire)
				var actor := _actor(height, height == 0, wall)
				var health := actor.health
				var events: Array[Dictionary] = []
				world.apply_product_effects([actor], 10, config, CollisionWorld.new(2_000_000, 1_500_000), events)
				var affected := actor.health < health
				equal(affected, height < 18_000 or wall, "surface %d respects clearance, slides and vulnerable wallrun at %d" % [wire, height])


func _test_landing_sweeps_and_tall_effects() -> void:
	var world := _world()
	var actor := _actor(17_999)
	actor.position_x += 48_000
	var sample := {"start": ORIGIN - Vector2i(48_000, 0), "finish": Vector2i(actor.position_x, actor.position_y), "previous_height": 18_000}
	check(not Effects._path_touches(world, _product(302), actor, sample, true), "descending through clearance cannot inherit crossed surface at quiet endpoint")
	sample.previous_height = 17_999
	check(Effects._path_touches(world, _product(302), actor, sample, true), "below-clearance travel remains exposed along swept path")
	actor.wall_skim_ticks = 2
	sample.previous_height = 60_000
	check(Effects._path_touches(world, _product(302), actor, sample, true), "wallrun does not gain landing-sweep immunity")
	actor = _actor(48_000)
	sample = {"start": ORIGIN, "finish": ORIGIN, "previous_height": 48_000}
	check(Effects._path_touches(world, _product(310), actor, sample, false), "Steam retains explicit inclusive 48px ceiling")
	actor.air_height = 48_001
	check(not Effects._path_touches(world, _product(310), actor, sample, false), "above Steam ceiling avoids Steam")
	actor.wall_skim_ticks = 2
	check(Effects._path_touches(world, _product(310), actor, sample, false), "wallrun remains vulnerable to tall effects")
	actor = _actor(60_000)
	check(Effects._endpoint_inside(world, _product(308), actor, ORIGIN), "ground surface visibility membership remains height-agnostic")


func _test_modifiers_keep_paid_budgets_separate() -> void:
	var world := _world()
	world.products[1] = _product(316)
	var actor := _actor(0, true)
	equal(Effects.pre_movement(world, actor, 10, ORIGIN, config).ground_target_ratio, 1000, "paid slide bypasses the ordinary-walk Frostway slow")
	world.products[1] = _product(302)
	equal(Effects.pre_movement(world, actor, 10, ORIGIN, config).ground_target_ratio, 750, "low-profile slide is not hidden from harmful surface queries")
	actor.air_height = 18_000
	equal(Effects.pre_movement(world, actor, 10, ORIGIN, config).ground_target_ratio, 1000, "cleared surface does not request locomotion slow")
	actor.wall_skim_ticks = 2
	equal(Effects.pre_movement(world, actor, 10, ORIGIN, config).ground_target_ratio, 750, "wallrun is eligible for surface query without changing paid impulse budget")


func _test_root_fire_and_steam() -> void:
	var world := _world()
	world.set_cell_amount(Vector2i.ZERO,"fire",1,100)
	world.casts[1] = {"element": HexChemistryWorld.FIRE, "ground": 100, "created": 0, "expires": 200,
		"source": 1, "owner": 1, "coverage": {Vector2i.ZERO: 1}, "ground_parts": {1: {"coverage": {Vector2i.ZERO: 1}, "created": 0, "expiry_tick": 200, "quantity": 100}}}
	for height: int in [0, 17_999, 18_000]:
		var actor := _actor(height, height == 0)
		var before := actor.health
		world._expose(actor, ORIGIN, 30, config, [])
		equal(actor.health < before, height < 18_000, "base Fire applies actual clearance at %d" % height)
	var wall := _actor(60_000, false, true)
	var before_wall := wall.health
	world._expose(wall, ORIGIN, 30, config, [])
	check(wall.health < before_wall, "elevated wallrun remains exposed to base Fire")
	world.cells[Vector2i.ZERO].fire.clear()
	world.set_cell_amount(Vector2i.ZERO,"steam",1,100)
	world.products[1] = _product(310)
	var landing := _actor(17_999)
	landing.position_x += 48_000
	world._expose(landing, {"point": ORIGIN - Vector2i(48_000, 0), "height": 18_000}, 30, config, [])
	check(int(world.exposure.get(landing.entity_id, 0)) > 0, "ground clearance crossing does not erase already-exposed tall Steam path")


func _test_capacitor_and_legacy() -> void:
	var rows := PackedInt32Array([1, ORIGIN.x, ORIGIN.y, ORIGIN.x + 200_000, ORIGIN.y, 30_000, 200_000, 10, 100, 1])
	for height: int in [0, 17_999, 18_000]:
		var actor := _actor(height, height == 0)
		equal(CapacitorFieldPolicy.apply_discharge(rows, actor, 99, null), height < 18_000, "legacy Capacitor uses shared clearance at %d" % height)
	var wall := _actor(60_000, false, true)
	check(CapacitorFieldPolicy.apply_discharge(rows, wall, 99, null), "legacy Capacitor affects elevated wallrun")
	var dodging := _actor()
	dodging.air_dodge_ticks = config.milliseconds_to_ticks(MovementTuning.AIR_DODGE_DURATION_MS)
	check(not CapacitorFieldPolicy.apply_discharge(rows, dodging, 99, null, config), "legacy Capacitor respects separate timed dodge protection")
	for height: int in [0, 17_999, 18_000]:
		var reaction := ElementReactionState.new()
		reaction.entity_id = 1
		reaction.recipe_wire_id = 309
		reaction.team_id = 1
		reaction.position_x = ORIGIN.x
		reaction.position_y = ORIGIN.y
		reaction.radius = 30_000
		reaction.active_tick = 10
		var actor := _actor(height, height == 0)
		var before := actor.health
		ElementChemistrySystem._apply_result(reaction, [], [], [actor], null, config, 10, [])
		equal(actor.health < before, height < 18_000, "legacy Conflagration follows surface clearance at %d" % height)
