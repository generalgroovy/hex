extends FluxTestSuite

const Codec = preload("res://src/net/expanded_spell_state_codec.gd")
const Mixtures = preload("res://src/content/mixture_catalog.gd")
const Snapshot = preload("res://src/net/hex_world_snapshot.gd")


func run() -> int:
	_test_status_admission()
	_test_delivery_admission()
	_test_authority_and_prediction()
	_test_transport_budget()
	return finish("expanded-spell-network")


func _status_actor(entity: int = 2) -> PlayerState:
	var actor := PlayerState.new(entity)
	actor.team_id = 2
	SpellStatusPolicy.apply_hit(actor, Mixtures.wire_for(63, "bolt"), 9001, 1, 1, 8000, SimConfig.new(), Vector2i.RIGHT * 1000)
	return actor


func _test_status_admission() -> void:
	var actor := _status_actor()
	var values := PackedInt64Array(Array(actor.spell_status_values))
	check(Codec.valid_status_values(values), "all six legitimate channels admit before narrowing")
	equal(values.size(), 48, "six fixed eight-value lanes")
	for channel: int in 6:
		check(values[channel * 8] > 0, "six-element payload carries every actual status")
		for lane: int in 8:
			var bad := values.duplicate()
			bad[channel * 8 + lane] = 0x100000000 + values[channel * 8 + lane]
			check(not Codec.valid_status_values(bad), "64-bit alias cannot narrow into a valid status")
		var amplified := values.duplicate()
		amplified[channel * 8 + 1] += 1
		check(not Codec.valid_status_values(amplified), "network cannot amplify authored status potency")
		var extinct := values.duplicate()
		extinct[channel * 8] = 0
		check(not Codec.valid_status_values(extinct), "expired status has no concealed owner or damage metadata")
	var wrong_element := values.duplicate()
	wrong_element[6] = Mixtures.wire_for(4, "bolt")
	check(not Codec.valid_status_values(wrong_element), "Water source cannot carry an Earth status")
	var unbounded_burn := values.duplicate()
	unbounded_burn[10] = 2401
	check(not Codec.valid_status_values(unbounded_burn), "burn reserve is capped at its authored maximum")
	check(not Codec.valid_status_values(values.slice(0, 47)), "partial status row fails closed")
	check(not Codec.valid_status_values(Array(values)), "wire accepts packed integer arrays only")


func _test_delivery_admission() -> void:
	for family: String in Mixtures.FAMILIES:
		var wire := Mixtures.wire_for(63, family)
		var definition := CombatTuning.cast_definition_view(wire)
		var shot := ProjectileState.new(11, 1, 1, wire, int(definition.element_wire_id), Vector2i(200000, 300000), Vector2i.ZERO, 8000, int(definition.damage), 120)
		if family in ["mantle", "fuse"]: shot.delivery_damage_remaining = int(definition.damage)
		if family == "fuse":
			shot.delivery_phase = 1
			shot.delivery_ticks = 72
		if family == "split": shot.delivery_phase = 2
		if family == "mantle": shot.contact_entity_ids = PackedInt64Array([2, 4, 8])
		var values := Codec.capture_delivery(shot)
		check(not values.is_empty(), "authored delivery extension admits: " + family)
		if values.is_empty(): continue
		var copied := ProjectileState.new(12, 1, 1, wire, int(definition.element_wire_id), Vector2i.ZERO, Vector2i.ZERO, 8000, int(definition.damage), 120)
		check(Codec.restore_delivery(copied, values), "delivery restores: " + family)
		equal(Codec.capture_delivery(copied), values, "phase, clock, pool and contact history round-trip")
		for lane: int in values.size():
			var bad := PackedInt64Array(Array(values))
			bad[lane] += 0x100000000
			check(not Codec.valid_delivery(bad, wire), "delivery64-bit alias rejects before narrowing")
		var bad_padding := values.duplicate()
		bad_padding[15] = 1
		check(not Codec.valid_delivery(bad_padding, wire), "unused contact padding cannot conceal an actor")
	var fuse := PackedInt32Array()
	fuse.resize(16)
	fuse[0] = 1; fuse[1] = 73
	check(not Codec.valid_delivery(fuse, Mixtures.wire_for(6, "fuse")), "Fuse clock cannot exceed real600ms warning")
	fuse[1] = 72
	check(not Codec.valid_delivery(fuse, Mixtures.wire_for(6, "bolt")), "Bolt cannot impersonate an armed Fuse")
	fuse[0] = 2
	check(not Codec.valid_delivery(fuse, Mixtures.wire_for(6, "split")), "spent Split child cannot carry a new split timer")


