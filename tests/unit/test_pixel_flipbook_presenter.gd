extends FluxTestSuite

const Pilot = preload("res://src/presentation/pixel_flipbook_presenter.gd")
const ID := "synthetic_small"
const WAIST := 78
const PILOT_IDS := ["s_wayne", "oh_tipi", "red_baron"]


func run() -> int:
	var pixels := Image.create(1024, 768, false, Image.FORMAT_RGBA8)
	# A synthetic page avoids a dependency on art production or import timing.
	for row: int in Pilot.ROWS.size():
		pixels.fill_rect(Rect2i(0, row * 128, 1024, 128), Color(float(row + 1) / 6.0, 0.25, 0.75, 1.0))
	var texture := ImageTexture.create_from_image(pixels)
	var digest := _rgba_hash(pixels)
	var manifest := _manifest(digest)
	var pages := {"pilot.png": texture}
	var presenter := Pilot.new()
	check(presenter.admit_manifest(manifest, [ID], pages), "synthetic pilot admission: " + presenter.last_error)
	if not presenter.has_character(ID):
		return finish("pixel-flipbook-presenter")
	_test_manifest_contract(manifest)
	_test_regions(texture)
	_test_aim_travel_matrix(presenter)
	_test_standing_and_fallback(presenter)
	_test_input_validation(presenter)
	_test_immutable_queries(presenter, manifest)
	_test_admission_failures(manifest, pages)
	equal(_rgba_hash(texture.get_image()), digest, "all queries preserve exact admitted pixels")
	_test_full_cast_contact_timing()
	_test_live_presenter()
	return finish("pixel-flipbook-presenter")


func _manifest(digest: String) -> Dictionary:
	return {
		"schema_version": 1, "id": "hex-pixel-body-pilot-v1",
		"directions": Pilot.DIRECTIONS.duplicate(), "rows": Pilot.ROWS.duplicate(),
		"cell": [128, 128], "pivot": [64, 104],
		"characters": [{"id": ID, "body": "small", "atlas": "pilot.png",
			"rgba_sha256": digest, "waist_y": WAIST, "display_height": 58}],
	}


func _test_manifest_contract(valid: Dictionary) -> void:
	equal(Pilot.manifest_error(valid, [ID]), "", "fixed pilot schema accepted")
	var scalar := valid.duplicate(true)
	scalar.cell = 128
	equal(Pilot.manifest_error(scalar, [ID]), "", "scalar128 denotes the same fixed square cell")
	var json_numbers: Variant = JSON.parse_string(JSON.stringify(valid))
	equal(Pilot.manifest_error(json_numbers, [ID]), "", "whole JSON numbers preserve the schema")
	for value: Variant in [null, [], 1, "manifest"]:
		check(not Pilot.manifest_error(value, [ID]).is_empty(), "non-dictionary manifest rejected")
	for key: String in ["schema_version", "id", "directions", "rows", "cell", "pivot", "characters"]:
		var missing := valid.duplicate(true)
		missing.erase(key)
		check(not Pilot.manifest_error(missing, [ID]).is_empty(), "required manifest field: " + key)
	for version: Variant in [0, 2, 1.5, true, "1"]:
		var changed := valid.duplicate(true)
		changed.schema_version = version
		check(not Pilot.manifest_error(changed, [ID]).is_empty(), "schema version must be integer1")
	var wrong_id := valid.duplicate(true)
	wrong_id.id = "another-pilot"
	check(not Pilot.manifest_error(wrong_id, [ID]).is_empty(), "manifest identity is exact")
	for key: String in ["directions", "rows"]:
		var reordered := valid.duplicate(true)
		reordered[key].reverse()
		check(not Pilot.manifest_error(reordered, [ID]).is_empty(), "atlas order is fixed: " + key)
	for size: Variant in [64, [128, 64], [128, 128, 128], "128", [128.5, 128]]:
		var changed := valid.duplicate(true)
		changed.cell = size
		check(not Pilot.manifest_error(changed, [ID]).is_empty(), "cell cannot resize or change shape")
	var moved_pivot := valid.duplicate(true)
	moved_pivot.pivot = [64, 103]
	check(not Pilot.manifest_error(moved_pivot, [ID]).is_empty(), "foot registration cannot drift")
	for key: String in ["id", "body", "atlas", "rgba_sha256", "waist_y", "display_height"]:
		var missing := valid.duplicate(true)
		missing.characters[0].erase(key)
		check(not Pilot.manifest_error(missing, [ID]).is_empty(), "required character field: " + key)
	for waist: Variant in [0, 128, -1, 78.5, INF, NAN, "78", true]:
		var changed := valid.duplicate(true)
		changed.characters[0].waist_y = waist
		check(not Pilot.manifest_error(changed, [ID]).is_empty(), "waist is a strict interior integer seam")
	for leaf: String in ["", "../pilot.png", "nested/pilot.png", "nested\\pilot.png", "C:pilot.png", "/pilot.png", "res://pilot.png", "pilot.txt", "pilot..png"]:
		var changed := valid.duplicate(true)
		changed.characters[0].atlas = leaf
		check(not Pilot.manifest_error(changed, [ID]).is_empty(), "unsafe/non-PNG atlas rejected: " + leaf)
	for digest: String in ["", "00", "g".repeat(64), "A".repeat(64)]:
		var changed := valid.duplicate(true)
		changed.characters[0].rgba_sha256 = digest
		check(not Pilot.manifest_error(changed, [ID]).is_empty(), "decoded hash must be lowercase SHA256")
	var wrong_body := valid.duplicate(true)
	wrong_body.characters[0].body = "giant"
	check(not Pilot.manifest_error(wrong_body, [ID]).is_empty(), "unknown body rejected")
	var wrong_height := valid.duplicate(true)
	wrong_height.characters[0].display_height = 68
	check(not Pilot.manifest_error(wrong_height, [ID]).is_empty(), "body calibration cannot be silently refitted")
	check(not Pilot.manifest_error(valid, []).is_empty(), "pilot must be a subset of the live catalog")
	var empty := valid.duplicate(true)
	empty.characters.clear()
	check(not Pilot.manifest_error(empty, [ID]).is_empty(), "empty bank fails closed")
	var repeated := valid.duplicate(true)
	repeated.characters.append(repeated.characters[0].duplicate(true))
	repeated.characters[1].atlas = "other.png"
	check(not Pilot.manifest_error(repeated, [ID]).is_empty(), "duplicate identity rejected")
	repeated.characters[1].id = "other"
	repeated.characters[1].atlas = "PILOT.PNG"
	check(not Pilot.manifest_error(repeated, [ID, "other"]).is_empty(), "duplicate atlas paths are case-insensitive")
	var bounded := valid.duplicate(true)
	var catalog: Array = [ID]
	for index: int in range(1, 4):
		var entry: Dictionary = valid.characters[0].duplicate(true)
		entry.id = "synthetic_" + str(index)
		entry.atlas = entry.id + ".png"
		bounded.characters.append(entry)
		catalog.append(entry.id)
		if index < 3:
			equal(Pilot.manifest_error(bounded, catalog), "", "two and three unique pilot entries allowed")
	check(not Pilot.manifest_error(bounded, catalog).is_empty(), "fourth character exceeds explicit pilot bound")


