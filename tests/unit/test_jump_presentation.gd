extends FluxTestSuite


func run() -> int:
	_test_physical_height()
	_test_interpolation_and_resets()
	_test_mode_continuity_and_reduced_motion()
	_test_immediate_protection()
	_test_protection_matches_authority_with_overlaps()
	_test_real_tap_and_hold()
	_test_real_float_and_dodge_continuity()
	_test_float_and_takeoff_contract()
	_test_real_float_release_cue()
	return finish("jump-presentation")


func _test_physical_height() -> void:
	var config := SimConfig.new(120)
	var state := PlayerState.new()
	for height: int in [0, 1000, 35_000, 90_000, 130_000, 180_000]:
		state.air_height = height
		for stale_timer: int in [0, 1, 999]:
			state.hop_ticks = stale_timer
			state.jump_sustain_ticks = stale_timer
			var sample := JumpPresentation.sample(state, config)
			equal(sample.body_lift_pixels, float(height) / 1000.0, "physical height alone owns body lift")
			equal(sample.active, height > 0, "timers cannot fabricate airborne height")
	check(not JumpPresentation.sample(null, config).active, "missing actor fails closed")
	check(not JumpPresentation.sample(state, null).active, "missing configuration fails closed")


func _test_interpolation_and_resets() -> void:
	var config := SimConfig.new(120)
	var state := PlayerState.new()
	state.air_height = 48_000
	state.air_vertical_velocity = 300_000
	var before := state.canonical_values()
	for alpha: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
		equal(JumpPresentation.sample(state, config, alpha, false, 42_000).body_lift_pixels, lerpf(42.0, 48.0, alpha), "height interpolates only previous-to-current accepted positions")
	equal(JumpPresentation.sample(state, config, -2.0, false, 42_000).body_lift_pixels, 42.0, "negative alpha clamps")
	equal(JumpPresentation.sample(state, config, 2.0, false, 42_000).body_lift_pixels, 48.0, "alpha cannot extrapolate")
	equal(JumpPresentation.sample(state, config, 0.0).body_lift_pixels, 48.0, "missing previous height uses current")
	equal(JumpPresentation.sample(state, config, 0.0, false, 150_000).body_lift_pixels, 48.0, "large correction resets")
	equal(state.canonical_values(), before, "presentation never mutates authority")
	state.air_height = 0
	equal(JumpPresentation.sample(state, config, 0.0, false, 4000).body_lift_pixels, 0.0, "landing immediately reaches ground")
	state.air_height = 48_000
	state.health = 0
	equal(JumpPresentation.sample(state, config, 0.0, false, 42_000).body_lift_pixels, 0.0, "defeat resets visible height")


func _test_mode_continuity_and_reduced_motion() -> void:
	var config := SimConfig.new(120)
	var state := PlayerState.new()
	state.air_height = 76_000
	for mode: int in [PlayerState.MovementMode.HOP, PlayerState.MovementMode.DOUBLE_JUMP, PlayerState.MovementMode.AIR_DODGE, PlayerState.MovementMode.WALL_SKIM, PlayerState.MovementMode.WALL_KICK, PlayerState.MovementMode.FAST_FALL]:
		state.movement_mode = mode
		state.hop_mode = mode
		state.hop_ticks = 20
		state.air_dodge_ticks = 12 if mode == PlayerState.MovementMode.AIR_DODGE else 0
		state.wall_skim_ticks = 12 if mode == PlayerState.MovementMode.WALL_SKIM else 0
		for velocity: int in [-500_000, 0, 600_000]:
			state.air_vertical_velocity = velocity
			equal(JumpPresentation.sample(state, config).body_lift_pixels, 76.0, "mode or velocity changes cannot restart height")
	var last_shadow := JumpPresentation.GROUND_SHADOW_SCALE.x
	for height: int in [1000, 35_000, 90_000, 180_000]:
		state.air_height = height
		var normal := JumpPresentation.sample(state, config)
		var reduced := JumpPresentation.sample(state, config, 0.0, true)
		equal(reduced.body_lift_pixels, normal.body_lift_pixels * JumpPresentation.REDUCED_HEIGHT_RATIO, "reduced displacement keeps physical height ordering")
		check(normal.shadow_scale.x >= last_shadow, "rising height cannot shrink the ground reference")
		check(normal.shadow_scale.x <= JumpPresentation.NORMAL_APEX_SHADOW_SCALE.x, "double jump shadow remains bounded")
		check(reduced.shadow_scale.x <= JumpPresentation.REDUCED_APEX_SHADOW_SCALE.x, "reduced shadow remains bounded")
		last_shadow = normal.shadow_scale.x


