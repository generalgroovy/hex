extends FluxTestSuite


var abilities := AbilityCatalog.new()
var champions := ChampionCatalog.new()


func run() -> int:
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "team replication loads production abilities")
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "team replication loads production champions")
	if not abilities.last_error.is_empty() or not champions.last_error.is_empty():
		return finish("team-replication")
	for hex_enabled: bool in [false, true]:
		for mode: int in [SessionRound.Mode.DUOS, SessionRound.Mode.TRIOS]:
			_test_departed_ledger_replication(mode, hex_enabled)
			_test_score_result_event_replication(mode, hex_enabled)
	return finish("team-replication")


func _ids(mode: int) -> Array[int]:
	if mode == SessionRound.Mode.DUOS:
		return [1, 4, 6, 8]
	return [1, 2, 4, 5, 7, 8]


func _fixture(mode: int, hex_enabled: bool, score_limit: int = 3) -> AuthoritativeSession:
	var world := SimWorld.new(120, 752, CollisionWorld.new(1_280_000, 960_000))
	check(champions.apply_to_player(world.player(), "oh_tipi"), "replication host uses authored champion stats")
	if hex_enabled:
		check(HexCourtPractice.configure(world, abilities, false), "replication fixture uses the real HEX court")
	var ids := _ids(mode)
	var roster: Array[Dictionary] = []
	for entity_id: int in ids:
		if entity_id != 1:
			roster.append({"entity_id": entity_id, "name": "Player %d" % entity_id})
	var session := AuthoritativeSession.new()
	var charter := "duos" if mode == SessionRound.Mode.DUOS else "trios"
	if not session.bind(world, champions, Vector2i(640, 710), "Host", roster, charter):
		check(false, "replication session must bind: " + session.last_error)
		return null
	if not session.begin_round({
		"bounds": [0, 0, 1280, 960], "score_limit": score_limit,
		"round_seconds": 15, "result_seconds": 2,
		"respawn_ms": 500, "spawn_protection_ms": 250,
		"spawns": [[280, 300], [1000, 300], [280, 710], [1000, 710], [280, 500], [1000, 500]],
	}):
		check(false, "replication fixture must begin exact-count team mode")
		return null
	for actor: PlayerState in world.players:
		actor.spawn_protection_ticks = 0
		actor.health_recovery_per_second = 0
	return session


# Earn the point using a real paid spell command and the production world step.
# Only the victim's initial health and both actors' starting positions are set;
# no champion_defeated event or team score is fabricated by this fixture.
func _earn_point(session: AuthoritativeSession, owner_id: int, victim_id: int) -> bool:
	var world := session.world
	var owner := world.player(owner_id)
	var victim := world.player(victim_id)
	owner.position_x = 640_000
	owner.position_y = 710_000
	victim.position_x = 640_000
	victim.position_y = 480_000
	victim.health = 1
	victim.spawn_protection_ticks = 0
	var fire_wire := int(abilities.ability(abilities.spell_id_at("fire", "bolt")).wire_id)
	check(owner.place_proven_spell(0, fire_wire), "replication scorer equips a real Fire Bolt")
	var flux_before := owner.flux
	var saw_payment := false
	for step: int in range(240):
		var pressed := SimCommand.PRESSED_SPELL_1 if step == 0 else 0
		if not world.step([SimCommand.new(world.tick, owner_id, 0, 0, 0, pressed, 0, -1000, 640_000, 480_000)]):
			check(false, "paid team defeat simulation must stay valid: " + world.last_error)
			return false
		saw_payment = saw_payment or owner.flux < flux_before
		var defeated := world.combat_events.any(func(event: Dictionary) -> bool:
			return String(event.get("type", "")) == "champion_defeated" \
				and int(event.get("owner_id", 0)) == owner_id and int(event.get("target_id", 0)) == victim_id)
		session.advance_round(world.combat_events)
		session.record_combat_events(world.combat_events)
		if defeated:
			check(saw_payment, "real team knockout consumed the spell's Flux cost")
			check(victim.health == 0, "real contact defeats the opposing champion")
			equal(session.session_round.scores_by_team[1], 1, "actual simulated defeat earns one shared team point")
			return true
	check(false, "paid Fire Bolt must produce its authoritative team defeat within 240 ticks")
	return false


