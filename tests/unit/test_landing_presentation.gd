extends FluxTestSuite


func run() -> int:
	_test_inactive_and_intensity_contract()
	_test_phase_and_reduced_motion()
	_test_120hz_phase_integrity()
	_test_sampler_does_not_mutate_authority()
	_test_directional_puffs()
	return finish("landing-presentation")


func _test_inactive_and_intensity_contract() -> void:
	var grounded := LandingPresentation.sample(PlayerState.new(), SimConfig.new(120))
	check(not grounded.active, "ordinary grounded state has no landing pulse")
	_near(grounded.ring_opacity, 0.0, "inactive landing pulse is transparent")

	var light := _sample_at_phase(120, 400, 0.0)
	var heavy := _sample_at_phase(120, 1000, 0.0)
	check(light.active and heavy.active, "positive canonical intensity activates landing presentation")
	check(heavy.ring_opacity > light.ring_opacity, "strong landing is more legible than light landing")
	check(heavy.shadow_scale.x > light.shadow_scale.x, "strong landing produces broader impact shadow")


func _test_phase_and_reduced_motion() -> void:
	var start := _sample_at_phase(120, 1000, 0.0)
	var middle := _sample_at_phase(120, 1000, 0.5)
	var end := _sample_at_phase(120, 1000, 0.9)
	check(middle.ring_radius > start.ring_radius, "landing ring expands after contact")
	check(end.ring_radius > middle.ring_radius, "landing ring continues expanding through recovery")
	check(middle.ring_opacity < start.ring_opacity, "landing ring fades after contact")
	check(end.ring_opacity < middle.ring_opacity, "landing ring finishes with a restrained fade")

	var reduced := _sample_at_phase(120, 1000, 0.5, true)
	check(reduced.active, "reduced motion retains landing timing information")
	check(reduced.ring_radius < middle.ring_radius, "reduced motion limits ring travel")
	check(reduced.ring_opacity < middle.ring_opacity, "reduced motion limits impact intensity")
	_near(reduced.ring_width, LandingPresentation.REDUCED_RING_WIDTH, "reduced motion uses the restrained stroke")


func _test_120hz_phase_integrity() -> void:
	for phase: float in [0.0, 0.25, 0.5, 0.75]:
		var at_120 := _sample_at_phase(120, 820, phase)
		_near(at_120.normalized_phase, phase, "120 Hz landing reaches requested phase")
		check(at_120.ring_radius >= LandingPresentation.MINIMUM_RING_RADIUS, "120 Hz landing ring stays inside its authored phase envelope")
		check(at_120.shadow_scale.x >= LandingPresentation.BASE_SHADOW_SCALE.x, "120 Hz landing retains contact weight")


func _test_sampler_does_not_mutate_authority() -> void:
	var state := PlayerState.new()
	state.position_x = 377_000
	state.position_y = 411_000
	state.landing_ticks = SimConfig.new(120).milliseconds_to_ticks(MovementTuning.LANDING_WINDOW_MS)
	state.landing_intensity = 880
	var before := state.canonical_values()
	LandingPresentation.sample(state, SimConfig.new(120), 0.5)
	equal(state.canonical_values(), before, "landing sampling never mutates canonical state")
	equal(state.position_x, 377_000, "landing sampling preserves collision x")
	equal(state.position_y, 411_000, "landing sampling preserves collision y")


func _sample_at_phase(
	tick_rate: int,
	intensity: int,
	phase: float,
	reduced_motion: bool = false,
) -> LandingPresentation.Sample:
	var config := SimConfig.new(tick_rate)
	var state := PlayerState.new()
	var total_ticks := config.milliseconds_to_ticks(MovementTuning.LANDING_WINDOW_MS)
	var remaining_fractional := float(total_ticks) * (1.0 - phase)
	state.landing_ticks = ceili(remaining_fractional)
	state.landing_intensity = intensity
	var interpolation_alpha := float(state.landing_ticks) - remaining_fractional
	return LandingPresentation.sample(state, config, interpolation_alpha, reduced_motion)


func _near(actual: float, expected: float, message: String) -> void:
	check(is_equal_approx(actual, expected), "%s (expected=%s actual=%s)" % [message, expected, actual])


func _test_directional_puffs() -> void:
	var config := SimConfig.new(120)
	for fixed: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		var state := PlayerState.new()
		state.velocity_x = fixed.x * 400
		state.velocity_y = fixed.y * 400
		state.facing_x = -fixed.x
		state.facing_y = -fixed.y
		state.landing_ticks = 7
		state.landing_intensity = 900
		var sample := LandingPresentation.sample(state, config)
		var reduced := LandingPresentation.sample(state, config, 0.0, true)
		check(sample.travel_direction.is_equal_approx(Vector2(fixed).normalized()), "landing dust follows real coast even when body input reverses")
		equal(sample.puff_offsets.size(), 3, "normal landing has exactly three restrained puffs")
		equal(reduced.puff_offsets.size(), 1, "reduced landing preserves one contact puff")
		for offset: Vector2 in sample.puff_offsets:
			check(offset.dot(sample.travel_direction) < 0.0, "landing cloud stays behind the escape direction")
			check(offset.length() < 30.0, "landing cloud cannot fill neighboring lanes")
		check(sample.puff_opacity <= LandingPresentation.NORMAL_MAXIMUM_OPACITY * 0.80, "landing puff stays subordinate to active threats")
		check(sample.puff_radius <= 6.5, "dust lobes remain small enough to leave nearby threats clear")
	check(not LandingPresentation.sample(null, config).active, "missing landing actor fails closed")
