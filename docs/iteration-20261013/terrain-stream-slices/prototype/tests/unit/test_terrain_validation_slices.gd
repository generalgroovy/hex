extends FluxTestSuite
## Exact bytes must survive bounded multi-frame validation and owner changes.

const Stream = preload("res://src/presentation/wellspring_terrain_stream.gd")
const Fixtures = preload("res://tests/unit/test_wellspring_terrain_stream.gd")
const VIEW := Rect2(48, 48, 160, 160)
const FAR := Rect2(5100, 4400, 160, 160)

class SliceProbe:
	extends "res://src/presentation/wellspring_terrain_stream.gd"
	var allow_ready := false
	var clock_usec := 0
	var clock_step := 0
	var retrieval_delay := 0
	var corrupt_byte := -1
	var original_images: Dictionary[String, Image] = {}
	var gets: Array[String] = []
	var waits: Array[String] = []
	var starts: Array[String] = []
	var premature_gets := 0
	func _clock_usec() -> int:
		var value := clock_usec
		clock_usec += clock_step
		return value
	func _start_request(path: String) -> Error:
		starts.append(path)
		return OK
	func _request_status(_path: String) -> int:
		return ResourceLoader.THREAD_LOAD_LOADED if allow_ready else ResourceLoader.THREAD_LOAD_IN_PROGRESS
	func _take_ready(path: String) -> Image:
		if not allow_ready: premature_gets += 1
		gets.append(path)
		clock_usec += retrieval_delay
		var height := 256 if path.ends_with("_10.res") else 512
		var image := Image.create(512, height, false, Image.FORMAT_RGBA8)
		image.fill(Color(0.25, 0.5, 0.75, 1.0))
		if corrupt_byte >= 0:
			var bytes := image.get_data()
			bytes[mini(corrupt_byte, bytes.size() - 1)] ^= 255
			image.set_data(512, height, false, Image.FORMAT_RGBA8, bytes)
		original_images[path] = image
		return image
	func _finish_request(path: String) -> void:
		waits.append(path)


func run() -> int:
	_sliced_completion_and_detached_bytes()
	_cropped_edge()
	_corruption_at_different_offsets()
	_owned_validation_lifecycle()
	_retrieval_overrun_boundary()
	return finish("terrain-validation-slices")


func _new_stream(view: Rect2 = VIEW) -> SliceProbe:
	var stream := SliceProbe.new()
	check(stream.configure(Fixtures.new()._fixture(), "a".repeat(64), Vector2i(6144, 5376)), "slice fixture owns complete bounded inventory")
	stream.request_view(view)
	equal(stream.pump(), 0, "initial pump starts only real owned tokens")
	equal(stream.pending.size(), 2, "decode and validation share the original two-job ceiling")
	stream.allow_ready = true
	stream.clock_step = 100
	return stream


func _partial(stream: SliceProbe, view: Rect2 = VIEW) -> void:
	for frame: int in 80:
		stream.pump(2, 800)
		if int(stream.status().validation_buffer_bytes) > 0 and int(stream.status().validation_updates) > 0:
			break
	check(int(stream.status().validation_buffer_bytes) > 0 and int(stream.status().validation_updates) > 0, "clock-limited pump reaches a genuine partial SHA-256 state")
	check(not stream.ready_for(view) and stream.uploads == 0, "partial digest never advertises readiness or publishes a texture")
	check(stream.pending.size() <= 2 and stream.pending.size() > 0, "collected validation keeps its ownership slot")


func _bounded_status(stream: SliceProbe) -> void:
	var status := stream.status()
	equal(int(status.decode_pending) + int(status.validation_pending), stream.pending.size(), "every owned job belongs to exactly one lifecycle phase")
	check(stream.pending.size() <= 2, "decode plus hashing never exceed two owners")
	check(int(status.pump_validation_bytes) <= Stream.MAX_VALIDATION_BYTES, "each pump retains the strict aggregate hashing byte bound")
	equal(int(status.validation_chunk_bytes), 32768, "individual hash updates retain the measured 32 KiB bound")
	check(int(status.validation_logical_bytes) <= 2 * 512 * 512 * 4, "at a pump boundary each of two jobs retains only its image or byte representation")
	check(int(status.validation_peak_logical_bytes) <= 3 * 512 * 512 * 4, "one indivisible copy can transiently overlap one extra logical tile payload")
	check(stream.last_pump_bytes <= Stream.MAX_UPLOAD_BYTES, "published texture bytes remain independently bounded")


