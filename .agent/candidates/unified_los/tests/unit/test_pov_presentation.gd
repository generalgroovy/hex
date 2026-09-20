extends FluxTestSuite


const Harness = preload("res://tests/support/chemistry_coach_harness.gd")

class SpectatorHarness:
	extends "res://tests/support/chemistry_coach_harness.gd"
	var follow_id := 0
	func _is_spectating() -> bool:
		return follow_id > 0
	func _spectator_state() -> PlayerState:
		return world.player(follow_id) if follow_id > 0 else null


func run() -> int:
	_test_owned_sprite_overlay()
	_test_shared_rear_visibility()
	_test_hex_pillar_visibility()
	_test_spectator_overlay_owner()
	return finish("pov-presentation")


func _test_owned_sprite_overlay() -> void:
	var node := Harness.new()
	check(node.configure_fixture(true), "POV tests configure production body presentation")
	var state: PlayerState = node.world.player()
	for champion_id: String in ["s_wayne", "oh_tipi", "red_baron"]:
		check(node.champion_catalog.apply_to_player(state, champion_id), "POV uses actual size identity")
		state.spawn_protection_ticks = 0
		for aim: Vector2i in EightDirectionResolver.FIXED_VECTORS:
			state.aim_x = aim.x
			state.aim_y = aim.y
			for angle: int in [15, 120, 360]:
				node.player_preferences.pov_mode = PlayerPreferences.POV_CONE
				node.player_preferences.set_pov_angle_degrees(angle)
				for height: int in [0, 65000]:
					state.air_height = height
					state.movement_mode = PlayerState.MovementMode.IDLE if height == 0 else PlayerState.MovementMode.HOP
					node.previous_air_height = height
					var before := state.canonical_values()
					var overlay: Dictionary = node._pov_observer_overlay_frame(30.0, 0.0)
					check(not overlay.is_empty(), "own sprite has a body-only overlay for every heading, angle and jump height")
					equal(overlay.get("observer_id"), state.entity_id, "overlay belongs to the living viewpoint owner")
					var ordinary := node.cartoon_champion_presenter.movement_frame(champion_id, state, 30.0, node.world.config, false, 0.0)
					equal(overlay.get("source_region"), ordinary.get("source_region"), "postmask body uses exactly the ordinary animation cell")
					equal(overlay.get("texture"), ordinary.get("texture"), "postmask body uses the same corresponding size texture")
					var jump := JumpPresentation.sample(state, node.world.config, 0.0, false, height)
					var expected := node.current_position + Vector2(0, float(MovementTuning.PLAYER_RADIUS) / 1000.0 * 0.58 - jump.body_lift_pixels) + (ordinary["offset"] as Vector2) - CartoonChampionPresenter.PIVOT
					equal((overlay["destination"] as Rect2).position, expected, "raised body placement stays exact without growing a mask hole")
					equal(state.canonical_values(), before, "overlay queries never change jump, visibility, collision or combat authority")
	node.player_preferences.pov_mode = PlayerPreferences.POV_FULL
	check(node._pov_observer_overlay_frame(0.0, 0.0).is_empty(), "default full view adds no redundant overlay")
	node.player_preferences.pov_mode = PlayerPreferences.POV_CONE
	state.health = 0
	check(node._pov_observer_overlay_frame(0.0, 0.0).is_empty(), "dead local body is not resurrected above the mask")
	node.free()


func _test_shared_rear_visibility() -> void:
	var node := Harness.new()
	check(node.configure_fixture(), "rear visibility fixture configures without rendering")
	var observer: PlayerState = node.world.player()
	observer.position_x = 1000000
	observer.position_y = 1000000
	observer.aim_x = 1000
	observer.aim_y = 0
	node.current_position = Vector2(1000, 1000)
	node.previous_position = node.current_position
	node.player_preferences.pov_mode = PlayerPreferences.POV_CONE
	node.player_preferences.set_pov_angle_degrees(15)
	var target := PlayerState.new(2)
	target.position_x = 930000
	target.position_y = 1000000
	node.world.players.append(target)
	var original_buildings: Array = node.campus_layout.data["buildings"]
	node.campus_layout.data["buildings"] = []
	check(node._chemistry_actor_visible(target), "near rear target is visible in clear space")
	node.campus_layout.data["buildings"] = [{"bounds": [955, 990, 10, 20], "occlusion_policy": "los_cutaway"}]
	check(not node._chemistry_actor_visible(target), "the shared actor predicate hides a target behind near opaque rear cover")
	target.chemistry_reveal_ticks = 2
	check(not node._chemistry_actor_visible(target), "chemical reveal cannot turn rear awareness into a wall reveal")
	target.chemistry_reveal_ticks = 0
	node.campus_layout.data["buildings"] = [{"bounds": [955, 990, 10, 20], "occlusion_policy": "low_never_occludes"}]
	check(node._chemistry_actor_visible(target), "authored low cover keeps its existing non-occluding policy")
	var steam := ElementReactionState.new()
	steam.recipe_wire_id = 310
	steam.position_x = 965000
	steam.position_y = 1000000
	steam.origin_x = steam.position_x
	steam.origin_y = steam.position_y
	steam.radius = 30000
	steam.active_tick = 0
	steam.decay_tick = 100
	steam.expiry_tick = 120
	node.world.reactions.append(steam)
	check(not node._chemistry_actor_visible(target), "rear awareness does not bypass existing Steam concealment beyond its64px grace")
	target.chemistry_reveal_ticks = 2
	check(node._chemistry_actor_visible(target), "authoritative chemical reveal still defeats chemistry when opaque LOS is clear")
	node.campus_layout.data["buildings"] = original_buildings
	node.player_preferences.pov_mode = PlayerPreferences.POV_FULL
	check(node._chemistry_actor_visible(target), "full-view mode preserves its prior chemistry-reveal behavior")
	node.free()


