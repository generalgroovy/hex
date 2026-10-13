extends FluxTestSuite
## A successful paid Hex step must remain a complete replicable state, including
## the boundary at which an unfired cast loses its living owner.

const HexSnapshot = preload("res://src/net/hex_world_snapshot.gd")
const ORIGIN := Vector2i(600_000, 500_000)
var abilities := AbilityCatalog.new()
var champions := ChampionCatalog.new()


func run() -> int:
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "defeated capture loads real spells")
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "defeated capture loads real profiles")
	if not abilities.last_error.is_empty() or not champions.last_error.is_empty(): return finish("defeated-pending-capture")
	for kind: String in ["projectile", "burning", "ground", "survivor", "released_flight"]:
		_paid_route(kind)
	_legacy_boundary_unchanged()
	return finish("defeated-pending-capture")


func _world(kind: String, hex: bool = true) -> SimWorld:
	var world := SimWorld.new(120, 714, CollisionWorld.new(2_000_000, 2_000_000))
	if hex:
		var court := HexChemistryWorld.new()
		check(court.configure_geometry(ORIGIN, HexGrid.disk(Vector2i.ZERO, 8)), "death route owns real finite topology")
		court.chemistry_enabled = true
		world.hex_court = court
	var actor := world.player()
	check(champions.apply_to_player(actor, "oh_tipi"), "death route applies victim profile")
	actor.reset_for_spawn(ORIGIN)
	actor.health_recovery_per_second = 0
	actor.flux_recovery_per_second = 0
	var fire_quote := int(CombatTuning.cast_definition_view(MixtureCatalog.wire_for(2, "rapid")).damage)
	# The ground case survives the complete finite Burn pool with exactly one
	# Health, so the first real pressure pulse kills during the later Heavy.
	actor.health = fire_quote + 1 if kind == "burning" else fire_quote + mini(2400, maxi(1, fire_quote / 4)) + 1 if kind == "ground" else actor.health_maximum if kind == "survivor" else 1
	check(actor.place_proven_spell(0, MixtureCatalog.wire_for(16, "heavy")), "victim equips a real finite Heavy")
	if kind == "released_flight": check(actor.place_proven_spell(1, MixtureCatalog.wire_for(16, "rapid")), "victim also equips independent earlier Rapid")
	var attacker := PlayerState.new(2)
	check(champions.apply_to_player(attacker, "s_wayne"), "death route applies actual attacker profile")
	attacker.reset_for_spawn(ORIGIN + Vector2i(80_000, 0))
	attacker.team_id = 2
	attacker.health_recovery_per_second = 0
	attacker.flux_recovery_per_second = 0
	var mask := 2 if kind in ["burning", "ground", "survivor"] else 16
	check(attacker.place_proven_spell(0, MixtureCatalog.wire_for(mask, "rapid")), "attacker equips ordinary lethal-source spell")
	world.players.append(attacker)
	return world


func _commands(world: SimWorld, victim_bits: int, attacker_press: bool) -> Array[SimCommand]:
	return [SimCommand.new(world.tick, 1, 0, 0, 0, victim_bits, 0, -1000),
		SimCommand.new(world.tick, 2, 0, 0, 0, SimCommand.PRESSED_SPELL_1 if attacker_press else 0, -1000, 0)]


func _step_pair(world: SimWorld, replay: SimWorld, commands: Array[SimCommand], label: String) -> void:
	check(world.step(commands), label + " ordinary command step succeeds")
	check(replay.step(commands), label + " exact command replay succeeds")
	equal(world.state_hash(), replay.state_hash(), label + " canonical replay agrees")
	equal(world.combat_events, replay.combat_events, label + " event ownership/order replay agrees")
	check(world.hex_court.conservation_valid() and replay.hex_court.conservation_valid(), label + " paid matter conserves")
	var packet := HexSnapshot.capture(world)
	check(not packet.is_empty(), label + " every successful boundary has a strict complete packet")
	equal(var_to_bytes(packet), var_to_bytes(HexSnapshot.capture(replay)), label + " exact complete packet replay agrees")
	if not packet.is_empty():
		var decoded: SimWorld = HexSnapshot.prepare(packet, world)
		check(decoded != null and decoded.state_hash() == world.state_hash(), label + " accepted packet restores identical authority")


