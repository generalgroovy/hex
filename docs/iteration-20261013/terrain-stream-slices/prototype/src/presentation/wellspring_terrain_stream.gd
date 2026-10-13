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
const MAX_UPLOAD_BYTES := MAX_UPLOADS * CHUNK * CHUNK * 4
const MAX_PUMP_USEC := 2000
const VALIDATION_CHUNK_BYTES := 32 * 1024
const MAX_VALIDATION_BYTES := MAX_UPLOAD_BYTES
const VALIDATION_COLLECTED := 0
const VALIDATION_HASHING := 1
const VALIDATION_VERIFIED := 2
const VALIDATION_UPLOAD_READY := 3
const MAX_PREFETCH_CHUNKS := 24
const MAX_PREFETCH_BYTES := MAX_PREFETCH_CHUNKS * CHUNK * CHUNK * 4
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
var prefetched: Array[Vector2i] = []
var pending: Dictionary[Vector2i, String] = {}
# Pending owns both uncollected loader tokens and collected validation jobs.
# A job never adds a third in-flight tile or exposes partially verified pixels.
var _validation_jobs: Dictionary[Vector2i, Dictionary] = {}
var queue: Array[Vector2i] = []
var cache_bytes := 0
var uploads := 0
var hits := 0
var requests := 0
var overview_record: Dictionary = {}
var _request_rect := Rect2()
var _prefetch_rect := Rect2()
var last_pump_usec := 0
var last_pump_bytes := 0
var last_pump_validation_bytes := 0
var validation_buffer_bytes := 0
var validation_peak_logical_bytes := 0
var validation_started := 0
var validation_completed := 0
var validation_updates := 0
var budget_yields := 0
var suspended := false
var closed := false
const PROFILE_STAGES := [&"ready_retrieval", &"pixel_validation", &"image_reconstruction", &"texture_creation", &"retention_trim", &"request_submission"]
var profile_enabled := false
var _profile_usec: Dictionary = {}
var _profile_calls: Dictionary = {}
var _request_started_usec: Dictionary[Vector2i, int] = {}
var _completed_request_latency_usec := 0
var _maximum_request_latency_usec := 0
var _completed_profiled_requests := 0


func configure(document: Dictionary, expected_signature: String, expected_canvas: Vector2i) -> bool:
	# A pending item owns either a loader token or a collected validation job.
	# Refuse replacement in either phase; dropping a RefCounted owner does not
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
	prefetched.clear()
	queue.clear()
	overview_record.clear()
	cache_bytes = 0
	_request_rect = Rect2()
	_prefetch_rect = Rect2()
	last_pump_usec = 0
	last_pump_bytes = 0
	last_pump_validation_bytes = 0
	_validation_jobs.clear()
	validation_buffer_bytes = 0
	validation_peak_logical_bytes = 0
	validation_started = 0
	validation_completed = 0
	validation_updates = 0
	budget_yields = 0
	suspended = false
	closed = false
	reset_profile()
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
	_rebuild_demand()


func prefetch_view(view: Rect2) -> void:
	# Intent only: safe from a map draw callback. It neither wakes a suspended
	# stream nor grants travel/readiness, and never starts a decode or upload.
	if closed or suspended or records.is_empty() or view == _prefetch_rect: return
	_prefetch_rect = view
	prefetched = ids_for(view)
	_sort_nearest(prefetched, view.get_center())
	if prefetched.size() > MAX_PREFETCH_CHUNKS: prefetched.resize(MAX_PREFETCH_CHUNKS)
	_rebuild_demand()


func clear_prefetch() -> void:
	if prefetched.is_empty() and not _prefetch_rect.has_area(): return
	prefetched.clear()
	_prefetch_rect = Rect2()
	_rebuild_demand()


