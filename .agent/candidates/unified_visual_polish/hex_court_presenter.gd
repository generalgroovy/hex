class_name HexCourtPresenter
extends RefCounted


# H0/H2 presentation candidate. Court state, occupied cells, quantities and
# phases remain authoritative in HexCourt; this class only reads them.
const HexGrid = preload("res://src/sim/hex/hex_grid.gd")
const ProjectileMotion = preload("res://src/presentation/projectile_presentation_motion.gd")

const ATLAS_PATH := "res://assets/sprites/hex_court_v1/projectile_atlas.png"
const ATLAS_RGBA_SHA256 := "bbdbcf3212b17582a9d9314b53d5f671f1c45eaca4192c67d5591e45cd41e717"
const ATLAS_CELL := Vector2i(24, 24)
const COURT_ORIGIN := Vector2i(640_000, 480_000)
const EDGE_NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, -1), Vector2i(1, 0), Vector2i(0, 1),
	Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(0, -1),
]
const FAMILY_ROWS := {"rapid": 0, "bolt": 1, "heavy": 2, "spray": 3}
const FAMILY_SIZE := {"rapid": 18.0, "bolt": 24.0, "heavy": 32.0, "spray": 24.0}
const PROJECTILE_READABLE_FLOOR := 5.0
const PROJECTILE_SHRINK_TICKS := 6.0
const PROJECTILE_CACHE_LIMIT := 128
const ELEMENT_COLUMNS := {1: 0, 2: 1, 3: 2, 4: 3, 5: 4, 6: 5, 7: 6, 8: 7}
const ELEMENT_IDS := {1: "earth", 2: "fire", 3: "water", 4: "wind", 5: "ice", 6: "charge", 7: "light", 8: "dark"}
const INGREDIENT_MATERIALS: Array[String] = ["earth", "fire", "water", "wind", "ice", "charge", "light", "dark"]
const LEGACY_HEX_MATERIALS: Array[String] = ["water", "fire", "steam", "flood", "conflagration"]
const PRODUCT_MATERIALS: Array[String] = [
	"fortify", "magma", "mud", "dustfront", "permafrost", "grounding_network", "crystal_prism", "blightsoil",
	"conflagration", "steam", "firestorm", "thermal_shock", "plasma_arc", "solar_flare", "cinderveil", "flood",
	"mistcurrent", "freeze", "conductive_flood", "mirrorwater", "blackwater", "vortex", "hailstream", "ion_storm",
	"lightbend", "shadowdraft", "glacier", "superconduct", "crystal_lens", "black_ice", "overload", "arcflash",
	"static_shroud", "radiance", "penumbra", "umbral_field",
]
const MATERIALS: Array[String] = [
	"earth", "fire", "water", "wind", "ice", "charge", "light", "dark",
	"fortify", "magma", "mud", "dustfront", "permafrost", "grounding_network", "crystal_prism", "blightsoil",
	"conflagration", "steam", "firestorm", "thermal_shock", "plasma_arc", "solar_flare", "cinderveil", "flood",
	"mistcurrent", "freeze", "conductive_flood", "mirrorwater", "blackwater", "vortex", "hailstream", "ion_storm",
	"lightbend", "shadowdraft", "glacier", "superconduct", "crystal_lens", "black_ice", "overload", "arcflash",
	"static_shroud", "radiance", "penumbra", "umbral_field",
]
const ELEMENT_WIRES := {"earth": 1, "fire": 2, "water": 3, "wind": 4, "ice": 5, "charge": 6, "light": 7, "dark": 8}
# Presentation metadata mirrors the stable compiled recipe identity table. It
# selects palette and mark vocabulary only; it does not imply a gameplay rule.
const PRODUCT_ROWS: Array = [
	["fortify",301,"earth","earth","cover"], ["magma",302,"earth","fire","front"],
	["mud",303,"earth","water","disk"], ["dustfront",304,"earth","wind","corridor"],
	["permafrost",305,"earth","ice","cover"], ["grounding_network",306,"earth","charge","node"],
	["crystal_prism",307,"earth","light","plane"], ["blightsoil",308,"earth","dark","disk"],
	["conflagration",309,"fire","fire","ring"], ["steam",310,"fire","water","expanding_veil"],
	["firestorm",311,"fire","wind","corridor"], ["thermal_shock",312,"fire","ice","fracture"],
	["plasma_arc",313,"fire","charge","branch"], ["solar_flare",314,"fire","light","reveal_pulse"],
	["cinderveil",315,"fire","dark","ember_veil"], ["flood",316,"water","water","flow"],
	["mistcurrent",317,"water","wind","corridor"], ["freeze",318,"water","ice","growing_strip"],
	["conductive_flood",319,"water","charge","water_path"], ["mirrorwater",320,"water","light","observation"],
	["blackwater",321,"water","dark","motion_veil"], ["vortex",322,"wind","wind","annulus"],
	["hailstream",323,"wind","ice","pulse_lane"], ["ion_storm",324,"wind","charge","drifting_node"],
	["lightbend",325,"wind","light","bend"], ["shadowdraft",326,"wind","dark","bands"],
	["glacier",327,"ice","ice","corridor"], ["superconduct",328,"ice","charge","frost_path"],
	["crystal_lens",329,"ice","light","lens"], ["black_ice",330,"ice","dark","entry_mark"],
	["overload",331,"charge","charge","corridor"], ["arcflash",332,"charge","light","reveal_line"],
	["static_shroud",333,"charge","dark","entry_veil"], ["radiance",334,"light","light","reveal_area"],
	["penumbra",335,"light","dark","border"], ["umbral_field",336,"dark","dark","attrition_veil"],
]
const ATMOSPHERIC_MATERIALS := {
	"wind": true, "steam": true, "dustfront": true, "firestorm": true, "cinderveil": true,
	"mistcurrent": true, "blackwater": true, "ion_storm": true, "shadowdraft": true,
	"static_shroud": true, "umbral_field": true,
}

const STONE_DARK := Color("403424")
const STONE_LOW := Color("6c5737")
const STONE_BASE := Color("98805a")
const STONE_HIGH := Color("c2ac7b")
const STONE_LIGHT := Color("e2d4a7")
const RIM_BRASS := Color("d19a3f")
const APRON_SIZE := Vector2(1280, 960)
const APRON_BASE := Color("31472b")
const APRON_GRASS := Color("6e8d47")
const APRON_LIGHT := Color("a8b967")

var _language: VisualLanguage
var _atlas_texture: Texture2D
var _atlas_attempted := false
var _cached_court_id := -1
var _cached_revision := -1
var _cells: Array[Vector2i] = []
var _cell_set: Dictionary = {}
var _centers: Dictionary = {}
var _vertices: Dictionary = {}
var _projectile_size_cache: Dictionary = {}


func configure(shared_language: VisualLanguage) -> bool:
	if shared_language == null or shared_language.elements.is_empty() or shared_language.reaction_materials.is_empty():
		_language = null
		return false
	_language = shared_language
	return true


func draw_ground(canvas: CanvasItem, court: RefCounted, tick: float, reduced: bool, draw_district_base: bool = true) -> bool:
	if canvas == null or court == null or _language == null or not is_finite(tick) or not court.has_method("view"):
		return false
	if not _prepare_court(court):
		return false
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var views: Dictionary = {}
	for cell: Vector2i in _cells:
		var value: Variant = court.call("view", cell, tick)
		views[cell] = value if value is Dictionary else {}
	var regions := _collect_render_regions(court, views, tick)
	if regions.is_empty() and _has_active_material(views):
		return false
	if draw_district_base:
		_draw_apron(canvas, reduced)
		_draw_stone(canvas, court, reduced)
	_draw_water(canvas, views, regions.get("water", {}), tick, reduced)
	_draw_fire(canvas, views, regions.get("fire", {}), tick, reduced)
	for material: String in INGREDIENT_MATERIALS:
		if material not in ["water", "fire"]:
			_draw_shared_material(canvas, regions.get(material, {}), material, tick, reduced)
	_draw_steam(canvas, views, regions.get("steam", {}), tick, reduced)
	_draw_mirror_product(canvas, regions.get("flood", {}), "flood", tick, reduced)
	_draw_mirror_product(canvas, regions.get("conflagration", {}), "conflagration", tick, reduced)
	for material: String in PRODUCT_MATERIALS:
		if material not in ["steam", "flood", "conflagration"]:
			_draw_shared_material(canvas, regions.get(material, {}), material, tick, reduced)
	if draw_district_base:
		_draw_outer_rim(canvas)
	return true


