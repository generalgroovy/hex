extends FluxTestSuite


func run() -> int:
	_test_repository_recipes()
	_test_temporary_body_templates()
	_test_semantic_states()
	_test_semantic_aliases_fail_closed()
	_test_diagonal_contract_fails_closed()
	_test_diagonal_evasion_contract_and_direction()
	_test_relative_locomotion_gaits()
	_test_locomotion_contact_regions()
	_test_extension_pages_and_motion_facing()
	_test_live_extension_page_bounds()
	_test_extension_integrity_reload()
	_test_complete_page_overrides()
	_test_top_third_portraits()
	_test_movement_template_direction_matrix()
	_test_distance_phase_frames()
	_test_wall_contact_side()
	_test_immediate_protection_contract()
	_test_protection_body_and_budget_boundaries()
	_test_float_time_budget()
	_test_directional_movement_trails()
	_test_pixel_movement_layers()
	_test_wall_contact_lifecycle()
	return finish("cartoon-champion-presenter")


func _test_wall_contact_lifecycle() -> void:
	var config := SimConfig.new()
	var first := PixelMovementEffects.new()
	var second := PixelMovementEffects.new(first.library)
	var actor := PlayerState.new()
	actor.entity_id = 1
	actor.wall_x = 1000
	actor.wall_contact_id = 7
	actor.wall_memory_ticks = config.milliseconds_to_ticks(MovementTuning.WALL_MEMORY_MS)
	actor.hop_mode = PlayerState.MovementMode.WALL_KICK
	actor.movement_commitment_ticks = config.milliseconds_to_ticks(MovementTuning.HOP_COMMITMENT_MS)
	actor.air_vertical_velocity = 520000
	var before := actor.canonical_values()
	var contact := first.walljump_contact(actor,config,20,Vector2(100,100))
	var other := second.walljump_contact(actor,config,20,Vector2(900,400))
	equal(contact.get("anchor"),Vector2(82,100),"first world retains its own observed contact")
	equal(other.get("anchor"),Vector2(882,400),"same entity ID in a separate scope retains another contact")
	actor.wall_memory_ticks = 0
	equal(first.walljump_contact(actor,config,22,Vector2(150,60)).get("anchor"),Vector2(82,100),"another world cannot overwrite first world's historical contact")
	var camera_a := Transform2D(0,Vector2(-20,40))
	var camera_b := Transform2D(0,Vector2(-80,10))
	var fixed_world_contact: Vector2 = first.walljump_contact(actor,config,22,Vector2(150,60)).anchor
	equal(camera_b*fixed_world_contact-camera_a*fixed_world_contact,Vector2(-60,-30),"a remembered world contact follows the canvas camera, not the moving body")
	var neighbor := PlayerState.new()
	neighbor.entity_id = 2
	neighbor.wall_x = -1000
	neighbor.wall_contact_id = 9
	neighbor.wall_memory_ticks = config.milliseconds_to_ticks(MovementTuning.WALL_MEMORY_MS)
	neighbor.hop_mode = PlayerState.MovementMode.WALL_KICK
	neighbor.movement_commitment_ticks = actor.movement_commitment_ticks
	neighbor.air_vertical_velocity = 520000
	first.walljump_contact(neighbor,config,22,Vector2(300,300))
	equal(first.walljump_contact(actor,config,23,Vector2(180,40)).get("anchor"),Vector2(82,100),"another entity cannot overwrite historical contact")
	var library_before: RefCounted = first.library
	var budget_before: Dictionary = first.library.decoration_stats()
	first.clear_contacts()
	check(first.walljump_contact(actor,config,23,Vector2(180,40)).is_empty(),"world reset clears near-time reused entity contact without manufacturing a new one")
	equal(first.library,library_before,"contact reset preserves shared admitted art")
	equal(first.library.decoration_stats(),budget_before,"contact reset cannot reset the shared decoration budget")
	check(not second.walljump_contact(actor,config,23,Vector2(980,340)).is_empty(),"clearing one scope leaves the other scope's history intact")
	var presenter := CartoonChampionPresenter.new()
	presenter.pixel_movement = second
	presenter.clear_motion_contacts()
	check(second.walljump_contact(actor,config,23,Vector2(980,340)).is_empty(),"presenter lifecycle wrapper clears only its owned contact history")
	actor.wall_memory_ticks = config.milliseconds_to_ticks(MovementTuning.WALL_MEMORY_MS)
	equal(actor.canonical_values(),before,"contact sampling and lifecycle reset never change actor authority")


func _test_top_third_portraits() -> void:
	# Distinct colors above/below the anatomical third make a fixed 32px crop or
	# accidentally included body fail, even with a large transparent cell gutter.
	for height: int in [58, 68, 76]:
		var image := Image.create(192, 192, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		var used := Rect2i(123, 84 - height, 42, height)
		image.fill_rect(used, Color.RED)
		var third := ceili(float(height) / 3.0)
		image.fill_rect(Rect2i(used.position, Vector2i(42, third)), Color.BLUE)
		image.set_pixel(used.position.x + 21, used.position.y + 2, Color.TRANSPARENT)
		var original := image.get_data()
		var frame := CartoonChampionPresenter._build_portrait(image, Rect2i(96, 0, 96, 96))
		equal(frame.get("occupied_model_region"), Rect2(used), "portrait measures actual South-grounded anatomy including nonzero atlas cell origin")
		equal(frame.get("source_region"), Rect2(used.position, Vector2i(42, third)), "portrait crops exactly the top ceil(occupied height / 3), not the empty cell")
		var pixels := (frame["texture"] as Texture2D).get_image()
		equal(pixels.get_size(), Vector2i(32, 32), "each size uses one bounded compact portrait")
		var content: Rect2 = frame["content_region"]
		equal(content.size.x, 32.0, "entire occupied width is retained in the fitted portrait")
		check(absf(content.size.y - 32.0 * third / 42.0) <= 0.5, "portrait fitting preserves anatomy aspect to the nearest output pixel")
		for y: int in 32:
			for x: int in 32:
				var color := pixels.get_pixel(x, y)
				check(color == Color.BLUE or color == Color.TRANSPARENT, "nearest crop preserves transparent pixels and excludes the lower two thirds")
		check(not pixels.has_mipmaps(), "portrait upload never adds mipmap blur")
		equal(image.get_data(), original, "portrait extraction never edits the original source pixels")
	check(CartoonChampionPresenter._build_portrait(null, Rect2i(0, 0, 96, 96)).is_empty(), "missing portrait source fails closed")
	var blank := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	blank.fill(Color.TRANSPARENT)
	check(CartoonChampionPresenter._build_portrait(blank, Rect2i(0, 0, 96, 96)).is_empty(), "empty anatomy does not manufacture a portrait")
	check(CartoonChampionPresenter._build_portrait(blank, Rect2i(1, 0, 96, 96)).is_empty(), "out-of-bounds portrait source is rejected")
	var language := VisualLanguage.new()
	check(language.load_from_file(), "portrait visual language loads")
	var baseline := CartoonChampionPresenter.new()
	check(baseline.configure(language, CartoonChampionPresenter.DEFAULT_PATH, "", false), "all baseline and alias portrait paths load independently of overrides")
	var unique_textures: Dictionary = {}
	for champion_id: String in baseline.champions:
		var frame := baseline.portrait_frame(champion_id)
		var source: Rect2 = frame["source_region"]
		var occupied: Rect2 = frame["occupied_model_region"]
		equal(source.position, occupied.position, "every baseline portrait starts at the front model's actual top")
		equal(source.size, Vector2(occupied.size.x, ceilf(occupied.size.y / 3.0)), "every baseline body and alias obeys the same upper-third crop")
		equal(source, baseline.portrait_region(champion_id), "legacy source-region query is consistent with baseline atlas residency")
		equal((frame["texture"] as Texture2D).get_size(), Vector2(32, 32), "Gallery no longer receives whole-body baseline cells")
		unique_textures[(frame["texture"] as Texture2D).get_instance_id()] = true
		var template_id := String(baseline.champions[champion_id].get("template_source_id", ""))
		if not template_id.is_empty():
			check(frame["texture"] == baseline.portrait_frame(template_id)["texture"], "temporary aliases share their baseline crop without duplicate texture allocation")
		equal(frame["texture"], baseline.portrait_frame(champion_id)["texture"], "repeated portrait reads reuse the prepared compact texture")
	equal(unique_textures.size(), baseline.REQUIRED_FOUNDATION.size() + baseline.extension_atlases.size(), "only actual baseline identities allocate compact textures")
	check(baseline.portrait_frame("unknown").is_empty(), "unknown portrait metadata fails closed")
	var active := CartoonChampionPresenter.new()
	check(active.configure(language, CartoonChampionPresenter.DEFAULT_PATH, CartoonChampionPresenter.DEFAULT_OVERRIDE_PATH, false), "accepted page portraits load at configuration")
	var revision := active.portrait_revision()
	for champion_id: String in active.override_page_ids:
		var frame := active.portrait_frame(champion_id)
		var occupied: Rect2 = frame["occupied_model_region"]
		equal((frame["source_region"] as Rect2).size, Vector2(occupied.size.x, ceilf(occupied.size.y / 3.0)), "all accepted overrides use the exact anatomical crop before world residency")
		check(frame.get("complete_page_override", false), "compact portrait reports effective accepted art without requiring a full page")
		equal(active.override_resident_count(), 0, "viewing all accepted portraits never admits a world page")
		equal(active.portrait_revision(), revision, "portrait lookup cannot mutate art generation")
	for champion_id: String in active.override_page_ids:
		var first_texture: Texture2D
		for index: int in range(8):
			var view := active.inspection_frame(champion_id, EightDirectionResolver.DIRECTION_ORDER[index])
			check(not view.is_empty(), "nonresident accepted character has an inspection body")
			equal(view.region, Rect2(index * 96, 0, 96, 96), "nonresident override inspects its own first row, not baseline fallback")
			equal((view.texture as Texture2D).get_size(), Vector2(768, 960), "inspection borrows the complete accepted character page")
			if index == 0:
				first_texture = view.texture
			else:
				check(first_texture == view.texture, "turning reuses one inspection page without repeated loads")
			equal(active.override_resident_count(), 0, "inspection never changes the admitted eight-actor page set")
		equal(active._inspection_champion_id, champion_id, "one inspection slot replaces previous character instead of growing a cache")
	check(active.inspection_frame("unknown", "south").is_empty(), "unknown identity has no body preview")
	check(active.inspection_frame("oh_tipi", "unknown").is_empty(), "unknown heading cannot fake a valid front pose")
	check(active.configure(language, CartoonChampionPresenter.DEFAULT_PATH, "", false), "portrait reload can return to baseline art")
	check(active._inspection_texture == null and active._inspection_champion_id.is_empty(), "art reload releases the borrowed inspection page")
	check(active.portrait_revision() > revision, "art reload invalidates consumer portrait caches")
	for champion_id: String in active.champions:
		check(not active.portrait_frame(champion_id).get("complete_page_override", false), "baseline reload releases every stale accepted portrait")


func _test_distance_phase_frames() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "distance gait visual language loads")
	var presenter := CartoonChampionPresenter.new()
	check(presenter.configure(language, CartoonChampionPresenter.DEFAULT_PATH, CartoonChampionPresenter.DEFAULT_OVERRIDE_PATH, false), "distance gait presenter loads")
	var config := SimConfig.new(120)
	for champion_id: String in presenter.champions:
		for direction_index: int in range(8):
			var direction := EightDirectionResolver.FIXED_VECTORS[direction_index]
			var state := PlayerState.new(1)
			state.facing_x = direction.x
			state.facing_y = direction.y
			state.aim_x = direction.x
			state.aim_y = direction.y
			state.velocity_x = direction.x * 300
			state.velocity_y = direction.y * 300
			var canonical := state.canonical_values()
			for action: int in [PlayerState.MovementMode.WALK, PlayerState.MovementMode.SPRINT]:
				state.movement_mode = action
				for phase: float in [0.0, 0.25, 0.5, 0.75]:
					var first := presenter.movement_frame(champion_id, state, 0.0, config, false, phase)
					var later := presenter.movement_frame(champion_id, state, 950.0, config, false, phase)
					equal(first["source_region"], later["source_region"], "held distance phase cannot march because the wall clock advanced")
					equal(first["contact_frame"], 0 if phase < 0.5 else 1, "walk and sprint preserve the same opposite-foot phase")
					equal((first["source_region"] as Rect2).position.x, float(direction_index * 96), "distance gait never delays or blends an input-facing column")
					equal(first["scale"], Vector2.ONE, "distance cadence does not stretch the size template")
			state.movement_mode = PlayerState.MovementMode.IDLE
			equal(state.canonical_values(), canonical, "distance phase sampling never mutates authority")


