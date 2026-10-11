extends FluxTestSuite


func run() -> int:
	for tick_rate: int in [120]:
		_test_deterministic_convergence(tick_rate)
		_test_eight_direction_parity(tick_rate)
	_test_soft_and_hard_correction()
	_test_history_and_validation_bounds()
	_test_movement_intent_state_round_trip()
	_test_momentum_preparation_replay()
	_test_bounded_slide_carry_replay()
	_test_evade_current_intent_prediction()
	_test_float_recovery_live_prediction()
	_test_expanded_status_wire_round_trip()
	return finish("client-prediction")


func _test_deterministic_convergence(tick_rate: int) -> void:
	var config := SimConfig.new(tick_rate)
	var collision := CollisionWorld.new(2_000_000, 1_500_000)
	var authority := _state()
	var prediction := ClientPrediction.new()
	check(prediction.configure(config, collision, 2), "%d Hz prediction configures" % tick_rate)
	var initial := ClientPrediction.capture_packet(authority, 10, -1)
	check(ClientPrediction.validate_packet(initial), "%d Hz authoritative prediction state validates" % tick_rate)
	_assert_actual_wire_round_trip(initial)
	check(prediction.reconcile(initial, "farflow_arrival"), "%d Hz first authority initializes prediction" % tick_rate)
	var command := SimCommand.new(
		0, 2, 1000, 0,
		SimCommand.HELD_JUMP | SimCommand.HELD_PRIMARY,
		SimCommand.PRESSED_JUMP | SimCommand.PRESSED_ACTIVE_1,
		700, 700,
	)
	check(prediction.queue_input(1, command), "%d Hz local input enters bounded prediction" % tick_rate)
	equal(prediction.predicted_state.position_x, authority.position_x, "%d Hz gathering from rest does not invent self-motion" % tick_rate)
	check(prediction.predicted_state.jumpsquat_active and not prediction.predicted_state.is_airborne(), "%d Hz held press predicts grounded anticipation immediately" % tick_rate)
	check(not prediction.predicted_state.primary_held, "%d Hz prediction never simulates held combat" % tick_rate)
	_advance_authority_movement(authority, command, config, collision)
	var confirmed := ClientPrediction.capture_packet(authority, 11, 1)
	check(prediction.reconcile(confirmed, authority.last_event), "%d Hz acknowledgement reconciles" % tick_rate)
	equal(prediction.pending_count(), 0, "%d Hz acknowledged input leaves history" % tick_rate)
	equal(Vector2i(prediction.predicted_state.position_x, prediction.predicted_state.position_y), Vector2i(authority.position_x, authority.position_y), "%d Hz equal input converges exactly" % tick_rate)
	_near(prediction.last_correction_pixels, 0.0, 0.001, "%d Hz equal prediction needs no correction" % tick_rate)
	check(not prediction.reconcile(confirmed, authority.last_event), "%d Hz repeated authority tick fails closed" % tick_rate)
	var release := SimCommand.new(1, 2, 1000, 0)
	check(prediction.queue_input(2, release), "%d Hz jump release enters prediction" % tick_rate)
	_advance_authority_movement(authority, release, config, collision)
	check(prediction.predicted_state.is_airborne() and not prediction.predicted_state.jumpsquat_active, "%d Hz release predicts actual takeoff" % tick_rate)
	check(prediction.reconcile(ClientPrediction.capture_packet(authority, 12, 2), authority.last_event), "%d Hz released jump reconciles" % tick_rate)
	equal(prediction.predicted_state.air_height, authority.air_height, "%d Hz release height converges exactly" % tick_rate)


