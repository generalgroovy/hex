extends SceneTree
## Native all-roster review: actual presenter, no body stretching or state writes.
const Art = preload("res://src/presentation/fullbody_cast_presenter.gd")
var output := ""

class Board:
	extends Node2D
	var presenter: CartoonChampionPresenter
	var identity := "oh_tipi"
	var checks := 0
	var failed := false
	var config := SimConfig.new(120)
	func _draw() -> void:
		draw_rect(Rect2(0,0,1024,1056),Color("31473e"))
		draw_string(ThemeDB.fallback_font,Vector2(8,22),"H.E.X. / %s / idle, A, neutral, B, neutral, cast+A, cast+B, backpedal+A" % identity,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("f3d9a1"))
		for row: int in 8:
			for aim: int in 8:
				var state := PlayerState.new()
				var look: Vector2i = EightDirectionResolver.FIXED_VECTORS[aim]
				var move: Vector2i = EightDirectionResolver.FIXED_VECTORS[(aim+4)%8 if row==7 else aim]
				state.aim_x=look.x;state.aim_y=look.y
				if row>0:
					state.velocity_x=move.x*200;state.velocity_y=move.y*200
					state.movement_mode=PlayerState.MovementMode.WALK
				state.pending_cast_wire_id=1 if row in [5,6] else 0
				state.pending_cast_ticks=0
				var phase: float = [0.0,0.0,0.25,0.5,0.75,0.0,0.5,0.0][row]
				var before := state.canonical_values()
				var frame := presenter.movement_frame(identity,state,0.0,config,false,phase)
				if frame.get("visual_mode")!="pixel_cast" or frame.has("mesh") or state.canonical_values()!=before:
					failed=true
					continue
				var at := Vector2(aim*128+64,row*128+136)
				Art.draw_frame(self,frame,at)
				draw_string(ThemeDB.fallback_font,at+Vector2(-30,15),Art.DIRS[aim],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("c6d0bc"))
				checks+=1

func _initialize() -> void:
	root.hide()
	_run.call_deferred()

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
	var probe_root: String = ProjectSettings.globalize_path(str(get_script().resource_path)).get_base_dir().get_base_dir().get_base_dir().replace("\\","/")
	var contained: bool = output.begins_with("res://.godot/pixel-cast-") or output.begins_with(probe_root.path_join(".godot/pixel-cast-"))
	if not contained or ".." in output or DirAccess.dir_exists_absolute(output):
		push_error("Fresh contained pixel-cast output required");quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	var language := VisualLanguage.new()
	var presenter := CartoonChampionPresenter.new()
	if not language.load_from_file() or not presenter.configure(language) or not presenter.enable_fullbody_art(false,true):
		push_error(presenter.last_error);quit(1);return
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1024,1056)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := Board.new()
	board.presenter=presenter
	board.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(board)
	var images: Array[String] = []
	for identity: String in presenter.champions:
		board.identity=identity
		board.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var leaf := identity+".png"
		if board.failed or viewport.get_texture().get_image().save_png(output.path_join(leaf))!=OK:
			push_error("Pixel-cast capture failed");quit(1);return
		images.append(leaf)
	var receipt := FileAccess.open(output.path_join("receipt.json"),FileAccess.WRITE)
	receipt.store_string(JSON.stringify({"images":images,"checks":board.checks,
		"scope":"all catalog identities x8facings, contacts/neutral/moving casts/backpedal, native presenter",
		"human_acceptance":false,"all_actions_replaced":false},"\t")+"\n")
	receipt.close()
	print("PASS: ",images.size()," native pixel-cast boards / ",board.checks," checks; human and all-action acceptance remain open")
	quit(0)
