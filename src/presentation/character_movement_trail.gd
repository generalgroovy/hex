class_name CharacterMovementTrail
extends RefCounted


# Presentation-only wakes: sampled displayed anchors, never velocity-projected
# body copies, material deposits, collision, or delayed gameplay state.
const MAX_TRACKS := 8
const MAX_SEGMENTS_PER_ACTOR := 6
const SAMPLE_SECONDS := 1.0 / 40.0
const MAX_FRAME_SECONDS := 0.1
const MAX_SEGMENT_PIXELS := 16.0
const SNAP_DISTANCE_PIXELS := 72.0
const MIN_SPEED_PIXELS := 24.0
const COLLINEAR_TOLERANCE_PIXELS := 0.01
const VISIBILITY_STEP_PIXELS := 2.0
const MAX_VISIBILITY_PROBES_PER_SEGMENT := 9
const MAX_FRAME_VISIBILITY_PROBES := MAX_TRACKS * MAX_SEGMENTS_PER_ACTOR * MAX_VISIBILITY_PROBES_PER_SEGMENT
const MAX_FRAME_DRAW_CALLS := MAX_TRACKS * MAX_SEGMENTS_PER_ACTOR * 2
const WAKE_COLOR := Color("b9cdd0")
const WAKE_EDGE := Color("34474c")


class Segment:
	extends RefCounted
	var start := Vector2.ZERO
	var finish := Vector2.ZERO
	var age := 0.0
	var lifetime := 0.12
	var strength := 0.0
	var height := 68.0
	var side_sign := -1.0
	var active := false

	func reset() -> void:
		start = Vector2.ZERO
		finish = Vector2.ZERO
		age = 0.0
		lifetime = 0.12
		strength = 0.0
		height = 68.0
		side_sign = -1.0
		active = false


class Track:
	extends RefCounted
	var point := Vector2.ZERO
	var sample_point := Vector2.ZERO
	var sample_seconds := 0.0
	var champion_wire_id := 0
	var spawn_protection_ticks := 0
	var observed_frame := -1
	var moving := false
	var next_side := -1.0
	var slots: Array[Segment] = []
	var order := PackedInt32Array()
	var count := 0
	# Detached ordering view for diagnostics; records are the live fixed slots.
	# The hot path walks slots directly without allocating this inspection list.
	var segments: Array[Segment]:
		get:
			var result: Array[Segment] = []
			for index: int in count: result.append(slots[order[index]])
			return result

	func _init() -> void:
		order.resize(MAX_SEGMENTS_PER_ACTOR)
		for index: int in MAX_SEGMENTS_PER_ACTOR: slots.append(Segment.new())

	func reset() -> void:
		point = Vector2.ZERO
		sample_point = Vector2.ZERO
		sample_seconds = 0.0
		champion_wire_id = 0
		spawn_protection_ticks = 0
		observed_frame = -1
		moving = false
		next_side = -1.0
		clear_segments()

	func clear_segments() -> void:
		count = 0
		for segment: Segment in slots: segment.reset()

	func age_segments(delta: float) -> void:
		var retained := 0
		for index: int in count:
			var slot := order[index]
			var segment: Segment = slots[slot]
			segment.age += delta
			if segment.age >= segment.lifetime:
				segment.reset()
			else:
				order[retained] = slot
				retained += 1
		count = retained

	func next_segment() -> Segment:
		var slot := -1
		if count == MAX_SEGMENTS_PER_ACTOR:
			slot = order[0]
			for index: int in count - 1: order[index] = order[index + 1]
			count -= 1
		else:
			for index: int in MAX_SEGMENTS_PER_ACTOR:
				if not slots[index].active:
					slot = index
					break
		if slot < 0: return null
		var segment: Segment = slots[slot]
		segment.reset()
		segment.active = true
		order[count] = slot
		count += 1
		return segment


var tracks: Dictionary[int, Track] = {}
var _frame := 0
var _delta := 0.0
var _enabled := false
var _free_tracks: Array[Track] = []
var _stale_ids := PackedInt64Array()


func _init() -> void:
	# Exactly eight tracks and 48 stroke records for this presenter's lifetime.
	# Speed, frame rate, turns and scene resets cannot grow the record pool.
	for index: int in MAX_TRACKS: _free_tracks.append(Track.new())
	_stale_ids.resize(MAX_TRACKS)


func clear() -> void:
	for entity_id: int in tracks:
		var track: Track = tracks[entity_id]
		track.reset()
		_free_tracks.append(track)
	tracks.clear()


