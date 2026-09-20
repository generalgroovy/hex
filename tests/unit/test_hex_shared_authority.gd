extends FluxTestSuite

const Shared = preload("res://src/sim/hex/hex_chemistry_world.gd")
const Snapshot = preload("res://src/net/hex_world_snapshot.gd")
const CAMPUS_PATH := "res://content/maps/sanctum_campus_g2_v1.json"
const CHAMPION_PATH := "res://content/champions/foundation_champions_v1.json"
const OLD_CRUCIBLE_BOUNDS := Rect2i(1_056_000, 1_152_000, 960_000, 448_000)
const ORDINARY_BENCH := Vector2i(1_536_000, 880_000)
const ORDINARY_TARGET := Vector2i(1_431_000, 867_000)

func run() -> int:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "shared authority uses production catalog")
	var unconfigured := Shared.new()
	unconfigured.chemistry_enabled = true
	check(not unconfigured.admission_reason(145).is_empty(), "unconfigured world cannot mint paid fields")
	var before := unconfigured.state_hash()
	check(not unconfigured.reserve_cast(1, 145), "unconfigured reservation refuses before mutation")
	equal(unconfigured.state_hash(), before, "refusal preserves IDs, pending entries and ledgers")
	check(not unconfigured.configure_geometry(Vector2i(9_000_000, 0), [Vector2i.ZERO]), "unsupported origin refuses")
	check(not unconfigured.configure_geometry(Vector2i.ZERO, HexGrid.disk(Vector2i.ZERO, 37)), "topology refuses beyond finite map-cell cap")
	check(not unconfigured.configure_geometry(Vector2i.ZERO, [Vector2i(2000, 0)]), "unsupported axial coordinate refuses")
	check(not unconfigured.configure_geometry(Vector2i.ZERO, []), "empty topology is rejected")
	check(not unconfigured.configure_geometry(Vector2i.ZERO, [Vector2i.ZERO, Vector2i.ZERO]), "duplicate topology is rejected atomically")
	equal(unconfigured.state_hash(), before, "rejected topology leaves authority unchanged")
	for slot: int in range(8):
		_test_paid_parity(catalog, slot)
	_test_translated_non_disk(catalog)
	_test_normal_campus_paid_exposure_and_snapshot(catalog)
	var shifted := Shared.new()
	check(shifted.configure_geometry(Vector2i(100_000, 100_000), [Vector2i.ZERO]), "translated bind fixture configured")
	shifted.chemistry_enabled = true
	check(shifted.reserve_cast(1, 145), "translated bind reservation admitted")
	shifted.commit_payment(1)
	var paid_hash := shifted.state_hash()
	shifted.bind_release(1, 1, "invalid")
	equal(shifted.state_hash(), paid_hash, "mistyped release fails closed without consuming reservation")
	shifted.bind_release(1, 1)
	equal(shifted.casts[1].origin, shifted.origin, "omitted release origin uses configured world origin")
	return finish("hex-shared-authority")

func _practice(catalog: AbilityCatalog) -> SimWorld:
	var world := SimWorld.new()
	check(HexCourtPractice.configure(world, catalog, false), "retained practice configuration loads")
	return world

func _test_paid_parity(catalog: AbilityCatalog, slot: int) -> void:
	var wrapper := _practice(catalog)
	var shared_world := _practice(catalog)
	var shared := Shared.new()
	check(shared.configure_geometry(HexCourt.ORIGIN, HexGrid.disk(Vector2i.ZERO, 6)), "shared world accepts explicit retained topology")
	shared.chemistry_enabled = true
	shared_world.hex_court = shared
	equal(shared.state_hash(), wrapper.hex_court.state_hash(), "scenario wrapper and base have identical initial authority")
	var definition := CombatTuning.cast_definition(wrapper.player().spell_wire_id(slot + 1))
	var flux_before := wrapper.player().flux
	var deposited := false
	for step: int in range(420):
		var pressed := int(SimCommand.SPELL_PRESSED_BITS[slot]) if step == 0 else 0
		for world: SimWorld in [wrapper, shared_world]:
			check(world.step([SimCommand.new(world.tick, 1, 0, 0, 0, pressed, 0, -1000, 640_000, 480_000)]), "paid command advances through shared authority")
		if step == 0:
			equal(wrapper.player().flux, flux_before - int(definition.flux_cost), "real input charges exact positive Flux")
			equal(shared_world.player().flux, wrapper.player().flux, "extraction preserves payment")
			before_reconfigure(shared)
		equal(shared.state_hash(), wrapper.hex_court.state_hash(), "shared authority preserves every ledger and lifecycle tick")
		equal(shared_world.state_hash(), wrapper.state_hash(), "whole simulation remains identical after extraction")
		for id: int in shared.casts:
			if int(shared.casts[id].ground) == 600: deposited = true
		if deposited: break
	check(deposited, "paid delivery reaches persistent selected cells")
	check(shared.conservation_valid(), "shared payment and persistent state conserve material")
	equal(shared_world.deposits.size() + shared_world.reactions.size() + shared_world.fields.size(), 0, "no legacy resolver state accompanies shared cast")

