extends FluxTestSuite


const BootstrapScript: Script = preload("res://src/app/bootstrap.gd")


# Inherited input/submission/authority paths, with no startup, simulation loop,
# socket, drawing, or persistent profile. Holding a request models delayed
# authority without replacing the actual pending-request admission logic.
class HandoffHarness:
	extends "res://src/app/bootstrap.gd"
	var hold_requests: bool = false
	var submitted: Array[Dictionary] = []
	var save_calls: int = 0
	var saved_wires := PackedInt32Array()
	var fixture_store: String = ""

	func _ready() -> void:
		pass

	func _process(_delta: float) -> void:
		pass

	func _draw() -> void:
		pass

	func _handle_session_requests(requests: Array[Dictionary]) -> void:
		for request: Dictionary in requests:
			submitted.append(request.duplicate(true))
		if not hold_requests:
			super._handle_session_requests(requests)

	func _save_confirmed_weave(state: PlayerState, mode: String) -> void:
		save_calls += 1
		saved_wires = state.spell_wire_ids.duplicate()
		super._save_confirmed_weave(state, mode)


var _abilities := AbilityCatalog.new()
var _champions := ChampionCatalog.new()
var _campus := SanctumCampusLayout.new()


func run() -> int:
	check(_abilities.load_from_file(BootstrapScript.ABILITY_CATALOG_PATH), "handoff loads the actual ability catalog")
	check(_champions.load_from_file(BootstrapScript.CHAMPION_CATALOG_PATH, _abilities), "handoff loads the actual character catalog")
	check(_campus.load_from_file(BootstrapScript.CAMPUS_LAYOUT_PATH), "handoff uses actual station admission geometry")
	for controller: bool in [false, true]:
		for active_drag: bool in [false, true]:
			_test_unchanged(controller, active_drag)
			_test_local_refusal(controller, active_drag)
			_test_delayed_outcome(controller, active_drag, false)
			_test_delayed_outcome(controller, active_drag, true)
	_test_ordinary_pointer_drop()
	_test_fitted_pointer_paths()
	_test_failed_save_feedback()
	_test_starter_failure_feedback()
	for controller: bool in [false, true]:
		_test_starter_cancel_after_timeout(controller)
	return finish("spell-loom-input-handoff")


func _test_failed_save_feedback() -> void:
	var node := _fixture()
	var actor := node.world.player()
	var before := node.character_weaves.library.to_dictionary()
	# Reject only local persistence, after normal authority has applied the swap.
	node.character_weaves.configured = false
	_arm_drag(node, actor.spell_wire_ids[1], false)
	var requested := node.spell_loom_editor.requested_wire_ids(actor)
	_confirm(node, false)
	equal(actor.spell_wire_ids, requested, "failed local save does not roll back accepted authority")
	equal(node.save_calls, 1, "accepted assignment attempts exactly one local save")
	equal(node.character_weaves.library.to_dictionary(), before, "rejected local save preserves the prior library")
	var availability: Dictionary = node._loom_assignment_availability(actor, node.spell_loom_editor.requested_wire_ids(actor))
	check(not bool(availability.enabled), "accepted selection becomes an unavailable no-op")
	var lines := SpellLoomPresenter.feedback_lines(node.spell_loom_editor, availability)
	check(lines.size() == 2 and String(lines[0].text).contains("saved file could not be updated"), "actual save-failure warning survives the renderer's disabled assignment state")
	_dispose(node)


