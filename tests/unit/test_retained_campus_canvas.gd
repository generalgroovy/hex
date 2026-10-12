extends FluxTestSuite
const Retained = preload("res://src/presentation/retained_campus_canvas.gd")

func run() -> int:
	var common: Array = ["fixture-generation", Rect2(10, 20, 1280, 720), Color.WHITE, 2]
	var first := Retained.signatures(common, 120, Vector2(1536, 880), false, true, true, "", ["tile-resource", 3])
	var next_tick := Retained.signatures(common, 121, Vector2(1536, 880), false, true, true, "", ["tile-resource", 3])
	equal(changed_layers(first, next_tick), [3], "animation invalidates only landmark commands while static painter layers stay retained")
	var next_focus := Retained.signatures(common, 120, Vector2(1540, 880), false, true, true, "", ["tile-resource", 3])
	equal(changed_layers(first, next_focus), [1, 3, 4], "proximity text, station activity and landmark occlusion all follow the live focus")
	equal(changed_layers(first, Retained.signatures(common, 120, Vector2(1536, 880), false, false, true, "", ["tile-resource", 3])), [4], "station-title visibility affects the correct painter layer")
	equal(changed_layers(first, Retained.signatures(common, 120, Vector2(1536, 880), false, true, false, "", ["tile-resource", 3])), [1], "practice detail visibility stays live")
	equal(changed_layers(first, Retained.signatures(common, 120, Vector2(1536, 880), false, true, true, "signature_challenge", ["tile-resource", 3])), [1], "court rule labels change immediately with their actual context")
	equal(changed_layers(first, Retained.signatures(common, 120, Vector2(1536, 880), false, true, true, "", ["tile-resource", 4])), [0], "terrain admission updates ground commands")
	var reduced := Retained.signatures(common, 120, Vector2(1536, 880), true, true, true, "", [])
	equal(reduced, Retained.signatures(common, 999, Vector2(1536, 880), true, true, true, "", []), "reduced ambient motion has no unnecessary clock invalidation")
	var changed_common := common.duplicate()
	changed_common[3] = 3
	equal(changed_layers(first, Retained.signatures(changed_common, 120, Vector2(1536, 880), false, true, true, "", ["tile-resource", 3])), [0, 1, 2, 3, 4, 5], "content/font/style/view generation changes invalidate every ordered layer")
	common[0] = "caller mutation"
	equal(first[0][0], "fixture-generation", "retained signatures do not borrow the caller's mutable array")
	var other_layer := first[1].duplicate()
	first[0].append("layer-only mutation")
	equal(first[1], other_layer, "each layer owns its signature storage")
	var canvas := Retained.new()
	check(canvas.show_behind_parent and not canvas.visible, "bounded campus layers start hidden behind existing gameplay drawing")
	equal(canvas.get_child_count(), 6, "six fixed painter layers cannot grow with world or frame count")
	for index: int in 6:
		equal(String(canvas.get_child(index).name), Retained.LAYER_NAMES[index], "child order preserves original campus painter order")
	var stats := canvas.stats()
	stats.layers.clear()
	equal(canvas.stats().layers.size(), 6, "stats are detached from retained ownership")
	canvas.free()
	return finish("retained-campus-canvas")

func changed_layers(before: Array[Array], after: Array[Array]) -> Array[int]:
	var result: Array[int] = []
	for index: int in before.size():
		if before[index] != after[index]: result.append(index)
	return result
