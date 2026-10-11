extends RefCounted


# A finite, stationary bare-hand release, not an attack body or damage area.
# Bootstrap continues to own admission, visibility, anchor and cue lifetime.
const Library = preload("res://src/presentation/pixel_magic_library.gd")
const FAMILY_SCALES := {"rapid": 1.0, "bolt": 1.25, "heavy": 1.5, "spray": 1.25}
const RELEASE_SECONDS := 0.20
const RELEASE_TICKS := 24
var library: RefCounted


func _init(shared_library: RefCounted = null) -> void:
	library = shared_library if shared_library != null else Library.default_library()


# Empty means unavailable/unsupported. A handled but invisible result suppresses
# the old cross after expiry. Returned metadata retains no mutable input aliases.
func sample(cue: Dictionary, definition: Dictionary, reduced: bool) -> Dictionary:
	if cue.get("kind") != "pixel_release" or not cue.get("position") is Vector2:
		return {}
	var position: Vector2 = cue.position
	var age_value: Variant = cue.get("age_ticks", 0)
	var duration_value: Variant = cue.get("duration", RELEASE_SECONDS)
	var remaining_value: Variant = cue.get("remaining", RELEASE_SECONDS)
	if not position.is_finite() or typeof(age_value) != TYPE_INT or int(age_value) < 0 \
		or typeof(duration_value) not in [TYPE_INT, TYPE_FLOAT] or typeof(remaining_value) not in [TYPE_INT, TYPE_FLOAT]:
		return {}
	var duration := float(duration_value)
	var remaining := float(remaining_value)
	if not is_finite(duration) or not is_finite(remaining) or not is_equal_approx(duration, RELEASE_SECONDS):
		return {}
	var family := String(definition.get("family", ""))
	var element_wire := int(definition.get("element_wire_id", 0))
	if not FAMILY_SCALES.has(family) or element_wire < 1 or element_wire > Library.ELEMENTS.size() \
		or String(definition.get("shape", "")) != ("spray" if family == "spray" else "projectile") \
		or library == null or library.asset_count() == 0:
		return {}
	var asset_id := Library.element_asset_id(element_wire, "hand_release", reduced)
	var asset: Dictionary = library.asset(asset_id)
	if asset.is_empty() or bool(asset.get("loop", true)) or String(asset.get("end_behavior", "")) != "hide" \
		or String(asset.get("layer_role", "")) != "harmless_cast_detail":
		return {}
	var authored_ticks := int(asset.get("total_ticks", 0))
	if authored_ticks <= 0:
		return {}
	var age := int(age_value)
	# Fit the complete authored sequence into the EXISTING 24-tick cue. Test
	# expiry first, so even an arbitrarily old age cannot overflow multiplication.
	var sample_age := floori(float(age * authored_ticks) / RELEASE_TICKS) if age < RELEASE_TICKS and remaining > 0.0 else authored_ticks
	var frame: Dictionary = library.sample(asset_id, sample_age)
	return {"handled": true, "visible": not frame.is_empty(), "position": position,
		"family": family, "element_wire_id": element_wire, "scale": float(FAMILY_SCALES[family]),
		"asset_id": asset_id, "frame": frame, "age_ticks": age, "sample_age_ticks": sample_age,
		"duration_ticks": RELEASE_TICKS, "opacity": 0.95 if reduced else 1.0}


func draw(canvas: CanvasItem, cue: Dictionary, definition: Dictionary, reduced: bool) -> bool:
	if canvas == null:
		return false
	var model := sample(cue, definition, reduced)
	if model.is_empty():
		return false
	if not bool(model.visible):
		return true
	# One existing stamp replaces the old cross. No optional budget, particle,
	# generated texture, second timer, orbit, travel tail or authority state.
	return library.draw_stamp(canvas, model.asset_id, model.position, model.sample_age_ticks, 0.0, model.opacity, model.scale)
