class_name HexEnvironmentLayout
extends RefCounted

# Presentation-only rasterization of the existing fixed-point chemistry grid.
# Materials are sampled once at cell centers; the exact polygons, not an offset
# imitation grid, partition the floor. Nothing here changes collision or effects.
const SCALE := 1000
const HALF_SCALE := 500
const MAX_CANVAS := Vector2i(4096, 4096)
const FAMILIES := ["paving", "earth", "grass", "worldbone", "water"]
const VARIANTS := 4
const VERSION := "hex-ground-8-world-region-raster"
enum Finish { ORIGINAL, COMMONS, CHEMISTRY, DUEL, CHAIN, INSET, ROUTE }
const STAMP_SIZE := Vector2i(24, 29)
# Five originals, four paving courts, one paving inset and two route materials.
# There are exactly125 subpixel row phases. One bounded preparation set is
# reused across regions; texture residency is managed separately by the caller.
const MAX_STAMPS := 12 * VARIANTS * 125
const MAX_STAMP_BYTES := 16 * 1024 * 1024
const AUTHORED_WEAR_PIXEL_LIMIT := 16
const AUTHORED_TILE_SIZE := Vector2i(128, 128)
const SOIL_REPEAT_BOUNDS := Rect2i(1, 1, 126, 126)
const MAX_AUTHORED_TILES := 9 # Seven paving finishes and two earth finishes.
const MAX_AUTHORED_BYTES := MAX_AUTHORED_TILES * 128 * 128 * 4
const AUTHORED_CONTRAST := 0.52
const AUTHORED_CHANNEL_LIMIT := 0.10
# Tiny surface marks, not standing scenery. Half the variants stay unmarked;
# the other half place one connected motif near a shoulder of the true hex.
# Empty tile centres leave feet, projectiles and active matter unobstructed.
const MATERIAL_MARKS := {
	"paving": ["....ll", "..ddd.", "..d..."],
	"earth": ["ll....", "ld..d.", "....dd"],
	"grass": ["l...l.", "dl.ld.", ".ddd.."],
	"worldbone": ["...l..", "dddld.", "..dl.."],
	"water": ["lllll.", "......", "..ddd."],
}
var cell_count := 0
var stamp_count := 0
var stamp_bytes := 0
var authored_tile_count := 0
var authored_tile_bytes := 0
var authored_copy_count := 0
var last_error := ""
var _prepared_key := ""
var _prepared_authored: Dictionary = {}
var _prepared_stamps: Dictionary = {}
var _prepared_stamp_bytes := 0


static func center_pixels(cell: Vector2i) -> Vector2:
	return Vector2(HexGrid.center(cell)) / SCALE


static func cell_at(point: Vector2) -> Vector2i:
	return HexGrid.world_to_cell(Vector2i(roundi(point.x * SCALE), roundi(point.y * SCALE)))


static func inlay_lines(bounds: Rect2) -> PackedVector2Array:
	# Cosmetic joints are clipped to the authoritative rectangle. They do not
	# pretend square collision corners have become passable hex corners.
	var lines := PackedVector2Array()
	if bounds.size.x <= 0 or bounds.size.y <= 0 or bounds.size.x > MAX_CANVAS.x or bounds.size.y > MAX_CANVAS.y:
		return lines
	var first_r := floori((bounds.position.y * SCALE - HexGrid.HALF_HEIGHT) / HexGrid.ROW_PITCH)
	var last_r := ceili((bounds.end.y * SCALE + HexGrid.HALF_HEIGHT) / HexGrid.ROW_PITCH)
	for r: int in range(first_r, last_r + 1):
		var first_q := floori((bounds.position.x * SCALE - HexGrid.HALF_WIDTH * r - HexGrid.HALF_WIDTH) / HexGrid.COLUMN_PITCH)
		var last_q := ceili((bounds.end.x * SCALE - HexGrid.HALF_WIDTH * r + HexGrid.HALF_WIDTH) / HexGrid.COLUMN_PITCH)
		for q: int in range(first_q, last_q + 1):
			var vertices := HexGrid.vertices(Vector2i(q, r))
			# Three faces per cell: every shared face appears exactly once.
			for edge: int in range(3):
				lines.append_array(_clip_segment(Vector2(vertices[edge]) / SCALE, Vector2(vertices[edge + 1]) / SCALE, bounds))
	return lines


