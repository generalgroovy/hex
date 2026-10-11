extends FluxTestSuite


const ABILITY_PATH := "res://content/abilities/foundation_abilities_v1.json"
var _next_source := 20_000


func run() -> int:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file(ABILITY_PATH), "optics fixture loads the production ability catalog: %s" % catalog.last_error)
	if not catalog.last_error.is_empty():
		return finish("hex-optics")
	_test_retired_recipe_admission(catalog)
	_test_prism_reflects_once(catalog)
	_test_lightbend_rotates_light_once(catalog)
	_test_penumbra_projectiles_preserve_pulse_clock(catalog)
	_test_low_level_split_preserves_one_finite_light_source(catalog)
	_test_constructs_use_selected_hex_cover(catalog)
	_test_clipped_damage_cannot_reappear_in_heavy_blast(catalog)
	_test_low_level_suppression_requires_whole_strength_quantum(catalog)
	_test_parent_terminal_precedes_child_clash(catalog)
	_test_new_ground_contact_starts_at_terminal_time(catalog)
	return finish("hex-optics")


func _test_retired_recipe_admission(catalog: AbilityCatalog) -> void:
	for wire: int in [305, 306, 329]:
		check(HexRecipePolicy.definition(wire).is_empty(), "retired optical recipe%d has no active formation policy" % wire)
	for element: String in ["ice", "charge"]:
		for family: String in ["bolt", "heavy", "rapid", "spray"]:
			equal(catalog.spell_id_at(element, family), "", "retired element has no live selectable spell")
	for retired: int in [5, 6]:
		for live: int in ElementRules.WIRE_IDS:
			equal(HexRecipePolicy.recipe_wire(retired, live), 0, "retired optical ingredient never folds inside live chemistry")


func _test_prism_reflects_once(catalog: AbilityCatalog) -> void:
	var fixture := _world()
	var world: SimWorld = fixture.world
	var court: HexCourt = fixture.court
	var product := _form_product(world, catalog, 307, court.origin, Vector2i(1000, 0))
	_activate(world)
	var start := court.origin - Vector2i(220_000, 0)
	var shot := _shot(world, court, catalog, "water", "bolt", start, Vector2i(52_800_000, 0))
	HexProjectileCombat.advance(world)
	check(shot.velocity_x < 0 and shot.velocity_y == 0, "Crystal Prism reflects the incoming velocity across its authored normal")
	check(shot.position_x < int(product.position.x), "reflected flight spends the remainder of the same tick on the reflected side")
	equal(_events(world, "hex_optical_contact").size(), 1, "multi-hex Prism coverage reflects one projectile only once")
	equal(int(court.ledger_for_source(shot.source_cast_id).flight_quantity), 600, "reflection changes motion without spending source stock")
	check(court.conservation_valid(), "reflected paid source and formed Prism remain conserved")


func _test_lightbend_rotates_light_once(catalog: AbilityCatalog) -> void:
	var fixture := _world()
	var world: SimWorld = fixture.world
	var court: HexCourt = fixture.court
	_form_product(world, catalog, 325, court.origin, Vector2i(0, 1000))
	_activate(world)
	var original_velocity := Vector2i(52_800_000, 0)
	var light := _shot(world, court, catalog, "light", "bolt", court.origin - Vector2i(220_000, 0), original_velocity)
	HexProjectileCombat.advance(world)
	var once := ElementChemistrySystem.rotated_fifteen(original_velocity, 1)
	equal(Vector2i(light.velocity_x, light.velocity_y), once, "Lightbend rotates Light by exactly positive15 degrees")
	check(Vector2i(light.velocity_x, light.velocity_y) != ElementChemistrySystem.rotated_fifteen(once, 1), "multi-cell traversal cannot apply a second15-degree rotation")
	equal(_events(world, "hex_optical_contact").size(), 1, "Lightbend records one optical contact for the source")
	equal(int(court.ledger_for_source(light.source_cast_id).flight_quantity), 600, "Lightbend motion leaves finite matter untouched")

	fixture = _world()
	world = fixture.world
	court = fixture.court
	_form_product(world, catalog, 325, court.origin, Vector2i(0, 1000))
	_activate(world)
	var fire := _shot(world, court, catalog, "fire", "bolt", court.origin - Vector2i(220_000, 0), original_velocity)
	HexProjectileCombat.advance(world)
	equal(Vector2i(fire.velocity_x, fire.velocity_y), original_velocity, "Lightbend does not rotate non-Light flight")
	equal(_events(world, "hex_optical_contact").size(), 0, "ineligible non-Light traversal creates no optical contact")


