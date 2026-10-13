extends SceneTree
## Ignored native subtraction proof; no application boot or performance claim.
const ROOT := "res://.godot/iteration-20261013/hud-name/"
const Candidate = preload("res://.godot/iteration-20261013/hud-name/candidate_hud.gd")
const Packet = preload("res://src/net/hex_world_snapshot.gd")
const BEFORE_SHA := "a6a62bc23cceed6c9e9f4e75d2b4d19120a89929f5cbceac6b4d4bf183bceb73"
const WATCHED := [ROOT+"compare-hud-name.gd", ROOT+"candidate_hud.gd", ROOT+"compact_combat_hud.before.gd",
	"res://src/presentation/compact_combat_hud.gd", "res://src/presentation/compact_hud_layout_cache.gd",
	"res://src/presentation/visual_language.gd", "res://src/presentation/cartoon_champion_presenter.gd",
	"res://src/presentation/cast_startup_witness.gd", "res://src/app/bootstrap.gd",
	"res://src/sim/core/sim_world.gd", "res://src/sim/core/sim_config.gd", "res://src/sim/entities/player_state.gd",
	"res://src/sim/movement/movement_system.gd", "res://src/presentation/jump_presentation.gd",
	"res://src/net/hex_world_snapshot.gd", "res://src/content/runtime_build_identity.gd",
	"res://content/visual/compact_hud_v1.json", "res://content/champions/foundation_champions_v1.json",
	"res://content/abilities/foundation_abilities_v1.json"]

class BeforeHud extends CompactCombatHud:
	var actual_resource_call: Dictionary={}
	func _draw_resources(canvas: CanvasItem, rectangle: Rect2, state: PlayerState, champion_id: String, champion_name: String, layout: Dictionary, tick_rate: int) -> void:
		actual_resource_call={"rectangle":rectangle,"entity":state.entity_id,"champion":champion_id,"name":champion_name,"protection":protection_status(state,tick_rate)}
		super._draw_resources(canvas,rectangle,state,champion_id,champion_name,layout,tick_rate)

class AfterHud extends Candidate:
	var actual_resource_call: Dictionary={}
	func _draw_resources(canvas: CanvasItem, rectangle: Rect2, state: PlayerState, champion_id: String, champion_name: String, layout: Dictionary, tick_rate: int) -> void:
		actual_resource_call={"rectangle":rectangle,"entity":state.entity_id,"champion":champion_id,"name":champion_name,"protection":protection_status(state,tick_rate)}
		super._draw_resources(canvas,rectangle,state,champion_id,champion_name,layout,tick_rate)

class Board extends Node2D:
	var hud: CompactCombatHud
	var world: SimWorld
	var actor: PlayerState
	var catalog: AbilityCatalog
	var preferences: PlayerPreferences
	var champion_id := ""
	var champion_name := ""
	var spectating := false
	var pointer := Vector2(-1000,-1000)
	var active := false
	var serial := 0
	var pure := false
	func _draw() -> void:
		serial+=1
		draw_rect(get_viewport_rect(),Color("283e37"))
		if not active: return
		var before := world.state_hash()
		hud.draw(self,get_viewport_rect().size,actor,catalog,champion_id,champion_name,"Element Garden","PRACTICE",0,120,spectating,
			world.available_cast_offer(actor.entity_id),world.transition_policy.cast_gate_reason(actor),pointer,"",preferences,{})
		pure=before==world.state_hash()

