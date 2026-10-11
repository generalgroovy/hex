extends FluxTestSuite


const Harness = preload("res://tests/support/chemistry_coach_harness.gd")
const OBSERVER_POINT := Vector2(1000.0, 1000.0)


class SpectatorHarness:
	extends "res://tests/support/chemistry_coach_harness.gd"
	var follow_id := 0
	func _is_spectating() -> bool:
		return follow_id > 0
	func _spectator_state() -> PlayerState:
		return world.player(follow_id) if follow_id > 0 else null


class MaskHarness:
	extends "res://tests/support/chemistry_coach_harness.gd"
	var replacement_polygons: Array[PackedVector2Array] = []
	func _draw_pov_terrain(points: PackedVector2Array, _camera_origin: Vector2, _shade: Color = Color.WHITE, _feather: bool = false) -> void:
		replacement_polygons.append(points.duplicate())
	func _pov_hex_occluder_polygons(_camera_origin: Vector2) -> Array[PackedVector2Array]:
		return []


func run() -> int:
	_test_single_mode_and_owned_body()
	_test_fixed_range_and_rotation_invariance()
	_test_full_viewport_and_frame_cache()
	_test_remote_actor_and_chemistry_visibility()
	_test_hex_pillar_visibility()
	_test_interpolated_actor_uses_rendered_side_of_wall()
	_test_cue_endpoints_sources_and_hidden_actors()
	_test_ingested_lanes_bind_interpolated_caster()
	_test_character_cue_anchor_uses_rendered_position()
	_test_spectator_focus_regates_cues()
	_test_missing_observer_fails_closed()
	_test_spray_opaque_pillar_draw_view()
	_test_spray_chemical_interior_and_policy()
	_test_spray_observer_recheck_and_timing()
	return finish("pov-presentation")


func _test_single_mode_and_owned_body() -> void:
	var node := Harness.new()
	check(node.configure_fixture(true), "relative vision configures production body presentation")
	var state: PlayerState = node.world.player()
	for champion_id: String in ["s_wayne", "oh_tipi", "red_baron"]:
		check(node.champion_catalog.apply_to_player(state, champion_id), "relative vision uses an actual authored body size")
		state.spawn_protection_ticks = 0
		for aim: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			state.aim_x = aim.x
			state.aim_y = aim.y
			for height: int in [0, 65_000]:
				state.air_height = height
				state.movement_mode = PlayerState.MovementMode.IDLE if height == 0 else PlayerState.MovementMode.HOP
				var before := state.canonical_values()
				check(node._chemistry_actor_visible(state), "living viewpoint owner remains visible for every body, heading and jump height")
				var overlay: Dictionary = node._pov_observer_overlay_frame(30.0, 0.0)
				equal(int(overlay.get("observer_id", 0)), state.entity_id, "post-mask repaint contains only the living viewpoint owner's body")
				equal(state.canonical_values(), before, "owned-body visibility never mutates combat or movement authority")
	state.health = 0
	check(not node._chemistry_actor_visible(state), "dead viewpoint owner cannot create a visible-body exception")
	equal(node._pov_observer_overlay_frame(30.0, 0.0), {}, "dead viewpoint owner has no post-mask repaint")
	node.free()


func _test_fixed_range_and_rotation_invariance() -> void:
	var node := Harness.new()
	check(node.configure_fixture(), "fixed-range fixture configures without rendering")
	var observer: PlayerState = node.world.player()
	_set_actor_point(observer, OBSERVER_POINT)
	node.current_position = OBSERVER_POINT
	node.previous_position = OBSERVER_POINT
	node.campus_layout.data["buildings"] = []
	check(node._pov_point_visible(OBSERVER_POINT + Vector2(720.0, 0.0)), "exact positive-x 720 boundary is visible")
	check(node._pov_point_visible(OBSERVER_POINT - Vector2(720.0, 0.0)), "exact negative-x 720 boundary is visible")
	check(not node._pov_point_visible(OBSERVER_POINT + Vector2(720.001, 0.0)), "point just beyond positive-x 720 boundary is hidden")
	check(not node._pov_point_visible(OBSERVER_POINT - Vector2(720.001, 0.0)), "point just beyond negative-x 720 boundary is hidden")
	# At the authored 55-degree projection, a 720 ground-unit vertical radius is
	# 589.789 screen-map units. These literals keep this oracle independent of
	# SightOcclusion.project_ground and the production visibility helper.
	check(node._pov_point_visible(OBSERVER_POINT + Vector2(0.0, 589.78)), "point just inside the projected vertical 720 boundary is visible")
	check(not node._pov_point_visible(OBSERVER_POINT + Vector2(0.0, 589.80)), "point just outside the projected vertical 720 boundary is hidden")
	for aim: Vector2i in EightDirectionResolver.FIXED_VECTORS:
		observer.aim_x = aim.x
		observer.aim_y = aim.y
		check(node._pov_point_visible(OBSERVER_POINT + Vector2(600.0, 0.0)), "all eight aim rotations preserve visible points")
		check(not node._pov_point_visible(OBSERVER_POINT + Vector2(721.0, 0.0)), "all eight aim rotations preserve hidden points")
	node.free()


