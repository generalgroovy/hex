extends "res://src/presentation/wellspring_terrain_stream.gd"
## Exact terrain validation on bounded worker tasks. Images, residency and
## rendering remain owned by the main thread.
## The inherited loader, admission, residency and synchronous tooling paths stay
## intact. Only asynchronous pump validation uses a separately owned hash task.

const HashJob = preload("res://src/presentation/terrain_hash_job.gd")
const VALIDATION_BACKEND := "worker_sha256_v1"
# Additive provenance for the asynchronous runtime selection; the base tooling
# inventory stays intact and the output manifest is deliberately absent.
const VALIDATION_SOURCE_PATHS: Array[String] = [
	"res://src/presentation/wellspring_async_terrain_stream.gd",
	"res://src/presentation/terrain_hash_job.gd",
]
const COLLECTED := 0
const HASHING := 1
const VERIFIED := 2
const UPLOAD_READY := 3
const WORKER_PROFILE_STAGES := [&"ready_retrieval", &"byte_snapshot",
	&"worker_dispatch", &"worker_collection", &"image_reconstruction",
	&"texture_creation", &"retention_trim", &"request_submission"]

# pending retains the original combined ownership ceiling. A loader token is
# represented by pending alone; only a collected token gains a _jobs record.
var _jobs: Dictionary[Vector2i, Dictionary] = {}
var _cancelled: Dictionary[Vector2i, bool] = {}
var _generation := 0
var _pump_serial := 0
var _tasks_started := 0
var _tasks_joined := 0
var _worker_wait_pumps := 0
var _obsolete_worker_wait_pumps := 0
var _discarded_jobs := 0
var _peak_combined_owners := 0
var _peak_stored_validation_bytes := 0
var _peak_transient_validation_bytes := 0
var _worker_elapsed_usec := 0
var _worker_maximum_usec := 0
var _worker_measured_completions := 0


func configure(document: Dictionary, expected_signature: String, expected_canvas: Vector2i) -> bool:
	if not pending.is_empty() or not _jobs.is_empty():
		last_error = "Terrain stream cannot reconfigure in flight"
		return false
	_generation += 1
	_cancelled.clear()
	_pump_serial = 0
	_tasks_started = 0
	_tasks_joined = 0
	_worker_wait_pumps = 0
	_obsolete_worker_wait_pumps = 0
	_discarded_jobs = 0
	_peak_combined_owners = 0
	_peak_stored_validation_bytes = 0
	_peak_transient_validation_bytes = 0
	return super.configure(document, expected_signature, expected_canvas)


func _rebuild_demand() -> void:
	super._rebuild_demand()
	for id: Vector2i in pending:
		# Cancellation is sticky until this exact owner is collected. A quick
		# return to the same ID queues a new request after the obsolete join.
		if not desired.has(id): _cancelled[id] = true


func pump(upload_budget: int = MAX_UPLOADS, time_budget_usec: int = MAX_PUMP_USEC, byte_budget: int = MAX_UPLOAD_BYTES) -> int:
	last_pump_usec = 0
	last_pump_bytes = 0
	if closed: return 0
	_pump_serial += 1
	if suspended or not _stream_error.is_empty():
		_drain_ready()
		return 0
	var budget := clampi(upload_budget, 0, MAX_UPLOADS)
	var usec_limit := clampi(time_budget_usec, 0, MAX_PUMP_USEC)
	var byte_limit := clampi(byte_budget, 0, MAX_UPLOAD_BYTES)
	if budget == 0 or usec_limit == 0 or byte_limit == 0: return 0
	var started := _clock_usec()
	var completed := 0
	var admission_order: Array = pending.keys()
	admission_order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _demand_rank(a) < _demand_rank(b))
	for id: Vector2i in admission_order:
		if completed >= budget or not _within_budget(started, usec_limit): break
		if not _jobs.has(id):
			var path: String = pending[id]
			var state := _request_status(path)
			if state == ResourceLoader.THREAD_LOAD_IN_PROGRESS: continue
			if state != ResourceLoader.THREAD_LOAD_LOADED:
				if state == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE: _release_owner(id)
				_fail("Unable to decode prepared terrain: " + path)
				break
			if not records.has(id):
				_fail("Prepared terrain metadata removed while loading: " + path)
				break
			var bytes := int(records[id].size[0]) * int(records[id].size[1]) * 4
			if desired.has(id) and last_pump_bytes + bytes > byte_limit:
				budget_yields += 1
				continue
			_collect_ready_loader(id, path)
			if not _stream_error.is_empty(): break
			if not _jobs.has(id): continue
		if _advance_job(id, started, usec_limit, byte_limit): completed += 1
		if not _stream_error.is_empty(): break
	while _stream_error.is_empty() and pending.size() < MAX_PENDING and not queue.is_empty():
		if not _within_budget(started, usec_limit): break
		var id: Vector2i = queue.pop_front()
		if textures.has(id) or pending.has(id) or not desired.has(id): continue
		var path: String = records[id].path
		var request_started := _clock_usec() if profile_enabled else 0
		var request_error := _start_request(path)
		_record_profile(&"request_submission", request_started)
		if request_error != OK:
			_fail("Could not queue prepared terrain: " + path)
			break
		pending[id] = path
		if profile_enabled: _request_started_usec[id] = request_started
		requests += 1
		_peak_combined_owners = maxi(_peak_combined_owners, pending.size())
	last_pump_usec = maxi(0, _clock_usec() - started)
	return completed


