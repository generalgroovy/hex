extends SceneTree
## Native production-renderer review, isolated from preferences and simulation.
## PNG readbacks and WAV export are tooling work, never gameplay work.
const Audio = preload("res://src/presentation/element_audio.gd")
const Details = preload("res://src/presentation/wellspring_environment_details.gd")
const SIZE := Vector2i(1280, 720)
const ZOOM := 0.75
const LIVE_ELEMENTS := ["earth", "fire", "water", "wind", "light", "dark"]
const LANDMARK_IDS := ["tideglass-beacon", "verdant-heartwell", "foundry-furnace", "starward-orrery"]
const SOURCES := [
	"res://tests/visual/capture_world_audio_details.gd",
	"res://src/presentation/element_audio.gd",
	"res://src/presentation/wellspring_environment_details.gd",
	"res://src/presentation/wellspring_district_style.gd",
	"res://src/presentation/sanctum_campus_renderer.gd",
	"res://src/presentation/wellspring_illustrated_kit.gd",
	"res://content/maps/sanctum_campus_g2_v1.json",
	"res://assets/environment/wellspring_ground_v1/manifest.tres",
]
var output := ""
var assertions := 0
var failures := 0
var viewport: SubViewport
var canvas: ReviewCanvas
var renderer := SanctumCampusRenderer.new()
var layout := SanctumCampusLayout.new()
var frames: Array[Dictionary] = []


class ReviewCanvas:
	extends Node2D
	var renderer: SanctumCampusRenderer
	var layout: SanctumCampusLayout
	var world_view := Rect2()
	var show_details := true
	var reduced := false
	var empty_details := Details.new()
	func _draw() -> void:
		# Swap the independent static layer only for the explicit comparison.
		# Preserve the production API and retain both resources across drawing.
		var actual_details := renderer.environment_details
		if not show_details: renderer.environment_details = empty_details
		renderer.draw(self, layout, 0, Vector2(-1000000, -1000000), reduced, false, world_view, false)
		renderer.environment_details = actual_details


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.is_absolute_path() or output.begins_with("res://") or output.begins_with("user://") or ".." in output or DirAccess.dir_exists_absolute(output):
		push_error("A native backend and fresh absolute --output directory are required")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Cannot create world/audio review output")
		quit(1)
		return
	var hashes := {}
	for path: String in SOURCES: hashes[path] = FileAccess.get_sha256(path)
	var language := VisualLanguage.new()
	if not _check(language.load_from_file(), "production visual language loads") or not _check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "production campus loads"):
		quit(1)
		return
	if not _check(renderer.configure(language), "production renderer configures") or not _check(renderer.configure_campus(layout), "production terrain and detail layer configure: " + renderer.last_error):
		quit(1)
		return
	var original_map := CanonicalContent.sha256(layout.data)
	var original_builds := renderer.environment_details.build_count
	root.size = Vector2i(320, 180)
	root.content_scale_size = Vector2i.ZERO
	root.visible = true
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	canvas = ReviewCanvas.new()
	canvas.renderer = renderer
	canvas.layout = layout
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(canvas)
	var cases: Array[Dictionary] = []
	for landmark: Dictionary in layout.data.get("landmarks", []):
		if String(landmark.id) in LANDMARK_IDS:
			cases.append({"id": String(landmark.id), "center": Vector2(SanctumCampusLayout._parse_point(landmark.position))})
	for route: Dictionary in layout.data.get("routes", []):
		if String(route.id) == "nexus-processional":
			cases.append({"id": "academy-route-shoulders", "center": (Vector2(SanctumCampusLayout._parse_point(route.points[0])) + Vector2(SanctumCampusLayout._parse_point(route.points[1]))) * 0.5})
	_check(cases.size() == 5, "four authored travel destinations and one ordinary route are captured")
	for sample: Dictionary in cases:
		var view := Rect2(sample.center - Vector2(SIZE) / (2.0 * ZOOM), Vector2(SIZE) / ZOOM)
		if not await _prepare(view): break
		var before := await _capture(String(sample.id) + "-before-details", view, false, false)
		var after := await _capture(String(sample.id) + "-after-details", view, true, false)
		var reduced := await _capture(String(sample.id) + "-reduced", view, true, true)
		_check(not before.is_empty() and before != after, String(sample.id) + " retained detail meshes change real rendered pixels")
		_check(not after.is_empty() and after == reduced, String(sample.id) + " static floor craft is identical in normal and reduced effects")
	_check(frames.size() == 15, "all five scenes have before, after and reduced native review images")
	_check(CanonicalContent.sha256(layout.data) == original_map, "capture leaves authoritative map bytes unchanged")
	_check(renderer.environment_details.build_count == original_builds, "camera moves and comparisons never rebuild floor detail meshes")
	var audio_receipt := _export_audio()
	renderer.finish_terrain_shutdown()
	for path: String in SOURCES: _check(FileAccess.get_sha256(path) == String(hashes[path]), "source did not change during capture: " + path)
	var receipt := {
		"status": "passed" if failures == 0 else "failed", "assertions": assertions, "failures": failures,
		"sources": hashes, "frames": frames, "audio": audio_receipt,
		"map": {"hash": original_map, "detail_hash": renderer.environment_details.content_hash, "marks": renderer.environment_details.marks.size(), "patches": renderer.environment_details.patches.size(), "vertices": renderer.environment_details.vertex_count},
		"scope": "Actual production campus renderer in a fixed 1280x720 SubViewport at75percent gameplay zoom; before images disable only the new detail layer. Native pixels and PCM measurements, not gameplay, performance or listening acceptance. No preference files or playback devices used.",
	}
	var file := FileAccess.open(output + "/receipt.json", FileAccess.WRITE)
	if file == null:
		push_error("Cannot save world/audio receipt")
		quit(1)
		return
	file.store_string(JSON.stringify(receipt, "\t") + "\n")
	file.close()
	print("%s world-audio review assertions=%d failures=%d frames=%d" % ["PASS" if failures == 0 else "FAIL", assertions, failures, frames.size()])
	quit(0 if failures == 0 else 1)


