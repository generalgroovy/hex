extends SceneTree
## Presentation CPU diagnostic, NOT a rendered-frame or GPU capacity gate.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var output := ""
	var dynamic := false
	var dense_reference := false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
		if argument == "--dynamic": dynamic=true
		if argument == "--dense-reference": dense_reference=true
	if not output.begins_with("res://.godot/character-stream-") or ".." in output or FileAccess.file_exists(output):
		push_error("Fresh contained output required");quit(1);return
	var language := VisualLanguage.new()
	var presenter := CartoonChampionPresenter.new()
	if not language.load_from_file() or not presenter.configure(language) or not presenter.enable_fullbody_art():
		push_error(presenter.last_error);quit(1);return
	if dense_reference:
		# Diagnostic-only control: original full-square topology, identical pose
		# math and stream path. This is not a user setting or a different engine.
		for id: String in presenter.fullbody_art.entries:
			for facing: int in 8:
				presenter.fullbody_art.skin_tables["%s/%d" % [id,facing]]=presenter.fullbody_art.compile_skin(presenter.fullbody_art.entries[id].directions[presenter.fullbody_art.DIRS[facing]])
	var config := SimConfig.new(120)
	var ids: Array = presenter.champions.keys()
	ids.sort()
	ids=ids.slice(0,8)
	var players: Array[PlayerState] = []
	for index: int in ids.size():
		var actor := PlayerState.new(index+1)
		actor.aim_x=0
		actor.aim_y=1000
		actor.velocity_x=MovementTuning.BASE_SPEED
		actor.movement_mode=PlayerState.MovementMode.WALK
		players.append(actor)
	var times: Array[int] = []
	var meshes_verified := 0
	for frame: int in 960:
		var mode := PlayerState.MovementMode.WALK if frame%240<120 else PlayerState.MovementMode.SPRINT
		for actor: PlayerState in players:
			actor.movement_mode=mode
			if dynamic:
				actor.velocity_x=roundi(MovementTuning.BASE_SPEED*(0.15+0.85*absf(sin(frame*0.031))))
				actor.cast_recovery_ticks=1+frame%config.milliseconds_to_ticks(90)
		var started := Time.get_ticks_usec()
		for index: int in players.size():
			var pose := presenter.movement_frame(ids[index],players[index],frame*0.5,config,false,float(frame%48)/48.0)
			if not pose.has("render_mesh"):
				push_error("Expected streaming pose: "+ids[index]);quit(1);return
			meshes_verified+=1
		if frame>=240: times.append(Time.get_ticks_usec()-started)
	times.sort()
	var receipt := {"status":"passed","scope":"720 measured CPU pose-update batches after240 warmups; eight detailed actors, walk/run changes; no rendering, GPU completion, simulation, networking or physical input", "build_id":JSON.parse_string(FileAccess.get_file_as_string(RuntimeBuildIdentity.MANIFEST_PATH)).build_id,"actors":players.size(),"pose_queries":meshes_verified,"batch_p50_us":times[360],"batch_p95_us":times[684],"batch_max_us":times[-1],"cached_source_meshes":presenter.fullbody_art.meshes.size(),"stream_buffers":presenter.fullbody_art.render_meshes.size()}
	receipt.dynamic_cast_and_stride=dynamic
	receipt.dense_reference=dense_reference
	var live_vertices := 0
	for entry: Dictionary in presenter.fullbody_art.render_meshes.values():
		live_vertices += (entry.mesh.get_meta("cpu_vertices") as PackedVector3Array).size()
	receipt.live_stream_vertices=live_vertices
	receipt.untrimmed_stream_vertices=players.size()*289
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file==null: quit(1);return
	file.store_string(JSON.stringify(receipt,"\t")+"\n")
	file.close()
	print("CHARACTER_STREAM ",JSON.stringify(receipt))
	quit(0)
