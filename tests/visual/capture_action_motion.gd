extends SceneTree
@warning_ignore_start("integer_division")
## Complete paid SimCommand trajectories, sampled at declared 20/30/60Hz through live draw.
## This proves timer/draw coupling, not human input feel or device performance.
const IDS := ["s_wayne","oh_tipi","red_baron","grace_reava"]
const CASES := ["jump_cast","air_evade","ground_roll","wall_east","wall_west","wall_south","wall_north"]
const NORMALS := {"wall_east":Vector2i(-1000,0),"wall_west":Vector2i(1000,0),"wall_south":Vector2i(0,-1000),"wall_north":Vector2i(0,1000)}
const Fullbody = preload("res://src/presentation/fullbody_cast_presenter.gd")
var output := ""
var fps := 30
var reduced := false
var contact_audit := false
var flier_audit := false

class Board extends Node2D:
	var presenter: CartoonChampionPresenter
	var ids: Array[String]=[]
	var worlds: Array[SimWorld]=[]
	var histories: Array[ActorMotionHistory]=[]
	var effects: Array[PixelMovementEffects]=[]
	var observed_contacts: Array[Vector2]=[]
	var label := ""
	var reduced := false
	var failed := false
	var records: Array[Dictionary]=[]
	var layer_mode := "full"
	func _draw() -> void:
		PixelMagicLibrary.default_library().begin_frame(reduced)
		draw_rect(Rect2(0,0,960,550 if worlds.size()>4 else 300),Color("283e37"))
		draw_string(ThemeDB.fallback_font,Vector2(16,23),"Paid motion / "+label+" / "+layer_mode,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("eadfc3"))
		draw_string(ThemeDB.fallback_font,Vector2(16,43),"Camera follows each actor. Commands and authority ticks recorded; no gameplay edits during a trajectory.",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("acbebd"))
		for index: int in worlds.size():
			var world := worlds[index]
			var actor := world.player()
			var floor_at := Vector2(120+(index%4)*240,240+(index/4)*250)
			var world_at := Vector2(actor.position_x,actor.position_y)/1000.0
			var camera_offset := floor_at-world_at
			var sample := JumpPresentation.sample(actor,world.config,0,reduced)
			var body_at := world_at-Vector2(0,sample.body_lift_pixels)
			draw_line(floor_at+Vector2(-80,3),floor_at+Vector2(80,3),Color("778e75"),1)
			draw_set_transform(floor_at,0,sample.shadow_scale)
			draw_circle(Vector2.ZERO,18,Color(0.03,0.07,0.06,sample.shadow_opacity))
			draw_set_transform(Vector2.ZERO)
			if NORMALS.has(label):
				var normal := Vector2(NORMALS[label]).normalized()
				var wall_at := Vector2(5000,5000)-normal*20+camera_offset
				if normal.x!=0 and absf(wall_at.x-floor_at.x)<108:
					draw_line(Vector2(wall_at.x,70),Vector2(wall_at.x,245),Color("9ba78a"),2)
				elif normal.y!=0 and wall_at.y>=70 and wall_at.y<=245:
					draw_line(Vector2(floor_at.x-108,wall_at.y),Vector2(floor_at.x+108,wall_at.y),Color("9ba78a"),2)
			var before := actor.canonical_values()
			# Each independent world owns mutable contact history; admitted art remains shared.
			presenter.pixel_movement=effects[index]
			draw_set_transform(camera_offset)
			if actor.wall_contact_id>0 and actor.wall_memory_ticks==world.config.milliseconds_to_ticks(MovementTuning.WALL_MEMORY_MS):
				var normal := Vector2(actor.wall_x,actor.wall_y).normalized()
				if normal!=Vector2.ZERO: observed_contacts[index]=body_at-normal*float(MovementTuning.PLAYER_RADIUS)/1000.0
			if layer_mode=="full":
				if not presenter.draw(self,actor,ids[index],body_at,float(world.tick)/2.0,world.config,reduced,world_at,histories[index].gait_phase(1),histories[index].wall_travel(1)): failed=true
			elif layer_mode in ["body","plain_body"]:
				var frame := presenter.movement_frame(ids[index],actor,float(world.tick)/2.0,world.config,reduced,histories[index].gait_phase(1),histories[index].wall_travel(1))
				if layer_mode=="plain_body": frame.erase("cast_arm_parts")
				var tint: Color=presenter.protection_contract(actor,world.config,reduced,float(frame.display_height)).body_tint
				Fullbody.draw_frame(self,frame,body_at+(frame.get("offset",Vector2.ZERO) as Vector2),tint)
			var contact := effects[index].walljump_contact(actor,world.config,world.tick,body_at)
			if not contact.is_empty() and (not observed_contacts[index].is_finite() or not (contact.anchor as Vector2).is_equal_approx(observed_contacts[index])): failed=true
			if layer_mode=="contact" and not contact.is_empty():
				effects[index].stamp(self,"walljump_burst",contact.anchor,int(contact.age),reduced)
			if layer_mode=="full":
				var value := {"scope":index,"entity":actor.entity_id,"camera_offset":[camera_offset.x,camera_offset.y],"contact":{}}
				if not contact.is_empty():
					var at: Vector2=contact.anchor
					value.contact={"world":[at.x,at.y],"screen":[at.x+camera_offset.x,at.y+camera_offset.y],"age":int(contact.age)}
				records[index]=value
			draw_set_transform(Vector2.ZERO)
			if before!=actor.canonical_values(): failed=true
			draw_string(ThemeDB.fallback_font,floor_at+Vector2(-104,24),ids[index]+" / "+str(index)+" / "+str(world.tick),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("eadfc3"))
			draw_string(ThemeDB.fallback_font,floor_at+Vector2(-104,43),actor.last_event,HORIZONTAL_ALIGNMENT_LEFT,220,12,Color("acbebd"))

