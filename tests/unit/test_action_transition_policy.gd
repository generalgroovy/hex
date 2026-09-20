extends FluxTestSuite


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
	return finish("action-transition-policy")
