extends FluxTestSuite

const Terrain = preload("res://src/presentation/hex_environment_layout.gd")


func run() -> int:
	_test_raster_ownership()
	_test_inlay_bounds()
	_test_terrain_hierarchy()
	_test_material_wear()
	_test_variant_distribution()
	var library := PixelMapLibrary.default_library()
	var style := WellspringIllustratedKit.GroundStyle.new()
	check(style.configure_style(library), "hex terrain receives the validated authored palette")
	_test_authored_wear(style)
	_test_floor_finishes(style)
	var terrain := Terrain.new()
	var classify := func(point: Vector2) -> String: return Terrain.FAMILIES[posmod(Terrain.cell_at(point).x, Terrain.FAMILIES.size())]
	var image: Image = terrain.compose(Vector2i(192, 144), classify, style)
	check(image != null, "hex floor composes from exact cells and existing material art")
	if image != null:
		equal(image.get_size(), Vector2i(192, 144), "hex raster covers the requested canvas without rescaling")
		for y: int in range(image.get_height()):
			for x: int in range(image.get_width()):
				equal(image.get_pixel(x, y).a, 1.0, "canonical stamps cover every pixel without seams")
		var repeat: Image = terrain.compose(Vector2i(192, 144), classify, style)
		equal(image.get_data(), repeat.get_data(), "authored colors and deterministic hex variants reproduce exactly")
		check(terrain.stamp_count > 0 and terrain.stamp_count <= Terrain.FAMILIES.size() * Terrain.VARIANTS * 125, "stamp preparation has a fixed row-phase/material bound")
		check(terrain.cell_count >= terrain.stamp_count, "every prepared stamp is used by at least one map cell")
	check(terrain.compose(Vector2i(4097, 8), classify, style) == null, "oversized terrain fails before allocating a raster")
	check(terrain.compose(Vector2i(0, 8), classify, style) == null, "empty terrain fails closed")
	check(terrain.compose(Vector2i(8, 8), Callable(), style) == null, "missing classification fails closed")
	check(terrain.compose(Vector2i(8, 8), classify, null) == null, "missing validated style fails closed")
	check(terrain.compose(Vector2i(8, 8), func(_point: Vector2) -> String: return "invented", style) == null, "unknown material cannot silently paint an accepted map")
	_test_continuous_surfaces(style)
	return finish("hex-environment-layout")


