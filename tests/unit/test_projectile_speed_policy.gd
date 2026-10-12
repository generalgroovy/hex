extends FluxTestSuite
@warning_ignore_start("integer_division")
## Delivery speed is a H.E.X. hypothesis, not an imported balance number.
## Gungeon's developer describes testing weapon rhythms, patterns and cover:
## https://www.gamedeveloper.com/design/q-a-the-guns-and-dungeons-of-i-enter-the-gungeon-i-
## These fixtures test ordinary paid pursuit and physical counterplay, not feel.

const Snapshot = preload("res://src/net/hex_world_snapshot.gd")
const ORIGIN := Vector2i(2_000_000, 2_000_000)
const FAST := {"bolt": [1_260_000, 1_152_000, 915], "rapid": [1_440_000, 648_000, 450], "split": [1_080_000, 792_000, 734], "rebound": [1_170_000, 910_000, 778]}
const AUTHORED_RANGES := {140: 1_036_800, 145: 1_052_640, 142: 1_248_480}
var abilities := AbilityCatalog.new()
var champions := ChampionCatalog.new()


func run() -> int:
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "fast delivery catalog loads")
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "speed fixtures use finite authored characters")
	_test_catalog()
	_test_paid_endpoints()
	_test_paid_pursuit()
	_test_split_branch_pursuit()
	_test_paid_movement_chain()
	_test_paid_counters()
	_test_split_and_rebound()
	_test_paid_frostway()
	return finish("projectile-speed-policy")


func _test_catalog() -> void:
	equal(CombatTuning.runtime_wire_ids().size(), 504, "speed pass preserves six/63/eight/504 grammar")
	for mask: int in range(1, 64):
		for family: String in FAST:
			var wire := MixtureCatalog.wire_for(mask, family)
			var definition := CombatTuning.cast_definition_view(wire)
			var rule: Array = FAST[family]
			equal(int(definition.speed), int(rule[0]), "all masks share the actual fast delivery speed: %d" % wire)
			check(int(definition.speed) >= MovementTuning.MAX_AUTHORED_SPEED * 6 / 5, "fast delivery exceeds the bounded traversal cap by at least20 percent")
			equal(int(definition.range), int(AUTHORED_RANGES.get(wire, rule[1])), "nominal range stays exactly authored, including original singletons")
			check(int(definition.speed) * int(definition.lifetime_ms) / 1000 >= int(definition.range), "finite lifetime reaches the distance ceiling in clear flight")
			check(int(definition.speed) * (int(definition.lifetime_ms) - 1) / 1000 < int(definition.range), "flight timeout is the smallest whole millisecond that covers that range")
			equal(int(definition.element_mask), mask, "speed never changes the paid elemental payload")
		for family: String in ["heavy", "fuse"]:
			var definition := CombatTuning.cast_definition_view(MixtureCatalog.wire_for(mask, family))
			equal(int(definition.speed), 180_000 if family == "heavy" else 260_000, "deliberately slow pressure keeps its identity")
			check(not definition.has("range"), "slow delivery keeps its established lifetime/landing contract")
	var split := CombatTuning.cast_definition_view(MixtureCatalog.wire_for(16, "split"))
	equal(int(split.split_delay_ms), 77, "Split retains its near-muzzle fork distance at faster travel")
	check(SimConfig.new().milliseconds_to_ticks(int(split.split_delay_ms)) < SimConfig.new().milliseconds_to_ticks(int(split.lifetime_ms)), "Split has a positive remaining flight window")
	for value: Variant in [0, -1, 1.5, "900", 10_000_001]:
		var invalid := abilities.ability_from_wire(140).duplicate(true)
		invalid.range = value
		check(not abilities._validate_playable_simulation(invalid), "optional projectile distance rejects invalid scalar: %s" % str(value))
	for value: Variant in [0, -1, 1.5, 251, "77"]:
		var invalid := abilities.ability_from_wire(MixtureCatalog.wire_for(16, "split")).duplicate(true)
		invalid.split_delay_ms = value
		check(not abilities._validate_playable_simulation(invalid), "Split delay rejects invalid scalar: %s" % str(value))
	var wrong_family := abilities.ability_from_wire(140).duplicate(true)
	wrong_family.split_delay_ms = 77
	check(not abilities._validate_playable_simulation(wrong_family), "other deliveries cannot acquire a hidden Split timer")
	abilities.last_error = ""


