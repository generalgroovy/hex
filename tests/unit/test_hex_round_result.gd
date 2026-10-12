extends FluxTestSuite


const ABILITY_PATH := "res://content/abilities/foundation_abilities_v1.json"
const CHAMPION_PATH := "res://content/champions/foundation_champions_v1.json"

var abilities := AbilityCatalog.new()
var champions := ChampionCatalog.new()


func run() -> int:
	check(abilities.load_from_file(ABILITY_PATH), "round result loads production abilities")
	check(champions.load_from_file(CHAMPION_PATH, abilities), "round result loads production champions")
	if not abilities.last_error.is_empty() or not champions.last_error.is_empty():
		return finish("hex-round-result")
	for finish_reason: String in ["timeout", "score", "departure"]:
		_test_paid_result_boundary(finish_reason, false)
	_test_paid_result_boundary("timeout", true)
	_test_paid_rampart_retirement()
	return finish("hex-round-result")


func _fixture(mutable_geometry: bool) -> Dictionary:
	var world := SimWorld.new(120, 213, CollisionWorld.new(1_280_000, 960_000))
	check(champions.apply_to_player(world.player(), "oh_tipi"), "result host has authored champion stats")
	check(HexCourtPractice.configure(world, abilities, false), "result fixture configures real HEX spell loadout")
	# Exercise the production concrete sealed geometry, not only HexCourt's
	# compatibility subclass. The second fixture retains writable legacy cells.
	var court := HexChemistryWorld.new()
	var cells: Array[Vector2i] = []
	for cell: Vector2i in world.hex_court.cell_keys():
		cells.append(cell)
	check(court.configure_geometry(world.hex_court.origin, cells), "result fixture seals the same admitted geometry")
	court.chemistry_enabled = true
	world.hex_court = court
	if mutable_geometry:
		var terrain: Dictionary = court.cells
		terrain[Vector2i.ZERO].terrain = 2
		terrain[Vector2i.ZERO].elevation = 3
	var session := AuthoritativeSession.new()
	check(session.bind(world, champions, Vector2i(640, 710), "Result Host", [{"entity_id": 2, "name": "Result Guest"}], "duel_knot"), "result fixture binds a real two-player authority")
	check(session.begin_round({
		"bounds": [0, 0, 1280, 960], "score_limit": 3,
		"round_seconds": 15, "result_seconds": 2,
		"respawn_ms": 500, "spawn_protection_ms": 250,
		"spawns": [[640, 710], [1000, 800]],
	}), "result fixture enters the actual round lifecycle")
	var fire_wire := int(abilities.ability(abilities.spell_id_at("fire", "bolt")).wire_id)
	var heavy_wire := int(abilities.ability(abilities.spell_id_at("water", "heavy")).wire_id)
	check(world.player(2).place_proven_spell(0, fire_wire), "guest equips a real isolated Fire Bolt")
	check(world.player(2).place_proven_spell(1, heavy_wire), "guest equips a different paid startup for the departure boundary")
	for actor: PlayerState in world.players:
		actor.spawn_protection_ticks = 0
		actor.health_recovery_per_second = 0
	# The same paid command schedule used by the full-world snapshot fixture
	# creates a Steam product, a surviving flight and another paid startup.
	# The guest adds separate ordinary Fire ground, away from that reaction.
	var followup_requested := false
	for step: int in range(560):
		var slot := 0 if step in [0, 160, 260] else 1 if step == 100 else -1
		var host := world.player(1)
		# Faster Bolts finish this same short route before the old tick 190
		# followup. Submit one Fire request while flight survives after recovery,
		# preserving the scheduled Water requests and ordinary paid authority.
		if step > 160 and slot < 0 and not followup_requested and not world.projectiles.is_empty() and not court.products.is_empty() and host.pending_cast_wire_id == 0 and host.cast_recovery_ticks == 0 and host.spell_cooldown_for_wire(fire_wire) == 0:
			slot = 1
			followup_requested = true
		var pressed := int(SimCommand.SPELL_PRESSED_BITS[slot]) if slot >= 0 else 0
		var commands: Array[SimCommand] = [
			SimCommand.new(world.tick, 1, 0, 0, 0, pressed, 0, -1000, 640_000, 480_000),
			SimCommand.new(world.tick, 2, 0, 0, 0, SimCommand.PRESSED_SPELL_1 if step == 0 else 0, -1000, -1000, 900_000, 600_000),
		]
		if not world.step(commands):
			check(false, "paid result fixture step failed: " + world.last_error)
			return {}
		session.advance_round(world.combat_events)
		var ground := 0
		for record: Dictionary in court.casts.values():
			ground += int(record.ground)
		if not court.pending.is_empty() and not world.projectiles.is_empty() and not court.products.is_empty() and ground > 0:
			check(world.step([
				SimCommand.new(world.tick, 1),
				SimCommand.new(world.tick, 2, 0, 0, 0, SimCommand.PRESSED_SPELL_2, -1000, -1000, 900_000, 600_000),
			]), "guest admits its own real paid startup before the result")
			session.advance_round(world.combat_events)
			check(world.player(2).pending_cast_wire_id == heavy_wire and court.pending.has(2), "departing guest owns a live paid reservation")
			check(not world.projectiles.is_empty(), "rich result state retains its independent flight")
			check(int(court.metrics.matter_paid) >= HexChemistryWorld.MATTER_PER_CAST * 4, "rich result state is backed by at least four admitted payments")
			return {"world": world, "session": session}
	check(false, "paid command fixture must reach simultaneous startup, flight, ground and reaction")
	return {}


