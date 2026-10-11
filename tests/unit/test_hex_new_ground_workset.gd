extends FluxTestSuite

const ABILITY_PATH := "res://content/abilities/foundation_abilities_v1.json"
const Workset = preload("res://src/sim/hex/hex_contact_workset.gd")


func run() -> int:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(ABILITY_PATH), "new-ground workset loads production paid definitions")
	if not catalog.last_error.is_empty(): return finish("hex-new-ground-workset")
	_test_exact_new_source_queue(catalog)
	return finish("hex-new-ground-workset")


func _world() -> Dictionary:
	var world := SimWorld.new(120, 73, CollisionWorld.new(1_280_000, 960_000))
	world.players.clear()
	# Exercise the production unified authority, not the legacy court wrapper.
	var court := HexChemistryWorld.new()
	check(court.configure_geometry(HexCourt.ORIGIN, HexGrid.disk(Vector2i.ZERO, 20)), "new-ground fixture admits real unified court geometry")
	court.chemistry_enabled = true
	world.hex_court = court
	return {"world": world, "court": court}


func _field(court: HexChemistryWorld, catalog: AbilityCatalog, owner: int, source: int, point: Vector2i) -> void:
	var wire := int(catalog.ability(catalog.spell_id_at("water", "bolt")).get("wire_id", 0))
	check(court.reserve_cast(owner, wire), "fixture reserves one bounded paid water source")
	var cast_id := int(court.pending.get(owner, 0))
	check(cast_id > 0, "fixture obtains a stable cast id")
	if cast_id <= 0: return
	court.commit_payment(owner)
	court.bind_release(owner, source, point, Vector2i(1000, 0))
	check(not court.ledger_for_source(source).is_empty(), "released source owns one bound strength ledger")
	var definition := CombatTuning.cast_definition(wire)
	court.deposit_terminal({
		"type": "projectile_terminal", "source_cast_id": source, "source_wire_id": wire,
		"owner_id": owner, "team_id": owner, "element_wire_id": int(definition.element_wire_id),
		"position": point, "direction": Vector2i(1000, 0), "strength": 1000,
		"reaction_strength": int(definition.reaction_strength),
	}, 0)
	check(int(court.casts[cast_id].ground) > 0, "paid source actually deposits ground ownership")


func _test_exact_new_source_queue(catalog: AbilityCatalog) -> void:
	var fixture := _world()
	var world: SimWorld = fixture.world
	var court: HexChemistryWorld = fixture.court
	var center := court.origin
	# Water + Water is Flood, so touching fields would consume one another
	# during the real deposit. Keep the 34px bolt footprints and their selected
	# whole cells disjoint, on a legal larger diagnostic topology.
	for index: int in 8:
		_field(court, catalog, index + 1, 8401 + index,
			center + Vector2i(index * 120_000 - 420_000, 0))
	check(court.conservation_valid(), "new-ground fixture retains eight finite paid fields")
	check(court.products.is_empty() and int(court.metrics.reactions) == 0, "separated deposits retain live ingredients rather than reacting into products")
	equal(HexProjectileCombat._ground_fields(world).size(), 8, "unrelated ground remains present in the oracle workload")
	var crossing: Array[Dictionary] = [{"entity_id": 90, "source_id": 8990,
		"start": center - Vector2i(500_000, 0), "finish": center + Vector2i(500_000, 0),
		"time": 0.0, "terminal_fraction": 1.0, "reason": "range", "generation": 0}]
	for source: int in range(8401, 8409):
		_compare_new_ground(crossing, {}, 0.0, source, world, 1)
	_compare_new_ground(crossing, {}, 0.0, 8999, world, 0)
	var plans: Array[Dictionary] = []
	for index: int in 16:
		var y := (index % 4 - 2) * 24_000
		plans.append({
			"entity_id": index + 1, "source_id": 8401 if index % 5 == 0 else 8900 + index,
			"start": center + Vector2i(-500_000, y), "finish": center + Vector2i(500_000, -y),
			"time": float(index % 3) / 4.0, "terminal_fraction": 0.5 if index % 3 == 1 else 1.0,
			"reason": "obstacle" if index % 4 == 0 else "range", "generation": index % 3,
		})
	var ended := {2: true, 7: true, 13: true}
	for reverse_order: bool in [false, true]:
		if reverse_order: plans.reverse()
		for time: float in [0.0, 0.125, 0.5, 1.0]:
			for source: int in [8401, 8404, 8408, 8999]:
				_compare_new_ground(plans, ended, time, source, world)
	# A workset is scoped to one call, never reused after authority changes.
	var changed: Dictionary = court.casts[int(court.sources[8404])]
	changed.expires = world.tick
	_compare_new_ground(plans, ended, 0.125, 8404, world, 0)
	_compare_new_ground(crossing, {}, 0.0, 8404, world, 0)
	var empty_plans: Array[Dictionary] = []
	_compare_new_ground(empty_plans, {}, 0.0, 8401, world, 0)
	var all_ended := {}
	for plan: Dictionary in plans: all_ended[int(plan.entity_id)] = true
	_compare_new_ground(plans, all_ended, 0.0, 8401, world, 0)
	# Stored whole-cell closed endpoints and same-source suppression use the
	# exact unchanged interval routine in both arms.
	var field := HexProjectileCombat._ground_field_for_source(world, 8401)
	var occupied: Array = HexChemistryWorld.coverage(field).keys()
	check(not occupied.is_empty(), "boundary fixture selects a real stored field cell")
	if occupied.is_empty(): return
	occupied.sort_custom(HexGrid._cell_less)
	var boundary_center := center + HexGrid.center(occupied[0])
	var boundary: Array[Dictionary] = [
		{"entity_id": 91, "source_id": 8991, "start": boundary_center + HexGrid.LOCAL_VERTICES[0],
			"finish": boundary_center + HexGrid.LOCAL_VERTICES[1], "time": 0.0, "terminal_fraction": 1.0,
			"reason": "range", "generation": 0},
		{"entity_id": 92, "source_id": 8401, "start": boundary_center, "finish": boundary_center,
			"time": 0.0, "terminal_fraction": 1.0, "reason": "range", "generation": 0},
	]
	_compare_new_ground(boundary, {}, 0.0, 8401, world, 1)


