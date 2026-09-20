extends FluxTestSuite

func run() -> int:
	_test_paid_world_and_modal_debt()
	_test_snapshot_and_reconciliation()
	_test_round_score()
	return finish("physical-integration")

func _world() -> SimWorld:
	var world := SimWorld.new(120, 9, CollisionWorld.new(1_280_000, 960_000))
	world.player().position_x = 300_000
	world.player().position_y = 480_000
	world.player().champion_wire_id = 1
	world.player().stamina_recovery_per_second = 0
	world.player().flux_recovery_per_second = 0
	return world

func _step(world: SimWorld, pressed: int = 0, held: int = 0) -> void:
	check(world.step([SimCommand.new(world.tick, 1, 0, 0, held, pressed, 1000, 0)]), "real authority step: " + world.last_error)

func _test_paid_world_and_modal_debt() -> void:
	var world := _world()
	var actor := world.player()
	var stamina := actor.stamina
	var flux := actor.flux
	_step(world, SimCommand.PRESSED_PUNCH | SimCommand.PRESSED_KICK | SimCommand.PRESSED_SPELL_1, SimCommand.HELD_PRIMARY)
	equal(actor.physical_kind, 1, "same-tick buttons buy Punch once")
	equal(actor.stamina, stamina - 14_000, "accepted physical start pays once")
	equal(actor.flux, flux, "same-tick spell selection cannot also buy ranged attack")
	equal(actor.pending_cast_wire_id, 0, "melee and pending ranged cast cannot coexist")
	_step(world, SimCommand.PRESSED_MODAL_CANCEL)
	equal([actor.physical_phase, actor.physical_buffer_kind, actor.physical_recovery_lock_ticks], [0, 0, 16], "opening a modal cancels attack and preserves recovery debt")
	_step(world, SimCommand.PRESSED_MODAL_CANCEL)
	equal(actor.physical_recovery_lock_ticks, 15, "a second modal command cannot erase recovery debt")
	equal(actor.stamina, stamina - 14_000, "paid whiff/modal cancellation does not refund")
	actor.health = 0
	actor.physical_buffer_kind = 2
	actor.physical_buffer_ticks = 5
	actor.knockback_guard_ticks = 48
	_step(world)
	equal([actor.physical_phase, actor.physical_buffer_kind, actor.physical_recovery_lock_ticks, actor.knockback_guard_ticks], [0, 0, 0, 0], "dead branch clears delayed physical state and guard")
	world = _world()
	actor = world.player()
	_step(world, SimCommand.PRESSED_SPELL_1)
	check(actor.pending_cast_wire_id > 0, "real paid cast starts before the physical request")
	stamina = actor.stamina
	_step(world, SimCommand.PRESSED_KICK)
	equal(actor.physical_phase, 0, "pending ranged cast refuses simultaneous physical start")
	equal(actor.stamina, stamina, "busy refusal makes no Stamina spend")

func _test_snapshot_and_reconciliation() -> void:
	var world := _world()
	_step(world, SimCommand.PRESSED_KICK)
	var actor := world.player()
	# Codec fixture deliberately carries a target ID above the lobby ID range.
	actor.physical_hit_ids = PackedInt32Array([2, 900])
	var values := PhysicalStateCodec.capture(actor)
	check(PhysicalStateCodec.validate(values), "bounded physical packet retains practice-target hit IDs")
	var restored := PlayerState.new()
	PhysicalStateCodec.apply(restored, values)
	equal(PhysicalStateCodec.capture(restored), values, "physical state roundtrips every clock and hit ID")
	var bad := values.duplicate()
	bad[18] = 2
	check(not PhysicalStateCodec.validate(bad), "duplicate hit IDs cannot restore repeated-hit ambiguity")
	bad = values.duplicate()
	bad[16] = 12
	check(not PhysicalStateCodec.validate(bad), "over-cap hit list is rejected without truncation")
	var snapshot := SessionSnapshot.capture(world, {1: "Host"})
	check(SessionSnapshot.validate(snapshot), "production snapshot accepts all physical phase fields")
	var copy := _world()
	check(SessionSnapshot.apply_to_world(snapshot, copy), "production snapshot restores physical state")
	equal(PhysicalStateCodec.capture(copy.player()), values, "snapshot does not erase no-repeat history")
	actor.entity_id = 2
	var prediction := ClientPrediction.capture_packet(actor, world.tick, 3)
	check(ClientPrediction.validate_packet(prediction), "host reconciliation carries physical state")
	var predicted := ClientPrediction.restore_state(prediction.values)
	equal(PhysicalStateCodec.capture(predicted), values, "local predicted presentation retains authority phase and hits")
	for kind: String in PhysicalEventCodec.TYPES:
		var event := {"type": kind, "entity_id": 1, "attacker_id": 1, "target_id": 900, "kind": "kick", "sequence_id": 1, "phase": "active", "reason": "modal", "damage": 12000, "contact_position": Vector2i(348000, 480000), "target_position_before_knockback": Vector2i(365000, 480000), "knockback_delta": Vector2i(30000, 0), "first_contact": true}
		var encoded := SessionSnapshot.encode_event(event)
		check(SessionSnapshot._valid_event_values(encoded), "physical feedback encodes and validates: " + kind)
		equal(SessionSnapshot.decode_event(encoded).type, kind, "physical feedback type roundtrip")

func _test_round_score() -> void:
	var world := _world()
	var target := PlayerState.new(2)
	target.team_id = 2
	target.champion_wire_id = 2
	world.players.append(target)
	var round := SessionRound.new()
	round.bind_hearth()
	check(round.begin(world, [1, 2], {"bounds": [100, 100, 900, 700], "score_limit": 1, "round_seconds": 15, "result_seconds": 2, "respawn_ms": 500, "spawn_protection_ms": 250, "spawns": [[300, 480], [360, 480]]}), "scored round fixture starts")
	world.player().spawn_protection_ticks = 0
	target.spawn_protection_ticks = 0
	target.health = 6_000
	target.health_recovery_per_second = 0
	_step(world, SimCommand.PRESSED_PUNCH)
	for tick: int in range(6):
		_step(world)
		round.advance(world, world.combat_events)
	equal(target.health, 0, "real paid Punch confirms the lethal enemy hit")
	equal(round.winner_entity_id, 1, "physical knockout awards the real attacker and wins a one-point round")
