extends RefCounted

const StrengthBudgetCandidate = preload("strength_budget.gd")
const FIXTURE_BUDGET: int = 600

var _assertions: int = 0
var _failures: Array[String] = []


func run() -> Dictionary:
	_test_chain_15_to_10_to_7()
	_test_equal_and_unequal_contacts()
	_test_nondivisible_cumulative_rounding()
	_test_rejections_are_atomic()
	_test_deposit_then_field_consumption()
	_test_expiry_and_conservation()
	_test_single_source_external_consumption()
	_test_provenance_and_bounds()
	return {
		"passed": _failures.is_empty(),
		"assertions": _assertions,
		"failures": _failures.duplicate(),
	}


func _test_chain_15_to_10_to_7() -> void:
	var source: Dictionary = StrengthBudgetCandidate.make(1, 15, FIXTURE_BUDGET)
	var five: Dictionary = StrengthBudgetCandidate.make(2, 5, FIXTURE_BUDGET)
	var first_contact: Dictionary = StrengthBudgetCandidate.consume_pair(source, five)
	_check(first_contact[&"accepted"], "15->10 first contact accepted")
	_check(first_contact[&"matched_strength"] == 5, "15->10 matches five strength")
	_check(source[&"remaining_strength"] == 10, "15->10 remaining strength")
	_check(first_contact[&"first"][&"consumed_quantity"] == 200, "15->10 consumes 200 quantity")
	_check(five[&"consumed_quantity"] == FIXTURE_BUDGET, "exhausted five-strength source consumes its budget")

	var three: Dictionary = StrengthBudgetCandidate.make(3, 3, FIXTURE_BUDGET)
	var second_contact: Dictionary = StrengthBudgetCandidate.consume_pair(source, three)
	_check(second_contact[&"accepted"], "10->7 second contact accepted")
	_check(second_contact[&"matched_strength"] == 3, "10->7 matches three strength")
	_check(source[&"remaining_strength"] == 7, "10->7 remaining strength")
	_check(second_contact[&"first"][&"consumed_quantity"] == 120, "10->7 consumes next 120 quantity")
	_check(second_contact[&"source_portions"].size() == 2, "one contact result reports exactly two source portions")
	_check(source[&"consumed_quantity"] == 320, "successive contacts charge cumulative quantity")
	_check(StrengthBudgetCandidate.validate(source), "15->10->7 record remains valid")


func _test_equal_and_unequal_contacts() -> void:
	var equal_a: Dictionary = StrengthBudgetCandidate.make(10, 7, FIXTURE_BUDGET)
	var equal_b: Dictionary = StrengthBudgetCandidate.make(11, 7, FIXTURE_BUDGET)
	var equal_result: Dictionary = StrengthBudgetCandidate.consume_pair(equal_a, equal_b)
	_check(equal_result[&"matched_strength"] == 7, "equal contact matches all strength")
	_check(equal_result[&"first"][&"exhausted"] and equal_result[&"second"][&"exhausted"], "equal contact exhausts both")
	_check(equal_a[&"consumed_quantity"] == FIXTURE_BUDGET and equal_b[&"consumed_quantity"] == FIXTURE_BUDGET, "equal contact consumes both finite budgets")

	var strong: Dictionary = StrengthBudgetCandidate.make(12, 9, FIXTURE_BUDGET)
	var weak: Dictionary = StrengthBudgetCandidate.make(13, 4, FIXTURE_BUDGET)
	var unequal_result: Dictionary = StrengthBudgetCandidate.consume_pair(strong, weak)
	_check(unequal_result[&"matched_strength"] == 4, "unequal contact uses minimum strength")
	_check(strong[&"remaining_strength"] == 5 and weak[&"remaining_strength"] == 0, "unequal post strengths are conserved")
	_check(unequal_result[&"first"][&"consumed_strength"] == 4, "strong source portion reports consumed strength")
	_check(weak[&"consumed_quantity"] == FIXTURE_BUDGET, "weak exhausted source consumes full budget")
	_check(StrengthBudgetCandidate.validate(strong) and StrengthBudgetCandidate.validate(weak), "unequal records remain valid")


