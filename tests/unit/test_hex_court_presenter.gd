extends FluxTestSuite


const Presenter = preload("res://src/presentation/hex_court_presenter.gd")
const OLD_PRODUCT_IDENTITIES := [
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


class MissingRegionCourt:
	extends RefCounted


class RegionCourt:
	extends RefCounted
	var regions: Array = []

	func render_regions(_cell: Vector2i, _material: String, _tick: float) -> Array:
		return regions


# Geometry-only duck-typed court: exercises cache invalidation without claiming
# gameplay admission. Real paid material coverage is tested in shared presenter.
class GeometryCourt:
	extends RefCounted
	var cells: Dictionary = {Vector2i.ZERO: {}}
	var origin := Vector2i.ZERO
	var render_revision := 0


class ViewProbe extends HexCourtPresenter:
	var selected: Array[Vector2i] = []
	func draw_ground(_canvas: CanvasItem, court: RefCounted, _tick: float, _reduced: bool, draw_district_base: bool = true) -> bool:
		if not _prepare_court(court, draw_district_base): return false
		selected = _cells.duplicate()
		return true


class OutlineProbe extends HexCourtPresenter:
	var submitted: Array[Dictionary] = []
	func _submit_outline(_canvas: CanvasItem, points: PackedVector2Array, color: Color) -> void:
		submitted.append({"points": points.duplicate(), "color": color})


func run() -> int:
	_test_configuration_and_fail_closed_regions()
	_test_compiled_product_identity()
	_test_backdraft_authoritative_warning()
	_test_coherent_surface_seam_identity()
	_test_inward_outline_geometry()
	_test_boundary_geometry_reuse()
	_test_exact_outline_batches()
	_test_resident_outline_meshes()
	_test_phase_style_metadata()
	_test_strength_scaled_projectile_size()
	_test_compiled_flight_size_and_fixed_contact_extent()
	_test_projectile_size_cache()
	_test_projectile_cache_reuse_and_bound()
	_test_projectile_helpers_do_not_mutate_state()
	_test_projectile_nose_facet()
	_test_projectile_nose_motion_and_modes()
	_test_spray_cue_clear_geometry()
	_test_spray_cue_cover_and_ownership()
	_test_spray_cue_collision_policy()
	_test_spray_cue_center_pillar()
	_test_retro_pixel_contract()
	_test_material_personalities()
	_test_readable_reaction_stamps()
	_test_magic_glow_geometry_and_palettes()
	_test_magic_glow_cue_lifecycle()
	_test_magic_glow_spray_origin()
	_test_magic_glow_surface_and_budget_contract()
	_test_magic_glow_zero_intensity_integration()
	_test_resident_geometry_cache()
	_test_view_culling_contract()
	return finish("hex-court-presenter")


func _test_compiled_flight_size_and_fixed_contact_extent() -> void:
	var counts := {"rapid": 0, "bolt": 0, "heavy": 0}
	for wire: int in CombatTuning.runtime_wire_ids():
		var definition := CombatTuning.projectile_definition(wire)
		var family := String(definition.get("family", ""))
		if not counts.has(family): continue
		counts[family] += 1
		var radius := int(definition.radius)
		var strength := int(definition.reaction_strength)
		var full := Presenter.projectile_full_size(family, radius)
		check(full >= float(radius) * 0.002, "full-strength compiled core art box spans at least its actual collider diameter")
		if family == "heavy": equal(full, 60.0, "current Heavy starts with60px art diameter, not the retired32px box")
		if family == "rapid": equal(full, 18.0, "tiny fast Rapid retains its18px readable art floor without enlarging collider")
		if family == "bolt": check(full >= 24.0 and full <= 36.0, "per-spell Bolt body preserves its actual12-18px radius distinction")
		var marks := Presenter.projectile_contact_pixels(Presenter.collision_radius_px(radius))
		equal(marks.size(), 4, "all current family radii have four fixed contact marks")
		equal(marks.size() * 2, Presenter.PROJECTILE_CONTACT_DRAW_LIMIT, "contact contrast has a fixed eight-command budget per live projectile")
		var previous := INF
		for remaining: int in range(strength, 0, -1):
			var core := Presenter.strength_scaled_size(full, remaining, strength)
			check(core <= previous and core > 0.0, "strength loss can only shrink the readable central energy core")
			previous = core
			for mark: Rect2 in marks:
				for point: Vector2 in [mark.position, mark.end, Vector2(mark.position.x, mark.end.y), Vector2(mark.end.x, mark.position.y)]:
					check(point.length() <= float(radius) / 1000.0, "both contrast layers remain inside the unchanged flight collider")
				equal(mark.size, Vector2(2, 2), "strength loss cannot reduce fixed collision contact ticks")
			for velocity: Vector2i in [Vector2i.ZERO, Vector2i(1000, 0), Vector2i(600000, 0), Vector2i(-900000, 900000)]:
				var shot := ProjectileState.new(77, 1, 1, wire, int(definition.element_wire_id), Vector2i.ZERO, velocity, radius, int(definition.damage), 100)
				shot.initial_strength = strength
				shot.remaining_strength = remaining
				var before := shot.canonical_values()
				equal(Presenter.projectile_full_size(family, shot.radius), full, "field slowing/reversal never buffs body size or collision extent")
				equal(Presenter.projectile_contact_pixels(Presenter.collision_radius_px(shot.radius)), marks, "full and weakened flight disclose identical physical extent")
				equal(shot.canonical_values(), before, "size/extent queries never mutate authoritative projectile values")
				equal(shot.remaining_strength, remaining, "readability does not restore spent strength")
	for family: String in counts: check(counts[family] >= 6, "flight comparison covers every canonical element for " + family)
	equal(Presenter.projectile_full_size("missing", 30000), 0.0, "unknown family cannot invent a large body")
	equal(Presenter.projectile_full_size("heavy", 0), 0.0, "missing physical radius has no body")
	var source := FileAccess.get_file_as_string("res://src/presentation/hex_court_presenter.gd")
	check(source.contains("var authored_size := projectile_full_size(family, shot.radius)"), "live flight uses physical full-size helper before existing strength/cache path")
	check(source.contains("_draw_projectile_contact_pixels(canvas, position, shot.radius, shot.element_wire_id, reduced)"), "live fixed contact extent does not borrow shrunken core size")


func _test_magic_glow_geometry_and_palettes() -> void:
	var glow := Presenter.MagicGlow
	var presenter := _configured_presenter()
	var colors := {}
	var shot := ProjectileState.new(82, 2, 3, 140, 3, Vector2i(10_000, 20_000), Vector2i(200_000, -100_000), 9600, 9000, 40)
	shot.initial_strength = 15
	for element: int in range(1, 9):
		shot.element_wire_id = element
		var palette := presenter._element_palette(element)
		colors[glow.layer_color(palette[1], palette[2], 0, 1.0, false)] = true
		for family: String in Presenter.FAMILY_SIZE:
			var previous := INF
			for strength: int in [15, 7, 1, 0]:
				shot.remaining_strength = strength
				var before := shot.canonical_values()
				var size := Presenter.strength_scaled_size(Presenter.FAMILY_SIZE[family], strength, 15)
				var radius := glow.projectile_radius(Presenter.collision_radius_px(shot.radius), size)
				check(radius <= previous, "spent projectile strength never enlarges its luminous envelope")
				previous = radius
				if strength == 0:
					equal(radius, 0.0, "exhausted projectile has no residual glow")
				for layer: int in glow.NORMAL_LAYERS:
					var center := Vector2(120.25, 300.75)
					var points := glow.radial_polygon(center, radius, layer)
					equal(points.size(), 0 if strength == 0 else 12, "bounded twelve-sided light has no particles or travel history")
					for point: Vector2 in points:
						check(point.distance_to(center) <= radius + 0.0001 and point.distance_to(center) < Presenter.collision_radius_px(shot.radius), "every light vertex stays inside true collision extent")
					var normal := glow.layer_color(palette[1], palette[2], layer, 1.0, false)
					var reduced := glow.layer_color(palette[1], palette[2], layer, 1.0, true)
					check(reduced.a < normal.a and normal.a <= 0.24, "Reduced Effects dims light without whitening away element identity")
					equal(Color(normal, 1.0), Color(reduced, 1.0), "effects modes use exactly the same element hue")
				equal(shot.canonical_values(), before, "light sampling cannot change authority, momentum, payload or lifetime")
	equal(colors.size(), 8, "all eight elements preserve distinct canonical light palettes")
	for invalid: float in [0.0, -1.0, INF, NAN]:
		equal(glow.projectile_radius(invalid, 24.0), 0.0, "invalid physical extent suppresses glow")
		equal(glow.projectile_radius(12.0, invalid), 0.0, "invalid core extent suppresses glow")
		check(glow.radial_polygon(Vector2.ZERO, invalid).is_empty(), "invalid light geometry fails closed")
	check(glow.radial_polygon(Vector2(INF, 0), 4.0).is_empty(), "nonfinite position cannot paint light")
	check(glow.radial_polygon(Vector2.ZERO, 1.0e300).is_empty(), "oversized finite decoration is rejected")
	check(glow.radial_polygon(Vector2.ZERO, 4.0, -1).is_empty(), "negative layer is rejected")
	check(glow.radial_polygon(Vector2.ZERO, 4.0, glow.NORMAL_LAYERS).is_empty(), "additional layers are not admitted")
	var points := glow.radial_polygon(Vector2.ZERO, 12.0)
	points[0] = Vector2(999, 999)
	check(glow.radial_polygon(Vector2.ZERO, 12.0)[0] != points[0], "returned light geometry never aliases a future frame")
	equal(glow.draw_radial(null, Vector2.ZERO, 12.0, Color.RED, Color.WHITE, false), 0, "missing canvas never submits light")


func _test_magic_glow_cue_lifecycle() -> void:
	var glow := Presenter.MagicGlow
	var cue := {"age_ticks": 0, "duration": 0.20, "remaining": 0.20}
	var before := var_to_bytes(cue)
	equal(glow.cue_opacity(cue, 24), 1.0, "new admitted cue begins at its existing clock origin")
	equal(var_to_bytes(cue), before, "glow cannot restart or retain a cue clock")
	var last := 1.0
	for age: int in 25:
		cue.age_ticks = age
		var opacity := glow.cue_opacity(cue, 24)
		check(opacity <= last, "light only fades and never pulses or regrows")
		last = opacity
	equal(last, 0.0, "24-tick release leaves no luminous residue")
	for bad_age: Variant in [-1, 24, 9223372036854775807, NAN, "0"]:
		cue.age_ticks = bad_age
		equal(glow.cue_opacity(cue, 24), 0.0, "expired or invalid age fails closed without overflow")
	cue.age_ticks = 0
	for bad_remaining: Variant in [0.0, -1.0, INF, NAN, "1"]:
		cue.remaining = bad_remaining
		equal(glow.cue_opacity(cue, 24), 0.0, "remaining lifetime can extinguish but never revive a cue")
	cue.remaining = 0.1
	equal(glow.cue_opacity(cue, 24), 0.25, "the earliest existing clock controls the squared fade")
	for bad_duration: Variant in [0.0, -1.0, INF, NAN, "1"]:
		cue.duration = bad_duration
		equal(glow.cue_opacity(cue, 24), 0.0, "invalid timer never creates immortal light")


func _test_magic_glow_spray_origin() -> void:
	var definition := CombatTuning.cast_definition(CombatTuning.TIDELINE_WIRE_ID)
	for octant: int in 8:
		for length: float in [8.0, 40.0, 280.0]:
			var cue := _spray_cue_fixture(Vector2(120.25, 320.5), Vector2.from_angle(octant * PI / 4.0), length)
			var geometry := Presenter._spray_cue_geometry(cue, definition)
			var before := var_to_bytes(geometry)
			var origin := Presenter.ProjectileFacets.spray_origin(geometry)
			if origin.is_empty(): continue
			var radius := Presenter.MagicGlow.projectile_radius(origin.radius, origin.core_size)
			var triangle := PackedVector2Array([geometry.start, geometry.brace[0], geometry.brace[1]])
			for point: Vector2 in Presenter.MagicGlow.radial_polygon(origin.position, radius):
				check(Geometry2D.is_point_in_polygon(point, triangle), "Spray glow stays inside its existing cover-clipped origin fan")
			equal(var_to_bytes(geometry), before, "light does not lengthen or retile the admitted Spray geometry")


func _test_magic_glow_surface_and_budget_contract() -> void:
	var glow := Presenter.MagicGlow
	for phase: String in ["forming", "ignition", "active", "decaying", "cooling", "invalid"]:
		for reduced: bool in [false, true]:
			var value := glow.surface_opacity(phase, 1000, reduced)
			equal(value > 0.0, phase == "active" and not reduced, "only normal active material receives decorative light")
	equal(glow.surface_opacity("active", 0, false), 0.0, "zero-intensity residue cannot gain an active glow")
	equal(glow.surface_opacity("active", 10000, false), 0.52, "high intensity cannot turn light opaque")
	for cell: Vector2i in [Vector2i(1, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var polygon := PackedVector2Array()
		for fixed_point: Vector2i in HexGrid.vertices(cell): polygon.append(Vector2(fixed_point) / 1000.0)
		var before := polygon.duplicate()
		for layer: int in glow.SURFACE_LAYERS:
			var inset := glow.surface_polygon(polygon, layer)
			equal(inset.size(), 6, "surface glow is an inset of the occupied hex, never a radial field")
			for point: Vector2 in inset:
				check(Geometry2D.is_point_in_polygon(point, polygon), "surface light never crosses its authoritative boundary into an empty neighbor")
			check(not Geometry2D.is_point_in_polygon(Vector2.ZERO, inset), "a ring of occupied hexes leaves its center safely unpainted")
			equal(polygon, before, "inset geometry never mutates stored coverage")
		polygon.reverse()
		equal(glow.surface_polygon(polygon, 0).size(), 6, "clockwise and counterclockwise canonical hexes work")
		for offset: int in 6:
			var crossed := PackedVector2Array()
			for index: int in [0, 2, 4, 1, 3, 5]: crossed.append(polygon[(index + offset) % 6])
			for reverse: bool in [false, true]:
				if reverse: crossed.reverse()
				for layer: int in glow.SURFACE_LAYERS:
					check(glow.surface_polygon(crossed, layer).is_empty(), "equal-turn crossed hex order fails closed in every start/winding/layer")
	for invalid: PackedVector2Array in [PackedVector2Array(), PackedVector2Array([Vector2.ZERO, Vector2.ONE]), PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])]:
		check(glow.surface_polygon(invalid, 0).is_empty(), "malformed surface cannot invent coverage")
	equal(glow.NORMAL_LAYERS, 3, "at most three normal projectile/contact glow draws")
	equal(glow.REDUCED_LAYERS, 1, "Reduced Effects uses only one soft core draw")
	equal(glow.SURFACE_LIMIT * glow.SURFACE_LAYERS, 96, "at most 96 decoration-only surface draws per ground frame including cover repaint")
	var source := FileAccess.get_file_as_string("res://src/presentation/hex_court_presenter.gd")
	check(source.contains("_magic_surface_glows = 0") and source.contains("_magic_surface_glows >= Quality.surface_glow_limit(MagicGlow.SURFACE_LIMIT)"), "production resets and enforces the surface-only decoration budget")
	check(source.contains("MagicGlow.projectile_radius(collision_radius_px(shot.radius), minf(size, target_size))"), "production light shares physical and immediately consumed strength limits")
	check(source.contains("not bool(model.get(\"visible\", false))"), "authored hidden/expired contact and release frames cannot leave glow behind")
	var helper := FileAccess.get_file_as_string("res://src/presentation/hex_magic_glow.gd")
	for forbidden: String in ["Image.create", "ImageTexture.create", "ShaderMaterial", "PointLight2D", "GPUParticles", "CPUParticles", "lifetime_ticks =", "remaining_strength =", "previous_position", "sin(", "cos("]:
		check(not helper.contains(forbidden), "glow avoids per-pixel, world-light, time-history and gameplay work: " + forbidden)


func _test_magic_glow_zero_intensity_integration() -> void:
	var presenter := _configured_presenter()
	var fixed := PackedVector2Array()
	var display := PackedVector2Array()
	for point: Vector2i in HexGrid.vertices(Vector2i.ZERO):
		fixed.append(Vector2(point))
		display.append(Vector2(point) / 1000.0)
	var source := {"footprint_id": 17, "polygon": fixed, "phase": "active", "danger": false, "intensity": 0, "owner_key": 4, "expiry_tick": 720}
	var before := var_to_bytes(source)
	var zero := presenter._prepare_region(source, "water", display)
	check(not zero.is_empty(), "zero-intensity authoritative material remains valid stored residue")
	equal(int(zero.intensity), 1, "existing nonzero art floor is preserved exactly")
	equal(int(zero.raw_intensity), 0, "raw authority intensity survives preparation for light admission only")
	equal(var_to_bytes(source), before, "preparing light metadata never mutates authoritative material")
	source.intensity = 1
	var positive := presenter._prepare_region(source, "water", display)
	equal(presenter._water_region_style(zero, false), presenter._water_region_style(positive, false), "legacy fill/edge/phase art remains identical at the existing clamped floor")
	for _index: int in Presenter.MagicGlow.SURFACE_LIMIT + 1:
		equal(presenter._take_magic_surface_glow_opacity(zero, false), 0.0, "prepared zero-intensity residue cannot receive new light")
	equal(presenter._magic_surface_glows, 0, "zero-intensity preparation consumes no decorative budget")
	check(presenter._take_magic_surface_glow_opacity(positive, false) > 0.0, "genuinely positive authority stock retains its proportional light")
	equal(presenter._magic_surface_glows, 1, "one positive surface reserves one bounded glow")
	equal(presenter._take_magic_surface_glow_opacity(zero, false), 0.0, "later zero residue cannot borrow the positive surface admission")
	equal(presenter._magic_surface_glows, 1, "zero residue leaves an existing budget count unchanged")
	equal(presenter._take_magic_surface_glow_opacity(positive, true), 0.0, "Reduced Effects never reserves a decorative surface slot")
	positive.phase = "decaying"
	equal(presenter._take_magic_surface_glow_opacity(positive, false), 0.0, "terminal material never reserves a decorative surface slot")
	equal(presenter._magic_surface_glows, 1, "quiet modes/phases preserve the remaining budget")
	positive.phase = "active"
	for _index: int in Presenter.MagicGlow.SURFACE_LIMIT - 1:
		check(presenter._take_magic_surface_glow_opacity(positive, false) > 0.0, "remaining supported surfaces can consume the finite budget")
	equal(presenter._magic_surface_glows, Presenter.MagicGlow.SURFACE_LIMIT, "surface admissions stop at the original cap")
	equal(presenter._take_magic_surface_glow_opacity(positive, false), 0.0, "overflow only omits decorative glow")
	equal(presenter._magic_surface_glows, Presenter.MagicGlow.SURFACE_LIMIT, "overflow cannot grow the budget")


func _test_compiled_product_identity() -> void:
	var presenter := _configured_presenter()
	# The original 36 art identities are still frozen; live rules choose their
	# visual alias explicitly without inheriting archived geometry or admission.
	for index: int in OLD_PRODUCT_IDENTITIES.size():
		var row: Array = OLD_PRODUCT_IDENTITIES[index]
		var archived: Dictionary = Presenter.ArchiveContract.REACTIONS[index]
		equal([archived.id, archived.wire_id, archived.elements[0], archived.elements[1], archived.shape], row, "all archived artwork identities remain exact")
	equal(Presenter.INGREDIENT_MATERIALS, ["water", "fire", "wind", "earth", "light", "dark"], "live ingredient admission follows the six canonical elements")
	equal(Presenter.PRODUCT_MATERIALS.size(), 63, "every live combination has a render material")
	var live_wires: Array[int] = Presenter.RecipePolicy.active_wire_ids()
	for index: int in live_wires.size():
		var wire: int = live_wires[index]
		var definition := Presenter.RecipePolicy.definition(wire)
		var material := String(definition.product_layer)
		equal(Presenter.PRODUCT_MATERIALS[index], material, "live policy order selects the current material")
		var archived: Dictionary = Presenter.ArchiveContract.REACTIONS[int(definition.archive_recipe_wire) - 301]
		var first := String(archived.elements[0])
		var second := String(archived.elements[1])
		var expected := {"material": material, "wire_id": wire, "ingredient": false,
			"first": first, "second": second, "shape": String(archived.shape),
			"visual_material": String(definition.visual_material),
			"cadence": "%s+%s" % [presenter._language.element_cadence(first), presenter._language.element_cadence(second)],
			"atmospheric": Presenter.ATMOSPHERIC_MATERIALS.has(String(definition.visual_material))}
		var actual := presenter._material_descriptor(material)
		equal(var_to_bytes(actual), var_to_bytes(expected), "live descriptor uses its explicit archived art alias only")
		actual.shape = "caller mutation"
		equal(presenter._material_descriptor(material), expected, "descriptor result does not alias later calls")
	for material: String in ["flood", "firestorm", "mistcurrent", "blackwater"]:
		var style := presenter._shared_material_style(material, {"phase": "active", "danger": true, "intensity": 1000}, false)
		equal(style.visual_material, Presenter.RecipePolicy.definition(int(style.wire_id)).visual_material, "derived frozen/electrical motifs bypass retired behavior-name overrides")
		check(style.visual_material != material, "repurposed stable wire explicitly selects a new derived motif")
	for material: String in Presenter.INGREDIENT_MATERIALS:
		var value := presenter._material_descriptor(material)
		equal(value.first, material, "ingredient identity preserved")
		equal(value.wire_id, 0, "ingredients cannot become reaction recipes")
	for retired: String in ["ice", "charge", "overload", "not-a-material"]:
		check(presenter._material_descriptor(retired).is_empty(), "retired/archive-only material is not a live selectable field")
	presenter._language.elements.earth.cadence = "changed-at-runtime"
	equal(presenter._material_descriptor("fortify").cadence, "changed-at-runtime+changed-at-runtime", "visual metadata is not frozen in a persistent descriptor cache")


func _test_backdraft_authoritative_warning() -> void:
	var presenter := _configured_presenter()
	var region := {"recipe_wire_id": 315, "phase": "active", "danger": true, "active_tick": 80, "decay_tick": 400, "expiry_tick": 448}
	check(not Presenter.backdraft_warning(region, 327.999), "Backdraft remains veiled before the actual final 72 ticks")
	check(Presenter.backdraft_warning(region, 328), "Backdraft exposes its exact 600 ms detonation warning")
	check(Presenter.backdraft_warning(region, 399.999), "warning persists until the actual end of active danger")
	check(not Presenter.backdraft_warning(region, 400), "decay cannot retain a detonation warning")
	for field: String in ["phase", "danger", "recipe_wire_id", "decay_tick"]:
		var invalid := region.duplicate()
		invalid[field] = {"phase": "forming", "danger": false, "recipe_wire_id": 310, "decay_tick": 0}[field]
		check(not Presenter.backdraft_warning(invalid, 399), "warning rejects inappropriate " + field)
	var fixed := PackedVector2Array()
	for vertex: Vector2i in HexGrid.vertices(Vector2i.ZERO): fixed.append(Vector2(vertex))
	var source := region.duplicate()
	source.merge({"footprint_id": 37, "intensity": 1000, "owner": 1, "source_ids": [4, 5], "polygon": fixed})
	var prepared := presenter._prepare_region(source, "cinderveil")
	check(not prepared.is_empty(), "real Backdraft region is prepared")
	equal(prepared.active_tick, region.active_tick, "preparation preserves authoritative formation endpoint")
	equal(prepared.decay_tick, region.decay_tick, "preparation preserves possibly clipped active endpoint")
	check(Presenter.backdraft_warning(prepared, 328), "prepared render record carries actual warning timing")
	var later := prepared.duplicate(true)
	later.decay_tick = 500
	check(presenter._region_edge_prefix(later) != presenter._region_edge_prefix(prepared), "different Backdraft fuse endpoints cannot hide their semantic boundary")
	check(not Presenter.backdraft_warning(later, 328), "neighbour with a later fuse remains outside its warning")


func _test_boundary_geometry_reuse() -> void:
	var presenter := _configured_presenter()
	var oracle := preload("res://tests/support/hex_boundary_oracle.gd").new()
	var metadata := {"material": "steam", "footprint_id": 17, "phase": "active", "danger": true, "intensity": 900, "owner_key": [4, 7], "expiry_tick": 720}
	for origin: Vector2 in [Vector2.ZERO, Vector2(-24000, 18000), Vector2(314159, -271828)]:
		var fixed := PackedVector2Array()
		var display := PackedVector2Array()
		for point: Vector2i in HexGrid.vertices(Vector2i.ZERO):
			fixed.append(Vector2(point) + origin)
			display.append((Vector2(point) + origin) / 1000.0)
		for reversed: bool in [false, true]:
			if reversed:
				fixed.reverse()
				display.reverse()
			var segments := presenter._boundary_segments(fixed)
			for index: int in 6:
				equal(presenter._region_edge_prefix(metadata) + segments[index], presenter._region_edge_key(metadata, fixed[index], fixed[(index + 1) % 6]), "cached segment is byte-exact in either winding and at shifted origins")
			var region := metadata.duplicate(true)
			region.fixed_polygon = fixed
			region.polygon = display
			var rows := {Vector2i.ZERO: [region]}
			for material: String in Presenter.MATERIALS:
				region.material = material
				for phase: String in ["forming", "active", "decaying"]:
					region.phase = phase
					region.danger = phase == "active"
					region.owner_key = [4, phase.length()]
					region.intensity += 1
					region.expiry_tick += 1
					equal(var_to_bytes(presenter._region_edge_counts(rows)), var_to_bytes(oracle._region_edge_counts(rows)), "cached geometry never freezes dynamic seam identity")
			for width: float in [1.0, 2.0, 2.5, 0.75, 0.0, -1.0]:
				var triangles := presenter._boundary_triangles(display, width)
				check(triangles.is_read_only(), "outer geometry is immutable")
				for index: int in 6:
					check(triangles[index].is_read_only(), "per-edge geometry is immutable")
					var expected := presenter._inward_edge_triangles(display, index, width)
					equal(triangles[index].size(), expected.size(), "cached edge retains exact triangle count")
					for part: int in expected.size():
						check(triangles[index][part].is_read_only(), "triangle points are immutable too")
						equal(var_to_bytes(PackedVector2Array(triangles[index][part])), var_to_bytes(expected[part]), "cached triangles are exactly the previous geometry")
				if width > 0.0:
					var detached := PackedVector2Array(triangles[0][0])
					detached[0] += Vector2(123, 456)
					equal(PackedVector2Array(presenter._boundary_triangles(display, width)[0][0]), presenter._inward_edge_triangles(display, 0, width)[0], "native conversion cannot poison cached points")
			check(segments.is_read_only(), "segment array is immutable")
			var detached_segments := segments.duplicate()
			detached_segments[0] = "changed by caller"
			check(presenter._boundary_segments(fixed)[0] != detached_segments[0], "detached segments cannot poison cache")
	# Fill and wrap the bounded FIFO without relying on a court revision or tick.
	for index: int in Presenter.BOUNDARY_CACHE_LIMIT + 37:
		var polygon := PackedVector2Array()
		for point: Vector2i in HexGrid.vertices(Vector2i(index, 0)):
			polygon.append(Vector2(point) / 1000.0)
		presenter._boundary_segments(polygon)
		for width: float in [1.0, 2.0, 2.5, 3.25]: presenter._boundary_triangles(polygon, width)
		check(presenter._edge_segments_cache.size() <= Presenter.BOUNDARY_CACHE_LIMIT, "segment cache remains bounded across map travel")
		check(presenter._outline_geometry_cache.size() <= Presenter.BOUNDARY_CACHE_LIMIT, "outline cache remains bounded across map travel")
		check((presenter._outline_geometry_cache[polygon] as Dictionary).size() == 3, "nonproduction widths cannot grow a cached row")
	var oldest := presenter._outline_geometry_order[presenter._outline_geometry_cursor]
	var original := presenter._boundary_triangles(oldest, 2.0)
	var shifted := oldest.duplicate()
	shifted[0] += Vector2(0.001, 0.002)
	check(presenter._boundary_triangles(shifted, 2.0) != original, "tiny geometry changes are not quantized or aliased")
	check(not presenter.configure(null), "invalid reconfiguration rejected")
	check(presenter._edge_segments_cache.is_empty() and presenter._outline_geometry_cache.is_empty(), "reconfiguration clears geometry and no stale cache survives failure")
	check(presenter._edge_segments_order.is_empty() and presenter._outline_geometry_order.is_empty(), "eviction indexes are reset too")


func _test_retro_pixel_contract() -> void:
	var stamps := Presenter.RetroMarks.new()
	for kind: String in stamps.MASKS:
		var rows: Array = stamps.MASKS[kind]
		equal(rows.size(), 9, "pixel stamp has nine rows")
		for row: String in rows:
			equal(row.length(), 9, "pixel stamp has nine columns")
			for token: String in row:
				check(token in [".", "1", "2", "3"], "stamp uses only transparent/ink/base/highlight")
		for frame: int in 3:
			var texture: Texture2D = stamps.texture_for(kind, Color.BLACK, Color.RED, Color.WHITE, frame)
			equal(texture.get_size(), Vector2(9,9), "native pixel grid")
			equal(stamps.texture_for(kind, Color.BLACK, Color.RED, Color.WHITE, frame), texture, "repeated marks share one texture")
	for radius: float in [7.0, 8.0, 9.0, 12.0, 30.0]:
		for center: Vector2 in [Vector2.ZERO, Vector2(0.49,-0.49), Vector2(107.21,808.31)]:
			var rect := stamps.stamp_rect(center, radius)
			if not rect.has_area(): continue
			equal(int(rect.size.x)%9, 0, "stamp uses integer texel size")
			for point: Vector2 in [rect.position, rect.end, Vector2(rect.position.x,rect.end.y), Vector2(rect.end.x,rect.position.y)]:
				check(point.distance_to(center) < radius, "mark remains inside cell clearance after pixel snapping")
		for rect: Rect2 in Presenter.projectile_contact_pixels(radius):
			for point: Vector2 in [rect.position, rect.end, Vector2(rect.position.x,rect.end.y), Vector2(rect.end.x,rect.position.y)]:
				check(point.length() <= radius, "contact pixel stays inside physical projectile radius")
	equal(stamps.frame_index(100,2,true),0,"reduced effects freeze decorative pixel motion")
	equal(stamps.frame_index(7,0,false),0,"retro cadence stable within eight samples")
	equal(stamps.frame_index(8,0,false),1,"retro cadence advances without rotating geometry")
	for index: int in 220:
		stamps.texture_for("fire", Color(float(index)/255.0,0,0), Color.RED, Color.WHITE,0)
	check(stamps.textures.size() <= stamps.CACHE_LIMIT, "texture cache remains bounded")
	check(Presenter.projectile_contact_pixels(INF).is_empty(),"invalid radius does not draw")


func _test_material_personalities() -> void:
	var stamps := Presenter.RetroMarks.new()
	var silhouettes := {}
	for kind: String in Presenter.INGREDIENT_MATERIALS + Presenter.COMBAT_PHASE_MATERIALS:
		check(stamps.MASKS.has(kind), "every basic element and revised reaction has its own compact pixel vocabulary")
		var signature := ""
		for row: String in stamps.MASKS[kind]:
			signature += row.replace("1", "#").replace("2", "#").replace("3", "#")
		check(not silhouettes.has(signature), "elements and revised reactions have distinct silhouettes even without color")
		silhouettes[signature] = true
		equal(stamps.material_frame(kind, 9999, 13, true), 0, "Reduced Effects uses a stable readable material pose")
		equal(stamps.material_frame(kind, NAN, 13, false), 0, "invalid time cannot animate a material")
	for kind: String in stamps.ANIMATED_MASKS:
		var identities := {}
		for frame: int in 3:
			var rows: Array = stamps.ANIMATED_MASKS[kind][frame]
			equal(rows.size(), 9, "each authored material pose remains nine rows")
			for row: String in rows:
				equal(row.length(), 9, "each authored material pose remains nine columns")
				for token: String in row:
					check(token in [".", "1", "2", "3"], "animated material uses only the same three palette entries")
			var texture := stamps.texture_for(kind, Color.BLACK, Color.RED, Color.WHITE, frame, true) as Texture2D
			var pixels := texture.get_image()
			equal(pixels.get_size(), Vector2i(11, 11), "clipped material has one transparent source-texel padding")
			for index: int in 11:
				check(pixels.get_pixel(index, 0).a == 0 and pixels.get_pixel(index, 10).a == 0 and pixels.get_pixel(0, index).a == 0 and pixels.get_pixel(10, index).a == 0, "padded material cannot repeat edge ink into neighboring coverage")
			identities[pixels.get_data().hex_encode()] = true
			equal(stamps.texture_for(kind, Color.BLACK, Color.RED, Color.WHITE, frame, true), texture, "phase-specific padded texture is shared rather than allocated per cell")
		check(identities.size() == 3, "Fire, Charge and Steam each expose three distinct restrained pixel poses")
	equal(stamps.material_frame("earth", 888, 1, false), 0, "loose Earth remains weighty rather than flickering")
	check(int(stamps.CADENCE_TICKS.charge) < int(stamps.CADENCE_TICKS.ice), "Charge highlights snap faster than crystalline Ice")
	check(int(stamps.CADENCE_TICKS.steam) > int(stamps.CADENCE_TICKS.fire), "Steam rises more slowly than Fire flickers")
	var polygon := PackedVector2Array()
	for vertex: Vector2i in HexGrid.vertices(Vector2i(15, 19)):
		polygon.append(Vector2(vertex) / 1000.0)
	var before := polygon.duplicate()
	var uv := stamps.region_uv(polygon)
	equal(uv.size(), 6, "one clipped material draw uses the exact six-point authority polygon")
	for point: Vector2 in uv:
		check(point.x >= 0 and point.x <= 1 and point.y >= 0 and point.y <= 1, "whole-cell material samples remain inside the padded standalone texture")
	var translated := PackedVector2Array()
	for point: Vector2 in polygon:
		translated.append(point + Vector2(300, -200))
	var shifted_uv := stamps.region_uv(translated)
	for index: int in 6:
		check(uv[index].is_equal_approx(shifted_uv[index]), "world translation cannot change motif shape or clip extent")
	equal(polygon, before, "material sampling never edits authoritative geometry")
	check(stamps.region_uv(PackedVector2Array()).is_empty(), "removed region leaves no ghost material")
	check(not stamps.draw_region(null, "steam", polygon, Color.BLACK, Color.RED, Color.WHITE, 0, 0, false), "missing canvas cannot accidentally admit presentation work")


func _test_readable_reaction_stamps() -> void:
	var stamps := Presenter.RetroMarks.new()
	for kind: String in Presenter.COMBAT_PHASE_MATERIALS:
		var occupied := 0
		var ink := 0
		for row: String in stamps.MASKS[kind]:
			for token: String in row:
				if token != ".": occupied += 1
				if token == "1": ink += 1
		check(occupied >= 27 and occupied <= 45, "reaction clusters retain a readable core and breathing room at gameplay scale")
		check(ink * 2 < occupied, "selective reaction shadow does not dominate as a closed outline")
		var first := stamps.texture_for(kind, Color.BLACK, Color.RED, Color.WHITE, 0, true).get_image()
		for frame: int in 3:
			var pixels := stamps.texture_for(kind, Color.BLACK, Color.RED, Color.WHITE, frame, true).get_image()
			for y: int in 11:
				for x: int in 11:
					equal(pixels.get_pixel(x, y).a, first.get_pixel(x, y).a, "reaction highlight cadence never moves or expands its silhouette")
			for edge: int in 11:
				check(pixels.get_pixel(edge, 0).a == 0 and pixels.get_pixel(edge, 10).a == 0 and pixels.get_pixel(0, edge).a == 0 and pixels.get_pixel(10, edge).a == 0, "revised reaction keeps transparent padding for exact hex clipping")
	for kind: String in stamps.MIRRORED_MATERIALS:
		equal(stamps.spatial_variant(kind, -1), 1, "negative world seeds select the same bounded static poses")
		equal(stamps.spatial_variant(kind, 200), 0, "large seed does not add texture variants")
		for frame: int in 3:
			var original := stamps.texture_for(kind, Color.BLACK, Color.RED, Color.WHITE, frame, true, 0).get_image()
			var reflected := stamps.texture_for(kind, Color.BLACK, Color.RED, Color.WHITE, frame, true, 1).get_image()
			check(original.get_data() != reflected.get_data(), "asymmetric reaction has two distinct anchored poses")
			for y: int in 11:
				for x: int in 11:
					equal(reflected.get_pixel(x, y), original.get_pixel(10 - x, y), "spatial pose reflects only source pixels inside the unchanged padding")
		var still := stamps.texture_for(kind, Color.BLACK, Color.RED, Color.WHITE, 0, true, 1)
		for tick: float in [0.0, 18.0, 90.0, 9999.0]:
			var frame := stamps.material_frame(kind, tick, 17, true)
			equal(stamps.texture_for(kind, Color.BLACK, Color.RED, Color.WHITE, frame, true, stamps.spatial_variant(kind, 17)), still, "Reduced Effects retains the same cached spatial pose across time")
	var bounded := Presenter.RetroMarks.new()
	for seed: int in range(-100, 101):
		for frame: int in 3:
			bounded.texture_for("arcflash", Color.BLACK, Color.RED, Color.WHITE, frame, true, seed)
	equal(bounded.textures.size(), 6, "arbitrary cell seeds reuse only two poses times three frames")
	equal(bounded.order.size(), 6, "reused poses do not duplicate cache eviction entries")
	equal(stamps.texture_for("earth", Color.BLACK, Color.RED, Color.WHITE, 0, false, 999), stamps.texture_for("earth", Color.BLACK, Color.RED, Color.WHITE, 0), "unrelated elements keep one spatial pose and their existing cache entry")


func _configured_presenter() -> HexCourtPresenter:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "shared visual language loads for the hex presenter")
	var presenter := Presenter.new()
	check(presenter.configure(language), "hex presenter accepts the validated shared palette")
	return presenter


