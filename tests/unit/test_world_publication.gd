extends FluxTestSuite

const Bootstrap = preload("res://src/app/bootstrap.gd")

class Harness:
	extends "res://src/app/bootstrap.gd"
	var refuse_context := false
	var spectator_test := false
	var preparation_count := 0
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _draw() -> void: pass
	func _incoming_spectator_state(_candidate: SimWorld, _envelope: Dictionary) -> bool: return spectator_test
	func _prepare_client_hex_context(predictor: ClientPrediction, candidate: SimWorld) -> Dictionary:
		preparation_count += 1
		return {} if refuse_context else super._prepare_client_hex_context(predictor, candidate)

func run() -> int:
	_test_publication_transaction()
	_test_preparation_is_detached()
	return finish("world-publication")

func _test_publication_transaction() -> void:
	var node := Harness.new()
	node.preference_overrides_are_transient = true
	node.preferences_persistence_allowed = false
	node.campus_layout = SanctumCampusLayout.new()
	check(node.campus_layout.load_from_file(Bootstrap.CAMPUS_LAYOUT_PATH), "transaction loads trusted campus")
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file(Bootstrap.ABILITY_CATALOG_PATH), "transaction loads paid spells")
	var champions := ChampionCatalog.new()
	check(champions.load_from_file(Bootstrap.CHAMPION_CATALOG_PATH, abilities), "transaction loads current cast")
	var authority: SimWorld = node._new_wellspring_world(120)
	var template: SimWorld = node._new_wellspring_world(120)
	check(authority != null and template != null, "transaction builds independent trusted worlds")
	if authority == null or template == null:
		node.free()
		return
	champions.apply_to_player(authority.player(), champions.default_champion_id)
	champions.apply_to_player(template.player(), champions.default_champion_id)
	authority.player().reset_for_spawn(node.campus_layout.spawn * SimConfig.FIXED_SCALE)
	template.player().reset_for_spawn(node.campus_layout.spawn * SimConfig.FIXED_SCALE)
	var host := AuthoritativeSession.new()
	check(host.bind(authority, champions, node.campus_layout.spawn, "Host", [{"entity_id": 2, "name": "Guest"}]), "actual guest is admitted")
	node.trusted_hex_template = template
	node.session_transport = SessionTransport.new()
	node.session_transport.local_entity_id = 2
	node.client_prediction = ClientPrediction.new()
	var first := host.capture_envelope()
	check(node._apply_world_envelope(first), "first complete world publishes")
	if node.world == null:
		node.free()
		return
	node.last_client_snapshot_tick = int(first.tick)
	check(node.client_prediction.reconcile(ClientPrediction.capture_packet(node.world.player(2), node.world.tick, -1)), "initial matching actor reconciles")
	check(node.client_prediction.queue_input(1, SimCommand.new(node.world.tick, 2, 1000, 0)), "real unacknowledged movement is retained")
	var original: SimWorld = node.world
	var prediction: ClientPrediction = node.client_prediction
	var context: HexChemistryWorld = prediction.hex_authority
	var state := prediction.predicted_state.canonical_values()
	var command_bytes := (prediction.pending_inputs[0].command as SimCommand).canonical_bytes()
	var queued := ClientPrediction.capture_packet(original.player(2), original.tick + 1, 1)
	queued.world_epoch = int(first.world_epoch)
	check(node.client_reconciliation_buffer.offer(queued), "future actor acknowledgement waits for complete geometry")
	node.combat_cues.append({"test": "keep"})
	node.social_bubbles.append({"test": "keep"})
	check(authority.step([]), "host advances before next complete snapshot")
	var next := host.capture_envelope()
	node.refuse_context = true
	for epoch: int in [int(first.world_epoch), int(first.world_epoch) + 1]:
		var attempted := next.duplicate(true)
		attempted.world_epoch = epoch
		check(WorldSnapshotEnvelope.validate(attempted), "refused fixture remains valid at envelope boundary")
		check(not node._apply_world_envelope(attempted), "prediction preparation refusal rejects complete publication")
		check(node.world == original and node.client_prediction == prediction, "refusal preserves exact published objects")
		check(prediction.hex_authority == context, "refusal preserves prediction geometry object")
		equal(prediction.predicted_state.canonical_values(), state, "refusal preserves predicted movement")
		equal((prediction.pending_inputs[0].command as SimCommand).canonical_bytes(), command_bytes, "refusal preserves pending input")
		equal(node.last_client_world_epoch, int(first.world_epoch), "refusal preserves published epoch")
		equal(node.last_client_snapshot_tick, int(first.tick), "refusal preserves snapshot cursor")
		equal(node.client_reconciliation_buffer.active_epoch, int(first.world_epoch), "refusal preserves buffer epoch")
		check(node.client_reconciliation_buffer.has_tick(int(next.tick)), "refusal preserves waiting exact acknowledgement")
		equal(node.combat_cues.size(), 1, "refusal preserves combat cues")
		equal(node.social_bubbles.size(), 1, "refusal preserves social cues")
	node.refuse_context = false
	check(node._apply_world_envelope(next), "same-epoch valid retry publishes")
	check(node.client_prediction == prediction, "same epoch preserves predictor identity/history")
	check(node.client_prediction.hex_authority != context, "same epoch replaces geometry after successful preparation")
	equal(node.client_prediction.pending_count(), 1, "same epoch keeps unacknowledged movement")
	check(node.client_prediction.reconcile(node.client_reconciliation_buffer.take_exact(int(next.world_epoch), int(next.tick))), "queued reconciliation uses matching accepted geometry")
	equal(node.client_prediction.pending_count(), 0, "accepted acknowledgement removes only processed input")
	node.last_client_snapshot_tick = int(next.tick)
	var replaced := next.duplicate(true)
	replaced.world_epoch = int(next.world_epoch) + 1
	check(node._apply_world_envelope(replaced), "new epoch publishes as a complete pair")
	check(node.client_prediction != prediction, "new epoch starts detached predictor")
	equal(node.client_prediction.hex_context_tick, int(replaced.tick), "new predictor owns current geometry")
	equal(node.client_prediction.pending_count(), 0, "new epoch discards previous history only on success")
	check(node.combat_cues.is_empty() and node.social_bubbles.is_empty(), "new epoch clears old cues on commit")
	var epoch_prediction: ClientPrediction = node.client_prediction
	node.session_transport.local_entity_id = 99
	replaced.world_epoch += 1
	check(not node._apply_world_envelope(replaced), "invalid local actor refuses before publication")
	check(node.client_prediction == epoch_prediction, "configuration failure cannot reset current predictor")
	node.session_transport.local_entity_id = 2
	node.spectator_test = true
	node.refuse_context = true
	var prepared_before: int = node.preparation_count
	check(node._apply_world_envelope(replaced), "spectator can publish without local prediction preparation")
	equal(node.preparation_count, prepared_before, "spectator path never asks for a local movement context")
	check(node.client_prediction.hex_authority == null and not node.client_prediction.is_ready(), "spectator new epoch cannot retain old prediction")
	var published: SimWorld = node.world
	check(not node._apply_world_envelope(first), "stale epoch still refuses")
	check(node.world == published, "stale packet leaves spectator world intact")
	node.free()

func _test_preparation_is_detached() -> void:
	var fixture := preload("res://tests/unit/test_unified_prediction.gd").new()
	var world: SimWorld = fixture._world([])
	world.players = [fixture._actor(Vector2i(1_000_000, 1_000_000))]
	var prediction := ClientPrediction.new()
	check(prediction.configure(world.config, world.collision, 2), "detached context configures")
	var prior_collision: CollisionWorld = prediction.collision
	var prepared := prediction.prepare_hex_context(world)
	check(not prepared.is_empty(), "valid context prepares")
	check(prediction.hex_authority == null and prediction.collision == prior_collision, "prepare changes no published predictor fields")
	check(prepared.authority != world.hex_court and prepared.collision != world.collision, "prepared mutable context is detached")
	prediction.publish_hex_context(prepared)
	check(prediction.hex_authority == prepared.authority, "commit publishes the prepared authority without preparing twice")
	check(prediction.prepare_hex_context(null).is_empty(), "null preparation refuses")
	check(prediction.hex_authority == prepared.authority, "failed later preparation preserves committed context")