func _test_full_viewport_and_frame_cache() -> void:
	var viewport := SubViewport.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(viewport)
	var node := MaskHarness.new()
	check(node.configure_fixture(), "viewport visibility loads real gameplay authority")
	viewport.add_child(node)
	var observer: PlayerState = node.world.player()
	_set_actor_point(observer, OBSERVER_POINT)
	node.current_position = OBSERVER_POINT
	node.previous_position = OBSERVER_POINT
	node.campus_layout.data["buildings"] = []
	node.player_camera.initialized = true
	var authority_before := observer.canonical_values()
	for size: Vector2i in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1920,1080), Vector2i(2560,1080)]:
		viewport.size = size
		for offset: Vector2 in [Vector2(320.25,480.75), Vector2(-32.25,16.75)]:
			node.player_camera.origin = offset
			var translation := (-offset * 0.75).round()
			for pixel: Vector2 in [Vector2.ZERO, Vector2(size.x,0), Vector2(size), Vector2(0,size.y)]:
				var corner := (pixel - translation) / 0.75
				check(node._pov_point_visible(corner), "every actual viewport corner is visible despite aspect ratio, camera offset and projection")
			var radius: float = node._pov_sight_range(observer)
			check(not node._pov_point_visible(OBSERVER_POINT + Vector2(radius + 1.0, 0)), "screen coverage retains a finite shared range beyond the viewport")
			node.replacement_polygons.clear()
			node._draw_pov_mask(OBSERVER_POINT * 0.75 + translation, Vector2.RIGHT, offset)
			check(node.replacement_polygons.is_empty(), "clear full-screen sight submits no radial mask strips despite world/screen padding differences")
	viewport.size = Vector2i(1280,720)
	node.player_camera.origin = Vector2(300,400)
	node._begin_visibility_frame()
	var cached: float = node._pov_sight_range(observer)
	check(cached > 720.0, "screen coverage expands the legacy radius")
	equal(node._visibility_frame_sight_range, cached, "one draw shares a prepared range for all body and cue queries")
	node._end_visibility_frame()
	viewport.size = Vector2i(2560,1440)
	check(node._pov_sight_range(observer) > cached, "resize outside a draw immediately refreshes screen coverage")
	node.campus_layout.data["buildings"] = [{"bounds": [1050,990,20,20], "occlusion_policy": "los_cutaway"}]
	check(not node._pov_point_visible(Vector2(1300,1000)), "wider screen coverage preserves opaque wall shadows")
	node._draw_pov_mask(OBSERVER_POINT * 0.75 + (-node.player_camera.origin * 0.75).round(), Vector2.RIGHT, node.player_camera.origin)
	check(not node.replacement_polygons.is_empty(), "positive opaque-wall control still submits terrain replacement and shadow polygons")
	equal(observer.canonical_values(), authority_before, "viewport changes never alter simulation state")
	viewport.free()


func _test_remote_actor_and_chemistry_visibility() -> void:
	var node := Harness.new()
	check(node.configure_fixture(), "remote visibility fixture configures")
	var observer: PlayerState = node.world.player()
	_set_actor_point(observer, OBSERVER_POINT)
	node.current_position = OBSERVER_POINT
	node.previous_position = OBSERVER_POINT
	node.campus_layout.data["buildings"] = []
	var target := PlayerState.new(2)
	_set_actor_point(target, OBSERVER_POINT + Vector2(700.0, 0.0))
	node.world.players.append(target)
	node.actor_motion_history.capture(node.world.players)
	check(node._chemistry_actor_visible(target), "remote body, name and health are admitted inside the common range")
	_set_actor_point(target, OBSERVER_POINT + Vector2(721.0, 0.0))
	node.actor_motion_history.clear()
	node.actor_motion_history.capture(node.world.players)
	check(not node._chemistry_actor_visible(target), "remote body, name and health are rejected outside the common range")

	_set_actor_point(target, OBSERVER_POINT - Vector2(70.0, 0.0))
	node.actor_motion_history.clear()
	node.actor_motion_history.capture(node.world.players)
	var steam := ElementReactionState.new()
	steam.recipe_wire_id = 310
	steam.position_x = 965_000
	steam.position_y = 1_000_000
	steam.origin_x = steam.position_x
	steam.origin_y = steam.position_y
	steam.radius = 30_000
	steam.active_tick = 0
	steam.decay_tick = 100
	steam.expiry_tick = 120
	node.world.reactions.append(steam)
	check(not node._chemistry_actor_visible(target), "Steam conceals a remote actor beyond the existing 64-pixel close-readability grace")
	target.chemistry_reveal_ticks = 2
	check(node._chemistry_actor_visible(target), "authoritative chemical reveal defeats chemistry when geometric LOS is clear")
	node.campus_layout.data["buildings"] = [{"bounds": [955, 990, 10, 20], "occlusion_policy": "los_cutaway"}]
	check(not node._chemistry_actor_visible(target), "chemical reveal cannot bypass an opaque building")
	node.free()