func _world(with_target: bool = false, target_offset: Vector2i = Vector2i(300_000, 0)) -> SimWorld:
	var world := SimWorld.new(120, 212, CollisionWorld.new(5_000_000, 5_000_000))
	var court := HexChemistryWorld.new()
	var cells: Array[Vector2i] = []
	for q: int in range(-8, 66):
		for r: int in range(-10, 11): cells.append(Vector2i(q, r))
	check(court.configure_geometry(ORIGIN, cells), "finite flight corridor configures")
	court.chemistry_enabled = true
	world.hex_court = court
	check(champions.apply_to_player(world.player(), "oh_tipi"), "caster starts with ordinary finite authored resources")
	world.player().reset_for_spawn(ORIGIN)
	world.player().spawn_protection_ticks = 0
	if with_target:
		var target := PlayerState.new(2)
		check(champions.apply_to_player(target, "s_wayne"), "pursuit uses an actual fastest-profile small character")
		target.team_id = 2
		target.reset_for_spawn(ORIGIN + target_offset)
		target.spawn_protection_ticks = 0
		world.players.append(target)
	return world


func _commands(world: SimWorld, actor_press: int = 0, target_move: Vector2i = Vector2i.ZERO, target_held: int = 0, target_press: int = 0, endpoint: Vector2i = Vector2i(-1, -1)) -> Array[SimCommand]:
	var result: Array[SimCommand] = [SimCommand.new(world.tick, 1, 0, 0, 0, actor_press, 1000, 0, endpoint.x, endpoint.y)]
	if world.player(2) != null: result.append(SimCommand.new(world.tick, 2, target_move.x, target_move.y, target_held, target_press))
	return result


func _pay(world: SimWorld, wire: int, endpoint: Vector2i = Vector2i(-1, -1)) -> void:
	check(world.player().place_proven_spell(0, wire), "actual slot accepts the selected fast spell")
	var before := world.player().flux
	check(world.step(_commands(world, SimCommand.PRESSED_SPELL_1, Vector2i.ZERO, 0, 0, endpoint)), "ordinary spell command admits paid startup")
	equal(before - world.player().flux, int(CombatTuning.cast_definition_view(wire).flux_cost), "full authored Flux is spent exactly once")
	for unused: int in range(32):
		if world.player().pending_cast_wire_id == 0: break
		check(world.step([]), "paid preparation releases without a grant")
	equal(world.player().pending_cast_wire_id, 0, "ordinary paid preparation completed")
	equal(int(world.hex_court.metrics.matter_paid), 600, "faster flight still owns one finite paid source")
	check(not world.projectiles.is_empty(), "paid cast produces real flight")


