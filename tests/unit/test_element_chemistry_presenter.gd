extends FluxTestSuite

const Presenter = preload("res://src/presentation/element_chemistry_presenter.gd")
const Chemistry = preload("res://src/sim/chemistry/element_chemistry_system.gd")
const Reaction = preload("res://src/sim/chemistry/element_reaction_state.gd")
const Deposit = preload("res://src/sim/chemistry/element_deposit_state.gd")
const Reticle = preload("res://src/presentation/aim_reticle_presenter.gd")
const Capacitor = preload("res://src/sim/chemistry/capacitor_field_policy.gd")

func run() -> int:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "chemistry visual language loads")
	var presenter := Presenter.new()
	check(not presenter.configure(null), "chemistry rendering refuses missing visual tokens")
	check(presenter.configure(language), "chemistry rendering uses canonical element palette")
	var identities := {}
	for wire: int in range(301,337):
		var recipe := Chemistry.recipe(wire)
		var state := Reaction.new()
		state.recipe_wire_id = wire
		state.position_x = 123000
		state.position_y = 234000
		state.endpoint_x = 323000
		state.endpoint_y = 234000
		state.direction_x = 1000
		state.radius = int(recipe.radius) / 2
		state.length = int(recipe.length) / 2
		state.created_tick = 10
		state.active_tick = 30
		state.decay_tick = 300
		state.expiry_tick = 360
		var before := state.canonical_values()
		var g := Presenter.geometry(state,recipe)
		equal(g.position,Vector2(123,234),"recipe %d uses actual moving authority origin" % wire)
		equal(g.endpoint,Vector2(323,234),"recipe %d uses authoritative endpoint" % wire)
		equal(g.radius,float(state.radius)/1000.0,"recipe %d uses current grown radius, not final authored radius" % wire)
		equal(g.length,float(state.length)/1000.0,"recipe %d uses actual length" % wire)
		check(not identities.has(g.id),"recipe %d has distinct rendered identity" % wire)
		identities[g.id] = true
		equal(Presenter.phase_at(state,9),"expired","unborn matter is not shown")
		equal(Presenter.phase_at(state,10),"forming","formation is explicit")
		equal(Presenter.phase_at(state,30),"active","active phase starts at authority tick")
		equal(Presenter.phase_at(state,300),"decaying","decay begins at authority tick")
		equal(Presenter.phase_at(state,360),"expired","expired matter is never shown")
		equal(Presenter.phase_opacity(state,360),0.0,"expired opacity is exactly zero")
		check(Presenter.phase_opacity(state,330) < Presenter.phase_opacity(state,300),"decay visibly reduces opacity")
		check(not presenter.draw_reaction(null,state,recipe,30),"null canvas cannot accidentally mutate chemistry")
		if wire == 303:
			for reduced: bool in [false, true]:
				var mud := presenter.reaction_model(state, recipe, 30, reduced)
				equal(String(mud.material_asset_id), PixelMagicLibrary.element_asset_id(1, "deposit_active", reduced), "Mud reuses native soil instead of Flood waves")
				equal(String(mud.effect_label), "MUD · GROUND SLOW", "active Mud explains its actual effect")
				check(presenter.reaction_model(state, recipe, 360, reduced).is_empty(), "Mud label expires with authority")
		equal(state.canonical_values(),before,"presentation queries cannot change game state")
		check(Presenter.geometry(state,Chemistry.recipe(301 if wire!=301 else 302)).is_empty(),"mismatched recipe fails closed")
	equal(identities.size(),36,"all thirty-six reactions are represented")
	check("front" in Presenter.LINE_SHAPES,"Magma uses the authority corridor, not a perpendicular invented ridge")
	var ring := Reaction.new()
	ring.recipe_wire_id = 309
	ring.radius = 72000
	ring.length = 24000
	equal(Presenter.geometry(ring,Chemistry.recipe(309)).inner_radius,24.0,"Conflagration safe hole uses inner radius, not thickness subtraction")
	var hail := Reaction.new()
	hail.position_x = 10000
	hail.endpoint_x = 110000
	hail.length = 100000
	hail.active_tick = 20
	equal(Presenter.hail_position(hail,20),Vector2(10,0),"single hail pulse starts at authoritative activation")
	equal(Presenter.hail_position(hail,47),Vector2(60,0),"single hail pulse reaches halfway after225ms")
	equal(Presenter.hail_position(hail,74),Vector2(10,0),"single hail pulse restarts exactly every450ms")
	for wire: int in range(1,9):
		var deposit := Deposit.new()
		deposit.element_wire_id = wire
		check(not presenter.draw_deposit(null,deposit,0),"deposit draw refuses missing canvas")
	for direction: Vector2 in [Vector2.RIGHT,Vector2.DOWN,Vector2.ZERO]:
		var lines := Reticle.segments(Vector2(640,360),direction)
		equal(lines.size(),5,"reticle preserves a four-arm open centre and direction tail")
		for line: PackedVector2Array in lines:
			for p: Vector2 in line:
				check(p.distance_to(Vector2(640,360)) >= 4,"reticle leaves target centre unobscured")
	check(Reticle.segments(Vector2(INF,0)).is_empty(),"reticle rejects invalid screen location")
	_test_pixel_phases_and_native_cells(presenter)
	_test_deposit_material_readability(presenter)
	_test_ingredient_roles(presenter)
	_test_compact_native_material(presenter)
	_test_concealment_windows(presenter)
	_test_live_links_and_worldbone(presenter)
	_test_budget_culling_and_information(presenter)
	_test_thin_material_paths(presenter)
	_test_material_only_footprints(presenter)
	_test_large_coordinate_triangulation(presenter)
	_test_rampart_footprint(presenter)
	_test_capacitor_cues(presenter)
	var empty_library := PixelMagicLibrary.new()
	check(not Presenter.new().configure(language, empty_library), "invalid pixel library cannot silently fall back to old chemistry visuals")
	return finish("element-chemistry-presenter")


