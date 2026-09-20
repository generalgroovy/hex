class_name PhysicalAttackPresenter
extends RefCounted

# Separate presentation layers. Body artwork contains neither magic nor reach.
static func draw(canvas: CanvasItem, state: PlayerState, frame: Dictionary, body_anchor: Vector2, ground_anchor: Vector2, language: VisualLanguage, _reduced: bool) -> void:
	if state.physical_kind == 0 or state.physical_phase == 0 or state.health <= 0: return
	var profile := PhysicalAttackTuning.shared().profile(state.physical_kind)
	if profile.is_empty(): return
	var aim := Vector2(state.physical_aim_x, state.physical_aim_y)
	var angle := aim.angle()
	var half_angle := acos(sqrt(float(profile.half_arc_cosine_squared) / 1_000_000.0))
	var reach := float(profile.reach) / 1000.0
	if state.physical_phase in [1, 2]:
		var color := Color("efe1bd")
		color.a = 0.50 if state.physical_phase == 2 else 0.24
		# The quiet arc is the authored center reach, identical for every size.
		# Target hurt radius participates in contact; body pose never enlarges it.
		canvas.draw_arc(ground_anchor, reach, angle - half_angle, angle + half_angle, 12, color, 1.0, false)
		for edge: float in [angle - half_angle, angle + half_angle]:
			var direction := Vector2(cos(edge), sin(edge))
			canvas.draw_line(ground_anchor + direction * (reach - 4.0), ground_anchor + direction * reach, color, 1.0)
	if not bool(frame.get("attachment_available", false)): return
	var point: Vector2 = body_anchor - Vector2(48, 84) + Vector2(frame.attachment_point)
	if state.physical_phase == 2:
		canvas.draw_line(point - aim.normalized() * 2.0, point + aim.normalized() * 4.0, Color("fff0c8"), 2.0)
	if state.infusion_wire_id <= 0 or language == null: return
	var element: String = HexCourtPresenter.ELEMENT_IDS.get(int(CombatTuning.cast_definition(state.infusion_wire_id).get("element_wire_id", 0)), "")
	if element not in ["water", "fire"]: return
	var outline := language.element_color(element, "dark")
	var base := language.element_color(element)
	var light := language.element_color(element, "bright")
	# Fixed, small hand/foot marker; no extra collision, particles, or trail.
	if element == "water":
		canvas.draw_circle(point, 5.0, outline, false, 2.0, false)
		canvas.draw_arc(point, 3.0, 0.25, TAU - 0.3, 10, base, 2.0, false)
		canvas.draw_rect(Rect2(point + Vector2(-1, -2), Vector2(2, 2)), light)
	else:
		var triangle := PackedVector2Array([point + Vector2(0, -6), point + Vector2(5, 4), point + Vector2(-4, 4)])
		canvas.draw_colored_polygon(triangle, outline)
		canvas.draw_colored_polygon(PackedVector2Array([point + Vector2(0, -4), point + Vector2(3, 3), point + Vector2(-2, 3)]), base)
		canvas.draw_rect(Rect2(point + Vector2(0, 0), Vector2(1, 2)), light)