func _test_regions(texture: Texture2D) -> void:
	# This generic helper test covers region arithmetic, not approval of a
	# mixed-facing body. Runtime-frame tests below require one shared heading.
	var page := Rect2(Vector2.ZERO, Vector2(Pilot.ATLAS_SIZE))
	for waist: int in [1, WAIST, 127]:
		for lower_facing: int in 8:
			for upper_facing: int in 8:
				var regions := Pilot.make_regions(texture, waist, lower_facing, 4, upper_facing, 5)
				equal(regions.size(), 2, "one lower and one upper immutable blit")
				var lower: Rect2 = regions[0].destination_region
				var upper: Rect2 = regions[1].destination_region
				equal(upper.end.y, lower.position.y, "regions meet at the exact integer seam")
				check(not upper.intersects(lower), "region interiors never overlap")
				equal(upper.get_area() + lower.get_area(), 128.0 * 128.0, "two regions cover exactly one fixed canvas")
				for component: Dictionary in regions:
					var source: Rect2 = component.source_region
					var destination: Rect2 = component.destination_region
					equal(component.texture, texture, "components borrow one admitted immutable texture")
					equal(source.size, destination.size, "native1x blits never scale the body")
					check(page.encloses(source), "source region stays within admitted atlas")
					equal(source.position, source.position.round(), "source region coordinates are integral")
					equal(destination.position, destination.position.round(), "destination registration is integral")
	for values: Array in [[0, 0, 0, 0, 0], [128, 0, 0, 0, 0], [WAIST, -1, 0, 0, 0], [WAIST, 8, 0, 0, 0], [WAIST, 0, 6, 0, 0], [WAIST, 0, -1, 0, 0], [WAIST, 0, 0, 8, 0], [WAIST, 0, 0, -1, 0], [WAIST, 0, 0, 0, 6], [WAIST, 0, 0, 0, -1]]:
		equal(Pilot.make_regions(texture, values[0], values[1], values[2], values[3], values[4]), [], "out-of-range region request rejected")
	equal(Pilot.make_regions(null, WAIST, 0, 0, 0, 0), [], "null texture has no drawable regions")


