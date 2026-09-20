extends FluxTestSuite
@warning_ignore_start("integer_division")


const ELEMENTS: Array[int] = [2, 3, 1, 4, 6, 5, 7, 8]
const FAR_POINT := Vector2i(6_000_000, 1_000_000)
const ORIGIN := Vector2i(1_000_000, 1_000_000)


func run() -> int:
	_test_real_catalog_and_paid_lanes()
	_test_archived_field_records_are_gated()
	_test_retired_delivery_admission_fails_closed()
	_test_heavy_direct_hit_and_single_terminal()
	_test_heavy_protection_and_split_damage()
	_test_heavy_solid_and_temporary_cover()
	_test_heavy_range_wall_and_lifetime()
	_test_private_terminal_event_once()
	_test_rapid_repeat_payment_and_release()
	_test_held_priority_and_silent_refusals()
	_test_router_plain_ctrl_alt_rapid()
	_test_delivery_replay_in_eight_directions()
	return finish("spell-delivery-expansion")


func _world(seed: int = 8209) -> SimWorld:
	var world := SimWorld.new(120, seed, CollisionWorld.new(8_000_000, 8_000_000))
	_configure(world.player())
	return world


func _configure(actor: PlayerState) -> void:
	actor.champion_wire_id = 1
	actor.position_x = ORIGIN.x
	actor.position_y = ORIGIN.y
	actor.team_id = 1
	actor.health_recovery_per_second = 0
	actor.flux_maximum = 160_000
	actor.flux = 160_000
	actor.flux_recovery_per_second = 0


func _victim(entity_id: int, position: Vector2i) -> PlayerState:
	var actor := PlayerState.new(entity_id)
	_configure(actor)
	actor.team_id = 2
	actor.position_x = position.x
	actor.position_y = position.y
	return actor


func _command(world: SimWorld, held: int = 0, pressed: int = 0, target: Vector2i = FAR_POINT, direction: Vector2i = Vector2i.ZERO) -> SimCommand:
	return SimCommand.new(world.tick, 1, direction.x, direction.y, held, pressed, 1000, 0, target.x, target.y)


func _step(world: SimWorld, command: SimCommand = null) -> void:
	var commands: Array[SimCommand] = []
	if command != null:
		commands.append(command)
	check(world.step(commands), "real delivery tick succeeds: %s" % world.last_error)
	check(world.last_error.is_empty(), "a paid cast keeps its terminal matter reservation")


func _events(world: SimWorld, kind: String, wire: int = 0) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for event: Dictionary in world.combat_events:
		if String(event.get("type", "")) == kind and (wire == 0 or int(event.get("wire_id", event.get("source_wire_id", 0))) == wire):
			found.append(event)
	return found


func _terminal_deposits(world: SimWorld, seen_trail_ids: Dictionary) -> Array[ElementDepositState]:
	var found: Array[ElementDepositState] = []
	for deposit: ElementDepositState in world.deposits:
		if deposit.is_trail():
			# Keep IDs even after expiry or promotion: both material roles share
			# the allocator, but only a terminal proves the Heavy has impacted.
			seen_trail_ids[deposit.entity_id] = true
		else:
			found.append(deposit)
	return found


func _start(world: SimWorld, wire: int, target: Vector2i = FAR_POINT) -> void:
	check(world.player().place_proven_spell(0, wire), "real delivery wire %d can be woven" % wire)
	var before := world.player().flux
	_step(world, _command(world, 0, SimCommand.PRESSED_SPELL_1, target))
	equal(world.player().pending_cast_wire_id, wire, "wire %d owns paid startup" % wire)
	equal(world.player().flux, before - int(CombatTuning.cast_definition(wire)["flux_cost"]), "wire %d pays exactly its authored Flux cost" % wire)
	equal(_events(world, "cast_started", wire).size(), 1, "one explicit press accepts exactly one cast")


func _release(world: SimWorld, wire: int) -> Array[Dictionary]:
	for _tick: int in range(90):
		# Later aim changes may not redirect an accepted cursor endpoint.
		_step(world, _command(world, 0, 0, Vector2i(1_000_000, 6_000_000)))
		var spawned := _events(world, "projectile_spawned", wire)
		if not spawned.is_empty():
			return spawned
	check(false, "wire %d releases within its bounded startup" % wire)
	return []


