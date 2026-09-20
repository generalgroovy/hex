class_name MovementPracticeTrace
extends RefCounted


# Local teaching only. No file, network, collision or simulation writes.
const SAMPLE_TICKS := 4
const MAX_SAMPLES := 1800 # sixty seconds at 120 Hz, sampled at 30 Hz
const SAME_START_RADIUS := 36.0
var enabled := false
var samples := PackedVector2Array()
var previous := PackedVector2Array()
var previous_champion := 0
var champion := 0
var start_tick := 0
var last_sample_tick := -1
var elapsed_ticks := 0
var compare_previous := false
var last_input := ""
var pending_pressed := 0
var last_status := ""


func toggle(tick: int, position: Vector2, champion_id: int) -> void:
	if enabled:
		enabled = false
		return
	begin(tick, position, champion_id)


func begin(tick: int, position: Vector2, champion_id: int) -> void:
	if samples.size() > 1:
		previous = samples.duplicate()
		previous_champion = champion
	champion = champion_id
	enabled = true
	start_tick = tick
	last_sample_tick = tick
	elapsed_ticks = 0
	compare_previous = previous.size() > 1 and previous_champion == champion and previous[0].distance_to(position) <= SAME_START_RADIUS
	samples = PackedVector2Array([position])
	last_input = "MOVE TO TRACE"
	pending_pressed = 0
	last_status = ""


func record(tick: int, position: Vector2, command: SimCommand, champion_id: int = -1, state: PlayerState = null) -> void:
	if not enabled or command == null:
		return
	if tick < start_tick or samples.size() >= MAX_SAMPLES or (champion_id >= 0 and champion_id != champion):
		enabled = false
		return
	pending_pressed |= command.pressed_actions
	elapsed_ticks = tick - start_tick
	if tick - last_sample_tick < SAMPLE_TICKS:
		return
	last_sample_tick = tick
	samples.append(position)
	if state != null:
		var mode: String = PlayerState.MovementMode.keys()[state.movement_mode]
		mode = "FLOAT" if state.air_floating else {"HOP": "JUMP", "DOUBLE_JUMP": "AIRBORNE", "WALL_SKIM": "WALLRUN", "WAVE_DASH": "WAVEDASH"}.get(mode, mode.replace("_", " "))
		var speed := roundi(Vector2(state.velocity_x, state.velocity_y).length() / SimConfig.FIXED_SCALE)
		var premium := mini(state.movement_chain_count, MovementTuning.MOVEMENT_CHAIN_MAXIMUM_STEPS) * MovementTuning.MOVEMENT_CHAIN_COST_STEP_RATIO / 10 if state.movement_chain_reset_ticks > 0 else 0
		last_status = "%s  %du/s  |  STAMINA %.1f/%.1f  |  NEXT +%d%%" % [mode, speed, float(state.stamina) / 1000.0, float(state.stamina_maximum) / 1000.0, premium]
	var actions: Array[String] = []
	if command.move_x != 0 or command.move_y != 0:
		actions.append("MOVE")
	if command.has_held(SimCommand.HELD_SPRINT):
		actions.append("SPRINT")
	if command.has_held(SimCommand.HELD_JUMP) or pending_pressed & SimCommand.PRESSED_JUMP:
		actions.append("JUMP")
	var slide_intent := command.has_held(SimCommand.HELD_FAST_FALL) or pending_pressed & SimCommand.PRESSED_SLIDE
	if slide_intent:
		actions.append("SLIDE -> FAST FALL" if state != null and state.movement_mode == PlayerState.MovementMode.FAST_FALL else "SLIDE")
	if pending_pressed & SimCommand.PRESSED_EVADE:
		var evade_result := "EVADE"
		if state != null:
			evade_result = {
				PlayerState.MovementMode.ROLL: "EVADE -> ROLL",
				PlayerState.MovementMode.AIR_DODGE: "EVADE -> AIR DODGE",
				PlayerState.MovementMode.WAVE_DASH: "EVADE -> WAVEDASH",
				PlayerState.MovementMode.FAST_FALL: "EVADE -> FAST FALL",
			}.get(state.movement_mode, evade_result)
		actions.append(evade_result)
	if pending_pressed & SimCommand.PRESSED_TECHNIQUE:
		actions.append("WALL / TURN")
	last_input = " + ".join(actions) if not actions.is_empty() else "RELEASE"
	pending_pressed = 0


func echo_position() -> Vector2:
	if not compare_previous or previous.is_empty():
		return Vector2.INF
	var sample_time := float(elapsed_ticks) / SAMPLE_TICKS
	var index := mini(int(sample_time), previous.size() - 1)
	return previous[index].lerp(previous[mini(index + 1, previous.size() - 1)], sample_time - floorf(sample_time))


func draw(canvas: CanvasItem, position: Vector2, reduced_effects: bool) -> void:
	if not enabled:
		return
	var recent := samples.slice(maxi(0, samples.size() - 120))
	if recent.size() > 1:
		canvas.draw_polyline(recent, Color(0.73, 0.82, 0.64, 0.32), 2.0, false)
	var echo := echo_position()
	if echo.is_finite():
		canvas.draw_arc(echo, 16, 0, TAU, 16, Color(0.75, 0.74, 0.94, 0.72), 2)
		canvas.draw_line(echo + Vector2(-6, 0), echo + Vector2(6, 0), Color(0.75, 0.74, 0.94, 0.72), 2)
	# Quiet text follows the feet, never the crosshair or projectile lanes.
	var label := "PRACTICE %.1fs  %s" % [float(elapsed_ticks) / 120.0, last_input]
	canvas.draw_string(ThemeDB.fallback_font, position + Vector2(-96, 44), label, HORIZONTAL_ALIGNMENT_LEFT, 280, 12, Color(0.88, 0.86, 0.68, 0.9 if reduced_effects else 0.75))
	if not last_status.is_empty():
		canvas.draw_string(ThemeDB.fallback_font, position + Vector2(-160, 60), last_status, HORIZONTAL_ALIGNMENT_LEFT, 420, 12, Color(0.9, 0.89, 0.78, 0.9))
