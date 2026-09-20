extends FluxTestSuite


const Feedback = preload("res://src/presentation/interception_feedback.gd")
const ABILITY_PATH := "res://content/abilities/foundation_abilities_v1.json"

var catalog: AbilityCatalog
var spray_wire: int = 0
var projectile_wire: int = 0


func run() -> int:
	catalog = AbilityCatalog.new()
	check(catalog.load_from_file(ABILITY_PATH), "interception feedback loads the authoritative ability identities")
	for wire_id: int in catalog.runtime_wire_ids:
		var ability: Dictionary = catalog.ability_from_wire(wire_id)
		if spray_wire == 0 and String(ability.get("shape", "")) == "spray":
			spray_wire = wire_id
	var spray_element := String(catalog.ability_from_wire(spray_wire).get("element", ""))
	for wire_id: int in catalog.runtime_wire_ids:
		var ability: Dictionary = catalog.ability_from_wire(wire_id)
		if String(ability.get("shape", "")) == "projectile" and String(ability.get("element", "")) != spray_element:
			projectile_wire = wire_id
			break
	check(spray_wire > 0 and projectile_wire > 0, "fixture resolves live Spray and projectile wire identities")
	_test_outcomes_and_actual_anchor()
	_test_reduced_essential_readability()
	_test_finite_lifetime_and_bounds()
	_test_same_frame_aggregation_and_visible_loss()
	_test_malformed_events_fail_closed()
	return finish("interception-feedback")


func _event(outcome: int = Feedback.OUTCOME_SPRAY_WINS, x: int = 384_250, y: int = 211_750) -> Dictionary:
	return {
		"type": Feedback.EVENT_TYPE,
		"owner_id": 2,
		"source_wire_id": spray_wire,
		"projectile_id": 1007,
		"other_wire_id": projectile_wire,
		"x": x,
		"y": y,
		"outcome": outcome,
	}


func _test_outcomes_and_actual_anchor() -> void:
	var expected := ["", "SPRAY WINS", "SPRAY STOPPED", "EQUAL · REACTION"]
	for outcome: int in range(1, 4):
		var event := _event(outcome)
		var before := event.duplicate(true)
		var cue := Feedback.describe(event, catalog)
		check(not cue.is_empty(), "outcome %d produces feedback" % outcome)
		equal(cue.position, Vector2(384.25, 211.75), "feedback uses exact authoritative contact coordinates")
		equal(cue.label, expected[outcome], "outcome %d has explicit player-facing copy" % outcome)
		equal(cue.outcome, outcome, "presentation retains the reported outcome without deriving strength")
		equal(event, before, "describing feedback cannot mutate its authoritative event")


func _test_reduced_essential_readability() -> void:
	var cue := Feedback.describe(_event(Feedback.OUTCOME_SPRAY_STOPPED), catalog)
	var full := Feedback.visual_sample(cue, false)
	var reduced := Feedback.visual_sample(cue, true)
	equal(full.glyph_count, 2, "full feedback shows both element identities")
	equal(reduced.glyph_count, 2, "reduced feedback retains both element identities")
	equal(reduced.label, "SPRAY STOPPED", "reduced feedback retains the essential outcome text")
	equal(reduced.contact_half_size, 5.0, "reduced feedback retains a finite contact-point mark")
	equal(reduced.fragment_count, 0, "reduced feedback removes optional moving fragments")
	equal(full.fragment_count, 4, "full feedback uses a fixed four-fragment accent")


func _test_finite_lifetime_and_bounds() -> void:
	var feedback := Feedback.new()
	var receipt := feedback.ingest(_event(), catalog)
	check(receipt.accepted and receipt.dropped == 0, "valid authoritative event is admitted")
	equal(feedback.cues.size(), 1, "one event owns one bounded cue")
	feedback.advance(Feedback.CUE_DURATION_SECONDS * 0.5)
	equal(feedback.cues.size(), 1, "cue remains during its finite lifetime")
	var middle := Feedback.visual_sample(feedback.cues[0], false)
	check(float(middle.phase) > 0.0 and float(middle.phase) < 1.0, "finite cue exposes bounded progress")
	feedback.advance(Feedback.CUE_DURATION_SECONDS * 0.5)
	equal(feedback.cues.size(), 0, "cue expires exactly without a retained node or timer")
	feedback.advance(NAN)
	equal(feedback.cues.size(), 0, "non-finite frame delta cannot create or retain feedback")


