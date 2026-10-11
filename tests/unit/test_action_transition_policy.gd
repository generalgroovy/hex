extends FluxTestSuite


class ExtendedPolicy:
	extends ActionTransitionPolicy
	var failure_calls := 0
	func _fail(message: String) -> bool:
		failure_calls += 1
		return super._fail(message)


func run() -> int:
	var policy := ActionTransitionPolicy.new()
	check(policy.load_from_file(), "action transition matrix validates: %s" % policy.last_error)
	check(policy.content_hash.length() == 64, "transition matrix owns a stable canonical hash")
	equal(policy.content_hash, ActionTransitionPolicy.repository_hash(), "runtime and compatibility use the same transition identity")
	equal((policy.data["coverage"] as Dictionary)["movement_modes"].size(), PlayerState.MovementMode.size(), "transition matrix covers every current movement mode")
	equal((policy.data["coverage"] as Dictionary)["spell_shapes"].size(), 4, "transition matrix covers every live foundation spell shape")
	equal((policy.data["rules"] as Array).size(), ActionTransitionPolicy.REQUIRED_RULES.size(), "transition matrix exposes the exact foundation transition rules")
	check(policy.allows_during_recovery(), "generic recovery is explicitly non-blocking")
	for reason: String in ActionTransitionPolicy.DECLARED_REFUSAL_REASONS:
		check(policy.refusal_reason_is_declared(reason), "refusal reason is declared: %s" % reason)
	var state := PlayerState.new()
	equal(policy.cast_gate_reason(state), "", "free movement permits spell startup")
	state.cast_recovery_ticks = 12
	equal(policy.cast_gate_reason(state), "", "recovery animation does not become a global spell lock")
	state.pending_cast_wire_id = CombatTuning.RILLSHOT_WIRE_ID
	equal(policy.cast_gate_reason(state), "startup_commitment", "one active startup occupies the execution channel")
	state.pending_cast_wire_id = 0
	for control_state: int in [
		PlayerState.ControlState.LAUNCHED,
		PlayerState.ControlState.GRAPPLED,
		PlayerState.ControlState.CHARGING,
		PlayerState.ControlState.STUNNED,
		PlayerState.ControlState.ROOTED,
	]:
		state.control_state = control_state
		var control_id := ActionTransitionPolicy.control_state_id(control_state)
		equal(policy.cast_gate_reason(state), "control_%s" % control_id, "%s is an explicit physical cast gate" % control_id)
	state.control_state = PlayerState.ControlState.SLOWED
	equal(policy.cast_gate_reason(state), "", "slow changes motion but does not silence casting")
	_load_reuse_tests()
	return finish("action-transition-policy")


func _load_reuse_tests() -> void:
	# Never edit the packaged policy. Every file and directory below belongs only
	# to this invocation, including when the suite runs against exported content.
	var directory := "user://action-policy-cache-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(not DirAccess.dir_exists_absolute(directory), "policy fixture directory is fresh")
	if DirAccess.dir_exists_absolute(directory): return
	var created := DirAccess.make_dir_absolute(directory)
	equal(created, OK, "policy fixture directory created")
	if created != OK: return
	var first_path := directory + "/first.json"
	var second_path := directory + "/second.json"
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ActionTransitionPolicy.DEFAULT_PATH))
	source["cache_test_marker"] = "alpha"
	source["cache_test_nested"] = {"items": [{"name": "original"}, 7]}
	var first_text := JSON.stringify(source)
	var second_text := first_text.replace("\"alpha\"", "\"bravo\"")
	equal(first_text.length(), second_text.length(), "changed valid policy has identical text length")
	check(first_text != second_text, "same-size fixture actually differs")
	if _write_policy(first_path, first_text) and _write_policy(second_path, second_text):
		# JSON numbers reload as floats; compare against independently parsed
		# fixture text rather than the pre-serialization integer literal above.
		var expected: Dictionary = JSON.parse_string(first_text)
		_exercise_load_reuse(first_path, second_path, first_text, second_text, expected)
	for path: String in [first_path, second_path]:
		if FileAccess.file_exists(path): equal(DirAccess.remove_absolute(path), OK, "owned policy fixture removed")
	equal(DirAccess.remove_absolute(directory), OK, "empty owned policy fixture directory removed")
	# Leave the ordinary repository policy as the final valid load, rather than
	# retaining fixture content beyond this focused suite.
	check(ActionTransitionPolicy.new().load_from_file(), "ordinary policy reloads after fixture cleanup")


