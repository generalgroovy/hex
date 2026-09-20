class_name PracticeCoachCard
extends RefCounted


# A compact view of existing, snapshot-derived teaching. No new progression,
# rewards or simulated actions: hover only reveals the same source details.
static func model(view: Dictionary, viewport_size: Vector2, pointer: Vector2) -> Dictionary:
	if view.is_empty() or viewport_size.x < 64.0:
		return {}
	var lines := PackedStringArray(view.get("lines", []))
	var panel := Rect2(maxf(16.0, viewport_size.x - 456.0), 86.0, minf(440.0, viewport_size.x - 32.0), 82.0)
	# Admission uses the compact card, keeping expansion independent of its own
	# height. No hidden panel captures movement or casting input.
	var expanded := panel.has_point(pointer)
	var visible := PackedStringArray()
	if expanded:
		for index: int in range(mini(3, lines.size())):
			visible.append(lines[index])
		panel.size.y = 68.0 + 18.0 * visible.size()
	elif not lines.is_empty():
		# Reaction line zero is the recipe, line one the actual current effect.
		var effect_line := 1 if String(view.get("kind", "")) == "reaction" and lines.size() > 1 else 0
		visible.append(lines[effect_line])
	return {"panel": panel, "lines": visible, "expanded": expanded,
		"title": String(view.get("title", "PRACTICE")), "phase": String(view.get("phase", ""))}