static func _clip_segment(a: Vector2, b: Vector2, bounds: Rect2) -> PackedVector2Array:
	var delta := b - a
	var near := 0.0
	var far := 1.0
	for axis: int in range(2):
		if is_zero_approx(delta[axis]):
			if a[axis] < bounds.position[axis] or a[axis] > bounds.end[axis]:
				return PackedVector2Array()
		else:
			var low := (bounds.position[axis] - a[axis]) / delta[axis]
			var high := (bounds.end[axis] - a[axis]) / delta[axis]
			near = maxf(near, minf(low, high))
			far = minf(far, maxf(low, high))
			if near >= far:
				return PackedVector2Array()
	return PackedVector2Array([a + delta * near, a + delta * far])


static func raster_origin(cell: Vector2i) -> Vector2i:
	var center := HexGrid.center(cell)
	return Vector2i(floori(float(center.x - HexGrid.HALF_WIDTH) / SCALE), floori(float(center.y - HexGrid.HALF_HEIGHT) / SCALE))


static func raster_spans(row: int) -> Array[Rect2i]:
	# One native blit per stamp during composition. These short scanline lists
	# are only used when preparing one of the bounded row-phase/material stamps.
	var cell := Vector2i(0, row)
	var center := HexGrid.center(cell)
	var origin := raster_origin(cell)
	var result: Array[Rect2i] = []
	var last_y := ceili(float(center.y + HexGrid.HALF_HEIGHT) / SCALE)
	for y: int in range(origin.y, last_y):
		var dy := absi(y * SCALE + HALF_SCALE - center.y)
		if dy > HexGrid.HALF_HEIGHT:
			continue
		var half_width := minf(HexGrid.HALF_WIDTH, float(2 * HexGrid.HALF_WIDTH * (HexGrid.HALF_HEIGHT - dy)) / HexGrid.HALF_HEIGHT)
		var left := ceili((float(center.x) - half_width - SCALE / 2.0) / SCALE)
		var right := floori((float(center.x) + half_width - SCALE / 2.0) / SCALE)
		# Exact face ties use the same lexicographic owner as chemistry. There
		# are no epsilon seams or pixels claimed by both neighboring cells.
		if left <= right and not _owns_sample(cell, Vector2i(left, y)):
			left += 1
		if left <= right and not _owns_sample(cell, Vector2i(right, y)):
			right -= 1
		if left <= right:
			result.append(Rect2i(left - origin.x, y - origin.y, right - left + 1, 1))
	return result


static func _owns_sample(cell: Vector2i, pixel: Vector2i) -> bool:
	var point := pixel * SCALE + Vector2i(HALF_SCALE, HALF_SCALE)
	return HexGrid.world_to_cell(point) == cell


func compose(size: Vector2i, material_at: Callable, style: RefCounted, finish_at: Callable = Callable(), authored_sources: Dictionary = {}) -> Image:
	# Legacy whole-image calls retain their fresh-composition diagnostics.
	_prepared_key = ""
	_prepared_authored.clear()
	_prepared_stamps.clear()
	_prepared_stamp_bytes = 0
	return compose_region(Rect2i(Vector2i.ZERO, size), material_at, style, finish_at, authored_sources)


