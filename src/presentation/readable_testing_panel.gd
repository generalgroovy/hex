extends RefCounted
## Selected-item reading view; the original Range model still owns every action.
const Inspector = preload("res://src/presentation/spell_inspector_model.gd")
const PAPER := Color("eadfc3")

static func geometry(viewport: Vector2) -> Dictionary:
	var panel := Rect2(Vector2(12,12),viewport-Vector2(24,24))
	var width := panel.size.x-24
	var tight := panel.size.y < 300
	var entry_y := 36 if tight else 42
	var family_y := 69 if tight else 79
	var body_y := 88 if tight else 122
	var buttons: Array[Rect2] = []
	for index: int in 10:
		buttons.append(Rect2(panel.position+Vector2(12+(index%5)*width/5,panel.size.y-42-(36 if index>=5 else 0)),Vector2(width/5-3,30)))
	if tight:
		for index: int in 3: buttons[index+2]=Rect2(panel.position+Vector2(12+index*width/3,panel.size.y-42),Vector2(width/3-3,30))
	return {"panel":panel,"tight":tight,"previous":Rect2(panel.position+Vector2(12,entry_y),Vector2(44,30)),
		"compare":Rect2(panel.position+Vector2(panel.size.x-110,6),Vector2(98,30)),
		"setup":buttons[3] if tight else Rect2(panel.position+Vector2(panel.size.x-192,6),Vector2(76,30)),
		"next":Rect2(panel.position+Vector2(width-32,entry_y),Vector2(44,30)),
		"body":Rect2(panel.position+Vector2(12,body_y),Vector2(width,maxf(19,panel.size.y-(80 if tight else 120)-body_y))),
		"family_previous":Rect2(panel.position+Vector2(12,family_y),Vector2(44,28)),
		"family_next":Rect2(panel.position+Vector2(width-32,family_y),Vector2(44,28)),
		"details_previous":Rect2(panel.position+Vector2(12,panel.size.y-(74 if tight else 112)),Vector2(44,26)),
		"details_next":Rect2(panel.position+Vector2(62,panel.size.y-(74 if tight else 112)),Vector2(44,26)),"buttons":buttons}

static func paragraphs(model) -> Array[String]:
	var row: Dictionary = model._rows[model.selected_index]
	var values: Array[String] = []
	if model.mode=="range":
		values=model.inspection_paragraphs()
		if model.compare_equipped and values.size()>1 and values[0].begins_with("Equipped ->"): values.remove_at(0)
	elif model.mode=="challenges":
		values=model.challenge_paragraphs()
	else:
		values=["Session-only overrides. No earned progress.","All characters are already available.","Leave Developer restores the original weave."]
	if not model.message.is_empty(): values.push_front(model.message)
	return values

