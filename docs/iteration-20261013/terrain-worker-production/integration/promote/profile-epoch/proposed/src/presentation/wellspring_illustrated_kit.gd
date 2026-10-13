class_name WellspringIllustratedKit
extends RefCounted

# Bounded terrain regions plus shared object atlases. Map data remains the
# only authority for walkability, walls, targets and station commands.
const PATH := "res://content/visual/wellspring_illustrated_v1.json"
const MapLibrary = preload("res://src/presentation/pixel_map_library.gd")
const GroundStyle = preload("res://art_batches/wellspring_style_v2/ground_style.gd")
const HexTerrain = preload("res://src/presentation/hex_environment_layout.gd")
const WallSkin = preload("res://src/presentation/practice_wall_skin.gd")
const ROOF_SKIN_VERSION := "slate-roofs-1"
const ROOF_CACHE_MAX_BYTES := 1024 * 1024
const PRACTICE_CACHE_MAX_BYTES := 3 * 1024 * 1024
const GROUND_CHUNK_SIZE := 512
const GROUND_CACHE_LIMIT := 24 # Explicit synchronous tooling cache, not a viewport limit.
const GROUND_MAX_RESIDENT := 132
const TerrainStream = preload("res://src/presentation/wellspring_terrain_stream.gd")
const AsyncTerrainStream = preload("res://src/presentation/wellspring_async_terrain_stream.gd")
const GROUND_SAMPLER_VERSION := "authored-regions-2"
const GROUND_CACHE_MAX_BYTES := 6144 * 5376 * 4
const OVERVIEW_SCALE := 4
const LARGE_WORLD_MAX := Vector2i(6144, 5376)
const DistrictStyle = preload("res://src/presentation/wellspring_district_style.gd")
const COMMONS_FLOOR := Rect2(1148, 568, 776, 568)
const FLOOR_INSET := 24.0
const FLOOR_RIBBON_HALF_WIDTH := 24.0
const PROP_IDS := ["oak", "small_tree", "flowers", "ferns", "wall_horizontal", "wall_vertical", "rocks", "planter", "fountain", "lectern", "target", "bell", "doorway", "bench", "lantern", "banner"]
var data: Dictionary = {}
var content_hash := ""
var last_error := ""
var ground: Texture2D
var ground_chunks: Dictionary[Vector2i, Texture2D] = {}
var ground_chunk_order: Array[Vector2i] = []
var ground_cache_bytes := 0
var ground_chunk_builds := 0
var ground_chunk_hits := 0
var ground_overview: Texture2D
var terrain_stream: RefCounted
var bake_signature := ""
var surfaces: Texture2D
var props: Texture2D
var tiles: Array[Image] = []
var water_tiles: Array[Image] = []
var paths: Array[Dictionary] = []
var decorations: Array[Dictionary] = []
var campus: SanctumCampusLayout
var cached_terrain_builds := 0
var ground_generation_ms := 0
var pixel_map: RefCounted
var ground_style: RefCounted
var hex_terrain: RefCounted
var roof_skins: Dictionary[int, Texture2D] = {}
var roof_skin_bytes := 0
var cached_roof_builds := 0
var practice_skins: Dictionary[int, Texture2D] = {}
var practice_skin_bytes := 0


