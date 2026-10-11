extends FluxTestSuite
## Admission and routing evidence, not artwork or animation-cycle acceptance.
const Bank = preload("res://src/presentation/pixel_action_bank.gd")
const Pixels = preload("res://src/presentation/pixel_flipbook_presenter.gd")
const Fullbody = preload("res://src/presentation/fullbody_cast_presenter.gd")
const ACTION_ROWS := {"jumpsquat":0, "jump":1, "double_jump":1, "walljump":1,
	"slide_jump":1, "fall":2, "fast_fall":2, "land":3}
const CATALOG := "res://content/champions/foundation_champions_v1.json"


class RejectedActionBank:
	extends RefCounted
	var last_error := "injected optional action admission failure"
	var called := false
	func configure(_parent_entries: Dictionary) -> bool:
		called=true
		return false


func run() -> int:
	_test_manifest()
	_test_admission()
	_test_selection_matrix()
	_test_fullbody_routing()
	return finish("pixel-action-bank")


func _pixels() -> Image:
	var image := Image.create(1024,512,false,Image.FORMAT_RGBA8)
	for row: int in 4:
		for direction: int in 8:
			image.fill_rect(Rect2i(direction*128+40,row*128+50,48,54),Color(float(row+1)/4.0,float(direction+1)/8.0,0.5,1.0))
	return image


func _hash(image: Image) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(image.get_data())
	return hash.finish().hex_encode()


func _manifest(digest: String) -> Dictionary:
	return {"id":"hex-pixel-actions-v1","schema_version":1,"cell":[128,128],"pivot":[64,104],
		"directions":["S","SE","E","NE","N","NW","W","SW"],
		"rows":["jumpsquat","rise","fall","land"],
		"characters":[{"id":"one","body":"small","atlas":"one.png","rgba_sha256":digest}]}


func _parents() -> Dictionary:
	return {"one":{"body":"small"},"two":{"body":"middle"}}


func _test_manifest() -> void:
	var valid := _manifest("a".repeat(64))
	equal(Bank.manifest_error(valid,_parents()),"","explicit subset may omit unrelated parent identities")
	var json_round_trip: Variant = JSON.parse_string(JSON.stringify(valid))
	equal(Bank.manifest_error(json_round_trip,_parents()),"","JSON round-trip numeric floats preserve exact cell and pivot geometry")
	for geometry_key: String in ["cell","pivot"]:
		var expected := 128 if geometry_key=="cell" else 64
		for malformed_number: Variant in [str(expected),true,float(expected)+0.5,NAN,INF]:
			var changed := valid.duplicate(true)
			changed[geometry_key][0]=malformed_number
			check(not Bank.manifest_error(changed,_parents()).is_empty(),"geometry rejects strings, booleans, fractional and nonfinite values")
	for malformed: Variant in [null,false,0,"bad",[],{}]:
		check(not Bank.manifest_error(malformed,_parents()).is_empty(),"malformed manifest fails validation")
	for key: String in ["id","schema_version","cell","pivot","directions","rows","characters"]:
		var changed := valid.duplicate(true)
		changed.erase(key)
		check(not Bank.manifest_error(changed,_parents()).is_empty(),"required manifest field: "+key)
	for change: Dictionary in [{"id":"wrong"},{"schema_version":2},{"schema_version":NAN},{"cell":[128,127]},
		{"pivot":[64,103]},{"directions":["S","SE","E","NW","N","NE","W","SW"]},
		{"rows":["land","rise","fall","jumpsquat"]},{"characters":[]},{"characters":[null]}]:
		var changed := valid.duplicate(true)
		changed.merge(change,true)
		check(not Bank.manifest_error(changed,_parents()).is_empty(),"identity/geometry/row/roster contract is strict")
	for key: String in ["id","body","atlas","rgba_sha256"]:
		var changed := valid.duplicate(true)
		changed.characters[0].erase(key)
		check(not Bank.manifest_error(changed,_parents()).is_empty(),"required character field: "+key)
	for id: Variant in ["unknown","",1,null]:
		var changed := valid.duplicate(true)
		changed.characters[0].id=id
		check(not Bank.manifest_error(changed,_parents()).is_empty(),"unknown or malformed identity rejected")
	for body: Variant in ["middle","large","unknown",null]:
		var changed := valid.duplicate(true)
		changed.characters[0].body=body
		check(not Bank.manifest_error(changed,_parents()).is_empty(),"action art cannot change parent body tier")
	for leaf: Variant in ["","../one.png","nested/one.png","nested\\one.png","C:one.png","one.jpg","one..png",null]:
		var changed := valid.duplicate(true)
		changed.characters[0].atlas=leaf
		check(not Bank.manifest_error(changed,_parents()).is_empty(),"unsafe or malformed atlas leaf rejected")
	for digest: Variant in ["","a".repeat(63),"a".repeat(65),"A".repeat(64),"g".repeat(64),null]:
		var changed := valid.duplicate(true)
		changed.characters[0].rgba_sha256=digest
		check(not Bank.manifest_error(changed,_parents()).is_empty(),"digest requires lowercase SHA256")
	var duplicate := valid.duplicate(true)
	duplicate.characters.append(duplicate.characters[0].duplicate(true))
	check(not Bank.manifest_error(duplicate,_parents()).is_empty(),"duplicate identity rejected")
	duplicate.characters[1].id="two"
	duplicate.characters[1].body="middle"
	check(not Bank.manifest_error(duplicate,_parents()).is_empty(),"two identities cannot share one page")
	duplicate.characters[1].atlas="two.png"
	equal(Bank.manifest_error(duplicate,_parents()),"","distinct subset entries admitted structurally")
	var bounded := valid.duplicate(true)
	bounded.characters=[]
	var parents := {}
	for index: int in 65:
		var id := "actor_%d" % index
		parents[id]={"body":"small"}
		bounded.characters.append({"id":id,"body":"small","atlas":id+".png","rgba_sha256":"a".repeat(64)})
		if index==63: equal(Bank.manifest_error(bounded,parents),"","64 entries remain within resident bound")
	check(not Bank.manifest_error(bounded,parents).is_empty(),"65th entry exceeds resident bound")


