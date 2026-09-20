@tool
extends EditorExportPlugin

const Sources = preload("res://addons/pixel_assets_export/atlas_source_contract.gd")


func _get_name() -> String:
	return "FLUXPixelAtlasBytes"


func _supports_platform(_platform: EditorExportPlatform) -> bool:
	return true


func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	# Validate the complete set before adding anything: never produce a silently
	# partial material library, and never alter the original source files.
	var result := Sources.collect_sources()
	if not String(result.error).is_empty():
		var platform := get_export_platform()
		if platform != null:
			platform.add_message(EditorExportPlatform.EXPORT_MESSAGE_ERROR, "FLUX pixel atlases", String(result.error))
		push_error(String(result.error))
		return
	for entry: Dictionary in result.files:
		# Raw custom data coexists with the normal .import/.ctex export route.
		# Do not skip the imported resource or remap its virtual path.
		add_file(String(entry.path), entry.bytes, false)
	print("FLUX pixel atlas export: %d verified original PNGs, %d bytes" % [result.files.size(), result.total_bytes])
