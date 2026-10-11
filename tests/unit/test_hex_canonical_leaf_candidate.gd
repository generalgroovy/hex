extends FluxTestSuite

const World = preload("res://src/sim/hex/hex_chemistry_world.gd")
const Candidate = preload("res://tests/support/hex_canonical_leaf_candidate.gd")
const Dynamic = preload("res://tests/support/hex_dynamic_leaf_candidate.gd")
const Oracle = preload("res://tests/support/hex_canonical_pre_e9.gd")

class RecordingKey:
	extends RefCounted
	var label := ""
	var trace: Array[String] = []
	var nested_world: HexChemistryWorld
	func _to_string() -> String:
		trace.append(label)
		if nested_world != null: Candidate.state_hash(nested_world)
		return label

class ExtendedWorld:
	extends HexChemistryWorld
	func _state_hash_bytes() -> PackedByteArray:
		return "extension owns bytes 水".to_utf8_buffer()


func run() -> int:
	_test_leaf_shapes()
	_test_mixed_parents_and_numbers()
	_test_token_collisions_and_unicode()
	_test_mutable_aliases()
	_test_fallback_and_callbacks()
	return finish("hex-canonical-leaf-candidate")


func _world() -> HexChemistryWorld:
	var world := World.new()
	check(world.configure_geometry(Vector2i(640_000, 480_000), HexGrid.disk(Vector2i.ZERO, 2)), "leaf fixture has concrete immutable topology")
	return world


func _leaf(count: int, reversed: bool = false) -> Dictionary:
	var result := {}
	for index: int in count:
		var value := count - index - 1 if reversed else index
		result[Vector2i(value - 20, (value % 13) - 6)] = value - 12
	return result


func _assert_exact(world: HexChemistryWorld, label: String) -> void:
	var before := var_to_bytes(Dynamic.lanes(world))
	var expected_document := JSON.stringify(Oracle._stable(Dynamic.lanes(world)))
	equal(Dynamic.document(world), expected_document, label + " independent full-depth dynamic JSON")
	var expected := Oracle.state_bytes(world)
	var actual := Candidate.canonical_bytes(world)
	check(actual == expected, label + " independent framed full-state bytes")
	check(actual.size() >= 8, label + " header present")
	if actual.size() >= 8: equal(actual.decode_s64(0), actual.size() - 8, label + " signed UTF-8 byte framing")
	equal(Candidate.state_hash(world), Oracle.hash_bytes(expected), label + " full SHA256")
	equal(var_to_bytes(Dynamic.lanes(world)), before, label + " authority unchanged")


func _test_leaf_shapes() -> void:
	for count: int in [0, 1, 7, 8, 9, 13, 152, 511]:
		for reversed: bool in [false, true]:
			var world := _world()
			world.casts = {10: {"cells": _leaf(count, reversed), "coverage": _leaf(count, not reversed)}}
			_assert_exact(world, "coordinate count %d reverse %s" % [count, reversed])
			equal(Dynamic.admitted_leaf_count(Dynamic.lanes(world)), 2 if count >= Dynamic.MIN_LEAF_ENTRIES else 0, "actual leaf admission threshold")
	var boundaries := _leaf(8)
	boundaries[Vector2i(-2_147_483_648, 2_147_483_647)] = -2_147_483_648
	boundaries[Vector2i(2_147_483_647, -2_147_483_648)] = 2_147_483_647
	boundaries[Vector2i.ZERO] = 0
	var world := _world()
	world.products = {2: {"cells": boundaries, "coverage": boundaries}}
	_assert_exact(world, "signed extrema, explicit zero and repeated alias")


func _test_mixed_parents_and_numbers() -> void:
	var world := _world()
	var parent := {"10": _leaf(13), 10: _leaf(8), Vector2i(-2, 10): _leaf(9), false: _leaf(8), 2.5: _leaf(8)}
	parent[StringName("named-key")] = _leaf(8)
	world.casts = parent
	world.products = {"values": [-9_223_372_036_854_775_807, 9_223_372_036_854_775_807, -0.0, 1.25, true, null, StringName("named-value")]}
	_assert_exact(world, "mixed equal-formatted parents retain existing order and native numeric JSON")
	var oversized := _leaf(8)
	oversized[Vector2i.ZERO] = 2_147_483_648
	world.pending = {"oversized": oversized}
	_assert_exact(world, "int64 map leaf stays on original stable representation")
	var nested: Variant = _leaf(8)
	for unused: int in 20: nested = [nested]
	world.metrics = {"deep": nested}
	equal(Dynamic.admitted_leaf_count(Dynamic.lanes(world)), -1, "deep document declines before conversion")
	_assert_exact(world, "deep whole-document fallback retains original JSON depth")


