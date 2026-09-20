extends "res://tests/performance/profile_unified_wellspring.gd"

# Bounded dense-field probe reuses the unchanged production paid workload,
# host event retention, 60 Hz snapshots, warmup and finite expiry cleanup.
func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output_path = argument.trim_prefix("--output=")
	if not output_path.begins_with("res://.godot/global-hex-profile-") or ".." in output_path or FileAccess.file_exists(output_path):
		quit(1)
		return
	sample_ticks = 480
	_check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "production abilities")
	_check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "production champions")
	_check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "production map")
	definition = HexWorldDefinition.from_campus(layout)
	_check(definition != null, "whole-map topology")
	if failures > 0:
		quit(1)
		return
	var runs: Array[Dictionary] = []
	for repetition: int in 1:
		var result := _measure("dense-crucible", repetition == 1)
		result.repeat = repetition + 1
		runs.append(result)
		print("GLOBAL_HEX_PROFILE_RESULT ", JSON.stringify(result))
	var receipt := {
		"status": "passed" if failures == 0 else "failed", "failures": failures, "assertions": assertions,
		"runtime_identity": JSON.parse_string(FileAccess.get_file_as_string(RuntimeBuildIdentity.MANIFEST_PATH)),
		"scope": "480 sampled ticks in one complete authored cycle of existing dense8-player paid workload;120Hz sim,60Hz host snapshot/packing; one command order;120 warmup ticks and full finite expiry cleanup. Short probe, not the historical720-tick workload or a long soak. No render/socket/input-latency acceptance.",
		"topology_cells": definition.eligible_cells.size(), "runs": runs, "source_sha256": _source_hashes(),
	}
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt, "\t") + "\n")
	file.close()
	quit(1 if failures > 0 else 0)