func _test_paid_result_boundary(finish_reason: String, mutable_geometry: bool) -> void:
	var fixture := _fixture(mutable_geometry)
	if fixture.is_empty():
		return
	var world: SimWorld = fixture.world
	var session: AuthoritativeSession = fixture.session
	var court: HexChemistryWorld = world.hex_court
	var round: SessionRound = session.session_round
	var victim: PlayerState = world.player(2)
	# Put a living participant inside admitted product coverage, so continued
	# RESULT stepping would expose the old chemistry instead of harmless terrain.
	var product: Dictionary = court.products.values()[0]
	var covered_cell: Vector2i = product.cells.keys()[0]
	var danger_point := court.origin + HexGrid.center(covered_cell)
	victim.position_x = danger_point.x
	victim.position_y = danger_point.y
	var before := HexWorldSnapshot.capture(world)
	check(not before.is_empty(), "rich paid active state has a valid positive-control snapshot")
	if before.is_empty():
		return
	check(not session.capture_envelope().is_empty(), "active paid fixture captures the real session envelope")
	var control := HexWorldSnapshot.prepare(before, world)
	check(control != null, "positive-control hazards restore independently")
	if control == null:
		return
	var control_health := control.player(2).health
	for _step: int in range(120):
		if not control.step([]):
			check(false, "positive-control world stays valid: " + control.last_error)
			break
	check(control.player(2).health < control_health, "unsealed paid product demonstrably damages its exposed participant")

	var tick_before := world.tick
	var chemistry_tick_before := court.current_tick
	var topology_before := court.immutable_topology()
	var origin_before := court.origin
	var map_before := [world.map_id, world.map_hash]
	var geometry_before := court.cell_keys()
	var metadata_before := _terrain_metadata(court)
	var next_ids := [world.next_projectile_id, court.next_cast_id, court.next_product_id, court.next_ground_part_id]
	var geometry_revision := court.render_revision
	var paid_before := int(court.metrics.matter_paid)
	var consumed_before := int(court.metrics.matter_consumed)
	var expected_expired := int(court.metrics.matter_expired)
	for record: Dictionary in court.casts.values():
		if bool(record.paid):
			expected_expired += int(record.unallocated) + int(record.ground)
	var result_events: Array[Dictionary] = []
	match finish_reason:
		"timeout":
			round.round_end_tick = world.tick
			result_events = session.advance_round([])
		"score":
			round.scores_by_entity[1] = 2
			victim.health = 0
			result_events = session.advance_round([{"type": "champion_defeated", "owner_id": 1, "target_id": 2}])
		"departure":
			# Actual removal drops the guest's score before _finish, and drops its
			# actor afterward. Its paid reservation must not outlive either edge.
			check(session.remove_peers([{"entity_id": 2}]) == 1, "actual guest departure removes the admitted actor")
			check(world.player(2) == null and victim.pending_cast_wire_id == 0, "departing actor startup was cancelled before its reservation retired")
	if finish_reason != "departure":
		check(result_events.any(func(event: Dictionary) -> bool: return event.type == "round_finished"), finish_reason + " seals a result")
	equal(round.phase, SessionRound.Phase.RESULT, "cleanup retains the authoritative RESULT phase")
	equal(world.tick, tick_before, "sealing never advances the world tick")
	equal(court.current_tick, chemistry_tick_before, "sealing never expires material at a fabricated future tick")
	equal([world.map_id, world.map_hash], map_before, "result keeps exact map identity")
	equal(court.origin, origin_before, "result keeps exact geometry origin")
	equal(court.cell_keys(), geometry_before, "result keeps every eligible cell")
	equal(_terrain_metadata(court), metadata_before, "result preserves sealed and writable terrain metadata")
	equal(court.immutable_topology(), topology_before, "result preserves the existing immutable topology handle")
	equal(court.render_revision, geometry_revision, "retiring material is not a geometry rebuild")
	equal([world.next_projectile_id, court.next_cast_id, court.next_product_id, court.next_ground_part_id], next_ids, "result preserves all monotonic source and part IDs")
	equal(int(court.metrics.matter_paid), paid_before, "result preserves paid source history")
	equal(int(court.metrics.matter_consumed), consumed_before, "product retirement never expires already-consumed matter twice")
	equal(int(court.metrics.matter_expired), expected_expired, "all and only remaining paid matter expires")
	check(court.conservation_valid(), "result preserves the finite provenance accounting equation")
	check(court.casts.is_empty() and court.products.is_empty() and court.pending.is_empty() and court.sources.is_empty(), "result retires every cast, product, startup and source relation")
	check(court.exposure.is_empty() and court.flow_carry.is_empty() and court.occupied_cells().is_empty(), "result retires exposure, displacement carry and occupied-material views")
	check(world.projectiles.is_empty(), "result retires live flights")
	for actor: PlayerState in world.players:
		equal(actor.pending_cast_wire_id, 0, "result retires pending actor identity even after roster removal")
		check(actor.has_valid_spell_slots(), "result never clears the selected weave")
	var sealed := HexWorldSnapshot.capture(world)
	check(not sealed.is_empty(), "the exact finish tick captures without waiting for sync_flights")
	check(not session.capture_envelope().is_empty(), "the exact finish tick captures a complete session envelope")
	if sealed.is_empty():
		return
	var restored := HexWorldSnapshot.prepare(sealed, world)
	check(restored != null, "the result snapshot restores through strict incoming preparation")
	if restored != null:
		equal(restored.state_hash(), world.state_hash(), "restored result is exact authority, not only structurally valid")
	var sealed_hash := world.state_hash()
	var value_revision := court.value_revision
	court.retire_round_material()
	equal(world.state_hash(), sealed_hash, "repeated retirement is authority-idempotent")
	equal(court.value_revision, value_revision, "repeated retirement does not invent presentation work")
	var health_by_actor := {}
	var positions_by_actor := {}
	for actor: PlayerState in world.players:
		health_by_actor[actor.entity_id] = actor.health
		positions_by_actor[actor.entity_id] = Vector2i(actor.position_x, actor.position_y)
	for _step: int in range(round.configured_result_ticks):
		check(world.step(session.commands_for_tick(SimCommand.new(world.tick, 1))), "neutral result tick remains a valid world step")
		check(session.advance_round(world.combat_events).is_empty(), "sealed result emits no repeated outcome")
		for actor: PlayerState in world.players:
			equal(actor.health, health_by_actor[actor.entity_id], "sealed material cannot cause post-result damage")
			equal(Vector2i(actor.position_x, actor.position_y), positions_by_actor[actor.entity_id], "sealed material cannot displace result participants")
	check(session.round_return_due(), "harmless result stepping preserves its exact return deadline")
	check(not session.capture_envelope().is_empty(), "result remains publishable through the entire return interval")


