extends FluxTestSuite

const Pixels = preload("res://src/presentation/pixel_flipbook_presenter.gd")
const Fullbody = preload("res://src/presentation/fullbody_cast_presenter.gd")
const CatalogPath := "res://content/champions/foundation_champions_v1.json"

func run() -> int:
	_test_compact_contract()
	_test_live_cast()
	return finish("pixel-cast")

func _test_compact_contract() -> void:
	var image := Image.create(1024, 512, false, Image.FORMAT_RGBA8)
	for row: int in 4:
		image.fill_rect(Rect2i(0,row*128,1024,128), Color(float(row+1)/4.0,0.3,0.7))
	var texture := ImageTexture.create_from_image(image)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(image.get_data())
	var entry := {"id":"one", "body":"small", "display_height":58, "waist_y":93,
		"atlas":"one.png", "rgba_sha256":hash.finish().hex_encode()}
	var manifest := {"id":Pixels.CAST_MANIFEST_ID, "schema_version":1,
		"cell":[128,128], "pivot":[64,104], "rows":Pixels.CAST_ROWS.duplicate(),
		"directions":Pixels.DIRECTIONS.duplicate(), "characters":[entry]}
	var pixels := Pixels.new()
	check(pixels.admit_manifest(manifest,["one"],{"one.png":texture}), "four-row bank admission")
	equal(pixels.visual_mode(),"pixel_cast","full cast mode explicit")
	check(not Pixels.manifest_error(manifest,["one","two"]).is_empty(),"missing live identity fails exact-roster admission")
	var wrong := manifest.duplicate(true)
	wrong.rows = Pixels.ROWS.duplicate()
	check(not Pixels.manifest_error(wrong,["one"]).is_empty(),"six-row schema cannot masquerade as compact bank")
	for aim: int in 8:
		for travel: int in 8:
			for step: int in 4:
				var phase := step/4.0
				var frame: Dictionary = pixels.frame("one","walk",aim,travel,phase,false,0.0,false)
				var reverse := posmod(travel-aim,8) in [3,4,5]
				var beat := posmod(-step,4) if reverse else step
				var row: int = [1,0,2,0][beat]
				equal(frame.components[0].source_region,Rect2(aim*128,row*128+93,128,35),"compact walking selects exact contact/neutral beat")
				equal(frame.components[1].source_region,Rect2(aim*128,row*128,128,93),"whole-body connected direction and phase")
				var casting: Dictionary = pixels.frame("one","walk",aim,travel,phase,true,1.0,false)
				equal(casting.components[0],frame.components[0],"casting never freezes feet")
				equal(casting.components[1].source_region,Rect2(aim*128,384,128,93),"cast uses compact final row")
				for component: Dictionary in casting.components:
					check(Rect2(0,0,1024,512).encloses(component.source_region),"all matrix queries stay within compact page")
	for action: String in ["slide","jump","air_dodge","roll","wall_run","flight","stunned"]:
		equal(pixels.frame("one",action,0,0,0.0,false,0.0,false),{},"unpainted action requests explicit fallback")
	var wrong_size := ImageTexture.create_from_image(Image.create(1024,768,false,Image.FORMAT_RGBA8))
	check(not pixels.admit_manifest(manifest,["one"],{"one.png":wrong_size}),"old page geometry rejected by compact admission")
	check(pixels.entries.is_empty() and pixels.textures.is_empty() and not pixels.full_cast,"failed re-admission clears all prior bank state")
	check(not pixels.admit_manifest(manifest,["one"],{}),"missing atlas cannot expose partial bank")
	wrong = manifest.duplicate(true)
	wrong.characters[0].rgba_sha256 = "0".repeat(64)
	check(not pixels.admit_manifest(wrong,["one"],{"one.png":texture}),"changed decoded pixels fail closed")
	for position: Vector2i in [Vector2i(0,0),Vector2i(7,3)]:
		var blank := image.get_region(Rect2i(Vector2i.ZERO,image.get_size()))
		blank.fill_rect(Rect2i(position*128,Vector2i(128,128)),Color.TRANSPARENT)
		var blank_hash := HashingContext.new()
		blank_hash.start(HashingContext.HASH_SHA256);blank_hash.update(blank.get_data())
		wrong=manifest.duplicate(true)
		wrong.characters[0].rgba_sha256=blank_hash.finish().hex_encode()
		check(not pixels.admit_manifest(wrong,["one"],{"one.png":ImageTexture.create_from_image(blank)}),"correctly hashed empty required cell rejected before activation")
		check(pixels.entries.is_empty(),"empty-cell failure leaves no partial bank")
	equal(Fullbody.build_portrait(Image.create(128,128,false,Image.FORMAT_RGBA8)),{},"empty portrait rejected without zero-size crop or division")
	equal(Fullbody.build_portrait(null),{},"null portrait fails defensively")
	for fraction: float in [0.0,-0.5,1.1,NAN,INF]:
		equal(Fullbody.build_portrait(image,1,fraction),{},"unsafe portrait crop rejected")
	var ids: Array = []
	var entries: Array = []
	for index: int in 65:
		var next := entry.duplicate(true)
		next.id = "identity_%d" % index
		next.atlas = next.id + ".png"
		ids.append(next.id)
		entries.append(next)
		wrong.characters = entries
		if index == 29 or index == 63:
			equal(Pixels.manifest_error(wrong,ids),"","catalog expansion bounded but not hardcoded to30")
	check(not Pixels.manifest_error(wrong,ids).is_empty(),"65th character exceeds resident bound")