func _test_hex_pillar_visibility() -> void:
	var node := Harness.new()
	check(node.configure_fixture(), "Hex POV fixture configures without rendering")
	var observer: PlayerState = node.world.player()
	observer.position_x = 1_000_000
	observer.position_y = 1_000_000
	observer.aim_x = -1000
	observer.aim_y = 0
	node.current_position = Vector2(1000, 1000)
	node.previous_position = node.current_position
	node.player_preferences.pov_mode = PlayerPreferences.POV_CONE
	node.player_preferences.set_pov_angle_degrees(360)
	var target := PlayerState.new(2)
	target.position_x = 930_000
	target.position_y = 1_000_000
	node.world.players.append(target)
	var original_buildings: Array = node.campus_layout.data["buildings"]
	node.campus_layout.data["buildings"] = []
	var base: CollisionWorld = node.world.collision
	base.add_obstacle(CollisionWorld.Obstacle.new(999_001, 960_000, 990_000, 970_000, 1_010_000))
	var collision := HexCollisionWorld.new(base)
	var pillar_origin := Vector2i(965_000, 1_000_000)
	var topology := HexGrid.disk(Vector2i.ZERO, 1)
	check(collision.configure_hexes(pillar_origin, topology, []), "POV begins with trusted empty Hex topology")
	node.world.collision = collision
	node.world.reaction_movement = collision
	check(node._chemistry_actor_visible(target), "physical low cover does not become opaque through the combined collision query")
	equal(node._pov_hex_occluder_polygons(Vector2(900, 900)), [], "empty Hex topology contributes no mask polygon")
	check(collision.configure_hexes(pillar_origin, topology, [Vector2i.ZERO]), "POV activates one physical six-face pillar")
	check(not node._chemistry_actor_visible(target), "active pillar hides an actor on its far side")
	target.chemistry_reveal_ticks = 2
	check(not node._chemistry_actor_visible(target), "chemical reveal cannot bypass an opaque physical pillar")
	target.chemistry_reveal_ticks = 0
	var screen_polygons: Array[PackedVector2Array] = node._pov_hex_occluder_polygons(Vector2(900, 900))
	equal(screen_polygons.size(), 1, "active pillar contributes one screen-space occluder")
	if screen_polygons.size() == 1:
		equal(screen_polygons[0].size(), 6, "screen-space pillar retains all six physical faces")
		var fixed_polygon: Array = collision.hex_occluders()[0]
		for index: int in range(6):
			var expected := Vector2(fixed_polygon[index]) / SimConfig.FIXED_SCALE - Vector2(900, 900)
			check(screen_polygons[0][index].is_equal_approx(expected), "POV mask converts each exact fixed-point vertex")
	node.player_preferences.set_camera_zoom_percent(75)
	var reduced_polygons: Array[PackedVector2Array] = node._pov_hex_occluder_polygons(Vector2(900, 900))
	if screen_polygons.size() == 1 and reduced_polygons.size() == 1:
		for index: int in range(6):
			check(reduced_polygons[0][index].is_equal_approx(screen_polygons[0][index] * 0.75), "camera zoom scales the same exact pillar polygon")
	observer.position_x = pillar_origin.x + 31_000
	observer.position_y = pillar_origin.y - 35_000
	target.position_x = pillar_origin.x + 31_000
	target.position_y = pillar_origin.y - 30_000
	node.current_position = Vector2(observer.position_x, observer.position_y) / SimConfig.FIXED_SCALE
	node.previous_position = node.current_position
	check(node._chemistry_actor_visible(target), "actor ray through an empty AABB corner remains visible outside the Hex triangle")
	observer.position_x = 1_000_000
	observer.position_y = 1_000_000
	target.position_x = 930_000
	target.position_y = 1_000_000
	node.current_position = Vector2(1000, 1000)
	node.previous_position = node.current_position
	check(not node._chemistry_actor_visible(target), "active pillar still blocks the original ray before removal")
	check(collision.configure_hexes(pillar_origin, topology, []), "POV destroys or expires the active pillar")
	check(node._chemistry_actor_visible(target), "destruction or expiry restores actor visibility")
	equal(node._pov_hex_occluder_polygons(Vector2(900, 900)), [], "destruction or expiry removes the mask polygon immediately")
	node.campus_layout.data["buildings"] = original_buildings
	node.free()


func _test_spectator_overlay_owner() -> void:
	var node := SpectatorHarness.new()
	check(node.configure_fixture(true), "spectator overlay fixture configures")
	var local: PlayerState = node.world.player()
	local.health = 0
	var followed := PlayerState.new(2)
	check(node.champion_catalog.apply_to_player(followed, "red_baron"), "spectator follows a real large body")
	followed.position_x = local.position_x + 50000
	followed.position_y = local.position_y
	node.world.players.append(followed)
	node.actor_motion_history.capture(node.world.players)
	node.follow_id = 2
	node.player_preferences.pov_mode = PlayerPreferences.POV_CONE
	var overlay: Dictionary = node._pov_observer_overlay_frame(0.0, 0.0)
	equal(overlay.get("observer_id"), 2, "only the followed actor owns the spectator mask exemption")
	followed.health = 0
	check(node._pov_observer_overlay_frame(0.0, 0.0).is_empty(), "dead followed actor is not repainted as a live visible character")
	node.free()
