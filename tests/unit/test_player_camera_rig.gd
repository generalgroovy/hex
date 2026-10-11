extends FluxTestSuite

const Rig = preload("res://src/presentation/player_camera_rig.gd")
const VIEW := Vector2(1280, 720)
const WORLD := Rect2(0, 0, 3072, 2304)
const FEET := Vector2(1536, 1152)


func run() -> int:
	_test_framing_and_limits()
	_test_time_partition_independence()
	_test_gentle_framing()
	_test_lifecycle()
	_test_input_transform()
	_test_visible_world_rect()
	_test_arrow()
	return finish("player-camera-rig")


func _test_framing_and_limits() -> void:
	equal(Rig.ZOOM_PERCENT, 75, "one gameplay zoom retains legible body and hex sizes")
	equal(Rig.focus_screen_anchor(VIEW, 112.0), Vector2(640, 416), "HUD reserve is excluded from focus anchor")
	equal(Rig.mouse_look_intent(Vector2(640, 416), VIEW), Vector2.ZERO, "pointer at resting anchor does not pan")
	equal(Rig.mouse_look_intent(Vector2(650, 416), VIEW), Vector2.ZERO, "small pointer noise remains in framing dead zone")
	check(Rig.mouse_look_intent(Vector2(1279, 416), VIEW).is_equal_approx(Vector2.RIGHT), "right-screen cursor produces full right lead")
	check(Rig.desired_offset(Vector2(1_000_000, 0), Vector2.RIGHT).length() <= Rig.MAX_COMBINED_LEAD_PIXELS + 0.001, "arbitrary speed cannot send player out of frame")
	check(Rig.desired_offset(Vector2(400, 0), Vector2.LEFT).x < 0.0, "looking backwards and running forwards combines both intents")
	check(Rig.desired_offset(Vector2(400, 0), Vector2.ZERO).x > Rig.desired_offset(Vector2(200, 0), Vector2.ZERO).x, "faster travel looks farther ahead")
	equal(Rig.clamped_origin(Vector2(-100, -100), VIEW, WORLD), Vector2.ZERO, "northwest world edge clamps")
	var southeast := Rig.clamped_origin(Vector2(10000, 10000), VIEW, WORLD)
	check(southeast.is_equal_approx(WORLD.end - VIEW / Rig.ZOOM), "southeast world edge clamps")
	var small := Rect2(200, 300, 320, 240)
	check(Rig.clamped_origin(Vector2(360, 420), VIEW, small).is_equal_approx(small.position + (small.size - VIEW / Rig.ZOOM) * 0.5), "small and translated worlds center without negative clamp ranges")


func _test_time_partition_independence() -> void:
	var offsets: Array[Vector2] = []
	for rate: int in [30, 60, 120, 240]:
		var rig := Rig.new()
		rig.advance(FEET, Vector2.ZERO, Vector2.ZERO, 0.0, VIEW, WORLD)
		for _frame: int in range(rate):
			rig.advance(FEET, Vector2(400, 0), Vector2.UP, 1.0 / float(rate), VIEW, WORLD)
		offsets.append(rig.framing_offset)
	for offset: Vector2 in offsets:
		check(offset.distance_to(offsets[0]) < 0.001, "same held framing intent has same result at30/60/120/240Hz")
	var rig := Rig.new()
	rig.advance(FEET, Vector2.ZERO, Vector2.ZERO, 0.0, VIEW, WORLD)
	rig.advance(FEET, Vector2.ZERO, Vector2.RIGHT, Rig.LEAD_HALF_LIFE_SECONDS, VIEW, WORLD)
	check(rig.framing_offset.is_equal_approx(Vector2(Rig.AIM_LEAD_PIXELS * 0.5, 0)), "one half-life closes exactly half the framing distance")
	var saved := rig.framing_offset
	rig.advance(FEET, Vector2.ZERO, Vector2.LEFT, 0.0, VIEW, WORLD)
	equal(rig.framing_offset, saved, "duplicate zero-delta query cannot advance smoothing")
	rig.advance(FEET + Vector2(8, 0), Vector2.ZERO, Vector2.RIGHT, 0.0, VIEW, WORLD)
	check(rig.origin.is_equal_approx(Rig.clamped_origin(FEET + Vector2(8, 0) + saved, VIEW, WORLD)), "already interpolated feet follow without a second positional lag filter")


