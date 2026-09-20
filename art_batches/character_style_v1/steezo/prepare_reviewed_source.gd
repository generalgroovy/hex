extends SceneTree

# Steezo-only, hash-locked background extraction. No anatomy/colour synthesis.
const Builder = preload("res://scripts/build_character_style_pack.gd")
const ROOT := "res://art_batches/character_style_v1/steezo/"
const HASH := "8a3c4f79d5840535550ed099eaf8fc1ed9db23b2c18cba588fa124e65ad706f0"
const HOLES := [
	{"state":"hit/south_west","seed":[1044,488],"pixels":26,"reason":"Reviewed empty gap between recoil forearm and coat"},
	{"state":"sprint/east","seed":[323,745],"pixels":65,"reason":"Reviewed empty gap behind bent rear arm"},
	{"state":"sprint/west","seed":[902,747],"pixels":56,"reason":"Reviewed mirrored empty gap behind bent rear arm"}
]

func _initialize() -> void:
	var gait := "--gait" in OS.get_cmdline_user_args()
	var expected_hash := "4a8846a89c121e6cbfabe53fe87d818f2f28de42ee834d080e2c7dfcdc7a9987" if gait else HASH
	var holes: Array = [
		{"state":"sprint_b/north_east","seed":[731,595],"pixels":160,"reason":"Reviewed empty gap behind bent arm, white patch in native capture"},
		{"state":"sprint_b/north_west","seed":[1261,593],"pixels":258,"reason":"Reviewed mirrored empty gap behind bent arm, white patch in native capture"}
	] if gait else HOLES
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + ("source-layout-v2.json" if gait else "source-layout-v1.json")))
	var entry: Dictionary = spec.pages[1 if gait else 0]
	if FileAccess.get_sha256(entry.path) != expected_hash: _fail("Source hash changed"); return
	var original := Image.load_from_file(entry.path)
	original.convert(Image.FORMAT_RGBA8)
	var checked := Builder.inspect_source(original, entry)
	if not String(checked.error).is_empty(): _fail(checked.error); return
	var cleaned: Image = original.duplicate()
	var mask: Image = checked.removal_mask
	for y: int in range(original.get_height()):
		for x: int in range(original.get_width()):
			if mask.get_pixel(x,y).r > 0.0: cleaned.set_pixel(x,y,Color.TRANSPARENT)
	var removed_interior := 0
	for hole: Dictionary in holes:
		var pending: Array[Vector2i] = [Vector2i(hole.seed[0],hole.seed[1])]
		var visited: Dictionary = {}
		var pixels: Array[Vector2i] = []
		while not pending.is_empty():
			var point: Vector2i = pending.pop_back()
			if visited.has(point): continue
			visited[point] = true
			if not Rect2i(Vector2i.ZERO,original.get_size()).has_point(point) or not Builder.is_checker(original.get_pixelv(point), entry.background_removal): continue
			pixels.append(point)
			if pixels.size() > hole.pixels: _fail("Interior seed escaped its reviewed exact component"); return
			for step: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]: pending.append(point+step)
		if pixels.size() != hole.pixels: _fail("Interior component changed"); return
		for point: Vector2i in pixels:
			cleaned.set_pixelv(point,Color.TRANSPARENT)
			mask.set_pixelv(point,Color.WHITE)
		removed_interior += pixels.size()
	# Exact unchanged-pixel guard; all edits are represented by the retained mask.
	for y: int in range(original.get_height()):
		for x: int in range(original.get_width()):
			if mask.get_pixel(x,y).r == 0.0 and original.get_pixel(x,y) != cleaned.get_pixel(x,y): _fail("Non-mask pixel changed"); return
	var output := ROOT + ("reviewed-gait-v3" if gait else "reviewed-source-v2")
	if DirAccess.dir_exists_absolute(output): _fail("Will not overwrite prior source preparation"); return
	if DirAccess.make_dir_recursive_absolute(output) != OK: _fail("Output unavailable"); return
	if cleaned.save_png(output + "/body-source.png") != OK or mask.save_png(output + "/exact-removal-mask.png") != OK: _fail("Could not save source or mask"); return
	var receipt := {"source_sha256":expected_hash,"source_path":entry.path,"derived_sha256":FileAccess.get_sha256(output+"/body-source.png"),"mask_sha256":FileAccess.get_sha256(output+"/exact-removal-mask.png"),"authorization":"User-authorized reviewed background removal only; parent approved exact enclosed seeds on2026-09-08","interior_components":holes,"interior_removed_pixels":removed_interior,"outer_removed_pixels":checked.removed_pixels,"non_mask_pixels_unchanged":true,"anatomy_synthesis":false}
	FileAccess.open(output+"/receipt.json",FileAccess.WRITE).store_string(JSON.stringify(receipt,"  ")+"\n")
	print("PASS: exact Steezo background mask; ",removed_interior," interior pixels; non-mask RGBA unchanged; ",output)
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
