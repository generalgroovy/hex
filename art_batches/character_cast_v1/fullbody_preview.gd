extends SceneTree
## Staged full-body IDLE artwork only. No actor, simulation or live presenter.

const DIRECTIONS := ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
const CELL := Vector2i(96, 96)
const PIVOT := Vector2(48, 84)
var manifest: Dictionary = {}
var characters: Array = []
var folder := ""
var error := ""
var selected := 0
var facing := 0
var light_background := false
var atlas: Texture2D
var regions: Array[Rect2i] = []
var board: GalleryBoard
var capture_mode := ""
var selected_capture := 0

class GalleryBoard extends Node2D:

	var gallery

	func _unhandled_key_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo:
			gallery.handle_key(event.keycode)

	func _draw() -> void:
		gallery.draw_gallery(self)

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
		elif arg.begins_with("--character="):
			selected_capture = maxi(0, arg.trim_prefix("--character=").to_int())
		elif arg == "--validate":
			validate_only = true
	if not load_manifest(manifest_path):
		fail(error)
		return
	if selected_capture >= characters.size():
		fail("Selected character index exceeds candidate roster")
		return
	if validate_only:
		for index: int in characters.size():
			selected = index
			if not load_character():
				fail(error)
				return
		print("PASS: %d full-body characters / %d IDLE direction cells; source hashes and alpha geometry. No animation or live-game acceptance." % [characters.size(), characters.size() * 8])
		quit(0)
		return
	selected = selected_capture
	if not load_character():
		fail(error)
		return
	board = GalleryBoard.new()
	board.gallery = self
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not capture_path.is_empty():
		await capture_boards(capture_path)
		return
	root.title = "H.E.X. Full-Body Art Gallery - IDLE CANDIDATES"
	root.size = Vector2i(1280, 800)
	root.add_child(board)

static func safe_root(path: String) -> bool:
	return not ".." in path and not "\\" in path and path.begins_with("res://art_batches/character_cast_v1/output/")

static func safe_leaf(path: String) -> bool:
	return not path.is_empty() and path == path.get_file() and not ".." in path and not ":" in path and not "\\" in path

static func exact_numbers(value: Variant, expected: Array) -> bool:
	if not value is Array or value.size() != expected.size():
		return false
	for index: int in expected.size():
		if typeof(value[index]) not in [TYPE_INT, TYPE_FLOAT]:
			return false
		if not is_finite(float(value[index])) or float(value[index]) != float(expected[index]):
			return false
	return true

