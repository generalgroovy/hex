extends FluxTestSuite


const Emitter = preload("res://.godot/iteration-20261013/trail-noop/candidate_emitter.gd")
const FIRE_BOLT := CombatTuning.CINDERBOLT_WIRE_ID
const FIRE_HEAVY := 179
const FIRE_RAPID := 180


func run() -> int:
	_test_live_play_has_no_trails()
	_test_cumulative_allocation_and_terminal_remainder()
	_test_split_branches_share_one_allowance()
	_test_refusals_are_atomic_and_rapid_is_trail_free()
	_test_parts_expire_independently()
	_test_owner_and_global_caps_preserve_paid_capacity()
	return finish("hex-trail-emitter")


func _test_live_play_has_no_trails() -> void:
	# Historical direct-emitter fixtures below retain save/ledger compatibility.
	# This checks actual live paid inputs, where the emitter is no longer called.
	for wire: int in [FIRE_BOLT, FIRE_HEAVY, FIRE_RAPID]:
		var world := _world()
		var actor := world.player()
		actor.position_x = 600_000
		actor.position_y = 480_000
		actor.spawn_protection_ticks = 0
		check(actor.place_proven_spell(0, wire), "live trail-free cast equips")
		var saw_flight := false
		var saw_terminal := false
		for frame: int in 160:
			var command := SimCommand.new(world.tick, 1, 0, 0, 0, SimCommand.PRESSED_SPELL_1 if frame == 0 else 0, 1000, 0, 760_000, 480_000)
			check(world.step([command]), "live trail-free paid tick remains valid")
			saw_flight = saw_flight or not world.projectiles.is_empty()
			for record: Dictionary in world.hex_court.casts.values():
				equal(int(record.get("trail_spent", 0)), 0, "no flight payload is diverted to residue")
				for part: Dictionary in record.ground_parts.values():
					check(not bool(part.get("trail", false)), "live ground parts are impact-only")
					saw_terminal = true
			check(world.hex_court.conservation_valid(), "retired trail emission cannot mint or lose matter")
		check(saw_flight and saw_terminal, "Bolt, Heavy and Rapid retain both flight and actual impact fields")


func _test_cumulative_allocation_and_terminal_remainder() -> void:
	var world := _world()
	var center: Vector2i = world.hex_court.origin + HexGrid.center(Vector2i.ZERO)
	var shot := _bind_shot(world, 1000, 1, FIRE_BOLT, center)
	var cast_id := int(world.hex_court.sources[1000])
	var record: Dictionary = world.hex_court.casts[cast_id]
	var expected := [37, 38, 37, 38]
	for index: int in range(expected.size()):
		world.tick = index * Emitter.SAMPLE_TICKS
		shot.position_x = center.x + index * 30_000
		shot.position_y = center.y
		equal(Emitter.emit(world), 1, "sampled Bolt admits one cumulative-floor trail installment")
		var part_id := index + 1
		equal(int(record.ground_parts[part_id].quantity), expected[index], "trail installment follows 37,38,37,38 allocation")
		equal(int(record.ground_parts[part_id].created), world.tick, "trail part keeps its own creation tick")

	equal(int(record.trail_spent), 150, "one paid source spends at most150 of its600 units on optional trails")
	equal(int(record.ledger.flight_quantity), 450, "optional trails preserve exactly450 units for terminal deposit")
	equal(int(record.ledger.deposited_quantity), 150, "all optional stock is ledger-owned ground quantity")
	equal(int(record.ledger.remaining_strength), int(record.ledger.initial_strength), "moving stock into trails does not reduce reaction strength")
	equal(int(world.hex_court.metrics.matter_paid), HexChemistryWorld.MATTER_PER_CAST, "trails create no second payment")
	equal(world.hex_court.casts.size(), 1, "trails create no cloned cast")
	equal(world.hex_court.sources.size(), 1, "trails keep one source identity")
	check(world.hex_court.conservation_valid(), "four trail parts preserve the source ledger")

	var first_part: Dictionary = record.ground_parts[1]
	check(Emitter.terminal_coverage(record).is_empty(), "trail-only source has no terminal field coverage")
	check(Emitter.contact_coverage(record, int(first_part.created)).is_empty(), "same-tick terminal cannot contact a newly created trail")
	equal(Emitter.contact_coverage(record, int(first_part.created) + 1), first_part.coverage, "later terminal can contact strictly older trail coverage")

	world.tick = 4 * Emitter.SAMPLE_TICKS
	shot.position_x = center.x + 120_000
	var frozen := _mutation_snapshot(world, record)
	equal(Emitter.emit(world), 0, "fifth optional installment is refused")
	equal(_mutation_snapshot(world, record), frozen, "allowance refusal has no authority mutation")

	world.hex_court.deposit_terminal(_terminal_event(shot, Vector2i(shot.position_x, shot.position_y)), world.tick)
	equal(int(record.ledger.flight_quantity), 0, "terminal receives every unit left in flight")
	equal(int(record.ledger.deposited_quantity), 600, "trail and terminal parts retain the whole paid600 ledger")
	equal(int(record.ground_parts[5].quantity), 450, "terminal part owns the exact reserved remainder")
	check(not bool(record.ground_parts[5].trail), "reserved remainder is a terminal part, not another trail")
	check(not Emitter.terminal_coverage(record).is_empty(), "terminal helper exposes only real terminal coverage")
	check(world.hex_court.conservation_valid(), "terminal completion remains conserved")


