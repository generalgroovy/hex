extends RefCounted

# Setup-only pixel masonry for existing rectangular worldbone. All bevels,
# masonry joints and wear are INSIDE its real footprint, including the border.
# The room chooses a quiet material, not a new elemental or collision property.
const VERSION := "practice-masonry-3-relief"
const Terrain = preload("res://src/presentation/hex_environment_layout.gd")
const MAX_EDGE := 1024 # Authored expedition walls reach832px; total residency is separately bounded.
# Visual relief only: these pixels do not describe traversable elevation or a
# projectile height. Thin footprints keep a cap; deeper blocks gain a facade.
const FACE_HEIGHTS := {"limestone": 20, "slate": 30, "coast": 22, "foundry": 38, "observatory": 42, "garden": 16}
const PALETTES := {
	"limestone": ["34372f", "626650", "8a8d70", "b4b396", "d0c7a4", "74795f", "aaa986", "918063"],
	"slate": ["303733", "515e59", "75867b", "a1b0a0", "c0c6ad", "627467", "95a58c", "98846a"],
	"coast": ["323f43", "587179", "799299", "aab9b5", "c4cbbd", "647e83", "a4b4b1", "a39270"],
	"foundry": ["352e2d", "57463e", "856752", "a28c70", "c2ae8a", "715347", "ae9577", "765546"],
	"observatory": ["353541", "575868", "808497", "b0b7c6", "d0d1d5", "6d728a", "b8bcca", "b7a476"],
	"garden": ["303b2e", "52634b", "829074", "adb798", "c9c8a8", "6c805c", "9dac83", "727d4c"],
}


static func family_for(bounds: Rect2i, activities: Array, districts: Array = []) -> String:
	for area: Dictionary in activities:
		if not Rect2(SanctumCampusLayout._parse_bounds(area["bounds"])).has_point(Vector2(bounds.get_center())):
			continue
		match String(area["id"]):
			"cover-garden": return "garden"
			"chain-courtyard", "duel-court": return "slate"
	for district: Dictionary in districts:
		if not Rect2(SanctumCampusLayout._parse_bounds(district["bounds"])).has_point(Vector2(bounds.get_center())): continue
		match String(district.get("environment", "")):
			"grove": return "garden"
			"coast", "foundry", "observatory": return String(district.environment)
	return "limestone"


static func compose(bounds: Rect2i, family: String) -> Image:
	var size := bounds.size
	if size.x < 16 or size.y < 16 or size.x > MAX_EDGE or size.y > MAX_EDGE or not PALETTES.has(family):
		return null
	var colors: Array[Color] = []
	for code: String in PALETTES[family]:
		colors.append(Color(code))
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(colors[0])
	var face_height := mini(int(FACE_HEIGHTS[family]), (size.y - 4) / 2)
	var face_y := size.y - face_height - 2
	var side_width := clampi(size.x / 16, 4, 8)
	var top := Rect2i(2, 2, size.x - 4 - side_width, face_y - 2)
	var front := Rect2i(2, face_y, size.x - 4 - side_width, face_height)
	var side := Rect2i(top.end.x, 2, side_width, size.y - 4)
	image.fill_rect(Rect2i(2, 2, size.x - 4, size.y - 4), colors[1])
	image.fill_rect(top, colors[3])
	# A broad dark east plane and a brighter cap establish a stable light
	# direction. Everything stays inside the opaque, authoritative outer rim.
	image.fill_rect(side, colors[1])
	image.fill_rect(Rect2i(side.position, Vector2i(2, side.size.y)), colors[5])
	# One canonical hex lattice, not a second decorative offset grid.
	var cap_world := Rect2(Vector2(bounds.position + top.position), Vector2(top.size - Vector2i.ONE))
	var seams := Terrain.inlay_lines(cap_world)
	for index: int in range(0, seams.size(), 2):
		var a := Vector2i(seams[index] - Vector2(bounds.position))
		var b := Vector2i(seams[index + 1] - Vector2(bounds.position))
		_line(image, a + Vector2i.DOWN, b + Vector2i.DOWN, colors[4], top)
		_line(image, a, b, colors[2], top)
	# Broken cap wear is sparse and stationary. Never animate masonry as threat.
	for y: int in range(7, face_y - 3, 29):
		for x: int in range(7, top.end.x - 3, 37):
			if posmod(bounds.position.x + x * 13 + bounds.position.y + y * 7, 5) == 0:
				image.fill_rect(Rect2i(x, y, 3, 1), colors[6])
	_draw_face(image, front, family, colors)
	# Continuous bright northwest / dark southeast edges keep clearance obvious.
	image.fill_rect(Rect2i(2, 2, top.size.x, 2), colors[4])
	image.fill_rect(Rect2i(2, 4, 2, face_y - 4), colors[6])
	image.fill_rect(Rect2i(size.x - 3, 2, 1, size.y - 4), colors[0])
	if family == "garden":
		# Small moss clusters adhere to stone; no fake shrub outside worldbone.
		for y: int in range(8, face_y - 3, 48):
			image.fill_rect(Rect2i(4, y, 5, 2), colors[7])
			image.fill_rect(Rect2i(5, y + 2, 3, 2), colors[5])
		for x: int in range(18, top.end.x - 6, 64):
			image.fill_rect(Rect2i(x, 4, 6, 2), colors[7])
	elif family == "slate" and top.size.y >= 9:
		# Bounded bronze corner fasteners distinguish the chain and sparring rooms.
		for point: Vector2i in [Vector2i(6, 6), top.end - Vector2i(7, 7)]:
			image.fill_rect(Rect2i(point, Vector2i(4, 4)).intersection(top), colors[1])
			image.fill_rect(Rect2i(point + Vector2i.ONE, Vector2i(2, 2)).intersection(top), colors[7])
	elif family == "coast":
		# Quiet inset pier joints and paired tie blocks, wholly inside real cover.
		for x: int in range(8, top.end.x - 2, 32):
			_line(image, Vector2i(x, 5), Vector2i(x, face_y - 3), colors[5], top)
			_line(image, Vector2i(x + 2, 5), Vector2i(x + 2, face_y - 3), colors[4], top)
		for y: int in range(10, face_y - 6, 40):
			image.fill_rect(Rect2i(7, y, 4, 4), colors[7])
	elif family == "foundry":
		# Cross ribs and inset grates identify industrial cover without lava/light.
		for y: int in range(10, face_y - 3, 24):
			_line(image, Vector2i(5, y), Vector2i(size.x - 6, y), colors[1], top)
			_line(image, Vector2i(5, y + 2), Vector2i(size.x - 6, y + 2), colors[4], top)
		for x: int in range(10, top.end.x - 2, 48):
			_line(image, Vector2i(x, 6), Vector2i(x, face_y - 4), colors[7], top)
	elif family == "observatory":
		# Brass crosshair plates remain stationary, rectangular and on solid caps.
		for y: int in range(10, face_y - 5, 40):
			for x: int in range(12, top.end.x - 4, 48):
				_line(image, Vector2i(x - 4, y), Vector2i(x + 4, y), colors[7], top)
				_line(image, Vector2i(x, y - 4), Vector2i(x, y + 4), colors[7], top)
	return image


