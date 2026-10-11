extends FluxTestSuite


const History = preload("res://src/presentation/actor_motion_history.gd")
const Fullbody = preload("res://src/presentation/fullbody_cast_presenter.gd")
const Pixels = preload("res://src/presentation/pixel_flipbook_presenter.gd")


func run() -> int:
	var history := History.new()
	var state := PlayerState.new(2)
	state.champion_wire_id = 1
	state.position_x = 100_000
	state.position_y = 200_000
	state.air_height = 20_000
	var actors: Array[PlayerState] = [state]
	history.capture(actors)
	equal(history.sample(state, 0.0), Vector3(100, 200, 20), "new actor never flies in from an old origin")
	state.position_x += 10_000
	state.air_height += 6_000
	history.capture(actors)
	var canonical_before := state.canonical_values()
	equal(history.sample(state, 0.5), Vector3(105, 200, 23), "planar and elevation samples use the same slight interpolation")
	equal(history.previous_height(state), 20_000, "jump sampler receives exact fixed previous height")
	equal(history.sample(state, -2.0), Vector3(100, 200, 20), "negative alpha never extrapolates backwards")
	equal(history.sample(state, 2.0), Vector3(110, 200, 26), "late frames never extrapolate through cover")
	equal(state.canonical_values(), canonical_before, "render interpolation cannot mutate authority")
	state.position_x += 200_000
	history.capture(actors)
	equal(history.sample(state, 0.0), Vector3(310, 200, 26), "teleport snaps instead of sliding through the world")
	state.champion_wire_id = 2
	state.air_height = 0
	history.capture(actors)
	equal(history.previous_height(state), 0, "character switch resets old elevation")
	state.health = 0
	state.position_x += 1000
	history.capture(actors)
	equal(history.sample(state, 0.0).x, 311.0, "defeat has no delayed position trail")
	actors.clear()
	for entity_id: int in range(1, 12):
		actors.append(PlayerState.new(entity_id))
	history.capture(actors)
	equal(history.tracks.size(), 8, "history remains bounded to eight admitted champion tracks")
	actors.clear()
	history.capture(actors)
	equal(history.tracks.size(), 0, "disconnected actors leave no retained history")
	history.clear()
	_test_nearby_protected_spawn()
	_test_distance_gait()
	_test_gait_discontinuities_and_limits()
	_test_gait_frame_rate_parity()
	_test_ground_restart_contact()
	_test_start_stop_frame_rate_parity()
	_test_idle_ground_boundaries()
	_test_wall_contact_gait()
	_test_slowed_frame_sequence()
	_test_capped_contact_readability()
	return finish("actor-motion-history")


func _test_wall_contact_gait() -> void:
	for height: float in [58.0, 63.0, 68.0]:
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			var history := History.new()
			var state := PlayerState.new(1)
			state.wall_skim_ticks = 60
			state.air_height = 20000
			state.wall_skim_x = direction.x
			state.wall_skim_y = direction.y
			state.velocity_x = direction.x * 240
			state.velocity_y = direction.y * 240
			var states: Array[PlayerState] = [state]
			var points := {1: Vector2.ZERO}
			var heights := {1: height}
			history.capture_gaits(states, points, heights, 1.0 / 120.0)
			equal(history.wall_travel(1), direction, "wall entry owns tangent not cursor")
			points[1] = Vector2(direction).normalized() * 2.0
			history.capture_gaits(states, points, heights, 1.0 / 120.0)
			var phase := history.gait_phase(1)
			check(phase > 0.0, "real wall travel advances alternating support pose")
			state.wall_skim_x = 0
			state.wall_skim_y = 0
			state.velocity_x = 0
			state.velocity_y = 0
			for aim: Vector2i in EightDirectionResolver.FIXED_VECTORS:
				state.aim_x = aim.x
				state.aim_y = aim.y
				state.wall_skim_ticks -= 1
				var before := state.canonical_values()
				history.capture_gaits(states, points, heights, 1.0 / 120.0)
				equal(history.gait_phase(1), phase, "blocked wall feet hold while finite timer expires")
				equal(history.wall_travel(1), direction, "aim cannot rotate blocked attached body")
				equal(state.canonical_values(), before, "wall history never alters air budget or authority")
			state.velocity_x = -direction.x * 240
			history.rebase_gait(1)
			history.capture_gaits(states, points, heights, 1.0 / 120.0)
			equal(history.wall_travel(1), direction, "prediction correction preserves blocked wall support tangent")
			for gap: float in [0.0, 0.2]:
				history.capture_gaits(states, points, heights, gap)
				equal(history.wall_travel(1), direction, "zero or delayed frame cannot spin wall pose")
				equal(history.gait_phase(1), phase, "zero or delayed frame cannot add a wall step")
			state.velocity_y = -direction.y * 240
			points[1] = Vector2.ZERO
			history.capture_gaits(states, points, heights, 1.0 / 120.0)
			check(history.gait_phase(1) > phase, "travel after blocked wall resumes cadence")
			equal(history.wall_travel(1), -direction, "real wall turnaround updates support facing")
			state.wall_skim_ticks = 0
			history.capture_gaits(states, points, heights, 1.0 / 120.0)
			equal(history.wall_travel(1), Vector2i.ZERO, "ordinary flight drops stale wall tangent")
			phase = history.gait_phase(1)
			points[1] += Vector2(1, 0)
			history.capture_gaits(states, points, heights, 1.0 / 120.0)
			equal(history.gait_phase(1), phase, "ordinary flight never advances ground or wall feet")