func _test_temporary_body_templates() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "temporary template visual language loads")
	var presenter := CartoonChampionPresenter.new()
	check(presenter.configure(language, CartoonChampionPresenter.DEFAULT_PATH, CartoonChampionPresenter.DEFAULT_OVERRIDE_PATH, false), "explicit full-cast temporary templates load")
	var live: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(presenter.LIVE_CATALOG_PATH))
	equal(presenter.champions.size(), (live["champions"] as Array).size(), "every live identity has a bounded presentation recipe")
	var temporary_count := 0
	for entry: Dictionary in live["champions"]:
		var id := String(entry["id"])
		var recipe := presenter.recipe(id)
		equal(recipe.get("body_type"), entry.get("body_type"), "visual and simulation body agree: " + id)
		if entry.get("art_status", "") != "temporary_body_template":
			check(not recipe.get("temporary_body_template", false), "existing individual art is not mislabeled temporary")
			continue
		temporary_count += 1
		var source_id := String(entry["template_source_id"])
		check(recipe.get("temporary_body_template", false), "template substitution is explicit: " + id)
		equal(recipe.get("display_name"), entry.get("display_name"), "temporary art retains the actual identity")
		check(presenter.texture_for_champion(id) == presenter.texture_for_champion(source_id), "aliases share one texture rather than allocating extra pages")
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			var state := PlayerState.new()
			state.facing_x = direction.x
			state.facing_y = direction.y
			for pose: String in presenter.EXPECTED_ATLAS_STATES:
				equal(presenter.source_region_for_animation_state(id, state, pose), presenter.source_region_for_animation_state(source_id, state, pose), "all eighty cells retain exact body registration")
	equal(temporary_count, 25, "25 catalog fallback template declarations remain available independently of accepted overrides")
	equal(presenter.extension_atlases.size(), 2, "full cast does not grow texture allocations")
	for invalid: Dictionary in [
		{"id": "bad", "template_source_id": "oh_tipi", "body_type": "large", "art_status": "temporary_body_template", "unique_runtime_art_approved": false},
		{"id": "bad", "template_source_id": "unknown", "body_type": "middle", "art_status": "temporary_body_template", "unique_runtime_art_approved": false},
		{"id": "bad", "template_source_id": "oh_tipi", "body_type": "middle", "art_status": "approved", "unique_runtime_art_approved": true},
	]:
		check(not presenter._register_temporary_templates([invalid]), "unapproved or mismatched template fails closed")
		check(not presenter.can_present("bad"), "failed validation does not partially register artwork")


func _test_pixel_movement_layers() -> void:
	var pixels := preload("res://src/presentation/pixel_movement_effects.gd").new()
	check(pixels.ready(), "movement reads the supplied immutable pixel registry: " + pixels.library.last_error)
	var state := PlayerState.new()
	var config := SimConfig.new()
	state.air_height = 22000
	state.velocity_x = 700000
	state.air_dodge_ticks = config.milliseconds_to_ticks(MovementTuning.AIR_DODGE_DURATION_MS)
	equal(pixels.afterimage_offsets(state,config,false).size(),0,"dash afterimage cannot predate accepted dash")
	state.air_dodge_ticks -= 4
	equal(pixels.afterimage_offsets(state,config,false).size(),2,"normal dash uses two bounded body-only copies")
	equal(pixels.afterimage_offsets(state,config,true).size(),1,"reduced dash keeps one body-only copy")
	for point: Vector2 in pixels.afterimage_offsets(state,config,false):
		check(point.x < 0 and point.y == 0,"continuous velocity controls afterimage displacement")
	state.air_dodge_ticks = 0
	equal(pixels.afterimage_offsets(state,config,false).size(),0,"dash exit removes all afterimages without fade")
	var body_image := Image.create(96,96,false,Image.FORMAT_RGBA8)
	body_image.fill(Color.TRANSPARENT)
	body_image.fill_rect(Rect2i(20,18,56,66),Color("718e43"))
	var body_texture := ImageTexture.create_from_image(body_image)
	var frame: Dictionary = pixels.library.sample("magic.movement.air_dash_afterimage_mask.normal",0)
	for height: int in [58,68,76]:
		var masked: Texture2D = pixels.masked_body(body_texture,Rect2(0,0,96,96),frame,height)
		check(masked != null,"body stencil is reusable for each size")
		if masked == null:
			continue
		var result := masked.get_image()
		check(result.get_used_rect().has_area(),"body-only afterimage is visible")
		for y: int in range(0,96,3):
			for x: int in range(0,96,3):
				var color := result.get_pixel(x,y)
				if color.a > 0.0:
					equal(color,body_image.get_pixel(x,y),"stencil never paints a new body, hand or protection pixel")
		check(pixels.masked_body(body_texture,Rect2(0,0,96,96),frame,height) == masked,"cached afterimage reuses texture without rebuild")
	check(pixels.cache_size() <= pixels.CACHE_LIMIT,"afterimage texture cache is bounded")
	state.entity_id = 5
	state.hop_mode = PlayerState.MovementMode.WALL_KICK
	state.movement_commitment_ticks = config.milliseconds_to_ticks(MovementTuning.HOP_COMMITMENT_MS)
	state.air_vertical_velocity = 520000
	check(pixels.walljump_contact(state,config,10,Vector2(100,100)).is_empty(),"unobserved wall contact never manufactures sparks beside the moving body")
	state.wall_x = 1000
	state.wall_y = 0
	state.wall_contact_id = 1
	state.wall_memory_ticks = config.milliseconds_to_ticks(MovementTuning.WALL_MEMORY_MS)
	var contact: Dictionary = pixels.walljump_contact(state,config,10,Vector2(100,100))
	check(not contact.is_empty(),"actual current contact can anchor a walljump burst")
	state.wall_memory_ticks = 0
	var moved: Dictionary = pixels.walljump_contact(state,config,12,Vector2(130,130))
	equal(moved.get("anchor"),contact.get("anchor"),"walljump dust stays fixed at the real old contact")
	check(pixels.walljump_contact(state,config,100,Vector2(130,130)).is_empty(),"old wall contact cannot be reused by a future airtime")


func _test_extension_pages_and_motion_facing() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "motion-facing language loads")
	var presenter := CartoonChampionPresenter.new()
	check(presenter.configure(language, CartoonChampionPresenter.DEFAULT_PATH, CartoonChampionPresenter.DEFAULT_OVERRIDE_PATH, false), "paged champion art validates")
	for champion_id: String in presenter.champions:
		var pixels := presenter.texture_for_champion(champion_id).get_image()
		var portrait := presenter.portrait_region(champion_id)
		check(Rect2(Vector2.ZERO, pixels.get_size()).encloses(portrait), "portrait stays in the character's own atlas")
		check(pixels.get_region(Rect2i(portrait)).get_used_rect().has_area(), "every playable champion has a current portrait")
		var row := int(presenter.recipe(champion_id).get("atlas_row", 0)) * 960
		for direction: int in range(8):
			var first := pixels.get_region(Rect2i(direction * 96, row + 384, 96, 96))
			var second := pixels.get_region(Rect2i(direction * 96, row + 768, 96, 96))
			check(first.get_data() != second.get_data(), "walk contacts cannot be duplicate cells; anatomical quality requires separate review")
	equal(presenter.portrait_region("unknown"), Rect2(), "unknown portrait fails closed")
	for champion_id: String in presenter.extension_atlases:
		var pixels := presenter.texture_for_champion(champion_id).get_image()
		for row: int in range(10):
			for direction: int in range(8):
				var used := pixels.get_region(Rect2i(direction * 96, row * 96, 96, 96)).get_used_rect()
				check(used.size.x > 16 and used.position.x > 0 and used.end.x < 96, "extension pose remains inside its cell")
				equal(used.end.y, 85, "extension pose shares the same feet baseline")
				check(used.size.y >= 29 and used.size.y <= 60, "small extension keeps fixed anatomy envelope")
	var state := PlayerState.new()
	state.primary_held = true
	state.aim_x = -1000
	state.facing_x = -707
	state.facing_y = 707
	for pose: String in ["walk", "sprint", "jump", "slide", "roll"]:
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			state.facing_x = direction.x
			state.facing_y = direction.y
			state.velocity_x = direction.x * 300
			state.velocity_y = direction.y * 300
			state.aim_x = -direction.x
			state.aim_y = -direction.y
			var expected := direction * 300 if pose == "slide" else -direction
			equal(CartoonChampionPresenter.presentation_facing_vector(state, pose), expected, pose + " uses travel for slide and independent aim for other poses")
	state.velocity_x = 0
	state.velocity_y = 300000
	state.facing_x = 0
	state.facing_y = -1000
	state.aim_x = 0
	state.aim_y = -1000
	equal(presenter.source_region_for_animation_state("oh_tipi", state, "slide"), Rect2(0, 576, 96, 96), "slide body follows south travel while spell aim stays north")
	state.pending_cast_wire_id = 1
	state.pending_cast_aim_x = -1000
	state.pending_cast_aim_y = 0
	state.aim_x = 1000
	state.aim_y = 0
	for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		state.velocity_x = direction.x
		state.velocity_y = direction.y
		state.facing_x = direction.x
		state.facing_y = direction.y
		for mode: int in [PlayerState.MovementMode.WALK, PlayerState.MovementMode.SPRINT, PlayerState.MovementMode.SLIDE]:
			state.movement_mode = mode
			var pose := String(PlayerState.MovementMode.keys()[mode]).to_lower()
			equal(presenter.silhouette_state(state), pose, "moving casts preserve " + pose + " contacts")
			equal(CartoonChampionPresenter.presentation_facing_vector(state, presenter.silhouette_state(state)), Vector2i(1000, 0), "moving casts face current cursor without replacing locomotion")
	state.velocity_x = 0
	state.velocity_y = 0
	state.movement_mode = PlayerState.MovementMode.IDLE
	equal(presenter.silhouette_state(state), "cast", "stationary casts retain the authored bare-hand pose")
	equal(CartoonChampionPresenter.presentation_facing_vector(state, "cast"), Vector2i(1000, 0), "stationary casting follows current cursor, not the locked shot")
	equal(state.pending_cast_aim_x, -1000, "visual turning cannot retarget the committed shot")
	state.movement_mode = PlayerState.MovementMode.HOP
	state.hop_ticks = 2
	state.air_height = 1000
	equal(presenter.silhouette_state(state), "jump", "air casting never substitutes standing legs")
	state.control_state = PlayerState.ControlState.STUNNED
	equal(presenter.silhouette_state(state), "hit", "loss of control keeps precedence over cast locomotion")


