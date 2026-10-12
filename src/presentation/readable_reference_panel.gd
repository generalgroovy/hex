extends RefCounted
## Selected-entry reading surface over the existing Gallery/Compendium models.
## XAG101: content reflows and remains reachable at 200%; no smaller text fallback.
## https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/101
const Wrap = preload("res://src/presentation/spell_testing_panel.gd")
const PAPER := Color("eadfc3")
var page := 0
var options_open := false
var _selection_key := ""

static func geometry(viewport: Vector2, chemistry: bool = false, options: bool = false) -> Dictionary:
	var panel := Rect2(Vector2(12,12),viewport-Vector2(24,24))
	var width := panel.size.x-24
	var buttons: Dictionary = {}
	for index: int in 3:
		buttons[["tab0","tab1","tab2"][index]]=Rect2(panel.position+Vector2(12+index*width/3,37),Vector2(width/3-4,28))
	for index: int in 2:
		buttons[["previous","next"][index]]=Rect2(panel.position+Vector2(12+index*width/2,70),Vector2(width/2-4,28))
	for index: int in 3:
		buttons[["variant_previous","variant_next","mode"][index]]=Rect2(panel.position+Vector2(12+index*width/3,103),Vector2(width/3-4,28))
	for index: int in 6:
		buttons["element%d" % index]=Rect2(panel.position+Vector2(12+index*width/6,103),Vector2(width/6-3,28))
	buttons["page_previous"]=Rect2(panel.position+Vector2(12,panel.size.y-72),Vector2(44,26))
	buttons["page_next"]=Rect2(panel.position+Vector2(62,panel.size.y-72),Vector2(44,26))
	buttons["primary"]=Rect2(panel.position+Vector2(12,panel.size.y-38),Vector2(width/2-4,26))
	buttons["close"]=Rect2(panel.position+Vector2(16+width/2,panel.size.y-38),Vector2(width/2-4,26))
	var tight := panel.size.y<300
	buttons["options"]=Rect2(panel.position+Vector2(panel.size.x-132,6),Vector2(120,26))
	if tight and not options:
		buttons.previous.position.y=panel.position.y+37
		buttons.next.position.y=panel.position.y+37
	var top := 75 if tight and not options else 138
	return {"panel":panel,"buttons":buttons,"body":Rect2(panel.position+Vector2(12,top),Vector2(width,maxf(19,panel.size.y-78-top))),"chemistry":chemistry,"tight":tight}

func _sync(key: String) -> void:
	if key != _selection_key:
		_selection_key=key
		page=0

static func wrapped(paragraphs: Array[String], width: float) -> Array[String]:
	var lines: Array[String]=[]
	for paragraph: String in paragraphs: lines.append_array(Wrap._wrap(paragraph,ThemeDB.fallback_font,14,width))
	return lines

func _body(canvas: CanvasItem, geo: Dictionary, paragraphs: Array[String]) -> void:
	var lines := wrapped(paragraphs,geo.body.size.x)
	var count := maxi(1,floori(geo.body.size.y/19))
	var pages := maxi(1,ceili(float(lines.size())/count))
	page=posmod(page,pages)
	var first := page*count
	for index: int in mini(count,lines.size()-first): _text(canvas,geo.body.position+Vector2(0,15+index*19),lines[first+index],14,geo.body.size.x)
	_button(canvas,geo.buttons.page_previous,"<")
	_button(canvas,geo.buttons.page_next,">")
	_text(canvas,geo.buttons.page_next.end+Vector2(10,-7),"Details %d/%d" % [page+1,pages],12,geo.panel.size.x-150)

static func _frame(canvas: CanvasItem, geo: Dictionary, title: String) -> void:
	canvas.draw_rect(geo.panel,Color("101c23fc"))
	canvas.draw_rect(geo.panel,Color("77dddc"),false,1)
	_text(canvas,geo.panel.position+Vector2(12,27),title,18,geo.panel.size.x-(150 if geo.tight else 24))

static func _hit(point: Vector2, geo: Dictionary, hidden: Array[String] = []) -> String:
	for key: String in geo.buttons:
		if key in hidden: continue
		if (geo.buttons[key] as Rect2).has_point(point): return key
	return ""

static func _page_delta(event: InputEvent, gallery: bool) -> int:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if key in ([KEY_HOME,KEY_PAGEUP] if gallery else [KEY_PAGEUP]): return -1
		if key in ([KEY_END,KEY_PAGEDOWN] if gallery else [KEY_PAGEDOWN]): return 1
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index==JOY_BUTTON_X: return -1
		if event.button_index==JOY_BUTTON_Y: return 1
	return 0

