extends FluxTestSuite

const Garden = preload("res://src/app/element_garden_exhibition.gd")
const Presenter = preload("res://src/presentation/element_garden_presenter.gd")
const Surface = preload("res://src/presentation/element_garden_surface.gd")
const Mixtures = preload("res://src/content/mixture_catalog.gd")
const Policy = preload("res://src/sim/hex/hex_recipe_policy.gd")

class SampleDispatchProbe extends HexCourtPresenter:
	var selected := ""
	func _draw_shared_material(_canvas: CanvasItem, _regions: Dictionary, material: String, _tick: float, _reduced: bool) -> void:
		selected = "shared/" + material
	func _draw_mirror_product(_canvas: CanvasItem, _regions: Dictionary, material: String, _tick: float, _reduced: bool) -> void:
		selected = "mirror/" + material


func run() -> int:
	var catalog := AbilityCatalog.new()
	check(catalog.load_from_file("res://content/abilities/foundation_abilities_v1.json"), "garden uses the full current authored spell catalog")
	_test_directory_and_refusal()
	_test_all_real_fields()
	_test_visible_budget_and_isolation()
	_test_retained_phases_and_event_equivalence()
	_test_frame_restart_budget()
	_test_production_sample_dispatch()
	_test_far_garden_bounds()
	_test_cached_inspection()
	return finish("element-garden-exhibition")


func _rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in 63:
		result.append({"mask": index + 1, "center": Vector2(500 + (index % 9) * 288, 500 + (index / 9) * 288)})
	return result


func _test_directory_and_refusal() -> void:
	var garden := Garden.new()
	var rows := _rows()
	check(garden.configure(rows), "all 63 unique bounded plots configure")
	var ordered := garden.plots()
	equal(ordered.size(), 63, "all nonempty masks remain individually inspectable")
	var previous_arity := 0
	var previous_mask := 0
	for row: Dictionary in ordered:
		var count := Policy.elements_for_mask(int(row.mask)).size()
		check(count > previous_arity or (count == previous_arity and int(row.mask) > previous_mask), "garden groups simple ingredients before increasingly complex mixtures deterministically")
		previous_arity = count
		previous_mask = int(row.mask)
		var info := garden.plot_info(int(row.mask))
		check(not String(info.name).is_empty() and not String(info.ingredients).is_empty() and String(info.notice).contains("harmless"), "every plot names actual ingredients and its harmless exhibition scope")
	rows[0].center = Vector2(7000, 7000)
	ordered[0].name = "mutated"
	equal(garden.plots()[0].center, Vector2(500, 500), "caller rows and inspection copies cannot alter admitted directory")
	check(String(garden.plots()[0].name) != "mutated", "inspection metadata is detached")
	for mutation: int in 5:
		var invalid := _rows()
		match mutation:
			0: invalid.pop_back()
			1: invalid[1].mask = 1
			2: invalid[1].mask = 2.5
			3: invalid[1].center = Vector2(INF, 500)
			4: invalid[1].center = invalid[0].center
		check(not garden.configure(invalid), "incomplete, duplicate, fractional, nonfinite or overlapping plots refuse")
		check(garden.plots().is_empty() and garden.render_entries().is_empty(), "failed configuration publishes no stale plot authority")
		check(not garden.last_error.is_empty(), "invalid garden layout has an actionable diagnostic")


