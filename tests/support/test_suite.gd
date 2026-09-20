class_name FluxTestSuite
extends RefCounted


var failures: int = 0
var assertions: int = 0


func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		print("FAIL: ", message)


func equal(actual: Variant, expected: Variant, message: String) -> void:
	check(actual == expected, "%s (expected=%s actual=%s)" % [message, expected, actual])


func finish(name: String) -> int:
	print("%s: %d assertions, %d failures" % [name, assertions, failures])
	return failures
