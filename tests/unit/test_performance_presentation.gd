extends FluxTestSuite

const Quality = preload("res://src/presentation/render_quality.gd")
const PerformancePanel = preload("res://src/presentation/performance_panel.gd")
const Batch = preload("res://src/presentation/pov_terrain_batch.gd")

func run() -> int:
	_test_preferences()
	_test_panel()
	_test_mask_geometry()
	_test_frame_visibility_bounds()
	return finish("performance-presentation")

func _test_frame_visibility_bounds() -> void:
	var game := preload("res://src/app/bootstrap.gd").new()
	game.campus_layout = SanctumCampusLayout.new()
	game.campus_layout.data = {"buildings": [
		{"bounds": [10, 20, 30, 40], "occlusion_policy": "los_cutaway"},
		{"bounds": [70, 80, 90, 100], "occlusion_policy": "none"},
	]}
	var expected: Array[Rect2] = [Rect2(10, 20, 30, 40)]
	equal(game._pov_opaque_bounds(), expected, "fresh sight bounds preserve only actual opaque buildings")
	game._begin_visibility_frame()
	var before: int = game._visibility_bounds_builds
	for query: int in 40:
		equal(game._pov_opaque_bounds(), expected, "every same-frame sight query receives the exact layout")
	equal(game._visibility_bounds_builds, before + 1, "one draw parses opaque building bounds only once")
	game._end_visibility_frame()
	game.campus_layout.data.buildings[0].bounds = [11, 22, 33, 44]
	equal(game._pov_opaque_bounds(), [Rect2(11, 22, 33, 44)], "outside-draw query immediately sees a layout replacement")
	game._begin_visibility_frame()
	equal(game._pov_opaque_bounds(), [Rect2(11, 22, 33, 44)], "the next frame never retains prior layout geometry")
	game._end_visibility_frame()
	check(not game._visibility_frame_active and game._visibility_frame_bounds.is_empty(), "frame end releases the private borrowed cache")
	game.free()

func _test_preferences() -> void:
	var prefs := PlayerPreferences.new()
	equal([prefs.render_quality, prefs.frame_limit], ["low", 60], "new profiles use the economical 60 FPS presentation")
	var legacy := prefs.to_dictionary()
	legacy.erase("render_quality")
	legacy.erase("frame_limit")
	check(prefs.apply_dictionary(legacy), "existing saved controls accept additive performance defaults")
	prefs.reduced_motion = true
	prefs.keyboard_bindings[&"emote"] = KEY_U
	for quality: String in ["low", "standard"]:
		for limit: int in [0, 60, 120]:
			prefs.render_quality = quality
			prefs.frame_limit = limit
			var other := PlayerPreferences.new()
			check(other.apply_dictionary(prefs.to_dictionary()), "every valid quality and cap round-trips")
			equal(other.to_dictionary(), prefs.to_dictionary(), "performance persistence preserves accessibility and customized controls")
	var before := prefs.to_dictionary()
	for bad: Dictionary in [{"render_quality": "ultra"}, {"render_quality": 1}, {"frame_limit": -1}, {"frame_limit": 60.5}, {"frame_limit": "60"}]:
		var invalid := before.duplicate(true)
		invalid.merge(bad, true)
		check(not prefs.apply_dictionary(invalid), "invalid performance preference rejected before mutation")
		equal(prefs.to_dictionary(), before, "rejected quality keeps the entire profile")
	var previous: String = Quality.profile
	check(Quality.set_profile("low"), "Low selects cosmetic budgets")
	equal(Quality.surface_glow_limit(12), 0, "Low avoids optional surface glow")
	equal(Quality.garden_sample_limit(), 1, "Low uses one native material sample per exhibit")
	check(not Quality.set_profile("unexpected"), "unknown profiles cannot alter shared renderer")
	equal(Quality.profile, "low", "invalid quality cannot promote extra work")
	check(Quality.set_profile("standard"), "Standard restores decoration")
	equal(Quality.surface_glow_limit(12), 12, "Standard retains original surface budget")
	Quality.set_profile(previous)

