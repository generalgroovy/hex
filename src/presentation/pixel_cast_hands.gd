extends RefCounted
## Additive native arm keys while the lower body keeps its movement silhouette.
## Precedent: Epic's movement + upper-body action layers and Riot's action clarity.
## https://dev.epicgames.com/documentation/en-us/unreal-engine/using-layered-animations-in-unreal-engine
## https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/
## These are reused registered pixels, not newly painted action animation.

const StartupTiming = preload("res://src/presentation/cast_startup_witness.gd")

static func decorate(frame: Dictionary, state: PlayerState, texture: Texture2D, config: SimConfig, reduced: bool, cast_timing: Dictionary = {}) -> void:
	if frame.is_empty() or state==null or config==null or texture==null or texture.get_size()!=Vector2(1024,512): return
	if state.health<=0 or (state.pending_cast_wire_id<=0 and state.cast_recovery_ticks<=0): return
	if state.control_state not in [PlayerState.ControlState.FREE,PlayerState.ControlState.SLOWED]: return
	var aim := int(frame.get("aim_index",0))
	var phase := "release"
	if state.pending_cast_wire_id>0:
		phase="gather" if StartupTiming.animation_progress(state, config, cast_timing) < 0.5 else "extend"
	elif state.cast_recovery_ticks<=config.milliseconds_to_ticks(45): phase="settle"
	var reach := 0 if reduced else (2 if phase=="extend" or phase=="release" else 1)
	var direction := Vector2(state.aim_x,state.aim_y).normalized()
	var displacement := (direction*reach).round()
	# Side arm/hand strips exclude the original face and central torso. The
	# tucked head, folded legs, and flying anatomy remain independently visible.
	var parts: Array[Dictionary]=[]
	for left: int in [0,76]:
		var inward := Vector2(1 if left==0 else -1,-1) if phase=="gather" and not reduced else Vector2.ZERO
		parts.append({"source":Rect2(aim*128+left,384+60,52,36),"at":Vector2(left-64,-44)+displacement+inward})
	frame["cast_arm_parts"]=parts
	frame["cast_arm_texture"]=texture
	frame["cast_pose_phase"]=phase
	frame["independent_cast_pose"]=true
	frame["cast_arm_native_pixels"]=true
	frame["frame_id"]=String(frame.get("frame_id",""))+"/hands/"+phase+"/"+str(aim)
	var bounds: Rect2=frame.get("body_bounds",Rect2(-64,-104,128,128))
	for part: Dictionary in parts: bounds=bounds.merge(Rect2(part.at,(part.source as Rect2).size))
	frame["body_bounds"]=bounds

static func draw(canvas: CanvasItem, frame: Dictionary, anchor: Vector2, tint: Color) -> void:
	for part: Dictionary in frame.get("cast_arm_parts",[]):
		var source: Rect2=part.source
		canvas.draw_texture_rect_region(frame.cast_arm_texture,Rect2(anchor+(part.at as Vector2),source.size),source,tint)
