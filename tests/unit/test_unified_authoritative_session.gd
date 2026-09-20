extends FluxTestSuite


const ABILITY_PATH := "res://content/abilities/foundation_abilities_v1.json"
const CHAMPION_PATH := "res://content/champions/foundation_champions_v1.json"


func run() -> int:
	_test_envelopes_and_atomic_world_replacement()
	_test_catalogue_actor_roundtrips()
	return finish("unified-authoritative-session")


func _test_catalogue_actor_roundtrips() -> void:
	var abilities := AbilityCatalog.new()
	var champions := ChampionCatalog.new()
	check(abilities.load_from_file(ABILITY_PATH) and champions.load_from_file(CHAMPION_PATH, abilities), "full cast snapshot fixture loads")
	var world := SimWorld.new(120, 45, CollisionWorld.new(1_280_000, 960_000))
	check(HexCourtPractice.configure(world, abilities, false), "cast snapshot topology configures")
	for id: String in champions.ordered_champion_ids():
		check(champions.apply_to_player(world.player(), id), "%s uses actual authored stats" % id)
		var snapshot := HexWorldSnapshot.capture(world)
		check(not snapshot.is_empty(), "%s complete actor state is encodable" % id)
		if snapshot.is_empty(): continue
		var restored := HexWorldSnapshot.prepare(snapshot, world)
		check(restored != null and restored.player().canonical_values() == world.player().canonical_values(), "%s keeps size, movement ratio, Float and custom slots" % id)