func _test_all_real_fields() -> void:
	var garden := Garden.new()
	check(garden.configure(_rows()), "real ground matrix configures")
	var language := VisualLanguage.new()
	check(language.load_from_file(), "real ground matrix uses current visual metadata")
	var renderer := HexCourtPresenter.new()
	check(renderer.configure(language), "actual Hex renderer accepts current material palette")
	var surface := Surface.new()
	var seen_recipes := {}
	var seen_raw := {}
	for mask: int in range(1, 64):
		var center: Vector2 = garden.plot_info(mask).center
		var view := Rect2(center - Vector2.ONE, Vector2.ONE * 2)
		check(garden.step(view, center), "nearby plot starts actual isolated finite authority")
		var entries := garden.render_entries()
		equal(entries.size(), 1, "isolated inspection does not activate unseen neighbors")
		if entries.size() != 1: continue
		var entry: Dictionary = entries[0]
		var court: HexChemistryWorld = entry.court
		equal(court.cell_count(), 61, "each plot uses exactly bounded four-ring geometry")
		equal(court.origin, Vector2i(center * 1000.0), "renderedground owns its actual absolute plot origin")
		equal(int(court.metrics.matter_paid), 600, "initial exhibit has exactly one600-unit exhibition source")
		check(court.conservation_valid(), "firstground state passes the actual source ledger invariant")
		_assert_ground_render(renderer, court, int(entry.tick))
		_assert_retained_surface(surface, renderer, entry)
		_assert_card(garden.nearest_info(center))
		var singleton := Policy.elements_for_mask(mask).size() == 1
		if singleton:
			var element := Policy.elements_for_mask(mask)[0]
			seen_raw[Policy.ingredient_layer(element)] = true
			equal(court.products.size(), 0, "single deposit is ingredient matter, not fabricated self reaction")
			equal(court.casts.size(), 1, "raw ingredient retains its actual source partition")
			var source: Dictionary = court.casts.values()[0]
			equal(int(source.ground), 600, "raw material contains exactly its finite deposited stock")
			var raw_expiry := int(source.expires)
			equal(raw_expiry, HexChemistryWorld.ingredient_lifetime(element), "single deposit lifetime is the current authored ingredient lifetime")
			for unused: int in raw_expiry: check(garden.step(view, center), "raw exhibit advances ordinary finite clock")
			check(court.occupied_cells().is_empty() and court.casts.is_empty(), "raw stock fully expires before any loop can restart")
			equal(int(court.metrics.matter_expired), 600, "raw stock retires through actual expiry accounting")
			equal(String(garden.nearest_info(center).phase), "resetting", "short reset interval is explicitly described")
			for unused: int in Garden.RESET_TICKS: check(garden.step(view, center), "singleton moves to its separately funded matching-source cycle")
			equal(String(garden.nearest_info(center).demonstration), "self", "singleton explicitly alternates to two matching sources")
			equal(int(court.metrics.matter_paid), 1800, "self reaction adds exactly two new600-unit sources without restoring prior stock")
			equal(int(court.metrics.matter_consumed), 1200, "self reaction consumes exactly both matching exhibition sources")
			_assert_ground_render(renderer, court, int(garden.render_entries()[0].tick))
			_assert_retained_surface(surface, renderer, garden.render_entries()[0])
			_assert_card(garden.nearest_info(center))
		if court.products.size() != 1:
			check(false, "each mixed or matching cycle forms exactly one real product")
			continue
		var product: Dictionary = court.products.values()[0]
		var wire := Policy.wire_for_mask(mask)
		seen_recipes[int(product.recipe_wire_id)] = true
		equal(int(product.recipe_wire_id), wire, "formed product is exactly the recipe for the displayed mask")
		equal(int(product.quantity), 1200 if singleton else 600, "mixture elements never multiply a single paid source budget")
		equal(product.source_ids.size(), 2 if singleton else 1, "exhibit preserves actual distinct source provenance")
		var strength := int(CombatTuning.cast_definition(Mixtures.wire_for(mask, "bolt")).reaction_strength)
		equal(int(product.funded_strength), strength * (2 if singleton else 1), "damage funding retains exact compiled source strength")
		equal(int(product.damage_budget_remaining), int(product.funded_strength) * 4000, "real harm pool is finite although no live actor is exposed")
		check(court.conservation_valid(), "raw-to-self and directmixed paths retain actual conservation")
		var policy := Policy.definition(wire)
		equal(int(product.active_tick) - int(product.created), int(policy.formation_ticks), "exhibition never skips the real formation warning")
		equal(int(product.decay_tick) - int(product.active_tick), int(policy.active_ticks), "boundedplot does not retune active lifetime")
		equal(int(product.expiry_tick) - int(product.decay_tick), int(policy.decay_ticks), "boundedplot retains real harmless decay")
		var expiry := int(product.expiry_tick)
		while int(garden.render_entries()[0].tick) < expiry:
			check(garden.step(view, center), "field completes every ordinary lifecycle tick")
			equal(int(court.metrics.matter_paid), 1800 if singleton else 600, "active or decaying phase cannot refresh its exhibition source")
		check(court.products.is_empty() and court.occupied_cells().is_empty(), "every real recipe expires completely before restart")
		check(court.conservation_valid(), "expired field leaves no unaccounted matter")
		if mask == 63:
			for unused: int in Garden.RESET_TICKS - 1: check(garden.step(view, center), "mixed reset waits its full explicit gap")
			check(court.products.is_empty(), "mixed reset does not refresh before exact boundary")
			check(garden.step(view, center), "mixed reset starts a fresh independently funded cycle at boundary")
			equal(int(court.metrics.matter_paid), 1200, "second mixture cycle is one fresh600 unit contribution")
			check(int(court.products.values()[0].source_ids[0]) > int(product.source_ids[0]), "repeat cycle never reuses old source identity")
	equal(seen_raw.size(), 6, "all six actual rawground materials were rendered")
	equal(seen_recipes.size(), 63, "all 63 actual recipe IDs were formed across63plots plus six alternating deposit modes")
	for wire: int in Policy.active_wire_ids(): check(seen_recipes.has(wire), "no authored reaction is replaced by a static legend or omitted")
	equal(int(surface.diagnostics().resident), 63, "bounded retained display admits every actual recipe and raw mode")
	var empty: Array[Dictionary] = []
	surface.retain(empty)
	equal(int(surface.diagnostics().resident), 0, "leaving the Garden releases retained meshes")
	equal(int(surface.diagnostics().retained_geometry), 0, "leaving also releases last-nonempty repeat geometry")


