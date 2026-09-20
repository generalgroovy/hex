extends SceneTree


const MANIFEST_PATH: String = "res://content/assets/sanctum_modular_kit_candidate_v2.json"
const OUTPUT_DIRECTORY: String = "res://assets/concept/sanctum_modular_kit_candidate_v2"
const ALPHA_PADDING: int = 4


func _initialize() -> void:
	var exit_code := _prepare()
	quit(exit_code)


func _prepare() -> int:
	var manifest := EnvironmentKitManifest.new()
	if not manifest.load_from_file(MANIFEST_PATH):
		push_error(manifest.last_error)
		return 1
	var alpha_contract: Dictionary = (manifest.data.get("files", {}) as Dictionary).get("alpha_candidate", {})
	var source_path := String(alpha_contract.get("path", ""))
	var source := Image.new()
	if source.load_png_from_buffer(FileAccess.get_file_as_bytes(source_path)) != OK:
		push_error("Cannot decode G2 alpha candidate")
		return 1
	var absolute_output := ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	if DirAccess.make_dir_recursive_absolute(absolute_output) != OK:
		push_error("Cannot create G2 candidate crop directory")
		return 1
	var image_contract: Dictionary = manifest.data.get("image", {})
	var columns := int(image_contract.get("columns", 0))
	var rows := int(image_contract.get("rows", 0))
	var outputs: Array[Dictionary] = []
	for value: Variant in manifest.data.get("modules", []):
		var module: Dictionary = value
		var column := int(module.get("column", -1))
		var row := int(module.get("row", -1))
		var x0 := column * source.get_width() / columns
		var x1 := (column + 1) * source.get_width() / columns
		var y0 := row * source.get_height() / rows
		var y1 := (row + 1) * source.get_height() / rows
		var cell := source.get_region(Rect2i(x0, y0, x1 - x0, y1 - y0))
		var used := cell.get_used_rect()
		if used.size == Vector2i.ZERO:
			push_error("G2 candidate module cell is empty: %s" % String(module.get("id", "")))
			return 1
		used = used.grow(ALPHA_PADDING).intersection(Rect2i(Vector2i.ZERO, cell.get_size()))
		var output := cell.get_region(used)
		var output_path := "%s/%s.png" % [OUTPUT_DIRECTORY, String(module.get("id", ""))]
		if output.save_png(output_path) != OK:
			push_error("Cannot save G2 candidate module: %s" % output_path)
			return 1
		outputs.append({
			"id": String(module.get("id", "")),
			"path": output_path,
			"width": output.get_width(),
			"height": output.get_height(),
			"pivot": [output.get_width() / 2, output.get_height() - ALPHA_PADDING],
			"sha256": FileAccess.get_sha256(output_path),
		})
	print(JSON.stringify(outputs, "  ", false))
	return 0
