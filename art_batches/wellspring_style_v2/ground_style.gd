extends "res://src/presentation/pixel_map_library.gd"


# Terrain-only adapter: inherit the proven cardinal/corner composition exactly.
# All135 cells are prepared once; no sampling, recolouring or images per draw.
const STYLE_MANIFEST := "res://art_batches/wellspring_style_v2/runtime/manifest.json"
const STYLE_ATLAS := "res://art_batches/wellspring_style_v2/runtime/terrain.png"
const STYLE_SIZE := Vector2i(1024, 180)
var style_data: Dictionary = {}


func configure_style(base: PixelMapLibrary, path: String = STYLE_MANIFEST) -> bool:
	content_hash = ""
	last_error = ""
	_tiles.clear()
	style_data.clear()
	if base == null or base.content_hash.is_empty() or not FileAccess.file_exists(path):
		return _fail("Warm campus terrain requires its validated base and style manifest")
	var source := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(source)
	if not parsed is Dictionary or int(parsed.get("schema_version", 0)) != 1 or String(parsed.get("authority", "")) != "presentation_only" or String(parsed.get("base_manifest_sha256", "")) != base.content_hash:
		return _fail("Warm terrain cannot replace layout authority or an unreviewed base pack")
	var dimensions: Array = parsed.get("size", [])
	if dimensions.size() != 2 or int(dimensions[0]) != STYLE_SIZE.x or int(dimensions[1]) != STYLE_SIZE.y or String(parsed.get("atlas", "")) != STYLE_ATLAS or not FileAccess.file_exists(STYLE_ATLAS):
		return _fail("Warm terrain atlas metadata is missing or outside its bounded page")
	var bytes := FileAccess.get_file_as_bytes(STYLE_ATLAS)
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(bytes)
	if bytes.size() != int(parsed.get("png_bytes", 0)) or digest.finish().hex_encode() != String(parsed.get("png_sha256", "")):
		return _fail("Warm terrain PNG differs from its reviewed style manifest")
	var atlas := Image.new()
	if atlas.load_png_from_buffer(bytes) != OK or atlas.get_size() != STYLE_SIZE or atlas.get_format() != Image.FORMAT_RGBA8 or atlas.has_mipmaps():
		return _fail("Warm terrain must be an unscaled lossless RGBA page")
	digest.start(HashingContext.HASH_SHA256)
	digest.update(atlas.get_data())
	if digest.finish().hex_encode() != String(parsed.get("rgba_sha256", "")):
		return _fail("Warm terrain decoded pixels differ from their style manifest")
	var entries: Array = parsed.get("tiles", [])
	if entries.size() != 135:
		return _fail("Warm terrain must retain all135 original terrain cells")
	var prepared := {}
	for entry: Dictionary in entries:
		var id := String(entry.get("id", ""))
		var values: Array = entry.get("rect", [])
		var original := base.sample(id)
		if not id.begins_with("map.terrain.") or prepared.has(id) or values.size() != 4 or original.is_empty():
			return _fail("Warm terrain cell registration differs from its original")
		var rect := Rect2i(int(values[0]), int(values[1]), int(values[2]), int(values[3]))
		if rect != Rect2i(original.region) or rect.size != Vector2i(CELL, CELL) or not Rect2i(Vector2i.ZERO, STYLE_SIZE).encloses(rect):
			return _fail("Warm terrain cannot move or resize original terrain cells")
		prepared[id] = atlas.get_region(rect)
	_tiles = prepared
	style_data = parsed
	content_hash = source.sha256_text()
	return true


func tile_image(id: String) -> Image:
	return _tiles.get(id)