func _assert_retained_surface(surface: RefCounted, renderer: HexCourtPresenter, entry: Dictionary) -> void:
	var court: HexChemistryWorld = entry.court
	var before := court.state_hash()
	var retained: Dictionary = surface.prepare(entry, renderer, false)
	check(retained.mesh != null and not retained.boundary.is_empty(), "each real field retains a nonempty mesh and its outer boundary")
	check(retained.native_mesh != null, "every actual recipe and raw ingredient has a retained native-texture mesh")
	equal(retained.cells.size(), court.occupied_cells().size(), "retained display includes every actually occupied cell without nearest-cell truncation")
	var expected_vertices := 0
	for cell: Vector2i in court.occupied_cells():
		var regions := court.render_regions(cell, String(entry.material), float(entry.tick))
		if regions.is_empty(): continue
		var polygon := PackedVector2Array()
		for point: Vector2 in regions[0].polygon: polygon.append(point / 1000.0)
		var clipped: Dictionary = renderer.material_surface.geometry_for_polygon(polygon)
		expected_vertices += clipped.points.size()
	equal(int(retained.native_vertices), expected_vertices, "merged native art includes exactly the production-clipped geometry of every occupied cell")
	check(retained.samples.size() >= 1 and retained.samples.size() <= 3, "material animation is bounded independently of occupied coverage")
	for region: Dictionary in retained.samples:
		equal(String(region.phase), String(entry.phase), "retained material sample uses the actual lifecycle phase")
		equal(String(region.material), String(entry.material), "retained material sample preserves exact recipe identity")
		for point: Vector2 in region.polygon: check(Vector2(court.origin).distance_to(point * 1000.0) <= 110000.0, "retained sample stays inside physical exhibit bounds")
	var builds := int(surface.diagnostics().geometry_builds)
	var mesh: ArrayMesh = retained.mesh
	var native_mesh: ArrayMesh = retained.native_mesh
	surface.prepare(entry, renderer, false)
	equal(int(surface.diagnostics().geometry_builds), builds, "unchanged footprint causes no rebuild on repeated draw preparation")
	equal((surface.prepare(entry, renderer, true) as Dictionary).mesh, mesh, "reduced motion refreshes style without rebuilding mesh geometry")
	equal((surface.prepare(entry, renderer, true) as Dictionary).native_mesh, native_mesh, "reduced motion shares the exact native-texture footprint without rebuilding geometry")
	equal(court.state_hash(), before, "retained display and quality choice cannot mutate exhibition authority")


