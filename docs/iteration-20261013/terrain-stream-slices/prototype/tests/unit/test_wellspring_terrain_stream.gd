extends FluxTestSuite

const Stream = preload("res://src/presentation/wellspring_terrain_stream.gd")

class LoaderProbe:
	extends "res://src/presentation/wellspring_terrain_stream.gd"
	var allow_completion := false
	var started: Array[String] = []
	var retrieved: Array[String] = []
	var finalized: Array[String] = []
	var statuses: Dictionary[String, int] = {}
	var premature_gets := 0
	var clock_usec := 0
	var retrieval_usec := 0
	func _clock_usec() -> int:
		return clock_usec
	func _start_request(path: String) -> Error:
		started.append(path)
		return OK
	func _request_status(path: String) -> int:
		if statuses.has(path): return statuses[path]
		return ResourceLoader.THREAD_LOAD_LOADED if allow_completion else ResourceLoader.THREAD_LOAD_IN_PROGRESS
	func _take_ready(path: String) -> Image:
		if _request_status(path) != ResourceLoader.THREAD_LOAD_LOADED: premature_gets += 1
		retrieved.append(path)
		clock_usec += retrieval_usec
		var size := Vector2i(512, 256 if path.ends_with("_10.res") else 512)
		var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		image.fill(Color(0.25, 0.5, 0.75, 1.0))
		return image
	func _finish_request(path: String) -> void:
		finalized.append(path)


func run() -> int:
	_test_manifest_and_pixels()
	_test_queue_and_large_views()
	_test_time_bytes_and_destination_prefetch()
	_test_suspend_resume_and_shutdown()
	_test_reconfiguration_ownership()
	_test_profile_stages()
	_test_real_bake_equivalence()
	return finish("wellspring-terrain-stream")


func _test_profile_stages() -> void:
	var stream := LoaderProbe.new()
	check(stream.configure(_fixture(), "a".repeat(64), Vector2i(6144, 5376)), "profile fixture admits the same pixel-validated terrain")
	stream.request_view(Rect2(1024, 1024, 512, 512))
	check(stream.status().profile == null, "production default performs no detailed stage capture")
	stream.profile_enabled = true
	stream.clock_usec = 1000
	stream.pump(1)
	var pending_before := stream.pending.duplicate()
	var queue_before := stream.queue.duplicate()
	stream.reset_profile()
	equal(stream.pending, pending_before, "resetting observation never cancels or changes resource tokens")
	equal(stream.queue, queue_before, "resetting observation cannot reorder demand")
	stream.clock_usec = 9000
	stream.allow_completion = true
	stream.retrieval_usec = 350
	equal(stream.pump(1), 1, "profile mode keeps the ordinary upload count budget")
	var stages := stream.profile_status()
	equal(int(stages.calls.get("ready_retrieval", 0)), 1, "one ready resource retrieval is recorded")
	equal(int(stages.elapsed_usec.get("ready_retrieval", -1)), 350, "retrieval interval is separate from validation, texture creation and trim")
	equal(int(stages.calls.get("pixel_validation", 0)), 1, "exact pixel validation remains measured and mandatory")
	equal(int(stages.calls.get("texture_creation", 0)), 1, "only one admitted texture creation is counted")
	equal(int(stages.completed_profiled_requests), 0, "requests pending before reset never acquire invented decode latency")
	stages.calls.clear()
	check(not stream.profile_status().calls.is_empty(), "caller mutation cannot erase retained timing evidence")
	stream.retrieval_usec = 0
	stream.clock_usec = 12000
	stream.pump(2)
	check(int(stream.profile_status().completed_profiled_requests) >= 1, "a request submitted during capture produces real request-to-observed-ready latency")
	check(int(stream.profile_status().maximum_request_latency_usec) > 0, "request latency retains wall scheduling/poll delay without calling it decode CPU")
	check(stream._request_started_usec.size() <= Stream.MAX_PENDING, "pending timing metadata stays within resource token bound")
	var before_disabled := stream.profile_status()
	stream.profile_enabled = false
	stream.pump(2)
	equal(stream.profile_status().calls, before_disabled.calls, "disabled observer does not collect new stage samples")
	stream.finish_shutdown()
	check(stream._request_started_usec.is_empty(), "final teardown releases pending timing ownership")