func _rebuild_demand() -> void:
	desired = required.duplicate()
	var neighbors := ids_for(_request_rect.grow(CHUNK)) if _request_rect.has_area() else []
	# Nearest unseen tiles first. Stable coordinate tie breaking makes the
	# preparation order independent of Dictionary iteration and frame rate.
	_sort_nearest(neighbors, _request_rect.get_center())
	for id: Vector2i in neighbors:
		if desired.has(id): continue
		desired.append(id)
	# Current view and its movement halo always win. Destination retention adds
	# at most24 native tiles/24MiB within the existing whole-campus ceiling.
	for id: Vector2i in prefetched:
		if not desired.has(id): desired.append(id)
	# These jobs have no loader token left to collect. Superseded tokens stay
	# owned until their normal ready drain, but detached stale pixels can retire.
	for id: Vector2i in _validation_jobs.keys():
		if not desired.has(id): _discard_validation(id)
	queue.clear()
	for id: Vector2i in desired:
		if not textures.has(id) and not pending.has(id): queue.append(id)
	_trim()


static func _sort_nearest(ids: Array, center: Vector2) -> void:
	ids.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := (Vector2(a * CHUNK) + Vector2.ONE * CHUNK / 2.0).distance_squared_to(center)
		var db := (Vector2(b * CHUNK) + Vector2.ONE * CHUNK / 2.0).distance_squared_to(center)
		if is_equal_approx(da, db): return a.y < b.y or (a.y == b.y and a.x < b.x)
		return da < db)


func pump(upload_budget: int = MAX_UPLOADS, time_budget_usec: int = MAX_PUMP_USEC, byte_budget: int = MAX_UPLOAD_BYTES) -> int:
	last_pump_usec = 0
	last_pump_bytes = 0
	last_pump_validation_bytes = 0
	if closed: return 0
	if suspended:
		_drain_ready()
		return 0
	var completed := 0
	var budget := clampi(upload_budget, 0, MAX_UPLOADS)
	var usec_limit := clampi(time_budget_usec, 0, MAX_PUMP_USEC)
	var byte_limit := clampi(byte_budget, 0, MAX_UPLOAD_BYTES)
	if budget == 0 or usec_limit == 0 or byte_limit == 0: return 0
	var started := _clock_usec()
	# Pending order can predate a changed destination. Required/current demand
	# takes precedence when multiple decoded results become ready together.
	var admission_order: Array = pending.keys()
	admission_order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _demand_rank(a) < _demand_rank(b))
	for id: Vector2i in admission_order:
		if completed >= budget: break
		if _pump_time_exhausted(started, usec_limit): break
		var path: String = pending[id]
		var bytes := int(records[id].size[0]) * int(records[id].size[1]) * 4
		if desired.has(id) and last_pump_bytes + bytes > byte_limit:
			budget_yields += 1
			continue
		if not _validation_jobs.has(id):
			var status := _request_status(path)
			if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS: continue
			if status != ResourceLoader.THREAD_LOAD_LOADED:
				# FAILED still owns a token; final teardown collects it. INVALID
				# has no live request token left to collect.
				if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
					pending.erase(id)
					_request_started_usec.erase(id)
				_fail("Unable to decode prepared terrain: " + path)
				continue
			var retrieval_started := _clock_usec() if profile_enabled else 0
			if profile_enabled and _request_started_usec.has(id):
				var latency := maxi(0, retrieval_started - _request_started_usec[id])
				_completed_request_latency_usec += latency
				_maximum_request_latency_usec = maxi(_maximum_request_latency_usec, latency)
				_completed_profiled_requests += 1
			var decoded := _take_ready(path)
			_record_profile(&"ready_retrieval", retrieval_started)
			_request_started_usec.erase(id)
			# Collected tokens cannot be collected again, even on a changed view.
			if not desired.has(id):
				pending.erase(id)
				continue
			var validation_clock := _clock_usec() if profile_enabled else 0
			var valid := _begin_validation(id, decoded)
			_record_profile(&"pixel_validation", validation_clock)
			if not valid:
				pending.erase(id)
				continue
		if not _advance_validation(id, started, usec_limit): continue
		if _pump_time_exhausted(started, usec_limit): break
		var image: Image = _validation_jobs[id].image
		_admit(id, image)
		_discard_validation(id)
		last_pump_bytes += bytes
		completed += 1
	while _stream_error.is_empty() and pending.size() < MAX_PENDING and not queue.is_empty() and budget > 0:
		if _pump_time_exhausted(started, usec_limit): break
		var id: Vector2i = queue.pop_front()
		if textures.has(id) or pending.has(id) or not desired.has(id): continue
		var path: String = records[id].path
		var request_started := _clock_usec() if profile_enabled else 0
		var request_error := _start_request(path)
		_record_profile(&"request_submission", request_started)
		if request_error != OK:
			_fail("Could not queue prepared terrain: " + path)
			continue
		pending[id] = path
		if profile_enabled: _request_started_usec[id] = request_started
		requests += 1
	# Time checks divide validation into bounded updates. Retrieval, buffer copy,
	# reconstruction and upload remain indivisible and can overrun the target.
	# Retrieved-image metadata and ownership bookkeeping finish before the next
	# check; no further copy, hash, reconstruction or upload starts after it.
	# Upload/validation byte limits and the two-item ownership ceiling are strict.
	last_pump_usec = maxi(0, _clock_usec() - started)
	return completed


