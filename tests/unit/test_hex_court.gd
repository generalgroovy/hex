extends FluxTestSuite

func run() -> int:
	var world := SimWorld.new(120, 19, CollisionWorld.new(1_280_000, 960_000))
	world.hex_court = HexCourt.new()
	var court: HexCourt = world.hex_court
	equal(court.cells.size(), 469, "radius-twelve fine-grid court retains its approximate world-space footprint")
	var state := world.player()
	state.position_x = 640_000
	state.position_y = 480_000
	check(not state.place_proven_spell(0, 101), "retired Charge cannot enter the preparation weave")
	check(state.place_proven_spell(0, 145), "paid baseline Fire Bolt equips")
	var before := state.flux
	check(world.step([SimCommand.new(world.tick, 1, 1000, 0, 0, SimCommand.PRESSED_SPELL_1, 0, 1000)]), "preparation court steps continuous movement with independent aim")
	equal(state.flux, before, "H1 unavailable chemistry refuses without payment")
	equal(state.pending_cast_wire_id, 0, "unavailable chemistry cannot start a pending cast")
	for index: int in range(24):
		check(world.step([SimCommand.new(world.tick, 1, 1000, 0, 0, 0, 0, 1000)]), "court continuous movement advances")
	check(state.position_x > 640_000 and state.position_x % 32_000 != 0, "actor movement does not snap to hex centers")
	equal(Vector2i(state.aim_x, state.aim_y), Vector2i(0, 1000), "eight-way aim stays independent of east travel")
	equal(world.deposits.size() + world.reactions.size(), 0, "court has no duplicate old chemistry authority")
	check(SessionSnapshot.capture(world, {}).is_empty(), "solo court refuses incomplete legacy snapshot")
	var dry_hash := world.state_hash()
	court.cells[Vector2i.ZERO].structure = 7
	check(world.state_hash() != dry_hash, "cell structural layer belongs to authority hash")
	equal(court.cells[Vector2i.ZERO].get("water", {}).size(), 0, "structure does not overwrite independent ground layer")
	return finish("hex-court")
