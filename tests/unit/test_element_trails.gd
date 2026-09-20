extends FluxTestSuite

const Chemistry = preload("res://src/sim/chemistry/element_chemistry_system.gd")
var config := SimConfig.new(120)

func run() -> int:
	_test_roles_and_expiry()
	_test_pairs_and_promotion()
	_test_same_tick_terminal_trail_ordering()
	_test_one_payload()
	_test_spent_payload_through_optics()
	_test_paid_world_and_rapid_exclusion()
	_test_reserved_capacity_and_wall()
	_test_transactional_reclamation()
	_test_reclamation_refusals_and_protection()
	_test_reclamation_global_reservations()
	return finish("element-trails")

func _make(element: int, id: int, trail: bool, at: Vector2i = Vector2i(500000, 500000), cast: int = -1) -> ElementDepositState:
	var values: Array = []
	equal(Chemistry.deposit_terminal(values, id, id if cast < 0 else cast, 100, 1, 1, element, at, 0, config, Vector2i.RIGHT * 1000, 1000, trail), 1, "fixture creates the requested bounded material role")
	return values[0]

func _test_roles_and_expiry() -> void:
	for element: int in range(1, 9):
		var trail := _make(element, element, true)
		var terminal := _make(element, element + 100, false)
		check(trail.is_trail() and trail.validate(), "all eight narrow roles are valid canonical deposits")
		equal(trail.radius, 20000, "flight material has exactly20px radius")
		equal(terminal.radius, 40000, "full-strength terminal radius is twice trail radius")
		equal(trail.strength, 250, "trail strength is capped without multiplying the paid terminal")
		equal(trail.expiry_tick, config.milliseconds_to_ticks(Chemistry.TRAIL_LIFE_MS[element]), "element-specific trail lifetime is authoritative")
		var decoded := ElementDepositState.from_values(trail.canonical_values())
		check(decoded != null and decoded.is_trail(), "trail role survives the fifteen-value strength-aware snapshot shape")
		equal(decoded.canonical_values(), trail.canonical_values(), "all trail state survives roundtrip exactly")
		var deposits: Array = [trail]
		var events: Array = []
		Chemistry.step(deposits, [], [], null, config, trail.expiry_tick - 1, 4000, events)
		equal(deposits.size(), 1, "trail remains until last live tick")
		Chemistry.step(deposits, [], [], null, config, trail.expiry_tick, 4000, events)
		check(deposits.is_empty(), "trail disappears at exact expiry")
		var bad := trail.canonical_values()
		bad[10] = 17000
		check(ElementDepositState.from_values(bad) == null, "unregistered narrow radius is rejected")
		bad = trail.canonical_values()
		bad[11] = 251
		check(ElementDepositState.from_values(bad) == null, "a trail cannot claim full-impact strength")
		bad = trail.canonical_values()
		bad[13] = 181
		check(ElementDepositState.from_values(bad) == null, "trail cannot inherit the five-second terminal lifetime")

