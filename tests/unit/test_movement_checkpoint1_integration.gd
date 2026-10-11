extends FluxTestSuite

const NEW_FIELDS: Array[StringName] = [&"flight_capable", &"jumpsquat_active", &"jumpsquat_ticks", &"double_jump_used", &"wallrun_armed", &"crouching"]

func run() -> int:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "abilities load")
	var catalog := ChampionCatalog.new()
	check(catalog.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "champions load")
	for champion_id: String in catalog.ordered_champion_ids():
		var actor := PlayerState.new(2)
		check(catalog.apply_to_player(actor, champion_id), "apply " + champion_id)
		equal(actor.flight_capable, String(catalog.champion(champion_id).ancestry) in ["sylph", "wyrmborn", "angel", "demon"], "ancestry owns flight: " + champion_id)
		actor.double_jump_used = true
		actor.float_used = true
		check(catalog.apply_to_player(actor, champion_id, true), "reattune " + champion_id)
		check(actor.double_jump_used and actor.float_used, "reattunement cannot refill airborne allowance")
	_test_replication(abilities)
	_test_gather_snapshot_continuation(abilities, catalog)
	_test_slide_carry_snapshot_continuation(abilities, catalog)
	_test_input_cancel()
	_test_projectile_matrix()
	return finish("movement-checkpoint1-integration")

func _test_replication(abilities: AbilityCatalog) -> void:
	var world := SimWorld.new()
	check(HexCourtPractice.configure(world, abilities, false), "small hex authority fixture")
	var actor := world.player()
	actor.champion_wire_id = 1
	actor.flight_capable = true
	actor.jumpsquat_active = true
	actor.jumpsquat_ticks = 25
	actor.double_jump_used = true
	actor.wallrun_armed = false
	actor.crouching = false
	var frozen := actor.canonical_values()
	var snapshot := HexWorldSnapshot.capture(world)
	check(not snapshot.is_empty(), "new scalar fields capture")
	if snapshot.is_empty(): return
	var restored := HexWorldSnapshot.prepare(snapshot, world)
	check(restored != null, "full authority restores new schema")
	if restored != null:
		equal(restored.player().canonical_values(), frozen, "new fields survive complete authority roundtrip")
	# The legacy presentation envelope deliberately refuses unified hex worlds.
	# Test its scalar compatibility using its supported non-hex fixture.
	var legacy := SimWorld.new()
	legacy.players[0] = actor
	var compact := SessionSnapshot.capture(legacy, {}, [])
	check(SessionSnapshot.validate(compact), "presentation snapshot accepts new fields")
	var displayed := SimWorld.new()
	check(SessionSnapshot.apply_to_world(compact, displayed), "presentation snapshot restores")
	for field: StringName in NEW_FIELDS:
		equal(displayed.player().get(field), actor.get(field), "remote presentation field " + String(field))
	actor.entity_id = 2
	var packet := ClientPrediction.capture_packet(actor, 1, 0)
	check(ClientPrediction.validate_packet(packet), "prediction accepts movement state")
	var predicted := ClientPrediction.restore_state(packet.values)
	for field: StringName in NEW_FIELDS:
		equal(predicted.get(field), actor.get(field), "prediction field " + String(field))
	var invalid: PackedInt64Array = packet.values.duplicate()
	invalid[ClientPrediction.STATE_FIELDS.find(&"jumpsquat_ticks")] = 100000
	check(not ClientPrediction.validate_values(invalid), "overlong squat rejected at network boundary")

func _test_gather_snapshot_continuation(abilities: AbilityCatalog, catalog: ChampionCatalog) -> void:
	var selected: Dictionary = {}
	for champion_id: String in catalog.ordered_champion_ids():
		var body := String(catalog.champions_by_id[champion_id]["body_type"])
		if not selected.has(body): selected[body] = champion_id
	equal(selected.size(), 3, "gather snapshots cover all three actual body profiles")
	for body: String in selected:
		for from_slide: bool in [false, true]:
			var world := SimWorld.new(120, 719)
			check(HexCourtPractice.configure(world, abilities, false), "gather continuation uses full paid hex authority")
			check(catalog.apply_to_player(world.player(), String(selected[body])), "gather snapshot applies actual catalog profile")
			var actor := world.player()
			actor.position_x = 640_000
			actor.position_y = 710_000
			actor.velocity_x = 459_550
			actor.velocity_y = 459_550
			var replica: SimWorld = null
			for tick: int in range(44):
				var held := SimCommand.HELD_SLIDE if from_slide and tick < 6 else SimCommand.HELD_JUMP if tick < 24 else 0
				var pressed := SimCommand.PRESSED_SLIDE if from_slide and tick == 0 else SimCommand.PRESSED_JUMP if tick == (6 if from_slide else 0) else 0
				var aim: Vector2i = EightDirectionResolver.FIXED_VECTORS[(tick / 8) % 8]
				var command := SimCommand.new(tick, 1, 0, 0, held, pressed, aim.x, aim.y)
				check(world.step([command]), "full authority advances actual gather and release commands")
				if replica != null:
					check(replica.step([command.copy()]), "restored gather advances identical command")
					equal(replica.player().canonical_values(), actor.canonical_values(), "moving gather snapshot continues every actor scalar exactly")
					equal(replica.state_hash(), world.state_hash(), "gather continuation preserves full authoritative hash")
				if tick in [12, 25]:
					check(actor.velocity_x > 0 and actor.velocity_y > 0, "captured gather/release retains real diagonal momentum")
					equal(actor.jumpsquat_active, tick == 12, "snapshot distinguishes held gathering and paid release")
					var packet := HexWorldSnapshot.capture(world)
					check(not packet.is_empty(), "moving gather and release fit existing complete snapshot")
					replica = HexWorldSnapshot.prepare(packet, world)
					check(replica != null, "moving gather and release restore without schema changes")
					if replica != null:
						equal(replica.state_hash(), world.state_hash(), "each full momentum snapshot restores exact authority")


