extends FluxTestSuite

const Grid = preload("res://src/presentation/character_selection_grid.gd")
const Model = preload("res://src/app/character_selection_model.gd")


# Reconciliation and feedback remain the actual Bootstrap methods. This node is
# never attached to a tree: no startup, preferences, frames, drawing or sockets.
class AttunementHarness:
	extends "res://src/app/bootstrap.gd"
	func _ready() -> void:
		pass
	func _process(_delta: float) -> void:
		pass
	func _draw() -> void:
		pass


func run() -> int:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "attunement recovery loads actual abilities")
	var champions := ChampionCatalog.new()
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "attunement recovery loads actual champions")
	var roster := ChampionRosterPlan.new()
	check(roster.load_from_files(), "attunement recovery loads actual Gallery roster")
	var grid := Grid.new()
	check(grid.configure(champions, roster), "attunement recovery configures standalone production Gallery")
	var original := champions.default_champion_id
	grid.open_panel(original)
	var target := _select_other(grid.model, original)
	check(not target.is_empty(), "attunement recovery has a real alternate playable identity")
	if target.is_empty(): return finish("character-attunement-recovery")
	var champion_hash := champions.content_hash
	var roster_hash := roster.content_hash
	_test_timeout_and_retry(grid, original, target)
	_test_authority_completion(grid, original, target)
	_test_context_changes(grid, original, target)
	_test_stale_feedback(grid, original, target)
	_test_failed_send_and_reload(grid, champions, roster, original, target)
	_test_bootstrap_authority(champions, roster, original, target)
	equal(champions.content_hash, champion_hash, "UI request recovery never changes champion authority")
	equal(roster.content_hash, roster_hash, "UI request recovery never changes roster definitions")
	return finish("character-attunement-recovery")


func _select_other(model: CharacterSelectionModel, original: String) -> String:
	for race: int in model.races().size():
		for character: int in model.characters(race).size():
			model.select_cell(race, character)
			var entry := model.selected_entry()
			if bool(entry.get("selectable", false)) and String(entry.get("id", "")) != original:
				return String(entry.id)
	return ""


func _select(model: CharacterSelectionModel, id: String) -> void:
	for race: int in model.races().size():
		for character: int in model.characters(race).size():
			model.select_cell(race, character)
			if String(model.selected_entry().get("id", "")) == id: return
	check(false, "requested test identity exists in actual Gallery")


func _arm(grid: CharacterSelectionGrid, original: String, target: String, context: Array, now_ms: int) -> int:
	grid.open_panel(original)
	grid.reconcile_attunement(context, original, now_ms, true)
	_select(grid.model, target)
	var wire := grid.model.request_selection()
	check(wire > 0, "deliberate selection creates one pending request")
	check(grid.bind_pending_attunement(context, now_ms), "pending request binds current session and monotonic deadline")
	equal(grid.model.equipped_id, original, "sending never fabricates equipped success")
	return wire


func _test_timeout_and_retry(grid: CharacterSelectionGrid, original: String, target: String) -> void:
	var context: Array = [2, 2, 7, 9001]
	var wire := _arm(grid, original, target, context, 1000)
	check(not grid.bind_pending_attunement(context, 5000), "repeated binding cannot postpone an existing deadline")
	equal(grid.reconcile_attunement(context, original, 5999), "", "lost refusal remains pending before its local deadline")
	equal(grid.model.pending_wire, wire, "pending intent survives ordinary unchanged authoritative snapshots")
	equal(grid.model.request_selection(), 0, "pending request cannot automatically queue a duplicate")
	grid.close_panel()
	equal(grid.reconcile_attunement(context, original, 6000), "timed_out", "lost refusal unlocks after exactly five seconds even with Gallery closed")
	equal(grid.model.pending_wire, 0, "timeout releases UI lock")
	equal(grid.model.equipped_id, original, "timeout preserves actual current identity")
	check(grid.model.status_message.contains("not cancelled") and grid.model.status_message.contains("retrying"), "timeout accurately warns that authority was not cancelled")
	equal(grid.reconcile_attunement(context, original, 9000), "", "timeout is one local transition, not repeated requests")
	equal(grid.model.request_selection(), wire, "timeout permits a deliberate retry of the same selection")
	check(grid.bind_pending_attunement(context, 9000), "retry has its own bounded local lifetime")
	equal(grid.reconcile_attunement(context, original, 13_999), "", "retry does not inherit expired deadline")
	equal(grid.reconcile_attunement(context, original, 14_000), "timed_out", "retry has the same unchanged timeout")
	var timed_out_message := grid.model.status_message
	equal(grid.reconcile_attunement(context, target, 14_001), "", "late authority is not falsely called an acknowledgement of a retired UI request")
	equal(grid.model.equipped_id, target, "late real authoritative change still updates the equipped identity")
	equal(grid.model.status_message, timed_out_message, "late identity sync does not invent request correlation")
	check(grid.confirm_attunement_feedback(target, context), "matching late feedback can be recognized as describing current authority")
	equal(grid.model.status_message, timed_out_message, "late feedback cannot manufacture a pending-request success message")