func compose_region(world_rect: Rect2i, material_at: Callable, style: RefCounted, finish_at: Callable = Callable(), authored_sources: Dictionary = {}) -> Image:
	# Absolute cell coordinates and source UVs are preserved across chunk edges.
	# The allocation is the requested region only, never its world-space extent.
	var size := world_rect.size
	last_error = ""
	cell_count = 0
	stamp_count = 0
	stamp_bytes = 0
	authored_tile_count = 0
	authored_tile_bytes = 0
	authored_copy_count = 0
	if size.x <= 0 or size.y <= 0 or size.x > MAX_CANVAS.x or size.y > MAX_CANVAS.y or absi(world_rect.position.x) > 8192 or absi(world_rect.position.y) > 8192 or absi(world_rect.end.x) > 8192 or absi(world_rect.end.y) > 8192 or not material_at.is_valid() or style == null:
		last_error = "Hex terrain requires bounded dimensions, materials and a validated style"
		return null
	if not authored_sources.is_empty() and authored_sources.size() != MAX_AUTHORED_TILES:
		last_error = "Authored ground requires all nine existing stone/soil finishes"
		return null
	var source_tiles := {}
	var source_palettes := {}
	for family: String in FAMILIES:
		var tile := style.tile_image("map.terrain.%s.fill_v1" % family) as Image
		if tile == null or tile.get_size() != Vector2i(32, 32):
			last_error = "Hex terrain is missing authored material " + family
			return null
		source_tiles[family] = tile
		source_palettes[family] = _material_palette(tile)
	# One bounded native preparation cache across regions. Fingerprint actual
	# immutable source pixels/dimensions, so changed imagery cannot reuse stale
	# colors even when a caller retains the same Image or style object.
	var fingerprint := HashingContext.new()
	fingerprint.start(HashingContext.HASH_SHA256)
	for family: String in FAMILIES:
		fingerprint.update((family + str((source_tiles[family] as Image).get_size())).to_utf8_buffer())
		fingerprint.update((source_tiles[family] as Image).get_data())
	for key: Variant in authored_sources:
		if not key is String or not authored_sources[key] is Image:
			last_error = "Authored ground requires known native image sources"
			return null
		var source: Image = authored_sources[key]
		fingerprint.update((String(key) + str(source.get_size()) + str(source.get_format())).to_utf8_buffer())
		fingerprint.update(source.get_data())
	var source_key := fingerprint.finish().hex_encode()
	if source_key != _prepared_key:
		_prepared_authored.clear()
		_prepared_stamps.clear()
		_prepared_stamp_bytes = 0
		_prepared_key = source_key
	var tones: Array[Color] = finish_tones(source_palettes)
	var authored_tiles := {}
	for key: Variant in authored_sources:
		if not key is String or not authored_key_allowed(key):
			last_error = "Authored ground cannot replace a protected family or invent a finish"
			return null
		var source: Variant = authored_sources[key]
		if not source is Image:
			last_error = "Authored ground requires native opaque128px source tiles"
			return null
		var family := String(key).get_slice(":", 0)
		var finish := int(String(key).get_slice(":", 1))
		var base := terrain_tone(source_palettes[family][0], family) if finish == Finish.ORIGINAL else tones[finish]
		var prepared: Image = _prepared_authored.get(key)
		if prepared == null:
			prepared = prepare_authored_tile(source, base)
			if prepared != null: _prepared_authored[key] = prepared
		if prepared == null:
			last_error = "Authored ground requires native opaque128px source tiles"
			return null
		authored_tiles[key] = prepared
		authored_tile_bytes += prepared.get_data().size()
		if authored_tiles.size() > MAX_AUTHORED_TILES or authored_tile_bytes > MAX_AUTHORED_BYTES:
			last_error = "Authored ground exceeds its setup-only texture budget"
			return null
	authored_tile_count = authored_tiles.size()
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var stamps: Dictionary = _prepared_stamps
	stamp_bytes = _prepared_stamp_bytes
	var first_row := floori(float(world_rect.position.y * SCALE - HexGrid.HALF_HEIGHT) / HexGrid.ROW_PITCH)
	var last_row := ceili(float(world_rect.end.y * SCALE + HexGrid.HALF_HEIGHT) / HexGrid.ROW_PITCH)
	for row: int in range(first_row, last_row + 1):
		var spans := raster_spans(row)
		var rectangles: Array[Rect2i] = []
		if not authored_tiles.is_empty():
			rectangles = _joined_spans(spans)
		var first_q := floori(float(world_rect.position.x * SCALE - HexGrid.HALF_WIDTH * row - HexGrid.HALF_WIDTH) / HexGrid.COLUMN_PITCH)
		var last_q := ceili(float(world_rect.end.x * SCALE - HexGrid.HALF_WIDTH * row + HexGrid.HALF_WIDTH) / HexGrid.COLUMN_PITCH)
		var phase := posmod(row * HexGrid.ROW_PITCH, SCALE)
		for q: int in range(first_q, last_q + 1):
			var cell := Vector2i(q, row)
			var point := center_pixels(cell)
			var material := String(material_at.call(point))
			if not source_tiles.has(material):
				last_error = "Hex terrain material callback returned an unknown family"
				return null
			var finish: int = Finish.ORIGINAL
			if finish_at.is_valid():
				var requested: Variant = finish_at.call(point, material)
				if not requested is int or not finish_allowed(int(requested), material):
					last_error = "Hex terrain finish cannot replace its authored material family"
					return null
				finish = int(requested)
			var authored_key := surface_key(material, finish)
			if authored_tiles.has(authored_key):
				# Native world-space UVs cross cell boundaries continuously. These
				# exact ownership rectangles change neither classification nor edges.
				var origin := raster_origin(cell)
				var repeat_bounds := authored_repeat_bounds(material)
				for rectangle: Rect2i in rectangles:
					authored_copy_count += _copy_authored_rect(image, authored_tiles[authored_key], Rect2i(origin + rectangle.position, rectangle.size), repeat_bounds, world_rect.position)
				cell_count += 1
				continue
			var variant := cell_variant(cell)
			var key := "%s:%d:%d:%d" % [material, phase, variant, finish]
			if not stamps.has(key):
				if stamps.size() >= MAX_STAMPS or stamp_bytes + authored_tile_bytes + STAMP_SIZE.x * STAMP_SIZE.y * 4 > MAX_STAMP_BYTES:
					last_error = "Hex terrain exceeds its setup stamp budget"
					return null
				stamps[key] = _make_stamp(spans, source_palettes[material], variant, material, source_tiles[material], finish, tones, authored_tiles.is_empty())
				stamp_bytes += STAMP_SIZE.x * STAMP_SIZE.y * 4
				_prepared_stamp_bytes = stamp_bytes
			var stamp: Image = stamps[key]
			image.blend_rect(stamp, Rect2i(Vector2i.ZERO, stamp.get_size()), raster_origin(cell) - world_rect.position)
			cell_count += 1
	stamp_count = stamps.size()
	# Region calls reuse one bounded prepared-source/stamp set. A changed source
	# fingerprint releases that set; world dimensions never multiply its budget.
	return image