class GroundRegionSampler:
	extends RefCounted
	# Short-lived broadphase only. Preserve original callback precedence and
	# exact segment distance tests; no quantized material or new art cache.
	var owner: RefCounted
	var sample_bounds: Rect2
	var land: Rect2
	var seed_value: int
	var areas: Array[Dictionary] = []
	var segments: Array[Dictionary] = []
	var ribbons: Array[Dictionary] = []
	var districts: Array[Dictionary] = []

	func _init(kit: RefCounted, region: Rect2i) -> void:
		owner = kit
		# compose_region visits off-image centers: one half-extent plus one
		# floor/ceil pitch on each side. Two pixels conservatively cover float
		# conversion and cell_at's fixed-point round trip at either boundary.
		var pad_x := float(HexGrid.HALF_WIDTH + HexGrid.COLUMN_PITCH) / SimConfig.FIXED_SCALE + 2.0
		var pad_y := float(HexGrid.HALF_HEIGHT + HexGrid.ROW_PITCH) / SimConfig.FIXED_SCALE + 2.0
		sample_bounds = Rect2(region).grow_individual(pad_x, pad_y, pad_x, pad_y)
		land = Rect2(64, 128, kit.campus.canvas_size.x - 128, kit.campus.canvas_size.y - 224)
		seed_value = int(kit.data.get("terrain", {}).get("seed", 0))
		for area: Dictionary in kit.campus.data.get("activity_areas", []):
			var room := Rect2(SanctumCampusLayout._parse_bounds(area["bounds"]))
			if room.intersects(sample_bounds, true):
				areas.append({"id": String(area["id"]), "room": room})
		for route: Dictionary in kit.paths:
			var points: PackedVector2Array = route["points"]
			var width := float(route["width"])
			var advanced := bool(route["advanced"])
			for index: int in range(points.size() - 1):
				var envelope := Rect2(points[index], Vector2.ZERO).expand(points[index + 1]).grow(maxf(width * 0.5, FLOOR_RIBBON_HALF_WIDTH))
				if not envelope.intersects(sample_bounds, true): continue
				var segment := {"a": points[index], "b": points[index + 1], "half_width": width * 0.5, "advanced": advanced}
				segments.append(segment)
				if not advanced and width >= 160.0: ribbons.append(segment)
		for district: Dictionary in kit.campus.data.get("districts", []):
			var bounds := Rect2(SanctumCampusLayout._parse_bounds(district["bounds"]))
			if bounds.intersects(sample_bounds, true):
				districts.append({"bounds": bounds, "environment": String(district.get("environment", ""))})

	func material_at(point: Vector2) -> String:
		return WellspringIllustratedKit.pixel_family(surface_at(point))

	func surface_at(point: Vector2) -> int:
		var cell := HexTerrain.cell_at(point)
		point = HexTerrain.center_pixels(cell)
		# Safe for incidental out-of-region callers; compositor centers remain
		# inside the prepared envelope, verified independently by the suite.
		if not sample_bounds.has_point(point): return owner.surface_at(point)
		var seed := absi(cell.x * 173 + cell.y * 389 + seed_value)
		if not land.has_point(point): return 8
		var edge := minf(minf(point.x - land.position.x, land.end.x - point.x), minf(point.y - land.position.y, land.end.y - point.y))
		if edge < 28 + (seed % 3) * 8: return 14 if edge > 14 else 8
		if COMMONS_FLOOR.has_point(point): return 0
		for area: Dictionary in areas:
			var room: Rect2 = area.room
			if not room.grow(-16).has_point(point): continue
			match String(area.id):
				"chain-courtyard": return 0
				"open-laboratory": return 1 if room.grow(-48).has_point(point) else 0
				"cover-garden":
					var inset := point - room.position
					if int(inset.x) % 224 < 64 and int(inset.y) % 192 < 64: return 4
					return 0
		for area: Dictionary in areas:
			if String(area.id) in ["pattern-range", "duel-court", "crucible"] and (area.room as Rect2).grow(-16).has_point(point):
				return 2 if String(area.id) == "crucible" else 0
		for segment: Dictionary in segments:
			var distance := point.distance_to(Geometry2D.get_closest_point_to_segment(point, segment.a, segment.b))
			if distance <= float(segment.half_width):
				return 13 if bool(segment.advanced) else (2 if distance > float(segment.half_width) - 18 else 1)
		for district: Dictionary in districts:
			if not (district.bounds as Rect2).has_point(point): continue
			match String(district.environment):
				"coast", "observatory": return 0
				"foundry": return 6
		return 5 if seed % 5 == 0 else 4

	func finish_at(point: Vector2, material: String) -> int:
		point = HexTerrain.center_pixels(HexTerrain.cell_at(point))
		if not sample_bounds.has_point(point): return owner.floor_finish_at(point, material)
		if material not in ["paving", "earth"]: return HexTerrain.Finish.ORIGINAL
		for segment: Dictionary in ribbons:
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point, segment.a, segment.b)) <= FLOOR_RIBBON_HALF_WIDTH:
				return HexTerrain.Finish.ROUTE
		if material != "paving": return HexTerrain.Finish.ORIGINAL
		for area: Dictionary in areas:
			var finish: int = HexTerrain.Finish.ORIGINAL
			match String(area.id):
				"source-court": finish = HexTerrain.Finish.COMMONS
				"crucible": finish = HexTerrain.Finish.CHEMISTRY
				"duel-court": finish = HexTerrain.Finish.DUEL
				"chain-courtyard": finish = HexTerrain.Finish.CHAIN
				_: continue
			var room: Rect2 = area.room
			if finish == HexTerrain.Finish.COMMONS: room = room.intersection(COMMONS_FLOOR)
			if not room.grow(-FLOOR_INSET).has_point(point): continue
			return finish if room.grow(-2.0 * FLOOR_INSET).has_point(point) else HexTerrain.Finish.INSET
		for district: Dictionary in districts:
			if not (district.bounds as Rect2).has_point(point): continue
			if String(district.environment) == "coast": return HexTerrain.Finish.DUEL
			if String(district.environment) == "observatory": return HexTerrain.Finish.COMMONS
		return HexTerrain.Finish.ORIGINAL


func ground_region_sampler(region: Rect2i) -> GroundRegionSampler:
	return GroundRegionSampler.new(self, region)


