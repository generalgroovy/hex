extends SceneTree
@warning_ignore_start("integer_division")
## Live material stamp contact sheet, not simulated gameplay or capacity proof.
const Marks = preload("res://src/presentation/retro_material_marks.gd")

class Board:
	extends Node2D
	var marks := Marks.new()
	var language := VisualLanguage.new()
	var presenter := HexCourtPresenter.new()
	var sample := 0
	var failed := false
	func _draw() -> void:
		draw_rect(Rect2(0,0,990,390),Color("26342e"))
		draw_string(ThemeDB.fallback_font,Vector2(18,26),"H.E.X. | retro material pixels | live stamps, enlarged 4x",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("ead8b0"))
		var kinds := ["earth","fire","steam","magma","mud","ice","charge","light","dark","vortex"]
		for index: int in kinds.size():
			var kind: String = kinds[index]
			var style := presenter._shared_material_style(kind,{"phase":"active","danger":true,"intensity":1000},false)
			if kind=="steam": style=presenter._steam_region_style({"phase":"active","danger":true,"intensity":1000},1000,false)
			var dark: Color = style.dark
			var base: Color = style.base
			var bright: Color = style.bright
			var anchor := Vector2(95+index%5*197,116+index/5*166)
			draw_set_transform(anchor,0,Vector2(4,4))
			draw_rect(Rect2(-13,-13,26,26),Color(base,0.18))
			if not marks.draw(self,kind,Vector2.ZERO,10,dark,base,bright,sample*8,0,false): failed=true
			draw_set_transform(Vector2.ZERO)
			draw_string(ThemeDB.fallback_font,anchor+Vector2(-42,74),kind.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("ead8b0"))

func _initialize() -> void:
	root.hide()
	_run.call_deferred()

func _run() -> void:
	var output := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	if DisplayServer.get_name()=="headless" or not output.begins_with("res://.godot/retro-materials-") or ".." in output or DirAccess.dir_exists_absolute(output):
		push_error("Fresh contained native capture output required");quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := SubViewport.new()
	viewport.size=Vector2i(990,390)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var board := Board.new()
	if not board.language.load_from_file() or not board.presenter.configure(board.language): quit(1);return
	viewport.add_child(board)
	for frame: int in 3:
		board.sample=frame
		board.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		if viewport.get_texture().get_image().save_png(output+"/materials-%d.png"%frame)!=OK or board.failed:
			push_error("Material contact sheet failed");quit(1);return
	print("PASS retro material sheet:3 frames,10 live marks, no gameplay claims")
	quit(0)