func _assert_actual_wire_round_trip(packet: Dictionary) -> void:
	equal(SessionTransport.ENET_MTU_BYTES, 1392, "expanded prediction retains the exact1392-byte wire MTU")
	var wire_packets := SessionTransport._snapshot_wire_packets(packet, true, 13)
	check(not wire_packets.is_empty() and wire_packets.size() <= 64, "production reconciliation packing produces a bounded complete wire set")
	var receiver := SessionTransport.new()
	receiver.mode = SessionTransport.Mode.CLIENT
	receiver.local_entity_id = 2
	receiver.configure_world_epoch(13)
	wire_packets.reverse()
	for wire_packet: Dictionary in wire_packets:
		check(var_to_bytes(wire_packet).size() <= 1392, "every actual compressed or fragmented reconciliation datagram fits the unchanged MTU")
		receiver._handle_packet(SessionTransport.SERVER_PEER_ID, var_to_bytes(wire_packet))
	var received := receiver.take_reconciliations()
	equal(received.size(), 1, "complete packed authority is published exactly once")
	if not received.is_empty():
		var expected := packet.duplicate(true)
		expected.world_epoch = 13
		equal(received[0], expected, "all movement, resource, status and field values survive the actual wire packing path")
		var restored := ClientPrediction.restore_state(received[0].values)
		check(restored != null, "decoded expanded authority restores a valid prediction actor")
		if restored != null:
			equal(ClientPrediction.capture_packet(restored, int(packet.tick), int(packet.sequence)).values, packet.values, "restored state retains every appended status lane exactly")
	receiver.stop()


func _test_expanded_status_wire_round_trip() -> void:
	var authority := _state()
	# Codec upper-bound witness, not a claim that one attack applies this duration.
	var potencies := [80, 1000, 120, 80, 1000, 1000]
	for channel: int in 6:
		var at := channel * 8
		var values := [600, potencies[channel], 2400 if channel == 1 else 0, 12 if channel == 1 else 0,
			0x7fffffff - channel, 10000 - channel, MixtureCatalog.wire_for(63, ["bolt", "heavy", "rapid", "spray", "mantle", "fuse"][channel]), 0x7fffffff - channel * 7919]
		for index: int in 8: authority.spell_status_values[at + index] = int(values[index])
	var packet := ClientPrediction.capture_packet(authority, 100, 99)
	check(ClientPrediction.validate_packet(packet), "all six maximum-valid status channels form admissible prediction authority")
	check(var_to_bytes(packet).size() > 1392, "dense raw state exercises packing rather than the obsolete raw-one-MTU assumption")
	_assert_actual_wire_round_trip(packet)
	var before := authority.canonical_values()
	for index: int in [0, 10, 11, 5]:
		var malformed := packet.duplicate(true)
		var values: PackedInt64Array = malformed.values
		values[ClientPrediction.STATE_FIELDS.size() + index] += 1
		malformed.values = values
		check(not ClientPrediction.validate_packet(malformed), "status timer/pool/pulse/team beyond its exact bound fails closed")
		check(SessionTransport._snapshot_wire_packets(malformed, true, 13).is_empty(), "invalid status authority cannot reach wire fragmentation")
	equal(authority.canonical_values(), before, "rejected status packets cannot mutate the source actor")


