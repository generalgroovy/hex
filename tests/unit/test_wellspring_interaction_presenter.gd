extends FluxTestSuite


func run() -> int:
	_test_repository_interaction_language()
	_test_prompt_copy_and_safe_area()
	_test_compact_service_cards()
	_test_readable_notices()
	_test_fail_closed_station_coverage()
	_test_live_practice_help()
	return finish("wellspring-interaction-presenter")


func _test_live_practice_help() -> void:
	var preferences := PlayerPreferences.new()
	preferences.keyboard_bindings[&"jump"] = KEY_J
	preferences.keyboard_bindings[&"slide"] = KEY_K
	preferences.keyboard_bindings[&"evade"] = KEY_L
	preferences.keyboard_bindings[&"technique"] = KEY_T
	var movement := WellspringInteractionPresenter.practice_station_lines({"command": "movement_guide", "lines": ["obsolete"]}, preferences)
	equal(movement.size(), 6, "movement coaching fits the service directory help budget")
	var copy := " ".join(movement)
	check(copy.contains("Jump J: press, then release") and copy.contains("Hold Jump to brake for charge"), "first interaction teaches current preparation and release")
	check(copy.contains("Slide K at speed") and copy.contains("release and press K again"), "slide coaching uses current binding and a deliberate second gesture")
	check(copy.contains("Air L: direction dodges; neutral fast-falls"), "air coaching distinguishes directional and neutral outcomes")
	check(copy.contains("hold J along it; release to walljump"), "wall coaching uses the held jump contract")
	check(not copy.contains("obsolete") and not copy.contains("Release direction to brake"), "static map copy cannot revive a stale blanket braking rule")
	var impact := WellspringInteractionPresenter.practice_station_lines({"command": "impact_practice"}, preferences)
	copy = " ".join(impact)
	check(copy.contains("Tech T near landing or during the brace"), "impact coaching follows a rebound Technique key")
	check(copy.contains("%.1f base Stamina; perks / chain apply" % (float(MovementTuning.IMPACT_RECOVERY_TECH_COST) / SimConfig.FIXED_SCALE)), "impact cost derives from actual tuning and discloses perk and chain modifiers")
	check(copy.contains("full %d ms brace" % MovementTuning.IMPACT_RECOVERY_DURATION_MS) and copy.contains("No new protection"), "impact recovery explains its actual fallback and exposure")
	for command: String in ["movement_guide", "impact_practice"]:
		for device: int in [ControlBindingEditor.DEVICE_KEYBOARD, ControlBindingEditor.DEVICE_MOUSE, ControlBindingEditor.DEVICE_CONTROLLER]:
			var lines := WellspringInteractionPresenter.practice_station_lines({"command": command}, preferences, device)
			check(lines.size() <= WellspringServiceDirectory.MAX_DETAIL_LINES, "practice help keeps six-row bound on each device")
			for line: String in lines:
				check(ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x <= 728.0, "all current practice controls fit the directory detail width")
	preferences.mouse_bindings[&"jump"] = MOUSE_BUTTON_WHEEL_DOWN
	copy = " ".join(WellspringInteractionPresenter.practice_station_lines({"command": "movement_guide"}, preferences, ControlBindingEditor.DEVICE_MOUSE))
	check(copy.contains("Wheel cannot hold charge, flight or wallrun"), "wheel impulses never advertise a held gesture")
	preferences.keyboard_bindings[&"technique"] = 0
	copy = " ".join(WellspringInteractionPresenter.practice_station_lines({"command": "impact_practice"}, preferences))
	check(copy.contains("Not bound") and not copy.contains("Tech V"), "unbound controls never silently advertise a default")
	equal(WellspringInteractionPresenter.practice_station_lines({"command": "host_session"}, preferences), [], "network and other station help keeps its existing owner")
	equal(WellspringInteractionPresenter.practice_station_lines({"command": "movement_guide"}, null), [], "missing preferences leave help selection with the caller")


