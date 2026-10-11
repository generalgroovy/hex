extends FluxTestSuite
## Exact descriptors and ownership, not rendered/native or capacity acceptance.

const Pixels = preload("res://src/presentation/pixel_flipbook_presenter.gd")
const Actions = preload("res://src/presentation/pixel_action_bank.gd")
const Reference = preload("res://tests/support/pixel_descriptor_reference.gd")
const MovementReference = preload("res://tests/support/pixel_movement_reference.gd")
const AerialChecks = preload("res://tests/support/native_aerial_assertions.gd")
const CATALOG := "res://content/champions/foundation_champions_v1.json"
const GROUND_ACTIONS := ["idle", "walk", "sprint", "cast", "rooted"]
const ACTION_ALIASES := ["jumpsquat", "jump", "double_jump", "walljump", "slide_jump", "fall", "fast_fall", "land"]
var compared := 0
var wrapper_compared := 0


func run() -> int:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	var ids: Array = []
	for champion: Dictionary in catalog.champions: ids.append(champion.id)
	ids.sort()
	var bank := Pixels.new()
	check(bank.configure(ids, true), "live fixed banks admit before descriptor oracle: " + bank.last_error)
	check(bank.action_bank != null, "optional current action bank actually admitted")
	if bank.entries.is_empty() or bank.action_bank == null: return finish("pixel-descriptor-reuse")
	equal(ids.size(), 30, "all thirty live identities participate")
	_ground_matrix(bank, ids)
	_action_matrix(bank, ids)
	_phase_edges(bank, ids[0])
	_invalid_queries(bank, ids[0])
	_mutation_and_interleaving(bank, ids[0])
	var pilot := Pixels.new()
	check(pilot.configure(ids, false), "historical pilot remains independently admitted")
	if not pilot.entries.is_empty():
		_ground_matrix(pilot, pilot.entries.keys())
		_mutation_and_interleaving(pilot, pilot.entries.keys()[0])
	_admission_lifecycle()
	_wrapper_equivalence(ids)
	_aerial_cache_ownership(bank, ids)
	# Expected loop counts catch helpers that aborted rather than completed.
	equal(compared, 159019, "all complete reference cases executed, no empty partial pass")
	return finish("pixel-descriptor-reuse")


func _ground_matrix(bank: RefCounted, ids: Array) -> void:
	for id: String in ids:
		for action: String in GROUND_ACTIONS:
			for aim: int in 8:
				for travel: int in 8:
					for step: int in 4:
						for cast_case: int in 3:
							var casting := cast_case > 0
							var weight := 0.375 if cast_case == 2 else 0.0
							var reduced := (aim + travel + step + cast_case) % 2 == 0
							_compare(bank, id, action, aim, travel, float(step) / 4.0, casting, weight, reduced)


func _action_matrix(bank: RefCounted, ids: Array) -> void:
	for id: String in ids:
		for action: String in ACTION_ALIASES:
			for aim: int in 8:
				for travel: int in 8:
					for casting: bool in [false, true]:
						var phase := -2.25 if (aim + travel) % 2 == 0 else 3.125
						_compare(bank, id, action, aim, travel, phase, casting, 1.0, casting)


func _phase_edges(bank: RefCounted, id: String) -> void:
	for action: String in ["walk", "sprint"]:
		for aim: int in 8:
			for travel: int in 8:
				for phase: float in [-2.0, -0.25, -0.000001, 0.0, 0.249999, 0.25, 0.499999, 0.5, 0.749999, 0.75, 1.0, 2.5]:
					_compare(bank, id, action, aim, travel, phase, true, 1.0, false)
	# The compact neutral row is reused at two distinct logical beats, but
	# those beats must still disclose different sample_phase metadata.
	var first: Dictionary = bank.frame(id, "walk", 0, 0, 0.25, false, 0.0, false)
	var second: Dictionary = bank.frame(id, "walk", 0, 0, 0.75, false, 0.0, false)
	equal(first.components, second.components, "reused neutral pixels are exactly equal")
	check(first.sample_phase != second.sample_phase and first.motion_phase != second.motion_phase, "descriptor reuse never erases live gait phase")