func _test_configuration_and_fail_closed_regions() -> void:
	var presenter := Presenter.new()
	check(not presenter.configure(null), "hex presenter refuses a missing shared palette")
	check(not presenter.configure(VisualLanguage.new()), "hex presenter refuses an unloaded shared palette")
	presenter = _configured_presenter()
	presenter._cells = [Vector2i.ZERO]
	var full_fixed := PackedVector2Array([
		Vector2(0, -27_712), Vector2(24_000, -13_856), Vector2(24_000, 13_856),
		Vector2(0, 27_712), Vector2(-24_000, 13_856), Vector2(-24_000, -13_856),
	])
	var full_display := PackedVector2Array()
	for point: Vector2 in full_fixed:
		full_display.append(point / 1000.0)
	presenter._vertices[Vector2i.ZERO] = full_display
	var active_views := {Vector2i.ZERO: {"water_quantity": 1, "fire_quantity": 0, "steam_quantity": 0}}
	check(presenter._collect_render_regions(MissingRegionCourt.new(), active_views, 0.0).is_empty(), "quantity-positive material without the authority API fails closed")
	var court := RegionCourt.new()
	check(presenter._collect_render_regions(court, active_views, 0.0).is_empty(), "quantity-positive material without an explicit region fails closed")
	var metadata := {"footprint_id": 7, "phase": "forming", "danger": false, "intensity": 1000, "owner": 2, "expires": 480}
	var tangent := metadata.duplicate()
	tangent.polygon = PackedVector2Array()
	court.regions = [tangent]
	check(presenter._collect_render_regions(court, active_views, 0.0).is_empty(), "zero-area analytic tangent is no longer valid whole-cell presentation input")
	var clipped := metadata.duplicate()
	clipped.polygon = PackedVector2Array([full_fixed[0], full_fixed[1], full_fixed[2], full_fixed[3]])
	court.regions = [clipped]
	check(presenter._collect_render_regions(court, active_views, 0.0).is_empty(), "analytic four-edge clip cannot masquerade as selected-hex coverage")
	var whole := metadata.duplicate()
	whole.polygon = full_fixed
	court.regions = [whole]
	var regions := presenter._collect_render_regions(court, active_views, 0.0)
	check(not regions.is_empty(), "complete authoritative selected-hex polygon is valid presentation input")
	equal((regions.water[Vector2i.ZERO] as Array).size(), 1, "one authoritative cell record produces one complete visual surface")
	equal(((regions.water[Vector2i.ZERO] as Array)[0] as Dictionary).polygon, full_display, "presenter preserves the exact complete cell boundary")
	var missing_owner := whole.duplicate()
	missing_owner.erase("owner")
	court.regions = [missing_owner]
	check(presenter._collect_render_regions(court, active_views, 0.0).is_empty(), "whole-cell surface still requires ownership metadata")
	var missing_expiry := whole.duplicate()
	missing_expiry.erase("expires")
	court.regions = [missing_expiry]
	check(presenter._collect_render_regions(court, active_views, 0.0).is_empty(), "whole-cell surface still requires expiry metadata")


