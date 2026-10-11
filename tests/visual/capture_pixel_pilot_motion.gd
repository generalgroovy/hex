extends SceneTree
## Actual Wellspring frames with production command fixtures, not physical input.
const Bootstrap = preload("res://src/app/bootstrap.gd")
var output := ""
var delayed_spell_slot := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
		elif argument.begins_with("--capture-delayed-slot="):
			var requested := argument.trim_prefix("--capture-delayed-slot=")
			if not requested.is_valid_int() or requested.to_int() < 1 or requested.to_int() > PlayerState.SPELL_SLOT_COUNT:
				push_error("Delayed spell slot must be 1 through 12");quit(1);return
			delayed_spell_slot=requested.to_int()
	# An external probe can render the preserved PCK without writing into its folder.
	var valid_output := output.begins_with("res://.godot/pixel-pilot-motion-") or (output.is_absolute_path() and output.replace("\\", "/").contains("/.godot/pixel-pilot-motion-"))
	if not valid_output or ".." in output or DirAccess.dir_exists_absolute(output) or DisplayServer.get_name()=="headless":
		push_error("Fresh contained native motion output required");quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	var game := Bootstrap.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	var frames: Array = []
	var delayed_air_cast := OS.get_cmdline_user_args().has("--capture-delayed-air-cast")
	var stop_start := OS.get_cmdline_user_args().has("--capture-stop-start")
	if stop_start and delayed_air_cast:
		push_error("Choose one motion acceptance lane");quit(1);return
	if delayed_air_cast and game.capture_pointer_world.x < 0:
		push_error("Paid airborne capture requires an explicit --capture-pointer=x,y; desktop mouse position must not choose its cast endpoint");quit(1);return
	var champion_id: String = game.champion_catalog.champion_id_from_wire(game._local_player_state().champion_wire_id)
	var expected_wire: int = game._local_player_state().active_1_wire_id if delayed_spell_slot == 0 else game._local_player_state().spell_wire_id(delayed_spell_slot)
	if delayed_air_cast and (game.requested_capture_spell_slot != 0 or game.requested_capture_active_cast):
		push_error("Delayed airborne capture cannot also request an immediate cast");quit(1);return
	if delayed_air_cast and AbilityCatalog._spell_family(game.ability_catalog.ability_from_wire(expected_wire)) != "spray":
		push_error("Delayed airborne cast review requires the actual actor's paid Spray kit; do not inject cast state");quit(1);return
	var requested_air_cast := false
	var paid_air_casts := 0
	var paid_wire := 0
	var air_releases := 0
	var fixed_air_cast_ticks := 0
	var fixed_landing_ticks := 0
	var captured_landing := false
	var restart_phases: Array[float] = []
	var restart_advances := 0
	var stopped_pose_seen := false
	for tick: int in (240 if delayed_air_cast or stop_start else 120):
		if stop_start:
			game.requested_capture_movement = "walk" if tick % 80 < 40 else "grounded"
			if tick in [80,160]: restart_phases.append(game.actor_motion_history.gait_phase(game._local_player_state().entity_id))
		var before_actor: PlayerState = game._local_player_state()
		if delayed_air_cast and not requested_air_cast and before_actor.air_height > 0:
			# Arm the existing one-shot capture command only after real takeoff.
			# No resource, movement-plane or pending-cast state is injected.
			game.requested_capture_active_cast=true
			game.requested_capture_spell_slot=delayed_spell_slot
			game.capture_active_cast_sent=false
			requested_air_cast=true
		if delayed_air_cast and tick >= 40:
			game.requested_capture_movement="grounded" # Neutral input allows a planted landing review.
		var before_flux := before_actor.flux
		# This fixture owns synthetic commands; desktop focus is not test input.
		# Leave the application's real focus-loss guard unchanged for players.
		game.application_input_active = true
		game._process(1.0/120.0)
		var actor: PlayerState = game._local_player_state()
		var gait: float = game.actor_motion_history.gait_phase(actor.entity_id)
		var art: Dictionary = game.cartoon_champion_presenter.movement_frame(champion_id,actor,float(game.world.tick)/2.0,game.world.config,false,gait)
		if stop_start:
			if tick in [82,162] and not is_equal_approx(gait, restart_phases[-1]): restart_advances += 1
			if tick % 80 >= 65 and art.get("action") == "idle": stopped_pose_seen = true
		if delayed_air_cast:
			for event: Dictionary in game.world.combat_events:
				if event.get("type")=="cast_started" and event.get("entity_id")==actor.entity_id and actor.air_height > 0 and actor.flux < before_flux:
					paid_air_casts+=1
					paid_wire=int(event.get("wire_id",0))
				if event.get("type")=="spray_fired" and event.get("owner_id")==actor.entity_id and event.get("source_wire_id")==paid_wire and actor.air_height > 0:
					air_releases+=1
			if actor.air_height > 0 and actor.pending_cast_wire_id > 0 and art.get("pixel_action_key",false): fixed_air_cast_ticks+=1
			if art.get("action")=="land" and art.get("pixel_action_key",false): fixed_landing_ticks+=1
		var first_landing: bool = delayed_air_cast and art.get("action")=="land" and not captured_landing
		if tick%8!=0 and not first_landing: continue
		if first_landing: captured_landing=true
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var leaf := "frame-%03d.png" % tick
		if root.get_texture().get_image().save_png(output.path_join(leaf))!=OK:
			push_error("Native motion image failed");quit(1);return
		frames.append({"image":leaf,"tick":game.world.tick,"movement":actor.movement_mode,
			"position":[actor.position_x,actor.position_y],"velocity":[actor.velocity_x,actor.velocity_y],
			"pending_cast":actor.pending_cast_wire_id,"cast_recovery":actor.cast_recovery_ticks,
			"air_height":actor.air_height,"landing_ticks":actor.landing_ticks,"gait_phase":gait,"action":art.get("action",""),"action_key":art.get("frame_id","")})
	var motion_passed := delayed_air_cast and paid_air_casts>0 and paid_wire==expected_wire and air_releases>0 and fixed_air_cast_ticks>0 and fixed_landing_ticks>0
	if stop_start: motion_passed = restart_advances == 2 and stopped_pose_seen
	var file := FileAccess.open(output.path_join("receipt.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"capture_succeeded":true,"motion_acceptance":("PASS" if motion_passed else ("FAILED" if delayed_air_cast or stop_start else "NOT_RUN")),"passed":motion_passed,"champion":champion_id,"capture_pointer":[game.capture_pointer_world.x,game.capture_pointer_world.y],"frames":frames,"paid_air_casts":paid_air_casts,"paid_wire":paid_wire,"air_releases":air_releases,"fixed_air_cast_ticks":fixed_air_cast_ticks,"fixed_landing_ticks":fixed_landing_ticks,"stop_start":stop_start,"restart_advances":restart_advances,"stopped_pose_seen":stopped_pose_seen,"scope":"actual Bootstrap/map/render path; production capture commands and explicit pointer. Delayed-air-cast validates paid airborne admission/release and planted landing; stop-start validates two resumed gait clocks and a stopped pose. Ordinary mode is capture-only. Fixed-step capture, not physical input, complete animation-cycle or performance acceptance"},"\t")+"\n")
	file.close()
	if (delayed_air_cast or stop_start) and not motion_passed:
		push_error("Requested motion lane did not satisfy every acceptance check; inspect receipt");quit(1);return
	print("PASS motion lane: " if motion_passed else "CAPTURE ONLY: ",frames.size()," actual Wellspring frames")
	game.queue_free();await process_frame;quit(0)
