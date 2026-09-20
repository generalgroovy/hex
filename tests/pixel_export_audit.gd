extends SceneTree

# Run from outside an exported PCK with --main-pack and --script. No project
# classes are needed: this verifies what the player actually receives.
const REQUIRED := [
	"res://art_batches/pixel_v1/magic/manifest.json",
	"res://art_batches/pixel_v1/magic/export/magic_00.png",
	"res://art_batches/pixel_v1/magic/export/magic_01.png",
	"res://art_batches/pixel_v1/magic/export/magic_02.png",
	"res://art_batches/pixel_v1/map/manifest.json",
	"res://art_batches/pixel_v1/map/export/terrain/atlas.png",
	"res://art_batches/pixel_v1/map/export/architecture/atlas.png",
	"res://art_batches/pixel_v1/map/export/props/atlas.png",
	"res://art_batches/pixel_v1/map/export/ambient/atlas.png",
]

func _init() -> void:
	var failures := 0
	for path: String in REQUIRED:
		if not FileAccess.file_exists(path):
			push_error("Pixel export missing: " + path)
			failures += 1
	for folder: String in ["res://reference/art", "res://art_batches/pixel_v1/magic/source", "res://art_batches/pixel_v1/magic/previews", "res://art_batches/pixel_v1/map/source", "res://art_batches/pixel_v1/map/previews"]:
		if DirAccess.dir_exists_absolute(folder):
			push_error("Authoring-only directory leaked into export: " + folder)
			failures += 1
	if failures == 0:
		var magic: RefCounted = load("res://src/presentation/pixel_magic_library.gd").new()
		if not magic.load_from_file() or magic.asset_count() != 474 or magic.page_count() != 3:
			push_error("Exported magic integrity failed: " + str(magic.last_error))
			failures += 1
		var map: RefCounted = load("res://src/presentation/pixel_map_library.gd").new()
		if not map.load_from_file() or map.data.assets.size() != 250 or map.textures.size() != 4:
			push_error("Exported map integrity failed: " + str(map.last_error))
			failures += 1
		if failures == 0:
			print("FLUX exported loaders: 474 magic sequences / 3 pages; 250 map assets / 4 pages; exact integrity passed")
	print("FLUX pixel export audit: %d required files, %d failures" % [REQUIRED.size(), failures])
	quit(0 if failures == 0 else 1)