func _initialize() -> void:
	root.hide()
	_run.call_deferred()

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg=="--fps=60": fps=60
		if arg=="--reduced": reduced=true
		if arg=="--wall-contact-audit": contact_audit=true
		if arg=="--flier-cast-audit": flier_audit=true
	if contact_audit and flier_audit: _fail("Choose one bounded audit mode"); return
	if DisplayServer.get_name()=="headless" or not output.begins_with("res://.godot/motion-proof-") or ".." in output or DirAccess.dir_exists_absolute(output): _fail("Native renderer and fresh res://.godot/motion-proof-* directory required"); return
	if DirAccess.make_dir_recursive_absolute(output)!=OK: _fail("Cannot create output"); return
	var abilities := AbilityCatalog.new()
	var catalog := ChampionCatalog.new()
	var language := VisualLanguage.new()
	var presenter := CartoonChampionPresenter.new()
	if not abilities.load_from_file("res://content/abilities/foundation_abilities_v1.json") or not catalog.load_from_file("res://content/champions/foundation_champions_v1.json",abilities) or not language.load_from_file() or not presenter.configure_fullbody_startup(language,true,true): _fail("Native content admission failed"); return
	var admitted: Array[String]=[]
	admitted.assign(IDS)
	if not presenter.prepare_override_pages(admitted): _fail("Four prototype pages not resident"); return
	var viewport := SubViewport.new()
	viewport.size=Vector2i(960,550 if flier_audit else 300)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := Board.new()
	board.presenter=presenter
	board.ids.assign(["grace_reava","grace_reava","grace_reava","grace_reava","grace_reava","grace_reava","grace_reava","grace_reava"] if flier_audit else IDS)
	board.reduced=reduced
	board.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(board)
	root.mode=Window.MODE_WINDOWED
	root.size=viewport.size
	root.show()
	create_timer(180).timeout.connect(func() -> void: _fail("Native motion capture exceeded its 180-second watchdog"))
	var receipt := {"sampling_hz":20 if flier_audit else (30 if contact_audit else fps),"reduced":reduced,"authority_hz":120,"source":"ordinary paid SimCommand trajectories after documented fixture setup","acceptance":"draw/timer evidence; not physical device input, human feel, or frame-performance acceptance","scenarios":[],"sources":{},"isolated_layers":[]}
	for path: String in ["res://src/presentation/pixel_wallrun_pose.gd","res://src/presentation/pixel_cast_hands.gd","res://src/presentation/fullbody_cast_presenter.gd","res://src/presentation/pixel_aerial_pose.gd","res://src/presentation/cartoon_champion_presenter.gd","res://src/presentation/pixel_movement_effects.gd","res://src/presentation/pixel_magic_library.gd","res://tests/visual/capture_action_motion.gd","res://art_batches/pixel_v1/magic/manifest.json","res://art_batches/pixel_v1/magic/export/magic_00.png","res://assets/sprites/pixel_actions_v1/manifest.json","res://assets/sprites/pixel_cast_v1/manifest.json"]: receipt.sources[path]=FileAccess.get_sha256(path)
	for id: String in IDS:
		for bank: String in ["pixel_actions_v1","pixel_cast_v1"]:
			var path := "res://assets/sprites/%s/%s.png"%[bank,id]
			receipt.sources[path]=FileAccess.get_sha256(path)
	var cases: Array = ["jump_cast"] if flier_audit else (["wall_east"] if contact_audit else CASES)
	for kind: String in cases:
		board.worlds.clear(); board.histories.clear(); board.effects.clear(); board.observed_contacts.clear(); board.records.clear(); board.label=kind
		var diagnostics: Array[Dictionary]=[]
		for id: String in board.ids:
			var arena := CollisionWorld.new(10_000_000,10_000_000)
			if NORMALS.has(kind):
				var normal: Vector2i=NORMALS[kind]
				var lower := Vector2i(4_000_000,4_000_000)
				var upper := Vector2i(6_000_000,6_000_000)
				if normal.x<0: lower.x=5_020_000
				elif normal.x>0: upper.x=4_980_000
				elif normal.y<0: lower.y=5_020_000
				else: upper.y=4_980_000
				arena.add_obstacle(CollisionWorld.Obstacle.new(31,lower.x,lower.y,upper.x,upper.y))
			var world := SimWorld.new(120,41,arena)
			var actor := world.player()
			if not catalog.apply_to_player(actor,id): _fail("Missing actual prototype identity"); return
			actor.position_x=5_000_000; actor.position_y=5_000_000; actor.spawn_protection_ticks=0
			if not actor.place_proven_spell(0,MixtureCatalog.wire_for(2,"heavy")): _fail("Cannot equip paid spell fixture"); return
			board.worlds.append(world); board.histories.append(ActorMotionHistory.new())
			board.effects.append(PixelMovementEffects.new()); board.observed_contacts.append(Vector2.INF); board.records.append({})
			diagnostics.append({"id":id,"initial":world.state_hash(),"cast_started":0,"cast_released":0,"wall_frames":0,"protected_frames":0,"recovery_frames":0,"air_frames":0,"hands_frames":0,"released_wall":false,"frames":[],"commands":[],"events":[]})
		var frame_index := 0
		var trajectory_ticks: int=96 if flier_audit else (72 if contact_audit else 180)
		for tick: int in trajectory_ticks:
			for index: int in board.worlds.size():
				var world := board.worlds[index]
				var actor := world.player()
				var move := Vector2i(1000,0)
				var held := 0
				var pressed := 0
				if NORMALS.has(kind):
					var normal: Vector2i=NORMALS[kind]
					move=Vector2i(-normal.y,normal.x)
					if tick in [0,20]: pressed|=SimCommand.PRESSED_JUMP
					if tick>=20 and tick<50: held|=SimCommand.HELD_JUMP
					# Release before the 420ms wall budget expires. An unrelated
					# Technique press would own this tick instead of the release edge.
					if tick==32: pressed|=SimCommand.PRESSED_SPELL_1
				elif kind=="ground_roll":
					if tick==0: pressed=SimCommand.PRESSED_EVADE
				else:
					if tick==0: pressed=SimCommand.PRESSED_JUMP
					if kind=="air_evade" and tick==20: pressed|=SimCommand.PRESSED_EVADE
					if kind=="jump_cast":
						# A full ordinary ground charge gives this single jump enough
						# air time for the admitted Heavy's startup and recovery.
						if flier_audit and tick<36: held|=SimCommand.HELD_JUMP
						if tick==20 and not flier_audit: pressed|=SimCommand.PRESSED_JUMP
						if not flier_audit and actor.flight_capable and tick>=20 and tick<85: held|=SimCommand.HELD_JUMP
						if tick==(36 if flier_audit else 32): pressed|=SimCommand.PRESSED_SPELL_1
				var facing: Vector2i=EightDirectionResolver.FIXED_VECTORS[index] if flier_audit else (NORMALS[kind] if NORMALS.has(kind) else EightDirectionResolver.FIXED_VECTORS[(tick/24+index)%8])
				var command := SimCommand.new(world.tick,1,move.x,move.y,held,pressed,facing.x,facing.y)
				diagnostics[index].commands.append({"tick":world.tick,"move":[move.x,move.y],"held":held,"pressed":pressed,"aim":[facing.x,facing.y]})
				if not world.step([command]): _fail("Paid trajectory refused a simulation tick"); return
				if flier_audit and actor.air_floating: _fail("Ordinary flier cast fixture must not activate held flight"); return
				board.histories[index].capture_gaits([actor],{1:Vector2(actor.position_x,actor.position_y)/1000.0},{1:actor.air_height},1.0/120.0)
				for event: Dictionary in world.combat_events:
					diagnostics[index].events.append({"tick":world.tick,"event":event.duplicate(true)})
					if event.get("type")=="cast_started": diagnostics[index].cast_started+=1
					if event.get("type")=="projectile_spawned": diagnostics[index].cast_released+=1
				if actor.wall_skim_ticks>0: diagnostics[index].wall_frames+=1
				if actor.is_airborne(): diagnostics[index].air_frames+=1
				if actor.hop_mode==PlayerState.MovementMode.WALL_KICK: diagnostics[index].released_wall=true
				if MovementSystem.is_combat_intangible(actor,world.config): diagnostics[index].protected_frames+=1
				if not CartoonChampionPresenter.evasion_recovery_contract(actor,world.config).is_empty(): diagnostics[index].recovery_frames+=1
			var sample_step: int=6 if flier_audit else (4 if contact_audit else 120/fps)
			if (tick+1)%sample_step!=0: continue
			board.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			if board.failed: _fail("Production drawing mutated authority or failed"); return
			var leaf := "%s-%03d.png" % [kind,frame_index]
			if viewport.get_texture().get_image().save_png(output.path_join(leaf))!=OK: _fail("PNG capture failed"); return
			if contact_audit and tick+1==52:
				for layer: String in ["body","contact"]:
					board.layer_mode=layer
					board.queue_redraw()
					await process_frame
					await RenderingServer.frame_post_draw
					if board.failed: _fail("Isolated production drawing mutated authority or failed"); return
					var layer_leaf := "%s-tick052-%s.png"%[kind,layer]
					if viewport.get_texture().get_image().save_png(output.path_join(layer_leaf))!=OK: _fail("Isolated layer PNG failed"); return
					receipt.isolated_layers.append({"image":layer_leaf,"layer":layer,"tick":52,"contacts":board.records.duplicate(true)})
				board.layer_mode="full"
			if flier_audit and tick+1==54:
				board.layer_mode="plain_body"
				board.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				if board.failed: _fail("Plain authored body witness mutated authority or failed"); return
				var layer_leaf := "%s-tick054-plain-body.png"%kind
				if viewport.get_texture().get_image().save_png(output.path_join(layer_leaf))!=OK: _fail("Plain body PNG failed"); return
				receipt.isolated_layers.append({"image":layer_leaf,"layer":"plain_body_without_additive_hands","tick":54})
				board.layer_mode="full"
			for index: int in board.worlds.size():
				var world := board.worlds[index]
				var actor := world.player()
				var frame := presenter.movement_frame(board.ids[index],actor,float(world.tick)/2.0,world.config,reduced,board.histories[index].gait_phase(1),board.histories[index].wall_travel(1))
				if frame.get("independent_cast_pose",false): diagnostics[index].hands_frames+=1
				diagnostics[index].frames.append({"image":leaf,"tick":world.tick,"hash":world.state_hash(),"action":frame.get("action"),"pose":frame.get("aerial_pose",""),"hands":frame.get("cast_pose_phase",""),"height":actor.air_height,"protection":MovementSystem.is_combat_intangible(actor,world.config),"last_event":actor.last_event,"wall_ticks":actor.wall_skim_ticks,"wall_id":actor.wall_skim_surface_id,"cast_wire":actor.pending_cast_wire_id,"cast_ticks":actor.pending_cast_ticks,"cast_recovery_ticks":actor.cast_recovery_ticks,"stamina":actor.stamina,"flux":actor.flux,"contact_presentation":board.records[index].duplicate(true)})
			frame_index+=1
		receipt.scenarios.append({"name":kind,"samples":frame_index,"actors":diagnostics})
		for diagnostic: Dictionary in diagnostics: diagnostic["coverage"]=_coverage(kind,diagnostic)
		_save_partial(receipt)
		for diagnostic: Dictionary in diagnostics:
			var checks := _coverage(kind,diagnostic)
			diagnostic["coverage"]=checks
			if not checks.is_empty():
				_fail("Required trajectory coverage missing: "+kind+" / "+String(diagnostic.id)+" / "+", ".join(checks)); return
	var file := FileAccess.open(output.path_join("receipt.json"),FileAccess.WRITE)
	if file==null: _fail("Cannot save motion receipt"); return
	file.store_string(JSON.stringify(receipt,"  ")); file.close()
	print("PASS: paid motion frames captured with exact ticks/commands. Inspect clips before visual acceptance.")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _coverage(kind: String,record: Dictionary) -> PackedStringArray:
	var missing := PackedStringArray()
	if kind!="ground_roll" and int(record.air_frames)==0: missing.append("airborne action")
	if kind in ["ground_roll","air_evade"]:
		if int(record.protected_frames)==0: missing.append("protected opening")
		if int(record.recovery_frames)==0: missing.append("vulnerable recovery")
	if kind=="jump_cast" or NORMALS.has(kind):
		if int(record.cast_started)==0 or int(record.cast_released)==0: missing.append("actual paid cast/release")
		if int(record.hands_frames)==0: missing.append("sampled independent casting pose")
	if NORMALS.has(kind):
		if int(record.wall_frames)==0: missing.append("actual wall contact")
		if not bool(record.released_wall): missing.append("actual wall release")
	if flier_audit:
		var phases := {}
		var restored := false
		for frame: Dictionary in record.frames:
			if int(frame.height)>0 and String(frame.action) in ["jump","double_jump","walljump","slide_jump","fall","fast_fall"] and not String(frame.hands).is_empty():
				phases[String(frame.hands)]=true
			if int(frame.tick)>58 and int(frame.cast_wire)==0 and int(frame.cast_recovery_ticks)==0 and String(frame.hands).is_empty(): restored=true
		for phase: String in ["gather","extend","release","settle"]:
			if not phases.has(phase): missing.append("paid ordinary-air hand phase "+phase)
		if not restored: missing.append("paid cast expiry returns to plain body")
	return missing


func _save_partial(receipt: Dictionary) -> void:
	var file := FileAccess.open(output.path_join("partial-receipt.json"),FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify(receipt,"  "))
		file.close()