func _test_retained_phases_and_event_equivalence() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "event-equivalence fixture loads production palette")
	var renderer := HexCourtPresenter.new()
	check(renderer.configure(language), "event-equivalence fixture configures production material sampling")
	for mask: int in [2, 4, 6, 34, 63]:
		var garden := Garden.new()
		check(garden.configure(_rows()), "event-equivalence plot directory configures")
		var center: Vector2 = garden.plot_info(mask).center
		var view := Rect2(center - Vector2.ONE, Vector2.ONE * 2)
		check(garden.step(view, center), "event-equivalence starts isolated plot")
		var reference: Dictionary = garden._new_entry(mask)
		var reference_court: HexChemistryWorld = reference.court
		var surface := Surface.new()
		var initial: Dictionary = surface.prepare(garden.render_entries()[0], renderer, false)
		var mesh: ArrayMesh = initial.mesh
		var native_mesh: ArrayMesh = initial.native_mesh
		var expiry := int(reference.expiry)
		for tick: int in range(1, expiry + 1):
			check(garden.step(view, center), "boundary-driven exhibit advances one exact authority tick")
			reference_court.expire_at(tick)
			reference_court.fracture_products(tick)
			reference_court.sync_flights([], [])
			if tick not in [int(reference.active), int(reference.decay) - 72, int(reference.decay), expiry]: continue
			var entry: Dictionary = garden.render_entries()[0]
			var court: HexChemistryWorld = entry.court
			equal(court.state_hash(), reference_court.state_hash(), "boundary-only maintenance matches original per-tick production maintenance")
			var retained: Dictionary = surface.prepare(entry, renderer, false)
			if tick < expiry:
				equal(retained.mesh, mesh, "formation, active warning and decay changes reuse geometry")
				equal(retained.native_mesh, native_mesh, "all unexpired phase and warning changes reuse native UV geometry")
				var actual := court.render_regions(retained.sample_cells[0], String(entry.material), float(tick))
				equal(String(retained.samples[0].phase), String(actual[0].phase), "phase cache refreshes from real authority even with unchanged coverage")
				equal(bool(retained.samples[0].danger), bool(actual[0].danger), "active and harmless phases never reuse stale danger")
				if mask == 34 and tick == int(reference.decay) - 72:
					equal(float(retained.style.edge_width), 3.0, "Backdraft fuse warning appears on the exact production warning boundary")
					check(retained.native_entry.is_empty(), "Backdraft fuse warning uses its explicit production warning cue without an opaque native fill")
			else:
				check(retained.mesh == null and retained.samples.is_empty(), "expired material leaves no retained display or stale material sample")
				check(retained.native_mesh == null and retained.native_entry.is_empty(), "expiry clears both native texture geometry and phase-frame selection")
		if mask == 63:
			var builds := int(surface.diagnostics().geometry_builds)
			for unused: int in Garden.RESET_TICKS: garden.step(view, center)
			var repeated: Dictionary = surface.prepare(garden.render_entries()[0], renderer, false)
			equal(repeated.mesh, mesh, "a fresh paid repeat reuses its exact unchanged footprint after rendering an empty expiry")
			equal(repeated.native_mesh, native_mesh, "identical repeat avoids native clipping and GPU mesh upload")
			equal(int(surface.diagnostics().geometry_builds), builds, "repeat with identical public polygons creates no replacement geometry")
			check(int(surface.diagnostics().geometry_reuses) >= 1, "exact source-polygon comparison records actual repeat reuse")
			check(repeated.samples[0].source_ids != initial.samples[0].source_ids, "geometry reuse never reuses retired source identity")
			var actual := (garden.render_entries()[0].court as HexChemistryWorld).render_regions(repeated.sample_cells[0], String(garden.render_entries()[0].material), float(garden.render_entries()[0].tick))
			equal(repeated.samples[0].source_ids, actual[0].source_ids, "repeat material metadata comes from current funded authority")
			var moved_rows := _rows()
			moved_rows[62].center += Vector2(12, 0)
			var moved := Garden.new()
			check(moved.configure(moved_rows), "same-cell-count relocated plot fixture is valid")
			var moved_center: Vector2 = moved.plot_info(63).center
			check(moved.step(Rect2(moved_center - Vector2.ONE, Vector2.ONE * 2), moved_center), "relocated isolated plot admits")
			var relocated: Dictionary = surface.prepare(moved.render_entries()[0], renderer, false)
			check(relocated.mesh != mesh and relocated.native_mesh != native_mesh, "same cell keys at changed actual polygon coordinates cannot reuse old geometry")
			equal(int(surface.diagnostics().retained_geometry), 1, "one last nonempty shape per plot remains bounded across replacements")


