class_name MovementGuideModel
extends RefCounted


# Read-only guide data. Rules and costs remain owned by MovementSystem/Tuning;
# the overlay may paginate/wrap these rows without inventing gameplay state.
static func entries(preferences: PlayerPreferences = null, device: int = ControlBindingEditor.DEVICE_KEYBOARD) -> Array[Dictionary]:
	var current := preferences if preferences != null else PlayerPreferences.new()
	var editor := ControlBindingEditor.new()
	var bindings: Dictionary = {}
	for action: StringName in [&"jump", &"slide", &"sprint", &"evade", &"technique", &"move_up", &"move_left", &"move_down", &"move_right", &"practice_trace", &"practice_retry"]:
		var label := editor.binding_label(action, device, current)
		bindings[String(action)] = "UNBOUND" if label == "—" else label
	bindings["move"] = "%s / %s / %s / %s" % [bindings["move_up"], bindings["move_left"], bindings["move_down"], bindings["move_right"]]
	var rows: Array[Dictionary] = [
		_row("move", "Move / brake", "move", 0,
			"Hold {move}; combine directions for diagonals. On the ground release to brake. In air release to coast, steer to turn, or press against travel to brake.",
			"Ordinary movement stays available at zero Stamina. Aim remains independent of travel. Toggle practice trace with {practice_trace}; restart it with {practice_retry} to compare speed, Stamina and your next chain premium.",
			{}, "No protection; read and leave incoming projectile lanes."),
		_row("sprint", "Sprint", "sprint", 0,
			"Hold {sprint} while moving. Release it to stop paying the sprint drain.",
			"Targets %.1fx walk speed. Drains Stamina only while moving; release carries excess speed down naturally. Opposite movement brakes harder; empty reserves cannot buy more sprint speed." % (float(MovementTuning.SPRINT_MULTIPLIER) / 1000.0),
			{"sustain_milli_per_second": MovementTuning.SPRINT_DRAIN_PER_SECOND}, "No protection; predict the longer travel lane."),
		_row("jump", "Press / release jump", "jump", MovementTuning.HOP_COST,
			"Press {jump} to prepare a jumpsquat; release to launch. Held preparation gradually brakes momentum for a bounded stronger jump. A complete tap carries momentum; steer, coast or counter-steer after takeoff.",
			"Jumpsquat remains grounded and vulnerable. A quick tap still jumps. No automatic repeat or free charge; landing restores air opportunities.",
			{"protection_note": "Height clearance, not immunity: above %s units avoids ordinary projectiles and ground-contact effects." % _units(MovementTuning.GROUND_PROJECTILE_CLEARANCE_HEIGHT), "protection_label": "Height clearance"},
			"Takeoff and landing remain vulnerable below clearance. Existing timed statuses are not cleansed; tall hazards can still reach you."),
		_row("double_jump", "Double jump / racial flight", "jump", MovementTuning.FLOAT_COST,
			"Every race first jumps normally: press then release {jump} on the ground. In air, press {jump} again for one double jump. Sylphs, Wyrmborn, Angels and Demons use that deliberate second press and hold to fly; release to descend. Steer and cast independently.",
			"Flight is finite and paid. It ends on release, exhaustion or expiry; wall contact does not refill the air budget. After a dodge discards held {jump}, or a wallrun consumes it, release and press {jump} again to fly. Other races cannot Float.",
			{"sustain_milli_per_second": MovementTuning.FLOAT_DRAIN_PER_SECOND, "protection_note": "Only actual height avoids ground effects/projectiles; flight grants no universal immunity.", "protection_label": "Height clearance"},
			"Plan a safe landing. Double jump, flight and air dodge are finite opportunities, not repeatable resource resets."),
		_row("slide", "Slide / held slide", "slide", MovementTuning.SLIDE_COST,
			"Build ground speed, then press {slide} for a paid boost along the incoming travel lane. Side input carves; opposite input brakes. Speed lost in a turn stays lost. Near landing, fresh {slide} fast-falls and buffers one paid slide. Hold for the longer slide or release for the shorter remainder.",
			"Needs %s units/s; adds %s up to the %s speed cap. Landing buffer lasts %d ms and rechecks cost, speed and cooldown. During an air dodge, Slide only fast-falls into the existing wavedash route. Release limits slide remainder to %d ms." % [_units(MovementTuning.SLIDE_ENTRY_SPEED), _units(MovementTuning.SLIDE_ENTRY_BOOST), _units(MovementTuning.MAX_AUTHORED_SPEED), MovementTuning.INPUT_BUFFER_MS, MovementTuning.SLIDE_MINIMUM_MS],
			{"duration_ms": MovementTuning.SLIDE_DURATION_MS, "cooldown_ms": MovementTuning.SLIDE_COOLDOWN_MS, "sustain_milli_per_second": MovementTuning.SLIDE_SUSTAIN_DRAIN_PER_SECOND, "protection_note": "Low profile passes under ordinary projectiles, never ground effects.", "protection_label": "Low profile"},
			"Fire and other ground-contact effects still affect crouching/sliding characters."),
		_row("slide_brake", "Slide brake", "slide", 0,
			"Release and press {slide} again during the slide to stop immediately.",
			"Free cancellation; does not refund cost or cooldown. Repeated wheel notches in one gesture do not count as deliberate second presses.", {},
			"Braking ends the slide lane; choose a safe stopping point away from ground effects."),
		_row("slide_jump", "Slide jump", "jump", MovementTuning.SLIDE_JUMP_COST,
			"While sliding, press then release {jump} after the minimum commitment. A complete tap carries momentum; holding Jump gradually brakes for charge, then release carries the remaining velocity.",
			"Available after %d ms of accepted slide time, even while {slide} is held. Held preparation ends slide sustain, not its cooldown or paid jump family; travel slows naturally." % MovementTuning.SLIDE_JUMP_MINIMUM_COMMITMENT_MS,
			{"protection_note": "Only actual height grants ground/projectile clearance.", "protection_label": "Height clearance"},
			"Costs another paid action and chain premium; anticipation and landing remain vulnerable."),
		_row("roll", "Ground roll", "evade", MovementTuning.ROLL_COST,
			"On the ground, press {evade} with a direction. Use a neutral direction only when your facing is the intended escape.",
			"Ground roll has its own cooldown. Air dodge uses a separate once-per-airtime opportunity.",
			{"duration_ms": MovementTuning.ROLL_DURATION_MS, "cooldown_ms": MovementTuning.ROLL_COOLDOWN_MS, "protection_ms": MovementTuning.ROLL_INVULNERABILITY_MS},
			"The end of the roll is vulnerable; do not roll into the next projectile."),
		_row("air_dodge", "Air dodge / neutral fast fall", "evade", MovementTuning.AIR_DODGE_COST,
			"While airborne or wallrunning, press {evade}. With movement direction, it attempts a paid air dodge. With neutral movement, it detaches wallrun, ends flight and takes the free vertical fast-fall path. Fresh {slide} also descends, with a separate paid landing-slide buffer outside active dodges.",
			"Buffered Evade samples current movement direction at admission for up to %d ms. One air dodge per airtime is available with direction. Its burst decays, preserving height and vertical motion, then returns to steerable flight; landing refills it without a cooldown wait and wall contact does not. An old airborne Evade is dropped after grounding. Neutral Evade on the last airborne tick fast-falls before landing; it does not become a ground roll." % MovementTuning.INPUT_BUFFER_MS,
			{"duration_ms": MovementTuning.AIR_DODGE_DURATION_MS, "protection_ms": MovementTuning.AIR_DODGE_INVULNERABILITY_MS, "cost_scope": "Directional air dodge cost", "protection_scope": "Directional air dodge protection"},
			"Directional dodge protection ends immediately on landing. Neutral fast fall adds no protection, spends no Stamina, and resets no air budget or cooldown."),
		_row("wave_dash", "Wavedash", "evade", MovementTuning.AIR_DODGE_COST,
			"Near landing, press {evade} with the direction you want to travel; the dodge resolves into a low landing dash.",
			"While descending, accept the dodge within an estimated %d ms of landing. No turn-angle requirement or extra cost; it uses your one air dodge." % MovementTuning.WAVE_DASH_INPUT_WINDOW_MS,
			{"duration_ms": MovementTuning.WAVE_DASH_DURATION_MS},
			"The landing dash grants no new protection; an early input gives an ordinary air dodge."),
		_row("air_turn", "Air turn", "technique", MovementTuning.AIR_REDIRECT_COST,
			"During a jump, press {technique} with a changed direction for a stronger immediate turn. At a wall, along-wall input chooses a valid wallrun; an unavailable wallrun can fall back to a legal air turn.",
			"One redirect per jump stage. After air-dodge commitment, this turns the remaining dodge without extending its timer or protection. Ordinary steering is free; straight-ahead input spends nothing.", {},
			"No new protection; predict the redirected path."),
		_row("wall_run", "Held wallrun", "jump", MovementTuning.WALL_SKIM_COST,
			"In air near a runnable wall, hold {jump} and movement along its face. Release {jump} to walljump; steer away or reach the wall end to detach.",
			"Wallrun takes priority over racial flight near eligible geometry. Wall contact refills no air budget. Same-surface lockout: %d ms." % MovementTuning.WALL_SKIM_SAME_SURFACE_LOCKOUT_MS,
			{"duration_ms": MovementTuning.WALL_SKIM_DURATION_MS, "cooldown_ms": MovementTuning.WALL_SKIM_COOLDOWN_MS},
			"No protection. Follow the exposed wall lane or threaten its exit."),
		_row("wall_jump", "Wall jump", "jump", MovementTuning.HOP_COST,
			"Release {jump} during wallrun to kick in movement direction, constrained outward from the wall. Without movement, the wall normal supplies a safe outward direction, never cursor aim.",
			"Same-wall lockout %d ms. Retains useful momentum; another wallrun, unused racial flight/double jump, air dodge and casting can chain when legal." % MovementTuning.SAME_WALL_LOCKOUT_MS,
			{"protection_note": "Clearance begins only above the height threshold, not on button release.", "protection_label": "Height clearance"},
			"Re-arm deliberately between wall chains; held input cannot grant infinite climbing."),
		_row("fast_fall", "Fast fall", "slide", 0,
			"After takeoff, press {slide} afresh to commit to an earlier landing. If you were already holding Slide before jumping, release and press again first. Neutral {evade} takes the same free vertical path; held Evade does not repeat it.",
			"A fresh Slide also buffers a paid landing slide for %d ms outside an active air dodge; neutral Evade descends without that purchase. Sets downward speed to at least %s units/s; ordinary gravity continues to real contact. Ends flight without clearing spent air budgets." % [MovementTuning.INPUT_BUFFER_MS, _units(MovementTuning.AIR_FAST_FALL_SPEED)],
			{}, "No new protection; land earlier only if the floor lane is safe."),
		_row("landing_cut", "Landing reversal", "move", 0,
			"Press against your current travel immediately after landing for a firmer reversal.",
			"Landing window: %d ms; multiplies counter-steer acceleration by %.2f, not top speed." % [MovementTuning.LANDING_WINDOW_MS, float(MovementTuning.LANDING_CUT_MULTIPLIER) / 1000.0],
			{}, "Free braking response, not an attack cancel or invulnerability window."),
		_row("impact_tech", "Impact recovery tech", "technique", MovementTuning.IMPACT_RECOVERY_TECH_COST,
			"After an external launch, press {technique} near landing or during the recovery brace, with your exit direction.",
			"Cancels the %d ms recovery brace when legal. Holding direction during launch also bends its path for free." % MovementTuning.IMPACT_RECOVERY_DURATION_MS,
			{}, "No new protection. Without enough Stamina, expect the full recovery brace."),
	]
	for row: Dictionary in rows:
		row["category"] = category_for(String(row["id"]))
		row.merge(_intent_for(String(row["id"])))
		row["binding"] = bindings[String(row["action"])]
		for key: String in ["execution", "timing_note"]:
			var value := String(row[key])
			for action: String in bindings:
				value = value.replace("{%s}" % action, String(bindings[action]))
			row[key] = value
	return rows


