extends "res://tests/visual/capture_unified_wellspring.gd"
## Native production drawing with explicitly authored inspection fixtures.
## No network peers, physical input, paid knockout or human feel acceptance.

const CONTACT_PHASES := [0.14, 0.16, 0.34, 0.36, 0.64, 0.66, 0.84, 0.86]
const CONTACT_IDS := ["s_wayne", "oh_tipi", "red_baron"]
const ContactArt = preload("res://src/presentation/fullbody_cast_presenter.gd")
var fixture_session: AuthoritativeSession
var contact_board: ContactBoard


class ContactBoard:
	extends Node2D
	var presenter: CartoonChampionPresenter
	var config: SimConfig
	var states: Array[PlayerState] = []
	var reduced := false
	var invalid := false
	var checks := 0

	func authority_bytes() -> PackedByteArray:
		var values: Array = []
		for state: PlayerState in states: values.append(state.canonical_values())
		return var_to_bytes(values)

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 720), Color("263b35"))
		draw_string(ThemeDB.fallback_font, Vector2(26, 32), "H.E.X. | REGISTERED PIXEL CONTACT TIMING | %s" % ("REDUCED" if reduced else "NORMAL"), HORIZONTAL_ALIGNMENT_LEFT, 1228, 20, Color("f3d9a1"))
		draw_string(ThemeDB.fallback_font, Vector2(26, 57), "Inspection fixture: production pixel-cast presenter, explicit distance phases, native 1x pixels. Not a timed gameplay capture.", HORIZONTAL_ALIGNMENT_LEFT, 1228, 13, Color("d3dccc"))
		for column: int in CONTACT_PHASES.size():
			var x := 216.0 + float(column) * 132.0
			draw_string(ThemeDB.fallback_font, Vector2(x - 41, 99), "phase %.2f" % CONTACT_PHASES[column], HORIZONTAL_ALIGNMENT_LEFT, 105, 13, Color("f3d9a1"))
		for row: int in states.size():
			var y := 225.0 + float(row) * 186.0
			var id: String = CONTACT_IDS[row]
			var state: PlayerState = states[row]
			var label: String = ["S. Wayne / walk S", "Oh Tipi / sprint E", "Red Baron / cast SE"][row]
			draw_string(ThemeDB.fallback_font, Vector2(22, y - 43), label, HORIZONTAL_ALIGNMENT_LEFT, 183, 13, Color("f3d9a1"))
			draw_string(ThemeDB.fallback_font, Vector2(22, y - 20), ["forward", "backpedal", "sidestep + cast"][row], HORIZONTAL_ALIGNMENT_LEFT, 183, 12, Color("c6d0bc"))
			for column: int in CONTACT_PHASES.size():
				var x := 216.0 + float(column) * 132.0
				var before := state.canonical_values()
				var frame := presenter.movement_frame(id, state, 40.0, config, reduced, float(CONTACT_PHASES[column]))
				if frame.get("visual_mode") != "pixel_cast" or not frame.get("pixel_body_pilot", false) or frame.has("mesh") or frame.has("render_mesh") or state.canonical_values() != before:
					invalid = true
					continue
				draw_rect(Rect2(x - 62, y - 113, 124, 139), Color("31473e"))
				draw_line(Vector2(x - 45, y), Vector2(x + 45, y), Color("4b6052"), 1.0)
				ContactArt.draw_frame(self, frame, Vector2(x, y))
				var region: Rect2 = frame.components[0].source_region
				var selected_row := floori(region.position.y / 128.0)
				draw_string(ThemeDB.fallback_font, Vector2(x - 39, y + 21), "row %d / beat %.2f" % [selected_row, float(frame.sample_phase)], HORIZONTAL_ALIGNMENT_LEFT, 117, 10, Color("d3dccc"))
				checks += 1
		draw_string(ThemeDB.fallback_font, Vector2(26, 694), "Same approved art and registration. Contacts 5/16 each; neutral passes 3/16 each. Held jump keys and missing action art are not expanded.", HORIZONTAL_ALIGNMENT_LEFT, 1228, 12, Color("c6d0bc"))


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.begins_with("res://.godot/match-refinement-native-") or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("fresh native match-refinement output required")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("cannot create match-refinement capture output")
		return
	root.size = Vector2i(WIDTH, HEIGHT)
	root.visible = true
	game = BootstrapScene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.preference_overrides_are_transient = true
	game.preferences_persistence_allowed = false
	if game.element_audio != null:
		game.element_audio.silence()
		game.element_audio.set_process(false)
	if game.world == null or game.world.hex_court == null:
		_fail("production Wellspring world did not boot")
		return
	if game.cartoon_champion_presenter.fullbody_art == null or game.cartoon_champion_presenter.fullbody_art.pixel_pilot == null or not game.cartoon_champion_presenter.fullbody_art.pixel_pilot.full_cast:
		_fail("capture requires admitted --fullbody-art --pixel-cast production rendering")
		return
	if not _prepare_round_fixture(): return
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = size
		await process_frame
		await process_frame
		fixture_session.session_round.phase = SessionRound.Phase.ACTIVE
		fixture_session.session_round.round_end_tick = game.world.tick + 10_800
		fixture_session.session_round.respawn_tick_by_entity[1] = game.world.tick + 216
		game.world.player(1).health = 0
		_sync()
		if not game._round_label().contains("YOU P1 RETURN IN 1.8s"):
			_fail("active FFA fixture did not expose the exact local respawn clock")
			return
		if not await _capture_both("ffa-duplicate-names-respawn", "production-HUD-four-way-round-presentation-fixture"): return
		# Deliberately select a tied timeout boundary; the real round transition
		# computes DRAW and freezes/retire material. No paid knockout is claimed.
		for entity_id: int in fixture_session.session_round.scores_by_entity:
			fixture_session.session_round.scores_by_entity[entity_id] = 2
		fixture_session.session_round.round_end_tick = game.world.tick
		fixture_session.advance_round([])
		if fixture_session.session_round.phase != SessionRound.Phase.RESULT or fixture_session.session_round.winner_entity_id != 0 or not game._round_label().begins_with("DRAW"):
			_fail("real round lifecycle did not resolve the selected tie as DRAW")
			return
		_sync()
		if not await _capture_both("ffa-draw-result", "production-HUD-real-tied-timeout-transition-from-fixture"): return
	root.size = Vector2i(WIDTH, HEIGHT)
	await process_frame
	await process_frame
	game.visible = false
	if not _prepare_contact_board(): return
	if not await _capture_both("pixel-contact-boundaries", "production-pixel-cast-explicit-phase-inspection-board"): return
	if frames.size() != 10 or contact_board.invalid or contact_board.checks < 48:
		_fail("capture did not cover eight HUD frames and two complete native contact boards")
		return
	var receipt := FileAccess.open(output + "/receipt.json", FileAccess.WRITE)
	if receipt == null:
		_fail("cannot save match-refinement receipt")
		return
	receipt.store_string(JSON.stringify({
		"schema": 1, "status": "passed", "frames": frames,
		"runtime_identity": JSON.parse_string(FileAccess.get_file_as_string(RuntimeBuildIdentity.MANIFEST_PATH)),
		"display": {"server": DisplayServer.get_name(), "headless": false, "visible_window": root.visible},
		"contact_phases": CONTACT_PHASES, "contact_identities": CONTACT_IDS,
		"contact_board_checks": contact_board.checks,
		"scope": "native production Bootstrap HUD at1280x720 and960x540 with four admitted fixture participants, duplicate names, local1.8s respawn, and real tied-timeout RESULT; native production fixed-pixel three-size contact boards at eight explicit non-quarter phases; normal/reduced draw authority nonmutation",
		"limitations": "session transport hosting mode is a drawing fixture with no sockets or peers; scores/death/clock are selected fixture state, not earned gameplay; contact board is not motion timing, physical input, human feel, network, performance, or complete animation acceptance",
	}, "\t") + "\n")
	receipt.close()
	print("PASS match-refinement native frames=", frames.size(), " contact_checks=", contact_board.checks)
	quit(0)


