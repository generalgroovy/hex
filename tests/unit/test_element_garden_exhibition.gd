extends FluxTestSuite

const Garden = preload("res://src/app/element_garden_exhibition.gd")
const Presenter = preload("res://src/presentation/element_garden_presenter.gd")
const Surface = preload("res://src/presentation/element_garden_surface.gd")
const Mixtures = preload("res://src/content/mixture_catalog.gd")
const Policy = preload("res://src/sim/hex/hex_recipe_policy.gd")
const ExhibitCourt = preload("res://src/app/element_garden_court.gd")

class OrdinaryGarden extends Garden:
	# Independent pre-memo constructor: actual concrete production chemistry.
	func _new_entry(mask: int) -> Dictionary:
		var court := HexChemistryWorld.new()
		var center: Vector2 = _by_mask[mask].center
		if not court.configure_geometry(Vector2i(center * 1000.0), HexGrid.disk(Vector2i.ZERO, TOPOLOGY_RADIUS)): return {}
		court.chemistry_enabled = true
		var entry := {"court": court, "tick": 0, "cycle": 0, "started": 0, "expiry": 0, "mode": ""}
		return entry if _emit_cycle(mask, entry) else {}

class CountedGarden extends Garden:
	var entry_creations := 0
	var cycle_emissions := 0
	func _new_entry(mask: int) -> Dictionary:
		entry_creations += 1
		return super._new_entry(mask)
	func _emit_cycle(mask: int, entry: Dictionary) -> bool:
		cycle_emissions += 1
		return super._emit_cycle(mask, entry)

class SampleDispatchProbe extends HexCourtPresenter:
	var selected := ""
	func _draw_shared_material(_canvas: CanvasItem, _regions: Dictionary, material: String, _tick: float, _reduced: bool) -> void:
		selected = "shared/" + material
	func _draw_mirror_product(_canvas: CanvasItem, _regions: Dictionary, material: String, _tick: float, _reduced: bool) -> void:
		selected = "mirror/" + material

class CountedArrivalPresenter extends Presenter:
	var preparation_calls := 0
	func _prepare_arrival_entry(entry: Dictionary, reduced: bool) -> bool:
		preparation_calls += 1
		return super._prepare_arrival_entry(entry, reduced)


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
	_test_exact_spatial_reuse()
	_test_selection_memo_contract()
	_test_memo_all_mixture_lifecycles()
	_test_staged_arrival_equivalence()
	_test_staged_arrival_cancellation()
	_test_arrival_presentation_invalidation()
	_test_arrival_font_lifetime()
	return finish("element-garden-exhibition")


