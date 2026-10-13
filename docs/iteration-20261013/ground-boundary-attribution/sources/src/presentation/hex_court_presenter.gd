class_name HexCourtPresenter
extends RefCounted


# H0/H2 presentation candidate. Court state, occupied cells, quantities and
# phases remain authoritative in HexCourt; this class only reads them.
const HexGrid = preload("res://src/sim/hex/hex_grid.gd")
const HexChemistryWorldScript = preload("res://src/sim/hex/hex_chemistry_world.gd")
const HexCourtScript = preload("res://src/sim/hex/hex_court.gd")
const RecipePolicy = preload("res://src/sim/hex/hex_recipe_policy.gd")
const Elements = preload("res://src/content/element_rules.gd")
const ArchiveContract = preload("res://src/presentation/archive_magic_contract.gd")
const ProjectileMotion = preload("res://src/presentation/projectile_presentation_motion.gd")
const ProjectileFacets = preload("res://src/presentation/hex_projectile_facets.gd")
const MagicGlow = preload("res://src/presentation/hex_magic_glow.gd")
const SurfaceGlowCache = preload("res://src/presentation/hex_surface_glow_cache.gd")
const Quality = preload("res://src/presentation/render_quality.gd")
const WaterMaterial = preload("res://src/presentation/hex_water_material_presenter.gd")
const RetroMarks = preload("res://src/presentation/retro_material_marks.gd")
const MaterialSurface = preload("res://src/presentation/hex_material_surface.gd")
const StoneFloor = preload("res://src/presentation/hex_stone_floor.gd")
const COMBAT_PHASE_MATERIALS := ["thermal_shock", "plasma_arc", "solar_flare", "superconduct", "arcflash", "radiance", "penumbra"]

const ATLAS_PATH := "res://assets/sprites/hex_court_v1/projectile_atlas.png"
const ATLAS_RGBA_SHA256 := "bbdbcf3212b17582a9d9314b53d5f671f1c45eaca4192c67d5591e45cd41e717"
const ATLAS_CELL := Vector2i(24, 24)
const COURT_ORIGIN := Vector2i(640_000, 480_000)
const EDGE_NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, -1), Vector2i(1, 0), Vector2i(0, 1),
	Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(0, -1),
]
const FAMILY_ROWS := {"rapid": 0, "bolt": 1, "heavy": 2, "spray": 3}
# Minimum art diameters retain tiny fast cores; larger physical projectiles
# start from their real diameter before remaining-strength presentation shrink.
const FAMILY_SIZE := {"rapid": 18.0, "bolt": 24.0, "heavy": 32.0, "spray": 24.0}
const PROJECTILE_CONTACT_DRAW_LIMIT := 8
const PROJECTILE_READABLE_FLOOR := 5.0
const PROJECTILE_SHRINK_TICKS := 6.0
const PROJECTILE_CACHE_LIMIT := 128
const SPRAY_CUE_RAYS := [0, 1, 2, 3, 4]
const SPRAY_CUE_REDUCED_RAYS := [0, 2, 4]
const STEAM_VENT_OUTLINE_WIDTH := 4.0
const STEAM_VENT_CORE_WIDTH := 2.0
const DRAW_STYLE_LIMIT := 64
const ELEMENT_COLUMNS := {1: 0, 2: 1, 3: 2, 4: 3, 5: 4, 6: 5, 7: 6, 8: 7}
const ELEMENT_IDS := {1: "earth", 2: "fire", 3: "water", 4: "wind", 5: "ice", 6: "charge", 7: "light", 8: "dark"}
const INGREDIENT_MATERIALS: Array[String] = Elements.IDS
const LEGACY_HEX_MATERIALS: Array[String] = ["water", "fire", "steam", "flood", "conflagration"]
static var PRODUCT_MATERIALS: Array[String] = _live_product_materials()
static var MATERIALS: Array[String] = _live_materials()
static var _product_wire_by_material: Dictionary = _live_product_wire_map()


static func _live_product_wire_map() -> Dictionary:
	var result := {}
	for wire: int in RecipePolicy.ACTIVE_RECIPE_WIRES:
		result[RecipePolicy.product_layer(wire)] = wire
	result.make_read_only()
	return result


static func _material_wire(material: String) -> int:
	return 0 if material in INGREDIENT_MATERIALS else int(_product_wire_by_material.get(material, -1))


static func _live_product_materials() -> Array[String]:
	var result: Array[String] = []
	for wire: int in RecipePolicy.active_wire_ids():
		result.append(RecipePolicy.product_layer(wire))
	return result


static func _live_materials() -> Array[String]:
	var result: Array[String] = []
	result.assign(Elements.IDS)
	result.append_array(_live_product_materials())
	return result

const ELEMENT_WIRES := {"earth": 1, "fire": 2, "water": 3, "wind": 4, "ice": 5, "charge": 6, "light": 7, "dark": 8}
# Product identities and visual grammar come from the compiled recipe rows;
# presentation owns palettes/motifs, not a second recipe identity table.
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
var _stone_floor := StoneFloor.new(STONE_DARK, STONE_LOW, STONE_BASE, STONE_HIGH, STONE_LIGHT)
var _contact_punctuation := preload("res://src/presentation/hex_contact_punctuation.gd").new()
var _cast_release := preload("res://src/presentation/hex_cast_release.gd").new()
var _atlas_texture: Texture2D
var _atlas_attempted := false
var _cached_court_id := -1
var _cached_revision := -1
# Geometry only, shared across the Garden's independent courts. Bound retained
# cells as well as courts, so a large main court cannot multiply its footprint.
const COURT_CACHE_LIMIT := 64
const COURT_CACHE_CELL_LIMIT := 8192
const VIEW_CULL_MARGIN := 64.0 # Complete neighbor cells + all existing material marks.
var _court_geometry: Dictionary = {}
var _court_order: Array[int] = []
var _court_cache_cells := 0
var _court_geometry_builds := 0
var _court_geometry_hits := 0
var _visible_rect := Rect2()
var _compact_draw_bundle := false
var _cells: Array[Vector2i] = []
var _cell_set: Dictionary = {}
var _centers: Dictionary = {}
var _vertices: Dictionary = {}
var _projectile_size_cache: Dictionary = {}
var _cover_surface_regions: Dictionary = {}
# Exact polygon keys only: phase, owner, danger and lifetime never enter these
# bounded geometry caches. Keys are detached; returned scalar/vector arrays are
# recursively read-only (packed arrays are mutable reference values in GDScript).
const BOUNDARY_CACHE_LIMIT := 512
var _edge_segments_cache: Dictionary = {}
var _edge_segments_order: Array[PackedVector2Array] = []
var _edge_segments_cursor := 0
var _outline_geometry_cache: Dictionary = {}
var _outline_geometry_order: Array[PackedVector2Array] = []
var _outline_geometry_cursor := 0
# Exact geometry plus this draw's exposed-edge mask; never cached authority.
const OUTLINE_BATCH_LIMIT := 512
var _outline_batches: Dictionary = {}
var _outline_batch_order: Array[Array] = []
var _outline_batch_cursor := 0
var _outline_meshes: Dictionary = {}
var _outline_mesh_uploads := 0
var _outline_mesh_hits := 0
var _outline_mesh_fallbacks := 0
var water_material := WaterMaterial.new()
var retro_marks := RetroMarks.new()
var material_surface := MaterialSurface.new()
var _surface_palettes: Dictionary = {}
var _surface_palette_compatible := false
const REGION_LAYOUT_LIMIT := 512
const REGION_GEOMETRY_LIMIT := 512
const CELL_BOUNDARY_DUPLICATE_LIMIT := 64
const BOUNDARY_TOPOLOGY_LIMIT := 8
const BOUNDARY_TOPOLOGY_ROWS := 512
var _region_layouts: Dictionary = {}
var _edge_prefixes: Dictionary = {}
var _boundary_topologies: Dictionary = {}
var _boundary_topology_order: Array = []
var _boundary_topology_hits := 0
var _boundary_topology_builds := 0
var _boundary_mask_counts: Dictionary = {}
var _boundary_masks: Dictionary = {}
var _boundary_mask_hits := 0
var _boundary_mask_builds := 0
var _fire_phase_marks: Dictionary = {}
var _pixel_region_polygons: Dictionary = {}
var _pixel_region_builds := 0
var _pixel_region_hits := 0
var _pixel_region_fallbacks := 0
var _pixel_region_rejections := 0
var _surface_glow := SurfaceGlowCache.new()
# Diagnostic comparison only: toggling this never changes region authority.
var water_motifs_enabled := true
var material_surfaces_enabled := true
var _magic_surface_glows := 0


func configure(shared_language: VisualLanguage) -> bool:
	_court_geometry.clear()
	_court_order.clear()
	_court_cache_cells = 0
	_court_geometry_builds = 0
	_court_geometry_hits = 0
	_cached_court_id = -1
	_cached_revision = -1
	_cells = []
	_cell_set = {}
	_centers = {}
	_vertices = {}
	_surface_palettes.clear()
	_surface_palette_compatible = false
	_region_layouts.clear()
	_edge_prefixes.clear()
	_boundary_topologies.clear()
	_boundary_topology_order.clear()
	_boundary_topology_hits = 0
	_boundary_topology_builds = 0
	_boundary_mask_counts = {}
	_boundary_masks = {}
	_boundary_mask_hits = 0
	_boundary_mask_builds = 0
	_fire_phase_marks.clear()
	_pixel_region_polygons.clear()
	_pixel_region_builds = 0
	_pixel_region_hits = 0
	_pixel_region_fallbacks = 0
	_pixel_region_rejections = 0
	_surface_glow = SurfaceGlowCache.new()
	_edge_segments_cache.clear()
	_edge_segments_order.clear()
	_edge_segments_cursor = 0
	_outline_geometry_cache.clear()
	_outline_geometry_order.clear()
	_outline_geometry_cursor = 0
	_outline_batches.clear()
	_outline_batch_order.clear()
	_outline_batch_cursor = 0
	_outline_meshes.clear()
	_outline_mesh_uploads = 0
	_outline_mesh_hits = 0
	_outline_mesh_fallbacks = 0
	if shared_language == null or shared_language.elements.is_empty() or shared_language.reaction_materials.is_empty():
		_language = null
		return false
	_language = shared_language
	# A failed candidate import retains the old marks and the canonical fill.
	water_material.configure()
	material_surface.configure()
	var native_language := VisualLanguage.new()
	_surface_palette_compatible = native_language.load_from_file() and native_language.elements == shared_language.elements and native_language.reaction_materials == shared_language.reaction_materials
	_prepare_surface_palettes()
	return true