func _test_real_catalog_and_paid_lanes() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "expanded real catalog validates")
	for index: int in range(ELEMENTS.size()):
		for family: String in ["heavy", "rapid"]:
			var wire: int = 179 + index * 2 + int(family == "rapid")
			var definition := CombatTuning.cast_definition(wire)
			equal(int(definition.get("element_wire_id", 0)), ELEMENTS[index], "%s wire %d preserves element identity" % [family, wire])
			if family == "heavy":
				for key: String in ["speed", "radius", "damage", "blast_radius", "blast_damage", "flux_cost", "startup_ms", "cooldown_ms"]:
					var expected: Dictionary = {"speed": 320_000, "radius": 19_200, "damage": 18_000, "blast_radius": 84_000, "blast_damage": 18_000, "flux_cost": 18_000, "startup_ms": 200, "cooldown_ms": 1000}
					equal(int(definition.get(key, 0)), int(expected[key]), "Heavy %d has the shared %s contract" % [wire, key])
			elif family == "rapid":
				for key: String in ["speed", "radius", "damage", "flux_cost", "startup_ms", "cooldown_ms"]:
					var expected: Dictionary = {"speed": 608_000, "radius": 6000, "damage": 3000, "flux_cost": 2000, "startup_ms": 25, "cooldown_ms": 100}
					equal(int(definition.get(key, 0)), int(expected[key]), "Rapid %d has the shared %s contract" % [wire, key])
				equal(bool(definition.get("repeat_while_held", false)), true, "every element's Rapid explicitly opts into held-number repeat")
			var world := _world()
			_start(world, wire)
			var spawned := _release(world, wire)
			equal(spawned.size(), 1, "wire %d releases its one authored lane in one authoritative tick" % wire)
			equal(world.projectiles.size(), 1, "wire %d does not silently add projectiles" % wire)
			var strength := 0
			var first_cast := 0
			var remaining := -1
			for lane: ProjectileState in world.projectiles:
				if first_cast == 0:
					first_cast = lane.source_cast_id
					remaining = lane.remaining_distance
				equal(lane.source_cast_id, first_cast, "all lanes share one paid cast identity")
				equal(lane.element_wire_id, ELEMENTS[index], "live projectile carries its real element")
				equal(lane.radius, int(definition["radius"]), "live collision radius matches the authored readable silhouette")
				check(lane.velocity_x > 0, "later mouse movement cannot redirect the locked eastward release")
				check(lane.remaining_distance > 0 and absi(lane.remaining_distance - remaining) <= 10, "lanes share one finite locked range")
				strength += lane.material_strength
			equal(strength, 1000, "one cast partitions exactly one material contribution")


func _test_archived_field_records_are_gated() -> void:
	# Archived-data coverage preserves identity and authored geometry without
	# equipping a Field or constructing a live cast definition.
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "catalog loads for archived Field data")
	var field_ids: Array[String] = ["rimewake", "hearthring", "springwell", "stonehold", "updraft", "static-snare", "halo-ground", "umbral-pool"]
	for ability_id: String in field_ids:
		var ability: Dictionary = catalog.ability(ability_id)
		var wire := int(ability.get("wire_id", 0))
		var baseline_radius := 72_000 if wire == 144 else 85_000
		equal(String(ability.get("runtime_status", "")), "catalog_only", ability_id + " remains explicitly archived")
		equal(int(ability.get("radius", 0)) * 5, baseline_radius * 6, ability_id + " preserves its authored enlarged radius")
		check(not CombatTuning.is_runtime_wire_id(wire), ability_id + " is excluded from runtime admission")
		check(CombatTuning.cast_definition(wire).is_empty(), ability_id + " has no compiled live cast definition")