func _test_departed_ledger_replication(mode: int, hex_enabled: bool) -> void:
	var session := _fixture(mode, hex_enabled)
	if session == null:
		return
	var ids := _ids(mode)
	var scorer := ids[2]
	if not _earn_point(session, scorer, ids[1]):
		return
	var label := "%s mode %d" % ["HEX" if hex_enabled else "legacy", mode]
	var material_before := _prepare_departure_material(session, scorer, label) if hex_enabled else {}
	var active := _assert_replication(session, label + " earned point")
	if active.is_empty():
		return
	_assert_knockout_event(active, scorer, ids[1], label)
	_assert_live_team_mismatch(active, label)
	_assert_healthy_actor_marked_departed(active, scorer, label)
	equal(session.remove_peers([{"entity_id": scorer}]), 1, label + " scorer leaves permanently")
	check(session.world.player(scorer) == null, label + " departed actor is really absent")
	equal(session.session_round.scores_by_team[1], 1, label + " departure keeps its earned point")
	if hex_enabled:
		_assert_departure_material(session, scorer, material_before, label)
	var absent := _assert_replication(session, label + " absent scorer ledger")
	if absent.is_empty():
		return
	_assert_forged_present(absent, scorer, label)
	equal(session.register_peers([{"entity_id": scorer, "name": "New Observer"}]), 1, label + " vacated ID is reused by a new observer")
	if session.world.player(scorer) == null:
		return # The failed admission assertion above is sufficient; avoid a nil cascade.
	check(session.input_locked(scorer), label + " replacement observer remains input locked")
	equal(session.world.player(scorer).health, 0, label + " replacement observer remains health zero")
	check(session.world.player(scorer).team_id != session.session_round.team_by_entity[scorer], label + " fixture exposes differing observer and historical teams")
	var reused := _assert_replication(session, label + " reused observer ID")
	if reused.is_empty():
		return
	var reused_round := SessionRound.decoded(WorldSnapshotEnvelope.round_state(reused))
	check(not bool(_entry(reused_round, scorer).present), label + " replicated historical row stays absent despite live ID reuse")
	equal(int(_entry(reused_round, scorer).score), 1, label + " observer cannot overwrite historical contribution")
	_assert_absent_observer_with_health(reused, scorer, label)
	# A whole opposing-team departure resolves by forfeit without inventing
	# points. This uses the production authority removal path and its events.
	for index: int in range(1, ids.size(), 2):
		equal(session.remove_peers([{"entity_id": ids[index]}]), 1, label + " opposing teammate leaves through authority")
	equal(session.session_round.winner_team_id, 1, label + " remaining team owns the forfeit result")
	equal(session.session_round.result_reason, SessionRound.ResultReason.FORFEIT, label + " result retains the actual forfeit reason")
	var result := _assert_replication(session, label + " forfeit result")
	if not result.is_empty():
		_assert_finished_event(result, 1, SessionRound.ResultReason.FORFEIT, label)


