extends SceneTree


# Actual controls rendering, with no boot, sockets, input, persistence or audio.
func _initialize() -> void:
	root.hide()
	_run.call_deferred()


func _run() -> void:
	var output := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if not output.begins_with("res://.godot/sound-controls-") or ".." in output or DirAccess.dir_exists_absolute(output):
		push_error("Provide a new --output=res://.godot/sound-controls-NAME")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sheet := ControlsSheet.new()
	sheet.configure()
	viewport.add_child(sheet)
	for size: Vector2i in [Vector2i(1280,720), Vector2i(1920,1080)]:
		viewport.size = size
		for volume: int in [0, 30, 100]:
			sheet.player_preferences.sound_volume_percent = volume
			sheet.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var rendered := viewport.get_texture().get_image()
			var path := output.path_join("controls-%dx%d-%d.png" % [size.x, size.y, volume])
			if rendered == null or rendered.get_size() != size or rendered.save_png(path) != OK:
				push_error("Controls render readback failed")
				quit(1)
				return
			print("RENDERED ", path)
	print("PASS: six actual controls renders; no playback or preferences writes")
	quit(0)


class ControlsSheet:
	extends "res://src/app/bootstrap.gd"

	func configure() -> void:
		player_preferences = PlayerPreferences.new()
		controls_editor = ControlBindingEditor.new()
		controls_editor.open_editor()
		visual_accessibility_filter = VisualAccessibilityFilter.new()

	func _ready() -> void:
		pass

	func _process(_delta: float) -> void:
		pass

	func _input(_event: InputEvent) -> void:
		pass

	func _notification(_what: int) -> void:
		pass

	func _exit_tree() -> void:
		visual_accessibility_filter.free()

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * _ui_scale())
		_draw_controls_editor()