# Additive entry point: existing generic/profiling draw_ground overrides retain
# their original signature. Only presentation is culled; authority is untouched.
func draw_ground_in_view(canvas: CanvasItem, court: RefCounted, tick: float, reduced: bool, draw_district_base: bool, visible_rect: Rect2) -> bool:
	if not visible_rect.has_area() or not visible_rect.position.is_finite() or not visible_rect.end.is_finite(): return false
	var previous := _visible_rect
	_visible_rect = visible_rect
	var result := draw_ground(canvas, court, tick, reduced, draw_district_base)
	_visible_rect = previous
	return result


func draw_ground(canvas: CanvasItem, court: RefCounted, tick: float, reduced: bool, draw_district_base: bool = true) -> bool:
	_cover_surface_regions.clear()
	_edge_prefixes.clear()
	_magic_surface_glows = 0
	if canvas == null or court == null or _language == null or not is_finite(tick) or not court.has_method("view"):
		return false
	if not _prepare_court(court, draw_district_base):
		return false
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# The normal campus already supplies its floor. After validated membership
	# is empty there is no material to prepare or submit; leave the standalone
	# diagnostic court's apron/base path intact. No tick/revision cache: a cast,
	# restore or direct coverage change is observed by _prepare_court each call.
	if _cells.is_empty() and not draw_district_base:
		return true
	var frame: Dictionary = _prepare_draw_bundle(court, tick)
	var views: Dictionary = frame.get("views", {})
	var regions: Dictionary = frame.get("regions", {})
	if regions.is_empty() and not views.is_empty() and _has_active_material(views):
		return false
	for material: String in ["fortify", "permafrost", "grounding_network", "crystal_prism", "crystal_lens"]:
		var active := {}
		for cell: Vector2i in regions.get(material, {}):
			var selected: Array[Dictionary] = []
			for region: Dictionary in regions[material][cell]:
				if String(region.phase) == "active": selected.append(region)
			if not selected.is_empty(): active[cell] = selected
		_cover_surface_regions[material] = active
	if draw_district_base:
		_draw_apron(canvas, reduced)
		_draw_stone(canvas, court, reduced)
	_draw_water(canvas, views, regions.get("water", {}), tick, reduced)
	_draw_fire(canvas, views, regions.get("fire", {}), tick, reduced)
	for material: String in INGREDIENT_MATERIALS:
		if material not in ["water", "fire"]:
			_draw_shared_material(canvas, regions.get(material, {}), material, tick, reduced)
	_draw_steam(canvas, views, regions.get("steam", {}), tick, reduced)
	_draw_mirror_product(canvas, regions.get("conflagration", {}), "conflagration", tick, reduced)
	for material: String in PRODUCT_MATERIALS:
		if material not in ["steam", "conflagration"]:
			_draw_shared_material(canvas, regions.get(material, {}), material, tick, reduced)
	if draw_district_base:
		_draw_outer_rim(canvas)
	return true


# Repaint only the visible physical cover after opaque terrain replacement.
# Reuses this frame's canonical prepared regions; never redraws other layers.
func draw_cover_surfaces(canvas: CanvasItem, polygons: Array[PackedVector2Array], tick: float, reduced: bool) -> void:
	var allowed := {}
	for polygon: PackedVector2Array in polygons:
		allowed[Vector2i((_polygon_centroid(polygon) * 1000.0).round())] = true
	for material: String in _cover_surface_regions:
		var selected := {}
		for cell: Vector2i in _cover_surface_regions[material]:
			if allowed.has(Vector2i((_centers[cell] * 1000.0).round())):
				selected[cell] = _cover_surface_regions[material][cell]
		_draw_shared_material(canvas, selected, material, tick, reduced)


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
		_draw_magic_cue_glow(canvas, cue, _cast_release.sample(cue, definition, reduced), palette, reduced)
		if _cast_release.draw(canvas, cue, definition, reduced):
			return true
		_draw_cue_cross(canvas, position, dark, base, bright, opacity, progress, reduced, false)
		return true
	if kind == "spray" or event_type == "spray_fired":
		return _draw_spray_cue(canvas, cue, definition, dark, base, bright, opacity, reduced)
	if semantic in ["impact", "pixel_impact", "projectile_hit", "spray_hit", "field_triggered", "projectile_bounced"]:
		_draw_magic_cue_glow(canvas, cue, _contact_punctuation.sample(cue, String(ELEMENT_IDS[element_wire]), reduced), palette, reduced)
		if _contact_punctuation.draw(canvas, cue, String(ELEMENT_IDS[element_wire]), reduced):
			return true
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
	var authored_size := projectile_full_size(family, shot.radius)
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
		canvas.draw_polygon(vertices, PackedColorArray([Color.WHITE]), uvs, texture)
	elif size > 0.0:
		_draw_projectile_fallback(canvas, position, angle, family, shot.element_wire_id, size, reduced)
	var glow_palette := _element_palette(shot.element_wire_id)
	MagicGlow.draw_radial(canvas, position, MagicGlow.projectile_radius(collision_radius_px(shot.radius), minf(size, target_size)), glow_palette[1], glow_palette[2], reduced)
	if projectile_has_motion(shot):
		# The atlas keeps its pixel octants; this inset facet follows true travel.
		# Read current strength immediately in both modes while remaining inside
		# the displayed core during its existing normal-mode shrink transition.
		_draw_projectile_nose_facet(canvas, position, travel, shot.radius, shot.element_wire_id, minf(size, target_size))
	_draw_projectile_contact_pixels(canvas, position, shot.radius, shot.element_wire_id, reduced)
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


func _prepare_court(court: RefCounted, include_empty: bool = true) -> bool:
	var cells_value: Variant = (court as HexChemistryWorld).topology_cells_view() if court.get_script() == HexChemistryWorldScript else court.get("cells")
	if not cells_value is Dictionary:
		return false
	if not include_empty and court.has_method("occupied_cells"):
		cells_value = court.call("occupied_cells")
	var origin_value: Variant = court.get("origin")
	var origin: Vector2i = origin_value if origin_value is Vector2i else COURT_ORIGIN
	# Keep whole selected cells and a generous neighbor margin. Never trim the
	# polygon or manufacture a visible outline where an offscreen neighbor ends.
	if _visible_rect.has_area():
		var visible := {}
		var bounds := _visible_rect.grow(VIEW_CULL_MARGIN)
		for key: Variant in cells_value:
			if key is Vector2i:
				var point := Vector2(HexGrid.center(key) + origin) / 1000.0
				if point.x >= bounds.position.x and point.x <= bounds.end.x and point.y >= bounds.position.y and point.y <= bounds.end.y:
					visible[key] = true
		cells_value = visible
	var revision := int(court.get("render_revision"))
	var court_id := int(court.get_instance_id())
	var cached: Dictionary = _court_geometry.get(court_id, {})
	if not cached.is_empty() and (cached.reference as WeakRef).get_ref() == court and int(cached.revision) == revision and cached.origin == origin:
		var membership: Dictionary = cached.membership
		var same: bool = cells_value.size() == membership.size()
		if same:
			for key: Variant in cells_value:
				if not membership.has(key): same = false; break
		if same:
			_cells = cached.cells
			_cell_set = membership
			_centers = cached.centers
			_vertices = cached.vertices
			_cached_court_id = court_id
			_cached_revision = revision
			_court_order.erase(court_id)
			_court_order.append(court_id)
			_court_geometry_hits += 1
			return true
	# Fresh containers: clearing a previous borrowed cache entry would corrupt
	# another resident court. Origin and direct membership mutations are checked.
	_cells = []
	_cell_set = {}
	_centers = {}
	_vertices = {}
	for key: Variant in cells_value:
		if key is Vector2i: _cells.append(key)
	_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for cell: Vector2i in _cells:
		_cell_set[cell] = true
		_centers[cell] = Vector2(HexGrid.center(cell) + origin) / 1000.0
		var polygon := PackedVector2Array()
		for fixed_vertex: Vector2i in HexGrid.vertices(cell):
			polygon.append(Vector2(fixed_vertex + origin) / 1000.0)
		_vertices[cell] = polygon
	_cached_court_id = court_id
	_cached_revision = revision
	_court_geometry_builds += 1
	_forget_court_geometry(court_id)
	if _cells.size() <= COURT_CACHE_CELL_LIMIT:
		while not _court_order.is_empty() and (_court_order.size() >= COURT_CACHE_LIMIT or _court_cache_cells + _cells.size() > COURT_CACHE_CELL_LIMIT):
			_forget_court_geometry(_court_order[0])
		_court_geometry[court_id] = {"reference": weakref(court), "revision": revision, "origin": origin,
			"cells": _cells, "membership": _cell_set, "centers": _centers, "vertices": _vertices}
		_court_order.append(court_id)
		_court_cache_cells += _cells.size()
	return true


func _forget_court_geometry(court_id: int) -> void:
	if _court_geometry.has(court_id):
		_court_cache_cells -= (_court_geometry[court_id].cells as Array).size()
		_court_geometry.erase(court_id)
	_court_order.erase(court_id)


func geometry_cache_stats() -> Dictionary:
	return {"courts": _court_geometry.size(), "cells": _court_cache_cells,
		"builds": _court_geometry_builds, "hits": _court_geometry_hits}


func _same_membership(cells: Dictionary) -> bool:
	for cell: Variant in cells:
		if not _cell_set.has(cell): return false
	return true


