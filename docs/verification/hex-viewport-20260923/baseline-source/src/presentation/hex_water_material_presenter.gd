extends RefCounted

# Inner material pixels only. The caller retains its complete canonical fill
# and semantic outline; no texture rectangle supplies a gameplay footprint.
const MANIFEST_PATH := "res://assets/sprites/hex_water_pilot_v1/manifest.json"
const DIMENSIONS := Vector2(512, 240)
const CELL := Vector2(64, 80)
const DISPLAY_CELL := Vector2(48, 60)
const ROWS: Array[String] = ["forming", "active", "decaying"]
const EXPECTED := {
	"normal": ["e1fcfe9050503b01186ecc465e064eb11a30986666e41615f97e5e0061ecce76", "1f3936d408c33ad1893fe9fdb231581b6f7ca46377d07631a1d06f341e970ee0"],
	"reduced": ["0cbd1a1a207a282d6c8224e338313d458331c0cd11e60ee6fc78a57b3f0d0a8b", "0c78d0c0206a3b971e209d6e423284bdadc5172b61df40ec1877fceb63616eae"],
}

var textures: Dictionary = {}
var last_error := ""
var manifest_hash := ""
var loaded_resources: Array[Dictionary] = []


func configure() -> bool:
	textures.clear()
	loaded_resources.clear()
	last_error = ""
	manifest_hash = ""
	var source := FileAccess.get_file_as_string(MANIFEST_PATH)
	var data: Variant = JSON.parse_string(source)
	if not data is Dictionary or int(data.get("schema_version", -1)) != 1 or data.get("rows") != ROWS:
		return _fail("Water pilot manifest is missing or incompatible")
	for mode: String in ["normal", "reduced"]:
		var entry: Dictionary = data.get("textures", {}).get(mode, {})
		var path := "res://assets/sprites/hex_water_pilot_v1/water-%s.png" % mode
		if entry.get("path") != path or entry.get("sha256") != EXPECTED[mode][0] or entry.get("rgba_sha256") != EXPECTED[mode][1] or not ResourceLoader.exists(path):
			return _fail("Water pilot texture metadata is invalid: " + mode)
		if OS.has_feature("editor") and FileAccess.file_exists(path) and FileAccess.get_sha256(path) != EXPECTED[mode][0]:
			return _fail("Water pilot source pixels changed: " + mode)
		var texture := load(path) as Texture2D
		if texture == null or texture.get_size() != DIMENSIONS:
			return _fail("Water pilot dimensions changed: " + mode)
		var pixels := texture.get_image()
		if pixels == null or pixels.is_empty() or pixels.has_mipmaps():
			return _fail("Water pilot requires decoded nearest pixels without mipmaps")
		pixels.convert(Image.FORMAT_RGBA8)
		var digest := HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		digest.update(pixels.get_data())
		var rgba_hash := digest.finish().hex_encode()
		if rgba_hash != EXPECTED[mode][1]:
			return _fail("Water pilot imported pixels changed: " + mode)
		textures[mode] = texture
		loaded_resources.append({"mode": mode, "path": texture.resource_path, "rgba_sha256": rgba_hash, "width": pixels.get_width(), "height": pixels.get_height()})
	manifest_hash = source.sha256_text()
	return true


func ready() -> bool:
	return textures.size() == 2 and not manifest_hash.is_empty()


# Phase is supplied by authority. The column is cosmetic motion only and never
# starts, prolongs or recreates a region. Reduced mode retains the same row.
static func frame_cell(phase: String, tick: float, seed: int, reduced: bool) -> Vector2i:
	var row := ROWS.find(phase)
	if row < 0 or not is_finite(tick):
		return Vector2i(-1, -1)
	return Vector2i(0 if reduced else posmod(floori(tick / 8.0) + posmod(seed, 8), 8), row)


static func sampling(polygon: PackedVector2Array, phase: String, tick: float, seed: int, reduced: bool) -> Dictionary:
	var frame := frame_cell(phase, tick, seed, reduced)
	if frame.x < 0 or polygon.size() != 6:
		return {}
	var center := Vector2.ZERO
	for point: Vector2 in polygon:
		if not point.is_finite(): return {}
		center += point
	center /= 6.0
	var uv := PackedVector2Array()
	for point: Vector2 in polygon:
		var local := (point - center + DISPLAY_CELL * 0.5) / DISPLAY_CELL
		# Fail back to the old material marks rather than sample another atlas
		# cell when a future geometry change exceeds this explicit 48px adapter.
		if local.x < -0.0001 or local.x > 1.0001 or local.y < -0.0001 or local.y > 1.0001:
			return {}
		local = local.clamp(Vector2.ZERO, Vector2.ONE)
		uv.append((Vector2(frame) * CELL + local * CELL) / DIMENSIONS)
	return {"uv": uv, "frame": frame, "phase": phase, "polygon": polygon}


func draw_region(canvas: CanvasItem, polygon: PackedVector2Array, phase: String, tick: float, seed: int, reduced: bool) -> bool:
	if canvas == null or not ready(): return false
	var sample := sampling(polygon, phase, tick, seed, reduced)
	if sample.is_empty(): return false
	# HexCourtPresenter.draw_ground establishes nearest filtering for its
	# presentation canvas. Do not mutate shared item settings per material.
	canvas.draw_polygon(polygon, PackedColorArray([Color.WHITE]), sample.uv, textures["reduced" if reduced else "normal"])
	return true


func evidence() -> Dictionary:
	return {"ready": ready(), "manifest": MANIFEST_PATH, "manifest_sha256": manifest_hash, "textures": loaded_resources.duplicate(true), "last_error": last_error, "display_scale": 0.75, "clip": "authoritative whole-cell polygon"}


func _fail(message: String) -> bool:
	textures.clear()
	loaded_resources.clear()
	last_error = message
	return false