func _test_continuous_surfaces(style: RefCounted) -> void:
	var texture := load("res://assets/environment/wellspring_v3/surfaces.png") as Texture2D
	var atlas := texture.get_image()
	atlas.convert(Image.FORMAT_RGBA8)
	var kit := WellspringIllustratedKit.new()
	for index: int in 16:
		kit.tiles.append(atlas.get_region(Rect2i(index % 4 * 128, index / 4 * 128, 128, 128)))
	var sources: Dictionary = kit.ground_surface_sources()
	equal(sources.size(), Terrain.MAX_AUTHORED_TILES, "live ground reuses exactly nine existing stone/soil finish sources")
	var originals := {}
	var palettes := {}
	for family: String in Terrain.FAMILIES:
		palettes[family] = Terrain._material_palette(style.tile_image("map.terrain.%s.fill_v1" % family))
	var tones: Array[Color] = Terrain.finish_tones(palettes)
	var prepared := {}
	for key: String in sources:
		var source: Image = sources[key]
		originals[key] = source.get_data()
		var family := key.get_slice(":", 0)
		var finish := int(key.get_slice(":", 1))
		var base: Color = Terrain.terrain_tone(palettes[family][0], family) if finish == Terrain.Finish.ORIGINAL else tones[finish]
		var tile := Terrain.prepare_authored_tile(source, base)
		check(tile != null, "admitted native opaque source prepares without a new asset")
		if tile == null: return
		prepared[key] = tile
		equal(tile.get_size(), source.get_size(), "authored paving is never cropped, blurred, rotated or rescaled")
		equal(tile.get_data(), Terrain.prepare_authored_tile(source, base).get_data(), "source-to-finish transformation is deterministic")
		var average := Color(0, 0, 0, 0)
		var maximum_delta := 0.0
		var squared_delta := 0.0
		var colors := {}
		var visible_detail := 0
		var ordered_pairs := 0
		var checked_pairs := 0
		for y: int in 128:
			for x: int in 128:
				var color := tile.get_pixel(x, y)
				average += color
				var delta := maxf(absf(color.r - base.r), maxf(absf(color.g - base.g), absf(color.b - base.b)))
				maximum_delta = maxf(maximum_delta, delta)
				squared_delta += pow(color.get_luminance() - base.get_luminance(), 2)
				colors[color.to_rgba32()] = true
				if delta >= 0.012: visible_detail += 1
				check(color.a == 1.0, "authored material detail never cuts alpha holes")
				# Compare native horizontal red-channel ordering, independent of
				# the preparation implementation. Real source joints must survive.
				if x < 127 and absf(source.get_pixel(x + 1, y).r - source.get_pixel(x, y).r) > 0.04:
					checked_pairs += 1
					var source_difference := source.get_pixel(x + 1, y).r - source.get_pixel(x, y).r
					var output_difference := tile.get_pixel(x + 1, y).r - color.r
					if source_difference * output_difference > 0.0: ordered_pairs += 1
		average /= 16384.0
		check(maximum_delta <= Terrain.AUTHORED_CHANNEL_LIMIT + 1.0 / 255.0, "native joints remain within the quiet ten-percent channel contrast budget")
		check(sqrt(squared_delta / 16384.0) < 0.055, "whole-tile RMS contrast stays subordinate to actors and live matter")
		check(absf(average.get_luminance() - base.get_luminance()) < 0.015, "native texture preserves the classified court/route mean brightness")
		check(colors.size() > 24 and visible_detail > 2000, "actual imported stone/soil detail replaces flat color plus sparse procedural specks")
		check(checked_pairs > 100 and ordered_pairs >= checked_pairs * 0.85, "at least85 percent of native high-contrast source pairs retain their authored order")
		equal(source.get_data(), originals[key], "preparation cannot mutate the shared original atlas tile")
	# Uniform terrain is byte-identical to a native repeated source over every
	# chemistry boundary and128px source boundary: no hidden per-hex outline.
	var terrain := Terrain.new()
	var paving := func(_point: Vector2) -> String: return "paving"
	var size := Vector2i(257, 145)
	var image: Image = terrain.compose(size, paving, style, Callable(), sources)
	check(image != null, "continuous imported stone composes an odd-sized native floor")
	if image == null: return
	var original_tile: Image = prepared[Terrain.surface_key("paving", Terrain.Finish.ORIGINAL)]
	var seamless := true
	for y: int in size.y:
		for x: int in size.x:
			seamless = seamless and image.get_pixel(x, y) == original_tile.get_pixel(x % 128, y % 128)
	check(seamless, "native pixels continue unchanged across every true hex edge with no artificial empty-floor mesh")
	equal(image.get_data(), terrain.compose(size, paving, style, Callable(), sources).get_data(), "complete continuous stone repeats exactly without RNG or time input")
	equal(terrain.authored_tile_bytes, Terrain.MAX_AUTHORED_BYTES, "nine native variants have exact576KiB transient image accounting")
	equal(terrain.stamp_count, 0, "uniform stone needs no per-cell phase/variant image cache")
	check(terrain.authored_copy_count > 0 and terrain.authored_copy_count <= terrain.cell_count * 40, "joined ownership spans bound native setup copy submissions")
	_test_real_soil_repeat(style, sources, prepared, atlas)
	# Mixed families and finishes compare every pixel to the independent actual
	# chemistry owner, not to a decorative mask or the composer's iteration order.
	var material_at := func(point: Vector2) -> String: return Terrain.FAMILIES[posmod(Terrain.cell_at(point).x, Terrain.FAMILIES.size())]
	var finish_at := func(point: Vector2, material: String) -> int:
		if material == "earth": return Terrain.Finish.ROUTE if posmod(Terrain.cell_at(point).y, 2) == 0 else Terrain.Finish.ORIGINAL
		if material == "paving": return posmod(Terrain.cell_at(point).y, Terrain.Finish.size())
		return Terrain.Finish.ORIGINAL
	var mixed: Image = terrain.compose(size, material_at, style, finish_at, sources)
	check(mixed != null, "all five families coexist with the nine authored finishes")
	if mixed == null: return
	var exact := true
	var expected_stamps := {}
	for y: int in size.y:
		for x: int in size.x:
			var cell := HexGrid.world_to_cell(Vector2i(x * 1000 + 500, y * 1000 + 500))
			var point := Vector2(HexGrid.center(cell)) / 1000.0
			var material: String = material_at.call(point)
			var finish: int = finish_at.call(point, material)
			var key := Terrain.surface_key(material, finish)
			var expected: Color
			if prepared.has(key):
				# Independent mapping: soil omits the proven one-pixel sheet ink;
				# stone remains the complete native128px authored material.
				var source_point := Vector2i(1 + x % 126, 1 + y % 126) if material == "earth" else Vector2i(x % 128, y % 128)
				expected = (prepared[key] as Image).get_pixelv(source_point)
			else:
				var stamp_key := "%s:%d:%d" % [key, cell.y, Terrain.cell_variant(cell)]
				if not expected_stamps.has(stamp_key):
					expected_stamps[stamp_key] = Terrain._make_stamp(Terrain.raster_spans(cell.y), palettes[material], Terrain.cell_variant(cell), material, style.tile_image("map.terrain.%s.fill_v1" % material), finish, tones, false)
				expected = (expected_stamps[stamp_key] as Image).get_pixelv(Vector2i(x, y) - Terrain.raster_origin(cell))
			exact = exact and mixed.get_pixel(x, y) == expected and expected.a == 1.0
	check(exact, "mixed finish boundaries retain every exact canonical owner, opaque pixel and protected family")
	check(terrain.stamp_bytes + terrain.authored_tile_bytes <= Terrain.MAX_STAMP_BYTES, "all transient composition images fit the existing16MiB budget together")
	var invalid := sources.duplicate()
	invalid.erase(Terrain.surface_key("earth", Terrain.Finish.ROUTE))
	check(terrain.compose(size, paving, style, Callable(), invalid) == null, "an incomplete live source set cannot silently fall back to flat stone")
	invalid = sources.duplicate()
	invalid.erase(Terrain.surface_key("earth", Terrain.Finish.ROUTE))
	invalid["grass:0"] = sources["earth:0"]
	check(terrain.compose(size, paving, style, Callable(), invalid) == null, "source data cannot override protected grass or invent terrain authority")
	invalid = sources.duplicate()
	invalid["paving:0"] = Image.create(127, 128, false, Image.FORMAT_RGBA8)
	check(terrain.compose(size, paving, style, Callable(), invalid) == null, "resized native artwork is rejected")
	invalid["paving:0"] = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	check(terrain.compose(size, paving, style, Callable(), invalid) == null, "transparent source images cannot introduce holes or fake art")
	for key: String in sources:
		equal((sources[key] as Image).get_data(), originals[key], "successful and rejected live compositions preserve original source pixels")
	for row: int in [-1, 0, 1, 62, 124]:
		var spans: Array[Rect2i] = Terrain.raster_spans(row)
		var rectangles: Array[Rect2i] = Terrain._joined_spans(spans)
		check(rectangles.size() < spans.size(), "native scanline joining reduces calls without changing geometry")
		for y: int in 29:
			for x: int in 24:
				var in_spans := false
				var in_rectangles := 0
				for span: Rect2i in spans: in_spans = in_spans or span.has_point(Vector2i(x, y))
				for rectangle: Rect2i in rectangles: in_rectangles += 1 if rectangle.has_point(Vector2i(x, y)) else 0
				equal(in_rectangles, 1 if in_spans else 0, "joined rectangles preserve exact ownership once at every positive/negative row phase")


