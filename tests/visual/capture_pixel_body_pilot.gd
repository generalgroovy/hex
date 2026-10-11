extends SceneTree
## Real presenter, immutable pixels, independent8x8 aim/travel and casting.
const Art = preload("res://src/presentation/fullbody_cast_presenter.gd")
var output := ""

class Board:
	extends Node2D
	var presenter: CartoonChampionPresenter
	var identity := "s_wayne"
	var phase := 0.0
	var casting := false
	var failed := false
	var checks := 0
	var config := SimConfig.new(120)
	func _draw() -> void:
		draw_rect(Rect2(0,0,1024,1056),Color("31473e"))
		draw_string(ThemeDB.fallback_font,Vector2(8,22),"H.E.X. pixel pilot / %s / %s / phase%.2f / rows travel, columns aim" % [identity,"cast" if casting else "walk",phase],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("f3d9a1"))
		for travel: int in 8:
			for aim: int in 8:
				var state := PlayerState.new()
				var look: Vector2i = EightDirectionResolver.FIXED_VECTORS[aim]
				var move: Vector2i = EightDirectionResolver.FIXED_VECTORS[travel]
				state.aim_x = look.x
				state.aim_y = look.y
				state.velocity_x = move.x*200
				state.velocity_y = move.y*200
				state.movement_mode = PlayerState.MovementMode.WALK
				state.pending_cast_wire_id = 1 if casting else 0
				# Wire1 has a one-tick startup; remaining1 is its zero-weight entry.
				# Sample the fully reached cast here; unit tests cover the envelope.
				state.pending_cast_ticks = 0
				var before := state.canonical_values()
				var frame := presenter.movement_frame(identity,state,0,config,false,phase)
				if not frame.get("pixel_body_pilot",false) or frame.has("mesh") or state.canonical_values()!=before:
					failed = true
					continue
				var at := Vector2(aim*128+64,travel*128+136)
				Art.draw_frame(self,frame,at)
				draw_string(ThemeDB.fallback_font,at+Vector2(-38,15),"%s/%s" % [Art.DIRS[aim],Art.DIRS[travel]],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("c6d0bc"))
				checks += 1

func _initialize() -> void:
	root.hide()
	_run.call_deferred()

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	# An external probe can mount the exact exported PCK while keeping evidence
	# beside its source script, never writing into or modifying the package.
	var probe_root: String = ProjectSettings.globalize_path(str(get_script().resource_path)).get_base_dir().get_base_dir().get_base_dir().replace("\\", "/")
	var contained_output: bool = output.begins_with("res://.godot/pixel-pilot-") or output.begins_with(probe_root.path_join(".godot/pixel-pilot-"))
	if not contained_output or ".." in output or DirAccess.dir_exists_absolute(output):
		push_error("Fresh contained pixel-pilot output required");quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	var language := VisualLanguage.new()
	var presenter := CartoonChampionPresenter.new()
	if not language.load_from_file() or not presenter.configure(language) or not presenter.enable_fullbody_art(true):
		push_error(presenter.last_error);quit(1);return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1024,1056)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := Board.new()
	board.presenter = presenter
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(board)
	var images: Array[String] = []
	for identity: String in ["s_wayne","oh_tipi","red_baron"]:
		for casting: bool in [false,true]:
			for step: int in 4:
				board.identity = identity
				board.casting = casting
				board.phase = step/4.0
				board.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				var leaf := "%s-%s-%d.png" % [identity,"cast" if casting else "walk",step]
				if board.failed or viewport.get_texture().get_image().save_png(output.path_join(leaf))!=OK:
					push_error("Pixel-pilot capture failed");quit(1);return
				images.append(leaf)
	var receipt := FileAccess.open(output.path_join("receipt.json"),FileAccess.WRITE)
	receipt.store_string(JSON.stringify({"images":images,"checks":board.checks,
		"scope":"3 identities x8aim x8travel x4phases xwalk/cast; native presenter; no authority writes",
		"human_acceptance":false,"all_actions_replaced":false},"\t")+"\n")
	receipt.close()
	print("PASS: 24 native pixel-pilot matrices / ",board.checks," checks; human and all-action acceptance remain open")
	quit(0)