static func _draw_face(image: Image, face: Rect2i, family: String, colors: Array[Color]) -> void:
	# All relief is compiled once into the existing texture. The lower contact
	# course is continuous; dark joints never expose floor or imply a doorway.
	image.fill_rect(face, colors[1])
	image.fill_rect(Rect2i(face.position, Vector2i(face.size.x, 2)), colors[0])
	image.fill_rect(Rect2i(face.position + Vector2i(0, 2), Vector2i(face.size.x, 2)), colors[2])
	var course_height := 10 if family in ["foundry", "observatory"] else 8
	var row := 0
	for y: int in range(face.position.y + 7, face.end.y - 3, course_height):
		image.fill_rect(Rect2i(face.position.x, y, face.size.x, 1), colors[0])
		image.fill_rect(Rect2i(face.position.x, y + 1, face.size.x, 1), colors[5])
		for x: int in range(face.position.x + 12 + posmod(row, 2) * 16, face.end.x - 1, 32):
			var joint_height := mini(course_height - 2, face.end.y - y - 4)
			if joint_height > 0: image.fill_rect(Rect2i(x, y + 2, 1, joint_height), colors[0])
		row += 1
	image.fill_rect(Rect2i(face.position.x, face.end.y - 2, face.size.x, 2), colors[5])
	if face.size.x < 28 or face.size.y < 10: return
	if family in ["slate", "foundry", "observatory"]:
		# Inset merlons/plinth ribs distinguish masonry profiles without adding
		# a notched collision outline, an overhang, or a second draw submission.
		var spacing := 48 if family == "slate" else 64
		for x: int in range(face.position.x + 8, face.end.x - 10, spacing):
			var rib_height := mini(face.size.y - 4, 8) if family == "slate" else face.size.y - 4
			image.fill_rect(Rect2i(x, face.position.y + 2, 9, rib_height), colors[0])
			image.fill_rect(Rect2i(x, face.position.y + 2, 7, rib_height - 1), colors[2])
			image.fill_rect(Rect2i(x, face.position.y + 2, 7, 2), colors[4])
			if family == "observatory" and rib_height > 6:
				image.fill_rect(Rect2i(x + 2, face.position.y + 6, 2, rib_height - 6), colors[7])
	elif family == "coast":
		for x: int in range(face.position.x + 10, face.end.x - 5, 40):
			image.fill_rect(Rect2i(x, face.position.y + 4, 4, 4), colors[7])
	elif family == "garden":
		for x: int in range(face.position.x + 14, face.end.x - 7, 64):
			image.fill_rect(Rect2i(x, face.end.y - 4, 6, 2), colors[7])


static func _line(image: Image, a: Vector2i, b: Vector2i, color: Color, clip: Rect2i) -> void:
	# Integer Bresenham, setup only. No filtered strokes or pixels outside cap.
	var delta := (b - a).abs()
	var step := Vector2i(1 if a.x < b.x else -1, 1 if a.y < b.y else -1)
	var error := delta.x - delta.y
	while true:
		if clip.has_point(a): image.set_pixelv(a, color)
		if a == b: return
		var twice := error * 2
		if twice > -delta.y:
			error -= delta.y
			a.x += step.x
		if twice < delta.x:
			error += delta.x
			a.y += step.y