func _test_paid_rampart_retirement() -> void:
	var world := SimWorld.new(120, 214, CollisionWorld.new(1_280_000, 960_000))
	check(champions.apply_to_player(world.player(), "oh_tipi"), "Rampart result uses an authored champion")
	check(HexCourtPractice.configure(world, abilities, false), "Rampart result configures valid HEX authority")
	var base: CollisionWorld = world.collision
	base.add_obstacle(CollisionWorld.Obstacle.new(701, 100_000, 100_000, 200_000, 200_000, false))
	var wall_start := Vector2i(50_000, 150_000)
	var wall_delta := Vector2i(250_000, 0)
	var permanent_wall_result := base.move_box(wall_start, wall_delta, MovementTuning.PLAYER_RADIUS)
	check(permanent_wall_result.position != wall_start + wall_delta, "permanent worldbone is a blocking positive control")
	var session := AuthoritativeSession.new()
	check(session.bind(world, champions, Vector2i(640, 710), "Rampart Host", [{"entity_id": 2, "name": "Rampart Guest"}], "duel_knot"), "Rampart fixture binds two participants")
	check(session.begin_round({
		"bounds": [0, 0, 1280, 960], "score_limit": 3,
		"round_seconds": 15, "result_seconds": 2,
		"respawn_ms": 500, "spawn_protection_ms": 250,
		"spawns": [[640, 710], [1000, 800]],
	}), "Rampart fixture enters an active round")
	var court: HexChemistryWorld = world.hex_court
	var flux_before := world.player().flux
	if not _paid_earth_terminal(world) or not _paid_earth_terminal(world):
		return
	check(world.player().flux < flux_before, "the two Earth ingredients spent actor Flux")
	equal(int(court.metrics.matter_paid), 2 * HexChemistryWorld.MATTER_PER_CAST, "Rampart owns exactly two finite paid source budgets")
	check(court.products.size() == 1, "the two paid Earth terminals form one real reaction")
	if court.products.size() != 1:
		return
	var product: Dictionary = court.products.values()[0]
	equal(int(product.recipe_wire_id), 301, "the admitted reaction is Earth Rampart")
	# Advance its real formation clock; do not inject an active product or move
	# either clock into the future merely to force collision admission.
	for _step: int in range(120):
		check(world.step(session.commands_for_tick(SimCommand.new(world.tick, 1))), "paid Rampart advances through normal simulation")
		session.advance_round(world.combat_events)
		if world.tick > int(product.active_tick):
			break
	var physics := world.collision as HexCollisionWorld
	check(physics != null, "live simulation owns the dynamic HEX collision adapter")
	if physics == null:
		return
	check(not physics._solid.is_empty() and not physics._cover.is_empty(), "paid active Rampart supplies both solid movement and cover surfaces")
	if physics._solid.is_empty():
		return
	var blocked_cell: Vector2i = physics._solid.keys()[0]
	var blocked_point := court.origin + HexGrid.center(blocked_cell)
	var ray_start := blocked_point - Vector2i(120_000, 0)
	var ray_finish := blocked_point + Vector2i(120_000, 0)
	physics.begin_actor(Vector2i(1_000_000, 800_000), MovementTuning.PLAYER_RADIUS)
	check(not physics.can_occupy(blocked_point, MovementTuning.PLAYER_RADIUS), "paid Rampart blocks ordinary actor occupancy before the result")
	check(not physics.hex_pillar_segment_clear(ray_start, ray_finish), "paid Rampart blocks its cover ray before the result")
	equal(_move_values(physics.move_box(wall_start, wall_delta, MovementTuning.PLAYER_RADIUS)), _move_values(permanent_wall_result), "temporary Rampart leaves the distant permanent-wall baseline unchanged")
	check(not session.capture_envelope().is_empty(), "active paid Rampart is snapshot-valid before retirement")
	var tick_before := world.tick
	var chemistry_tick_before := court.current_tick
	var map_before := [world.map_id, world.map_hash, court.origin, court.cell_keys()]
	session.session_round.round_end_tick = world.tick
	session.advance_round([])
	equal(world.tick, tick_before, "cover retirement never advances the world clock")
	equal(court.current_tick, chemistry_tick_before, "cover retirement never fabricates a future chemistry tick")
	equal([world.map_id, world.map_hash, court.origin, court.cell_keys()], map_before, "cover retirement preserves exact map and topology")
	check(physics == world.collision and physics.base_world == base, "result preserves both collision objects and the permanent worldbone")
	check(physics._solid.is_empty() and physics._cover.is_empty() and physics._faces.is_empty(), "temporary movement, cover and attachment surfaces disappear on the exact finish tick")
	check(physics.can_occupy(blocked_point, MovementTuning.PLAYER_RADIUS), "retired Rampart permits occupancy immediately without another world step")
	check(physics.hex_pillar_segment_clear(ray_start, ray_finish), "retired Rampart permits its cover ray immediately")
	equal(_move_values(physics.move_box(wall_start, wall_delta, MovementTuning.PLAYER_RADIUS)), _move_values(permanent_wall_result), "result preserves the exact permanent-wall collision response")
	check(not physics.hex_segment_clear(wall_start, wall_start + wall_delta), "retiring temporary cover never opens the permanent wall to shots or rays")
	check(court.conservation_valid(), "retired Rampart retains its consumed paid-matter provenance")
	var sealed := HexWorldSnapshot.capture(world)
	check(not sealed.is_empty() and not session.capture_envelope().is_empty(), "exact cover-retirement boundary publishes valid world and session snapshots")
	if not sealed.is_empty():
		check(HexWorldSnapshot.prepare(sealed, world) != null, "retired-cover snapshot passes strict incoming preparation")


