extends FluxTestSuite
## Real task ownership and exact bytes with deterministic loader/clock controls.
## Polling below is test-only; it does not qualify native throughput or frame time.
const Stream = preload("res://src/presentation/wellspring_async_terrain_stream.gd")
const Job = preload("res://src/presentation/terrain_hash_job.gd")
const Fixtures = preload("res://tests/unit/test_wellspring_terrain_stream.gd")
const VIEW := Rect2(48, 48, 160, 160)
const FAR := Rect2(5100, 4400, 160, 160)

class Gate extends RefCounted:
	var job: Job
	var semaphore := Semaphore.new()
	var released := false # Main-thread only.
	func _init(value: Job) -> void: job=value
	func run() -> void:
		semaphore.wait()
		job.run()
	func release() -> void:
		if not released:
			released=true
			semaphore.post()

class Probe extends Stream:
	var allow_ready := false
	var hold_workers := true
	var fail_join_once := false
	var corrupt_byte := -1
	var clock_offset := 0
	var retrieval_extra_usec := 0
	var starts: Dictionary[String, int] = {}
	var gets: Dictionary[String, int] = {}
	var finishes: Dictionary[String, int] = {}
	var images: Dictionary[String, Image] = {}
	var gates: Array[Gate] = []
	var submitted: Array[int] = []
	var actual_joins: Dictionary[int, int] = {}
	var join_attempts := 0
	var polls_after_join := 0
	var premature_gets := 0
	func _clock_usec() -> int: return clock_offset
	func _start_request(path: String) -> Error:
		starts[path]=int(starts.get(path,0))+1
		return OK
	func _request_status(_path: String) -> int:
		return ResourceLoader.THREAD_LOAD_LOADED if allow_ready else ResourceLoader.THREAD_LOAD_IN_PROGRESS
	func _take_ready(path: String) -> Image:
		if not allow_ready: premature_gets+=1
		gets[path]=int(gets.get(path,0))+1
		clock_offset+=retrieval_extra_usec
		var height := 256 if path.ends_with("_10.res") else 512
		var image := Image.create(512,height,false,Image.FORMAT_RGBA8)
		image.fill(Color(0.25,0.5,0.75,1.0))
		if corrupt_byte>=0:
			var bytes := image.get_data()
			bytes[mini(corrupt_byte,bytes.size()-1)]^=255
			image.set_data(512,height,false,Image.FORMAT_RGBA8,bytes)
		images[path]=image
		return image
	func _finish_request(path: String) -> void:
		finishes[path]=int(finishes.get(path,0))+1
	func _start_hash_task(worker: Job) -> int:
		var task := -1
		if hold_workers:
			var gate := Gate.new(worker)
			gates.append(gate)
			task=WorkerThreadPool.add_task(gate.run,false,"Bounded terrain ownership gate")
		else:
			task=super._start_hash_task(worker)
		submitted.append(task)
		return task
	func _hash_task_completed(task: int) -> bool:
		if actual_joins.has(task):
			polls_after_join+=1
			return false
		return super._hash_task_completed(task)
	func _join_hash_task(task: int) -> Error:
		join_attempts+=1
		if fail_join_once:
			fail_join_once=false
			return ERR_BUSY # Explicit non-disposing join failure control only.
		actual_joins[task]=int(actual_joins.get(task,0))+1
		return super._join_hash_task(task)
	func release_gates() -> void:
		hold_workers=false
		for gate: Gate in gates: gate.release()
		gates.clear()

var owned: Array[Probe] = []
var cases: Array[Dictionary] = []
var document: Dictionary = {}

func run() -> int:
	document = Fixtures.new()._fixture()
	_run_cases()
	# Always release every semaphore before waiting, including failed cases.
	for stream: Probe in owned:
		stream.release_gates()
		stream.finish_shutdown()
		_check(stream.pending.is_empty() and stream._jobs.is_empty(), "Suite teardown retains no task or loader token")
	return finish("wellspring-async-terrain-stream")

