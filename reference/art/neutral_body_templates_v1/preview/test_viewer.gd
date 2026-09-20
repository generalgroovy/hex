extends SceneTree

const Model = preload("res://viewer_model.gd")
const Canvas = preload("res://sprite_canvas.gd")
const ViewerScene = preload("res://viewer.tscn")
var assertions := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		print("FAIL: " + message)


func _run() -> void:
	_check(Model.SIZES.size() == 3, "exactly three neutral templates")
	_check(Model.ROWS.size() == 10 and Model.DIRECTIONS.size() == 8, "exact sheet geometry")
	_check(Model.ACTIONS.size() == 17, "all requested reference action labels are present")
	_check(Model.runtime_directory().ends_with("neutral_body_templates_v1/runtime"), "source root is adjacent to standalone project, not game resource root")
	for row: String in Model.ROWS:
		for column: int in range(8):
			var region := Model.source_region(row, column)
			_check(region.size == Vector2(96,96), "source cell is never independently trimmed")
			_check(Rect2(Vector2.ZERO,Vector2(Model.ATLAS_SIZE)).encloses(region), "source region stays inside atlas")
	_check(Model.source_region("missing",0) == Rect2(), "unknown row has no invented art")
	_check(Model.source_region("jump",8) == Rect2(), "ninth direction fails closed")
	for action: String in Model.ACTIONS:
		var rows := Model.sequence(action)
		_check(not rows.is_empty(), "requested action maps to actual rows")
		_check(rows.size() == (2 if action in ["walk","sprint"] else 1), "only supplied paired contacts are animated")
		for row: String in rows:
			_check(row in Model.ROWS, "reference alias points to an existing row")
		_check(Model.pose_label(action,0).contains("2 supplied") if rows.size() == 2 else Model.pose_label(action,0).contains("1 static"), "visible label reports actual pose count")
	_check(Model.pose_label("float",0).contains("not a dedicated animation"), "Float alias cannot claim new frames")
	_check(Model.pose_label("walk",-1).contains("walk_b"), "backward frame step wraps deterministically")
	_check(Model.sequence("missing").is_empty(), "unknown action is not silently aliased")
	_check(Model.sequence("wallrun") == ["slide"], "wallrun matches the shared low-pose reference component")
	_check(Model.sequence("defend") == ["grounded"] and Model.sequence("interact") == ["grounded"], "gallery-only labels match the neutral component without invented casting poses")
	var canvas := Canvas.new()
	for scale_value: int in [1,2,3]:
		canvas.zoom = scale_value
		canvas.show_directions = false
		canvas.refresh()
		_check(canvas.custom_minimum_size.x >= 3*(96*scale_value+60), "comparison contains all three same-scale cells")
		canvas.show_directions = true
		canvas.refresh()
		_check(canvas.custom_minimum_size.x >= 118+8*96*scale_value, "eight-direction grid is scrollable, not clipped")
	canvas.contact_sheet = true
	canvas.refresh()
	_check(canvas.custom_minimum_size.x > 2486 and canvas.custom_minimum_size.y > 1169, "full source contact sheet includes final row and large west cells")
	canvas.free()
	var viewer := ViewerScene.instantiate()
	root.add_child(viewer)
	_check(Engine.max_fps == 120, "viewer has a 120 FPS cap")
	viewer.action_picker.select(1)
	viewer._reset_pose()
	viewer._step(1)
	_check(viewer.frame == 1 and viewer.paused, "frame step pauses on second walking contact")
	viewer._step(1)
	_check(viewer.frame == 0, "frame step wraps without fabricating interpolation")
	viewer.action_picker.select(4)
	viewer._reset_pose()
	_check(viewer.previous_button.disabled and viewer.next_button.disabled, "static reused pose has no misleading next-frame control")
	_check(viewer.pose_label.text.contains("1 static"), "actual UI exposes static pose limitation")
	viewer.zoom_picker.select(2)
	viewer._refresh()
	_check(viewer.canvas.zoom == 3, "scale control updates actual rendering")
	if "--require-sheets" in OS.get_cmdline_user_args():
		_check(viewer.model.textures.size() == 3, "all three real source sheets pass dimensions and RGBA validation")
	print("Reference viewer: %d assertions, %d failures; actual sheets loaded: %d/3" % [assertions, failures, viewer.model.textures.size()])
	viewer.free()
	quit(0 if failures == 0 else 1)