func _prepare_round_fixture() -> bool:
	var actor: PlayerState = game.world.player()
	var spawn := Vector2i(roundi(float(actor.position_x) / SimConfig.FIXED_SCALE), roundi(float(actor.position_y) / SimConfig.FIXED_SCALE))
	fixture_session = AuthoritativeSession.new()
	var peers: Array[Dictionary] = [{"entity_id": 2, "name": "Traveller"}, {"entity_id": 3, "name": "Traveller"}, {"entity_id": 4, "name": "Traveller"}]
	if not fixture_session.bind(game.world, game.champion_catalog, spawn, "Traveller", peers, "sparring_circle") or not fixture_session.begin_round(game.campus_layout.arena_definition):
		_fail("four-way production round fixture refused: " + fixture_session.last_error)
		return false
	game.authoritative_session = fixture_session
	game.session_transport.mode = SessionTransport.Mode.HOSTING
	game.session_transport.local_entity_id = 1
	game.session_names_by_entity = fixture_session.names_by_entity.duplicate()
	game.station_notice = "INSPECTION FIXTURE | duplicate names, four participants, local respawn"
	game.station_notice_seconds = 20.0
	for entity_id: int in fixture_session.session_round.scores_by_entity:
		fixture_session.session_round.scores_by_entity[entity_id] = 2
		game.world.player(entity_id).spawn_protection_ticks = 0
	_sync()
	game.player_camera.clear()
	var focus: Vector2 = game._player_position()
	for index: int in 240:
		game.player_camera.advance(focus, Vector2.ZERO, Vector2.UP, 1.0 / 120.0, Vector2(WIDTH, HEIGHT), Rect2(Vector2.ZERO, Vector2(game.campus_layout.canvas_size)))
	return true