func _test_retired_delivery_admission_fails_closed() -> void:
	var state := PlayerState.new()
	for wire: int in [146, 155, 156]:
		var before_slots := PackedInt32Array(state.spell_wire_ids)
		var before_cooldowns := PackedInt32Array(state.spell_cooldown_ticks)
		var before_flux := state.flux
		check(not state.place_proven_spell(0, wire), "retired Wave, Beam, or Field wire is rejected: %d" % wire)
		equal(state.spell_wire_ids, before_slots, "retired delivery rejection preserves weave positions")
		equal(state.spell_cooldown_ticks, before_cooldowns, "retired delivery rejection preserves cooldowns")
		equal(state.flux, before_flux, "retired delivery rejection spends no Flux")


func _test_heavy_direct_hit_and_single_terminal() -> void:
	for index: int in range(ELEMENTS.size()):
		var wire := 179 + index * 2
		var world := _world()
		var direct := _victim(2, ORIGIN + Vector2i(200_000, 0))
		var splash := _victim(3, ORIGIN + Vector2i(175_000, 55_000))
		world.players.append_array([direct, splash])
		var direct_before := direct.health
		var splash_before := splash.health
		_start(world, wire)
		var hit_count := {2: 0, 3: 0}
		var terminals := 0
		var initial_deposit_id := world.next_deposit_id
		var seen_trail_ids := {}
		var terminal_deposits: Array[ElementDepositState] = []
		for _tick: int in range(150):
			_step(world)
			for event: Dictionary in _events(world, "projectile_hit", wire):
				var target_id := int(event["target_id"])
				hit_count[target_id] = int(hit_count.get(target_id, 0)) + 1
			# SimWorld consumes the private event before exposing combat_events.
			# Discount every observed flight allocation without treating a trail
			# as impact evidence; retain the exact one-terminal allocation check.
			terminal_deposits = _terminal_deposits(world, seen_trail_ids)
			terminals = world.next_deposit_id - initial_deposit_id - seen_trail_ids.size()
			if not terminal_deposits.is_empty():
				break
		equal(direct.health, direct_before - 18_000, "Heavy %d direct victim is not double-damaged by its own blast" % wire)
		equal(splash.health, splash_before - 18_000, "Heavy %d applies one nearby area hit" % wire)
		equal(hit_count, {2: 1, 3: 1}, "direct and area victims each receive exactly one hit event")
		equal(terminals, 1, "Heavy emits exactly one normal terminal event")
		equal(terminal_deposits.size(), 1, "one Heavy terminal becomes one existing elemental deposit, separately from flight trails")
		equal(world.projectiles.size(), 0, "Heavy direct impact retires the projectile rather than stopping the fixture on a trail")
		if terminal_deposits.size() == 1:
			equal(terminal_deposits[0].element_wire_id, ELEMENTS[index], "Heavy terminal preserves its authored element")
		for _tick: int in range(3):
			_step(world)
			equal(_events(world, "projectile_hit", wire).size(), 0, "spent Heavy cannot reapply its blast on later ticks")


func _shell(wire: int = 179, damage: int = 18_000) -> ProjectileState:
	return ProjectileState.new(1000, 1, 1, wire, int(CombatTuning.cast_definition(wire)["element_wire_id"]), ORIGIN, Vector2i(400_000, 0), 16_000, damage, 200)