func _test_admission() -> void:
	var image := _pixels()
	var texture := ImageTexture.create_from_image(image)
	var valid := _manifest(_hash(image))
	var json_round_trip: Variant = JSON.parse_string(JSON.stringify(valid))
	var json_bank := Bank.new()
	check(json_bank.admit(json_round_trip,_parents(),{"one.png":texture}),"JSON-deserialized manifest reaches decoded-page admission: "+json_bank.last_error)
	check(json_bank.entries.has("one") and json_bank.textures.has("one"),"JSON number representation cannot silently disable valid optional action art")
	var bank := Bank.new()
	check(bank.admit(valid,_parents(),{"one.png":texture}),"valid page admitted")
	var frame: Dictionary = bank.frame("one","jump",0,0,0.5,false)
	valid.characters[0].body="large"
	equal(bank.entries.one.body,"small","admission copies metadata rather than sharing mutable manifest")
	valid.characters[0].body="small"
	frame.components[0].source_region=Rect2()
	equal(bank.frame("one","jump",0,0,0.5,false).components[0].source_region,Rect2(0,128,128,128),"queries own fresh component dictionaries")
	for pages: Dictionary in [{},{"one.png":null},{"one.png":ImageTexture.create_from_image(Image.create(1024,768,false,Image.FORMAT_RGBA8))}]:
		check(not bank.admit(valid,_parents(),pages),"missing or wrong-size page fails closed")
		check(bank.entries.is_empty() and bank.textures.is_empty() and not bank.last_error.is_empty(),"failed admission clears prior visibility and reports error")
	var wrong := valid.duplicate(true)
	wrong.characters[0].rgba_sha256="0".repeat(64)
	check(not bank.admit(wrong,_parents(),{"one.png":texture}),"changed decoded pixel hash rejected")
	for row: int in 4:
		for direction: int in 8:
			var blank := image.get_region(Rect2i(0,0,1024,512))
			blank.fill_rect(Rect2i(direction*128,row*128,128,128),Color.TRANSPARENT)
			wrong=valid.duplicate(true)
			wrong.characters[0].rgba_sha256=_hash(blank)
			check(not bank.admit(wrong,_parents(),{"one.png":ImageTexture.create_from_image(blank)}),"correctly hashed blank required cell rejected: %d/%d" % [row,direction])
			check(bank.entries.is_empty() and bank.textures.is_empty(),"blank-cell failure exposes no partial art")
	wrong=valid.duplicate(true)
	wrong.characters.append({"id":"two","body":"middle","atlas":"two.png","rgba_sha256":_hash(image)})
	check(not bank.admit(wrong,_parents(),{"one.png":texture}),"failure after first valid entry remains atomic")
	check(bank.entries.is_empty() and bank.textures.is_empty(),"later failure cannot publish first entry")
	equal(bank.frame("one","jump",0,0,0.5,false),{},"failed admission offers explicit fallback only")
	check(bank.admit(valid,_parents(),{"one.png":texture}),"valid re-admission recovers after failure")
	equal(bank.last_error,"","successful re-admission clears old error")


