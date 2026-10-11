extends RefCounted
## Ground-local heel punctuation, not a retained wake or a second body image.
## Uses accepted speed/direction and the existing distance-owned gait phase.

const MAX_DRAW_COMMANDS := 6
const MAX_EXTENT := 24.0


static func sample(state: PlayerState, locomotion_phase: float = -1.0, reduced: bool = false) -> Dictionary:
	if state == null or state.health <= 0 or state.is_airborne() or not is_finite(locomotion_phase):
		return {}
	var velocity := Vector2(state.velocity_x, state.velocity_y)
	var speed := velocity.length()
	if speed <= float(MovementTuning.MOVING_MODE_MINIMUM_SPEED):
		return {}
	# Aim/facing can oppose travel while freely coasting; it is not evidence of
	# braking. Admit only accepted ground-skid actions, with their own timers.
	var sliding := (state.slide_ticks > 0 and state.movement_mode == PlayerState.MovementMode.SLIDE) \
		or (state.wave_dash_ticks > 0 and state.movement_mode == PlayerState.MovementMode.WAVE_DASH)
	if not sliding:
		return {}
	var direction := velocity / speed
	var speed_ratio := clampf(speed / (float(MovementTuning.BASE_SPEED) * float(MovementTuning.SPRINT_MULTIPLIER) / 1000.0), 0.0, 1.0)
	# The normal cadence follows traversed distance. Slow/stop never runs an
	# independent wall-clock dust cycle; callers without a phase get a still mark.
	var contact := 1.0
	if not reduced and locomotion_phase >= 0.0:
		contact = 0.82 + 0.18 * pow(maxf(0.0, cos(fposmod(locomotion_phase, 1.0) * TAU * 2.0)), 2.0)
	var side := direction.orthogonal()
	var offsets := PackedVector2Array()
	for sign_value: float in ([-1.0] if reduced else [-1.0, 1.0]):
		offsets.append(-direction * (5.0 + 2.0 * speed_ratio) + side * sign_value * 9.0)
	return {"direction": direction, "speed_ratio": speed_ratio, "sliding": sliding,
		"offsets": offsets, "width": 3 + roundi(speed_ratio * 4.0),
		"opacity": (0.22 + speed_ratio * 0.26) * contact * (0.72 if reduced else 1.0),
		"reduced": reduced, "draw_commands": 2 if reduced else MAX_DRAW_COMMANDS}


static func draw(canvas: CanvasItem, anchor: Vector2, model: Dictionary, language: VisualLanguage) -> int:
	if canvas == null or language == null or model.is_empty() or not anchor.is_finite():
		return 0
	var ink := language.ramp_color("warm_stone", 0)
	var light := language.ramp_color("warm_stone", 4)
	var opacity: float = model.opacity
	var width: int = model.width
	var draws := 0
	for offset: Vector2 in model.offsets:
		var at := (anchor + offset - Vector2(float(width) * 0.5, 1.0)).round()
		canvas.draw_rect(Rect2(at - Vector2.ONE, Vector2(width + 2, 4)), Color(ink, opacity * 0.8))
		canvas.draw_rect(Rect2(at, Vector2(width, 2)), Color(light, opacity))
		draws += 2
		if not bool(model.reduced):
			var chip := (anchor + offset - (model.direction as Vector2) * 5.0).round()
			canvas.draw_rect(Rect2(chip, Vector2(2, 1)), Color(light, opacity * 0.65))
			draws += 1
	return draws
