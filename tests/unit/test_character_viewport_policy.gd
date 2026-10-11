extends FluxTestSuite

const Policy = preload("res://src/presentation/character_viewport_policy.gd")
const PixelBody = preload("res://src/presentation/pixel_flipbook_presenter.gd")
const PixelActions = preload("res://src/presentation/pixel_action_bank.gd")
const Fullbody = preload("res://src/presentation/fullbody_cast_presenter.gd")
const VIEW := Rect2(0, 0, 1280, 720)
const FAR := Vector2(10000, 10000)
const ID := "synthetic"


class CountingPixelBody:
	extends "res://src/presentation/pixel_flipbook_presenter.gd"
	var route_queries := 0
	func has_character(id: String) -> bool:
		route_queries += 1
		return super.has_character(id)


func run() -> int:
	_test_camera_geometry()
	_test_visible_anchor_fast_admission()
	_test_routes_and_cues()
	_test_direction_size_and_jump_matrix()
	_test_reentry_and_read_only_history()
	_test_draw_integration_boundary()
	return finish("character-viewport-policy")


func _presenter(body_type: String = "middle", pixel: bool = true) -> CartoonChampionPresenter:
	var result := CartoonChampionPresenter.new()
	result.champions[ID] = {"height": PixelBody.BODY_HEIGHTS[body_type], "body_type": body_type}
	if pixel:
		# Pure policy tests use synthetic admitted metadata; no atlas import or
		# GPU texture is needed to decide the exact fixed destination geometry.
		result.fullbody_art = Fullbody.new()
		result.fullbody_art.entries[ID] = {"body": body_type}
		result.fullbody_art.pixel_pilot = PixelBody.new()
		result.fullbody_art.pixel_pilot.entries[ID] = {"body": body_type}
		result.fullbody_art.pixel_pilot.textures[ID] = null
	return result


func _skip(presenter: CartoonChampionPresenter, state: PlayerState, anchor: Vector2 = FAR, ground: Vector2 = FAR, camera: Vector2 = Vector2.ZERO, zoom: int = 100) -> bool:
	return Policy.can_skip_body(presenter, ID, state, SimConfig.new(120), anchor, ground, camera, VIEW, zoom)


func _test_camera_geometry() -> void:
	for zoom: int in [50, 75, 100]:
		for camera: Vector2 in [Vector2.ZERO, Vector2(123.4, -59.7), Vector2(12000.25, 18000.75)]:
			var scale := PixelPresentation.zoom_scale(zoom)
			var translation := PixelPresentation.snapped_canvas_origin(camera, zoom)
			for edge: Rect2 in [Rect2(-20, 300, 20, 20), Rect2(1280, 300, 20, 20), Rect2(600, -20, 20, 20), Rect2(600, 720, 20, 20)]:
				var world_rect := Rect2((edge.position - translation) / scale, edge.size / scale)
				check(not Policy.outside_viewport(world_rect, camera, VIEW, zoom), "touching viewport edge is retained with exact snapped camera")
			for outside: Rect2 in [Rect2(-30, 300, 20, 20), Rect2(1290, 300, 20, 20), Rect2(600, -30, 20, 20), Rect2(600, 730, 20, 20)]:
				var world_rect := Rect2((outside.position - translation) / scale, outside.size / scale)
				check(Policy.outside_viewport(world_rect, camera, VIEW, zoom), "fully outside rectangle may be rejected at every zoom")
	check(not Policy.outside_viewport(Rect2(FAR, Vector2(20, 20)), Vector2.ZERO, VIEW, 99), "unknown camera zoom fails open")
	check(not Policy.outside_viewport(Rect2(), Vector2.ZERO, VIEW, 100), "empty envelope fails open")
	check(not Policy.outside_viewport(Rect2(FAR, Vector2(20, 20)), Vector2.INF, VIEW, 100), "nonfinite camera fails open")
	check(not Policy.outside_viewport(Rect2(Vector2.INF, Vector2.ONE), Vector2.ZERO, VIEW, 100), "nonfinite envelope fails open")
	check(not Policy.outside_viewport(Rect2(FAR, Vector2.ONE), Vector2.ZERO, Rect2(), 100), "empty viewport fails open")


