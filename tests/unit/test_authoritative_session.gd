extends FluxTestSuite


const ABILITY_PATH: String = "res://content/abilities/foundation_abilities_v1.json"
const CHAMPION_PATH: String = "res://content/champions/foundation_champions_v1.json"


func run() -> int:
	_test_authoritative_presence_and_input()
	_test_round_reconnect_team_invariance()
	_test_hitch_input_coalescing_contract()
	_test_event_burst_overflow_contract()
	_test_hex_clash_outcome_delivery()
	return finish("authoritative-session")


func _test_round_reconnect_team_invariance() -> void:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file(ABILITY_PATH), "abilities load for round reconnect invariance")
	var champions := ChampionCatalog.new()
	check(champions.load_from_file(CHAMPION_PATH, abilities), "champions load for round reconnect invariance")
	var world := SimWorld.new(120, 95, CollisionWorld.new(3_000_000, 2_000_000))
	check(champions.apply_to_player(world.player(), "oh_tipi"), "round reconnect host champion applies")
	var session := AuthoritativeSession.new()
	check(session.bind(world, champions, Vector2i(1280, 720), "Return Host"), "round reconnect uses the Open Commons charter")
	# Six entrants with holes in the entity sequence exercise the real capacity
	# without pretending that the current individual-score court is a team mode.
	var participants: Array[int] = [1, 2, 4, 5, 7, 8]
	var roster: Array[Dictionary] = []
	for entity_id: int in participants:
		if entity_id != 1:
			roster.append({"entity_id": entity_id, "name": "Return %d" % entity_id})
	equal(session.register_peers(roster), 5, "sparse roster admits five guests beside the host")
	equal(session.hearth.connected_entity_ids(), participants, "six-person roster retains its sparse authoritative identities")
	var definition := {
		"bounds": [400, 300, 1200, 900], "score_limit": 3, "round_seconds": 15,
		"result_seconds": 2, "respawn_ms": 500, "spawn_protection_ms": 250,
		"spawns": [[500, 400], [1500, 400], [500, 1100], [1500, 1100], [500, 750], [1500, 750]],
	}
	check(session.begin_round(definition), "six sparse entrants begin the real authoritative court")
	if not session.session_round.active():
		return
	equal(session.session_round.scores_by_entity.size(), 6, "round freezes exactly six participants")
	var original_spawns := session.session_round.spawn_by_entity.duplicate()
	var actors: Dictionary[int, PlayerState] = {}
	for entity_id: int in participants:
		var actor := world.player(entity_id)
		actors[entity_id] = actor
		equal(actor.team_id, entity_id, "court owns the sparse participant's individual team %d" % entity_id)
		actor.position_x += entity_id * 1000
		actor.health -= entity_id * 1000
		actor.flux -= entity_id * 100
		check(actor.place_proven_spell(0, actor.spell_wire_ids[1]), "participant %d retains a nondefault valid weave" % entity_id)
		check(actor.set_spell_cooldown(actor.spell_wire_ids[0], entity_id + 10), "participant %d has a live cooldown to preserve" % entity_id)
		session.session_round.scores_by_entity[entity_id] = entity_id % 3

	for entity_id: int in participants:
		if entity_id != 1:
			_assert_reconnect_invariants(session, entity_id, entity_id, "active sparse participant %d" % entity_id)
	# A sentinel assignment rejects a repair that recomputes entity-id teams
	# instead of retaining the existing authority. It does not add a team mode.
	world.player(7).team_id = 4
	_assert_reconnect_invariants(session, 7, 4, "active round-owned nondefault team")
	world.player(7).team_id = 7
	# A pending respawn is round state too, not permission to reassign a team.
	world.player(4).health = 0
	session.session_round.respawn_tick_by_entity[4] = world.tick + session.session_round.respawn_ticks
	_assert_reconnect_invariants(session, 4, 4, "defeated active participant")

	equal(session.register_peers([{"entity_id": 3, "name": "Waiting Guest"}]), 1, "late observer uses one unoccupied identity, not a seventh round slot")
	var observer := world.player(3)
	if observer == null:
		return
	equal(observer.health, 0, "late observer remains health-zero outside the round")
	observer.team_id = 77
	_assert_reconnect_invariants(session, 3, 1, "active nonparticipant")
	check(session.input_locked(3), "resumed observer remains authority-input-locked")
	check(not session.session_round.scores_by_entity.has(3), "observer resume cannot enroll a participant")

	world.tick = session.session_round.round_end_tick
	session.advance_round([])
	equal(session.session_round.phase, SessionRound.Phase.RESULT, "timeout enters the real result path before result reconnects")
	for entity_id: int in participants:
		if entity_id != 1:
			_assert_reconnect_invariants(session, entity_id, entity_id, "result sparse participant %d" % entity_id)
	world.player(7).team_id = 4
	_assert_reconnect_invariants(session, 7, 4, "result round-owned nondefault team")
	world.player(7).team_id = 7
	observer.team_id = 77
	_assert_reconnect_invariants(session, 3, 1, "result nonparticipant")
	check(session.input_locked(3), "result observer stays input-locked after resume")

	# Bind the next Hearth phase directly: world reconstruction is separately
	# covered, while this fixture isolates phase-dependent resume assignment.
	session.session_round.bind_hearth()
	for entity_id: int in participants:
		if entity_id != 1:
			_assert_reconnect_invariants(session, entity_id, 1, "Hearth traveller %d" % entity_id)
	observer.team_id = 77
	_assert_reconnect_invariants(session, 3, 1, "Hearth former observer")
	check(not session.input_locked(3), "Hearth resume is no longer gated as a round observer")
	equal(session.remove_peers([{"entity_id": 3}]), 1, "waiting guest leaves before the six-person rematch")
	check(session.begin_round(definition), "same sparse six-person roster can begin the next round")
	equal(session.session_round.serial, 2, "reconnects do not consume or rewind the round serial")
	equal(session.session_round.spawn_by_entity, original_spawns, "next round preserves the deterministic sparse-roster spawn mapping")
	for entity_id: int in participants:
		check(world.player(entity_id) == actors[entity_id], "next round retains exact participant actor %d" % entity_id)
		equal(world.player(entity_id).team_id, entity_id, "next round owns participant team %d again" % entity_id)
		equal(int(session.session_round.scores_by_entity[entity_id]), 0, "next round resets participant score %d only at begin" % entity_id)
		check(world.player(entity_id).has_valid_spell_slots(), "next round keeps participant %d weave valid" % entity_id)


