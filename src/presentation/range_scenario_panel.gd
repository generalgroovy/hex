extends RefCounted
## Optional settings inside the existing Range modal. Intents only; controller
## owns offline authority and each target continues ordinary paid commands.
## Respawn precedent: https://www.ea.com/ea-play/news/arsenal-season-game-updates
const ACTIONS := ["range_target_motion","range_target_fire","range_target_size","range_reset_statistics","refill","reset_cooldowns","reset_targets","clear_shots","introduction","skip_introduction","form_previous","form_next","mixture_previous","mixture_next"]
const PAPER := Color("eadfc3")

static func geometry(viewport: Vector2) -> Dictionary:
	var panel := Rect2(Vector2(12,12),viewport-Vector2(24,24))
	var width := panel.size.x-24
	var controls: Array[Rect2]=[]
	for index: int in 4: controls.append(Rect2(panel.position+Vector2(12+(index%2)*(width+6)/2,42+(index/2)*35),Vector2((width-6)/2,29)))
	return {"panel":panel,"controls":controls,"back":Rect2(panel.position+Vector2(panel.size.x-108,6),Vector2(96,29)),
		"more":Rect2(panel.position+Vector2(panel.size.x-210,6),Vector2(96,29)),
		"body":Rect2(panel.position+Vector2(12,118),Vector2(width,maxf(20,panel.size.y-164))),
		"previous":Rect2(panel.position+Vector2(12,panel.size.y-36),Vector2(44,26)),"next":Rect2(panel.position+Vector2(62,panel.size.y-36),Vector2(44,26))}

static func labels(view: Dictionary) -> Array[String]:
	return ["Movement: "+("Strafe" if view.get("moving",false) else "Still"),"Target fire: "+("On" if view.get("firing",false) else "Off"),"Size: "+String(view.get("size","Medium")),"Reset statistics","Refill resources","Reset cooldowns","Reset targets","Clear fields","Introduction","Skip guide","Previous delivery","Next delivery","Previous mixture","Next mixture"]

static func paragraphs(view: Dictionary) -> Array[String]:
	if not view.get("active",false): return ["Start an offline Range session to adjust its target."]
	var stats: Dictionary=view.get("statistics",{})
	var tick_rate := int(view.get("tick_rate", 0))
	var status_ticks: Array = stats.get("status_ticks", [])
	var status_times: Array[String] = []
	if tick_rate > 0:
		for channel: int in mini(SpellStatusPolicy.NAMES.size(), status_ticks.size()):
			if int(status_ticks[channel]) > 0:
				status_times.append("%s %.2fs" % [SpellStatusPolicy.NAMES[channel], float(status_ticks[channel]) / tick_rate])
	var status_summary := "No target status observed in this window."
	if tick_rate <= 0:
		status_summary = "Target status time is unavailable."
	elif not status_times.is_empty():
		status_summary = "Target status time in this window: %s. Channels can overlap." % "; ".join(status_times)
	return ["Target changes apply when you resume. Firing spends its finite ordinary Flux; changing settings never refills resources.",
		"Observed %.1fs. Player: %d accepted casts / %.1f Flux; target: %d accepted casts / %.1f Flux." % [float(view.get("elapsed_seconds",0.0)),int(stats.get("player_casts",0)),float(stats.get("player_flux",0))/1000.0,int(stats.get("target_casts",0)),float(stats.get("target_flux",0))/1000.0],
		"Damage to target %.1f HP; to player %.1f HP. Target components: direct %.1f, status %.1f, ground %.1f HP." % [float(stats.get("damage_to_target",0))/1000.0,float(stats.get("damage_to_player",0))/1000.0,float(stats.get("direct_damage",0))/1000.0,float(stats.get("status_damage",0))/1000.0,float(stats.get("ground_damage",0))/1000.0],
		status_summary,
		String(view.get("scope","These observations describe this Range session; they are not a balance ranking.")),
		"Reset statistics starts a new observation window. It does not clear shots, heal, refill or reset cooldowns; the original Range tools remain available."]