func _prepare_contact_board() -> bool:
	contact_board = ContactBoard.new()
	contact_board.presenter = game.cartoon_champion_presenter
	contact_board.config = game.world.config
	contact_board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for index: int in CONTACT_IDS.size():
		var state := PlayerState.new(9800 + index)
		if not game.champion_catalog.apply_to_player(state, CONTACT_IDS[index]):
			_fail("contact fixture cannot apply approved identity")
			return false
		var aim: Vector2i = EightDirectionResolver.FIXED_VECTORS[[0, 2, 1][index]]
		var travel: Vector2i = EightDirectionResolver.FIXED_VECTORS[[0, 6, 3][index]]
		state.aim_x = aim.x
		state.aim_y = aim.y
		state.velocity_x = travel.x * 200
		state.velocity_y = travel.y * 200
		state.movement_mode = PlayerState.MovementMode.WALK if index == 0 else PlayerState.MovementMode.SPRINT
		if index == 2: state.cast_recovery_ticks = 8
		contact_board.states.append(state)
	root.add_child(contact_board)
	return true


func _capture_both(label: String, kind: String) -> bool:
	var same_world: String = game.world.state_hash()
	var same_round := fixture_session.session_round.capture(game.world)
	for reduced: bool in [false, true]:
		game.requested_capture_reduced_effects = reduced
		if contact_board != null:
			contact_board.reduced = reduced
			contact_board.queue_redraw()
		if not await _capture_selected(label + ("-reduced" if reduced else "-normal"), kind, reduced): return false
	if game.world.state_hash() != same_world or fixture_session.session_round.capture(game.world) != same_round:
		_fail("normal/reduced comparison changed world or round authority")
		return false
	return true


func _capture_selected(label: String, kind: String, reduced: bool) -> bool:
	var before: String = game.world.state_hash()
	var round_before := fixture_session.session_round.capture(game.world)
	var contact_before := contact_board.authority_bytes() if contact_board != null else PackedByteArray()
	var size := root.size
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var resource_path := output + "/" + label + "-%dx%d.png" % [size.x, size.y]
	if image == null or image.is_empty() or image.get_size() != size or image.save_png(resource_path) != OK or game.world.state_hash() != before or fixture_session.session_round.capture(game.world) != round_before:
		_fail("native frame dimensions/save/authority failed: " + label)
		return false
	if contact_board != null and (contact_board.invalid or contact_board.authority_bytes() != contact_before):
		_fail("contact board left the fixed-pixel path or changed actor authority")
		return false
	frames.append({"file": resource_path.get_file(), "resource_path": resource_path,
		"absolute_path": ProjectSettings.globalize_path(resource_path), "sha256": FileAccess.get_sha256(resource_path),
		"width": size.x, "height": size.y, "kind": kind, "reduced_effects": reduced,
		"world_hash": before, "authority_hash": game.world.hex_court.state_hash(),
		"round_values": Array(round_before), "round_label": game._round_label(),
		"contact_authority_sha256": contact_before.hex_encode().sha256_text() if contact_board != null else "",
	})
	return true