func _fixture() -> Dictionary:
	var hashes := {}
	for height: int in [512, 256]:
		var image := Image.create(512, height, false, Image.FORMAT_RGBA8)
		image.fill(Color(0.25, 0.5, 0.75, 1.0))
		hashes[height] = Stream.pixel_hash(image)
	var rows: Array[Dictionary] = []
	for y: int in 11:
		for x: int in 12:
			var height := 256 if y == 10 else 512
			rows.append({"id": [x, y], "size": [512, height], "path": Stream.ROOT + "/chunk_%02d_%02d.res" % [x, y], "rgba_sha256": hashes[height]})
	return {"version": Stream.VERSION, "signature": "a".repeat(64), "canvas": [6144, 5376], "chunk_size": 512, "chunks": rows, "overview": {"path": Stream.ROOT + "/overview.res", "size": [1536, 1344], "rgba_sha256": "b".repeat(64)}}


func _test_manifest_and_pixels() -> void:
	var fixture := _fixture()
	var original := fixture.duplicate(true)
	var stream := Stream.new()
	check(stream.configure(fixture, "a".repeat(64), Vector2i(6144, 5376)), "complete independently authored132-region manifest admits")
	equal(stream.records.size(), 132, "all12 columns and11 rows are represented")
	equal(stream.ids_for(Rect2(512, 512, 512, 512)), [Vector2i(1, 1)], "exact upper boundary cannot request adjacent chunk")
	equal(stream.ids_for(Rect2(-32, -32, 64, 64)), [Vector2i.ZERO], "negative margin clips to actual map")
	equal(stream.ids_for(Rect2(5632, 5120, 512, 256)), [Vector2i(11, 10)], "partial southern edge retains exact native ownership")
	check(stream.ids_for(Rect2(Vector2(NAN, 0), Vector2.ONE)).is_empty(), "nonfinite view cannot schedule resources")
	for mutation: String in ["signature", "version", "missing", "duplicate", "size", "path", "hash", "overview"]:
		var bad := fixture.duplicate(true)
		match mutation:
			"signature": bad.signature = "c".repeat(64)
			"version": bad.version = "old"
			"missing": bad.chunks.pop_back()
			"duplicate": bad.chunks[1] = bad.chunks[0].duplicate(true)
			"size": bad.chunks[131].size = [512, 512]
			"path": bad.chunks[0].path = "res://unrelated.res"
			"hash": bad.chunks[0].rgba_sha256 = "z".repeat(64)
			"overview": bad.overview.size = [6144, 5376]
		check(not stream.configure(bad, "a".repeat(64), Vector2i(6144, 5376)), "stale or malformed bake refuses: " + mutation)
		check(stream.records.is_empty() and stream.textures.is_empty(), "failed admission never retains prior published terrain")
	check(stream.configure(fixture, "a".repeat(64), Vector2i(6144, 5376)), "valid bake readmits after failures")
	fixture.chunks[0].path = "mutated"
	equal(stream.records[Vector2i.ZERO].path, Stream.ROOT + "/chunk_00_00.res", "manifest caller cannot mutate admitted paths")
	var image := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.25, 0.5, 0.75, 1.0))
	check(Stream.valid_image(image, original.chunks[0]), "exact RGBA payload admits")
	image.set_pixel(0, 0, Color.BLACK)
	check(not Stream.valid_image(image, original.chunks[0]), "one changed native pixel rejects before upload")
	check(not Stream.valid_image(null, original.chunks[0]), "missing decoded image refuses")