static func entry_by_id(id: String, preferences: PlayerPreferences = null, device: int = ControlBindingEditor.DEVICE_KEYBOARD) -> Dictionary:
	for row: Dictionary in entries(preferences, device):
		if String(row["id"]) == id:
			return row
	return {}


static func detail_lines(row: Dictionary) -> Array[String]:
	if row.is_empty():
		return []
	var result: Array[String] = ["- %s / Execute: %s" % [String(row.get("category", "travel")).capitalize(), String(row.get("execution", ""))]]
	var cost_scope := String(row.get("cost_scope", "Cost"))
	var cost := _units(int(row.get("cost_milli", 0))) + " Stamina base"
	var sustain := int(row.get("sustain_milli_per_second", 0))
	if sustain > 0:
		cost += "; +%s/s while sustaining" % _units(sustain)
	result.append("- %s: %s." % [cost_scope, cost])
	var timing: Array[String] = []
	if int(row.get("commitment_ms", 0)) > 0:
		timing.append("%d ms initial commitment" % int(row["commitment_ms"]))
	if int(row.get("duration_ms", 0)) > 0:
		var duration_note := String(row.get("duration_note", ""))
		timing.append("%d ms %s" % [int(row["duration_ms"]), duration_note] if not duration_note.is_empty() else "up to %d ms action" % int(row["duration_ms"]))
	if int(row.get("cooldown_ms", 0)) > 0:
		timing.append("%d ms cooldown" % int(row["cooldown_ms"]))
	if not timing.is_empty():
		result.append("- Timing: " + "; ".join(timing) + ".")
	result.append("- Rule: " + String(row.get("timing_note", "")))
	var protection := int(row.get("protection_ms", 0))
	var protection_note := String(row.get("protection_note", ""))
	if not protection_note.is_empty():
		result.append("- Protection: " + protection_note)
	else:
		var protection_scope := String(row.get("protection_scope", "Protection"))
		result.append("- %s: opening %d ms only; the rest is vulnerable." % [protection_scope, protection] if protection > 0 else "- Protection: no new immunity from this technique.")
	result.append("- Counter / caution: " + String(row.get("counter", "")))
	return result


