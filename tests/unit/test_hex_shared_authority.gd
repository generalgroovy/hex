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
	check(not unconfigured.configure_geometry(Vector2i.ZERO, HexGrid.disk(Vector2i.ZERO, 148)), "topology refuses beyond finite map-cell cap")
	check(not unconfigured.configure_geometry(Vector2i.ZERO, [Vector2i(2000, 0)]), "unsupported axial coordinate refuses")
	check(not unconfigured.configure_geometry(Vector2i.ZERO, []), "empty topology is rejected")
	check(not unconfigured.configure_geometry(Vector2i.ZERO, [Vector2i.ZERO, Vector2i.ZERO]), "duplicate topology is rejected atomically")
	equal(unconfigured.state_hash(), before, "rejected topology leaves authority unchanged")
	for slot: int in range(8):
		_test_paid_parity(catalog, slot)
	_test_translated_non_disk(catalog)
	_test_normal_campus_paid_exposure_and_snapshot(catalog)
	_test_paid_muzzle_cover(catalog)
	_test_paid_muzzle_earth_cover(catalog)
	_test_paid_spray_fan_cover(catalog)
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
	check(shared.configure_geometry(HexCourt.ORIGIN, HexGrid.disk(Vector2i.ZERO, HexCourt.RADIUS)), "shared world accepts explicit retained topology")
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

	# Observe one actual active pulse; do not assume an apex can remain above
	# Steam throughout a variable formation wait without gravity pulling it down.
	var pulse_tick := int(product.active_tick)
	while pulse_tick % Shared.PULSE_TICKS != 0: pulse_tick += 1
	while steps < 500 and world.tick < pulse_tick:
		check(world.step([]), "paid Steam reaches its observed active pulse")
		steps += 1
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


func _spray_fan_world(catalog: AbilityCatalog, wire: int, geometry: String, target_count: int) -> SimWorld:
	var world := _practice(catalog)
	var origin := HexCourt.ORIGIN
	var owner := world.player()
	owner.reset_for_spawn(origin)
	owner.spawn_protection_ticks = 0
	owner.flux_recovery_per_second = 0
	check(owner.place_proven_spell(0, wire), "Spray fan fixture equips the real authored wire")
	var offsets: Array[Vector2i] = [Vector2i(250_000, -90_000), Vector2i(250_000, 90_000), Vector2i(250_000, 0)]
	for index: int in target_count:
		var target := PlayerState.new(index + 2)
		target.team_id = 2
		target.reset_for_spawn(origin + offsets[index])
		target.spawn_protection_ticks = 0
		target.health_recovery_per_second = 0
		world.players.append(target)
	if geometry in ["pillar", "side", "wall"]:
		var height := 180_000 if geometry == "wall" else 10_000
		world.collision.add_obstacle(CollisionWorld.Obstacle.new(991, origin.x + 80_000, origin.y - height, origin.x + 90_000, origin.y + height))
	if geometry == "side":
		world.collision.add_obstacle(CollisionWorld.Obstacle.new(992, origin.x + 120_000, origin.y - 90_000, origin.x + 130_000, origin.y - 30_000))
	return world