func _test_aim_travel_matrix(presenter: RefCounted) -> void:
	for action: String in ["walk", "sprint"]:
		for aim: int in 8:
			for travel: int in 8:
				for step: int in 4:
					var phase := float(step) / 4.0
					var gait := _expected_gait_mode(aim, travel)
					var selected_step: int = [0, 3, 2, 1][step] if gait == "backpedal" else step
					var frame: Dictionary = presenter.frame(ID, action, aim, travel, phase, false, 0.0, false)
					equal(frame.aim_index, aim, "aim selects the connected whole-body heading")
					equal(frame.travel_index, travel, "travel remains independent gait metadata in every matrix cell")
					equal(frame.gait_mode, gait, "relative travel reports forward, backpedal or incomplete sidestep coverage")
					equal(frame.lower_facing, aim, "runtime legs never splice a different-facing tail or cape onto the body")
					equal(frame.components[0].source_region, Rect2(aim * 128, (selected_step + 1) * 128 + WAIST, 128, 128 - WAIST), "feet keep aim-facing anatomy with the selected forward/reverse cycle")
					equal(frame.components[1].source_region, Rect2(aim * 128, (selected_step + 1) * 128, 128, WAIST), "uncast upper and lower body share the same heading and cycle row")
					equal(frame.components[0].source_region.position.x, frame.components[1].source_region.position.x, "runtime never mixes atlas-facing columns")
					check(not frame.strafe_art_complete, "sidestep metadata does not claim dedicated strafe artwork")
					equal(frame.anatomy_note, Pilot.ANATOMY_NOTE, "frame discloses preserved anatomy and unfinished strafe art")
					if step == 0:
						equal(frame.components[0].source_region.position.y, float(128 + WAIST), "backpedal reversal preserves phase-zero contactA")
					var casting: Dictionary = presenter.frame(ID, action, aim, travel, phase, true, 0.25, false)
					equal(casting.components[0], frame.components[0], "moving cast preserves exact lower-body frame")
					equal(casting.components[1].source_region, Rect2(aim * 128, 5 * 128, 128, WAIST), "cast upper row shares the lower body's aim-facing anatomy")
					equal(casting.components[0].source_region.position.x, casting.components[1].source_region.position.x, "casting never reintroduces a mixed-facing waist cut")
					check(casting.cast_frame and not frame.cast_frame, "cast-row metadata is truthful")
					check(casting.frame_id != frame.frame_id, "cast selection has a distinct immutable frame identifier")
					var reduced: Dictionary = presenter.frame(ID, action, aim, travel, phase, true, 0.25, true)
					equal(reduced.components, casting.components, "reduced motion does not suppress authoritative leg steps")
					var zero_cast: Dictionary = presenter.frame(ID, action, aim, travel, phase, true, 0.0, false)
					equal(zero_cast.components, frame.components, "zero cast envelope keeps the ordinary upper row")
					var wrapped: Dictionary = presenter.frame(ID, action, aim, travel, phase + 2.0, false, 0.0, false)
					equal(wrapped.frame_id, frame.frame_id, "whole gait loops repeat exact frame selection")
					for forbidden: String in ["mesh", "render_mesh", "rotation", "scale", "pose_blend"]:
						check(not frame.has(forbidden), "pixel frame never exposes runtime morph parameter: " + forbidden)


func _test_standing_and_fallback(presenter: RefCounted) -> void:
	for action: String in ["idle", "rooted", "cast"]:
		for aim: int in 8:
			var frame: Dictionary = presenter.frame(ID, action, aim, (aim + 4) % 8, 0.75, false, 0.0, false)
			equal(frame.components[0].source_region, Rect2(aim * 128, WAIST, 128, 128 - WAIST), "standing feet follow aim, not stale travel")
			equal(frame.lower_facing, aim, "standing body keeps one shared heading")
			equal(frame.gait_mode, "standing", "held standing poses do not claim a locomotion gait")
			equal(frame.cast_frame, action == "cast", "standing charge selects authored cast upper row")
			equal(frame.offset, Vector2.ZERO, "pilot does not inherit procedural pivot bob")
			equal(frame.squat_depth, 0, "pilot never inherits a split-body squat deformation")
			equal(frame.pivot, Vector2(64, 104), "fixed foot registration")
			equal(frame.display_height, 58, "display height is identity calibration, not pose fitting")
			var inspection: Dictionary = presenter.inspection_frame(ID, aim)
			equal(inspection.region, Rect2(aim * 128, 0, 128, 128), "inspection borrows complete standing frame")
	for action: String in ["crouch", "jumpsquat", "jump", "fall", "fast_fall", "double_jump", "slide", "slide_jump", "roll", "air_dodge", "wavedash", "wallrun", "walljump", "land", "fly", "hit", "stunned", "defeated", "cast_recovery", "unknown"]:
		equal(presenter.frame(ID, action, 0, 2, 0.25, true, 1.0, false), {}, "unsupported action explicitly falls back: " + action)
	equal(presenter.frame("missing", "walk", 0, 2, 0.25, false, 0.0, false), {}, "nonpilot identity explicitly falls back")
	equal(presenter.inspection_frame("missing", 0), {}, "nonpilot inspection is explicit")
	var method_found := false
	for method: Dictionary in presenter.get_method_list():
		if method.name != "frame":
			continue
		method_found = true
		equal(method.args.size(), 8, "frame accepts only selected presentation scalars")
		for argument: Dictionary in method.args:
			check(int(argument.type) != TYPE_OBJECT, "presenter has no authoritative state/config object parameter")
	check(method_found, "frame API is inspectable")


func _test_input_validation(presenter: RefCounted) -> void:
	for bad: float in [INF, -INF, NAN]:
		equal(presenter.frame(ID, "walk", 0, 2, bad, false, 0.0, false), {}, "nonfinite phase rejected")
		equal(presenter.frame(ID, "walk", 0, 2, 0.25, true, bad, false), {}, "nonfinite cast envelope rejected")
	for bad: float in [-0.01, 1.01]:
		equal(presenter.frame(ID, "walk", 0, 2, 0.25, true, bad, false), {}, "out-of-range cast envelope rejected")
	for bad: int in [-1, 8]:
		equal(presenter.frame(ID, "walk", bad, 2, 0.25, false, 0.0, false), {}, "out-of-range aim rejected")
		equal(presenter.frame(ID, "walk", 0, bad, 0.25, false, 0.0, false), {}, "out-of-range travel rejected")
		equal(presenter.inspection_frame(ID, bad), {}, "out-of-range inspection direction rejected")
	var negative: Dictionary = presenter.frame(ID, "walk", 0, 2, -0.25, false, 0.0, false)
	var wrapped: Dictionary = presenter.frame(ID, "walk", 0, 2, 0.75, false, 0.0, false)
	equal(negative.frame_id, wrapped.frame_id, "finite negative preview phases wrap without invalid atlas regions")


