extends SceneTree
## Isolated art lab. No production presenter, actor, simulation, or network state.

const DIRECTIONS := ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
const ROWS := ["grounded", "jump", "cast", "hit", "walk", "sprint", "slide", "roll", "walk_b", "sprint_b"]
const BODIES := ["small", "middle", "large"]
const PRESENTATIONS := ["neutral", "masculine", "feminine"]
const CELL := Vector2i(96, 96)
const PIVOT := Vector2(48, 84)
const INTERACTIVE_ANCHOR := Vector2(650, 540)
var manifest: Dictionary = {}
var frames: Dictionary = {}
var atlas: Texture2D
var folder := ""
var error := ""
var body := 1
var presentation := 0
var action := 4
var phase := 0.0
var aim := 0
var travel := 0
var moving := false
var animation_paused := false
var board: LabBoard
var capture_bank := ""

class LabBoard extends Node2D:
	var lab
	func _process(delta: float) -> void:
		lab.update_lab(delta)
		queue_redraw()
	func _unhandled_key_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo:
			lab.handle_key(event.keycode)
	func _draw() -> void:
		lab.draw_lab(self)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var manifest_path := ""
	var capture_path := ""
	var validate_only := false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--manifest="):
			manifest_path = arg.trim_prefix("--manifest=")
		elif arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
		elif arg == "--validate":
			validate_only = true
	if not load_manifest(manifest_path):
		_fail(error)
		return
	if validate_only:
		for size_index: int in 3:
			for presentation_index: int in 3:
				body = size_index
				presentation = presentation_index
				if not load_family():
					_fail(error)
					return
		print("PASS: 9 candidate families / 9936 logical frame records; source hashes, pixels, layout. Human approval NOT established.")
		quit(0)
		return
	if not load_family():
		_fail(error)
		return
	board = LabBoard.new()
	board.lab = self
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not capture_path.is_empty():
		await capture_boards(capture_path)
		return
	root.title = "H.E.X. Candidate Art Lab - NOT PRODUCTION"
	root.size = Vector2i(1280, 800)
	root.add_child(board)

static func safe_root(path: String) -> bool:
	return not ".." in path and not "\\" in path and (path.begins_with("res://.godot/race-sprite-candidates/") or path.begins_with("res://art_batches/race_sprite_factory_v1/output/"))

static func safe_leaf(path: String) -> bool:
	return not path.is_empty() and path == path.get_file() and not ".." in path and not ":" in path and not "\\" in path

static func number_pair_matches(value: Variant, expected: Vector2i) -> bool:
	# JSON decodes numbers as floats. Array equality is type-sensitive, so
	# validate numeric type, finiteness and exact integral value individually.
	if not value is Array or value.size() != 2:
		return false
	for index: int in 2:
		if typeof(value[index]) not in [TYPE_INT, TYPE_FLOAT]:
			return false
		var component := float(value[index])
		if not is_finite(component) or component != float(expected[index]):
			return false
	return true

func reject(message: String) -> bool:
	error = message
	return false

func json_file(path: String, max_bytes: int) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > max_bytes:
		return null
	return JSON.parse_string(file.get_as_text())

func load_manifest(path: String) -> bool:
	if not safe_root(path) or path.get_file() != "manifest.json":
		return reject("Expected contained candidate --manifest=res://.../manifest.json")
	var data: Variant = json_file(path, 1048576)
	if not data is Dictionary:
		return reject("Missing or invalid manifest")
	if data.get("schema_version") != 1 or data.get("factory") != "race_sprite_factory_v1" or data.get("motion_revision") != "slide_v1":
		return reject("Unknown factory schema or motion revision")
	if not number_pair_matches(data.get("cell"), CELL) or not number_pair_matches(data.get("pivot"), Vector2i(48, 84)):
		return reject("Candidate cell/pivot geometry differs")
	if data.get("directions") != DIRECTIONS or data.get("base_rows") != ROWS:
		return reject("Candidate directions/actions differ")
	if data.get("production_ready") != false or data.get("human_approved") != false:
		return reject("This lab only accepts explicitly unapproved candidates")
	if not data.get("variants") is Dictionary or data.variants.size() != 9:
		return reject("Expected nine candidate variants")
	for size_id: String in BODIES:
		for gender: String in PRESENTATIONS:
			if not data.variants.get(size_id + "/" + gender) is Dictionary:
				return reject("Missing variant " + size_id + "/" + gender)
	manifest = data
	folder = path.get_base_dir()
	return true

