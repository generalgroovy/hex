extends SceneTree

const Builder := preload("res://scripts/build_character_style_pack.gd")
const Base := preload("res://reference/art/neutral_body_templates_v1/build_pack.gd")
var assertions := 0
var failures := 0


func _initialize() -> void:
	check(Builder.safe_path(Builder.ROOT + "pilot/candidate-v1"), "isolated output accepted")
	check(not Builder.safe_path("res://art_batches/character_style_v1/../live"), "parent escape rejected")
	check(not Builder.safe_path("res://src/presentation/live.png"), "live output rejected")
	var sources: Dictionary = {}
	for source_id: String in Base.PAGE_SPECS:
		var fixture := make_fixture(source_id)
		var before := Base.bytes_sha256(fixture.image.get_data())
		var result := Builder.inspect_source(fixture.image, fixture.entry)
		check(result.error == "", source_id + " explicit rectangles accepted")
		check(Base.bytes_sha256(fixture.image.get_data()) == before, source_id + " immutable original")
		check(result.import_mode == "solid_matte", source_id + " exact matte identified")
		check(result.original_alpha.minimum == 255, source_id + " original alpha recorded")
		sources[source_id] = result
	var assembled := Base.assemble(sources)
	check(assembled.error == "", "all80 cells assemble")
	if assembled.error == "":
		for body: String in Base.HEIGHTS:
			var atlas: Image = assembled.images[body]
			var frames: Array = assembled.manifest.bodies[body].frames
			check(atlas.get_size() == Vector2i(768, 960), body + " exact dimensions")
			check(frames.size() == 80, body + " all80 states/headings")
			for frame: Dictionary in frames:
				var bounds: Array = frame.output_visible_bounds
				check(int(bounds[1]) + int(bounds[3]) == 84, body + " foot pivot")
				check(bounds[0] >= 1 and bounds[1] >= 1 and bounds[0] + bounds[2] < 96, body + " complete gutter")
				var region: Array = frame.output_region
				check(atlas.get_pixel(int(region[0]), int(region[1])).a == 0.0, body + " transparent cell corner")
	var basic := make_fixture("cardinal_core")
	var alpha_image: Image = basic.image.duplicate()
	Base._remove_edge_matte(alpha_image, Color.MAGENTA)
	check(Builder.inspect_source(alpha_image, basic.entry).error == "", "actual alpha accepted")
	var wrong_matte: Image = basic.image.duplicate()
	wrong_matte.set_pixel(0, 0, Color("eb0aed"))
	check(Builder.inspect_source(wrong_matte, basic.entry).error != "", "near-magenta rejected, no tolerance")
	var checker: Image = basic.image.duplicate()
	checker.set_pixel(1, 0, Color("dddddd"))
	check(Builder.inspect_source(checker, basic.entry).error != "", "fake checkerboard rejected")
	var empty: Image = basic.image.duplicate()
	empty.fill_rect(Rect2i(0, 0, 16, 14), Color.MAGENTA)
	check(Builder.inspect_source(empty, basic.entry).error != "", "empty pose rejected")
	var clipped: Image = basic.image.duplicate()
	clipped.set_pixel(0, 3, Color.BLACK)
	check(Builder.inspect_source(clipped, basic.entry).error != "", "clipped pose rejected")
	var bad_entry: Dictionary = basic.entry.duplicate(true)
	bad_entry.cells[1].rect = bad_entry.cells[0].rect
	check(Builder.inspect_source(basic.image, bad_entry).error != "", "overlap rejected")
	bad_entry = basic.entry.duplicate(true)
	bad_entry.cells[1].direction = "south"
	check(Builder.inspect_source(basic.image, bad_entry).error != "", "duplicate semantic slot rejected")
	bad_entry = basic.entry.duplicate(true)
	bad_entry.id = "../escaped_mask"
	check(Builder.inspect_source(basic.image, bad_entry).error != "", "mask source identifier cannot escape outputfolder")
	var normalized_sources: Dictionary = sources.duplicate(true)
	normalized_sources.diagonal_phase_b.cell_width *= 2.0
	for pose: Dictionary in normalized_sources.diagonal_phase_b.poses:
		var enlarged: Image = pose.image.duplicate()
		enlarged.resize(enlarged.get_width() * 2, enlarged.get_height() * 2, Image.INTERPOLATE_NEAREST)
		pose.image = enlarged
	var normalized := Base.assemble(normalized_sources)
	check(normalized.error == "", "different source canvas widths accepted through common normalization")
	if normalized.error == "":
		for body: String in Base.HEIGHTS:
			check(Base.bytes_sha256(normalized.images[body].get_data()) == Base.bytes_sha256(assembled.images[body].get_data()), body + " page normalization preserves exact output without per-pose fitting")
	var huge := Image.create(100, 10, false, Image.FORMAT_RGBA8)
	huge.fill(Color.BLACK)
	sources.cardinal_motion.poses[0].image = huge
	check(Base.assemble(sources).error != "", "oversized pose fails instead of per-pose shrinking")
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Builder.ROOT + "oh_tipi/source-layout-v1.json"))
	var cells := 0
	for entry: Dictionary in parsed.pages:
		var image := Image.new()
		check(image.load_png_from_buffer(FileAccess.get_file_as_bytes(entry.path)) == OK, entry.id + " actual source decodes")
		check(FileAccess.get_sha256(entry.path) == entry.sha256, entry.id + " actual source immutable hash")
		var rejected := Builder.inspect_source(image, entry)
		check(String(rejected.error).contains("No automatic chroma tolerance"), entry.id + " actual invalid matte rejected")
		cells += entry.cells.size()
	check(cells == 80, "source manifest contains80 planned cells, not an accepted atlas")
	test_generic_profiles()
	test_neutral_template_profiles()
	test_post_resize_registration()
	print("%s: character-style strict importer %d assertions, %d failures" % ["PASS" if failures == 0 else "FAIL", assertions, failures])
	quit(0 if failures == 0 else 1)