func _test_capacitor_cues(presenter: ElementChemistryPresenter) -> void:
	var config := SimConfig.new(120)
	var state := _state(Capacitor.RECIPE_WIRE)
	var recipe := Chemistry.recipe(Capacitor.RECIPE_WIRE)
	var before := state.canonical_values()
	var warning_tick := state.decay_tick - Capacitor.FINAL_WARNING_TICKS
	var ticks := [state.created_tick, state.active_tick, state.active_tick + 4, warning_tick - 1, warning_tick, state.decay_tick - 2, state.decay_tick - 1, state.decay_tick]
	var expected := ["formation", "acceleration", "acceleration", "acceleration", "final_warning", "final_warning", "discharge", "decay"]
	var stage_geometry: Dictionary = {}
	for reduced: bool in [false, true]:
		var mode_geometry: Dictionary = {}
		presenter.begin_frame(config, null, Rect2(), [], reduced)
		for index: int in range(ticks.size()):
			var model := presenter.reaction_model(state, recipe, ticks[index], reduced)
			check(not model.is_empty() and model.has("capacitor_cue"), "Capacitor keeps a phase cue in every finite normal/reduced state")
			if model.is_empty() or not model.has("capacitor_cue"):
				continue
			var cue: Dictionary = model.capacitor_cue
			equal(cue.stage, expected[index], "Capacitor cue follows formation, acceleration, final warning, discharge and harmless decay ticks")
			equal(cue.warning_tick, warning_tick, "final warning derives from the actual decay tick minus60")
			equal(cue.discharge_tick, state.decay_tick - 1, "release mark exists only on the exact last active tick")
			check(not cue.parts.is_empty() and cue.parts.size() <= Presenter.CAPACITOR_CUE_PART_LIMIT, "Capacitor cue is present and hard-bounded under load")
			for part: Dictionary in cue.parts:
				var points: PackedVector2Array = part.points
				var indices: PackedInt32Array = part.indices
				check(not indices.is_empty() and indices.size() % 3 == 0, "every clipped cue part submits explicit valid triangles")
				var center := Vector2.ZERO
				for point: Vector2 in points:
					center += point
				center /= float(points.size())
				check(PixelEffectGeometry.contains_point(model.mask.polygons, center), "every chevron/bar remains clipped to the authority footprint")
			if expected[index] not in mode_geometry:
				mode_geometry[expected[index]] = str(cue.parts)
			elif index not in [2, 3, 5]:
				equal(str(cue.parts), mode_geometry[expected[index]], "stable phase samples retain their bounded silhouette")
		var active_a: Dictionary = presenter.reaction_model(state, recipe, state.active_tick, reduced).capacitor_cue
		var active_b: Dictionary = presenter.reaction_model(state, recipe, state.active_tick + 4, reduced).capacitor_cue
		check(str(active_a.parts) != str(active_b.parts) and active_a.motion_step != active_b.motion_step, "active chevrons visibly advance using absolute authority age")
		var early_warning: Dictionary = presenter.reaction_model(state, recipe, warning_tick, reduced).capacitor_cue
		var late_warning: Dictionary = presenter.reaction_model(state, recipe, state.decay_tick - 2, reduced).capacitor_cue
		check(early_warning.motion == "inward" and late_warning.buildup > early_warning.buildup and str(late_warning.parts) != str(early_warning.parts), "the full500ms warning visibly builds before the one-tick release")
		var discharge := presenter.reaction_model(state, recipe, state.decay_tick - 1, reduced)
		var active_material := presenter.reaction_model(state, recipe, state.active_tick, reduced)
		var decay_material := presenter.reaction_model(state, recipe, state.decay_tick, reduced)
		check(float(decay_material.material_opacity) < float(active_material.material_opacity) * 0.5, "harmless decay becomes visibly quiet on its first tick in both effects modes")
		check(float(discharge.material_opacity) > float(active_material.material_opacity), "single discharge distinctly brightens the occupied material")
		var canvas := Node2D.new()
		var parts_before := int(presenter.stats().capacitor_parts)
		equal(presenter.draw_capacitor_cue(canvas, discharge), discharge.capacitor_cue.parts.size(), "draw path submits every bounded clipped discharge part")
		equal(int(presenter.stats().capacitor_parts), parts_before + discharge.capacitor_cue.parts.size(), "draw submission stays observable in the presentation budget")
		equal(presenter.draw_capacitor_cue(null, discharge), 0, "missing canvas cannot turn a cue into authority or a draw")
		canvas.free()
		if not reduced:
			stage_geometry = mode_geometry
	check(stage_geometry.size() == 5, "shape and motion distinguish all five Capacitor phases without relying on color")
	check(presenter.reaction_model(state, recipe, state.expiry_tick).is_empty(), "Capacitor cues stop exactly at authority expiry")
	equal(state.canonical_values(), before, "Capacitor model and draw queries never edit gameplay state")
	check(presenter._capacitor_cues.size() <= Presenter.CAPACITOR_CUE_CACHE_LIMIT, "Capacitor geometry cache has a hard entry bound")


