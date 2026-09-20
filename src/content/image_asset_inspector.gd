class_name ImageAssetInspector
extends RefCounted


# Runtime/export-safe image inspection. Imported textures are authoritative in
# a packaged build; source bytes remain a deterministic editor fallback for
# validation tools before import metadata exists.
static func load_image(path: String) -> Image:
	if path.is_empty() or (not path.begins_with("res://") and not path.begins_with("user://")):
		return null
	if ResourceLoader.exists(path, "Texture2D"):
		var resource := ResourceLoader.load(path, "Texture2D")
		if resource is Texture2D:
			var imported := (resource as Texture2D).get_image()
			if imported != null and not imported.is_empty():
				return imported
	if not FileAccess.file_exists(path):
		return null
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var image := Image.new()
	var error := ERR_FILE_UNRECOGNIZED
	match path.get_extension().to_lower():
		"png":
			error = image.load_png_from_buffer(bytes)
		"jpg", "jpeg":
			error = image.load_jpg_from_buffer(bytes)
		"webp":
			error = image.load_webp_from_buffer(bytes)
	return image if error == OK and not image.is_empty() else null
