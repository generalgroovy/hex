extends SceneTree
## Native registration board from real Fullbody queries; not motion-cycle proof.
const Art = preload("res://src/presentation/fullbody_cast_presenter.gd")
const CATALOG := "res://content/champions/foundation_champions_v1.json"
const ACTIONS := ["idle","jumpsquat","jump","fall","land","idle"]
var output := ""
var requested_id := "s_wayne"


class Board:
	extends Node2D
	var presenter: RefCounted
	var casting := false
	var reduced := false
	var failed := false
	var frames: Array[Dictionary] = []
	var records: Array[Dictionary] = []
	var checks := 0
	var config := SimConfig.new(120)
	var champion_id := "s_wayne"
	var champion_name := "S. Wayne"
	var standing_height := 58
	func prepare() -> void:
		frames.clear(); records.clear(); checks=0; failed=false
		for row: int in 6:
			for aim: int in 8:
				var action: String = ACTIONS[row]
				var state := PlayerState.new(9500+aim)
				var look: Vector2i = EightDirectionResolver.FIXED_VECTORS[aim]
				state.aim_x=look.x; state.aim_y=look.y
				state.facing_x=look.x; state.facing_y=look.y
				state.pending_cast_wire_id=1 if casting else 0; state.pending_cast_ticks=0
				match action:
					"jumpsquat": state.jumpsquat_active=true; state.jumpsquat_ticks=18
					"jump", "fall":
						state.movement_mode=PlayerState.MovementMode.HOP; state.hop_mode=PlayerState.MovementMode.HOP
						state.hop_ticks=12; state.air_height=24000
						state.air_vertical_velocity=30000 if action=="jump" else -30000
					"land": state.landing_ticks=6
				var before := state.canonical_values()
				var frame: Dictionary = presenter.frame(champion_id,state,60.0,config,0.375,reduced)
				var is_key := bool(frame.get("pixel_action_key",false))
				var expected_key := row in [1,2,3,4]
				var unchanged := state.canonical_values()==before
				if frame.is_empty() or frame.get("action")!=action or frame.get("visual_mode")!="pixel_cast" or frame.has("mesh") or is_key!=expected_key or not unchanged:
					failed=true
				var regions: Array = []
				for component: Dictionary in frame.get("components",[]):
					var source: Rect2 = component.source_region
					var destination: Rect2 = component.destination_region
					regions.append({"source":[source.position.x,source.position.y,source.size.x,source.size.y],
						"destination":[destination.position.x,destination.position.y,destination.size.x,destination.size.y]})
				frames.append(frame)
				records.append({"row":row,"requested_action":action,"actual_action":frame.get("action"),
					"aim":frame.get("aim_index"),"travel":frame.get("travel_index"),"frame_id":frame.get("frame_id",""),
					"pixel_action_key":is_key,"visual_mode":frame.get("visual_mode"),"art_pose_quality":frame.get("art_pose_quality"),
					"motion_phase":frame.get("motion_phase"),"independent_cast_pose":frame.get("independent_cast_pose",false),
					"cast_overlay_requested":frame.get("cast_overlay_requested",false),"ground_cast_frame":frame.get("cast_frame",false),
					"casting_fixture":casting,"reduced_motion":reduced,"authority_unchanged":unchanged,
					"fixture_air_height":state.air_height,"components":regions})
				checks+=1
	func _draw() -> void:
		draw_rect(Rect2(0,0,1152,832),Color("31473e"))
		draw_string(ThemeDB.fallback_font,Vector2(8,20),"%s | real presenter | casting=%s reduced=%s | held keys, not completed cycles" % [champion_name,casting,reduced],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("f3d9a1"))
		draw_string(ThemeDB.fallback_font,Vector2(8,38),"Fixed registration: pale line = foot pivot; faint line = standing %dpx guide. World lift excluded from this board." % standing_height,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("c6d0bc"))
		for row: int in 6:
			var baseline := float(row*128+144)
			draw_line(Vector2(128,baseline),Vector2(1152,baseline),Color(0.8,0.88,0.78,0.35))
			draw_line(Vector2(128,baseline-standing_height),Vector2(1152,baseline-standing_height),Color(0.7,0.82,0.8,0.13))
			draw_string(ThemeDB.fallback_font,Vector2(8,baseline-30),ACTIONS[row],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("f3d9a1"))
			for aim: int in 8:
				var anchor := Vector2(128+aim*128+64,baseline)
				var frame: Dictionary = frames[row*8+aim]
				if not frame.is_empty(): Art.draw_frame(self,frame,anchor)
				draw_string(ThemeDB.fallback_font,anchor+Vector2(-14,17),Art.DIRS[aim],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("c6d0bc"))