func _test_live_extension_page_bounds() -> void:
	var visual: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CartoonChampionPresenter.DEFAULT_PATH))
	var live: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CartoonChampionPresenter.LIVE_CATALOG_PATH))
	var entries: Array = live["champions"]
	var presenter := CartoonChampionPresenter.new()
	presenter.champions = (visual["champions"] as Dictionary).duplicate(true)
	check(presenter._validate_extension_registry(visual["extension_atlases"], entries), "current two-page registry is matched to the actual live roster")
	equal(presenter.extension_page_capacity, 27, "30 live identities permit27 individual pages beyond the three foundation bodies")
	equal(presenter.extension_page_capacity, entries.size() - presenter.REQUIRED_FOUNDATION.size(), "page bound is content-derived, not the previous21-page limit")
	# Structural admission fixture only: no new image files, accepted art, or GPU
	# resources are produced by describing future pages for existing identities.
	var full_pages: Dictionary = {}
	for entry: Dictionary in entries:
		var id := String(entry["id"])
		if id in presenter.REQUIRED_FOUNDATION:
			continue
		if not presenter.champions.has(id):
			presenter.champions[id] = (visual["champions"][String(entry["template_source_id"])] as Dictionary).duplicate(true)
		full_pages[id] = {"path": "res://assets/sprites/champions_v3/capacity_fixture/" + id + ".png", "sha256": "a".repeat(64), "imported_rgba_sha256": "b".repeat(64)}
	var full_recipes := presenter.champions.duplicate(true)
	check(presenter._validate_extension_registry(full_pages, entries), "all matched live page descriptors are admitted before file/import checks")
	check(presenter.extension_atlases.is_empty() and presenter.atlas == null, "descriptor admission creates no textures or fake runtime art")
	var mutations: Array[Dictionary] = []
	var extra := full_pages.duplicate(true)
	extra["not_in_cast"] = (full_pages["grace_reava"] as Dictionary).duplicate(true)
	mutations.append(extra)
	var missing := full_pages.duplicate(true)
	missing.erase("grace_reava")
	mutations.append(missing)
	var wrong_identity := full_pages.duplicate(true)
	wrong_identity["not_in_cast"] = wrong_identity["grace_reava"]
	wrong_identity.erase("grace_reava")
	mutations.append(wrong_identity)
	var base_page := full_pages.duplicate(true)
	base_page["oh_tipi"] = base_page["grace_reava"]
	base_page.erase("grace_reava")
	mutations.append(base_page)
	var duplicate_path := full_pages.duplicate(true)
	duplicate_path["wa_bidi"]["path"] = duplicate_path["grace_reava"]["path"]
	mutations.append(duplicate_path)
	for bad_path: String in ["res://assets/other.png", "res://assets/sprites/champions_v3/../other.png", "res://assets/sprites/champions_v3/page.txt"]:
		var bad := full_pages.duplicate(true)
		bad["grace_reava"]["path"] = bad_path
		mutations.append(bad)
	for field: String in ["sha256", "imported_rgba_sha256"]:
		for invalid_digest: String in ["a".repeat(63), "g".repeat(64), "-" + "a".repeat(63), "é".repeat(64)]:
			var bad := full_pages.duplicate(true)
			bad["grace_reava"][field] = invalid_digest
			mutations.append(bad)
	var malformed := full_pages.duplicate(true)
	malformed["grace_reava"] = []
	mutations.append(malformed)
	for mutation: Dictionary in mutations:
		check(not presenter._validate_extension_registry(mutation, entries), "extra, unmatched, duplicate, escaped or unauthenticated page descriptors fail closed")
		equal(presenter.extension_page_capacity, 0, "rejected page registry exposes no validated allowance")
		check(not presenter.last_error.is_empty(), "page descriptor rejection has an explicit reason")
	var duplicate_id := entries.duplicate(true)
	duplicate_id.append(entries[0])
	var missing_base := entries.duplicate(true)
	missing_base.pop_front()
	var excessive := entries.duplicate(true)
	while excessive.size() <= presenter.MAX_LIVE_RECIPES:
		excessive.append(entries[0])
	for invalid_entries: Array in [duplicate_id, missing_base, excessive, [null]]:
		check(not presenter._validate_extension_registry(full_pages, invalid_entries), "invalid live identity source cannot inflate atlas capacity")
	presenter.champions.erase("grace_reava")
	check(not presenter._validate_extension_registry(full_pages, entries), "a live ID without an authored recipe cannot acquire a page")
	presenter.champions = full_recipes
	presenter.champions["orphan_recipe"] = (full_recipes["oh_tipi"] as Dictionary).duplicate(true)
	check(not presenter._validate_extension_registry(full_pages, entries), "an authored recipe outside the live catalog is rejected")


func _test_extension_integrity_reload() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "page integrity language loads")
	var presenter := CartoonChampionPresenter.new()
	var started := Time.get_ticks_usec()
	check(presenter.configure(language, CartoonChampionPresenter.DEFAULT_PATH, CartoonChampionPresenter.DEFAULT_OVERRIDE_PATH, false), "baseline individual pages validate before adversarial reload")
	var configure_usec := Time.get_ticks_usec() - started
	var payload_bytes := int(presenter.atlas.get_width() * presenter.atlas.get_height() * 4)
	for texture: Texture2D in presenter.extension_atlases.values():
		payload_bytes += texture.get_width() * texture.get_height() * 4
	print("CHAMPION_ATLAS_SETUP live=%d extensions=%d capacity=%d decoded_payload_bytes=%d configure_us=%d" % [presenter.champions.size(), presenter.extension_atlases.size(), presenter.extension_page_capacity, payload_bytes, configure_usec])
	var visual: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CartoonChampionPresenter.DEFAULT_PATH))
	var fixture_path := "user://cartoon-atlas-integrity-%d.json" % Time.get_ticks_usec()
	for mutation_id: String in ["orphan", "missing_file", "source_hash", "imported_hash"]:
		var changed := visual.duplicate(true)
		var pages: Dictionary = changed["extension_atlases"]
		match mutation_id:
			"orphan":
				pages["not_in_cast"] = (pages["grace_reava"] as Dictionary).duplicate(true)
			"missing_file":
				pages["grace_reava"]["path"] = "res://assets/sprites/champions_v3/no-such-atlas-integrity-fixture.png"
			"source_hash":
				pages["grace_reava"]["sha256"] = "0".repeat(64)
			"imported_hash":
				pages["grace_reava"]["imported_rgba_sha256"] = "0".repeat(64)
		var file := FileAccess.open(fixture_path, FileAccess.WRITE)
		check(file != null, "isolated invalid manifest fixture opens")
		if file == null:
			return
		file.store_string(JSON.stringify(changed))
		file.close()
		check(not presenter.configure(language, fixture_path, CartoonChampionPresenter.DEFAULT_OVERRIDE_PATH, false), "real configure rejects " + mutation_id)
		check(not presenter.last_error.is_empty(), "real rejected configure reports its integrity failure")
		check(presenter.champions.is_empty() and presenter.extension_atlases.is_empty() and presenter.atlas == null, "failed reload cannot expose old or partly validated page textures")
		equal(presenter.extension_page_capacity, 0, "failed reload clears page allowance")
		equal(presenter.content_hash, "", "failed reload cannot advertise a valid manifest hash")
		equal(DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path)), OK, "isolated integrity fixture is removed")
	check(presenter.configure(language, CartoonChampionPresenter.DEFAULT_PATH, CartoonChampionPresenter.DEFAULT_OVERRIDE_PATH, false), "valid full-cast template presentation recovers after every rejected reload")
	equal(presenter.champions.size(), 30, "capacity fix retains all current30 visible identities")
	equal(presenter.extension_atlases.size(), 2, "capacity fix does not manufacture future champion pages")


func _override_manifest(pages: Dictionary) -> Dictionary:
	return {
		"schema_version": 1, "id": CartoonChampionPresenter.OVERRIDE_ID,
		"authority": CartoonChampionPresenter.EXPECTED_AUTHORITY,
		"cell": [96, 96], "pivot": [48, 84], "dimensions": [768, 960], "runtime_scale": [1, 1],
		"directions": CartoonChampionPresenter.EXPECTED_DIRECTIONS.duplicate(),
		"states": CartoonChampionPresenter.EXPECTED_ATLAS_STATES.duplicate(),
		"frame_count": 80, "row_layout": "state_major_direction_minor",
		"sampling": "nearest_no_mipmaps", "atlas_role": "body_and_clothing_only",
		"timing": "existing_minimal_champion_motion", "pages": pages,
	}