func _test_queue_and_large_views() -> void:
	var stream := LoaderProbe.new()
	check(stream.configure(_fixture(), "a".repeat(64), Vector2i(6144, 5376)), "stream probe uses complete real-size region inventory")
	# Independent known1920x1080/75% POV envelope:28 tiles exceeded the old24.
	var view := Rect2(896, 896, 2816, 1664)
	stream.request_view(view)
	equal(stream.required.size(), 28, "large legal backdrop keeps all28 native regions rather than an overview")
	check(stream.desired.size() > stream.required.size(), "full512px neighborhood prepares ahead of ordinary movement")
	for id: Vector2i in stream.ids_for(view.grow(512)):
		check(stream.desired.has(id), "every neighboring tile is retained for one full prefetch ring")
	equal(stream.pump(2), 0, "first pump only queues background work")
	equal(stream.pending.size(), 2, "at most two background decodes may be in flight")
	for index: int in 4:
		equal(stream.pump(2), 0, "in-progress decode never blocks by retrieving early")
	equal(stream.retrieved.size(), 0, "get is never called before loaded status")
	stream.allow_completion = true
	for index: int in 80:
		var before: int = stream.uploads
		var count: int = stream.pump(99)
		check(count <= 2 and stream.uploads - before <= 2, "even oversized caller budget cannot exceed two texture uploads")
		check(stream.pending.size() <= 2, "request concurrency remains bounded while draining")
		if stream.pending.is_empty() and stream.queue.is_empty(): break
	check(stream.ready_for(view), "every visible region eventually receives exact native pixels")
	equal(stream.premature_gets, 0, "no hidden blocking get occurred")
	check(stream.textures.size() <= stream.desired.size() and stream.cache_bytes <= Stream.MAX_BYTES, "viewport-pinned cache stays inside finite world byte budget")
	var uploads: int = stream.uploads
	var requests: int = stream.requests
	for index: int in 12:
		stream.request_view(view)
		stream.pump(2)
		check(stream.ready_for(view), "stable large view remains complete")
	equal(stream.uploads, uploads, "stable large view cannot cyclically evict and reupload itself")
	equal(stream.requests, requests, "stable large view schedules no redundant disk decode")
	var destination := Rect2(5000, 4400, 1000, 800)
	stream.allow_completion = false
	stream.request_view(destination)
	stream.pump(2)
	var pending_before: int = stream.pending.size()
	check(pending_before > 0 and not stream.ready_for(destination), "cold teleport is explicitly unready")
	stream.request_view(Rect2(0, 0, 400, 400))
	stream.allow_completion = true
	var before: int = stream.uploads
	stream.pump(2)
	equal(stream.uploads, before, "superseded destination decodes are drained without stale uploads")
	stream.request_view(Rect2(0, 0, 6144, 5376))
	equal(stream.required.size(), 132, "whole-campus camera request remains exact and finite with no quality fallback")
	equal(stream.desired.size(), 132, "prefetch never extends beyond the world or duplicates native tiles")