func _test_visible_anchor_fast_admission() -> void:
	var presenter := _presenter()
	var counting := CountingPixelBody.new()
	counting.entries = presenter.fullbody_art.pixel_pilot.entries
	counting.textures = presenter.fullbody_art.pixel_pilot.textures
	presenter.fullbody_art.pixel_pilot = counting
	var state := PlayerState.new()
	var config := SimConfig.new(120)
	var before := state.canonical_values()
	for zoom: int in [50, 75, 100]:
		for camera: Vector2 in [Vector2.ZERO, Vector2(123.4, -59.7), Vector2(10000.25, -20000.75)]:
			var scale := PixelPresentation.zoom_scale(zoom)
			var translation := PixelPresentation.snapped_canvas_origin(camera, zoom)
			var outside := (Vector2(10000, 10000) - translation) / scale
			# The fringe includes all closed screen edges, including right/bottom
			# which Rect2.has_point alone would exclude without a raster guard.
			for screen_anchor: Vector2 in [Vector2(640, 360), Vector2(0, 360), Vector2(1280, 360), Vector2(640, 0), Vector2(640, 720)]:
				var visible := (screen_anchor - translation) / scale
				check(not Policy.can_skip_body(presenter, ID, state, config, visible, outside, camera, VIEW, zoom), "visible body anchor is immediately admitted")
				check(not Policy.can_skip_body(presenter, ID, state, config, outside, visible, camera, VIEW, zoom), "visible floor anchor is immediately admitted")
				check(not Policy.can_skip_body(presenter, "unknown-character", state, config, visible, outside, camera, VIEW, zoom), "visible anchor is admitted without knowing the renderer identity")
	equal(counting.route_queries, 0, "visible-anchor admission never asks the pixel renderer to classify a route")
	equal(state.canonical_values(), before, "visible-anchor fast path is authority read-only")
	# This is deliberately invalid metadata, not an admitted art fixture. The
	# fast path must not inspect or convert it when either anchor is visible.
	presenter.champions[ID] = null
	counting.entries[ID] = null
	state.health = 0 # Unsupported fixed-pixel action must also remain admitted.
	check(not Policy.can_skip_body(presenter, ID, state, config, Vector2(640, 360), FAR, Vector2.ZERO, VIEW, 100), "visible unsupported state bypasses invalid metadata")
	check(not Policy.can_skip_body(presenter, ID, state, config, FAR, Vector2(640, 360), Vector2.ZERO, VIEW, 100), "visible ground bypasses invalid metadata")
	equal(counting.route_queries, 0, "unknown action and malformed metadata do not reach route resolution")
	check(not Policy.can_skip_body(presenter, ID, state, config, FAR, FAR, Vector2.INF, VIEW, 100), "nonfinite camera fails open before invalid metadata")
	check(not Policy.can_skip_body(presenter, ID, state, config, Vector2.INF, FAR, Vector2.ZERO, VIEW, 100), "nonfinite body anchor fails open before invalid metadata")
	check(not Policy.can_skip_body(presenter, ID, state, config, FAR, Vector2.INF, Vector2.ZERO, VIEW, 100), "nonfinite ground anchor fails open before invalid metadata")
	check(not Policy.can_skip_body(presenter, ID, state, config, FAR, FAR, Vector2.ZERO, Rect2(Vector2.INF, Vector2.ONE), 100), "nonfinite viewport origin fails open before invalid metadata")
	check(not Policy.can_skip_body(presenter, ID, state, config, FAR, FAR, Vector2.ZERO, Rect2(Vector2.ZERO, Vector2.INF), 100), "nonfinite viewport size fails open before invalid metadata")
	check(not Policy.can_skip_body(presenter, ID, state, config, FAR, FAR, Vector2.ZERO, Rect2(), 100), "empty viewport fails open before invalid metadata")
	check(not Policy.can_skip_body(presenter, ID, state, config, FAR, FAR, Vector2.ZERO, VIEW, 99), "unknown zoom fails open before invalid metadata")
	var source := FileAccess.get_file_as_string("res://src/presentation/character_viewport_policy.gd")
	var fast_path := source.find("if anchor_view.has_point(body_anchor")
	check(fast_path >= 0 and fast_path < source.find("JumpPresentation.takeoff_contract(state, config)"), "visible anchor precedes takeoff work")
	check(fast_path >= 0 and fast_path < source.find("JumpPresentation.protection_ratio(state, config)"), "visible anchor precedes protection work")
	check(fast_path >= 0 and fast_path < source.find("var local_body := stateless_body_bounds("), "visible anchor precedes renderer and bounds work")