static func selection_title(model) -> String:
	if model.combination_mode: return String(model.combination_definition(model.combination_mask).get("name","Choose ingredients"))
	if model.tab==0 and not model.movement_rows.is_empty(): return String(model.movement_rows[model.selected_row].title)
	if model.tab==1: return String(model.character_title()).split("/")[0].strip_edges()
	if model.selected_row==0: return "Chemistry: start here"
	var cell: Dictionary=model.hex_matrix_cell(model.selected_row-1,model.selected_element_column)
	return String(cell.get("name","Reaction unavailable"))

func draw_compendium(canvas: CanvasItem, viewport: Vector2, model) -> void:
	_sync("c/%d/%d/%d/%d/%s/%d" % [model.tab,model.selected_row,model.selected_character,model.selected_element_column,model.combination_mode,model.combination_mask])
	var geo := geometry(viewport,false,options_open)
	_frame(canvas,geo,selection_title(model) if geo.tight else "Compendium")
	if geo.tight: _button(canvas,geo.buttons.options,"Done O/Back" if options_open else "Options O/Back",options_open)
	_button(canvas,geo.buttons.previous,"Previous entry")
	_button(canvas,geo.buttons.next,"Next entry")
	if not geo.tight or options_open:
		for index: int in 3: _button(canvas,geo.buttons["tab%d" % index],["Movement","Characters","Chemistry"][index],model.tab==index)
		if model.tab==2 and model.combination_mode:
			for index: int in 6:
				var bit: int=ElementRules.MASK_BY_WIRE[ElementRules.WIRE_IDS[index]]
				_button(canvas,geo.buttons["element%d" % index],String(ElementRules.NAMES[ElementRules.IDS[index]]),(model.combination_mask&bit)!=0)
				if index==model.combination_cursor: canvas.draw_rect(geo.buttons["element%d" % index],PAPER,false,2.0)
		else:
			_button(canvas,geo.buttons.variant_previous,"Previous type" if model.tab==1 else "Pair <" if model.tab==2 else "< Entry")
			_button(canvas,geo.buttons.variant_next,"Next type" if model.tab==1 else "Pair >" if model.tab==2 else "Entry >")
			_button(canvas,geo.buttons.mode,"Combine" if model.tab==2 else "Next detail")
	var paragraphs: Array[String]=[]
	if model.combination_mode: paragraphs.append("Combination: %s. C / right-stick returns to pairs." % String(model.combination_definition(model.combination_mask).get("name","Choose ingredients")))
	elif model.tab==0 and not model.movement_rows.is_empty(): paragraphs.append(String(model.movement_rows[model.selected_row].title))
	elif model.tab==1: paragraphs.append(model.character_title())
	else: paragraphs.append(model.chemistry_title())
	paragraphs.append_array(model.detail_paragraphs())
	_body(canvas,geo,paragraphs)
	_button(canvas,geo.buttons.primary,"Map" if not model.combination_mode else "Return to pairs")
	_button(canvas,geo.buttons.close,"Close")

func handle_compendium(event: InputEvent, pointer: Vector2, viewport: Vector2, model) -> void:
	if _options_event(event,viewport): options_open=not options_open; return
	var delta := _page_delta(event,false)
	if delta!=0: page+=delta; return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var hidden: Array[String]=[]
		hidden.assign(["variant_previous","variant_next","mode"] if model.combination_mode else ["element0","element1","element2","element3","element4","element5"])
		var geo := geometry(viewport,false,options_open)
		if geo.tight and not options_open: hidden.append_array(["tab0","tab1","tab2","variant_previous","variant_next","mode","element0","element1","element2","element3","element4","element5"])
		if not geo.tight: hidden.append("options")
		var action := _hit(pointer,geo,hidden)
		match action:
			"options": options_open=not options_open
			"tab0","tab1","tab2": model.set_tab(int(action[-1]))
			"previous": model.move_row(-1)
			"next": model.move_row(1)
			"variant_previous":
				if model.tab==0: model.move_row(-1)
				else: model.move_column(-1)
			"variant_next":
				if model.tab==0: model.move_row(1)
				else: model.move_column(1)
			"mode":
				if model.tab==2: model.toggle_combination_mode()
				else: page+=1
			"page_previous": page-=1
			"page_next": page+=1
			"primary":
				if model.combination_mode: model.toggle_combination_mode()
				else: model.map_requested=true
			"close": model.close_panel()
			_:
				if action.begins_with("element"): model.toggle_combination_element(int(action.substr(7)))
		return
	model.handle_event(event,ThemeDB.fallback_font,Vector2(-1,-1))

