extends FluxTestSuite

const ABILITY_PATH := "res://content/abilities/foundation_abilities_v1.json"


func run() -> int:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(ABILITY_PATH), "field-interception fixture loads the production ability catalog: %s" % catalog.last_error)
	if not catalog.last_error.is_empty():
		return finish("hex-field-interception")
	_test_strength_chain_multicell_and_later_tick(catalog)
	_test_equal_exhaustion_has_no_terminal_or_product_recursion(catalog)
	_test_surviving_field_retiles_proportionally(catalog)
	_test_ordered_requeue_after_retile(catalog)
	_test_closed_stored_geometry()
	_test_stored_union_and_center_query(catalog)
	_test_wall_tie_height_and_same_source(catalog)
	_test_phase_zero_spray_fields_and_cover(catalog)
	_test_phase_zero_equal_exhaustion_and_wall_cutoff(catalog)
	return finish("hex-field-interception")


func _world() -> Dictionary:
	var world := SimWorld.new(120, 73, CollisionWorld.new(1_280_000, 960_000))
	world.players.clear()
	var court := HexCourt.new()
	court.chemistry_enabled = true
	world.hex_court = court
	return {"world": world, "court": court}


func _wire(catalog: AbilityCatalog, element: String, family: String) -> int:
	return int(catalog.ability(catalog.spell_id_at(element, family)).get("wire_id", 0))


func _reserve(court: HexCourt, owner: int, wire: int, source: int, release_origin: Vector2i = HexCourt.ORIGIN, aim: Vector2i = Vector2i(1000, 0)) -> int:
	check(court.reserve_cast(owner, wire), "fixture reserves one bounded paid source")
	var cast_id := int(court.pending.get(owner, 0))
	check(cast_id > 0, "fixture obtains a stable cast id")
	court.commit_payment(owner)
	court.bind_release(owner, source, release_origin, aim)
	check(not court.ledger_for_source(source).is_empty(), "released source owns one bound strength ledger")
	return cast_id


func _shot(world: SimWorld, court: HexCourt, catalog: AbilityCatalog, entity_id: int, owner: int, element: String, family: String, source: int, start: Vector2i, velocity: Vector2i) -> ProjectileState:
	var wire := _wire(catalog, element, family)
	var definition := CombatTuning.cast_definition(wire)
	_reserve(court, owner, wire, source, start)
	var shot := ProjectileState.new(
		entity_id, owner, owner, wire, int(definition.element_wire_id), start, velocity,
		int(definition.radius), int(definition.damage), 120,
	)
	shot.source_cast_id = source
	shot.reaction_strength = int(definition.reaction_strength)
	world.projectiles.append(shot)
	return shot


func _field(court: HexCourt, catalog: AbilityCatalog, owner: int, element: String, family: String, source: int, point: Vector2i, tick: int = 0, release_origin: Vector2i = Vector2i.ZERO) -> Dictionary:
	var wire := _wire(catalog, element, family)
	var origin := point if release_origin == Vector2i.ZERO else release_origin
	var cast_id := _reserve(court, owner, wire, source, origin)
	var definition := CombatTuning.cast_definition(wire)
	court.deposit_terminal({
		"type": "projectile_terminal", "source_cast_id": source, "source_wire_id": wire,
		"owner_id": owner, "team_id": owner, "element_wire_id": int(definition.element_wire_id),
		"position": point, "direction": Vector2i(1000, 0), "strength": 1000,
		"reaction_strength": int(definition.reaction_strength),
	}, tick)
	return court.casts[cast_id]


func _field_events(world: SimWorld) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in world.combat_events:
		if String(event.get("type", "")) == "hex_clash" and String(event.get("contact_kind", "")) == "field":
			result.append(event)
	return result


func _events(world: SimWorld, kind: String, projectile_id: int = -1) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in world.combat_events:
		if String(event.get("type", "")) == kind and (projectile_id < 0 or int(event.get("projectile_id", -1)) == projectile_id):
			result.append(event)
	return result