func _test_selection_matrix() -> void:
	var image := _pixels()
	var texture := ImageTexture.create_from_image(image)
	var bank := Bank.new()
	check(bank.admit(_manifest(_hash(image)),_parents(),{"one.png":texture}),"synthetic action bank admitted")
	var pixels := Pixels.new()
	var ground := {"id":Pixels.CAST_MANIFEST_ID,"schema_version":1,"cell":[128,128],"pivot":[64,104],
		"directions":Pixels.DIRECTIONS.duplicate(),"rows":Pixels.CAST_ROWS.duplicate(),
		"characters":[{"id":"one","body":"small","display_height":58,"waist_y":93,"atlas":"one.png","rgba_sha256":_hash(image)}]}
	check(pixels.admit_manifest(ground,["one"],{"one.png":texture}),"synthetic parent bank admitted")
	pixels.action_bank=bank
	for action: String in ACTION_ROWS:
		for aim: int in 8:
			for travel: int in 8:
				for casting: bool in [false,true]:
					for reduced: bool in [false,true]:
						var frame: Dictionary = pixels.frame("one",action,aim,travel,0.375,casting,1.0 if casting else 0.0,reduced)
						_check_key(frame,action,aim,travel,casting)
	for action: String in ACTION_ROWS:
		var held: Dictionary = bank.frame("one",action,2,6,0.0,false)
		for phase: float in [-2.0,0.25,0.5,1.0,15.0]:
			var sample: Dictionary = bank.frame("one",action,2,6,phase,false)
			equal(sample.frame_id,held.frame_id,"a held key never claims invented intermediate poses")
			equal(sample.motion_phase,phase,"actual finite phase remains inspectable")
	for bad: int in [-100,-1,8,100]:
		equal(bank.frame("one","jump",bad,0,0.5,false),{},"invalid aim index rejected")
		equal(bank.frame("one","jump",0,bad,0.5,false),{},"invalid travel index rejected")
	for phase: float in [NAN,INF,-INF]:
		equal(bank.frame("one","jump",0,0,phase,false),{},"nonfinite phase rejected by action bank")
		equal(pixels.frame("one","jump",0,0,phase,false,0.0,false),{},"nonfinite phase rejected at parent boundary")
	for weight: float in [NAN,INF,-INF,-0.1,1.1]:
		equal(pixels.frame("one","jump",0,0,0.5,true,weight,false),{},"malformed cast envelope rejected before key lookup")
	for action: String in ["idle","walk","sprint","crouch","slide","roll","air_dodge","wavedash","wallrun","fly","hit","stunned","defeated","unknown"]:
		equal(bank.frame("one",action,0,0,0.5,false),{},"unmapped action stays outside explicit key coverage")
	equal(bank.frame("two","jump",0,0,0.5,false),{},"unpainted parent identity requests fallback")
	check(not pixels.frame("one","idle",0,0,0.0,false,0.0,false).get("pixel_action_key",false),"ground bank is not replaced by action keys")
	check(not pixels.frame("one","walk",0,0,0.5,true,1.0,false).get("pixel_action_key",false),"ground moving cast retains existing bank")
	var ground_entries := pixels.entries.duplicate(true)
	var rejected := RejectedActionBank.new()
	check(not pixels.configure_actions(rejected) and rejected.called,"optional failure is exercised through actual configuration boundary")
	check(pixels.action_bank==null,"failed optional reconfiguration clears previous action extension only")
	equal(pixels.action_bank_error,rejected.last_error,"optional admission failure remains inspectable")
	equal(pixels.last_error,"","optional rejection does not turn valid parent admission into a failure")
	equal(pixels.entries,ground_entries,"optional rejection preserves admitted ground metadata")
	check(pixels.full_cast and pixels.textures.one==texture,"optional rejection preserves ground mode and texture")
	var retained: Dictionary = pixels.frame("one","walk",0,0,0.5,true,1.0,false)
	check(not retained.is_empty() and retained.get("cast_frame",false),"ground movement and casts remain visible after optional rejection")
	equal(pixels.frame("one","jump",0,0,0.5,true,1.0,false),{},"rejected optional action explicitly requests legacy fallback")
	check(not pixels.configure_actions(null),"null optional bank is rejected defensively")
	equal(pixels.action_bank_error,"","null reconfiguration clears stale optional diagnostics")
	check(not pixels.frame("one","idle",0,0,0.0,false,0.0,false).is_empty(),"null optional bank does not revoke valid ground frames")


