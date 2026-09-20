extends RefCounted

const ContactOrderCandidate = preload("projectile_contact_order.gd")

var _assertions: int = 0
var _failures: Array[String] = []


func run() -> Dictionary:
	_test_toi_order_and_stable_ids()
	_test_terminal_cutoff_and_cover_tie()
	_test_crossing_and_unequal_radii()
	_test_stationary_overlap_and_tangency()
	_test_equal_velocity_and_one_unit_miss()
	_test_negative_coordinates_and_same_source()
	_test_input_guards()
	return {
		"passed": _failures.is_empty(),
		"assertions": _assertions,
		"failures": _failures.duplicate(),
	}


func _record(
	entity_id: int,
	source_id: int,
	start: Vector2i,
	finish: Vector2i,
	radius: int = 10,
	remaining_strength: int = 5,
	terminal_fraction: float = 1.0,
	terminal_inclusive: bool = true,
) -> Dictionary:
	return {
		"entity_id": entity_id,
		"source_id": source_id,
		"start": start,
		"finish": finish,
		"radius": radius,
		"remaining_strength": remaining_strength,
		"terminal_fraction": terminal_fraction,
		"terminal_inclusive": terminal_inclusive,
	}


func _test_toi_order_and_stable_ids() -> void:
	var moving: Dictionary = _record(40, 100, Vector2i(0, 0), Vector2i(200, 0))
	var far: Dictionary = _record(2, 102, Vector2i(160, 0), Vector2i(160, 0))
	var near: Dictionary = _record(9, 101, Vector2i(100, 0), Vector2i(100, 0))
	var result: Dictionary = ContactOrderCandidate.plan([far, moving, near])
	_check(result[&"accepted"], "valid moving-circle batch is accepted")
	var contacts: Array = result[&"contacts"]
	_check(contacts.size() == 2, "two swept contacts are planned")
	_check(_near(contacts[0][&"fraction"], 0.4), "near contact is first by analytic TOI")
	_check(_near(contacts[1][&"fraction"], 0.7), "far contact is second by analytic TOI")
	_check(contacts[0][&"entity_a_id"] == 9 and contacts[0][&"entity_b_id"] == 40, "pair ids are canonical independent of input order")
	_check(contacts[0][&"input_a_index"] == 2 and contacts[0][&"input_b_index"] == 1, "canonical result retains input lookup indices")
	_check(result[&"broadphase_pairs"] == 3 and result[&"quadratic_pairs"] == 2, "AABB broadphase bounds quadratic work")


func _test_terminal_cutoff_and_cover_tie() -> void:
	var target: Dictionary = _record(2, 202, Vector2i(100, 0), Vector2i(100, 0))
	var covered: Dictionary = _record(1, 201, Vector2i(0, 0), Vector2i(200, 0), 10, 5, 0.4, false)
	var tie: Dictionary = ContactOrderCandidate.plan([covered, target])
	_check(tie[&"contacts"].is_empty(), "cover terminal wins an exact projectile-contact tie")

	var before_cover: Dictionary = _record(1, 201, Vector2i(0, 0), Vector2i(200, 0), 10, 5, 0.400001)
	var eligible: Dictionary = ContactOrderCandidate.plan([before_cover, target])
	_check(eligible[&"contacts"].size() == 1, "contact strictly before both cutoffs remains eligible")

	var target_terminated: Dictionary = _record(2, 202, Vector2i(100, 0), Vector2i(100, 0), 10, 5, 0.3)
	var actor_first: Dictionary = ContactOrderCandidate.plan([before_cover, target_terminated])
	_check(actor_first[&"contacts"].is_empty(), "either participant terminal cutoff excludes a later contact")

	var endpoint_target: Dictionary = _record(4, 204, Vector2i(220, 0), Vector2i(220, 0))
	var endpoint_mover: Dictionary = _record(3, 203, Vector2i(0, 0), Vector2i(200, 0))
	var endpoint: Dictionary = ContactOrderCandidate.plan([endpoint_mover, endpoint_target])
	_check(endpoint[&"contacts"].size() == 1 and endpoint[&"contacts"][0][&"fraction"] == 1.0, "default inclusive tick-end retains an exact endpoint contact")
	var range_limited: Dictionary = _record(3, 203, Vector2i(0, 0), Vector2i(200, 0), 10, 5, 1.0, true)
	var exact_range: Dictionary = ContactOrderCandidate.plan([range_limited, endpoint_target])
	_check(exact_range[&"contacts"].size() == 1, "inclusive range termination retains an exact range-end clash")