func _test_strength_chain_multicell_and_later_tick(catalog: AbilityCatalog) -> void:
	var fixture := _world()
	var world: SimWorld = fixture.world
	var court: HexCourt = fixture.court
	var y := court.origin.y
	var field_five := _field(court, catalog, 2, "fire", "bolt", 2001, Vector2i(300_000, y))
	var field_three := _field(court, catalog, 3, "fire", "spray", 2002, Vector2i(430_000, y), 0, Vector2i(350_000, y))
	check(field_five.cells.size() > 1 and field_three.cells.size() > 1, "each source field spans multiple storage cells in the traversal fixture")
	var heavy := _shot(world, court, catalog, 1000, 1, "water", "heavy", 1000, Vector2i(200_000, y), Vector2i(36_000_000, 0))
	HexProjectileCombat.advance(world)
	equal(heavy.remaining_strength, 7, "one tick orders Heavy strength 15 to 10 to 7 across two fields")
	equal(_field_events(world).size(), 2, "multi-cell fields emit one contact per source rather than one per cell")
	var clashes := _field_events(world)
	if clashes.size() == 2:
		check(int(clashes[0].x) < int(clashes[1].x), "field events retain earliest center-entry TOI order")
	equal(court.products.size(), 2, "each exhausting source contact creates exactly one medium")
	equal(int(field_five.ledger.remaining_strength), 0, "strength-five field exhausts once")
	equal(int(field_three.ledger.remaining_strength), 0, "strength-three field exhausts once")
	equal(int(court.ledger_for_source(1000).flight_quantity), 280, "surviving Heavy retains only its strength-seven flight allocation")
	check(court.conservation_valid(), "two field contacts preserve source-ledger conservation")
	world.combat_events.clear()
	world.tick += 1
	HexProjectileCombat.advance(world)
	equal(_field_events(world).size(), 0, "a later tick cannot drain exhausted multi-cell fields again")
	equal(court.products.size(), 2, "later traversal cannot duplicate either reaction product")


func _test_equal_exhaustion_has_no_terminal_or_product_recursion(catalog: AbilityCatalog) -> void:
	var fixture := _world()
	var world: SimWorld = fixture.world
	var court: HexCourt = fixture.court
	var y := court.origin.y
	var field := _field(court, catalog, 2, "fire", "bolt", 3001, Vector2i(300_000, y))
	_shot(world, court, catalog, 3000, 1, "water", "bolt", 3000, Vector2i(200_000, y), Vector2i(24_000_000, 0))
	HexProjectileCombat.advance(world)
	equal(_field_events(world).size(), 1, "equal projectile and field strengths resolve one contact")
	equal(world.projectiles.size(), 0, "zero-strength projectile is removed in the contact tick")
	equal(_events(world, "projectile_terminal", 3000).size(), 0, "field-exhausted projectile emits no ordinary terminal deposit")
	equal(int(field.ledger.remaining_strength), 0, "equal contact exhausts the field ledger too")
	equal(court.products.size(), 1, "equal field contact creates one medium")
	world.combat_events.clear()
	world.tick += 1
	var survivor := _shot(world, court, catalog, 3002, 3, "water", "rapid", 3002, Vector2i(200_000, y), Vector2i(24_000_000, 0))
	HexProjectileCombat.advance(world)
	equal(_field_events(world).size(), 0, "a derived product is never re-entered as a fundamental field")
	equal(survivor.remaining_strength, 1, "product-only traversal leaves the new projectile strength unchanged")
	equal(court.products.size(), 1, "product traversal cannot recurse into a new product")
	check(court.conservation_valid(), "equal exhaustion and product-only traversal remain conserved")


