extends SceneTree

# Standalone exported-pack audit. No project classes or checkout resources are
# referenced by this script. Use verify-terrain-pack.ps1 to freeze expectations
# and launch editor Godot with an exact minimal isolated project. The pack is
# mounted explicitly only after the filesystem and launch boundary is checked.
const TERRAIN := "res://assets/environment/wellspring_ground_v1"
const IDENTITY := "res://content/runtime/runtime_build_identity_v1.json"
const ISOLATED_PROJECT := "config_version=5\n\n[application]\nconfig/name=\"H.E.X. isolated terrain audit\"\n"
const SOURCES := [
	"res://scripts/bake_wellspring_terrain.gd",
	"res://src/presentation/wellspring_terrain_stream.gd",
	"res://src/presentation/wellspring_illustrated_kit.gd",
	"res://src/presentation/hex_environment_layout.gd",
	"res://src/presentation/pixel_map_library.gd",
	"res://art_batches/wellspring_style_v2/ground_style.gd",
	"res://src/sim/hex/hex_grid.gd",
	"res://src/sim/core/sim_config.gd",
]
var error := ""
var checks := 0
var _progress_file_owned := false
var report: Dictionary = {"schema_version": 1, "status": "failed", "scope": "Exported terrain resource integrity and expected release identity; not gameplay, native rendering, or performance acceptance."}


func _init() -> void:
	_progress("script.init")


func _initialize() -> void:
	_progress("initialize")
	call_deferred("_run")


func _run() -> void:
	_progress("run")
	var output := _option("--verification-output")
	if output.is_empty() or not output.is_absolute_path() or FileAccess.file_exists(output) or FileAccess.file_exists(output + ".partial"):
		printerr("TERRAIN_PACK_VERIFY_FAILED: fresh absolute output path required")
		quit(1)
		return
	var started := Time.get_ticks_msec()
	_progress("verify.before")
	var ok := _verify()
	_progress("verify.after")
	report["status"] = "passed" if ok else "failed"
	report["checks"] = checks
	report["error"] = error
	report["elapsed_ms"] = Time.get_ticks_msec() - started
	var file := FileAccess.open(output + ".partial", FileAccess.WRITE)
	if file == null:
		printerr("TERRAIN_PACK_VERIFY_FAILED: cannot write report")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or FileAccess.file_exists(output) or DirAccess.rename_absolute(output + ".partial", output) != OK:
		printerr("TERRAIN_PACK_VERIFY_FAILED: cannot publish fresh report")
		quit(1)
		return
	if ok: print("TERRAIN_PACK_VERIFY_PASSED " + output)
	else: printerr("TERRAIN_PACK_VERIFY_FAILED: " + error)
	quit(0 if ok else 1)