func _test_real_soil_repeat(style: RefCounted, sources: Dictionary, prepared: Dictionary, atlas: Image) -> void:
	var source: Image = sources["earth:0"]
	var original := source.get_data()
	equal(original, atlas.get_region(Rect2i(256, 128, 128, 128)).get_data(), "soil is exactly admitted atlas tile6, not an offset extraction or a substitute")
	var left_ink := 0
	var right_ink := 0
	for y: int in 128:
		if source.get_pixel(0, y).get_luminance() * 255.0 < 80.0: left_ink += 1
		if source.get_pixel(127, y).get_luminance() * 255.0 < 80.0: right_ink += 1
	equal(left_ink, 125, "real source has125 dark pixels in its outer left ink column")
	equal(right_ink, 128, "real source has a complete128-pixel dark outer right ink column")
	equal(Terrain.authored_repeat_bounds("earth"), Rect2i(1, 1, 126, 126), "only the measured soil collar is excluded, retaining every native interior pixel")
	for family: String in ["paving", "grass", "worldbone", "water"]:
		equal(Terrain.authored_repeat_bounds(family), Rect2i(0, 0, 128, 128), "soil repair cannot crop other material families")
	var terrain := Terrain.new()
	var earth := func(_point: Vector2) -> String: return "earth"
	# Cross both126px native interior repeats and the former128px dark-ink joins.
	var size := Vector2i(259, 257)
	for finish: int in [Terrain.Finish.ORIGINAL, Terrain.Finish.ROUTE]:
		var finish_at := func(_point: Vector2, _material: String) -> int: return finish
		var image: Image = terrain.compose(size, earth, style, finish_at, sources)
		check(image != null, "native soil and the route ribbon compose without divider ink")
		if image == null: return
		var tile: Image = prepared[Terrain.surface_key("earth", finish)]
		var exact := true
		for y: int in size.y:
			for x: int in size.x:
				exact = exact and image.get_pixel(x, y) == tile.get_pixel(1 + x % 126, 1 + y % 126)
		check(exact, "every soil/ribbon output pixel equals its exact native interior source, including repeat and hex edges")
		equal(image.get_data(), terrain.compose(size, earth, style, finish_at, sources).get_data(), "soil collar exclusion is deterministic across complete recomposition")
		equal(terrain.stamp_count, 0, "soil repair introduces no per-cell stamps or artificial mesh")
		check(terrain.authored_copy_count <= terrain.cell_count * 40, "soil interior splitting retains the bounded native-copy budget")
	equal(source.get_data(), original, "soil repair never rewrites or resizes the imported source image")
	equal(original, atlas.get_region(Rect2i(256, 128, 128, 128)).get_data(), "the full original atlas remains byte-for-byte unchanged after soil composition")


