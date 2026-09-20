class_name InterceptionFeedback
extends RefCounted


# Presentation only. Authority supplies the outcome and projectile-center anchor;
# this model never compares strength, finds a projectile, or changes simulation.
const ElementGlyph = preload("res://src/presentation/element_glyph_renderer.gd")

const EVENT_TYPE := "spray_intercepted"
const MAX_CUES: int = 12
const MAX_AGGREGATE_COUNT: int = 99
const CUE_DURATION_SECONDS: float = 0.62
const MAX_ABSOLUTE_COORDINATE: int = 100_000_000
const MAX_ENTITY_ID: int = 0x7fffffff
const MAX_WIRE_ID: int = 65_535

const OUTCOME_SPRAY_WINS: int = 1
const OUTCOME_SPRAY_STOPPED: int = 2
const OUTCOME_REACTION: int = 3

var cues: Array[Dictionary] = []
# Explicit loss accounting for the bounded presentation lane. Integration may
# surface this in diagnostics; gameplay outcome remains authoritative elsewhere.
var dropped_count: int = 0
var aggregated_count: int = 0


func clear() -> void:
	cues.clear()
	dropped_count = 0
	aggregated_count = 0


# Returns an empty Dictionary for another event type. A matching event returns
# an explicit admission receipt so saturation is never indistinguishable from
# successful presentation.
func ingest(event: Dictionary, catalog: AbilityCatalog) -> Dictionary:
	if String(event.get("type", "")) != EVENT_TYPE:
		return {}
	var cue := describe(event, catalog)
	if cue.is_empty():
		return {"accepted": false, "aggregated": false, "dropped": 0}
	for index: int in range(cues.size() - 1, -1, -1):
		var existing: Dictionary = cues[index]
		# Events ingested before the next advance belong to one presentation frame.
		# Aggregate only an exact known point and identity/outcome tuple.
		if not is_equal_approx(float(existing.get("remaining", 0.0)), CUE_DURATION_SECONDS):
			continue
		if _aggregation_key(existing) != _aggregation_key(cue):
			continue
		var count := int(existing.get("count", 1))
		if count >= MAX_AGGREGATE_COUNT:
			_record_drop()
			return {"accepted": false, "aggregated": false, "dropped": 1}
		existing["count"] = count + 1
		existing["label"] = _outcome_label(int(existing["outcome"]), count + 1)
		cues[index] = existing
		aggregated_count = mini(MAX_ENTITY_ID, aggregated_count + 1)
		return {"accepted": true, "aggregated": true, "dropped": 0}
	var dropped := 0
	if cues.size() >= MAX_CUES:
		cues.pop_front()
		_record_drop()
		dropped = 1
	cues.append(cue)
	return {"accepted": true, "aggregated": false, "dropped": dropped}


func advance(delta_seconds: float) -> void:
	if not is_finite(delta_seconds) or delta_seconds <= 0.0:
		return
	for index: int in range(cues.size() - 1, -1, -1):
		var cue: Dictionary = cues[index]
		cue["remaining"] = float(cue.get("remaining", 0.0)) - delta_seconds
		if float(cue["remaining"]) <= 0.0:
			cues.remove_at(index)
		else:
			cues[index] = cue


func draw(canvas: CanvasItem, language: VisualLanguage, reduced_effects: bool) -> int:
	if canvas == null or language == null:
		return 0
	var drawn := 0
	for cue: Dictionary in cues:
		if _draw_cue(canvas, language, cue, reduced_effects):
			drawn += 1
	return drawn


static func describe(event: Dictionary, catalog: AbilityCatalog) -> Dictionary:
	if String(event.get("type", "")) != EVENT_TYPE or catalog == null or catalog.content_hash.is_empty():
		return {}
	for key: String in ["owner_id", "source_wire_id", "projectile_id", "other_wire_id", "x", "y", "outcome"]:
		if typeof(event.get(key)) != TYPE_INT:
			return {}
	var owner_id := int(event["owner_id"])
	var source_wire_id := int(event["source_wire_id"])
	var projectile_id := int(event["projectile_id"])
	var other_wire_id := int(event["other_wire_id"])
	var coordinate := Vector2i(int(event["x"]), int(event["y"]))
	var outcome := int(event["outcome"])
	if (
		owner_id <= 0 or owner_id > MAX_ENTITY_ID
		or projectile_id <= 0 or projectile_id > MAX_ENTITY_ID
		or source_wire_id <= 0 or source_wire_id > MAX_WIRE_ID
		or other_wire_id <= 0 or other_wire_id > MAX_WIRE_ID
		or absi(coordinate.x) > MAX_ABSOLUTE_COORDINATE
		or absi(coordinate.y) > MAX_ABSOLUTE_COORDINATE
		or outcome not in [OUTCOME_SPRAY_WINS, OUTCOME_SPRAY_STOPPED, OUTCOME_REACTION]
	):
		return {}
	if source_wire_id not in catalog.runtime_wire_ids or other_wire_id not in catalog.runtime_wire_ids:
		return {}
	var spray: Dictionary = catalog.ability_from_wire(source_wire_id)
	var other: Dictionary = catalog.ability_from_wire(other_wire_id)
	if String(spray.get("shape", "")) != "spray" or String(other.get("shape", "")) != "projectile":
		return {}
	var spray_element := String(spray.get("element", ""))
	var other_element := String(other.get("element", ""))
	if spray_element.is_empty() or other_element.is_empty():
		return {}
	return {
		"position": Vector2(coordinate) / 1000.0,
		"fixed_x": coordinate.x,
		"fixed_y": coordinate.y,
		"owner_id": owner_id,
		"projectile_id": projectile_id,
		"source_wire_id": source_wire_id,
		"other_wire_id": other_wire_id,
		"spray_element": spray_element,
		"other_element": other_element,
		"outcome": outcome,
		"count": 1,
		"label": _outcome_label(outcome, 1),
		"remaining": CUE_DURATION_SECONDS,
		"duration": CUE_DURATION_SECONDS,
	}