func _invalid_queries(bank: RefCounted, id: String) -> void:
	for action: String in ["walk", "jump"]:
		for phase: float in [NAN, INF, -INF]:
			_compare(bank, id, action, 0, 0, phase, false, 0.0, false)
		for weight: float in [NAN, INF, -INF, -0.01, 1.01]:
			_compare(bank, id, action, 0, 0, 0.25, true, weight, false)
		for facing: int in [-1, 8]:
			_compare(bank, id, action, facing, 0, 0.25, false, 0.0, false)
			_compare(bank, id, action, 0, facing, 0.25, false, 0.0, false)
		_compare(bank, "missing", action, 0, 0, 0.25, false, 0.0, false)
	for action: String in ["slide", "roll", "air_dodge", "wallrun", "fly", "hit", "stunned", "defeated", "unknown"]:
		_compare(bank, id, action, 0, 0, 0.25, false, 0.0, false)


func _compare(bank: RefCounted, id: String, action: String, aim: int, travel: int, phase: float, casting: bool, weight: float, reduced: bool) -> void:
	var expected_phase := phase
	if bank.full_cast and action in ["walk", "sprint"] and is_finite(phase):
		# The frozen October3 selector remains untouched. The intentional contact
		# timing refinement samples its original four quarter-phase descriptors;
		# exact edge/occupancy tests live in test_pixel_flipbook_presenter.gd.
		var cycle := fposmod(phase, 1.0)
		if cycle >= 0.15625 and cycle < 0.34375: expected_phase = 0.25
		elif cycle >= 0.34375 and cycle < 0.65625: expected_phase = 0.5
		elif cycle >= 0.65625 and cycle < 0.84375: expected_phase = 0.75
		else: expected_phase = 0.0
	var expected := Reference.ground_frame(bank, id, action, aim, travel, expected_phase, casting, weight, reduced)
	if not expected.is_empty(): expected.motion_phase = phase
	var actual: Dictionary = bank.frame(id, action, aim, travel, phase, casting, weight, reduced)
	compared += 1
	var same := Reference.same_descriptor(actual, expected)
	check(same, "complete descriptor retains exact keys/types/regions/texture/live values")
	if not same:
		print("DESCRIPTOR_ORACLE_MISMATCH ", [id, action, aim, travel, phase, casting, weight, reduced])


func _mutation_and_interleaving(bank: RefCounted, id: String) -> void:
	var actions: Array = ["walk", "idle", "cast", "jump"] if bank.action_bank != null else ["walk", "idle", "cast"]
	for action: String in actions:
		var held: Dictionary = bank.frame(id, action, 3, 6, 0.75, true, 1.0, false)
		var expected := held.duplicate(true)
		for index: int in 16:
			var other: Dictionary = bank.frame(id, action, index % 8, (index * 3) % 8, float(index) / 7.0, index % 2 == 0, 0.25, true)
			other.components[0].source_region = Rect2()
			other.components[0].texture = null
			other.components.append({"source_region": Rect2(1, 2, 3, 4)})
			other.motion_phase = -999.0
			other.clear()
		check(Reference.same_descriptor(held, expected), "other actors and observers cannot mutate a retained descriptor")
		var later: Dictionary = bank.frame(id, action, 3, 6, 0.75, true, 1.0, false)
		check(Reference.same_descriptor(later, expected), "offscreen gap/reentry reproduces fresh scalars without stale history")
		held.components.clear()
		held.clear()
		check(Reference.same_descriptor(bank.frame(id, action, 3, 6, 0.75, true, 1.0, false), expected), "returned top-level/array/component mutations never reach templates")


