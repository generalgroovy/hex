extends SceneTree
## Native production Bootstrap UI. Team scores, death and staging positions are
## explicit inspection fixtures, not earned/network/human gameplay evidence.
## Chemistry is a real finite two-Bolt paid demo; no product injection.

const BootstrapScene = preload("res://scenes/bootstrap/bootstrap.tscn")
const Card = preload("res://src/presentation/hex_demo_result_card.gd")
const Team = preload("res://src/presentation/team_match_presentation.gd")
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(960, 540)]
const EXPECTED_FRAMES := 48
const SOURCE_PATHS: Array[String] = [
	"res://tests/visual/capture_team_checkpoint.gd", "res://src/app/bootstrap.gd",
	"res://src/app/hex_playground_demo.gd", "res://src/presentation/hex_demo_result_card.gd",
	"res://src/presentation/team_match_presentation.gd", "res://src/presentation/session_round_label.gd",
	"res://src/net/session_round.gd", "res://src/net/session_charter.gd", "res://src/net/authoritative_session.gd",
	"res://src/app/wellspring_service_directory.gd", "res://src/presentation/wellspring_service_buildings.gd",
	"res://src/content/champion_catalog.gd", "res://src/app/character_weave_coordinator.gd",
	"res://src/presentation/cartoon_champion_presenter.gd",
]
const STAGED_POSITIONS: Array[Vector2i] = [
	Vector2i(2528_000, 1328_000), Vector2i(2704_000, 1168_000),
	Vector2i(2352_000, 1168_000), Vector2i(2704_000, 1344_000),
	Vector2i(2352_000, 1344_000), Vector2i(2528_000, 1168_000),
]

var output := ""
var game: Node2D
var fixture_session: AuthoritativeSession
var frames: Array[Dictionary] = []
var paid_demo_receipt: Dictionary = {}
var failed := false
var output_created := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.begins_with("res://.godot/team-checkpoint-native-") or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("fresh native res://.godot/team-checkpoint-native- output required")
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("cannot create native team-checkpoint capture output")
		return
	output_created = true
	root.size = SIZES[0]
	root.visible = true
	root.title = "H.E.X. native checkpoint | inspection fixtures"
	game = BootstrapScene.instantiate()
	game.preference_overrides_are_transient = true
	game.preferences_persistence_allowed = false
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.set_process_unhandled_input(false)
	game.preference_overrides_are_transient = true
	game.preferences_persistence_allowed = false
	game.application_input_active = true
	game.controls_input_guard_frames = 0
	if game.element_audio != null:
		game.element_audio.silence()
		game.element_audio.set_process(false)
	if game.world == null or game.world.hex_court == null or game.cartoon_champion_presenter.fullbody_art == null \
		or game.cartoon_champion_presenter.fullbody_art.pixel_pilot == null or not game.cartoon_champion_presenter.fullbody_art.pixel_pilot.full_cast:
		_fail("capture requires normal Wellspring and admitted --fullbody-art --pixel-cast rendering")
		return
	game.player_preferences.reduced_motion = false
	game.player_preferences.pov_mode = PlayerPreferences.POV_FULL
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for size: Vector2i in SIZES:
		root.size = size
		await process_frame
		await process_frame
		for profile_id: String in ["duos", "trios"]:
			if not _prepare_team_fixture(profile_id): return
			if not await _capture_both(profile_id + "-hearth", "team-Hearth-preview-visual-fixture"): return
			if not _begin_team_round(): return
			if not await _capture_both(profile_id + "-active-markers", "team-ACTIVE-staged-score-and-position-fixture"): return
			fixture_session.session_round.respawn_tick_by_entity[1] = game.world.tick + 216
			game.world.player(1).health = 0
			_sync()
			if not game._round_label().contains("YOU P1 RETURN IN 1.8s"):
				_fail("team respawn fixture lost its exact authoritative local clock")
				return
			if not await _capture_both(profile_id + "-active-respawn", "team-ACTIVE-staged-local-defeat-216-tick-respawn"): return
			# Select a valid 2:1 timeout; the real round transition owns RESULT,
			# winner, participant retirement and the retained final team totals.
			game.world.player(1).health = game.world.player(1).health_maximum
			fixture_session.session_round.respawn_tick_by_entity.clear()
			fixture_session.session_round.round_end_tick = game.world.tick
			fixture_session.advance_round([])
			_sync()
			if fixture_session.session_round.phase != SessionRound.Phase.RESULT or fixture_session.session_round.winner_team_id != 1 or not game._round_label().begins_with("AMBER WINS"):
				_fail("real team timeout transition failed to retain the selected Amber result")
				return
			if not await _capture_both(profile_id + "-result", "team-RESULT-real-timeout-transition-from-staged-score"): return
	for size: Vector2i in SIZES:
		root.size = size
		await process_frame
		await process_frame
		if not await _capture_farflow_directory(): return
	if not _prepare_paid_demo():
		_fail("paid demo fixture did not complete; a script error is not a successful capture")
		return
	for size: Vector2i in SIZES:
		root.size = size
		await process_frame
		await process_frame
		_sync()
		for expanded: bool in [false, true]:
			var label := "chemistry-result-hover" if expanded else "chemistry-result-compact"
			if not await _capture_both(label, "actual-paid-two-Bolt-result", expanded): return
	if frames.size() != EXPECTED_FRAMES:
		_fail("native capture count did not cover 32 team, eight Farflow directory and eight paid-result views")
		return
	var receipt := _receipt("captured")
	if not _write_receipt(receipt):
		_fail("cannot save native team-checkpoint receipt")
		return
	print("PASS team-checkpoint native frames=", frames.size(), " paid_casts=", paid_demo_receipt.get("paid_casts", 0))
	game.queue_free()
	await process_frame
	quit(0)