func _test_hex_pillar_visibility() -> void:
	var node := Harness.new()
	check(node.configure_fixture(), "Hex visibility fixture configures")
	var observer: PlayerState = node.world.player()
	_set_actor_point(observer, OBSERVER_POINT)
	node.current_position = OBSERVER_POINT
	node.previous_position = OBSERVER_POINT
	node.campus_layout.data["buildings"] = []
	var target := PlayerState.new(2)
	_set_actor_point(target, Vector2(930.0, 1000.0))
	node.world.players.append(target)
	node.actor_motion_history.capture(node.world.players)
	var base: CollisionWorld = node.world.collision
	base.add_obstacle(CollisionWorld.Obstacle.new(999_001, 960_000, 990_000, 970_000, 1_010_000))
	var collision := HexCollisionWorld.new(base)
	var pillar_origin := Vector2i(965_000, 1_000_000)
	var topology := HexGrid.disk(Vector2i.ZERO, 1)
	check(collision.configure_hexes(pillar_origin, topology, []), "visibility starts with trusted empty Hex topology")
	node.world.collision = collision
	node.world.reaction_movement = collision
	check(node._chemistry_actor_visible(target), "ordinary low collision does not become opaque LOS cover")
	equal(node._pov_hex_occluder_polygons(Vector2(900, 900)), [], "empty Hex topology contributes no mask polygon")
	check(collision.configure_hexes(pillar_origin, topology, [Vector2i.ZERO]), "one active physical six-face pillar is installed")
	check(not node._chemistry_actor_visible(target), "active Rampart pillar hides the remote actor")
	target.chemistry_reveal_ticks = 2
	check(not node._chemistry_actor_visible(target), "chemical reveal cannot bypass an opaque physical pillar")
	target.chemistry_reveal_ticks = 0
	var screen_polygons: Array[PackedVector2Array] = node._pov_hex_occluder_polygons(Vector2(900, 900))
	equal(screen_polygons.size(), 1, "active pillar contributes one screen-space occluder")
	if screen_polygons.size() == 1:
		equal(screen_polygons[0].size(), 6, "screen-space pillar retains all six physical faces")
		var fixed_polygon: Array = collision.hex_occluders()[0]
		for index: int in range(6):
			var expected := Vector2(fixed_polygon[index]) / SimConfig.FIXED_SCALE * PlayerCameraRig.ZOOM + (-Vector2(900, 900) * PlayerCameraRig.ZOOM).round()
			check(screen_polygons[0][index].is_equal_approx(expected), "mask converts each exact fixed-point Hex vertex")
	for zoom_percent: int in [50, 75, 100]:
		node.player_preferences.set_camera_zoom_percent(zoom_percent)
		var camera := Vector2(900.37, 901.81)
		var zoom := PlayerCameraRig.ZOOM
		var translation := (-camera * zoom).round()
		var polygons: Array[PackedVector2Array] = node._pov_hex_occluder_polygons(camera)
		for index: int in 6:
			var exact_vertex: Vector2 = Vector2(collision.hex_occluders()[0][index]) / 1000.0
			check(polygons[0][index].is_equal_approx(exact_vertex * zoom + translation), "fractional camera mask remains fixed75% for every legacy saved zoom")
		var building_polygons: Array[PackedVector2Array] = node._pov_building_surface_polygons(camera)
		equal(building_polygons.size(), 0, "low geometry remains absent at every zoom")
	check(collision.configure_hexes(pillar_origin, topology, []), "pillar destruction or expiry clears physical cover")
	check(node._chemistry_actor_visible(target), "pillar removal restores actor visibility")
	node.free()


