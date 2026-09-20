class_name PixelMapLibrary
extends RefCounted

# Supplied map candidates, decoded without resampling or palette changes.
# Every footprint is descriptive: this class cannot access game collision.
const ROOT := "res://art_batches/pixel_v1/map"
const MANIFEST := ROOT + "/manifest.json"
const GROUPS := ["terrain", "architecture", "props", "ambient"]
const FAMILIES := ["paving", "earth", "grass", "worldbone", "water"]
const CELL := 32
const DECODED_BYTES := 6_144_000
static var _shared: PixelMapLibrary
var last_error := ""
var content_hash := ""
var palette_status := ""
var data: Dictionary = {}
var textures: Dictionary = {}
var _images: Dictionary = {}
var _assets: Dictionary = {}
var _tiles: Dictionary = {}


static func default_library() -> PixelMapLibrary:
	if _shared == null:
		_shared = PixelMapLibrary.new()
		_shared.load_from_file()
	return _shared


func load_from_file(path: String = MANIFEST) -> bool:
	last_error = ""
	content_hash = ""
	data.clear()
	textures.clear()
	_images.clear()
	_assets.clear()
	_tiles.clear()
	if not FileAccess.file_exists(path):
		return _fail("Map pack manifest is missing")
	var source := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(source)
	if not parsed is Dictionary or not validate_manifest(parsed):
		return false
	data = parsed
	var root := path.get_base_dir()
	for atlas: Dictionary in data.atlases:
		var bytes := FileAccess.get_file_as_bytes(root.path_join(String(atlas.path)))
		var pixels := Image.new()
		if pixels.load_png_from_buffer(bytes) != OK or pixels.get_format() != Image.FORMAT_RGBA8 or pixels.has_mipmaps():
			return _fail("Map atlas is not a lossless unmipped RGBA PNG: " + String(atlas.path))
		if pixels.get_size() != Vector2i(int(atlas.size_px[0]), int(atlas.size_px[1])):
			return _fail("Map atlas dimensions differ from the manifest")
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(pixels.get_data())
		if hash.finish().hex_encode() != String(atlas.rgba_sha256):
			return _fail("Map atlas pixels differ from the manifest: " + String(atlas.path))
		# Raw bytes are explicitly included in the export. Direct lossless decode
		# avoids Godot import alpha-border recolouring of this immutable pack.
		_images[String(atlas.path)] = pixels
		textures[String(atlas.path)] = ImageTexture.create_from_image(pixels)
	for asset: Dictionary in data.assets:
		var prepared: Array[Dictionary] = []
		var end_tick := 0
		for frame: Dictionary in asset.atlas_frames:
			end_tick += int(frame.duration_ticks)
			var rect: Array = frame.rect
			var prepared_frame := {"texture": textures[String(frame.path)], "region": Rect2(rect[0], rect[1], rect[2], rect[3]), "pivot": Vector2(asset.pivot_px[0], asset.pivot_px[1]), "end_tick": end_tick}
			prepared_frame.make_read_only()
			prepared.append(prepared_frame)
		_assets[String(asset.id)] = {"frames": prepared, "loop": bool(asset.loop), "duration": end_tick, "footprint": asset.visual_ground_footprint.rect_px}
	palette_status = String(data.palette.status)
	content_hash = source.sha256_text()
	return true


