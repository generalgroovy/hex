extends SceneTree
## Ignored native layout probe of unapplied controllers. No game boot or input proof.
const ROOT := "res://.godot/iteration-20261013/remap-guide-hints/"
const Expansion = preload("res://.godot/iteration-20261013/remap-guide-hints/proposed/src/app/element_expansion_controller.gd")
const Navigation = preload("res://.godot/iteration-20261013/remap-guide-hints/proposed/src/app/local_navigation_controller.gd")
const BeforeExpansion = preload("res://.godot/iteration-20261013/remap-guide-hints/before/src/app/element_expansion_controller.gd")
const BeforeNavigation = preload("res://.godot/iteration-20261013/remap-guide-hints/before/src/app/local_navigation_controller.gd")
const Bootstrap = preload("res://src/app/bootstrap.gd")
const Reading = preload("res://src/presentation/ui_reading_policy.gd")
const PATCH_SHA := "93628c4843e11611f0420222d568c07ced1e635b9d9f483abdfac66869e9cc16"
const WATCHED := [ROOT+"capture-remap-hint-fit.gd", ROOT+"manifest.json", ROOT+"remap-guide-hints.patch",
	"res://src/app/bootstrap.gd", "res://src/app/control_binding_editor.gd", "res://src/app/optional_introduction.gd",
	"res://src/app/signature_progression.gd", "res://src/app/player_preferences.gd", "res://src/presentation/ui_reading_policy.gd",
	"res://src/presentation/spell_binding_labels.gd", "res://src/presentation/spell_loom_presenter.gd",
	"res://src/presentation/spell_testing_panel.gd", "res://src/net/session_transport.gd",
	"res://src/sim/core/sim_world.gd", "res://src/content/runtime_build_identity.gd"]

class Board extends Node2D:
	var world := SimWorld.new(120, 935, CollisionWorld.new(2000000, 2000000))
	var player_preferences := PlayerPreferences.new()
	var session_transport := SessionTransport.new()
	var service_directory := {"is_open": false}
	var solo_trial_menu_open := false
	var campus_renderer = null
	var element_expansion
	var local_navigation
	var active := false
	var surface := "menu"
	var serial := 0
	var pure := true
	func initialize(old: bool = false) -> void:
		element_expansion = BeforeExpansion.new() if old else Expansion.new()
		local_navigation = BeforeNavigation.new() if old else Navigation.new()
		element_expansion.game = self
		local_navigation.configure(self)
	func _is_hex_practice() -> bool: return false
	func _directory_child_open() -> bool: return false
	func _gameplay_input_blocked() -> bool: return false
	func _readable_ui() -> bool:
		return Reading.needs_reflow(get_viewport_rect().size, player_preferences.ui_text_percent)
	func _ui_scale() -> float:
		return Bootstrap.ui_scale_for(get_viewport_rect().size) * float(player_preferences.ui_text_percent) / 100.0
	func _draw() -> void:
		serial += 1
		draw_rect(get_viewport_rect(), Color("283e37"))
		if not active: return
		var before := world.state_hash()
		var scale_value := _ui_scale()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * scale_value)
		if surface == "guide": element_expansion.draw(self, ThemeDB.fallback_font, get_viewport_rect().size / scale_value)
		else: local_navigation.draw(self, ThemeDB.fallback_font, get_viewport_rect().size / scale_value)
		draw_set_transform(Vector2.ZERO)
		pure = before == world.state_hash()
	func release() -> void:
		if element_expansion != null: element_expansion.game = null
		if local_navigation != null: local_navigation.game = null

var output := ""
var output_authorized := false
var finished := false
var checks := 0
var errors: Array[String] = []
var cases: Array[Dictionary] = []
var source_hashes: Dictionary = {}
var board: Board
var old_board: Board
var view: SubViewport
var old_mouse_mode: int