func _draw_stone(canvas: CanvasItem, court: RefCounted, reduced: bool) -> void:
	var cells: Dictionary = (court as HexChemistryWorld).topology_cells_view() if court.get_script() == HexChemistryWorldScript else court.get("cells")
	if _stone_floor.draw(canvas, _cells, _centers, _vertices, cells, reduced): return
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


# Builds the two read-only presentation products together for the exact base
# court. Generic courts, subclasses, and renderable malformed records retain
# the published call-based path below.
func _prepare_draw_bundle(court: RefCounted, tick: float) -> Dictionary:
	var previous := _compact_draw_bundle
	var floor_cells := _cells
	# The standalone Range still draws every eligible floor cell. Material work
	# follows only current paid coverage, intersected with the prepared view. The
	# known HexCourt compatibility class adds topology only, with no view override.
	# Arbitrary subclasses/generic contracts keep their complete existing queries.
	if court.get_script() == HexChemistryWorldScript or court.get_script() == HexCourtScript:
		var world: HexChemistryWorld = court as HexChemistryWorld
		var aggregate_coverage := true
		# Legacy/directly authored ground parts may have no aggregate coverage.
		# Preserve their complete prepared-view fallback instead of hiding them.
		# Ordinary paid records always carry a Dictionary aggregate, even empty.
		for cast_id: int in world.casts:
			if not world.casts[cast_id].get("coverage") is Dictionary:
				aggregate_coverage = false
				break
		if aggregate_coverage:
			var material_cells: Array[Vector2i] = []
			for cell: Vector2i in world.occupied_cells():
				if _cell_set.has(cell): material_cells.append(cell)
			material_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
			_cells = material_cells
	_compact_draw_bundle = true
	var result := _prepare_frame_bundle(court, tick)
	_compact_draw_bundle = previous
	_cells = floor_cells
	return result


func _prepare_frame_bundle(court: RefCounted, tick: float) -> Dictionary:
	if court.get_script() != HexChemistryWorldScript and not (_compact_draw_bundle and court.get_script() == HexCourtScript):
		return _current_frame_bundle(court, tick)
	var materials: Array[String] = HexChemistryWorld.material_layers()
	if materials != MATERIALS:
		return _current_frame_bundle(court, tick)
	var world: HexChemistryWorld = court as HexChemistryWorld
	var views: Dictionary = {}
	var regions: Dictionary = {}
	if not _compact_draw_bundle:
		for material: String in materials: regions[material] = {}
	if _cells.is_empty():
		return {"views": views, "regions": regions}

	var zero_view: Dictionary = {"fire_phase": "none", "steam_heat": 1000}
	if not _compact_draw_bundle:
		for material: String in materials:
			zero_view[material + "_quantity"] = 0
			zero_view[material + "_present"] = false
	var preparation_failed := false
	for cell: Vector2i in _cells:
		if not world.has_cell(cell):
			views[cell] = {"fire_phase": "none", "steam_heat": 1000}
			continue
		var view: Dictionary = zero_view.duplicate()
		var record_value: Variant = world.cell_record_value(cell)
		if not record_value is Dictionary:
			return _current_frame_bundle(court, tick)
		var record: Dictionary = record_value
		# Sparse authority stores only present layers. Keep the stable output
		# schema, but do work for actual materials rather than44 empty slots.
		for key: Variant in record:
			if typeof(key) not in [TYPE_STRING, TYPE_STRING_NAME] or _material_wire(String(key)) < 0:
				continue
			var material: String = key
			var layer_value: Variant = record[material]
			if not layer_value is Dictionary:
				return _current_frame_bundle(court, tick)
			if (layer_value as Dictionary).is_empty():
				continue
			var raw: Array[Dictionary] = world.render_regions(cell, material, tick)
			if raw.is_empty():
				continue
			var quantity := 0
			for region: Dictionary in raw:
				quantity += int(region.quantity)
				if material == "fire":
					view.fire_phase = region.phase
				elif material == "steam":
					view.steam_heat = maxi(int(view.steam_heat), int(region.intensity))
			view[material + "_quantity"] = quantity
			view[material + "_present"] = true
			if preparation_failed:
				continue
			var prepared: Array[Dictionary] = []
			for value: Dictionary in raw:
				var expected_polygon: PackedVector2Array = _vertices.get(cell, PackedVector2Array())
				var prepared_region: Dictionary = _prepare_region(value, material, expected_polygon)
				if prepared_region.is_empty():
					preparation_failed = true
					break
				prepared.append(prepared_region)
			if not preparation_failed:
				prepared.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.footprint_id) < int(b.footprint_id))
				if not regions.has(material): regions[material] = {}
				(regions[material] as Dictionary)[cell] = prepared
		views[cell] = view
	return {"views": views, "regions": {} if preparation_failed else regions}


func _current_frame_bundle(court: RefCounted, tick: float) -> Dictionary:
	var views: Dictionary = {}
	for cell: Vector2i in _cells:
		var value: Variant = court.call("view", cell, tick)
		views[cell] = value if value is Dictionary else {}
	return {"views": views, "regions": _collect_render_regions(court, views, tick)}


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
	var expected_wire := _material_wire(material)
	var direction_value: Variant = source.get("direction", Vector2i(0, -1000))
	var source_ids_value: Variant = source.get("source_ids", [])
	if (
		expected_wire < 0
		or (source.has("recipe_wire_id") and int(source.recipe_wire_id) != expected_wire)
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
		# Preserve the existing art floor; only decorative light reads raw stock.
		"raw_intensity": int(source.intensity),
		"owner_key": source.get("owner_key", source.get("owner", source.get("owner_id", source.get("source_ids", [])))),
		"owner": int(source.get("owner", source.get("owner_id", 0))),
		"source_ids": (source_ids_value as Array).duplicate(),
		"quantity": maxi(0, int(source.get("quantity", 0))),
		"expiry_tick": int(source.get("expiry_tick", source.get("expires", 0))),
		"active_tick": int(source.get("active_tick", 0)),
		"decay_tick": int(source.get("decay_tick", 0)),
		"recipe_wire_id": int(source.get("recipe_wire_id", 0)),
		"direction": direction_value,
	}
	var polygon := _pixel_region_polygon(fixed_polygon, expected_polygon)
	if polygon.is_empty(): return {}
	result.polygon = polygon
	return result


func _pixel_region_polygon(fixed_polygon: PackedVector2Array, expected_polygon: PackedVector2Array) -> PackedVector2Array:
	# Geometry is immutable between real membership changes; authority is not.
	# Key both exact inputs, since a moved/reversed/edited expected cell must be
	# checked again. Return a detached array so diagnostic callers cannot poison
	# the retained geometry or another region's public result.
	var key: Array = [fixed_polygon, expected_polygon]
	if _pixel_region_polygons.has(key):
		_pixel_region_hits += 1
		return (_pixel_region_polygons[key] as PackedVector2Array).duplicate()
	var polygon := PackedVector2Array()
	for fixed_point: Vector2 in fixed_polygon:
		var point := fixed_point / 1000.0
		if not point.is_finite():
			_pixel_region_rejections += 1
			return PackedVector2Array()
		polygon.append(point)
	if expected_polygon.size() == 6 and not _same_polygon_vertices(polygon, expected_polygon):
		_pixel_region_rejections += 1
		return PackedVector2Array()
	if fixed_polygon.size() == 6 and expected_polygon.size() == 6 and _pixel_region_polygons.size() < REGION_GEOMETRY_LIMIT:
		key = [fixed_polygon.duplicate(), expected_polygon.duplicate()]
		key.make_read_only()
		_pixel_region_polygons[key] = polygon.duplicate()
		_pixel_region_builds += 1
	else:
		_pixel_region_fallbacks += 1
	return polygon


func region_geometry_cache_stats() -> Dictionary:
	return {"entries": _pixel_region_polygons.size(), "builds": _pixel_region_builds,
		"hits": _pixel_region_hits, "fallbacks": _pixel_region_fallbacks, "rejections": _pixel_region_rejections}


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
	var surface_styles: Dictionary = {}
	for cell: Vector2i in regions_by_cell:
		for region: Dictionary in regions_by_cell[cell]:
			var active: bool = region.phase == "active"
			var decaying: bool = region.phase == "decaying"
			var intensity := clampf(float(region.intensity) / 1000.0, 0.1, 1.5)
			var opacity := ((0.19 if reduced else 0.25) + 0.06 * intensity) * (0.45 if decaying else 1.0)
			_draw_retained_region_fill(canvas, region.polygon, Color(base, opacity))
			var phase_key := String(region.phase)
			if not surface_styles.has(phase_key):
				surface_styles[phase_key] = {"dark": dark, "base": base, "bright": bright, "phase": phase_key}
			var surface_style: Dictionary = surface_styles[phase_key]
			var painted := _draw_material_surface(canvas, material, region, surface_style, tick, reduced)
			_draw_region_outline(canvas, region, counts, Color(bright if active else dark, 0.80 if active else 0.50), 2.0)
			var layout := _region_layout(region.polygon)
			var center: Vector2 = layout.center
			var radius: float = float(layout.clearance) - 3.0
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
				if not painted or not active:
					_draw_fire_region_mark(canvas, region.polygon, phase, dark, base, bright, _language.reaction_color(material, "danger"), tick, int(region.footprint_id), reduced)
				# A restrained three-point crown distinguishes the mirror product
				# from one ordinary Fire ingredient without obscuring its footprint.
				if active:
					for offset: float in [-0.45, 0.45]:
						var anchor := center + Vector2(radius * offset, radius * 0.12)
						canvas.draw_line(anchor, anchor + Vector2(0, -radius * 0.35), Color(bright, 0.78), 2.0)


func _draw_retained_region_fill(canvas: CanvasItem, polygon: PackedVector2Array, color: Color) -> void:
	# The same exact polygon/triangulation as the clipped flame stamp, with no
	# texture and the original float color. Every region keeps its painter order.
	var mesh := retro_marks._region_mesh(polygon)
	if mesh != null:
		RenderingServer.canvas_item_add_mesh(canvas.get_canvas_item(), mesh.get_rid(), Transform2D.IDENTITY, color)
	else:
		canvas.draw_colored_polygon(polygon, color)