func _exercise_load_reuse(first_path: String, second_path: String, first_text: String,
		second_text: String, expected: Dictionary) -> void:
	var first := ActionTransitionPolicy.new()
	var warm := ActionTransitionPolicy.new()
	check(first.load_from_file(first_path), "first isolated valid policy loads")
	var first_hash := ActionTransitionPolicy.repository_hash(first_path)
	equal(first.content_hash, first_hash, "first load keeps independent repository hash")
	equal(first.data, expected, "first load retains every parsed field")
	check(warm.load_from_file(first_path), "unchanged policy loads again")
	equal(warm.content_hash, first_hash, "warm load preserves hash")
	equal(warm.data, expected, "warm load preserves data")
	first.data["cache_test_nested"]["items"][0]["name"] = "mutated"
	first.data["cache_test_nested"]["items"].append(99)
	first.data["rules"][0]["allowed"] = false
	first.content_hash = "caller-modified"
	equal(warm.data, expected, "policy instances never share nested writable data")
	check(first.load_from_file(first_path), "same instance reloads after caller mutation")
	equal(first.data, expected, "caller mutation cannot poison retained policy data")
	equal(first.content_hash, first_hash, "caller mutation cannot poison retained hash")
	first.data.clear()
	check(first.load_from_file(first_path), "reload after caller clearing data")
	equal(first.data, expected, "clearing caller data does not clear retained data")
	check(warm.load_from_file(second_path), "different path with different valid content loads")
	equal(warm.data.get("cache_test_marker"), "bravo", "different path uses its own bytes")
	var second_hash := ActionTransitionPolicy.repository_hash(second_path)
	equal(warm.content_hash, second_hash, "different content uses independent canonical hash")
	check(second_hash != first_hash, "same-size valid content changes canonical identity")
	check(first.load_from_file(first_path), "prior path reloads after another source")
	equal(first.data.get("cache_test_marker"), "alpha", "cross-path loads never exchange content")
	if _write_policy(first_path, second_text):
		check(first.load_from_file(first_path), "same path and same length changed valid text reloads")
		equal(first.data.get("cache_test_marker"), "bravo", "same-size edit is not hidden by reuse")
		equal(first.content_hash, second_hash, "same-size edit uses new exact canonical identity")
	if _write_policy(second_path, first_text):
		check(warm.load_from_file(second_path), "second path changed back to first source")
		equal(warm.data, expected, "same text at another path restores exact data")
		equal(warm.content_hash, first_hash, "same text at another path restores exact hash")
	var invalid_identity := first_text.replace("action-transition-matrix-v1", "action-transition-matrix-v2")
	equal(invalid_identity.length(), first_text.length(), "invalid identity fixture keeps length")
	if _write_policy(second_path, invalid_identity):
		check(not warm.load_from_file(second_path), "same-size invalid identity after warm load rejects")
		equal(warm.last_error, "Action transition matrix identity is unsupported", "invalid identity preserves refusal text")
		_failed_load_is_empty(warm)
	if _write_policy(second_path, first_text):
		check(warm.load_from_file(second_path), "valid source recovers after invalid identity")
		equal(warm.last_error, "", "success clears preceding error")
	if _write_policy(second_path, "{"):
		# The original JSON.parse_string emits an engine error for this deliberate
		# malformed input. Silence only that expected call, then restore logging
		# before assertions or any other production operation.
		var print_errors_before: bool = Engine.print_error_messages
		Engine.print_error_messages = false
		var malformed_accepted: bool = warm.load_from_file(second_path)
		Engine.print_error_messages = print_errors_before
		check(not malformed_accepted, "malformed JSON after warm load rejects")
		equal(Engine.print_error_messages, print_errors_before, "malformed fixture restores engine error reporting")
		equal(warm.last_error, "Action transition matrix is missing or invalid JSON", "malformed JSON preserves refusal text")
		_failed_load_is_empty(warm)
	if _write_policy(second_path, first_text):
		check(warm.load_from_file(second_path), "warm fixture restored before deletion")
		equal(DirAccess.remove_absolute(second_path), OK, "owned warm fixture deleted")
		check(not warm.load_from_file(second_path), "deleted file cannot reuse formerly valid source")
		equal(warm.last_error, "Action transition matrix is missing or invalid JSON", "missing file preserves refusal text")
		_failed_load_is_empty(warm)
	var oversized: Dictionary = expected.duplicate(true)
	oversized["cache_test_large"] = "x".repeat(65_537)
	var oversized_text := JSON.stringify(oversized)
	oversized = JSON.parse_string(oversized_text)
	var retained_cache: Dictionary = ActionTransitionPolicy._load_cache.duplicate(true)
	if _write_policy(second_path, oversized_text):
		check(warm.load_from_file(second_path), "valid source over retention bound still loads")
		equal(warm.data, oversized, "oversized source preserves full data")
		equal(warm.content_hash, ActionTransitionPolicy.repository_hash(second_path), "oversized source keeps independent hash")
		warm.data["cache_test_large"] = "changed"
		check(warm.load_from_file(second_path), "oversized source reloads without caller alias")
		equal(warm.data, oversized, "oversized source reload retains exact fresh content")
		equal(ActionTransitionPolicy._load_cache, retained_cache, "oversized valid source is not retained")
	oversized["cache_test_large"] = "\u00e9".repeat(33_000)
	var multibyte_text := JSON.stringify(oversized)
	oversized = JSON.parse_string(multibyte_text)
	check(multibyte_text.to_utf8_buffer().size() > 65_536, "multibyte fixture exceeds byte retention limit")
	if _write_policy(second_path, multibyte_text):
		check(warm.load_from_file(second_path), "multibyte oversized policy still loads")
		equal(warm.data, oversized, "multibyte oversized policy retains exact contents")
		equal(ActionTransitionPolicy._load_cache, retained_cache, "retention bound counts UTF-8 bytes")
	if _write_policy(second_path, first_text):
		check(warm.load_from_file(second_path), "concrete source warmed before extension load")
		var extension := ExtendedPolicy.new()
		check(extension.load_from_file(second_path), "extension retains ordinary successful load")
		equal(extension.data, expected, "extension gets exact source data")
		equal(extension.content_hash, first_hash, "extension gets independent source hash")
		extension.data["cache_test_nested"]["items"][0]["name"] = "extension-mutated"
		equal(warm.data, expected, "extension output cannot mutate concrete policy data")
		check(extension.load_from_file(first_path), "extension loads different valid source")
		equal(extension.data.get("cache_test_marker"), "bravo", "extension reads its requested source")
		equal(ActionTransitionPolicy._load_cache.source, first_text, "extension does not replace concrete load entry")
		if _write_policy(second_path, invalid_identity):
			check(not extension.load_from_file(second_path), "extension rejects changed invalid source")
			equal(extension.failure_calls, 1, "extension retains original failure callback")
			_failed_load_is_empty(extension)
	equal(ActionTransitionPolicy._load_cache.size(), 3, "retained cache is exactly one source-data-hash entry")
	check(ActionTransitionPolicy._load_cache.source.to_utf8_buffer().size() <= 65_536, "retained source obeys byte limit")


func _failed_load_is_empty(policy: ActionTransitionPolicy) -> void:
	check(policy.data.is_empty(), "failed load clears preceding data")
	equal(policy.content_hash, "", "failed load clears preceding hash")


func _write_policy(path: String, value: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "owned policy fixture opens for writing")
	if file == null: return false
	file.store_string(value)
	file.close()
	return true