func _within_budget(started: int, limit: int) -> bool:
	if _clock_usec() - started < limit: return true
	budget_yields += 1
	return false


func _collect_ready_loader(id: Vector2i, path: String) -> void:
	var started := _clock_usec() if profile_enabled else 0
	if profile_enabled and _request_started_usec.has(id):
		var latency := maxi(0, started - _request_started_usec[id])
		_completed_request_latency_usec += latency
		_maximum_request_latency_usec = maxi(_maximum_request_latency_usec, latency)
		_completed_profiled_requests += 1
	var image := _take_ready(path)
	_record_profile(&"ready_retrieval", started)
	_request_started_usec.erase(id)
	if _cancelled.has(id) or not desired.has(id):
		_release_owner(id)
		return
	var row: Dictionary = records[id]
	var size := Rect2i(id * CHUNK, Vector2i.ONE * CHUNK).intersection(Rect2i(Vector2i.ZERO, canvas_size)).size
	var digest := String(row.get("rgba_sha256", ""))
	if image == null or image.has_mipmaps() or image.get_format() != Image.FORMAT_RGBA8 \
			or image.get_size() != size or row.get("id", []) != [id.x, id.y] \
			or row.get("size", []) != [size.x, size.y] or row.get("path", "") != path \
			or path != ROOT + "/chunk_%02d_%02d.res" % [id.x, id.y] or not _valid_hash(digest):
		_release_owner(id)
		_fail("Prepared terrain pixel metadata failed: " + path)
		return
	_jobs[id] = {"id": id, "phase": COLLECTED, "image": image, "worker": null, "task": -1,
		"path": path, "size": size, "sha256": digest, "generation": _generation,
		"bytes": size.x * size.y * 4, "submitted_pump": -1}
	_track_buffers()


func _advance_job(id: Vector2i, started: int, limit: int, byte_limit: int) -> bool:
	var job: Dictionary = _jobs[id]
	if _cancelled.has(id) or not desired.has(id):
		if int(job.task) >= 0 and not _collect_worker(job, false): return false
		_discarded_jobs += 1
		_release_owner(id)
		return false
	if not _pins_match(id, job):
		_cancelled[id] = true
		_fail("Prepared terrain metadata changed while owned: " + String(job.path))
		return false
	if int(job.phase) == COLLECTED:
		if not _within_budget(started, limit): return false
		if not _detach_and_submit(id, job): return false
	if int(job.phase) == HASHING:
		if not _within_budget(started, limit): return false
		if not _collect_worker(job, false): return false
		if not _stream_error.is_empty(): return false
	if int(job.phase) == VERIFIED:
		if not _within_budget(started, limit): return false
		if not _reconstruct(id, job): return false
	if int(job.phase) != UPLOAD_READY or not _within_budget(started, limit): return false
	if last_pump_bytes + int(job.bytes) > byte_limit:
		budget_yields += 1
		return false
	if not _pins_match(id, job):
		_fail("Prepared terrain metadata changed before publication: " + String(job.path))
		return false
	var image: Image = job.image
	_admit(id, image)
	last_pump_bytes += int(job.bytes)
	_release_owner(id)
	return true


