extends RefCounted
const Wrap = preload("res://src/presentation/spell_testing_panel.gd")

static func geometry(viewport: Vector2) -> Dictionary:
	var panel := Rect2(Vector2(16,16),viewport-Vector2(32,32))
	var width := panel.size.x-24
	return {"compact":true,"panel":panel,"cards":[],"columns":1,
		"previous":Rect2(panel.position+Vector2(12,62),Vector2(44,38)),
		"next":Rect2(panel.position+Vector2(width-32,62),Vector2(44,38)),
		"body":Rect2(panel.position+Vector2(12,124),Vector2(width,maxf(38,panel.size.y-230))),
		"detail_previous":Rect2(panel.position+Vector2(12,panel.size.y-92),Vector2(44,26)),
		"detail_next":Rect2(panel.position+Vector2(62,panel.size.y-92),Vector2(44,26)),
		"open":Rect2(panel.position+Vector2(12,panel.size.y-42),Vector2(width*0.5-4,30)),
		"close":Rect2(panel.position+Vector2(16+width*0.5,panel.size.y-42),Vector2(width*0.5-4,30))}

static func handle_input(model, event: InputEvent, pointer: Vector2, viewport: Vector2) -> String:
	var action := ""
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]: action="previous" if event.button_index==MOUSE_BUTTON_WHEEL_UP else "next"
		elif event.button_index==MOUSE_BUTTON_LEFT:
			var geo := geometry(viewport)
			for key: String in ["previous","next","detail_previous","detail_next","open","close"]:
				if (geo[key] as Rect2).has_point(pointer): action=key; break
	elif event is InputEventKey and event.pressed and not event.echo:
		var key: int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		action={KEY_UP:"previous",KEY_W:"previous",KEY_DOWN:"next",KEY_S:"next",KEY_TAB:"next",KEY_LEFT:"detail_previous",KEY_COMMA:"detail_previous",KEY_RIGHT:"detail_next",KEY_PERIOD:"detail_next",KEY_ENTER:"open",KEY_KP_ENTER:"open",KEY_SPACE:"open",KEY_ESCAPE:"close"}.get(key,"")
	elif event is InputEventJoypadButton and event.pressed:
		action={JOY_BUTTON_DPAD_UP:"previous",JOY_BUTTON_DPAD_DOWN:"next",JOY_BUTTON_DPAD_LEFT:"detail_previous",JOY_BUTTON_DPAD_RIGHT:"detail_next",JOY_BUTTON_A:"open",JOY_BUTTON_B:"close",JOY_BUTTON_BACK:"close"}.get(event.button_index,"")
	elif event is InputEventJoypadMotion and event.axis==JOY_AXIS_LEFT_Y:
		if absf(event.axis_value)<0.35: model._stick_y_latched=false
		elif absf(event.axis_value)>0.65 and not model._stick_y_latched:
			action="next" if event.axis_value>0 else "previous"
			model._stick_y_latched=true
	match action:
		"previous","next":
			model.selected_index=posmod(model.selected_index+(-1 if action=="previous" else 1),model.entries.size())
			model.readable_page=0
			model.status_text=""
		"detail_previous": model.readable_page-=1
		"detail_next": model.readable_page+=1
		"open": return model.request_selected()
		"close": model.close()
	return ""

static func draw(canvas: CanvasItem, viewport: Vector2, model) -> void:
	var geo := geometry(viewport)
	var panel: Rect2=geo.panel
	canvas.draw_rect(panel,Color("14242cf7"))
	canvas.draw_rect(panel,Color("77dddc"),false,1)
	_text(canvas,panel.position+Vector2(12,27),model.group_title(),18,panel.size.x-24)
	_text(canvas,panel.position+Vector2(12,47),"Choose a service · %d/%d" % [model.selected_index+1,model.entries.size()],12,panel.size.x-24)
	_button(canvas,geo.previous,"<")
	_button(canvas,geo.next,">")
	var entry: Dictionary=model.entries[model.selected_index]
	var card: Dictionary=model.card_overrides_by_station.get(model.selected_station_id(),entry)
	var title := String(card.get("title",WellspringServiceBuildings.definition_for(entry).get("title","Service")))
	_text(canvas,panel.position+Vector2(64,87),title,15,panel.size.x-128)
	var lines: Array[String]=[]
	var paragraphs: Array[String]=model.selected_detail_lines()
	if not model.status_text.is_empty() and not paragraphs.has(model.status_text): paragraphs.push_front(model.status_text)
	for text: String in paragraphs: lines.append_array(Wrap._wrap(text,ThemeDB.fallback_font,13,geo.body.size.x))
	var count:=maxi(1,floori(geo.body.size.y/18))
	var pages:=maxi(1,ceili(float(lines.size())/count))
	var first:=posmod(model.readable_page,pages)*count
	for index: int in mini(count,lines.size()-first): _text(canvas,geo.body.position+Vector2(0,14+index*18),lines[first+index],13,geo.body.size.x)
	_button(canvas,geo.detail_previous,"<")
	_button(canvas,geo.detail_next,">")
	_text(canvas,geo.detail_next.end+Vector2(10,-7),"Details %d/%d · Left / Right" % [posmod(model.readable_page,pages)+1,pages],12,panel.size.x-145)
	_button(canvas,geo.open,"Open / A" if model.selected_available() else "Unavailable · read reason")
	_button(canvas,geo.close,"Close / B")

static func _button(canvas: CanvasItem, box: Rect2, value: String) -> void:
	canvas.draw_rect(box,Color("305157"))
	_text(canvas,box.position+Vector2(8,21),value,13,box.size.x-16)

static func _text(canvas: CanvasItem, at: Vector2, value: String, size: int, width: float) -> void:
	canvas.draw_string(ThemeDB.fallback_font,at,value,HORIZONTAL_ALIGNMENT_LEFT,width,size,Color("eadfc3"))
