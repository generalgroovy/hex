class_name WellspringEnvironmentDetails
extends RefCounted

# Static floor craft, compiled once into spatially bounded colored meshes.
# No nodes, particles, clocks, lights, collision, or per-frame triangulation.
# Raised silhouettes remain owned by the authored buildings. These are flush
# engravings, leaf litter and wear, with the center of each travel lane clear.
const Style = preload("res://src/presentation/wellspring_district_style.gd")
const PATCH_SIZE := 512
const MAX_PATCHES := 132
const MAX_VERTICES := 60000
const MAX_MARKS := 512
const LANE_CLEAR_HALF_WIDTH := 24.0
const LANDMARK_CLEAR_RADIUS := 88.0
const VERSION := "wellspring-floor-craft-2"

var patches: Array[Dictionary] = []
var marks: Array[Dictionary] = []
var vertex_count := 0
var build_count := 0
var content_hash := ""
var last_error := ""
var _building_bounds: Array[Rect2] = []
var _landmarks: Array[Vector2] = []
var _lane_segments: Array[Dictionary] = []
var _world_bounds := Rect2()
var _chunks: Dictionary = {}


func configure(layout: SanctumCampusLayout) -> bool:
	last_error = ""
	if layout == null or layout.districts_by_id.is_empty() or layout.canvas_size == Vector2i.ZERO:
		return _fail("Floor craft requires an admitted campus")
	# Hash actual relevant data, not a caller-supplied unchanged content hash.
	var signature := CanonicalContent.sha256({"version": VERSION, "canvas": layout.data.get("canvas_size", []), "districts": layout.data.get("districts", []), "routes": layout.data.get("routes", []), "landmarks": layout.data.get("landmarks", []), "buildings": layout.data.get("buildings", [])})
	if signature == content_hash and not patches.is_empty():
		return true
	clear()
	_world_bounds = Rect2(Vector2(80, 144), Vector2(layout.canvas_size) - Vector2(160, 256))
	for building: Dictionary in layout.data.get("buildings", []):
		_building_bounds.append(Rect2(SanctumCampusLayout._parse_bounds(building.get("bounds", []))).grow(12.0))
	for landmark: Dictionary in layout.data.get("landmarks", []):
		_landmarks.append(Vector2(SanctumCampusLayout._parse_point(landmark.get("position", []))))
	for route: Dictionary in layout.data.get("routes", []):
		if String(route.get("kind", "")) != "ordinary": continue
		var points: Array = route.get("points", [])
		for index: int in range(points.size() - 1):
			var a := Vector2(SanctumCampusLayout._parse_point(points[index]))
			var b := Vector2(SanctumCampusLayout._parse_point(points[index + 1]))
			_lane_segments.append({"a": a, "b": b, "bounds": Rect2(a, Vector2.ZERO).expand(b).grow(LANE_CLEAR_HALF_WIDTH)})
	for route: Dictionary in layout.data.get("routes", []):
		if String(route.get("kind", "")) != "ordinary": continue
		_prepare_route(route, layout.districts_by_id.get(String(route.get("district", "")), {}))
	for landmark: Dictionary in layout.data.get("landmarks", []):
		_prepare_landmark(landmark, layout.districts_by_id.get(String(landmark.get("district", "")), {}))
	if not last_error.is_empty():
		var error := last_error
		clear()
		return _fail(error)
	for key: Vector2i in _chunks:
		var chunk: Dictionary = _chunks[key]
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = chunk.vertices
		arrays[Mesh.ARRAY_COLOR] = chunk.colors
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		patches.append({"mesh": mesh, "bounds": chunk.bounds, "vertices": (chunk.vertices as PackedVector2Array).size()})
	_chunks.clear()
	content_hash = signature
	build_count += 1
	return true


func clear() -> void:
	patches.clear()
	marks.clear()
	_chunks.clear()
	_building_bounds.clear()
	_landmarks.clear()
	_lane_segments.clear()
	vertex_count = 0
	content_hash = ""
	_world_bounds = Rect2()


func draw(canvas: CanvasItem, visible: Rect2) -> void:
	if canvas == null: return
	# Reduced effects use the identical static layer. It has no hidden live
	# information, so the terrain backdrop also draws these exact same meshes.
	var clipped := visible.has_area() and visible.position.is_finite() and visible.end.is_finite()
	for patch: Dictionary in patches:
		if not clipped or (patch.bounds as Rect2).intersects(visible, true):
			canvas.draw_mesh(patch.mesh, null)


