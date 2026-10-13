extends RefCounted
## Ignored prototype. One immutable byte owner and one task-local hash context.
## No Image, ResourceLoader, rendering or scene-tree call runs on the worker.

var _pixels: PackedByteArray
var _measure := false
var _mutex := Mutex.new()
var _result: Dictionary = {}
var _joined := false # Main-thread only; changed after the task has been joined.


func _init(pixels: PackedByteArray, measure: bool) -> void:
	_pixels = pixels
	_measure = measure


func run() -> void:
	var started := Time.get_ticks_usec() if _measure else 0
	var context := HashingContext.new()
	var error: Error = context.start(HashingContext.HASH_SHA256)
	if error == OK:
		error = context.update(_pixels)
	var digest := context.finish().hex_encode() if error == OK else ""
	var elapsed := maxi(0, Time.get_ticks_usec() - started) if _measure else 0
	# Hashing is outside the lock. Publish only a bounded scalar result.
	_mutex.lock()
	_result = {"error": int(error), "sha256": digest,
		"measured": _measure, "elapsed_usec": elapsed}
	_mutex.unlock()


func joined_result() -> Dictionary:
	# Called only after WorkerThreadPool.wait_for_task_completion succeeded.
	_joined = true
	_mutex.lock()
	var result := _result.duplicate()
	_mutex.unlock()
	return result


func pixels_after_join() -> PackedByteArray:
	return _pixels if _joined else PackedByteArray()