func _test_surviving_field_retiles_proportionally(catalog: AbilityCatalog) -> void:
	var fixture := _world()
	var world: SimWorld = fixture.world
	var court: HexCourt = fixture.court
	var y := court.origin.y
	var field := _field(court, catalog, 2, "fire", "bolt", 4001, Vector2i(300_000, y))
	var before: Dictionary = field.cells.duplicate(true)
	_shot(world, court, catalog, 4000, 1, "water", "rapid", 4000, Vector2i(200_000, y), Vector2i(24_000_000, 0))
	HexProjectileCombat.advance(world)
	equal(int(field.ledger.remaining_strength), 4, "strength-one flight leaves strength four in the field")
	equal(int(field.ledger.deposited_quantity), 480, "surviving field retains the cumulative four-fifths quantity")
	equal(_sum(field.cells), 480, "retiled field cells equal the deposited ledger exactly")
	equal(field.cells, _proportional(before, 600, 480), "surviving field uses canonical cumulative proportional retiling")
	equal(int(court.products[_single_product(court)].quantity), 720, "contact medium contains only the new 600 plus 120 portions")
	check(court.conservation_valid(), "surviving field, exhausted flight and medium remain conserved")
	world.combat_events.clear()
	world.tick += 1
	_shot(world, court, catalog, 4002, 3, "water", "rapid", 4002, Vector2i(200_000, y), Vector2i(24_000_000, 0))
	HexProjectileCombat.advance(world)
	equal(int(field.ledger.remaining_strength), 3, "later independent source continues from field strength four instead of resetting five")
	equal(int(field.ledger.deposited_quantity), 360, "second contact charges the next cumulative 120-unit field portion")
	equal(court.products.size(), 2, "each distinct exhausting contact emits one product while retaining one field ledger")
	check(court.conservation_valid(), "successive field resistance remains finite and conserved")


func _test_ordered_requeue_after_retile(catalog: AbilityCatalog) -> void:
	var fixture := _world()
	var world: SimWorld = fixture.world
	var court: HexCourt = fixture.court
	var y := court.origin.y
	var left := Vector2i(-1, 0)
	var right := Vector2i.ZERO
	var field := _field(court, catalog, 3, "fire", "heavy", 4201, court.origin + Vector2i(-32_000, 0))
	# Direct conserved fixture: a one-unit leading allocation models a clipped
	# irregular field. The first legal strength decrement removes that cell and
	# forces the already queued second contact from x=544k to x=608k.
	for cell: Vector2i in field.cells:
		court.cells[cell]["fire"].erase(int(field.id))
	field.cells = {left: 1, right: 599}
	court.cells[left]["fire"][int(field.id)] = 1
	court.cells[right]["fire"][int(field.id)] = 599
	check(court.conservation_valid(), "irregular two-cell fixture still owns exactly one conserved ledger")
	_shot(world, court, catalog, 4200, 2, "water", "rapid", 4200,
		Vector2i(700_000, y), Vector2i(-24_000_000, 0))
	var later := _shot(world, court, catalog, 4202, 1, "water", "heavy", 4202,
		Vector2i(500_000, y), Vector2i(24_000_000, 0))
	var target := PlayerState.new(4299)
	target.team_id = 2 # Friendly to the first shot, hostile to the later Heavy.
	target.position_x = 600_000
	target.position_y = y
	target.radius = 18_000
	target.health = 100_000
	target.spawn_protection_ticks = 0
	world.players.append(target)
	HexProjectileCombat.advance(world)
	equal(int(field.ledger.remaining_strength), 14, "only the earlier Rapid drains the field before its leading cell disappears")
	check(not field.cells.has(left), "partial subtraction removes the one-unit leading allocation")
	equal(_field_events(world).size(), 1, "moved field entry is requeued rather than resolved at its stale earlier TOI")
	check(target.health < 100_000, "actor contact between old and new field entries wins after the requeue")
	check(not world.projectiles.has(later), "the intervening actor contact terminates the later Heavy before the requeued field event")
	check(court.conservation_valid(), "same-tick retile and requeue preserve every source budget")


