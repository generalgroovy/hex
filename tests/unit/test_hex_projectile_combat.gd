extends FluxTestSuite

# Isolated resolver fixture: paid-ledger behavior is tested independently in
# HexCourt integration; this fixture controls exact collision order and time.
class LedgerCourt:
	extends RefCounted
	var ledgers := {}
	var products: Dictionary = {}
	var origin := Vector2i(200_000, 400_000)
	func contains_stored(record: Dictionary, point: Vector2i) -> bool:
		return HexFootprint.contains_selected(HexChemistryWorld.coverage(record), origin, point)
	func ledger_for_source(source: int) -> Dictionary:
		return ledgers.get(source, {})
	func flight_quantity(source: int, entity: int) -> int:
		return int(ledger_for_source(source).get("flight_quantity", 0)) if source == entity else 0
	func deposit_terminal(event: Dictionary, _tick: int, _spray_collision: CollisionWorld = null) -> void:
		StrengthBudget.deposit_quantity(ledger_for_source(int(event.source_cast_id)), int(ledger_for_source(int(event.source_cast_id)).flight_quantity))
	func resolve_contact(a: int, b: int, point: Vector2i, _tick: int) -> Dictionary:
		var result := StrengthBudget.consume_pair(ledger_for_source(a), ledger_for_source(b))
		if bool(result.accepted):
			products[products.size() + 1] = {"point": point, "quantity": int(result.first.consumed_quantity) + int(result.second.consumed_quantity), "recipe_wire_id": 310, "active_tick": 1000000, "decay_tick": 1000001}
			result.recipe_wire_id = 310
			result.reaction_id = products.size()
		return result


func run() -> int:
	_test_retired_inputs()
	_test_successive_order_and_no_terminal_duplication()
	_test_actor_before_clash_and_revalidation()
	_test_wall_tie_and_range_endpoint()
	_test_spray_zero_and_survivor()
	_test_released_dead_owner_and_splash_defeat()
	_test_height_lifetime_and_projection_bounds()
	_test_authored_heavy_area_preserves_counterplay()
	_test_heavy_impact_origin_cover()
	_test_heavy_hex_face_origin()
	_test_hit_events_report_realized_damage()
	_test_frostway_slow_never_increases_authored_power()
	return finish("hex-projectile-combat")


func _test_retired_inputs() -> void:
	equal(AbilityCatalog.DISPLAY_ELEMENT_IDS.size(), 6, "projectile geometry matrices cover exactly six live element rows")
	var court := HexCourt.new()
	court.chemistry_enabled = true
	equal(court.admission_reason(140), "", "retired refusal control has live chemistry and accepts an active Water Bolt")
	for retired: int in [101, 167, 170, 171, 187, 188, 189, 190]:
		check(CombatTuning.cast_definition(retired).is_empty(), "retired Ice/Charge wire has no compiled live projectile")
		equal(court.admission_reason(retired), "hex_unsupported_delivery", "retired refusal is unsupported content rather than preparation or capacity")
		check(not court.reserve_cast(1, retired), "retired projectile cannot acquire a paid source reservation")
	for retired_element: int in [5, 6]:
		for live_element: int in ElementRules.WIRE_IDS:
			equal(HexRecipePolicy.recipe_wire(retired_element, live_element), 0, "retired ingredient cannot silently alias a live reaction")
	equal(int(court.metrics.matter_paid), 0, "retired projectile refusals mint no source matter")


func _world() -> SimWorld:
	var world := SimWorld.new(120, 1, CollisionWorld.new(2_000_000, 2_000_000))
	world.players.clear()
	world.hex_court = LedgerCourt.new()
	return world


func _shot(world: SimWorld, id: int, strength: int, x: int, speed: int = 0, owner: int = 1, wire: int = 140) -> ProjectileState:
	var shot := ProjectileState.new(id, owner, owner, wire, 3, Vector2i(x, 400_000), Vector2i(speed, 0), 1000, 6000, 120)
	shot.source_cast_id = id
	shot.reaction_strength = strength
	(world.hex_court as LedgerCourt).ledgers[id] = StrengthBudget.make(id, strength, 600)
	world.projectiles.append(shot)
	return shot


