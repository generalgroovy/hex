extends RefCounted
## Candidate-only articulated authored sprites. Simulation and hurtboxes stay external.

const DIRECTIONS := ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
const ORIGIN := Vector2(16, 20)
var texture: Texture2D
var entry: Dictionary
var motions: Dictionary
var error := ""
var deform_mesh := true
var mesh_holds: Array[ArrayMesh] = []
var key_texture: Texture2D
var key_rows: Array = []
var authored_keys_enabled := true

func configure_keys(folder: String, definition: Dictionary) -> bool:
	var leaf:=String(definition.get("atlas",""))
	if leaf!=leaf.get_file() or ".." in leaf: return false
	var path:=folder.path_join(leaf)
	if FileAccess.get_sha256(path)!=definition.get("atlas_sha256",""): return false
	var image:=Image.load_from_file(path)
	if image==null or image.get_size()!=Vector2i(1024,1024): return false
	key_texture=ImageTexture.create_from_image(image)
	key_rows=definition.rows
	return true

func authored_row(action: String, phase: float) -> String:
	match action:
		"slide": return "slide_entry" if phase<0.2 else "slide_hold"
		"roll": return "roll_anticipation" if phase<0.3 else "roll_tuck"
		"jumpsquat": return "jumpsquat"
		"jump": return "jump_rise"
		"fall": return "fall"
		"land": return "land"
	return ""

