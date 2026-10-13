extends SceneTree
## Instrumented real Bootstrap lifecycle, not physical-input or FPS evidence.
const Scene = preload("res://scenes/bootstrap/bootstrap.tscn")
const Before = preload("res://.godot/iteration-20261013/terrain-before/src/presentation/wellspring_terrain_stream.gd")
const After = preload("res://src/presentation/wellspring_terrain_stream.gd")
const Snapshot = preload("res://src/net/hex_world_snapshot.gd")
const Weaves = preload("res://src/app/character_weave_library.gd")
const Progression = preload("res://src/app/signature_progression.gd")
const BEFORE_SHA := "83c1ee7a896ca60a92f2b691c9c7cfd54faff32fffdc33d84181e38ccdcdf0ca"
const STEP_DELTA := 1.0 / 60.0
const ROUTE_TICKS := 480
const MAX_PROCESS_ROWS := 1800
const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down", &"sprint", &"slide", &"jump", &"evade"]
const SAVES := [PlayerPreferences.DEFAULT_PATH, PlayerPreferences.DEFAULT_PATH + PlayerPreferences.PRE_FOUR_DELIVERY_BACKUP_SUFFIX,
	PlayerPreferences.DEFAULT_PATH + PlayerPreferences.PRE_S4_CONTROLS_BACKUP_SUFFIX,
	Weaves.DEFAULT_PATH, Weaves.DEFAULT_PATH + Weaves.BACKUP_SUFFIX,
	Progression.DEFAULT_PATH, Progression.DEFAULT_PATH + Progression.BACKUP_SUFFIX, Progression.DEFAULT_PATH + Progression.ROLLING_SUFFIX]
const WATCH := ["res://.godot/iteration-20261013/compare-bootstrap-terrain-walk.gd",
	"res://.godot/iteration-20261013/terrain-before/src/presentation/wellspring_terrain_stream.gd",
	"res://src/presentation/wellspring_terrain_stream.gd", "res://src/presentation/wellspring_illustrated_kit.gd",
	"res://src/presentation/sanctum_campus_renderer.gd", "res://src/presentation/player_camera_rig.gd",
	"res://src/app/bootstrap.gd", "res://src/app/input_router.gd", "res://src/app/local_navigation_controller.gd",
	"res://src/app/element_garden_exhibition.gd", "res://src/app/element_garden_court.gd",
	"res://src/presentation/element_garden_presenter.gd", "res://src/presentation/element_garden_surface.gd",
	"res://src/sim/core/sim_world.gd", "res://src/sim/core/sim_config.gd", "res://src/sim/movement/movement_system.gd",
	"res://content/maps/sanctum_campus_g2_v1.json", "res://assets/environment/wellspring_ground_v1/manifest.tres",
	"res://scenes/bootstrap/bootstrap.tscn"]

