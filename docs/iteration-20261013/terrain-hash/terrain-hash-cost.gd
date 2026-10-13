extends SceneTree

# Primitive CPU comparison only. No stream scheduling, texture upload, rendering,
# foreground admission, gameplay authority or source promotion is exercised.
const MANIFEST := "res://assets/environment/wellspring_ground_v1/manifest.tres"
const METHODS: Array[int] = [0, 32768, 65536, 131072]
const ROUNDS := 64
const WARMUPS := 2
var failed := false
var failures: Array[String] = []
var output := ""
var reverse := false
var rows: Array[Dictionary] = []
var raw: Array[Dictionary] = []
var initial_source_hashes: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> bool:
	if not value:
		failed = true
		failures.append(message)
	return value


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		if argument == "--reverse": reverse = true
	if not _check(not output.is_empty(), "Explicit output is required"):
		quit(1)
		return
	if not _check(not FileAccess.file_exists(output), "Output must not overwrite prior evidence"):
		quit(1)
		return
	for path: String in [get_script().resource_path, MANIFEST]:
		initial_source_hashes[path] = FileAccess.get_sha256(path)
	var manifest := load(MANIFEST)
	if not _check(manifest != null, "Manifest loads"):
		_write()
		return
	var document: Dictionary = manifest.get("descriptor")
	var all_records: Array = document.get("chunks", [])
	# Two full regions and one shorter southern edge from the actual asset set.
	for index: int in [0, 53, 131]:
		if not _check(index < all_records.size(), "Expected tile record exists"): break
		var record: Dictionary = all_records[index]
		var resource_path: String = record.path
		var image := ResourceLoader.load(resource_path, "Image", ResourceLoader.CACHE_MODE_IGNORE) as Image
		if not _check(image != null and image.get_format() == Image.FORMAT_RGBA8 and not image.has_mipmaps(), "Actual tile is mip-free RGBA8"): break
		if not _check(record.size == [image.get_width(), image.get_height()], "Actual tile dimensions match"): break
		var before_hash := FileAccess.get_sha256(resource_path)
		var expected_hash: String = record.rgba_sha256
		var measured: Array[Dictionary] = []
		for round_index: int in range(-WARMUPS, ROUNDS):
			var methods: Array[int] = METHODS.duplicate()
			if ((round_index + WARMUPS) % 2 == 1) != reverse: methods.reverse()
			for order_index: int in methods.size():
				var chunk_size: int = methods[order_index]
				var result := _measure(image, chunk_size)
				_check(result.digest == expected_hash, "All methods retain exact native pixel hash")
				_check(result.hash_error == OK, "Hash context start and every update succeed")
				_check(result.updates == (1 if chunk_size == 0 else ceili(float(result.buffer_bytes) / float(chunk_size))), "Actual update count matches bounded chunk size")
				_check(result.final_offset == result.buffer_bytes, "Updates consume every byte exactly once")
				result.tile = resource_path
				result.round_index = round_index
				result.warmup = round_index < 0
				result.order_index = order_index
				result.chunk_size = chunk_size
				raw.append(result)
				if round_index >= 0:
					measured.append(result)
		if not _check(FileAccess.get_sha256(resource_path) == before_hash, "Source image unchanged through comparison"): break
		rows.append({"path": resource_path, "resource_sha256": before_hash,
			"pixel_sha256": expected_hash, "size": record.size, "bytes": image.get_width() * image.get_height() * 4,
			"methods": _summarize(measured), "mutation_rejections": _mutation_controls(image, expected_hash)})
	_write()


