extends SceneTree

const ROOT := "res://art_batches/character_style_v1/wireframe_motion_v2/moving_cast_feasibility/"


func _sha(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _initialize() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "candidate-manifest.json"))
	if not parsed is Dictionary:
		push_error("Candidate manifest missing")
		quit(1)
		return
	var manifest: Dictionary = parsed
	assert(FileAccess.get_sha256("res://assets/sprites/wireframe_motion_v2/manifest.json") == String(manifest["w2_runtime_manifest_sha256"]))
	var image := Image.load_from_file(ROOT + String(manifest["page"]))
	image.convert(Image.FORMAT_RGBA8)
	assert(_sha(image.get_data()) == String(manifest["page_rgba_sha256"]))
	var atlas := ImageTexture.create_from_image(image)
	var checks := 0
	var failures := 0
	var first_failure := ""
	for entry: Dictionary in manifest["frames"]:
		var region: Array = entry["region"]
		var margin: Array = entry["margin"]
		var view := AtlasTexture.new()
		view.atlas = atlas
		view.region = Rect2(float(region[0]), float(region[1]), float(region[2]), float(region[3]))
		view.margin = Rect2(float(margin[0]), float(margin[1]), float(margin[2]), float(margin[3]))
		view.filter_clip = true
		var logical := view.get_image()
		if logical != null:
			logical.convert(Image.FORMAT_RGBA8)
		var valid := view.get_size() == Vector2(96, 96) and logical != null and logical.get_size() == Vector2i(96, 96)
		if valid:
			valid = _sha(logical.get_data()) == String(entry["rgba_sha256"])
		if not valid:
			failures += 1
			if first_failure.is_empty():
				first_failure = "travel=%s aim=%s phase=%s upper=%s view_size=%s image_size=%s" % [entry["travel"], entry["aim"], entry["phase"], entry["upper_pose"], view.get_size(), logical.get_size() if logical != null else Vector2i.ZERO]
		checks += 1
	var receipt := {"status":"passed" if failures == 0 else "failed", "checks":checks, "failures":failures,
		"first_failure":first_failure,"engine":Engine.get_version_info()["string"],
		"candidate_manifest_sha256":FileAccess.get_sha256(ROOT + "candidate-manifest.json"),
		"w2_runtime_manifest_unchanged":FileAccess.get_sha256("res://assets/sprites/wireframe_motion_v2/manifest.json") == String(manifest["w2_runtime_manifest_sha256"]),
		"scope":"Real AtlasTexture margin/get_image logical 96x96 pixel roundtrip; not viewport rendering or production migration"}
	var file := FileAccess.open(ROOT + "atlas-roundtrip-evidence.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt, "  ") + "\n")
	file.close()
	print("%s: AtlasTexture logical96 roundtrip checks=%d failures=%d %s" % ["PASS" if failures == 0 else "FAIL",checks,failures,first_failure])
	quit(0 if failures == 0 else 1)
