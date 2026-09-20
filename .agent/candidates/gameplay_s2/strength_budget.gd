class_name StrengthBudget
extends RefCounted

## Pure integer accounting for one finite-strength gameplay source.
##
## A record owns exactly [code]budget[/code] quantity. Quantity begins in flight,
## can move to deposited stock, and can end in consumed or expired sinks. Strength
## loss charges quantity cumulatively, so repeated contacts cannot gain or lose
## quantity through per-contact rounding.

const MIN_STRENGTH: int = 1
const MAX_STRENGTH: int = 15

# Every multiplication is budget * strength_delta, and strength_delta <= 15.
const MAX_SAFE_BUDGET: int = 614891469123651720

const _PROVENANCE_KEY: StringName = &"_strength_budget_provenance"


static func make(source_id: int, initial_strength: int, budget: int) -> Dictionary:
	if source_id <= 0:
		return {}
	if initial_strength < MIN_STRENGTH or initial_strength > MAX_STRENGTH:
		return {}
	if budget <= 0 or budget > MAX_SAFE_BUDGET:
		return {}
	return {
		"source_id": source_id,
		"initial_strength": initial_strength,
		"budget": budget,
		"remaining_strength": initial_strength,
		"flight_quantity": budget,
		"deposited_quantity": 0,
		"consumed_quantity": 0,
		"expired_quantity": 0,
		_PROVENANCE_KEY: PackedInt64Array([source_id, initial_strength, budget]),
	}


static func validate(record: Dictionary) -> bool:
	var names: Array[StringName] = [
		&"source_id",
		&"initial_strength",
		&"budget",
		&"remaining_strength",
		&"flight_quantity",
		&"deposited_quantity",
		&"consumed_quantity",
		&"expired_quantity",
	]
	for name: StringName in names:
		if not record.has(name) or typeof(record[name]) != TYPE_INT:
			return false
	if not record.has(_PROVENANCE_KEY):
		return false
	var provenance_value: Variant = record[_PROVENANCE_KEY]
	if typeof(provenance_value) != TYPE_PACKED_INT64_ARRAY:
		return false
	var provenance: PackedInt64Array = provenance_value
	if provenance.size() != 3:
		return false

	var source_id: int = record[&"source_id"]
	var initial_strength: int = record[&"initial_strength"]
	var budget: int = record[&"budget"]
	var remaining_strength: int = record[&"remaining_strength"]
	var flight_quantity: int = record[&"flight_quantity"]
	var deposited_quantity: int = record[&"deposited_quantity"]
	var consumed_quantity: int = record[&"consumed_quantity"]
	var expired_quantity: int = record[&"expired_quantity"]

	if source_id <= 0:
		return false
	if initial_strength < MIN_STRENGTH or initial_strength > MAX_STRENGTH:
		return false
	if budget <= 0 or budget > MAX_SAFE_BUDGET:
		return false
	if provenance[0] != source_id or provenance[1] != initial_strength or provenance[2] != budget:
		return false
	if remaining_strength < 0 or remaining_strength > initial_strength:
		return false
	if flight_quantity < 0 or deposited_quantity < 0 or consumed_quantity < 0 or expired_quantity < 0:
		return false

	# Subtraction avoids overflowing while checking the conserved total.
	var unaccounted: int = budget
	for quantity: int in [flight_quantity, deposited_quantity, consumed_quantity, expired_quantity]:
		if quantity > unaccounted:
			return false
		unaccounted -= quantity
	if unaccounted != 0:
		return false
	# Operations keep all live quantity in exactly one location.
	if flight_quantity > 0 and deposited_quantity > 0:
		return false

	if expired_quantity > 0:
		if remaining_strength != 0 or flight_quantity != 0 or deposited_quantity != 0:
			return false
		return _is_cumulative_consumed(initial_strength, budget, consumed_quantity)

	var strength_spent: int = initial_strength - remaining_strength
	var expected_consumed: int = _cumulative_quantity(initial_strength, budget, strength_spent)
	return consumed_quantity == expected_consumed


