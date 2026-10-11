extends SceneTree
## Standalone art acceptance workbench, never the production game.
const ActorView = preload("res://art_batches/character_motion_v1/motion_view.gd")
const DIRS := ["S","SE","E","NE","N","NW","W","SW"]
var manifest: Dictionary
var bank: Dictionary
var folder := ""
var actors: Array = []
var actor
var selected := 0
var action_index := 1
var actions: Array = []
var phase := 0.0
var elapsed := 0.0
var motion_paused := false
var aim := 0
var travel := 0
var light := false
var overlay := false
var board: MotionBoard
var capture := ""
var key_bank:Dictionary={}
const KEY_MANIFEST := "res://art_batches/character_motion_v1/output/authored-keys-v2/manifest.json"

class MotionBoard extends Node2D:
	var owner_gallery
	func _process(delta: float) -> void:
		owner_gallery.advance(delta)
		queue_redraw()
	func _unhandled_key_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo:
			owner_gallery.key(event.keycode)
	func _draw() -> void:
		owner_gallery.paint(self)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var path := "res://art_batches/character_motion_v1/output/motion-common-heads-v3/manifest.json"
	var validate := false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--manifest="): path=argument.trim_prefix("--manifest=")
		if argument.begins_with("--capture="): capture=argument.trim_prefix("--capture=")
		if argument=="--validate": validate=true
	if not path.begins_with("res://art_batches/character_motion_v1/output/") or ".." in path:
		fail("Unsafe manifest"); return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("factory")!="articulated_fullbody_candidate_v1" or parsed.get("production_ready")!=false:
		fail("Wrong candidate manifest"); return
	manifest=parsed
	folder=path.get_base_dir()
	var bank_path:=folder.path_join(String(manifest.motion_bank))
	if String(manifest.motion_bank)!=String(manifest.motion_bank).get_file() or FileAccess.get_sha256(bank_path)!=manifest.motion_bank_sha256:
		fail("Motion bank hash mismatch");return
	bank=JSON.parse_string(FileAccess.get_file_as_string(bank_path))
	actions=bank.actions.keys()
	if FileAccess.file_exists(KEY_MANIFEST):
		var key_parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(KEY_MANIFEST))
		if not key_parsed is Dictionary or ActorView.vec(key_parsed.get("cell",[0,0]))!=Vector2(128,128) or ActorView.vec(key_parsed.get("pivot",[0,0]))!=Vector2(64,104):
			fail("Invalid authored key catalog");return
		key_bank=key_parsed
	if validate:
		var count:=0
		for character: Dictionary in manifest.characters:
			var candidate=ActorView.new()
			if not candidate.configure(folder,character,bank): fail(candidate.error);return
			if not configure_authored(candidate,character.id): fail("Invalid authored key atlas");return
			for action: String in actions:
				for direction: int in 8:
					for t: float in [0.0,0.25,0.5,0.75,1.0]:
						for command: Dictionary in candidate.commands(action,direction,(direction+2)%8,t):
							var transform: Transform2D=command.transform
							if not transform.origin.is_finite() or not is_finite(transform.get_rotation()):
								fail("Nonfinite transform");return
						count+=1
			candidate=null
		print("PASS: %d cast members, %d action samplings; hashes, atlas loading and finite articulated transforms. NOT visual acceptance." % [manifest.characters.size(),count])
		quit(0);return
	for index:int in manifest.characters.size():
		if manifest.characters[index].id=="wa_bidi": selected=index;break
	load_actor()
	action_index=actions.find("slide")
	board=MotionBoard.new()
	board.owner_gallery=self
	board.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	root.size=Vector2i(1280,720)
	root.title="H.E.X. Full-Body Motion - ART CANDIDATE"
	root.add_child(board)
	if not capture.is_empty(): await capture_frames()

func fail(message: String) -> void:
	printerr(message)
	quit(1)

func load_actor() -> void:
	actor=null
	actor=ActorView.new()
	if not actor.configure(folder,manifest.characters[selected],bank): fail(actor.error)
	if not configure_authored(actor,manifest.characters[selected].id): fail("Invalid authored key atlas")

func configure_authored(candidate, id:String) -> bool:
	for definition:Dictionary in key_bank.get("characters",[]):
		if definition.id==id: return candidate.configure_keys(KEY_MANIFEST.get_base_dir(),definition)
	return true