func _events(world: SimWorld, kind: String, source: int = -1) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in world.combat_events:
		if event.get("type", "") == kind and (source < 0 or int(event.get("source_cast_id", event.get("projectile_id", -1))) == source): result.append(event)
	return result


func _target(world: SimWorld, x: int, id: int = 20) -> PlayerState:
	var actor := PlayerState.new(id)
	actor.team_id = 2
	actor.position_x = x
	actor.position_y = 400_000
	actor.radius = 18_000
	actor.health = 100_000
	actor.spawn_protection_ticks = 0
	world.players.append(actor)
	return actor


func _test_successive_order_and_no_terminal_duplication() -> void:
	var world := _world()
	var heavy := _shot(world, 1000, 15, 200_000, 12_000_000)
	_shot(world, 1002, 3, 280_000, 0, 2)
	_shot(world, 1003, 5, 250_000, 0, 2)
	HexProjectileCombat.advance(world)
	equal(world.projectiles.size(), 1, "only finite stronger survivor remains after two swept clashes")
	equal(heavy.remaining_strength, 7, "TOI orders strength15 to10 to7 despite reversed entity IDs")
	equal(heavy.initial_strength, 15, "initial provenance remains fifteen")
	var clashes := _events(world, "hex_clash")
	equal(clashes.size(), 2, "each exhausted partner creates exactly one clash result")
	equal(int(clashes[0].first_remaining), 10, "first event consumes nearby five")
	equal(int(clashes[1].first_remaining), 7, "second event consumes later three")
	equal(_events(world, "projectile_terminal").size(), 0, "exhausted collision inputs do not also emit terminal deposits")
	var ledger: Dictionary = world.hex_court.ledger_for_source(1000)
	equal(int(ledger.flight_quantity), 280, "survivor retains only its remaining paid material")
	equal(int(ledger.consumed_quantity), 320, "successive products consume200 then120 from Heavy")
	check(StrengthBudget.validate(ledger), "ordered resolver leaves conserved ledger")
	world.combat_events.clear()
	HexProjectileCombat.advance(world)
	equal(_events(world, "hex_clash").size(), 0, "destroyed projectiles cannot react on the next tick")


func _test_actor_before_clash_and_revalidation() -> void:
	var world := _world()
	_shot(world, 1000, 5, 200_000, 12_000_000)
	_shot(world, 1001, 5, 250_000, 0, 2)
	var target := _target(world, 240_000)
	HexProjectileCombat.advance(world)
	equal(target.health, 94000, "earlier actor contact receives one direct hit")
	equal((world.hex_court as LedgerCourt).products.size(), 0, "later queued clash is invalid after actor termination")
	equal(_events(world, "projectile_terminal", 1000).size(), 1, "actor contact has exactly one terminal")
	world = _world()
	_shot(world, 1000, 15, 200_000, 12_000_000)
	_shot(world, 1001, 5, 240_000, 0, 2)
	target = _target(world, 280_000)
	HexProjectileCombat.advance(world)
	equal(target.health, 96000, "later actor hit uses remaining10/15 damage after prior clash")
	equal(_events(world, "projectile_terminal", 1001).size(), 0, "exhausted partner cannot deposit while survivor hits")
	# The first shot kills the closest actor; the second must skip that now-dead
	# queued contact and continue to the next enemy instead of disappearing.
	world = _world()
	_shot(world, 1000, 5, 205_000, 12_000_000)
	_shot(world, 1001, 5, 200_000, 12_000_000)
	target = _target(world, 240_000)
	target.health = 6000
	var farther := _target(world, 290_000, 21)
	HexProjectileCombat.advance(world)
	equal(target.health, 0, "earliest projectile kills the first enemy")
	equal(farther.health, 94000, "later projectile revalidates dead target then reaches farther enemy")


