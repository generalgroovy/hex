extends FluxTestSuite


const Practice = preload("res://src/sim/combat/interception_practice.gd")
const Card = preload("res://src/presentation/interception_practice_card.gd")
const ABILITY_PATH := "res://content/abilities/foundation_abilities_v1.json"
const CHAMPION_PATH := "res://content/champions/foundation_champions_v1.json"
var abilities := AbilityCatalog.new()
var champions := ChampionCatalog.new()
var campus := SanctumCampusLayout.new()


func run() -> int:
	check(abilities.load_from_file(ABILITY_PATH), "interception practice loads the current ability catalog")
	check(champions.load_from_file(CHAMPION_PATH, abilities), "interception practice loads the current champion catalog")
	check(campus.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "interception practice loads the current Wellspring court")
	_test_profiles_and_spawns()
	_test_timeline_and_commands()
	_test_card_contract()
	_test_real_paid_opponent_cast()
	return finish("interception-practice")


func _test_profiles_and_spawns() -> void:
	var spawn := Practice.spawn_contract(campus)
	check(not spawn.is_empty(), "practice binds only the reviewed existing Duel Court anchors")
	equal(spawn.player_spawn_px, Practice.PLAYER_SPAWN_PX, "player uses the quiet west-center authored arena spawn")
	equal(spawn.opponent_spawn_px, Practice.OPPONENT_SPAWN_PX, "opponent uses the quiet east-center authored arena spawn")
	var collision := campus.build_collision_world()
	check(collision.can_occupy(spawn.player_spawn_fixed, MovementTuning.PLAYER_RADIUS), "player anchor has current movement clearance")
	check(collision.can_occupy(spawn.opponent_spawn_fixed, MovementTuning.PLAYER_RADIUS), "opponent anchor has current movement clearance")

	var player := Practice.player_profile(abilities)
	var opponent := Practice.opponent_profile(abilities)
	equal(player.champion_id, "s_wayne", "the small player identity reuses S. Wayne")
	equal(opponent.champion_id, "oh_tipi", "the middle opponent identity reuses Oh Tipi")
	for role: String in ["water_spray", "earth_spray", "fire_bolt", "fire_rapid"]:
		_assert_spell(player, role)
	for role: String in ["rapid", "bolt", "heavy"]:
		_assert_spell(opponent, role)
	equal(int(abilities.ability_from_wire(int(player.wires.water_spray)).reaction_strength), 3, "Water Spray retains catalog strength 3")
	equal(int(abilities.ability_from_wire(int(player.wires.earth_spray)).reaction_strength), 3, "Earth Spray retains matching catalog strength 3")
	equal(AbilityCatalog._spell_family(abilities.ability_from_wire(int(opponent.wires.rapid))), "rapid", "opponent weak shot is the real Rapid family")
	equal(AbilityCatalog._spell_family(abilities.ability_from_wire(int(opponent.wires.bolt))), "bolt", "opponent stronger read is the real Bolt family")
	equal(AbilityCatalog._spell_family(abilities.ability_from_wire(int(opponent.wires.heavy))), "heavy", "opponent final read is the real Heavy family")
	check(int(abilities.ability_from_wire(int(opponent.wires.rapid)).reaction_strength) < int(abilities.ability_from_wire(int(player.wires.water_spray)).reaction_strength), "paid Spray is stronger than the Rapid lesson")
	check(int(abilities.ability_from_wire(int(opponent.wires.bolt)).reaction_strength) > int(abilities.ability_from_wire(int(player.wires.water_spray)).reaction_strength), "Bolt truthfully overpowers Spray")
	check(int(abilities.ability_from_wire(int(opponent.wires.heavy)).reaction_strength) > int(abilities.ability_from_wire(int(player.wires.water_spray)).reaction_strength), "Heavy truthfully overpowers Spray")


func _assert_spell(profile: Dictionary, role: String) -> void:
	var wire := int((profile.get("wires", {}) as Dictionary).get(role, 0))
	var definition := abilities.ability_from_wire(wire)
	check(wire > 0 and not definition.is_empty(), "%s resolves through the current catalog" % role)
	check(String(definition.get("runtime_status", "")) == "playable" and int(definition.get("flux_cost", 0)) > 0, "%s is a playable positive-cost spell" % role)