func _test_slide_carry_snapshot_continuation(abilities: AbilityCatalog, catalog: ChampionCatalog) -> void:
	for champion_id: String in ["s_wayne", "spai_si", "fluup"]:
		var world := SimWorld.new(120, 723)
		check(HexCourtPractice.configure(world, abilities, false), "slide continuation uses paid hex authority")
		check(catalog.apply_to_player(world.player(), champion_id), "slide continuation applies actual profile " + champion_id)
		var actor := world.player()
		actor.position_x = 640_000
		actor.position_y = 710_000
		actor.velocity_x = 594_000 * actor.movement_speed_ratio / 1000
		actor.velocity_y = 0
		var replica: SimWorld = null
		for tick: int in range(80):
			var move := Vector2i(0, -1000) if tick >= 6 and tick < 14 else Vector2i(-1000, 0) if tick >= 14 and tick < 18 else Vector2i.ZERO
			var held := SimCommand.HELD_SLIDE if tick < 24 else 0
			var pressed := SimCommand.PRESSED_SLIDE if tick == 0 else 0
			var aim: Vector2i = EightDirectionResolver.FIXED_VECTORS[(tick / 7) % 8]
			var command := SimCommand.new(tick, 1, move.x, move.y, held, pressed, aim.x, aim.y)
			check(world.step([command]), "slide continuation advances actual carve/brake/release input")
			if replica != null:
				check(replica.step([command.copy()]), "restored slide advances the same input")
				equal(replica.player().canonical_values(), actor.canonical_values(), "snapshot preserves each revised slide and ground-carry scalar exactly")
				equal(replica.state_hash(), world.state_hash(), "slide carry preserves full authoritative continuation hash")
			if tick in [10, 20, 43]:
				var packet := HexWorldSnapshot.capture(world)
				check(not packet.is_empty(), "carve, brake and ordinary exit fit the existing full snapshot schema")
				replica = HexWorldSnapshot.prepare(packet, world)
				check(replica != null, "slide snapshot restores without new replicated fields")
				if replica != null:
					equal(replica.state_hash(), world.state_hash(), "each slide snapshot restores the exact authoritative state")


func _test_input_cancel() -> void:
	var router := InputRouter.new(1)
	var state := PlayerState.new()
	state.jumpsquat_active = true
	state.jumpsquat_ticks = 20
	state.jump_held_last_tick = true
	router.discard_transient_movement_input()
	var command := router.sample(0, Vector2(160, 360), Vector2(260, 360))
	check(command.has_pressed(SimCommand.PRESSED_CANCEL_MOVEMENT), "modal quarantine emits cancellation instead of release")
	MovementSystem.step(state, command, SimConfig.new(), CollisionWorld.new())
	check(not state.jumpsquat_active and state.air_vertical_velocity == 0, "menu/focus cancellation cannot launch")
	check(not router.sample(1, Vector2.ZERO, Vector2.RIGHT).has_pressed(SimCommand.PRESSED_CANCEL_MOVEMENT), "cancellation edge consumed once")
	var bootstrap := preload("res://src/app/bootstrap.gd").new()
	bootstrap.input_router = router
	var blocked := bootstrap._sample_gameplay_command(2, Vector2.ZERO, Vector2.RIGHT, true)
	check(blocked.has_pressed(SimCommand.PRESSED_CANCEL_MOVEMENT), "blocked bootstrap delivers cancellation immediately")
	check(not router.movement_cancel_pending, "already delivered cancellation cannot eat first fresh action after guard")
	bootstrap.free()

func _test_projectile_matrix() -> void:
	var shot := ProjectileState.new(1000, 1, 1, CombatTuning.RILLSHOT_WIRE_ID, 3, Vector2i.ZERO, Vector2i(1000, 0), 1000, 1000, 120)
	var actor := PlayerState.new(2)
	actor.team_id = 2
	var config := SimConfig.new()
	check(HexProjectileCombat._eligible(shot, actor, config), "standing vulnerable")
	actor.crouching = true
	check(not HexProjectileCombat._eligible(shot, actor, config), "crouching below ordinary projectile")
	actor.crouching = false
	actor.slide_ticks = 30
	check(not HexProjectileCombat._eligible(shot, actor, config), "sliding below ordinary projectile")
	actor.slide_ticks = 0
	actor.air_height = MovementTuning.GROUND_PROJECTILE_CLEARANCE_HEIGHT - 1
	check(HexProjectileCombat._eligible(shot, actor, config), "takeoff below threshold remains vulnerable")
	actor.air_height += 1
	check(not HexProjectileCombat._eligible(shot, actor, config), "airborne clears ordinary projectile")
	actor.wall_skim_ticks = 30
	check(HexProjectileCombat._eligible(shot, actor, config), "wallrun explicitly exposed despite rendered height")