func _test_nondivisible_cumulative_rounding() -> void:
	var source: Dictionary = StrengthBudgetCandidate.make(20, 3, 10)
	var one_a: Dictionary = StrengthBudgetCandidate.make(21, 1, 10)
	var one_b: Dictionary = StrengthBudgetCandidate.make(22, 1, 10)
	var one_c: Dictionary = StrengthBudgetCandidate.make(23, 1, 10)
	var first_result: Dictionary = StrengthBudgetCandidate.consume_pair(source, one_a)
	var second_result: Dictionary = StrengthBudgetCandidate.consume_pair(source, one_b)
	var third_result: Dictionary = StrengthBudgetCandidate.consume_pair(source, one_c)
	_check(first_result[&"first"][&"consumed_quantity"] == 3, "first nondivisible third rounds cumulatively to 3")
	_check(second_result[&"first"][&"consumed_quantity"] == 3, "second nondivisible third advances from 3 to 6")
	_check(third_result[&"first"][&"consumed_quantity"] == 4, "last nondivisible third closes budget exactly")
	_check(source[&"consumed_quantity"] == 10 and source[&"flight_quantity"] == 0, "nondivisible contacts neither clone nor lose quantity")
	_check(StrengthBudgetCandidate.validate(source), "nondivisible exhausted record validates")

	# A positive strength clash can legitimately charge zero quantity before a
	# later cumulative boundary when budget is smaller than initial strength.
	var sparse: Dictionary = StrengthBudgetCandidate.make(24, 3, 2)
	var sparse_one: Dictionary = StrengthBudgetCandidate.make(25, 1, 2)
	var sparse_result: Dictionary = StrengthBudgetCandidate.consume_pair(sparse, sparse_one)
	_check(sparse_result[&"accepted"] and sparse_result[&"matched_strength"] == 1, "positive clash is accepted across a zero rounding increment")
	_check(sparse_result[&"first"][&"consumed_quantity"] == 0, "cumulative formula preserves an initial zero quantity increment")
	_check(StrengthBudgetCandidate.validate(sparse), "zero-increment strength loss remains valid")


func _test_rejections_are_atomic() -> void:
	var first: Dictionary = StrengthBudgetCandidate.make(30, 8, FIXTURE_BUDGET)
	var same_source: Dictionary = StrengthBudgetCandidate.make(30, 3, FIXTURE_BUDGET)
	var first_before: Dictionary = first.duplicate(true)
	var same_before: Dictionary = same_source.duplicate(true)
	var same_result: Dictionary = StrengthBudgetCandidate.consume_pair(first, same_source)
	_check(not same_result[&"accepted"] and same_result[&"reason"] == &"same_source", "same-source contact is rejected")
	_check(first == first_before and same_source == same_before, "same-source rejection does not partially mutate")

	var invalid: Dictionary = StrengthBudgetCandidate.make(31, 2, FIXTURE_BUDGET)
	invalid[&"flight_quantity"] = -1
	first_before = first.duplicate(true)
	var invalid_before: Dictionary = invalid.duplicate(true)
	var invalid_result: Dictionary = StrengthBudgetCandidate.consume_pair(first, invalid)
	_check(not invalid_result[&"accepted"] and invalid_result[&"reason"] == &"invalid", "invalid participant is rejected")
	_check(first == first_before and invalid == invalid_before, "invalid rejection does not partially mutate")

	var exhausted: Dictionary = StrengthBudgetCandidate.make(32, 1, FIXTURE_BUDGET)
	var exhaust_partner: Dictionary = StrengthBudgetCandidate.make(33, 1, FIXTURE_BUDGET)
	StrengthBudgetCandidate.consume_pair(exhausted, exhaust_partner)
	first_before = first.duplicate(true)
	var exhausted_before: Dictionary = exhausted.duplicate(true)
	var zero_result: Dictionary = StrengthBudgetCandidate.consume_pair(first, exhausted)
	_check(not zero_result[&"accepted"] and zero_result[&"reason"] == &"exhausted", "zero-strength participant is rejected")
	_check(first == first_before and exhausted == exhausted_before, "zero-strength rejection does not partially mutate")


func _test_deposit_then_field_consumption() -> void:
	var field: Dictionary = StrengthBudgetCandidate.make(40, 12, FIXTURE_BUDGET)
	var pre_strength: int = field[&"remaining_strength"]
	_check(StrengthBudgetCandidate.deposit(field) == FIXTURE_BUDGET, "deposit moves entire flight stock")
	_check(field[&"flight_quantity"] == 0 and field[&"deposited_quantity"] == FIXTURE_BUDGET, "deposit changes only stock location")
	_check(field[&"remaining_strength"] == pre_strength, "deposit does not restore or spend strength")
	var partner: Dictionary = StrengthBudgetCandidate.make(41, 3, FIXTURE_BUDGET)
	var result: Dictionary = StrengthBudgetCandidate.consume_pair(field, partner)
	_check(result[&"accepted"] and field[&"remaining_strength"] == 9, "deposited field participates in a contact")
	_check(field[&"consumed_quantity"] == 150 and field[&"deposited_quantity"] == 450, "field consumption draws from deposited stock")
	var deposited_before: Dictionary = field.duplicate(true)
	_check(StrengthBudgetCandidate.deposit(field) == 0, "duplicate deposit is terminally idempotent")
	_check(field == deposited_before, "duplicate deposit does not mutate")
	_check(StrengthBudgetCandidate.validate(field), "partly consumed deposited field validates")


