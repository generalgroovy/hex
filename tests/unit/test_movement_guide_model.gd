extends FluxTestSuite


const MovementGuideModelScript = preload("res://src/presentation/movement_guide_model.gd")


func run() -> int:
	var preferences := PlayerPreferences.new()
	var rows: Array[Dictionary] = MovementGuideModelScript.entries(preferences)
	for evade_id: String in ["roll", "air_dodge"]:
		equal(String(MovementGuideModelScript.entry_by_id(evade_id, preferences)["binding"]), "B", "evade guide follows the current B default")
	for technique_id: String in ["wall_run", "air_turn", "impact_tech"]:
		equal(String(MovementGuideModelScript.entry_by_id(technique_id, preferences)["binding"]), "V", "wall/air/tech guides follow the current V default")
	equal(rows.size(), 16, "guide covers sixteen active movement techniques, not retired vault adapters")
	var ids: Dictionary = {}
	for row: Dictionary in rows:
		var id := String(row.get("id", ""))
		check(not id.is_empty() and not ids.has(id), "guide IDs are stable and unique")
		ids[id] = true
		check(String(row.get("category", "")) in ["travel", "escape", "expression"], "%s belongs to a learning group" % id)
		for key: String in ["title", "binding", "execution", "timing_note", "counter", "state", "directional", "neutral", "steering", "legal_next", "feedback"]:
			check(not String(row.get(key, "")).is_empty(), "%s exposes %s" % [id, key])
		check(not String(row["execution"]).contains("{"), "%s execution resolves actual bindings" % id)
		check(not String(row["timing_note"]).contains("{"), "%s timing notes resolve actual bindings" % id)
		check(int(row.get("cost_milli", -1)) >= 0, "%s has an honest non-negative base cost" % id)
		var lines: Array[String] = MovementGuideModelScript.detail_lines(row)
		check(lines.size() >= 5 and lines.size() <= 6, "%s details fit a bounded bullet list before wrapping" % id)
		for line: String in lines:
			check(line.begins_with("- "), "%s detail is a structured readable bullet" % id)
	check(not ids.has("vault") and not ids.has("superglide"), "retired movement IDs cannot appear as usable skills")
	equal(int(MovementGuideModelScript.entry_by_id("jump")["cost_milli"]), MovementTuning.HOP_COST, "jump cost derives from runtime tuning")
	equal(int(MovementGuideModelScript.entry_by_id("jump")["sustain_milli_per_second"]), MovementTuning.JUMP_SUSTAIN_DRAIN_PER_SECOND, "held jump cost derives from runtime tuning")
	equal(int(MovementGuideModelScript.entry_by_id("slide")["duration_ms"]), MovementTuning.SLIDE_DURATION_MS, "slide duration derives from runtime tuning")
	equal(int(MovementGuideModelScript.entry_by_id("slide")["protection_ms"]), MovementTuning.SLIDE_INVULNERABILITY_MS, "slide protection cannot silently equal total duration")
	equal(int(MovementGuideModelScript.entry_by_id("roll")["protection_ms"]), MovementTuning.ROLL_INVULNERABILITY_MS, "roll protection derives from runtime tuning")
	equal(int(MovementGuideModelScript.entry_by_id("air_dodge")["protection_ms"]), MovementTuning.AIR_DODGE_INVULNERABILITY_MS, "air dodge protection derives from runtime tuning")
	equal(int(MovementGuideModelScript.entry_by_id("wave_dash")["protection_ms"]), 0, "wavedash landing does not promise new immunity")
	equal(int(MovementGuideModelScript.entry_by_id("slide_brake")["cost_milli"]), 0, "slide brake is described as a free cancel")
	equal(MovementGuideModelScript.category_for("jump"), "travel", "jump is taught as core travel")
	equal(MovementGuideModelScript.category_for("roll"), "escape", "roll belongs to defensive escape")
	equal(MovementGuideModelScript.category_for("wave_dash"), "expression", "wavedash belongs to expressive combinations")
	check(String(MovementGuideModelScript.entry_by_id("move")["execution"]).contains("release to coast"), "free aerial momentum is explained explicitly")
	check(String(MovementGuideModelScript.entry_by_id("fast_fall")["execution"]).contains("release and press again"), "carried Slide cannot be mistaken for fresh fast-fall intent")
	check(String(MovementGuideModelScript.entry_by_id("wave_dash")["timing_note"]).contains("No turn-angle requirement"), "guide cannot retain retired angle-gated wavedash instructions")
	check(String(MovementGuideModelScript.entry_by_id("slide_brake")["timing_note"]).contains("wheel notches"), "guide explains wheel gesture safety versus deliberate braking")
	_test_direction_and_neutral_matrix()
	_test_continuous_height_rules()
	equal(int(MovementGuideModelScript.entry_by_id("jump")["commitment_ms"]), MovementTuning.HOP_COMMITMENT_MS, "jump commitment derives from movement authority")
	equal(int(MovementGuideModelScript.entry_by_id("air_dodge")["commitment_ms"]), MovementTuning.AIR_DODGE_COMMITMENT_MS, "air-dodge commitment is not confused with total duration")
	equal(int(MovementGuideModelScript.entry_by_id("slide_brake")["commitment_ms"]), 0, "free slide brake cannot promise a fresh paid commitment")
	check(MovementGuideModelScript.entry_by_id("missing").is_empty(), "unknown technique fails closed")
	check(MovementGuideModelScript.detail_lines({}).is_empty(), "missing technique cannot fabricate details")
	preferences.keyboard_bindings[&"jump"] = KEY_J
	var rebound: Dictionary = MovementGuideModelScript.entry_by_id("jump", preferences)
	equal(String(rebound["binding"]), "J", "guide follows rebound keyboard actions")
	check(String(rebound["execution"]).contains("Tap J"), "execution instructions follow rebinding too")
	preferences.keyboard_bindings[&"jump"] = 0
	equal(String(MovementGuideModelScript.entry_by_id("jump", preferences)["binding"]), "UNBOUND", "missing keyboard action is explicit, not a false default")
	var controller_rows: Array[Dictionary] = MovementGuideModelScript.entries(preferences, ControlBindingEditor.DEVICE_CONTROLLER)
	equal(controller_rows.size(), rows.size(), "controller gets the same complete movement curriculum")
	var state := PlayerState.new(1)
	state.stamina_maximum = 123_000
	state.stamina_recovery_per_second = 31_000
	state.movement_chain_count = 3
	state.movement_chain_reset_ticks = 10
	var summary: Array[String] = MovementGuideModelScript.summary_lines(state)
	check(summary[0].contains("123 maximum") and summary[0].contains("31/s"), "summary uses the selected champion's real Stamina profile")
	check(summary[1].contains("Next premium: 30%"), "summary explains the actual next chain premium")
	check(summary[2].contains("%d ms" % MovementTuning.INPUT_BUFFER_MS) and summary[2].contains("newest"), "buffer explanation derives its timing and explicit intent replacement rule")
	check(" ".join(summary).contains("%d ms without another notch" % InputRouter.WHEEL_GESTURE_QUIET_MS), "wheel instruction follows actual quiet-gap tuning")
	state.movement_chain_reset_ticks = 0
	check(MovementGuideModelScript.summary_lines(state)[1].contains("Next premium: 0%"), "expired movement chain cannot remain expensive in the guide")
	return finish("movement-guide-model")