func visible_patch_count(visible: Rect2) -> int:
	var count := 0
	for patch: Dictionary in patches:
		if not visible.has_area() or (patch.bounds as Rect2).intersects(visible, true): count += 1
	return count


func _prepare_route(route: Dictionary, district: Dictionary) -> void:
	var width := float(route.get("width", 0))
	if width < 128.0: return
	var points: Array = route.get("points", [])
	var environment := Style.environment_for(district)
	for index: int in range(points.size() - 1):
		var a := Vector2(SanctumCampusLayout._parse_point(points[index]))
		var b := Vector2(SanctumCampusLayout._parse_point(points[index + 1]))
		var length := a.distance_to(b)
		var axis := a.direction_to(b)
		var distance := 96.0
		while distance < length - 96.0:
			for side: int in [-1, 1]:
				var anchor := a + axis * distance + axis.orthogonal() * (width * 0.5 - 12.0) * side
				var bounds := Rect2(anchor - Vector2(26, 26), Vector2(52, 52))
				if not _admit(bounds): continue
				_record_mark("route", environment, anchor, bounds, width * 0.5 - 38.0)
				_small_craft(anchor, axis, environment, index + side)
			distance += 288.0


func _prepare_landmark(landmark: Dictionary, district: Dictionary) -> void:
	var center := Vector2(SanctumCampusLayout._parse_point(landmark.get("position", [])))
	var environment := Style.environment_for(district)
	# A divided composition leaves all four approaches and the actual arrival
	# point open. Its shape belongs to the district, rather than a spell circle.
	for side: int in [-1, 1]:
		for row: int in [-1, 1]:
			# The quay's two parallel promenades leave a narrower inset here.
			var anchor := center + Vector2(side * 156, row * (110 if environment == "coast" else 126))
			var bounds := Rect2(anchor - Vector2(76, 50), Vector2(152, 100))
			if not _admit(bounds): continue
			_record_mark("landmark", environment, anchor, bounds)
			_large_craft(anchor, environment, (0 if side < 0 else 2) + (0 if row < 0 else 1))


func _admit(bounds: Rect2) -> bool:
	if not _world_bounds.encloses(bounds): return false
	for building: Rect2 in _building_bounds:
		if bounds.intersects(building, true): return false
	for landmark: Vector2 in _landmarks:
		var nearest := landmark.clamp(bounds.position, bounds.end)
		if nearest.distance_squared_to(landmark) < LANDMARK_CLEAR_RADIUS * LANDMARK_CLEAR_RADIUS: return false
	# Crossings and destination corners must also yield to other route centers.
	# This broadphase/exact check runs once, never while drawing or moving.
	for lane: Dictionary in _lane_segments:
		if not bounds.intersects(lane.bounds, true): continue
		if segment_crosses_rect(lane.a, lane.b, bounds.grow(LANE_CLEAR_HALF_WIDTH)): return false
	return true


static func segment_crosses_rect(a: Vector2, b: Vector2, bounds: Rect2) -> bool:
	if bounds.has_point(a) or bounds.has_point(b): return true
	var corners := PackedVector2Array([bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)])
	for index: int in 4:
		if Geometry2D.segment_intersects_segment(a, b, corners[index], corners[(index + 1) % 4]) != null: return true
	return false


func _record_mark(kind: String, environment: String, anchor: Vector2, bounds: Rect2, clear_half_width: float = 0.0) -> void:
	if marks.size() >= MAX_MARKS:
		_fail("Floor craft exceeds the finite mark budget")
		return
	marks.append({"kind": kind, "environment": environment, "anchor": anchor, "bounds": bounds, "clear_half_width": clear_half_width})


func _small_craft(anchor: Vector2, axis: Vector2, environment: String, variation: int) -> void:
	var style := Style.style_for(environment)
	var edge := Color(style.edge.darkened(0.24), 0.52)
	var accent := Color(style.accent, 0.52)
	match environment:
		"garden", "grove":
			_frond(anchor, axis.rotated(0.28), 26.0, 3)
			_flower(anchor + axis.orthogonal() * 17 + axis * 6, 4.0, variation)
		"coast":
			_shell(anchor, 15.0, variation * 0.35)
		"foundry":
			_vent(anchor, Vector2(21, 14), 3, false)
		"observatory":
			_star(anchor, 16.0, variation * 0.17, Color(Color("d4b779"), 0.52), Color(Color("625037"), 0.52))
			for side: int in [-1, 1]:
				_relief_line(anchor + Vector2(side * 21, -6), anchor + Vector2(side * 21, 6), 2.0, accent)
		_:
			var side := axis.orthogonal()
			for tile: int in 3:
				var p := anchor + axis * (tile * 13 - 13)
				_quad(p - axis * 6 - side * 8 + Vector2(1, 2), p + axis * 6 - side * 8 + Vector2(1, 2), p + axis * 6 + side * 8 + Vector2(1, 2), p - axis * 6 + side * 8 + Vector2(1, 2), Color(Color("34392f"), 0.48))
				_quad(p - axis * 6 - side * 8, p + axis * 6 - side * 8, p + axis * 6 + side * 8, p - axis * 6 + side * 8, accent if tile == 1 else edge)
				_segment(p - axis * 5 - side * 8, p + axis * 5 - side * 8, 2.0, accent)


