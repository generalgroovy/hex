extends RefCounted
## Native-pixel assemblies; original atlases and gameplay state are immutable.

const BALL_ACTIONS := ["jump", "double_jump", "slide_jump", "walljump", "fall", "fast_fall"]
const KEY_HOLD_TICKS := 12.0 # 60Hz presentation units;200ms held wing keys.
const BALL_KEY_BOUNDARIES := [9.0, 21.0, 33.0] #150/200/200ms, then hold descent.
const MAX_TUCK_KEYS := 64 # Bounded per admitted identity; no per-draw clipping after warmup.
const RADII := {"small": 19, "middle": 22, "large": 25}


static func profile(entry: Dictionary, pixels: Image, texture: Texture2D) -> Dictionary:
	var gathers: Array[Rect2i] = []
	for facing: int in 8:
		var cell := pixels.get_region(Rect2i(facing * 128, 0, 128, 128))
		gathers.append(cell.get_used_rect())
	return {"body": String(entry.body), "race": String(entry.race), "texture": texture,
		"gathers": gathers, "tucks": {}}


static func pose_ticks(state: PlayerState, config: SimConfig) -> float:
	if state == null or config == null or not config.is_valid(): return 0.0
	if state.air_floating and state.flight_capable and state.float_ticks > 0 and state.stamina > 0:
		var duration := config.milliseconds_to_ticks(clampi(state.float_max_duration_ms, MovementTuning.FLOAT_LARGE_DURATION_MS, MovementTuning.FLOAT_SMALL_DURATION_MS))
		return float(maxi(0, duration-state.float_ticks))*60.0/float(config.tick_rate)
	# A physical pose phase, not elapsed time: charged lift holds the opening
	# longer. Every fresh jump impulse starts upright, including slide jumps
	# which do not reset the hop cooldown. Wall/flight exits use actual descent.
	return maxf(0.0, float(MovementTuning.JUMP_VERTICAL_SPEED-state.air_vertical_velocity)*60.0/float(MovementTuning.VERTICAL_GRAVITY))


static func frame(id: String, identity: Dictionary, action: String, aim: int, travel: int, tick: float, vertical_velocity: int, reduced: bool, second_jump: bool = false) -> Dictionary:
	if identity.is_empty() or aim < 0 or aim >= 8 or not is_finite(tick): return {}
	if action != "fly" and action not in BALL_ACTIONS: return {}
	var flying := action == "fly"
	var key := 0
	if flying:
		key = [0, 1, 2, 1][posmod(floori(maxf(0.0,tick) / KEY_HOLD_TICKS), 4)]
	else:
		for boundary: float in BALL_KEY_BOUNDARIES:
			if tick >= boundary: key += 1
		if action == "fast_fall": key = 3
	if reduced: key = 1 if flying else 0
	var repeated := second_jump or action == "double_jump"
	var fold_key := 0 if vertical_velocity > 120_000 else (2 if vertical_velocity < -120_000 else 1)
	var radius := int(RADII.get(identity.body, 22))
	var parts: Array[Dictionary] = []
	var shapes: Array[Dictionary] = []
	var head := Rect2()
	var head_at := Rect2()
	if flying:
		# Retain the entire authored airborne anatomy, including each race's own
		# feathers, membranes, fairy wings or open arms. Only outer upper strips
		# translate by three native pixels; the face/torso stay planted and
		# no generic replacement wing or whole-body rescale is drawn.
		var offset: int = [-3, 0, 3][key]
		_part(parts, Rect2(aim*128,128,50,92), Vector2(-64,-104+offset))
		_part(parts, Rect2(aim*128+50,128,28,128), Vector2(-14,-104))
		_part(parts, Rect2(aim*128+78,128,50,92), Vector2(14,-104+offset))
		_part(parts, Rect2(aim*128,220,50,36), Vector2(-64,-12))
		_part(parts, Rect2(aim*128+78,220,50,36), Vector2(14,-12))
	else:
		var used: Rect2i = identity.gathers[aim]
		var head_height := mini(22, maxi(12, roundi(used.size.y * 0.43)))
		var foot_height := mini(13, maxi(8, roundi(used.size.y * 0.25)))
		var head_width := mini(30, used.size.x)
		var head_left := clampi(64-floori(head_width/2.0), used.position.x, used.end.x-head_width)
		head = Rect2(aim*128+head_left,used.position.y,head_width,head_height)
		head_at = Rect2(-floorf(head_width/2.0),-radius*2,head_width,head_height)
		var torso_top := used.position.y + head_height - 3
		var torso_bottom := used.end.y - foot_height
		var torso_width := mini(radius*2-2,used.size.x)
		var torso_left := clampi(64-floori(torso_width/2.0),used.position.x,used.end.x-torso_width)
		_part(parts,Rect2(aim*128+torso_left,torso_top,torso_width,maxi(1,torso_bottom-torso_top)),Vector2(-floorf(torso_width/2.0),-radius*2+head_height-3))
		# Fold actual left/right shin, boot or bare-foot pixels upward and inward.
		# These quarter turns preserve every original pixel without resampling.
		var leg_width := mini(14,maxi(6,floori(used.size.x*0.3)))
		var seam := int([-1,0,1][fold_key]) * (-3 if repeated else 1)
		_part(parts,Rect2(aim*128+64-leg_width,used.end.y-foot_height,leg_width,foot_height),Vector2(-2,-radius+2+seam),PI/2.0)
		_part(parts,Rect2(aim*128+64,used.end.y-foot_height,leg_width,foot_height),Vector2(2,-radius+16-seam),-PI/2.0)
		# Face, hair and horns remain native and are laid over the folded limbs.
		_part(parts,head,head_at.position)
		var turn := key if travel < 4 else -key
		if repeated: turn = -turn
		var cache_key := "%d/%d/%d/%d" % [aim,fold_key,turn,int(repeated)]
		var cache: Dictionary = identity.tucks
		if cache.has(cache_key):
			parts = cache[cache_key]
		else:
			_clip_tuck(parts, radius, turn)
			_freeze(parts)
			if cache.size() >= MAX_TUCK_KEYS: cache.erase(cache.keys()[0])
			cache[cache_key] = parts
	return {"pixel_body_pilot":true,"fullbody_art":true,"procedural_pixel_pose":true,
		"visual_mode":"pixel_cast","pixel_action_key":false,"components":[],"pixel_parts":parts,
		"texture":identity.texture,"source_region":head,"head_destination":head_at,"pixel_shapes":shapes,
		"aerial_pose":"open_flight" if flying else "tucked_ball","pose_key":key,"second_jump_tuck":repeated and not flying,
		"action":action,"aim_index":aim,"travel_index":travel,"display_height":{ "small":58,"middle":63,"large":68 }.get(identity.body,63) if flying else radius*2,
		"offset":Vector2.ZERO,"squat_depth":0,"motion_phase":float(key)/3.0,
		"art_pose_quality":"round-clipped native anatomy, physical-phase held somersault keys" if not flying else "original airborne anatomy with three-pixel wing-key holds",
		"all_action_art_complete":false,"frame_id":"%s/aerial/%s/%d/%d/%d" % [id,action,aim,key,int(repeated)],
		"body_bounds":Rect2(-radius,-radius*2,radius*2,radius*2) if not flying else Rect2(-64,-104,128,128)}


