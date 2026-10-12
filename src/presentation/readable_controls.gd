extends RefCounted
## Reflow the same binding editor; device columns become explicit tabs.
const Wrap = preload("res://src/presentation/spell_testing_panel.gd")

static func geometry(viewport: Vector2, selected: int) -> Dictionary:
	var panel := Rect2(Vector2(12,12),viewport-Vector2(24,24))
	var count := clampi(floori((panel.size.y-224)/32),1,12)
	var first := clampi(selected-floori(float(count)/2),0,maxi(0,ControlBindingEditor.ACTIONS.size()-count))
	var tabs: Array[Rect2] = []
	var buttons: Array[Rect2] = []
	var settings: Array[Rect2] = []
	var rows: Array[Rect2] = []
	for index: int in 3: tabs.append(Rect2(panel.position+Vector2(12+index*(panel.size.x-24)/3,76),Vector2((panel.size.x-24)/3-4,28)))
	for index: int in 6: settings.append(Rect2(panel.position+Vector2(12+index*(panel.size.x-24)/6,40),Vector2((panel.size.x-24)/6-3,28)))
	for index: int in count: rows.append(Rect2(panel.position+Vector2(12,112+index*32),Vector2(panel.size.x-24,29)))
	for index: int in 4: buttons.append(Rect2(panel.position+Vector2(12+index*(panel.size.x-24)/4,panel.size.y-42),Vector2((panel.size.x-24)/4-4,30)))
	return {"panel":panel,"tabs":tabs,"settings":settings,"rows":rows,"buttons":buttons,"first":first,"previous":Rect2(panel.end.x-104,panel.position.y+8,44,28),"next":Rect2(panel.end.x-56,panel.position.y+8,44,28),"notice":Rect2(panel.position+Vector2(12,116+count*32),Vector2(panel.size.x-24,minf(62,panel.size.y-50-(116+count*32))))}

static func setting_labels(preferences: PlayerPreferences) -> Array[String]:
	return ["FX " + ("Low" if preferences.reduced_motion else "Full"), "Contrast", "Sound -", "Sound +", "Mute", "Aim cue"]

static func draw(canvas: CanvasItem, viewport: Vector2, editor: ControlBindingEditor, preferences: PlayerPreferences) -> void:
	var geo := geometry(viewport,editor.selected_action_index)
	var panel: Rect2 = geo.panel
	canvas.draw_rect(panel,Color("101c23fc"))
	canvas.draw_rect(panel,Color("77dddc"),false,1)
	_text(canvas,panel.position+Vector2(12,27),"CONTROLS",19,panel.size.x-24)
	_button(canvas,geo.previous,"↑",false)
	_button(canvas,geo.next,"↓",false)
	var settings := setting_labels(preferences)
	for index: int in settings.size(): _button(canvas,geo.settings[index],settings[index],false)
	for index: int in 3: _button(canvas,geo.tabs[index],ControlBindingEditor.DEVICE_LABELS[index],editor.selected_device==index)
	for index: int in geo.rows.size():
		var action: StringName = ControlBindingEditor.ACTIONS[geo.first+index]
		var row: Rect2 = geo.rows[index]
		if geo.first+index==editor.selected_action_index: canvas.draw_rect(row,Color("305157"))
		_text(canvas,row.position+Vector2(6,20),ControlBindingEditor.ACTION_LABELS[action],13,row.size.x*0.62-12)
		_text(canvas,row.position+Vector2(row.size.x*0.62,20),editor.binding_label(action,editor.selected_device,preferences),14,row.size.x*0.38-8)
	var notice := "Press the chosen input. Esc / Back cancels." if editor.capturing else editor.status_message
	var lines := Wrap._wrap(notice,ThemeDB.fallback_font,13,geo.notice.size.x)
	for index: int in mini(floori(geo.notice.size.y/18),lines.size()): _text(canvas,geo.notice.position+Vector2(0,15+index*18),lines[index],13,geo.notice.size.x)
	for index: int in 4: _button(canvas,geo.buttons[index],["Bind","Unbind","Restore","Close"][index],index==0)

static func pointer_action(point: Vector2, viewport: Vector2, editor: ControlBindingEditor) -> String:
	var geo := geometry(viewport,editor.selected_action_index)
	if (geo.previous as Rect2).has_point(point): editor.move_selection(-1,0); return "selected"
	if (geo.next as Rect2).has_point(point): editor.move_selection(1,0); return "selected"
	for index: int in 3:
		if (geo.tabs[index] as Rect2).has_point(point): editor.selected_device=index; return "selected"
	for index: int in geo.rows.size():
		if (geo.rows[index] as Rect2).has_point(point): editor.selected_action_index=geo.first+index; return "selected"
	for index: int in 6:
		if (geo.settings[index] as Rect2).has_point(point): return ["effects","contrast","sound_down","sound_up","mute","aim"][index]
	for index: int in 4:
		if (geo.buttons[index] as Rect2).has_point(point): return ["bind","unbind","restore","close"][index]
	return ""

static func _button(canvas: CanvasItem, rect: Rect2, value: String, selected: bool) -> void:
	canvas.draw_rect(rect,Color("305157") if selected else Color("20353e"))
	_text(canvas,rect.position+Vector2(6,20),value,13,rect.size.x-12)

static func _text(canvas: CanvasItem, at: Vector2, value: String, size: int, width: float) -> void:
	canvas.draw_string(ThemeDB.fallback_font,at,value,HORIZONTAL_ALIGNMENT_LEFT,width,size,Color("eadfc3"))