func _test_staged_arrival_equivalence() -> void:
	var garden := CountedGarden.new()
	var control := OrdinaryGarden.new()
	var rows := _rows()
	var view := Rect2(0, 0, 3400, 3000)
	var observer: Vector2 = rows[0].center
	var language := VisualLanguage.new()
	var presenter := CountedArrivalPresenter.new()
	var cold := Presenter.new()
	check(language.load_from_file() and presenter.configure(language) and cold.configure(language), "staged visuals and ordinary first-draw control use the real configured material renderer")
	check(garden.configure(rows) and control.configure(rows), "staged and independent concrete Garden configure all63 plots")
	check(control.step(view, observer), "concrete predecessor admits the complete first-visible state synchronously")
	check(garden.request_arrival(view, observer), "explicit arrival requests detached preparation")
	equal(int(garden.arrival_status().required), 63, "the full view requires all63 plots without silently culling any")
	for prepared: int in range(1, 64):
		garden.begin_frame()
		presenter.begin_frame()
		check(garden.prepare_arrival(), "one current-frame preparation call succeeds")
		check(garden.prepare_arrival() and garden.prepare_arrival(), "repeated pumps share the same frame construction budget")
		equal(garden.entry_creations, prepared, "each rendered frame constructs exactly one genuinely funded exhibition")
		equal(garden.cycle_emissions, prepared, "preparation emits each first cycle exactly once")
		var status: Dictionary = garden.arrival_status()
		var entries: Array[Dictionary] = garden.arrival_render_entries()
		equal(entries.size(), prepared, "unpublished render projection includes only actually funded entries")
		var projected: Dictionary = entries[-1]
		var projected_hash: String = (projected.court as HexChemistryWorld).state_hash()
		check(presenter.prepare_arrival(entries, 63, false), "one real visual preparation succeeds without publishing chemistry")
		check(presenter.prepare_arrival(entries, 63, false), "a second presentation pump shares the same frame budget")
		equal(presenter._plaques.size(), prepared, "arrival text cache contains only the currently available requested labels")
		equal(presenter.preparation_calls, prepared, "funded and visual preparation each perform at most one entry per frame")
		equal(int(presenter.arrival_status().prepared), prepared, "visual readiness includes every and only prepared current entry")
		equal(bool(presenter.arrival_status().ready), prepared == 63, "visual readiness cannot omit unavailable required entries")
		equal((projected.court as HexChemistryWorld).state_hash(), projected_hash, "surface and plaque preparation do not mutate the borrowed paid court")
		projected.name = "caller mutation"
		projected.phase = "caller mutation"
		check(String(garden.arrival_render_entries()[-1].name) != "caller mutation" and String(garden.arrival_render_entries()[-1].phase) != "caller mutation", "unpublished projection metadata is detached from Garden ownership")
		equal(int(status.prepared), prepared, "readiness counts only completed concrete entries")
		equal(int(status.remaining), 63 - prepared, "remaining count includes every not-yet-prepared visible plot")
		equal(int(status.total_courts), prepared, "detached authority stays within the63-court combined bound")
		equal(bool(status.ready), prepared == 63, "partial preparation never declares an incomplete view ready")
		check(garden.render_entries().is_empty(), "unpublished preparation cannot leak an early visible field")
		equal(String(garden.plot_info(1).phase), "offscreen", "inspection cannot expose unpublished authority")
		check(garden.request_arrival(view, observer), "identical arrival intent is idempotent")
		equal(garden.entry_creations, prepared, "repeated arrival intent never constructs or refunds a source")
	check(garden.publish_arrival(), "complete preparation publishes atomically before any simulation step")
	equal(garden.render_entries().size(), 63, "zero-step first rendered frame already contains every visible plot")
	_assert_arrival_visuals(presenter, cold, garden.render_entries(), control.render_entries(), false)
	for mask: int in range(1, 64): _assert_memo_entry_equal(garden, control, mask)
	var emissions := garden.cycle_emissions
	for unused: int in 3:
		garden.begin_frame()
		for mask: int in range(1, 64):
			equal(int(garden._resident[mask].tick), 0, "rendered frames without fixed steps never age a published arrival")
			check((garden._resident[mask].court as HexChemistryWorld).conservation_valid(), "waiting publication retains finite exhibition conservation")
	check(garden.step(view, observer), "first real step consumes the prepared admission once")
	_assert_arrival_visuals(presenter, cold, garden.render_entries(), control.render_entries(), false)
	for mask: int in range(1, 64): _assert_memo_entry_equal(garden, control, mask)
	# The control's first step admitted at tick0. Subsequent catch-up ticks must
	# advance both exactly once, without multiplying preparation or emissions.
	for tick: int in range(1, 9):
		check(garden.step(view, observer) and control.step(view, observer), "ordinary catch-up advances staged and direct authorities together")
		for mask: int in range(1, 64):
			equal(int(garden._resident[mask].tick), tick, "one-use arrival admission cannot suppress later lifecycle ticks")
			_assert_memo_entry_equal(garden, control, mask)
		if tick == 8: _assert_arrival_visuals(presenter, cold, garden.render_entries(), control.render_entries(), true)
	equal(garden.entry_creations, 63, "publication and catch-up never recreate a prepared court")
	equal(garden.cycle_emissions, emissions, "adoption never adds another paid exhibition cycle")
	check(int(garden.arrival_status().total_courts) <= 63, "published ownership remains bounded after all markers are consumed")
	equal(presenter.preparation_calls, 63, "normal first draw and catch-up never invoke staged preparation again")
	presenter.cancel_arrival()
	equal(int(presenter._surface.diagnostics().resident), 0, "cancel without published entries releases staged surface caches")
	equal(presenter._plaques.size(), 0, "cancel without published entries releases staged text layouts")
	equal(int(presenter.arrival_status().prepared), 0, "cancel releases local arrival readiness")