func _initialize() -> void:
	old_mouse_mode = Input.mouse_mode
	_run.call_deferred()

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if not _check(DisplayServer.get_name() != "headless" and OS.get_cmdline_user_args().has("--no-lan-discovery")
		and output.get_base_dir() == ROOT + "runs" and output.get_file().begins_with("fit-")
		and output.get_file().is_valid_filename() and not ".." in output
		and not DirAccess.dir_exists_absolute(output) and not FileAccess.file_exists(output), "Fresh owned native output required"):
		_finish(); return
	if not _check(DirAccess.make_dir_recursive_absolute(output) == OK, "Fresh output created"):
		_finish(); return
	output_authorized = true
	for path: String in WATCHED:
		source_hashes[path] = FileAccess.get_sha256(path)
		if not _check(String(source_hashes[path]).length() == 64, "Watched source exists: " + path): _finish(); return
	if not _source_guard(): _finish(); return
	board = Board.new(); board.initialize()
	old_board = Board.new(); old_board.initialize(true)
	view = SubViewport.new(); view.size = Vector2i(1280,720)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view); view.add_child(board)
	create_timer(120).timeout.connect(func() -> void:
		if not finished: errors.append("Bounded capture watchdog expired"); _finish())
	for size: Vector2i in [Vector2i(960,540), Vector2i(1280,720)]:
		for percent: int in [100,200]:
			for mode: String in ["default", "remapped", "controller"]:
				if not await _case(size, percent, mode): _finish(); return
	_finish()

func _source_guard() -> bool:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "manifest.json"))
	if not _check(manifest is Dictionary and manifest.get("patch_sha256", "") == PATCH_SHA
		and FileAccess.get_sha256(ROOT + "remap-guide-hints.patch") == PATCH_SHA, "Exact approved unapplied patch"): return false
	for value: Variant in manifest.files:
		var record: Dictionary = value
		for location: String in ["before/", "proposed/", "canonical"]:
			var path: String = "res://" + String(record.path) if location == "canonical" else ROOT + location + String(record.path)
			var expected: String = String(record.proposed_sha256) if location == "proposed/" else String(record.before_sha256)
			if not _check(FileAccess.get_sha256(path) == expected, "Pinned proposal/predecessor remains unapplied: " + path): return false
			source_hashes[path] = expected
	return true

func _prepare_preferences(target: Board, percent: int, mode: String) -> bool:
	target.player_preferences = PlayerPreferences.new()
	target.player_preferences.ui_text_percent = percent
	target.player_preferences.prompt_device = ControlBindingEditor.DEVICE_CONTROLLER if mode == "controller" else ControlBindingEditor.DEVICE_KEYBOARD
	if mode == "remapped":
		var editor := ControlBindingEditor.new()
		editor.open_editor()
		for slot: int in 2:
			editor.selected_action_index = ControlBindingEditor.ACTIONS.find(&"spell_1" if slot == 0 else &"spell_2")
			editor.selected_device = ControlBindingEditor.DEVICE_KEYBOARD
			editor.begin_capture()
			var event := InputEventKey.new()
			event.pressed = true; event.physical_keycode = KEY_F5 if slot == 0 else KEY_F6
			if not _check(editor.capture_event(event, target.player_preferences), "Supported editor accepts prepared F5/F6 remap"): return false
		editor.close_editor()
	target.element_expansion.refresh_guide_bindings()
	# Prepared visual lesson state only; no invented observation or paid completion.
	target.element_expansion.guide.active = true
	target.element_expansion.guide.step = 4
	target.element_expansion.guide.detail_page = false
	target.local_navigation.menu_open = true
	return true

