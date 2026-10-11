extends FluxTestSuite

const Harness = preload("res://tests/support/solo_trial_harness.gd")
const Run = preload("res://src/app/solo_duel_trial.gd")
const Rival = preload("res://src/app/solo_duel_rival.gd")


func run() -> int:
	var node := Harness.new()
	var configured := node.configure_trial_fixture()
	check(configured, "world warning fixture configures the actual Bootstrap trial without saved preference writes")
	if not configured:
		node.free()
		return finish("solo-duel-world-tell")
	(Engine.get_main_loop() as SceneTree).root.add_child(node)
	check(node._open_solo_trial_menu(), "normal offline entry opens the trial briefing")
	_sample(node, node.world.player(2), 0, "briefing outside a started trial has no world warning")
	var started := node._start_interception_trial()
	check(started, "world warning uses production startup and the real two-actor court")
	if started:
		_test_ready_to_windup(node)
		_test_owner_and_phase_guards(node)
		_test_clock_and_effects(node)
		_test_court_edges(node)
		_test_shared_visibility(node)
		_test_pause_world_tell(node)
		check(node._start_match(120), "production return restores Wellspring")
		_sample(node, node.world.player(2), 0, "return cannot carry a trial warning into Wellspring")
		_sample_tell(node, node.world.player(2), {}, "return cannot carry a pause cue into Wellspring")
	node.free()
	return finish("solo-duel-world-tell")


func _sample(node: Node, actor: PlayerState, expected: int, message: String) -> void:
	var authority_before: String = node.world.state_hash()
	var trial_before: Dictionary = node.solo_trial.view()
	var preferences_before: Dictionary = node.player_preferences.to_dictionary().duplicate(true)
	equal(node._solo_rival_heavy_tell_segments(actor), expected, message)
	equal(node.world.state_hash(), authority_before, message + " leaves authority untouched")
	equal(node.solo_trial.view(), trial_before, message + " leaves trial bookkeeping untouched")
	equal(node.player_preferences.to_dictionary(), preferences_before, message + " leaves preferences untouched")


func _sample_tell(node: Node, actor: PlayerState, expected: Dictionary, message: String) -> void:
	var authority_before: String = node.world.state_hash()
	var trial_before: Dictionary = node.solo_trial.view()
	var preferences_before: Dictionary = node.player_preferences.to_dictionary().duplicate(true)
	equal(node._solo_rival_world_tell(actor), expected, message)
	equal(node.world.state_hash(), authority_before, message + " leaves authority untouched")
	equal(node.solo_trial.view(), trial_before, message + " leaves trial bookkeeping untouched")
	equal(node.player_preferences.to_dictionary(), preferences_before, message + " leaves preferences untouched")


