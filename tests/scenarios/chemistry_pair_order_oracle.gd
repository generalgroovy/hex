extends SceneTree
@warning_ignore_start("integer_division")

# Inert standalone differential corpus. The integration owner may copy this to
# tests/scenarios/chemistry_pair_order_oracle.gd and run it explicitly. It is
# never registered in the ordinary suite and contains no timing acceptance.
#
# Production ElementChemistrySystem.step may later move the occupied-cell gate
# before pair-gate clear_line. OldOrder must remain the preserved observer whose
# decision order is reach -> clear_line -> occupied cell.
const Chemistry = preload("res://src/sim/chemistry/element_chemistry_system.gd")
const OldOrder = preload("res://tests/scenarios/runtime_chemistry_stage_sampler.gd")

const PAIR_START := Vector2i(500_000, 500_000)
const NEXT_REACTION_ID: int = 9_000
const TERMINAL_REACH: int = 80_000


class CountingCollisionWorld:
	extends CollisionWorld
	var can_occupy_calls: int = 0

	func can_occupy(position: Vector2i, radius: int, ignored_obstacle_id: int = -1) -> bool:
		can_occupy_calls += 1
		return super.can_occupy(position, radius, ignored_obstacle_id)


var config := SimConfig.new(120)
var assertions: int = 0
var failures: int = 0
var cases: int = 0
var production_collision_queries: int = 0
var observer_collision_queries: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# Every authored pair, with each element assigned to the lower stable entity.
	# Reversed input arrays also prove that step's stable ID sort owns admission.
	for wire: int in range(301, 337):
		for swap_elements: bool in [false, true]:
			_compare_case(
				"wire%d-elements-%s" % [wire, "reversed" if swap_elements else "forward"],
				Callable(self, "_pair_case"),
				[wire, swap_elements, 40_000],
				{"deposits":0, "reactions":1, "events":1, "next_delta":1, "new_wire":wire},
			)

	# Exact terminal reach boundaries use two40px terminal footprints.
	for offset: int in [-1, 0, 1]:
		_compare_case(
			"reach-offset-%d" % offset,
			Callable(self, "_pair_case"),
			[302, false, TERMINAL_REACH + offset],
			{"deposits":0 if offset <= 0 else 2, "reactions":1 if offset <= 0 else 0, "events":1 if offset <= 0 else 0, "next_delta":1 if offset <= 0 else 0, "new_wire":302 if offset <= 0 else 0},
		)

	# An occupied midpoint is final regardless of whether the old-order LOS test
	# is clear or blocked. These are the direct future-reorder equivalence cases.
	_compare_case("occupied-midpoint-clear-los", Callable(self, "_occupied_case"), [false],
		{"deposits":2, "reactions":1, "events":0, "next_delta":0, "new_wire":0})
	_compare_case("occupied-midpoint-blocked-los", Callable(self, "_occupied_case"), [true],
		{"deposits":2, "reactions":1, "events":0, "next_delta":0, "new_wire":0})
	_compare_case("unoccupied-midpoint-blocked-los", Callable(self, "_blocked_unoccupied_case"), [],
		{"deposits":2, "reactions":0, "events":0, "next_delta":0, "new_wire":0})

	# Deposit wire validation is non-negative, so signed authoritative coverage
	# uses the reaction coordinate range (-1,000,000 is valid) while deposit-pair
	# admission exercises the exact low/high map boundaries.
	_compare_case("signed-existing-reaction", Callable(self, "_signed_reaction_case"), [],
		{"deposits":0, "reactions":1, "events":0, "next_delta":0, "new_wire":0})
	_compare_case("low-map-boundary-tangent", Callable(self, "_boundary_case"), [false],
		{"deposits":0, "reactions":1, "events":1, "next_delta":1, "new_wire":302})
	_compare_case("high-map-boundary-tangent", Callable(self, "_boundary_case"), [true],
		{"deposits":0, "reactions":1, "events":1, "next_delta":1, "new_wire":302})

	_compare_case("same-source-cast", Callable(self, "_same_cast_case"), [],
		{"deposits":2, "reactions":0, "events":0, "next_delta":0, "new_wire":0})
	_compare_case("older-trail-newer-terminal", Callable(self, "_trail_case"), ["allowed"],
		{"deposits":0, "reactions":1, "events":1, "next_delta":1, "new_wire":302})
	_compare_case("newer-trail-older-terminal", Callable(self, "_trail_case"), ["rejected"],
		{"deposits":2, "reactions":0, "events":0, "next_delta":0, "new_wire":0})
	_compare_case("trail-with-trail", Callable(self, "_trail_case"), ["two_trails"],
		{"deposits":2, "reactions":0, "events":0, "next_delta":0, "new_wire":0})

	_compare_case("multiple-eligible-stable-pair", Callable(self, "_multiple_pair_case"), [],
		{"deposits":1, "reactions":1, "events":1, "next_delta":1, "new_wire":302, "source_a":101, "source_b":102})
	_compare_case("newly-occupied-cell-keeps-second-pair", Callable(self, "_newly_occupied_case"), [],
		{"deposits":2, "reactions":1, "events":1, "next_delta":1, "new_wire":302, "source_a":101, "source_b":102})
	_compare_case("max128-fills-reaction32", Callable(self, "_maximum_case"), [31],
		{"deposits":126, "reactions":32, "events":1, "next_delta":1, "new_wire":302})
	_compare_case("max128-preserved-at-reaction32", Callable(self, "_maximum_case"), [32],
		{"deposits":128, "reactions":32, "events":0, "next_delta":0, "new_wire":0})

	print("%s: chemistry-pair-order-oracle; %d assertions; %d failures; %d deterministic cases" % [
		"PASS" if failures == 0 else "FAIL", assertions, failures, cases,
	])
	print("CHEMISTRY_PAIR_ORDER_QUERY_TOTALS ", JSON.stringify({
		"production_can_occupy_calls": production_collision_queries,
		"old_order_can_occupy_calls": observer_collision_queries,
		"comparison": "diagnostic counts only; output equivalence is the acceptance gate",
	}))
	quit(0 if failures == 0 else 1)