func forget(entity_id: int) -> void:
	var track: Track = tracks.get(entity_id)
	if track == null: return
	tracks.erase(entity_id)
	track.reset()
	_free_tracks.append(track)


# Exactly once per presentation update, not per redraw or portrait query.
# Menus/privacy/reduced effects pass enabled=false. A long pause cannot become
# a long streak, even if a sprite reappears at a nearby location afterward.
func begin_frame(delta_seconds: float, enabled: bool = true) -> void:
	_frame += 1
	_delta = delta_seconds
	_enabled = enabled and is_finite(_delta) and _delta > 0.0 and _delta <= MAX_FRAME_SECONDS
	if not _enabled:
		clear()
		return
	for entity_id: int in tracks:
		(tracks[entity_id] as Track).age_segments(_delta)


# The caller supplies the SAME world-space foot/body anchor displayed this
# frame, after interpolation and visual prediction correction, not authority's
# unsmoothed position. Height is the admitted body size; no sprite image reads.
# Identity/health/spawn always come from authority, never an incomplete local
# prediction packet. Omitted/hidden actors must not be observed.
func observe(authority: PlayerState, motion: PlayerState, display_anchor: Vector2, display_height: float) -> void:
	if authority == null:
		return
	var entity_id := authority.entity_id
	if not _enabled or authority.actor_kind != PlayerState.ActorKind.CHAMPION or authority.health <= 0 \
			or not display_anchor.is_finite() or not is_finite(display_height):
		forget(entity_id)
		return
	if motion == null or motion.entity_id != entity_id:
		motion = authority
	var track: Track = tracks.get(entity_id)
	var identity_changed := track != null and (track.champion_wire_id != authority.champion_wire_id \
		or authority.spawn_protection_ticks > track.spawn_protection_ticks)
	if identity_changed:
		forget(entity_id)
		track = null
	if track == null:
		if tracks.size() >= MAX_TRACKS:
			return
		track = _free_tracks.pop_back()
		track.point = display_anchor
		track.sample_point = display_anchor
		track.champion_wire_id = authority.champion_wire_id
		track.spawn_protection_ticks = authority.spawn_protection_ticks
		track.observed_frame = _frame
		track.moving = _eligible_motion(motion)
		tracks[entity_id] = track
		return
	# A second draw of this actor cannot advance age or add another sample.
	if track.observed_frame == _frame:
		return
	var skipped_frame := track.observed_frame != _frame - 1
	track.observed_frame = _frame
	track.spawn_protection_ticks = authority.spawn_protection_ticks
	var travel := display_anchor - track.point
	var velocity := Vector2(motion.velocity_x, motion.velocity_y) / float(SimConfig.FIXED_SCALE)
	var speed := velocity.length()
	var plausible_distance := minf(SNAP_DISTANCE_PIXELS, speed * _delta * 2.0 + 3.0)
	var discontinuity := skipped_frame or travel.length() > plausible_distance
	if discontinuity:
		track.clear_segments()
	var moving := _eligible_motion(motion)
	# Stationary/blocked bodies and held preparation leave only a brief fading
	# wake. Aim changes and backwards prediction corrections cannot make one.
	var advanced := moving and track.moving and not discontinuity \
		and travel.length_squared() > 0.01 and travel.dot(velocity) > 0.0
	if advanced:
		# Accumulate only a witnessed straight leg. A turn keeps prior strokes,
		# but never joins anchors across the corner or adds distance-based work.
		var pending := track.point - track.sample_point
		if pending.length_squared() > 0.000001 and (pending.dot(travel) <= 0.0 \
				or absf(pending.cross(travel)) > COLLINEAR_TOLERANCE_PIXELS * travel.length()):
			track.sample_point = track.point
		track.sample_seconds += _delta
		if track.sample_seconds + 0.000001 >= SAMPLE_SECONDS:
			var span := display_anchor - track.sample_point
			if span.length_squared() >= 1.0:
				var segment := track.next_segment()
				segment.finish = display_anchor
				segment.start = display_anchor - span.limit_length(MAX_SEGMENT_PIXELS)
				segment.height = clampf(display_height, 40.0, 80.0)
				segment.side_sign = track.next_side
				track.next_side = -track.next_side
				var displayed_speed := minf(speed, travel.length() / _delta)
				segment.strength = _strength(motion, displayed_speed)
				segment.lifetime = _lifetime(motion)
			track.sample_point = display_anchor
			track.sample_seconds = 0.0
	else:
		track.sample_point = display_anchor
		track.sample_seconds = 0.0
	track.point = display_anchor
	track.moving = moving


