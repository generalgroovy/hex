extends FluxTestSuite

const TrialPanel = preload("res://src/presentation/solo_duel_trial_panel.gd")
const Run = preload("res://src/app/solo_duel_trial.gd")
const Rival = preload("res://src/app/solo_duel_rival.gd")
const Practice = preload("res://src/sim/combat/interception_practice.gd")


func run() -> int:
	var definition := {"score_limit": 3, "bounds": [100, 100, 500, 500]}
	var before := definition.duplicate(true)
	equal(SanctumCampusRenderer.arena_label(definition), "PROVING COURT · FIRST 3", "normal court keeps its score rule")
	equal(SanctumCampusRenderer.arena_label({"score_limit": 7}), "PROVING COURT · FIRST 7", "normal score remains authored")
	equal(SanctumCampusRenderer.arena_label(definition, "unknown"), SanctumCampusRenderer.arena_label(definition), "unknown context preserves normal court")
	equal(SanctumCampusRenderer.arena_label(definition, SanctumCampusRenderer.SIGNATURE_CHALLENGE_CONTEXT), "SIGNATURE CHALLENGE", "all signature rivals use their own encounter label without a hardcoded opponent")
	var label := SanctumCampusRenderer.arena_label(definition, SanctumCampusRenderer.SOLO_DUEL_CONTEXT)
	equal(label, "DUEL TRIAL · DEFEAT OH TIPI", "trial states single-defeat objective")
	equal(definition, before, "context cannot change court authority")
	check(_width(label, 12) <= 198, "trial caption fits existing plaque")
	check(_width(SanctumCampusRenderer.arena_label(definition, SanctumCampusRenderer.SIGNATURE_CHALLENGE_CONTEXT), 12) <= 198, "signature caption fits the same existing plaque")
	_test_policy_copy()
	_test_world_tell()
	_test_world_tell_incomplete_status()
	_test_phase_world_tell()
	_test_pause_world_tell_guards()
	_test_world_tell_nameplate_separation()
	_test_modal_fit()
	return finish("solo-duel-trial-panel")


func _test_world_tell_nameplate_separation() -> void:
	for anchor: Vector2 in [Vector2.ZERO, Vector2(540, 360), Vector2(542.4, 359.7)]:
		var box := TrialPanel.world_tell_box(anchor)
		# Mirrors Bootstrap's ordinary14px nameplate at baseline-64. Native
		# acceptance additionally checks the real rendered plate in both viewports.
		var nameplate := Rect2(anchor + Vector2(-40, -77), Vector2(80, 17))
		check(not box.intersects(nameplate, true), "Heavy/Pause badge never overlaps the ordinary actor nameplate")
		check(nameplate.position.y - box.end.y >= 15.0, "rounded moving anchor retains a clear roughly12-screen-pixel gap")
		equal(box.size, Vector2(80, 30), "fix stacks the existing compact badge instead of expanding its footprint")


func _test_policy_copy() -> void:
	# Status/copy agreement only: this does not prove paid cast admission or difficulty.
	var boundaries := [
		[0, Rival.WINDUP_TICKS - 1, "HEAVY INCOMING · Sidestep / cover"],
		[Rival.WINDUP_TICKS, Rival.WINDUP_TICKS + Rival.PRESSURE_TICKS - 1, "VOLLEY · Move between shots"],
		[Rival.WINDUP_TICKS + Rival.PRESSURE_TICKS, Rival.CYCLE_TICKS - 1, "OPENING · Attack or recover Flux"],
	]
	var active := {"phase": Run.ACTIVE}
	for boundary: Array in boundaries:
		for offset: int in [int(boundary[0]), int(boundary[1])]:
			for start: int in [0, 9137]:
				var status := Rival.status(start + Rival.READY_END + Rival.CYCLE_TICKS + offset, start)
				var before := status.duplicate(true)
				var hint := TrialPanel.pressure_hint(active, status)
				equal(hint, boundary[2], "cue follows exact real phase boundaries and shifted start")
				equal(status, before, "reading cue cannot change policy")
				check(_width(hint, 12) <= 292, "live cue fits unchanged HUD")
	var neutral := TrialPanel.pressure_hint(active)
	equal(TrialPanel.pressure_hint(active, {"phase": "windup"}), neutral, "missing telegraph cannot invent Heavy")
	equal(TrialPanel.pressure_hint(active, Rival.status(9, 10)), neutral, "invalid status stays neutral")
	equal(TrialPanel.pressure_hint({"phase": Run.READY, "countdown_ticks": 121}), "READY IN 2", "countdown uses observed remaining ticks")
	equal(TrialPanel.pressure_hint({"phase": Run.TIMEOUT, "finished": true}, Rival.status(Rival.DURATION_TICKS, 0)), "TRIAL COMPLETE", "terminal view advertises no opening")