func validate_manifest(document: Dictionary) -> bool:
	last_error = ""
	if int(document.get("schema_version", 0)) != 1 or String(document.get("contract_id", "")) != "flux-pixel-assets-v1" or String(document.get("namespace", "")) != "map":
		return _fail("Map pack has the wrong schema or namespace")
	var authority: Dictionary = document.get("usage_authority", {})
	if not bool(authority.get("presentation_only", false)) or bool(authority.get("collision_authority", true)) or bool(authority.get("navigation_authority", true)) or bool(authority.get("sample_is_production_layout", true)):
		return _fail("Map art cannot own layout, collision or navigation")
	var cell: Array = document.get("ground_cell_px", [])
	if int(document.get("tick_rate_hz", 0)) != 120 or cell.size() != 2 or int(cell[0]) != 32 or int(cell[1]) != 32:
		return _fail("Map cell and animation clock differ from the runtime contract")
	var atlases: Array = document.get("atlases", [])
	var assets: Array = document.get("assets", [])
	if atlases.size() != 4 or assets.size() != 250:
		return _fail("Map pack must contain four atlases and250 assets")
	var page_sizes := {}
	var decoded_bytes := 0
	for atlas: Dictionary in atlases:
		var group := String(atlas.get("group", ""))
		var path := String(atlas.get("path", ""))
		var size: Array = atlas.get("size_px", [])
		if group not in GROUPS or path != "export/%s/atlas.png" % group or page_sizes.has(path) or size.size() != 2 or int(size[0]) != 1024 or int(size[1]) <= 0 or int(size[1]) > 1024:
			return _fail("Map atlas metadata is unsafe or out of budget")
		page_sizes[path] = Vector2i(int(size[0]), int(size[1]))
		decoded_bytes += int(size[0]) * int(size[1]) * 4
	if decoded_bytes != DECODED_BYTES:
		return _fail("Map texture budget changed")
	var ids := {}
	var frame_count := 0
	for asset: Dictionary in assets:
		var id := String(asset.get("id", ""))
		var size: Array = asset.get("frame_size_px", [])
		var pivot: Array = asset.get("pivot_px", [])
		var footprint: Dictionary = asset.get("visual_ground_footprint", {})
		var frames: Array = asset.get("atlas_frames", [])
		if not id.begins_with("map.") or ids.has(id) or size.size() != 2 or pivot.size() != 2 or frames.is_empty() or frames.size() > 4:
			return _fail("Map asset identity, size or frame count is invalid")
		if not bool(footprint.get("descriptive_only", false)) or bool(footprint.get("collision_authority", true)):
			return _fail("Map footprint cannot become gameplay geometry")
		if int(size[0]) <= 0 or int(size[1]) <= 0 or int(size[0]) % 32 != 0 or int(size[1]) % 32 != 0 or int(pivot[0]) < 0 or int(pivot[1]) < 0 or int(pivot[0]) > int(size[0]) or int(pivot[1]) > int(size[1]):
			return _fail("Map asset does not preserve its authored grid and pivot")
		ids[id] = true
		for frame: Dictionary in frames:
			var rect: Array = frame.get("rect", [])
			var path := String(frame.get("path", ""))
			if not page_sizes.has(path) or rect.size() != 4 or int(frame.get("duration_ticks", 0)) <= 0 or int(frame.duration_ticks) > 1200:
				return _fail("Map frame has unsafe atlas or timing metadata")
			var bounds := Rect2i(int(rect[0]), int(rect[1]), int(rect[2]), int(rect[3]))
			if bounds.size != Vector2i(int(size[0]), int(size[1])) or not Rect2i(Vector2i.ZERO, page_sizes[path]).encloses(bounds):
				return _fail("Map frame rectangle leaves its atlas")
			frame_count += 1
	if frame_count != 274:
		return _fail("Map pack frame coverage changed")
	for family: String in FAMILIES:
		for variant: int in range(1, 4):
			if not ids.has("map.terrain.%s.fill_v%d" % [family, variant]):
				return _fail("Map terrain interior coverage is incomplete")
		for mask: int in range(16):
			if not ids.has("map.terrain.%s.mask_%02d" % [family, mask]):
				return _fail("Map terrain cardinal coverage is incomplete")
		for corner: String in ["nw", "ne", "se", "sw"]:
			for kind: String in ["concave", "convex"]:
				if not ids.has("map.terrain.%s.corner_%s_%s" % [family, kind, corner]):
					return _fail("Map terrain corner coverage is incomplete")
	return true