func _test_closed_stored_geometry() -> void:
	var footprint := HexFootprint.disk(Vector2i.ZERO, 100_000)
	var stored := {Vector2i.ZERO: 1}
	var face := Vector2i(32_000, 0)
	var vertex := Vector2i(0, -36_950)
	check(bool(HexFootprint.stored_segment_interval(footprint, stored, Vector2i.ZERO, face, face).get("hit", false)), "stored union includes a stationary point on a closed hex face")
	check(bool(HexFootprint.stored_segment_interval(footprint, stored, Vector2i.ZERO, vertex, vertex).get("hit", false)), "stored union includes an exact hex vertex")
	check(bool(HexFootprint.stored_segment_interval(footprint, stored, Vector2i.ZERO, vertex + Vector2i(-20_000, 0), vertex + Vector2i(20_000, 0)).get("hit", false)), "stored union includes segment tangency along a vertex")
	check(not bool(HexFootprint.stored_segment_interval(footprint, stored, Vector2i.ZERO, face + Vector2i(1, 0), face + Vector2i(1, 0)).get("hit", false)), "one fixed unit beyond a closed face is excluded")
	var diagonal := HexFootprint.stored_segment_interval(
		footprint, stored, Vector2i.ZERO,
		Vector2i(23_796, 70_811), Vector2i(-487, -44_962))
	check(bool(diagonal.get("hit", false)), "continuous diagonal crossing retains its true stored-cell entry")
	equal(diagonal.get("point", Vector2i.ZERO), Vector2i(14_890, 28_353), "nearest constrained lattice witness stays inside instead of rounding across the sloped edge")
	check(HexGrid._point_in_cell(Vector2i(diagonal.point), Vector2i.ZERO), "quantized diagonal witness remains in the authoritative closed stored hex")
	check(not bool(diagonal.get("quantization_outside", true)), "representable diagonal contact does not require a bounded outside witness")
	# Two integer-centered disks can be exactly tangent at a non-lattice point.
	# Their real contact must survive even though no Vector2i belongs to both.
	var subunit_tangent := HexFootprint.contact_point_in_cells(
		HexFootprint.disk(Vector2i.ZERO, 1), HexFootprint.disk(Vector2i(3, 4), 4),
		Vector2i.ZERO, stored, Vector2i.ZERO)
	check(not subunit_tangent.is_empty(), "real analytic subunit tangency is not discarded for lacking a common lattice point")
	equal(subunit_tangent.get("point", Vector2i.ZERO), Vector2i(1, 1), "nonrepresentable tangency retains its nearest deterministic fixed-grid witness")
	check(bool(subunit_tangent.get("quantization_outside", false)), "nonrepresentable tangency explicitly marks its bounded quantization exception")
	check(float(subunit_tangent.get("quantization_error_squared", 2.0)) <= 1.0, "tangency witness remains within one fixed world unit of the continuous point")


func _test_stored_union_and_center_query(catalog: AbilityCatalog) -> void:
	var fixture := _world()
	var world: SimWorld = fixture.world
	var court: HexCourt = fixture.court
	var y := court.origin.y
	var boundary_point := court.origin + HexGrid.center(Vector2i(6, 0))
	var boundary_field := _field(court, catalog, 2, "fire", "heavy", 5001, boundary_point)
	var outside_start := Vector2i(boundary_point.x + 56_000, y)
	var outside_end := Vector2i(boundary_point.x + 96_000, y)
	check(HexFootprint.segment_intersects(boundary_field.footprint, outside_start, outside_end), "boundary fixture crosses the analytic Heavy disk outside the court")
	check(not bool(HexFootprint.stored_segment_interval(boundary_field.footprint, boundary_field.cells, court.origin, outside_start, outside_end).get("hit", false)), "unrendered analytic extent outside stored court cells is ineligible")
	var outside_shot := _shot(world, court, catalog, 5000, 1, "water", "bolt", 5000, outside_start, Vector2i(4_800_000, 0))
	HexProjectileCombat.advance(world)
	equal(outside_shot.remaining_strength, 5, "off-court analytic extent cannot consume projectile strength")
	equal(_field_events(world).size(), 0, "off-court analytic extent emits no hidden field contact")

	fixture = _world()
	world = fixture.world
	court = fixture.court
	y = court.origin.y
	_field(court, catalog, 2, "fire", "bolt", 5101, Vector2i(300_000, y))
	var offset_shot := _shot(world, court, catalog, 5100, 1, "water", "heavy", 5100, Vector2i(200_000, y + 40_000), Vector2i(24_000_000, 0))
	HexProjectileCombat.advance(world)
	equal(offset_shot.remaining_strength, 15, "projectile collision radius cannot enlarge center-only field eligibility")
	equal(_field_events(world).size(), 0, "physical envelope overlap without center entry emits no field reaction")


