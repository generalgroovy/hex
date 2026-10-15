extends RefCounted
## Setup-only massing for two existing solid structures. Texture pixels stay
## inside authoritative footprints; facade relief is not playable elevation.
const VERSION := "existing-tall-facades-1"
const SPECS := {
	105: {"style": "spire", "size": Vector2i(192, 160), "face": 100, "family": "observatory"},
	108: {"style": "service_tower", "size": Vector2i(144, 144), "face": 92, "family": "limestone"},
}
const WallSkin = preload("res://src/presentation/practice_wall_skin.gd")

static func supports(building: Dictionary) -> bool:
	var spec: Dictionary = SPECS.get(int(building.get("id", 0)), {})
	if spec.is_empty(): return false
	var bounds := SanctumCampusLayout._parse_bounds(building.get("bounds", []))
	return String(building.get("style", "")) == String(spec.style) and bounds.size == spec.size and String(building.get("occlusion_policy", "")) == "los_cutaway" and not bool(building.get("vaultable", true))


static func compose_building(building: Dictionary, slate: Image, facade_tile: Image) -> Image:
	if not supports(building): return null
	var id := int(building.id)
	var spec: Dictionary = SPECS[id]
	return compose(spec.size, int(spec.face), String(spec.family), slate, facade_tile, id == 105)


static func compose(size: Vector2i, face_height: int, family: String, slate: Image, facade_tile: Image, spire: bool) -> Image:
	if size.x < 100 or size.y < 100 or size.x > 256 or size.y > 256 or face_height < 60 or face_height >= size.y - 24 or not WallSkin.PALETTES.has(family) or slate == null or slate.get_size() != Vector2i(128, 128): return null
	if facade_tile == null or facade_tile.get_size() != Vector2i(128, 128) or facade_tile.get_format() != Image.FORMAT_RGBA8: return null
	var colors: Array[Color] = []
	for code: String in WallSkin.PALETTES[family]: colors.append(Color(code))
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color("4b3025")) # Retain a solid boundary beneath the existing frame.
	var face_y := size.y - face_height
	var side := 14 if spire else 18
	var cap := Rect2i(3, 3, size.x - side - 6, face_y - 3)
	var stone_regions: Array[Rect2i] = [Rect2i(3, face_y, size.x - 6, face_height - 3), Rect2i(size.x - side - 3, 3, side, size.y - 6), Rect2i(3, 3, size.x - side - 6, 2)]
	for y: int in range(cap.position.y, cap.end.y):
		for x: int in range(cap.position.x, cap.end.x):
			image.set_pixel(x, y, slate.get_pixel(posmod(x - 3, 128), posmod(y - 3, 128)))
	# Broad continuous face, narrow dark east plane; no horizontal stair shelves.
	image.fill_rect(Rect2i(3, face_y, size.x - side - 6, face_height - 3), colors[2])
	image.fill_rect(Rect2i(size.x - side - 3, 3, side, size.y - 6), colors[1])
	image.fill_rect(Rect2i(size.x - side - 3, 3, 3, size.y - 6), colors[5])
	image.fill_rect(Rect2i(3, face_y, size.x - 6, 3), colors[0])
	image.fill_rect(Rect2i(3, face_y + 3, size.x - side - 6, 3), colors[4])
	image.fill_rect(Rect2i(3, size.y - 8, size.x - 6, 5), colors[1])
	image.fill_rect(Rect2i(3, size.y - 5, size.x - 6, 2), colors[5])
	# Tall vertical supports have a single uninterrupted ground contact.
	var columns: Array[int] = [12, size.x - side - 23]
	if spire: columns.insert(1, size.x / 2 - 9)
	for x: int in columns:
		image.fill_rect(Rect2i(x, face_y + 6, 12, face_height - 14), colors[0])
		image.fill_rect(Rect2i(x, face_y + 6, 8, face_height - 15), colors[3])
		image.fill_rect(Rect2i(x, face_y + 6, 2, face_height - 15), colors[4])
	# Sparse shallow panel seams differ from the close-set low-cover masonry.
	for y: int in range(face_y + 30, size.y - 12, 32):
		image.fill_rect(Rect2i(28, y, maxi(1, size.x - side - 60), 1), colors[5])
	if spire:
		# A nested, solid raised roof plate reads as a spire crown, not an opening.
		var crown := Rect2i(size.x / 2 - 26, 10, 40, maxi(12, face_y - 24))
		stone_regions.append(crown)
		image.fill_rect(crown, colors[0])
		image.fill_rect(Rect2i(crown.position, Vector2i(crown.size.x - 5, crown.size.y - 5)), colors[2])
		image.fill_rect(Rect2i(crown.position, Vector2i(crown.size.x - 5, 3)), colors[4])
		image.fill_rect(Rect2i(crown.position + Vector2i(17, 6), Vector2i(2, crown.size.y - 14)), colors[7])
	else:
		# Parapet merlons sit on a continuous solid band; no cuts expose ground.
		image.fill_rect(Rect2i(6, 7, size.x - side - 12, 9), colors[1])
		stone_regions.append(Rect2i(6, 7, size.x - side - 12, 9))
		for x: int in range(10, size.x - side - 14, 28):
			stone_regions.append(Rect2i(x, 5, 14, 8))
			image.fill_rect(Rect2i(x, 5, 14, 8), colors[0])
			image.fill_rect(Rect2i(x, 5, 11, 5), colors[3])
			image.fill_rect(Rect2i(x, 5, 11, 2), colors[4])
	image.fill_rect(Rect2i(3, 3, size.x - side - 6, 2), colors[4])
	# Keep the admitted massing/lighting, but derive its masonry and grain from
	# the same approved128px facade tile as adjacent buildings. Tile scale stays1:1.
	var base_value := _value(colors[2])
	for y: int in range(3, size.y - 3):
		for x: int in range(3, size.x - 3):
			var selected := false
			for region: Rect2i in stone_regions:
				if region.has_point(Vector2i(x, y)): selected = true; break
			if not selected: continue
			var plane := image.get_pixel(x, y)
			var source := facade_tile.get_pixel(posmod(x - 3, 128), posmod(y - face_y, 128))
			var light := clampf(_value(plane) / base_value, 0.45, 1.38)
			var stone := Color(source.r * light, source.g * light, source.b * light, 1.0)
			var shaded := stone.lerp(plane, 0.12)
			shaded.a = 1.0
			image.set_pixel(x, y, shaded)
	return image

static func _value(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722