func _test_pairs_and_promotion() -> void:
	for first: int in range(1, 9):
		for second: int in range(first, 9):
			var trail := _make(first, 1, true)
			var other := _make(second, 2, true)
			var deposits: Array = [trail, other]
			var reactions: Array = []
			var events: Array = []
			Chemistry.step(deposits, reactions, [], null, config, 0, 4000, events)
			check(reactions.is_empty() and deposits.size() == 2, "trail + trail cannot form any of the 36 recipes")
			var terminal := _make(second, 3, false)
			terminal.created_tick = 1
			terminal.expiry_tick += 1
			deposits = [trail, terminal]
			Chemistry.step(deposits, reactions, [], null, config, 1, 4000, events)
			equal(reactions.size(), 1, "a separate terminal can consume a trail")
			check(deposits.is_empty(), "trail-assisted pairing consumes both inputs once")
			var result: ElementReactionState = reactions[0]
			var definition := Chemistry.recipe(result.recipe_wire_id)
			equal(result.recipe_wire_id, Chemistry.recipe_wire(first, second), "trail keeps its actual element identity")
			var expected_ms := int(definition.active_ms)
			if expected_ms >= 1000:
				expected_ms = expected_ms * 600 / 1000
			equal(result.decay_tick - result.active_tick, config.milliseconds_to_ticks(expected_ms), "sustained result is shorter; instant windows remain unchanged")
			check(result.validate(), "all trail-assisted recipes remain snapshot-valid")
	var same: Array = [_make(2, 10, true, Vector2i(500000, 500000), 20), _make(3, 11, false, Vector2i(500000, 500000), 20)]
	var same_reactions: Array = []
	Chemistry.step(same, same_reactions, [], null, config, 0, 4000, [])
	check(same_reactions.is_empty(), "a paid cast never reacts with its own trail or sibling payload")
	var old := _make(3, 31, true)
	var promoted: Array = [old]
	equal(Chemistry.deposit_terminal(promoted, 32, 31, 100, 1, 1, 3, Vector2i(500002, 500002), 20, config), 1, "real same-cell impact replaces the weaker trail")
	equal(promoted.size(), 1, "promotion does not duplicate material")
	equal(promoted[0].entity_id, 32, "new impact identity prevents old conductor links from being revived")
	check(not promoted[0].is_trail(), "replacement is the broad terminal role")
	var original: PackedInt64Array = promoted[0].canonical_values()
	equal(Chemistry.deposit_terminal(promoted, 33, 31, 100, 1, 1, 3, Vector2i(500003, 500003), 21, config), 0, "repeated terminal still coalesces")
	equal(promoted[0].canonical_values(), original, "duplicate contact cannot refresh promoted impact")

func _world() -> SimWorld:
	var world := SimWorld.new(120, 772, CollisionWorld.new(8000000, 8000000))
	world.player().position_x = 1000000
	world.player().position_y = 1000000
	world.player().champion_wire_id = 1
	world.player().flux_recovery_per_second = 0
	return world

func _test_same_tick_terminal_trail_ordering() -> void:
	for trail_first_id: bool in [false, true]:
		for reverse_input: bool in [false, true]:
			var trail := _make(3, 10 if trail_first_id else 11, true, Vector2i(500000, 500000), 1000)
			var terminal := _make(2, 11 if trail_first_id else 10, false, Vector2i(500000, 500000), 2000)
			equal(trail.created_tick, terminal.created_tick, "fixture overlaps distinct casts created on exactly the same tick")
			var trail_before := trail.canonical_values()
			var terminal_before := terminal.canonical_values()
			var deposits: Array = [trail, terminal] if not reverse_input else [terminal, trail]
			var reactions: Array = []
			var events: Array = []
			for tick: int in [0, 1]:
				equal(Chemistry.step(deposits, reactions, [], null, config, tick, 4000, events), 4000, "same-created-tick pair never allocates a reaction ID in either entity ordering")
				check(reactions.is_empty() and events.is_empty(), "same-created-tick terminal/trail cannot react now or become eligible merely by aging")
				equal(deposits.size(), 2, "same-tick rejection retains both real ingredients")
				equal(trail.canonical_values(), trail_before, "same-tick rejection never spends or refreshes the trail")
				equal(terminal.canonical_values(), terminal_before, "same-tick rejection never spends or refreshes the terminal")

