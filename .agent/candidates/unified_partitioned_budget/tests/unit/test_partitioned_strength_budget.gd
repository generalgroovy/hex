extends FluxTestSuite


const Budget = preload("res://src/sim/combat/strength_budget.gd")


func run() -> int:
	_test_strict_contract_unchanged()
	_test_partitioned_constructor_and_immutable_mode()
	_test_no_expiry_cumulative_contacts_and_mixed_locations()
	_test_partial_expiry_before_and_after_contact()
	_test_terminal_expiry_and_normal_dispatch()
	_test_interval_and_epoch_prefix_counterexamples()
	_test_atomic_quantity_refusals()
	_test_tiny_zero_quantity_transition()
	_test_exhaustive_bounded_step_sequences()
	return finish("partitioned-strength-budget")


func _test_strict_contract_unchanged() -> void:
	var strict: Dictionary = Budget.make(1, 15, 600)
	check(not strict.has("partitioned") and not strict.has("epoch_strength") and not strict.has("epoch_base_consumed"), "original constructor retains its exact strict schema")
	equal((strict[&"_strength_budget_provenance"] as PackedInt64Array).size(), 3, "strict provenance retains its original three immutable lanes")
	var five: Dictionary = Budget.make(2, 5, 600)
	var first: Dictionary = Budget.consume_pair(strict, five)
	equal(int(first.first.consumed_quantity), 200, "strict 15-to-10 contact still consumes 200")
	var three: Dictionary = Budget.make(3, 3, 600)
	var second: Dictionary = Budget.consume_pair(strict, three)
	equal(int(second.first.consumed_quantity), 120, "strict 10-to-7 contact still consumes 120")
	check(Budget.validate(strict), "existing strict cumulative record remains valid")
	var strict_partial := Budget.make(4, 6, 600)
	var before := strict_partial.duplicate(true)
	equal(Budget.deposit_quantity(strict_partial, 100), -1, "strict mode refuses a partial deposit")
	check(strict_partial == before, "strict partial-deposit refusal is atomic")
	var strict_full := Budget.make(5, 6, 600)
	equal(Budget.deposit_quantity(strict_full, 600), 600, "exact-quantity API retains the strict all-flight deposit transition")
	equal(Budget.expire_quantity(strict_full, 600, false), 600, "exact-quantity API retains the strict all-live expiry transition")
	check(Budget.validate(strict_full), "strict record reached through exact-quantity full moves still validates")


func _test_partitioned_constructor_and_immutable_mode() -> void:
	var record: Dictionary = Budget.make_partitioned(10, 15, 600)
	check(Budget.validate(record), "bounded partitioned constructor creates a valid ledger")
	check(bool(record.partitioned), "partitioned mode is explicit")
	equal(int(record.epoch_strength), 15, "first epoch begins at initial strength")
	equal(int(record.epoch_base_consumed), 0, "first epoch begins before any consumption")
	equal((record[&"_strength_budget_provenance"] as PackedInt64Array), PackedInt64Array([10, 15, 600, 1]), "partitioned provenance records identity, budget and explicit mode")
	check(Budget.make_partitioned(10, 15, 601).is_empty(), "partitioned budget above the reviewed 600-unit bound rejects")
	check(Budget.make_partitioned(10, 15, 0).is_empty(), "partitioned zero budget rejects")
	check(Budget.make_partitioned(10, 16, 600).is_empty(), "partitioned strength above fifteen rejects")

	var changed := record.duplicate(true)
	changed.partitioned = false
	check(not Budget.validate(changed), "changing partitioned mode to strict conflicts with immutable provenance")
	changed = record.duplicate(true)
	changed.erase("partitioned")
	check(not Budget.validate(changed), "erasing partitioned mode cannot reinterpret a partitioned ledger as strict")
	changed = Budget.make(11, 5, 50)
	changed.partitioned = true
	check(not Budget.validate(changed), "changing a strict ledger to partitioned rejects without partition provenance and epoch fields")
	changed = record.duplicate(true)
	var changed_provenance: PackedInt64Array = changed[&"_strength_budget_provenance"]
	changed_provenance[3] = 0
	changed[&"_strength_budget_provenance"] = changed_provenance
	check(not Budget.validate(changed), "partitioned provenance mode lane is immutable")