func _run_cases() -> void:
	if not _detached_pixels(VIEW,"full"): return
	if not _detached_pixels(Rect2(48,5184,160,128),"cropped"): return
	for offset: int in [0,512*512*2,512*512*4-1]:
		if not _wrong_digest(offset): return
	if not _cancel_reentry(): return
	if not _suspension(): return
	if not _metadata_mutation(): return
	if not _retrieval_overrun(): return
	if not _join_retry(): return
	if not _check(cases.size() == 10, "Every original real-worker lifecycle case completed"): return
	_test_default_profile()
	_test_kit_selection_and_sync_tooling()

func _new(view: Rect2=VIEW) -> Probe:
	var stream := Probe.new()
	owned.append(stream)
	stream.profile_enabled=true
	if not _check(stream.configure(document,"a".repeat(64),Vector2i(6144,5376)),"Original complete manifest admitted"): return null
	stream.request_view(view)
	if not _check(stream.pump()==0 and stream.pending.size()==2,"Initial pump owns two loader tokens only"): return null
	stream.allow_ready=true
	return stream

func _blocked(stream: Probe) -> bool:
	for frame: int in 16:
		stream.pump()
		if int(stream.status().active_hash_tasks)==2: break
	return _check(int(stream.status().active_hash_tasks)==2 and stream.uploads==0
		and stream.pending.size()==2 and not stream.ready_for(stream._request_rect),
		"Real submitted but gated workers retain both slots without publication")

func _bounds(stream: Probe) -> bool:
	var s := stream.status()
	return _check(int(s.decode_pending)+int(s.validation_pending)==stream.pending.size()
		and stream.pending.size()<=2 and int(s.active_hash_tasks)<=2
		and int(s.validation_logical_bytes)<=2*512*512*4
		and int(s.peak_stored_validation_bytes)<=2*512*512*4
		and int(s.peak_transient_validation_bytes)<=3*512*512*4
		and stream.last_pump_bytes<=Stream.MAX_UPLOAD_BYTES,
		"Two combined owners and explicit logical/upload bounds hold")

func _drain(stream: Probe, expect_error: bool=false) -> bool:
	# The synchronous suite runner cannot SceneTree frames. Only this
	# test polling yields the calling thread; production pump never sleeps.
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		stream.pump()
		if not _bounds(stream): return false
		if expect_error and not stream._stream_error.is_empty(): return true
		if stream.pending.is_empty() and stream.queue.is_empty(): return not expect_error
		OS.delay_usec(1000)
	return _check(false,"Finite worker drain completes within five seconds")

func _detached_pixels(view: Rect2,label: String) -> bool:
	var stream := _new(view)
	if stream==null or not _blocked(stream): return false
	var required_id: Vector2i=stream.required[0]
	if not _check(stream._jobs.has(required_id) and int(stream._jobs[required_id].phase)==Stream.HASHING,
		"Required full/cropped tile has detached actual worker bytes"): return false
	for image: Image in stream.images.values(): image.fill(Color.BLACK)
	stream.release_gates()
	if not _drain(stream): return false
	if not _check(stream.ready_for(view) and stream._stream_error.is_empty(),"Joined digest gates exact required readiness"): return false
	for id: Vector2i in stream.textures:
		var image: Image=stream.textures[id].get_image()
		if not _check(image!=null and Stream.pixel_hash(image)==String(stream.records[id].rgba_sha256),
			"Uploaded pixels match original manifest despite external Image mutation"): return false
	if label=="cropped" and not _check(stream.textures[required_id].get_height()==256,"Actual cropped512x256 texture"): return false
	var profile: Dictionary = stream.profile_status()
	if not _check(profile.backend == "worker_sha256_v1"
		and int(profile.calls.get("byte_snapshot",0)) == stream._tasks_started
		and not profile.calls.has("pixel_validation")
		and int(profile.worker_measured_completions) == stream._tasks_joined,
		"Main-thread byte snapshots and joined worker hash samples remain separately named and counted"): return false
	var retained_calls: Dictionary = profile.calls.duplicate()
	profile.calls.clear()
	if not _check(stream.profile_status().calls == retained_calls,"Caller cannot mutate the retained profiling counters"): return false
	var before: Dictionary=stream.status()
	stream.pump()
	if not _check(stream.requests==int(before.requests) and stream._tasks_started==int(before.tasks_started),"Warm unchanged view starts no new load/hash"): return false
	return _close(stream,label)