class ProofGame extends "res://src/app/bootstrap.gd":
	var harness: SceneTree
	var variant := ""
	var route_direction := 1
	var phase := "boot"
	var injection := {}
	var route_start_tick := -1
	var command_rows: Array[Dictionary] = []
	var step_rows: Array[Dictionary] = []
	var process_rows: Array[Dictionary] = []
	var first_ready := {}
	var held_actions: Dictionary[StringName, bool] = {}
	var route_start_actor: Array = []
	var initial_stamina := -1
	var minimum_stamina := 2147483647
	var seen_sprint := false
	var seen_air := false
	var seen_slide := false
	var seen_evade := false
	var paid_events: Dictionary[String, int] = {}
	var preparation_errors: Array[String] = []
	var injection_ok := false
	var first_parent_process := true
	var synthetic_application_focus := false

	func _ready() -> void:
		super._ready()
		if world == null or campus_renderer == null or campus_renderer.illustrated_kit == null:
			harness._fail("Inherited Bootstrap setup did not create the actual world and terrain kit.")
			return
		var kit: WellspringIllustratedKit = campus_renderer.illustrated_kit
		var original: RefCounted = kit.terrain_stream
		if original == null or not original.pending.is_empty() or not original.queue.is_empty() or not original.textures.is_empty() or int(original.requests) != 0 or int(original.uploads) != 0:
			harness._fail("Stream injection must precede every request/upload and own no pending work.")
			return
		var chosen: RefCounted = Before.new() if variant == "before" else After.new()
		var manifest: Resource = load(After.MANIFEST)
		if manifest == null or not chosen.configure(manifest.get("descriptor"), kit.bake_signature, campus_layout.canvas_size):
			harness._fail("Concrete stream configuration failed before injection.")
			return
		original.finish_shutdown()
		if not bool(original.closed) or not original.pending.is_empty():
			harness._fail("Unused original stream did not close cleanly.")
			return
		kit.terrain_stream = chosen
		kit.ground_chunks = chosen.textures
		kit.ground_chunk_order = chosen.order
		kit._sync_terrain_stats()
		injection = {"when": "after inherited _ready, before first inherited _process/request", "world_tick": world.tick,
			"original_closed": original.closed, "original_pending": original.pending.size(), "chosen_status": chosen.status(),
			"bake_signature": kit.bake_signature, "texture_alias": is_same(kit.ground_chunks, chosen.textures),
			"order_alias": is_same(kit.ground_chunk_order, chosen.order), "cache_bytes": kit.ground_cache_bytes,
			"builds": kit.ground_chunk_builds, "hits": kit.ground_chunk_hits}
		injection_ok = bool(injection.texture_alias) and bool(injection.order_alias) and kit.ground_cache_bytes == 0 and kit.ground_chunk_builds == 0
		if not injection_ok: harness._fail("Kit aliases/counters do not match the injected idle owner.")

	func _process(real_delta: float) -> void:
		if not injection_ok: return
		if first_parent_process:
			first_parent_process = false
			if int(campus_renderer.illustrated_kit.terrain_stream.requests) != 0:
				harness._fail("An unseen request preceded the first observed callback.")
				return
		var start_usec := Time.get_ticks_usec()
		var tick_before := world.tick
		var phase_before := phase
		var position_before := Vector2i(_local_player_state().position_x, _local_player_state().position_y)
		var resources_before: Array[int] = [_local_player_state().health, _local_player_state().flux, _local_player_state().stamina]
		var was_loading := _area_loading()
		var application_gate_before_override := application_input_active
		if synthetic_application_focus:
			# Explicit fixture-only admission to the normal input path. Do not
			# alter modal/loading guards, quarantine, commands, timers or focus.
			application_input_active = true
		super._process(STEP_DELTA)
		var end_usec := Time.get_ticks_usec()
		if phase_before not in ["arrival", "route"]: return
		var terrain: Dictionary = campus_renderer.terrain_status()
		var actor: PlayerState = _local_player_state()
		var origin: Vector2 = _camera_origin(_camera_focus_position(current_position))
		var row := {"process": process_rows.size(), "phase": phase_before, "real_callback_delta": real_delta,
			"declared_delta": STEP_DELTA, "started_usec": start_usec, "parent_process_usec": end_usec-start_usec,
			"tick_before": tick_before, "tick_after": world.tick, "was_loading": was_loading, "area_loading": _area_loading(),
			"terrain_loading": terrain_loading, "garden_pending": element_garden_arrival_pending,
			"position_before": [position_before.x,position_before.y], "position_after": [actor.position_x,actor.position_y],
			"resources_before": resources_before, "resources_after": [actor.health,actor.flux,actor.stamina],
			"application_input_active": application_input_active, "application_gate_before_override":application_gate_before_override,
			"synthetic_application_focus":synthetic_application_focus,"window_focused": get_window().has_focus(),
			"input_guard": controls_input_guard_frames, "quarantined": Array(input_router.quarantined_actions.keys()),
			"view": [origin.x,origin.y,get_viewport_rect().size.x/_camera_zoom_scale(),get_viewport_rect().size.y/_camera_zoom_scale()],
			"terrain": terrain, "movement_event": actor.last_event}
		process_rows.append(row)
		if first_ready.is_empty() and not _area_loading(): first_ready = row.duplicate(true)
		if not terrain_loading_error.is_empty() or not element_garden_arrival_error.is_empty() or not String(terrain.get("error", "")).is_empty():
			harness._fail("Actual arrival/walking reported a terrain or Garden preparation failure.")
			return
		if _area_loading() and (world.tick != tick_before or Vector2i(actor.position_x,actor.position_y) != position_before or resources_before != [actor.health,actor.flux,actor.stamina]):
			harness._fail("Existing offline loading guard did not freeze authority/resources.")
			return
		if process_rows.size() > MAX_PROCESS_ROWS:
			harness._fail("Arrival/traversal exceeded the finite process-observation bound.")
			return
		if route_start_tick >= 0 and world.tick >= route_start_tick + ROUTE_TICKS:
			phase = "endpoint"
			release_fixture_actions()
			set_process(false)
			harness._route_finished.call_deferred()

	func _sample_gameplay_command(tick: int, player_position: Vector2, pointer_position: Vector2, controls_blocking: bool) -> SimCommand:
		if phase not in ["arrival", "route"]:
			return super._sample_gameplay_command(tick, player_position, pointer_position, controls_blocking)
		if controls_blocking or not application_input_active:
			return super._sample_gameplay_command(tick, player_position, pointer_position, controls_blocking)
		if route_start_tick < 0:
			route_start_tick = tick
			phase = "route"
			route_start_actor = Array(_local_player_state().canonical_values())
			initial_stamina = _local_player_state().stamina
		var relative := tick - route_start_tick
		if relative >= ROUTE_TICKS:
			harness._fail("A callback attempted more than the exact480 route commands.")
			return super._sample_gameplay_command(tick,player_position,pointer_position,true)
		# Synthetic action state drives the actual router. It follows successful
		# simulation ticks, so presses wait through stalls; this is not human input.
		var requested: Dictionary[StringName, bool] = {&"move_left":route_direction < 0, &"move_right":route_direction > 0,
			&"move_up":false, &"move_down":false, &"sprint":relative >= 8 and relative < 48,
			&"slide":relative == 48, &"jump":relative == 53, &"evade":relative == 63}
		for action: StringName in ACTIONS:
			var down: bool = bool(requested[action])
			if down != bool(held_actions.get(action,false)):
				if down: Input.action_press(action)
				else: Input.action_release(action)
				held_actions[action] = down
		var result: SimCommand = super._sample_gameplay_command(tick, player_position, player_position+Vector2(route_direction*100,0), controls_blocking)
		command_rows.append({"relative_tick":relative,"tick":tick,"entity_id":result.entity_id,"move_x":result.move_x,"move_y":result.move_y,
			"held":result.held_actions,"pressed":result.pressed_actions,"aim_x":result.aim_x,"aim_y":result.aim_y,
			"target_x":result.aim_target_x,"target_y":result.aim_target_y,"requested":requested.duplicate(),
			"quarantined":Array(input_router.quarantined_actions.keys())})
		return result

	func _ingest_combat_cues(events: Array[Dictionary]) -> void:
		super._ingest_combat_cues(events)
		if phase != "route" or route_start_tick < 0: return
		var actor: PlayerState = _local_player_state()
		minimum_stamina = mini(minimum_stamina,actor.stamina)
		seen_sprint = seen_sprint or actor.sprinting
		seen_air = seen_air or actor.is_airborne()
		seen_slide = seen_slide or actor.last_event == "slide"
		seen_evade = seen_evade or actor.last_event in ["air_dodge", "roll"]
		if actor.last_event in ["slide", "slide_jump", "hop", "air_dodge", "roll"]:
			paid_events[actor.last_event] = int(paid_events.get(actor.last_event,0)) + 1
		step_rows.append({"relative_tick":world.tick-route_start_tick,"position":[actor.position_x,actor.position_y],
			"stamina":actor.stamina,"flux":actor.flux,"health":actor.health,"air_height":actor.air_height,
			"last_event":actor.last_event,"sprinting":actor.sprinting,"chain":actor.movement_chain_count})

	func release_fixture_actions() -> void:
		for action: StringName in ACTIONS: Input.action_release(action)
		held_actions.clear()

	func _exit_tree() -> void:
		release_fixture_actions()
		super._exit_tree()
		if harness != null:
			harness._closed(campus_renderer.terrain_status() if campus_renderer != null else {})

