class_name VisualLanguage
extends RefCounted


const DEFAULT_PATH := "res://content/visual/visual_language_v1.json"
const SUPPORTED_SCHEMA_VERSION := 1
const EXPECTED_ID := "flux-visual-language-v1"
const EXPECTED_AUTHORITY := "presentation only; simulation, collision, visibility and outcomes remain authoritative elsewhere"
const REQUIRED_RAMPS := [
	"deep_water", "worldbone", "warm_stone", "timber", "aged_brass",
	"garden", "indigo_roof", "parchment", "health", "flux", "stamina",
]
const REQUIRED_ELEMENTS := [
	"earth", "fire", "water", "wind", "ice", "charge",
	"light", "dark", "spirit", "chaos", "gravity", "time",
]
const ACTIVE_ELEMENTS := ["earth", "fire", "water", "wind", "ice", "charge", "light", "dark"]
const RESERVED_ELEMENT_STYLES := ["spirit", "chaos", "gravity", "time"]
const REQUIRED_REACTION_MATERIALS := ["steam", "flood", "conflagration"]
const REQUIRED_PHASE_COLOR_ROLES := ["dark", "base", "bright", "danger"]
const REQUIRED_STEAM_PHASES := ["forming", "active", "hot", "cool", "decaying"]
const CHARACTER_BODY_HEIGHTS := {"small": 58, "middle": 68, "large": 76}
const CHARACTER_DIRECTIONS := ["south", "south_east", "east", "north_east", "north", "north_west", "west", "south_west"]
const CHARACTER_STATES := ["grounded", "jump", "cast", "hit", "walk", "sprint", "slide", "roll", "walk_b", "sprint_b"]
const REQUIRED_LAYERS := [
	"deep_water", "world_foundation", "traversable_surface", "surface_detail",
	"architecture", "props", "actor_shadow", "actor", "spell_underlay",
	"spell", "spell_impact", "cutaway", "world_prompt", "visibility_mask",
	"combat_hud", "station_overlay", "diagnostics",
]
const REQUIRED_RUBRIC := [
	"cohesion", "silhouette", "material_identity", "world_overview",
	"hud_clarity", "animation_response", "spell_readability",
]

var data: Dictionary = {}
var ramps: Dictionary = {}
var elements: Dictionary = {}
var reaction_materials: Dictionary = {}
var ui: Dictionary = {}
var budgets: Dictionary = {}
var layer_index: Dictionary = {}
var last_error := ""


