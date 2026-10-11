class_name ChampionRosterPlan
extends RefCounted


const DEFAULT_PATH := "res://content/champions/champion_roster_plan_v1.json"
const EXPECTED_ID := "champion-roster-plan-v1"
const EXPECTED_STATUS := "canonical_identity_availability_registry"
const EXPECTED_AUTHORITY := "canonical identity, ancestry, body role and availability; playable profiles remain owned by foundation_champions_v1"
const EXPECTED_CHAMPION_COUNT := 30
const EXPECTED_PLAYABLE_COUNT := 30
const ALLOWED_AVAILABILITY: Array[String] = ["playable", "planned", "placeholder"]
const EXPECTED_BODY_ROLES: Array[String] = ["small", "middle", "large"]

var data: Dictionary = {}
var champions_by_id: Dictionary = {}
var affinities_by_id: Dictionary = {}
var ordered_ids: Array[String] = []
var content_hash := ""
var last_error := ""


func load_from_files(path: String = DEFAULT_PATH) -> bool:
	data.clear()
	champions_by_id.clear()
	affinities_by_id.clear()
	ordered_ids.clear()
	content_hash = ""
	last_error = ""
	if not FileAccess.file_exists(path):
		return _fail("champion roster plan does not exist: %s" % path)
	var source := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(source)
	if not parsed is Dictionary:
		return _fail("champion roster plan root must be an object")
	data = parsed
	if not validate():
		return false
	var hash_source := source
	for dependency: String in ["affinity_catalog", "playable_catalog", "identity_migrations"]:
		hash_source += "\n" + FileAccess.get_file_as_string(String(data[dependency])).sha256_text()
	content_hash = hash_source.sha256_text()
	return true


func validate() -> bool:
	last_error = ""
	champions_by_id.clear()
	affinities_by_id.clear()
	ordered_ids.clear()
	if int(data.get("schema_version", -1)) != 1 or String(data.get("id", "")) != EXPECTED_ID:
		return _fail("champion roster plan identity is unsupported")
	if String(data.get("status", "")) != EXPECTED_STATUS or String(data.get("authority", "")) != EXPECTED_AUTHORITY:
		return _fail("champion roster must declare canonical identity and availability authority")
	for required_path: String in ["affinity_catalog", "playable_catalog", "identity_migrations"]:
		var referenced_path := String(data.get(required_path, ""))
		if not referenced_path.begins_with("res://content/champions/") or not FileAccess.file_exists(referenced_path):
			return _fail("champion roster plan reference is missing: %s" % required_path)
	for array_field: String in ["allowed_ancestries", "allowed_body_roles", "champions"]:
		if not data.get(array_field) is Array:
			return _fail("champion roster plan %s must be an array" % array_field)
	var allowed_ancestries: Array = data.get("allowed_ancestries", [])
	var allowed_body_roles: Array = data.get("allowed_body_roles", [])
	if allowed_ancestries.size() < 16 or allowed_body_roles != EXPECTED_BODY_ROLES:
		return _fail("champion roster plan ancestry/body vocabulary is incomplete")
	var champions: Array = data.get("champions", [])
	if champions.size() != EXPECTED_CHAMPION_COUNT:
		return _fail("champion roster plan must contain exactly %d identities" % EXPECTED_CHAMPION_COUNT)
	var display_names: Dictionary = {}
	var playable_count := 0
	var placeholder_count := 0
	for value: Variant in champions:
		if not value is Dictionary:
			return _fail("champion roster plan entry must be an object")
		var champion: Dictionary = value
		var champion_id := String(champion.get("id", ""))
		var display_name := String(champion.get("display_name", ""))
		var ancestry := String(champion.get("ancestry", ""))
		var body_role := String(champion.get("body_role", ""))
		var availability := String(champion.get("availability", ""))
		if not _valid_id(champion_id) or champions_by_id.has(champion_id):
			return _fail("champion roster plan ID is invalid or duplicated: %s" % champion_id)
		if display_name.is_empty() or display_names.has(display_name.to_lower()):
			return _fail("champion roster display name is empty or duplicated: %s" % display_name)
		if ancestry not in allowed_ancestries or body_role not in allowed_body_roles:
			return _fail("champion roster ancestry/body role is invalid: %s" % champion_id)
		if availability not in ALLOWED_AVAILABILITY:
			return _fail("champion roster availability is invalid: %s" % champion_id)
		if String(champion.get("affinity_profile_id", "")) != champion_id:
			return _fail("champion roster affinity reference must preserve the compatibility ID: %s" % champion_id)
		if availability == "playable":
			playable_count += 1
		elif availability == "placeholder":
			placeholder_count += 1
		champions_by_id[champion_id] = champion.duplicate(true)
		ordered_ids.append(champion_id)
		display_names[display_name.to_lower()] = true
	if playable_count != EXPECTED_PLAYABLE_COUNT or placeholder_count != 0:
		return _fail("champion roster must contain %d playable entries and no placeholders" % EXPECTED_PLAYABLE_COUNT)
	return _validate_linked_catalogs()