func configure(layout: SanctumCampusLayout, path: String = PATH, use_prebaked: bool = true) -> bool:
	if terrain_stream != null and not terrain_stream.pending.is_empty():
		last_error = "Drain or finish the current terrain stream before reconfiguration"
		return false
	last_error = ""
	content_hash = ""
	ground = null
	terrain_stream = null
	bake_signature = ""
	ground_overview = null
	ground_chunks.clear()
	ground_chunk_order.clear()
	ground_cache_bytes = 0
	ground_chunk_builds = 0
	ground_chunk_hits = 0
	ground_style = null
	hex_terrain = null
	_clear_roof_skins()
	practice_skins.clear()
	practice_skin_bytes = 0
	tiles.clear()
	water_tiles.clear()
	paths.clear()
	decorations.clear()
	if layout == null or not FileAccess.file_exists(path):
		return _fail("Illustrated campus requires a layout and manifest")
	var source := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(source)
	if not parsed is Dictionary:
		return _fail("Illustrated manifest must be an object")
	data = parsed
	if int(data.get("schema_version", 0)) != 1 or String(data.get("authority", "")) != "presentation_only":
		return _fail("Illustrated manifest cannot own gameplay")
	var camera: Dictionary = data.get("camera", {})
	var terrain: Dictionary = data.get("terrain", {})
	if String(camera.get("ground_axes", "")) != "screen_cardinal" or int(camera.get("art_elevation_degrees", 0)) != 55 or int(camera.get("maximum_facade_pixels", 0)) not in range(16, 65) or int(camera.get("canopy_clearance", 0)) not in range(64, 161):
		return _fail("Camera art must preserve readable cardinal navigation")
	if int(terrain.get("cell_pixels", 0)) != 32 or int(terrain.get("texture_cell_pixels", 0)) != 128 or int(terrain.get("maximum_decorations", 0)) not in range(1, 401):
		return _fail("Illustrated terrain budget is invalid")
	if data.get("prop_order", []) != PROP_IDS:
		return _fail("Illustrated prop order is invalid")
	surfaces = load(String(data.get("surfaces", ""))) as Texture2D
	props = load(String(data.get("props", ""))) as Texture2D
	if surfaces == null or props == null or surfaces.get_size() != Vector2(512, 512) or props.get_size() != Vector2(512, 512):
		return _fail("Illustrated atlases must be two 512px sheets")
	for key: String in ["surfaces", "props"]:
		var texture: Texture2D = surfaces if key == "surfaces" else props
		var pixels := texture.get_image()
		pixels.convert(Image.FORMAT_RGBA8)
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(pixels.get_data())
		if hash.finish().hex_encode() != String(data.get(key + "_rgba_sha256", "")):
			return _fail("Illustrated %s pixels differ from their manifest" % key)
	campus = layout
	var image := surfaces.get_image()
	image.convert(Image.FORMAT_RGBA8)
	for index: int in range(16):
		tiles.append(image.get_region(Rect2i(index % 4 * 128, index / 4 * 128, 128, 128)))
	# Mirror-repeat water without atlas-cell border ink or hard repeat seams.
	for variant: int in range(4):
		var water := tiles[8].get_region(Rect2i(4, 4, 120, 120))
		water.resize(128, 128, Image.INTERPOLATE_BILINEAR)
		if variant % 2 == 1:
			water.flip_x()
		if variant >= 2:
			water.flip_y()
		water_tiles.append(water)
	for value: Variant in (layout.data.get("routes", []) as Array) + (layout.data.get("connections", []) as Array):
		var definition: Dictionary = value
		var points := PackedVector2Array()
		for point: Array in definition["points"]:
			points.append(Vector2(point[0], point[1]))
		paths.append({"points": points, "width": float(definition["width"]), "advanced": String(definition.get("kind", "")) == "advanced"})
	var started := Time.get_ticks_msec()
	pixel_map = MapLibrary.default_library()
	if pixel_map.content_hash.is_empty():
		return _fail(pixel_map.last_error)
	ground_style = GroundStyle.new()
	if not ground_style.configure_style(pixel_map):
		return _fail(ground_style.last_error)
	if not _compile_ground():
		return _fail("Warm terrain composition failed; historical ground is not a fallback")
	for building: Dictionary in campus.buildings_by_id.values():
		var bounds := Rect2(SanctumCampusLayout._parse_bounds(building["bounds"]))
		if String(building.get("style", "")) == "practice_wall":
			var family := WallSkin.family_for(Rect2i(bounds), campus.data.get("activity_areas", []), campus.data.get("districts", []))
			var skin := WallSkin.compose(Rect2i(bounds), family)
			if skin == null or practice_skin_bytes + (skin.get_data().size() if skin != null else 0) > PRACTICE_CACHE_MAX_BYTES:
				ground = null
				practice_skins.clear()
				practice_skin_bytes = 0
				return _fail("Practice masonry requires a bounded worldbone footprint")
			practice_skins[int(building["id"])] = ImageTexture.create_from_image(skin)
			practice_skin_bytes += skin.get_data().size()
		else:
			bounds.size.y -= minf(float(data["camera"]["maximum_facade_pixels"]), bounds.size.y * 0.42)
			var size := Vector2i(bounds.size.ceil())
			if roof_skin_bytes + size.x * size.y * 4 >= ROOF_CACHE_MAX_BYTES:
				ground = null
				return _fail("Slate roofs exceed their setup-only texture budget")
			var skin := compose_roof_skin(size, tiles[10])
			if skin == null:
				ground = null
				return _fail("Slate roofs require bounded footprints and the validated slate tile")
			roof_skins[int(building["id"])] = ImageTexture.create_from_image(skin)
			roof_skin_bytes += skin.get_data().size()
			cached_roof_builds += 1
	# Decorative cutouts are withheld until each one has an authoritative
	# worldbone/clearance contract. A visible tree or fountain must never invite
	# the player to collide with geometry that the simulation does not own.
	ground_generation_ms = Time.get_ticks_msec() - started
	# Decoded pixel hashes also work in exported builds where PNGs are remapped.
	content_hash = (source + layout.content_hash + pixel_map.content_hash + ground_style.content_hash + HexTerrain.VERSION + WallSkin.VERSION + ROOF_SKIN_VERSION).sha256_text()
	bake_signature = CanonicalContent.sha256({"map": CanonicalContent.sha256(layout.data), "art": source.sha256_text(), "base": pixel_map.content_hash, "style": ground_style.content_hash, "composer": HexTerrain.VERSION, "sampler": GROUND_SAMPLER_VERSION, "baker": TerrainStream.VERSION})
	if ground == null and use_prebaked:
		if not ResourceLoader.exists(TerrainStream.MANIFEST): return _fail("Prepared campus terrain is missing; run scripts/bake_wellspring_terrain.gd")
		var manifest := load(TerrainStream.MANIFEST) as Resource
		if manifest == null: return _fail("Prepared campus terrain manifest could not load")
		var stream := AsyncTerrainStream.new()
		if not stream.configure(manifest.get("descriptor"), bake_signature, campus.canvas_size): return _fail(stream.last_error)
		terrain_stream = stream
		ground_chunks = stream.textures
		ground_chunk_order = stream.order
	return true