func _case(size: Vector2i, percent: int, mode: String) -> bool:
	board.active = false
	if not _prepare_preferences(board, percent, mode) or not _prepare_preferences(old_board, percent, mode): return false
	view.size = size
	await process_frame; await process_frame; RenderingServer.force_draw(false)
	if finished: return false
	var scale_value := board._ui_scale()
	var logical := Vector2(size) / scale_value
	var rows: Array[Dictionary] = board.local_navigation.entries()
	var old_rows: Array[Dictionary] = old_board.local_navigation.entries()
	var guide: Dictionary = board.element_expansion.guide.view()
	if not _check(rows.size() == old_rows.size() and rows.size() == 12, "Prepared non-practice menu includes Challenge and Developer routes"): return false
	var developer_index := -1
	var hints := {}
	for index: int in rows.size():
		var row: Dictionary = rows[index]
		if not _check(row.id == old_rows[index].id and row.label == old_rows[index].label, "Existing menu action and label preserved"): return false
		hints[String(row.id)] = String(row.hint)
		if row.id == "expansion-developer": developer_index = index
		var changed: bool = String(row.id) in ["expansion-introduction", "expansion-range", "expansion-challenges", "expansion-developer"]
		if not _check(String(row.hint) == ("" if mode == "remapped" and changed else String(old_rows[index].hint)), "Only unavailable keyboard convenience hints are omitted"): return false
	if mode == "default":
		if not _check(rows == old_rows and guide == old_board.element_expansion.guide.view(), "Default menu and guide text is byte-identical to predecessor"): return false
	else:
		if not _check("Menu > Spell Range" in String(guide.instruction) and String(guide.skip) == "Menu > Skip introduction", "Remap/controller uses actual Menu fallback"): return false
	var captures: Array[Dictionary] = []
	for surface: String in ["menu_first", "menu_developer", "guide_range"]:
		var geometry: Dictionary = {}
		if surface == "guide_range":
			board.surface = "guide"
			board.local_navigation.menu_open = false
			geometry = _guide_geometry(logical)
		else:
			board.surface = "menu"
			board.local_navigation.menu_open = true
			board.local_navigation.selected = 0 if surface == "menu_first" else developer_index
			geometry = _menu_geometry(logical, rows)
		if not errors.is_empty(): return false
		var prior := board.serial
		var authority := board.world.state_hash()
		board.active = true; board.queue_redraw()
		await process_frame; await process_frame; RenderingServer.force_draw(false)
		if finished: return false
		if not _check(board.serial == prior + 1 and board.pure and board.world.state_hash() == authority, "One unchanged-authority actual native draw"): return false
		var pixels := view.get_texture().get_image()
		if not _check(pixels != null and pixels.get_size() == size, "Exact physical native pixels"): return false
		pixels.convert(Image.FORMAT_RGBA8)
		var box: Rect2 = geometry.box
		if not _check(pixels.get_pixelv(Vector2i(box.get_center() * scale_value)) != pixels.get_pixel(1,1), "Native panel is nonblank"): return false
		var name := "%d-%d-%s-%s.png" % [size.x, percent, mode, surface]
		var path := output.path_join(name)
		if not _check(pixels.save_png(path) == OK and FileAccess.get_sha256(path).length() == 64, "Native PNG written"): return false
		captures.append({"surface":surface,"path":path,"sha256":FileAccess.get_sha256(path),"geometry":_json_geometry(geometry),"authority_hash":authority})
		board.active = false
	cases.append({"physical_size":[size.x,size.y],"text_percent":percent,"scale":scale_value,"logical_size":[logical.x,logical.y],"mode":mode,
		"hints":hints,"menu_hint_ink_suppressed_for_controller":mode == "controller","guide":guide,"captures":captures})
	return true