func entry(champion_id: String) -> Dictionary:
	return (champions_by_id.get(champion_id, {}) as Dictionary).duplicate(true)


func affinity_entry(champion_id: String) -> Dictionary:
	return (affinities_by_id.get(champion_id, {}) as Dictionary).duplicate(true)


func visual_metadata(champion_id: String, asset_entry: Dictionary) -> Dictionary:
	if not champions_by_id.has(champion_id) or not affinities_by_id.has(champion_id):
		return {}
	var roster := entry(champion_id)
	var affinity := affinity_entry(champion_id)
	var result := asset_entry.duplicate(true)
	for field: String in ["display_name", "ancestry", "size", "elements"]:
		result["archive_" + field] = result.get(field)
	result["display_name"] = roster["display_name"]
	result["ancestry"] = roster["ancestry"]
	result["body_type"] = roster["body_role"]
	result["availability"] = roster["availability"]
	result["elements"] = affinity["affinities"]
	result["affinity_points"] = affinity["affinity_points"]
	# Correct metadata does not certify that archived pixels match today's design.
	result["asset_authority"] = "legacy_visual_archive"
	return result


func ids_by_availability(availability: String) -> Array[String]:
	var result: Array[String] = []
	for champion_id: String in ordered_ids:
		if String((champions_by_id[champion_id] as Dictionary).get("availability", "")) == availability:
			result.append(champion_id)
	return result


