extends SceneTree

# Explicit user-approved background cleanup and binary pixel-edge assembly.
# No RGB changes, pose warping, per-pose scaling or original overwrites.
func _initialize() -> void:
	const SOURCE := "res://art_batches/character_style_v1/oh_tipi/gaits-ns-v1.png"
	const OUTPUT := "res://art_batches/character_style_v1/oh_tipi/gaits-ns-alpha-v1.png"
	const MASK := "res://art_batches/character_style_v1/oh_tipi/gaits-ns-alpha-v1-mask.png"
	const AUDIT := "res://art_batches/character_style_v1/oh_tipi/gaits-ns-alpha-v1-audit.json"
	if FileAccess.get_sha256(SOURCE) != "b8788688b2ee7d8e475fccc1d258d1261647f783c614fe916e7928750251645f" or FileAccess.file_exists(OUTPUT):
		push_error("Wrong immutable source or output already exists")
		quit(1)
		return
	var pixels := Image.load_from_file(SOURCE)
	pixels.convert(Image.FORMAT_RGBA8)
	var bytes := pixels.get_data()
	var mask := Image.create(pixels.get_width(), pixels.get_height(), false, Image.FORMAT_RGBA8)
	mask.fill(Color.TRANSPARENT)
	var removed := 0
	var snapped := 0
	for i: int in range(3, bytes.size(), 4):
		var original_alpha := int(bytes[i])
		if original_alpha == 0 or original_alpha == 255:
			continue
		var index := (i - 3) / 4
		if original_alpha < 128:
			bytes[i] = 0
			removed += 1
			mask.set_pixel(index % pixels.get_width(), index / pixels.get_width(), Color.RED)
		else:
			bytes[i] = 255
			snapped += 1
			mask.set_pixel(index % pixels.get_width(), index / pixels.get_width(), Color.CYAN)
	var result := Image.create_from_data(pixels.get_width(), pixels.get_height(), false, Image.FORMAT_RGBA8, bytes)
	if result.save_png(OUTPUT) != OK or mask.save_png(MASK) != OK:
		quit(1)
		return
	var report := {"source": SOURCE, "source_sha256": FileAccess.get_sha256(SOURCE), "output": OUTPUT,
		"output_sha256": FileAccess.get_sha256(OUTPUT), "mask": MASK, "mask_sha256": FileAccess.get_sha256(MASK),
		"authorization": "User approved reviewed background removal and assembly; original retained",
		"method": "one source-wide alpha threshold128; RGB untouched; red removed/cyan opacity snapped",
		"removed_faint_pixels": removed, "snapped_edge_pixels": snapped, "visual_acceptance": false}
	var file := FileAccess.open(AUDIT, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	print("ALPHA CLEANUP: ", removed, " faint pixels removed; ", snapped, " edge alphas snapped; original preserved")
	quit(0)