func _assert_arrival_visuals(warm: RefCounted, cold: RefCounted, actual: Array[Dictionary], expected: Array[Dictionary], reduced: bool) -> void:
	equal(actual.size(), expected.size(), "prepared and ordinary first draw have equal entry counts")
	for index: int in mini(actual.size(), expected.size()):
		var a: Dictionary = actual[index]
		var b: Dictionary = expected[index]
		for key: String in ["mask", "center", "tick", "phase", "name", "ingredients", "material", "cycle", "decay"]:
			equal(a[key], b[key], "prepared visual projection preserves exact ordinary " + key)
		var before: String = (a.court as HexChemistryWorld).state_hash()
		var retained: Dictionary = warm._surface.prepare(a, warm._ground, reduced)
		var direct: Dictionary = cold._surface.prepare(b, cold._ground, reduced)
		for key: String in ["boundary", "cells", "sample_cells", "samples", "style", "style_key", "sample_phase", "native_opacity"]:
			equal(retained[key], direct[key], "staged surface matches current ordinary geometry/phase/style " + key)
		for key: String in ["mesh", "native_mesh"]:
			var left: ArrayMesh = retained[key]
			var right: ArrayMesh = direct[key]
			equal(left == null, right == null, "valid empty material has the same absence of geometry")
			if left != null and right != null:
				equal(left.get_surface_count(), right.get_surface_count(), "prepared and ordinary mesh surface counts agree")
				for surface: int in mini(left.get_surface_count(), right.get_surface_count()):
					equal(left.surface_get_arrays(surface), right.surface_get_arrays(surface), "prepared mesh retains exact ordinary vertices, UVs and indices")
		var label := String(a.name)
		var line := TextLine.new()
		line.add_string(label, ThemeDB.fallback_font, 14)
		var width := minf(234.0, line.get_size().x + 20.0)
		line.width = width - 20.0
		line.alignment = HORIZONTAL_ALIGNMENT_CENTER
		check(warm._plaques.has(label), "staging prepared the actual visible plaque before first draw")
		if warm._plaques.has(label):
			equal(float(warm._plaques[label].width), width, "prepared plaque preserves original independent shaping width")
			equal((warm._plaques[label].line as TextLine).get_size(), line.get_size(), "prepared plaque preserves original independent text layout")
			equal((warm._plaques[label].line as TextLine).get_line_ascent(), line.get_line_ascent(), "prepared plaque preserves original independent baseline")
		equal((a.court as HexChemistryWorld).state_hash(), before, "reading prepared display leaves finite authority untouched")


func _test_arrival_presentation_invalidation() -> void:
	var language := VisualLanguage.new()
	var presenter := CountedArrivalPresenter.new()
	var cold := Presenter.new()
	check(language.load_from_file() and presenter.configure(language) and cold.configure(language), "visual invalidation uses the actual configured renderer")
	var garden := Garden.new()
	check(garden.configure(_rows()), "visual invalidation configures a real finite Backdraft exhibit")
	var center: Vector2 = garden.plot_info(34).center
	var view := Rect2(center - Vector2.ONE, Vector2.ONE * 2)
	check(garden.step(view, center), "phase fixture admits through ordinary paid exhibition funding")
	var entries: Array[Dictionary] = garden.render_entries()
	presenter.begin_frame()
	check(presenter.prepare_arrival(entries, 1, false) and bool(presenter.arrival_status().ready), "initial current phase is prepared")
	var calls := presenter.preparation_calls
	check(presenter.prepare_arrival(entries, 1, false), "identical current input is idempotent")
	equal(presenter.preparation_calls, calls, "same-frame duplicate input does not spend another visual preparation")
	var exposed: Dictionary = presenter.arrival_status()
	exposed.prepared = 63
	equal(int(presenter.arrival_status().prepared), 1, "caller mutation of readiness diagnostics cannot admit missing fields")
	presenter.cancel_arrival(entries)
	check(presenter.prepare_arrival(entries, 1, false), "same-frame canceled request can remain valid but incomplete")
	equal(presenter.preparation_calls, calls, "cancellation never refunds a frame's already spent visual preparation budget")
	check(not bool(presenter.arrival_status().ready), "cleared readiness cannot be republished without real preparation")
	presenter.begin_frame()
	check(presenter.prepare_arrival(entries, 1, false) and bool(presenter.arrival_status().ready), "the next actual frame can prepare the canceled entry again")
	var entry: Dictionary = garden._resident[34]
	var boundaries: Array[int] = [int(entry.active), int(entry.decay) - 72, int(entry.decay), int(entry.expiry)]
	for boundary: int in boundaries:
		while int(garden._resident[34].tick) < boundary:
			check(garden.step(view, center), "phase test advances ordinary clocks without injecting material or timers")
		entries = garden.render_entries()
		for reduced: bool in [false, true]:
			presenter.begin_frame()
			calls = presenter.preparation_calls
			check(presenter.prepare_arrival(entries, 1, reduced), "changed current phase/style has a bounded valid preparation")
			check(bool(presenter.arrival_status().ready), "each finite current phase including empty expiry can become ready")
			equal(presenter.preparation_calls, calls + 1, "phase or reduced-effects invalidation performs exactly one fresh visual preparation")
			_assert_arrival_visuals(presenter, cold, entries, entries, reduced)
			if boundary == int(entry.expiry):
				check(presenter._surface.prepare(entries[0], presenter._ground, reduced).mesh == null, "expired authority prepares valid empty visuals without reviving a field")
	# Configuration and font changes invalidate derived text/readiness even
	# when every chemistry scalar remains identical. Restore the global font.
	check(presenter.configure(language), "renderer reconfiguration retains its normal validated language path")
	equal(int(presenter.arrival_status().prepared), 0, "configure cannot retain stale arrival readiness")
	presenter.begin_frame()
	check(presenter.prepare_arrival(entries, 1, false), "unchanged expired court can prepare after configuration reset")
	var original_font: Font = ThemeDB.fallback_font
	var replacement_font: Font = original_font.duplicate()
	ThemeDB.fallback_font = replacement_font
	presenter.begin_frame()
	calls = presenter.preparation_calls
	check(presenter.prepare_arrival(entries, 1, false), "a different font instance reshapes current plaques")
	equal(presenter.preparation_calls, calls + 1, "font replacement cannot reuse old text readiness")
	_assert_arrival_visuals(presenter, cold, entries, entries, false)
	replacement_font.emit_changed()
	presenter.begin_frame()
	calls = presenter.preparation_calls
	check(presenter.prepare_arrival(entries, 1, false), "same-instance font mutation is observed")
	equal(presenter.preparation_calls, calls + 1, "font Resource.changed invalidates readiness without replacing its object")
	ThemeDB.fallback_font = original_font
	presenter.cancel_arrival(entries)
	equal(int(presenter.arrival_status().prepared), 0, "arrival cancellation clears readiness independently from resident visuals")
	equal(int(presenter._surface.diagnostics().resident), 1, "cancellation may retain the current published empty-phase surface only")
	equal(presenter._plaques.keys(), [String(entries[0].name)], "cancellation retains only the actual published plaque label")
	var replacement := Garden.new()
	check(replacement.configure(_rows()) and replacement.step(view, center), "replacement world owns a new genuine source at the same plot")
	entries = replacement.render_entries()
	presenter.begin_frame()
	calls = presenter.preparation_calls
	check(presenter.prepare_arrival(entries, 1, false), "new court identity cannot inherit expired readiness")
	equal(presenter.preparation_calls, calls + 1, "world replacement prepares its new current authority")
	_assert_arrival_visuals(presenter, cold, entries, entries, false)
	presenter.cancel_arrival()
	equal(int(presenter._surface.diagnostics().resident), 0, "canceling all views removes retained surface entries")
	equal(presenter._plaques.size(), 0, "canceling all views removes retained arrival labels")
	equal(int(presenter._surface.diagnostics().retained_geometry), 0, "canceling all views removes last-nonempty geometry as well")
	var unconfigured := Presenter.new()
	unconfigured.begin_frame()
	check(not unconfigured.prepare_arrival(entries, 1, false), "an unconfigured presenter refuses instead of claiming prepared visuals")
	check(not String(unconfigured.arrival_status().error).is_empty(), "presentation refusal is distinguishable from ordinary incomplete readiness")