func _test_frame_restart_budget() -> void:
	var garden := Garden.new()
	check(garden.configure(_rows()), "restart-budget fixture configures all plots")
	var view := Rect2(0, 0, 7800, 7800)
	check(garden.step(view, Vector2.ZERO), "restart-budget fixture admits all 63 plots")
	var saw_queue := false
	var saw_restart := false
	var last_first_expiry := 0
	for entry: Dictionary in garden._resident.values(): last_first_expiry = maxi(last_first_expiry, int(entry.expiry))
	# At one restart per displayed frame, a simultaneous cohort legitimately
	# needs up to63frames after its latest expiry, independently of tick rate.
	var frames := ceili(float(last_first_expiry + Garden.RESET_TICKS) / 8.0) + Garden.MAX_RESIDENT + 1
	var waiting_frames := {}
	for frame: int in frames:
		var before := 0
		for entry: Dictionary in garden.render_entries(): before += int(entry.cycle)
		garden.begin_frame()
		for catchup: int in 8: check(garden.step(view, Vector2.ZERO), "fixed-step catch-up preserves Garden lifecycle budget")
		var after := 0
		for entry: Dictionary in garden.render_entries():
			after += int(entry.cycle)
			var mask := int(entry.mask)
			if String(garden.plot_info(mask).timing).contains("queued"):
				saw_queue = true
				waiting_frames[mask] = int(waiting_frames.get(mask, 0)) + 1
				check(int(waiting_frames[mask]) <= Garden.MAX_RESIDENT, "FIFO repeat queue gives every expired plot a turn within the bounded cohort")
			else: waiting_frames.erase(mask)
		check(after - before <= Garden.RESTARTS_PER_FRAME, "eight catch-up ticks cannot multiply harmless cycle preparation per rendered frame")
		if after > before: saw_restart = true
	check(saw_queue and saw_restart, "cohort resets are visibly queued and continue making bounded progress")
	for entry: Dictionary in garden.render_entries():
		check(int(entry.cycle) >= 1, "no visible plot is starved by restart ordering")
		check((entry.court as HexChemistryWorld).conservation_valid(), "queued repeat cycles conserve their independently funded source history")


func _test_production_sample_dispatch() -> void:
	var surface := Surface.new()
	var probe := SampleDispatchProbe.new()
	surface._draw_sample(null, "flood", Vector2i.ZERO, {}, probe, 0.0, false)
	equal(probe.selected, "shared/flood", "Frostway keeps production glacier grammar despite its historical flood layer name")
	surface._draw_sample(null, "conflagration", Vector2i.ZERO, {}, probe, 0.0, false)
	equal(probe.selected, "mirror/conflagration", "Fire self-reaction retains its actual production mirror grammar")


