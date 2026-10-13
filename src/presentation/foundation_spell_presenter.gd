class_name FoundationSpellPresenter
extends RefCounted


const DEFAULT_PATH := "res://content/visual/foundation_spell_visuals_v1.json"
const PixelEffects = preload("res://src/presentation/pixel_spell_effects.gd")
const ElementGlyphRendererScript = preload("res://src/presentation/element_glyph_renderer.gd")
const EXPECTED_ID := "foundation-spell-visuals-v4-first-eight-burst"
const EXPECTED_AUTHORITY := "presentation only; simulation owns spell membership, geometry, timing, collision, resources, damage, control and outcomes"
const REQUIRED_IDS := ["rillshot", "cinderbolt", "cinder-fan", "stone-burst", "rill-burst", "gale-burst", "rime-burst", "arc-burst", "prism-burst", "eclipse-burst", "tideline", "rimewake", "eclipse-disc", "pocket-eclipse"]
const BURST_IDS := ["stone-burst", "cinder-fan", "rill-burst", "gale-burst", "rime-burst", "arc-burst", "prism-burst", "eclipse-burst"]
const STARTUPS := ["gathered_drop", "banked_coal", "elemental_burst", "rising_fan", "frost_sigil", "orbiting_crescents", "paired_focus"]
const SILHOUETTES := ["droplet", "ember_spear", "burst_mote", "wave_fan", "crystal_wake", "eclipse_disc", "eclipse_beam", "elemental_bolt", "elemental_spray", "elemental_beam", "elemental_field"]
const TRAILS := ["none", "split_rill", "cinder_forks", "burst_wake", "curling_lanes", "orbit_echo", "paired_boundary", "elemental_streak", "elemental_lanes", "elemental_boundary"]
const IMPACTS := ["splash_ring", "ash_burst", "burst_break", "breaker_arc", "freeze_star", "crescent_break", "revealed_diamond", "elemental_break", "elemental_field_break"]

var language: VisualLanguage
var data: Dictionary = {}
var profiles_by_wire: Dictionary[int, Dictionary] = {}
var profiles_by_id: Dictionary[String, Dictionary] = {}
var direction_contract := SpellDeliveryDirectionContract.new()
var animation_skeletons := SpellAnimationSkeletonLibrary.new()
var content_hash := ""
var direction_contract_hash := ""
var animation_skeleton_hash := ""
var last_error := ""
var pixel_effects := PixelEffects.new()
var ability_catalog: AbilityCatalog
var frame_config: SimConfig


func begin_frame(config: SimConfig, collision: CollisionWorld) -> void:
	frame_config = config
	pixel_effects.begin_frame(config,collision)


func configure(visual_language: VisualLanguage, catalog: AbilityCatalog, path: String = DEFAULT_PATH) -> bool:
	language = visual_language
	ability_catalog = catalog
	data.clear()
	profiles_by_wire.clear()
	profiles_by_id.clear()
	direction_contract = SpellDeliveryDirectionContract.new()
	animation_skeletons = SpellAnimationSkeletonLibrary.new()
	content_hash = ""
	direction_contract_hash = ""
	animation_skeleton_hash = ""
	last_error = ""
	if language == null or catalog == null or language.elements.is_empty() or catalog.abilities_by_id.is_empty():
		return _fail("Foundation spell presentation requires validated visual and ability catalogs")
	if not direction_contract.load_from_file():
		return _fail(direction_contract.last_error)
	direction_contract_hash = direction_contract.content_hash
	if not animation_skeletons.load_from_file():
		return _fail(animation_skeletons.last_error)
	animation_skeleton_hash = animation_skeletons.content_hash
	if not FileAccess.file_exists(path):
		return _fail("Foundation spell presentation does not exist: %s" % path)
	var source := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(source)
	if not parsed is Dictionary:
		return _fail("Foundation spell presentation root must be an object")
	data = parsed
	if not validate(catalog):
		data.clear()
		return false
	_add_inferred_profiles(catalog)
	content_hash = CanonicalContent.sha256({"authored": data, "effective_profiles": profiles_by_id})
	return true


