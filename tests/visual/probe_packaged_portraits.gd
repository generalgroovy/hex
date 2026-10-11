extends SceneTree
## External, read-only admission probe. Run from an isolated payload directory:
## godot --headless --path <payload> --main-pack <absolute hex.pck>
##   --script <absolute path to this file> --
##   --pack-path=<same absolute hex.pck> --expected-build-id=p57-30b90507f932
## The engine process working directory must also be <payload>.
## No test dependency, source PNG hashing, bootstrap, rendering, or user-data writes.

const MARKER := "PACKAGED_PORTRAITS "
const EXPECTED_IDS := [
	"oh_tipi", "s_wayne", "red_baron", "grace_reava", "wa_bidi", "steezo",
	"treevor_mason", "oll_i", "fluup", "nico_lai", "spai_si", "leaf_hidden",
	"ha_rekt", "dr_apex", "haara", "hesus_christo", "grimm_bow", "biggy_bob",
	"jan_wicked", "ba_djoh", "urzh", "donnok", "djonah_thaan", "luuh_i_zeh",
	"juul_i_yaina", "faab_i_yaina", "joh_haynes", "h_le_ne", "fimu_yashiha", "sai_laas",
]
const SCRIPT_PATHS := {
	"identity": "res://src/content/runtime_build_identity.gd",
	"abilities": "res://src/content/ability_catalog.gd",
	"champions": "res://src/content/champion_catalog.gd",
	"roster": "res://src/content/champion_roster_plan.gd",
	"portraits": "res://src/presentation/champion_portrait_library.gd",
	"gallery": "res://src/presentation/character_selection_grid.gd",
}

var report: Dictionary = {"status": "failed", "probe": "packaged-portraits-v2"}
var scripts: Dictionary = {}
var failure := ""
var max_cached := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _check_isolation() or not _load_runtime_scripts() or not _check_portraits():
		report["error"] = failure
		push_error("Packaged portrait probe: " + failure)
		print(MARKER + JSON.stringify(report))
		quit(1)
		return

	report["status"] = "passed"
	report["resource_source"] = "mounted_pck_remaps_isolated_physical_cwd"
	report["max_cached"] = max_cached
	report["gallery_close_released"] = true
	report["rendered"] = false
	report["scope"] = "Imported resource admission and Gallery cache lifecycle only; no visual, input, gameplay, installer, or human acceptance."
	print(MARKER + JSON.stringify(report))
	quit(0)