func _test_heavy_protection_and_split_damage() -> void:
	var config := SimConfig.new(120)
	var collision := CollisionWorld.new(8_000_000, 8_000_000)
	for index: int in range(ELEMENTS.size()):
		for protection: String in ["none", "height_only", "ally", "owner", "dead", "spawn", "float", "hop", "air_dodge", "excluded", "outside"]:
			var victim := _victim(2, ORIGIN + Vector2i(50_000, 0))
			match protection:
				"height_only":
					victim.air_height = 25_000
					victim.hop_ticks = 10
				"ally": victim.team_id = 1
				"owner": victim.entity_id = 1
				"dead": victim.health = 0
				"spawn": victim.spawn_protection_ticks = 5
				"float":
					victim.air_height = 25_000
					victim.air_floating = true
					victim.float_ticks = 10
				"hop":
					victim.hop_ticks = 10
					victim.jump_protection_ticks = 5
				"air_dodge": victim.air_dodge_ticks = config.milliseconds_to_ticks(MovementTuning.AIR_DODGE_DURATION_MS)
				"outside": victim.position_x = ORIGIN.x + 200_000
			var before := victim.health
			var events: Array[Dictionary] = []
			var players: Array[PlayerState] = [victim]
			CombatSystem._explode_projectile(_shell(179 + index * 2), players, config, collision, [], 50, events, 2 if protection == "excluded" else 0)
			var damages := protection in ["none", "height_only"]
			equal(victim.health, before - 18_000 if damages else before, "Heavy %d respects %s without making ordinary height invulnerable" % [179 + index * 2, protection])
			equal(events.filter(func(event: Dictionary) -> bool: return event.get("type") == "projectile_hit").size(), 1 if damages else 0, "ineligible area victims emit no misleading hit event")
		var split_target := _victim(2, ORIGIN + Vector2i(50_000, 0))
		var before := split_target.health
		var split_events: Array[Dictionary] = []
		CombatSystem._explode_projectile(_shell(179 + index * 2, 9000), [split_target], config, collision, [], 50, split_events)
		equal(split_target.health, before - 9000, "an optical half-damage shell cannot recreate a full-strength blast")
	var defeated := _victim(2, ORIGIN + Vector2i(50_000, 0))
	defeated.health = 10_000
	var events: Array[Dictionary] = []
	CombatSystem._explode_projectile(_shell(), [defeated], config, collision, [], 50, events)
	equal(defeated.health, 0, "area damage defeats a low-health champion")
	equal(events.filter(func(event: Dictionary) -> bool: return event.get("type") == "champion_defeated").size(), 1, "one lethal area hit emits exactly one defeat")


func _cover() -> ElementReactionState:
	var cover := ElementReactionState.new()
	cover.entity_id = 4000
	cover.recipe_wire_id = 301
	cover.owner_id = 3
	cover.team_id = 3
	cover.position_x = ORIGIN.x + 25_000
	cover.position_y = ORIGIN.y
	cover.origin_x = cover.position_x
	cover.origin_y = cover.position_y
	# Cover direction is its normal; the physical long axis is perpendicular.
	cover.direction_x = 1000
	cover.direction_y = 0
	cover.created_tick = 0
	cover.active_tick = 20
	cover.decay_tick = 100
	cover.expiry_tick = 140
	var definition := ElementChemistrySystem.recipe(301)
	cover.radius = int(definition.radius)
	cover.length = int(definition.length)
	cover.health = 32_000
	cover.source_a = 2000
	cover.source_b = 2001
	cover.endpoint_x = cover.position_x + cover.length
	cover.endpoint_y = cover.position_y
	check(cover.validate(), "temporary cover fixture is a valid authoritative Fortify")
	return cover