func _test_wall_tie_and_range_endpoint() -> void:
	var world := _world()
	_shot(world, 1000, 5, 200_000, 12_000_000)
	_shot(world, 1001, 5, 242_000, 0, 2)
	world.collision.add_obstacle(CollisionWorld.Obstacle.new(7, 241_000, 390_000, 260_000, 410_000, false))
	HexProjectileCombat.advance(world)
	equal(_events(world, "hex_clash").size(), 0, "wall wins an exact pair contact tie")
	var terminal := _events(world, "projectile_terminal", 1000)
	equal(terminal.size(), 1, "wall terminated source deposits once")
	if not terminal.is_empty(): equal(terminal[0].position, Vector2i(241_000, 400_000), "wall deposit uses physical wall surface")
	world = _world()
	var shot := _shot(world, 1000, 5, 200_000, 12_000_000)
	shot.remaining_distance = 40_000
	_shot(world, 1001, 5, 242_000, 0, 2)
	HexProjectileCombat.advance(world)
	equal(_events(world, "hex_clash").size(), 1, "clash at exact range endpoint precedes ordinary expiry")
	equal(_events(world, "projectile_terminal").size(), 0, "range tie does not duplicate exhausted payload")
	world = _world()
	shot = _shot(world, 1000, 5, 200_000, 12_000_000)
	shot.remaining_distance = 10_000
	_shot(world, 1001, 5, 250_000, 0, 2)
	HexProjectileCombat.advance(world)
	equal(_events(world, "hex_clash").size(), 0, "pair beyond earlier range endpoint is ineligible")
	terminal = _events(world, "projectile_terminal", 1000)
	if not terminal.is_empty(): equal(terminal[0].position, Vector2i(210_000, 400_000), "range terminal uses exact consumed travel")


func _test_spray_zero_and_survivor() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "production catalogue loads for pulse fixture")
	var wire := int(catalog.ability(catalog.spell_id_at("fire", "spray")).wire_id)
	for strength: int in [3, 15]:
		var world := _world()
		var owner := PlayerState.new(2)
		owner.team_id = 2
		world.players.append(owner)
		var shot := _shot(world, 1000, strength, 250_000, 0)
		(world.hex_court as LedgerCourt).ledgers[1001] = StrengthBudget.make(1001, 3, 600)
		world.combat_events.append({"type": "spray_requested", "source_cast_id": 1001, "owner_id": 2,
			"source_wire_id": wire, "origin_x": 200_000, "origin_y": 400_000, "aim_x": 1000, "aim_y": 0, "target_x": 300_000, "target_y": 400_000})
		HexProjectileCombat.resolve_sprays(world)
		equal(_events(world, "hex_clash").size(), 1, "instant pulse clash emits one result for equal or unequal strength")
		equal(_events(world, "projectile_terminal", 1001).size(), 0, "exhausted pulse never deposits or damages after interception")
		equal(_events(world, "spray_fired").size(), 0, "exhausted pulse cannot resolve actor damage")
		if strength == 15:
			equal(shot.remaining_strength, 12, "stronger flight loses exact pulse strength")
		else:
			equal(world.projectiles.size(), 0, "equal pulse exhausts both participants")


func _test_released_dead_owner_and_splash_defeat() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "catalogue loads for paid-release regression")
	var world := _world()
	var owner := PlayerState.new(2)
	owner.health = 0 # Captured release already paid before this phase's damage.
	owner.team_id = 2
	world.players.append(owner)
	var target := _target(world, 250_000)
	target.team_id = 3
	var wire := int(catalog.ability(catalog.spell_id_at("fire", "spray")).wire_id)
	(world.hex_court as LedgerCourt).ledgers[1001] = StrengthBudget.make(1001, 3, 600)
	world.combat_events.append({"type": "spray_requested", "source_cast_id": 1001, "owner_id": 2,
		"source_wire_id": wire, "origin_x": 200_000, "origin_y": 400_000, "aim_x": 1000, "aim_y": 0, "target_x": 300_000, "target_y": 400_000})
	HexProjectileCombat.resolve_sprays(world)
	check(target.health < 100000, "already released paid pulse is not suppressed by owner death in its phase")
	equal(_events(world, "projectile_terminal", 1001).size(), 1, "released paid pulse retains exactly one terminal")
	world = _world()
	wire = int(catalog.ability(catalog.spell_id_at("water", "heavy")).wire_id)
	var heavy := _shot(world, 1000, 15, 200_000, 0, 1, wire)
	var direct := _target(world, 200_000)
	var splash := _target(world, 240_000, 21)
	splash.health = 1000
	check(HexProjectileCombat.sync_strength(world), "Heavy obtains its paid projection")
	HexProjectileCombat._terminal(world, heavy, Vector2i(200_000, 400_000), "actor", direct.entity_id)
	equal(direct.health, 100000, "direct victim remains excluded from secondary blast")
	equal(splash.health, 0, "secondary blast can defeat a nearby champion")
	var defeats := _events(world, "champion_defeated")
	equal(defeats.size(), 1, "secondary blast emits the authoritative defeat event")
	if not defeats.is_empty(): equal(int(defeats[0].target_id), splash.entity_id, "defeat event identifies splash victim")