func draw_gallery(canvas: CanvasItem, viewport: Vector2, gallery, availability: Dictionary) -> void:
	var entry: Dictionary=gallery.model.selected_entry()
	_sync("g/%d/%d" % [gallery.model.race_index,gallery.model.character_index])
	var geo := geometry(viewport,false,options_open)
	_frame(canvas,geo,String(entry.get("display_name","Gallery")) if geo.tight else "CHAMPION GALLERY")
	if geo.tight: _button(canvas,geo.buttons.options,"Done O/Back" if options_open else "Options O/Back",options_open)
	_button(canvas,geo.buttons.previous,"Previous character")
	_button(canvas,geo.buttons.next,"Next character")
	if not geo.tight or options_open:
		for index: int in 3: _button(canvas,geo.buttons["tab%d" % index],["Small","Middle","Large"][index],String(entry.get("body_type",""))==["small","middle","large"][index])
		_button(canvas,geo.buttons.variant_previous,"Facing <")
		_button(canvas,geo.buttons.variant_next,"Facing >")
		_button(canvas,geo.buttons.mode,"Portrait" if not gallery.portrait_expanded else "Details")
	var paragraphs: Array[String]=[String(entry.get("race",""))+" / "+String(entry.get("body_type","")).capitalize(),gallery.model.air_action_summary(entry)]
	paragraphs.append_array(gallery.model.detail_paragraphs())
	if not bool(availability.get("enabled",true)): paragraphs.push_front(String(availability.get("reason","Attunement unavailable.")))
	if not gallery.model.status_message.is_empty():
		if gallery.model.status_message.begins_with("Inspect freely"): paragraphs.append(gallery.model.status_message)
		else: paragraphs.push_front(gallery.model.status_message)
	if gallery.portrait_expanded and not entry.is_empty():
		var side := minf((geo.body.size.x-88)/2,geo.body.size.y)
		gallery._draw_portrait(canvas,ThemeDB.fallback_font,String(entry.id),Rect2(geo.body.position,Vector2(side,side)))
		var facing: Dictionary=gallery.facing_preview(String(entry.id))
		if not facing.is_empty(): canvas.draw_texture_rect_region(facing.texture,Rect2(geo.body.position+Vector2(side+8,0),Vector2(side,side)),facing.region)
		_text(canvas,geo.body.position+Vector2(side*2+16,19),"Facing %d / 8" % [gallery.preview_direction+1],13,geo.body.size.x-side*2-20)
	else: _body(canvas,geo,paragraphs)
	_button(canvas,geo.buttons.primary,"Attune" if bool(availability.get("enabled",true)) else "Unavailable")
	_button(canvas,geo.buttons.close,"Close")

func handle_gallery(event: InputEvent, pointer: Vector2, viewport: Vector2, gallery, availability: Dictionary) -> int:
	if _options_event(event,viewport): options_open=not options_open; return 0
	var delta := _page_delta(event,true)
	if delta!=0: page+=delta; gallery.portrait_expanded=false; return 0
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var hidden: Array[String]=["element0","element1","element2","element3","element4","element5"]
		var geo := geometry(viewport,false,options_open)
		if geo.tight and not options_open: hidden.append_array(["tab0","tab1","tab2","variant_previous","variant_next","mode"])
		if not geo.tight: hidden.append("options")
		var action := _hit(pointer,geo,hidden)
		var index: int=gallery.model.display_index(gallery.model.race_index,gallery.model.character_index)
		match action:
			"options": options_open=not options_open
			"tab0","tab1","tab2":
				var desired: String=["small","middle","large"][int(action[-1])]
				for cell: Vector2i in gallery.model.display_cells():
					if String(gallery.model.characters(cell.x)[cell.y].body_type)==desired: gallery.model.select_cell(cell.x,cell.y); break
			"previous": gallery.model.select_display_index(posmod(index-1,gallery.model.display_cells().size()))
			"next": gallery.model.select_display_index(posmod(index+1,gallery.model.display_cells().size()))
			"variant_previous": gallery.change_preview_direction(-1); gallery.portrait_expanded=true
			"variant_next": gallery.change_preview_direction(1); gallery.portrait_expanded=true
			"mode": gallery.toggle_portrait()
			"page_previous": page-=1
			"page_next": page+=1
			"primary":
				if bool(availability.get("enabled",true)): return gallery.model.request_selection()
			"close": gallery.close_panel()
		return 0
	return gallery.handle_event(event,ThemeDB.fallback_font,Vector2(-1,-1),availability)

static func _button(canvas: CanvasItem, rect: Rect2, value: String, active: bool=false) -> void:
	canvas.draw_rect(rect,Color("305157") if active else Color("20353e"))
	_text(canvas,rect.position+Vector2(6,20),value,13,rect.size.x-12)

static func _text(canvas: CanvasItem, at: Vector2, value: String, size: int, width: float) -> void:
	canvas.draw_string(ThemeDB.fallback_font,at,value,HORIZONTAL_ALIGNMENT_LEFT,width,size,PAPER)


static func _options_event(event: InputEvent, viewport: Vector2) -> bool:
	if not bool(geometry(viewport).tight): return false
	return (event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode==KEY_O or event.keycode==KEY_O)) or (event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_BACK)