func _prepare_team_fixture(profile_id: String) -> bool:
	game.service_directory.close()
	game.controls_input_guard_frames = 0
	game.hex_playground_demo.cancel(null)
	game.hex_playground_demo.dismiss_result()
	game.world = game._new_wellspring_world(120)
	if game.world == null:
		_fail("team visual fixture could not create normal Wellspring")
		return false
	if not _prepare_fixture_local_identity(): return false
	var count := SessionCharter.required_players(profile_id)
	var peers: Array[Dictionary] = []
	for entity_id: int in range(2, count + 1):
		peers.append({"entity_id": entity_id, "name": "Traveller"})
	fixture_session = AuthoritativeSession.new()
	if not fixture_session.bind(game.world, game.champion_catalog, game.campus_layout.spawn, "Traveller", peers, profile_id):
		_fail("team visual fixture could not bind exact roster: " + fixture_session.last_error)
		return false
	if not game._prepare_active_character_pages():
		_fail("team visual fixture could not prepare the actual roster's admitted character art")
		return false
	game.authoritative_session = fixture_session
	game.selected_charter_id = profile_id
	game.session_transport.mode = SessionTransport.Mode.HOSTING
	game.session_transport.local_entity_id = 1
	game.session_transport.session_charter_id = profile_id
	game.session_transport.maximum_players = count
	game.session_names_by_entity = fixture_session.names_by_entity.duplicate()
	game.hex_playground_open = false
	game.station_notice = "VISUAL FIXTURE | exact roster, duplicate names, no network peers"
	game.station_notice_seconds = 20.0
	_arrange_fixture_actors(count)
	_sync()
	var hearth_label: String = game._session_label()
	if not hearth_label.contains("%d/%d REQUIRED" % [count, count]) or not hearth_label.contains("PREVIEW") or not hearth_label.contains("+ READY | - WAITING") or not hearth_label.contains("SHARED HAZARDS CAN HURT ALL"):
		_fail("Hearth preview omitted exact admission, provisional teams or shared-damage disclosure")
		return false
	return true


