class_name ActorMotionHistory
extends RefCounted


# One adjacent authoritative sample per admitted champion. Presentation only:
# no extrapolation, gameplay-state writes, or delayed facing/protection clocks.
const MAX_TRACKS: int = 8
const SNAP_DISTANCE_PIXELS: float = 72.0
const MAX_GAIT_SAMPLE_SECONDS: float = 0.1
const MAX_GAIT_CYCLES_PER_SECOND: float = 5.0
const MAX_WALK_GAIT_CYCLES_PER_SECOND: float = 3.0

class Track:
	extends RefCounted
	var previous := Vector3.ZERO
	var current := Vector3.ZERO
	var champion_wire_id: int = 0
	var alive: bool = true
	var spawn_protection_ticks: int = 0

class GaitTrack:
	extends RefCounted
	var point := Vector2.ZERO
	var phase := 0.0
	var champion_wire_id := 0
	var alive := true
	var spawn_protection_ticks := 0
	var ground_locomotion := false
	var rebase := false

var tracks: Dictionary[int, Track] = {}
var gait_tracks: Dictionary[int, GaitTrack] = {}


func clear() -> void:
	tracks.clear()
	gait_tracks.clear()


# Once per presentation update, using interpolated locomotion anchors. Local
# prediction correction offsets are deliberately excluded: smoothing a correction
# is not walking. Repeated draw/portrait/QA queries never advance this clock.
func capture_gaits(states: Array[PlayerState], points: Dictionary, heights: Dictionary, delta_seconds: float, predicted_motion: Dictionary = {}) -> void:
	var retained: Dictionary[int, bool] = {}
	for state: PlayerState in states:
		if state.actor_kind != PlayerState.ActorKind.CHAMPION or retained.has(state.entity_id) or retained.size() >= MAX_TRACKS or not points.has(state.entity_id):
			continue
		retained[state.entity_id] = true
		var point: Vector2 = points[state.entity_id]
		if not point.is_finite():
			gait_tracks.erase(state.entity_id)
			continue
		var track: GaitTrack = gait_tracks.get(state.entity_id)
		var new_identity := track == null
		if track != null:
			new_identity = track.champion_wire_id != state.champion_wire_id or track.alive != (state.health > 0) or state.spawn_protection_ticks > track.spawn_protection_ticks
		if track == null:
			track = GaitTrack.new()
		# Prediction packets intentionally omit identity, health and spawn data.
		# Their motion can lead authority, but cannot replace lifecycle metadata.
		var motion_state: PlayerState = predicted_motion.get(state.entity_id, state)
		if motion_state == null or motion_state.entity_id != state.entity_id:
			motion_state = state
		var moving := state.health > 0 and _ground_locomotion(motion_state)
		var delta := maxf(0.0, delta_seconds) if is_finite(delta_seconds) else 0.0
		var distance := track.point.distance_to(point)
		var speed := Vector2(motion_state.velocity_x, motion_state.velocity_y).length() / float(SimConfig.FIXED_SCALE)
		# A correction/teleport cannot be reinterpreted as several rapid steps.
		# The small tolerance accommodates adjacent snapshot rounding, not warps.
		var plausible_distance := minf(SNAP_DISTANCE_PIXELS, speed * delta * 2.0 + 2.0)
		var discontinuity := new_identity or track.rebase or delta <= 0.0 or delta > MAX_GAIT_SAMPLE_SECONDS or distance > plausible_distance
		if new_identity:
			track.phase = 0.0
		elif not discontinuity and moving and track.ground_locomotion and speed > 0.0:
			var stride := MinimalChampionMotion.locomotion_stride_pixels(float(heights.get(state.entity_id, 68.0)))
			# Extreme retained momentum cannot flicker the two contact poses.
			var sprinting := motion_state.sprinting or motion_state.movement_mode == PlayerState.MovementMode.SPRINT
			var cadence_limit := MAX_GAIT_CYCLES_PER_SECOND if sprinting else MAX_WALK_GAIT_CYCLES_PER_SECOND
			var cycle_delta := minf(distance / stride, cadence_limit * delta)
			track.phase = fposmod(track.phase + cycle_delta, 1.0)
		track.point = point
		track.champion_wire_id = state.champion_wire_id
		track.alive = state.health > 0
		track.spawn_protection_ticks = state.spawn_protection_ticks
		track.ground_locomotion = moving
		track.rebase = false
		gait_tracks[state.entity_id] = track
	for entity_id: int in gait_tracks.keys():
		if not retained.has(entity_id):
			gait_tracks.erase(entity_id)


func gait_phase(entity_id: int) -> float:
	var track: GaitTrack = gait_tracks.get(entity_id)
	return track.phase if track != null else 0.0


func rebase_gait(entity_id: int) -> void:
	var track: GaitTrack = gait_tracks.get(entity_id)
	if track != null:
		track.rebase = true


static func _ground_locomotion(state: PlayerState) -> bool:
	return state.health > 0 and not state.is_airborne() and not state.is_rolling() \
		and state.control_state in [PlayerState.ControlState.FREE, PlayerState.ControlState.SLOWED] \
		and state.movement_mode in [PlayerState.MovementMode.WALK, PlayerState.MovementMode.SPRINT, PlayerState.MovementMode.SLOWED]


func capture(states: Array[PlayerState]) -> void:
	var retained: Dictionary[int, bool] = {}
	for state: PlayerState in states:
		if state.actor_kind != PlayerState.ActorKind.CHAMPION or retained.size() >= MAX_TRACKS:
			continue
		retained[state.entity_id] = true
		var next := _point(state)
		var track: Track = tracks.get(state.entity_id)
		var reset := track == null
		if not reset:
			reset = track.champion_wire_id != state.champion_wire_id or track.alive != (state.health > 0)
			# A round can respawn an already-alive traveller nearby, including at
			# the same planar point while elevated. A fresh/replenished spawn clock
			# is a discontinuity; its ordinary countdown must not disable smoothing.
			reset = reset or state.spawn_protection_ticks > track.spawn_protection_ticks
			reset = reset or Vector2(track.current.x, track.current.y).distance_to(Vector2(next.x, next.y)) > SNAP_DISTANCE_PIXELS
		if track == null:
			track = Track.new()
		track.previous = next if reset else track.current
		track.current = next
		track.champion_wire_id = state.champion_wire_id
		track.alive = state.health > 0
		track.spawn_protection_ticks = state.spawn_protection_ticks
		tracks[state.entity_id] = track
	for entity_id: int in tracks.keys():
		if not retained.has(entity_id):
			tracks.erase(entity_id)


func sample(state: PlayerState, alpha: float) -> Vector3:
	var track: Track = tracks.get(state.entity_id)
	if track == null:
		return _point(state)
	return track.previous.lerp(track.current, clampf(alpha, 0.0, 1.0))


func previous_height(state: PlayerState) -> int:
	var track: Track = tracks.get(state.entity_id)
	return state.air_height if track == null else roundi(track.previous.z * SimConfig.FIXED_SCALE)


static func _point(state: PlayerState) -> Vector3:
	return Vector3(state.position_x, state.position_y, state.air_height) / float(SimConfig.FIXED_SCALE)