func _check_isolation() -> bool:
	# Exported packs may have no physical res:// root, even in an editor binary.
	# A filesystem DirAccess for "." observes the process's actual fallback root.
	var physical_directory := DirAccess.open(".")
	var working_directory := "" if physical_directory == null else physical_directory.get_current_dir()
	var globalized_root := ProjectSettings.globalize_path("res://")
	var probe_path: String = get_script().resource_path
	report["path_diagnostics"] = {
		"globalized_res_root": globalized_root,
		"physical_working_directory": working_directory,
		"external_probe_path": probe_path,
		"engine_executable": OS.get_executable_path(),
	}
	var options := {}
	for argument: String in OS.get_cmdline_user_args():
		var parts := argument.split("=", true, 1)
		if parts.size() != 2 or parts[0] not in ["--pack-path", "--expected-build-id"] \
				or options.has(parts[0]) or parts[1].is_empty():
			return _fail("Use exactly --pack-path=<absolute PCK> and --expected-build-id=<ID> after --.")
		options[parts[0]] = parts[1]
	if options.size() != 2:
		return _fail("Both --pack-path and --expected-build-id are required.")
	var pack_path: String = options["--pack-path"]
	if not pack_path.is_absolute_path() or pack_path.get_extension().to_lower() != "pck" \
			or not FileAccess.file_exists(pack_path):
		return _fail("The caller-supplied absolute PCK file does not exist.")
	# Engine-processed --main-pack is not reliably exposed by OS.get_cmdline_args.
	# The caller records the real invocation and independently hashes the PCK.
	report["pack_path_caller_supplied"] = pack_path
	report["expected_build_id"] = options["--expected-build-id"]
	var resource_root := pack_path.get_base_dir()
	if not working_directory.is_absolute_path() or working_directory.begins_with("res://") \
			or _normal(working_directory) != _normal(resource_root):
		return _fail("Start the engine with its physical WorkingDirectory set to the supplied PCK's parent.")
	if not probe_path.is_absolute_path() or probe_path.begins_with("res://"):
		return _fail("The probe itself must be an external absolute filesystem script.")
	# This probe lives at <checkout>/tests/visual/<file>; never load res:// there.
	var checkout := probe_path.get_base_dir().get_base_dir().get_base_dir()
	if _within(resource_root, checkout) or _within(resource_root, probe_path.get_base_dir()):
		return _fail("The resource root must be outside the probe's source checkout.")
	# When Godot does expose a physical resource root, it must agree too. An
	# empty/abstract root in a mounted export resolves loose files against cwd;
	# the enforced physical cwd and checks below close that source fallback.
	if globalized_root.is_absolute_path() and not globalized_root.begins_with("res://"):
		if _normal(globalized_root) != _normal(resource_root):
			return _fail("Godot's physical resource root differs from the isolated PCK parent.")
	elif globalized_root not in ["", "res://", "res:/", ".", "./"]:
		return _fail("Godot reported an unsupported relative resource root.")
	for directory: String in ["src", "content", "assets", "art_batches", ".godot", "tests"]:
		if DirAccess.dir_exists_absolute(resource_root.path_join(directory)):
			return _fail("Loose runtime directory permits source fallback: " + directory)
	for filename: String in ["project.godot", "project.binary", "override.cfg"]:
		if FileAccess.file_exists(resource_root.path_join(filename)):
			return _fail("Loose project configuration is not allowed: " + filename)
	if not FileAccess.file_exists("res://project.binary"):
		return _fail("Packed project.binary is missing; --main-pack was not mounted.")
	report["resource_root"] = resource_root
	report["loose_runtime_absent"] = true
	return true


func _load_runtime_scripts() -> bool:
	var remaps := {}
	for key: String in SCRIPT_PATHS:
		var path: String = SCRIPT_PATHS[key]
		var remap := ConfigFile.new()
		if remap.load(path + ".remap") != OK:
			return _fail("Exported script remap missing: " + path)
		var target := String(remap.get_value("remap", "path", ""))
		if not target.begins_with("res://") or target.get_extension() != "gdc" \
				or ".." in target or not FileAccess.file_exists(target):
			return _fail("Compiled packed script target missing: " + path)
		var script := ResourceLoader.load(path, "Script") as Script
		if script == null or not script.can_instantiate():
			return _fail("Packed runtime script cannot instantiate: " + path)
		scripts[key] = script
		remaps[key] = target
	report["compiled_script_remaps"] = remaps
	var identity: Dictionary = scripts.identity.load_current(57, 23)
	if not bool(identity.get("ok", false)):
		return _fail("Runtime identity validation failed: " + String(identity.get("error", "")))
	if identity.get("build_id", "") != report.expected_build_id:
		return _fail("Packed runtime build ID differs from the expected candidate.")
	report["build_id"] = identity.build_id
	report["runtime_source_sha256"] = identity.runtime_source_sha256
	return true


