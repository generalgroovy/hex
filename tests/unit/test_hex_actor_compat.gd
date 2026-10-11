extends FluxTestSuite

## Actor adapter boundaries for the current six-element products. These isolated
## records have explicit ten-strength finite damage pools; paid formation and
## snapshot provenance are tested separately by the actual Hex world suites.

const Effects = preload("res://src/sim/hex/hex_product_effects.gd")
const RecipePolicy = preload("res://src/sim/hex/hex_recipe_policy.gd")
const ORIGIN := Vector2i(600_000, 500_000)
var config := SimConfig.new(120)


func run() -> int:
	_test_zero_period_is_one_shared_activation_pulse()
	_test_arcstorm_standalone_and_broken_links()
	_test_black_ice_entry_and_grounded_exit()
	_test_retired_actor_wires_are_inert()
	_test_later_products_block_sight()
	_test_shadowdraft_alternating_sight_bands()
	_test_first_four_products_stay_transparent()
	_test_sight_range_footprint_and_active_phase_boundaries()
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
		"strength": 10,
		"funded_strength": 20,
		"damage_budget_remaining": 80_000,
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


func _step(authority: HexChemistryWorld, actors: Array[PlayerState], tick: int, paths: Dictionary = {}) -> void:
	Effects.step(authority, actors, tick, config, CollisionWorld.new(2_000_000, 1_500_000), [], paths)


func _crossing_observer() -> Vector2i:
	return ORIGIN - Vector2i(160_000, 0)


func _crossing_target() -> Vector2i:
	return ORIGIN + Vector2i(160_000, 0)


func _test_zero_period_is_one_shared_activation_pulse() -> void:
	var authority := _authority()
	var flare := _product(1, 314)
	flare.pulse_ms = 0
	authority.products[1] = flare
	var first := _actor(2)
	var second := _actor(3)
	var initial_health := first.health
	_step(authority, [first, second], 10)
	var reveal_ticks := config.milliseconds_to_ticks(700)
	equal(first.chemistry_reveal_ticks, reveal_ticks, "Solar Flare activation reveals the first actor")
	equal(second.chemistry_reveal_ticks, reveal_ticks, "one product pulse is shared by every actor in that tick")
	equal(int(authority.products[1].pulse_index), 0, "zero-period activation consumes the canonical product pulse")
	equal(first.health, initial_health - 6_000, "Solar Flare activation spends one exact full-strength flash")
	equal(second.health, initial_health - 6_000, "shared activation can hit each eligible actor once")
	equal(int(flare.damage_budget_remaining), 68_000, "both realized Health losses debit one shared finite pool")
	first.chemistry_reveal_ticks = 0
	second.chemistry_reveal_ticks = 0
	_step(authority, [first, second], 11)
	equal(first.chemistry_reveal_ticks, 0, "zero-period Solar Flare does not refresh on its next active tick")
	equal(second.chemistry_reveal_ticks, 0, "zero-period pulse remains consumed for every actor")

	# A restored or otherwise first-processed product still owns its one attempt;
	# legacy pulse_index, rather than equality with active_tick, is authoritative.
	var late := _product(2, 314)
	late.pulse_ms = 0
	authority.products.clear()
	authority.products[2] = late
	first = _actor(4)
	first.chemistry_reveal_ticks = 0
	_step(authority, [first], 12)
	equal(first.chemistry_reveal_ticks, reveal_ticks, "unconsumed Solar Flare pulses once when first processed after activation")
	first.chemistry_reveal_ticks = 0
	_step(authority, [first], 13)
	equal(first.chemistry_reveal_ticks, 0, "late first processing cannot make a zero-period impulse repeat")


func _test_arcstorm_standalone_and_broken_links() -> void:
	var authority := _authority()
	var arc := _product(1, 311)
	authority.products[1] = arc
	var actor := _actor(2)
	var before := actor.health
	_step(authority, [actor], 10)
	equal(before - actor.health, 9_000, "unlinked Arcstorm has its independently bounded electrical activation")
	equal(int(arc.damage_budget_remaining), 71_000, "electrical activation debits actual Health from its own finite pool")

	# An explicitly selected chain is different from a standalone origin. Every
	# selected link must stay live; losing one disables the connected discharge.
	arc.contacts.clear()
	arc.pulse_index = -1
	arc.linked_sources = [9001]
	actor = _actor(3)
	before = actor.health
	_step(authority, [actor], 10)
	equal(actor.health, before, "a missing explicitly selected Fire link disables the connected electrical attempt")
	authority.sources[9001] = 20
	authority.casts[20] = {"element": 2, "wire": 145, "expires": 100, "coverage": {Vector2i.ZERO: 1}}
	arc.contacts.clear()
	arc.pulse_index = -1
	actor = _actor(4)
	before = actor.health
	_step(authority, [actor], 10)
	equal(before - actor.health, 9_000, "a live explicitly selected Fire link permits the finite connected attempt")
	for invalid_link: String in ["expired", "empty"]:
		authority.casts[20].expires = 10 if invalid_link == "expired" else 100
		authority.casts[20].coverage = {} if invalid_link == "empty" else {Vector2i.ZERO: 1}
		arc.contacts.clear(); arc.pulse_index = -1
		actor = _actor(5)
		before = actor.health
		_step(authority, [actor], 10)
		equal(actor.health, before, "an expired or empty linked Fire footprint cannot discharge: " + invalid_link)