static func compact_cells(row: Dictionary) -> Array[String]:
	if row.is_empty():
		return []
	var protection := "%d ms opening" % int(row.protection_ms) if int(row.protection_ms) > 0 else "None added"
	var cost := _units(int(row.cost_milli))
	if not String(row.get("cost_scope", "")).is_empty():
		cost += " dir / 0 neutral"
		protection = "%d ms dir only" % int(row.protection_ms)
	if not String(row.get("protection_note", "")).is_empty():
		protection = String(row.get("protection_label", "See rule"))
	var cooldown := "%d ms" % int(row.cooldown_ms) if int(row.cooldown_ms) > 0 else "See rule"
	return [String(row.title), String(row.binding), cost, _units(int(row.sustain_milli_per_second)) + "/s", protection, cooldown]


static func summary_lines(state: PlayerState = null) -> Array[String]:
	var maximum := state.stamina_maximum if state != null else MovementTuning.STAMINA_MAXIMUM
	var recovery := state.stamina_recovery_per_second if state != null else MovementTuning.STAMINA_RECOVERY_PER_SECOND
	var steps := mini(state.movement_chain_count, MovementTuning.MOVEMENT_CHAIN_MAXIMUM_STEPS) if state != null and state.movement_chain_reset_ticks > 0 else 0
	var step_percent := roundi(float(MovementTuning.MOVEMENT_CHAIN_COST_STEP_RATIO) / 10.0)
	return [
		"Stamina %s maximum; base recovery %s/s, rising to %s/s after its %d ms spend delay when ordinary movement allows refill." % [_units(maximum), _units(recovery), _units(recovery * PlayerTuning.RESOURCE_RECOVERY_MAXIMUM_RATIO / 1000), MovementTuning.STAMINA_RECOVERY_DELAY_MS],
		"Costs shown are base. Each paid continuation adds %d%%, capped at %d%%; resets after %d ms. Next premium: %d%%." % [step_percent, step_percent * MovementTuning.MOVEMENT_CHAIN_MAXIMUM_STEPS, MovementTuning.MOVEMENT_CHAIN_RESET_MS, steps * step_percent],
		"The newest movement tap replaces older intent for up to %d ms; legal state, cooldown and Stamina are checked again. One paid action starts per tick; a refused move spends nothing." % MovementTuning.INPUT_BUFFER_MS,
		"For simultaneous movement presses, priority is Evade, then Jump, Slide, Technique. Initial commitment is the short interval before another action can replace the current one, not a new immunity window.",
		"Airborne Evade reads current movement at admission: direction buys air dodge; neutral fast-falls freely with no landing purchase. Fresh Slide fast-falls and buffers one paid landing slide for %d ms outside active dodges. Held inputs do not repeat." % MovementTuning.INPUT_BUFFER_MS,
		"Flux pays for spells; movement uses Stamina. High clears ordinary projectiles and ground effects; low clears ordinary projectiles only. Standing and wallrunning evade neither. Shield brackets mean timed dodge/spawn immunity, not height.",
		"Learn Travel first: move, sprint, press/release jump, slide. Then Escape: roll, air dodge, fast fall. Expression adds double jump or racial flight, held wallruns, release walljumps, turns and wavedashes.",
		"Wheel movement is a short pulse, not a hold. Same-direction notches group until %d ms without another notch; use buttons for precise second presses or sustained height and distance." % InputRouter.WHEEL_GESTURE_QUIET_MS,
		"Hold drain and sprint cost are additional to base cost; chain premiums apply to paid starts. Flight spends Stamina and a finite air budget but never grants universal immunity.",
		"Unused Flux and Stamina independently ramp recovery from 1x to %.0fx over %.1f seconds after their own delay. Any positive spend resets only that resource's ramp; failed and free actions do not. Health recovery is unchanged." % [float(PlayerTuning.RESOURCE_RECOVERY_MAXIMUM_RATIO) / 1000.0, float(PlayerTuning.RESOURCE_RECOVERY_RAMP_MS) / 1000.0],
		"Unbound action? Assign it at the Controls Lectern. Vault and crest-superglide are not active techniques.",
	]