static func compose_roof_skin(size: Vector2i, slate: Image) -> Image:
	# Copy the admitted tile at 1px scale, once at setup. No new art, filtering,
	# overhang or material authority; partial edge tiles are cropped, not stretched.
	if size.x < 1 or size.y < 1 or size.x > 1024 or size.y > 1024 or size.x * size.y * 4 >= ROOF_CACHE_MAX_BYTES:
		return null
	if slate == null or slate.get_size() != Vector2i(128, 128) or slate.get_format() != Image.FORMAT_RGBA8:
		return null
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y: int in range(0, size.y, 128):
		for x: int in range(0, size.x, 128):
			var portion := Vector2i(mini(128, size.x - x), mini(128, size.y - y))
			image.blit_rect(slate, Rect2i(Vector2i.ZERO, portion), Vector2i(x, y))
	return image


func _clear_roof_skins() -> void:
	roof_skins.clear()
	roof_skin_bytes = 0
	cached_roof_builds = 0


func _compile_ground() -> bool:
	if campus.canvas_size.x > LARGE_WORLD_MAX.x or campus.canvas_size.y > LARGE_WORLD_MAX.y: return false
	if campus.canvas_size.x > HexTerrain.MAX_CANVAS.x or campus.canvas_size.y > HexTerrain.MAX_CANVAS.y:
		hex_terrain = HexTerrain.new()
		# Asset preparation composes native chunks; gameplay loads their exact baked pixels.
		return true
	if pixel_map != null:
		hex_terrain = HexTerrain.new()
		var composed: Image = hex_terrain.compose(campus.canvas_size, func(point: Vector2) -> String: return pixel_family(surface_at(point)), ground_style, floor_finish_at, ground_surface_sources())
		if composed != null:
			ground = ImageTexture.create_from_image(composed)
			cached_terrain_builds += 1
			return true
	return false


func ground_surface_sources() -> Dictionary:
	# Existing validated v3 stone/soil art, at native scale. Every finish remains
	# the same walkable material and owns the same exact chemistry cells.
	return {
		HexTerrain.surface_key("paving", HexTerrain.Finish.ORIGINAL): tiles[0],
		HexTerrain.surface_key("paving", HexTerrain.Finish.COMMONS): tiles[1],
		HexTerrain.surface_key("paving", HexTerrain.Finish.CHEMISTRY): tiles[2],
		HexTerrain.surface_key("paving", HexTerrain.Finish.DUEL): tiles[3],
		HexTerrain.surface_key("paving", HexTerrain.Finish.CHAIN): tiles[0],
		HexTerrain.surface_key("paving", HexTerrain.Finish.INSET): tiles[3],
		HexTerrain.surface_key("paving", HexTerrain.Finish.ROUTE): tiles[3],
		HexTerrain.surface_key("earth", HexTerrain.Finish.ORIGINAL): tiles[6],
		HexTerrain.surface_key("earth", HexTerrain.Finish.ROUTE): tiles[6],
	}


func floor_finish_at(point: Vector2, material: String) -> int:
	# Called only while composing the cached floor. Preserve surface_at's family
	# and the actual lattice: no geometry, obstacle or chemistry material changes.
	point = HexTerrain.center_pixels(HexTerrain.cell_at(point))
	if material not in ["paving", "earth"]:
		return HexTerrain.Finish.ORIGINAL
	# Only broad ordinary circulation gets a ribbon. Narrow wall/chain/cover
	# drills and the sparring zigzag retain their own existing floor language.
	# Crossings take precedence so the flat inset never closes a real entrance.
	for route: Dictionary in paths:
		if bool(route["advanced"]) or float(route["width"]) < 160.0:
			continue
		var points: PackedVector2Array = route["points"]
		for index: int in range(points.size() - 1):
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point, points[index], points[index + 1])) <= FLOOR_RIBBON_HALF_WIDTH:
				return HexTerrain.Finish.ROUTE
	if material != "paving":
		return HexTerrain.Finish.ORIGINAL
	for area: Dictionary in campus.data.get("activity_areas", []):
		var finish: int = HexTerrain.Finish.ORIGINAL
		match String(area["id"]):
			"source-court": finish = HexTerrain.Finish.COMMONS
			"crucible": finish = HexTerrain.Finish.CHEMISTRY
			"duel-court": finish = HexTerrain.Finish.DUEL
			"chain-courtyard": finish = HexTerrain.Finish.CHAIN
			_: continue
		var room := Rect2(SanctumCampusLayout._parse_bounds(area["bounds"]))
		if finish == HexTerrain.Finish.COMMONS:
			room = room.intersection(COMMONS_FLOOR)
		if not room.grow(-FLOOR_INSET).has_point(point):
			continue
		return finish if room.grow(-2.0 * FLOOR_INSET).has_point(point) else HexTerrain.Finish.INSET
	for district: Dictionary in campus.data.get("districts", []):
		if not Rect2(SanctumCampusLayout._parse_bounds(district["bounds"])).has_point(point): continue
		if String(district.get("environment", "")) == "coast": return HexTerrain.Finish.DUEL
		if String(district.get("environment", "")) == "observatory": return HexTerrain.Finish.COMMONS
	return HexTerrain.Finish.ORIGINAL


