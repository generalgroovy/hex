extends FluxTestSuite

const Presenter = preload("res://src/presentation/heavy_blast_presenter.gd")
const ORIGIN := Vector2i(500_000, 500_000)
const ORIGINAL_HEAVY_WIRES: Array[int] = [181, 179, 185, 183, 191, 193]


func run() -> int:
	_test_profiles_and_lifetime()
	_test_expanded_heavy_route()
	_test_cover_clipping_and_cache()
	return finish("heavy-blast-presenter")


func _deposit(wire: int = 179) -> ElementDepositState:
	var deposit := ElementDepositState.new()
	deposit.entity_id = 3000
	deposit.source_cast_id = 1000
	deposit.source_wire_id = wire
	deposit.owner_id = 1
	deposit.team_id = 1
	deposit.element_wire_id = int(CombatTuning.cast_definition(wire).get("element_wire_id", 2))
	deposit.position_x = ORIGIN.x
	deposit.position_y = ORIGIN.y
	deposit.created_tick = 50
	deposit.expiry_tick = 290
	return deposit


func _test_profiles_and_lifetime() -> void:
	var presenter := Presenter.new()
	var config := SimConfig.new(120)
	var world := CollisionWorld.new(2_000_000, 2_000_000)
	var checked := 0
	# The legacy deposit adapter retains its six singleton aftermaths. Mixed
	# payloads use Hex-owned material and the expanded projectile presenter.
	for wire: int in ORIGINAL_HEAVY_WIRES:
		check(wire in CombatTuning.runtime_wire_ids(), "original Heavy remains live")
		equal(String(CombatTuning.cast_definition(wire).family), "heavy", "independent original wire remains Heavy")
		checked += 1
		var deposit := _deposit(wire)
		check(deposit.validate(), "singleton aftermath fixture is an admitted legacy deposit")
		var before := deposit.canonical_values()
		var previous_opacity := 1.0
		for age: int in range(HeavyBlastPresenter.DURATION_TICKS):
			var model := presenter.model(deposit, 50 + age, config, world, [])
			check(not model.is_empty(), "each Heavy element has a bounded aftermath")
			if model.is_empty(): continue
			equal(model.radius, 120.0, "aftermath uses the enlarged actual blast radius, not impact/deposit radius")
			equal(model.boundary_ticks.size(), Presenter.RAY_COUNT * 2, "open blast has a complete bounded broken footprint")
			equal(model.spokes.size(), 16, "at most eight quiet spokes connect the two visual scales")
			check(model.opacity > 0.0 and model.opacity <= previous_opacity, "aftermath only fades, without flashing or fresh telegraph")
			previous_opacity = model.opacity
			equal(presenter.model(deposit, 50 + age, config, world, [], true), model, "reduced mode retains identical essential radius and lifetime")
			for point: Vector2 in model.boundary_ticks:
				check(point.distance_to(model.origin) >= 117.9 and point.distance_to(model.origin) <= 120.001, "static radius never expands beyond authority or collapses onto deposit")
		check(presenter.model(deposit, 49, config, world, []).is_empty(), "unborn aftermath is hidden")
		check(presenter.model(deposit, 50 + Presenter.DURATION_TICKS, config, world, []).is_empty(), "aftermath disappears on the exact authored terminal-contact tick")
		deposit.expiry_tick = 60
		check(presenter.model(deposit, 60, config, world, []).is_empty(), "earlier deposit expiry wins")
		deposit.expiry_tick = 290
		equal(deposit.canonical_values(), before, "reading aftermath never changes canonical material")
	equal(checked, 6, "all six current Heavy identities preserve exact aftermath geometry")
	for wire: int in [145, 180, 146, 154, 155, 156, 110, 187, 189]:
		check(presenter.model(_deposit(wire), 50, config, world, []).is_empty(), "non-Heavy wire %d cannot invent an area blast" % wire)
	check(presenter.model(null, 50, config, world, []).is_empty(), "fully consumed/missing deposit has no aftermath")
	var spent := _deposit()
	spent.strength = 0
	check(presenter.model(spent, 50, config, world, []).is_empty(), "spent deposit has no aftermath")


func _test_expanded_heavy_route() -> void:
	var presenter := Presenter.new()
	var config := SimConfig.new(120)
	var count := 0
	for mask: int in range(1, 64):
		if (mask & (mask - 1)) == 0: continue
		count += 1
		var wire := MixtureCatalog.wire_for(mask, "heavy")
		var definition := CombatTuning.projectile_definition(wire)
		check(not definition.is_empty(), "every mixed Heavy has a live projectile definition")
		if definition.is_empty(): continue
		var legacy := _deposit(wire)
		check(not legacy.validate(), "expanded payload cannot fabricate a legacy single-element deposit")
		check(presenter.model(legacy, 50, config, null, []).is_empty(), "legacy aftermath remains closed to expanded material records")
		# Pure descriptor coverage only: actual paid formation/impact and mask
		# provenance are exercised by the live Hex combat and presentation suites.
		var shot := ProjectileState.new(3100, 1, 1, wire, int(definition.element_wire_id), ORIGIN,
			Vector2i(int(definition.speed), 0), int(definition.radius), int(definition.damage),
			config.milliseconds_to_ticks(int(definition.lifetime_ms)))
		var before := shot.canonical_values()
		for reduced: bool in [false, true]:
			var model := PixelSpellEffects.expanded_projectile_model(shot, definition, Vector2(500, 500), config, null, reduced)
			check(not model.is_empty(), "mixed Heavy keeps its actual expanded descriptor in both visual modes")
			if model.is_empty(): continue
			equal(model.family, "heavy", "expanded descriptor preserves Heavy delivery")
			equal(model.mask, mask, "expanded descriptor preserves every ingredient instead of borrowing one deposit identity")
			equal(model.radius, 30.0, "travelling Heavy shows its physical contact radius")
			equal(model.warning_radius, 0.0, "travelling Heavy does not borrow Fuse's future blast warning")
			equal(shot.canonical_values(), before, "descriptor sampling leaves expanded authority unchanged")
		shot.lifetime_ticks = 0
		check(PixelSpellEffects.expanded_projectile_model(shot, definition, Vector2(500, 500), config).is_empty(), "expired mixed Heavy cannot retain a travelling descriptor")
	equal(count, 57, "all nonsingleton Heavy payloads use the expanded boundary")