func _test_readable_notices() -> void:
	var presenter := WellspringInteractionPresenter.new()
	var messages: Array[String] = [
		"Spell setup closed; confirmation is still pending.",
		"Only the Farflow host can restore the shared court.",
		"Press F again within three seconds to close the company.",
		"Water Spray | Earth Spray | Fire Bolt | Fire Rapid in your first four positions.",
		"Saved spell weaves could not load; stored file preserved.",
	]
	for viewport: Vector2 in [Vector2(1280, 720), Vector2(960, 540), Vector2(1600, 900)]:
		for message: String in messages:
			var model := presenter.notice_layout(viewport, message)
			var rect: Rect2 = model.rect
			equal(" ".join(model.lines), message, "ordinary actionable notice remains complete")
			check(Rect2(Vector2.ZERO, viewport).encloses(rect), "notice stays in viewport")
			check(model.lines.size() <= 3 and rect.size.y <= 70.0, "notice has bounded height")
			for line: String in model.lines:
				check(ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x <= rect.size.x - 54.0, "each line fits actual font width")
			check(is_same(model, presenter.notice_layout(viewport, message)), "unchanged notice reuses cached layout")
			check(model.is_read_only() and model.lines.is_read_only(), "callers cannot corrupt cached layout")
			equal(rect.position.y, 60.0 if viewport.x == 960.0 else 16.0, "narrow notice clears top HUD")
	equal((presenter.notice_layout(Vector2(1280,720), "Saved.").rect as Rect2).size.y, 42.0, "short notice stays compact")
	var huge := presenter.notice_layout(Vector2(1280,720), "W".repeat(2048))
	check(huge.lines.size() == 3 and String(huge.lines[-1]).ends_with("..."), "oversized input is bounded with explicit truncation")
	# Equal bounded prefixes must not reuse a layout with the wrong overflow cue.
	var prefix := "a " + " ".repeat(510)
	var short_prefix := presenter.notice_layout(Vector2(1280,720), prefix)
	var long_prefix := presenter.notice_layout(Vector2(1280,720), prefix + "b")
	check(not String(short_prefix.lines[-1]).ends_with("...") and String(long_prefix.lines[-1]).ends_with("..."), "overflow participates in cache identity")
	check(presenter.notice_layout(Vector2(1280,720), "  ").is_empty(), "empty copy draws no notice")
	check(presenter.notice_layout(Vector2(INF,720), "Saved.").is_empty(), "nonfinite viewport is rejected")


func _test_repository_interaction_language() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "visual language loads for interaction presentation")
	var campus := SanctumCampusLayout.new()
	var campus_loaded := campus.load_from_file("res://content/maps/sanctum_campus_g2_v1.json")
	check(campus_loaded, "campus loads for interaction presentation: " + campus.last_error)
	if not campus_loaded: return
	var presenter := WellspringInteractionPresenter.new()
	check(presenter.configure(language, campus), "Wellspring interaction language validates: %s" % presenter.last_error)
	equal(presenter.styles_by_kind.size(), 10, "every live station kind has one interaction style")
	equal(presenter.content_hash.length(), 64, "interaction presentation has a stable content hash")
	for station: Dictionary in campus.stations_by_id.values():
		check(presenter.styles_by_kind.has(String(station.get("kind", ""))), "%s has a validated prompt style" % String(station.get("id", "station")))