func _test_immutable_queries(presenter: RefCounted, original_manifest: Dictionary) -> void:
	var first: Dictionary = presenter.frame(ID, "walk", 0, 2, 0.25, false, 0.0, false)
	var again: Dictionary = presenter.frame(ID, "walk", 0, 2, 0.25, false, 0.0, false)
	equal(first, again, "world and observer queries select the exact same immutable frame")
	first.components[0].source_region = Rect2()
	var later: Dictionary = presenter.frame(ID, "walk", 0, 2, 0.25, false, 0.0, false)
	equal(later.components, again.components, "caller cannot mutate a shared cached region table")
	var prior_waist: Variant = original_manifest.characters[0].waist_y
	original_manifest.characters[0].waist_y = 1
	var copied: Dictionary = presenter.frame(ID, "idle", 0, 0, 0.0, false, 0.0, false)
	equal(copied.components[0].destination_region.position.y, float(WAIST), "admission owns a deep copy of registration metadata")
	original_manifest.characters[0].waist_y = prior_waist


func _test_admission_failures(valid: Dictionary, pages: Dictionary) -> void:
	var presenter := Pilot.new()
	var wrong_size := ImageTexture.create_from_image(Image.create(1024, 767, false, Image.FORMAT_RGBA8))
	var wrong_pixels := ImageTexture.create_from_image(Image.create(1024, 768, false, Image.FORMAT_RGBA8))
	for rejected: Dictionary in [{}, {"pilot.png": wrong_size}, {"pilot.png": wrong_pixels}]:
		check(presenter.admit_manifest(valid, [ID], pages), "restore known synthetic admission before failure")
		check(not presenter.admit_manifest(valid, [ID], rejected), "missing, wrong-size or changed pixels reject admission")
		check(not presenter.last_error.is_empty(), "failed admission reports a reason")
		equal(presenter.entries.size(), 0, "failed admission clears every identity")
		equal(presenter.textures.size(), 0, "failed admission clears every retained texture")
		check(not presenter.has_character(ID), "failed bank cannot retain a stale drawable pilot")
	check(presenter.admit_manifest(valid, [ID], pages), "valid bank can be restored")
	var partial := valid.duplicate(true)
	var second: Dictionary = partial.characters[0].duplicate(true)
	second.id = "missing_second"
	second.atlas = "second.png"
	partial.characters.append(second)
	check(not presenter.admit_manifest(partial, [ID, "missing_second"], pages), "later missing page rejects the whole eager bank")
	equal(presenter.entries.size(), 0, "first valid page does not leak from partial admission")
	equal(presenter.textures.size(), 0, "first texture does not leak from partial admission")
	check(not presenter.admit_manifest({"id": "invalid"}, [ID], pages), "invalid manifest fails before texture admission")
	equal(presenter.frame(ID, "idle", 0, 0, 0.0, false, 0.0, false), {}, "failed bank only offers explicit fallback")


func _test_full_cast_contact_timing() -> void:
	var pixels := Image.create(1024, 512, false, Image.FORMAT_RGBA8)
	for row: int in 4:
		pixels.fill_rect(Rect2i(0, row * 128, 1024, 128), Color(float(row + 1) / 4.0, 0.25, 0.75, 1.0))
	var texture := ImageTexture.create_from_image(pixels)
	var digest := _rgba_hash(pixels)
	var manifest := _manifest(digest)
	manifest.id = Pilot.CAST_MANIFEST_ID
	manifest.rows = Pilot.CAST_ROWS.duplicate()
	var presenter := Pilot.new()
	check(presenter.admit_manifest(manifest, [ID], {"pilot.png": texture}), "compact contact timing admits registered synthetic pixels")
	if not presenter.has_character(ID): return
	# Independently stated exact boundaries, adjacent dyadic samples and wrap.
	# Quarter phases retain their original contact/pass identity.
	var cases := [
		[-0.25, 3], [-0.03125, 0], [0.0, 0],
		[0.1552734375, 0], [0.15625, 1], [0.1572265625, 1], [0.25, 1],
		[0.3427734375, 1], [0.34375, 2], [0.3447265625, 2], [0.5, 2],
		[0.6552734375, 2], [0.65625, 3], [0.6572265625, 3], [0.75, 3],
		[0.8427734375, 3], [0.84375, 0], [0.8447265625, 0], [1.0, 0], [2.5, 2],
	]
	for action: String in ["walk", "sprint"]:
		for aim: int in 8:
			for travel: int in 8:
				for sample: Array in cases:
					var phase := float(sample[0])
					var beat := int(sample[1])
					if _expected_gait_mode(aim, travel) == "backpedal": beat = [0, 3, 2, 1][beat]
					var row: int = [1, 0, 2, 0][beat]
					var frame: Dictionary = presenter.frame(ID, action, aim, travel, phase, false, 0.0, false)
					equal(frame.components[0].source_region, Rect2(aim * 128, row * 128 + WAIST, 128, 128 - WAIST), "centered compact contacts select exact immutable lower pixels")
					equal(frame.components[1].source_region, Rect2(aim * 128, row * 128, 128, WAIST), "unmodified whole-body heading and seam share the contact beat")
					equal(frame.motion_phase, phase, "contact timing never rewrites the distance-owned phase")
					equal(frame.sample_phase, float(beat) / 4.0, "logical passing beats remain distinct even when their pixels repeat")
					equal(frame.aim_index, aim, "contact emphasis never delays a facing change")
					equal(frame.travel_index, travel, "contact emphasis preserves independent travel")
					for reduced: bool in [false, true]:
						var casting: Dictionary = presenter.frame(ID, action, aim, travel, phase, true, 1.0, reduced)
						equal(casting.components[0], frame.components[0], "cast and Reduced Effects retain the same live contact timing")
						equal(casting.components[1].source_region, Rect2(aim * 128, 384, 128, WAIST), "contact rhythm cannot suppress the authored casting arms")
						for component: Dictionary in casting.components:
							equal(component.source_region.size, component.destination_region.size, "contact rhythm never stretches registered pixels")
						for key: String in ["pivot", "offset", "cell_size", "display_height", "squat_depth"]:
							equal(casting[key], frame[key], "contact and casting preserve fixed registration: " + key)
	# A dense, centered sampling grid measures the whole cyclic duration rather
	# than allowing a boundary-only test to miss a shortened passing interval.
	var counts := [0, 0, 0, 0]
	for index: int in 64:
		var frame: Dictionary = presenter.frame(ID, "sprint", 0, 0, (float(index) + 0.5) / 64.0, false, 0.0, false)
		counts[roundi(float(frame.sample_phase) * 4.0)] += 1
	equal(counts, [20, 12, 20, 12], "each contact holds 5/16 cycle and each neutral pass retains 3/16")
	for step: int in 30:
		var first: Dictionary = presenter.frame(ID, "sprint", 0, 0, float(step) / 30.0, false, 0.0, false)
		var next: Dictionary = presenter.frame(ID, "sprint", 0, 0, float(step + 5) / 30.0, false, 0.0, false)
		var first_beat := roundi(float(first.sample_phase) * 4.0)
		var next_beat := roundi(float(next.sample_phase) * 4.0)
		check(posmod(next_beat - first_beat, 4) <= 1, "30FPS at the 5Hz cap cannot skip a complete contact or passing beat")
	equal(_rgba_hash(texture.get_image()), digest, "contact timing never edits the admitted art")