func _test_arrival_font_lifetime() -> void:
	# A real retained Font must not keep its observer alive. Release the same
	# subclass used by staged preparation, then emit after target destruction;
	# the strict stderr gate also rejects an invalid callback or PREDELETE call.
	var font: Font = ThemeDB.fallback_font.duplicate()
	var initial_connections: int = font.changed.get_connections().size()
	var presenter: CountedArrivalPresenter = CountedArrivalPresenter.new()
	presenter._observe_plaque_font(font)
	equal(font.changed.get_connections().size(), initial_connections + 1, "live presenter subscribes to the actual retained font resource")
	var observer: WeakRef = weakref(presenter)
	presenter = null
	check(observer.get_ref() == null, "font signal subscription cannot retain a released presentation observer")
	equal(font.changed.get_connections().size(), initial_connections, "released observer is disconnected from the still-live font")
	font.emit_changed()
	equal(font.changed.get_connections().size(), initial_connections, "post-release font mutation invokes no dead observer or new subscription")


func _test_staged_arrival_cancellation() -> void:
	var garden := CountedGarden.new()
	var control := OrdinaryGarden.new()
	var rows := _rows()
	var all := Rect2(0, 0, 3400, 3000)
	var first: Vector2 = rows[0].center
	var last: Vector2 = rows[62].center
	var first_view := Rect2(first - Vector2.ONE, Vector2.ONE * 2)
	var last_view := Rect2(last - Vector2.ONE, Vector2.ONE * 2)
	check(garden.configure(rows) and control.configure(rows), "cancellation fixture admits the ordinary directory")
	check(garden.request_arrival(all, first), "partial destination starts through explicit arrival API")
	for unused: int in 3:
		garden.begin_frame()
		check(garden.prepare_arrival(), "partial destination creates finite entries without publishing")
	check(garden.request_arrival(last_view, last), "resize or superseded exact view replaces the old request")
	equal(int(garden.arrival_status().required), 1, "replacement demand contains only the actual new view")
	equal(int(garden.arrival_status().total_courts), 0, "changed view releases every unpublished old-generation court")
	garden.begin_frame()
	check(garden.prepare_arrival() and garden.publish_arrival(), "replacement view completes and publishes its sole requested plot")
	check(control.step(last_view, last), "independent direct replacement supplies exact comparison")
	equal(garden._resident.keys(), [63], "superseded destination never publishes stale plots")
	_assert_memo_entry_equal(garden, control, 63)
	check(garden.step(last_view, last), "replacement first step consumes its own admission")
	for unused: int in 3: check(garden.step(last_view, last) and control.step(last_view, last), "existing resident acquires a real finite age")
	var retained_hash := (garden._resident[63].court as HexChemistryWorld).state_hash()
	var retained_tick := int(garden._resident[63].tick)
	check(garden.request_arrival(all, first), "another arrival may prepare beside an existing resident")
	garden.begin_frame()
	check(garden.prepare_arrival(), "new detached entry is funded separately from existing resident")
	check(int(garden.arrival_status().total_courts) <= 63, "resident and unpublished entries share the combined world bound")
	garden.cancel_arrival()
	check(not bool(garden.arrival_status().active), "explicit cancellation ends the arrival latch")
	equal(int(garden.arrival_status().total_courts), 1, "cancellation releases detached entries but retains existing resident")
	equal((garden._resident[63].court as HexChemistryWorld).state_hash(), retained_hash, "canceling another destination cannot rewind or replace a live exhibit")
	equal(int(garden._resident[63].tick), retained_tick, "preparation and cancellation do not age existing residents")
	check(garden.step(first_view, first), "unexpected direct step keeps ordinary synchronous admission")
	check(control.step(first_view, first), "concrete baseline follows the same direct view change")
	_assert_memo_entry_equal(garden, control, 1)
	check(not bool(garden.arrival_status().active), "direct walking-style admission never invents an arrival wait")
	check(garden.request_arrival(all, first), "direct fallback control begins a real partial preparation")
	garden.begin_frame()
	check(garden.prepare_arrival(), "direct fallback owns unpublished funded work before being interrupted")
	check(garden.step(last_view, last) and control.step(last_view, last), "unexpected direct step cancels partial work and retains synchronous admission")
	check(not bool(garden.arrival_status().active), "partial request cannot survive an ordinary direct step")
	equal(int(garden.arrival_status().total_courts), 1, "direct fallback releases unrelated unpublished courts")
	_assert_memo_entry_equal(garden, control, 63)
	for reset_kind: String in ["clear", "configure"]:
		check(garden.request_arrival(all, first), "reset case begins a new explicit preparation")
		garden.begin_frame()
		check(garden.prepare_arrival(), "reset case owns a real detached entry")
		if reset_kind == "clear": garden.clear()
		else: check(garden.configure(rows), "directory replacement validates before reuse")
		check(not bool(garden.arrival_status().active), "mode or directory reset clears pending arrival")
		equal(int(garden.arrival_status().total_courts), 0, "reset releases staged and published exhibition authority")
		check(garden.render_entries().is_empty(), "reset cannot retain stale first-frame fields")