func _test_direction_and_neutral_matrix() -> void:
	var dodge: Dictionary = MovementGuideModelScript.entry_by_id("air_dodge")
	check(String(dodge.execution).contains("neutral movement") and String(dodge.execution).contains("free vertical fast-fall"), "air guide teaches neutral Evade as free fast fall")
	check(String(dodge.execution).contains("Fresh C") and String(dodge.execution).contains("same free fast-fall alias"), "air guide preserves the established Slide alias")
	check(String(dodge.timing_note).contains("%d ms" % MovementTuning.INPUT_BUFFER_MS) and String(dodge.timing_note).contains("samples current movement direction at admission"), "air guide explains admission-time direction sampling")
	check(String(dodge.timing_note).contains("last airborne tick") and String(dodge.timing_note).contains("does not become a ground roll"), "air guide explains the height-edge admission result")
	check(String(dodge.neutral).contains("spends no Stamina") and String(dodge.neutral).contains("budget and cooldown unchanged"), "neutral air Evade promises no paid dodge side effects")
	check(String(dodge.legal_next).contains("Held Evade does not repeat") and String(dodge.legal_next).contains("drops after grounding"), "guide explains held and stale-buffer behavior")
	check(String(dodge.directional).contains("paid once-per-airtime"), "directional air Evade remains the paid dodge")
	check(String(dodge.feedback).contains("Only directional dodge has opening protection"), "feedback does not grant protection to fast fall")
	var dodge_cells: Array[String] = MovementGuideModelScript.compact_cells(dodge)
	check(dodge_cells[2].contains("dir / 0 neutral") and dodge_cells[4].contains("dir only"), "compact guide scopes paid cost and protection to directional air dodge")
	var fall: Dictionary = MovementGuideModelScript.entry_by_id("fast_fall")
	check(String(fall.neutral).contains("Fresh Slide") and String(fall.steering).contains("Horizontal momentum"), "fast-fall row covers both aliases and retained horizontal control")
	check(String(MovementGuideModelScript.entry_by_id("roll").neutral).contains("movement-facing") and String(MovementGuideModelScript.entry_by_id("roll").neutral).contains("never aim"), "neutral ground roll follows movement-facing fallback")
	check(String(MovementGuideModelScript.entry_by_id("slide").neutral).contains("movement-facing") and String(MovementGuideModelScript.entry_by_id("impact_tech").neutral).contains("movement-facing"), "ground Slide and impact tech expose the same established fallback")
	check(String(MovementGuideModelScript.entry_by_id("jump").neutral).contains("without horizontal impulse"), "neutral Jump carries momentum without a horizontal impulse")
	check(String(MovementGuideModelScript.entry_by_id("air_turn").neutral).contains("refused") and String(MovementGuideModelScript.entry_by_id("air_turn").neutral).contains("spends nothing"), "neutral air Technique fails without cost")
	check(String(MovementGuideModelScript.entry_by_id("wall_run").directional).contains("Along-face") and String(MovementGuideModelScript.entry_by_id("wall_run").neutral).contains("cannot invent"), "wallrun remains constrained by wall geometry")