func load_family() -> bool:
	# Release the previous GPU texture before loading another family.
	atlas = null
	frames.clear()
	var variant: Dictionary = manifest.variants[BODIES[body] + "/" + PRESENTATIONS[presentation]]
	var atlas_leaf := String(variant.get("atlas", ""))
	var frames_leaf := String(variant.get("frames", ""))
	if not safe_leaf(atlas_leaf) or not atlas_leaf.ends_with(".png") or not safe_leaf(frames_leaf) or not frames_leaf.ends_with(".frames.json"):
		return reject("Unsafe candidate asset path")
	var atlas_path := folder.path_join(atlas_leaf)
	var frames_path := folder.path_join(frames_leaf)
	for entry: Array in [[atlas_path, "atlas_sha256"], [frames_path, "frames_sha256"]]:
		var expected := String(variant.get(entry[1], ""))
		if expected.length() != 64 or not FileAccess.file_exists(entry[0]) or FileAccess.get_sha256(entry[0]) != expected:
			return reject("Candidate source hash mismatch: " + String(entry[0]))
	var dimensions: Variant = variant.get("atlas_dimensions")
	var unique_count := int(variant.get("unique_frames", 0))
	if not dimensions is Array or dimensions.size() != 2 or variant.get("atlas_columns") != 16 or unique_count < 1 or unique_count > 1104:
		return reject("Invalid bounded atlas dimensions/count")
	if not number_pair_matches(dimensions, Vector2i(1536, ceili(float(unique_count) / 16.0) * 96)) or variant.get("logical_frames") != 1104:
		return reject("Atlas rows or logical frame count differ")
	var image := Image.load_from_file(atlas_path)
	if image == null or image.is_empty() or image.has_mipmaps() or image.get_size() != Vector2i(dimensions[0], dimensions[1]):
		return reject("Cannot decode exact candidate atlas")
	image.convert(Image.FORMAT_RGBA8)
	var records: Variant = json_file(frames_path, 2097152)
	if not records is Array or records.size() != 1104:
		return reject("Invalid frame records")
	var checked_pixels: Dictionary = {}
	for item: Variant in records:
		if not item is Dictionary:
			return reject("Frame record is not an object")
		var key := String(item.get("key", ""))
		var index := int(item.get("atlas_index", -1))
		if index < 0 or index >= unique_count or frames.has(key):
			return reject("Duplicate frame key or invalid atlas index")
		var region := Rect2i((index % 16) * 96, floori(float(index) / 16.0) * 96, 96, 96)
		if not checked_pixels.has(index):
			var pixels := image.get_region(region)
			var digest := HashingContext.new()
			digest.start(HashingContext.HASH_SHA256)
			digest.update(pixels.get_data())
			checked_pixels[index] = digest.finish().hex_encode()
		if checked_pixels[index] != item.get("rgba_sha256"):
			return reject("Decoded frame hash mismatch: " + key)
		frames[key] = region
	for state: String in ROWS:
		for facing: int in 8:
			if not frames.has("%s/%d" % [state, facing]):
				return reject("Missing base frame")
	for state: String in ["locomotion", "sprint_locomotion"]:
		for direction: int in 8:
			for facing: int in 8:
				for frame: int in 8:
					if not frames.has("%s/%d/%d/%d" % [state, direction, facing, frame]):
						return reject("Missing independent movement/aim frame")
	atlas = ImageTexture.create_from_image(image)
	return true

static func direction_index(vector: Vector2, fallback: int = 0) -> int:
	if vector.length_squared() < 0.0001:
		return fallback
	return posmod(roundi(atan2(vector.x, vector.y) / (PI / 4.0)), 8)

static func frame_key(state: String, aim_index: int, travel_index: int, gait_phase: float, is_moving: bool) -> String:
	if state.trim_suffix("_b") in ["walk", "sprint"] and is_moving:
		return "%s/%d/%d/%d" % ["sprint_locomotion" if state.begins_with("sprint") else "locomotion", travel_index, aim_index, mini(7, floori(fposmod(gait_phase, 1.0) * 8.0))]
	return "%s/%d" % [state, travel_index if state == "slide" and is_moving else aim_index]

func update_lab(delta: float) -> void:
	if not capture_bank.is_empty():
		return
	var vector := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	moving = not vector.is_zero_approx()
	travel = direction_index(vector, travel)
	aim = direction_index(root.get_mouse_position() - INTERACTIVE_ANCHOR, aim)
	if moving and not animation_paused:
		phase = fposmod(phase + delta * (5.0 if ROWS[action].begins_with("sprint") else 3.0), 1.0)

func handle_key(key: int) -> void:
	var reload_family := false
	match key:
		KEY_ESCAPE:
			quit()
		KEY_1, KEY_2, KEY_3:
			body = key - KEY_1
			reload_family = true
		KEY_N, KEY_M, KEY_F:
			presentation = [KEY_N, KEY_M, KEY_F].find(key)
			reload_family = true
		KEY_TAB:
			action = (action + 1) % ROWS.size()
		KEY_SPACE:
			animation_paused = not animation_paused
		KEY_RIGHT:
			phase = fposmod(phase + 0.125, 1.0)
	if reload_family and not load_family():
		_fail(error)

func text_at(canvas: CanvasItem, position: Vector2, message: String, size: int = 16) -> void:
	canvas.draw_string(ThemeDB.fallback_font, position, message, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("eeddb7"))