func _test_routes_and_cues() -> void:
	var state := PlayerState.new()
	var presenter := _presenter()
	check(_skip(presenter, state), "fixed-pixel idle can reject before pose generation")
	check(_skip(_presenter("large", false), state), "legacy atlas/wireframe fixed cell can reject")
	presenter.fullbody_art.pixel_pilot = null
	check(not _skip(presenter, state), "shared-rig settling must continue offscreen")
	presenter = _presenter()
	state.air_height = 120000
	state.hop_ticks = 10
	state.air_vertical_velocity = 1000
	check(not _skip(presenter, state), "unsupported pixel action uses established rig fallback")
	presenter.fullbody_art.pixel_pilot.action_bank = PixelActions.new()
	presenter.fullbody_art.pixel_pilot.action_bank.entries[ID] = {"body": "middle"}
	check(_skip(presenter, state), "admitted fixed-pixel action key can reject")
	state.movement_commitment_ticks = 10
	state.hop_mode = PlayerState.MovementMode.HOP
	check(not _skip(presenter, state), "takeoff stamp budget is preserved even offscreen")
	state = PlayerState.new()
	state.wall_memory_ticks = 1
	check(not _skip(presenter, state), "wall-contact capture is never suppressed")
	state.wall_memory_ticks = 0
	state.hop_mode = PlayerState.MovementMode.WALL_KICK
	state.movement_commitment_ticks = 1
	check(not _skip(presenter, state), "past wall-contact replay is never suppressed")
	state = PlayerState.new()
	state.wall_skim_ticks = 1
	check(not _skip(presenter, state), "wall spark budget is preserved")
	state = PlayerState.new()
	state.spawn_protection_ticks = 1
	check(not _skip(presenter, state), "essential authored protection remains on established draw path")
	state = PlayerState.new()
	state.health = 0
	check(not _skip(presenter, state), "unsupported defeated action fails open")
	check(not Policy.can_skip_body(null, ID, state, SimConfig.new(), FAR, FAR, Vector2.ZERO, VIEW, 100), "missing presenter fails open")


func _test_direction_size_and_jump_matrix() -> void:
	for size: String in ["small", "middle", "large"]:
		var presenter := _presenter(size)
		presenter.fullbody_art.pixel_pilot.action_bank = PixelActions.new()
		presenter.fullbody_art.pixel_pilot.action_bank.entries[ID] = {"body": size}
		for direction: int in 8:
			var state := PlayerState.new()
			var heading: Vector2i = EightDirectionResolver.FIXED_VECTORS[direction]
			state.aim_x = heading.x
			state.aim_y = heading.y
			state.velocity_x = -heading.x * 200
			state.velocity_y = -heading.y * 200
			state.movement_mode = PlayerState.MovementMode.SPRINT
			var before := state.canonical_values()
			equal(Policy.stateless_body_bounds(presenter, ID, state), Rect2(-PixelBody.PIVOT, PixelBody.CELL), "all8 directions and3 sizes keep entire fixed cell")
			for anchor: Vector2 in [Vector2(-63, 300), Vector2(1343, 300), Vector2(640, -23), Vector2(640, 823)]:
				check(not _skip(presenter, state, anchor, anchor), "one-pixel body fragment on each viewport edge is retained")
			state.air_height = 400000
			state.hop_ticks = 10
			state.air_vertical_velocity = 1000
			# Feet below view, lifted body in view: no ground-only culling.
			check(not _skip(presenter, state, Vector2(640, 500), Vector2(640, 900)), "high jump remains when feet are below view")
			# Body above view, ground cue in view: no body-only envelope.
			check(not _skip(presenter, state, Vector2(640, -300), Vector2(640, 100)), "ground cue remains when body is above view")
			var jump_before := state.canonical_values()
			check(_skip(presenter, state), "fully outside admitted jump may skip")
			equal(state.canonical_values(), jump_before, "bounds never write jump authority")
			state.air_height = 0
			state.hop_ticks = 0
			state.air_vertical_velocity = 0
			equal(state.canonical_values(), before, "policy never alters identity, facing or motion state")


