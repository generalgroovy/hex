extends FluxTestSuite


const Trails = preload("res://src/presentation/character_movement_trail.gd")


func run() -> int:
	equal(Trails.MAX_FRAME_DRAW_CALLS, 96, "two-tone wake stays within 96 bounded draw submissions")
	_test_actual_motion_and_draw_cadence()
	_test_speed_and_action_hierarchy()
	_test_lifecycle_and_privacy()
	_test_limits_and_rates()
	_test_visibility_interior()
	return finish("character-movement-trail")


func _actor(entity_id: int = 1) -> PlayerState:
	var actor := PlayerState.new(entity_id)
	actor.champion_wire_id = 1
	actor.velocity_x = 240_000
	actor.movement_mode = PlayerState.MovementMode.WALK
	return actor


func _observe(trails: RefCounted, authority: PlayerState, point: Vector2, delta: float = 1.0 / 30.0, motion: PlayerState = null) -> void:
	trails.begin_frame(delta)
	trails.observe(authority, authority if motion == null else motion, point, 68.0)
	trails.end_frame()


func _seed(trails: RefCounted, actor: PlayerState) -> void:
	_observe(trails, actor, Vector2.ZERO)
	_observe(trails, actor, Vector2(8, 0))


func _test_actual_motion_and_draw_cadence() -> void:
	for heading: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		var actor := _actor()
		var direction := Vector2(heading).normalized()
		actor.velocity_x = roundi(direction.x * 240_000)
		actor.velocity_y = roundi(direction.y * 240_000)
		var before := actor.canonical_values()
		var trails := Trails.new()
		_observe(trails, actor, Vector2.ZERO)
		equal(trails.segment_count(), 0, "new actors cannot project a trail behind their entry")
		_observe(trails, actor, direction * 8.0)
		equal(trails.segment_count(1), 1, "actual displayed travel emits in all eight headings")
		var segment = trails.tracks[1].segments[0]
		check(segment.start.distance_to(Vector2.ZERO) < 0.001, "wake begins at sampled display anchor")
		equal(segment.finish, direction * 8.0, "wake ends at actual display anchor rather than authority position")
		trails.observe(actor, actor, direction * 16.0, 68.0)
		equal(trails.segment_count(), 1, "repeated draw does not add samples")
		equal(segment.finish, direction * 8.0, "repeated draw does not rewrite sampled history")
		_observe(trails, actor, direction * 8.0)
		equal(trails.segment_count(), 1, "blocked display with stale velocity creates no trail")
		actor.aim_x = -heading.x
		actor.aim_y = -heading.y
		_observe(trails, actor, direction * 8.0)
		equal(trails.segment_count(), 1, "aim-only turn creates no trail")
		actor.aim_x = 1000
		actor.aim_y = 0
		equal(actor.canonical_values(), before, "presentation never mutates authority")
		for frame: int in range(8):
			_observe(trails, actor, direction * 8.0)
		equal(trails.segment_count(), 0, "stationary wake fully expires")
		_observe(trails, actor, direction * 4.0)
		equal(trails.segment_count(), 0, "backwards visual correction cannot imitate forward travel")


func _test_speed_and_action_hierarchy() -> void:
	var strengths: Array[float] = []
	for mode: int in [PlayerState.MovementMode.WALK, PlayerState.MovementMode.SPRINT, PlayerState.MovementMode.SLIDE, PlayerState.MovementMode.AIR_DODGE]:
		var actor := _actor()
		actor.movement_mode = mode
		actor.velocity_x = 240_000 if mode == PlayerState.MovementMode.WALK else 600_000
		actor.slide_ticks = 30 if mode == PlayerState.MovementMode.SLIDE else 0
		actor.air_dodge_ticks = 20 if mode == PlayerState.MovementMode.AIR_DODGE else 0
		var trails := Trails.new()
		_observe(trails, actor, Vector2.ZERO)
		_observe(trails, actor, Vector2(float(actor.velocity_x) / 30_000.0, 0))
		var segment = trails.tracks[1].segments[0]
		strengths.append(segment.strength)
		check(segment.lifetime <= 0.18, "all motion wakes have sub-200 ms lifetime")
		check(segment.start.distance_to(segment.finish) <= Trails.MAX_SEGMENT_PIXELS, "no stroke extends beyond bounded history")
	for index: int in range(1, strengths.size()):
		check(strengths[index] > strengths[index - 1], "run, slide and dodge progressively strengthen subtle wake")
	var slow := _actor()
	slow.movement_mode = PlayerState.MovementMode.SLIDE
	slow.slide_ticks = 30
	check(Trails._strength(slow, 600.0) > Trails._strength(slow, 120.0), "slide strength scales with actual displayed speed")
	var predicted := _actor()
	predicted.champion_wire_id = 0
	predicted.slide_ticks = 30
	var authority := _actor()
	var trails := Trails.new()
	_observe(trails, authority, Vector2.ZERO, 1.0 / 30.0, predicted)
	_observe(trails, authority, Vector2(8, 0), 1.0 / 30.0, predicted)
	equal(trails.tracks[1].champion_wire_id, authority.champion_wire_id, "prediction cannot replace identity metadata")
	check(trails.tracks[1].segments[0].lifetime > 0.12, "accepted prediction controls immediate slide styling")
	authority.jumpsquat_active = true
	_observe(trails, authority, Vector2(16, 0))
	equal(trails.segment_count(), 1, "held preparation does not emit even with externally moved anchor")


