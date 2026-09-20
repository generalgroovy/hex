extends SceneTree


const Harness = preload("res://tests/support/chemistry_coach_harness.gd")
const SIZE := Vector2i(1280, 720)
const CHAMPIONS: Array[String] = ["s_wayne", "oh_tipi", "red_baron"]
var output := "res://.godot/awareness-tempo-render"
var node: Node2D
var viewport: SubViewport
var records: Array[Dictionary] = []


class ImpactBoard:
	extends Node2D
	var pixels := PixelSpellEffects.new()
	var age := 0
	var duration := 0
	var failures := 0

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color("182528"))
		label(Vector2(30, 42), "PRODUCTION FIRE / WATER TERMINAL CONTACT", 25)
		label(Vector2(30, 75), "Controlled age: %d / %d ticks at 120 Hz | production sample age: %d" % [age, duration, PixelSpellEffects.impact_sample_age(age)], 18)
		label(Vector2(30, 105), "Synthetic stationary contacts; actual PixelSpellEffects playback. No collision, damage or accepted-cast claim.", 15)
		pixels.library.begin_frame(false)
		for column: int in 2:
			var element: String = ["fire", "water"][column]
			var x := 320.0 + float(column) * 640.0
			label(Vector2(x - 70, 190), element.to_upper(), 25, pixels.material_color(element, 4))
			for row: int in 2:
				var center := Vector2(x, 300 + row * 235)
				draw_rect(Rect2(center - Vector2(230, 80), Vector2(460, 165)), Color("aaa58f") if row == 1 else Color("243733"))
				draw_set_transform(center, 0.0, Vector2.ONE * (4.0 if row == 1 else 1.0))
				if not pixels.impact(self, element, Vector2.ZERO, age, false, 10.8):
					failures += 1
				draw_set_transform(Vector2.ZERO)
				label(Vector2(x - 216, center.y + 72), "4x nearest diagnostic enlargement" if row == 1 else "100% native world size", 14)
		label(Vector2(30, 677), "1.5x duration, not speed: contact stays stationary; the exact expiry frame draws no fallback or lingering ghost.", 16)

	func label(at: Vector2, text: String, font_size: int, tint := Color("e9ddbc")) -> void:
		draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)


