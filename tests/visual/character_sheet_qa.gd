extends SceneTree

const Model = preload("res://tests/visual/character_sheet_qa_model.gd")
const VIEW_SIZE := Vector2i(1280, 720)
var board: ReviewBoard
var output := ""
var mode := "view"


func _initialize() -> void:
	root.hide()
	Engine.max_fps = 120
	_run.call_deferred()


func _run() -> void:
	var sheet_path := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--sheet="): sheet_path = argument.trim_prefix("--sheet=")
		elif argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		elif argument.begins_with("--mode="): mode = argument.trim_prefix("--mode=")
	if mode not in ["view", "check", "export"] or sheet_path.is_empty() or not FileAccess.file_exists(sheet_path):
		_fail("Use --sheet=PATH.png --mode=view|check|export; export also needs --output=res://.godot/character-qa/NEW.")
		return
	var source := FileAccess.open(sheet_path, FileAccess.READ)
	if source.get_length() > Model.MAX_FILE_BYTES:
		_fail("Candidate exceeds the bounded 32 MiB file limit.")
		return
	var bytes := source.get_buffer(source.get_length())
	if bytes.size() < 24 or bytes.slice(0, 8) != PackedByteArray([137,80,78,71,13,10,26,10]):
		_fail("Candidate is not a PNG.")
		return
	var width := int(bytes[16]) * 16777216 + int(bytes[17]) * 65536 + int(bytes[18]) * 256 + int(bytes[19])
	var height := int(bytes[20]) * 16777216 + int(bytes[21]) * 65536 + int(bytes[22]) * 256 + int(bytes[23])
	if width != Model.SIZE.x or height != Model.SIZE.y:
		_fail("PNG header must declare 768x960 before decoding.")
		return
	var candidate := Image.new()
	if candidate.load_png_from_buffer(bytes) != OK:
		_fail("Candidate PNG could not be decoded.")
		return
	var report := Model.inspect(candidate)
	report["source"] = sheet_path
	report["source_sha256"] = FileAccess.get_sha256(sheet_path)
	report["cadence_note"] = "Viewer-only 6 poses/sec at a 120 FPS cap; no gameplay animation timing inferred."
	var console_report: Dictionary = report.duplicate()
	console_report.erase("frames")
	print("CHARACTER_SHEET_QA=" + JSON.stringify(console_report))
	if mode == "check":
		quit(0 if report.valid else 2)
		return
	if not report.valid:
		_fail("Technical candidate checks failed: " + "; ".join(report.errors))
		return
	board = ReviewBoard.new()
	board.sheet = ImageTexture.create_from_image(candidate)
	board.report = report
	board.title = sheet_path.get_file()
	if mode == "view":
		root.size = VIEW_SIZE
		root.title = "FLUX / Character Sheet QA / Not visual acceptance"
		root.add_child(board)
		root.show()
		return
	if not output.begins_with("res://.godot/character-qa/") or ".." in output or DirAccess.dir_exists_absolute(output):
		board.free()
		_fail("Export requires a new directory under res://.godot/character-qa/; existing outputs are never overwritten.")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		board.free()
		_fail("Could not create isolated QA output.")
		return
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(board)
	board.playing = false
	var images: Array[String] = []
	for light: bool in [false, true]:
		board.light = light
		for scale_value: int in [1, 2]:
			board.scale_value = scale_value
			board.view = "Contact"
			for page: int in range(Model.page_count(scale_value)):
				board.page = page
				var name := "contact-%s-%dx-%02d.png" % ["light" if light else "dark", scale_value, page + 1]
				if not await _capture(viewport, name): return
				images.append(name)
		board.view = "Playback"
		board.scale_value = 2
		for action: String in ["walk", "sprint"]:
			board.action = action
			for frame: int in range(2):
				board.frame = frame
				var name := "%s-%s-%d.png" % [action, "light" if light else "dark", frame]
				if not await _capture(viewport, name): return
				images.append(name)
	report["captures"] = images
	var report_file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report, "  ") + "\n")
	print("PASS: %d actual Godot QA PNG pages / source unchanged / NOT visual acceptance / %s" % [images.size(), output])
	quit(0)


func _capture(viewport: SubViewport, name: String) -> bool:
	board.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image == null or image.get_size() != VIEW_SIZE or image.save_png(output.path_join(name)) != OK:
		_fail("Godot capture failed: " + name)
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(2)