func _pump_time_exhausted(started: int, usec_limit: int) -> bool:
	if _clock_usec() - started < usec_limit: return false
	budget_yields += 1
	return true


func _begin_validation(id: Vector2i, image: Image) -> bool:
	validation_started += 1
	var record: Dictionary = records[id]
	if image == null or image.has_mipmaps() or image.get_format() != Image.FORMAT_RGBA8 or record.size != [image.get_width(), image.get_height()]:
		return _fail("Prepared terrain pixel validation failed: " + String(record.path))
	var size := image.get_size()
	_validation_jobs[id] = {"phase": VALIDATION_COLLECTED, "image": image,
		"size": size, "expected_hash": String(record.rgba_sha256), "path": String(record.path),
		"bytes": size.x * size.y * 4, "pixels": PackedByteArray(), "offset": 0, "context": null}
	_note_validation_peak()
	return true


func _advance_validation(id: Vector2i, pump_started: int, usec_limit: int) -> bool:
	var job: Dictionary = _validation_jobs[id]
	var size: Vector2i = job.size
	var record: Dictionary = records[id]
	if not desired.has(id):
		_discard_validation(id)
		return false
	if record.size != [size.x, size.y] or String(record.rgba_sha256) != String(job.expected_hash) or String(record.path) != String(job.path):
		return _reject_validation(id)
	if int(job.phase) == VALIDATION_COLLECTED:
		if _pump_time_exhausted(pump_started, usec_limit): return false
		var preparation_started := _clock_usec() if profile_enabled else 0
		var image: Image = job.image
		# Recheck metadata in case a custom loader retained a mutable Image alias.
		if image == null or image.has_mipmaps() or image.get_format() != Image.FORMAT_RGBA8 or image.get_size() != size:
			_record_profile(&"pixel_validation", preparation_started, false)
			return _reject_validation(id)
		var pixels := image.get_data()
		var context := HashingContext.new()
		if pixels.size() != int(job.bytes) or context.start(HashingContext.HASH_SHA256) != OK:
			_record_profile(&"pixel_validation", preparation_started, false)
			return _reject_validation(id)
		job.pixels = pixels
		job.context = context
		validation_buffer_bytes += pixels.size()
		# Count the brief original-image plus detached-buffer overlap logically;
		# this is deliberately not a claim about the engine allocator or RSS.
		_note_validation_peak()
		job.image = null
		job.phase = VALIDATION_HASHING
		_record_profile(&"pixel_validation", preparation_started, false)
	if int(job.phase) == VALIDATION_HASHING:
		var pixels: PackedByteArray = job.pixels
		var context: HashingContext = job.context
		while int(job.offset) < pixels.size():
			if _pump_time_exhausted(pump_started, usec_limit): return false
			if last_pump_validation_bytes >= MAX_VALIDATION_BYTES:
				budget_yields += 1
				return false
			var begin: int = job.offset
			var end := mini(pixels.size(), begin + mini(VALIDATION_CHUNK_BYTES, MAX_VALIDATION_BYTES - last_pump_validation_bytes))
			var update_started := _clock_usec() if profile_enabled else 0
			var result := context.update(pixels.slice(begin, end))
			_record_profile(&"pixel_validation", update_started, false)
			validation_updates += 1
			last_pump_validation_bytes += end - begin
			if result != OK: return _reject_validation(id)
			job.offset = end
		if _pump_time_exhausted(pump_started, usec_limit): return false
		var finish_started := _clock_usec() if profile_enabled else 0
		var digest := context.finish().hex_encode()
		_record_profile(&"pixel_validation", finish_started, false)
		if digest != String(job.expected_hash): return _reject_validation(id)
		job.context = null
		job.phase = VALIDATION_VERIFIED
		validation_completed += 1
	if int(job.phase) == VALIDATION_VERIFIED:
		if _pump_time_exhausted(pump_started, usec_limit): return false
		var reconstruction_started := _clock_usec() if profile_enabled else 0
		var pixels: PackedByteArray = job.pixels
		# Upload the exact byte snapshot that was hashed, never the old Image.
		var image := Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, pixels)
		_record_profile(&"image_reconstruction", reconstruction_started)
		if image == null or image.get_size() != size or image.get_format() != Image.FORMAT_RGBA8 or image.has_mipmaps():
			return _reject_validation(id)
		job.image = image
		_note_validation_peak()
		validation_buffer_bytes -= pixels.size()
		job.pixels = PackedByteArray()
		job.phase = VALIDATION_UPLOAD_READY
	return int(job.phase) == VALIDATION_UPLOAD_READY


