extends FluxTestSuite

const GroundSkid = preload("res://src/presentation/ground_skid_presentation.gd")


func run() -> int:
	_test_inactive_and_intensity_contract()
	_test_phase_and_reduced_motion()
	_test_120hz_phase_integrity()
	_test_sampler_does_not_mutate_authority()
	_test_directional_puffs()
	_test_pixel_contact_force_and_accessibility()
	_test_contact_lifecycle()
	_test_ground_skid_contacts()
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


func _test_pixel_contact_force_and_accessibility() -> void:
	var config := SimConfig.new(120)
	var light := _sample_at_phase(120, 250, 0.0)
	var heavy := _sample_at_phase(120, 1000, 0.0)
	check(heavy.contact_width > light.contact_width, "canonical landing force changes actual pixel contact width")
	check(heavy.contact_opacity > light.contact_opacity, "canonical landing force changes actual pixel contact contrast")
	check(heavy.contact_height > _sample_at_phase(120, 1000, 0.75).contact_height, "landing compression settles in floor pixels without resizing the body")
	equal(_sample_at_phase(120, 1000, 0.0, true).contact_height, _sample_at_phase(120, 1000, 0.75, true).contact_height, "reduced landing compression keeps floor geometry still")
	for fixed: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		for reduced: bool in [false, true]:
			var state := PlayerState.new()
			state.velocity_x = fixed.x * 400
			state.velocity_y = fixed.y * 400
			state.facing_x = -fixed.x
			state.facing_y = -fixed.y
			state.landing_ticks = config.milliseconds_to_ticks(MovementTuning.LANDING_WINDOW_MS)
			state.landing_intensity = 900
			var opening := LandingPresentation.sample(state, config, 0.0, reduced)
			var direction := Vector2(fixed).normalized()
			equal(opening.contact_offsets.size(), 2, "both settings retain exactly two open pixel contacts")
			equal(opening.reduced_effects, reduced, "sample explicitly carries the effects variant to drawing")
			check(opening.dust_offset.dot(direction) < 0.0, "existing dust is biased behind actual coast, not aim")
			check(opening.dust_offset.length() <= 4.0, "dust attachment never becomes a travel wake")
			for offset: Vector2 in opening.contact_offsets:
				check(offset.dot(direction) < 0.0, "pixel contacts leave the forward escape lane open")
				check(offset.length() + float(opening.contact_width) < 24.0, "contact pixels remain local to the feet")
			state.landing_ticks = 2
			var late := LandingPresentation.sample(state, config, 0.0, reduced)
			check(late.contact_opacity < opening.contact_opacity, "contact fades monotonically within the accepted landing")
			if reduced:
				equal(late.contact_offsets, opening.contact_offsets, "Reduced Effects reads force/direction without moving contact geometry")
			else:
				check(late.contact_offsets[0].length() > opening.contact_offsets[0].length(), "normal contact has a small bounded outward settle")


func _test_contact_lifecycle() -> void:
	var config := SimConfig.new(120)
	var state := PlayerState.new()
	state.landing_ticks = config.milliseconds_to_ticks(MovementTuning.LANDING_WINDOW_MS)
	state.landing_intensity = 1000
	var before := state.canonical_values()
	for reduced: bool in [false, true]:
		LandingPresentation.sample(state, config, 0.5, reduced)
		equal(state.canonical_values(), before, "pixel contact sampling leaves every authority field unchanged")
	state.health = 0
	var dead := LandingPresentation.sample(state, config)
	check(not dead.active and dead.contact_offsets.is_empty(), "death hides stale landing contact immediately")
	state.health = 1000
	state.landing_ticks = 0
	var ended := LandingPresentation.sample(state, config)
	check(not ended.active and ended.contact_offsets.is_empty(), "landing expiry leaves no contact residue or retained emitter")