func _move_values(result: CollisionWorld.MoveResult) -> Array:
	return [result.position, result.wall_normal, result.wall_id, result.blocking_normals]


func _paid_earth_terminal(world: SimWorld) -> bool:
	# Same reserve/pay/bind/terminal path as the existing paid chemistry fixtures,
	# with an actual actor Flux debit as well as the source-budget commitment.
	var wire := int(abilities.ability(abilities.spell_id_at("earth", "bolt")).wire_id)
	var definition := CombatTuning.cast_definition(wire)
	var court: HexChemistryWorld = world.hex_court
	var reserved := court.reserve_cast(1, wire)
	check(reserved, "Earth terminal reserves an admitted chemistry cast")
	if not reserved:
		return false
	var paid := PlayerResourcesSystem.spend_flux(world.player(), int(definition.flux_cost), world.config)
	check(paid, "Earth terminal pays its ordinary Flux cost")
	if not paid:
		court.cancel_pending(1)
		return false
	court.commit_payment(1)
	var source := world.next_projectile_id
	world.next_projectile_id += 1
	court.bind_release(1, source, court.origin, Vector2i(1000, 0), 1)
	court.deposit_terminal({
		"type": "projectile_terminal", "projectile_id": source,
		"source_cast_id": source, "source_wire_id": wire,
		"owner_id": 1, "team_id": 1, "element_wire_id": int(definition.element_wire_id),
		"position": court.origin, "direction": Vector2i(1000, 0),
		"strength": 1000, "reaction_strength": int(definition.reaction_strength),
	}, world.tick)
	check(court.conservation_valid(), "paid Earth terminal retains valid source partitions")
	return true


func _terrain_metadata(court: HexChemistryWorld) -> Array:
	var result: Array = []
	for cell: Vector2i in court.cell_keys():
		var row := court.cell_record(cell)
		result.append([cell, row.get("terrain", 0), row.get("elevation", 0), row.get("structure", 0)])
	return result
