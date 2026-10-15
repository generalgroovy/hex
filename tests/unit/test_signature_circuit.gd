extends FluxTestSuite

const Circuit = preload("res://src/app/signature_circuit.gd")
const CircuitPanel = preload("res://src/presentation/signature_circuit_panel.gd")
const Trial = preload("res://src/app/solo_duel_trial.gd")
const Challenges = preload("res://src/content/signature_challenge_catalog.gd")
var definitions: Array[Dictionary] = []


func run() -> int:
	var abilities := AbilityCatalog.new()
	var champions := ChampionCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "circuit loads real spell definitions")
	check(champions.load_from_file("res://content/champions/foundation_champions_v1.json", abilities), "circuit loads real rival definitions")
	for id: String in Circuit.ROUTE:
		definitions.append(Challenges.definition(id, champions, abilities))
		check(not definitions.back().is_empty(), "each circuit leg is an existing signature rival")
	_test_admission_and_three_results()
	_test_retries_and_tainted_results()
	_test_detachment_exit_and_save()
	_test_panel_geometry_and_input()
	return finish("signature-circuit")


func _terminal(stage: int, phase: String = Trial.VICTORY, saved: bool = true) -> Dictionary:
	# Prepared terminal views test the coordinator, not new combat/reward proof.
	# SignatureChallengeSession remains the sole real earned-result producer.
	var row: Dictionary = definitions[stage].duplicate(true)
	return {"finished": true, "phase": phase, "challenge": row, "developer": false,
		"elapsed_ticks": 1200 + stage * 60, "health": 74250, "health_maximum": 100000, "paid_casts": 13, "interceptions": 2,
		"reward": {"ok": phase == Trial.VICTORY, "new": true, "saved": saved, "wire": int(row.signature_wire), "notice": "Saved" if saved else "Available this session; progress has not been saved."}}


func _test_admission_and_three_results() -> void:
	var circuit := Circuit.new()
	check(not circuit.observe_result(_terminal(0)), "a result cannot create a circuit")
	equal(circuit.current_id(), "", "idle has no active route")
	check(circuit.begin(), "explicit start prepares the first rival")
	equal(circuit.current_id(), "wa_bidi", "first rival teaches crossing Rapid gaps")
	check(not circuit.admit_current("s_wayne"), "wrong admitted world cannot skip a leg")
	check(not circuit.observe_result(_terminal(0)), "failed world admission leaves result ineligible")
	check(circuit.admit_current("wa_bidi"), "successful real-world admission activates the leg")
	check(not circuit.admit_current("wa_bidi"), "duplicate start does not reset active attempt")
	var total := 0
	for stage: int in 3:
		check(not circuit.observe_result(_terminal((stage + 1) % 3)), "another rival result cannot advance this leg")
		var live := _terminal(stage)
		live.finished = false
		check(not circuit.observe_result(live), "nonterminal view cannot grant progress")
		var receipt := _terminal(stage, Trial.VICTORY, stage != 1)
		check(circuit.observe_result(receipt, circuit.ticket()), "matching earned victory ends current leg")
		total += int(receipt.elapsed_ticks)
		equal(circuit.view().total_elapsed_ticks, total, "elapsed total uses each observed result once")
		var frozen := circuit.view()
		check(not circuit.observe_result(receipt), "repeated terminal callback cannot duplicate route credit")
		equal(circuit.view(), frozen, "repeated result preserves all route state")
		if stage < 2:
			check(bool(circuit.view().can_next), "session-earned victory permits explicit next even before save succeeds")
			equal(circuit.retry_id(), "", "a clean win offers next instead of accidental retry")
			var next := circuit.next_id()
			equal(circuit.view(), frozen, "querying next cannot mutate a completed result")
			check(not circuit.admit_next("not-a-rival"), "failed next admission leaves prior result intact")
			check(circuit.admit_next(next), "only admitted authored next world advances the stage")
		else:
			check(bool(circuit.view().complete), "exactly three clean wins complete the route")
			equal(circuit.next_id(), "", "complete circuit cannot index a fourth rival")
			check(not circuit.admit_retry(circuit.current_id()), "complete route requires deliberate replay")
	equal(total, 3780, "declared fixture elapsed total is independent of UI time")
	var old_ticket := circuit.ticket()
	circuit.begin()
	check(circuit.admit_current("wa_bidi"), "replay is a fresh first encounter")
	check(not circuit.observe_result(_terminal(0), old_ticket), "prior run ticket cannot complete a replay")
	equal(circuit.view().total_elapsed_ticks, 0, "replay clears the prior timer")


