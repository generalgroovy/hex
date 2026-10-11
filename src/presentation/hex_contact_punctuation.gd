extends RefCounted


# Point-contact presentation only. The existing cue owns admission, visibility,
# its anchor and lifetime; reported damage changes cosmetic emphasis, not reach.
const Library = preload("res://src/presentation/pixel_magic_library.gd")
const Effects = preload("res://src/presentation/pixel_spell_effects.gd")
const HIT_EVENTS := ["projectile_hit", "spray_hit"]
const SMALL_DAMAGE_MAX: int = 5_000
const MEDIUM_DAMAGE_MAX: int = 12_000
const TIER_SCALES := [1.0, 1.5, 2.0]

var library: RefCounted


func _init(shared_library: RefCounted = null) -> void:
	library = shared_library if shared_library != null else Library.default_library()


# Empty means unsupported/unavailable, allowing the caller's existing fallback.
# A nonempty expired sample is still handled: it must not revive that fallback.
# No input dictionary, geometry, actor, or mutable per-cue cache is retained.
func sample(cue: Dictionary, element: String, reduced: bool) -> Dictionary:
	if (
		typeof(cue.get("event_type")) != TYPE_STRING
		or cue.event_type not in HIT_EVENTS
		or element not in Effects.ELEMENTS
		or not cue.get("position") is Vector2
	):
		return {}
	var position: Vector2 = cue.position
	var damage_value: Variant = cue.get("damage", 0)
	var age_value: Variant = cue.get("age_ticks", 0)
	if not position.is_finite() or typeof(damage_value) != TYPE_INT or int(damage_value) < 0 or typeof(age_value) != TYPE_INT or int(age_value) < 0:
		return {}
	if library == null or library.asset_count() == 0:
		return {}
	var profile := Effects.impact_profile(element, 8.0, reduced)
	var asset_id := String(profile.asset_id)
	var asset: Dictionary = library.asset(asset_id)
	if asset.is_empty() or bool(asset.get("loop", true)) or String(asset.get("end_behavior", "")) != "hide" or String(asset.get("layer_role", "")) != "terminal_contact":
		return {}
	var authored_ticks := int(asset.get("total_ticks", 0))
	if authored_ticks <= 0:
		return {}
	var damage := int(damage_value)
	var tier := 0 if damage <= SMALL_DAMAGE_MAX else (1 if damage <= MEDIUM_DAMAGE_MAX else 2)
	var age := int(age_value)
	var duration := Effects.impact_duration_ticks(authored_ticks)
	# Decide expiry before scaling the age, including arbitrarily old integer
	# samples. The shared atlas remains the sole source of sequence duration.
	var sample_age := Effects.impact_sample_age(age) if age < duration else authored_ticks
	var frame: Dictionary = library.sample(asset_id, sample_age)
	var envelope := Effects.impact_envelope(age, duration, tier, reduced)
	return {
		"handled": true, "visible": not frame.is_empty(),
		"position": position, "damage": damage, "tier": tier,
		"scale": float(TIER_SCALES[tier]), "opacity": float(profile.opacity),
		"asset_id": asset_id, "age_ticks": age, "sample_age_ticks": sample_age,
		"duration_ticks": duration, "frame": frame,
		"render_scale": float(TIER_SCALES[tier]) * envelope.x,
		"render_opacity": float(profile.opacity) * envelope.y,
	}


# True covers both a rendered hit and a valid, expired hit. Only one cached
# stamp replaces the old cross; no generated images, particles, trails, or
# decoration budget changes are needed, including in Reduced Effects.
func draw(canvas: CanvasItem, cue: Dictionary, element: String, reduced: bool) -> bool:
	if canvas == null:
		return false
	var model := sample(cue, element, reduced)
	if model.is_empty():
		return false
	if not bool(model.visible):
		return true
	return library.draw_stamp(canvas, String(model.asset_id), model.position, int(model.sample_age_ticks), 0.0, float(model.render_opacity), float(model.render_scale))