func draw_cue(canvas: CanvasItem, cue: Dictionary, reduced: bool) -> bool:
	if canvas == null or _language == null or cue.is_empty():
		return false
	var wire_id := int(cue.get("source_wire_id", 0))
	var definition := CombatTuning.cast_definition(wire_id)
	if definition.is_empty():
		return false
	var element_wire := int(definition.get("element_wire_id", 0))
	if not ELEMENT_IDS.has(element_wire):
		return false
	var palette := _element_palette(element_wire)
	var dark: Color = palette[0]
	var base: Color = palette[1]
	var bright: Color = palette[2]
	var kind := String(cue.get("kind", ""))
	var event_type := String(cue.get("event_type", ""))
	var semantic := event_type if not event_type.is_empty() else kind
	var position := _cue_point(cue, "position", Vector2.ZERO)
	var progress := _cue_progress(cue)
	var opacity := 1.0 - progress
	if semantic == "hex_clash":
		return _draw_hex_clash_cue(canvas, cue, position, palette, progress, reduced)
	if kind == "pixel_release":
		_draw_cue_cross(canvas, position, dark, base, bright, opacity, progress, reduced, false)
		return true
	if kind == "spray" or event_type == "spray_fired":
		return _draw_spray_cue(canvas, cue, definition, dark, base, bright, opacity, reduced)
	if semantic in ["impact", "pixel_impact", "projectile_hit", "spray_hit", "field_triggered", "projectile_bounced"]:
		_draw_cue_cross(canvas, position, dark, base, bright, opacity, progress, reduced, true)
		return true
	if semantic in ["refusal", "cast_refused", "cast_blocked"]:
		var extent := 7.0 + progress * 3.0
		canvas.draw_line(position + Vector2(-extent, -extent), position + Vector2(extent, extent), Color(dark, opacity * 0.88), 4.0)
		canvas.draw_line(position + Vector2(-extent, extent), position + Vector2(extent, -extent), Color(bright, opacity), 2.0)
		return true
	return false


func draw_projectile(canvas: CanvasItem, shot: ProjectileState, tick: float, alpha: float, reduced: bool) -> bool:
	if canvas == null or _language == null or shot == null or not is_finite(tick) or not is_finite(alpha):
		return false
	if shot.lifetime_ticks <= 0:
		_projectile_size_cache.erase(shot.entity_id)
		return true
	var family := _projectile_family(shot)
	var column := int(ELEMENT_COLUMNS.get(shot.element_wire_id, -1))
	if not FAMILY_ROWS.has(family) or column < 0:
		return false
	var position := ProjectileMotion.interpolated_position(shot, alpha).round()
	var travel := ProjectileMotion.travel_direction(shot)
	var angle := _octant_angle(travel)
	var authored_size := float(FAMILY_SIZE[family])
	var strength := projectile_strength_pair(shot)
	if strength.y <= 0:
		_projectile_size_cache.erase(shot.entity_id)
		return true
	var target_size := strength_scaled_size(authored_size, strength.y, strength.x)
	var size := cache_projectile_size(
		_projectile_size_cache, shot.entity_id, projectile_cache_identity(shot),
		shot.lifetime_ticks, tick + clampf(alpha, 0.0, 1.0), target_size, reduced,
	)
	var texture := _projectile_atlas()
	if texture != null and size > 0.0:
		var row := int(FAMILY_ROWS[family])
		var source := Rect2(Vector2(column * ATLAS_CELL.x, row * ATLAS_CELL.y), Vector2(ATLAS_CELL))
		var shimmer := 1.0 if reduced else 0.94 + 0.06 * float(posmod(int(floor(tick)) + shot.entity_id, 8) < 4)
		var half_size := Vector2.ONE * size * 0.5
		var vertices := _world_points(PackedVector2Array([
			-half_size, Vector2(half_size.x, -half_size.y), half_size, Vector2(-half_size.x, half_size.y),
		]), position, angle)
		var atlas_size := Vector2(texture.get_size())
		var uv_start := source.position / atlas_size
		var uv_end := source.end / atlas_size
		var uvs := PackedVector2Array([
			uv_start, Vector2(uv_end.x, uv_start.y), uv_end, Vector2(uv_start.x, uv_end.y),
		])
		canvas.draw_polygon(vertices, PackedColorArray([Color(1.0, 1.0, 1.0, shimmer)]), uvs, texture)
	elif size > 0.0:
		_draw_projectile_fallback(canvas, position, angle, family, shot.element_wire_id, size, reduced)
	_draw_projectile_collision_outline(canvas, position, shot.radius, shot.element_wire_id, reduced)
	return true


func _draw_apron(canvas: CanvasItem, reduced: bool) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, APRON_SIZE), APRON_BASE, true)
	var step := 112 if reduced else 78
	for y: int in range(step / 2, int(APRON_SIZE.y), step):
		for x: int in range(step / 2, int(APRON_SIZE.x), step):
			var seed := _mix(x * 19_349_663 ^ y * 73_856_093 ^ 271)
			var anchor := Vector2(
				float(x + posmod(seed, 25) - 12),
				float(y + posmod(seed >> 6, 21) - 10),
			).round()
			if seed % 5 == 0:
				var pebble_size := Vector2(4 + posmod(seed >> 11, 4), 2)
				canvas.draw_rect(Rect2(anchor - pebble_size * 0.5, pebble_size), Color(STONE_LOW, 0.38), true)
				canvas.draw_line(anchor - Vector2(1, 1), anchor + Vector2(2, -1), Color(STONE_HIGH, 0.30), 1.0)
				continue
			var blade_height := 4.0 + float(posmod(seed >> 12, 4))
			var sway := -2.0 if seed & 1 else 2.0
			canvas.draw_line(anchor, anchor + Vector2(sway, -blade_height), Color(APRON_GRASS, 0.54), 2.0)
			if not reduced and seed % 3 == 0:
				canvas.draw_line(anchor + Vector2(2, 0), anchor + Vector2(4 - sway, -blade_height + 1), Color(APRON_LIGHT, 0.32), 1.0)


func _prepare_court(court: RefCounted) -> bool:
	var cells_value: Variant = court.get("cells")
	if not cells_value is Dictionary:
		return false
	var revision := int(court.get("render_revision"))
	var court_id := int(court.get_instance_id())
	if court_id == _cached_court_id and revision == _cached_revision:
		return not _cells.is_empty()
	var cells: Dictionary = cells_value
	_cells.clear()
	_cell_set.clear()
	_centers.clear()
	_vertices.clear()
	for key: Variant in cells.keys():
		if key is Vector2i:
			_cells.append(key)
	_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var origin_value: Variant = court.get("origin")
	var origin: Vector2i = origin_value if origin_value is Vector2i else COURT_ORIGIN
	for cell: Vector2i in _cells:
		_cell_set[cell] = true
		_centers[cell] = Vector2(HexGrid.center(cell) + origin) / 1000.0
		var polygon := PackedVector2Array()
		for fixed_vertex: Vector2i in HexGrid.vertices(cell):
			polygon.append(Vector2(fixed_vertex + origin) / 1000.0)
		_vertices[cell] = polygon
	_cached_court_id = court_id
	_cached_revision = revision
	return not _cells.is_empty()


func _draw_stone(canvas: CanvasItem, court: RefCounted, reduced: bool) -> void:
	var cells: Dictionary = court.get("cells")
	for cell: Vector2i in _cells:
		var record: Dictionary = cells.get(cell, {})
		var terrain := int(record.get("terrain", 0))
		var elevation := clampi(int(record.get("elevation", 0)), 0, 3)
		var seed := _cell_seed(cell, terrain * 17 + elevation * 31)
		var fill := STONE_BASE.lerp(STONE_HIGH, 0.06 * float(elevation))
		fill = fill.lerp(STONE_LOW, 0.08) if seed % 5 == 0 else fill
		canvas.draw_colored_polygon(_vertices[cell], fill)
		var center: Vector2 = _centers[cell]
		var mark_count := 1 if reduced else 3
		for mark_index: int in range(mark_count):
			var mark_seed := _mix(seed + mark_index * 97)
			var offset := Vector2(float(posmod(mark_seed, 31) - 15), float(posmod(mark_seed >> 6, 25) - 12))
			var length := 3.0 + float(posmod(mark_seed >> 12, 4))
			var color := Color(STONE_LIGHT if mark_seed & 1 else STONE_DARK, 0.12 if reduced else 0.16)
			canvas.draw_line((center + offset).round(), (center + offset + Vector2(length, 0)).round(), color, 2.0)


func _collect_render_regions(court: RefCounted, views: Dictionary, tick: float) -> Dictionary:
	var result := {}
	for material: String in MATERIALS:
		result[material] = {}
	if not court.has_method("render_regions"):
		return result if not _has_active_material(views) else {}
	for material: String in MATERIALS:
		var quantity_key := material + "_quantity"
		var material_regions: Dictionary = result[material]
		for cell: Vector2i in _cells:
			var cell_view: Dictionary = views.get(cell, {})
			if int(cell_view.get(quantity_key, 0)) <= 0 and not bool(cell_view.get(material + "_present", false)):
				continue
			var raw: Variant = court.call("render_regions", cell, material, tick)
			if not raw is Array or (raw as Array).is_empty():
				return {}
			var prepared: Array[Dictionary] = []
			for value: Variant in raw:
				var expected_polygon: PackedVector2Array = _vertices.get(cell, PackedVector2Array())
				var region := _prepare_region(value, material, expected_polygon)
				if region.is_empty():
					return {}
				prepared.append(region)
			prepared.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.footprint_id) < int(b.footprint_id))
			material_regions[cell] = prepared
	return result