func _test_heavy_solid_and_temporary_cover() -> void:
	var config := SimConfig.new(120)
	for obstruction: String in ["worldbone", "active_cover", "forming_cover", "decaying_cover", "broken_cover"]:
		var collision := CollisionWorld.new(8_000_000, 8_000_000)
		var target := _victim(2, ORIGIN + Vector2i(60_000, 0))
		var cover := _cover()
		var reactions: Array[ElementReactionState] = []
		var tick := 50
		if obstruction == "worldbone":
			collision.add_obstacle(CollisionWorld.Obstacle.new(7, ORIGIN.x + 20_000, ORIGIN.y - 100_000, ORIGIN.x + 30_000, ORIGIN.y + 100_000))
		else:
			reactions.append(cover)
			if obstruction == "forming_cover": tick = cover.active_tick - 1
			if obstruction == "decaying_cover": tick = cover.decay_tick
			if obstruction == "broken_cover": cover.health = 0
		var before := target.health
		var cover_before := cover.canonical_values()
		var events: Array[Dictionary] = []
		CombatSystem._explode_projectile(_shell(), [target], config, collision, reactions, tick, events)
		var blocked := obstruction in ["worldbone", "active_cover"]
		equal(target.health, before if blocked else before - 18_000, "blast line of sight respects exact %s lifecycle" % obstruction)
		equal(cover.canonical_values(), cover_before, "blast visibility checks never mutate cover per candidate victim")
	# The impact integration must originate outside surviving cover; otherwise
	# starting a visibility ray inside the cover hides even its exposed side.
	var collision := CollisionWorld.new(8_000_000, 8_000_000)
	var cover := _cover()
	check(not ElementChemistrySystem.contains(cover, ORIGIN, 50, config), "construct impact fixture launches outside the temporary cover")
	check(ElementChemistrySystem.contains(cover, ORIGIN + Vector2i(10_000, 0), 50, config), "construct impact fixture crosses the cover's exposed boundary")
	var front := _victim(2, ORIGIN + Vector2i(-30_000, 40_000))
	var back := _victim(3, ORIGIN + Vector2i(60_000, 0))
	var before_front := front.health
	var before_back := back.health
	var active: Array[ProjectileState] = [_shell()]
	var events: Array[Dictionary] = []
	for _tick: int in range(10):
		active = CombatSystem.advance_projectiles(active, [front, back], config, collision, events, [cover], 50)
		if active.is_empty(): break
	check(active.is_empty() and cover.health > 0, "Heavy really impacts, but does not destroy, the temporary Fortify")
	equal(cover.health, 14_000, "one Heavy impact spends its 18 damage on temporary cover once")
	equal(front.health, before_front - 18_000, "Heavy construct impact splashes the exposed side of surviving cover")
	equal(back.health, before_back, "surviving temporary cover still blocks the same impact blast on its sheltered side")
	equal(events.filter(func(event: Dictionary) -> bool: return event.get("type") == "projectile_terminal").size(), 1, "construct contact emits exactly one ordinary terminal matter event")
	# Compare actual explosion origins on both sides of the source-derived
	# face, not offsets that become interior after a footprint balance change.
	var face_x := ElementChemistrySystem.rampart_bounds(cover).position.x - ORIGIN.x
	for penetrated: bool in [true, false]:
		var offset_x := face_x + (1000 if penetrated else -1000)
		equal(ElementChemistrySystem.contains(cover, ORIGIN + Vector2i(offset_x, 0), 50, config), penetrated, "negative-control origin is actually inside or outside the live cover face")
		var sample_target := _victim(4, ORIGIN + Vector2i(-30_000, 40_000))
		var sample_before := sample_target.health
		var sample_shell := _shell()
		sample_shell.position_x += offset_x
		var sample_events: Array[Dictionary] = []
		CombatSystem._explode_projectile(sample_shell, [sample_target], config, collision, [cover], 50, sample_events)
		equal(sample_target.health, sample_before if penetrated else sample_before - 18_000, "inside versus exposed sample proves why Heavy contact-origin correction is necessary")


func _test_heavy_range_wall_and_lifetime() -> void:
	for terminal: String in ["range", "wall", "lifetime"]:
		var world := _world()
		var target := ORIGIN + Vector2i(240_000, 0)
		var splash_offset := Vector2i(240_000, 55_000)
		if terminal == "wall":
			world.collision.add_obstacle(CollisionWorld.Obstacle.new(9, ORIGIN.x + 150_000, ORIGIN.y - 100_000, ORIGIN.x + 170_000, ORIGIN.y + 100_000))
			splash_offset = Vector2i(135_000, 55_000)
		if terminal == "lifetime":
			splash_offset = Vector2i(3000, 55_000)
			var projectile := _shell()
			projectile.lifetime_ticks = 1
			projectile.source_cast_id = 1000
			world.projectiles.append(projectile)
		else:
			_start(world, 179, target)
		var splash := _victim(2, ORIGIN + splash_offset)
		var before := splash.health
		world.players.append(splash)
		var terminals := 0
		var initial_deposit_id := world.next_deposit_id
		var seen_trail_ids := {}
		var terminal_deposits: Array[ElementDepositState] = []
		for _tick: int in range(160):
			_step(world, _command(world, 0, 0, ORIGIN + Vector2i(0, 500_000)))
			terminal_deposits = _terminal_deposits(world, seen_trail_ids)
			terminals = world.next_deposit_id - initial_deposit_id - seen_trail_ids.size()
			if not terminal_deposits.is_empty(): break
		equal(terminals, 1, "Heavy %s termination emits one existing matter event" % terminal)
		equal(world.projectiles.size(), 0, "Heavy %s removes the spent projectile" % terminal)
		equal(terminal_deposits.size(), 1, "Heavy %s does not duplicate its terminal residue, separately from flight trails" % terminal)
		equal(splash.health, before - 18_000, "Heavy %s actually blasts a nearby non-contact target" % terminal)
		if terminal_deposits.size() != 1: continue
		var point := Vector2i(terminal_deposits[0].position_x, terminal_deposits[0].position_y)
		if terminal == "range":
			check(absi(point.x - target.x) <= 3 and absi(point.y - target.y) <= 3, "Heavy explodes at its accepted cursor endpoint, not the later cursor")
		elif terminal == "wall":
			check(point.x <= ORIGIN.x + 150_000 and point.y == ORIGIN.y, "wall impact never deposits the shell through solid worldbone")


