class_name PixelSpellEffects
extends RefCounted

# Rendering only. A material frame never determines attack admission or coverage.
const Library = preload("res://src/presentation/pixel_magic_library.gd")
const Geometry = preload("res://src/presentation/pixel_effect_geometry.gd")
const FootprintPresenter = preload("res://src/presentation/element_chemistry_presenter.gd")
const ELEMENTS := ["earth", "fire", "water", "wind", "ice", "charge", "light", "dark"]
const MAX_FIELD_STAMPS := 64
const MAX_SPRAY_STAMPS := 24
const MAX_TAIL_SCALE := 1.5
const MAX_IMPACT_SCALE := 3.0
const IMPACT_READABILITY_SCALE := 1.50
const IMPACT_IMPRINT_TICKS := 18 # Retained as a historical capture checkpoint; no borrowed looped stamp.
const TERMINAL_CONTACT_TICKS := 36
var library: RefCounted
var geometry := Geometry.new()
var collision: CollisionWorld
var material_footprint := FootprintPresenter.new()


func _init(shared_library: RefCounted = null) -> void:
	library = shared_library if shared_library != null else Library.default_library()


func ready() -> bool:
	return library != null and library.asset_count() > 0


func begin_frame(_config: SimConfig, collision_world: CollisionWorld) -> void:
	collision = collision_world


static func asset_id(element: String, effect: String, reduced: bool) -> String:
	return Library.element_asset_id(ELEMENTS.find(element) + 1, effect, reduced)


static func lifetime_age(lifetime_ms: int, remaining_ticks: int) -> int:
	return maxi(0, ceili(float(lifetime_ms) * 0.12) - remaining_ticks)


static func accepted_release(event: Dictionary) -> Dictionary:
	var kind := String(event.get("type",""))
	if kind not in ["projectile_spawned","field_spawned","beam_fired","spray_fired"]:
		return {}
	if kind == "projectile_spawned" and int(event.get("lane_index",0)) != 0:
		return {} # One bare-hand release per real cast, not one per Burst lane.
	var owner_id := int(event.get("owner_id",0))
	var wire_id := int(event.get("source_wire_id",event.get("wire_id",0)))
	if owner_id <= 0 or wire_id <= 0:
		return {}
	# Optical continuations share this key; caller deduplicates within the same
	# accepted simulation tick and attaches to that owner's current hand anchor.
	return {"owner_id":owner_id,"wire_id":wire_id,"dedup_key":"%d:%d" % [owner_id,wire_id]}


func material_color(element: String, index: int = 3) -> Color:
	var entry: Dictionary = library.asset(asset_id(element,"field_tile",false))
	var palette: Array = entry.get("palette_rgba",[])
	return Color(String(palette[index])) if palette.size() > index else Color("cddbc9")


func flight(canvas: CanvasItem, element: String, position: Vector2, direction: Vector2, radius: float, age: int, reduced: bool) -> bool:
	if not ready() or element not in ELEMENTS or radius <= 0.0 or age < 0:
		return false
	var scale := radius / 8.0 # Authored core envelope is 16 px, not its 32 px gutter cell.
	var tail := flight_tail_profile(element, position, direction, radius, reduced)
	if not tail.is_empty() and library.take_decoration(tail.asset_id):
		library.draw_stamp(canvas, tail.asset_id, tail.anchor, age, tail.angle, tail.opacity, tail.scale)
	return library.draw_stamp(canvas, asset_id(element, "flight", reduced), position, age, 0.0, 1.0, scale)


static func flight_tail_profile(element: String, position: Vector2, direction: Vector2, radius: float, reduced: bool) -> Dictionary:
	if element not in ELEMENTS or not position.is_finite() or not direction.is_finite() or not is_finite(radius) or radius <= 0.0 or direction.length_squared() <= 0.0:
		return {}
	# Reduced mode keeps a short heading cue, not a second projectile. The
	# upright material core and real collision radius are never rotated/resized.
	return {"asset_id": asset_id(element, "flight_tail", reduced),
		"anchor": position - direction.normalized() * radius, "angle": direction.angle(),
		"opacity": 0.24 if reduced else 0.32, "scale": minf(radius / 8.0, MAX_TAIL_SCALE) * (0.60 if reduced else 1.0)}