func _test_interpolated_actor_uses_rendered_side_of_wall() -> void:
	var node := Harness.new()
	check(node.configure_fixture(), "interpolation fixture configures")
	var observer: PlayerState = node.world.player()
	_set_actor_point(observer, Vector2(900.0, 1000.0))
	node.current_position = Vector2(900.0, 1000.0)
	node.previous_position = node.current_position
	node.campus_layout.data["buildings"] = [{"bounds": [960, 990, 10, 20], "occlusion_policy": "los_cutaway"}]
	var target := PlayerState.new(2)
	node.world.players.append(target)

	_set_actor_point(target, Vector2(940.0, 1000.0))
	node.actor_motion_history.capture(node.world.players)
	_set_actor_point(target, Vector2(1000.0, 1000.0))
	node.actor_motion_history.capture(node.world.players)
	node.accumulator_seconds = 0.0
	check(node._chemistry_actor_visible(target), "authority beyond wall does not hide an interpolated body still rendered on the near side")
	node.accumulator_seconds = 1.0 / 120.0
	check(not node._chemistry_actor_visible(target), "interpolated body becomes hidden when its rendered point reaches the far side")

	node.actor_motion_history.clear()
	_set_actor_point(target, Vector2(1000.0, 1000.0))
	node.actor_motion_history.capture(node.world.players)
	_set_actor_point(target, Vector2(940.0, 1000.0))
	node.actor_motion_history.capture(node.world.players)
	node.accumulator_seconds = 0.0
	check(not node._chemistry_actor_visible(target), "authority near wall does not reveal an interpolated body still rendered on the far side")
	node.accumulator_seconds = 1.0 / 120.0
	check(node._chemistry_actor_visible(target), "interpolated body becomes visible when its rendered point reaches the near side")
	node.free()


func _test_cue_endpoints_sources_and_hidden_actors() -> void:
	var node := Harness.new()
	check(node.configure_fixture(), "combat-cue visibility fixture configures")
	var observer: PlayerState = node.world.player()
	_set_actor_point(observer, OBSERVER_POINT)
	node.current_position = OBSERVER_POINT
	node.previous_position = OBSERVER_POINT
	node.campus_layout.data["buildings"] = []
	var target := PlayerState.new(2)
	_set_actor_point(target, OBSERVER_POINT + Vector2(721.0, 0.0))
	node.world.players.append(target)
	node.actor_motion_history.capture(node.world.players)
	check(not node._combat_cue_visible({"position": OBSERVER_POINT + Vector2(100.0, 0.0), "visibility_entity_id": 2}), "visible hit point cannot reveal a hidden target actor")
	check(node._combat_cue_visible({"position": OBSERVER_POINT + Vector2(100.0, 0.0)}), "ordinary cue inside the common LOS is visible")
	check(not node._combat_cue_visible({"position": OBSERVER_POINT + Vector2(721.0, 0.0)}), "cue beyond the common range is hidden")
	check(node._combat_cue_visible({"position": OBSERVER_POINT + Vector2(200.0, 0.0), "start": OBSERVER_POINT + Vector2(100.0, 0.0), "end": OBSERVER_POINT + Vector2(200.0, 0.0)}), "beam or spray lane draws when source and endpoint are both visible")
	check(not node._combat_cue_visible({"position": OBSERVER_POINT + Vector2(200.0, 0.0), "start": OBSERVER_POINT + Vector2(721.0, 0.0), "end": OBSERVER_POINT + Vector2(200.0, 0.0)}), "visible endpoint cannot reveal a hidden beam or spray source")
	check(not node._combat_cue_visible({"position": OBSERVER_POINT + Vector2(200.0, 0.0), "start": OBSERVER_POINT + Vector2(100.0, 0.0), "end": OBSERVER_POINT + Vector2(721.0, 0.0)}), "visible source cannot reveal a hidden beam or spray endpoint")
	node.free()


