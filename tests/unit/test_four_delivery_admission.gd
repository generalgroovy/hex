extends FluxTestSuite


const DISABLED_WIRES: Array[int] = [110, 143, 144, 146, 147, 148, 149, 150, 151, 152, 153, 155, 156, 157, 158, 161, 162, 165, 166, 168, 169, 172, 175, 177, 178]


func run() -> int:
	var catalogue := AbilityCatalog.new()
	var policy := ActionTransitionPolicy.new()
	check(policy.load_from_file(ActionTransitionPolicy.DEFAULT_PATH), "authority transition policy loads")
	check(catalogue.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "four-delivery catalogue validates")
	equal(catalogue.runtime_wire_ids.size(), 32, "eight elements retain exactly four deliveries")
	for wire: int in catalogue.runtime_wire_ids:
		var world := SimWorld.new(120)
		var state := world.player()
		check(state.place_proven_spell(0, wire), "retained spell %d equips" % wire)
		var flux_before := state.flux
		var command := SimCommand.new(0, state.entity_id, 0, 0, 0, SimCommand.PRESSED_SPELL_1, 1000, 0)
		check(world.step([command]), "retained spell %d enters authority" % wire)
		equal(state.pending_cast_wire_id, wire, "retained spell %d starts its own attack" % wire)
		check(state.flux < flux_before, "retained spell %d pays positive Flux" % wire)
		var released := false
		for _tick: int in range(80):
			check(world.step([SimCommand.new(world.tick, state.entity_id)]), "retained release remains valid")
			for event: Dictionary in world.combat_events:
				if String(event.get("type", "")) in ["projectile_spawned", "spray_fired"] and int(event.get("wire_id", event.get("source_wire_id", 0))) == wire:
					released = true
			if released:
				break
		check(released, "retained spell %d reaches its actual delivery resolver" % wire)
	for wire: int in DISABLED_WIRES:
		check(not catalogue.ability_from_wire(wire).is_empty(), "disabled %d keeps authored identity" % wire)
		check(CombatTuning.cast_definition(wire).is_empty(), "disabled %d has no live definition" % wire)
		var state := PlayerState.new(1)
		var slots_before := state.spell_wire_ids.duplicate()
		check(not state.place_proven_spell(0, wire), "disabled %d cannot be placed" % wire)
		equal(state.spell_wire_ids, slots_before, "disabled placement preserves the weave")
		# Bypass placement deliberately: authority must reject an injected slot.
		state.spell_wire_ids[0] = wire
		var flux_before := state.flux
		var events: Array[Dictionary] = []
		var result: Variant = CombatSystem.step_player(state, SimCommand.new(0, 1, 0, 0, 0, SimCommand.PRESSED_SPELL_1, 1000, 0), SimConfig.new(120), 500, 600, CollisionWorld.new(), events, policy)
		check(result == null and state.pending_cast_wire_id == 0, "injected disabled %d produces no attack" % wire)
		equal(state.flux, flux_before, "disabled admission spends no Flux")
		check(events.size() == 1 and events[0].get("type") == "cast_refused" and events[0].get("reason") == "kit", "disabled admission reports refusal")
		equal(state.spell_cooldown_for_wire(wire), 0, "disabled admission creates no cooldown")
		state.pending_cast_wire_id = wire
		state.pending_cast_ticks = 1
		events.clear()
		result = CombatSystem.step_player(state, SimCommand.new(1, 1), SimConfig.new(120), 500, 600, CollisionWorld.new(), events, policy)
		check(result == null and state.pending_cast_wire_id == 0 and state.pending_cast_ticks == 0, "disabled pending %d is cancelled before release" % wire)
		equal(state.flux, flux_before, "disabled pending state cannot add spend or refunds")
		check(events.size() == 1 and events[0].get("type") == "cast_refused", "disabled pending state cannot emit damage or deposit outcomes")
	return finish("four-delivery-admission")