func _test_complete_page_overrides() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "override language loads")
	var presenter := CartoonChampionPresenter.new()
	check(presenter.configure(language, presenter.DEFAULT_PATH, "", false), "explicit baseline has no optional overrides")
	var visual: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(presenter.DEFAULT_PATH))
	_test_cross_baseline_override_identity(presenter, visual)
	var approved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(presenter.DEFAULT_OVERRIDE_PATH))
	# Reuse the actually approved S. Wayne page as a loader fixture, never another identity's art.
	var source_page: Dictionary = approved["pages"]["s_wayne"].duplicate(true)
	var manifest := _override_manifest({"s_wayne": source_page})
	check(presenter._validate_override_manifest(manifest), "required foundation IDs can own a complete independent replacement page")
	var all_pages: Dictionary = {}
	for champion_id: String in presenter.champions:
		var page := source_page.duplicate(true)
		page["path"] = "res://assets/sprites/champions_v3/test-descriptor-only/" + champion_id + ".png"
		page["body_type"] = presenter.champions[champion_id]["body_type"]
		page["reference_height"] = presenter.champions[champion_id]["height"]
		page["sha256"] = (champion_id + "source-descriptor-only").sha256_text()
		page["imported_rgba_sha256"] = (champion_id + "pixels-descriptor-only").sha256_text()
		all_pages[champion_id] = page
	check(presenter._validate_override_manifest(_override_manifest(all_pages)), "all current live IDs admit descriptors without loading nonexistent future art")
	equal(presenter.override_resident_count(), 0, "descriptor checks allocate no complete-page textures")
	var too_many: Array[String] = []
	for champion_id: String in all_pages:
		too_many.append(champion_id)
		if too_many.size() == 9: break
	presenter._override_pages = all_pages.duplicate(true)
	check(not presenter.prepare_override_pages(too_many), "nine active override pages are refused before any nonexistent file is accessed")
	equal(presenter.override_resident_count(), 0, "oversized request cannot allocate a partial working set")
	presenter._override_pages.clear()
	for key: String in ["frame_count", "states", "directions", "pivot", "cell", "dimensions", "runtime_scale", "sampling", "timing", "authority", "atlas_role", "row_layout", "schema_version"]:
		var invalid := manifest.duplicate(true)
		invalid.erase(key)
		check(not presenter._validate_override_manifest(invalid), "incomplete or incompatible override metadata fails closed: " + key)
	for geometry: Array in [[48.1, 84], [48, 84.1], ["48", 84]]:
		var invalid := manifest.duplicate(true)
		invalid["pivot"] = geometry
		check(not presenter._validate_override_manifest(invalid), "fractions and numeric strings cannot shift an approved pivot")
	for changes: Dictionary in [
		{"body_type": "large"}, {"reference_height": 76}, {"status": "candidate"},
		{"visible_feet_y": 82}, {"visible_feet_y": 83.1}, {"visible_feet_y": "83"},
		{"path": "res://assets/sprites/champions_v3/../outside.png"}, {"path": "user://page.png"},
		{"sha256": "g".repeat(64)}, {"imported_rgba_sha256": "A".repeat(64)},
	]:
		var invalid := manifest.duplicate(true)
		invalid["pages"]["s_wayne"].merge(changes, true)
		check(not presenter._validate_override_manifest(invalid), "mismatched body, unaccepted status, escaped path or malformed hash fails closed")
	var orphan := manifest.duplicate(true)
	orphan["pages"]["not_a_live_character"] = source_page
	check(not presenter._validate_override_manifest(orphan), "unknown character overrides fail closed")
	var duplicated := manifest.duplicate(true)
	duplicated["pages"]["grace_reava"] = source_page
	check(not presenter._validate_override_manifest(duplicated), "one imported path cannot impersonate two approved unique pages")
	for duplicate_field: String in ["sha256", "imported_rgba_sha256"]:
		var renamed := all_pages.duplicate(true)
		renamed["steezo"][duplicate_field] = renamed["s_wayne"][duplicate_field]
		check(not presenter._validate_override_manifest(_override_manifest(renamed)), "renamed/recompressed template pixels are not unique identity art: " + duplicate_field)
	var original_pixels := presenter.texture_for_champion("grace_reava").get_image()
	check(presenter._validate_override_pixels(original_pixels, 58), "existing complete small page meets exact native registration")
	var edge_aligned := Image.create(768, 960, false, Image.FORMAT_RGBA8)
	edge_aligned.blit_rect(original_pixels, Rect2i(0, 1, 768, 959), Vector2i.ZERO)
	check(presenter._validate_override_pixels(edge_aligned, 58, 83), "new importer feet-edge convention is explicit, not a hidden sprite translation")
	check(not presenter._validate_override_pixels(edge_aligned, 58, 84), "the same pixels cannot claim a different exact feet convention")
	var raised_arm := original_pixels.duplicate() as Image
	raised_arm.set_pixel(48, 96 + 2, Color.WHITE)
	check(presenter._validate_override_pixels(raised_arm, 58), "registered raised action anatomy may extend above standing guide without rescaling")
	for mutation: String in ["empty", "gutter", "feet", "body_height", "partial", "blurred_alpha", "mipmaps", "rgb"]:
		var pixels := original_pixels.duplicate() as Image
		match mutation:
			"empty": pixels.fill_rect(Rect2i(0, 96, 96, 96), Color.TRANSPARENT)
			"gutter": pixels.set_pixel(0, 40, Color.WHITE)
			"feet": pixels.set_pixel(48, 85, Color.WHITE)
			"body_height": pixels.set_pixel(48, 2, Color.WHITE)
			"partial": pixels.crop(768, 864)
			"blurred_alpha": pixels.set_pixel(48, 40, Color(1.0, 1.0, 1.0, 0.5))
			"mipmaps": pixels.generate_mipmaps()
			"rgb": pixels.convert(Image.FORMAT_RGB8)
		check(not presenter._validate_override_pixels(pixels, 58), "pixel-level incomplete/clipped/unregistered override is rejected: " + mutation)
	var fixture_path := "user://complete-page-override-%d.json" % Time.get_ticks_usec()
	var file := FileAccess.open(fixture_path, FileAccess.WRITE)
	check(file != null, "isolated override manifest fixture opens")
	if file == null: return
	file.store_string(JSON.stringify(manifest))
	file.close()
	var configured := presenter.configure(language, presenter.DEFAULT_PATH, fixture_path, false)
	check(configured, "real source/import hashes validate a complete foundation override: " + presenter.last_error)
	if not configured: return
	equal(presenter.override_page_ids, ["s_wayne"], "only the explicitly named identity is registered")
	equal(presenter.override_resident_count(), 0, "registration retains no full-page override textures")
	var portrait := presenter.portrait_frame("s_wayne")
	check(bool(portrait.get("complete_page_override", false)), "Gallery receives the accepted portrait before world page preparation")
	equal((portrait["texture"] as Texture2D).get_size(), Vector2(32, 32), "each unique Gallery portrait occupies only32px square")
	check(presenter.portrait_frame("s_wayne")["texture"] == portrait["texture"], "Gallery portrait reuses its small verified texture")
	var baseline_texture := presenter.texture_for_champion("s_wayne")
	var state := PlayerState.new()
	state.facing_y = 1000
	state.facing_x = 0
	state.aim_x = 0
	state.aim_y = 1000
	var baseline_region := presenter.source_region_for_animation_state("s_wayne", state, "grounded")
	check(presenter.prepare_override_pages(["s_wayne", "s_wayne", "oh_tipi"]), "one unique override and baseline identities prepare atomically")
	equal(presenter.override_resident_count(), 1, "duplicate requests do not duplicate residency")
	check(presenter.texture_for_champion("s_wayne") != baseline_texture, "complete page supersedes foundation texture only when prepared")
	for pose: String in presenter.EXPECTED_ATLAS_STATES:
		for direction: String in presenter.EXPECTED_DIRECTIONS:
			var vector := EightDirectionResolver.fixed_vector(direction)
			state.facing_x = vector.x
			state.facing_y = vector.y
			state.slide_x = vector.x
			state.slide_y = vector.y
			state.aim_x = vector.x
			state.aim_y = vector.y
			var region := presenter.source_region_for_animation_state("s_wayne", state, pose)
			equal(region, Rect2(presenter.EXPECTED_DIRECTIONS.find(direction) * 96, presenter.EXPECTED_ATLAS_STATES.find(pose) * 96, 96, 96), "every override pose/direction uses the same complete native page")
	for champion_id: String in presenter.champions:
		if presenter.champions[champion_id].get("template_source_id", "") == "s_wayne":
			check(presenter.texture_for_champion(champion_id) == baseline_texture, "temporary aliases retain old source pixels when exemplar becomes unique")
	var retained := presenter.texture_for_champion("s_wayne")
	check(presenter.prepare_override_pages(["s_wayne"]), "same active set is cheap and valid")
	check(presenter.texture_for_champion("s_wayne") == retained, "same active set never reloads/uploads a full page")
	check(not presenter.prepare_override_pages(["unknown"]), "unknown preparation is refused without changing verified residency")
	equal(presenter.override_resident_count(), 1, "failed preparation preserves the old verified working set")
	check(presenter.prepare_override_pages([]), "empty active set releases complete-page ownership")
	equal(presenter.override_resident_count(), 0, "no inactive full override remains cached")
	check(presenter.texture_for_champion("s_wayne") == baseline_texture, "unprepared character retains working v15 fallback")
	state.facing_x = 0
	state.facing_y = 1000
	state.aim_x = 0
	state.aim_y = 1000
	equal(presenter.source_region_for_animation_state("s_wayne", state, "grounded"), baseline_region, "fallback uses original foundation row, not override row zero")
	check(presenter.portrait_frame("s_wayne")["texture"] == portrait["texture"], "compact portrait survives full-page eviction")
	for bad_field: String in ["sha256", "imported_rgba_sha256", "path", "baseline_clone"]:
		var invalid := manifest.duplicate(true)
		if bad_field == "baseline_clone":
			invalid["pages"]["s_wayne"].merge(visual["extension_atlases"]["grace_reava"], true)
			invalid["pages"]["s_wayne"]["visible_feet_y"] = 84
		else:
			invalid["pages"]["s_wayne"][bad_field] = "res://assets/sprites/champions_v3/missing-complete-page.png" if bad_field == "path" else "0".repeat(64)
		file = FileAccess.open(fixture_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(invalid))
		file.close()
		check(not presenter.configure(language, presenter.DEFAULT_PATH, fixture_path, false), "actual configure rejects missing or tampered override: " + bad_field)
		check(presenter.champions.is_empty() and presenter.override_page_ids.is_empty() and presenter.override_resident_count() == 0, "failed override configure exposes no partial registry or stale page set")
		check(presenter._baseline_identity_pages.is_empty(), "invalid configure also releases baseline identity fingerprints")
	var same_identity: Dictionary = visual["extension_atlases"]["grace_reava"].duplicate(true)
	same_identity.merge({"body_type": "small", "reference_height": 58, "visible_feet_y": 84, "status": "reviewed_complete_runtime_page"})
	file = FileAccess.open(fixture_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(_override_manifest({"grace_reava": same_identity})))
	file.close()
	check(presenter.configure(language, presenter.DEFAULT_PATH, fixture_path, false), "actual loader permits deliberate same-identity baseline replacement")
	check(presenter.prepare_override_pages(["grace_reava"]), "same-identity replacement remains preparable with verified pixels")
	equal(DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path)), OK, "isolated override fixture is removed")
	check(presenter.configure(language, presenter.DEFAULT_PATH, "", false), "working v15 remains reloadable without overrides")


func _test_cross_baseline_override_identity(presenter: CartoonChampionPresenter, visual: Dictionary) -> void:
	var approved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(presenter.DEFAULT_OVERRIDE_PATH))
	var page: Dictionary = approved["pages"]["s_wayne"].duplicate(true)
	var extension: Dictionary = visual["extension_atlases"]["grace_reava"]
	for field: String in ["path", "sha256", "imported_rgba_sha256"]:
		var clone := page.duplicate(true)
		clone[field] = extension[field]
		check(not presenter._validate_override_manifest(_override_manifest({"s_wayne": clone})), "another baseline extension cannot be claimed by path/source/pixel identity: " + field)
	var same_extension := page.duplicate(true)
	same_extension.merge(extension, true)
	same_extension["visible_feet_y"] = 84
	check(presenter._validate_override_manifest(_override_manifest({"grace_reava": same_extension})), "deliberate same-identity extension replacement remains valid")
	var atlas_pixels := presenter.atlas.get_image()
	for index: int in presenter.REQUIRED_FOUNDATION.size():
		var identity: String = presenter.REQUIRED_FOUNDATION[index]
		var foundation_page := atlas_pixels.get_region(Rect2i(0, index * 960, 768, 960))
		var crop := page.duplicate(true)
		crop["imported_rgba_sha256"] = presenter._bytes_sha256(foundation_page.get_data())
		var impostor := "steezo" if identity == "s_wayne" else "ha_rekt" if identity == "oh_tipi" else "fluup"
		crop["body_type"] = presenter.champions[impostor]["body_type"]
		crop["reference_height"] = presenter.champions[impostor]["height"]
		check(not presenter._validate_override_manifest(_override_manifest({impostor: crop})), "cropped/recompressed foundation pixels cannot become a different identity: " + identity)
		crop["body_type"] = presenter.champions[identity]["body_type"]
		crop["reference_height"] = presenter.champions[identity]["height"]
		check(presenter._validate_override_manifest(_override_manifest({identity: crop})), "same-identity foundation pixels remain admissible metadata: " + identity)
	equal(presenter.override_resident_count(), 0, "cross-baseline hash checks keep no full override textures resident")
	equal(presenter._baseline_identity_pages.size(), presenter.REQUIRED_FOUNDATION.size() + presenter.extension_atlases.size(), "fingerprints cover each independently verified baseline identity")
	for baseline: Dictionary in presenter._baseline_identity_pages.values():
		for fingerprint: Variant in baseline.values():
			check(fingerprint is String, "baseline cache retains only short strings, never a cropped image or texture")