func _test_momentum_preparation_replay() -> void:
	var config := SimConfig.new(120)
	var collision := CollisionWorld.new(10_000_000, 10_000_000)
	for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		for from_slide: bool in [false, true]:
			for cancel: bool in [false, true]:
				var authority := _state()
				authority.position_x = 5_000_000
				authority.position_y = 5_000_000
				authority.velocity_x = direction.x * 840
				authority.velocity_y = direction.y * 840
				authority.position_remainder_x = 119
				authority.position_remainder_y = -119
				authority.facing_x = -direction.x
				authority.facing_y = -direction.y
				var prediction := ClientPrediction.new()
				check(prediction.configure(config, collision, 2), "preparation replay configures at 120 Hz")
				check(prediction.reconcile(ClientPrediction.capture_packet(authority, 0, -1)), "preparation replay seeds incoming momentum and remainders")
				var commands: Array[SimCommand] = []
				if from_slide:
					commands.append(SimCommand.new(0, 2, -direction.y, direction.x, SimCommand.HELD_SLIDE, SimCommand.PRESSED_SLIDE))
					for index: int in range(config.milliseconds_to_ticks(MovementTuning.SLIDE_JUMP_MINIMUM_COMMITMENT_MS)):
						commands.append(SimCommand.new(index + 1, 2, 0, 0, SimCommand.HELD_SLIDE))
				var preparation_start := commands.size()
				var inputs: Array[Vector2i] = [direction, -direction, Vector2i(-direction.y, direction.x), Vector2i.ZERO]
				for index: int in range(41):
					var input := inputs[index % inputs.size()]
					commands.append(SimCommand.new(commands.size(), 2, input.x, input.y, SimCommand.HELD_JUMP | SimCommand.HELD_SPRINT, SimCommand.PRESSED_JUMP))
				commands.append(SimCommand.new(commands.size(), 2, 0, 0, 0, SimCommand.PRESSED_CANCEL_MOVEMENT if cancel else 0))
				commands.append(SimCommand.new(commands.size(), 2))
				var packets: Array[Dictionary] = []
				var anchor := Vector2i.ZERO
				for index: int in range(commands.size()):
					var command := commands[index]
					if index == preparation_start: anchor = Vector2i(authority.position_x, authority.position_y)
					check(prediction.queue_input(index + 1, command), "bounded preparation input enters prediction")
					_advance_authority_movement(authority, command, config, collision)
					var packet := ClientPrediction.capture_packet(authority, index + 1, index + 1)
					packets.append(packet)
					equal(ClientPrediction.capture_packet(prediction.predicted_state, index + 1, index + 1).values, packet.values, "all movement stores agree through Slide, held preparation and exit")
					if index >= preparation_start:
						var displacement := Vector2i(authority.position_x, authority.position_y) - anchor
						check(displacement.x * direction.x + displacement.y * direction.y > 0, "predicted preparation and neutral exit preserve earned travel")
					if index >= 2 and index % 7 == 6:
						check(prediction.reconcile(packets[index - 2], authority.last_event), "delayed acknowledgement replays two pending preparation inputs")
						equal(ClientPrediction.capture_packet(prediction.predicted_state, index + 1, index + 1).values, packet.values, "replayed moving preparation exactly matches uninterrupted authority")
				check(not authority.jumpsquat_active and authority.is_airborne() != cancel, "prediction agrees on explicit cancellation versus release")
				check(prediction.reconcile(packets.back(), authority.last_event), "final preparation acknowledgement drains pending history")
				equal(prediction.pending_count(), 0, "no preparation input remains after final acknowledgement")