func _test_floor_finishes(style: RefCounted) -> void:
	var palettes := {}
	var source_bytes := {}
	for family: String in Terrain.FAMILIES:
		var tile := style.tile_image("map.terrain.%s.fill_v1" % family) as Image
		palettes[family] = Terrain._material_palette(tile)
		source_bytes[family] = tile.get_data()
	var tones: Array[Color] = Terrain.finish_tones(palettes)
	equal(tones.size(), Terrain.Finish.size(), "floor finishes have one finite shared palette, not per-cell colors")
	var inset_luminance: float = tones[Terrain.Finish.INSET].get_luminance()
	var route_luminance: float = tones[Terrain.Finish.ROUTE].get_luminance()
	var paving_luminance: float = Terrain.terrain_tone(palettes["paving"][0], "paving").get_luminance()
	var earth_luminance: float = Terrain.terrain_tone(palettes["earth"][0], "earth").get_luminance()
	var distinct := {}
	for kind: int in range(Terrain.Finish.COMMONS, Terrain.Finish.CHAIN + 1):
		var tone := tones[kind]
		check(tone.a == 1.0 and tone.s < 0.40 and tone.get_luminance() > 0.15 and tone.get_luminance() < 0.85, "court finishes are opaque quiet stone, never emissive hazard colors")
		check(not distinct.has(tone.to_rgba32()), "commons, chemistry, sparring and chain keep distinct finishes")
		check(absf(inset_luminance - tone.get_luminance()) <= tone.get_luminance() * 0.12, "shared flat inset stays within twelve percent of every court, never a dark barrier")
		distinct[tone.to_rgba32()] = true
	check(tones[Terrain.Finish.ROUTE].get_luminance() > tones[Terrain.Finish.COMMONS].get_luminance(), "ordinary circulation remains legible through the light commons field")
	check(route_luminance - tones[Terrain.Finish.COMMONS].get_luminance() <= tones[Terrain.Finish.COMMONS].get_luminance() * 0.05, "crossing ribbon stays within five percent of commons brightness")
	check(route_luminance > paving_luminance and route_luminance - paving_luminance <= paving_luminance * 0.08, "route accents stay within eight percent of ordinary paving brightness")
	check(route_luminance >= earth_luminance * 1.20, "the same quiet ribbon remains readable on darker earth approaches")
	check(not Terrain.finish_allowed(-1, "paving") and not Terrain.finish_allowed(99, "paving"), "unbounded finish identifiers cannot grow the cache")
	check(not Terrain.finish_allowed(Terrain.Finish.ORIGINAL, "invented"), "a finish cannot authorize an unknown base material")
	var combinations := 0
	for family: String in Terrain.FAMILIES:
		var tile := style.tile_image("map.terrain.%s.fill_v1" % family) as Image
		var palette: Array[Color] = palettes[family]
		for kind: int in Terrain.Finish.size():
			if not Terrain.finish_allowed(kind, family): continue
			combinations += 1
			for row: int in [-1, 0, 1, 62, 124]:
				var spans: Array[Rect2i] = Terrain.raster_spans(row)
				var original: Image = Terrain._make_stamp(spans, palette, 2, family, tile)
				var prepared: Image = Terrain._make_stamp(spans, palette, 2, family, tile, kind, tones)
				equal(prepared.get_data(), Terrain._make_stamp(spans, palette, 2, family, tile, kind, tones).get_data(), "every finish deterministically reuses the native cached stamp recipe")
				equal(prepared.get_size(), original.get_size(), "inlays never enlarge a cell or add another raster layer")
				var base := prepared.get_pixel(12, 14)
				var same_alpha := true
				var quiet_center := true
				var bounded_contrast := true
				var opaque := 0
				var calm := 0
				var colors := {}
				for y: int in prepared.get_height():
					for x: int in prepared.get_width():
						var color := prepared.get_pixel(x, y)
						same_alpha = same_alpha and color.a == original.get_pixel(x, y).a
						if color.a == 0.0: continue
						opaque += 1
						if color == base: calm += 1
						colors[color.to_rgba32()] = true
						bounded_contrast = bounded_contrast and absf(color.r - base.r) <= 0.07 and absf(color.g - base.g) <= 0.07 and absf(color.b - base.b) <= 0.07
						if Rect2i(7, 9, 10, 11).has_point(Vector2i(x, y)):
							quiet_center = quiet_center and color == base
				check(same_alpha, "all finishes retain exact hex edges and coverage through each row phase")
				check(quiet_center and calm * 100 >= opaque * 85, "floor identity comes from broad finishes, not busy cell centers")
				check(bounded_contrast and colors.size() <= 4, "inlays preserve the existing quiet four-tone native texture detail")
				if kind == Terrain.Finish.ORIGINAL:
					equal(prepared.get_data(), original.get_data(), "unaccented materials remain byte-identical")
		equal(tile.get_data(), source_bytes[family], "finish preparation cannot repaint the approved source atlas")
	equal(combinations, 12, "five originals, four rooms, one inset and two route families bound the stamp space")
	equal(Terrain.MAX_STAMPS, combinations * Terrain.VARIANTS * 125, "stamp count limit covers exactly the finite finish/material/phase combinations")
	check(Terrain.MAX_STAMPS * Terrain.STAMP_SIZE.x * Terrain.STAMP_SIZE.y * 4 <= Terrain.MAX_STAMP_BYTES, "even every possible setup stamp fits the16MiB transient budget")
	var terrain := Terrain.new()
	var material_at := func(point: Vector2) -> String: return Terrain.FAMILIES[posmod(Terrain.cell_at(point).x, Terrain.FAMILIES.size())]
	var finish_at := func(point: Vector2, material: String) -> int:
		if material == "earth": return Terrain.Finish.ROUTE
		if material == "paving": return Terrain.Finish.COMMONS if posmod(Terrain.cell_at(point).y, 2) == 0 else Terrain.Finish.INSET
		return Terrain.Finish.ORIGINAL
	var size := Vector2i(192, 144)
	var plain: Image = terrain.compose(size, material_at, style)
	var prepared: Image = terrain.compose(size, material_at, style, finish_at)
	check(plain != null and prepared != null, "bounded finish callback composes the existing five-family floor")
	if plain != null and prepared != null:
		var same_coverage := true
		var protected_same := true
		var changed := false
		for y: int in size.y:
			for x: int in size.x:
				var old := plain.get_pixel(x, y)
				var current := prepared.get_pixel(x, y)
				same_coverage = same_coverage and current.a == 1.0 and current.a == old.a
				var family := String(material_at.call(Vector2(x + 0.5, y + 0.5)))
				if family not in ["earth", "paving"]: protected_same = protected_same and current == old
				changed = changed or current != old
		check(same_coverage and protected_same, "full composition changes finishes but neither seams nor grass/water/worldbone pixels")
		check(changed, "the live composition applies inlays rather than only reporting their IDs")
		equal(prepared.get_data(), terrain.compose(size, material_at, style, finish_at).get_data(), "complete inlaid raster is deterministic")
		equal(terrain.stamp_bytes, terrain.stamp_count * Terrain.STAMP_SIZE.x * Terrain.STAMP_SIZE.y * 4, "temporary stamp accounting matches actual RGBA extents")
		check(terrain.stamp_count <= Terrain.MAX_STAMPS and terrain.stamp_bytes <= Terrain.MAX_STAMP_BYTES, "composition stays within both setup cache limits")
	var paving := func(_point: Vector2) -> String: return "paving"
	check(terrain.compose(Vector2i(8, 8), paving, style, func(_p: Vector2, _m: String) -> int: return 99) == null, "unknown finish fails closed before any unbounded cache entry")
	check(terrain.compose(Vector2i(8, 8), paving, style, func(_p: Vector2, _m: String) -> float: return 1.0) == null, "noninteger finish metadata is not silently coerced")
	check(terrain.compose(Vector2i(8, 8), func(_p: Vector2) -> String: return "grass", style, func(_p: Vector2, _m: String) -> int: return Terrain.Finish.ROUTE) == null, "route finishes cannot repaint protected garden families")
	for family: String in Terrain.FAMILIES:
		equal((style.tile_image("map.terrain.%s.fill_v1" % family) as Image).get_data(), source_bytes[family], "successful and failed compositions leave every source image untouched")


