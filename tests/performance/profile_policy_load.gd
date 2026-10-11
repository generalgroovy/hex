extends SceneTree

const ORIGINAL_PATH := "res://tests/support/references/policy-load-oct6-before.gd.txt"
const ORIGINAL_SHA := "d19c37dc7c091a21b2b1c52dd0109648d2808bfaf3bd5d9fc52e2e5d9f9bf9ba"
const CURRENT_PATH := "res://src/sim/core/action_transition_policy.gd"
const PAIRS := 31
var assertions := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output=") and output.is_empty(): output = argument.trim_prefix("--output=")
		else: _check(false, "unknown or repeated argument")
	_check(output.begins_with("res://.godot/policy-load-samples-") and output.ends_with(".json") and output.get_base_dir() == "res://.godot" and not ".." in output and not FileAccess.file_exists(output), "fresh scoped output")
	_check(FileAccess.get_sha256(ORIGINAL_PATH) == ORIGINAL_SHA, "exact saved original source")
	if failures > 0:
		quit(1)
		return
	var current_sha := FileAccess.get_sha256(CURRENT_PATH)
	var input_sha := FileAccess.get_sha256(ActionTransitionPolicy.DEFAULT_PATH)
	var original_text := FileAccess.get_file_as_string(ORIGINAL_PATH)
	_check(original_text.begins_with("class_name ActionTransitionPolicy\r\n") or original_text.begins_with("class_name ActionTransitionPolicy\n"), "exact original class-name first line")
	if failures > 0:
		quit(1)
		return
	var original := GDScript.new()
	original.source_code = original_text.substr(original_text.find("\n") + 1)
	_check(original.reload() == OK, "anonymous original compiles with only first line removed")
	if failures > 0:
		quit(1)
		return
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ActionTransitionPolicy.DEFAULT_PATH))
	var expected_hash := ActionTransitionPolicy.repository_hash()
	_check(not expected.is_empty() and expected_hash.length() == 64, "independent fixture and hash")
	var preceding_cache: Dictionary = ActionTransitionPolicy._load_cache
	var records: Array[Dictionary] = []
	var retained_bytes := 0
	for mode: String in ["cold", "warm"]:
		var samples := {"original": PackedInt64Array(), "candidate": PackedInt64Array()}
		var rows: Array[Dictionary] = []
		for index: int in PAIRS:
			if mode == "cold": ActionTransitionPolicy._load_cache = {}
			else: _check(ActionTransitionPolicy.new().load_from_file(), "untimed warm prime")
			var order: Array = ["original", "candidate"] if (index + int(mode == "warm")) % 2 == 0 else ["candidate", "original"]
			var row := {"pair": index, "order": order.duplicate(), "samples_us": {}}
			for arm: String in order:
				var policy: RefCounted = original.new() if arm == "original" else ActionTransitionPolicy.new()
				var started := Time.get_ticks_usec()
				var accepted: bool = policy.load_from_file(ActionTransitionPolicy.DEFAULT_PATH)
				var elapsed := Time.get_ticks_usec() - started
				var observations: PackedInt64Array = samples[arm]
				observations.append(elapsed)
				samples[arm] = observations
				row.samples_us[arm] = elapsed
				_check(accepted and policy.data == expected and policy.content_hash == expected_hash and policy.last_error == "", mode + " " + arm + " exact result")
			rows.append(row)
			var entry: Dictionary = ActionTransitionPolicy._load_cache
			_check(entry.size() == 3 and entry.has("source") and entry.has("data") and entry.has("hash"), "one complete retained entry")
			if entry.has("source"):
				retained_bytes = maxi(retained_bytes, String(entry.source).to_utf8_buffer().size())
				_check(retained_bytes <= 65_536 and entry.data == expected and entry.hash == expected_hash, "bounded exact retained entry")
		_check(samples.original.size() == PAIRS and samples.candidate.size() == PAIRS, "all alternating pairs recorded")
		records.append({"mode": mode, "pairs": rows, "original": _stats(samples.original), "candidate": _stats(samples.candidate)})
	ActionTransitionPolicy._load_cache = preceding_cache
	_check(FileAccess.get_sha256(ORIGINAL_PATH) == ORIGINAL_SHA, "saved original remains unchanged")
	_check(FileAccess.get_sha256(CURRENT_PATH) == current_sha and FileAccess.get_sha256(ActionTransitionPolicy.DEFAULT_PATH) == input_sha, "production and input remain unchanged")
	var receipt := {
		"profile_version": "policy-load-v1", "engine": Engine.get_version_info().get("string", ""),
		"original_sha256": ORIGINAL_SHA, "candidate_sha256": current_sha, "input_sha256": input_sha,
		"pairs_per_mode": PAIRS, "records": records, "max_retained_source_bytes": retained_bytes,
		"scope": "Actual default policy file and fresh original/candidate policy instances. The saved original is compiled anonymously after removing only its exact class_name first line. Cold clears candidate cache before each pair; warm primes outside timers. Pair order alternates and is counterbalanced across modes. Only load_from_file is timed; construction, priming, checks and receipt work are excluded.",
		"limits": "Bounded CPU microbenchmark, not complete publication, sustained percentiles, FPS, network, 120Hz or capacity acceptance. No performance threshold. Cold means empty policy cache, not cold operating-system file cache. Each sample still reads the actual file.",
		"performance_acceptance": "NOT_ESTABLISHED",
	}
	var file := FileAccess.open(output, FileAccess.WRITE)
	_check(file != null, "fresh receipt opens")
	if file != null:
		receipt.assertions = assertions
		receipt.failures = failures
		receipt.diagnostic_status = "PASS" if failures == 0 else "FAIL"
		file.store_string(JSON.stringify(receipt, "\t") + "\n")
		file.close()
	print("%s: policy-load; %d assertions; %d failures; output=%s" % ["PASS" if failures == 0 else "FAIL", assertions, failures, output])
	quit(1 if failures > 0 else 0)


func _stats(samples: PackedInt64Array) -> Dictionary:
	var ordered := samples.duplicate()
	ordered.sort()
	return {"samples_us": samples, "median_us": ordered[15], "p95_us": ordered[29], "min_us": ordered[0], "max_us": ordered[30]}


func _check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		print("FAIL policy-load: " + label)
