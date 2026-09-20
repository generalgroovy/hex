class_name CharacterWeavePolicy
extends RefCounted


# Pure authority operation. Persistence and location/round admission belong to
# the caller. The twelve positions do not change the legacy E/controller kit.
static func apply(state: PlayerState, requested: PackedInt32Array) -> bool:
	if state == null or not state.has_valid_spell_slots() or requested.size() != PlayerState.SPELL_SLOT_COUNT:
		return false
	var seen := {}
	for wire: int in requested:
		if not CombatTuning.is_runtime_wire_id(wire) or seen.has(wire): return false
		seen[wire] = true
	var cooldowns := PackedInt32Array()
	for wire: int in requested:
		cooldowns.append(state.spell_cooldown_for_wire(wire))
	# Validation completed before the first mutation. Preserve cooldown ownership
	# for every retained spell, including the independent legacy aliases.
	state.spell_wire_ids = requested.duplicate()
	state.spell_cooldown_ticks = cooldowns
	state._sync_legacy_spell_cooldowns()
	return true


static func changes(state: PlayerState, requested: PackedInt32Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if state == null or requested.size() != PlayerState.SPELL_SLOT_COUNT: return result
	for slot: int in PlayerState.SPELL_SLOT_COUNT:
		if state.spell_wire_id(slot + 1) != requested[slot]:
			result.append({"slot": slot, "before": state.spell_wire_id(slot + 1), "after": requested[slot]})
	return result
