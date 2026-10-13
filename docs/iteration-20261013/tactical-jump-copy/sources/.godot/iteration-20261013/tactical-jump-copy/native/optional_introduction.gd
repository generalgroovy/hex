extends RefCounted
## Optional observation-only lesson. No input injection, equip, spending or save.

const Mixtures = preload("res://src/content/mixture_catalog.gd")
const TestingPanelScript = preload("res://src/presentation/spell_testing_panel.gd")
const STEP_COUNT := 6
const DamageEvent = preload("res://src/sim/combat/combat_damage_event.gd")
var active := false
var step := 0
var complete := false
var tactical := false
var detail_page := false
var _world: SimWorld
var _tick := -1
var _position := Vector2i.ZERO
var _distance := 0.0
var _flux := 0
var _last_event := ""
var _chain := 0
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


func start_tactical(world: SimWorld) -> bool:
	if not start(world): return false
	tactical = true
	return true


func reset() -> void:
	stop()
	step = 0
	complete = false
	tactical = false
	detail_page = false
	_distance = 0.0
	_tick = -1


func rebind(world: SimWorld) -> bool:
	if world == null or not world.is_valid() or world.player(1) == null: return false
	_world = world
	_tick = world.tick
	_position = Vector2i(world.player(1).position_x, world.player(1).position_y)
	_flux = world.player(1).flux
	_last_event = world.player(1).last_event
	_chain = world.player(1).movement_chain_count
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
		if tactical:
			match step:
				0: achieved = actor.movement_chain_count >= 2 and actor.movement_chain_count > _chain
				1:
					for event: Dictionary in events:
						var mask := DamageEvent.element_mask(event,world)
						if int(event.get("owner_id",0)) == actor.entity_id and DamageEvent.target_id(event) > 0 and DamageEvent.target_id(event) != actor.entity_id and DamageEvent.amount(event) > 0 and mask > 0 and (mask & (mask-1)) != 0: achieved = true
				2: achieved = bool(context.get("challenge",false)) and actor.last_event != _last_event and actor.last_event in ["evaded_projectile","evaded_spray","evaded_beam"]
				3: achieved = bool(context.get("earned",false)) and bool(context.get("saved",false))
		else:
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
	_last_event = actor.last_event
	_chain = actor.movement_chain_count
	if achieved:
		step += 1
		detail_page = false
		if step >= (4 if tactical else STEP_COUNT):
			complete = true
			active = false
	return achieved


func view() -> Dictionary:
	if tactical: return tactical_view()
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
			explanation = "Recovery begins after its wait. Slashes and translucency mark the dodge protection window; two low bars mark opaque, vulnerable recovery."
		4:
			title = "Open the optional Spell Range"
			instruction = "Use %s. Range loaners never replace your saved weave." % String(_bindings.range)
			explanation = "Choose a mixture and a delivery. Equip prepares slot 1; you still choose when to cast. Reset, refill and clear fields are explicit tools."
		5:
			title = "Try a mixture with two or more elements"
			instruction = "Equip a mixed loaner in the Range, close the menu, then cast it normally."
			explanation = "Read its damage, extra status or terrain effect, and counter. Fuse has a visible delay; leave its marked blast."
	return {"active": active, "complete": complete, "step": step, "total": STEP_COUNT, "title": title, "instruction": instruction, "explanation": explanation, "skip": String(_bindings.skip)}


func tactical_view() -> Dictionary:
	var titles := ["Link two paid movement actions","Land a mixed spell","Avoid a rival's shot","Win and keep the learned spell"]
	var instructions := ["Sprint, Slide, then press and release %s to jump. Watch the Stamina cost." % String(_bindings.jump),"Open %s. Equip a mixed spell, then actually damage a target." % String(_bindings.range),"Choose a Bolt rival in Signature Challenges. Dodge through or jump over a shot.","Defeat the rival cleanly. If saving fails, choose Menu > Retry progress save."]
	var explanations := ["Accepted chains carry momentum and add a bounded cost. A denied input does not count.","Damage, status and ground effects are separate. Read the mixture's counter in the Range.","Height clears low shots. During a dodge, the translucent slash window avoids damage; the following opaque recovery is vulnerable.","Developer tools cannot earn progress. A save receipt completes this lesson; replay after restarting to check your learned weave."]
	return {"active":active,"complete":complete,"step":step,"total":4,"title":titles[mini(step,3)] if not complete else "Tactical lessons complete","instruction":instructions[mini(step,3)],"explanation":explanations[mini(step,3)],"skip":String(_bindings.skip)}


func geometry(viewport: Vector2, font: Font) -> Dictionary:
	# Keep the resource HUD visible during the recovery lesson. The fixed left
	# reading column stays anchored while the current bound text sets its height.
	var line_count := maxi(1, body_lines(font, viewport).size())
	var body_bottom := 46.0 + (line_count - 1) * 18.0 + font.get_descent(12)
	var box := Rect2(16, 86 if viewport.x < 900 else 110, _column_width(viewport), ceilf(body_bottom + 8.0 + 38.0))
	return {"box": box, "skip": Rect2(box.end - Vector2(102, 38), Vector2(90, 26)),"details":Rect2(box.position+Vector2(12,box.size.y-38),Vector2(94,26))}


func skip_rect(viewport: Vector2, font: Font) -> Rect2:
	return geometry(viewport, font).skip


static func _column_width(viewport: Vector2) -> float:
	return viewport.x-32 if viewport.x < 900 else minf(440, viewport.x * 0.5 - 24)


func body_lines(font: Font, viewport: Vector2) -> Array[String]:
	var data := view()
	var width := _column_width(viewport) - 24
	if viewport.x < 900: return TestingPanelScript._wrap(String(data.explanation if detail_page else data.instruction),font,12,width)
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
	canvas.draw_string(font, box.position + Vector2(12, 24), "%d/%d  %s" % [mini(step + 1, int(data.total)), int(data.total), data.title], HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 24, 15, Color("eadfc3"))
	var y := box.position.y + 46
	for line: String in lines:
		canvas.draw_string(font, Vector2(box.position.x + 12, y), line, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 24, 12, Color("b8c8ca"))
		y += 18
	var skip: Rect2 = layout.skip
	canvas.draw_rect(skip, Color("26414c"))
	canvas.draw_string(font, skip.position + Vector2(8, 18), "Skip guide", HORIZONTAL_ALIGNMENT_LEFT, skip.size.x - 16, 12, Color("eadfc3"))
	if viewport.x < 900:
		var details: Rect2 = layout.details
		canvas.draw_rect(details,Color("26414c"))
		canvas.draw_string(font,details.position+Vector2(8,18),"Action" if detail_page else "Why / details",HORIZONTAL_ALIGNMENT_LEFT,details.size.x-16,12,Color("eadfc3"))