func _test_live_presenter() -> void:
	var language := VisualLanguage.new()
	var language_ready := language.load_from_file()
	check(language_ready, "live visual language loads for pilot integration")
	if not language_ready:
		return
	var presenter := CartoonChampionPresenter.new()
	var configured := presenter.configure(language)
	check(configured, "live catalog/presenter configures: " + presenter.last_error)
	if not configured:
		return
	check(presenter.fullbody_art == null, "fixed-pixel pilot remains opt-in")
	var portrait_revision := presenter.portrait_revision()
	var enabled := presenter.enable_fullbody_art(true)
	check(enabled, "live fixed-pixel pilot admits all registered pages: " + presenter.last_error)
	if not enabled or presenter.fullbody_art == null:
		return
	var art: RefCounted = presenter.fullbody_art
	var pilot: RefCounted = art.pixel_pilot
	check(pilot != null, "explicit pilot flag reaches the fullbody adapter")
	if pilot == null:
		return
	equal(pilot.entries.size(), PILOT_IDS.size(), "live pilot is exactly the three approved identities")
	check(presenter.portrait_revision() > portrait_revision, "pilot activation invalidates standing portrait caches")
	for id: String in PILOT_IDS:
		check(pilot.has_character(id), "live pilot identity admitted: " + id)
		if not pilot.has_character(id):
			return
		equal(pilot.entries[id].body, presenter.champions[id].body_type, "pilot anatomy agrees with live catalog: " + id)
	var config := SimConfig.new(120)
	_test_live_matrix(presenter, pilot, config)
	_test_live_portraits_and_inspection(presenter, pilot)
	_test_live_cast_envelope(presenter, pilot, config)
	_test_live_fallbacks(presenter, pilot, config)
	for id: String in PILOT_IDS:
		var texture: Texture2D = pilot.textures[id]
		equal(_rgba_hash(texture.get_image()), String(pilot.entries[id].rgba_sha256), "live presentation leaves admitted atlas pixels unchanged: " + id)
	_test_live_full_cast_contact_timing(presenter, config)
	check(presenter.configure(language), "ordinary presenter can be restored after pilot review")
	check(presenter.fullbody_art == null, "reconfiguration clears optional pilot and fullbody adapter")


