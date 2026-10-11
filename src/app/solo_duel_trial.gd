extends RefCounted
## Local encounter bookkeeping only. Never mutates simulation or supplies attacks.

const Practice = preload("res://src/sim/combat/interception_practice.gd")
const IDLE := "idle"
const READY := "ready"
const ACTIVE := "active"
const VICTORY := "victory"
const DEFEATED := "defeated"
const TIMEOUT := "timeout"
const LEFT_COURT := "left_court"
const UNAVAILABLE := "unavailable"

var phase := IDLE
var start_tick := -1
var last_observed_tick := -1
var end_tick := -1
var player_health := 0
var player_health_maximum := 1
var opponent_health := 0
var opponent_health_maximum := 1
var interceptions := 0
var paid_casts := 0
var court := Rect2i()
var _authority: SimWorld = null
var _opponent_projectiles: Dictionary = {}
var _counted_interceptions: Dictionary = {}


func begin(world: SimWorld, bounds_pixels: Rect2i) -> bool:
	if world == null or not world.is_valid() or world.players.size() != 2 or not bounds_pixels.has_area():
		return false
	var player := world.player(1)
	var opponent := world.player(2)
	if player == null or opponent == null or player.health <= 0 or opponent.health <= 0 or player.team_id == opponent.team_id:
		return false
	var bounds := Rect2i(bounds_pixels.position * SimConfig.FIXED_SCALE, bounds_pixels.size * SimConfig.FIXED_SCALE)
	if not bounds.has_point(Vector2i(player.position_x, player.position_y)) or not bounds.has_point(Vector2i(opponent.position_x, opponent.position_y)):
		return false
	reset()
	_authority = world
	court = bounds
	start_tick = world.tick
	last_observed_tick = world.tick
	phase = READY
	_sample_health(player, opponent)
	return true


func reset() -> void:
	phase = IDLE
	start_tick = -1
	last_observed_tick = -1
	end_tick = -1
	interceptions = 0
	paid_casts = 0
	player_health = 0
	player_health_maximum = 1
	opponent_health = 0
	opponent_health_maximum = 1
	court = Rect2i()
	_authority = null
	_opponent_projectiles.clear()
	_counted_interceptions.clear()


func is_running() -> bool:
	return phase in [READY, ACTIVE]


func is_finished() -> bool:
	return phase not in [IDLE, READY, ACTIVE]


func blocks_gameplay() -> bool:
	return phase == READY or is_finished()


func observe(world: SimWorld) -> bool:
	if not is_running() or world == null or world != _authority or world.tick <= last_observed_tick:
		return false
	last_observed_tick = world.tick
	var player := world.player(1)
	var opponent := world.player(2)
	if player == null or opponent == null:
		_finish(UNAVAILABLE, world.tick)
		return true
	_sample_health(player, opponent)
	# Events are the untrimmed local authority batch, observed once per stepped tick.
	for event: Dictionary in world.combat_events:
		var kind := String(event.get("type", ""))
		var projectile_id := int(event.get("projectile_id", 0))
		if kind == "projectile_spawned" and int(event.get("owner_id", 0)) == 2 and projectile_id > 0:
			_opponent_projectiles[projectile_id] = true
		elif kind == "cast_started" and int(event.get("entity_id", 0)) == 1:
			paid_casts += 1
		elif kind == "spray_intercepted" and int(event.get("owner_id", 0)) == 1 and int(event.get("outcome", 0)) == 1:
			if _opponent_projectiles.has(projectile_id) and not _counted_interceptions.has(projectile_id):
				_counted_interceptions[projectile_id] = true
				interceptions += 1
	# Mutual defeat is a loss, independent of event iteration order. Leaving the
	# visibly marked court cannot win by firing at the opponent from safety.
	if player.health <= 0:
		_finish(DEFEATED, world.tick)
	elif not court.has_point(Vector2i(player.position_x, player.position_y)):
		_finish(LEFT_COURT, world.tick)
	elif opponent.health <= 0:
		_finish(VICTORY, world.tick)
	elif world.tick - start_tick >= Practice.DURATION_TICKS:
		_finish(TIMEOUT, world.tick)
	elif world.tick - start_tick >= Practice.READY_END:
		phase = ACTIVE
	return true


func view() -> Dictionary:
	var elapsed := maxi(0, (end_tick if is_finished() else last_observed_tick) - start_tick)
	return {"phase": phase, "elapsed_ticks": elapsed,
		"remaining_ticks": maxi(0, Practice.DURATION_TICKS - elapsed),
		"countdown_ticks": maxi(0, Practice.READY_END - elapsed),
		"health": player_health, "health_maximum": player_health_maximum,
		"opponent_health": opponent_health, "opponent_health_maximum": opponent_health_maximum,
		"interceptions": interceptions, "paid_casts": paid_casts, "finished": is_finished()}


func _sample_health(player: PlayerState, opponent: PlayerState) -> void:
	player_health = player.health
	player_health_maximum = maxi(1, player.health_maximum)
	opponent_health = opponent.health
	opponent_health_maximum = maxi(1, opponent.health_maximum)


func _finish(outcome: String, tick: int) -> void:
	phase = outcome
	end_tick = tick