func _test_selection_memo_contract() -> void:
	var memo := ExhibitCourt.SelectionMemo.new()
	var canonical := HexGrid.disk(Vector2i.ZERO, Garden.TOPOLOGY_RADIUS)
	for origin_value: Vector2i in [Vector2i.ZERO, Vector2i(2_345_000, 1_555_000), Vector2i(-3_000_000, -2_000_000), Vector2i(7_750_000, 7_750_000)]:
		var court := ExhibitCourt.new(memo)
		var ordinary := HexChemistryWorld.new()
		check(court.configure_geometry(origin_value, canonical) and ordinary.configure_geometry(origin_value, canonical), "memo and ordinary court admit identical complete topology at translated origins")
		for shape: Dictionary in [HexFootprint.disk(origin_value, 0), HexFootprint.disk(origin_value, 34_000),
				HexFootprint.capsule(origin_value, origin_value + Vector2i(135_000, 0), 14_000), HexFootprint.annulus(origin_value, 40_000, 60_000)]:
			var expected := ordinary.select_cells(shape)
			var actual := court.select_cells(shape)
			equal(actual, expected, "relative memo preserves exact canonical order and positive-area membership at each world origin")
			actual.clear()
			actual.append(Vector2i(99, 99))
			equal(court.select_cells(shape), expected, "consumer mutation cannot poison retained selected cells")
			equal(court.state_hash(), ordinary.state_hash(), "selection and cache reads do not alter authority or geometry")
	check(int(memo.stats().hits) > 20 and int(memo.stats().resident) == 4, "translated identical shapes actually share only four bounded derived records")

	var center := Vector2i(500_000, 500_000)
	var guarded := ExhibitCourt.new(memo)
	var control := HexChemistryWorld.new()
	check(guarded.configure_geometry(center, canonical) and control.configure_geometry(center, canonical), "fallback fixture admits canonical geometry")
	var disk := HexFootprint.disk(center, 34_000)
	guarded.select_cells(disk)
	var hits := int(memo.stats().hits)
	var eligible := {Vector2i.ZERO: true}
	equal(guarded.select_cells(disk, eligible), control.select_cells(disk, eligible), "explicit eligible subset remains authoritative")
	var walls := CollisionWorld.new(2_000_000, 2_000_000)
	walls.add_obstacle(CollisionWorld.Obstacle.new(1, center.x + 5000, center.y - 100_000, center.x + 15_000, center.y + 100_000))
	guarded.collision = walls
	control.collision = walls
	var visible := control.select_cells(disk)
	check(visible.size() < HexFootprint.selected_cells(disk, center, control.topology_cells_view()).size(), "collision fallback positive control actually removes occluded cells")
	equal(guarded.select_cells(disk), visible, "a newly added wall cannot reuse unoccluded cached cells")
	guarded.collision = null
	control.collision = null
	for shape: Dictionary in [HexFootprint.sector(center, Vector2i(1000, 0), 75_000, 820_000),
			HexFootprint.intersection(disk, HexFootprint.disk(center + Vector2i(12_000, 0), 34_000)),
			{"kind": "unknown"}, {"kind": "disk", "center": center, "radius": 34_000, "future": true},
			{"kind": "disk", "center": center, "radius": 34_000.0}]:
		equal(guarded.select_cells(shape), control.select_cells(shape), "unknown, extra-field, noninteger and unproven primitive paths keep ordinary semantics")
	equal(int(memo.stats().hits), hits, "excluded paths never count as memo hits")

	var far := ExhibitCourt.new(memo)
	check(far.configure_geometry(Vector2i(7_800_000, 0), canonical), "near-world-bound topology remains valid")
	var local := ExhibitCourt.new(memo)
	check(local.configure_geometry(Vector2i.ZERO, canonical), "local counterpart admits same relative shape")
	var local_shape := HexFootprint.disk(Vector2i(250_000, 0), 256_000)
	check(not local.select_cells(local_shape).is_empty(), "valid local query supplies a positive cached footprint")
	hits = int(memo.stats().hits)
	check(far.select_cells(HexFootprint.disk(Vector2i(8_050_000, 0), 256_000)).is_empty(), "original absolute world bounds reject before matching a valid relative cache key")
	equal(int(memo.stats().hits), hits, "invalid absolute query cannot consume a cached valid relative footprint")

	var edited: Dictionary = guarded.cells
	edited.erase(Vector2i.ZERO)
	edited[Vector2i(5, 0)] = {"terrain": 0, "elevation": 0, "structure": 0}
	control.cells = edited.duplicate(true)
	equal(guarded.cell_count(), 61, "changed topology keeps the same count to challenge identity-only admission")
	equal(guarded.select_cells(disk), control.select_cells(disk), "writable topology detachment rejects previous cache eligibility even with identical cell count")
	var translated_cells: Array[Vector2i] = []
	for cell: Vector2i in canonical: translated_cells.append(cell + Vector2i(1, 0))
	var translated := ExhibitCourt.new(memo)
	check(translated.configure_geometry(center, translated_cells), "same-size translated topology is valid ordinary geometry")
	equal(translated.select_cells(disk), HexFootprint.selected_cells(disk, center, translated.topology_cells_view()), "full topology comparison refuses translated disk reuse")
	var relocated := ExhibitCourt.new(memo)
	check(relocated.configure_geometry(center, canonical), "origin replacement fixture admits")
	relocated.origin = center + Vector2i(30_000, 0)
	equal(relocated.select_cells(disk), HexFootprint.selected_cells(disk, relocated.origin, relocated.topology_cells_view()), "post-configuration origin mutation cannot retain stale relative eligibility")
	equal(int(memo.stats().hits), hits, "topology and origin fallback paths do not reuse retained selection")

	memo.clear()
	var bounded := ExhibitCourt.new(memo)
	check(bounded.configure_geometry(Vector2i.ZERO, canonical), "bounded selection fixture admits")
	for index: int in range(ExhibitCourt.MAX_SELECTIONS + 3):
		var shape := HexFootprint.disk(Vector2i.ZERO, 20_000 + index)
		equal(bounded.select_cells(shape), HexFootprint.selected_cells(shape, Vector2i.ZERO, bounded.topology_cells_view()), "capacity overflow remains exact ordinary selection")
	equal(int(memo.stats().resident), ExhibitCourt.MAX_SELECTIONS, "selection cache saturates at64 shapes without eviction churn")
	hits = int(memo.stats().hits)
	bounded.select_cells(HexFootprint.disk(Vector2i.ZERO, 20_000))
	equal(int(memo.stats().hits), hits + 1, "saturation preserves earlier resident selection")
	memo.clear()
	equal(memo.stats(), {"resident": 0, "hits": 0, "misses": 0, "fallbacks": 0}, "memo reset releases geometry and all diagnostic counters")


