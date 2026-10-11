extends RefCounted

# Lossless baked Image resources are decoded by ResourceLoader. Retrieval is
# permitted only after THREAD_LOAD_LOADED during gameplay; final shutdown has
# an explicit bounded token-collection hook. Uploads are budgeted by the caller,
# never initiated from a draw method.
const VERSION := "wellspring-exact-regions-1"
const ROOT := "res://assets/environment/wellspring_ground_v1"
const MANIFEST := ROOT + "/manifest.tres"
const CHUNK := 512
const MAX_CHUNKS := 132
const BASE_RESIDENT := 24
const MAX_PENDING := 2
const MAX_UPLOADS := 2
const MAX_BYTES := 6144 * 5376 * 4
# Authoring provenance is checked by the bake-equivalence suite. Runtime uses
# versioned signatures because exported GDScript may be remapped or compiled.
# None of these inputs includes the output manifest, so the digest is acyclic.
const BAKE_SOURCE_PATHS: Array[String] = [
	"res://scripts/bake_wellspring_terrain.gd",
	"res://src/presentation/wellspring_terrain_stream.gd",
	"res://src/presentation/wellspring_illustrated_kit.gd",
	"res://src/presentation/hex_environment_layout.gd",
	"res://src/presentation/pixel_map_library.gd",
	"res://art_batches/wellspring_style_v2/ground_style.gd",
	"res://src/sim/hex/hex_grid.gd",
	"res://src/sim/core/sim_config.gd",
]
var last_error := ""
# A rejected replacement reports its own error without invalidating the
# healthy current stream. Only admission/decode failures set this load error.
var _stream_error := ""
var canvas_size := Vector2i.ZERO
var records: Dictionary[Vector2i, Dictionary] = {}
var textures: Dictionary[Vector2i, Texture2D] = {}
var order: Array[Vector2i] = []
var required: Array[Vector2i] = []
var desired: Array[Vector2i] = []
var pending: Dictionary[Vector2i, String] = {}
var queue: Array[Vector2i] = []
var cache_bytes := 0
var uploads := 0
var hits := 0
var requests := 0
var overview_record: Dictionary = {}
var _request_rect := Rect2()
var suspended := false
var closed := false


func configure(document: Dictionary, expected_signature: String, expected_canvas: Vector2i) -> bool:
	# A request token belongs to this instance until its result is collected.
	# Refuse replacement while pending; dropping a RefCounted owner does not
	# cancel ResourceLoader's retained request tokens.
	if not pending.is_empty():
		last_error = "Terrain stream cannot reconfigure in flight"
		return false
	last_error = ""
	_stream_error = ""
	records.clear()
	textures.clear()
	order.clear()
	required.clear()
	desired.clear()
	queue.clear()
	overview_record.clear()
	cache_bytes = 0
	_request_rect = Rect2()
	suspended = false
	closed = false
	canvas_size = Vector2i.ZERO
	if String(document.get("version", "")) != VERSION or String(document.get("signature", "")) != expected_signature or expected_signature.length() != 64:
		return _fail("Terrain bake does not match the map, art and compositor contract; regenerate it")
	if document.get("canvas", []) != [expected_canvas.x, expected_canvas.y] or int(document.get("chunk_size", 0)) != CHUNK:
		return _fail("Terrain bake has incompatible dimensions")
	if expected_canvas.x < 1 or expected_canvas.y < 1 or expected_canvas.x > 6144 or expected_canvas.y > 5376:
		return _fail("Terrain bake exceeds its explicit world bound")
	var rows: Variant = document.get("chunks", [])
	var expected_count := ceili(float(expected_canvas.x) / CHUNK) * ceili(float(expected_canvas.y) / CHUNK)
	if not rows is Array or rows.size() != expected_count or expected_count > MAX_CHUNKS:
		return _fail("Terrain bake must cover every native region exactly once")
	var admitted: Dictionary[Vector2i, Dictionary] = {}
	for index: int in rows.size():
		if not rows[index] is Dictionary: return _fail("Invalid terrain region record")
		var row: Dictionary = rows[index]
		var columns := ceili(float(expected_canvas.x) / CHUNK)
		var id := Vector2i(index % columns, index / columns)
		var rect := Rect2i(id * CHUNK, Vector2i.ONE * CHUNK).intersection(Rect2i(Vector2i.ZERO, expected_canvas))
		if row.get("id", []) != [id.x, id.y] or row.get("size", []) != [rect.size.x, rect.size.y] or String(row.get("path", "")) != ROOT + "/chunk_%02d_%02d.res" % [id.x, id.y] or not _valid_hash(String(row.get("rgba_sha256", ""))):
			return _fail("Terrain regions must retain exact ordered bounds, paths and pixel hashes")
		admitted[id] = row.duplicate(true)
	var overview: Variant = document.get("overview", {})
	var overview_size := Vector2i(ceili(float(expected_canvas.x) / 4), ceili(float(expected_canvas.y) / 4))
	if not overview is Dictionary or overview.get("size", []) != [overview_size.x, overview_size.y] or String(overview.get("path", "")) != ROOT + "/overview.res" or not _valid_hash(String(overview.get("rgba_sha256", ""))):
		return _fail("Terrain overview needs its own bounded prebuilt resource")
	records = admitted
	overview_record = overview.duplicate(true)
	canvas_size = expected_canvas
	return true