func _add_inferred_profiles(catalog: AbilityCatalog) -> void:
	for wire_id: int in catalog.runtime_wire_ids:
		if profiles_by_wire.has(wire_id):
			continue
		var ability := catalog.ability_from_wire(wire_id)
		var family := String(ability.get("family", ""))
		if family.is_empty():
			family = "bolt" if String(ability.get("shape", "")) == "projectile" else String(ability.get("shape", ""))
		var vocabulary: Dictionary = {
			"bolt": ["projectile", "paired_focus", "elemental_bolt", "elemental_streak", "elemental_break"],
			"heavy": ["projectile", "paired_focus", "elemental_bolt", "elemental_streak", "elemental_break"],
			"rapid": ["projectile", "paired_focus", "elemental_bolt", "elemental_streak", "elemental_break"],
			"spray": ["spray", "rising_fan", "elemental_spray", "elemental_lanes", "elemental_break"],
			"beam": ["beam", "paired_focus", "elemental_beam", "elemental_boundary", "elemental_break"],
			"field": ["field", "frost_sigil", "elemental_field", "none", "elemental_field_break"],
			"mantle": ["projectile", "paired_focus", "elemental_bolt", "none", "elemental_break"],
			"fuse": ["projectile", "paired_focus", "elemental_bolt", "none", "elemental_break"],
			"split": ["projectile", "paired_focus", "elemental_bolt", "none", "elemental_break"],
			"rebound": ["projectile", "paired_focus", "elemental_bolt", "none", "elemental_break"],
		}
		if not vocabulary.has(family):
			continue
		var values: Array = vocabulary[family]
		var profile := {
			"id": String(ability.get("id", "")),
			"wire_id": wire_id,
			"shape": String(values[0]),
			"skeleton_id": String(values[0]),
			"element": String(ability.get("element", "")),
			"element_mask": int(ability.get("element_mask", 0)),
			"startup": String(values[1]),
			"silhouette": String(values[2]),
			"trail": String(values[3]),
			"impact": String(values[4]),
			"residue": String(ability.get("residue", "none")),
			"generated_from_family": family,
		}
		profiles_by_id[profile["id"]] = profile
		profiles_by_wire[wire_id] = profile


func validate(catalog: AbilityCatalog) -> bool:
	last_error = ""
	profiles_by_wire.clear()
	profiles_by_id.clear()
	if not direction_contract.is_valid():
		return _fail("Foundation spell presentation requires the validated shared direction contract")
	if int(data.get("schema_version", -1)) != 3 or String(data.get("id", "")) != EXPECTED_ID:
		return _fail("Foundation spell presentation identity is unsupported")
	if String(data.get("authority", "")) != EXPECTED_AUTHORITY:
		return _fail("Foundation spell presentation must remain presentation-only")
	var budgets: Dictionary = data.get("budgets", {})
	if int(budgets.get("profile_count", 0)) != REQUIRED_IDS.size() \
		or int(budgets.get("maximum_curve_samples", 0)) < 16 or int(budgets.get("maximum_curve_samples", 0)) > 40 \
		or int(budgets.get("maximum_lane_rays", 0)) < 5 or int(budgets.get("maximum_lane_rays", 0)) > 9 \
		or float(budgets.get("maximum_effect_alpha", 0.0)) < 0.60 or float(budgets.get("maximum_effect_alpha", 0.0)) > 0.85:
		return _fail("Foundation spell visual budgets are unsafe")
	var profiles: Variant = data.get("profiles", [])
	if not profiles is Array or (profiles as Array).size() != REQUIRED_IDS.size():
		return _fail("Foundation spell presentation must define one profile for every live foundation spell")
	var claimed_startups: Dictionary[String, bool] = {}
	var burst_elements: Dictionary[String, bool] = {}
	for value: Variant in profiles:
		if not value is Dictionary:
			return _fail("Foundation spell profile must be an object")
		var profile: Dictionary = value
		var profile_id := String(profile.get("id", ""))
		var wire_id := int(profile.get("wire_id", 0))
		var ability := catalog.ability(profile_id)
		if profile_id not in REQUIRED_IDS or profiles_by_id.has(profile_id) or wire_id <= 0 or profiles_by_wire.has(wire_id):
			return _fail("Foundation spell profile identity is invalid: %s" % profile_id)
		if ability.is_empty() or int(ability.get("wire_id", 0)) != wire_id \
			or String(ability.get("shape", "")) != String(profile.get("shape", "")) \
			or String(ability.get("element", "")) != String(profile.get("element", "")) \
			or String(ability.get("residue", "")) != String(profile.get("residue", "")):
			return _fail("Foundation spell visual contradicts the ability catalog: %s" % profile_id)
		var skeleton_id := String(profile.get("skeleton_id", ""))
		if skeleton_id.is_empty() or not animation_skeletons.skeletons.has(skeleton_id) \
			or String(animation_skeletons.skeletons[skeleton_id].get("shape", "")) != String(profile.get("shape", "")):
			return _fail("Foundation spell visual has no matching animation skeleton: %s" % profile_id)
		var startup := String(profile.get("startup", ""))
		var is_burst := profile_id in BURST_IDS
		if startup not in STARTUPS or (claimed_startups.has(startup) and not is_burst) \
			or String(profile.get("silhouette", "")) not in SILHOUETTES \
			or String(profile.get("trail", "")) not in TRAILS \
			or String(profile.get("impact", "")) not in IMPACTS:
			return _fail("Foundation spell visual vocabulary is invalid: %s" % profile_id)
		if is_burst:
			var element_id := String(profile.get("element", ""))
			if String(ability.get("delivery_kernel", "")) != "burst" \
				or String(profile.get("delivery_kernel", "")) != "burst" \
				or startup != "elemental_burst" \
				or String(profile.get("silhouette", "")) != "burst_mote" \
				or String(profile.get("trail", "")) != "burst_wake" \
				or String(profile.get("impact", "")) != "burst_break" \
				or burst_elements.has(element_id):
				return _fail("First-eight Burst visuals must share geometry and keep unique element identity: %s" % profile_id)
			burst_elements[element_id] = true
		claimed_startups[startup] = true
		profiles_by_id[profile_id] = profile
		profiles_by_wire[wire_id] = profile
	for profile_id: String in REQUIRED_IDS:
		if not profiles_by_id.has(profile_id):
			return _fail("Foundation spell visual is missing: %s" % profile_id)
	if burst_elements.size() != BURST_IDS.size():
		return _fail("Foundation spell visuals require every first-eight Burst element")
	return true