func _test_rampart_footprint(presenter: ElementChemistryPresenter) -> void:
	var directions: Array[Vector2i] = [Vector2i(1000,0), Vector2i(707,707), Vector2i(0,1000), Vector2i(-707,707), Vector2i(-1000,0), Vector2i(-707,-707), Vector2i(0,-1000), Vector2i(707,-707)]
	var recipe := Chemistry.recipe(301)
	var state := Reaction.new()
	state.entity_id = 4000
	state.recipe_wire_id = 301
	state.position_x = 700000
	state.position_y = 500000
	state.created_tick = 10
	state.active_tick = 32
	state.decay_tick = 407
	state.expiry_tick = 455
	state.radius = 18000
	state.length = 64000
	state.health = 32000
	presenter.begin_frame(SimConfig.new(120), null, Rect2(0,0,1280,960), [])
	for direction: Vector2i in directions:
		state.direction_x = direction.x
		state.direction_y = direction.y
		var expected := Vector2(Chemistry.rampart_bounds(state).size) / 1000.0
		for tick: int in [11, 40, 410]:
			var model := presenter.reaction_model(state, recipe, tick)
			check(not model.is_empty(), "Rampart has warning, active and harmless decay art in every cast direction")
			if model.is_empty():
				continue
			equal(model.mask.bounds.size, expected, "Rampart art is the exact cardinal rectangle, not a diagonal capsule or invisible AABB")
			equal(model.mask.polygons.size(), 1, "open-ground Rampart is one unbroken rectangle")
			var actual := Chemistry.rampart_bounds(state)
			for vertex: Vector2 in model.mask.polygons[0]:
				check(vertex.x >= float(actual.position.x)/1000.0 and vertex.x <= float(actual.end.x)/1000.0 and vertex.y >= float(actual.position.y)/1000.0 and vertex.y <= float(actual.end.y)/1000.0, "every visible Rampart corner lies on the authoritative footprint")
			check(not presenter.footprint_cells(model).is_empty(), "native pixel cells tile the actual Rampart footprint")
	var earth_display_index := ChemistryGuideModel.DISPLAY_WIRES.find(int(AbilityCatalog.DISPLAY_ELEMENT_WIRES["earth"]))
	check(earth_display_index >= 0, "Earth stable wire resolves inside the player-facing display order")
	var detail := " ".join(ChemistryGuideModel.pair_lines(earth_display_index, earth_display_index))
	check(detail.contains("wallrun/walljump") and detail.contains("80 x 45 px") and detail.contains("escape"), "F4 teaches live Rampart size, movement and escape rule")
	check(not detail.contains("not walking"), "Earth mirror no longer carries obsolete non-solid cover teaching")


func _test_large_coordinate_triangulation(presenter: ElementChemistryPresenter) -> void:
	# Exact subpixel triangle from the paid Charge trail/terminal capture at
	# tick54. World-coordinate float area loses its sign; no vertex is invalid.
	var sliver := PackedVector2Array([Vector2(1576, 1336.21997070313), Vector2(1576, 1336), Vector2(1576.431640625, 1336)])
	var original := sliver.duplicate()
	for reverse: bool in [false, true]:
		var points := sliver.duplicate()
		if reverse:
			points.reverse()
		var indices := PixelEffectGeometry.local_triangle_indices(points)
		equal(indices.size(), 3, "captured nonzero-area sliver triangulates in either winding")
		if indices.size() == 3:
			var twice_area := absf((points[indices[1]] - points[indices[0]]).cross(points[indices[2]] - points[indices[0]]))
			check(twice_area > 0.09 and twice_area < 0.10, "small valid material area is retained, not culled as numerical noise")
	equal(sliver, original, "triangulation never rounds or shifts actual world vertices")
	check(PixelEffectGeometry.local_triangle_indices(PackedVector2Array([Vector2.ZERO, Vector2.ONE])).is_empty(), "fewer than three points have no drawable triangles")
	check(PixelEffectGeometry.local_triangle_indices(PackedVector2Array([Vector2.ZERO, Vector2.ONE, Vector2(INF, 0)])).is_empty(), "nonfinite geometry fails closed")
	var deposit := Deposit.from_values(PackedInt64Array([3002, 1000, 101, 1, 1, 6, 1568000, 1322560, 0, -1000, Deposit.TRAIL_RADIUS, 250, 24, 120, 5]))
	check(deposit != null, "current Charge trail admits source-derived canonical dimensions")
	if deposit == null:
		return
	# Preserve the exact old pixel sliver as a synthetic geometry regression,
	# not a current playable deposit or a relaxation of wire validation.
	deposit.radius = 16000
	var before := deposit.canonical_values()
	for reduced: bool in [false, true]:
		presenter.begin_frame(SimConfig.new(120), null, Rect2(), [deposit], reduced)
		var model := presenter.deposit_model(deposit, 54, reduced)
		var retained_sliver := false
		for cell: Dictionary in presenter.footprint_cells(model):
			for part: Dictionary in cell.parts:
				var points: PackedVector2Array = part.points
				var indices: PackedInt32Array = part.indices
				check(not indices.is_empty() and indices.size() % 3 == 0, "every cached footprint part has explicit complete triangle indices")
				for index: int in indices:
					check(index >= 0 and index < points.size(), "cached triangle indices address original mask vertices")
				if points.size() == 3 and points.has(original[0]) and points.has(original[1]) and points.has(original[2]):
					retained_sliver = true
				for index: int in range(points.size()):
					var expected_uv: Vector2 = (points[index] - cell.anchor + model.frame.pivot) / model.frame.texture.get_size()
					check((part.uvs[index] as Vector2).is_equal_approx(expected_uv), "local triangulation preserves exact cached atlas-relative UV mapping")
		check(retained_sliver, "real normal/reduced footprint retains the formerly failing Charge sliver")
	equal(deposit.canonical_values(), before, "render triangulation leaves trail authority unchanged")