func _prepare_region(value: Variant, material: String, expected_polygon: PackedVector2Array = PackedVector2Array()) -> Dictionary:
	if not value is Dictionary:
		return {}
	var source: Dictionary = value
	var phase := String(source.get("phase", ""))
	var has_owner := source.has("owner_key") or source.has("owner") or source.has("owner_id") or source.has("source_ids")
	var has_expiry := source.has("expiry_tick") or source.has("expires")
	if phase.is_empty() or not source.has("footprint_id") or not source.has("danger") or not source.has("intensity") or not has_owner or not has_expiry:
		return {}
	var descriptor := _material_descriptor(material)
	var direction_value: Variant = source.get("direction", Vector2i(0, -1000))
	var source_ids_value: Variant = source.get("source_ids", [])
	if (
		descriptor.is_empty()
		or (source.has("recipe_wire_id") and int(source.recipe_wire_id) != int(descriptor.wire_id))
		or not direction_value is Vector2i
		or not source_ids_value is Array
		or (source.has("material") and String(source.material) != material)
	):
		return {}
	var raw_polygon: Variant = source.get("polygon")
	if not raw_polygon is PackedVector2Array:
		return {}
	var fixed_polygon: PackedVector2Array = raw_polygon
	# Court storage cells are the coverage contract. A region is one complete
	# authored cell polygon; presentation must not resurrect analytic disk/sector
	# clipping or invent a fallback for malformed authority data.
	if fixed_polygon.size() != 6:
		return {}
	var result := {
		"footprint_id": int(source.footprint_id), "fixed_polygon": fixed_polygon,
		"polygon": PackedVector2Array(), "phase": phase, "danger": bool(source.danger),
		"intensity": maxi(1, int(source.intensity)), "material": material,
		"owner_key": source.get("owner_key", source.get("owner", source.get("owner_id", source.get("source_ids", [])))),
		"owner": int(source.get("owner", source.get("owner_id", 0))),
		"source_ids": (source_ids_value as Array).duplicate(),
		"quantity": maxi(0, int(source.get("quantity", 0))),
		"expiry_tick": int(source.get("expiry_tick", source.get("expires", 0))),
		"recipe_wire_id": int(source.get("recipe_wire_id", 0)),
		"direction": direction_value,
	}
	var polygon := PackedVector2Array()
	for fixed_point: Vector2 in fixed_polygon:
		var point := fixed_point / 1000.0 # Court returns absolute world-fixed cell vertices.
		if not point.is_finite():
			return {}
		polygon.append(point)
	if expected_polygon.size() == 6 and not _same_polygon_vertices(polygon, expected_polygon):
		return {}
	result.polygon = polygon
	return result


static func _same_polygon_vertices(first: PackedVector2Array, second: PackedVector2Array) -> bool:
	if first.size() != second.size():
		return false
	var remaining: Array[Vector2] = []
	for point: Vector2 in second:
		remaining.append(point)
	for point: Vector2 in first:
		var match_index := -1
		for index: int in remaining.size():
			if point.is_equal_approx(remaining[index]):
				match_index = index
				break
		if match_index < 0:
			return false
		remaining.remove_at(match_index)
	return remaining.is_empty()


func _has_active_material(views: Dictionary) -> bool:
	for cell: Vector2i in _cells:
		var view: Dictionary = views.get(cell, {})
		for material: String in MATERIALS:
			if int(view.get(material + "_quantity", 0)) > 0 or bool(view.get(material + "_present", false)): return true
	return false


func _draw_mirror_product(canvas: CanvasItem, regions_by_cell: Dictionary, material: String, tick: float, reduced: bool) -> void:
	var counts := _region_edge_counts(regions_by_cell)
	var base := _language.reaction_color(material, "base")
	var bright := _language.reaction_color(material, "bright")
	var dark := _language.reaction_color(material, "dark")
	for cell: Vector2i in regions_by_cell:
		for region: Dictionary in regions_by_cell[cell]:
			var active: bool = region.phase == "active"
			var decaying: bool = region.phase == "decaying"
			var intensity := clampf(float(region.intensity) / 1000.0, 0.1, 1.5)
			var opacity := ((0.19 if reduced else 0.25) + 0.06 * intensity) * (0.45 if decaying else 1.0)
			canvas.draw_colored_polygon(region.polygon, Color(base, opacity))
			_draw_region_outline(canvas, region, counts, Color(bright if active else dark, 0.80 if active else 0.50), 2.0)
			var center := _polygon_centroid(region.polygon)
			var radius := _polygon_clearance(center, region.polygon) - 3.0
			if radius < 5.0: continue
			if material == "flood":
				var direction := Vector2(region.direction).normalized()
				var side := Vector2(-direction.y, direction.x)
				var drift := 0.0 if reduced or not active else sin(tick * 0.08) * minf(2.0, radius * 0.1)
				for offset: float in [-0.30, 0.30]:
					var anchor := center + direction * (radius * offset + drift)
					canvas.draw_line(anchor - direction * radius * 0.18 - side * radius * 0.28, anchor + direction * radius * 0.15, Color(bright, 0.85), 2.0)
					canvas.draw_line(anchor + direction * radius * 0.15, anchor - direction * radius * 0.18 + side * radius * 0.28, Color(bright, 0.85), 2.0)
			else:
				var phase := "active" if active else "cooling" if decaying else "ignition"
				_draw_fire_region_mark(canvas, region.polygon, phase, dark, base, bright, _language.reaction_color(material, "danger"), tick, int(region.footprint_id), reduced)
				# A restrained three-point crown distinguishes the mirror product
				# from one ordinary Fire ingredient without obscuring its footprint.
				if active:
					for offset: float in [-0.45, 0.45]:
						var anchor := center + Vector2(radius * offset, radius * 0.12)
						canvas.draw_line(anchor, anchor + Vector2(0, -radius * 0.35), Color(bright, 0.78), 2.0)


func _draw_water(canvas: CanvasItem, _views: Dictionary, regions_by_cell: Dictionary, tick: float, reduced: bool) -> void:
	var edge_counts := _region_edge_counts(regions_by_cell)
	for cell: Vector2i in regions_by_cell:
		for region: Dictionary in regions_by_cell[cell]:
			var style := _water_region_style(region, reduced)
			canvas.draw_colored_polygon(region.polygon, Color(style.base, style.fill_opacity))
			_draw_region_outline(canvas, region, edge_counts, Color(style.edge, style.edge_opacity), style.edge_width)
			var seed := _cell_seed(cell, int(region.footprint_id) * 401)
			_draw_water_region_mark(canvas, region.polygon, style.bright, style.phase, tick, seed, reduced)


func _draw_fire(canvas: CanvasItem, _views: Dictionary, regions_by_cell: Dictionary, tick: float, reduced: bool) -> void:
	var edge_counts := _region_edge_counts(regions_by_cell)
	for cell: Vector2i in regions_by_cell:
		for region: Dictionary in regions_by_cell[cell]:
			var style := _fire_region_style(region, reduced)
			canvas.draw_colored_polygon(region.polygon, Color(style.base, style.fill_opacity))
			_draw_region_outline(canvas, region, edge_counts, Color(style.edge, style.edge_opacity), style.edge_width)
			var seed := _cell_seed(cell, int(region.footprint_id) * 809)
			_draw_fire_region_mark(canvas, region.polygon, style.phase, style.dark, style.base, style.bright, style.danger_color, tick, seed, reduced)


func _draw_steam(canvas: CanvasItem, views: Dictionary, regions_by_cell: Dictionary, tick: float, reduced: bool) -> void:
	var edge_counts := _region_edge_counts(regions_by_cell)
	for cell: Vector2i in regions_by_cell:
		var heat := int((views.get(cell, {}) as Dictionary).get("steam_heat", 1000))
		for region: Dictionary in regions_by_cell[cell]:
			var style := _steam_region_style(region, heat, reduced)
			canvas.draw_colored_polygon(region.polygon, Color(style.base, style.fill_opacity))
			_draw_region_outline(canvas, region, edge_counts, Color(style.dark, style.edge_opacity), style.edge_width)
			if bool(style.danger):
				_draw_region_outline(canvas, region, edge_counts, Color(style.danger_color, style.danger_opacity), 1.0)
			var seed := _cell_seed(cell, int(region.footprint_id) * 1201 + heat)
			_draw_steam_region_mark(canvas, region.polygon, style.dark, style.bright, style.danger_color, style.palette_phase, tick, seed, reduced, bool(style.danger))