func _admission_lifecycle() -> void:
	var image := Image.create(1024, 512, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.3, 0.5, 0.7, 1.0))
	var texture := ImageTexture.create_from_image(image)
	var digest := _rgba_hash(image)
	var ground := {"id": Pixels.CAST_MANIFEST_ID, "schema_version": 1, "cell": [128,128], "pivot": [64,104],
		"directions": Pixels.DIRECTIONS.duplicate(), "rows": Pixels.CAST_ROWS.duplicate(),
		"characters": [{"id":"one", "body":"small", "atlas":"one.png", "rgba_sha256":digest, "waist_y":78, "display_height":58}]}
	var action := {"id":"hex-pixel-actions-v1", "schema_version":1, "cell":[128,128], "pivot":[64,104],
		"directions": Actions.DIRECTIONS.duplicate(), "rows": Actions.ROWS.duplicate(),
		"characters":[{"id":"one", "body":"small", "atlas":"one.png", "rgba_sha256":digest}]}
	var bank := Pixels.new()
	var actions := Actions.new()
	for waist: int in [78, 93, 1, 127]:
		ground.characters[0].waist_y = waist
		check(bank.admit_manifest(ground, ["one"], {"one.png":texture}), "ground re-admission publishes a complete bounded domain")
		_compare(bank, "one", "walk", 2, 5, 0.75, true, 0.5, false)
		equal(bank.frame("one", "idle", 0, 0, 0.0, false, 0.0, false).components[0].destination_region.position.y, float(waist), "new admitted waist cannot reuse old geometry")
		check(actions.admit(action, bank.entries, {"one.png":texture}), "action re-admission succeeds independently")
		bank.action_bank = actions
		_compare(bank, "one", "jump", 7, 2, 0.375, true, 1.0, false)
		check(not actions.admit(action, bank.entries, {}), "failed action re-admission clears prior drawable state")
		check(bank.frame("one", "jump", 0, 0, 0.5, false, 0.0, false).is_empty(), "old action descriptors are unreachable after failed admission")
		check(not bank.admit_manifest(ground, ["one"], {}), "failed ground re-admission clears prior state")
		check(bank.action_bank == null and bank.entries.is_empty(), "failed ground admission also revokes optional action bank")
		check(bank.frame("one", "idle", 0, 0, 0.0, false, 0.0, false).is_empty(), "failed ground bank returns fallback, not a cached stale frame")
	# Replacing a valid texture also replaces every borrowed resource reference.
	image.fill(Color(0.8, 0.2, 0.1, 1.0))
	var replacement := ImageTexture.create_from_image(image)
	ground.characters[0].rgba_sha256 = _rgba_hash(image)
	check(bank.admit_manifest(ground, ["one"], {"one.png":replacement}), "replacement immutable atlas admits")
	var fresh: Dictionary = bank.frame("one", "idle", 0, 0, 0.0, false, 0.0, false)
	check(fresh.texture == replacement and fresh.components[0].texture == replacement and fresh.texture != texture, "replacement templates retain no stale old atlas")
	action.characters[0].rgba_sha256 = _rgba_hash(image)
	action.characters[0].body = "middle"
	check(actions.admit(action, {"one":{"body":"middle"}}, {"one.png":replacement}), "replacement action atlas and parent body admit together")
	var fresh_action: Dictionary = actions.frame("one", "jump", 2, 7, 0.625, true)
	check(Reference.same_descriptor(fresh_action, Reference.action_frame(actions, "one", "jump", 2, 7, 0.625, true)), "action re-admission replaces complete descriptors exactly")
	check(fresh_action.texture == replacement and fresh_action.components[0].texture == replacement and fresh_action.texture != texture, "replacement action templates retain no stale atlas")
	check(fresh_action.body_type == "middle" and fresh_action.display_height == 63, "replacement action templates retain no stale body metadata")


func _rgba_hash(image: Image) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(image.get_data())
	return hash.finish().hex_encode()