func draw_startup(
	canvas: CanvasItem,
	wire_id: int,
	position: Vector2,
	aim: Vector2,
	phase: float,
	tick: int,
	reduced_effects: bool,
	cast_timing: Dictionary = {},
) -> bool:
	if canvas == null or not profiles_by_wire.has(wire_id):
		return false
	var profile: Dictionary = profiles_by_wire[wire_id]
	if not animation_skeletons.skeletons.has(String(profile.get("skeleton_id", ""))):
		return false
	var direction := aim.normalized() if aim.length_squared() > 0.0 else Vector2.DOWN
	var side := direction.orthogonal()
	var visual_direction := SpellDeliveryDirectionContract.visual_vector(aim)
	var progress := clampf(phase, 0.0, 1.0)
	var element := String(profile.get("element", "water"))
	var ability := ability_catalog.ability_from_wire(wire_id)
	var preparation_sample := startup_sample_ticks(wire_id, progress, reduced_effects, cast_timing)
	if pixel_effects.hand(canvas, element, position, preparation_sample, reduced_effects):
		_draw_mixture_hand(canvas, int(ability.get("element_mask", 0)), position)
		return true
	var dark := language.element_color(element, "dark")
	var base := language.element_color(element, "base")
	var bright := language.element_color(element, "bright")
	var pulse := 0.0 if reduced_effects else sin(float(tick + wire_id) * 0.20) * 1.5
	var readability := startup_readability_geometry(aim, progress)
	var brace_origin: Vector2 = position + (readability["origin"] as Vector2)
	var brace_focus: Vector2 = position + (readability["focus"] as Vector2)
	var brace_side: Vector2 = readability["side"]
	var brace_half_width := float(readability["half_width"])
	var brace_thickness := 2.0 if reduced_effects else 3.0
	# A color-independent fork makes the hand channel, direction and release
	# commitment readable before the spell-specific silhouette resolves.
	for sign_value: float in [-1.0, 1.0]:
		var start := brace_origin + brace_side * brace_half_width * sign_value
		var finish := brace_focus + brace_side * brace_half_width * 0.48 * sign_value
		canvas.draw_line(start, finish, Color(dark, 0.64), brace_thickness + 2.0)
		canvas.draw_line(start, finish, Color(bright, 0.82), brace_thickness)
		canvas.draw_circle(start, 2.0, Color(bright, 0.78))
	canvas.draw_circle(brace_focus, 3.0 + progress * 2.0, Color(dark, 0.76))
	canvas.draw_arc(brace_focus, 5.0 + progress * 3.0, 0.0, TAU, 12, Color(bright, 0.82), brace_thickness)
	_draw_element_mark(canvas, brace_focus, direction, element, 3.5 + progress, bright)
	var skeleton_phase := animation_skeletons.phase_for(String(profile.get("shape", "")), progress)
	var phase_id := String(skeleton_phase.get("id", ""))
	# The delivery skeleton contributes a small shared hand cue before the
	# spell-specific silhouette. It is presentation-only; the authoritative
	# cast timer still decides when this layer appears and disappears.
	match phase_id:
		"startup":
			var gather_radius := 5.0 + progress * 5.0
			canvas.draw_circle(position, gather_radius, Color(base, 0.12 if reduced_effects else 0.20))
			canvas.draw_arc(position, gather_radius + 4.0, -2.4, 0.6, 16, Color(bright, 0.72), 2.0)
		"release":
			var release_origin := position + visual_direction * 7.0
			canvas.draw_arc(release_origin, 9.0 + pulse * 0.35, 0.0, TAU, 16, Color(bright, 0.82), 2.0)
			canvas.draw_line(position + visual_direction * 2.0, position + visual_direction * 14.0, Color(base, 0.64), 2.0)
	match String(profile.get("startup", "")):
		"gathered_drop":
			var gather := position + direction * (16.0 + progress * 7.0)
			canvas.draw_arc(gather, 10.0 - progress * 4.0 + pulse, -2.6, 0.55, 14, Color(bright, 0.82), 2.0)
			canvas.draw_line(gather - direction * 13.0 + side * 5.0, gather - direction * 4.0 + side * 2.0, Color(base, 0.54), 2.0)
			canvas.draw_line(gather - direction * 13.0 - side * 5.0, gather - direction * 4.0 - side * 2.0, Color(base, 0.54), 2.0)
		"banked_coal":
			var coal := position + direction * (17.0 + progress * 8.0)
			var coal_radius := 8.0 - progress * 3.0
			canvas.draw_circle(coal, coal_radius + 3.0, Color(dark, 0.52))
			canvas.draw_circle(coal, coal_radius, Color(base, 0.76))
			canvas.draw_line(position + side * 7.0, coal - direction * 2.0, Color(bright, 0.72), 2.0)
			canvas.draw_line(position - side * 7.0, coal - direction * 2.0, Color(bright, 0.72), 2.0)
		"elemental_burst":
			var reach := 16.0 + progress * 15.0
			for offset: float in [-0.418879, -0.209440, 0.0, 0.209440, 0.418879]:
				var lane := direction.rotated(offset)
				var lane_color := bright if is_zero_approx(offset) else base
				canvas.draw_line(position + lane * 7.0, position + lane * reach, Color(lane_color, 0.58 + progress * 0.24), 2.0)
				canvas.draw_circle(position + lane * reach, 2.0 + progress * 1.5, Color(lane_color, 0.76))
		"rising_fan":
			for offset: float in [-0.34, 0.0, 0.34]:
				var lane := direction.rotated(offset)
				var reach := 22.0 + progress * 15.0
				canvas.draw_arc(position, reach, lane.angle() - 0.12, lane.angle() + 0.12, 6, Color(bright if offset == 0.0 else base, 0.54 + progress * 0.22), 2.0)
		"frost_sigil":
			var sigil_radius := 15.0 + progress * 8.0
			canvas.draw_arc(position, sigil_radius, 0.0, TAU, 18, Color(base, 0.48 + progress * 0.28), 2.0)
			ElementGlyphRendererScript.draw_material_motion(canvas, language, position, element, sigil_radius, progress, 1.0 - progress * 0.2, reduced_effects)
			_draw_element_mark(canvas, position, Vector2.UP, element, 5.0, Color(bright, 0.82))
		"orbiting_crescents":
			for offset: float in [0.0, PI]:
				var angle := progress * PI * 1.4 + offset
				var center := position + Vector2.from_angle(angle) * (18.0 + pulse)
				canvas.draw_arc(center, 6.0, angle - 1.9, angle + 1.1, 9, Color(bright if offset == 0.0 else base, 0.78), 2.0)
		"paired_focus":
			var focus := position + direction * (28.0 + progress * 12.0)
			var separation := 9.0 - progress * 5.0
			canvas.draw_line(position + side * separation, focus + side * separation, Color(base, 0.64), 2.0)
			canvas.draw_line(position - side * separation, focus - side * separation, Color(base, 0.64), 2.0)
			_draw_diamond(canvas, focus, 4.0 + progress * 3.0, Color(bright, 0.82), Color(dark, 0.24))
		_:
			return false
	return true