func _capture_farflow_directory() -> bool:
	if not _prepare_team_fixture("trios"): return false
	if not game._arrange_hearth_roster():
		_fail("Farflow visual fixture could not use the authored Hearth gathering positions")
		return false
	for entity_id: int in [1, 3, 6]:
		if not fixture_session.toggle_ready(entity_id):
			_fail("mixed Hearth readiness fixture refused an ordinary ready toggle")
			return false
	if not _open_directory_card("session-hearth"): return false
	var mixed := "\n".join(game.service_directory.selected_detail_lines())
	if not mixed.contains("P1+") or not mixed.contains("P2-") or not mixed.contains("+ READY | - WAITING") or not mixed.to_lower().contains("toggles ready"):
		_fail("actual Hearth directory did not display mixed readiness and the binding-aware ready action")
		return false
	if not await _capture_frame("farflow-hearth-mixed-ready-normal", "actual-Farflow-directory-mixed-readiness-fixture", false, false): return false
	for entity_id: int in [2, 4, 5]:
		if not fixture_session.toggle_ready(entity_id):
			_fail("Hearth countdown fixture could not ready its remaining participants")
			return false
	if not fixture_session.start_practice_countdown(1):
		_fail("actual exact-six all-ready authority refused the ordinary countdown")
		return false
	if not _open_directory_card("session-hearth"): return false
	var countdown := "\n".join(game.service_directory.selected_detail_lines())
	if not countdown.contains("IN 3.0s") or not countdown.contains("TEAMS LOCK AT START"):
		_fail("actual Hearth directory omitted the live countdown or lock-at-start guidance")
		return false
	if not await _capture_frame("farflow-hearth-countdown-normal", "actual-Farflow-directory-real-all-ready-countdown-fixture", false, false): return false
	game.session_transport.mode = SessionTransport.Mode.OFFLINE
	if not _open_directory_card("farflow-charter"): return false
	if not game.service_directory.selected_available() or not _charter_policy_visible(false):
		_fail("offline Charter directory did not expose its selected action and full five-row team policy")
		return false
	if not await _capture_frame("farflow-charter-offline-normal", "actual-Farflow-directory-selected-offline-Charter-fixture", false, false): return false
	game.session_transport.mode = SessionTransport.Mode.HOSTING
	if not _open_directory_card("farflow-charter"): return false
	if game.service_directory.selected_available() or not _charter_policy_visible(true):
		_fail("online sealed Charter lost its first-row disabled reason or five policy rows")
		return false
	if not await _capture_frame("farflow-charter-sealed-normal", "actual-Farflow-directory-sealed-online-Charter-fixture", false, false): return false
	game.service_directory.close()
	game.controls_input_guard_frames = 0
	return true


func _open_directory_card(station_id: String) -> bool:
	game.service_directory.close()
	game.requested_capture_reduced_effects = false
	game.station_notice = ""
	game.station_notice_seconds = 0.0
	game.focused_station_id = station_id
	# Use the production return-selection mechanism to choose the exact card,
	# including the deliberately disabled online Charter. Do not inject its text.
	game.directory_return_group = "farflow"
	game.directory_return_station = station_id
	_sync()
	game._open_focused_service_directory()
	game.service_directory.input_source = "keyboard"
	game.service_directory.details_visible = true
	game._update_service_directory(0.0)
	if not game.service_directory.is_open or game.service_directory.group_id != "farflow" or game.service_directory.selected_station_id() != station_id:
		_fail("actual Farflow directory did not open the requested station card")
		return false
	if game.service_directory.status_text.contains("\n") or game.service_directory.status_text != game._session_label().get_slice("\n", 0):
		_fail("Farflow directory status did not use only the actual first session-label row")
		return false
	return true


func _charter_policy_visible(sealed: bool) -> bool:
	var lines: Array[String] = game.service_directory.selected_detail_lines()
	var policy := Team.damage_policy_lines()
	if lines.size() != 6 or policy.size() != 5:
		return false
	if sealed:
		if lines[0] != game.service_directory.selected_disabled_reason(): return false
	elif not lines[0].to_lower().contains("turns to"):
		return false
	for index: int in policy.size():
		if lines[index + 1] != policy[index]: return false
	return true


func _begin_team_round() -> bool:
	if not fixture_session.begin_round(game.campus_layout.arena_definition):
		_fail("production team begin refused exact eligible roster")
		return false
	var round := fixture_session.session_round
	for entity_id: int in round.scores_by_entity:
		round.scores_by_entity[entity_id] = 0
	round.scores_by_entity[1] = 2
	round.scores_by_entity[2] = 1
	round.scores_by_team = {1: 2, 2: 1}
	_arrange_fixture_actors(SessionCharter.required_players(game.selected_charter_id))
	game.station_notice = "VISUAL FIXTURE | selected 2:1 score and inspection positions"
	_sync()
	var packet := round.capture(game.world)
	if not SessionRound.validate_packet(packet) or not game._round_label().contains("AMBER 2 | TEAL 1"):
		_fail("team ACTIVE fixture lost strict packet validity or actual team totals")
		return false
	var state := SessionRound.decoded(packet)
	for entity_id: int in round.scores_by_entity:
		var marker := Team.actor_marker(state, entity_id, 1)
		var expected_relation := "YOU" if entity_id == 1 else "ALLY" if int(round.team_by_entity[entity_id]) == 1 else "ENEMY"
		if String(marker.get("relation", "")) != expected_relation:
			_fail("team fixture did not expose YOU/ALLY/ENEMY identities")
			return false
	return true


