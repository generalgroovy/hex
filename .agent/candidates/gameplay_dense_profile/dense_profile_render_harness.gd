extends "res://tests/support/chemistry_coach_harness.gd"


const Workload = preload("res://tests/performance/dense_profile_workload.gd")

var last_draw_cpu_us := 0
var profiled_draw_count := 0


class EmptyCourtRenderer extends SanctumCampusRenderer:
	func draw(canvas: CanvasItem, _layout: SanctumCampusLayout, _presentation_tick: int, _focus_world_position: Vector2 = Vector2(-1000000.0, -1000000.0), _reduced_effects: bool = false) -> void:
		# Matched empty-map background for the ordinary comparator. Production
		# chemistry, projectiles, actors, HUD and cues remain in Bootstrap._draw.
		canvas.draw_rect(Rect2(0.0, 0.0, 1280.0, 960.0), Color("25331f"), true)


func configure_dense_profile(use_hex: bool, reduced: bool) -> bool:
	if not configure_fixture(true):
		return false
	var dense_world := Workload.create_world(use_hex, ability_catalog, champion_catalog)
	if dense_world == null:
		return false
	world = dense_world
	var empty_renderer := EmptyCourtRenderer.new()
	# Bootstrap also uses the campus renderer's configured natural actor kit
	# after drawing the backing. Keep those production dependencies intact.
	if not empty_renderer.configure(visual_language) or not empty_renderer.configure_campus(campus_layout):
		return false
	campus_renderer = empty_renderer
	player_preferences.reduced_motion = reduced
	authoritative_session = AuthoritativeSession.new()
	authoritative_session.world = world
	session_round_values = authoritative_session.session_round.capture(world)
	current_position = _player_position()
	previous_position = current_position
	previous_air_height = world.player().air_height
	accumulator_seconds = 0.0
	combat_cues.clear()
	_reset_motion_history()
	return world.is_valid()


func profile_sync_after_step() -> void:
	previous_position = current_position
	current_position = _player_position()
	previous_air_height = world.player().air_height
	actor_motion_history.capture(world.players)
	_update_combat_cues(1.0 / float(Workload.TICK_RATE))
	_ingest_combat_cues(world.combat_events)


func profile_prepare_render_frame() -> void:
	_update_character_gaits(float(Workload.SIM_TICKS_PER_RENDER_FRAME) / float(Workload.TICK_RATE))


func _draw() -> void:
	var started := Time.get_ticks_usec()
	super._draw()
	last_draw_cpu_us = Time.get_ticks_usec() - started
	profiled_draw_count += 1
