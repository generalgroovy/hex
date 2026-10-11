extends FluxTestSuite

const VIEWPORT := Vector2(1280, 720)
const Teams = preload("res://src/presentation/team_match_presentation.gd")


func run() -> int:
	_test_explicit_selection_and_safe_close()
	_test_keyboard_and_controller()
	_test_mouse_delay_and_responsive_geometry()
	_test_availability_and_bad_content()
	_test_spatial_edges_and_feedback()
	_test_live_detail_lines()
	_test_disabled_team_policy()
	_test_live_team_hearth()
	return finish("wellspring-service-directory")


func _test_live_detail_lines() -> void:
	var stations := _stations()
	var before := CanonicalContent.sha256(stations)
	var directory := WellspringServiceDirectory.new()
	check(directory.open_group("farflow", stations, "farflow-charter"), "live detail fixture opens the real charter card")
	var static_lines: Array = directory.entries[directory.selected_index].get("lines", []).duplicate()
	equal(directory.selected_detail_lines(), static_lines, "omitted live detail preserves canonical help")
	var updates := {"farflow-charter": ["Current action", "Current rule"]}
	directory.set_station_lines(updates)
	updates["farflow-charter"][1] = "Caller changed after refresh"
	equal(directory.selected_detail_lines(), ["Current action", "Current rule"], "live detail is copied rather than aliased to caller data")
	var drawn_lines := directory.selected_detail_lines()
	drawn_lines[1] = "Presentation copy changed"
	equal(directory.selected_detail_lines(), ["Current action", "Current rule"], "reading drawable lines cannot mutate stored details")
	equal(directory.entries[directory.selected_index].get("lines", []), static_lines, "live details do not overwrite directory station definitions")
	equal(CanonicalContent.sha256(stations), before, "live updates leave canonical campus objects untouched")
	directory.set_station_lines({"farflow-charter": PackedStringArray(["New action", "New rule"])})
	equal(directory.selected_detail_lines(), ["New action", "New rule"], "the next refresh replaces stale detail and accepts packed text rows")
	directory.set_station_lines({})
	equal(directory.selected_detail_lines(), static_lines, "clearing the live map restores original help")
	directory.set_station_lines({"farflow-charter": ["0", "1", "2", "3", "4", "5", "6"]})
	equal(directory.selected_detail_lines(), ["0", "1", "2", "3", "4", "5"], "the shared draw model enforces the six-row budget")
	directory.close()
	check(directory.selected_detail_lines().is_empty(), "closed directory never exposes stale details")
	check(directory.open_group("farflow", stations, "farflow-charter"), "detail fixture can reopen")
	equal(directory.selected_detail_lines(), static_lines, "reopening does not reuse an old live map")


func _test_disabled_team_policy() -> void:
	var directory := WellspringServiceDirectory.new()
	var reason := "Close the session before changing rules."
	check(directory.open_group("farflow", _stations(), "farflow-charter", {"farflow-charter": {"enabled": false, "reason": reason}}), "sealed team charter remains inspectable")
	var policy := Teams.damage_policy_lines()
	var charter_lines: Array[String] = ["SEALED WHILE FARFLOW IS OPEN"]
	charter_lines.append_array(policy)
	directory.set_station_lines({"farflow-charter": charter_lines})
	var lines := directory.selected_detail_lines()
	equal(lines.size(), 6, "disabled charter uses exactly six visible detail rows")
	equal(lines[0], reason, "full details replace only the reserved action/status row with the disabled reason")
	for index: int in policy.size():
		equal(lines[index + 1], policy[index], "disabled charter retains every complete damage and scoring warning")
	equal(charter_lines[0], "SEALED WHILE FARFLOW IS OPEN", "disabled presentation cannot rewrite caller instructions")
	equal(directory.request_selected(), "", "readable disabled help never permits a charter action")
	check(directory.details_visible, "refused activation immediately reveals the full readable policy")
	for viewport: Vector2 in [Vector2(960, 540), VIEWPORT]:
		var detail: Rect2 = directory.layout_for(viewport).details
		check(17 + (lines.size() - 1) * 14 <= detail.size.y, "all six baselines fit the actual directory detail lane")
		for line: String in lines:
			check(ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x <= detail.size.x, "complete sealed rule fits actual font11 directory width")
	directory.set_station_lines({"farflow-charter": ["One useful rule", "Second useful rule"]})
	equal(directory.selected_detail_lines(), [reason, "One useful rule", "Second useful rule"], "shorter disabled help prepends the reason without dropping either rule")
	directory.set_station_lines({"farflow-charter": [reason, "One useful rule"]})
	equal(directory.selected_detail_lines(), [reason, "One useful rule"], "an existing first-row reason is not duplicated")
	directory.availability_by_station["farflow-charter"] = {"enabled": true}
	equal(directory.request_selected(), "farflow-charter", "presentation updates preserve the existing enabled dispatch path")