static func pixel_family(material: int) -> String:
	if material in [4, 5]:
		return "grass"
	if material in [1, 6, 7]:
		return "earth"
	if material in [8, 9]:
		return "water"
	if material in [13, 14]:
		return "worldbone"
	return "paving"


func surface_at(point: Vector2) -> int:
	# One material per canonical chemistry hex. Input routes remain authority;
	# presentation rounds only their visual edge, not their walkable clearance.
	var cell := HexTerrain.cell_at(point)
	point = HexTerrain.center_pixels(cell)
	var seed := absi(cell.x * 173 + cell.y * 389 + int(data["terrain"]["seed"]))
	# Retain the authored64/128px shore margins inside the current map envelope.
	# Resizing the campus must not paint playable annex routes as water. This
	# classification grants no water collision or material-assisted movement.
	var land := Rect2(64, 128, campus.canvas_size.x - 128, campus.canvas_size.y - 224)
	if not land.has_point(point):
		return 8
	var edge := minf(minf(point.x - land.position.x, land.end.x - point.x), minf(point.y - land.position.y, land.end.y - point.y))
	if edge < 28 + (seed % 3) * 8:
		return 14 if edge > 14 else 8
	if COMMONS_FLOOR.has_point(point):
		return 0
	# Reuse the existing autotiles for bounded practice rooms, not decorative
	# objects with fictitious collision. Grass insets keep the cover garden
	# distinct from the open experiment floor and compact chain courtyard.
	for area: Dictionary in campus.data.get("activity_areas", []):
		var room := Rect2(SanctumCampusLayout._parse_bounds(area["bounds"]))
		if not room.grow(-16).has_point(point):
			continue
		match String(area["id"]):
			"chain-courtyard":
				return 0
			"open-laboratory":
				return 1 if room.grow(-48).has_point(point) else 0
			"cover-garden":
				var inset := point - room.position
				if int(inset.x) % 224 < 64 and int(inset.y) % 192 < 64:
					return 4
				return 0
	for area: Dictionary in campus.data.get("activity_areas", []):
		if String(area["id"]) in ["pattern-range", "duel-court", "crucible"] and Rect2(SanctumCampusLayout._parse_bounds(area["bounds"])).grow(-16).has_point(point):
			return 2 if String(area["id"]) == "crucible" else 0
	for route: Dictionary in paths:
		var points: PackedVector2Array = route["points"]
		for index: int in range(points.size() - 1):
			var distance := point.distance_to(Geometry2D.get_closest_point_to_segment(point, points[index], points[index + 1]))
			if distance <= float(route["width"]) * 0.5:
				return 13 if bool(route["advanced"]) else (2 if distance > float(route["width"]) * 0.5 - 18 else 1)
	for district: Dictionary in campus.data.get("districts", []):
		if not Rect2(SanctumCampusLayout._parse_bounds(district["bounds"])).has_point(point): continue
		match String(district.get("environment", "")):
			"coast", "observatory": return 0
			"foundry": return 6
	return 5 if seed % 5 == 0 else 4


func _compile_decorations() -> void:
	var maximum := int(data["terrain"]["maximum_decorations"])
	for y: int in range(190, 1610, 70):
		for x: int in range(105, 2980, 86):
			var seed := absi(x * 113 + y * 257 + int(data["terrain"]["seed"]))
			var point := Vector2(x + seed % 19 - 9, y + seed % 13 - 6)
			if decorations.size() >= maximum:
				return
			if surface_at(point) not in [4, 5, 14] or _near_service_or_building(point):
				continue
			var edge := x < 190 or x > 2870 or y < 240 or y > 1530
			if not edge and seed % 7 > 2:
				continue
			var kind := "oak" if edge and seed % 3 == 0 else ("small_tree" if edge else ("flowers" if seed % 2 == 0 else "ferns"))
			decorations.append({"kind": kind, "point": point, "size": 138.0 if kind == "oak" else (104.0 if kind == "small_tree" else 55.0)})
	decorations.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["point"] as Vector2).y < (b["point"] as Vector2).y)


