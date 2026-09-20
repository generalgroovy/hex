extends FluxTestSuite

## Focused compatibility checks for Ice/Charge/Light/Dark actor effects. The
## fixture supplies already-formed products; formation, costs and durations are
## covered by the recipe/world suites.

const Effects = preload("res://src/sim/hex/hex_product_effects.gd")
const ORIGIN := Vector2i(600_000, 500_000)
var config := SimConfig.new(120)


func run() -> int:
	_test_zero_period_is_one_shared_activation_pulse()
	_test_conductive_flood_standalone_and_broken_links()
	_test_black_ice_reveal_is_not_a_ground_slow()
	return finish("hex-actor-compat")


func _authority() -> HexChemistryWorld:
	var authority := HexChemistryWorld.new()
	var configured := authority.configure_geometry(ORIGIN, [Vector2i.ZERO])
	check(configured, "actor compatibility fixture geometry configures")
	return authority


func _product(id: int, wire: int) -> Dictionary:
	return {
		"id": id,
		"recipe_wire_id": wire,
		"cells": {Vector2i.ZERO: 100},
		"coverage": {Vector2i.ZERO: 1},
		"quantity": 100,
		"capacity": 100,
		"owner": 1,
		"team": 1,
		"active_tick": 10,
		"decay_tick": 500,
		"expiry_tick": 560,
		"intensity": 1000,
		"health": 0,
		"flow_aim": Vector2i(1000, 0),
		"position": ORIGIN,
		"contacts": {},
		"linked_sources": [],
		"pulse_index": -1,
	}


func _actor(id: int, point: Vector2i = ORIGIN) -> PlayerState:
	var actor := PlayerState.new(id)
	actor.team_id = 2
	actor.position_x = point.x
	actor.position_y = point.y
	actor.spawn_protection_ticks = 0
	return actor


func _step(authority: HexChemistryWorld, actors: Array[PlayerState], tick: int) -> void:
	Effects.step(authority, actors, tick, config, CollisionWorld.new(2_000_000, 1_500_000), [])


func _test_zero_period_is_one_shared_activation_pulse() -> void:
	var authority := _authority()
	var flare := _product(1, 314)
	flare.pulse_ms = 0
	authority.products[1] = flare
	var first := _actor(2)
	var second := _actor(3)
	_step(authority, [first, second], 10)
	var reveal_ticks := config.milliseconds_to_ticks(700)
	equal(first.chemistry_reveal_ticks, reveal_ticks, "Solar Flare activation reveals the first actor")
	equal(second.chemistry_reveal_ticks, reveal_ticks, "one product pulse is shared by every actor in that tick")
	equal(int(authority.products[1].pulse_index), 0, "zero-period activation consumes the canonical product pulse")
	first.chemistry_reveal_ticks = 0
	second.chemistry_reveal_ticks = 0
	_step(authority, [first, second], 11)
	equal(first.chemistry_reveal_ticks, 0, "zero-period Solar Flare does not refresh on its next active tick")
	equal(second.chemistry_reveal_ticks, 0, "zero-period pulse remains consumed for every actor")

	# A restored or otherwise first-processed product still owns its one attempt;
	# legacy pulse_index, rather than equality with active_tick, is authoritative.
	var late := _product(2, 332)
	late.pulse_ms = 0
	authority.products.clear()
	authority.products[2] = late
	first.chemistry_reveal_ticks = 0
	_step(authority, [first], 12)
	equal(first.chemistry_reveal_ticks, reveal_ticks, "unconsumed Arcflash pulses once when first processed after activation")
	first.chemistry_reveal_ticks = 0
	_step(authority, [first], 13)
	equal(first.chemistry_reveal_ticks, 0, "late first processing cannot make a zero-period impulse repeat")


func _test_conductive_flood_standalone_and_broken_links() -> void:
	var authority := _authority()
	var flood := _product(1, 319)
	flood.pulse_ms = 600
	flood.pulse_damage = 6_000
	authority.products[1] = flood
	var actor := _actor(2)
	var before := actor.health
	_step(authority, [actor], 10)
	equal(before - actor.health, 6_000, "unlinked Conductive Flood retains its damaging origin footprint")

	# An explicitly selected chain is different from a standalone origin. Every
	# selected link must stay live; losing one disables the connected discharge.
	flood.contacts.clear()
	flood.pulse_index = -1
	flood.linked_sources = [9001]
	actor = _actor(3)
	before = actor.health
	_step(authority, [actor], 10)
	equal(actor.health, before, "a missing explicit Water link disables Conductive Flood damage")
	authority.sources[9001] = 20
	authority.casts[20] = {"expires": 100, "coverage": {Vector2i.ZERO: 1}}
	flood.contacts.clear()
	flood.pulse_index = -1
	actor = _actor(4)
	before = actor.health
	_step(authority, [actor], 10)
	equal(before - actor.health, 6_000, "a live explicit Water link restores connected Conductive Flood damage")


func _test_black_ice_reveal_is_not_a_ground_slow() -> void:
	var authority := _authority()
	authority.products[1] = _product(1, 330)
	var airborne := _actor(2)
	airborne.air_height = 80_000
	airborne.air_vertical_velocity = 1
	_step(authority, [airborne], 10)
	equal(airborne.chemistry_reveal_ticks, config.milliseconds_to_ticks(250), "Black Ice entry reveal remains visible at playable air height")
	equal(airborne.control_state, PlayerState.ControlState.FREE, "Black Ice delayed slow remains restricted to grounded actors")

	var grounded := _actor(3)
	_step(authority, [grounded], 10)
	for tick: int in range(11, 10 + config.milliseconds_to_ticks(350)):
		_step(authority, [grounded], tick)
	equal(grounded.control_state, PlayerState.ControlState.FREE, "Black Ice does not slow before its grounded dwell threshold")
	_step(authority, [grounded], 10 + config.milliseconds_to_ticks(350))
	equal(grounded.control_state, PlayerState.ControlState.SLOWED, "grounded Black Ice dwell still applies the established finite slow")