func _draw_shared_material(canvas: CanvasItem, regions_by_cell: Dictionary, material: String, tick: float, reduced: bool) -> void:
	if regions_by_cell.is_empty():
		return
	var edge_counts := _region_edge_counts(regions_by_cell)
	for cell: Vector2i in regions_by_cell:
		for region: Dictionary in regions_by_cell[cell]:
			var style := _shared_material_style(material, region, reduced)
			if style.is_empty():
				continue
			canvas.draw_colored_polygon(region.polygon, Color(style.base, style.fill_opacity))
			_draw_region_outline(canvas, region, edge_counts, Color(style.edge, style.edge_opacity), style.edge_width)
			var seed := _cell_seed(cell, int(region.footprint_id) * 1597 + int(style.wire_id))
			_draw_shared_material_mark(canvas, region, style, tick, seed, reduced)


func _material_descriptor(material: String) -> Dictionary:
	if material in INGREDIENT_MATERIALS:
		return {
			"material": material, "wire_id": 0, "ingredient": true,
			"first": material, "second": material,
			"shape": _language.element_shape(material),
			"cadence": _language.element_cadence(material),
			"atmospheric": ATMOSPHERIC_MATERIALS.has(material),
		}
	for row: Array in PRODUCT_ROWS:
		if String(row[0]) == material:
			return {
				"material": material, "wire_id": int(row[1]), "ingredient": false,
				"first": String(row[2]), "second": String(row[3]), "shape": String(row[4]),
				"cadence": "%s+%s" % [_language.element_cadence(String(row[2])), _language.element_cadence(String(row[3]))],
				"atmospheric": ATMOSPHERIC_MATERIALS.has(material),
			}
	return {}


func _shared_material_style(material: String, region: Dictionary, reduced: bool) -> Dictionary:
	var descriptor := _material_descriptor(material)
	if descriptor.is_empty():
		return {}
	var phase := String(region.get("phase", "active"))
	var first := String(descriptor.first)
	var second := String(descriptor.second)
	var dark := _language.element_phase_color(first, phase, "dark")
	var base := _language.element_phase_color(first, phase, "base")
	var bright := _language.element_phase_color(first, phase, "bright")
	if second != first:
		dark = dark.lerp(_language.element_phase_color(second, phase, "dark"), 0.42)
		base = base.lerp(_language.element_phase_color(second, phase, "base"), 0.50)
		bright = bright.lerp(_language.element_phase_color(second, phase, "bright"), 0.58)
	# Active danger keeps its dominant material instead of averaging Fire into
	# a green Air corridor. Geometry and phase still come from authority.
	if material in ["magma", "firestorm"]:
		dark = _language.element_phase_color("fire", phase, "dark")
		base = _language.element_phase_color("fire", phase, "base")
		bright = _language.element_phase_color("fire", phase, "bright")
	elif material in ["mud", "dustfront"]:
		dark = _language.element_phase_color("earth", phase, "dark")
		base = _language.element_phase_color("earth", phase, "base")
		bright = _language.element_phase_color("earth", phase, "bright")
	var intensity := _intensity_ratio(region)
	var phase_opacity := 0.66 if phase in ["forming", "ignition"] else 0.52 if phase in ["decaying", "cooling"] else 1.0
	var atmospheric := bool(descriptor.atmospheric)
	var fill_opacity := (0.13 if reduced else 0.18) if atmospheric else (0.26 if reduced else 0.34)
	fill_opacity *= intensity * phase_opacity
	if atmospheric:
		fill_opacity = minf(fill_opacity, 0.22)
	var danger := bool(region.get("danger", false))
	return {
		"material": material, "wire_id": int(descriptor.wire_id), "shape": String(descriptor.shape), "cadence": String(descriptor.cadence),
		"phase": phase, "danger": danger, "atmospheric": atmospheric,
		"dark": dark, "base": base, "bright": bright,
		"edge": bright if danger else dark,
		"fill_opacity": fill_opacity, "edge_opacity": 0.88 if danger else 0.72,
		"edge_width": 2.5 if danger else 2.0, "motion": not reduced, "mark_count": 1,
	}


func _draw_shared_material_mark(canvas: CanvasItem, region: Dictionary, style: Dictionary, tick: float, seed: int, reduced: bool) -> void:
	var polygon: PackedVector2Array = region.polygon
	var center := _polygon_centroid(polygon)
	var radius := _polygon_clearance(center, polygon) - 3.0
	if radius < 4.0:
		return
	var shape := String(style.shape)
	var material := String(style.material)
	if material == "earth":
		# Loose, harmless ingredient stock must not imply an active solid pillar.
		for offset: Vector2 in [Vector2(-0.30, 0.12), Vector2(0.22, -0.20), Vector2(0.31, 0.30)]:
			var pebble := center + offset * radius
			canvas.draw_rect(Rect2(pebble - Vector2(3, 2), Vector2(6, 4)), Color(style.dark, 0.82))
			canvas.draw_line(pebble - Vector2(2, 2), pebble + Vector2(2, -2), Color(style.bright, 0.88), 1.0)
		return
	if int(style.wire_id) == 301 and String(region.get("phase", "")) == "active":
		_draw_earth_pillar(canvas, polygon, style.dark, style.base, style.bright, radius)
		return
	var motion := 0.0 if reduced else sin((tick + float(seed % 71)) * _cadence_rate(String(style.cadence))) * minf(2.0, radius * 0.08)
	var direction := Vector2(region.get("direction", Vector2i(0, -1000))).normalized()
	if direction.is_zero_approx():
		direction = Vector2.UP
	var side := Vector2(-direction.y, direction.x)
	if material == "firestorm":
		_draw_fire_region_mark(canvas, polygon, style.phase, style.dark, style.base, style.bright, style.bright, tick, seed, reduced)
		# Arrowheads indicate front travel; the flame remains the danger mark.
		for sign_value: float in [-1.0, 1.0]:
			var tip := center + side * radius * 0.62 * sign_value + direction * radius * 0.18
			canvas.draw_polyline(PackedVector2Array([tip - direction * radius * 0.22 - side * radius * 0.12, tip, tip - direction * radius * 0.22 + side * radius * 0.12]), Color(style.bright, 0.90), 2.0, false)
		return
	if material == "magma":
		var crack := PackedVector2Array([center + Vector2(-0.66, 0.35) * radius, center + Vector2(-0.16, 0.03) * radius, center + Vector2(0.18, 0.16) * radius, center + Vector2(0.58, -0.44) * radius])
		canvas.draw_polyline(crack, Color(style.dark, 0.96), 6.0, false)
		canvas.draw_polyline(crack, Color(style.bright, 0.96), 2.0, false)
		canvas.draw_line(center + Vector2(-0.16, 0.03) * radius, center + Vector2(-0.34, -0.48) * radius, Color(style.base, 0.96), 3.0)
		return
	if material in ["dustfront", "mistcurrent"]:
		var flow := side if material == "dustfront" else direction
		var flow_side := Vector2(-flow.y, flow.x)
		for lane: float in [-0.32, 0.32]:
			var tip := center + flow * radius * (0.36 + motion / maxf(radius, 1.0)) + flow_side * lane * radius
			canvas.draw_polyline(PackedVector2Array([tip - flow * radius * 0.48 - flow_side * radius * 0.16, tip, tip - flow * radius * 0.48 + flow_side * radius * 0.16]), Color(style.bright, 0.94), 2.0, false)
		return
	if material == "wind" or shape in ["corridor", "flow", "water_path", "growing_strip", "pulse_lane", "bands", "frost_path", "reveal_line"]:
		for lane: float in [-0.34, 0.0, 0.34]:
			var lane_center := center + side * radius * lane + direction * motion
			canvas.draw_line(lane_center - direction * radius * 0.56, lane_center + direction * radius * 0.56, Color(style.bright, 0.82), 2.0)
		return
	if material == "vortex":
		var angle := 0.0 if reduced else tick * 0.035
		for spoke: int in 3:
			var start := angle + float(spoke) * TAU / 3.0
			var finish := start + PI * 0.43
			canvas.draw_polyline(_arc_points(center, radius * 0.63, start, finish, 9), Color(style.bright, 0.92), 2.0, false)
			var tip := center + Vector2.from_angle(finish) * radius * 0.63
			var tangent := Vector2(-sin(finish), cos(finish))
			var radial := Vector2.from_angle(finish)
			canvas.draw_polyline(PackedVector2Array([tip - tangent * radius * 0.23 - radial * radius * 0.12, tip, tip - tangent * radius * 0.23 + radial * radius * 0.12]), Color(style.dark, 0.94), 2.0, false)
		return
	if shape in ["ring", "annulus", "border"]:
		canvas.draw_polyline(_arc_points(center, radius * 0.72, 0.0, TAU, 24), Color(style.dark, 0.86), 3.0, false)
		canvas.draw_polyline(_arc_points(center, radius * 0.46, 0.0, TAU, 20), Color(style.bright, 0.76), 2.0, false)
		return
	if material == "ice" or shape in ["fracture", "lens", "entry_mark"]:
		for arm: int in 6:
			var angle := float(arm) * TAU / 6.0
			canvas.draw_line(center, center + Vector2.from_angle(angle) * radius * 0.68, Color(style.bright, 0.86), 2.0)
		return
	if material == "charge" or shape in ["branch", "node", "drifting_node"]:
		var bolt := PackedVector2Array([
			center + Vector2(-radius * 0.34, -radius * 0.62), center + Vector2(radius * 0.04, -radius * 0.12),
			center + Vector2(-radius * 0.12, -radius * 0.12), center + Vector2(radius * 0.34, radius * 0.62),
		])
		canvas.draw_polyline(bolt, Color(style.bright, 0.94), 3.0, false)
		return
	if material == "light" or shape in ["plane", "reveal_pulse", "observation", "bend", "reveal_area"]:
		var diamond := PackedVector2Array([
			center + Vector2(0, -radius * 0.62), center + Vector2(radius * 0.52, 0),
			center + Vector2(0, radius * 0.62), center + Vector2(-radius * 0.52, 0), center + Vector2(0, -radius * 0.62),
		])
		canvas.draw_polyline(diamond, Color(style.bright, 0.90), 2.0, false)
		return
	if material == "dark" or shape in ["disk", "ember_veil", "motion_veil", "entry_veil", "attrition_veil"]:
		canvas.draw_polyline(_arc_points(center - Vector2(radius * 0.10, 0), radius * 0.54, -PI * 0.70, PI * 0.70, 13), Color(style.dark, 0.88), 3.0, false)
		canvas.draw_polyline(_arc_points(center + Vector2(radius * 0.10, 0), radius * 0.38, -PI * 0.70, PI * 0.70, 11), Color(style.bright, 0.76), 2.0, false)
		return
	# Remaining authored products retain both source colors in a bounded crossed
	# mark. The mark names the recipe family without implying its gameplay rule.
	canvas.draw_line(center - direction * radius * 0.54, center + direction * radius * 0.54, Color(style.dark, 0.90), 3.0)
	canvas.draw_line(center - side * radius * 0.42, center + side * radius * 0.42, Color(style.bright, 0.86), 2.0)