var output := ""
var output_authorized := false
var finished := false
var checks := 0
var errors: Array[String]=[]
var source_hashes: Dictionary={}
var cases: Array[Dictionary]=[]
var commands: Array[Dictionary]=[]
var language := VisualLanguage.new()
var abilities := AbilityCatalog.new()
var champions := ChampionCatalog.new()
var portraits := CartoonChampionPresenter.new()
var preferences := PlayerPreferences.new()
var world: SimWorld
var before_board: Board
var after_board: Board
var before_view: SubViewport
var after_view: SubViewport
var paid_evade: Dictionary={}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	if not _check(DisplayServer.get_name()!="headless" and OS.get_cmdline_user_args().has("--no-lan-discovery")
		and output.get_base_dir()==ROOT+"runs" and output.get_file().begins_with("native-") and output.get_file().is_valid_filename()
		and not ".." in output and not DirAccess.dir_exists_absolute(output) and not FileAccess.file_exists(output),"Fresh exact owned native directory and no-LAN required"): _finish();return
	if not _check(DirAccess.make_dir_recursive_absolute(output)==OK,"Owned output created"): _finish();return
	output_authorized=true
	for path: String in WATCHED:
		source_hashes[path]=FileAccess.get_sha256(path)
		if not _check(String(source_hashes[path]).length()==64,"Watched source exists: "+path): _finish();return
	if not _source_guard(): _finish();return
	if not _check(language.load_from_file() and abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json")
		and champions.load_from_file("res://content/champions/foundation_champions_v1.json",abilities)
		and portraits.configure_fullbody_startup(language,true,true),"Actual content admission"): _finish();return
	var ids: Array[String]=["oh_tipi","wa_bidi"]
	if not _check(portraits.prepare_override_pages(ids),"Both actual portrait pages admitted"): _finish();return
	world=SimWorld.new(120,817,CollisionWorld.new(2000000,2000000))
	var court := HexChemistryWorld.new()
	if not _check(court.configure_geometry(Vector2i(800000,800000),HexGrid.disk(Vector2i.ZERO,12)),"Actual finite court"): _finish();return
	court.chemistry_enabled=true;world.hex_court=court
	for index: int in 2:
		var actor: PlayerState=world.player() if index==0 else PlayerState.new(2)
		if not _check(champions.apply_to_player(actor,ids[index]),"Actual finite champion profile"): _finish();return
		actor.reset_for_spawn(Vector2i(800000,800000+index*180000))
		actor.team_id=1
		if not _check(actor.place_proven_spell(0,MixtureCatalog.wire_for(2,"heavy")),"Prepared ordinary legal loadout"): _finish();return
		if index==1: world.players.append(actor)
	before_board=Board.new();after_board=Board.new()
	before_board.hud=BeforeHud.new();after_board.hud=AfterHud.new()
	for board: Board in [before_board,after_board]:
		if not _check(board.hud.configure(language),"Current HUD layout admitted"): _finish();return
		board.hud.champion_art=portraits;board.world=world;board.catalog=abilities;board.preferences=preferences
		board.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	before_view=_viewport(before_board);after_view=_viewport(after_board)
	create_timer(120).timeout.connect(func() -> void:
		if not finished: errors.append("Bounded native watchdog expired");_finish())
	if not await _both_sizes("local",0,false,false): _finish();return
	if not await _both_sizes("spectator",1,true,false): _finish();return
	if not await _both_sizes("switch_back",0,false,false): _finish();return
	var stamina_before := world.players[1].stamina
	if not _step(true): _finish();return
	var target: PlayerState=world.players[1]
	if not _check(target.is_rolling() and target.last_event=="roll" and target.stamina<stamina_before
		and CompactCombatHud.protection_status(target,120)=="PROTECTED","Actual ordinary paid Evade enters protected state"): _finish();return
	paid_evade={"tick":world.tick,"stamina_before":stamina_before,"stamina_after":target.stamina,"state":target.canonical_values(),"events":world.combat_events.duplicate(true)}
	if not await _both_sizes("protected_outside",1,true,false): _finish();return
	if not await _both_sizes("protected_inside",1,true,true): _finish();return
	for unused: int in 120:
		if CompactCombatHud.protection_status(target,120).is_empty(): break
		if not _step(false): _finish();return
	if not _check(CompactCombatHud.protection_status(target,120).is_empty() and world.tick>int(paid_evade.tick),"Protection expires through ordinary successful steps"): _finish();return
	if not await _both_sizes("expired_inside",1,true,true): _finish();return
	if not await _both_sizes("expired_outside",1,true,false): _finish();return
	for width: int in [960,1280]:
		var local := _find_case("local",width)
		var switched := _find_case("switch_back",width)
		var spectator := _find_case("spectator",width)
		if not _check(local.header_sha256==switched.header_sha256 and local.resource_sha256==switched.resource_sha256
			and local.header_sha256!=spectator.header_sha256 and local.portrait_sha256!=spectator.portrait_sha256,"Actual identity switch and return remain visible at "+str(width)): _finish();return
		for phase: String in ["protected","expired"]:
			var inside := _find_case(phase+"_inside",width)
			var outside := _find_case(phase+"_outside",width)
			if not _check(inside.header_sha256==outside.header_sha256 and inside.resource_sha256==outside.resource_sha256
				and inside.detail_sha256!=outside.detail_sha256,"Actual resource-pointer inspection changes only the separate detail panel"): _finish();return
	for path: String in source_hashes:
		if not _check(source_hashes[path]==FileAccess.get_sha256(path),"No watched source drift: "+path): _finish();return
	_finish()