func _test_prompt_copy_and_safe_area() -> void:
	equal(WellspringInteractionPresenter.station_action_text({"prompt": "F  STUDY THE ROUTES"}), "Study The Routes", "compact prompt removes the stale hard-coded key")
	equal(WellspringInteractionPresenter.station_action_text({"prompt": "E  OPEN GALLERY"}), "Open Gallery", "compact Gallery prompt removes its obsolete alternate key")
	equal(WellspringInteractionPresenter.localized_interaction_line("F closes this field note", "Q"), "Q closes this field note", "expanded guidance follows the live interaction binding")
	equal(WellspringInteractionPresenter.localized_interaction_line("E opens this field note", "Y"), "Y opens this field note", "legacy alternate prompts also follow the live interaction binding")
	equal(WellspringInteractionPresenter.localized_interaction_line("Everyone readies", "Q"), "Everyone readies", "non-input guidance stays unchanged")
	var clamped := WellspringInteractionPresenter.clamped_panel_rect(Rect2(-80, -40, 232, 52), Vector2(1280, 720), 16, 126)
	equal(clamped.position, Vector2(16, 58), "world prompt clamps below the compact top HUD")
	var lower := WellspringInteractionPresenter.clamped_panel_rect(Rect2(1200, 690, 232, 52), Vector2(1280, 720), 16, 126)
	equal(lower.position, Vector2(1032, 542), "world prompt clamps clear of bottom combat HUD lanes")
	for center: Vector2 in [Vector2(640, 360), Vector2(80, 180), Vector2(1200, 180), Vector2(640, 540)]:
		var actor := Rect2(center - Vector2(48, 160), Vector2(96, 176))
		var overlap := Rect2(center - Vector2(116, 40), Vector2(232, 52))
		var readable := WellspringInteractionPresenter.avoid_actor_rect(overlap, actor, Vector2(1280, 720))
		check(not readable.intersects(actor), "compact station prompt leaves body and feet visible")
		equal(readable.size, overlap.size, "avoiding actors never shrinks prompt text")
	var clear := Rect2(16, 100, 232, 52)
	equal(WellspringInteractionPresenter.avoid_actor_rect(clear, Rect2(600, 200, 96, 176), Vector2(1280, 720)), clear, "non-overlapping prompts retain their stable station position")


func _test_fail_closed_station_coverage() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "visual language loads before interaction mutation")
	var campus := SanctumCampusLayout.new()
	var campus_loaded := campus.load_from_file("res://content/maps/sanctum_campus_g2_v1.json")
	check(campus_loaded, "campus loads before interaction mutation: " + campus.last_error)
	if not campus_loaded: return
	var source := WellspringInteractionPresenter.new()
	var source_configured := source.configure(language, campus)
	check(source_configured, "valid interaction presentation loads before mutation: " + source.last_error)
	if not source_configured: return
	var presenter := WellspringInteractionPresenter.new()
	presenter.language = language
	presenter.data = source.data.duplicate(true)
	(presenter.data["station_styles"] as Array).remove_at(0)
	check(not presenter.validate(campus), "missing station visual fails closed")
	check(not presenter.last_error.is_empty(), "interaction failure is actionable")
	presenter.data = source.data.duplicate(true)
	((presenter.data["station_styles"] as Array)[1] as Dictionary)["kind"] = String(((presenter.data["station_styles"] as Array)[0] as Dictionary)["kind"])
	check(not presenter.validate(campus), "duplicate station style fails closed")


func _test_compact_service_cards() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "visual language loads for compact service cards")
	var campus := SanctumCampusLayout.new()
	var campus_loaded := campus.load_from_file("res://content/maps/sanctum_campus_g2_v1.json")
	check(campus_loaded, "campus loads for compact service cards: " + campus.last_error)
	if not campus_loaded: return
	var presenter := WellspringInteractionPresenter.new()
	check(presenter.configure(language, campus), "compact service presenter configures")
	var viewport := Vector2(1280, 720)
	var anchor := Vector2(640, 400)
	var compact := presenter.station_rect(viewport, anchor, false, 6)
	equal(compact.size.y, 40.0, "collapsed card is a single icon/title/key row")
	var detail := presenter.station_rect(viewport, anchor, true, 6)
	check(detail.size.y > compact.size.y, "expanded card reserves detailed guidance only when requested")
	var overflow := presenter.station_rect(viewport, anchor, true, 1000)
	equal(overflow.size, detail.size, "expanded card obeys validated line budget")
	var actor := Rect2(592, 260, 96, 176)
	var avoided := presenter.station_rect(viewport, anchor, false, 0, actor)
	check(not avoided.intersects(actor), "compact service card remains clear of the local body")
