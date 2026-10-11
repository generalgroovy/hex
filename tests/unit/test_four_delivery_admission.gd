extends FluxTestSuite


const DISABLED_WIRES: Array[int] = [101, 110, 143, 144, 146, 147, 148, 149, 150, 151, 152, 153, 155, 156, 157, 158, 161, 162, 165, 166, 167, 168, 169, 170, 171, 172, 175, 177, 178, 187, 188, 189, 190]
const ORIGINAL_WIRES: Array[int] = [140, 181, 182, 141, 145, 179, 180, 154, 163, 185, 186, 164, 159, 183, 184, 160, 173, 191, 192, 174, 142, 193, 194, 176]
const LIVE_FAMILIES: Array[String] = ["bolt", "heavy", "rapid", "spray", "mantle", "fuse", "split", "rebound"]


func run() -> int:
	var catalogue := AbilityCatalog.new()
	var policy := ActionTransitionPolicy.new()
	check(policy.load_from_file(ActionTransitionPolicy.DEFAULT_PATH), "authority transition policy loads")
	check(catalogue.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "four-delivery catalogue validates")
	equal(catalogue.runtime_wire_ids.size(), 504, "63 nonempty mixtures have exactly eight live deliveries")
	equal(Array(catalogue.runtime_wire_ids.slice(0, 24)), ORIGINAL_WIRES, "the original 24 retain their exact wire identities and order")
	var live_cells := {}
	for wire: int in catalogue.runtime_wire_ids:
		var definition := CombatTuning.cast_definition(wire)
		var mask := int(definition.get("element_mask", 0))
		var family := String(definition.get("family", ""))
		check(mask >= 1 and mask <= 63, "live delivery owns a nonempty six-element mask")
		check(family in LIVE_FAMILIES, "live delivery belongs to one of eight authored families")
		var cell := "%s/%s" % [mask, family]
		check(not live_cells.has(cell), "every mixture/family cell is unique")
		live_cells[cell] = true
	for mask: int in range(1, 64):
		for family: String in LIVE_FAMILIES:
			check(live_cells.has("%s/%s" % [mask, family]), "the complete 63 by eight matrix has no missing cell")
	# The compatibility harness intentionally has no Hex court. These original
	# four families must keep their already proven admission and release behavior.
	var original_cells := {}
	for wire: int in ORIGINAL_WIRES:
		var definition := CombatTuning.cast_definition(wire)
		check(int(definition.element_wire_id) in [3, 2, 4, 1, 7, 8], "delivery belongs to one canonical live element")
		check(String(definition.family) in ["bolt", "heavy", "rapid", "spray"], "delivery belongs to one proven family")
		var cell := "%s/%s" % [definition.element_wire_id, definition.family]
		check(not original_cells.has(cell), "every original element/family delivery cell is unique")
		original_cells[cell] = true
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
	# New persistent deliveries require the funded Hex authority. Valid library
	# placement alone must never partially admit them into this legacy harness.
	for mask: int in [1, 2, 4, 8, 16, 32, 63]:
		for family: String in ["mantle", "fuse", "split", "rebound"]:
			var wire := MixtureCatalog.wire_for(mask, family)
			var world := SimWorld.new(120)
			var actor := world.player()
			check(actor.place_proven_spell(0, wire), "live persistent spell remains a valid library choice")
			var before := actor.flux
			check(world.step([SimCommand.new(0, actor.entity_id, 0, 0, 0, SimCommand.PRESSED_SPELL_1)]), "unsupported authority still accepts a well-formed command")
			equal(actor.flux, before, "unsupported authority refuses before any payment")
			equal(actor.pending_cast_wire_id, 0, "unsupported authority does not leave a paid startup")
			equal(actor.spell_cooldown_for_wire(wire), 0, "unsupported authority creates no cooldown")
			equal(world.projectiles.size(), 0, "unsupported authority cannot fabricate an unfunded projectile")
			var refusal := false
			for event: Dictionary in world.combat_events:
				if event.get("type") == "cast_refused" and int(event.get("wire_id", 0)) == wire and event.get("reason") == "requires_hex_authority": refusal = true
			check(refusal, "persistent-family refusal explains its missing Hex authority")
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
