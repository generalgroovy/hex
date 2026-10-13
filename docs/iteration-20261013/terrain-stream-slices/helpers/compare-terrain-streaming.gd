extends SceneTree
## Native, instrumented sequential ResourceLoader/ImageTexture comparison.
## No production bootstrap, save/profile writes, networking, or FPS claim.
const Before = preload("res://.godot/iteration-20261013/terrain-before/src/presentation/wellspring_terrain_stream.gd")
const After = preload("res://src/presentation/wellspring_terrain_stream.gd")
const SELF_PATH := "res://.godot/iteration-20261013/compare-terrain-streaming.gd"
const WATCHED := [SELF_PATH, "res://src/presentation/wellspring_terrain_stream.gd",
	"res://.godot/iteration-20261013/terrain-before/src/presentation/wellspring_terrain_stream.gd",
	"res://.godot/iteration-20261013/terrain-before/manifest.json",
	"res://assets/environment/wellspring_ground_v1/manifest.tres",
	"res://src/presentation/wellspring_terrain_manifest.gd",
	"res://src/content/sanctum_campus_layout.gd", "res://content/maps/sanctum_campus_g2_v1.json"]
const STAGES := ["ready_retrieval", "pixel_validation", "image_reconstruction", "texture_creation", "retention_trim", "request_submission"]
const CYCLES := 8
const WARMUPS := 2
const MAX_PUMPS := 360
var output := ""
var reverse := false
var checks := 0
var errors: Array[String] = []
var sources: Dictionary = {}
var cases: Array[Dictionary] = []
var cancellation: Array[Dictionary] = []
var early_walking: Array[Dictionary] = []
var descriptor: Dictionary = {}
var active: RefCounted
var finished := false
var output_authorized := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	reverse = OS.get_cmdline_user_args().has("--reverse")
	if not _check(DisplayServer.get_name() != "headless" and output.begins_with("res://.godot/iteration-20261013/terrain-native-") and not ".." in output and not FileAccess.file_exists(output), "Fresh owned native output required"):
		_finish(); return
	output_authorized = true
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/iteration-20261013/terrain-before/manifest.json"))
	if not _check(manifest is Array, "Pinned predecessor manifest exists"): _finish(); return
	var pinned := false
	for row: Dictionary in manifest:
		if row.path == "src/presentation/wellspring_terrain_stream.gd":
			pinned = FileAccess.get_sha256(WATCHED[2]) == String(row.sha256)
	if not _check(pinned, "Exact predecessor source hash"): _finish(); return
	for path: String in WATCHED:
		sources[path] = FileAccess.get_sha256(path)
		if not _check(String(sources[path]).length() == 64, "Every watched input exists"): _finish(); return
	var resource: Resource = ResourceLoader.load(After.MANIFEST, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not _check(resource != null and resource.get("descriptor") is Dictionary, "Actual baked descriptor"): _finish(); return
	descriptor = resource.get("descriptor").duplicate(true)
	var layout := SanctumCampusLayout.new()
	if not _check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "Actual campus layout"): _finish(); return
	var plots := layout.element_garden_plots()
	if not _check(plots.size() == 63, "Actual Garden has63 authored plots"): _finish(); return
	var bounds := Rect2(plots[0].center, Vector2.ZERO)
	for plot: Dictionary in plots: bounds = bounds.expand(plot.center)
	var focus: Vector2 = plots[0].center
	for plot: Dictionary in plots:
		if Vector2(plot.center).distance_squared_to(bounds.get_center()) < focus.distance_squared_to(bounds.get_center()): focus = plot.center
	var views: Array[Dictionary] = [
		{"id": "garden", "rect": Rect2(focus - Vector2(640, 360), Vector2(1280, 720))},
		{"id": "large28", "rect": Rect2(1024, 1024, 3584, 2048)},
		{"id": "partial_edge", "rect": Rect2(5632, 5120, 512, 256)}]
	create_timer(300).timeout.connect(func() -> void:
		if not finished: errors.append("Native terrain watchdog"); _finish())
	for view: Dictionary in views:
		for cycle: int in CYCLES:
			var order: Array = ["before", "after"] if ((cycle % 2 == 0) != reverse) else ["after", "before"]
			for role: String in order:
				await process_frame
				var result: Dictionary = await _case(role, view, cycle, order)
				cases.append(result)
				if not errors.is_empty(): _finish(); return
	for role: String in (["after", "before"] if reverse else ["before", "after"]):
		cancellation.append(await _cancel_case(role, views[1].rect, views[2].rect))
		if not errors.is_empty(): _finish(); return
	for view: Dictionary in views:
		for role: String in (["after", "before"] if reverse else ["before", "after"]):
			early_walking.append(await _early_walk_case(role, view))
			if not errors.is_empty(): _finish(); return
	for path: String in WATCHED: _check(FileAccess.get_sha256(path) == sources[path], "Watched source remains frozen")
	_check(cases.size() == 48 and cancellation.size() == 2 and early_walking.size() == 6, "Complete bounded native matrix")
	_finish()