func _test_height_lifetime_and_projection_bounds() -> void:
	for height: int in [MovementTuning.GROUND_PROJECTILE_CLEARANCE_HEIGHT - 1, MovementTuning.GROUND_PROJECTILE_CLEARANCE_HEIGHT]:
		var world := _world()
		_shot(world, 1000, 5, 200_000, 12_000_000)
		var target := _target(world, 240_000)
		target.air_height = height
		HexProjectileCombat.advance(world)
		equal(target.health < 100000, height < MovementTuning.GROUND_PROJECTILE_CLEARANCE_HEIGHT, "ground flight uses exact authoritative height boundary")
	var world := _world()
	var shot := _shot(world, 1000, 5, 200_000, 12_000_000)
	shot.lifetime_ticks = 1
	_shot(world, 1001, 5, 302_000, 0, 2)
	HexProjectileCombat.advance(world)
	equal(_events(world, "hex_clash").size(), 1, "exact lifetime endpoint clash precedes terminal expiry")
	equal(_events(world, "projectile_terminal").size(), 0, "lifetime tie cannot duplicate the exhausted ingredients")
	world = _world()
	shot = _shot(world, 1000, 5, 200_000)
	var canonical := shot.canonical_values()
	shot.initial_strength = 5
	shot.remaining_strength = 2
	equal(shot.canonical_values(), canonical, "derived hex projections do not alter legacy canonical state")
	var sibling := _shot(world, 1001, 5, 250_000)
	sibling.source_cast_id = 1000
	check(not HexProjectileCombat.sync_strength(world), "court refuses unpartitioned multiflight source")
	check(world.last_error.contains("allocated flight branch"), "a sibling without a finite allocation is explicitly rejected")


func _test_authored_heavy_area_preserves_counterplay() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "Heavy area tests load all eight authored families")
	for element: String in AbilityCatalog.DISPLAY_ELEMENT_IDS:
		var wire := int(catalog.ability(catalog.spell_id_at(element, "heavy")).wire_id)
		var definition := CombatTuning.cast_definition(wire)
		for scenario: String in ["new_area", "edge", "outside", "below_clearance", "airborne", "cover", "spawn", "ally", "direct", "weakened_inside", "weakened_outside"]:
			var world := _world()
			var heavy := _shot(world, 1000, int(definition.reaction_strength), 200_000, 0, 1, wire)
			heavy.radius = int(definition.radius)
			heavy.damage = int(definition.damage)
			var distance := 110_000 # Beyond the previous 84px blast plus this target's 18px body.
			if scenario == "edge": distance = 138_000
			if scenario == "outside": distance = 138_001
			if scenario == "weakened_outside": distance = 125_000
			var target := _target(world, 200_000 + distance)
			if scenario == "below_clearance": target.air_height = MovementTuning.GROUND_PROJECTILE_CLEARANCE_HEIGHT - 1
			if scenario == "airborne": target.air_height = MovementTuning.GROUND_PROJECTILE_CLEARANCE_HEIGHT
			if scenario == "cover": world.collision.add_obstacle(CollisionWorld.Obstacle.new(7, 250_000, 390_000, 260_000, 410_000, false))
			if scenario == "spawn": target.spawn_protection_ticks = 1
			if scenario == "ally": target.team_id = heavy.team_id
			var ledger: Dictionary = world.hex_court.ledger_for_source(1000)
			if scenario.begins_with("weakened"):
				var outcome := StrengthBudget.consume_pair(ledger, StrengthBudget.make(1001, 5, 600))
				check(bool(outcome.accepted), "a prior five-strength clash consumes paid Heavy strength")
			check(HexProjectileCombat.sync_strength(world), "authored Heavy is projected from its conserved source")
			var expected_radius := 97_980 if scenario.begins_with("weakened") else 120_000
			equal(HexProjectileCombat.terminal_radius(heavy), expected_radius, "120px Heavy area still contracts with remaining strength")
			HexProjectileCombat._terminal(world, heavy, Vector2i(200_000, 400_000), "range", target.entity_id if scenario == "direct" else 0)
			var expected_damage := 0
			if scenario in ["new_area", "edge", "below_clearance"]: expected_damage = 18_000
			if scenario == "weakened_inside": expected_damage = 12_000
			equal(target.health, 100_000 - expected_damage, "%s Heavy: enlarged %s area retains exact hit and refusal boundary" % [element, scenario])
			equal(_events(world, "projectile_hit").size(), 1 if expected_damage > 0 else 0, "Heavy secondary contact emits only its actual accepted hit")
			equal(_events(world, "projectile_terminal", 1000).size(), 1, "larger area emits exactly one terminal, never a second paid source")
			equal(int(ledger.flight_quantity), 0, "terminal retires all remaining flight material")
			equal(int(ledger.deposited_quantity), 400 if scenario.begins_with("weakened") else 600, "wider area does not multiply deposited matter")
			check(StrengthBudget.validate(ledger), "enlarged or weakened terminal preserves finite material accounting")


