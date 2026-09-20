extends FluxTestSuite


const Body = preload("res://src/presentation/wireframe_body_presenter.gd")
const Guide = preload("res://art_batches/character_style_v1/template_v2/pose_guide_model.gd")


func run() -> int:
	_test_compact_proportion_contract()
	_test_matrix_geometry()
	_test_default_live_roster()
	_test_manifest_fail_closed()
	return finish("wireframe-body-presenter")


func _test_compact_proportion_contract() -> void:
	equal(Body.BODY_HEIGHTS, {"small": 58, "middle": 68, "large": 76}, "historical authoring envelopes are not runtime visible heights")
	equal(Body.DISPLAY_HEIGHTS, {"small": 58, "middle": 63, "large": 68}, "three live sizes have modest five-pixel increments")
	equal(Body.MOTION_REVISION, "slide_v1", "revised fixed-bone slide geometry has a distinct revision")
	var head_count := Guide.SOUTH_STANDING_SPAN / (Guide.HEAD_RADIUS * 2.0)
	check(head_count >= 4.0 and head_count <= 4.5, "shared construction is four to four-and-a-half heads tall")
	for body_type: String in Body.BODY_TYPES:
		check(is_equal_approx(float(Body.BODY_HEIGHTS[body_type]) * float(Body.PRESENTATION_SCALES[body_type]), float(Body.DISPLAY_HEIGHTS[body_type])), "one explicit per-size bake scale reaches the requested visible height")
	for state_id: String in Guide.STATES:
		var pose := Guide.landmarks(state_id)
		check(not pose.is_empty(), "compact head does not invalidate an existing fixed-bone base pose")
		if pose.is_empty():
			continue
		var shoulders: Vector3 = (pose.shoulder_l + pose.shoulder_r) * 0.5
		check(is_equal_approx(shoulders.distance_to(pose.head), Guide.HEAD_OFFSET), "all base poses use the same shortened head attachment")
		check(is_equal_approx(shoulders.distance_to(pose.neck), Guide.NECK_OFFSET), "all base poses use the same compact neck")
		check(is_equal_approx(shoulders.distance_to(pose.pelvis), Guide.TORSO), "head proportion changes do not stretch the torso")


func _test_matrix_geometry() -> void:
	var cells: Dictionary = {}
	for travel: int in 8:
		for aim: int in 8:
			for phase: int in 8:
				var region: Rect2 = Body.locomotion_region(travel, aim, phase)
				check(Rect2(Vector2.ZERO, Body.MATRIX_DIMENSIONS).encloses(region), "each travel/aim/phase sample fits its single size atlas")
				check(not cells.has(region.position), "every travel/aim/phase has a distinct authored cell")
				cells[region.position] = true
	equal(cells.size(), 512, "one shared size atlas holds all 64 independent direction pairs and eight gait phases")
	for indices: Vector3i in [Vector3i(-1, 0, 0), Vector3i(0, 8, 0), Vector3i(0, 0, 8)]:
		equal(Body.locomotion_region(indices.x, indices.y, indices.z), Rect2(), "invalid matrix indices fail closed")
	equal(Body.base_region("unknown", 0), Rect2(), "unknown base action fails closed")