func _test_repository_recipes() -> void:
	var presenter := CartoonChampionPresenter.new()
	check(not presenter.configure(null, CartoonChampionPresenter.DEFAULT_PATH, CartoonChampionPresenter.DEFAULT_OVERRIDE_PATH, false), "presenter refuses an absent visual language")
	var language := VisualLanguage.new()
	check(language.load_from_file(), "visual language loads for champion recipes")
	check(presenter.configure(language, CartoonChampionPresenter.DEFAULT_PATH, CartoonChampionPresenter.DEFAULT_OVERRIDE_PATH, false), "foundation cartoon recipes validate: %s" % presenter.last_error)
	check(presenter.atlas != null, "reviewed foundation runtime atlas loads")
	check(presenter.motion != null and presenter.motion.content_hash.length() == 64, "editable minimal-motion recipes load with champion art")
	check(presenter.content_hash.length() == 64, "champion presentation content has a stable hash")
	equal(presenter.atlas_hash, "3a0f8bb6187b360f8de1e93809447b809503af6c4ae79c3b12046dc2df273e7b", "elevated three-champion eight-way action atlas hash is pinned")
	equal(String(presenter.shared_style_contract.get("reference_champion", "")), "red_baron", "Red Baron defines the shared compact material and outline grammar")
	equal(int(presenter.shared_style_contract.get("outline_radius_pixels", 0)), 1, "shared character ink remains a bounded one-pixel treatment")
	equal(presenter.body_templates.keys(), ["small", "middle", "large"], "three reusable body-size templates load in canonical order")
	equal(String((presenter.body_templates["small"] as Dictionary).get("exemplar", "")), "s_wayne", "S. Wayne defines the reusable small template")
	equal(String((presenter.body_templates["middle"] as Dictionary).get("exemplar", "")), "oh_tipi", "Oh Tipi defines the reusable middle template")
	equal(String((presenter.body_templates["large"] as Dictionary).get("exemplar", "")), "red_baron", "The Red Baron defines the reusable large template")
	equal(presenter.cardinal_animation_contract.get("directions", []), ["south", "east", "north", "west"], "foundation animation contract covers four cardinal directions")
	equal(presenter.cardinal_animation_contract.get("states", []), ["grounded", "jump", "cast", "hit", "walk", "sprint", "slide", "roll"], "foundation animation contract covers core and movement actions")
	equal(presenter.diagonal_core_contract.get("directions", []), ["south_east", "north_east", "north_west", "south_west"], "foundation diagonal core covers four intercardinals")
	equal(presenter.diagonal_core_contract.get("states", []), ["grounded", "cast", "hit"], "foundation diagonal core is explicitly state-scoped")
	equal(presenter.diagonal_locomotion_contract.get("states", []), ["walk", "sprint"], "foundation diagonal locomotion is explicitly state-scoped")
	equal(presenter.diagonal_locomotion_contract.get("gaits", []), ["idle", "forward", "backward", "strafe_left", "strafe_right"], "relative gait catalog is exact")
	equal(presenter.diagonal_evasion_contract.get("states", []), ["jump", "slide", "roll"], "foundation diagonal evasion contract covers all three evasion states")
	equal(String(presenter.diagonal_evasion_contract.get("coverage", "")), "every_foundation_champion_has_every_diagonal_evasion_cell", "every evasion state owns native diagonal art")
	equal(presenter.locomotion_phase_contract.get("states", []), ["walk", "sprint"], "walk and sprint own alternating contact phases")
	equal(presenter.semantic_state_aliases.size(), CartoonChampionPresenter.EXPECTED_SEMANTIC_ACTIONS.size(), "every authoritative semantic action has an explicit atlas alias")
	for champion_id: String in ["oh_tipi", "s_wayne", "red_baron"]:
		check(presenter.can_present(champion_id), "%s has a promoted cartoon recipe" % champion_id)
		var recipe := presenter.recipe(champion_id)
		var height := int(recipe.get("height", 0))
		var ratio := float(recipe.get("head_ratio", 0.0))
		check(height >= 44 and height <= 76, "%s stays inside gameplay height" % champion_id)
		check(ratio >= 0.20 and ratio <= 0.23, "%s keeps the mature compact ordinary-head ratio" % champion_id)
		check((recipe.get("affinities", []) as Array).size() in [2, 3], "%s exposes only a bounded aura palette" % champion_id)
		equal(String(recipe.get("casting_origin", "")), "hands", "%s casts visibly through hands" % champion_id)
		equal(String(recipe.get("equipment", "")), "body_clothing_only", "%s keeps body and clothing separate from effects" % champion_id)
		check(String(recipe.get("body_type", "")) in ["small", "middle", "large"], "%s uses one of three body types" % champion_id)
		check(int(recipe.get("atlas_row", -1)) in [0, 1, 2], "%s uses a data-driven foundation atlas row" % champion_id)
		check("staff" not in String(recipe.get("equipment", "")).to_lower(), "%s has no staff casting focus" % champion_id)
		equal(String(recipe.get("silhouette_features", [])[-1]), "open_empty_hands", "%s has empty hands in the body recipe" % champion_id)
	equal(CartoonChampionPresenter.body_type_render_scale("small"), 1.0, "small body scale is baked once into its reusable atlas template")
	equal(CartoonChampionPresenter.body_type_render_scale("middle"), 1.0, "middle body scale is baked once into its reusable atlas template")
	equal(CartoonChampionPresenter.body_type_render_scale("large"), 1.0, "large body scale is baked once into its reusable atlas template")
	equal(CartoonChampionPresenter.body_type_render_scale("legacy"), 1.0, "unknown body types fail safe to the neutral render scale")
	equal(CartoonChampionPresenter.hand_cast_origin(Vector2.ZERO, Vector2.RIGHT), Vector2(4.0, -34.0), "casts originate from the authored forward hand lane")
	equal(CartoonChampionPresenter.hand_cast_origin(Vector2(10.0, 6.0), Vector2.ZERO), Vector2(17.0, -17.0), "zero aim uses a deterministic down-facing hand lane")
	for direction_id: String in EightDirectionResolver.DIRECTION_ORDER:
		var fixed := EightDirectionResolver.fixed_vector(direction_id)
		var continuous := Vector2(fixed.x, fixed.y).normalized()
		var expected_origin := Vector2(0.0, -27.0) + continuous * 4.0 + continuous.orthogonal() * 7.0
		check(CartoonChampionPresenter.hand_cast_origin(Vector2.ZERO, continuous).is_equal_approx(expected_origin), "hand origin preserves continuous aim through %s" % direction_id)
	var arbitrary_aim := Vector2(0.83, -0.41).normalized()
	var arbitrary_origin := Vector2(0.0, -27.0) + arbitrary_aim * 4.0 + arbitrary_aim.orthogonal() * 7.0
	check(CartoonChampionPresenter.hand_cast_origin(Vector2.ZERO, arbitrary_aim).is_equal_approx(arbitrary_origin), "hand origin does not quantize continuous cast geometry")
	check(not presenter.can_present("unreviewed"), "unreviewed champion fails closed")
	var state := PlayerState.new()
	state.facing_x = 0
	state.facing_y = 1000
	state.aim_x = 0
	state.aim_y = 1000
	equal(presenter.source_region("oh_tipi", state), Rect2(0, 0, 96, 96), "Oh Tipi south grounded selects the first cell")
	state.facing_x = -1000
	state.facing_y = 0
	state.aim_x = -1000
	state.aim_y = 0
	equal(presenter.source_region("oh_tipi", state), Rect2(576, 0, 96, 96), "Oh Tipi west grounded selects dedicated west art")
	state.pending_cast_wire_id = 1
	state.pending_cast_aim_x = -1000
	state.pending_cast_aim_y = 0
	equal(presenter.source_region("s_wayne", state), Rect2(576, 1152, 96, 96), "S. Wayne west cast selects dedicated cardinal action art")
	state.pending_cast_wire_id = 0
	state.facing_x = 1000
	state.facing_y = 0
	state.aim_x = 1000
	state.aim_y = 0
	equal(presenter.source_region("red_baron", state), Rect2(192, 1920, 96, 96), "The Red Baron east grounded selects the large foundation row")
	equal(String(presenter.recipe("red_baron").get("body_type", "")), "large", "The Red Baron is the first promoted large body")
	var atlas_image := presenter.atlas.get_image()
	var template_height_contract := {"oh_tipi": 68, "s_wayne": 58, "red_baron": 76}
	for champion_index: int in range(CartoonChampionPresenter.REQUIRED_FOUNDATION.size()):
		var champion_id: String = CartoonChampionPresenter.REQUIRED_FOUNDATION[champion_index]
		var standing_height: int = template_height_contract[champion_id]
		for state_index: int in range(CartoonChampionPresenter.EXPECTED_ATLAS_STATES.size()):
			for direction_index: int in range(CartoonChampionPresenter.EXPECTED_DIRECTIONS.size()):
				var region := Rect2i(direction_index * 96, (champion_index * 10 + state_index) * 96, 96, 96)
				var used := atlas_image.get_region(region).get_used_rect()
				var label := "%s %s/%s" % [champion_id, CartoonChampionPresenter.EXPECTED_ATLAS_STATES[state_index], CartoonChampionPresenter.EXPECTED_DIRECTIONS[direction_index]]
				check(used.size.x > 16 and used.position.x > 0 and used.end.x < 96, label + " stays inside its ink-safe cell")
				equal(used.end.y, 85, label + " keeps the shared feet baseline including exterior ink")
				if state_index in [1, 6, 7]:
					check(used.size.y >= standing_height / 2 and used.size.y <= standing_height + 2, label + " crouches without stretching to standing height")
				else:
					equal(used.size.y, standing_height + 2, label + " keeps the upright template height")
	var cardinal_cases := [
		{"facing": Vector2i(0, 1000), "state": "south", "column": 0},
		{"facing": Vector2i(1000, 0), "state": "east", "column": 2},
		{"facing": Vector2i(0, -1000), "state": "north", "column": 4},
		{"facing": Vector2i(-1000, 0), "state": "west", "column": 6},
	]
	for case: Dictionary in cardinal_cases:
		var directional_state := PlayerState.new()
		directional_state.facing_x = int((case["facing"] as Vector2i).x)
		directional_state.facing_y = int((case["facing"] as Vector2i).y)
		directional_state.aim_x = directional_state.facing_x
		directional_state.aim_y = directional_state.facing_y
		directional_state.slide_x = directional_state.facing_x
		directional_state.slide_y = directional_state.facing_y
		var expected_x := float(case["column"]) * 96.0
		equal(presenter.source_region("oh_tipi", directional_state), Rect2(expected_x, 0, 96, 96), "grounded %s animation selects dedicated cardinal art" % case["state"])
		directional_state.pending_cast_wire_id = 1
		directional_state.pending_cast_aim_x = directional_state.facing_x
		directional_state.pending_cast_aim_y = directional_state.facing_y
		equal(presenter.source_region("oh_tipi", directional_state), Rect2(expected_x, 192, 96, 96), "cast animation selects dedicated %s art" % case["state"])
		directional_state.pending_cast_wire_id = 0
		directional_state.movement_mode = PlayerState.MovementMode.HOP
		directional_state.hop_ticks = 2
		equal(presenter.source_region("oh_tipi", directional_state), Rect2(expected_x, 96, 96, 96), "jump animation selects dedicated %s art" % case["state"])
		directional_state.movement_mode = PlayerState.MovementMode.LAUNCHED
		directional_state.hop_ticks = 0
		equal(presenter.source_region("oh_tipi", directional_state), Rect2(expected_x, 288, 96, 96), "hit animation selects dedicated %s art" % case["state"])
		directional_state.control_state = PlayerState.ControlState.FREE
		var movement_cases := [
			{"mode": PlayerState.MovementMode.WALK, "state": "walk", "row": 4},
			{"mode": PlayerState.MovementMode.SPRINT, "state": "sprint", "row": 5},
			{"mode": PlayerState.MovementMode.SLIDE, "state": "slide", "row": 6},
			{"mode": PlayerState.MovementMode.ROLL, "state": "roll", "row": 7},
		]
		for movement_case: Dictionary in movement_cases:
			directional_state.movement_mode = int(movement_case["mode"])
			equal(presenter.source_region("oh_tipi", directional_state), Rect2(expected_x, float(movement_case["row"]) * 96.0, 96, 96), "%s animation selects dedicated %s art" % [movement_case["state"], case["state"]])
	var diagonal_cases := [
		{"facing": Vector2i(707, 707), "state": "south_east", "column": 1},
		{"facing": Vector2i(707, -707), "state": "north_east", "column": 3},
		{"facing": Vector2i(-707, -707), "state": "north_west", "column": 5},
		{"facing": Vector2i(-707, 707), "state": "south_west", "column": 7},
	]
	for case: Dictionary in diagonal_cases:
		var diagonal_state := PlayerState.new()
		diagonal_state.facing_x = int((case["facing"] as Vector2i).x)
		diagonal_state.facing_y = int((case["facing"] as Vector2i).y)
		diagonal_state.aim_x = diagonal_state.facing_x
		diagonal_state.aim_y = diagonal_state.facing_y
		diagonal_state.slide_x = diagonal_state.facing_x
		diagonal_state.slide_y = diagonal_state.facing_y
		var expected_x := float(case["column"]) * 96.0
		equal(presenter.source_region("oh_tipi", diagonal_state), Rect2(expected_x, 0, 96, 96), "grounded %s selects promoted diagonal art" % case["state"])
		diagonal_state.pending_cast_wire_id = 1
		diagonal_state.pending_cast_aim_x = diagonal_state.facing_x
		diagonal_state.pending_cast_aim_y = diagonal_state.facing_y
		equal(presenter.source_region("oh_tipi", diagonal_state), Rect2(expected_x, 192, 96, 96), "cast %s selects promoted diagonal art" % case["state"])
		diagonal_state.pending_cast_wire_id = 0
		diagonal_state.movement_mode = PlayerState.MovementMode.LAUNCHED
		equal(presenter.source_region("oh_tipi", diagonal_state), Rect2(expected_x, 288, 96, 96), "hit %s selects promoted diagonal art" % case["state"])
		diagonal_state.movement_mode = PlayerState.MovementMode.WALK
		diagonal_state.velocity_x = int((case["facing"] as Vector2i).x)
		diagonal_state.velocity_y = int((case["facing"] as Vector2i).y)
		equal(presenter.source_region("oh_tipi", diagonal_state), Rect2(expected_x, 384, 96, 96), "walk %s selects promoted diagonal art" % case["state"])
		diagonal_state.movement_mode = PlayerState.MovementMode.SPRINT
		equal(presenter.source_region("oh_tipi", diagonal_state), Rect2(expected_x, 480, 96, 96), "sprint %s selects promoted diagonal art" % case["state"])
		diagonal_state.movement_mode = PlayerState.MovementMode.HOP
		diagonal_state.hop_ticks = 2
		equal(presenter.source_region("oh_tipi", diagonal_state), Rect2(expected_x, 96, 96, 96), "jump %s selects native diagonal art" % case["state"])
		diagonal_state.hop_ticks = 0
		diagonal_state.movement_mode = PlayerState.MovementMode.SLIDE
		equal(presenter.source_region("oh_tipi", diagonal_state), Rect2(expected_x, 576, 96, 96), "slide %s selects native diagonal art" % case["state"])
		diagonal_state.movement_mode = PlayerState.MovementMode.ROLL
		equal(presenter.source_region("oh_tipi", diagonal_state), Rect2(expected_x, 672, 96, 96), "roll %s selects native diagonal art" % case["state"])
	check(presenter.source_region("unreviewed", state).has_area() == false, "unreviewed champion has no source region")


