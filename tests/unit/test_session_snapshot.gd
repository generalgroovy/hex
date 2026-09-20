extends FluxTestSuite


const TIDE_SHELL_WIRE_ID: int = 181
const NIGHT_SHELL_WIRE_ID: int = 193


func run() -> int:
	_test_snapshot_round_trip()
	_test_movement_presentation_round_trip()
	_test_projectile_and_event_round_trip()
	_test_hex_clash_event_round_trip()
	_test_reaction_strength_round_trip_and_validation()
	_test_boundary_impacts()
	_test_retired_field_snapshot_rejected()
	_test_event_inbox_deduplicates_redundancy()
	_test_maximum_envelope_fits_transport()
	_test_fragment_assembly_faults()
	_test_snapshot_validation_fails_closed()
	_test_complete_chemistry_envelope()
	_test_trail_snapshot_limits()
	return finish("session-snapshot")


func _test_boundary_impacts() -> void:
	for axis: int in range(2):
		var world := SimWorld.new(120, 77, CollisionWorld.new(3_000_000, 2_000_000))
		world.player().champion_wire_id = 1
		var start := Vector2i(2_998_000, 1_000_000) if axis == 0 else Vector2i(1_500_000, 1_998_000)
		var velocity := Vector2i(600_000, 0) if axis == 0 else Vector2i(0, 600_000)
		var projectile := ProjectileState.new(1000, 1, 1, CombatTuning.RILLSHOT_WIRE_ID, 2, start, velocity, 1000, 1000, 120)
		world.projectiles.append(projectile)
		check(world.step([]), "production boundary collision advances")
		var impacts := 0
		for event: Dictionary in world.combat_events:
			if String(event.get("type", "")) == "projectile_impact":
				impacts += 1
				equal(event.wall_id, -1 - axis, "production impact retains the exact boundary sentinel")
				equal(SessionSnapshot.decode_event(SessionSnapshot.encode_event(event)).wall_id, -1 - axis, "boundary impact event roundtrips")
		equal(impacts, 1, "one real projectile reaches the selected boundary")
		var snapshot := SessionSnapshot.capture(world, {}, world.combat_events)
		check(SessionSnapshot.validate(snapshot), "boundary impact cannot poison the complete authoritative snapshot")
		check(not SessionTransport._snapshot_wire_packets(snapshot).is_empty(), "boundary impact snapshot packs for transport")
	for kind: String in ["projectile_impact", "projectile_bounced"]:
		for wall: int in [-3, -2, -1, 0, 7]:
			var event := SessionSnapshot.encode_event({"type":kind, "projectile_id":1000, "wall_id":wall, "remaining_bounces":1})
			equal(SessionSnapshot._valid_event_values(event), wall != -3, "only authored boundary sentinels extend ordinary wall admission")


func _test_hex_clash_event_round_trip() -> void:
	var event := {
		"type": "hex_clash", "event_id": 77,
		"source_wire_id": CombatTuning.RILLSHOT_WIRE_ID,
		"other_wire_id": CombatTuning.CINDERBOLT_WIRE_ID,
		"x": -17_250_000, "y": 91_500_000,
		"first_remaining": 10, "second_remaining": 0,
	}
	var encoded: PackedInt64Array = SessionSnapshot.encode_event(event)
	equal(encoded.size(), 8, "hex clash uses the existing maximum eight-value event row")
	check(SessionSnapshot._valid_event_values(encoded), "exact hex clash row validates")
	equal(SessionSnapshot.decode_event(encoded), event, "guest receives exact clash contact, wires, remaining strengths, and event identity")
	for missing_key: String in ["source_wire_id", "other_wire_id", "x", "y", "first_remaining", "second_remaining"]:
		var missing: Dictionary = event.duplicate(true)
		missing.erase(missing_key)
		check(SessionSnapshot.encode_event(missing).is_empty(), "hex clash refuses missing %s instead of silently filling zero" % missing_key)
	var coerced: Dictionary = event.duplicate(true)
	coerced["x"] = float(event.x)
	check(SessionSnapshot.encode_event(coerced).is_empty(), "hex clash refuses a coerced contact coordinate")
	var malformed_rows: Array[PackedInt64Array] = []
	malformed_rows.append(encoded.slice(0, 7))
	for mutation: Vector2i in [
		Vector2i(1, 0), Vector2i(2, 65_536),
		Vector2i(3, SessionSnapshot.MAX_ABSOLUTE_POSITION + 1),
		Vector2i(4, -SessionSnapshot.MAX_ABSOLUTE_POSITION - 1),
		Vector2i(5, -1), Vector2i(6, 16), Vector2i(7, 1),
	]:
		var malformed: PackedInt64Array = encoded.duplicate()
		malformed[mutation.x] = mutation.y
		malformed_rows.append(malformed)
	for row: PackedInt64Array in malformed_rows:
		check(not SessionSnapshot._valid_event_values(row), "malformed hex clash row fails closed")