# Read-only primitive counts/phase for deterministic source tests and review.
# Reduced effects retains the actual contact mark, both identities, and copy.
static func visual_sample(cue: Dictionary, reduced_effects: bool) -> Dictionary:
	var duration := float(cue.get("duration", 0.0))
	var remaining := clampf(float(cue.get("remaining", 0.0)), 0.0, duration)
	if duration <= 0.0:
		return {}
	var phase := 1.0 - remaining / duration
	return {
		"position": cue.get("position", Vector2.ZERO),
		"phase": phase,
		"opacity": clampf(remaining / minf(duration, 0.24), 0.0, 1.0),
		"contact_half_size": 5.0 if reduced_effects else 5.0 + floorf(phase * 3.0) * 2.0,
		"fragment_count": 0 if reduced_effects else 4,
		"glyph_count": 2,
		"label": String(cue.get("label", "")),
	}


static func _draw_cue(canvas: CanvasItem, language: VisualLanguage, cue: Dictionary, reduced_effects: bool) -> bool:
	var spray_element := String(cue.get("spray_element", ""))
	var other_element := String(cue.get("other_element", ""))
	if not language.elements.has(spray_element) or not language.elements.has(other_element):
		return false
	var sample := visual_sample(cue, reduced_effects)
	if sample.is_empty():
		return false
	var position: Vector2 = sample["position"]
	var opacity := float(sample["opacity"])
	var half_size := float(sample["contact_half_size"])
	var outcome := int(cue.get("outcome", 0))
	var spray_color := language.element_color(spray_element, "bright")
	var other_color := language.element_color(other_element, "bright")
	var result_color := spray_color if outcome == OUTCOME_SPRAY_WINS else other_color
	if outcome == OUTCOME_REACTION:
		result_color = language.ui_color("text_primary")
	# A crisp contact cross marks the authoritative point without describing a
	# range or adding a damage margin.
	canvas.draw_rect(Rect2(position - Vector2(half_size, 1.0), Vector2(half_size * 2.0, 2.0)), Color(result_color, opacity), true)
	canvas.draw_rect(Rect2(position - Vector2(1.0, half_size), Vector2(2.0, half_size * 2.0)), Color(result_color, opacity), true)
	canvas.draw_rect(Rect2(position - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), Color(language.element_color(spray_element, "dark"), opacity * 0.86), true)
	if not reduced_effects:
		var phase := float(sample["phase"])
		for direction: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
			var fragment_position := position + direction * (8.0 + floorf(phase * 3.0) * 2.0)
			canvas.draw_rect(Rect2(fragment_position - Vector2.ONE, Vector2(2.0, 2.0)), Color(result_color, opacity * 0.72), true)
	var glyph_opacity := maxf(0.66, opacity)
	ElementGlyph.draw(canvas, language, position + Vector2(-11.0, 0.0), spray_element, 4.5, Color(spray_color, glyph_opacity))
	ElementGlyph.draw(canvas, language, position + Vector2(11.0, 0.0), other_element, 4.5, Color(other_color, glyph_opacity))
	var label := String(sample["label"])
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var label_position := position + Vector2(-width * 0.5, -42.0)
	canvas.draw_rect(Rect2(label_position + Vector2(-4, -12), Vector2(width + 8, 17)), Color(Color("111b20"), glyph_opacity * 0.94))
	canvas.draw_string(font, label_position + Vector2(1.0, 1.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(language.element_color(other_element, "dark"), 0.88 * glyph_opacity))
	canvas.draw_string(font, label_position, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(result_color, glyph_opacity))
	return true


static func _aggregation_key(cue: Dictionary) -> String:
	return "%d:%d:%d:%d:%d" % [int(cue.get("fixed_x", 0)), int(cue.get("fixed_y", 0)), int(cue.get("outcome", 0)), int(cue.get("source_wire_id", 0)), int(cue.get("other_wire_id", 0))]


func _record_drop() -> void:
	dropped_count = mini(MAX_ENTITY_ID, dropped_count + 1)


static func _outcome_label(outcome: int, count: int) -> String:
	var label: String = {
		OUTCOME_SPRAY_WINS: "SPRAY WINS",
		OUTCOME_SPRAY_STOPPED: "SPRAY STOPPED",
		OUTCOME_REACTION: "EQUAL · REACTION",
	}.get(outcome, "")
	return "%s ×%d" % [label, count] if count > 1 else label