# The score above is command-driven. This extra fixture uses the production
# paid-budget API to cover simultaneous pending, ground, flight and mixed-owner
# product state at the exact disconnect boundary, without fabricating a score.
func _prepare_departure_material(session: AuthoritativeSession, departing: int, label: String) -> Dictionary:
	var world := session.world
	var court: HexChemistryWorld = world.hex_court
	var water := int(abilities.ability(abilities.spell_id_at("water", "rapid")).wire_id)
	var earth := int(abilities.ability(abilities.spell_id_at("earth", "rapid")).wire_id)
	var ground_source := _paid_material_source(world, 1, water, label)
	court.deposit_terminal({"source_cast_id": ground_source, "source_wire_id": water, "reaction_strength": 1,
		"position": court.origin + Vector2i(-250_000, 0), "direction": Vector2i(1000, 0)}, court.current_tick)
	var surviving_products := {}
	for product_owner: int in [1, departing]:
		var other_owner := departing if product_owner == 1 else 1
		var first := _paid_material_source(world, product_owner, earth, label)
		var second := _paid_material_source(world, other_owner, earth, label)
		var formed := court.resolve_contact(first, second, court.origin + Vector2i(-150_000 if product_owner == 1 else 150_000, 0), court.current_tick)
		check(bool(formed.get("accepted", false)) and formed.has("product_id"), label + " mixed-owner paid Earth sources form a Rampart")
		if not formed.has("product_id"):
			continue
		var product_id := int(formed.product_id)
		var product: Dictionary = court.products[product_id]
		equal(int(product.owner), product_owner, label + " oldest source owns mixed-product attribution")
		product.contacts[departing] = {"inside": true, "entered": court.current_tick, "last_pulse": -1, "effect_used": true}
		product.contacts[1] = {"inside": false, "entered": -1, "last_pulse": -1, "effect_used": false}
		if product_owner == 1:
			var expected := product.duplicate(true)
			expected.contacts.erase(departing)
			surviving_products[product_id] = expected
			court.flow_carry["%d:%d" % [product_id, departing]] = Vector2i(1, 0)
			court.flow_carry["%d:1" % product_id] = Vector2i(2, 0)
	var surviving_shots: Array = []
	for owner_id: int in [1, departing]:
		var source := _paid_material_source(world, owner_id, water, label)
		var shot := ProjectileState.new(source, owner_id, world.player(owner_id).team_id, water, 3, court.origin, Vector2i(1000, 0), 3000, 1000, 400)
		shot.source_cast_id = source
		shot.reaction_strength = 1
		shot.initial_strength = 1
		shot.remaining_strength = 1
		if owner_id == 1:
			shot.record_graze(departing)
			surviving_shots.append(shot)
		world.projectiles.append(shot)
	check(court.reserve_cast(departing, water), label + " departing owner has an admitted startup reservation")
	court.commit_payment(departing)
	world.player(departing).pending_cast_wire_id = water
	world.player(departing).pending_cast_ticks = 1
	court.exposure[departing] = 17
	var surviving_casts := {}
	var expiring_quantity := 0
	for cast_id: int in court.casts:
		var record: Dictionary = court.casts[cast_id]
		if int(record.owner) == departing:
			expiring_quantity += int(record.unallocated) + int(record.ground)
		else:
			surviving_casts[cast_id] = record.duplicate(true)
	check(court.conservation_valid(), label + " mixed departure fixture conserves its real paid budgets")
	return {"casts": surviving_casts, "products": surviving_products, "shots": surviving_shots,
		"paid": int(court.metrics.matter_paid), "consumed": int(court.metrics.matter_consumed),
		"expired": int(court.metrics.matter_expired) + expiring_quantity,
		"ids": [court.next_cast_id, court.next_product_id, court.next_ground_part_id, world.next_projectile_id],
		"tick": [world.tick, court.current_tick], "topology": court.cell_keys()}


func _paid_material_source(world: SimWorld, owner_id: int, wire: int, label: String) -> int:
	var court: HexChemistryWorld = world.hex_court
	check(court.reserve_cast(owner_id, wire), label + " preservation fixture reserves a real material source")
	court.commit_payment(owner_id)
	var source := world.next_projectile_id
	world.next_projectile_id += 1
	court.bind_release(owner_id, source, court.origin, Vector2i(1000, 0), world.player(owner_id).team_id)
	return source


func _assert_departure_material(session: AuthoritativeSession, departing: int, before: Dictionary, label: String) -> void:
	var world := session.world
	var court: HexChemistryWorld = world.hex_court
	check(court.conservation_valid(), label + " permanent departure conserves every paid matter unit")
	equal(court.casts, before.casts, label + " departure removes only its casts and preserves every surviving cast exactly")
	equal(court.products, before.products, label + " departure retires its mixed product and preserves surviving-owner mixed provenance")
	equal(int(court.metrics.matter_paid), int(before.paid), label + " departure never invents or refunds paid matter")
	equal(int(court.metrics.matter_consumed), int(before.consumed), label + " consumed product provenance remains consumed")
	equal(int(court.metrics.matter_expired), int(before.expired), label + " all and only departed pending, flight and ground matter expires")
	check(not court.pending.has(departing) and not court.exposure.has(departing), label + " departed reservation and exposure cannot reach a reused ID")
	for source_id: int in court.sources:
		check(court.casts.has(int(court.sources[source_id])) and int(court.casts[int(court.sources[source_id])].owner) != departing, label + " live source mapping cannot outlive its departed owner")
	for key: String in court.flow_carry:
		check(not key.ends_with(":%d" % departing), label + " surviving product drops only departed actor flow carry")
	for product_id: int in before.products:
		equal(court.flow_carry.get("%d:1" % product_id), Vector2i(2, 0), label + " surviving actor flow carry remains exact")
	equal(world.projectiles, before.shots, label + " departure removes only owned live projectiles")
	for shot: ProjectileState in world.projectiles:
		check(not shot.has_grazed(departing), label + " surviving shots cannot retain a reused actor graze")
	equal([court.next_cast_id, court.next_product_id, court.next_ground_part_id, world.next_projectile_id], before.ids, label + " departure preserves monotonic source identities")
	equal([world.tick, court.current_tick], before.tick, label + " departure never fabricates a future tick")
	equal(court.cell_keys(), before.topology, label + " departure preserves map topology")
	if world.collision is HexCollisionWorld:
		var expected_collision := HexCollisionWorld.new(world.collision.base_world)
		check(expected_collision.set_hex_surfaces(court, world.tick), label + " surviving material has a valid collision projection")
		equal(world.collision._solid, expected_collision._solid, label + " departure refreshes movement collision immediately")
		equal(world.collision._cover, expected_collision._cover, label + " departure refreshes cover collision immediately")