func _test_split_branches_share_one_allowance() -> void:
	var world := _world()
	var center: Vector2i = world.hex_court.origin + HexGrid.center(Vector2i.ZERO)
	var parent := _bind_shot(world, 2000, 1, FIRE_HEAVY, center)
	check(world.hex_court.split_flight(2000, 2000, 2001), "fixture partitions one source into two flight branches")
	var child := _projectile(2001, 1, FIRE_HEAVY, center)
	child.source_cast_id = 2000
	world.projectiles.append(child)
	var samples := [
		{"tick": 0, "shot": parent, "x": 0},
		{"tick": 7, "shot": child, "x": 30_000},
		{"tick": 8, "shot": parent, "x": 60_000},
		{"tick": 15, "shot": child, "x": 90_000},
	]
	for sample: Dictionary in samples:
		world.tick = int(sample.tick)
		var active: ProjectileState = sample.shot
		active.position_x = center.x + int(sample.x)
		active.position_y = center.y
		equal(Emitter.emit(world), 1, "one sampled split branch advances the source-wide allowance")
	var record: Dictionary = world.hex_court.casts[int(world.hex_court.sources[2000])]
	equal(int(record.trail_spent), 150, "split siblings share one150-unit source cap")
	equal(record.flight_parts, {2000: 226, 2001: 224}, "branches retain300 minus their37+37 or38+38 installments")
	equal(int(record.ledger.flight_quantity), 450, "split flight aggregate never crosses the terminal reserve")
	equal(record.ground_parts.size(), 4, "split source still creates at most four trail parts")
	equal(world.hex_court.casts.size(), 1, "split trails do not clone source authority")
	world.tick = 16
	parent.position_x = center.x + 120_000
	var frozen := _mutation_snapshot(world, record)
	equal(Emitter.emit(world), 0, "either sibling is refused after the shared cap")
	equal(_mutation_snapshot(world, record), frozen, "shared-cap refusal is atomic")
	check(world.hex_court.conservation_valid(), "split trail source remains conserved")


func _test_refusals_are_atomic_and_rapid_is_trail_free() -> void:
	var rapid_world := _world()
	var center: Vector2i = rapid_world.hex_court.origin + HexGrid.center(Vector2i.ZERO)
	_bind_shot(rapid_world, 3000, 1, FIRE_RAPID, center)
	var rapid_record: Dictionary = rapid_world.hex_court.casts[int(rapid_world.hex_court.sources[3000])]
	var frozen := _mutation_snapshot(rapid_world, rapid_record)
	equal(Emitter.emit(rapid_world), 0, "Rapid is explicitly trail-free")
	equal(_mutation_snapshot(rapid_world, rapid_record), frozen, "Rapid exclusion consumes no stock or IDs")

	var bolt_world := _world()
	var shot := _bind_shot(bolt_world, 3008, 1, FIRE_BOLT, center)
	bolt_world.tick = 0
	equal(Emitter.emit(bolt_world), 1, "eligible Bolt seeds its first trail")
	var record: Dictionary = bolt_world.hex_court.casts[int(bolt_world.hex_court.sources[3008])]
	frozen = _mutation_snapshot(bolt_world, record)
	equal(Emitter.emit(bolt_world), 0, "duplicate sample at the same point is refused")
	equal(_mutation_snapshot(bolt_world, record), frozen, "duplicate refusal has no mutation")
	bolt_world.tick = 8
	shot.position_x = center.x + 27_999
	frozen = _mutation_snapshot(bolt_world, record)
	equal(Emitter.emit(bolt_world), 0, "sample closer than28px is refused")
	equal(_mutation_snapshot(bolt_world, record), frozen, "spacing refusal has no mutation")
	bolt_world.tick = 16
	shot.position_x = center.x + 1_000_000
	frozen = _mutation_snapshot(bolt_world, record)
	equal(Emitter.emit(bolt_world), 0, "sample center outside trusted cells is refused")
	equal(_mutation_snapshot(bolt_world, record), frozen, "outside-court refusal has no mutation")


func _test_parts_expire_independently() -> void:
	var world := _world()
	var center: Vector2i = world.hex_court.origin + HexGrid.center(Vector2i.ZERO)
	var shot := _bind_shot(world, 3200, 1, FIRE_BOLT, center)
	world.tick = 0
	equal(Emitter.emit(world), 1, "first timed trail deposits")
	world.tick = 8
	shot.position_x += 30_000
	equal(Emitter.emit(world), 1, "second timed trail deposits")
	var record: Dictionary = world.hex_court.casts[int(world.hex_court.sources[3200])]
	var first_expiry := int(record.ground_parts[1].expiry_tick)
	var second_expiry := int(record.ground_parts[2].expiry_tick)
	equal(second_expiry - first_expiry, 8, "equal-element trail lifetimes retain independent creation offsets")
	world.hex_court.expire_at(first_expiry)
	check(not record.ground_parts.has(1), "first trail expires at its own exact tick")
	check(record.ground_parts.has(2), "later sibling survives the first expiry")
	equal(int(record.ground_parts[2].expiry_tick), second_expiry, "sibling expiry is not refreshed or shortened")
	check(world.hex_court.conservation_valid(), "independent trail expiry preserves conservation")


