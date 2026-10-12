extends FluxTestSuite


func run() -> int:
	var preferences := PlayerPreferences.new()
	var rows := MovementGuideModel.entries(preferences)
	equal(rows.size(), 16, "guide retains sixteen useful techniques")
	check(String(MovementGuideModel.entry_by_id("sprint").timing_note).contains("2.2x walk speed"), "guide follows authored sprint contrast")
	check(String(MovementGuideModel.entry_by_id("slide").execution).contains("Speed lost in a turn stays lost"), "guide explains earned momentum rather than hidden reacceleration")
	var ids: Dictionary = {}
	for row: Dictionary in rows:
		var id := String(row["id"])
		check(not ids.has(id), "technique IDs remain unique")
		ids[id] = true
		check(row["category"] in ["travel", "escape", "expression"], "technique has a learning category")
		for key: String in ["title", "binding", "execution", "timing_note", "counter", "state", "directional", "neutral", "steering", "legal_next", "feedback"]:
			check(not String(row.get(key, "")).is_empty(), id + " exposes " + key)
		check(not String(row["execution"]).contains("{"), "bindings resolve in instructions")
		check(not String(row["timing_note"]).contains("{"), "bindings resolve in timing")
		check(int(row["cost_milli"]) >= 0, "cost is non-negative")
		var lines := MovementGuideModel.detail_lines(row)
		check(lines.size() >= 5 and lines.size() <= 6, "details remain bounded")
		for line: String in lines:
			check(line.begins_with("- "), "details are structured")
	check(not ids.has("vault") and not ids.has("superglide"), "retired adapters are not offered")
	for id: String in ["roll", "air_dodge"]:
		equal(MovementGuideModel.entry_by_id(id)["binding"], "B", "Evade follows B binding")
	for id: String in ["air_turn", "impact_tech"]:
		equal(MovementGuideModel.entry_by_id(id)["binding"], "V", "Technique follows V binding")
	equal(MovementGuideModel.entry_by_id("wall_run")["action"], "jump", "wallrun now uses held Jump")
	equal(MovementGuideModel.entry_by_id("slide")["binding"], "C", "slide follows C binding")
	preferences.keyboard_bindings[&"jump"] = KEY_J
	for id: String in ["jump", "wall_run", "wall_jump", "double_jump"]:
		var row := MovementGuideModel.entry_by_id(id, preferences)
		equal(row["binding"], "J", "rebound Jump propagates through dependent routes")
		check(String(row["execution"]).contains("J"), "instruction includes current binding")
	check(String(MovementGuideModel.entry_by_id("double_jump", preferences).timing_note).contains("release and press J again"), "held-intent rearm guidance follows the rebound Jump key")
	preferences.keyboard_bindings[&"jump"] = 0
	equal(MovementGuideModel.entry_by_id("jump", preferences)["binding"], "UNBOUND", "unbound is explicit")
	equal(MovementGuideModel.entries(preferences, ControlBindingEditor.DEVICE_CONTROLLER).size(), rows.size(), "controller shares curriculum")
	_test_height_and_costs()
	_test_resource_summary()
	_test_route_choices()
	check(MovementGuideModel.entry_by_id("missing").is_empty(), "unknown technique fails closed")
	check(MovementGuideModel.detail_lines({}).is_empty(), "empty details fail closed")
	return finish("movement-guide-model")