func _test_reentry_and_read_only_history() -> void:
	var presenter := _presenter()
	var state := PlayerState.new()
	state.entity_id = 7
	var history := ActorMotionHistory.new()
	var states: Array[PlayerState] = [state]
	history.capture(states)
	history.capture_gaits(states, {7: Vector2.ZERO}, {7: 63.0}, 1.0 / 60.0)
	var before := state.canonical_values()
	var gait_before := history.gait_phase(7)
	var sample_before := history.sample(state, 0.5)
	check(_skip(presenter, state), "far body starts outside")
	for camera: Vector2 in [FAR - Vector2(640, 360), Vector2(-20000, -20000), FAR - Vector2(640, 360)]:
		var skip := _skip(presenter, state, FAR, FAR, camera)
		equal(skip, camera.x < 0.0, "fast pan / spectator focus / return uses current camera without stale visibility")
	for _query: int in 32:
		_skip(presenter, state)
	equal(state.canonical_values(), before, "repeated culling cannot write authority")
	equal(history.gait_phase(7), gait_before, "culling has no gait clock side effects")
	equal(history.sample(state, 0.5), sample_before, "culling has no interpolation side effects")
	equal(presenter.fullbody_art.meshes.size(), 0, "route check does not build a source pose")
	equal(presenter.fullbody_art.render_meshes.size(), 0, "route check does not allocate/update stream history")


func _test_draw_integration_boundary() -> void:
	var source := FileAccess.get_file_as_string("res://src/app/bootstrap.gd").replace("\r\n", "\n")
	var start := source.find("func _draw_remote_travellers(")
	var end := source.find("\nfunc _draw_receiving_surface_shadow(", start)
	var section := source.substr(start, end - start)
	var admission := section.find("if not _chemistry_actor_visible(remote_state):")
	var rejection := section.find("viewport_policy.can_skip_body(")
	var build := section.find("cartoon_champion_presenter.draw(")
	check(admission >= 0 and rejection > admission and build > rejection, "visibility authority precedes viewport gate and expensive pose follows it")
	check(rejection >= 0 and not section.substr(rejection).contains("continue"), "body rejection cannot skip the later label, health, aim or spell cues")
	check(not section.contains("history.clear(") and not section.contains("rebase_gait("), "body gate does not reset motion history")
	for cue: String in ["_draw_receiving_surface_shadow(", "_draw_landing_cue(", "_draw_spell_startup(", "_draw_actor_identity_label(display_name, body_position, identity_color)", "draw_rect(health_bar", "draw_line(body_position"]:
		check(section.contains(cue), "nonbody cue retains its independent draw: " + cue)
	var label_call := "_draw_actor_identity_label(display_name, body_position, identity_color)"
	check(section.contains("\n\t\t" + label_call + "\n") and section.find(label_call) > build,
		"identity label remains outside the body-only culling and presenter branches")
	var label_start := source.find("func _draw_actor_identity_label(")
	var label_end := source.find("\nfunc ", label_start)
	check(label_start >= 0 and label_end > label_start, "shared identity-label helper is present")
	if label_start >= 0 and label_end > label_start:
		var label_section := source.substr(label_start, label_end - label_start)
		check(label_section.contains("font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)")
			and label_section.contains("draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)"),
			"identity measurement and text use the same fixed readable font size")
		check(label_section.contains("baseline := body_position + Vector2(-width * 0.5, -64)"),
			"identity placement follows the actor without body-size-dependent scaling")
		for forbidden: String in ["draw_set_transform", "body_type_render_scale", "viewport_policy", "cartoon_champion_presenter"]:
			check(not label_section.contains(forbidden),
				"identity label remains independent of sprite transforms and body culling: " + forbidden)
	check(section.contains("sprite_drawn = true # Only the bounded presenter body is skipped."), "culled body never becomes a fallback circle")
