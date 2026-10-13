extends RefCounted
## Tiny code-authored pixel stamps, not a second effect authority. Three opaque
## palette entries, nearest sampling, integer texels and a bounded texture cache.
## Marks identify materials; the court still draws exact selected-cell borders.

const CACHE_LIMIT := 192
const REGION_MESH_LIMIT := 512
const REGION_VERTEX_COUNT := 6
# Two anchored poses break repeated electrical knots without changing a mark's
# size, position or occupied hex. The pose never depends on the animation clock.
const MIRRORED_MATERIALS := ["thermal_shock", "plasma_arc", "arcflash"]
const CADENCE_TICKS := {"earth": 0, "fire": 10, "water": 16, "wind": 10, "ice": 28, "charge": 7, "light": 30, "dark": 32, "steam": 16, "mud": 24, "magma": 18, "vortex": 14,
	"thermal_shock": 24, "plasma_arc": 10, "solar_flare": 24, "superconduct": 18,
	"arcflash": 10, "radiance": 30, "penumbra": 32}
const MASKS := {
	"fire": ["....1....","...121...","...121...",".1.1221..","1212231..","12233321.","12233321.",".122321..","..1111..."],
	"steam": ["..11.11..",".1221221.","122332221",".1223321.","..12221..",".122.21..","..22.22..","..2...2..","........."],
	"water": [".........","..111....",".12321...","123.2111.",".12222231","..111111.",".111.....","12222231.",".111111.."],
	"wind": ["....111..","...12321.","1112221..","122111...",".........","..111111.",".12222231","...11121.",".....11.."],
	"earth": [".........","..111....",".12231...","1222231..",".11111...",".....111.",".11.12231","1221.111.",".11......"],
	"mud": [".........","..1111...",".122221..","12213221.",".1222221.","...11221.",".1111221.","1222211..",".1111...."],
	"magma": ["11....11.","121..1221",".1311221.",".123321..","..12231..",".122131..","1221.131.","121...131","11.....11"],
	"vortex": ["..11111..",".1222231.","12311121.","121..121.","121.1321.","121.111..","1232221..",".11111...","........."],
	"ice": ["....1....",".1.121.1.","121131121",".1233321.","113333311",".1233321.","121131121",".1.121.1.","....1...."],
	"charge": ["....111..","...1231..","..1231...",".1233111.","12222331.",".111231..","...131...","..131....","..11....."],
	"light": ["....1....","...121...","..12321..",".1233321.","123333321",".1233321.","..12321..","...121...","....1...."],
	"dark": ["..1111...",".1221....","1221.....","1231.....","1231.....","1231.....","12221....",".122221..","..1111..."],
	# Filled clusters and selective underside ink survive the 75% gameplay view
	# better than a closed outline around every branch. Keep the fracture, elbow,
	# sun rays, crystal junction, fork, lantern cross and split crescents distinct.
	"thermal_shock": ["..22..3..",".122.331.","122..31..",".12.331..","..1..31..",".122..31.","122...331",".22....3.","........."],
	"plasma_arc": ["......23.",".....231.","..22231..",".23331...","123222...",".111232..",".....232.","......21.","........."],
	"solar_flare": ["....2....",".2..3..2.","..2...2..","...232...","231333132","...232...","..2...2..",".2..1..2.","....1...."],
	"superconduct": ["..2...2..",".231.132.","..23132..","...232...",".2233322.","...121...","..21.12..",".21...12.","..1...1.."],
	"arcflash": [".....23..","....231..",".2.231...","123332...",".112332..","...12332.","...231.1.","..231....","..21....."],
	"radiance": ["...232...","....3....","....3....",".2.232.2.","233333332",".1.232.1.","....2....","....2....","...121..."],
	"penumbra": ["..22.33..",".221.133.","221...133","21.....13","21..2..13","21.....13","221...133",".221.133.","..22.33.."],
}
# Alternative silhouettes, not particles or translated/rotating effect bounds.
# The two vapor lobes remain pale while separate ground vents convey scalding.
const ANIMATED_MASKS := {
	"steam": [
		["..11.11..",".1221221.","122332221",".1223321.","..12221..",".122.21..","..22.22..","..2...2..","........."],
		["...11....",".1112211.","122332221","123333321",".1223221.","..12221..",".122.221.","..2...2..","........."],
		["..111.11.",".12321221","122333221",".1233321.","..12221..","..22.21..",".22..22..","..2...2..","........."],
	],
	"fire": [
		["....1....","...121...","...121...",".1.1221..","1212231..","12233321.","12233321.",".122321..","..1111..."],
		["...1.....","..121.1..","..121121.","..122231.",".1223321.","122333321",".1233321.",".122321..","..1111..."],
		[".....1...","....121..","..1.121..",".121221..",".1223321.","12233321.","122333321",".1223321.","..11111.."],
	],
	"charge": [
		["....111..","...1231..","..1231...",".1233111.","12222331.",".111231..","...131...","..131....","..11....."],
		["....111..","...1231..","..1231...",".1233111.","12223331.",".113231..","...131...","..131....","..11....."],
		["....111..","...1231..","..1331...",".1333111.","12222331.",".111331..","...131...","..131....","..11....."],
	],
}
var textures: Dictionary = {}
var order: Array[String] = []
var _region_meshes: Dictionary = {}
var _region_mesh_builds := 0
var _region_mesh_hits := 0
var _region_mesh_draws := 0
var _region_mesh_fallbacks := 0
var _texture_prefixes: Dictionary = {}


