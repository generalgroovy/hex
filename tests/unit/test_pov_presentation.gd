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


func run() -> int:
	_test_single_mode_and_owned_body()
	_test_fixed_range_and_rotation_invariance()
	_test_remote_actor_and_chemistry_visibility()
	_test_hex_pillar_visibility()
	_test_interpolated_actor_uses_rendered_side_of_wall()
	_test_cue_endpoints_sources_and_hidden_actors()
	_test_ingested_lanes_bind_interpolated_caster()
	_test_character_cue_anchor_uses_rendered_position()
	_test_spectator_focus_regates_cues()
	_test_missing_observer_fails_closed()
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
			var expected := Vector2(fixed_polygon[index]) / SimConfig.FIXED_SCALE - Vector2(900, 900)
			check(screen_polygons[0][index].is_equal_approx(expected), "mask converts each exact fixed-point Hex vertex")
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


func _set_actor_point(actor: PlayerState, point: Vector2) -> void:
	actor.position_x = roundi(point.x * SimConfig.FIXED_SCALE)
	actor.position_y = roundi(point.y * SimConfig.FIXED_SCALE)
	actor.spawn_protection_ticks = 0
