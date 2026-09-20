extends SceneTree

const Guide := preload("res://art_batches/character_style_v1/template_v2/pose_guide_model.gd")
const OUTPUT := "res://art_batches/character_style_v1/template_v2/guides-v3/"
var contact_pairs := false


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument != "--contacts":
			push_error("Only optional --contacts is supported")
			quit(1)
			return
		contact_pairs = true
	root.hide()
	_run.call_deferred()


func _run() -> void:
	var output := "res://art_batches/character_style_v1/template_v2/contact-guides-v2/" if contact_pairs else OUTPUT
	if DirAccess.dir_exists_absolute(output):
		push_error("Refusing to overwrite existing construction guides")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 700) if contact_pairs else Vector2i(960, 1260)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := Board.new()
	board.contact_pairs = contact_pairs
	viewport.add_child(board)
	for body: String in Guide.HEIGHTS:
		for direction: String in Guide.DIRECTIONS:
			board.body = body
			board.direction = direction
			board.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var rendered := viewport.get_texture().get_image()
			if rendered.save_png(output + body + "-" + direction + ".png") != OK:
				push_error("Failed to save construction guide")
				quit(1)
				return
	print("PASS: 24 size/heading construction boards. NOT character artwork or runtime atlases.")
	quit(0)


class Board:
	extends Node2D
	var body := "small"
	var direction := "south"
	var contact_pairs := false
	var font: Font = ThemeDB.fallback_font

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 960, 1260), Color("17262b"))
		draw_string(font, Vector2(24, 32), "FLUX CONSTRUCTION / " + body.to_upper() + " / " + direction.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color("efe3be"))
		draw_string(font, Vector2(24, 57), "COPPER = anatomical LEFT    BLUE = anatomical RIGHT    NOT FINISHED ART", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("efe3be"))
		for index: int in range(2 if contact_pairs else 10):
			var state: String = ["walk", "walk_b"][index] if contact_pairs else Guide.BOARD_STATES[index]
			var origin := Vector2(20 + index * 480, 115) if contact_pairs else Vector2(40 + (index % 2) * 460, 90 + (index / 2) * 230)
			var pose_data := Guide.pose(body, state, direction)
			var points: Dictionary = pose_data.points
			var scale_factor := 4.4 if contact_pairs else 2.2
			draw_rect(Rect2(origin, Vector2(96, 96) * scale_factor), Color("223b41"))
			draw_line(origin + Vector2(0, 84) * scale_factor, origin + Vector2(96, 84) * scale_factor, Color("69857c"), 1)
			for chain: Dictionary in pose_data.chains:
				if float(chain.depth) <= float(pose_data.torso_depth):
					_draw_chain(chain, points, origin, scale_factor)
			var torso := Geometry2D.convex_hull(pose_data.torso_corners)
			if torso.size() > 1 and torso[0] == torso[torso.size() - 1]:
				torso.remove_at(torso.size() - 1)
			for vertex: int in range(torso.size()):
				torso[vertex] = origin + torso[vertex] * scale_factor
			var rear_view := direction in ["north_east", "north", "north_west"]
			draw_colored_polygon(torso, Color("3e605b") if rear_view else Color("557b75"))
			draw_line(origin + points.neck * scale_factor, origin + points.pelvis * scale_factor, Color("dee0bb"), 3)
			for chain: Dictionary in pose_data.chains:
				if float(chain.depth) > float(pose_data.torso_depth):
					_draw_chain(chain, points, origin, scale_factor)
			var head: Vector2 = origin + points.head * scale_factor
			draw_circle(head, float(pose_data.pixels_per_unit) * Guide.HEAD_RADIUS * scale_factor, Color("99977d") if rear_view else Color("bdb997"))
			if not rear_view:
				draw_line(head, origin + points.nose * scale_factor, Color("fcedc5"), 5)
			var label := state.replace("_b", " B")
			if state in ["walk", "sprint"]:
				label += " A"
			var label_origin := Vector2(115, 470) if contact_pairs else Vector2(240, 72)
			draw_string(font, origin + label_origin, label.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("efe3be"))
			draw_string(font, origin + label_origin + Vector2(0, 25), "plant: " + String(pose_data.contact), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("b8cec6"))


	func _draw_chain(chain: Dictionary, points: Dictionary, origin: Vector2, scale_factor: float) -> void:
		var color := Color("e29857") if chain.side == "l" else Color("5faacb")
		var keys: Array = chain["keys"]
		for index: int in range(keys.size() - 1):
			draw_line(origin + points[keys[index]] * scale_factor, origin + points[keys[index + 1]] * scale_factor, color, 5)
			draw_circle(origin + points[keys[index + 1]] * scale_factor, 3, color)
