extends SceneTree

const Prep = preload("res://scripts/build_illustrated_visuals.gd")
const SOURCE := "res://reference/art/cast_expansion_v1/"
const DEST := "res://assets/sprites/champions_v3/expansion_v1/"
const STATES := [0, 4, 5, 0, 1, 3, 6, 7, 2, 2]
const FRONT_COLUMNS := {"oh_tipi": 0, "s_wayne": 1, "red_baron": 2, "grace_reava": 3, "wa_bidi": 4}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DEST)
	var front := Image.load_from_file(SOURCE + "front-contacts-source.png")
	assert(front != null)
	var corrected_contact := Image.load_from_file(SOURCE + "oh-tipi-front-contact-b-source.png")
	assert(corrected_contact != null)
	var foundation := Image.create(768, 2880, false, Image.FORMAT_RGBA8)
	for champion: String in FRONT_COLUMNS:
		var page: Image
		var height := 68 if champion == "oh_tipi" else (76 if champion == "red_baron" else 58)
		if champion in ["grace_reava", "wa_bidi"]:
			page = compile_sheet(Image.load_from_file(SOURCE + champion + "-source.png"), height)
		else:
			var base := Image.new()
			assert(base.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/sprites/champions_v3/foundation/runtime_atlas_eight_v14.png")) == OK)
			page = base.get_region(Rect2i(0, int(FRONT_COLUMNS[champion]) * 960, 768, 960))
		# Only replace reviewed front contacts. Other directions retain their
		# authored cells; no fake mirroring of asymmetrical tails/clothing.
		var neutral := front_cell(front, int(FRONT_COLUMNS[champion]), 0)
		for entry: Array in [[4, 0], [8, 1], [5, 0], [9, 1], [6, 2]]:
			# Only the reviewed middle-left cell is consumed from the correction.
			# Other cells in that generated edit drifted and remain unused.
			var input := corrected_contact if champion == "oh_tipi" and int(entry[1]) == 1 else front
			var pose := front_cell(input, int(FRONT_COLUMNS[champion]), int(entry[1]))
			var target_height := height
			if int(entry[0]) == 6:
				target_height = clampi(roundi(float(pose.get_height()) * height / neutral.get_height()), height / 2, height)
			var cell := pack(pose, target_height)
			cell = Prep.ink_and_palette(cell)
			page.fill_rect(Rect2i(0, int(entry[0]) * 96, 96, 96), Color.TRANSPARENT)
			page.blit_rect(cell, Rect2i(0, 0, 96, 96), Vector2i(0, int(entry[0]) * 96))
		Prep.write_image(page, DEST + champion + ".png")
		if champion in ["oh_tipi", "s_wayne", "red_baron"]:
			foundation.blit_rect(page, Rect2i(0, 0, 768, 960), Vector2i(0, int(FRONT_COLUMNS[champion]) * 960))
	Prep.write_image(foundation, "res://assets/sprites/champions_v3/foundation/runtime_atlas_eight_v15.png")
	quit(0)


static func front_cell(image: Image, column: int, row: int) -> Image:
	var top: int = [64, 390, 700][row]
	var bottom: int = [386, 695, 1004][row]
	var left := roundi(float(column) * image.get_width() / 5)
	var right := roundi(float(column + 1) * image.get_width() / 5)
	var cell := image.get_region(Rect2i(left, top, right - left, bottom - top))
	return Prep.subject_crop(Prep.clean_alpha(Prep.import_cutout(cell)))


static func pack(pose: Image, height: int) -> Image:
	var width := clampi(roundi(float(pose.get_width()) * height / pose.get_height()), 16, 86)
	pose.resize(width, height, Image.INTERPOLATE_LANCZOS)
	pose = Prep.clean_alpha(pose)
	var cell := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	cell.blit_rect(pose, Rect2i(Vector2i.ZERO, pose.get_size()), Vector2i(48 - width / 2, 84 - height))
	return cell


static func compile_sheet(source: Image, height: int) -> Image:
	assert(source != null)
	var page := Image.create(768, 960, false, Image.FORMAT_RGBA8)
	for direction: int in range(8):
		var neutral := Prep.subject_crop(Prep.clean_alpha(Prep.import_cutout(Prep.grid_cell(source, direction, 0, 8))))
		for state: int in range(STATES.size()):
			var pose := Prep.subject_crop(Prep.clean_alpha(Prep.import_cutout(Prep.grid_cell(source, direction, STATES[state], 8))))
			var target := height
			if state in [1, 6, 7]:
				target = clampi(roundi(float(pose.get_height()) * height / neutral.get_height()), height / 2, height)
			page.blit_rect(pack(pose, target), Rect2i(0, 0, 96, 96), Vector2i(direction * 96, state * 96))
	return Prep.ink_and_palette(page)