func _sliced_completion_and_detached_bytes() -> void:
	var stream := _new_stream()
	_partial(stream)
	var path: String = stream.records[Vector2i.ZERO].path
	check(stream.original_images.has(path), "required first tile was actually retrieved")
	if stream.original_images.has(path):
		stream.original_images[path].fill(Color.BLACK)
	var previous_uploads := 0
	for frame: int in 240:
		var uploaded := stream.pump(2, 800)
		check(uploaded <= 2 and stream.uploads - previous_uploads <= 2, "split work never bypasses the upload-count cap")
		previous_uploads = stream.uploads
		_bounded_status(stream)
		if stream.queue.is_empty() and stream.pending.is_empty(): break
	check(stream.ready_for(VIEW), "finite sliced work eventually completes exact required pixels")
	check(stream.pending.is_empty(), "completed validation releases all owned slots")
	if stream.textures.has(Vector2i.ZERO):
		equal(Stream.pixel_hash(stream.textures[Vector2i.ZERO].get_image()), String(stream.records[Vector2i.ZERO].rgba_sha256), "upload comes from verified detached bytes despite external Image mutation")
	for retrieved: String in stream.gets:
		equal(stream.gets.count(retrieved), 1, "a collected ResourceLoader token is never retrieved twice")
	var requests := stream.requests
	var validations: int = stream.status().validation_started
	stream.clock_step = 0
	for frame: int in 8:
		stream.request_view(VIEW)
		stream.pump()
	equal(stream.requests, requests, "stable warm view starts no redundant decode")
	equal(int(stream.status().validation_started), validations, "stable warm view repeats no pixel validation")
	equal(stream.premature_gets, 0, "no gameplay retrieval precedes ready status")
	stream.finish_shutdown()
	equal(int(stream.status().validation_logical_bytes), 0, "final close releases retained validation buffers")


func _cropped_edge() -> void:
	var view := Rect2(5632, 5120, 512, 256)
	var stream := _new_stream(view)
	_partial(stream, view)
	for frame: int in 240:
		stream.pump(1, 800, 512 * 256 * 4)
		_bounded_status(stream)
		check(stream.last_pump_bytes <= 512 * 256 * 4, "cropped edge retains its exact half-tile upload budget")
		if stream.ready_for(view): break
	check(stream.ready_for(view), "southeast half-height tile completes sliced validation")
	if stream.textures.has(Vector2i(11, 10)):
		var image: Image = stream.textures[Vector2i(11, 10)].get_image()
		equal(image.get_size(), Vector2i(512, 256), "partial edge never pads beyond authored native dimensions")
		equal(Stream.pixel_hash(image), String(stream.records[Vector2i(11, 10)].rgba_sha256), "cropped native bytes pass the same exact digest")
		equal(stream.cache_bytes, 512 * 256 * 4, "first cropped upload accounts its actual 512 KiB residency")
	stream.finish_shutdown()


func _corruption_at_different_offsets() -> void:
	for offset: int in [0, 512 * 512 * 2, 512 * 512 * 4 - 1]:
		var stream := _new_stream()
		stream.corrupt_byte = offset
		for frame: int in 240:
			stream.pump(2, 800)
			_bounded_status(stream)
			if not String(stream.status().error).is_empty(): break
		check(not String(stream.status().error).is_empty(), "corruption at byte%d refuses exact final digest" % offset)
		check(stream.uploads == 0 and not stream.ready_for(VIEW), "no corrupt slice can publish before complete validation")
		stream.finish_shutdown()
		equal(int(stream.status().validation_pending), 0, "failed validation is releasable without leaked jobs")


func _owned_validation_lifecycle() -> void:
	for action: String in ["obsolete", "suspend", "shutdown"]:
		var stream := _new_stream()
		_partial(stream)
		var collected := stream.gets.duplicate()
		var owned := stream.pending.duplicate()
		check(not stream.configure({}, "bad", Vector2i.ONE), "partial validation refuses replacement before losing ownership")
		equal(stream.pending, owned, "rejected replacement retains every collected and uncollected job")
		check(String(stream.status().error).is_empty(), "rejected replacement cannot poison healthy validation")
		match action:
			"obsolete":
				stream.request_view(FAR)
				check(not stream.pending.has(Vector2i.ZERO), "obsolete collected job is cancelled without a second get")
				stream.suspend()
			"suspend": stream.suspend()
			"shutdown": stream.finish_shutdown()
		stream.finish_shutdown()
		for path: String in collected:
			equal(stream.gets.count(path), 1, action + " cannot collect an already consumed token twice")
			check(not stream.waits.has(path), action + " teardown never waits on a token already retrieved for validation")
		check(stream.pending.is_empty() and int(stream.status().validation_logical_bytes) == 0, action + " clears bounded validation ownership")
		equal(stream.uploads, 0, action + " cannot publish abandoned partial pixels")
		var final_waits := stream.waits.duplicate()
		stream.finish_shutdown()
		equal(stream.waits, final_waits, action + " final close remains idempotent")


func _retrieval_overrun_boundary() -> void:
	var stream := _new_stream()
	stream.clock_step = 0
	stream.retrieval_delay = Stream.MAX_PUMP_USEC + 1
	equal(stream.pump(), 0, "over-budget retrieval stops before new hash or upload work")
	equal(stream.gets.size(), 1, "the next ready token waits after one native overrun")
	check(stream.last_pump_usec > Stream.MAX_PUMP_USEC, "actual indivisible overrun is reported honestly")
	check(not stream.ready_for(VIEW) and stream.pending.size() == 2, "retrieved unverified image retains its slot without false readiness")
	stream.retrieval_delay = 0
	stream.pump()
	check(stream.ready_for(VIEW), "subsequent budget resumes the same collected image")
	stream.finish_shutdown()
