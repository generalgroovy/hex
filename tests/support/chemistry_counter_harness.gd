extends "res://tests/support/chemistry_coach_harness.gd"

const Chemistry = preload("res://src/sim/chemistry/element_chemistry_system.gd")
var radiance_origin := Vector2i.ZERO
var steam_origin := Vector2i.ZERO
var overlap_point := Vector2i.ZERO
var cast_receipts: Array[Dictionary] = []
var failure := ""


# Four real depositing casts in two separate admission cells. The optional
# immutable wall is fixture-only geometry, not a new object in the campus JSON.
func configure_counter(blocked: bool = false, render: bool = false) -> bool:
	if not configure_fixture(render):
		return _fail("base Crucible fixture failed")
	radiance_origin = fixture_anchor + Vector2i(-64_000, -112_000)
	steam_origin = radiance_origin + Vector2i(Chemistry.CELL_SIZE, 0)
	overlap_point = radiance_origin + Vector2i(52_000, 0)
	# Single paid Rapid shots isolate the terminal-origin reveal/cover contract.
	# Bolt now also leaves trails, whose valid reaction midpoint is not the
	# cursor endpoint used to position this immutable obstruction fixture.
	var light_wire := int(ability_catalog.ability(ability_catalog.spell_id_at("light", "rapid")).wire_id)
	var fire_wire := int(ability_catalog.ability(ability_catalog.spell_id_at("fire", "rapid")).wire_id)
	var water_wire := int(ability_catalog.ability(ability_catalog.spell_id_at("water", "rapid")).wire_id)
	var actor := world.player()
	if not actor.place_proven_spell(0, light_wire) or not actor.place_proven_spell(1, fire_wire) or not actor.place_proven_spell(2, water_wire):
		return _fail("real three-spell loadout failed")
	var target := PlayerState.new(2)
	if not champion_catalog.apply_to_player(target, "oh_tipi"):
		return _fail("target needs a real snapshot-valid champion profile")
	target.team_id = 2
	target.position_x = fixture_anchor.x
	target.position_y = fixture_anchor.y - 220_000
	target.spawn_protection_ticks = 0
	target.health_recovery_per_second = 0
	world.players.append(target)
	if blocked:
		world.collision.add_obstacle(CollisionWorld.Obstacle.new(990, radiance_origin.x + 24_000, radiance_origin.y - 24_000, radiance_origin.x + 32_000, radiance_origin.y + 32_000, false))
	return true


func build_counter() -> bool:
	if not cast_at(1, radiance_origin) or not wait_for_matter(7):
		return false
	if not cast_at(1, radiance_origin) or not wait_for_reaction(334):
		return false
	# Separate the lifetimes enough to observe Radiance's reveal cease while
	# Steam still conceals. This is ordinary elapsed world time, not a refill.
	if not advance_to(reaction(334).active_tick + 70):
		return _fail("Radiance setup wait failed")
	if not cast_at(2, steam_origin) or not wait_for_matter(2):
		return false
	if not cast_at(3, steam_origin) or not wait_for_reaction(310):
		return false
	if not advance_to(reaction(310).active_tick + 40):
		return _fail("Steam expansion wait failed")
	return reaction(334) != null and reaction(334).active(world.tick)


func cast_at(slot: int, endpoint: Vector2i) -> bool:
	var actor := world.player()
	var wire := actor.spell_wire_id(slot)
	for unused: int in range(240):
		if actor.pending_cast_wire_id == 0 and actor.spell_cooldown_for_wire(wire) == 0:
			break
		if not world.step([]):
			return _fail("cast cooldown wait failed")
	var direction := SimCommand._normalized_direction(endpoint.x - actor.position_x, endpoint.y - actor.position_y)
	var before := actor.flux
	var tick := world.tick
	var cost := int(CombatTuning.cast_definition(wire).flux_cost)
	var command := SimCommand.new(tick, actor.entity_id, 0, 0, 0, SimCommand.SPELL_PRESSED_BITS[slot - 1], direction.x, direction.y, endpoint.x, endpoint.y)
	if not world.step([command]) or cost <= 0 or actor.flux != before - cost or actor.pending_cast_wire_id != wire:
		return _fail("paid cast refused at tick%d wire%d: %s" % [tick, wire, str(world.combat_events)])
	cast_receipts.append({"wire_id": wire, "tick": tick, "spent": cost, "endpoint": endpoint})
	return true


func wait_for_matter(element: int) -> bool:
	for unused: int in range(180):
		for deposit: ElementDepositState in world.deposits:
			if deposit.owner_id == 1 and deposit.element_wire_id == element and not deposit.is_trail():
				return true
		if not world.step([]):
			return _fail("matter wait could not step")
	return _fail("terminal matter absent for element%d" % element)


func wait_for_reaction(wire: int) -> bool:
	for unused: int in range(180):
		if reaction(wire) != null:
			return true
		if not world.step([]):
			return _fail("reaction wait could not step")
	return _fail("reaction absent for recipe%d" % wire)


func reaction(wire: int) -> ElementReactionState:
	for result: ElementReactionState in world.reactions:
		if result.recipe_wire_id == wire:
			return result
	return null


func place_target(point: Vector2i) -> bool:
	if not world.collision.can_occupy(point, MovementTuning.PLAYER_RADIUS):
		return _fail("fixture target placement intersects worldbone")
	var target := world.player(2)
	target.position_x = point.x
	target.position_y = point.y
	target.velocity_x = 0
	target.velocity_y = 0
	return world.step([])


func target_visible() -> bool:
	return _chemistry_actor_visible(world.player(2))


func _fail(message: String) -> bool:
	failure = message
	return false