func _test_coherent_surface_seam_identity() -> void:
	var presenter := _configured_presenter()
	var identity := {"material": "steam", "footprint_id": 17, "phase": "active", "danger": true, "intensity": 900, "owner_key": 4, "expiry_tick": 720}
	var forward := presenter._region_edge_key(identity, Vector2(1000, -500), Vector2(1000, 500))
	var reverse := presenter._region_edge_key(identity, Vector2(1000, 500), Vector2(1000, -500))
	equal(forward, reverse, "seam identity is independent of polygon winding")
	equal(forward, "steam/17/active/true/900/720/4/1000,-500:1000,500", "record, phase, danger, intensity, expiry and owner use explicit stable text")
	var safe := identity.duplicate()
	safe.danger = false
	check(presenter._region_edge_key(safe, Vector2(1000, -500), Vector2(1000, 500)) != forward, "danger boundary cannot merge into a safe neighbor")
	for changed_field: String in ["phase", "owner_key", "intensity", "expiry_tick"]:
		var changed := identity.duplicate()
		changed[changed_field] = "decaying" if changed_field == "phase" else int(changed[changed_field]) + 1
		check(presenter._region_edge_key(changed, Vector2(1000, -500), Vector2(1000, 500)) != forward, "%s boundary remains visible" % changed_field)
	var left_polygon := PackedVector2Array([Vector2(0, -1000), Vector2(1000, -500), Vector2(1000, 500), Vector2(0, 1000), Vector2(-1000, 500), Vector2(-1000, -500)])
	var right_polygon := PackedVector2Array([Vector2(1000, -500), Vector2(2000, -1000), Vector2(3000, -500), Vector2(3000, 500), Vector2(2000, 1000), Vector2(1000, 500)])
	var left_source := {"footprint_id": 17, "polygon": left_polygon, "phase": "active", "danger": true, "intensity": 900, "owner_key": 4, "expiry_tick": 720}
	var right_source := left_source.duplicate()
	right_source.polygon = right_polygon
	var left := presenter._prepare_region(left_source, "steam")
	var right := presenter._prepare_region(right_source, "steam")
	var counts := presenter._region_edge_counts({Vector2i.ZERO: [left], Vector2i.RIGHT: [right]})
	equal(int(counts[forward]), 2, "matching footprint/phase/danger/intensity hides the internal shared segment")
	var outer_key := presenter._region_edge_key(left, left_polygon[0], left_polygon[1])
	equal(int(counts[outer_key]), 1, "unpaired outer or hole-facing edge remains a visible boundary")
	var rotated := PackedVector2Array()
	for index: int in left.polygon.size():
		rotated.append(left.polygon[(index + 2) % left.polygon.size()])
	check(Presenter._same_polygon_vertices(left.polygon, rotated), "whole-cell validation accepts the same vertices from a rotated winding")
	check(not Presenter._same_polygon_vertices(left.polygon, PackedVector2Array([left.polygon[0], left.polygon[1], left.polygon[2], left.polygon[3]])), "whole-cell validation rejects a clipped subset")


