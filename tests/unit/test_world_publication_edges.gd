extends FluxTestSuite
## Application publication edges through real transport/round admission. No
## sockets, scene startup, profile persistence or rendering are needed here.

const Bootstrap = preload("res://src/app/bootstrap.gd")

class Harness:
	extends "res://src/app/bootstrap.gd"
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _draw() -> void: pass


func run() -> int:
	_test_transport_ahead_of_rejected_world()
	_test_spectator_handoff_first_envelope()
	_test_hex_to_legacy_replacement()
	return finish("world-publication-edges")


func _fixture(local_id: int = 2) -> Dictionary:
	var node := Harness.new()
	node.preference_overrides_are_transient = true
	node.preferences_persistence_allowed = false
	node.campus_layout = SanctumCampusLayout.new()
	var abilities := AbilityCatalog.new()
	var champions := ChampionCatalog.new()
	var loaded: bool = node.campus_layout.load_from_file(Bootstrap.CAMPUS_LAYOUT_PATH) \
		and abilities.load_from_file(Bootstrap.ABILITY_CATALOG_PATH) \
		and champions.load_from_file(Bootstrap.CHAMPION_CATALOG_PATH, abilities)
	check(loaded, "publication edges load trusted campus and current catalogs")
	if not loaded:
		node.free()
		return {}
	node.ability_catalog = abilities
	node.champion_catalog = champions
	node.spell_loom_editor = SpellLoomEditor.new()
	var authority: SimWorld = node._new_wellspring_world(120)
	var template: SimWorld = node._new_wellspring_world(120)
	check(authority != null and template != null, "publication edges construct independent authority and trusted template")
	if authority == null or template == null:
		node.free()
		return {}
	champions.apply_to_player(authority.player(), champions.default_champion_id)
	champions.apply_to_player(template.player(), champions.default_champion_id)
	authority.player().reset_for_spawn(node.campus_layout.spawn * SimConfig.FIXED_SCALE)
	template.player().reset_for_spawn(node.campus_layout.spawn * SimConfig.FIXED_SCALE)
	var host := AuthoritativeSession.new()
	var bound := host.bind(authority, champions, node.campus_layout.spawn, "Host", [
		{"entity_id": 2, "name": "Participant"}, {"entity_id": 3, "name": "Late guest"},
	])
	check(bound, "publication edges admit actual champion identities before snapshots")
	if not bound:
		node.free()
		return {}
	node.trusted_hex_template = template
	node.session_transport = SessionTransport.new()
	node.session_transport.mode = SessionTransport.Mode.CLIENT
	node.session_transport.accepted = true
	node.session_transport.local_entity_id = local_id
	node.session_transport.world_epoch = -1
	node.client_prediction = ClientPrediction.new()
	node.spectator_focus = SpectatorFocus.new()
	return {"node": node, "authority": authority, "host": host, "champions": champions}


func _deliver(node: Harness, envelope: Dictionary) -> bool:
	# Match the production order: transport acceptance may advance first, then
	# application preparation decides whether a complete world can publish.
	node.session_transport._accept_envelope(envelope)
	var received: Array[Dictionary] = node.session_transport.poll_envelopes()
	check(received.size() == 1, "one complete envelope reaches the application boundary")
	if received.size() != 1: return false
	var candidate: Dictionary = received[0]
	if not node._apply_world_envelope(candidate): return false
	node.last_client_snapshot_tick = int(candidate.tick)
	node.session_hearth_values = WorldSnapshotEnvelope.hearth(candidate)
	node.session_round_values = WorldSnapshotEnvelope.round_state(candidate)
	node._reconcile_spectator_focus()
	return true