func _validation_image_bytes() -> int:
	var bytes := 0
	for job: Dictionary in _validation_jobs.values():
		if job.image != null: bytes += int(job.bytes)
	return bytes


func _note_validation_peak() -> void:
	validation_peak_logical_bytes = maxi(validation_peak_logical_bytes, validation_buffer_bytes + _validation_image_bytes())


func _discard_validation(id: Vector2i) -> void:
	if _validation_jobs.has(id):
		var pixels: PackedByteArray = _validation_jobs[id].pixels
		validation_buffer_bytes -= pixels.size()
		_validation_jobs.erase(id)
	pending.erase(id)
	_request_started_usec.erase(id)


func _reject_validation(id: Vector2i) -> bool:
	var path := String(pending.get(id, ""))
	_discard_validation(id)
	return _fail("Prepared terrain pixel validation failed: " + path)


func _clock_usec() -> int:
	return Time.get_ticks_usec()


func reset_profile() -> void:
	_profile_usec.clear()
	_profile_calls.clear()
	_request_started_usec.clear()
	_completed_request_latency_usec = 0
	_maximum_request_latency_usec = 0
	_completed_profiled_requests = 0


func _record_profile(stage: StringName, started: int, count_as_call: bool = true) -> void:
	if not profile_enabled or stage not in PROFILE_STAGES: return
	_profile_usec[stage] = int(_profile_usec.get(stage, 0)) + maxi(0, _clock_usec() - started)
	if count_as_call: _profile_calls[stage] = int(_profile_calls.get(stage, 0)) + 1


func profile_status() -> Dictionary:
	return {"enabled": profile_enabled, "elapsed_usec": _profile_usec.duplicate(), "calls": _profile_calls.duplicate(),
		"completed_request_latency_usec": _completed_request_latency_usec, "maximum_request_latency_usec": _maximum_request_latency_usec, "completed_profiled_requests": _completed_profiled_requests,
		"scope": "Optional aggregate CPU elapsed intervals. Pixel validation sums metadata, byte-copy, hashing and digest intervals without inter-pump waits; its call count records attempts once at start. Ready retrieval, exact-byte image reconstruction, texture creation and trimming are separate. Request-to-ready latency includes worker decode, polling and main-thread scheduling; it is not pure decode CPU time. Texture creation includes driver work, not GPU execution. Reset excludes request latency for requests already pending. Six fixed stage keys, at most two combined loader/validation items, no sample history."}


func _demand_rank(id: Vector2i) -> int:
	var rank := desired.find(id)
	return rank if rank >= 0 else MAX_CHUNKS


