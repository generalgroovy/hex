extends FluxTestSuite

## Source-level unit fixtures for the detached helper. World-loop integration,
## paid formation and native gameplay evidence remain explicitly pending.

const Effects = preload("res://src/sim/hex/hex_product_effects.gd")
const ORIGIN := Vector2i(600_000, 500_000)
var config := SimConfig.new(120)


func run() -> int:
	_test_zero_allocation_coverage_and_sweep_dedupe()
	_test_mistcurrent_visible_ground_steering()
	_test_pre_movement_exit_and_precedence()
	_test_later_actor_parity_and_strict_links()
	_test_contact_bound()
	return finish("hex-product-effects-unit-integration-pending")


func _authority() -> HexChemistryWorld:
	var authority := HexChemistryWorld.new()
	check(authority.configure_geometry(ORIGIN, [Vector2i(-1, 0), Vector2i.ZERO, Vector2i(1, 0), Vector2i(2, 0)]), "product fixture geometry configures")
	return authority


func _product(id: int, wire: int, cells: Dictionary, team: int = 1) -> Dictionary:
	var coverage := {}
	for cell: Vector2i in cells:
		coverage[cell] = 1
	return {
		"id": id, "recipe_wire_id": wire, "cells": cells, "coverage": coverage,
		"quantity": 100, "capacity": 100, "owner": 1, "team": team,
		"active_tick": 10, "decay_tick": 500, "expiry_tick": 560,
		"intensity": 1000, "health": 0, "flow_aim": Vector2i(1000, 0),
		"position": ORIGIN, "contacts": {}, "linked_sources": [], "pulse_index": -1,
	}


func _actor(id: int = 2, team: int = 2, point: Vector2i = ORIGIN) -> PlayerState:
	var actor := PlayerState.new(id)
	actor.team_id = team
	actor.position_x = point.x
	actor.position_y = point.y
	actor.spawn_protection_ticks = 0
	return actor


func _test_zero_allocation_coverage_and_sweep_dedupe() -> void:
	var authority := _authority()
	var product := _product(1, 304, {Vector2i.ZERO: 100, Vector2i(1, 0): 0})
	authority.products[1] = product
	var actor := _actor(2, 2, ORIGIN + Vector2i(96_000, 0))
	var events: Array = []
	Effects.step(authority, [actor], 10, config, CollisionWorld.new(2_000_000, 1_500_000), events, {2: ORIGIN - Vector2i(96_000, 0)})
	equal(actor.chemistry_conceal_ticks, 0, "unified Dustfront pressure keeps actors visible")
	check(Vector2i(actor.position_x, actor.position_y) != ORIGIN + Vector2i(96_000, 0), "canonical swept foot traversal applies Dustfront once")
	var once := Vector2i(actor.position_x, actor.position_y)
	Effects.step(authority, [actor], 10, config, CollisionWorld.new(2_000_000, 1_500_000), events, {2: ORIGIN - Vector2i(96_000, 0)})
	equal(Vector2i(actor.position_x, actor.position_y), once, "product/actor/tick contact record deduplicates repeated step")
	equal(authority.products[1].contacts[2].last_pulse, 10, "dedupe state is stored in product authority")


