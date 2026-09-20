extends SceneTree

# Read-only projection of the source-specific light-neutral matte. Its measured
# runs guide explicit reviewed rectangles; this is not automatic art approval.
func _initialize() -> void:
	var path := "res://art_batches/character_style_v1/red_baron/full-page-v1.png"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--source="): path = argument.trim_prefix("--source=")
	var source := Image.load_from_file(path)
	if source == null:
		quit(1)
		return
	source.convert(Image.FORMAT_RGBA8)
	var bytes := source.get_data()
	var width := source.get_width()
	var height := source.get_height()
	var rows := PackedInt32Array()
	rows.resize(height)
	var occupied := PackedByteArray()
	occupied.resize(width * height)
	var transparent := 0
	for y: int in range(height):
		for x: int in range(width):
			var i := (y * width + x) * 4
			if bytes[i + 3] == 0: transparent += 1
			var low := mini(bytes[i], mini(bytes[i + 1], bytes[i + 2]))
			var high := maxi(bytes[i], maxi(bytes[i + 1], bytes[i + 2]))
			if bytes[i + 3] > 0 and (low < 170 or high - low > 18):
				occupied[y * width + x] = 1
				rows[y] += 1
	print("SOURCE ", path, " SIZE ", source.get_size(), " TRANSPARENT ", transparent, " HASH ", FileAccess.get_sha256(path))
	var bands := runs(rows)
	print("ROW BANDS ", bands)
	for band: Vector2i in bands:
		var columns := PackedInt32Array()
		columns.resize(width)
		for y: int in range(band.x, band.y):
			for x: int in range(width): columns[x] += occupied[y * width + x]
		print("BAND ", band, " COLUMNS ", runs(columns))
	quit(0)


func runs(values: PackedInt32Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var start := -1
	for i: int in range(values.size() + 1):
		var matches := i < values.size() and values[i] > 0
		if matches and start < 0: start = i
		elif not matches and start >= 0:
			result.append(Vector2i(start, i))
			start = -1
	return result