func _wrong_digest(offset: int) -> bool:
	var stream := _new()
	if stream==null: return false
	stream.corrupt_byte=offset
	stream.hold_workers=false
	if not _drain(stream,true): return false
	if not _check(stream.uploads==0 and not stream.ready_for(VIEW)
		and stream._stream_error.contains("pixel validation failed"),"Wrong first/middle/last byte fails closed"): return false
	return _close(stream,"corrupt_%d"%offset)

func _cancel_reentry() -> bool:
	var stream := _new()
	if stream==null: return false
	stream.corrupt_byte=0 # Obsolete bad payload must never become fresh readiness.
	if not _blocked(stream): return false
	var generation: int=stream.status().worker_generation
	if not _check(not stream.configure(document,"a".repeat(64),Vector2i(6144,5376))
		and stream._stream_error.is_empty() and int(stream.status().worker_generation)==generation,
		"Busy reconfigure refuses without discarding or poisoning healthy owners"): return false
	stream.request_view(FAR)
	stream.request_view(VIEW)
	stream.pump()
	if not _check(stream.pending.size()==2 and stream._cancelled.size()==2 and stream.requests==2
		and stream._tasks_joined==0 and int(stream.status().obsolete_worker_wait_pumps)>0,
		"Superseded running jobs retain slots and sticky cancellation on same-ID return"): return false
	stream.corrupt_byte=-1
	stream.release_gates()
	if not _drain(stream): return false
	var path: String=stream.records[Vector2i.ZERO].path
	if not _check(stream.ready_for(VIEW) and stream._stream_error.is_empty()
		and int(stream.starts.get(path,0))==2 and stream._discarded_jobs>=2,
		"Reentry publishes only a newly requested valid owner after obsolete join"): return false
	return _close(stream,"cancel_reentry")

func _suspension() -> bool:
	var stream := _new()
	if stream==null or not _blocked(stream): return false
	if not _check(not stream.suspend() and stream.pending.size()==2 and stream._tasks_joined==0,
		"Suspend does not wait for gated running tasks"): return false
	stream.release_gates()
	if not _drain(stream): return false
	if not _check(stream.uploads==0 and stream._tasks_started==stream._tasks_joined,
		"Suspended completion joins and discards without upload"): return false
	var generation: int=stream.status().worker_generation
	if not _check(stream.configure(document,"a".repeat(64),Vector2i(6144,5376))
		and int(stream.status().worker_generation)==generation+1 and stream.pending.is_empty(),
		"After all joins a fresh configuration may replace the generation"): return false
	return _close(stream,"suspend_reconfigure")

func _retrieval_overrun() -> bool:
	var stream := _new()
	if stream==null: return false
	stream.retrieval_extra_usec=3000
	stream.pump()
	if not _check(stream._jobs.size()==1 and stream._tasks_started==0 and stream.uploads==0,
		"Retrieval overrun keeps collected image but starts no hash or upload"): return false
	return _close(stream,"retrieval_overrun_shutdown")

func _metadata_mutation() -> bool:
	var stream := _new()
	if stream==null or not _blocked(stream): return false
	stream.records[Vector2i.ZERO].rgba_sha256="b".repeat(64)
	stream.pump()
	if not _check(stream.uploads==0 and not stream.ready_for(VIEW)
		and stream._stream_error.contains("metadata changed"),"Changed manifest pins cannot publish an existing worker result"): return false
	return _close(stream,"metadata_changed_while_hashing")

func _join_retry() -> bool:
	var stream := _new()
	if stream==null or not _blocked(stream): return false
	stream.release_gates()
	stream.fail_join_once=true
	stream.finish_shutdown()
	if not _check(stream.closed and stream.pending.size()==1 and stream._tasks_joined==1
		and stream._stream_error.contains("join failed"),"Non-disposing join failure retains exact task owner for retry"): return false
	return _close(stream,"non_disposing_join_retry")

