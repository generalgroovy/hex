class_name ChampionPortraitLibrary
extends RefCounted
## Optional Gallery illustrations. This library never owns actor/HUD artwork.
## Only requested, catalog-admitted identities load; two uncached resources at
## most are retained here. Asset hashes are verified by the build, not per draw.

const ROOT := "res://assets/portraits/champions_v1/"
const MANIFEST_PATH := ROOT + "manifest.json"
const MANIFEST_ID := "hex-champion-portraits-v1"
const MAX_ENTRIES := 64
const CACHE_LIMIT := 2
const MIN_EDGE := 256
const MAX_EDGE := 512

var entries: Dictionary = {}
var last_error := ""
var _textures: Dictionary = {}
var _recent: Array[String] = []
var _unavailable: Dictionary = {}


func configure(catalog_ids: Array, path: String = MANIFEST_PATH) -> bool:
	clear()
	if not FileAccess.file_exists(path):
		last_error = "Detailed portraits are not installed."
		return false
	return admit_manifest(JSON.parse_string(FileAccess.get_file_as_string(path)), catalog_ids)


func admit_manifest(value: Variant, catalog_ids: Array) -> bool:
	clear()
	last_error = manifest_error(value, catalog_ids)
	if not last_error.is_empty():
		return false
	for entry: Dictionary in value.characters:
		entries[String(entry.id)] = entry.duplicate(true)
	return true


static func manifest_error(value: Variant, catalog_ids: Array) -> String:
	if not value is Dictionary or value.get("id") != MANIFEST_ID:
		return "Detailed portrait registry identity is invalid."
	var version: Variant = value.get("schema_version")
	if not (version is int or version is float) or version != 1:
		return "Detailed portrait registry identity is invalid."
	if not value.get("characters") is Array or value.characters.is_empty() or value.characters.size() > MAX_ENTRIES:
		return "Detailed portrait registry exceeds its bounded roster."
	var seen := {}
	for entry: Variant in value.characters:
		if not entry is Dictionary or not entry.get("id") is String:
			return "Detailed portrait identity is invalid."
		var id: String = entry.id
		if id.is_empty() or id not in catalog_ids or seen.has(id) or not _safe_id(id):
			return "Detailed portrait identity is unknown or duplicated."
		seen[id] = true
		if not entry.get("file") is String or entry.file != id + ".png":
			return "Detailed portrait file must be its canonical identity PNG."
		for axis: String in ["width", "height"]:
			var edge: Variant = entry.get(axis)
			if not (edge is int or edge is float) or not is_finite(float(edge)) \
					or float(edge) != floorf(float(edge)) or edge < MIN_EDGE or edge > MAX_EDGE:
				return "Detailed portrait dimensions exceed the imported texture budget."
		if entry.width != entry.height:
			return "Detailed portrait must be square."
		var digest: Variant = entry.get("sha256")
		if not digest is String or digest.length() != 64 or not digest.is_valid_hex_number(false):
			return "Detailed portrait build digest is invalid."
	return ""


static func _safe_id(id: String) -> bool:
	for character: String in id:
		if character not in "abcdefghijklmnopqrstuvwxyz0123456789_":
			return false
	return true


func portrait_frame(champion_id: String) -> Dictionary:
	if not entries.has(champion_id) or _unavailable.has(champion_id):
		return {}
	if not _textures.has(champion_id):
		var entry: Dictionary = entries[champion_id]
		var texture := _load_texture(ROOT + String(entry.file))
		if texture == null or texture.get_size() != Vector2(float(entry.width), float(entry.height)):
			# Failed requests are bounded by the admitted roster and never retried
			# every frame. Reconfiguration is the explicit asset-refresh boundary.
			_unavailable[champion_id] = true
			last_error = "Detailed portrait unavailable: " + champion_id
			return {}
		while _recent.size() >= CACHE_LIMIT:
			_textures.erase(_recent.pop_front())
		_textures[champion_id] = texture
	_recent.erase(champion_id)
	_recent.append(champion_id)
	var selected: Texture2D = _textures[champion_id]
	return {"texture": selected, "region": Rect2(Vector2.ZERO, selected.get_size()),
		"champion_id": champion_id, "detailed_portrait": true}


func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	# Bypass the global resource cache so browsing the roster does not retain
	# thirty large portraits after this library evicts its own references.
	return ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D


func cached_ids() -> Array[String]:
	return _recent.duplicate()


func release_textures() -> void:
	_textures.clear()
	_recent.clear()
	# Keep negative results until a new registry is admitted, not each reopen.


func clear() -> void:
	release_textures()
	_unavailable.clear()
	entries.clear()
	last_error = ""