func _test_penumbra_projectiles_preserve_pulse_clock(catalog: AbilityCatalog) -> void:
	var fixture := _world()
	var world: SimWorld = fixture.world
	var court: HexCourt = fixture.court
	var caster := _target(world, court.origin + Vector2i(0, 96_000), 1)
	for element: String in ["light", "dark"]:
		check(caster.place_proven_spell(0, _wire(catalog, element, "bolt")), "Penumbra fixture equips a production Bolt")
		var flux_before := caster.flux
		var paid_before := int(court.metrics.matter_paid)
		var command := SimCommand.new(world.tick, 1, 0, 0, 0, int(SimCommand.SPELL_PRESSED_BITS[0]), 0, -1000, court.origin.x, court.origin.y)
		check(world.step([command]), "Penumbra formation starts through real paid input")
		check(caster.flux < flux_before, "each Penumbra ingredient actually spends Flux")
		equal(int(court.metrics.matter_paid), paid_before + 600, "each paid ingredient owns one finite600-unit budget")
		for unused: int in 300:
			if caster.pending_cast_wire_id == 0 and world.projectiles.is_empty(): break
			check(world.step([]), "Penumbra paid startup and terminal complete")
		check(caster.pending_cast_wire_id == 0 and world.projectiles.is_empty(), "Penumbra ingredient reaches its endpoint in bounded time")
		if element == "light":
			for unused: int in 36: check(world.step([]), "first paid ingredient persists through cast recovery")
	var product: Dictionary = {}
	for candidate: Dictionary in court.products.values():
		if int(candidate.recipe_wire_id) == 335: product = candidate
	check(not product.is_empty(), "two real paid Bolts form Penumbra")
	if product.is_empty(): return
	equal(int(product.quantity), 1200, "paid Penumbra transfers exactly two conserved source budgets")
	while world.tick < int(product.active_tick): check(world.step([]), "paid Penumbra completes its warning")
	var point: Vector2i = product.position + Vector2i(0, -40_000)
	check(court.contains_stored(product, point), "pulse actors occupy actual Penumbra coverage away from projectile paths")
	var hostile := _target(world, point, 2)
	var ally := _target(world, point, 3)
	ally.team_id = int(product.team)
	var protected_actor := _target(world, point, 4)
	protected_actor.spawn_protection_ticks = 1
	world.tick = int(product.active_tick)
	court.current_tick = world.tick
	world.combat_events.clear()
	court.apply_product_effects(world.players, world.tick, world.config, world.collision, world.combat_events)
	equal(hostile.health, 97_000, "Penumbra activation pays one3000 hostile pulse")
	equal(ally.health, 100_000, "Penumbra activation does not damage its team")
	equal(protected_actor.health, 100_000, "Penumbra activation respects spawn protection")
	equal(_events(world, "chemistry_hit").size(), 1, "activation emits exactly one eligible actor hit")
	equal(int(product.pulse_index), 0, "activation consumes pulse index zero")
	var snapshot := HexChemistrySnapshot.capture(court)
	check(not snapshot.is_empty(), "paid Penumbra pulse, entry latch and contact state capture")
	if snapshot.is_empty(): return
	var restored := _restore_penumbra_fixture(world, snapshot)
	var old_write_control := _restore_penumbra_fixture(world, snapshot)
	if restored == null or old_write_control == null: return
	var source_sequence := _next_source
	_penumbra_crossing_sequence(world, catalog, int(product.id))
	_next_source = source_sequence
	_penumbra_crossing_sequence(restored, catalog, int(product.id))
	equal(restored.hex_court.state_hash(), court.state_hash(), "snapshot continuation preserves complete pulse/contact and paid-matter authority")
	for actor: PlayerState in world.players:
		equal(restored.player(actor.entity_id).canonical_values(), actor.canonical_values(), "snapshot continuation preserves complete actor effect state")
	equal(var_to_bytes(restored.combat_events), var_to_bytes(world.combat_events), "snapshot continuation emits identical entry-damage events")
	# Emulate the removed optical clock write. The current entry latch must
	# independently prevent repeated damage, while a genuinely new entrant pays once.
	old_write_control.tick = int(product.active_tick) + 1
	old_write_control.hex_court.current_tick = old_write_control.tick
	old_write_control.hex_court.products[int(product.id)].pulse_index = old_write_control.tick
	old_write_control.combat_events.clear()
	old_write_control.hex_court.apply_product_effects(old_write_control.players, old_write_control.tick, old_write_control.config, old_write_control.collision, old_write_control.combat_events)
	equal(old_write_control.player(2).health, 97_000, "entry latch rejects repeat damage even if the old optical clock write is emulated")
	equal(_events(old_write_control, "chemistry_hit").size(), 0, "clock mutation cannot create an off-entry hostile hit")
	var new_entrant := _target(old_write_control, point, 95)
	old_write_control.hex_court.apply_product_effects(old_write_control.players, old_write_control.tick, old_write_control.config, old_write_control.collision, old_write_control.combat_events)
	equal(new_entrant.health, 97_000, "positive control admits one3000 hit for a genuinely new hostile entrant")
	equal(_events(old_write_control, "chemistry_hit").size(), 1, "new entry retains observable damage after the clock-mutation refusal")
	check(court.conservation_valid() and restored.hex_court.conservation_valid(), "crossings and snapshot continuation conserve paid material")