func _near_service_or_building(point: Vector2) -> bool:
	for building: Dictionary in campus.buildings_by_id.values():
		if Rect2(SanctumCampusLayout._parse_bounds(building["bounds"])).grow(50).has_point(point):
			return true
	for station: Dictionary in campus.stations_by_id.values():
		if point.distance_to(Vector2(station["position"][0], station["position"][1])) < 110:
			return true
	for target: Dictionary in campus.practice_targets_by_id.values():
		if point.distance_to(Vector2(target["position"][0], target["position"][1])) < 110:
			return true
	return false


func ground_ready() -> bool:
	return ground != null or (campus != null and ground_style != null and hex_terrain != null and not content_hash.is_empty())


func ground_chunk_ids(visible: Rect2) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if campus == null or not visible.has_area() or not visible.position.is_finite() or not visible.end.is_finite(): return result
	var clipped := visible.intersection(Rect2(Vector2.ZERO, Vector2(campus.canvas_size)))
	if not clipped.has_area(): return result
	var first := Vector2i(floori(clipped.position.x / GROUND_CHUNK_SIZE), floori(clipped.position.y / GROUND_CHUNK_SIZE))
	var last := Vector2i(ceili(clipped.end.x / GROUND_CHUNK_SIZE), ceili(clipped.end.y / GROUND_CHUNK_SIZE))
	for y: int in range(first.y, last.y):
		for x: int in range(first.x, last.x): result.append(Vector2i(x, y))
	return result


func ground_chunk_rect(id: Vector2i) -> Rect2i:
	return Rect2i(id * GROUND_CHUNK_SIZE, Vector2i.ONE * GROUND_CHUNK_SIZE).intersection(Rect2i(Vector2i.ZERO, campus.canvas_size))


func ground_chunk(id: Vector2i) -> Texture2D:
	# Explicit synchronous tooling API, never called by live drawing.
	if terrain_stream != null:
		var result: Texture2D = terrain_stream.load_immediate(id)
		_sync_terrain_stats()
		return result
	if ground_chunks.has(id):
		ground_chunk_hits += 1
		ground_chunk_order.erase(id)
		ground_chunk_order.append(id)
		return ground_chunks[id]
	var region := ground_chunk_rect(id)
	if not region.has_area(): return null
	var sampler := ground_region_sampler(region)
	var image: Image = hex_terrain.compose_region(region, sampler.material_at, ground_style, sampler.finish_at, ground_surface_sources())
	if image == null:
		last_error = hex_terrain.last_error
		return null
	while ground_chunk_order.size() >= GROUND_CACHE_LIMIT:
		var expired: Vector2i = ground_chunk_order.pop_front()
		var texture: Texture2D = ground_chunks[expired]
		ground_cache_bytes -= int(texture.get_width()) * int(texture.get_height()) * 4
		ground_chunks.erase(expired)
	var texture := ImageTexture.create_from_image(image)
	ground_chunks[id] = texture
	ground_chunk_order.append(id)
	ground_cache_bytes += image.get_data().size()
	ground_chunk_builds += 1
	return texture


func prepare_ground_view(visible: Rect2) -> bool:
	if ground != null: return true
	if not ground_ready(): return false
	var ids := ground_chunk_ids(visible)
	if ids.size() > GROUND_CACHE_LIMIT: return false
	for id: Vector2i in ids:
		if ground_chunk(id) == null: return false
	return true


func request_ground_view(visible: Rect2, upload_budget: int = 2) -> bool:
	if ground != null: return true
	if terrain_stream == null: return false
	terrain_stream.request_view(visible)
	terrain_stream.pump(upload_budget)
	_sync_terrain_stats()
	return terrain_stream.ready_for(visible)


func ground_ready_for(visible: Rect2) -> bool:
	return ground != null or (terrain_stream != null and terrain_stream.ready_for(visible))


func prefetch_ground_view(visible: Rect2) -> void:
	if terrain_stream != null: terrain_stream.prefetch_view(visible)


func clear_ground_prefetch() -> void:
	if terrain_stream != null: terrain_stream.clear_prefetch()


func suspend_ground() -> bool:
	if terrain_stream == null: return true
	var drained: bool = terrain_stream.suspend()
	_sync_terrain_stats()
	return drained


func finish_ground_shutdown() -> void:
	if terrain_stream == null: return
	terrain_stream.finish_shutdown()
	_sync_terrain_stats()


func ground_status() -> Dictionary:
	return terrain_stream.status() if terrain_stream != null else {"ready": 1 if ground != null else 0, "required": 1, "pending": 0, "error": last_error}


func _sync_terrain_stats() -> void:
	ground_cache_bytes = terrain_stream.cache_bytes
	ground_chunk_builds = terrain_stream.uploads
	ground_chunk_hits = terrain_stream.hits


func _prepare_ground_overview() -> bool:
	# Explicit noninteractive overview preparation. No composition, world-size
	# raster or native-cache churn, even when a capture requests an uncropped map.
	if ground_overview != null: return true
	if terrain_stream == null: return false
	var record: Dictionary = terrain_stream.overview_record
	var path: String = record.path
	if not ResourceLoader.exists(path, "Image"): return false
	var image := ResourceLoader.load(path, "Image", ResourceLoader.CACHE_MODE_IGNORE) as Image
	if not TerrainStream.valid_image(image, record): return false
	ground_overview = ImageTexture.create_from_image(image)
	return true