func _region_layout(polygon: PackedVector2Array) -> Dictionary:
	if _region_layouts.has(polygon): return _region_layouts[polygon]
	var center := _polygon_centroid(polygon)
	var result := {"center": center, "clearance": _polygon_clearance(center, polygon)}
	# Cache geometry only. Values are detached, immutable and never contain phase,
	# stock, owner, animation time or palette. Excess/diagnostic inputs stay exact.
	result.make_read_only()
	if _region_layouts.size() < REGION_LAYOUT_LIMIT and polygon.size() == 6 and _finite_boundary(polygon):
		_region_layouts[polygon.duplicate()] = result
	return result


func _draw_water(canvas: CanvasItem, _views: Dictionary, regions_by_cell: Dictionary, tick: float, reduced: bool) -> void:
	var edge_counts := _region_edge_counts(regions_by_cell)
	for cell: Vector2i in regions_by_cell:
		for region: Dictionary in regions_by_cell[cell]:
			var style := _water_region_style(region, reduced)
			_draw_retained_region_fill(canvas, region.polygon, Color(style.base, style.fill_opacity))
			var painted := water_motifs_enabled and _draw_material_surface(canvas, "water", region, style, tick, reduced)
			_draw_region_outline(canvas, region, edge_counts, Color(style.edge, style.edge_opacity), style.edge_width)
			var seed := _cell_seed(cell, int(region.footprint_id) * 401)
			if not painted and (not water_motifs_enabled or not _surface_palette_matches("water", style) or not water_material.draw_region(canvas, region.polygon, style.phase, tick, seed, reduced)):
				_draw_water_region_mark(canvas, region.polygon, style.bright, style.phase, tick, seed, reduced)


func _draw_fire(canvas: CanvasItem, _views: Dictionary, regions_by_cell: Dictionary, tick: float, reduced: bool) -> void:
	var edge_counts := _region_edge_counts(regions_by_cell)
	for cell: Vector2i in regions_by_cell:
		for region: Dictionary in regions_by_cell[cell]:
			var style := _fire_region_style(region, reduced)
			_draw_retained_region_fill(canvas, region.polygon, Color(style.base, style.fill_opacity))
			var painted := _draw_material_surface(canvas, "fire", region, style, tick, reduced)
			_draw_region_outline(canvas, region, edge_counts, Color(style.edge, style.edge_opacity), style.edge_width)
			var seed := _cell_seed(cell, int(region.footprint_id) * 809)
			if not painted or String(region.phase) != "active":
				_draw_fire_region_mark(canvas, region.polygon, style.phase, style.dark, style.base, style.bright, style.danger_color, tick, seed, reduced)


func _draw_steam(canvas: CanvasItem, views: Dictionary, regions_by_cell: Dictionary, tick: float, reduced: bool) -> void:
	var edge_counts := _region_edge_counts(regions_by_cell)
	for cell: Vector2i in regions_by_cell:
		var heat := int((views.get(cell, {}) as Dictionary).get("steam_heat", 1000))
		for region: Dictionary in regions_by_cell[cell]:
			var style := _steam_region_style(region, heat, reduced)
			_draw_retained_region_fill(canvas, region.polygon, Color(style.base, style.fill_opacity))
			var painted := _draw_material_surface(canvas, "steam", region, style, tick, reduced)
			_draw_region_outline(canvas, region, edge_counts, Color(style.dark, style.edge_opacity), style.edge_width)
			if bool(style.danger):
				_draw_region_outline(canvas, region, edge_counts, Color(style.danger_color, style.danger_opacity), 1.0)
			var seed := _cell_seed(cell, int(region.footprint_id) * 1201 + heat)
			_draw_steam_region_mark(canvas, region.polygon, style.dark, style.bright, style.danger_color, style.palette_phase, tick, seed, reduced, bool(style.danger), String(region.phase), painted)


func _draw_shared_material(canvas: CanvasItem, regions_by_cell: Dictionary, material: String, tick: float, reduced: bool) -> void:
	if regions_by_cell.is_empty():
		return
	var edge_counts := _region_edge_counts(regions_by_cell)
	var styles: Dictionary = {} # Call-local: never survives a phase/palette update.
	for cell: Vector2i in regions_by_cell:
		for region: Dictionary in regions_by_cell[cell]:
			var style := _shared_style_for_draw(styles, material, region, reduced)
			if style.is_empty():
				continue
			var warning := backdraft_warning(region, tick)
			if warning:
				style = style.duplicate()
				style["backdraft_warning"] = true
				style.fill_opacity = 0.06
				style.bright = _language.element_color("fire", "bright")
				style.edge = style.bright
				style.edge_opacity = 1.0
				style.edge_width = 3.0
			_draw_retained_region_fill(canvas, region.polygon, Color(style.base, style.fill_opacity))
			var painted := false if warning else _draw_material_surface(canvas, material, region, style, tick, reduced)
			_draw_region_outline(canvas, region, edge_counts, Color(style.edge, style.edge_opacity), style.edge_width)
			var seed := _cell_seed(cell, int(region.footprint_id) * 1597 + int(style.wire_id))
			_draw_shared_material_mark(canvas, region, style, tick, seed, reduced, painted)


static func backdraft_warning(region: Dictionary, tick: float) -> bool:
	var decay_tick := int(region.get("decay_tick", 0))
	return int(region.get("recipe_wire_id", 0)) == 315 and String(region.get("phase", "")) == "active" \
		and bool(region.get("danger", false)) and decay_tick > 0 and tick >= decay_tick - 72 and tick < decay_tick


func _prepare_surface_palettes() -> void:
	# The asset bank contains canonical RGB pixels. A later public palette edit
	# must immediately use the old freshly colored marks, never stale artwork or
	# a per-draw image rebuild. These are compatibility guards, not cached styles.
	for material: String in MATERIALS:
		for phase: String in ["forming", "ignition", "active", "decaying", "cooling"]:
			var region := {"phase": phase, "danger": false, "intensity": 1000}
			var style: Dictionary
			if material == "water": style = _water_region_style(region, false)
			elif material == "fire": style = _fire_region_style(region, false)
			elif material == "conflagration":
				style = {"phase": phase, "dark": _language.reaction_color(material, "dark"), "base": _language.reaction_color(material, "base"), "bright": _language.reaction_color(material, "bright")}
			elif material == "steam":
				for heat: int in [500, 1000, 1500]:
					style = _steam_region_style(region, heat, false)
					_surface_palettes[_surface_palette_key(material, style)] = [style.dark, style.base, style.bright]
				continue
			else: style = _shared_material_style(material, region, false)
			_surface_palettes[_surface_palette_key(material, style)] = [style.dark, style.base, style.bright]


static func _surface_palette_key(material: String, style: Dictionary) -> String:
	return material + "/" + String(style.phase) + "/" + String(style.get("palette_phase", ""))


func _surface_palette_matches(material: String, style: Dictionary) -> bool:
	if not _surface_palette_compatible: return false
	var expected: Array = _surface_palettes.get(_surface_palette_key(material, style), [])
	return expected.size() == 3 and expected[0] == style.dark and expected[1] == style.base and expected[2] == style.bright


func _draw_material_surface(canvas: CanvasItem, material: String, region: Dictionary, style: Dictionary, tick: float, reduced: bool) -> bool:
	if not material_surfaces_enabled or not _surface_palette_matches(material, style):
		return false
	# These two categorical silhouettes carry the field's vapor/flame identity
	# at gameplay zoom. Select their original mark instead of layering textures.
	if material in ["steam", "conflagration"]:
		return false
	# A tiny phase mask may sample only transparent pixels on a world grid.
	# Keep the guaranteed centered warning/terminal mark for pressure effects;
	# their active field alone replaces the emblem with native material pixels.
	if String(style.get("visual_material", material)) in COMBAT_PHASE_MATERIALS and String(region.phase) != "active":
		return false
	var wire := int(ELEMENT_WIRES.get(material, 0))
	if wire == 0:
		wire = _material_wire(material)
		if wire <= 0: return false
	var polygon: PackedVector2Array = region.polygon
	var phase := String(region.phase)
	var opacity := (0.82 if not reduced else 0.64) * _intensity_ratio(region)
	var tint := Color.WHITE
	if phase in ["forming", "ignition"]: opacity *= 0.70
	elif phase in ["decaying", "cooling"]: opacity *= 0.46
	if material == "steam" and String(style.get("palette_phase", "active")) in ["hot", "cool"]:
		tint = style.base # Heat remains a fresh palette input, not a stored phase.
	var painted := material_surface.draw_region(canvas, wire, polygon, phase, tick, reduced, opacity, tint)
	if painted:
		var glow_opacity := _take_magic_surface_glow_opacity(region, reduced)
		if glow_opacity > 0.0:
			_surface_glow.draw_surface(canvas, polygon, style.base, style.bright, glow_opacity)
	return painted


func _take_magic_surface_glow_opacity(region: Dictionary, reduced: bool) -> float:
	if _magic_surface_glows >= Quality.surface_glow_limit(MagicGlow.SURFACE_LIMIT):
		return 0.0
	var intensity := int(region.get("raw_intensity", region.get("intensity", 0)))
	var opacity := MagicGlow.surface_opacity(String(region.get("phase", "")), intensity, reduced)
	# Reserve only admitted decoration. Real zero stock must neither brighten
	# through the legacy art floor nor deny another occupied cell its light.
	if opacity > 0.0:
		_magic_surface_glows += 1
	return opacity


