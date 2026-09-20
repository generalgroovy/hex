class_name RuntimeContentSummary
extends RefCounted


# Derived presentation/evidence only: never consulted for combat legality.
static func build(abilities: AbilityCatalog, champions: ChampionCatalog, reactions: ReactionCatalog) -> Dictionary:
	if abilities == null or champions == null or reactions == null:
		return {}
	if abilities.content_hash.is_empty() or champions.content_hash.is_empty() or reactions.content_hash.is_empty():
		return {}
	return {
		"schema_version": 1,
		"authority": "derived from validated loaded catalogs; not gameplay configuration",
		"runtime": {
			"protocol": SimConfig.PROTOCOL_VERSION,
			"snapshot_schema": SessionSnapshot.SCHEMA_VERSION,
			"preferences_schema": PlayerPreferences.SCHEMA_VERSION,
			"simulation_hz": SimConfig.TICK_RATE,
			"maximum_players": SessionTransport.MAX_PLAYERS,
		},
		"content": {
			"abilities_authored": abilities.abilities_by_id.size(),
			"spells_runtime_selectable": abilities.runtime_wire_ids.size(),
			"spell_positions": PlayerState.SPELL_SLOT_COUNT,
			"champions_playable": champions.champions_by_id.size(),
			"playable_champion_ids": champions.ordered_champion_ids(),
			"body_roles": ChampionCatalog.SUPPORTED_BODY_TYPES.duplicate(),
			"reactions_defined": reactions.reactions_by_id.size(),
			"reaction_mutation_enabled": bool(reactions.data.get("runtime_enabled", false)),
			"hashes": {
				"abilities": abilities.content_hash,
				"champions": champions.content_hash,
				"reactions": reactions.content_hash,
			},
		},
	}


static func spell_loom_lines(summary: Dictionary) -> Array[String]:
	if summary.is_empty():
		return ["CONTENT STATUS UNAVAILABLE"]
	var content: Dictionary = summary["content"]
	return [
		"%d SPELLS / %d POSITIONS" % [content["spells_runtime_selectable"], content["spell_positions"]],
		"%d PLAYABLE CHAMPIONS" % content["champions_playable"],
		"%d RECIPES / %s" % [content["reactions_defined"], "CHEMISTRY LIVE" if content["reaction_mutation_enabled"] else "CHEMISTRY SEALED"],
	]