func _initialize() -> void:
	root.hide()
	_run.call_deferred()


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
		if argument.begins_with("--champion="): requested_id=argument.trim_prefix("--champion=")
		if argument=="--all-characters": requested_id="all"
	var probe_root: String = ProjectSettings.globalize_path(str(get_script().resource_path)).get_base_dir().get_base_dir().get_base_dir().replace("\\","/")
	var normalized := output.replace("\\","/")
	var contained := normalized.begins_with("res://.godot/pixel-actions-") or normalized.begins_with(probe_root.path_join(".godot/pixel-actions-"))
	if DisplayServer.get_name()=="headless" or not contained or ".." in normalized or DirAccess.dir_exists_absolute(output):
		push_error("Fresh contained native pixel-actions output required"); quit(1); return
	if DirAccess.make_dir_recursive_absolute(output)!=OK:
		push_error("Could not create native pixel-actions output"); quit(1); return
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	var ids: Array = []
	for champion: Dictionary in catalog.champions: ids.append(champion.id)
	var presenter := Art.new()
	if not presenter.configure(ids) or not presenter.enable_pixel_pilot(ids,true):
		push_error(presenter.last_error); quit(1); return
	if requested_id!="all" and not ids.has(requested_id):
		push_error("Unknown capture identity"); quit(1); return
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1152,832)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := Board.new()
	board.presenter=presenter
	board.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(board)
	var images: Array[String] = []
	var reports: Array[Dictionary] = []
	var total_checks := 0
	for champion: Dictionary in catalog.champions:
		if requested_id!="all" and champion.id!=requested_id: continue
		board.champion_id=champion.id; board.champion_name=champion.display_name
		board.standing_height={"small":58,"middle":63,"large":68}[champion.body_type]
		for casting: bool in [false,true]:
			for reduced: bool in [false,true]:
				board.casting=casting; board.reduced=reduced
				board.prepare(); board.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				var leaf := "%s-cast-%d-reduced-%d.png" % [String(champion.id).replace("_","-"),int(casting),int(reduced)]
				if board.failed or viewport.get_texture().get_image().save_png(output.path_join(leaf))!=OK:
					push_error("Pixel-action presenter capture failed: "+String(champion.id)); quit(1); return
				images.append(leaf)
				reports.append({"champion":champion.id,"image":leaf,"casting":casting,"reduced_motion":reduced,"checks":board.checks,"frames":board.records.duplicate(true)})
				total_checks+=board.checks
	var receipt := FileAccess.open(output.path_join("receipt.json"),FileAccess.WRITE)
	if receipt==null:
		push_error("Pixel-action receipt could not be written"); quit(1); return
	receipt.store_string(JSON.stringify({"images":images,"checks":total_checks,"reports":reports,
		"scope":"actual full-cast Fullbody presenter; 8 headings x idle/squat/rise/fall/land/idle x casting x reduced motion; fixed native registration boards",
		"world_lift_applied":false,"physical_input":false,"timed_motion_cycle":false,
		"human_acceptance":false,"all_actions_replaced":false,"independent_air_cast_art_complete":false},"\t")+"\n")
	receipt.close()
	print("PASS: ",images.size()," native action-key boards / ",total_checks," presenter queries; motion-cycle and human acceptance remain open")
	quit(0)