func _shared_style_for_draw(styles: Dictionary, material: String, region: Dictionary, reduced: bool) -> Dictionary:
	# These are exactly the dynamic inputs read by _shared_material_style. Owner,
	# direction and footprint affect borders/marks separately and are not memoized.
	# Clamp identically, never quantize: close intensities still yield exact colors.
	var key: Array = [material, String(region.get("phase", "active")), bool(region.get("danger", false)), _intensity_ratio(region), reduced]
	if styles.has(key): return styles[key]
	var style := _shared_material_style(material, region, reduced)
	style.make_read_only() # Scalars, strings and Color values only.
	if not style.is_empty() and styles.size() < DRAW_STYLE_LIMIT:
		key.make_read_only()
		styles[key] = style
	return style


func _material_descriptor(material: String) -> Dictionary:
	if material in INGREDIENT_MATERIALS:
		return {
			"material": material, "wire_id": 0, "ingredient": true,
			"first": material, "second": material,
			"shape": _language.element_shape(material),
			"cadence": _language.element_cadence(material),
			"atmospheric": ATMOSPHERIC_MATERIALS.has(material),
		}
	var wire := _material_wire(material)
	if wire <= 0:
		return {}
	var definition := RecipePolicy.runtime_definition(wire)
	var archive_wire := int(definition.get("archive_recipe_wire", 0))
	if archive_wire < 301 or archive_wire > 336:
		return {}
	var archived: Dictionary = ArchiveContract.REACTIONS[archive_wire - 301]
	var first := String(archived.elements[0])
	var second := String(archived.elements[1])
	return {
		"material": material, "wire_id": wire, "ingredient": false,
		"first": first, "second": second, "shape": String(archived.shape),
		"visual_material": String(definition.get("visual_material", material)),
		"cadence": "%s+%s" % [_language.element_cadence(first), _language.element_cadence(second)],
		"atmospheric": ATMOSPHERIC_MATERIALS.has(String(definition.get("visual_material", material))),
	}


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
	var visual_material := String(descriptor.get("visual_material", material))
	if visual_material in ["magma", "firestorm"]:
		dark = _language.element_phase_color("fire", phase, "dark")
		base = _language.element_phase_color("fire", phase, "base")
		bright = _language.element_phase_color("fire", phase, "bright")
	elif visual_material in ["mud", "dustfront"]:
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
	# The revised pressure fields need a phase cue that survives pale palettes
	# and reduced effects. Reuse the existing strokes: small dark preparation,
	# full bright active mark, tiny dim embers in decay. No extra draw calls,
	# particles, geometry queries or authoritative state are introduced.
	var combat_phase := visual_material in COMBAT_PHASE_MATERIALS
	var fading := phase in ["decaying", "cooling"]
	var preparing := phase in ["forming", "ignition"]
	var mark_scale := 1.0
	var edge_opacity := 0.88 if danger else 0.72
	if combat_phase and (preparing or fading):
		# Light's authored dark tint is sand-colored: preserve its colored fill
		# but anchor the warning ink against the beige Wellspring floor.
		if preparing:
			dark = Color("202737")
		bright = dark.lerp(base, 0.18 if preparing else 0.12)
		mark_scale = 0.72 if preparing else 0.40
		if fading:
			fill_opacity *= 0.30
			edge_opacity = 0.24
	return {
		"material": material, "visual_material": visual_material, "wire_id": int(descriptor.wire_id), "shape": String(descriptor.shape), "cadence": String(descriptor.cadence),
		"phase": phase, "danger": danger, "atmospheric": atmospheric,
		"dark": dark, "base": base, "bright": bright,
		"edge": bright if danger else dark,
		"fill_opacity": fill_opacity, "edge_opacity": edge_opacity, "mark_scale": mark_scale,
		"edge_width": 2.5 if danger else 2.0, "motion": not reduced, "mark_count": 1,
	}


func _draw_shared_material_mark(canvas: CanvasItem, region: Dictionary, style: Dictionary, tick: float, seed: int, reduced: bool, surface_painted: bool = false) -> void:
	var shape := String(style.shape)
	var material := String(style.get("visual_material", style.material))
	var retain_cover := String(region.phase) == "active" and material in ["permafrost", "grounding_network", "crystal_prism", "crystal_lens"]
	var retain_pillar := int(style.wire_id) == 301 and String(region.phase) == "active"
	# A successfully painted surface already replaces these exact old no-op
	# branches. Skip their polygon centroid/clearance; essential cues still run.
	if surface_painted and not bool(style.get("backdraft_warning", false)) and not retain_cover and not retain_pillar:
		if material in COMBAT_PHASE_MATERIALS or material in ["earth", "wind", "mud", "magma", "vortex", "ice", "charge", "light", "dark"]:
			return
		if material not in ["firestorm", "dustfront", "mistcurrent"] and shape not in ["corridor", "flow", "water_path", "growing_strip", "pulse_lane", "bands", "frost_path", "reveal_line"]:
			return
	var polygon: PackedVector2Array = region.polygon
	var layout := _region_layout(polygon)
	var center: Vector2 = layout.center
	var radius: float = float(layout.clearance) - 3.0
	if radius < 4.0:
		return
	radius *= float(style.get("mark_scale", 1.0))
	if bool(style.get("backdraft_warning", false)):
		# One stable impending-burst mark replaces the veil motif in both modes.
		canvas.draw_line(center + Vector2(0, -radius * 0.55), center + Vector2(0, radius * 0.18), Color(style.bright), 3.0)
		canvas.draw_rect(Rect2(center + Vector2(-1.5, radius * 0.40), Vector2(3, 3)), Color(style.bright))
		return
	# The native surface replaces the emblem, not essential physical-cover or
	# directional information. Keep exactly the previously reached cue branches.
	if surface_painted and not retain_cover and retain_pillar:
		_draw_earth_pillar(canvas, polygon, style.dark, style.base, style.bright, radius)
		return
	if material in COMBAT_PHASE_MATERIALS:
		# One bounded retro stamp replaces several thin line segments. It follows
		# the existing harmless-warning/active/decay scale and stays clipped inside
		# the authoritative cell; the unchanged fill/outline communicates reach.
		var mark_polygon := PackedVector2Array()
		var scale := float(style.get("mark_scale", 1.0))
		for point: Vector2 in polygon: mark_polygon.append(center + (point - center) * scale)
		var mark_base: Color = style.base if String(region.phase) == "active" else style.bright
		if retro_marks.draw_region(canvas, material, mark_polygon, style.dark, mark_base, style.bright, tick, seed,
			reduced or String(region.phase) != "active", 0.98 if bool(style.danger) else 0.72):
			return
	if material == "earth":
		# Loose, harmless ingredient stock must not imply an active solid pillar.
		if retro_marks.draw_region(canvas, "earth", polygon, style.dark, style.base, style.bright, tick, seed, true):
			return
		for offset: Vector2 in [Vector2(-0.30, 0.12), Vector2(0.22, -0.20), Vector2(0.31, 0.30)]:
			var pebble := center + offset * radius
			canvas.draw_rect(Rect2(pebble - Vector2(3, 2), Vector2(6, 4)), Color(style.dark, 0.82))
			canvas.draw_line(pebble - Vector2(2, 2), pebble + Vector2(2, -2), Color(style.bright, 0.88), 1.0)
		return
	if int(style.wire_id) == 301 and String(region.get("phase", "")) == "active":
		_draw_earth_pillar(canvas, polygon, style.dark, style.base, style.bright, radius)
		return
	# Compact material stamps replace smooth glyphs for the most common cells.
	# Cover, directional lanes and warning/decay boundaries retain their specific
	# grammar. The exact cell fill/border continues to define the real footprint.
	if material in ["wind", "mud", "magma", "vortex", "ice", "charge", "light", "dark"]:
		if retro_marks.draw_region(canvas, material, polygon, style.dark, style.base, style.bright, tick, seed, reduced, 0.94 if String(style.phase) == "active" else 0.72):
			return
	var motion := 0.0 if reduced else sin((tick + float(seed % 71)) * _cadence_rate(String(style.cadence))) * minf(2.0, radius * 0.08)
	var direction := Vector2(region.get("direction", Vector2i(0, -1000))).normalized()
	if direction.is_zero_approx():
		direction = Vector2.UP
	var side := Vector2(-direction.y, direction.x)
	if material == "firestorm":
		if not surface_painted or String(region.phase) != "active":
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
	var phase_opacity := 0.70 if phase == "forming" else 0.56 if phase in ["decaying", "cooling"] else 1.0
	var base := _language.reaction_phase_color("steam", palette_phase, "base")
	var bright := _language.reaction_phase_color("steam", palette_phase, "bright")
	return {
		"phase": phase, "palette_phase": palette_phase, "danger": danger,
		"dark": _language.reaction_phase_color("steam", palette_phase, "dark"),
		"base": base.lerp(bright, 0.32),
		"bright": bright,
		"danger_color": _language.reaction_phase_color("steam", palette_phase, "danger"),
		"fill_opacity": (0.34 + 0.08 * intensity) * phase_opacity,
		"edge_opacity": 0.84, "edge_width": 2.0,
		"danger_opacity": 0.92,
		"motion": not reduced, "mark_count": 2,
	}