func _test_pause_world_tell(node: Node) -> void:
	var rival: PlayerState = node.world.player(2)
	var center: Vector2i = node.solo_trial.court.get_center()
	_place(node, 1, center - Vector2i(100000, 0))
	_place(node, 2, center + Vector2i(100000, 0))
	_refresh_motion(node)
	var pause_tick := Rival.READY_END + Rival.WINDUP_TICKS + Rival.PRESSURE_TICKS
	var full := {"kind": "pause", "label": "PAUSE", "segments": 6}
	for reduced: bool in [false, true]:
		node.player_preferences.reduced_motion = reduced
		for elapsed: int in [0, 27, 28, 55, 56, 83, 84, 111, 112, 139, 140, 167]:
			node.world.tick = pause_tick + elapsed
			var segments := ceili(float(Rival.RECOVERY_TICKS - elapsed) * 6.0 / float(Rival.RECOVERY_TICKS))
			_sample_tell(node, rival, {"kind": "pause", "label": "PAUSE", "segments": segments}, "actual world pause follows policy countdown in both effects modes")
		node.world.tick = pause_tick - 1
		_sample_tell(node, rival, {}, "last pressure tick does not prematurely advertise a pause")
		node.world.tick = pause_tick + Rival.RECOVERY_TICKS
		_sample_tell(node, rival, {"kind": "heavy", "label": "HEAVY", "segments": 6}, "next windup replaces pause rather than extending it")
	node.player_preferences.reduced_motion = false
	node.world.tick = pause_tick
	rival.pending_cast_wire_id = 1
	_sample_tell(node, rival, {}, "pending paid startup withholds pause even if the policy is resting")
	rival.pending_cast_wire_id = 0
	rival.cast_recovery_ticks = 1
	_sample_tell(node, rival, {}, "last paid cast recovery tick withholds pause")
	rival.cast_recovery_ticks = 0
	_sample_tell(node, rival, full, "finished paid cast recovery admits the remaining policy pause")
	_sample_tell(node, null, {}, "missing actor has no pause cue")
	_sample_tell(node, node.world.player(1), {}, "local player does not borrow the rival pause")
	var impostor := PlayerState.new(2)
	_sample_tell(node, impostor, {}, "matching number alone does not own the pause cue")
	var health := rival.health
	rival.health = 0
	_sample_tell(node, rival, {}, "dead rival never advertises a pause")
	rival.health = health
	var local: PlayerState = node.world.player(1)
	health = local.health
	local.health = 0
	_sample_tell(node, rival, {}, "dead local observer has no pause cue")
	local.health = health
	for mode: int in [SessionTransport.Mode.HOSTING, SessionTransport.Mode.CONNECTING, SessionTransport.Mode.CLIENT]:
		node.session_transport.mode = mode
		_sample_tell(node, rival, {}, "network actors do not inherit offline rival timing")
	node.session_transport.mode = SessionTransport.Mode.OFFLINE
	for phase: String in [Run.IDLE, Run.READY, Run.VICTORY, Run.DEFEATED, Run.TIMEOUT, Run.LEFT_COURT, Run.UNAVAILABLE]:
		node.solo_trial.phase = phase
		_sample_tell(node, rival, {}, "inactive and terminal trials cannot show pause")
	node.solo_trial.phase = Run.ACTIVE
	node.interception_practice_active = false
	_sample_tell(node, rival, {}, "inactive ownership hides stale pause state")
	node.interception_practice_active = true
	var saved_setup: Dictionary = node.interception_practice_setup
	node.interception_practice_setup = {}
	_sample_tell(node, rival, {}, "missing source clock never manufactures pause")
	node.interception_practice_setup = saved_setup
	var buildings: Array = node.campus_layout.data.buildings
	var point := Vector2i(center / SimConfig.FIXED_SCALE)
	node.campus_layout.data.buildings = [{"bounds": [point.x - 5, point.y - 100, 10, 200], "occlusion_policy": "los_cutaway"}]
	_sample_tell(node, rival, {}, "opaque geometry hides rival pause as well as the body")
	node.campus_layout.data.buildings = buildings
	_sample_tell(node, rival, full, "clear view restores source countdown without changing its clock")
	_place(node, 2, Vector2i(node.solo_trial.court.end.x, center.y))
	_refresh_motion(node)
	_sample_tell(node, rival, {}, "outside court cannot advertise a pause")
	_place(node, 2, center + Vector2i(100000, 0))
	_refresh_motion(node)
	node.world.tick = Rival.READY_END


func _test_ready_to_windup(node: Node) -> void:
	var rival: PlayerState = node.world.player(2)
	_sample(node, rival, 0, "fresh production trial remains quiet during ready")
	var all_steps := true
	while node.world.tick < Rival.READY_END:
		if not node.step_trial(SimCommand.new(node.world.tick, 1)):
			all_steps = false
			break
		if node.world.tick == Rival.READY_END - 1:
			_sample(node, rival, 0, "last real ready tick has no Heavy warning")
	check(all_steps, "ordinary neutral commands advance the production ready countdown")
	equal(node.solo_trial.phase, Run.ACTIVE, "observed authority makes the trial active at the actual ready boundary")
	check(node._chemistry_actor_visible(rival), "authored starting rival is visible through the inherited actor gate")
	_sample(node, rival, 6, "first actual windup displays six segments on the owned rival")