func _test_transport_ahead_of_rejected_world() -> void:
	var fixture := _fixture()
	if fixture.is_empty(): return
	var node: Harness = fixture.node
	var authority: SimWorld = fixture.authority
	var host: AuthoritativeSession = fixture.host
	check(not node._client_world_ready(), "accepted client without an application world remains unready")
	check(_deliver(node, host.capture_envelope()), "initial complete transport/application world publishes")
	if node.world == null:
		node.free()
		return
	check(node._client_world_ready(), "matching accepted transport/application epochs are ready")
	for field: String in ["map_hash", "map_id"]:
		var prediction: ClientPrediction = node.client_prediction
		check(prediction.reconcile(ClientPrediction.capture_packet(node.world.player(2), node.world.tick, -1)), "current accepted predictor has a real authoritative movement state")
		check(prediction.queue_input(1, SimCommand.new(node.world.tick, 2, 1000, 0)), "current accepted predictor retains pending movement")
		var published: SimWorld = node.world
		var old_epoch: int = node.last_client_world_epoch
		var old_tick: int = node.last_client_snapshot_tick
		var old_context: HexChemistryWorld = prediction.hex_authority
		var old_state: PackedInt64Array = prediction.predicted_state.canonical_values()
		var old_command: PackedByteArray = (prediction.pending_inputs[0].command as SimCommand).canonical_bytes()
		var waiting := ClientPrediction.capture_packet(published.player(2), published.tick + 1, 1)
		waiting.world_epoch = old_epoch
		check(node.client_reconciliation_buffer.offer(waiting), "application retains an exact old-epoch acknowledgement before refusal")
		node.combat_cues.append({"test": field})
		node.social_bubbles.append({"test": field})
		check(authority.step([]), "authority advances to a future complete frame")
		var rejected: Dictionary = host.capture_envelope()
		rejected.world_epoch = old_epoch + 1
		rejected.authority[field] = "0".repeat(64) if field == "map_hash" else "unknown-trusted-campus"
		check(WorldSnapshotEnvelope.validate(rejected), "wrong trusted %s is structurally valid transport data" % field)
		check(not _deliver(node, rejected), "application refuses wrong trusted %s after transport acceptance" % field)
		equal(node.session_transport.world_epoch, old_epoch + 1, "transport monotonically advances after structural acceptance")
		check(not node._client_world_ready(), "transport ahead of application keeps gameplay readiness closed")
		check(node.world == published and node.client_prediction == prediction, "semantic refusal preserves published world/predictor identities")
		check(prediction.hex_authority == old_context, "semantic refusal preserves existing prediction geometry")
		equal(prediction.predicted_state.canonical_values(), old_state, "semantic refusal preserves actual predicted movement")
		equal((prediction.pending_inputs[0].command as SimCommand).canonical_bytes(), old_command, "semantic refusal preserves pending command bytes")
		equal(node.last_client_world_epoch, old_epoch, "semantic refusal cannot publish the new epoch")
		equal(node.last_client_snapshot_tick, old_tick, "semantic refusal cannot advance the application snapshot cursor")
		equal(node.client_reconciliation_buffer.active_epoch, old_epoch, "semantic refusal retains the application reconciliation epoch")
		check(node.client_reconciliation_buffer.has_tick(published.tick + 1), "semantic refusal retains application-staged reconciliation")
		equal(node.combat_cues.size(), 1, "semantic refusal preserves visible combat cues")
		equal(node.social_bubbles.size(), 1, "semantic refusal preserves visible social cues")
		_assert_sync_actions_blocked(node)
		# Transport has consumed the refused tick. A newer valid frame in that
		# same transport epoch must recover without rolling transport backwards.
		check(authority.step([]), "authority advances beyond the refused transport cursor")
		var recovery: Dictionary = host.capture_envelope()
		recovery.world_epoch = old_epoch + 1
		check(_deliver(node, recovery), "newer valid frame recovers within the already accepted transport epoch")
		check(node._client_world_ready(), "valid application publication reopens matching-epoch readiness")
		check(node.client_prediction != prediction, "recovery commits a fresh new-epoch predictor")
		equal(node.client_reconciliation_buffer.active_epoch, old_epoch + 1, "only successful recovery replaces the application buffer epoch")
		check(node.combat_cues.is_empty() and node.social_bubbles.is_empty(), "successful new-epoch publication clears old cues")
	node.free()