func _large_craft(anchor: Vector2, environment: String, variation: int) -> void:
	var style := Style.style_for(environment)
	var edge := Color(style.edge.darkened(0.3), 0.52)
	var accent := Color(style.accent, 0.52)
	match environment:
		"garden", "grove":
			# Three fallen fern fans with seeds and flower heads, not tall shrubs.
			for index: int in 3:
				var p := anchor + Vector2(index * 43 - 43, -5 if index % 2 == 0 else 10)
				var direction := Vector2.from_angle(-0.7 + index * 0.55 + variation * 0.14)
				_frond(p, direction, 38.0 - index * 3.0, 4)
			for offset: Vector2 in [Vector2(-57, 24), Vector2(-13, -22), Vector2(16, 29), Vector2(58, 16)]:
				_flower(anchor + offset, 6.0, variation)
		"coast":
			# Scalloped mother-of-pearl reliefs interrupt the tidal contour bands.
			_shell(anchor + Vector2(-33, -2), 32.0, -0.35 + variation * 0.22)
			_shell(anchor + Vector2(35, 12), 22.0, 0.7 - variation * 0.25)
			for row: int in 3:
				var y := float(row * 13 - 30)
				for column: int in 3:
					var p := anchor + Vector2(column * 20 + 5, y)
					_relief_line(p, p + Vector2(9, -4), 2.4, Color(Color("91ada5"), 0.52))
					_relief_line(p + Vector2(9, -4), p + Vector2(17, 0), 2.4, edge)
			_relief_line(anchor + Vector2(-67, 38), anchor + Vector2(62, 38), 2.5, accent)
		"foundry":
			# Recessed cooling slots, broad copper flanges and angled steel fins.
			_vent(anchor, Vector2(66, 36), 6 + variation % 2, true)
		"observatory":
			# A segmented astrolabe is visibly brass, with broken elliptical bands
			# and a different stellar pointer in each quadrant; no glowing ring.
			var center := anchor + Vector2(-14, 0)
			var brass := Color(Color("d7b974"), 0.52)
			var dark_brass := Color(Color("5a4731"), 0.52)
			for index: int in 12:
				if index == variation * 3 or index == (variation * 3 + 6) % 12: continue
				var a := float(index) * TAU / 12.0 + 0.035
				var b := float(index + 1) * TAU / 12.0 - 0.035
				_arc_facet(center + Vector2(2, 3), Vector2(47, 33), 5.0, a, b, dark_brass)
				_arc_facet(center, Vector2(47, 33), 4.0, a, b, brass if index >= 6 else Color(Color("af8746"), 0.52))
				var p := center + Vector2(cos(a) * 53, sin(a) * 39)
				_segment(p, center + Vector2(cos(a) * 57, sin(a) * 42), 2.0, brass)
			_star(center, 26.0, variation * PI / 4.0, brass, dark_brass)
			var tip := center + Vector2.from_angle(-0.85 + variation * 0.6) * Vector2(39, 26)
			_triangle(center + Vector2(-3, 3), tip, center + Vector2(3, -3), Color(Color("ece0b2"), 0.52))
			var trail := PackedVector2Array([anchor + Vector2(29, -23), anchor + Vector2(61, -11 + variation * 4), anchor + Vector2(47, 29)])
			for index: int in 2: _relief_line(trail[index], trail[index + 1], 2.0, dark_brass)
			for point: Vector2 in trail: _star(point, 6.0, 0.0, brass, dark_brass)
		_:
			# The Academy crest is a cut-stone open book with brass page ribs.
			var dark := Color(Color("4a4940"), 0.52)
			var ivory := Color(Color("d6cba2"), 0.52)
			for side: int in [-1, 1]:
				var hinge := anchor + Vector2(0, 23)
				var upper := anchor + Vector2(side * 48, -28)
				_quad(hinge + Vector2(2, 4), anchor + Vector2(side * 55 + 2, 34), upper + Vector2(2, 4), anchor + Vector2(2, -16), dark)
				_quad(hinge, anchor + Vector2(side * 55, 30), upper, anchor + Vector2(0, -20), ivory if side < 0 else accent)
				for page: int in 4:
					var y := float(page * 10 - 13)
					_relief_line(anchor + Vector2(side * 8, y), anchor + Vector2(side * (41 + page), y + 3), 2.0, dark)
			_segment(anchor + Vector2(0, -19), anchor + Vector2(0, 26), 3.5, Color(Color("bca36b"), 0.52))
			_star(anchor + Vector2(0, -35), 10.0, variation * PI / 4.0, ivory, edge)