func _paid_route(kind: String) -> void:
	var world := _world(kind)
	var replay: SimWorld = HexSnapshot.prepare(HexSnapshot.capture(world), world)
	check(replay != null, kind + " starts from a strict detached initial packet")
	if replay == null: return
	var actor := world.player()
	var attacker := world.player(2)
	var heavy := actor.spell_wire_id(1)
	var initial_flux := actor.flux
	var attacker_flux := attacker.flux
	var admissions := 0
	var enemy_admissions := 0
	var direct_hit_tick := -1
	var pending_cast := 0
	var pending_tick := -1
	var death_tick := -1
	var death_kind := ""
	var prior_flight_source := 0
	var heavy_releases := 0
	var observed_alive_pending := false
	var ground_total := 0
	var burn_total := 0
	for step: int in 96:
		var press := 0
		if pending_tick < 0:
			if kind == "projectile" and step == 0: press = SimCommand.PRESSED_SPELL_1
			elif kind == "burning" and direct_hit_tick >= 0: press = SimCommand.PRESSED_SPELL_1
			elif kind in ["ground", "survivor"] and direct_hit_tick >= 0 and world.tick >= direct_hit_tick + 12: press = SimCommand.PRESSED_SPELL_1
			elif kind == "released_flight":
				if step == 0: press = SimCommand.SPELL_PRESSED_BITS[1]
				elif prior_flight_source > 0 and actor.pending_cast_wire_id == 0 and actor.cast_recovery_ticks == 0: press = SimCommand.PRESSED_SPELL_1
		var enemy_press := step == 0 if kind != "released_flight" else pending_tick >= 0 and enemy_admissions == 0
		var was_pending := actor.pending_cast_wire_id == heavy and actor.pending_cast_ticks > 0
		var expired_before := int(world.hex_court.metrics.matter_expired)
		var original_aim := Vector2i(actor.pending_cast_aim_x, actor.pending_cast_aim_y)
		_step_pair(world, replay, _commands(world, press, enemy_press), "%s tick%d" % [kind, world.tick])
		for event: Dictionary in world.combat_events:
			var type := String(event.get("type", ""))
			if type == "cast_started":
				if int(event.entity_id) == 2: enemy_admissions += 1
				elif int(event.wire_id) == heavy:
					admissions += 1
					pending_tick = world.tick
					pending_cast = int(world.hex_court.pending.get(1, 0))
			if type == "projectile_spawned" and int(event.owner_id) == 1:
				if int(event.wire_id) == heavy: heavy_releases += 1
				else: prior_flight_source = int(event.projectile_id)
			if type == "projectile_hit" and int(event.target_id) == 1:
				direct_hit_tick = world.tick
				if actor.health == 0: death_kind = "projectile"
			if type == "spell_status_hit" and int(event.target_id) == 1:
				burn_total += int(event.damage)
				if actor.health == 0: death_kind = "burning"
			if type == "hex_pressure" and int(event.entity_id) == 1:
				ground_total += int(event.amount)
				if actor.health == 0: death_kind = "ground"
		if actor.health == 0:
			death_tick = world.tick
			check(was_pending and pending_cast > 0, kind + " victim already owned a paid pending Heavy before lethal step")
			equal(actor.pending_cast_wire_id, 0, kind + " completed death clears only unfired reservation wire")
			equal(actor.pending_cast_ticks, 0, kind + " completed death clears unfired reservation clock")
			equal(Vector2i(actor.pending_cast_aim_x, actor.pending_cast_aim_y), original_aim, kind + " cleanup does not broaden into aim resets")
			check(not world.hex_court.pending.has(1) and not world.hex_court.casts.has(pending_cast), kind + " ordinary sync retires the same paid cast")
			equal(int(world.hex_court.metrics.matter_expired) - expired_before, 600, kind + " cancellation expires exactly existing unfired paid stock")
			if kind == "released_flight":
				check(prior_flight_source > 0 and world.hex_court.sources.has(prior_flight_source), "owner death does not retire already released source")
				var live := false
				for shot: ProjectileState in world.projectiles:
					live = live or (shot.owner_id == 1 and shot.source_cast_id == prior_flight_source)
				check(live, "independent paid flight survives its owner's pending cancellation")
			break
		if kind == "survivor" and ground_total > 0:
			observed_alive_pending = actor.pending_cast_wire_id == heavy and actor.pending_cast_ticks > 0 and world.hex_court.pending.has(1)
			check(observed_alive_pending, "nonlethal ground leaves the living actor's real pending cast intact")
			break
	check(pending_tick > 0 and admissions == 1 and enemy_admissions == 1, kind + " uses one ordinary Heavy and one ordinary attack admission")
	if kind == "survivor":
		check(death_tick < 0 and observed_alive_pending, "matched healthy actor survives raw ground with its reservation")
	else:
		check(death_tick > pending_tick, kind + " actual death occurs after the paid admission")
		equal(death_kind, "projectile" if kind == "released_flight" else kind, kind + " actual lethal event belongs to intended damage lane")
		equal(heavy_releases, 0, kind + " cancelled paid Heavy never releases")
	if kind == "burning":
		equal(ground_total, 0, "Burning lethality is isolated before real Fire ground ignition")
		check(burn_total > 0, "ordinary finite status pulse actually kills the pending caster")
	if kind in ["ground", "survivor"]: check(ground_total > 0 and burn_total > 0, "raw ground fixture separately accounts earlier real Burning")
	if kind == "ground": equal(ground_total, 1, "first actual ground pulse takes only the one Health left after direct Fire and finite Burn")
	var expected_cost := int(CombatTuning.cast_definition_view(heavy).flux_cost)
	if kind == "released_flight": expected_cost += int(CombatTuning.cast_definition_view(actor.spell_wire_id(2)).flux_cost)
	equal(initial_flux - actor.flux, expected_cost, kind + " cancellation never refunds any accepted Flux")
	equal(attacker_flux - attacker.flux, int(CombatTuning.cast_definition_view(attacker.spell_wire_id(1)).flux_cost), kind + " incoming damage also pays ordinary cost")
	equal(int(world.hex_court.metrics.matter_paid), 1800 if kind == "released_flight" else 1200, kind + " no cleanup creates new source material")
	if kind == "survivor": return
	var deadline := _expiry_deadline(world)
	check(deadline > world.tick and deadline - world.tick <= 1200, kind + " natural expiry bound derives from actual remaining paid material")
	for post: int in mini(1200, maxi(1, deadline - world.tick)):
		_step_pair(world, replay, _commands(world, SimCommand.PRESSED_SPELL_1 if post < 8 else 0, false), "%s expiry%d" % [kind, post])
		equal(actor.health, 0, kind + " ordinary later inputs cannot resurrect a defeated actor")
		equal(actor.pending_cast_wire_id, 0, kind + " later inputs cannot restart cancelled paid cast")
		equal(actor.flux, initial_flux - expected_cost, kind + " later cleanup never refunds Flux")
		for event: Dictionary in world.combat_events:
			check(not (String(event.get("type", "")) == "projectile_spawned" and int(event.get("owner_id", 0)) == 1 and int(event.get("wire_id", 0)) == heavy), kind + " no delayed Heavy resurrection")
		if world.hex_court.casts.is_empty() and world.hex_court.products.is_empty() and world.projectiles.is_empty(): break
	check(world.hex_court.casts.is_empty() and world.projectiles.is_empty(), kind + " remaining paid sources expire naturally within finite bound")
	equal(int(world.hex_court.metrics.matter_expired), int(world.hex_court.metrics.matter_paid), kind + " all nonreacting paid matter eventually expires exactly once")