func _test_starter_failure_feedback() -> void:
	for timeout: bool in [false, true]:
		var node := _fixture()
		node.hold_requests = true
		var actor := node.world.player()
		var before := actor.canonical_values()
		check(node.spell_loom_editor.prepare_starter_preview(actor, _champions, _abilities), "starter failure fixture opens actual comparison")
		_confirm(node, false)
		check(not node.pending_weave_request.is_empty(), "starter request reaches real pending admission")
		check(String(node.spell_loom_editor.starter_preview.notice).contains("Waiting for authority"), "pending starter identifies the request as in flight")
		if timeout:
			node.pending_weave_request.deadline_ms = 0
			node._complete_pending_weave()
		else:
			node._ingest_session_feedback([{"type": "request_refused", "entity_id": actor.entity_id, "action": SessionTransport.REQUEST_WEAVE_APPLY, "sequence": node.client_request_sequence, "reason": SessionRequestPolicy.REFUSED_UNAVAILABLE}])
		var lines := SpellLoomPresenter.feedback_lines(node.spell_loom_editor, node._loom_assignment_availability(actor, node._loom_presented_request(actor), true), true)
		check(not lines.is_empty() and String(lines[0].text).contains("timed out" if timeout else "previous weave remains usable"), "actual starter failure reaches the visible outcome projection")
		check(not String(node.spell_loom_editor.starter_preview.notice).contains("Waiting for authority"), "actual starter failure clears stale in-flight notice")
		check(node.pending_weave_request.is_empty() and node.spell_loom_editor.starter_preview_active(), "failed request unlocks review without discarding comparison")
		equal(actor.canonical_values(), before, "starter failure feedback does not alter authoritative state")
		equal(node.save_calls, 0, "starter failure feedback invokes no save")
		_dispose(node)


func _test_starter_cancel_after_timeout(controller: bool) -> void:
	var node := _fixture()
	node.hold_requests = true
	var actor := node.world.player()
	var custom := actor.spell_wire_ids.duplicate()
	var first_wire := custom[0]
	custom[0] = custom[1]
	custom[1] = first_wire
	check(CharacterWeavePolicy.apply(actor, custom), "timeout cancellation begins with a custom weave")
	check(node.spell_loom_editor.prepare_starter_preview(actor, _champions, _abilities), "timeout cancellation opens a real starter comparison")
	_confirm(node, controller)
	check(not node.pending_weave_request.is_empty(), "starter request is genuinely pending before timeout")
	if node.pending_weave_request.is_empty():
		_dispose(node)
		return
	var requested: PackedInt32Array = node.pending_weave_request.wires.duplicate()
	var sequence := node.client_request_sequence
	var sent := node.submitted.size()
	var saves := node.save_calls
	var saved_before := node.character_weaves.library.to_dictionary()
	# The preview Cancel button still cannot revoke an in-flight request.
	_mouse_button(node, SpellLoomEditor.STARTER_PREVIEW_CANCEL_RECT.get_center(), true)
	check(not node.pending_weave_request.is_empty() and node.spell_loom_editor.starter_preview_active(), "pending request continues to quarantine preview cancellation")
	equal(node.submitted.size(), sent, "pending Cancel sends no extra request")
	node.pending_weave_request.deadline_ms = 0
	node._complete_pending_weave()
	check(node.pending_weave_request.is_empty() and node.spell_loom_editor.status_message.contains("timed out"), "timeout truthfully releases only local request tracking")
	# Arrange a late authoritative result through the actual pure weave policy.
	# This is not a socket test: it proves closing cannot assert or restore the
	# old weave even when authority changed after local confirmation expired.
	check(requested != actor.spell_wire_ids and CharacterWeavePolicy.apply(actor, requested), "late authoritative starter result differs from the old custom weave")
	var late_feedback: Array[Dictionary] = [{"type": "station_confirmed", "entity_id": actor.entity_id, "action": SessionTransport.REQUEST_WEAVE_APPLY, "sequence": sequence, "champion_wire_id": actor.champion_wire_id}]
	node._ingest_session_feedback(late_feedback)
	var authoritative := actor.canonical_values()
	if controller:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_B
		event.pressed = true
		node._handle_spell_loom_input(event)
	else:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.pressed = true
		node._handle_spell_loom_input(event)
	check(not node.spell_loom_editor.starter_preview_active() and node.spell_loom_editor.is_open, "post-timeout Cancel closes only the comparison")
	equal(node.spell_loom_editor.status_message, "Starter preview closed. No new request was sent.", "post-timeout Cancel does not claim an unchanged weave or cancel remote authority")
	equal(actor.canonical_values(), authoritative, "closing after timeout cannot roll back late authority")
	equal(node.submitted.size(), sent, "closing after timeout sends no new request")
	equal(node.client_request_sequence, sequence, "closing after timeout consumes no request sequence")
	equal(node.save_calls, saves, "late acknowledgement and closing after timeout invoke no unconfirmed save")
	equal(node.character_weaves.library.to_dictionary(), saved_before, "closing after timeout preserves the saved weave")
	check(node.pending_weave_request.is_empty(), "closing after timeout cannot resurrect expired request tracking")
	_dispose(node)