func suspend() -> bool:
	# Called once per non-campus frame. Never starts, blocks, validates pixels
	# or uploads; cached textures remain available for a later same-view return.
	suspended = true
	required.clear()
	desired.clear()
	prefetched.clear()
	queue.clear()
	_request_rect = Rect2()
	_prefetch_rect = Rect2()
	for id: Vector2i in _validation_jobs.keys(): _discard_validation(id)
	_drain_ready()
	return pending.is_empty()


func _drain_ready() -> void:
	for id: Vector2i in pending.keys():
		if _validation_jobs.has(id):
			_discard_validation(id)
			continue
		var path: String = pending[id]
		var request_status := _request_status(path)
		if request_status == ResourceLoader.THREAD_LOAD_LOADED:
			_take_ready(path)
			pending.erase(id)
			_request_started_usec.erase(id)
		elif request_status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			pending.erase(id)
			_request_started_usec.erase(id)
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
	prefetched.clear()
	queue.clear()
	_request_rect = Rect2()
	_prefetch_rect = Rect2()
	# These items already consumed their ResourceLoader token. Discard only
	# detached validation resources; collecting them again would wait on an
	# unrelated or nonexistent loader request for the same path.
	for id: Vector2i in _validation_jobs.keys(): _discard_validation(id)
	for id: Vector2i in pending.keys():
		var path: String = pending[id]
		if _request_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_finish_request(path)
		pending.erase(id)
		_request_started_usec.erase(id)
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
	var prefetch_ready := 0
	for id: Vector2i in prefetched:
		if textures.has(id): prefetch_ready += 1
	var validation_image_bytes := _validation_image_bytes()
	return {"ready": ready, "required": required.size(), "pending": pending.size(), "queued": queue.size(), "resident": textures.size(), "bytes": cache_bytes, "uploads": uploads, "requests": requests, "suspended": suspended, "closed": closed, "error": _stream_error,
		"prefetch_required": prefetched.size(), "prefetch_ready": prefetch_ready, "prefetch_byte_limit": MAX_PREFETCH_BYTES,
		"pump_usec": last_pump_usec, "pump_bytes": last_pump_bytes, "pump_time_target_usec": MAX_PUMP_USEC, "pump_byte_limit": MAX_UPLOAD_BYTES, "budget_yields": budget_yields,
		"decode_pending": pending.size() - _validation_jobs.size(), "validation_pending": _validation_jobs.size(),
		"validation_buffer_bytes": validation_buffer_bytes, "validation_image_bytes": validation_image_bytes,
		"validation_logical_bytes": validation_buffer_bytes + validation_image_bytes, "validation_peak_logical_bytes": validation_peak_logical_bytes,
		"validation_started": validation_started, "validation_completed": validation_completed, "validation_updates": validation_updates,
		"pump_validation_bytes": last_pump_validation_bytes, "validation_chunk_bytes": VALIDATION_CHUNK_BYTES, "validation_byte_limit": MAX_VALIDATION_BYTES,
		"profile": profile_status() if profile_enabled else null}


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
	var upload_started := _clock_usec() if profile_enabled else 0
	textures[id] = ImageTexture.create_from_image(image)
	_record_profile(&"texture_creation", upload_started)
	order.append(id)
	# Validation established mip-free RGBA8 and the exact upload bytes, either
	# through the detached incremental snapshot or synchronous tooling check.
	# Do not copy the full pixel buffer again merely for accounting.
	cache_bytes += image.get_width() * image.get_height() * 4
	uploads += 1
	_trim()


func _trim() -> void:
	var trim_started := _clock_usec() if profile_enabled else 0
	var limit := mini(MAX_CHUNKS, maxi(BASE_RESIDENT, desired.size()))
	for id: Vector2i in order.duplicate():
		if textures.size() <= limit: break
		if desired.has(id): continue
		var texture: Texture2D = textures[id]
		cache_bytes -= texture.get_width() * texture.get_height() * 4
		textures.erase(id)
		order.erase(id)
	_record_profile(&"retention_trim", trim_started)


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