func _test_memo_all_mixture_lifecycles() -> void:
	var garden := Garden.new()
	var ordinary := OrdinaryGarden.new()
	var rows := _rows()
	for row: Dictionary in rows: row.center += Vector2(1800, 900)
	check(garden.configure(rows) and ordinary.configure(rows), "full memo/control matrix configures translated real plots")
	for mask: int in range(1, 64):
		var center: Vector2 = garden.plot_info(mask).center
		var view := Rect2(center - Vector2.ONE, Vector2.ONE * 2)
		check(garden.step(view, center) and ordinary.step(view, center), "each current mixture begins from actual funded exhibition admission")
		for cycle: int in 2:
			var entry: Dictionary = garden._resident[mask]
			_assert_memo_entry_equal(garden, ordinary, mask)
			var expiry := int(entry.expiry)
			while int(entry.tick) < expiry:
				check(garden.step(view, center) and ordinary.step(view, center), "memo and concrete control advance actual finite ticks without granting matter")
				if int(entry.tick) in [int(entry.active), int(entry.decay) - 72, int(entry.decay), expiry]:
					_assert_memo_entry_equal(garden, ordinary, mask)
			check((entry.court as HexChemistryWorld).occupied_cells().is_empty(), "memo field naturally reaches complete finite expiry")
			if cycle == 0:
				for unused: int in Garden.RESET_TICKS:
					check(garden.step(view, center) and ordinary.step(view, center), "exact reset interval admits ordinary self/mixed repeat")
				equal(int(entry.cycle), 1, "each plot reaches its first genuinely funded repeat")
	check(int(garden._selection_memo.stats().hits) > 100, "all-mixture lifecycle actually exercises shared derived selection")
	check(int(garden._selection_memo.stats().resident) <= ExhibitCourt.MAX_SELECTIONS, "all63 masks and repeated states remain inside the fixed memo bound")
	var resident := int(garden._selection_memo.stats().resident)
	check(garden.step(Rect2(0, 0, 100, 100), Vector2.ZERO), "departure releases live exhibitions")
	check(garden._resident.is_empty(), "departure never retains mutable paid courts")
	equal(int(garden._selection_memo.stats().resident), resident, "ordinary departure retains only bounded derived geometry for a later visit")
	garden.clear()
	equal(int(garden._selection_memo.stats().resident), 0, "explicit mode/reset clear releases every derived selection")
	var center: Vector2 = rows[0].center
	check(garden.step(Rect2(center - Vector2.ONE, Vector2.ONE * 2), center), "fresh admission after clear rebuilds from the retained directory")
	check(int(garden._selection_memo.stats().resident) > 0, "fresh admission repopulates geometry only when requested")
	check(garden.configure(_rows()), "reconfiguration resets the same Garden instance")
	equal(garden._selection_memo.stats(), {"resident": 0, "hits": 0, "misses": 0, "fallbacks": 0}, "new directory cannot inherit another content generation's memo")