func _fixture(viewport_size: Vector2i = Vector2i.ZERO) -> HandoffHarness:
	var node := HandoffHarness.new()
	node.ability_catalog = _abilities
	node.champion_catalog = _champions
	node.campus_layout = _campus
	node.world = SimWorld.new(120, 91, CollisionWorld.new(3_072_000, 1_728_000))
	check(_champions.apply_to_player(node.world.player(), _champions.default_champion_id), "handoff fixture owns a valid twelve-spell character")
	node.session_transport = SessionTransport.new()
	node.session_transport.local_entity_id = SessionTransport.SERVER_PEER_ID
	node.authoritative_session = AuthoritativeSession.new()
	node.authoritative_session.world = node.world
	node.spell_loom_editor = SpellLoomEditor.new()
	node.preferences_persistence_allowed = false
	node.preference_overrides_are_transient = true
	node.fixture_store = "user://loom-handoff-%d-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec(), node.get_instance_id()]
	check(not FileAccess.file_exists(node.fixture_store), "isolated handoff library never reads an existing player profile")
	check(node.character_weaves.configure(_champions, _abilities, false, node.fixture_store), "handoff initializes an in-memory weave library")
	check(not node.character_weaves.persistence_allowed, "handoff fixture cannot persist a weave")
	_place_at_loom(node)
	node.spell_loom_editor.open_editor(node.world.player(), _abilities)
	if viewport_size != Vector2i.ZERO:
		var viewport := SubViewport.new()
		viewport.size = viewport_size
		(Engine.get_main_loop() as SceneTree).root.add_child(viewport)
		viewport.add_child(node)
	else:
		(Engine.get_main_loop() as SceneTree).root.add_child(node)
	return node


func _dispose(node: HandoffHarness) -> void:
	check(node.session_transport.peer == null, "input handoff never opens a network peer")
	check(not FileAccess.file_exists(node.fixture_store), "input handoff leaves no saved profile file")
	var viewport := node.get_parent() as SubViewport
	node.free()
	if viewport != null: viewport.free()


func _place_at_loom(node: HandoffHarness) -> void:
	var position: Array = _campus.stations_by_id["spell-loom"].position
	node.world.player().position_x = int(position[0]) * 1000
	node.world.player().position_y = (int(position[1]) + 48) * 1000


func _arm_drag(node: HandoffHarness, wire_id: int, active_drag: bool) -> void:
	var editor: SpellLoomEditor = node.spell_loom_editor
	var index := editor.available_wire_ids.find(wire_id)
	check(index >= 0, "handoff drag source has an actual catalog identity")
	if index < 0:
		return
	# A fresh Loom starts with the equipped mixture. Use its actual filters to
	# expose the intended drag source; hidden cards have no pointer rectangle.
	check(editor.set_element_mask(MixtureCatalog.mask_for_wire(wire_id)), "handoff reveals the source mixture through the real filter")
	check(editor.set_family_filter(MixtureCatalog.family_for_wire(wire_id)), "handoff reveals the source delivery through the real filter")
	check(index in editor.visible_spell_indices(), "handoff drag source is an actual visible library card")
	equal(editor.selected_wire_id(), wire_id, "exact mixture and delivery reveal the intended stable wire")
	editor.selected_slot_index = 0
	var origin := editor.spell_rect(index).get_center()
	_mouse_button(node, origin, true)
	_mouse_motion(node, SpellLoomEditor.slot_rect(4).get_center() if active_drag else origin + Vector2(3, 2))
	equal(editor.drag_spell_index, index, "pointer press retains the actual spell identity")
	equal(editor.dragging, active_drag, "fixture distinguishes an active drag from an armed below-threshold press")
	equal(editor.selected_slot_index, 0, "moving the pointer alone does not confirm its drop destination")


