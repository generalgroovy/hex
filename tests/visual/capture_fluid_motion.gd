extends SceneTree
## A complete cycle, not a posed still: three sizes x eight directions.
var output := ""
var samples := 24
var refined := false
var reduced := false

class Board:
	extends Node2D
	var presenter: CartoonChampionPresenter
	var mode := "walk"
	var frame_index := 0
	var samples := 24
	var config := SimConfig.new(120)
	var failed := false
	var reduced := false
	var language: VisualLanguage
	func _draw() -> void:
		PixelMagicLibrary.default_library().begin_frame(reduced)
		draw_rect(Rect2(0,0,1024,420),Color("263b35"))
		draw_string(ThemeDB.fallback_font,Vector2(16,24),"H.E.X. / " + mode + " / three sizes, eight headings" + (" / reduced" if reduced else ""),HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("ead9b6"))
		var ids := ["wa_bidi","jan_wicked","fluup"]
		for row: int in 3:
			for heading: int in 8:
				var ground := Vector2(64+heading*128,138+row*130)
				var state := PlayerState.new()
				state.entity_id = 800+row*8+heading
				var travel: Vector2i = EightDirectionResolver.FIXED_VECTORS[heading]
				state.aim_x = travel.x
				state.aim_y = travel.y
				state.velocity_x = travel.x*373
				state.velocity_y = travel.y*373
				state.movement_mode = PlayerState.MovementMode.WALK
				if mode == "sprint":
					state.movement_mode = PlayerState.MovementMode.SPRINT
					state.velocity_x *= 1.6
					state.velocity_y *= 1.6
				elif mode in ["wallrun", "blocked_wall"]:
					state.air_height = 20000
					state.hop_ticks = 20
					state.wall_skim_ticks = maxi(1,config.milliseconds_to_ticks(MovementTuning.WALL_SKIM_DURATION_MS)-roundi(float(frame_index)*48.0/samples))
					state.wall_skim_x = travel.x
					state.wall_skim_y = travel.y
					if mode == "blocked_wall":
						state.velocity_x = 0
						state.velocity_y = 0
						state.aim_x = EightDirectionResolver.FIXED_VECTORS[(heading+frame_index)%8].x
						state.aim_y = EightDirectionResolver.FIXED_VECTORS[(heading+frame_index)%8].y
				elif mode == "landing":
					state.velocity_x = 0
					state.velocity_y = 0
					state.facing_x = travel.x
					state.facing_y = travel.y
					state.landing_ticks = maxi(1,config.milliseconds_to_ticks(MovementTuning.LANDING_WINDOW_MS)-frame_index)
					state.landing_intensity = 350 + row * 325
				elif mode == "hit":
					state.control_state = PlayerState.ControlState.LAUNCHED
					state.control_ticks = maxi(1, 30-frame_index)
				elif mode == "moving_cast":
					var progress := float(frame_index)/maxi(1,samples-1)
					var speed := 0.15+0.85*sin(progress*PI)
					state.velocity_x = roundi(travel.x*MovementTuning.BASE_SPEED/1000.0*speed)
					state.velocity_y = roundi(travel.y*MovementTuning.BASE_SPEED/1000.0*speed)
					var aim: Vector2i = EightDirectionResolver.FIXED_VECTORS[(heading+2)%8]
					state.aim_x=aim.x
					state.aim_y=aim.y
					if progress < 0.4:
						state.pending_cast_wire_id=145
						state.pending_cast_ticks=roundi(config.milliseconds_to_ticks(int(CombatTuning.cast_definition(145).startup_ms))*(1.0-progress/0.4))
					else: state.cast_recovery_ticks=roundi(config.milliseconds_to_ticks(90)*(1.0-(progress-0.4)/0.6))
				draw_set_transform(ground,0,Vector2(1,0.4))
				draw_circle(Vector2.ZERO,16,Color(0.04,0.07,0.05,0.6))
				draw_set_transform(Vector2.ZERO)
				var before := state.canonical_values()
				if mode == "landing": LandingPresentation.draw(self, ground, LandingPresentation.sample(state, config, 0.0, reduced), language)
				var phase := 0.25 if mode == "blocked_wall" else float(frame_index)/samples
				if not presenter.draw(self,state,ids[row],ground-Vector2(0,20 if mode in ["wallrun", "blocked_wall"] else 0),float(frame_index)*24.0/samples,config,reduced,ground,phase,travel if mode in ["wallrun", "blocked_wall"] else Vector2i.ZERO): failed=true
				if state.canonical_values() != before: failed=true

func _initialize() -> void:
	root.hide()
	_run.call_deferred()

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
		if argument=="--samples=48": samples=48
		if argument=="--refined": refined=true
		if argument=="--reduced": reduced=true
	if not output.begins_with("res://.godot/fluid-motion-") or ".." in output or DirAccess.dir_exists_absolute(output):
		push_error("Fresh contained output required");quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	var language := VisualLanguage.new()
	var presenter := CartoonChampionPresenter.new()
	if not language.load_from_file() or not presenter.configure(language) or not presenter.enable_fullbody_art():
		push_error(presenter.last_error);quit(1);return
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1024,420)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := Board.new()
	board.presenter=presenter
	board.samples=samples
	board.reduced=reduced
	board.language=language
	board.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(board)
	var modes: Array[String] = ["walk","sprint","wallrun","moving_cast"]
	if refined: modes.append_array(["blocked_wall", "landing", "hit"])
	for mode: String in modes:
		board.mode=mode
		for index: int in samples:
			board.frame_index=index
			board.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			if board.failed or viewport.get_texture().get_image().save_png(output.path_join("%s-%02d.png" % [mode,index])) != OK:
				push_error("Motion capture failed");quit(1);return
	print("PASS: %d native motion frames; three bodies/eight headings; authority unchanged" % (samples*modes.size()))
	quit(0)