func _test_paid_endpoints() -> void:
	for wire: int in [140, 145, 142, MixtureCatalog.wire_for(63, "bolt"), MixtureCatalog.wire_for(63, "rapid"), MixtureCatalog.wire_for(63, "rebound")]:
		for request: String in ["free", "near", "far"]:
			var world := _world()
			var definition := CombatTuning.cast_definition_view(wire)
			var endpoint := ORIGIN + Vector2i(200_000 if request == "near" else 2_000_000, 0) if request != "free" else Vector2i(-1, -1)
			_pay(world, wire, endpoint)
			if world.projectiles.is_empty(): continue
			var shot := world.projectiles[0]
			var muzzle := Vector2i(shot.previous_x, shot.previous_y)
			var expected := endpoint if request == "near" else muzzle + Vector2i(int(definition.range), 0)
			var terminal := Vector2i(-1, -1)
			for tick: int in range(160):
				check(world.step([]), "fast paid flight consumes bounded distance")
				for event: Dictionary in world.combat_events:
					if String(event.get("type", "")) == "projectile_expired": terminal = event.contact_position
				if world.projectiles.is_empty(): break
			equal(terminal, expected, "free/far range ceiling and closer cursor end exactly at the intended point: %d/%s" % [wire, request])
			equal(Vector2i(shot.position_x, shot.position_y), expected, "retained authoritative flight object ends at that exact point")
			equal(shot.remaining_distance, 0, "terminal exhausts the same finite distance budget")
			check(world.projectiles.is_empty(), "faster shots cannot persist beyond their authored range")
			check(world.hex_court.conservation_valid(), "flight and terminal conserve the original paid source")


func _test_paid_pursuit() -> void:
	for family: String in FAST:
		# Warm up from a rear position so release occurs near the shooter, while
		# the target already has real sprint momentum rather than injected speed.
		var world := _world(true, Vector2i(-190_000, 0))
		var target := world.player(2)
		var initial_stamina := target.stamina
		for tick: int in range(90):
			if target.position_x >= ORIGIN.x + 60_000 and target.velocity_x > 600_000: break
			check(world.step(_commands(world, 0, Vector2i(1000, 0), SimCommand.HELD_SPRINT)), "pursuit target earns its actual sprint before the cast")
		check(target.velocity_x > 600_000 and target.stamina < initial_stamina, "fastest-profile pursuit is moving with paid sprint reserve")
		check(target.position_x >= ORIGIN.x + 60_000 and target.position_x < ORIGIN.x + 66_000, "cast begins at the first observed pursuit window, never by repositioning the actor")
		var wire := MixtureCatalog.wire_for(16, family)
		check(world.player().place_proven_spell(0, wire), "pursuit equips real fast delivery")
		var paid := false
		var released := false
		var hit := false
		var largest_target_step := 0
		for tick: int in range(150):
			var old_x := target.position_x
			check(world.step(_commands(world, SimCommand.PRESSED_SPELL_1 if tick == 0 else 0, Vector2i(1000, 0), SimCommand.HELD_SPRINT)), "fast shot pursues ordinary moving opposition")
			largest_target_step = maxi(largest_target_step, target.position_x - old_x)
			for event: Dictionary in world.combat_events:
				paid = paid or String(event.get("type", "")) == "cast_started"
				released = released or String(event.get("type", "")) == "projectile_spawned"
				hit = hit or (String(event.get("type", "")) == "projectile_hit" and int(event.get("target_id", 0)) == 2)
			if hit: break
		check(paid and released, "pursuit actually pays and releases the chosen delivery")
		equal(hit, family != "split", "straight fast shots catch sprint; Split's central fan gap remains a usable weave counter: " + family)
		check(largest_target_step <= MovementTuning.MAX_AUTHORED_SPEED / 120 + 1, "opposition remains inside actual movement bound")
		check(world.hex_court.conservation_valid(), "pursuit hit conserves finite ownership")


