extends SceneTree
## Bounded CPU selection comparison, not identical pixels or end-to-end120Hz.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var output := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	if not output.begins_with("res://.godot/pixel-pilot-profile-") or ".." in output or FileAccess.file_exists(output):
		push_error("Fresh contained pixel profile required");quit(1);return
	var language := VisualLanguage.new()
	var old := CartoonChampionPresenter.new()
	var pilot := CartoonChampionPresenter.new()
	if not language.load_from_file() or not old.configure(language) or not pilot.configure(language) or not old.enable_fullbody_art() or not pilot.enable_fullbody_art(true):
		push_error("Character profile admission failed");quit(1);return
	var config := SimConfig.new(120)
	var ids := ["s_wayne","oh_tipi","red_baron"]
	var players: Array[PlayerState] = []
	for index: int in 8: players.append(PlayerState.new(index+1))
	var times := {"shared_rig":[],"fixed_pixel":[]}
	var checks := 0
	for sample: int in 400:
		for index: int in 8:
			var actor := players[index]
			var aim: Vector2i = EightDirectionResolver.FIXED_VECTORS[(sample/17+index)%8]
			var travel: Vector2i = EightDirectionResolver.FIXED_VECTORS[(sample/23+index)%8]
			actor.aim_x=aim.x;actor.aim_y=aim.y
			actor.velocity_x=travel.x*200;actor.velocity_y=travel.y*200
			actor.movement_mode=PlayerState.MovementMode.WALK if sample%80<40 else PlayerState.MovementMode.SPRINT
			actor.cast_recovery_ticks=6 if sample%3==0 else 0
		var order := ["shared_rig","fixed_pixel"] if sample%2==0 else ["fixed_pixel","shared_rig"]
		for mode: String in order:
			var presenter := pilot if mode=="fixed_pixel" else old
			var start := Time.get_ticks_usec()
			for index: int in 8:
				var frame := presenter.movement_frame(ids[index%3],players[index],sample/2.0,config,false,float(sample%48)/48.0)
				if frame.is_empty() or (mode=="fixed_pixel" and frame.has("mesh")):
					push_error("Invalid profile frame");quit(1);return
				checks+=1
			if sample>=80: times[mode].append(Time.get_ticks_usec()-start)
	var result := {"scope":"CPU frame selection/update only: eight actors from the same three identities, alternating sample order,80warmup/320measured batches. Artwork differs. No rendering/simulation/network/FPS acceptance.","queries":checks,"results":{}}
	for mode: String in times:
		times[mode].sort()
		result.results[mode]={"p50_us":times[mode][160],"p95_us":times[mode][304],"max_us":times[mode][-1]}
	result.build_id=JSON.parse_string(FileAccess.get_file_as_string(RuntimeBuildIdentity.MANIFEST_PATH)).build_id
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t")+"\n");file.close()
	print("PIXEL_BODY_CPU ",JSON.stringify(result));quit(0)