func hand(canvas: CanvasItem, element: String, position: Vector2, age: int, reduced: bool, effect: String = "hand_prepare") -> bool:
	return ready() and library.draw_stamp(canvas, asset_id(element, effect, reduced), position, age)


func impact(canvas: CanvasItem, element: String, position: Vector2, age: int, reduced: bool, radius: float = 8.0) -> bool:
	if canvas == null or not ready() or not position.is_finite() or age < 0 or impact_profile(element, radius, reduced).is_empty():
		return false
	var model := impact_model(element, position, age, reduced, radius)
	if model.is_empty():
		# A valid expired contact is handled without drawing. Returning false here
		# would resurrect legacy fallback artwork in FoundationSpellPresenter.
		return true
	var profile: Dictionary = model.breakup
	var sample_age: int = model.sample_age_ticks
	# The authored contact now contains its own full material bloom. One guaranteed
	# finite stamp keeps that identity at zero optional budget without borrowing
	# a looping flight core or overdrawing a duplicate contact silhouette.
	library.draw_stamp(canvas, profile.asset_id, position, sample_age, 0.0, profile.opacity, profile.scale)
	return true


func impact_model(element: String, position: Vector2, age: int, reduced: bool, radius: float = 8.0) -> Dictionary:
	var profile := impact_profile(element, radius, reduced)
	if not ready() or profile.is_empty() or not position.is_finite() or age < 0:
		return {}
	# Only the nonlooping contact is sampled. No flight loop can revive expiry.
	var sample_age := impact_sample_age(age)
	if library.sample(profile.asset_id, sample_age).is_empty():
		return {}
	return {"breakup": profile, "imprint": {}, "anchor": position, "age_ticks": age, "sample_age_ticks": sample_age}


static func impact_sample_age(age: int) -> int:
	# Finite 1.5x playback, not a looping ghost or an extended damage window.
	return floori(float(age) * 2.0 / 3.0)


static func impact_duration_ticks(authored_ticks: int) -> int:
	return ceili(float(maxi(0, authored_ticks)) * 1.5)


static func impact_profile(element: String, radius: float, reduced: bool) -> Dictionary:
	if element not in ELEMENTS or not is_finite(radius) or radius <= 0.0:
		return {}
	# Expand only the short contact sprite, never a persistent area or damage mask.
	# The finite contact envelope remains cosmetic and does not resize matter.
	return {"asset_id": asset_id(element, "impact", reduced), "opacity": 0.95 if reduced else 1.0,
		"scale": clampf(radius / 8.0 * IMPACT_READABILITY_SCALE, 0.75, MAX_IMPACT_SCALE)}


static func spray_polygon(start: Vector2, endpoint: Vector2, cosine_squared: int) -> PackedVector2Array:
	var lane := endpoint - start
	var points := PackedVector2Array()
	if lane.length_squared() <= 0.0:
		return points
	var half_angle := acos(sqrt(clampf(float(cosine_squared) / 1000000.0, 0.0, 1.0)))
	points.append(start)
	for index: int in range(25):
		points.append(start + Vector2.from_angle(lane.angle() - half_angle + half_angle * 2.0 * float(index) / 24.0) * lane.length())
	return points


func beam(canvas: CanvasItem, element: String, start: Vector2, endpoint: Vector2, radius: float, age: int, reduced: bool, opacity: float) -> bool:
	if not ready() or element not in ELEMENTS:
		return false
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var lane := endpoint - start
	if lane.length_squared() <= 0.0 or radius <= 0.0:
		return true
	var direction := lane.normalized()
	var side := direction.orthogonal() * radius
	var mask := PackedVector2Array([start-side, endpoint-side, endpoint+side, start+side])
	var frame: Dictionary = library.sample(asset_id(element, "beam_body", reduced), age)
	for index: int in range(ceili(lane.length() / 16.0)):
		Geometry.draw_clipped_frame(canvas, frame, start + direction * float(index * 16), [mask], opacity, lane.angle())
	for cap: String in ["beam_start", "beam_end"]:
		var cap_frame: Dictionary = library.sample(asset_id(element, cap, reduced), age)
		Geometry.draw_clipped_frame(canvas, cap_frame, start if cap == "beam_start" else endpoint, [mask], opacity)
	# These two one-pixel rails are information, not the magic material.
	canvas.draw_line(start-side, endpoint-side, Color(material_color(element), opacity * 0.85), 1.0, false)
	canvas.draw_line(start+side, endpoint+side, Color(material_color(element), opacity * 0.85), 1.0, false)
	return true