func _assert_reconnect_invariants(session: AuthoritativeSession, entity_id: int, expected_team: int, label: String) -> void:
	var actor := session.world.player(entity_id)
	check(actor != null, "%s has an existing actor" % label)
	if actor == null:
		return
	var expected_actor_values := actor.canonical_values()
	expected_actor_values[1] = expected_team
	var round_before := session.session_round.capture(session.world)
	check(SessionRound.validate_packet(round_before), "%s begins with a valid round packet" % label)
	var scores_before := session.session_round.scores_by_entity.duplicate()
	var spawns_before := session.session_round.spawn_by_entity.duplicate()
	var respawns_before := session.session_round.respawn_tick_by_entity.duplicate()
	var player_count_before := session.world.players.size()
	var player_name := String(session.names_by_entity[entity_id])
	session.last_processed_input_sequence_by_entity[entity_id] = 77
	equal(session.suspend_peers([{"entity_id": entity_id, "reserved": true}]), 1, "%s suspends its reserved presence" % label)
	check(session.world.player(entity_id) == actor, "%s suspension retains the exact actor" % label)
	equal(session.register_peers([{"entity_id": entity_id, "name": player_name, "resumed": true}]), 1, "%s resumes once" % label)
	check(session.world.player(entity_id) == actor, "%s resume retains the exact actor" % label)
	equal(actor.team_id, expected_team, "%s uses the correct phase-owned team" % label)
	equal(actor.canonical_values(), expected_actor_values, "%s preserves identity, position, health, resources, loadout and cooldowns" % label)
	equal(session.world.players.size(), player_count_before, "%s cannot duplicate the roster" % label)
	equal(session.session_round.scores_by_entity, scores_before, "%s preserves every round score" % label)
	equal(session.session_round.spawn_by_entity, spawns_before, "%s preserves every spawn assignment" % label)
	equal(session.session_round.respawn_tick_by_entity, respawns_before, "%s preserves pending respawn timing" % label)
	equal(session.session_round.capture(session.world), round_before, "%s preserves the complete round packet" % label)
	equal(int(session.last_processed_input_sequence_by_entity[entity_id]), -1, "%s resets only the reconnect input acknowledgement" % label)
	equal(int(session.hearth.presence_by_entity[entity_id]), SessionHearth.STATUS_CONNECTED, "%s reconnects Hearth presence" % label)
	check(not session.hearth.is_ready(entity_id), "%s requires fresh readiness" % label)
	equal(actor.last_event, "farflow_return", "%s retains ordinary reconnect feedback" % label)


