extends FluxTestSuite


func run() -> int:
	_test_repository_motion()
	_test_complete_movement_mapping()
	_test_tick_rate_parity_and_reduced_motion()
	_test_locomotion_contact_phase()
	_test_continuous_micro_pivot()
	_test_contact_weight_transfer()
	_test_invalid_micro_pivot()
	_test_distance_phase_helpers()
	return finish("minimal-champion-motion")


func _test_distance_phase_helpers() -> void:
	var motion := MinimalChampionMotion.new()
	check(motion.load_from_file(), "distance phase helper loads existing durations")
	for height: float in [58.0, 68.0, 76.0]:
		check(absf(MinimalChampionMotion.locomotion_stride_pixels(height) - height * 1.3) < 0.00001, "full stride is two clear 0.65-height foot contacts")
	for profile_id: String in motion.profiles:
		for action: String in ["walk", "sprint"]:
			for phase: float in [0.0, 0.25, 0.5, 0.75]:
				var elapsed := motion.locomotion_elapsed_at_phase(profile_id, action, phase)
				equal(motion.locomotion_contact_frame(profile_id, action, elapsed), 0 if phase < 0.5 else 1, "distance phase selects the same support foot across all authored durations")
	equal(motion.locomotion_elapsed_at_phase("missing", "walk", 0.5), 0.0, "invalid profile fails to a stable contact")
	equal(motion.locomotion_elapsed_at_phase("buoyant_keeper", "air", 0.5), 0.0, "distance phase cannot advance an airborne action")
	check(is_finite(MinimalChampionMotion.locomotion_stride_pixels(NAN)), "invalid height cannot poison a presentation phase")
	equal(motion.locomotion_elapsed_at_phase("buoyant_keeper", "walk", NAN), 0.0, "invalid phase fails to a stable plant")


func _test_repository_motion() -> void:
	var motion := MinimalChampionMotion.new()
	check(motion.load_from_file(), "minimal champion motion validates: %s" % motion.last_error)
	check(motion.content_hash.length() == 64, "minimal motion has a stable content hash")
	for profile_id: String in ["buoyant_keeper", "grounded_weaver", "iron_regent"]:
		check(motion.has_profile(profile_id), "%s is an editable motion profile" % profile_id)
		for motion_id: String in MinimalChampionMotion.REQUIRED_MOTIONS:
			var sample := motion.sample(profile_id, motion_id, 11.0)
			check(sample.offset.abs().x <= 4.0 and sample.offset.abs().y <= 4.0, "%s/%s stays within translation budget" % [profile_id, motion_id])
			equal(sample.scale, Vector2.ONE, "%s/%s cannot resize its body template" % [profile_id, motion_id])
	equal(motion.movement_accents.size(), MinimalChampionMotion.REQUIRED_ACCENTS.size(), "every declared movement-response family owns one bounded accent")
	equal(String(motion.accent_by_id("counter_strafe").get("kind", "")), "brake_ticks", "ordinary reversal owns an editable heel-plant accent")
	equal(String(motion.accent_by_id("impact_recovery").get("kind", "")), "recovery_brace", "impact recovery begins the reusable animation/environment slice with a readable brace accent")


func _test_complete_movement_mapping() -> void:
	var state := PlayerState.new()
	var expected := {
		PlayerState.MovementMode.IDLE: "idle",
		PlayerState.MovementMode.WALK: "walk",
		PlayerState.MovementMode.SPRINT: "sprint",
		PlayerState.MovementMode.HOP: "air",
		PlayerState.MovementMode.DOUBLE_JUMP: "air",
		PlayerState.MovementMode.SLIDE: "low",
		PlayerState.MovementMode.SLIDE_JUMP: "air",
		PlayerState.MovementMode.AIR_DODGE: "air",
		PlayerState.MovementMode.ROLL: "low",
		PlayerState.MovementMode.WAVE_DASH: "low",
		PlayerState.MovementMode.WALL_KICK: "air",
		PlayerState.MovementMode.VAULT: "air",
		PlayerState.MovementMode.SUPERGLIDE: "air",
		PlayerState.MovementMode.LAUNCHED: "hit",
		PlayerState.MovementMode.GRAPPLED: "hit",
		PlayerState.MovementMode.CHARGING: "cast",
		PlayerState.MovementMode.STUNNED: "hit",
		PlayerState.MovementMode.ROOTED: "idle",
		PlayerState.MovementMode.SLOWED: "walk",
		PlayerState.MovementMode.FAST_FALL: "air",
		PlayerState.MovementMode.WALL_SKIM: "low",
		PlayerState.MovementMode.IMPACT_RECOVERY: "hit",
	}
	for movement_mode: int in expected:
		state.movement_mode = movement_mode
		state.control_state = PlayerState.ControlState.FREE
		equal(MinimalChampionMotion.motion_id(state), expected[movement_mode], "%s owns a readable motion family" % PlayerState.MovementMode.keys()[movement_mode])
	state.movement_mode = PlayerState.MovementMode.IDLE
	state.pending_cast_wire_id = CombatTuning.PRIMARY_WIRE_ID
	equal(MinimalChampionMotion.motion_id(state), "cast", "authoritative startup state selects cast anticipation")