func _test_owner_and_phase_guards(node: Node) -> void:
	var rival: PlayerState = node.world.player(2)
	var owned_world: SimWorld = node.world
	node.world = null
	equal(node._solo_rival_heavy_tell_segments(rival), 0, "missing authority has no world warning")
	node.world = owned_world
	var transport: SessionTransport = node.session_transport
	node.session_transport = null
	_sample(node, rival, 0, "missing session has no world warning")
	node.session_transport = transport
	_sample(node, null, 0, "missing actor is never a rival warning")
	_sample(node, node.world.player(1), 0, "local player cannot borrow the rival warning")
	var impostor := PlayerState.new(2)
	check(node.champion_catalog.apply_to_player(impostor, "oh_tipi"), "impostor has the same real champion identity")
	impostor.position_x = rival.position_x
	impostor.position_y = rival.position_y
	_sample(node, impostor, 0, "matching entity number and champion do not replace the actual world opponent")
	var other := PlayerState.new(3)
	_sample(node, other, 0, "unrelated actor cannot borrow the rival warning")
	rival.actor_kind = PlayerState.ActorKind.TRAINING_TARGET
	_sample(node, rival, 0, "training target with entity two is not a duelling champion")
	rival.actor_kind = PlayerState.ActorKind.CHAMPION
	for mode: int in [SessionTransport.Mode.HOSTING, SessionTransport.Mode.CONNECTING, SessionTransport.Mode.CLIENT]:
		node.session_transport.mode = mode
		_sample(node, rival, 0, "every non-offline mode rejects a stale trial warning")
	node.session_transport.mode = SessionTransport.Mode.OFFLINE
	node.interception_practice_active = false
	_sample(node, rival, 0, "inactive trial cannot borrow stale active bookkeeping")
	node.interception_practice_active = true
	for phase: String in [Run.IDLE, Run.READY, Run.VICTORY, Run.DEFEATED, Run.TIMEOUT, Run.LEFT_COURT, Run.UNAVAILABLE]:
		node.solo_trial.phase = phase
		_sample(node, rival, 0, "ready and terminal trial phases never advertise an active warning")
	node.solo_trial.phase = Run.ACTIVE
	var health := rival.health
	rival.health = 0
	_sample(node, rival, 0, "rival death hides the warning before bookkeeping catches up")
	rival.health = health
	var player: PlayerState = node.world.player(1)
	health = player.health
	player.health = 0
	_sample(node, rival, 0, "dead local observer cannot reveal the rival warning")
	player.health = health
	_sample(node, rival, 6, "restored living offline ownership still admits the same warning")


func _test_clock_and_effects(node: Node) -> void:
	# Source-only presentation samples, not additional encounter success proof.
	# The policy clock is authority tick/start tick, never visual time or effects.
	var rival: PlayerState = node.world.player(2)
	var cases := [[Rival.READY_END - 1, 0], [Rival.READY_END, 6],
		[Rival.READY_END + 15, 6], [Rival.READY_END + 16, 5],
		[Rival.READY_END + Rival.WINDUP_TICKS - 1, 1],
		[Rival.READY_END + Rival.WINDUP_TICKS, 0],
		[Rival.READY_END + Rival.WINDUP_TICKS + Rival.PRESSURE_TICKS, 0],
		[Rival.READY_END + Rival.CYCLE_TICKS - 1, 0],
		[Rival.READY_END + Rival.CYCLE_TICKS, 6], [Rival.DURATION_TICKS, 0]]
	for reduced: bool in [false, true]:
		node.player_preferences.reduced_motion = reduced
		for boundary: Array in cases:
			node.world.tick = int(boundary[0])
			_sample(node, rival, int(boundary[1]), "Normal and Reduced use the exact authoritative phase boundary")
	node.player_preferences.reduced_motion = false
	node.world.tick = Rival.READY_END
	var setup: Dictionary = node.interception_practice_setup
	node.interception_practice_setup = {}
	_sample(node, rival, 0, "missing setup start cannot manufacture a warning")
	node.interception_practice_setup = setup


func _place(node: Node, actor_id: int, point: Vector2i) -> void:
	var actor: PlayerState = node.world.player(actor_id)
	actor.position_x = point.x
	actor.position_y = point.y
	if actor_id == 1:
		node.current_position = Vector2(point) / SimConfig.FIXED_SCALE
		node.previous_position = node.current_position


func _refresh_motion(node: Node) -> void:
	node.accumulator_seconds = 0.0
	node.actor_motion_history.clear()
	node.actor_motion_history.capture(node.world.players)