func _test_material_only_footprints(presenter: ElementChemistryPresenter) -> void:
	var config := SimConfig.new(120)
	var source := FileAccess.get_file_as_string("res://src/presentation/element_chemistry_presenter.gd")
	check(not source.contains("draw_polyline("), "chemistry does not draw separate range rings or outline strokes")
	check(not source.contains("magic.geometry.boundary_"), "chemistry does not replace removed outlines with boundary markers")
	for wire: int in range(301, 337):
		var state := _state(wire)
		state.radius = int(Chemistry.recipe(wire).radius)
		state.length = int(Chemistry.recipe(wire).length)
		var before := state.canonical_values()
		presenter.begin_frame(config, null, Rect2(), [])
		var normal := presenter.reaction_model(state, Chemistry.recipe(wire), state.active_tick)
		var cells := presenter.footprint_cells(normal)
		if normal.socket:
			check(cells.is_empty(), "unlinked sources do not invent a material footprint")
			continue
		check(not cells.is_empty() and cells.size() <= Presenter.FOOTPRINT_CELL_LIMIT, "each occupied reaction has bounded native material coverage")
		var reduced := presenter.reaction_model(state, Chemistry.recipe(wire), state.active_tick, true)
		equal(presenter.footprint_cells(reduced), cells, "reduced effects retain the same occupied cells rather than a ring")
		for element: int in range(1, 9):
			for attempt: int in range(100):
				presenter.library.take_decoration(PixelMagicLibrary.element_asset_id(element, "deposit_active", false))
		equal(presenter.footprint_cells(normal), cells, "zero decorative budget does not erase footprint material")
		check(presenter.footprint_cells(presenter.reaction_model(state, Chemistry.recipe(wire), state.expiry_tick)).is_empty(), "authority expiry removes all footprint cells")
		equal(state.canonical_values(), before, "material footprints never edit reaction authority")
		for cell: Dictionary in cells:
			check(not cell.parts.is_empty(), "every footprint cell is clipped to occupied geometry")
			for part: Dictionary in cell.parts:
				equal(part.points.size(), part.uvs.size(), "clipped geometry retains native atlas coordinates")
	check(presenter._footprints.size() <= Presenter.FOOTPRINT_CACHE_LIMIT, "footprint geometry cache has a hard entry bound")
	# Four source-scaled full-length linked Ice sections are the widest path.
	var path := _state(328)
	var diagonal := Chemistry.scaled(Vector2i(707, 707), int(Chemistry.recipe(328).length))
	path.path_points = PackedInt64Array()
	for index: int in range(5):
		path.path_points.append(500000 + diagonal.x * index)
		path.path_points.append(500000 + diagonal.y * index)
	var mask := PixelEffectGeometry.new().reaction_mask(path, Chemistry.recipe(328), path.active_tick, config)
	var frame := presenter.library.sample("magic.reaction.superconduct.active.normal", 0)
	var path_cells := presenter.footprint_cells({"mask": mask, "frame": frame})
	check(not path_cells.is_empty() and path_cells.size() <= Presenter.FOOTPRINT_CELL_LIMIT, "maximum four-link occupied path retains a bounded full native-cell footprint")
	for point: Vector2 in [Vector2(600,600), Vector2(900,900), Vector2(1200,1200)]:
		var covered := false
		for cell: Dictionary in path_cells:
			for part: Dictionary in cell.parts:
				covered = covered or Geometry2D.is_point_in_polygon(point, part.points)
		check(covered, "long diagonal material has no gaps from spacing larger than its native frame")
	for headings: Array in [[Vector2i(1000,0), Vector2i(0,1000), Vector2i(-1000,0), Vector2i(0,-1000)], [Vector2i(707,707), Vector2i(707,-707), Vector2i(707,707), Vector2i(707,-707)]]:
		path.path_points = PackedInt64Array([500000,500000])
		var cursor := Vector2i(500000,500000)
		for heading: Vector2i in headings:
			cursor += Chemistry.scaled(heading, int(Chemistry.recipe(328).length))
			path.path_points.append(cursor.x)
			path.path_points.append(cursor.y)
		var shaped_mask := PixelEffectGeometry.new().reaction_mask(path, Chemistry.recipe(328), path.active_tick, config)
		var shaped_cells := presenter.footprint_cells({"mask": shaped_mask, "frame": frame})
		check(not shaped_cells.is_empty() and shaped_cells.size() <= Presenter.FOOTPRINT_CELL_LIMIT, "scaled full-length square/zigzag paths keep bounded complete native coverage")


func _state(wire: int) -> ElementReactionState:
	var definition := Chemistry.recipe(wire)
	var deposits: Array = []
	for index: int in range(2):
		Chemistry.deposit_terminal(deposits, 3000 + index, 1000 + index, 100, 1, 1, int(definition.elements[index]), Vector2i(500000, 500000), 0, SimConfig.new())
	return Chemistry.form_reaction(deposits[0], deposits[1], 4000, 0, SimConfig.new())


func _test_pixel_phases_and_native_cells(presenter: ElementChemistryPresenter) -> void:
	presenter.begin_frame(SimConfig.new(), null, Rect2(), [])
	for wire: int in range(301, 337):
		var state := _state(wire)
		var before := state.canonical_values()
		var definition := Chemistry.recipe(wire)
		for reduced: bool in [false, true]:
			for phase: String in ["formation", "active", "decay"]:
				var tick := state.created_tick if phase == "formation" else state.active_tick if phase == "active" else state.decay_tick
				var model := presenter.reaction_model(state, definition, tick, reduced)
				check(not model.is_empty(), "all36 reactions have visible authored phase models")
				if model.is_empty():
					continue
				equal(model.asset_id, "magic.reaction.%s.%s.%s" % [definition.id, phase, "reduced" if reduced else "normal"], "reaction selects its distinct material and exact accessibility phase")
				equal(model.age_ticks, 0, "phase change immediately selects its first authored key pose")
				equal(model.frame.index, 0, "absolute first pose never delays behind another animation")
				equal(model.frame.size, Vector2(32, 32), "material cells remain native32px instead of stretching across gameplay geometry")
				if not model.socket:
					check(PixelEffectGeometry.contains_point(model.mask.polygons, model.core_anchor), "essential identity core is anchored inside actual occupied geometry")
		check(presenter.reaction_model(state, definition, state.created_tick - 1).is_empty(), "unborn effect has no pixel material")
		check(presenter.reaction_model(state, definition, state.expiry_tick).is_empty(), "authority expiry immediately removes material and boundaries")
		equal(state.canonical_values(), before, "phase sampling never mutates reaction state")
	for element: int in range(1, 9):
		var values: Array = []
		Chemistry.deposit_terminal(values, 3010, 1010, 100, 1, 1, element, Vector2i(500000, 500000), 0, SimConfig.new())
		var deposit: ElementDepositState = values[0]
		var before := deposit.canonical_values()
		var first := presenter.deposit_model(deposit, 0)
		var active := presenter.deposit_model(deposit, 100)
		var decay := presenter.deposit_model(deposit, deposit.expiry_tick - 1)
		equal(first.phase, "formation", "deposit uses authored immediate formation")
		equal(active.phase, "active", "deposit switches to actual remaining-lifetime material loop")
		equal(decay.phase, "decay", "finite deposit ends with its authored decay")
		equal(first.frame.size, Vector2(32, 32), "deposit never grows a fake tall collision pillar")
		check(presenter.deposit_model(deposit, deposit.expiry_tick).is_empty(), "deposit pixels stop exactly at expiry")
		deposit.strength = 0
		check(presenter.deposit_model(deposit, 0).is_empty(), "consumed deposit disappears immediately")
		deposit.strength = 1000
		equal(deposit.canonical_values(), before, "deposit artwork owns no gameplay fields")
	var hail := _state(323)
	hail.endpoint_y += 20000
	var hail_model := presenter.reaction_model(hail, Chemistry.recipe(323), hail.active_tick + 27)
	equal(hail_model.mask.hail_position, Presenter.hail_position(hail, hail.active_tick + 27), "display helper agrees with actual single-pulse geometry despite noncollinear endpoint")
	check(not PixelEffectGeometry.contains_point(hail_model.mask.polygons, Vector2(510, 500)), "warning lane does not become a string of active hail projectiles")
	var steam := _state(310)
	var steam_model := presenter.reaction_model(steam, Chemistry.recipe(310), steam.active_tick)
	equal(steam_model.edge_color, Color(String(presenter.language.data.reaction_materials.steam.base)), "Steam uses its canonical neutral vapor color, never Fire orange")