func _test_lifecycle_and_privacy() -> void:
	for reset_kind: String in ["teleport", "champion", "spawn", "dead", "hidden", "reduced", "clear", "long-frame", "bad-point", "skipped-frame"]:
		var actor := _actor()
		var trails := Trails.new()
		_seed(trails, actor)
		equal(trails.segment_count(), 1, "positive control before %s" % reset_kind)
		match reset_kind:
			"teleport":
				_observe(trails, actor, Vector2(400, 0))
			"champion":
				actor.champion_wire_id += 1
				_observe(trails, actor, Vector2(16, 0))
			"spawn":
				actor.spawn_protection_ticks = 60
				_observe(trails, actor, Vector2(16, 0))
			"dead":
				actor.health = 0
				_observe(trails, actor, Vector2(16, 0))
			"hidden":
				trails.begin_frame(1.0 / 30.0)
				trails.end_frame()
			"reduced":
				trails.begin_frame(1.0 / 30.0, false)
				trails.observe(actor, actor, Vector2(16, 0), 68.0)
			"clear":
				trails.clear()
			"long-frame":
				_observe(trails, actor, Vector2(16, 0), 0.2)
			"bad-point":
				_observe(trails, actor, Vector2.INF)
			"skipped-frame":
				trails.begin_frame(1.0 / 30.0)
				_observe(trails, actor, Vector2(16, 0))
		equal(trails.segment_count(), 0, "%s removes previous decoration immediately" % reset_kind)
		_observe(trails, actor, Vector2(16, 0))
		equal(trails.segment_count(), 0, "%s cannot resurrect its prior trail on a stationary frame" % reset_kind)
	var actor := _actor()
	var trails := Trails.new()
	actor.spawn_protection_ticks = 60
	_seed(trails, actor)
	actor.spawn_protection_ticks -= 1
	_observe(trails, actor, Vector2(16, 0))
	equal(trails.segment_count(), 2, "normal spawn countdown does not reset live movement history")
	trails.forget(1)
	equal(trails.tracks.size(), 0, "explicit privacy/actor reset discards the track")


func _test_limits_and_rates() -> void:
	equal(Trails.MAX_SEGMENT_PIXELS, 16.0, "drawable wake length has the explicit 16-pixel cap")
	equal(Trails.MAX_FRAME_VISIBILITY_PROBES, 432, "global maximum is eight actors times six strokes times nine probes")
	for rate: int in [30, 60, 120, 240]:
		var trails := Trails.new()
		var actors: Array[PlayerState] = []
		for entity_id: int in range(1, 13):
			var actor := _actor(entity_id)
			actor.air_dodge_ticks = 60
			actor.velocity_x = 600_000
			actors.append(actor)
		var delta := 1.0 / float(rate)
		for frame: int in range(rate + 1):
			trails.begin_frame(delta)
			for actor: PlayerState in actors:
				var before := actor.canonical_values()
				trails.observe(actor, actor, Vector2(float(frame) * 600.0 * delta, float(actor.entity_id) * 100.0), 68.0)
				equal(actor.canonical_values(), before, "bounded sampling never writes simulated state")
			trails.end_frame()
			check(trails.tracks.size() <= Trails.MAX_TRACKS, "global actor history bound holds at every visual rate")
			check(trails.segment_count() <= Trails.MAX_TRACKS * Trails.MAX_SEGMENTS_PER_ACTOR, "global segment bound holds during sustained travel")
		equal(trails.tracks.size(), 8, "extra actors cannot expand the presentation cap")
		check(trails.segment_count(1) >= 4, "visible wake survives at 30/60/120/240 fps")
		for track in trails.tracks.values():
			check(track.segments.size() <= 6, "per-actor history is bounded")
			for segment in track.segments:
				check(segment.start.distance_to(segment.finish) <= Trails.MAX_SEGMENT_PIXELS + 0.001, "frame-rate changes cannot create longer strokes")
		trails.clear()
		equal(trails.segment_count(), 0, "scene reset drops all retained samples")


func _test_visibility_interior() -> void:
	var slit := func(point: Vector2) -> bool: return absf(point.x - 5.0) > 1.1
	check(not Trails.segment_visible(Vector2.ZERO, Vector2(10, 0), slit), "visible endpoints cannot leak a wake across an occluded interior")
	var visible := func(_point: Vector2) -> bool: return true
	check(Trails.segment_visible(Vector2.ZERO, Vector2(10, 0), visible), "fully visible short stroke remains eligible")
	check(not Trails.segment_visible(Vector2.ZERO, Vector2(1000, 0), visible), "visibility work rejects unbounded geometry")
	check(not Trails.segment_visible(Vector2.INF, Vector2.ZERO, visible), "invalid geometry never reaches the canvas")
	var probe_count := [0]
	var counted := func(_point: Vector2) -> bool:
		probe_count[0] += 1
		return true
	check(Trails.segment_visible(Vector2.ZERO, Vector2(16, 0), counted), "longest admitted stroke stays visible")
	equal(probe_count[0], Trails.MAX_VISIBILITY_PROBES_PER_SEGMENT, "visibility work never exceeds nine queries per segment")
	probe_count[0] = 0
	check(not Trails.segment_visible(Vector2.ZERO, Vector2(16.0005, 0), counted), "even a subpixel excess is rejected before it can need a tenth probe")
	equal(probe_count[0], 0, "over-limit boundary geometry makes no visibility calls")
