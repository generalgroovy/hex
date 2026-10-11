class_name CompactCombatHud
extends RefCounted


const DEFAULT_PATH := "res://content/visual/compact_hud_v1.json"
const ElementGlyphRendererScript = preload("res://src/presentation/element_glyph_renderer.gd")
const BindingLabels = preload("res://src/presentation/spell_binding_labels.gd")
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
var _spell_card_layouts: Dictionary[int, Dictionary] = {}
var _spell_card_layout_builds := 0
const MAX_PANEL_GEOMETRIES := 64
var _panel_geometries: Dictionary = {}
var _panel_geometry_builds := 0


func configure(visual_language: VisualLanguage, path: String = DEFAULT_PATH) -> bool:
	_spell_card_layouts.clear()
	_panel_geometries.clear()
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


static func session_panel(viewport_size: Vector2, margin: float, width: float, header_height: float, line_count: int) -> Rect2:
	# One normal status line retains its previous footprint. Match standings
	# grow vertically, never crowding a four-player score into the same line.
	var height := header_height + float(clampi(line_count, 1, 6) - 1) * 14.0
	return Rect2(viewport_size.x - margin - width, margin, width, height)


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
	preferences: PlayerPreferences = null,
) -> void:
	if canvas == null or state == null or ability_catalog == null or language == null:
		return
	var layout: Dictionary = data.get("layout", {})
	var copy: Dictionary = data.get("copy", {})
	var margin := float(layout.get("margin", 16))
	var header_height := float(layout.get("header_height", 34))
	var header := Rect2(margin, margin, float(layout.get("header_width", 312)), header_height)
	var session_width := float(layout.get("session_width", 248))
	var session_lines := session_label.to_upper().split("\n")
	var session := session_panel(viewport_size, margin, session_width, header_height, session_lines.size())
	_draw_panel(canvas, header, 1.0)
	_draw_panel(canvas, session, 0.82)
	var title := ("WATCHING " if spectating else "") + champion_name.to_upper()
	canvas.draw_string(ThemeDB.fallback_font, header.position + Vector2(10, 15), title, HORIZONTAL_ALIGNMENT_LEFT, header.size.x - 20.0, 12, language.ui_color("text_primary"))
	canvas.draw_string(ThemeDB.fallback_font, header.position + Vector2(10, 29), location_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, header.size.x - 20.0, 10, language.ui_color("text_secondary"))
	for line_index: int in range(mini(session_lines.size(), 6)):
		canvas.draw_string(ThemeDB.fallback_font, session.position + Vector2(10, 21 + line_index * 14), session_lines[line_index], HORIZONTAL_ALIGNMENT_RIGHT, session.size.x - 20.0, 11, language.ui_color("focus"))
	if not feedback_label.is_empty():
		# Queue pressure has its own bounded line so build/round text cannot clip it.
		var feedback := Rect2(session.position + Vector2(0, session.size.y + 4), Vector2(session_width, 24))
		_draw_panel(canvas, feedback, 0.94)
		canvas.draw_string(ThemeDB.fallback_font, feedback.position + Vector2(10, 16), feedback_label, HORIZONTAL_ALIGNMENT_RIGHT, feedback.size.x - 20.0, 11, language.ui_color("focus"))

	var resource_width := float(layout.get("resource_width", 270))
	var resource_height := float(layout.get("resource_height", 118))
	var resources := Rect2(margin, viewport_size.y - margin - resource_height, resource_width, resource_height)
	_draw_resources(canvas, resources, state, champion_id, champion_name, layout, tick_rate)
	var preparation := {} if spectating else jump_preparation_status(state, tick_rate)
	var preparation_panel := jump_preparation_panel(resources, viewport_size) if not preparation.is_empty() else Rect2()
	if preparation_panel.has_area():
		_draw_jump_preparation(canvas, preparation_panel, preparation)
	if resources.has_point(pointer):
		var detail_lines := resource_detail_lines(state, tick_rate, preparation_panel.has_area())
		var detail_anchor := Rect2(preparation_panel.position, resources.size) if preparation_panel.has_area() else resources
		var detail_panel := resource_detail_panel(detail_anchor, viewport_size, detail_lines.size())
		if detail_panel.has_area():
			_draw_panel(canvas, detail_panel, 0.94)
			for line_index: int in range(detail_lines.size()):
				canvas.draw_string(ThemeDB.fallback_font, detail_panel.position + Vector2(10, 18 + line_index * 16), detail_lines[line_index], HORIZONTAL_ALIGNMENT_LEFT, detail_panel.size.x - 20.0, 11, language.ui_color("text_primary"))

	var cell_width := float(layout.get("spell_cell_width", 142))
	var cell_height := float(layout.get("spell_cell_height", 70))
	var gap := float(layout.get("spell_cell_gap", 6))
	var spell_width := cell_width * float(PlayerState.SPELL_BUTTON_COUNT) + gap * float(PlayerState.SPELL_BUTTON_COUNT - 1)
	var spell_start := Vector2(viewport_size.x - margin - spell_width, viewport_size.y - margin - cell_height)
	var layer_label := binding_layer_label(active_layer, preferences)
	var layer_width := clampf(ThemeDB.fallback_font.get_string_size(layer_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 28.0, 112.0, 220.0)
	var layer_tab := Rect2(spell_start + Vector2(0, -24), Vector2(layer_width, 20))
	_draw_panel(canvas, layer_tab, 0.94)
	canvas.draw_rect(Rect2(layer_tab.position + Vector2(5, 5), Vector2(5, 10)), language.ui_color("focus"), true)
	canvas.draw_string(ThemeDB.fallback_font, layer_tab.position + Vector2(16, 14), layer_label, HORIZONTAL_ALIGNMENT_LEFT, layer_tab.size.x - 22.0, 9, language.ui_color("text_primary"))
	var hidden_cast := hidden_cast_status(state, ability_catalog, active_layer, preferences, tick_rate)
	if not hidden_cast.is_empty():
		# Releasing a modifier must not hide an already-paid cast's progress.
		# This reads authority each draw; it never keeps its own startup timer.
		var cue := Rect2(layer_tab.position + Vector2(layer_width + gap, 0), Vector2(spell_width - layer_width - gap, 20))
		var accent := language.element_color(String(hidden_cast.element), "bright")
		_draw_panel(canvas, cue, 0.94)
		canvas.draw_string(ThemeDB.fallback_font, cue.position + Vector2(7, 13), String(hidden_cast.label), HORIZONTAL_ALIGNMENT_LEFT, cue.size.x - 14.0, 9, accent)
		canvas.draw_rect(Rect2(cue.position + Vector2(5, 17), Vector2((cue.size.x - 10.0) * float(hidden_cast.progress), 2)), accent)
	elif not cast_wait_label(state, cast_gate).is_empty():
		# The visible casting card already identifies the paid spell. Explain the
		# shared restriction once, leaving other cards free for their own cooldown.
		var cue := Rect2(layer_tab.position + Vector2(layer_width + gap, 0), Vector2(spell_width - layer_width - gap, 20))
		_draw_panel(canvas, cue, 0.82)
		canvas.draw_string(ThemeDB.fallback_font, cue.position + Vector2(7, 13), cast_wait_label(state, cast_gate), HORIZONTAL_ALIGNMENT_LEFT, cue.size.x - 14.0, 9, language.ui_color("text_secondary"))
	for button_index: int in range(PlayerState.SPELL_BUTTON_COUNT):
		var rectangle := Rect2(spell_start + Vector2(float(button_index) * (cell_width + gap), 0), Vector2(cell_width, cell_height))
		var slot_index := active_layer * PlayerState.SPELL_BUTTON_COUNT + button_index
		_draw_spell_cell(canvas, rectangle, state, ability_catalog, slot_index, button_index, tick_rate, copy, capacity, cast_gate, preferences)


func _draw_resources(canvas: CanvasItem, rectangle: Rect2, state: PlayerState, champion_id: String, champion_name: String, layout: Dictionary, tick_rate: int) -> void:
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
	_draw_resource_bar(canvas, Rect2(bar_x, rectangle.position.y + 29, bar_width, bar_height), quiet_resource_label(state, "HEALTH"), state.health, state.health_maximum, language.ramp_color("health", 3))
	_draw_resource_bar(canvas, Rect2(bar_x, rectangle.position.y + 56, bar_width, bar_height), quiet_resource_label(state, "FLUX"), state.flux, state.flux_maximum, language.ramp_color("flux", 3))
	_draw_resource_bar(canvas, Rect2(bar_x, rectangle.position.y + 83, bar_width, bar_height), quiet_resource_label(state, "STAMINA"), state.stamina, state.stamina_maximum, language.ramp_color("stamina", 3))


static func jump_preparation_status(state: PlayerState, tick_rate: int = 120) -> Dictionary:
	if state == null or state.health <= 0 or not state.jumpsquat_active or state.is_airborne() \
		or state.impact_recovery_ticks > 0 or state.control_state not in [PlayerState.ControlState.FREE, PlayerState.ControlState.SLOWED]:
		return {}
	var config := SimConfig.new(tick_rate)
	if not config.is_valid():
		return {}
	# Read the same prepared family and paid chain cost as release admission.
	# A slide timer may expire during preparation without changing that family.
	var slide_jump := state.slide_ticks > 0 or state.hop_mode == PlayerState.MovementMode.SLIDE_JUMP
	var cost := MovementSystem._movement_action_cost(state, MovementTuning.SLIDE_JUMP_COST if slide_jump else MovementTuning.HOP_COST)
	var wait_ticks := maxi(0, state.hop_cooldown_ticks)
	if slide_jump:
		var slide_age := config.milliseconds_to_ticks(MovementTuning.SLIDE_COOLDOWN_MS) - state.slide_cooldown_ticks
		wait_ticks = maxi(0, config.milliseconds_to_ticks(MovementTuning.SLIDE_JUMP_MINIMUM_COMMITMENT_MS) - slide_age)
	var progress := clampf(float(state.jumpsquat_ticks) / float(config.milliseconds_to_ticks(MovementTuning.JUMPSQUAT_CHARGE_MS)), 0.0, 1.0)
	var kind := "ready"
	var label := "RELEASE TO JUMP · %s ST" % _rate_points(cost)
	if wait_ticks > 0:
		kind = "cooldown"
		label = "JUMP WAIT %.1fs" % (ceilf(float(wait_ticks) * 10.0 / float(tick_rate)) / 10.0)
	elif state.stamina < cost:
		kind = "stamina"
		label = "JUMP NEED %s STAMINA" % _rate_points(cost)
	return {"kind": kind, "label": label, "cost": cost, "progress": progress,
		"title": ("SLIDE JUMP" if slide_jump else "JUMP") + (" FULL" if progress >= 1.0 else " CHARGE"),
		"slide_jump": slide_jump, "wait_ticks": wait_ticks}


static func jump_preparation_panel(resources: Rect2, viewport_size: Vector2) -> Rect2:
	var panel := Rect2(resources.position - Vector2(0, 54), Vector2(resources.size.x, 48))
	return panel if Rect2(Vector2.ZERO, viewport_size).encloses(panel) else Rect2()


func _draw_jump_preparation(canvas: CanvasItem, panel: Rect2, preparation: Dictionary) -> void:
	_draw_panel(canvas, panel, 0.94)
	var accent := language.ui_color("danger" if preparation.kind == "stamina" else ("pending" if preparation.kind == "cooldown" else "focus"))
	canvas.draw_string(ThemeDB.fallback_font, panel.position + Vector2(10, 15), preparation.title, HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 60.0, 11, language.ui_color("text_primary"))
	canvas.draw_string(ThemeDB.fallback_font, panel.position + Vector2(10, 15), "%d%%" % roundi(float(preparation.progress) * 100.0), HORIZONTAL_ALIGNMENT_RIGHT, panel.size.x - 20.0, 11, language.ui_color("text_secondary"))
	canvas.draw_string(ThemeDB.fallback_font, panel.position + Vector2(10, 31), preparation.label, HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 20.0, 11, accent)
	var track := Rect2(panel.position + Vector2(10, 39), Vector2(panel.size.x - 20.0, 3))
	canvas.draw_rect(track, Color(accent, 0.18))
	canvas.draw_rect(Rect2(track.position, Vector2(track.size.x * float(preparation.progress), track.size.y)), accent)


static func resource_detail_lines(state: PlayerState, tick_rate: int, preparation_visible: bool = false) -> PackedStringArray:
	# Keep the existing inspection information, but do not make it compete with
	# the always-visible quantity or repeat a quiet bar's identity/sealed label.
	var lines := PackedStringArray()
	var flux := flux_status_label(state, tick_rate)
	var stamina := stamina_status_label(state, tick_rate)
	if flux != "FLUX" and flux != quiet_resource_label(state, "FLUX"):
		lines.append(flux)
	if stamina != "STAMINA" and stamina != quiet_resource_label(state, "STAMINA") and not (preparation_visible and state.jumpsquat_active):
		lines.append(stamina)
	return lines


static func resource_detail_panel(resources: Rect2, viewport_size: Vector2, line_count: int) -> Rect2:
	if line_count <= 0 or line_count > 2:
		return Rect2()
	var panel_size := Vector2(resources.size.x, 12 + line_count * 16)
	var panel := Rect2(Vector2(clampf(resources.position.x, 0.0, maxf(0.0, viewport_size.x - panel_size.x)), resources.position.y - panel_size.y - 6.0), panel_size)
	# Use the caller's logical canvas dimensions, never the physical viewport.
	# Inspection stays above the resource panel, clear of the bottom spell row.
	return panel if Rect2(Vector2.ZERO, viewport_size).encloses(panel) else Rect2()


static func quiet_resource_label(state: PlayerState, resource: String) -> String:
	# Routine wait/rate numbers are available on pointer inspection, not a
	# continuously changing combat label. Sealed recovery remains prominent.
	if state == null or state.health <= 0:
		return resource
	if state.chemistry_regen_block_ticks > 0 or resource in ["HEALTH", "FLUX"] and SpellStatusPolicy.active(state, 5):
		return resource + " SEALED"
	# Finite flight time affects the next decision, unlike routine regen
	# bookkeeping. Keep it visible even when recovery details are collapsed.
	if resource == "STAMINA" and state.flight_capable and state.air_floating and state.float_ticks > 0 and state.stamina > 0 and state.control_state in [PlayerState.ControlState.FREE, PlayerState.ControlState.SLOWED]:
		return "STAMINA FLY %.1fs" % (float(state.float_ticks) / 120.0)
	return resource


static func protection_status(state: PlayerState, tick_rate: int = 120) -> String:
	var config := SimConfig.new(maxi(1, tick_rate))
	if JumpPresentation.protection_ratio(state, config) <= 0.0:
		return ""
	if state.spawn_protection_ticks > 0:
		return "PROTECTED / SPAWN"
	return "PROTECTED"


static func flux_status_label(state: PlayerState, tick_rate: int) -> String:
	if state == null or state.flux >= state.flux_maximum:
		return "FLUX"
	if state.flux_recovery_delay_ticks > 0:
		return "FLUX WAIT %.1fs" % (float(state.flux_recovery_delay_ticks) / float(maxi(1, tick_rate)))
	if state.chemistry_regen_block_ticks > 0 or SpellStatusPolicy.active(state, 5):
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
	if free_control and state.flight_capable and state.air_floating and state.float_ticks > 0 and state.is_airborne() and state.stamina > 0:
		var remaining := ceilf(float(state.float_ticks) * 10.0 / float(safe_rate)) / 10.0
		return "STAMINA FLY %.1fs -%d/s" % [remaining, MovementTuning.FLOAT_DRAIN_PER_SECOND / 1000]
	# Press/hold prepares on ground; release pays for launch. There is no
	# ordinary airborne jump-sustain drain in the current movement contract.
	if free_control and state.jumpsquat_active:
		return "STAMINA RELEASE TO JUMP"
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
		canvas.draw_line(Vector2(marker_x, rectangle.end.y - 5), Vector2(marker_x, rectangle.end.y - 2), Color(language.ramp_color("worldbone", 0), 0.36), 1.0)
	var amount := resource_amount_label(value, maximum)
	var label_width := maxf(0.0, rectangle.size.x - 20.0 - ThemeDB.fallback_font.get_string_size(amount, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x)
	# A one-pixel dark underprint keeps values legible over both the bright fill
	# and empty track without adding an opaque plate or obscuring bar quantities.
	canvas.draw_string(ThemeDB.fallback_font, rectangle.position + Vector2(7, 15), label, HORIZONTAL_ALIGNMENT_LEFT, label_width, 11, language.ramp_color("worldbone", 0))
	canvas.draw_string(ThemeDB.fallback_font, rectangle.position + Vector2(6, 14), label, HORIZONTAL_ALIGNMENT_LEFT, label_width, 11, language.ui_color("text_primary"))
	canvas.draw_string(ThemeDB.fallback_font, rectangle.position + Vector2(7, 15), amount, HORIZONTAL_ALIGNMENT_RIGHT, rectangle.size.x - 12.0, 12, language.ramp_color("worldbone", 0))
	canvas.draw_string(ThemeDB.fallback_font, rectangle.position + Vector2(6, 14), amount, HORIZONTAL_ALIGNMENT_RIGHT, rectangle.size.x - 12.0, 12, language.ui_color("text_primary"))


static func resource_amount_label(value: int, maximum: int) -> String:
	# Preserve positive milli-units without promising a spendable whole point.
	# In particular, living sub-point Health must not look identical to defeat.
	if value > 0 and value < 1000:
		return "<1/%d" % (maximum / 1000)
	return "%d/%d" % [value / 1000, maximum / 1000]


func _draw_spell_cell(canvas: CanvasItem, rectangle: Rect2, state: PlayerState, ability_catalog: AbilityCatalog, slot_index: int, button_index: int, tick_rate: int, copy: Dictionary, capacity: Vector2i = Vector2i(-1, -1), cast_gate: String = "", preferences: PlayerPreferences = null) -> void:
	var wire_id: int = state.spell_wire_id(slot_index + 1)
	var ability: Dictionary = ability_catalog.ability_from_wire(wire_id)
	var empty := ability.is_empty()
	var element := String(ability.get("element", "dark"))
	var accent := language.element_color(element, "bright") if not empty and language.elements.has(element) else language.ui_color("text_muted")
	var readiness := spell_display_status(state, ability, tick_rate, capacity, cast_gate)
	_draw_panel(canvas, rectangle, 0.95)
	canvas.draw_rect(rectangle, Color(accent, 1.0 if readiness.casting else (0.36 if readiness.waiting else 0.72)), false, 3.0 if readiness.casting else (1.0 if readiness.waiting else 2.0))
	var card := _spell_card_layout(slot_index, ability, button_binding_label(button_index, preferences), rectangle)
	var key_box: Rect2 = card.key_box
	canvas.draw_rect(key_box, Color(accent, 0.18))
	canvas.draw_string(ThemeDB.fallback_font, card.key_at, card.key_label, HORIZONTAL_ALIGNMENT_LEFT, key_box.size.x - 10.0, 10, language.ui_color("text_primary"))
	if not bool(card.mixed):
		_draw_element_glyph(canvas, rectangle.position + Vector2(18, 37), element, accent, empty)
	for heading: Dictionary in card.headings:
		canvas.draw_string(ThemeDB.fallback_font, heading.at, heading.text, HORIZONTAL_ALIGNMENT_LEFT, heading.width, 12, language.ui_color("text_primary") if not empty else language.ui_color("text_muted"))
	if empty:
		canvas.draw_string(ThemeDB.fallback_font, card.summary_at, String(copy.get("loom", "WEAVE AT LOOM")), HORIZONTAL_ALIGNMENT_LEFT, card.summary_width, 9, language.ui_color("text_muted"))
		return
	var status := String(readiness.label)
	canvas.draw_string(ThemeDB.fallback_font, card.summary_at, card.summary, HORIZONTAL_ALIGNMENT_LEFT, card.summary_width, 10, language.ui_color("text_secondary"))
	if not status.is_empty():
		canvas.draw_string(ThemeDB.fallback_font, card.status_at, status, HORIZONTAL_ALIGNMENT_LEFT, card.status_width, 10, language.ui_color("pending") if readiness.kind in ["cooldown", "startup"] else language.ui_color("danger"))
	var track: Rect2 = card.track
	canvas.draw_rect(track, Color(accent, 0.15))
	canvas.draw_rect(Rect2(track.position, Vector2(track.size.x * float(readiness.progress), track.size.y)), Color(accent, 0.42 if readiness.waiting else 0.9))


static func spell_readiness(state: PlayerState, ability: Dictionary, tick_rate: int = 120, capacity: Vector2i = Vector2i(-1, -1), cast_gate: String = "") -> Dictionary:
	if state == null or state.health <= 0 or ability.is_empty():
		return {"kind": "unavailable", "label": "UNAVAILABLE", "progress": 0.0}
	var wire := int(ability.get("wire_id", 0))
	if state.pending_cast_wire_id != 0 or cast_gate == "startup_commitment":
		var active_cast := wire > 0 and state.pending_cast_wire_id == wire
		var progress := 0.0
		if active_cast:
			var config := SimConfig.new(tick_rate)
			if config.is_valid():
				# This cast is already paid. Read the same quantized startup as
				# authority; other slots must not borrow its progress or timing.
				var startup_ticks := config.milliseconds_to_ticks(int(ability.get("startup_ms", 0)))
				progress = clampf(1.0 - float(state.pending_cast_ticks) / float(maxi(1, startup_ticks)), 0.0, 1.0)
		return {"kind": "startup", "label": "CASTING" if active_cast else "FINISH CAST", "progress": progress}
	if not cast_gate.is_empty():
		return {"kind": "control", "label": "CONTROLLED", "progress": 0.0}
	return _spell_availability(state, ability, tick_rate, capacity)


static func _spell_availability(state: PlayerState, ability: Dictionary, tick_rate: int, capacity: Vector2i) -> Dictionary:
	var wire := int(ability.get("wire_id", 0))
	var cooldown := state.spell_cooldown_for_wire(wire)
	if cooldown > 0:
		var total := maxi(1, ceili(float(int(ability.get("cooldown_ms", 1)) * maxi(1, tick_rate)) / 1000.0))
		return {"kind": "cooldown", "label": "%.1fs" % (float(cooldown) / float(maxi(1, tick_rate))), "progress": clampf(1.0 - float(cooldown) / float(total), 0.0, 1.0)}
	var needed := CombatSystem.cast_capacity_requirement(wire)
	if (capacity.x >= 0 and needed.x > capacity.x) or (capacity.y >= 0 and needed.y > capacity.y):
		return {"kind": "capacity", "label": "MATERIAL LIMIT" if needed.x > 0 else "FIELD LIMIT", "progress": 0.0}
	if not spell_is_affordable(state, ability):
		return {"kind": "flux", "label": "NEED %d F" % int(ability.get("flux_cost", 0)), "progress": 0.0}
	return {"kind": "ready", "label": "", "progress": 1.0}


static func spell_display_status(state: PlayerState, ability: Dictionary, tick_rate: int = 120, capacity: Vector2i = Vector2i(-1, -1), cast_gate: String = "") -> Dictionary:
	var result := spell_readiness(state, ability, tick_rate, capacity, cast_gate)
	var casting: bool = result.kind == "startup" and int(ability.get("wire_id", 0)) > 0 and state.pending_cast_wire_id == int(ability.wire_id)
	var waiting: bool = result.kind == "startup" and not casting
	if waiting:
		# Read secondary restrictions without clearing or copying paid authority.
		# This is a display model, not another cast-admission decision.
		result = _spell_availability(state, ability, tick_rate, capacity)
		if result.kind == "ready":
			result.kind = "waiting"
			result.progress = 0.0
	result.casting = casting
	result.waiting = waiting
	return result


static func cast_wait_label(state: PlayerState, cast_gate: String = "") -> String:
	if state == null or state.health <= 0: return ""
	if state.pending_cast_wire_id > 0: return "OTHER SPELLS WAIT"
	return "SPELLS WAIT" if cast_gate == "startup_commitment" else ""


static func hidden_cast_status(state: PlayerState, catalog: AbilityCatalog, active_layer: int, preferences: PlayerPreferences = null, tick_rate: int = 120) -> Dictionary:
	if state == null or catalog == null or state.health <= 0 or state.pending_cast_wire_id <= 0:
		return {}
	if active_layer < 0 or active_layer >= PlayerState.SPELL_SLOT_COUNT / PlayerState.SPELL_BUTTON_COUNT:
		return {}
	var wire := state.pending_cast_wire_id
	var ability := catalog.ability_from_wire(wire)
	if ability.is_empty(): return {}
	for button: int in PlayerState.SPELL_BUTTON_COUNT:
		if state.spell_wire_id(active_layer * PlayerState.SPELL_BUTTON_COUNT + button + 1) == wire:
			return {}
	var slot := state.spell_slot_index_for_wire(wire)
	var binding := SpellLoomPresenter.slot_binding_label(slot, preferences) if slot >= 0 else ""
	var label := "CASTING " + spell_header_label(ability) + " " + AbilityCatalog._spell_family(ability).to_upper()
	if not binding.is_empty(): label += " / " + binding
	return {"wire_id": wire, "slot": slot, "element": String(ability.get("element", "")), "label": label,
		"progress": spell_readiness(state, ability, tick_rate).progress}


static func spell_header_label(ability: Dictionary) -> String:
	if ability.is_empty(): return "EMPTY"
	var mask := int(ability.get("element_mask", 0))
	if mask > 0 and (mask & (mask - 1)) != 0:
		var payload := MixtureCatalog.definition(mask)
		if not payload.is_empty(): return String(payload.display_name)
	# Preserve all original singleton headings, including Air's public name.
	var element := String(ability.get("element", ""))
	return "AIR" if element == "wind" else element.to_upper()


static func spell_card_model(ability: Dictionary, key_label: String, rectangle: Rect2 = Rect2(0, 0, 142, 70), font: Font = null) -> Dictionary:
	if font == null: font = ThemeDB.fallback_font
	var mask := int(ability.get("element_mask", 0))
	var mixed := mask > 0 and (mask & (mask - 1)) != 0 and not MixtureCatalog.definition(mask).is_empty()
	var key_width := clampf(font.get_string_size(key_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 10.0, 19.0, 64.0)
	var title := spell_header_label(ability)
	var header_x := key_width + 15.0
	var first_width := rectangle.size.x - header_x - 6.0
	var headings: Array[Dictionary] = []
	if mixed and font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x > first_width:
		# Keep the complete payload name. The second line uses the whole card;
		# an unusually wide binding may leave the first title line empty.
		var first := ""
		var rest := ""
		for word: String in title.split(" ", false):
			var candidate := word if first.is_empty() else first + " " + word
			if rest.is_empty() and font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x <= first_width:
				first = candidate
			else:
				rest += ("" if rest.is_empty() else " ") + word
		if not first.is_empty(): headings.append({"text": first, "at": rectangle.position + Vector2(header_x, 16), "width": first_width})
		headings.append({"text": rest, "at": rectangle.position + Vector2(8, 33), "width": rectangle.size.x - 16.0})
	else:
		headings.append({"text": title, "at": rectangle.position + Vector2(header_x, 16 if mixed else 21), "width": first_width})
	return {"wire_id": int(ability.get("wire_id", 0)), "element_mask": mask, "mixed": mixed,
		"header": title, "headings": headings, "key_label": key_label,
		"key_box": Rect2(rectangle.position + Vector2(8, 3 if mixed else 7), Vector2(key_width, 16 if mixed else 20)),
		"key_at": rectangle.position + Vector2(13, 15 if mixed else 21),
		"summary": spell_summary_label(ability), "summary_at": rectangle.position + Vector2(8 if mixed else 34, 48 if mixed else 43),
		"summary_width": rectangle.size.x - (16.0 if mixed else 40.0),
		"status_at": rectangle.position + Vector2(8 if mixed else 10, 62 if mixed else 57),
		"status_width": rectangle.size.x - (16.0 if mixed else 20.0),
		"track": Rect2(rectangle.position + Vector2(10, rectangle.size.y - (4 if mixed else 8)), Vector2(rectangle.size.x - 20, 3))}


func _spell_card_layout(slot: int, ability: Dictionary, key_label: String, rectangle: Rect2, font: Font = null) -> Dictionary:
	# Only text/geometry is retained. Resource use, cooldowns, cast progress,
	# capacity and control locks are still sampled from authority every draw.
	if font == null: font = ThemeDB.fallback_font
	if slot < 0 or slot >= PlayerState.SPELL_SLOT_COUNT: return spell_card_model(ability, key_label, rectangle, font)
	var row: Dictionary = _spell_card_layouts.get(slot, {})
	if not row.is_empty() and row.ability == ability and row.key_label == key_label and row.rectangle == rectangle and row.font_id == font.get_instance_id():
		return row.model
	var model := spell_card_model(ability, key_label, rectangle, font)
	_spell_card_layouts[slot] = {"ability": ability.duplicate(true), "key_label": key_label, "rectangle": rectangle, "font_id": font.get_instance_id(), "model": model}
	_spell_card_layout_builds += 1
	return model


static func button_binding_label(button_index: int, preferences: PlayerPreferences) -> String:
	if preferences == null or button_index < 0 or button_index >= PlayerState.SPELL_BUTTON_COUNT:
		return "?"
	var label := BindingLabels.action_label(StringName("spell_%d" % (button_index + 1)), preferences)
	return label if not label.is_empty() else "-"


static func binding_layer_label(layer: int, preferences: PlayerPreferences) -> String:
	if layer == 0:
		return "PLAIN SPELLS"
	if preferences == null:
		return "? SPELLS"
	var label := BindingLabels.action_label(&"spell_layer_ctrl" if layer == 1 else &"spell_layer_alt", preferences)
	return "%s SPELLS" % label if not label.is_empty() else "LAYER UNBOUND"


static func spell_summary_label(ability: Dictionary) -> String:
	var family := AbilityCatalog._spell_family(ability)
	if not family in MixtureCatalog.FAMILIES or String(ability.get("runtime_status", "playable")) != "playable":
		return "DISABLED"
	var label := family.to_upper()
	var cost := int(ability.get("flux_cost", 0))
	return "%s · %s" % [label, "FREE" if cost == 0 else "%d F" % cost]


static func spell_is_affordable(state: PlayerState, ability: Dictionary) -> bool:
	return state != null and state.flux >= maxi(0, int(ability.get("flux_cost", 0))) * 1000


static func _cooldown_for_wire(state: PlayerState, wire_id: int) -> int:
	return state.spell_cooldown_for_wire(wire_id)


func _draw_panel(canvas: CanvasItem, rectangle: Rect2, opacity: float) -> void:
	var step := float((data.get("layout", {}) as Dictionary).get("panel_corner_step", 6))
	var geometry := _panel_geometry(rectangle, step)
	var fill := Color(language.ui_color("panel_fill"), opacity)
	if geometry.mesh != null:
		canvas.draw_mesh(geometry.mesh, null, Transform2D.IDENTITY, fill)
	else:
		canvas.draw_colored_polygon(geometry.points, fill)
	canvas.draw_polyline(geometry.outline, Color(language.ramp_color("aged_brass", 2), 0.72 * opacity), 1.0, false)


func _panel_geometry(rectangle: Rect2, step: float) -> Dictionary:
	# Shape only: colors and opacity stay live. Position and size are explicit
	# keys, so resizing and moving transient cards cannot reuse stale vertices.
	var key: Array = [rectangle, step]
	if _panel_geometries.has(key): return _panel_geometries[key]
	var points := PackedVector2Array([
		rectangle.position + Vector2(step, 0), rectangle.end - Vector2(step, rectangle.size.y),
		rectangle.end - Vector2(0, rectangle.size.y - step), rectangle.end - Vector2(0, step),
		rectangle.end - Vector2(step, 0), rectangle.position + Vector2(step, rectangle.size.y),
		rectangle.position + Vector2(0, rectangle.size.y - step), rectangle.position + Vector2(0, step),
	])
	var outline := points.duplicate()
	outline.append(points[0])
	var indices := Geometry2D.triangulate_polygon(points)
	var vertices := PackedVector3Array()
	for point: Vector2 in points: vertices.append(Vector3(point.x, point.y, 0))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = null
	if _panel_geometries.size() < MAX_PANEL_GEOMETRIES:
		mesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var geometry := {"mesh": mesh, "points": points, "outline": outline, "indices": indices}
	# Never evict a mesh that this frame may already have submitted. Unusual
	# resize histories retain the exact original polygon path at the finite cap.
	if mesh != null: _panel_geometries[key] = geometry
	_panel_geometry_builds += 1
	return geometry


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


func _fail(message: String) -> bool:
	last_error = message
	return false