class ReviewBoard:
	extends Node2D
	var sheet: Texture2D
	var report: Dictionary
	var title := "Candidate"
	var view := "Contact"
	var action := "walk"
	var scale_value := 1
	var page := 0
	var frame := 0
	var light := false
	var playing := true
	var age := 0.0
	var cadence := 6.0
	var font: Font = ThemeDB.fallback_font
	var action_picker: OptionButton

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var toolbar := HBoxContainer.new()
		toolbar.position = Vector2(20, 55)
		add_child(toolbar)
		for text: String in ["Contact", "Playback", "1x / 2x", "Light / dark", "Previous page", "Next page", "Play / pause", "Step"]:
			var button := Button.new()
			button.text = text
			button.pressed.connect(_button.bind(text))
			toolbar.add_child(button)
		var picker := OptionButton.new()
		action_picker = picker
		for entry: String in ["walk", "sprint", "Action cycle"]: picker.add_item(entry)
		picker.item_selected.connect(func(index: int): action = ["walk", "sprint", "Action cycle"][index]; frame = 0; age = 0; queue_redraw())
		toolbar.add_child(picker)

	func _button(text: String) -> void:
		match text:
			"Contact", "Playback": view = text
			"1x / 2x": scale_value = 3 - scale_value; page = 0
			"Light / dark": light = not light
			"Previous page": page = posmod(page - 1, Model.page_count(scale_value))
			"Next page": page = posmod(page + 1, Model.page_count(scale_value))
			"Play / pause": playing = not playing
			"Step": playing = false; frame += 1
		queue_redraw()

	func _process(delta: float) -> void:
		if view != "Playback" or not playing: return
		age += delta * cadence
		if age >= 1:
			frame += floori(age)
			age = fmod(age, 1.0)
			queue_redraw()

	func _unhandled_key_input(event: InputEvent) -> void:
		if not event is InputEventKey or not event.pressed or event.echo: return
		match event.keycode:
			KEY_SPACE: _button("Play / pause")
			KEY_LEFT: playing = false; frame -= 1; queue_redraw()
			KEY_RIGHT: _button("Step")
			KEY_PAGEUP: _button("Previous page")
			KEY_PAGEDOWN: _button("Next page")
			KEY_B: _button("Light / dark")
			KEY_1: scale_value = 1; page = 0; queue_redraw()
			KEY_2: scale_value = 2; page = 0; queue_redraw()
			KEY_ESCAPE: get_tree().quit(0)

	func _draw() -> void:
		if action_picker != null:
			action_picker.select(["walk", "sprint", "Action cycle"].find(action))
		draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("cbbf9e") if light else Color("192329"))
		label(Vector2(20, 32), "FLUX / CHARACTER SHEET QA / " + title, 22)
		var detail := "CONTACT / %dx / PAGE %d/%d / 80 source cells, not 80 unique animations" % [scale_value, page + 1, Model.page_count(scale_value)]
		if view == "Playback": detail = Model.Contract.pose_label(action, frame) if action != "Action cycle" else "Action cycle: ten supplied source rows; NOT ten multi-frame animations."
		label(Vector2(20, 112), detail, 17)
		if view == "Contact":
			for cell: Dictionary in Model.page_cells(scale_value, page):
				_draw_cell(cell.row, cell.direction, cell.slot_x, cell.slot_y, scale_value)
		else:
			var row: int = Model.Contract.ROWS.find(Model.action_row(action, frame))
			var columns := 8 if scale_value == 1 else 4
			for direction: int in range(8):
				@warning_ignore("integer_division")
				_draw_cell(row, direction, direction % columns, direction / columns, scale_value)
		var warning := Model.admission_summary(report)
		if not report.warnings.is_empty(): warning = "REVIEW: " + " | ".join(report.warnings)
		label(Vector2(20, 674), warning, 14)
		label(Vector2(20, 701), "Space pause / arrows step / PgUp-PgDn pages / 1-2 scale / B background / Esc close. Preview 6 poses/sec; no gameplay timing or visual approval.", 13)

	func _draw_cell(row: int, direction: int, slot_x: int, slot_y: int, zoom: int) -> void:
		var origin := Vector2(150 + slot_x * (96 * zoom + 16), 143 + slot_y * (96 * zoom + 9 if zoom == 1 else 220))
		var area := Rect2(origin, Vector2(96, 96) * zoom)
		draw_rect(area, Color("dbd2b7") if light else Color("26373d"))
		var feet := origin + Model.PIVOT * zoom
		draw_line(Vector2(origin.x, feet.y), Vector2(area.end.x, feet.y), Color("8d8067"), 1)
		draw_texture_rect_region(sheet, area, Model.Contract.source_region(Model.Contract.ROWS[row], direction))
		if slot_y == 0 or view == "Playback":
			label(origin + Vector2(2, -8), Model.Contract.DIRECTION_LABELS[direction], 14)
		if slot_x == 0:
			label(Vector2(20, origin.y + 50), Model.Contract.ROWS[row], 16)

	func label(position: Vector2, text: String, size: int) -> void:
		var limit := float(VIEW_SIZE.x) - position.x - 20.0
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > limit:
			while not text.is_empty() and font.get_string_size(text + "...", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > limit:
				text = text.left(text.length() - 1)
			text += "..."
		draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("222e30") if light else Color("e9dfc6"))