func _test_no_expiry_cumulative_contacts_and_mixed_locations() -> void:
	var source := Budget.make_partitioned(20, 15, 600)
	equal(Budget.deposit_quantity(source, 400), 400, "partial deposit creates one mixed-location ledger")
	equal(Vector2i(int(source.flight_quantity), int(source.deposited_quantity)), Vector2i(200, 400), "partial deposit conserves both live locations")
	var strict_five := Budget.make(21, 5, 600)
	var first := Budget.consume_pair(source, strict_five)
	check(bool(first.accepted), "partitioned and strict ledgers can participate in one mixed-mode pair")
	equal(int(first.first.consumed_quantity), 200, "partitioned no-expiry 15-to-10 contact consumes the original 200")
	equal(Vector2i(int(source.flight_quantity), int(source.deposited_quantity)), Vector2i(0, 400), "one cumulative delta debits the stable flight prefix before ground stock")
	var partitioned_three := Budget.make_partitioned(22, 3, 90)
	var second := Budget.consume_pair(source, partitioned_three)
	equal(int(second.first.consumed_quantity), 120, "partitioned no-expiry 10-to-7 contact consumes the next 120")
	equal(Vector2i(int(source.flight_quantity), int(source.deposited_quantity)), Vector2i(0, 280), "after flight prefix exhaustion the same delta continues through ground")
	equal(int(source.consumed_quantity), 320, "mixed location does not change cumulative source consumption")
	check(Budget.validate(source), "mixed-location cumulative source validates")


func _test_partial_expiry_before_and_after_contact() -> void:
	var source := Budget.make_partitioned(30, 15, 600)
	equal(Budget.deposit_quantity(source, 200), 200, "fixture places stock in flight and ground")
	equal(Budget.expire_quantity(source, 50, true), 50, "partial flight expiry before contact succeeds")
	equal(Vector2i(int(source.flight_quantity), int(source.deposited_quantity)), Vector2i(350, 200), "partial flight expiry touches only its selected location")
	equal(Vector3i(int(source.expired_quantity), int(source.epoch_base_consumed), int(source.epoch_strength)), Vector3i(50, 0, 15), "pre-contact expiry rebases the epoch without spending strength")
	check(Budget.validate(source), "pre-contact partial expiry validates")

	var five := Budget.make_partitioned(31, 5, 75)
	var first := Budget.consume_pair(source, five)
	equal(int(first.first.consumed_quantity), 183, "post-expiry contact uses floor(550*5/15) exactly")
	equal(Vector2i(int(source.flight_quantity), int(source.deposited_quantity)), Vector2i(167, 200), "post-expiry debit consumes one stable flight prefix")
	equal(Budget.expire_quantity(source, 50, false), 50, "partial ground expiry after contact succeeds")
	equal(Vector3i(int(source.expired_quantity), int(source.epoch_base_consumed), int(source.epoch_strength)), Vector3i(100, 183, 10), "post-contact expiry records the consumed base and current strength")
	check(Budget.validate(source), "post-contact rebase validates")

	var three := Budget.make(32, 3, 60)
	var second := Budget.consume_pair(source, three)
	equal(int(second.first.consumed_quantity), 95, "next epoch consumes floor(317*3/10) from its rebased budget")
	equal(int(source.remaining_strength), 7, "next epoch subtracts only matched strength")
	equal(int(source.consumed_quantity), 278, "global consumed sink accumulates both epochs")
	check(Budget.validate(source), "multiple contacts around partial expiries preserve the exact epoch equation")


func _test_terminal_expiry_and_normal_dispatch() -> void:
	var direct := Budget.make_partitioned(40, 8, 80)
	equal(Budget.expire_quantity(direct, 80, true), 80, "all-live explicit quantity expiry terminates a pure-flight source")
	equal(Vector3i(int(direct.remaining_strength), int(direct.epoch_strength), int(direct.epoch_base_consumed)), Vector3i.ZERO, "terminal partitioned record uses canonical zero epoch fields")
	check(int(direct.consumed_quantity) + int(direct.expired_quantity) == int(direct.budget) and Budget.validate(direct), "terminal partitioned expiry closes the whole budget")

	var mixed := Budget.make_partitioned(41, 10, 100)
	Budget.deposit_quantity(mixed, 40)
	equal(Budget.expire(mixed), 100, "normal expiry dispatch consumes both partitioned live locations atomically")
	check(Budget.validate(mixed), "normal partitioned expiry produces canonical terminal state")
	var deposited := Budget.make_partitioned(42, 7, 70)
	equal(Budget.deposit(deposited), 70, "normal deposit dispatch moves all partitioned flight stock")
	equal(Vector2i(int(deposited.flight_quantity), int(deposited.deposited_quantity)), Vector2i(0, 70), "normal partitioned deposit preserves its historic all-stock behavior")
	equal(Budget.consume_remaining(deposited), 70, "normal remaining-consumption dispatch exhausts a partitioned source")
	check(Budget.validate(deposited), "normal remaining consumption closes partitioned epoch canonically")