func _test_far_garden_bounds() -> void:
	var garden := Garden.new()
	check(garden.configure(_rows()), "far-view broadphase fixture configures")
	var far := Rect2(6000, 6000, 200, 200)
	check(garden.step(far, far.get_center()), "distant view remains a valid exhibition step")
	check(garden.render_entries().is_empty() and garden.nearest_info(far.get_center()).is_empty(), "distant broadphase admits no plot and invents no inspection")
	var center: Vector2 = garden.plot_info(63).center
	var touching := Rect2(center + Vector2(Garden.PLOT_RADIUS, -1), Vector2(1, 2))
	check(garden.step(touching, center), "view touching the exact outer admission boundary is not rejected")
	equal(garden.render_entries().size(), 1, "inclusive broadphase retains original one-plot boundary admission")
	equal(int(garden.nearest_info(center + Vector2(Garden.INSPECTION_RADIUS, 0)).get("mask", 0)), 63, "exact maximum inspection distance remains inclusive")
	check(garden.nearest_info(center + Vector2(Garden.INSPECTION_RADIUS + 0.25, 0)).is_empty(), "inspection outside the exact outer bound stays empty")
	check(garden.step(far, far.get_center()), "leaving the Garden enters the broadphase fast path")
	check(garden.render_entries().is_empty() and garden._restart_queue.is_empty(), "distant transition retires all live exhibits and repeat work")
	check(garden.step(touching, center), "return after distant suspension starts fresh authority")
	equal(int(garden.render_entries()[0].cycle), 0, "distant suspension does not silently advance or revive an old cycle")


func _test_cached_inspection() -> void:
	var garden := Garden.new()
	check(garden.configure(_rows()), "cached-inspection fixture configures")
	var presenter := Presenter.new()
	var info := garden.plot_info(63)
	var font := ThemeDB.fallback_font
	for viewport: Vector2 in [Vector2(1280, 720), Vector2(960, 540), Vector2(340, 720)]:
		for phase: String in ["forming", "active", "decaying", "resetting"]:
			info.phase = phase
			info.phase_label = "Mixture field · " + phase.capitalize()
			info.timing = "Expired · queued to repeat." if phase == "resetting" else "0.1s to next phase · 4.0s finite cycle"
			var point := Vector2(viewport.x - 200, 190)
			equal(presenter.inspection_geometry(info, viewport, font, point, 118), Presenter.card_geometry(info, viewport, font, point, 118), "cached text preserves exact current phase/timing and responsive card placement")
			var builds := int(presenter._card_text_builds)
			presenter.inspection_geometry(info, viewport, font, point, 118)
			equal(int(presenter._card_text_builds), builds, "unchanged inspection text is never wrapped again")
			info.timing = "0.0s to next phase · 4.0s finite cycle"
			equal(presenter.inspection_geometry(info, viewport, font, Vector2.ZERO, 118), Presenter.card_geometry(info, viewport, font, Vector2.ZERO, 118), "countdown text and moving avoidance position cannot inherit a prior layout")
	for index: int in Presenter.CARD_TEXT_LIMIT + 1:
		presenter._wrapped_card_text("Distinct bounded row %d" % index, font, 12, 324)
	check(presenter._card_text.size() <= Presenter.CARD_TEXT_LIMIT and presenter._card_text_order.size() <= Presenter.CARD_TEXT_LIMIT, "inspection text reuse has an explicit bounded residency cap")


func _assert_ground_render(renderer: HexCourtPresenter, court: HexChemistryWorld, tick: int) -> void:
	check(renderer._prepare_court(court, false), "actual presenter accepts isolated Hex authority")
	var bundle := renderer._prepare_frame_bundle(court, float(tick))
	var regions := 0
	for material: String in bundle.regions:
		for cell: Vector2i in bundle.regions[material]:
			regions += bundle.regions[material][cell].size()
			for vertex: Vector2 in court.whole_cell_polygon(cell):
				check(Vector2(court.origin).distance_to(vertex) <= 110000.0, "real ground coverage stays inside bounded exhibit pad")
	check(regions > 0, "plot exposes actual nonempty production material polygons, not only a nameplate")