func _initialize() -> void:
	root.hide()
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if not output.begins_with("res://.godot/awareness-tempo-render") or ".." in output or DirAccess.dir_exists_absolute(output):
		fail("Provide a fresh awareness-tempo-render output; existing evidence is preserved")
		return
	node = Harness.new()
	if not node.configure_fixture(true) or DirAccess.make_dir_recursive_absolute(output) != OK:
		fail("Tempo production fixture could not configure")
		node.free()
		return
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(node)
	node.player_preferences.pov_mode = PlayerPreferences.POV_FULL
	var state: PlayerState = node.world.player()
	for champion_id: String in CHAMPIONS:
		if not node.champion_catalog.apply_to_player(state, champion_id):
			fail("Tempo fixture could not apply a real size identity")
			return
		node.selected_champion_id = champion_id
		state.reset_for_spawn(node.fixture_anchor + Vector2i(0, -100000))
		state.spawn_protection_ticks = 0
		node.actor_motion_history.clear()
		_sync(0.0)
		for unused: int in 24:
			if not _step_travel(false):
				return
		if state.movement_mode != PlayerState.MovementMode.WALK or state.velocity_x <= 0:
			fail("Walk capture requires actual eastward walk input")
			return
		var walk_speed := state.velocity_x
		var sprint_stamina_before := state.stamina
		var health_before := state.health
		var flux_before := state.flux
		if not await capture(champion_id + "-walk", {"kind": "actual_world_walk", "command_ticks": 24, "held_sprint": false, "stamina": state.stamina}):
			return
		for unused: int in 24:
			if not _step_travel(true):
				return
		if state.movement_mode != PlayerState.MovementMode.SPRINT or not state.sprinting or state.velocity_x <= walk_speed or state.stamina >= sprint_stamina_before or state.health != health_before or state.flux != flux_before:
			fail("Sprint must be faster, actually stamina-paid, and leave Health/Flux unchanged")
			return
		if not await capture(champion_id + "-paid-sprint", {"kind": "actual_world_paid_walk_to_sprint", "command_ticks": 24, "held_sprint": true, "walk_velocity_x": walk_speed, "stamina_before": sprint_stamina_before, "stamina_after": state.stamina, "stamina_paid": sprint_stamina_before - state.stamina, "health_unchanged": true, "flux_unchanged": true}):
			return
	node.hide()
	var board := ImpactBoard.new()
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not board.pixels.ready():
		fail("Production PixelSpellEffects must load validated assets")
		board.free()
		return
	var authored_duration := int(board.pixels.library.asset(PixelSpellEffects.asset_id("fire", "impact", false)).get("total_ticks", 0))
	board.duration = PixelSpellEffects.impact_duration_ticks(authored_duration)
	if authored_duration <= 0 or int(board.pixels.library.asset(PixelSpellEffects.asset_id("water", "impact", false)).get("total_ticks", 0)) != authored_duration:
		fail("The bounded paired impact board requires matching positive Fire/Water contact duration")
		board.free()
		return
	viewport.add_child(board)
	for age: int in [0, PixelSpellEffects.IMPACT_IMPRINT_TICKS, board.duration - 1, board.duration]:
		board.age = age
		var evidence: Array[Dictionary] = []
		for element: String in ["fire", "water"]:
			var model := board.pixels.impact_model(element, Vector2.ZERO, age, false, 10.8)
			var alive := not model.is_empty()
			if alive != (age < board.duration):
				fail("Impact must remain live until, and expire exactly at, the production duration")
				return
			evidence.append({"element": element, "alive": alive, "imprint_alive": alive and not model.get("imprint", {}).is_empty(), "source_sample_age": PixelSpellEffects.impact_sample_age(age)})
		board.queue_redraw()
		if not await capture("fire-water-contact-age-%02d" % age, {"kind": "synthetic_age_production_impact_renderer", "age_ticks": age, "authored_duration_ticks": authored_duration, "production_duration_ticks": board.duration, "elements": evidence}):
			return
		if board.failures != 0:
			fail("Production impact draw must handle both live and expired samples")
			return
	var receipt := FileAccess.open(output.path_join("capture-receipt.json"), FileAccess.WRITE)
	if receipt == null:
		fail("Tempo receipt could not be written")
		return
	receipt.store_string(JSON.stringify({"schema_version": 1, "frames": records, "size": [1280, 720], "movement": "real_simulation_commands_in_offline_production_fixture", "impacts": "synthetic_stationary_contact_ages_drawn_by_production_PixelSpellEffects_no_hit_claim", "impact_duration_multiplier": 1.5, "authority_unchanged_by_draw": true, "network": "not_started", "audio": "not_started", "preferences": "transient_fixture_only", "human_acceptance": "not_run"}, "  "))
	receipt.close()
	print("PASS: 10 frames; three actual paid walk-to-sprint transitions; production Fire/Water impact contact/imprint-end/last-live/expiry at controlled ages; world hash unchanged by every draw")
	quit(0)


func _step_travel(sprint: bool) -> bool:
	var state: PlayerState = node.world.player()
	var commands: Array[SimCommand] = [SimCommand.new(node.world.tick, state.entity_id, 1000, 0, SimCommand.HELD_SPRINT if sprint else 0, 0, 0, -1000)]
	if not node.world.step(commands):
		fail("Real walk/sprint simulation step failed")
		return false
	_sync(1.0 / 120.0)
	return true


func _sync(delta: float) -> void:
	var state: PlayerState = node.world.player()
	node.current_position = Vector2(state.position_x, state.position_y) / 1000.0
	node.previous_position = node.current_position
	node.previous_air_height = state.air_height
	node.actor_motion_history.capture(node.world.players)
	node._update_character_gaits(delta)


func capture(name: String, evidence: Dictionary) -> bool:
	var before: String = node.world.state_hash()
	node.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var pixels := viewport.get_texture().get_image()
	if pixels == null or pixels.get_size() != SIZE or pixels.save_png(output.path_join(name + ".png")) != OK or node.world.state_hash() != before:
		fail("Capture failed or changed canonical world state: " + name)
		return false
	var record := {"file": name + ".png", "world_hash": before}
	if String(evidence.get("kind", "")).begins_with("actual_world"):
		var state: PlayerState = node.world.player()
		var phase: float = node.actor_motion_history.gait_phase(state.entity_id)
		var frame: Dictionary = node.cartoon_champion_presenter.movement_frame(node.selected_champion_id, state, float(node.world.tick), node.world.config, false, phase)
		var expected_bank := "sprint" if state.sprinting else "walk"
		if frame.get("gait_bank", "") != expected_bank:
			fail("Real movement mode must select its corresponding production gait bank")
			return false
		record.merge({"champion": node.selected_champion_id, "tick": node.world.tick, "aim": [state.aim_x, state.aim_y], "velocity": [state.velocity_x, state.velocity_y], "gait_bank": frame.get("gait_bank"), "distance_phase": phase})
	record.merge(evidence)
	records.append(record)
	print("RENDERED ", output.path_join(name + ".png"))
	return true


func fail(message: String) -> void:
	push_error(message)
	quit(1)
