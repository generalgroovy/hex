extends SceneTree


const BOOTSTRAP_SCENE_PATH: String = "res://scenes/bootstrap/bootstrap.tscn"
const SAMPLE_INTERVAL_MSEC: int = 5000
const PROBE_DURATION_MSEC: int = 120000


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed_scene: PackedScene = load(BOOTSTRAP_SCENE_PATH)
	if packed_scene == null:
		push_error("Bootstrap tick probe could not load the production scene")
		quit(1)
		return
	var game: Node = packed_scene.instantiate()
	if game == null:
		push_error("Bootstrap tick probe could not instantiate the production scene")
		quit(1)
		return
	root.add_child(game)
	await process_frame
	await process_frame
	if game == null or not is_instance_valid(game):
		push_error("Bootstrap tick probe lost the production scene during startup")
		quit(1)
		return

	var started_msec: int = Time.get_ticks_msec()
	var next_sample_msec: int = started_msec
	var previous_sample_msec: int = started_msec
	var previous_world_tick: int = _world_tick(game)
	while Time.get_ticks_msec() - started_msec < PROBE_DURATION_MSEC:
		await process_frame
		var now_msec: int = Time.get_ticks_msec()
		if now_msec < next_sample_msec:
			continue
		var world_tick: int = _world_tick(game)
		var sample_seconds: float = float(now_msec - previous_sample_msec) / 1000.0
		var observed_ticks_per_second: float = 0.0
		if previous_world_tick >= 0 and world_tick >= previous_world_tick and sample_seconds > 0.0:
			observed_ticks_per_second = float(world_tick - previous_world_tick) / sample_seconds
		print("BOOTSTRAP_TICK_PROBE %s" % JSON.stringify({
			"wall_seconds": float(now_msec - started_msec) / 1000.0,
			"world_tick": world_tick,
			"countdown_end_tick": _countdown_end_tick(game),
			"round_phase": _round_phase(game),
			"world_epoch": _world_epoch(game),
			"observed_ticks_per_second": observed_ticks_per_second,
			"process_enabled": game.is_processing(),
		}))
		previous_sample_msec = now_msec
		previous_world_tick = world_tick
		next_sample_msec += SAMPLE_INTERVAL_MSEC
		if next_sample_msec <= now_msec:
			next_sample_msec = now_msec + SAMPLE_INTERVAL_MSEC

	game.queue_free()
	await process_frame
	quit(0)


func _world_tick(game: Node) -> int:
	var world: SimWorld = game.get("world") as SimWorld
	return world.tick if world != null else -1


func _authoritative_session(game: Node) -> AuthoritativeSession:
	return game.get("authoritative_session") as AuthoritativeSession


func _countdown_end_tick(game: Node) -> int:
	var session: AuthoritativeSession = _authoritative_session(game)
	if session == null or session.hearth == null:
		return -1
	return session.hearth.countdown_end_tick


func _round_phase(game: Node) -> int:
	var session: AuthoritativeSession = _authoritative_session(game)
	if session == null or session.session_round == null:
		return -1
	return session.session_round.phase


func _world_epoch(game: Node) -> int:
	var session: AuthoritativeSession = _authoritative_session(game)
	return session.world_epoch if session != null else -1