static func surface_key(material: String, finish: int) -> String:
	return "%s:%d" % [material, finish]


static func authored_key_allowed(key: String) -> bool:
	# Only the nine existing stone/soil finishes admit richer artwork. A typo,
	# ambiguous number or protected family fails closed instead of adding cache keys.
	for family: String in ["paving", "earth"]:
		for finish: int in Finish.size():
			if finish_allowed(finish, family) and key == surface_key(family, finish):
				return true
	return false


static func prepare_authored_tile(source: Image, base: Color) -> Image:
	# Keep source pixels in their original positions and preserve their relative
	# RGB differences. Mean-centering makes the established court/route tones the
	# visual authority; capped contrast keeps mortar and wear below live effects.
	# No blur, crop, resize, random marks or per-cell lighting is introduced.
	if source == null or source.get_size() != AUTHORED_TILE_SIZE or source.get_format() != Image.FORMAT_RGBA8 or source.has_mipmaps():
		return null
	var average := Color(0, 0, 0, 0)
	for y: int in AUTHORED_TILE_SIZE.y:
		for x: int in AUTHORED_TILE_SIZE.x:
			var color := source.get_pixel(x, y)
			if color.a != 1.0:
				return null
			average += color
	average /= float(AUTHORED_TILE_SIZE.x * AUTHORED_TILE_SIZE.y)
	var image := Image.create(AUTHORED_TILE_SIZE.x, AUTHORED_TILE_SIZE.y, false, Image.FORMAT_RGBA8)
	for y: int in AUTHORED_TILE_SIZE.y:
		for x: int in AUTHORED_TILE_SIZE.x:
			var delta := (source.get_pixel(x, y) - average) * AUTHORED_CONTRAST
			image.set_pixel(x, y, Color(
				clampf(base.r + clampf(delta.r, -AUTHORED_CHANNEL_LIMIT, AUTHORED_CHANNEL_LIMIT), 0.0, 1.0),
				clampf(base.g + clampf(delta.g, -AUTHORED_CHANNEL_LIMIT, AUTHORED_CHANNEL_LIMIT), 0.0, 1.0),
				clampf(base.b + clampf(delta.b, -AUTHORED_CHANNEL_LIMIT, AUTHORED_CHANNEL_LIMIT), 0.0, 1.0), 1.0))
	return image