func make_fixture(source_id: String) -> Dictionary:
	var contract: Dictionary = Base.PAGE_SPECS[source_id]
	var rows: Array = [0, 14, 32, 48, 64] if contract.states.size() == 4 else [0, 16, 32]
	var image := Image.create(64, int(rows[-1]), false, Image.FORMAT_RGBA8)
	image.fill(Color.MAGENTA)
	var cells: Array[Dictionary] = []
	for row: int in range(contract.states.size()):
		for column: int in range(4):
			image.fill_rect(Rect2i(column * 16 + 5, int(rows[row]) + 2, 5, 10), Color("203c56"))
			cells.append({"state": contract.states[row], "direction": contract.directions[column],
				"rect": [column * 16, rows[row], 16, int(rows[row + 1]) - int(rows[row])]})
	return {"image": image, "entry": {"id": source_id, "reference_cell_width": 16.0, "cells": cells}}


func check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		print("FAIL: ", label)


func test_post_resize_registration() -> void:
	# A thin last toe pixel is not necessarily sampled by nearest downscaling.
	# The final pixels, not a pre-resize rectangle, must determine registration.
	var dense := Image.create(40, 116, false, Image.FORMAT_RGBA8)
	dense.fill(Color("294c63"))
	var sparse := Image.create(40, 120, false, Image.FORMAT_RGBA8)
	sparse.fill_rect(Rect2i(2, 0, 36, 115), Color("294c63"))
	sparse.set_pixel(39, 119, Color.WHITE)
	var before := Base.bytes_sha256(sparse.get_data())
	var source := {"error": "", "cell_width": 128.0, "poses": [
		{"state": "grounded", "direction": "south", "image": dense, "cell_region": [0, 0, 128, 128], "visible_bounds": [0, 0, 40, 116]},
		{"state": "walk", "direction": "south", "image": sparse, "cell_region": [128, 0, 128, 128], "visible_bounds": [0, 0, 40, 120]},
	]}
	for body: String in Builder.HEIGHTS:
		var identity := {"champion_id": "fixture", "display_name": "Fixture", "body": body}
		var built := Builder.assemble({"sparse_toe": source}, identity, true)
		check(built.error == "", body + " sparse toe assembly")
		if built.error != "": continue
		for frame: Dictionary in built.manifest.frames:
			var region := Rect2i(frame.output_region[0], frame.output_region[1], 96, 96)
			var actual: Rect2i = built.image.get_region(region).get_used_rect()
			check(actual.end.y == 84, body + " actual decoded feet registered after nearest sampling")
			check(Base._rect_values(actual) == frame.output_visible_bounds, body + " manifest occupied bounds equal actual pixels")
			check(actual.position.x + floori(actual.size.x / 2.0) == 48, body + " actual bottom center registered")
		var walk: Dictionary = built.manifest.frames[1]
		var expected: Image = sparse.duplicate()
		expected.resize(walk.resampled_dimensions[0], walk.resampled_dimensions[1], Image.INTERPOLATE_NEAREST)
		var occupied := expected.get_used_rect()
		var actual_walk: Image = built.image.get_region(Rect2i(96 + walk.output_visible_bounds[0], walk.output_visible_bounds[1], walk.output_visible_bounds[2], walk.output_visible_bounds[3]))
		check(Base.bytes_sha256(actual_walk.get_data()) == Base.bytes_sha256(expected.get_region(occupied).get_data()), body + " translated output preserves every surviving source pixel")
	check(Base.bytes_sha256(sparse.get_data()) == before, "post-resize registration never changes original")