func _test_world_tell() -> void:
	for offset: int in range(Rival.CYCLE_TICKS):
		var status := Rival.status(9137 + Rival.READY_END + offset, 9137)
		var before := status.duplicate(true)
		var expected := ceili(float(Rival.WINDUP_TICKS - offset) * 6.0 / float(Rival.WINDUP_TICKS)) if offset < Rival.WINDUP_TICKS else 0
		equal(TrialPanel.heavy_tell_segments(Run.ACTIVE, status, true, true), expected, "world warning follows every policy tick")
		equal(TrialPanel.heavy_tell_segments(Run.ACTIVE, status, false, true), 0, "re-entry without attack has no warning")
		equal(TrialPanel.heavy_tell_segments(Run.ACTIVE, status, true, false), 0, "dead rival has no warning")
		equal(status, before, "world warning cannot mutate authority")
	var windup := Rival.status(Rival.READY_END, 0)
	for phase: String in [Run.READY, Run.VICTORY, Run.DEFEATED, Run.TIMEOUT, Run.LEFT_COURT, Run.UNAVAILABLE, ""]:
		equal(TrialPanel.heavy_tell_segments(phase, windup, true, true), 0, "inactive trial never shows warning")
	equal(TrialPanel.heavy_tell_segments(Run.ACTIVE, {}, true, true), 0, "missing policy cannot invent warning")
	check(_width("HEAVY", 14) <= 76, "world badge label fits")


func _test_world_tell_incomplete_status() -> void:
	for status: Dictionary in [
		{"phase": Rival.WINDUP, "remaining_ticks": Rival.WINDUP_TICKS},
		{"telegraph": "heavy", "remaining_ticks": Rival.WINDUP_TICKS},
		{"phase": Rival.WINDUP, "telegraph": "volley", "remaining_ticks": Rival.WINDUP_TICKS},
		{"phase": Rival.PRESSURE, "telegraph": "heavy", "remaining_ticks": Rival.WINDUP_TICKS},
		{"phase": Rival.RECOVER, "telegraph": "heavy", "remaining_ticks": Rival.WINDUP_TICKS},
		{"phase": Rival.WINDUP, "telegraph": "heavy"},
	]:
		var before := status.duplicate(true)
		equal(TrialPanel.heavy_tell_segments(Run.ACTIVE, status, true, true), 0, "incomplete or contradictory status cannot invent a Heavy countdown")
		equal(status, before, "rejected status remains read-only")
	for boundary: Array in [[-1, 0], [0, 0], [1, 1], [16, 1], [17, 2], [Rival.WINDUP_TICKS, 6], [Rival.WINDUP_TICKS + 1, 6]]:
		var status := {"phase": Rival.WINDUP, "telegraph": "heavy", "remaining_ticks": int(boundary[0])}
		equal(TrialPanel.heavy_tell_segments(Run.ACTIVE, status, true, true), int(boundary[1]), "countdown has six bounded segments and no positive segment after zero")