func ids_for(view: Rect2) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not view.has_area() or not view.position.is_finite() or not view.end.is_finite(): return result
	var clipped := view.intersection(Rect2(Vector2.ZERO, Vector2(canvas_size)))
	if not clipped.has_area(): return result
	var first := Vector2i((clipped.position / CHUNK).floor())
	var end := Vector2i((clipped.end / CHUNK).ceil())
	for y: int in range(first.y, end.y):
		for x: int in range(first.x, end.x): result.append(Vector2i(x, y))
	return result


func request_view(view: Rect2) -> void:
	if closed or records.is_empty(): return
	if not suspended and view == _request_rect: return
	suspended = false
	_request_rect = view
	required = ids_for(view)
	desired = required.duplicate()
	var neighbors := ids_for(view.grow(CHUNK))
	# Nearest unseen tiles first. Stable coordinate tie breaking makes the
	# preparation order independent of Dictionary iteration and frame rate.
	var center := view.get_center()
	neighbors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := (Vector2(a * CHUNK) + Vector2.ONE * CHUNK / 2.0).distance_squared_to(center)
		var db := (Vector2(b * CHUNK) + Vector2.ONE * CHUNK / 2.0).distance_squared_to(center)
		if is_equal_approx(da, db): return a.y < b.y or (a.y == b.y and a.x < b.x)
		return da < db)
	for id: Vector2i in neighbors:
		if desired.has(id): continue
		desired.append(id)
	queue.clear()
	for id: Vector2i in desired:
		if not textures.has(id) and not pending.has(id): queue.append(id)
	_trim()


func pump(upload_budget: int = MAX_UPLOADS) -> int:
	if closed: return 0
	if suspended:
		_drain_ready()
		return 0
	var completed := 0
	var budget := clampi(upload_budget, 0, MAX_UPLOADS)
	for id: Vector2i in pending.keys():
		if completed >= budget: break
		var path: String = pending[id]
		var status := _request_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS: continue
		if status != ResourceLoader.THREAD_LOAD_LOADED:
			# FAILED still owns a ResourceLoader token; final teardown collects
			# it. INVALID has no live request token to collect.
			if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE: pending.erase(id)
			_fail("Unable to decode prepared terrain: " + path)
			continue
		var image := _take_ready(path)
		pending.erase(id)
		# A teleport may supersede a request while its bounded decode finishes.
		# Drain it without retaining or uploading irrelevant old-view pixels.
		if not desired.has(id): continue
		if not valid_image(image, records[id]):
			_fail("Prepared terrain pixel validation failed: " + path)
			continue
		_admit(id, image)
		completed += 1
	while _stream_error.is_empty() and pending.size() < MAX_PENDING and not queue.is_empty() and budget > 0:
		var id: Vector2i = queue.pop_front()
		if textures.has(id) or pending.has(id) or not desired.has(id): continue
		var path: String = records[id].path
		if _start_request(path) != OK:
			_fail("Could not queue prepared terrain: " + path)
			continue
		pending[id] = path
		requests += 1
	return completed


func suspend() -> bool:
	# Called once per non-campus frame. Never starts, blocks, validates pixels
	# or uploads; cached textures remain available for a later same-view return.
	suspended = true
	required.clear()
	desired.clear()
	queue.clear()
	_request_rect = Rect2()
	_drain_ready()
	return pending.is_empty()