func _compare_case(label: String, factory: Callable, arguments: Array, expected: Dictionary) -> void:
	cases += 1
	var production: Dictionary = factory.callv(arguments)
	var observer: Dictionary = factory.callv(arguments)
	_validate_inputs(label + " production", production)
	_validate_inputs(label + " observer", observer)

	var production_next := Chemistry.step(
		production.deposits,
		production.reactions,
		production.actors,
		production.collision,
		config,
		int(production.tick),
		int(production.next_reaction_id),
		production.events,
	)
	var old_result: Dictionary = OldOrder.measured_step(
		observer.deposits,
		observer.reactions,
		observer.actors,
		observer.collision,
		config,
		int(observer.tick),
		int(observer.next_reaction_id),
		observer.events,
	)
	_check(bool(old_result.get("ok", false)), label + " old-order observer completes")
	var observer_next := int(old_result.get("next_reaction_id", -1))

	_check(_ordered_values(production.deposits) == _ordered_values(observer.deposits), label + " ordered deposits agree")
	_check(_ordered_values(production.reactions) == _ordered_values(observer.reactions), label + " ordered reactions agree")
	_check(_ordered_values(production.actors) == _ordered_values(observer.actors), label + " ordered actors agree")
	_check(production_next == observer_next, label + " next reaction ID agrees")
	_check(production.events == observer.events, label + " ordered events agree")
	var production_queries := int(production.collision.can_occupy_calls)
	var old_order_queries := int(observer.collision.can_occupy_calls)
	production_collision_queries += production_queries
	observer_collision_queries += old_order_queries
	print("CHEMISTRY_PAIR_ORDER_QUERY_CASE ", JSON.stringify({
		"case": label,
		"production_can_occupy_calls": production_queries,
		"old_order_can_occupy_calls": old_order_queries,
	}))

	_check(production.deposits.size() == int(expected.deposits), label + " expected deposit count")
	_check(production.reactions.size() == int(expected.reactions), label + " expected reaction count")
	_check(production.events.size() == int(expected.events), label + " expected event count")
	_check(production_next == int(production.next_reaction_id) + int(expected.next_delta), label + " expected next-ID delta")
	if int(expected.get("new_wire", 0)) > 0:
		var formed := _reaction_by_id(production.reactions, int(production.next_reaction_id))
		_check(formed != null, label + " expected reaction identity exists")
		if formed != null:
			_check(formed.recipe_wire_id == int(expected.new_wire), label + " expected recipe wins")
			if expected.has("source_a"):
				_check(formed.source_a == int(expected.source_a), label + " expected stable source A wins")
				_check(formed.source_b == int(expected.source_b), label + " expected stable source B wins")

	for deposit: ElementDepositState in production.deposits:
		_check(deposit.validate(), label + " output deposit remains canonical")
	for reaction: ElementReactionState in production.reactions:
		_check(reaction.validate(), label + " output reaction remains canonical")