func _test_retries_and_tainted_results() -> void:
	for phase: String in [Trial.DEFEATED, Trial.TIMEOUT, Trial.LEFT_COURT, Trial.UNAVAILABLE, Trial.VICTORY]:
		var circuit := Circuit.new()
		circuit.begin()
		circuit.admit_current("wa_bidi")
		var receipt := _terminal(0, phase)
		if phase == Trial.VICTORY: receipt.developer = true
		check(circuit.observe_result(receipt), "loss/interruption/tainted victory remains an honest terminal result")
		check(not bool(circuit.view().can_next) and not bool(circuit.view().complete), "unqualified outcome never advances")
		equal(circuit.retry_id(), "wa_bidi", "retry stays on the same rival")
		var previous := circuit.ticket()
		check(circuit.admit_retry("wa_bidi"), "successful fresh retry is a new attempt")
		check(not circuit.observe_result(receipt, previous), "prior attempt ticket cannot end new retry")
		check(circuit.observe_result(_terminal(0), circuit.ticket()), "later real clean result may succeed")
		equal(circuit.view().total_elapsed_ticks, 2400, "total includes actual failed and successful attempt time")
	for invalid: Dictionary in [{"ok": false}, {"ok": true, "wire": 0}, {"ok": true, "wire": 1}]:
		var circuit := Circuit.new()
		circuit.begin()
		circuit.admit_current("wa_bidi")
		var receipt := _terminal(0)
		receipt.reward = invalid
		check(circuit.observe_result(receipt), "unearned result still permits leaving/retry")
		equal(circuit.next_id(), "", "missing or mismatched earned reward cannot advance")
		check(not circuit.refresh_reward(_terminal(0).reward), "save refresh cannot manufacture clean victory")


func _test_detachment_exit_and_save() -> void:
	var circuit := Circuit.new()
	circuit.begin()
	circuit.admit_current("wa_bidi")
	var receipt := _terminal(0, Trial.VICTORY, false)
	var original := receipt.duplicate(true)
	circuit.observe_result(receipt)
	equal(receipt, original, "observing cannot mutate challenge/reward authority")
	receipt.reward.saved = true
	equal(circuit.view().result.reward.saved, false, "result snapshot cannot inherit later caller mutation")
	var view := circuit.view()
	view.result.reward.ok = false
	view.result.health = 0
	check(bool(circuit.view().result.reward.ok) and int(circuit.view().result.health) == 74250, "returned nested view is detached")
	var saved: Dictionary = original.reward.duplicate(true)
	saved.saved = true
	saved.notice = "Progress saved."
	var before := circuit.view()
	check(circuit.refresh_reward(saved), "real save retry updates the persistence display")
	equal(circuit.view().stage, before.stage, "save cannot advance the route")
	equal(circuit.view().total_elapsed_ticks, before.total_elapsed_ticks, "save cannot advance elapsed time")
	check(bool(circuit.view().result.reward.saved), "saved status becomes visible")
	circuit.reset()
	check(not bool(circuit.view().active), "leave discards only ephemeral circuit")
	equal(original.reward.ok, true, "route reset cannot revoke an external earned receipt")
	check(not circuit.observe_result(original), "late terminal callback cannot reopen an exited route")