func _source_guard() -> bool:
	if not _check(source_hashes["res://src/presentation/compact_combat_hud.gd"]==BEFORE_SHA and source_hashes[ROOT+"compact_combat_hud.before.gd"]==BEFORE_SHA,"Exact frozen current HUD predecessor"): return false
	var source := FileAccess.get_file_as_string(ROOT+"compact_combat_hud.before.gd").replace("\r\n","\n")
	var start := source.find("func _draw_resources(")
	var end := source.find("\n\nstatic func jump_preparation_status",start)
	if not _check(start>=0 and end>start,"Exact method extraction boundary"): return false
	var method := source.substr(start,end-start).strip_edges()
	var old_line := "\tcanvas.draw_string(ThemeDB.fallback_font, rectangle.position + Vector2(54, 19), champion_name.to_upper() if protection.is_empty() else protection, HORIZONTAL_ALIGNMENT_LEFT, rectangle.size.x - 64.0, 11, language.ui_color(\"text_primary\") if protection.is_empty() else language.ui_color(\"focus\"))"
	var new_line := "\tif not protection.is_empty():\n\t\tcanvas.draw_string(ThemeDB.fallback_font, rectangle.position + Vector2(54, 19), protection, HORIZONTAL_ALIGNMENT_LEFT, rectangle.size.x - 64.0, 11, language.ui_color(\"focus\"))"
	if not _check(method.count(old_line)==1,"Exactly one duplicate-name call"): return false
	var expected := "extends CompactCombatHud\n## Ignored prototype: omit only the lower duplicate idle identity.\n\n"+method.replace(old_line,new_line).replace("champion_name: String","_champion_name: String")+"\n"
	return _check(FileAccess.get_file_as_string(ROOT+"candidate_hud.gd")==expected,"Candidate differs only by protected-only text and unused parameter name")

func _viewport(board: Board) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1280,720);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport);viewport.add_child(board)
	return viewport

func _step(evade: bool) -> bool:
	var typed: Array[SimCommand]=[SimCommand.new(world.tick,1,0,0,0,0,1000,0),SimCommand.new(world.tick,2,1000,0,0,SimCommand.PRESSED_EVADE if evade else 0,1000,0)]
	commands.append({"tick":world.tick,"target_move_x":1000,"target_pressed":typed[1].pressed_actions})
	if not _check(world.step(typed),"Ordinary successful paid-route step"): return false
	return _check(world.hex_court.conservation_valid() and not Packet.capture(world).is_empty(),"Finite complete authoritative state")

func _both_sizes(label: String,index: int,spectating: bool,inside: bool) -> bool:
	for size: Vector2i in [Vector2i(960,540),Vector2i(1280,720)]:
		if not await _case(label,index,spectating,inside,size): return false
	return true