func _test_semantic_states() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "visual language loads for semantic states")
	var presenter := CartoonChampionPresenter.new()
	check(presenter.configure(language, CartoonChampionPresenter.DEFAULT_PATH, CartoonChampionPresenter.DEFAULT_OVERRIDE_PATH, false), "foundation cartoon recipes load for semantic states")
	var state := PlayerState.new()
	equal(CartoonChampionPresenter.semantic_action(state), "idle", "idle resolves to a stable semantic action")
	equal(presenter.silhouette_state(state), "grounded", "idle state uses its declared grounded alias")
	state.movement_mode = PlayerState.MovementMode.HOP
	state.hop_ticks = 2
	equal(CartoonChampionPresenter.semantic_action(state), "jump", "hop resolves to a stable semantic action")
	equal(presenter.silhouette_state(state), "jump", "airborne state uses its declared jump alias")
	state.movement_mode = PlayerState.MovementMode.IDLE
	state.hop_ticks = 0
	state.hop_mode = PlayerState.MovementMode.ROLL
	state.air_dodge_ticks = 2
	state.movement_mode = PlayerState.MovementMode.ROLL
	equal(CartoonChampionPresenter.semantic_action(state), "roll", "roll retains a distinct semantic action")
	equal(presenter.silhouette_state(state), "roll", "roll uses the dedicated compact silhouette")
	state.air_dodge_ticks = 0
	state.movement_mode = PlayerState.MovementMode.IDLE
	state.pending_cast_wire_id = 1
	equal(CartoonChampionPresenter.semantic_action(state), "cast", "pending cast resolves to cast")
	equal(presenter.silhouette_state(state), "cast", "pending cast uses cast silhouette")
	state.pending_cast_wire_id = 0
	state.control_state = PlayerState.ControlState.STUNNED
	equal(CartoonChampionPresenter.semantic_action(state), "stunned", "stun retains its semantic identity")
	equal(presenter.silhouette_state(state), "hit", "stun explicitly aliases to the hit silhouette")
	state.control_state = PlayerState.ControlState.FREE
	state.movement_mode = PlayerState.MovementMode.WALK
	equal(presenter.silhouette_state(state), "walk", "walk uses the planted contact silhouette")
	state.movement_mode = PlayerState.MovementMode.SPRINT
	equal(presenter.silhouette_state(state), "sprint", "sprint uses the directional drive silhouette")
	state.movement_mode = PlayerState.MovementMode.SLIDE
	equal(presenter.silhouette_state(state), "slide", "slide uses the dedicated low silhouette")
	state.movement_mode = PlayerState.MovementMode.WAVE_DASH
	equal(CartoonChampionPresenter.semantic_action(state), "wave_dash", "wave dash retains its semantic identity")
	equal(presenter.silhouette_state(state), "slide", "wave dash explicitly aliases to the direction-complete low body row")
	var semantic_by_mode := {
		PlayerState.MovementMode.IDLE: "idle",
		PlayerState.MovementMode.WALK: "walk",
		PlayerState.MovementMode.SPRINT: "sprint",
		PlayerState.MovementMode.HOP: "jump",
		PlayerState.MovementMode.DOUBLE_JUMP: "double_jump",
		PlayerState.MovementMode.SLIDE: "slide",
		PlayerState.MovementMode.SLIDE_JUMP: "slide_jump",
		PlayerState.MovementMode.AIR_DODGE: "air_dodge",
		PlayerState.MovementMode.WAVE_DASH: "wave_dash",
		PlayerState.MovementMode.WALL_KICK: "wall_kick",
		PlayerState.MovementMode.VAULT: "vault",
		PlayerState.MovementMode.SUPERGLIDE: "superglide",
		PlayerState.MovementMode.LAUNCHED: "launched",
		PlayerState.MovementMode.GRAPPLED: "grappled",
		PlayerState.MovementMode.CHARGING: "charging",
		PlayerState.MovementMode.STUNNED: "stunned",
		PlayerState.MovementMode.ROOTED: "rooted",
		PlayerState.MovementMode.SLOWED: "slowed",
		PlayerState.MovementMode.FAST_FALL: "fast_fall",
		PlayerState.MovementMode.WALL_SKIM: "wall_skim",
		PlayerState.MovementMode.IMPACT_RECOVERY: "impact_recovery",
		PlayerState.MovementMode.ROLL: "roll",
	}
	for movement_mode: int in semantic_by_mode:
		var mode_state := PlayerState.new()
		mode_state.movement_mode = movement_mode
		equal(CartoonChampionPresenter.semantic_action(mode_state), semantic_by_mode[movement_mode], "%s resolves through the semantic visual contract" % PlayerState.MovementMode.keys()[movement_mode])
		check(presenter.silhouette_state(mode_state) in CartoonChampionPresenter.EXPECTED_CARDINAL_STATES, "%s aliases to a promoted atlas state" % PlayerState.MovementMode.keys()[movement_mode])
	state = PlayerState.new()
	state.cast_recovery_ticks = 2
	equal(CartoonChampionPresenter.semantic_action(state), "cast_recovery", "cast recovery retains a stable semantic action")
	equal(presenter.silhouette_state(state), "cast", "cast recovery explicitly holds the readable cast silhouette")
	state.aim_x = -707
	state.aim_y = -707
	equal(presenter.source_region("oh_tipi", state), Rect2(480, 192, 96, 96), "cast recovery retains nearest-eight north-west presentation")
	state.health = 0
	equal(CartoonChampionPresenter.semantic_action(state), "defeated", "defeat overrides every non-terminal action")
	equal(presenter.silhouette_state(state), "hit", "defeat explicitly aliases to the current recovery silhouette")
	for presentation_action: String in ["attack_primary", "defend", "interact", "taunt"]:
		check(presenter.atlas_state_for_action(presentation_action) in CartoonChampionPresenter.EXPECTED_CARDINAL_STATES, "%s has an explicit reusable alias before it gains an authoritative local state" % presentation_action)
	equal(presenter.atlas_state_for_action("unowned_action"), "", "unknown presentation actions fail closed instead of guessing a pose")
	equal(CartoonChampionPresenter.cardinal_direction(1000, 10), "east", "horizontal facing stays horizontal")
	equal(CartoonChampionPresenter.cardinal_direction(-1000, 10), "west", "negative horizontal facing stays horizontal")
	equal(CartoonChampionPresenter.cardinal_direction(0, -1000), "north", "negative vertical facing reads north")
	equal(CartoonChampionPresenter.cardinal_direction(0, 1000), "south", "positive vertical facing reads south")
	equal(CartoonChampionPresenter.direction_for_state("grounded", 707, -707), "north_east", "promoted grounded state resolves north-east")
	equal(CartoonChampionPresenter.direction_for_state("cast", -707, 707), "south_west", "promoted cast resolves south-west")
	equal(CartoonChampionPresenter.direction_for_state("walk", 707, -707), "north_east", "promoted walk resolves north-east")
	equal(CartoonChampionPresenter.direction_for_state("jump", 707, -707), "north_east", "jump resolves native north-east art")
	state.movement_mode = PlayerState.MovementMode.WALK
	state.movement_speed_ratio = 1000
	state.velocity_x = MovementTuning.BASE_SPEED / 10
	var starting_response := CartoonChampionPresenter.movement_response_scale(state)
	check(starting_response > 0.0 and starting_response < 0.1, "early acceleration uses a restrained body response")
	state.velocity_x = MovementTuning.BASE_SPEED
	equal(CartoonChampionPresenter.movement_response_scale(state), 1.0, "full ordinary speed reaches the complete walk response")


func _test_semantic_aliases_fail_closed() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "visual language loads for adversarial alias tests")
	var valid := CartoonChampionPresenter.new()
	check(valid.configure(language, CartoonChampionPresenter.DEFAULT_PATH, CartoonChampionPresenter.DEFAULT_OVERRIDE_PATH, false), "valid semantic aliases load before adversarial mutations")
	var mutations: Array[Dictionary] = []
	var missing: Dictionary = valid.semantic_state_aliases.duplicate(true)
	missing.erase("roll")
	mutations.append(missing)
	var extra: Dictionary = valid.semantic_state_aliases.duplicate(true)
	extra["unowned_action"] = "grounded"
	mutations.append(extra)
	var bad_target: Dictionary = valid.semantic_state_aliases.duplicate(true)
	bad_target["rooted"] = "missing_row"
	mutations.append(bad_target)
	for mutation: Dictionary in mutations:
		var presenter := CartoonChampionPresenter.new()
		check(not presenter._validate_semantic_state_aliases(mutation), "incomplete or unsafe semantic aliases fail closed")
		check(not presenter.last_error.is_empty(), "semantic alias failure is actionable")
		equal(presenter.semantic_state_aliases, {}, "failed alias validation exposes no stale mapping")


func _test_diagonal_contract_fails_closed() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "visual language loads for diagonal contract tests")
	var presenter := CartoonChampionPresenter.new()
	check(presenter.configure(language, CartoonChampionPresenter.DEFAULT_PATH, CartoonChampionPresenter.DEFAULT_OVERRIDE_PATH, false), "valid diagonal contract loads before mutation")
	var contract := presenter.diagonal_core_contract.duplicate(true)
	contract["states"] = ["grounded", "cast"]
	check(not presenter._validate_diagonal_core_contract(contract), "missing diagonal core state fails closed")
	check(not presenter.last_error.is_empty(), "diagonal contract failure is actionable")
	equal(presenter.diagonal_core_contract, {}, "failed diagonal validation exposes no stale contract")
	check(presenter.configure(language, CartoonChampionPresenter.DEFAULT_PATH, CartoonChampionPresenter.DEFAULT_OVERRIDE_PATH, false), "valid diagonal contracts reload before locomotion mutation")
	var locomotion_contract := presenter.diagonal_locomotion_contract.duplicate(true)
	locomotion_contract["gaits"] = ["forward", "backward"]
	check(not presenter._validate_diagonal_locomotion_contract(locomotion_contract), "incomplete gait catalog fails closed")
	equal(presenter.diagonal_locomotion_contract, {}, "failed locomotion validation exposes no stale contract")
	check(presenter.configure(language, CartoonChampionPresenter.DEFAULT_PATH, CartoonChampionPresenter.DEFAULT_OVERRIDE_PATH, false), "valid diagonal contracts reload before evasion mutation")
	var evasion_contract := presenter.diagonal_evasion_contract.duplicate(true)
	evasion_contract["states"] = ["jump", "roll"]
	check(not presenter._validate_diagonal_evasion_contract(evasion_contract), "missing diagonal evasion state fails closed")
	equal(presenter.diagonal_evasion_contract, {}, "failed evasion validation exposes no stale contract")
	check(presenter.configure(language, CartoonChampionPresenter.DEFAULT_PATH, CartoonChampionPresenter.DEFAULT_OVERRIDE_PATH, false), "valid contracts reload before locomotion phase mutation")
	var phase_contract := presenter.locomotion_phase_contract.duplicate(true)
	phase_contract["frame_states"] = {"walk": ["walk", "walk_b"], "sprint": ["sprint"]}
	check(not presenter._validate_locomotion_phase_contract(phase_contract), "missing alternate sprint contact fails closed")
	equal(presenter.locomotion_phase_contract, {}, "failed locomotion phase validation exposes no stale contract")


