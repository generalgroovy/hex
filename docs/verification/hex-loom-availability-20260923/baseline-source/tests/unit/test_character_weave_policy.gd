extends FluxTestSuite


func run() -> int:
	var state := PlayerState.new()
	var wires := state.spell_wire_ids.duplicate()
	state.set_spell_cooldown(wires[0], 91)
	state.set_spell_cooldown(wires[5], 27)
	var changed := wires.duplicate()
	changed.reverse()
	var before := state.canonical_values()
	var preview := CharacterWeavePolicy.changes(state, changed)
	equal(preview.size(), 12, "starter preview names every changed position")
	equal(state.canonical_values(), before, "preview cannot mutate authority")
	check(CharacterWeavePolicy.apply(state, changed), "complete valid weave applies atomically")
	equal(state.spell_wire_ids, changed, "all twelve positions apply")
	equal(state.spell_cooldown_for_wire(wires[0]), 91, "moving a spell preserves its cooldown")
	equal(state.spell_cooldown_for_wire(wires[5]), 27, "a second moved spell preserves independent cooldown")
	before = state.canonical_values()
	var duplicate := changed.duplicate()
	duplicate[0] = duplicate[1]
	check(not CharacterWeavePolicy.apply(state, duplicate), "duplicate weave refuses as a whole")
	equal(state.canonical_values(), before, "invalid weave changes no slots or cooldowns")
	check(not CharacterWeavePolicy.apply(state, PackedInt32Array([140])), "partial weave refuses")
	equal(state.canonical_values(), before, "partial request changes no authority")
	_test_cooling_spell_removal()
	return finish("character-weave-policy")


func _test_cooling_spell_removal() -> void:
	var state := PlayerState.new()
	var original := state.spell_wire_ids.duplicate()
	var cooling_slot := -1
	for slot: int in range(original.size()):
		if original[slot] not in state.kit_spell_wire_ids():
			cooling_slot = slot
			break
	var replacement := 0
	for wire: int in CombatTuning.runtime_wire_ids():
		if wire not in original and wire not in state.kit_spell_wire_ids():
			replacement = wire
			break
	check(cooling_slot >= 0 and replacement > 0, "cooldown regression has a non-legacy equipped spell and an unequipped replacement")
	if cooling_slot < 0 or replacement <= 0: return
	var cooling_wire: int = original[cooling_slot]
	check(state.set_spell_cooldown(cooling_wire, 7), "cooldown regression starts with a real spell-owned timer")
	var proposed := original.duplicate()
	proposed[cooling_slot] = replacement
	var before := state.canonical_values()
	check(not CharacterWeavePolicy.apply(state, proposed), "removing a cooling non-legacy spell refuses before its timer can be lost")
	equal(state.canonical_values(), before, "cooldown removal refusal leaves the full actor authority unchanged")
	check(CharacterWeavePolicy.apply(state, original), "reapplying the original weave is safe after refused removal")
	equal(state.spell_cooldown_for_wire(cooling_wire), 7, "remove and reequip cannot reset a spell-owned cooldown")
	var swapped := original.duplicate()
	var other_slot := (cooling_slot + 1) % original.size()
	swapped[cooling_slot] = original[other_slot]
	swapped[other_slot] = cooling_wire
	check(CharacterWeavePolicy.apply(state, swapped), "a cooling spell may move between slots without being removed")
	equal(state.spell_cooldown_for_wire(cooling_wire), 7, "slot swap retains the complete cooldown")
	for unused: int in range(7): state.advance_spell_cooldowns()
	equal(state.spell_cooldown_for_wire(cooling_wire), 0, "spell cooldown expires through its ordinary advancement")
	var after_expiry := state.spell_wire_ids.duplicate()
	after_expiry[other_slot] = replacement
	check(CharacterWeavePolicy.apply(state, after_expiry), "expired spell can be replaced without cooldown loss")
	check(state.has_valid_spell_slots(), "successful post-expiry replacement keeps a valid twelve-spell weave")