func _test_heavy_impact_origin_cover() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "Heavy cover regressions use real authored definitions")
	var anchor := Vector2i(400_000, 400_000)
	for element: String in AbilityCatalog.DISPLAY_ELEMENT_IDS:
		var wire := int(catalog.ability(catalog.spell_id_at(element, "heavy")).wire_id)
		var definition := CombatTuning.cast_definition(wire)
		for quarter: int in 4:
			for weakened: bool in [false, true]:
				for scenario: String in ["corner_hidden", "corner_exposed", "wall_front", "wall_back"]:
					var world := _world()
					var heavy := _shot(world, 1000, 15, 0, 0, 1, wire)
					var start := anchor + _quarter_turn(Vector2i(-30_000, 0), quarter)
					var velocity := _quarter_turn(Vector2i(12_000_000, 0), quarter)
					heavy.position_x = start.x
					heavy.position_y = start.y
					heavy.velocity_x = velocity.x
					heavy.velocity_y = velocity.y
					heavy.radius = int(definition.radius)
					heavy.damage = int(definition.damage)
					var low := Vector2i(33_000, 50_000)
					var high := Vector2i(47_000, 55_000)
					var secondary := Vector2i(60_000, 110_000)
					var direct: PlayerState = null
					if scenario.begins_with("corner"):
						# The actual actor impact is at +30px; the flight center
						# stops at zero. The two rays disagree at this short wall.
						direct = _target(world, 0, 20)
						var direct_point := anchor + _quarter_turn(Vector2i(48_000, 0), quarter)
						direct.position_x = direct_point.x
						direct.position_y = direct_point.y
						if scenario == "corner_exposed":
							low.x = 19_000
							high.x = 29_000
					else:
						low = Vector2i(30_000, -50_000)
						high = Vector2i(40_000, 50_000)
						secondary = Vector2i(-30_000 if scenario == "wall_front" else 70_000, 80_000)
					var rotated_low := anchor + _quarter_turn(low, quarter)
					var rotated_high := anchor + _quarter_turn(high, quarter)
					world.collision.add_obstacle(CollisionWorld.Obstacle.new(7,
						mini(rotated_low.x, rotated_high.x), mini(rotated_low.y, rotated_high.y),
						maxi(rotated_low.x, rotated_high.x), maxi(rotated_low.y, rotated_high.y), false))
					var target := _target(world, 0, 21)
					var target_point := anchor + _quarter_turn(secondary, quarter)
					target.position_x = target_point.x
					target.position_y = target_point.y
					var ledger: Dictionary = world.hex_court.ledger_for_source(1000)
					if weakened:
						check(bool(StrengthBudget.consume_pair(ledger, StrengthBudget.make(1001, 5, 600)).accepted), "corner fixture consumes finite Heavy strength before impact")
					HexProjectileCombat.advance(world)
					var exposed := scenario in ["corner_exposed", "wall_front"]
					var damage := (12_000 if weakened else 18_000) if exposed else 0
					var label := "%s/%s/quarter%d/weakened%s" % [element, scenario, quarter, weakened]
					equal(target.health, 100_000 - damage, "physical impact cover controls Heavy splash: " + label)
					if direct != null:
						equal(direct.health, 100_000 - (16_000 if weakened else 24_000), "direct victim receives no duplicate splash: " + label)
					var terminal := _events(world, "projectile_terminal", 1000)
					equal(terminal.size(), 1, "physical contact emits one terminal: " + label)
					if not terminal.is_empty():
						equal(terminal[0].position, anchor + _quarter_turn(Vector2i(30_000, 0), quarter), "cover correction preserves exact impact and deposit position: " + label)
					equal(world.projectiles.size(), 0, "terminal cannot leave a surviving projectile: " + label)
					equal(int(ledger.deposited_quantity), 400 if weakened else 600, "cover correction preserves finite terminal matter: " + label)
					check(StrengthBudget.validate(ledger), "corner outcome conserves the paid ledger: " + label)