func _pair_case(wire: int, swap_elements: bool, separation: int) -> Dictionary:
	var elements: Array = Chemistry.recipe(wire).elements
	var first_element := int(elements[1] if swap_elements else elements[0])
	var second_element := int(elements[0] if swap_elements else elements[1])
	var first := _terminal(1, 101, first_element, PAIR_START, 0)
	var second := _terminal(2, 102, second_element, PAIR_START + Vector2i(separation, 0), 0)
	return _case([second, first] if swap_elements else [first, second], [], [], 0, NEXT_REACTION_ID, 2_000_000, 2_000_000)


func _occupied_case(blocked: bool) -> Dictionary:
	var midpoint := PAIR_START + Vector2i(20_000, 0)
	var existing := _reaction(7_000, 303, midpoint, 7_101)
	var result := _case([
		_terminal(1, 101, 1, PAIR_START, 0),
		_terminal(2, 102, 2, PAIR_START + Vector2i(40_000, 0), 0),
	], [existing], [], 0, NEXT_REACTION_ID, 2_000_000, 2_000_000)
	if blocked:
		result.collision.add_obstacle(CollisionWorld.Obstacle.new(11, midpoint.x - 2_000, 0, midpoint.x + 2_000, 2_000_000))
	return result


func _blocked_unoccupied_case() -> Dictionary:
	var midpoint := PAIR_START + Vector2i(20_000, 0)
	var result := _case([
		_terminal(1, 101, 1, PAIR_START, 0),
		_terminal(2, 102, 2, PAIR_START + Vector2i(40_000, 0), 0),
	], [], [], 0, NEXT_REACTION_ID, 2_000_000, 2_000_000)
	result.collision.add_obstacle(CollisionWorld.Obstacle.new(12, midpoint.x - 2_000, 0, midpoint.x + 2_000, 2_000_000))
	return result


func _signed_reaction_case() -> Dictionary:
	var signed := _reaction(7_000, 303, Vector2i(-900_000, -900_000), 7_201)
	return _case([], [signed], [], 0, NEXT_REACTION_ID, 2_000_000, 2_000_000)


func _boundary_case(high: bool) -> Dictionary:
	var first_position := Vector2i(1_920_000, 2_000_000) if high else Vector2i.ZERO
	var second_position := first_position + Vector2i(TERMINAL_REACH, 0)
	return _case([
		_terminal(1, 101, 1, first_position, 0),
		_terminal(2, 102, 2, second_position, 0),
	], [], [], 0, NEXT_REACTION_ID, 2_000_000, 2_000_000)


func _same_cast_case() -> Dictionary:
	return _case([
		_terminal(1, 101, 1, PAIR_START, 0),
		_terminal(2, 101, 2, PAIR_START + Vector2i(40_000, 0), 0),
	], [], [], 0, NEXT_REACTION_ID, 2_000_000, 2_000_000)


func _trail_case(mode: String) -> Dictionary:
	var deposits: Array = []
	var tick := 1
	if mode == "allowed":
		deposits = [
			_terminal(1, 101, 1, PAIR_START, 0, true),
			_terminal(2, 102, 2, PAIR_START + Vector2i(40_000, 0), 1),
		]
	elif mode == "rejected":
		deposits = [
			_terminal(1, 101, 1, PAIR_START, 0),
			_terminal(2, 102, 2, PAIR_START + Vector2i(40_000, 0), 1, true),
		]
	else:
		deposits = [
			_terminal(1, 101, 1, PAIR_START, 0, true),
			_terminal(2, 102, 2, PAIR_START + Vector2i(30_000, 0), 0, true),
		]
	return _case(deposits, [], [], tick, NEXT_REACTION_ID, 2_000_000, 2_000_000)


func _multiple_pair_case() -> Dictionary:
	# Deliberately reverse input order. Stable entity1+entity2 must form before
	# the also-eligible entity1+entity3 combination.
	var first := _terminal(1, 101, 1, PAIR_START, 0)
	var second := _terminal(2, 102, 2, PAIR_START + Vector2i(40_000, 0), 0)
	var third := _terminal(3, 103, 3, PAIR_START + Vector2i(20_000, 20_000), 0)
	return _case([third, second, first], [], _actors(1_800_000), 0, NEXT_REACTION_ID, 2_000_000, 2_000_000)


