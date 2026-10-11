extends RefCounted


const Compendium = preload("res://src/presentation/player_compendium.gd")
const Bindings = preload("res://src/presentation/spell_loom_presenter.gd")


# Presentation only: every call reads the restored/current weave and saved
# bindings afresh. A result never retains loaner slots, casts, equips or resets.
static func build(result: Dictionary, actor: PlayerState, preferences: PlayerPreferences) -> Dictionary:
	if result.is_empty():
		return {}
	var outcome := String(result.get("outcome", "aborted"))
	var product: Dictionary = result.get("observed_product", {})
	var observed := not product.is_empty()
	var recipe_wire := int(product.get("recipe_wire_id", result.get("recipe_wire_id", 0)))
	var recipe := HexRecipePolicy.definition(recipe_wire)
	var lines := PackedStringArray()
	if outcome != "complete":
		lines.append(String(result.get("message", "The demo stopped.")))
	if observed:
		lines.append("Observed: %s / %d matter across %d whole hexes." % [product.get("name", "reaction"), int(product.get("quantity", 0)), int(product.get("cell_count", 0))])
	else:
		lines.append("No selected two-source reaction was observed in this run.")
	lines.append("Paid: %d / 2 Bolts / %.1f Flux / %d matter. No refund." % [int(result.get("paid_casts", 0)), float(result.get("paid_flux", 0)) / float(SimConfig.FIXED_SCALE), int(result.get("paid_matter", 0))])
	var cell := _recipe_cell(recipe)
	if not cell.is_empty():
		lines.append(("Effect: " if observed else "If %s forms: " % String(cell.name)) + String(cell.effect))
		# Keep authored casing and wording intact (e.g. the Water element).
		# String.capitalize() title-cases every word, not just the sentence.
		lines.append("Counter: " + String(cell.counter) + ".")
	var retry := retry_guidance(result, actor, preferences)
	lines.append("TRY BY HAND / same nearby empty endpoint, two separate paid Bolts.")
	lines.append_array(retry.lines)
	lines.append("Let old matter clear; cast the second before the first deposit expires. Normal Flux, cooldown and recovery apply.")
	lines.append("Original weave restored; no loaners kept. No world reset." if bool(result.get("weave_restored", false)) else "Actor unavailable; no replacement weave or world reset was made.")
	return {"title": {"complete": "CHEMISTRY OBSERVED", "canceled": "DEMO CANCELED", "aborted": "DEMO STOPPED"}.get(outcome, "DEMO STOPPED"),
		"lines": lines, "retry_ready": bool(retry.ready), "retry_steps": retry.steps,
		"outcome": outcome, "observed": observed, "recipe_wire_id": recipe_wire,
		"summary": ("%s / %d matter / %d hexes" % [product.get("name", "Reaction"), int(product.get("quantity", 0)), int(product.get("cell_count", 0))] if observed else "No selected reaction observed") + " / %d paid Bolts" % int(result.get("paid_casts", 0)),
		"turn_hint": "Your turn: cast by hand when cooldowns allow." if bool(retry.ready) else "Your turn: check your weave and Controls below."}


static func retry_guidance(result: Dictionary, actor: PlayerState, preferences: PlayerPreferences) -> Dictionary:
	var lines := PackedStringArray()
	var steps: Array[Dictionary] = []
	if actor == null or actor.entity_id != int(result.get("actor_id", 0)) or actor.health <= 0:
		return {"ready": false, "steps": steps, "lines": PackedStringArray(["Return to a living free-practice actor before trying by hand."])}
	var wires: PackedInt32Array = result.get("wires", PackedInt32Array())
	var elements: PackedStringArray = result.get("elements", PackedStringArray())
	if wires.size() != 2 or elements.size() != 2:
		return {"ready": false, "steps": steps, "lines": PackedStringArray(["Choose a supported pair again in the Chemistry Matrix."])}
	var ready := true
	for index: int in 2:
		var wire := int(wires[index])
		var name := AbilityCatalog.element_display_name(elements[index]) + " Bolt"
		var slot := actor.spell_wire_ids.find(wire)
		var binding := Bindings.slot_binding_label(slot, preferences) if slot >= 0 else ""
		var available := slot >= 0 and binding not in ["", "Not bound", "Binding unavailable", "Invalid slot"]
		steps.append({"wire_id": wire, "slot": slot, "binding": binding, "available": available,
			"cooldown_ticks": actor.spell_cooldown_for_wire(wire) if slot >= 0 else 0})
		ready = ready and available
		if slot < 0:
			lines.append("%d. %s is absent from your restored weave. Equip it in Spell Loom." % [index + 1, name])
		elif not available:
			lines.append("%d. %s / slot %02d: %s. Assign its button and modifier in Controls." % [index + 1, name, slot + 1, binding])
		else:
			lines.append("%d. %s / slot %02d / %s%s." % [index + 1, name, slot + 1, binding, " after its cooldown" if actor.spell_cooldown_for_wire(wire) > 0 else ""])
	return {"ready": ready, "steps": steps, "lines": lines}