func _test_owner_and_global_caps_preserve_paid_capacity() -> void:
	var owner_world := _world()
	var center: Vector2i = owner_world.hex_court.origin + HexGrid.center(Vector2i.ZERO)
	for index: int in range(5):
		_bind_shot(owner_world, 4000 + index * 8, 1, FIRE_BOLT, center)
	equal(Emitter.emit(owner_world), Emitter.MAX_OWNER_TRAILS, "one owner admits at most four live trail parts")
	var refused_source := 4000 + 4 * 8
	var refused_record: Dictionary = owner_world.hex_court.casts[int(owner_world.hex_court.sources[refused_source])]
	equal(int(refused_record.ledger.flight_quantity), 600, "owner-cap refusal preserves the untouched paid branch")
	equal(int(refused_record.get("trail_spent", 0)), 0, "owner-cap refusal spends no optional allowance")
	equal(int(owner_world.hex_court.metrics.matter_paid), 5 * 600, "owner cap creates no extra payment")
	check(owner_world.hex_court.conservation_valid(), "owner-capped fixtures preserve every paid ledger")

	var global_world := _world()
	var first: ProjectileState = null
	for index: int in range(Emitter.MAX_TRAILS):
		var shot := _bind_shot(global_world, 5000 + index * 8, index + 1, FIRE_BOLT, center)
		if index == 0:
			first = shot
	equal(global_world.hex_court.reserved_products(), Emitter.MAX_TRAILS, "fixture fills the existing paid admission envelope")
	equal(Emitter.emit(global_world), Emitter.MAX_TRAILS, "global trail cap admits exactly32 live parts")
	equal(global_world.hex_court.reserved_products(), Emitter.MAX_TRAILS, "trail parts consume no extra cast or product reservation")
	global_world.tick = 8
	first.position_x += 30_000
	var first_record: Dictionary = global_world.hex_court.casts[int(global_world.hex_court.sources[first.source_cast_id])]
	var frozen := _mutation_snapshot(global_world, first_record)
	equal(Emitter.emit(global_world), 0, "thirty-third live trail is refused globally")
	equal(_mutation_snapshot(global_world, first_record), frozen, "global-cap refusal has no mutation")
	equal(int(first_record.ledger.flight_quantity), 563, "cap refusal leaves the source's terminal stock untouched")
	check(global_world.hex_court.conservation_valid(), "global trail cap preserves all32 paid ledgers")


func _world() -> SimWorld:
	var world := SimWorld.new(120, 73, CollisionWorld.new(1_280_000, 960_000))
	var court := HexCourt.new()
	court.chemistry_enabled = true
	world.hex_court = court
	return world


func _bind_shot(world: SimWorld, entity_id: int, owner: int, wire: int, position: Vector2i) -> ProjectileState:
	var authority: HexChemistryWorld = world.hex_court
	check(authority.reserve_cast(owner, wire), "fixture reserves one supported source")
	authority.commit_payment(owner)
	authority.bind_release(owner, entity_id, position, Vector2i(1000, 0), owner)
	var shot := _projectile(entity_id, owner, wire, position)
	world.projectiles.append(shot)
	return shot


func _projectile(entity_id: int, owner: int, wire: int, position: Vector2i) -> ProjectileState:
	var definition := CombatTuning.cast_definition(wire)
	var shot := ProjectileState.new(entity_id, owner, owner, wire, int(definition.element_wire_id),
		position, Vector2i(120_000, 0), int(definition.radius), int(definition.damage), 600)
	shot.source_cast_id = entity_id
	shot.reaction_strength = int(definition.reaction_strength)
	shot.material_strength = 1000
	return shot


func _terminal_event(shot: ProjectileState, position: Vector2i) -> Dictionary:
	return {
		"type": "projectile_terminal",
		"projectile_id": shot.entity_id,
		"source_cast_id": shot.source_cast_id,
		"source_wire_id": shot.source_wire_id,
		"owner_id": shot.owner_id,
		"team_id": shot.team_id,
		"element_wire_id": shot.element_wire_id,
		"position": position,
		"direction": Vector2i(1000, 0),
		"strength": shot.material_strength,
		"reaction_strength": shot.reaction_strength,
	}


func _mutation_snapshot(world: SimWorld, record: Dictionary) -> Dictionary:
	return {
		"record": record.duplicate(true),
		"next_ground_part_id": int(world.hex_court.next_ground_part_id),
		"value_revision": int(world.hex_court.value_revision),
		"metrics": world.hex_court.metrics.duplicate(true),
	}
