extends Control

const Model = preload("res://viewer_model.gd")
const SpriteCanvas = preload("res://sprite_canvas.gd")
var model := Model.new()
var canvas: Control
var action_picker: OptionButton
var direction_picker: OptionButton
var zoom_picker: OptionButton
var pause_button: Button
var previous_button: Button
var next_button: Button
var pose_label: Label
var status_label: Label
var frame_label: Label
var export_button: Button
var frame := 0
var elapsed := 0.0
var cadence := 6.0
var paused := false
var exporting := false


func _ready() -> void:
	Engine.max_fps = 120
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_ui()
	_reload()
	if "--check" in OS.get_cmdline_user_args():
		print("Reference sheets: %d/3 loaded. %s" % [model.textures.size(), "; ".join(model.status_lines)])
		get_tree().quit(0 if model.textures.size() == 3 else 2)
	elif "--export-contact-sheet" in OS.get_cmdline_user_args():
		call_deferred("_export_contact_sheet", true)


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)
	var title := Label.new()
	title.text = "FLUX / NEUTRAL BODY REFERENCE"
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color("e5c480"))
	column.add_child(title)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 10)
	column.add_child(toolbar)
	_add_label(toolbar, "Action")
	action_picker = _picker(toolbar, Model.ACTIONS, 145)
	action_picker.item_selected.connect(func(_index: int): _reset_pose())
	_add_label(toolbar, "Direction")
	direction_picker = _picker(toolbar, Model.DIRECTION_LABELS, 135)
	direction_picker.item_selected.connect(func(_index: int): _refresh())
	_add_label(toolbar, "Scale")
	zoom_picker = _picker(toolbar, ["1x / native", "2x", "3x"], 115)
	zoom_picker.select(1)
	zoom_picker.item_selected.connect(func(_index: int): _refresh())
	var view_picker := _picker(toolbar, ["Compare sizes", "8-direction grid"], 180)
	view_picker.item_selected.connect(func(index: int): canvas.show_directions = index == 1; _refresh())
	var filler := Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(filler)
	_button(toolbar, "Reload sheets", _reload)
	var playback := HBoxContainer.new()
	playback.add_theme_constant_override("separation", 9)
	column.add_child(playback)
	previous_button = _button(playback, "< Frame", func(): _step(-1))
	pause_button = _button(playback, "Pause", _toggle_pause)
	next_button = _button(playback, "Frame >", func(): _step(1))
	frame_label = Label.new()
	frame_label.custom_minimum_size.x = 115
	playback.add_child(frame_label)
	_add_label(playback, "Preview poses/sec")
	var rate := SpinBox.new()
	rate.min_value = 1
	rate.max_value = 24
	rate.step = 1
	rate.value = cadence
	rate.value_changed.connect(func(value: float): cadence = value; elapsed = 0.0)
	playback.add_child(rate)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	playback.add_child(spacer)
	export_button = _button(playback, "Export all source rows", _export_contact_sheet)
	pose_label = Label.new()
	pose_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pose_label.add_theme_color_override("font_color", Color("e5c480"))
	column.add_child(pose_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	canvas = SpriteCanvas.new()
	canvas.model = model
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(canvas)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("b1c2bc"))
	status_label.add_theme_font_size_override("font_size", 14)
	column.add_child(status_label)
	var footer := Label.new()
	footer.text = "REFERENCE ONLY / no gameplay, saves or network / 120 FPS cap / Space: pause / arrows: frame / 1-3: scale / F5: reload"
	footer.add_theme_font_size_override("font_size", 13)
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(footer)


func _add_label(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	parent.add_child(label)


func _picker(parent: Control, options: Array, width: int) -> OptionButton:
	var picker := OptionButton.new()
	picker.custom_minimum_size.x = width
	for option: String in options:
		picker.add_item(option.replace("_", " ").capitalize())
	parent.add_child(picker)
	return picker


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _reload() -> void:
	model.reload_sheets()
	status_label.text = " | ".join(model.status_lines)
	export_button.disabled = model.textures.size() != 3
	_refresh()


func _reset_pose() -> void:
	frame = 0
	elapsed = 0.0
	_refresh()


func _refresh() -> void:
	var action := String(Model.ACTIONS[action_picker.selected])
	var count := Model.sequence(action).size()
	frame = posmod(frame, count)
	canvas.action = action
	canvas.direction = direction_picker.selected
	canvas.zoom = zoom_picker.selected + 1
	canvas.frame = frame
	canvas.refresh()
	pose_label.text = Model.pose_label(action, frame)
	frame_label.text = "Pose %d / %d" % [frame + 1, count]
	previous_button.disabled = count < 2
	next_button.disabled = count < 2
	pause_button.text = "Play" if paused else "Pause"


func _toggle_pause() -> void:
	paused = not paused
	elapsed = 0.0
	_refresh()


func _step(amount: int) -> void:
	paused = true
	frame += amount
	elapsed = 0.0
	_refresh()


func _process(delta: float) -> void:
	if paused or Model.sequence(Model.ACTIONS[action_picker.selected]).size() < 2:
		return
	elapsed += delta * cadence
	if elapsed >= 1.0:
		frame += floori(elapsed)
		elapsed = fmod(elapsed, 1.0)
		_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			_toggle_pause()
		KEY_LEFT:
			_step(-1)
		KEY_RIGHT:
			_step(1)
		KEY_1, KEY_2, KEY_3:
			zoom_picker.select(event.keycode - KEY_1)
			_refresh()
		KEY_F5:
			_reload()
		_:
			return
	get_viewport().set_input_as_handled()


func _export_contact_sheet(quit_after: bool = false) -> void:
	if exporting:
		return
	if model.textures.size() != 3 or DisplayServer.get_name() == "headless":
		status_label.text = "Export needs all three valid PNGs and a graphics-capable Godot run. Nothing was written."
		if quit_after:
			print(status_label.text)
			get_tree().quit(2)
		return
	exporting = true
	export_button.disabled = true
	var viewport := SubViewport.new()
	viewport.size = Vector2i(2520, 1190)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)
	var sheet := SpriteCanvas.new()
	sheet.model = model
	sheet.contact_sheet = true
	sheet.size = Vector2(viewport.size)
	viewport.add_child(sheet)
	sheet.refresh()
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var directory := ProjectSettings.globalize_path("res://exports")
	var folder_error := DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join("body-contact-sheet-%d.png" % Time.get_ticks_usec())
	var save_error := image.save_png(path) if folder_error == OK else folder_error
	status_label.text = "Exported: " + path if save_error == OK else "Export failed (%d); source PNGs were not changed." % save_error
	print(status_label.text)
	viewport.queue_free()
	exporting = false
	export_button.disabled = false
	if quit_after:
		get_tree().quit(0 if save_error == OK else 2)
