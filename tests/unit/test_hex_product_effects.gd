extends FluxTestSuite

## Direct actor-effect and independent geometry oracles for the live63 policies.
## Paid formation and input routes are covered by the separate integration suites.

const Effects = preload("res://src/sim/hex/hex_product_effects.gd")
const ORIGIN := Vector2i(600_000, 500_000)
var config := SimConfig.new(120)


func run() -> int:
	_test_zero_allocation_coverage_and_sweep_dedupe()
	_test_hailcurrent_visible_ground_steering()
	_test_pre_movement_exit_and_precedence()
	_test_contact_bound()
	_test_shared_path_equivalence()
	_test_endpoint_boundary_oracle()
	_test_endpoint_height_oracle()
	_test_endpoint_remains_pre_push()
	_test_realized_chemistry_damage_receipts()
	_test_six_element_trigger_counters()
	return finish("hex-product-effects")


func _test_realized_chemistry_damage_receipts() -> void:
	for scenario: String in ["mitigated", "threshold", "lethal"]:
		var authority := _authority()
		var product := _product(1, 335, {Vector2i.ZERO:100})
		product.pulse_damage = 6000
		authority.products[1] = product
		var actor := _actor()
		actor.champion_wire_id = 15 if scenario == "threshold" else 19
		actor.health_maximum = 100_000
		actor.health = 76_000 if scenario == "threshold" else (1000 if scenario == "lethal" else 100_000)
		actor.cast_recovery_ticks = 1 if scenario != "threshold" else 0
		var health_before := actor.health
		var events: Array = []
		Effects.step(authority, [actor], 10, config, CollisionWorld.new(2_000_000, 1_500_000), events)
		var expected := 6300 if scenario == "threshold" else (1000 if scenario == "lethal" else 5400)
		equal(actor.health, health_before - expected, "chemistry uses the pre-hit perk window: " + scenario)
		var hits := 0
		var defeats := 0
		for event: Dictionary in events:
			if String(event.get("type", "")) == "chemistry_hit":
				hits += 1
				equal(int(event.damage), expected, "chemistry receipt is exact realized Health loss: " + scenario)
			if String(event.get("type", "")) == "champion_defeated": defeats += 1
		equal(hits, 1, "one chemistry damage receipt")
		equal(defeats, 1 if scenario == "lethal" else 0, "chemistry keeps exact lethal attribution")


func _test_shared_path_equivalence() -> void:
	var authority := _authority()
	var product := _product(1,302,{Vector2i.ZERO:100,Vector2i(1,0):0})
	var membership := {Vector2i.ZERO:1,Vector2i(1,0):1,Vector2i(-1,0):1}
	var segments: Array[Array] = [
		[Vector2i(-96_000,0),Vector2i(96_000,0)],
		[Vector2i(12_000,-6000),Vector2i(12_000,6000)],
		[Vector2i(-1000,1000),Vector2i(2000,-2000)],
		[Vector2i(36_000,0),Vector2i(36_000,0)],
	]
	for wire: int in HexRecipePolicy.active_wire_ids():
		product.recipe_wire_id = wire
		for segment: Array in segments:
			for height: int in [0,17_999,18_000,48_000,48_001,60_000]:
				for previous_height: int in [0,60_000]:
					for wallrun: bool in [false,true]:
						var actor := _actor()
						actor.air_height = height
						actor.wall_skim_ticks = 2 if wallrun else 0
						var sample := {"start":ORIGIN+segment[0],"finish":ORIGIN+segment[1],"previous_height":previous_height,"height":height}
						var cached := sample.duplicate()
						cached.touched_cells = HexFootprint.traversed_selected_cells(membership,ORIGIN,sample.start,sample.finish)
						Effects._cache_endpoint(cached, ORIGIN)
						equal(Effects._endpoint_inside(authority,product,actor,sample.finish,cached),_legacy_endpoint_inside(authority,product,actor,sample.finish),"cached endpoint retains original actor-plane rules")
						for ground: bool in [false,true]:
							equal(Effects._path_touches(authority,product,actor,cached,ground),_legacy_path_touches(authority,product,actor,sample,ground),"shared path retains all63 plane/landing/wallrun/seam/zero-allocation rules")


# Frozen pre-endpoint-cache helpers. These deliberately do not call the new
# production membership adapter, so a shared cache bug cannot bless itself.
func _legacy_coverage(product: Dictionary) -> Dictionary:
	if product.has("coverage"):
		var stored: Variant = product.coverage
		return stored if stored is Dictionary else {}
	var result := {}
	var allocations: Variant = product.get("cells", {})
	if allocations is Dictionary:
		for cell: Variant in allocations:
			if cell is Vector2i and int(allocations[cell]) > 0:
				result[cell] = 1
	return result