func _test_terrain_hierarchy() -> void:
	var neutral := Color("999999")
	var tones := {}
	for material: String in Terrain.FAMILIES:
		var tone := Terrain.terrain_tone(neutral, material)
		equal(tone.a, 1.0, "terrain tint cannot introduce holes")
		check(tone.s < 0.25, "terrain accents stay restrained so combat saturation leads")
		check(not tones.has(tone.to_html()), "each floor material keeps its own restrained hue")
		tones[tone.to_html()] = true
	equal(Terrain.terrain_tone(neutral, "unknown"), neutral, "unknown tone cannot invent an unreviewed tint")


func _test_material_wear() -> void:
	var palette: Array[Color] = [Color("999999")]
	var material_masks := {}
	for material: String in Terrain.FAMILIES:
		for variant: int in range(Terrain.VARIANTS):
			for row: int in [-1, 0, 1, 62, 124]:
				var spans: Array[Rect2i] = Terrain.raster_spans(row)
				var stamp: Image = Terrain._make_stamp(spans, palette, variant, material)
				var base := stamp.get_pixel(12, 14)
				var opaque := 0
				var unmarked := 0
				var colors := {}
				for y: int in range(stamp.get_height()):
					for x: int in range(stamp.get_width()):
						var point := Vector2i(x, y)
						var color := stamp.get_pixelv(point)
						var owned := false
						for span: Rect2i in spans:
							if span.has_point(point):
								owned = true
								break
						equal(color.a, 1.0 if owned else 0.0, "material wear cannot add pixels outside ownership or cut holes in the floor")
						if not owned:
							continue
						opaque += 1
						if color == base:
							unmarked += 1
						colors[color.to_rgba32()] = true
						check(absf(color.r - base.r) <= 0.07 and absf(color.g - base.g) <= 0.07 and absf(color.b - base.b) <= 0.07, "static wear remains lower-contrast than live danger")
						if Rect2i(7, 9, 10, 11).has_point(point):
							equal(color, base, "tile centres stay empty for feet and active matter")
				check(unmarked * 100 >= opaque * 85, "at least 85 percent of each floor tile stays calm")
				check(colors.size() <= 4, "a static stamp has at most base, joint and two mark tones")
				if variant < 2:
					check(colors.size() <= 2, "half of the surface variants carry no decorative mark")
		var marked: Image = Terrain._make_stamp(Terrain.raster_spans(0), palette, 2, material)
		var marked_base := marked.get_pixel(12, 14)
		var mask := ""
		for y: int in range(20, 23):
			for x: int in range(3, 9):
				mask += "x" if marked.get_pixel(x, y) != marked_base else "."
		check(mask.contains("x"), "each material receives its own small surface motif")
		check(not material_masks.has(mask), "material identity uses a distinct pixel shape as well as hue")
		material_masks[mask] = true