func _test_wall_tie_height_and_same_source(catalog: AbilityCatalog) -> void:
	var fixture := _world()
	var world: SimWorld = fixture.world
	var court: HexCourt = fixture.court
	var y := court.origin.y
	var field := _field(court, catalog, 2, "fire", "bolt", 6001, Vector2i(300_000, y))
	var shot := _shot(world, court, catalog, 6000, 1, "water", "heavy", 6000, Vector2i(200_000, y), Vector2i(24_000_000, 0))
	world.collision.add_obstacle(CollisionWorld.Obstacle.new(61, 285_200, y - 80_000, 320_000, y + 80_000, false))
	HexProjectileCombat.advance(world)
	equal(_field_events(world).size(), 0, "cover wins the exact center-entry tie with the field boundary")
	equal(int(field.ledger.remaining_strength), 5, "wall-tied field keeps its full resistance")
	equal(_events(world, "projectile_terminal", shot.entity_id).size(), 1, "wall winner emits the projectile's one terminal")
	fixture = _world()
	world = fixture.world
	court = fixture.court
	field = _field(court, catalog, 2, "fire", "bolt", 6051, Vector2i(300_000, y))
	shot = _shot(world, court, catalog, 6050, 1, "water", "bolt", 6050, Vector2i(200_000, y), Vector2i(24_000_000, 0))
	shot.remaining_distance = 66_000 # Exact entry into the 34px field disk.
	HexProjectileCombat.advance(world)
	equal(_field_events(world).size(), 1, "field entry at the exact range endpoint remains eligible")
	equal(_events(world, "projectile_terminal", shot.entity_id).size(), 0, "endpoint clash exhausts the projectile before range termination can duplicate it")
	equal(int(field.ledger.remaining_strength), 0, "equal endpoint contact exhausts the field once")

	# Player height eligibility remains the existing actor rule. Fields have no
	# height of their own; all active projectiles use the authored ground layer.
	fixture = _world()
	world = fixture.world
	court = fixture.court
	field = _field(court, catalog, 2, "fire", "bolt", 6101, Vector2i(300_000, y))
	var self_plan := {"source_id": 6101, "start": Vector2i(200_000, y), "finish": Vector2i(400_000, y), "terminal_fraction": 1.0, "reason": ""}
	equal(HexProjectileCombat._field_contacts(self_plan, world).size(), 0, "a source can never intercept its own deposited footprint")
	var high_actor := PlayerState.new(99)
	high_actor.team_id = 2
	high_actor.position_x = 250_000
	high_actor.position_y = y
	high_actor.air_height = MovementTuning.GROUND_PROJECTILE_CLEARANCE_HEIGHT
	high_actor.spawn_protection_ticks = 0
	world.players.append(high_actor)
	shot = _shot(world, court, catalog, 6100, 1, "water", "heavy", 6100, Vector2i(200_000, y), Vector2i(24_000_000, 0))
	var health_before := high_actor.health
	HexProjectileCombat.advance(world)
	equal(high_actor.health, health_before, "actor at the exact height boundary remains ineligible")
	equal(shot.remaining_strength, 10, "ground flight still reaches the later eligible field")