func _legacy_endpoint_inside(authority: HexChemistryWorld, product: Dictionary, actor: PlayerState, point: Vector2i) -> bool:
	var policy := HexRecipePolicy.runtime_definition(int(product.get("recipe_wire_id", 0)))
	var maximum_height := 256_000 if bool(policy.get("ground_only", false)) else int(policy.get("maximum_height", 256_000))
	if actor.wall_skim_ticks <= 0 and actor.air_height > maximum_height:
		return false
	var coverage := _legacy_coverage(product)
	return not coverage.is_empty() and HexFootprint.contains_selected(coverage, authority.origin, point)


func _legacy_path_touches(authority: HexChemistryWorld, product: Dictionary, actor: PlayerState, sample: Dictionary, grounded_only: bool) -> bool:
	var policy := HexRecipePolicy.runtime_definition(int(product.get("recipe_wire_id", 0)))
	var requires_ground := grounded_only
	var maximum_height := MovementTuning.GROUND_PROJECTILE_CLEARANCE_HEIGHT if requires_ground else (256_000 if bool(policy.get("ground_only", false)) else int(policy.get("maximum_height", 256_000)))
	if requires_ground and MovementSystem.avoids_ground_effects(actor): return false
	if not requires_ground and actor.wall_skim_ticks <= 0 and actor.air_height > maximum_height: return false
	var finish: Vector2i = sample.finish
	var start: Vector2i = sample.start
	var previous_height := int(sample.previous_height)
	if actor.wall_skim_ticks <= 0 and ((requires_ground and previous_height >= maximum_height) or (not requires_ground and previous_height > maximum_height)):
		start = finish
	var coverage := _legacy_coverage(product)
	if coverage.is_empty(): return false
	if sample.has("touched_cells"):
		if start == finish: return HexFootprint.contains_selected(coverage,authority.origin,finish)
		for cell: Vector2i in sample.touched_cells:
			if HexFootprint._selected_cell_active(coverage,cell): return true
		return false
	return HexFootprint.touches_selected(coverage, authority.origin, start, finish)


func _test_endpoint_boundary_oracle() -> void:
	var authority := _authority()
	var actor := _actor()
	for origin: Vector2i in [ORIGIN, Vector2i(-7_900_000,0)]:
		authority.origin = origin
		var points: Array[Vector2i] = [origin, origin+Vector2i(11_999,0), origin+Vector2i(12_000,0), origin+Vector2i(12_001,0), Vector2i(8_000_000,0), Vector2i(8_000_001,0), Vector2i(-8_000_000,0), Vector2i(-8_000_001,0)]
		for vertex: Vector2i in HexGrid.vertices(Vector2i.ZERO):
			for delta: Vector2i in [Vector2i(-1,0),Vector2i.ZERO,Vector2i(1,0)]: points.append(origin+vertex+delta)
		for point: Vector2i in points:
			var owner := HexGrid.world_to_cell(point-origin)
			var product := _product(1,303,{owner:0})
			var endpoint := {"finish":point}
			Effects._cache_endpoint(endpoint,origin)
			for mode: int in range(7):
				product.coverage = {owner:1}
				if mode == 1: product.coverage = {owner:0}
				elif mode == 2: product.coverage = {owner:-1}
				elif mode == 3: product.coverage = {}
				elif mode == 4: product.coverage = "invalid"
				elif mode >= 5:
					product.erase("coverage")
					product.cells = {owner:100 if mode == 5 else 0}
				var expected := _legacy_endpoint_inside(authority,product,actor,point)
				equal(Effects._endpoint_inside(authority,product,actor,point,endpoint),expected,"cached owner preserves validity, signed seams and positive/fallback coverage")
				equal(Effects._endpoint_inside(authority,product,actor,point),expected,"uncached endpoint remains supported")
				authority.products = {1:product}
				var modifiers := Effects.pre_movement(authority,actor,10,{"point":point},config)
				equal(int(modifiers.acceleration_ratio),700 if expected else 1000,"pre-movement resolves its own explicit point with the original membership")
				var sample := {"start":point,"finish":point,"previous_height":0,"height":0,"touched_cells":[]}
				Effects._cache_endpoint(sample,origin)
				equal(Effects._path_touches(authority,product,actor,sample,true),_legacy_path_touches(authority,product,actor,sample,true),"stationary cached path retains invalid and boundary behavior")