func _verify() -> bool:
	_progress("isolation.before")
	var isolated := _option("--isolated-root")
	var pack := _option("--expected-pack")
	var expected_pack_hash := _option("--expected-pack-sha256")
	# Record observations before any admission check so a rejected pack launch
	# can be diagnosed without changing the isolation requirement.
	var observed_root := ProjectSettings.globalize_path("res://")
	var current_directory := DirAccess.open(".")
	report["launch_diagnostics"] = {
		"observed_resource_root": observed_root,
		"normalized_resource_root": observed_root.replace("\\", "/").simplify_path().trim_suffix("/").to_lower(),
		"expected_isolated_root": isolated,
		"normalized_isolated_root": isolated.replace("\\", "/").simplify_path().trim_suffix("/").to_lower(),
		"expected_pack": pack,
		"executable": OS.get_executable_path(),
		"current_directory": current_directory.get_current_dir() if current_directory != null else "",
		"current_directory_open_error": DirAccess.get_open_error(),
		"command_line_arguments": OS.get_cmdline_args(),
		"user_arguments": OS.get_cmdline_user_args(),
		"verification_script_path": get_script().resource_path,
		"engine": Engine.get_version_info(),
	}
	if not _check(isolated.is_absolute_path() and pack.is_absolute_path(), "absolute isolated root and pack required"): return false
	if not _check(_same_path(ProjectSettings.globalize_path("res://"), isolated), "resource root must be the isolated directory, never the checkout"): return false
	if not _check(current_directory != null and _same_path(current_directory.get_current_dir(), isolated), "working directory must be the isolated directory"): return false
	var script_path := ProjectSettings.globalize_path(get_script().resource_path)
	if not _check(script_path.is_absolute_path() and _same_path(script_path.get_base_dir(), isolated), "audit script must be inside the isolated directory"): return false
	if not _check(_same_path(pack.get_base_dir(), isolated), "pinned pack must be the staged isolated copy"): return false
	var project_path := isolated.path_join("project.godot")
	if not _check(FileAccess.get_file_as_bytes(project_path) == ISOLATED_PROJECT.to_utf8_buffer(), "isolated project bytes differ from the known minimal project"): return false
	if not _check(String(ProjectSettings.get_setting("application/run/main_scene", "")).is_empty(), "isolated project must not configure a main scene"): return false
	for property: Dictionary in ProjectSettings.get_property_list():
		if not _check(not String(property.name).begins_with("autoload/"), "isolated project must not configure autoloads"): return false
	for forbidden: String in ["assets", "src", "content", "override.cfg"]:
		var path := isolated.path_join(forbidden)
		if not _check(not FileAccess.file_exists(path) and not DirAccess.dir_exists_absolute(path), "isolated directory contains a possible checkout fallback: " + forbidden): return false
	_progress("pack_hash.before")
	if not _check(_valid_hash(expected_pack_hash) and FileAccess.get_sha256(pack) == expected_pack_hash, "pack hash differs from the pinned export"): return false
	_progress("pack_hash.after")
	var targets: Array[String] = [IDENTITY, TERRAIN + "/manifest.tres", TERRAIN + "/overview.res", "res://src/presentation/wellspring_terrain_manifest.gd"]
	for index: int in range(132): targets.append(TERRAIN + "/chunk_%02d_%02d.res" % [index % 12, index / 12])
	for target: String in targets:
		if not _check(not FileAccess.file_exists(target), "target resource was already available before explicit mount: " + target): return false
	_progress("mount.before")
	var mounted := ProjectSettings.load_resource_pack(pack, false)
	_progress("mount.after")
	report["mount"] = {"method": "ProjectSettings.load_resource_pack", "replace_files": false, "path": pack, "success": mounted, "target_resources_absent_before_mount": targets.size(), "minimal_project_sha256": FileAccess.get_sha256(project_path)}
	if not _check(mounted, "explicit pinned resource-pack mount failed"): return false
	if not _check(_same_path(ProjectSettings.globalize_path("res://"), isolated), "explicit mount changed the isolated resource root"): return false
	report["pack_sha256"] = expected_pack_hash
	report["isolated_resource_root"] = ProjectSettings.globalize_path("res://")
	report["verification_script_sha256"] = FileAccess.get_sha256(get_script().resource_path)
	var expectation_hashes := {}
	for input: String in ["--expected-identity", "--expected-manifest", "--expected-provenance"]:
		var input_path := _option(input)
		if not _check(input_path.is_absolute_path() and _same_path(input_path.get_base_dir(), isolated) and FileAccess.file_exists(input_path), "expectations must be frozen files in the isolated directory: " + input): return false
		expectation_hashes[input.trim_prefix("--")] = FileAccess.get_sha256(input_path)
	report["expectation_sha256"] = expectation_hashes
	var expected_identity := _json_file(_option("--expected-identity"))
	if not error.is_empty(): return false
	var actual_identity := _json_file(IDENTITY)
	if not error.is_empty(): return false
	if not _check(actual_identity == expected_identity, "packed release identity differs from the frozen expected identity"): return false
	var digest := String(actual_identity.get("runtime_source_sha256", ""))
	if not _check(_valid_hash(digest) and int(actual_identity.get("schema_version", 0)) == 1 and int(actual_identity.get("protocol_version", 0)) > 0 and int(actual_identity.get("snapshot_schema", 0)) > 0 and int(actual_identity.get("record_count", 0)) > 0, "invalid release identity schema"): return false
	if not _check(String(actual_identity.get("build_id", "")) == "p%d-%s" % [int(actual_identity.protocol_version), digest.left(12)], "release build ID is inconsistent with its digest"): return false
	report["release_identity"] = actual_identity
	var provenance := _json_file(_option("--expected-provenance"))
	if not error.is_empty(): return false
	if not _check(provenance.size() == SOURCES.size(), "expected provenance must contain exactly all eight producers"): return false
	for source_path: String in SOURCES:
		if not _check(_valid_hash(String(provenance.get(source_path, ""))), "missing or invalid producer hash: " + source_path): return false
	var expected_manifest := _manifest(_option("--expected-manifest"))
	if not error.is_empty(): return false
	var manifest := _manifest(TERRAIN + "/manifest.tres")
	if not error.is_empty(): return false
	if not _check(manifest == expected_manifest, "packed terrain descriptor differs from the frozen source descriptor"): return false
	if not _check(manifest.get("source_sha256", {}) == provenance, "bake provenance differs from independently hashed producer sources"): return false
	if not _check(manifest.get("version", "") == "wellspring-exact-regions-1" and _valid_hash(String(manifest.get("signature", ""))), "invalid bake version or signature"): return false
	if not _check(manifest.get("canvas", []) == [6144, 5376] and manifest.get("chunk_size", 0) == 512, "unexpected campus or chunk bounds"): return false
	var rows: Variant = manifest.get("chunks", null)
	if not _check(rows is Array and rows.size() == 132, "all132 ordered chunks are required"): return false
	var verified: Array[Dictionary] = []
	for index: int in range(132):
		if index % 32 == 0: _progress("images.before.%d" % index)
		if not _check(rows[index] is Dictionary, "invalid chunk record"): return false
		var row: Dictionary = rows[index]
		var x := index % 12
		var y := index / 12
		var height := 256 if y == 10 else 512
		var path := TERRAIN + "/chunk_%02d_%02d.res" % [x, y]
		if not _check(row.size() == 4 and row.get("id", []) == [x, y] and row.get("size", []) == [512, height] and row.get("path", "") == path, "chunk order, extent or path changed: " + path): return false
		if not _image(row, Vector2i(512, height)): return false
		verified.append(row.duplicate(true))
	_progress("images.complete.132")
	var overview: Variant = manifest.get("overview", null)
	if not _check(overview is Dictionary and overview.size() == 3 and overview.get("path", "") == TERRAIN + "/overview.res" and overview.get("size", []) == [1536, 1344], "invalid bounded overview record"): return false
	if not _image(overview, Vector2i(1536, 1344)): return false
	_progress("overview.complete")
	if not _check(FileAccess.get_sha256(pack) == expected_pack_hash, "pack changed during verification"): return false
	report["signature"] = manifest.signature
	report["source_sha256"] = provenance
	report["verified_chunks"] = verified
	report["verified_overview"] = overview
	report["decoded_image_count"] = 133
	report["decoded_rgba_bytes"] = (6144 * 5376 + 1536 * 1344) * 4
	return true