func _wrapper_equivalence(ids: Array) -> void:
	var language := VisualLanguage.new()
	var candidate := CartoonChampionPresenter.new()
	var reference := MovementReference.new()
	check(language.load_from_file(), "wrapper oracle uses production visual language")
	check(candidate.configure(language) and candidate.enable_fullbody_art(false, true), "candidate wrapper admits both fixed banks")
	check(reference.configure(language) and reference.enable_fullbody_art(false, true), "frozen preceding wrapper admits both fixed banks")
	if candidate.fullbody_art == null or reference.fullbody_art == null: return
	check(not candidate.fullbody_art.pixel_pilot.has_method("descriptor_template_count"), "rejected persistent descriptor cache is absent from production")
	var fixed_actions := ["idle", "walk", "sprint", "moving_pending_cast", "moving_recovery_cast", "cast", "jumpsquat", "jump", "fall", "fast_fall", "double_jump", "walljump", "slide_jump", "land", "rooted"]
	for id: String in ids:
		for action: String in fixed_actions:
			for aim: int in 8:
				for reduced: bool in [false, true]:
					var phase := float(aim % 4) / 4.0
					_wrapper_check(candidate, reference, id, _wrapper_state(action, aim), 123.75, phase, reduced)
	for id: String in ["s_wayne", "oh_tipi", "red_baron"]:
		for action: String in ["slide", "roll", "wavedash", "wallrun", "fly", "hit", "stunned", "defeated", "crouch", "air_dodge"]:
			for aim: int in 8:
				for reduced: bool in [false, true]:
					_wrapper_rigid_transition_check(candidate, reference, id, _wrapper_state(action, aim), 140.25, 0.375, reduced)
	var candidate_bank: RefCounted = candidate.fullbody_art.pixel_pilot
	var reference_bank: RefCounted = reference.fullbody_art.pixel_pilot
	candidate.fullbody_art.pixel_pilot = null
	reference.fullbody_art.pixel_pilot = null
	# The deliberately changed pixel fallbacks above exercised legacy GPU
	# streams only in the frozen reference. Start explicit legacy comparison
	# from the same empty dynamic history, not create-vs-update buffer histories.
	# Immutable pose caches remain intact; every following descriptor and actual
	# mesh surface is still compared exactly, including the ordered settle test.
	for art: RefCounted in [candidate.fullbody_art, reference.fullbody_art]:
		art.render_meshes.clear()
		art.render_order.clear()
	for id: String in ["s_wayne", "oh_tipi", "red_baron"]:
		for action: String in ["idle", "walk", "sprint", "slide", "wallrun", "roll", "jump"]:
			for aim: int in 8:
				for reduced: bool in [false, true]:
					_wrapper_check(candidate, reference, id, _wrapper_state(action, aim), 150.5, -1.0, reduced)
	# Legacy per-actor settling still sees the identical ordered pose history.
	for reduced: bool in [false, true]:
		var step := 0
		for action: String in ["walk", "idle", "sprint", "slide", "jump", "walk"]:
			var tick := 300.0 + float(step) * 0.5 if step < 4 else 600.0 + float(step) * 0.5
			_wrapper_check(candidate, reference, "oh_tipi", _wrapper_state(action, 2), tick, float(step) / 7.0, reduced)
			step += 1
	candidate.fullbody_art.pixel_pilot = candidate_bank
	reference.fullbody_art.pixel_pilot = reference_bank
	# No-fullbody wireframe paths still request the default full motion sample.
	candidate.fullbody_art = null
	reference.fullbody_art = null
	for id: String in ["s_wayne", "oh_tipi", "red_baron"]:
		for action: String in ["walk", "idle", "slide", "jump"]:
			for aim: int in 8:
				for reduced: bool in [false, true]:
					_wrapper_check(candidate, reference, id, _wrapper_state(action, aim), 190.125, 0.625, reduced)
	equal(wrapper_compared, 8220, "complete unchanged-frame oracle plus deliberate rigid-fallback transition matrix ran")
	for profile: String in candidate.motion.profiles:
		for action: String in MinimalChampionMotion.REQUIRED_MOTIONS:
			for elapsed: float in [-1.0, 0.0, 3.25, 12.5, 84.0, 180.25]:
				for reduced: bool in [false, true]:
					var complete := candidate.motion.sample(profile, action, elapsed, reduced)
					var aura_only := candidate.motion.sample(profile, action, elapsed, reduced, false)
					equal(aura_only.aura_scale, complete.aura_scale, "selective sample retains exact aura interpolation")
					equal(aura_only.scale, complete.scale, "selective sample keeps invariant body scale")
					equal(aura_only.offset, Vector2.ZERO, "selective sample does not prepare discarded offset")


