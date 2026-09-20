extends FluxTestSuite


const History = preload("res://src/presentation/actor_motion_history.gd")


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
	return finish("actor-motion-history")


func _test_gait_frame_rate_parity() -> void:
	var phases: Array[float] = []
	for rate: int in [30, 60, 120, 240]:
		var history := History.new()
		var state := PlayerState.new(1)
		state.movement_mode = PlayerState.MovementMode.WALK
		state.velocity_x = 200_000
		var states: Array[PlayerState] = [state]
		var points := {1: Vector2.ZERO}
		var heights := {1: 68.0}
		var delta := 1.0 / float(rate)
		history.capture_gaits(states, points, heights, delta)
		for frame: int in range(rate):
			points[1] = Vector2(200.0 * float(frame + 1) / float(rate), 0.0)
			history.capture_gaits(states, points, heights, delta)
		phases.append(history.gait_phase(1))
	for phase: float in phases:
		check(absf(phase - fposmod(200.0 / 88.4, 1.0)) < 0.00001, "identical ground distance has identical gait at 30/60/120/240 visual samples per second")


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
			check(absf(history.gait_phase(1) - walk_delta - 2.0 / stride) < 0.00001, "walk-to-sprint and input reversal preserve contact progression instead of resetting phase")
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
	check(absf(history.gait_phase(1) - phase - 3.0 / 120.0) < 0.00001, "walking is limited to three readable visual cycles per second")
	phase = history.gait_phase(1)
	state.movement_mode = PlayerState.MovementMode.SPRINT
	points[1] += Vector2(30, 0)
	history.capture_gaits(states, points, heights, 1.0 / 120.0)
	check(absf(history.gait_phase(1) - phase - 5.0 / 120.0) < 0.00001, "sprint accelerates the same continuous phase to five cycles per second")
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