func _manifest(path: String) -> Dictionary:
	_progress("manifest.exists.before " + path)
	if not _check(not path.is_empty() and ResourceLoader.exists(path), "missing terrain manifest: " + path): return {}
	_progress("manifest.load.before " + path)
	var resource: Resource = ResourceLoader.load(path, "Resource", ResourceLoader.CACHE_MODE_IGNORE)
	_progress("manifest.load.after " + path)
	if not _check(resource != null, "unreadable terrain manifest: " + path): return {}
	var descriptor: Variant = resource.get("descriptor")
	if not _check(descriptor is Dictionary, "terrain manifest has no descriptor"): return {}
	return descriptor


func _image(row: Dictionary, size: Vector2i) -> bool:
	var path := String(row.get("path", ""))
	var expected_hash := String(row.get("rgba_sha256", ""))
	if not _check(_valid_hash(expected_hash) and ResourceLoader.exists(path, "Image"), "missing image or invalid pixel hash: " + path): return false
	var resource: Resource = ResourceLoader.load(path, "Image", ResourceLoader.CACHE_MODE_IGNORE)
	if not _check(resource is Image, "resource is not a decoded Image: " + path): return false
	var image := resource as Image
	if not _check(image.get_size() == size and image.get_format() == Image.FORMAT_RGBA8 and not image.has_mipmaps(), "decoded image dimensions/format/mipmaps changed: " + path): return false
	var bytes := image.get_data()
	if not _check(bytes.size() == size.x * size.y * 4, "unexpected decoded pixel length: " + path): return false
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return _check(hash.finish().hex_encode() == expected_hash, "decoded RGBA pixels differ: " + path)


func _json_file(path: String) -> Dictionary:
	if not _check(not path.is_empty() and FileAccess.file_exists(path), "missing JSON input: " + path): return {}
	var json := JSON.new()
	if not _check(json.parse(FileAccess.get_file_as_string(path)) == OK and json.data is Dictionary, "invalid JSON object: " + path): return {}
	return json.data


func _check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition: error = message
	return condition


func _option(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix + "="): return argument.substr(prefix.length() + 1)
	return ""


func _same_path(first: String, second: String) -> bool:
	return not first.is_empty() and first.replace("\\", "/").simplify_path().trim_suffix("/").to_lower() == second.replace("\\", "/").simplify_path().trim_suffix("/").to_lower()


func _valid_hash(value: String) -> bool:
	if value.length() != 64: return false
	for index: int in value.length():
		if value.substr(index, 1) not in "0123456789abcdef": return false
	return true


func _progress(stage: String) -> void:
	# Only the explicit standalone audit emits these bounded progress witnesses.
	# They make a stalled API call visible without extending the watchdog.
	var output := _option("--verification-output")
	if not output.is_absolute_path(): return
	var line := "TERRAIN_PACK_VERIFY_PROGRESS %d checks=%d %s" % [Time.get_ticks_msec(), checks, stage]
	print(line)
	# A fresh, separate append-only witness survives stdout buffering or a kill.
	# Never overwrite an earlier diagnostic file supplied under the same name.
	var progress_path := output + ".progress"
	if not _progress_file_owned and FileAccess.file_exists(progress_path): return
	var progress_file := FileAccess.open(progress_path, FileAccess.READ_WRITE if _progress_file_owned else FileAccess.WRITE)
	if progress_file == null: return
	_progress_file_owned = true
	progress_file.seek_end()
	progress_file.store_line(line)
	progress_file.flush()
	progress_file.close()