func _frond(point: Vector2, axis: Vector2, length: float, pairs: int) -> void:
	var shadow := Color(Color("294735"), 0.52)
	var face := Color(Color("91a969"), 0.52)
	_relief_line(point - axis * length * 0.55, point + axis * length * 0.55, 1.8, Color(Color("b4b27e"), 0.52))
	for index: int in pairs:
		var progress := float(index + 1) / float(pairs + 1)
		var joint := point + axis * ((progress - 0.5) * length)
		var leaf_length := length * 0.24 * (1.0 - progress * 0.4)
		for side: int in [-1, 1]:
			var direction := (axis * 0.72 + axis.orthogonal() * side).normalized()
			_leaf(joint + direction * leaf_length * 0.65, direction, leaf_length, shadow, face)


func _flower(point: Vector2, radius: float, variation: int) -> void:
	var petal := Color(Color("c4ad75") if variation % 2 == 0 else Color("b49dad"), 0.52)
	_quad(point + Vector2(-radius, 2), point + Vector2(2, -radius), point + Vector2(radius + 2, 2), point + Vector2(2, radius + 2), Color(Color("314532"), 0.46))
	for index: int in 4:
		var axis := Vector2.from_angle(index * PI * 0.5)
		var side := axis.orthogonal() * radius * 0.4
		_quad(point, point + axis * radius * 0.65 + side, point + axis * radius, point + axis * radius * 0.65 - side, petal)
	_quad(point + Vector2(-1.6, 0), point + Vector2(0, -1.6), point + Vector2(1.6, 0), point + Vector2(0, 1.6), Color(Color("e0c788"), 0.52))


func _shell(point: Vector2, radius: float, rotation: float) -> void:
	var hinge := point + Vector2(0, radius * 0.4).rotated(rotation)
	var shade := Color(Color("3c645f"), 0.52)
	var pearl := Color(Color("d9d0ac"), 0.52)
	var silver := Color(Color("9fb4a8"), 0.52)
	for index: int in 7:
		var a := PI + float(index) * PI / 7.0
		var b := PI + float(index + 1) * PI / 7.0
		var left := hinge + Vector2.from_angle(a + rotation) * radius
		var right := hinge + Vector2.from_angle(b + rotation) * radius
		var ridge := hinge + Vector2.from_angle((a + b) * 0.5 + rotation) * radius * 1.06
		_triangle(hinge + Vector2(2, 3), left + Vector2(2, 3), right + Vector2(2, 3), shade)
		_triangle(hinge, left, ridge, pearl if index < 4 else silver)
		_triangle(hinge, ridge, right, silver if index < 4 else shade)
		_segment(hinge, left, 1.6, Color(Color("ede0b7"), 0.52))
	_quad(hinge + Vector2(-3, 0), hinge + Vector2(0, -2), hinge + Vector2(3, 0), hinge + Vector2(0, 3), pearl)