func _detach_and_submit(id: Vector2i, job: Dictionary) -> bool:
	var image: Image = job.image
	var size: Vector2i = job.size
	if image == null or image.get_size() != size or image.has_mipmaps() or image.get_format() != Image.FORMAT_RGBA8:
		_release_owner(id)
		return _fail("Prepared terrain image changed before snapshot")
	var started := _clock_usec() if profile_enabled else 0
	var bytes := image.get_data()
	_record_profile(&"byte_snapshot", started)
	if bytes.size() != int(job.bytes):
		_release_owner(id)
		return _fail("Prepared terrain snapshot has an invalid byte count")
	_track_buffers(bytes.size()) # Original image and detached snapshot overlap.
	var worker := HashJob.new(bytes, profile_enabled)
	job.image = null
	job.worker = worker
	job.phase = HASHING
	job.submitted_pump = _pump_serial
	var dispatch_started := _clock_usec() if profile_enabled else 0
	var task := _start_hash_task(worker)
	_record_profile(&"worker_dispatch", dispatch_started)
	if task < 0:
		_release_owner(id)
		return _fail("Could not submit prepared terrain validation task")
	job.task = task
	_tasks_started += 1
	return true


func _collect_worker(job: Dictionary, final_join: bool) -> bool:
	var task := int(job.task)
	if task < 0: return true
	if not final_join and not _hash_task_completed(task):
		_worker_wait_pumps += 1
		if _cancelled.has(job.id): _obsolete_worker_wait_pumps += 1
		return false
	var started := _clock_usec() if profile_enabled else 0
	var error := _join_hash_task(task)
	_record_profile(&"worker_collection", started)
	# All callers are main-thread. ERR_BUSY cannot arise from nested worker waits.
	# Preserve ownership if an unexpected wait failure has not disposed the task.
	if error != OK:
		if error == ERR_INVALID_PARAMETER: job.task = -1
		_fail("Prepared terrain task join failed: %d" % error)
		return false
	job.task = -1
	_tasks_joined += 1
	var worker: HashJob = job.worker
	var result: Dictionary = worker.joined_result()
	if profile_enabled and bool(result.get("measured", false)):
		var elapsed := int(result.get("elapsed_usec", 0))
		_worker_elapsed_usec += elapsed
		_worker_maximum_usec = maxi(_worker_maximum_usec, elapsed)
		_worker_measured_completions += 1
	if final_join or _cancelled.has(job.id) or suspended or closed or not _stream_error.is_empty(): return true
	if int(result.get("error", FAILED)) != OK or String(result.get("sha256", "")) != String(job.sha256):
		_fail("Prepared terrain pixel validation failed: " + String(job.path))
		return false
	job.phase = VERIFIED
	return true


func _reconstruct(id: Vector2i, job: Dictionary) -> bool:
	var worker: HashJob = job.worker
	var bytes: PackedByteArray = worker.pixels_after_join()
	if bytes.size() != int(job.bytes): return _fail("Joined terrain payload has invalid byte count")
	_track_buffers(bytes.size()) # Exact-byte reconstruction transiently overlaps.
	var size: Vector2i = job.size
	var started := _clock_usec() if profile_enabled else 0
	var image := Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, bytes)
	_record_profile(&"image_reconstruction", started)
	if image == null or image.get_size() != size or image.has_mipmaps() or image.get_format() != Image.FORMAT_RGBA8:
		_release_owner(id)
		return _fail("Could not reconstruct exact verified terrain bytes")
	job.worker = null
	job.image = image
	job.phase = UPLOAD_READY
	return true


func _pins_match(id: Vector2i, job: Dictionary) -> bool:
	if closed or suspended or not _stream_error.is_empty() or _cancelled.has(id) \
			or not desired.has(id) or not pending.has(id) or not records.has(id) \
			or int(job.generation) != _generation or pending[id] != String(job.path): return false
	var row: Dictionary = records[id]
	var size: Vector2i = job.size
	return row.get("id", []) == [id.x, id.y] and row.get("size", []) == [size.x, size.y] \
		and row.get("path", "") == job.path and row.get("rgba_sha256", "") == job.sha256


func _release_owner(id: Vector2i) -> void:
	_jobs.erase(id)
	pending.erase(id)
	_cancelled.erase(id)
	_request_started_usec.erase(id)
	if not closed and not suspended and _stream_error.is_empty() and desired.has(id) \
			and not textures.has(id) and not queue.has(id):
		queue.append(id)
		queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _demand_rank(a) < _demand_rank(b))


func _drain_ready() -> void:
	for id: Vector2i in pending.keys():
		_cancelled[id] = true
		if _jobs.has(id):
			var job: Dictionary = _jobs[id]
			if int(job.task) >= 0 and not _collect_worker(job, false): continue
			_discarded_jobs += 1
			_release_owner(id)
			continue
		var path: String = pending[id]
		var state := _request_status(path)
		if state == ResourceLoader.THREAD_LOAD_LOADED:
			_take_ready(path)
			_release_owner(id)
		elif state == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_release_owner(id)
		elif state == ResourceLoader.THREAD_LOAD_FAILED:
			_fail("Unable to decode prepared terrain: " + path)