func _case(label: String,index: int,spectating: bool,inside: bool,size: Vector2i) -> bool:
	var actor: PlayerState=world.players[index]
	var champion_id := "oh_tipi" if index==0 else "wa_bidi"
	var champion_name := String(champions.champion(champion_id).display_name)
	var layout: Dictionary=before_board.hud.data.layout
	var rectangle := Rect2(float(layout.margin),float(size.y)-float(layout.margin)-float(layout.resource_height),float(layout.resource_width),float(layout.resource_height))
	var pointer := rectangle.get_center() if inside else Vector2(rectangle.end.x+1,rectangle.end.y-1)
	var detail_lines := CompactCombatHud.resource_detail_lines(actor,120)
	var detail_rect := CompactCombatHud.resource_detail_panel(rectangle,Vector2(size),detail_lines.size())
	if not _check(rectangle.has_point(pointer)==inside,"Actual resource rectangle pointer boundary"): return false
	if label.begins_with("protected") or label.begins_with("expired"):
		if not _check(not detail_lines.is_empty() and detail_rect.has_area(),"Paid stamina creates genuine hover details"): return false
	var authority := world.state_hash()
	var packet := var_to_bytes(Packet.capture(world))
	var events := var_to_bytes(world.combat_events)
	for board: Board in [before_board,after_board]:
		board.active=false;board.actor=actor;board.champion_id=champion_id;board.champion_name=champion_name;board.spectating=spectating;board.pointer=pointer
	before_view.size=size;after_view.size=size
	await process_frame;await process_frame;RenderingServer.force_draw(false)
	var before_serial := before_board.serial
	var after_serial := after_board.serial
	for board: Board in [before_board,after_board]: board.active=true;board.queue_redraw()
	await process_frame;await process_frame;RenderingServer.force_draw(false)
	var before_call: Dictionary=(before_board.hud as BeforeHud).actual_resource_call
	var after_call: Dictionary=(after_board.hud as AfterHud).actual_resource_call
	if not _check(before_board.serial==before_serial+1 and after_board.serial==after_serial+1 and before_board.pure and after_board.pure,"Exactly one pure actual HUD draw per arm"): return false
	if not _check(before_call==after_call and before_call.rectangle==rectangle and int(before_call.entity)==actor.entity_id,"Same actual observed actor/protection/layout arguments"): return false
	if not _check(world.state_hash()==authority and var_to_bytes(Packet.capture(world))==packet and var_to_bytes(world.combat_events)==events,"Native draws preserve all authority, packet and events"): return false
	var a := before_view.get_texture().get_image()
	var b := after_view.get_texture().get_image()
	if not _check(a!=null and b!=null,"Native pixels exist"): return false
	a.convert(Image.FORMAT_RGBA8);b.convert(Image.FORMAT_RGBA8)
	if not _check(a.get_size()==size and b.get_size()==size,"Exact native physical dimensions"): return false
	# Only the old idle-text ink may differ. Resource bars begin at y+29;
	# the fixed protected warning occupies this same reserved row.
	var roi := Rect2i(Vector2i(rectangle.position)+Vector2i(52,3),Vector2i(int(rectangle.size.x)-62,25))
	var outside_regions: Array[Rect2i]=[Rect2i(0,0,size.x,roi.position.y),Rect2i(0,roi.end.y,size.x,size.y-roi.end.y),Rect2i(0,roi.position.y,roi.position.x,roi.size.y),Rect2i(roi.end.x,roi.position.y,size.x-roi.end.x,roi.size.y)]
	for region: Rect2i in outside_regions:
		if not _check(a.get_region(region).get_data()==b.get_region(region).get_data(),"All pixels outside duplicate idle-text row remain exact"): return false
	var delta := 0
	for y: int in range(roi.position.y,roi.end.y):
		for x: int in range(roi.position.x,roi.end.x):
			if a.get_pixel(x,y)!=b.get_pixel(x,y): delta+=1
	var protected := not String(before_call.protection).is_empty()
	if not _check((delta==0 and a.get_data()==b.get_data()) if protected else delta>0,"Protection entire-image parity; idle change exists only in allowed name row"): return false
	var header := Rect2i(int(layout.margin),int(layout.margin),int(layout.header_width),int(layout.header_height))
	var portrait := Rect2i(Vector2i(rectangle.position)+Vector2i(7,12),Vector2i(43,44))
	var images := {}
	for role: String in ["before","after"]:
		var path := output.path_join(label+"-"+str(size.x)+"-"+role+".png")
		if not _check((a if role=="before" else b).save_png(path)==OK,"Representative PNG saved"): return false
		images[role]={"path":path,"sha256":FileAccess.get_sha256(path)}
	cases.append({"label":label,"width":size.x,"height":size.y,"tick":world.tick,"observed_entity":actor.entity_id,"champion":champion_id,"name":champion_name,"spectating":spectating,
		"protection":before_call.protection,"pointer_inside":inside,"pointer":[pointer.x,pointer.y],"resource_rectangle":[rectangle.position.x,rectangle.position.y,rectangle.size.x,rectangle.size.y],
		"detail_lines":Array(detail_lines),"difference_pixels":delta,"all_outside_pixels_exact":true,"protected_entire_image_exact":protected,
		"header_sha256":_image_hash(b.get_region(header)),"portrait_sha256":_image_hash(b.get_region(portrait)),"resource_sha256":_image_hash(b.get_region(Rect2i(rectangle))),
		"detail_sha256":_image_hash(b.get_region(Rect2i(detail_rect))) if detail_rect.has_area() else "","authority_hash":authority,"images":images})
	return true