func _test_score_result_event_replication(mode: int, hex_enabled: bool) -> void:
	var session := _fixture(mode, hex_enabled, 1)
	if session == null:
		return
	var ids := _ids(mode)
	if not _earn_point(session, ids[2], ids[1]):
		return
	var label := "%s mode %d score result" % ["HEX" if hex_enabled else "legacy", mode]
	equal(session.session_round.result_reason, SessionRound.ResultReason.SCORE_LIMIT, label + " actual paid knockout reaches the configured threshold")
	var result := _assert_replication(session, label)
	if result.is_empty():
		return
	_assert_knockout_event(result, ids[2], ids[1], label)
	_assert_finished_event(result, 1, SessionRound.ResultReason.SCORE_LIMIT, label)
	equal(session.remove_peers([{"entity_id": ids[2]}]), 1, label + " winning scorer leaves during RESULT")
	var departed_result := _assert_replication(session, label + " departed winner")
	if not departed_result.is_empty():
		var decoded := SessionRound.decoded(WorldSnapshotEnvelope.round_state(departed_result))
		equal(int(decoded.winner_team_id), 1, label + " replicated winner survives later departure")
		equal(int(decoded.result_reason), SessionRound.ResultReason.SCORE_LIMIT, label + " later departure cannot rewrite score result as forfeit")
	# Timeout is separately produced by the authority's actual deadline branch.
	var timeout_session := _fixture(mode, hex_enabled)
	if timeout_session == null:
		return
	timeout_session.session_round.round_end_tick = timeout_session.world.tick
	var timeout_events := timeout_session.advance_round([])
	timeout_session.record_combat_events(timeout_events)
	var timeout := _assert_replication(timeout_session, label + " timeout draw")
	if not timeout.is_empty():
		_assert_finished_event(timeout, 0, SessionRound.ResultReason.TIMEOUT, label)


func _assert_replication(session: AuthoritativeSession, label: String) -> Dictionary:
	var world_hash_before := session.world.state_hash()
	var round_before := session.session_round.capture(session.world)
	check(SessionRound.validate_packet(round_before), label + " round capture is a positive control")
	var envelope := session.capture_envelope()
	check(WorldSnapshotEnvelope.validate(envelope), label + " real session envelope validates")
	if envelope.is_empty():
		return {}
	equal(session.world.state_hash(), world_hash_before, label + " capture does not mutate world authority")
	equal(session.session_round.capture(session.world), round_before, label + " capture does not mutate round state")
	var bytes := var_to_bytes(envelope)
	var received_value: Variant = bytes_to_var(bytes)
	check(received_value is Dictionary, label + " exact serialized envelope decodes as a dictionary")
	if not received_value is Dictionary:
		return {}
	var received: Dictionary = received_value
	check(WorldSnapshotEnvelope.validate(received), label + " independently deserialized envelope validates")
	equal(var_to_bytes(received), bytes, label + " serialized packet has an exact lossless round trip")
	equal(WorldSnapshotEnvelope.round_state(received), round_before, label + " replicated round bytes exactly match authority")
	equal(SessionRound.decoded(WorldSnapshotEnvelope.round_state(received)), SessionRound.decoded(round_before), label + " every decoded team field matches the same capture")
	var received_before := var_to_bytes(received)
	var metadata := WorldSnapshotEnvelope.metadata(received)
	check(not metadata.is_empty(), label + " validated metadata projection succeeds")
	equal(var_to_bytes(received), received_before, label + " metadata reads do not mutate the received packet")
	var detached_round: PackedInt32Array = metadata.round
	detached_round[9] = 99
	metadata.round = detached_round
	equal(var_to_bytes(received), received_before, label + " caller mutations cannot reach the packet's round lane")
	if session.world.hex_court != null:
		var replica := HexWorldSnapshot.prepare(WorldSnapshotEnvelope.authority(received), session.world)
		check(replica != null, label + " strict HEX authority reconstruction succeeds")
		if replica != null:
			equal(replica.state_hash(), session.world.state_hash(), label + " reconstructed HEX state matches authority exactly")
	else:
		var snapshot := session.capture_snapshot()
		check(SessionSnapshot.validate(snapshot), label + " direct legacy snapshot validates")
		equal(SessionSnapshot.round_values(snapshot), round_before, label + " direct legacy and envelope captures agree")
		var replica := SimWorld.new(120, 752, CollisionWorld.new(1_280_000, 960_000))
		check(SessionSnapshot.apply_to_world(received.authority, replica), label + " legacy authority applies to independent replica")
		for actor: PlayerState in session.world.players:
			var replicated := replica.player(actor.entity_id)
			check(replicated != null, label + " every present actor is replicated")
			if replicated != null:
				equal(replicated.team_id, actor.team_id, label + " actual actor team survives legacy reconstruction")
				equal(replicated.health, actor.health, label + " actual actor health survives legacy reconstruction")
	equal(session.world.state_hash(), world_hash_before, label + " validation and reconstruction leave source world unchanged")
	equal(session.session_round.capture(session.world), round_before, label + " validation and reconstruction leave source round unchanged")
	equal(var_to_bytes(received), received_before, label + " strict reconstruction leaves received bytes unchanged")
	return received


