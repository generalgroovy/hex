class_name ActionTransitionPolicy
extends RefCounted


const DEFAULT_PATH: String = "res://content/gameplay/action_transition_matrix_v1.json"
const EXPECTED_ID: String = "action-transition-matrix-v1"
const EXPECTED_AUTHORITY: String = "authoritative simulation policy; presentation may explain refusals but never changes transition legality"
const BLOCKED_CONTROL_STATES: Array[String] = ["launched", "grappled", "charging", "stunned", "rooted"]
const REQUIRED_MOVEMENT_MODES: Array[String] = [
	"idle", "walk", "sprint", "hop", "double_jump", "slide", "slide_jump",
	"air_dodge", "wave_dash", "wall_kick", "vault", "superglide", "launched",
	"grappled", "charging", "stunned", "rooted", "slowed", "fast_fall", "wall_skim",
	"impact_recovery", "roll",
]
const REQUIRED_SPELL_SHAPES: Array[String] = ["projectile", "beam", "spray", "field"]
const REQUIRED_RULES: Array[Dictionary] = [
	{"from": "movement_any", "to": "spell_start", "allowed": true, "gate": "control_state"},
	{"from": "spell_start", "to": "movement_any", "allowed": true, "gate": "physical_requirements"},
	{"from": "spell_recovery", "to": "spell_start", "allowed": true, "gate": "own_cooldown_resource"},
	{"from": "spell_start", "to": "spell_start", "allowed": false, "gate": "startup_commitment"},
]
const DECLARED_REFUSAL_REASONS: Array[String] = [
	"empty_slot", "kit", "flux", "cooldown", "startup_commitment",
	"control_launched", "control_grappled", "control_charging",
	"control_stunned", "control_rooted",
]
const MAX_CACHED_SOURCE_BYTES := 65_536

# One complete value is replaced on a successful ordinary load, never mutated
# after publication. Readers retain one local entry, so overlapping loads cannot
# pair one source's data with another source's hash. No live policy is retained.
static var _load_cache: Dictionary = {}

var data: Dictionary = {}
var content_hash: String = ""
var last_error: String = ""


func load_from_file(path: String = DEFAULT_PATH) -> bool:
	data = {}
	content_hash = ""
	last_error = ""
	var concrete: bool = get_script() == load("res://src/sim/core/action_transition_policy.gd")
	var source_text := ""
	var parsed: Dictionary
	if concrete:
		# Always open and read the requested path. A path, timestamp or length is
		# not proof that the current bytes match a previously validated policy.
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return _fail("Action transition matrix is missing or invalid JSON")
		source_text = file.get_as_text()
		file.close()
		var cached: Dictionary = _load_cache
		if not cached.is_empty() and source_text == cached.source:
			data = cached.data.duplicate(true)
			content_hash = cached.hash
			return true
		var value: Variant = JSON.parse_string(source_text)
		parsed = value if value is Dictionary else {}
	else:
		# Extensions preserve the preceding helper and validation/callback path.
		parsed = _parsed_dictionary(path)
	if parsed.is_empty():
		return _fail("Action transition matrix is missing or invalid JSON")
	if int(parsed.get("schema_version", 0)) != 1 or String(parsed.get("id", "")) != EXPECTED_ID:
		return _fail("Action transition matrix identity is unsupported")
	if String(parsed.get("authority", "")) != EXPECTED_AUTHORITY:
		return _fail("Action transition matrix authority is invalid")
	var coverage: Dictionary = parsed.get("coverage", {})
	if (
		_sorted_strings(coverage.get("movement_modes", [])) != _sorted_strings(REQUIRED_MOVEMENT_MODES)
		or _sorted_strings(coverage.get("spell_shapes", [])) != _sorted_strings(REQUIRED_SPELL_SHAPES)
	):
		return _fail("Action transition matrix must cover every live movement mode and spell shape")
	var rules: Array = parsed.get("rules", [])
	if rules.size() != REQUIRED_RULES.size():
		return _fail("Action transition matrix requires the exact foundation rule set")
	for required_rule: Dictionary in REQUIRED_RULES:
		if not rules.has(required_rule):
			return _fail("Action transition matrix is missing rule %s" % required_rule)
	var spell_start: Dictionary = parsed.get("spell_start", {})
	if (
		int(spell_start.get("execution_channels", 0)) != 1
		or typeof(spell_start.get("allow_during_movement")) != TYPE_BOOL
		or not bool(spell_start.get("allow_during_movement", false))
		or typeof(spell_start.get("allow_during_recovery")) != TYPE_BOOL
		or not bool(spell_start.get("allow_during_recovery", false))
		or String(spell_start.get("startup_commitment_reason", "")) != "startup_commitment"
		or _sorted_strings(spell_start.get("blocked_control_states", [])) != _sorted_strings(BLOCKED_CONTROL_STATES)
	):
		return _fail("Spell-start transitions must allow movement/recovery and retain one explicit execution channel")
	if _sorted_strings(parsed.get("declared_refusal_reasons", [])) != _sorted_strings(DECLARED_REFUSAL_REASONS):
		return _fail("Action transition refusal vocabulary is incomplete")
	data = parsed
	content_hash = CanonicalContent.sha256(data)
	if concrete and source_text.to_utf8_buffer().size() <= MAX_CACHED_SOURCE_BYTES:
		# Both cold and warm results remain independently writable. The cache's
		# private deep copy is never handed to a caller or mutated after commit.
		_load_cache = {"source": source_text, "data": data.duplicate(true), "hash": content_hash}
	return true


func cast_gate_reason(state: PlayerState) -> String:
	if state == null or data.is_empty():
		return "invalid_state"
	if state.pending_cast_wire_id != 0:
		return String((data["spell_start"] as Dictionary).get("startup_commitment_reason", "startup_commitment"))
	var control_id := control_state_id(state.control_state)
	if control_id in BLOCKED_CONTROL_STATES:
		return "control_%s" % control_id
	return ""


func allows_during_recovery() -> bool:
	return not data.is_empty() and bool((data["spell_start"] as Dictionary).get("allow_during_recovery", false))


func refusal_reason_is_declared(reason: String) -> bool:
	return reason in DECLARED_REFUSAL_REASONS


static func repository_hash(path: String = DEFAULT_PATH) -> String:
	var parsed := _parsed_dictionary(path)
	return CanonicalContent.sha256(parsed) if not parsed.is_empty() else ""


static func control_state_id(control_state: int) -> String:
	match control_state:
		PlayerState.ControlState.FREE:
			return "free"
		PlayerState.ControlState.LAUNCHED:
			return "launched"
		PlayerState.ControlState.GRAPPLED:
			return "grappled"
		PlayerState.ControlState.CHARGING:
			return "charging"
		PlayerState.ControlState.STUNNED:
			return "stunned"
		PlayerState.ControlState.ROOTED:
			return "rooted"
		PlayerState.ControlState.SLOWED:
			return "slowed"
	return "unknown"


static func _parsed_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


static func _sorted_strings(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if values is Array:
		for value: Variant in values:
			result.append(String(value))
	result.sort()
	return result


func _fail(message: String) -> bool:
	last_error = message
	data = {}
	content_hash = ""
	return false