func _test_default_live_roster() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "wireframe visual language loads")
	var presenter := CartoonChampionPresenter.new()
	var configured := presenter.configure(language)
	check(configured, "default live presentation loads shared size skeletons: " + presenter.last_error)
	if not presenter.wireframe_body.ready():
		return
	check(presenter.wireframe_mode, "all live characters default to skeleton presentation")
	equal(presenter.extension_atlases.size(), 0, "skeleton mode loads no per-identity legacy texture pages")
	equal(presenter.override_resident_count(), 0, "skeleton mode admits no per-identity skin overrides")
	check(presenter.atlas == null, "skeleton mode does not load the legacy foundation atlas")
	equal(presenter.wireframe_body.base_textures.size(), 3, "base poses share exactly three size textures")
	equal(presenter.wireframe_body.locomotion_textures.size(), 3, "locomotion shares exactly three size textures")
	equal(presenter.wireframe_body.sprint_textures.size(), 3, "dynamic sprint adds only three shared size textures")
	var portraits: Dictionary = {}
	var examples: Dictionary = {}
	for champion_id: String in presenter.champions:
		var recipe: Dictionary = presenter.champions[champion_id]
		var body_type := String(recipe["body_type"])
		examples[body_type] = champion_id
		check(presenter.can_present(champion_id), "every live identity can present its corresponding size skeleton")
		equal(presenter.texture_for_champion(champion_id), presenter.wireframe_body.base_texture(body_type), "identity and ancestry cannot replace the size-only skeleton")
		var portrait := presenter.portrait_frame(champion_id)
		equal(portrait.get("visual_mode"), "wireframe_body", "Gallery labels the active body honestly")
		equal(portrait.get("body_type"), body_type, "portrait reports the actual body size")
		equal(portrait.get("template_source_id"), "", "skeletons do not claim to borrow another named character")
		var source: Rect2 = portrait["source_region"]
		var occupied: Rect2 = portrait["occupied_model_region"]
		equal(source.position, occupied.position, "skeleton portrait begins at its South-facing model top")
		equal(source.size, Vector2(occupied.size.x, ceilf(occupied.size.y / 3.0)), "skeleton portrait contains the anatomical top third")
		portraits[(portrait["texture"] as Texture2D).get_instance_id()] = true
		for aim: int in 8:
			var inspection := presenter.inspection_frame(champion_id, EightDirectionResolver.DIRECTION_ORDER[aim])
			equal(inspection.get("texture"), presenter.texture_for_champion(champion_id), "Gallery reuses the same three world size templates")
			equal(inspection.get("region"), Body.base_region("grounded", aim), "Gallery direction is the requested skeleton heading")
	equal(portraits.size(), 3, "all identities reuse exactly three prepared skeleton portraits")
	equal(examples.size(), 3, "live roster retains all three body sizes")
	var config := SimConfig.new(120)
	for body_type: String in examples:
		var champion_id := String(examples[body_type])
		var body_pixels := presenter.wireframe_body.base_texture(body_type).get_image()
		var standing_pixels := body_pixels.get_region(Rect2i(0, 0, 96, 96))
		equal(standing_pixels.get_used_rect().size.y, int(Body.DISPLAY_HEIGHTS[body_type]), "per-size bake has its measured visible height without changing source authoring envelopes")
		equal(standing_pixels.get_used_rect().end.y, 84, "dressed adventurer retains the same feet pivot")
		for travel_index: int in 8:
			var travel := EightDirectionResolver.FIXED_VECTORS[travel_index]
			for aim_index: int in 8:
				var aim := EightDirectionResolver.FIXED_VECTORS[aim_index]
				var state := PlayerState.new(7)
				state.velocity_x = travel.x * 300
				state.velocity_y = travel.y * 300
				state.aim_x = aim.x
				state.aim_y = aim.y
				state.facing_x = travel.x
				state.facing_y = travel.y
				for mode: int in [PlayerState.MovementMode.WALK, PlayerState.MovementMode.SPRINT]:
					state.movement_mode = mode
					var canonical := state.canonical_values()
					for phase_index: int in 8:
						var phase := float(phase_index) / 8.0
						var frame := presenter.movement_frame(champion_id, state, 0.0, config, false, phase)
						var later := presenter.movement_frame(champion_id, state, 950.0, config, false, phase)
						equal(frame.get("source_region"), Body.locomotion_region(travel_index, aim_index, phase_index), "live walk/sprint independently resolves travel A, aim B and distance phase")
						var expected_bank: Dictionary = presenter.wireframe_body.sprint_textures if mode == PlayerState.MovementMode.SPRINT else presenter.wireframe_body.locomotion_textures
						equal(frame.get("texture"), expected_bank[body_type], "walk and sprint use distinct matching size gait textures")
						equal(frame.get("gait_bank"), "sprint" if mode == PlayerState.MovementMode.SPRINT else "walk", "stronger sprint is a distinct authored gait, not just a faster walk page")
						equal(frame.get("source_region"), later.get("source_region"), "clock advancement cannot move a held distance phase")
						equal(frame.get("aim_index"), aim_index, "all movement directions retain cursor-facing anatomy")
						equal(frame.get("scale"), Vector2.ONE, "skeleton gait never stretches body size")
						equal(frame.get("style_id"), Body.STYLE_ID, "every travel/aim frame uses the shared warm adventurer foundation")
						equal(frame.get("motion_revision"), Body.MOTION_REVISION, "all directions share the compact proportion revision")
						equal(frame.get("baked_presentation_scale"), Body.PRESENTATION_SCALES[body_type], "modest size difference is already baked, not a second runtime body scale")
						equal(frame.get("display_height"), Body.DISPLAY_HEIGHTS[body_type], "movement VFX receive the visible frame height rather than the legacy authoring envelope")
						equal(state.canonical_values(), canonical, "presentation cannot mutate movement, hitboxes or combat authority")
					state.pending_cast_wire_id = 145
					var casting_canonical := state.canonical_values()
					var casting_frame := presenter.movement_frame(champion_id, state, 0.0, config, false, 0.375)
					equal(casting_frame.get("source_region"), Body.locomotion_region(travel_index, aim_index, 3), "occupied casting startup retains all64 travel/aim pairs and current stride")
					equal(casting_frame.get("aim_index"), aim_index, "moving spellcast keeps current cursor-facing anatomy")
					equal(state.canonical_values(), casting_canonical, "moving-cast animation cannot change cast or movement authority")
					state.pending_cast_wire_id = 0
		check(presenter.wireframe_body.sprint_textures[body_type] != presenter.wireframe_body.locomotion_textures[body_type], "each body keeps separate sprint geometry while reusing it across identities")
		var state := PlayerState.new(3)
		for animation_state: String in Body.BASE_ROWS:
			equal(presenter.source_region_for_animation_state(champion_id, state, animation_state), Body.base_region(animation_state, EightDirectionResolver.classify_index(state.aim_x, state.aim_y)), "base-only region API stays paired with base-only texture API")
	check(presenter.inspection_frame("unknown", "south").is_empty(), "unknown identity cannot fall back to another body")
	check(presenter.portrait_frame("unknown").is_empty(), "unknown portrait fails closed")
	presenter.wireframe_body.clear()
	check(not presenter.can_present("oh_tipi"), "missing wireframe resource never silently reactivates a legacy skin")
	check(presenter.movement_frame("oh_tipi", PlayerState.new(1), 0.0, config).is_empty(), "missing wireframe resource cannot produce a draw frame")


