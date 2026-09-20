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
	return finish("character-weave-policy")