func _test_hex_clash_outcome_delivery() -> void:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file(ABILITY_PATH), "abilities load for remote clash delivery")
	var champions := ChampionCatalog.new()
	check(champions.load_from_file(CHAMPION_PATH, abilities), "champions load for remote clash delivery")
	var world := SimWorld.new(120, 94, CollisionWorld.new(1_280_000, 960_000))
	check(champions.apply_to_player(world.player(), "oh_tipi"), "remote clash host champion applies")
	check(HexCourtPractice.configure(world, abilities, false), "remote clash fixture configures trusted hex authority")
	var session := AuthoritativeSession.new()
	check(session.bind(world, champions, Vector2i(640, 710), "Clash Host"), "remote clash authority binds")
	var source_wire: int = world.player().spell_wire_ids[0]
	var other_wire: int = world.player().spell_wire_ids[1]
	var cosmetic_fill: Array[Dictionary] = []
	for index: int in range(SessionSnapshot.MAX_EVENTS):
		cosmetic_fill.append({"type": "projectile_spawned", "projectile_id": 31_000 + index, "owner_id": 1, "wire_id": source_wire})
	equal(session.record_combat_events(cosmetic_fill), SessionSnapshot.MAX_EVENTS, "cosmetic events fill the bounded clash-delivery lane")
	var clash := {"type": "hex_clash", "source_wire_id": source_wire, "other_wire_id": other_wire,
		"x": 640_125, "y": 479_875, "first_remaining": 10, "second_remaining": 0}
	equal(session.record_combat_events([clash]), 1, "authority admits an encodable hex clash")
	equal(session.pending_combat_events.size(), SessionSnapshot.MAX_EVENTS, "outcome admission preserves the event-lane bound")
	equal(String(session.pending_combat_events.back().get("type", "")), "hex_clash", "hex clash outcome evicts older cosmetic feedback")
	equal(AuthoritativeSession._combat_event_priority(session.pending_combat_events.back()), AuthoritativeSession.EVENT_PRIORITY_OUTCOME, "hex clash is classified as outcome feedback")
	var envelope: Dictionary = session.capture_envelope()
	check(WorldSnapshotEnvelope.validate(envelope), "hex authority captures clash feedback in a validated unified envelope")
	if envelope.is_empty():
		return
	var wire_events: Array = WorldSnapshotEnvelope.events(envelope)
	equal(wire_events.size(), SessionSnapshot.MAX_EVENTS, "hex envelope carries the complete retained bounded event lane")
	var decoded: Dictionary = SessionSnapshot.decode_event(wire_events.back())
	for key: String in ["source_wire_id", "other_wire_id", "x", "y", "first_remaining", "second_remaining"]:
		equal(decoded.get(key), clash.get(key), "remote clash envelope preserves exact %s" % key)
	check(int(decoded.get("event_id", 0)) > 0, "remote clash envelope carries stable redundancy identity")


