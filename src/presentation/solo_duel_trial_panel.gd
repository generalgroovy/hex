extends RefCounted

const Run = preload("res://src/app/solo_duel_trial.gd")
const ENTRY := Rect2(20, 196, 226, 30)
const LIVE := Rect2(20, 88, 316, 150)
const LEAVE := Rect2(32, 206, 292, 24)
const PANEL := Color("111b20f5")
const PAPER := Color("e2d8b2")
const CYAN := Color("55dbe0")
const MUTED := Color("b6a477")
const BODY_FIRST_BASELINE := 68.0
const BODY_LINE_STEP := 25.0
const RivalPolicy = preload("res://src/app/solo_duel_rival.gd")


static func heavy_tell_segments(phase: String, rival_status: Dictionary, inside_court: bool, alive: bool) -> int:
	# A warning of intent, not guaranteed admission, range or a safe direction.
	if phase != Run.ACTIVE or not inside_court or not alive:
		return 0
	if String(rival_status.get("phase", "")) != RivalPolicy.WINDUP or String(rival_status.get("telegraph", "")) != "heavy":
		return 0
	var remaining := clampi(int(rival_status.get("remaining_ticks", 0)), 0, RivalPolicy.WINDUP_TICKS)
	return ceili(float(remaining) * 6.0 / float(RivalPolicy.WINDUP_TICKS))


static func draw_heavy_tell(canvas: CanvasItem, body_position: Vector2, segments: int) -> void:
	if segments <= 0: return
	draw_world_tell(canvas, body_position, {"kind": "heavy", "label": "HEAVY", "segments": mini(segments, 6)})


static func world_tell(phase: String, rival_status: Dictionary, inside_court: bool, alive: bool, cast_busy: bool = false) -> Dictionary:
	if phase != Run.ACTIVE or not inside_court or not alive or bool(rival_status.get("complete", false)):
		return {}
	var heavy_segments := heavy_tell_segments(phase, rival_status, inside_court, alive)
	if heavy_segments > 0 and not bool(rival_status.get("break", false)):
		return {"kind": "heavy", "label": "HEAVY", "segments": heavy_segments}
	# PAUSE describes the rival's no-new-casts beat, not player safety or a
	# vulnerability modifier. Paid startups/recovery and lingering shots remain
	# real; the caller withholds this cue while the actual caster is still busy.
	if cast_busy or String(rival_status.get("phase", "")) != RivalPolicy.RECOVER:
		return {}
	if typeof(rival_status.get("telegraph")) != TYPE_STRING or rival_status.telegraph != "" \
			or typeof(rival_status.get("break")) != TYPE_BOOL or not rival_status["break"] \
			or typeof(rival_status.get("complete")) != TYPE_BOOL or rival_status.complete \
			or typeof(rival_status.get("remaining_ticks")) != TYPE_INT:
		return {}
	var remaining := int(rival_status.remaining_ticks)
	if remaining <= 0 or remaining > RivalPolicy.RECOVERY_TICKS:
		return {}
	var segments := ceili(float(remaining) * 6.0 / float(RivalPolicy.RECOVERY_TICKS))
	return {"kind": "pause", "label": "PAUSE", "segments": segments}


static func world_tell_box(body_position: Vector2) -> Rect2:
	# The ordinary nameplate occupies y[-77,-60] relative to the actor's feet.
	# Leave16 world pixels (12 screen pixels at fixed75%) above that plate.
	return Rect2((body_position + Vector2(-40, -123)).round(), Vector2(80, 30))


static func draw_world_tell(canvas: CanvasItem, body_position: Vector2, tell: Dictionary) -> void:
	var kind := String(tell.get("kind", ""))
	var label := "HEAVY" if kind == "heavy" else "PAUSE" if kind == "pause" else ""
	if canvas == null or label.is_empty() or String(tell.get("label", "")) != label \
			or typeof(tell.get("segments")) != TYPE_INT:
		return
	var segments := int(tell.segments)
	if segments <= 0 or segments > 6: return
	# Same static, high-contrast treatment in Normal and Reduced Effects. The
	# world actor visibility gate and subsequent POV mask also cover this badge.
	# Both phases reuse one footprint; no extra panel, pulse or safe-green cue.
	var box := world_tell_box(body_position)
	var warning := Color("ffd276") if kind == "heavy" else CYAN
	var empty := Color("515044") if kind == "heavy" else Color("3c5155")
	canvas.draw_rect(box, PANEL)
	canvas.draw_rect(box, warning, false, 1.0)
	var text_width := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	_text(canvas, box.position + Vector2((80.0 - text_width) * 0.5, 16), label, 14, warning, 76)
	for index: int in 6:
		canvas.draw_rect(Rect2(box.position + Vector2(5 + index * 12, 22), Vector2(10, 3)), warning if index < segments else empty)