func _test_live_team_hearth() -> void:
	var directory := WellspringServiceDirectory.new()
	check(directory.open_group("farflow", _stations(), "session-hearth"), "team Hearth details use the actual selected service card")
	var readiness := {1: true, 2: false, 3: true, 4: true, 5: true, 6: true}
	var lines: Array = Array(Teams.hearth_label("trios", [1, 2, 3, 4, 5, 6], 6, 120, 0, readiness).split("\n"))
	lines.append("INTERACT TOGGLES READY")
	directory.set_station_lines({"session-hearth": lines})
	equal(directory.selected_detail_lines(), lines, "the renderer sees the complete six-row live Hearth model")
	check(directory.selected_detail_lines()[2].contains("P2-"), "actual waiting identity survives the directory seam")
	readiness[2] = true
	lines = Array(Teams.hearth_label("trios", [1, 2, 3, 4, 5, 6], 6, 120, 481, readiness).split("\n"))
	lines.append("TEAMS LOCK AT START")
	directory.set_station_lines({"session-hearth": lines})
	equal(directory.selected_detail_lines()[0], "3v3 PREVIEW | IN 4.1s", "refresh exposes the real pending countdown")
	check(directory.selected_detail_lines()[2].contains("P2+"), "readiness refresh removes obsolete waiting marker")
	equal(directory.selected_detail_lines()[5], "TEAMS LOCK AT START", "countdown contract remains visible in the last rendered row")
	equal(directory.handle_event(_key(KEY_TAB), Vector2.ZERO, VIEWPORT), "", "live details cannot turn navigation into an action")
	equal(directory.selected_station_id(), "company-ledger", "existing selection order is unchanged")
	equal(directory.selected_detail_lines(), directory.entries[directory.selected_index].get("lines", []), "unoverridden next service retains its own static help")


func _test_spatial_edges_and_feedback() -> void:
	var directory := WellspringServiceDirectory.new()
	check(directory.open_group("farflow", _stations()), "spatial fixture opens")
	directory.selected_index = 2
	directory.handle_event(_key(KEY_RIGHT), Vector2.ZERO, VIEWPORT)
	equal(directory.selected_index, 2, "right edge does not jump down to another row")
	directory.handle_event(_key(KEY_DOWN), Vector2.ZERO, VIEWPORT)
	equal(directory.selected_index, 5, "vertical movement keeps the same column")
	directory.handle_event(_key(KEY_TAB), Vector2.ZERO, VIEWPORT)
	equal(directory.selected_index, 0, "linear Tab intentionally wraps all services")
	directory.availability_by_station[directory.selected_station_id()] = {"enabled": false, "reason": "Join a session first."}
	directory.details_visible = false
	equal(directory.request_selected(), "", "disabled service sends no action")
	equal(directory.status_text, "Join a session first.", "disabled activation gives immediate actionable feedback")
	check(directory.details_visible, "disabled click does not wait for hover to explain refusal")
	var pointer: Vector2 = (directory.layout_for(VIEWPORT).cards[0] as Rect2).get_center()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	directory.handle_event(click, pointer, VIEWPORT)
	directory.update(0.001, pointer, VIEWPORT)
	directory.status_text = "Live session status"
	check(directory.details_visible, "disabled mouse activation survives the next frame without restarting the hover timer")
	equal(directory.selected_disabled_reason(), "Join a session first.", "root session subtitle cannot erase the selected action's refusal")
	directory.handle_event(_key(KEY_RIGHT), Vector2.ZERO, VIEWPORT)
	equal(directory.status_text, "", "new selection clears stale refusal")