func _expiry_deadline(world: SimWorld) -> int:
	var deadline := world.tick + 2
	for record: Dictionary in world.hex_court.casts.values():
		for part: Dictionary in record.ground_parts.values():
			deadline = maxi(deadline, int(part.expiry_tick) + 2)
	for product: Dictionary in world.hex_court.products.values():
		deadline = maxi(deadline, int(product.expiry_tick) + 2)
	for shot: ProjectileState in world.projectiles:
		# A surviving earlier flight may still deposit its own terminal stock.
		deadline = maxi(deadline, world.tick + shot.lifetime_ticks + HexChemistryWorld.ingredient_lifetime(shot.element_wire_id) + 2)
	return deadline


func _legacy_boundary_unchanged() -> void:
	var world := _world("projectile", false)
	var replay := _world("projectile", false)
	var died := false
	for step: int in 16:
		var commands := _commands(world, SimCommand.PRESSED_SPELL_1 if step == 0 else 0, step == 0)
		check(world.step(commands) and replay.step(commands), "legacy ordinary route advances unchanged")
		equal(world.state_hash(), replay.state_hash(), "legacy deterministic state stays unchanged between identical controls")
		equal(world.combat_events, replay.combat_events, "legacy damage ownership stays deterministic")
		if world.player().health == 0:
			died = true
			check(world.player().pending_cast_wire_id > 0 and world.player().pending_cast_ticks > 0, "Hex-specific cleanup does not alter existing legacy death boundary")
			break
	check(died, "legacy negative control actually reaches ordinary lethal contact")
	check(world.step(_commands(world, 0, false)), "legacy next successful step performs its existing cleanup")
	equal(world.player().pending_cast_wire_id, 0, "legacy retains its prior next-step pending cleanup")