func _assert_live_team_mismatch(envelope: Dictionary, label: String) -> void:
	var forged := envelope.duplicate(true)
	var authority: Dictionary = forged.authority
	if int(forged.world_kind) == WorldSnapshotEnvelope.WORLD_HEX:
		var actors: PackedInt32Array = authority.players
		actors[1] = 2
		authority.players = actors
		check(HexWorldSnapshot.validate_wire_structure(authority), label + " mismatched live team still has valid authority wire shape")
	else:
		var rows: Array = authority.players
		var row: Array = rows[0]
		var actor: PackedInt32Array = row[3]
		actor[31] = 2
		row[3] = actor
		rows[0] = row
		authority.players = rows
	forged.authority = authority
	_assert_rejected_read_only(forged, label + " live actor team disagrees with frozen team")


func _assert_forged_present(envelope: Dictionary, absent_id: int, label: String) -> void:
	var forged := envelope.duplicate(true)
	var lane_name := "session" if int(forged.world_kind) == WorldSnapshotEnvelope.WORLD_HEX else "authority"
	var lane: Dictionary = forged[lane_name]
	var values: PackedInt32Array = lane.round
	var changed := false
	for index: int in range(values[6]):
		var offset := SessionRound.HEADER_VALUES + index * SessionRound.ENTRY_VALUES
		if (values[offset] & SessionRound.ENTITY_MASK) == absent_id:
			values[offset + 4] = 1
			changed = true
	check(changed, label + " forged-present fixture finds the departed frozen entry")
	check(SessionRound.validate_packet(values), label + " forged-present round alone is structurally plausible")
	lane.round = values
	forged[lane_name] = lane
	_assert_rejected_read_only(forged, label + " present row refers to missing world actor")


func _assert_healthy_actor_marked_departed(envelope: Dictionary, entity_id: int, label: String) -> void:
	var forged := envelope.duplicate(true)
	var lane_name := "session" if int(forged.world_kind) == WorldSnapshotEnvelope.WORLD_HEX else "authority"
	var lane: Dictionary = forged[lane_name]
	var values: PackedInt32Array = lane.round
	var changed := false
	for index: int in range(values[6]):
		var offset := SessionRound.HEADER_VALUES + index * SessionRound.ENTRY_VALUES
		if (values[offset] & SessionRound.ENTITY_MASK) == entity_id:
			values[offset + 1] = 0
			values[offset + 2] = 0
			values[offset + 4] = 0
			changed = true
	check(changed, label + " healthy-departed fixture finds the scoring actor")
	check(SessionRound.validate_packet(values), label + " falsely departed row is plausible without cross-lane actor health")
	lane.round = values
	forged[lane_name] = lane
	_assert_rejected_read_only(forged, label + " healthy live champion cannot be marked departed")


