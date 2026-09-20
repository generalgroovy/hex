extends SceneTree


const CONTRACT_PATH := "res://content/assets/wellspring_environment_source_v2.json"
const OUTPUT_DIRECTORY := "res://assets/environment/wellspring_v2/runtime_kit_v2"


func _initialize() -> void:
	quit(_prepare())


func _prepare() -> int:
	var contract_file := FileAccess.open(CONTRACT_PATH, FileAccess.READ)
	if contract_file == null:
		push_error("Cannot open Wellspring environment source contract")
		return 1
	var parsed: Variant = JSON.parse_string(contract_file.get_as_text())
	if not parsed is Dictionary:
		push_error("Wellspring environment source contract must be an object")
		return 1
	var contract: Dictionary = parsed
	var source_contract: Dictionary = contract.get("source", {})
	var source_path := String(source_contract.get("path", ""))
	if FileAccess.get_sha256(source_path) != String(source_contract.get("sha256", "")):
		push_error("Wellspring environment source hash changed")
		return 1
	var source := Image.new()
	if source.load_png_from_buffer(FileAccess.get_file_as_bytes(source_path)) != OK:
		push_error("Cannot decode Wellspring environment source")
		return 1
	if source.get_size() != Vector2i(int(source_contract.get("width", 0)), int(source_contract.get("height", 0))):
		push_error("Wellspring environment source dimensions changed")
		return 1
	if source.get_format() != Image.FORMAT_RGBA8:
		source.convert(Image.FORMAT_RGBA8)
	if not _has_transparency(source):
		push_error("Wellspring environment source has no genuine alpha")
		return 1
	var absolute_output := ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	if DirAccess.make_dir_recursive_absolute(absolute_output) != OK:
		push_error("Cannot create Wellspring environment runtime directory")
		return 1
	var columns := int(source_contract.get("columns", 0))
	var rows := int(source_contract.get("rows", 0))
	var extraction: Dictionary = contract.get("extraction", {})
	var padding := int(extraction.get("alpha_padding", 0))
	var outputs: Array[Dictionary] = []
	for value: Variant in contract.get("modules", []):
		var module: Dictionary = value
		var column := int(module.get("column", -1))
		var row := int(module.get("row", -1))
		var cell := source.get_region(Rect2i(
			column * source.get_width() / columns,
			row * source.get_height() / rows,
			source.get_width() / columns,
			source.get_height() / rows,
		))
		var used := cell.get_used_rect()
		if used.size == Vector2i.ZERO:
			push_error("Wellspring environment source cell is empty: %s" % String(module.get("id", "")))
			return 1
		used = used.grow(padding).intersection(Rect2i(Vector2i.ZERO, cell.get_size()))
		var output := cell.get_region(used)
		var maximum: Array = module.get("maximum_size", [])
		var scale := minf(float(maximum[0]) / float(output.get_width()), float(maximum[1]) / float(output.get_height()))
		var output_size := Vector2i(maxi(1, roundi(output.get_width() * scale)), maxi(1, roundi(output.get_height() * scale)))
		output.resize(output_size.x, output_size.y, Image.INTERPOLATE_NEAREST)
		var output_path := "%s/%s.png" % [OUTPUT_DIRECTORY, String(module.get("id", ""))]
		if output.save_png(ProjectSettings.globalize_path(output_path)) != OK:
			push_error("Cannot save Wellspring environment module: %s" % output_path)
			return 1
		outputs.append({
			"id": String(module.get("id", "")),
			"role": String(module.get("role", "")),
			"path": output_path,
			"width": output_size.x,
			"height": output_size.y,
			"pivot": [output_size.x / 2, output_size.y - maxi(2, roundi(float(padding) * scale))],
			"sha256": FileAccess.get_sha256(output_path),
		})
	print(JSON.stringify(outputs, "  ", false))
	return 0


static func _has_transparency(image: Image) -> bool:
	for y: int in range(0, image.get_height(), 8):
		for x: int in range(0, image.get_width(), 8):
			if image.get_pixel(x, y).a < 0.05:
				return true
	return false