func _test_paid_spray_fan_cover(catalog: AbilityCatalog) -> void:
	for element: String in AbilityCatalog.DISPLAY_ELEMENT_IDS:
		var wire := int(catalog.ability(catalog.spell_id_at(element, "spray")).wire_id)
		for geometry: String in ["open1", "open2", "open3", "pillar", "side", "wall", "short"]:
			var target_count := int(geometry.right(1)) if geometry.begins_with("open") else 3
			var world := _spray_fan_world(catalog, wire, geometry, target_count)
			var owner := world.player()
			var definition := CombatTuning.cast_definition(wire)
			var label := "%s Spray/%s" % [element, geometry]
			var origin := HexCourt.ORIGIN
			var reach := 100_000 if geometry == "short" else int(definition.range)
			for actor: PlayerState in world.players:
				check(world.collision.can_occupy(Vector2i(actor.position_x, actor.position_y), actor.radius), label + " actors have legal non-overlapping wall clearance")
			var flux_before := owner.flux
			check(world.step([_paid_command(world, owner, 0, origin + Vector2i(reach, 0))]), label + " begins via real paid input")
			equal(flux_before - owner.flux, int(definition.flux_cost), label + " exact authored Flux debit")
			equal(int(world.hex_court.metrics.matter_paid), Shared.MATTER_PER_CAST, label + " reserves one 600-unit ingredient")
			var restored: SimWorld = null
			if geometry == "pillar":
				var snapshot := Snapshot.capture(world)
				check(not snapshot.is_empty(), label + " captures pending paid release")
				if not snapshot.is_empty(): restored = Snapshot.prepare(snapshot, _spray_fan_world(catalog, wire, geometry, target_count))
				check(restored != null, label + " pending release restores against trusted pillar geometry")
			var fired: Dictionary = {}
			for step: int in 64:
				check(world.step([]), label + " advances with no repeat cast input")
				if restored != null:
					check(restored.step([]), label + " restored paid command advances")
					equal(restored.state_hash(), world.state_hash(), label + " exact host/snapshot authority continuation")
					equal(var_to_bytes(restored.combat_events), var_to_bytes(world.combat_events), label + " exact event-byte continuation")
				for event: Dictionary in world.combat_events:
					if event.get("type", "") == "spray_fired": fired = event
				if not fired.is_empty(): break
			check(not fired.is_empty(), label + " releases one bounded paid fan")
			if fired.is_empty(): continue
			var expected_hits := target_count if geometry.begins_with("open") else 2 if geometry == "pillar" else 1 if geometry == "side" else 0
			equal(int(fired.hit_count), expected_hits, label + " clear flank benefits do not penetrate the center/side wall or exceed cursor range")
			equal(int(fired.range), reach, label + " center cover never contracts the authored sector envelope")
			for index: int in target_count:
				var target := world.player(index + 2)
				var should_hit := geometry.begins_with("open") or (geometry == "pillar" and index < 2) or (geometry == "side" and index == 1)
				equal(target.health_maximum - target.health, int(definition.damage) if should_hit else 0, label + " target %d receives only authored direct damage" % index)
			equal(flux_before - owner.flux, int(definition.flux_cost), label + " release does not refund or debit again")
			equal(world.hex_court.casts.size(), 1, label + " retains exactly the one paid source")
			if world.hex_court.casts.size() != 1: continue
			var record: Dictionary = world.hex_court.casts.values()[0]
			equal(int(record.ground), Shared.MATTER_PER_CAST, label + " spread redistributes but never increases finite matter")
			equal(int(record.ledger.remaining_strength), int(definition.reaction_strength), label + " actor count does not mint or subtract interception strength")
			var far_flank := false
			var blocked_candidates := 0
			for cell: Vector2i in HexFootprint.selected_cells(record.footprint, world.hex_court.origin, world.hex_court.topology_cells_view()):
				var center: Vector2i = world.hex_court.origin + HexGrid.center(cell)
				var visible := ContinuousContact.wall_contact(origin, center, int(definition.radius), world.collision).is_empty()
				if not visible:
					blocked_candidates += 1
					check(not Shared.coverage(record).has(cell), label + " hidden whole-cell center receives no deposited material")
				elif Shared.coverage(record).has(cell) and center.x > origin.x + 150_000 and absi(center.y - origin.y) > 55_000:
					far_flank = true
			if geometry == "pillar":
				check(far_flank, label + " actual paid selected cells reach beyond the pillar on a clear flank")
				check(blocked_candidates > 0, label + " negative material control includes shadowed cells")
			check(world.hex_court.conservation_valid(), label + " conserves paid, deposited and expired matter")
			if element == "fire" and geometry == "pillar":
				for step: int in Shared.FIRE_TICKS + 2: check(world.step([]), "paid pillar material expires through ordinary idle commands")
				equal(int(world.hex_court.metrics.matter_expired), Shared.MATTER_PER_CAST, "entire paid fan eventually expires without free material")
				check(world.hex_court.conservation_valid(), "per-ray fan remains conserved through complete expiry")


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


func _test_paid_muzzle_cover(catalog: AbilityCatalog) -> void:
	for element: String in AbilityCatalog.DISPLAY_ELEMENT_IDS:
		for family: String in ["bolt", "heavy", "rapid", "spray"]:
			var wire := int(catalog.ability(catalog.spell_id_at(element, family)).wire_id)
			# The same paid catalog path covers all32 spells. Spray already clips
			# before the wall; it must not inherit projectile creation semantics.
			for sign_x: int in [-1, 1]:
				_run_paid_muzzle_case(catalog, wire, family, "thin", sign_x, element == "fire")
			_run_paid_muzzle_case(catalog, wire, family, "open", 1)
			if family == "spray": continue
			for geometry: String in ["side", "away", "corner", "short"]:
				_run_paid_muzzle_case(catalog, wire, family, geometry, 1, element == "fire" and geometry == "away")