func key(code: int) -> void:
	match code:
		KEY_ESCAPE: quit()
		KEY_LEFT: selected=posmod(selected-1,manifest.characters.size());load_actor()
		KEY_RIGHT: selected=(selected+1)%manifest.characters.size();load_actor()
		KEY_UP: action_index=posmod(action_index-1,actions.size());phase=0
		KEY_DOWN: action_index=(action_index+1)%actions.size();phase=0
		KEY_SPACE: motion_paused=not motion_paused
		KEY_B: light=not light
		KEY_T: travel=(travel+1)%8
		KEY_C: overlay=not overlay
		KEY_M: actor.deform_mesh=not actor.deform_mesh
		KEY_K: actor.authored_keys_enabled=not actor.authored_keys_enabled
		KEY_R: phase=0
	if code>=KEY_1 and code<=KEY_8: aim=code-KEY_1

func advance(delta: float) -> void:
	if motion_paused or not capture.is_empty(): return
	elapsed+=delta
	var definition: Dictionary=bank.actions[actions[action_index]]
	phase+=delta*float(definition.fps)/float(definition.frames)
	if phase>=1.3: phase=0.0

func paint(canvas: CanvasItem) -> void:
	var bg:=Color("ded1ae") if light else Color("252b35")
	var ink:=Color("2d2830") if light else Color("eed9b0")
	canvas.draw_rect(Rect2(0,0,1280,720),bg)
	var font:=ThemeDB.fallback_font
	var char: Dictionary=manifest.characters[selected]
	var action: String=actions[action_index]
	canvas.draw_string(font,Vector2(22,32),"H.E.X.  /  FULL-BODY ARTICULATED MOTION CANDIDATES",HORIZONTAL_ALIGNMENT_LEFT,-1,22,ink)
	canvas.draw_string(font,Vector2(22,62),"%s  |  %s / %s  |  %s  |  aim %s / travel %s" % [char.display_name,char.race,char.body,action,DIRS[aim],DIRS[travel]],HORIZONTAL_ALIGNMENT_LEFT,-1,19,ink)
	canvas.draw_string(font,Vector2(22,88),"Arrows character/action |1-8 aim |T travel |C cast |M mesh/layers |K authored keys |Space pause |B background |Esc",HORIZONTAL_ALIGNMENT_LEFT,-1,14,ink)
	var authored_active:bool=actor.key_texture!=null and actor.authored_keys_enabled and not actor.authored_row(action,phase).is_empty()
	var status:="AUTHORED ACTION KEYS: real full-body poses, not complete cycles or live-game integration." if authored_active else "PROCEDURAL REVIEW HOLD: gaps/stretch/occlusion remain. Not installed in the game."
	canvas.draw_string(font,Vector2(22,112),status,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("cd976c"))
	for index: int in 8:
		var at:=Vector2(12+(index%4)*316,118+(index/4)*250)
		canvas.draw_line(at+Vector2(0,208),at+Vector2(256,208),Color("63746b"),1)
		var row_travel:int=index if bool(bank.actions[action].get("travel_facing",false)) else travel
		actor.draw(canvas,action,index,row_travel,phase,at,2.0,overlay)
		canvas.draw_string(font,at+Vector2(115,234),DIRS[index],HORIZONTAL_ALIGNMENT_LEFT,-1,16,ink)
	canvas.draw_string(font,Vector2(22,648),"240 authored standing sources -> shared fixed-bone motion -> editable character-specific layer corrections.",HORIZONTAL_ALIGNMENT_LEFT,-1,16,ink)
	canvas.draw_string(font,Vector2(22,674),"Shared skull target: 18px. Bodies: 58 / 63 / 68px; size carried by body mass. Gameplay unchanged. Review pending.",HORIZONTAL_ALIGNMENT_LEFT,-1,15,ink)
	canvas.draw_string(font,Vector2(22,700),"Large-pose skinning is held: source gaps, mesh stretch and occlusion need authored corrections. Do not promote.",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("cd976c"))

func capture_frames() -> void:
	if not capture.begins_with("res://art_batches/character_motion_v1/output/") or ".." in capture:
		fail("Unsafe capture path");return
	DirAccess.make_dir_recursive_absolute(capture)
	# Previous pilots plus the next three identities, not a full-cast visual pass.
	for id: String in ["s_wayne","oh_tipi","red_baron","wa_bidi","jan_wicked","fluup"]:
		for index: int in manifest.characters.size():
			if manifest.characters[index].id==id: selected=index
		load_actor()
		for clip: String in ["idle","walk","sprint","slide","cast","jump","roll"]:
			action_index=actions.find(clip)
			phase=0.25
			board.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var screenshot:=root.get_texture().get_image()
			if screenshot.save_png(capture.path_join(id+"-"+clip+".png"))!=OK: fail("Capture save failed");return
	print("PASS: captured 42 native six-character/eight-direction action boards. Review candidates, not animation approval.")
	quit(0)