func _test_endpoint_height_oracle() -> void:
	var authority := _authority()
	var actor := _actor()
	var product := _product(1,302,{Vector2i.ZERO:100})
	for wire: int in [302,321,336]:
		product.recipe_wire_id = wire
		for height: int in [17_999,18_000,18_001,255_999,256_000,256_001]:
			actor.air_height = height
			for previous_height: int in [17_999,18_000,18_001,256_000,256_001]:
				for wallrun: bool in [false,true]:
					actor.wall_skim_ticks = 1 if wallrun else 0
					for start: Vector2i in [ORIGIN,ORIGIN+Vector2i(96_000,0),Vector2i(8_000_001,0)]:
						var sample := {"start":start,"finish":ORIGIN,"previous_height":previous_height,"height":height}
						sample.touched_cells = HexFootprint.traversed_selected_cells(product.coverage,ORIGIN,start,ORIGIN)
						var cached := sample.duplicate()
						Effects._cache_endpoint(cached,ORIGIN)
						equal(Effects._endpoint_inside(authority,product,actor,ORIGIN,cached),_legacy_endpoint_inside(authority,product,actor,ORIGIN),"endpoint height equality and wallrun match original")
						for ground: bool in [false,true]:
							equal(Effects._path_touches(authority,product,actor,cached,ground),_legacy_path_touches(authority,product,actor,sample,ground),"ground >= and upper-plane > landing boundaries remain distinct")


func _test_endpoint_remains_pre_push() -> void:
	var authority := _authority()
	authority.products[1] = _product(1,317,{Vector2i.ZERO:100}, 2)
	authority.products[2] = _product(2,302,{Vector2i(1,0):100})
	var point := ORIGIN+Vector2i(11_999,0)
	var actor := _actor(2,2,point)
	var before := actor.health
	var events: Array = []
	Effects.step(authority,[actor],10,config,CollisionWorld.new(2_000_000,1_500_000),events)
	check(actor.position_x > ORIGIN.x+12_000,"first product pushes the live actor across the canonical face")
	equal(actor.health,before,"later Magma cannot damage a manufactured post-push entry")
	check(not authority.products[2].contacts.has(actor.entity_id),"later product keeps the common frozen pre-push endpoint")
	equal(events.size(),1,"only the original field emits its single flow event")
	Effects.step(authority,[actor],11,config,CollisionWorld.new(2_000_000,1_500_000),[])
	check(authority.products[2].contacts.has(actor.entity_id),"next effects call captures the new endpoint instead of retaining a stale owner")
	if authority.products[2].contacts.has(actor.entity_id):
		check(bool(authority.products[2].contacts[actor.entity_id].inside),"fresh next-call endpoint is inside the second product")


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
		"strength": 10, "funded_strength": 20, "damage_budget_remaining": 80_000,
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
	equal(actor.chemistry_conceal_ticks, 0, "unified Sandblast pressure keeps actors visible")
	check(Vector2i(actor.position_x, actor.position_y) != ORIGIN + Vector2i(96_000, 0), "canonical swept foot traversal applies Sandblast once")
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
	actor.air_dodge_ticks = config.milliseconds_to_ticks(MovementTuning.AIR_DODGE_DURATION_MS)
	equal(Effects.pre_movement(authority, actor, 10, ORIGIN, config), {"acceleration_ratio": 1000, "braking_ratio": 1000, "ground_target_ratio": 1000}, "combat intangibility blocks physical Mud and Magma movement effects")
	actor.air_dodge_ticks = 0
	actor.team_id = 2
	authority.products[3] = _product(3, 331, {Vector2i.ZERO: 100})
	modifiers = Effects.pre_movement(authority, actor, 10, ORIGIN, config)
	equal(modifiers.ground_target_ratio, 750, "retired Charge metadata cannot override active Magma")
	authority.products.erase(2)
	equal(Effects.pre_movement(authority, actor, 10, ORIGIN, config).ground_target_ratio, 1000, "retired standalone Charge recipe cannot provide a hidden movement bonus")
	authority.products[4] = _product(4, 316, {Vector2i.ZERO: 100})
	equal(Effects.pre_movement(authority, actor, 10, ORIGIN, config).ground_target_ratio, 750, "active Frostway is unaffected by retired Charge metadata")
	actor.air_height = MovementTuning.GROUND_PROJECTILE_CLEARANCE_HEIGHT
	equal(Effects.pre_movement(authority, actor, 10, ORIGIN, config).ground_target_ratio, 1000, "airborne movement above clearance ignores ground product ratios")