func _newly_occupied_case() -> Dictionary:
	# The first pair reserves cell(5,5); the disjoint second pair must remain
	# unconsumed even though its own LOS and reach are clear in the same step.
	return _case([
		_terminal(4, 104, 2, PAIR_START + Vector2i(60_000, 0), 0),
		_terminal(3, 103, 1, PAIR_START + Vector2i(40_000, 0), 0),
		_terminal(2, 102, 2, PAIR_START + Vector2i(20_000, 0), 0),
		_terminal(1, 101, 1, PAIR_START, 0),
	], [], _actors(1_800_000), 0, NEXT_REACTION_ID, 2_000_000, 2_000_000)


func _maximum_case(existing_reaction_count: int) -> Dictionary:
	var deposits: Array = [
		_terminal(1, 101, 1, Vector2i(1_000_000, 1_000_000), 0),
		_terminal(2, 102, 2, Vector2i(1_040_000, 1_000_000), 0),
	]
	for index: int in range(2, Chemistry.MAX_DEPOSITS):
		var column := (index - 2) % 16
		var row := (index - 2) / 16
		deposits.append(_terminal(index + 1, 1_000 + index, 1 + index % 8,
			Vector2i(3_000_000 + column * 200_000, 3_000_000 + row * 200_000), 0))
	var reactions: Array = []
	for index: int in range(existing_reaction_count):
		var column := index % 8
		var row := index / 8
		reactions.append(_reaction(7_000 + index, 303,
			Vector2i(7_000_000 + column * 200_000, 7_000_000 + row * 200_000), 20_000 + index * 2))
	return _case(deposits, reactions, _actors(9_000_000), 0, NEXT_REACTION_ID, 10_000_000, 10_000_000)


func _case(deposits: Array, reactions: Array, actors: Array, tick: int, next_reaction_id: int, width: int, height: int) -> Dictionary:
	return {
		"deposits": deposits,
		"reactions": reactions,
		"actors": actors,
		"collision": CountingCollisionWorld.new(width, height),
		"tick": tick,
		"next_reaction_id": next_reaction_id,
		"events": [],
	}


func _terminal(entity_id: int, cast_id: int, element: int, position: Vector2i, created_tick: int, trail: bool = false) -> ElementDepositState:
	var values: Array = []
	var admitted := Chemistry.deposit_terminal(
		values, entity_id, cast_id, 100, 1 + entity_id % 8, 1 + entity_id % 8,
		element, position, created_tick, config, Vector2i(1000, 0), 1_000, trail,
	)
	_check(admitted == 1 and values.size() == 1, "fixture terminal admits as canonical state")
	return values[0] if values.size() == 1 else ElementDepositState.new()


func _reaction(entity_id: int, wire: int, origin: Vector2i, source_base: int) -> ElementReactionState:
	var elements: Array = Chemistry.recipe(wire).elements
	var first := _terminal(source_base, source_base, int(elements[0]), Vector2i(500_000, 500_000), 0)
	var second := _terminal(source_base + 1, source_base + 1, int(elements[1]), Vector2i(520_000, 500_000), 0)
	var result := Chemistry.form_reaction(first, second, entity_id, 0, config)
	result.position_x = origin.x
	result.position_y = origin.y
	result.origin_x = origin.x
	result.origin_y = origin.y
	var endpoint := origin + Chemistry.scaled(Vector2i(result.direction_x, result.direction_y), result.length)
	result.endpoint_x = endpoint.x
	result.endpoint_y = endpoint.y
	return result


func _actors(anchor: int) -> Array:
	var second := PlayerState.new(2)
	second.team_id = 2
	second.position_x = anchor
	second.position_y = anchor
	var first := PlayerState.new(1)
	first.team_id = 1
	first.position_x = anchor - 100_000
	first.position_y = anchor
	return [second, first]


func _ordered_values(entities: Array) -> Array:
	var values: Array = []
	for entity: Variant in entities:
		values.append(entity.canonical_values())
	return values


func _reaction_by_id(reactions: Array, entity_id: int) -> ElementReactionState:
	for reaction: ElementReactionState in reactions:
		if reaction.entity_id == entity_id:
			return reaction
	return null


func _validate_inputs(label: String, data: Dictionary) -> void:
	_check(data.deposits.size() <= Chemistry.MAX_DEPOSITS, label + " respects deposit cap")
	_check(data.reactions.size() <= Chemistry.MAX_REACTIONS, label + " respects reaction cap")
	_check(data.actors.size() <= 8, label + " respects supported actor limit")
	for deposit: ElementDepositState in data.deposits:
		_check(deposit.validate(), label + " input deposit validates")
	for reaction: ElementReactionState in data.reactions:
		_check(reaction.validate(), label + " input reaction validates")


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		return
	failures += 1
	if failures <= 40:
		push_error(message)
