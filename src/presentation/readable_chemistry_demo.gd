extends RefCounted
## Reflow existing demo intents. Payment/reset authority stays in Bootstrap.
const Wrap = preload("res://src/presentation/spell_testing_panel.gd")
const ACTIONS := ["launch_paid_hex_demo","reset_hex_playground_area","open_spell_loom","open_chemistry_help","close_hex_playground"]
var focus := 0
var tool := 0
var page := 0
var _axis_latched := false

static func geometry(viewport: Vector2) -> Dictionary:
	var panel := Rect2(Vector2(12,12),viewport-Vector2(24,24))
	var width := panel.size.x-24
	var buttons: Array[Rect2]=[]
	for index: int in 5: buttons.append(Rect2(panel.position+Vector2(12+index*width/5,panel.size.y-42),Vector2(width/5-4,30)))
	return {"panel":panel,"previous_first":Rect2(panel.position+Vector2(12,44),Vector2(44,28)),"next_first":Rect2(panel.position+Vector2(width-32,44),Vector2(44,28)),"previous_second":Rect2(panel.position+Vector2(12,80),Vector2(44,28)),"next_second":Rect2(panel.position+Vector2(width-32,80),Vector2(44,28)),"body":Rect2(panel.position+Vector2(12,144),Vector2(width,maxf(38,panel.size.y-244))),"detail_previous":Rect2(panel.position+Vector2(12,panel.size.y-88),Vector2(44,26)),"detail_next":Rect2(panel.position+Vector2(62,panel.size.y-88),Vector2(44,26)),"buttons":buttons}

func handle_input(event: InputEvent, viewport: Vector2, selected_pair: Vector2i) -> Dictionary:
	var action := ""
	var pair := HexPlaygroundPanel.canonical_pair(selected_pair)
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var geo := geometry(viewport)
		for key: String in ["previous_first","next_first","previous_second","next_second","detail_previous","detail_next"]:
			if (geo[key] as Rect2).has_point(event.position): action=key; break
		for index: int in 5:
			if (geo.buttons[index] as Rect2).has_point(event.position): action=ACTIONS[index]; break
	elif event is InputEventKey and event.pressed and not event.echo:
		var key: int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		action={KEY_ESCAPE:"close_hex_playground",KEY_TAB:"focus_next",KEY_UP:"focus_previous",KEY_DOWN:"focus_next",KEY_LEFT:"previous",KEY_RIGHT:"next",KEY_ENTER:"activate",KEY_KP_ENTER:"activate",KEY_COMMA:"detail_previous",KEY_PERIOD:"detail_next"}.get(key,"")
	elif event is InputEventJoypadButton and event.pressed:
		action={JOY_BUTTON_B:"close_hex_playground",JOY_BUTTON_BACK:"close_hex_playground",JOY_BUTTON_Y:"focus_next",JOY_BUTTON_DPAD_UP:"focus_previous",JOY_BUTTON_DPAD_DOWN:"focus_next",JOY_BUTTON_DPAD_LEFT:"previous",JOY_BUTTON_DPAD_RIGHT:"next",JOY_BUTTON_A:"activate",JOY_BUTTON_LEFT_SHOULDER:"detail_previous",JOY_BUTTON_RIGHT_SHOULDER:"detail_next"}.get(event.button_index,"")
	elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y]:
		if absf(event.axis_value)<0.35: _axis_latched=false
		elif absf(event.axis_value)>0.65 and not _axis_latched:
			action=("focus_next" if event.axis_value>0 else "focus_previous") if event.axis==JOY_AXIS_LEFT_Y else ("next" if event.axis_value>0 else "previous")
			_axis_latched=true
	if action=="detail_previous": page-=1; return {}
	if action=="detail_next": page+=1; return {}
	if action in ["focus_previous","focus_next"]: focus=posmod(focus+(-1 if action=="focus_previous" else 1),3); return {}
	if action in ["previous","next","activate"]:
		if focus==2:
			if action=="activate": action=ACTIONS[tool]
			else: tool=posmod(tool+(-1 if action=="previous" else 1),5); return {}
		else: action=("previous_" if action=="previous" else "next_")+("first" if focus==0 else "second")
	if action in ["previous_first","next_first","previous_second","next_second"]:
		var axis := 0 if action.ends_with("first") else 1
		pair[axis]=HexPlaygroundPanel.ELEMENT_WIRES[posmod(HexPlaygroundPanel.ELEMENT_WIRES.find(pair[axis])+(-1 if action.begins_with("previous") else 1),6)]
		page=0
		return {"action":"select_hex_pair","selected_pair":pair}
	if action == "launch_paid_hex_demo":
		return {"action":action,"selected_pair":pair,"recipe_wire_id":HexPlaygroundPanel.selection_model(pair).recipe_wire_id,"requires_paid_casts":true,"direct_effect_injection":false}
	return {"action":action,"selected_pair":pair} if action in ACTIONS else {}