func _test_pre_movement_exit_and_precedence() -> void:
	var authority := _authority()
	authority.products[1] = _product(1, 303, {Vector2i.ZERO: 100})
	authority.products[2] = _product(2, 302, {Vector2i.ZERO: 100})
	var actor := _actor()
	var modifiers := Effects.pre_movement(authority, actor, 10, ORIGIN, config)
	equal(modifiers.acceleration_ratio, 700, "Mud reduces ordinary grounded acceleration")
	equal(modifiers.braking_ratio, 700, "Mud reduces ordinary grounded braking")
	equal(modifiers.ground_target_ratio, 750, "Magma applies bounded ground target slow")
	modifiers = Effects.pre_movement(authority, actor, 10, ORIGIN + Vector2i(192_000, 0), config)
	equal(modifiers, {"acceleration_ratio": 1000, "braking_ratio": 1000, "ground_target_ratio": 1000}, "Mud and Magma end on the immediate post-exit query")
	actor.team_id = 1
	modifiers = Effects.pre_movement(authority, actor, 10, ORIGIN, config)
	equal(modifiers.acceleration_ratio, 700, "the Mud caster is subject to the same viscous acceleration surface")
	equal(modifiers.braking_ratio, 700, "the Mud caster is subject to the same viscous braking surface")
	equal(modifiers.ground_target_ratio, 750, "the Magma caster is subject to the same bounded ground slow")
	actor.hop_ticks = 1
	actor.jump_protection_ticks = 1
	equal(Effects.pre_movement(authority, actor, 10, ORIGIN, config), {"acceleration_ratio": 1000, "braking_ratio": 1000, "ground_target_ratio": 1000}, "combat intangibility blocks physical Mud and Magma movement effects")
	actor.hop_ticks = 0
	actor.jump_protection_ticks = 0
	actor.team_id = 2
	authority.products[3] = _product(3, 331, {Vector2i.ZERO: 100})
	modifiers = Effects.pre_movement(authority, actor, 10, ORIGIN, config)
	equal(modifiers.ground_target_ratio, 750, "Magma cannot be overwritten by Capacitor acceleration")
	authority.products.erase(2)
	equal(Effects.pre_movement(authority, actor, 10, ORIGIN, config).ground_target_ratio, 1250, "Capacitor accelerates both teams on ordinary ground")
	authority.products[4] = _product(4, 327, {Vector2i.ZERO: 100})
	equal(Effects.pre_movement(authority, actor, 10, ORIGIN, config).ground_target_ratio, 750, "Frostway takes priority over Capacitor")
	actor.air_height = 1
	equal(Effects.pre_movement(authority, actor, 10, ORIGIN, config).ground_target_ratio, 1000, "airborne movement ignores ground product ratios")


func _test_mistcurrent_visible_ground_steering() -> void:
	var authority := _authority()
	authority.products[1] = _product(1, 317, {Vector2i.ZERO: 100})
	# Remain inside one48px cell throughout the unchanged25px flow journey.
	var actor := _actor(2, 1, ORIGIN - Vector2i(12_000, 0))
	var start := Vector2i(actor.position_x, actor.position_y)
	var events: Array = []
	var collision := CollisionWorld.new(2_000_000, 1_500_000)
	var intangible := _actor(3, 1)
	intangible.hop_ticks = 1
	intangible.jump_protection_ticks = 1
	var intangible_start := Vector2i(intangible.position_x, intangible.position_y)
	Effects.step(authority, [intangible], 10, config, collision, events)
	equal(Vector2i(intangible.position_x, intangible.position_y), intangible_start, "combat intangibility blocks friendly physical flow")
	for tick: int in range(10, 130):
		Effects.step(authority, [actor], tick, config, collision, events)
	equal(Vector2i(actor.position_x, actor.position_y) - start, Vector2i(25_000, 0), "Mistcurrent gives its caster exactly25k one-second steering through authority carry")
	equal(authority.flow_carry["1:2"], Vector2i.ZERO, "directional fractional carry closes exactly after120 ticks")
	equal(actor.chemistry_conceal_ticks, 0, "Mistcurrent keeps actors visible")
	var grounded_position := Vector2i(actor.position_x, actor.position_y)
	authority.products[1].contacts.clear()
	actor.air_height = 1
	Effects.step(authority, [actor], 130, config, collision, events)
	equal(Vector2i(actor.position_x, actor.position_y), grounded_position, "airborne actor bypasses Mistcurrent steering")
	var vortex := _product(2, 322, {Vector2i.ZERO: 100})
	authority.products.clear()
	authority.products[2] = vortex
	actor.air_height = 0
	actor.position_x = ORIGIN.x + 20_000
	actor.position_y = ORIGIN.y
	var vortex_start := Vector2i(actor.position_x, actor.position_y)
	Effects.step(authority, [actor], 131, config, collision, events)
	check(actor.position_y > vortex_start.y, "Vortex tangential utility also moves its owning team")