func _test_panel_geometry_and_input() -> void:
	var circuit := Circuit.new()
	circuit.begin()
	circuit.admit_current("wa_bidi")
	circuit.observe_result(_terminal(0, Trial.VICTORY, false))
	var won := circuit.view()
	won.progress = {"can_retry_save": true}
	var lost := won.duplicate(true)
	lost.can_next = false
	lost.can_retry = true
	lost.result.qualified = false
	lost.result.phase = Trial.TIMEOUT
	var complete := won.duplicate(true)
	complete.complete = true
	complete.can_next = false
	complete.state = "complete"
	complete.stage = 2
	complete.result = _terminal(2)
	complete.result.name = definitions[2].name
	complete.result.spell_name = definitions[2].spell_name
	complete.result.qualified = true
	complete.progress = {"can_recover_backup": true}
	var middle := won.duplicate(true)
	middle.stage = 1
	middle.result.name = definitions[1].name
	middle.result.spell_name = definitions[1].spell_name
	middle.result.reward.new = false
	check(CircuitPanel.lines(won)[1].contains("74/100") and not CircuitPanel.lines(won)[1].contains("74250"), "health uses existing player-facing resource units")
	complete.total_elapsed_ticks = 3780
	equal(CircuitPanel.lines(complete)[1], "Encounter 31.50s total (incl. retries) | Health 74/100", "completion states aggregate encounter time including readiness and retries, with normalized health")
	check(CircuitPanel.lines(middle)[2].contains("Already known, not saved"), "previously earned and failed persistence remain distinct")
	for view: Dictionary in [won, middle, lost, complete]:
		for size: Vector2 in [Vector2(480,270), Vector2(640,360), Vector2(960,540), Vector2(1280,720)]:
			var panel := CircuitPanel.new()
			var rows := CircuitPanel.actions(view)
			var geometry := CircuitPanel.geometry(size, view)
			var rectangle: Rect2 = geometry.panel
			check(Rect2(Vector2.ZERO, size).encloses(rectangle), "result stays inside compact logical viewport")
			var buttons: Array[Rect2] = geometry.buttons
			for index: int in buttons.size():
				check(rectangle.encloses(buttons[index]) and buttons[index].size.y >= 26, "action has a bounded readable target")
				for other: int in range(index + 1, buttons.size()):
					check(not buttons[index].intersects(buttons[other], true), "different result actions never overlap")
				check(_width(String(rows[index].label), 13) <= buttons[index].size.x - 20, "actual action label fits its target")
				var mouse := InputEventMouseButton.new()
				mouse.pressed = true
				mouse.button_index = MOUSE_BUTTON_LEFT
				mouse.position = buttons[index].get_center()
				equal(panel.handle_input(mouse, size, view), rows[index].id, "each visible button dispatches its own action")
			for index: int in CircuitPanel.lines(view).size():
				check(_width(CircuitPanel.lines(view)[index], 11 if index >= 3 else 12) <= float(geometry.text_width), "real rival/reward and honest resource copy fit compact width")
			check(_width(CircuitPanel.title(view), 18) <= float(geometry.text_width), "result title fits")
	var panel := CircuitPanel.new()
	var size := Vector2(480,270)
	equal(panel.handle_input(_key(KEY_ENTER), size, won), "circuit-next-learned", "default offers optional earned-tool use")
	panel.handle_input(_key(KEY_DOWN), size, won)
	equal(panel.handle_input(_key(KEY_ENTER), size, won), "circuit-next", "ordinary next remains a separate unforced choice")
	panel.handle_input(_pad(JOY_BUTTON_DPAD_DOWN), size, won)
	equal(panel.handle_input(_pad(JOY_BUTTON_A), size, won), "circuit-leave", "controller selection activates exact leave intent")
	equal(panel.handle_input(_pad(JOY_BUTTON_B), size, won), "circuit-leave", "controller back exits result")
	var echoed := _key(KEY_ENTER)
	echoed.echo = true
	equal(panel.handle_input(echoed, size, won), "", "held key repeat cannot trigger another world transition")
	var next_result := won.duplicate(true)
	next_result.attempt = int(won.attempt) + 1
	equal(panel.handle_input(_key(KEY_ENTER), size, next_result), "circuit-next-learned", "new result resets selection before first input")
	equal(panel.handle_input(_key(KEY_ENTER), size, {"active": false}), "", "inactive circuit cannot intercept ordinary input")


static func _width(text: String, size: int) -> float:
	return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


static func _pad(code: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	return event
