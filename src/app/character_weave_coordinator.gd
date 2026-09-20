class_name CharacterWeaveCoordinator
extends RefCounted


# Local configuration memory only. The caller owns station/round admission and
# host authority. Remote actors never write the local player's library.
var library := CharacterWeaveLibrary.new()
var champions: ChampionCatalog
var abilities: AbilityCatalog
var path := CharacterWeaveLibrary.DEFAULT_PATH
var persistence_allowed := false
var configured := false
var last_error := ""
var session_weaves: Dictionary = {}


func configure(champion_catalog: ChampionCatalog, ability_catalog: AbilityCatalog, allow_persistence: bool, store_path: String = CharacterWeaveLibrary.DEFAULT_PATH) -> bool:
	champions = champion_catalog
	abilities = ability_catalog
	path = store_path
	configured = library.load_from_file(path, champions, abilities)
	persistence_allowed = configured and allow_persistence
	last_error = library.last_error
	return configured


func remember_actor(state: PlayerState) -> void:
	if champions == null or state == null or state.entity_id < 1 or state.entity_id > 8 or not state.has_valid_spell_slots(): return
	var champion_id := champions.champion_id_from_wire(state.champion_wire_id)
	if champion_id.is_empty(): return
	var per_character: Dictionary = session_weaves.get(state.entity_id, {})
	per_character[champion_id] = state.spell_wire_ids.duplicate()
	session_weaves[state.entity_id] = per_character


func preferred_weave(state: PlayerState, local: bool) -> PackedInt32Array:
	if state == null or champions == null: return PackedInt32Array()
	var champion_id := champions.champion_id_from_wire(state.champion_wire_id)
	var per_character: Dictionary = session_weaves.get(state.entity_id, {})
	if per_character.has(champion_id): return (per_character[champion_id] as PackedInt32Array).duplicate()
	if local and configured:
		var saved := library.saved_weave(champion_id)
		if not saved.is_empty(): return (saved.wire_ids as PackedInt32Array).duplicate()
	return PackedInt32Array()


func restore_actor(state: PlayerState, local: bool) -> bool:
	var wires := preferred_weave(state, local)
	if wires.is_empty(): return true
	if not CharacterWeavePolicy.apply(state, wires):
		last_error = "Saved weave contains an unavailable spell; stored weave preserved."
		return false
	return true


func save_local(state: PlayerState, mode: String) -> bool:
	if not configured or state == null: return false
	var champion_id := champions.champion_id_from_wire(state.champion_wire_id)
	var previous_library := library.weaves_by_champion.duplicate(true)
	if not library.remember(champion_id, state.spell_wire_ids, mode, champions, abilities):
		last_error = library.last_error
		return false
	remember_actor(state)
	if persistence_allowed and not library.save_to_file(path):
		library.weaves_by_champion = previous_library
		last_error = library.last_error
		return false
	last_error = ""
	return true