func _test_spent_payload_through_optics() -> void:
	var world := _world()
	world.tick = 1
	world.deposits.append(_make(7, 3000, true, Vector2i(1200000, 1000000), 1000))
	var terminal := _make(2, 3001, false, Vector2i(1200000, 1000000), 2000)
	terminal.created_tick = 1
	terminal.expiry_tick += 1
	world.deposits.append(terminal)
	world.next_deposit_id = 3002
	# Archived-data low-level fixture: a formerly captured Burst projectile is
	# injected as passive state. No retired spell is equipped or live-cast.
	var shot := ProjectileState.new(1000, 1, 1, CombatTuning.LIGHT_BURST_WIRE_ID, 7, Vector2i(1500000, 1000000), Vector2i(120000, 0), 12000, 5001, 400)
	shot.source_cast_id = 1000
	world.projectiles.append(shot)
	check(world.step([]) and world.reactions.size() == 1, "production chemistry spends the still-flying Light projectile through its older trail")
	equal(shot.material_strength, 0, "optics receives a genuinely spent projectile, not a manually zeroed fixture")
	equal(shot.damage, 5001, "spending chemistry preserves the odd paid damage budget before optics")
	for wire: int in [307, 329]:
		var elements: Array = Chemistry.recipe(wire)["elements"]
		var center := Vector2i(shot.position_x, shot.position_y)
		var optical := Chemistry.form_reaction(_make(int(elements[0]), 3100, false, center), _make(int(elements[1]), 3101, false, center), 4100, 0, config)
		equal(optical.recipe_wire_id, wire, "real recipe forms the requested Prism or Lens")
		var events: Array[Dictionary] = []
		# Inspect production split output before SimWorld's reacted-cast cleanup:
		# that cleanup must not hide a child incorrectly minted with strength one.
		var survivors := CombatSystem.advance_projectiles([shot], [], config, world.collision, events, [optical], optical.active_tick, 1, {1: 1})
		check(survivors.size() == 1 and survivors[0] == shot, "spent parent survives the real combat optics path")
		equal(shot.material_strength, 0, "Prism and Lens cannot restore the parent's spent material")
		check((shot.chemistry_interaction_mask & (1 << (wire - 301))) != 0, "projectile actually traverses each optical primitive")
		var splits := events.filter(func(event: Dictionary) -> bool: return event.get("type") == "chemistry_projectile_split")
		if wire == 307:
			check(shot.velocity_x < 0, "Prism reflects the actual spent projectile")
			equal(shot.damage, 5001, "Prism preserves the spent projectile's damage")
			check(splits.is_empty(), "Prism reflection does not manufacture a child")
		else:
			equal(splits.size(), 1, "Lens produces exactly one production split child")
			if splits.size() != 1:
				continue
			var child: ProjectileState = splits[0]["projectile"]
			equal(child.material_strength, 0, "new Lens child inherits zero chemistry before any cleanup can mask a refill")
			equal(child.source_cast_id, shot.source_cast_id, "split retains the same already-spent cast identity")
			check(shot.damage > 0 and child.damage > 0, "both spent branches retain positive projectile damage")
			equal(shot.damage + child.damage, 5001, "Lens preserves the exact odd damage budget without minting damage or matter")
			check(shot.velocity_y * child.velocity_y < 0, "Lens child and parent take distinct split paths")

func _test_paid_world_and_rapid_exclusion() -> void:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "production catalog loads for trail tests")
	for element: int in range(1, 9):
		for rapid: bool in [false, true]:
			var wire := 0
			for candidate: int in abilities.runtime_wire_ids:
				var definition := CombatTuning.cast_definition(candidate)
				if definition.get("shape", "") == "projectile" and int(definition.get("element_wire_id", 0)) == element and bool(definition.get("repeat_while_held", false)) == rapid and (definition.get("projectile_rotations", []) as Array).size() <= 1 and int(definition.get("blast_radius", 0)) == 0:
					wire = candidate
					break
			check(wire > 0, "every element supplies a real Bolt and Rapid test cast")
			if wire == 0:
				continue
			var left := _world()
			var right := _world()
			check(left.player().place_proven_spell(0, wire) and right.player().place_proven_spell(0, wire), "cast is woven normally")
			var before := left.player().flux
			var observed_trail := false
			for step: int in range(200):
				var command := SimCommand.new(left.tick, 1, 0, 0, 0, SimCommand.PRESSED_SPELL_1 if step == 0 else 0, 1000, 0)
				command.aim_target_x = 1600000
				command.aim_target_y = 1000000
				check(left.step([command]) and right.step([command.copy()]), "ordinary paid cast executes in both deterministic worlds")
				check(left.last_error.is_empty(), "optional trail never steals an already-paid terminal slot")
				equal(left.state_hash(), right.state_hash(), "seeded inputs reproduce trail IDs, expiry, events and gameplay")
				var count := 0
				for deposit: ElementDepositState in left.deposits:
					if deposit.is_trail():
						count += 1
				check(count <= 4, "live trail owner role remains capped")
				observed_trail = observed_trail or count > 0
				if rapid:
					equal(count, 0, "Rapid explicitly creates no flight trails at every tick")
			check(left.player().flux < before, "trail options still require the actual positive Flux cast")
			equal(observed_trail, not rapid, "eligible Bolt seeds trails; Rapid never does")
			check(left.deposits.any(func(value: ElementDepositState) -> bool: return not value.is_trail()), "both families retain their real terminal deposit")
			var snapshot := SessionSnapshot.capture(left, {})
			check(SessionSnapshot.validate(snapshot), "current trail/terminal state has a valid network envelope")
			var replica := _world()
			check(SessionSnapshot.apply_to_world(snapshot, replica), "display replica accepts the new material role")
			equal(replica.deposits.size(), left.deposits.size(), "replica preserves deposit count; this is not mid-run authoritative continuation")