func _test_lifecycle() -> void:
	var rig := Rig.new()
	rig.advance(FEET, Vector2.ZERO, Vector2.ZERO, 0.0, VIEW, WORLD)
	rig.advance(FEET, Vector2(400, 0), Vector2.RIGHT, 0.5, VIEW, WORLD)
	check(rig.framing_offset.x > 0.0, "active movement builds anticipatory framing")
	var before := rig.origin
	rig.advance(FEET + Vector2(30, 0), Vector2.ZERO, Vector2.LEFT, 1.0, VIEW, WORLD, 112.0, false, true)
	equal(rig.origin, before, "modal UI and lost focus freeze the exact visible frame")
	rig.advance(FEET + Vector2(30, 0), Vector2.ZERO, Vector2.LEFT, 0.01, VIEW, WORLD)
	equal(rig.framing_offset, Vector2.ZERO, "resume discards stale look-ahead and offscreen history")
	rig.advance(FEET + Vector2(500, 0), Vector2.ZERO, Vector2.LEFT, 0.01, VIEW, WORLD)
	equal(rig.framing_offset, Vector2.ZERO, "teleport snaps rather than sweeping across intervening rooms")
	rig.advance(FEET + Vector2(500, 0), Vector2(400, 0), Vector2.RIGHT, 1.0, VIEW, WORLD)
	rig.advance(FEET + Vector2(500, 0), Vector2(400, 0), Vector2.RIGHT, 0.01, VIEW, WORLD, 112.0, true)
	equal(rig.framing_offset, Vector2.ZERO, "reduced-motion mode is stable player following without lead")
	rig.advance(FEET, Vector2.ZERO, Vector2.RIGHT, 0.1, VIEW, WORLD, 112.0, false, false, true)
	equal(rig.origin, Rig.clamped_origin(FEET, VIEW, WORLD), "explicit spectator/respawn focus change snaps immediately")
	before = rig.origin
	rig.advance(Vector2(INF, 0), Vector2.ZERO, Vector2.ZERO, 0.1, VIEW, WORLD)
	equal(rig.origin, before, "non-finite input never poisons camera state")
	rig.clear()
	check(not rig.initialized, "scene reset releases camera history")


func _test_gentle_framing() -> void:
	check(Rig.MAX_COMBINED_LEAD_PIXELS * Rig.ZOOM <= 36.0, "anticipatory framing never exceeds36screen pixels at fixed75percent")
	check(Rig.LEAD_HALF_LIFE_SECONDS >= 0.20, "camera anticipation settles gently without filtering player motion")
	var anchor := Rig.focus_screen_anchor(VIEW)
	var just_outside := Rig.mouse_look_intent(anchor + Vector2(Rig.POINTER_DEAD_ZONE_PIXELS + 1.0, 0.0), VIEW)
	check(just_outside.x > 0.0 and just_outside.x < 0.0001, "dead-zone boundary has no abrupt look-ahead gain")
	var previous := 0.0
	for distance: int in range(36, 360, 8):
		var strength := Rig.mouse_look_intent(anchor + Vector2(distance, 0.0), VIEW).length()
		check(strength >= previous and strength <= 1.000001, "pointer framing grows continuously and never reverses or overshoots")
		previous = strength
	var rig := Rig.new()
	rig.advance(FEET, Vector2.ZERO, Vector2.ZERO, 0.0, VIEW, WORLD)
	rig.advance(FEET, Vector2(10000, 0), Vector2.RIGHT, 3.0, VIEW, WORLD)
	var before := rig.framing_offset
	rig.advance(FEET, Vector2(-10000, 0), Vector2.LEFT, 1.0 / 120.0, VIEW, WORLD)
	check(rig.framing_offset.distance_to(before) * Rig.ZOOM < 1.9, "maximum aim/speed reversal moves framing less than1.9screen pixels in one120Hz frame")
	var last := rig.framing_offset.length()
	for _frame: int in 120:
		rig.advance(FEET, Vector2.ZERO, Vector2.ZERO, 1.0 / 120.0, VIEW, WORLD)
		check(rig.framing_offset.length() <= last, "framing returns monotonically without spring overshoot or camera wobble")
		last = rig.framing_offset.length()
	check(last * Rig.ZOOM < 1.6, "released framing is within1.6screen pixels of rest after one second")