func _new_stream(role: String) -> RefCounted:
	var stream: RefCounted = Before.new() if role == "before" else After.new()
	_check(stream.configure(descriptor, String(descriptor.signature), Vector2i(6144, 5376)), "Configure actual baked stream")
	stream.profile_enabled = true
	stream.reset_profile()
	active = stream
	return stream


func _case(role: String, view: Dictionary, cycle: int, order: Array) -> Dictionary:
	var stream := _new_stream(role)
	var rect: Rect2 = view.rect
	var required: Array = stream.ids_for(rect)
	if view.id == "large28": _check(required.size() == 28, "Large view has exactly28 required tiles")
	if view.id == "partial_edge": _check(required == [Vector2i(11, 10)], "Native partial edge is exactly one512x256 tile")
	var result := {"role": role, "view": view.id, "cycle": cycle, "warmup": cycle < WARMUPS, "actual_arm_order": order.duplicate(),
		"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "required_ids": _ids(required),
		"pumps": [], "pixel_checks": [], "first_ready_frame": -1, "first_ready_wall_us": -1,
		"walking_unready_frames": 0, "request_boundary_status": {}}
	var started := Time.get_ticks_usec()
	stream.request_view(rect)
	result.request_boundary_status = _small_status(stream.status())
	await _drain(stream, rect, "arrival", result, started, true)
	if errors.is_empty(): _verify_pixels(stream, rect, result, "arrival_endpoint")
	for frame: int in 8:
		await process_frame
		_pump(stream, rect, "warm_stationary", frame, result)
		_check(stream.ready_for(rect), "Fully drained stationary view stays ready")
	# Ordinary walking changes demand on every frame; never pause the trace to
	# hide unready frames. Hold/drain only at its explicit recorded endpoints.
	for leg: int in 2:
		for frame: int in 12:
			await process_frame
			var distance := float(frame + 1 if leg == 0 else 11 - frame) * 48.0
			var walking := Rect2(rect.position + Vector2(-distance, 0), rect.size)
			stream.request_view(walking)
			_pump(stream, walking, "walk_out" if leg == 0 else "walk_return", frame, result)
			if not stream.ready_for(walking): result.walking_unready_frames += 1
		var endpoint := Rect2(rect.position + Vector2(-576.0 if leg == 0 else 0.0, 0), rect.size)
		await _drain(stream, endpoint, "walk_out_drain" if leg == 0 else "walk_return_drain", result, Time.get_ticks_usec(), false)
		if errors.is_empty(): _verify_pixels(stream, endpoint, result, "walk_out_endpoint" if leg == 0 else "walk_return_endpoint")
	result.final_status = _small_status(stream.status())
	result.profile = stream.profile_status()
	var close_started := Time.get_ticks_usec()
	stream.finish_shutdown()
	result.shutdown_us = Time.get_ticks_usec() - close_started
	result.closed_status = _small_status(stream.status())
	_check(bool(stream.closed) and stream.pending.is_empty() and stream.textures.is_empty(), "Fully drained stream closes without ownership or textures")
	active = null
	return result


func _drain(stream: RefCounted, rect: Rect2, phase: String, result: Dictionary, started: int, capture_ready: bool, stop_at_first_ready: bool = false) -> void:
	for frame: int in MAX_PUMPS:
		await process_frame
		_pump(stream, rect, phase, frame, result)
		if not errors.is_empty(): return
		if capture_ready and int(result.first_ready_frame) < 0 and stream.ready_for(rect):
			result.first_ready_frame = frame
			result.first_ready_wall_us = Time.get_ticks_usec() - started
			if stop_at_first_ready: return
		if stream.queue.is_empty() and stream.pending.is_empty():
			_check(stream.ready_for(rect), "Drained demand has every required texture")
			if capture_ready:
				result.halo_drained_frame = frame
				result.halo_drained_wall_us = Time.get_ticks_usec() - started
			return
	_check(false, "Bounded stream drain exceeded360 pumps: " + phase)