func _test_court_edges(node: Node) -> void:
	var rival: PlayerState = node.world.player(2)
	var court: Rect2i = node.solo_trial.court
	var center := court.get_center()
	var cases := [
		[Vector2i(court.position.x, center.y), 6], [Vector2i(court.position.x - 1, center.y), 0],
		[Vector2i(court.end.x - 1, center.y), 6], [Vector2i(court.end.x, center.y), 0],
		[Vector2i(center.x, court.position.y), 6], [Vector2i(center.x, court.position.y - 1), 0],
		[Vector2i(center.x, court.end.y - 1), 6], [Vector2i(center.x, court.end.y), 0],
	]
	for boundary: Array in cases:
		var point: Vector2i = boundary[0]
		_place(node, 1, Vector2i(clampi(point.x, court.position.x + 100000, court.end.x - 100000), clampi(point.y, court.position.y + 100000, court.end.y - 100000)))
		_place(node, 2, point)
		_refresh_motion(node)
		check(node._chemistry_actor_visible(rival), "court edge fixture is visible so only court admission decides")
		_sample(node, rival, int(boundary[1]), "each exact fixed-point court edge uses the real half-open boundary")
	_place(node, 1, center - Vector2i(100000, 0))
	_place(node, 2, center + Vector2i(100000, 0))
	_refresh_motion(node)
	_sample(node, rival, 6, "ordinary re-entry restores the existing windup without restarting its clock")


func _test_shared_visibility(node: Node) -> void:
	var rival: PlayerState = node.world.player(2)
	var court: Rect2i = node.solo_trial.court
	var center := court.get_center()
	_place(node, 1, court.position + Vector2i(30000, 30000))
	_place(node, 2, court.end - Vector2i(30000, 30000))
	_refresh_motion(node)
	check(court.has_point(Vector2i(rival.position_x, rival.position_y)), "expanded-range fixture remains inside the real court")
	var observer: PlayerState = node.world.player(1)
	var observer_point: Vector2 = node._pov_actor_ground_position(observer)
	var rival_point: Vector2 = node._pov_actor_ground_position(rival)
	check(SightOcclusion.inverse_project_ground(rival_point - observer_point).length() > PlayerPreferences.RELATIVE_SIGHT_RANGE, "far court witness exceeds the legacy ground-metric radius")
	check(node._chemistry_actor_visible(rival), "attached viewport expands shared sight beyond the legacy fixed radius")
	_sample(node, rival, 6, "visible in-court rival retains its real warning at the expanded sight range")
	check(not node._pov_point_visible(observer_point + Vector2(float(node._pov_sight_range(observer)) + 1.0, 0)), "attached viewport still rejects points beyond its finite expanded range")
	_place(node, 1, center - Vector2i(100000, 0))
	_place(node, 2, center + Vector2i(100000, 0))
	_refresh_motion(node)
	var buildings: Array = node.campus_layout.data.buildings
	var center_pixels := Vector2i(center / SimConfig.FIXED_SCALE)
	node.campus_layout.data.buildings = [{"bounds": [center_pixels.x - 5, center_pixels.y - 100, 10, 200], "occlusion_policy": "los_cutaway"}]
	check(not node._chemistry_actor_visible(rival), "opaque geometry hides the actual rival through the existing visibility helper")
	_sample(node, rival, 0, "hidden rival cannot disclose its attack through the badge")
	rival.chemistry_reveal_ticks = 2
	_sample(node, rival, 0, "chemical reveal does not bypass opaque geometry for the warning")
	rival.chemistry_reveal_ticks = 0
	# Two adjacent samples straddle the wall without exceeding motion snap distance.
	for reverse: bool in [false, true]:
		var near := center - Vector2i(20000, 0)
		var far := center + Vector2i(20000, 0)
		_place(node, 2, far if reverse else near)
		_refresh_motion(node)
		_place(node, 2, near if reverse else far)
		node.actor_motion_history.capture(node.world.players)
		_sample(node, rival, 0 if reverse else 6, "warning follows the visible interpolated actor, not its latest authority position")
		node.accumulator_seconds = 1.0 / 120.0
		_sample(node, rival, 6 if reverse else 0, "warning regates when the interpolated actor crosses the opaque boundary")
	node.campus_layout.data.buildings = buildings
	_refresh_motion(node)
	_sample(node, rival, 6, "removing sight occlusion restores the same source-clock warning")
