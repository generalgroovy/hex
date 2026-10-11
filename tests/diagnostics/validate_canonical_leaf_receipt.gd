extends "res://tests/performance/profile_canonical_leaf_candidate.gd"

# Read-only receipt-validator check. No fixture construction, source changes,
# gameplay stepping, timers, or evidence rewriting occurs here.
func _run() -> void:
	var input_path := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--input="): input_path = argument.trim_prefix("--input=")
		else: _check(false, "unknown leaf receipt validation argument")
	_check(input_path.begins_with("res://.godot/canonical-leaf-") and input_path.ends_with(".json") and input_path.get_base_dir() == "res://.godot" and not ".." in input_path and FileAccess.file_exists(input_path), "existing scoped leaf receipt")
	if failures > 0:
		quit(1)
		return
	var receipt: Variant = JSON.parse_string(FileAccess.get_file_as_string(input_path))
	_check(receipt is Dictionary and receipt.get("records") is Array, "receipt has records")
	if failures > 0:
		quit(1)
		return
	_check(_leaf_records_valid(receipt.records), "parsed JSON records pass exact integral numeric validation")
	var records: Array[Dictionary] = []
	for record: Dictionary in receipt.records: records.append(record)
	_leaf_receipt_guards(records)
	print("%s: canonical-leaf-receipt-validation; %d assertions; %d failures; input=%s; prior diagnostic_status unchanged=%s" % ["PASS" if failures == 0 else "FAIL", assertions, failures, input_path, receipt.get("diagnostic_status", "unknown")])
	quit(1 if failures > 0 else 0)