func _test_tick_rate_parity_and_reduced_motion() -> void:
	equal(MinimalChampionMotion.tick_at_visual_rate(120, 120), 60.0, "one canonical simulation second advances the 60 fps art clock once")
	equal(MinimalChampionMotion.tick_at_visual_rate(61, 120, 0.0), 30.5, "120 Hz half-ticks map exactly onto the art clock")
	var motion := MinimalChampionMotion.new()
	check(motion.load_from_file(), "motion loads for accessibility sample")
	var normal := motion.sample("buoyant_keeper", "sprint", 7.0, false)
	var reduced := motion.sample("buoyant_keeper", "sprint", 7.0, true)
	check(reduced.offset.length() < normal.offset.length(), "reduced motion damps translation")
	equal(normal.scale, Vector2.ONE, "ordinary motion keeps template scale invariant")
	equal(reduced.scale, Vector2.ONE, "reduced motion keeps template scale invariant")
	var state := PlayerState.new()
	var config := SimConfig.new(120)
	state.hop_mode = PlayerState.MovementMode.HOP
	state.hop_ticks = config.milliseconds_to_ticks(MovementTuning.HOP_DURATION_MS) / 2
	var elapsed_120 := MinimalChampionMotion.elapsed_for_state(state, "air", 0.0, config)
	var expected_half_phase := float(MovementTuning.HOP_DURATION_MS) * 60.0 / 2000.0
	check(absf(elapsed_120 - expected_half_phase) <= 0.5, "120 Hz airborne half-phase reaches the center of its 60 fps art duration")


func _test_locomotion_contact_phase() -> void:
	var motion := MinimalChampionMotion.new()
	check(motion.load_from_file(), "motion loads for locomotion contact phases")
	equal(motion.locomotion_contact_frame("buoyant_keeper", "walk", 0.0), 0, "walk begins on contact A")
	equal(motion.locomotion_contact_frame("buoyant_keeper", "walk", 10.9), 0, "contact A holds through the first half-cycle")
	equal(motion.locomotion_contact_frame("buoyant_keeper", "walk", 11.0), 1, "walk swaps legs at the half-cycle")
	equal(motion.locomotion_contact_frame("buoyant_keeper", "walk", 22.0), 0, "walk loops back to contact A")
	var phase_120 := motion.locomotion_contact_frame("grounded_weaver", "sprint", MinimalChampionMotion.tick_at_visual_rate(24, 120), 3)
	equal(phase_120, 1, "120 Hz contact-frame cadence reaches the authored opposite contact")
	equal(motion.locomotion_contact_frame("buoyant_keeper", "idle", 99.0), 0, "non-locomotion states cannot select an alternate contact")


func _test_continuous_micro_pivot() -> void:
	var motion := MinimalChampionMotion.new()
	check(motion.load_from_file(), "micro-pivot uses existing motion profiles")
	for profile_id: String in motion.profiles:
		for action: String in ["walk", "sprint"]:
			var duration := float((motion.profiles[profile_id][action] as Dictionary)["duration_ticks"])
			for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
				var facing := Vector2(direction)
				for phase: float in [0.0, 0.5, 1.0]:
					check(motion.locomotion_pivot_offset(profile_id, action, phase * duration, facing, 1.0).length() < 0.0001, "both planted contacts return to the exact pivot")
				var previous := Vector2.ZERO
				for index: int in range(121):
					var elapsed := duration * float(index) / 120.0
					var offset := motion.locomotion_pivot_offset(profile_id, action, elapsed, facing, 1.0)
					var reduced := motion.locomotion_pivot_offset(profile_id, action, elapsed, facing, 1.0, true)
					check(offset.length() <= 1.5, "gait interpolation never becomes a large body displacement")
					check(offset.distance_to(previous) <= 0.16, "fractional gait advances smoothly without a pose-position snap")
					check(reduced.length() <= offset.length() + 0.0001, "reduced mode retains the same phase with quieter displacement")
					previous = offset
				equal(motion.locomotion_pivot_offset(profile_id, action, duration * 0.25, facing, 0.0), Vector2.ZERO, "stopped body cannot inherit a moving bob")