func _test_time_bytes_and_destination_prefetch() -> void:
	var stream := LoaderProbe.new()
	check(stream.configure(_fixture(), "a".repeat(64), Vector2i(6144, 5376)), "budget fixture admits exact native inventory")
	var view := Rect2(48, 48, 160, 160)
	var destination := Rect2(4608, 3584, 1536, 1536)
	stream.request_view(view)
	var active_required: Array = stream.required.duplicate()
	var active_desired: Array = stream.desired.duplicate()
	stream.prefetch_view(destination)
	equal(stream.required, active_required, "map highlight never replaces current readiness requirement")
	equal(stream.desired.slice(0, active_desired.size()), active_desired, "current camera and movement halo precede destination jobs")
	equal(stream.requests, 0, "prefetch intent cannot decode or upload inside a draw callback")
	check(not stream.ready_for(destination), "highlight alone makes no destination-ready promise")
	stream.pump()
	stream.allow_completion = true
	stream.retrieval_usec = Stream.MAX_PUMP_USEC + 1
	equal(stream.pump(), 0, "over-budget retrieval yields before validation and texture creation")
	equal(stream.last_pump_usec, Stream.MAX_PUMP_USEC + 1, "actual time overrun remains visible rather than clamped")
	equal(stream.last_pump_bytes, 0, "unverified retrieval cannot spend an upload byte budget")
	equal(stream.requests, 2, "time overrun also prevents another request admission")
	check(stream.budget_yields > 0 and not stream.ready_for(view), "budget yield preserves the unfinished tile's actual readiness")
	stream.retrieval_usec = 0
	equal(stream.pump(1), 1, "next pump resumes the collected image and admits one verified tile")
	check(stream.ready_for(view), "resumed validation publishes exact current pixels")
	var reads: int = stream.retrieved.size()
	equal(stream.pump(2, Stream.MAX_PUMP_USEC, 512 * 512 * 4 - 1), 0, "subtile byte budget cannot exceed limit even for first upload")
	equal(stream.retrieved.size(), reads, "insufficient byte budget leaves loaded token owned for a later frame")
	for frame: int in 30:
		stream.pump(2, Stream.MAX_PUMP_USEC, 512 * 512 * 4)
		check(stream.last_pump_bytes <= 512 * 512 * 4, "per-frame byte budget is strict")
		check(stream.pending.size() <= 2, "prefetch shares the original request concurrency ceiling")
		if stream.queue.is_empty() and stream.pending.is_empty(): break
	check(stream.ready_for(destination), "bounded destination eventually verifies every requested native tile")
	var uploads: int = stream.uploads
	var prefetched_before: Array = stream.prefetched.duplicate()
	stream.request_view(view)
	equal(stream.prefetched, prefetched_before, "repeated live camera preparation preserves active destination selection")
	stream.clear_prefetch()
	check(stream.prefetched.is_empty() and stream.status().prefetch_required == 0, "closing map clears only speculative demand")
	check(stream.ready_for(view), "closing map cannot evict current required pixels")
	stream.request_view(destination)
	check(stream.ready_for(destination), "confirmed travel reuses verified destination pixels already retained")
	equal(stream.uploads, uploads, "prepared arrival performs no duplicate upload")
	stream.prefetch_view(Rect2(0, 0, 6144, 5376))
	equal(stream.prefetched.size(), Stream.MAX_PREFETCH_CHUNKS, "even full-world highlight cannot exceed24 destination tiles")
	check(stream.desired.size() <= Stream.MAX_CHUNKS and stream.cache_bytes <= Stream.MAX_BYTES, "speculative demand retains finite whole-world ceilings")
	stream.clear_prefetch()
	stream.request_view(view)
	stream.prefetch_view(Rect2(2500, 2500, 400, 400))
	stream.pump()
	check(not stream.pending.is_empty(), "cancellation fixture owns real destination request tokens")
	stream.clear_prefetch()
	var kept: int = stream.uploads
	stream.pump()
	equal(stream.uploads, kept, "cancelled destination tokens drain without stale pixel uploads")
	stream.suspend()
	stream.prefetch_view(destination)
	check(stream.prefetched.is_empty() and stream.suspended, "highlight cannot wake a suspended terrain owner")
	stream.finish_shutdown()
	equal(stream.premature_gets, 0, "prefetch and budgets never retrieve an in-progress resource")