func _test_heavy_hex_face_origin() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "hex-face Heavy tests use production data")
	var wire := int(catalog.ability(catalog.spell_id_at("water", "heavy")).wire_id)
	var definition := CombatTuning.cast_definition(wire)
	var origin := Vector2i(500_000, 500_000)
	for normal: Vector2i in HexConvexGeometry.NORMALS:
		for side: int in [-1, 1]:
			var world := _world()
			var collision := HexCollisionWorld.new(world.collision)
			var occupied: Array[Vector2i] = [Vector2i.ZERO]
			check(collision.configure_hexes(origin, HexGrid.disk(Vector2i.ZERO, 6), occupied), "actual six-face cover query is configured")
			world.collision = collision
			var contact := HexConvexGeometry.sweep_circle(origin + normal * 100, origin, int(definition.radius), Vector2i.ZERO, origin)
			check(not contact.is_empty(), "authored Heavy sweep reaches an actual hex face")
			if contact.is_empty(): continue
			var heavy := _shot(world, 1000, 15, int(contact.center.x), 0, 1, wire)
			heavy.position_y = int(contact.center.y)
			heavy.radius = int(definition.radius)
			heavy.damage = int(definition.damage)
			var target_point: Vector2i = contact.point + normal * (80 * side)
			var target := _target(world, target_point.x)
			target.position_y = target_point.y
			check(collision.can_occupy(target_point, target.radius), "front/back hex target has room outside the pillar")
			check(HexProjectileCombat.sync_strength(world), "hex-face blast retains its valid finite source")
			HexProjectileCombat._terminal(world, heavy, contact.point, "construct")
			equal(target.health, 82_000 if side > 0 else 100_000, "all six faces allow outward splash and block splash through the pillar")
			var terminal := _events(world, "projectile_terminal", 1000)
			equal(terminal.size(), 1, "hex-face cover correction emits exactly one terminal")
			if not terminal.is_empty(): equal(terminal[0].position, contact.point, "ray nudge never moves deposited hex matter")
			check(StrengthBudget.validate(world.hex_court.ledger_for_source(1000)), "hex-face contact conserves its paid source")


func _test_hit_events_report_realized_damage() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "damage receipt fixtures use production spells")
	for route: String in ["projectile", "splash", "spray"]:
		for scenario: String in ["mitigated", "threshold", "lethal"]:
			var world := _world()
			var target := _target(world, 240_000)
			target.champion_wire_id = 15 if scenario == "threshold" else 19
			target.health_maximum = 100_000
			target.health = 76_000 if scenario == "threshold" else (1000 if scenario == "lethal" else 100_000)
			target.cast_recovery_ticks = 1 if scenario != "threshold" else 0
			var health_before := target.health
			var raw_damage := 6000
			if route == "projectile":
				_shot(world, 1000, 5, 200_000, 12_000_000)
				HexProjectileCombat.advance(world)
			elif route == "splash":
				var wire := int(catalog.ability(catalog.spell_id_at("water", "heavy")).wire_id)
				var definition := CombatTuning.cast_definition(wire)
				var heavy := _shot(world, 1000, 15, 200_000, 0, 1, wire)
				heavy.damage = int(definition.damage)
				raw_damage = int(definition.blast_damage)
				check(HexProjectileCombat.sync_strength(world), "receipt splash owns conserved paid material")
				HexProjectileCombat._terminal(world, heavy, Vector2i(200_000, 400_000), "range")
			else:
				var wire := int(catalog.ability(catalog.spell_id_at("fire", "spray")).wire_id)
				var definition := CombatTuning.cast_definition(wire)
				raw_damage = int(definition.damage)
				var owner := PlayerState.new(1)
				owner.team_id = 1
				CombatSystem._resolve_spray(owner, wire, definition, Vector2i(200_000,400_000), Vector2i(1000,0), Vector2i(500_000,400_000), world.players, world.config, world.collision, world.combat_events)
			@warning_ignore("integer_division")
			var expected := mini(health_before, raw_damage * (1050 if scenario == "threshold" else 900) / 1000)
			equal(target.health, health_before - expected, "actual perk and lethal Health outcome: " + route + "/" + scenario)
			var hits := _events(world, "spray_hit" if route == "spray" else "projectile_hit")
			equal(hits.size(), 1, "one confirmed hit receipt: " + route + "/" + scenario)
			if not hits.is_empty():
				equal(int(hits[0].damage), expected, "receipt uses realized Health loss, not raw damage or post-hit threshold: " + route + "/" + scenario)
			equal(_events(world, "champion_defeated").size(), 1 if scenario == "lethal" else 0, "realized receipt preserves single defeat event")