func _region_edge_counts(regions_by_cell: Dictionary) -> Dictionary:
	# Keep only exact presentation topology. Fresh prefixes still read current
	# owner, danger, phase and the material's lifetime rules on every call. This
	# avoids six string joins/count lookups per unchanged region per draw without
	# retaining any simulation view or deciding whether a region is alive.
	_boundary_mask_counts = {}
	_boundary_masks = {}
	var topology: Array = []
	var cacheable := true
	for cell: Vector2i in regions_by_cell:
		# Overlapping compatible records in one cell are one side of a boundary,
		# not neighboring coverage. Keep each record's draw/lifetime independent.
		var cell_regions: Dictionary = {}
		for region: Dictionary in regions_by_cell[cell]:
			var fixed_polygon: PackedVector2Array = region.fixed_polygon
			var prefix := _region_edge_prefix(region)
			# Same-cell compatible overlaps already contribute one side per edge.
			# Skip their repeated six concatenations without changing neighboring
			# cell counts, insertion order, fresh dynamic prefixes or generic input.
			var identity: Array = [prefix, fixed_polygon]
			if cell_regions.has(identity): continue
			if fixed_polygon.size() == 6 and cell_regions.size() < CELL_BOUNDARY_DUPLICATE_LIMIT:
				cell_regions[identity] = true
			topology.append([cell, prefix, fixed_polygon])
			cacheable = cacheable and fixed_polygon.size() == 6 and topology.size() <= BOUNDARY_TOPOLOGY_ROWS
	# One compound-key lookup: has() followed by [] hashed every row twice.
	var retained: Variant = _boundary_topologies.get(topology) if cacheable else null
	if retained is Dictionary:
		_boundary_topology_hits += 1
		_boundary_mask_counts = retained.counts
		_boundary_masks = retained.masks
		return _boundary_mask_counts
	var counts: Dictionary = {}
	var cell_edges: Dictionary = {}
	var previous_cell := Vector2i(2147483647, 2147483647)
	for row: Array in topology:
		if row[0] != previous_cell:
			cell_edges.clear()
			previous_cell = row[0]
		for segment: String in _boundary_segments(row[2]):
			var key: String = row[1] + segment
			if cell_edges.has(key): continue
			cell_edges[key] = true
			counts[key] = int(counts.get(key, 0)) + 1
	if cacheable and not topology.is_empty():
		for row: Array in topology:
			if not _finite_boundary(row[2]): return counts
			row[2] = (row[2] as PackedVector2Array).duplicate()
			row.make_read_only()
		topology.make_read_only()
		counts.make_read_only()
		var masks: Dictionary = {}
		for row: Array in topology:
			var prefix: String = row[1]
			var polygons: Dictionary = masks.get(prefix, {})
			if not polygons.has(row[2]):
				polygons[row[2]] = _count_exposed_edges(prefix, row[2], counts, 6)
				_boundary_mask_builds += 1
			masks[prefix] = polygons
		for polygons: Dictionary in masks.values(): polygons.make_read_only()
		masks.make_read_only()
		var entry := {"counts": counts, "masks": masks}
		entry.make_read_only()
		if _boundary_topology_order.size() == BOUNDARY_TOPOLOGY_LIMIT:
			_boundary_topologies.erase(_boundary_topology_order.pop_front())
		_boundary_topology_order.append(topology)
		_boundary_topologies[topology] = entry
		_boundary_mask_counts = counts
		_boundary_masks = masks
		_boundary_topology_builds += 1
	return counts


func _boundary_segments(fixed_polygon: PackedVector2Array) -> Array[String]:
	if _edge_segments_cache.has(fixed_polygon):
		return _edge_segments_cache[fixed_polygon]
	var result: Array[String] = []
	for index: int in fixed_polygon.size():
		var first := fixed_polygon[index]
		var second := fixed_polygon[(index + 1) % fixed_polygon.size()]
		var a := "%d,%d" % [roundi(first.x), roundi(first.y)]
		var b := "%d,%d" % [roundi(second.x), roundi(second.y)]
		result.append(a + ":" + b if a < b else b + ":" + a)
	result.make_read_only()
	# Non-hex diagnostic callers still get exact results without growing storage.
	if fixed_polygon.size() == 6 and _finite_boundary(fixed_polygon):
		var key := fixed_polygon.duplicate()
		if _edge_segments_order.size() < BOUNDARY_CACHE_LIMIT:
			_edge_segments_order.append(key)
		else:
			_edge_segments_cache.erase(_edge_segments_order[_edge_segments_cursor])
			_edge_segments_order[_edge_segments_cursor] = key
			_edge_segments_cursor = (_edge_segments_cursor + 1) % BOUNDARY_CACHE_LIMIT
		_edge_segments_cache[key] = result
	return result


func _boundary_triangles(polygon: PackedVector2Array, width: float) -> Array:
	# Only the three production stroke widths can occupy a cached polygon row;
	# unusual/invalid diagnostic inputs use the unchanged geometry calculation.
	var cacheable := polygon.size() == 6 and width in [1.0, 2.0, 2.5] and _finite_boundary(polygon)
	if cacheable and _outline_geometry_cache.has(polygon) and (_outline_geometry_cache[polygon] as Dictionary).has(width):
		return _outline_geometry_cache[polygon][width]
	var result: Array = []
	var center := _polygon_centroid(polygon)
	for index: int in polygon.size():
		var triangles: Array = []
		for packed: PackedVector2Array in _inward_edge_triangles(polygon, index, width, center):
			var points: Array[Vector2] = []
			for point: Vector2 in packed: points.append(point)
			points.make_read_only()
			triangles.append(points)
		triangles.make_read_only()
		result.append(triangles)
	result.make_read_only()
	if cacheable:
		if not _outline_geometry_cache.has(polygon):
			var key := polygon.duplicate()
			if _outline_geometry_order.size() < BOUNDARY_CACHE_LIMIT:
				_outline_geometry_order.append(key)
			else:
				_outline_geometry_cache.erase(_outline_geometry_order[_outline_geometry_cursor])
				_outline_geometry_order[_outline_geometry_cursor] = key
				_outline_geometry_cursor = (_outline_geometry_cursor + 1) % BOUNDARY_CACHE_LIMIT
			_outline_geometry_cache[key] = {}
		_outline_geometry_cache[polygon][width] = result
	return result


static func _finite_boundary(polygon: PackedVector2Array) -> bool:
	for point: Vector2 in polygon:
		if not point.is_finite(): return false
	return true


func _region_edge_key(region: Dictionary, first: Vector2, second: Vector2, prefix: String = "") -> String:
	var a := "%d,%d" % [roundi(first.x), roundi(first.y)]
	var b := "%d,%d" % [roundi(second.x), roundi(second.y)]
	var segment := a + ":" + b if a < b else b + ":" + a
	return (_region_edge_prefix(region) if prefix.is_empty() else prefix) + segment


func _region_edge_prefix(region: Dictionary) -> String:
	# Every dynamic boundary input is read now. The ordinary ground draw clears
	# this bounded cache each pass; direct callers also key all current values.
	var owner_value: Variant = region.get("owner_key", null)
	# Ordinary world regions carry integer owners. Use that exact immutable value
	# for lookup and serialize only on a miss. Generic arrays/dictionaries still
	# serialize before lookup, preserving order and observing in-place mutations.
	var scalar_owner := typeof(owner_value) == TYPE_INT
	var owner_cache_key: Variant = owner_value if scalar_owner else JSON.stringify(owner_value)
	var material := String(region.material)
	var legacy := material in LEGACY_HEX_MATERIALS
	var key: Array = [material, String(region.phase), bool(region.danger), owner_cache_key,
		int(region.footprint_id) if legacy else 0, int(region.intensity) if legacy else 0,
		int(region.get("expiry_tick", 0)) if legacy else 0, int(region.get("decay_tick", 0)) if material == "cinderveil" else 0]
	var retained_prefix: String = _edge_prefixes.get(key, "")
	if not retained_prefix.is_empty(): return retained_prefix
	var owner_key := JSON.stringify(owner_value) if scalar_owner else String(owner_cache_key)
	var result: String
	if String(region.material) == "cinderveil":
		# Adjacent Backdrafts with different real fuse endpoints must keep their
		# boundary when one is warning and its neighbour still conceals.
		result = "%s/%s/%s/%s/%d/" % [String(region.material), String(region.phase), str(bool(region.danger)), owner_key, int(region.get("decay_tick", 0))]
	elif String(region.material) not in LEGACY_HEX_MATERIALS:
		# Unified fields cohere across adjacent records from the same owner and
		# phase. Record lifetime and intensity alter the fill without inventing an
		# internal wall; ownership, phase and danger remain visible boundaries.
		result = "%s/%s/%s/%s/" % [String(region.material), String(region.phase), str(bool(region.danger)), owner_key]
	else:
		result = "%s/%d/%s/%s/%d/%d/%s/" % [String(region.material), int(region.footprint_id), String(region.phase), str(bool(region.danger)), int(region.intensity), int(region.get("expiry_tick", 0)), owner_key]
	if _edge_prefixes.size() < REGION_LAYOUT_LIMIT:
		key.make_read_only()
		_edge_prefixes[key] = result
	return result


func _draw_region_outline(canvas: CanvasItem, region: Dictionary, edge_counts: Dictionary, color: Color, width: float) -> void:
	var polygon: PackedVector2Array = region.polygon
	var exposed := _region_exposed_edges(region, edge_counts)
	if exposed == 0: return
	var points := _outline_batch_points(polygon, width, exposed)
	if not points.is_empty(): _submit_outline(canvas, points, color)


func _region_exposed_edges(region: Dictionary, edge_counts: Dictionary) -> int:
	# Counts and masks are one immutable topology result. Fresh owner/phase/danger
	# prefixes and exact vertex order are still required for every region. Generic
	# callers passing their own count map always execute the original calculation.
	var prefix := _region_edge_prefix(region)
	var fixed_polygon: PackedVector2Array = region.fixed_polygon
	var vertex_count: int = (region.polygon as PackedVector2Array).size()
	if vertex_count == 6 and is_same(edge_counts, _boundary_mask_counts):
		var polygons: Variant = _boundary_masks.get(prefix)
		if polygons is Dictionary:
			var retained: int = polygons.get(fixed_polygon, -1)
			if retained >= 0:
				_boundary_mask_hits += 1
				return retained
	return _count_exposed_edges(prefix, fixed_polygon, edge_counts, vertex_count)


func _count_exposed_edges(prefix: String, fixed_polygon: PackedVector2Array, edge_counts: Dictionary, vertex_count: int) -> int:
	var segments := _boundary_segments(fixed_polygon)
	var exposed := 0
	for index: int in vertex_count:
		if int(edge_counts.get(prefix + segments[index], 0)) <= 1:
			exposed |= 1 << index
	return exposed