func _compare_new_ground(plans: Array[Dictionary], ended: Dictionary, time: float, source: int, world: SimWorld, expected_contacts: int = -1) -> void:
	var before_hash := world.state_hash()
	var before_plans := plans.duplicate(true)
	var candidate := Workset.OrderedQueue.new(HexProjectileCombat._ordered)
	var reference := Workset.OrderedQueue.new(HexProjectileCombat._ordered)
	# Retain surrounding queued events, including equal priority/fraction keys,
	# to verify insertion stability and complete event dictionaries.
	for queue: Workset.OrderedQueue in [candidate, reference]:
		queue.append({"kind": "sentinel", "fraction": 0.5, "priority": 1, "first": 3,
			"second": source, "generation": 0, "point": Vector2i.ZERO})
	HexProjectileCombat._enqueue_new_ground(plans, ended, candidate, time, source, world)
	_old_enqueue_new_ground(plans, ended, reference, time, source, world)
	var actual := _drain_new_ground(candidate)
	var expected := _drain_new_ground(reference)
	if expected_contacts >= 0:
		# The single sentinel is not a contact: reject vacuous oracle equality.
		equal(actual.size() - 1, expected_contacts, "candidate enqueues the expected real field contacts")
		equal(expected.size() - 1, expected_contacts, "frozen oracle enqueues the expected real field contacts")
	equal(var_to_bytes(actual), var_to_bytes(expected), "new-source workset preserves exact complete queue, times, witnesses and stable order")
	equal(plans, before_plans, "new-source scheduling does not mutate path plans")
	equal(world.state_hash(), before_hash, "new-source scheduling does not mutate authority")


func _drain_new_ground(queue: Workset.OrderedQueue) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	while not queue.is_empty(): result.append(queue.pop_front())
	return result


# Frozen preceding function, not an alternate production path. It deliberately
# computes contacts for every field before retaining only the new source.
func _old_enqueue_new_ground(plans: Array[Dictionary], ended: Dictionary, queue: Workset.OrderedQueue, time: float, new_source: int, world: SimWorld) -> void:
	for plan: Dictionary in plans:
		if ended.has(int(plan.entity_id)) or time > float(plan.terminal_fraction): continue
		var probe := plan.duplicate()
		probe.time = maxf(time, float(plan.time))
		probe.start = HexProjectileCombat._plan_point(plan, float(probe.time))
		for field: Dictionary in HexProjectileCombat._field_contacts(probe, world):
			if int(field.field_source) != new_source: continue
			var fraction := float(probe.time) + (1.0 - float(probe.time)) * float(field.fraction)
			queue.append({"kind": "field", "fraction": fraction, "priority": 1, "first": int(plan.entity_id),
				"second": int(field.field_source), "generation": int(plan.generation), "point": field.point, "formed_after": float(probe.time)})