func _test_phase_zero_spray_fields_and_cover(catalog: AbilityCatalog) -> void:
	var fixture := _world()
	var world: SimWorld = fixture.world
	var court: HexCourt = fixture.court
	var y := court.origin.y
	# Reverse spatial order to prove phase-zero ties use stable source ids.
	var field_7202 := _field(court, catalog, 2, "fire", "rapid", 7202, Vector2i(300_000, y))
	var field_7201 := _field(court, catalog, 3, "fire", "rapid", 7201, Vector2i(400_000, y))
	var stored_before := {
		7201: {"footprint": field_7201.footprint.duplicate(true), "cells": field_7201.cells.duplicate(true)},
		7202: {"footprint": field_7202.footprint.duplicate(true), "cells": field_7202.cells.duplicate(true)},
	}
	var spray_wire := _wire(catalog, "water", "spray")
	_reserve(court, 1, spray_wire, 7200, Vector2i(200_000, y))
	var owner := PlayerState.new(1)
	owner.team_id = 1
	owner.position_x = 200_000
	owner.position_y = y
	world.players.append(owner)
	world.combat_events.append(_spray_request(7200, spray_wire, owner.entity_id, Vector2i(200_000, y)))
	HexProjectileCombat.resolve_sprays(world)
	var clashes := _field_events(world)
	equal(clashes.size(), 2, "one phase-zero Spray contacts each eligible source-owned field once")
	if clashes.size() == 2:
		equal(int(clashes[0].field_source_id), 7201, "simultaneous phase-zero fields use stable source-id order")
		equal(int(clashes[1].field_source_id), 7202, "stable order is independent of spatial insertion order")
	equal(int(court.ledger_for_source(7200).remaining_strength), 1, "strength-three Spray loses one strength to each Rapid field")
	equal(_events(world, "projectile_terminal").size(), 1, "surviving Spray emits one remaining terminal payload")
	var spray_definition := CombatTuning.cast_definition(spray_wire)
	var pulse_footprint := HexFootprint.sector(Vector2i(200_000, y), Vector2i(1000, 0), int(spray_definition.range), int(spray_definition.cone_cosine_squared_per_million))
	for event: Dictionary in clashes:
		var point := Vector2i(int(event.x), int(event.y))
		var prior: Dictionary = stored_before[int(event.field_source_id)]
		check(HexFootprint.contains(pulse_footprint, point), "Spray witness lies in the exact authored pulse footprint")
		check(HexFootprint.contains(prior.footprint, point), "Spray contact uses a common analytic field witness")
		check(bool(HexFootprint.stored_segment_interval(prior.footprint, prior.cells, court.origin, point, point).get("hit", false)), "Spray witness lies in the field's stored-cell union")
	check(court.conservation_valid(), "phase-zero field chain conserves every paid source")

	fixture = _world()
	world = fixture.world
	court = fixture.court
	y = court.origin.y
	var blocked_field := _field(court, catalog, 2, "fire", "bolt", 7301, Vector2i(360_000, y))
	_reserve(court, 1, spray_wire, 7300, Vector2i(200_000, y))
	owner = PlayerState.new(1)
	owner.team_id = 1
	owner.position_x = 200_000
	owner.position_y = y
	world.players.append(owner)
	world.collision.add_obstacle(CollisionWorld.Obstacle.new(73, 300_000, y - 100_000, 320_000, y + 100_000, false))
	world.combat_events.append(_spray_request(7300, spray_wire, owner.entity_id, Vector2i(200_000, y)))
	HexProjectileCombat.resolve_sprays(world)
	equal(_field_events(world).size(), 0, "phase-zero Spray cannot reach a field behind solid cover")
	equal(int(blocked_field.ledger.remaining_strength), 5, "covered field retains its complete ledger")