var role := ""
var destination := ""
var output := ""
var isolated_data := ""
var game: ProofGame
var source_hashes := {}
var saved_after_boot := {}
var initial_packet := {}
var endpoint := {}
var navigation := {}
var peer_comparison := {}
var compare_path := ""
var checks := 0
var failure := ""
var closing := false
var output_created := false
var closed := false
var synthetic_application_focus := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--arm="): role=arg.trim_prefix("--arm=")
		if arg.begins_with("--destination="): destination=arg.trim_prefix("--destination=")
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--fixture-user-data="): isolated_data=arg.trim_prefix("--fixture-user-data=")
		if arg.begins_with("--compare="): compare_path=arg.trim_prefix("--compare=")
		if arg=="--synthetic-application-focus": synthetic_application_focus=true
	var allowed := ProjectSettings.globalize_path("res://.godot/iteration-20261013/").replace("\\","/").simplify_path().trim_suffix("/") + "/"
	var actual := OS.get_user_data_dir().replace("\\","/").simplify_path().trim_suffix("/")
	var expected := isolated_data.replace("\\","/").simplify_path().trim_suffix("/")
	if role not in ["before","after"] or destination not in ["element-garden","verdant"] or DisplayServer.get_name()=="headless" or actual.to_lower()!=expected.to_lower() or not actual.to_lower().begins_with(allowed.to_lower()):
		_fail("Require native before/after arm, authored destination, and exact isolated user data path."); return
	if not OS.get_cmdline_user_args().has("--no-lan-discovery") or not OS.get_cmdline_user_args().has("--champion=oh_tipi"):
		_fail("Require --no-lan-discovery and --champion=oh_tipi."); return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-") or arg.begins_with("--farflow-") or arg in ["--hex-court","--interception-trial","--retained-campus"]:
			_fail("No authority/render capture or network-mode overrides are admitted."); return
	if not output.begins_with("res://.godot/iteration-20261013/bootstrap-terrain-walk-") or ".." in output or DirAccess.dir_exists_absolute(output):
		_fail("Require fresh owned bootstrap-terrain-walk-* output."); return
	for path: String in SAVES:
		if FileAccess.file_exists(path): _fail("Fresh isolated profile required: "+path); return
	if DirAccess.make_dir_recursive_absolute(output)!=OK: _fail("Cannot create owned output."); return
	output_created=true
	for path: String in WATCH:
		source_hashes[path]=FileAccess.get_sha256(path)
		if String(source_hashes[path]).length()!=64: _fail("Missing watched source: "+path); return
	if not _check(FileAccess.get_sha256(WATCH[1])==BEFORE_SHA,"Concrete predecessor bytes match preserved terrain-before."): return
	root.size=Vector2i(1280,720)
	root.mode=Window.MODE_WINDOWED
	root.show()
	create_timer(180.0).timeout.connect(func(): _fail("Bootstrap traversal watchdog exceeded180 seconds."))
	var instance: Node=Scene.instantiate()
	instance.set_script(ProofGame)
	game=instance as ProofGame
	game.harness=self
	game.variant=role
	game.synthetic_application_focus=synthetic_application_focus
	game.route_direction=-1 if destination=="element-garden" else 1
	root.add_child(game)
	for unused: int in 1800:
		await process_frame
		if closing: return
		if game.injection_ok and game.world!=null and game._character_pages_ready and not game._area_loading() and bool(game.local_navigation.travel_availability().enabled): break
	if not _check(game.injection_ok and game.world!=null and game._character_pages_ready and not game._area_loading() and bool(game.local_navigation.travel_availability().enabled),"Actual boot reaches ordinary travel readiness."): return
	game.set_process(false)
	if not _check(game.session_transport.mode==SessionTransport.Mode.OFFLINE and game.tick_rate==120,"Actual route uses ordinary offline120Hz authority."): return
	if not _check(game.player_preferences.movement_reference==PlayerPreferences.MOVEMENT_WORLD_RELATIVE,"Fresh profile uses authored world-relative movement."): return
	for path: String in SAVES: saved_after_boot[path]=_hash(path)
	var actor: PlayerState=game._local_player_state()
	var dest: Dictionary=game.campus_layout.travel_destination(destination)
	var values: Array=dest.get("position",[])
	if not _check(values.size()==2,"Destination exists in authored map."): return
	var start:=Vector2i(int(values[0]),int(values[1]))*SimConfig.FIXED_SCALE
	# Both declared straight corridors are broad open approaches in the actual
	# campus. Check the live collision, with extra endpoint margin, before input.
	for pixel: int in range(0,1537,16):
		if not _check(game.world.collision.can_occupy(start+Vector2i(game.route_direction*pixel*1000,0),actor.radius),"Authored traversal corridor remains collision feasible."): return
	var before_resources := [actor.health,actor.flux,actor.stamina,Array(actor.spell_wire_ids),int(game.world.hex_court.metrics.matter_paid)]
	if not _check(game.local_navigation.open_map(),"Actual map opens."): return
	var model: RefCounted=game.local_navigation.map_panel.model
	for unused: int in 63:
		if String(model.selected_destination().get("id",""))==destination: break
		game.local_navigation.handle_input(_key(KEY_DOWN))
	if not _check(String(model.selected_destination().get("id",""))==destination,"Actual map selects authored destination."): return
	game.local_navigation.handle_input(_key(KEY_ENTER))
	if not _check(actor.last_event=="map_travel" and not game.local_navigation.blocks_gameplay(),"Actual committed travel closes navigation."): return
	if not _check(before_resources==[actor.health,actor.flux,actor.stamina,Array(actor.spell_wire_ids),int(game.world.hex_court.metrics.matter_paid)],"Travel does not grant resources or change the kit."): return
	initial_packet=Snapshot.capture(game.world)
	if not _check(not initial_packet.is_empty(),"Committed arrival starts with a complete strict packet."): return
	var restored: SimWorld=Snapshot.prepare(initial_packet,game.world)
	if not _check(restored!=null and restored.state_hash()==game.world.state_hash(),"Arrival packet decodes exact complete authority."): return
	navigation={"destination":destination,"start":Array([actor.position_x,actor.position_y]),"resources":before_resources,
		"world_tick":game.world.tick,"state_hash":game.world.state_hash(),"terrain":game.campus_renderer.terrain_status(),
		"garden_required":int(game.element_garden.arrival_status().required),"profile":game.player_preferences.render_quality}
	game.release_fixture_actions()
	game.phase="arrival"
	game.set_process(true)