func spray(canvas: CanvasItem, element: String, start: Vector2, endpoint: Vector2, cosine_squared: int, age: int, reduced: bool, opacity: float, clearance_radius: float = 0.0) -> bool:
	if not ready() or element not in ELEMENTS:
		return false
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mask := spray_polygon(start, endpoint, cosine_squared)
	if mask.is_empty():
		return true
	var bounds := Rect2(start,Vector2.ZERO)
	for point: Vector2 in mask:
		bounds = bounds.expand(point)
	var clipped: Dictionary = geometry.clip_spell_mask([mask],start,bounds,collision,clearance_radius)
	var polygons: Array = clipped.get("polygons",[])
	if polygons.is_empty():
		return true
	var frame: Dictionary = library.sample(asset_id(element, "spray_grain", reduced), age)
	_draw_occupied_material(canvas, frame, clipped, opacity * 0.9)
	var lane := endpoint - start
	var half_angle := acos(sqrt(clampf(float(cosine_squared) / 1000000.0, 0.0, 1.0)))
	var count := 12 if reduced else MAX_SPRAY_STAMPS
	for index: int in range(count):
		if not library.take_decoration(asset_id(element,"spray_grain",reduced)):
			break
		# Stable sparse rays with continuous outward phase; no invented extra hits.
		var ray := -0.88 + float(index % 5) * 0.44
		var distance_ratio := fmod(float(index) * 0.381966 + float(age) / 36.0, 1.0)
		var anchor := start + lane.rotated(ray * half_angle) * distance_ratio
		Geometry.draw_clipped_frame(canvas, frame, anchor, polygons, opacity * 0.9)
	return true


func _draw_occupied_material(canvas: CanvasItem, frame: Dictionary, mask: Dictionary, opacity: float) -> int:
	var model := {"frame": frame, "mask": mask, "socket": false}
	var cells := material_footprint.footprint_cells(model)
	var offset: Vector2 = frame.region.position / frame.texture.get_size()
	for cell: Dictionary in cells:
		for part: Dictionary in cell.parts:
			var uvs: PackedVector2Array = part.uvs.duplicate()
			for index: int in range(uvs.size()):
				uvs[index] += offset
			canvas.draw_polygon(part.points, PackedColorArray([Color(1, 1, 1, opacity)]), uvs, frame.texture)
	return cells.size()


func field_model(element: String, center: Vector2, radius: float, age: int, reduced: bool) -> Dictionary:
	if not ready() or element not in ELEMENTS or not center.is_finite() or not is_finite(radius) or radius <= 0.0 or age < 0:
		return {}
	var mask := Geometry.circle_polygon(center, radius)
	var core_asset := asset_id(element, "flight", reduced)
	return {"frame": library.sample(asset_id(element, "field_tile", reduced), age),
		"core_asset_id": core_asset, "core_frame": library.sample(core_asset, age), "polygons": [mask],
		"core_anchor": center, "core_opacity": 0.55 if reduced else 0.72, "material_opacity": 0.10 if reduced else 0.20}


func field(canvas: CanvasItem, element: String, center: Vector2, radius: float, age: int, reduced: bool) -> bool:
	var model := field_model(element, center, radius, age, reduced)
	if canvas == null or model.is_empty():
		return false
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mask: PackedVector2Array = model.polygons[0]
	var frame: Dictionary = model.frame
	# The element remains identifiable even after optional density is exhausted.
	# Native flight identity is more legible than sparse tile grains. It is one
	# unscaled32px atlas cell clipped to the same real mask, not another projectile.
	Geometry.draw_clipped_frame(canvas, model.core_frame, center, model.polygons, model.core_opacity)
	_draw_occupied_material(canvas, frame, {"polygons": [mask], "bounds": Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)}, model.material_opacity)
	return true
