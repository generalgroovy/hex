extends SceneTree
## Owner-run native presentation fixture; no physical controller or delivery claim.

const Harness = preload("res://tests/support/chemistry_coach_harness.gd")
const DIRECTIONS: Array[Vector2] = [Vector2.LEFT, Vector2(-1, -1), Vector2.UP, Vector2(1, -1), Vector2.RIGHT, Vector2(1, 1), Vector2.DOWN, Vector2(-1, 1)]
const LABELS: Array[String] = ["west", "northwest", "north", "northeast", "east", "southeast", "south", "southwest"]
const EXTRA_LABELS: Array[String] = ["near-header-left", "near-header-top", "near-resource-left", "near-hotbar-bottom", "center-controller", "center-mouse"]
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900)]
var output := ""
var game: Node2D
var viewport: SubViewport
var reference_viewport: SubViewport
var reference: ReticleReference
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var frames: Array[Dictionary] = []
var previous_mouse_mode: Input.MouseMode


class ReticleReference:
	extends Node2D
	var reticle_at := Vector2(16, 16)
	var aim := Vector2.RIGHT

	func _draw() -> void:
		AimReticlePresenter.draw(self, reticle_at, aim)


func _initialize() -> void:
	root.hide()
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless" or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output) or not OS.get_user_data_dir().replace("\\", "/").contains("/hex-probe-"):
		push_error("Native backend, fresh absolute output and wrapper-isolated profile required")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Cannot create fresh reticle evidence directory")
		quit(2)
		return
	previous_mouse_mode = Input.mouse_mode
	game = Harness.new()
	_check(game.configure_fixture(true), "no-boot production gameplay renderer configures")
	if failures.is_empty():
		_check(game.cartoon_champion_presenter.enable_fullbody_art(false, true), "production pixel character pages configure")
	if not failures.is_empty():
		await _finish()
		return
	viewport = SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(game)
	game.player_preferences.pov_mode = PlayerPreferences.POV_FULL
	game.visual_accessibility_filter = VisualAccessibilityFilter.new()
	game.add_child(game.visual_accessibility_filter)
	game.spell_loom_editor.open_editor(game.world.player(), game.ability_catalog)
	game.spell_loom_editor.is_open = false
	reference_viewport = SubViewport.new()
	reference_viewport.size = Vector2i(32, 32)
	reference_viewport.transparent_bg = true
	reference_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(reference_viewport)
	reference = ReticleReference.new()
	reference_viewport.add_child(reference)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var canvas: Vector2 = Vector2(game.campus_layout.canvas_size)
	for dimensions: Vector2i in SIZES:
		viewport.size = dimensions
		await process_frame
		for index: int in range(DIRECTIONS.size()):
			var aim := DIRECTIONS[index]
			var feet := canvas * 0.5
			if aim.x != 0.0: feet.x = 18.0 if aim.x < 0.0 else canvas.x - 18.0
			if aim.y != 0.0: feet.y = 18.0 if aim.y < 0.0 else canvas.y - 18.0
			await _capture("edge-" + LABELS[index], dimensions, feet, aim, true)
		await _capture("near-header-left", dimensions, Vector2(18, 40), Vector2.LEFT, true)
		await _capture("near-header-top", dimensions, Vector2(160, 18), Vector2.UP, true)
		await _capture("near-resource-left", dimensions, Vector2(18, canvas.y - 120), Vector2.LEFT, true)
		await _capture("near-hotbar-bottom", dimensions, Vector2(canvas.x - 200, canvas.y - 18), Vector2.DOWN, true)
		await _capture("center-controller", dimensions, canvas * 0.5, Vector2.RIGHT, true)
		await _capture("center-mouse", dimensions, canvas * 0.5, Vector2(-1, -1), false)
		await _verify_handoff_hidden(dimensions)
	await _finish()