func _test_snapshot_round_trip() -> void:
	equal(SessionSnapshot.SCHEMA_VERSION, 21, "remote hex-clash feedback owns the explicit snapshot schema21 boundary")
	var source := SimWorld.new(120, 7, CollisionWorld.new(3_000_000, 2_000_000))
	var host: PlayerState = source.player()
	host.champion_wire_id = 1
	host.position_x = 1_280_000
	host.position_y = 720_000
	host.health = 87_000
	host.primary_wire_id = CombatTuning.RILLSHOT_WIRE_ID
	host.active_1_wire_id = CombatTuning.TIDELINE_WIRE_ID
	host.active_2_wire_id = TIDE_SHELL_WIRE_ID
	host.reset_spell_slots_to_kit()
	check(host.place_proven_spell(11, host.primary_wire_id), "host rewoves primary to Alt+4 before snapshot")
	check(host.set_spell_cooldown(CombatTuning.CINDERBOLT_WIRE_ID, 17), "host owns a cooldown for a non-champion global spell")
	var guest := PlayerState.new(2)
	guest.champion_wire_id = 2
	guest.position_x = 1_352_000
	guest.position_y = 720_000
	guest.movement_mode = PlayerState.MovementMode.SPRINT
	guest.sprinting = true
	guest.health_maximum = 90_000
	guest.health = 72_000
	guest.flux_maximum = 112_000
	guest.flux = 54_000
	guest.stamina_maximum = 96_000
	guest.stamina = 33_000
	guest.jump_sustain_ticks = 12
	guest.movement_chain_count = 3
	guest.movement_chain_reset_ticks = 31
	guest.movement_action_speed = 777_000
	guest.spawn_protection_ticks = 77
	guest.primary_wire_id = CombatTuning.ECLIPSE_DISC_WIRE_ID
	guest.active_1_wire_id = NIGHT_SHELL_WIRE_ID
	guest.reset_spell_slots_to_kit()
	source.players.append(guest)
	var source_target := PlayerState.new(900)
	source_target.actor_kind = PlayerState.ActorKind.TRAINING_TARGET
	source_target.position_x = 1_500_000
	source_target.position_y = 720_000
	source_target.radius = 18_000
	source_target.health_maximum = 80_000
	source_target.health = 51_000
	source_target.health_recovery_per_second = 0
	source.players.append(source_target)
	check(source.step([SimCommand.new(0, 1), SimCommand.new(0, 2, 1000, 0, SimCommand.HELD_SPRINT)]), "authoritative source advances before capture")
	var snapshot := SessionSnapshot.capture(source, {1: "Lantern Host", 2: "River Guest"})
	check(SessionSnapshot.validate(snapshot), "bounded two-player snapshot validates")
	equal(int(snapshot.get("tick", -1)), source.tick, "snapshot owns the authoritative post-step tick")
	var encoded := var_to_bytes(snapshot)
	check(encoded.size() < SessionTransport.MAX_PACKET_BYTES, "two-player snapshot fits the transport packet budget")

	var replica := SimWorld.new(120, 7, CollisionWorld.new(3_000_000, 2_000_000))
	var target := PlayerState.new(900)
	target.actor_kind = PlayerState.ActorKind.TRAINING_TARGET
	replica.players.append(target)
	check(SessionSnapshot.apply_to_world(snapshot, replica), "validated snapshot applies to a replica")
	equal(replica.tick, source.tick, "replica adopts host tick")
	equal(replica.player(2).position_x, source.player(2).position_x, "guest authoritative position round-trips")
	equal(replica.player(2).movement_mode, PlayerState.MovementMode.SPRINT, "guest movement mode round-trips")
	equal(replica.player(2).primary_wire_id, CombatTuning.ECLIPSE_DISC_WIRE_ID, "guest kit identity round-trips")
	equal(Array(replica.player().spell_wire_ids), Array(source.player().spell_wire_ids), "host ordered spell slots round-trip")
	equal(Array(replica.player().spell_cooldown_ticks), Array(source.player().spell_cooldown_ticks), "all independent spell cooldowns round-trip")
	equal(replica.player().spell_cooldown_for_wire(CombatTuning.CINDERBOLT_WIRE_ID), 16, "non-champion global cooldown survives one source tick and replication")
	equal(replica.player().active_2_wire_id, TIDE_SHELL_WIRE_ID, "host retained Heavy identity round-trips as the third proven spell")
	equal(replica.player(2).spawn_protection_ticks, source.player(2).spawn_protection_ticks, "guest spawn protection round-trips")
	equal(replica.player(2).jump_sustain_ticks, source.player(2).jump_sustain_ticks, "paid jump height context round-trips")
	equal(replica.player(2).movement_chain_count, source.player(2).movement_chain_count, "movement chain count round-trips")
	equal(replica.player(2).movement_chain_reset_ticks, source.player(2).movement_chain_reset_ticks, "movement chain reset round-trips")
	equal(replica.player(2).movement_action_speed, source.player(2).movement_action_speed, "action momentum survives independently of current presentation velocity")
	check(replica.player(900) != null, "authoritative practice actor is reconstructed")
	equal(replica.player(900).health, 51_000, "practice actor health round-trips")
	equal(replica.player(900).team_id, 900, "practice actor has a distinct non-champion team after replication")
	equal(SessionSnapshot.names(snapshot), {1: "Lantern Host", 2: "River Guest"}, "display names round-trip separately from simulation state")
	var hearth_state := SessionSnapshot.hearth(snapshot)
	equal(int(hearth_state.get("maximum_players", 0)), 8, "snapshot carries Hearth capacity")
	equal((hearth_state.get("entries", []) as Array).size(), 2, "snapshot carries sorted Hearth roster")
	equal(int(SessionSnapshot.round_state(snapshot).get("phase", -1)), SessionRound.Phase.HEARTH, "snapshot carries explicit Hearth round phase")


func _test_movement_presentation_round_trip() -> void:
	equal(SessionSnapshot.PLAYER_VALUE_COUNT, 74 + SessionSnapshot.MOVEMENT_PRESENTATION_FIELDS.size(), "movement extension has an exact fixed packet shape")
	var source := SimWorld.new(120, 61, CollisionWorld.new(3_000_000, 2_000_000))
	var actor := source.player()
	actor.champion_wire_id = 1
	for property_name: StringName in SessionSnapshot.MOVEMENT_PRESENTATION_FIELDS:
		var value := 13
		if property_name in [&"wall_x", &"hop_x", &"air_dodge_x"]:
			value = -600
		elif property_name in [&"wall_y", &"hop_y", &"air_dodge_y"]:
			value = 800
		elif property_name in [&"hop_stage", &"air_redirects_remaining"]:
			value = 1
		elif property_name in [&"movement_action_speed", &"hop_speed"]:
			value = 456_000
		elif property_name in [&"air_dodge_used", &"jump_held_last_tick", &"air_floating", &"float_used"]:
			value = 1
		elif property_name == &"float_max_duration_ms":
			value = MovementTuning.FLOAT_MIDDLE_DURATION_MS
		elif property_name == &"air_vertical_velocity":
			value = -456_000
		elif property_name == &"air_height_remainder":
			value = -119
		actor.set(property_name, value)
	var snapshot := SessionSnapshot.capture(source, {1: "Motion"})
	check(SessionSnapshot.validate(snapshot), "wall/air contact and protection clocks validate")
	var replica := SimWorld.new(120, 61, CollisionWorld.new(3_000_000, 2_000_000))
	check(SessionSnapshot.apply_to_world(snapshot, replica), "movement presentation applies atomically")
	for property_name: StringName in SessionSnapshot.MOVEMENT_PRESENTATION_FIELDS:
		equal(replica.player().get(property_name), actor.get(property_name), "remote movement preserves %s" % property_name)
	for index: int in range(SessionSnapshot.MOVEMENT_PRESENTATION_FIELDS.size()):
		var malformed := snapshot.duplicate(true)
		var values: PackedInt32Array = malformed["players"][0][3]
		values[74 + index] = 2_000_000_000
		malformed["players"][0][3] = values
		check(not SessionSnapshot.validate(malformed), "out-of-range movement field fails closed: %s" % SessionSnapshot.MOVEMENT_PRESENTATION_FIELDS[index])