func _restore_penumbra_fixture(source: SimWorld, snapshot: Dictionary) -> SimWorld:
	var fixture := _world()
	var restored: SimWorld = fixture.world
	var accepted := HexChemistrySnapshot.restore(snapshot, restored.hex_court)
	check(accepted, "paid Penumbra restores against matching trusted hex topology")
	if not accepted: return null
	for actor: PlayerState in source.players:
		var copy := HexWorldSnapshot._decode_valid_player_values(actor.canonical_values())
		check(copy != null, "snapshot continuation copies canonical actor effect state")
		if copy == null: return null
		restored.players.append(copy)
	restored.tick = source.tick
	check((restored.collision as HexCollisionWorld).set_hex_surfaces(restored.hex_court, restored.tick), "restored Penumbra installs the same trusted collision view")
	return restored


func _penumbra_crossing_sequence(world: SimWorld, catalog: AbilityCatalog, product_id: int) -> void:
	var court: HexCourt = world.hex_court
	var product: Dictionary = court.products[product_id]
	for offset: int in [1, 2, 71, 72]:
		world.tick = int(product.active_tick) + offset
		court.current_tick = world.tick
		world.combat_events.clear()
		var crossing_shots: Array[ProjectileState] = []
		for lane: int in 2:
			var shot := _shot(world, court, catalog, "water", "rapid", Vector2i(product.position) + Vector2i(-220_000, lane * 16_000), Vector2i(52_800_000, 0))
			shot.team_id = int(product.team) if lane == 0 else int(product.team) + 1
			court.casts[int(court.sources[shot.source_cast_id])].team = shot.team_id
			crossing_shots.append(shot)
		HexProjectileCombat.advance(world)
		for shot: ProjectileState in crossing_shots:
			check((shot.chemistry_interaction_mask & (1 << (335 - 301))) != 0, "both allied and hostile projectiles actually cross Penumbra once")
			equal(Vector2i(shot.velocity_x, shot.velocity_y), Vector2i(52_800_000, 0), "Penumbra crossings remain non-deflecting")
		equal(int(product.pulse_index), 0, "projectile contact cannot overwrite the actor pulse clock")
		court.apply_product_effects(world.players, world.tick, world.config, world.collision, world.combat_events)
		equal(world.player(2).health, 97_000, "crossings cannot rearm the once-per-actor Penumbra entry hit, including the former600ms pulse boundary")
		equal(world.player(3).health, 100_000, "allied actor remains unharmed through crossing pulses")
		equal(world.player(4).health, 100_000, "protected actor remains unharmed through crossing pulses")
		equal(_events(world, "chemistry_hit").size(), 0, "multiple crossings never add a repeated actor hit")
		court.apply_product_effects(world.players, world.tick, world.config, world.collision, world.combat_events)
		equal(_events(world, "chemistry_hit").size(), 0, "repeated same-tick effects cannot duplicate the entry hit")