func startup_sample_ticks(wire_id: int, release_proximity: float, reduced_effects: bool, cast_timing: Dictionary = {}) -> int:
	# Fresh local admission evidence supplies elapsed ticks. Unknown views select
	# an artistic position in the admitted clip, never an invented admission age.
	if cast_timing.get("known_total") == true and cast_timing.get("wire_id") == wire_id \
		and typeof(cast_timing.get("elapsed_ticks")) == TYPE_INT and int(cast_timing.elapsed_ticks) >= 0 \
		and typeof(cast_timing.get("remaining_ticks")) == TYPE_INT and int(cast_timing.remaining_ticks) > 0 \
		and typeof(cast_timing.get("total_ticks")) == TYPE_INT \
		and int(cast_timing.total_ticks) == int(cast_timing.elapsed_ticks) + int(cast_timing.remaining_ticks):
		return int(cast_timing.elapsed_ticks)
	if not pixel_effects.ready() or ability_catalog == null or not is_finite(release_proximity): return 0
	var ability := ability_catalog.ability_from_wire(wire_id)
	var element := String(ability.get("element", "water"))
	var clip: Dictionary = pixel_effects.library.asset(pixel_effects.asset_id(element, "hand_prepare", reduced_effects))
	return floori(clampf(release_proximity, 0.0, 1.0) * maxi(0, int(clip.get("total_ticks", 1)) - 1))


static func startup_readability_geometry(aim: Vector2, progress: float) -> Dictionary:
	var direction := SpellDeliveryDirectionContract.visual_vector(aim)
	var side := direction.orthogonal()
	var bounded := clampf(progress, 0.0, 1.0)
	return {
		"origin": direction * 1.5,
		"focus": direction * (10.0 + bounded * 8.0),
		"side": side,
		"half_width": 6.0 - bounded * 1.5,
	}