func _test_projectile_and_event_round_trip() -> void:
	var source := SimWorld.new(120, 3, CollisionWorld.new(3_000_000, 2_000_000))
	source.player().champion_wire_id = 1
	source.player().last_event = "cast_release_140"
	var projectile := ProjectileState.new(
		1000, 1, 1, CombatTuning.RILLSHOT_WIRE_ID, 2,
		Vector2i(1_000_000, 700_000), Vector2i(480_000, 0),
		12_000, 9_000, 90,
	)
	projectile.previous_x = 996_000
	source.projectiles.append(projectile)
	var events: Array[Dictionary] = [
		{"type": "projectile_hit", "event_id": 41, "projectile_id": 1000, "source_wire_id": CombatTuning.RILLSHOT_WIRE_ID, "owner_id": 1, "target_id": 900, "damage": 9_000},
		{"type": "edgeweave", "event_id": 42, "entity_id": 1, "projectile_id": 1000, "stamina": 8_000},
		{"type": "social_emote", "event_id": 43, "entity_id": 1, "emote_id": 1},
		{"type": "ready_changed", "event_id": 44, "entity_id": 1, "ready": true},
		{"type": "projectile_spawned", "event_id": 45, "projectile_id": 1001, "owner_id": 1, "wire_id": TIDE_SHELL_WIRE_ID},
		{"type": "spray_fired", "event_id": 46, "owner_id": 1, "source_wire_id": CombatTuning.TIDELINE_WIRE_ID, "end_x": 1_520_000, "end_y": 720_000, "hit_count": 1},
		{"type": "spray_hit", "event_id": 47, "owner_id": 1, "source_wire_id": CombatTuning.TIDELINE_WIRE_ID, "target_id": 900, "damage": int(CombatTuning.cast_definition(CombatTuning.TIDELINE_WIRE_ID)["damage"])},
	]
	var impact_station_event := SessionSnapshot.encode_event({"type": "station_confirmed", "event_id": 48, "entity_id": 1, "action": SessionTransport.REQUEST_IMPACT_PRACTICE})
	check(not impact_station_event.is_empty() and SessionSnapshot._valid_event_values(impact_station_event), "Momentum Chime confirmation uses the bounded semantic event lane")
	equal(int(SessionSnapshot.decode_event(impact_station_event).get("action", 0)), SessionTransport.REQUEST_IMPACT_PRACTICE, "Momentum Chime confirmation round-trips its stable action")
	for reason: int in [SessionRequestPolicy.REFUSED_COOLDOWN, SessionRequestPolicy.REFUSED_DISTANCE, SessionRequestPolicy.REFUSED_UNAVAILABLE]:
		var refusal := SessionSnapshot.encode_event({"type": "request_refused", "event_id": 49, "entity_id": 1, "action": SessionTransport.REQUEST_CHAMPION_SELECT, "reason": reason})
		check(not refusal.is_empty() and SessionSnapshot._valid_event_values(refusal), "exact champion refusal retains bounded host feedback")
		var decoded := SessionSnapshot.decode_event(refusal)
		equal(int(decoded.get("action", 0)), SessionTransport.REQUEST_CHAMPION_SELECT, "selection refusal round-trips exact action")
		equal(int(decoded.get("reason", 0)), reason, "selection refusal round-trips host reason")
	var exact_confirmation := SessionSnapshot.encode_event({"type": "champion_attuned", "event_id": 50, "entity_id": 1, "champion_wire_id": 27})
	check(not exact_confirmation.is_empty() and SessionSnapshot._valid_event_values(exact_confirmation), "named roster wire confirmation remains within existing snapshot schema")
	equal(int(SessionSnapshot.decode_event(exact_confirmation).get("champion_wire_id", 0)), 27, "host confirms exact champion wire, not a cycle index")
	var snapshot := SessionSnapshot.capture(source, {1: "Host"}, events)
	check(SessionSnapshot.validate(snapshot), "projectile/event snapshot validates")
	var replica := SimWorld.new(120, 3, CollisionWorld.new(3_000_000, 2_000_000))
	check(SessionSnapshot.apply_to_world(snapshot, replica), "projectile/event snapshot applies")
	equal(replica.projectiles.size(), 1, "one authoritative projectile is reconstructed for presentation")
	if not replica.projectiles.is_empty():
		equal(replica.projectiles[0].source_wire_id, CombatTuning.RILLSHOT_WIRE_ID, "projectile spell identity round-trips")
		equal(replica.projectiles[0].previous_x, 996_000, "projectile lane origin round-trips")
	equal(replica.combat_events.size(), 7, "retained projectile and spray cues plus social and Hearth events round-trip")
	if replica.combat_events.size() == 7:
		equal(String(replica.combat_events[0].get("type", "")), "projectile_hit", "hit event decodes")
		equal(int(replica.combat_events[1].get("stamina", 0)), 8_000, "edgeweave reward decodes")
		equal(String(replica.combat_events[2].get("type", "")), "social_emote", "social emote decodes")
		equal(int(replica.combat_events[2].get("event_id", 0)), 43, "semantic event identity round-trips inside the fixed header")
		check(bool(replica.combat_events[3].get("ready", false)), "Hearth readiness event decodes")
		equal(String(replica.combat_events[4].get("type", "")), "projectile_spawned", "Heavy projectile cue decodes distinctly")
		equal(int(replica.combat_events[4].get("wire_id", 0)), TIDE_SHELL_WIRE_ID, "Heavy projectile cue retains its runtime wire")
		equal(String(replica.combat_events[5].get("type", "")), "spray_fired", "spray fan cue decodes distinctly")
		equal(int(replica.combat_events[5].get("hit_count", 0)), 1, "spray affected count round-trips")
		equal(String(replica.combat_events[6].get("type", "")), "spray_hit", "spray target cue decodes distinctly")
		equal(int(replica.combat_events[6].get("damage", 0)), int(CombatTuning.cast_definition(CombatTuning.TIDELINE_WIRE_ID)["damage"]), "spray hit damage round-trips")
	equal(replica.player().last_event, "cast_release_140", "readable cast event round-trips")


