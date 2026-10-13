extends RefCounted
## Local command planning only. Each signature uses its existing delivery,
## payment, collision and cooldown rules; no target tracking changes a paid shot.
@warning_ignore_start("integer_division")

const Rival = preload("res://src/app/solo_duel_rival.gd")
const Challenges = preload("res://src/content/signature_challenge_catalog.gd")
const COMMIT_TICKS := 30
const RAPID_BURST_TICKS := 18
const RAPID_PERIOD_TICKS := RAPID_BURST_TICKS+COMMIT_TICKS
const PROFILES := {
	"bolt": {"windup":72, "pressure":108, "pause":180, "near":220000, "far":380000},
	"heavy": {"windup":108, "pressure":84, "pause":216, "near":260000, "far":400000},
	"rapid": {"windup":72, "pressure":RAPID_PERIOD_TICKS*3, "pause":180, "near":260000, "far":420000},
	"spray": {"windup":72, "pressure":96, "pause":192, "near":140000, "far":240000},
	"mantle": {"windup":72, "pressure":180, "pause":204, "near":38000, "far":70000},
	"fuse": {"windup":96, "pressure":108, "pause":204, "near":220000, "far":380000},
	"split": {"windup":84, "pressure":120, "pause":180, "near":240000, "far":380000},
	"rebound": {"windup":96, "pressure":120, "pause":180, "near":220000, "far":380000},
}


static func profile(family: String) -> Dictionary:
	return (PROFILES.get(family, {}) as Dictionary).duplicate(true)


static func status(world_tick: int, start_tick: int, family: String) -> Dictionary:
	var delivery: Dictionary = PROFILES.get(family, {})
	if delivery.is_empty(): return {}
	var elapsed := maxi(0, world_tick - start_tick)
	if elapsed < Rival.READY_END:
		return {"phase":"ready", "cue":"Read the signature, then defeat the rival to learn it.", "remaining_ticks":Rival.READY_END-elapsed, "telegraph":"", "break":false, "cycle_tick":-1, "cycle_index":-1}
	var cycle := int(delivery.windup) + int(delivery.pressure) + int(delivery.pause)
	var tick := posmod(elapsed-Rival.READY_END, cycle)
	var phase := "windup" if tick < int(delivery.windup) else ("pressure" if tick < int(delivery.windup)+int(delivery.pressure) else "recover")
	var end := int(delivery.windup) if phase == "windup" else (int(delivery.windup)+int(delivery.pressure) if phase == "pressure" else cycle)
	return {"phase":phase, "cue":"No new casts during this pause; existing shots and fields remain dangerous." if phase == "recover" else String(Challenges.TELLS[family]),
		"remaining_ticks":end-tick, "telegraph":"" if phase == "recover" else family, "break":phase == "recover", "cycle_tick":tick, "cycle_index":(elapsed-Rival.READY_END)/cycle}


static func movement(opponent: PlayerState, player: PlayerState, bounds: Rect2i, collision: CollisionWorld, family: String, cycle_index: int, pursuing: bool = false) -> Vector2i:
	var delivery: Dictionary = PROFILES.get(family, {})
	if delivery.is_empty(): return Vector2i.ZERO
	var position := Vector2i(opponent.position_x, opponent.position_y)
	var delta := Vector2i(player.position_x, player.position_y)-position
	var toward := SimCommand._normalized_direction(delta.x, delta.y)
	var side := 1 if posmod(cycle_index, 2) == 0 else -1
	var tangent := Vector2i(-toward.y, toward.x)*side
	var distance_squared := delta.length_squared()
	var desired := Vector2i.ZERO
	if not bounds.has_point(position):
		desired = bounds.get_center()-position
	elif distance_squared > int(delivery.far)*int(delivery.far):
		desired = toward
	elif distance_squared < int(delivery.near)*int(delivery.near) and family != "mantle":
		desired = -toward
	elif pursuing:
		desired = toward if family == "mantle" and distance_squared > int(delivery.near)*int(delivery.near) else tangent
	if desired == Vector2i.ZERO: return desired
	desired = SimCommand._normalized_direction(desired.x, desired.y)
	var safe := bounds.grow(-Rival.COURT_INSET)
	var point := position+desired*Rival.STEER_DISTANCE/1000
	point.x = clampi(point.x, safe.position.x, safe.end.x-1)
	point.y = clampi(point.y, safe.position.y, safe.end.y-1)
	var planned := collision.move_box(position, point-position, MovementTuning.PLAYER_RADIUS)
	if (planned.position-position).length_squared() < 12000*12000:
		# Obstacle contact requests a bounded tangent, never a teleport or an
		# authority mutation. The following ordinary movement still owns collision.
		for turn: Vector2i in [tangent, -tangent]:
			var around := position+turn*Rival.STEER_DISTANCE/1000
			if safe.has_point(around) and collision.can_occupy(around, MovementTuning.PLAYER_RADIUS):
				return turn
	var adjusted := point-position
	return SimCommand._normalized_direction(adjusted.x, adjusted.y)