func _arrange_fixture_actors(count: int) -> void:
	# Deliberate compact inspection staging, not an authored spawn/fairness test.
	for index: int in count:
		var actor: PlayerState = game.world.player(index + 1)
		var point := STAGED_POSITIONS[index]
		actor.position_x = point.x
		actor.position_y = point.y
		actor.position_remainder_x = 0
		actor.position_remainder_y = 0
		actor.velocity_x = 0
		actor.velocity_y = 0
		actor.aim_x = 0
		actor.aim_y = -1000
		actor.spawn_protection_ticks = 0


func _prepare_fixture_local_identity() -> bool:
	# _new_wellspring_world creates a bare simulation actor. Ordinary Bootstrap
	# applies the selected identity and remembered weave BEFORE session.bind;
	# bind initializes only the host team, but applies identities for new peers.
	var actor: PlayerState = game.world.player()
	if actor == null or not game.champion_catalog.apply_to_player(actor, game.selected_champion_id) \
		or not game.character_weaves.restore_actor(actor, true):
		_fail("fresh native fixture could not apply the ordinary selected champion and starting weave")
		return false
	if actor.champion_wire_id <= 0 or game._champion_visual_id(actor) != game.selected_champion_id or not actor.has_valid_spell_slots():
		_fail("fresh native fixture retained an anonymous or invalid local actor")
		return false
	return true


func _prepare_paid_demo() -> bool:
	game.service_directory.close()
	game.focused_station_id = ""
	game.expanded_station_id = ""
	game.directory_return_group = ""
	game.directory_return_station = ""
	game.hex_playground_demo.cancel(null)
	game.hex_playground_demo.dismiss_result()
	game.world = game._new_wellspring_world(120)
	if game.world == null:
		_fail("paid result fixture could not create ordinary Wellspring")
		return false
	if not _prepare_fixture_local_identity(): return false
	fixture_session = AuthoritativeSession.new()
	if not fixture_session.bind(game.world, game.champion_catalog, game.campus_layout.spawn, "Traveller"):
		_fail("paid result fixture could not bind ordinary Hearth authority")
		return false
	if not game._prepare_active_character_pages():
		_fail("paid result fixture could not prepare its actual local champion art")
		return false
	game.authoritative_session = fixture_session
	game.session_transport.mode = SessionTransport.Mode.OFFLINE
	game.session_transport.local_entity_id = 1
	game.selected_charter_id = SessionCharter.DEFAULT_ID
	game.hex_playground_open = false
	game.controls_input_guard_frames = 0
	game.application_input_active = true
	var actor: PlayerState = game.world.player()
	var water := int(game.ability_catalog.ability(game.ability_catalog.spell_id_at("water", "bolt")).wire_id)
	var fire := int(game.ability_catalog.ability(game.ability_catalog.spell_id_at("fire", "bolt")).wire_id)
	# Explicit starting weave fixture demonstrates restoration to non-loaner
	# positions and existing layer bindings. The demo itself changes none of it.
	if not actor.place_proven_spell(6, water) or not actor.place_proven_spell(11, fire):
		_fail("paid result fixture could not equip valid initial inspection weave")
		return false
	var saved_weave := actor.spell_wire_ids.duplicate()
	if not game.hex_playground_demo.begin(game.world, 1, "water", "fire", game.ability_catalog):
		_fail("ordinary paid demo refused: " + game.hex_playground_demo.status())
		return false
	for unused: int in 900:
		if not game.hex_playground_demo.is_active(): break
		var command: SimCommand = game.hex_playground_demo.command(game.world)
		if command == null: break
		var commands: Array[SimCommand] = [command]
		if not game.world.step(commands) or not game.world.hex_court.conservation_valid():
			_fail("real paid chemistry step or conservation failed")
			return false
	paid_demo_receipt = game.hex_playground_demo.terminal_result()
	if game.hex_playground_demo.is_active() or String(paid_demo_receipt.get("outcome", "")) != "complete" \
		or int(paid_demo_receipt.get("paid_casts", 0)) != 2 or int(paid_demo_receipt.get("paid_matter", 0)) != 1200 \
		or actor.spell_wire_ids != saved_weave or game._demo_result_view().is_empty():
		_fail("real paid result did not complete, restore weave and reach actual Bootstrap view")
		return false
	paid_demo_receipt["restored_weave"] = Array(saved_weave)
	paid_demo_receipt["champion_wire_id"] = actor.champion_wire_id
	paid_demo_receipt["champion_id"] = game._champion_visual_id(actor)
	paid_demo_receipt["matter_paid_metric"] = int(game.world.hex_court.metrics.matter_paid)
	paid_demo_receipt["world_hash_at_completion"] = game.world.state_hash()
	game.station_notice = "ACTUAL PAID DEMO | original weave restored; no reset after completion"
	game.station_notice_seconds = 20.0
	_sync()
	return true