func _test_authority_and_prediction() -> void:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "network fixture loads504 catalog")
	var world := SimWorld.new()
	check(HexCourtPractice.configure(world, catalog), "network fixture uses real local Hex authority")
	var target := world.player(2)
	SpellStatusPolicy.apply_hit(target, Mixtures.wire_for(63, "bolt"), 9001, 1, 1, 8000, world.config, Vector2i.RIGHT * 1000)
	var source_hash := world.state_hash()
	var snapshot := Snapshot.capture(world)
	check(not snapshot.is_empty(), "full authority captures live target statuses")
	if not snapshot.is_empty():
		var restored := Snapshot.prepare(snapshot, world)
		check(restored != null, "full authority prepares live statuses")
		if restored != null:
			equal(restored.state_hash(), source_hash, "snapshot preserves complete authoritative state")
			equal(restored.player(2).spell_status_values, target.spell_status_values, "all48 target lanes survive")
			restored.player(2).spell_status_values[0] -= 1
			equal(world.state_hash(), source_hash, "restored mutable lanes never alias live authority")
	var actor := _status_actor()
	var packet := ClientPrediction.capture_packet(actor, 0, -1)
	check(not packet.is_empty(), "prediction acknowledges live status lanes")
	if packet.is_empty(): return
	var predictor := ClientPrediction.new()
	check(predictor.configure(SimConfig.new(), CollisionWorld.new(), 2), "prediction fixture configures")
	check(predictor.reconcile(packet), "prediction admits status packet")
	var before_health := predictor.predicted_state.health
	check(predictor.queue_input(0, SimCommand.new(0, 2, 1000, 0, 0, 0, 1000, 0)), "movement predicts with chilled state")
	equal(predictor.predicted_state.health, before_health, "prediction never invents authoritative burn damage")
	check(predictor.predicted_state.spell_status_values[0] < actor.spell_status_values[0], "status clock advances in prediction")
	var forged := packet.duplicate(true)
	forged.values[ClientPrediction.STATE_FIELDS.size() + 1] = 0x100000000 + 80
	check(not ClientPrediction.validate_packet(forged), "prediction rejects oversized status before cast")


func _test_transport_budget() -> void:
	var maximum_fixed_lanes := (Snapshot.MAX_ACTORS * Snapshot.PLAYER_VALUE_COUNT + Snapshot.MAX_PROJECTILES * Snapshot.PROJECTILE_ROW_SIZE) * 4
	check(maximum_fixed_lanes > 32768, "expanded legal actor/projectile rows exceed old32KiB limit")
	check(maximum_fixed_lanes < Snapshot.MAX_RAW_BYTES, "new bounded64KiB envelope retains all legal fixed lanes")
	equal(Snapshot.MAX_RAW_BYTES, WorldSnapshotEnvelope.MAX_RAW_BYTES, "outer and Hex limits agree")
	equal(Snapshot.MAX_RAW_BYTES, SessionTransport.MAX_SNAPSHOT_UNCOMPRESSED_BYTES, "transport owns same raw budget")
	check(SessionTransport.MAX_SNAPSHOT_FRAGMENTS * SessionTransport.SNAPSHOT_FRAGMENT_PAYLOAD_BYTES >= Snapshot.MAX_RAW_BYTES, "fragment budget can carry bounded incompressible payload")
	equal(SessionTransport.MAX_SPELL_LIBRARY_SIZE, 512, "weave wire capacity holds504 stable indices")