func _test_authority_completion(grid: CharacterSelectionGrid, original: String, target: String) -> void:
	var context: Array = [2, 2, 7, 9001]
	var wire := _arm(grid, original, target, context, 20_000)
	equal(grid.reconcile_attunement(context, target, 20_001, false), "", "unpublished or syncing candidate does not prove completion")
	equal(grid.model.pending_wire, wire, "syncing source keeps pending intent")
	equal(grid.model.equipped_id, original, "syncing target cannot replace equipped authority")
	equal(grid.reconcile_attunement(context, "not-a-champion", 20_002, true), "", "invalid alleged authority cannot complete request")
	equal(grid.model.pending_wire, wire, "invalid identity keeps pending intent")
	equal(grid.reconcile_attunement(context, target, 25_000, true), "confirmed", "fresh matching authority wins exactly at timeout boundary")
	equal(grid.model.pending_wire, 0, "actual completion clears pending state")
	equal(grid.model.equipped_id, target, "actual completion identifies the published champion")
	check(grid.model.status_message.begins_with("Attuned:"), "actual pending success uses existing truthful confirmation")
	equal(grid.model.request_selection(), 0, "confirmed selection becomes an unchanged no-op")


func _test_context_changes(grid: CharacterSelectionGrid, original: String, target: String) -> void:
	var old_context: Array = [2, 2, 7, 9001]
	for new_context: Array in [[0, 1, -1, 0], [2, 3, 7, 9001], [2, 2, 8, 9001], [2, 2, 7, 9002]]:
		_arm(grid, original, target, old_context, 30_000)
		equal(grid.reconcile_attunement(new_context, target, 30_001, true), "context_changed", "mode/entity/epoch/peer replacement invalidates the old request before matching identity")
		equal(grid.model.pending_wire, 0, "context transition unlocks stale pending UI")
		equal(grid.model.equipped_id, target, "new context may display its actual champion without claiming old-request success")
		check(not grid.model.status_message.begins_with("Attuned:"), "new context never fabricates old request acceptance")
		check(not grid.confirm_attunement_feedback(target, old_context), "old context feedback cannot rewrite current Gallery")
	var supplied: Array = old_context.duplicate()
	_arm(grid, original, target, supplied, 40_000)
	supplied[3] = 8000
	equal(grid.reconcile_attunement(old_context, original, 40_001), "", "caller context mutation cannot alter captured request identity")
	equal(grid.reconcile_attunement(old_context, target, 40_002), "confirmed", "detached context still recognizes actual original session")


func _test_stale_feedback(grid: CharacterSelectionGrid, original: String, target: String) -> void:
	var context: Array = [2, 2, 7, 9001]
	var wire := _arm(grid, original, target, context, 50_000)
	check(not grid.confirm_attunement_feedback(target, context), "event alone cannot claim unobserved authoritative target")
	check(not grid.confirm_attunement_feedback(original, context), "old current-character event cannot retire another wire's pending intent")
	equal(grid.model.pending_wire, wire, "stale or premature events preserve pending request")
	equal(grid.model.equipped_id, original, "stale events cannot change actual equipped badge")
	grid.reconcile_attunement(context, target, 50_001, false)
	check(not grid.confirm_attunement_feedback(target, context), "event cannot upgrade non-ready authority to success")
	equal(grid.reconcile_attunement(context, target, 50_002), "confirmed", "fresh publication remains sufficient when its event was lost")
	check(not grid.confirm_attunement_feedback(original, context), "late mismatched confirmation cannot overwrite a newer published identity")
	equal(grid.model.equipped_id, target, "newest actual identity survives stale feedback")


func _test_failed_send_and_reload(grid: CharacterSelectionGrid, champions: ChampionCatalog, roster: ChampionRosterPlan, original: String, target: String) -> void:
	var context: Array = [2, 2, 7, 9001]
	_arm(grid, original, target, context, 60_000)
	grid.refuse("Request could not be sent.")
	equal(grid.model.pending_wire, 0, "existing send/refusal route clears new deadline and context too")
	equal(grid.reconcile_attunement(context, original, 70_000), "", "failed send leaves no late timeout")
	_arm(grid, original, target, context, 70_000)
	check(not grid.configure(null, null), "failed catalog replacement remains refused")
	equal(grid.model.pending_wire, 0, "failed catalog replacement clears pending request")
	check(not grid.confirm_attunement_feedback(target, context), "catalog replacement also clears observed authority proof")
	check(grid.configure(champions, roster), "valid catalogs recover after refused replacement")
	grid.open_panel(original)
	_select(grid.model, target)
	check(grid.model.request_selection() > 0, "recovered model can request another real identity")
	for invalid_context: Array in [[], [2, 2, 7], [2, 2, 7, "9001"], [2, 2, 7, {}]]:
		check(not grid.bind_pending_attunement(invalid_context, 80_000), "request context accepts no malformed shape or live container")
	check(not grid.bind_pending_attunement(context, -1), "negative monotonic timestamp does not arm a request")
	check(grid.bind_pending_attunement(context, 80_000), "invalid binding attempts cannot poison subsequent valid admission")
	equal(grid.reconcile_attunement(context, target, -1), "", "invalid update time cannot fabricate success or clear a request")
	equal(grid.reconcile_attunement(context, original, 85_000), "timed_out", "normal timeout survives malformed update attempts")