func _test_ground_skid_contacts() -> void:
	for fixed: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		for sliding: bool in [false, true]:
			var state := PlayerState.new()
			state.velocity_x = fixed.x * 400
			state.velocity_y = fixed.y * 400
			state.facing_x = -fixed.x
			state.facing_y = -fixed.y
			state.movement_mode = PlayerState.MovementMode.SLIDE if sliding else PlayerState.MovementMode.WAVE_DASH
			state.slide_ticks = 20 if sliding else 0
			state.wave_dash_ticks = 0 if sliding else 20
			var authority := state.canonical_values()
			for phase: float in [0.0, 0.125, 0.25, 0.5, 0.75, 1.0, 4.5]:
				var normal: Dictionary = GroundSkid.sample(state, phase)
				var reduced: Dictionary = GroundSkid.sample(state, phase, true)
				check(not normal.is_empty() and not reduced.is_empty(), "all eight actual coast headings retain compact ground contacts")
				check(normal.direction.is_equal_approx(Vector2(fixed).normalized()), "ground skid direction follows retained velocity, never opposite aim/facing")
				equal(normal.width, reduced.width, "reduced contacts keep the same speed-readable contact width")
				equal(normal.draw_commands, 6, "normal skid uses exactly six bounded primitive commands")
				equal(reduced.draw_commands, 2, "reduced skid uses one still two-tone heel contact")
				check(normal.opacity <= 0.48 and reduced.opacity <= normal.opacity, "skid contact stays subordinate to threats")
				for offset: Vector2 in normal.offsets:
					check(offset.dot(normal.direction) < 0.0, "skid pixels leave the forward escape lane open")
					check(offset.length() + normal.width + 5.0 <= GroundSkid.MAX_EXTENT, "all heel/chip pixels stay local, never a retained movement wake")
				equal(GroundSkid.sample(state, phase, true), GroundSkid.sample(state, 0.0, true), "reduced geometry and contrast do not animate with distance phase")
				equal(state.canonical_values(), authority, "ground contacts cannot change mechanics or sprite body parameters")
			var fast: Dictionary = GroundSkid.sample(state, 0.0)
			for aim: Vector2i in EightDirectionResolver.FIXED_VECTORS:
				state.facing_x = aim.x
				state.facing_y = aim.y
				equal(GroundSkid.sample(state, 0.0), fast, "all eight aim headings preserve the same accepted slide/wave-dash contact")
			state.velocity_x = fixed.x * 80
			state.velocity_y = fixed.y * 80
			var slow: Dictionary = GroundSkid.sample(state, 0.0)
			check(slow.width < fast.width and slow.opacity < fast.opacity, "slower real coast produces quieter smaller floor marks, not a full-speed dust loop")
			state.air_height = 1000
			check(GroundSkid.sample(state).is_empty(), "airborne motion cannot paint a false ground contact")
			state.air_height = 0
			state.velocity_x = 0
			state.velocity_y = 0
			check(GroundSkid.sample(state).is_empty(), "stopped actor leaves no loop or lingering contact")
	var idle := PlayerState.new()
	for mode: int in [PlayerState.MovementMode.WALK, PlayerState.MovementMode.SPRINT]:
		idle.movement_mode = mode
		idle.velocity_x = MovementTuning.BASE_SPEED
		for aim: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			idle.facing_x = aim.x
			idle.facing_y = aim.y
			check(GroundSkid.sample(idle, 0.25).is_empty(), "walking/coasting while aiming backward is not evidence of braking")
	idle.velocity_x = 0
	check(GroundSkid.sample(idle).is_empty() and GroundSkid.sample(null).is_empty(), "idle/missing actors have no ground decoration")
	for phase: float in [NAN, INF, -INF]:
		check(GroundSkid.sample(idle, phase).is_empty(), "nonfinite phase cannot reach drawing")
	equal(GroundSkid.draw(null, Vector2.ZERO, {}, null), 0, "missing draw dependencies are a bounded no-op")