static func _part(parts: Array[Dictionary], source: Rect2, at: Vector2, rotation: float = 0.0) -> void:
	parts.append({"source":source,"at":at,"rotation":rotation})


static func _clip_tuck(parts: Array[Dictionary], radius: int, turn: int) -> void:
	var center := Vector2(0,-radius)
	var envelope := PackedVector2Array()
	for i: int in 32:
		var angle := float(i)*TAU/32.0
		envelope.append((center+Vector2(cos(angle),sin(angle))*radius).round())
	for part: Dictionary in parts:
		var source: Rect2 = part.source
		var at: Vector2 = part.at
		var rotation := float(part.rotation)
		var quad := PackedVector2Array([Vector2.ZERO,Vector2(source.size.x,0),source.size,Vector2(0,source.size.y)])
		for i: int in quad.size(): quad[i] = (quad[i].rotated(rotation)+at).round()
		var clipped: Array[PackedVector2Array] = Geometry2D.intersect_polygons(quad,envelope)
		var meshes: Array[Dictionary] = []
		for polygon: PackedVector2Array in clipped:
			var points := PackedVector2Array()
			var uvs := PackedVector2Array()
			for point: Vector2 in polygon:
				var local := (point-at).rotated(-rotation)
				uvs.append((source.position+local)/Vector2(1024,512))
				points.append((point-center).rotated(float(turn)*PI/2.0).round()+center)
			meshes.append({"points":points,"uvs":uvs})
		part["meshes"] = meshes


static func draw(canvas: CanvasItem, value: Dictionary, anchor: Vector2, tint: Color) -> void:
	for shape: Dictionary in value.get("pixel_shapes",[]):
		var points: PackedVector2Array = shape.points.duplicate()
		for i: int in points.size(): points[i] += anchor
		canvas.draw_colored_polygon(points,(shape.color as Color)*tint)
	for part: Dictionary in value.get("pixel_parts",[]):
		if part.has("meshes"):
			for mesh: Dictionary in part.meshes:
				var points: PackedVector2Array = mesh.points.duplicate()
				for i: int in points.size(): points[i] += anchor
				canvas.draw_polygon(points,PackedColorArray([tint]),mesh.uvs,value.texture)
			continue
		var source: Rect2 = part.source
		var points := PackedVector2Array()
		var uvs := PackedVector2Array()
		var texture: Texture2D = value.texture
		for corner: Vector2 in [Vector2.ZERO, Vector2(source.size.x, 0), source.size, Vector2(0, source.size.y)]:
			points.append(anchor + (part.at as Vector2) + corner.rotated(float(part.rotation)))
			uvs.append((source.position + corner) / texture.get_size())
		# As with clipped ball meshes, explicit world vertices preserve the
		# incoming camera transform and all effects drawn after the character.
		canvas.draw_polygon(points, PackedColorArray([tint]), uvs, texture)


static func _freeze(value: Variant) -> void:
	if value is Dictionary:
		for child: Variant in value.values(): _freeze(child)
		value.make_read_only()
	elif value is Array:
		for child: Variant in value: _freeze(child)
		value.make_read_only()