func draw_release(canvas: CanvasItem, wire_id: int, hand_anchor: Vector2, age_ticks: int, reduced_effects: bool) -> bool:
	if canvas == null or age_ticks < 0 or not profiles_by_wire.has(wire_id) or not pixel_effects.ready():
		return false
	var profile: Dictionary = profiles_by_wire[wire_id]
	var effect := "burst_release" if String(profile.get("id","")) in BURST_IDS else "hand_release"
	pixel_effects.hand(canvas,String(profile.get("element","")),hand_anchor,age_ticks,reduced_effects,effect)
	_draw_mixture_hand(canvas, int(ability_catalog.ability_from_wire(wire_id).get("element_mask", 0)), hand_anchor)
	return true


func _draw_mixture_hand(canvas: CanvasItem, mask: int, position: Vector2) -> void:
	if PixelEffects.mixture_elements(mask).size() <= 1: return
	for sector: Dictionary in PixelEffects.mixture_layout(mask, position, 12.0):
		var bright := language.element_color(sector.element, "bright")
		canvas.draw_arc(position, 11.0, float(sector.start) + 0.06, float(sector.end) - 0.06, 8, bright, 2.0)
		ElementGlyphRendererScript.draw(canvas, language, sector.glyph_anchor, sector.element, 2.5, bright)


func draw_expanded_projectile(canvas: CanvasItem, projectile: ProjectileState, _tick: int, reduced_effects: bool, interpolation_alpha: float = 1.0, owner: PlayerState = null) -> bool:
	if canvas == null or projectile == null or language == null or frame_config == null or not is_finite(interpolation_alpha): return false
	var definition := CombatTuning.cast_definition_view(projectile.source_wire_id)
	var mask := int(definition.get("element_mask", 0))
	var family := String(definition.get("family", ""))
	if PixelEffects.mixture_elements(mask).is_empty(): return false
	if mask & (mask - 1) == 0 and family not in ["mantle", "fuse", "split", "rebound"]: return false
	if projectile.lifetime_ticks <= 0: return true
	var position := ProjectilePresentationMotion.interpolated_position(projectile, interpolation_alpha)
	var model := PixelEffects.expanded_projectile_model(projectile, definition, position, frame_config, owner, reduced_effects)
	if model.is_empty(): return true # Exhausted valid effects never revive fallback art.
	return pixel_effects.draw_expanded_projectile(canvas, model, language)


func draw_expanded_cue(canvas: CanvasItem, cue: Dictionary, reduced_effects: bool) -> bool:
	if canvas == null or language == null: return false
	var definition := CombatTuning.cast_definition_view(int(cue.get("source_wire_id", 0)))
	var mask := int(definition.get("element_mask", 0))
	if mask <= 0 or mask & (mask - 1) == 0 or String(definition.get("shape", "")) != "spray": return false
	if String(cue.get("kind", "")) != "spray" and String(cue.get("event_type", "")) != "spray_fired": return false
	var model := PixelEffects.mixed_spray_model(cue, definition, reduced_effects)
	if model.is_empty(): return true # Invalid/expired cached view never recreates hidden spokes.
	for segment: Dictionary in model.segments:
		var color := language.element_color(segment.element, "bright" if int(segment.ray) == 2 else "base")
		canvas.draw_line(segment.start, segment.end, Color(color, float(model.opacity) * (0.84 if int(segment.ray) == 2 else 0.60)), 2.0 if int(segment.ray) == 2 else 1.0)
	if bool(model.origin_visible):
		var elements := PixelEffects.mixture_elements(mask)
		var brace: PackedVector2Array = model.brace
		for index: int in elements.size():
			canvas.draw_line(brace[0].lerp(brace[1], float(index) / float(elements.size())), brace[0].lerp(brace[1], float(index + 1) / float(elements.size())), Color(language.element_color(elements[index], "bright"), float(model.opacity)), 2.0)
	return true