func _pump(stream: RefCounted, view: Rect2, phase: String, frame: int, result: Dictionary) -> void:
	var before: Dictionary = stream.profile_status()
	var before_uploads := int(stream.uploads)
	var started := Time.get_ticks_usec()
	var admitted: int = stream.pump()
	var elapsed := Time.get_ticks_usec() - started
	var profile: Dictionary = stream.profile_status()
	var status: Dictionary = stream.status()
	var times := {}
	var calls := {}
	for stage: String in STAGES:
		times[stage] = int(profile.elapsed_usec.get(stage, 0)) - int(before.elapsed_usec.get(stage, 0))
		calls[stage] = int(profile.calls.get(stage, 0)) - int(before.calls.get(stage, 0))
		_check(int(times[stage]) >= 0 and int(calls[stage]) >= 0, "Monotonic profile counters")
	_check(String(status.error).is_empty(), "Actual stream error: " + String(status.error))
	_check(admitted == int(stream.uploads) - before_uploads and admitted <= 2 and admitted >= 0, "Real upload count matches strict cap")
	_check(int(status.pending) <= 2 and int(status.pump_bytes) <= 2097152, "Combined ownership and upload byte caps")
	if status.has("pump_validation_bytes"):
		_check(int(status.pump_validation_bytes) <= int(status.validation_byte_limit), "Exact validation byte cap")
		_check(int(status.decode_pending) + int(status.validation_pending) == int(status.pending), "Combined job ownership counted once")
	var independently_ready := true
	for id: Vector2i in stream.ids_for(view): independently_ready = independently_ready and stream.textures.has(id)
	_check(bool(stream.ready_for(view)) == independently_ready, "Required readiness equals actual resident texture ownership")
	result.pumps.append({"phase": phase, "frame": frame, "whole_pump_us": elapsed, "stage_us": times, "stage_calls": calls,
		"admitted": admitted, "ready": stream.ready_for(view), "status": _small_status(status)})


func _verify_pixels(stream: RefCounted, view: Rect2, result: Dictionary, phase: String) -> void:
	# Endpoint-only readback/hash adds diagnostic wall time, outside every pump
	# and before the next phase starts. Never keep evicted Texture references.
	var verified := 0
	var bytes := 0
	var started := Time.get_ticks_usec()
	for id: Vector2i in stream.textures:
		var texture: Texture2D = stream.textures[id]
		var image := texture.get_image()
		var record: Dictionary = stream.records[id]
		_check(image != null and image.get_format() == Image.FORMAT_RGBA8 and not image.has_mipmaps(), "Real uploaded RGBA8 mip-free pixels")
		if image == null: continue
		_check(record.size == [image.get_width(), image.get_height()], "Uploaded native region exact dimensions")
		var data := image.get_data()
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(data)
		_check(context.finish().hex_encode() == String(record.rgba_sha256), "Exact manifest pixels after actual ImageTexture upload")
		bytes += data.size()
		verified += 1
	_check(stream.ready_for(view), "Endpoint verification retains complete required readiness")
	result.pixel_checks.append({"phase": phase, "textures": verified, "rgba_bytes": bytes, "readback_hash_us": Time.get_ticks_usec() - started})


func _cancel_case(role: String, distant: Rect2, destination: Rect2) -> Dictionary:
	var stream := _new_stream(role)
	var result := {"role": role, "pumps": [], "pixel_checks": [], "first_ready_frame": -1, "first_ready_wall_us": -1}
	stream.request_view(distant)
	var found := false
	for frame: int in 60:
		await process_frame
		_pump(stream, distant, "before_cancel", frame, result)
		var status: Dictionary = stream.status()
		if (int(status.get("validation_pending", 0)) > 0 if role == "after" else int(status.pending) > 0):
			found = true
			result.cancel_boundary_status = _small_status(status)
			break
	_check(found, "Cancellation witnesses actual owned decode/validation work")
	var uploads_at_cancel := int(stream.uploads)
	var cancel_started := Time.get_ticks_usec()
	stream.suspend()
	result.suspend_us = Time.get_ticks_usec() - cancel_started
	for frame: int in 120:
		if stream.pending.is_empty(): break
		await process_frame
		var tick_started := Time.get_ticks_usec()
		stream.pump()
		result.pumps.append({"phase": "suspended_drain", "frame": frame, "whole_pump_us": Time.get_ticks_usec() - tick_started, "status": _small_status(stream.status())})
	_check(stream.pending.is_empty() and stream.queue.is_empty() and stream.required.is_empty(), "Cancellation drains actual tokens and publishes no demand")
	_check(int(stream.uploads) == uploads_at_cancel, "Suspended token collection performs no upload")
	result.suspended_status = _small_status(stream.status())
	stream.request_view(destination)
	await _drain(stream, destination, "reentry", result, Time.get_ticks_usec(), true)
	_verify_pixels(stream, destination, result, "reentry_endpoint")
	stream.finish_shutdown()
	_check(stream.pending.is_empty() and stream.textures.is_empty() and stream.closed, "Cancel/reentry stream final ownership drained")
	result.closed_status = _small_status(stream.status())
	active = null
	return result