func before_reconfigure(shared: HexChemistryWorld) -> void:
	var before := shared.state_hash()
	check(not shared.configure_geometry(Vector2i.ZERO, [Vector2i.ZERO]), "cannot move topology beneath paid reservations")
	equal(shared.state_hash(), before, "rejected live reconfiguration is atomic")

func _test_translated_non_disk(catalog: AbilityCatalog) -> void:
	var world := _practice(catalog)
	var shared := Shared.new()
	var center := Vector2i(700_000, 450_000)
	check(shared.configure_geometry(center, [Vector2i(1, 0), Vector2i.ZERO]), "non-disk district supplies explicit translated eligible cells")
	shared.chemistry_enabled = true
	world.hex_court = shared
	world.player().reset_for_spawn(center + Vector2i(0, 200_000))
	var deposited := false
	for step: int in range(300):
		check(world.step([SimCommand.new(world.tick, 1, 0, 0, 0, int(SimCommand.SPELL_PRESSED_BITS[1]) if step == 0 else 0, 0, -1000, center.x, center.y)]), "translated district accepts real paid Fire Bolt")
		for id: int in shared.casts:
			if int(shared.casts[id].ground) > 0:
				deposited = true
				for cell: Vector2i in shared.casts[id].cells:
					check(cell in [Vector2i.ZERO, Vector2i(1, 0)], "paid field cannot escape configured eligibility")
		if deposited: break
	check(deposited, "translated topology receives the actual projectile terminal")
	check(shared.conservation_valid(), "translated finite field remains conserved")