func _wrapper_rigid_transition_check(candidate: CartoonChampionPresenter, reference: CartoonChampionPresenter, id: String, state: PlayerState, tick: float, phase: float, reduced: bool) -> void:
	# These ten full-pixel actions intentionally no longer match the frozen rig
	# pixels/geometry. Keep the preceding oracle unchanged and compare every
	# stable wrapper, direction, clock and ground-anchor field separately.
	var config := SimConfig.new(120)
	var before := var_to_bytes([state.canonical_values(), state.last_event])
	var expected := reference.movement_frame(id, state, tick, config, reduced, phase)
	var actual := candidate.movement_frame(id, state, tick, config, reduced, phase)
	check(expected.has("mesh") and expected.has("render_mesh"), "frozen preceding unsupported-action path establishes the legacy morphing regression")
	if actual.get("procedural_pixel_pose", false):
		_assert_aerial_wrapper(actual, expected, candidate.fullbody_art.pixel_pilot, id)
		check(var_to_bytes([state.canonical_values(), state.last_event]) == before, "aerial and archived wrapper queries preserve all authority and event history")
		wrapper_compared += 1
		return
	check(actual.get("rigid_pose_fallback", false) and actual.get("visual_mode") == "pixel_cast", "current unsupported-action path explicitly stays in rigid pixels")
	check(not actual.has("mesh") and not actual.has("render_mesh") and not actual.has("pose_blend"), "intentional renderer correction removes all body-part morphing")
	for key: String in ["animation_state", "motion_id", "contact_frame", "offset", "scale", "aura_scale", "squat_depth", "cell_size", "pivot", "action", "aim_index", "travel_index", "display_height", "motion_phase", "wireframe_body", "fullbody_art"]:
		equal(actual.get(key), expected.get(key), "rigid renderer correction preserves preceding wrapper contract: " + key)
	check(not actual.get("all_action_art_complete", true) and not actual.get("independent_cast_pose", true), "renderer correction never claims new action cycles or low/air cast art")
	check(var_to_bytes([state.canonical_values(), state.last_event]) == before, "rigid and frozen legacy queries preserve authority and event history")
	wrapper_compared += 1


func _wrapper_check(candidate: CartoonChampionPresenter, reference: CartoonChampionPresenter, id: String, state: PlayerState, tick: float, phase: float, reduced: bool) -> void:
	var config := SimConfig.new(120)
	var before := var_to_bytes([state.canonical_values(), state.last_event])
	var expected := _geometry_descriptor(reference.movement_frame(id, state, tick, config, reduced, phase))
	var actual := _geometry_descriptor(candidate.movement_frame(id, state, tick, config, reduced, phase))
	check(not expected.is_empty(), "wrapper oracle must have a nonempty reference frame")
	if actual.get("procedural_pixel_pose", false):
		_assert_aerial_wrapper(actual, expected, candidate.fullbody_art.pixel_pilot, id)
		check(var_to_bytes([state.canonical_values(), state.last_event]) == before, "new aerial assembly and archived wrapper both preserve authority and event history")
		wrapper_compared += 1
		return
	var same := Reference.same_descriptor(actual, expected)
	check(same, "discarded-work subtraction preserves complete frame keys/types/values and geometry")
	if not same:
		var different: Array[String] = []
		for key: String in actual:
			if not expected.has(key) or not Reference.same_descriptor(actual[key], expected[key]): different.append(key)
		print("WRAPPER_ORACLE_MISMATCH ", [id, state.movement_mode, state.control_state, tick, phase, reduced], " differing_keys=", different)
	check(var_to_bytes([state.canonical_values(), state.last_event]) == before, "neither wrapper writes authority or event history")
	wrapper_compared += 1