func _route_finished() -> void:
	if closing: return
	var actor: PlayerState=game._local_player_state()
	if not _check(game.command_rows.size()==ROUTE_TICKS and game.step_rows.size()==ROUTE_TICKS and game.world.tick-game.route_start_tick==ROUTE_TICKS,"Exactly480 ordinary sampled commands complete480 successful fixed steps."): return
	if not _check(not game.first_ready.is_empty(),"First combined readiness is recorded without a halo-drain wait."): return
	if not _check(game.seen_sprint and game.seen_slide and game.seen_air and game.seen_evade and game.minimum_stamina>=0 and game.minimum_stamina<game.initial_stamina,"Real paid sprint/slide/jump/evade consume finite Stamina."): return
	if not _check(actor.health>=0 and actor.flux>=0 and actor.stamina>=0 and game.world.hex_court.conservation_valid(),"Ordinary route retains finite resources and chemistry conservation."): return
	var start: Array=navigation.start
	var displacement := Vector2(actor.position_x-int(start[0]),actor.position_y-int(start[1]))/1000.0
	if not _check(displacement.length()>512.0 and absf(displacement.y)<8.0,"Paid real traversal crosses more than a terrain tile along the declared clear corridor."): return
	var packet: Dictionary=Snapshot.capture(game.world)
	var restored: SimWorld=Snapshot.prepare(packet,game.world) if not packet.is_empty() else null
	if not _check(restored!=null and restored.state_hash()==game.world.state_hash(),"Traversal endpoint captures/decodes a strict complete packet."): return
	endpoint={"tick":game.world.tick,"state_hash":game.world.state_hash(),"packet_sha256":_bytes_hash(var_to_bytes(packet)),
		"actor":Array(actor.canonical_values()),"position":[actor.position_x,actor.position_y],"displacement_pixels":[displacement.x,displacement.y],
		"health":actor.health,"flux":actor.flux,"stamina":actor.stamina,"minimum_stamina":game.minimum_stamina,
		"start_stamina":game.initial_stamina,"paid_movement_events":game.paid_events.duplicate(),
		"matter_paid":int(game.world.hex_court.metrics.matter_paid),"matter_expired":int(game.world.hex_court.metrics.matter_expired),
		"terrain":game.campus_renderer.terrain_status(),"dropped_time_seconds":game.dropped_time_seconds}
	if not compare_path.is_empty() and not _compare_peer(): return
	# Endpoints alone use expensive serialization/readback. No arrival/route
	# callback pauses for screenshots or hashing, and no halo drain is requested.
	var before_hash := game.world.state_hash()
	game.queue_redraw()
	await RenderingServer.frame_post_draw
	if closing: return
	var pixels: Image=root.get_texture().get_image()
	if not _check(pixels!=null and pixels.get_size()==Vector2i(1280,720) and pixels.save_png(output.path_join("endpoint.png"))==OK,"Normal complete Bootstrap rendering remains visible at endpoint."): return
	if not _check(game.world.state_hash()==before_hash,"Endpoint native draw preserves authority."): return
	endpoint["image_sha256"]=FileAccess.get_sha256(output.path_join("endpoint.png"))
	for path: String in SAVES:
		if not _check(_hash(path)==saved_after_boot[path],"Traversal causes no profile/progression write: "+path): return
	for path: String in WATCH:
		if not _check(FileAccess.get_sha256(path)==source_hashes[path],"Watched input unchanged: "+path): return
	_begin_close()