func _sync() -> void:
	game.accumulator_seconds = 0.0
	game.current_position = game._player_position()
	game.previous_position = game.current_position
	game.previous_air_height = game.world.player().air_height
	game.session_round_values = fixture_session.session_round.capture(game.world)
	game.session_hearth_values = fixture_session.hearth.capture(game.world.tick, game.session_transport.player_capacity())
	game.combat_cues.clear()
	game._reset_motion_history()
	game.player_camera.clear()
	game.player_camera.advance(game.current_position, Vector2.ZERO, Vector2.UP, 1.0 / 120.0,
		Vector2(root.size), Rect2(Vector2.ZERO, Vector2(game.campus_layout.canvas_size)))


func _capture_both(label: String, kind: String, expanded: bool = false) -> bool:
	var before: String = game.world.state_hash()
	for reduced: bool in [false, true]:
		game.requested_capture_reduced_effects = reduced
		root.warp_mouse(Vector2(root.size.x - 64, 112) if expanded else Vector2(24, root.size.y - 160))
		await process_frame
		if kind == "actual-paid-two-Bolt-result":
			var view: Dictionary = game._demo_result_view()
			var placement := Card.layout(view, Vector2(root.size), root.get_mouse_position(), ThemeDB.fallback_font)
			if placement.is_empty() or bool(placement.expanded) != expanded or not bool(placement.content_fits):
				_fail("actual pointer did not select a fully fitting compact/hover result card")
				return false
		if not await _capture_frame(label + ("-reduced" if reduced else "-normal"), kind, reduced, expanded): return false
	if game.world.state_hash() != before:
		_fail("normal/reduced capture pair mutated authority")
		return false
	return true


func _capture_frame(label: String, kind: String, reduced: bool, expanded: bool) -> bool:
	var before: String = game.world.state_hash()
	var actor_render_identities: Array[Dictionary] = []
	for actor: PlayerState in game.world.players:
		if actor.actor_kind != PlayerState.ActorKind.CHAMPION: continue
		var champion_id: String = game._champion_visual_id(actor)
		if champion_id.is_empty() or actor.champion_wire_id <= 0 or actor.health < 0:
			_fail("native capture refused an anonymous or invalid actor: P%d" % actor.entity_id)
			return false
		if actor.health == 0:
			# Production intentionally hides the defeated body while its real
			# respawn clock remains visible. Identity is still mandatory above.
			actor_render_identities.append({"entity_id": actor.entity_id, "champion_wire_id": actor.champion_wire_id,
				"champion_id": champion_id, "visual_mode": "hidden", "hidden_reason": "defeated_health_zero",
				"health": 0, "component_count": 0})
			continue
		var frame: Dictionary = game.cartoon_champion_presenter.movement_frame(champion_id, actor,
			MinimalChampionMotion.tick_at_visual_rate(game.world.tick, game.tick_rate, 0.0), game.world.config, reduced)
		if frame.get("visual_mode", "") != "pixel_cast" or not bool(frame.get("pixel_body_pilot", false)) \
			or frame.get("components", []).is_empty():
			_fail("native capture refused an anonymous/fallback actor instead of its actual pixel skin: P%d" % actor.entity_id)
			return false
		var visible: bool = game._chemistry_actor_visible(actor)
		actor_render_identities.append({"entity_id": actor.entity_id, "champion_wire_id": actor.champion_wire_id,
			"champion_id": champion_id, "visual_mode": String(frame.visual_mode), "pixel_body_pilot": true,
			"component_count": frame.components.size(), "presentation_visible": visible,
			"hidden_reason": "" if visible else ("no_living_pov_observer" if game._pov_observer() == null else "outside_current_visibility")})
	var round_before := fixture_session.session_round.capture(game.world)
	var hearth_before := fixture_session.hearth.capture(game.world.tick, game.session_transport.player_capacity())
	var directory_before := _directory_view()
	var receipt_before: Dictionary = game.hex_playground_demo.terminal_result()
	var preferences_before: Dictionary = game.player_preferences.to_dictionary().duplicate(true)
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var capture: Image = root.get_texture().get_image()
	var size := root.size
	var path := output + "/" + label + "-%dx%d.png" % [size.x, size.y]
	if capture == null or capture.is_empty() or capture.get_size() != size or capture.save_png(path) != OK \
		or game.world.state_hash() != before or fixture_session.session_round.capture(game.world) != round_before \
		or fixture_session.hearth.capture(game.world.tick, game.session_transport.player_capacity()) != hearth_before or _directory_view() != directory_before \
		or game.hex_playground_demo.terminal_result() != receipt_before or game.player_preferences.to_dictionary() != preferences_before:
		_fail("native capture save/dimensions/read-only gate failed: " + label)
		return false
	var markers: Array[Dictionary] = []
	var state := SessionRound.decoded(round_before)
	for actor: PlayerState in game.world.players:
		var marker := Team.actor_marker(state, actor.entity_id, 1)
		if not marker.is_empty(): markers.append(marker)
	frames.append({"file": path.get_file(), "resource_path": path, "absolute_path": ProjectSettings.globalize_path(path),
		"sha256": FileAccess.get_sha256(path), "width": size.x, "height": size.y, "kind": kind,
		"reduced_effects": reduced, "expanded_result": expanded, "world_hash": before,
		"authority_hash": game.world.hex_court.state_hash(), "round_values": Array(round_before),
		"hearth_values": Array(hearth_before), "service_directory": directory_before,
		"session_label": game._session_label(), "round_label": game._round_label(), "actor_markers": markers,
		"actor_render_identities": actor_render_identities,
		"demo_result": HexChemistryWorld._stable(receipt_before), "pointer": [root.get_mouse_position().x, root.get_mouse_position().y]})
	return true