func _test_panel() -> void:
	var prefs := PlayerPreferences.new()
	var PerformancePanel := PerformancePanel.new()
	var viewport := Vector2(960, 540)
	var rect: Rect2 = PerformancePanel.panel_rect(viewport)
	check(Rect2(Vector2.ZERO, viewport).encloses(rect), "performance PerformancePanel fits smallest supported window")
	for index: int in 2: check(rect.encloses(PerformancePanel.row_rect(viewport, index)), "controls remain inside compact PerformancePanel")
	PerformancePanel.open()
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	equal(PerformancePanel.handle_input(key, viewport, prefs), {"render_quality": "standard"}, "keyboard changes selected cosmetic setting")
	key.keycode = KEY_DOWN
	PerformancePanel.handle_input(key, viewport, prefs)
	key.keycode = KEY_LEFT
	equal(PerformancePanel.handle_input(key, viewport, prefs), {"frame_limit": 0}, "left wraps cap to unlimited")
	var pad := InputEventJoypadButton.new()
	pad.pressed = true
	pad.button_index = JOY_BUTTON_A
	equal(PerformancePanel.handle_input(pad, viewport, prefs), {"frame_limit": 120}, "controller confirms next cap")
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = PerformancePanel.row_rect(viewport, 0).get_center() + Vector2(70, 0)
	equal(PerformancePanel.handle_input(click, viewport, prefs), {"render_quality": "standard"}, "pointer reaches quality control")
	key.keycode = KEY_ESCAPE
	equal(PerformancePanel.handle_input(key, viewport, prefs), {"close": true}, "Escape dismisses without changing settings")
	PerformancePanel.close()
	equal(PerformancePanel.handle_input(pad, viewport, prefs), {}, "closed performance PerformancePanel cannot consume or change gameplay")

func _test_mask_geometry() -> void:
	var batch := Batch.new()
	var texture := ImageTexture.create_from_image(Image.create(16, 16, false, Image.FORMAT_RGBA8))
	var backdrop := Rect2(192, 128, 512, 512)
	var translation := Vector2(-240, -192)
	var zoom := 0.75
	batch.begin(null, texture, backdrop, translation, zoom)
	var points := PackedVector2Array([Vector2(0, 0), Vector2(80, 0), Vector2(80, 60), Vector2(0, 60)])
	var shade := Color(0.66, 0.66, 0.66, 1)
	var edge := Color(0.4, 0.4, 0.4, 1)
	batch.append_polygon(points, shade, edge, true)
	var mesh := batch.geometry()
	equal(mesh.points.size(), 4, "terrain replacement retains full visibility polygon")
	equal(mesh.indices.size(), 6, "opaque quad becomes exactly two triangles")
	for index: int in points.size():
		var world_point: Vector2 = (points[index] - translation) / zoom
		var expected_uv: Vector2 = (world_point - backdrop.position) / backdrop.size
		check(mesh.uvs[index].is_equal_approx(expected_uv), "batched terrain UV matches world backdrop despite camera offset")
		equal(mesh.colors[index].a, 1.0, "mask stays opaque and cannot expose hidden actors")
	equal(mesh.colors, PackedColorArray([shade, edge, edge, shade]), "range feather shades the same two far vertices")
	var first_vertices: PackedVector2Array = mesh.points.duplicate()
	batch.append_polygon(PackedVector2Array([Vector2(80, 0), Vector2(100, 0), Vector2(100, 60)]), shade, shade)
	mesh.points[0] = Vector2(999, 999)
	var combined := batch.geometry()
	equal(combined.points[0], first_vertices[0], "diagnostic buffers cannot mutate retained mask")
	for index: int in combined.indices: check(index >= 0 and index < combined.points.size(), "all batched polygons index their own vertices")
	batch.finish()
	check(not batch.active and batch.geometry().points.is_empty(), "painter-order flush cannot leave previous-frame geometry")