func _assert_memo_entry_equal(garden: RefCounted, ordinary: RefCounted, mask: int) -> void:
	equal(garden._resident.keys(), ordinary._resident.keys(), "memo never alters visible plot admission or ordering")
	var actual: Dictionary = garden._resident[mask]
	var expected: Dictionary = ordinary._resident[mask]
	for key: String in ["tick", "cycle", "started", "active", "decay", "expiry", "mode", "material"]:
		equal(actual[key], expected[key], "memo preserves exact real exhibition lifecycle metadata")
	var court: HexChemistryWorld = actual.court
	var reference: HexChemistryWorld = expected.court
	equal(court.state_hash(), reference.state_hash(), "complete ordinary chemistry authority remains exact through formation, danger, decay, expiry and repeat")
	check(court.conservation_valid() and reference.conservation_valid(), "both real exhibition ledgers conserve all paid matter")
	equal(garden.plot_info(mask), ordinary.plot_info(mask), "every phase keeps identical player-facing timing, identity and counter information")
	equal(court.occupied_cells(), reference.occupied_cells(), "memo preserves every owned ground cell")
	for cell: Vector2i in court.occupied_cells():
		equal(court.render_regions(cell, String(actual.material), float(actual.tick)), reference.render_regions(cell, String(expected.material), float(expected.tick)), "rendered ground preserves current geometry, owners, source IDs, damage and lifecycle cues")