func _directory_view() -> Dictionary:
	var directory: WellspringServiceDirectory = game.service_directory
	return {"open": directory.is_open, "selected_station": directory.selected_station_id(),
		"details_visible": directory.details_visible, "status": directory.status_text,
		"available": directory.selected_available(), "disabled_reason": directory.selected_disabled_reason(),
		"detail_lines": directory.selected_detail_lines(),
		"selected_card_override": directory.card_overrides_by_station.get(directory.selected_station_id(), {}).duplicate(true)}


func _receipt(status: String, reason: String = "") -> Dictionary:
	var sources: Array[Dictionary] = []
	for path: String in SOURCE_PATHS:
		sources.append({"path": path, "sha256": FileAccess.get_sha256(path)})
	return {"schema": 1, "status": status, "failure_reason": reason, "frames": frames,
		"expected_frames": EXPECTED_FRAMES, "runtime_identity": JSON.parse_string(FileAccess.get_file_as_string(RuntimeBuildIdentity.MANIFEST_PATH)),
		"sources": sources, "display": {"server": DisplayServer.get_name(), "headless": false, "visible_window": root.visible},
		"paid_demo": HexChemistryWorld._stable(paid_demo_receipt),
		"scope": "actual production Bootstrap native team Hearth, ACTIVE markers/scoreboard/local respawn and RESULT; actual paid demo terminal card compact and pointer-hover; both viewports and effects settings; actual Farflow directory mixed ready/countdown/offline Charter/sealed Charter at both sizes in Normal effects",
		"directory_fixture_boundary": "real Farflow directory opening, root dynamic station text, exact-six mixed readiness and real all-ready countdown; selected Charter policy comes from actual offline/online rules; hosting is a transport-mode visual fixture without sockets",
		"team_fixture_boundary": "exact roster uses real AuthoritativeSession admission and SessionRound begin; score, death and positions are selected visual fixtures; real timeout transition selects retained result; no sockets or remote peers",
		"chemistry_boundary": "normal Wellspring, real HexPlaygroundDemo commands, real paid admissions and product, exact restored starting weave; no direct product injection or reset after completion",
		"limitations": "native captures and read-only assertions do not establish human readability, physical input, animation feel, performance, earned team scores or network acceptance",
		"human_acceptance": "NOT_RUN", "network_acceptance": "NOT_RUN", "profile_storage": "isolated APPDATA supplied by root engine owner"}


func _write_receipt(receipt: Dictionary) -> bool:
	var file := FileAccess.open(output + "/receipt.json", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(receipt, "\t") + "\n")
	file.close()
	return true


func _fail(reason: String) -> void:
	if failed: return
	failed = true
	if output_created and DirAccess.dir_exists_absolute(output):
		_write_receipt(_receipt("failed", reason))
	push_error(reason)
	quit(1)