func _test_immediate_protection() -> void:
	var config := SimConfig.new(120)
	var state := PlayerState.new()
	state.air_height = 90_000
	state.hop_ticks = 30
	state.jump_protection_ticks = config.milliseconds_to_ticks(MovementTuning.JUMP_INVULNERABILITY_MS)
	for alpha: float in [0.0, 0.5, 1.0]:
		check(JumpPresentation.sample(state, config, alpha, false, 89_000).protection_active, "opening cue ignores height interpolation delay")
	state.jump_protection_ticks = 0
	check(not JumpPresentation.sample(state, config, 0.0, false, 89_000).protection_active, "expired opening has no interpolation tail")
	state.hop_mode = PlayerState.MovementMode.AIR_DODGE
	state.air_dodge_ticks = config.milliseconds_to_ticks(MovementTuning.AIR_DODGE_DURATION_MS)
	equal(JumpPresentation.protection_ratio(state, config), 1.0, "dodge owns protection while derived hop timer coexists")
	state.air_dodge_ticks = 1
	check(not JumpPresentation.sample(state, config).protection_active, "dodge movement can outlast protection")
	state.spawn_protection_ticks = 1
	check(JumpPresentation.sample(state, config).protection_active, "spawn safety is visibly protected")
	state.spawn_protection_ticks = 0
	check(not JumpPresentation.sample(state, config).protection_active, "spawn expiry leaves no shield")
	state.air_height = 0
	state.hop_ticks = 0
	state.hop_mode = PlayerState.MovementMode.ROLL
	state.air_dodge_ticks = config.milliseconds_to_ticks(MovementTuning.ROLL_DURATION_MS)
	var roll := JumpPresentation.sample(state, config)
	check(not roll.active and roll.protection_active, "roll protection cannot fabricate airborne height")


func _test_protection_matches_authority_with_overlaps() -> void:
	var config := SimConfig.new(120)
	for hop: int in [0, 1]:
		for jump_protection: int in [0, 1]:
			for slide: int in [0, 1]:
				for cooldown: int in [0, config.milliseconds_to_ticks(MovementTuning.SLIDE_COOLDOWN_MS)]:
					for dodge: int in [0, 1, config.milliseconds_to_ticks(MovementTuning.AIR_DODGE_DURATION_MS)]:
						for spawn: int in [0, 1]:
							var state := PlayerState.new()
							state.hop_ticks = hop
							state.jump_protection_ticks = jump_protection
							state.slide_ticks = slide
							state.slide_cooldown_ticks = cooldown
							state.air_dodge_ticks = dodge
							state.spawn_protection_ticks = spawn
							equal(JumpPresentation.protection_ratio(state, config) > 0.0, spawn > 0 or MovementSystem.is_combat_intangible(state, config), "overlapping timers never disagree with actual protection authority")


func _test_real_tap_and_hold() -> void:
	var peaks: Array[float] = []
	for held: bool in [false, true]:
		var world := SimWorld.new(120)
		var peak := 0.0
		var protected_ticks := 0
		for index: int in range(150):
			world.step([SimCommand.new(world.tick, 1, 0, 0, SimCommand.HELD_JUMP if held else 0, SimCommand.PRESSED_JUMP if index == 0 else 0)])
			var sample := JumpPresentation.sample(world.player(), world.config)
			peak = maxf(peak, sample.body_lift_pixels)
			equal(sample.body_lift_pixels, float(world.player().air_height) / 1000.0, "real simulation height is rendered every tick")
			if sample.protection_active:
				protected_ticks += 1
		peaks.append(peak)
		check(protected_ticks <= world.config.milliseconds_to_ticks(MovementTuning.JUMP_INVULNERABILITY_MS), "longer height cannot extend protection")
		equal(JumpPresentation.sample(world.player(), world.config).body_lift_pixels, 0.0, "real jump returns to ground")
	check(peaks[1] >= 28.0 and peaks[1] <= 30.0, "held low jump reaches the requested approximately twenty-nine-pixel apex")
	check(peaks[0] >= 21.0 and peaks[0] <= 23.0, "tap low jump reaches the requested approximately twenty-two-pixel apex")
	check(peaks[1] - peaks[0] >= 6.0 and peaks[1] - peaks[0] <= 8.0, "new low tap and hold preserve a clear six-to-eight-pixel height choice")


