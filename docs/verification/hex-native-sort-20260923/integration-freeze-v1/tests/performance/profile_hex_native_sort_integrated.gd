extends "res://tests/performance/profile_hex_native_sort_candidate.gd"


# Current production now includes native key sorting. This is integration
# verification and current cost, not another pre-change versus new comparison.
func _native_source_hashes() -> Dictionary:
	var hashes: Dictionary = super._native_source_hashes()
	hashes["tests/performance/profile_hex_native_sort_integrated.gd"] = FileAccess.get_sha256("res://tests/performance/profile_hex_native_sort_integrated.gd")
	return hashes


func _hashes_complete(hashes: Dictionary) -> bool:
	if hashes.size() != 14:
		return false
	for value: Variant in hashes.values():
		if typeof(value) != TYPE_STRING or String(value).length() != 64:
			return false
	return true


func _finish(receipt: Dictionary) -> void:
	if not receipt.is_empty():
		receipt.profile_version = "hex-native-sort-integrated-v1"
		receipt.scope = "Actual integrated production public state_hash versus the preserved native-sort prototype, with independent frozen original byte/hash equivalence outside timers. production_current now includes native ordering and array reconstruction. The preserved candidate-v1 receipt is the old-versus-new comparison; this run measures the integrated path, not another speedup against old production."
		receipt.timing_limit = "56 samples per arm and workload. p99 is the sample-limited maximum. Synthetic all-nonempty authority is invalid chemistry used only for pressure. No frame, networking, full preparation or capacity acceptance follows from isolated hashing."
	super._finish(receipt)