func _test_diagonal_evasion_contract_and_direction() -> void:
	var state := PlayerState.new()
	var directions := [
		{"vector": Vector2i(0, 1000), "id": "south"},
		{"vector": Vector2i(707, 707), "id": "south_east"},
		{"vector": Vector2i(1000, 0), "id": "east"},
		{"vector": Vector2i(707, -707), "id": "north_east"},
		{"vector": Vector2i(0, -1000), "id": "north"},
		{"vector": Vector2i(-707, -707), "id": "north_west"},
		{"vector": Vector2i(-1000, 0), "id": "west"},
		{"vector": Vector2i(-707, 707), "id": "south_west"},
	]
	for direction: Dictionary in directions:
		state.velocity_x = int((direction["vector"] as Vector2i).x)
		state.velocity_y = int((direction["vector"] as Vector2i).y)
		equal(CartoonChampionPresenter.evasion_direction(state), direction["id"], "evasion cue follows every eight-direction travel vector")
	state.velocity_x = 0
	state.velocity_y = 0
	state.facing_x = -707
	state.facing_y = 707
	equal(CartoonChampionPresenter.evasion_direction(state), "south_west", "stationary evasion cue follows authored facing")
	state.facing_x = 0
	state.facing_y = 0
	equal(CartoonChampionPresenter.evasion_direction(state), "south", "zero-vector evasion cue fails safe to south")


func _test_relative_locomotion_gaits() -> void:
	var state := PlayerState.new()
	state.movement_mode = PlayerState.MovementMode.WALK
	state.velocity_x = 707
	state.velocity_y = 707
	state.facing_x = 707
	state.facing_y = 707
	state.aim_x = 707
	state.aim_y = 707
	equal(CartoonChampionPresenter.presentation_facing_vector(state, "walk"), Vector2i(707, 707), "coincident cursor and travel face forward")
	equal(CartoonChampionPresenter.locomotion_gait(state), "forward", "free locomotion uses forward gait")
	state.primary_held = true
	state.aim_x = -707
	state.aim_y = -707
	equal(CartoonChampionPresenter.presentation_facing_vector(state, "walk"), Vector2i(-707, -707), "movement art follows opposed cursor")
	equal(CartoonChampionPresenter.locomotion_gait(state), "backward", "opposed cursor selects backward cadence")
	state.aim_x = -707
	state.aim_y = 707
	equal(CartoonChampionPresenter.locomotion_gait(state), "strafe_left", "quarter-turn cursor selects left strafe")
	state.aim_x = 707
	state.aim_y = -707
	equal(CartoonChampionPresenter.locomotion_gait(state), "strafe_right", "opposite quarter-turn cursor selects right strafe")
	var backward_sample := MinimalChampionMotion.Sample.new()
	backward_sample.offset = Vector2(2.0, -2.0)
	backward_sample.scale = Vector2(1.04, 0.96)
	backward_sample.aura_scale = 1.08
	CartoonChampionPresenter._apply_relative_gait_motion(backward_sample, "backward", false)
	equal(backward_sample.offset, Vector2(-2.0, -1.44), "backward cadence reverses lateral phase and restrains bounce")
	equal(backward_sample.scale, Vector2(1.04, 0.96), "relative gait never rescales the body template")
	var left_sample := MinimalChampionMotion.Sample.new()
	var right_sample := MinimalChampionMotion.Sample.new()
	CartoonChampionPresenter._apply_relative_gait_motion(left_sample, "strafe_left", false)
	CartoonChampionPresenter._apply_relative_gait_motion(right_sample, "strafe_right", false)
	equal(left_sample.offset.x, -right_sample.offset.x, "strafe cadence mirrors its lateral weight shift")


func _test_locomotion_contact_regions() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "visual language loads for contact-frame regions")
	var presenter := CartoonChampionPresenter.new()
	check(presenter.configure(language, CartoonChampionPresenter.DEFAULT_PATH, CartoonChampionPresenter.DEFAULT_OVERRIDE_PATH, false), "foundation recipes load for contact-frame regions")
	var state := PlayerState.new()
	state.movement_mode = PlayerState.MovementMode.WALK
	state.velocity_x = 707
	state.velocity_y = -707
	state.facing_x = 707
	state.facing_y = -707
	state.aim_x = 707
	state.aim_y = -707
	equal(presenter.source_region_for_animation_state("oh_tipi", state, "walk"), Rect2(288, 384, 96, 96), "walk contact A owns north-east art")
	equal(presenter.source_region_for_animation_state("oh_tipi", state, "walk_b"), Rect2(288, 768, 96, 96), "walk contact B owns north-east art")
	state.movement_mode = PlayerState.MovementMode.SPRINT
	equal(presenter.source_region_for_animation_state("s_wayne", state, "sprint"), Rect2(288, 1440, 96, 96), "S. Wayne sprint contact A owns north-east art")
	equal(presenter.source_region_for_animation_state("s_wayne", state, "sprint_b"), Rect2(288, 1824, 96, 96), "S. Wayne sprint contact B owns north-east art")


func _test_movement_template_direction_matrix() -> void:
	var language := VisualLanguage.new()
	check(language.load_from_file(), "movement matrix language loads")
	var presenter := CartoonChampionPresenter.new()
	check(presenter.configure(language, CartoonChampionPresenter.DEFAULT_PATH, CartoonChampionPresenter.DEFAULT_OVERRIDE_PATH, false), "movement matrix uses the live champion presenter")
	var config := SimConfig.new(120)
	var actions := {"idle": PlayerState.MovementMode.IDLE, "walk": PlayerState.MovementMode.WALK, "sprint": PlayerState.MovementMode.SPRINT, "jump": PlayerState.MovementMode.HOP, "float": PlayerState.MovementMode.DOUBLE_JUMP, "slide": PlayerState.MovementMode.SLIDE, "roll": PlayerState.MovementMode.ROLL, "air_turn": PlayerState.MovementMode.HOP, "wallrun": PlayerState.MovementMode.WALL_SKIM, "landing": PlayerState.MovementMode.IDLE}
	equal(presenter.champions.size(), 30, "movement matrix retains all thirty catalog identities")
	for champion_id: String in presenter.champions:
		var profile_id := String(presenter.recipe(champion_id)["motion_profile"])
		for direction_index: int in range(8):
			var direction: Vector2i = EightDirectionResolver.FIXED_VECTORS[direction_index]
			for action: String in actions:
				var state := PlayerState.new(1)
				state.movement_mode = int(actions[action])
				state.facing_x = direction.x
				state.facing_y = direction.y
				state.velocity_x = direction.x * 300
				state.velocity_y = direction.y * 300
				state.aim_x = -direction.x
				state.aim_y = -direction.y
				if action in ["idle", "landing"]:
					state.velocity_x = 0
					state.velocity_y = 0
				if action in ["jump", "air_turn", "float"]:
					state.air_height = 45_000
					state.hop_ticks = 12
					state.hop_mode = PlayerState.MovementMode.HOP
					if action == "float":
						state.air_floating = true
						state.float_used = true
						state.float_ticks = 120
						state.hop_mode = PlayerState.MovementMode.DOUBLE_JUMP
				if action == "roll":
					state.air_dodge_ticks = 12
					state.hop_mode = PlayerState.MovementMode.ROLL
				if action == "wallrun":
					state.air_height = 45_000
					state.wall_skim_ticks = 18
					state.wall_skim_surface_id = 7
				if action == "landing":
					state.landing_ticks = 6
					state.landing_intensity = 800
				var before := state.canonical_values()
				for reduced: bool in [false, true]:
					var frame := presenter.movement_frame(champion_id, state, 19.0, config, reduced)
					var region: Rect2 = frame["source_region"]
					var facing_index := direction_index if action == "slide" else (direction_index + 4) % 8
					equal(region.position.x, float(facing_index * 96), "%s/%s uses travel-aligned slide and independent aim %d" % [champion_id, action, direction_index])
					equal(region.size, CartoonChampionPresenter.CELL_SIZE, "%s/%s uses the same source-cell dimensions" % [champion_id, action])
					equal(frame["scale"], Vector2.ONE, "%s/%s never rescales its template" % [champion_id, action])
					if action in ["walk", "sprint", "wallrun"]:
						check((frame["offset"] as Vector2).length() <= 1.5, "%s/%s uses only a bounded micro-pivot" % [champion_id, action])
					else:
						equal(frame["offset"], Vector2.ZERO, "%s/%s keeps its feet pivot pinned" % [champion_id, action])
					check(presenter.texture_for_champion(champion_id).get_image().get_region(Rect2i(region)).get_used_rect().has_area(), "%s/%s resolves actual body pixels" % [champion_id, action])
				if action in ["walk", "sprint", "wallrun"]:
					var gait := "sprint" if action == "wallrun" else action
					var duration := float((presenter.motion.profiles[profile_id][gait] as Dictionary)["duration_ticks"])
					var first := presenter.movement_frame(champion_id, state, duration - 3.0, config)
					var second := presenter.movement_frame(champion_id, state, duration * 1.5 - 3.0, config)
					equal(int(first["contact_frame"]), 0, "all templates/directions visibly plant contact A")
					equal(int(second["contact_frame"]), 1, "all templates/directions visibly plant opposite contact B")
					check(first["source_region"] != second["source_region"], "opposite contacts use distinct atlas cells")
				equal(state.canonical_values(), before, "full movement rendering contract is read-only")
	check(presenter.movement_frame("unknown", PlayerState.new(), 0, config).is_empty(), "unpromoted movement art fails closed")


func _test_wall_contact_side() -> void:
	for normal: Vector2i in [Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN]:
		var state := PlayerState.new()
		state.wall_skim_ticks = 12
		state.wall_skim_surface_id = 7
		state.wall_x = normal.x * 1000
		state.wall_y = normal.y * 1000
		var geometry := CartoonChampionPresenter.wall_contact_geometry(state)
		var offset: Vector2 = geometry["offset"]
		check(offset.dot(Vector2(normal)) < 0.0, "wall sparks originate toward the wall, not away from it")
		equal(offset.length(), float(state.radius) / SimConfig.FIXED_SCALE, "wall contact uses the real body radius")
	check(CartoonChampionPresenter.wall_contact_geometry(PlayerState.new()).is_empty(), "no wall contact cannot fabricate sparks")


func _test_immediate_protection_contract() -> void:
	var config := SimConfig.new(120)
	for height: float in [58.0, 68.0, 76.0]:
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			for reduced: bool in [false, true]:
				var state := PlayerState.new()
				state.hop_ticks = 20
				state.facing_x = direction.x
				state.facing_y = direction.y
				for rolling: bool in [false, true]:
					state.hop_mode = PlayerState.MovementMode.ROLL if rolling else PlayerState.MovementMode.AIR_DODGE
					var duration_ms := MovementTuning.ROLL_DURATION_MS if rolling else MovementTuning.AIR_DODGE_DURATION_MS
					var protection_ms := MovementTuning.ROLL_INVULNERABILITY_MS if rolling else MovementTuning.AIR_DODGE_INVULNERABILITY_MS
					state.air_dodge_ticks = config.milliseconds_to_ticks(duration_ms) - config.milliseconds_to_ticks(protection_ms) + 1
					var protected := CartoonChampionPresenter.protection_contract(state, config, reduced, height)
					check(bool(protected["active"]), "even the last roll/air-dodge protected tick is unmistakably marked")
					equal(protected.get("body_tint"), Color(1, 1, 1, 0.62), "last protected tick changes the actual body without changing native RGB identity")
					equal(int(protected.get("budget_pips", -1)), 1, "last protected tick keeps one visible avoidance-budget pip")
					equal((protected["brackets"] as Array).size(), 4, "four quiet corners are colour-independent status")
					equal(protected["kind"], "intangible", "roll and air-dodge use their actual timed damage-avoidance kind")
					equal((protected["shield"] as PackedVector2Array).size(), 0, "dodge avoidance never borrows the spawn shield")
					equal((protected["badge_lines"] as Array).size(), 2, "two stable slashes distinguish timed avoidance in normal and reduced effects")
					state.air_dodge_ticks -= 1
					var expired := CartoonChampionPresenter.protection_contract(state, config, reduced, height)
					check(not bool(expired["active"]), "protection disappears on the exact authoritative off tick")
					equal(expired.get("body_tint"), Color.WHITE, "first vulnerable recovery tick restores the opaque body immediately")
					equal(int(expired.get("budget_pips", -1)), 0, "no avoidance-budget pip survives into vulnerable recovery")
					check((expired["brackets"] as Array).is_empty() and (expired["shield"] as PackedVector2Array).is_empty(), "no shield geometry remains to suggest protection")
				state.air_dodge_ticks = 0
				state.jump_protection_ticks = 1
				check(not bool(CartoonChampionPresenter.protection_contract(state, config, reduced, height)["active"]), "legacy jump timer cannot create a universal shield")
				state.air_height = 55_000
				state.air_floating = true
				state.flight_capable = true
				state.float_used = true
				state.float_ticks = 120
				var floating := CartoonChampionPresenter.protection_contract(state, config, reduced, height)
				check(not bool(floating["active"]), "flight itself never creates a protection shield in any size or effect profile")
				equal(floating["remaining_ratio"], 0.0, "held flight has no universal protection budget")
				state.air_floating = false
				var released := CartoonChampionPresenter.protection_contract(state, config, reduced, height)
				check(not bool(released["active"]) and not released.has("float_wings"), "flight release cannot leave obsolete shield wings")
				state.air_floating = true
				state.stamina = 0
				check(not bool(CartoonChampionPresenter.protection_contract(state, config, reduced, height)["active"]), "exhausted Float cannot fabricate protection even with a stale flag")
				state.stamina = state.stamina_maximum
				state.float_ticks = 0
				var timed_out := CartoonChampionPresenter.protection_contract(state, config, reduced, height)
				check(not bool(timed_out["active"]) and not timed_out.has("float_wings"), "expired flight cannot retain a shield even with Stamina and a stale active flag")
				state.air_floating = false
				state.spawn_protection_ticks = 1
				var spawn := CartoonChampionPresenter.protection_contract(state, config, reduced, height)
				check(bool(spawn["active"]), "spawn safety cannot look vulnerable")
				equal(spawn["kind"], "invulnerable", "spawn damage guard owns the closed shield kind")
				equal((spawn["shield"] as PackedVector2Array).size(), 6, "spawn shield remains visibly closed")
				check((spawn["badge_lines"] as Array).is_empty(), "spawn does not advertise the dodge-only slash")
	check(not bool(CartoonChampionPresenter.protection_contract(null, config)["active"]), "missing protection state fails closed")