func _drain_ready() -> void:
	for id: Vector2i in pending.keys():
		var path: String = pending[id]
		var request_status := _request_status(path)
		if request_status == ResourceLoader.THREAD_LOAD_LOADED:
			_take_ready(path)
			pending.erase(id)
		elif request_status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			pending.erase(id)
		elif request_status == ResourceLoader.THREAD_LOAD_FAILED:
			_fail("Unable to decode prepared terrain: " + path)


func finish_shutdown() -> void:
	# Genuine final teardown only. ResourceLoader has no cancellation API.
	# Collect at most MAX_PENDING tokens, including failed/in-progress loads;
	# unlike every gameplay path, this may wait for a decode to finish.
	if closed: return
	suspended = true
	closed = true
	required.clear()
	desired.clear()
	queue.clear()
	_request_rect = Rect2()
	for id: Vector2i in pending.keys():
		var path: String = pending[id]
		if _request_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_finish_request(path)
		pending.erase(id)
	textures.clear()
	order.clear()
	cache_bytes = 0


func _finish_request(path: String) -> void:
	ResourceLoader.load_threaded_get(path)


func _start_request(path: String) -> Error:
	if not ResourceLoader.exists(path, "Image"): return ERR_FILE_NOT_FOUND
	return ResourceLoader.load_threaded_request(path, "Image", false, ResourceLoader.CACHE_MODE_IGNORE)


func _request_status(path: String) -> int:
	return ResourceLoader.load_threaded_get_status(path)


func _take_ready(path: String) -> Image:
	return ResourceLoader.load_threaded_get(path) as Image


func ready_for(view: Rect2) -> bool:
	if closed or records.is_empty() or not _stream_error.is_empty() or not view.has_area() or not view.position.is_finite() or not view.end.is_finite(): return false
	for id: Vector2i in ids_for(view):
		if not textures.has(id): return false
	return true


func status() -> Dictionary:
	var ready := 0
	for id: Vector2i in required:
		if textures.has(id): ready += 1
	return {"ready": ready, "required": required.size(), "pending": pending.size(), "queued": queue.size(), "resident": textures.size(), "bytes": cache_bytes, "uploads": uploads, "requests": requests, "suspended": suspended, "closed": closed, "error": _stream_error}


func load_immediate(id: Vector2i) -> Texture2D:
	# Explicit tooling/preparation API. Gameplay uses request_view + pump;
	# draw methods never call this synchronous path.
	if closed: return null
	if textures.has(id):
		hits += 1
		order.erase(id)
		order.append(id)
		return textures[id]
	if not records.has(id) or pending.has(id): return null
	var path: String = records[id].path
	if not ResourceLoader.exists(path, "Image"): return null
	var image := ResourceLoader.load(path, "Image", ResourceLoader.CACHE_MODE_IGNORE) as Image
	if not valid_image(image, records[id]):
		_fail("Prepared terrain pixel validation failed: " + path)
		return null
	_admit(id, image)
	return textures.get(id)


func _admit(id: Vector2i, image: Image) -> void:
	if textures.has(id): return
	textures[id] = ImageTexture.create_from_image(image)
	order.append(id)
	cache_bytes += image.get_data().size()
	uploads += 1
	_trim()


func _trim() -> void:
	var limit := mini(MAX_CHUNKS, maxi(BASE_RESIDENT, desired.size()))
	for id: Vector2i in order.duplicate():
		if textures.size() <= limit: break
		if desired.has(id): continue
		var texture: Texture2D = textures[id]
		cache_bytes -= texture.get_width() * texture.get_height() * 4
		textures.erase(id)
		order.erase(id)


static func valid_image(image: Image, record: Dictionary) -> bool:
	if image == null or image.has_mipmaps() or image.get_format() != Image.FORMAT_RGBA8: return false
	var size := image.get_size()
	if record.get("size", []) != [size.x, size.y]: return false
	return pixel_hash(image) == String(record.get("rgba_sha256", ""))


static func pixel_hash(image: Image) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(image.get_data())
	return hash.finish().hex_encode()


static func _valid_hash(value: String) -> bool:
	if value.length() != 64: return false
	for index: int in value.length():
		if not value.substr(index, 1) in "0123456789abcdef": return false
	return true


func _fail(message: String) -> bool:
	last_error = message
	_stream_error = message
	return false