func _test_low_level_split_preserves_one_finite_light_source(catalog: AbilityCatalog) -> void:
	# Lens329 is retired. Exercise the retained finite-branch API directly;
	# this is accounting/flight coverage, not a claim that live chemistry splits shots.
	var fixture := _world()
	var world: SimWorld = fixture.world
	var court: HexCourt = fixture.court
	var original_damage := int(CombatTuning.cast_definition(_wire(catalog, "light", "bolt")).damage)
	var light := _shot(world, court, catalog, "light", "bolt", court.origin, Vector2i(24_000_000, 0))
	var child := _split_fixture(world, light)
	check(child != null, "paid Light can be partitioned by the finite branch API")
	if child == null: return
	HexProjectileCombat.advance(world)
	equal(world.projectiles.size(), 2, "two explicitly prepared branches remain independently in flight")
	var damage_total := 0
	var branch_quantities: Array[int] = []
	var record: Dictionary = court.casts[int(court.sources[light.source_cast_id])]
	for branch: ProjectileState in world.projectiles:
		damage_total += branch.damage
		branch_quantities.append(int(record.flight_parts.get(branch.entity_id, 0)))
	branch_quantities.sort()
	equal(damage_total, original_damage, "branch damage partitions the original paid damage without multiplication")
	equal(branch_quantities, [300, 300], "one600-unit source partitions evenly between parent and child")
	equal(int(record.ledger.flight_quantity), 600, "splitting preserves aggregate finite flight stock")
	equal(court.casts.size(), 1, "direct branch split creates no cast or additional paid source")
	equal(_events(world, "hex_optical_contact").size(), 0, "low-level branch fixture does not claim a retired Lens contact")
	check(court.conservation_valid(), "parent and child retain one conserved source ledger")


func _test_constructs_use_selected_hex_cover(catalog: AbilityCatalog) -> void:
	for wire: int in [301]:
		var fixture := _world()
		var world: SimWorld = fixture.world
		var court: HexCourt = fixture.court
		var product := _form_product(world, catalog, wire, court.origin, Vector2i(0, 1000))
		_activate(world)
		var health_before := int(product.health)
		var start := court.origin - Vector2i(220_000, 0)
		var velocity := Vector2i(52_800_000, 0)
		var shot := _shot(world, court, catalog, "fire", "bolt", start, velocity)
		var expected_contact := HexProjectileCombat._product_contact(product, start, start + velocity / world.config.tick_rate, shot.radius, court.origin)
		check(not expected_contact.is_empty(), "construct recipe%d exposes continuous selected-hex cover" % wire)
		HexProjectileCombat.advance(world)
		equal(world.projectiles.size(), 0, "construct contact terminates non-optical flight for recipe%d" % wire)
		check(int(product.health) < health_before, "construct recipe%d loses observable health" % wire)
		var terminals := _events(world, "projectile_terminal", shot.entity_id)
		equal(terminals.size(), 1, "construct recipe%d emits exactly one terminal" % wire)
		if not terminals.is_empty():
			equal(terminals[0].position, expected_contact.point,
				"construct recipe%d terminates at the continuous selected-hex cover TOI" % wire)
		equal(int(court.ledger_for_source(shot.source_cast_id).deposited_quantity), 0, "new Fire element upgrades Earth cover before an independent deposit")
		equal(int(court.ledger_for_source(shot.source_cast_id).consumed_quantity), 600, "construct terminal transfers the exact600-unit source into its strict-growing union")
		check(_has_recipe(court, 302), "Fire terminal extends Earth self cover into the live Earth/Fire reaction")
		check(court.conservation_valid(), "construct recipe%d preserves paid matter" % wire)