static func _joined_spans(spans: Array[Rect2i]) -> Array[Rect2i]:
	# The vertical middle of an exact hex is one rectangle instead of fourteen
	# one-pixel calls. Sloped shoulders retain every original ownership sample.
	var rectangles: Array[Rect2i] = []
	for span: Rect2i in spans:
		if not rectangles.is_empty():
			var previous := rectangles[-1]
			if previous.position.x == span.position.x and previous.size.x == span.size.x and previous.end.y == span.position.y:
				previous.size.y += span.size.y
				rectangles[-1] = previous
				continue
		rectangles.append(span)
	return rectangles


static func authored_repeat_bounds(material: String) -> Rect2i:
	# The admitted soil tile has sheet-divider ink in its one-pixel collar:
	# all128 pixels of column127 are below80/255 luminance, unlike its native
	# interior. Repeat only the original126px interior, with no resizing, edge
	# repaint or interpolation. Stone retains its intentional native mortar.
	return SOIL_REPEAT_BOUNDS if material == "earth" else Rect2i(Vector2i.ZERO, AUTHORED_TILE_SIZE)


static func _copy_authored_rect(destination: Image, tile: Image, world_rect: Rect2i, repeat_bounds: Rect2i = Rect2i(0, 0, 128, 128), destination_origin: Vector2i = Vector2i.ZERO) -> int:
	# Split only on native source repeat boundaries, never stretch edge tiles.
	# Image.blit_rect performs all pixel copying natively during setup.
	var clipped := world_rect.intersection(Rect2i(destination_origin, destination.get_size()))
	var count := 0
	var y := clipped.position.y
	while y < clipped.end.y:
		var source_y := repeat_bounds.position.y + posmod(y, repeat_bounds.size.y)
		var height := mini(clipped.end.y - y, repeat_bounds.end.y - source_y)
		var x := clipped.position.x
		while x < clipped.end.x:
			var source_x := repeat_bounds.position.x + posmod(x, repeat_bounds.size.x)
			var width := mini(clipped.end.x - x, repeat_bounds.end.x - source_x)
			destination.blit_rect(tile, Rect2i(source_x, source_y, width, height), Vector2i(x, y) - destination_origin)
			x += width
			count += 1
		y += height
	return count


static func finish_allowed(finish: int, material: String) -> bool:
	if finish == Finish.ORIGINAL:
		return material in FAMILIES
	if finish == Finish.ROUTE:
		return material in ["paving", "earth"]
	return finish >= Finish.COMMONS and finish <= Finish.INSET and material == "paving"


static func finish_tones(palettes: Dictionary) -> Array[Color]:
	# Broad inlays borrow only the admitted material palette. No elemental hues,
	# bevels or shadows: they are flat stone finishes, never new floor authority.
	var paving: Color = terrain_tone(palettes["paving"][0], "paving")
	var earth: Color = terrain_tone(palettes["earth"][0], "earth")
	var stone: Color = terrain_tone(palettes["worldbone"][0], "worldbone")
	var water: Color = terrain_tone(palettes["water"][0], "water")
	# Keep shared trim close to every court so it reads as flush paving, not
	# another solid practice wall. Routes remain quiet in commons but clear on soil.
	return [paving, paving.lightened(0.04), paving.lerp(earth, 0.35).darkened(0.015),
		paving.lerp(stone, 0.40).lightened(0.02), paving.lerp(stone, 0.32).lerp(water, 0.06),
		paving.lerp(stone, 0.22).darkened(0.015), paving.lightened(0.10)]


static func _material_palette(tile: Image) -> Array[Color]:
	# Reuse the authored palette but not its square-brick grout. Most common
	# colors supply a quiet base and two subtle material flecks for hex paving.
	var counts := {}
	for y: int in range(2, 30):
		for x: int in range(2, 30):
			var key := tile.get_pixel(x, y).to_rgba32()
			counts[key] = int(counts.get(key, 0)) + 1
	var keys: Array = counts.keys()
	keys.sort_custom(func(a: int, b: int) -> bool: return int(counts[a]) > int(counts[b]) if int(counts[a]) != int(counts[b]) else a < b)
	var base := Color.hex(int(keys[0]))
	var palette: Array[Color] = [base]
	for index: int in range(1, 3):
		palette.append(base.lerp(Color.hex(int(keys[mini(index, keys.size() - 1)])), 0.38))
	return palette