func finish_shutdown() -> void:
	if closed and pending.is_empty(): return
	suspended = true
	closed = true
	_generation += 1
	required.clear()
	desired.clear()
	prefetched.clear()
	queue.clear()
	_request_rect = Rect2()
	_prefetch_rect = Rect2()
	for id: Vector2i in pending.keys():
		if _jobs.has(id):
			var job: Dictionary = _jobs[id]
			if int(job.task) >= 0 and not _collect_worker(job, true):
				# An unexpected non-disposing wait error retains its owner for an
				# explicit later teardown retry; never drop a running task handle.
				if int(job.task) >= 0: continue
		else:
			var path: String = pending[id]
			if _request_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE: _finish_request(path)
		_release_owner(id)
	textures.clear()
	order.clear()
	cache_bytes = 0


func _start_hash_task(worker: HashJob) -> int:
	return WorkerThreadPool.add_task(worker.run, false, "H.E.X exact terrain SHA-256")


func _hash_task_completed(task: int) -> bool:
	return WorkerThreadPool.is_task_completed(task)


func _join_hash_task(task: int) -> Error:
	return WorkerThreadPool.wait_for_task_completion(task)


func reset_profile() -> void:
	super.reset_profile()
	_worker_elapsed_usec = 0
	_worker_maximum_usec = 0
	_worker_measured_completions = 0


func _record_profile(stage: StringName, started: int) -> void:
	if not profile_enabled or stage not in WORKER_PROFILE_STAGES: return
	_profile_usec[stage] = int(_profile_usec.get(stage, 0)) + maxi(0, _clock_usec() - started)
	_profile_calls[stage] = int(_profile_calls.get(stage, 0)) + 1


func profile_status() -> Dictionary:
	var result := super.profile_status()
	result["backend"] = VALIDATION_BACKEND
	result["worker_elapsed_usec"] = _worker_elapsed_usec
	result["worker_maximum_usec"] = _worker_maximum_usec
	result["worker_measured_completions"] = _worker_measured_completions
	result["scope"] = "Worker SHA-256 validation. Eight fixed main-thread elapsed interval keys, not thread CPU counters; scheduling and driver waits may be included. byte_snapshot measures obtaining detached Image bytes, not hashing or a guaranteed physical copy. Worker hash elapsed is separately observed and may overlap main work or include descheduling; never add it to a frame total or subtract it as a speedup. Texture creation measures submission, not GPU execution. Normal collection polls then joins completed tasks only; final teardown may wait. Source Image and exact-byte reconstruction remain main-thread. No sample history."
	return result


func _logical_validation_bytes() -> int:
	var count := 0
	for job: Dictionary in _jobs.values(): count += int(job.bytes)
	return count


func _track_buffers(extra_transient: int = 0) -> void:
	var stored := _logical_validation_bytes()
	_peak_stored_validation_bytes = maxi(_peak_stored_validation_bytes, stored)
	_peak_transient_validation_bytes = maxi(_peak_transient_validation_bytes, stored + extra_transient)


func status() -> Dictionary:
	var result := super.status()
	var active_tasks := 0
	for job: Dictionary in _jobs.values():
		if int(job.task) >= 0: active_tasks += 1
	result.merge({"validation_backend": VALIDATION_BACKEND, "worker_generation": _generation,
		"decode_pending": pending.size() - _jobs.size(), "validation_pending": _jobs.size(),
		"active_hash_tasks": active_tasks, "tasks_started": _tasks_started, "tasks_joined": _tasks_joined,
		"worker_wait_pumps": _worker_wait_pumps, "obsolete_worker_wait_pumps": _obsolete_worker_wait_pumps,
		"obsolete_owned": _cancelled.size(), "discarded_validation_jobs": _discarded_jobs,
		"peak_combined_owners": _peak_combined_owners,
		"validation_logical_bytes": _logical_validation_bytes(),
		"peak_stored_validation_bytes": _peak_stored_validation_bytes,
		"peak_transient_validation_bytes": _peak_transient_validation_bytes,
		"memory_scope": "Logical retained validation payloads and conservative Image/copy/reconstruction overlap only; excludes hash context, dictionaries, pool resources, allocator/COW behavior, resident textures and driver memory. Not RSS."})
	return result