func _test_live_full_cast_contact_timing(presenter: CartoonChampionPresenter, config: SimConfig) -> void:
	var enabled := presenter.enable_fullbody_art(false, true)
	check(enabled, "live compact cast admits before contact timing review: " + presenter.last_error)
	if not enabled: return
	var bank: RefCounted = presenter.fullbody_art.pixel_pilot
	var phases := [0.125, 0.1875, 0.375, 0.625, 0.8125, 0.875]
	var rows := [1, 0, 2, 2, 0, 1]
	for id: String in PILOT_IDS:
		var waist := int(bank.entries[id].waist_y)
		for action: String in ["walk", "sprint"]:
			var state := _live_action_state(action, 8700 + PILOT_IDS.find(id))
			state.movement_mode = PlayerState.MovementMode.SPRINT if action == "sprint" else PlayerState.MovementMode.WALK
			for aim: int in 8:
				var facing: Vector2i = EightDirectionResolver.FIXED_VECTORS[aim]
				state.aim_x = facing.x
				state.aim_y = facing.y
				for relative: int in [0, 2, 4]:
					var travel := (aim + relative) % 8
					var velocity: Vector2i = EightDirectionResolver.FIXED_VECTORS[travel]
					state.velocity_x = velocity.x * 200
					state.velocity_y = velocity.y * 200
					for index: int in phases.size():
						for casting: bool in [false, true]:
							state.pending_cast_wire_id = 1 if casting else 0
							state.pending_cast_ticks = 0
							var before := state.canonical_values()
							for reduced: bool in [false, true]:
								var frame := presenter.movement_frame(id, state, 40.0, config, reduced, float(phases[index]))
								equal(frame.get("visual_mode"), "pixel_cast", "live compact mode owns the refined contact rhythm")
								equal(frame.get("action"), action, "contact rhythm preserves the authoritative locomotion action")
								equal(frame.components[0].source_region, Rect2(aim * 128, int(rows[index]) * 128 + waist, 128, 128 - waist), "live forward/side/backward movement uses centered contact holds")
								equal(frame.components[1].source_region.position.y, 384.0 if casting else float(int(rows[index]) * 128), "moving casts keep their arms while contact timing advances")
								equal(frame.motion_phase, float(phases[index]), "live sampling retains the exact distance phase")
								equal(frame.display_height, int(bank.entries[id].display_height), "all three body sizes keep their neutral calibration")
								equal(frame.pivot, Vector2(64, 104), "live contact hold cannot move the foot registration")
								equal(frame.offset, Vector2.ZERO, "live contact emphasis adds no procedural body bob")
								check(not frame.has("mesh") and not frame.has("render_mesh"), "live contact emphasis never falls through to body morphing")
								equal(state.canonical_values(), before, "live queries cannot change costs, balance, clocks, velocity or authority")
		equal(_rgba_hash(bank.textures[id].get_image()), String(bank.entries[id].rgba_sha256), "live contact timing retains exact approved identity pixels")


func _test_live_matrix(presenter: CartoonChampionPresenter, pilot: RefCounted, config: SimConfig) -> void:
	for id: String in PILOT_IDS:
		var state := PlayerState.new(8200 + PILOT_IDS.find(id))
		var waist := int(pilot.entries[id].waist_y)
		for action: String in ["walk", "sprint"]:
			state.movement_mode = PlayerState.MovementMode.WALK if action == "walk" else PlayerState.MovementMode.SPRINT
			for aim: int in 8:
				var aim_vector: Vector2i = EightDirectionResolver.FIXED_VECTORS[aim]
				state.aim_x = aim_vector.x
				state.aim_y = aim_vector.y
				for travel: int in 8:
					var travel_vector: Vector2i = EightDirectionResolver.FIXED_VECTORS[travel]
					state.velocity_x = travel_vector.x * 200
					state.velocity_y = travel_vector.y * 200
					for step: int in 4:
						var phase := float(step) / 4.0
						var gait := _expected_gait_mode(aim, travel)
						var selected_step: int = [0, 3, 2, 1][step] if gait == "backpedal" else step
						state.pending_cast_wire_id = 0
						state.pending_cast_ticks = 0
						state.cast_recovery_ticks = 0
						var before := state.canonical_values()
						var frame := presenter.movement_frame(id, state, 30.0, config, false, phase)
						equal(state.canonical_values(), before, "live pilot sample cannot mutate any authority field")
						if not _check_live_pixel(frame, id + "/" + action):
							continue
						equal(frame.action, action, "live dispatch preserves locomotion action")
						equal(frame.aim_index, aim, "live cursor selects the connected body's heading")
						equal(frame.travel_index, travel, "live movement remains independent gait metadata")
						equal(frame.gait_mode, gait, "live relative travel selects forward/backpedal/sidestep metadata")
						equal(frame.lower_facing, aim, "live lower body never faces away from its upper-body art")
						equal(frame.motion_phase, phase, "distance phase reaches fixed-pixel selector unchanged")
						equal(frame.texture, pilot.textures[id], "live draw payload owns the actual pilot atlas")
						equal(frame.components[0].source_region, Rect2(aim * 128, (selected_step + 1) * 128 + waist, 128, 128 - waist), "live lower body keeps aim-facing anatomy across all travel/phase combinations")
						equal(frame.components[1].source_region, Rect2(aim * 128, (selected_step + 1) * 128, 128, waist), "live uncast upper and lower body use one connected source heading and row")
						equal(frame.components[0].source_region.position.x, frame.components[1].source_region.position.x, "live frame cannot splice opposing costume directions")
						check(not frame.strafe_art_complete, "live sidestep reuse is not misreported as finished strafe art")
						if step == 0:
							equal(frame.components[0].source_region.position.y, float(128 + waist), "live backpedal retains phase-zero contactA")
						state.pending_cast_wire_id = 1
						before = state.canonical_values()
						var casting := presenter.movement_frame(id, state, 30.0, config, false, phase)
						equal(state.canonical_values(), before, "moving cast art never changes costs, timers, velocity, control or committed aim")
						if not _check_live_pixel(casting, id + "/moving-cast"):
							continue
						equal(casting.action, action, "pending cast never replaces walking/running action")
						equal(casting.components[0], frame.components[0], "live moving cast preserves exact lower-body phase")
						equal(casting.components[1].source_region, Rect2(aim * 128, 5 * 128, 128, waist), "live upper cast uses the same facing as the preserved lower anatomy")
						equal(casting.components[0].source_region.position.x, casting.components[1].source_region.position.x, "live casting cannot reintroduce independently facing legs")
						check(casting.cast_frame and casting.independent_cast_pose, "live cast metadata matches painted upper row")
						var reduced := presenter.movement_frame(id, state, 30.0, config, true, phase)
						equal(reduced.get("components"), casting.components, "live reduced effects do not freeze leg steps")
						equal(state.canonical_values(), before, "reduced presentation does not alter the cast or movement state")


