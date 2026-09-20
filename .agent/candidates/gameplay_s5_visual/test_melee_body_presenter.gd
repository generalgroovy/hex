extends FluxTestSuite


const MeleeBody = preload("res://src/presentation/melee_body_presenter.gd")


func run() -> int:
	_test_row_contract()
	_test_relative_stance_selection()
	_test_phase_selection()
	_test_attachment_schema()
	_test_promoted_resources()
	_test_missing_attachment_table_is_explicit()
	_test_missing_manifest_fails_closed()
	return finish("melee-body-presenter")


func _test_row_contract() -> void:
	equal(MeleeBody.CELL, Vector2(96, 96), "melee uses the shared 96-pixel body cell")
	equal(MeleeBody.PIVOT, Vector2(48, 84), "melee uses the shared fixed feet pivot")
	equal(MeleeBody.DISPLAY_HEIGHTS, {"small": 58, "middle": 63, "large": 68}, "melee pages already contain all three display heights")
	equal(MeleeBody.source_region(0, 1, 1, 0), Rect2(0, 0, 96, 96), "idle Punch startup begins the page")
	equal(MeleeBody.source_region(0, 2, 1, 0), Rect2(0, 288, 96, 96), "idle Kick follows all three Punch phases")
	equal(MeleeBody.source_region(1, 1, 1, 0), Rect2(0, 576, 96, 96), "forward stance begins after both idle attacks")
	equal(MeleeBody.source_region(4, 2, 3, 7), Rect2(672, 2784, 96, 96), "left-strafe Kick recovery closes the page")
	var cells: Dictionary = {}
	for gait_index: int in MeleeBody.GAITS.size():
		for physical_kind: int in [1, 2]:
			for physical_phase: int in [1, 2, 3]:
				for aim_index: int in 8:
					var region := MeleeBody.source_region(gait_index, physical_kind, physical_phase, aim_index)
					check(Rect2(Vector2.ZERO, MeleeBody.PAGE_DIMENSIONS).encloses(region), "each melee frame fits the fixed page")
					check(not cells.has(region.position), "each gait, attack, phase and aim resolves a unique cell")
					cells[region.position] = true
	equal(cells.size(), 240, "each body page exposes five by two by three by eight cells")
	for invalid: Vector4i in [Vector4i(-1, 1, 1, 0), Vector4i(5, 1, 1, 0), Vector4i(0, 0, 1, 0), Vector4i(0, 3, 1, 0), Vector4i(0, 1, 0, 0), Vector4i(0, 1, 4, 0), Vector4i(0, 1, 1, 8)]:
		equal(MeleeBody.source_region(invalid.x, invalid.y, invalid.z, invalid.w), Rect2(), "invalid matrix coordinates fail closed")


func _test_relative_stance_selection() -> void:
	var east := Vector2i(1000, 0)
	equal(MeleeBody.relative_gait_index(east, Vector2i.ZERO), 0, "zero travel retains the idle stance")
	equal(MeleeBody.relative_gait_index(east, Vector2i(900, 0)), 1, "positive dot selects forward")
	equal(MeleeBody.relative_gait_index(east, Vector2i(0, 900)), 2, "positive screen-space cross selects right strafe")
	equal(MeleeBody.relative_gait_index(east, Vector2i(-900, 0)), 3, "negative dot selects backward")
	equal(MeleeBody.relative_gait_index(east, Vector2i(0, -900)), 4, "negative screen-space cross selects left strafe")
	equal(MeleeBody.relative_gait_index(east, Vector2i(700, 700)), 1, "forward owns the exact forward-right boundary")
	equal(MeleeBody.relative_gait_index(east, Vector2i(-700, 700)), 3, "backward owns the exact back-right boundary")
	equal(MeleeBody.relative_gait_index(Vector2i.ZERO, east), -1, "missing latched aim fails closed")


func _test_phase_selection() -> void:
	for physical_kind: int in [1, 2]:
		for physical_phase: int in [1, 2, 3]:
			var phase := MeleeBody.phase_selector(physical_kind, physical_phase, 3, 6)
			equal(int(phase.get("attack_index", -1)), physical_kind - 1, "physical kind selects the baked attack")
			equal(int(phase.get("phase_index", -1)), physical_phase - 1, "physical phase selects the exact authored key")
			equal(str(phase.get("phase_name", "")), MeleeBody.PHASES[physical_phase - 1], "phase selector reports its authored name")
			check(is_equal_approx(float(phase.get("progress", -1.0)), 0.5), "phase timing reports bounded authority progress without changing frames")
	equal(MeleeBody.phase_selector(0, 1, 1, 2), {}, "no physical attack has no melee frame")
	equal(MeleeBody.phase_selector(1, 0, 1, 2), {}, "missing physical phase has no melee frame")
	equal(MeleeBody.phase_selector(1, 1, -1, 2), {}, "negative remaining ticks fail closed")
	equal(MeleeBody.phase_selector(1, 1, 3, 2), {}, "remaining ticks above total fail closed")
	equal(MeleeBody.phase_selector(1, 1, 0, 0), {}, "active phase requires a positive authored duration")