func _test_ingested_lanes_bind_interpolated_caster() -> void:
	var node := Harness.new()
	check(node.configure_fixture(), "ingested lane fixture configures")
	var observer: PlayerState = node.world.player()
	_set_actor_point(observer, Vector2(900.0, 1000.0))
	node.current_position = Vector2(900.0, 1000.0)
	node.previous_position = node.current_position
	node.campus_layout.data["buildings"] = [{"bounds": [960, 990, 10, 20], "occlusion_policy": "los_cutaway"}]
	var caster := PlayerState.new(2)
	node.world.players.append(caster)
	# The authority state has crossed to the visible side, while interpolation
	# still renders the caster behind the wall. Lane admission must follow the
	# rendered character and cannot infer visibility from authority coordinates.
	_set_actor_point(caster, Vector2(1000.0, 1000.0))
	node.actor_motion_history.capture(node.world.players)
	_set_actor_point(caster, Vector2(940.0, 1000.0))
	node.actor_motion_history.capture(node.world.players)
	node.accumulator_seconds = 0.0
	equal(node._pov_actor_ground_position(caster), Vector2(1000.0, 1000.0), "fixture renders the caster on the hidden side of the wall")
	check(node._pov_point_visible(Vector2(940.0, 1000.0)), "caster authority point is independently visible")
	check(node._pov_point_visible(Vector2(930.0, 1000.0)), "lane endpoint is independently visible")

	var events: Array[Dictionary] = [
		{"type": "beam_fired", "owner_id": 2, "source_wire_id": CombatTuning.VECTOR_LANCE_WIRE_ID, "target_id": 0, "origin_x": 940_000, "origin_y": 1_000_000, "end_x": 930_000, "end_y": 1_000_000},
		{"type": "spray_fired", "owner_id": 2, "source_wire_id": CombatTuning.TIDELINE_WIRE_ID, "end_x": 930_000, "end_y": 1_000_000, "hit_count": 0},
	]
	node._ingest_combat_cues(events)
	equal(node.combat_cues.size(), 2, "real bootstrap ingestion retains one beam and one spray cue")
	if node.combat_cues.size() == 2:
		var beam: Dictionary = node.combat_cues[0]
		var spray: Dictionary = node.combat_cues[1]
		equal(int(beam.get("visibility_source_id", 0)), caster.entity_id, "beam cue binds visibility to its caster")
		equal(int(spray.get("visibility_source_id", 0)), caster.entity_id, "spray cue binds visibility to its caster")
		equal(beam.get("start"), Vector2(940.0, 1000.0), "explicit beam origin remains the exact authored world contact")
		equal(spray.get("start"), Vector2(1000.0, 1000.0), "spray fallback origin follows the interpolated rendered caster")
		check(not node._combat_cue_visible(beam), "visible beam endpoints cannot reveal its hidden interpolated caster")
		check(not node._combat_cue_visible(spray), "visible spray endpoint cannot reveal its hidden interpolated caster")
	node.free()


func _test_character_cue_anchor_uses_rendered_position() -> void:
	var node := Harness.new()
	check(node.configure_fixture(), "character cue anchor fixture configures")
	var target := PlayerState.new(2)
	node.world.players.append(target)
	_set_actor_point(target, Vector2(1000.0, 1000.0))
	node.actor_motion_history.capture(node.world.players)
	_set_actor_point(target, Vector2(940.0, 1000.0))
	node.actor_motion_history.capture(node.world.players)
	node.accumulator_seconds = 0.0
	var interpolated := node._combat_event_anchor({"type": "projectile_hit", "target_id": target.entity_id})
	equal(interpolated.get("position"), Vector2(1000.0, 1000.0), "character hit cue anchors to the interpolated rendered body instead of current authority")
	var exact_contact := node._combat_event_anchor({"type": "projectile_hit", "target_id": target.entity_id, "contact_position": Vector2i(945_000, 1_000_000)})
	equal(exact_contact.get("position"), Vector2(945.0, 1000.0), "explicit contact position remains exact world evidence")
	node.free()


func _test_spectator_focus_regates_cues() -> void:
	var node := SpectatorHarness.new()
	check(node.configure_fixture(), "spectator focus fixture configures")
	node.campus_layout.data["buildings"] = []
	var local: PlayerState = node.world.player()
	local.health = 0
	var first := PlayerState.new(2)
	var second := PlayerState.new(3)
	var target := PlayerState.new(4)
	_set_actor_point(first, Vector2(1000.0, 1000.0))
	_set_actor_point(second, Vector2(2500.0, 1000.0))
	_set_actor_point(target, Vector2(1600.0, 1000.0))
	node.world.players.append(first)
	node.world.players.append(second)
	node.world.players.append(target)
	node.actor_motion_history.capture(node.world.players)
	var cue := {"position": Vector2(1600.0, 1000.0), "visibility_entity_id": 4}
	node.follow_id = 2
	check(node._combat_cue_visible(cue), "cue is visible from the first followed champion")
	check(node._chemistry_actor_visible(first), "followed champion owns the spectator self-visibility exception")
	node.follow_id = 3
	check(not node._combat_cue_visible(cue), "same retained cue is re-gated after spectator focus changes")
	check(node._chemistry_actor_visible(second), "new followed champion owns the self-visibility exception")
	check(not node._chemistry_actor_visible(first), "previous followed champion receives ordinary range gating")
	node.free()


func _test_missing_observer_fails_closed() -> void:
	var node := Harness.new()
	check(node.configure_fixture(), "missing-observer fixture configures")
	var observer: PlayerState = node.world.player()
	observer.health = 0
	var target := PlayerState.new(2)
	_set_actor_point(target, Vector2(node.fixture_anchor) / SimConfig.FIXED_SCALE)
	node.world.players.append(target)
	check(node._pov_observer() == null, "dead local actor supplies no viewpoint")
	check(not node._pov_point_visible(Vector2(target.position_x, target.position_y) / SimConfig.FIXED_SCALE), "point visibility fails closed without a living observer")
	check(not node._chemistry_actor_visible(target), "actor visibility fails closed without a living observer")
	check(not node._combat_cue_visible({"position": Vector2(target.position_x, target.position_y) / SimConfig.FIXED_SCALE}), "combat cues fail closed without a living observer")
	node.free()