func _test_split_branch_pursuit() -> void:
	# Lead the fan by fifteen degrees. Its upper branch then follows the runner's
	# lane; the center-gap control above must continue to miss the same small body.
	var world := _world(true, Vector2i(-190_000, -30_000))
	var target := world.player(2)
	for tick: int in range(90):
		if target.position_x >= ORIGIN.x + 60_000 and target.velocity_x > 600_000: break
		check(world.step(_commands(world, 0, Vector2i(1000, 0), SimCommand.HELD_SPRINT)), "branch pursuit earns ordinary fastest-profile sprint")
	check(world.player().place_proven_spell(0, MixtureCatalog.wire_for(16, "split")), "lead shot equips the same finite Split")
	var hit := false
	var forked := false
	var paid := false
	for tick: int in range(120):
		check(world.step([SimCommand.new(world.tick, 1, 0, 0, 0, SimCommand.PRESSED_SPELL_1 if tick == 0 else 0, 966, -259), SimCommand.new(world.tick, 2, 1000, 0, SimCommand.HELD_SPRINT)]), "ordinary angled aim directs the fan toward a sprinting lane")
		for event: Dictionary in world.combat_events:
			paid = paid or String(event.get("type", "")) == "cast_started"
			forked = forked or String(event.get("type", "")) == "projectile_split"
			hit = hit or (String(event.get("type", "")) == "projectile_hit" and int(event.get("target_id", 0)) == 2)
		if hit: break
	check(paid and forked and hit, "an actual fast Split branch catches the sprinting lane when its fan is led correctly")
	check(world.hex_court.conservation_valid(), "branch pursuit preserves shared finite paid strength")


func _test_paid_movement_chain() -> void:
	for family: String in FAST:
		var world := _world(true, Vector2i(0, 120_000))
		var target := world.player(2)
		for tick: int in range(40):
			check(world.step(_commands(world, 0, Vector2i(1000, 0), SimCommand.HELD_SPRINT)), "chain approach earns sprint momentum")
		var initial_stamina := target.stamina
		check(world.player().place_proven_spell(0, MixtureCatalog.wire_for(16, family)), "parallel chain comparison equips actual fast delivery")
		var compared := 0
		var paid_chain := false
		var dodge_seen := false
		for tick: int in range(60):
			var origin := Vector2i(target.position_x, target.position_y)
			var before := {}
			for shot: ProjectileState in world.projectiles: before[shot.entity_id] = Vector2i(shot.position_x, shot.position_y)
			var press := SimCommand.PRESSED_SLIDE if tick == 0 else (SimCommand.PRESSED_JUMP if tick == 5 else (SimCommand.PRESSED_EVADE if tick == 15 else 0))
			check(world.step(_commands(world, SimCommand.PRESSED_SPELL_1 if tick == 0 else 0, Vector2i(1000, 0), 0, press)), "real slide-jump-air-dodge chain progresses beside the paid projectile")
			paid_chain = paid_chain or target.movement_chain_count >= 3
			dodge_seen = dodge_seen or target.air_dodge_ticks > 0
			var travel := (Vector2i(target.position_x, target.position_y) - origin).length()
			check(travel <= float(MovementTuning.MAX_AUTHORED_SPEED) / 120.0 + 2.0, "actual paid chain respects the authored traversal bound")
			for shot: ProjectileState in world.projectiles:
				if not before.has(shot.entity_id): continue
				var flight := (Vector2i(shot.position_x, shot.position_y) - (before[shot.entity_id] as Vector2i)).length()
				check(flight > travel, "free fast projectile advances farther per tick than the real paid movement chain: " + family)
				compared += 1
		check(compared >= 20 and paid_chain and dodge_seen and target.stamina < initial_stamina, "comparison witnesses finite sprint/slide/jump/air-dodge, not an injected maximum velocity")