func _test_gait_frame_rate_parity() -> void:
	var phases: Array[float] = []
	for rate: int in [30, 60, 120, 240]:
		var history := History.new()
		var state := PlayerState.new(1)
		state.movement_mode = PlayerState.MovementMode.WALK
		state.velocity_x = 120_000
		var states: Array[PlayerState] = [state]
		var points := {1: Vector2.ZERO}
		var heights := {1: 68.0}
		var delta := 1.0 / float(rate)
		history.capture_gaits(states, points, heights, delta)
		for frame: int in range(rate):
			points[1] = Vector2(120.0 * float(frame + 1) / float(rate), 0.0)
			history.capture_gaits(states, points, heights, delta)
		phases.append(history.gait_phase(1))
	for phase: float in phases:
		check(absf(phase - fposmod(120.0 / 88.4, 1.0)) < 0.00001, "identical ground distance has identical gait at 30/60/120/240 visual samples per second")


func _test_ground_restart_contact() -> void:
	var presenter := _gait_pixel_presenter()
	if presenter == null: return
	var history := History.new()
	var state := PlayerState.new(1)
	state.movement_mode = PlayerState.MovementMode.WALK
	state.velocity_x = 240_000
	state.aim_x = 1000
	state.aim_y = 0
	var states: Array[PlayerState] = [state]
	var points := {1: Vector2.ZERO}
	var heights := {1: 58.0}
	var config := SimConfig.new(120)
	var stride := MinimalChampionMotion.locomotion_stride_pixels(58.0)
	var delta := 1.0 / 120.0
	history.capture_gaits(states, points, heights, delta)
	# Compact contacts now release at 5/32, not the historical quarter phase.
	# Preserve this test's purpose: stop in contact A, then cross into its pass
	# on the first real displacement, without discarding that restart distance.
	for index: int in 12:
		points[1] = Vector2(stride * 0.14 * float(index + 1) / 12.0, 0)
		history.capture_gaits(states, points, heights, delta)
	var phase := history.gait_phase(1)
	check(absf(phase - 0.14) < 0.00001 and phase < 5.0 / 32.0, "actual ground travel stops within contact A before its centered release boundary")
	var contact: Dictionary = presenter.frame("one", state, 40.0, config, phase)
	equal(contact.components[0].source_region, Rect2(256, 221, 128, 35), "actual Fullbody path initially selects east-facing contact A")
	var historical_probe: Dictionary = presenter.frame("one", state, 40.0, config, 0.24)
	equal(historical_probe.components[0].source_region, Rect2(256, 93, 128, 35), "old quarter-boundary fixture phase now correctly lies inside the centered neutral pass")
	equal(history.gait_phase(1), phase, "an independent inspection phase cannot advance the live distance clock")
	state.movement_mode = PlayerState.MovementMode.IDLE
	state.velocity_x = 0
	history.capture_gaits(states, points, heights, delta)
	equal(history.gait_phase(1), phase, "stopping retains phase without a synthetic step")
	state.movement_mode = PlayerState.MovementMode.WALK
	state.velocity_x = 240_000
	points[1] += Vector2(2, 0)
	var before := state.canonical_values()
	history.capture_gaits(states, points, heights, delta)
	var resumed := history.gait_phase(1)
	check(absf(resumed - phase - minf(2.0 / stride, History.MAX_WALK_GAIT_CYCLES_PER_SECOND * delta)) < 0.00001, "the first actual displacement after idle counts immediately")
	check(resumed >= 5.0 / 32.0 and resumed < 11.0 / 32.0, "first travelled restart crosses the real contact-to-pass boundary")
	for reduced: bool in [false, true]:
		var next: Dictionary = presenter.frame("one", state, 40.0, config, resumed, reduced)
		equal(next.components[0].source_region, Rect2(256, 93, 128, 35), "first travelled restart frame reaches the existing neutral beat without a delayed contact flash")
		equal(next.components[1].source_region, Rect2(256, 0, 128, 93), "both immutable body regions consume the same restarted phase")
		equal(next.motion_phase, resumed, "Fullbody consumes the actual distance phase unchanged")
		check(not next.has("mesh") and not next.has("pose_blend"), "restart correction cannot morph or blend authored body pixels")
		equal(history.gait_phase(1), resumed, "render queries never advance the gait clock")
	equal(state.canonical_values(), before, "restart sampling changes no authoritative state")