func _test_float_time_budget() -> void:
	var config := SimConfig.new(120)
	for body: Vector2i in [Vector2i(58, MovementTuning.FLOAT_SMALL_DURATION_MS), Vector2i(68, MovementTuning.FLOAT_MIDDLE_DURATION_MS), Vector2i(76, MovementTuning.FLOAT_LARGE_DURATION_MS)]:
		for direction: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			var state := PlayerState.new()
			state.air_height = 20000
			state.air_floating = true
			state.flight_capable = true
			state.float_used = true
			state.float_max_duration_ms = body.y
			state.facing_x = direction.x
			state.facing_y = direction.y
			var total := config.milliseconds_to_ticks(body.y)
			for remaining: int in [total, total / 2, 1, 0]:
				state.float_ticks = remaining
				var canonical := state.canonical_values()
				var normal := CartoonChampionPresenter.protection_contract(state, config, false, body.x)
				var reduced := CartoonChampionPresenter.protection_contract(state, config, true, body.x)
				equal(normal, reduced, "true protection information is identical in reduced effects")
				check(not normal.active, "flight budget never creates a protection shield")
				var cue := JumpPresentation.height_contract(state, config)
				equal(cue["budget"], float(remaining) / total, "flight meter reports exact authoritative remaining time for every body")
				equal(cue["flight"], remaining > 0, "only positive remaining flight time shows the flight meter")
				check(cue["active"] and cue["above"], "height clearance stays independent of flight timeout")
				check(not normal.has("float_wings") and not normal.has("float_budget_slots") and not normal.has("float_budget_fills") and not normal.has("float_budget_ratio"), "true shield contract contains no legacy Float embellishment")
				if remaining > 0:
					var fill_width := ceilf(18.0 * float(cue["budget"]))
					check(fill_width >= 1.0 and fill_width <= 18.0, "live height meter retains a visible pixel inside its fixed width")
					if remaining == total:
						equal(fill_width, 18.0, "full flight time fills the complete height meter")
					elif remaining == 1:
						equal(fill_width, 1.0, "final tick remains one crisp pixel without flashing")
				else:
					check(not cue["flight"] and float(cue["budget"]) == 0.0, "timeout removes flight time on the exact query")
				equal(state.canonical_values(), canonical, "budget sampling cannot consume Stamina/time or change direction")
			state.spawn_protection_ticks = 1
			state.float_ticks = total
			var spawn_shield := CartoonChampionPresenter.protection_contract(state, config, false, body.x)
			for exit_kind: String in ["active", "release", "exhaustion", "timeout", "incapable"]:
				state.air_floating = exit_kind != "release"
				state.flight_capable = exit_kind != "incapable"
				state.stamina = 0 if exit_kind == "exhaustion" else state.stamina_maximum
				state.float_ticks = 0 if exit_kind == "timeout" else total
				var canonical := state.canonical_values()
				var ended := CartoonChampionPresenter.protection_contract(state, config, false, body.x)
				check(ended.active, "independent spawn protection remains visible during and after flight")
				equal(ended, spawn_shield, "flight state cannot embellish or alter independent spawn protection")
				equal(ended, CartoonChampionPresenter.protection_contract(state, config, true, body.x), "overlapping flight and spawn protection are identical in reduced effects")
				check(not ended.has("float_budget_slots") and not ended.has("float_wings"), "overlapping spawn protection never acquires legacy Float decoration")
				var cue := JumpPresentation.height_contract(state, config)
				equal(cue["flight"], exit_kind == "active", "release, exhaustion, timeout and incapable flags remove only the flight meter")
				equal(cue["budget"], 1.0 if exit_kind == "active" else 0.0, "inactive flight cannot retain a nonzero meter")
				check(cue["active"] and cue["above"], "height cue remains when flight ends despite overlapping spawn protection")
				equal(state.canonical_values(), canonical, "overlapping visual queries cannot mutate authority")


func _test_directional_movement_trails() -> void:
	var config := SimConfig.new(120)
	for fixed: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		for reduced: bool in [false, true]:
			for airborne: bool in [false, true]:
				var state := PlayerState.new()
				state.velocity_x = fixed.x * 600
				state.velocity_y = fixed.y * 600
				state.facing_x = -fixed.x
				state.facing_y = -fixed.y
				state.air_height = 55_000 if airborne else 0
				state.air_dodge_ticks = config.milliseconds_to_ticks(MovementTuning.AIR_DODGE_DURATION_MS) if airborne else 0
				state.slide_ticks = 0 if airborne else 15
				var before := state.canonical_values()
				var trail := CartoonChampionPresenter.movement_trail_contract(state, config, reduced)
				check(bool(trail["active"]), "moving dodge and slide have a bounded directional flourish")
				equal(bool(trail["body_anchored"]), airborne, "only dodge streaks follow the lifted body")
				equal((trail["lines"] as Array).size(), 4 if airborne and not reduced else 2, "trail count is strictly bounded")
				var direction := Vector2(fixed).normalized()
				for line: PackedVector2Array in trail["lines"]:
					for point: Vector2 in line:
						check(point.dot(direction) < 0.0, "trails follow actual travel behind the body even with reversed facing")
						check(point.length() <= 52.0, "trails cannot reach an adjacent combat lane")
					equal(line.size(), 2, "speed lines do not duplicate or blur sprite silhouettes")
				equal(state.canonical_values(), before, "trail sampling never moves an actor")
				state.air_dodge_ticks = 0
				state.slide_ticks = 0
				check(not bool(CartoonChampionPresenter.movement_trail_contract(state, config, reduced)["active"]), "trails stop immediately with their action")


func _test_protection_body_and_budget_boundaries() -> void:
	var config := SimConfig.new(120)
	# Independent120Hz witnesses: air dodge22/15 ticks, roll29/16 ticks.
	# Quantized3/2/1 pips describe the protected opening, not the whole action.
	# These literals intentionally fail if runtime tuning changes without a
	# corresponding review of the displayed protection budget.
	for rolling: bool in [false, true]:
		var witnesses: Array[Vector2i] = [Vector2i(22,3), Vector2i(18,3), Vector2i(17,2), Vector2i(13,2), Vector2i(12,1), Vector2i(8,1), Vector2i(7,0), Vector2i(1,0), Vector2i(0,0)]
		if rolling: witnesses.assign([Vector2i(29,3), Vector2i(24,3), Vector2i(23,2), Vector2i(19,2), Vector2i(18,1), Vector2i(14,1), Vector2i(13,0), Vector2i(1,0), Vector2i(0,0)])
		for height: float in [38.0, 44.0, 50.0, 58.0, 68.0, 76.0]:
			var state := PlayerState.new()
			state.hop_mode = PlayerState.MovementMode.ROLL if rolling else PlayerState.MovementMode.AIR_DODGE
			state.air_height = 0 if rolling else 20_000
			for witness: Vector2i in witnesses:
				state.air_dodge_ticks = witness.x
				var before := state.canonical_values()
				var ordinary := CartoonChampionPresenter.protection_contract(state, config, false, height)
				var reduced := CartoonChampionPresenter.protection_contract(state, config, true, height)
				equal(ordinary, reduced, "reduced effects retain exact body treatment, budget and expiry information")
				equal(int(ordinary.get("budget_pips", -1)), witness.y, "independent opening-budget boundary gives exact discrete pip count")
				equal(bool(ordinary.active), witness.y > 0, "pips cannot contradict the actual protected interval")
				equal(ordinary.get("body_tint"), Color(1,1,1,0.62) if witness.y > 0 else Color.WHITE, "body returns opaque while vulnerable dodge animation can still be running")
				equal(state.canonical_values(), before, "repeated protection samples never spend or extend authoritative timers")
			# Overlapping spawn protection is an opaque shield, not partial
			# dodge transparency or a guessed normalized spawn countdown.
			state.air_dodge_ticks = 14 if rolling else 8
			state.spawn_protection_ticks = 1
			var overlap := CartoonChampionPresenter.protection_contract(state, config, false, height)
			equal(overlap.kind, "invulnerable", "last spawn tick takes precedence over a simultaneous protected dodge")
			equal(overlap.get("body_tint"), Color.WHITE, "spawn shield keeps the original opaque body")
			equal(int(overlap.get("budget_pips", -1)), 0, "spawn never borrows the shorter dodge-budget meter")
			equal(overlap, CartoonChampionPresenter.protection_contract(state, config, true, height), "overlap has identical meaning under reduced effects")
			state.spawn_protection_ticks = 0
			var remaining_dodge := CartoonChampionPresenter.protection_contract(state, config, false, height)
			equal(remaining_dodge.kind, "intangible", "spawn expiry reveals only the independently remaining dodge opening")
			equal(remaining_dodge.get("body_tint"), Color(1,1,1,0.62), "overlap expiry cannot suppress still-authoritative dodge body treatment")
			equal(int(remaining_dodge.get("budget_pips", -1)), 1, "overlap expiry reveals the exact last dodge-budget pip")
			state.air_dodge_ticks -= 1
			var recovery := CartoonChampionPresenter.protection_contract(state, config, false, height)
			check(not recovery.active, "both protections end immediately while vulnerable recovery remains")
			equal(recovery.get("body_tint"), Color.WHITE, "overlap recovery cannot retain a fading body")
			equal(int(recovery.get("budget_pips", -1)), 0, "overlap recovery cannot retain a stale protection meter")
	var state := PlayerState.new()
	state.spawn_protection_ticks = 1
	state.air_dodge_ticks = 22
	state.hop_mode = PlayerState.MovementMode.AIR_DODGE
	state.health = 0
	var invalid: Array[Dictionary] = []
	invalid.append(CartoonChampionPresenter.protection_contract(state, config))
	invalid.append(CartoonChampionPresenter.protection_contract(null, config))
	invalid.append(CartoonChampionPresenter.protection_contract(PlayerState.new(), null))
	for result: Dictionary in invalid:
		check(not result.active, "dead or missing authority fails closed despite stale protection fields")
		equal(result.get("body_tint"), Color.WHITE, "invalid protection leaves no transparent protected body")
		equal(int(result.get("budget_pips", -1)), 0, "invalid protection leaves no budget pips")