func _assert_sync_actions_blocked(node: Harness) -> void:
	var actor: PlayerState = node.world.player(node.session_transport.local_entity_id)
	var sequence: int = node.client_request_sequence
	var canonical: PackedInt64Array = actor.canonical_values()
	check(node.session_transport.peer == null, "sync-gate fixture has no peer for accidental outbound requests")
	node._submit_session_request(SessionTransport.REQUEST_READY_TOGGLE)
	equal(node.client_request_sequence, sequence, "unpublished transport epoch cannot consume a session request sequence")
	check(node.station_notice.begins_with("Synchronizing"), "blocked session request explains that world synchronization is pending")
	var gallery: Dictionary = node._gallery_selection_availability(actor)
	check(not bool(gallery.get("enabled", true)), "character selection is unavailable while the application epoch trails transport")
	check(String(gallery.get("reason", "")).begins_with("Synchronizing"), "character selection reports synchronization rather than a station failure")
	node.spell_loom_editor.open_editor(actor, node.ability_catalog)
	var preview_ready: bool = node.spell_loom_editor.prepare_starter_preview(actor, node.champion_catalog, node.ability_catalog)
	check(preview_ready, "sync-gate fixture prepares a real catalog-backed starter preview")
	if not preview_ready: return
	var request: Dictionary = node.spell_loom_editor.request_starter_apply()
	var expected: PackedInt32Array = request.expected_wire_ids
	var requested: PackedInt32Array = request.wire_ids
	var availability: Dictionary = node._loom_assignment_availability(actor, requested, true)
	check(not bool(availability.get("enabled", true)), "whole-weave assignment is unavailable while the application epoch trails transport")
	check(String(availability.get("reason", "")).begins_with("Synchronizing"), "whole-weave assignment identifies the synchronization gate")
	check(node.pending_weave_request.is_empty(), "sync-gate fixture starts without a pending weave request")
	var preview_notice: String = String(node.spell_loom_editor.starter_preview.notice)
	node._submit_whole_weave(actor, expected, requested, CharacterWeaveLibrary.MODE_STARTER, true, true)
	equal(node.client_request_sequence, sequence, "blocked whole-weave submission cannot consume a request sequence")
	check(node.pending_weave_request.is_empty(), "blocked whole-weave submission cannot leave the editor waiting on authority")
	check(node.spell_loom_editor.status_message.begins_with("Synchronizing"), "blocked whole-weave submission explains why no apply was sent")
	check(node.spell_loom_editor.starter_preview_active(), "blocked whole-weave submission keeps its reviewable preview")
	equal(String(node.spell_loom_editor.starter_preview.notice), preview_notice, "blocked whole-weave submission does not mark the preview sent or uncancellable")
	equal(actor.canonical_values(), canonical, "sync-gated actions leave every authoritative actor field unchanged")
	node.spell_loom_editor.cancel_starter_preview(false)
	check(not node.spell_loom_editor.starter_preview_active(), "blocked preview remains cancellable without an authority response")
	node.spell_loom_editor.close_editor()