func _test_event_burst_overflow_contract() -> void:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file(ABILITY_PATH), "abilities load for event overflow contract")
	var champions := ChampionCatalog.new()
	check(champions.load_from_file(CHAMPION_PATH, abilities), "champions load for event overflow contract")
	var world := SimWorld.new(120, 92, CollisionWorld.new(3_000_000, 2_000_000))
	check(champions.apply_to_player(world.player(), "oh_tipi"), "event overflow host champion applies")
	world.player().health -= 17_000
	var expected_health := world.player().health
	var session := AuthoritativeSession.new()
	check(session.bind(world, champions, Vector2i(1280, 720), "Overflow Host"), "event overflow authority binds")
	var burst: Array[Dictionary] = [
		{"type": "cast_refused", "entity_id": 1, "wire_id": CombatTuning.ECLIPSE_DISC_WIRE_ID, "reason": "flux"},
		{"type": "request_refused", "entity_id": 1, "action": SessionTransport.REQUEST_READY_TOGGLE, "reason": 1},
		{"type": "round_finished", "winner_id": 1},
	]
	for noise_index: int in range(15):
		burst.append({"type": "projectile_spawned", "projectile_id": 10_000 + noise_index, "owner_id": 1, "wire_id": CombatTuning.ECLIPSE_DISC_WIRE_ID})
	equal(session.record_combat_events(burst), burst.size(), "authority accepts every encodable event before bounded prioritization")
	equal(session.pending_combat_events.size(), SessionSnapshot.MAX_EVENTS, "event burst retains exactly the bounded snapshot lane")

	# The first snapshot is intentionally not applied, modelling loss after a
	# successful host send. Acknowledgement advances the existing redundancy lane.
	var lost_snapshot := session.capture_snapshot()
	check(SessionSnapshot.validate(lost_snapshot), "event burst first snapshot validates before simulated loss")
	equal(int((lost_snapshot["overflow"] as PackedInt32Array)[2]), burst.size() - SessionSnapshot.MAX_EVENTS, "event burst reports exact concealed feedback loss")
	session.acknowledge_snapshot()

	var delivered_snapshot := session.capture_snapshot()
	check(SessionSnapshot.validate(delivered_snapshot), "redundant event snapshot remains valid after one lost send")
	equal(int((delivered_snapshot["overflow"] as PackedInt32Array)[2]), burst.size() - SessionSnapshot.MAX_EVENTS, "overflow accounting shares the event redundancy window")
	var replica := SimWorld.new(120, 93, CollisionWorld.new(3_000_000, 2_000_000))
	check(SessionSnapshot.apply_to_world(delivered_snapshot, replica), "client applies the real redundant snapshot entry path")
	equal(replica.player().health, expected_health, "event trimming cannot alter authoritative gameplay health")
	var inbox := SessionEventInbox.new()
	var unseen := inbox.take_unseen(replica.combat_events)
	equal(unseen.size(), SessionSnapshot.MAX_EVENTS, "client inbox receives the complete retained bounded event lane")
	var unseen_types: Array[String] = []
	var previous_event_id := 0
	for event: Dictionary in unseen:
		unseen_types.append(String(event.get("type", "")))
		check(int(event.get("event_id", 0)) > previous_event_id, "prioritized events preserve chronological event-id order")
		previous_event_id = int(event.get("event_id", 0))
	check(unseen_types.has("cast_refused"), "actionable cast refusal survives a later cosmetic burst")
	check(unseen_types.has("request_refused"), "actionable request refusal survives a later cosmetic burst")
	check(unseen_types.has("round_finished"), "round outcome survives a later cosmetic burst")

	session.acknowledge_snapshot()
	var redundant_snapshot := session.capture_snapshot()
	check(SessionSnapshot.apply_to_world(redundant_snapshot, replica), "client applies a later redundant event snapshot")
	equal(inbox.take_unseen(replica.combat_events).size(), 0, "event inbox deduplicates the retained burst after packet loss recovery")
	equal(int((redundant_snapshot["overflow"] as PackedInt32Array)[2]), burst.size() - SessionSnapshot.MAX_EVENTS, "loss count remains explicit on the third redundant snapshot")
	session.acknowledge_snapshot()
	var final_redundant_snapshot := session.capture_snapshot()
	equal((final_redundant_snapshot.get("events", []) as Array).size(), SessionSnapshot.MAX_EVENTS, "retained feedback reaches the fourth redundancy snapshot")
	equal(int((final_redundant_snapshot["overflow"] as PackedInt32Array)[2]), burst.size() - SessionSnapshot.MAX_EVENTS, "loss count reaches the fourth redundancy snapshot")
	session.acknowledge_snapshot()
	var expired_snapshot := session.capture_snapshot()
	equal((expired_snapshot.get("events", []) as Array).size(), 0, "retained event burst expires after four acknowledged snapshots")
	equal(int((expired_snapshot["overflow"] as PackedInt32Array)[2]), 0, "event loss notice expires with its bounded redundancy window")

	check(session.bind(world, champions, Vector2i(1280, 720), "Overflow Host"), "event policy resets for incoming-priority coverage")
	var actionable_fill: Array[Dictionary] = []
	for event_index: int in range(SessionSnapshot.MAX_EVENTS):
		actionable_fill.append({"type": "ready_changed", "entity_id": 1, "ready": event_index % 2 == 0})
	equal(session.record_combat_events(actionable_fill), SessionSnapshot.MAX_EVENTS, "actionable fixture fills the bounded lane")
	var actionable_ids_before := PackedInt32Array()
	for event: Dictionary in session.pending_combat_events:
		actionable_ids_before.append(int(event.get("event_id", 0)))
	equal(session.record_combat_events([{"type": "projectile_spawned", "projectile_id": 20_000, "owner_id": 1, "wire_id": CombatTuning.ECLIPSE_DISC_WIRE_ID}]), 1, "valid low-priority event reaches saturated admission policy")
	equal(session.pending_combat_events.size(), SessionSnapshot.MAX_EVENTS, "discarding incoming cosmetic feedback preserves the lane bound")
	var actionable_ids_after := PackedInt32Array()
	for event: Dictionary in session.pending_combat_events:
		actionable_ids_after.append(int(event.get("event_id", 0)))
	equal(actionable_ids_after, actionable_ids_before, "incoming cosmetic feedback cannot evict a full actionable lane")
	equal(session.pending_combat_event_overflow_count, 1, "discarded incoming cosmetic feedback increments explicit loss")

	check(session.bind(world, champions, Vector2i(1280, 720), "Overflow Host"), "event policy resets for equal-priority ordering coverage")
	var equal_priority_burst: Array[Dictionary] = []
	for event_index: int in range(SessionSnapshot.MAX_EVENTS + 1):
		equal_priority_burst.append({"type": "projectile_spawned", "projectile_id": 21_000 + event_index, "owner_id": 1, "wire_id": CombatTuning.ECLIPSE_DISC_WIRE_ID})
	equal(session.record_combat_events(equal_priority_burst), equal_priority_burst.size(), "equal-priority burst reaches bounded admission")
	equal(int(session.pending_combat_events.front().get("projectile_id", 0)), 21_001, "equal-priority overflow evicts the oldest event")
	equal(int(session.pending_combat_events.back().get("projectile_id", 0)), 21_012, "equal-priority overflow retains the newest event")
	var previous_projectile_id := 0
	for event: Dictionary in session.pending_combat_events:
		check(int(event.get("projectile_id", 0)) > previous_projectile_id, "equal-priority retention preserves chronological order")
		previous_projectile_id = int(event.get("projectile_id", 0))

	var remaining_before_ack := int(session.pending_combat_events.front().get("_remaining_snapshots", 0))
	session.acknowledge_snapshot()
	equal(int(session.pending_combat_events.front().get("_remaining_snapshots", 0)), remaining_before_ack, "acknowledgement without capture cannot age pending feedback")
	equal(session.pending_combat_event_overflow_count, 1, "acknowledgement without capture cannot clear loss accounting")
	equal(session.pending_combat_event_overflow_remaining_snapshots, AuthoritativeSession.EVENT_REDUNDANCY_SNAPSHOTS, "acknowledgement without capture cannot age the loss notice")
	check(SessionSnapshot.validate(session.capture_snapshot()), "equal-priority lane captures before acknowledged aging")
	session.acknowledge_snapshot()
	equal(session.pending_combat_event_overflow_remaining_snapshots, AuthoritativeSession.EVENT_REDUNDANCY_SNAPSHOTS - 1, "successful snapshot acknowledgement ages the loss notice once")
	equal(session.record_combat_events([{"type": "projectile_spawned", "projectile_id": 21_013, "owner_id": 1, "wire_id": CombatTuning.ECLIPSE_DISC_WIRE_ID}]), 1, "continuous cosmetic noise reaches the saturated lane")
	equal(session.pending_combat_event_overflow_count, 2, "continuous noise counts loss within the active notice window")
	equal(session.pending_combat_event_overflow_remaining_snapshots, AuthoritativeSession.EVENT_REDUNDANCY_SNAPSHOTS, "new loss refreshes the bounded notice window")

	session.pending_combat_event_overflow_count = SessionSnapshot.MAX_EVENT_ID - 1
	equal(session.record_combat_events([
		{"type": "projectile_spawned", "projectile_id": 21_014, "owner_id": 1, "wire_id": CombatTuning.ECLIPSE_DISC_WIRE_ID},
		{"type": "projectile_spawned", "projectile_id": 21_015, "owner_id": 1, "wire_id": CombatTuning.ECLIPSE_DISC_WIRE_ID},
	]), 2, "loss saturation fixture drops two more valid cosmetic events")
	equal(session.pending_combat_event_overflow_count, SessionSnapshot.MAX_EVENT_ID, "feedback loss count saturates at the existing nonnegative int32 wire bound")
	check(SessionSnapshot.validate(session.capture_snapshot()), "saturated loss count still produces a validated snapshot")
	equal(int((session.capture_snapshot()["overflow"] as PackedInt32Array)[2]), SessionSnapshot.MAX_EVENT_ID, "saturated loss count is represented exactly on the existing wire field")

	check(session.bind(world, champions, Vector2i(1280, 720), "Overflow Host"), "binding a new authority lifecycle succeeds after saturated noise")
	equal(session.pending_combat_events.size(), 0, "authority bind clears pending feedback")
	equal(session.pending_combat_event_overflow_count, 0, "authority bind clears feedback loss count")
	equal(session.pending_combat_event_overflow_remaining_snapshots, 0, "authority bind clears feedback loss redundancy")
	check(not session.snapshot_capture_pending_ack, "authority bind clears pending snapshot acknowledgement state")

	var pre_capture_fill: Array[Dictionary] = []
	for event_index: int in range(SessionSnapshot.MAX_EVENTS):
		pre_capture_fill.append({"type": "projectile_spawned", "projectile_id": 22_000 + event_index, "owner_id": 1, "wire_id": CombatTuning.ECLIPSE_DISC_WIRE_ID})
	equal(session.record_combat_events(pre_capture_fill), SessionSnapshot.MAX_EVENTS, "acknowledgement race fixture fills one captured event lane")
	check(SessionSnapshot.validate(session.capture_snapshot()), "acknowledgement race fixture captures the original lane")
	equal(session.record_combat_events([{"type": "projectile_spawned", "projectile_id": 22_012, "owner_id": 1, "wire_id": CombatTuning.ECLIPSE_DISC_WIRE_ID}]), 1, "post-capture mutation replaces one event and opens an overflow notice")
	check(not session.snapshot_capture_pending_ack, "post-capture event mutation invalidates the stale acknowledgement token")
	session.acknowledge_snapshot()
	for event: Dictionary in session.pending_combat_events:
		equal(int(event.get("_remaining_snapshots", 0)), AuthoritativeSession.EVENT_REDUNDANCY_SNAPSHOTS, "stale acknowledgement cannot age an event absent from its capture")
	equal(session.pending_combat_event_overflow_count, 1, "stale acknowledgement cannot clear post-capture loss")
	equal(session.pending_combat_event_overflow_remaining_snapshots, AuthoritativeSession.EVENT_REDUNDANCY_SNAPSHOTS, "stale acknowledgement cannot age a post-capture overflow generation")
	check(SessionSnapshot.validate(session.capture_snapshot()), "mutated lane captures again before safe acknowledgement")
	session.acknowledge_snapshot()
	for event: Dictionary in session.pending_combat_events:
		equal(int(event.get("_remaining_snapshots", 0)), AuthoritativeSession.EVENT_REDUNDANCY_SNAPSHOTS - 1, "fresh acknowledgement ages the recaptured lane exactly once")
	equal(session.pending_combat_event_overflow_remaining_snapshots, AuthoritativeSession.EVENT_REDUNDANCY_SNAPSHOTS - 1, "fresh acknowledgement ages the recaptured overflow generation exactly once")