func _test_clipped_damage_cannot_reappear_in_heavy_blast(catalog: AbilityCatalog) -> void:
	# Grounding306 is retired. Prepare a clipped packet explicitly against live
	# Earth cover to retain the independent Heavy blast cap and rounding oracle.
	# At10/15 strength the original16k direct hit is clipped by1 or4001; the
	# independent strength-scaled18k splash ceiling is12k in either case.
	for absorption: int in [1, 4001]:
		var fixture := _world()
		var world: SimWorld = fixture.world
		var court: HexCourt = fixture.court
		var product := _form_product(world, catalog, 301, court.origin, Vector2i(0, 1000))
		_activate(world)
		var start := court.origin - Vector2i(220_000, 0)
		var velocity := Vector2i(52_800_000, 0)
		var heavy := _shot(world, court, catalog, "fire", "heavy", start, velocity)
		var disposable_source := _reserve(court, catalog, "water", "bolt", court.origin + HexGrid.center(Vector2i(0, 5)))
		var weakened := court.resolve_contact(heavy.source_cast_id, disposable_source, court.origin + HexGrid.center(Vector2i(0, 5)), world.tick)
		check(bool(weakened.accepted), "real paid clash weakens Heavy before its construct contact")
		var ledger: Dictionary = court.ledger_for_source(heavy.source_cast_id)
		equal(int(ledger.remaining_strength), 10, "strength15 Heavy is reduced to10 through the real source ledger")
		equal(int(ledger.flight_quantity), 400, "partial-strength Heavy owns the cumulative400-unit flight remainder")
		var finish := start + velocity / world.config.tick_rate
		var contact := HexProjectileCombat._product_contact(product, start, finish, heavy.radius, court.origin)
		check(not contact.is_empty(), "live Earth cover has a continuous selected-hex contact")
		var splash_target := _target(world, Vector2i(contact.point) + Vector2i(-30_000, 50_000), 99)
		var definition := CombatTuning.cast_definition(heavy.source_wire_id)
		equal(heavy.damage, 24000, "clipping control starts from the current authored24k direct Heavy")
		equal(int(definition.blast_damage), 18000, "splash control uses the independently authored18k ceiling")
		var expected_after_absorb := 15999 if absorption == 1 else 11999
		var expected_splash := 12000 if absorption == 1 else 11999
		var health_before := splash_target.health
		check(health_before > expected_after_absorb, "clipping control target is nonlethal above either possible damage result")
		# Explicit full-strength packet inputs: floor(23999*10/15)=15999 and
		# floor(17999*10/15)=11999. Do not introduce a retired live absorber.
		heavy.damage = 23999 if absorption == 1 else 17999
		HexProjectileCombat.advance(world)
		equal(HexProjectileCombat.scaled_damage(heavy), expected_after_absorb, "prepared clipped packet retains its exact partial-strength damage")
		equal(health_before - splash_target.health, expected_splash, "blast obeys its own strength-scaled ceiling without restoring an absorbed damage unit")
		equal(int(product.capacity), 0, "active Earth cover does not masquerade as a retired absorption mechanic")
		equal(int(court.ledger_for_source(heavy.source_cast_id).deposited_quantity), 0, "clipped Heavy extends cover before creating a separate deposit")
		equal(int(court.ledger_for_source(heavy.source_cast_id).consumed_quantity), 600, "earlier clash200 plus union400 consume exactly the one paid source")
		check(_has_recipe(court, 302), "the surviving Fire Heavy transfers its real400-unit remainder into Earth/Fire")
		check(court.conservation_valid(), "explicit clipping and real Heavy terminal remain conserved")