static func geometry(viewport: Vector2) -> Dictionary:
	var size := Vector2(minf(620.0, viewport.x - 32.0), minf(430.0, viewport.y - 32.0))
	var panel := Rect2(((viewport - size) * 0.5).round(), size)
	var width := (size.x - 48.0) * 0.5
	return {"panel": panel,
		"primary": Rect2(panel.position + Vector2(16, size.y - 58), Vector2(width, 38)),
		"secondary": Rect2(panel.position + Vector2(32 + width, size.y - 58), Vector2(width, 38))}


static func result_title(phase: String) -> String:
	return {Run.VICTORY:"TRIAL CLEARED", Run.DEFEATED:"DEFEATED", Run.TIMEOUT:"TIME EXPIRED", Run.LEFT_COURT:"LEFT THE COURT", Run.UNAVAILABLE:"TRIAL INTERRUPTED"}.get(phase, "WELLSPRING DUEL TRIAL")


static func intent(event: InputEvent, pointer: Vector2, viewport: Vector2, selected: int) -> String:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE: return "cancel"
			KEY_TAB, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN: return "toggle"
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: return "primary" if selected == 0 else "secondary"
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_B, JOY_BUTTON_BACK: return "cancel"
			JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN: return "toggle"
			JOY_BUTTON_A: return "primary" if selected == 0 else "secondary"
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var boxes := geometry(viewport)
		for action: String in ["primary", "secondary"]:
			if (boxes[action] as Rect2).has_point(pointer): return action
	return ""


static func draw_entry(canvas: CanvasItem) -> void:
	canvas.draw_rect(ENTRY, PANEL)
	_text(canvas, ENTRY.position + Vector2(10, 20), "SOLO DUEL TRIAL", 12, PAPER, ENTRY.size.x - 20)


static func pressure_hint(view: Dictionary, rival_status: Dictionary = {}) -> String:
	# Consume the same policy status that supplies rival commands. No local clock,
	# second attack schedule, or claim that recovery clears existing projectiles.
	if String(view.get("phase", "")) == Run.READY:
		return "READY IN %d" % ceili(float(view.get("countdown_ticks", 0)) / 120.0)
	if bool(view.get("finished", false)):
		return "TRIAL COMPLETE"
	match String(rival_status.get("phase", "")):
		"windup":
			if String(rival_status.get("telegraph", "")) == "heavy":
				return "HEAVY INCOMING · Sidestep / cover"
		"pressure":
			if String(rival_status.get("telegraph", "")) == "volley":
				return "VOLLEY · Move between shots"
		"recover":
			return "OPENING · Attack or recover Flux"
	return "Attack, reposition, and watch your Flux."


static func draw_live(canvas: CanvasItem, run: RefCounted, rival_status: Dictionary = {}) -> void:
	var view: Dictionary = run.view()
	canvas.draw_rect(LIVE, PANEL)
	canvas.draw_rect(Rect2(LIVE.position, Vector2(3, LIVE.size.y)), CYAN)
	var left := LIVE.position + Vector2(12, 22)
	_text(canvas, left, "DUEL TRIAL   %.1fs" % (float(view.remaining_ticks) / 120.0), 15, PAPER, 292)
	_text(canvas, left + Vector2(0, 22), "Defeat Oh Tipi before time runs out.", 12, MUTED, 292)
	var bar := Rect2(left + Vector2(0, 34), Vector2(292, 7))
	canvas.draw_rect(bar, Color("495052"))
	canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(view.opponent_health) / float(view.opponent_health_maximum), 0, 1), 7)), Color("e58a38"))
	_text(canvas, left + Vector2(0, 60), pressure_hint(view, rival_status), 12, CYAN, 292)
	_text(canvas, left + Vector2(0, 82), "Clean interceptions: %d" % int(view.interceptions), 11, MUTED, 292)
	canvas.draw_rect(LEAVE, Color("27352f"))
	_text(canvas, LEAVE.position + Vector2(7, 17), "ESC / BACK  ·  RETURN TO WELLSPRING", 10, PAPER, 278)