func _test_bounded_slide_carry_replay() -> void:
	var config := SimConfig.new(120)
	var collision := CollisionWorld.new(10_000_000, 10_000_000)
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "carry replay loads abilities")
	var catalog := ChampionCatalog.new()
	check(catalog.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "carry replay loads actual profiles")
	var profiles: Dictionary = {}
	for champion_id: String in catalog.ordered_champion_ids():
		var body := String(catalog.champion(champion_id).body_type)
		if not profiles.has(body): profiles[body] = champion_id
	for body: String in profiles:
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			for exit_kind: String in ["expiry", "jump", "cancel"]:
				var authority := _state()
				check(catalog.apply_to_player(authority, String(profiles[body])), "carry replay applies " + body)
				authority.position_x = 5_000_000
				authority.position_y = 5_000_000
				authority.position_remainder_x = 119
				authority.position_remainder_y = -119
				var prediction := ClientPrediction.new()
				check(prediction.configure(config, collision, 2), "carry replay configures prediction")
				check(prediction.reconcile(ClientPrediction.capture_packet(authority, 0, -1)), "carry replay seeds real profile and subpixel remainders")
				var packets: Array[Dictionary] = []
				for tick: int in range(150):
					var move := direction if tick < 45 else Vector2i(-direction.y, direction.x) if tick >= 50 and tick < 60 else -direction if tick >= 60 and tick < 64 else Vector2i.ZERO
					var held := SimCommand.HELD_SPRINT if tick < 45 else SimCommand.HELD_SLIDE if tick < 70 else 0
					var pressed := SimCommand.PRESSED_SLIDE if tick == 45 else 0
					if exit_kind != "expiry" and tick >= 70 and tick < 82:
						held = SimCommand.HELD_JUMP
						pressed = SimCommand.PRESSED_JUMP if tick == 70 else 0
					if exit_kind == "cancel" and tick == 82:
						pressed = SimCommand.PRESSED_CANCEL_MOVEMENT
					var aim: Vector2i = EightDirectionResolver.FIXED_VECTORS[(tick / 5) % 8]
					var command := SimCommand.new(tick, 2, move.x, move.y, held, pressed, aim.x, aim.y)
					check(prediction.queue_input(tick + 1, command), "paid run/carve/brake/exit command enters prediction")
					_advance_authority_movement(authority, command, config, collision)
					var packet := ClientPrediction.capture_packet(authority, tick + 1, tick + 1)
					packets.append(packet)
					equal(ClientPrediction.capture_packet(prediction.predicted_state, tick + 1, tick + 1).values, packet.values, "all movement/resource/aim stores match after bounded slide carry")
					if tick % 8 == 7:
						check(prediction.reconcile(packets[tick - 3], authority.last_event), "delayed carry acknowledgement replays three pending commands")
						equal(ClientPrediction.capture_packet(prediction.predicted_state, tick + 1, tick + 1).values, packet.values, "carry replay exactly matches uninterrupted authority")
					if tick == 81 and exit_kind != "expiry":
						check(authority.jumpsquat_active and Vector2i(authority.velocity_x, authority.velocity_y).length() > 0, "replay includes real inherited slide gather, not stationary setup")
					if tick == 82:
						equal(authority.is_airborne(), exit_kind == "jump", "expiry, paid release and cancel have distinct exact outcomes")
				check(prediction.reconcile(packets.back(), authority.last_event), "final carry acknowledgement succeeds")
				equal(prediction.pending_count(), 0, "final carry acknowledgement drains all pending commands")


func _test_eight_direction_parity(tick_rate: int) -> void:
	var config := SimConfig.new(tick_rate)
	var collision := CollisionWorld.new(2_000_000, 1_500_000)
	for direction_index: int in range(EightDirectionResolver.DIRECTION_ORDER.size()):
		var direction_id := EightDirectionResolver.DIRECTION_ORDER[direction_index]
		var fixed := EightDirectionResolver.FIXED_VECTORS[direction_index]
		var authority := _state()
		var prediction := ClientPrediction.new()
		check(prediction.configure(config, collision, 2), "%d Hz %s prediction configures" % [tick_rate, direction_id])
		check(prediction.reconcile(ClientPrediction.capture_packet(authority, 20, -1)), "%d Hz %s authority initializes prediction" % [tick_rate, direction_id])
		var command := SimCommand.new(0, 2, fixed.x, fixed.y, 0, 0, fixed.x, fixed.y)
		check(prediction.queue_input(1, command), "%d Hz %s input enters prediction" % [tick_rate, direction_id])
		var queued: SimCommand = prediction.pending_inputs[0]["command"]
		equal(Vector2i(queued.move_x, queued.move_y), fixed, "%d Hz %s prediction preserves movement components" % [tick_rate, direction_id])
		equal(Vector2i(queued.aim_x, queued.aim_y), fixed, "%d Hz %s prediction preserves aim heading" % [tick_rate, direction_id])
		_advance_authority_movement(authority, command, config, collision)
		check(prediction.reconcile(ClientPrediction.capture_packet(authority, 21, 1), authority.last_event), "%d Hz %s authority reconciles" % [tick_rate, direction_id])
		equal(
			Vector2i(prediction.predicted_state.position_x, prediction.predicted_state.position_y),
			Vector2i(authority.position_x, authority.position_y),
			"%d Hz %s prediction converges without directional drift" % [tick_rate, direction_id],
		)