func _muzzle_world(catalog: AbilityCatalog, wire: int, geometry: String, sign_x: int) -> SimWorld:
	var world := _practice(catalog)
	var origin := HexCourt.ORIGIN
	var actor := world.player()
	actor.reset_for_spawn(origin)
	actor.spawn_protection_ticks = 0
	actor.flux_recovery_per_second = 0
	actor.health_recovery_per_second = 0
	check(actor.place_proven_spell(0, wire), "muzzle fixture equips the actual paid spell")
	var target := PlayerState.new(2)
	target.team_id = 2
	target.reset_for_spawn(origin + Vector2i(sign_x * 120_000, 0))
	target.spawn_protection_ticks = 0
	target.health_recovery_per_second = 0
	world.players.append(target)
	if geometry == "short" and AbilityCatalog._spell_family(catalog.ability_from_wire(wire)) == "heavy":
		var beyond_blast := PlayerState.new(3)
		beyond_blast.team_id = 2
		var blast_radius := int(CombatTuning.cast_definition(wire).blast_radius)
		beyond_blast.reset_for_spawn(origin + Vector2i(sign_x * 8000, blast_radius + beyond_blast.radius + 1))
		beyond_blast.spawn_protection_ticks = 0
		beyond_blast.health_recovery_per_second = 0
		world.players.append(beyond_blast)
	var radius := int(CombatTuning.cast_definition(wire).radius)
	if geometry == "thin":
		var near_x := origin.x + sign_x * MovementTuning.PLAYER_RADIUS
		var far_x := near_x + sign_x * 1000
		world.collision.add_obstacle(CollisionWorld.Obstacle.new(990, mini(near_x, far_x), origin.y - 80_000, maxi(near_x, far_x), origin.y + 80_000))
	elif geometry == "side":
		# Heavy's full body is exactly tangent. Smaller projectiles retain the
		# shared actor clearance rather than being placed inside the side wall.
		var side := origin.y + maxi(radius, MovementTuning.PLAYER_RADIUS)
		world.collision.add_obstacle(CollisionWorld.Obstacle.new(990, origin.x - 80_000, side, origin.x + 240_000, side + 1000))
	elif geometry == "away":
		var edge := origin.x - MovementTuning.PLAYER_RADIUS
		world.collision.add_obstacle(CollisionWorld.Obstacle.new(990, edge - 1000, origin.y - 80_000, edge, origin.y + 80_000))
	elif geometry == "corner":
		# The actor clears this real corner; both the muzzle center line and
		# the created projectile's full-radius path pass it on the safe side.
		world.collision.add_obstacle(CollisionWorld.Obstacle.new(990, origin.x + 20_000, origin.y + radius + 1, origin.x + 21_000, origin.y + radius + 30_000))
	return world