func load_from_file(path: String = DEFAULT_PATH) -> bool:
	_clear()
	if not FileAccess.file_exists(path):
		return _fail("Visual language does not exist: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("Visual language cannot be opened: %s" % path)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return _fail("Visual language root must be an object")
	data = parsed
	return validate()


func validate() -> bool:
	last_error = ""
	ramps.clear()
	elements.clear()
	reaction_materials.clear()
	ui.clear()
	budgets.clear()
	layer_index.clear()
	if int(data.get("schema_version", -1)) != SUPPORTED_SCHEMA_VERSION:
		return _fail("Unsupported visual language schema")
	if String(data.get("id", "")) != EXPECTED_ID:
		return _fail("Unexpected visual language id")
	if String(data.get("authority", "")) != EXPECTED_AUTHORITY:
		return _fail("Visual language must remain presentation-only")
	var pixel: Dictionary = data.get("pixel_contract", {})
	if _vector2i(pixel.get("design_viewport", [])) != Vector2i(640, 360):
		return _fail("Visual language design viewport must remain 640 x 360")
	if int(pixel.get("output_scale", 0)) != 2 or int(pixel.get("base_unit", 0)) != 2:
		return _fail("Visual language requires the two-pixel output grid")
	if not _numeric_array_equals(pixel.get("supported_camera_percent", []), [50.0, 75.0, 100.0]):
		return _fail("Visual language camera contract must remain 50/75/100")
	for flag: String in ["nearest_neighbor", "snap_translation_to_output_pixel", "subpixel_simulation_preserved"]:
		if not bool(pixel.get(flag, false)):
			return _fail("Visual language pixel flag is required: %s" % flag)
	var perspective: Dictionary = data.get("perspective_contract", {})
	if String(perspective.get("projection", "")) != "top_down_cardinal_with_tilted_facades":
		return _fail("Visual language requires the gameplay-safe cardinal projection")
	if perspective.get("floor_axes", []) != ["screen_horizontal", "screen_vertical"]:
		return _fail("Walkable floor axes must remain screen-cardinal")
	if not is_equal_approx(float(perspective.get("floor_tile_aspect_ratio", 0.0)), 1.0):
		return _fail("Walkable floor tiles must remain square in gameplay projection")
	var facade_ratio := float(perspective.get("maximum_facade_rise_to_footprint_ratio", 0.0))
	if facade_ratio <= 0.0 or facade_ratio > 0.85:
		return _fail("Facade rise exceeds the user-friendly perspective bound")
	if perspective.get("foreground_cutaway_required") != false:
		return _fail("Automatic foreground cutaway is not part of the current opaque-worldbone contract")
	for flag: String in ["cardinal_navigation_unambiguous", "collision_footprint_visible", "door_threshold_visible", "worldbone_opaque", "forbid_diamond_grid", "forbid_art_owned_collision"]:
		if not bool(perspective.get(flag, false)):
			return _fail("Perspective safety flag is required: %s" % flag)
	var character: Dictionary = data.get("character_contract", {})
	if String(character.get("style", "")) != "mature_compact_expressive_cartoon_pixel":
		return _fail("Character style must remain mature compact expressive cartoon pixel art")
	if not _numeric_array_equals(character.get("head_height_ratio", []), [0.20, 0.23]):
		return _fail("Character head/body readability ratio changed")
	if _vector2i(character.get("grounded_cell", [])) != Vector2i(96, 96) or _vector2i(character.get("grounded_pivot", [])) != Vector2i(48, 84):
		return _fail("Character grounded cell/pivot changed outside migration")
	if not _numeric_array_equals(character.get("gameplay_height_pixels", []), [58.0, 76.0]) \
		or not _numeric_array_equals(character.get("outline_pixels", []), [1.0, 2.0]) \
		or not _numeric_array_equals(character.get("material_ramp_colors", []), [3.0, 5.0]):
		return _fail("Character gameplay-scale pixel budget changed")
	var body_heights: Dictionary = character.get("body_heights", {})
	if body_heights.size() != CHARACTER_BODY_HEIGHTS.size():
		return _fail("Character templates require exactly Small, Middle and Large")
	for body: String in CHARACTER_BODY_HEIGHTS:
		var height: Variant = body_heights.get(body)
		if (not height is int and not height is float) or float(height) != float(CHARACTER_BODY_HEIGHTS[body]):
			return _fail("Character body height must match the registered three-size template: " + body)
	if character.get("required_directions", []) != CHARACTER_DIRECTIONS \
		or character.get("required_silhouette_states", []) != CHARACTER_STATES:
		return _fail("Character review requires eight headings and ten action/contact rows")
	if String(character.get("portrait_source", "")) != "south_grounded_occupied_top_third":
		return _fail("Character portraits must derive from the occupied front-model top third")
	for flag: String in ["separate_ground_shadow", "preserve_sensible_anatomy", "preserve_fixed_body_scale", "forbid_photorealistic_rendering", "forbid_sexualized_design"]:
		if not bool(character.get(flag, false)):
			return _fail("Character readability/safety flag is required: %s" % flag)
	var layers: Array = data.get("layers", [])
	if layers != REQUIRED_LAYERS:
		return _fail("Visual layer order differs from the production contract")
	for index: int in layers.size():
		layer_index[String(layers[index])] = index
	ramps = data.get("ramps", {})
	if ramps.size() != REQUIRED_RAMPS.size():
		return _fail("Visual language ramp count changed")
	for ramp_id: String in REQUIRED_RAMPS:
		var ramp: Array = ramps.get(ramp_id, [])
		if ramp.size() != 5:
			return _fail("Visual ramp must expose five ordered values: %s" % ramp_id)
		for color_value: Variant in ramp:
			if not _valid_color(String(color_value)):
				return _fail("Visual ramp contains an invalid color: %s" % ramp_id)
	elements = data.get("elements", {})
	var availability: Dictionary = data.get("element_availability", {})
	if availability.get("active", []) != ACTIVE_ELEMENTS or availability.get("reserved_style_only", []) != RESERVED_ELEMENT_STYLES:
		return _fail("Visual language must distinguish eight active elements from four reserved styles")
	if elements.size() != REQUIRED_ELEMENTS.size():
		return _fail("Visual language must define all twelve element families")
	var shapes: Dictionary = {}
	for element_id: String in REQUIRED_ELEMENTS:
		var element: Dictionary = elements.get(element_id, {})
		for key: String in ["dark", "base", "bright"]:
			if not _valid_color(String(element.get(key, ""))):
				return _fail("Element color is invalid: %s/%s" % [element_id, key])
		var shape := String(element.get("shape", ""))
		var cadence := String(element.get("cadence", ""))
		if shape.is_empty() or cadence.is_empty() or shapes.has(shape):
			return _fail("Element shape/cadence must be present and shape-unique: %s" % element_id)
		shapes[shape] = true
		var phases: Variant = element.get("phases", {})
		if not phases is Dictionary:
			return _fail("Element phases must be an object: %s" % element_id)
		for phase_id: Variant in phases:
			if not phase_id is String or String(phase_id).is_empty() or not _valid_phase_palette(phases[phase_id]):
				return _fail("Element phase palette is invalid: %s/%s" % [element_id, String(phase_id)])
	reaction_materials = data.get("reaction_materials", {})
	if reaction_materials.size() < REQUIRED_REACTION_MATERIALS.size():
		return _fail("Visual language is missing required reaction materials")
	for reaction_id: String in REQUIRED_REACTION_MATERIALS:
		var reaction: Dictionary = reaction_materials.get(reaction_id, {})
		for key: String in ["dark", "base", "bright"]:
			if not _valid_color(String(reaction.get(key, ""))):
				return _fail("Reaction material color is invalid: %s/%s" % [reaction_id, key])
		if String(reaction.get("shape", "")).is_empty() or String(reaction.get("cadence", "")).is_empty():
			return _fail("Reaction material shape/cadence is missing: %s" % reaction_id)
		var reaction_phases: Variant = reaction.get("phases", {})
		if not reaction_phases is Dictionary:
			return _fail("Reaction phases must be an object: %s" % reaction_id)
		if reaction_id == "steam":
			for phase_id: String in REQUIRED_STEAM_PHASES:
				if not _valid_phase_palette(reaction_phases.get(phase_id, {})):
					return _fail("Steam phase palette is invalid: %s" % phase_id)
		for phase_id: Variant in reaction_phases:
			if not phase_id is String or String(phase_id).is_empty() or not _valid_phase_palette(reaction_phases[phase_id]):
				return _fail("Reaction phase palette is invalid: %s/%s" % [reaction_id, String(phase_id)])
	ui = data.get("ui", {})
	for key: String in ["panel_fill", "panel_fill_strong", "scrim", "text_primary", "text_secondary", "text_muted", "focus", "danger", "pending"]:
		if not _valid_color(String(ui.get(key, ""))):
			return _fail("UI color is invalid: %s" % key)
	for key: String in ["panel_padding", "cell_gap", "outline_thin", "outline_regular", "outline_emphasis", "corner_step", "prompt_maximum_width", "combat_hud_maximum_height"]:
		if int(ui.get(key, 0)) <= 0:
			return _fail("UI metric must be positive: %s" % key)
	budgets = data.get("budgets", {})
	for key: String in budgets:
		if int(budgets[key]) <= 0:
			return _fail("Visual budget must be positive: %s" % key)
	if int(budgets.get("maximum_combat_hud_coverage_percent", 100)) > 20:
		return _fail("Combat HUD coverage budget may not exceed 20 percent")
	var rubric: Dictionary = data.get("rubric", {})
	if rubric.get("categories", []) != REQUIRED_RUBRIC:
		return _fail("Visual rubric category order changed")
	if int(rubric.get("minimum_each", 0)) < 4 or float(rubric.get("minimum_mean", 0.0)) < 4.5:
		return _fail("Visual quality rubric cannot be weakened")
	if bool(rubric.get("automatic_acceptance", true)):
		return _fail("Visual candidates require human review")
	return true


func ramp(ramp_id: String) -> Array[Color]:
	var output: Array[Color] = []
	for value: Variant in ramps.get(ramp_id, []):
		output.append(Color(String(value)))
	return output


func ramp_color(ramp_id: String, index: int) -> Color:
	var values: Array = ramps.get(ramp_id, [])
	return Color(String(values[clampi(index, 0, values.size() - 1)])) if not values.is_empty() else Color.MAGENTA


func ui_color(key: String) -> Color:
	return Color(String(ui.get(key, "#ff00ff")))


func ui_metric(key: String) -> int:
	return int(ui.get(key, 0))


func element_color(element_id: String, value: String = "base") -> Color:
	var element: Dictionary = elements.get(element_id, {})
	return Color(String(element.get(value, "#ff00ff")))


func element_shape(element_id: String) -> String:
	return String((elements.get(element_id, {}) as Dictionary).get("shape", ""))


func element_cadence(element_id: String) -> String:
	return String((elements.get(element_id, {}) as Dictionary).get("cadence", ""))


func reaction_color(reaction_id: String, value: String = "base") -> Color:
	var reaction: Dictionary = reaction_materials.get(reaction_id, {})
	return Color(String(reaction.get(value, "#ff00ff")))


func element_phase_color(element_id: String, phase: String, value: String = "base") -> Color:
	var element: Dictionary = elements.get(element_id, {})
	var phases: Dictionary = element.get("phases", {})
	var phase_palette: Dictionary = phases.get(phase, {})
	return Color(String(phase_palette.get(value, element.get(value, "#ff00ff"))))


func reaction_phase_color(reaction_id: String, phase: String, value: String = "base") -> Color:
	var reaction: Dictionary = reaction_materials.get(reaction_id, {})
	var phases: Dictionary = reaction.get("phases", {})
	var phase_palette: Dictionary = phases.get(phase, {})
	return Color(String(phase_palette.get(value, reaction.get(value, "#ff00ff"))))


func reaction_shape(reaction_id: String) -> String:
	return String((reaction_materials.get(reaction_id, {}) as Dictionary).get("shape", ""))


func reaction_cadence(reaction_id: String) -> String:
	return String((reaction_materials.get(reaction_id, {}) as Dictionary).get("cadence", ""))


func content_hash() -> String:
	var canonical := JSON.stringify(data, "", true)
	return canonical.sha256_text()


func _clear() -> void:
	data.clear()
	ramps.clear()
	elements.clear()
	reaction_materials.clear()
	ui.clear()
	budgets.clear()
	layer_index.clear()
	last_error = ""


func _fail(message: String) -> bool:
	ramps.clear()
	elements.clear()
	reaction_materials.clear()
	ui.clear()
	budgets.clear()
	layer_index.clear()
	last_error = message
	return false


static func _valid_color(value: String) -> bool:
	return value.length() in [7, 9] and value.begins_with("#") and Color.html_is_valid(value)


static func _valid_phase_palette(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for role: String in REQUIRED_PHASE_COLOR_ROLES:
		if not _valid_color(String((value as Dictionary).get(role, ""))):
			return false
	return true


static func _vector2i(value: Variant) -> Vector2i:
	if not value is Array or (value as Array).size() != 2:
		return Vector2i(-1, -1)
	return Vector2i(int((value as Array)[0]), int((value as Array)[1]))


static func _numeric_array_equals(value: Variant, expected: Array[float]) -> bool:
	if not value is Array or (value as Array).size() != expected.size():
		return false
	for index: int in expected.size():
		var actual_value: Variant = (value as Array)[index]
		if typeof(actual_value) not in [TYPE_INT, TYPE_FLOAT] or not is_equal_approx(float(actual_value), expected[index]):
			return false
	return true