func _compare_peer() -> bool:
	var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(compare_path))
	if not _check(value is Dictionary,"Comparison receipt parses."): return false
	var other: Dictionary=value
	if not _check(String(other.get("schema",""))=="bootstrap-terrain-walk-v1" and bool(other.get("passed",false)) and String(other.get("destination",""))==destination and String(other.get("arm",""))!=role and bool(other.get("synthetic_application_focus",false))==synthetic_application_focus,"Comparison is a passed opposing arm for the same route and declared focus policy."): return false
	var previous: Array=other.get("commands",[])
	if not _check(previous.size()==game.command_rows.size(),"Both arms emit equal command counts."): return false
	for index: int in previous.size():
		var old: Dictionary=previous[index]
		var current: Dictionary=game.command_rows[index]
		for key: String in ["relative_tick","entity_id","move_x","move_y","held","pressed","aim_x","aim_y","target_x","target_y"]:
			if not _check(int(old.get(key,-99999999))==int(current[key]),"Complete normalized command trace matches: %d/%s"%[index,key]): return false
	peer_comparison={"receipt":compare_path,"sha256":FileAccess.get_sha256(compare_path),"normalized_commands_equal":true,
		"other_process_rows":(other.get("processes",[]) as Array).size(),"current_process_rows":game.process_rows.size(),
		"other_endpoint":other.get("endpoint",{}),"same_physical_timing_or_absolute_tick_claim":false}
	return true