func _test_deposit_material_readability(presenter: ElementChemistryPresenter) -> void:
	var config := SimConfig.new(120)
	for element: int in range(1, 9):
		var values: Array = []
		Chemistry.deposit_terminal(values, 3010, 1010, 100, 1, 1, element, Vector2i(500000, 500000), 0, config)
		var deposit: ElementDepositState = values[0]
		var canonical := deposit.canonical_values()
		for reduced: bool in [false, true]:
			presenter.library.begin_frame(reduced)
			presenter.begin_frame(config, null, Rect2(), values, reduced)
			var active := presenter.deposit_model(deposit, 100, reduced)
			equal(active.core_opacity, 0.88 if reduced else 0.94, "all eight terminal ingredients keep a readable native identity core")
			equal(active.material_opacity, 0.50 if reduced else 0.64, "harmless ingredient surroundings remain quieter than active material")
			check(float(active.core_opacity) > float(active.material_opacity), "readability is strengthened without increasing tiled density")
			equal(active.frame.size, Vector2(32, 32), "stronger deposit never changes native material scale")
			for other: int in range(1, 9):
				for unused: int in range(100):
					presenter._take_optional(PixelMagicLibrary.element_asset_id(other, "deposit_active", reduced), reduced)
			equal(presenter.library.decoration_remaining(), 0, "deposit regression reaches the shared decoration ceiling")
			var budgeted := presenter.deposit_model(deposit, 100, reduced)
			equal(budgeted.core_opacity, active.core_opacity, "identity does not become faint at the decoration ceiling")
			equal(budgeted.mask, active.mask, "stronger material and exhausted density share the exact old footprint")
			var fading := presenter.deposit_model(deposit, deposit.expiry_tick - 1, reduced)
			check(float(fading.core_opacity) < float(active.core_opacity), "identity still follows finite deposit decay")
			check(presenter.deposit_model(deposit, deposit.expiry_tick, reduced).is_empty(), "stronger identity does not persist after expiry")
			equal(deposit.canonical_values(), canonical, "material strength has no gameplay ownership")
	# Generic reactions still use their authored opacity; only deposits expose
	# the stronger identity override, keeping Steam/Shadowdraft thinning intact.
	presenter.begin_frame(config, null, Rect2(), [])
	for wire: int in range(301, 337):
		var state := _state(wire)
		var model := presenter.reaction_model(state, Chemistry.recipe(wire), state.active_tick)
		check(not model.has("core_opacity"), "reaction material never inherits the stronger deposit-only opacity")


func _test_ingredient_roles(presenter: ElementChemistryPresenter) -> void:
	var config := SimConfig.new(120)
	var screen_filter := VisualAccessibilityFilter.new()
	check(screen_filter.configure(), "ingredient accessibility fixture uses the actual screen filter")
	for reduced: bool in [false, true]:
		for element: int in range(1, 9):
			var values: Array = []
			Chemistry.deposit_terminal(values, 3010, 1010, 100, 1, 1, element, Vector2i(500000, 500000), 0, config)
			Chemistry.deposit_terminal(values, 3011, 1011, 100, 1, 1, element, Vector2i(500000, 500000), 0, config, Vector2i(1000, 0), 250, true)
			var terminal: ElementDepositState = values[0]
			var trail: ElementDepositState = values[1]
			var before := [terminal.canonical_values(), trail.canonical_values()]
			presenter.begin_frame(config, null, Rect2(), values, reduced)
			var normal_models: Array = []
			var normal_cells: Array = []
			for profile: String in ["standard", "high_contrast"]:
				check(screen_filter.set_profile(profile), "ordinary/high-contrast profile selects through the production filter")
				var terminal_model := presenter.deposit_model(terminal, 50, reduced)
				var trail_model := presenter.deposit_model(trail, 50, reduced)
				equal(terminal_model.material_role, "terminal_ingredient", "full contact is explicitly an ingredient, not persistent impact damage")
				equal(trail_model.material_role, "optional_trail", "flight residue has its own quieter optional role")
				check(not terminal_model.deals_damage and not terminal_model.applies_status and not trail_model.deals_damage and not trail_model.applies_status, "all eight plain ingredients truthfully claim no passive damage or status")
				check(trail_model.material_opacity < terminal_model.material_opacity and trail_model.core_opacity < terminal_model.core_opacity, "narrow trail has lower area and identity emphasis than full terminal")
				check(trail_model.material_opacity >= 0.30 and terminal_model.material_opacity >= 0.50, "reduced effects retain a nonzero material readability floor")
				equal(trail_model.mask.bounds.size, Vector2.ONE * float(Deposit.TRAIL_RADIUS) / 500.0, "trail footprint uses authoritative radius")
				equal(terminal_model.mask.bounds.size, Vector2.ONE * float(Deposit.TERMINAL_MAX_RADIUS) / 500.0, "terminal footprint uses authoritative maximum radius")
				equal(trail_model.asset_id, terminal_model.asset_id, "roles retain the same element-specific active artwork, not generic recolored disks")
				equal(trail_model.edge_color, terminal_model.edge_color, "role distinction does not replace any element palette")
				check(presenter.accent_anchors(trail_model).is_empty(), "optional trails do not duplicate their identity into extra accent stamps")
				var cells := [presenter.footprint_cells(terminal_model), presenter.footprint_cells(trail_model)]
				check(not cells[0].is_empty() and not cells[1].is_empty(), "both essential tiled masks survive independently of accent density")
				if profile == "standard":
					normal_models = [terminal_model, trail_model]
					normal_cells = cells
				else:
					equal([terminal_model, trail_model], normal_models, "high contrast is a screen transform, not a new role/phase/coverage authority")
					equal(cells, normal_cells, "high contrast retains every exact prefilter material cell")
				for state: ElementDepositState in [terminal, trail]:
					check(presenter.deposit_model(state, state.expiry_tick, reduced).is_empty(), "both roles disappear at exact authoritative expiry in either profile")
				equal([terminal.canonical_values(), trail.canonical_values()], before, "role and filter queries cannot modify ingredients")
			# Representative active damaging recipe retains its stronger authored
			# area cap. Forming/decaying and intentionally thinning veils differ.
			var hazard := _state(309)
			var hazard_model := presenter.reaction_model(hazard, Chemistry.recipe(309), hazard.active_tick, reduced)
			check(hazard_model.material_opacity > normal_models[0].material_opacity, "active Conflagration area retains priority over harmless ingredient tiles")
	screen_filter.free()