func _test_token_collisions_and_unicode() -> void:
	var texts: Array[String] = ["", "水🙂ß", "quote\"slash\\\n\t", String.chr(1), Dynamic.CELL_MARKER,
		Dynamic._token(0), Dynamic._token(1), "before\"" + Dynamic._token(0) + "\"after", "before" + Dynamic._token(0) + "after"]
	for text: String in texts:
		var world := _world()
		world.casts = {"cells": _leaf(13), "coverage": _leaf(8), text: [text, {text: text}]}
		_assert_exact(world, "literal or escaped marker collision " + text)


func _test_mutable_aliases() -> void:
	var world := _world()
	var leaf := _leaf(13)
	world.casts = {"cells": leaf}
	var before := Candidate.canonical_bytes(world)
	var revision := world.value_revision
	leaf[Vector2i.ZERO] = 0
	_assert_exact(world, "direct alias adds zero entry")
	check(Candidate.canonical_bytes(world) != before, "zero entry remains observable without revision change")
	leaf[Vector2i.ZERO] = 93
	_assert_exact(world, "direct alias changes amount")
	equal(world.value_revision, revision, "test mutation bypasses revisions")
	var returned := Candidate.canonical_bytes(world)
	returned[returned.size() - 1] ^= 1
	_assert_exact(world, "returned bytes cannot corrupt later assembly")
	leaf.erase(Vector2i.ZERO)
	check(Candidate.canonical_bytes(world) == before, "restoring alias recovers original bytes")


func _test_fallback_and_callbacks() -> void:
	var world := _world()
	var nested := _world()
	check(nested.configure_geometry(Vector2i.ZERO, HexGrid.disk(Vector2i.ZERO, 1)), "nested reentrant hash has different topology")
	var trace: Array[String] = []
	var first := RecordingKey.new()
	first.label = "10"
	first.trace = trace
	first.nested_world = nested
	var second := RecordingKey.new()
	second.label = "2"
	second.trace = trace
	world.casts = {"cells": _leaf(13), first: "first", second: "second", 10: "integer", "10": "string"}
	equal(Dynamic.admitted_leaf_count(Dynamic.lanes(world)), -1, "opaque keys decline fast conversion")
	equal(Dynamic.admission_diagnostic(Dynamic.lanes(world)).get("reason"), "unsupported-type", "opaque diagnostic gives rejection reason")
	check(trace.is_empty(), "admission has zero formatting callbacks")
	var baseline_document := Dynamic.baseline_document(world)
	var baseline_trace := trace.duplicate()
	trace.clear()
	equal(Dynamic.document(world), baseline_document, "opaque document exact fallback")
	equal(trace, baseline_trace, "opaque fallback preserves callback order/count")
	trace.clear()
	var expected := Oracle.state_bytes(world)
	trace.clear()
	check(Candidate.canonical_bytes(world) == expected, "reentrant different topology preserves invocation fragments")
	world.casts = {"cells": _leaf(8), "packed": PackedInt64Array([1, 2])}
	equal(Dynamic.admitted_leaf_count(Dynamic.lanes(world)), -1, "packed extension declines bounded prototype")
	var rejected := Dynamic.admission_diagnostic(Dynamic.lanes(world))
	equal(rejected.get("type"), "PackedInt64Array", "packed rejection identifies native provenance type")
	check(String(rejected.get("path", "")).ends_with("/packed"), "packed rejection names path without formatting opaque values")
	_assert_exact(world, "packed value exact original document")
	var extension := ExtendedWorld.new()
	check(extension.configure_geometry(Vector2i.ZERO, HexGrid.disk(Vector2i.ZERO, 1)), "extension geometry configured")
	check(Candidate.canonical_bytes(extension).is_empty(), "helper retains exact-concrete admission")
	equal(extension.state_hash(), Oracle.hash_bytes(extension._state_hash_bytes()), "public subclass hash still owns bytes")