func _test_crossing_and_unequal_radii() -> void:
	var left: Dictionary = _record(10, 301, Vector2i(0, 0), Vector2i(100, 0))
	var right: Dictionary = _record(11, 302, Vector2i(100, 0), Vector2i(0, 0))
	var crossing: Dictionary = ContactOrderCandidate.plan([left, right])
	var crossing_contact: Dictionary = crossing[&"contacts"][0]
	_check(_near(crossing_contact[&"fraction"], 0.4), "opposing moving circles use relative velocity")
	_check(crossing_contact[&"point"] == Vector2i(50, 0), "crossing contact point uses both unrounded centers")

	var small: Dictionary = _record(12, 303, Vector2i(0, 0), Vector2i(200, 0), 10)
	var large: Dictionary = _record(13, 304, Vector2i(100, 0), Vector2i(100, 0), 30)
	var unequal: Dictionary = ContactOrderCandidate.plan([large, small])
	var unequal_contact: Dictionary = unequal[&"contacts"][0]
	_check(_near(unequal_contact[&"fraction"], 0.3), "unequal radii sum for first contact")
	_check(unequal_contact[&"point"] == Vector2i(70, 0), "unequal-radius physical touching point is quantized once")


func _test_stationary_overlap_and_tangency() -> void:
	var overlap_a: Dictionary = _record(20, 401, Vector2i(0, 0), Vector2i(0, 0), 10)
	var overlap_b: Dictionary = _record(21, 402, Vector2i(10, 0), Vector2i(10, 0), 10)
	var overlap: Dictionary = ContactOrderCandidate.plan([overlap_a, overlap_b])
	_check(overlap[&"contacts"].size() == 1 and overlap[&"contacts"][0][&"fraction"] == 0.0, "stationary initial overlap is planned at zero")
	_check(overlap[&"contacts"][0][&"point"] == Vector2i(5, 0), "initial overlap uses deterministic radius-weighted representative")

	var tangent_b: Dictionary = _record(22, 403, Vector2i(20, 0), Vector2i(20, 0), 10)
	var tangent: Dictionary = ContactOrderCandidate.plan([overlap_a, tangent_b])
	_check(tangent[&"contacts"].size() == 1 and tangent[&"contacts"][0][&"fraction"] == 0.0, "stationary closed tangency is eligible")
	_check(tangent[&"contacts"][0][&"point"] == Vector2i(10, 0), "stationary tangent has the physical shared point")

	var coincident_point_a: Dictionary = _record(23, 404, Vector2i(-5, 7), Vector2i(-5, 7), 0)
	var coincident_point_b: Dictionary = _record(24, 405, Vector2i(-5, 7), Vector2i(-5, 7), 0)
	var coincident: Dictionary = ContactOrderCandidate.plan([coincident_point_a, coincident_point_b])
	_check(coincident[&"contacts"][0][&"point"] == Vector2i(-5, 7), "coincident zero-radius circles have a defined contact point")


func _test_equal_velocity_and_one_unit_miss() -> void:
	var first: Dictionary = _record(30, 501, Vector2i(0, 0), Vector2i(200, 0), 10)
	var separated_same_velocity: Dictionary = _record(31, 502, Vector2i(0, 21), Vector2i(200, 21), 10)
	var separated: Dictionary = ContactOrderCandidate.plan([first, separated_same_velocity])
	_check(separated[&"contacts"].is_empty(), "equal-velocity separated circles never contact")

	var tangent: Dictionary = _record(32, 503, Vector2i(100, 20), Vector2i(100, 20), 10)
	var tangent_result: Dictionary = ContactOrderCandidate.plan([first, tangent])
	_check(tangent_result[&"contacts"].size() == 1, "moving closed tangency is retained")
	_check(_near(tangent_result[&"contacts"][0][&"fraction"], 0.5), "moving tangency uses the exact interior TOI")

	var diagonal: Dictionary = _record(33, 504, Vector2i(0, 0), Vector2i(150, 200), 10)
	var diagonal_tangent: Dictionary = _record(34, 505, Vector2i(91, 88), Vector2i(91, 88), 10)
	var diagonal_hit: Dictionary = ContactOrderCandidate.plan([diagonal, diagonal_tangent])
	_check(diagonal_hit[&"contacts"].size() == 1, "integer 12-16-20 diagonal tangency passes the exact predicate")
	var diagonal_miss: Dictionary = _record(35, 506, Vector2i(91, 87), Vector2i(91, 87), 10)
	var miss: Dictionary = ContactOrderCandidate.plan([diagonal, diagonal_miss])
	_check(miss[&"quadratic_pairs"] == 1 and miss[&"contacts"].is_empty(), "one-unit diagonal tangent miss passes AABB then fails exact geometry")