func _test_real_float_and_dodge_continuity() -> void:
	var world := SimWorld.new(120)
	var float_seen := false
	var dodge_seen := false
	for index: int in range(150):
		var before := world.player().air_height
		var held := SimCommand.HELD_JUMP if index < 50 and index != 19 else 0
		var pressed := SimCommand.PRESSED_JUMP if index in [0, 20] else SimCommand.PRESSED_EVADE if index == 35 else 0
		world.step([SimCommand.new(world.tick, 1, 1000, 0, held, pressed)])
		var state := world.player()
		if index in [20, 35]:
			check(before > MovementTuning.GROUND_PROJECTILE_CLEARANCE_HEIGHT, "real transition occurs above the low-projectile clearance line")
			check(absi(state.air_height - before) < 12_000, "Float/dodge cannot snap the physical or visible height")
			var sample := JumpPresentation.sample(state, world.config, 0.5, false, before)
			check(sample.body_lift_pixels >= float(mini(before, state.air_height)) / 1000.0 and sample.body_lift_pixels <= float(maxi(before, state.air_height)) / 1000.0, "transition frame remains between its actual height endpoints")
		if state.air_floating:
			float_seen = true
			equal(state.air_height, before, "real Float preserves the height already earned")
			equal(JumpPresentation.protection_ratio(state, world.config), 1.0, "Float protection is continuous while actively paid")
		if state.air_dodge_ticks > 0 and not state.is_rolling():
			dodge_seen = true
	check(float_seen, "continuity test actually entered Float")
	check(dodge_seen, "continuity test actually entered airborne dodge")


func _test_float_and_takeoff_contract() -> void:
	var config := SimConfig.new(120)
	var state := PlayerState.new()
	state.air_height = 55_000
	state.air_vertical_velocity = 250_000
	state.hop_ticks = 40
	var total := config.milliseconds_to_ticks(MovementTuning.JUMP_INVULNERABILITY_MS)
	for reduced: bool in [false, true]:
		var last_radius := 0.0
		for remaining: int in range(total, 0, -1):
			state.jump_protection_ticks = remaining
			var cue := JumpPresentation.takeoff_contract(state, config, reduced)
			check(bool(cue["active"]), "accepted ascending takeoff has a short floor ring")
			check(float(cue["radius"]) >= last_radius, "takeoff ring advances once, never loops")
			check(float(cue["radius"]) <= (18.0 if reduced else 27.0), "takeoff ring has a strict spatial bound")
			last_radius = float(cue["radius"])
		state.jump_protection_ticks = 0
		check(not bool(JumpPresentation.takeoff_contract(state, config, reduced)["active"]), "takeoff ring finishes with its accepted opening")
		state.air_floating = true
		state.float_used = true
		state.float_ticks = 120
		for stale_timer: int in [0, 1, 100]:
			state.jump_protection_ticks = stale_timer
			equal(JumpPresentation.protection_ratio(state, config), 1.0, "active Float does not fade with stale jump protection clocks")
			check(not bool(JumpPresentation.takeoff_contract(state, config, reduced)["active"]), "Float cannot replay takeoff ring")
		state.jump_protection_ticks = 0
		state.air_floating = false
		equal(JumpPresentation.protection_ratio(state, config), 0.0, "Float release removes protection immediately")
	state.jump_protection_ticks = total
	state.air_vertical_velocity = -100_000
	check(not bool(JumpPresentation.takeoff_contract(state, config)["active"]), "descent cannot replay takeoff accent")


func _test_real_float_release_cue() -> void:
	var world := SimWorld.new(120)
	var float_ticks := 0
	for index: int in range(100):
		var before := world.player().air_height
		var held := SimCommand.HELD_JUMP if index < 70 and index != 19 else 0
		var pressed := SimCommand.PRESSED_JUMP if index in [0, 20] else 0
		world.step([SimCommand.new(world.tick, 1, 1000 if index < 40 else 0, 0 if index < 40 else 1000, held, pressed)])
		var state := world.player()
		var sample := JumpPresentation.sample(state, world.config, 0.0, false, before)
		if state.air_floating:
			float_ticks += 1
			check(sample.protection_active, "every actually paid Float tick keeps a steady shield")
			equal(sample.body_lift_pixels, float(before) / 1000.0, "Float steering never changes the attained visual height")
		if index == 70:
			check(state.air_height > MovementTuning.GROUND_PROJECTILE_CLEARANCE_HEIGHT, "release test remains visibly above the low-projectile clearance line")
			check(not state.air_floating and not sample.protection_active, "release cue ends immediately even when height interpolation is one sample behind")
	check(float_ticks >= 45, "release test actually holds Float beyond the original jump opening")