func sample(id: String, tick: int = 0, reduced_effects: bool = false) -> Dictionary:
	if not _assets.has(id):
		return {}
	var asset: Dictionary = _assets[id]
	var age := 0 if reduced_effects or not bool(asset.loop) else posmod(tick, int(asset.duration))
	for frame: Dictionary in asset.frames:
		if age < int(frame.end_tick):
			return frame
	return {}


func draw(canvas: CanvasItem, id: String, anchor: Vector2, tick: int = 0, reduced_effects: bool = false, modulation: Color = Color.WHITE) -> bool:
	var frame := sample(id, tick, reduced_effects)
	if canvas == null or frame.is_empty():
		return false
	canvas.draw_texture_rect_region(frame.texture, Rect2((anchor - frame.pivot).round(), frame.region.size), frame.region, modulation)
	return true


static func terrain_layers(family: String, cardinal_mask: int, diagonal_mask: int, variant: int = 0) -> Array[String]:
	if family not in FAMILIES or cardinal_mask < 0 or cardinal_mask > 15 or diagonal_mask < 0 or diagonal_mask > 15:
		return []
	var layers: Array[String] = ["map.terrain.%s.mask_%02d" % [family, cardinal_mask]]
	if cardinal_mask == 15 and variant > 0:
		layers[0] = "map.terrain.%s.fill_v%d" % [family, clampi(variant, 1, 3)]
	var corners := ["nw", "ne", "se", "sw"]
	var adjacent := [9, 3, 6, 12]
	for index: int in range(4):
		if (cardinal_mask & int(adjacent[index])) == int(adjacent[index]) and (diagonal_mask & (1 << index)) == 0:
			layers.append("map.terrain.%s.corner_concave_%s" % [family, corners[index]])
		elif (cardinal_mask & int(adjacent[index])) == 0:
			layers.append("map.terrain.%s.corner_convex_%s" % [family, corners[index]])
	return layers


func tile_image(id: String) -> Image:
	if _tiles.has(id):
		return _tiles[id]
	var frame := sample(id)
	if frame.is_empty():
		return null
	var asset: Dictionary = data.assets.filter(func(value: Dictionary) -> bool: return String(value.id) == id)[0]
	var source: Image = _images[String(asset.atlas_frames[0].path)]
	var pixels := source.get_region(Rect2i(frame.region))
	_tiles[id] = pixels
	return pixels


func compose_ground(families: Array[String], columns: int, rows: int) -> Image:
	if columns <= 0 or rows <= 0 or families.size() != columns * rows or columns > 128 or rows > 128:
		return null
	var image := Image.create(columns * CELL, rows * CELL, false, Image.FORMAT_RGBA8)
	var cardinal := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var diagonals := [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]
	for y: int in range(rows):
		for x: int in range(columns):
			var family := families[y * columns + x]
			var masks: Array[int] = [0, 0]
			for group: int in range(2):
				var offsets: Array = cardinal if group == 0 else diagonals
				for index: int in range(4):
					var neighbor := Vector2i(x, y) + (offsets[index] as Vector2i)
					if neighbor.x >= 0 and neighbor.x < columns and neighbor.y >= 0 and neighbor.y < rows and families[neighbor.y * columns + neighbor.x] == family:
						masks[group] |= 1 << index
			var layers := terrain_layers(family, masks[0], masks[1], posmod(x * 17 + y * 31, 4))
			for index: int in range(layers.size()):
				var tile := tile_image(layers[index])
				if tile == null:
					return null
				if index == 0:
					image.blit_rect(tile, Rect2i(0, 0, CELL, CELL), Vector2i(x, y) * CELL)
				else:
					image.blend_rect(tile, Rect2i(0, 0, CELL, CELL), Vector2i(x, y) * CELL)
	return image


func _fail(message: String) -> bool:
	last_error = message
	return false