func _test_reaction_strength_round_trip_and_validation() -> void:
	var source := SimWorld.new(120, 31, CollisionWorld.new(3_000_000, 2_000_000))
	source.tick = 100
	source.player().champion_wire_id = 1
	var projectile := ProjectileState.new(
		7001, 1, 1, CombatTuning.RILLSHOT_WIRE_ID, 2,
		Vector2i(1_000_000, 700_000), Vector2i(480_000, 0),
		12_000, 9_000, 90,
	)
	# A zero source cast falls back to the projectile entity ID. Spent material
	# remains legal and independent from the immutable cast provenance.
	projectile.source_cast_id = 0
	projectile.material_strength = 0
	projectile.reaction_strength = 15
	source.projectiles.append(projectile)
	var deposit := _chemistry_deposit(0)
	deposit.entity_id = 8001
	deposit.source_cast_id = projectile.entity_id
	deposit.reaction_strength = projectile.reaction_strength
	source.deposits.append(deposit)
	var snapshot := SessionSnapshot.capture(source, {1: "Host"})
	check(SessionSnapshot.validate(snapshot), "same-cast projectile/deposit strength validates with spent projectile material")
	equal(snapshot["schema"], 21, "cast provenance shares the current bounded snapshot schema")
	var projectile_values: PackedInt32Array = snapshot["projectiles"]
	equal(projectile_values.size(), 18, "projectile row appends exactly one cast-strength value")
	equal(projectile_values[15], 0, "optical mask low slot retains its published index")
	equal(projectile_values[16], 0, "optical mask high slot retains its published index")
	equal(projectile_values[17], 15, "projectile cast strength occupies appended index17")
	var deposit_values: PackedInt32Array = snapshot["deposits"][0]
	equal(deposit_values.size(), 15, "deposit row appends exactly one cast-strength value")
	equal(deposit_values[13], deposit.expiry_tick, "deposit expiry retains its published index")
	equal(deposit_values[14], 15, "deposit cast strength occupies appended index14")
	check(ElementDepositState.from_values(PackedInt64Array(Array(deposit_values.slice(0, 14)))) == null, "legacy fourteen-value deposit rows fail closed")
	var replica := SimWorld.new(120, 31, CollisionWorld.new(3_000_000, 2_000_000))
	check(SessionSnapshot.apply_to_world(snapshot, replica), "validated cast provenance applies to the presentation replica")
	equal(replica.projectiles[0].reaction_strength, 15, "projectile cast strength round-trips")
	equal(replica.projectiles[0].material_strength, 0, "spent material remains zero after round-trip")
	equal(replica.deposits[0].reaction_strength, 15, "deposit cast strength round-trips")
	for invalid_strength: int in [0, 16]:
		var malformed_projectile := snapshot.duplicate(true)
		var malformed_projectile_values: PackedInt32Array = malformed_projectile["projectiles"]
		malformed_projectile_values[17] = invalid_strength
		malformed_projectile["projectiles"] = malformed_projectile_values
		check(not SessionSnapshot.validate(malformed_projectile), "projectile cast strength %d fails closed" % invalid_strength)
		var malformed_deposit := snapshot.duplicate(true)
		var malformed_deposit_values: PackedInt32Array = malformed_deposit["deposits"][0]
		malformed_deposit_values[14] = invalid_strength
		malformed_deposit["deposits"][0] = malformed_deposit_values
		check(not SessionSnapshot.validate(malformed_deposit), "deposit cast strength %d fails closed" % invalid_strength)
	var conflicting := snapshot.duplicate(true)
	var conflicting_values: PackedInt32Array = conflicting["deposits"][0]
	conflicting_values[14] = 14
	conflicting["deposits"][0] = conflicting_values
	check(not SessionSnapshot.validate(conflicting), "one cast cannot claim different projectile and deposit strengths")
	deposit.reaction_strength = 14
	check(SessionSnapshot.capture(source, {1: "Host"}).is_empty(), "capture refuses inconsistent live objects from one cast")


func _test_event_inbox_deduplicates_redundancy() -> void:
	var inbox := SessionEventInbox.new()
	var first: Array[Dictionary] = [{"type": "social_emote", "event_id": 7, "entity_id": 2, "emote_id": 1}]
	equal(inbox.take_unseen(first).size(), 1, "first semantic event reaches presentation")
	equal(inbox.take_unseen(first).size(), 0, "redundant snapshot event is deduplicated")
	var repeated_action: Array[Dictionary] = [{"type": "social_emote", "event_id": 8, "entity_id": 2, "emote_id": 1}]
	equal(inbox.take_unseen(repeated_action).size(), 1, "same action with a new identity remains a real event")
	for event_id: int in range(9, 80):
		inbox.take_unseen([{"type": "projectile_expired", "event_id": event_id, "projectile_id": event_id}])
	equal(inbox.seen_event_ids.size(), SessionEventInbox.MAX_SEEN_EVENT_IDS, "event deduplication memory is bounded")
	inbox.reset()
	equal(inbox.seen_event_ids.size(), 0, "event deduplication resets at session boundary")


func _test_retired_field_snapshot_rejected() -> void:
	var source := SimWorld.new(120, 4, CollisionWorld.new(3_000_000, 2_000_000))
	source.player().champion_wire_id = 1
	var guest := PlayerState.new(2)
	guest.champion_wire_id = 2
	source.players.append(guest)
	var snapshot := SessionSnapshot.capture(source, {1: "Host", 2: "Guest"})
	check(SessionSnapshot.validate(snapshot), "field-free four-delivery snapshot validates")
	check(CombatTuning.cast_definition(CombatTuning.RIMEWAKE_WIRE_ID).is_empty(), "retired Rimewake has no authority definition")
	var retired := snapshot.duplicate(true)
	retired["fields"] = PackedInt32Array([
		2000, 1, CombatTuning.RIMEWAKE_WIRE_ID,
		1_400_000, 720_000, 180, 1 << 1,
	])
	check(not SessionSnapshot.validate(retired), "snapshot containing a retired Field wire fails closed")
	var replica := SimWorld.new(120, 4, CollisionWorld.new(3_000_000, 2_000_000))
	var before := replica.state_hash()
	check(not SessionSnapshot.apply_to_world(retired, replica), "retired Field snapshot cannot enter replica state")
	equal(replica.state_hash(), before, "rejected retired Field snapshot applies atomically")