func _test_low_level_suppression_requires_whole_strength_quantum(catalog: AbilityCatalog) -> void:
	# Hail317 has no authored absorption capacity. Isolate the retained finite
	# suppression API with explicit capacities; do not claim a live Hail power.
	var fixture := _world()
	var world: SimWorld = fixture.world
	var court: HexCourt = fixture.court
	var first := _form_product(world, catalog, 317, court.origin - Vector2i(180_000, 0), Vector2i(0, 1000))
	var second := _form_product(world, catalog, 317, court.origin + Vector2i(180_000, 0), Vector2i(0, 1000))
	_activate(world)
	equal(int(first.capacity), 0, "live Hail has no implicit suppression capacity")
	equal(int(second.capacity), 0, "separately formed Hail also has no implicit capacity")
	first.capacity = 119 # Fire Bolt's smallest one-strength debit is120 of600.
	second.capacity = 600
	var fire := _shot(world, court, catalog, "fire", "bolt", court.origin - Vector2i(360_000, 0), Vector2i(86_400_000, 0))
	equal(court.suppress_source(fire.source_cast_id, int(first.id)), 0, "119 units cannot pay one120-unit source quantum")
	equal(int(first.capacity), 119, "refused quantum leaves all earlier capacity intact")
	equal(int(court.ledger_for_source(fire.source_cast_id).remaining_strength), 5, "refused quantum leaves original strength untouched")
	equal(court.suppress_source(fire.source_cast_id, int(second.id)), 600, "a later sufficient budget consumes the exact finite source")
	equal(int(second.capacity), 0, "successful suppression spends exactly its explicit capacity")
	equal(int(court.ledger_for_source(fire.source_cast_id).remaining_strength), 0, "successful suppression leaves no surviving source strength")
	court.deposit_terminal({"source_cast_id":fire.source_cast_id,"projectile_id":fire.entity_id,"position":court.origin,"source_wire_id":fire.source_wire_id,"reaction_strength":fire.reaction_strength}, world.tick)
	equal(int(court.ledger_for_source(fire.source_cast_id).deposited_quantity), 0, "exhausted source refuses a second terminal allocation")
	check(court.conservation_valid(), "failed then successful lower-level suppression conserves source matter")


func _test_parent_terminal_precedes_child_clash(catalog: AbilityCatalog) -> void:
	var fixture := _world()
	var world: SimWorld = fixture.world
	var court: HexCourt = fixture.court
	# Explicit branch fixture, independent of retired Lens329 admission.
	var center := court.origin - Vector2i(100_000, 0)
	var velocity := Vector2i(52_800_000, 0)
	var parent := _shot(world, court, catalog, "light", "heavy", center, velocity)
	var child := _split_fixture(world, parent)
	check(child != null, "same-source ordering fixture partitions paid Heavy into two branches")
	if child == null: return
	var parent_finish := center + Vector2i(parent.velocity_x, parent.velocity_y) / world.config.tick_rate
	var child_finish := center + Vector2i(child.velocity_x, child.velocity_y) / world.config.tick_rate
	var parent_target := center + (parent_finish - center) * 65 / 100
	var child_clash := center + (child_finish - center) * 85 / 100
	var actor := _target(world, parent_target, 98)
	actor.radius = 10_000
	_shot(world, court, catalog, "fire", "bolt", child_clash, Vector2i.ZERO)
	HexProjectileCombat.advance(world)
	var record: Dictionary = court.casts[int(court.sources[parent.source_cast_id])]
	equal(int(record.ledger.deposited_quantity), 300, "parent terminal deposits its exact split branch before the child clash")
	equal(int(record.ledger.flight_quantity), 100, "later child clash consumes200 from the remaining300-unit flight branch")
	equal(int(record.ledger.consumed_quantity), 200, "same-tick child clash owns the exact finite debit")
	equal(record.ground_parts.size(), 1, "only the terminated parent becomes a ground part")
	var only_part: Dictionary = record.ground_parts.values()[0]
	equal(int(only_part.quantity), 300, "parent ground ownership cannot be retiled as a later flight deposit")
	equal(_events(world, "hex_clash").size(), 1, "child creates one later clash after the parent terminal")
	check(actor.health < 100_000, "parent branch reaches its earlier actor terminal")
	check(court.conservation_valid(), "parent-ground and child-flight locations conserve one source")