func _test_attachment_schema() -> void:
	equal(MeleeBody.ATTACHMENT_RECORD_FIELDS, ["body_index", "gait_index", "physical_kind", "physical_phase", "aim_index", "point_x", "point_y", "pixel_x", "pixel_y"], "compact records declare every key and already-baked coordinate")
	equal(MeleeBody.ATTACHMENT_COORDINATE_SPACE, "baked_cell_pixels_subpixel", "attachment coordinates are explicitly post-bake local cell pixels")
	var presenter := MeleeBody.new()
	equal(presenter.attachment_status, "missing_attachment_table", "an unloaded table is explicitly missing")


func _test_promoted_resources() -> void:
	var presenter := MeleeBody.new()
	check(presenter.configure(), "promoted melee manifest, pages and compact attachment table load: " + presenter.last_error)
	if not presenter.ready():
		return
	equal(presenter.page_textures.size(), 3, "only the three shared body pages are resident")
	equal(presenter.frame_records.size(), MeleeBody.FRAME_COUNT, "manifest indexes all 720 shared body frames")
	equal(presenter.attachment_status, "verified_compact_table", "promoted compact table supplies exact striking attachments")
	equal(presenter.attachment_records.size(), MeleeBody.FRAME_COUNT, "every rendered melee frame has a corresponding compact attachment")
	for body_type: String in MeleeBody.BODY_TYPES:
		var texture := presenter.page_texture(body_type)
		check(texture != null and texture.get_size() == MeleeBody.PAGE_DIMENSIONS, "body page retains its authored dimensions")
		for aim_index: int in 8:
			var aim: Vector2i = EightDirectionResolver.FIXED_VECTORS[aim_index]
			var travels: Array[Vector2i] = [
				Vector2i.ZERO,
				aim,
				Vector2i(-aim.y, aim.x),
				-aim,
				Vector2i(aim.y, -aim.x),
			]
			for gait_index: int in MeleeBody.GAITS.size():
				for physical_kind: int in [1, 2]:
					for physical_phase: int in [1, 2, 3]:
						var frame := presenter.frame(body_type, physical_kind, physical_phase, aim, travels[gait_index], 2, 4)
						check(not frame.is_empty(), "every promoted matrix cell resolves")
						if frame.is_empty():
							continue
						equal(frame.get("texture"), texture, "frame uses its shared size page")
						equal(frame.get("source_region"), MeleeBody.source_region(gait_index, physical_kind, physical_phase, aim_index), "frame follows the baker row order")
						equal(frame.get("relative_gait_index"), gait_index, "travel-to-latched-aim stance stays independent from attack phase")
						check(not frame.has("scale") and not frame.has("offset"), "body adapter cannot override the composite movement scale or offset")
						equal(frame.get("display_height"), MeleeBody.DISPLAY_HEIGHTS[body_type], "frame reports its baked display height")
						check(bool(frame.get("attachment_available", false)), "frame exposes a verified compact-table attachment")
						equal(str(frame.get("attachment_name", "")), "hand_r" if physical_kind == 1 else "toe_r", "Punch and Kick expose the authored striking limb")
						var attachment: Vector2 = frame.get("attachment_point", Vector2.INF)
						check(attachment.is_finite() and Rect2(Vector2.ZERO, MeleeBody.CELL).has_point(attachment), "attachment stays in the fixed local cell")
	check(presenter.frame("small", 0, 0, Vector2i(0, 1000), Vector2i.ZERO, 0, 0).is_empty(), "inactive physical state falls back to the ordinary body presenter")
	check(presenter.frame("small", 1, 1, Vector2i.ZERO, Vector2i.ZERO, 1, 2).is_empty(), "missing latched aim cannot select a melee silhouette")


func _test_missing_attachment_table_is_explicit() -> void:
	if not FileAccess.file_exists(MeleeBody.DEFAULT_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MeleeBody.DEFAULT_PATH))
	if not parsed is Dictionary:
		return
	var without_table: Dictionary = (parsed as Dictionary).duplicate(true)
	without_table.erase("attachment_table")
	var path := "user://melee_manifest_without_attachment_table.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "test can write an isolated manifest without optional attachments")
	if file == null:
		return
	file.store_string(JSON.stringify(without_table))
	file.close()
	var presenter := MeleeBody.new()
	check(presenter.configure(path), "body pages remain usable when no attachment table is referenced: " + presenter.last_error)
	if not presenter.ready():
		return
	equal(presenter.attachment_status, "missing_attachment_table", "unreferenced optional table remains explicit")
	var frame := presenter.frame("small", 1, 2, Vector2i(0, 1000), Vector2i.ZERO, 1, 2)
	check(not frame.is_empty(), "missing optional table does not erase valid body art")
	check(not bool(frame.get("attachment_available", true)), "frame never invents an attachment when the table is missing")
	equal(frame.get("attachment_point"), Vector2.INF, "missing attachment uses an explicit non-position sentinel")
	equal(str(frame.get("attachment_source", "")), "missing_attachment_table", "frame reports why the attachment is unavailable")


func _test_missing_manifest_fails_closed() -> void:
	var presenter := MeleeBody.new()
	check(not presenter.configure("res://assets/sprites/wireframe_melee_v1/definitely-missing.json"), "missing melee manifest fails closed")
	check(not presenter.ready() and presenter.page_textures.is_empty(), "failed configuration leaves no partial texture residency")