func _test_envelopes_and_atomic_world_replacement() -> void:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file(ABILITY_PATH), "unified session fixture loads abilities")
	var champions := ChampionCatalog.new()
	check(champions.load_from_file(CHAMPION_PATH, abilities), "unified session fixture loads champions")
	var legacy := SimWorld.new(120, 41, CollisionWorld.new(3_000_000, 2_000_000))
	check(champions.apply_to_player(legacy.player(), "oh_tipi"), "legacy host receives a persistent champion identity")
	var session := AuthoritativeSession.new()
	check(session.bind(legacy, champions, Vector2i(1280, 720), "Epoch Host", [], "sparring_circle"), "initial legacy authority binds")
	check(session.register_peers([{"entity_id": 2, "name": "Epoch Guest"}]) == 1, "remote persistent roster identity registers")
	var host: PlayerState = legacy.player(1)
	var guest: PlayerState = legacy.player(2)
	check(host.place_proven_spell(0, host.spell_wire_ids[3]), "host stores a non-default woven slot choice")
	check(guest.place_proven_spell(1, guest.spell_wire_ids[4]), "guest stores a non-default woven slot choice")
	var expected_host_slots := host.spell_wire_ids.duplicate()
	var expected_guest_slots := guest.spell_wire_ids.duplicate()
	var expected_host_champion := host.champion_wire_id
	var expected_guest_champion := guest.champion_wire_id
	host.health -= 21_000
	host.pending_cast_ticks = 9
	guest.control_ticks = 17
	session.latest_input_by_entity[2] = {"sequence": 9, "received_tick": 0}
	session.last_processed_input_sequence_by_entity[2] = 8
	session.session_round.serial = 7
	check(session.record_combat_events([{"type": "cast_started", "entity_id": 2, "wire_id": guest.primary_wire_id}]) == 1, "pre-reset event receives a monotonic identity")
	var preserved_next_event_id := session.next_event_id

	var legacy_snapshot := session.capture_snapshot()
	check(SessionSnapshot.validate(legacy_snapshot), "legacy capture_snapshot API remains unchanged")
	var legacy_envelope := session.capture_envelope()
	check(WorldSnapshotEnvelope.validate(legacy_envelope), "capture_envelope wraps a valid legacy snapshot")
	equal(int(legacy_envelope.world_kind), WorldSnapshotEnvelope.WORLD_LEGACY, "legacy envelope identifies its authority kind")
	equal(int(legacy_envelope.world_epoch), 0, "first bound world starts at epoch zero")

	var invalid := SimWorld.new(120, 42, CollisionWorld.new(3_000_000, 2_000_000))
	invalid.tick = 1
	var before_world := session.world
	var before_epoch := session.world_epoch
	check(not session.replace_world(invalid, Vector2i(640, 710)), "nonzero-tick replacement rejects atomically")
	check(session.world == before_world and session.world_epoch == before_epoch, "failed replacement cannot swap authority or epoch")

	var first_hex := SimWorld.new(120, 43, CollisionWorld.new(1_280_000, 960_000))
	check(HexCourtPractice.configure(first_hex, abilities, false), "fresh Wellspring replacement configures")
	check(session.replace_world(first_hex, Vector2i(640, 710)), "fresh hex world replaces legacy authority")
	equal(session.world_epoch, 1, "successful replacement advances exactly one epoch")
	check(session.world == first_hex and session.world.collision != legacy.collision, "replacement owns independent mutable physics")
	equal(session.names_by_entity, {1: "Epoch Host", 2: "Epoch Guest"}, "replacement preserves sorted roster names")
	var reset_host: PlayerState = first_hex.player(1)
	var reset_guest: PlayerState = first_hex.player(2)
	equal(reset_host.champion_wire_id, expected_host_champion, "host champion identity survives reset")
	equal(reset_guest.champion_wire_id, expected_guest_champion, "guest champion identity survives reset")
	equal(reset_host.spell_wire_ids, expected_host_slots, "host woven loadout survives reset")
	equal(reset_guest.spell_wire_ids, expected_guest_slots, "guest woven loadout survives reset")
	equal(reset_host.team_id, host.team_id, "host combat team survives reset")
	equal(reset_guest.team_id, guest.team_id, "guest combat team survives reset")
	equal(reset_host.health, reset_host.health_maximum, "host transient damage resets at tick zero")
	equal(reset_host.pending_cast_ticks, 0, "host pending cast timer resets")
	equal(reset_guest.control_ticks, 0, "guest control timer resets")
	check(session.latest_input_by_entity.is_empty() and session.last_processed_input_sequence_by_entity.is_empty(), "input and reconciliation queues clear at the epoch boundary")
	check(session.pending_combat_events.is_empty() and not session.snapshot_capture_pending_ack, "old event payload and capture acknowledgement clear")
	equal(session.next_event_id, preserved_next_event_id, "event identity remains monotonic across reset")
	equal(session.session_round.serial, 7, "round serial remains monotonic across reset")
	equal(session.session_round.phase, SessionRound.Phase.HEARTH, "replacement closes the old round into a fresh Hearth")

	var hex_envelope := session.capture_envelope()
	check(WorldSnapshotEnvelope.validate(hex_envelope), "hex authority and session lanes capture in one validated envelope")
	if hex_envelope.is_empty(): return
	equal(int(hex_envelope.world_kind), WorldSnapshotEnvelope.WORLD_HEX, "hex envelope identifies its authority kind")
	equal(int(hex_envelope.world_epoch), 1, "hex envelope carries the replacement epoch")
	var name_rows: Array = (hex_envelope.session as Dictionary).names
	equal(name_rows[0][0], 1, "hex session names are sorted by champion entity")
	equal(name_rows[1][0], 2, "hex session includes the complete remote champion identity")
	var reconciliation := session.capture_reconciliation(2)
	check(ClientPrediction.validate_packet(reconciliation), "hex authority emits full PlayerState reconciliation without legacy reactions")

	var source_wire := reset_host.primary_wire_id
	check(first_hex.hex_court.reserve_cast(1, source_wire), "old hex authority reserves paid source before reset")
	first_hex.hex_court.commit_payment(1)
	first_hex.hex_court.bind_release(1, 81_001, Vector2i(reset_host.position_x, reset_host.position_y), Vector2i(1000, 0), reset_host.team_id)
	check(not first_hex.hex_court.casts.is_empty(), "old authority owns a live partitioned source budget")
	var second_hex := SimWorld.new(120, 44, CollisionWorld.new(1_280_000, 960_000))
	check(HexCourtPractice.configure(second_hex, abilities, false), "second fresh Wellspring configures")
	check(session.replace_world(second_hex, Vector2i(640, 710)), "hex return/reset replaces the prior Wellspring")
	equal(session.world_epoch, 2, "second successful replacement advances one more epoch")
	check(second_hex.hex_court.casts.is_empty() and second_hex.hex_court.sources.is_empty(), "no paid source ledger or branch budget carries into the new world")
	equal(session.next_event_id, preserved_next_event_id, "second replacement still preserves the next event identity")
	equal(session.session_round.serial, 7, "second replacement still preserves the round serial")
	check(second_hex.player(1).spell_wire_ids == expected_host_slots and second_hex.player(2).spell_wire_ids == expected_guest_slots, "roster loadouts survive repeated world replacement")