func _test_new_ground_contact_starts_at_terminal_time(catalog: AbilityCatalog) -> void:
	for crosses_after_terminal: bool in [false, true]:
		var fixture := _world()
		var world: SimWorld = fixture.world
		var court: HexCourt = fixture.court
		var y := court.origin.y
		var terminal := _shot(world, court, catalog, "water", "bolt", Vector2i(400_000, y), Vector2i(48_000_000, 0))
		terminal.remaining_distance = 200_000 # Deposits at x600000 and global time0.5.
		var other_start := Vector2i(300_000 if crosses_after_terminal else 500_000, y)
		var other := _shot(world, court, catalog, "fire", "bolt", other_start, Vector2i(48_000_000, 0))
		HexProjectileCombat.advance(world)
		var terminal_ledger: Dictionary = court.ledger_for_source(terminal.source_cast_id)
		var other_ledger: Dictionary = court.ledger_for_source(other.source_cast_id)
		if crosses_after_terminal:
			equal(_field_events(world).size(), 1, "flight crossing after terminal TOI contacts the newly deposited source field")
			equal(int(terminal_ledger.remaining_strength), 0, "later field contact consumes the deposited source")
			equal(int(other_ledger.remaining_strength), 0, "later field contact consumes equal incoming flight")
			check(_has_recipe(court, 310), "post-terminal Water/Fire contact forms one Steam product")
		else:
			equal(_field_events(world).size(), 0, "flight that crossed before terminal TOI is not contacted retroactively")
			equal(int(terminal_ledger.deposited_quantity), 600, "new source field exists after its terminal time")
			equal(int(other_ledger.flight_quantity), 600, "earlier crossing keeps the unrelated flight ledger intact")
		check(court.conservation_valid(), "terminal-time field ordering preserves paid matter")


func _world() -> Dictionary:
	var world := SimWorld.new(120, 91, CollisionWorld.new(1_280_000, 960_000))
	world.players.clear()
	var court := HexCourt.new()
	court.chemistry_enabled = true
	world.hex_court = court
	world.collision = HexCollisionWorld.new(world.collision)
	world.reaction_movement = world.collision
	court.collision = (world.collision as HexCollisionWorld).base_world
	world.next_projectile_id = 90_000
	return {"world": world, "court": court}


func _wire(catalog: AbilityCatalog, element: String, family: String) -> int:
	return int(catalog.ability(catalog.spell_id_at(element, family)).get("wire_id", 0))


func _reserve(court: HexCourt, catalog: AbilityCatalog, element: String, family: String, origin: Vector2i, aim: Vector2i = Vector2i(1000, 0)) -> int:
	var wire := _wire(catalog, element, family)
	var source := _next_source
	_next_source += 1
	var owner := source
	check(court.reserve_cast(owner, wire), "fixture reserves one supported paid source")
	court.commit_payment(owner)
	court.bind_release(owner, source, origin, aim, owner)
	return source


