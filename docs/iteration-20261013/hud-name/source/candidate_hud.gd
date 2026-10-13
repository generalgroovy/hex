extends CompactCombatHud
## Ignored prototype: omit only the lower duplicate idle identity.

func _draw_resources(canvas: CanvasItem, rectangle: Rect2, state: PlayerState, champion_id: String, _champion_name: String, layout: Dictionary, tick_rate: int) -> void:
	_draw_panel(canvas, rectangle, 0.94)
	var medallion := rectangle.position + Vector2(28, 34)
	canvas.draw_circle(medallion + Vector2(2, 3), 19.0, Color(language.ramp_color("worldbone", 0), 0.7))
	canvas.draw_circle(medallion, 18.0, language.ramp_color("aged_brass", 2))
	_draw_portrait(canvas, medallion, champion_id)
	var protection := protection_status(state, tick_rate)
	if not protection.is_empty():
		canvas.draw_string(ThemeDB.fallback_font, rectangle.position + Vector2(54, 19), protection, HORIZONTAL_ALIGNMENT_LEFT, rectangle.size.x - 64.0, 11, language.ui_color("focus"))
	var bar_x := rectangle.position.x + 54.0
	var bar_width := rectangle.size.x - 66.0
	var bar_height := float(layout.get("resource_bar_height", 20))
	_draw_resource_bar(canvas, Rect2(bar_x, rectangle.position.y + 29, bar_width, bar_height), quiet_resource_label(state, "HEALTH"), state.health, state.health_maximum, language.ramp_color("health", 3), &"health")
	_draw_resource_bar(canvas, Rect2(bar_x, rectangle.position.y + 56, bar_width, bar_height), quiet_resource_label(state, "FLUX"), state.flux, state.flux_maximum, language.ramp_color("flux", 3), &"flux")
	_draw_resource_bar(canvas, Rect2(bar_x, rectangle.position.y + 83, bar_width, bar_height), quiet_resource_label(state, "STAMINA"), state.stamina, state.stamina_maximum, language.ramp_color("stamina", 3), &"stamina")