func _test_paid_counters() -> void:
	for family: String in ["bolt", "rapid", "rebound"]:
		for route: String in ["ground", "jump", "cover", "cross"]:
			var world := _world(true)
			if route == "cover": world.collision.add_obstacle(CollisionWorld.Obstacle.new(998, ORIGIN.x + 150_000, ORIGIN.y - 100_000, ORIGIN.x + 155_000, ORIGIN.y + 100_000))
			var wire := MixtureCatalog.wire_for(16, family)
			check(world.player().place_proven_spell(0, wire), "counter fixture equips a real paid fast cast")
			var hit := false
			var avoided := false
			var paid := false
			var jumped := false
			var jump_requested := false
			for tick: int in range(100):
				var press := 0
				if route == "jump" and not jump_requested:
					for shot: ProjectileState in world.projectiles:
						var remaining := world.player(2).position_x - shot.position_x
						if remaining > 0 and remaining * 1000 <= shot.velocity_x * 150:
							press = SimCommand.PRESSED_JUMP
							jump_requested = true
							break
				var move := Vector2i(0, 1000) if route == "cross" else Vector2i.ZERO
				check(world.step(_commands(world, SimCommand.PRESSED_SPELL_1 if tick == 0 else 0, move, SimCommand.HELD_JUMP if press else 0, press)), "counter route uses only ordinary input against paid flight")
				jumped = jumped or world.player(2).is_airborne()
				avoided = avoided or world.player(2).last_event == "evaded_projectile"
				for event: Dictionary in world.combat_events:
					paid = paid or String(event.get("type", "")) == "cast_started"
					hit = hit or (String(event.get("type", "")) == "projectile_hit" and int(event.get("target_id", 0)) == 2)
			check(paid, "counter route genuinely faces a paid cast")
			equal(hit, route == "ground", "cover, committed perpendicular motion and paid jump remain useful: " + family + "/" + route)
			if route == "jump": check(jumped and avoided, "jump earns height and survives an actual swept crossing")
			if route == "cover": check(not avoided, "cover resolves before protection feedback behind it")


func _test_split_and_rebound() -> void:
	var world := _world()
	_pay(world, MixtureCatalog.wire_for(16, "split"))
	if world.projectiles.is_empty(): return
	var muzzle := Vector2i(world.projectiles[0].previous_x, world.projectiles[0].previous_y)
	var fork := Vector2i.ZERO
	for tick: int in range(20):
		check(world.step([]), "Split reaches its finite travel fork")
		if world.projectiles.size() == 2:
			fork = Vector2i(world.projectiles[0].previous_x, world.projectiles[0].previous_y)
			break
	equal(world.projectiles.size(), 2, "one paid parent forks once before expiry")
	if world.projectiles.size() != 2: return
	check(absi(fork.x - muzzle.x - 79_750) <= 9_000, "fork stays within one new travel tick of its former muzzle distance")
	equal(world.projectiles[0].damage + world.projectiles[1].damage, 14_000, "fast branches partition the same direct damage")
	equal(world.projectiles[0].source_cast_id, world.projectiles[1].source_cast_id, "fast branches retain one source")
	equal(world.projectiles[0].remaining_distance, world.projectiles[1].remaining_distance, "new branch inherits the same remaining path ceiling")
	var packet := Snapshot.capture(world)
	check(not packet.is_empty(), "faster finite branches serialize through existing wire format")
	if not packet.is_empty():
		var restored := Snapshot.prepare(packet, world)
		check(restored != null, "strict network decoder admits exact fast branch state")
		if restored != null: equal(restored.state_hash(), world.state_hash(), "fast branch roundtrip preserves canonical state")
	var source := world.projectiles[0].source_cast_id
	for tick: int in range(100):
		if world.projectiles.is_empty(): break
		check(world.step([]), "shared finite branch flight ends")
		check(world.projectiles.size() <= 2, "branches never recursively multiply")
	equal(world.projectiles.size(), 0, "both branches exhaust their original flight window")
	equal(int(world.hex_court.ledger_for_source(source).budget), 600, "Split never buys extra source material")
	check(world.hex_court.conservation_valid(), "fast Split finishes with conserved source ownership")
	world = _world()
	world.collision.add_obstacle(CollisionWorld.Obstacle.new(999, ORIGIN.x + 200_000, ORIGIN.y - 100_000, ORIGIN.x + 210_000, ORIGIN.y + 100_000))
	_pay(world, MixtureCatalog.wire_for(16, "rebound"))
	var bounced := false
	var previous_remaining := 910_000
	for tick: int in range(130):
		if world.projectiles.is_empty(): break
		check(world.step([]), "banked fast flight remains finite")
		for shot: ProjectileState in world.projectiles:
			bounced = bounced or shot.remaining_bounces == 1
			check(shot.remaining_distance <= previous_remaining, "bank never resets the shared path budget")
			previous_remaining = shot.remaining_distance
	check(bounced and world.projectiles.is_empty(), "fast Rebound banks off real cover then expires")
	check(world.hex_court.conservation_valid(), "fast Rebound preserves finite payment through its bank")