func _test_soft_and_hard_correction() -> void:
	var config := SimConfig.new(120)
	var collision := CollisionWorld.new(2_000_000, 1_500_000)
	var prediction := ClientPrediction.new()
	check(prediction.configure(config, collision, 2), "correction fixture configures")
	var authority := _state()
	check(prediction.reconcile(ClientPrediction.capture_packet(authority, 1, -1)), "correction fixture initializes")
	authority.position_x += 10_000
	check(prediction.reconcile(ClientPrediction.capture_packet(authority, 2, -1)), "small divergence reconciles")
	_near(prediction.last_correction_pixels, 10.0, 0.001, "small correction is measured in pixels")
	check(prediction.visual_offset.length() > 0.0, "small correction preserves a decaying presentation offset")
	prediction.advance_visual(1.0)
	_near(prediction.visual_offset.length(), 0.0, 0.001, "presentation correction decays to zero")
	for tick: int in range(3, 11):
		authority.position_x += 10_000
		check(prediction.reconcile(ClientPrediction.capture_packet(authority, tick, -1)), "repeated small correction %d reconciles" % tick)
	check(prediction.visual_offset.length() <= ClientPrediction.SOFT_CORRECTION_LIMIT_PIXELS, "accumulated soft correction stays visibly bounded")
	authority.position_x += 200_000
	check(prediction.reconcile(ClientPrediction.capture_packet(authority, 11, -1)), "large divergence reconciles")
	check(prediction.last_correction_pixels > ClientPrediction.SOFT_CORRECTION_LIMIT_PIXELS, "large correction crosses the hard-snap threshold")
	equal(prediction.hard_snap_count, 1, "large correction is counted as one hard snap")
	_near(prediction.visual_offset.length(), 0.0, 0.001, "hard snap never carries a misleading visual offset")


func _test_history_and_validation_bounds() -> void:
	var prediction := ClientPrediction.new()
	check(prediction.configure(SimConfig.new(120), CollisionWorld.new(2_000_000, 1_500_000), 2), "history fixture configures at the canonical rate")
	var authority := _state()
	var initial := ClientPrediction.capture_packet(authority, 1, -1)
	check(prediction.reconcile(initial), "history fixture initializes")
	for sequence: int in range(1, ClientPrediction.MAX_PENDING_INPUTS + 9):
		check(prediction.queue_input(sequence, SimCommand.new(0, 2, 1000, 0)), "history accepts monotonic input %d" % sequence)
	equal(prediction.pending_count(), ClientPrediction.MAX_PENDING_INPUTS, "prediction input memory is strictly bounded")
	check(prediction.history_overflowed, "history overflow is explicit")
	check(not prediction.queue_input(ClientPrediction.MAX_PENDING_INPUTS + 8, SimCommand.new(0, 2)), "replayed local sequence fails closed")
	var newest := ClientPrediction.capture_packet(authority, 2, ClientPrediction.MAX_PENDING_INPUTS + 8)
	check(prediction.reconcile(newest), "overflowed history accepts newer authority")
	equal(prediction.pending_count(), 0, "new authority drains acknowledged bounded history")
	equal(prediction.hard_snap_count, 1, "history loss forces an explicit hard snap")
	var malformed := initial.duplicate(true)
	malformed["values"] = PackedInt64Array([2])
	check(not ClientPrediction.validate_packet(malformed), "short reconciliation state fails closed")
	malformed = initial.duplicate(true)
	var values: PackedInt64Array = malformed["values"]
	values[0] = 9
	malformed["values"] = values
	check(not ClientPrediction.validate_packet(malformed), "out-of-roster prediction entity fails closed")