func _test_height_and_costs() -> void:
	var jump := MovementGuideModel.entry_by_id("jump")
	check(String(jump["execution"]).contains("release to launch"), "release-to-jump is explicit")
	check(String(jump["timing_note"]).contains("grounded and vulnerable"), "jumpsquat cannot imply protection")
	check(String(jump["execution"]).contains("gradually brakes momentum") and String(jump["execution"]).contains("complete tap carries momentum"), "guide distinguishes gradual gathering drag from complete momentum-carrying taps")
	check(String(jump["steering"]).contains("External pushes still act"), "gathering is not advertised as immunity to displacement")
	var slide := MovementGuideModel.entry_by_id("slide")
	check(String(slide["directional"]).contains("Incoming velocity") and String(slide["neutral"]).contains("never stale facing"), "guide teaches momentum-led Slide entry independent of facing")
	var slide_jump := MovementGuideModel.entry_by_id("slide_jump")
	check(String(slide_jump["execution"]).contains("holding Jump gradually brakes") and String(slide_jump["neutral"]).contains("remaining velocity"), "slidejump teaches momentum retention through gathering")
	check(String(slide_jump["timing_note"]).contains("not its cooldown or paid jump family"), "gathering never promises a paid-action refund")
	equal(jump["cost_milli"], MovementTuning.HOP_COST, "jump cost derives from runtime")
	for id: String in ["jump", "slide", "slide_jump", "wall_jump", "double_jump"]:
		equal(MovementGuideModel.entry_by_id(id)["protection_ms"], 0, "height actions advertise no timed immunity")
	equal(MovementGuideModel.entry_by_id("roll")["protection_ms"], MovementTuning.ROLL_INVULNERABILITY_MS, "roll retains true timed immunity")
	equal(MovementGuideModel.entry_by_id("air_dodge")["protection_ms"], MovementTuning.AIR_DODGE_INVULNERABILITY_MS, "dodge retains true timed immunity")
	equal(MovementGuideModel.entry_by_id("slide")["duration_ms"], MovementTuning.SLIDE_DURATION_MS, "slide time is source derived")
	equal(MovementGuideModel.compact_cells(MovementGuideModel.entry_by_id("slide"))[4], "Low profile", "table distinguishes low profile")
	var air := MovementGuideModel.entry_by_id("double_jump")
	check(String(air["title"]).contains("Double jump"), "most characters have a genuine double jump")
	for race: String in ["Sylphs", "Wyrmborn", "Angels", "Demons"]:
		check(String(air["execution"]).contains(race), "flight capability is explicit for " + race)
	check(String(air["timing_note"]).contains("does not refill"), "wall contact cannot refill flight")
	check(String(air["timing_note"]).contains("dodge discards") and String(air["timing_note"]).contains("wallrun consumes"), "guide makes held-air ownership visible rather than a surprise lockout")
	var wall := MovementGuideModel.entry_by_id("wall_run")
	check(String(wall["execution"]).contains("Release") and String(wall["counter"]).contains("No protection"), "wall release and vulnerability are explicit")
	var dodge := MovementGuideModel.entry_by_id("air_dodge")
	var turn := MovementGuideModel.entry_by_id("air_turn")
	check(String(turn["timing_note"]).contains("After air-dodge commitment") and String(turn["timing_note"]).contains("without extending"), "guide teaches paid recovery turn without promising renewed protection")
	check(String(dodge["execution"]).contains("neutral movement") and String(dodge["execution"]).contains("free vertical fast-fall"), "neutral Evade is free fastfall")
	equal(MovementGuideModel.entry_by_id("wave_dash")["protection_ms"], 0, "wavedash landing adds no immunity")
	equal(MovementGuideModel.entry_by_id("slide_brake")["cost_milli"], 0, "brake remains free")
	check(String(MovementGuideModel.entry_by_id("roll")["neutral"]).contains("never aim"), "ground roll uses movement fallback")
	check(String(MovementGuideModel.entry_by_id("wall_jump")["neutral"]).contains("not cursor"), "walljump uses outward geometry not cursor")


func _test_resource_summary() -> void:
	var state := PlayerState.new()
	state.stamina_maximum = 123000
	state.stamina_recovery_per_second = 31000
	state.movement_chain_count = 3
	state.movement_chain_reset_ticks = 10
	var lines := MovementGuideModel.summary_lines(state)
	check(lines[0].contains("123 maximum") and lines[0].contains("31/s"), "summary uses selected character resources")
	check(lines[1].contains("Next premium: 30%"), "next chain premium is current")
	check(" ".join(lines).contains("Standing and wallrunning evade neither"), "exposure matrix is taught")
	check(" ".join(lines).contains("independently ramp recovery"), "recovery ramps remain explained")
	check(" ".join(lines).contains("%d ms without another notch" % InputRouter.WHEEL_GESTURE_QUIET_MS), "wheel timing derives from runtime")
	state.movement_chain_reset_ticks = 0
	check(MovementGuideModel.summary_lines(state)[1].contains("Next premium: 0%"), "expired chain no longer raises cost")


func _test_route_choices() -> void:
	var state := PlayerState.new()
	state.movement_chain_count = 2
	state.movement_chain_reset_ticks = 30
	var preferences := PlayerPreferences.new()
	preferences.keyboard_bindings[&"jump"] = KEY_J
	var before := state.canonical_values()
	var rows := MovementGuideModel.route_choices(state,preferences)
	equal(rows.size(),3,"optional route choices teach three distinct purposes")
	equal(rows[0].id,"open_brake","ordinary zero-action-cost route remains the first option")
	equal(int(rows[0].next_cost),0,"free steering is not assigned an invented chain cost")
	equal(int(rows[1].next_cost),MovementSystem._movement_action_cost(state,MovementTuning.HOP_COST),"wall approach next jump cost uses actual identity and chain policy")
	equal(int(rows[2].next_cost),MovementSystem._movement_action_cost(state,MovementTuning.SLIDE_COST),"combat approach next slide uses the actual current cost")
	check(String(rows[1].execution).contains("J"),"route instructions follow the rebound jump input")
	for row: Dictionary in rows:
		for key: String in ["title","execution","benefit","cost","counter","reference"]:
			check(not String(row[key]).is_empty(),"route choice exposes "+key)
		check(not row.moves.is_empty(),"optional reader can attach routes to relevant moves")
	equal(state.canonical_values(),before,"cost comparison never changes movement authority")
	rows[1].moves.clear()
	check(not MovementGuideModel.route_choices(state,preferences)[1].moves.is_empty(),"route view rows are detached")