func _outline_batch_points(polygon: PackedVector2Array, width: float, exposed: int) -> PackedVector2Array:
	# The old triangles were consecutive commands with identical color/transform.
	# Flatten only that single region: no material, owner, cell or painter-order
	# sorting. Fresh edge counts still decide the mask after every phase/change.
	var key: Array = [polygon, width, exposed]
	var retained_points: Variant = _outline_batches.get(key)
	if retained_points is PackedVector2Array: return retained_points
	var points := PackedVector2Array()
	var geometry := _boundary_triangles(polygon, width)
	for index: int in polygon.size():
		if exposed & (1 << index) == 0: continue
		for triangle: Array in geometry[index]:
			for point: Vector2 in triangle: points.append(point)
	# 512 x at most36 native points (144 KiB) plus small bounded keys. Diagnostic
	# nonhex/invalid widths remain exact without growing resident storage.
	if polygon.size() == 6 and width in [1.0, 2.0, 2.5, 3.0] and exposed > 0 and exposed < 64 and _finite_boundary(polygon):
		key = [polygon.duplicate(), width, exposed]
		key.make_read_only()
		if _outline_batch_order.size() < OUTLINE_BATCH_LIMIT:
			_outline_batch_order.append(key)
		else:
			_outline_batches.erase(_outline_batch_order[_outline_batch_cursor])
			_outline_batch_order[_outline_batch_cursor] = key
			_outline_batch_cursor = (_outline_batch_cursor + 1) % OUTLINE_BATCH_LIMIT
		_outline_batches[key] = points
	return points


func _submit_outline(canvas: CanvasItem, points: PackedVector2Array, color: Color) -> void:
	var mesh := _resident_outline_mesh(points)
	if mesh != null:
		RenderingServer.canvas_item_add_mesh(canvas.get_canvas_item(), mesh.get_rid(), Transform2D.IDENTITY, color)
	else:
		# Overflow stays exact. Never evict an in-flight mesh/RID just because a
		# later region in this retained draw list needs a different edge mask.
		RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), PackedInt32Array(),
			points, PackedColorArray([color]), PackedVector2Array())
		_outline_mesh_fallbacks += 1


func _resident_outline_mesh(points: PackedVector2Array) -> ArrayMesh:
	if _outline_meshes.has(points):
		_outline_mesh_hits += 1
		return _outline_meshes[points]
	if _outline_meshes.size() >= OUTLINE_BATCH_LIMIT or points.is_empty() or points.size() > 36 or points.size() % 3 != 0 or not _finite_boundary(points):
		return null
	var vertices := PackedVector3Array()
	for point: Vector2 in points: vertices.append(Vector3(point.x, point.y, 0.0))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_outline_meshes[points.duplicate()] = mesh
	_outline_mesh_uploads += 1
	return mesh


func outline_cache_stats() -> Dictionary:
	return {"batches": _outline_batches.size(), "meshes": _outline_meshes.size(),
		"uploads": _outline_mesh_uploads, "hits": _outline_mesh_hits, "fallbacks": _outline_mesh_fallbacks,
		"topologies": _boundary_topologies.size(), "topology_hits": _boundary_topology_hits, "topology_builds": _boundary_topology_builds,
		"edge_mask_hits": _boundary_mask_hits, "edge_mask_builds": _boundary_mask_builds,
		"phase_marks": _fire_phase_marks.size()}


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
	var layout := _region_layout(polygon)
	var center: Vector2 = layout.center
	var radius: float = float(layout.clearance) - 2.5
	if radius < 3.5:
		return
	if phase == "ignition":
		var warning := _fire_phase_mark(polygon, phase, reduced, center, radius)
		canvas.draw_polyline(warning, Color(dark, 0.78), 4.0, false)
		canvas.draw_polyline(warning, Color(danger, 0.98), 2.0, false)
		return
	if phase == "cooling":
		var ember := _fire_phase_mark(polygon, phase, reduced, center, radius)
		canvas.draw_polyline(ember, Color(dark, 0.88), 3.0, false)
		canvas.draw_polyline(ember, Color(bright, 0.68), 1.0, false)
		return
	if retro_marks.draw_region(canvas, "fire", polygon, dark, base, bright, tick, seed, reduced):
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


func _fire_phase_mark(polygon: PackedVector2Array, phase: String, reduced: bool, center: Vector2, radius: float) -> PackedVector2Array:
	# Static warning/ember strokes have no tick, owner or palette dependency.
	# Include the exact derived geometry for diagnostic/subclass callers too.
	var key: Array = [polygon, phase, reduced, center, radius]
	if _fire_phase_marks.has(key): return (_fire_phase_marks[key] as PackedVector2Array).duplicate()
	var points := PackedVector2Array()
	if phase == "ignition":
		points = PackedVector2Array([
			(center + Vector2(-radius * 0.58, radius * 0.34)).round(),
			(center + Vector2(0.0, -radius * 0.54)).round(),
			(center + Vector2(radius * 0.58, radius * 0.34)).round(),
		])
	elif phase == "cooling":
		var ember_width := radius * (0.42 if reduced else 0.56)
		points = PackedVector2Array([
			(center + Vector2(-ember_width, radius * 0.22)).round(),
			(center + Vector2(-ember_width * 0.10, radius * 0.06)).round(),
			(center + Vector2(ember_width, radius * 0.24)).round(),
		])
	if not points.is_empty() and _fire_phase_marks.size() < REGION_LAYOUT_LIMIT and polygon.size() == 6 and _finite_boundary(polygon) and center.is_finite() and is_finite(radius):
		key[0] = polygon.duplicate()
		key.make_read_only()
		_fire_phase_marks[key] = points.duplicate()
	return points


func _draw_steam_region_mark(canvas: CanvasItem, polygon: PackedVector2Array, dark: Color, bright: Color, danger: Color, phase: String, tick: float, seed: int, reduced: bool, harmful: bool, source_phase: String = "active", surface_painted: bool = false) -> void:
	var center := _polygon_centroid(polygon)
	var radius := _polygon_clearance(center, polygon) - 2.0
	if radius < 5.0:
		return
	# Pale, chunky vapor occupies the real cell instead of a tiny warm symbol.
	# Warm ground vents are a separate harm cue; they do not recolor the cloud
	# into Water or Fire, obscure actors, or imply smoke/line-of-sight mechanics.
	var vapor_opacity := 0.50 if source_phase in ["decaying", "cooling"] else 0.72 if source_phase == "forming" else 0.94
	var painted := surface_painted or retro_marks.draw_region(canvas, "steam", polygon, dark, bright.darkened(0.16), bright, tick, seed, reduced, vapor_opacity)
	for vent: PackedVector2Array in steam_vent_marks(polygon, harmful, source_phase):
		canvas.draw_polyline(vent, Color(dark, 0.90), STEAM_VENT_OUTLINE_WIDTH, false)
		canvas.draw_polyline(vent, Color(danger if harmful else bright, 0.98), STEAM_VENT_CORE_WIDTH, false)
	if painted:
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


# Source phase controls the terminal bracket in both full and reduced modes.
# Removal is naturally immediate: no occupied region means no call or after-image.
static func steam_vent_marks(polygon: PackedVector2Array, harmful: bool, source_phase: String) -> Array[PackedVector2Array]:
	var marks: Array[PackedVector2Array] = []
	if polygon.size() < 3:
		return marks
	var center := _polygon_centroid(polygon)
	var radius := _polygon_clearance(center, polygon) - STEAM_VENT_OUTLINE_WIDTH * 0.5
	if radius < 5.0:
		return marks
	if harmful:
		for side: float in [-1.0, 1.0]:
			# Broad angular vents remain readable on 24px cells at 75% zoom.
			# Their static shape carries danger even without color or motion;
			# keep the outlined strokes well inside the real occupied polygon.
			var anchor := center + Vector2(side * radius * 0.39, radius * 0.43)
			marks.append(PackedVector2Array([
				anchor + Vector2(-radius * 0.27, radius * 0.09),
				anchor + Vector2(0, -radius * 0.25),
				anchor + Vector2(radius * 0.27, radius * 0.09),
			]))
	if source_phase in ["decaying", "cooling"]:
		marks.append(PackedVector2Array([
			center + Vector2(-radius * 0.42, radius * 0.57),
			center + Vector2(-radius * 0.42, radius * 0.70),
			center + Vector2(radius * 0.42, radius * 0.70),
			center + Vector2(radius * 0.42, radius * 0.57),
		]))
	return marks


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


func _draw_projectile_fallback(canvas: CanvasItem, position: Vector2, angle: float, family: String, element_wire: int, size: float, _reduced: bool) -> void:
	var palette := _element_palette(element_wire if ELEMENT_IDS.has(element_wire) else 3)
	var dark: Color = palette[0]
	var base: Color = palette[1]
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


func _draw_projectile_nose_facet(canvas: CanvasItem, position: Vector2, travel: Vector2, radius_fixed: int, element_wire: int, core_size: float) -> void:
	if canvas == null or _language == null or not position.is_finite() or not ELEMENT_IDS.has(element_wire):
		return
	var element := String(ELEMENT_IDS[element_wire])
	ProjectileFacets.draw(canvas, position, travel, collision_radius_px(radius_fixed), core_size, element_wire, _language.element_color(element, "bright"))


static func projectile_has_motion(shot: ProjectileState) -> bool:
	# ProjectileMotion's stationary DOWN fallback is useful for the old body,
	# but must never manufacture a new directional cue.
	return shot != null and (shot.velocity_x != 0 or shot.velocity_y != 0 or shot.position_x != shot.previous_x or shot.position_y != shot.previous_y)


static func projectile_nose_facet(direction: Vector2, radius: float, core_size: float, highlight: bool = false) -> PackedVector2Array:
	if not direction.is_finite() or not is_finite(radius) or not is_finite(core_size) or radius <= 0.0 or core_size <= 0.0:
		return PackedVector2Array()
	var squared := direction.length_squared()
	if not is_finite(squared) or squared <= 0.0:
		return PackedVector2Array()
	# Keep a full pixel of raster clearance inside both the current visual
	# core and physical disk. The smaller centre facet cannot imply more reach.
	var extent := minf(radius, core_size * 0.35) - 1.0
	if extent < 2.0:
		return PackedVector2Array()
	var forward := direction / sqrt(squared)
	var side := Vector2(-forward.y, forward.x)
	var tip := extent * (0.78 if highlight else 1.0)
	var rear := extent * (0.40 if highlight else 0.15)
	var half_width := extent * (0.16 if highlight else 0.45)
	return PackedVector2Array([forward * tip, forward * rear + side * half_width, forward * rear - side * half_width])