func test_generic_profiles() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Builder.CATALOG))
	var sources: Dictionary = {}
	for source_id: String in Base.PAGE_SPECS:
		var fixture := make_fixture(source_id)
		sources[source_id] = Builder.inspect_source(fixture.image, fixture.entry)
	var count := 0
	for entry: Dictionary in catalog.champions:
		var identity := Builder.resolve_identity({"champion_id": entry.id, "body": entry.body_type}, catalog.champions)
		check(identity.error == "", entry.id + " canonical identity recognized")
		check(identity.standing_height == Builder.HEIGHTS[entry.body_type], entry.id + " canonical body height")
		var full := Builder.assemble(sources, identity)
		check(full.error == "", entry.id + " generic80-cell pack")
		if full.error == "":
			check(full.manifest.frame_count == 80 and full.manifest.complete_coverage, entry.id + " full coverage not aliases")
			check(full.manifest.champion_id == entry.id and full.manifest.body_type == entry.body_type, entry.id + " output identity")
			check(full.image.get_size() == Vector2i(768, 960), entry.id + " exact outputdimensions")
			check(full.manifest.live_promotion == false, entry.id + " build is not art acceptance")
		count += 1
	check(count == 30, "all30 named profiles covered with no reserved placeholder")
	check(Builder.resolve_identity({"champion_id": "angel"}, catalog.champions).error != "", "unknown noncanonical identity rejected")
	check(Builder.resolve_identity({"champion_id": "s_wayne", "body": "large"}, catalog.champions).error != "", "wrong body rejected")
	check(Builder.resolve_identity({"champion_id": "s_wayne", "standing_height": 68}, catalog.champions).error != "", "wrong height rejected")
	var arbitrary := make_fixture("cardinal_core")
	arbitrary.entry.id = "arbitrary_review_page"
	arbitrary.entry.cells = arbitrary.entry.cells.slice(0, 3)
	var partial := Builder.inspect_source(arbitrary.image, arbitrary.entry)
	check(partial.error == "", "arbitrary partial page layout supported")
	var identity := Builder.resolve_identity({"champion_id": "s_wayne"}, catalog.champions)
	check(Builder.assemble({"partial": partial}, identity).error != "", "partial pages cannot become fullatlas")
	var review := Builder.assemble({"partial": partial}, identity, true)
	check(review.error == "" and review.manifest.status == "partial_review_only" and not review.manifest.complete_coverage, "partial review honeststatus")
	check(review.image.get_size() == Vector2i(288, 96), "3cells compactreview no fakeemptycoverage")
	check(Builder.assemble({"a": sources.cardinal_core, "b": sources.cardinal_core}, identity, true).error != "", "crosspage duplicate rejected")
	var rule := {"method": "edge_connected_neutral_checker", "minimum_channel": 170, "maximum_spread": 18, "authorization": "explicit synthetic fixture"}
	var checker := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	checker.fill(Color("dddddd"))
	checker.fill_rect(Rect2i(4, 3, 8, 10), Color("26364a"))
	checker.set_pixel(6, 6, Color.WHITE)
	var original_hash := Base.bytes_sha256(checker.get_data())
	var page := {"id": "checker_fixture", "reference_cell_width": 16, "background_removal": rule,
		"cells": [{"state": "grounded", "direction": "south", "rect": [0, 0, 16, 16]}]}
	var cleaned := Builder.inspect_source(checker, page)
	check(cleaned.error == "" and cleaned.import_mode == "reviewed_neutral_checker", "explicit checker rule accepted")
	check(cleaned.removed_pixels == 176, "only176 edgeconnected backgroundpixels removed")
	check(cleaned.removal_mask.get_pixel(0, 0).r == 1.0 and cleaned.removal_mask.get_pixel(6, 6).r == 0.0, "exact removal mask preserves subject highlight")
	check(Base.bytes_sha256(checker.get_data()) == original_hash, "sourceRGBAunchanged by approved removal")
	check(cleaned.poses[0].image.get_pixel(2, 3) == Color.WHITE, "enclosedsubjecthighlight preserved")
	page.background_removal.authorization = ""
	check(Builder.inspect_source(checker, page).error != "", "missing removal authorization rejected")
	page.background_removal.authorization = "fixture"
	page.background_removal.minimum_channel = 90
	check(Builder.inspect_source(checker, page).error != "", "broad destructive threshold rejected")
	var actual: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Builder.ROOT + "s_wayne/source-layout-v1.json"))
	var source := Image.new()
	check(source.load_png_from_buffer(FileAccess.get_file_as_bytes(actual.pages[0].path)) == OK, "Swayne actualsource decodes")
	var actual_hash := Base.bytes_sha256(source.get_data())
	var actual_cleaned := Builder.inspect_source(source, actual.pages[0])
	check(actual_cleaned.error == "", "Swayne actual reviewed checker removal")
	check(Base.bytes_sha256(source.get_data()) == actual_hash, "Swayne originalRGBA retained")
	if actual_cleaned.error == "":
		var result := Builder.assemble({"south": actual_cleaned}, identity, true)
		check(result.error == "" and result.manifest.frame_count == 3, "Swayne actual3pose nativepacking")
		check(result.image.get_pixel(0, 0).a == 0.0, "Swayne actual transparent output corner")
		check(result.manifest.frames[0].output_visible_bounds[3] == 58, "Swayne58px nativeidle")


