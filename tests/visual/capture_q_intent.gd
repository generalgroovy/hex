extends SceneTree

const Harness = preload("res://tests/support/chemistry_coach_harness.gd")
const PROFILES := ["s_wayne", "oh_tipi", "red_baron"]
const TRIALS := ["directional", "neutral-momentum", "float-neutral", "screen-down"]
var node: Node2D
var viewport: SubViewport
var output := ""
var records: Array[Dictionary] = []
var admissions: Array[Dictionary] = []


func _initialize() -> void:
	root.hide()
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if not output.begins_with("res://.godot/q-intent-render-") or ".." in output or DirAccess.dir_exists_absolute(output):
		fail("Provide a fresh --output=res://.godot/q-intent-render-NAME")
		return
	node = Harness.new()
	if not node.configure_fixture(true) or DirAccess.make_dir_recursive_absolute(output) != OK:
		fail("Cannot configure actual Q gameplay fixture")
		return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(node)
	for champion: String in PROFILES:
		for trial: String in TRIALS:
			if not await run_trial(champion, trial):
				return
	var receipt := FileAccess.open(output.path_join("capture-receipt.json"), FileAccess.WRITE)
	if receipt == null:
		fail("Cannot write Q capture receipt")
		return
	var hashes := {}
	for path: String in ["src/sim/movement/movement_system.gd", "src/sim/movement/movement_tuning.gd", "src/presentation/movement_guide_model.gd", "src/presentation/movement_practice_coach.gd", "src/app/bootstrap.gd", "tests/visual/capture_q_intent.gd"]:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	receipt.store_string(JSON.stringify({"schema_version":1,"frames":records,"admissions":admissions,
		"source_sha256":hashes,"movement_hash":MovementTuning.compatibility_hash(),"movement_matrix":MovementGuideModel.entries(),
		"map_hash":node.campus_layout.content_hash,"method":"fresh world, real profiles, paid ground jump and Float, semantic Q press, inherited production draw",
		"authority_unchanged_by_draw":true,"preferences":"transient_fixture_only","network":"not_started","audio":"not_started","human_acceptance":"not_run"}, "  "))
	receipt.close()
	print("PASS: %d actual Q-intent frames; %d real airborne admissions; three sizes; independent aim; normal/reduced; draw hashes unchanged" % [records.size(),admissions.size()])
	quit(0)