func _test_one_payload() -> void:
	var older_terminal := _make(2, 10, false)
	var new_trail := _make(3, 11, true)
	new_trail.created_tick = 1
	new_trail.expiry_tick += 1
	var values: Array = [older_terminal, new_trail]
	var results: Array = []
	Chemistry.step(values, results, [], null, config, 1, 4000, [])
	check(results.is_empty(), "passing over older terminal material never auto-cashes a new trail")
	var world := _world()
	world.tick = 1
	world.deposits.append(_make(3, 3000, true, Vector2i(1200000, 1000000), 1000))
	world.deposits.append(_make(3, 3001, true, Vector2i(1300000, 1000000), 1000))
	var impact := _make(2, 3002, false, Vector2i(1200000, 1000000), 2000)
	impact.created_tick = 1
	impact.expiry_tick += 1
	world.deposits.append(impact)
	world.next_deposit_id = 3003
	var shot := ProjectileState.new(1000, 1, 1, CombatTuning.RILLSHOT_WIRE_ID, 3, Vector2i(1500000, 1000000), Vector2i(120000, 0), 12000, 5000, 400)
	shot.source_cast_id = 1000
	world.projectiles.append(shot)
	check(world.step([]) and world.reactions.size() == 1, "new impact consumes an older flight ingredient")
	check(world.deposits.is_empty(), "all same-source fragments are spent with their one chemistry payload")
	equal(shot.material_strength, 0, "still-flying parent cannot regenerate spent chemistry")
	equal(shot.damage, 5000, "spending chemistry does not erase paid projectile damage")
	var snapshot := SessionSnapshot.capture(world, {})
	check(SessionSnapshot.validate(snapshot), "spent zero-strength projectile remains a valid display snapshot")
	var replica := _world()
	check(SessionSnapshot.apply_to_world(snapshot, replica), "spent payload reaches client presentation")
	if not replica.projectiles.is_empty():
		equal(replica.projectiles[0].material_strength, 0, "snapshot keeps the spent role, not fresh material")
	for _tick: int in range(420):
		check(world.step([]), "spent projectile continues safely beyond reaction expiry")
		check(world.deposits.is_empty(), "neither flight nor final impact refills an already-consumed payload")
	check(world.projectiles.is_empty() and world.reactions.is_empty(), "spent flight and recipe eventually expire without descendants")

func _test_reserved_capacity_and_wall() -> void:
	var world := _world()
	for index: int in range(13):
		world.deposits.append(_make(1, 3000 + index, false, Vector2i(2000000 + index * 100000, 2000000)))
	var projectile := ProjectileState.new(1000, 1, 1, CombatTuning.CINDERBOLT_WIRE_ID, 2, Vector2i(1200000, 1000000), Vector2i(320000, 0), 12000, 1000, 1)
	projectile.source_cast_id = 1000
	world.projectiles.append(projectile)
	world.next_deposit_id = 3100
	world._seed_projectile_trails()
	equal(world.deposits.size(), 13, "two remaining cast slots are not spent on optional trails")
	check(world.step([]) and world.last_error.is_empty(), "reserved one-tick terminal still executes")
	check(world.deposits.any(func(value: ElementDepositState) -> bool: return value.source_cast_id == 1000 and not value.is_trail()), "terminal exists despite saturated material owner")
	var blocked := _world()
	blocked.collision.add_obstacle(CollisionWorld.Obstacle.new(91, 1250000, 900000, 1270000, 1100000))
	var shot := ProjectileState.new(1000, 1, 1, CombatTuning.CINDERBOLT_WIRE_ID, 2, Vector2i(1100000, 1000000), Vector2i(600000, 0), 12000, 1000, 120)
	shot.source_cast_id = 1000
	blocked.projectiles.append(shot)
	for _step: int in range(40):
		check(blocked.step([]), "wall-contact trail fixture executes")
		for deposit: ElementDepositState in blocked.deposits:
			check(deposit.position_x <= 1250000, "flight/terminal material never originates behind blocking worldbone")
			if not deposit.is_trail():
				equal(deposit.position_x, 1250000, "terminal uses the exact near wall contact, not its radius-offset center")
	check(blocked.projectiles.is_empty(), "obstacle terminates the projectile before it can seed the far side")