func _test_rapid_repeat_payment_and_release() -> void:
	for index: int in range(ELEMENTS.size()):
		var wire := 180 + index * 2
		var world := _world()
		check(world.player().place_proven_spell(0, wire), "Rapid repeat fixture equips the real elemental spell")
		var before := world.player().flux
		var starts := 0
		var releases: Array[int] = []
		var release_count := 0
		var cast_ids := {}
		for _tick: int in range(100):
			_step(world, _command(world, SimCommand.SPELL_HELD_BITS[0]))
			starts += _events(world, "cast_started", wire).size()
			if not _events(world, "projectile_spawned", wire).is_empty(): releases.append(world.tick)
			release_count += _record_rapid_releases(world, wire, cast_ids)
			equal(_events(world, "cast_refused").size(), 0, "held Rapid cooldown/startup is silent, not an error event every tick")
		check(starts >= 6 and releases.size() >= 6, "holding Rapid %d repeatedly accepts and releases paid shots" % wire)
		equal(before - world.player().flux, starts * 2000, "Rapid pays exactly once per accepted shot, never once per held tick")
		for release_index: int in range(1, releases.size()):
			check(releases[release_index] - releases[release_index - 1] >= world.config.milliseconds_to_ticks(100), "Rapid cannot bypass its authored cooldown")
		var after_release := world.player().flux
		for _tick: int in range(50):
			_step(world, _command(world))
			release_count += _record_rapid_releases(world, wire, cast_ids)
			equal(_events(world, "cast_started", wire).size(), 0, "releasing the number key ends auto-repeat immediately")
			# An already accepted startup may finish; no future startup is invented.
			if _tick > world.config.milliseconds_to_ticks(25):
				equal(_events(world, "projectile_spawned", wire).size(), 0, "only an already-paid startup may release after key-up")
		equal(world.player().flux, after_release, "key-up never pays for a phantom follow-up shot")
		equal(release_count, starts, "every paid Rapid startup releases exactly one projectile after the final startup drains")
		equal(cast_ids.size(), starts, "Rapid assigns exactly one distinct cast identity to each paid shot")


func _record_rapid_releases(world: SimWorld, wire: int, cast_ids: Dictionary) -> int:
	var spawned := _events(world, "projectile_spawned", wire)
	if not spawned.is_empty(): equal(spawned.size(), 1, "Rapid releases only one projectile per cast")
	for event: Dictionary in spawned:
		var found := false
		for projectile: ProjectileState in world.projectiles:
			if projectile.entity_id != int(event["projectile_id"]): continue
			found = true
			check(projectile.source_cast_id > 0 and not cast_ids.has(projectile.source_cast_id), "Rapid release owns a new, positive paid cast identity")
			cast_ids[projectile.source_cast_id] = true
		check(found, "Rapid far-range release event corresponds to a real admitted projectile")
	return spawned.size()