func _run_paid_muzzle_case(catalog: AbilityCatalog, wire: int, family: String, geometry: String, sign_x: int, restore: bool = false) -> void:
	var world := _muzzle_world(catalog, wire, geometry, sign_x)
	var actor := world.player()
	var origin := Vector2i(actor.position_x, actor.position_y)
	var definition := CombatTuning.cast_definition(wire)
	var aim_target := origin + Vector2i(sign_x * (8000 if geometry == "short" else 200_000), 0)
	var spawn_distance := mini(MovementTuning.PLAYER_RADIUS + int(definition.radius) + CombatTuning.PROJECTILE_SPAWN_CLEARANCE, absi(aim_target.x - origin.x))
	var muzzle := origin + Vector2i(sign_x * spawn_distance, 0)
	var label := "%s/%s/%s" % [wire, geometry, sign_x]
	check(world.collision.can_occupy(origin, MovementTuning.PLAYER_RADIUS), label + " caster has legal shared wall clearance")
	if family != "spray":
		check(world.collision.can_occupy(muzzle, int(definition.radius)), label + " old endpoint-only check would admit the projectile")
		equal(ContinuousContact.wall_contact(origin, muzzle, 0, world.collision).is_empty(), geometry != "thin", label + " exact center-line witness distinguishes cover from the safe controls")
		if geometry == "away" and family == "heavy":
			check(not world.collision.can_occupy(origin, int(definition.radius)), "Heavy control really begins wider than actor clearance; do not sweep a fictional full body from the caster")
	var flux_before := actor.flux
	var health_before := world.player(2).health
	check(world.step([_paid_command(world, actor, 0, aim_target)]), label + " starts through a real paid command")
	equal(flux_before - actor.flux, int(definition.flux_cost), label + " pays exactly one authored Flux cost")
	equal(int(world.hex_court.metrics.matter_paid), Shared.MATTER_PER_CAST, label + " reserves exactly one finite ingredient")
	var prepared: SimWorld = null
	if restore:
		var snapshot := Snapshot.capture(world)
		check(not snapshot.is_empty(), label + " pending paid cast captures before its release decision")
		if not snapshot.is_empty(): prepared = Snapshot.prepare(snapshot, _muzzle_world(catalog, wire, geometry, sign_x))
		check(prepared != null, label + " trusted cover and pending payment restore")
		if prepared != null: equal(prepared.state_hash(), world.state_hash(), label + " restore preserves exact authority")
	var events: Array[Dictionary] = world.combat_events.duplicate(true)
	var steps := 0
	while steps < 180 and (actor.pending_cast_wire_id != 0 or not world.projectiles.is_empty()):
		check(world.step([]), label + " paid release and flight advance without more cast input")
		events.append_array(world.combat_events)
		if prepared != null:
			check(prepared.step([]), label + " restored continuation advances")
			equal(prepared.state_hash(), world.state_hash(), label + " continuation preserves full authority")
			equal(var_to_bytes(prepared.combat_events), var_to_bytes(world.combat_events), label + " continuation preserves release/contact event bytes")
		steps += 1
	check(steps < 180 and actor.pending_cast_wire_id == 0 and world.projectiles.is_empty(), label + " resolves within the bounded paid case")
	equal(flux_before - actor.flux, int(definition.flux_cost), label + " release neither refunds nor pays twice")
	check(world.hex_court.conservation_valid(), label + " conserves the complete paid budget")
	var blocked := geometry == "thin" and family != "spray"
	equal(events.filter(func(event: Dictionary) -> bool: return String(event.get("type", "")) == "cast_blocked").size(), 1 if blocked else 0, label + " emits exactly the existing blocked outcome when center cover intervenes")
	equal(events.filter(func(event: Dictionary) -> bool: return String(event.get("type", "")) == "projectile_spawned").size(), 0 if blocked or family == "spray" else 1, label + " creates only the legal paid projectile")
	if geometry == "thin":
		equal(world.player(2).health, health_before, label + " never damages the far-side target through cover")
	elif geometry == "short":
		# SimWorld consumes its private material terminal before publishing events;
		# projectile_expired retains the authoritative range-contact witness.
		var expirations := events.filter(func(event: Dictionary) -> bool: return String(event.get("type", "")) == "projectile_expired")
		equal(expirations.size(), 1, label + " cursor-bounded flight expires exactly once")
		if not expirations.is_empty():
			equal(Vector2i(expirations[0].contact_position), aim_target, label + " flight stops at the cursor rather than following the beyond-cursor target")
		equal(events.filter(func(event: Dictionary) -> bool: return String(event.get("type", "")) == "projectile_impact").size(), 0,
			label + " short flight ends by range without inventing a wall impact")
		if family == "heavy":
			equal(health_before - world.player(2).health, 18_000, label + " cursor detonation still applies the real Heavy splash to the nearby target")
			equal(world.player(3).health, world.player(3).health_maximum, label + " a target one fixed unit outside the cursor blast remains unharmed")
		else:
			equal(world.player(2).health, health_before, label + " non-explosive short flight never reaches the beyond-cursor target")
	else:
		check(world.player(2).health < health_before, label + " unobstructed control really reaches an enemy")
	if blocked:
		equal(int(world.hex_court.metrics.matter_expired), Shared.MATTER_PER_CAST, label + " blocked paid material expires without being minted on either side")
		equal(int(world.hex_court.metrics.deposited), 0, label + " blocked release deposits nothing")
		equal(world.hex_court.casts.size() + world.hex_court.products.size() + world.hex_court.pending.size(), 0, label + " leaves no stranded reservation or chemical source")
		check(actor.spell_cooldown_for_wire(wire) > 0 and actor.cast_recovery_ticks > 0, label + " blocked release retains its authored recovery and cooldown")
	else:
		check(int(world.hex_court.metrics.deposited) > 0, label + " positive control reaches real terminal material")
	if family == "spray":
		equal(events.filter(func(event: Dictionary) -> bool: return String(event.get("type", "")) == "spray_fired").size(), 1, label + " Spray retains its own single finite fan release")