func draw(canvas: CanvasItem, viewport: Vector2, pair: Vector2i) -> void:
	var geo := geometry(viewport)
	var panel: Rect2=geo.panel
	var model := HexPlaygroundPanel.selection_model(pair)
	canvas.draw_rect(panel,Color("14242cf7"))
	canvas.draw_rect(panel,Color("77dddc"),false,1)
	_text(canvas,panel.position+Vector2(12,28),"CHEMISTRY DEMO",19,panel.size.x-24)
	for key: String in ["previous_first","next_first","previous_second","next_second"]: _button(canvas,geo[key],"<" if key.begins_with("previous") else ">",focus==(0 if key.ends_with("first") else 1))
	_text(canvas,panel.position+Vector2(66,64),"First: "+String(model.first_name),14,panel.size.x-132)
	_text(canvas,panel.position+Vector2(66,100),"Second: "+String(model.second_name),14,panel.size.x-132)
	_text(canvas,panel.position+Vector2(12,133),String(model.name),16,panel.size.x-24)
	var facts := HexPlaygroundPanel._selection_fact(model)
	if int(model.pulse_damage)>0: facts += "  Damage <=12" if int(model.recipe_wire_id)==310 else "  Base %.0f / trigger" % (float(model.pulse_damage)/1000)
	if int(model.flow_speed)>0: facts += "  Flow %.0fpx/s" % (float(model.flow_speed)/1000)
	if int(model.slow_ratio)!=1000: facts += "  Move %.0f%%" % (float(model.slow_ratio)/10)
	var paragraphs: Array[String]=[String(model.purpose),facts,"Counter: "+String(model.counter),"Formation %.2fs / active %.2fs / decay %.2fs" % [float(model.formation_ticks)/120,float(model.active_ticks)/120,float(model.decay_ticks)/120],HexPlaygroundPanel.DEMO_GUIDANCE,HexPlaygroundPanel.RESET_GUIDANCE]
	var lines: Array[String]=[]
	for text: String in paragraphs: lines.append_array(Wrap._wrap(text,ThemeDB.fallback_font,13,geo.body.size.x))
	var count:=maxi(1,floori(geo.body.size.y/18))
	var pages:=maxi(1,ceili(float(lines.size())/count))
	var first:=posmod(page,pages)*count
	for index: int in mini(count,lines.size()-first): _text(canvas,geo.body.position+Vector2(0,14+index*18),lines[first+index],13,geo.body.size.x)
	_button(canvas,geo.detail_previous,"<",false)
	_button(canvas,geo.detail_next,">",false)
	_text(canvas,geo.detail_next.end+Vector2(10,-7),"Details %d/%d · , . / LB RB" % [posmod(page,pages)+1,pages],12,panel.size.x-145)
	for index: int in 5: _button(canvas,geo.buttons[index],["Run demo","Reset area","Spell Loom","Guide","Close"][index],focus==2 and tool==index)
	_text(canvas,panel.position+Vector2(12,panel.size.y-51),"Up/Down: ingredient or tools · Left/Right: change · Enter/A: activate",11,panel.size.x-24)

static func _button(canvas: CanvasItem, rect: Rect2, value: String, selected: bool) -> void:
	canvas.draw_rect(rect,Color("3b646a") if selected else Color("20353e"))
	_text(canvas,rect.position+Vector2(6,20),value,13,rect.size.x-12)

static func _text(canvas: CanvasItem, at: Vector2, value: String, size: int, width: float) -> void:
	canvas.draw_string(ThemeDB.fallback_font,at,value,HORIZONTAL_ALIGNMENT_LEFT,width,size,Color("eadfc3"))