func _test_private_terminal_event_once() -> void:
	# The world consumes these private events. Verify the actual producer as
	# well as the paid-world deposit allocation checks above.
	var config := SimConfig.new(120)
	for terminal: String in ["actor", "obstacle", "range", "lifetime"]:
		var collision := CollisionWorld.new(8_000_000, 8_000_000)
		var projectile := _shell()
		var players: Array[PlayerState] = []
		if terminal == "actor": players.append(_victim(2, ORIGIN + Vector2i(25_000, 0)))
		if terminal == "obstacle": collision.add_obstacle(CollisionWorld.Obstacle.new(1, ORIGIN.x + 18_000, ORIGIN.y - 100_000, ORIGIN.x + 30_000, ORIGIN.y + 100_000))
		if terminal == "range": projectile.remaining_distance = 1000
		if terminal == "lifetime": projectile.lifetime_ticks = 1
		var events: Array[Dictionary] = []
		var survivors := CombatSystem.advance_projectiles([projectile], players, config, collision, events)
		var terminals: Array[Dictionary] = []
		for event: Dictionary in events:
			if event.get("type") == "projectile_terminal": terminals.append(event)
		equal(survivors.size(), 0, "private %s path retires the Heavy exactly once" % terminal)
		equal(terminals.size(), 1, "private %s path emits exactly one matter event before world consumption" % terminal)
		if terminals.size() == 1:
			equal(String(terminals[0]["reason"]), "range" if terminal == "lifetime" else terminal, "private terminal cause remains the existing pipeline contract")
		events.clear()
		CombatSystem.advance_projectiles(survivors, players, config, collision, events)
		equal(events.size(), 0, "retired Heavy never emits a second terminal on the next step")


func _test_held_priority_and_silent_refusals() -> void:
	for wire: int in [145, 179, 154]:
		var world := _world()
		check(world.player().place_proven_spell(0, wire), "non-Rapid held fixture equips a real spell")
		var before := world.player().flux
		for _tick: int in range(30): _step(world, _command(world, SimCommand.SPELL_HELD_BITS[0]))
		equal(world.player().flux, before, "holding a non-Rapid number without an edge never auto-starts wire %d" % wire)
		_start(world, wire)
		var starts := 0
		for _tick: int in range(180):
			_step(world, _command(world, SimCommand.SPELL_HELD_BITS[0]))
			starts += _events(world, "cast_started", wire).size()
		equal(starts, 0, "holding a non-Rapid number after its explicit cast cannot repeat wire %d" % wire)
	var priority := _world()
	check(priority.player().place_proven_spell(0, 180) and priority.player().place_proven_spell(1, 179), "priority fixture equips Rapid and Heavy")
	_step(priority, _command(priority, SimCommand.SPELL_HELD_BITS[0] | SimCommand.HELD_PRIMARY, SimCommand.PRESSED_SPELL_2))
	equal(priority.player().pending_cast_wire_id, 179, "fresh explicit Heavy press wins over held Rapid and held primary")
	equal(priority.player().flux, 142_000, "priority resolves one payment, not multiple concurrent casts")
	for refusal: String in ["flux", "capacity"]:
		var world := _world()
		check(world.player().place_proven_spell(0, 180), "silent refusal fixture equips Rapid")
		if refusal == "flux": world.player().flux = 4000
		else:
			for index: int in range(16):
				var projectile := ProjectileState.new(1000 + index, 1, 1, 180, 2, Vector2i(2_000_000 + 100_000 * index, 2_000_000), Vector2i.ZERO, 5000, 3000, 1000)
				projectile.source_cast_id = 1000 + index
				world.projectiles.append(projectile)
		var before := world.player().flux
		var starts := 0
		for _tick: int in range(70):
			_step(world, _command(world, SimCommand.SPELL_HELD_BITS[0]))
			starts += _events(world, "cast_started", 180).size()
			equal(_events(world, "cast_refused").size(), 0, "unaffordable/full-capacity held Rapid stays silent")
		equal(starts, 2 if refusal == "flux" else 0, "held Rapid cannot exceed available %s" % refusal)
		equal(world.player().flux, 0 if refusal == "flux" else before, "refused repeat spends no resource")
		_step(world, _command(world, 0, SimCommand.PRESSED_SPELL_1))
		var refused := _events(world, "cast_refused")
		equal(refused.size(), 1, "fresh explicit press still reports one actionable refusal")
		if refused.size() == 1: equal(String(refused[0].get("reason", "")), refusal, "explicit refusal identifies the real blocked resource")
	var primary := _world()
	var starts := 0
	for _tick: int in range(100):
		_step(primary, _command(primary, SimCommand.HELD_PRIMARY))
		starts += _events(primary, "cast_started").size()
	check(starts > 1, "existing held-left-mouse primary behavior remains available")


