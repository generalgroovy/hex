@tool
extends EditorPlugin

const AtlasExporter = preload("res://addons/pixel_assets_export/export_plugin.gd")

var _exporter: EditorExportPlugin


func _enter_tree() -> void:
	_exporter = AtlasExporter.new()
	add_export_plugin(_exporter)


func _exit_tree() -> void:
	if _exporter != null:
		remove_export_plugin(_exporter)
		_exporter = null