static func frame_index(tick: float, seed: int, reduced: bool) -> int:
	return 0 if reduced or not is_finite(tick) else posmod(floori(tick / 8.0) + seed, 3)


static func material_frame(kind: String, tick: float, seed: int, reduced: bool) -> int:
	var cadence := int(CADENCE_TICKS.get(kind, 16))
	return 0 if reduced or cadence == 0 or not is_finite(tick) else posmod(floori(tick / cadence) + seed, 3)


static func spatial_variant(kind: String, seed: int) -> int:
	return posmod(seed, 2) if kind in MIRRORED_MATERIALS else 0


static func region_uv(polygon: PackedVector2Array) -> PackedVector2Array:
	var uv := PackedVector2Array()
	if polygon.size() != 6:
		return uv
	var minimum := polygon[0]
	var maximum := polygon[0]
	for point: Vector2 in polygon:
		if not point.is_finite():
			return PackedVector2Array()
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	var side := maxf(maximum.x - minimum.x, maximum.y - minimum.y)
	if side <= 0.0:
		return uv
	var origin := (minimum + maximum - Vector2.ONE * side) * 0.5
	for point: Vector2 in polygon:
		# Large world coordinates can round the boundary a fraction outside [0,1].
		# Clamp UVs only; the authoritative polygon is never rounded or expanded.
		uv.append(((point - origin) / side).clamp(Vector2.ZERO, Vector2.ONE))
	return uv


func draw_region(canvas: CanvasItem, kind: String, polygon: PackedVector2Array,
	dark: Color, base: Color, bright: Color, tick: float, seed: int, reduced: bool,
	opacity: float = 1.0) -> bool:
	if canvas == null or not MASKS.has(kind):
		return false
	# Exact absolute vertices and their original UV arithmetic are retained.
	# Never evict an in-flight mesh: excess shapes keep the original draw path.
	var mesh := _region_mesh(polygon)
	if mesh != null:
		var retained_texture := texture_for(kind, dark, base, bright, material_frame(kind, tick, seed, reduced), true, seed)
		if retained_texture != null:
			RenderingServer.canvas_item_add_mesh(canvas.get_canvas_item(), mesh.get_rid(), Transform2D.IDENTITY,
				Color(1, 1, 1, clampf(opacity, 0, 1)), retained_texture.get_rid())
			_region_mesh_draws += 1
			return true
	var uv := region_uv(polygon)
	if uv.is_empty():
		return false
	var texture := texture_for(kind, dark, base, bright, material_frame(kind, tick, seed, reduced), true, seed)
	# A transparent one-texel border and actual polygon clipping permit a much
	# larger readable motif without painting into a safe neighboring hex.
	canvas.draw_polygon(polygon, PackedColorArray([Color(1, 1, 1, clampf(opacity, 0, 1))]), uv, texture)
	_region_mesh_fallbacks += 1
	return true