static func _recipe_cell(recipe: Dictionary) -> Dictionary:
	if recipe.is_empty():
		return {}
	var elements: Array = recipe.get("elements", [])
	if elements.size() != 2:
		return {}
	var row := ChemistryGuideModel.DISPLAY_WIRES.find(int(elements[0]))
	var column := ChemistryGuideModel.DISPLAY_WIRES.find(int(elements[1]))
	return Compendium.hex_matrix_cell(row, column)


# Nonmodal top-right learning card. Hover expansion uses one stable footprint,
# so moving down to read cannot collapse it. Nothing here captures input or
# gameplay; the caller owns Escape/click dismissal and context invalidation.
static func layout(view: Dictionary, viewport: Vector2, pointer: Vector2, font: Font) -> Dictionary:
	if view.is_empty() or font == null or viewport.x < 240 or viewport.y < 280:
		return {}
	var width := minf(480.0, viewport.x - 32.0)
	var origin := Vector2(viewport.x - width - 16.0, 90.0)
	var body_width := width - 28.0
	var available_height := viewport.y - origin.y - 104.0
	var body_size := 12
	var expanded_lines := _wrapped_lines(view.get("lines", PackedStringArray()), font, body_size, body_width)
	while body_size > 9 and 52.0 + expanded_lines.size() * (body_size + 3.0) > available_height:
		body_size -= 1
		expanded_lines = _wrapped_lines(view.get("lines", PackedStringArray()), font, body_size, body_width)
	var expanded_height := 52.0 + expanded_lines.size() * (body_size + 3.0)
	var expanded_panel := Rect2(origin, Vector2(width, minf(expanded_height, available_height)))
	var content_fits := expanded_height <= available_height
	var expanded := content_fits and (bool(view.get("expanded", false)) or expanded_panel.has_point(pointer))
	var content := expanded_lines
	if not expanded:
		body_size = 12
		var compact_lines := PackedStringArray([String(view.get("summary", "")), String(view.get("turn_hint", "")), "Hover to read / Esc or X to dismiss" if content_fits else "Enlarge the window to read / Esc or X to dismiss"])
		content = _wrapped_lines(compact_lines, font, body_size, body_width)
		while body_size > 9 and 52.0 + content.size() * (body_size + 3.0) > available_height:
			body_size -= 1
			content = _wrapped_lines(compact_lines, font, body_size, body_width)
		if 52.0 + content.size() * (body_size + 3.0) > available_height:
			return {} # Retain the result for a larger viewport, never overdraw HUD.
	var panel := Rect2(origin, Vector2(width, minf(52.0 + content.size() * (body_size + 3.0), available_height)))
	var rows: Array[Dictionary] = []
	for index: int in content.size():
		rows.append({"text": content[index], "position": origin + Vector2(14, 43 + index * (body_size + 3)), "font_size": body_size})
	return {"panel": panel, "close": Rect2(origin + Vector2(width - 31, 6), Vector2(24, 24)),
		"expanded": expanded, "rows": rows, "body_width": body_width,
		"title_position": origin + Vector2(14, 23), "title_font_size": 15,
		"content_fits": content_fits, "body_font_size": body_size}


static func draw(canvas: CanvasItem, view: Dictionary, viewport: Vector2, pointer: Vector2) -> void:
	if canvas == null:
		return
	var font := ThemeDB.fallback_font
	var boxes := layout(view, viewport, pointer, font)
	if boxes.is_empty():
		return
	var panel: Rect2 = boxes.panel
	var close: Rect2 = boxes.close
	var paper := Color("e2d8b2")
	var accent := Color("55dbe0")
	canvas.draw_rect(panel, Color("111b20f5"))
	canvas.draw_rect(panel, accent, false, 1.0)
	canvas.draw_string(font, boxes.title_position, String(view.title), HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 55, int(boxes.title_font_size), accent)
	for row: Dictionary in boxes.rows:
		canvas.draw_string(font, row.position, row.text, HORIZONTAL_ALIGNMENT_LEFT, float(boxes.body_width), int(row.font_size), paper)
	canvas.draw_rect(close, Color("315e4f") if close.has_point(pointer) else Color("27352f"))
	canvas.draw_string(font, close.position + Vector2(7, 17), "X", HORIZONTAL_ALIGNMENT_LEFT, 18, 13, paper)


static func _wrapped_lines(lines: PackedStringArray, font: Font, font_size: int, width: float) -> PackedStringArray:
	var wrapped := PackedStringArray()
	for line: String in lines:
		var current := ""
		for word: String in line.split(" ", false):
			var candidate := word if current.is_empty() else current + " " + word
			if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width:
				current = candidate
				continue
			if not current.is_empty():
				wrapped.append(current)
			current = ""
			# Preserve long saved chords in full, including unusual OS key names.
			for character: String in word:
				if not current.is_empty() and font.get_string_size(current + character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
					wrapped.append(current)
					current = ""
				current += character
		if not current.is_empty():
			wrapped.append(current)
	return wrapped