static func category_for(id: String) -> String:
	if id in ["move", "sprint", "jump", "slide"]:
		return "travel"
	if id in ["roll", "air_dodge", "fast_fall", "impact_tech"]:
		return "escape"
	return "expression"


static func _intent_for(id: String) -> Dictionary:
	match id:
		"move":
			return _intent("Ground or air while ordinary movement is legal.", "Held movement chooses cardinal or diagonal travel.", "Release: brake on ground and coast in air.", "Ground movement accelerates or brakes; air movement steers or counter-steers without changing aim.", "Fresh paid movement still needs its own state, commitment and Stamina gate.", "Travel direction and speed change; practice trace reads MOVE or RELEASE.")
		"sprint":
			return _intent("While ordinary movement accepts held Sprint and a movement direction.", "Sprint follows current movement direction.", "Sprint held without movement adds no travel and pays no drain.", "Change movement normally; release Sprint to return to ordinary speed and cost.", "Jump, Slide, Evade and Technique retain their normal admission gates.", "Higher travel speed and live Stamina drain distinguish accepted Sprint.")
		"jump":
			return _intent("On legal ground, press prepares; release launches.", "Held preparation gradually brakes existing travel without acceleration or a direction snap. Steering resumes after release.", "Neutral release carries the remaining velocity; a complete tap carries existing momentum.", "Hold moving anticipation for bounded charge. External pushes still act; steer or coast after release.", "Fresh legal air movement is checked normally; no automatic repeat jump.", "Gather then lift confirm admission. Up chevron means height clearance, not immunity.")
		"double_jump":
			return _intent("After the ordinary first ground jump, airborne with the second air opportunity unused.", "Movement steers horizontal momentum independently of the upward jump or flight.", "Neutral direction preserves coast; a deliberate second Jump double-jumps, or begins paid held flight for capable races.", "Flight holds height only while paid and within its finite budget; release descends.", "Wall contact cannot refresh consumed air opportunities.", "A second lift or actual held flight with a budget meter confirms admission; only clearance avoids low threats.")
		"slide":
			return _intent("On ground with fresh Slide; a fresh air Slide outside an active dodge may buffer the landing purchase for %d ms." % MovementTuning.INPUT_BUFFER_MS, "Incoming velocity sets the boosted slide lane; movement carves without instantly redirecting earned speed.", "Neutral Slide keeps actual travel, never stale facing or aim direction.", "The lane is committed; hold extends the paid remainder and release shortens it. Every boost pays cost and cooldown.", "After minimum commitment, fresh Slide brakes; a Jump tap carries through, while held Jump gradually brakes for charge.", "Low body and downward chevron mean ordinary projectiles pass above; ground effects still hit.")
		"slide_brake":
			return _intent("During active Slide after release and a fresh second Slide press.", "Supplied direction is ignored by the brake.", "Neutral and directional second presses stop the same slide.", "Braking ends the committed lane instead of steering it.", "Later actions use ordinary state, cooldown, commitment and resource gates.", "The slide stops and protection ends; no cost or cooldown is refunded.")
		"slide_jump":
			return _intent("During Slide after minimum commitment, press then release Jump.", "A complete tap carries the slide vector; held Jump gradually brakes it before ordinary air steering resumes.", "Neutral tap carries the current slide lane; held release carries the remaining velocity.", "Holding brakes without refunding Slide or its cooldown. After takeoff, ordinary air steering and coasting apply.", "Legal double jump or racial flight, fast fall, air dodge and wall actions stay independently gated.", "Lift grants clearance only after crossing the threshold; anticipation is vulnerable.")
		"roll":
			return _intent("On legal ground with Roll cooldown ready and a paid Evade accepted.", "Current movement chooses the roll lane.", "Neutral Evade rolls along movement-facing fallback, never aim direction.", "The admitted roll lane is committed until ordinary control returns.", "A later action must pass commitment and its own state, cooldown and Stamina gates.", "The burst and opening protection confirm Roll; its ending is vulnerable.")
		"air_dodge":
			return _intent("Airborne or wallrunning when fresh or buffered Evade is admitted; current direction is sampled then.", "Non-zero movement attempts the paid once-per-airtime directional dodge.", "Zero movement takes free vertical fast fall, ends flight and preserves spent air budgets and cooldowns.", "Directional burst decays into steerable air travel; neutral keeps horizontal coast while forcing descent.", "Fresh paid actions stay gated. Held Evade does not repeat; buffered airborne Evade drops after grounding.", "AIR DODGE marks the paid burst; FAST FALL marks neutral Evade. Only directional dodge has opening protection.")
		"wave_dash":
			return _intent("Descending near legal ground within the landing estimate, with air dodge available.", "Non-zero current movement chooses the low landing-dash lane.", "Neutral Evade takes free fast fall instead of wavedash.", "The landing dash has limited steering after admission.", "Fresh later actions retain landing state, commitment and their own gates.", "WAVEDASH and the low lane confirm conversion; it grants no new protection.")
		"air_turn":
			return _intent("During a jump stage with redirect available and a fresh paid Technique.", "A changed non-zero direction purchases the sharper correction.", "Neutral Technique is refused as an air redirect and spends nothing.", "Ordinary air steering stays free before and after the sharp turn.", "Another redirect needs a new jump stage; wall geometry may admit wallrun instead.", "A sharp path change and Stamina spend confirm admission; no protection is added.")
		"wall_run":
			return _intent("Airborne near runnable geometry, holding Jump with wallrun gates ready.", "Along-face movement admits wallrun; away movement detaches.", "Neutral movement cannot invent a wallrun lane.", "Hold Jump along the wall; release Jump kicks outward, wall end or expiry detaches.", "Re-arm deliberately; used air opportunities stay consumed.", "WALLRUN, running legs and contact sparks confirm admission; no height avoidance or immunity.")
		"wall_jump":
			return _intent("During accepted wallrun, release Jump.", "Movement chooses the kick direction, constrained safely outward from the wall.", "Neutral release uses the outward wall normal, not cursor aim.", "Retain tangential momentum and steer freely after launch.", "Unused extra air action and air dodge remain available; same-wall lockout prevents infinite climbing.", "Contact burst and outward lift confirm release; clearance depends on actual height.")
		"fast_fall":
			return _intent("Airborne on fresh Slide, or on Evade admitted with zero current movement.", "Direction does not bend fast fall; directional airborne Evade attempts paid air dodge.", "Neutral Evade takes this free path. Fresh Slide takes it regardless of movement direction.", "Horizontal momentum keeps ordinary coast and air steering while vertical speed is forced down.", "Fresh paid actions stay gated; fast fall spends no air-dodge opportunity and resets no cooldown.", "FAST FALL and earlier descent confirm admission; flight ends and no new immunity begins.")
		"landing_cut":
			return _intent("Immediately after landing within the source-derived landing window.", "Movement against current travel activates stronger reversal acceleration.", "Neutral movement does not create reversal; ordinary ground braking applies.", "Counter-steer chooses the reverse lane but does not increase top speed.", "Fresh actions retain their normal ground state and gates.", "A firmer reversal confirms the cut; it adds no protection or attack cancel.")
		"impact_tech":
			return _intent("After external launch, near landing or during legal recovery with enough Stamina.", "Current movement chooses the recovery exit.", "Neutral Technique uses movement-facing fallback for the exit, never aim direction.", "Held movement can bend the launch path for free before a paid legal cancel.", "Fresh later actions retain the resulting state and their own costs.", "The brace ends into the chosen exit on acceptance; no protection is added.")
	return {}