func _test_movement_intent_state_round_trip() -> void:
	var authority := _state()
	authority.air_velocity_x = -333_000
	authority.air_velocity_y = 444_000
	authority.movement_commitment_ticks = 9
	authority.wall_air_ticks = 27
	authority.slide_held_last_tick = true
	authority.fast_fall_armed = true
	authority.evade_buffer_airborne = true
	authority.air_height = 123_456
	authority.air_vertical_velocity = -456_789
	authority.air_height_remainder = -119
	authority.air_dodge_used = true
	authority.jump_held_last_tick = true
	authority.air_floating = true
	authority.float_used = true
	authority.flight_capable = true
	authority.double_jump_used = true
	authority.wallrun_armed = false
	authority.float_ticks = 100
	authority.chemistry_reveal_ticks = 84
	authority.chemistry_conceal_ticks = 2
	authority.chemistry_regen_block_ticks = 2
	authority.hop_stage = 2
	authority.air_vertical_velocity = 0
	authority.stamina_recovery_idle_ticks = 137
	authority.stamina_maximum = 792_000
	authority.stamina = 791_123
	var packet := ClientPrediction.capture_packet(authority, 1, -1)
	check(not packet.is_empty(), "new movement intent state is admitted for prediction")
	var restored := ClientPrediction.restore_state(packet["values"])
	for property_name: StringName in ClientPrediction.STATE_FIELDS:
		equal(restored.get(property_name), authority.get(property_name), "prediction round-trips %s" % property_name)
	for fixture: Array in [
		[&"air_height", -1], [&"air_height", MovementTuning.AIR_MAX_HEIGHT + 1],
		[&"air_vertical_velocity", -MovementTuning.AIR_TERMINAL_FALL_SPEED - 1],
		[&"air_vertical_velocity", MovementTuning.CHARGED_JUMP_VERTICAL_SPEED + 1],
		[&"air_height_remainder", -240], [&"air_height_remainder", 240],
		[&"air_dodge_used", 2], [&"jump_held_last_tick", -1],
		[&"air_floating", 2], [&"air_floating", -1],
		[&"float_used", 2], [&"float_ticks", -1], [&"float_ticks", (MovementTuning.FLOAT_MIDDLE_DURATION_MS * 120 + 999) / 1000 + 1], [&"float_max_duration_ms", 1400],
		[&"flight_capable", -1], [&"flight_capable", 2], [&"jumpsquat_active", 2],
		[&"jumpsquat_ticks", -1], [&"jumpsquat_ticks", (MovementTuning.JUMPSQUAT_CHARGE_MS * 120 + 999) / 1000 + 1],
		[&"double_jump_used", 2], [&"wallrun_armed", 2], [&"crouching", 2],
		[&"chemistry_reveal_ticks", 121], [&"chemistry_conceal_ticks", -1], [&"chemistry_regen_block_ticks", 121],
		[&"stamina_recovery_idle_ticks", -1], [&"stamina_recovery_idle_ticks", 361],
	]:
		var malformed: PackedInt64Array = packet["values"].duplicate()
		malformed[ClientPrediction.STATE_FIELDS.find(fixture[0])] = fixture[1]
		check(not ClientPrediction.validate_values(malformed), "physical airborne bounds reject %s=%s" % fixture)
	for property_name: StringName in [&"slide_held_last_tick", &"fast_fall_armed", &"evade_buffer_airborne", &"movement_commitment_ticks", &"wall_air_ticks"]:
		var malformed: PackedInt64Array = packet["values"].duplicate()
		malformed[ClientPrediction.STATE_FIELDS.find(property_name)] = -1
		check(not ClientPrediction.validate_values(malformed), "invalid movement intent rejected: %s" % property_name)
	var collision := CollisionWorld.new(3_000_000, 2_000_000)
	var config := SimConfig.new(120)
	for unsafe_ratio: int in [0, MovementTuning.SLOW_MINIMUM_RATIO - 1, 1001]:
		var malformed: PackedInt64Array = packet["values"].duplicate()
		malformed[ClientPrediction.STATE_FIELDS.find(&"slow_ratio")] = unsafe_ratio
		check(not ClientPrediction.validate_values(malformed), "unsafe slow ratio cannot reach momentum restoration")
	for tick: int in range(90):
		var direction := Vector2i(600, -800) if tick < 45 else Vector2i(-800, 600)
		var pressed := SimCommand.PRESSED_JUMP if tick in [0, 22] else 0
		var command := SimCommand.new(tick, 2, direction.x, direction.y, SimCommand.HELD_JUMP, pressed)
		_advance_authority_movement(authority, command, config, collision)
		_advance_authority_movement(restored, command, config, collision)
		for property_name: StringName in ClientPrediction.STATE_FIELDS:
			equal(restored.get(property_name), authority.get(property_name), "restored movement remains deterministic: tick %d / %s" % [tick, property_name])