func _test_bootstrap_authority(champions: ChampionCatalog, roster: ChampionRosterPlan, original: String, target: String) -> void:
	var node := AttunementHarness.new()
	node.champion_catalog = champions
	node.character_selection_grid = Grid.new()
	check(node.character_selection_grid.configure(champions, roster), "Bootstrap authority harness configures the actual Gallery")
	node.session_transport = SessionTransport.new()
	node.world = SimWorld.new(120, 1, CollisionWorld.new())
	var grid := node.character_selection_grid
	var host := node.world.player(SessionTransport.SERVER_PEER_ID)
	check(champions.apply_to_player(host, original), "offline authority starts with the actual original champion")
	equal(node.session_transport.local_entity_id, 0, "ordinary offline transport has no assigned network identity")
	_arm(grid, original, target, node._weave_session_context(), Time.get_ticks_msec())
	check(champions.apply_to_player(host, target), "ordinary offline authority actually accepts the selected champion")
	node._reconcile_character_attunement()
	equal(grid.model.pending_wire, 0, "Bootstrap confirms actual offline actor1 despite unassigned network ID0")
	equal(grid.model.equipped_id, target, "offline confirmation follows the real host actor")

	node.session_transport.mode = SessionTransport.Mode.CLIENT
	node.session_transport.accepted = true
	node.session_transport.local_entity_id = 2
	node.session_transport.world_epoch = 7
	node.last_client_world_epoch = 7
	var wire := _arm(grid, original, target, node._weave_session_context(), Time.get_ticks_msec())
	check(node.world.player(2) == null and node._local_player_state() == host, "fixture exposes the camera's missing-client host fallback")
	node._reconcile_character_attunement()
	equal(grid.model.pending_wire, wire, "matching host identity cannot confirm an absent client's request")
	equal(grid.model.equipped_id, original, "missing exact client actor cannot replace the equipped badge")

	var local := PlayerState.new(2)
	check(champions.apply_to_player(local, original), "exact local client actor starts as the original champion")
	node.world.players.append(local)
	var before := local.canonical_values()
	node.station_notice = "Previous truthful notice"
	node._ingest_session_feedback([{"type": "champion_attuned", "entity_id": 2, "champion_wire_id": wire}])
	equal(grid.model.pending_wire, wire, "Bootstrap ignores target feedback before the exact local authority changes")
	equal(grid.model.equipped_id, original, "forged early feedback cannot equip the requested card")
	equal(node.station_notice, "Previous truthful notice", "unconfirmed local feedback cannot announce success")
	equal(local.canonical_values(), before, "feedback never mutates authoritative champion state")

	check(champions.apply_to_player(local, target), "published-target candidate uses an actual valid champion")
	node.last_client_world_epoch = 6
	node._reconcile_character_attunement()
	equal(grid.model.pending_wire, wire, "matching actor from an unpublished client epoch cannot confirm")
	equal(grid.model.equipped_id, original, "stale epoch leaves the last proven badge unchanged")
	grid.close_panel()
	node.last_client_world_epoch = 7
	node._reconcile_character_attunement()
	equal(grid.model.pending_wire, 0, "fresh exact local authority confirms even when the Gallery is closed")
	equal(grid.model.equipped_id, target, "published exact local actor owns the equipped identity")
	check(grid.model.status_message.begins_with("Attuned:"), "actual published request completion reports success")

	node.session_transport.mode = SessionTransport.Mode.CONNECTING
	node.session_transport.accepted = false
	wire = _arm(grid, original, target, node._weave_session_context(), Time.get_ticks_msec())
	node._reconcile_character_attunement()
	equal(grid.model.pending_wire, wire, "CONNECTING cannot confirm from a retained matching actor")
	equal(grid.model.equipped_id, original, "CONNECTING leaves the last proven identity intact")
	node.world = null
	node._reconcile_character_attunement()
	equal(grid.model.pending_wire, wire, "temporarily absent world cannot fabricate completion")
	check(not node.is_inside_tree() and node.session_transport.peer == null, "harness never starts a scene or network peer")
	node.free()
