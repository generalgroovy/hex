class_name WellspringVisualCatalog
extends RefCounted


const SUPPORTED_SCHEMA_VERSION: int = 2
const DEFAULT_PATH: String = "res://content/visual/wellspring_visual_catalog_v2.json"
const CHARACTER_ATLAS_SIZE := Vector2i(1920, 2560)
const REQUIRED_RACE_COUNT: int = 21
const REQUIRED_CHAMPION_COUNT: int = 24
const REQUIRED_DISTRICT_COUNT: int = 9
const REQUIRED_SIZES := [
	"size_1_tiny",
	"size_2_small",
	"size_3_medium",
	"size_4_large",
	"size_5_huge",
]
const CANONICAL_BODY_TYPES: Array[String] = ["small", "middle", "large"]
const REQUIRED_PRESENTATIONS := ["masculine", "feminine"]
const ChampionRosterPlanScript = preload("res://src/content/champion_roster_plan.gd")

var data: Dictionary = {}
var last_error: String = ""
var races: Dictionary = {}
var champions: Dictionary = {}
var districts: Dictionary = {}
var materials: Dictionary = {}
var props: Dictionary = {}
var element_vfx: Dictionary = {}
var ui: Dictionary = {}
var wellspring: Dictionary = {}
var roster_plan = ChampionRosterPlanScript.new()