func _capture(label: String, dimensions: Vector2i, feet: Vector2, aim: Vector2, controller: bool) -> void:
	var actor: PlayerState = game.world.player()
	actor.position_x = roundi(feet.x * 1000.0)
	actor.position_y = roundi(feet.y * 1000.0)
	actor.aim_x = roundi(aim.x * 1000.0)
	actor.aim_y = roundi(aim.y * 1000.0)
	game.previous_position = feet
	game.current_position = feet
	game.previous_air_height = actor.air_height
	game.accumulator_seconds = 0.0
	game.player_camera.clear()
	game.actor_motion_history.clear()
	game.actor_motion_history.capture(game.world.players)
	game._update_character_gaits(0.0)
	game.input_router.controller_aim_active = controller
	game.capture_pointer_world = Vector2i(-1, -1)
	var camera: Vector2 = game._camera_origin(feet)
	var direction := aim.normalized()
	var origin := (feet - camera) * PlayerCameraRig.ZOOM
	var requested := (feet + direction * 320.0 - camera) * PlayerCameraRig.ZOOM
	var placed := AimReticlePresenter.controller_position(origin, requested, Rect2(Vector2.ZERO, Vector2(dimensions)))
	if not controller:
		# Arrange the existing deterministic mouse-capture path; never warp a
		# physical pointer or alter the controller/helper branch to create evidence.
		game.capture_pointer_world = Vector2i(feet + Vector2(48, 24))
		requested = (Vector2(game.capture_pointer_world) - camera) * PlayerCameraRig.ZOOM
		placed = requested
	var suffix := label + "-%dx%d" % [dimensions.x, dimensions.y]
	_check(placed.is_finite(), suffix + " has a finite fully visible display endpoint")
	if not placed.is_finite():
		return
	if controller:
		_check(absf((placed - origin).cross(direction)) < 0.0001, suffix + " retains the original controller aim ray")
		_check((placed - origin).length() <= 240.0001, suffix + " only shortens the display reach")
		_check(placed == requested if label == "center-controller" else placed != requested, suffix + " preserves center behavior or exercises the real edge defect")
	var authority_before: String = game.world.state_hash()
	var values_before := actor.canonical_values()
	reference.reticle_at = Vector2(16, 16) + (placed - placed.floor())
	reference.aim = direction
	reference.queue_redraw()
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := viewport.get_texture().get_image()
	var expected := reference_viewport.get_texture().get_image()
	_check(picture != null and picture.get_size() == dimensions, suffix + " captures the requested native dimensions")
	if picture == null or expected == null:
		_check(false, suffix + " native textures are available")
		return
	var ink_pixels := 0
	var mismatched_pixels := 0
	var offset := Vector2i(placed.floor()) - Vector2i(16, 16)
	for y: int in range(expected.get_height()):
		for x: int in range(expected.get_width()):
			var target := expected.get_pixel(x, y)
			if target.a < 0.999:
				continue
			ink_pixels += 1
			var at := offset + Vector2i(x, y)
			if at.x < 0 or at.y < 0 or at.x >= dimensions.x or at.y >= dimensions.y:
				mismatched_pixels += 1
				continue
			var actual := picture.get_pixelv(at)
			if absf(actual.r - target.r) > 1.0 / 255.0 or absf(actual.g - target.g) > 1.0 / 255.0 or absf(actual.b - target.b) > 1.0 / 255.0:
				mismatched_pixels += 1
	_check(ink_pixels > 0 and mismatched_pixels == 0, suffix + " preserves every production reticle pixel without clipping or HUD occlusion")
	_check(game.world.state_hash() == authority_before and actor.canonical_values() == values_before, suffix + " rendering preserves exact actor and world authority")
	var file_name := suffix + ".png"
	_check(picture.save_png(output.path_join(file_name)) == OK, suffix + " saves native evidence")
	frames.append({"file": file_name, "size": [dimensions.x, dimensions.y], "controller": controller,
		"origin": [origin.x, origin.y], "requested": [requested.x, requested.y], "placed": [placed.x, placed.y],
		"aim": [actor.aim_x, actor.aim_y], "world_hash": authority_before,
		"reference_opaque_pixels": ink_pixels, "mismatched_reticle_pixels": mismatched_pixels})