func _check_portraits() -> bool:
	var abilities: Variant = scripts.abilities.new()
	if not abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"):
		return _fail("Packed ability catalog: " + String(abilities.last_error))
	var champions: Variant = scripts.champions.new()
	if not champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities):
		return _fail("Packed champion catalog: " + String(champions.last_error))
	var live_ids: Array = champions.ordered_champion_ids()
	if live_ids != EXPECTED_IDS:
		return _fail("Packed catalog differs from the exact 30 expected live IDs/wire order.")
	var roster: Variant = scripts.roster.new()
	if not roster.load_from_files():
		return _fail("Packed roster registry: " + String(roster.last_error))
	var gallery: Variant = scripts.gallery.new()
	if not gallery.configure(champions, roster):
		return _fail("Packed Gallery configuration: " + String(gallery.last_error))
	var library: Variant = gallery.portrait_library
	if library.get_script() != scripts.portraits:
		return _fail("Gallery does not use the packed portrait library script.")
	var admitted: Array = library.entries.keys()
	admitted.sort()
	var expected: Array = EXPECTED_IDS.duplicate()
	expected.sort()
	if admitted != expected or not library.cached_ids().is_empty():
		return _fail("Exactly 30 portraits must be admitted without eager texture loading.")
	gallery.open_panel("s_wayne")
	if not gallery.is_open or not library.cached_ids().is_empty():
		return _fail("Opening Gallery failed or eagerly retained a portrait.")
	var references: Array[WeakRef] = []
	var expected_cache: Array[String] = []
	for id: String in live_ids:
		var reference := _inspect_portrait(gallery, id)
		if reference == null:
			return false
		references.append(reference)
		expected_cache.append(id)
		if expected_cache.size() > 2:
			expected_cache.pop_front()
		var cached: Array = library.cached_ids()
		max_cached = maxi(max_cached, cached.size())
		if cached != expected_cache:
			return _fail("Sequential portrait requests violate the two-entry LRU: " + id)
		if references.size() > 2 and references[references.size() - 3].get_ref() != null:
			return _fail("An evicted portrait remains retained: " + id)
	# Touch an older entry, then load a third: this distinguishes LRU from FIFO.
	if _inspect_portrait(gallery, "fimu_yashiha") == null \
			or _inspect_portrait(gallery, "s_wayne") == null:
		return false
	if library.cached_ids() != ["fimu_yashiha", "s_wayne"]:
		return _fail("Touching a cached portrait did not update LRU eviction order.")
	var selected := _inspect_portrait(gallery, "s_wayne")
	if selected == null:
		return false
	gallery.close_panel()
	if gallery.is_open or gallery.portrait_expanded or not library.cached_ids().is_empty() \
			or selected.get_ref() != null:
		return _fail("Production Gallery close did not release its selected portrait.")
	for reference: WeakRef in references:
		if reference.get_ref() != null:
			return _fail("Production Gallery close left an imported portrait retained.")
	report["live_ids"] = live_ids
	report["admitted"] = admitted.size()
	report["imported_textures_checked"] = references.size()
	report["texture_dimensions"] = [512, 512]
	report["texture_type"] = "CompressedTexture2D"
	report["lru_touch_verified"] = true
	return true


func _inspect_portrait(gallery: Variant, id: String) -> WeakRef:
	var frame: Dictionary = gallery.hero_portrait_source(id)
	var texture: Variant = frame.get("texture")
	if not texture is CompressedTexture2D or texture.get_size() != Vector2(512, 512) \
			or frame.get("champion_id", "") != id or not bool(frame.get("detailed_portrait", false)) \
			or frame.get("region") != Rect2(0, 0, 512, 512):
		_fail("Imported 512px identity/region check failed: " + id)
		return null
	var entry: Dictionary = gallery.portrait_library.entries[id]
	if entry.get("width") != 512 or entry.get("height") != 512:
		_fail("Packed manifest dimensions differ from 512px: " + id)
		return null
	return weakref(texture)


func _normal(path: String) -> String:
	var result := path.replace("\\", "/").simplify_path().trim_suffix("/")
	return result.to_lower() if OS.get_name() == "Windows" else result


func _within(path: String, directory: String) -> bool:
	return _normal(path) == _normal(directory) or _normal(path).begins_with(_normal(directory) + "/")


func _fail(message: String) -> bool:
	failure = message
	return false
