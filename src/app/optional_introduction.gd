class_name OptionalIntroduction
extends RefCounted
## Optional observation-only lesson. No input injection, equip, spending or save.

const Mixtures = preload("res://src/content/mixture_catalog.gd")
const TestingPanelScript = preload("res://src/presentation/spell_testing_panel.gd")
const STEP_COUNT := 6
var active := false
var step := 0
var complete := false
var _world: SimWorld
var _tick := -1
var _position := Vector2i.ZERO
var _distance := 0.0
var _flux := 0
var _bindings := {"move": "your movement controls", "jump": "Jump", "cast": "a spell control", "range": "F6 / Spell Range", "skip": "F5 / Skip guide"}


func configure_bindings(labels: Dictionary) -> void:
	for key: String in _bindings.keys():
		if labels.get(key) is String and not String(labels[key]).is_empty(): _bindings[key] = String(labels[key])


func start(world: SimWorld) -> bool:
	if world == null or not world.is_valid() or world.player(1) == null: return false
	reset()
	active = true
	return rebind(world)


func stop() -> void:
	active = false
	_world = null


func reset() -> void:
	stop()
	step = 0
	complete = false
	_distance = 0.0
	_tick = -1


func rebind(world: SimWorld) -> bool:
	if world == null or not world.is_valid() or world.player(1) == null: return false
	_world = world
	_tick = world.tick
	_position = Vector2i(world.player(1).position_x, world.player(1).position_y)
	_flux = world.player(1).flux
	active = not complete
	return true


func observe(world: SimWorld, events: Array[Dictionary], context: Dictionary = {}) -> bool:
	if not active or world == null or world != _world or world.tick <= _tick or world.player(1) == null: return false
	var actor := world.player(1)
	var elapsed := world.tick - _tick
	var position := Vector2i(actor.position_x, actor.position_y)
	var travelled := Vector2(position - _position).length()
	var paid_wire := 0
	for event: Dictionary in events:
		if String(event.get("type", "")) == "cast_started" and int(event.get("entity_id", 0)) == actor.entity_id:
			var wire := int(event.get("wire_id", 0))
			if CombatTuning.is_runtime_wire_id(wire): paid_wire = wire
	var achieved := false
	if not bool(context.get("panel_open", false)) and not bool(context.get("developer", false)):
		match step:
			0:
				# Bound ordinary travel; a relocated fixture/world spawn is no lesson.
				if travelled <= 20000.0 * elapsed: _distance += travelled
				achieved = _distance >= 80000.0
			1: achieved = actor.air_height > 0 and actor.air_vertical_velocity > 0
			2: achieved = paid_wire > 0
			3: achieved = actor.flux > _flux and actor.flux_recovery_delay_ticks == 0 and actor.pending_cast_ticks == 0
			4: achieved = bool(context.get("range", false))
			5:
				var mask := Mixtures.mask_for_wire(paid_wire)
				achieved = bool(context.get("range", false)) and mask > 0 and (mask & (mask - 1)) != 0
	_tick = world.tick
	_position = position
	_flux = actor.flux
	if achieved:
		step += 1
		if step >= STEP_COUNT:
			complete = true
			active = false
	return achieved


func view() -> Dictionary:
	var title := "Introduction complete"
	var instruction := "Explore the Range, then defeat a Signature Challenge rival to learn that spell."
	var explanation := "Health shows what you can survive; Flux pays spells; Stamina pays movement. Damage, status and terrain are different effects."
	match step:
		0:
			title = "Move a short distance"
			instruction = "Use %s. Your actual movement advances this step." % String(_bindings.move)
			explanation = "Aim and travel can point in different directions. Walking lets resources recover."
		1:
			title = "Prepare, then jump"
			instruction = "Press %s to prepare; release it to leave the ground." % String(_bindings.jump)
			explanation = "A second press gives a second tuck or a flying race's paid flight. Height clears low effects; it does not make every attack miss."
		2:
			title = "Pay for one spell"
			instruction = "Aim into the court and use %s. Only an accepted cast advances this step." % String(_bindings.cast)
			explanation = "Flux pays startup. Watch the spell's cooldown after release. A denied input does not spend or cast."
		3:
			title = "Let Flux recover"
			instruction = "Pause casting and walk or stand until Flux actually rises."
			explanation = "Recovery begins after its wait. Slashes and translucency mark only the short dodge protection window; opaque recovery is vulnerable."
		4:
			title = "Open the optional Spell Range"
			instruction = "Use %s. Range loaners never replace your saved weave." % String(_bindings.range)
			explanation = "Choose a mixture and a delivery. Equip prepares slot 1; you still choose when to cast. Reset, refill and clear fields are explicit tools."
		5:
			title = "Try a mixture with two or more elements"
			instruction = "Equip a mixed loaner in the Range, close the menu, then cast it normally."
			explanation = "Read its damage, extra status or terrain effect, and counter. Fuse has a visible delay; leave its marked blast."
	return {"active": active, "complete": complete, "step": step, "total": STEP_COUNT, "title": title, "instruction": instruction, "explanation": explanation, "skip": String(_bindings.skip)}


func geometry(viewport: Vector2, font: Font) -> Dictionary:
	# Keep the resource HUD visible during the recovery lesson. The fixed left
	# reading column stays anchored while the current bound text sets its height.
	var line_count := maxi(1, body_lines(font, viewport).size())
	var body_bottom := 46.0 + (line_count - 1) * 18.0 + font.get_descent(12)
	var box := Rect2(16, 110, _column_width(viewport), ceilf(body_bottom + 8.0 + 38.0))
	return {"box": box, "skip": Rect2(box.end - Vector2(102, 38), Vector2(90, 26))}


func skip_rect(viewport: Vector2, font: Font) -> Rect2:
	return geometry(viewport, font).skip


static func _column_width(viewport: Vector2) -> float:
	return minf(440, viewport.x * 0.5 - 24)


func body_lines(font: Font, viewport: Vector2) -> Array[String]:
	var data := view()
	var width := _column_width(viewport) - 24
	var lines := TestingPanelScript._wrap(String(data.instruction), font, 12, width)
	lines.append_array(TestingPanelScript._wrap(String(data.explanation), font, 12, width))
	return lines


func draw(canvas: CanvasItem, font: Font, viewport: Vector2) -> void:
	if not active or canvas == null or font == null: return
	var data := view()
	var layout := geometry(viewport, font)
	var box: Rect2 = layout.box
	var lines := body_lines(font, viewport)
	canvas.draw_rect(box, Color("101c23f2"))
	canvas.draw_rect(box, Color("77dddc"), false, 1)
	canvas.draw_string(font, box.position + Vector2(12, 24), "%d/%d  %s" % [mini(step + 1, STEP_COUNT), STEP_COUNT, data.title], HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 24, 15, Color("eadfc3"))
	var y := box.position.y + 46
	for line: String in lines:
		canvas.draw_string(font, Vector2(box.position.x + 12, y), line, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 24, 12, Color("b8c8ca"))
		y += 18
	var skip: Rect2 = layout.skip
	canvas.draw_rect(skip, Color("26414c"))
	canvas.draw_string(font, skip.position + Vector2(8, 18), "Skip guide", HORIZONTAL_ALIGNMENT_LEFT, skip.size.x - 16, 12, Color("eadfc3"))
