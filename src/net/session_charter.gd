class_name SessionCharter
extends RefCounted


const SCHEMA_VERSION: int = 1
const MAX_SUPPORTED_PLAYERS: int = 8
const HOST_ENTITY_ID: int = 1
const DEFAULT_ID: String = "open_commons"
const PROFILE_ORDER: Array[String] = ["open_commons", "sparring_circle", "duel_knot"]
const RESET_ANY_TRAVELLER: String = "any_traveller"
const RESET_HOST_ONLY: String = "host_only"
const PROFILES: Dictionary = {
	"open_commons": {
		"id": "open_commons",
		"display_name": "OPEN COMMONS",
		"maximum_players": 8,
		"player_damage": false,
		"practice_reset": RESET_ANY_TRAVELLER,
		"description": "Roam, train and cast together without friendly harm",
	},
	"sparring_circle": {
		"id": "sparring_circle",
		"display_name": "SPARRING CIRCLE",
		"maximum_players": 4,
		"player_damage": true,
		"practice_reset": RESET_ANY_TRAVELLER,
		"description": "Four-way friendly combat with a shared practice bell",
	},
	"duel_knot": {
		"id": "duel_knot",
		"display_name": "DUEL KNOT",
		"maximum_players": 2,
		"player_damage": true,
		"practice_reset": RESET_HOST_ONLY,
		"description": "A focused pair; only the host restores the court",
	},
}


static func definition(profile_id: String) -> Dictionary:
	if not PROFILE_ORDER.has(profile_id) or not PROFILES.has(profile_id):
		return {}
	var value: Variant = PROFILES[profile_id]
	if not value is Dictionary or not validate_definition(value):
		return {}
	return (value as Dictionary).duplicate(true)


static func validate_definition(value: Dictionary) -> bool:
	var profile_id := String(value.get("id", ""))
	if not PROFILE_ORDER.has(profile_id) or not PROFILES.has(profile_id):
		return false
	if String(value.get("display_name", "")).is_empty() or String(value.get("display_name", "")).length() > 24:
		return false
	if typeof(value.get("maximum_players")) != TYPE_INT:
		return false
	var maximum_players := int(value["maximum_players"])
	if maximum_players < 2 or maximum_players > MAX_SUPPORTED_PLAYERS:
		return false
	if typeof(value.get("player_damage")) != TYPE_BOOL:
		return false
	if String(value.get("practice_reset", "")) not in [RESET_ANY_TRAVELLER, RESET_HOST_ONLY]:
		return false
	var description := String(value.get("description", ""))
	return not description.is_empty() and description.length() <= 64


static func is_valid_id(profile_id: String) -> bool:
	return not definition(profile_id).is_empty()


static func next_id(profile_id: String) -> String:
	var index := PROFILE_ORDER.find(profile_id)
	return PROFILE_ORDER[(index + 1) % PROFILE_ORDER.size()] if index >= 0 else DEFAULT_ID


static func catalog_hash() -> String:
	return CanonicalContent.sha256({
		"schema_version": SCHEMA_VERSION,
		"order": PROFILE_ORDER,
		"profiles": PROFILES,
	})


static func profile_hash(profile_id: String) -> String:
	var profile := definition(profile_id)
	return CanonicalContent.sha256(profile) if not profile.is_empty() else ""


static func validate_assignment(profile_id: String, expected_hash: String) -> bool:
	var actual_hash := profile_hash(profile_id)
	return actual_hash.length() == 64 and actual_hash == expected_hash


static func maximum_players(profile_id: String) -> int:
	return int(definition(profile_id).get("maximum_players", 0))


static func player_damage_enabled(profile_id: String) -> bool:
	return bool(definition(profile_id).get("player_damage", false))


static func can_reset_practice(profile_id: String, entity_id: int) -> bool:
	var policy := String(definition(profile_id).get("practice_reset", ""))
	return policy == RESET_ANY_TRAVELLER or (policy == RESET_HOST_ONLY and entity_id == HOST_ENTITY_ID)


static func team_for_champion(profile_id: String, entity_id: int) -> int:
	if entity_id < HOST_ENTITY_ID or not is_valid_id(profile_id):
		return 0
	return entity_id if player_damage_enabled(profile_id) else HOST_ENTITY_ID


static func display_name(profile_id: String) -> String:
	return String(definition(profile_id).get("display_name", "UNKNOWN CHARTER"))