func _test_compact_native_material(presenter: ElementChemistryPresenter) -> void:
	var config := SimConfig.new(120)
	var signatures: Dictionary = {}
	for element: int in range(1, 9):
		var values: Array = []
		Chemistry.deposit_terminal(values, 3010, 1010, 100, 1, 1, element, Vector2i(500000, 500000), 0, config)
		var state: ElementDepositState = values[0]
		var before := state.canonical_values()
		presenter.begin_frame(config, null, Rect2(), values)
		var normal := presenter.deposit_model(state, 100)
		var reduced := presenter.deposit_model(state, 100, true)
		var anchors := presenter.accent_anchors(normal)
		equal(anchors.size(), 2, "normal material has only two compact budgeted accents")
		equal(presenter.accent_anchors(reduced).size(), 1, "reduced material removes an accent before identity")
		check(presenter.accent_anchors(reduced)[0] == anchors[0], "reduced material is a stable subset")
		signatures[str(anchors)] = true
		for anchor: Vector2 in anchors:
			check(PixelEffectGeometry.contains_point(normal.mask.polygons, anchor), "material accents stay anchored in the actual occupied mask")
			check(anchor.distance_to(normal.core_anchor) <= 12.0, "material reads as a compact native cluster, not another threat")
		for tick: int in [0, state.expiry_tick - 1]:
			var phased := presenter.deposit_model(state, tick)
			equal(presenter.decoration_frame(phased, 3), phased.frame, "formation and decay never borrow active or future poses")
		check(presenter.deposit_model(state, state.expiry_tick).is_empty(), "composition stops exactly at expiry")
		equal(state.canonical_values(), before, "cosmetic composition owns no gameplay state")
	equal(signatures.size(), 8, "all eight basic materials have distinct compact layouts")
	var steam := _state(310)
	presenter.begin_frame(config, null, Rect2(), [])
	var steam_model := presenter.reaction_model(steam, Chemistry.recipe(310), steam.active_tick)
	var frames: Dictionary = {}
	for index: int in range(8):
		var sample := presenter.decoration_frame(steam_model, index)
		frames[int(sample.index)] = true
		equal(sample.size, Vector2(32, 32), "staggered vapor remains native-size immutable source pixels")
	check(frames.size() > 1, "active vapor avoids synchronized wallpaper poses")
	check(presenter.accent_anchors(steam_model).is_empty(), "Steam does not multiply its existing weak silhouette into false cover-like piles")
	for tick: int in [steam.created_tick, steam.decay_tick, steam.expiry_tick - 1]:
		var phased := presenter.reaction_model(steam, Chemistry.recipe(310), tick)
		equal(presenter.decoration_frame(phased, 5), phased.frame, "Steam formation/decay are never dephased")
	for wire: int in range(301, 337):
		if wire == 310:
			continue
		var reaction := _state(wire)
		var model := presenter.reaction_model(reaction, Chemistry.recipe(wire), reaction.active_tick)
		check(presenter.accent_anchors(model).is_empty(), "other reaction layouts remain unchanged")
		equal(presenter.decoration_frame(model, 5), model.frame, "other reaction phase sampling remains unchanged")


