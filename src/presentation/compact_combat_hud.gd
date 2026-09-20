class_name CompactCombatHud
extends RefCounted


const DEFAULT_PATH := "res://content/visual/compact_hud_v1.json"
const ElementGlyphRendererScript = preload("res://src/presentation/element_glyph_renderer.gd")
const Recovery = preload("res://src/sim/entities/resource_recovery.gd")
const EXPECTED_ID := "compact-combat-hud-v1"
const EXPECTED_AUTHORITY := "presentation only; simulation, input legality and resource ownership remain authoritative elsewhere"
const REQUIRED_LAYOUT_KEYS := [
	"margin", "header_width", "header_height", "session_width", "resource_width",
	"resource_height", "resource_bar_height", "spell_cell_width", "spell_cell_height",
	"spell_cell_gap", "spell_footer_height", "panel_corner_step",
]

var language: VisualLanguage
var champion_art: CartoonChampionPresenter
var data: Dictionary = {}
var content_hash := ""
var last_error := ""


func configure(visual_language: VisualLanguage, path: String = DEFAULT_PATH) -> bool:
	language = visual_language
	data.clear()
	content_hash = ""
	last_error = ""
	if language == null or language.ramps.is_empty():
		return _fail("Compact HUD requires the validated visual language")
	if not FileAccess.file_exists(path):
		return _fail("Compact HUD layout does not exist: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("Compact HUD layout cannot be opened")
	var source := file.get_as_text()
	var parsed: Variant = JSON.parse_string(source)
	if not parsed is Dictionary:
		return _fail("Compact HUD layout root must be an object")
	data = parsed
	if not validate():
		data.clear()
		return false
	content_hash = source.sha256_text()
	return true


func validate() -> bool:
	last_error = ""
	if int(data.get("schema_version", -1)) != 1 or String(data.get("id", "")) != EXPECTED_ID:
		return _fail("Compact HUD identity is unsupported")
	if String(data.get("authority", "")) != EXPECTED_AUTHORITY:
		return _fail("Compact HUD must remain presentation-only")
	var layout_value: Variant = data.get("layout", {})
	if not layout_value is Dictionary:
		return _fail("Compact HUD layout must be an object")
	var layout: Dictionary = layout_value
	for key: String in REQUIRED_LAYOUT_KEYS:
		if int(layout.get(key, 0)) <= 0:
			return _fail("Compact HUD layout value is missing or invalid: %s" % key)
	if int(layout.get("margin", 0)) > 48 or int(layout.get("header_width", 0)) > 420 \
		or int(layout.get("session_width", 0)) > 360 or int(layout.get("resource_width", 0)) > 360 \
		or int(layout.get("resource_height", 0)) > 180 or int(layout.get("spell_cell_width", 0)) > 180 \
		or int(layout.get("spell_cell_height", 0)) > 96:
		return _fail("Compact HUD layout exceeds bounded presentation dimensions")
	var copy_value: Variant = data.get("copy", {})
	if not copy_value is Dictionary:
		return _fail("Compact HUD copy must be an object")
	for copy_key: String in ["plain", "ctrl", "alt", "ready", "loom"]:
		if String((copy_value as Dictionary).get(copy_key, "")).is_empty():
			return _fail("Compact HUD copy is incomplete: %s" % copy_key)
	var coverage := int(data.get("maximum_view_coverage_percent", 0))
	if coverage < 6 or coverage > int(language.data.get("budgets", {}).get("maximum_combat_hud_coverage_percent", 19)):
		return _fail("Compact HUD coverage is outside the visual budget")
	return true


func draw(
	canvas: CanvasItem,
	viewport_size: Vector2,
	state: PlayerState,
	ability_catalog: AbilityCatalog,
	champion_id: String,
	champion_name: String,
	location_name: String,
	session_label: String,
	active_layer: int,
	tick_rate: int,
	spectating: bool,
	capacity: Vector2i = Vector2i(-1, -1),
	cast_gate: String = "",
	pointer: Vector2 = Vector2(-1000, -1000),
	feedback_label: String = "",
) -> void:
	if canvas == null or state == null or ability_catalog == null or language == null:
		return
	var layout: Dictionary = data.get("layout", {})
	var copy: Dictionary = data.get("copy", {})
	var margin := float(layout.get("margin", 16))
	var header_height := float(layout.get("header_height", 34))
	var header := Rect2(margin, margin, float(layout.get("header_width", 312)), header_height)
	var session_width := float(layout.get("session_width", 248))
	var session := Rect2(viewport_size.x - margin - session_width, margin, session_width, header_height)
	_draw_panel(canvas, header, 1.0)
	_draw_panel(canvas, session, 0.82)
	var title := ("WATCHING " if spectating else "") + champion_name.to_upper()
	canvas.draw_string(ThemeDB.fallback_font, header.position + Vector2(10, 15), title, HORIZONTAL_ALIGNMENT_LEFT, header.size.x - 20.0, 12, language.ui_color("text_primary"))
	canvas.draw_string(ThemeDB.fallback_font, header.position + Vector2(10, 29), location_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, header.size.x - 20.0, 10, language.ui_color("text_secondary"))
	canvas.draw_string(ThemeDB.fallback_font, session.position + Vector2(10, 21), session_label.to_upper(), HORIZONTAL_ALIGNMENT_RIGHT, session.size.x - 20.0, 11, language.ui_color("focus"))
	if not feedback_label.is_empty():
		# Queue pressure has its own bounded line so build/round text cannot clip it.
		var feedback := Rect2(session.position + Vector2(0, header_height + 4), Vector2(session_width, 24))
		_draw_panel(canvas, feedback, 0.94)
		canvas.draw_string(ThemeDB.fallback_font, feedback.position + Vector2(10, 16), feedback_label, HORIZONTAL_ALIGNMENT_RIGHT, feedback.size.x - 20.0, 11, language.ui_color("focus"))

	var resource_width := float(layout.get("resource_width", 270))
	var resource_height := float(layout.get("resource_height", 118))
	var resources := Rect2(margin, viewport_size.y - margin - resource_height, resource_width, resource_height)
	_draw_resources(canvas, resources, state, champion_id, champion_name, layout, tick_rate, resources.has_point(pointer))

	var cell_width := float(layout.get("spell_cell_width", 142))
	var cell_height := float(layout.get("spell_cell_height", 70))
	var gap := float(layout.get("spell_cell_gap", 6))
	var spell_width := cell_width * float(PlayerState.SPELL_BUTTON_COUNT) + gap * float(PlayerState.SPELL_BUTTON_COUNT - 1)
	var spell_start := Vector2(viewport_size.x - margin - spell_width, viewport_size.y - margin - cell_height)
	var layer_label := _layer_label(active_layer, copy)
	var layer_tab := Rect2(spell_start + Vector2(0, -24), Vector2(112, 20))
	_draw_panel(canvas, layer_tab, 0.94)
	canvas.draw_rect(Rect2(layer_tab.position + Vector2(5, 5), Vector2(5, 10)), language.ui_color("focus"), true)
	canvas.draw_string(ThemeDB.fallback_font, layer_tab.position + Vector2(16, 14), layer_label, HORIZONTAL_ALIGNMENT_LEFT, layer_tab.size.x - 22.0, 9, language.ui_color("text_primary"))
	for button_index: int in range(PlayerState.SPELL_BUTTON_COUNT):
		var rectangle := Rect2(spell_start + Vector2(float(button_index) * (cell_width + gap), 0), Vector2(cell_width, cell_height))
		var slot_index := active_layer * PlayerState.SPELL_BUTTON_COUNT + button_index
		_draw_spell_cell(canvas, rectangle, state, ability_catalog, slot_index, button_index, tick_rate, copy, capacity, cast_gate)


func _draw_resources(canvas: CanvasItem, rectangle: Rect2, state: PlayerState, champion_id: String, champion_name: String, layout: Dictionary, tick_rate: int, details: bool = false) -> void:
	_draw_panel(canvas, rectangle, 0.94)
	var medallion := rectangle.position + Vector2(28, 34)
	canvas.draw_circle(medallion + Vector2(2, 3), 19.0, Color(language.ramp_color("worldbone", 0), 0.7))
	canvas.draw_circle(medallion, 18.0, language.ramp_color("aged_brass", 2))
	_draw_portrait(canvas, medallion, champion_id)
	var protection := protection_status(state, tick_rate)
	canvas.draw_string(ThemeDB.fallback_font, rectangle.position + Vector2(54, 19), champion_name.to_upper() if protection.is_empty() else protection, HORIZONTAL_ALIGNMENT_LEFT, rectangle.size.x - 64.0, 11, language.ui_color("text_primary") if protection.is_empty() else language.ui_color("focus"))
	var bar_x := rectangle.position.x + 54.0
	var bar_width := rectangle.size.x - 66.0
	var bar_height := float(layout.get("resource_bar_height", 20))
	_draw_resource_bar(canvas, Rect2(bar_x, rectangle.position.y + 29, bar_width, bar_height), "HEALTH", state.health, state.health_maximum, language.ramp_color("health", 3))
	_draw_resource_bar(canvas, Rect2(bar_x, rectangle.position.y + 56, bar_width, bar_height), flux_status_label(state, tick_rate) if details else quiet_resource_label(state, "FLUX"), state.flux, state.flux_maximum, language.ramp_color("flux", 3))
	_draw_resource_bar(canvas, Rect2(bar_x, rectangle.position.y + 83, bar_width, bar_height), stamina_status_label(state, tick_rate) if details else quiet_resource_label(state, "STAMINA"), state.stamina, state.stamina_maximum, language.ramp_color("stamina", 3))


static func quiet_resource_label(state: PlayerState, resource: String) -> String:
	# Routine wait/rate numbers are available on pointer inspection, not a
	# continuously changing combat label. Sealed recovery remains prominent.
	if state == null or state.health <= 0:
		return resource
	if state.chemistry_regen_block_ticks > 0:
		return resource + " SEALED"
	# Finite protection time affects the next decision, unlike routine regen
	# bookkeeping. Keep it visible even when recovery details are collapsed.
	if resource == "STAMINA" and state.air_floating and state.float_ticks > 0 and state.stamina > 0 and state.control_state in [PlayerState.ControlState.FREE, PlayerState.ControlState.SLOWED]:
		return "STAMINA FLOAT %.1fs" % (float(state.float_ticks) / 120.0)
	return resource


static func protection_status(state: PlayerState, tick_rate: int = 120) -> String:
	var config := SimConfig.new(maxi(1, tick_rate))
	if JumpPresentation.protection_ratio(state, config) <= 0.0:
		return ""
	if state.spawn_protection_ticks > 0:
		return "PROTECTED / SPAWN"
	if state.air_floating:
		return "PROTECTED / FLOAT"
	return "PROTECTED"


static func flux_status_label(state: PlayerState, tick_rate: int) -> String:
	if state == null or state.flux >= state.flux_maximum:
		return "FLUX"
	if state.flux_recovery_delay_ticks > 0:
		return "FLUX WAIT %.1fs" % (float(state.flux_recovery_delay_ticks) / float(maxi(1, tick_rate)))
	if state.chemistry_regen_block_ticks > 0:
		return "FLUX SEALED"
	if state.health <= 0:
		return "FLUX"
	return "FLUX +%s/s" % _rate_points(Recovery.rate_per_second(state.flux_recovery_per_second, state.flux_recovery_idle_ticks, tick_rate))


static func stamina_status_label(state: PlayerState, tick_rate: int) -> String:
	if state == null:
		return "STAMINA"
	var safe_rate := maxi(1, tick_rate)
	var slide_minimum := ceili(float(MovementTuning.SLIDE_MINIMUM_MS * safe_rate) / 1000.0)
	var free_control := state.impact_recovery_ticks <= 0 and state.control_state in [PlayerState.ControlState.FREE, PlayerState.ControlState.SLOWED]
	if free_control and state.air_floating and state.float_ticks > 0 and state.is_airborne() and state.stamina > 0:
		var remaining := ceilf(float(state.float_ticks) * 10.0 / float(safe_rate)) / 10.0
		return "STAMINA FLOAT %.1fs -%d/s" % [remaining, MovementTuning.FLOAT_DRAIN_PER_SECOND / 1000]
	# Airtime is not sustain: falling, dodging, wall attachment, released input
	# and forced control all stop optional Jump spending in the simulation.
	if free_control and state.is_airborne() and state.air_vertical_velocity > 0 \
		and state.air_dodge_ticks <= 0 and state.wall_skim_ticks <= 0 \
		and state.jump_held_last_tick and state.variable_jump_grace_ticks <= 0 \
		and state.stamina >= MovementTuning.JUMP_SUSTAIN_DRAIN_PER_SECOND / safe_rate:
		return "STAMINA  JUMP -%d/s" % (MovementTuning.JUMP_SUSTAIN_DRAIN_PER_SECOND / 1000)
	if free_control and state.slide_ticks > slide_minimum and state.slide_held_last_tick \
		and state.stamina >= MovementTuning.SLIDE_SUSTAIN_DRAIN_PER_SECOND / safe_rate:
		return "STAMINA  SLIDE -%d/s" % (MovementTuning.SLIDE_SUSTAIN_DRAIN_PER_SECOND / 1000)
	if free_control and state.sprinting and state.stamina > 0:
		return "STAMINA SPRINT -%d/s" % (MovementTuning.SPRINT_DRAIN_PER_SECOND / 1000)
	if state.movement_chain_reset_ticks > 0 and state.movement_chain_count > 0:
		return "STAMINA  NEXT +%d%%" % (mini(state.movement_chain_count, MovementTuning.MOVEMENT_CHAIN_MAXIMUM_STEPS) * MovementTuning.MOVEMENT_CHAIN_COST_STEP_RATIO / 10)
	if state.stamina < state.stamina_maximum and state.health > 0:
		if state.chemistry_regen_block_ticks > 0:
			return "STAMINA SEALED"
		if state.stamina_recovery_delay_ticks > 0:
			return "STAMINA WAIT %.1fs" % (float(state.stamina_recovery_delay_ticks) / float(safe_rate))
		if free_control and not state.is_airborne() and state.air_dodge_ticks <= 0 \
			and state.slide_ticks <= 0 and state.wave_dash_ticks <= 0 and state.wall_skim_ticks <= 0 \
			and state.vault_ticks <= 0 and state.superglide_ticks <= 0:
			return "STAMINA +%s/s" % _rate_points(Recovery.rate_per_second(state.stamina_recovery_per_second, state.stamina_recovery_idle_ticks, tick_rate))
	return "STAMINA"


static func _rate_points(value: int) -> String:
	return ("%.1f" % (float(value) / 1000.0)).trim_suffix(".0")


func _draw_resource_bar(canvas: CanvasItem, rectangle: Rect2, label: String, value: int, maximum: int, color: Color) -> void:
	var ratio := clampf(float(value) / float(maxi(maximum, 1)), 0.0, 1.0)
	canvas.draw_rect(rectangle, Color(language.ramp_color("worldbone", 0), 0.92), true)
	canvas.draw_rect(Rect2(rectangle.position + Vector2(2, 2), Vector2((rectangle.size.x - 4.0) * ratio, rectangle.size.y - 4.0)), color, true)
	canvas.draw_rect(rectangle, Color(language.ui_color("text_primary"), 0.52), false, 1.0)
	for marker_index: int in range(1, 4):
		var marker_x := rectangle.position.x + rectangle.size.x * float(marker_index) / 4.0
		canvas.draw_line(Vector2(marker_x, rectangle.position.y + 2), Vector2(marker_x, rectangle.end.y - 2), Color(language.ramp_color("worldbone", 0), 0.36), 1.0)
	canvas.draw_string(ThemeDB.fallback_font, rectangle.position + Vector2(6, 14), "%s  %d/%d" % [label, value / 1000, maximum / 1000], HORIZONTAL_ALIGNMENT_LEFT, rectangle.size.x - 12.0, 10, language.ui_color("text_primary"))


func _draw_spell_cell(canvas: CanvasItem, rectangle: Rect2, state: PlayerState, ability_catalog: AbilityCatalog, slot_index: int, button_index: int, tick_rate: int, copy: Dictionary, capacity: Vector2i = Vector2i(-1, -1), cast_gate: String = "") -> void:
	var wire_id: int = state.spell_wire_id(slot_index + 1)
	var ability: Dictionary = ability_catalog.ability_from_wire(wire_id)
	var empty := ability.is_empty()
	var element := String(ability.get("element", "dark"))
	var accent := language.element_color(element, "bright") if not empty and language.elements.has(element) else language.ui_color("text_muted")
	_draw_panel(canvas, rectangle, 0.95)
	canvas.draw_rect(rectangle, Color(accent, 0.72), false, 2.0)
	_draw_element_glyph(canvas, rectangle.position + Vector2(18, 20), element, accent, empty)
	canvas.draw_string(ThemeDB.fallback_font, rectangle.position + Vector2(34, 15), "%d  %s" % [button_index + 1, "EMPTY" if empty else String(ability.get("display_name", "SPELL")).to_upper()], HORIZONTAL_ALIGNMENT_LEFT, rectangle.size.x - 40.0, 10, language.ui_color("text_primary") if not empty else language.ui_color("text_muted"))
	if empty:
		canvas.draw_string(ThemeDB.fallback_font, rectangle.position + Vector2(10, 35), String(copy.get("loom", "WEAVE AT LOOM")), HORIZONTAL_ALIGNMENT_LEFT, rectangle.size.x - 20.0, 9, language.ui_color("text_muted"))
		return
	var readiness := spell_readiness(state, ability, tick_rate, capacity, cast_gate)
	var status := String(readiness.label)
	canvas.draw_string(ThemeDB.fallback_font, rectangle.position + Vector2(10, 35), spell_summary_label(ability), HORIZONTAL_ALIGNMENT_LEFT, rectangle.size.x - 20.0, 9, language.ui_color("text_secondary"))
	if not status.is_empty():
		canvas.draw_string(ThemeDB.fallback_font, rectangle.position + Vector2(10, 55), status, HORIZONTAL_ALIGNMENT_LEFT, rectangle.size.x - 20.0, 10, language.ui_color("pending") if readiness.kind in ["cooldown", "startup"] else language.ui_color("danger"))
	var track := Rect2(rectangle.position + Vector2(10, rectangle.size.y - 8), Vector2(rectangle.size.x - 20, 3))
	canvas.draw_rect(track, Color(accent, 0.15))
	canvas.draw_rect(Rect2(track.position, Vector2(track.size.x * float(readiness.progress), track.size.y)), Color(accent, 0.9))


static func spell_readiness(state: PlayerState, ability: Dictionary, tick_rate: int = 120, capacity: Vector2i = Vector2i(-1, -1), cast_gate: String = "") -> Dictionary:
	var result := {"kind": "ready", "label": "", "progress": 1.0}
	if state == null or state.health <= 0 or ability.is_empty():
		return {"kind": "unavailable", "label": "UNAVAILABLE", "progress": 0.0}
	var wire := int(ability.get("wire_id", 0))
	if state.pending_cast_wire_id != 0 or cast_gate == "startup_commitment":
		return {"kind": "startup", "label": "CASTING" if state.pending_cast_wire_id == wire else "FINISH CAST", "progress": 0.0}
	if not cast_gate.is_empty():
		return {"kind": "control", "label": "CONTROLLED", "progress": 0.0}
	var cooldown := state.spell_cooldown_for_wire(wire)
	if cooldown > 0:
		var total := maxi(1, ceili(float(int(ability.get("cooldown_ms", 1)) * maxi(1, tick_rate)) / 1000.0))
		return {"kind": "cooldown", "label": "%.1fs" % (float(cooldown) / float(maxi(1, tick_rate))), "progress": clampf(1.0 - float(cooldown) / float(total), 0.0, 1.0)}
	var needed := CombatSystem.cast_capacity_requirement(wire)
	if (capacity.x >= 0 and needed.x > capacity.x) or (capacity.y >= 0 and needed.y > capacity.y):
		return {"kind": "capacity", "label": "MATERIAL LIMIT" if needed.x > 0 else "FIELD LIMIT", "progress": 0.0}
	if not spell_is_affordable(state, ability):
		return {"kind": "flux", "label": "NEED %d F" % int(ability.get("flux_cost", 0)), "progress": 0.0}
	return result


static func spell_summary_label(ability: Dictionary) -> String:
	var family := AbilityCatalog._spell_family(ability)
	if not family in ["bolt", "heavy", "rapid", "spray"] or String(ability.get("runtime_status", "playable")) != "playable":
		return "DISABLED"
	var label := "WAVE" if family == "burst" else (family.to_upper() if not family.is_empty() else "SPELL")
	var cost := int(ability.get("flux_cost", 0))
	return "%s · %s" % [label, "FREE" if cost == 0 else "%d F" % cost]


static func spell_is_affordable(state: PlayerState, ability: Dictionary) -> bool:
	return state != null and state.flux >= maxi(0, int(ability.get("flux_cost", 0))) * 1000


static func _cooldown_for_wire(state: PlayerState, wire_id: int) -> int:
	return state.spell_cooldown_for_wire(wire_id)


func _draw_panel(canvas: CanvasItem, rectangle: Rect2, opacity: float) -> void:
	var step := float((data.get("layout", {}) as Dictionary).get("panel_corner_step", 6))
	var points := PackedVector2Array([
		rectangle.position + Vector2(step, 0), rectangle.end - Vector2(step, rectangle.size.y),
		rectangle.end - Vector2(0, rectangle.size.y - step), rectangle.end - Vector2(0, step),
		rectangle.end - Vector2(step, 0), rectangle.position + Vector2(step, rectangle.size.y),
		rectangle.position + Vector2(0, rectangle.size.y - step), rectangle.position + Vector2(0, step),
	])
	canvas.draw_colored_polygon(points, Color(language.ui_color("panel_fill"), opacity))
	var outline := points.duplicate()
	outline.append(points[0])
	canvas.draw_polyline(outline, Color(language.ramp_color("aged_brass", 2), 0.72 * opacity), 1.0, false)


func portrait_source(champion_id: String) -> Dictionary:
	return {} if champion_art == null else champion_art.portrait_frame(champion_id)


func _draw_portrait(canvas: CanvasItem, center: Vector2, champion_id: String) -> void:
	canvas.draw_circle(center, 14.0, language.ramp_color("worldbone", 0))
	var frame := portrait_source(champion_id)
	if not frame.is_empty():
		# Share the Gallery's anatomy-derived crop, including accepted art whose
		# full world page is not resident. The transparent square preserves aspect.
		canvas.draw_texture_rect_region(frame["texture"], Rect2(center - Vector2(16, 16), Vector2(32, 32)), frame["region"])


func _draw_element_glyph(canvas: CanvasItem, center: Vector2, element: String, accent: Color, empty: bool) -> void:
	canvas.draw_circle(center, 9.0, Color(accent, 0.14 if empty else 0.24))
	if empty:
		canvas.draw_arc(center, 5.0, 0.0, TAU, 12, accent, 1.0)
		return
	ElementGlyphRendererScript.draw(canvas, language, center, element, 6.0, accent)


func _layer_label(active_layer: int, copy: Dictionary) -> String:
	match active_layer:
		1:
			return String(copy.get("ctrl", "CTRL SPELLS"))
		2:
			return String(copy.get("alt", "ALT SPELLS"))
		_:
			return String(copy.get("plain", "PLAIN SPELLS"))


func _fail(message: String) -> bool:
	last_error = message
	return false