func _test_authored_wear(style: RefCounted) -> void:
	var changed_total := 0
	for material: String in Terrain.FAMILIES:
		var tile := style.tile_image("map.terrain.%s.fill_v1" % material) as Image
		var before := tile.get_data()
		var palette: Array[Color] = Terrain._material_palette(tile)
		for variant: int in Terrain.VARIANTS:
			for row: int in [-1, 0, 1, 62, 124]:
				var spans: Array[Rect2i] = Terrain.raster_spans(row)
				var plain: Image = Terrain._make_stamp(spans, palette, variant, material)
				var sampled: Image = Terrain._make_stamp(spans, palette, variant, material, tile)
				var repeated: Image = Terrain._make_stamp(spans, palette, variant, material, tile)
				equal(sampled.get_data(), repeated.get_data(), "native source sampling produces identical cached stamps")
				var base := sampled.get_pixel(12, 14)
				var changed := 0
				var opaque := 0
				var unmarked := 0
				var colors := {}
				for y: int in sampled.get_height():
					for x: int in sampled.get_width():
						var color := sampled.get_pixel(x, y)
						var old := plain.get_pixel(x, y)
						equal(color.a, old.a, "source detail cannot change exact chemistry hex ownership or alpha")
						if color != old: changed += 1
						if color.a == 0.0: continue
						opaque += 1
						if color == base: unmarked += 1
						colors[color.to_rgba32()] = true
						check(absf(color.r - base.r) <= 0.07 and absf(color.g - base.g) <= 0.07 and absf(color.b - base.b) <= 0.07, "authored wear remains subordinate to active spell contrast")
						if Rect2i(7, 9, 10, 11).has_point(Vector2i(x, y)):
							equal(color, base, "authored detail leaves the full feet/matter center clear")
				for span: Rect2i in spans:
					for x: int in [span.position.x, span.end.x - 1]:
						equal(sampled.get_pixel(x, span.position.y), plain.get_pixel(x, span.position.y), "sampling cannot overwrite a shared hex edge or create a seam")
				check(changed <= Terrain.AUTHORED_WEAR_PIXEL_LIMIT, "source contribution is capped at sixteen pixels per cached stamp")
				check(unmarked * 100 >= opaque * 85, "at least 85 percent of each sampled hex remains quiet")
				check(colors.size() <= 4, "source reuse introduces no extra noise palette")
				if variant < 2: equal(changed, 0, "half the variants remain free of authored wear")
				changed_total += changed
		equal(tile.get_data(), before, "sampling cannot mutate the approved source tile")
	check(changed_total > 0, "live ground genuinely reuses authored texture detail rather than only its average color")
	var flat := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	flat.fill(Color("999999"))
	var fixture_palette: Array[Color] = [Color("999999")]
	var fixture_spans: Array[Rect2i] = Terrain.raster_spans(0)
	var fixture_plain: Image = Terrain._make_stamp(fixture_spans, fixture_palette, 2, "paving")
	var transparent := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	transparent.fill(Color(0, 0, 0, 0))
	equal(Terrain._make_stamp(fixture_spans, fixture_palette, 2, "paving", transparent).get_data(), fixture_plain.get_data(), "transparent source pixels cannot invent dark wear or floor holes")
	# A noisy collar is not usable surface detail; only native interior pixels count.
	flat.fill_rect(Rect2i(0, 0, 32, 2), Color.BLACK)
	flat.fill_rect(Rect2i(0, 30, 32, 2), Color.BLACK)
	flat.fill_rect(Rect2i(0, 0, 2, 32), Color.BLACK)
	flat.fill_rect(Rect2i(30, 0, 2, 32), Color.BLACK)
	equal(Terrain._make_stamp(fixture_spans, fixture_palette, 2, "paving", flat).get_data(), fixture_plain.get_data(), "source atlas collars and square boundary ink are never sampled")
	var kit_source := FileAccess.get_file_as_string("res://src/presentation/wellspring_illustrated_kit.gd").replace("\r", "")
	var draw_source := kit_source.get_slice("func draw_ground(", 1).get_slice("\n\nfunc ", 0)
	check(draw_source.contains("canvas.draw_texture(ground, Vector2.ZERO)"), "small-map compatibility retains its one cached native floor")
	check(not draw_source.contains("compose_region") and not draw_source.contains("Image.create") and not draw_source.contains("surface_at"), "ground drawing delegates bounded cache preparation without inline per-cell sampling")