func test_neutral_template_profiles() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Builder.CATALOG))
	var fixture := make_fixture("cardinal_core")
	fixture.entry.cells = fixture.entry.cells.slice(0, 1)
	var before := Base.bytes_sha256(fixture.image.get_data())
	var source := Builder.inspect_source(fixture.image, fixture.entry)
	for body: String in Builder.HEIGHTS:
		var spec := {"asset_kind": "neutral_body_template", "champion_id": "template_" + body,
			"body": body, "standing_height": Builder.HEIGHTS[body]}
		var identity := Builder.resolve_identity(spec, catalog.champions)
		check(identity.error == "", body + " explicit neutral identity is accepted")
		check(identity.asset_kind == "neutral_body_template" and identity.champion_id == "template_" + body, body + " neutral identity remains distinct from live catalog")
		check(Builder.resolve_identity(spec, []).error == "", body + " neutral construction does not need a borrowed champion")
		var partial := Builder.assemble({"front": source}, identity, true)
		check(partial.error == "", body + " South-only partial review assembles")
		if partial.error == "":
			check(partial.manifest.frame_count == 1 and not partial.manifest.complete_coverage, body + " one cell never claims full80 coverage")
			check(partial.manifest.asset_kind == "neutral_body_template" and not partial.manifest.live_promotion, body + " template manifest remains offline and nonpromoted")
			check(partial.image.get_size() == Vector2i(96, 96), body + " one partial review cell is96px")
			check(partial.image.get_used_rect().end.y == 84, body + " template uses existing actual-foot registration")
		check(Builder.assemble({"front": source}, identity).error != "", body + " partial template cannot become fullatlas")
		var wrong_heading: Dictionary = source.duplicate(true)
		wrong_heading.poses[0].direction = "north_east"
		check(Builder.assemble({"rear": wrong_heading}, identity, true).error != "", body + " partial template still requires actual South-grounded calibration")
		for field: String in ["champion_id", "body", "standing_height"]:
			var missing := spec.duplicate()
			missing.erase(field)
			check(Builder.resolve_identity(missing, catalog.champions).error != "", body + " neutral explicit field required: " + field)
		var implicit := spec.duplicate()
		implicit.erase("asset_kind")
		check(Builder.resolve_identity(implicit, catalog.champions).error != "", body + " neutral identity without explicit asset kind is not a champion alias")
		for changed: Dictionary in [
			{"champion_id": "template_huge"}, {"champion_id": "s_wayne"}, {"champion_id": "Template_" + body},
			{"body": "middle" if body == "small" else "small"}, {"body": "huge"},
			{"standing_height": float(Builder.HEIGHTS[body]) + 0.5}, {"standing_height": str(Builder.HEIGHTS[body])},
			{"standing_height": -1}, {"standing_height": INF}, {"standing_height": true},
			{"asset_kind": "neutral"}, {"asset_kind": "champion"},
			{"asset_kind": null}, {"asset_kind": 1}, {"asset_kind": true}, {"asset_kind": []}, {"asset_kind": {}},
		]:
			var invalid := spec.duplicate()
			invalid.merge(changed, true)
			check(Builder.resolve_identity(invalid, catalog.champions).error != "", body + " neutral identity/body/height/kind mismatches fail closed")
	check(Builder.resolve_identity({"asset_kind": "neutral_body_template", "champion": "template_small", "body": "small", "standing_height": 58}, catalog.champions).error != "", "legacy champion field cannot supply a neutral identity")
	check(Builder.resolve_identity({"asset_kind": "neutral_body_template", "champion_id": "Oh Tipi", "body": "middle", "standing_height": 68}, catalog.champions).error != "", "catalog display name cannot impersonate a neutral template")
	check(Builder.resolve_identity({"asset_kind": "unknown", "champion_id": "oh_tipi"}, catalog.champions).error != "", "invalid asset kind does not fall through to a real champion")
	check(Base.bytes_sha256(fixture.image.get_data()) == before, "neutral assembly preserves the raw source exactly")
