extends FluxTestSuite


# Execute the production frame loop and real simulation/authority. Only startup
# and drawing are suppressed; this fixture neither loads art nor saves settings.
class FrameHarness:
	extends "res://src/app/bootstrap.gd"
	func _ready() -> void:
		set_process(false)
	func _draw() -> void:
		pass


class CountedTransport:
	extends SessionTransport
	var frame_world: SimWorld
	var polled_ticks: Array[int] = []
	var on_second_poll: Callable
	func poll() -> void:
		polled_ticks.append(frame_world.tick)
		super.poll()
		if polled_ticks.size() == 2 and on_second_poll.is_valid():
			on_second_poll.call()


class NoSavePreferences:
	extends PlayerPreferences
	var save_attempts: int = 0
	func save_to_file(_path: String = DEFAULT_PATH) -> bool:
		save_attempts += 1
		return true


class TransitionHarness:
	extends FrameHarness
	# Keep the real close -> offline lifecycle; substitute only map/art startup.
	func _start_match(requested_tick_rate: int) -> bool:
		world = SimWorld.new(requested_tick_rate, 20260914, CollisionWorld.new(3_072_000, 1_728_000))
		accumulator_seconds = 0.0
		dropped_time_seconds = 0.0
		return true


func run() -> int:
	_test_real_frame_catch_up(true)
	_test_real_frame_catch_up(false)
	_test_real_frame_catch_up(false, 0.25)
	_test_real_frame_catch_up(true, 0.1, true)
	return finish("bootstrap-catch-up")


func _test_real_frame_catch_up(hosting: bool, frame_delta: float = 0.1, close_during_catch_up: bool = false) -> void:
	var previous_mouse_mode := Input.mouse_mode
	InputRouter.ensure_input_map()
	var node: FrameHarness = TransitionHarness.new() if close_during_catch_up else FrameHarness.new()
	node.preference_overrides_are_transient = true
	node.world = SimWorld.new(120, 20260913, CollisionWorld.new(3_072_000, 1_728_000))
	node.input_router = InputRouter.new(1)
	var harness_preferences := NoSavePreferences.new()
	node.player_preferences = harness_preferences
	node.session_steward = SessionSteward.new()
	node.campus_layout = SanctumCampusLayout.new()
	node.ability_catalog = AbilityCatalog.new()
	check(node.ability_catalog.load_from_file(node.ABILITY_CATALOG_PATH), "frame fixture loads production abilities")
	node.champion_catalog = ChampionCatalog.new()
	check(node.champion_catalog.load_from_file(node.CHAMPION_CATALOG_PATH, node.ability_catalog), "frame fixture loads production champion catalog")
	node.authoritative_session = AuthoritativeSession.new()
	check(node.authoritative_session.bind(node.world, node.champion_catalog, Vector2i(500, 500), "Frame Host"), "frame fixture binds real authority")
	var transport := CountedTransport.new()
	transport.frame_world = node.world
	node.session_transport = transport
	if hosting:
		check(transport.start_host(0, "a".repeat(64), "Frame Host"), "frame fixture starts a real local ENet host")
	if close_during_catch_up:
		transport.on_second_poll = func() -> void: node.host_close_pending = true
	(Engine.get_main_loop() as SceneTree).root.add_child(node)
	node._process(frame_delta)
	if close_during_catch_up:
		equal(node.world.tick, 0, "host close during catch-up leaves the replacement offline world unstepped")
		equal(transport.polled_ticks, [0, 1], "closing the host ends the current frame's authority loop")
		check(not transport.is_online() and not node.host_close_pending, "actual pending host close completes the offline transition")
		equal(node.accumulator_seconds, 0.0, "world replacement cannot subtract old frame time into a negative accumulator")
	else:
		equal(node.world.tick, 8, "a rendered hitch advances exactly eight ordinary 120 Hz ticks")
		equal(transport.polled_ticks, [0, 1, 2, 3, 4, 5, 6, 7] if hosting else [0], "host services transport before each catch-up tick; offline stays frame-only")
		check(absf(node.dropped_time_seconds - (0.1 - 8.0 / 120.0)) < 0.000001, "unserved whole-tick time remains explicitly reported")
	check(node.accumulator_seconds < 1.0 / 120.0, "bounded catch-up retains only the fractional remainder")
	if frame_delta > 0.1:
		equal(node.get("clamped_frame_time_seconds"), frame_delta - 0.1, "frame time discarded before accumulation is reported separately")
	transport.stop()
	transport.on_second_poll = Callable()
	node.free()
	equal(harness_preferences.save_attempts, 0, "frame harness teardown never saves player settings")
	Input.mouse_mode = previous_mouse_mode