func _test_maximum_envelope_fits_transport() -> void:
	var world := SimWorld.new(120, 5, CollisionWorld.new(20_000_000, 20_000_000))
	world.player().champion_wire_id = 1
	var names_by_entity: Dictionary[int, String] = {1: "Traveller01LongDisplayXX"}
	world.player().last_event = "cast_release_65535"
	for entity_id: int in range(2, SessionSnapshot.MAX_PLAYERS + 1):
		var state := PlayerState.new(entity_id)
		state.champion_wire_id = 1 if entity_id % 2 == 1 else 2
		world.players.append(state)
		state.last_event = "cast_release_65535"
		names_by_entity[entity_id] = "Traveller%02dLongDisplayXX" % entity_id
	for index: int in range(SessionSnapshot.MAX_PROJECTILES):
		world.projectiles.append(ProjectileState.new(
			1000 + index,
			1 + index % SessionSnapshot.MAX_PLAYERS,
			1,
			CombatTuning.RILLSHOT_WIRE_ID,
			2,
			Vector2i(500_000 + index * 7919, 500_000 + index * 6151),
			Vector2i(480_000 - index * 187, index * 157),
			12_000,
			9_000,
			90 + index,
		))
	var events: Array[Dictionary] = []
	for index: int in range(SessionSnapshot.MAX_EVENTS):
		events.append({"type": "projectile_hit", "projectile_id": 1000 + index, "source_wire_id": CombatTuning.RILLSHOT_WIRE_ID, "owner_id": 1, "target_id": 2, "damage": 9_000})
	for index: int in range(SessionSnapshot.MAX_TARGETS):
		var target := PlayerState.new(900 + index)
		target.actor_kind = PlayerState.ActorKind.TRAINING_TARGET
		target.position_x = 900_000 + index * 40_000
		target.position_y = 800_000
		target.radius = 18_000
		target.health_maximum = 80_000
		target.health = 40_000
		world.players.append(target)
	var snapshot := SessionSnapshot.capture(world, names_by_entity, events)
	check(SessionSnapshot.validate(snapshot), "maximum four-delivery snapshot envelope validates")
	var packets := SessionTransport._snapshot_wire_packets(snapshot)
	check(packets.size() > 1 and packets.size() <= SessionTransport.MAX_SNAPSHOT_FRAGMENTS, "varied maximum threat load uses a bounded complete fragment set")
	var receiver := SessionTransport.new()
	receiver.mode = SessionTransport.Mode.CLIENT
	packets.reverse()
	for packet: Dictionary in packets:
		check(var_to_bytes(packet).size() <= SessionTransport.ENET_MTU_BYTES, "each threat fragment fits one MTU")
		receiver._handle_packet(SessionTransport.SERVER_PEER_ID, var_to_bytes(packet))
	var received := receiver.take_snapshots()
	equal(received.size(), 1, "reordered maximum snapshot is applied atomically once")
	if not received.is_empty():
		check(received[0] == snapshot, "all varied maximum-envelope values round-trip exactly")
		equal((received[0]["projectiles"] as PackedInt32Array).size(), SimConfig.MAX_ACTIVE_PROJECTILES * SessionSnapshot.PROJECTILE_VALUE_COUNT, "no admitted projectile omitted")
		check((received[0]["fields"] as PackedInt32Array).is_empty(), "disabled authored Fields never enter the authoritative envelope")
	receiver.stop()


func _chemistry_deposit(index: int) -> ElementDepositState:
	var deposit := ElementDepositState.new()
	deposit.entity_id = 3000 + index
	deposit.source_cast_id = 1000 + index
	deposit.source_wire_id = CombatTuning.RILLSHOT_WIRE_ID
	deposit.owner_id = 1 + index % 8
	deposit.team_id = 1 + index % 8
	deposit.element_wire_id = 1 + index % 8
	deposit.position_x = 300_000 + index * 7919
	deposit.position_y = 400_000 + index * 6151
	deposit.created_tick = 100
	deposit.expiry_tick = 600
	deposit.reaction_strength = 1 + index % 15
	return deposit


func _chemistry_reaction(index: int) -> ElementReactionState:
	var reaction := ElementReactionState.new()
	reaction.entity_id = 4000 + index
	reaction.recipe_wire_id = 301 + index % 36
	reaction.owner_id = 1 + index % 8
	reaction.team_id = 1 + index % 8
	reaction.position_x = 500_000 + index * 3571
	reaction.position_y = 600_000 + index * 2371
	reaction.origin_x = reaction.position_x
	reaction.origin_y = reaction.position_y
	reaction.endpoint_x = reaction.position_x + 200_000
	reaction.endpoint_y = reaction.position_y
	reaction.created_tick = 100
	reaction.active_tick = 110
	reaction.decay_tick = 580
	reaction.expiry_tick = 600
	reaction.radius = ElementReactionState.MAX_RADIUS
	reaction.length = ElementReactionState.MAX_LENGTH
	reaction.health = 60_000
	reaction.capacity = 36_000
	reaction.pulse_index = 3
	reaction.source_a = 3000 + index * 2
	reaction.source_b = 3001 + index * 2
	reaction.linked_deposit_ids = PackedInt64Array([6000, 6001, 6002, 6003])
	reaction.path_points = PackedInt64Array([500000, 600000, 550000, 601000, 600000, 602000, 650000, 603000, 700000, 604000])
	for actor_id: int in range(1, 17):
		reaction.contacts.append_array(PackedInt64Array([actor_id, 100 + actor_id, actor_id % 2]))
	return reaction