func _assert_absent_observer_with_health(envelope: Dictionary, entity_id: int, label: String) -> void:
	var forged := envelope.duplicate(true)
	var authority: Dictionary = forged.authority
	var changed := false
	if int(forged.world_kind) == WorldSnapshotEnvelope.WORLD_HEX:
		var actors: PackedInt32Array = authority.players
		for offset: int in range(0, actors.size(), HexWorldSnapshot.PLAYER_VALUE_COUNT):
			if actors[offset] == entity_id:
				equal(actors[offset + 33], 0, label + " valid reused HEX observer begins health zero")
				actors[offset + 33] = 1
				changed = true
		authority.players = actors
		check(HexWorldSnapshot.validate_wire_structure(authority), label + " revived observer still has valid actor wire shape")
	else:
		var rows: Array = authority.players
		for index: int in range(rows.size()):
			var row: Array = rows[index]
			if int(row[0]) == entity_id:
				var actor: PackedInt32Array = row[3]
				equal(actor[12], 0, label + " valid reused legacy observer begins health zero")
				actor[12] = 1
				row[3] = actor
				rows[index] = row
				changed = true
		authority.players = rows
	check(changed, label + " revived-observer fixture finds the reused identity")
	forged.authority = authority
	_assert_rejected_read_only(forged, label + " absent frozen row permits only a health-zero observer")


func _assert_rejected_read_only(envelope: Dictionary, label: String) -> void:
	var before := var_to_bytes(envelope)
	check(not WorldSnapshotEnvelope.validate(envelope), label + " rejects at envelope admission")
	check(WorldSnapshotEnvelope.metadata(envelope).is_empty(), label + " exposes no partial metadata")
	check(WorldSnapshotEnvelope.round_state(envelope).is_empty(), label + " exposes no partial round state")
	if int(envelope.world_kind) == WorldSnapshotEnvelope.WORLD_LEGACY:
		check(not SessionSnapshot.validate(envelope.authority), label + " also rejects direct legacy snapshot")
	equal(var_to_bytes(envelope), before, label + " rejection leaves caller-owned packet unchanged")


func _assert_knockout_event(envelope: Dictionary, owner_id: int, target_id: int, label: String) -> void:
	var found := false
	for values: PackedInt64Array in WorldSnapshotEnvelope.events(envelope):
		var event := SessionSnapshot.decode_event(values)
		if String(event.get("type", "")) != "round_knockout" or int(event.get("owner_id", 0)) != owner_id:
			continue
		found = true
		equal(int(event.target_id), target_id, label + " knockout victim survives the real event codec")
		check(bool(event.get("scored", false)), label + " credited knockout survives scored flag")
		equal(int(event.get("credited_team_id", 0)), 1, label + " credited team survives event codec")
		equal(int(event.get("team_score", -1)), 1, label + " explicit shared total survives event codec")
		check(SessionSnapshot._valid_event_values(values), label + " credited event row passes strict validation")
		equal(SessionSnapshot.encode_event(event), values, label + " knockout event has an exact codec round trip")
		for flag: int in [-1, 2, 4, 7, 8]:
			var malformed := values.duplicate()
			malformed[4] = flag
			check(not SessionSnapshot._valid_event_values(malformed), label + " rejects malformed or unscored-with-credit knockout flag")
	check(found, label + " envelope contains the actual simulated knockout outcome")


func _assert_finished_event(envelope: Dictionary, winner_team: int, reason: int, label: String) -> void:
	var found := false
	for values: PackedInt64Array in WorldSnapshotEnvelope.events(envelope):
		var event := SessionSnapshot.decode_event(values)
		if String(event.get("type", "")) != "round_finished":
			continue
		found = true
		equal(int(event.get("winner_id", -1)), 0, label + " team finish does not fabricate an entity winner")
		equal(int(event.get("winner_team_id", -1)), winner_team, label + " team finish winner survives codec")
		equal(int(event.get("result_reason", -1)), reason, label + " explicit finish reason survives codec")
		check(SessionSnapshot._valid_event_values(values), label + " finish event passes strict wire validation")
		equal(SessionSnapshot.encode_event(event), values, label + " finish event has an exact codec round trip")
		var malformed := values.duplicate()
		malformed[2] = 3
		check(not SessionSnapshot._valid_event_values(malformed), label + " finish rejects unknown winner team")
		malformed = values.duplicate()
		malformed[3] = 99
		check(not SessionSnapshot._valid_event_values(malformed), label + " finish rejects unknown result reason")
	check(found, label + " envelope contains the real authoritative finish outcome")


func _entry(decoded: Dictionary, entity_id: int) -> Dictionary:
	for entry: Dictionary in decoded.get("entries", []):
		if int(entry.entity_id) == entity_id:
			return entry
	return {}
