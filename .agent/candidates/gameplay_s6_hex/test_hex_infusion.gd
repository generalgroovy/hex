extends FluxTestSuite


func run() -> int:
	_test_paid_release_is_one_exact_hex()
	_test_edge_hex_and_outside_miss()
	_test_cancel_and_duplicate_are_finite()
	_test_atomic_refusals_and_capacity()
	_test_existing_reaction_and_modifier_channels()
	return finish("hex-infusion")


func _test_paid_release_is_one_exact_hex() -> void:
	var court := _court()
	var water := _wire("water", "bolt")
	check(court.reserve_infusion(1, water, 7001), "Water infusion reserves before caller payment")
	check(court.ledger_for_source(7001).is_empty() and int(court.metrics.matter_paid) == 0, "unpaid reservation cannot enter chemistry or paid accounting")
	check(court.commit_infusion_payment(1), "reserved infusion commits one finite payment")
	var players: Array[PlayerState] = []
	var projectiles: Array[ProjectileState] = []
	court.sync_flights(players, projectiles)
	check(court.held_infusions.has(1), "sync keeps a legitimate paid held payload without fabricating a projectile")
	var pre_knockback_target := court.origin + Vector2i(10_000, 0)
	var post_knockback_target := court.origin + Vector2i(80_000, 0)
	var expected_cell := HexGrid.world_to_cell(pre_knockback_target - court.origin)
	check(court.release_infusion(1, pre_knockback_target, 40), "paid infusion releases at the caller's pre-knockback point")
	var id := int(court.sources[7001])
	var record: Dictionary = court.casts[id]
	equal(record.cells, {expected_cell: HexCourt.INFUSION_BUDGET}, "release stores the entire 180 quantity in exactly one canonical cell")
	check(record.footprint.kind == HexFootprint.KIND_HEX and record.footprint.cell == expected_cell, "release authority is a real canonical hex primitive")
	check(HexFootprint.contains(record.footprint, pre_knockback_target), "released footprint contains the supplied impact")
	check(not HexFootprint.contains(record.footprint, post_knockback_target), "later knockback cannot move or enlarge the already released hex")
	check(record.ledger.flight_quantity == 0 and record.ledger.deposited_quantity == 180, "release moves the same paid stock from flight to ground")
	check(not court.held_infusions.has(1) and court.metrics.matter_paid == 180 and court.conservation_valid(), "one release clears held ownership and conserves the 180 budget")


func _test_edge_hex_and_outside_miss() -> void:
	var water := _wire("water", "bolt")
	var edge := _court()
	var exact_outer_face := edge.origin + Vector2i(416_000, 0)
	var edge_cell := HexGrid.world_to_cell(exact_outer_face - edge.origin)
	check(edge.cells.has(edge_cell), "closed outer face canonical tie belongs to the bounded court")
	check(edge.reserve_infusion(2, water, 7101) and edge.commit_infusion_payment(2), "edge fixture owns one paid payload")
	check(edge.release_infusion(2, exact_outer_face, 8), "exact closed outer face releases successfully")
	var edge_record: Dictionary = edge.casts[int(edge.sources[7101])]
	equal(edge_record.cells, {edge_cell: 180}, "edge release stores only the canonical edge hex")
	check(HexFootprint.contains(edge_record.footprint, exact_outer_face), "exact court face remains part of the released hex")

	var miss := _court()
	check(miss.reserve_infusion(3, water, 7102) and miss.commit_infusion_payment(3), "miss fixture owns one paid payload")
	check(not miss.release_infusion(3, exact_outer_face + Vector2i(1, 0), 8), "one unit outside the court terminates as a miss")
	check(miss.held_infusions.is_empty() and miss.sources.is_empty() and miss.casts.is_empty(), "outside release leaves no future held payload")
	check(miss.metrics.matter_paid == 180 and miss.metrics.matter_expired == 180 and miss.conservation_valid(), "outside release expires the paid stock once without refund")


func _test_cancel_and_duplicate_are_finite() -> void:
	var fire := _wire("fire", "bolt")
	var court := _court()
	check(court.reserve_infusion(4, fire, 7201) and court.commit_infusion_payment(4), "cancel fixture commits a paid Fire payload")
	check(court.cancel_infusion(4), "cancel expires an owned paid held payload")
	check(not court.cancel_infusion(4), "duplicate cancel is inert")
	check(court.metrics.matter_paid == 180 and court.metrics.matter_expired == 180 and court.conservation_valid(), "cancel conserves paid quantity with no refund or duplicate expiry")

	var released := _court()
	check(released.reserve_infusion(5, fire, 7202) and released.commit_infusion_payment(5), "duplicate-release fixture commits once")
	check(released.release_infusion(5, released.origin, 12), "first release succeeds")
	var before := released.state_hash()
	check(not released.release_infusion(5, released.origin, 13), "second release is rejected")
	equal(released.state_hash(), before, "duplicate release cannot add a cast, deposit, or ledger mutation")
	var record: Dictionary = released.casts[int(released.sources[7202])]
	check(released.render_regions(Vector2i.ZERO, "fire", 12)[0].phase == "ignition", "Fire infusion retains the ordinary 24-tick warning phase")
	check(released.render_regions(Vector2i.ZERO, "fire", 35)[0].phase == "ignition", "Fire remains warning-only through tick created+23")
	check(released.render_regions(Vector2i.ZERO, "fire", 36)[0].phase == "active" and int(record.expires) == 12 + HexCourt.FIRE_TICKS, "Fire activates at created+24 and keeps ordinary lifetime")


