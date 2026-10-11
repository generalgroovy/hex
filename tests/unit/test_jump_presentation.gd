extends FluxTestSuite


func run() -> int:
	_test_physical_height()
	_test_interpolation()
	_test_protection()
	_test_release_jump()
	_test_flight()
	_test_takeoff()
	return finish("jump-presentation")


func _test_physical_height() -> void:
	var config := SimConfig.new(120)
	var state := PlayerState.new()
	for height: int in [0, 1000, 35000, 90000, 130000, 180000]:
		state.air_height = height
		for stale_timer: int in [0, 1, 999]:
			state.hop_ticks = stale_timer
			var sample := JumpPresentation.sample(state, config)
			equal(sample.body_lift_pixels, float(height) / 1000.0, "physical height alone owns lift")
			equal(sample.active, height > 0, "timers cannot fabricate height")
			var reduced := JumpPresentation.sample(state, config, 0, true)
			equal(reduced.body_lift_pixels, float(height) / 1000.0 * JumpPresentation.REDUCED_HEIGHT_RATIO, "reduced motion keeps a physical-height cue")
			check(sample.shadow_scale.x <= JumpPresentation.NORMAL_APEX_SHADOW_SCALE.x, "shadow is bounded")
	check(not JumpPresentation.sample(null, config).active, "missing actor fails closed")
	check(not JumpPresentation.sample(state, null).active, "missing config fails closed")


func _test_interpolation() -> void:
	var config := SimConfig.new(120)
	var state := PlayerState.new()
	state.air_height = 48000
	state.air_vertical_velocity = 300000
	var before := state.canonical_values()
	for alpha: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
		equal(JumpPresentation.sample(state, config, alpha, false, 42000).body_lift_pixels, lerpf(42.0, 48.0, alpha), "only accepted endpoints interpolate")
	equal(JumpPresentation.sample(state, config, -2, false, 42000).body_lift_pixels, 42.0, "negative alpha clamps")
	equal(JumpPresentation.sample(state, config, 2, false, 42000).body_lift_pixels, 48.0, "large alpha clamps")
	equal(JumpPresentation.sample(state, config, 0, false, 150000).body_lift_pixels, 48.0, "large correction resets")
	equal(state.canonical_values(), before, "sampling never mutates authority")
	state.air_height = 0
	equal(JumpPresentation.sample(state, config, 0, false, 4000).body_lift_pixels, 0.0, "landing immediately reaches ground")
	state.air_height = 48000
	state.health = 0
	equal(JumpPresentation.sample(state, config).body_lift_pixels, 0.0, "defeat resets lift")


func _test_protection() -> void:
	var config := SimConfig.new(120)
	for height: int in [0, 18000, 90000]:
		for slide: int in [0, 1]:
			for dodge: int in [0, 1, config.milliseconds_to_ticks(MovementTuning.AIR_DODGE_DURATION_MS)]:
				for spawn: int in [0, 1]:
					var state := PlayerState.new()
					state.air_height = height
					state.slide_ticks = slide
					state.jump_protection_ticks = 999
					state.air_dodge_ticks = dodge
					state.spawn_protection_ticks = spawn
					equal(JumpPresentation.protection_ratio(state, config) > 0, spawn > 0 or MovementSystem.is_combat_intangible(state, config), "shield matches authority, never height or stale jump timers")


func _test_release_jump() -> void:
	var peaks: Array[float] = []
	for hold_ticks: int in [0, 36]:
		var world := SimWorld.new(120)
		var peak := 0.0
		for tick: int in 160:
			var held := SimCommand.HELD_JUMP if tick < hold_ticks else 0
			world.step([SimCommand.new(world.tick, 1, 0, 0, held, SimCommand.PRESSED_JUMP if tick == 0 else 0)])
			var state := world.player()
			var sample := JumpPresentation.sample(state, world.config)
			equal(sample.body_lift_pixels, float(state.air_height) / 1000.0, "release-jump renders authority every tick")
			check(not sample.protection_active, "jump height never promises immunity")
			if tick < hold_ticks:
				equal(sample.body_lift_pixels, 0.0, "held grounded Jump remains anticipation")
			peak = maxf(peak, sample.body_lift_pixels)
		peaks.append(peak)
		equal(world.player().air_height, 0, "jump returns to real ground")
	check(peaks[0] > 40 and peaks[0] < 52, "tap release reaches longer approximately47px apex")
	check(peaks[1] > peaks[0] + 8 and peaks[1] < 66, "bounded charge gives a distinct higher apex")


func _test_flight() -> void:
	var world := SimWorld.new(120)
	world.player().flight_capable = true
	var flight_ticks := 0
	for tick: int in 100:
		var before := world.player().air_height
		var held := SimCommand.HELD_JUMP if tick >= 8 and tick < 65 else 0
		var pressed := SimCommand.PRESSED_JUMP if tick in [0, 8] else 0
		world.step([SimCommand.new(world.tick, 1, 1000, 0, held, pressed)])
		var state := world.player()
		var sample := JumpPresentation.sample(state, world.config, 0.5, false, before)
		if state.air_floating:
			flight_ticks += 1
			check(not sample.protection_active, "flight has clearance, never universal shield")
			check(JumpPresentation.height_contract(state, world.config)["flight"], "flight shows its own finite budget")
			check(absi(before - state.air_height) < 5000, "flight does not snap height")
		if tick == 65:
			check(not state.air_floating, "release ends flight immediately")
	check(flight_ticks > 20, "fixture actually sustains flight")


func _test_takeoff() -> void:
	var config := SimConfig.new(120)
	var state := PlayerState.new()
	state.air_height = 55000
	state.air_vertical_velocity = 250000
	state.hop_mode = PlayerState.MovementMode.HOP
	var total := config.milliseconds_to_ticks(MovementTuning.HOP_COMMITMENT_MS)
	for reduced: bool in [false, true]:
		var last_radius := 0.0
		for remaining: int in range(total, 0, -1):
			state.movement_commitment_ticks = remaining
			var cue := JumpPresentation.takeoff_contract(state, config, reduced)
			check(cue["active"], "takeoff has a brief non-protection accent")
			check(float(cue["radius"]) >= last_radius, "ring expands once, never loops")
			check(float(cue["radius"]) <= (18.0 if reduced else 27.0), "accent is bounded")
			last_radius = float(cue["radius"])
		state.movement_commitment_ticks = 0
		check(not JumpPresentation.takeoff_contract(state, config, reduced)["active"], "accent ends with commitment")
	state.movement_commitment_ticks = total
	state.air_vertical_velocity = -100000
	check(not JumpPresentation.takeoff_contract(state, config)["active"], "descent cannot replay takeoff")