static func cell_variant(cell: Vector2i) -> int:
	# A bounded integer mix breaks the old three-cell diagonal striping. It is
	# setup-only, stable at negative coordinates, and never touches global RNG.
	var seed := posmod((cell.x * 73856093) ^ (cell.y * 19349663), 2147483647)
	seed = posmod((seed ^ (seed >> 13)) * 1274126177, 2147483647)
	return posmod(seed, VARIANTS)


static func _make_stamp(spans: Array[Rect2i], palette: Array[Color], variant: int, material: String, authored: Image = null, finish: int = Finish.ORIGINAL, tones: Array[Color] = [], paint_joints: bool = true) -> Image:
	var image := Image.create(STAMP_SIZE.x, STAMP_SIZE.y, false, Image.FORMAT_RGBA8)
	var base := terrain_tone(palette[0], material)
	if finish != Finish.ORIGINAL and finish_allowed(finish, material) and tones.size() == Finish.size():
		base = tones[finish]
	if paint_joints:
		base = base.lightened(0.008 * variant)
	# Worn, interrupted joints keep the exact lattice without giving every
	# traversable tile a closed dark outline. Organic floors barely show a seam.
	# No bevel, cast shadow or raised edge can imply a new collision obstacle.
	var edge := base.darkened(0.055 if material == "worldbone" else (0.06 if material == "paving" else 0.01))
	for span: Rect2i in spans:
		image.fill_rect(span, base)
		if paint_joints and posmod(span.position.y + variant * 3, 9) < 6:
			image.set_pixel(span.position.x, span.position.y, edge)
			if span.size.x > 1:
				image.set_pixel(span.end.x - 1, span.position.y, edge)
	if variant >= 2:
		_paint_material_mark(image, spans, material, variant, base)
		_paint_authored_wear(image, spans, authored, palette[0], variant, base)
	return image


static func _paint_authored_wear(image: Image, spans: Array[Rect2i], authored: Image, authored_base: Color, variant: int, base: Color) -> void:
	# Borrow native interior wear, not square grout/alpha borders or a second
	# floor grid. Quantize its value to the same two quiet tones as the motif.
	# This bounded shoulder patch runs only while making a cached hex stamp.
	if authored == null or authored.get_size() != Vector2i(32, 32):
		return
	var dark := base.darkened(0.065)
	var light := base.lightened(0.055)
	var painted := 0
	for y: int in range(5, 9):
		for x: int in range(5, 18):
			if painted >= AUTHORED_WEAR_PIXEL_LIMIT:
				return
			# Interrupted little clusters, never a complete rectangular outline.
			if posmod(x + variant, 7) == 0:
				continue
			var source := authored.get_pixel(x + 4, y + 8)
			var contrast := source.get_luminance() - authored_base.get_luminance()
			if source.a < 1.0 or absf(contrast) < 0.018:
				continue
			var point := Vector2i(x, y)
			if variant == 3:
				point = Vector2i(23, 28) - point
			for span: Rect2i in spans:
				if span.has_point(point) and point.x > span.position.x and point.x < span.end.x - 1:
					image.set_pixelv(point, dark if contrast < 0 else light)
					painted += 1
					break


static func _paint_material_mark(image: Image, spans: Array[Rect2i], material: String, variant: int, base: Color) -> void:
	var rows: Array = MATERIAL_MARKS.get(material, [])
	var dark := base.darkened(0.065)
	var light := base.lightened(0.055)
	for y: int in range(rows.size()):
		var row := String(rows[y])
		for x: int in range(row.length()):
			if row[x] == ".":
				continue
			var point := Vector2i(3 + x, 20 + y)
			if variant == 3:
				point = Vector2i(23, 28) - point
			# Clip against exact row-phase ownership, not a decorative hex mask.
			# Keep one untouched pixel between a mark and the actual cell edge.
			for span: Rect2i in spans:
				if span.has_point(point) and point.x > span.position.x and point.x < span.end.x - 1:
					image.set_pixelv(point, dark if row[x] == "d" else light)
					break


static func terrain_tone(authored: Color, material: String) -> Color:
	# Reuse the reviewed atlas values; restrained material tinting, never hazard
	# saturation. All tinting happens once at composition, not during drawing.
	var accents := {"paving": Color("ae9c78"), "earth": Color("88704d"),
		"grass": Color("426c44"), "worldbone": Color("526365"), "water": Color("285f73")}
	return authored.lerp(accents.get(material, authored), 0.32)