func _test_hailcurrent_visible_ground_steering() -> void:
	var authority := _authority()
	authority.products[1] = _product(1, 317, {Vector2i.ZERO: 100, Vector2i(1,0): 100})
	# Cross two24px cells throughout the unchanged25px flow journey.
	var actor := _actor(2, 1, ORIGIN)
	var start := Vector2i(actor.position_x, actor.position_y)
	var events: Array = []
	var collision := CollisionWorld.new(2_000_000, 1_500_000)
	var intangible := _actor(3, 1)
	intangible.air_dodge_ticks = config.milliseconds_to_ticks(MovementTuning.AIR_DODGE_DURATION_MS)
	var intangible_start := Vector2i(intangible.position_x, intangible.position_y)
	Effects.step(authority, [intangible], 10, config, collision, events)
	equal(Vector2i(intangible.position_x, intangible.position_y), intangible_start, "combat intangibility blocks friendly physical flow")
	for tick: int in range(10, 130):
		Effects.step(authority, [actor], tick, config, collision, events)
	equal(Vector2i(actor.position_x, actor.position_y) - start, Vector2i(25_000, 0), "Hailcurrent gives its caster exactly25k one-second steering through authority carry")
	equal(authority.flow_carry["1:2"], Vector2i.ZERO, "directional fractional carry closes exactly after120 ticks")
	equal(actor.chemistry_conceal_ticks, 0, "Hailcurrent keeps actors visible")
	var grounded_position := Vector2i(actor.position_x, actor.position_y)
	authority.products[1].contacts.clear()
	actor.air_height = MovementTuning.GROUND_PROJECTILE_CLEARANCE_HEIGHT
	Effects.step(authority, [actor], 130, config, collision, events)
	equal(Vector2i(actor.position_x, actor.position_y), grounded_position, "airborne actor bypasses Hailcurrent steering")
	var vortex := _product(2, 322, {Vector2i.ZERO: 100})
	authority.products.clear()
	authority.products[2] = vortex
	actor.air_height = 0
	actor.position_x = ORIGIN.x + 10_000
	actor.position_y = ORIGIN.y
	var vortex_start := Vector2i(actor.position_x, actor.position_y)
	Effects.step(authority, [actor], 131, config, collision, events)
	check(actor.position_y > vortex_start.y, "Vortex tangential utility also moves its owning team")


func _test_contact_bound() -> void:
	var authority := _authority()
	authority.products[1] = _product(1, 317, {Vector2i.ZERO: 100})
	var actors: Array[PlayerState] = []
	for id: int in range(1, 15):
		actors.append(_actor(id + 10))
	Effects.step(authority, actors, 10, config, CollisionWorld.new(2_000_000, 1_500_000), [])
	equal(authority.products[1].contacts.size(), 12, "product authority retains at most twelve actor contact records")


func _test_six_element_trigger_counters() -> void:
	var collision := CollisionWorld.new(2_000_000, 1_500_000)
	# Sandblast cannot be farmed by oscillating across its boundary.
	var world := _authority()
	world.products[1] = _product(1, 304, {Vector2i.ZERO: 100})
	var actor := _actor()
	var health := actor.health
	Effects.step(world, [actor], 10, config, collision, [])
	equal(health - actor.health, 6000, "Sandblast has one exact grounded attack")
	for tick: int in range(11, 20):
		var previous := Vector2i(actor.position_x, actor.position_y)
		actor.position_x = ORIGIN.x if tick % 2 == 0 else ORIGIN.x + 96_000
		actor.position_y = ORIGIN.y
		Effects.step(world, [actor], tick, config, collision, [], {actor.entity_id: previous})
	equal(health - actor.health, 6000, "edge oscillation cannot regenerate Sandblast damage")
	# Mirrorwater rewards holding a position, unlike the plain reveal field.
	world = _authority(); world.products[1] = _product(1, 320, {Vector2i.ZERO: 100})
	actor = _actor(); health = actor.health
	Effects.step(world, [actor], 10, config, collision, [])
	equal(actor.health, health, "still Mirrorwater occupant avoids damage")
	actor.velocity_x = 3000
	Effects.step(world, [actor], 70, config, collision, [])
	equal(health - actor.health, 3000, "moving Mirrorwater occupant triggers its pulse")
	# Backdraft's warning is harmless; only its terminal clock releases damage.
	world = _authority(); world.products[1] = _product(1, 315, {Vector2i.ZERO: 100})
	actor = _actor(); health = actor.health
	Effects.step(world, [actor], 427, config, collision, [])
	equal(actor.health, health, "Backdraft does not cause premature ember damage")
	check(not Effects._concealing(world.products[1], 315, 428, config), "Backdraft exposes its final600ms warning")
	Effects.step(world, [actor], 499, config, collision, [])
	equal(health - actor.health, 12000, "Backdraft detonates at its exact terminal tick")
	Effects.step(world, [actor], 499, config, collision, [])
	equal(health - actor.health, 12000, "same tick cannot repeat terminal damage")
	# Overlapping currents share one movement application per actor/tick.
	world = _authority()
	world.products[1] = _product(1, 317, {Vector2i.ZERO:100}, 2)
	world.products[2] = _product(2, 317, {Vector2i.ZERO:100}, 2)
	actor = _actor(); var start := actor.position_x
	Effects.step(world, [actor], 10, config, collision, [])
	equal(actor.position_x - start, 208, "two paid currents cannot stack forced displacement")
