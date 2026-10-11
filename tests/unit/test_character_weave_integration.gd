extends FluxTestSuite


class FailedSaveLibrary:
	extends CharacterWeaveLibrary
	func save_to_file(_path: String) -> bool:
		last_error = "Simulated persistent write failure."
		return false


func run() -> int:
	var abilities := AbilityCatalog.new()
	var champions := ChampionCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "canonical ability catalog loads")
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "canonical character catalog loads")
	for id: String in champions.ordered_champion_ids():
		var actor := PlayerState.new()
		check(champions.apply_to_player(actor, id), "all thirty initialize")
		equal(actor.spell_wire_ids, CharacterStarterKit.build(champions, abilities, id).wire_ids, "live character initialization uses the canonical generated twelve")
	_test_legacy_alias_cooldown()
	_test_whole_request()
	_test_session_memory(champions, abilities)
	_test_failed_save_keeps_accepted_session_weave(champions, abilities)
	return finish("character-weave-integration")


func _test_legacy_alias_cooldown() -> void:
	var world := SimWorld.new()
	var state := world.player()
	var alias := 0
	for wire: int in CombatTuning.runtime_wire_ids():
		if state.spell_slot_index_for_wire(wire) < 0:
			alias = wire
			break
	check(alias > 0, "fixture finds independent old active spell")
	state.active_1_wire_id = alias
	state.flux_recovery_per_second = 0
	check(state.set_spell_cooldown(alias, 5), "legacy E accepts cooldown while absent from twelve slots")
	state.advance_spell_cooldowns()
	equal(state.spell_cooldown_for_wire(alias), 4, "absent E cooldown decrements once")
	var before := state.flux
	check(world.step([SimCommand.new(world.tick, 1, 0, 0, 0, SimCommand.PRESSED_ACTIVE_1, 1000, 0)]), "legacy E cooldown refusal world step")
	equal(state.flux, before, "E on cooldown cannot spend")
	state.set_spell_cooldown(alias, 0)
	check(world.step([SimCommand.new(world.tick, 1, 0, 0, 0, SimCommand.PRESSED_ACTIVE_1, 1000, 0)]), "legacy E outside twelve still uses real paid command")
	equal(state.flux, before - int(CombatTuning.cast_definition(alias).flux_cost), "dedicated mouse melee never changes E spell payment")
	state.set_spell_cooldown(alias, 19)
	var reordered := state.spell_wire_ids.duplicate()
	reordered.reverse()
	check(CharacterWeavePolicy.apply(state, reordered), "whole weave applies alongside absent alias")
	equal(state.spell_cooldown_for_wire(alias), 19, "starter application preserves absent alias cooldown")
	check(state.place_proven_spell(5, alias), "alias can be placed in a free position")
	equal(state.spell_cooldown_ticks[5], 19, "placing E shares its existing cooldown")


func _test_whole_request() -> void:
	var actor := PlayerState.new()
	var wires := Array(actor.spell_wire_ids)
	var packet := {"kind": SessionTransport.PACKET_REQUEST, "sequence": 1, "action": SessionTransport.REQUEST_WEAVE_APPLY, "value": 1, "expected": wires.duplicate(), "wires": wires.duplicate()}
	check(SessionTransport._valid_request_packet(packet), "bounded whole weave packet validates")
	var malformed := packet.duplicate(true)
	malformed.wires[1] = malformed.wires[0]
	check(not SessionTransport._valid_request_packet(malformed), "duplicate requested spell refuses atomically")
	malformed = packet.duplicate(true)
	malformed.expected[0] = 1.5
	check(not SessionTransport._valid_request_packet(malformed), "fractional wire refuses before truncation")
	malformed = packet.duplicate(true)
	malformed.wires.pop_back()
	check(not SessionTransport._valid_request_packet(malformed), "partial whole weave refuses")
	malformed = packet.duplicate(true)
	malformed.action = SessionTransport.REQUEST_CHAMPION_SELECT
	check(not SessionTransport._valid_request_packet(malformed), "old action cannot carry a hidden weave payload")


func _test_session_memory(champions: ChampionCatalog, abilities: AbilityCatalog) -> void:
	var memory := CharacterWeaveCoordinator.new()
	var store := "user://s4-empty-session-memory.json"
	check(not FileAccess.file_exists(store), "isolated memory fixture begins without a user library")
	check(memory.configure(champions, abilities, false, store), "missing library initializes recommended kits in memory")
	var ids := champions.ordered_champion_ids()
	var state := PlayerState.new()
	champions.apply_to_player(state, ids[0])
	var custom := state.spell_wire_ids.duplicate()
	custom.reverse()
	check(CharacterWeavePolicy.apply(state, custom), "first character accepts custom weave")
	check(memory.save_local(state, CharacterWeaveLibrary.MODE_CUSTOM), "confirmed custom remembered without disk fixture writes")
	champions.apply_to_player(state, ids[1])
	check(memory.restore_actor(state, true), "switching character restores its own weave")
	check(state.spell_wire_ids != custom, "second character does not inherit first custom")
	champions.apply_to_player(state, ids[0])
	check(memory.restore_actor(state, true), "switch back restores first custom")
	equal(state.spell_wire_ids, custom, "custom weave survives character switching")
	check(not FileAccess.file_exists(store), "configuration and transient saves leave no profile file")


func _test_failed_save_keeps_accepted_session_weave(champions: ChampionCatalog, abilities: AbilityCatalog) -> void:
	var memory := CharacterWeaveCoordinator.new()
	memory.library = FailedSaveLibrary.new()
	var store := "user://weave-failed-save-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(not FileAccess.file_exists(store), "failed-save fixture never touches an existing user library")
	check(memory.configure(champions, abilities, true, store), "failed-save fixture loads canonical in-memory starters")
	var ids := champions.ordered_champion_ids()
	var state := PlayerState.new()
	check(champions.apply_to_player(state, ids[0]), "failed-save fixture equips its original character")
	var saved_before := memory.library.to_dictionary()
	var accepted := state.spell_wire_ids.duplicate()
	accepted.reverse()
	check(CharacterWeavePolicy.apply(state, accepted), "authority accepts a valid custom weave before persistence")
	var authority_before_save := state.canonical_values()
	check(not memory.save_local(state, CharacterWeaveLibrary.MODE_CUSTOM), "persistent write failure is explicitly reported")
	equal(state.canonical_values(), authority_before_save, "failed persistence cannot undo host-accepted actor authority")
	equal(memory.library.to_dictionary(), saved_before, "failed persistence restores prior saved-library memory")
	equal(memory.preferred_weave(state, true), accepted, "accepted weave remains preferred for this session after disk failure")
	check(not memory.last_error.is_empty(), "failed persistence keeps an actionable error")
	check(champions.apply_to_player(state, ids[1]) and memory.restore_actor(state, true), "another character remains usable after disk failure")
	check(champions.apply_to_player(state, ids[0]) and memory.restore_actor(state, true), "returning character restores accepted session weave despite disk failure")
	equal(state.spell_wire_ids, accepted, "failed save does not lose the accepted weave during character switching")
	check(not FileAccess.file_exists(store), "failed-save test creates no profile file")