func _vent(point: Vector2, half: Vector2, slats: int, flanges: bool) -> void:
	var plate := PackedVector2Array([
		point + Vector2(-half.x + 5, -half.y), point + Vector2(half.x - 5, -half.y),
		point + Vector2(half.x, -half.y + 5), point + Vector2(half.x, half.y - 5),
		point + Vector2(half.x - 5, half.y), point + Vector2(-half.x + 5, half.y),
		point + Vector2(-half.x, half.y - 5), point + Vector2(-half.x, -half.y + 5),
	])
	for index: int in range(1, plate.size() - 1):
		_triangle(plate[0] + Vector2(2, 3), plate[index] + Vector2(2, 3), plate[index + 1] + Vector2(2, 3), Color(Color("282e2b"), 0.52))
		_triangle(plate[0], plate[index], plate[index + 1], Color(Color("a67e52"), 0.52))
	var inset := Vector2(half.x - 7, half.y - 5)
	_quad(point - inset, point + Vector2(inset.x, -inset.y), point + inset, point + Vector2(-inset.x, inset.y), Color(Color("263a38"), 0.52))
	for row: int in slats:
		var y := lerpf(-inset.y + 3, inset.y - 3, float(row) / float(maxi(1, slats - 1)))
		var left := point + Vector2(-inset.x + 2, y)
		var right := point + Vector2(inset.x - 2, y)
		_quad(left, right, right + Vector2(-2, 3), left + Vector2(2, 3), Color(Color("687778"), 0.52))
		_segment(left, right, 1.8, Color(Color("bfc2aa"), 0.52))
	_segment(point + Vector2(-half.x + 6, -half.y), point + Vector2(half.x - 6, -half.y), 2.0, Color(Color("d9b77b"), 0.52))
	for side: int in [-1, 1]:
		var rivet := point + Vector2(side * (half.x - 3), 0)
		if flanges:
			for row: int in [-1, 1]:
				var bolt := rivet + Vector2(0, row * (half.y - 7))
				_quad(bolt + Vector2(-4, -4), bolt + Vector2(4, -4), bolt + Vector2(4, 4), bolt + Vector2(-4, 4), Color(Color("cd9a60"), 0.52))
				_star(bolt, 2.7, 0.0, Color(Color("ddd1ac"), 0.52), Color(Color("584433"), 0.52))
		else:
			_segment(rivet - Vector2(0, 2), rivet + Vector2(0, 2), 2.0, Color(Color("ddbd86"), 0.52))


func _arc_facet(center: Vector2, radius: Vector2, width: float, a: float, b: float, color: Color) -> void:
	var inner := radius - Vector2.ONE * width
	_quad(center + Vector2.from_angle(a) * radius, center + Vector2.from_angle(b) * radius, center + Vector2.from_angle(b) * inner, center + Vector2.from_angle(a) * inner, color)


func _star(point: Vector2, radius: float, rotation: float, light: Color, shade: Color) -> void:
	for index: int in 4:
		var axis := Vector2.from_angle(rotation + index * PI * 0.5)
		var side := axis.orthogonal() * radius * 0.24
		_triangle(point, point + axis * radius * 0.24 - side, point + axis * radius, light)
		_triangle(point, point + axis * radius, point + axis * radius * 0.24 + side, shade)


func _leaf(point: Vector2, axis: Vector2, length: float, shadow: Color, face: Color) -> void:
	var side := axis.orthogonal() * length * 0.40
	var start := point - axis * length
	var tip := point + axis * length
	_triangle(start + Vector2(1, 2), point + side + Vector2(1, 2), tip + Vector2(1, 2), Color(Color("253e2e"), 0.40))
	_triangle(start + Vector2(1, 2), tip + Vector2(1, 2), point - side + Vector2(1, 2), Color(Color("253e2e"), 0.40))
	_triangle(start, point + side, tip, shadow)
	_triangle(start, tip, point - side, face)
	_segment(start - axis * 2.0, tip, 1.0, Color(face, 0.52))


func _relief_line(a: Vector2, b: Vector2, width: float, face: Color) -> void:
	_segment(a + Vector2(0, 1.5), b + Vector2(0, 1.5), width + 1.0, Color(Color("26322e"), 0.24))
	_segment(a, b, width, face)


func _segment(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var side := a.direction_to(b).orthogonal() * width * 0.5
	_quad(a - side, b - side, b + side, a + side, color)


func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color) -> void:
	_triangle(a, b, c, color)
	_triangle(a, c, d, color)


func _triangle(a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	if vertex_count + 3 > MAX_VERTICES:
		_fail("Floor craft exceeds the finite geometry budget")
		return
	var id := Vector2i(((a + b + c) / (3.0 * PATCH_SIZE)).floor())
	if not _chunks.has(id):
		if _chunks.size() >= MAX_PATCHES:
			_fail("Floor craft exceeds the finite patch budget")
			return
		_chunks[id] = {"vertices": PackedVector2Array(), "colors": PackedColorArray(), "bounds": Rect2(a, Vector2.ZERO)}
	var chunk: Dictionary = _chunks[id]
	var vertices: PackedVector2Array = chunk.vertices
	var colors: PackedColorArray = chunk.colors
	vertices.append_array(PackedVector2Array([a, b, c]))
	colors.append_array(PackedColorArray([color, color, color]))
	chunk.vertices = vertices
	chunk.colors = colors
	chunk.bounds = (chunk.bounds as Rect2).expand(a).expand(b).expand(c)
	vertex_count += 3


func _fail(message: String) -> bool:
	last_error = message
	return false