func _assert_card(info: Dictionary) -> void:
	var font := ThemeDB.fallback_font
	# Bootstrap clamps UI scale to at least 1.0: both supported sizes use their actual pixel dimensions.
	for physical: Vector2 in [Vector2(1280, 720), Vector2(960, 540)]:
		var viewport := physical
		var geometry := Presenter.card_geometry(info, viewport, font)
		var box: Rect2 = geometry.box
		if String(info.get("demonstration", "")) == "self":
			var sources := String(info.ingredients).split(" + ")
			check(sources.size() == 2 and sources[0] == sources[1], "matching-source card explicitly names both ingredients")
		if String(info.get("demonstration", "")) == "raw":
			check(String(info.name) not in geometry.body, "single ingredient does not duplicate its title as a body row")
			if int(info.mask) != 2: check(not " ".join(geometry.body).contains("Counter:"), "inert raw matter does not present a redundant threat counter")
		check(Rect2(Vector2.ZERO, viewport).encloses(box) and box.end.y < viewport.y - 90, "every actual garden card fits above bottom controls at both supported native sizes")
		for screen: Vector2 in [Vector2(1280,720), Vector2(960,540)]:
			for fraction: float in [0.25,0.5,0.8]:
				var inspected := Vector2(screen.x * fraction, 220)
				var relocated := Presenter.card_geometry(info, screen, font, inspected, 88.5)
				check(not (relocated.box as Rect2).intersects(Rect2(inspected - Vector2.ONE * 88.5,Vector2.ONE * 177.0)), "nearby explanation never covers the inspected plot at clamped camera edges or center")
		for line: String in geometry.title: check(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x <= box.size.x - 24, "complete actual title fits its authored 15px font")
		for line: String in geometry.body: check(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x <= box.size.x - 24, "allactual ingredients,phase,effect,counter,timing fit without truncation")
		check(" ".join(geometry.body).contains("Bounded, harmless exhibit.") and " ".join(geometry.body).contains("Your spells stay live."), "compact card distinguishes harmless exhibition from the player's live combat effects")


func _test_visible_budget_and_isolation() -> void:
	var garden := Garden.new()
	check(garden.configure(_rows()), "visibility fixture configures")
	var viewport := Rect2(608, 680, 1280.0 / 0.75, 720.0 / 0.75)
	check(garden.step(viewport, viewport.get_center()), "largest current native camera admits every visible lattice plot")
	var expected := 0
	for row: Dictionary in garden.plots():
		if Rect2(row.center - Vector2.ONE * 180, Vector2.ONE * 360).intersects(viewport, true): expected += 1
	equal(garden.render_entries().size(), expected, "no actually visible plot is silently discarded by nearest sorting")
	check(expected <= 40, "reviewed1280 view stays under40 isolated courts")
	var first: HexChemistryWorld = garden.render_entries()[0].court
	var before := first.state_hash()
	check(not garden.step(Rect2(0, 0, 0, 0), Vector2.ZERO), "empty diagnostic view refuses atomically")
	equal(first.state_hash(), before, "invalid view refusal never advances or resets existing field state")
	check(garden.step(Rect2(0, 0, 7800, 7800), Vector2.ZERO), "larger desktop view admits the whole finite garden without empty visible plots")
	equal(garden.render_entries().size(), 63, "all63 authored plots remain visible together when a larger viewport includes them")
	var cells := 0
	for entry: Dictionary in garden.render_entries(): cells += (entry.court as HexChemistryWorld).cell_count()
	equal(cells, 3843, "even a whole garden view retains at most63 independent61-cell courts")
	check(garden.nearest_info(Vector2(7800, 7800)).is_empty(), "distant observer gets no persistent explanatory overlay")
	garden.clear()
	check(garden.render_entries().is_empty() and garden.plots().size() == 63, "mode exit retires transient authority but keeps validated map directory")
	check(garden.step(Rect2(490, 490, 20, 20), Vector2(500, 500)), "returning to Wellspring restarts exhibits without reloading content")
	var actor := PlayerState.new(1)
	var original := actor.canonical_values()
	var saved_weave := {"sentinel": [140, 145]}
	var saved_before := saved_weave.duplicate(true)
	for unused: int in 10: check(garden.step(Rect2(490, 490, 20, 20), Vector2(500, 500)), "isolated exhibition keeps advancing normally")
	equal(actor.canonical_values(), original, "exhibition has no reference to mutate player Health, Flux, Stamina, cooldowns, statuses or weave")
	equal(saved_weave, saved_before, "exhibition receives no persistent storage or reward reference")