func _test_atomic_refusals_and_capacity() -> void:
	var water := _wire("water", "bolt")
	var court := _court()
	var initial := court.state_hash()
	check(not court.reserve_infusion(1, 999_999, 7301), "unsupported non-Water/Fire wire is refused")
	equal(court.state_hash(), initial, "unsupported reservation is atomic")
	check(court.reserve_infusion(1, water, 7301), "first owner/source reservation succeeds")
	var held := court.state_hash()
	check(not court.reserve_infusion(1, water, 7302), "same owner cannot reserve a second held infusion")
	check(not court.reserve_infusion(2, water, 7301), "same immutable source cannot be reserved by another owner")
	equal(court.state_hash(), held, "owner/source refusals do not partially mutate counters or maps")

	var capacity := _court()
	for index: int in range(HexCourt.MAX_PRODUCTS):
		check(capacity.reserve_infusion(index + 1, water, 7400 + index), "each admitted infusion retains one potential product slot")
	var full := capacity.state_hash()
	check(not capacity.reserve_infusion(100, water, 7500), "product reservation cap refuses another held payload")
	equal(capacity.state_hash(), full, "capacity refusal is atomic")
	check(capacity.reserved_products() == HexCourt.MAX_PRODUCTS and capacity.conservation_valid(), "held capacity accounting remains bounded and valid")


func _test_existing_reaction_and_modifier_channels() -> void:
	var water := _wire("water", "bolt")
	var fire := _wire("fire", "bolt")
	var reaction := _court()
	check(reaction.reserve_infusion(1, water, 7601) and reaction.commit_infusion_payment(1), "Water reaction payload commits")
	check(reaction.reserve_infusion(2, fire, 7602) and reaction.commit_infusion_payment(2), "Fire reaction payload commits")
	check(reaction.release_infusion(1, reaction.origin, 0), "first infusion deposits its exact hex")
	check(reaction.release_infusion(2, reaction.origin, 1), "second infusion reaches existing ground reaction rules")
	check(reaction.products.size() == 1, "overlapping Water/Fire infusion hexes create one product")
	var product: Dictionary = reaction.products[reaction.products.keys()[0]]
	check(product.recipe_wire_id == HexCourt.STEAM_WIRE and product.quantity == 360 and product.intensity == 300, "strength3/180 pair creates finite Steam310 from both exact portions")
	check(reaction.metrics.matter_paid == 360 and reaction.metrics.matter_consumed == 360 and reaction.conservation_valid(), "infusion reaction conserves both paid ledgers")

	var modifier := _court()
	_add_normal_terminal(modifier, 10, water, 7701, modifier.origin, 0)
	_add_normal_terminal(modifier, 11, fire, 7702, modifier.origin, 0)
	check(modifier.products.size() == 1, "normal source pair prepares one Steam modifier target")
	var steam: Dictionary = modifier.products[modifier.products.keys()[0]]
	var before_quantity := int(steam.quantity)
	var before_intensity := int(steam.intensity)
	check(modifier.reserve_infusion(12, fire, 7703) and modifier.commit_infusion_payment(12), "Fire modifier infusion commits separately")
	check(modifier.release_infusion(12, modifier.origin, 2), "infusion uses the existing bounded Steam modifier channel")
	check(steam.heated and int(steam.quantity) == before_quantity + 180 and int(steam.intensity) == mini(1500, before_intensity + 150), "modifier adds only its consumed strength3/quantity180 payload")
	check(modifier.casts[int(modifier.sources[7703])].cells.is_empty() and modifier.conservation_valid(), "modifier consumes the incoming ledger without fabricating a ground deposit")


func _court() -> HexCourt:
	var court := HexCourt.new()
	court.chemistry_enabled = true
	return court


func _wire(element: String, delivery: String) -> int:
	var catalog := AbilityCatalog.new()
	var ability_id := catalog.spell_id_at(element, delivery)
	return int(catalog.ability(ability_id).get("wire_id", 0))


func _add_normal_terminal(court: HexCourt, owner: int, wire: int, source: int, point: Vector2i, tick: int) -> void:
	check(court.reserve_cast(owner, wire), "normal fixture reserves a paid source")
	court.commit_payment(owner)
	court.bind_release(owner, source, court.origin)
	var definition := CombatTuning.cast_definition(wire)
	court.deposit_terminal({
		"source_cast_id": source,
		"source_wire_id": wire,
		"reaction_strength": int(definition.reaction_strength),
		"position": point,
		"direction": Vector2i(0, -1000),
	}, tick)
