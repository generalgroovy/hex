extends FluxTestSuite


const TIDE_SHELL_WIRE_ID: int = 181


func run() -> int:
	_test_supported_tick_rates()
	_test_command_serialization()
	_test_independent_aim()
	_test_actor_kind_is_canonical()
	_test_command_validation()
	_test_post_cast_owner_capacity()
	return finish("core")


func _test_supported_tick_rates() -> void:
	equal(SimConfig.PROTOCOL_VERSION, 61, "same-step defeated pending cleanup has an explicit protocol boundary")
	check(not SimConfig.new(60).is_valid(), "retired 60 Hz cadence fails closed")
	check(SimConfig.new(120).is_valid(), "120 Hz is the sole supported cadence")
	check(not SimConfig.new(90).is_valid(), "intermediate tick rates fail closed")
	equal(SimConfig.new(120).milliseconds_to_ticks(85), 11, "120 Hz duration rounds upward")


func _test_command_serialization() -> void:
	var command := SimCommand.new(7, 3, -1000, 1000, SimCommand.HELD_SPRINT, SimCommand.PRESSED_JUMP, 300, -400)
	command.aim_target_x = 1_234_567
	command.aim_target_y = 7_654_321
	var copy: SimCommand = command.copy()
	equal(command.canonical_bytes(), copy.canonical_bytes(), "command bytes are stable across copies")
	equal(command.canonical_bytes().size(), 80, "command retains ten fixed-width int64 values including locked target")
	equal(Vector2i(copy.aim_target_x, copy.aim_target_y), Vector2i(1_234_567, 7_654_321), "canonical command copy retains the exact locked world endpoint")
	equal(Vector2i(command.aim_x, command.aim_y), Vector2i(600, -800), "aim is deterministically quantized to scale 1000")
	var spell_command := SimCommand.new(8, 3, 0, 0, 0, SimCommand.PRESSED_SPELL_4 | SimCommand.PRESSED_SPELL_2)
	equal(spell_command.first_pressed_spell_slot(), 2, "lowest requested spell slot wins deterministically")
	equal(spell_command.copy().first_pressed_spell_slot(), 2, "spell slot bits survive command copies")
	equal(SimCommand.new(9, 3).first_pressed_spell_slot(), 0, "command with no spell slot reports none")
	equal(SimCommand.new(10, 3, 0, 0, 0, SimCommand.PRESSED_SPELL_12).first_pressed_spell_slot(), 12, "Alt+4 occupies the bounded final command bit")


func _test_independent_aim() -> void:
	var world := SimWorld.new(120)
	var command := SimCommand.new(0, 1, 1000, 0, SimCommand.HELD_PRIMARY, 0, 0, -1000)
	check(world.step([command]), "independent-aim command steps")
	var state: PlayerState = world.player()
	equal(Vector2i(state.facing_x, state.facing_y), Vector2i(1000, 0), "movement facing follows movement")
	equal(Vector2i(state.aim_x, state.aim_y), Vector2i(0, -1000), "aim remains independent from movement")
	check(state.primary_held, "primary action is represented in canonical player state")


func _test_command_validation() -> void:
	var world := SimWorld.new(120)
	equal(world.state_hash().length(), 64, "world state uses a SHA-256 compatibility hash")
	check(not world.step([SimCommand.new(1, 1)]), "future command tick is rejected")
	check(world.last_error.contains("does not match"), "tick rejection is diagnosable")


func _test_actor_kind_is_canonical() -> void:
	var champion_world := SimWorld.new(120)
	var target_world := SimWorld.new(120)
	target_world.player().actor_kind = PlayerState.ActorKind.TRAINING_TARGET
	check(champion_world.state_hash() != target_world.state_hash(), "champion and practice-target actor kinds hash differently")


func _test_post_cast_owner_capacity() -> void:
	var world := SimWorld.new(120)
	_check_owner_capacity(world,"offline owner")
	world.players.clear()
	_check_owner_capacity(world,"empty world")
	world.players.append(PlayerState.new(1))
	world.players.append(PlayerState.new(2))
	world.players[0].pending_cast_wire_id = CombatTuning.CINDERFAN_WIRE_ID
	check(CombatTuning.cast_definition(CombatTuning.CINDERFAN_WIRE_ID).is_empty(), "retired Wave has no authoritative cast definition")
	_check_owner_capacity(world,"retired pending Wave reserves no runtime lanes")
	equal(world._owner_material_slots()[1],16,"retired pending Wave cannot consume authority capacity")
	world.players[0].pending_cast_wire_id = TIDE_SHELL_WIRE_ID
	world.players[1].pending_cast_wire_id = TIDE_SHELL_WIRE_ID
	world.players[1].health = 0
	_check_owner_capacity(world,"living Heavy reserves one; dead Heavy reserves none")
	equal(world._owner_material_slots()[1],15,"pending Heavy reserves one owner slot")
	for index: int in range(127):
		world.projectiles.append(ProjectileState.new(1000+index,999,1,145,2,Vector2i(100000,100000),Vector2i(1000,0),10800,9000,120))
	_check_owner_capacity(world,"orphan material still fills global capacity")
	equal(world._owner_material_slots()[1],0,"127 orphan projectiles plus one pending lane fill the global cap")
	world.projectiles.pop_back()
	_check_owner_capacity(world,"one global slot remains")
	equal(world._owner_material_slots()[1],1,"single-lane Heavy reservation leaves exactly one global slot")
	world.players.reverse()
	world.projectiles.reverse()
	_check_owner_capacity(world,"reordered owners and material")
	world.projectiles.clear()
	for index: int in range(16):
		var deposit := ElementDepositState.new()
		deposit.entity_id = 3000+index
		deposit.owner_id = 2
		world.deposits.append(deposit)
	_check_owner_capacity(world,"owner deposit ceiling includes defeated owners")
	equal(world._owner_material_slots()[2],0,"sixteen deposits exhaust that owner's material slots")
	equal(world._owner_material_slots()[1],15,"other owner's deposit ceiling does not consume these owner slots")


func _check_owner_capacity(world: SimWorld,label: String) -> void:
	var before := world.state_hash()
	var expected := {}
	for actor: PlayerState in world.players:
		expected[actor.entity_id] = world.available_cast_capacity(actor.entity_id).x
	var actual := world._owner_material_slots()
	equal(actual,expected,label+": batch matches unchanged sequential query")
	equal(actual.keys(),expected.keys(),label+": requested-owner insertion order is preserved")
	equal(world.state_hash(),before,label+": capacity reads never change canonical state")