func _test_inward_outline_geometry() -> void:
	var sampled := PackedVector2Array([Vector2(0, 0), Vector2(2, 0), Vector2(4, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
	check(Presenter._polygon_centroid(sampled).is_equal_approx(Vector2(5, 5)), "boundary sampling cannot pull an area-centered mark toward one short edge")
	var polygon := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
	var strip := Presenter._inward_edge_strip(polygon, 0, 2.0)
	equal(strip.size(), 4, "one semantic boundary is a finite four-point strip")
	equal(strip[0], polygon[0], "boundary strip begins at the exact authority edge")
	equal(strip[1], polygon[1], "boundary strip ends at the exact authority edge")
	for point: Vector2 in strip:
		check(point.x >= 0.0 and point.x <= 10.0 and point.y >= 0.0 and point.y <= 10.0, "outline strip never expands outside the selected cell")
	check(strip[2].y > 0.0 and strip[3].y > 0.0, "outline thickness extends inward from the authority edge")
	check(Presenter._inward_edge_strip(polygon, -1, 2.0).is_empty(), "invalid edge fails closed")
	check(Presenter._inward_edge_strip(polygon, 0, 0.0).is_empty(), "nonpositive boundary width fails closed")
	equal(Presenter._inward_edge_triangles(polygon, 0, 2.0).size(), 2, "convex strip draws as two primitives without polygon triangulation")
	var duplicate := PackedVector2Array([Vector2(1000, 700), Vector2(1000, 700), Vector2(1001, 701), Vector2(999, 701)])
	check(Presenter._inward_edge_triangles(duplicate, 0, 3.0).is_empty(), "zero-length malformed edge produces no degenerate draw primitive")
	var sliver := PackedVector2Array([Vector2(1000, 700), Vector2(1000.0001, 700.0001), Vector2(1001, 701), Vector2(999, 701)])
	for triangle: PackedVector2Array in Presenter._inward_edge_triangles(sliver, 0, 3.0):
		equal(triangle.size(), 3, "float32 sliver emits only explicitly triangulated primitives")
		check(absf((triangle[1] - triangle[0]).cross(triangle[2] - triangle[0])) > 0.0001, "subpixel border omits collapsed triangles")


func _test_phase_style_metadata() -> void:
	var presenter := _configured_presenter()
	var water := {"phase": "active", "danger": false, "intensity": 1000}
	var water_normal := presenter._water_region_style(water, false)
	var water_reduced := presenter._water_region_style(water, true)
	equal(water_normal.base, presenter._language.element_color("water", "base"), "active court Water uses canonical saturated blue")
	equal(water_normal.phase, water_reduced.phase, "reduced Water preserves authoritative phase")
	equal(water_normal.mark_count, 1, "normal Water guarantees one fitting ripple")
	equal(water_reduced.mark_count, 1, "reduced Water keeps one fitting identity ripple")
	check(float(water_reduced.fill_opacity) < float(water_normal.fill_opacity), "reduced Water lowers fill without dropping identity")
	check(not bool(water_reduced.motion) and bool(water_normal.motion), "reduced Water removes motion only")
	var fire := {"phase": "active", "danger": true, "intensity": 1000}
	var fire_normal := presenter._fire_region_style(fire, false)
	var fire_reduced := presenter._fire_region_style(fire, true)
	equal(fire_normal.edge, fire_normal.danger_color, "active harmful Fire uses its shared vivid danger edge")
	equal(fire_normal.phase, fire_reduced.phase, "reduced Fire preserves active phase")
	equal(fire_reduced.mark_count, 1, "reduced Fire retains one fitting phase glyph")
	var steam := {"phase": "active", "danger": true, "intensity": 1000}
	var hot_normal := presenter._steam_region_style(steam, 1500, false)
	var hot_reduced := presenter._steam_region_style(steam, 1500, true)
	equal(hot_normal.palette_phase, "hot", "active high-heat Steam selects the shared hot palette")
	equal(hot_reduced.palette_phase, "hot", "reduced Steam preserves the heat cue")
	equal(hot_normal.mark_count, 2, "normal Steam guarantees two fitting curls")
	equal(hot_reduced.mark_count, 2, "reduced Steam keeps two fitting curls")
	check(bool(hot_reduced.danger) and float(hot_reduced.danger_opacity) > 0.0, "reduced Steam retains the warm scald boundary")
	equal(hot_reduced.fill_opacity, hot_normal.fill_opacity, "Reduced Steam preserves full coverage readability while removing motion")
	check(float(hot_normal.fill_opacity) >= 0.40 and float(hot_normal.fill_opacity) < 0.50, "Steam has a clear vapor bed without becoming opaque smoke")
	equal(hot_reduced.danger_opacity, hot_normal.danger_opacity, "Reduced Steam retains equally visible warm harm accents")
	var harmless := steam.duplicate()
	harmless.danger = false
	check(not bool(presenter._steam_region_style(harmless, 2000, false).danger), "a cosmetic hot palette never invents damage authority")
	var decaying := steam.duplicate()
	decaying.phase = "decaying"
	equal(presenter._steam_region_style(decaying, 1500, false).palette_phase, "decaying", "formation/decay authority is not overwritten by heat")
	check(float(presenter._steam_region_style(decaying, 1500, false).fill_opacity) < float(hot_normal.fill_opacity), "decaying vapor recedes visibly without changing expiry")


func _test_strength_scaled_projectile_size() -> void:
	var authored := 32.0
	var strengths := [12, 8, 3, 1]
	var sizes: Array[float] = []
	for remaining: int in strengths:
		sizes.append(Presenter.strength_scaled_size(authored, remaining, 12))
	for index: int in range(1, sizes.size()):
		check(sizes[index] < sizes[index - 1], "successive authoritative strength loss produces a strictly shrinking Heavy silhouette")
	check(is_equal_approx(sizes[0], authored), "full strength retains authored family size")
	check(is_equal_approx(sizes[1], authored * sqrt(8.0 / 12.0)), "strength target uses authored size times square-root ratio")
	check(is_equal_approx(Presenter.strength_scaled_size(authored, 1, 1000), 5.0), "positive extreme loss retains only the five-pixel readable floor")
	check(is_zero_approx(Presenter.strength_scaled_size(authored, 0, 12)), "exhausted strength has no projectile body")
	check(is_equal_approx(Presenter.collision_radius_px(84_000), 84.0), "collision outline radius uses exact fixed-to-world conversion")


func _test_projectile_size_cache() -> void:
	var cache := {}
	var identity := "owner/team/cast/wire/element/initial/radius"
	var full := Presenter.cache_projectile_size(cache, 71, identity, 20, 0.0, 32.0, false)
	check(is_equal_approx(full, 32.0), "new projectile begins at its current target without a presentation-only grow-in")
	var weakened_target := Presenter.strength_scaled_size(32.0, 8, 12)
	var change_tick := Presenter.cache_projectile_size(cache, 71, identity, 19, 1.0, weakened_target, false)
	check(is_equal_approx(change_tick, 32.0), "strength change begins from the currently displayed same-shot size")
	var start_tick := float((cache[71] as Dictionary).start_tick)
	var next_tick := Presenter.cache_projectile_size(cache, 71, identity, 18, 2.0, weakened_target, false)
	check(is_equal_approx(float((cache[71] as Dictionary).start_tick), start_tick), "same-shot repeated draw does not restart its transition")
	check(next_tick < full and next_tick > weakened_target, "same-shot shrink advances monotonically between endpoints")
	var settled := Presenter.cache_projectile_size(cache, 71, identity, 13, 7.0, weakened_target, false)
	check(is_equal_approx(settled, weakened_target), "normal presentation reaches its new target within six simulation ticks")
	var immediate := Presenter.cache_projectile_size(cache, 71, identity, 12, 8.0, 7.0, true)
	check(is_equal_approx(immediate, 7.0), "reduced mode applies the strength target immediately")


func _test_projectile_cache_reuse_and_bound() -> void:
	var cache := {}
	Presenter.cache_projectile_size(cache, 5, "first-identity", 5, 10.0, 20.0, false)
	var changed_identity := Presenter.cache_projectile_size(cache, 5, "second-identity", 4, 11.0, 12.0, false)
	check(is_equal_approx(changed_identity, 12.0), "reused entity ID with new immutable identity resets instead of inheriting an old shrink")
	var renewed_lifetime := Presenter.cache_projectile_size(cache, 5, "second-identity", 30, 12.0, 18.0, false)
	check(is_equal_approx(renewed_lifetime, 18.0), "same identity with a lifetime increase is treated as ID reuse")
	cache.clear()
	for entity_id: int in range(1, 131):
		Presenter.cache_projectile_size(cache, entity_id, "identity-%d" % entity_id, 1000, float(entity_id), 16.0, false)
	equal(cache.size(), 128, "per-shot presentation cache stays at its hard 128-entry bound")
	check(cache.has(130), "cache eviction retains the shot currently being drawn")
	Presenter.prune_projectile_cache(cache, 10_000.0)
	check(cache.is_empty(), "cache prunes entries after their observed projectile lifetime expires")


func _test_projectile_helpers_do_not_mutate_state() -> void:
	var shot := ProjectileState.new(81, 2, 3, 203, 3, Vector2i(10_000, 20_000), Vector2i(30_000, 0), 84_000, 9000, 40)
	shot.source_cast_id = 901
	shot.initial_strength = 12
	shot.remaining_strength = 3
	var canonical_before := shot.canonical_values()
	var initial_before := shot.initial_strength
	var remaining_before := shot.remaining_strength
	var pair := Presenter.projectile_strength_pair(shot)
	var identity := Presenter.projectile_cache_identity(shot)
	var cache := {}
	Presenter.cache_projectile_size(cache, shot.entity_id, identity, shot.lifetime_ticks, 12.0, Presenter.strength_scaled_size(32.0, pair.y, pair.x), false)
	equal(shot.canonical_values(), canonical_before, "presentation size/cache helpers do not mutate canonical projectile state")
	equal(shot.initial_strength, initial_before, "presentation helpers do not mutate initial hex strength")
	equal(shot.remaining_strength, remaining_before, "presentation helpers do not mutate remaining hex strength")


func _test_projectile_nose_facet() -> void:
	for family: String in ["rapid", "bolt", "heavy"]:
		for strength: Vector2i in [Vector2i(15, 15), Vector2i(15, 7), Vector2i(1000, 1), Vector2i(15, 0)]:
			var size := Presenter.strength_scaled_size(float(Presenter.FAMILY_SIZE[family]), strength.y, strength.x)
			for radius: float in [4.0, 9.6, 84.0]:
				for degrees: int in 360:
					var direction := Vector2.from_angle(deg_to_rad(float(degrees) + 0.25))
					var outer := Presenter.projectile_nose_facet(direction, radius, size)
					var inner := Presenter.projectile_nose_facet(direction, radius, size, true)
					var extent := minf(radius, size * 0.35) - 1.0
					if extent < 2.0:
						check(outer.is_empty() and inner.is_empty(), "exhausted or unreadably small current cores never gain a larger facet")
						continue
					equal(outer.size(), 3, "outer facet is one bounded triangle")
					equal(inner.size(), 3, "highlight is one bounded triangle")
					var inside := true
					for points: PackedVector2Array in [outer, inner]:
						for point: Vector2 in points:
							inside = inside and point.is_finite() and point.length() < radius and point.length() < size * 0.5 and point.dot(direction) > 0.0
					check(inside, "all 360-degree vertices stay strictly inside physical radius and current core, ahead of centre")
					check(outer[0].normalized().is_equal_approx(direction), "nose follows continuous travel without octant snapping")
					check(inner[0].normalized().is_equal_approx(direction), "highlight follows the identical continuous heading")
					check((outer[1] + outer[2]).is_equal_approx(direction * extent * 0.30), "rear corners remain symmetric around actual travel")
					var inset := true
					for point: Vector2 in inner:
						inset = inset and Geometry2D.is_point_in_polygon(point, outer)
					check(inset, "bright geometry remains wholly inside the dark facet")
	for direction: Vector2 in [Vector2.ZERO, Vector2(INF, 0), Vector2(0, NAN), Vector2(1.0e30, 1.0e30)]:
		for highlight: bool in [false, true]:
			check(Presenter.projectile_nose_facet(direction, 12.0, 24.0, highlight).is_empty(), "zero or invalid direction fails closed")
	for invalid: float in [0.0, -1.0, INF, NAN]:
		for highlight: bool in [false, true]:
			check(Presenter.projectile_nose_facet(Vector2.RIGHT, invalid, 24.0, highlight).is_empty(), "invalid physical radius fails closed")
			check(Presenter.projectile_nose_facet(Vector2.RIGHT, 12.0, invalid, highlight).is_empty(), "invalid current core size fails closed")
	var unit := Presenter.projectile_nose_facet(Vector2.RIGHT, 12.0, 24.0)
	equal(Presenter.projectile_nose_facet(Vector2(576_000, 0), 12.0, 24.0), unit, "speed magnitude cannot enlarge the direction facet")
	check(absf(Presenter.projectile_nose_facet(Vector2.from_angle(deg_to_rad(22.4)), 12.0, 24.0)[0].angle() - deg_to_rad(22.4)) < 0.00001, "direction remains truthful just before an atlas octant boundary")
	check(absf(Presenter.projectile_nose_facet(Vector2.from_angle(deg_to_rad(22.6)), 12.0, 24.0)[0].angle() - deg_to_rad(22.6)) < 0.00001, "direction remains truthful just after an atlas octant boundary")


func _test_projectile_nose_motion_and_modes() -> void:
	check(not Presenter.projectile_has_motion(null), "missing projectile cannot gain a direction marker")
	var shot := ProjectileState.new(82, 2, 3, 140, 3, Vector2i(10_000, 20_000), Vector2i.ZERO, 9600, 9000, 40)
	check(not Presenter.projectile_has_motion(shot), "stationary projectile suppresses the helper's default DOWN direction")
	shot.previous_x -= 1000
	check(Presenter.projectile_has_motion(shot), "actual displacement admits a direction when velocity is absent")
	equal(Presenter.ProjectileMotion.travel_direction(shot), Vector2.RIGHT, "displacement supplies the truthful fallback direction")
	shot.velocity_y = -1000
	equal(Presenter.ProjectileMotion.travel_direction(shot), Vector2.UP, "actual velocity wins over old displacement")
	shot.source_cast_id = 902
	shot.initial_strength = 15
	shot.remaining_strength = 7
	var canonical_before := shot.canonical_values()
	for element_wire: int in range(1, 9):
		shot.element_wire_id = element_wire
		canonical_before = shot.canonical_values()
		var normal_cache := {}
		var reduced_cache := {}
		var identity := Presenter.projectile_cache_identity(shot)
		Presenter.cache_projectile_size(normal_cache, shot.entity_id, identity, 41, 10.0, 32.0, false)
		Presenter.cache_projectile_size(reduced_cache, shot.entity_id, identity, 41, 10.0, 32.0, true)
		var target := Presenter.strength_scaled_size(32.0, shot.remaining_strength, shot.initial_strength)
		var normal_size := Presenter.cache_projectile_size(normal_cache, shot.entity_id, identity, 40, 11.0, target, false)
		var reduced_size := Presenter.cache_projectile_size(reduced_cache, shot.entity_id, identity, 40, 11.0, target, true)
		for highlight: bool in [false, true]:
			var normal := Presenter.projectile_nose_facet(Presenter.ProjectileMotion.travel_direction(shot), Presenter.collision_radius_px(shot.radius), minf(normal_size, target), highlight)
			var reduced := Presenter.projectile_nose_facet(Presenter.ProjectileMotion.travel_direction(shot), Presenter.collision_radius_px(shot.radius), minf(reduced_size, target), highlight)
			equal(normal, reduced, "normal/reduced share exact facet geometry even while the existing normal core shrinks")
		check(Presenter.projectile_has_motion(shot), "motion admission stays a read-only scalar query")
		equal(shot.canonical_values(), canonical_before, "direction facet sampling leaves canonical authority unchanged for every element")
		equal(shot.initial_strength, 15, "direction facet cannot change initial strength")
		equal(shot.remaining_strength, 7, "direction facet cannot change remaining strength")


func _spray_cue_fixture(start: Vector2 = Vector2(400, 400), direction: Vector2 = Vector2.RIGHT, length: float = 280.0) -> Dictionary:
	return {"source_wire_id": CombatTuning.TIDELINE_WIRE_ID, "kind": "spray", "event_type": "spray_fired",
		"start": start, "end": start + direction * length, "range": 280_000, "duration": 0.20, "remaining": 0.20}


# Frozen predecessor geometry: no candidate helper and no collision query.
func _old_spray_geometry(cue: Dictionary) -> Dictionary:
	var definition := CombatTuning.cast_definition(int(cue.source_wire_id))
	var start: Vector2 = cue.start
	var lane: Vector2 = cue.end - start
	var length := minf(lane.length(), float(cue.range) / 1000.0)
	var direction := lane.normalized()
	var side := direction.orthogonal()
	var half_angle := acos(sqrt(clampf(float(definition.cone_cosine_squared_per_million) / 1_000_000.0, 0.05, 1.0)))
	var endpoints := PackedVector2Array()
	for offset: float in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		endpoints.append(start + direction.rotated(half_angle * offset) * length)
	var brace_distance := minf(18.0, length * 0.22)
	var brace_center := start + direction * brace_distance
	var brace_half := minf(8.0, tan(half_angle) * brace_distance)
	return {"start": start, "endpoints": endpoints, "brace": PackedVector2Array([brace_center - side * brace_half, brace_center + side * brace_half])}


func _test_spray_cue_clear_geometry() -> void:
	var collision := CollisionWorld.new(2_000_000, 2_000_000)
	for degrees: int in [0, 23, 45, 90, 135, 180, 270, 337]:
		for length: float in [12.75, 80.0, 280.0]:
			var cue := _spray_cue_fixture(Vector2(700.25, 700.125), Vector2.from_angle(deg_to_rad(degrees)), length)
			var before := var_to_bytes(cue)
			var expected := _old_spray_geometry(cue)
			var prepared := Presenter.prepare_spray_cue(cue, collision)
			check(not prepared.is_empty(), "valid Spray prepares a finite fan")
			if prepared.is_empty(): continue
			equal(var_to_bytes(prepared.endpoints), var_to_bytes(expected.endpoints), "all-clear rays retain exact predecessor float geometry at every sampled angle/reach")
			equal(var_to_bytes(prepared.brace), var_to_bytes(expected.brace), "all-clear start brace retains exact predecessor geometry")
			equal(prepared.start, cue.start, "cue preparation never recenters the existing cast anchor")
			equal(var_to_bytes(cue), before, "preparation never changes source event, reach or finite lifetime")
	equal(Presenter.SPRAY_CUE_RAYS, [0, 1, 2, 3, 4], "normal mode keeps exactly the existing five rays")
	equal(Presenter.SPRAY_CUE_REDUCED_RAYS, [0, 2, 4], "reduced mode selects the same cached outer/center rays without another cover query")
	check(Presenter.prepare_spray_cue(_spray_cue_fixture(), null).is_empty(), "missing collision cannot claim a prepared clear fan")
	for patch: Dictionary in [{"source_wire_id": 101}, {"end": Vector2(400, 400)}, {"start": Vector2(INF, 400)}, {"end": Vector2(NAN, 0)}, {"end": Vector2(1000, 400), "range": 600_000}]:
		var invalid := _spray_cue_fixture()
		invalid.merge(patch, true)
		check(Presenter.prepare_spray_cue(invalid, collision).is_empty(), "invalid/non-Spray/unbounded admission cannot produce prepared fan geometry")


func _test_spray_cue_cover_and_ownership() -> void:
	var collision := CollisionWorld.new(2_000_000, 2_000_000)
	var wall := CollisionWorld.Obstacle.new(7, 480_000, 340_000, 500_000, 365_000)
	collision.add_obstacle(wall)
	var cue := _spray_cue_fixture()
	var old := _old_spray_geometry(cue)
	var source_before := var_to_bytes(cue)
	var wall_before := [wall.minimum_x, wall.minimum_y, wall.maximum_x, wall.maximum_y, collision.width, collision.height]
	var prepared := Presenter.prepare_spray_cue(cue, collision)
	check(not prepared.is_empty(), "side-wall cue prepares")
	if prepared.is_empty(): return
	var endpoints: PackedVector2Array = prepared.endpoints
	check(endpoints[0].distance_to(cue.start) < old.endpoints[0].distance_to(cue.start), "narrow side wall stops the outward ray before hidden space")
	equal(endpoints[2], old.endpoints[2], "side wall does not shorten the clear center ray")
	equal(endpoints[4], old.endpoints[4], "opposite clear side retains exact authored reach")
	var requested := Vector2i((old.endpoints[0] * 1000.0).round()) - Vector2i(400_000, 400_000)
	var definition := CombatTuning.cast_definition(CombatTuning.TIDELINE_WIRE_ID)
	var clear := CombatSystem.spray_clear_endpoint(Vector2i(400_000, 400_000), SimCommand._normalized_direction(requested.x, requested.y), SimCommand._integer_square_root(requested.length_squared()), int(definition.radius), collision)
	equal(endpoints[0], Vector2(clear) / 1000.0, "clipped endpoint is the shared analytic target-ray clearance result")
	equal(var_to_bytes(cue), source_before, "side-wall preparation leaves event-owned values unchanged")
	equal([wall.minimum_x, wall.minimum_y, wall.maximum_x, wall.maximum_y, collision.width, collision.height], wall_before, "presentation does not modify authoritative collision geometry")
	# Exercise the actual accepted target rule: the side target is protected,
	# while the center target is damaged by this same cone and collision world.
	var owner := PlayerState.new(1)
	owner.position_x = 400_000
	owner.position_y = 400_000
	var side_target := PlayerState.new(2)
	side_target.team_id = 2
	side_target.position_x = 650_000
	side_target.position_y = 280_000
	var center_target := PlayerState.new(3)
	center_target.team_id = 2
	center_target.position_x = 650_000
	center_target.position_y = 400_000
	var actors: Array[PlayerState] = [owner, side_target, center_target]
	var events: Array[Dictionary] = []
	CombatSystem._resolve_spray(owner, CombatTuning.TIDELINE_WIRE_ID, definition, Vector2i(400_000, 400_000), Vector2i(1000, 0), Vector2i(680_000, 400_000), actors, SimConfig.new(), collision, events)
	equal(side_target.health, side_target.health_maximum, "actual Spray target resolution refuses damage behind the side wall")
	equal(center_target.health, center_target.health_maximum - int(definition.damage), "same accepted Spray still reaches the clear center target")
	var retained := var_to_bytes(prepared)
	cue.start = Vector2(30, 30)
	cue.end = Vector2(31, 30)
	wall.minimum_y = 900_000
	wall.maximum_y = 925_000
	equal(var_to_bytes(prepared), retained, "later source/cover mutations cannot move a previously admitted finite fan")
	var fresh := Presenter.prepare_spray_cue(_spray_cue_fixture(), collision)
	equal(fresh.endpoints, old.endpoints, "new admission reads newly changed cover instead of a stale global cache")
	fresh.endpoints[0] = Vector2.ZERO
	equal(var_to_bytes(prepared), retained, "separate admissions own detached endpoint buffers")


func _test_spray_cue_collision_policy() -> void:
	var cue := _spray_cue_fixture()
	var definition := CombatTuning.cast_definition(CombatTuning.TIDELINE_WIRE_ID)
	var physical_radius := int(definition.radius)
	var tangent_center := Vector2i(480_000 - physical_radius, 400_000)
	var blocked := CollisionWorld.new(2_000_000, 2_000_000)
	blocked.add_obstacle(CollisionWorld.Obstacle.new(1, 405_000, 300_000, 450_000, 500_000))
	var fully_blocked := Presenter.prepare_spray_cue(cue, blocked)
	for endpoint: Vector2 in fully_blocked.endpoints:
		equal(endpoint, cue.start, "initial physical contact leaves no false outgoing ray")
	equal(fully_blocked.brace, PackedVector2Array([cue.start, cue.start]), "fully blocked start does not retain a brace through cover")
	var escaping := CollisionWorld.new(2_000_000, 2_000_000)
	escaping.add_obstacle(CollisionWorld.Obstacle.new(2, 390_000, 390_000, 401_000, 410_000))
	var exiting_cue := _spray_cue_fixture(Vector2(405.5, 400))
	check(not escaping.can_occupy(Vector2i(405_500, 400_000), int(definition.radius)), "escape fixture begins within the clearance envelope")
	for endpoint: Vector2 in Presenter.prepare_spray_cue(exiting_cue, escaping).endpoints:
		equal(endpoint, exiting_cue.start, "initial physical overlap cannot tunnel out via the old two-pixel sampling step")
	# Continuous projectile contact is closed when the ray reaches a wall at
	# positive time. Only an already touching start may slide/separate. The old
	# sampled beam helper's strict occupancy test is not the Spray authority.
	for gap: int in [0, 1]:
		var tangent := CollisionWorld.new(2_000_000, 2_000_000)
		tangent.add_obstacle(CollisionWorld.Obstacle.new(3, 480_000, 400_000 + physical_radius + gap, 500_000, 435_000 + physical_radius + gap))
		var hit := ContinuousContact.wall_contact(Vector2i(400_000, 400_000), Vector2i(680_000, 400_000), int(definition.radius), tangent)
		equal(hit.is_empty(), gap == 1, "positive-time grazing is closed contact; one fixed unit of clearance is a genuine miss")
		if gap == 0 and not hit.is_empty():
			equal(hit.center, tangent_center, "grazing contact uses the live full-radius physical center")
			check(float(hit.fraction) > 0.0, "grazing fixture enters later rather than starting on the separating/sliding exemption")
		equal(Presenter.prepare_spray_cue(cue, tangent).endpoints[2], Vector2(tangent_center) / SimConfig.FIXED_SCALE if gap == 0 else cue.end, "prepared Spray matches physical grazing and one-unit-clearance outcomes")
		var owner := PlayerState.new(1)
		owner.team_id = 1
		owner.position_x = 400_000
		owner.position_y = 400_000
		var target := PlayerState.new(2)
		target.team_id = 2
		target.position_x = 650_000
		target.position_y = 400_000
		target.spawn_protection_ticks = 0
		check(tangent.can_occupy(Vector2i(owner.position_x, owner.position_y), owner.radius) and tangent.can_occupy(Vector2i(target.position_x, target.position_y), target.radius), "grazing target control uses legally positioned actors")
		var actors: Array[PlayerState] = [owner, target]
		var events: Array[Dictionary] = []
		CombatSystem._resolve_spray(owner, CombatTuning.TIDELINE_WIRE_ID, definition, Vector2i(400_000, 400_000), Vector2i(1000, 0), Vector2i(680_000, 400_000), actors, SimConfig.new(), tangent, events)
		equal(target.health_maximum - target.health, 0 if gap == 0 else int(definition.damage), "actual Spray actor ray is blocked at closed tangency and hits with one-unit positive clearance")
		if gap == 0:
			check(ContinuousContact.wall_contact(Vector2i(490_000, 400_000), Vector2i(680_000, 400_000), int(definition.radius), tangent).is_empty(), "existing initial exact-tangent sliding remains clear")
			check(ContinuousContact.wall_contact(tangent_center, Vector2i(400_000, 400_000), physical_radius, tangent).is_empty(), "existing initial exact-tangent separation remains clear")
	var grid_origin := Vector2i(500_000, 400_000)
	var topology := HexGrid.disk(Vector2i.ZERO, 2)
	var cover := HexCollisionWorld.new(CollisionWorld.new(2_000_000, 2_000_000))
	check(cover._configure_hex_sets(grid_origin, topology, [], [Vector2i.ZERO]), "fixture admits shot cover without a movement-solid cell")
	check(not ContinuousContact.wall_contact(Vector2i(400_000, 400_000), Vector2i(680_000, 400_000), int(definition.radius), cover).is_empty(), "projectile contact would stop at this later-cover policy")
	check(Presenter.prepare_spray_cue(cue, cover).endpoints[2].x < cue.end.x, "Spray actor rays and cues share all shot-cover recipes, including non-movement-solid cover")
	check(cover._configure_hex_sets(grid_origin, topology, [Vector2i.ZERO], [Vector2i.ZERO]), "same fixture now admits movement-solid Rampart")
	check(Presenter.prepare_spray_cue(cue, cover).endpoints[2].distance_to(cue.start) < cue.end.distance_to(cue.start), "actual movement-solid Rampart stops the Spray cue like target rays")
	var edge := CollisionWorld.new(500_000, 800_000)
	equal(Presenter.prepare_spray_cue(cue, edge).endpoints[2], Vector2(500_000 - physical_radius, 400_000) / SimConfig.FIXED_SCALE, "world edge uses the live authored physical clearance exactly")


func _test_spray_cue_center_pillar() -> void:
	var collision := CollisionWorld.new(2_000_000, 2_000_000)
	collision.add_obstacle(CollisionWorld.Obstacle.new(90, 480_000, 390_000, 490_000, 410_000))
	var cue := _spray_cue_fixture()
	var prepared := Presenter.prepare_spray_cue(cue, collision)
	var physical_radius := int(CombatTuning.cast_definition(CombatTuning.TIDELINE_WIRE_ID).radius)
	var pillar_center := Vector2(480_000 - physical_radius, 400_000) / SimConfig.FIXED_SCALE
	var full := _old_spray_geometry(cue)
	equal(prepared.endpoints[0], full.endpoints[0], "clear upper flank retains authored reach around a center pillar")
	equal(prepared.endpoints[4], full.endpoints[4], "clear lower flank retains authored reach around a center pillar")
	equal(prepared.endpoints[2], pillar_center, "blocked center spoke stops at exact live physical-radius pillar contact")
	var reduced_endpoints := PackedVector2Array()
	for index: int in Presenter.SPRAY_CUE_REDUCED_RAYS: reduced_endpoints.append(prepared.endpoints[index])
	equal(reduced_endpoints, PackedVector2Array([full.endpoints[0], pillar_center, full.endpoints[4]]), "reduced selection keeps both clear flanks and the exact blocked center")
	# A one-unit thin wall located between old two-pixel samples still clips.
	var thin := CollisionWorld.new(2_000_000, 2_000_000)
	thin.add_obstacle(CollisionWorld.Obstacle.new(91, 481_001, 350_000, 481_002, 450_000))
	equal(CombatSystem.spray_clear_endpoint(Vector2i(400_000, 400_000), Vector2i(1000, 0), 280_000, 0, thin), Vector2i(481_001, 400_000), "analytic Spray cannot step across a one-unit wall")


func _test_resident_geometry_cache() -> void:
	var presenter := Presenter.new()
	var first := GeometryCourt.new()
	var second := GeometryCourt.new()
	second.origin = Vector2i(288000, 0)
	check(presenter._prepare_court(first), "first resident geometry prepares")
	var first_vertices: PackedVector2Array = presenter._vertices[Vector2i.ZERO].duplicate()
	check(presenter._prepare_court(second), "second independent resident prepares")
	var second_vertices: PackedVector2Array = presenter._vertices[Vector2i.ZERO].duplicate()
	for index: int in 12:
		check(presenter._prepare_court(first), "alternating resident one remains available")
		equal(presenter._vertices[Vector2i.ZERO], first_vertices, "resident one geometry survives another court's preparation")
		check(presenter._prepare_court(second), "alternating resident two remains available")
		equal(presenter._vertices[Vector2i.ZERO], second_vertices, "resident two keeps its distinct origin")
	equal(presenter.geometry_cache_stats().builds, 2, "24 alternating warm preparations rebuild neither resident")
	equal(presenter.geometry_cache_stats().hits, 24, "each alternating warm court uses its own geometry")
	first.origin += Vector2i(1000, 2000)
	check(presenter._prepare_court(first), "direct origin change is observed without revision bump")
	equal(presenter._centers[Vector2i.ZERO], Vector2(1, 2), "cached geometry never keeps a previous origin")
	equal(presenter.geometry_cache_stats().builds, 3, "origin change causes exactly one rebuild")
	first.cells.erase(Vector2i.ZERO)
	first.cells[Vector2i.RIGHT] = {}
	check(presenter._prepare_court(first), "same-count direct membership change is observed")
	check(presenter._cell_set.has(Vector2i.RIGHT) and not presenter._cell_set.has(Vector2i.ZERO), "cache checks keys, not just count or revision")
	first.render_revision += 1
	check(presenter._prepare_court(first), "explicit topology revision invalidates resident")
	equal(presenter.geometry_cache_stats().builds, 5, "membership and explicit revision each rebuild once")
	var residents: Array[RefCounted] = []
	for index: int in 70:
		var court := GeometryCourt.new()
		residents.append(court)
		check(presenter._prepare_court(court), "bounded resident accepts another small court")
		check(int(presenter.geometry_cache_stats().courts) <= 64, "court cache never retains more than64 courts")
		check(int(presenter.geometry_cache_stats().cells) <= 8192, "court cache also bounds total cell geometry")
	equal(presenter.geometry_cache_stats().courts, 64, "LRU evicts oldest residents at the exact court limit")
	# Force the independent cell limit with many valid grid cells in one court.
	var large := GeometryCourt.new()
	large.cells.clear()
	for cell: Vector2i in Presenter.HexGrid.disk(Vector2i.ZERO, 52): large.cells[cell] = {}
	check(large.cells.size() > 8192, "oversized geometry fixture actually crosses the retained-cell limit")
	var retained := presenter.geometry_cache_stats().duplicate()
	check(presenter._prepare_court(large), "large standalone court still prepares rather than disappearing")
	equal(presenter._cells.size(), large.cells.size(), "oversized public draw retains every eligible cell")
	equal(presenter.geometry_cache_stats().cells, retained.cells, "oversized court cannot grow retained geometry memory")
	check(not presenter._court_geometry.has(large.get_instance_id()), "oversized court is not retained as another resident")
	var temporary := GeometryCourt.new()
	var reference: WeakRef = weakref(temporary)
	check(presenter._prepare_court(temporary), "temporary resident prepares")
	temporary = null
	check(reference.get_ref() == null, "geometry cache never retains court authority or its lifetime")
	var stats := presenter.geometry_cache_stats()
	stats.cells = -100
	check(int(presenter.geometry_cache_stats().cells) >= 0, "diagnostic counters are detached from cache")
	check(not presenter.configure(null), "failed reconfiguration clears prior renderer state")
	equal(presenter.geometry_cache_stats(), {"courts":0,"cells":0,"builds":0,"hits":0}, "configuration resets all retained geometry and diagnostics")


func _test_view_culling_contract() -> void:
	var presenter := ViewProbe.new()
	var court := GeometryCourt.new()
	court.cells.clear()
	for cell: Vector2i in Presenter.HexGrid.disk(Vector2i.ZERO, 8): court.cells[cell] = {}
	var before := var_to_bytes([court.cells, court.origin, court.render_revision])
	var view := Rect2(-1, -1, 2, 2)
	check(presenter.draw_ground_in_view(null, court, 0.0, false, true, view), "additive culling API still dispatches the original overridable draw method")
	var expected: Array[Vector2i] = []
	for cell: Vector2i in court.cells:
		var center := Vector2(Presenter.HexGrid.center(cell)) / 1000.0
		if absf(center.x) <= 65.0 and absf(center.y) <= 65.0: expected.append(cell)
	expected.sort_custom(func(a: Vector2i,b: Vector2i)->bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	equal(presenter.selected, expected, "viewport conservatively keeps full cells inside exact64px neighbor halo")
	check(presenter.selected.size() > 1 and presenter.selected.size() < court.cells.size(), "view culling retains neighbors while excluding genuinely distant cells")
	for cell: Vector2i in presenter.selected:
		var actual: PackedVector2Array = presenter._vertices[cell]
		var complete := PackedVector2Array()
		for point: Vector2i in Presenter.HexGrid.vertices(cell): complete.append(Vector2(point) / 1000.0)
		equal(actual, complete, "viewport admission never clips or changes authoritative hex coverage")
	equal(presenter._visible_rect, Rect2(), "scoped view does not contaminate a later generic draw")
	check(presenter._prepare_court(court), "uncropped public path still available after view draw")
	equal(presenter._cells.size(), court.cells.size(), "legacy caller still prepares its complete court")
	for invalid: Rect2 in [Rect2(), Rect2(0,0,-1,1), Rect2(Vector2(INF,0), Vector2.ONE), Rect2(Vector2.ZERO,Vector2(NAN,1))]:
		check(not presenter.draw_ground_in_view(null, court, 0.0, false, true, invalid), "invalid viewport refuses without inventing a selected region")
	equal(var_to_bytes([court.cells, court.origin, court.render_revision]), before, "culling changes no authority membership, origin or revision")


func _test_exact_outline_batches() -> void:
	var presenter := OutlineProbe.new()
	var region := {"material": "convergence", "footprint_id": 17, "phase": "active", "danger": true,
		"intensity": 900, "owner_key": [4, 7], "expiry_tick": 720, "decay_tick": 650}
	# Each mask is tested in both windings and at a fractional distant origin.
	# The independent expected path below repeats the original inward strip
	# calculation, triangle order and fresh edge decisions, never batch geometry.
	for offset: Vector2 in [Vector2.ZERO, Vector2(-240.125, 180.375)]:
		var fixed := PackedVector2Array()
		var display := PackedVector2Array()
		for point: Vector2i in HexGrid.vertices(Vector2i.ZERO):
			fixed.append(Vector2(point) + offset * 1000.0)
			display.append((Vector2(point) + offset * 1000.0) / 1000.0)
		for reversed: bool in [false, true]:
			if reversed:
				fixed.reverse()
				display.reverse()
			region.fixed_polygon = fixed
			region.polygon = display
			for width: float in [1.0, 2.0, 2.5, 3.0, 0.75, 0.0]:
				for mask: int in 64:
					var counts := {}
					for edge: int in 6:
						counts[presenter._region_edge_key(region, fixed[edge], fixed[(edge + 1) % 6])] = 1 if mask & (1 << edge) else 2
					var expected := _old_outline_points(region, counts, width)
					presenter.submitted.clear()
					var ink := Color(0.25, 0.50, 0.75, 0.31)
					presenter._draw_region_outline(null, region, counts, ink, width)
					equal(presenter.submitted.size(), 0 if expected.is_empty() else 1, "one region submits at most one boundary command; hidden or zero-width edges submit none")
					if not expected.is_empty():
						equal(var_to_bytes(presenter.submitted[0].points), var_to_bytes(expected), "batch retains the exact ordered old triangles for every six-edge mask and stroke width")
						equal(presenter.submitted[0].color, ink, "batch retains the caller's exact alpha and RGB")
					check(presenter._outline_batches.size() <= Presenter.OUTLINE_BATCH_LIMIT, "all masks remain within the independent 512-batch storage cap")
	# Keep a warm geometry but change each live seam input; counts must be read
	# again, not memoized by polygon or render_revision. Old counts suppress all
	# six edges; new identity makes all six visible immediately.
	for material: String in ["steam", "convergence", "cinderveil"]:
		region.material = material
		var counts := {}
		for edge: int in 6:
			counts[presenter._region_edge_key(region, region.fixed_polygon[edge], region.fixed_polygon[(edge + 1) % 6])] = 2
		for field: String in ["phase", "danger", "owner_key", "decay_tick", "intensity", "expiry_tick"]:
			var changed := region.duplicate(true)
			match field:
				"phase": changed.phase = "decaying"
				"danger": changed.danger = false
				"owner_key": changed.owner_key = [9, 10]
				_: changed[field] = int(changed[field]) + 1
			presenter.submitted.clear()
			presenter._draw_region_outline(null, changed, counts, Color.WHITE, 2.5)
			var expected := _old_outline_points(changed, counts, 2.5)
			equal(presenter.submitted.size(), 0 if expected.is_empty() else 1, "fresh phase/danger/source/fuse/lifetime fields decide exposed edges even with a warm batch")
			if not expected.is_empty(): equal(presenter.submitted[0].points, expected, "dynamic boundary remains exactly the original boundary oracle")
	# More distinct geometry than the cap: no travel-sized retained allocation.
	for index: int in Presenter.OUTLINE_BATCH_LIMIT + 17:
		var polygon: PackedVector2Array = region.polygon.duplicate()
		polygon[0] += Vector2(float(index) / 1024.0, 0)
		presenter._outline_batch_points(polygon, 2.0, 63)
		check(presenter._outline_batches.size() <= Presenter.OUTLINE_BATCH_LIMIT, "direct fractional geometry changes and eviction remain bounded")
	check(not presenter.configure(null), "failed reconfiguration remains fail-closed")
	check(presenter._outline_batches.is_empty() and presenter._outline_batch_order.is_empty(), "reconfiguration retires all packed outline data")


func _old_outline_points(region: Dictionary, counts: Dictionary, width: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var polygon: PackedVector2Array = region.polygon
	var fixed: PackedVector2Array = region.fixed_polygon
	# Preserved area-weighted centroid from the preceding renderer. A vertex
	# average is not an independent exact oracle for fractional float geometry.
	var origin := polygon[0]
	var weighted := Vector2.ZERO
	var area := 0.0
	for index: int in range(1, polygon.size() - 1):
		var a := polygon[index] - origin
		var b := polygon[index + 1] - origin
		var cross := a.cross(b)
		weighted += (a + b) * cross / 3.0
		area += cross
	var center := origin + weighted / area
	var presenter := Presenter.new()
	for edge: int in polygon.size():
		var key := presenter._region_edge_key(region, fixed[edge], fixed[(edge + 1) % fixed.size()])
		if int(counts.get(key, 0)) > 1 or not is_finite(width) or width <= 0.0: continue
		var first := polygon[edge]
		var second := polygon[(edge + 1) % polygon.size()]
		var first_ratio := clampf(width / maxf(1.0, first.distance_to(center)), 0.0, 0.48)
		var second_ratio := clampf(width / maxf(1.0, second.distance_to(center)), 0.0, 0.48)
		var strip := PackedVector2Array([first, second, second.lerp(center, second_ratio), first.lerp(center, first_ratio)])
		for indices: Vector3i in [Vector3i(0, 1, 2), Vector3i(0, 2, 3)]:
			var a := strip[indices.x]
			var b := strip[indices.y]
			var c := strip[indices.z]
			if absf((b - a).cross(c - a)) > 0.0001:
				points.append(a)
				points.append(b)
				points.append(c)
	return points


func _test_resident_outline_meshes() -> void:
	var presenter := Presenter.new()
	var polygon := PackedVector2Array()
	for point: Vector2i in HexGrid.vertices(Vector2i.ZERO): polygon.append(Vector2(point) / 1000.0)
	var points := presenter._outline_batch_points(polygon, 2.5, 63)
	var mesh: ArrayMesh = presenter._resident_outline_mesh(points)
	check(mesh != null, "full outline has a resident exact mesh")
	if mesh == null: return
	equal(mesh.get_surface_count(), 1, "outline is one untextured triangle surface")
	equal(mesh.surface_get_primitive_type(0), Mesh.PRIMITIVE_TRIANGLES, "native outline does not join triangles as a strip or polygon")
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	equal(vertices.size(), points.size(), "every original triangle vertex is retained")
	for index: int in points.size(): equal(vertices[index], Vector3(points[index].x, points[index].y, 0), "resident native vertices preserve exact position, order and zero depth")
	for repeat: int in 30:
		check(presenter._resident_outline_mesh(points) == mesh, "warm animation/phase-color frames reuse the exact resource")
	equal(presenter.outline_cache_stats().uploads, 1, "warm outline never recreates vertex buffers")
	equal(presenter.outline_cache_stats().hits, 30, "warm reuse is counted independently from upload")
	# Geometry and source decisions live outside the resource. Public packed
	# input mutation must create another resource rather than poison the old RID.
	var changed := points.duplicate()
	changed[0] += Vector2(0.125, 0.25)
	var altered: ArrayMesh = presenter._resident_outline_mesh(changed)
	check(altered != null and altered != mesh, "subpixel geometry changes do not reuse the wrong mesh")
	equal(mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], vertices, "original resource remains untouched for earlier retained commands")
	for index: int in Presenter.OUTLINE_BATCH_LIMIT:
		var distinct := points.duplicate()
		for vertex: int in distinct.size(): distinct[vertex] += Vector2(float(index + 1), 0)
		presenter._resident_outline_mesh(distinct)
	check(presenter.outline_cache_stats().meshes == Presenter.OUTLINE_BATCH_LIMIT, "resident resources stop at512 without evicting queued RIDs")
	check(presenter._resident_outline_mesh(points) == mesh, "old in-flight resource survives full residency and later geometry")
	var overflow := points.duplicate()
	for vertex: int in overflow.size(): overflow[vertex] += Vector2(9000, 9000)
	check(presenter._resident_outline_mesh(overflow) == null, "overflow selects exact triangle fallback rather than an unbounded resource")
	var canvas := Node2D.new()
	presenter._submit_outline(canvas, overflow, Color(0.4, 0.6, 0.8, 0.25))
	equal(presenter.outline_cache_stats().fallbacks, 1, "overflow submits existing complete triangles; it never drops a hazard boundary")
	equal(presenter.outline_cache_stats().meshes, Presenter.OUTLINE_BATCH_LIMIT, "overflow rendering allocates no extra retained mesh")
	canvas.free()
	# Warm every newer retained path before reset so a missing clear cannot pass
	# merely because that cache/counter was still at its initial zero value.
	var fixed := PackedVector2Array()
	for point: Vector2i in HexGrid.vertices(Vector2i.ZERO): fixed.append(Vector2(point))
	var region := {"material": "conflagration", "footprint_id": 1, "phase": "active", "danger": true,
		"intensity": 1000, "owner_key": 1, "expiry_tick": 720, "decay_tick": 650,
		"fixed_polygon": fixed, "polygon": polygon}
	var grouped := {Vector2i.ZERO: [region]}
	presenter._region_edge_counts(grouped)
	var counts: Dictionary = presenter._region_edge_counts(grouped)
	equal(presenter._region_exposed_edges(region, counts), 63, "reset fixture exercises a retained six-edge mask")
	var layout: Dictionary = presenter._region_layout(polygon)
	presenter._fire_phase_mark(polygon, "cooling", false, layout.center, float(layout.clearance) - 2.5)
	var expected_reset := {
		"batches": 0, "meshes": 0, "uploads": 0, "hits": 0, "fallbacks": 0,
		"topologies": 0, "topology_hits": 0, "topology_builds": 0,
		"edge_mask_hits": 0, "edge_mask_builds": 0, "phase_marks": 0,
	}
	var populated: Dictionary = presenter.outline_cache_stats()
	for counter: String in expected_reset:
		check(int(populated[counter]) > 0, "reset fixture first populates " + counter)
	check(not presenter.configure(null), "failed setup remains fail-closed after resident drawing")
	equal(presenter.outline_cache_stats(), expected_reset, "setup clears every geometry/resource/counter without retaining another content generation")
	check(presenter._boundary_topology_order.is_empty() and presenter._boundary_mask_counts.is_empty() and presenter._boundary_masks.is_empty(), "setup also releases topology eviction order and active immutable count/mask witnesses")