func _assert_aerial_wrapper(actual: Dictionary, expected: Dictionary, bank: RefCounted, id: String) -> void:
	# The frozen ground/legacy oracle remains unchanged. New aerial geometry is
	# checked against independent native-pixel bounds, not a copy of the builder.
	AerialChecks.assert_frame(self, actual, bank, id, String(expected.action), int(expected.aim_index))
	for key: String in ["animation_state", "motion_id", "contact_frame", "offset", "scale", "aura_scale", "squat_depth", "action", "aim_index", "travel_index", "fullbody_art"]:
		equal(actual.get(key), expected.get(key), "new aerial geometry preserves exact preceding wrapper state and timing: " + key)
	check(not actual.has("mesh") and not actual.has("render_mesh") and not actual.has("pose_blend"), "aerial assembly cannot reactivate legacy body deformation")
	check(not actual.get("wireframe_body", false), "native aerial parts never opt into wireframe rendering")


func _aerial_cache_ownership(bank: RefCounted, ids: Array) -> void:
	for id: String in ids:
		var held: Dictionary = bank.aerial_frame(id, "jump", 3, 6, 20.0, 28_000, false)
		var expected := held.duplicate(true)
		check(held.pixel_parts.is_read_only(), "shared tuck part arrays are immutable when borrowed")
		for part: Dictionary in held.pixel_parts:
			check(part.is_read_only() and part.meshes.is_read_only(), "borrowed anatomy and clipped polygon collections are immutable")
		for index: int in 96:
			#8 aim columns x3 vertical folds x4 held quarter turns:96 distinct
			# native geometry keys must really exceed the64-entry cache bound.
			var fold := floori(float(index) / 8.0) % 3
			var turn := floori(float(index) / 24.0)
			var vertical: int = [200_000, 28_000, -200_000][fold]
			var other: Dictionary = bank.aerial_frame(id, "fall", index % 8, 6, float([0,9,21,33][turn]), vertical, false)
			other.texture = null
			other.clear()
		check(Reference.same_descriptor(held, expected), "interleaved actors and bounded-cache evictions cannot mutate retained aerial pixels")
		equal(bank.aerial_profiles[id].tucks.size(), 64, "all96 distinct keys exercise actual eviction at the exact64-entry geometry bound")
		held.clear()
		check(Reference.same_descriptor(bank.aerial_frame(id, "jump", 3, 6, 20.0, 28_000, false), expected), "evicted or retained aerial query reproduces exact geometry and identity without history")


func _geometry_descriptor(frame: Dictionary) -> Dictionary:
	var result := frame.duplicate(true)
	for key: String in ["mesh", "render_mesh"]:
		if not frame.has(key): continue
		var mesh: ArrayMesh = frame[key]
		var arrays: Array = mesh.surface_get_arrays(0) if mesh.get_surface_count() == 1 else []
		var available: bool = arrays.size() == Mesh.ARRAY_MAX \
			and arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array and not arrays[Mesh.ARRAY_VERTEX].is_empty() \
			and arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array and not arrays[Mesh.ARRAY_TEX_UV].is_empty() \
			and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array and not arrays[Mesh.ARRAY_INDEX].is_empty()
		check(available, "source/stream surface exposes nonempty vertex, UV and index arrays for honest geometry comparison")
		if not available:
			result[key] = {"geometry_unavailable":true}
			continue
		# Source meshes retain every prepared array; streaming meshes retain
		# only CPU vertices. Missing metadata falls back to that actual surface,
		# never null/empty data or the other mesh's unverified topology. Compare
		# both prepared data and real surface arrays without demanding identical
		# CPU/GPU packing within one arm. This is geometry, not raster evidence.
		result[key] = {
			"vertices":mesh.get_meta("cpu_vertices") if mesh.has_meta("cpu_vertices") else arrays[Mesh.ARRAY_VERTEX],
			"uvs":mesh.get_meta("cpu_uvs") if mesh.has_meta("cpu_uvs") else arrays[Mesh.ARRAY_TEX_UV],
			"indices":mesh.get_meta("cpu_indices") if mesh.has_meta("cpu_indices") else arrays[Mesh.ARRAY_INDEX],
			"surface_vertices":arrays[Mesh.ARRAY_VERTEX], "surface_uvs":arrays[Mesh.ARRAY_TEX_UV],
			"surface_indices":arrays[Mesh.ARRAY_INDEX],
		}
	return result