func _test_hitch_input_coalescing_contract() -> void:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file(ABILITY_PATH), "abilities load for hitch input contract")
	var champions := ChampionCatalog.new()
	check(champions.load_from_file(CHAMPION_PATH, abilities), "champions load for hitch input contract")
	var world := SimWorld.new(120, 91, CollisionWorld.new(3_000_000, 2_000_000))
	check(champions.apply_to_player(world.player(), "oh_tipi"), "hitch contract host champion applies")
	var session := AuthoritativeSession.new()
	check(session.bind(world, champions, Vector2i(1280, 720), "Hitch Host"), "hitch authority binds")
	equal(session.register_peers([{"peer_id": 42, "entity_id": 2, "name": "Burst Guest"}]), 1, "hitch authority registers the remote lane")
	var saturation_packets: Array[Dictionary] = [
		{"peer_id": 42, "entity_id": 2, "sequence": 1, "move_x": 100, "move_y": 0, "held": SimCommand.HELD_JUMP, "pressed": SimCommand.PRESSED_JUMP, "aim_x": 1000, "aim_y": 0},
		{"peer_id": 42, "entity_id": 2, "sequence": 2, "move_x": 200, "move_y": 0, "held": SimCommand.HELD_SPRINT, "pressed": SimCommand.PRESSED_EVADE, "aim_x": 1000, "aim_y": 0},
		{"peer_id": 42, "entity_id": 2, "sequence": 3, "move_x": 300, "move_y": 0, "held": SimCommand.HELD_PRIMARY, "pressed": 0, "aim_x": 1000, "aim_y": 0},
		{"peer_id": 42, "entity_id": 2, "sequence": 4, "move_x": 400, "move_y": 0, "held": SimCommand.HELD_PRIMARY, "pressed": SimCommand.PRESSED_SPELL_1, "aim_x": 1000, "aim_y": 0},
		{"peer_id": 42, "entity_id": 2, "sequence": 5, "move_x": 450, "move_y": -450, "held": SimCommand.HELD_SPRINT, "pressed": 0, "aim_x": 0, "aim_y": -1000},
		{"peer_id": 42, "entity_id": 2, "sequence": 6, "move_x": 500, "move_y": -500, "held": SimCommand.HELD_SPRINT | SimCommand.HELD_PRIMARY, "pressed": 0, "aim_x": 0, "aim_y": -1000, "aim_target_x": 1_000_000, "aim_target_y": 700_000},
	]
	var saturated_transport := SessionTransport.new()
	for packet: Dictionary in saturation_packets:
		saturated_transport._queue_input(42, packet)
	var packets := saturated_transport.take_inputs()
	equal(packets.size(), SessionTransport.MAX_QUEUED_INPUTS_PER_PEER, "authority fixture consumes the real saturated transport lane")
	equal(session.ingest_inputs(packets), packets.size(), "hitch authority accepts the retained remote lane")
	var commands := session.commands_for_tick(SimCommand.new(world.tick, 1))
	var remote: SimCommand = commands[1]
	var expected_pressed := SimCommand.PRESSED_JUMP | SimCommand.PRESSED_EVADE | SimCommand.PRESSED_SPELL_1
	equal(remote.pressed_actions, expected_pressed, "authority delivers jump, evade and cast edges on the next real tick")
	equal(remote.held_actions, SimCommand.HELD_SPRINT | SimCommand.HELD_PRIMARY, "authority resolves held actions to the newest input")
	equal(Vector2i(remote.move_x, remote.move_y), Vector2i(500, -500), "authority resolves movement to the newest input")
	equal(Vector2i(remote.aim_x, remote.aim_y), Vector2i(0, -1000), "authority resolves aim to the newest input")
	equal(Vector2i(remote.aim_target_x, remote.aim_target_y), Vector2i(1_000_000, 700_000), "authority retains the newest world aim target")
	equal(int(session.last_processed_input_sequence_by_entity.get(2, -1)), 6, "authority acknowledges the newest retained sequence after repeated saturation")
	var next_commands := session.commands_for_tick(SimCommand.new(world.tick, 1))
	equal(next_commands[1].pressed_actions, 0, "coalesced edges are consumed once without adding simulation ticks")
	equal(next_commands[1].held_actions, SimCommand.HELD_SPRINT | SimCommand.HELD_PRIMARY, "newest held actions continue on the next tick")