func _prepare(view: Rect2) -> bool:
	for attempt: int in 600:
		if renderer.prepare_terrain_view(view, 2): return true
		await process_frame
	return _check(false, "bounded terrain preparation timed out: " + str(renderer.terrain_status()))


func _capture(label: String, view: Rect2, details: bool, reduced: bool) -> String:
	canvas.world_view = view
	canvas.show_details = details
	canvas.reduced = reduced
	canvas.position = (-view.position * ZOOM).round()
	canvas.scale = Vector2.ONE * ZOOM
	canvas.queue_redraw()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if not _check(image != null and image.get_size() == SIZE, label + " uses the fixed SubViewport rather than desktop window size"): return ""
	var path := output + "/" + label + ".png"
	if not _check(image.save_png(path) == OK, label + " saves native pixels"): return ""
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(image.get_data())
	var digest := hash.finish().hex_encode()
	frames.append({"id": label, "path": path.get_file(), "size": [SIZE.x, SIZE.y], "world_rect": [view.position.x, view.position.y, view.size.x, view.size.y], "details": details, "reduced": reduced, "visible_detail_patches": renderer.environment_details.visible_patch_count(view) if details else 0, "rgba_sha256": digest, "png_sha256": FileAccess.get_sha256(path)})
	return digest


func _export_audio() -> Dictionary:
	var audio := Audio.new()
	audio.prepare(false)
	var metrics: Dictionary = {}
	var peak := 0.0
	var pcm_bytes := 0
	for key: String in audio.clips:
		var clip: AudioStreamWAV = audio.clips[key]
		var bytes := clip.data
		var signal_peak := 0.0
		var energy := 0.0
		for offset: int in range(0, bytes.size(), 2):
			var sample := float(bytes.decode_s16(offset)) / 32767.0
			signal_peak = maxf(signal_peak, absf(sample))
			energy += sample * sample
		var zero_ends := bytes.decode_s16(0) == 0 and bytes.decode_s16(bytes.size() - 2) == 0
		_check(zero_ends and signal_peak <= Audio.PEAK + 1.0 / 32767.0, key + " retains zero endpoints and bounded PCM peak")
		metrics[key] = {"seconds": clip.get_length(), "peak": signal_peak, "rms": sqrt(energy / (bytes.size() / 2.0)), "zero_endpoints": zero_ends}
		peak = maxf(peak, signal_peak)
		pcm_bytes += bytes.size()
	var reel := PackedByteArray()
	var cues: Array[Dictionary] = []
	for element: String in LIVE_ELEMENTS:
		for slot: int in 4:
			var key := Audio._key(element, slot > 0, maxi(0, slot - 1))
			var clip: AudioStreamWAV = audio.clips[key]
			cues.append({"element": element, "kind": "cast" if slot == 0 else "contact", "variant": maxi(0, slot - 1), "start_seconds": float(reel.size()) / (Audio.RATE * 2), "duration_seconds": clip.get_length()})
			reel.append_array(clip.data)
			var silence := PackedByteArray()
			silence.resize(roundi(Audio.RATE * (0.66 if slot == 3 else 0.24)) * 2)
			silence.fill(0)
			reel.append_array(silence)
	var exports: Array[Dictionary] = []
	for gain: int in [30, 100]:
		var bytes := reel.duplicate()
		for offset: int in range(0, bytes.size(), 2): bytes.encode_s16(offset, roundi(float(bytes.decode_s16(offset)) * gain / 100.0))
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = Audio.RATE
		wav.stereo = false
		wav.data = bytes
		var name := "element-audio-%d-percent.wav" % gain
		_check(wav.save_to_wav(output + "/" + name) == OK, name + " exports actual cached PCM with separation")
		exports.append({"path": name, "gain_percent": gain, "seconds": wav.get_length(), "sha256": FileAccess.get_sha256(output + "/" + name)})
	_check(audio.players.is_empty() and pcm_bytes <= Audio.MAX_PCM_BYTES, "audio review allocates no playback devices and stays inside production PCM budget")
	audio.free()
	return {"files": exports, "sequence": cues, "clips": metrics, "bank_pcm_bytes": pcm_bytes, "raw_peak": peak, "conservative_four_voice_peak": Audio.PEAK * Audio.VOICES, "default_four_voice_peak": Audio.PEAK * Audio.VOICES * 0.30, "listening_acceptance": "not assessed; review the exported WAV files"}


func _check(condition: bool, label: String) -> bool:
	assertions += 1
	if not condition:
		failures += 1
		print("FAIL: ", label)
	return condition