func _test_negative_coordinates_and_same_source() -> void:
	var moving: Dictionary = _record(40, 601, Vector2i(-200, -50), Vector2i(0, -50), 10)
	var target: Dictionary = _record(41, 602, Vector2i(-100, -50), Vector2i(-100, -50), 10)
	var negative: Dictionary = ContactOrderCandidate.plan([target, moving])
	_check(_near(negative[&"contacts"][0][&"fraction"], 0.4), "negative coordinates preserve analytic TOI")
	_check(negative[&"contacts"][0][&"point"] == Vector2i(-110, -50), "negative-coordinate contact point is physical")
	var reversed: Dictionary = _record(43, 606, Vector2i(0, -50), Vector2i(-200, -50), 10)
	var reversed_result: Dictionary = ContactOrderCandidate.plan([target, reversed])
	_check(_near(reversed_result[&"contacts"][0][&"fraction"], 0.4), "reversed negative travel preserves first-contact TOI")
	_check(reversed_result[&"contacts"][0][&"point"] == Vector2i(-90, -50), "reversed travel reports the opposite physical surface")

	var sibling: Dictionary = _record(42, 601, Vector2i(-100, -50), Vector2i(-100, -50), 10)
	var same_source: Dictionary = ContactOrderCandidate.plan([moving, sibling])
	_check(same_source[&"accepted"] and same_source[&"contacts"].is_empty(), "same-source circles are intentionally ineligible")

	var tie_mover: Dictionary = _record(50, 603, Vector2i(0, 0), Vector2i(200, 0), 10)
	var upper: Dictionary = _record(9, 604, Vector2i(100, 20), Vector2i(100, 20), 10)
	var lower: Dictionary = _record(3, 605, Vector2i(100, -20), Vector2i(100, -20), 10)
	var ties: Array = ContactOrderCandidate.plan([upper, tie_mover, lower])[&"contacts"]
	_check(ties.size() == 2, "simultaneous tangent contacts are both candidates")
	_check(ties[0][&"entity_a_id"] == 3 and ties[1][&"entity_a_id"] == 9, "TOI ties sort by stable canonical entity ids")


func _test_input_guards() -> void:
	var valid: Dictionary = _record(60, 701, Vector2i.ZERO, Vector2i(1, 0))
	var exhausted: Dictionary = _record(61, 702, Vector2i.ZERO, Vector2i(1, 0), 10, 0)
	var exhausted_result: Dictionary = ContactOrderCandidate.plan([valid, exhausted])
	_check(not exhausted_result[&"accepted"] and exhausted_result[&"reason"] == &"invalid_record", "zero-strength active input is rejected")

	var duplicate: Dictionary = _record(60, 703, Vector2i.ZERO, Vector2i(1, 0))
	var duplicate_result: Dictionary = ContactOrderCandidate.plan([valid, duplicate])
	_check(not duplicate_result[&"accepted"] and duplicate_result[&"reason"] == &"duplicate_entity_id", "duplicate entity identity is rejected")

	var too_many: Array[Dictionary] = []
	for index: int in range(ContactOrderCandidate.MAX_RECORDS + 1):
		too_many.append(_record(index + 1, index + 1, Vector2i(index, 0), Vector2i(index, 0), 0))
	var guard: Dictionary = ContactOrderCandidate.plan(too_many)
	_check(not guard[&"accepted"] and guard[&"reason"] == &"too_many_records", "planner rejects more than 128 records before pair enumeration")


func _near(actual: float, expected: float, tolerance: float = 0.000000001) -> bool:
	return absf(actual - expected) <= tolerance


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