func _test_complete_chemistry_envelope() -> void:
	for deposit_count: int in [0, 64, 128]:
		var world := SimWorld.new(120, 73, CollisionWorld.new(20_000_000, 20_000_000))
		world.tick = 300
		for actor_id: int in range(2, 9):
			world.players.append(PlayerState.new(actor_id))
		var names := {}
		for actor: PlayerState in world.players:
			actor.champion_wire_id = 1
			names[actor.entity_id] = "T".repeat(SessionTransport.MAX_PLAYER_NAME_LENGTH)
			actor.float_used = true
			actor.air_floating = true
			actor.air_height = 20_000
			actor.float_ticks = 100
			actor.chemistry_reveal_ticks = 120
			actor.chemistry_conceal_ticks = 120
			actor.chemistry_regen_block_ticks = 120
			actor.pending_cast_target_x = 3_000_000
			actor.pending_cast_target_y = 2_000_000
		for index: int in range(128 - deposit_count):
			var projectile := ProjectileState.new(1000 + index, 1 + index % 8, 1, CombatTuning.RILLSHOT_WIRE_ID, 2, Vector2i(300000 + index * 7919, 500000 + index * 6151), Vector2i(480000 - index * 187, index * 157), 12000, 9000, 500)
			projectile.remaining_distance = 1_000_000 + index
			projectile.source_cast_id = 1000 + index
			projectile.material_strength = 1 + index % 1000
			projectile.chemistry_interaction_mask = (1 << 36) - 1
			projectile.reaction_strength = 1 + index % 15
			world.projectiles.append(projectile)
		for index: int in range(deposit_count):
			world.deposits.append(_chemistry_deposit(index))
		for index: int in range(32):
			world.reactions.append(_chemistry_reaction(index))
		var events: Array[Dictionary] = []
		for index: int in range(12):
			events.append({"type": "spray_fired", "source_wire_id": CombatTuning.TIDELINE_WIRE_ID, "owner_id": 1, "end_x": 900000 + index * 1957, "end_y": 800000, "hit_count": index % SessionSnapshot.MAX_PLAYERS})
		for index: int in range(4):
			var target := PlayerState.new(900 + index)
			target.actor_kind = PlayerState.ActorKind.TRAINING_TARGET
			world.players.append(target)
		var snapshot := SessionSnapshot.capture(world, names, events)
		check(SessionSnapshot.validate(snapshot), "worst bounded mixed projectile/deposit/reaction snapshot validates")
		var raw_size := var_to_bytes(snapshot).size()
		check(raw_size <= SessionTransport.MAX_SNAPSHOT_UNCOMPRESSED_BYTES, "complete dangerous chemistry state fits the unchanged32KB raw envelope")
		var packets := SessionTransport._snapshot_wire_packets(snapshot)
		check(not packets.is_empty() and packets.size() <= SessionTransport.MAX_SNAPSHOT_FRAGMENTS, "complete chemistry state is admitted to bounded transport")
		var receiver := SessionTransport.new()
		receiver.mode = SessionTransport.Mode.CLIENT
		packets.reverse()
		var largest_datagram := 0
		for packet: Dictionary in packets:
			var bytes := var_to_bytes(packet)
			largest_datagram = maxi(largest_datagram, bytes.size())
			check(bytes.size() <= SessionTransport.ENET_MTU_BYTES, "chemistry fragment remains inside one MTU")
			receiver._handle_packet(1, bytes)
		var received := receiver.take_snapshots()
		check(received.size() == 1 and received[0] == snapshot, "reversed fragments reconstruct one exact complete chemistry snapshot")
		var replica := SimWorld.new(120, 73)
		check(SessionSnapshot.apply_to_world(snapshot, replica), "complete chemistry snapshot applies atomically")
		for index: int in range(world.deposits.size()):
			equal(replica.deposits[index].canonical_values(), world.deposits[index].canonical_values(), "deposit canonical state round-trips losslessly")
		for index: int in range(world.reactions.size()):
			equal(replica.reactions[index].canonical_values(), world.reactions[index].canonical_values(), "reaction geometry/timeline/contact state round-trips losslessly")
		for index: int in range(world.projectiles.size()):
			var original: ProjectileState = world.projectiles[index]
			var copied: ProjectileState = replica.projectiles[index]
			equal(copied.chemistry_interaction_mask, original.chemistry_interaction_mask, "all36 optical interaction bits round-trip without signed32 truncation")
			equal(copied.remaining_distance, original.remaining_distance, "projectile cursor-range budget round-trips")
			equal(copied.source_cast_id, original.source_cast_id, "projectile deposit source identity round-trips")
			equal(copied.material_strength, original.material_strength, "projectile matter strength round-trips")
			equal(copied.reaction_strength, original.reaction_strength, "projectile cast strength round-trips independently from material")
		print("chemistry snapshot deposits=", deposit_count, " projectiles=", world.projectiles.size(), " reactions=32 raw_bytes=", raw_size, " fragments=", packets.size(), " largest_datagram=", largest_datagram)
		for key: String in ["deposits", "reactions"]:
			var missing := snapshot.duplicate(true)
			missing.erase(key)
			check(not SessionSnapshot.validate(missing), "missing dangerous chemistry lane fails closed")
		var malformed := snapshot.duplicate(true)
		malformed["reactions"][0][1] = 337
		check(not SessionSnapshot.validate(malformed), "unknown reaction wire fails closed")
		malformed = snapshot.duplicate(true)
		malformed["reactions"].append(malformed["reactions"][0])
		check(not SessionSnapshot.validate(malformed), "over-cap reaction array fails closed")
		malformed = snapshot.duplicate(true)
		malformed["deposits"].append(PackedInt32Array(Array(_chemistry_deposit(200).canonical_values())))
		check(not SessionSnapshot.validate(malformed), "combined projectile/deposit count cannot exceed authority admission")
		world.deposits.append(_chemistry_deposit(200))
		check(SessionSnapshot.capture(world, names).is_empty(), "over-admitted source refuses a whole snapshot instead of hiding a threat")
		receiver.stop()
	for recipe_wire: int in range(301, 337):
		var world := SimWorld.new(120, 3)
		world.player().champion_wire_id = 1
		var reaction := _chemistry_reaction(0)
		reaction.recipe_wire_id = recipe_wire
		world.reactions.append(reaction)
		var snapshot := SessionSnapshot.capture(world, {})
		check(SessionSnapshot.validate(snapshot), "each of36 recipe identities is admitted without promoting unsupported values")
		var replica := SimWorld.new(120, 3)
		check(SessionSnapshot.apply_to_world(snapshot, replica), "each reaction identity restores for remote presentation")
		equal(replica.reactions[0].recipe_wire_id, recipe_wire, "all36 reaction identities survive replication")