static func can_attempt(opponent: PlayerState, player: PlayerState, definition: Dictionary) -> bool:
	var distance := Vector2i(player.position_x-opponent.position_x, player.position_y-opponent.position_y).length()
	match String(definition.get("family", "")):
		"mantle": return distance <= 120000.0 # Ordinary pursuit must still close contact distance.
		"spray": return distance <= float(int(definition.get("range", 0))+player.radius)
		_: return distance <= float(_travel_reach(definition))


static func _travel_reach(definition: Dictionary) -> int:
	return int(definition.get("range", int(definition.get("speed", 0))*int(definition.get("lifetime_ms", 0))/1000))


static func committed_aim(origin: Vector2i, target: Vector2i, definition: Dictionary, collision: CollisionWorld) -> Vector2i:
	if String(definition.get("family", "")) != "rebound": return target-origin
	var bank := bank_target(origin, target, definition, collision)
	return (bank if bank != Vector2i(-1,-1) else target)-origin


static func bank_target(origin: Vector2i, target: Vector2i, definition: Dictionary, collision: CollisionWorld) -> Vector2i:
	# Reflect the target across a real solid face, then verify both swept legs.
	# Only one bank is planned; the paid projectile retains its authored two-bank
	# limit. No nearby valid face means a direct shot, not invented geometry.
	if collision == null: return Vector2i(-1,-1)
	var base: CollisionWorld = collision.base_world if collision is HexCollisionWorld else collision
	var radius := int(definition.get("radius", 0))
	var reach := _travel_reach(definition)
	var faces: Array[Array] = [[0,radius,0,base.height,1000], [0,base.width-radius,0,base.height,-1000], [1,radius,0,base.width,1000], [1,base.height-radius,0,base.width,-1000]]
	for obstacle: CollisionWorld.Obstacle in base.obstacle_view():
		var low := Vector2i(obstacle.minimum_x-radius, obstacle.minimum_y-radius)
		var high := Vector2i(obstacle.maximum_x+radius, obstacle.maximum_y+radius)
		var nearest := Vector2i(clampi(origin.x,low.x,high.x),clampi(origin.y,low.y,high.y))
		if (nearest-origin).length_squared() > reach*reach: continue
		faces.append_array([[0,low.x,low.y,high.y,-1000], [0,high.x,low.y,high.y,1000], [1,low.y,low.x,high.x,-1000], [1,high.y,low.x,high.x,1000]])
	var best := Vector2i(-1,-1)
	var best_length := float(reach)
	for face: Array in faces:
		var axis := int(face[0])
		var plane := int(face[1])
		if (origin[axis]-plane)*(target[axis]-plane) <= 0: continue
		var mirror := target
		mirror[axis] = 2*plane-target[axis]
		var denominator := mirror[axis]-origin[axis]
		if denominator == 0: continue
		var fraction := float(plane-origin[axis])/float(denominator)
		if fraction <= 0.0 or fraction >= 1.0: continue
		var bounce := ContinuousContact.point_at(origin, mirror, fraction)
		if bounce[1-axis] <= int(face[2])+radius or bounce[1-axis] >= int(face[3])-radius: continue
		var length := (bounce-origin).length()+(target-bounce).length()
		if length >= best_length: continue
		var normal := Vector2i.ZERO
		normal[axis] = int(face[4])
		var hit := ContinuousContact.wall_contact(origin, bounce-normal/1000, radius, base)
		if hit.is_empty() or hit.normal != normal or (Vector2i(hit.center)-bounce).length_squared() > 16: continue
		if not ContinuousContact.wall_contact(bounce+normal*2/1000, target, radius, base).is_empty(): continue
		best = bounce
		best_length = length
	return best