func _validate_linked_catalogs() -> bool:
	var affinity_data := _load_dictionary(String(data["affinity_catalog"]), "affinity catalog")
	var playable_data := _load_dictionary(String(data["playable_catalog"]), "playable catalog")
	var migration_data := _load_dictionary(String(data["identity_migrations"]), "identity migration catalog")
	if affinity_data.is_empty() or playable_data.is_empty() or migration_data.is_empty():
		return false
	for value: Variant in affinity_data.get("champions", []):
		if not value is Dictionary:
			return _fail("affinity profile must be an object")
		var affinity: Dictionary = value
		var affinity_id := String(affinity.get("id", ""))
		if affinities_by_id.has(affinity_id):
			return _fail("duplicate affinity profile: %s" % affinity_id)
		if not affinity.get("affinities") is Array or not affinity.get("affinity_points") is Dictionary:
			return _fail("affinity profile requires element and point collections: %s" % affinity_id)
		var elements: Array = affinity["affinities"]
		var points: Dictionary = affinity["affinity_points"]
		if elements.size() < 2 or elements.size() > 3 or points.size() != elements.size():
			return _fail("affinity profile requires two or three distinct elements: %s" % affinity_id)
		var seen: Dictionary = {}
		var point_total := 0
		for element: Variant in elements:
			if element not in AbilityCatalog.DISPLAY_ELEMENT_IDS or seen.has(element):
				return _fail("affinity profile contains a duplicate or gated element: %s" % affinity_id)
			var strength: Variant = points.get(element)
			if not (strength is int or strength is float):
				return _fail("affinity strength must be numeric: %s" % affinity_id)
			if float(strength) != floorf(float(strength)) or int(strength) < 1 or int(strength) > 2:
				return _fail("affinity strength must be one or two: %s" % affinity_id)
			point_total += int(strength)
			seen[element] = true
		if point_total != 3:
			return _fail("affinity profile must spend exactly three points: %s" % affinity_id)
		affinities_by_id[affinity_id] = affinity
	if affinities_by_id.size() != champions_by_id.size():
		return _fail("planned roster and affinity catalog contain different identity counts")
	for champion_id: String in ordered_ids:
		if not affinities_by_id.has(champion_id):
			return _fail("planned roster is missing affinity identity: %s" % champion_id)
		if String((affinities_by_id[champion_id] as Dictionary).get("display_name", "")) != String((champions_by_id[champion_id] as Dictionary).get("display_name", "")):
			return _fail("planned roster and affinity display names disagree: %s" % champion_id)
		if String((affinities_by_id[champion_id] as Dictionary).get("availability", "")) != String((champions_by_id[champion_id] as Dictionary).get("availability", "")):
			return _fail("roster and affinity availability disagree: %s" % champion_id)
	var playable_by_id: Dictionary = {}
	for value: Variant in playable_data.get("champions", []):
		if value is Dictionary:
			playable_by_id[String((value as Dictionary).get("id", ""))] = value
	if playable_by_id.size() != EXPECTED_PLAYABLE_COUNT:
		return _fail("playable catalog must contain exactly %d promoted champions" % EXPECTED_PLAYABLE_COUNT)
	for champion_id: String in ordered_ids:
		var roster_entry: Dictionary = champions_by_id[champion_id]
		var should_be_playable := String(roster_entry.get("availability", "")) == "playable"
		if should_be_playable != playable_by_id.has(champion_id):
			return _fail("planned roster availability disagrees with playable catalog: %s" % champion_id)
		if not should_be_playable:
			continue
		var playable_entry: Dictionary = playable_by_id[champion_id]
		if String(playable_entry.get("display_name", "")) != String(roster_entry.get("display_name", "")) \
			or String(playable_entry.get("ancestry", "")) != String(roster_entry.get("ancestry", "")) \
			or String(playable_entry.get("body_type", "")) != String(roster_entry.get("body_role", "")):
			return _fail("promoted champion identity differs from roster plan: %s" % champion_id)
	var migrations_by_id: Dictionary = {}
	for value: Variant in migration_data.get("migrations", []):
		if value is Dictionary:
			migrations_by_id[String((value as Dictionary).get("legacy_technical_id", ""))] = value
	for champion_id: String in ["nico_lai", "donnok"]:
		if not migrations_by_id.has(champion_id):
			return _fail("planned technical identity lacks its migration contract: %s" % champion_id)
		var migration: Dictionary = migrations_by_id[champion_id]
		var roster_entry: Dictionary = champions_by_id[champion_id]
		if String(migration.get("canonical_display_name", "")) != String(roster_entry.get("display_name", "")) \
			or String(migration.get("planned_canonical_technical_id", "")) != String(roster_entry.get("future_technical_id", "")):
			return _fail("planned technical identity migration differs from roster plan: %s" % champion_id)
	return true


func _load_dictionary(path: String, label: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_fail("%s is missing: %s" % [label, path])
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		_fail("%s root must be an object" % label)
		return {}
	return parsed


func _valid_id(value: String) -> bool:
	if value.is_empty() or value.begins_with("_") or value.ends_with("_"):
		return false
	for character: String in value:
		if character != "_" and not character.is_valid_identifier() and not character.is_valid_int():
			return false
	return value.to_lower() == value


func _fail(message: String) -> bool:
	last_error = message
	champions_by_id.clear()
	affinities_by_id.clear()
	ordered_ids.clear()
	content_hash = ""
	return false