func _test_expiry_and_conservation() -> void:
	var source: Dictionary = StrengthBudgetCandidate.make(50, 10, FIXTURE_BUDGET)
	var partner: Dictionary = StrengthBudgetCandidate.make(51, 4, FIXTURE_BUDGET)
	StrengthBudgetCandidate.consume_pair(source, partner)
	_check(source[&"consumed_quantity"] == 240, "pre-expiry contact consumes proportional stock")
	_check(StrengthBudgetCandidate.expire(source) == 360, "expiry moves every remaining unit")
	_check(source[&"remaining_strength"] == 0, "expiry terminates remaining strength")
	_check(source[&"flight_quantity"] == 0 and source[&"deposited_quantity"] == 0, "expiry clears live stocks")
	_check(source[&"consumed_quantity"] + source[&"expired_quantity"] == FIXTURE_BUDGET, "expiry conserves original budget")
	_check(StrengthBudgetCandidate.validate(source), "partly consumed expired record validates")
	var expired_before: Dictionary = source.duplicate(true)
	_check(StrengthBudgetCandidate.expire(source) == 0, "duplicate expiry is terminally idempotent")
	_check(source == expired_before, "duplicate expiry does not mutate")

	var pristine: Dictionary = StrengthBudgetCandidate.make(52, 15, FIXTURE_BUDGET)
	_check(StrengthBudgetCandidate.expire(pristine) == FIXTURE_BUDGET, "pristine expiry moves full fixture budget")
	_check(pristine[&"expired_quantity"] == FIXTURE_BUDGET and StrengthBudgetCandidate.validate(pristine), "pristine expiry conserves and validates")


func _test_single_source_external_consumption() -> void:
	var source: Dictionary = StrengthBudgetCandidate.make(55, 15, FIXTURE_BUDGET)
	var partner: Dictionary = StrengthBudgetCandidate.make(56, 5, FIXTURE_BUDGET)
	StrengthBudgetCandidate.consume_pair(source, partner)
	_check(source[&"remaining_strength"] == 10 and source[&"flight_quantity"] == 400, "fixture begins with a partially consumed real source")
	_check(StrengthBudgetCandidate.consume_remaining(source) == 400, "remaining consumption moves only current live stock")
	_check(source[&"remaining_strength"] == 0 and source[&"consumed_quantity"] == FIXTURE_BUDGET, "remaining consumption exhausts strength and closes cumulative budget")
	var before: Dictionary = source.duplicate(true)
	_check(StrengthBudgetCandidate.consume_remaining(source) == 0 and source == before, "duplicate remaining consumption is terminally idempotent")
	var invalid: Dictionary = source.duplicate(true)
	invalid[&"consumed_quantity"] = -1
	_check(StrengthBudgetCandidate.consume_remaining(invalid) == -1, "invalid remaining consumption fails without a partial move")
	_check(StrengthBudgetCandidate.validate(source), "single-source remaining accounting stays valid")


func _test_provenance_and_bounds() -> void:
	_check(StrengthBudgetCandidate.make(0, 1, 1).is_empty(), "source id must be positive")
	_check(StrengthBudgetCandidate.make(60, 0, 1).is_empty(), "zero initial strength is rejected")
	_check(StrengthBudgetCandidate.make(60, 16, 1).is_empty(), "strength above fifteen is rejected")
	_check(StrengthBudgetCandidate.make(60, 1, 0).is_empty(), "zero budget is rejected")
	var record: Dictionary = StrengthBudgetCandidate.make(61, 6, FIXTURE_BUDGET)
	record[&"source_id"] = 62
	_check(not StrengthBudgetCandidate.validate(record), "provenance mutation is detected")
	var impossible_expired: Dictionary = StrengthBudgetCandidate.make(63, 3, 10)
	impossible_expired[&"remaining_strength"] = 0
	impossible_expired[&"flight_quantity"] = 0
	impossible_expired[&"consumed_quantity"] = 5
	impossible_expired[&"expired_quantity"] = 5
	_check(not StrengthBudgetCandidate.validate(impossible_expired), "expiry cannot hide a non-cumulative consumed amount")


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