func _region_mesh(polygon: PackedVector2Array) -> ArrayMesh:
	# Admission is explicit before retention: at most six vertices/twelve indices
	# per entry. region_uv has the same whole-cell contract for the fallback.
	if polygon.size() != REGION_VERTEX_COUNT: return null
	if _region_meshes.has(polygon):
		_region_mesh_hits += 1
		return _region_meshes[polygon]
	if _region_meshes.size() >= REGION_MESH_LIMIT: return null
	var uv := region_uv(polygon)
	if uv.is_empty(): return null
	var indices := Geometry2D.triangulate_polygon(polygon)
	if indices.is_empty(): return null
	var vertices := PackedVector3Array()
	for point: Vector2 in polygon: vertices.append(Vector3(point.x, point.y, 0.0))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_region_meshes[polygon.duplicate()] = mesh
	_region_mesh_builds += 1
	return mesh


func geometry_stats() -> Dictionary:
	return {"meshes": _region_meshes.size(), "builds": _region_mesh_builds,
		"hits": _region_mesh_hits, "draws": _region_mesh_draws, "fallbacks": _region_mesh_fallbacks, "texture_prefixes": _texture_prefixes.size()}


static func stamp_rect(center: Vector2, clearance: float) -> Rect2:
	# A centered square's corner radius is sqrt(2)*half_width. Reserve a full
	# pixel for center rounding so a mark cannot leak into a safe neighboring hex.
	var step := floori((clearance - 1.0) * sqrt(2.0) / 9.0)
	if step < 1: return Rect2()
	var size := Vector2.ONE * 9 * step
	return Rect2((center - size * 0.5).round(), size)


func draw(canvas: CanvasItem, kind: String, center: Vector2, clearance: float,
	dark: Color, base: Color, bright: Color, tick: float, seed: int, reduced: bool,
	opacity: float = 1.0) -> bool:
	if canvas == null or not MASKS.has(kind): return false
	var rect := stamp_rect(center, clearance)
	if not rect.has_area(): return false
	var texture := texture_for(kind, dark, base, bright, material_frame(kind, tick, seed, reduced), false, seed)
	canvas.draw_texture_rect(texture, rect, false, Color(1, 1, 1, clampf(opacity, 0, 1)))
	return true


func texture_for(kind: String, dark: Color, base: Color, bright: Color, frame: int, padded: bool = false, variant: int = 0) -> Texture2D:
	if not MASKS.has(kind): return null
	frame = posmod(frame, 3)
	variant = spatial_variant(kind, variant)
	# Preserve the original HTML-color key (including its intentional color
	# quantization), while avoiding repeated color formatting for every cell.
	var prefix_key: Array = [kind, dark, base, bright]
	var prefix: String = _texture_prefixes.get(prefix_key, "")
	if prefix.is_empty():
		prefix = "%s/%s/%s/%s/" % [kind, dark.to_html(), base.to_html(), bright.to_html()]
		if _texture_prefixes.size() < CACHE_LIMIT:
			prefix_key.make_read_only()
			_texture_prefixes[prefix_key] = prefix
	var key := prefix + "%d/%s/%d" % [frame, str(padded), variant]
	if textures.has(key): return textures[key]
	var padding := 1 if padded else 0
	var image := Image.create(9 + padding * 2, 9 + padding * 2, false, Image.FORMAT_RGBA8)
	var palette := [Color.TRANSPARENT, dark, base, bright]
	var mask: Array = ANIMATED_MASKS[kind][frame] if ANIMATED_MASKS.has(kind) else MASKS[kind]
	for y: int in 9:
		for x: int in 9:
			var token := String(mask[y]).substr(x, 1)
			if token == ".": continue
			var index := int(token)
			# A three-frame highlight crawl reads as flowing/flickering matter,
			# never a rotating ring, a moving hazard boundary or a brightness flash.
			if index == 2 and frame > 0 and posmod(x + y * 2 + frame, 7) == 0: index = 3
			# Reflect pixels inside the same padded source, never the polygon. Each
			# cell keeps this static pose even when Reduced Effects freezes its frame.
			var target_x := 8 - x if variant == 1 else x
			image.set_pixel(target_x + padding, y + padding, palette[index])
	var texture := ImageTexture.create_from_image(image)
	if order.size() >= CACHE_LIMIT: textures.erase(order.pop_front())
	order.append(key)
	textures[key] = texture
	return texture
