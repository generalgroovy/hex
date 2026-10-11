class_name SpellTrainingRange
extends RefCounted
## Catalog-derived temporary weave. A selection never fires or persists a spell.

const Mixtures = preload("res://src/content/mixture_catalog.gd")
var active := false
var last_error := ""
var selected_mask := 1
var selected_family := "bolt"
var _actor: PlayerState
var _champion_wire := 0
var _original_wires := PackedInt32Array()
var _cooldowns := {}
var _started_tick := 0


func begin(actor: PlayerState, offline: bool, world_tick: int = 0) -> bool:
	if active or not offline or actor == null or not actor.has_valid_spell_slots() or world_tick < 0: return false
	_actor = actor
	_champion_wire = actor.champion_wire_id
	_original_wires = actor.spell_wire_ids.duplicate()
	_cooldowns.clear()
	for wire: int in _original_wires: _cooldowns[wire] = actor.spell_cooldown_for_wire(wire)
	_started_tick = world_tick
	active = true
	last_error = ""
	return true


func preview(mask: int, family: String, abilities: AbilityCatalog) -> Dictionary:
	if not _same_actor(_actor) or abilities == null: return {}
	var wire := Mixtures.wire_for(mask, family)
	var spell_id := abilities.ability_id_from_wire(wire)
	if wire <= 0 or spell_id.is_empty() or not CombatTuning.is_runtime_wire_id(wire): return {}
	var requested := _actor.spell_wire_ids.duplicate()
	var previous_index := requested.find(wire)
	if previous_index >= 0:
		requested[previous_index] = requested[0]
	requested[0] = wire
	if not CharacterWeavePolicy.can_apply(_actor, requested):
		last_error = "That loaner is still cooling. Wait, or use Range Reset before changing it."
		return {}
	selected_mask = mask
	selected_family = family
	last_error = ""
	return {"expected_wire_ids": _actor.spell_wire_ids.duplicate(), "wire_ids": requested,
		"selected_wire": wire, "spell_id": spell_id, "save": false,
		"notice": "Temporary Range loaner in slot 1. Press its normal control to cast.",
		"warning": "Fuse detonates after its visible delay; leave the marked blast." if family == "fuse" else "Normal paid casting, collision and elemental effects apply."}


func restore(actor: PlayerState, world_tick: int = 0) -> bool:
	if not _same_actor(actor) or world_tick < _started_tick: return false
	# Ending this isolated loaner session may remove a cooling loaner. Original
	# spell timers retain the later of their real current timer and elapsed saved
	# timer; entering/leaving practice cannot reset an original paid cooldown.
	var timers := PackedInt32Array()
	for wire: int in _original_wires:
		timers.append(maxi(actor.spell_cooldown_for_wire(wire), maxi(0, int(_cooldowns[wire]) - (world_tick - _started_tick))))
	actor.spell_wire_ids = _original_wires.duplicate()
	actor.spell_cooldown_ticks = timers
	actor._sync_legacy_spell_cooldowns()
	close()
	return true


func close() -> void:
	active = false
	_actor = null
	_original_wires = PackedInt32Array()
	_cooldowns.clear()
	last_error = ""


func view() -> Dictionary:
	return {"active": active, "mask": selected_mask, "family": selected_family,
		"mixtures": 63, "families": Mixtures.FAMILIES.size(), "spells": 63 * Mixtures.FAMILIES.size(),
		"error": last_error, "notice": "Range loaners are temporary. Your original weave returns when you leave."}


static func entries(abilities: AbilityCatalog) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if abilities == null: return result
	for mixture: Dictionary in Mixtures.all():
		for family: String in Mixtures.FAMILIES:
			var wire := Mixtures.wire_for(int(mixture.element_mask), family)
			var spell := abilities.ability(abilities.ability_id_from_wire(wire))
			if spell.is_empty() or not CombatTuning.is_runtime_wire_id(wire): return []
			result.append({"wire": wire, "mask": int(mixture.element_mask), "family": family,
				"name": String(spell.get("display_name", "")), "purpose": String(mixture.get("purpose", "")), "counter": String(mixture.get("counter", ""))})
	return result


func _same_actor(actor: PlayerState) -> bool:
	return active and actor != null and actor == _actor and actor.champion_wire_id == _champion_wire and actor.has_valid_spell_slots()