func _test_input_transform() -> void:
	var frame_origin := Vector2(777.371, 413.918)
	var point := Vector2(911.7, 820.9)
	var drawn_screen := point * Rig.ZOOM + (-frame_origin * Rig.ZOOM).round()
	check(Rig.screen_to_world(drawn_screen, frame_origin).is_equal_approx(point), "input exactly inverts snapped canvas transform")
	var pointer := Vector2(900, 300)
	var intent := Rig.mouse_look_intent(pointer, VIEW)
	for pan: Vector2 in [Vector2.ZERO, Vector2(100, 100), Vector2(-100, -100)]:
		var target := Rig.screen_to_world(pointer, frame_origin + pan)
		check(target.is_finite(), "actual aim remains a finite world endpoint")
		equal(Rig.mouse_look_intent(pointer, VIEW), intent, "camera pan cannot amplify raw screen-space look intent")


func _test_visible_world_rect() -> void:
	for size: Vector2 in [Vector2(960, 540), Vector2(1280, 720), Vector2(3440, 1440), Vector2(720, 1280), Vector2(3840, 2160)]:
		for zoom: float in [0.5, 0.75, 1.0]:
			for origin: Vector2 in [Vector2.ZERO, Vector2(777.371, 413.918), Vector2(-81.7, -62.6)]:
				var viewport := Rect2(Vector2(13, -7), size)
				var world_view := Rig.visible_world_rect(viewport, origin, zoom)
				var translation := (-origin * zoom).round()
				check((world_view.position * zoom + translation).is_equal_approx(viewport.position), "visible world origin exactly matches drawn viewport after pixel snapping")
				check((world_view.end * zoom + translation).is_equal_approx(viewport.end), "visible world end includes every rendered edge at wide/portrait/4K sizes and all zooms")
				check(world_view.size.is_equal_approx(size / zoom), "visible bounds retain exact rendered world extent")
	for bad: Rect2 in [Rect2(), Rect2(0, 0, -1, 10), Rect2(Vector2(INF, 0), Vector2.ONE)]:
		equal(Rig.visible_world_rect(bad, Vector2.ZERO), Rect2(), "invalid viewport cannot poison sight or terrain demand")
	equal(Rig.visible_world_rect(Rect2(Vector2.ZERO, VIEW), Vector2(NAN, 0)), Rect2(), "invalid camera origin cannot poison view bounds")
	equal(Rig.visible_world_rect(Rect2(Vector2.ZERO, VIEW), Vector2.ZERO, 0.0), Rect2(), "zero zoom cannot divide into an invalid view")


func _test_arrow() -> void:
	var rig := Rig.new()
	var shadow := Vector2(100, 120)
	for direction_index: int in range(8):
		var direction := Vector2.RIGHT.rotated(float(direction_index) * TAU / 8.0)
		var points := rig.ground_arrow(shadow, direction)
		equal(points.size(), 3, "arrow is exactly one triangle in all eight headings")
		var tip_delta: Vector2 = points[0] - shadow
		check(tip_delta.normalized().dot(direction) > 0.99999, "arrow follows actual aim with no movement-direction substitution")
		check(absf(tip_delta.length() - 31.0) < 0.001, "arrow stays near ground shadow with no pulse or orbit")
		check(absf((points[1] - shadow).dot(direction) - (points[2] - shadow).dot(direction)) < 0.001, "arrow wings remain symmetric around real aim")
	equal(rig.ground_arrow(shadow, Vector2.RIGHT, false).size(), 0, "preference can completely hide direction marker")
	equal(rig.ground_arrow(shadow, Vector2.ZERO).size(), 0, "unknown aim never invents a direction")