func _draw_earth_pillar(canvas: CanvasItem, polygon: PackedVector2Array, dark: Color, base: Color, bright: Color, radius: float) -> void:
	var geometry := _earth_pillar_geometry(polygon, minf(7.0, radius * 0.25))
	for face_value: Variant in geometry.get("faces", []):
		var face: PackedVector2Array = face_value
		canvas.draw_colored_polygon(face, Color(dark, 0.74))
		canvas.draw_polyline(_closed(face), Color(dark, 0.86), 1.0, false)
	var top: PackedVector2Array = geometry.get("top", PackedVector2Array())
	if top.size() == 6:
		canvas.draw_colored_polygon(top, Color(base, 0.92))
		canvas.draw_polyline(_closed(top), Color(bright, 0.86), 2.0, false)


static func _earth_pillar_geometry(polygon: PackedVector2Array, height: float) -> Dictionary:
	if polygon.size() != 6 or not is_finite(height) or height <= 0.0:
		return {}
	var center := _polygon_centroid(polygon)
	var clearance := _polygon_clearance(center, polygon)
	if clearance <= 0.0:
		return {}
	var top_center := center + Vector2(0, -minf(height, clearance * 0.24))
	var base := PackedVector2Array()
	var top := PackedVector2Array()
	for vertex: Vector2 in polygon:
		base.append(vertex.lerp(center, 0.24))
		# Both endpoints are inside the convex authored hex, so every top edge
		# and side face remains inside authority even with the visible rise.
		top.append(vertex.lerp(top_center, 0.50))
	var faces: Array[PackedVector2Array] = []
	for index: int in 6:
		faces.append(PackedVector2Array([base[index], base[(index + 1) % 6], top[(index + 1) % 6], top[index]]))
	return {"top": top, "base": base, "faces": faces, "height": top_center.distance_to(center)}


