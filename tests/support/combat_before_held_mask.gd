extends RefCounted

# Exact ordered held-repeat selection before the empty-mask guard.
# Source SHA-256: 748b852dbe1910e7daaa422e3abf52e7a3968a28928a46b1e88375a4641f426e

static func _first_held_repeating_slot(state: PlayerState, command: SimCommand) -> int:
	# Single-press families and empty positions do not own held intent. Among
	# repeating positions, the lowest slot keeps deterministic priority even
	# when its ordinary cooldown/resource/capacity gate refuses admission.
	for index: int in range(SimCommand.SPELL_HELD_BITS.size()):
		if command.has_held(SimCommand.SPELL_HELD_BITS[index]) and bool(CombatTuning.cast_definition_view(state.spell_wire_id(index + 1)).get("repeat_while_held", false)):
			return index + 1
	return 0