func _test_later_actor_parity_and_strict_links() -> void:
	var authority := _authority()
	var actor := _actor()
	var magma := _product(1, 302, {Vector2i.ZERO: 100})
	magma.pulse_ms = 400
	authority.products[1] = magma
	var before := actor.health
	var events: Array = []
	Effects.step(authority, [actor], 10, config, CollisionWorld.new(2_000_000, 1_500_000), events)
	equal(before - actor.health, 5_000, "Magma preserves grounded five-point pulse damage")
	var airborne := _actor(3)
	airborne.air_height = 1
	var protected := _actor(4)
	protected.spawn_protection_ticks = 1
	var allied := _actor(5, 1)
	var airborne_health := airborne.health
	var protected_health := protected.health
	var allied_health := allied.health
	Effects.step(authority, [airborne, protected, allied], 10, config, CollisionWorld.new(2_000_000, 1_500_000), events)
	equal(airborne.health, airborne_health, "airborne actor escapes Magma ground damage")
	equal(protected.health, protected_health, "spawn protection blocks Magma ground damage")
	equal(allied.health, allied_health, "Magma movement affects its caster but its damage remains hostile")
	authority.products.clear()
	var shroud := _product(2, 333, {Vector2i.ZERO: 100})
	authority.products[2] = shroud
	Effects.step(authority, [actor], 11, config, CollisionWorld.new(2_000_000, 1_500_000), events)
	check(actor.chemistry_conceal_ticks >= 2 and actor.chemistry_reveal_ticks >= config.milliseconds_to_ticks(120), "Static Shroud preserves conceal and entry reveal")
	actor.position_x = ORIGIN.x + 192_000
	actor.chemistry_reveal_ticks = 0
	Effects.step(authority, [actor], 12, config, CollisionWorld.new(2_000_000, 1_500_000), events)
	check(actor.chemistry_reveal_ticks >= config.milliseconds_to_ticks(120), "Static Shroud exit transition reveals")
	authority.products.clear()
	actor.position_x = ORIGIN.x
	var arc := _product(3, 313, {Vector2i.ZERO: 100})
	arc.pulse_ms = 0
	arc.source_ids = [9001, 9002]
	arc.linked_sources = []
	authority.products[3] = arc
	before = actor.health
	Effects.step(authority, [actor], 13, config, CollisionWorld.new(2_000_000, 1_500_000), events)
	equal(actor.health, before, "parent source_ids cannot falsely satisfy linked damage")
	authority.casts[20] = {"expires": 100, "cells": {Vector2i.ZERO: 1}}
	authority.sources[9100] = 20
	authority.products[3].linked_sources = [9100]
	# The previous no-link attempt consumed this zero-period fixture's one pulse.
	# Reset canonical pulse state to isolate link liveness on the next sample.
	authority.products[3].pulse_index = -1
	Effects.step(authority, [actor], 14, config, CollisionWorld.new(2_000_000, 1_500_000), events)
	equal(before - actor.health, 9_000, "explicit live linked source enables Plasma Arc damage")


func _test_contact_bound() -> void:
	var authority := _authority()
	authority.products[1] = _product(1, 317, {Vector2i.ZERO: 100})
	var actors: Array[PlayerState] = []
	for id: int in range(1, 15):
		actors.append(_actor(id + 10))
	Effects.step(authority, actors, 10, config, CollisionWorld.new(2_000_000, 1_500_000), [])
	equal(authority.products[1].contacts.size(), 12, "product authority retains at most twelve actor contact records")