func _reclamation_world(projectile_count: int = 12) -> SimWorld:
	var world := _world()
	world.tick = 20
	check(world.player().place_proven_spell(0, CombatTuning.CINDERBOLT_WIRE_ID), "reclamation fixture weaves a retained single-projectile Bolt")
	for index: int in range(projectile_count):
		var shot := ProjectileState.new(1000 + index, 1, 1, 145, 2, Vector2i(6000000, 6000000), Vector2i.ZERO, 10800, 9000, 600)
		shot.source_cast_id = shot.entity_id
		shot.material_strength = 0 # Existing spent dangerous shots cannot add incidental new trails.
		world.projectiles.append(shot)
	world.next_projectile_id = 1000 + projectile_count
	for index: int in range(4):
		var trail := _make(1, 3000 + index, true, Vector2i(3000000 + index * 100000, 3000000))
		trail.created_tick = [4, 2, 2, 1][index]
		world.deposits.append(trail)
	world.next_deposit_id = 3004
	return world


func _deposit_values(world: SimWorld) -> Array:
	var result: Array = []
	for deposit: ElementDepositState in world.deposits:
		result.append(deposit.canonical_values())
	return result


func _reclaim_command(world: SimWorld) -> SimCommand:
	return SimCommand.new(world.tick, 1, 0, 0, 0, SimCommand.PRESSED_SPELL_1, 1000, 0)