func _confirm(node: HandoffHarness, controller: bool) -> void:
	if controller:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_A
		event.pressed = true
		node._handle_spell_loom_input(event)
	else:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = true
		node._handle_spell_loom_input(event)


func _mouse_button(node: HandoffHarness, point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = point * node._loom_scale()
	node._handle_spell_loom_input(event)


func _mouse_motion(node: HandoffHarness, point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point * node._loom_scale()
	node._handle_spell_loom_input(event)


func _check_disarmed(node: HandoffHarness, message: String) -> void:
	check(not node.spell_loom_editor.dragging, message + ": no drag preview remains")
	equal(node.spell_loom_editor.drag_spell_index, -1, message + ": no below-threshold drop remains armed")
	equal(node.controls_input_guard_frames, 2, message + ": modal input remains quarantined from gameplay")


func _test_unchanged(controller: bool, active_drag: bool) -> void:
	var node := _fixture()
	var actor := node.world.player()
	var before := actor.canonical_values()
	var saved_before := node.character_weaves.library.to_dictionary()
	_arm_drag(node, actor.spell_wire_ids[0], active_drag)
	_confirm(node, controller)
	_check_disarmed(node, "unchanged explicit confirmation")
	check(node.spell_loom_editor.status_message.contains("Already in this slot"), "unchanged confirmation reports no assignment")
	_mouse_button(node, SpellLoomEditor.slot_rect(5).get_center(), false)
	_mouse_motion(node, SpellLoomEditor.slot_rect(6).get_center())
	_check_disarmed(node, "release after unchanged confirmation")
	equal(node.spell_loom_editor.selected_slot_index, 0, "stale release cannot choose a second destination after unchanged confirmation")
	equal(node.submitted.size(), 0, "unchanged confirmation plus stale release emits no request")
	equal(node.client_request_sequence, 0, "unchanged confirmation consumes no request sequence")
	equal(actor.canonical_values(), before, "unchanged handoff changes no actor state, resource, cooldown, or spell")
	equal(node.save_calls, 0, "unchanged handoff invokes no local save")
	equal(node.character_weaves.library.to_dictionary(), saved_before, "unchanged handoff preserves the saved weave")
	_assert_fresh_drop(node)
	_dispose(node)


func _test_local_refusal(controller: bool, active_drag: bool) -> void:
	var node := _fixture()
	var actor := node.world.player()
	actor.position_x = 400_000
	actor.position_y = 400_000
	var before := actor.canonical_values()
	var saved_before := node.character_weaves.library.to_dictionary()
	_arm_drag(node, actor.spell_wire_ids[1], active_drag)
	check(not bool(node._loom_assignment_availability(actor, node.spell_loom_editor.requested_wire_ids(actor)).get("enabled", true)), "distant fixture genuinely refuses the selected swap")
	_confirm(node, controller)
	_check_disarmed(node, "locally refused explicit confirmation")
	_mouse_button(node, SpellLoomEditor.slot_rect(5).get_center(), false)
	_mouse_motion(node, SpellLoomEditor.slot_rect(6).get_center())
	_check_disarmed(node, "release after local refusal")
	equal(node.spell_loom_editor.selected_slot_index, 0, "refused handoff does not reinterpret release as another target")
	equal(node.submitted.size(), 0, "local refusal and its stale release emit no authority request")
	equal(node.client_request_sequence, 0, "local refusal consumes no request sequence")
	check(node.pending_weave_request.is_empty(), "local refusal invents no pending transaction")
	equal(actor.canonical_values(), before, "locally refused handoff changes no authoritative actor field")
	equal(node.save_calls, 0, "local refusal invokes no save")
	equal(node.character_weaves.library.to_dictionary(), saved_before, "local refusal preserves the saved weave")
	_place_at_loom(node)
	_assert_fresh_drop(node)
	_dispose(node)


func _test_delayed_outcome(controller: bool, active_drag: bool, timeout: bool) -> void:
	var node := _fixture()
	node.hold_requests = true
	var actor := node.world.player()
	var before := actor.canonical_values()
	var saved_before := node.character_weaves.library.to_dictionary()
	_arm_drag(node, actor.spell_wire_ids[1], active_drag)
	var expected := node.spell_loom_editor.requested_wire_ids(actor)
	check(bool(node._loom_assignment_availability(actor, expected).get("enabled", false)), "delayed fixture admits the real selected swap")
	_confirm(node, controller)
	_check_disarmed(node, "pending explicit confirmation")
	equal(node.submitted.size(), 1, "explicit confirmation emits exactly one intended request")
	equal(node.client_request_sequence, 1, "one intended pending request consumes one sequence")
	check(not node.pending_weave_request.is_empty(), "held authority request remains pending")
	if node.pending_weave_request.is_empty() or node.submitted.is_empty():
		_dispose(node)
		return
	equal(PackedInt32Array(node.submitted[0].wires), expected, "explicit confirmation keeps the selected target, not the hovered drop target")
	_mouse_button(node, SpellLoomEditor.slot_rect(5).get_center(), false)
	_confirm(node, controller)
	equal(node.submitted.size(), 1, "pending mouse release and repeat confirmation cannot submit another request")
	if timeout:
		node.pending_weave_request.deadline_ms = 0
		node._complete_pending_weave()
		check(node.spell_loom_editor.status_message.contains("timed out"), "timeout remains truthful instead of inventing a success")
	else:
		node._ingest_session_feedback([{
			"type": "request_refused", "entity_id": actor.entity_id,
			"action": SessionTransport.REQUEST_WEAVE_APPLY, "sequence": 1,
			"reason": SessionRequestPolicy.REFUSED_UNAVAILABLE,
		}])
		check(node.spell_loom_editor.status_message.contains("previous weave remains usable"), "matching refusal retains truthful unchanged-weave feedback")
	check(node.pending_weave_request.is_empty(), "matching refusal or timeout unlocks the editor")
	_mouse_motion(node, SpellLoomEditor.slot_rect(6).get_center())
	_check_disarmed(node, "pointer movement after pending refusal or timeout")
	equal(node.spell_loom_editor.selected_slot_index, 0, "consumed pending release does not leave a hidden second destination")
	equal(node.submitted.size(), 1, "pointer movement after recovery cannot resurrect the completed gesture")
	equal(actor.canonical_values(), before, "pending refusal or timeout changes no authoritative actor field")
	equal(node.save_calls, 0, "pending refusal or timeout invokes no save")
	equal(node.character_weaves.library.to_dictionary(), saved_before, "pending refusal or timeout preserves the saved weave")
	node.hold_requests = false
	_assert_fresh_drop(node)
	_dispose(node)


func _test_ordinary_pointer_drop() -> void:
	var node := _fixture()
	_assert_fresh_drop(node)
	_dispose(node)


func _assert_fresh_drop(node: HandoffHarness) -> void:
	var actor := node.world.player()
	var before := actor.canonical_values()
	var expected := actor.spell_wire_ids.duplicate()
	var swap := expected[0]
	expected[0] = expected[1]
	expected[1] = swap
	var requests_before := node.submitted.size()
	var sequence_before := node.client_request_sequence
	var saves_before := node.save_calls
	var tick_before := node.world.tick
	var resources_before := [actor.health, actor.flux, actor.position_x, actor.position_y, actor.velocity_x, actor.velocity_y, actor.air_height, actor.pending_cast_ticks, actor.cast_recovery_ticks]
	_arm_drag(node, actor.spell_wire_ids[1], true)
	equal(actor.canonical_values(), before, "fresh press and drag remain presentation-only until release")
	_mouse_button(node, SpellLoomEditor.slot_rect(0).get_center(), false)
	_check_disarmed(node, "normal successful pointer drop")
	equal(node.submitted.size(), requests_before + 1, "a fresh pointer gesture submits exactly once")
	equal(node.client_request_sequence, sequence_before + 1, "normal drop consumes exactly one new request sequence")
	equal(actor.spell_wire_ids, expected, "normal drop reaches actual offline authority and swaps the intended two slots")
	check(actor.has_valid_spell_slots(), "normal drop preserves the exact twelve-slot invariant")
	check(node.pending_weave_request.is_empty(), "actual matching offline acknowledgement completes normal drop")
	equal(node.save_calls, saves_before + 1, "only the accepted drop saves its confirmed weave once")
	equal(node.saved_wires, expected, "confirmed save receives exactly the accepted weave")
	var champion_id := _champions.champion_id_from_wire(actor.champion_wire_id)
	equal(node.character_weaves.library.saved_weave(champion_id).wire_ids, expected, "normal accepted drop updates only the isolated in-memory weave")
	equal([actor.health, actor.flux, actor.position_x, actor.position_y, actor.velocity_x, actor.velocity_y, actor.air_height, actor.pending_cast_ticks, actor.cast_recovery_ticks], resources_before, "normal drop does not pay, move, launch, cast, or alter health")
	equal(node.world.tick, tick_before, "menu handoff never advances the simulation")
	var accepted := actor.canonical_values()
	_mouse_button(node, SpellLoomEditor.slot_rect(5).get_center(), false)
	equal(node.submitted.size(), requests_before + 1, "duplicate release after a successful drop cannot submit twice")
	equal(actor.canonical_values(), accepted, "duplicate release preserves the accepted authority")



func _test_fitted_pointer_paths() -> void:
	for viewport_size: Vector2i in [Vector2i(960,540), Vector2i(960,720), Vector2i(1280,720), Vector2i(1920,1080), Vector2i(2560,1080)]:
		var node := _fixture(viewport_size)
		var expected_scale := minf(float(viewport_size.x) / 1280.0, float(viewport_size.y) / 720.0)
		equal(node._loom_scale(), expected_scale, "actual viewport drives the fitted Loom grid at %s" % viewport_size)
		var scale_factor := node._loom_scale()
		var frame := Rect2(Vector2.ZERO, Vector2(viewport_size))
		for rect: Rect2 in [SpellLoomEditor.PANEL_RECT, SpellLoomEditor.CLOSE_RECT, SpellLoomEditor.ASSIGN_RECT, SpellLoomEditor.STARTER_BUTTON_RECT, SpellLoomEditor.STARTER_PREVIEW_RECT, SpellLoomEditor.STARTER_PREVIEW_APPLY_RECT, SpellLoomEditor.STARTER_PREVIEW_CANCEL_RECT]:
			check(frame.encloses(Rect2(rect.position * scale_factor, rect.size * scale_factor)), "modal and action targets fit the actual viewport")
		var actor := node.world.player()
		var before := actor.canonical_values()
		for index: int in SpellLoomEditor.ELEMENT_FILTERS.size():
			_mouse_button(node, SpellLoomEditor.element_filter_rect(0).get_center(), true)
			_mouse_button(node, SpellLoomEditor.element_filter_rect(0).get_center(), false)
			_mouse_button(node, SpellLoomEditor.element_filter_rect(index).get_center(), true)
			equal(node.spell_loom_editor.selected_element_filter, SpellLoomEditor.ELEMENT_FILTERS[index], "scaled filter pointer selects the visible canonical target")
			_mouse_button(node, SpellLoomEditor.element_filter_rect(index).get_center(), false)
		_mouse_button(node, SpellLoomEditor.element_filter_rect(0).get_center(), true)
		_mouse_button(node, SpellLoomEditor.element_filter_rect(0).get_center(), false)
		_mouse_button(node, SpellLoomEditor.element_filter_rect(1).get_center(), true)
		_mouse_button(node, SpellLoomEditor.element_filter_rect(1).get_center(), false)
		_mouse_button(node, SpellLoomEditor.element_filter_rect(2).get_center(), true)
		_mouse_button(node, SpellLoomEditor.element_filter_rect(2).get_center(), false)
		equal(node.spell_loom_editor.selected_element_mask, 6, "scaled ingredient buttons combine Water and Fire instead of replacing the first choice")
		_mouse_button(node, SpellLoomEditor.element_filter_rect(0).get_center(), true)
		_mouse_button(node, SpellLoomEditor.element_filter_rect(0).get_center(), false)
		if node.spell_loom_editor.basic_forms_only:
			_mouse_button(node, SpellLoomEditor.MORE_FORMS_RECT.get_center(), true)
			_mouse_button(node, SpellLoomEditor.MORE_FORMS_RECT.get_center(), false)
		_mouse_button(node, SpellLoomEditor.family_filter_rect(0).get_center(), true)
		_mouse_button(node, SpellLoomEditor.family_filter_rect(0).get_center(), false)
		equal(node.spell_loom_editor.filtered_spell_indices().size(), 504, "actual All and More Forms controls expose the complete live library")
		while node.spell_loom_editor.page_index > 0:
			_mouse_button(node, SpellLoomEditor.PAGE_PREVIOUS_RECT.get_center(), true)
			_mouse_button(node, SpellLoomEditor.PAGE_PREVIOUS_RECT.get_center(), false)
		var seen := {}
		var pages := node.spell_loom_editor.page_count()
		equal(pages, 32, "sixteen readable cards expose all504 choices through32 pages")
		for page: int in pages:
			equal(node.spell_loom_editor.page_index, page, "scaled page control reaches the intended page")
			var visible := node.spell_loom_editor.visible_spell_indices()
			equal(visible.size(), mini(16, 504 - page * 16), "each actual page has exactly its remaining bounded cards")
			for index: int in visible:
				var rect := node.spell_loom_editor.spell_rect(index)
				check(rect.has_area() and frame.encloses(Rect2(rect.position * scale_factor, rect.size * scale_factor)), "every revealed spell card fits the actual viewport")
				_mouse_button(node, rect.get_center(), true)
				_mouse_button(node, rect.get_center(), false)
				equal(node.spell_loom_editor.selected_spell_index, index, "scaled library pointer chooses its exact visible card")
				var wire := int(node.spell_loom_editor.available_wire_ids[index])
				equal(node.spell_loom_editor.selected_wire_id(), wire, "scaled selection retains the stable spell identity across pages")
				check(not seen.has(wire), "page traversal never substitutes a repeated visible card for a hidden one")
				seen[wire] = true
			if page + 1 < pages:
				_mouse_button(node, SpellLoomEditor.PAGE_NEXT_RECT.get_center(), true)
				_mouse_button(node, SpellLoomEditor.PAGE_NEXT_RECT.get_center(), false)
		equal(seen.size(), 504, "all504 actual cards were individually selected at this viewport")
		for slot: int in PlayerState.SPELL_SLOT_COUNT:
			var rect := SpellLoomEditor.slot_rect(slot)
			check(frame.encloses(Rect2(rect.position * scale_factor, rect.size * scale_factor)), "every equipped slot fits")
		equal(actor.canonical_values(), before, "reading all scaled filters and cards preserves authority")
		equal(node.save_calls, 0, "scaled selection alone never saves")
		_assert_fresh_drop(node)
		_mouse_button(node, SpellLoomEditor.STARTER_BUTTON_RECT.get_center(), true)
		check(node.spell_loom_editor.starter_preview_active(), "scaled starter button opens the real comparison")
		_mouse_button(node, SpellLoomEditor.STARTER_PREVIEW_CANCEL_RECT.get_center(), true)
		check(not node.spell_loom_editor.starter_preview_active(), "scaled preview cancel reaches its own target")
		node.hold_requests = true
		_arm_drag(node, actor.spell_wire_ids[1], true)
		_confirm(node, false)
		check(not node.pending_weave_request.is_empty(), "keyboard confirmation still reaches pending authority after scaled drag")
		_mouse_button(node, SpellLoomEditor.CLOSE_RECT.get_center(), true)
		check(not node.spell_loom_editor.is_open, "scaled pending close uses the same coordinate transform")
		check(not node.pending_weave_request.is_empty(), "closing scaled pending view does not revoke admitted request")
		_dispose(node)