# Call after the local/remote actor pass. This also removes actor tracks when
# their body was culled, hidden, disconnected, or excluded by a modal screen.
func end_frame() -> void:
	var count := 0
	for entity_id: int in tracks:
		if tracks[entity_id].observed_frame != _frame:
			_stale_ids[count] = entity_id
			count += 1
	for index: int in count: forget(_stale_ids[index])


func segment_count(entity_id: int = -1) -> int:
	if entity_id >= 0:
		var track: Track = tracks.get(entity_id)
		return track.count if track != null else 0
	var count := 0
	for id: int in tracks:
		count += tracks[id].count
	return count


# Draw behind the live body and beneath the existing world/POV mask. The
# optional callback tests CURRENT observer visibility along each short stroke,
# including its interior; historic actor visibility is never sufficient.
func draw_actor(canvas: CanvasItem, entity_id: int, point_visible: Callable = Callable()) -> int:
	if canvas == null or not _enabled:
		return 0
	var track: Track = tracks.get(entity_id)
	if track == null or track.observed_frame != _frame:
		return 0
	var count := 0
	for index: int in track.count:
		var segment: Segment = track.slots[track.order[index]]
		var direction := (segment.finish - segment.start).normalized()
		var side := Vector2(-direction.y, direction.x) * segment.height * 0.10
		var lift := Vector2(0.0, -segment.height * 0.36)
		var fade := 1.0 - clampf(segment.age / segment.lifetime, 0.0, 1.0)
		var opacity := segment.strength * fade * fade
		# Alternate compact strokes along the two edges of the body's path,
		# rather than painting a filled ribbon or duplicating the silhouette.
		var start := (segment.start.lerp(segment.finish, 0.12) + lift + side * segment.side_sign).round()
		var finish := (segment.start.lerp(segment.finish, 0.88) + lift + side * segment.side_sign).round()
		if not segment_visible(start, finish, point_visible):
			continue
		# A compact two-tone stroke survives pale stone and dark grass without
		# extending history, creating body ghosts or increasing particle density.
		canvas.draw_line(start, finish, Color(WAKE_EDGE, opacity), 3.0, false)
		canvas.draw_line(start, finish, Color(WAKE_COLOR, opacity), 2.0 if segment.strength >= 0.27 else 1.0, false)
		count += 1
	return count


static func segment_visible(start: Vector2, finish: Vector2, point_visible: Callable) -> bool:
	if not start.is_finite() or not finish.is_finite():
		return false
	if not point_visible.is_valid():
		return true
	# Observe bounds every admitted segment, so this loop has at most 9 probes.
	# Reject out-of-contract geometry rather than silently reducing coverage.
	if start.distance_to(finish) > MAX_SEGMENT_PIXELS:
		return false
	var steps := maxi(1, ceili(start.distance_to(finish) / VISIBILITY_STEP_PIXELS))
	for index: int in range(steps + 1):
		if not bool(point_visible.call(start.lerp(finish, float(index) / float(steps)))):
			return false
	return true


static func _eligible_motion(state: PlayerState) -> bool:
	return state != null and not state.jumpsquat_active \
		and state.control_state in [PlayerState.ControlState.FREE, PlayerState.ControlState.SLOWED] \
		and Vector2(state.velocity_x, state.velocity_y).length() / float(SimConfig.FIXED_SCALE) >= MIN_SPEED_PIXELS


static func _strength(state: PlayerState, displayed_speed: float) -> float:
	var speed_ratio := clampf(displayed_speed / 720.0, 0.0, 1.0)
	if state.air_dodge_ticks > 0:
		return lerpf(0.58, 0.86, speed_ratio)
	if state.slide_ticks > 0 or state.movement_mode in [PlayerState.MovementMode.SLIDE, PlayerState.MovementMode.WAVE_DASH]:
		return lerpf(0.52, 0.78, speed_ratio)
	return lerpf(0.40, 0.64, speed_ratio)


static func _lifetime(state: PlayerState) -> float:
	if state.air_dodge_ticks > 0:
		return 0.18
	if state.slide_ticks > 0 or state.movement_mode in [PlayerState.MovementMode.SLIDE, PlayerState.MovementMode.WAVE_DASH]:
		return 0.16
	return 0.12