func _quarter_turn(value: Vector2i, quarter: int) -> Vector2i:
	match quarter:
		1: return Vector2i(-value.y, value.x)
		2: return -value
		3: return Vector2i(value.y, -value.x)
	return value


func _test_frostway_slow_never_increases_authored_power() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "field-slow tests use current launch definitions")
	var footprint_court := HexChemistryWorld.new()
	for element: String in AbilityCatalog.DISPLAY_ELEMENT_IDS:
		for family: String in ["rapid", "bolt", "heavy"]:
			var wire := int(catalog.ability(catalog.spell_id_at(element, family)).wire_id)
			var definition := CombatTuning.cast_definition(wire)
			for product_count: int in [0, 1, 2]:
				var world := _world()
				var shot := _shot(world, 1000, int(definition.reaction_strength), 200_000, int(definition.speed), 1, wire)
				shot.radius = int(definition.radius)
				shot.damage = int(definition.damage)
				var court := world.hex_court as LedgerCourt
				for index: int in product_count:
					court.products[index + 1] = {"recipe_wire_id": 316, "active_tick": 0, "decay_tick": 10, "coverage": {Vector2i.ZERO: 1}}
				HexProjectileCombat.advance(world)
				check(world.last_error.is_empty(), "slowed flight remains authoritative and paid")
				equal(world.projectiles.size(), 1, "Frostway is not an impact or a source-creating field")
				@warning_ignore("integer_division")
				var expected_step := int(definition.speed) * (650 if product_count > 0 else 1000) / 1000 / 120
				equal(shot.position_x - 200_000, expected_step, "one or overlapping Frostways slow displacement to65%, without stacking")
				equal(shot.velocity_x, int(definition.speed), "authored launch speed remains the baseline, not a power input")
				equal(shot.reaction_strength, int(definition.reaction_strength), "field slowing never grants authored reaction strength")
				equal(shot.initial_strength, int(definition.reaction_strength), "field slowing preserves initial source provenance")
				equal(shot.remaining_strength, int(definition.reaction_strength), "field slowing cannot replenish remaining clash strength")
				equal(HexProjectileCombat.scaled_damage(shot), int(definition.damage), "slower displacement does not increase direct damage")
				equal(shot.radius, int(definition.radius), "field slowing does not increase collision size")
				equal(HexProjectileCombat.terminal_radius(shot), int(definition.get("blast_radius", 0)), "field slowing does not increase radial blast size")
				equal(shot.lifetime_ticks, 119, "slowed shots still spend one finite lifetime tick")
				var ledger: Dictionary = court.ledger_for_source(1000)
				equal(int(ledger.flight_quantity), 600, "field slowing cannot mint paid flight material")
				equal(int(ledger.deposited_quantity), 0, "flight creates no trail residue while slowed")
				check(StrengthBudget.validate(ledger), "slowed flight retains its unchanged finite ledger")
				var footprint := footprint_court.terminal_footprint({"position": Vector2i(shot.position_x, shot.position_y)}, {"wire": wire, "ledger": ledger})
				equal(int(footprint.radius), 120_000 if family == "heavy" else (12_000 if family == "rapid" else 34_000), "field slowing cannot enlarge the terminal chemistry footprint")