func _test_same_frame_aggregation_and_visible_loss() -> void:
	var feedback := Feedback.new()
	var first := feedback.ingest(_event(), catalog)
	var second_event := _event()
	second_event.projectile_id += 1
	var second := feedback.ingest(second_event, catalog)
	check(first.accepted and second.accepted and second.aggregated, "same-frame exact-point outcomes aggregate")
	equal(feedback.cues.size(), 1, "aggregation avoids duplicate visual objects")
	equal(feedback.cues[0].count, 2, "aggregated cue reports its exact admitted count")
	equal(feedback.cues[0].label, "SPRAY WINS ×2", "aggregation remains visible to the player")
	equal(feedback.aggregated_count, 1, "aggregation is measurable")
	feedback.advance(0.001)
	var later := feedback.ingest(second_event, catalog)
	check(later.accepted and not later.aggregated, "later-frame event remains a distinct confirmation")
	feedback.clear()
	for index: int in range(Feedback.MAX_CUES):
		var receipt := feedback.ingest(_event(Feedback.OUTCOME_SPRAY_WINS, 100_000 + index * 1000, 200_000), catalog)
		check(receipt.accepted and receipt.dropped == 0, "cue %d fits the finite lane" % index)
	var overflow := feedback.ingest(_event(Feedback.OUTCOME_SPRAY_WINS, 999_000, 200_000), catalog)
	check(overflow.accepted and overflow.dropped == 1, "bounded lane explicitly reports oldest-cue displacement")
	equal(feedback.cues.size(), Feedback.MAX_CUES, "interception feedback cannot grow past twelve cues")
	equal(feedback.dropped_count, 1, "presentation displacement remains measurable")
	equal(feedback.cues[0].position, Vector2(101, 200), "deterministic overflow removes the oldest cue")
	feedback.clear()
	equal(feedback.dropped_count, 0, "clear resets the lane diagnostics with its cues")


func _test_malformed_events_fail_closed() -> void:
	var malformed: Array[Dictionary] = []
	var wrong_type := _event()
	wrong_type.type = "spray_hit"
	malformed.append(wrong_type)
	for replacement: Variant in [0, 4, "1"]:
		var invalid_outcome := _event()
		invalid_outcome.outcome = replacement
		malformed.append(invalid_outcome)
	for key: String in ["owner_id", "source_wire_id", "projectile_id", "other_wire_id"]:
		var invalid_id := _event()
		invalid_id[key] = 0
		malformed.append(invalid_id)
	var invalid_coordinate := _event()
	invalid_coordinate.x = Feedback.MAX_ABSOLUTE_COORDINATE + 1
	malformed.append(invalid_coordinate)
	var crossed_shapes := _event()
	crossed_shapes.source_wire_id = projectile_wire
	malformed.append(crossed_shapes)
	var wrong_other_shape := _event()
	wrong_other_shape.other_wire_id = spray_wire
	malformed.append(wrong_other_shape)
	var feedback := Feedback.new()
	for event: Dictionary in malformed:
		var before_size := feedback.cues.size()
		var receipt := feedback.ingest(event, catalog)
		if String(event.get("type", "")) == Feedback.EVENT_TYPE:
			check(not receipt.accepted, "malformed interception returns explicit refusal")
		else:
			check(receipt.is_empty(), "unrelated event is ignored without claiming refusal")
		equal(feedback.cues.size(), before_size, "malformed or unrelated event cannot add feedback")
	equal(feedback.dropped_count, 0, "invalid input is refusal, not capacity loss")