func _configure_spray_visibility(node: Node2D) -> bool:
	if not node.configure_fixture(): return false
	_set_actor_point(node.world.player(), OBSERVER_POINT)
	node.current_position = OBSERVER_POINT
	node.previous_position = OBSERVER_POINT
	node.campus_layout.data["buildings"] = []
	node.world.collision = CollisionWorld.new(3_000_000, 2_300_000)
	node.world.hex_court = HexCourt.new()
	return node.world.hex_court.configure_geometry(Vector2i(1_000_000,1_000_000),HexGrid.disk(Vector2i.ZERO,12))


func _ingested_spray(node: Node2D, owner_id: int, endpoint: Vector2) -> Dictionary:
	node.combat_cues.clear()
	var events: Array[Dictionary] = [{"type":"spray_fired","owner_id":owner_id,"source_wire_id":CombatTuning.TIDELINE_WIRE_ID,
		"end_x":roundi(endpoint.x*1000.0),"end_y":roundi(endpoint.y*1000.0),"range":280_000,"hit_count":0}]
	node._ingest_combat_cues(events)
	for cue: Dictionary in node.combat_cues:
		if cue.get("kind") == "spray": return cue
	return {}


func _test_spray_opaque_pillar_draw_view() -> void:
	var node := Harness.new()
	check(_configure_spray_visibility(node), "Spray view uses actual Bootstrap ingestion and POV helpers")
	var collision := HexCollisionWorld.new(node.world.collision)
	check(collision.configure_hexes(Vector2i(1_080_000,1_000_000),HexGrid.disk(Vector2i.ZERO,1),[Vector2i.ZERO]), "actual six-face opaque center pillar enters collision and POV")
	node.world.collision = collision
	var cue := _ingested_spray(node,1,OBSERVER_POINT + Vector2(280,0))
	check(not cue.is_empty(), "real Spray event creates prepared physical spokes")
	if cue.is_empty(): node.free(); return
	cue.label = "SPRAY" # Explicit label negative, independent of wording policy.
	check(not node._pov_point_visible(cue.position) and not node._pov_point_visible(cue.end), "fixture reproduces BOTH hidden full-center endpoint gates")
	var before := var_to_bytes(cue)
	var authority := node.world.state_hash()
	var view := node._spray_cue_draw_view(cue)
	check(not view.is_empty() and node._combat_cue_visible(cue), "opaque center pillar does not suppress genuinely visible clear flanks")
	if view.is_empty(): node.free(); return
	check(view.spray_visible_indices.has(0) and view.spray_visible_indices.has(4), "both outer physical spokes remain visible around actual opaque Hex geometry")
	check(view.spray_geometry.endpoints[2].distance_to(OBSERVER_POINT) < 80.0, "center spoke still ends on the near side of the true pillar")
	equal(view.label, "", "hidden center anchor cannot acquire a floating Spray label")
	check(not view.spray_chemical_broadphase and int(view.spray_visibility_probes) <= 5, "ordinary opaque cover uses only bounded endpoint probes and the final world mask")
	for reduced: bool in [false,true]:
		node.requested_capture_reduced_effects = reduced
		var mode_view := node._spray_cue_draw_view(cue)
		equal(mode_view.spray_geometry,view.spray_geometry,"Normal/Reduced consume the same observer-filtered physical geometry")
		var rays: Array = HexCourtPresenter.SPRAY_CUE_REDUCED_RAYS if reduced else HexCourtPresenter.SPRAY_CUE_RAYS
		check(0 in rays and 4 in rays,"both existing mode subsets retain the two admitted flanks")
	# A new observer-only side shadow hides one whole spoke without rewriting
	# the admission-time physical cache or exposing it via a filled fan.
	# The current outer ray is 45 degrees: x + y = 2000. This rectangle
	# intersects its interior while leaving the opposite lower ray clear.
	node.campus_layout.data["buildings"] = [{"bounds":[1130,850,35,38],"occlusion_policy":"los_cutaway"}]
	check(not node._pov_point_visible(cue.spray_geometry.endpoints[0]), "observer-only side blocker intersects the actual upper spoke sightline")
	check(node._pov_point_visible(cue.spray_geometry.endpoints[4]), "observer-only side blocker leaves the actual lower spoke sightline clear")
	var side_view := node._spray_cue_draw_view(cue)
	check(not side_view.is_empty(), "one hidden side cannot remove the opposite visible flank")
	if not side_view.is_empty():
		equal(side_view.spray_geometry.endpoints[0],OBSERVER_POINT,"hidden upper spoke collapses to the existing no-draw sentinel")
		check(side_view.spray_visible_indices.has(4),"opposite lower spoke remains independently visible")
	equal(var_to_bytes(cue),before,"draw views never mutate retained event/cache geometry or label")
	equal(node.world.state_hash(),authority,"visibility and mode changes never change authority")
	var hidden := PlayerState.new(2)
	_set_actor_point(hidden,OBSERVER_POINT + Vector2(280,0))
	node.world.players.append(hidden)
	node.actor_motion_history.capture(node.world.players)
	var hidden_source := cue.duplicate(true)
	hidden_source.visibility_source_id = 2
	check(node._spray_cue_draw_view(hidden_source).is_empty(),"visible prepared spokes cannot reveal a genuinely opaque-hidden source actor")
	for patch: Dictionary in [{"spray_geometry":{}},{"start":Vector2(INF,0)}]:
		var invalid := cue.duplicate(true)
		invalid.merge(patch,true)
		check(node._spray_cue_draw_view(invalid).is_empty(),"invalid prepared geometry fails closed")
	node.world.player().health = 0
	check(node._spray_cue_draw_view(cue).is_empty(),"dead or missing observer cannot retain a Spray view")
	node.free()