func _test_suspend_resume_and_shutdown() -> void:
	var fixture := _fixture()
	var stream := LoaderProbe.new()
	check(stream.configure(fixture, "a".repeat(64), Vector2i(6144, 5376)), "lifecycle fixture owns a validated finite stream")
	var view := Rect2(48, 48, 160, 160)
	stream.request_view(view)
	stream.pump()
	equal(stream.started.size(), 2, "departure begins with precisely two admitted request handles")
	check(not stream.queue.is_empty(), "departure also has unstarted prefetch work to cancel")
	var first: String = stream.started[0]
	var second: String = stream.started[1]
	stream.statuses[first] = ResourceLoader.THREAD_LOAD_LOADED
	check(not stream.suspend(), "loaded/in-progress departure drains only the completed handle")
	equal(stream.retrieved, [first], "completed unused image is collected exactly once")
	equal(stream.pending.size(), 1, "in-progress handle remains owned while away")
	check(stream.queue.is_empty() and stream.required.is_empty() and stream.desired.is_empty(), "suspension cancels queued work and releases old viewport demand")
	for frame: int in 6:
		check(not stream.suspend(), "repeated suspension polls without blocking")
		equal(stream.pump(99), 0, "an accidental normal pump while suspended cannot upload")
	equal(stream.started.size(), 2, "suspension never starts replacement work")
	equal(stream.uploads, 0, "unneeded completed pixels never become textures")
	equal(stream.premature_gets, 0, "all gameplay retrievals required LOADED status")
	equal(stream.finalized.size(), 0, "gameplay suspension never invokes the teardown wait path")
	stream.statuses[second] = ResourceLoader.THREAD_LOAD_LOADED
	check(stream.suspend(), "last completed request drains on a later non-campus frame")
	equal(stream.retrieved, [first, second], "both request tokens are consumed without duplicate retrieval")
	stream.request_view(view)
	check(not stream.suspended and not stream.required.is_empty() and not stream.queue.is_empty(), "identical pre-departure viewport rebuilds demand after suspension")
	stream.allow_completion = true
	for frame: int in 12:
		stream.pump()
		if stream.pending.is_empty() and stream.queue.is_empty(): break
	check(stream.ready_for(view), "return prepares exactly the original visible terrain")
	var resident_before: int = stream.textures.size()
	var bytes_before: int = stream.cache_bytes
	var requests_before: int = stream.requests
	check(resident_before > 0 and stream.suspend(), "warm departure has no remaining handles")
	equal(stream.textures.size(), resident_before, "suspension preserves reusable warm textures")
	equal(stream.cache_bytes, bytes_before, "suspension does not allocate or discard resident pixel memory")
	stream.request_view(view)
	stream.pump()
	check(stream.ready_for(view), "same warm viewport is immediately ready on return")
	equal(stream.requests, requests_before, "warm return does not start redundant decode work")
	stream.finish_shutdown()
	check(stream.closed and stream.pending.is_empty() and stream.textures.is_empty() and stream.cache_bytes == 0, "final shutdown retires demand and releases residency")
	stream.request_view(view)
	equal(stream.pump(), 0, "terminal stream cannot silently restart")
	check(stream.load_immediate(Vector2i.ZERO) == null and not stream.ready_for(view), "terminal stream rejects tooling loads and readiness until explicit configuration")
	check(stream.configure(fixture, "a".repeat(64), Vector2i(6144, 5376)), "explicit configuration can reuse a fully drained closed instance")
	check(not stream.closed and not stream.suspended, "configuration resets lifecycle state")
	stream.allow_completion = false
	stream.statuses.clear()
	stream.request_view(view)
	stream.pump()
	var terminal_paths: Array[String] = []
	for path: String in stream.pending.values(): terminal_paths.append(path)
	equal(terminal_paths.size(), 2, "shutdown control begins with the bounded pair of handles")
	stream.statuses[terminal_paths[0]] = ResourceLoader.THREAD_LOAD_FAILED
	var starts_before: int = stream.started.size()
	stream.pump()
	check(not stream.last_error.is_empty(), "failed decode reports its real error")
	var failed_load_error: String = stream.status().error
	check(not stream.configure(fixture, "a".repeat(64), Vector2i(6144, 5376)), "failed request ownership also refuses replacement")
	equal(stream.status().error, failed_load_error, "rejected replacement cannot hide an existing decode failure")
	check(not stream.ready_for(view), "an existing load failure stays fail-closed after rejected replacement")
	equal(stream.pending.size(), 2, "failed and running handles remain owned until collected")
	equal(stream.started.size(), starts_before, "terminal decode failure cannot admit further queued work")
	check(not stream.suspend(), "failed token is retained for final cleanup rather than forgotten")
	stream.finish_shutdown()
	equal(stream.finalized, terminal_paths, "final teardown consumes both failed and in-progress tokens once")
	equal(stream.pending.size(), 0, "final teardown leaves no outstanding token")
	stream.finish_shutdown()
	equal(stream.finalized.size(), 2, "repeated final teardown is idempotent")
	equal(stream.premature_gets, 0, "the only potentially waiting path is the explicit final teardown hook")
	var invalid := LoaderProbe.new()
	check(invalid.configure(fixture, "a".repeat(64), Vector2i(6144, 5376)), "invalid-token negative uses an admitted stream")
	invalid.request_view(view)
	invalid.pump()
	for path: String in invalid.pending.values(): invalid.statuses[path] = ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
	check(invalid.suspend(), "missing loader tokens are forgotten without a spurious retrieval")
	invalid.finish_shutdown()
	check(invalid.retrieved.is_empty() and invalid.finalized.is_empty(), "invalid handles are never passed to threaded get")