func _snapshot_trail(index: int, owner: int) -> ElementDepositState:
	var deposit := _chemistry_deposit(index)
	deposit.owner_id = owner
	deposit.radius = ElementChemistrySystem.TRAIL_RADIUS
	deposit.strength = ElementChemistrySystem.TRAIL_STRENGTH
	deposit.expiry_tick = deposit.created_tick + SimConfig.new(120).milliseconds_to_ticks(ElementChemistrySystem.TRAIL_LIFE_MS[deposit.element_wire_id])
	return deposit


func _test_trail_snapshot_limits() -> void:
	var world := SimWorld.new(120, 119, CollisionWorld.new(20_000_000, 20_000_000))
	world.tick = 150
	world.player().champion_wire_id = 1
	for owner: int in range(2, 9):
		var actor := PlayerState.new(owner)
		actor.champion_wire_id = 1
		world.players.append(actor)
	for index: int in ElementChemistrySystem.MAX_TRAILS:
		world.deposits.append(_snapshot_trail(index, 1 + index % 8))
	var before := world.state_hash()
	var boundary := SessionSnapshot.capture(world, {})
	check(not boundary.is_empty(), "capture admits exactly32 global trails at four for each of eight owners")
	check(SessionSnapshot.validate(boundary), "received snapshot admits the exact global/per-owner trail boundary")
	equal(world.state_hash(), before, "role-cap capture leaves canonical source state untouched")
	if boundary.is_empty():
		return
	equal(boundary["schema"], 21, "trail role caps share the current snapshot schema")
	equal(boundary["deposits"][0].size(), 15, "trail role retains its footprint while cast strength is appended")
	var replica := SimWorld.new(120, 119)
	check(SessionSnapshot.apply_to_world(boundary, replica), "exact-boundary trails restore as a presentation replica")
	equal(replica.deposits.size(), ElementChemistrySystem.MAX_TRAILS, "replica loses no admitted trail at the boundary")
	for index: int in world.deposits.size():
		equal(replica.deposits[index].canonical_values(), world.deposits[index].canonical_values(), "trail canonical footprint/strength/expiry round-trips exactly")
	# A ninth, orphan owner isolates the GLOBAL cap: no owner has a fifth trail.
	var extra_global := _snapshot_trail(ElementChemistrySystem.MAX_TRAILS, 10000)
	check(extra_global.validate(), "global one-over payload is individually valid and does not rely on malformed fields")
	world.deposits.append(extra_global)
	before = world.state_hash()
	check(SessionSnapshot.capture(world, {}).is_empty(), "capture refuses33 global trails even when every owner remains within four")
	equal(world.state_hash(), before, "refused global capture does not prune or alter authoritative matter")
	var forged_global := boundary.duplicate(true)
	forged_global["deposits"].append(PackedInt32Array(Array(extra_global.canonical_values())))
	check(not SessionSnapshot.validate(forged_global), "handcrafted incoming dictionary cannot bypass the global trail cap")
	before = replica.state_hash()
	check(not SessionSnapshot.apply_to_world(forged_global, replica), "over-global trail snapshot cannot apply")
	equal(replica.state_hash(), before, "rejected over-global snapshot leaves the existing replica atomic")
	# Four trails plus eleven real terminals remain legal. The fifth trail then
	# violates only the role cap, not the existing16-owner/128-global matter cap.
	world.deposits.clear()
	for index: int in ElementChemistrySystem.MAX_OWNER_TRAILS:
		world.deposits.append(_snapshot_trail(index, 10000))
	for index: int in range(ElementChemistrySystem.MAX_OWNER_TRAILS, 15):
		var terminal := _chemistry_deposit(index)
		terminal.owner_id = 10000
		world.deposits.append(terminal)
	var owner_boundary := SessionSnapshot.capture(world, {})
	check(SessionSnapshot.validate(owner_boundary), "orphan owner may carry four trails alongside eleven genuine terminal deposits")
	var fifth := _snapshot_trail(15, 10000)
	world.deposits.append(fifth)
	check(SessionSnapshot.capture(world, {}).is_empty(), "capture rejects a fifth owner trail while total matter stays within16")
	if not owner_boundary.is_empty():
		var forged_owner := owner_boundary.duplicate(true)
		forged_owner["deposits"].append(PackedInt32Array(Array(fifth.canonical_values())))
		check(not SessionSnapshot.validate(forged_owner), "handcrafted incoming dictionary cannot bypass the per-owner trail cap")
		before = replica.state_hash()
		check(not SessionSnapshot.apply_to_world(forged_owner, replica), "over-owner snapshot refuses before mutation")
		equal(replica.state_hash(), before, "rejected per-owner snapshot preserves existing replica")
	# Full shared envelope remains128: terminal deposits do not consume trail caps.
	world.deposits.clear()
	for index: int in SessionSnapshot.MAX_DEPOSITS:
		world.deposits.append(_snapshot_trail(index, 1 + index % 8) if index < ElementChemistrySystem.MAX_TRAILS else _chemistry_deposit(index))
	var mixed := SessionSnapshot.capture(world, {})
	check(SessionSnapshot.validate(mixed), "32trails plus96terminals preserve the complete existing128-deposit envelope")
	if not mixed.is_empty():
		equal(mixed["deposits"].size(), SessionSnapshot.MAX_DEPOSITS, "no terminal or trail is silently truncated")
		var malformed := mixed.duplicate(true)
		malformed["deposits"][0][10] = ElementChemistrySystem.TRAIL_RADIUS - 1
		check(not SessionSnapshot.validate(malformed), "a forged near-trail radius cannot dodge role limits by becoming an invalid terminal")
	# The remaining shared projectile/deposit bound still applies independently.
	world.deposits.append(_chemistry_deposit(SessionSnapshot.MAX_DEPOSITS))
	check(SessionSnapshot.capture(world, {}).is_empty(), "trail hardening retains the original shared total matter limit")


func _fragment_fixture(tick: int = 10) -> Dictionary:
	var world := SimWorld.new(120, 71, CollisionWorld.new(20_000_000, 20_000_000))
	world.player().champion_wire_id = 1
	world.tick = tick
	for index: int in range(80):
		world.projectiles.append(ProjectileState.new(
			1000 + index, 1, 1, CombatTuning.RILLSHOT_WIRE_ID, 2,
			Vector2i(500_000 + index * 7919, 500_000 + index * 6151),
			Vector2i(480_000 - index * 187, index * 157), 12_000, 9_000, 90 + index,
		))
	return SessionSnapshot.capture(world, {1: "Fragment test"})


