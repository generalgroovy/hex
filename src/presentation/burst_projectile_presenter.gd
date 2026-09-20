class_name BurstProjectilePresenter
extends RefCounted


# All live projectile families share the validated native-pixel material library.
# Historical burst_v3 sheets are source archives, never a startup dependency.
const PixelEffects = preload("res://src/presentation/pixel_spell_effects.gd")
const Library = preload("res://src/presentation/pixel_magic_library.gd")
const REQUIRED_ELEMENTS := ["earth", "fire", "water", "wind", "ice", "charge", "light", "dark"]
var language: VisualLanguage
var catalog: AbilityCatalog
var direction_contract := SpellDeliveryDirectionContract.new()
var content_hash := ""
var direction_contract_hash := ""
var last_error := ""
var pixel_effects: PixelSpellEffects


func configure(visual_language: VisualLanguage, ability_catalog: AbilityCatalog, shared_library: PixelMagicLibrary = null) -> bool:
	language = null
	catalog = null
	pixel_effects = null
	content_hash = ""
	direction_contract_hash = ""
	last_error = ""
	if visual_language == null or ability_catalog == null or visual_language.elements.is_empty() or ability_catalog.elements_by_id.is_empty():
		return _fail("Projectile presentation requires validated visual and ability catalogs")
	direction_contract = SpellDeliveryDirectionContract.new()
	if not direction_contract.load_from_file():
		return _fail(direction_contract.last_error)
	var candidate := shared_library if shared_library != null else Library.default_library()
	if candidate.asset_count() != 474 or candidate.page_count() != 3 or candidate.content_hash.is_empty():
		return _fail("Projectile pixel pack is unavailable: %s" % candidate.last_error)
	for element: String in REQUIRED_ELEMENTS:
		if not visual_language.elements.has(element) or not ability_catalog.elements_by_id.has(element) or not bool(ability_catalog.elements_by_id[element].get("runtime_enabled", false)):
			return _fail("Projectile material has no active element: %s" % element)
		for reduced: bool in [false, true]:
			for effect: String in ["flight", "flight_tail", "impact"]:
				if candidate.sample(PixelEffects.asset_id(element, effect, reduced), 0).is_empty():
					return _fail("Projectile pixel component is missing: %s / %s" % [element, effect])
	language = visual_language
	catalog = ability_catalog
	pixel_effects = PixelEffects.new(candidate)
	direction_contract_hash = direction_contract.content_hash
	content_hash = CanonicalContent.sha256({"pixel_pack": candidate.content_hash, "direction_contract": direction_contract_hash})
	return true


func projectile_model(projectile: ProjectileState, interpolation_alpha: float = 1.0) -> Dictionary:
	if projectile == null or catalog == null or pixel_effects == null or projectile.lifetime_ticks <= 0 or projectile.radius <= 0:
		return {}
	var ability := catalog.ability_from_wire(projectile.source_wire_id)
	var element := String(ability.get("element", ""))
	if String(ability.get("shape", "")) != "projectile" or element not in REQUIRED_ELEMENTS:
		return {}
	return {"element": element, "position": ProjectilePresentationMotion.interpolated_position(projectile, interpolation_alpha),
		"direction": ProjectilePresentationMotion.travel_direction(projectile), "radius": float(projectile.radius) / SimConfig.FIXED_SCALE,
		"age_ticks": PixelEffects.lifetime_age(int(ability.get("lifetime_ms", 0)), projectile.lifetime_ticks)}


func draw_projectile(canvas: CanvasItem, projectile: ProjectileState, _tick: int, reduced_effects: bool, interpolation_alpha: float = 1.0) -> bool:
	if canvas == null:
		return false
	if projectile != null and projectile.lifetime_ticks <= 0:
		return true
	var model := projectile_model(projectile, interpolation_alpha)
	if model.is_empty():
		return false
	return pixel_effects.flight(canvas, model.element, model.position, model.direction, model.radius, model.age_ticks, reduced_effects)


static func impact_profile(element: String, age_ticks: int, duration_ticks: int) -> Dictionary:
	if element not in REQUIRED_ELEMENTS or duration_ticks <= 0 or age_ticks < 0 or age_ticks >= duration_ticks:
		return {}
	var progress := float(age_ticks) / float(duration_ticks)
	return {"element": element, "progress": progress, "opacity": 1.0 - progress}


func draw_impact(canvas: CanvasItem, element: String, position: Vector2, direction: Vector2, age_ticks: int, duration_ticks: int, reduced_effects: bool = false, source_radius: float = 8.0) -> bool:
	if canvas == null or pixel_effects == null or not position.is_finite() or not direction.is_finite() or impact_profile(element, age_ticks, duration_ticks).is_empty():
		return false
	return pixel_effects.impact(canvas, element, position, age_ticks, reduced_effects, source_radius)


func _fail(message: String) -> bool:
	last_error = message
	return false
