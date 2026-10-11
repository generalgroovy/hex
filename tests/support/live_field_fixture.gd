extends RefCounted

const ORIGIN := Vector2i(600_000, 500_000)
const BOLTS := {1:159, 2:145, 3:140, 4:163, 7:173, 8:142}

# Test-only construction uses the same reservation, payment, source binding and
# contact transaction as gameplay. No reaction record or damage pool is injected.
static func make(wire: int, direction: Vector2i = Vector2i(1000, 0), copies: int = 1) -> SimWorld:
	var world := SimWorld.new(120, 817, CollisionWorld.new(2_000_000, 1_500_000))
	world.hex_court = HexChemistryWorld.new()
	var court: HexChemistryWorld = world.hex_court
	if not court.configure_geometry(ORIGIN, HexGrid.disk(Vector2i.ZERO, 18)): return null
	court.chemistry_enabled = true
	court.collision = world.collision
	var owner := world.player()
	owner.champion_wire_id = 0
	owner.position_x = 100_000
	owner.position_y = 100_000
	owner.spawn_protection_ticks = 0
	var actor := PlayerState.new(2)
	actor.team_id = 2
	actor.position_x = ORIGIN.x
	actor.position_y = ORIGIN.y
	actor.spawn_protection_ticks = 0
	actor.health_recovery_per_second = 0
	world.players.append(actor)
	var elements: Array = HexRecipePolicy.definition(wire).get("elements", [])
	if elements.size() != 2: return null
	for index: int in copies:
		var first := 1000 + index * 2
		for part: int in 2:
			var source := first + part
			if not court.reserve_cast(1, int(BOLTS[int(elements[part])])): return null
			court.commit_payment(1)
			court.bind_release(1, source, ORIGIN, direction, 1)
		if not bool(court.resolve_contact(first, first + 1, ORIGIN, 0).get("accepted", false)): return null
		court.sync_flights(world.players, world.projectiles)
	world.next_projectile_id = 1000 + copies * 2
	court.sync_flights(world.players, world.projectiles)
	world.collision = HexCollisionWorld.new(world.collision)
	world.reaction_movement = world.collision
	if not world.collision.set_hex_surfaces(court, 0): return null
	return world


static func set_tick(world: SimWorld, tick: int) -> bool:
	world.tick = tick
	# SimWorld.tick is the next step; chemistry retains the last completed tick.
	world.hex_court.current_tick = maxi(0, tick - 1)
	return world.collision.set_hex_surfaces(world.hex_court, tick)


static func ratio(world: SimWorld, actor: PlayerState, tick: int, point: Vector2i) -> int:
	return int(HexProductEffects.pre_movement(world.hex_court, actor, tick, point, world.config).ground_target_ratio)