func _test_black_ice_entry_and_grounded_exit() -> void:
	var authority := _authority()
	var ice := _product(1, 321)
	authority.products[1] = ice
	var airborne := _actor(2)
	airborne.air_height = 80_000
	airborne.air_vertical_velocity = 1
	airborne.velocity_x = 100_000
	_step(authority, [airborne], 10)
	equal(airborne.chemistry_reveal_ticks, config.milliseconds_to_ticks(250), "Black Ice moving reveal remains visible at playable air height")
	equal(airborne.control_state, PlayerState.ControlState.FREE, "Black Ice entry slow remains restricted to grounded actors")

	var grounded := _actor(3)
	var before := grounded.health
	_step(authority, [grounded], 10)
	equal(grounded.control_state, PlayerState.ControlState.SLOWED, "current Black Ice briefly slows on grounded entry")
	equal(grounded.slow_ratio, 650, "entry slow has an independent65percent bound")
	equal(grounded.control_ticks, config.milliseconds_to_ticks(250), "entry slow has an independent250ms duration")
	_step(authority, [grounded], 11)
	equal(grounded.health, before, "entry and continued occupation do not trigger the exit fracture")
	grounded.position_x += 100_000
	_step(authority, [grounded], 12, {3: {"point": ORIGIN, "height": 0}})
	equal(grounded.health, before - 4_000, "first actual grounded exit fractures for exactly4Health")
	equal(int(ice.damage_budget_remaining), 76_000, "exit fracture spends exactly its realized finite damage")
	grounded.position_x = ORIGIN.x
	_step(authority, [grounded], 13)
	grounded.position_x += 100_000
	_step(authority, [grounded], 14, {3: {"point": ORIGIN, "height": 0}})
	equal(grounded.health, before - 4_000, "reentry and another exit cannot repeat the spent actor fracture")
	var jumper := _actor(4)
	_step(authority, [jumper], 15)
	before = jumper.health
	jumper.air_height = 80_000
	jumper.position_x += 100_000
	_step(authority, [jumper], 16, {4: {"point": ORIGIN, "height": 80_000}})
	equal(jumper.health, before, "jumping out avoids the grounded exit fracture")


func _test_retired_actor_wires_are_inert() -> void:
	var authority := _authority()
	for wire: int in [305, 306, 312, 313, 318, 319, 323, 324, 327, 328, 329, 330, 331, 332, 333]:
		authority.products.clear()
		authority.products[wire] = _product(wire, wire)
		var actor := _actor(2)
		var before := actor.canonical_values()
		_step(authority, [actor], 10)
		check(RecipePolicy.definition(wire).is_empty(), "retired archive recipe has no live definition")
		equal(actor.canonical_values(), before, "retired actor wire cannot leak an old damage, slow, reveal or conceal effect")
		check(not Effects.blocks_sight(authority, _crossing_observer(), _crossing_target(), 10, config), "retired visual identity never becomes live concealment")


func _test_later_products_block_sight() -> void:
	var authority := _authority()
	for wire: int in [315, 326, 336]:
		authority.products.clear()
		authority.products[wire] = _product(wire, wire)
		check(Effects.blocks_sight(authority, _crossing_observer(), _crossing_target(), 10, config), "later conceal wire %d blocks a far sight segment through its selected whole hex" % wire)
	for wire: int in [321, 335]:
		authority.products.clear()
		authority.products[wire] = _product(wire, wire)
		check(not Effects.blocks_sight(authority, _crossing_observer(), _crossing_target(), 10, config), "current Ice fracture and optical boundary remain visible to opponents")


func _test_shadowdraft_alternating_sight_bands() -> void:
	var authority := _authority()
	authority.products[326] = _product(326, 326)
	var band_ticks := config.milliseconds_to_ticks(300)
	check(Effects.blocks_sight(authority, _crossing_observer(), _crossing_target(), 10, config), "Shadowdraft conceals during its first authored band")
	check(not Effects.blocks_sight(authority, _crossing_observer(), _crossing_target(), 10 + band_ticks, config), "Shadowdraft opens during its second authored band")
	check(Effects.blocks_sight(authority, _crossing_observer(), _crossing_target(), 10 + band_ticks * 2, config), "Shadowdraft conceals again during its third authored band")


func _test_first_four_products_stay_transparent() -> void:
	var authority := _authority()
	for wire: int in RecipePolicy.FIRST_TEN_WIRES:
		authority.products.clear()
		authority.products[wire] = _product(wire, wire)
		check(not Effects.blocks_sight(authority, _crossing_observer(), _crossing_target(), 10, config), "first-four product wire %d remains sight-transparent" % wire)


func _test_sight_range_footprint_and_active_phase_boundaries() -> void:
	var authority := _authority()
	var veil := _product(315, 315)
	authority.products[315] = veil
	var before: Dictionary = authority.products.duplicate(true)
	check(not Effects.blocks_sight(authority, ORIGIN - Vector2i(32_000, 0), ORIGIN + Vector2i(32_000, 0), 10, config), "a silhouette exactly64 px away remains readable")
	check(Effects.blocks_sight(authority, ORIGIN - Vector2i(32_001, 0), ORIGIN + Vector2i(32_001, 0), 10, config), "a silhouette beyond64 px can be concealed by a crossed whole hex")
	check(not Effects.blocks_sight(authority, ORIGIN + Vector2i(-160_000, 100_000), ORIGIN + Vector2i(160_000, 100_000), 10, config), "a far segment outside stored coverage remains visible")
	check(not Effects.blocks_sight(authority, _crossing_observer(), _crossing_target(), 9, config), "a forming product cannot block sight")
	check(not Effects.blocks_sight(authority, _crossing_observer(), _crossing_target(), 500, config), "a decaying product cannot block sight")
	equal(authority.products, before, "sight queries do not mutate authoritative products")
	authority.products[315].decay_tick = 600
	check(not Effects.blocks_sight(authority, _crossing_observer(), _crossing_target(), 560, config), "an expired product cannot block sight")
