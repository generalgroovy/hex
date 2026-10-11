extends "res://tests/performance/profile_hex_hash_candidate.gd"

# Validate the actual integrated function against the preserved measured
# prototype and the frozen legacy byte oracle. The old runtime is not timed here.


func _assert_equivalent(court: HexChemistryWorld, label: String) -> void:
	super._assert_equivalent(court, label)
	_check(court._state_hash_bytes() == Candidate.frozen_original_bytes(court), label + " actual integrated bytes equal the frozen old bytes")
	_check(court._state_hash_bytes() == Candidate.candidate_bytes(court), label + " actual integrated bytes equal the measured prototype")


func _candidate_source_hashes() -> Dictionary:
	var hashes: Dictionary = super._candidate_source_hashes()
	hashes["tests/performance/profile_hex_hash_integrated.gd"] = FileAccess.get_sha256("res://tests/performance/profile_hex_hash_integrated.gd")
	return hashes


func _finish(receipt: Dictionary) -> void:
	if not receipt.is_empty():
		receipt.profile_version = "hex-hash-integrated-v1"
		receipt.scope = "Actual integrated production hash versus the preserved measured prototype, with exact actual production bytes checked against an independent frozen old oracle. Production_current now means the integrated function; this is not a second old-versus-new speedup comparison. Workload and timers are inherited unchanged from the candidate ABBA profiler."
		receipt.timing_limit = "56 samples per implementation/case; p99 is the sample-limited maximum. The historical pre-integration ABBA receipt supplies old-versus-new evidence. This run verifies the integrated path and its current isolated cost. Synthetic all-nonempty is invalid chemistry used only for fallback pressure. No allocation, frame, network, export or capacity claim."
	super._finish(receipt)