static func draw(canvas: CanvasItem,font: Font,viewport: Vector2,model) -> void:
	var geo := geometry(viewport)
	canvas.draw_rect(geo.panel,Color("101c23fc"))
	canvas.draw_rect(geo.panel,Color("77dddc"),false,1)
	canvas.draw_string(font,geo.panel.position+Vector2(12,27),"Range setup",HORIZONTAL_ALIGNMENT_LEFT,geo.panel.size.x-234,19,PAPER)
	_button(canvas,font,geo.back,"Back T / X",false)
	_button(canvas,font,geo.more,"More O/L3",false)
	var values := labels(model._range_scenario)
	var first: int=(model.range_setup_index/4)*4
	for index: int in mini(4,values.size()-first): _button(canvas,font,geo.controls[index],values[first+index],model.range_setup_index==first+index)
	var lines: Array[String]=[]
	for value: String in paragraphs(model._range_scenario): lines.append_array(model._wrap(value,font,14,geo.body.size.x))
	if not model.message.is_empty(): lines.append_array(model._wrap(model.message,font,14,geo.body.size.x))
	var count := maxi(1,floori(geo.body.size.y/19))
	var pages := maxi(1,ceili(float(lines.size())/count))
	var line_first := posmod(model.detail_page,pages)*count
	for index: int in mini(count,lines.size()-line_first): canvas.draw_string(font,geo.body.position+Vector2(0,15+index*19),lines[line_first+index],HORIZONTAL_ALIGNMENT_LEFT,geo.body.size.x,14,PAPER)
	_button(canvas,font,geo.previous,"<",false)
	_button(canvas,font,geo.next,">",false)
	canvas.draw_string(font,geo.next.end+Vector2(8,-7),"%d/%d | , . / triggers" % [posmod(model.detail_page,pages)+1,pages],HORIZONTAL_ALIGNMENT_LEFT,geo.panel.size.x-138,12,PAPER)

static func input(event: InputEvent,viewport: Vector2,model) -> Dictionary:
	var move := 0
	var apply := false
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int=event.physical_keycode if event.physical_keycode else event.keycode
		match key:
			KEY_O: model.range_setup_index=posmod((model.range_setup_index/4+1)*4,ACTIONS.size())
			KEY_ESCAPE: model.range_setup_open=false
			KEY_UP,KEY_LEFT: move=-1
			KEY_DOWN,KEY_RIGHT,KEY_TAB: move=1
			KEY_ENTER,KEY_KP_ENTER,KEY_SPACE: apply=true
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_LEFT_STICK: model.range_setup_index=posmod((model.range_setup_index/4+1)*4,ACTIONS.size())
			JOY_BUTTON_B,JOY_BUTTON_BACK: model.range_setup_open=false
			JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_LEFT: move=-1
			JOY_BUTTON_DPAD_DOWN,JOY_BUTTON_DPAD_RIGHT: move=1
			JOY_BUTTON_A: apply=true
	elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var geo := geometry(viewport)
		if (geo.more as Rect2).has_point(event.position): model.range_setup_index=posmod((model.range_setup_index/4+1)*4,ACTIONS.size())
		elif (geo.back as Rect2).has_point(event.position): model.range_setup_open=false
		elif (geo.previous as Rect2).has_point(event.position): model.detail_page-=1
		elif (geo.next as Rect2).has_point(event.position): model.detail_page+=1
		else:
			var first: int=(model.range_setup_index/4)*4
			for index: int in mini(4,ACTIONS.size()-first):
				if (geo.controls[index] as Rect2).has_point(event.position): model.range_setup_index=first+index; apply=true
	if move: model.range_setup_index=posmod(model.range_setup_index+move,ACTIONS.size())
	if apply:
		var action := String(ACTIONS[model.range_setup_index])
		if action.begins_with("form_"):
			model.family_index=posmod(model.family_index+(-1 if action.ends_with("previous") else 1),8)
			return {}
		if action.begins_with("mixture_"):
			model.selected_index=posmod(model.selected_index+(-1 if action.ends_with("previous") else 1),model._rows.size())
			return {}
		return {"action":action}
	return {}

static func _button(canvas: CanvasItem,font: Font,rect: Rect2,text: String,active: bool) -> void:
	canvas.draw_rect(rect,Color("305157") if active else Color("20353e"))
	canvas.draw_string(font,rect.position+Vector2(8,20),text,HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-16,13,PAPER)