func draw_projectile(canvas: CanvasItem, projectile: ProjectileState, tick: int, reduced_effects: bool, interpolation_alpha: float = 1.0) -> bool:
	if draw_expanded_projectile(canvas, projectile, tick, reduced_effects, interpolation_alpha): return true
	if canvas == null or projectile == null or not profiles_by_wire.has(projectile.source_wire_id):
		return false
	if projectile.lifetime_ticks <= 0:
		return true
	var profile: Dictionary = profiles_by_wire[projectile.source_wire_id]
	if String(profile.get("shape", "")) != "projectile":
		return false
	var position := ProjectilePresentationMotion.interpolated_position(projectile, interpolation_alpha)
	var travel_direction := ProjectilePresentationMotion.travel_direction(projectile)
	var direction := SpellDeliveryDirectionContract.visual_vector(travel_direction)
	var side := direction.orthogonal()
	var radius := float(projectile.radius) / SimConfig.FIXED_SCALE
	var element := String(profile.get("element", "water"))
	var ability := ability_catalog.ability_from_wire(projectile.source_wire_id)
	var projectile_age := PixelEffects.lifetime_age(int(ability.get("lifetime_ms", 0)), projectile.lifetime_ticks)
	if pixel_effects.flight(canvas, element, position, travel_direction, radius, projectile_age, reduced_effects):
		return true
	var dark := language.element_color(element, "dark")
	var base := language.element_color(element, "base")
	var bright := language.element_color(element, "bright")
	var visual_size := ProjectilePresentationMotion.visual_diameter(projectile)
	canvas.draw_circle(position + Vector2(0.0, maxf(3.0, radius * 0.48)), maxf(3.0, visual_size * 0.30), Color(0.02, 0.03, 0.03, 0.32))
	canvas.draw_circle(position, visual_size * 0.44, Color(dark, 0.20))
	match String(profile.get("silhouette", "")):
		"droplet":
			var drop := PackedVector2Array([
				position + direction * (radius + 4.0),
				position + side * radius,
				position - direction * (radius + 3.0),
				position - side * radius,
			])
			canvas.draw_colored_polygon(drop, base)
			canvas.draw_polyline(_closed(drop), bright, 2.0, false)
			canvas.draw_circle(position + direction * 2.0 - side * 2.0, maxf(2.0, radius * 0.30), Color(bright, 0.88))
		"eclipse_disc":
			var pulse := 0.0 if reduced_effects else sin(float(tick + projectile.entity_id) * 0.18) * 1.5
			canvas.draw_circle(position, radius + 8.0 + pulse, Color(base, 0.14))
			canvas.draw_circle(position, radius + 1.0, dark)
			canvas.draw_arc(position, radius + 1.0, -2.45, 0.70, 18, bright, 3.0)
			canvas.draw_arc(position, radius - 3.0, 0.70, 3.84, 18, Color(bright, 0.72), 2.0)
			for bounce_index: int in range(projectile.remaining_bounces):
				canvas.draw_circle(position + side * (radius + 7.0) + direction * float(bounce_index * 4 - 2), 1.5, bright)
		"ember_spear":
			var tip := position + direction * (radius + 6.0)
			var tail := position - direction * radius
			var flame := PackedVector2Array([
				tip,
				position + side * (radius + 1.0),
				tail,
				position - side * (radius + 1.0),
			])
			canvas.draw_colored_polygon(flame, base)
			canvas.draw_polyline(_closed(flame), bright, 2.0, false)
			canvas.draw_circle(position + direction * 2.0, maxf(2.0, radius * 0.34), Color(bright, 0.92))
		"burst_mote":
			var tip := position + direction * (radius + 5.0)
			var tail := position - direction * radius
			var mote := PackedVector2Array([tip, position + side * radius, tail, position - side * radius])
			canvas.draw_colored_polygon(mote, base)
			canvas.draw_polyline(_closed(mote), bright, 2.0, false)
			canvas.draw_circle(position, maxf(2.0, radius * 0.34), Color(bright, 0.90))
		"elemental_bolt":
			var tip := position + direction * (radius + 5.0)
			var tail := position - direction * radius
			var bolt := PackedVector2Array([tip, position + side * radius, tail, position - side * radius])
			canvas.draw_colored_polygon(bolt, Color(base, 0.94))
			canvas.draw_polyline(_closed(bolt), bright, 2.0, false)
			canvas.draw_line(position - direction * 3.0, tail, Color(dark, 0.62), 3.0)
			_draw_element_mark(canvas, position, direction, element, maxf(3.0, radius * 0.42), bright)
		_:
			return false
	canvas.draw_arc(position, radius, 0.0, TAU, 16, Color(bright, 0.58 if not reduced_effects else 0.70), 1.5)
	canvas.draw_circle(position + ProjectilePresentationMotion.leading_point(projectile), 1.75, Color(bright, 0.92))
	return true


func draw_field(canvas: CanvasItem, field: FieldState, life_ratio: float, tick: int, reduced_effects: bool) -> bool:
	if canvas == null or field == null or not profiles_by_wire.has(field.source_wire_id):
		return false
	if field.lifetime_ticks <= 0:
		return true
	var profile: Dictionary = profiles_by_wire[field.source_wire_id]
	if String(profile.get("silhouette", "")) not in ["crystal_wake", "elemental_field"]:
		return false
	var center := Vector2(float(field.position_x), float(field.position_y)) / SimConfig.FIXED_SCALE
	var radius := float(field.radius) / SimConfig.FIXED_SCALE
	var element := String(profile.get("element", "ice"))
	var ability := ability_catalog.ability_from_wire(field.source_wire_id)
	var field_age := PixelEffects.lifetime_age(int(ability.get("lifetime_ms", 0)), field.lifetime_ticks)
	if pixel_effects.field(canvas, element, center, radius, field_age, reduced_effects):
		return true
	var dark := language.element_color(element, "dark")
	var base := language.element_color(element, "base")
	var bright := language.element_color(element, "bright")
	var remaining := clampf(life_ratio, 0.0, 1.0)
	var phase := ElementGlyphRendererScript.material_phase(language, element, tick, field.entity_id)
	canvas.draw_circle(center, radius, Color(dark, 0.12 + remaining * 0.05))
	# Only the interior moves. The unbroken outer edge always marks the exact
	# authoritative footprint, including in reduced-effects and decay frames.
	canvas.draw_arc(center, radius, 0.0, TAU, 32, Color(dark, 0.80), 4.0)
	canvas.draw_arc(center, radius, 0.0, TAU, 32, Color(base, 0.72), 2.0)
	ElementGlyphRendererScript.draw_material_motion(canvas, language, center, element, radius, phase, remaining, reduced_effects)
	for affected_index: int in range(mini(field.affected_entity_ids.size(), 8)):
		var angle := TAU * float(affected_index) / 8.0
		canvas.draw_rect(Rect2(center + Vector2.from_angle(angle) * radius * 0.90 - Vector2(2, 2), Vector2(4, 4)), bright, true)
	_draw_element_mark(canvas, center, Vector2.UP, element, 7.0, bright)
	return true