func _concealing_spray_product(node: Node2D, wire: int = 315) -> Dictionary:
	# Unit-only existing product fixture, not paid-formation/native evidence.
	# One real whole hex is placed between observer and a remote spoke interior.
	var cell := Vector2i(2,5)
	var product := {"recipe_wire_id":wire,"active_tick":0,"decay_tick":600,"expiry_tick":700,
		"quantity":600,"coverage":{cell:1},"cells":{cell:600}}
	node.world.hex_court.products[1] = product
	return product


func _remote_spray(node: Node2D) -> Dictionary:
	var caster := PlayerState.new(2)
	_set_actor_point(caster,OBSERVER_POINT + Vector2(0,200))
	node.world.players.append(caster)
	node.actor_motion_history.capture(node.world.players)
	return _ingested_spray(node,2,OBSERVER_POINT + Vector2(280,200))


func _test_spray_chemical_interior_and_policy() -> void:
	var node := Harness.new()
	check(_configure_spray_visibility(node),"chemical Spray view fixture configures")
	var cue := _remote_spray(node)
	var baseline := node._spray_cue_draw_view(cue)
	check(not baseline.is_empty() and not baseline.spray_chemical_broadphase,"ordinary remote Spray needs no chemical broadphase")
	var product := _concealing_spray_product(node)
	check(HexProductEffects._active(product,0) and HexProductEffects._concealing(product,315,0,node.world.config),"Cinderveil fixture uses the actual active concealment contract")
	check(node._pov_point_visible(cue.start) and node._pov_point_visible(cue.end),"remote source and center endpoint are both independently visible")
	check(not node._pov_point_visible(OBSERVER_POINT + Vector2(208,200)),"the same remote center spoke has a genuinely concealed interior")
	var before := var_to_bytes(cue)
	var product_before := var_to_bytes(product)
	var view := node._spray_cue_draw_view(cue)
	check(view.is_empty(),"conservative overlapping visibility-triangle bounds reject the fan instead of bridging concealed interiors")
	# The lower spoke is geometrically clear, but its triangle AABB includes this
	# near product. That bounded false positive is intentional privacy policy.
	check(node._pov_point_visible(cue.spray_geometry.endpoints[4]),"rejection explicitly accepts conservative near-field false positives")
	var bounds: Array[Rect2] = node._spray_concealment_bounds()
	var stats := {"probes":0,"box_checks":0}
	check(not node._spray_spoke_visible(cue.start,cue.end,OBSERVER_POINT,bounds,stats),"whole-spoke chemical broadphase rejects actual concealed interior")
	equal(int(stats.probes),1,"chemical decision performs one endpoint probe, no length-dependent samples")
	equal(int(stats.box_checks),1,"one active product needs at most one box comparison per spoke")
	var grazing: Array[Rect2] = [Rect2(1280.0,1200.0,0.0001,0.0001)]
	stats = {"probes":0,"box_checks":0}
	check(not node._spray_spoke_visible(cue.start,cue.end,OBSERVER_POINT,grazing,stats),"closed AABB tangency rejects even a sub-pixel grazing bound without sample gaps")
	equal(var_to_bytes(cue),before,"chemical filtering leaves cached physical geometry unchanged")
	equal(var_to_bytes(product),product_before,"chemical visibility cannot mutate product state")
	# Steam no longer conceals in unified Hex policy; do not duplicate a stale
	# legacy recipe list in presentation or allocate concealment bounds for it.
	product.recipe_wire_id = HexProductEffects.STEAM
	var steam_view := node._spray_cue_draw_view(cue)
	check(not steam_view.is_empty() and not steam_view.spray_chemical_broadphase,"visible unified Steam follows the current effect contract")
	product.recipe_wire_id = 326
	node.world.tick = node.world.config.milliseconds_to_ticks(300)
	var off_band := node._spray_cue_draw_view(cue)
	check(not off_band.is_empty() and not off_band.spray_chemical_broadphase,"inactive Shadowdraft concealment band does not trigger broadphase")
	node.world.tick = 0
	product.recipe_wire_id = 315
	product.decay_tick = 0
	check(not node._spray_cue_draw_view(cue).spray_chemical_broadphase,"decayed concealment cannot retain stale masking cost")
	product.decay_tick = 600
	var local_cue := _ingested_spray(node,1,OBSERVER_POINT + Vector2(280,0))
	var local_view := node._spray_cue_draw_view(local_cue)
	check(not local_view.is_empty() and not local_view.spray_chemical_broadphase,"exact observer-origin cue uses valid endpoint-prefix fast path even with active chemistry")
	# Active but unrelated far coverage must not suppress remote Spray globally.
	product.coverage = {Vector2i(-8,-3):1}
	product.cells = {Vector2i(-8,-3):600}
	var far_view := node._spray_cue_draw_view(cue)
	check(not far_view.is_empty() and far_view.spray_chemical_broadphase,"far active concealer permits actual clear remote spokes")
	if not far_view.is_empty():
		equal(far_view.spray_visible_indices,PackedInt32Array([0,1,2,3,4]),"unrelated far product does not hide any of the five clear rays")
		check(int(far_view.spray_visibility_probes) <= 5 and int(far_view.spray_chemical_box_checks) <= 5*HexChemistryWorld.MAX_PRODUCTS,"work is bounded by five rays and finite active products, never pixel length")
	stats = {"probes":0,"box_checks":0}
	check(not node._spray_spoke_visible(OBSERVER_POINT,OBSERVER_POINT+Vector2(381,0),OBSERVER_POINT,[],stats),"over-budget geometry fails closed before any point query")
	equal(int(stats.probes),0,"invalid length cannot allocate any spoke visibility queries")
	node.free()