func _actors() -> Array[PlayerState]:
	var player := PlayerState.new(1)
	var opponent := PlayerState.new(2)
	player.position_x = Practice.PLAYER_SPAWN_PX.x * SimConfig.FIXED_SCALE
	player.position_y = Practice.PLAYER_SPAWN_PX.y * SimConfig.FIXED_SCALE
	opponent.position_x = Practice.OPPONENT_SPAWN_PX.x * SimConfig.FIXED_SCALE
	opponent.position_y = Practice.OPPONENT_SPAWN_PX.y * SimConfig.FIXED_SCALE
	return [player, opponent]


func _test_timeline_and_commands() -> void:
	equal(Practice.DURATION_TICKS, 72 * SimConfig.TICK_RATE, "circuit lasts exactly 72 seconds at the one supported tick rate")
	var transitions := [
		[0, Practice.PHASE_READY],
		[Practice.READY_END, Practice.PHASE_RAPID_SINGLE],
		[Practice.RAPID_SINGLE_END, Practice.PHASE_MUD_BREAK],
		[Practice.MUD_BREAK_END, Practice.PHASE_RAPID_PRESSURE],
		[Practice.RAPID_PRESSURE_END, Practice.PHASE_STRONGER_WARNING],
		[Practice.STRONGER_WARNING_END, Practice.PHASE_BOLT_READ],
		[Practice.BOLT_READ_END, Practice.PHASE_RECENTER],
		[Practice.RECENTER_END, Practice.PHASE_FINAL_MIX],
		[Practice.FINAL_MIX_END, Practice.PHASE_CLEAR],
		[Practice.DURATION_TICKS, Practice.PHASE_COMPLETE],
	]
	for transition: Array in transitions:
		equal(Practice.status(int(transition[0]), 0).phase, transition[1], "phase boundary is deterministic at tick %d" % int(transition[0]))
	check(Practice.status(99, 100).is_empty(), "pre-start tick cannot create an opponent command")
	equal(Practice.retry_start_tick(9301), 9301, "retry uses caller-owned current authority tick without hidden state")

	var actors := _actors()
	var slots: Dictionary = Practice.opponent_profile(abilities).slots
	var before_player := actors[0].canonical_values()
	var before_opponent := actors[1].canonical_values()
	var first := Practice.command_for_tick(Practice.READY_END + 120, 0, actors[1], actors[0], slots)
	var second := Practice.command_for_tick(Practice.READY_END + 120, 0, actors[1], actors[0], slots)
	check(first != null and first.canonical_bytes() == second.canonical_bytes(), "same tick and observed actors produce the same ordinary command")
	equal(Vector2i(first.aim_target_x, first.aim_target_y), Vector2i(actors[0].position_x, actors[0].position_y), "opponent aims at the player's current authoritative point")
	equal(first.first_held_spell_slot(), int(slots.rapid), "first release window holds the equipped Rapid slot")
	equal(first.first_pressed_spell_slot(), 0, "Rapid window does not manufacture another cast edge")
	equal(actors[0].canonical_values(), before_player, "command generation cannot mutate the player")
	equal(actors[1].canonical_values(), before_opponent, "command generation cannot mutate the opponent")
	check(Practice.command_for_tick(0, 0, actors[1], actors[0], {"rapid":1,"bolt":1,"heavy":2}) == null, "overlapping slot contract fails closed")

	var rapid_ticks := 0
	var bolt_edges := 0
	var heavy_edges := 0
	for tick: int in range(Practice.DURATION_TICKS):
		var command := Practice.command_for_tick(tick, 0, actors[1], actors[0], slots)
		rapid_ticks += int(command.first_held_spell_slot() == int(slots.rapid))
		bolt_edges += int(command.first_pressed_spell_slot() == int(slots.bolt))
		heavy_edges += int(command.first_pressed_spell_slot() == int(slots.heavy))
	equal(rapid_ticks, 1176, "bounded schedule contains finite Rapid pressure and pauses")
	equal(bolt_edges, 5, "four isolated Bolt reads and one final Bolt are edge-triggered")
	equal(heavy_edges, 1, "one explicitly telegraphed Heavy closes the mixed read")
	for quiet_tick: int in [Practice.RAPID_SINGLE_END, Practice.RAPID_PRESSURE_END, Practice.BOLT_READ_END, Practice.FINAL_MIX_END]:
		var quiet := Practice.command_for_tick(quiet_tick, 0, actors[1], actors[0], slots)
		equal(quiet.first_held_spell_slot(), 0, "pressure break has no held cast at tick %d" % quiet_tick)
		equal(quiet.first_pressed_spell_slot(), 0, "pressure break has no cast edge at tick %d" % quiet_tick)