func _test_fragment_assembly_faults() -> void:
	var refused := SessionSnapshot.encode_event({"type": "cast_refused", "entity_id": 1, "wire_id": CombatTuning.RILLSHOT_WIRE_ID, "reason": "capacity"})
	check(SessionSnapshot._valid_event_values(refused), "capacity refusal remains a valid network event")
	equal(String(SessionSnapshot.decode_event(refused).get("reason", "")), "capacity", "remote refusal preserves the actionable cause")
	var snapshot := _fragment_fixture()
	var packets := SessionTransport._snapshot_wire_packets(snapshot)
	check(packets.size() > 1, "fault fixture actually requires multiple MTUs")
	if packets.size() < 2:
		return
	var receiver := SessionTransport.new()
	receiver.mode = SessionTransport.Mode.CLIENT
	var first := var_to_bytes(packets[0])
	receiver._handle_packet(99, first)
	equal(receiver._snapshot_assemblies.size(), 0, "non-host cannot allocate fragment state")
	receiver._handle_packet(1, first)
	receiver._handle_packet(1, first)
	equal(receiver.take_snapshots().size(), 0, "duplicate/missing fragment never applies a partial frame")
	equal(receiver._snapshot_assemblies.size(), 1, "duplicates do not allocate another assembly")
	for index: int in range(1, packets.size()):
		receiver._handle_packet(1, var_to_bytes(packets[index]))
	equal(receiver.take_snapshots().size(), 1, "complete frame survives a duplicate")
	for packet: Dictionary in packets:
		receiver._handle_packet(1, var_to_bytes(packet))
	equal(receiver.take_snapshots().size(), 0, "old fragments cannot replay after the inbox is drained")
	for mutation: Callable in [
		func(p: Dictionary) -> void: p["count"] = SessionTransport.MAX_SNAPSHOT_FRAGMENTS + 1,
		func(p: Dictionary) -> void: p["index"] = -1,
		func(p: Dictionary) -> void: p["raw_size"] = SessionTransport.MAX_SNAPSHOT_UNCOMPRESSED_BYTES + 1,
		func(p: Dictionary) -> void: p["tick"] = "11",
		func(p: Dictionary) -> void: p["payload"] = PackedByteArray([1]),
	]:
		var malformed: Dictionary = packets[0].duplicate(true)
		malformed["tick"] = 11
		mutation.call(malformed)
		receiver._handle_packet(1, var_to_bytes(malformed))
	equal(receiver._snapshot_assemblies.size(), 0, "invalid metadata/length rejected before allocation")
	for tick: int in range(11, 18):
		var pending: Dictionary = packets[0].duplicate(true)
		pending["tick"] = tick
		receiver._handle_packet(1, var_to_bytes(pending))
	check(receiver._snapshot_assemblies.size() <= SessionTransport.MAX_PENDING_SNAPSHOT_ASSEMBLIES, "missing packets have a hard memory bound")
	for tick: int in receiver._snapshot_assemblies.keys():
		receiver._snapshot_assemblies[tick]["created_ms"] = Time.get_ticks_msec() - SessionTransport.SNAPSHOT_ASSEMBLY_TIMEOUT_MS - 1
	var newer := _fragment_fixture(20)
	for packet: Dictionary in SessionTransport._snapshot_wire_packets(newer):
		receiver._handle_packet(1, var_to_bytes(packet))
	var recovered := receiver.take_snapshots()
	equal(recovered.size(), 1, "new complete snapshot recovers after loss/timeout")
	if not recovered.is_empty():
		check(recovered[0] == newer, "recovery does not combine data from different ticks")
	equal(receiver._snapshot_assemblies.size(), 0, "expired and superseded partial frames are cleared")
	receiver.stop()
	equal(receiver._last_snapshot_tick, -1, "disconnect clears monotonic session tracking")


func _test_snapshot_validation_fails_closed() -> void:
	var world := SimWorld.new(120, 1, CollisionWorld.new())
	world.player().champion_wire_id = 1
	var valid := SessionSnapshot.capture(world, {1: "Host"})
	var retired_kit := valid.duplicate(true)
	var retired_values: PackedInt32Array = retired_kit["players"][0][3]
	retired_values[49] = CombatTuning.RIMEWAKE_WIRE_ID
	retired_kit["players"][0][3] = retired_values
	check(not SessionSnapshot.validate(retired_kit), "snapshot carrying a retired kit wire fails closed")
	for mutation: Callable in [
		func(value: Dictionary) -> void: value["schema"] = 99,
		func(value: Dictionary) -> void: value["tick"] = -1,
		func(value: Dictionary) -> void: value["state_hash"] = "forged",
		func(value: Dictionary) -> void: (value["players"] as Array).append((value["players"] as Array)[0].duplicate(true)),
		func(value: Dictionary) -> void: ((value["players"] as Array)[0] as Array)[0] = 9,
		func(value: Dictionary) -> void: ((value["players"] as Array)[0] as Array)[1] = "",
		func(value: Dictionary) -> void: ((value["players"] as Array)[0] as Array)[2] = "BAD EVENT",
		func(value: Dictionary) -> void: ((value["players"] as Array)[0] as Array)[3] = PackedInt32Array([1]),
		func(value: Dictionary) -> void: value["overflow"] = PackedInt32Array([-1, 0, 0, 0]),
		func(value: Dictionary) -> void: value["fields"] = PackedInt32Array([2000, 1, CombatTuning.RIMEWAKE_WIRE_ID, 0, 0, 0, 0]),
		func(value: Dictionary) -> void: value["events"] = [PackedInt64Array([99, 0, 0, 0, 0, 0])],
		func(value: Dictionary) -> void: value["hearth"] = PackedInt32Array([1, 8, 0, 8]),
		func(value: Dictionary) -> void: value["round"] = PackedInt32Array([1, 9, 0, 0, 0, 3, 0]),
	]:
		var malformed: Dictionary = valid.duplicate(true)
		mutation.call(malformed)
		check(not SessionSnapshot.validate(malformed), "malformed snapshot is rejected")