func _test_spray_observer_recheck_and_timing() -> void:
	var node := SpectatorHarness.new()
	check(_configure_spray_visibility(node),"Spray observer/timing fixture configures")
	var cue := _remote_spray(node)
	var before := var_to_bytes(cue)
	var timings: Array[Dictionary] = []
	# Small repeated-view diagnostic, deliberately no timing pass/fail threshold.
	# It measures helper CPU on the current host, not gameplay frame acceptance.
	for mode: String in ["ordinary","near-active-concealment","far-active-concealment"]:
		if mode != "ordinary":
			var product := _concealing_spray_product(node)
			if mode == "far-active-concealment":
				product.coverage = {Vector2i(-8,-3):1}
				product.cells = {Vector2i(-8,-3):600}
		var began := Time.get_ticks_usec()
		var probes := 0
		var admitted := 0
		for _iteration: int in range(20):
			var view := node._spray_cue_draw_view(cue)
			equal(view.is_empty(),mode == "near-active-concealment","repeated chemical broadphase preserves near fail-closed and far positive controls")
			if not view.is_empty(): admitted += 1
			probes += int(view.get("spray_visibility_probes",0))
		timings.append({"mode":mode,"iterations":20,"elapsed_usec":Time.get_ticks_usec()-began,"admitted_views":admitted,"admitted_view_spoke_point_probes":probes})
	print("DIAGNOSTIC Spray POV repeated-view timing (not performance acceptance): ",JSON.stringify(timings))
	var distant := PlayerState.new(3)
	_set_actor_point(distant,Vector2(2500,1000))
	node.world.players.append(distant)
	node.actor_motion_history.capture(node.world.players)
	node.world.player().health = 0
	node.follow_id = 2
	var caster_view := node._spray_cue_draw_view(cue)
	check(not caster_view.is_empty() and not caster_view.spray_chemical_broadphase,"following the rendered caster immediately enables observer-origin fast path")
	node.follow_id = 3
	check(node._spray_cue_draw_view(cue).is_empty(),"retained Spray is re-gated when the spectator moves beyond source visibility")
	node.follow_id = 2
	check(not node._spray_cue_draw_view(cue).is_empty(),"returning to the source re-admits current visible spokes without a stale observer cache")
	equal(var_to_bytes(cue),before,"repeated and changed-observer views never mutate retained cue geometry")
	node.free()


func _set_actor_point(actor: PlayerState, point: Vector2) -> void:
	actor.position_x = roundi(point.x * SimConfig.FIXED_SCALE)
	actor.position_y = roundi(point.y * SimConfig.FIXED_SCALE)
	actor.spawn_protection_ticks = 0