func _test_exact_spatial_reuse() -> void:
	var garden := Garden.new()
	check(garden.configure(_rows()), "spatial reuse admits the fixed directory")
	var rows := garden.plots()
	for offset: float in [-0.25, 0.0, 0.25, 200.0, 800.0]:
		var view := Rect2(680 + offset, 300, 720, 540)
		var expected: Array[int] = []
		for row: Dictionary in rows:
			if Rect2(row.center - Vector2.ONE * 180.0, Vector2(360, 360)).intersects(view, true): expected.append(int(row.mask))
		for repeat: int in 3:
			garden.begin_frame()
			check(garden.step(view, view.get_center()), "repeated exact view advances exhibits")
			var actual: Array[int] = []
			for entry: Dictionary in garden.render_entries(): actual.append(int(entry.mask))
			equal(actual, expected, "fractional camera change and inclusive boundaries match an independent full-directory query")
			check(garden._visible_masks.is_read_only(), "spatial result cannot be accidentally edited by a consumer")
	var center: Vector2 = rows[0].center
	var view := Rect2(center - Vector2(80,80), Vector2(160,160))
	check(garden.step(view, center), "stationary observer admits nearest plot")
	var first := garden.nearest_info(center)
	for repeat: int in 12: check(garden.step(view, center), "stationary cache still advances the real exhibition clock")
	var later := garden.nearest_info(center)
	check(first.timing != later.timing, "nearest-mask reuse never retains stale phase timing")
	check(garden.step(Rect2(7400,7400,100,100), Vector2(7500,7500)), "leave cached visible area")
	check(garden._resident.is_empty(), "far view retires every cached-view resident")
	check(garden.step(view, center), "return to identical earlier rectangle readmits plots")
	check(not garden.nearest_info(center).is_empty(), "nearest query reenters correctly after an out-of-bounds miss")
	garden.clear()
	check(garden.step(view, center), "clear invalidates spatial keys without discarding the directory")
	equal(int(garden.nearest_info(center).mask), int(rows[0].mask), "clear retains correct nearest identity")
	var moved := _rows()
	for row: Dictionary in moved: row.center += Vector2(2000, 2000)
	check(garden.configure(moved), "new valid directory replaces the same instance")
	check(garden.step(view, center), "old rectangle remains a valid empty query after reconfiguration")
	check(garden.render_entries().is_empty() and garden.nearest_info(center).is_empty(), "reconfigure cannot reuse old view or observer answers")


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
			info.phase_label = "Mixture field Â· " + phase.capitalize()
			info.timing = "Expired Â· queued to repeat." if phase == "resetting" else "0.1s to next phase Â· 4.0s finite cycle"
			var point := Vector2(viewport.x - 200, 190)
			equal(presenter.inspection_geometry(info, viewport, font, point, 118), Presenter.card_geometry(info, viewport, font, point, 118), "cached text preserves exact current phase/timing and responsive card placement")
			var builds := int(presenter._card_text_builds)
			presenter.inspection_geometry(info, viewport, font, point, 118)
			equal(int(presenter._card_text_builds), builds, "unchanged inspection text is never wrapped again")
			info.timing = "0.0s to next phase Â· 4.0s finite cycle"
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
	for logical: Vector2 in [Vector2(640,360),Vector2(853,480)]:
		var readable := Presenter.card_geometry(info,logical,font)
		check(Rect2(Vector2.ZERO,logical).encloses(readable.box),"large-text Garden details reflow without leaving the logical screen")
		var explanation := " ".join(readable.body)
		check(explanation.contains("Harmless ground exhibit"),"Garden names the displayed ground exhibition as harmless")
		check(explanation.contains("actor statuses need paid damaging hits") and explanation.contains("Your spells stay live."),"Garden separates actor statuses from exhibits and requires real paid damage while preserving live player spells")
		check(explanation.contains("Menu > Spell Range tests this mixture"),"readable Garden card gives the actual selected-mixture testing route")
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
		check(" ".join(geometry.body).contains("Harmless ground exhibit") and " ".join(geometry.body).contains("Your spells stay live."), "compact card distinguishes harmless exhibition from the player's live combat effects")
		check(" ".join(geometry.body).contains("actor statuses need paid damaging hits"), "physical Garden card separates actual damaging-hit statuses from harmless ground exhibits")
		check(" ".join(geometry.body).contains("Menu > Spell Range tests this mixture"), "Garden card explains the actual selected-plot handoff")


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