func _wrapper_state(action: String, aim: int) -> PlayerState:
	var state := PlayerState.new(90000 + aim)
	var look: Vector2i = EightDirectionResolver.FIXED_VECTORS[aim]
	var travel: Vector2i = EightDirectionResolver.FIXED_VECTORS[(aim + 3) % 8]
	state.aim_x = look.x; state.aim_y = look.y; state.facing_x = look.x; state.facing_y = look.y
	match action:
		"walk", "sprint", "moving_pending_cast", "moving_recovery_cast":
			state.movement_mode = PlayerState.MovementMode.SPRINT if action == "sprint" else PlayerState.MovementMode.WALK
			state.velocity_x = travel.x * 90; state.velocity_y = travel.y * 90
			if action == "moving_pending_cast": state.pending_cast_wire_id = 1; state.pending_cast_ticks = 4
			elif action == "moving_recovery_cast": state.cast_recovery_ticks = 4
		"cast":
			state.control_state = PlayerState.ControlState.CHARGING; state.movement_mode = PlayerState.MovementMode.CHARGING
			state.pending_cast_wire_id = 1; state.pending_cast_ticks = 3
		"rooted": state.control_state = PlayerState.ControlState.ROOTED
		"jumpsquat": state.jumpsquat_active = true; state.jumpsquat_ticks = 12
		"land": state.landing_ticks = 5
		"slide", "wavedash":
			state.movement_mode = PlayerState.MovementMode.SLIDE if action == "slide" else PlayerState.MovementMode.WAVE_DASH
			state.velocity_x = travel.x * 120; state.velocity_y = travel.y * 120
			state.slide_x = travel.x; state.slide_y = travel.y; state.slide_ticks = 12
		"wallrun":
			state.wall_skim_ticks = 12; state.movement_mode = PlayerState.MovementMode.WALL_SKIM
			state.wall_skim_x = travel.x; state.wall_skim_y = travel.y
			state.velocity_x = travel.x * 110; state.velocity_y = travel.y * 110
		"hit": state.control_state = PlayerState.ControlState.LAUNCHED; state.impact_recovery_ticks = 8
		"stunned": state.control_state = PlayerState.ControlState.STUNNED
		"defeated": state.health = 0
		"crouch": state.crouching = true
		"roll":
			state.movement_mode = PlayerState.MovementMode.ROLL; state.hop_mode = PlayerState.MovementMode.ROLL
			state.air_dodge_ticks = 12
		"idle": pass
		_:
			state.air_height = 45000; state.air_vertical_velocity = 28000; state.hop_ticks = 12
			state.movement_mode = PlayerState.MovementMode.HOP; state.hop_mode = PlayerState.MovementMode.HOP
			if action == "double_jump": state.hop_mode = PlayerState.MovementMode.DOUBLE_JUMP
			elif action == "walljump": state.hop_mode = PlayerState.MovementMode.WALL_KICK
			elif action == "slide_jump": state.hop_mode = PlayerState.MovementMode.SLIDE_JUMP
			elif action in ["fall", "fast_fall"]:
				state.air_vertical_velocity = -28000
				if action == "fast_fall": state.movement_mode = PlayerState.MovementMode.FAST_FALL
			elif action == "air_dodge": state.air_dodge_ticks = 8
			elif action == "fly": state.air_floating = true; state.flight_capable = true; state.float_ticks = 12
	return state