func _test_delivery_replay_in_eight_directions() -> void:
	var directions: Array[Vector2i] = [Vector2i(1000, 0), Vector2i(707, 707), Vector2i(0, 1000), Vector2i(-707, 707), Vector2i(-1000, 0), Vector2i(-707, -707), Vector2i(0, -1000), Vector2i(707, -707)]
	var left := _world(9191)
	var right := _world(9191)
	for world: SimWorld in [left, right]:
		check(world.player().place_proven_spell(0, 180) and world.player().place_proven_spell(1, 179) and world.player().place_proven_spell(2, 154), "replay equips retained Rapid, Heavy, and Spray")
	var observed := {}
	for tick: int in range(480):
		var direction: Vector2i = directions[tick / 60]
		var held: int = SimCommand.SPELL_HELD_BITS[0] if tick % 120 >= 65 and tick % 120 < 105 else 0
		var pressed: int = SimCommand.PRESSED_SPELL_2 if tick % 240 == 0 else (SimCommand.PRESSED_SPELL_3 if tick % 240 == 120 else 0)
		for world: SimWorld in [left, right]:
			_step(world, _command(world, held, pressed, Vector2i(2_000_000, 1_000_000), direction))
		for event: Dictionary in _events(left, "projectile_spawned"):
			observed[int(event["wire_id"])] = true
		for event: Dictionary in _events(left, "spray_fired"):
			observed[int(event["source_wire_id"])] = true
		equal(left.state_hash(), right.state_hash(), "mixed-delivery movement replay is canonical at tick %d" % tick)
		equal(left.combat_events, right.combat_events, "mixed-delivery event order is deterministic at tick %d" % tick)
	equal(observed.size(), 3, "deterministic replay actually releases Heavy, Rapid, and Spray")


func _test_router_plain_ctrl_alt_rapid() -> void:
	InputRouter.ensure_input_map()
	var previous := {}
	for action: StringName in InputMap.get_actions():
		previous[action] = Input.get_action_strength(action)
		Input.action_release(action)
	for slot_index: int in [0, 4, 8]:
		var router := InputRouter.new(1)
		var world := _world()
		check(world.player().place_proven_spell(slot_index, 180), "real router fixture equips Rapid at the plain/Ctrl/Alt number-one slot")
		if slot_index == 4: Input.action_press(InputRouter.SPELL_CTRL_LAYER_ACTION)
		if slot_index == 8: Input.action_press(InputRouter.SPELL_ALT_LAYER_ACTION)
		Input.action_press(InputRouter.SPELL_ACTIONS[0])
		var starts := 0
		for tick: int in range(60):
			var command := router.sample(world.tick, Vector2(ORIGIN) / 1000.0, Vector2(FAR_POINT) / 1000.0)
			equal(command.first_held_spell_slot(), slot_index + 1, "real InputRouter sustains the selected plain/Ctrl/Alt Rapid slot")
			equal(command.first_pressed_spell_slot(), slot_index + 1 if tick == 0 else 0, "real router emits one edge and subsequent held-only Rapid commands")
			_step(world, command)
			starts += _events(world, "cast_started", 180).size()
		check(starts >= 3, "real router plain/Ctrl/Alt hold reaches repeated paid Rapid casts")
		equal(160_000 - world.player().flux, starts * 2000, "real router repeat uses ordinary authoritative per-shot payment")
		Input.action_release(InputRouter.SPELL_ACTIONS[0])
		Input.action_release(InputRouter.SPELL_CTRL_LAYER_ACTION)
		Input.action_release(InputRouter.SPELL_ALT_LAYER_ACTION)
		for _tick: int in range(35):
			var command := router.sample(world.tick, Vector2(ORIGIN) / 1000.0, Vector2(FAR_POINT) / 1000.0)
			equal(command.first_held_spell_slot(), 0, "real router key-up clears every spell-held slot")
			_step(world, command)
			equal(_events(world, "cast_started", 180).size(), 0, "real router key-up cannot create another paid cast")
	for action: StringName in previous:
		Input.action_release(action)
		if float(previous[action]) > 0.0: Input.action_press(action, float(previous[action]))
