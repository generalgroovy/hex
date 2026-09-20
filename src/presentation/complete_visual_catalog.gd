class_name CompleteVisualCatalog
extends RefCounted


const SUPPORTED_SCHEMA_VERSION: int = 1
const DEFAULT_PATH: String = "res://content/visual/complete_visual_catalog_v1.json"
const CHARACTER_ATLAS_SIZE := Vector2i(960, 1280)
const ChampionRosterPlanScript = preload("res://src/content/champion_roster_plan.gd")

var data: Dictionary = {}
var last_error: String = ""
var ancestries: Dictionary = {}
var champions: Dictionary = {}
var districts: Dictionary = {}
var props: Dictionary = {}
var element_vfx: Dictionary = {}
var ui: Dictionary = {}
var overviews: Dictionary = {}
var roster_plan = ChampionRosterPlanScript.new()


func load_from_file(path: String = DEFAULT_PATH) -> bool:
	last_error = ""
	if not FileAccess.file_exists(path):
		return _fail("complete visual catalog does not exist: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("could not open complete visual catalog: %s" % path)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return _fail("complete visual catalog root must be an object")
	data = parsed
	return validate()


func validate() -> bool:
	last_error = ""
	if roster_plan.ordered_ids.is_empty() and not roster_plan.load_from_files():
		return _fail("canonical champion roster cannot be loaded: %s" % roster_plan.last_error)
	if int(data.get("schema_version", -1)) != SUPPORTED_SCHEMA_VERSION:
		return _fail("unsupported complete visual catalog schema")
	var contract: Dictionary = data.get("character_contract", {})
	if _vector2i(contract.get("cell_size", [])) != Vector2i(32, 32):
		return _fail("complete visual catalog cell size must remain 32 x 32")
	if _vector2i(contract.get("pivot", [])) != Vector2i(16, 28):
		return _fail("complete visual catalog pivot must remain (16, 28)")
	if (contract.get("directions", []) as Array).size() != 8:
		return _fail("complete visual catalog requires eight directions")
	if (contract.get("animations", []) as Array).size() != 25:
		return _fail("complete visual catalog requires 25 animation states")

	ancestries = data.get("ancestries", {})
	var asset_champions: Dictionary = data.get("champions", {})
	districts = data.get("districts", {})
	props = data.get("props", {})
	element_vfx = data.get("element_vfx", {})
	ui = data.get("ui", {})
	overviews = data.get("overviews", {})
	if ancestries.size() != 23:
		return _fail("complete visual catalog requires 23 ancestry/body plans")
	if asset_champions.size() != 24:
		return _fail("complete visual catalog requires 24 champion slots")
	if districts.size() != 9:
		return _fail("complete visual catalog requires nine Sanctum districts")

	for ancestry_id: String in ancestries:
		var ancestry: Dictionary = ancestries[ancestry_id]
		if not _validate_image(str(ancestry.get("atlas", "")), CHARACTER_ATLAS_SIZE, "%s ancestry atlas" % ancestry_id):
			return false
		if not _validate_image(str(ancestry.get("debug_atlas", "")), CHARACTER_ATLAS_SIZE, "%s ancestry debug atlas" % ancestry_id):
			return false
		if not _validate_image(str(ancestry.get("preview", "")), Vector2i(1024, 128), "%s ancestry preview" % ancestry_id):
			return false

	for champion_id: String in asset_champions:
		var champion: Dictionary = asset_champions[champion_id]
		if champion_id == "unnamed_angel":
			if str(champion.get("status", "")) != "placeholder_unapproved":
				return _fail("Unnamed Angel must remain placeholder_unapproved")
		elif str(champion.get("status", "")) != "integrated_candidate":
			return _fail("%s must remain integrated_candidate" % champion_id)
		if not ancestries.has(str(champion.get("ancestry", ""))):
			return _fail("%s references an unknown ancestry" % champion_id)
		if not _validate_image(str(champion.get("atlas", "")), CHARACTER_ATLAS_SIZE, "%s champion atlas" % champion_id):
			return false
		if not _validate_image(str(champion.get("debug_atlas", "")), CHARACTER_ATLAS_SIZE, "%s champion debug atlas" % champion_id):
			return false
		if not _validate_image(str(champion.get("direction_preview", "")), Vector2i(1024, 128), "%s direction preview" % champion_id):
			return false
		if not _validate_image(str(champion.get("portrait", "")), Vector2i(64, 64), "%s portrait" % champion_id):
			return false
		if not _validate_image(str(champion.get("selection_icon", "")), Vector2i(32, 32), "%s selection icon" % champion_id):
			return false
	if not _apply_canonical_champion_metadata(asset_champions):
		return false

	for district_id: String in districts:
		var district: Dictionary = districts[district_id]
		if str(district.get("status", "")) != "presentation_only":
			return _fail("%s must remain presentation_only" % district_id)
		if not _validate_image(str(district.get("preview", "")), Vector2i(1280, 720), "%s preview" % district_id):
			return false
		if not FileAccess.file_exists(str(district.get("layout", ""))):
			return _fail("%s layout is missing" % district_id)

	if (props.get("order", []) as Array).size() != 16 or (props.get("states", []) as Array).size() != 8:
		return _fail("interaction prop atlas must contain 16 props x 8 states")
	if not _validate_image(str(props.get("path", "")), Vector2i(512, 256), "interaction prop atlas"):
		return false
	if (element_vfx.get("elements", []) as Array).size() != 8 or (element_vfx.get("phases", []) as Array).size() != 6:
		return _fail("element VFX atlas must contain eight elements x six phases")
	if not _validate_image(str(element_vfx.get("path", "")), Vector2i(192, 256), "element VFX atlas"):
		return false
	if not _validate_image(str(ui.get("skin", "")), Vector2i(256, 256), "Sanctum UI skin"):
		return false
	if not _validate_image(str(overviews.get("roster", "")), Vector2i(768, 512), "roster overview"):
		return false
	if not _validate_image(str(overviews.get("districts", "")), Vector2i(960, 720), "district overview"):
		return false
	return true


func champion(champion_id: String) -> Dictionary:
	return champions.get(champion_id, {})


func ancestry(ancestry_id: String) -> Dictionary:
	return ancestries.get(ancestry_id, {})


func district(district_id: String) -> Dictionary:
	return districts.get(district_id, {})


func _apply_canonical_champion_metadata(asset_champions: Dictionary) -> bool:
	champions.clear()
	# The archive retains its historical 24 images. New canonical identities do
	# not acquire archived pixels merely by existing or becoming playable.
	var canonical_champions: Dictionary = {}
	for champion_id: String in asset_champions:
		# Retired placeholder pixels remain validated in the raw archive, but
		# must not recreate a current champion or alias the separate named Angel.
		if champion_id == "unnamed_angel":
			continue
		if roster_plan.entry(champion_id).is_empty():
			return _fail("complete visual archive contains unknown canonical champion ID: %s" % champion_id)
		var canonical: Dictionary = roster_plan.visual_metadata(champion_id, asset_champions[champion_id])
		if canonical.is_empty():
			return _fail("complete visual archive cannot resolve canonical metadata: %s" % champion_id)
		# Historical ancestry/art validity was checked before projection. Current
		# ancestry metadata must not imply that those old pixels were redesigned.
		canonical_champions[champion_id] = canonical
	champions = canonical_champions
	return true


func _validate_image(path: String, expected_size: Vector2i, label: String) -> bool:
	if path.is_empty() or not FileAccess.file_exists(path):
		return _fail("%s is missing: %s" % [label, path])
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