func _test_interval_and_epoch_prefix_counterexamples() -> void:
	var between := Budget.make_partitioned(50, 3, 10)
	between.remaining_strength = 2
	between.flight_quantity = 6
	between.consumed_quantity = 4
	check(not Budget.validate(between), "global conservation cannot hide a consumed quantity between exact cumulative intervals")

	var upper := Budget.make_partitioned(51, 15, 600)
	upper.remaining_strength = 10
	upper.epoch_strength = 10
	upper.epoch_base_consumed = 201
	upper.consumed_quantity = 201
	upper.flight_quantity = 399
	check(not Budget.validate(upper), "epoch base cannot exceed the original cumulative prefix K0")
	var lower := Budget.make_partitioned(52, 15, 600)
	lower.remaining_strength = 10
	lower.epoch_strength = 10
	lower.epoch_base_consumed = 189
	lower.consumed_quantity = 189
	lower.expired_quantity = 10
	lower.flight_quantity = 401
	check(not Budget.validate(lower), "epoch base cannot fall below K0 minus all prior expiry")


func _test_atomic_quantity_refusals() -> void:
	var record := Budget.make_partitioned(60, 9, 90)
	Budget.deposit_quantity(record, 30)
	for bad_quantity: Variant in [0, -1, 61, 1.0, "1"]:
		var before := record.duplicate(true)
		equal(Budget.deposit_quantity(record, bad_quantity), -1, "invalid partial-deposit quantity rejects")
		check(record == before, "partial-deposit rejection is atomic")
	for refusal: Array in [[0, true], [-1, true], [61, true], [31, false], [1.0, true], [1, 1]]:
		var before := record.duplicate(true)
		equal(Budget.expire_quantity(record, refusal[0], refusal[1]), -1, "invalid partial-expiry request rejects")
		check(record == before, "partial-expiry rejection is atomic")
	var invalid := record.duplicate(true)
	invalid.flight_quantity = -1
	var invalid_before := invalid.duplicate(true)
	equal(Budget.deposit_quantity(invalid, 1), -1, "invalid ledger rejects before partial deposit")
	check(invalid == invalid_before, "invalid-ledger refusal does not repair or mutate data")
	var peer := Budget.make_partitioned(61, 2, 20)
	var peer_before := peer.duplicate(true)
	var pair_result := Budget.consume_pair(invalid, peer)
	check(not bool(pair_result.accepted) and invalid == invalid_before and peer == peer_before, "pair rejection remains atomic across partitioned ledgers")


func _test_tiny_zero_quantity_transition() -> void:
	var sparse := Budget.make_partitioned(70, 3, 2)
	var one := Budget.make_partitioned(71, 1, 1)
	var result := Budget.consume_pair(sparse, one)
	check(bool(result.accepted) and int(result.matched_strength) == 1, "positive partitioned clash accepts across a zero rounded source increment")
	equal(int(result.first.consumed_quantity), 0, "zero-quantity source portion stays explicit")
	equal(int(sparse.remaining_strength), 2, "zero quantity does not cancel the matched strength transition")
	check(Budget.validate(sparse), "tiny-budget zero increment remains exact and conserved")


func _test_exhaustive_bounded_step_sequences() -> void:
	var source_id := 1000
	for initial_strength: int in range(1, 16):
		for original_budget: int in range(1, 31):
			source_id += 1
			var record := Budget.make_partitioned(source_id, initial_strength, original_budget)
			if original_budget >= 2:
				var split: int = original_budget >> 1
				equal(Budget.deposit_quantity(record, split), split, "bounded sequence creates a deterministic mixed split")
			if original_budget >= 3:
				var expiry_from_flight := int(record.flight_quantity) > 0
				equal(Budget.expire_quantity(record, 1, expiry_from_flight), 1, "bounded sequence accepts one proper partial expiry")
			check(Budget.validate(record), "bounded split/expiry prefix validates")
			while int(record.remaining_strength) > 0:
				source_id += 1
				var unit := Budget.make_partitioned(source_id, 1, 1)
				var result := Budget.consume_pair(record, unit)
				check(bool(result.accepted) and int(result.matched_strength) == 1, "bounded one-strength transition accepts")
				check(Budget.validate(record), "every bounded cumulative step validates")
				equal(int(record.flight_quantity) + int(record.deposited_quantity) + int(record.consumed_quantity) + int(record.expired_quantity), original_budget, "every bounded step conserves the original budget")
			check(int(record.flight_quantity) == 0 and int(record.deposited_quantity) == 0, "bounded sequence has no live stock after strength exhaustion")
			check(int(record.epoch_strength) == 0 and int(record.epoch_base_consumed) == 0, "bounded terminal sequence canonicalizes epoch fields")
			check(int(record.consumed_quantity) + int(record.expired_quantity) == original_budget, "bounded terminal sinks close the budget")