func _test_phase_zero_equal_exhaustion_and_wall_cutoff(catalog: AbilityCatalog) -> void:
	var fixture := _world()
	var world: SimWorld = fixture.world
	var court: HexCourt = fixture.court
	var y := court.origin.y
	var fire_spray_wire := _wire(catalog, "fire", "spray")
	var water_spray_wire := _wire(catalog, "water", "spray")
	var equal_field := _field(court, catalog, 2, "fire", "spray", 7401,
		Vector2i(350_000, y), 0, Vector2i(300_000, y))
	_reserve(court, 1, water_spray_wire, 7400, Vector2i(200_000, y))
	var owner := PlayerState.new(1)
	owner.team_id = 1
	owner.position_x = 200_000
	owner.position_y = y
	world.players.append(owner)
	var target := PlayerState.new(7499)
	target.team_id = 2
	target.position_x = 250_000
	target.position_y = y
	target.radius = 18_000
	target.health = 100_000
	target.spawn_protection_ticks = 0
	world.players.append(target)
	world.combat_events.append(_spray_request(7400, water_spray_wire, owner.entity_id, Vector2i(200_000, y)))
	HexProjectileCombat.resolve_sprays(world)
	var equal_clashes := _field_events(world)
	equal(equal_clashes.size(), 1, "equal phase-zero Spray and field emit one reaction")
	if not equal_clashes.is_empty():
		equal(int(equal_clashes[0].other_wire_id), fire_spray_wire, "phase-zero clash carries the exact other source wire for its two-element cue")
	equal(int(equal_field.ledger.remaining_strength), 0, "equal phase-zero field participant is exhausted once")
	equal(int(court.ledger_for_source(7400).remaining_strength), 0, "equal phase-zero Spray participant is exhausted once")
	equal(target.health, 100_000, "zero-strength Spray cannot damage an actor after field interception")
	equal(_events(world, "spray_fired").size(), 0, "zero-strength Spray emits no fired event after field interception")
	equal(_events(world, "projectile_terminal").size(), 0, "zero-strength Spray emits no terminal deposit after field interception")

	# A wall-clamped Spray ends at x=391000: obstacle x=400000 minus its
	# authored 9000 radius. A field exactly tangent there loses the wall tie,
	# while one fixed world unit of real overlap remains eligible.
	for inward_overlap: int in [0, 1]:
		fixture = _world()
		world = fixture.world
		court = fixture.court
		y = court.origin.y
		var field_center := 425_000 - inward_overlap
		var tied_field := _field(court, catalog, 2, "fire", "bolt", 7501 + inward_overlap,
			Vector2i(field_center, y))
		_reserve(court, 1, water_spray_wire, 7500 + inward_overlap, Vector2i(200_000, y))
		owner = PlayerState.new(1)
		owner.team_id = 1
		owner.position_x = 200_000
		owner.position_y = y
		world.players.append(owner)
		world.collision.add_obstacle(CollisionWorld.Obstacle.new(75, 400_000, y - 100_000, 420_000, y + 100_000, false))
		world.combat_events.append(_spray_request(7500 + inward_overlap, water_spray_wire, owner.entity_id, Vector2i(200_000, y)))
		HexProjectileCombat.resolve_sprays(world)
		equal(_field_events(world).size(), inward_overlap,
			"exact Spray wall tie is excluded while one fixed-unit analytic overlap remains eligible")
		equal(int(tied_field.ledger.remaining_strength), 5 if inward_overlap == 0 else 2,
			"wall cutoff changes field strength only for real pre-wall overlap")
		if inward_overlap == 0:
			equal(_events(world, "projectile_terminal").size(), 1, "wall-tied field leaves the surviving Spray one near-side terminal")
		else:
			equal(_events(world, "projectile_terminal").size(), 0, "one-unit pre-wall field overlap exhausts the weaker Spray without a duplicate terminal")


func _spray_request(source: int, wire: int, owner: int, origin: Vector2i) -> Dictionary:
	return {"type": "spray_requested", "source_cast_id": source, "owner_id": owner,
		"source_wire_id": wire, "origin_x": origin.x, "origin_y": origin.y,
		"aim_x": 1000, "aim_y": 0, "target_x": origin.x + 380_000, "target_y": origin.y}


func _proportional(before: Dictionary, old_total: int, new_total: int) -> Dictionary:
	var ordered: Array[Vector2i] = []
	for cell: Vector2i in before: ordered.append(cell)
	ordered.sort_custom(HexGrid._cell_less)
	var result := {}
	var old_cumulative := 0
	var new_cumulative := 0
	for cell: Vector2i in ordered:
		old_cumulative += int(before[cell])
		var next_cumulative: int = new_total * old_cumulative / old_total
		var amount := next_cumulative - new_cumulative
		new_cumulative = next_cumulative
		if amount > 0: result[cell] = amount
	return result


func _sum(values: Dictionary) -> int:
	var result := 0
	for value: int in values.values(): result += value
	return result


func _single_product(court: HexCourt) -> int:
	var ids: Array = court.products.keys()
	ids.sort()
	return int(ids[0]) if ids.size() == 1 else 0