func _measure(image: Image, chunk_size: int) -> Dictionary:
	var started := Time.get_ticks_usec()
	var context := HashingContext.new()
	var hash_error := context.start(HashingContext.HASH_SHA256)
	var context_us := Time.get_ticks_usec() - started
	var copy_started := Time.get_ticks_usec()
	var pixels := image.get_data()
	var copy_us := Time.get_ticks_usec() - copy_started
	var update_elapsed_us := 0
	var update_max_us := 0
	var updates := 0
	var offset := 0
	while offset < pixels.size():
		var update_started := Time.get_ticks_usec()
		var end := pixels.size() if chunk_size == 0 else mini(pixels.size(), offset + chunk_size)
		var error := context.update(pixels if chunk_size == 0 else pixels.slice(offset, end))
		var update_us := Time.get_ticks_usec() - update_started
		if error != OK: hash_error = error
		update_elapsed_us += update_us
		update_max_us = maxi(update_max_us, update_us)
		updates += 1
		offset = end
	var finish_started := Time.get_ticks_usec()
	var digest := context.finish().hex_encode()
	var finish_us := Time.get_ticks_usec() - finish_started
	var total_us := Time.get_ticks_usec() - started
	return {"digest": digest, "hash_error": hash_error, "context_us": context_us,
		"get_data_us": copy_us, "updates_us": update_elapsed_us, "update_max_us": update_max_us,
		"finish_us": finish_us, "total_us": total_us, "updates": updates, "final_offset": offset,
		"indivisible_max_us": maxi(maxi(context_us, copy_us), maxi(update_max_us, finish_us)),
		"buffer_bytes": pixels.size(), "additional_slice_bytes_upper_bound": mini(chunk_size, pixels.size())}


func _mutation_controls(image: Image, expected_hash: String) -> int:
	var original := image.get_data()
	var rejected := 0
	for changed_index: int in [0, floori(float(original.size()) / 2.0), original.size() - 1]:
		var changed := original.duplicate()
		changed[changed_index] = changed[changed_index] ^ 1
		var variant := Image.create_from_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, changed)
		for method: int in METHODS:
			var result := _measure(variant, method)
			if _check(result.digest != expected_hash, "Changed first/middle/last pixel byte rejects"):
				rejected += 1
	return rejected


func _stats(values: Array[int]) -> Dictionary:
	values.sort()
	var sum := 0
	for value: int in values: sum += value
	return {"count": values.size(), "mean": float(sum) / values.size(),
		"p50": values[ceili(values.size() * 0.5) - 1], "p95": values[ceili(values.size() * 0.95) - 1], "max": values.back()}


func _summarize(measured: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for method: int in METHODS:
		var summary := {"chunk_size": method, "stages_us": {}}
		for field: String in ["context_us", "get_data_us", "updates_us", "update_max_us", "finish_us", "total_us", "indivisible_max_us"]:
			var values: Array[int] = []
			for row: Dictionary in measured:
				if int(row.chunk_size) == method: values.append(int(row[field]))
			summary.stages_us[field] = _stats(values)
		result.append(summary)
	return result


func _write() -> void:
	for path: String in initial_source_hashes:
		_check(FileAccess.get_sha256(path) == initial_source_hashes[path], "Helper/manifest unchanged through comparison")
	var report := {"schema": "hex.terrain-hash-primitive.v1", "status": "failed" if failed else "passed",
		"scope": "Native engine CPU primitive only; not stream scheduling, texture upload, foreground/FPS or gameplay acceptance. Resource loading precedes timing. Images are warm. Repeated slice allocation and context lifecycle are timed; raw formatting and source equality are outside timing. Per-update timing itself is included and has more calls for smaller slices. Main-thread preemption may occur.",
		"memory_scope": "Logical pixel and temporary-slice sizes only, not measured allocator RSS. Image.get_data copy or sharing is an engine detail; no zero-copy claim.",
		"engine": Engine.get_version_info(), "display_server": DisplayServer.get_name(), "reverse_initial_order": reverse, "warmups": WARMUPS, "rounds": ROUNDS,
		"helper_sha256": FileAccess.get_sha256(get_script().resource_path), "manifest_sha256": FileAccess.get_sha256(MANIFEST),
		"initial_source_hashes": initial_source_hashes,
		"rows": rows, "raw": raw, "failures": failures}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		print("TERRAIN_HASH_COST_OUTPUT_FAILED")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("TERRAIN_HASH_COST_COMPLETE status=%s rows=%d observations=%d" % [report.status, rows.size(), raw.size()])
	quit(1 if failed else 0)