func _draw_projectile_contact_pixels(canvas: CanvasItem, position: Vector2, radius_fixed: int, element_wire: int, reduced: bool) -> void:
	var radius := collision_radius_px(radius_fixed)
	if radius <= 0.0:
		return
	var palette := _element_palette(element_wire if ELEMENT_IDS.has(element_wire) else 3)
	# Static, inset pixel ticks disclose the fixed collision extent as strength
	# shrinks the core. Two-tone contrast survives both light and dark ground,
	# including at75% zoom. Always four marks/eight draws, no optional budget,
	# flashing, strength-scaled radius, enclosing ring or new attack geometry.
	for mark: Rect2 in projectile_contact_pixels(radius):
		canvas.draw_rect(Rect2(position + mark.position, mark.size), Color(palette[0], 0.82 if reduced else 0.90))
		canvas.draw_rect(Rect2(position + mark.position + Vector2.ONE, Vector2.ONE), Color(palette[2], 0.90 if reduced else 1.0))


static func projectile_contact_pixels(radius: float) -> Array[Rect2]:
	var result: Array[Rect2] = []
	if not is_finite(radius) or radius < 3.0: return result
	var extent := floorf(radius) - 2.0
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		result.append(Rect2(direction * extent - Vector2.ONE, Vector2(2, 2)))
	return result


static func collision_radius_px(radius_fixed: int) -> float:
	return maxf(0.0, float(radius_fixed) / 1000.0)


func _draw_spray_cue(canvas: CanvasItem, cue: Dictionary, definition: Dictionary, dark: Color, base: Color, bright: Color, opacity: float, reduced: bool) -> bool:
	# Admission prepares detached geometry once. Drawing never re-queries cover,
	# including when Reduced Effects changes during this short cue's lifetime.
	var geometry: Dictionary
	if cue.has("spray_geometry"):
		geometry = cue["spray_geometry"]
	else:
		geometry = _spray_cue_geometry(cue, definition)
	if geometry.is_empty():
		return false
	var start: Vector2 = geometry.start
	var endpoints: PackedVector2Array = geometry.endpoints
	for index: int in (SPRAY_CUE_REDUCED_RAYS if reduced else SPRAY_CUE_RAYS):
		var target := endpoints[index]
		if target == start:
			continue
		var shoulder := start.lerp(target, 0.30)
		var line_color := bright if index == 2 else base
		var line_opacity := opacity * (0.84 if index == 2 else 0.46)
		canvas.draw_polyline(PackedVector2Array([start, shoulder, target]), Color(line_color, line_opacity), 2.0 if index == 2 else 1.0, false)
	var brace: PackedVector2Array = geometry.brace
	if brace[0] != brace[1]:
		var origin := ProjectileFacets.spray_origin(geometry)
		if not origin.is_empty():
			MagicGlow.draw_radial(canvas, origin.position, MagicGlow.projectile_radius(origin.radius, origin.core_size), base, bright, reduced, opacity * opacity)
		if origin.is_empty() or not ProjectileFacets.draw(canvas, origin.position, origin.direction, origin.radius, origin.core_size, int(definition.get("element_wire_id", 0)), Color(bright, opacity)):
			canvas.draw_line(brace[0], brace[1], Color(dark, opacity * 0.72), 2.0)
	return true


static func prepare_spray_cue(cue: Dictionary, collision: CollisionWorld) -> Dictionary:
	var definition := CombatTuning.cast_definition(int(cue.get("source_wire_id", 0)))
	if collision == null or String(definition.get("shape", "")) != "spray":
		return {}
	var geometry := _spray_cue_geometry(cue, definition)
	if geometry.is_empty():
		return {}
	var start: Vector2 = geometry.start
	var end: Vector2 = geometry.end
	var coordinate_limit := float(HexGrid.MAX_ABS_QUERY_COORDINATE) / SimConfig.FIXED_SCALE
	if maxf(absf(start.x), absf(start.y)) > coordinate_limit or maxf(absf(end.x), absf(end.y)) > coordinate_limit \
		or start.distance_to(end) > float(definition.range) / SimConfig.FIXED_SCALE + 0.001:
		return {}
	var origin := Vector2i((start * SimConfig.FIXED_SCALE).round())
	var endpoints: PackedVector2Array = geometry.endpoints
	var nearest := INF
	var clipped := false
	for index: int in endpoints.size():
		var requested := endpoints[index]
		var offset := Vector2i((requested * SimConfig.FIXED_SCALE).round()) - origin
		var distance := SimCommand._integer_square_root(offset.length_squared())
		if distance <= 0:
			endpoints[index] = start
			nearest = 0.0
			clipped = true
			continue
		var direction := SimCommand._normalized_direction(offset.x, offset.y)
		# Five analytic queries at cue creation share the actor-ray radius and
		# shot-cover policy. Drawing only consumes these detached cached spokes.
		var clear := CombatSystem.spray_clear_endpoint(origin, direction, distance, int(definition.radius), collision)
		var full := origin + ElementChemistrySystem.scaled(direction, distance)
		# Successful fixed-point normalization need not land on the original float
		# endpoint. Preserve the old all-clear visual exactly instead of jittering.
		if clear != full:
			endpoints[index] = start if clear == origin else Vector2(clear) / SimConfig.FIXED_SCALE
			clipped = true
		nearest = minf(nearest, start.distance_to(endpoints[index]))
	var old_length := start.distance_to(geometry.end)
	if clipped:
		geometry.brace = _spray_cue_brace(start, (geometry.end - start).normalized(), float(geometry.half_angle), minf(old_length, nearest))
	# Only detached vectors/scalars leave this helper: no mutable world, event,
	# obstacle or actor survives into the finite cue's drawing path.
	return geometry


static func _spray_cue_geometry(cue: Dictionary, definition: Dictionary) -> Dictionary:
	var start := _cue_point(cue, "start", _cue_point(cue, "position", Vector2.ZERO))
	var endpoint := _cue_point(cue, "end", _cue_point(cue, "position", start))
	if not start.is_finite() or not endpoint.is_finite():
		return {}
	var lane := endpoint - start
	if lane.length_squared() <= 0.0:
		return {}
	var fixed_range := _cue_fixed_range(cue)
	if fixed_range <= 0:
		fixed_range = int(definition.get("range", 0))
	var maximum_length := float(fixed_range) / 1000.0
	var length := minf(lane.length(), maximum_length) if maximum_length > 0.0 else lane.length()
	if length <= 0.0:
		return {}
	var direction := lane.normalized()
	var cone_cosine_squared := clampf(float(definition.get("cone_cosine_squared_per_million", 820_000)) / 1_000_000.0, 0.05, 1.0)
	var half_angle := acos(sqrt(cone_cosine_squared))
	var endpoints := PackedVector2Array()
	for offset: float in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		endpoints.append(start + direction.rotated(half_angle * offset) * length)
	return {"start": start, "end": start + direction * length, "half_angle": half_angle,
		"endpoints": endpoints, "brace": _spray_cue_brace(start, direction, half_angle, length)}


static func _spray_cue_brace(start: Vector2, direction: Vector2, half_angle: float, length: float) -> PackedVector2Array:
	# The start brace identifies a transient cast fan. It does not surround or
	# fill the authoritative ground cells affected after resolution.
	var brace_distance := minf(18.0, length * 0.22)
	var brace_center := start + direction * brace_distance
	var brace_half := minf(8.0, tan(half_angle) * brace_distance)
	var side := direction.orthogonal()
	return PackedVector2Array([brace_center - side * brace_half, brace_center + side * brace_half])


func _draw_cue_cross(canvas: CanvasItem, position: Vector2, dark: Color, base: Color, bright: Color, opacity: float, progress: float, reduced: bool, expanding: bool) -> void:
	var extent := 5.0 + (progress * (6.0 if reduced else 10.0) if expanding else 0.0)
	MagicGlow.draw_radial(canvas, position, 5.0, base, bright, reduced, opacity * opacity)
	var thickness := 2.0 if reduced else 3.0
	canvas.draw_line(position - Vector2(extent, 0), position + Vector2(extent, 0), Color(dark, opacity * 0.82), thickness + 2.0)
	canvas.draw_line(position - Vector2(0, extent), position + Vector2(0, extent), Color(dark, opacity * 0.82), thickness + 2.0)
	canvas.draw_line(position - Vector2(extent, 0), position + Vector2(extent, 0), Color(base, opacity * 0.92), thickness)
	canvas.draw_line(position - Vector2(0, extent), position + Vector2(0, extent), Color(bright, opacity), thickness)
	canvas.draw_rect(Rect2(position - Vector2.ONE * 2.0, Vector2.ONE * 4.0), Color(bright, opacity), true)


func _draw_magic_cue_glow(canvas: CanvasItem, cue: Dictionary, model: Dictionary, palette: Array[Color], reduced: bool) -> void:
	if model.is_empty() or not bool(model.get("visible", false)):
		return
	var opacity := MagicGlow.cue_opacity(cue, int(model.get("duration_ticks", 0)))
	# Stationary contact/hand accent, not an expanding area or extra lifetime.
	MagicGlow.draw_radial(canvas, model.position, minf(16.0, 8.0 * float(model.get("scale", 1.0))), palette[1], palette[2], reduced, opacity)


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


static func projectile_full_size(family: String, radius_fixed: int) -> float:
	if not FAMILY_SIZE.has(family) or radius_fixed <= 0:
		return 0.0
	# The immutable collision radius, never current velocity, owns launch size.
	# Core strength loss is independent: contact marks still use shot.radius.
	return maxf(float(FAMILY_SIZE[family]), collision_radius_px(radius_fixed) * 2.0)


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
		return String(definition.get("family", ""))
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