func cell_at(canvas: CanvasItem, key: String, anchor: Vector2, scale: float = 1.0) -> void:
	if not frames.has(key) or atlas == null:
		return
	# Shadow belongs to the lab floor, never to the supplied raster cell.
	canvas.draw_set_transform(anchor + Vector2(0, 1), 0, Vector2(scale, scale * 0.25))
	canvas.draw_circle(Vector2.ZERO, 16, Color(0.03, 0.04, 0.06, 0.6))
	canvas.draw_set_transform(anchor, 0, Vector2.ONE * scale)
	canvas.draw_line(Vector2(-36, 0), Vector2(36, 0), Color("687283"), 0.5)
	canvas.draw_texture_rect_region(atlas, Rect2(-PIVOT, Vector2(CELL)), Rect2(frames[key]))
	canvas.draw_line(Vector2(-2, 0), Vector2(2, 0), Color("ffbe65"), 1)
	canvas.draw_set_transform(Vector2.ZERO)

func draw_lab(canvas: CanvasItem) -> void:
	canvas.draw_rect(Rect2(0, 0, 1280, 1500), Color("242737"))
	text_at(canvas, Vector2(20, 30), "CANDIDATE ART LAB - NOT LIVE GAME - NOT APPROVED", 24)
	var anatomy: Dictionary = manifest.get("anatomy", {})
	var anatomy_label := "Anatomy incomplete: directional raster heads / shared body; race-specific body and tail not authored."
	if anatomy.get("body") == "authored_directional_torso_shared_rig_limbs":
		anatomy_label = "Anatomy incomplete: authored raster heads + torsos / shared geometric limbs, boots, gloves; tail not authored."
	text_at(canvas, Vector2(20, 57), anatomy_label)
	text_at(canvas, Vector2(20, 82), "%s / %s / %s | one family resident" % [manifest.race_id, BODIES[body], PRESENTATIONS[presentation]])
	if not capture_bank.is_empty():
		text_at(canvas, Vector2(20, 108), "Controlled %s board. Gait phase 2/8. Visual review pending." % capture_bank)
		for row: int in (10 if capture_bank == "base" else 8):
			text_at(canvas, Vector2(8, 168 + row * 123), ROWS[row] if capture_bank == "base" else "travel " + DIRECTIONS[row], 13)
			for facing: int in 8:
				var anchor := Vector2(174 + facing * 136, 227 + row * 123)
				var key := "%s/%d" % [ROWS[row], facing] if capture_bank == "base" else "%s/%d/%d/2" % [capture_bank, row, facing]
				cell_at(canvas, key, anchor)
				text_at(canvas, anchor + Vector2(-15, 22), DIRECTIONS[facing], 12)
		return
	text_at(canvas, Vector2(20, 112), "1/2/3 size | N/M/F presentation | Tab action | WASD travel | Mouse aim | Space pause | Right step | Esc quit")
	text_at(canvas, Vector2(20, 141), "Action %s | aim %s | travel %s | phase %d/8 | %s" % [ROWS[action], DIRECTIONS[aim], DIRECTIONS[travel], floori(phase * 8), "paused" if animation_paused else "running"])
	cell_at(canvas, frame_key(ROWS[action], aim, travel, phase, moving), INTERACTIVE_ANCHOR, 4)
	text_at(canvas, Vector2(430, 595), "4x nearest | feet pivot + independent shadow; no gameplay movement")
	for facing: int in 8:
		cell_at(canvas, "grounded/%d" % facing, Vector2(170 + facing * 130, 735))
		text_at(canvas, Vector2(160 + facing * 130, 760), DIRECTIONS[facing])

func capture_boards(path: String) -> void:
	if not safe_root(path + "/capture.json") or DirAccess.dir_exists_absolute(path):
		_fail("Capture requires a fresh contained candidate output folder")
		return
	if DisplayServer.get_name() == "headless":
		_fail("Capture requires a rendering display; --validate alone supports headless")
		return
	if DirAccess.make_dir_recursive_absolute(path) != OK:
		_fail("Cannot create capture directory")
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 1400)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(board)
	for bank: String in ["base", "locomotion", "sprint_locomotion"]:
		capture_bank = bank
		board.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var rendered := viewport.get_texture().get_image()
		if rendered == null or rendered.is_empty() or rendered.save_png(path.path_join(bank + ".png")) != OK:
			_fail("Capture failed: " + bank)
			return
	var receipt := FileAccess.open(path.path_join("capture.json"), FileAccess.WRITE)
	if receipt == null:
		_fail("Cannot write capture receipt")
		return
	receipt.store_string(JSON.stringify({"status": "native_candidate_sample_boards_captured", "visual_review": "pending", "human_approved": false, "production_ready": false, "live_game_verified": false, "family": BODIES[body] + "/" + PRESENTATIONS[presentation], "manifest_sha256": FileAccess.get_sha256(folder.path_join("manifest.json")), "gait_phase": 2, "all_phases_captured": false}, "\t"))
	print("PASS: native sample captures saved; visual review pending: " + path)
	quit(0)

func _fail(message: String) -> void:
	push_error("Candidate preview: " + message)
	quit(1)