func _test_concealment_windows(presenter: ElementChemistryPresenter) -> void:
	var config := SimConfig.new(120)
	for reduced: bool in [false, true]:
		presenter.begin_frame(config, null, Rect2(), [], reduced)
		for wire: int in [310, 326]:
			var state := _state(wire)
			var definition := Chemistry.recipe(wire)
			var before := state.canonical_values()
			var composition: Dictionary = presenter.library.reaction(wire)["composition"]
			var cap := float(composition["opacity_cap_reduced" if reduced else "opacity_cap_normal"])
			var cutoff := state.decay_tick - config.milliseconds_to_ticks(350)
			var ticks: Array = [cutoff-1, cutoff, cutoff+1] if wire == 310 else [state.active_tick+35, state.active_tick+36, state.active_tick+71, state.active_tick+72]
			var expected: Array = [true, false, false] if wire == 310 else [true, false, false, true]
			var reference := presenter.reaction_model(state, definition, state.active_tick, reduced)
			for index: int in range(ticks.size()):
				var model := presenter.reaction_model(state, definition, ticks[index], reduced)
				equal(model.concealing, expected[index], "Steam cutoff / Shadowdraft band follows exact authority tick")
				equal(model.concealing, state.active(ticks[index]) and Chemistry._concealing(state, ticks[index], config), "cue reuses current authority predicate")
				check(is_equal_approx(float(model.material_opacity), cap * (1.0 if expected[index] else 0.25)), "nonconcealing active material is quarter-opacity in normal and reduced mode")
				equal(model.phase, "active", "veil gap never restarts or skips the actual phase")
				equal(model.opacity, 1.0, "essential boundary retains full active opacity")
				equal(model.edge_color, reference.edge_color, "veil gap does not recolor the exact boundary")
				equal(model.mask.polygons, reference.mask.polygons, "veil gap never changes material clipping geometry")
			for tick: int in [state.created_tick, state.active_tick-1, state.decay_tick, state.expiry_tick-1]:
				var model := presenter.reaction_model(state, definition, tick, reduced)
				check(not model.concealing, "formation and decay never claim active concealment")
				check(is_equal_approx(float(model.material_opacity), Presenter.phase_opacity(state, tick) * cap), "formation/decay preserve their authored opacity curve")
				equal(model.opacity, Presenter.phase_opacity(state, tick), "phase boundary fade stays unchanged")
			check(state.canonical_values() == before, "concealment cue cannot mutate authoritative state")
		for wire: int in range(301, 337):
			if wire in [310, 326]:
				continue
			var state := _state(wire)
			var composition: Dictionary = presenter.library.reaction(wire)["composition"]
			var cap := float(composition["opacity_cap_reduced" if reduced else "opacity_cap_normal"])
			for tick: int in [state.created_tick, state.active_tick, state.decay_tick]:
				var model := presenter.reaction_model(state, Chemistry.recipe(wire), tick, reduced)
				var expected_cap := (0.18 if tick == state.created_tick else 0.32 if tick == state.active_tick else 0.10) if wire == 331 else cap
				check(is_equal_approx(float(model.material_opacity), Presenter.phase_opacity(state, tick) * expected_cap), "Capacitor uses its reviewed stage values; all other reactions retain material strength")


func _test_live_links_and_worldbone(presenter: ElementChemistryPresenter) -> void:
	var config := SimConfig.new()
	for wire: int in [313, 319, 328]:
		var state := _state(wire)
		state.path_points = PackedInt64Array([500000, 500000, 600000, 500000])
		state.linked_deposit_ids = PackedInt64Array([3010])
		var deposit := Deposit.new()
		deposit.entity_id = 3010
		deposit.strength = 1000
		deposit.expiry_tick = 500
		var before := state.canonical_values()
		presenter.begin_frame(config, null, Rect2(), [deposit])
		var linked := presenter.reaction_model(state, Chemistry.recipe(wire), state.active_tick)
		check(not linked.unlinked and PixelEffectGeometry.contains_point(linked.mask.polygons, Vector2(560, 500)), "live deposit sustains only the actual stored connection")
		presenter.begin_frame(config, null, Rect2(), [])
		var missing := presenter.reaction_model(state, Chemistry.recipe(wire), state.active_tick)
		check(missing.unlinked and not PixelEffectGeometry.contains_point(missing.mask.polygons, Vector2(560, 500)), "missing source removes stale active connection immediately")
		equal(missing.socket, wire != 319, "only unlinked Water retains local material; Frost/Plasma show an unconnected socket")
		equal(PixelEffectGeometry.contains_point(missing.mask.polygons, Vector2(500, 500)), wire == 319, "Water local disk and inactive Frost/Plasma remain distinct")
		presenter.begin_frame(config, null, Rect2(), [deposit])
		deposit.expiry_tick = state.active_tick
		check(presenter.reaction_model(state, Chemistry.recipe(wire), state.active_tick).unlinked, "exact source expiry is not kept alive by cached geometry")
		equal(state.canonical_values(), before, "clearing a stale render path never erases the authoritative path history")
	var collision := CollisionWorld.new(1000000, 1000000)
	collision.add_obstacle(CollisionWorld.Obstacle.new(1, 520000, 480000, 528000, 520000))
	presenter.begin_frame(config, collision, Rect2(), [])
	for wire: int in [309, 322, 303]:
		var state := _state(wire)
		var model := presenter.reaction_model(state, Chemistry.recipe(wire), state.active_tick)
		check(not PixelEffectGeometry.contains_point(model.mask.polygons, Vector2(550, 500)), "material and warning masks stop behind worldbone")
		check(PixelEffectGeometry.contains_point(model.mask.polygons, Vector2(460, 500)), "unoccluded material survives worldbone clipping")
		if wire in [309, 322]:
			check(not PixelEffectGeometry.contains_point(model.mask.polygons, Vector2(500, 500)), "ring safe hole is never painted by the identity core")
		for anchor: Vector2 in presenter.tile_anchors(model.mask, model.core_anchor, false, 192):
			for part: Dictionary in PixelEffectGeometry.clipped_frame_parts(model.frame, anchor, model.mask.polygons):
				var center := Vector2.ZERO
				for point: Vector2 in part.points:
					center += point
				center /= float(part.points.size())
				check(PixelEffectGeometry.contains_point(model.mask.polygons, center), "every clipped native-cell polygon stays in actual material coverage")
	for wire: int in [307, 329]:
		var state := _state(wire)
		var model := presenter.reaction_model(state, Chemistry.recipe(wire), state.active_tick)
		check(not PixelEffectGeometry.contains_point(model.mask.polygons, Vector2(560, 500)), "optical facet art never invents a continuation ray")