func _verify_handoff_hidden(dimensions: Vector2i) -> void:
	game.capture_pointer_world = Vector2i(-1, -1)
	game.input_router.controller_aim_active = true
	var authority_before: String = game.world.state_hash()
	for handoff: String in ["focus-inactive", "input-guard", "controls-modal", "loom-modal", "join-modal"]:
		game.application_input_active = handoff != "focus-inactive"
		game.controls_input_guard_frames = 2 if handoff == "input-guard" else 0
		game.controls_editor.is_open = handoff == "controls-modal"
		game.spell_loom_editor.is_open = handoff == "loom-modal"
		game.join_address_editor_open = handoff == "join-modal"
		# Deliberately leave stale hidden mouse mode: the immediate modal/focus
		# guard must work even before the next production process updates it.
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var hidden_mode_pixels := viewport.get_texture().get_image().get_data()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		_check(viewport.get_texture().get_image().get_data() == hidden_mode_pixels, "%s-%dx%d excludes controller reticle before and after cursor-mode synchronization" % [handoff, dimensions.x, dimensions.y])
	game.application_input_active = true
	game.controls_input_guard_frames = 0
	game.controls_editor.is_open = false
	game.spell_loom_editor.is_open = false
	game.join_address_editor_open = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_check(game.world.state_hash() == authority_before, "modal/focus display guards leave authority unchanged")


func _check(condition: bool, message: String) -> void:
	checks.append({"passed": condition, "message": message})
	if not condition: failures.append(message)


func _finish() -> void:
	Input.mouse_mode = previous_mouse_mode
	var expected_files: Array[String] = []
	for dimensions: Vector2i in SIZES:
		for label: String in LABELS:
			expected_files.append("edge-%s-%dx%d.png" % [label, dimensions.x, dimensions.y])
		for label: String in EXTRA_LABELS:
			expected_files.append("%s-%dx%d.png" % [label, dimensions.x, dimensions.y])
	var actual_files: Array[String] = []
	for frame: Dictionary in frames:
		var name := String(frame.file)
		_check(not actual_files.has(name), "native frame labels are unique: " + name)
		actual_files.append(name)
		_check(frame.size in [[1280, 720], [1600, 900]] and name.ends_with("-%dx%d.png" % [int(frame.size[0]), int(frame.size[1])]), "native frame label and recorded logical size agree: " + name)
	actual_files.sort()
	expected_files.sort()
	_check(actual_files == expected_files, "all 28 unique native edge/HUD/center frames exist at both logical viewport sizes")
	var disk_files: Array[String] = []
	for name: String in DirAccess.get_files_at(output):
		if name.ends_with(".png"): disk_files.append(name)
	disk_files.sort()
	_check(disk_files == expected_files, "saved native PNG inventory exactly matches the complete fixture")
	var receipt := FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE)
	if receipt == null:
		push_error("Cannot write reticle receipt")
		quit(2)
		return
	receipt.store_string(JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "frames": frames,
		"runtime_identity": JSON.parse_string(FileAccess.get_file_as_string("res://content/runtime/runtime_build_identity_v1.json")),
		"fixture": "Synthetic stationary poses at the campus boundary, HUD-adjacent edges and center; production Bootstrap draw/controller branch and exact production reticle pixels. Mouse capture and modal/focus states are arranged. Sizes are logical SubViewport dimensions, not physical-window resize or DPI evidence. No simulation movement, physical input, sockets, audio, or preference writes.",
		"not_run": ["physical controller", "physical window resize", "DPI scaling", "human feel", "network", "capacity acceptance"]}, "\t") + "\n")
	receipt.close()
	print("AIM_RETICLE_EDGE ", checks.size(), " checks / ", failures.size(), " failures / ", frames.size(), " native frames")
	for failure: String in failures: print("FAILED: ", failure)
	if is_instance_valid(game): game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