func _stations() -> Array:
	var layout := SanctumCampusLayout.new()
	check(layout.load_from_file("res://content/maps/sanctum_campus_g2_v1.json"), "directory uses canonical live stations")
	return layout.data["stations"]


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func _button(code: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	return event


func _test_explicit_selection_and_safe_close() -> void:
	var stations := _stations()
	var before := CanonicalContent.sha256(stations)
	var directory := WellspringServiceDirectory.new()
	check(directory.open_group("farflow", stations), "real building directory opens")
	equal(directory.entries.size(), 6, "six distinct Farflow actions stay available")
	equal(directory.selected_station_id(), "farflow-host", "deterministic order begins with Host")
	equal(CanonicalContent.sha256(stations), before, "opening changes no canonical station, authority, radius or state")
	directory.entries[0]["title"] = "Local view only"
	equal(CanonicalContent.sha256(stations), before, "directory edits cannot mutate caller's canonical station objects")
	check(directory.open_group("farflow", stations, "parting-bell"), "caller can preserve deliberately selected child")
	equal(directory.selected_station_id(), "parting-bell", "selected Parting remains distinct from Company")
	equal(directory.handle_event(_key(KEY_ESCAPE), Vector2.ZERO, VIEWPORT), "", "back never emits an action")
	check(not directory.is_open and directory.entries.is_empty(), "back releases modal contents and focus")
	equal(directory.request_selected(), "", "closed directory cannot request a stale command")


func _test_keyboard_and_controller() -> void:
	var directory := WellspringServiceDirectory.new()
	check(directory.open_group("farflow", _stations()), "keyboard fixture opens")
	equal(directory.handle_event(_key(KEY_RIGHT), Vector2.ZERO, VIEWPORT), "", "navigation alone has no external action")
	equal(directory.selected_station_id(), "farflow-join", "right selects Join after Host")
	equal(directory.handle_event(_key(KEY_ENTER), Vector2.ZERO, VIEWPORT), "farflow-join", "Enter explicitly requests only selected existing action")
	var had_interact := InputMap.has_action(InputRouter.INTERACT_ACTION)
	if not had_interact:
		InputMap.add_action(InputRouter.INTERACT_ACTION)
	var bound_interact := InputEventAction.new()
	bound_interact.action = InputRouter.INTERACT_ACTION
	bound_interact.pressed = true
	equal(directory.handle_event(bound_interact, Vector2.ZERO, VIEWPORT), "farflow-join", "current Interact action activates highlighted child without hard-coded F")
	if not had_interact:
		InputMap.erase_action(InputRouter.INTERACT_ACTION)
	directory.handle_event(_key(KEY_DOWN), Vector2.ZERO, VIEWPORT)
	equal(directory.selected_station_id(), "company-ledger", "down respects the three-column service grid")
	check(directory.details_visible, "deliberate keyboard focus immediately exposes details")
	equal(directory.handle_event(_button(JOY_BUTTON_DPAD_RIGHT), Vector2.ZERO, VIEWPORT), "", "controller navigation cannot dismiss a traveller")
	equal(directory.selected_station_id(), "parting-bell", "controller can reach separate Parting card")
	equal(directory.handle_event(_button(JOY_BUTTON_A), Vector2.ZERO, VIEWPORT), "parting-bell", "controller accept still returns only a request for existing confirmation path")
	directory.handle_event(_button(JOY_BUTTON_B), Vector2.ZERO, VIEWPORT)
	check(not directory.is_open, "controller Back closes directory")
	check(directory.open_group("farflow", _stations()), "stick fixture opens")
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 0.9
	directory.handle_event(stick, Vector2.ZERO, VIEWPORT)
	equal(directory.selected_index, 1, "stick deliberate threshold moves one card")
	directory.handle_event(stick, Vector2.ZERO, VIEWPORT)
	equal(directory.selected_index, 1, "held stick cannot repeat uncontrollably")
	stick.axis_value = 0.0
	directory.handle_event(stick, Vector2.ZERO, VIEWPORT)
	stick.axis_value = 0.9
	directory.handle_event(stick, Vector2.ZERO, VIEWPORT)
	equal(directory.selected_index, 2, "stick release re-arms a fresh deliberate navigation")


func _test_mouse_delay_and_responsive_geometry() -> void:
	var directory := WellspringServiceDirectory.new()
	check(directory.open_group("farflow", _stations()), "pointer fixture opens")
	for viewport: Vector2 in [Vector2(640, 480), VIEWPORT, Vector2(1920, 1080)]:
		var geometry := directory.layout_for(viewport)
		var panel: Rect2 = geometry["panel"]
		check(Rect2(Vector2.ZERO, viewport).encloses(panel), "directory stays inside supported viewport")
		var cards: Array[Rect2] = geometry["cards"]
		equal(cards.size(), 6, "all six session actions remain visible together")
		for index: int in range(cards.size()):
			check(panel.encloses(cards[index]), "card remains within panel")
			for other: int in range(index):
				check(not cards[index].intersects(cards[other]), "responsive cards never overlap")
	var card: Rect2 = directory.layout_for(VIEWPORT)["cards"][1]
	var motion := InputEventMouseMotion.new()
	motion.position = card.get_center()
	directory.handle_event(motion, motion.position, VIEWPORT)
	check(not directory.details_visible, "pointer entry does not flash detail immediately")
	directory.update(0.20, motion.position, VIEWPORT)
	check(not directory.details_visible, "moving between cards has a short read delay")
	directory.update(0.09, motion.position, VIEWPORT)
	check(directory.details_visible, "stable hover reveals details at280ms")
	equal(directory.selected_station_id(), "farflow-join", "pointer hit uses exact rendered card geometry")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	equal(directory.handle_event(click, motion.position, VIEWPORT), "farflow-join", "click explicitly requests selected service")
	equal(directory.handle_event(click, Vector2.ZERO, VIEWPORT), "", "outside click never emits action")


func _test_availability_and_bad_content() -> void:
	var stations := _stations()
	var directory := WellspringServiceDirectory.new()
	check(directory.open_group("farflow", stations, "parting-bell", {"parting-bell": {"enabled": false, "reason": "Only the host can dismiss travellers."}}), "availability metadata opens disabled card without changing host policy")
	equal(directory.request_selected(), "", "disabled entry cannot emit a command")
	check(not directory.open_group("unknown", stations), "unknown building group fails closed")
	check(not directory.is_open, "failed open cannot leave stale modal active")
	var duplicate := stations.duplicate(true)
	for entry: Dictionary in stations:
		if String(entry["command"]) == "host_session":
			duplicate.append(entry.duplicate(true))
			break
	check(not directory.open_group("farflow", duplicate), "duplicate action records fail closed")