static func vec(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

static func angle(a: Vector2, b: Vector2) -> float:
	return (b-a).angle()

static func solve_leg(start: Vector2, end: Vector2, hint: Vector2, upper: float, lower: float) -> Array:
	var delta := end-start
	var span := clampf(delta.length(),absf(upper-lower)+0.001,upper+lower-0.001)
	var axis := delta.normalized() if delta.length()>0.001 else Vector2.DOWN
	var along := (upper*upper-lower*lower+span*span)/(2.0*span)
	var normal := Vector2(-axis.y,axis.x)
	if (hint-start).dot(normal)<0: normal=-normal
	var knee := start+axis*along+normal*sqrt(maxf(0,upper*upper-along*along))
	return [knee,start+axis*span]

func configure(folder: String, character: Dictionary, bank: Dictionary) -> bool:
	entry = character
	motions = bank
	var leaf := String(entry.get("atlas", ""))
	if leaf != leaf.get_file() or ".." in leaf:
		error = "Unsafe atlas path"
		return false
	var path := folder.path_join(leaf)
	if FileAccess.get_sha256(path) != entry.get("atlas_sha256", ""):
		error = "Layer atlas hash mismatch"
		return false
	var image := Image.load_from_file(path)
	if image == null or image.is_empty() or image.get_width() > 2048 or image.get_height() > 2048:
		error = "Invalid atlas dimensions"
		return false
	texture = ImageTexture.create_from_image(image)
	return true

func sample(action: String, aim: int, travel: int, phase: float) -> Dictionary:
	var size: String = entry.body
	var body: Dictionary = motions.bodies[size]
	var definition: Dictionary = motions.actions[action]
	var facing := travel if bool(definition.get("travel_facing", false)) else aim
	var key := "%s/%d/%d" % [action, facing, travel if bool(definition.get("travel_matrix", false)) else facing]
	var frames: Array = body.clips[key]
	var looping := bool(definition.get("loop", false))
	var p := fposmod(phase, 1.0) if looping else clampf(phase, 0.0, 1.0)
	var cursor := p * (frames.size() if looping else frames.size()-1)
	var first := mini(frames.size()-1, floori(cursor))
	var second := (first+1) % frames.size() if looping else mini(frames.size()-1, first+1)
	var t := cursor - first
	var points: Dictionary = {}
	for name: String in frames[first].points:
		points[name] = vec(frames[first].points[name]).lerp(vec(frames[second].points[name]), t)
	return {"points": points, "rest": body.rest[str(facing)], "facing": facing,
		"order": frames[first].get("order", []), "phase_index": first}

static func retarget(source: Dictionary, rest: Dictionary, target: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var source_pelvis := vec(source.pelvis)
	var source_neck := vec(source.neck)
	var rest_pelvis := vec(rest.pelvis)
	var rest_neck := vec(rest.neck)
	var target_pelvis: Vector2 = target.pelvis
	var target_neck: Vector2 = target.neck
	var ratio := source_neck.distance_to(source_pelvis) / maxf(1.0, rest_neck.distance_to(rest_pelvis))
	var turn := angle(target_pelvis, target_neck) - angle(rest_pelvis, rest_neck)
	result.pelvis = source_pelvis + (target_pelvis-rest_pelvis)*ratio
	for name: String in ["neck", "head", "shoulder_l", "shoulder_r", "hip_l", "hip_r"]:
		result[name] = result.pelvis + (vec(source[name])-source_pelvis).rotated(turn)
	for side: String in ["l", "r"]:
		for chain: Array in [["shoulder_"+side,"elbow_"+side,"hand_"+side], ["hip_"+side,"knee_"+side,"ankle_"+side,"toe_"+side]]:
			for index: int in range(chain.size()-1):
				var start: String = chain[index]
				var finish: String = chain[index+1]
				var delta := angle(target[start], target[finish])-angle(vec(rest[start]),vec(rest[finish]))
				result[finish] = result[start] + (vec(source[finish])-vec(source[start])).rotated(delta)
		# Solve planted/travel foot endpoints, not just bone angles. Otherwise a
		# character with different costume proportions visibly skates or floats.
		var hip := "hip_"+side
		var knee := "knee_"+side
		var ankle := "ankle_"+side
		var toe := "toe_"+side
		var desired: Vector2 = vec(source[ankle])+(target[ankle]-vec(rest[ankle]))*ratio
		var solved := solve_leg(result[hip],desired,result[knee],vec(source[hip]).distance_to(vec(source[knee])),vec(source[knee]).distance_to(vec(source[ankle])))
		var foot_offset: Vector2=result[toe]-result[ankle]
		result[knee]=solved[0]
		result[ankle]=solved[1]
		result[toe]=solved[1]+foot_offset
	return result

func commands(action: String, aim: int, travel: int, phase: float, casting: bool = false) -> Array:
	var sampled := sample(action, aim, travel, phase)
	var direction: Dictionary = entry.directions[DIRECTIONS[sampled.facing]]
	var anchors: Dictionary = direction.anchors
	var target := retarget(anchors, sampled.rest, sampled.points)
	if casting:
		var cast_sample := sample("cast", aim, travel, phase)
		var cast_target := retarget(anchors, cast_sample.rest, cast_sample.points)
		for side: String in ["l", "r"]:
			# Move only the arms; running feet keep their uninterrupted phase.
			var attachment: Vector2 = target["shoulder_"+side]-cast_target["shoulder_"+side]
			for joint: String in ["elbow_"+side,"hand_"+side]:
				target[joint]=cast_target[joint]+attachment
	var output: Array = []
	var depth_order: Array = []
	for part_name: String in direction.layers:
		if part_name.begins_with("correction__"): depth_order.append(part_name)
	for part_name: String in direction.order:
		if part_name.begins_with("appendage_"): depth_order.append(part_name)
	for part_name: String in sampled.order:
		if not depth_order.has(part_name): depth_order.append(part_name)
	for part_name: String in direction.order:
		if not depth_order.has(part_name): depth_order.append(part_name)
	for name: String in depth_order:
		if name=="fullbody": continue
		if not direction.layers.has(name):
			continue
		var part: Dictionary = direction.layers[name]
		var binding: Array = part.binding
		var first: String = binding[0]
		var second: String = binding[1]
		var pivot := vec(anchors[first])
		var rotation := angle(target[first],target[second])-angle(pivot,vec(anchors[second]))
		if action=="fly" and name.begins_with("appendage_wing_"):
			rotation+=sin(phase*TAU)*0.12*(-1.0 if name.ends_with("l") else 1.0)
		var rect: Array = part.rect
		var transform := Transform2D(rotation, target[first]+ORIGIN)
		output.append({"name":name,"transform":transform,"pivot":pivot,"offset":vec(part.source_origin)-pivot,
			"region":Rect2(float(rect[0]),float(rect[1]),float(rect[2]),float(rect[3]))})
	return output

func draw(canvas: CanvasItem, action: String, aim: int, travel: int, phase: float, at: Vector2, zoom: float, casting: bool = false) -> void:
	var authored:=authored_row(action,phase)
	if authored_keys_enabled and key_texture!=null and key_rows.has(authored):
		var facing:=travel if action in ["slide","wavedash","roll"] else aim
		var region:=Rect2(facing*128,key_rows.find(authored)*128,128,128)
		canvas.draw_texture_rect_region(key_texture,Rect2(at,Vector2(128,128)*zoom),region)
		return
	var rendered := commands(action,aim,travel,phase,casting)
	if deform_mesh:
		draw_connected(canvas,action,aim,travel,phase,at,zoom,rendered)
		return
	for part: Dictionary in rendered:
		var transform: Transform2D = part.transform
		canvas.draw_set_transform(at+transform.origin*zoom,transform.get_rotation(),Vector2.ONE*zoom)
		canvas.draw_texture_rect_region(texture,Rect2(part.offset,part.region.size),part.region)
	canvas.draw_set_transform(Vector2.ZERO)

func draw_connected(canvas: CanvasItem, action: String, aim: int, travel: int, phase: float, at: Vector2, zoom: float, rendered: Array) -> void:
	var sampled:=sample(action,aim,travel,phase)
	var direction:Dictionary=entry.directions[DIRECTIONS[sampled.facing]]
	if not direction.has("mesh_vertices"): return
	var transforms:Dictionary={}
	for command:Dictionary in rendered: transforms[command.name]=command
	var full:Dictionary=direction.layers.fullbody
	var rect:Array=full.rect
	var atlas_size:=texture.get_size()
	var vertices:=PackedVector3Array()
	var uvs:=PackedVector2Array()
	for vertex:Dictionary in direction.mesh_vertices:
		var point:=vec(vertex.point)
		var projected:Array=[]
		for name:String in vertex.parts:
			if not transforms.has(name): name="torso"
			var command:Dictionary=transforms[name]
			projected.append(command.transform*(point-command.pivot))
		var moved:Vector2=projected[1].lerp(projected[0],float(vertex.weight))
		vertices.append(Vector3(moved.x,moved.y,0))
		var origin:=vec(full.source_origin)
		var uv:=Vector2(float(rect[0]),float(rect[1]))+point-origin
		# Outside the trimmed body must sample transparent padding, never a
		# neighbouring packed limb. Clamp to its two-pixel gutter.
		uv=uv.clamp(Vector2(rect[0]-1,rect[1]-1),Vector2(rect[0]+rect[2]+1,rect[1]+rect[3]+1))
		uvs.append(uv/atlas_size)
	var indices:=PackedInt32Array()
	for y:int in 16:
		for x:int in 16:
			var i:=y*17+x
			indices.append_array(PackedInt32Array([i,i+1,i+17,i+1,i+18,i+17]))
	var arrays:Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	# Canvas commands keep a RID, not this local RefCounted object. Retain
	# recent meshes through rendering; bounded candidate-only working set.
	mesh_holds.append(mesh)
	if mesh_holds.size()>128: mesh_holds.pop_front()
	canvas.draw_mesh(mesh,texture,Transform2D(0,Vector2.ONE*zoom,0,at))