func load_from_file(path: String = DEFAULT_PATH) -> bool:
	last_error = ""
	if not FileAccess.file_exists(path):
		return _fail("Wellspring visual catalog does not exist: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("could not open Wellspring visual catalog: %s" % path)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return _fail("Wellspring visual catalog root must be an object")
	data = parsed
	return validate()


func validate() -> bool:
	last_error = ""
	if roster_plan.ordered_ids.is_empty() and not roster_plan.load_from_files():
		return _fail("canonical champion roster cannot be loaded: %s" % roster_plan.last_error)
	if int(data.get("schema_version", -1)) != SUPPORTED_SCHEMA_VERSION:
		return _fail("unsupported Wellspring visual catalog schema")
	if str(data.get("id", "")) != "wellspring-visual-catalog-v2":
		return _fail("unexpected Wellspring visual catalog id")

	var contract: Dictionary = data.get("character_contract", {})
	if _vector2i(contract.get("cell_size", [])) != Vector2i(64, 64):
		return _fail("Wellspring character cell size must be 64 x 64")
	if _vector2i(contract.get("pivot", [])) != Vector2i(32, 56):
		return _fail("Wellspring character pivot must be (32, 56)")
	if _vector2i(contract.get("atlas_size", [])) != CHARACTER_ATLAS_SIZE:
		return _fail("Wellspring character atlas size mismatch")
	if (contract.get("directions", []) as Array).size() != 8:
		return _fail("Wellspring character contract requires eight directions")
	if (contract.get("animations", []) as Array).size() != 25:
		return _fail("Wellspring character contract requires 25 animation states")

	races = data.get("races", {})
	var asset_champions: Dictionary = data.get("champions", {})
	wellspring = data.get("wellspring", {})
	districts = wellspring.get("districts", {})
	materials = data.get("materials", {})
	props = data.get("props", {})
	element_vfx = data.get("element_vfx", {})
	ui = data.get("ui", {})

	if races.size() != REQUIRED_RACE_COUNT:
		return _fail("Wellspring visual catalog requires %d race foundations" % REQUIRED_RACE_COUNT)
	if asset_champions.size() != REQUIRED_CHAMPION_COUNT:
		return _fail("Wellspring visual catalog requires %d champion packages" % REQUIRED_CHAMPION_COUNT)
	if districts.size() != REQUIRED_DISTRICT_COUNT:
		return _fail("Wellspring visual catalog requires %d district packages" % REQUIRED_DISTRICT_COUNT)

	for race_id: String in races:
		var race: Dictionary = races[race_id]
		if str(race.get("status", "")) != "production_foundation":
			return _fail("%s race foundation has invalid status" % race_id)
		if race.get("supported_sizes", []) != REQUIRED_SIZES:
			return _fail("%s legacy race foundation does not expose all five archive sizes" % race_id)
		if race.get("presentations", []) != REQUIRED_PRESENTATIONS:
			return _fail("%s race foundation does not expose both presentations" % race_id)
		var base_variants: Dictionary = race.get("base_variants", {})
		for size_id: String in REQUIRED_SIZES:
			var presentations: Dictionary = base_variants.get(size_id, {})
			for presentation: String in REQUIRED_PRESENTATIONS:
				var variant: Dictionary = presentations.get(presentation, {})
				if not _validate_file(str(variant.get("atlas", "")), "%s/%s/%s atlas" % [race_id, size_id, presentation]):
					return false
				if not bool(variant.get("all_keyframes_included", false)):
					return _fail("%s/%s/%s is missing canonical keyframes" % [race_id, size_id, presentation])
		if not _validate_character_package(race.get("exemplar", {}), "%s exemplar" % race_id):
			return false
		if not _validate_image(str(race.get("matrix_preview", "")), Vector2i(800, 384), "%s matrix preview" % race_id):
			return false

	for champion_id: String in asset_champions:
		var champion: Dictionary = asset_champions[champion_id]
		if not races.has(str(champion.get("ancestry", ""))):
			return _fail("%s references an unknown race" % champion_id)
		if champion_id == "unnamed_angel":
			if str(champion.get("status", "")) != "placeholder_unapproved":
				return _fail("Unnamed Angel must remain placeholder_unapproved")
		elif str(champion.get("status", "")) != "integrated_candidate":
			return _fail("%s champion package must remain integrated_candidate" % champion_id)
		if not _validate_character_package(champion, "%s champion" % champion_id):
			return false
	if not _apply_canonical_champion_metadata(asset_champions):
		return false

	if str(wellspring.get("id", "")) != "wellspring" or str(wellspring.get("name", "")) != "The Wellspring":
		return _fail("central hub must be The Wellspring")
	if not _validate_image(str(wellspring.get("tileset", "")), Vector2i(256, 176), "Wellspring tileset"):
		return false
	if not _validate_image(str(wellspring.get("cosmic_cascade", "")), Vector2i(512, 128), "Cosmic Wellspring cascade"):
		return false
	if not _validate_image(str(wellspring.get("overview_1440p", "")), Vector2i(2560, 1440), "Wellspring 1440p overview"):
		return false
	if not _validate_file(str(wellspring.get("tile_registry", "")), "Wellspring tile registry"):
		return false
	for district_id: String in districts:
		var district: Dictionary = districts[district_id]
		if str(district.get("status", "")) != "integrated_candidate":
			return _fail("%s district has invalid status" % district_id)
		if not _validate_image(str(district.get("preview", "")), Vector2i(1280, 720), "%s preview" % district_id):
			return false
		if not _validate_file(str(district.get("layout", "")), "%s layout" % district_id):
			return false

	if (materials.get("materials", []) as Array).size() != 11 or (materials.get("states", []) as Array).size() != 12:
		return _fail("material atlas requires 11 materials x 12 states")
	if not _validate_image(str(materials.get("path", "")), Vector2i(352, 384), "material state atlas"):
		return false
	if (props.get("props", []) as Array).size() != 20 or (props.get("states", []) as Array).size() != 11:
		return _fail("prop atlas requires 20 props x 11 states")
	if not _validate_image(str(props.get("path", "")), Vector2i(960, 528), "interaction prop atlas"):
		return false
	if (element_vfx.get("elements", []) as Array).size() != 8 or (element_vfx.get("phases", []) as Array).size() != 8:
		return _fail("element VFX requires eight elements x eight phases")
	if int(element_vfx.get("frames_per_phase", 0)) != 4:
		return _fail("element VFX requires four frames per phase")
	if not _validate_image(str(element_vfx.get("path", "")), Vector2i(1024, 256), "element VFX atlas"):
		return false
	if (ui.get("surfaces", []) as Array).size() != 20:
		return _fail("UI catalog requires 20 application surfaces")
	if _vector2i(ui.get("virtual_viewport", [])) != Vector2i(640, 360):
		return _fail("UI virtual viewport must be 640 x 360")
	if not _validate_image(str(ui.get("skin", "")), Vector2i(512, 512), "Wellspring UI skin"):
		return false
	if not _validate_image(str(ui.get("surface_overview", "")), Vector2i(1280, 800), "UI surface overview"):
		return false
	return true


func race(race_id: String) -> Dictionary:
	return races.get(race_id, {})


func champion(champion_id: String) -> Dictionary:
	return champions.get(champion_id, {})


func district(district_id: String) -> Dictionary:
	return districts.get(district_id, {})


func _apply_canonical_champion_metadata(asset_champions: Dictionary) -> bool:
	champions.clear()
	# These are historical packages, not a completeness claim for today's cast.
	# Preserve the original 24 packages / 21 race foundations without inventing
	# images for newer identities or promoting archive art to runtime authority.
	var canonical_champions: Dictionary = {}
	for champion_id: String in asset_champions:
		# Retired placeholder pixels remain validated in the raw archive, but
		# must not recreate a current champion or alias the separate named Angel.
		if champion_id == "unnamed_angel":
			continue
		if roster_plan.entry(champion_id).is_empty():
			return _fail("visual archive contains unknown canonical champion ID: %s" % champion_id)
		var canonical: Dictionary = roster_plan.visual_metadata(champion_id, asset_champions[champion_id])
		if canonical.is_empty():
			return _fail("visual archive cannot resolve canonical metadata: %s" % champion_id)
		# Source ancestry was validated against the historical race foundations.
		# Canonical identity changes do not silently relabel pixels as current art.
		canonical_champions[champion_id] = canonical
	champions = canonical_champions
	return true


static func canonical_body_type(value: String) -> String:
	match value.to_lower():
		"small", "tiny", "size_1_tiny", "size_2_small":
			return "small"
		"middle", "medium", "size_3_medium":
			return "middle"
		"large", "huge", "size_4_large", "size_5_huge":
			return "large"
		_:
			return ""


func _validate_character_package(entry: Dictionary, label: String) -> bool:
	if not bool(entry.get("all_keyframes_included", false)):
		return _fail("%s does not include all canonical keyframes" % label)
	var images := {
		"atlas": CHARACTER_ATLAS_SIZE,
		"debug_atlas": CHARACTER_ATLAS_SIZE,
		"direction_preview": Vector2i(1024, 128),
		"keyframe_board": Vector2i(640, 640),
		"selection_icon": Vector2i(48, 48),
		"hud_portrait": Vector2i(64, 64),
		"roster_portrait": Vector2i(128, 128),
		"hero_portrait": Vector2i(256, 256),
	}
	for key: String in images:
		if not _validate_image(str(entry.get(key, "")), images[key], "%s %s" % [label, key]):
			return false
	return true


func _validate_file(path: String, label: String) -> bool:
	if path.is_empty() or not path.begins_with("res://") or not FileAccess.file_exists(path):
		return _fail("%s is missing: %s" % [label, path])
	return true


func _validate_image(path: String, expected_size: Vector2i, label: String) -> bool:
	if not _validate_file(path, label):
		return false
	var image := ImageAssetInspector.load_image(path)
	if image == null:
		return _fail("%s could not be decoded" % label)
	if image.get_size() != expected_size:
		return _fail("%s has size %s; expected %s" % [label, image.get_size(), expected_size])
	if image.is_empty():
		return _fail("%s is empty" % label)
	return true


func _vector2i(value: Variant) -> Vector2i:
	if not value is Array or (value as Array).size() != 2:
		return Vector2i(-1, -1)
	return Vector2i(int((value as Array)[0]), int((value as Array)[1]))


func _fail(message: String) -> bool:
	last_error = message
	return false