func _test_paid_muzzle_earth_cover(catalog: AbilityCatalog) -> void:
	for fire_away: bool in [false, true]:
		var earth_wire := int(catalog.ability(catalog.spell_id_at("earth", "bolt")).wire_id)
		var heavy_wire := int(catalog.ability(catalog.spell_id_at("fire", "heavy")).wire_id)
		var world := _practice(catalog)
		var actor := world.player()
		actor.reset_for_spawn(HexCourt.ORIGIN + Vector2i(0, 160_000))
		actor.spawn_protection_ticks = 0
		actor.flux_recovery_per_second = 0
		check(actor.place_proven_spell(0, earth_wire), "dynamic cover uses actual Earth Bolt")
		for ingredient: int in 2:
			check(world.step([_paid_command(world, actor, 0, HexCourt.ORIGIN)]), "Earth ingredient enters through paid command")
			for unused: int in 180:
				if actor.pending_cast_wire_id == 0 and world.projectiles.is_empty(): break
				check(world.step([]), "Earth ingredient reaches its real terminal")
			for unused: int in 36: check(world.step([]), "Earth ingredients respect authored recovery and cooldown")
			equal(int(world.hex_court.metrics.matter_paid), (ingredient + 1) * Shared.MATTER_PER_CAST, "each Rampart ingredient pays its own600-unit budget")
		var product := _product(world, 301)
		check(not product.is_empty(), "two real paid Earth Bolts form the Rampart control")
		if product.is_empty(): continue
		for unused: int in 180:
			if world.tick > int(product.active_tick): break
			check(world.step([]), "Rampart completes its real formation clock")
		check(world.tick > int(product.active_tick) and world.tick < int(product.decay_tick), "dynamic cover is genuinely active")
		var cells := Shared.coverage(product)
		check(not cells.is_empty(), "paid Rampart owns selected whole hexes")
		if cells.is_empty(): continue
		var edge_point: Vector2i = world.hex_court.origin + HexGrid.center(cells.keys()[0])
		for cell: Vector2i in cells:
			var candidate: Vector2i = world.hex_court.origin + HexGrid.center(cell)
			if candidate.x < edge_point.x: edge_point = candidate
		var cast_origin: Vector2i = edge_point - Vector2i(HexGrid.HALF_WIDTH + MovementTuning.PLAYER_RADIUS + 1, 0)
		actor.reset_for_spawn(cast_origin)
		actor.spawn_protection_ticks = 0
		check(world.collision.can_occupy(cast_origin, MovementTuning.PLAYER_RADIUS), "caster remains outside the active Rampart at shared actor clearance")
		check(actor.place_proven_spell(0, heavy_wire), "dynamic cover control equips actual Heavy")
		var target: Vector2i = cast_origin + Vector2i(-100_000, 0) if fire_away else edge_point
		var paid_before := int(world.hex_court.metrics.matter_paid)
		var expired_before := int(world.hex_court.metrics.matter_expired)
		var flux_before := actor.flux
		check(world.step([_paid_command(world, actor, 0, target)]), "Heavy facing toward/away from active Earth cover starts paid")
		var blocked_events := 0
		var spawned_events := 0
		for unused: int in 180:
			for event: Dictionary in world.combat_events:
				if String(event.get("type", "")) == "cast_blocked": blocked_events += 1
				if String(event.get("type", "")) == "projectile_spawned": spawned_events += 1
			if actor.pending_cast_wire_id == 0 and world.projectiles.is_empty(): break
			check(world.step([]), "Heavy uses the same active whole-hex collision adapter")
		check(actor.pending_cast_wire_id == 0 and world.projectiles.is_empty(), "dynamic cover cast finishes within the180-tick bound")
		equal(blocked_events, 0 if fire_away else 1, "active Earth cover blocks inward creation but permits the outward Heavy")
		equal(spawned_events, 1 if fire_away else 0, "dynamic cover admits only the legal Heavy")
		equal(flux_before - actor.flux, int(CombatTuning.cast_definition(heavy_wire).flux_cost), "dynamic cover cast pays exactly once without refund")
		equal(int(world.hex_court.metrics.matter_paid), paid_before + Shared.MATTER_PER_CAST, "dynamic cover cast owns exactly one additional finite source")
		if not fire_away: equal(int(world.hex_court.metrics.matter_expired), expired_before + Shared.MATTER_PER_CAST, "inward blocked Heavy expires its entire paid source")
		check(world.hex_court.conservation_valid(), "paid Earth cover and the subsequent Heavy remain conserved")