func _test_evade_current_intent_prediction() -> void:
	var config := SimConfig.new(120)
	var collision := CollisionWorld.new(2_000_000, 1_500_000)
	var authority := _state()
	authority.air_height = 120_000
	authority.air_vertical_velocity = 100_000
	authority.hop_ticks = MovementSystem._remaining_air_ticks(authority, config)
	authority.hop_stage = 1
	authority.movement_commitment_ticks = 2
	var prediction := ClientPrediction.new()
	check(prediction.configure(config, collision, 2), "buffered Evade prediction configures")
	check(prediction.reconcile(ClientPrediction.capture_packet(authority, 0, -1)), "buffered Evade prediction seeds exact authority")
	var commands: Array[SimCommand] = [
		SimCommand.new(0, 2, 1000, 0, 0, SimCommand.PRESSED_EVADE),
		SimCommand.new(1, 2, 0, 1000),
	]
	for index: int in range(commands.size()):
		check(prediction.queue_input(index + 1, commands[index]), "buffered Evade prediction accepts current-intent tick %d" % index)
		_advance_authority_movement(authority, commands[index], config, collision)
		equal(ClientPrediction.capture_packet(prediction.predicted_state, index + 1, index + 1)["values"], ClientPrediction.capture_packet(authority, index + 1, index + 1)["values"], "prediction matches current-direction Q admission tick %d" % index)
	equal(Vector2i(authority.air_dodge_x, authority.air_dodge_y), Vector2i(0, 1000), "authority and prediction use admission-time screen-down direction")
	var neutral_authority := _state()
	neutral_authority.air_height = 120_000
	neutral_authority.air_vertical_velocity = 100_000
	neutral_authority.hop_ticks = MovementSystem._remaining_air_ticks(neutral_authority, config)
	neutral_authority.hop_stage = 2
	neutral_authority.air_dodge_used = true
	neutral_authority.air_velocity_x = 280_000
	neutral_authority.velocity_x = neutral_authority.air_velocity_x
	var neutral_prediction := ClientPrediction.new()
	check(neutral_prediction.configure(config, collision, 2), "neutral Evade prediction configures")
	check(neutral_prediction.reconcile(ClientPrediction.capture_packet(neutral_authority, 0, -1)), "neutral Evade prediction seeds exact authority")
	var neutral_command := SimCommand.new(0, 2, 0, 0, 0, SimCommand.PRESSED_EVADE)
	check(neutral_prediction.queue_input(1, neutral_command), "neutral Evade enters prediction")
	_advance_authority_movement(neutral_authority, neutral_command, config, collision)
	check(neutral_authority.fast_falling and neutral_prediction.predicted_state.fast_falling, "authority and prediction both choose vertical fast-fall with spent dodge allowance")
	equal(ClientPrediction.capture_packet(neutral_prediction.predicted_state, 1, 1)["values"], ClientPrediction.capture_packet(neutral_authority, 1, 1)["values"], "neutral Q canonical prediction equals authority")