func _test_variant_distribution() -> void:
	var counts := PackedInt32Array()
	counts.resize(Terrain.VARIANTS)
	var breaks_old_repeat := false
	for y: int in range(-24, 25):
		for x: int in range(-24, 25):
			var cell := Vector2i(x, y)
			var variant: int = Terrain.cell_variant(cell)
			check(variant >= 0 and variant < Terrain.VARIANTS, "positive and negative cells use the bounded stamp cache")
			equal(variant, Terrain.cell_variant(cell), "material variation is deterministic without global RNG")
			counts[variant] += 1
			if variant != Terrain.cell_variant(cell + Vector2i(3, 0)):
				breaks_old_repeat = true
	for count: int in counts:
		check(count > 400 and count < 800, "broad floor areas mix quiet and marked variants without a dominant repeat")
	check(breaks_old_repeat, "ground no longer repeats its detail every three columns")


func _test_raster_ownership() -> void:
	for row: int in range(-1, 125):
		var cell := Vector2i(0, row)
		var origin := Terrain.raster_origin(cell)
		var spans: Array[Rect2i] = Terrain.raster_spans(row)
		check(not spans.is_empty(), "every positive and negative row phase rasterizes")
		for span: Rect2i in spans:
			check(Rect2i(0, 0, 24, 29).encloses(span), "every stamp span stays in its fixed texture extent")
			for x: int in [span.position.x, span.position.x + (span.size.x >> 1), span.end.x - 1]:
				var sample := (origin + Vector2i(x, span.position.y)) * 1000 + Vector2i(500, 500)
				equal(HexGrid.world_to_cell(sample), cell, "raster pixel center belongs to exactly the chemistry hex being painted")
			for outside: Vector2i in [origin + span.position - Vector2i(1, 0), origin + Vector2i(span.end.x, span.position.y)]:
				check(HexGrid.world_to_cell(outside * 1000 + Vector2i(500, 500)) != cell, "span is maximal and cannot hide a one-pixel gap")
		var translated := cell + Vector2i(-23, 0)
		equal(Terrain.raster_origin(translated) - origin, Vector2i(-23 * 24, 0), "negative columns reuse the exact same stamp without rounding drift")
		equal(Terrain.cell_at(Terrain.center_pixels(translated)), translated, "pixel and simulation conversions share the same origin")


func _test_inlay_bounds() -> void:
	for bounds: Rect2 in [Rect2(280, 368, 320, 28), Rect2(736, 352, 28, 320), Rect2(1248, 192, 576, 112), Rect2(-14, -29, 72, 72)]:
		var lines: PackedVector2Array = Terrain.inlay_lines(bounds)
		check(not lines.is_empty() and lines.size() % 2 == 0, "wall and roof cap details contain complete bounded line pairs")
		for point: Vector2 in lines:
			check(point.x >= bounds.position.x - 0.001 and point.y >= bounds.position.y - 0.001 and point.x <= bounds.end.x + 0.001 and point.y <= bounds.end.y + 0.001, "hex detail cannot extend a rectangular collision silhouette")
		equal(lines, Terrain.inlay_lines(bounds), "architecture geometry is deterministic for cache reuse")
	check(Terrain.inlay_lines(Rect2()).is_empty(), "empty architecture has no invented outline")
