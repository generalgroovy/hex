extends SceneTree

# Reproducible asset preparation only. Original pixels are image-generated;
# this compiler crops the declared grids, packs cells and anchors feet.
const SOURCE := "res://reference/art/wellspring_v3/"
const DEST := "res://assets/environment/wellspring_v3/"
const STATES := [0, 4, 5, 0, 1, 3, 6, 7, 2, 2]
const NAMES := ["oh_tipi", "s_wayne", "red_baron"]
const HEIGHTS := [68, 58, 76]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DEST)
	var surfaces := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	var props := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	for entry: Array in [["surfaces-source.png", surfaces, false], ["props-clean-source.png", props, true]]:
		var source := Image.load_from_file(SOURCE + String(entry[0]))
		assert(source != null and not source.is_empty(), "Missing source art")
		for y: int in range(4):
			for x: int in range(4):
				var cell := grid_cell(source, x, y, 4)
				if bool(entry[2]):
					cell = import_cutout(cell)
					cell = clean_alpha(cell)
					cell = cell.get_region(cell.get_used_rect())
					var scale_factor := minf(120.0 / cell.get_width(), 120.0 / cell.get_height())
					cell.resize(maxi(1, roundi(cell.get_width() * scale_factor)), maxi(1, roundi(cell.get_height() * scale_factor)), Image.INTERPOLATE_LANCZOS)
					cell = clean_alpha(cell)
					props.blit_rect(cell, Rect2i(Vector2i.ZERO, cell.get_size()), Vector2i(x * 128 + (128 - cell.get_width()) / 2, y * 128 + 124 - cell.get_height()))
				else:
					cell.resize(128, 128, Image.INTERPOLATE_LANCZOS)
					cell.convert(Image.FORMAT_RGBA8)
					surfaces.blit_rect(cell, Rect2i(0, 0, 128, 128), Vector2i(x * 128, y * 128))
	write_image(surfaces, DEST + "surfaces.png")
	write_image(props, DEST + "props.png")
	var atlas := Image.create(768, 2880, false, Image.FORMAT_RGBA8)
	# Author/template order is small -> middle -> large, runtime row IDs unchanged.
	for champion_index: int in [1, 0, 2]:
		var body_source := SOURCE if champion_index == 2 else "res://reference/art/clarity_v1/"
		var source := Image.load_from_file(body_source + NAMES[champion_index] + "-source.png")
		assert(source != null and not source.is_empty())
		for direction: int in range(8):
			var neutral_cell := grid_cell(source, direction, 0, 8)
			if champion_index != 2:
				neutral_cell = import_cutout(neutral_cell, true)
			var neutral := subject_crop(clean_alpha(neutral_cell))
			var neutral_height := neutral.get_used_rect().size.y
			assert(neutral_height > 40)
			for state_index: int in range(STATES.size()):
				var pose_cell := grid_cell(source, direction, STATES[state_index], 8)
				if champion_index != 2:
					pose_cell = import_cutout(pose_cell, true)
				var pose := subject_crop(clean_alpha(pose_cell))
				# Upright direction references share the authored envelope. Crouched
				# actions use that direction's neutral scale, never stretch to stand.
				var target_height: int = HEIGHTS[champion_index]
				if state_index in [1, 6, 7]:
					target_height = clampi(roundi(float(pose.get_height()) * HEIGHTS[champion_index] / neutral_height), HEIGHTS[champion_index] / 2, HEIGHTS[champion_index])
				var target_width := clampi(roundi(float(pose.get_width()) * target_height / pose.get_height()), 16, 86)
				pose.resize(target_width, target_height, Image.INTERPOLATE_LANCZOS)
				pose = clean_alpha(pose)
				var offset := Vector2i(48 - target_width / 2, 84 - target_height)
				# Hit/impact reuses the same torso model with a bounded recoil pose.
				if state_index == 3:
					offset.x += 2 if direction < 4 else -2
				atlas.blit_rect(pose, Rect2i(Vector2i.ZERO, pose.get_size()), Vector2i(direction * 96, (champion_index * 10 + state_index) * 96) + offset)
	atlas = ink_and_palette(atlas)
	write_image(atlas, "res://assets/sprites/champions_v3/foundation/runtime_atlas_eight_v14.png")
	quit(0)


static func grid_cell(source: Image, x: int, y: int, count: int) -> Image:
	var left := roundi(float(x) * source.get_width() / count)
	var top := roundi(float(y) * source.get_height() / count)
	var right := roundi(float(x + 1) * source.get_width() / count)
	var bottom := roundi(float(y + 1) * source.get_height() / count)
	return source.get_region(Rect2i(left, top, right - left, bottom - top))


static func clean_alpha(source: Image) -> Image:
	source.convert(Image.FORMAT_RGBA8)
	for y: int in range(source.get_height()):
		for x: int in range(source.get_width()):
			var color := source.get_pixel(x, y)
			color.a = 1.0 if color.a >= 0.5 else 0.0
			if color.a == 0.0:
				color = Color.TRANSPARENT
			source.set_pixel(x, y, color)
	return source