func _close(stream: Probe,label: String) -> bool:
	stream.release_gates()
	stream.finish_shutdown()
	if not _check(stream.pending.is_empty() and stream._jobs.is_empty()
		and stream._tasks_started==stream._tasks_joined and stream.polls_after_join==0
		and stream.actual_joins.size()==stream.submitted.size() and stream.premature_gets==0,
		"Final close has no unjoined tasks, duplicate polls or premature gets"): return false
	for task: int in stream.actual_joins:
		if not _check(int(stream.actual_joins[task])==1,"Each submitted actual worker is joined once"): return false
	for path: String in stream.starts:
		if not _check(int(stream.gets.get(path,0))+int(stream.finishes.get(path,0))==int(stream.starts[path]),
			"Each synthetic loader token is collected exactly once"): return false
	cases.append({"label":label,"status":stream.status(),"join_attempts":stream.join_attempts,
		"actual_join_calls":stream.actual_joins.size(),"loader_requests":stream.starts.duplicate(),
		"loader_gets":stream.gets.duplicate(),"loader_finalizations":stream.finishes.duplicate()})
	return true

func _test_default_profile() -> void:
	var stream := Probe.new()
	owned.append(stream)
	if not _check(stream.configure(document,"a".repeat(64),Vector2i(6144,5376)),"Default-profile fixture configures"): return
	_check(not stream.profile_enabled and stream.status().profile == null,"Detailed worker profiling stays off by default")
	stream.allow_ready = true
	stream.hold_workers = false
	stream.request_view(VIEW)
	if not _drain(stream): return
	var profile: Dictionary = stream.profile_status()
	_check(profile.backend == "worker_sha256_v1" and stream.status().validation_backend == "worker_sha256_v1","Production backend is explicit in status and profile")
	_check(profile.calls.is_empty() and profile.elapsed_usec.is_empty() and int(profile.worker_elapsed_usec) == 0 and int(profile.worker_measured_completions) == 0,"Disabled profiling adds no stage or worker elapsed samples")
	_check(stream._tasks_started > 0 and stream._tasks_started == stream._tasks_joined,"Default path still performs and joins genuine validation work")
	var before := [stream.pending.duplicate(),stream.queue.duplicate(),stream.textures.keys(),stream.requests,stream.uploads,stream._tasks_started,stream._tasks_joined]
	stream.reset_profile()
	_check(before == [stream.pending,stream.queue,stream.textures.keys(),stream.requests,stream.uploads,stream._tasks_started,stream._tasks_joined],"Profile reset cannot change owners, demand, residency or task totals")
	_close(stream,"default_profile")

func _test_kit_selection_and_sync_tooling() -> void:
	var layout := SanctumCampusLayout.new()
	if not _check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"),"Actual production campus loads"): return
	var kit := WellspringIllustratedKit.new()
	if not _check(kit.configure(layout),"Actual prebaked kit configures"):
		kit.finish_ground_shutdown()
		return
	var stream: RefCounted = kit.terrain_stream
	if not _check(stream != null and stream.get_script() == Stream,"Production kit selects the reviewed async stream"):
		kit.finish_ground_shutdown()
		return
	_check(not stream.profile_enabled and stream.status().profile == null,"Kit construction preserves the default-off observer")
	var texture: Texture2D = kit.ground_chunk(Vector2i.ZERO)
	_check(texture != null,"Inherited explicit synchronous tooling still loads a real chunk")
	if texture != null:
		_check(Stream.valid_image(texture.get_image(),stream.records[Vector2i.ZERO]),"Synchronous tooling preserves exact manifest pixels")
	_check(stream._tasks_started == 0 and stream.requests == 0,"Synchronous tooling neither queues loaders nor starts worker tasks")
	kit.request_ground_view(Rect2(1024,1024,512,512))
	var pending_before: Dictionary = stream.pending.duplicate()
	_check(not pending_before.is_empty(),"Ordinary kit request owns real async loader tokens")
	if not pending_before.is_empty():
		var id: Vector2i = pending_before.keys()[0]
		_check(stream.load_immediate(id) == null and stream.pending == pending_before,"Synchronous tooling cannot collect an already owned async token")
	kit.finish_ground_shutdown()
	_check(stream.closed and stream.pending.is_empty() and stream._jobs.is_empty() and stream._tasks_started == stream._tasks_joined,"Kit shutdown releases every loader and worker owner")
	_check(kit.ground_chunks.is_empty() and kit.ground_cache_bytes == 0,"Kit cache aliases release after shutdown")

func _check(condition: bool, message: String) -> bool:
	check(condition,message)
	return condition