func draw_cue(canvas: CanvasItem, cue: Dictionary, phase: float, reduced_effects: bool) -> bool:
	var wire_id := int(cue.get("source_wire_id", 0))
	if canvas == null or not profiles_by_wire.has(wire_id):
		return false
	var profile: Dictionary = profiles_by_wire[wire_id]
	if not animation_skeletons.skeletons.has(String(profile.get("skeleton_id", ""))):
		return false
	var position: Vector2 = cue.get("position", Vector2.ZERO)
	var start: Vector2 = cue.get("start", position)
	var endpoint: Vector2 = cue.get("end", position)
	phase = clampf(phase, 0.0, 1.0)
	var opacity := 1.0 - phase
	var element := String(profile.get("element", "water"))
	var dark := language.element_color(element, "dark")
	var base := language.element_color(element, "base")
	var bright := language.element_color(element, "bright")
	var event_type := String(cue.get("event_type", ""))
	var age := int(cue.get("age_ticks", floori(phase * float(cue.get("duration", 0.55)) * 120.0)))
	var ability := ability_catalog.ability_from_wire(wire_id)
	if event_type == "beam_fired" and pixel_effects.beam(canvas, element, start, endpoint, float(ability.get("radius", 8000)) / 1000.0, age, reduced_effects, opacity):
		return true
	if event_type == "spray_fired":
		# Centre-ray cover must not shorten the independently admitted side rays.
		var pulse_range := int(cue.get("range", -1))
		if pulse_range < 0:
			pulse_range = int(ability.get("range", 0))
		var full_endpoint := start + (endpoint-start).normalized() * float(pulse_range) / 1000.0
		if pixel_effects.spray(canvas, element, start, full_endpoint, int(ability.get("cone_cosine_squared_per_million", 820000)), age, reduced_effects, opacity, float(ability.get("radius",0))/1000.0):
			return true
	var impact_radius := float(ability.get("radius", 8000)) / 1000.0 if event_type == "projectile_hit" else 8.0
	if event_type in ["projectile_hit", "spray_hit", "field_triggered"] and pixel_effects.impact(canvas, element, position, age, reduced_effects, impact_radius):
		return true
	if event_type in ["cast_refused", "cast_blocked"]:
		var refusal_radius := 12.0 + phase * 11.0
		canvas.draw_arc(position, refusal_radius, 0.0, TAU, 20, Color(base, opacity * 0.74), 2.0)
		canvas.draw_line(position + Vector2(-7.0, -7.0), position + Vector2(7.0, 7.0), Color(bright, opacity * 0.88), 2.0)
		canvas.draw_line(position + Vector2(-7.0, 7.0), position + Vector2(7.0, -7.0), Color(bright, opacity * 0.88), 2.0)
		return true
	if event_type == "beam_fired" and String(profile.get("silhouette", "")) in ["eclipse_beam", "elemental_beam"]:
			var lane := endpoint - start
			var side := lane.normalized().orthogonal() if lane.length_squared() > 0.0 else Vector2.UP
			canvas.draw_line(start, endpoint, Color(dark, opacity * 0.42), 14.0)
			canvas.draw_line(start + side * 3.0, endpoint + side * 3.0, Color(base, opacity * 0.72), 3.0)
			canvas.draw_line(start - side * 3.0, endpoint - side * 3.0, Color(base, opacity * 0.66), 3.0)
			canvas.draw_line(start, endpoint, Color(bright, opacity * 0.92), 1.0)
			if String(profile.get("silhouette", "")) == "elemental_beam":
				_draw_element_impact(canvas, endpoint, element, phase, reduced_effects)
			else:
				_draw_diamond(canvas, endpoint, 10.0 + phase * 8.0, Color(bright, opacity), Color(dark, opacity * 0.28))
			return true
	if event_type == "spray_fired" and String(profile.get("silhouette", "")) in ["wave_fan", "elemental_spray"]:
			var lane := endpoint - start
			if lane.length_squared() <= 0.0:
				return true
			var direction := lane.normalized()
			var perpendicular := direction.orthogonal()
			var fan_width := lane.length() * 0.46
			var fan := PackedVector2Array([start, endpoint + perpendicular * fan_width, endpoint - perpendicular * fan_width])
			canvas.draw_colored_polygon(fan, Color(dark, opacity * 0.18))
			for offset: float in [-1.0, -0.66, -0.33, 0.0, 0.33, 0.66, 1.0]:
				var target := endpoint + perpendicular * fan_width * offset
				var midpoint := start.lerp(target, 0.58) + perpendicular * sin(offset * PI) * 9.0
				canvas.draw_polyline(PackedVector2Array([start, midpoint, target]), Color(bright if absf(offset) < 0.1 else base, opacity * (0.78 if absf(offset) < 0.1 else 0.42)), 2.0 if not reduced_effects else 1.0, false)
			canvas.draw_arc(start, minf(90.0, lane.length() * 0.34), lane.angle() - 0.43, lane.angle() + 0.43, 18, Color(bright, opacity * 0.82), 3.0)
			if String(profile.get("silhouette", "")) == "elemental_spray":
				_draw_element_mark(canvas, start + direction * 10.0, direction, element, 4.5, Color(bright, opacity))
			return true
	if event_type == "field_triggered" and String(profile.get("impact", "")) in ["freeze_star", "elemental_field_break"]:
		_draw_element_impact(canvas, position, element, phase, reduced_effects)
		return true
	if event_type == "spray_hit" and String(profile.get("impact", "")) == "elemental_break":
		_draw_element_impact(canvas, position, element, phase, reduced_effects)
		return true
	if event_type == "spray_hit" and String(profile.get("impact", "")) == "breaker_arc":
		var breaker_radius := 11.0 + phase * 28.0
		canvas.draw_arc(position, breaker_radius, -2.75, -0.39, 18, Color(bright, opacity), 3.0)
		canvas.draw_arc(position, breaker_radius * 0.66, -2.55, -0.59, 14, Color(base, opacity * 0.78), 2.0)
		canvas.draw_line(position + Vector2(-10.0, 2.0), position + Vector2(-17.0 - phase * 8.0, -7.0), Color(base, opacity * 0.72), 2.0)
		canvas.draw_line(position + Vector2(10.0, 2.0), position + Vector2(17.0 + phase * 8.0, -7.0), Color(base, opacity * 0.72), 2.0)
		return true
	if event_type == "projectile_hit":
		if String(profile.get("impact", "")) in ["burst_break", "elemental_break"]:
			_draw_element_impact(canvas, position, element, phase, reduced_effects)
		elif String(profile.get("impact", "")) == "splash_ring":
			var splash_radius := 10.0 + phase * 30.0
			canvas.draw_arc(position, splash_radius, 0.0, TAU, 24, Color(base, opacity * 0.78), 2.0)
			canvas.draw_arc(position, splash_radius * 0.72, -2.8, -0.2, 18, Color(bright, opacity), 3.0)
			for side_value: float in [-1.0, 0.0, 1.0]:
				canvas.draw_line(position + Vector2(side_value * 5.0, 0), position + Vector2(side_value * 13.0, -11.0 - phase * 11.0), Color(bright, opacity * 0.82), 2.0)
		elif String(profile.get("impact", "")) == "ash_burst":
			for index: int in range(8):
				var burst_direction := Vector2.from_angle(TAU * float(index) / 8.0 + 0.18)
				var length := 12.0 + phase * (22.0 if index % 2 == 0 else 14.0)
				canvas.draw_line(position + burst_direction * 4.0, position + burst_direction * length, Color(bright if index % 2 == 0 else base, opacity), 2.0)
			canvas.draw_circle(position, 7.0 + phase * 5.0, Color(dark, opacity * 0.48))
		else:
			canvas.draw_arc(position, 9.0 + phase * 20.0, -2.4, 0.7, 18, Color(base, opacity), 3.0)
			canvas.draw_arc(position, 9.0 + phase * 20.0, 0.7, 3.84, 18, Color(bright, opacity * 0.72), 2.0)
		return true
	return false


func _draw_element_impact(canvas: CanvasItem, position: Vector2, element: String, phase: float, reduced_effects: bool) -> void:
	var opacity := 1.0 - phase
	var extent := 18.0 + phase * (14.0 if reduced_effects else 22.0)
	ElementGlyphRendererScript.draw_material_motion(canvas, language, position, element, extent, phase, opacity, reduced_effects, opacity)
	_draw_element_mark(canvas, position, Vector2.UP, element, 4.0 + phase * 3.0, Color(language.element_color(element, "bright"), opacity * 0.80))


func _draw_element_mark(canvas: CanvasItem, center: Vector2, direction: Vector2, element: String, radius: float, color: Color) -> void:
	ElementGlyphRendererScript.draw(canvas, language, center, element, radius, color, direction)


static func _draw_diamond(canvas: CanvasItem, center: Vector2, radius: float, outline: Color, fill: Color) -> void:
	var points := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)])
	canvas.draw_colored_polygon(points, fill)
	canvas.draw_polyline(_closed(points), outline, 2.0, false)


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var output := points.duplicate()
	if not output.is_empty():
		output.append(output[0])
	return output


func _fail(message: String) -> bool:
	last_error = message
	return false
