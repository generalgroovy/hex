extends SceneTree
## Native render acceptance boards through the actual game presenter, not workbench.
var output := ""

class Board:
	extends Node2D
	var presenter: CartoonChampionPresenter
	var ids: Array = []
	var mode := "roster"
	var phase := 0.0
	var config := SimConfig.new(120)
	var failed := false
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,800),Color("263b35"))
		draw_string(ThemeDB.fallback_font,Vector2(20,25),"H.E.X. in-game character art / "+mode,HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("ead9b6"))
		for index: int in ids.size():
			var ground := Vector2(100+(index%6)*210,170+(index/6)*150)
			var state := PlayerState.new()
			var direction := index%8 if mode != "roster" else 0
			var travel: Vector2i = EightDirectionResolver.FIXED_VECTORS[direction]
			state.aim_x = travel.x
			state.aim_y = travel.y
			if mode.begins_with("walk"):
				state.movement_mode = PlayerState.MovementMode.WALK
				state.velocity_x = -travel.x*200
				state.velocity_y = -travel.y*200
				state.pending_cast_wire_id = 1
			elif mode == "slide":
				state.movement_mode = PlayerState.MovementMode.SLIDE
				state.slide_ticks = 12
				state.velocity_x = travel.x*300
				state.velocity_y = travel.y*300
			elif mode == "jump":
				state.movement_mode = PlayerState.MovementMode.HOP
				state.air_height = 20000
				state.air_vertical_velocity = 30000
				state.hop_ticks = 20
			draw_set_transform(ground,0,Vector2(1,0.4))
			draw_circle(Vector2.ZERO,16,Color(0.04,0.07,0.05,0.6))
			draw_set_transform(Vector2.ZERO)
			var before := state.canonical_values()
			if not presenter.draw(self,state,ids[index],ground-Vector2(0,20 if mode=="jump" else 0),30,config,false,ground,phase): failed = true
			if state.canonical_values() != before: failed = true
			draw_string(ThemeDB.fallback_font,ground+Vector2(-65,28),ids[index],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("ead9b6"))

func _initialize() -> void:
	root.hide()
	_run.call_deferred()

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	if not output.begins_with("res://.godot/fullbody-capture-") or ".." in output or DirAccess.dir_exists_absolute(output):
		push_error("Fresh contained output required");quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	var language := VisualLanguage.new()
	var presenter := CartoonChampionPresenter.new()
	if not language.load_from_file() or not presenter.configure(language) or not presenter.enable_fullbody_art():
		push_error(presenter.last_error);quit(1);return
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1280,800)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := Board.new()
	board.presenter=presenter
	board.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	board.ids=presenter.champions.keys()
	viewport.add_child(board)
	for mode: String in ["roster","walk-a","walk-b","slide","jump"]:
		board.mode=mode
		board.phase=0.0 if mode=="walk-a" else 0.5
		board.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		if board.failed or viewport.get_texture().get_image().save_png(output.path_join(mode+".png")) != OK:
			push_error("Capture failed");quit(1);return
	print("PASS: five native production-presenter boards, all30 identities; no authority mutation")
	quit(0)