func _test_live_cast() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CatalogPath))
	var language := VisualLanguage.new()
	var presenter := CartoonChampionPresenter.new()
	check(language.load_from_file() and presenter.configure(language),"live presentation config")
	var configured := presenter.enable_fullbody_art(false,true)
	check(configured,"full live pixel bank: " + presenter.last_error)
	if not configured:
		return
	var bank: RefCounted = presenter.fullbody_art.pixel_pilot
	equal(bank.entries.size(),catalog.champions.size(),"all current characters present exactly once")
	var config := SimConfig.new(120)
	for champion: Dictionary in catalog.champions:
		var id: String = champion.id
		equal(bank.entries[id].body,champion.body_type,"visual size follows current roster")
		var inspect: Dictionary = bank.inspection_frame(id,0)
		equal(inspect.visual_mode,"pixel_cast","inspection selects new identity bank")
		var portrait: Dictionary = presenter.fullbody_art.portrait_frame(id)
		check(portrait.get("texture") is Texture2D and portrait.get("visual_mode")=="pixel_cast","every identity has an admitted head-and-shoulders portrait")
		equal(portrait.source_region.size.y,float(ceili(portrait.occupied_model_region.size.y*0.5)),"compact portrait includes lower face rather than cutting below eyes")
		for aim: int in 8:
			for travel: int in 8:
				var state := PlayerState.new()
				var look: Vector2i = EightDirectionResolver.FIXED_VECTORS[aim]
				var move: Vector2i = EightDirectionResolver.FIXED_VECTORS[travel]
				state.aim_x=look.x;state.aim_y=look.y
				state.velocity_x=move.x*200;state.velocity_y=move.y*200
				state.movement_mode=PlayerState.MovementMode.WALK
				for casting: bool in [false,true]:
					state.pending_cast_wire_id=1 if casting else 0
					state.pending_cast_ticks=0
					var before := state.canonical_values()
					for step: int in 4:
						var frame := presenter.movement_frame(id,state,0.0,config,false,step/4.0)
						check(frame.get("visual_mode")=="pixel_cast" and not frame.has("mesh"),"every live heading/travel/cast uses fixed pixels")
						equal(frame.get("aim_index"),aim,"live aim selects current heading")
						equal(frame.get("travel_index"),travel,"travel remains independent")
						equal(frame.get("cast_frame"),casting,"moving cast is not suppressed")
						check(not frame.get("backpedal_art_complete",true),"symmetric two-contact loop does not claim finished backward animation")
					equal(state.canonical_values(),before,"art queries never write authoritative state")
		for action: String in ["slide","jump","roll","air_dodge"]:
			var state := PlayerState.new()
			state.aim_x=0;state.aim_y=1000;state.facing_x=0;state.facing_y=1000;state.velocity_y=200000
			match action:
				"slide":
					state.movement_mode=PlayerState.MovementMode.SLIDE;state.slide_ticks=12;state.slide_y=1000
				"jump":
					state.movement_mode=PlayerState.MovementMode.HOP;state.hop_mode=PlayerState.MovementMode.HOP;state.hop_ticks=12;state.air_height=20000
				"roll":
					state.movement_mode=PlayerState.MovementMode.ROLL;state.hop_mode=PlayerState.MovementMode.ROLL;state.air_dodge_ticks=12
				"air_dodge":
					state.movement_mode=PlayerState.MovementMode.AIR_DODGE;state.hop_mode=PlayerState.MovementMode.HOP;state.hop_ticks=12;state.air_height=20000;state.air_dodge_ticks=12
			state.pending_cast_wire_id=1
			var before := state.canonical_values()
			var frame := presenter.movement_frame(id,state,0.0,config,false,0.5)
			var compact_jump := action == "jump"
			check(not frame.is_empty() and frame.get("pixel_body_pilot",false),"all current identities stay in fixed pixels through advanced actions")
			equal(frame.get("pixel_action_key",false),false,"compact assembly and reused keys never claim newly authored action cycles")
			equal(frame.get("rigid_pose_fallback",false),not compact_jump,"unpainted ground and dodge actions disclose their reused fixed-pixel pose")
			if compact_jump:
				# Native atlas order is south0, south-east1, east2.
				preload("res://tests/support/native_aerial_assertions.gd").assert_frame(self, frame, bank, id, action, 0, "extend")
			check(not frame.has("mesh") and not frame.has("render_mesh"),"advanced pixel-cast actions never introduce mesh morphing")
			equal(frame.get("action"),action,"fallback retains the actual action")
			equal(state.canonical_values(),before,"fallback preserves gameplay authority")