func _form_product(world: SimWorld, catalog: AbilityCatalog, recipe_wire: int, point: Vector2i, aim: Vector2i) -> Dictionary:
	var court: HexCourt = world.hex_court
	var policy := HexRecipePolicy.definition(recipe_wire)
	var elements: Array = policy.get("elements", [])
	check(elements.size() == 2, "recipe%d exposes two canonical elements" % recipe_wire)
	if elements.size() != 2:
		return {}
	var first := _reserve(court, catalog, ElementRules.id_from_wire(int(elements[0])), "bolt", point, aim)
	var second := _reserve(court, catalog, ElementRules.id_from_wire(int(elements[1])), "bolt", point, aim)
	var outcome: Dictionary = court.resolve_contact(first, second, point, 0)
	check(bool(outcome.get("accepted", false)) and int(outcome.get("recipe_wire_id", 0)) == recipe_wire,
		"distinct paid sources form recipe%d" % recipe_wire)
	return court.products.get(int(outcome.get("product_id", 0)), {})


func _activate(world: SimWorld) -> void:
	var court: HexChemistryWorld = world.hex_court
	var tick := 0
	for product: Dictionary in court.products.values():
		tick = maxi(tick, int(product.active_tick))
	world.tick = tick
	court.current_tick = tick
	check((world.collision as HexCollisionWorld).set_hex_surfaces(court, tick), "optics fixture installs trusted hex surfaces")


func _shot(world: SimWorld, court: HexCourt, catalog: AbilityCatalog, element: String, family: String, start: Vector2i, velocity: Vector2i) -> ProjectileState:
	var source := _reserve(court, catalog, element, family, start)
	var wire := _wire(catalog, element, family)
	var definition := CombatTuning.cast_definition(wire)
	var shot := ProjectileState.new(source, source, source, wire, int(definition.element_wire_id), start, velocity,
		int(definition.radius), int(definition.damage), 120)
	shot.source_cast_id = source
	shot.reaction_strength = int(definition.reaction_strength)
	world.projectiles.append(shot)
	return shot


func _split_fixture(world: SimWorld, parent: ProjectileState) -> ProjectileState:
	var court: HexCourt = world.hex_court
	var child_id := world.next_projectile_id
	check(HexProjectileCombat.sync_strength(world), "branch fixture reads actual paid strength")
	if not court.split_flight(parent.source_cast_id, parent.entity_id, child_id): return null
	world.next_projectile_id += 1
	var original_velocity := Vector2i(parent.velocity_x, parent.velocity_y)
	var child_damage := parent.damage / 2
	parent.damage -= child_damage
	var child := ProjectileState.new(child_id, parent.owner_id, parent.team_id, parent.source_wire_id, parent.element_wire_id,
		Vector2i(parent.position_x, parent.position_y), ElementChemistrySystem.rotated_fifteen(original_velocity, -1),
		parent.radius, child_damage, parent.lifetime_ticks)
	child.source_cast_id = parent.source_cast_id
	child.reaction_strength = parent.reaction_strength
	child.initial_strength = parent.initial_strength
	child.remaining_strength = parent.remaining_strength
	child.material_strength = parent.material_strength / 2
	parent.material_strength -= child.material_strength
	child.remaining_distance = parent.remaining_distance
	var parent_velocity := ElementChemistrySystem.rotated_fifteen(original_velocity, 1)
	parent.velocity_x = parent_velocity.x
	parent.velocity_y = parent_velocity.y
	world.projectiles.append(child)
	return child


func _target(world: SimWorld, point: Vector2i, id: int) -> PlayerState:
	var actor := PlayerState.new(id)
	actor.team_id = id
	actor.position_x = point.x
	actor.position_y = point.y
	actor.radius = 18_000
	actor.health = 100_000
	actor.spawn_protection_ticks = 0
	world.players.append(actor)
	return actor


func _events(world: SimWorld, kind: String, projectile_id: int = -1) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in world.combat_events:
		if String(event.get("type", "")) == kind and (projectile_id < 0 or int(event.get("projectile_id", -1)) == projectile_id):
			result.append(event)
	return result


func _field_events(world: SimWorld) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in world.combat_events:
		if String(event.get("type", "")) == "hex_clash" and String(event.get("contact_kind", "")) == "field":
			result.append(event)
	return result


func _has_recipe(court: HexCourt, wire: int) -> bool:
	for product: Dictionary in court.products.values():
		if int(product.recipe_wire_id) == wire:
			return true
	return false
