extends SceneTree

# Candidate-only technical proof, adapted from south-pilot-v1/review-proof.gd.
# No pose synthesis, runtime resources or saved settings are touched.
const ROOT := "res://art_batches/character_style_v1/template_small/south-pilot-v3/"
const SOURCE_SHA := "97f1cf793f43f8a1c7126f08972e9cacbdfa070c2501db1f8af1a1baaf4ee5ac"
const Importer := preload("res://reference/art/neutral_body_templates_v1/build_pack.gd")

func _initialize() -> void:
	if FileAccess.get_sha256(ROOT + "source-corrected-v1.png") != SOURCE_SHA:
		_fail("Immutable source changed")
		return
	var path := ROOT + "review-v1/template_small-partial-review.png"
	var image := Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK \
		or image.get_size() != Vector2i(288, 96) or image.detect_alpha() != Image.ALPHA_BIT:
		_fail("Expected three native cells with binary alpha")
		return
	var frames: Array[Dictionary] = []
	for index: int in range(3):
		var cell := image.get_region(Rect2i(index * 96, 0, 96, 96))
		var used := cell.get_used_rect()
		if used.size.y != 58 or used.end.y != 84 or not Rect2i(1, 1, 94, 94).encloses(used):
			_fail("Native scale/feet/gutter mismatch")
			return
		frames.append({"slot": index, "bounds": [used.position.x, used.position.y, used.size.x, used.size.y],
			"rgba_sha256": Importer.bytes_sha256(cell.get_data())})
	if frames[1].rgba_sha256 == frames[2].rgba_sha256:
		_fail("Walking contacts duplicate")
		return
	var evidence: Array[Dictionary] = []
	for scale: int in [1, 4]:
		for tone: String in ["light", "dark"]:
			var proof_path := ROOT + "review-v1/" + ("native" if scale == 1 else "4x") + "-" + tone + ".png"
			if FileAccess.file_exists(proof_path):
				_fail("Refusing to overwrite proof")
				return
			var proof := Image.create(288, 96, false, Image.FORMAT_RGBA8)
			proof.fill(Color("e5e0ce") if tone == "light" else Color("17252b"))
			proof.blend_rect(image, Rect2i(0, 0, 288, 96), Vector2i.ZERO)
			proof.resize(288 * scale, 96 * scale, Image.INTERPOLATE_NEAREST)
			if proof.save_png(proof_path) != OK:
				_fail("Cannot save proof")
				return
			evidence.append({"path": proof_path, "sha256": FileAccess.get_sha256(proof_path)})
	var report := {"status": "partial_technical_review_only", "asset_kind": "neutral_body_template",
		"frame_count": 3, "required_frame_count": 80, "complete_coverage": false, "live_promotion": false,
		"binary_alpha": true, "transparent_gutters": true, "same_global_scale": true,
		"source_sha256": SOURCE_SHA, "candidate_sha256": FileAccess.get_sha256(path),
		"frames": frames, "evidence": evidence,
		"limits": "South stand and opposite contacts only; distinct hashes are not anatomy, animation or human acceptance."}
	var file := FileAccess.open(ROOT + "review-v1/technical-review.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	print("PASS: Small South 3/80, 58px each, feet83, binary alpha, gutters, unique walk contacts; candidate only")
	quit(0)

func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