func _check_key(frame: Dictionary, action: String, aim: int, travel: int, casting: bool) -> void:
	check(not frame.is_empty(),"mapped action produces a visible key")
	if frame.is_empty(): return
	check(frame.get("pixel_action_key",false) and frame.get("pixel_body_pilot",false),"authored key route is explicit")
	equal(frame.action,action,"mapped alias retains semantic action")
	equal(frame.aim_index,aim,"whole body uses current aim facing")
	equal(frame.travel_index,travel,"travel metadata remains independent")
	var components: Variant = frame.get("components")
	var whole_cell: bool = components is Array and components.size()==1 and components[0] is Dictionary
	check(whole_cell,"low/air pose uses one whole-cell blit without waist cut")
	if not whole_cell: return
	equal(components[0].get("source_region"),Rect2(aim*128,ACTION_ROWS[action]*128,128,128),"exact authored row and heading selected")
	equal(components[0].get("destination_region"),Rect2(0,0,128,128),"native fixed canvas is neither scaled nor rotated")
	equal(frame.get("pivot"),Vector2(64,104),"common body pivot retained")
	equal(frame.get("offset"),Vector2.ZERO,"world lift is not baked into sprite offset")
	equal(frame.get("cast_overlay_requested"),casting,"cast request remains visible in diagnostics")
	check(not frame.get("independent_cast_pose",true),"free hands are not claimed as an independently authored cast pose")
	check(not frame.get("all_action_art_complete",true),"four keys do not claim all-action completion")
	for forbidden: String in ["mesh","render_mesh","rotation","scale","pose_blend"]:
		check(not frame.has(forbidden),"fixed key excludes body morphing: "+forbidden)


func _test_fullbody_routing() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	var ids: Array = []
	for champion: Dictionary in catalog.champions: ids.append(champion.id)
	var presenter := Fullbody.new()
	var configured := presenter.configure(ids)
	check(configured,"live fullbody fallback admission: "+presenter.last_error)
	if not configured: return
	configured=presenter.enable_pixel_pilot(ids,true)
	check(configured,"live full-cast plus additive action admission: "+presenter.last_error)
	if not configured: return
	var action_admitted: bool = presenter.pixel_pilot.action_bank!=null
	check(action_admitted,"live optional action bank must admit before matrix: "+presenter.pixel_pilot.action_bank_error)
	if not action_admitted: return
	equal(presenter.pixel_pilot.action_bank.entries.size(),ids.size(),"published action bank contains every current identity exactly once")
	var old_pilot := Pixels.new()
	check(old_pilot.configure(ids,false),"preserved three-character pilot still admits independently")
	check(not old_pilot.full_cast and old_pilot.action_bank==null,"old opt-in pilot never silently loads new action bank")
	var unused_rejection := RejectedActionBank.new()
	check(not old_pilot.configure_actions(unused_rejection) and not unused_rejection.called,"action extension is unavailable on historical three-character mode")
	check(not old_pilot.frame("s_wayne","idle",0,0,0.0,false,0.0,false).is_empty(),"old pilot ground frame remains available")
	equal(old_pilot.frame("s_wayne","jump",0,0,0.5,false,0.0,false),{},"old pilot retains its original jump fallback")
	var config := SimConfig.new(120)
	for action: String in ACTION_ROWS:
		for aim: int in 8:
			for travel: int in 8:
				for casting: bool in [false,true]:
					for reduced: bool in [false,true]:
						var state := _state(action,aim,travel,casting)
						var before := state.canonical_values()
						var frame: Dictionary = presenter.frame("s_wayne",state,60.0,config,0.375,reduced)
						_check_routed_frame(frame,action,aim,aim if action=="land" else travel,casting)
						equal(state.canonical_values(),before,"Fullbody queries cannot write gameplay or grant a capability")
	for id: String in ids:
		if id=="s_wayne": continue
		for action: String in ACTION_ROWS:
			for aim: int in 8:
				for travel: int in 8:
					for casting: bool in [false,true]:
						for reduced: bool in [false,true]:
							var state := _state(action,aim,travel,casting)
							var before := state.canonical_values()
							var frame: Dictionary = presenter.frame(id,state,60.0,config,0.375,reduced)
							_check_routed_frame(frame,action,aim,aim if action=="land" else travel,casting)
							equal(state.canonical_values(),before,"all-roster action queries preserve authoritative state: "+id)
	for action: String in ["slide","roll"]:
		for aim: int in 8:
			for casting: bool in [false,true]:
				for reduced: bool in [false,true]:
					var state := _state(action,aim,(aim+3)%8,casting)
					var before := state.canonical_values()
					var frame: Dictionary = presenter.frame("s_wayne",state,60.0,config,0.375,reduced)
					check(not frame.is_empty() and not frame.get("pixel_action_key",false),"unpainted S. Wayne low action discloses reused pose rather than claiming authored coverage")
					check(frame.get("rigid_pose_fallback",false) and not frame.has("mesh") and not frame.has("render_mesh"),"slide/roll preserve fixed-pixel anatomy without legacy rig morphing")
					equal(frame.get("source_pose"),"jumpsquat","low actions reuse the existing whole-body gather key explicitly")
					equal(frame.components[0].source_region,Rect2(((aim+3)%8)*128,0,128,128),"slide/roll whole-body key follows actual travel independently of aim")
					equal(frame.get("action"),action,"fallback does not disguise unsupported action")
					equal(state.canonical_values(),before,"unsupported-action fallback is presentation only")