func _test_manifest_fail_closed() -> void:
	var body := Body.new()
	var configured := body.configure()
	check(configured, "wireframe resources load before rejected reload: " + body.last_error)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(Body.DEFAULT_PATH))
	if not parsed is Dictionary:
		return
	var malformed: Dictionary = (parsed as Dictionary).duplicate(true)
	malformed["sizes"]["middle"]["locomotion_rgba_sha256"] = "0".repeat(64)
	var path := "user://wireframe_body_rejected_manifest.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "test can write isolated malformed manifest")
	if file == null:
		return
	file.store_string(JSON.stringify(malformed))
	file.close()
	check(not body.configure(path), "changed decoded pixels fail closed even when PNG metadata is valid")
	equal(body.base_textures.size(), 0, "rejected partial reload releases already prepared sizes")
	equal(body.locomotion_textures.size(), 0, "rejected partial reload exposes no mixed locomotion pages")
	equal(body.sprint_textures.size(), 0, "rejected reload exposes no stale sprint pages")
	check(not body.ready(), "a rejected reload cannot remain ready")
	DirAccess.remove_absolute(path)
	var restored := body.configure()
	check(restored, "valid banks restore before the late Large sprint rejection case")
	if not restored:
		return
	var late_malformed: Dictionary = (parsed as Dictionary).duplicate(true)
	late_malformed["sizes"]["large"]["sprint_rgba_sha256"] = "0".repeat(64)
	var late_path := "user://wireframe_body_rejected_large_sprint_manifest.json"
	var late_file := FileAccess.open(late_path, FileAccess.WRITE)
	check(late_file != null, "test can write isolated late Large sprint corruption")
	if late_file == null:
		return
	late_file.store_string(JSON.stringify(late_malformed))
	late_file.close()
	check(not body.configure(late_path), "late Large sprint decoded-digest corruption rejects the reload")
	check(body.last_error.contains("large-sprint.png"), "late rejection identifies the corrupted Large sprint page")
	equal(body.base_textures.size(), 0, "late Large sprint rejection releases all prepared base banks")
	equal(body.locomotion_textures.size(), 0, "late Large sprint rejection releases all prepared walk banks")
	equal(body.sprint_textures.size(), 0, "late Large sprint rejection releases all prepared sprint banks")
	check(not body.ready(), "late Large sprint rejection cannot expose partially configured banks")
	DirAccess.remove_absolute(late_path)
	var invalid_scale: Dictionary = (parsed as Dictionary).duplicate(true)
	invalid_scale["sizes"]["middle"]["presentation_scale"] = 0.5
	var scale_path := "user://adventurer_rejected_scale_manifest.json"
	var scale_file := FileAccess.open(scale_path, FileAccess.WRITE)
	check(scale_file != null, "test can write isolated invalid baked-scale contract")
	if scale_file == null:
		return
	scale_file.store_string(JSON.stringify(invalid_scale))
	scale_file.close()
	check(not body.configure(scale_path), "unapproved per-size baked scale cannot silently replace the shared body contract")
	check(body.last_error.contains("presentation scale"), "scale rejection reports the presentation-only contract")
	DirAccess.remove_absolute(scale_path)
	var invalid_motion: Dictionary = (parsed as Dictionary).duplicate(true)
	invalid_motion["motion_revision"] = "obsolete_aim_ready"
	var motion_path := "user://adventurer_rejected_motion_manifest.json"
	var motion_file := FileAccess.open(motion_path, FileAccess.WRITE)
	check(motion_file != null, "test can write isolated stale motion contract")
	if motion_file == null:
		return
	motion_file.store_string(JSON.stringify(invalid_motion))
	motion_file.close()
	check(not body.configure(motion_path), "old motion art cannot silently satisfy the new proportion contract")
	check(body.last_error.contains("motion revision"), "stale motion rejection names the changed art contract")
	check(not body.ready() and body.base_textures.is_empty() and body.locomotion_textures.is_empty() and body.sprint_textures.is_empty(), "stale motion exposes no mixed old/new banks")
	DirAccess.remove_absolute(motion_path)