func _gait_pixel_presenter() -> RefCounted:
	# Exercise the real Fullbody-to-pixel selector with an admitted synthetic
	# compact page and its resident same-identity base row. No roster imports,
	# generated art or heavyweight legacy mesh setup.
	var image := Image.create(1024, 512, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(image.get_data())
	var entry := {"id": "one", "body": "small", "display_height": 58,
		"waist_y": 93, "atlas": "gait.png", "rgba_sha256": hash.finish().hex_encode()}
	var manifest := {"id": Pixels.CAST_MANIFEST_ID, "schema_version": 1,
		"cell": [128, 128], "pivot": [64, 104], "rows": Pixels.CAST_ROWS.duplicate(),
		"directions": Pixels.DIRECTIONS.duplicate(), "characters": [entry]}
	var pixels := Pixels.new()
	var admitted := pixels.admit_manifest(manifest, ["one"], {"gait.png": texture})
	check(admitted, "restart fixture admits an ordinary compact ground bank: " + pixels.last_error)
	if not admitted: return null
	var presenter := Fullbody.new()
	presenter.entries = {"one": entry}
	presenter.motions = {"actions": {"walk": {"fps": 8, "frames": 4}}}
	presenter.pixel_pilot = pixels
	var probe := PlayerState.new(1)
	probe.movement_mode = PlayerState.MovementMode.WALK
	probe.velocity_x = 240_000
	var config := SimConfig.new(120)
	check(presenter.frame("one", probe, 40.0, config, 0.14).is_empty(), "Fullbody metadata and compact art alone cannot claim a nonresident base identity")
	var base_row := image.get_region(Rect2i(0, 0, 1024, 128))
	var base_texture := ImageTexture.create_from_image(base_row)
	presenter.textures = {"one": base_texture}
	equal(base_texture.get_size(), Vector2(1024, 128), "synthetic resident base row obeys the real Fullbody page dimensions")
	var admitted_frame: Dictionary = presenter.frame("one", probe, 40.0, config, 0.14)
	equal(admitted_frame.get("components", []).size(), 2, "resident Fullbody identity reaches both original compact body components")
	equal(admitted_frame.get("texture"), texture, "gait descriptor uses the independently admitted compact page rather than the base fallback")
	return presenter


func _test_start_stop_frame_rate_parity() -> void:
	for height: float in [58.0, 63.0, 68.0]:
		var stride := MinimalChampionMotion.locomotion_stride_pixels(height)
		var reference_phase := -1.0
		for rate: int in [30, 60, 120, 240]:
			var history := History.new()
			var state := PlayerState.new(1)
			var states: Array[PlayerState] = [state]
			var points := {1: Vector2.ZERO}
			var heights := {1: height}
			var delta := 1.0 / float(rate)
			var distance := 0.0
			history.capture_gaits(states, points, heights, delta)
			# All segment boundaries are shared by 30/60/120/240Hz. Speeds stay
			# below the slower cadence cap; 10px/s is canonical idle coasting.
			for speed: int in [0, 120, 0, -120, 0, 10, 0]:
				state.velocity_x = speed * 1000
				state.movement_mode = PlayerState.MovementMode.IDLE if absi(state.velocity_x) < MovementTuning.MOVING_MODE_MINIMUM_SPEED else PlayerState.MovementMode.WALK
				for _frame: int in roundi(float(rate) * 0.2):
					points[1] += Vector2(float(speed) * delta, 0)
					distance += absf(float(speed) * delta)
					var before := state.canonical_values()
					history.capture_gaits(states, points, heights, delta)
					check(absf(history.gait_phase(1) - fposmod(distance / stride, 1.0)) < 0.00001, "every start, stop and low-speed coast preserves actual ground distance at %dHz" % rate)
					equal(state.canonical_values(), before, "piecewise gait sampling preserves authority")
			check(absf(distance - 50.0) < 0.00001, "all frame rates sample the same 50px piecewise ground path")
			if reference_phase < 0.0: reference_phase = history.gait_phase(1)
			check(absf(history.gait_phase(1) - reference_phase) < 0.00001, "stopped/moving transitions remain frame-rate independent")


func _test_slowed_frame_sequence() -> void:
	var presenter := _gait_pixel_presenter()
	if presenter == null: return
	presenter.motions.actions.idle = {"fps": 4, "frames": 8}
	var config := SimConfig.new(120)
	for height: float in [58.0, 63.0, 68.0]:
		var stride := MinimalChampionMotion.locomotion_stride_pixels(height)
		for travel: int in 8:
			var heading := Vector2(EightDirectionResolver.FIXED_VECTORS[travel]).normalized()
			var aim := (travel + 3) % 8
			var reference_sequence: Array[Rect2] = []
			for rate: int in [30, 60, 120, 240]:
				var history := History.new()
				var state := PlayerState.new(1)
				state.aim_x = EightDirectionResolver.FIXED_VECTORS[aim].x
				state.aim_y = EightDirectionResolver.FIXED_VECTORS[aim].y
				var states: Array[PlayerState] = [state]
				var points := {1: Vector2.ZERO}
				var heights := {1: height}
				var delta := 1.0 / float(rate)
				var cycles := 0.0
				var distance := 0.0
				var segment_cycles: Array[float] = []
				var sequence: Array[Rect2] = []
				var sample_interval := roundi(float(rate) / 30.0)
				history.capture_gaits(states, points, heights, delta)
				for speed: int in [120, 24, 0, 120]:
					state.velocity_x = roundi(heading.x * speed * SimConfig.FIXED_SCALE)
					state.velocity_y = roundi(heading.y * speed * SimConfig.FIXED_SCALE)
					state.control_state = PlayerState.ControlState.SLOWED if speed == 24 else PlayerState.ControlState.FREE
					state.movement_mode = PlayerState.MovementMode.SLOWED if speed == 24 else (PlayerState.MovementMode.IDLE if speed == 0 else PlayerState.MovementMode.WALK)
					var authority := state.canonical_values()
					var segment_start := cycles
					var sample_count := roundi(float(rate) * (0.2 if speed == 0 else 0.4))
					for index: int in sample_count:
						var before := history.gait_phase(1)
						points[1] += heading * float(speed) * delta
						distance += float(speed) * delta
						history.capture_gaits(states, points, heights, delta)
						var phase := history.gait_phase(1)
						cycles += fposmod(phase - before, 1.0)
						check(absf(cycles - distance / stride) < 0.00001, "slowed/stop/restart sequence counts exact distance for every body tier and heading")
						if speed == 0: equal(phase, before, "stopped segment adds zero gait cycles at every frame rate")
						var frame: Dictionary = presenter.frame("one", state, 60.0, config, phase)
						var expected_step := 0
						if phase >= 5.0 / 32.0 and phase < 11.0 / 32.0: expected_step = 1
						elif phase >= 11.0 / 32.0 and phase < 21.0 / 32.0: expected_step = 2
						elif phase >= 21.0 / 32.0 and phase < 27.0 / 32.0: expected_step = 3
						var expected_row: int = [1, 0, 2, 0][expected_step] if speed > 0 else 0
						equal(frame.components[0].source_region, Rect2(aim * 128, expected_row * 128 + 93, 128, 35), "actual lower pixels follow the same uninterrupted phase through slowed control and restart")
						equal(frame.get("aim_index"), aim, "slowed timing cannot delay opposite independent aim")
						equal(frame.get("travel_index"), aim if speed == 0 else travel, "slowed timing preserves all eight physical travel headings")
						equal(frame.get("action"), "idle" if speed == 0 else "walk", "slowed locomotion remains a real walking gait, not a frozen control pose")
						equal(state.canonical_values(), authority, "quantitative slowed sequence leaves authority unchanged")
						if (index + 1) % sample_interval == 0: sequence.append(frame.components[0].source_region)
					segment_cycles.append(cycles - segment_start)
				# Vector2 anchors accumulate float32 rounding, then the ratio check
				# multiplies the slow segment error by five. Bound it in world units
				# to one hundredth of a pixel; the tighter per-frame distance and
				# exact common-frame sequence assertions above remain unchanged.
				check(absf((segment_cycles[0] - segment_cycles[1] * 5.0) * stride) < 0.01, "one-fifth speed gives one-fifth gait progression within 0.01px accumulated float32 tolerance (%dHz/%d/%.0fpx)" % [rate, travel, height])
				check(absf(segment_cycles[2]) < 0.00001, "stop adds no hidden catch-up phase")
				check(absf(segment_cycles[0] - segment_cycles[3]) < 0.00001, "restart retains the full first travelled sample")
				equal(sequence.size(), 42, "frame-sequence comparison samples the same 1.4-second journey at 30Hz")
				if rate == 30: reference_sequence = sequence
				else: equal(sequence, reference_sequence, "30/60/120/240Hz produce the same visible contact/neutral sequence at common samples")


func _test_capped_contact_readability() -> void:
	var presenter := _gait_pixel_presenter()
	if presenter == null: return
	presenter.motions.actions.sprint = {"fps": 8, "frames": 4}
	var config := SimConfig.new(120)
	for height: float in [58.0, 63.0, 68.0]:
		for mode: int in [PlayerState.MovementMode.WALK, PlayerState.MovementMode.SPRINT, PlayerState.MovementMode.WALL_SKIM]:
			for rate: int in [30, 60, 120, 240]:
				var history := History.new()
				var state := PlayerState.new(1)
				state.movement_mode = mode
				state.velocity_x = 900_000
				if mode == PlayerState.MovementMode.WALL_SKIM:
					state.wall_skim_ticks = 60
					state.wall_skim_x = 1000
					state.air_height = 20_000
				var before := state.canonical_values()
				var states: Array[PlayerState] = [state]
				var points := {1: Vector2.ZERO}
				var heights := {1: height}
				var delta := 1.0 / float(rate)
				var cycles := 0.0
				var expected_cycles := 2.0 if mode == PlayerState.MovementMode.WALK else 2.5
				var previous_region := Rect2()
				var run_length := 0
				var complete_runs := 0
				var has_left_initial_run := false
				history.capture_gaits(states, points, heights, delta)
				for index: int in rate:
					var previous_phase := history.gait_phase(1)
					points[1] = Vector2(900.0 * float(index + 1) / float(rate), 0.0)
					history.capture_gaits(states, points, heights, delta)
					cycles += fposmod(history.gait_phase(1) - previous_phase, 1.0)
					if rate == 30 and mode != PlayerState.MovementMode.WALL_SKIM:
						var frame: Dictionary = presenter.frame("one", state, float(index), config, history.gait_phase(1))
						var region: Rect2 = frame.components[0].source_region
						if run_length > 0 and region != previous_region:
							# The first and last observed runs may be partial. Only
							# fully observed keys establish the 30FPS dwell bound.
							if has_left_initial_run:
								check(run_length >= 2, "every complete capped contact/pass remains visible for at least two real 30FPS samples")
								complete_runs += 1
							has_left_initial_run = true
							run_length = 0
						previous_region = region
						run_length += 1
				check(absf(cycles - expected_cycles) < 0.00001, "extreme momentum retains the independent walk2.0/sprint-wall2.5 visual limit for every body and frame rate")
				if rate == 30 and mode != PlayerState.MovementMode.WALL_SKIM:
					check(complete_runs >= 2, "readability witness observes multiple complete contact and neutral keys, not a held or missing pose")
				equal(state.canonical_values(), before, "slower capped presentation never changes physical momentum, control or action timers")


func _test_idle_ground_boundaries() -> void:
	var history := History.new()
	var state := PlayerState.new(1)
	var states: Array[PlayerState] = [state]
	var points := {1: Vector2.ZERO}
	var heights := {1: 68.0}
	var delta := 1.0 / 120.0
	history.capture_gaits(states, points, heights, delta)
	points[1] += Vector2(0.5, 0)
	history.capture_gaits(states, points, heights, delta)
	equal(history.gait_phase(1), 0.0, "zero-speed idle cannot turn small interpolation/correction displacement into footsteps")
	state.velocity_x = 10_000
	points[1] += Vector2(10.0 * delta, 0)
	history.capture_gaits(states, points, heights, delta)
	var phase := history.gait_phase(1)
	check(phase > 0.0, "real sub-20px/s ground coast remains eligible in canonical IDLE mode")
	for boundary: String in ["rebase", "warp", "long_gap", "zero_delta"]:
		if boundary == "rebase": history.rebase_gait(1)
		points[1] += Vector2(100.0 if boundary == "warp" else 0.05, 0)
		var sample_delta := 0.2 if boundary == "long_gap" else (0.0 if boundary == "zero_delta" else delta)
		history.capture_gaits(states, points, heights, sample_delta)
		equal(history.gait_phase(1), phase, "idle eligibility does not relax discontinuity rejection: " + boundary)
	for boundary: String in ["air", "roll", "wall", "control"]:
		var isolated := History.new()
		var actor := PlayerState.new(2)
		actor.velocity_x = 120_000
		match boundary:
			"air": actor.air_height = 1000
			"roll":
				actor.air_dodge_ticks = 10
				actor.hop_mode = PlayerState.MovementMode.ROLL
			"wall":
				actor.wall_skim_ticks = 10
				actor.wall_skim_x = 1000
			"control": actor.control_state = PlayerState.ControlState.ROOTED
		var actors: Array[PlayerState] = [actor]
		var anchors := {2: Vector2.ZERO}
		isolated.capture_gaits(actors, anchors, heights, delta)
		actor.air_height = 0
		actor.air_dodge_ticks = 0
		actor.wall_skim_ticks = 0
		actor.control_state = PlayerState.ControlState.FREE
		actor.landing_ticks = 8
		anchors[2] += Vector2(1, 0)
		isolated.capture_gaits(actors, anchors, heights, delta)
		equal(isolated.gait_phase(2), 0.0, "first mixed landing/control/wall segment is still excluded: " + boundary)
		anchors[2] += Vector2(1, 0)
		isolated.capture_gaits(actors, anchors, heights, delta)
		check(isolated.gait_phase(2) > 0.0, "confirmed ground travel resumes normally after " + boundary)


func _test_distance_gait() -> void:
	for height: float in [58.0, 68.0, 76.0]:
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			var history := History.new()
			var state := PlayerState.new(1)
			state.movement_mode = PlayerState.MovementMode.WALK
			state.velocity_x = direction.x * 240
			state.velocity_y = direction.y * 240
			state.facing_x = direction.x
			state.facing_y = direction.y
			var states: Array[PlayerState] = [state]
			var point := Vector2(100, 100)
			var points := {1: point}
			var heights := {1: height}
			history.capture_gaits(states, points, heights, 1.0 / 120.0)
			equal(history.gait_phase(1), 0.0, "new body/direction starts at planted contact A")
			var stride := MinimalChampionMotion.locomotion_stride_pixels(height)
			var travel := Vector2(direction).normalized() * 2.0
			point += travel
			points[1] = point
			history.capture_gaits(states, points, heights, 1.0 / 120.0)
			var walk_delta := minf(2.0 / stride, History.MAX_WALK_GAIT_CYCLES_PER_SECOND / 120.0)
			check(absf(history.gait_phase(1) - walk_delta) < 0.00001, "all headings advance by actual distance under the readable walking cadence limit")
			var phase := history.gait_phase(1)
			for unused_index: int in range(20):
				equal(history.gait_phase(1), phase, "repeated render queries are read-only")
			history.capture_gaits(states, points, heights, 1.0 / 120.0)
			equal(history.gait_phase(1), phase, "blocked body cannot march in place even when desired velocity is nonzero")
			state.movement_mode = PlayerState.MovementMode.SPRINT
			state.facing_x = -direction.x
			state.facing_y = -direction.y
			point += travel
			points[1] = point
			history.capture_gaits(states, points, heights, 1.0 / 120.0)
			check(absf(history.gait_phase(1) - walk_delta - minf(2.0 / stride, 2.5 / 120.0)) < 0.00001, "walk-to-sprint and input reversal preserve contact progression instead of resetting phase")
			phase = history.gait_phase(1)
			state.movement_mode = PlayerState.MovementMode.IDLE
			state.velocity_x = 0
			state.velocity_y = 0
			history.capture_gaits(states, points, heights, 0.05)
			equal(history.gait_phase(1), phase, "ordinary idle preserves the next support foot")
			state.movement_mode = PlayerState.MovementMode.WALK
			state.velocity_x = direction.x * 240
			state.velocity_y = direction.y * 240
			history.capture_gaits(states, points, heights, 1.0 / 120.0)
			equal(history.gait_phase(1), phase, "resume does not invent a step before travel")
			var canonical := state.canonical_values()
			point += travel
			points[1] = point
			history.capture_gaits(states, points, heights, 1.0 / 120.0)
			equal(state.canonical_values(), canonical, "gait history never changes gameplay state")


func _test_gait_discontinuities_and_limits() -> void:
	var history := History.new()
	var state := PlayerState.new(1)
	state.champion_wire_id = 1
	state.movement_mode = PlayerState.MovementMode.WALK
	state.velocity_x = 240_000
	var states: Array[PlayerState] = [state]
	var points := {1: Vector2.ZERO}
	var heights := {1: 68.0}
	history.capture_gaits(states, points, heights, 1.0 / 120.0)
	points[1] = Vector2(2, 0)
	history.capture_gaits(states, points, heights, 1.0 / 120.0)
	var phase := history.gait_phase(1)
	for action: int in [PlayerState.MovementMode.SLIDE, PlayerState.MovementMode.ROLL, PlayerState.MovementMode.HOP, PlayerState.MovementMode.AIR_DODGE, PlayerState.MovementMode.WALL_SKIM, PlayerState.MovementMode.LAUNCHED]:
		state.movement_mode = action
		points[1] += Vector2(2, 0)
		history.capture_gaits(states, points, heights, 1.0 / 120.0)
		equal(history.gait_phase(1), phase, "air/slide/roll/wallrun/lunge motion is not a ground footstep")
	state.movement_mode = PlayerState.MovementMode.WALK
	history.capture_gaits(states, points, heights, 1.0 / 120.0)
	points[1] += Vector2(100, 0)
	history.capture_gaits(states, points, heights, 1.0 / 120.0)
	equal(history.gait_phase(1), phase, "teleport rebases the anchor without fast-cycling")
	points[1] += Vector2(10, 0)
	history.capture_gaits(states, points, heights, 1.0 / 120.0)
	equal(history.gait_phase(1), phase, "smaller implausible network correction cannot count as travel")
	history.rebase_gait(1)
	points[1] += Vector2(2, 0)
	history.capture_gaits(states, points, heights, 1.0 / 120.0)
	equal(history.gait_phase(1), phase, "explicit local prediction correction preserves phase while rebasing")
	points[1] += Vector2(2, 0)
	history.capture_gaits(states, points, heights, 0.2)
	equal(history.gait_phase(1), phase, "long frame gap cannot fast-forward hidden steps")
	state.velocity_x = 4_000_000
	points[1] += Vector2(30, 0)
	history.capture_gaits(states, points, heights, 1.0 / 120.0)
	check(absf(history.gait_phase(1) - phase - 2.0 / 120.0) < 0.00001, "walking is limited to 2.0 visual cycles per second without delaying movement")
	phase = history.gait_phase(1)
	state.movement_mode = PlayerState.MovementMode.SPRINT
	points[1] += Vector2(30, 0)
	history.capture_gaits(states, points, heights, 1.0 / 120.0)
	check(absf(history.gait_phase(1) - phase - 2.5 / 120.0) < 0.00001, "sprint accelerates the same continuous phase to 2.5 visual cycles per second")
	state.movement_mode = PlayerState.MovementMode.WALK
	state.spawn_protection_ticks = 30
	history.capture_gaits(states, points, heights, 1.0 / 120.0)
	equal(history.gait_phase(1), 0.0, "nearby protected respawn returns to a stable plant")
	state.spawn_protection_ticks -= 1
	points[1] += Vector2(1, 0)
	history.capture_gaits(states, points, heights, 1.0 / 120.0)
	check(history.gait_phase(1) > 0.0, "ordinary protection countdown does not freeze walking")
	state.champion_wire_id = 2
	history.capture_gaits(states, points, heights, 1.0 / 120.0)
	equal(history.gait_phase(1), 0.0, "new character does not inherit the previous anatomy phase")
	states.clear()
	for entity_id: int in range(1, 14):
		var actor := PlayerState.new(entity_id)
		states.append(actor)
		points[entity_id] = Vector2.ZERO
	history.capture_gaits(states, points, heights, 1.0 / 120.0)
	equal(history.gait_tracks.size(), 8, "gait ownership remains bounded to eight admitted champions")
	states.clear()
	history.capture_gaits(states, points, heights, 1.0 / 120.0)
	equal(history.gait_tracks.size(), 0, "leaving actors release their gait tracks")


func _test_nearby_protected_spawn() -> void:
	for champion_wire: int in [1, 2, 3]: # Middle, Small, Large live templates.
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			var history := History.new()
			var state := PlayerState.new(2)
			state.champion_wire_id = champion_wire
			state.position_x = 512000
			state.position_y = 512000
			state.air_height = 20000
			var actors: Array[PlayerState] = [state]
			history.capture(actors)
			var spawn := Vector2i(state.position_x, state.position_y) + direction * 24
			state.reset_for_spawn(spawn, 30)
			state.facing_x = direction.x
			state.facing_y = direction.y
			history.capture(actors)
			var canonical_before := state.canonical_values()
			var expected := Vector3(spawn.x, spawn.y, 0) / 1000.0
			for alpha: float in [0.0, 0.25, 0.5, 1.0]:
				equal(history.sample(state, alpha), expected, "same-alive nearby protected spawn immediately resets position for every body/direction")
			equal(history.previous_height(state), 0, "nearby spawn cannot retain an old airborne elevation")
			equal(state.canonical_values(), canonical_before, "spawn presentation reset never changes facing, protection or gameplay")
			state.position_x += 2000
			state.position_y += 1000
			state.spawn_protection_ticks -= 1
			history.capture(actors)
			equal(history.sample(state, 0.5), expected + Vector3(1, 0.5, 0), "normal interpolation resumes while existing spawn protection counts down")
			# A restarted round can replenish protection before the previous timer
			# has expired; its small move is also a new spawn, not ordinary travel.
			spawn += direction * 8
			state.reset_for_spawn(spawn, 30)
			history.capture(actors)
			equal(history.sample(state, 0.0), Vector3(spawn.x, spawn.y, 0) / 1000.0, "replenished spawn protection resets an already-protected track")
			state.spawn_protection_ticks = 0
			state.air_height = 20000
			state.air_floating = true
			state.float_ticks = 60
			history.capture(actors)
			state.reset_for_spawn(spawn, 30)
			history.capture(actors)
			equal(history.sample(state, 0.0), Vector3(spawn.x, spawn.y, 0) / 1000.0, "same-position Float reset cannot retain airborne height")
			equal(history.sample(state, 0.5).z, 0.0, "same-position Float reset has no residual midpoint lift")
			equal(history.previous_height(state), 0, "jump presentation receives zero prior lift on same-position spawn")