func _state(action: String, aim: int, travel: int, casting: bool) -> PlayerState:
	var state := PlayerState.new(9400)
	var look: Vector2i = EightDirectionResolver.FIXED_VECTORS[aim]
	var move: Vector2i = EightDirectionResolver.FIXED_VECTORS[travel]
	state.aim_x=look.x; state.aim_y=look.y
	state.facing_x=look.x; state.facing_y=look.y
	state.velocity_x=move.x*200; state.velocity_y=move.y*200
	state.pending_cast_wire_id=1 if casting else 0
	state.pending_cast_ticks=0
	match action:
		"jumpsquat":
			state.jumpsquat_active=true; state.jumpsquat_ticks=18
		"land":
			state.velocity_x=0; state.velocity_y=0; state.landing_ticks=6
		"slide":
			state.movement_mode=PlayerState.MovementMode.SLIDE; state.slide_ticks=12
			state.slide_x=move.x; state.slide_y=move.y
		"roll":
			state.movement_mode=PlayerState.MovementMode.ROLL; state.hop_mode=PlayerState.MovementMode.ROLL; state.air_dodge_ticks=12
		_:
			state.movement_mode=PlayerState.MovementMode.HOP; state.hop_mode=PlayerState.MovementMode.HOP
			state.hop_ticks=12; state.air_height=24000; state.air_vertical_velocity=30000
			if action=="double_jump": state.hop_mode=PlayerState.MovementMode.DOUBLE_JUMP
			elif action=="walljump": state.hop_mode=PlayerState.MovementMode.WALL_KICK
			elif action=="slide_jump": state.hop_mode=PlayerState.MovementMode.SLIDE_JUMP
			elif action in ["fall","fast_fall"]:
				state.air_vertical_velocity=-30000
				if action=="fast_fall": state.movement_mode=PlayerState.MovementMode.FAST_FALL
	return state


func _check_routed_frame(frame: Dictionary, action: String, aim: int, travel: int, casting: bool) -> void:
	if action not in Fullbody.AerialPose.BALL_ACTIONS:
		_check_key(frame, action, aim, travel, casting)
		return
	check(frame.get("procedural_pixel_pose", false), "non-flying airborne route uses an explicit compact pose")
	equal(frame.get("aerial_pose"), "tucked_ball", "jump and repeated jump visibly tuck the body")
	equal(frame.get("components"), [], "tuck cannot fall back to a translated upright whole-body sprite")
	equal(frame.get("action"), action, "compact pose retains semantic jump/descent action")
	equal(frame.get("aim_index"), aim, "original face follows immediate aim")
	equal(frame.get("travel_index"), travel, "jump travel remains independent of face")
	equal(frame.get("cast_overlay_requested"), casting, "tucked casting retains external hand-effect admission")
	var source: Rect2 = frame.source_region
	var destination: Rect2 = frame.head_destination
	equal(source.size, destination.size, "original head pixels are never squeezed or resized")
	check(source.size.y <= 22 and destination.end.y < 0, "only the compact directional face accompanies the tucked body")
	check(frame.pixel_shapes.is_empty() and frame.pixel_parts.size() == 4 and frame.display_height <= 50, "ball geometry has a bounded compact silhouette and draw budget")
	check(not frame.get("all_action_art_complete", true), "additive poses do not claim all action art is complete")