func _test_phase_world_tell() -> void:
	for start: int in [0, 9137]:
		for offset: int in range(Rival.CYCLE_TICKS):
			var status := Rival.status(start + Rival.READY_END + offset, start)
			var before := status.duplicate(true)
			var expected: Dictionary = {}
			if offset < Rival.WINDUP_TICKS:
				expected = {"kind": "heavy", "label": "HEAVY", "segments": TrialPanel.heavy_tell_segments(Run.ACTIVE, status, true, true)}
			elif offset >= Rival.WINDUP_TICKS + Rival.PRESSURE_TICKS:
				expected = {"kind": "pause", "label": "PAUSE", "segments": ceili(float(Rival.CYCLE_TICKS - offset) * 6.0 / float(Rival.RECOVERY_TICKS))}
			equal(TrialPanel.world_tell(Run.ACTIVE, status, true, true), expected, "world phase cue follows every actual policy tick with no independent timer")
			equal(TrialPanel.world_tell(Run.ACTIVE, status, true, true), expected, "repeated presentation sampling cannot advance the countdown")
			equal(TrialPanel.world_tell(Run.ACTIVE, status, false, true), {}, "outside-court rival has neither warning nor pause cue")
			equal(TrialPanel.world_tell(Run.ACTIVE, status, true, false), {}, "dead rival has neither warning nor pause cue")
			equal(TrialPanel.world_tell(Run.ACTIVE, status, true, true, true), {} if String(status.phase) == Rival.RECOVER else expected, "real pending cast or recovery suppresses PAUSE without altering Heavy warning semantics")
			equal(status, before, "world phase sample cannot change the policy status")
	for tick: int in [0, Rival.READY_END - 1, Rival.DURATION_TICKS, Rival.DURATION_TICKS + 1]:
		equal(TrialPanel.world_tell(Run.ACTIVE, Rival.status(tick, 0), true, true), {}, "ready and expired policy never advertise a world opportunity")
	var pause := Rival.status(Rival.READY_END + Rival.WINDUP_TICKS + Rival.PRESSURE_TICKS, 0)
	for phase: String in [Run.IDLE, Run.READY, Run.VICTORY, Run.DEFEATED, Run.TIMEOUT, Run.LEFT_COURT, Run.UNAVAILABLE, "", "unknown"]:
		equal(TrialPanel.world_tell(phase, pause, true, true), {}, "inactive or terminal trial cannot display a stale pause")
	for label: String in ["HEAVY", "PAUSE"]:
		check(_width(label, 14) <= 76, "both phase labels fit the unchanged overhead footprint")
	var tell := TrialPanel.world_tell(Run.ACTIVE, pause, true, true)
	equal(tell, {"kind": "pause", "label": "PAUSE", "segments": 6}, "first real recovery tick exposes the full bounded pause countdown")
	tell.label = "SAFE"
	equal(TrialPanel.world_tell(Run.ACTIVE, pause, true, true).label, "PAUSE", "returned presentation data cannot mutate the next cue or promise immunity")
	equal(TrialPanel.pressure_hint({"phase": Run.ACTIVE}, pause), "OPENING · Attack or recover Flux", "overhead cue preserves the player's existing attack-or-rest choice")


func _test_pause_world_tell_guards() -> void:
	var pause := Rival.status(Rival.READY_END + Rival.WINDUP_TICKS + Rival.PRESSURE_TICKS, 0)
	for field: String in ["phase", "telegraph", "break", "complete", "remaining_ticks"]:
		var missing := pause.duplicate(true)
		missing.erase(field)
		equal(TrialPanel.world_tell(Run.ACTIVE, missing, true, true), {}, "missing recovery field cannot invent PAUSE: " + field)
	for replacement: Array in [
		["phase", Rival.WINDUP], ["phase", Rival.PRESSURE], ["phase", Rival.COMPLETE],
		["phase", "unknown"], ["telegraph", "heavy"], ["telegraph", "volley"],
		["telegraph", null], ["break", false], ["break", "true"],
		["complete", true], ["complete", 0],
		["remaining_ticks", -1], ["remaining_ticks", 0],
		["remaining_ticks", Rival.RECOVERY_TICKS + 1],
		["remaining_ticks", 1.0], ["remaining_ticks", "1"], ["remaining_ticks", null],
	]:
		var invalid := pause.duplicate(true)
		invalid[String(replacement[0])] = replacement[1]
		var before := invalid.duplicate(true)
		equal(TrialPanel.world_tell(Run.ACTIVE, invalid, true, true), {}, "contradictory, expired or malformed recovery status stays silent")
		equal(invalid, before, "rejected recovery status remains untouched")
	equal(TrialPanel.world_tell(Run.ACTIVE, {}, true, true), {}, "missing policy has no cue")
	var segments_seen := {}
	var previous := 6
	for remaining: int in range(Rival.RECOVERY_TICKS, 0, -1):
		var status := pause.duplicate(true)
		status.remaining_ticks = remaining
		var tell := TrialPanel.world_tell(Run.ACTIVE, status, true, true)
		var segments := int(tell.get("segments", 0))
		check(segments >= 1 and segments <= 6 and segments <= previous, "the 120 Hz recovery countdown only drains six bounded segments")
		segments_seen[segments] = true
		previous = segments
	equal(segments_seen.size(), 6, "every recovery segment is shown before expiry")
	for boundary: Array in [[1, 1], [28, 1], [29, 2], [140, 5], [141, 6], [Rival.RECOVERY_TICKS, 6]]:
		var status := pause.duplicate(true)
		status.remaining_ticks = int(boundary[0])
		equal(int(TrialPanel.world_tell(Run.ACTIVE, status, true, true).segments), int(boundary[1]), "PAUSE changes exactly every 28 authoritative recovery ticks")
	var busy := TrialPanel.world_tell(Run.ACTIVE, pause, true, true, true)
	equal(busy, {}, "a policy pause cannot hide an actual paid startup or recovery")
	pause.remaining_ticks = 84
	equal(TrialPanel.world_tell(Run.ACTIVE, pause, true, true, false).segments, 3, "ending actual cast recovery reveals only the remaining pause, never a fresh full clock")
	var windup := Rival.status(Rival.READY_END, 0)
	windup["break"] = true
	equal(TrialPanel.world_tell(Run.ACTIVE, windup, true, true), {}, "contradictory Heavy-and-break status cannot create a phase cue")
	windup["break"] = false
	windup.complete = true
	equal(TrialPanel.world_tell(Run.ACTIVE, windup, true, true), {}, "completed policy cannot retain a Heavy world warning")