static func draw(canvas: CanvasItem, font: Font, viewport: Vector2, model, page: int) -> void:
	var geo := geometry(viewport)
	var panel: Rect2 = geo.panel
	canvas.draw_rect(panel,Color("101c23fc"))
	canvas.draw_rect(panel,Color("77dddc"),false,1)
	_text(canvas,font,panel.position+Vector2(12,27),model.mode.capitalize(),19,panel.size.x-214)
	if model.mode=="range":
		if not geo.tight: _button(canvas,font,geo.setup,"Setup T/X",false)
		_button(canvas,font,geo.compare,"Compare ON" if model.compare_equipped else "Compare",model.compare_equipped)
	_button(canvas,font,geo.previous,"<",false)
	_button(canvas,font,geo.next,">",false)
	var row: Dictionary = model._rows[model.selected_index]
	var label := String(row.get("display_name",row.get("name","")))
	if geo.tight and model.mode=="range": label += " / "+String(MixtureCatalog.FAMILIES[model.family_index]).capitalize()
	_text(canvas,font,panel.position+Vector2(66,geo.previous.position.y-panel.position.y+22),label,15,panel.size.x-132)
	if model.mode=="range" and not geo.tight:
		_button(canvas,font,geo.family_previous,"<",false)
		_button(canvas,font,geo.family_next,">",false)
		_text(canvas,font,panel.position+Vector2(66,geo.family_previous.position.y-panel.position.y+20),"Delivery: "+String(MixtureCatalog.FAMILIES[model.family_index]).capitalize(),14,panel.size.x-132)
	elif model.mode=="developer" and bool(row.get("toggle",false)):
		_text(canvas,font,panel.position+Vector2(12,98),"ON" if bool(model._dev_view.get("toggles",{}).get(row.id,false)) else "OFF",14,panel.size.x-24)
	if geo.tight and model.mode=="range":
		var fact: Dictionary=Inspector.inspect(MixtureCatalog.wire_for(int(row.element_mask),String(MixtureCatalog.FAMILIES[model.family_index])),model.inspection_state)
		if not fact.is_empty(): _text(canvas,font,panel.position+Vector2(12,80),"%.1f Flux | %.2fs prepare / %.2fs cooldown" % [fact.flux,fact.startup,fact.cooldown],12,panel.size.x-24)
	var lines: Array[String] = []
	for paragraph: String in paragraphs(model): lines.append_array(model._wrap(paragraph,font,14,geo.body.size.x))
	var count := maxi(1,floori(geo.body.size.y/19))
	var pages := maxi(1,ceili(float(lines.size())/count))
	var first := posmod(page,pages)*count
	for index: int in mini(count,lines.size()-first): _text(canvas,font,geo.body.position+Vector2(0,15+index*19),lines[first+index],14,geo.body.size.x)
	_button(canvas,font,geo.details_previous,"<",false)
	_button(canvas,font,geo.details_next,">",false)
	_text(canvas,font,geo.details_next.end+Vector2(10,-7),"Details %d/%d | , . / triggers" % [posmod(page,pages)+1,pages],12,panel.size.x-150)
	var labels := ["Previous","Next","Equip" if model.mode=="range" else "Challenge" if model.mode=="challenges" else "Apply","Refill" if model.mode=="range" else "Leave Dev" if model.mode=="developer" else "Back","Close","Cooldowns","Targets","Clear","Guide","Skip"]
	for index: int in 10:
		if geo.tight and index not in [2,3,4]: continue
		if index in [5,6,7] and model.mode!="range": continue
		_button(canvas,font,geo.buttons[index],("Setup T/X" if geo.tight and model.mode=="range" and index==3 else labels[index]),model.pane==2 and model.tool_index==index)

static func pointer_action(point: Vector2, viewport: Vector2, model) -> Dictionary:
	var geo := geometry(viewport)
	if model.mode=="range" and (geo.setup as Rect2).has_point(point):
		model.range_setup_open=true
		model.detail_page=0
		return {}
	if model.mode=="range" and (geo.compare as Rect2).has_point(point):
		model.compare_equipped = not model.compare_equipped
		model.detail_page = 0
		return {}
	for key: String in ["previous","next","family_previous","family_next","details_previous","details_next"]:
		if geo.tight and key.begins_with("family"): continue
		if (geo[key] as Rect2).has_point(point):
			var direction := -1 if key.ends_with("previous") else 1
			if key.begins_with("details"): return {"detail_page":direction}
			if key.begins_with("family"):
				if model.mode=="range": model.family_index=posmod(model.family_index+direction,8)
			elif geo.tight and model.mode=="range" and model.pane==1: model.family_index=posmod(model.family_index+direction,8)
			else: model.selected_index=posmod(model.selected_index+direction,model._rows.size())
			return {}
	for index: int in 10:
		if geo.tight and index not in [2,3,4]: continue
		if (geo.buttons[index] as Rect2).has_point(point):
			model.tool_index=index
			return model._tool_action(bool(geo.tight))
	return {}

static func _button(canvas: CanvasItem, font: Font, rect: Rect2, value: String, selected: bool) -> void:
	canvas.draw_rect(rect,Color("305157") if selected else Color("20353e"))
	_text(canvas,font,rect.position+Vector2(6,20),value,12,rect.size.x-12)

static func _text(canvas: CanvasItem, font: Font, at: Vector2, value: String, size: int, width: float) -> void:
	canvas.draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,width,size,PAPER)