func _test_normal_campus_paid_exposure_and_snapshot(catalog: AbilityCatalog) -> void:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file(CAMPUS_PATH), "global authority fixture loads the production campus")
	var champions := ChampionCatalog.new()
	check(champions.load_from_file(CHAMPION_PATH, catalog), "global authority fixture loads ordinary champions")
	if layout.content_hash.is_empty() or not champions.last_error.is_empty():
		return
	var definition := HexWorldDefinition.from_campus(layout)
	check(definition != null, "normal campus supplies one trusted whole-map topology")
	if definition == null:
		return
	check(definition.eligible_cells.size() > HexGrid.disk(Vector2i.ZERO, 6).size(), "normal campus authority extends beyond the retained 127-cell Court")
	var world := SimWorld.new(120, 9_401, layout.build_collision_world(), String(layout.data.id), layout.content_hash)
	check(champions.apply_to_player(world.player(), champions.default_champion_id), "paid fixture equips an authored ordinary champion")
	check(definition.bind_world(world), "ordinary Wellspring world binds global chemistry authority")
	if world.hex_court == null:
		return
	var target := ORDINARY_TARGET
	var bench := ORDINARY_BENCH
	check(bench == layout.spawn * SimConfig.FIXED_SCALE, "global fixture starts at the production Wellspring spawn")
	check(definition.eligible_cells.has(HexGrid.world_to_cell(target - definition.origin)), "ordinary target belongs to trusted whole-map topology")
	check(world.collision.can_occupy(bench, MovementTuning.PLAYER_RADIUS) and world.collision.can_occupy(target, MovementTuning.PLAYER_RADIUS), "ordinary casting lane has clear champion endpoints")
	check(world.collision is HexCollisionWorld and (world.collision as HexCollisionWorld).hex_wall_contact(bench, target, 11_000).is_empty(), "ordinary casting lane has no intervening chemistry cover")
	check(not OLD_CRUCIBLE_BOUNDS.has_point(target) and not OLD_CRUCIBLE_BOUNDS.has_point(bench), "paid inputs occur outside the old Crucible-only district")
	check(bench.distance_squared_to(target) < 120_000 * 120_000, "fixture uses an ordinary local projectile range")
	var actor := world.player()
	actor.reset_for_spawn(bench)
	actor.spawn_protection_ticks = 0
	var water_wire := int(catalog.ability(catalog.spell_id_at("water", "bolt")).wire_id)
	var fire_wire := int(catalog.ability(catalog.spell_id_at("fire", "bolt")).wire_id)
	check(actor.place_proven_spell(0, water_wire), "ordinary champion equips production Water Bolt")
	check(actor.place_proven_spell(1, fire_wire), "ordinary champion equips production Fire Bolt")
	var paid_before := int(world.hex_court.metrics.matter_paid)
	var steps := 0
	check(world.step([_paid_command(world, actor, 0, target)]), "Water enters global authority through a real paid SimCommand")
	steps += 1
	equal(int(world.hex_court.metrics.matter_paid), paid_before + Shared.MATTER_PER_CAST, "Water reserves one finite paid source")
	while steps < 500 and (actor.pending_cast_wire_id != 0 or actor.cast_recovery_ticks > 0 or _owner_has_flight(world, actor.entity_id)):
		check(world.step([]), "Water reaches its actual terminal through ordinary simulation")
		steps += 1
	check(steps < 500 and actor.pending_cast_wire_id == 0 and not _owner_has_flight(world, actor.entity_id), "Water reaches finite terminal authority within the case bound")
	if steps >= 500:
		return
	check(world.step([_paid_command(world, actor, 1, target)]), "Fire enters global authority through a second real paid SimCommand")
	steps += 1
	equal(int(world.hex_court.metrics.matter_paid), paid_before + 2 * Shared.MATTER_PER_CAST, "Water and Fire pay two independent finite budgets")
	var steam_wire := HexRecipePolicy.recipe_wire(3, 2)
	var product := _product(world, steam_wire)
	while steps < 500 and product.is_empty():
		check(world.step([]), "Fire resolves against actual Water terminal authority")
		steps += 1
		product = _product(world, steam_wire)
	check(steps < 500 and not product.is_empty(), "ordinary campus Water plus Fire forms Steam within 500 ticks")
	if product.is_empty():
		return
	equal(int(product.quantity), 2 * Shared.MATTER_PER_CAST, "Steam retains both finite paid budgets")
	equal(product.source_ids.size(), 2, "Steam records two distinct paid sources")
	check(product.source_ids[0] != product.source_ids[1], "global reaction cannot match one source with itself")
	equal(int(world.hex_court.metrics.matter_consumed), 2 * Shared.MATTER_PER_CAST, "reaction consumption is exactly the paid product quantity")
	check(world.hex_court.conservation_valid(), "global reaction conserves paid matter")
	var actual_cells: Array = Shared.coverage(product).keys()
	actual_cells.sort_custom(HexGrid._cell_less)
	check(not actual_cells.is_empty(), "Steam owns canonical selected-cell coverage")
	if actual_cells.is_empty():
		return
	var actual_cell: Vector2i = actual_cells[0]
	var actual_point: Vector2i = Vector2i(world.hex_court.origin) + HexGrid.center(actual_cell)
	check(definition.eligible_cells.has(actual_cell), "actual terminal reaction remains in trusted global topology")
	check(not OLD_CRUCIBLE_BOUNDS.has_point(actual_point), "actual reaction coverage, rather than an assumed target hit, is outside the old Crucible")

	var grounded := _ordinary_observer(champions, 2, actual_point)
	var high := _ordinary_observer(champions, 3, actual_point)
	var protected := _ordinary_observer(champions, 4, actual_point)
	if grounded == null or high == null or protected == null:
		return
	high.air_height = MovementTuning.AIR_MAX_HEIGHT
	high.air_vertical_velocity = 0
	protected.spawn_protection_ticks = 120
	world.players.append(grounded)
	world.players.append(high)
	world.players.append(protected)
	equal(world.players.filter(func(candidate: PlayerState) -> bool: return candidate.actor_kind == PlayerState.ActorKind.TRAINING_TARGET).size(), 0, "global fixture uses no training targets")
	var grounded_health := grounded.health
	var high_health := high.health
	var protected_health := protected.health
	var pulse_tick := int(product.active_tick)
	while pulse_tick % Shared.PULSE_TICKS != 0:
		pulse_tick += 1
	check(pulse_tick < int(product.decay_tick), "Steam has an active authored pulse inside its finite lifetime")
	while steps < 500 and world.tick <= pulse_tick:
		check(world.step([]), "active Steam advances through ordinary Wellspring simulation")
		steps += 1
	check(steps < 500, "paid reaction and exposure controls complete within 500 ticks")
	check(grounded.health < grounded_health, "grounded unprotected champion receives active Steam pressure")
	check(high.air_height > Shared.STEAM_HEIGHT, "airborne control remains above Steam height authority through the observed pulse")
	equal(high.health, high_health, "champion above Steam height authority receives no pressure")
	equal(protected.health, protected_health, "spawn-protected champion receives no pressure")
	check(world.combat_events.any(func(event: Dictionary) -> bool: return String(event.get("type", "")) == "hex_pressure" and int(event.get("entity_id", 0)) == grounded.entity_id), "grounded exposure emits canonical pressure evidence")
	check(int(world.hex_court.exposure.get(grounded.entity_id, 0)) > 0, "grounded champion accumulates finite Steam exposure")
	equal(int(world.hex_court.exposure.get(high.entity_id, 0)), 0, "height-gated champion accumulates no Steam exposure")
	equal(int(world.hex_court.exposure.get(protected.entity_id, 0)), 0, "protected champion accumulates no Steam exposure")
	check(world.hex_court.conservation_valid(), "active global effect preserves finite chemistry accounting")

	var snapshot := Snapshot.capture(world)
	check(not snapshot.is_empty(), "active global topology captures complete actor and chemistry authority")
	if snapshot.is_empty():
		return
	check(Snapshot.byte_size(snapshot) <= Snapshot.MAX_RAW_BYTES, "active global snapshot fits the unchanged transport bound")
	var trusted := SimWorld.new(120, world.seed, layout.build_collision_world(), String(layout.data.id), layout.content_hash)
	check(definition.bind_world(trusted), "snapshot target independently supplies the trusted global topology")
	var prepared := Snapshot.prepare(snapshot, trusted)
	check(prepared != null, "active global snapshot prepares without remote topology mutation")
	if prepared == null:
		return
	equal(prepared.state_hash(), world.state_hash(), "global topology snapshot restores exact champion and chemistry authority")
	check(world.step([]) and prepared.step([]), "original and restored global worlds accept the same next tick")
	equal(prepared.state_hash(), world.state_hash(), "global snapshot produces identical subsequent authority")


func _paid_command(world: SimWorld, actor: PlayerState, slot: int, target: Vector2i) -> SimCommand:
	var delta := target - Vector2i(actor.position_x, actor.position_y)
	return SimCommand.new(world.tick, actor.entity_id, 0, 0, 0, int(SimCommand.SPELL_PRESSED_BITS[slot]), delta.x, delta.y, target.x, target.y)


func _owner_has_flight(world: SimWorld, owner_id: int) -> bool:
	return world.projectiles.any(func(projectile: ProjectileState) -> bool: return projectile.owner_id == owner_id)


func _product(world: SimWorld, wire: int) -> Dictionary:
	for product: Dictionary in world.hex_court.products.values():
		if int(product.recipe_wire_id) == wire:
			return product
	return {}


func _ordinary_observer(champions: ChampionCatalog, entity_id: int, point: Vector2i) -> PlayerState:
	var actor := PlayerState.new(entity_id)
	actor.team_id = entity_id
	check(champions.apply_to_player(actor, champions.default_champion_id), "observer %d uses an authored ordinary champion" % entity_id)
	if actor.champion_wire_id <= 0:
		return null
	actor.reset_for_spawn(point)
	actor.spawn_protection_ticks = 0
	actor.health_recovery_per_second = 0
	return actor