func _test_card_contract() -> void:
	var player := Practice.player_profile(abilities)
	var opponent := Practice.opponent_profile(abilities)
	var rapid := Card.view(Practice.READY_END, 0, player, opponent)
	check(String(rapid.lines[0]).contains("SMALL SHOT INCOMING") and String(rapid.lines[0]).contains("Spray"), "first live instruction gives the weak-shot response in player language")
	var mud := Card.view(Practice.RAPID_SINGLE_END, 0, player, opponent)
	equal(mud.title, "PRESSURE BREAK · MAKE MUD", "first recovery window exposes the chemistry experiment")
	equal(String(mud.lines[0]), "Water Spray then Earth Spray at the same spot makes Mud.", "Mud prompt describes the two-step ground experiment")
	equal(mud.slot_hints, PackedStringArray(["1  Tideline", "2  Shard Gale"]), "card exposes concise source-derived slot hints for binding labels")
	check(String(mud.lines[1]).contains("recover Flux") and String(mud.lines[1]).contains("change position"), "Mud break cues recovery and repositioning")
	var stronger := Card.view(Practice.RAPID_PRESSURE_END, 0, player, opponent)
	equal(String(stronger.lines[0]), "Catch small shots with Spray. Dodge the larger ones.", "pressure break teaches the readable size response")
	var heavy := Card.view(Practice.RECENTER_END + 400, 0, player, opponent)
	equal(heavy.telegraph, "heavy", "final Heavy warning begins before its one cast edge")
	check(String(heavy.lines[0]).contains("HEAVY WARNING") and String(heavy.lines[0]).contains("cover"), "Heavy card gives the non-Spray response")
	var complete := Card.view(Practice.DURATION_TICKS, 0, player, opponent)
	check(bool(complete.complete) and complete.action == "retry" and String(complete.lines[0]).contains("Try again") and String(complete.lines[0]).contains("experiment with Mud"), "completion exposes an obvious improvement-focused retry")


func _test_real_paid_opponent_cast() -> void:
	var spawn := Practice.spawn_contract(campus)
	var world := SimWorld.new(120, 9401, campus.build_collision_world(), String(campus.data.get("id", "")), campus.content_hash)
	var player := world.player()
	check(champions.apply_to_player(player, Practice.PLAYER_CHAMPION_ID), "real practice player applies the reused champion")
	var opponent := PlayerState.new(2)
	check(champions.apply_to_player(opponent, Practice.OPPONENT_CHAMPION_ID), "real practice opponent applies the reused champion")
	player.team_id = 1
	opponent.team_id = 2
	player.position_x = spawn.player_spawn_fixed.x
	player.position_y = spawn.player_spawn_fixed.y
	opponent.position_x = spawn.opponent_spawn_fixed.x
	opponent.position_y = spawn.opponent_spawn_fixed.y
	var profile := Practice.opponent_profile(abilities)
	for role: String in ["rapid", "bolt", "heavy"]:
		check(opponent.place_proven_spell(int(profile.slots[role]) - 1, int(profile.wires[role])), "root-style setup equips real %s" % role)
	world.players.append(opponent)
	var starting_flux := opponent.flux
	var paid_rapid := 0
	var released_rapid := 0
	while world.tick < Practice.READY_END + 220:
		var player_command := SimCommand.new(world.tick, player.entity_id, 0, 0, 0, 0, player.aim_x, player.aim_y)
		var opponent_command := Practice.command_for_tick(world.tick, 0, opponent, player, profile.slots)
		check(world.step([player_command, opponent_command]), "ordinary world step accepts the deterministic practice commands")
		for event: Dictionary in world.combat_events:
			if int(event.get("entity_id", event.get("owner_id", 0))) == opponent.entity_id and int(event.get("wire_id", event.get("source_wire_id", 0))) == int(profile.wires.rapid):
				paid_rapid += int(String(event.get("type", "")) == "cast_started")
				released_rapid += int(String(event.get("type", "")) == "projectile_spawned")
	check(paid_rapid > 0 and released_rapid > 0, "opponent pressure comes from real paid Rapid startups and releases")
	check(opponent.flux < starting_flux, "practice generator never refills the opponent after paid casts")
	check(world.next_projectile_id > 1, "projectiles arise only through ordinary combat allocation")