func _test_budget_culling_and_information(presenter: ElementChemistryPresenter) -> void:
	var config := SimConfig.new()
	for reduced: bool in [false, true]:
		presenter.library.begin_frame(reduced)
		presenter.begin_frame(config, null, Rect2(), [], reduced)
		var admitted := 0
		for element: int in range(1, 9):
			for attempt: int in range(100):
				if presenter._take_optional(PixelMagicLibrary.element_asset_id(element, "deposit_active", reduced), reduced):
					admitted += 1
		equal(admitted, 96 if reduced else 192, "all chemistry shares the exact bounded optional-material budget")
		equal(presenter.stats().optional_stamps, admitted, "decorative admission is measured independently of essential information")
		var state := _state(309)
		var model := presenter.reaction_model(state, Chemistry.recipe(309), state.active_tick, reduced)
		check(not model.frame.is_empty() and (model.mask.boundaries as Array).size() == 2, "exhausted decoration never removes core art or either occupied ring boundary")
		equal(presenter.tile_anchors(model.mask, model.core_anchor, reduced, 0).size(), 0, "zero remaining decorative budget allocates no optional anchors")
		var normal := presenter.tile_anchors(model.mask, model.core_anchor, false, 192)
		var sparse := presenter.tile_anchors(model.mask, model.core_anchor, true, 192)
		check(sparse.size() <= normal.size(), "reduced mode removes optional cell density, not effect coverage")
		for point: Vector2 in sparse:
			check(normal.has(point), "reduced stamps are a stable subset of the same world-locked grid")
		presenter.begin_frame(config, null, Rect2(), [], reduced)
		equal(presenter.library.decoration_remaining(), 0, "chemistry frame setup never resets global spell decoration admission")
	var state := _state(303)
	presenter.begin_frame(config, null, Rect2(0, 0, 100, 100), [])
	var builds := int(presenter.stats().geometry.builds)
	check(presenter.reaction_model(state, Chemistry.recipe(303), state.active_tick).is_empty(), "off-camera reaction is culled")
	equal(int(presenter.stats().geometry.builds), builds, "off-camera effects are rejected before polygon construction")
	equal(presenter.stats().culled, 1, "viewport culling is observable")


func _test_thin_material_paths(presenter: ElementChemistryPresenter) -> void:
	var config := SimConfig.new()
	var deposit := Deposit.new()
	deposit.entity_id = 3010
	deposit.strength = 1000
	deposit.expiry_tick = 1000
	for wire: int in [313, 328]:
		for direction: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2(0.8, 0.6), Vector2(0.6, -0.8)]:
			for offset: int in range(32):
				var state := _state(wire)
				var start := Vector2(512 + offset, 512 + offset)
				var end := start + direction * 160.0
				state.position_x = roundi(start.x * 1000.0)
				state.position_y = roundi(start.y * 1000.0)
				state.endpoint_x = roundi(end.x * 1000.0)
				state.endpoint_y = roundi(end.y * 1000.0)
				state.path_points = PackedInt64Array([state.position_x, state.position_y, state.endpoint_x, state.endpoint_y])
				state.linked_deposit_ids = PackedInt64Array([3010])
				var before := state.canonical_values()
				presenter.begin_frame(config, null, Rect2(), [deposit])
				var model := presenter.reaction_model(state, Chemistry.recipe(wire), state.active_tick)
				equal(model.material_path, PackedVector2Array([start, end]), "thin material uses the real link, independently of grid translation")
				var normal := presenter.tile_anchors(model.mask, model.core_anchor, false, 192, model.material_path)
				for reduced: bool in [false, true]:
					var anchors := presenter.tile_anchors(model.mask, model.core_anchor, reduced, 192, model.material_path)
					check(not anchors.is_empty(), "every translated cardinal/diagonal thin link keeps material away from its source")
					var distant := false
					for anchor: Vector2 in anchors:
						distant = distant or anchor.distance_to(start) >= 64.0
						check(normal.has(anchor), "reduced path stamps are a stable subset of normal material")
						check(PixelEffectGeometry.contains_point(model.mask.polygons, anchor), "path stamps remain inside occupied link geometry")
						check(not PixelEffectGeometry.clipped_frame_parts(model.frame, anchor, model.mask.polygons).is_empty(), "native cells intersect the true thin mask")
					check(distant, "thin material is not reduced to the single source symbol")
					check(presenter.tile_anchors(model.mask, model.core_anchor, reduced, 2, model.material_path).size() <= 2, "path alignment retains the caller's remaining material budget")
					equal(presenter.tile_anchors(model.mask, model.core_anchor, reduced, 0, model.material_path).size(), 0, "exhausted budget never allocates path material")
					equal(state.canonical_values(), before, "material alignment never edits authority")
				if direction == Vector2.RIGHT and offset == 0:
					equal(presenter.tile_anchors(model.mask, model.core_anchor, false, 192).size(), 0, "fixture reproduces the old between-grid-rows material gap")
	# Exact worldbone clipping still rejects the far side of a valid stored path.
	var state := _state(328)
	state.path_points = PackedInt64Array([500000, 512000, 660000, 512000])
	state.position_y = 512000
	state.linked_deposit_ids = PackedInt64Array([3010])
	var collision := CollisionWorld.new(1000000, 1000000)
	collision.add_obstacle(CollisionWorld.Obstacle.new(1, 550000, 480000, 560000, 544000))
	presenter.begin_frame(config, collision, Rect2(), [deposit])
	var clipped := presenter.reaction_model(state, Chemistry.recipe(328), state.active_tick)
	var anchors := presenter.tile_anchors(clipped.mask, clipped.core_anchor, false, 192, clipped.material_path)
	check(not anchors.is_empty(), "unoccluded thin-link material survives")
	for anchor: Vector2 in anchors:
		check(anchor.x < 550.0, "path alignment never carries material through worldbone shadows")
	presenter.begin_frame(config, null, Rect2(), [])
	var unlinked := presenter.reaction_model(state, Chemistry.recipe(328), state.active_tick)
	check(unlinked.socket and unlinked.material_path.is_empty(), "dead links retain only the unconnected socket, not a material path")
	for wire: int in [309, 322, 323]:
		state = _state(wire)
		var model := presenter.reaction_model(state, Chemistry.recipe(wire), state.active_tick)
		check(model.material_path.is_empty(), "safe rings and single Hail pulse never acquire an invented centreline")
	for wire: int in [307, 332]:
		state = _state(wire)
		var model := presenter.reaction_model(state, Chemistry.recipe(wire), state.active_tick)
		equal(model.material_path.size(), 2, "thin optical facets and reveal lines reuse their real finite centreline")
		for anchor: Vector2 in presenter.tile_anchors(model.mask, model.core_anchor, false, 192, model.material_path):
			check(PixelEffectGeometry.contains_point(model.mask.polygons, anchor), "thin optical material never invents continuation rays")