func _test_continuous_height_rules() -> void:
	var jump := MovementGuideModelScript.entry_by_id("jump")
	var jump_note := String(jump["timing_note"])
	check(jump_note.contains("%s units/s" % String.num(float(MovementTuning.SHORT_HOP_VERTICAL_SPEED) / 1000.0, 1).trim_suffix(".0")), "release instruction derives its upward velocity cap")
	check(jump_note.contains("not remaining flight time"), "jump guide no longer treats release as an artificial landing timer")
	check(jump_note.contains("only ascent pays sustain"), "jump does not advertise paying sustain on descent")
	check(jump_note.contains("Landing refreshes jump readiness"), "ground contact permits the next fresh or buffered jump")
	equal(int(jump["cooldown_ms"]), 0, "guide does not promise a remaining hop cooldown after landing")
	equal(int(MovementGuideModelScript.entry_by_id("slide_jump")["duration_ms"]), MovementTuning.HOP_DURATION_MS, "slide jump advertises the same physical launch, not an older adapter timer")
	equal(MovementGuideModelScript.full_jump_height(), roundi(float(MovementTuning.JUMP_VERTICAL_SPEED) * float(MovementTuning.JUMP_VERTICAL_SPEED) / (2.0 * float(MovementTuning.VERTICAL_GRAVITY))), "full jump height estimate derives from launch and gravity")
	for id: String in ["jump", "slide_jump", "wall_jump"]:
		var row := MovementGuideModelScript.entry_by_id(id)
		var text := " ".join(MovementGuideModelScript.detail_lines(row))
		check(text.contains("nominal"), id + " distinguishes nominal lift cycle from actual airtime")
		check(not text.contains("up to %d ms action" % int(row["duration_ms"])), id + " does not falsely cap flight at its nominal lift duration")
	var second := MovementGuideModelScript.entry_by_id("double_jump")
	check(String(second["title"]).begins_with("Float"), "former second-jump adapter displays current Float vocabulary")
	check(String(second["execution"]).contains("release and press"), "Float requires a fresh intentional airborne jump press")
	check(String(second["execution"]).contains("current height"), "Float holds actual height without inventing a second lift")
	equal(int(second["cost_milli"]), MovementTuning.FLOAT_COST, "Float startup derives from actual tuning")
	equal(int(second["sustain_milli_per_second"]), MovementTuning.FLOAT_DRAIN_PER_SECOND, "Float hold displays actual high Stamina cost")
	equal(int(second["duration_ms"]), 0, "Float is limited by hold and resource instead of a fake fixed duration")
	check(String(second["counter"]).contains("Wall contact does not refill"), "guide cannot promise unlimited Float resets from walls")
	check(String(second["timing_note"]).contains("wall jump -> Float -> air dodge"), "guide teaches the independent legal air chain")
	for duration: int in [MovementTuning.FLOAT_SMALL_DURATION_MS, MovementTuning.FLOAT_MIDDLE_DURATION_MS, MovementTuning.FLOAT_LARGE_DURATION_MS]:
		check(String(second["timing_note"]).contains("%.1fs" % (float(duration) / 1000.0)), "Float guide displays the actual size duration")
	check(String(jump["counter"]).contains("18 units") and String(jump["counter"]).contains("beams"), "low hop teaches projectile clearance without claiming blanket protection")
	var float_details := " ".join(MovementGuideModelScript.detail_lines(second))
	check(float_details.contains("Protected only while Float is active and paid"), "Float protection is continuous only during its paid hold")
	check(not float_details.contains("no new immunity"), "generic guide fallback cannot contradict Float protection")
	var common_rules := " ".join(MovementGuideModelScript.summary_lines())
	check(common_rules.contains("Float is the explicit exception"), "shared opening-only rule explicitly excludes protected Float")
	check(common_rules.contains("independently ramp recovery") and common_rules.contains("3.0 seconds"), "guide teaches source-derived independent quiet recovery")
	check(common_rules.contains("positive spend resets only that resource"), "guide explains independent reset and rejects free-action penalties")
	var dodge := MovementGuideModelScript.entry_by_id("air_dodge")
	check(String(dodge["timing_note"]).contains("One air dodge per airtime"), "air-dodge budget is a once-per-airtime opportunity")
	check(String(dodge["timing_note"]).contains("without a cooldown wait"), "landing refills air dodge independently from ground roll cooldown")
	equal(int(dodge["cooldown_ms"]), 0, "guide does not retain the retired air-dodge shared cooldown")
	equal(int(MovementGuideModelScript.entry_by_id("wave_dash")["cooldown_ms"]), 0, "landing-dash guide follows the same air-dodge readiness")
	check(String(dodge["timing_note"]).contains("preserving height and vertical motion"), "air dodge does not fabricate another jump arc")
	check(String(dodge["timing_note"]).contains("steerable flight"), "air-dodge burst is followed by controllable flight")
	check(String(dodge["counter"]).contains("Directional dodge protection ends immediately on landing"), "guide promises no lingering directional-dodge immunity")
	check(String(MovementGuideModelScript.entry_by_id("wave_dash")["timing_note"]).contains("While descending"), "wavedash instruction checks descent instead of only old hop timer")
	check(String(MovementGuideModelScript.entry_by_id("wall_run")["timing_note"]).contains("does not refill"), "wallrun explicitly preserves spent air budgets")
	var fall_note := String(MovementGuideModelScript.entry_by_id("fast_fall")["timing_note"])
	check(fall_note.contains("%s units/s" % String.num(float(MovementTuning.AIR_FAST_FALL_SPEED) / 1000.0, 1).trim_suffix(".0")), "fast fall describes source-derived real vertical speed")
	check(not fall_note.contains("flight tick"), "fast fall no longer describes a presentation-era arc counter")