func _early_walk_case(role: String, view: Dictionary) -> Dictionary:
	var stream := _new_stream(role)
	var rect: Rect2 = view.rect
	var result := {"role": role, "view": view.id, "pumps": [], "pixel_checks": [], "first_ready_frame": -1, "first_ready_wall_us": -1,
		"unready_frames": 0, "longest_unready_run": 0, "trace": [], "source": "Fixed synthetic camera demand; last-ready view is a diagnostic presentation proxy, not player/Bootstrap motion."}
	stream.request_view(rect)
	await _drain(stream, rect, "early_arrival", result, Time.get_ticks_usec(), true, true)
	result.first_ready_status = _small_status(stream.status())
	result.unfinished_halo_at_start = not stream.pending.is_empty() or not stream.queue.is_empty()
	_check(stream.ready_for(rect), "Early walking begins at actual required readiness")
	var last_ready := rect.position
	var current_gap := 0
	var previous_requested := rect.position
	var previous_presentable := rect.position
	var requested_distance := 0.0
	var presentable_distance := 0.0
	for sample: int in 24:
		await process_frame
		var distance := float(sample + 1 if sample < 12 else 23 - sample) * 48.0
		var demand := Rect2(rect.position - Vector2(distance, 0), rect.size)
		stream.request_view(demand)
		_pump(stream, demand, "early_walk_fixed_demand", sample, result)
		var ready: bool = stream.ready_for(demand)
		if ready:
			last_ready = demand.position
			current_gap = 0
		else:
			result.unready_frames += 1
			current_gap += 1
			result.longest_unready_run = maxi(int(result.longest_unready_run), current_gap)
		requested_distance += previous_requested.distance_to(demand.position)
		presentable_distance += previous_presentable.distance_to(last_ready)
		result.trace.append({"sample": sample, "requested_position": [demand.position.x, demand.position.y], "required_ready": ready,
			"last_ready_view_position": [last_ready.x, last_ready.y], "presentation_proxy_gap_px": demand.position.distance_to(last_ready)})
		previous_requested = demand.position
		previous_presentable = last_ready
	result.requested_path_px = requested_distance
	result.last_ready_proxy_path_px = presentable_distance
	result.final_proxy_displacement_px = last_ready.distance_to(rect.position)
	result.final_requested_position = [previous_requested.x, previous_requested.y]
	result.final_last_ready_position = [last_ready.x, last_ready.y]
	await _drain(stream, rect, "early_walk_final_drain", result, Time.get_ticks_usec(), false)
	_verify_pixels(stream, rect, result, "early_walk_final_endpoint")
	result.final_status = _small_status(stream.status())
	stream.finish_shutdown()
	_check(stream.closed and stream.pending.is_empty() and stream.textures.is_empty(), "Early-walk stream closes fully")
	active = null
	return result


func _small_status(status: Dictionary) -> Dictionary:
	var result := status.duplicate()
	result.erase("profile")
	return result


func _ids(ids: Array) -> Array:
	var result: Array = []
	for id: Vector2i in ids: result.append([id.x, id.y])
	return result


func _check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition: errors.append(message)
	return condition


func _finish() -> void:
	if finished: return
	finished = true
	if active != null: active.finish_shutdown(); active = null
	var receipt := {"schema": "hex.native.terrain-streaming.v1", "passed": errors.is_empty(), "errors": errors, "checks": checks,
		"engine": Engine.get_version_info(), "reverse": reverse, "sources": sources, "cases": cases, "cancellation": cancellation, "early_walking": early_walking,
		"scope": "Real native ResourceLoader and ImageTexture, exact predecessor vs current. Two warmup plus six measured fresh streams per view; sequential fully closed arms alternate and reversed process is separate. OS cache is uncontrolled; no cold-disk claim. One pump per process frame, whole call and nested stage clocks; stage sums are not an additive frame breakdown. Readiness wall/frames include diagnostic status collection and frame scheduling; endpoint pixel readback/hash is outside all pump clocks and delays subsequent phases. Construction/configuration costs are excluded; endpoint readback costs are recorded separately. Walking reports every unready frame without pausing its trace; endpoint drains are explicit. All retained endpoint textures are verified against exact manifest pixels without retaining evicted textures. Cancellation requires a naturally observed partial job; absence of that witness on faster hardware is a fixture limitation. No Bootstrap travel, foreground, FPS, GPU execution, physical input or hard2ms latency guarantee."}
	if output_authorized:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file == null: push_error("Cannot write native terrain receipt"); quit(1); return
		file.store_string(JSON.stringify(receipt, "\t")); file.close()
		var verified: Variant = JSON.parse_string(FileAccess.get_file_as_string(output))
		if not verified is Dictionary or int(verified.checks) != checks: push_error("Native terrain receipt readback failed"); quit(1); return
	print("TERRAIN_NATIVE ", checks, " checks, ", cases.size(), " cases, ", errors.size(), " errors: ", output)
	quit(0 if errors.is_empty() else 1)