func _test_authoritative_presence_and_input() -> void:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file(ABILITY_PATH), "abilities load for authoritative session")
	var champions := ChampionCatalog.new()
	check(champions.load_from_file(CHAMPION_PATH, abilities), "champions load for authoritative session")
	var world := SimWorld.new(120, 9, CollisionWorld.new(3_000_000, 2_000_000))
	check(champions.apply_to_player(world.player(), "oh_tipi"), "host champion applies")
	var session := AuthoritativeSession.new()
	check(session.bind(world, champions, Vector2i(1280, 720), "Lantern Host"), "authoritative session binds")
	equal(session.register_peers([{"peer_id": 42, "entity_id": 2, "name": "River Guest"}]), 1, "accepted peer registers once")
	equal(session.register_peers([{"peer_id": 42, "entity_id": 2, "name": "River Guest"}]), 0, "duplicate entity registration is ignored")
	var guest: PlayerState = world.player(2)
	check(guest != null, "guest owns a host-side simulation actor")
	if guest != null:
		equal(guest.champion_wire_id, 2, "first guest receives S. Wayne for a distinct two-character test")
		equal(Vector2i(guest.position_x, guest.position_y), Vector2i(1_352_000, 720_000), "guest receives deterministic collision-cleared spawn offset")
		equal(guest.team_id, 1, "Open Commons prevents traveller damage with a shared host-owned team")
	check(session.set_charter("sparring_circle"), "host authority can seal a known sparring charter")
	equal(world.player().team_id, 1, "sparring host keeps its stable combat team")
	equal(world.player(2).team_id, 2, "sparring guest receives an individual combat team")
	check(not session.set_charter("forged"), "unknown charter cannot mutate authority teams")
	equal(session.hearth.connected_count(), 2, "authority Hearth tracks host and accepted guest")
	check(session.toggle_ready(1) and session.toggle_ready(2), "both authoritative travellers can ready")
	check(session.can_start_practice(), "authority exposes all-ready start gate")
	check(session.start_practice_countdown(1), "authority host starts a deterministic practice countdown")
	check(session.practice_countdown_active(), "authority owns active countdown state")
	check(session.hearth.cancel_countdown(), "test fixture cancels countdown before movement exercise")
	var round_definition := {
		"bounds": [400, 300, 1200, 900],
		"score_limit": 3,
		"round_seconds": 15,
		"result_seconds": 2,
		"respawn_ms": 500,
		"spawn_protection_ms": 250,
		"spawns": [[500, 400], [1500, 1100]],
	}
	check(session.begin_round(round_definition), "authority starts a court from the connected Hearth roster")
	equal(session.session_round.phase, SessionRound.Phase.ACTIVE, "authority owns active round phase")
	equal(world.player(2).team_id, 2, "court makes the remote traveller independently damageable")

	var packet := {
		"entity_id": 2,
		"sequence": 1,
		"move_x": 1000,
		"move_y": 0,
		"held": SimCommand.HELD_JUMP,
		"pressed": SimCommand.PRESSED_JUMP,
		"aim_x": 1000,
		"aim_y": 0,
		"aim_target_x": 1_500_000,
		"aim_target_y": 750_000,
	}
	equal(session.ingest_inputs([packet]), 1, "validated transport input enters authority controller")
	var commands := session.commands_for_tick(SimCommand.new(world.tick, 1))
	equal(commands.size(), 2, "authority emits one ordered command per traveller")
	equal(Vector2i(commands[1].aim_target_x, commands[1].aim_target_y), Vector2i(1_500_000, 750_000), "authority preserves the accepted remote world target")
	var copied_command := commands[1].copy()
	equal(Vector2i(copied_command.aim_target_x, copied_command.aim_target_y), Vector2i(1_500_000, 750_000), "command copying cannot drop the captured world target")
	check(world.step(commands), "host simulates both travellers in one tick")
	check(world.player(2).position_x > 1_352_000, "remote input moves only through host simulation")
	check(world.player(2).jumpsquat_active and not world.player(2).is_airborne(), "remote held jump prepares through the shared movement grammar")
	var reconciliation := session.capture_reconciliation(2)
	check(ClientPrediction.validate_packet(reconciliation), "authority emits a validated movement reconciliation")
	equal(int(reconciliation.get("sequence", -1)), 1, "reconciliation acknowledges the input sequence actually processed")
	var reconciliation_values: PackedInt64Array = reconciliation.get("values", PackedInt64Array())
	equal(int(reconciliation_values[0]) if not reconciliation_values.is_empty() else 0, 2, "reconciliation is scoped to one remote traveller")
	var second_commands := session.commands_for_tick(SimCommand.new(world.tick, 1))
	equal(second_commands[1].pressed_actions, 0, "remote pressed action is consumed exactly once")
	check(world.step(second_commands), "held remote command continues on the next tick")
	var released_packet := packet.duplicate(true)
	released_packet["sequence"] = 2
	released_packet["held"] = 0
	released_packet["pressed"] = 0
	equal(session.ingest_inputs([released_packet]), 1, "remote release enters authority")
	check(world.step(session.commands_for_tick(SimCommand.new(world.tick, 1))), "remote release advances authority")
	check(world.player(2).is_airborne(), "remote release launches exactly one real jump")
	for _index: int in range(world.config.milliseconds_to_ticks(AuthoritativeSession.REMOTE_INPUT_TIMEOUT_MS) + 2):
		check(world.step(session.commands_for_tick(SimCommand.new(world.tick, 1))), "host advances toward remote input timeout")
	var stale_commands := session.commands_for_tick(SimCommand.new(world.tick, 1))
	equal(stale_commands[1].move_x, 0, "stale remote movement fails safe to idle")
	equal(stale_commands[1].held_actions, 0, "stale remote held actions fail safe to idle")

	equal(session.record_combat_events([{"type": "cast_started", "entity_id": 2, "wire_id": CombatTuning.ECLIPSE_DISC_WIRE_ID}]), 1, "semantic host combat event enters the next snapshot")
	var snapshot := session.capture_snapshot()
	check(SessionSnapshot.validate(snapshot), "authority emits a validated roster snapshot")
	equal((SessionSnapshot.hearth(snapshot).get("entries", []) as Array).size(), 2, "authority snapshot carries Hearth roster state")
	equal(int(SessionSnapshot.round_state(snapshot).get("phase", -1)), SessionRound.Phase.ACTIVE, "authority snapshot carries live court state")
	equal(session.register_peers([{"peer_id": 45, "entity_id": 3, "name": "Late Guest"}]), 1, "active authority admits a late friend for the next gathering")
	equal(world.player(3).health, 0, "late friend waits safely instead of entering the active result space")
	equal(world.player(3).last_event, "round_wait", "late friend receives a readable next-round state")
	var forged_late_input := {
		"entity_id": 3,
		"sequence": 1,
		"move_x": 1000,
		"move_y": -1000,
		"held": SimCommand.HELD_PRIMARY | SimCommand.HELD_SPRINT,
		"pressed": SimCommand.PRESSED_ACTIVE_1 | SimCommand.PRESSED_JUMP,
		"aim_x": -1000,
		"aim_y": 0,
	}
	equal(session.ingest_inputs([forged_late_input]), 1, "late spectator packet reaches host-owned command policy")
	var late_commands := session.commands_for_tick(SimCommand.new(world.tick, 1))
	equal(late_commands.size(), 3, "authority emits a command lane for the waiting actor")
	equal(late_commands[2].move_x, 0, "nonparticipant movement is neutralized by host authority")
	equal(late_commands[2].move_y, 0, "nonparticipant diagonal movement is neutralized")
	equal(late_commands[2].held_actions, 0, "nonparticipant held casts and sprint are neutralized")
	equal(late_commands[2].pressed_actions, SimCommand.PRESSED_CANCEL_MOVEMENT, "nonparticipant paid actions become only safe movement cancellation")
	equal(int(session.last_processed_input_sequence_by_entity.get(3, -1)), -1, "neutralized spectator input is never acknowledged as simulated")
	var late_snapshot := session.capture_snapshot()
	check(SessionSnapshot.validate(late_snapshot), "late friend and active round subset share a valid snapshot")
	equal((SessionSnapshot.round_state(late_snapshot).get("entries", []) as Array).size(), 2, "late friend cannot become an unspawned round participant")
	equal(session.remove_peers([{"entity_id": 3, "name": "Late Guest"}]), 1, "late waiting friend leaves cleanly")
	session.session_round.phase = SessionRound.Phase.RESULT
	var locked_commands := session.commands_for_tick(SimCommand.new(world.tick, 1, 1000, 0, SimCommand.HELD_PRIMARY, SimCommand.PRESSED_ACTIVE_1))
	equal(locked_commands[0].move_x, 0, "court result rejects host movement input")
	equal(locked_commands[0].held_actions, 0, "court result rejects host cast input")
	equal(locked_commands[1].move_x, 0, "court result rejects queued guest movement input")
	session.session_round.phase = SessionRound.Phase.ACTIVE
	var rebound_world := SimWorld.new(120, 10, CollisionWorld.new(3_000_000, 2_000_000))
	check(champions.apply_to_player(rebound_world.player(), "oh_tipi"), "rebind host champion applies")
	var rebound := AuthoritativeSession.new()
	check(rebound.bind(rebound_world, champions, Vector2i(1280, 720), "Lantern Host", [{"entity_id": 2, "name": "River Guest", "reserved": false}], "open_commons"), "authority rebind preserves a connected live roster")
	equal(rebound.hearth.connected_count(), 2, "rebound Hearth preserves connected presence")
	equal(SessionSnapshot.names(snapshot), {1: "Lantern Host", 2: "River Guest"}, "snapshot exposes authoritative presence names")
	equal((snapshot.get("events", []) as Array).size(), 1, "pending combat feedback is included once")
	var decoded_event := SessionSnapshot.decode_event((snapshot["events"] as Array)[0])
	check(int(decoded_event.get("event_id", 0)) > 0, "authority assigns a stable semantic event identity")
	for resend_index: int in range(AuthoritativeSession.EVENT_REDUNDANCY_SNAPSHOTS - 1):
		session.acknowledge_snapshot()
		var redundant_snapshot := session.capture_snapshot()
		equal((redundant_snapshot.get("events", []) as Array).size(), 1, "semantic event remains for redundancy snapshot %d" % (resend_index + 2))
	session.acknowledge_snapshot()
	equal((session.capture_snapshot().get("events", []) as Array).size(), 0, "bounded redundant combat feedback expires")
	equal(session.remove_peers([{"entity_id": 2, "name": "River Guest"}]), 1, "disconnect removes the remote actor")
	check(world.player(2) == null, "removed remote actor leaves no simulation ghost")
	equal(session.session_round.phase, SessionRound.Phase.RESULT, "last active rival leaving resolves the court for the survivor")
	equal(session.session_round.winner_entity_id, 1, "remaining host receives the bounded departure result")
	check(SessionSnapshot.validate(session.capture_snapshot()), "departure result remains snapshot-valid after actor removal")
	check(session.capture_reconciliation(2).is_empty(), "removed traveller leaves no reconciliation state")
	equal(session.register_peers([{"peer_id": 43, "entity_id": 2, "name": "River Guest"}]), 1, "removed traveller can join again")
	var returning_state: PlayerState = world.player(2)
	returning_state.position_x += 17_000
	returning_state.health -= 4_000
	equal(session.suspend_peers([{"entity_id": 2, "name": "River Guest", "reserved": true}]), 1, "reserved disconnect suspends actor instead of removing it")
	equal(session.hearth.returning_count(), 1, "reserved disconnect remains visible at the Hearth")
	check(world.player(2) == returning_state, "suspended return keeps the exact authoritative actor")
	equal(session.register_peers([{"peer_id": 44, "entity_id": 2, "name": "River Guest", "resumed": true}]), 1, "resumed presence reclaims suspended actor")
	equal(session.hearth.connected_count(), 2, "resumed identity returns to connected Hearth presence")
	check(world.player(2) == returning_state, "resumed identity preserves position, health and champion state")
	equal(world.player(2).health, returning_state.health, "resumed identity keeps authoritative health")