func _test_reconfiguration_ownership() -> void:
	var stream := LoaderProbe.new()
	check(stream.configure(_fixture(), "a".repeat(64), Vector2i(6144, 5376)), "reconfigure fixture admits")
	var kit := WellspringIllustratedKit.new()
	kit.terrain_stream = stream
	kit.content_hash = "retained-map"
	var roof_image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	roof_image.fill(Color.WHITE)
	var retained_roof := ImageTexture.create_from_image(roof_image)
	kit.roof_skins[17] = retained_roof
	kit.roof_skin_bytes = 16
	var renderer := SanctumCampusRenderer.new()
	renderer.illustrated_kit = kit
	renderer.floor_guide_hash = "retained-guides"
	stream.request_view(Rect2(48, 48, 160, 160))
	stream.pump()
	var owned := stream.pending.duplicate()
	check(not renderer.configure(null), "renderer rejects language replacement while it owns outstanding loads")
	check(renderer.illustrated_kit == kit and kit.terrain_stream == stream, "renderer reconfiguration cannot drop the request owner")
	check(not renderer.configure_campus(null), "renderer rejects map replacement while requests are in flight")
	equal(renderer.floor_guide_hash, "retained-guides", "rejected map replacement preserves existing presentation registration")
	check(not kit.configure(null), "kit refuses to replace an in-flight stream before clearing any current state")
	equal(kit.content_hash, "retained-map", "failed stream replacement preserves current map identity")
	equal(kit.roof_skins.get(17), retained_roof, "busy kit replacement preserves the current verified roof texture")
	equal(kit.roof_skin_bytes, 16, "busy kit replacement preserves resident roof accounting")
	equal(stream.pending, owned, "all request handles remain attached to the original owner")
	check(not renderer.suspend_terrain(), "renderer suspension forwards bounded nonblocking ownership")
	equal(kit.ground_status().queued, 0, "forwarded suspension cancels unstarted prefetch")
	stream.allow_completion = true
	check(renderer.suspend_terrain(), "renderer suspension drains completed original jobs")
	equal(stream.uploads, 0, "the renderer does not upload terrain while away")
	check(renderer.prepare_terrain_view(Rect2(48, 48, 160, 160)) == false, "renderer return schedules the identical view without claiming early readiness")
	check(not stream.pending.is_empty(), "return reaches the retained original stream")
	renderer.finish_terrain_shutdown()
	check(stream.closed and stream.pending.is_empty(), "renderer final teardown forwards terminal cleanup")
	equal(stream.finalized.size(), 2, "renderer final teardown owns no more than the two admitted handles")
	check(not kit.configure(null), "after cleanup an invalid replacement still fails ordinary admission")
	check(kit.terrain_stream == null, "fully drained ownership permits ordinary fail-closed reconfiguration")
	var warm := LoaderProbe.new()
	check(warm.configure(_fixture(), "a".repeat(64), Vector2i(6144, 5376)), "warm busy-replacement fixture admits")
	warm.allow_completion = true
	var visible := Rect2(48, 48, 160, 160)
	warm.request_view(visible)
	warm.pump()
	warm.pump()
	check(warm.ready_for(visible) and not warm.pending.is_empty(), "warm visible pixels coexist with outstanding prefetch")
	var warm_pending := warm.pending.duplicate()
	var warm_textures := warm.textures.duplicate()
	check(not warm.configure({}, "invalid", Vector2i.ONE), "busy stream rejects replacement before processing unrelated invalid input")
	check(not warm.last_error.is_empty(), "caller receives the rejected replacement diagnostic")
	equal(warm.pending, warm_pending, "busy stream replacement preserves every prefetch token")
	equal(warm.textures, warm_textures, "busy stream replacement preserves all visible textures")
	check(warm.ready_for(visible) and String(warm.status().error).is_empty(), "a rejected replacement does not poison current stream readiness or report a false load failure")
	warm.pump()
	check(warm.ready_for(visible) and warm.pending.is_empty(), "existing stream keeps collecting and uploading its admitted prefetch after rejection")
	warm.finish_shutdown()