static func valid_sha(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for index: int in value.length():
		if not value.substr(index, 1) in "0123456789abcdef":
			return false
	return true

func reject(message: String) -> bool:
	error = message
	return false

func load_manifest(path: String) -> bool:
	if not safe_root(path) or path.get_file() != "manifest.json":
		return reject("Expected a contained full-body candidate manifest.json")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 2097152:
		return reject("Manifest absent or oversized")
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or data.get("schema_version") != 1:
		return reject("Unknown full-body manifest schema")
	if data.get("production_ready") != false or data.get("human_approved") != false:
		return reject("Candidate must explicitly remain unapproved and not production-ready")
	if not exact_numbers(data.get("cell"), [96, 96]) or not exact_numbers(data.get("pivot"), [48, 84]):
		return reject("Full-body cell/pivot contract differs")
	if data.get("directions") != DIRECTIONS or data.get("animation_status") != "idle_only":
		return reject("Gallery requires eight authored idle facings, not synthetic animation claims")
	if not data.get("characters") is Array or data.characters.is_empty() or data.characters.size() > 64:
		return reject("Candidate roster must contain 1..64 identities")
	var ids: Dictionary = {}
	for item: Variant in data.characters:
		if not item is Dictionary:
			return reject("Character entry is not an object")
		var id := String(item.get("id", ""))
		if id.is_empty() or ids.has(id) or String(item.get("display_name", "")).is_empty():
			return reject("Missing or duplicate character identity")
		if item.get("body") not in ["small", "middle", "large"]:
			return reject("Unknown body size")
		ids[id] = true
	manifest = data
	characters = data.characters
	folder = path.get_base_dir()
	return true

func load_character() -> bool:
	# Release previous GPU texture before decoding the next identity.
	atlas = null
	regions.clear()
	var entry: Dictionary = characters[selected]
	var leaf := String(entry.get("atlas", ""))
	if not safe_leaf(leaf) or not leaf.ends_with(".png"):
		return reject("Unsafe full-body atlas path")
	var path := folder.path_join(leaf)
	if not valid_sha(entry.get("atlas_sha256")) or not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != entry.atlas_sha256:
		return reject("Full-body atlas hash mismatch: " + leaf)
	var image := Image.load_from_file(path)
	if image == null or image.is_empty() or image.has_mipmaps() or image.get_size() != Vector2i(768, 96):
		return reject("Expected exact 768x96 eight-idle-frame atlas")
	image.convert(Image.FORMAT_RGBA8)
	if not entry.get("frames") is Array or entry.frames.size() != 8:
		return reject("Expected eight explicit idle records")
	for index: int in 8:
		var frame: Variant = entry.frames[index]
		if not frame is Dictionary or frame.get("direction") != DIRECTIONS[index] or not exact_numbers(frame.get("rect"), [index * 96, 0, 96, 96]):
			return reject("Idle frame order/geometry differs")
		var region := Rect2i(index * 96, 0, 96, 96)
		var cell := image.get_region(region)
		var bytes := cell.get_data()
		var hashing := HashingContext.new()
		hashing.start(HashingContext.HASH_SHA256)
		hashing.update(bytes)
		if not valid_sha(frame.get("rgba_sha256")) or hashing.finish().hex_encode() != frame.rgba_sha256:
			return reject("Decoded idle pixel hash mismatch")
		var opaque := 0
		for offset: int in range(3, bytes.size(), 4):
			if bytes[offset] not in [0, 255]:
				return reject("Idle pixels must use crisp binary alpha")
			if bytes[offset] == 255:
				opaque += 1
		var bounds := cell.get_used_rect()
		if opaque < 100 or bounds.position.x < 1 or bounds.position.y < 1 or bounds.end.x > 95 or bounds.end.y > 84:
			return reject("Empty, clipped or ground-crossing full-body cell")
		regions.append(region)
	atlas = ImageTexture.create_from_image(image)
	return true

func handle_key(key: int) -> void:
	var reload_character := false
	match key:
		KEY_ESCAPE:
			quit(0)
		KEY_RIGHT, KEY_PAGEDOWN:
			selected = (selected + 1) % characters.size()
			reload_character = true
		KEY_LEFT, KEY_PAGEUP:
			selected = posmod(selected - 1, characters.size())
			reload_character = true
		KEY_TAB:
			facing = (facing + 1) % 8
		KEY_B:
			light_background = not light_background
	if key >= KEY_1 and key <= KEY_8:
		facing = key - KEY_1
	if reload_character and not load_character():
		fail(error)
	if board != null:
		board.queue_redraw()

func text_at(canvas: CanvasItem, position: Vector2, message: String, font_size: int = 16) -> void:
	canvas.draw_string(ThemeDB.fallback_font, position, message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("302719") if light_background else Color("efdfbc"))

func draw_cell(canvas: CanvasItem, index: int, anchor: Vector2, scale: float) -> void:
	canvas.draw_set_transform(anchor, 0, Vector2.ONE * scale)
	canvas.draw_line(Vector2(-34, 0), Vector2(34, 0), Color("788077"), .5)
	canvas.draw_texture_rect_region(atlas, Rect2(-PIVOT, Vector2(CELL)), Rect2(regions[index]))
	canvas.draw_set_transform(Vector2.ZERO)

func draw_gallery(canvas: CanvasItem) -> void:
	canvas.draw_rect(Rect2(0, 0, 1600, 800), Color("dfd0ae") if light_background else Color("252b35"))
	var entry: Dictionary = characters[selected]
	if capture_mode == "card":
		draw_cell(canvas, 0, Vector2(128, 217), 2)
		text_at(canvas, Vector2(10, 26), String(entry.display_name), 16)
		text_at(canvas, Vector2(10, 248), "%s | %s" % [entry.get("race", ""), entry.body], 13)
		return
	text_at(canvas, Vector2(20, 30), "H.E.X. FULL-BODY ART - EIGHT IDLE FACINGS ONLY", 24)
	text_at(canvas, Vector2(20, 60), "NOT a complete animation set. Not installed in the playable checkpoint.")
	text_at(canvas, Vector2(20, 90), "%d / %d: %s | %s | %s" % [selected+1, characters.size(), entry.display_name, entry.get("race", ""), entry.body], 20)
	text_at(canvas, Vector2(20, 118), "Left/Right identity | 1..8 or Tab facing | B background | Esc close | one identity texture resident")
	if capture_mode != "views":
		draw_cell(canvas, facing, Vector2(640, 580), 4)
		text_at(canvas, Vector2(570, 610), DIRECTIONS[facing] + " / 4x nearest", 16)
	for index: int in 8:
		var anchor := Vector2(84+index*155, 740) if capture_mode != "views" else Vector2(100+index*200, 425)
		draw_cell(canvas, index, anchor, 1 if capture_mode != "views" else 2)
		text_at(canvas, anchor+Vector2(-12, 24), DIRECTIONS[index])
	if capture_mode == "views":
		text_at(canvas, Vector2(20, 500), "All eight views. Blank animation rows are not fabricated from this idle art.")

func capture_boards(path: String) -> void:
	if not safe_root(path + "/capture.json") or DirAccess.dir_exists_absolute(path):
		fail("Capture requires a fresh contained candidate directory")
		return
	if DisplayServer.get_name() == "headless":
		fail("Native captures require a rendering display")
		return
	if DirAccess.make_dir_recursive_absolute(path) != OK:
		fail("Cannot create capture output")
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 264)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(board)
	var rows := ceili(float(characters.size()) / 5)
	var front_board := Image.create(1280, rows * 264, false, Image.FORMAT_RGBA8)
	front_board.fill(Color("252b35"))
	capture_mode = "card"
	for index: int in characters.size():
		selected = index
		if not load_character():
			fail(error)
			return
		board.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var card := viewport.get_texture().get_image()
		if card == null or card.is_empty():
			fail("Native character card capture failed")
			return
		front_board.blit_rect(card, Rect2i(0, 0, 256, 264), Vector2i((index % 5) * 256, floori(float(index)/5) * 264))
	if front_board.save_png(path.path_join("all-fronts.png")) != OK:
		fail("Cannot save native front board")
		return
	selected = selected_capture
	if not load_character():
		fail(error)
		return
	capture_mode = "views"
	viewport.size = Vector2i(1600, 560)
	for background: String in ["dark", "light"]:
		light_background = background == "light"
		board.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var rendered := viewport.get_texture().get_image()
		if rendered == null or rendered.is_empty() or rendered.save_png(path.path_join("selected-eight-"+background+".png")) != OK:
			fail("Cannot save eight-facing capture")
			return
	var receipt := FileAccess.open(path.path_join("capture.json"), FileAccess.WRITE)
	if receipt == null:
		fail("Cannot write capture receipt")
		return
	receipt.store_string(JSON.stringify({"status":"native_idle_capture_complete", "characters":characters.size(), "views_per_character":8, "selected_id":characters[selected].id, "fronts_captured":characters.size(), "all_views_captured_for_all_characters":false, "animation_status":"idle_only", "human_approved":false, "production_ready":false, "manifest_sha256":FileAccess.get_sha256(folder.path_join("manifest.json"))}, "\t"))
	print("PASS: native full-body idle front board and selected eight-facing boards saved: " + path)
	quit(0)

func fail(message: String) -> void:
	push_error("Full-body gallery: " + message)
	quit(1)