static func _arc_points(center: Vector2, radius: float, start_angle: float, end_angle: float, segments: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	if not center.is_finite() or not is_finite(radius) or radius <= 0.0 or segments < 2:
		return result
	for index: int in range(segments + 1):
		var ratio := float(index) / float(segments)
		result.append((center + Vector2.from_angle(lerpf(start_angle, end_angle, ratio)) * radius).round())
	return result


static func _cadence_rate(cadence: String) -> float:
	if "snapping" in cadence or "staccato" in cadence:
		return 0.11
	if "accelerating" in cadence or "flowing" in cadence:
		return 0.065
	if "measured_pulse" in cadence or "crystalline" in cadence:
		return 0.040
	if "lingering" in cadence or "weighty" in cadence:
		return 0.026
	return 0.050


func _water_region_style(region: Dictionary, reduced: bool) -> Dictionary:
	var phase := String(region.get("phase", "active"))
	var danger := bool(region.get("danger", false))
	var intensity := _intensity_ratio(region)
	var dark := _language.element_phase_color("water", phase, "dark")
	return {
		"phase": phase, "danger": danger,
		"dark": dark, "base": _language.element_phase_color("water", phase, "base"),
		"bright": _language.element_phase_color("water", phase, "bright"),
		"edge": _language.element_phase_color("water", phase, "danger") if danger else dark,
		"fill_opacity": (0.50 if reduced else 0.60) * intensity,
		"edge_opacity": 0.84, "edge_width": 2.0,
		"motion": not reduced, "mark_count": 1,
	}


func _fire_region_style(region: Dictionary, reduced: bool) -> Dictionary:
	var phase := String(region.get("phase", "active"))
	var danger := bool(region.get("danger", false))
	var intensity := _intensity_ratio(region)
	var dark := _language.element_phase_color("fire", phase, "dark")
	var danger_color := _language.element_phase_color("fire", phase, "danger")
	return {
		"phase": phase, "danger": danger,
		"dark": dark, "base": _language.element_phase_color("fire", phase, "base"),
		"bright": _language.element_phase_color("fire", phase, "bright"),
		"danger_color": danger_color, "edge": danger_color if danger else dark,
		"fill_opacity": (0.10 if phase != "active" else 0.18) * intensity,
		"edge_opacity": 0.90 if danger else 0.76, "edge_width": 2.5,
		"motion": not reduced, "mark_count": 1,
	}


func _steam_region_style(region: Dictionary, heat: int, reduced: bool) -> Dictionary:
	var phase := String(region.get("phase", "active"))
	var palette_phase := phase
	if phase == "active":
		palette_phase = "hot" if heat > 1000 else "cool" if heat < 1000 else "active"
	var danger := bool(region.get("danger", false))
	var intensity := _intensity_ratio(region)
	return {
		"phase": phase, "palette_phase": palette_phase, "danger": danger,
		"dark": _language.reaction_phase_color("steam", palette_phase, "dark"),
		"base": _language.reaction_phase_color("steam", palette_phase, "base"),
		"bright": _language.reaction_phase_color("steam", palette_phase, "bright"),
		"danger_color": _language.reaction_phase_color("steam", palette_phase, "danger"),
		"fill_opacity": (0.16 if reduced else 0.20) + 0.04 * intensity,
		"edge_opacity": 0.72, "edge_width": 3.0,
		"danger_opacity": 0.70 if reduced else 0.78,
		"motion": not reduced, "mark_count": 2,
	}


func _region_edge_counts(regions_by_cell: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	for cell: Vector2i in regions_by_cell:
		for region: Dictionary in regions_by_cell[cell]:
			var fixed_polygon: PackedVector2Array = region.fixed_polygon
			for index: int in fixed_polygon.size():
				var key := _region_edge_key(region, fixed_polygon[index], fixed_polygon[(index + 1) % fixed_polygon.size()])
				counts[key] = int(counts.get(key, 0)) + 1
	return counts


func _region_edge_key(region: Dictionary, first: Vector2, second: Vector2) -> String:
	var a := "%d,%d" % [roundi(first.x), roundi(first.y)]
	var b := "%d,%d" % [roundi(second.x), roundi(second.y)]
	var segment := a + ":" + b if a < b else b + ":" + a
	var owner_key := JSON.stringify(region.get("owner_key", null))
	if String(region.material) not in LEGACY_HEX_MATERIALS:
		# Unified fields cohere across adjacent records from the same owner and
		# phase. Record lifetime and intensity alter the fill without inventing an
		# internal wall; ownership, phase and danger remain visible boundaries.
		return "%s/%s/%s/%s/%s" % [String(region.material), String(region.phase), str(bool(region.danger)), owner_key, segment]
	return "%s/%d/%s/%s/%d/%d/%s/%s" % [String(region.material), int(region.footprint_id), String(region.phase), str(bool(region.danger)), int(region.intensity), int(region.get("expiry_tick", 0)), owner_key, segment]


func _draw_region_outline(canvas: CanvasItem, region: Dictionary, edge_counts: Dictionary, color: Color, width: float) -> void:
	var polygon: PackedVector2Array = region.polygon
	var fixed_polygon: PackedVector2Array = region.fixed_polygon
	var center := _polygon_centroid(polygon)
	for index: int in polygon.size():
		var key := _region_edge_key(region, fixed_polygon[index], fixed_polygon[(index + 1) % fixed_polygon.size()])
		if int(edge_counts.get(key, 0)) > 1:
			continue
		# Draw the cell boundary inward so hazard ink remains inside the complete
		# authoritative selected hex, including in reduced-effects mode.
		for triangle: PackedVector2Array in _inward_edge_triangles(polygon, index, width, center):
			canvas.draw_primitive(triangle, PackedColorArray([color]), PackedVector2Array())


static func _inward_edge_triangles(polygon: PackedVector2Array, edge_index: int, width: float, centroid: Vector2 = Vector2.INF) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var strip := _inward_edge_strip(polygon, edge_index, width, centroid)
	if strip.size() != 4: return result
	for indices: Vector3i in [Vector3i(0, 1, 2), Vector3i(0, 2, 3)]:
		var a := strip[indices.x]
		var b := strip[indices.y]
		var c := strip[indices.z]
		if absf((b - a).cross(c - a)) > 0.0001:
			result.append(PackedVector2Array([a, b, c]))
	return result


static func _inward_edge_strip(polygon: PackedVector2Array, edge_index: int, width: float, centroid: Vector2 = Vector2.INF) -> PackedVector2Array:
	if polygon.size() < 3 or edge_index < 0 or edge_index >= polygon.size() or not is_finite(width) or width <= 0.0:
		return PackedVector2Array()
	var center := centroid if centroid.is_finite() else _polygon_centroid(polygon)
	var first := polygon[edge_index]
	var second := polygon[(edge_index + 1) % polygon.size()]
	var first_ratio := clampf(width / maxf(1.0, first.distance_to(center)), 0.0, 0.48)
	var second_ratio := clampf(width / maxf(1.0, second.distance_to(center)), 0.0, 0.48)
	return PackedVector2Array([first, second, second.lerp(center, second_ratio), first.lerp(center, first_ratio)])


func _draw_outer_rim(canvas: CanvasItem) -> void:
	for cell: Vector2i in _cells:
		var polygon: PackedVector2Array = _vertices[cell]
		for edge_index: int in range(6):
			if _cell_set.has(cell + EDGE_NEIGHBORS[edge_index]):
				continue
			var start := polygon[edge_index]
			var finish := polygon[(edge_index + 1) % 6]
			canvas.draw_line(start + Vector2(0, 4), finish + Vector2(0, 4), Color(STONE_DARK, 0.92), 5.0)
			canvas.draw_line(start, finish, Color(RIM_BRASS, 0.72), 3.0)
			canvas.draw_line(start, finish, Color(STONE_LIGHT, 0.46), 1.0)


func _draw_water_region_mark(canvas: CanvasItem, polygon: PackedVector2Array, bright: Color, phase: String, tick: float, seed: int, reduced: bool) -> void:
	var center := _polygon_centroid(polygon)
	var radius := _polygon_clearance(center, polygon) - 2.0
	if radius < 3.0:
		return
	var motion := 0.0 if reduced else sin((tick + float(seed % 43)) * 0.075) * minf(2.0, radius * 0.12)
	var width := radius * (0.48 if phase == "forming" else 0.72 if phase == "active" else 0.38)
	var opacity := 0.70 if phase == "active" else 0.52
	var first := (center + Vector2(-width, motion)).round()
	var middle := (center + Vector2(width * 0.28, motion)).round()
	var finish := (center + Vector2(width, motion - minf(3.0, radius * 0.16))).round()
	canvas.draw_line(first, middle, Color(bright, opacity), 2.0)
	canvas.draw_line(middle, finish, Color(bright, opacity * 0.72), 2.0)


func _draw_fire_region_mark(canvas: CanvasItem, polygon: PackedVector2Array, phase: String, dark: Color, base: Color, bright: Color, danger: Color, tick: float, seed: int, reduced: bool) -> void:
	var center := _polygon_centroid(polygon)
	var radius := _polygon_clearance(center, polygon) - 2.5
	if radius < 3.5:
		return
	if phase == "ignition":
		var warning := PackedVector2Array([
			(center + Vector2(-radius * 0.58, radius * 0.34)).round(),
			(center + Vector2(0.0, -radius * 0.54)).round(),
			(center + Vector2(radius * 0.58, radius * 0.34)).round(),
		])
		canvas.draw_polyline(warning, Color(dark, 0.78), 4.0, false)
		canvas.draw_polyline(warning, Color(danger, 0.98), 2.0, false)
		return
	if phase == "cooling":
		var ember_width := radius * (0.42 if reduced else 0.56)
		var ember := PackedVector2Array([
			(center + Vector2(-ember_width, radius * 0.22)).round(),
			(center + Vector2(-ember_width * 0.10, radius * 0.06)).round(),
			(center + Vector2(ember_width, radius * 0.24)).round(),
		])
		canvas.draw_polyline(ember, Color(dark, 0.88), 3.0, false)
		canvas.draw_polyline(ember, Color(bright, 0.68), 1.0, false)
		return
	var sway := 0.0 if reduced else float(posmod(int(floor(tick / 4.0)) + seed, 3) - 1) * radius * 0.07
	var outer := PackedVector2Array([
		(center + Vector2(-radius * 0.54, radius * 0.43)).round(),
		(center + Vector2(-radius * 0.34, -radius * 0.08)).round(),
		(center + Vector2(-radius * 0.08 + sway, -radius * 0.76)).round(),
		(center + Vector2(radius * 0.12, -radius * 0.10)).round(),
		(center + Vector2(radius * 0.45 + sway, -radius * 0.46)).round(),
		(center + Vector2(radius * 0.54, radius * 0.43)).round(),
	])
	canvas.draw_colored_polygon(outer, dark)
	var inner := PackedVector2Array([
		(center + Vector2(-radius * 0.25, radius * 0.36)).round(),
		(center + Vector2(sway, -radius * 0.38)).round(),
		(center + Vector2(radius * 0.20, -radius * 0.02)).round(),
		(center + Vector2(radius * 0.34, radius * 0.36)).round(),
	])
	canvas.draw_colored_polygon(inner, base)
	var spark := PackedVector2Array([
		(center + Vector2(-radius * 0.05, radius * 0.27)).round(),
		(center + Vector2(radius * 0.10 + sway, -radius * 0.12)).round(),
		(center + Vector2(radius * 0.18, radius * 0.26)).round(),
	])
	canvas.draw_colored_polygon(spark, bright)


func _draw_steam_region_mark(canvas: CanvasItem, polygon: PackedVector2Array, dark: Color, bright: Color, danger: Color, phase: String, tick: float, seed: int, reduced: bool, harmful: bool) -> void:
	var center := _polygon_centroid(polygon)
	var radius := _polygon_clearance(center, polygon) - 2.0
	if radius < 5.0:
		return
	var drift := 0.0 if reduced else sin((tick + float(seed % 61)) * 0.045) * radius * 0.04
	var lift := -radius * 0.08 if phase == "hot" else radius * 0.05 if phase == "cool" else 0.0
	for curl_index: int in 2:
		var side := -1.0 if curl_index == 0 else 1.0
		var curl_center := center + Vector2(side * radius * 0.28, lift - radius * 0.04 * side)
		var points := PackedVector2Array([
			(curl_center + Vector2(-radius * 0.15, radius * 0.42)).round(),
			(curl_center + Vector2(radius * 0.08, radius * 0.24)).round(),
			(curl_center + Vector2(radius * 0.15 + drift, radius * 0.06)).round(),
			(curl_center + Vector2(-radius * 0.06 + drift, -radius * 0.10)).round(),
			(curl_center + Vector2(-radius * 0.12, -radius * 0.28)).round(),
			(curl_center + Vector2(radius * 0.12, -radius * 0.48)).round(),
		])
		canvas.draw_polyline(points, Color(dark, 0.82), 4.0, false)
		canvas.draw_polyline(points, Color(bright, 0.88 if reduced else 0.96), 2.0, false)
		if harmful:
			var scald := PackedVector2Array([points[1], points[1].lerp(points[2], 0.68)])
			canvas.draw_polyline(scald, Color(danger, 0.86 if reduced else 0.94), 1.5, false)


static func _polygon_centroid(polygon: PackedVector2Array) -> Vector2:
	if polygon.size() < 3: return Vector2.ZERO
	# Area weighting is invariant when the clipped circle contributes many
	# short edges on one side. A vertex mean pulled marks into boundary slivers.
	var origin := polygon[0]
	var weighted := Vector2.ZERO
	var area := 0.0
	for index: int in range(1, polygon.size() - 1):
		var a := polygon[index] - origin
		var b := polygon[index + 1] - origin
		var cross := a.cross(b)
		weighted += (a + b) * cross / 3.0
		area += cross
	return origin + weighted / area if absf(area) > 0.0001 else origin


static func _polygon_clearance(point: Vector2, polygon: PackedVector2Array) -> float:
	var clearance := INF
	for index: int in polygon.size():
		var first := polygon[index]
		var second := polygon[(index + 1) % polygon.size()]
		var segment := second - first
		var ratio := clampf((point - first).dot(segment) / maxf(segment.length_squared(), 0.0001), 0.0, 1.0)
		clearance = minf(clearance, point.distance_to(first + segment * ratio))
	return clearance


func _projectile_atlas() -> Texture2D:
	if _atlas_attempted:
		return _atlas_texture
	_atlas_attempted = true
	if not FileAccess.file_exists(ATLAS_PATH):
		return null
	var image := Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(ATLAS_PATH)) != OK or image.get_size() != Vector2i(192, 96):
		return null
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(image.get_data())
	if hash.finish().hex_encode() != ATLAS_RGBA_SHA256:
		return null
	_atlas_texture = ImageTexture.create_from_image(image)
	return _atlas_texture


func _draw_projectile_fallback(canvas: CanvasItem, position: Vector2, angle: float, family: String, element_wire: int, size: float, reduced: bool) -> void:
	var palette := _element_palette(element_wire if ELEMENT_IDS.has(element_wire) else 3)
	var dark: Color = palette[0]
	var base: Color = palette[1]
	var bright: Color = palette[2]
	var scale := size / 24.0
	var points := PackedVector2Array()
	match family:
		"rapid":
			points = PackedVector2Array([Vector2(6, 0), Vector2(0, -4), Vector2(-5, 0), Vector2(0, 4)])
		"heavy":
			points = PackedVector2Array([Vector2(10, 0), Vector2(5, -8), Vector2(-6, -8), Vector2(-10, 0), Vector2(-6, 8), Vector2(5, 8)])
		"spray":
			points = PackedVector2Array([Vector2(9, 0), Vector2(-5, -8), Vector2(-9, -3), Vector2(-4, 0), Vector2(-9, 3), Vector2(-5, 8)])
		_:
			points = PackedVector2Array([Vector2(11, 0), Vector2(1, -6), Vector2(-9, -3), Vector2(-5, 0), Vector2(-9, 3), Vector2(1, 6)])
	var world_points := _world_points(points, position, angle, scale)
	canvas.draw_colored_polygon(world_points, base)
	canvas.draw_polyline(_closed(world_points), dark, 2.0, false)
	var highlight := _world_points(PackedVector2Array([Vector2(2, 0), Vector2(7, 0)]), position, angle, scale)
	canvas.draw_line(highlight[0], highlight[1], Color(bright, 0.92 if reduced else 1.0), 2.0)


func _draw_projectile_collision_outline(canvas: CanvasItem, position: Vector2, radius_fixed: int, element_wire: int, reduced: bool) -> void:
	var radius := collision_radius_px(radius_fixed)
	if radius <= 0.0:
		return
	var palette := _element_palette(element_wire if ELEMENT_IDS.has(element_wire) else 3)
	var color: Color = palette[2] if reduced else palette[0]
	var point_count := clampi(ceili(radius * 0.85), 12, 32)
	canvas.draw_arc(position, radius, 0.0, TAU, point_count, Color(color, 0.30 if reduced else 0.36), 1.0, false)


static func collision_radius_px(radius_fixed: int) -> float:
	return maxf(0.0, float(radius_fixed) / 1000.0)


func _draw_spray_cue(canvas: CanvasItem, cue: Dictionary, definition: Dictionary, dark: Color, base: Color, bright: Color, opacity: float, reduced: bool) -> bool:
	var start := _cue_point(cue, "start", _cue_point(cue, "position", Vector2.ZERO))
	var endpoint := _cue_point(cue, "end", _cue_point(cue, "position", start))
	var lane := endpoint - start
	if lane.length_squared() <= 0.0:
		return false
	var fixed_range := _cue_fixed_range(cue)
	if fixed_range <= 0:
		fixed_range = int(definition.get("range", 0))
	var maximum_length := float(fixed_range) / 1000.0
	var length := minf(lane.length(), maximum_length) if maximum_length > 0.0 else lane.length()
	if length <= 0.0:
		return false
	var direction := lane.normalized()
	var side := direction.orthogonal()
	var cone_cosine_squared := clampf(float(definition.get("cone_cosine_squared_per_million", 820_000)) / 1_000_000.0, 0.05, 1.0)
	var half_angle := acos(sqrt(cone_cosine_squared))
	var offsets: Array[float] = [-1.0, -0.5, 0.0, 0.5, 1.0]
	if reduced:
		offsets = [-1.0, 0.0, 1.0]
	for offset: float in offsets:
		var target := start + direction.rotated(half_angle * offset) * length
		var shoulder := start.lerp(target, 0.30)
		var line_color := bright if is_zero_approx(offset) else base
		var line_opacity := opacity * (0.84 if is_zero_approx(offset) else 0.46)
		canvas.draw_polyline(PackedVector2Array([start, shoulder, target]), Color(line_color, line_opacity), 2.0 if is_zero_approx(offset) else 1.0, false)
	# The start brace identifies a transient cast fan. It does not surround or
	# fill the authoritative ground cells affected after resolution.
	var brace_distance := minf(18.0, length * 0.22)
	var brace_center := start + direction * brace_distance
	var brace_half := minf(8.0, tan(half_angle) * brace_distance)
	canvas.draw_line(brace_center - side * brace_half, brace_center + side * brace_half, Color(dark, opacity * 0.72), 2.0)
	return true


func _draw_cue_cross(canvas: CanvasItem, position: Vector2, dark: Color, base: Color, bright: Color, opacity: float, progress: float, reduced: bool, expanding: bool) -> void:
	var extent := 5.0 + (progress * (6.0 if reduced else 10.0) if expanding else 0.0)
	var thickness := 2.0 if reduced else 3.0
	canvas.draw_line(position - Vector2(extent, 0), position + Vector2(extent, 0), Color(dark, opacity * 0.82), thickness + 2.0)
	canvas.draw_line(position - Vector2(0, extent), position + Vector2(0, extent), Color(dark, opacity * 0.82), thickness + 2.0)
	canvas.draw_line(position - Vector2(extent, 0), position + Vector2(extent, 0), Color(base, opacity * 0.92), thickness)
	canvas.draw_line(position - Vector2(0, extent), position + Vector2(0, extent), Color(bright, opacity), thickness)
	canvas.draw_rect(Rect2(position - Vector2.ONE * 2.0, Vector2.ONE * 4.0), Color(bright, opacity), true)


func _draw_hex_clash_cue(canvas: CanvasItem, cue: Dictionary, fallback_position: Vector2, first_palette: Array[Color], progress: float, reduced: bool) -> bool:
	var position := fallback_position
	if cue.has("x") and cue.has("y"):
		position = Vector2(float(cue.x), float(cue.y)) / 1000.0
	var other_wire := int(cue.get("other_wire_id", 0))
	var other_definition := CombatTuning.cast_definition(other_wire)
	var second_palette := first_palette
	if not other_definition.is_empty():
		var other_element := int(other_definition.get("element_wire_id", 0))
		if ELEMENT_IDS.has(other_element):
			second_palette = _element_palette(other_element)
	var first_remaining := maxi(0, int(cue.get("first_remaining", 0)))
	var second_remaining := maxi(0, int(cue.get("second_remaining", 0)))
	var opacity := clampf(1.0 - progress, 0.0, 1.0)
	var base_extent := 4.0 if reduced else 5.0
	var first_extent := base_extent + minf(3.0, sqrt(float(first_remaining)))
	var second_extent := base_extent + minf(3.0, sqrt(float(second_remaining)))
	var first_alpha := opacity * (0.48 if first_remaining == 0 else 0.92)
	var second_alpha := opacity * (0.48 if second_remaining == 0 else 0.92)
	var first_dark: Color = first_palette[0]
	var first_base: Color = first_palette[1]
	var first_bright: Color = first_palette[2]
	var second_dark: Color = second_palette[0]
	var second_base: Color = second_palette[1]
	var second_bright: Color = second_palette[2]
	canvas.draw_line(position + Vector2(-first_extent, -first_extent), position + Vector2(first_extent, first_extent), Color(first_dark, opacity * 0.62), 4.0)
	canvas.draw_line(position + Vector2(-second_extent, second_extent), position + Vector2(second_extent, -second_extent), Color(second_dark, opacity * 0.62), 4.0)
	canvas.draw_line(position + Vector2(-first_extent, -first_extent), position + Vector2(first_extent, first_extent), Color(first_base, first_alpha), 2.0)
	canvas.draw_line(position + Vector2(-second_extent, second_extent), position + Vector2(second_extent, -second_extent), Color(second_base, second_alpha), 2.0)
	var outcome := first_bright if first_remaining > second_remaining else second_bright if second_remaining > first_remaining else first_bright.lerp(second_bright, 0.5)
	canvas.draw_rect(Rect2(position - Vector2.ONE, Vector2.ONE * 2.0), Color(outcome, opacity), true)
	return true


static func _cue_point(cue: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = cue.get(key, cue.get(key + "_world_px", cue.get(key + "_world", fallback)))
	if value is Vector2:
		return value
	if value is Vector2i:
		return Vector2(value)
	return fallback


static func _cue_fixed_range(cue: Dictionary) -> int:
	return int(cue.get("range", cue.get("range_fixed", cue.get("range_world_units", -1))))


static func _cue_progress(cue: Dictionary) -> float:
	var age_ticks := int(cue.get("age_ticks", 0))
	var duration_ticks := int(cue.get("duration_ticks", 0))
	if duration_ticks > 0:
		return clampf(float(age_ticks) / float(duration_ticks), 0.0, 1.0)
	var duration := maxf(0.001, float(cue.get("duration", 0.20)))
	var remaining := clampf(float(cue.get("remaining", duration)), 0.0, duration)
	if cue.has("remaining_ticks") and age_ticks > 0:
		var total_ticks := age_ticks + maxi(0, int(cue.get("remaining_ticks", 0)))
		return clampf(float(age_ticks) / float(maxi(1, total_ticks)), 0.0, 1.0)
	return clampf(1.0 - remaining / duration, 0.0, 1.0)


static func projectile_strength_pair(shot: ProjectileState) -> Vector2i:
	if shot == null:
		return Vector2i.ZERO
	if shot.initial_strength > 0:
		return Vector2i(shot.initial_strength, clampi(shot.remaining_strength, 0, shot.initial_strength))
	var legacy := maxi(1, shot.reaction_strength)
	return Vector2i(legacy, legacy)


static func strength_scaled_size(authored_size: float, remaining_strength: int, initial_strength: int, readable_floor: float = PROJECTILE_READABLE_FLOOR) -> float:
	if not is_finite(authored_size) or authored_size <= 0.0 or initial_strength <= 0 or remaining_strength <= 0:
		return 0.0
	var ratio := clampf(float(remaining_strength) / float(initial_strength), 0.0, 1.0)
	var minimum_size := clampf(readable_floor, 0.0, minf(PROJECTILE_READABLE_FLOOR, authored_size))
	return maxf(minimum_size, authored_size * sqrt(ratio))


static func projectile_cache_identity(shot: ProjectileState) -> String:
	if shot == null:
		return ""
	var strength := projectile_strength_pair(shot)
	return "%d/%d/%d/%d/%d/%d/%d" % [
		shot.owner_id, shot.team_id, shot.source_cast_id, shot.source_wire_id,
		shot.element_wire_id, strength.x, shot.radius,
	]


static func cache_projectile_size(cache: Dictionary, entity_id: int, identity: String, lifetime_ticks: int, tick: float, target_size: float, reduced: bool) -> float:
	if entity_id <= 0 or identity.is_empty() or lifetime_ticks <= 0 or not is_finite(tick) or not is_finite(target_size) or target_size < 0.0:
		return 0.0
	var entry: Dictionary = cache.get(entity_id, {})
	var reused := entry.is_empty() or String(entry.get("identity", "")) != identity or lifetime_ticks > int(entry.get("last_lifetime_ticks", lifetime_ticks))
	if reused:
		entry = {
			"identity": identity, "start_size": target_size, "target_size": target_size,
			"start_tick": tick, "end_tick": tick, "last_seen_tick": tick,
			"last_lifetime_ticks": lifetime_ticks, "expires_tick": tick + float(lifetime_ticks),
		}
		cache[entity_id] = entry
		prune_projectile_cache(cache, tick, entity_id)
		return target_size
	var current := _cached_projectile_size(entry, tick)
	if reduced:
		entry.start_size = target_size
		entry.target_size = target_size
		entry.start_tick = tick
		entry.end_tick = tick
	elif not is_equal_approx(float(entry.get("target_size", current)), target_size):
		entry.start_size = current
		entry.target_size = target_size
		entry.start_tick = tick
		entry.end_tick = tick + PROJECTILE_SHRINK_TICKS
	entry.last_seen_tick = tick
	entry.last_lifetime_ticks = lifetime_ticks
	entry.expires_tick = tick + float(lifetime_ticks)
	cache[entity_id] = entry
	prune_projectile_cache(cache, tick, entity_id)
	return _cached_projectile_size(entry, tick)


static func _cached_projectile_size(entry: Dictionary, tick: float) -> float:
	var start := float(entry.get("start_size", 0.0))
	var target := float(entry.get("target_size", start))
	var start_tick := float(entry.get("start_tick", tick))
	var end_tick := float(entry.get("end_tick", start_tick))
	if end_tick <= start_tick or tick >= end_tick:
		return target
	return lerpf(start, target, clampf((tick - start_tick) / (end_tick - start_tick), 0.0, 1.0))


static func prune_projectile_cache(cache: Dictionary, tick: float, keep_entity_id: int = -1) -> int:
	var removed := 0
	for key: Variant in cache.keys():
		var entity_id := int(key)
		var entry: Dictionary = cache.get(key, {})
		if entity_id != keep_entity_id and float(entry.get("expires_tick", -INF)) <= tick:
			cache.erase(key)
			removed += 1
	while cache.size() > PROJECTILE_CACHE_LIMIT:
		var oldest_id := -1
		var oldest_tick := INF
		for key: Variant in cache.keys():
			var entity_id := int(key)
			if entity_id == keep_entity_id:
				continue
			var seen := float((cache.get(key, {}) as Dictionary).get("last_seen_tick", -INF))
			if seen < oldest_tick or (is_equal_approx(seen, oldest_tick) and (oldest_id < 0 or entity_id < oldest_id)):
				oldest_tick = seen
				oldest_id = entity_id
		if oldest_id < 0:
			break
		cache.erase(oldest_id)
		removed += 1
	return removed


static func _projectile_family(shot: ProjectileState) -> String:
	var definition := CombatTuning.cast_definition(shot.source_wire_id)
	if not definition.is_empty():
		var shape := String(definition.get("shape", ""))
		if shape == "spray":
			return "spray"
		if shape != "projectile":
			return ""
		if bool(definition.get("repeat_while_held", false)):
			return "rapid"
		if int(definition.get("blast_radius", 0)) > 0:
			return "heavy"
		return "bolt"
	# Incomplete isolated fixtures may omit the source catalogue. The published
	# reaction ladder remains a bounded visual fallback, never simulation input.
	match shot.reaction_strength:
		15:
			return "heavy"
		5:
			return "bolt"
		3:
			return "spray"
		_:
			return "rapid"


func _element_palette(element_wire: int) -> Array[Color]:
	var element_id := String(ELEMENT_IDS.get(element_wire, "water"))
	return [
		_language.element_color(element_id, "dark"),
		_language.element_color(element_id, "base"),
		_language.element_color(element_id, "bright"),
	]


static func _intensity_ratio(region: Dictionary) -> float:
	return clampf(float(region.get("intensity", 1000)) / 1000.0, 0.35, 1.0)


static func _octant_angle(direction: Vector2) -> float:
	if direction.length_squared() <= 0.0:
		return PI * 0.5
	return roundf(direction.angle() / (PI * 0.25)) * (PI * 0.25)


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if not result.is_empty():
		result.append(result[0])
	return result


static func _world_points(points: PackedVector2Array, origin: Vector2, angle: float, scale: float = 1.0) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in points:
		result.append(origin + (point * scale).rotated(angle))
	return result


static func _cell_seed(cell: Vector2i, salt: int) -> int:
	return _mix(cell.x * 73_856_093 ^ cell.y * 19_349_663 ^ salt)


static func _mix(value: int) -> int:
	var mixed := value ^ (value >> 16)
	mixed *= 2_246_822_519
	mixed ^= mixed >> 13
	mixed *= 3_266_489_917
	return absi(mixed ^ (mixed >> 16))