func _cover() -> ElementReactionState:
	var cover := ElementReactionState.new()
	cover.entity_id = 4000
	cover.recipe_wire_id = 301
	cover.owner_id = 2
	cover.team_id = 2
	var definition := ElementChemistrySystem.recipe(301)
	# The east face must sit beyond the deposit's intentionally unmarked
	# center, but within the blast, so the first tick really is the east tick.
	cover.position_x = ORIGIN.x + ElementDepositState.TERMINAL_MAX_RADIUS + 12_000 + int(definition.radius)
	cover.position_y = ORIGIN.y
	cover.origin_x = cover.position_x
	cover.origin_y = cover.position_y
	cover.direction_x = 1000
	cover.radius = int(definition.radius)
	cover.length = int(definition.length)
	cover.endpoint_x = cover.position_x
	cover.endpoint_y = cover.position_y
	cover.created_tick = 0
	cover.active_tick = 45
	cover.decay_tick = 65
	cover.expiry_tick = 90
	cover.health = 32_000
	cover.source_a = 3001
	cover.source_b = 3002
	return cover


func _test_cover_clipping_and_cache() -> void:
	var config := SimConfig.new(120)
	for obstruction: String in ["worldbone", "active", "forming", "decaying", "broken"]:
		var presenter := Presenter.new()
		var world := CollisionWorld.new(2_000_000, 2_000_000)
		var cover := _cover()
		check(cover.validate(), "cover fixture is valid")
		var reactions: Array[ElementReactionState] = []
		if obstruction == "worldbone":
			world.add_obstacle(CollisionWorld.Obstacle.new(1, ORIGIN.x + 45_000, ORIGIN.y - 100_000, ORIGIN.x + 55_000, ORIGIN.y + 100_000))
		else:
			reactions.append(cover)
			if obstruction == "forming": cover.active_tick = 55
			if obstruction == "decaying": cover.decay_tick = 50
			if obstruction == "broken": cover.health = 0
		var before := cover.canonical_values()
		var deposit := _deposit()
		var cue := presenter.model(deposit, 50, config, world, reactions)
		var blocked := obstruction in ["worldbone", "active"]
		var eastern_end: Vector2 = cue.boundary_ticks[1]
		check(is_equal_approx(eastern_end.y, float(ORIGIN.y) / 1000.0) and eastern_end.x > float(ORIGIN.x + deposit.radius + 4000) / 1000.0, "fixture retains an east-facing marker outside the deposit's reserved center")
		var face_x := ORIGIN.x + 45_000 if obstruction == "worldbone" else ElementChemistrySystem.rampart_bounds(cover).position.x
		check(eastern_end.x < float(face_x) / 1000.0 + 0.001 if blocked else is_equal_approx(eastern_end.x, 620.0), "visible east footprint follows exact %s cover state" % obstruction)
		for field: String in ["boundary_ticks", "spokes"]:
			var points: PackedVector2Array = cue[field]
			for index: int in range(0, points.size(), 2):
				for fraction: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
					var point := Vector2i((points[index].lerp(points[index + 1], fraction) * 1000.0).round())
					check(CombatSystem.blast_clear_line(ORIGIN, point, world, reactions, 50, config), "every rendered line stays on the visible side of %s" % obstruction)
		equal(cover.canonical_values(), before, "clipping never mutates temporary cover")
		var checks := int(presenter.stats().line_checks)
		presenter.model(deposit, 51, config, world, reactions, true)
		equal(presenter.stats().line_checks, checks, "age/reduced changes reuse geometry without repeated clearance work")
		check(checks <= Presenter.RAY_COUNT * (Presenter.SEARCH_STEPS + 1), "one geometry build has a fixed clearance-call ceiling")
		if obstruction == "active":
			cover.pulse_index += 1
			cover.contacts = PackedInt64Array([7, 50, 1])
			cover.health -= 1
			presenter.model(deposit, 51, config, world, reactions)
			equal(presenter.stats().line_checks, checks, "contact bookkeeping and nonfatal damage do not rebuild unchanged cover geometry")
			cover.health = 0
			var opened := presenter.model(deposit, 51, config, world, reactions)
			equal(opened.boundary_ticks[1], Vector2(620, 500), "destroyed cover immediately invalidates its cached shadow")
		if obstruction == "worldbone":
			world.obstacle_view()[0].minimum_x += 300_000
			world.obstacle_view()[0].maximum_x += 300_000
			var opened := presenter.model(deposit, 51, config, world, reactions)
			equal(opened.boundary_ticks[1], Vector2(620, 500), "changed wall geometry cannot reuse a stale shadow")
	var bounded := Presenter.new()
	for index: int in range(Presenter.CACHE_LIMIT + 10):
		var deposit := _deposit()
		deposit.position_x += index * 1000
		bounded.model(deposit, 50, config, null, [])
		check(bounded.stats().cache_entries <= Presenter.CACHE_LIMIT, "aftermath geometry cache remains bounded")