static func consume_pair(first: Dictionary, second: Dictionary) -> Dictionary:
	# All checks and arithmetic precede mutation so every rejection is atomic.
	if not validate(first) or not validate(second):
		return _rejected(&"invalid")
	var first_source_id: int = first[&"source_id"]
	var second_source_id: int = second[&"source_id"]
	if first_source_id == second_source_id:
		return _rejected(&"same_source")
	var first_pre: int = first[&"remaining_strength"]
	var second_pre: int = second[&"remaining_strength"]
	if first_pre <= 0 or second_pre <= 0:
		return _rejected(&"exhausted")

	var matched_strength: int = mini(first_pre, second_pre)
	var first_post: int = first_pre - matched_strength
	var second_post: int = second_pre - matched_strength
	var first_delta: int = _quantity_delta(first, first_pre, first_post)
	var second_delta: int = _quantity_delta(second, second_pre, second_post)
	var first_available: int = first[&"flight_quantity"] + first[&"deposited_quantity"]
	var second_available: int = second[&"flight_quantity"] + second[&"deposited_quantity"]
	if first_delta < 0 or second_delta < 0:
		return _rejected(&"invalid")
	if first_delta > first_available or second_delta > second_available:
		return _rejected(&"invalid")

	_apply_consumption(first, first_post, first_delta)
	_apply_consumption(second, second_post, second_delta)
	var first_portion: Dictionary = _portion(first_source_id, first_pre, first_post, first_delta)
	var second_portion: Dictionary = _portion(second_source_id, second_pre, second_post, second_delta)
	return {
		"accepted": true,
		"reason": &"",
		"matched_strength": matched_strength,
		"first": first_portion,
		"second": second_portion,
		"source_portions": [first_portion, second_portion],
	}


## Consumes all current live stock from one real source. Returns the moved
## quantity, zero for an already-terminal record, or -1 for an invalid record.
static func consume_remaining(record: Dictionary) -> int:
	if not validate(record):
		return -1
	var pre_strength: int = record[&"remaining_strength"]
	var available: int = record[&"flight_quantity"] + record[&"deposited_quantity"]
	if pre_strength <= 0 or available <= 0:
		return 0
	var quantity: int = _quantity_delta(record, pre_strength, 0)
	if quantity != available:
		return -1
	_apply_consumption(record, 0, quantity)
	return quantity


## Moves all current flight stock into deposited stock. Returns the moved quantity,
## zero for an already terminal/deposited record, or -1 for an invalid record.
static func deposit(record: Dictionary) -> int:
	if not validate(record):
		return -1
	var moved: int = record[&"flight_quantity"]
	if moved <= 0:
		return 0
	record[&"flight_quantity"] = 0
	record[&"deposited_quantity"] = record[&"deposited_quantity"] + moved
	return moved


## Moves every live quantity to the expiry sink and terminates strength. Returns
## the moved quantity, zero for a duplicate terminal call, or -1 when invalid.
static func expire(record: Dictionary) -> int:
	if not validate(record):
		return -1
	var moved: int = record[&"flight_quantity"] + record[&"deposited_quantity"]
	if moved <= 0:
		return 0
	record[&"flight_quantity"] = 0
	record[&"deposited_quantity"] = 0
	record[&"expired_quantity"] = record[&"expired_quantity"] + moved
	record[&"remaining_strength"] = 0
	return moved


static func _quantity_delta(record: Dictionary, old_remaining: int, new_remaining: int) -> int:
	var initial_strength: int = record[&"initial_strength"]
	var budget: int = record[&"budget"]
	var old_spent: int = initial_strength - old_remaining
	var new_spent: int = initial_strength - new_remaining
	return _cumulative_quantity(initial_strength, budget, new_spent) \
		- _cumulative_quantity(initial_strength, budget, old_spent)


static func _cumulative_quantity(initial_strength: int, budget: int, strength_spent: int) -> int:
	@warning_ignore("integer_division")
	return (budget * strength_spent) / initial_strength


static func _is_cumulative_consumed(initial_strength: int, budget: int, quantity: int) -> bool:
	for strength_spent: int in range(initial_strength + 1):
		if _cumulative_quantity(initial_strength, budget, strength_spent) == quantity:
			return true
	return false


static func _apply_consumption(record: Dictionary, new_remaining: int, quantity: int) -> void:
	if record[&"deposited_quantity"] > 0:
		record[&"deposited_quantity"] = record[&"deposited_quantity"] - quantity
	else:
		record[&"flight_quantity"] = record[&"flight_quantity"] - quantity
	record[&"consumed_quantity"] = record[&"consumed_quantity"] + quantity
	record[&"remaining_strength"] = new_remaining


static func _portion(source_id: int, pre_strength: int, post_strength: int, quantity: int) -> Dictionary:
	return {
		"source_id": source_id,
		"pre_strength": pre_strength,
		"post_strength": post_strength,
		"consumed_strength": pre_strength - post_strength,
		"consumed_quantity": quantity,
		"exhausted": post_strength == 0,
	}


static func _rejected(reason: StringName) -> Dictionary:
	return {
		"accepted": false,
		"reason": reason,
		"matched_strength": 0,
		"first": {},
		"second": {},
		"source_portions": [],
	}
