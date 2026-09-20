extends SceneTree

const ROOT := "res://art_batches/character_style_v1/template_small/south-pilot-v1/review-v1/"
const SOURCE := "res://art_batches/character_style_v1/template_v2/small-south-base-v1.png"
const PAIR := "res://art_batches/character_style_v1/template_v2/small-ne-guide-first-pair-v1.png"

func _initialize() -> void:
	var source_hash := FileAccess.get_sha256(SOURCE)
	var pair_hash := FileAccess.get_sha256(PAIR)
	if source_hash != "b67f0ae46673f51350f56cb7d23764109a01a0bfbd45b4bbc36a43fa5e4852e3" \
		or pair_hash != "87f3ebc74b62b9c859201a76a39f567f47886e5761e0826def3637093bf7404a":
		push_error("Immutable generic source changed")
		quit(1)
		return
	var image := Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(ROOT + "template_small-partial-review.png")) != OK:
		quit(1)
		return
	var used := image.get_used_rect()
	if image.get_size() != Vector2i(96, 96) or used.size.y != 58 or used.end.y != 84 \
		or not Rect2i(1, 1, 94, 94).encloses(used) or image.detect_alpha() != Image.ALPHA_BIT:
		push_error("Partial template failed native alpha/size/feet/gutter validation")
		quit(1)
		return
	var evidence := []
	for scale: int in [1, 4]:
		for tone: String in ["light", "dark"]:
			var path := ROOT + ("native" if scale == 1 else "4x") + "-" + tone + ".png"
			if FileAccess.file_exists(path):
				push_error("Refusing to overwrite proof")
				quit(1)
				return
			var proof := Image.create(96, 96, false, Image.FORMAT_RGBA8)
			proof.fill(Color("e5e0ce") if tone == "light" else Color("17252b"))
			proof.blend_rect(image, Rect2i(0, 0, 96, 96), Vector2i.ZERO)
			proof.resize(96 * scale, 96 * scale, Image.INTERPOLATE_NEAREST)
			if proof.save_png(path) != OK:
				quit(1)
				return
			evidence.append({"path": path, "sha256": FileAccess.get_sha256(path)})
	var unchanged := source_hash == FileAccess.get_sha256(SOURCE) and pair_hash == FileAccess.get_sha256(PAIR)
	var report := {"status": "partial_technical_review_only", "asset_kind": "neutral_body_template", "id": "template_small",
		"frame_count": 1, "required_frame_count": 80, "complete_coverage": false, "live_promotion": false,
		"occupied_bounds": [used.position.x, used.position.y, used.size.x, used.size.y], "last_opaque_y": used.end.y - 1,
		"binary_alpha": true, "transparent_gutters": true, "sources_unchanged": unchanged,
		"candidate_sha256": FileAccess.get_sha256(ROOT + "template_small-partial-review.png"), "evidence": evidence,
		"visual_limits": "Only front standing pose; no walking/animation acceptance. NE pair held separately for unresolved uniform source-board calibration."}
	var file := FileAccess.open(ROOT + "technical-review.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	print("PASS: Small neutral South1/80; 58px; actualfeet83; binaryalpha; sourceimmutable; native/4x light/dark proof. Not full template acceptance.")
	quit(0 if unchanged else 1)