func run_trial(champion: String, trial: String) -> bool:
	node.world = SimWorld.new(120,912,node.campus_layout.build_collision_world())
	node.authoritative_session.world = node.world
	var actor: PlayerState = node.world.player()
	if not node.champion_catalog.apply_to_player(actor,champion):
		return fail("Actual profile unavailable")
	# Controlled grounded start inside the authored south loop; subsequent height,
	# velocity, protection and movement budgets come only from ordinary commands.
	actor.reset_for_spawn(Vector2i(496000,1920000))
	actor.spawn_protection_ticks = 0
	if not node.world.collision.can_occupy(Vector2i(actor.position_x,actor.position_y),actor.radius):
		return fail("South loop start collides")
	node.selected_champion_id = champion
	node.session_round_values = node.authoritative_session.session_round.capture(node.world)
	node.actor_motion_history.clear()
	for unused: int in 12:
		if not step(1000,0): return false
	var before_jump := actor.stamina
	if not step(1000,0,SimCommand.HELD_JUMP,SimCommand.PRESSED_JUMP) or not actor.is_airborne() or actor.stamina >= before_jump:
		return fail("Trial must use a real paid ground jump")
	for unused: int in 12:
		if not step(1000,0,SimCommand.HELD_JUMP): return false
	if trial == "float-neutral":
		if not step(0,0): return false
		var before_float := actor.stamina
		if not step(0,0,SimCommand.HELD_JUMP,SimCommand.PRESSED_JUMP) or not actor.air_floating or actor.stamina >= before_float:
			return fail("Trial must use real paid Float")
		for unused: int in node.world.config.milliseconds_to_ticks(MovementTuning.HOP_COMMITMENT_MS) + 1:
			if not step(0,0,SimCommand.HELD_JUMP): return false
	if not actor.is_airborne() or actor.air_height <= 0 or actor.movement_commitment_ticks > 0:
		return fail("Trial needs airborne height after commitment")
	var prefix := champion + "-" + trial
	if not await capture_pair(prefix + "-before"): return false
	var before := state_record(actor)
	var x := 1000 if trial == "directional" else 0
	var y := 1000 if trial == "screen-down" else 0
	var held := SimCommand.HELD_JUMP if trial == "float-neutral" else 0
	if not step(x,y,held,SimCommand.PRESSED_EVADE): return false
	var directional := x != 0 or y != 0
	if directional:
		if actor.air_dodge_ticks <= 0 or actor.stamina >= int(before.stamina) or actor.fast_falling:
			return fail("Directional Q must pay for a planar dodge")
	else:
		if not actor.fast_falling or actor.air_dodge_ticks > 0 or actor.air_vertical_velocity >= 0 or actor.stamina != int(before.stamina):
			return fail("Neutral Q must fast-fall vertically without dodge payment")
		if actor.air_floating or actor.float_used != bool(before.float_used) or actor.air_dodge_used != bool(before.air_dodge_used):
			return fail("Fast-fall must exit Float and preserve air budgets")
	admissions.append({"champion":champion,"trial":trial,"move":[x,y],"aim":[-1000,0],"before":before,"after":state_record(actor)})
	if not await capture_pair(prefix + "-admitted"): return false
	if not step(x,y,held): return false
	if not await capture_pair(prefix + "-travel"): return false
	for unused: int in 180:
		if not actor.is_airborne(): break
		if not step(0,0,held): return false
	if actor.is_airborne() or actor.air_height != 0 or actor.is_rolling():
		return fail("Natural landing must complete without a ground roll")
	return await capture_pair(prefix + "-landed")


func step(x: int, y: int, held: int = 0, pressed: int = 0) -> bool:
	var command := SimCommand.new(node.world.tick,1,x,y,held,pressed,-1000,0)
	var commands: Array[SimCommand] = [command]
	if not node.world.step(commands): return fail("Rejected actual gameplay command")
	return true


func state_record(actor: PlayerState) -> Dictionary:
	return {"tick":node.world.tick,"position":[actor.position_x,actor.position_y],"velocity":[actor.velocity_x,actor.velocity_y],
		"height":actor.air_height,"vertical_velocity":actor.air_vertical_velocity,"stamina":actor.stamina,"fast_falling":actor.fast_falling,
		"air_floating":actor.air_floating,"float_used":actor.float_used,"air_dodge_used":actor.air_dodge_used,
		"air_dodge_ticks":actor.air_dodge_ticks,"jump_protection_ticks":actor.jump_protection_ticks,"event":actor.last_event}


func capture_pair(label: String) -> bool:
	for reduced: bool in [false,true]:
		node.requested_capture_reduced_effects = reduced
		var actor: PlayerState = node.world.player()
		node.current_position = Vector2(actor.position_x,actor.position_y) / 1000.0
		node.previous_position = node.current_position
		node.previous_air_height = actor.air_height
		node.actor_motion_history.capture(node.world.players)
		var before: String = node.world.state_hash()
		node.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var pixels := viewport.get_texture().get_image()
		var filename := label + ("-reduced.png" if reduced else "-normal.png")
		if pixels == null or pixels.save_png(output.path_join(filename)) != OK or node.world.state_hash() != before:
			return fail("Q render failed or mutated authority")
		records.append({"file":filename,"reduced_effects":reduced,"state":state_record(actor),"world_hash":before,"draw_world_hash_unchanged":true,"coach":node._movement_practice_view()})
		print("RENDERED ", filename)
	return true


func fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