func _test_paid_frostway() -> void:
	# Opposing ordinary Water casts create the lane; neither its source ledgers,
	# phase clocks nor footprint are injected. Later Light shots traverse it.
	for family: String in ["bolt", "rapid", "rebound"]:
		# Keep the opposing supplier beyond the far whole-cell edge plus both
		# contact radii; otherwise the legitimate actor hit ends flight in-lane.
		var world := _world(true, Vector2i(600_000, 0))
		for id: int in [1, 2]: check(world.player(id).place_proven_spell(0, 140), "Frostway setup equips actual Water")
		check(world.step([SimCommand.new(world.tick, 1, 0, 0, 0, SimCommand.PRESSED_SPELL_1, 1000, 0), SimCommand.new(world.tick, 2, 0, 0, 0, SimCommand.PRESSED_SPELL_1, -1000, 0)]), "both ordinary Water commands pay into opposing flight")
		equal(int(world.hex_court.metrics.matter_paid), 1200, "freezing lane begins with two separately paid source stocks")
		var product: Dictionary = {}
		for tick: int in range(180):
			for row: Dictionary in world.hex_court.products.values():
				if int(row.recipe_wire_id) == 316: product = row
			if not product.is_empty() and world.tick >= int(product.active_tick): break
			check(world.step([]), "real collision forms and activates the paid freezing lane")
		check(not product.is_empty() and world.tick >= int(product.active_tick), "two released paid Water Bolts form active Frostway")
		if product.is_empty(): continue
		var wire := MixtureCatalog.wire_for(16, family)
		check(world.player().place_proven_spell(0, wire), "lane probe equips actual fast Light delivery")
		check(world.step(_commands(world, SimCommand.PRESSED_SPELL_1)), "ordinary probe pays before entering existing terrain")
		var slowed := 0
		var restored := 0
		var saw_slow := false
		var trace := []
		for tick: int in range(120):
			var shot: ProjectileState = null
			for candidate: ProjectileState in world.projectiles:
				if candidate.source_wire_id == wire: shot = candidate
			var start := Vector2i.ZERO if shot == null else Vector2i(shot.position_x, shot.position_y)
			var inside: bool = shot != null and bool(world.hex_court.contains_stored(product, start))
			check(world.step([]), "paid probe advances through terrain without a speed override")
			if shot == null or not world.projectiles.has(shot): continue
			var step := shot.position_x - start.x
			var full_step := int(FAST[family][0]) / 120
			if trace.size() < 16: trace.append([world.tick, start.x - ORIGIN.x, start.y - ORIGIN.y, inside, step])
			equal(shot.velocity_x, int(FAST[family][0]), "terrain never rewrites authored projectile velocity")
			if inside:
				check(absi(step - full_step * 650 / 1000) <= 1, "active Frostway retains its meaningful65percent flight counter")
				slowed += 1
				saw_slow = true
			elif saw_slow:
				equal(step, full_step, "leaving actual field coverage restores full speed immediately")
				restored += 1
		check(slowed > 0 and restored > 0, "real paid fast flight observes both slowing and exit: %s slowed=%d restored=%d footprint=%s trace=%s" % [family, slowed, restored, str(product.get("footprint", {})), str(trace)])
		equal(int(world.hex_court.metrics.matter_paid), 1800, "terrain traversal has exactly three ordinary paid sources")
		check(world.hex_court.conservation_valid(), "paid Frostway and fast probe preserve shared finite ownership")
