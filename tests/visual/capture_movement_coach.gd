extends SceneTree

const Harness = preload("res://tests/support/chemistry_coach_harness.gd")
var node: Node2D
var viewport: SubViewport
var output := ""


func _initialize() -> void:
	root.hide()
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if not output.begins_with("res://.godot/movement-coach-render-") or ".." in output or DirAccess.dir_exists_absolute(output):
		fail("Provide a new --output=res://.godot/movement-coach-render-NAME")
		return
	node = Harness.new()
	if not node.configure_fixture(true) or DirAccess.make_dir_recursive_absolute(output) != OK:
		node.free()
		fail("Actual movement coach fixture failed setup")
		return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(node)
	var state: PlayerState = node.world.player()
	var wall := SanctumCampusLayout._parse_bounds(node.campus_layout.buildings_by_id[115].bounds)
	# One explicitly staged start; all subsequent actions use paid world steps.
	state.reset_for_spawn(Vector2i(wall.get_center().x * 1000, wall.end.y * 1000 + MovementTuning.PLAYER_RADIUS + 1000))
	state.velocity_y = -MovementTuning.BASE_SPEED
	if not await capture("grounded", "grounded"):
		return
	if not step(0,-1000) or state.wall_contact_id != 115:
		fail("Staged approach did not touch the actual southern worldbone")
		return
	var before := state.stamina
	if not step(1000,0,0,SimCommand.PRESSED_TECHNIQUE) or state.last_event != "wall_skim" or state.stamina >= before:
		fail("Real wallrun must begin and pay Stamina")
		return
	for unused: int in range(node.world.config.milliseconds_to_ticks(MovementTuning.WALL_RUN_COMMITMENT_MS) + 1):
		if not step(1000,0):
			return
	if not await capture("wallrun", "wallrun"):
		return
	if not step(0,1000,0,SimCommand.PRESSED_JUMP) or state.last_event not in ["wall_kick", "air_wall_kick"]:
		fail("Real wallrun did not kick into the open loop")
		return
	for unused: int in range(node.world.config.milliseconds_to_ticks(MovementTuning.HOP_COMMITMENT_MS) + 1):
		if not step(0,1000):
			return
	if not await capture("wall-exit", "airborne"):
		return
	if not step(1000,0,SimCommand.HELD_JUMP,SimCommand.PRESSED_JUMP):
		return
	for unused: int in range(node.world.config.milliseconds_to_ticks(MovementTuning.HOP_COMMITMENT_MS) + 1):
		if not step(1000,0,SimCommand.HELD_JUMP):
			return
	if not state.air_floating or not await capture("float", "float"):
		fail("Paid Float was not still active after its opening")
		return
	node.movement_practice_device = ControlBindingEditor.DEVICE_CONTROLLER
	node.requested_capture_reduced_effects = true
	node.player_preferences.set_camera_zoom_percent(75)
	if not await capture("float-controller-75-reduced", "float"):
		return
	node.player_preferences.set_camera_zoom_percent(50)
	if not await capture("float-controller-50-reduced", "float"):
		return
	print("PASS: six actual1280x720 views; paid wallrun/kick/Float; shared live draw; no sockets/preferences/audio; human feel remains open")
	quit(0)


func step(x: int, y: int, held: int = 0, pressed: int = 0) -> bool:
	var commands: Array[SimCommand] = [SimCommand.new(node.world.tick,1,x,y,held,pressed)]
	if not node.world.step(commands):
		fail("Actual movement command was invalid")
		return false
	return true


func capture(label: String, expected_kind: String) -> bool:
	var state: PlayerState = node.world.player()
	node.current_position = Vector2(state.position_x,state.position_y) / SimConfig.FIXED_SCALE
	node.previous_position = node.current_position
	node.previous_air_height = state.air_height
	node.actor_motion_history.capture(node.world.players)
	var view: Dictionary = node._movement_practice_view()
	if view.get("kind", "") != expected_kind or not node._chemistry_practice_view().is_empty():
		fail("Wrong contextual coach for " + label + ": " + JSON.stringify(view))
		return false
	node.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var rendered := viewport.get_texture().get_image()
	if rendered == null or rendered.save_png(output.path_join(label + ".png")) != OK:
		fail("Render readback failed for " + label)
		return false
	print("RENDERED ",label," tick=",node.world.tick," stamina=",state.stamina," view=",JSON.stringify(view))
	return true


func fail(message: String) -> void:
	push_error(message)
	quit(1)