func _test_contact_weight_transfer() -> void:
	var motion := MinimalChampionMotion.new()
	check(motion.load_from_file(), "contact weight transfer uses all existing body profiles")
	for profile_id: String in motion.profiles:
		for action: String in ["walk", "sprint"]:
			var duration := float((motion.profiles[profile_id][action] as Dictionary)["duration_ticks"])
			for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
				var travel := Vector2(direction).normalized()
				var side := Vector2(-travel.y, travel.x)
				for phase: float in [0.0, 0.5, 1.0]:
					for delta: float in [-0.0001, 0.0001]:
						var near_plant := motion.locomotion_pivot_offset(profile_id, action, (phase + delta + 1.0) * duration, travel, 1.0)
						check(near_plant.length() < 0.00001, "all axes settle with zero velocity at either planted contact and the loop seam")
				var first := motion.locomotion_pivot_offset(profile_id, action, duration * 0.25, travel, 1.0)
				var second := motion.locomotion_pivot_offset(profile_id, action, duration * 0.75, travel, 1.0)
				var bob := (first + second) * 0.5
				check(absf(bob.x) < 0.0001 and bob.y < 0.0, "support shifts balance around the unchanged vertical body arc")
				check((first - bob).dot(side) > 0.15 and (second - bob).dot(side) < -0.15, "weight shifts between opposite support feet in every travel heading")
				for phase: float in [0.1, 0.25, 0.4, 0.6, 0.75, 0.9]:
					var elapsed := phase * duration
					var normal := motion.locomotion_pivot_offset(profile_id, action, elapsed, travel, 1.0)
					var partial := motion.locomotion_pivot_offset(profile_id, action, elapsed, travel, 0.25)
					var reduced := motion.locomotion_pivot_offset(profile_id, action, elapsed, travel, 1.0, true)
					check(partial.distance_to(normal * 0.25) < 0.0001, "acceleration and braking retain continuous proportional weight transfer")
					check(reduced.distance_to(normal * 0.25) < 0.0001, "reduced motion keeps the same support phase at quarter strength")
					var scaled_travel := motion.locomotion_pivot_offset(profile_id, action, elapsed, travel * 8.0, 1.0)
					check(scaled_travel.distance_to(normal) < 0.0001, "heading magnitude cannot inflate the bounded presentation offset")


func _test_invalid_micro_pivot() -> void:
	var motion := MinimalChampionMotion.new()
	check(motion.load_from_file(), "micro-pivot input guards load existing profiles")
	for elapsed: float in [NAN, INF, -INF]:
		equal(motion.locomotion_pivot_offset("buoyant_keeper", "walk", elapsed, Vector2.RIGHT, 1.0), Vector2.ZERO, "invalid time retains a stable planted pose")
	for response: float in [NAN, INF, -INF]:
		equal(motion.locomotion_pivot_offset("buoyant_keeper", "walk", 5.5, Vector2.RIGHT, response), Vector2.ZERO, "invalid response cannot displace a body")
	for direction: Vector2 in [Vector2.ZERO, Vector2(NAN, 1.0), Vector2(INF, 1.0)]:
		equal(motion.locomotion_pivot_offset("buoyant_keeper", "walk", 5.5, direction, 1.0), Vector2.ZERO, "missing or invalid travel retains grounded feet")
	for action: String in ["idle", "low", "air", "cast", "hit"]:
		equal(motion.locomotion_pivot_offset("buoyant_keeper", action, 5.5, Vector2.RIGHT, 1.0), Vector2.ZERO, "weight transfer cannot alter an action or airborne pose")
	equal(motion.locomotion_pivot_offset("missing", "walk", 5.5, Vector2.RIGHT, 1.0), Vector2.ZERO, "unknown profile does not invent a gait")