func draw_ground(canvas: CanvasItem, visible_world_rect: Rect2 = Rect2()) -> void:
	canvas.draw_rect(Rect2(-8192, -8192, 24576, 24576), Color("103c45"))
	if ground != null:
		canvas.draw_texture(ground, Vector2.ZERO)
		return
	if not ground_ready(): return
	# Empty means an explicitly prepared overview, never a large-camera fallback.
	if not visible_world_rect.has_area():
		if ground_overview != null: canvas.draw_texture_rect(ground_overview, Rect2(Vector2.ZERO, Vector2(campus.canvas_size)), false)
		return
	# The caller gates startup/travel until ready. Network authority continues
	# independently; missing visual preparation can never block a draw callback.
	for id: Vector2i in ground_chunk_ids(visible_world_rect):
		if ground_chunks.has(id): canvas.draw_texture(ground_chunks[id], Vector2(id * GROUND_CHUNK_SIZE))


func draw_gardens(canvas: CanvasItem, focus: Vector2) -> void:
	for decoration: Dictionary in decorations:
		var point: Vector2 = decoration["point"]
		var alpha := cover_opacity(Rect2(point - Vector2(10, 10), Vector2(20, 20)), focus, float(data["camera"]["canopy_clearance"]))
		draw_prop(canvas, String(decoration["kind"]), point, float(decoration["size"]), Color(1, 1, 1, alpha))


func draw_prop(canvas: CanvasItem, kind: String, feet: Vector2, size: float, modulation: Color = Color.WHITE, tick: int = 0, reduced_effects: bool = false) -> void:
	if pixel_map != null and _draw_pixel_prop(canvas, kind, feet, modulation, tick, reduced_effects):
		return
	var index := PROP_IDS.find(kind)
	if index < 0:
		return
	# A restrained ground contact ties every reusable cutout to the same plane.
	canvas.draw_line(feet - Vector2(size * 0.22, 1), feet + Vector2(size * 0.22, -1), Color(0.04, 0.07, 0.06, 0.20 * modulation.a), maxf(2, size * 0.06), true)
	canvas.draw_texture_rect_region(props, Rect2(feet - Vector2(size * 0.5, size * 124.0 / 128.0), Vector2(size, size)), Rect2(index % 4 * 128, index / 4 * 128, 128, 128), modulation)


func _draw_pixel_prop(canvas: CanvasItem, kind: String, anchor: Vector2, modulation: Color, tick: int, reduced_effects: bool) -> bool:
	# Existing placements only, at the pack's authored1px scale and pivots.
	# No new planters, poles, furniture or implied colliders are introduced.
	var layers: Array[String] = []
	match kind:
		"lectern": layers = ["map.prop.lectern"]
		"bench": layers = ["map.prop.bench"]
		"planter": layers = ["map.prop.planter.planted"]
		"target": layers = ["map.prop.training_dummy"]
		"lantern": layers = ["map.ambient.lantern.flame", "map.prop.lantern.housing"]
		"banner": layers = ["map.prop.banner.pole", "map.ambient.banner.indigo"]
		"fountain": layers = ["map.prop.fountain.basin", "map.ambient.fountain.water", "map.prop.fountain.spout", "map.ambient.fountain.overflow"]
		_: return false
	for id: String in layers:
		pixel_map.draw(canvas, id, anchor, tick, reduced_effects, modulation)
	return true


func draw_surface(canvas: CanvasItem, bounds: Rect2, material: int, tint: Color = Color.WHITE) -> void:
	var origin := Vector2(material % 4 * 128, material / 4 * 128)
	for y: int in range(0, ceili(bounds.size.y), 128):
		for x: int in range(0, ceili(bounds.size.x), 128):
			var size := Vector2(minf(128, bounds.size.x - x), minf(128, bounds.size.y - y))
			canvas.draw_texture_rect_region(surfaces, Rect2(bounds.position + Vector2(x, y), size), Rect2(origin, size), tint)