static func import_cutout(source: Image, black_matte: bool = false) -> Image:
	# Generated prop sources can contain an opaque preview matte. Treat that as
	# an explicit import format: remove only border-connected near-white neutral
	# pixels. Interior highlights and the immutable source art stay untouched.
	source.convert(Image.FORMAT_RGBA8)
	var visited := PackedByteArray()
	visited.resize(source.get_width() * source.get_height())
	var queue: Array[Vector2i] = []
	for x: int in range(source.get_width()):
		queue.append(Vector2i(x, 0))
		queue.append(Vector2i(x, source.get_height() - 1))
	for y: int in range(source.get_height()):
		queue.append(Vector2i(0, y))
		queue.append(Vector2i(source.get_width() - 1, y))
	var cursor := 0
	while cursor < queue.size():
		var point := queue[cursor]
		cursor += 1
		if point.x < 0 or point.y < 0 or point.x >= source.get_width() or point.y >= source.get_height():
			continue
		var key := point.y * source.get_width() + point.x
		if visited[key] != 0:
			continue
		visited[key] = 1
		var color := source.get_pixelv(point)
		var low := minf(color.r, minf(color.g, color.b))
		var high := maxf(color.r, maxf(color.g, color.b))
		var matte := high < 0.035 if black_matte else (low >= 0.78 and high - low <= 0.065)
		if color.a > 0.05 and not matte:
			continue
		source.set_pixelv(point, Color.TRANSPARENT)
		for delta: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			queue.append(point + delta)
	return source


static func subject_crop(source: Image) -> Image:
	# Generated contact sheets are not guaranteed to respect exact cell margins.
	# Locate the connected body before cropping so a neighboring foot fragment
	# cannot change its scale or enter the packed frame. Source is never altered.
	var visited := PackedByteArray()
	visited.resize(source.get_width() * source.get_height())
	var best := Rect2i()
	var largest := 0
	for y: int in range(source.get_height()):
		for x: int in range(source.get_width()):
			var key := y * source.get_width() + x
			if visited[key] != 0 or source.get_pixel(x, y).a < 0.5:
				continue
			var queue: Array[Vector2i] = [Vector2i(x, y)]
			visited[key] = 1
			var cursor := 0
			var bounds := Rect2i(x, y, 1, 1)
			while cursor < queue.size():
				var point := queue[cursor]
				cursor += 1
				bounds = bounds.merge(Rect2i(point, Vector2i.ONE))
				for delta: Vector2i in [Vector2i(-1,-1), Vector2i(0,-1), Vector2i(1,-1), Vector2i(-1,0), Vector2i(1,0), Vector2i(-1,1), Vector2i(0,1), Vector2i(1,1)]:
					var near := point + delta
					if near.x < 0 or near.y < 0 or near.x >= source.get_width() or near.y >= source.get_height():
						continue
					var index := near.y * source.get_width() + near.x
					if visited[index] == 0 and source.get_pixelv(near).a >= 0.5:
						visited[index] = 1
						queue.append(near)
			if queue.size() > largest:
				largest = queue.size()
				best = bounds
	assert(largest > 50, "No connected champion body in source cell")
	return source.get_region(best)


static func write_image(image: Image, path: String) -> void:
	assert(image.save_png(path) == OK)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(image.get_data())
	print(JSON.stringify({"path": path, "size": image.get_size(), "sha256": FileAccess.get_sha256(path), "rgba_sha256": hash.finish().hex_encode()}))


static func ink_and_palette(source: Image) -> Image:
	var colors: Array[Color] = []
	for value: String in ["1c1923","22242b","2c3441","39485a","4f6072","71808a","929c9d","bbc2b7", "092f43","104659","155c70","1e7389","288ea0","46a7b5","76c7cb","ace3df", "272a23","35422e","485638","647248","839254","a6ae70","c4c48e","d7d7b0", "514846","6e6054","8e7d65","ae9b7b","c5b898","dbd0ae","ece2c8","fff1da", "513324","6c4830","855c39","a5784c","c79768","ddb183","ebc699","f4dab5", "251d1c","372520","4b3025","623e2c","795033","95633b","ac7c4b","c9975b", "351522","4b182b","671b31","811f38","9e2a41","b93d4e","d25a5b","e37a71", "55462d","705b36","8f7040","a88a4c","c4a361","dac080","eed597","fae7bb"]:
		colors.append(Color(value))
	var palette_cache: Dictionary = {}
	var output := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	for y: int in range(source.get_height()):
		for x: int in range(source.get_width()):
			var pixel := source.get_pixel(x, y)
			if pixel.a <= 0.5:
				# Cell-local ink cannot bleed into the neighboring animation.
				for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var near := Vector2i(x, y) + offset
					if near.x >= 0 and near.y >= 0 and near.x < source.get_width() and near.y < source.get_height() and near.x / 96 == x / 96 and near.y / 96 == y / 96 and source.get_pixelv(near).a > 0.5:
						output.set_pixel(x, y, colors[0])
						break
				continue
			var key := pixel.to_rgba32()
			if not palette_cache.has(key):
				var best := colors[0]
				var distance := INF
				for candidate: Color in colors:
					var delta := Vector3(pixel.r - candidate.r, pixel.g - candidate.g, pixel.b - candidate.b)
					var squared := delta.length_squared()
					if squared < distance:
						distance = squared
						best = candidate
				palette_cache[key] = best
			output.set_pixel(x, y, palette_cache[key])
	return output