static func modal_lines(view: Dictionary, kit_lines: PackedStringArray) -> PackedStringArray:
	var finished := bool(view.get("finished", false))
	var lines := PackedStringArray()
	if finished:
		var won := String(view.phase) == Run.VICTORY
		lines.append("Oh Tipi defeated. Try for a faster, cleaner clear." if won else "Retry with a fresh practice kit. Your normal weave is safe.")
		if String(view.phase) == Run.LEFT_COURT: lines.append("Keep your feet inside the marked court boundary.")
		elif String(view.phase) == Run.TIMEOUT: lines.append("Survival alone does not clear this trial: defeat the rival.")
		elif String(view.phase) == Run.DEFEATED: lines.append("Evade Heavy / volley, then attack during Oh Tipi's pause.")
		else: lines.append("All attacks and movement used their normal paid rules.")
		lines.append("")
		lines.append("%s: %.2fs" % ["Clear time" if won else "Elapsed", float(view.elapsed_ticks) / 120.0])
		lines.append("Health remaining: " + CompactCombatHud.resource_amount_label(int(view.health), int(view.health_maximum)))
		lines.append("Clean enemy interceptions: %d" % int(view.interceptions))
		lines.append("Paid casts: %d" % int(view.paid_casts))
	else:
		lines.append("One defeat clears it: beat Oh Tipi within 72s, including 4s to get ready.")
		lines.append("Stay inside the marked court. Zero health or timeout ends the run.")
		lines.append("Sidestep Heavy; Spray catches Rapid. Move between Bolts.")
		lines.append("When Oh Tipi pauses, attack or recover Flux. Watch lingering shots.")
		lines.append("Loaner: S. Wayne practice weave. First four spell positions:")
		lines.append_array(kit_lines)
		lines.append("Your selected champion and saved weave return when you leave.")
		lines.append("Offline only · Normal Flux costs, recovery, and movement.")
	return lines


static func draw_modal(canvas: CanvasItem, viewport: Vector2, view: Dictionary, kit_lines: PackedStringArray, selected: int, error: String = "") -> void:
	var boxes := geometry(viewport)
	var panel: Rect2 = boxes.panel
	canvas.draw_rect(Rect2(Vector2.ZERO, viewport), Color("060907c8"))
	canvas.draw_rect(panel, PANEL)
	canvas.draw_rect(panel, CYAN, false, 2.0)
	var left := panel.position + Vector2(22, 34)
	var width := panel.size.x - 44
	var finished := bool(view.get("finished", false))
	_text(canvas, left, result_title(String(view.get("phase", ""))), 23, PAPER, width)
	var lines := modal_lines(view, kit_lines)
	for index: int in lines.size():
		_text(canvas, panel.position + Vector2(22, BODY_FIRST_BASELINE + index * BODY_LINE_STEP), lines[index], 12, CYAN if index == 4 and not finished else MUTED, width)
	if not error.is_empty(): _text(canvas, panel.position + Vector2(22, panel.size.y - 94), error, 12, Color("f1b89e"), width)
	_text(canvas, panel.position + Vector2(22, panel.size.y - 72), "ARROWS / D-PAD select · ENTER / A confirm · ESC / B back", 10, MUTED, width)
	for index: int in 2:
		var box: Rect2 = boxes.primary if index == 0 else boxes.secondary
		canvas.draw_rect(box, Color("315e4f") if selected == index else Color("27352f"))
		canvas.draw_rect(box, CYAN if selected == index else MUTED, false, 1.0)
		var label := ("RETRY TRIAL" if finished else "START TRIAL") if index == 0 else ("WELLSPRING" if finished else "BACK")
		_text(canvas, box.position + Vector2(10, 25), label, 14, PAPER, box.size.x - 20)


static func _text(canvas: CanvasItem, point: Vector2, words: String, size: int, color: Color, width: float) -> void:
	canvas.draw_string(ThemeDB.fallback_font, point, words, HORIZONTAL_ALIGNMENT_LEFT, width, size, color)