func _test_live_portraits_and_inspection(presenter: CartoonChampionPresenter, pilot: RefCounted) -> void:
	for id: String in PILOT_IDS:
		var texture: Texture2D = pilot.textures[id]
		for direction: int in 8:
			var inspection := presenter.inspection_frame(id, CartoonChampionPresenter.EXPECTED_DIRECTIONS[direction])
			check(bool(inspection.get("pixel_body_pilot", false)), "gallery inspection selects the admitted pilot: " + id)
			equal(inspection.get("texture"), texture, "inspection never substitutes a historical standing atlas")
			equal(inspection.get("region"), Rect2(direction * 128, 0, 128, 128), "inspection selects the native idle row in every direction")
		var portrait := presenter.portrait_frame(id)
		var expected := CartoonChampionPresenter.FullbodyCast.build_portrait(texture.get_image(), 1)
		var actual_texture := portrait.get("texture") as Texture2D
		check(actual_texture != null, "pilot portrait is available to HUD/gallery: " + id)
		if actual_texture == null:
			continue
		var expected_texture: Texture2D = expected.texture
		equal(_rgba_hash(actual_texture.get_image()), _rgba_hash(expected_texture.get_image()), "portrait pixels come from the pilot's south idle cell")
		for key: String in ["region", "source_region", "occupied_model_region", "content_region"]:
			equal(portrait.get(key), expected.get(key), "portrait keeps standing-source crop registration: " + key)
		check(Rect2(0, 0, 128, 128).encloses(portrait.source_region), "portrait crop never samples walk/cast rows")
		check(not bool(portrait.get("temporary_body_template", true)), "pilot portrait never reports a shared body template")


func _test_live_cast_envelope(presenter: CartoonChampionPresenter, pilot: RefCounted, config: SimConfig) -> void:
	var wire_id := 0
	var startup_ticks := 0
	for candidate: int in CombatTuning.runtime_wire_ids():
		var definition := CombatTuning.cast_definition(candidate)
		var ticks := config.milliseconds_to_ticks(int(definition.get("startup_ms", 0)))
		if ticks > 0:
			wire_id = candidate
			startup_ticks = ticks
			break
	check(wire_id > 0, "real cast with a startup window exists for envelope integration")
	if wire_id <= 0:
		return
	for id: String in PILOT_IDS:
		var state := _live_action_state("walk", 8300 + PILOT_IDS.find(id))
		var waist := int(pilot.entries[id].waist_y)
		# West-facing body traveling east backpedals: phase1/4 selects reverse
		# step3, while both body halves remain in the west-facing source column.
		var lower := Rect2(6 * 128, 4 * 128 + waist, 128, 128 - waist)
		state.pending_cast_wire_id = wire_id
		for remaining: int in [startup_ticks, maxi(0, startup_ticks - 1), 0]:
			state.pending_cast_ticks = remaining
			var before := state.canonical_values()
			var frame := presenter.movement_frame(id, state, 40.0, config, false, 0.25)
			equal(state.canonical_values(), before, "startup sampling cannot create a cast lock or consume a timer")
			if not _check_live_pixel(frame, id + "/startup"):
				continue
			equal(frame.action, "walk", "startup keeps movement active")
			equal(frame.components[0].source_region, lower, "startup envelope never changes the distance-owned leg frame")
			equal(frame.cast_frame, remaining < startup_ticks, "upper cast follows the existing startup envelope exactly")
		state.pending_cast_wire_id = 0
		state.pending_cast_ticks = 0
		for remaining: int in [config.milliseconds_to_ticks(90), 5, 1, 0]:
			state.cast_recovery_ticks = remaining
			var before := state.canonical_values()
			var frame := presenter.movement_frame(id, state, 40.0, config, false, 0.25)
			equal(state.canonical_values(), before, "recovery sampling never extends the authoritative action window")
			if not _check_live_pixel(frame, id + "/recovery"):
				continue
			equal(frame.components[0].source_region, lower, "recovery preserves the exact planted/pass leg pose")
			equal(frame.cast_frame, remaining > 0, "upper returns immediately when the real recovery window ends")
		state.cast_recovery_ticks = 1
		for aim: int in 8:
			var aim_vector: Vector2i = EightDirectionResolver.FIXED_VECTORS[aim]
			state.aim_x = aim_vector.x
			state.aim_y = aim_vector.y
			var before := state.canonical_values()
			var frame := presenter.movement_frame(id, state, 40.0, config, false, 0.25)
			equal(state.canonical_values(), before, "live aim changes do not write committed cast or movement state")
			if not _check_live_pixel(frame, id + "/live-aim"):
				continue
			equal(frame.aim_index, aim, "casting never latches the previous presentation-facing direction")
			var gait := _expected_gait_mode(aim, 2)
			var selected_step: int = 3 if gait == "backpedal" else 1
			equal(frame.components[0].source_region, Rect2(aim * 128, (selected_step + 1) * 128 + waist, 128, 128 - waist), "aim changes turn the complete body together while retaining distance phase")
			equal(frame.components[1].source_region.position.x, float(aim * 128), "painted upper body responds in the same query as the lower heading")
			equal(frame.lower_facing, frame.aim_index, "changing aim during recovery never leaves detached costume anatomy")
		var seen_lower_rows: Dictionary = {}
		for step: int in 4:
			var frame := presenter.movement_frame(id, state, 40.0, config, false, float(step) / 4.0)
			if not _check_live_pixel(frame, id + "/cast-stride"):
				continue
			seen_lower_rows[frame.components[0].source_region.position.y] = true
			check(frame.cast_frame, "upper may hold cast while distance phase continues")
		equal(seen_lower_rows.size(), 4, "casting cannot freeze any of the four live leg phases")