func draw_building(canvas: CanvasItem, building: Dictionary, _focus: Vector2) -> void:
	var bounds := Rect2(SanctumCampusLayout._parse_bounds(building["bounds"]))
	if String(building.get("style", "")) == "practice_wall":
		var skin: Texture2D = practice_skins.get(int(building["id"]))
		if skin != null:
			canvas.draw_texture(skin, bounds.position)
		return
	var facade_height := minf(float(data["camera"]["maximum_facade_pixels"]), bounds.size.y * 0.42)
	var facade := Rect2(bounds.position.x, bounds.end.y - facade_height, bounds.size.x, facade_height)
	var roof := Rect2(bounds.position, Vector2(bounds.size.x, bounds.size.y - facade_height))
	canvas.draw_rect(Rect2(bounds.position + Vector2(5, 9), bounds.size), Color(0.06, 0.09, 0.07, 0.5))
	draw_surface(canvas, facade, 11)
	for x: int in range(int(bounds.position.x) + 8, int(bounds.end.x), 48):
		canvas.draw_rect(Rect2(x, facade.position.y, 5, facade.size.y), Color("493024"))
		if absf(x - bounds.get_center().x) > 50:
			canvas.draw_rect(Rect2(x + 15, facade.position.y + 12, 15, 21), Color("3d382d"))
			canvas.draw_rect(Rect2(x + 17, facade.position.y + 14, 11, 16), Color("b69754"))
	# Buildings are validated worldbone and actors render above the map layer.
	# Keep the structure opaque and stable instead of fading on approach.
	var roof_skin: Texture2D = roof_skins.get(int(building["id"]))
	if roof_skin != null:
		# Preserve even fractional facade splits exactly without rescaling pixels.
		canvas.draw_texture_rect_region(roof_skin, roof, Rect2(Vector2.ZERO, roof.size))
	canvas.draw_rect(roof, Color(0.20, 0.15, 0.11, 1.0), false, 5)
	canvas.draw_line(roof.position + Vector2(0, roof.size.y * 0.32), roof.position + Vector2(roof.size.x, roof.size.y * 0.32), Color("aa8650"), 4)
	canvas.draw_line(Vector2(bounds.position.x, facade.position.y), Vector2(bounds.end.x, facade.position.y), Color("4b3025"), 6)
	draw_prop(canvas, "doorway", Vector2(bounds.get_center().x, bounds.end.y + 4), minf(110, bounds.size.y * 0.8))
	for side: float in [-1.0, 1.0]:
		draw_prop(canvas, "planter", Vector2(bounds.get_center().x + side * 82, bounds.end.y + 10), 45)
	canvas.draw_rect(bounds, Color(0.82, 0.71, 0.48, 0.3), false, 1)


static func cover_opacity(bounds: Rect2, focus: Vector2, clearance: float = 56.0) -> float:
	var nearest := focus.clamp(bounds.position, bounds.end)
	return lerpf(0.30, 1.0, clampf(focus.distance_to(nearest) / maxf(1.0, clearance), 0.0, 1.0))


func draw_landmark(canvas: CanvasItem, landmark: Dictionary, focus: Vector2 = Vector2(-1000000, -1000000), tick: int = 0, reduced_effects: bool = false) -> void:
	var point := Vector2(landmark["position"][0], landmark["position"][1])
	var kind := String(landmark["kind"])
	var phase := ambient_phase(tick, 180, reduced_effects)
	if kind == "grand_fountain":
		for radius: int in [92, 104]:
			canvas.draw_arc(point, radius, 0, TAU, 64, Color("a28a59"), 3)
		# Two quiet water rings move at different phases. They are decoration,
		# never a spell telegraph, collision surface or simulation timer.
		for offset: float in [0.0, 0.5]:
			var ripple := fmod(phase + offset, 1.0)
			canvas.draw_arc(point + Vector2(0, 24), 58.0 + ripple * 25.0, 0, TAU, 48, Color(0.31, 0.79, 0.85, (1.0 - ripple) * 0.18), 2.0)
		var alpha := landmark_opacity(point, focus)
		draw_prop(canvas, "fountain", point + Vector2(0, 38), 154, Color(1, 1, 1, alpha), tick, reduced_effects)
	else:
		if kind == "portal_ring":
			canvas.draw_circle(point + Vector2(0, 8), 27.0 + phase * 3.0, Color(0.38, 0.65, 0.86, 0.07 + phase * 0.05))
			canvas.draw_arc(point + Vector2(0, 8), 31.0, -2.7 + phase * 0.35, 0.45 + phase * 0.35, 28, Color(0.72, 0.62, 0.91, 0.42), 2.0)
		else:
			canvas.draw_circle(point + Vector2(0, 2), 13.0 + phase * 2.0, Color(0.95, 0.72, 0.31, 0.08 + phase * 0.05))
		draw_prop(canvas, "banner" if kind == "portal_ring" else "lantern", point + Vector2(0, 14), 74, Color.WHITE, tick, reduced_effects)


static func landmark_opacity(point: Vector2, focus: Vector2) -> float:
	# Cosmetic landmark may overlap a legal route: reduce its visual density
	# around the player, never invent a collision obstacle to match the art.
	return cover_opacity(Rect2(point - Vector2(48, 84), Vector2(96, 122)), focus, 56)


static func ambient_phase(tick: int, period_ticks: int = 180, reduced_effects: bool = false) -> float:
	if reduced_effects:
		return 0.0
	var period := maxi(2, period_ticks)
	var normalized := float(posmod(tick, period)) / float(period)
	return 0.5 - 0.5 * cos(normalized * TAU)


static func station_label_opacity(point: Vector2, focus: Vector2) -> float:
	if focus.x < -100000.0 or focus.y < -100000.0:
		return 1.0
	var distance := point.distance_to(focus)
	return 1.0 - smoothstep(280.0, 520.0, distance)


func draw_station(canvas: CanvasItem, station: Dictionary, _tick: int = 0, _reduced_effects: bool = false, focus: Vector2 = Vector2(-1000000, -1000000), draw_title: bool = true) -> void:
	var point := Vector2(station["position"][0], station["position"][1])
	WellspringServiceBuildings.draw_service(canvas, station, point.distance_squared_to(focus) < 96.0 * 96.0, draw_title, station_label_opacity(point, focus))


func _fail(message: String) -> bool:
	last_error = message
	_clear_roof_skins()
	return false