func _menu_geometry(logical: Vector2, rows: Array[Dictionary]) -> Dictionary:
	var font := ThemeDB.fallback_font
	var panel: Rect2 = Navigation.menu_rect(logical, rows.size())
	_check(Rect2(Vector2.ZERO,logical).encloses(panel), "Actual paged menu fits logical viewport")
	var visible: Array = board.local_navigation.visible_menu_indices(logical, rows.size())
	var row_boxes: Array[Rect2] = []
	var text_bounds: Array[Dictionary] = []
	for index: int in visible:
		var box: Rect2 = Navigation.row_rect(logical, rows.size(), index)
		row_boxes.append(box)
		_check(panel.encloses(box), "Actual visible menu pointer row fits panel")
		var label_width := font.get_string_size(String(rows[index].label),HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
		var hint_width := font.get_string_size(String(rows[index].hint),HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
		_check(label_width <= 220.0, "Actual menu label fits reserved draw width")
		if board.player_preferences.prompt_device != ControlBindingEditor.DEVICE_CONTROLLER:
			_check(hint_width <= 94.0, "Actual displayed convenience hint fits width")
		text_bounds.append({"id":String(rows[index].id),"label":String(rows[index].label),"label_width":label_width,"label_limit":220,
			"hint":String(rows[index].hint),"hint_width":hint_width,"hint_limit":94,"hint_drawn":board.player_preferences.prompt_device != ControlBindingEditor.DEVICE_CONTROLLER})
	if rows.size() > Navigation.menu_page_size(logical):
		for direction: int in [-1,1]: _check(panel.encloses(Navigation.page_rect(logical,rows.size(),direction)), "Actual page controls remain inside panel")
	return {"box":panel,"rows":row_boxes,"visible_indices":visible,"selected":board.local_navigation.selected,"text_bounds":text_bounds}

func _guide_geometry(logical: Vector2) -> Dictionary:
	var font := ThemeDB.fallback_font
	var geometry: Dictionary = board.element_expansion.guide.geometry(logical,font)
	var box: Rect2 = geometry.box
	_check(Rect2(Vector2.ZERO,logical).encloses(box), "Actual wrapped guide fits logical viewport")
	for key: String in ["skip","details"]: _check(box.encloses(geometry[key]), "Existing guide action bounds remain inside panel")
	var lines: Array[String] = board.element_expansion.guide.body_lines(font,logical)
	var line_widths: Array[float] = []
	for line: String in lines:
		line_widths.append(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x)
		_check(line_widths.back() <= box.size.x-24.0, "Actual guide wrapped line fits draw width")
	var last_ink := box.position.y+46+(lines.size()-1)*18+font.get_descent(12)
	_check(last_ink <= Rect2(geometry.skip).position.y-8, "Actual guide body leaves action spacing")
	geometry.lines = lines
	geometry.line_widths = line_widths
	geometry.line_limit = box.size.x-24.0
	return geometry

func _json_geometry(value: Dictionary) -> Dictionary:
	var result := {}
	for key: Variant in value:
		var item: Variant = value[key]
		if item is Rect2: result[key] = [item.position.x,item.position.y,item.size.x,item.size.y]
		elif key == "rows":
			var rows: Array = []
			for box: Rect2 in item: rows.append([box.position.x,box.position.y,box.size.x,box.size.y])
			result[key] = rows
		else: result[key] = item
	return result

func _check(value: bool, message: String) -> bool:
	checks += 1
	if not value: errors.append(message)
	return value

func _finish() -> void:
	if finished: return
	finished = true
	for path: String in source_hashes: _check(FileAccess.get_sha256(path) == source_hashes[path], "No watched source drift: " + path)
	_check(Input.mouse_mode == old_mouse_mode, "No global mouse state changed")
	Input.mouse_mode = old_mouse_mode
	if board != null: board.release()
	if old_board != null: old_board.release(); old_board.free(); old_board = null
	if view != null: view.free(); view = null; board = null
	var record := {"schema":"hex.remap-hint-fit.native.v1","passed":errors.is_empty() and cases.size()==12,"checks":checks,"errors":errors,
		"engine":Engine.get_version_info(),"source_hashes":source_hashes,"cases":cases,"png_count":cases.size()*3,
		"scope":"Offscreen native SubViewport; exact proposed controllers with production ui_scale and draw/geometry paths. Prepared visual lesson/menu state and supported editor remapping; no full Bootstrap boot, key dispatch, paid progress, save, physical device, audio or performance claim. No InputMap or input polling mutation. Fixed wide Developer/Range status overlays and challenge footer are outside this menu/guide fit scope."}
	if output_authorized:
		var path := output.path_join("receipt.json")
		var encoded := JSON.stringify(record,"\t")+"\n"
		var file := FileAccess.open(path,FileAccess.WRITE)
		if file == null: errors.append("Receipt open failed")
		else:
			file.store_string(encoded); file.close()
			if FileAccess.get_file_as_string(path) != encoded or not JSON.parse_string(encoded) is Dictionary: errors.append("Receipt readback failed")
	var passed: bool = bool(record.passed) and errors.is_empty()
	print("PASS: remap native fit " + str(checks) + " checks, 12 contexts, 36 PNGs" if passed else "FAIL: remap native fit " + JSON.stringify(errors))
	quit(0 if passed else 1)