func _test_float_recovery_live_prediction() -> void:
	var config := SimConfig.new(120)
	var collision := CollisionWorld.new(8_000_000, 8_000_000)
	var authority := _state()
	authority.position_x = 4_000_000
	authority.position_y = 4_000_000
	authority.stamina_maximum = 594_000
	authority.stamina = 594_000
	authority.float_max_duration_ms = MovementTuning.FLOAT_LARGE_DURATION_MS
	authority.flight_capable = true
	var prediction := ClientPrediction.new()
	check(prediction.configure(config, collision, 2), "Float recovery prediction configures")
	check(prediction.reconcile(ClientPrediction.capture_packet(authority, 0, -1)), "Float prediction seeds from authority")
	var flight_ticks := 0
	var peak_idle_ticks := 0
	var expired_while_held := false
	# The longer216-tick large flight consumes more resource than the old144
	# ticks. Continue through the unchanged full recovery ramp rather than
	# weakening its recovery threshold or silently boosting regeneration.
	for tick: int in range(1, 840):
		var held := SimCommand.HELD_JUMP if tick == 4 or (tick >= 24 and tick < 260) else 0
		var pressed := SimCommand.PRESSED_JUMP if tick in [4, 24] else 0
		var direction := Vector2i(1000, 0) if tick < 70 else Vector2i(0, -1000)
		var command := SimCommand.new(tick, 2, direction.x, direction.y, held, pressed)
		check(prediction.queue_input(tick, command), "Float input %d accepted" % tick)
		_advance_authority_movement(authority, command, config, collision)
		if authority.air_floating:
			flight_ticks += 1
			check(not MovementSystem.is_combat_intangible(authority, config), "predicted flight is height avoidance, not blanket immunity")
		if authority.last_event == "float_expired" and held & SimCommand.HELD_JUMP:
			expired_while_held = true
		peak_idle_ticks = maxi(peak_idle_ticks, authority.stamina_recovery_idle_ticks)
		var predicted_values: PackedInt64Array = ClientPrediction.capture_packet(prediction.predicted_state, tick, tick)["values"]
		var authoritative_packet := ClientPrediction.capture_packet(authority, tick, tick)
		equal(predicted_values, authoritative_packet["values"], "Float/protection/recovery match authority tick %d" % tick)
		if tick % 6 == 0:
			check(prediction.reconcile(authoritative_packet, authority.last_event), "Float snapshot %d reconciles" % tick)
			_near(prediction.last_correction_pixels, 0.0, 0.001, "Float/recovery needs no correction at tick %d" % tick)
	check(flight_ticks > 120, "production inputs hold race-enabled flight beyond one second")
	equal(flight_ticks, config.milliseconds_to_ticks(MovementTuning.FLOAT_LARGE_DURATION_MS) - 1, "prediction respects the exact body-limited flight tick budget")
	check(expired_while_held and not authority.air_floating and authority.air_height == 0, "hard Float expiry while still held matches authority and returns to ground")
	equal(peak_idle_ticks, ResourceRecovery.maximum_idle_ticks(120), "post-float recovery reaches bounded full ramp")
	check(authority.stamina > 500_000, "production float use refills through progressive recovery")


func _advance_authority_movement(state: PlayerState, command: SimCommand, config: SimConfig, collision: CollisionWorld) -> void:
	# These movement-only controls mirror SimWorld's aim -> resource -> movement
	# stages. Combat admission is intentionally outside prediction's scope.
	state.aim_x = command.aim_x
	state.aim_y = command.aim_y
	PlayerResourcesSystem.step(state, config)
	MovementSystem.step(state, command, config, collision)


func _state() -> PlayerState:
	var state := PlayerState.new(2)
	state.position_x = 600_000
	state.position_y = 500_000
	state.stamina_maximum = 96_000
	state.stamina = 96_000
	state.stamina_recovery_per_second = 17_000
	state.movement_speed_ratio = 1040
	return state


func _near(actual: float, expected: float, tolerance: float, message: String) -> void:
	check(absf(actual - expected) <= tolerance, "%s (expected=%s actual=%s)" % [message, expected, actual])