func _image_hash(value: Image) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256);context.update(value.get_data())
	return context.finish().hex_encode()

func _find_case(label: String,width: int) -> Dictionary:
	for row: Dictionary in cases:
		if row.label==label and int(row.width)==width: return row
	return {}

func _check(value: bool,message: String) -> bool:
	checks+=1
	if not value: errors.append(message)
	return value

func _finish() -> void:
	if finished: return
	finished=true
	var record := {"schema":"hex.hud.duplicate-name.native.v1","passed":errors.is_empty() and cases.size()==14,"checks":checks,"errors":errors,"engine":Engine.get_version_info(),
		"source_hashes":source_hashes,"cases":cases,"commands":commands,"paid_evade":paid_evade,
		"scope":"Offscreen native SubViewport complete HUD before/after only; two actual champion states exercise the established local/spectator argument contract and actor switch. Actual ordinary finite Evade and natural protection expiry; pointer coordinates enter the unchanged production resource inspection path. This is not Bootstrap spectator navigation, physical keyboard/controller/mouse, modal overlap,200% layout, animation feel, GPU, foreground frame pacing or performance proof. No application boot, user profile, save, LAN, generation or authority writes from drawing. Only declared ordinary commands advance authority.",
		"candidate":"Omit only repeated lower idle name; preserve top identity/WATCHING, portrait, every resource rectangle/bar/quantity, inspection, protection text and reserved warning position. No panel size or timing benefit claimed.",
		"boundedness":"14 paired cases,28 PNGs,two viewports at most1280x720; at most121 ordinary simulation steps;120second watchdog; no cost loops."}
	if output_authorized:
		var path := output.path_join("receipt.json")
		var file := FileAccess.open(path,FileAccess.WRITE)
		if file==null: errors.append("Receipt open failed")
		else:
			var encoded := JSON.stringify(record,"\t")+"\n"
			file.store_string(encoded);file.flush();var error := file.get_error();file.close()
			if error!=OK or FileAccess.get_file_as_string(path)!=encoded: errors.append("Receipt write/readback failed")
	if bool(record.passed) and errors.is_empty(): print("HUD_NAME_NATIVE_PASS checks=",checks," cases=",cases.size());quit(0)
	else: printerr("HUD_NAME_NATIVE_FAIL: ",errors);quit(1)