func _test_modal_fit() -> void:
	var abilities := AbilityCatalog.new()
	check(abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "loaner labels use current catalog")
	var profile := Practice.player_profile(abilities)
	check(not profile.is_empty(), "loaner profile resolves")
	if profile.is_empty(): return
	var preferences := PlayerPreferences.new()
	var bindings := ControlBindingEditor.new()
	var kit := PackedStringArray()
	for role: String in ["water_spray", "earth_spray", "fire_bolt", "fire_rapid"]:
		var slot := int(profile.slots[role])
		kit.append("%s / %s   %s" % [SpellLoomPresenter.slot_binding_label(slot - 1, preferences), bindings.binding_label(StringName("spell_%d" % slot), ControlBindingEditor.DEVICE_CONTROLLER, preferences), String(profile.spell_names[role])])
	var briefing := TrialPanel.modal_lines({}, kit)
	equal(briefing.size(), 11, "briefing retains bounded loop advice and four bindings")
	check(briefing[0].contains("One defeat"), "briefing states single-defeat rule")
	check(briefing[3].contains("lingering shots"), "opening does not promise safety")
	for index: int in 4: equal(briefing[index + 5], kit[index], "real binding line retained")
	for phase: String in ["", Run.VICTORY, Run.DEFEATED, Run.TIMEOUT, Run.LEFT_COURT, Run.UNAVAILABLE]:
		var view := {} if phase.is_empty() else {"phase": phase, "finished": true, "elapsed_ticks": 1217, "health": 12549, "health_maximum": 108000, "interceptions": 3, "paid_casts": 17}
		var before := view.duplicate(true)
		var lines := TrialPanel.modal_lines(view, kit)
		equal(view, before, "copy never rewrites run state")
		if not phase.is_empty():
			equal(lines[4], "Health remaining: " + CompactCombatHud.resource_amount_label(12549, 108000), "result and HUD share health rounding")
			equal(lines[4], "Health remaining: 12/108", "fractional health uses integer display")
		for size: Vector2 in [Vector2(960, 540), Vector2(1280, 720)]:
			var boxes := TrialPanel.geometry(size)
			var panel: Rect2 = boxes.panel
			check(Rect2(Vector2.ZERO, size).encloses(panel) and panel.encloses(boxes.primary) and panel.encloses(boxes.secondary), "compact panel and actions fit")
			check(not (boxes.primary as Rect2).intersects(boxes.secondary), "actions remain separate")
			var last_baseline := TrialPanel.BODY_FIRST_BASELINE + (lines.size() - 1) * TrialPanel.BODY_LINE_STEP
			check(last_baseline + ThemeDB.fallback_font.get_descent(12) < panel.size.y - 94 - ThemeDB.fallback_font.get_ascent(12), "body clears error and action rows")
			for line: String in lines: check(_width(line, 12) <= panel.size.x - 44, "actual modal copy fits without clipping")
			check(_width(TrialPanel.result_title(phase), 23) <= panel.size.x - 44, "title fits compact modal")


func _width(words: String, size: int) -> float:
	return ThemeDB.fallback_font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