static func _intent(state: String, directional: String, neutral: String, steering: String, legal_next: String, feedback: String) -> Dictionary:
	return {"state": state, "directional": directional, "neutral": neutral, "steering": steering, "legal_next": legal_next, "feedback": feedback}


static func _row(id: String, title: String, action: String, cost: int, execution: String, timing_note: String, timing: Dictionary, counter: String) -> Dictionary:
	var result := {"id": id, "title": title, "action": action, "cost_milli": cost, "execution": execution, "timing_note": timing_note, "counter": counter, "duration_ms": 0, "cooldown_ms": 0, "protection_ms": 0, "sustain_milli_per_second": 0, "commitment_ms": commitment_ms_for(id)}
	result.merge(timing, true)
	return result


static func commitment_ms_for(id: String) -> int:
	match id:
		"jump", "double_jump", "slide_jump", "wall_jump", "air_turn", "impact_tech":
			return MovementTuning.HOP_COMMITMENT_MS
		"slide":
			return MovementTuning.SLIDE_JUMP_MINIMUM_COMMITMENT_MS
		"roll":
			return MovementTuning.ROLL_COMMITMENT_MS
		"air_dodge":
			return MovementTuning.AIR_DODGE_COMMITMENT_MS
		"wall_run":
			return MovementTuning.WALL_RUN_COMMITMENT_MS
		"wave_dash":
			return MovementTuning.WAVE_DASH_COMMITMENT_MS
	return 0


static func _units(value: int) -> String:
	return ("%.1f" % (float(value) / 1000.0)).trim_suffix(".0")


static func full_jump_height() -> int:
	# A guide estimate, not an alternative simulation; fixed ticks can differ slightly.
	return roundi(float(MovementTuning.JUMP_VERTICAL_SPEED) * float(MovementTuning.JUMP_VERTICAL_SPEED) / (2.0 * float(MovementTuning.VERTICAL_GRAVITY)))
