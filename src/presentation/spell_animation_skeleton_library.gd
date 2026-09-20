class_name SpellAnimationSkeletonLibrary
extends RefCounted


const SUPPORTED_SCHEMA_VERSION: int = 1
const DEFAULT_PATH := "res://content/visual/spell_animation_skeletons_v1.json"
const EXPECTED_ID := "flux2-spell-animation-skeletons-v1"
const EXPECTED_AUTHORITY := "presentation only; simulation owns spell membership, geometry, timing, collision, resources, damage, control and outcomes"
const REQUIRED_SHAPES: Array[String] = ["projectile", "beam", "spray", "field"]
const REQUIRED_PHASES: Array[String] = ["startup", "release", "travel", "impact", "residue"]

var data: Dictionary = {}
var skeletons: Dictionary = {}
var phase_order: Array[String] = []
var content_hash := ""
var last_error := ""


func load_from_file(path: String = DEFAULT_PATH) -> bool:
	last_error = ""
	content_hash = ""
	if not FileAccess.file_exists(path):
		return _fail("spell animation skeleton manifest does not exist: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("could not open spell animation skeleton manifest: %s" % path)
	var source := file.get_as_text()
	var parsed: Variant = JSON.parse_string(source)
	if not parsed is Dictionary:
		return _fail("spell animation skeleton manifest root must be an object")
	data = parsed
	if not validate():
		return false
	content_hash = source.sha256_text()
	return true


func validate() -> bool:
	last_error = ""
	if int(data.get("schema_version", -1)) != SUPPORTED_SCHEMA_VERSION \
		or String(data.get("id", "")) != EXPECTED_ID \
		or String(data.get("authority", "")) != EXPECTED_AUTHORITY:
		return _fail("spell animation skeleton identity or authority is unsupported")
	var raw_phase_order: Variant = data.get("phase_order", [])
	if not raw_phase_order is Array or (raw_phase_order as Array).size() != REQUIRED_PHASES.size():
		return _fail("spell animation skeletons require exactly five ordered phases")
	phase_order.clear()
	for value: Variant in raw_phase_order:
		var phase_id := String(value)
		if phase_id not in REQUIRED_PHASES or phase_order.has(phase_id):
			return _fail("spell animation phase ids must be unique and canonical")
		phase_order.append(phase_id)
	for phase_id: String in REQUIRED_PHASES:
		if phase_order.find(phase_id) != REQUIRED_PHASES.find(phase_id):
			return _fail("spell animation phase order is not canonical")
	var budgets: Dictionary = data.get("budgets", {})
	if int(budgets.get("maximum_phase_count", 0)) != REQUIRED_PHASES.size() \
		or int(budgets.get("maximum_draw_layers", 0)) < 1 \
		or int(budgets.get("maximum_draw_layers", 0)) > 6 \
		or int(budgets.get("maximum_particle_density", 0)) < 10 \
		or int(budgets.get("maximum_particle_density", 0)) > 50:
		return _fail("spell animation skeleton budgets are unsafe")
	var raw_skeletons: Variant = data.get("skeletons", {})
	if not raw_skeletons is Dictionary or (raw_skeletons as Dictionary).size() != REQUIRED_SHAPES.size():
		return _fail("spell animation skeletons must define exactly four delivery shapes")
	skeletons.clear()
	for shape_id: String in REQUIRED_SHAPES:
		if not (raw_skeletons as Dictionary).has(shape_id):
			return _fail("spell animation skeleton is missing: %s" % shape_id)
		var skeleton: Variant = (raw_skeletons as Dictionary)[shape_id]
		if not skeleton is Dictionary or String((skeleton as Dictionary).get("shape", "")) != shape_id:
			return _fail("spell animation skeleton shape mismatch: %s" % shape_id)
		var phases: Variant = (skeleton as Dictionary).get("phases", [])
		if not phases is Array or (phases as Array).size() != REQUIRED_PHASES.size():
			return _fail("spell animation skeleton phase count is invalid: %s" % shape_id)
		var previous_end := 0.0
		var seen: Dictionary[String, bool] = {}
		for phase_value: Variant in phases:
			if not phase_value is Dictionary:
				return _fail("spell animation phase must be an object: %s" % shape_id)
			var phase: Dictionary = phase_value
			var phase_id := String(phase.get("id", ""))
			var start := float(phase.get("start", -1.0))
			var end := float(phase.get("end", -1.0))
			if phase_id not in REQUIRED_PHASES or seen.has(phase_id) \
				or start < 0.0 or end <= start or end > 1.0 \
				or absf(start - previous_end) > 0.0001 \
				or String(phase.get("draw_family", "")).is_empty() \
				or String(phase.get("cue", "")).is_empty():
				return _fail("spell animation phase bounds or vocabulary are invalid: %s" % shape_id)
			seen[phase_id] = true
			previous_end = end
		if previous_end != 1.0 or seen.size() != REQUIRED_PHASES.size():
			return _fail("spell animation phases must cover exactly 0..1: %s" % shape_id)
		skeletons[shape_id] = (skeleton as Dictionary).duplicate(true)
	return true


func skeleton_for_shape(shape_id: String) -> Dictionary:
	return (skeletons.get(shape_id, {}) as Dictionary).duplicate(true)


func phase_for(shape_id: String, progress: float) -> Dictionary:
	if not skeletons.has(shape_id):
		return {}
	var clamped := clampf(progress, 0.0, 1.0)
	var phases: Array = (skeletons[shape_id] as Dictionary).get("phases", [])
	for phase_value: Variant in phases:
		var phase: Dictionary = phase_value
		var end := float(phase.get("end", 0.0))
		if clamped < end or is_equal_approx(clamped, 1.0) and end >= 1.0:
			return phase.duplicate(true)
	return {}


func _fail(message: String) -> bool:
	last_error = message
	return false