func _test_spectator_handoff_first_envelope() -> void:
	var fixture := _fixture(3)
	if fixture.is_empty(): return
	var node: Harness = fixture.node
	var authority: SimWorld = fixture.authority
	var host: AuthoritativeSession = fixture.host
	var began := host.session_round.begin(authority, [1, 2], node.campus_layout.arena_definition)
	check(began, "actual Court round begins with two participants and excludes the late local guest")
	if not began:
		node.free()
		return
	var active_applied := _deliver(node, host.capture_envelope())
	check(active_applied, "late guest accepts the actual incoming active-round envelope")
	if not active_applied:
		node.free()
		return
	check(node.spectator_focus.active and node._is_spectating(), "real incoming round/focus logic makes the late guest a spectator")
	equal(node.spectator_focus.participant_entity_ids, [1, 2], "spectator follows the actual admitted round roster")
	check(node.client_prediction.hex_authority == null and node.client_prediction.config == null, "spectator does not retain a local movement context")
	var old_epoch: int = node.last_client_world_epoch
	host.session_round.bind_hearth()
	check(authority.step([]), "Hearth handoff advances one real authority tick")
	var handoff: Dictionary = host.capture_envelope()
	var handoff_applied := _deliver(node, handoff)
	check(handoff_applied, "first same-epoch Hearth envelope publishes its staged movement context")
	if not handoff_applied:
		node.free()
		return
	equal(node.last_client_world_epoch, old_epoch, "handoff exercises same-epoch readiness rather than relying on epoch reset")
	check(not node.spectator_focus.active and not node._is_spectating(), "real incoming Hearth round restores local play")
	check(node.client_prediction.config != null and node.client_prediction.hex_authority != null, "focus reconciliation keeps the freshly staged prediction context")
	equal(node.client_prediction.local_entity_id, 3, "first handoff context belongs to the returning local guest")
	equal(node.client_prediction.hex_context_tick, int(handoff.tick), "first handoff context has exactly the accepted envelope geometry tick")
	var packet := ClientPrediction.capture_packet(node.world.player(3), node.world.tick, -1)
	packet.world_epoch = old_epoch
	node.session_transport._accept_reconciliation(packet, old_epoch)
	var reconciliations: Array[Dictionary] = node.session_transport.take_reconciliations()
	equal(reconciliations.size(), 1, "matching first-handoff reconciliation survives transport admission")
	equal(node.client_reconciliation_buffer.offer_many(reconciliations), 1, "matching first-handoff reconciliation reaches application staging")
	var exact: Dictionary = node.client_reconciliation_buffer.take_exact(old_epoch, node.world.tick)
	check(not exact.is_empty() and node.client_prediction.reconcile(exact), "first handoff reconciliation succeeds without another world envelope")
	check(node.client_prediction.is_ready(), "first-envelope handoff leaves a usable local predictor")
	if node.client_prediction.is_ready():
		equal(node.client_prediction.predicted_state.canonical_values(), ClientPrediction.restore_state(packet.values).canonical_values(), "first-envelope movement matches the exact reconciled fields")
	node.free()


func _test_hex_to_legacy_replacement() -> void:
	var fixture := _fixture()
	if fixture.is_empty(): return
	var node: Harness = fixture.node
	var host: AuthoritativeSession = fixture.host
	var champions: ChampionCatalog = fixture.champions
	check(_deliver(node, host.capture_envelope()), "hex-to-legacy fixture first publishes hex authority")
	if node.world == null:
		node.free()
		return
	var old_prediction: ClientPrediction = node.client_prediction
	check(old_prediction.hex_authority != null, "replacement starts with real hex prediction geometry")
	check(old_prediction.reconcile(ClientPrediction.capture_packet(node.world.player(2), node.world.tick, -1)), "replacement starts with a seeded prediction")
	check(old_prediction.queue_input(1, SimCommand.new(node.world.tick, 2, 1000, 0)), "replacement starts with old-world pending input")
	var legacy := SimWorld.new(120, 8675309, node.campus_layout.build_collision_world(), String(node.campus_layout.data.id), node.campus_layout.content_hash)
	champions.apply_to_player(legacy.player(), champions.default_champion_id)
	var guest := PlayerState.new(2)
	champions.apply_to_player(guest, champions.default_champion_id)
	legacy.players.append(guest)
	for actor: PlayerState in legacy.players:
		actor.reset_for_spawn(node.campus_layout.spawn * SimConfig.FIXED_SCALE)
	legacy.tick = node.world.tick + 1
	var envelope := WorldSnapshotEnvelope.wrap_legacy(SessionSnapshot.capture(legacy, {1: "Host", 2: "Participant"}), node.last_client_world_epoch)
	check(WorldSnapshotEnvelope.validate(envelope), "same-epoch legacy replacement is a real valid envelope")
	check(_deliver(node, envelope), "same-epoch hex-to-legacy replacement publishes")
	check(node._client_world_ready() and node.world.hex_court == null, "legacy replacement remains ready without old chemistry authority")
	check(node.client_prediction != old_prediction, "world-kind replacement cannot retain old pending prediction history")
	check(node.client_prediction.hex_authority == null, "legacy predictor clears the old hex chemistry object")
	equal(node.client_prediction.hex_context_tick, -1, "legacy predictor clears the old hex geometry tick")
	check(not node.client_prediction.collision is HexCollisionWorld, "legacy predictor does not retain dynamic hex collision")
	equal(node.client_prediction.pending_count(), 0, "legacy replacement clears old-world pending commands")
	check(node.client_prediction.reconcile(ClientPrediction.capture_packet(node.world.player(2), node.world.tick, -1)), "first legacy actor reconciliation works after context replacement")
	node.free()