func _key(code: int) -> InputEventKey:
	var result:=InputEventKey.new()
	result.keycode=code
	result.physical_keycode=code
	result.pressed=true
	return result

func _bytes_hash(bytes: PackedByteArray) -> String:
	var context:=HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func _hash(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "ABSENT"

func _check(condition: bool,message: String) -> bool:
	checks+=1
	if not condition: _fail(message)
	return condition

func _fail(message: String) -> void:
	if not failure.is_empty(): return
	failure=message
	push_error(message)
	_begin_close()

func _begin_close() -> void:
	if closing: return
	closing=true
	if game==null or not game.is_inside_tree():
		_write({})
		quit(1)
		return
	game.phase="closing"
	game.release_fixture_actions()
	game.set_process(true)
	game._request_safe_quit("bootstrap-terrain-walk-fixture")

func _closed(terrain: Dictionary) -> void:
	if closed: return
	closed=true
	if not bool(terrain.get("closed",false)) or int(terrain.get("pending",-1))!=0:
		if failure.is_empty(): failure="Actual exit did not finish all owned terrain work."
	for path: String in saved_after_boot:
		if _hash(path)!=saved_after_boot[path] and failure.is_empty(): failure="Normal close changed profile contents: "+path
	_write(terrain)
	print("%s Bootstrap terrain walk %s/%s: %d checks, %d commands, %d observed callbacks; normal exit verified"%[
		"PASS" if failure.is_empty() else "FAIL",role,destination,checks,game.command_rows.size(),game.process_rows.size()])

func _write(terrain: Dictionary) -> void:
	if not output_created: return
	var paused_rows := 0
	var paused_real_delta := 0.0
	var paused_parent_usec := 0
	if game!=null:
		for row: Dictionary in game.process_rows:
			if bool(row.area_loading) and int(row.tick_after)==int(row.tick_before):
				paused_rows+=1
				paused_real_delta+=float(row.real_callback_delta)
				paused_parent_usec+=int(row.parent_process_usec)
	var record := {"schema":"bootstrap-terrain-walk-v1","passed":failure.is_empty() and closed,"error":failure,
		"scope":"Same current Bootstrap/protocol/kit; only concrete preserved vs current stream differs. Actual scene boot, supported map travel, first required+Garden readiness then tick-scheduled synthetic action state through the real InputRouter, normal rendering and normal close. Optional explicit synthetic-application-focus forces only the application-input-active Boolean before each inherited callback; real focus notifications still execute all production guard/quarantine behavior and actual window focus is recorded separately. This mode is not normal focus acceptance. Each inherited callback receives declared1/60s;480 successful120Hz ticks. World-tick input waits through pauses; this does not model physical input during stalls, certify focus, FPS, latency, player feel or total CPU speed. Endpoint serialization/readback occurs after traversal only; OS cache and startup costs are not isolated.",
		"arm":role,"destination":destination,"user_data":OS.get_user_data_dir(),"engine":Engine.get_version_info(),
		"synthetic_application_focus":synthetic_application_focus,
		"source_hashes":source_hashes,"checks":checks,"declared_process_delta":STEP_DELTA,"route_ticks":ROUTE_TICKS,
		"injection":game.injection if game!=null else {},"navigation":navigation,"first_combined_ready":game.first_ready if game!=null else {},
		"commands":game.command_rows if game!=null else [],"successful_steps":game.step_rows if game!=null else [],
		"processes":game.process_rows if game!=null else [],"endpoint":endpoint,"peer_comparison":peer_comparison,
		"paused_rows":paused_rows,"paused_declared_seconds":paused_rows*STEP_DELTA,"paused_real_callback_delta_sum":paused_real_delta,
		"paused_parent_process_usec":paused_parent_usec,"normal_exit":closed,"terrain_after_exit":terrain,"saves_after_boot":saved_after_boot}
	var file:=FileAccess.open(output.path_join("receipt.json"),FileAccess.WRITE)
	if file==null: push_error("Cannot write owned traversal receipt."); return
	file.store_string(JSON.stringify(record,"\t")+"\n")
	file.close()
	var readback: Variant=JSON.parse_string(FileAccess.get_file_as_string(output.path_join("receipt.json")))
	if not readback is Dictionary or int(readback.get("checks",-1))!=checks or bool(readback.get("passed",false))!=bool(record.passed):
		push_error("Owned traversal receipt did not round-trip.")