func _test_transactional_reclamation() -> void:
	var world := _reclamation_world()
	var reversed := _reclamation_world()
	reversed.deposits.reverse()
	var before := _deposit_values(world)
	var before_hash := world.state_hash()
	equal(world.available_cast_capacity(1).x, 0, "twelve projectiles plus four trails fill the owner material envelope")
	equal(world.available_cast_offer(1).x, 4, "read-only virtual offer adds only own eligible optional trails")
	var offer := world._cast_admission_offer(1)
	equal((offer.eligible_trails as Array).map(func(d: ElementDepositState) -> int: return d.entity_id), [3003, 3001, 3002, 3000], "oldest created tick then entity ID determines a stable candidate prefix")
	equal(_deposit_values(world), before, "offer cannot mutate any candidate or reorder live deposits")
	equal(world.state_hash(), before_hash, "offer cannot spend Flux, allocate IDs or modify canonical authority")
	var flux_before := world.player().flux
	check(world.step([_reclaim_command(world)]) and reversed.step([_reclaim_command(reversed)]), "retained paid Bolt admission executes with either deposit storage order")
	equal(world.player().pending_cast_wire_id, CombatTuning.CINDERBOLT_WIRE_ID, "offer commits only after the retained Bolt is accepted")
	equal(world.player().flux, flux_before - int(CombatTuning.cast_definition(CombatTuning.CINDERBOLT_WIRE_ID).flux_cost), "successful transaction pays the exact retained Bolt cost")
	equal(world.projectiles.size(), 12, "startup never creates a partial projectile")
	equal(world.deposits.size(), 3, "single-projectile cast reclaims exactly one of four trails")
	equal(world.deposits.map(func(d: ElementDepositState) -> int: return d.entity_id), [3000, 3001, 3002], "only the oldest eligible trail is removed")
	equal(world.available_cast_capacity(1).x, 0, "same-tick live plus pending plus retained material equals sixteen")
	var events := world.combat_events.filter(func(e: Dictionary) -> bool: return e.get("type") == "cast_trails_reclaimed")
	equal(events.size(), 1, "one internal cue describes the committed transaction")
	if events.size() == 1:
		equal(events[0].deposit_ids, PackedInt64Array([3003]), "cue lists only the committed oldest eligible ID")
		equal(events[0].count, 1, "cue reports the exact single-slot reclamation cost")
	equal(world.state_hash(), reversed.state_hash(), "reclaimed authority is independent of input deposit order")
	equal(world.combat_events, reversed.combat_events, "reclamation cue and ordinary admission events are deterministic")
	for _tick: int in range(19):
		check(world.step([]), "paid reclaimed Bolt reserves capacity until release")
		check(world.last_error.is_empty(), "reclamation never steals its paid terminal reservations")
		check(world.projectiles.size() + world.deposits.size() <= Chemistry.MAX_OWNER_DEPOSITS, "physical material never exceeds the existing owner envelope")
	check(world.projectiles.size() >= 12, "the admitted retained projectile releases without losing existing live payloads")
	# A fitting retained projectile must not cash in spare ingredients.
	for wire: int in [145, 179]:
		var fitting := _reclamation_world(10)
		check(fitting.player().place_proven_spell(0, wire), "fitting cast fixture uses a real ready spell")
		var fitting_before := _deposit_values(fitting)
		check(fitting.step([_reclaim_command(fitting)]), "fitting retained projectile cast admits normally")
		equal(_deposit_values(fitting), fitting_before, "cast with enough physical capacity never removes optional trails")
		check(not fitting.combat_events.any(func(e: Dictionary) -> bool: return e.get("type") == "cast_trails_reclaimed"), "fitting cast cannot emit a false reclamation cue")


func _test_reclamation_refusals_and_protection() -> void:
	for reason: String in ["cooldown", "flux", "control", "invalid_command"]:
		var world := _reclamation_world()
		if reason == "cooldown":
			world.player().spell_cooldown_ticks[world.player().spell_slot_index_for_wire(CombatTuning.CINDERBOLT_WIRE_ID)] = 10
			world.player()._sync_legacy_spell_cooldowns()
		elif reason == "flux":
			world.player().flux = 0
		elif reason == "control":
			world.player().control_state = PlayerState.ControlState.STUNNED
			world.player().control_ticks = 20
		var before := _deposit_values(world)
		var command := _reclaim_command(world)
		if reason == "invalid_command":
			command.tick += 1
		equal(world.step([command]), reason != "invalid_command", "refused/invalid admission reports the existing world-step contract")
		equal(_deposit_values(world), before, "cooldown, unaffordable or invalid-command refusal erases no candidate")
		check(not world.combat_events.any(func(e: Dictionary) -> bool: return e.get("type") == "cast_trails_reclaimed"), "refused cast never commits a reclamation event")
	# Protect links through formation, active and harmless-but-unexpired decay.
	for active_tick: int in [10, 40]:
		var world := _reclamation_world()
		var reaction := ElementReactionState.new()
		reaction.entity_id = 4000
		reaction.recipe_wire_id = 328
		reaction.owner_id = 1
		reaction.team_id = 1
		reaction.source_a = 9000
		reaction.source_b = 9001
		reaction.created_tick = 0
		reaction.active_tick = active_tick
		reaction.decay_tick = 90
		reaction.expiry_tick = 120
		reaction.position_x = 7000000
		reaction.position_y = 7000000
		reaction.origin_x = reaction.position_x
		reaction.origin_y = reaction.position_y
		reaction.endpoint_x = reaction.position_x
		reaction.endpoint_y = reaction.position_y
		reaction.radius = 8000
		reaction.length = 260000
		reaction.linked_deposit_ids = PackedInt64Array([3000, 3001, 3002, 3003])
		check(reaction.validate(), "protected conductor fixture obeys the canonical reaction envelope")
		world.reactions.append(reaction)
		var before := _deposit_values(world)
		equal(world.available_cast_offer(1).x, 0, "forming and active conductor ingredients are not offered for reclamation")
		check(world.step([_reclaim_command(world)]), "insufficient unlinked material refuses cleanly")
		equal(world.player().pending_cast_wire_id, 0, "linked anchors cannot fund a retained projectile cast")
		equal(_deposit_values(world), before, "refused cast preserves every protected conductor")
		reaction.decay_tick = world.tick
		equal(world.available_cast_offer(1).x, 0, "nonexpired decay also keeps its linked visual anchors")
		reaction.expiry_tick = world.tick
		equal(world.available_cast_offer(1).x, 4, "only expired reactions release their protected-link eligibility")
	var protected_world := _reclamation_world()
	protected_world.deposits[0].radius = 32000
	protected_world.deposits[0].strength = 1000
	protected_world.deposits[1].owner_id = 2
	var protected_offer := protected_world._cast_admission_offer(1)
	equal((protected_offer.eligible_trails as Array).map(func(d: ElementDepositState) -> int: return d.entity_id), [3003, 3002], "terminal matter and another owner's optional trail are never candidates")