func _test_live_fallbacks(presenter: CartoonChampionPresenter, pilot: RefCounted, config: SimConfig) -> void:
	for id: String in PILOT_IDS:
		for action: String in ["slide", "jump", "roll", "air_dodge"]:
			var state := _live_action_state(action, 8400 + PILOT_IDS.find(id))
			for casting: bool in [false, true]:
				state.pending_cast_wire_id = 1 if casting else 0
				var before := state.canonical_values()
				var frame := presenter.movement_frame(id, state, 50.0, config, false, 0.5)
				equal(state.canonical_values(), before, "advanced-action fallback is presentation-only")
				check(not frame.is_empty(), "unpainted advanced action keeps a visible fallback: " + action)
				check(not bool(frame.get("pixel_body_pilot", false)), "advanced action never masquerades as painted pilot coverage")
				equal(frame.get("action"), action, "fallback preserves the actual advanced movement action")
				check(frame.has("mesh") and frame.has("render_mesh"), "pilot advanced actions explicitly retain the existing shared-rig path")
				equal(bool(frame.get("independent_cast_pose", false)), casting, "advanced fallback keeps moving casts available")
	var remaining := 0
	for id: String in presenter.champions:
		if pilot.has_character(id):
			continue
		remaining += 1
		var state := _live_action_state("walk", 8500 + remaining)
		var before := state.canonical_values()
		var frame := presenter.movement_frame(id, state, 50.0, config, false, 0.25)
		equal(state.canonical_values(), before, "nonpilot identity retains unchanged authority")
		check(not frame.is_empty() and not bool(frame.get("pixel_body_pilot", false)), "remaining catalog identity keeps its explicit renderer fallback: " + id)
		check(frame.has("mesh") and frame.has("render_mesh"), "ordinary nonpilot movement is not silently replaced by a pilot atlas")
		equal(frame.get("texture"), presenter.fullbody_art.textures[id], "nonpilot keeps its own original identity texture")
	equal(remaining, presenter.champions.size() - PILOT_IDS.size(), "fallback coverage includes every remaining catalog identity")
	# The older authored low-pose pages lack painted cast overlays. They must
	# route to the existing cast-capable mesh, not suppress a moving cast.
	for id: String in ["wa_bidi", "jan_wicked", "fluup"]:
		var state := _live_action_state("slide", 8600)
		var plain := presenter.movement_frame(id, state, 50.0, config, false, 0.5)
		equal(plain.get("art_pose_quality"), "authored key pose", "uncast legacy low pose still uses existing authored keys")
		state.pending_cast_wire_id = 1
		var before := state.canonical_values()
		var casting := presenter.movement_frame(id, state, 50.0, config, false, 0.5)
		equal(state.canonical_values(), before, "legacy-key casting fallback adds no action lock")
		check(casting.has("mesh") and bool(casting.get("independent_cast_pose", false)), "unpainted special-key casts use explicit cast-capable fallback")


func _check_live_pixel(frame: Dictionary, label: String) -> bool:
	var components: Variant = frame.get("components")
	var admitted: bool = bool(frame.get("pixel_body_pilot", false)) and components is Array and components.size() == 2
	check(admitted, "live pilot has two native-pixel blits: " + label)
	check(not frame.has("mesh") and not frame.has("render_mesh"), "live pilot never builds or returns morphed geometry: " + label)
	return admitted


func _expected_gait_mode(aim: int, travel: int) -> String:
	match (travel - aim + 8) % 8:
		3, 4, 5:
			return "backpedal"
		2, 6:
			return "sidestep"
	return "forward"


func _live_action_state(action: String, entity_id: int) -> PlayerState:
	var state := PlayerState.new(entity_id)
	state.aim_x = -1000
	state.aim_y = 0
	state.velocity_x = 200000
	state.velocity_y = 0
	state.movement_mode = PlayerState.MovementMode.WALK
	match action:
		"slide":
			state.movement_mode = PlayerState.MovementMode.SLIDE
			state.slide_ticks = 12
			state.slide_x = 1000
		"jump":
			state.movement_mode = PlayerState.MovementMode.HOP
			state.hop_mode = PlayerState.MovementMode.HOP
			state.hop_ticks = 12
			state.air_height = 20000
			state.air_vertical_velocity = 30000
		"roll":
			state.movement_mode = PlayerState.MovementMode.ROLL
			state.hop_mode = PlayerState.MovementMode.ROLL
			state.air_dodge_ticks = 12
		"air_dodge":
			state.movement_mode = PlayerState.MovementMode.AIR_DODGE
			state.hop_mode = PlayerState.MovementMode.HOP
			state.hop_ticks = 12
			state.air_height = 20000
			state.air_dodge_ticks = 12
	return state


func _rgba_hash(pixels: Image) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(pixels.get_data())
	return hash.finish().hex_encode()