func _test_real_bake_equivalence() -> void:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "bake equivalence uses current13-destination campus")
	var kit := WellspringIllustratedKit.new()
	check(kit.configure(layout), "current map and art accept their prepared bake: " + kit.last_error)
	if kit.terrain_stream == null: return
	var manifest: Dictionary = (load(Stream.MANIFEST) as Resource).get("descriptor")
	var provenance: Dictionary = manifest.get("source_sha256", {})
	equal(provenance.size(), Stream.BAKE_SOURCE_PATHS.size(), "bake records the exact complete source provenance inventory")
	for source_path: String in Stream.BAKE_SOURCE_PATHS:
		equal(String(provenance.get(source_path, "")), FileAccess.get_sha256(source_path), "bake cannot survive an unversioned source edit: " + source_path)
	var old_source := CanonicalContent.sha256(layout.data)
	# Compare independent native composition at core, Garden, all four annexes,
	# an exact chunk seam and the cropped southeast edge, not the bake's own hash.
	for id: Vector2i in [Vector2i.ZERO, Vector2i(2, 1), Vector2i(9, 1), Vector2i(6, 1), Vector2i(1, 7), Vector2i(5, 7), Vector2i(10, 8), Vector2i(11, 10)]:
		var rect := kit.ground_chunk_rect(id)
		var reference: Image = kit.hex_terrain.compose_region(rect, func(point: Vector2) -> String: return kit.pixel_family(kit.surface_at(point)), kit.ground_style, kit.floor_finish_at, kit.ground_surface_sources())
		var texture := kit.ground_chunk(id)
		check(reference != null and texture != null, "prepared native region and original full sampler both succeed")
		if reference != null and texture != null:
			equal(texture.get_image().get_data(), reference.get_data(), "baked terrain retains every authored native pixel and global hex seam")
	check(kit._prepare_ground_overview(), "overview is separately prebuilt and explicitly loaded")
	if kit.ground_overview != null:
		equal(kit.ground_overview.get_size(), Vector2(1536, 1344), "explicit overview retains prior nearest-neighbor dimensions")
		var overview := kit.ground_overview.get_image()
		for id: Vector2i in [Vector2i(2, 1), Vector2i(9, 1), Vector2i(11, 10)]:
			var region := kit.ground_chunk_rect(id)
			var original := kit.ground_chunk(id).get_image()
			original.resize(region.size.x / 4, region.size.y / 4, Image.INTERPOLATE_NEAREST)
			equal(overview.get_region(Rect2i(region.position / 4, original.get_size())).get_data(), original.get_data(), "overview uses exact original nearest-neighbor reduction without recoloring")
	equal(manifest.chunks.size(), 132, "actual prepared manifest covers complete campus")
	equal(CanonicalContent.sha256(layout.data), old_source, "bake/loading cannot mutate world, collision, travel or chemistry authority")
	var source := FileAccess.get_file_as_string("res://src/presentation/wellspring_illustrated_kit.gd").replace("\r", "")
	var draw := source.get_slice("func draw_ground(", 1).get_slice("\n\nfunc ", 0)
	for forbidden: String in ["compose", "prepare_ground", "load(", "create_from_image", "pump("]:
		check(not draw.contains(forbidden), "live terrain draw contains no blocking preparation: " + forbidden)