func _test_reclamation_global_reservations() -> void:
	var world := _reclamation_world()
	var second := PlayerState.new(2)
	second.position_x = 1000000
	second.position_y = 2000000
	second.flux_recovery_per_second = 0
	check(second.place_proven_spell(0, CombatTuning.CINDERBOLT_WIRE_ID), "second owner equips the same retained Bolt")
	world.players.append(second)
	for index: int in range(12):
		var shot := ProjectileState.new(2000 + index, 2, 1, 145, 2, Vector2i(6000000, 6000000), Vector2i.ZERO, 10800, 9000, 600)
		shot.source_cast_id = shot.entity_id
		shot.material_strength = 0
		world.projectiles.append(shot)
	for index: int in range(4):
		var trail := _make(1, 4000 + index, true, Vector2i(3000000 + index * 100000, 4000000))
		trail.owner_id = 2
		trail.created_tick = [4, 2, 2, 1][index]
		world.deposits.append(trail)
	for index: int in range(96):
		var shot := ProjectileState.new(5000 + index, 99, 1, 145, 2, Vector2i(7000000, 7000000), Vector2i.ZERO, 10800, 9000, 600)
		shot.source_cast_id = shot.entity_id
		shot.material_strength = 0
		world.projectiles.append(shot)
	world.next_projectile_id = 6000
	world.next_deposit_id = 5000
	equal(world.projectiles.size() + world.deposits.size(), 128, "fixture fills the unchanged global shared material cap")
	equal(world.available_cast_offer(1).x, 4, "first owner's optional trails fund a retained projectile at the full global cap")
	equal(world.available_cast_offer(2).x, 4, "second owner's optional trails independently fund a retained projectile")
	var commands: Array[SimCommand] = [SimCommand.new(world.tick, 2, 0, 0, 0, SimCommand.PRESSED_SPELL_1), _reclaim_command(world)]
	check(world.step(commands), "reversed commands still transact in deterministic owner order")
	equal(world.player().pending_cast_wire_id, CombatTuning.CINDERBOLT_WIRE_ID, "first owner reserves one retained projectile")
	equal(second.pending_cast_wire_id, CombatTuning.CINDERBOLT_WIRE_ID, "second owner reserves one retained projectile from its own offer")
	equal(world.projectiles.size() + world.deposits.size() + 2, 128, "same-tick committed inventory and paid reservations never exceed the global cap")
	var reclaim_events := world.combat_events.filter(func(e: Dictionary) -> bool: return e.get("type") == "cast_trails_reclaimed")
	equal(reclaim_events.size(), 2, "each successful owner commits exactly one reclamation event")
	if reclaim_events.size() == 2:
		equal(reclaim_events.map(func(e: Dictionary) -> int: return int(e.owner_id)), [1, 2], "owner order remains deterministic despite reversed command input")
		equal(reclaim_events[0].deposit_ids, PackedInt64Array([3003]), "first owner spends only its oldest trail")
		equal(reclaim_events[1].deposit_ids, PackedInt64Array([4003]), "second owner spends only its oldest trail")
